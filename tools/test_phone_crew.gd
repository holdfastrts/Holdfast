extends SceneTree
## WORKERS FROM FARMS TO A POWDER MILL ON A PHONE (the owner's playtest, 2026-11-03: "In the mobile version there is
## no way to take workers from farms and put them in powder mills"). In phone mode, a Crown base with a Farm worked by
## 6 Labourers and an empty Powder Mill:
##  1. the Mill's card has + WORKER and - WORKER (CrewOrders); two presses of + WORKER (real presses on the card)
##     move two Labourers off the Farm onto the Mill (no idle one about: the Farm is the least important job);
##  2. - WORKER sends one of the Mill's men back to the Farm;
##  3. the other phone way: tap the Farm's label (its workers), keep one, tap the Mill: he goes to work it;
##  4. the Farm's card: + WORKER takes an idle Labourer first (one stands about).
## With a display (xvfb-run) it saves the Mill's card to docs/shots/phone_crew/.
##   godot --headless --fixed-fps 30 --script res://tools/test_phone_crew.gd
##   xvfb-run -a godot --fixed-fps 30 --script res://tools/test_phone_crew.gd      (the screenshot)
var fails := 0
var g: Game
var hud


func _initialize() -> void:
	_run()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func _button(label: String) -> Dictionary:
	hud._refresh_card()
	for bt in hud._card_buttons:
		if String(bt["item"][1]) == label:
			return bt
	return {}


## A real press on a card button, the way a finger does it (press, release on it).
func _tap_button(label: String) -> bool:
	var bt := _button(label)
	if bt.is_empty():
		return false
	var p: Vector2 = (bt["rect"] as Rect2).get_center()
	hud._press(p)
	hud._release(p)
	await physics_frame
	return true


func _crew(b: Building) -> Array:
	return b.crew.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)


func _run() -> void:
	Settings.load_all()       # (main loads the shared settings file at start: read it first, or its device wins over ours)
	Settings.device = "phone"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": "hollowfen", "seed": 4242, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
	for i in 30:
		await physics_frame
	g = main.game
	hud = g.hud
	hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	check(not Settings.pc(), "phone mode")
	g.reveal = true
	g.players[0]["gold"] = 5000
	var hall: Building = g.halls_of(0)[0]
	# the starting Labourers out of the way; a Farm and a Powder Mill by the hall
	for u in g.units.duplicate():
		if u.team == 0 and u.is_worker():
			g.consume_unit(u)
	var farm: Building = null
	var mill: Building = null
	var c0 := g.cell_of(hall.center())
	for r in range(4, 20):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := c0 + Vector2i(dx, dy)
				for kind in ["farm", "powder_mill"]:
					if (kind == "farm" and farm) or (kind == "powder_mill" and mill):
						continue
					if g.placement_problem(0, kind, c) == "":
						var b: Building = g._add_building(kind, 0, c, true)
						if kind == "farm":
							farm = b
						else:
							mill = b
		if farm and mill:
			break
	check(farm != null and mill != null, "a Farm and a Powder Mill by the hall")
	if farm == null or mill == null:
		quit(1)
		return
	g._astar_dirty = true
	await physics_frame
	var men: Array = []
	for i in 6:
		var u: Unit = g._add_unit("labourer", 0, farm.center() + Vector2(-40 + i * 16, 50))
		u.cmd_gather(farm)
		men.append(u)
	await wait(4.0)
	check(_crew(farm).size() == 6 and _crew(mill).is_empty(), "6 Labourers work the Farm, none the Mill")
	# 1. the Mill's card: + WORKER twice
	g.set_selection([mill])
	hud.queue_redraw()
	await _frames(3)
	var plus := _button("+ WORKER")
	check(not plus.is_empty() and bool(plus["enabled"]), "the Mill's card has + WORKER")
	check(not _button("- WORKER").is_empty() and not bool(_button("- WORKER")["enabled"]), "- WORKER is there, greyed (nobody works it yet)")
	check(await _tap_button("+ WORKER"), "+ WORKER pressed")
	check(await _tap_button("+ WORKER"), "+ WORKER pressed again")
	check(_crew(mill).size() == 2 and _crew(farm).size() == 4, "two Labourers moved from the Farm to the Mill (mill %d, farm %d)" % [_crew(mill).size(), _crew(farm).size()])
	var ok := false
	var end: float = g.clock + 30.0
	while g.clock < end:
		if mill.working_crew() >= 2:
			ok = true
			break
		await physics_frame
	check(ok, "both grind at the Mill (working %d)" % mill.working_crew())
	# the screenshot of the Mill's card (with a display)
	if DisplayServer.get_name() != "headless":
		g.camera.position = mill.center() + Vector2(0, 60)
		g.set_selection([mill])
		hud.queue_redraw()
		await _frames(12)
		var img := root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/shots/phone_crew"))
		img.save_png(ProjectSettings.globalize_path("res://docs/shots/phone_crew/mill_card_phone.png"))
		print("shot saved")
	# 2. - WORKER: one goes back to the Farm (it has room)
	check(await _tap_button("- WORKER"), "- WORKER pressed")
	check(_crew(mill).size() == 1 and _crew(farm).size() == 5, "one went back to the Farm (mill %d, farm %d)" % [_crew(mill).size(), _crew(farm).size()])
	# 3. the tap way: the Farm's label selects its workers, keep one, tap the Mill
	g.set_selection([])
	check(WorkerLabels.select_workers(g, farm), "the Farm's label selects its workers")
	check(g.selection.size() == 5, "5 selected")
	var one: Unit = g.selection[0]
	g.set_selection([one])
	g.controls._tap(Vector2.ZERO, false, false, mill.center())
	await physics_frame
	check(mill.crew.has(one) and _crew(mill).size() == 2, "a tap on the Mill with a Labourer selected sends him to work it")
	check(g.selection == [one], "the selection stays on him")
	# a tap on the Mill with its own man selected just selects the Mill
	g.controls._tap(Vector2.ZERO, false, false, mill.center())
	await physics_frame
	check(g.selection == [mill], "tapping it again (he works there already) selects the Mill")
	# 4. the Farm's card: an idle Labourer first
	var idle: Unit = g._add_unit("labourer", 0, hall.center() + Vector2(0, 90))
	idle.auto_work = false
	idle.cmd_stop()
	await physics_frame
	g.set_selection([farm])
	hud.queue_redraw()
	await _frames(3)
	check(await _tap_button("+ WORKER"), "the Farm's + WORKER pressed")
	check(farm.crew.has(idle) and _crew(mill).size() == 2, "it took the idle Labourer, not one off the Mill")
	# the computer's card has the buttons too
	Settings.device = "pc"
	g.set_selection([mill])
	check(not _button("+ WORKER").is_empty() and not _button("- WORKER").is_empty(), "the computer's card has them too")
	Settings.load_all()
	print("phone crew: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
