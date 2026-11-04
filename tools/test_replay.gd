extends SceneTree
## Replays (docs/replays.md), end to end in one process:
##   godot --headless --fixed-fps 30 --script res://tools/test_replay.gd [-- secs:<n> map:<id> seed:<n> spawn:<n> a:<faction> b:<faction>]
## Two Hard computers play for `secs` game seconds while the replay is recorded (as every match is); the true state of
## every unit is kept at each recorded picture. Then the replay is played back (Main.start_replay: the viewer with its
## HUD and bar) and checked: at several times the puppet's units match the match (kind, team, place within a few px,
## health), seeking backwards and forwards leaves nothing stale (units, bodies, effects), pause and speed move the
## clock as they should, a file cut short (a crash) still plays to its last whole chunk, and a replay stamped with
## another version (other field lists, a unit kind that is gone) shows the warning and still plays. Prints the size
## and the recorder's cost. spawn:N adds N Musketeers and N Raptors at 30 s (a big battle).
## rec:full|light|off: Settings REPLAY RECORDING for the match (default full). LIGHT: the header says 2 pictures a
## second, the pictures come 2 a second, everything above still matches, and the effects carry their times. OFF: no
## recorder and no replay file. Every run also plays 10 s at 1x from the middle and measures how far each unit is
## drawn from where it really was at that moment ("GLIDE"; every tick's true places kept in the match), the price of
## fewer pictures.
## rec:mixed: a MIXED replay (docs/replay_mixed.md: the commands and a keyframe every 10 s). It is played back by the real
## game from its keyframes; it measures the DRIFT (how far units stray from where they really were) over 10 s without
## the keyframes' correction and with it, the seek time, and checks the commands were given again.
var main: Node
var t := 0.0
var g: Game
var map := "hollowfen"
var seed_ := 4242
var secs := 150.0
var spawn := 0
var fa := "crown"
var fb := "brood"
var stage := "play"
var truth: Array = []            # one per recorded picture: {"clk", "u": {id: [kind, team, pos, hp]}}
var rec_path := ""
var rec_line := ""
var results := {}
var failed := 0
var _n_seen := 0
var _wait := 0
var _spawned := false
var _bench := {}
var _spawned_units: Array = []
var _march_n := -1
var _marks: Array = [120.0, 300.0, 600.0, 1200.0]
var _mark_clk := 0.0
var _mark_us := 0
var _mark_n := 0
var rec_mode := "full"
var _fine: Array = []           # [clock, {id: place}] every game tick in the GLIDE window (the true places)
var _fine_from := 0.0
var _gl_d: Array = []           # GLIDE: each unit's distance from its true place, each frame
var _gl_frames := 0
var _replays_before: Array = []     # (the replay files before the match: OFF adds none)
var _mtruth: Array = []         # MIXED: [clock, {id: [kind, team, place, health]}] twice a second (the ids the keyframes gave)
var _mt_n := -1


## The match as it is the moment a picture is taken.
func _capture() -> void:
	var u := {}
	for x in g.units:
		if is_instance_valid(x) and not x.dead and x.net_id != 0:
			u[x.net_id] = [x.kind, x.team, x.position.snapped(Vector2(0.1, 0.1)), snappedf(x.hp, 0.1)]
	truth.append({"clk": snappedf(g.rec.last_clk, 0.01), "u": u, "n": g.units.size()})     # (a picture's clock is to 0.01 s)


## spawn:N: N soldiers a side in the middle of the map (a big battle's worth of units), marching about (_march),
## topped up to N every minute (the fight there goes on all match).
func _spawn() -> void:
	_spawned_units = _spawned_units.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var mid := Vector2(Game.W, Game.H) * Game.T * 0.5
	for tm in 2:
		var hall: Building = null
		for b in g.buildings:
			if b.team == tm and b.kind == g.faction_hall(tm):
				hall = b
		var c: Vector2 = mid.lerp(hall.center(), 0.25) if hall else mid
		var have := _spawned_units.filter(func(u) -> bool: return u.team == tm).size()
		for i in maxi(0, spawn - have):
			var k := "musketeer" if g.faction_of(tm) == "crown" else ("raptor" if g.faction_of(tm) == "brood" else "windup_soldier")
			var cell := g.nearest_free(g.cell_of(c + Vector2.from_angle(randf() * TAU) * randf_range(80, 400)), 12)
			_spawned_units.append(g._add_unit(k, tm, g.cell_center(cell)))


## Every 4 s half the added soldiers walk somewhere else (the rest stand or fight where they are).
func _march() -> void:
	g.input_cmd = true           # (as a player's orders: a mixed replay records them as commands)
	for u in _spawned_units:
		if is_instance_valid(u) and not u.dead and randf() < 0.5:
			var to := g.cell_center(g.nearest_free(g.cell_of(u.position + Vector2.from_angle(randf() * TAU) * 300.0), 10))
			u.give({"o": "move", "p": to})
	g.input_cmd = false


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("secs:"):
			secs = float(a.substr(5))
		elif a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("spawn:"):
			spawn = int(a.substr(6))
		elif a.begins_with("a:"):
			fa = a.substr(2)
		elif a.begins_with("b:"):
			fb = a.substr(2)
		elif a.begins_with("rec:"):
			rec_mode = a.substr(4)


func check(name: String, ok: bool, detail := "") -> void:
	results[name] = ok
	if not ok:
		failed += 1
	print("CHECK %s %s %s" % [name, "OK" if ok else "FAILED", detail])


func _process(delta: float) -> bool:
	t += delta
	match stage:
		"play":
			return _play()
		"watch":
			return _watch()
		"watch_mixed":
			return _watch_mixed()
	return false


# ------------------------------------------------------------------ the match, recorded

func _play() -> bool:
	if t > 0.2 and main.game == null:
		seed(seed_)
		Settings.replay_rec = rec_mode      # (not saved: the player's own setting stays)
		ReplayFile.ensure_dir()
		_replays_before = Array(DirAccess.get_files_at(ReplayFile.DIR))
		_fine_from = maxf(secs * 0.5 - 1.0, 5.0)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": fa, "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": fb, "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	paused = false
	if rec_mode == "off":
		if g.clock < 20.0:
			return false
		check("off_no_recorder", g.rec == null, "REPLAY RECORDING OFF: recorder %s" % str(g.rec))
		main._to_menu()
		var new_files := Array(DirAccess.get_files_at(ReplayFile.DIR)).filter(func(f: String) -> bool: return not _replays_before.has(f))
		check("off_no_replay", new_files.is_empty(), "files written: %s" % str(new_files))
		check("off_online_host_records", ReplayRecorder.rate_for("off", true) == ReplayRecorder.RATE_LIGHT and ReplayRecorder.rate_for("off", false) == 0.0
			and ReplayRecorder.rate_for("light", false) == ReplayRecorder.RATE_LIGHT and ReplayRecorder.rate_for("full", true) == ReplayRecorder.RATE,
			"online host with OFF records at LIGHT, a skirmish not at all")
		print("ALL OK" if failed == 0 else "SOME FAILED (%d)" % failed)
		quit(0 if failed == 0 else 1)
		return true
	if g.rec == null:
		check("recorder_started", false, "no recorder on a skirmish")
		quit(1)
		return true
	if g.clock >= _fine_from and g.clock <= _fine_from + 12.0 and (_fine.is_empty() or g.clock > float(_fine.back()[0]) + 0.001):
		var fu := {}
		for x in g.units:
			if is_instance_valid(x) and not x.dead and x.net_id != 0:
				fu[x.net_id] = x.position
		_fine.append([g.clock, fu])
	if rec_mode == "mixed" and int(g.clock * 2.0) != _mt_n:
		_mt_n = int(g.clock * 2.0)
		var mu := {}
		for x in g.units:
			if is_instance_valid(x) and not x.dead and x.net_id != 0 and not x.off_field:
				mu[x.net_id] = [x.kind, x.team, x.position, x.hp]
		_mtruth.append([g.clock, mu])
	if spawn > 0 and not _spawned and g.clock >= 30.0:
		_spawned = true
		_spawn()
	if _spawned and int(g.clock / 4.0) != _march_n:
		_march_n = int(g.clock / 4.0)
		_march()
		if _march_n % 15 == 0:
			_spawn()
	var rec: ReplayRecorder = g.rec
	if _marks.size() > 0 and g.clock >= float(_marks[0]):
		var at: float = _marks.pop_front()
		var secs_w := maxf(g.clock - _mark_clk, 1.0)
		print("SIZE_AT %s: file %d KB (+ %d KB this chunk), %d units %d buildings, recording %.2f ms per match second since the last mark, %.1f pictures a second" % [
			ReplayPlayer.clock_text(at), (rec.bytes_file + ReplayFile.pack_frames(rec.frames).size()) / 1024, 0, g.units.size(), g.buildings.size(),
			(rec.cost_us - _mark_us) / 1000.0 / secs_w, (rec.n_frames - _mark_n) / secs_w])
		_mark_clk = g.clock
		_mark_us = rec.cost_us
		_mark_n = rec.n_frames
	if not rec.recorded.is_connected(_capture):
		rec.recorded.connect(_capture)
	if g.clock >= secs or g.over:
		rec_line = rec.cost_line()
		print("RECORDER %s %s" % [rec_mode.to_upper(), rec_line])
		if OS.get_cmdline_user_args().has("recordonly"):
			print("RECORDER %s %s" % [rec_mode.to_upper(), rec.cost_line()])
			rec.finish(-1)
			quit(0)
			return true
		if rec_mode == "mixed":
			check("mixed_recorder", rec is ReplayMixRecorder and int(rec.header.get("format", 0)) == ReplayMixRecorder.FORMAT_MIXED and rec.n_keys >= int(g.clock / ReplayRecorder.KEY_SECS),
				"%d keyframes in %.0f s, %d commands" % [rec.n_keys, g.clock, (rec as ReplayMixRecorder).n_cmds])
			if spawn > 0:
				check("mixed_commands", (rec as ReplayMixRecorder).n_cmds > 10, "%d commands recorded (the marching orders)" % (rec as ReplayMixRecorder).n_cmds)
			rec_path = rec.finish(g.winner if g.over else -1)
			check("replay_written", rec_path != "" and FileAccess.file_exists(rec_path), rec_path)
			var msize := FileAccess.get_file_as_bytes(rec_path).size()
			print("SIZE %.0f s of match: %d KB (%.1f KB a minute), %d units at the end" % [g.clock, msize / 1024, msize / 1024.0 / g.clock * 60.0, g.units.size()])
			var mm := ReplayFile.read_meta(rec_path)
			check("replay_listed", ReplayFile.list().any(func(x: Dictionary) -> bool: return String(x["path"]) == rec_path) and String(mm.get("result", "")) != "",
				"result %s, %s" % [mm.get("result"), ReplayPlayer.clock_text(float(mm.get("len", 0)))])
			stage = "watch_mixed"
			main._to_menu()
			main.start_replay(rec_path)
			_wait = 0
			return false
		var want_rate := ReplayRecorder.RATE_LIGHT if rec_mode == "light" else ReplayRecorder.RATE
		var pics := rec.n_frames / maxf(g.clock - float(rec.header.get("t0", 0.0)), 1.0)
		check("rate_in_header", absf(float(rec.header.get("rate", 0.0)) - want_rate) < 0.001 and pics <= want_rate + 0.2 and pics >= want_rate * 0.55,
			"%s: header %.1f a second, %.2f pictures a second taken" % [rec_mode, float(rec.header.get("rate", 0.0)), pics])
		rec_path = rec.finish(g.winner if g.over else -1)
		check("replay_written", rec_path != "" and FileAccess.file_exists(rec_path), rec_path)
		var size := FileAccess.get_file_as_bytes(rec_path).size()
		print("SIZE %.0f s of match: %d KB (%.1f KB a minute), %d units at the end" % [g.clock, size / 1024, size / 1024.0 / g.clock * 60.0, g.units.size()])
		var m := ReplayFile.read_meta(rec_path)
		check("replay_listed", ReplayFile.list().any(func(x: Dictionary) -> bool: return String(x["path"]) == rec_path) and String(m.get("result", "")) != "",
			"result %s, %d players, %s" % [m.get("result"), (m.get("players", []) as Array).size(), ReplayPlayer.clock_text(float(m.get("len", 0)))])
		_fxt_check()
		_make_variants()
		stage = "watch"
		main._to_menu()
		main.start_replay(rec_path)
		_wait = 0
	return false


# ------------------------------------------------------------------ playback

var _wstep := 0
var _wt := 0.0
var _p0 := 0.0
var _crash_path := ""
var _old_path := ""


func _watch() -> bool:
	_wait += 1
	if _wait < 3:
		return false
	g = main.game
	var rp: ReplayPlayer = g.replay if g != null else null
	match _wstep:
		0:
			check("viewer_open", rp != null and g.puppet and g.demo and g.spectator != null, "length %s, %d chunks" % [ReplayPlayer.clock_text(rp.length), rp.chunks.size()])
			var ks := [truth.size() / 5, truth.size() / 2, truth.size() * 4 / 5, truth.size() / 5, truth.size() - 3, 2]
			var worst := 0.0
			var bad := []
			var stale := 0
			var t0 := Time.get_ticks_usec()
			for k in ks:
				var r := _compare_at(rp, k)
				worst = maxf(worst, float(r["worst"]))
				stale += int(r["stale"])
				if not (r["bad"] as Array).is_empty():
					bad.append([k, r["bad"].slice(0, 3)])
			var seek_ms := (Time.get_ticks_usec() - t0) / 1000.0 / ks.size()
			check("units_match_the_match", bad.is_empty() and worst <= 3.0, "at %d times (back and forth): worst place %.2f px, mismatches %s" % [ks.size(), worst, str(bad)])
			check("seek_leaves_nothing_stale", stale == 0, "stale entities %d; a seek takes %.1f ms" % [stale, seek_ms])
			_bench["seek_ms"] = seek_ms
			# pause: the clock stands still
			rp.seek(float(truth[truth.size() / 2]["clk"]))
			rp.set_playing(false)
			_p0 = rp.play_t
			_wt = 0.0
			_wstep = 1
		1:
			_wt += 1.0
			if _wt >= 20.0:
				check("pause_holds", absf(rp.play_t - _p0) < 0.001 and g.world.process_mode == Node.PROCESS_MODE_DISABLED, "clock %.2f -> %.2f" % [_p0, rp.play_t])
				rp.set_playing(true)
				rp.set_speed(4.0)
				_p0 = rp.play_t
				_wt = 0.0
				_wstep = 2
		2:
			_wt += 1.0
			if _wt >= 30.0:
				var adv := rp.play_t - _p0
				check("speed_4x", adv > 3.0 and adv < 5.0, "30 frames at 4x moved the clock %.2f s (1 s at 1x)" % adv)
				var r := _compare_now(rp)
				check("units_match_while_playing", (r["bad"] as Array).is_empty() and float(r["worst"]) <= 4.0, "at %s: worst place %.2f px, mismatches %s" % [ReplayPlayer.clock_text(rp.play_t), r["worst"], str(r["bad"].slice(0, 3))])
				rp.set_speed(1.0)
				_wstep = 10
		10:
			# GLIDE: 10 s at 1x from the middle; each frame every unit against its true place at that moment
			rp.seek(_fine_from + 0.5)
			rp.set_speed(1.0)
			rp.set_playing(true)
			_gl_frames = 0
			_wstep = 11
		11:
			_gl_frames += 1
			_glide_frame(rp)
			if _gl_frames >= 2000 or rp.play_t >= _fine_from + 10.5:
				_gl_d.sort()
				var n := _gl_d.size()
				var mean := 0.0
				for d in _gl_d:
					mean += float(d)
				mean /= maxf(n, 1.0)
				var p95: float = _gl_d[int(n * 0.95)] if n > 0 else 0.0
				var p99: float = _gl_d[int(n * 0.99)] if n > 0 else 0.0
				var mx: float = _gl_d[n - 1] if n > 0 else 0.0
				print("GLIDE %s: %d unit-frames over %.1f s, off its true place: mean %.2f px, 95%% under %.1f, 99%% under %.1f, worst %.1f" % [
					rec_mode.to_upper(), n, rp.play_t - (_fine_from + 0.5), mean, p95, p99, mx])
				_bench["glide"] = [snappedf(mean, 0.01), snappedf(p95, 0.1), snappedf(p99, 0.1), snappedf(mx, 0.1)]
				check("glide_close", n > 1000 and p95 <= 12.0, "95%% of units within %.1f px of their true place" % p95)
				_wstep = 3
		3:
			# fog: one player's view hides the other's units out of sight; all vision shows them all
			g.spectator.set_mode("free", 0, true)
			g.refresh_fog()
			var hidden := g.units.filter(func(u: Unit) -> bool: return u.team == 1 and not u.visible).size()
			g.spectator.set_mode("all", 0, true)
			g.refresh_fog()
			var hidden_all := g.units.filter(func(u: Unit) -> bool: return not u.visible and not u.off_field).size()
			check("fog_switch", hidden > 0 and hidden_all == 0, "P1's view hides %d of P2's units, all vision hides %d" % [hidden, hidden_all])
			g.spectator.set_mode("free", 1, true)
			g.refresh_fog()
			var hidden2 := g.units.filter(func(u: Unit) -> bool: return u.team == 0 and not u.visible).size()
			g.spectator.set_mode("all", 0, true)
			g.refresh_fog()
			check("fog_switch_p2", hidden2 > 0, "P2's view hides %d of P1's units" % hidden2)
			# the end: the clock stops there, PLAY starts it again from the beginning
			rp.seek(rp.length)
			check("seek_to_end", rp.at_end and absf(rp.play_t - rp.length) < 0.01, "at %s of %s" % [ReplayPlayer.clock_text(rp.play_t), ReplayPlayer.clock_text(rp.length)])
			# selection: a unit can be selected and read, never commanded
			var u0: Unit = g.units[0] if not g.units.is_empty() else null
			if u0:
				g.selection = [u0]
				check("select_read_only", g.controlled_team() == -1 and g.selected_units().is_empty(), "%s selected, orders go nowhere" % u0.kind)
			main._to_replays()
			_wait = 0
			_wstep = 4
		4:
			# a file cut short (the game closed mid-match): plays to its last whole chunk
			main.start_replay(_crash_path)
			_wait = 0
			_wstep = 5
		5:
			var ok := rp != null and rp.length > 10.0 and rp.footer.is_empty()
			if ok:
				rp.seek(rp.length - 1.0)
				var k := _frame_at(rp.play_t)
				ok = k >= 0 and g.units.size() > 0
			check("crash_keeps_most", ok, "cut file: %s playable of %s" % [ReplayPlayer.clock_text(rp.length if rp else 0.0), ReplayPlayer.clock_text(float(truth.back()["clk"]))])
			main._to_replays()
			main.start_replay(_old_path)
			_wait = 0
			_wstep = 6
		6:
			var note_ok := rp != null and rp.version_note.contains("9.9.1")
			var r := _compare_at(rp, truth.size() / 2, true) if rp else {"bad": ["no viewer"], "worst": 99.0}
			var ph := 0
			for u in g.units:
				if u.modulate.a < 0.9:
					ph += 1
			check("old_version_plays", note_ok and (r["bad"] as Array).is_empty() and float(r["worst"]) <= 3.0 and ph > 0,
				"note '%s', worst place %.2f px, %d drawn as a placeholder, mismatches %s" % [rp.version_note if rp else "", r["worst"], ph, str(r["bad"].slice(0, 3))])
			main._to_replays()
			_wstep = 7
		7:
			for p in [_crash_path, _old_path]:
				ReplayFile.delete(p)
			print("BENCH %s" % str(_bench))
			print("ALL OK" if failed == 0 else "SOME FAILED (%d)" % failed)
			quit(0 if failed == 0 else 1)
			return true
	return false


## GLIDE: the true places at the tick nearest the shown clock; units that jumped (boarding, leaving: 40 px in a tick
## around it) are left out.
func _glide_frame(rp: ReplayPlayer) -> void:
	var best := -1
	var bd := 1e9
	for i in _fine.size():
		var d := absf(float(_fine[i][0]) - rp.play_t)
		if d < bd:
			bd = d
			best = i
	if best <= 0 or best >= _fine.size() - 1 or bd > 0.02:
		return
	var now: Dictionary = _fine[best][1]
	var before: Dictionary = _fine[best - 1][1]
	var after: Dictionary = _fine[best + 1][1]
	for id in now:
		var p: Vector2 = now[id]
		if not before.has(id) or not after.has(id) or p.distance_to(before[id]) > 40.0 or p.distance_to(after[id]) > 40.0:
			continue
		var u = rp.by_id.get(id)
		if not is_instance_valid(u) or not (u is Unit) or u.dead:
			continue
		_gl_d.append(u.position.distance_to(p))


## Every picture in the file carries its effects' times (fxt), one byte each.
func _fxt_check() -> void:
	var d := ReplayFile.read(rec_path)
	var with_fx := 0
	var timed := 0
	var spread := 0
	for c in d.get("chunks", []):
		for fb in ReplayFile.unpack_frames(c["data"]):
			var m = bytes_to_var(fb)
			if not (m is Dictionary) or not m.has("fx"):
				continue
			with_fx += 1
			var ft = m.get("fxt")
			if ft is PackedByteArray and (ft as PackedByteArray).size() == (m["fx"] as Array).size():
				timed += 1
				for b in ft:
					if int(b) > 0:
						spread += 1
	check("effects_timed", with_fx > 0 and timed == with_fx and spread > 0, "%d pictures with effects, %d with their times, %d effects before their picture" % [with_fx, timed, spread])


## The recorded picture with this clock (or the last one before it).
func _frame_at(clk: float) -> int:
	var k := -1
	for i in truth.size():
		if float(truth[i]["clk"]) <= clk:
			k = i
	return k


## Seek to picture k and compare: every unit of picture k+1 (the one ahead, as shown) is there with its kind, team and
## health, at picture k's place; nothing else is.
func _compare_at(rp: ReplayPlayer, k: int, old := false) -> Dictionary:
	k = clampi(k, 0, truth.size() - 2)
	rp.seek(float(truth[k]["clk"]))
	return _compare(rp, k, 0.0, old)


func _compare_now(rp: ReplayPlayer) -> Dictionary:
	var k := _frame_at(rp.play_t)
	var span := float(truth[k + 1]["clk"]) - float(truth[k]["clk"])
	return _compare(rp, k, clampf((rp.play_t - float(truth[k]["clk"])) / maxf(span, 0.001), 0.0, 1.0), false)


func _compare(rp: ReplayPlayer, k: int, f: float, old: bool) -> Dictionary:
	var a: Dictionary = truth[k]["u"]
	var b: Dictionary = truth[k + 1]["u"]
	var bad: Array = []
	var worst := 0.0
	var seen := {}
	for id in b:
		var want: Array = b[id]
		var u = rp.by_id.get(id)
		if not is_instance_valid(u) or not (u is Unit) or u.dead:
			bad.append("missing %s #%d" % [want[0], id])
			continue
		seen[u] = true
		if u.kind != String(want[0]) and not (old and u.modulate.a < 0.9):
			bad.append("kind %s != %s" % [u.kind, want[0]])
		if u.team != int(want[1]):
			bad.append("team #%d" % id)
		if absf(u.hp - float(want[3])) > 0.11:
			bad.append("hp %s #%d %.1f != %.1f" % [u.kind, id, u.hp, float(want[3])])
			if OS.get_cmdline_user_args().has("debug"):
				var tl: Array = []
				for kk in range(maxi(0, k - 3), mini(truth.size(), k + 3)):
					tl.append([kk, snappedf(float(truth[kk]["clk"]), 0.01), truth[kk]["u"].get(id, [0, 0, null, null])[3]])
				print("DEBUG hp #%d %s at k=%d viewer %.1f fast %s truth %s dead %s" % [id, u.kind, k, u.hp, str(rp._fast.get(id)), str(tl), u.dead])
		if a.has(id):
			var p: Vector2 = (a[id][2] as Vector2).lerp(want[2], f)
			var d: float = u.position.distance_to(p)
			if (a[id][2] as Vector2).distance_to(want[2]) < 200.0:     # (not a jump: a unit leaving or boarding)
				worst = maxf(worst, d)
				if d > 4.0:
					bad.append("place %s #%d off %.1f px" % [u.kind, id, d])
					if OS.get_cmdline_user_args().has("debug"):
						var tl: Array = []
						for kk in range(maxi(0, k - 3), mini(truth.size(), k + 3)):
							tl.append([kk, snappedf(float(truth[kk]["clk"]), 0.01), truth[kk]["u"].get(id, [0, 0, null])[2]])
						print("DEBUG #%d at k=%d f=%.2f shown %s hist %s truth %s motion %s" % [id, k, f, str(u.position), str(rp.hist.get(id)), str(tl), str(rp.motion.get(id))])
	var stale := 0
	for u in g.units:
		if not seen.has(u):
			stale += 1
			bad.append("stale %s #%d" % [u.kind, u.net_id])
	# bodies and rubble left from another time: only deaths since the keyframe may lie there; no effects at all
	var t0 := 0.0
	for c in rp.chunks:
		if float(c["t0"]) <= rp.play_t + 0.001:
			t0 = float(c["t0"])
	for n in g.world.get_children():
		if n is Unit and n.dead and not n.is_queued_for_deletion() and n.died_at < t0 - 0.01:
			stale += 1
			bad.append("old body %s died %.1f" % [n.kind, n.died_at])
	for n in g.get_children():
		if n is Shot and not n.is_queued_for_deletion() and f == 0.0:
			stale += 1              # (right after a seek: it fires no shots from the pictures it runs through, none may be in the air)
			bad.append("left over shot")
	return {"bad": bad, "worst": worst, "stale": stale}


# ------------------------------------------------------------------ a crashed file and an old version's

func _make_variants() -> void:
	var bytes := FileAccess.get_file_as_bytes(rec_path)
	var d := ReplayFile.parse(bytes)
	# the crash: everything up to the middle of the chunk before the last, no footer
	var cut := bytes.size()
	var pos := 4
	var n := 0
	var chunk_starts: Array = []
	while pos < bytes.size():
		var sz := bytes.decode_u32(pos + 1)
		if bytes.decode_u8(pos) == ReplayFile.T_CHUNK:
			chunk_starts.append(pos)
		pos += ReplayFile.REC_HEAD + sz
		n += 1
	cut = int(chunk_starts[chunk_starts.size() - 2]) + 200
	_crash_path = ReplayFile.DIR + "/test_crash.hfr"
	var f := FileAccess.open(_crash_path, FileAccess.WRITE)
	f.store_buffer(bytes.slice(0, cut))
	f.close()
	# an old version: other field lists (a field gone, one that no longer exists), and a unit kind that is gone
	var h: Dictionary = (d["header"] as Dictionary).duplicate(true)
	# (another version, but one with today's maps: a built-in map's replay from before MapGen.RESIZED is refused)
	h["game_version"] = "9.9.1"
	var up: Array = NetSnapshot.UNIT_PROPS.duplicate()
	up.erase("arm")
	up.insert(5, "zz_old")
	h["lists"]["up"] = up
	var gone_kind := ""
	for id in truth[truth.size() / 2]["u"]:
		gone_kind = String(truth[truth.size() / 2]["u"][id][0])
		break
	var out := PackedByteArray(ReplayFile.MAGIC.to_ascii_buffer())
	out.append_array(ReplayFile._record(ReplayFile.T_HEAD, 0, 0, var_to_bytes(h)))
	var ai := NetSnapshot.UNIT_PROPS.find("arm")
	var ex := ReplayPlayer.new()          # (the old version wrote whole rows: the patches undone first)
	for c in d["chunks"]:
		var frames := ReplayFile.unpack_frames(c["data"])
		var nf: Array = []
		for fb in frames:
			var m: Dictionary = bytes_to_var(fb)
			ex.expand(m)
			m = m.duplicate(true)
			for row in m.get("u", []):
				if String(row[1]) == gone_kind:
					row[1] = "zz_gone_unit"
				if row.size() > NetSnapshot.U_FIXED:
					var o := NetSnapshot.U_FIXED
					var vals: Array = row.slice(o, o + NetSnapshot.UNIT_PROPS.size())
					vals.remove_at(ai)
					vals.insert(5, 12345)
					var nr: Array = row.slice(0, o) + vals + row.slice(o + NetSnapshot.UNIT_PROPS.size())
					row.clear()
					row.append_array(nr)
			nf.append(var_to_bytes(m))
		out.append_array(ReplayFile._record(ReplayFile.T_CHUNK, c["t0"], c["t1"], ReplayFile.pack_frames(nf)))
	ex.free()
	out.append_array(ReplayFile._record(ReplayFile.T_EVENTS, 0, 0, var_to_bytes(d["events"])))
	out.append_array(ReplayFile._record(ReplayFile.T_FOOT, 0, 0, var_to_bytes(d["footer"])))
	_old_path = ReplayFile.DIR + "/test_old.hfr"
	var f2 := FileAccess.open(_old_path, FileAccess.WRITE)
	f2.store_buffer(out)
	f2.close()
	check("old_layout_refused", MapGen.old_layout("hollowfen", "0.14.100") and MapGen.old_layout("greenhold", "0.9.3")
		and not MapGen.old_layout("hollowfen", MapGen.RESIZED) and not MapGen.old_layout("custom:x", "0.1.0") and not MapGen.old_layout("hollowfen", "dev"),
		"a built-in map's replay from before %s is refused" % MapGen.RESIZED)
	print("VARIANTS crash file cut at %d of %d bytes; old version with '%s' renamed to a kind that is gone" % [cut, bytes.size(), gone_kind])
	# THE OLD BROOD (0.18.0, docs/brood_replace.md): a replay written before (format 1) with a "brood" slot had the old Brood of
	# buildings: it is refused with a clear note, no crash; the experiment's "brood_new" slots then are today's Brood: they play
	var rest := bytes.slice(4 + ReplayFile.REC_HEAD + bytes.decode_u32(5))
	var found := {}
	for which in ["brood", "brood_new"]:
		var ho: Dictionary = (d["header"] as Dictionary).duplicate(true)
		ho["format"] = 1
		ho["game_version"] = "0.17.0"
		for sl in ho["cfg"]["slots"]:
			if String(sl["faction"]) == "brood":
				sl["faction"] = which
		var ob := PackedByteArray(ReplayFile.MAGIC.to_ascii_buffer())
		ob.append_array(ReplayFile._record(ReplayFile.T_HEAD, 0, 0, var_to_bytes(ho)))
		ob.append_array(rest)
		var op := ReplayFile.DIR + "/test_old_%s.hfr" % which
		var f3 := FileAccess.open(op, FileAccess.WRITE)
		f3.store_buffer(ob)
		f3.close()
		found[which] = String(ReplayPlayer.load_file(op).get("error", ""))
		DirAccess.remove_absolute(op)
	check("old_brood_refused", found["brood"] == Defs.OLD_BROOD_NOTE, "a replay with the old Brood: '%s'" % found["brood"])
	check("old_experiment_plays", found["brood_new"] == "", "a replay with the experiment's new Brood: no error ('%s')" % found["brood_new"])
	# (and a saved match: SaveGame.old_brood, main.gd says it can't be continued instead of offering CONTINUE)
	var sl_old := {"cfg": {"slots": [{"faction": "crown"}, {"faction": "brood"}]}, "version": "0.17.0"}
	var sl_exp := {"cfg": {"slots": [{"faction": "crown"}, {"faction": "brood_new"}]}, "version": "0.17.0"}
	var sl_now := {"cfg": {"slots": [{"faction": "crown"}, {"faction": "brood"}]}, "brood": Defs.BROOD_FORMAT}
	check("old_brood_save", SaveGame.old_brood(sl_old) and not SaveGame.old_brood(sl_exp) and not SaveGame.old_brood(sl_now),
		"old save with the old Brood %s, with the experiment %s, today's %s" % [SaveGame.old_brood(sl_old), SaveGame.old_brood(sl_exp), SaveGame.old_brood(sl_now)])


# ------------------------------------------------------------------ a MIXED replay played back (docs/replay_mixed.md)

var _ms := 0
var _mk: Array = []             # the keyframe times the drift runs start at
var _mrun := {}                 # the run going: {"t0", "corr", "d": {secs since start: [distances]}}
var _mres: Array = []
var _mseek: Array = []          # seek times (real ms)
var _mframes := 0


const WORKERS := ["labourer", "winder", "grub"]


## Each unit (by id) against where it really was at the truth's sample nearest the shown clock (army: no workers).
func _mixed_off(rp: ReplayMix, army := false) -> Array:
	var best := -1
	var bd := 1e9
	for i in _mtruth.size():
		var d := absf(float(_mtruth[i][0]) - g.clock)
		if d < bd:
			bd = d
			best = i
	if best < 0 or bd > 0.017:
		return []
	var tr: Dictionary = _mtruth[best][1]
	var out: Array = []
	for u in g.units:
		if not is_instance_valid(u) or u.dead or u.net_id == 0 or not tr.has(u.net_id) or u.off_field:
			continue
		if army and WORKERS.has(String(tr[u.net_id][0])):
			continue
		out.append(u.position.distance_to(tr[u.net_id][2]))
	return out


func _drift_debug() -> void:
	var best := -1
	var bd := 1e9
	for i in _mtruth.size():
		var d := absf(float(_mtruth[i][0]) - g.clock)
		if d < bd:
			bd = d
			best = i
	var tr: Dictionary = _mtruth[best][1]
	var rows: Array = []
	for u in g.units:
		if is_instance_valid(u) and not u.dead and tr.has(u.net_id):
			rows.append([u.position.distance_to(tr[u.net_id][2]), u.kind, u.team, u.order, u.work if "work" in u else "", u.carrying, u.path.size() if "path" in u else -1])
	rows.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	print("DRIFT_DEBUG at %.2f: %s" % [g.clock, str(rows.slice(0, 12))])


static func _stats(a: Array) -> String:
	if a.is_empty():
		return "no units"
	a.sort()
	var mean := 0.0
	for x in a:
		mean += float(x)
	mean /= a.size()
	return "mean %.1f px, median %.1f, 95%% under %.0f, worst %.0f (%d units)" % [mean, float(a[a.size() / 2]), float(a[int(a.size() * 0.95)]), float(a.back()), a.size()]


func _p95(a: Array) -> float:
	if a.is_empty():
		return 0.0
	a.sort()
	return float(a[int(a.size() * 0.95)])


func _watch_mixed() -> bool:
	_wait += 1
	if _wait < 3:
		return false
	g = main.game
	var rp = g.replay if g != null else null
	if not (rp is ReplayMix):
		check("mixed_viewer_open", false, "no ReplayMix: %s" % str(rp))
		quit(1)
		return true
	var mx: ReplayMix = rp
	if mx.seeking():
		_mframes += 1
		return false
	match _ms:
		0:
			check("mixed_viewer_open", not g.puppet and g.demo and g.replay == mx and g.net == null,
				"length %s, %d keyframes, %d commands, AIs %d" % [ReplayPlayer.clock_text(mx.length), mx.keys.size(), mx.cmd_list.size(), g.ais.size()])
			var nk := mx.keys.size()
			for f in [0.3, 0.5, 0.7]:
				var ki := clampi(int(nk * f), 1, nk - 3)
				_mk.append(float(mx.keys[ki]["t0"]))
			_ms = 1
		1:
			# drift runs: from a keyframe, 10 s with the corrections off, then 30 s with them on (across three keyframes)
			if _mrun.is_empty():
				if _mk.is_empty():
					_ms = 2
					return false
				var kt: float = _mk.pop_front()
				for corr in [false, true]:
					_mres.append({"t0": kt, "corr": corr, "d": {}})
				_mrun = _mres[_mres.size() - 2]
				mx.corr_on = false
				mx.seek(kt)
				mx.set_speed(1.0)
				mx.set_playing(true)
				return false
			var el := g.clock - float(_mrun["t0"])
			var sec := snappedf(el, 0.5)
			var dd: Dictionary = _mrun["d"]
			if not dd.has(sec):
				var off := _mixed_off(mx)      # (only on a tick the truth has a sample of: twice a second)
				if not off.is_empty():
					dd[sec] = off
					if not _mrun.has("a"):
						_mrun["a"] = {}
					_mrun["a"][sec] = _mixed_off(mx, true)
					if OS.get_cmdline_user_args().has("debug") and (sec == 1.0 or sec == 3.0) and not bool(_mrun["corr"]):
						_drift_debug()
			var span := 30.0 if bool(_mrun["corr"]) else 10.0
			if el >= span + 0.1 or mx.at_end:
				if not bool(_mrun["corr"]):
					_mrun = _mres[_mres.size() - 1]
					mx.corr_on = true
					mx.seek(float(_mrun["t0"]))
					mx.set_speed(1.0)
					mx.set_playing(true)
				else:
					_mrun = {}
		2:
			var no_c: Dictionary = {}
			var wi_c: Array = []
			var wi_after: Array = []
			for r in _mres:
				var d: Dictionary = r["d"]
				for sec in d:
					if not bool(r["corr"]):
						if not no_c.has(sec):
							no_c[sec] = []
						no_c[sec].append_array(d[sec])
					else:
						wi_c.append_array(d[sec])
						var into := fmod(float(sec), ReplayRecorder.KEY_SECS)
						if into >= 0.9 and into <= 1.1:
							wi_after.append_array(d[sec])
			var first: Array = []
			for r in _mres:
				if not bool(r["corr"]):
					for sec in r["d"]:
						if float(sec) <= 0.5:
							first.append_array(r["d"][sec])
			check("mixed_key_exact", not first.is_empty() and _p95(first.duplicate()) < 40.0, "within half a second of a keyframe (no correction yet): %s" % _stats(first.duplicate()))
			var no_a := {}
			var wi_a: Array = []
			for r in _mres:
				var da: Dictionary = r.get("a", {})
				for sec in da:
					if not bool(r["corr"]):
						if not no_a.has(sec):
							no_a[sec] = []
						no_a[sec].append_array(da[sec])
					else:
						wi_a.append_array(da[sec])
			for sec in [1.0, 2.0, 5.0, 9.5]:
				print("DRIFT no correction, %.1f s after a keyframe: %s" % [sec, _stats(no_c.get(sec, []).duplicate())])
				print("DRIFT   (army only, no workers): %s" % _stats(no_a.get(sec, []).duplicate()))
			print("DRIFT with correction, army only, every sample: %s" % _stats(wi_a.duplicate()))
			print("DRIFT with correction, every sample over 30 s: %s" % _stats(wi_c.duplicate()))
			print("DRIFT with correction, 1 s after each keyframe (the glide done): %s" % _stats(wi_after.duplicate()))
			var p10 := _p95(no_c.get(9.5, []).duplicate())
			var p5 := _p95(no_c.get(5.0, []).duplicate())
			var pc := _p95(wi_c.duplicate())
			_bench["drift_10s_p95"] = p10
			_bench["drift_corr_p95"] = pc
			check("mixed_corrected_drift", not wi_c.is_empty() and pc <= maxf(p10, p5) * 1.1 + 1.0 and _p95(wi_after.duplicate()) <= maxf(p5, 40.0),
				"with the keyframes 95%% of units within %.0f px (without, after 10 s: %.0f px)" % [pc, p10])
			check("mixed_commands_given", mx.n_run > 0 or mx.cmd_list.is_empty(), "%d commands given, %d lost" % [mx.n_run, mx.n_lost])
			# seeking: to the end of a 10 s stretch (the longest run forward), and back
			_mseek = []
			var nk := mx.keys.size()
			var kt := float(mx.keys[clampi(nk / 2, 0, nk - 2)]["t0"])
			mx.set_speed(1.0)
			mx.seek(kt + 9.5)
			_mframes = 0
			_ms = 3
		3:
			_mseek.append([mx.ff_ms, _mframes])
			var nk := mx.keys.size()
			mx.seek(float(mx.keys[clampi(nk / 4, 0, nk - 2)]["t0"]) + 5.0)
			_mframes = 0
			_ms = 4
		4:
			_mseek.append([mx.ff_ms, _mframes])
			var ok := absf(mx.play_t - (float(mx.keys[clampi(mx.keys.size() / 4, 0, mx.keys.size() - 2)]["t0"]) + 5.0)) < 0.1
			print("SEEK mixed: 9.5 s past a keyframe %.0f ms (%d frames), 5 s past %.0f ms (%d frames)" % [_mseek[0][0], _mseek[0][1], _mseek[1][0], _mseek[1][1]])
			_bench["seek_ms"] = [_mseek[0][0], _mseek[1][0]]
			var stale := 0
			for u in g.units:
				if is_instance_valid(u) and not u.dead and u.net_id != 0 and not mx._by_nid.has(u.net_id):
					stale += 1
			check("mixed_seek", ok and stale == 0, "at %s (asked %s), stale %d" % [ReplayPlayer.clock_text(mx.play_t), ReplayPlayer.clock_text(float(mx.keys[clampi(mx.keys.size() / 4, 0, mx.keys.size() - 2)]["t0"]) + 5.0), stale])
			# pause holds the clock; the viewer orders nothing
			mx.set_playing(false)
			_p0 = mx.play_t
			_wt = 0.0
			_ms = 5
		5:
			_wt += 1.0
			if _wt >= 20.0:
				check("mixed_pause_holds", absf(mx.play_t - _p0) < 0.001, "clock %.2f -> %.2f" % [_p0, mx.play_t])
				var u0: Unit = null
				for u in g.units:
					if is_instance_valid(u) and not u.dead and u.kind != "horse" and float(u.d.get("speed", 0.0)) > 0.0:
						u0 = u
						break
				if u0:
					var was := u0.order_point
					g.input_cmd = true
					u0.give({"o": "move", "p": u0.position + Vector2(300, 0)})
					g.input_cmd = false
					check("mixed_viewer_orders_nothing", u0.order_point == was, "a click's order to %s was dropped" % u0.kind)
				mx.set_playing(true)
				mx.seek(mx.length)
				_ms = 6
		6:
			check("mixed_seek_to_end", mx.at_end, "at %s of %s" % [ReplayPlayer.clock_text(mx.play_t), ReplayPlayer.clock_text(mx.length)])
			main._to_replays()
			print("BENCH %s" % str(_bench))
			print("ALL OK" if failed == 0 else "SOME FAILED (%d)" % failed)
			quit(0 if failed == 0 else 1)
			return true
	return false
