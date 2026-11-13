extends SceneTree
## The spectator panels' icons (owner, 2026-11-13: "no tooltips ... not clickable, we should be able to click to select
## it to see where it is"): watch two computers play, then an ARMY & STRUCTURES icon and a PRODUCTION icon each give a
## tooltip and, clicked, select their units/building and move the camera to one; a second click goes to the next one.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --script res://tools/test_spec_icons.gd [-- out:/dir]
var main: Node
var fails := 0
var out := ""


func check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out:"):
			out = a.substr(4)
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main.start({"map": "greenhold", "seed": 7, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	paused = false
	g.spectator.process_mode = Node.PROCESS_MODE_DISABLED
	while g.clock < 150.0:
		await process_frame
	var sp: SpecPanels = g.hud.spec_panels()
	for p in SpecPanels.PANELS:
		SpecPanels.open[p] = true
		SpecPanels.team[p] = -1
	g.hud._sig.clear()
	for i in 10:
		await process_frame
	var army_hit: Array = []
	for h in sp._hits["army"]:
		if not bool(h[1]["bld"]) and int(h[1]["it"][1]) >= 2:
			army_hit = h
			break
	check(not army_hit.is_empty(), "ARMY & STRUCTURES: icons are clickable targets (%d)" % sp._hits["army"].size())
	check(not sp._hits["prod"].is_empty(), "PRODUCTION: icons are clickable targets (%d)" % sp._hits["prod"].size())
	if not army_hit.is_empty():
		var at: Vector2 = (army_hit[0] as Rect2).get_center()
		var hv: Dictionary = g.hud._hover_at(at)
		check(hv.has("spec"), "hovering an army icon: a tooltip target")
		var tp: Dictionary = g.hud._tip_of(hv) if hv.has("spec") else {}
		check(String(tp.get("title", "")) != "" and String(tp.get("hint", "")).begins_with("Click"), "its tooltip: %s / %s / %s" % [tp.get("title", ""), tp.get("body", ""), tp.get("stats", "")])
		var cam0: Vector2 = g.camera.position
		check(sp.press(at), "clicking it is taken by the panel")
		var sel: Array = g.selection.filter(func(x): return is_instance_valid(x))
		var key := String(army_hit[1]["key"])
		check(sel.size() >= 2 and sel.all(func(x): return x.kind == key), "it selects every %s of that side (%d)" % [key, sel.size()])
		check(g.camera.position.distance_to(cam0) > 1.0, "the camera goes to one of them")
		var cam1: Vector2 = g.camera.position
		sp.press(at)
		check(g.camera.position.distance_to(cam1) > 1.0, "a second click goes to the next one")
		if out != "":
			g.hud._sig.clear()
			g.hud._tip = tp
			g.hud._tip_at = at
			for i in 20:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png(out.path_join("spec_icons_click.png"))
	if not sp._hits["prod"].is_empty():
		var ph: Array = sp._hits["prod"][0]
		var tp2: Dictionary = g.hud._tip_of(g.hud._hover_at((ph[0] as Rect2).get_center()))
		check(String(tp2.get("body", "")) != "", "a production tooltip: %s / %s" % [tp2.get("title", ""), tp2.get("body", "")])
		sp.press((ph[0] as Rect2).get_center())
		var e = ph[1].get("e")
		check(is_instance_valid(e) and g.selection.has(e), "clicking a production icon selects where it is made")
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
