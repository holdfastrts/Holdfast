extends SceneTree
## Pictures for docs/crown_hold.md: the owner's game (Dune Sea, seed 693532400, Hard Brood Economy v Hard Crown Economy)
## played by the computers; at each time in `at` a picture centred on the Crown's natural gate (its army's home post), or
## its natural hall before there is one.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_crown_hold.gd \
##       -- [map:dune_sea seed:693532400 at:340,380 out:res://docs/shots/crown_hold tag:after]
var main: Node
var g: Game
var map := "dune_sea"
var seed_ := 693532400
var at: Array = [340.0, 380.0]
var out := "res://docs/shots/crown_hold"
var tag := "after"
var t := 0.0
var shooting := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"at": at = Array(kv[1].split(",")).map(func(x): return float(x))
			"out": out = kv[1]
			"tag": tag = kv[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.render_loop_enabled = false


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "brood", "colour": 0, "side": 0, "strategy": "economy"},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "economy"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	g.path_budget_us = 1 << 40
	if g.hud:
		g.hud.visible = false
	if shooting:
		return false
	if at.is_empty():
		quit(0)
		return true
	if g.clock >= float(at[0]):
		_shoot(float(at.pop_front()))
	return false


func _shoot(c: float) -> void:
	shooting = true
	var ai = null
	for a in g.ais:
		if g.faction_of(a.team) == "crown":
			ai = a
	var p := Vector2.INF
	if ai != null and ai.ch.gate_live():
		p = ai.ch._gate_at
	if p == Vector2.INF and ai != null:
		var home := Vector2(g.starts[ai.team]) * Defs.TILE
		for h in g.halls_of(ai.team, false):
			if h.center().distance_to(home) > 10.0 * Defs.TILE:
				p = h.center()
	if p == Vector2.INF:
		p = g.center_of_team(1)
	if ai != null:
		var on_spot := 0
		var musk := 0
		for u in g.army(ai.team):
			if u.kind in ["musketeer", "musketeer_armoured", "cannon", "mortar"]:
				musk += 1
				for q in ai.ch._gate_spots + ai.ch._gate_guns:
					if u.position.distance_to(q) < 24.0:
						on_spot += 1
						break
		print("[shot %d] gate post live %s at %s, %d muskets and guns, %d on a gate spot, edge %s wall %s" % [int(c), str(ai.ch.gate_live()), str(ai.ch._gate_at), musk, on_spot, str(ai.ch.edge_live()), str(ai.ch._wall_mode)])
		if g.mlog:
			for l in g.mlog.lines.slice(maxi(0, g.mlog.lines.size() - 400)):
				if "Crown" in str(l) and ("posts" in str(l) or "holds" in str(l) or "moves its" in str(l)):
					print("   | " + str(l))
	g.camera.position = p
	g.camera.zoom = Vector2(0.7, 0.7)
	g.camera.reset_smoothing()
	RenderingServer.render_loop_enabled = true
	for i in 4:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(out).path_join("%s_%s_%d%02d.png" % [map, tag, int(c) / 60, int(c) % 60]))
	RenderingServer.render_loop_enabled = false
	shooting = false
