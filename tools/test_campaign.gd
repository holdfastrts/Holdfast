extends SceneTree
## The campaign engine (docs/campaign_engine.md): every mission's data checks out (Campaign.problems), every campaign
## text has its Portuguese and Spanish, the setups for solo / co-op / versus seat the right players, and the test
## mission plays: the start is laid out, the triggers fire (lines, a counter-attack, reinforcements, a hurt hall), the
## mission is won (the rebels' hall burned: the storylines open), lost (the captain killed) and won by the other side
## (versus: the rebels hold out). The hub's talks change after the mission.
##   godot --headless --fixed-fps 30 --script res://tools/test_campaign.gd
## Prints CHECK lines, then "campaign: N failures"; exit code 1 on a failure. (Leaves user://campaign.json as it was.)
var main: Node
var fails := 0
var _kept := ""


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-64s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://running.txt"))
	if FileAccess.file_exists(Campaign.PROGRESS):
		_kept = FileAccess.get_file_as_string(Campaign.PROGRESS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.PROGRESS))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.PROGRESS))
	if _kept != "":
		var f := FileAccess.open(Campaign.PROGRESS, FileAccess.WRITE)
		f.store_string(_kept)
		f.close()
	print("campaign: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _data() -> void:
	for id in Campaign.mission_ids():
		var pr := Campaign.problems(Campaign.mission(id))
		check("mission %s: data checks out" % id, pr.is_empty(), "; ".join(pr))
	var texts: Array = Campaign.index_strings()
	for id in Campaign.mission_ids():
		texts.append_array(Campaign.strings_of(Campaign.mission(id)))
	var miss: Array = []
	for t in texts:
		if not LangPt.T.has(t) or not LangEs.T.has(t):
			miss.append(String(t).left(50))
	check("every campaign text has pt and es", miss.is_empty(), " | ".join(miss))
	# who sits where
	var c := Campaign.make_cfg("p01_revolt", "solo")
	check("solo: you, scripted horse, scripted rebels", c["slots"].map(func(s): return s["who"]) == ["you", "script", "script"], str(c["slots"].map(func(s): return s["who"])))
	c = Campaign.make_cfg("p01_revolt", "coop", "p1", true)
	check("co-op online: you, friend, scripted rebels", c["slots"].map(func(s): return s["who"]) == ["you", "remote", "script"])
	c = Campaign.make_cfg("p01_revolt", "versus", "p1", true)
	check("versus online: you (crown), scripted horse, friend (rebels)", c["slots"].map(func(s): return s["who"]) == ["you", "script", "remote"])
	c = Campaign.make_cfg("p01_revolt", "versus", "p2", true)
	check("versus online, host plays the rebels", c["slots"].map(func(s): return s["who"]) == ["remote", "script", "you"])
	check("crown and rebels on opposite sides", c["slots"][0]["side"] != c["slots"][2]["side"] and c["slots"][0]["side"] == c["slots"][1]["side"])
	# a campaign-only faction plays its stand-in until it exists
	check("campaign-only faction -> stand-in", Campaign.engine_faction({"factions": {"tribes": {"stand_in": "crown"}}}, "tribes") == "crown")
	check("only the prologue is open at first", Campaign.unlocked("p01_revolt") and not Campaign.storyline_open(Campaign.storylines()[1]))


func _start(mode: String, seat := "p1") -> Game:
	main.start(Campaign.make_cfg("p01_revolt", mode, seat))
	await process_frame
	await process_frame
	paused = false
	return main.game


func _step(g: Game, to: float) -> void:
	g.clock = to
	g.mission._run_triggers()
	g.mission._check_objectives()


func _run() -> void:
	await process_frame
	_data()
	# ---------------------------------------------------------------- solo, won
	var g := await _start("solo")
	var r: MissionRun = g.mission
	check("the mission is on the game", r != null and r.mode == "solo")
	check("no computer player for scripted sides", g.ais.is_empty(), str(g.ais.size()))
	var col := r.team_index("column")
	var reb := r.team_index("rebels")
	check("the column: captain, 8 muskets, 2 horse", r.count({"team": "column"}) == 11, str(r.count({"team": "column"})))
	check("the column has no buildings", r.count({"team": "column", "buildings": true}) == 11)
	check("the rebels' hall is tagged", r.tagged("rebel_hall").size() == 1)
	var kinds := {}
	for b in g.buildings:
		if b.team == reb:
			kinds[b.kind] = true
	check("rebels: hall, farm, cottage, barracks", kinds.has("town_hall") and kinds.has("farm") and kinds.has("cottage") and kinds.has("barracks"), str(kinds.keys()))
	check("rebel hall at its spot", r.tagged("rebel_hall")[0].cell == Vector2i(14, 28))
	check("the camera starts at the camp", r.area_rect("camp").grow(200).has_point(g.camera.position))
	check("objectives: 4 for the crown", r.objectives_for("crown").size() == 4)
	_step(g, 1.5)
	check("intro lines said", r.said_ids.slice(0, 3) == ["i1", "i2", "tip1"], str(r.said_ids))
	check("versus-only lines not said in solo", not r.said_ids.has("r1"))
	await process_frame
	var ui: MissionUi = null
	for n in main.ui_layer.get_children():
		if n is MissionUi:
			ui = n
	check("the dialogue box shows a line", ui != null and ui._box.visible and ui._text.text != "")
	ui.skip_all()
	check("SKIP clears the lines", not ui._box.visible and ui.queue.is_empty())
	# three of the column at the ford: the sergeant speaks; 10 s later the militia counter-attacks
	var foot := r.tagged("column_foot")
	var fr := r.area_rect("ford")
	for i in 5:
		foot[i].position = fr.get_center() + Vector2(i * 14 - 28, 0)
	g._rebuild_hash()
	_step(g, 5.0)
	check("at the ford: line said", r.fired.has("at_ford") and r.said_ids.has("f1"))
	check("take the ford: done with five men", r.obj["ford"] == "done")
	_step(g, 5.5)
	check("ford taken (next check): the village is shown", r.fired.has("ford_taken") and not r.reveals.is_empty())
	_step(g, 16.0)
	check("militia counter-attack after the delay", r.fired.has("militia_go"))
	var mil: Array = r.tagged("militia")
	check("the militia were ordered out", not mil.is_empty() and mil[0].order != "hold", str(mil[0].order if not mil.is_empty() else ""))
	_step(g, 121.0)
	check("the Crown's horse arrives", r.tagged("relief").size() == 4 and r.said_ids.has("h1"))
	var hall: Building = r.tagged("rebel_hall")[0]
	hall.take_damage(50.0, null)
	_step(g, 122.0)
	check("hurt hall: the ringleader speaks", r.said_ids.has("b1"))
	check("not over yet", not g.over)
	hall.take_damage(999999.0, null)
	_step(g, 123.0)
	check("hall burned: the crown wins", g.over and r.winner_side == "crown", "%s %s" % [g.over, r.winner_side])
	check("the winner is a crown team", g.winner == col or g.winner == r.team_index("horse"))
	check("the captain's protect is settled done", r.obj["captain"] == "done")
	await create_timer(1.6).timeout
	check("the mission's end screen shows", main.ui_layer.find_child("MissionEnd", true, false) != null)
	var p := Campaign.progress()
	check("progress: the prologue is done", (p["done"] as Dictionary).has("p01_revolt"))
	check("the explorer and clockmaker storylines open", Campaign.storyline_open(Campaign.storylines()[1]) and Campaign.storyline_open(Campaign.storylines()[2]))
	var tk: Dictionary = Campaign.storylines()[0]["hub"]["talks"]["captain"]
	check("the captain's talk changed after the mission", String(CampaignMenu.talk_lines(tk, p)[0]).begins_with("Well done"))
	# ---------------------------------------------------------------- solo, lost: the captain killed
	main._to_menu()
	g = await _start("solo")
	r = g.mission
	_step(g, 2.0)
	r.tagged("captain")[0].die()
	_step(g, 3.0)
	check("captain killed: the rebels win", g.over and r.winner_side == "rebels")
	# ---------------------------------------------------------------- versus (offline: the rebels scripted): they hold out
	main._to_menu()
	g = await _start("versus")
	r = g.mission
	_step(g, 2.0)
	check("versus: the rebels' own lines are said (shown to the rebels only)", r.said_ids.has("r1"))
	_step(g, 481.0)
	check("rebels hold eight minutes: they win", g.over and r.winner_side == "rebels")
	# ---------------------------------------------------------------- online, without a network: the room and a guest's mission
	var l := NetLobby.new()
	l.is_host = true
	root.add_child(l)
	l.set_campaign("p01_revolt", "coop")
	var lc := l.make_cfg()
	check("campaign room: the mission's map and seats", l.map == "campaign:ford_village" and l.slots.map(func(s): return s["who"]) == ["you", "remote", "script"])
	check("campaign room: the match setup carries the mission", lc.has("campaign") and lc["campaign"]["mode"] == "coop")
	var gc := l._guest_cfg(lc, 1)
	check("the guest's setup carries the mission too", gc.has("campaign") and gc["slots"][1]["who"] == "you")
	l.free()
	main._to_menu()
	g = await _start("coop")
	var guest := MissionRun.new()
	guest.game = g
	guest.setup(Campaign.mission("p01_revolt"), "coop", Campaign.make_cfg("p01_revolt", "coop"), true)
	var heard: Array = []
	guest.said.connect(func(ln: Dictionary) -> void: heard.append(ln["id"]))
	guest.on_net({"t": "camp", "k": "say", "ids": ["i1", "r1"]})
	check("guest: a line for its side is shown, the foe's is not", heard == ["i1"], str(heard))
	var ob := guest.obj.duplicate()
	ob["ford"] = "done"
	guest.on_net({"t": "camp", "k": "obj", "o": ob})
	check("guest: objectives follow the host's", guest.obj["ford"] == "done")
	guest.check_end()
	check("guest: never decides the end itself", not g.over)
	guest.free()
	# ---------------------------------------------------------------- the menu pages build
	main._to_menu()
	await process_frame
	main.show_campaign()
	await process_frame
	check("the hub has its hotspots", main.menu.find_child("Hotspot_war_table", true, false) != null and main.menu.find_child("HotspotList_captain", true, false) != null)
	CampaignMenu.war_table(main)
	await process_frame
	check("the war table lists the mission", main.menu.find_child("Mission_p01_revolt", true, false) != null)
	CampaignMenu.briefing(main, "p01_revolt")
	await process_frame
	check("the briefing has START", main.menu.find_child("Briefing_Start", true, false) != null)
	_finish()
