extends SceneTree
## qa-perf (0.33.8): the autosave's and the replay keyframe's costs on a late-game state (a save from perf_bench.gd
## savestate:FILE), each part timed REPS times: capture (the state as a Dictionary), the head's JSON (with the log), the
## units' JSON, the final text, the file; the MIXED replay's keyframe (the same capture plus var_to_bytes and compression).
##   godot --headless --fixed-fps 60 --script res://tools/qa/save_cost.gd -- save:/abs/state.json

var main: Node
var t := 0.0
var save_path := ""
var _phase := 0
var _n := 0


class SilentSfx extends Sfx:
	func _find(_name: String) -> Array:
		return []


func _initialize() -> void:
	Settings.load_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("save:"):
			save_path = a.substr(5)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.add_child(SilentSfx.new())


func _process(delta: float) -> bool:
	t += delta
	if _phase == 0 and t > 0.3:
		var save = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		var cfg: Dictionary = (save["cfg"] as Dictionary).duplicate(true)
		cfg["resume"] = save
		main.start(cfg)
		_phase = 1
	elif _phase == 1 and main.game != null:
		var g: Game = main.game
		if g.hud:
			g.hud.countdown = 0.0
		paused = false
		_n += 1
		if _n == 60:
			_measure(g)
			return true
	return false


func _measure(g: Game) -> void:
	var lines := g.mlog.lines.size() if g.mlog else 0
	for rep in 5:
		var t0 := Time.get_ticks_usec()
		var d := SaveGame.capture(g, main.last_cfg)
		var t1 := Time.get_ticks_usec()
		var nlog := JSON.stringify(d["log"]).length()
		var t1b := Time.get_ticks_usec()
		var job := SaveGame.SaveJob.new(d)
		var t2 := Time.get_ticks_usec()
		job.defer_write = true
		var steps := 0
		var worst := 0
		var fin := 0
		while true:
			var s0 := Time.get_ticks_usec()
			var done := job.step()
			var dt := Time.get_ticks_usec() - s0
			if done:
				fin = dt
				break
			steps += 1
			worst = maxi(worst, dt)
		var t3 := Time.get_ticks_usec()
		SaveGame._write_file(job.text)
		var t4 := Time.get_ticks_usec()
		var lt := g.mlog.text() if g.mlog else ""
		var t5 := Time.get_ticks_usec()
		var d2 := SaveGame.capture(g, main.last_cfg, true)
		var t6 := Time.get_ticks_usec()
		var raw := var_to_bytes(d2)
		var t7 := Time.get_ticks_usec()
		var zz := raw.compress(FileAccess.COMPRESSION_ZSTD)
		var t8 := Time.get_ticks_usec()
		print("SAVE %d units %d buildings, log %d lines (%d kB of JSON) | capture %.1f ms | head+copy %.1f ms | %d unit steps (worst %.1f ms) | final text %.1f ms | file %.1f ms (%d kB) | log text %.1f ms | replay key: capture %.1f, bytes %.1f (%d kB), zstd %.1f ms (%d kB)" % [
			g.units.size(), g.buildings.size(), lines, nlog / 1024, (t1 - t0) / 1000.0, (t2 - t1b) / 1000.0, steps, worst / 1000.0, fin / 1000.0, (t4 - t3) / 1000.0,
			job.text.length() / 1024, (t5 - t4) / 1000.0, (t6 - t5) / 1000.0, (t7 - t6) / 1000.0, raw.size() / 1024, (t8 - t7) / 1000.0, zz.size() / 1024])
