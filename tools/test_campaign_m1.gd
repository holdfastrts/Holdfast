extends SceneTree
## Campaign mission 1, "The Leaf and the Fire" (docs/campaign_m1_build.md): the mission's data checks out and every text
## has pt and es; the seats for solo / co-op / versus; the start (the plantation, the fort, the camps, the rebels' roles:
## the Pikeman's own strips, Varenne's name, the torches); part 1 at night (the waves come out of the fields, a torch
## burns a barn, Varenne shouts, dawn with three barns); part 2 (the camps, the CHOICE: save the families or march on,
## each with its effect); part 3 (the gate, the canister hint pointing at the card, "Canister. On my word.", the charge
## broken: the mission is won, the ending's stills play, the choice is kept); the losses (the manor, every barn, too few
## barns at dawn); the opening's stills and lines; the voice hook.
##   godot --headless --fixed-fps 30 --script res://tools/test_campaign_m1.gd
## Prints CHECK lines, then "campaign_m1: N failures"; exit code 1 on a failure. (Leaves user://campaign.json as it was.)
const MID := "p01_leaf"
var main: Node
var fails := 0
var _kept := ""


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-66s %s %s" % [name, "ok" if ok else "FAIL", detail])
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
	print("campaign_m1: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _start(mode: String, seat := "p1") -> Game:
	if main.game:
		main._to_menu()
		await process_frame
	main.start(Campaign.make_cfg(MID, mode, seat))
	await process_frame
	await process_frame
	paused = false
	return main.game


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


func _ui() -> MissionUi:
	for n in main.ui_layer.get_children():
		if n is MissionUi:
			return n
	return null


func _data() -> void:
	var m := Campaign.mission(MID)
	var pr := Campaign.problems(m)
	check("p01_leaf: data checks out", pr.is_empty(), "; ".join(pr))
	check("the prologue is p01_leaf", (Campaign.storylines()[0]["missions"] as Array) == [MID])
	var miss: Array = []
	for t in Campaign.strings_of(m) + Campaign.index_strings():
		if not LangPt.T.has(t) or not LangEs.T.has(t):
			miss.append(String(t).left(50))
	check("every text of the mission has pt and es", miss.is_empty(), " | ".join(miss))
	var c := Campaign.make_cfg(MID, "solo")
	check("solo: you, scripted guns, families and rebels", c["slots"].map(func(s): return s["who"]) == ["you", "script", "script", "script"])
	c = Campaign.make_cfg(MID, "coop", "p1", true)
	check("co-op online: you and a friend (the guns), the rebels scripted", c["slots"].map(func(s): return s["who"]) == ["you", "remote", "script", "script"])
	c = Campaign.make_cfg(MID, "versus", "p1", true)
	check("versus online: the friend plays the Free Assembly", c["slots"].map(func(s): return s["who"]) == ["you", "script", "script", "remote"])
	check("the Free Assembly plays as a Crown stand-in, green", c["slots"][3]["faction"] == "crown" and int(c["slots"][3]["colour"]) == 2)
	check("the Crown is purple", int(c["slots"][0]["colour"]) == 4)
	check("the Pikeman is a unit again (campaign only, trained nowhere)", Defs.UNITS.has("pikeman") and Defs.UNITS["pikeman"].get("campaign_only", false) and String(Defs.UNITS["pikeman"]["from"]) == "")
	check("the Pikeman's strips are in", ArtData.UNITS.has("pikeman") and ResourceLoader.exists("res://assets/units/pikeman/attack_e.png") and ResourceLoader.exists("res://assets/units/pikeman/walk_n.png"))
	check("every rebel role names a real unit", Rebels.ROLES.values().all(func(r): return Defs.UNITS.has(String(r["kind"]))))
	for k in m["stills"]:
		check("still %s: its picture loads" % k, ResourceLoader.exists(String(m["stills"][k]["image"])))


func _run() -> void:
	await process_frame
	_data()
	# ---------------------------------------------------------------- the opening (StillShow)
	var m := Campaign.mission(MID)
	var done := [false]
	var sh := StillShow.play(main.ui_layer, m, Campaign.show_pages(m, "opening"), func() -> void: done[0] = true)
	await process_frame
	check("the opening shows a still with its picture", sh._still != null and sh._still._tex != null)
	check("the opening's first line is the King's, named THE KING", sh._name.text == "THE KING" and sh._text.text.begins_with("You ask how"), sh._name.text)
	for i in 10:
		if not done[0]:
			sh.next()
	check("the opening: all seven lines in order, then it ends", sh.shown_ids == ["k_open1", "k_open2", "k_open3", "t_open3", "k_open4", "f_open5", "t_open5"] and done[0], str(sh.shown_ids))
	check("the King's recording is found (the owner's ElevenLabs take)", CampaignVoice.path_of(m, "k_open1") != "")
	check("no recording yet for Tomasz: the voice hook stays silent", CampaignVoice.path_of(m, "t_open3") == "" and CampaignVoice.play(main, m, "t_open3") == 0.0)
	check("the voice hook's path", ("%s/%s/%s.ogg" % [CampaignVoice.DIR, "p01", "k_open1"]) == "res://campaign/voice/p01/k_open1.ogg")
	await process_frame
	# ---------------------------------------------------------------- solo: the start
	var g := await _start("solo")
	var r: MissionRun = g.mission
	check("the mission is on", r != null and r.id == MID)
	check("no computer player (the rebels are scripted)", g.ais.is_empty())
	check("the manor stands", r.tagged("manor").size() == 1 and r.tagged("manor")[0].kind == "town_hall")
	check("five drying barns (Farms)", r.tagged("barns").size() == 5, str(r.tagged("barns").size()))
	check("the chapel", r.tagged("chapel").size() == 1 and r.tagged("chapel")[0].kind == "church")
	check("10 Musketeers, 2 cannons, the Governor and Tomasz", r.tagged("line").size() == 10 and r.tagged("guns").size() == 2 and r.tagged("fairleigh").size() == 1 and r.tagged("tomasz").size() == 1)
	check("the Governor's name over his bar", String(r.tagged("fairleigh")[0].get_meta("mission_name", "")) == "Lord Fairleigh")
	check("the fort's walls and gate", r.tagged("fort_wall").size() >= 70 and r.tagged("fort_gate").size() == 4, "%d %d" % [r.tagged("fort_wall").size(), r.tagged("fort_gate").size()])
	check("the mass in the fort: 14 militia + 8 pikemen", r.tagged("mass").size() == 22, str(r.tagged("mass").size()))
	check("the camps: 9 and 11 men", r.tagged("camp1").size() == 9 and r.tagged("camp2").size() == 11)
	var pike: Unit = null
	for u in r.tagged("mass"):
		if u.kind == "pikeman":
			pike = u
	check("a rebel pikeman wears the Pikeman's strips", pike != null and pike.art == "pikeman" and pike.sprite.texture != null)
	check("rebels in green", pike != null and int(g.colours[pike.team]) == 2)
	check("night", r.light_node != null and r.light_name == "night" and r.light_node.color.b > r.light_node.color.r)
	check("objectives: rising, manor, barns, dawn", r.objectives_for("crown").map(func(o): return o["id"]) == ["rising", "manor", "barns", "dawn"])
	_step(g, 2.0)
	check("the intro lines", r.said_ids.slice(0, 3) == ["p1_fair", "p1_rugg", "p1_tip"], str(r.said_ids))
	# ---------------------------------------------------------------- part 1: the waves, the torches, Varenne
	_step(g, 26.0)
	var night := r.tagged("night")
	check("wave 1 out of the fields: 4 militia, 2 torches", night.size() == 6, str(night.size()))
	var torches := night.filter(func(u): return u.has_meta("torch"))
	check("the torch-bearers carry torches", torches.size() == 2 and torches[0].kind == "labourer")
	check("the wave is sent at the plantation", night.all(func(u): return u.order != "hold" and u.order != "idle"), str(night.map(func(u): return u.order)))
	check("Varenne's first slogan", r.said_ids.has("v_1"))
	var barn: Building = r.tagged("barns")[0]
	var hp0 := barn.hp
	torches[0].position = barn.center() + Vector2(0, float(barn.size.y) * Defs.TILE * 0.5 + 6.0)
	for i in 8:
		Rebels.tick(r, 0.25)
	check("a torch at a barn sets it burning (6 a second)", barn.hp < hp0 - 10.0, "%d -> %d" % [hp0, barn.hp])
	_step(g, 27.0)
	check("a barn hurt: the Governor calls it", r.said_ids.has("f_barn"))
	_step(g, 141.0)
	check("Varenne comes, named on his bar", r.tagged("varenne").size() == 1 and String(r.tagged("varenne")[0].get_meta("mission_name", "")) == "Etienne Varenne")
	check("his slogan and the Governor's answer", r.said_ids.has("v_2") and r.said_ids.has("f_1"))
	for t in [151.0, 226.0, 261.0, 301.0, 386.0, 441.0]:
		_step(g, t)
	check("every wave of the night came", ["w2", "w3", "w4", "w5", "w6", "w7"].all(func(w): return r.fired.has(w)))
	check("the tobacco line", r.said_ids.has("r_leaf") and r.said_ids.has("f_leaf"))
	check("Lauds: the sky greys", r.said_ids.has("t_lauds") and r.light_name == "dawn")
	check("not over in the night", not g.over)
	# ---------------------------------------------------------------- dawn
	_step(g, 481.0)
	_step(g, 481.5)
	check("dawn with five barns: the march begins", r.fired.has("dawn") and r.obj["dawn"] == "done" and not g.over)
	check("the camps objective shows", r.obj["camps"] == "active")
	check("the night's rebels fall back", r.tagged("night").all(func(u): return u.order == "move"))
	check("reinforcements at the manor", r.tagged("relief").size() == 6)
	# ---------------------------------------------------------------- part 2: the camps, the choice (save)
	_kill(r, "camp1")
	_step(g, 490.0)
	check("first camp down: Hollins Farm, the families and the raiders", r.fired.has("camp1_down") and r.tagged("families").size() == 6 and r.tagged("raiders").size() == 5)
	check("the choice is offered", String(r.choice_open.get("id", "")) == "families")
	await process_frame
	var ui := _ui()
	var panel: Node = ui.find_child("Choice_families", true, false) if ui else null
	check("the choice panel with two buttons", panel != null and panel.find_child("Choose_save", true, false) != null and panel.find_child("Choose_leave", true, false) != null)
	ui.pick_choice("families", "save")
	check("SAVE: the flag is set", r.flags.get("families", "") == "save")
	check("SAVE: the families objective shows", r.obj["families"] == "active")
	check("SAVE: the rebels dig in (10 more at the gate, earthworks)", r.tagged("mass").size() == 32 and r.tagged("earthworks").size() == 2, "%d %d" % [r.tagged("mass").size(), r.tagged("earthworks").size()])
	_kill(r, "raiders")
	_step(g, 495.0)
	check("raiders gone: the families are saved", r.obj["families"] == "done" and r.said_ids.has("t_saved"))
	_kill(r, "camp2")
	_step(g, 500.0)
	check("both camps down: on to the gate", r.obj["camps"] == "done" and r.obj["gate"] == "active")
	# ---------------------------------------------------------------- part 3: the gate, canister
	var bg := r.area_rect("before_gate")
	var i2 := 0
	for u in r.tagged("line") + r.tagged("guns"):
		u.position = bg.get_center() + Vector2((i2 % 5) * 20 - 40, (i2 / 5) * 20 - 20)
		i2 += 1
	g._rebuild_hash()
	_step(g, 505.0)
	_step(g, 505.5)
	check("before the gate: the objective is met", r.obj["gate"] == "done" and r.fired.has("at_gate"))
	check("the canister lines", r.said_ids.has("r_mass") and r.said_ids.has("f_canister_load") and r.said_ids.has("tip_canister"))
	check("the hint points at the cannon's CANISTER button", String(r.pointer.get("ui", "")) == "card" and String(r.pointer.get("icon", "")) == "ab_canister")
	var gun: Unit = r.tagged("guns")[0]
	g.set_selection([gun])
	for k in 3:
		await process_frame
	var tg: Array = ui._pointer.target()
	var on_btn := false
	if g.hud:
		for b in g.hud._card_buttons:
			if b["item"] is Array and String(b["item"][0]) == "ab_canister":
				var xf: Transform2D = g.hud.get_global_transform()
				on_btn = tg[0] == "ui" and (tg[1] as Rect2).is_equal_approx(Rect2(xf * (b["rect"] as Rect2).position, xf.basis_xform((b["rect"] as Rect2).size)))
	if g.hud and (g.hud._card_buttons as Array).is_empty():
		# (headless runs never draw, so the card's buttons are never laid out: the pointer frames the whole card)
		var cr: Rect2 = g.hud._layout()["card"]
		var xf2: Transform2D = g.hud.get_global_transform()
		on_btn = tg[0] == "ui" and (tg[1] as Rect2).is_equal_approx(Rect2(xf2 * cr.position, xf2.basis_xform(cr.size)))
	check("with a cannon selected the pointer frames its CANISTER button (headless: the card)", on_btn, str(tg))
	gun.set_canister(true)
	check("canister loaded", gun.mode == "canister")
	_step(g, 509.0)
	check("SAVE: they are dug in", r.fired.has("dug_in") and r.said_ids.has("r_dug"))
	_step(g, 528.0)
	check("\"Canister. On my word.\"", r.said_ids.has("f_word") and r.pointer.is_empty())
	_step(g, 534.5)
	check("the charge", r.fired.has("charge_go") and r.said_ids.has("v_charge"))
	check("the mass charges the gate", r.tagged("mass").filter(func(u): return u.order == "hold").is_empty())
	_kill(r, "mass", 8)
	_step(g, 536.0)
	check("8 left (dug in): not broken yet", not g.over)
	_kill(r, "mass", 7)
	_step(g, 537.0)
	check("the charge broken: the Crown wins", g.over and r.winner_side == "crown", r.winner_side)
	await create_timer(1.8).timeout
	var show: Node = main.ui_layer.find_child("StillShow", true, false)
	check("the ending plays over the canister still", show != null and (show as StillShow)._still_id == "canister")
	if show:
		(show as StillShow).next()
		check("the ending: Tomasz, then the King", (show as StillShow).shown_ids == ["t_end", "k_end"], str((show as StillShow).shown_ids))
		(show as StillShow).next()
	await process_frame
	check("then the mission's end screen", main.ui_layer.find_child("MissionEnd", true, false) != null)
	check("the choice is kept: families = save", Campaign.flag(MID, "families") == "save")
	check("the storylines open", Campaign.storyline_open(Campaign.storylines()[1]) and Campaign.storyline_open(Campaign.storylines()[2]))
	# ---------------------------------------------------------------- solo again: MARCH ON
	g = await _start("solo")
	r = g.mission
	_step(g, 481.0)
	_step(g, 481.5)
	_kill(r, "camp1")
	_step(g, 485.0)
	await process_frame
	_ui().pick_choice("families", "leave")
	check("LEAVE: the flag is set, the fort as it was", r.flags.get("families", "") == "leave" and r.tagged("mass").size() == 22 and r.obj["families"] == "hidden")
	_step(g, 486.0)
	_step(g, 527.0)
	check("LEAVE: Hollins Farm burns, Tomasz remembers", r.fired.has("left") and r.tagged("hollins_farm").is_empty() and r.said_ids.has("t_left"))
	_kill(r, "camp2")
	_step(g, 530.0)
	for u in r.tagged("line"):
		u.position = r.area_rect("before_gate").get_center()
	g._rebuild_hash()
	_step(g, 531.0)
	_step(g, 531.5)
	check("LEAVE: part 3 reached", r.fired.has("at_gate") and not r.fired.has("dug_in"))
	_step(g, 560.0)
	_step(g, 567.0)
	_kill(r, "mass", 6)
	_step(g, 568.0)
	check("LEAVE: 6 left: not broken yet", not g.over)
	_kill(r, "mass", 5)
	_step(g, 569.0)
	check("LEAVE: the charge broken, the Crown wins", g.over and r.winner_side == "crown")
	await create_timer(1.8).timeout
	check("the choice is kept: families = leave", Campaign.flag(MID, "families") == "leave")
	# ---------------------------------------------------------------- the losses
	g = await _start("solo")
	r = g.mission
	_step(g, 30.0)
	_kill(r, "manor")
	_step(g, 31.0)
	check("the manor falls: the mission is lost", g.over and r.winner_side == "rebels")
	g = await _start("solo")
	r = g.mission
	_step(g, 30.0)
	_kill(r, "barns")
	_step(g, 31.0)
	check("every barn burns: the mission is lost", g.over and r.winner_side == "rebels")
	g = await _start("solo")
	r = g.mission
	_kill(r, "barns", 2)
	_step(g, 481.0)
	_step(g, 481.5)
	check("two barns at dawn: the year is lost", g.over and r.winner_side == "rebels" and r.said_ids.has("f_ash"))
	# ---------------------------------------------------------------- co-op and versus (offline: the friend's side scripted)
	g = await _start("coop")
	r = g.mission
	check("co-op: the guns are the second player's team", r.tagged("guns").all(func(u): return u.team == r.team_index("guns")) and r.tagged("guns").size() == 2)
	g = await _start("versus")
	r = g.mission
	_step(g, 2.0)
	check("versus: the Free Assembly's own lines", r.said_ids.has("r_intro"))
	main._to_menu()
	await process_frame
	# ---------------------------------------------------------------- the menu pages
	main.show_campaign()
	await process_frame
	check("the hub: the Governor's House", main.menu.find_child("HotspotList_fairleigh", true, false) != null)
	CampaignMenu.briefing(main, MID)
	await process_frame
	check("the briefing has START", main.menu.find_child("Briefing_Start", true, false) != null)
	_finish()
