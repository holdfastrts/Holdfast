extends SceneTree
## Screenshots of REMEMBERED ENEMY BUILDINGS under the fog (docs/fog_ghosts.md): Crown (you) v Clockwork on Ashford
## Crossing, a Crown scout looks at the Clockwork base, walks away, then one of its buildings is razed and another
## damaged while nobody of yours sees them:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_fog_ghosts.gd -- /abs/prefix
## writes <prefix>_1_seen.png, <prefix>_2_left.png and <prefix>_3_razed_unseen.png.
var main


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _snap() -> Image:
	paused = false
	await create_timer(0.8).timeout
	return root.get_viewport().get_texture().get_image()


func _spot(g, t: int, kind: String, near: Vector2i, avoid: Array) -> Vector2i:
	for r in range(5, 16):
		for a in 24:
			var c: Vector2i = near + Vector2i(roundi(cos(a * TAU / 24.0) * r), roundi(sin(a * TAU / 24.0) * r))
			if g.placement_problem(t, kind, c, true) != "":
				continue
			var ok := true
			for o in avoid:
				if Vector2(c - (o as Vector2i)).length() < 5.0:
					ok = false
			if ok:
				return c
	return Vector2i(-1, -1)


func _run() -> void:
	var prefix: String = OS.get_cmdline_user_args()[0]
	await process_frame
	main.start({"map": "ashford_crossing", "seed": 4242, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "easy", "faction": "clockwork", "colour": 1, "side": 1}]})
	await process_frame
	var g = main.game
	g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(0.5).timeout
	var hall = g.buildings.filter(func(b): return b.team == 1 and b.kind == g.faction_hall(1))[0]
	var hc: Vector2i = g.cell_of(hall.center())
	var used: Array = [hc]
	var extra: Array = []
	for k in ["movement_works", "cuckoo_house", "regulator"]:
		var c := _spot(g, 1, k, hc, used)
		if c.x >= 0:
			used.append(c)
			var b = g._add_building(k, 1, c, k != "cuckoo_house")
			if k == "cuckoo_house":
				b.progress = 0.45
			extra.append(b)
	# a Crown scout in the middle of their base
	var scout = g._add_unit("musketeer", 0, hall.center() + Vector2(0, 140))
	scout.max_hp = 99999.0
	scout.hp = 99999.0
	g.camera.zoom = Vector2(0.9, 0.9)
	g.camera.position = hall.center() + Vector2(0, 60)
	g.refresh_fog()
	var img: Image = await _snap()
	img.save_png(prefix + "_1_seen.png")
	# he walks away (far off): the base is under the fog
	scout.position = Vector2(g.W, g.H) * Game.T * 0.5
	g.note_move(scout)
	await create_timer(0.6).timeout
	g.refresh_fog()
	img = await _snap()
	img.save_png(prefix + "_2_left.png")
	# unseen: one razed, one hurt
	if extra.size() >= 1:
		extra[0].hp = 0.0
		extra[0].die()
	if extra.size() >= 3:
		extra[2].hp = extra[2].max_hp * 0.3
	hall.hp = hall.max_hp * 0.4
	await create_timer(3.0).timeout
	g.refresh_fog()
	img = await _snap()
	img.save_png(prefix + "_3_razed_unseen.png")
	print("shots: ", prefix)
	quit()
