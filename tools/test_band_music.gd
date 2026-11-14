## THE MARCHING BAND's MUSIC (jobs band-music, band-music-v2 and band-repertoire, docs/band_music.md): the REPERTOIRE
## BandSound plays (assets/audio/band/<tune>_<part>.ogg, made by tools/audio/make_band_music.py) must:
##  - have every tune's six files (drums, fife, pipes: background and solo), all exactly the tune's length (TUNES "n");
##  - give the Drummer a BACKGROUND part (a beating, snare and bass) like the Fifer and the Piper;
##  - keep the parts' loudness together: alone, the three background parts within LOUD_SPREAD dB of each other (a
##    rough loudness: the mixer's RMS after a high-pass, K-weighting's main step), the solo parts louder than the
##    background ones (the files themselves are levelled by LUFS in the script: -27 / -23, the pipes 1.5 LU back);
##  - go from one tune to the next without a click (the end of a tune, then the next one's roll-off);
##  - stay in step (two parts started on the band's clock stay within a few ms);
##  - the PLAYLIST: never the same tune twice in a row, the slow air never while fighting (and cut short at a phrase end
##    if fighting starts during it), the slow air may come next when the band stands idle;
##  - a SOLO does not change the tune (that, and the music going down further, are checked in test_marching_band.gd).
##   xvfb-run -a godot --rendering-driver opengl3 --write-movie /tmp/band_test/out.png --fixed-fps 30 --resolution 320x180 \
##       --script res://tools/test_band_music.gd        (the movie writer mixes the sound: every check runs)
##   godot --headless --fixed-fps 30 --script res://tools/test_band_music.gd   (no sound is mixed headless: the file and
##       playlist checks run, the sound checks are skipped with a note)
extends SceneTree
var fails := 0
const LOUD_SPREAD := 4.0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-78s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func stream(f: String) -> AudioStream:
	var st: AudioStream = (load("res://assets/audio/%s.ogg" % f) as AudioStream).duplicate()
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = false
	return st


## The capture's frames as a mono PackedFloat32Array.
func mono(fr: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(fr.size())
	for i in fr.size():
		out[i] = (fr[i].x + fr[i].y) * 0.5
	return out


## A rough loudness (dB): RMS after a first-order high-pass at 120 Hz (the low end counts less, as in K-weighting).
func loud(x: PackedFloat32Array) -> float:
	var a := exp(-TAU * 120.0 / 44100.0)
	var y := 0.0
	var px := 0.0
	var s := 0.0
	for v in x:
		y = a * (y + v - px)
		px = v
		s += y * y
	return 10.0 * log(s / maxf(1.0, x.size()) + 1e-12) / log(10.0)


func playlist_checks() -> void:
	var bs := BandSound.new()
	check("the playlist: four tunes in turn (God Save the King an extra in the files)", BandSound.ORDER.size() == 4 and BandSound.TUNES.has("godsave") and not BandSound.ORDER.has("godsave"), str(BandSound.ORDER))
	# never the same tune twice in a row, whatever the situation; never the slow air while fighting
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cur: String = BandSound.ORDER[0]
	var prev := ""
	var twice := 0
	var air_fight := 0
	var seen := {}
	for i in 4000:
		var f := rng.randf() < 0.3
		var idle := rng.randf() < 0.2
		var nx := BandSound.next_tune(cur, f, idle, prev)
		if nx == cur:
			twice += 1
		if f and String(BandSound.TUNES[nx]["kind"]) == "air":
			air_fight += 1
		seen[nx] = true
		prev = cur
		cur = nx
	check("never the same tune twice in a row (4000 picks, any situation)", twice == 0, "%d repeats" % twice)
	check("fighting: never the slow air next", air_fight == 0, "%d" % air_fight)
	check("every tune of the list comes round", seen.size() == BandSound.ORDER.size(), str(seen.keys()))
	check("in turn when marching: Grenadiers, Scotland, Garry Owen, the Minstrel Boy, Grenadiers", BandSound.next_tune("grenadiers", false, false) == "scotland" and BandSound.next_tune("scotland", false, false) == "garryowen" and BandSound.next_tune("garryowen", false, false) == "minstrel" and BandSound.next_tune("minstrel", false, false) == "grenadiers")
	check("fighting after Garry Owen: the Grenadiers (the slow air skipped)", BandSound.next_tune("garryowen", true, false) == "grenadiers")
	check("standing idle a while: the slow air may come next", BandSound.next_tune("grenadiers", false, true) == "minstrel" and BandSound.next_tune("minstrel", false, true) != "minstrel")
	# a playlist moving on: at a tune's end the next starts where the last ended (the roll-off links them)
	var pl := BandSound.Playlist.new()
	var now := Time.get_ticks_msec()
	pl.tune = "grenadiers"
	pl.start = now - int(BandSound.length("grenadiers") * 1000.0) - 2000
	pl.still_since = now
	bs.advance(pl)
	check("a playlist at a tune's end goes on to the next, its clock carried on (no gap, no restart)", pl.tune == "scotland" and absf(bs.pos(pl) - 2.0) < 0.05, "%s at %.2f s" % [pl.tune, bs.pos(pl)])
	# fighting starts during the slow air: it is cut short at its next phrase end, faded, then a march
	pl.tune = "minstrel"
	pl.prev = "garryowen"
	pl.cut = -1.0
	pl.start = Time.get_ticks_msec() - 20000
	pl.fighting = true
	bs.advance(pl)
	var ph: Array = BandSound.TUNES["minstrel"]["phrases"]
	check("fighting during the slow air: it stops at its next phrase end (not mid-phrase)", pl.tune == "minstrel" and ph.has(pl.cut) and pl.cut > 20.0, "cut at %.2f" % pl.cut)
	pl.start = Time.get_ticks_msec() - int((pl.cut - 0.05) * 1000.0)
	check("... fading over its last moment (no click)", bs.env_db(pl) < -20.0, "%.1f dB" % bs.env_db(pl))
	pl.start = Time.get_ticks_msec() - int((pl.cut + 0.3) * 1000.0)
	bs.advance(pl)
	check("... then a march or the quickstep", pl.tune != "minstrel" and String(BandSound.TUNES[pl.tune]["kind"]) != "air" and pl.cut < 0.0 and absf(bs.pos(pl) - 0.3) < 0.05, "%s at %.2f" % [pl.tune, bs.pos(pl)])
	bs.free()


func _run() -> void:
	# 1. the files
	for t in BandSound.TUNES:
		var n := 0
		for ins in BandSound.PARTS:
			for so in [false, true]:
				var f := BandSound.file(t, ins, so)
				if not ResourceLoader.exists("res://assets/audio/%s.ogg" % f):
					check("%s exists" % f, false)
					continue
				n += 1
				var st := stream(f)
				check("%s is exactly the tune's length" % f, absf(st.get_length() - BandSound.length(t)) < 0.003, "%.4f s (%.4f)" % [st.get_length(), BandSound.length(t)])
		check("%s: six files (drums, fife, pipes; background and solo)" % t, n == 6)
		var ph: Array = BandSound.TUNES[t]["phrases"]
		check("%s: its phrase ends inside the tune, in order" % t, not ph.is_empty() and ph.all(func(v) -> bool: return float(v) > float(BandSound.TUNES[t]["roll"]) and float(v) < BandSound.length(t)))
	playlist_checks()

	# the engine's mixer: a bus with a capture on it
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "BandTest")
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 8.0
	AudioServer.add_bus_effect(bus, cap)
	var probe := AudioStreamPlayer.new()
	probe.bus = "BandTest"
	probe.stream = stream(BandSound.file("scotland", "drums", false))
	root.add_child(probe)
	probe.play(10.0)
	await create_timer(0.3).timeout
	var mixing := cap.get_frames_available() > 0
	probe.stop()
	cap.clear_buffer()
	if not mixing:
		print("NOTE the audio driver mixes nothing here (run with --write-movie, see the top of this file): the sound checks are skipped")
	else:
		var p := AudioStreamPlayer.new()
		p.bus = "BandTest"
		root.add_child(p)
		# 2. loudness: each part alone, mid-tune (6 s), every tune but the slow air (its drum is a muffled drum)
		for t in ["grenadiers", "scotland", "garryowen", "godsave"]:
			var lv := {}
			for ins in BandSound.PARTS:
				for so in [false, true]:
					p.stream = stream(BandSound.file(t, ins, so))
					cap.clear_buffer()
					p.play(float(BandSound.TUNES[t]["roll"]) + 6.0)
					await create_timer(6.0).timeout
					var fr := cap.get_buffer(cap.get_frames_available())
					p.stop()
					lv["%s%s" % [ins, "_lead" if so else ""]] = loud(mono(fr))
			var on := [float(lv["drums"]), float(lv["fife"]), float(lv["pipes"])]
			var spread: float = on.max() - on.min()
			check("%s: the three background parts alone within %.0f dB of each other (the drummer clearly heard)" % [t, LOUD_SPREAD], spread <= LOUD_SPREAD, "drums %.1f fife %.1f pipes %.1f" % on)
			check("%s: each solo part louder than its background part (the soloist forward)" % t, ["drums", "fife", "pipes"].all(func(k) -> bool: return float(lv[k + "_lead"]) > float(lv[k]) + 2.0), str(lv))
		# 3. from one tune to the next, as BandSound does it (the stream changes at the playlist's boundary)
		for i in BandSound.ORDER.size():
			var a: String = BandSound.ORDER[i]
			var b: String = BandSound.ORDER[(i + 1) % BandSound.ORDER.size()]
			for ins in BandSound.PARTS:
				p.stream = stream(BandSound.file(a, ins, false))
				cap.clear_buffer()
				p.play(BandSound.length(a) - 1.0)
				await create_timer(1.0).timeout
				p.stop()
				p.stream = stream(BandSound.file(b, ins, false))
				p.play(0.0)
				await create_timer(1.2).timeout
				var fr := cap.get_buffer(cap.get_frames_available())
				p.stop()
				var x := mono(fr)
				var steps: Array = []
				var big := 0.0
				for k in range(882, x.size()):
					var d := absf(x[k] - x[k - 1])
					steps.append(d)
					big = maxf(big, d)
				steps.sort()
				var p99: float = steps[int(steps.size() * 0.995)] if steps.size() > 0 else 0.0
				var tail_end := 0.0
				var m := 0
				for k in range(maxi(0, int(44100 * 0.9) - 2205), mini(x.size(), int(44100 * 0.9))):
					tail_end += x[k] * x[k]
					m += 1
				tail_end = sqrt(tail_end / maxf(1, m))
				check("%s -> %s (%s): no click at the change" % [a, b, ins], big <= p99 * 4.0 + 0.02, "largest step %.4f, 99.5%% %.4f" % [big, p99])
				check("%s's %s ends quietly (its tail) before the next tune" % [a, ins], tail_end < 0.02, "RMS %.4f" % tail_end)
		# the drummer's roll-off starts the next tune (sound in its first second)
		for t in BandSound.ORDER:
			p.stream = stream(BandSound.file(t, "drums", false))
			cap.clear_buffer()
			p.play(0.0)
			await create_timer(1.0).timeout
			var fr := cap.get_buffer(cap.get_frames_available())
			p.stop()
			check("%s begins with the drums' roll-off" % t, loud(mono(fr)) > -45.0, "%.1f dB" % loud(mono(fr)))
		# 4. in step: two parts started where the band's clock is stay together
		var a2 := AudioStreamPlayer.new()
		var b2 := AudioStreamPlayer.new()
		a2.stream = stream(BandSound.file("grenadiers", "drums", false))
		b2.stream = stream(BandSound.file("grenadiers", "pipes", true))
		a2.bus = "BandTest"
		b2.bus = "BandTest"
		root.add_child(a2)
		root.add_child(b2)
		var clock := [10.0]
		a2.play(clock[0])
		for k in 8:
			await process_frame
			clock[0] += root.get_process_delta_time()
		b2.play(clock[0])                        # (a part joining later, as a solo does)
		var worst := 0.0
		var worst_clock := 0.0
		for k in 90:
			await process_frame
			clock[0] += root.get_process_delta_time()
			worst = maxf(worst, absf(a2.get_playback_position() - b2.get_playback_position()))
			worst_clock = maxf(worst_clock, absf(a2.get_playback_position() - clock[0]))
		check("two parts stay in step", worst < 0.05, "worst %.1f ms apart" % (worst * 1000.0))
		check("and with the band's clock (BandSound puts a part back past 80 ms)", worst_clock < 0.08, "worst %.1f ms" % (worst_clock * 1000.0))
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
