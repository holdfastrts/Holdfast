extends SceneTree
## Pictures of the Free Assembly's own sprites in campaign mission 1 (docs/rebel_art.md, docs/shots/rebel_art/):
## the night attack (a band of every role sent at the manor), the stronghold's massed rebels, and the same by day,
## close (militia firing, pikes, torch-bearers at the buildings, Varenne).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_rebel_art.gd -- <outdir>
## Leaves user://campaign.json as it was.
var main: Node
var out := "/tmp/rebel_art_shots"
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


func _look(g: Game, at: Vector2, zoom: float) -> void:
	g.camera.position = at
	g.camera.zoom = Vector2(zoom, zoom)
	g.camera.reset_smoothing()


## a band of every rebel role, `off` tiles from an area's middle, sent at another area
func _band(g: Game, r: MissionRun, from: String, off: Vector2, to: String, tag: String) -> Array:
	var c := r.area_rect(from).get_center() + off * Defs.TILE
	var at := [int(c.x / Defs.TILE), int(c.y / Defs.TILE)]
	var us: Array = []
	for it in [{"kind": "musketeer", "as": "militia", "count": 5}, {"kind": "pikeman", "as": "pikeman", "count": 3},
			{"kind": "labourer", "as": "torch", "count": 2}, {"kind": "dismounted", "as": "varenne", "count": 1}]:
		it["team"] = "rebels"
		it["at"] = at
		it["tag"] = tag
		us += r._spawn(it)
	g._rebuild_hash()
	g.group_move(us, r.area_rect(to).get_center(), true)
	return us


func _middle(us: Array) -> Vector2:
	var c := Vector2.ZERO
	var n := 0
	for u in us:
		if is_instance_valid(u) and not u.dead:
			c += u.position
			n += 1
	return c / maxf(n, 1)


func _run() -> void:
	await create_timer(1.5).timeout
	main.start(Campaign.make_cfg("p01_leaf", "solo"))
	await create_timer(1.0).timeout
	var g: Game = main.game
	var r: MissionRun = g.mission
	g.reveal = true          # (the shots look where the Governor's men can't see: the fort, the field edge)
	for mui in main.ui_layer.get_children():
		if mui is MissionUi:
			mui.skip_all()
	# 1, 2: the night: a band of every role coming at the manor
	var band := _band(g, r, "manor", Vector2(16, -6), "manor", "shot_night")
	await create_timer(5.0).timeout
	_look(g, _middle(band), 2.5)
	await create_timer(0.4).timeout
	print("zoom ", g.camera.zoom)
	await _shot("1_night_attack")
	await create_timer(5.0).timeout
	_look(g, _middle(band), 2.5)
	await create_timer(0.4).timeout
	await _shot("2_night_attack_b")
	# 3, 4: the stronghold: the massed rebels behind the gate
	_look(g, r.area_rect("mass").get_center(), 2.0)
	await create_timer(0.6).timeout
	await _shot("3_stronghold")
	_look(g, r.area_rect("mass").get_center(), 3.5)
	await create_timer(0.6).timeout
	await _shot("4_stronghold_close")
	# 5, 6: by day, close
	r.set_light("day", 0.0)
	var band2 := _band(g, r, "manor", Vector2(-14, 8), "manor", "shot_day")
	await create_timer(6.0).timeout
	_look(g, _middle(band2), 3.0)
	await create_timer(0.4).timeout
	await _shot("5_day_skirmish")
	await create_timer(3.0).timeout
	_look(g, _middle(band2), 3.0)
	await create_timer(0.4).timeout
	await _shot("6_day_skirmish_b")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.PROGRESS))
	if _kept != "":
		var f := FileAccess.open(Campaign.PROGRESS, FileAccess.WRITE)
		f.store_string(_kept)
		f.close()
	quit()
