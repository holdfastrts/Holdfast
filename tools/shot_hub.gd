extends SceneTree
## Pictures of a campaign hub (the layered paintings, docs/campaign_hub_art.md): the hub, its person lit up as if
## pointed at, and his talk open. line:<storyline> picks the hub (prologue = Rome, the default; clockmaker = Hollweg's
## workshop; explorer = Lindqvist's station; every storyline is opened for it: Campaign.open_all).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_hub.gd -- <outdir> [pc|mobile] [film] [line:clockmaker]
var main
var out := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://running.txt"))
	Settings.load_all()
	Settings.device = a[1] if a.size() > 1 else "pc"
	Settings.apply()
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _snap(name: String, wait := 0.6) -> void:
	await create_timer(wait).timeout
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	await create_timer(0.5).timeout
	CampaignMenu.line = "prologue"
	for x in OS.get_cmdline_user_args():
		if x.begins_with("line:"):
			CampaignMenu.line = x.substr(5)
			Campaign.open_all = true
	main.show_campaign()
	await _snap("1_hub", 2.0)
	var hs: HubScene = main.menu.find_child("*", true, false) as HubScene
	for n in main.menu.find_children("*", "HubScene", true, false):
		hs = n
	print("hub scene: ", hs != null and hs.ok())
	var person := ""        # the hub's person: the first talk hotspot with a layer of its own
	var who := ""
	for sl in Campaign.storylines():
		if String(sl["id"]) == CampaignMenu.line:
			for h in sl.get("hub", {}).get("hotspots", []):
				if who == "" and h.has("layer"):
					person = String(h["layer"])
					who = String(h["id"])
	if hs:
		hs.highlight = person
		await _snap("2_%s_pointed" % person, 0.4)
		hs.highlight = ""
	if OS.get_cmdline_user_args().has("film"):      # 6 s at 10 frames a second, for a gif of the life in the room
		for i in 60:
			await create_timer(0.1).timeout
			await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/film_%03d.png" % [out, i])
	var b: Button = main.menu.find_child("Hotspot_" + who, true, false)
	if b:
		b.pressed.emit()
	await _snap("3_%s_talks" % person, 0.6)
	quit()
