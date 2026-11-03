extends SceneTree
## Pictures of the painted resource icons and the pistol mark (docs/shots/res_icons/; docs/art_redraw_queue.md 1-2):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_res_icons.gd -- <outdir> crown [phone]
##   (brood, clockwork: the top bar only)
## <fac>_top[_phone].png: the whole screen with the top bar's pills; crown also: card_horseman_loaded, card_horseman_fired,
## card_farm_soil (the Farm's soil chip), card_mill_saltpetre; clockwork: card_press_brass.
## (The pictures in docs/ are cropped to the top bar / the card; contact.png and the zooms are made in Python.)
var main: Node
var g
var out := ""
var fac := "crown"
var phone := false
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		fac = a[1]
	phone = a.size() > 2 and a[2] == "phone"
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "phone" if phone else "pc"
	Settings.tooltips = true
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 7, "slots": [
			{"who": "you", "faction": fac, "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown" if fac != "crown" else "brood", "colour": 1, "side": 1}]})
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


func _snap(name: String) -> void:
	await create_timer(0.5).timeout
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("wrote ", name)


func _select(e: Entity) -> void:
	g.camera.position = e.center() if e is Building else e.position
	g.set_selection([e])
	g.hud._refresh_card()
	await create_timer(0.4).timeout


func _building(kind: String) -> Building:
	for b in g.buildings:
		if b.team == 0 and b.kind == kind:
			return b
	var hall: Building = g._own_hall(0)
	var c: Vector2i = g.find_spot(0, kind, hall, 2, 30)
	return g._add_building(kind, 0, c, true) if c.x >= 0 else null


func _run() -> void:
	await create_timer(0.5).timeout
	g.reveal = true
	g.players[0]["gold"] = 1234
	g.players[0]["res2"] = 321
	var sfx := "_phone" if phone else ""
	await _snap(fac + "_top" + sfx)
	if fac == "crown":
		var hall: Building = g._own_hall(0)
		var u: Unit = g._add_unit("cuirassier", 0, hall.center() + Vector2(0, 4.0 * Defs.TILE))
		u.pistol = true
		await _select(u)
		await _snap("card_horseman_loaded" + sfx)
		u.pistol = false
		await _snap("card_horseman_fired" + sfx)
		for k in [["farm", "card_farm_soil"], ["powder_mill", "card_mill_saltpetre"]]:
			var b := _building(k[0])
			if b:
				await _select(b)
				await _snap(k[1] + sfx)
	elif fac == "clockwork":
		var p := _building(Defs.GEAR_PRESS)
		if p:
			await _select(p)
			await _snap("card_press_brass" + sfx)
	quit()
