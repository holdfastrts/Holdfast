extends SceneTree
## clockwork-eco: pictures of the Clockwork's 2nd Clocktower spot, OLD (the computer's old pick: AI._safe_hall_spot, the
## base-site rating) or NEW (ClockSites), with the Clocktower and its ring of buildings laid as the game allows them
## (ClockSites.fill_ring: 2 Cog Presses, the Mainspring, 2 Light Works, 2 Regulators, the Escapement).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_clock_sites.gd -- \
##       map:cinder_steps which:new out:/abs/dir [zoom:0.55] [marks:1]
## Writes <out>/<map>_<which>.png and prints "RING <map> <which> <cell> placed N of 8: kinds".
## marks:1 also shows the gold EXPANSION SPOTS a Clockwork player sees (no ring laid; <map>_marks.png).
var main: Node
var g: Game
var out := "/tmp/clock_sites"
var map := "cinder_steps"
var which := "new"
var zoom := 0.8
var marks := false
var t := 0.0
var started := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"which": which = kv[1]
			"out": out = kv[1]
			"zoom": zoom = float(kv[1])
			"marks": marks = kv[1] == "1"
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.expansion_spots = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(11)
		main.start({"map": map, "seed": 11, "slots": [
			{"who": "you" if marks else "hard", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "economy"},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
	if g.spectator and g.spectator.process_mode != Node.PROCESS_MODE_DISABLED:
		g.spectator.process_mode = Node.PROCESS_MODE_DISABLED     # (the director camera would move it off the shot)
	if g.controls and g.controls.process_mode != Node.PROCESS_MODE_DISABLED:
		g.controls.process_mode = Node.PROCESS_MODE_DISABLED       # (the mouse sits in a corner under xvfb: edge scrolling)
	paused = false
	if not started and t > 1.5:
		started = true
		_run()
	return false


func _snap(path: String, frames := 40) -> void:
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


func _run() -> void:
	var cw: AIClockwork = null
	for ai in g.ais:
		if ai.team == 0 and ai is AIClockwork:
			cw = ai
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	g.explored.fill(1)
	g.reveal = true
	var main_h: Building = g._own_hall(0)
	if marks:
		var mid := main_h.center()
		for s in g.exp_spots.shown:
			if int(s["team"]) == 0:
				mid = mid.lerp((Vector2(s["c"]) + Vector2(2.5, 2.0)) * Defs.TILE, 0.5)
				break
		g.camera.position = mid
		g.camera.zoom = Vector2(zoom, zoom)
		await _snap("%s/%s_marks.png" % [out, map])
		quit(0)
		return
	var c := Vector2i(-1, -1)
	if cw != null:
		cw.sites_on = which == "new"
		c = cw._safe_hall_spot()
	if c.x < 0:
		print("RING %s %s none" % [map, which])
		quit(1)
		return
	var fit: Array = ClockSites.ring_fit(g, c, ClockSites._start(c))
	var tower := g._add_building("clocktower", 0, c, true)
	var ring: Array = ClockSites.fill_ring(g, 0, tower)
	var kinds: Array = ring.map(func(e): return String(e[0]))
	print("RING %s %s %s placed %d of %d (rated %d): %s | %d tiles from the main" % [map, which, str(c), ring.size(), ClockSites.FULL_RING.size(), int(fit[0]), ", ".join(kinds),
		int(tower.center().distance_to(main_h.center()) / Defs.TILE)])
	g.camera.position = tower.center().lerp(main_h.center(), 0.3)
	g.camera.zoom = Vector2(zoom, zoom)
	g.camera.reset_smoothing()
	g.gear_net.view = false
	await _snap("%s/%s_%s.png" % [out, map, which])
	quit(0)
