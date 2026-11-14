extends SceneTree
## VIEW MAP after a Clockwork game (owner 2026-11-13: "the clockwork gears disappear"): end a match, press VIEW MAP, move
## the camera, picture it.  godot --rendering-driver opengl3 --script res://tools/shot_view_map_gears.gd -- OUT.png
var main


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main.start({"map": "greenhold", "seed": 7, "slots": [{"who": "you", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "balanced"}, {"who": "normal", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await create_timer(0.5).timeout
	var g = main.game
	g.hud.countdown = 0.0
	paused = false
	await create_timer(3.0).timeout
	g.camera.position += Vector2(1600, 1100)    # (the match ends with the camera away from the base: the owner's case)
	await create_timer(0.5).timeout
	g.over = true
	g._sample_stats()
	main._on_end(g.human)
	await create_timer(1.8).timeout
	var rep: Control = null
	for c in main.ui_layer.get_children():
		if c.has_signal("view_map"):
			rep = c
	main._view_map(rep)
	await create_timer(0.5).timeout
	var hall = null
	for b in g.buildings:
		if b.team == g.human and b.kind == "clocktower":
			hall = b
	g.camera.position = hall.center() + Vector2(1400, 900)      # (roamed away first, as a player looking at the enemy would)
	await create_timer(0.6).timeout
	g.camera.position = hall.center() + Vector2(120, 60)        # (and back to his own base)
	await create_timer(1.0).timeout
	root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
