extends SceneTree
## Screenshots of campaign mission 1 (docs/shots/campaign_m1/): the opening's still with its line, the night defence,
## the choice, the canister charge at the gate, the ending.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_campaign_m1.gd -- <outdir>
## (PNGs; tools/campaign/shots_to_jpg.py makes the 1200 px JPEGs.) Leaves user://campaign.json as it was.
var main: Node
var out := "/tmp/campaign_m1_shots"
var _kept := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://running.txt"))
	if FileAccess.file_exists(Campaign.PROGRESS):
		_kept = FileAccess.get_file_as_string(Campaign.PROGRESS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.PROGRESS))
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("wrote ", name)


func _step(g: Game, to: float) -> void:
	g.clock = to
	g.mission._run_triggers()
	g.mission._check_objectives()


func _kill(r: MissionRun, tag: String, keep := 0) -> void:
	var list := r.tagged(tag)
	for i in range(keep, list.size()):
		if list[i] is Building:
			list[i].take_damage(1e9, null)
		else:
			list[i].die()


func _run() -> void:
	await create_timer(1.5).timeout
	var m := Campaign.mission("p01_leaf")
	# 1: the opening (the plantation still: the King, then Tomasz)
	var sh := StillShow.play(main.ui_layer, m, Campaign.show_pages(m, "opening"), func() -> void: pass)
	sh.auto = false
	for i in 3:
		sh.next()
	await create_timer(0.9).timeout
	await _shot("1_opening_still")
	sh.finish()
	# 2: the night defence
	main.start(Campaign.make_cfg("p01_leaf", "solo"))
	await create_timer(1.0).timeout
	var g: Game = main.game
	var r: MissionRun = g.mission
	Engine.time_scale = 4.0
	await create_timer(46.0).timeout          # (the first wave comes out of the north fields at 0:25)
	Engine.time_scale = 1.0
	# (where the fight is: the first night rebel the Crown can see, else the north barns)
	var at := r.area_rect("plantation").get_center() + Vector2(0, -200)
	for u in r.tagged("night"):
		if not u.dead and g.is_visible_to(g.human, u.position):
			at = u.position
			break
	g.camera.position = at
	await create_timer(1.2).timeout
	await _shot("2_night_defence")
	# 3: dawn, the first camp down, the choice
	_step(g, 481.0)
	_step(g, 481.5)
	await create_timer(1.5).timeout
	_kill(r, "camp1")
	_step(g, 490.0)
	g.camera.position = r.area_rect("fork").get_center()
	for mui in main.ui_layer.get_children():
		if mui is MissionUi:
			mui.skip_all()
	await create_timer(4.5).timeout
	await _shot("3_choice")
	for mui in main.ui_layer.get_children():
		if mui is MissionUi:
			mui.pick_choice("families", "leave")
	# 4: the gate: the army before it, canister, the charge
	_kill(r, "camp2")
	_step(g, 500.0)
	var bg := r.area_rect("before_gate")
	var army: Array = r.tagged("line") + r.tagged("relief") + r.tagged("fairleigh")
	var i := 0
	for u in army:
		u.position = bg.get_center() + Vector2(-30 + (i / 8) * 26, (i % 8) * 22 - 80)
		u.cmd_hold()
		i += 1
	var j := 0
	for u in r.tagged("guns"):
		u.position = bg.get_center() + Vector2(60, -40 + j * 80)
		u.facing = Vector2.RIGHT
		u.set_canister(true)
		j += 1
	g._rebuild_hash()
	_step(g, 501.0)
	_step(g, 501.5)
	for u in r.tagged("guns"):
		if u.has_method("cmd_deploy"):
			u.cmd_deploy()
	_step(g, 524.0)
	_step(g, 531.0)
	g.camera.position = r.area_rect("kill_zone").get_center() + Vector2(60, 0)
	await create_timer(7.0).timeout
	await _shot("4_canister_charge")
	# 5: the charge broken, the ending
	_kill(r, "mass", 4)
	_step(g, 560.0)
	await create_timer(2.6).timeout
	var show: Node = main.ui_layer.find_child("StillShow", true, false)
	if show:
		(show as StillShow).auto = false
	await create_timer(0.9).timeout
	await _shot("5_ending")
	if show:
		(show as StillShow).finish()
	await create_timer(0.6).timeout
	await _shot("6_mission_end")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.PROGRESS))
	if _kept != "":
		var f := FileAccess.open(Campaign.PROGRESS, FileAccess.WRITE)
		f.store_string(_kept)
		f.close()
	quit()
