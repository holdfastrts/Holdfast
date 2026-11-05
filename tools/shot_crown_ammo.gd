extends SceneTree
## crown-ammo's pictures (docs/shots/crown_ammo/): the unit card's ammo icon (a full Musketeer, NO AMMO, RELOADING at a
## reloading point and between shots, a Horseman's pistol), the no-ammo mark over men on the field, the Barracks' ARM
## WITH POWDER and the train button's tooltip with its ammunition line.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_crown_ammo.gd -- /abs/out [lang]
var main: Node
var g
var out := ""
var lang := ""
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		lang = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.tooltips = true
	if lang != "":
		Settings.language = lang
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 7, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.6:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func _snap(name: String, region := Rect2i()) -> void:
	await process_frame
	await process_frame
	var n := name + ("_" + lang if lang != "" else "")
	var img: Image = root.get_viewport().get_texture().get_image()
	if region.size != Vector2i.ZERO:
		img = img.get_region(region)
	img.save_png("%s/%s.png" % [out, n])
	print("wrote ", n)


## The bottom panel (the card and the command card), in screen pixels.
func _bottom() -> Rect2i:
	var vs: Vector2i = root.get_viewport().get_texture().get_image().get_size()
	return Rect2i(0, vs.y - 230, vs.x, 230)


func _select(e) -> void:
	Settings.tooltips = false
	g.set_selection([e])
	g.hud._refresh_card()
	g.camera.position = e.position if e is Unit else (e as Building).center()
	root.warp_mouse(Vector2(640, 250))
	await create_timer(0.5).timeout


func _open(p: Vector2) -> Vector2:
	var c: Vector2i = g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 8))


func _run() -> void:
	await create_timer(0.5).timeout
	g.reveal = true
	var me: int = g.human
	var hall: Building = g._own_hall(me)
	g.players[me]["gold"] = 3000
	# a line of four Musketeers out in the field: full, half, empty, empty (the no-ammo marks over the empty ones)
	var spot := _open(hall.center() + Vector2(300, 260))
	var men: Array = []
	for i in 4:
		var m: Unit = g._add_unit("musketeer", me, _open(spot + Vector2(i * 30, 0)))
		m.cmd_hold()
		men.append(m)
	men[1].powder = 5.0
	men[2].set_ammo(0)
	men[3].set_ammo(0)
	var h: Unit = g._add_unit("cuirassier", me, _open(spot + Vector2(40, 50)))
	h.cmd_hold()
	h.set_ammo(0)
	# 1. a full Musketeer's card
	await _select(men[0])
	await _snap("1_card_musketeer_full", _bottom())
	# 2. NO AMMO
	await _select(men[2])
	await _snap("2_card_musketeer_no_ammo", _bottom())
	# 3. RELOADING between shots (the musket's own reload)
	men[1].cooldown = 1.6
	await _select(men[1])
	men[1].cooldown = 1.4
	await _snap("3_card_musketeer_reloading_shot", _bottom())
	# 4. the field: the no-ammo marks
	Settings.tooltips = false
	g.set_selection([])
	g.camera.position = spot + Vector2(50, 10)
	g.camera.zoom = Vector2(2.2, 2.2)
	await create_timer(0.4).timeout
	var vs: Vector2i = root.get_viewport().get_texture().get_image().get_size()
	await _snap("4_field_no_ammo_marks", Rect2i(vs.x / 2 - 300, vs.y / 2 - 170, 600, 300))
	g.camera.zoom = Vector2(1, 1)
	# 5. the Horseman with no pistol shot: NO AMMO on the pistol
	await _select(h)
	await _snap("5_card_horseman_no_ammo", _bottom())
	# 6. RELOADING at a reloading point: an empty one walks to the Town Hall and fills up shot by shot
	g.players[me]["res2"] = 60.0
	men[3].cmd_move(hall.center() + Vector2(0, hall.size.y * Defs.TILE * 0.5 + 16))
	await _select(men[3])
	var guard := 0
	while guard < 900 and not (men[3].refilling() and men[3].ammo_shots() >= 4):
		await process_frame
		guard += 1
	await _snap("6_card_musketeer_refilling", _bottom())
	# 7. the Barracks: ARM WITH POWDER on its card; the train button's tooltip with the ammunition line
	var bar: Building = g._add_building("barracks", me, g.cell_of(_open(hall.center() + Vector2(-300, 120))), true)
	await process_frame
	g.players[me]["res2"] = 6.0
	await _select(bar)
	await _snap("7_card_barracks_arm_with_powder", _bottom())
	Settings.tooltips = true
	g.players[me]["res2"] = 6.0
	g.players[me]["cap"] = 100
	men[3].cmd_move(spot)            # (away from the hall: he takes no more of the bank)
	g.hud._refresh_card()
	for bt in g.hud._card_buttons:
		var lab := String(bt["item"][1]).trim_prefix("~ ")
		if lab == "MUSKETEER":
			root.warp_mouse(bt["rect"].get_center() * float(g.hud.ui_scale))
	await create_timer(1.2).timeout
	await _snap("8_tip_musketeer_partial_ammo")
	bar.arm_powder = false
	g.hud._refresh_card()
	root.warp_mouse(Vector2(640, 250))
	await create_timer(0.3).timeout
	for bt in g.hud._card_buttons:
		var lab := String(bt["item"][1]).trim_prefix("~ ")
		if lab == "ARM WITH POWDER":
			root.warp_mouse(bt["rect"].get_center() * float(g.hud.ui_scale))
	await create_timer(1.2).timeout
	await _snap("9_tip_arm_with_powder_off")
	quit()
