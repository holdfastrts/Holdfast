extends SceneTree
## Pictures of the spectator overhaul (0.27.0, docs/spectator.md): a 4-player computer match watched to `at` seconds,
## then the HUD with its PRODUCTION, ARMY & STRUCTURES and AI STORY panels in a few states.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_spectator.gd -- \
##       out:/abs/dir [device:pc|mobile] [at:240] [lang:en]
## Writes <out>/<device>_all.png (every panel, all players), <device>_picks.png (each panel on its own player, VIEW
## following another), <device>_dropdown.png (the AI STORY's list open), <device>_closed.png (ARMY closed) and,
## with lang:pt or es, <device>_<lang>.png.
var main: Node
var out := "/tmp/spectator_shots"
var device := "pc"
var at := 240.0
var lang := "en"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"device": device = kv[1]
			"at": at = float(kv[1])
			"lang": lang = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = device
	Settings.apply()
	Loc.set_lang(lang)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.render_loop_enabled = false     # (drawn only for the shots: the match runs many times faster)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main.start({"map": "twin_crowns", "seed": 7, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"},
		{"who": "normal", "faction": "brood", "colour": 2, "side": 2, "strategy": "rush"},
		{"who": "normal", "faction": "crown", "colour": 3, "side": 3, "strategy": "economy"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	paused = false
	g.ai_story.narrator.fake = true
	g.ai_story.narrator.available = true
	g.spectator.process_mode = Node.PROCESS_MODE_DISABLED
	while g.clock < at:
		await process_frame
	var sp: SpecPanels = g.hud.spec_panels()
	for p in SpecPanels.PANELS:
		SpecPanels.open[p] = true
		SpecPanels.team[p] = -1
	var h: Building = g._own_hall(0)
	g.camera.position = h.global_position + Vector2(120, 60) if h else g.camera.position
	g.camera.zoom = Vector2(0.8, 0.8)
	if lang != "en":
		await _shot(g, "%s_%s.png" % [device, lang])
		_quit()
		return
	await _shot(g, device + "_all.png")
	SpecPanels.team["prod"] = 1
	SpecPanels.team["army"] = 2
	SpecPanels.team["story"] = 0
	g.spectator.set_mode("free", 3, true)
	await _shot(g, device + "_picks.png")
	g.spectator.set_mode("all", 0, true)
	SpecPanels.team["story"] = -1
	sp.drop = "story"
	await _shot(g, device + "_dropdown.png")
	sp.drop = ""
	SpecPanels.open["army"] = false
	await _shot(g, device + "_closed.png")
	_quit()


func _shot(g: Game, file: String) -> void:
	g.hud._sig.clear()
	g.hud._redraw_t = 0.0
	RenderingServer.render_loop_enabled = true
	for i in 20:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(file))
	print("SHOT ", file)
	RenderingServer.render_loop_enabled = false


func _quit() -> void:
	main._to_menu()
	quit(0)
