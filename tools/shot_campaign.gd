extends SceneTree
## Screenshots of the campaign engine (docs/shots/campaign_engine/): the main menu, the hub, a talk, the war table,
## the briefing, the mission with its dialogue box and objectives, the ford fight, the mission's end.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_campaign.gd -- <outdir> [mobile]
## (PNGs; tools/campaign/shots_to_jpg.py makes the 1200 px JPEGs.) Leaves user://campaign.json as it was.
var main: Node
var out := "/tmp/campaign_shots"
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
	Settings.device = "mobile" if a.has("mobile") else "pc"
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


func _run() -> void:
	await create_timer(2.0).timeout
	await _shot("1_main_menu")
	main.show_campaign()
	await create_timer(0.5).timeout
	await _shot("2_hub")
	(main.menu.find_child("Hotspot_captain", true, false) as Button).pressed.emit()
	await create_timer(0.3).timeout
	await _shot("3_hub_talk")
	CampaignMenu.war_table(main)
	await create_timer(0.4).timeout
	await _shot("4_war_table")
	CampaignMenu.mode = "versus"
	CampaignMenu.war_table(main)
	await create_timer(0.4).timeout
	await _shot("5_war_table_versus")
	CampaignMenu.mode = "solo"
	CampaignMenu.briefing(main, "p01_revolt")
	await create_timer(0.4).timeout
	await _shot("6_briefing")
	main.start(Campaign.make_cfg("p01_revolt", "solo"))
	await create_timer(5.5).timeout          # (the 3-2-1, then the intro lines)
	await _shot("7_mission_dialogue")
	var g: Game = main.game
	var r: MissionRun = g.mission
	# march the column to the ford and let them fight a little
	var us: Array = g.units.filter(func(u) -> bool: return u.team == r.team_index("column") and not u.dead)
	g.group_move(us, r.area_rect("ford").get_center() + Vector2(40, 0), true)
	Engine.time_scale = 4.0
	await create_timer(30.0 * 4.0 / 4.0).timeout
	Engine.time_scale = 1.0
	g.camera.position = r.area_rect("ford").get_center()
	await create_timer(1.0).timeout
	await _shot("8_mission_ford")
	for b in r.tagged("rebel_hall"):
		b.take_damage(999999.0, null)
	await create_timer(3.0).timeout
	await _shot("9_mission_end")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.PROGRESS))
	if _kept != "":
		var f := FileAccess.open(Campaign.PROGRESS, FileAccess.WRITE)
		f.store_string(_kept)
		f.close()
	quit()
