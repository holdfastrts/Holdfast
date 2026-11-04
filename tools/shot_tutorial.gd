extends SceneTree
## Screenshots of the TUTORIAL (docs/shots/tutorial/): the main menu with TUTORIAL beside CAMPAIGN, the lesson list,
## a step of each lesson (the teacher's line, the task, the pointer) and a finished lesson.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_tutorial.gd -- <outdir> [mobile]
## (PNGs; make the 1200 px JPEGs with PIL or ImageMagick.) Leaves user://tutorial.json as it was.
var main: Node
var out := "/tmp/tutorial_shots"
var _kept := ""
var pre := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://running.txt"))
	if FileAccess.file_exists(Tutorial.PROGRESS):
		_kept = FileAccess.get_file_as_string(Tutorial.PROGRESS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.PROGRESS))
	Settings.load_all()
	Settings.device = "mobile" if a.has("mobile") else "pc"
	pre = "phone_" if a.has("mobile") else ""
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [out, pre, name])
	print("wrote ", pre, name)


## Start a lesson and go straight to one of its steps (the steps before it counted as done).
func _lesson_at(id: String, sid: String) -> Game:
	TutorialMenu.start(main, id)
	await create_timer(3.6).timeout          # (the 3-2-1)
	var g: Game = main.game
	var r := g.mission
	for tr in r.data["triggers"]:
		var tid := String(tr["id"])
		if tid == "start_" + sid:
			r.fire(tr)
			break
		r.fired[tid] = g.clock
		if tid.begins_with("done_") and r.obj.has("task_" + tid.substr(5)):
			r.obj["task_" + tid.substr(5)] = "done"
	r.objectives_changed.emit()
	for n in main.ui_layer.get_children():
		if n is MissionUi and not (n as MissionUi).queue.is_empty():
			(n as MissionUi).queue = (n as MissionUi).queue.slice(-1)      # (the step's last line: what to do now)
			(n as MissionUi).advance()
	Input.warp_mouse(Vector2(640, 6))
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(640, 6)
	root.push_input(mv)
	await create_timer(0.6).timeout
	return g


func _run() -> void:
	await create_timer(2.0).timeout
	Tutorial.mark_done("t01_basics")
	main.show_menu()
	await create_timer(0.5).timeout
	await _shot("1_main_menu")
	TutorialMenu.pick = "t10_crown"
	main.show_tutorial()
	await create_timer(0.5).timeout
	await _shot("2_lesson_list")
	var g := await _lesson_at("t01_basics", "move")
	g.set_selection(g.mission.tagged("recruits"))
	await create_timer(0.4).timeout
	await _shot("3_basics_move")
	main._to_menu()
	g = await _lesson_at("t01_basics", "card")
	g.set_selection(g.mission.tagged("recruits"))
	await create_timer(0.4).timeout
	await _shot("4_basics_card")
	main._to_menu()
	g = await _lesson_at("t10_crown", "wall")
	g.camera.position = g.mission.area_rect("ramp_top").get_center() + Vector2(0, 60)
	await create_timer(0.4).timeout
	await _shot("5_crown_wall")
	main._to_menu()
	g = await _lesson_at("t20_clockwork", "gear_view")
	g.toggle_gear_view()
	await create_timer(3.0).timeout          # (the step is done; the next one starts: close the view)
	for n in main.ui_layer.get_children():
		if n is MissionUi and not (n as MissionUi).queue.is_empty():
			(n as MissionUi).skip_all()
	await create_timer(2.5).timeout
	await _shot("6_clockwork_gear_view")
	main._to_menu()
	g = await _lesson_at("t30_brood", "turtle")
	g.camera.position = g.mission.area_rect("natural").get_center() + Vector2(0, -120)
	var gr: Array = g.units.filter(func(u) -> bool: return u.team == g.human and u.kind == "grub")
	g.set_selection(gr.slice(0, 1))
	await create_timer(0.4).timeout
	await _shot("7_brood_turtle")
	main._to_menu()
	g = await _lesson_at("t39_brood_practice", "attack")
	await create_timer(0.4).timeout
	await _shot("8_brood_practice_hint")
	main._to_menu()
	g = await _lesson_at("t01_basics", "end")
	g.mission.finish("you")
	await create_timer(2.0).timeout
	await _shot("9_lesson_done")
	main._to_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.PROGRESS))
	if _kept != "":
		var f := FileAccess.open(Tutorial.PROGRESS, FileAccess.WRITE)
		f.store_string(_kept)
		f.close()
	quit()
