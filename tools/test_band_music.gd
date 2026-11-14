## THE MARCHING BAND's MUSIC (jobs band-music and band-music-v2, docs/band_music.md): the six loops BandSound plays
## (assets/audio/band/, made by tools/audio/make_band_music.py) are one tune in one key and tempo, so they must:
##  - all be exactly BandSound.PHRASE long (16 bars of 4/4 at 110 beats a minute: 1,540,800 samples), the length the engine wraps its clock at;
##  - loop without a click: played through the engine's own mixer across the loop point (seeked a second before the end),
##    the music goes on after the end and no step between two samples is bigger than the music's own (a jump would);
##  - stay in step: two parts started at the shared clock's place stay within a few ms of each other and of the clock,
##    over the loop point too.
##   xvfb-run -a godot --rendering-driver opengl3 --write-movie /tmp/band_test/out.png --fixed-fps 30 --resolution 320x180 \
##       --script res://tools/test_band_music.gd        (the movie writer mixes the sound: every check runs)
##   godot --headless --fixed-fps 30 --script res://tools/test_band_music.gd   (no sound is mixed headless: the length
##       checks run, the loop and sync checks are skipped with a note)
extends SceneTree
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func stream(f: String) -> AudioStream:
	var st: AudioStream = (load("res://assets/audio/%s.ogg" % f) as AudioStream).duplicate()
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	return st


func _run() -> void:
	check("the loop is 16 bars of 4/4 at 110 a minute (109.91: a whole number of drone cycles)", absf(BandSound.BPM - 110.0) < 0.15 and is_equal_approx(BandSound.PHRASE, BandSound.BARS * 4 * 60.0 / BandSound.BPM) and BandSound.BARS == 16, "%.4f s at %.3f" % [BandSound.PHRASE, BandSound.BPM])
	check("the unit's phrase entry agrees", absf(float(Defs.MARCHING_BAND["phrase"]) - BandSound.PHRASE) < 0.01)
	var files: Array = []
	for ins in BandSound.PARTS:
		files.append_array(BandSound.PARTS[ins])
	check("six files: an always-on and a solo loop for drums, fife and pipes", files.size() == 6, str(files))
	for f in files:
		var st := stream(f)
		check("%s is exactly one phrase long" % f, absf(st.get_length() - BandSound.PHRASE) < 0.002, "%.4f s" % st.get_length())

	# the engine's mixer: a bus with a capture on it
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "BandTest")
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 4.0
	AudioServer.add_bus_effect(bus, cap)
	var probe := AudioStreamPlayer.new()
	probe.bus = "BandTest"
	probe.stream = stream("band/drums")
	root.add_child(probe)
	probe.play(0.0)
	await create_timer(0.3).timeout
	var mixing := cap.get_frames_available() > 0
	probe.stop()
	cap.clear_buffer()
	if not mixing:
		print("NOTE the audio driver mixes nothing here (run with --write-movie, see the top of this file): the loop and sync checks are skipped")
	else:
		# 1. across the loop point: every file, a second before its end to a second after its start
		for f in files:
			var p := AudioStreamPlayer.new()
			p.bus = "BandTest"
			p.stream = stream(f)
			root.add_child(p)
			cap.clear_buffer()
			p.play(BandSound.PHRASE - 1.0)
			await create_timer(2.0).timeout
			var fr := cap.get_buffer(cap.get_frames_available())
			p.stop()
			p.queue_free()
			var n := fr.size()
			var win := 441                       # 10 ms windows (at 44.1 kHz)
			var skip := 882                      # (the first 20 ms: playback starting mid-wave is a step of its own)
			var after := 0.0                     # the RMS of the second after the loop point (the music goes on)
			var na := 0
			var steps: Array = []
			var big := 0.0
			var seam := n - int(44100.0 * 1.0) if n > 44100 else n / 2
			for i in range(maxi(seam + 2205, 0), n):
				after += fr[i].x * fr[i].x
				na += 1
			after = sqrt(after / maxf(na, 1))
			for i in range(skip, n):
				var d := absf(fr[i].x - fr[i - 1].x)
				steps.append(d)
				big = maxf(big, d)
			steps.sort()
			var p99: float = steps[int(steps.size() * 0.995)] if steps.size() > 0 else 0.0
			# (rests in the score are fine: the snare rests in each phrase's last bar, so "never quiet" is not asked;
			# what is asked is that the loop goes on playing after its end, without a click)
			check("%s plays on through its loop point" % f, n > 44100 and after > 0.003, "%d frames, the second after it RMS %.4f" % [n, after])
			check("%s: no click at the loop point (no jump past the music's own)" % f, big <= p99 * 4.0 + 0.02, "largest step %.4f, 99.5%% %.4f" % [big, p99])
		# 2. in step: two parts started where the shared clock is stay together, over the loop point
		var a := AudioStreamPlayer.new()
		var b := AudioStreamPlayer.new()
		a.stream = stream("band/drums")
		b.stream = stream("band/pipes_lead")
		a.bus = "BandTest"
		b.bus = "BandTest"
		root.add_child(a)
		root.add_child(b)
		# the shared clock in the mixer's own time (frames of the fixed frame rate: in --write-movie the sound is mixed
		# exactly one frame's worth a frame, whatever the real time), starting 1.5 s before the loop point
		var clock := [BandSound.PHRASE - 1.5]
		a.play(clock[0])
		for k in 8:
			await process_frame
			clock[0] = fmod(clock[0] + root.get_process_delta_time(), BandSound.PHRASE)
		b.play(clock[0])                        # (a part joining later, as a solo does)
		var worst := 0.0
		var worst_clock := 0.0
		for k in 90:
			await process_frame
			clock[0] = fmod(clock[0] + root.get_process_delta_time(), BandSound.PHRASE)
			var pa := a.get_playback_position()
			var pb := b.get_playback_position()
			var d := absf(pa - pb)
			d = minf(d, BandSound.PHRASE - d)
			worst = maxf(worst, d)
			var dc := absf(pa - clock[0])
			worst_clock = maxf(worst_clock, minf(dc, BandSound.PHRASE - dc))
		check("two parts stay in step across the loop point", worst < 0.05, "worst %.1f ms apart" % (worst * 1000.0))
		check("and with the shared clock (BandSound puts a part back past 80 ms)", worst_clock < 0.08, "worst %.1f ms" % (worst_clock * 1000.0))
		a.queue_free()
		b.queue_free()
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
