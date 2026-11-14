extends SceneTree
## Pictures of the VETERANCY CHEVRONS (scripts/vet_chevrons.gd, docs/vet_chevrons.md): a line of soldiers of mixed ranks
## at the usual zoom and zoomed out, every faction's units, a field of bodies as a Crown player sees it (chevrons, no
## number) and as a Brood player sees it (chevrons over the spoils numbers).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_vet_chevrons.gd -- <outdir>
var g: Game
var out := ""


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _snap(name: String, w := 800, h := 450, at := Vector2.INF) -> void:
	for i in 3:
		await process_frame
	var full: Image = root.get_viewport().get_texture().get_image()
	var vs := Vector2i(full.get_width(), full.get_height())
	var c := Vector2(vs) * 0.5
	if at != Vector2.INF:
		c = g.get_viewport().get_canvas_transform() * at * (Vector2(vs) / root.get_viewport().get_visible_rect().size)
	var x := clampi(int(c.x) - w / 2, 0, vs.x - w)
	var y := clampi(int(c.y) - h / 2, 0, vs.y - h)
	full.get_region(Rect2i(x, y, w, h)).save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _dummy(kind: String, t: int, p: Vector2, kills: int, hurt := false) -> Unit:
	var u: Unit = g._add_unit(kind, t, p)
	if u == null:
		return null
	u.max_hp = 99999.0
	u.hp = 99999.0 * (0.6 if hurt else 1.0)
	u.auto_work = false
	u.hold_fire = true
	u.cmd_hold()
	u.kills = kills
	return u


func _game(facs: Array, human := -1) -> Vector2:
	if g != null:
		g.queue_free()
		await process_frame
	g = Game.new()
	g.map_id = "ashford_crossing"
	g.demo = human < 0
	if human >= 0:
		g.human = human
	g.factions = facs
	g.sides = range(facs.size())
	root.add_child(g)
	for i in 10:
		await process_frame
	g.reveal = true
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	var h: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == g.faction_hall(0):
			h = b
	var at := h.center() + Vector2(0, h.rect().size.y * 0.5 + 150.0)
	for u in g.units.duplicate():
		u.auto_work = false
		u.cmd_stop()
		u.position = at + Vector2(1400, 1400)
	return at


func _run() -> void:
	var at: Vector2 = await _game(["crown", "clockwork", "brood"])
	# ---- 1. a line of Musketeers: 0, 8, 15, 22, 30, 41, 50, 63 kills (some hurt: the bar shows, the chevron stays put)
	var ks := [0, 8, 15, 22, 30, 41, 50, 63]
	for i in ks.size():
		_dummy("musketeer", 0, at + Vector2(-140 + i * 40, 0), ks[i], i % 3 == 1)
	g.camera.position = at + Vector2(0, -20)
	g.camera.zoom = Vector2(2.2, 2.2)
	await create_timer(0.6).timeout
	await _snap("1_line_close", 800, 300)
	g.camera.zoom = Vector2(1.5, 1.5)
	await create_timer(0.4).timeout
	await _snap("2_line_usual_zoom", 800, 300)
	# ---- 2. every faction (guns, workers, flyers), usual zoom
	var row := [[0, "labourer", 16], [0, "cannon", 33], [0, "balloon", 55], [0, "cuirassier", 20], [1, "winder", 15], [1, "clock_soldier", 31],
		[1, "springer", 52], [1, "ticking_owl", 18], [1, "pendulum", 40], [2, "grub", 17], [2, "raptor", 34], [2, "spitter", 51], [2, "brute", 25], [2, "skywing", 60]]
	for i in row.size():
		_dummy(row[i][1], row[i][0], at + Vector2(-330 + i * 50, 190), row[i][2], i % 2 == 0)
	g.camera.position = at + Vector2(0, 160)
	await create_timer(0.6).timeout
	await _snap("3_every_faction", 1100, 330)
	# ---- 3. a big army zoomed out: 120 men, about a third of them veterans
	for i in 120:
		var k := 0
		if i % 3 == 0:
			k = [15, 20, 35, 52][i % 4]
		_dummy("musketeer" if i % 2 == 0 else "raptor", i % 2, at + Vector2(-400 + (i % 20) * 34, 420 + (i / 20) * 30), k)
	g.camera.position = at + Vector2(-80, 480)
	g.camera.zoom = Vector2(0.6, 0.6)
	await create_timer(0.6).timeout
	await _snap("4_army_zoomed_out", 900, 450)
	g.camera.zoom = Vector2(1.0, 1.0)
	await create_timer(0.4).timeout
	await _snap("5_army_zoom_1", 1100, 500)
	# ---- 4. a field of bodies, as a Crown player sees it and as a Brood player sees it
	for human in [0, 1]:
		var a2: Vector2 = await _game(["crown", "brood"], human)
		var bs: Array = []
		var kk := [3, 15, 18, 27, 31, 44, 50, 70, 9, 22]
		for i in kk.size():
			var u := _dummy("musketeer" if i % 2 == 0 else "raptor", i % 2, a2 + Vector2(-180 + i * 40, (i % 2) * 30), kk[i])
			bs.append(u)
		await create_timer(0.2).timeout
		for u in bs:
			u.hp = 0.0
			u.die()
		g.camera.position = a2 + Vector2(0, 0)
		g.camera.zoom = Vector2(2.0, 2.0)
		await create_timer(1.6).timeout
		await _snap("6_bodies_crown_player" if human == 0 else "7_bodies_brood_player", 900, 300)
	quit()
