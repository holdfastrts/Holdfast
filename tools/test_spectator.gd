extends SceneTree
## THE SPECTATOR OVERHAUL (0.27.0, docs/spectator.md): the PRODUCTION, ARMY & STRUCTURES and AI STORY panels and the
## narrator. A 4-player computer match is watched for a few minutes:
##  - each panel's player dropdown is its own (and none follows VIEW);
##  - ARMY & STRUCTURES counts each player's army, workers and buildings right; PRODUCTION lists queues;
##  - the AI STORY has every computer's plan, decisions with reasons, in plain sentences; repeats are dropped,
##    bursts of details limited, lines of one kind merged; the phrase book's rows fit their patterns and are translated;
##  - the narrator (pretended voice) never speaks two lines at once, drops a pile-up, and mute stops it;
##  - the AI lines go into the replay being recorded;
##  - a match you play has none of it (no story, no panels, N does nothing).
##   godot --headless --fixed-fps 30 --script res://tools/test_spectator.gd
var main: Node
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-66s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _wait(g, secs: float) -> void:
	var c0: float = g.clock
	var n := 0
	while g.clock < c0 + secs and n < int(secs * 45) + 200:
		await process_frame
		n += 1


func _run() -> void:
	await process_frame
	var keep_narr := Settings.narrator
	Settings.narrator = true
	main.start({"map": "twin_crowns", "seed": 7, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"},
		{"who": "normal", "faction": "brood", "colour": 2, "side": 2, "strategy": "rush"},
		{"who": "normal", "faction": "crown", "colour": 3, "side": 3, "strategy": "economy"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	paused = false
	check("watching: spectator, AI story and narrator made", g.spectating() and g.ai_story != null and g.ai_story.narrator != null)
	var st: AIStory = g.ai_story
	var nar: Narrator = st.narrator
	nar.fake = true
	nar.available = true
	var sp: SpecPanels = g.hud.spec_panels()
	check("panels: a panel set for the HUD", sp != null and sp.game == g)
	await _wait(g, 4.0)
	# ---- the plan at the start: one per computer
	var plans := st.entries.filter(func(e: Dictionary) -> bool: return String(e["tag"]) == "plan")
	check("story: a plan line for each of the 4 computers", plans.size() >= 4, str(plans.size()))
	check("story: the Brood's rush plan told", st.feed(2).any(func(e: Dictionary) -> bool: return st.text_of(e).contains("rush")), st.text_of(st.feed(2).back()) if not st.feed(2).is_empty() else "")
	check("story: the Crown's opening told", st.feed(0).any(func(e: Dictionary) -> bool: return String(e["tag"]) == "opening"))

	# ---- the phrase book
	var bad: Array = []
	for i in AIStoryLines.RULES.size():
		var r: Array = AIStoryLines.RULES[i]
		var rx := RegEx.new()
		if rx.compile(String(r[0])) != OK:
			bad.append("compile %d" % i)
			continue
		if String(r[1]) != "" and String(r[1]).count("%s") != rx.get_group_count() + 1:
			bad.append("args %d %s" % [i, r[0]])
	check("phrase book: every pattern compiles and fits its sentence", bad.is_empty(), str(bad))
	var untrans: Array = []
	var tpls: Array = []
	for r in AIStoryLines.RULES:
		if String(r[1]) != "":
			tpls.append(String(r[1]))
	tpls.append_array(AIStoryLines.PLANS.values())
	tpls.append_array(["%s starts a new base (base %s).", "%s starts its first %s: new tech.", "%s starts its first %s, to make %s."])
	for tp in tpls:
		for code in ["pt", "es"]:
			if not Loc.table(code).has(tp):
				untrans.append("%s: %s" % [code, tp])
	check("phrase book: every sentence has pt and es", untrans.is_empty(), str(untrans.slice(0, 4)))

	# ---- a computer's log line becomes a narrator sentence with its reason
	var n0 := st.entries.size()
	var rec0 := AIStory.recorded
	g.mlog.ai_team = 0
	g.mlog.add("%s's rush: FAILED (the riders are dead): the riders ride home, no more go out alone; it builds up and attacks only with a proper force" % g.mlog.who(0))
	g.mlog.ai_team = -1
	var last: Dictionary = st.entries.back()
	check("story: a log line is rewritten (rush failed, its reason, big)", st.entries.size() == n0 + 1 and String(last["tag"]) == "rush" and int(last["prio"]) == 3
		and st.text_of(last).contains("the riders are dead") and st.text_of(last).begins_with("P1"), st.text_of(last))
	check("replay: the AI line is written into the replay being recorded", g.rec != null and AIStory.recorded > rec0, "%d" % AIStory.recorded)
	g.mlog.add("%s's rush: FAILED (the riders are dead): the riders ride home" % g.mlog.who(0))      # (not in an AI's think)
	check("story: a line written outside a computer's think is not a decision", st.entries.size() == n0 + 1)

	# ---- de-duplicated, rate-limited, merged
	var d0 := st.dropped
	check("story: the same sentence again is dropped", not st.tell(0, String(last["tpl"]), last["args"], 3, "rush"))
	var kept := 0
	st._minor_t.erase(1)       # (the computer's own minor line a moment before would drop the whole burst: QA 2026-11-08)
	for i in 5:
		if st.tell(1, "%s sends a %s to scout.", ["Winder %d" % i], 1, "scout"):
			kept += 1
	check("story: a burst of 5 details keeps 1", kept == 1, "%d kept, %d dropped" % [kept, st.dropped - d0])
	var m0 := st.merged
	var size0 := st.entries.size()
	st.tell(1, "%s walls off its ramp: %s pieces.", ["6"], 2, "wall")
	st.tell(1, "%s walls its ramp in a hurry, %s pieces: it fears a rush.", ["8"], 2, "wall")
	check("story: two lines of one kind close together are merged", st.entries.size() == size0 + 1 and st.merged == m0 + 1 and st.text_of(st.entries.back()).contains("×2"),
		st.text_of(st.entries.back()))

	# ---- the dropdowns: each its own, none follows VIEW
	SpecPanels.team["prod"] = -1
	SpecPanels.team["army"] = -1
	SpecPanels.team["story"] = -1
	for p in SpecPanels.PANELS:
		SpecPanels.open[p] = true
	var parts := sp.parts()
	sp.press((parts["army"]["drop"] as Rect2).get_center())
	check("dropdown: the ARMY button opens its list", sp.drop == "army" and sp.drop_rows().size() == 5, "%s %d" % [sp.drop, sp.drop_rows().size()])
	var row2: Array = sp.drop_rows().filter(func(r: Array) -> bool: return int(r[1]) == 2)[0]
	sp.press((row2[0] as Rect2).get_center())
	check("dropdown: picking P3 sets only ARMY", SpecPanels.team["army"] == 2 and SpecPanels.team["prod"] == -1 and SpecPanels.team["story"] == -1 and sp.drop == "",
		str(SpecPanels.team))
	sp.press((sp.parts()["prod"]["drop"] as Rect2).get_center())
	var row1: Array = sp.drop_rows().filter(func(r: Array) -> bool: return int(r[1]) == 1)[0]
	sp.press((row1[0] as Rect2).get_center())
	sp.press((sp.parts()["story"]["drop"] as Rect2).get_center())
	var story_rows := sp.drop_rows()
	check("dropdown: the AI STORY lists All AIs and the 4 computers", story_rows.size() == 5 and String(story_rows[0][3]) == "All AIs", str(story_rows.map(func(r: Array) -> String: return r[3])))
	sp.press((story_rows[4][0] as Rect2).get_center())
	check("dropdown: three panels, three picks", SpecPanels.team["prod"] == 1 and SpecPanels.team["army"] == 2 and SpecPanels.team["story"] == 3, str(SpecPanels.team))
	g.spectator.set_mode("follow", 0, true)
	check("dropdown: VIEW changes nothing in the panels", g.view_team == 0 and SpecPanels.team["prod"] == 1 and SpecPanels.team["army"] == 2 and SpecPanels.team["story"] == 3)
	check("dropdown: each panel shows its pick", sp.teams_of("prod") == [1] and sp.teams_of("army") == [2] and sp.teams_of("story") == [3])
	g.spectator.set_mode("all", 0, true)
	sp.press((sp.parts()["army"]["title"] as Rect2).get_center())
	check("panel: the title closes ARMY alone", not SpecPanels.open["army"] and SpecPanels.open["prod"] and SpecPanels.open["story"])
	sp.press((sp.parts()["army"]["title"] as Rect2).get_center())
	check("panel: and opens it again", SpecPanels.open["army"])
	var lay := sp.layout()
	var overlap := false
	for a in SpecPanels.PANELS:
		for b in SpecPanels.PANELS:
			if a < b and (lay[a][0] as Rect2).merge(lay[a][1]).grow(-1).intersects((lay[b][0] as Rect2).merge(lay[b][1]).grow(-1)):
				overlap = true
	check("panel: the three panels don't overlap each other", not overlap)
	check("panel: the column stays off the command card", not (lay["story"][1] as Rect2).grow(-1).intersects(g.hud.card_rect()), "%s / %s" % [str(lay["story"][1]), str(g.hud.card_rect())])
	SpecPanels.team["prod"] = -1
	SpecPanels.team["army"] = -1
	SpecPanels.team["story"] = -1

	# ---- the match plays on: counts and decisions
	await _wait(g, 230.0)
	var cnt_bad: Array = []
	for t in 4:
		var a := sp.army_info(t)
		var want_army := 0
		var want_wk := 0
		for u in g.units:
			if u.team == t and not u.dead and u.kind != "horse" and u.kind != BroodNew.EGG:
				if u.is_worker():
					want_wk += 1
				else:
					want_army += 1
		var want_b := g.buildings.filter(func(b: Building) -> bool: return b.team == t and not b.dead and not b.ghost).size()
		var got_army: int = (a["army"] as Array).reduce(func(s: int, x: Array) -> int: return s + int(x[1]), 0)
		var got_wk: int = (a["workers"] as Array).reduce(func(s: int, x: Array) -> int: return s + int(x[1]), 0)
		var got_b: int = (a["buildings"] as Array).reduce(func(s: int, x: Array) -> int: return s + int(x[1]) + int(x[2]), 0)
		print("  P%d army %d/%d workers %d/%d buildings %d/%d value %d supply %d/%d" % [t + 1, got_army, want_army, got_wk, want_wk, got_b, want_b, a["value"], a["sup"], a["cap"]])
		if got_army != want_army or got_wk != want_wk or got_b != want_b or int(a["value"]) != g.army_value(t) or int(a["sup"]) != g.supply_used(t):
			cnt_bad.append(t + 1)
	check("army panel: every player's army, workers, buildings, value and supply right", cnt_bad.is_empty(), str(cnt_bad))
	check("army panel: the Crown's resources with gold, powder and horses", (sp.army_info(0)["res"] as Array).map(func(r: Array) -> String: return r[0]) == ["res_gold", "res_powder", "res_horses"])
	check("army panel: the Brood has no buildings, units only", (sp.army_info(2)["buildings"] as Array).is_empty() and not (sp.army_info(2)["workers"] as Array).is_empty())
	var prod_any := false
	for t in 4:
		if not g.hud.prod_items(t).is_empty():
			prod_any = true
	check("production panel: something in production", prod_any)
	var tags := {}
	for e in st.entries:
		tags[String(e["tag"])] = int(tags.get(String(e["tag"]), 0)) + 1
	print("  story: %d lines, tags %s, %d dropped, %d merged" % [st.entries.size(), str(tags), st.dropped, st.merged])
	for e in st.feed().slice(0, 14):
		print("    %5.0f P%d [%d] %s" % [float(e["t"]), int(e["team"]) + 1, int(e["prio"]), st.text_of(e)])
	check("story: decisions beyond the plan (attack, tech, expand, defend, wall...)", tags.keys().filter(func(k: String) -> bool: return k in ["attack", "tech", "expand", "defend", "wall", "raid", "rush"]).size() >= 2, str(tags))
	check("story: every line reads whole (no %s, no ?)", st.entries.all(func(e: Dictionary) -> bool: var x := st.text_of(e); return not x.contains("%s") and not x.contains("?")))
	var same := 0
	for i in st.entries.size():
		for j in range(i + 1, st.entries.size()):
			var a: Dictionary = st.entries[i]
			var b: Dictionary = st.entries[j]
			if a["team"] == b["team"] and a["tpl"] == b["tpl"] and a["args"] == b["args"] and float(b["t"]) - float(a["t"]) < AIStory.SAME:
				same += 1
	check("story: no sentence repeated within %d s" % int(AIStory.SAME), same == 0, str(same))
	Loc.set_lang("pt")
	var pt_line := st.text_of(plans[0])
	Loc.set_lang("es")
	var es_line := st.text_of(plans[0])
	Loc.set_lang("en")
	check("story: told in Portuguese and Spanish", pt_line != st.text_of(plans[0]) and es_line != st.text_of(plans[0]), pt_line + " | " + es_line)

	# ---- the narrator: one line at a time, a pile-up dropped, mute stops it
	var hist: Array = nar.history.duplicate()
	var overl := 0
	for i in range(1, hist.size()):
		if float(hist[i - 1][1]) < 0.0 or float(hist[i][0]) < float(hist[i - 1][1]) - 0.001:
			overl += 1
	print("  narrator: %d lines spoken, %d dropped" % [hist.size(), nar.dropped])
	check("narrator: spoke the big decisions", hist.size() >= 3, str(hist.size()))
	check("narrator: never two lines at once", overl == 0, str(overl))
	check("narrator: the player said in words", hist.all(func(h: Array) -> bool: return not String(h[2]).contains("P1 ")) and String(hist[0][2]).contains("Player"), String(hist[0][2]))
	for i in 6:
		nar.say("Line number %d for the pile." % i, 3)
	check("narrator: a pile-up keeps at most %d waiting" % Narrator.PILE, nar.queue.size() <= Narrator.PILE and nar.is_speaking(), str(nar.queue.size()))
	sp.toggle_voice()
	check("narrator: mute stops it at once", not Settings.narrator and nar.queue.is_empty() and nar.speaking == "" and not nar.is_speaking())
	nar.say("Not to be heard.", 3)
	st.tell(0, "%s resigns: good game.", [], 3, "end")
	check("narrator: muted, nothing more is said", nar.queue.is_empty() and nar.speaking == "")
	sp.toggle_voice()
	check("narrator: unmuted again", Settings.narrator)
	main._to_menu()
	await process_frame
	await process_frame

	# ---- a match you play: nothing of it
	var rec_before := AIStory.recorded
	main.start({"map": "twin_crowns", "seed": 3, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g2: Game = main.game
	g2.hud.countdown = 0.0
	paused = false
	await _wait(g2, 40.0)
	check("your match: not spectating, no AI story", not g2.spectating() and g2.ai_story == null)
	check("your match: no spectator panels made or drawn", g2.hud._spec == null)
	var ev := InputEventKey.new()
	ev.keycode = KEY_N
	ev.pressed = true
	var narr_before := Settings.narrator
	g2.controls._key(ev)
	check("your match: N does nothing to the narrator", Settings.narrator == narr_before and g2.hud._spec == null)
	print("  your match: %d computer lines recorded for the replay" % (AIStory.recorded - rec_before))
	main._to_menu()
	Settings.narrator = keep_narr
	Settings.save_all()
	for i in 30:
		await process_frame          # (the match's last save finishes before the quit)
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
