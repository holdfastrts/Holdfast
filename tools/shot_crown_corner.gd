extends SceneTree
## Pictures of the Crown's natural, A (by the ramp's foot) and B (the corner pocket), on the bare map with its wall laid in
## full (crown-v-brood, docs/crown_v_brood.md section 5):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_crown_corner.gd -- out:/abs/dir [maps...]
## For each map and variant: the Crown's hall at its 2nd-base spot, the wall plan's palisade and gates built, each building
## slot filled with what it is for (a Barracks, a Church or a Cottage), and the main's ramp wall; the picture is centred
## between the main's ramp and the new hall. Files <map>_<A|B>.png.
var main: Node
var g: Game
var out := "/tmp/crown_corner"
var maps: Array = ["redrock_canyon", "cinder_steps", "thornwood_maze", "greenhold"]


func _initialize() -> void:
	var m: Array = []
	for x in OS.get_cmdline_user_args():
		if String(x).begins_with("out:"):
			out = String(x).substr(4)
		else:
			m.append(x)
	if not m.is_empty():
		maps = m
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	for m in maps:
		for v in ["A", "B"]:
			await _one(m, v)
	quit()


func _one(map: String, v: String) -> void:
	if main != null:
		main.queue_free()
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var cfg := {"map": map, "seed": 4242, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "economy"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "economy"}]}
	if v == "B":
		cfg["crown_nat"] = "corner"
	main.start(cfg)
	g = main.game
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
	if g.spectator:
		g.spectator.process_mode = Node.PROCESS_MODE_DISABLED
	if g.controls:
		g.controls.process_mode = Node.PROCESS_MODE_DISABLED
	g.reveal = true
	await process_frame
	var ai: AICrown = null
	for a in g.ais:
		if a.team == 0:
			ai = a
	var mainm := Vector2(g.starts[0]) + Vector2(2.5, 2.0)
	var picks: Array = CrownSites.pick(g, 0, [mainm], 1)
	if picks.is_empty():
		return
	var c: Vector2i = picks[0]["c"]
	var rw: Dictionary = ai.plan_cottage_wall()
	var plan: Dictionary = ai.xw.plan_for(c)
	if not rw.is_empty():
		g._add_building("cottage", 0, rw["cottage"], true)
		for e in rw["pieces"]:
			g._add_building(e[0], 0, e[1], true)
	var hall: Building = g._add_building("town_hall", 0, c, true)
	for s in plan.get("slots", []):
		var sz: Vector2i = s["size"]
		var k := "cottage" if sz == Vector2i(2, 2) else ("church" if sz == Vector2i(3, 3) else "barracks")
		g._add_building(k, 0, s["cell"], true)
	for e in plan.get("pieces", []):
		g._add_building(e[0], 0, e[1], true)
	var ramp := CrownSites.ramp_of(g, 0)
	var top: Vector2 = (ramp["top"] if not ramp.is_empty() else mainm) * Defs.TILE
	var cam: Camera2D = g.camera
	cam.position = top.lerp(hall.center(), 0.5)
	var span: Vector2 = (top - hall.center()).abs() + Vector2(16, 16) * Defs.TILE
	var z := clampf(minf(1280.0 / span.x, 720.0 / span.y), 0.35, 1.0)
	cam.zoom = Vector2(z, z)
	cam.reset_smoothing()
	RenderingServer.render_loop_enabled = true
	for i in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [map, v]))
	print("SHOT %s_%s spot %s pieces %d slots %d" % [map, v, str(c), (plan.get("pieces", []) as Array).size(), (plan.get("slots", []) as Array).size()])
