class_name CampaignMenu
extends RefCounted
## The CAMPAIGN pages (docs/campaign_engine.md): the storylines and their missions (each opens in turn; progress is
## kept in user://campaign.json), the chosen mission with SOLO / CO-OP / VERSUS where it allows them, the BRIEFING
## (a still and the side's orders) and, after a mission, its END (won or lost, the still and words of the side that
## won, where the story goes next). CO-OP and VERSUS open an online room (NetLobby.set_campaign).

static var pick := ""            # the mission chosen on the list
static var line := ""            # the storyline whose hub is shown
static var mode := "solo"
static var seat := "p1"          # versus: which side the host plays ("p1" / "p2")


static func _side_col(m: Dictionary, side_id: String) -> Color:
	for tm in m.get("teams", []):
		if String(tm["side"]) == side_id:
			return Defs.colour_of(int(tm.get("colour", 0)))
	return Color(0.6, 0.5, 0.4)


static func _panel(parent: Control, minw := 0.0) -> VBoxContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = minw
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


static func _wrap(t: String, sz: int, col := UiStyle.TEXT) -> Label:
	var l := UiStyle.text(t, sz, col, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _frame(main: Node) -> VBoxContainer:
	var root: Control = main._page()
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 30)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	root.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	m.add_child(box)
	return box


# ------------------------------------------------------------------ the WAR TABLE: the storyline's missions

static func war_table(main: Node) -> void:
	var box := _frame(main)
	var p := Campaign.progress()
	var sl0 := _line_data()
	box.add_child(UiStyle.heading(Loc.t(String(sl0.get("hub", {}).get("title", sl0.get("title", "")))) + "  ·  " + Loc.t("WAR TABLE"), 34, UiStyle.TRIM))
	var ids: Array = (sl0.get("missions", []) as Array).map(func(x) -> String: return String(x))
	if pick == "" or not ids.has(pick) or not Campaign.unlocked(pick, p):
		pick = ""
		for x in ids:
			if Campaign.unlocked(x, p):
				pick = x
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	# left: the storylines, each with its missions
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.x = 420
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 12)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	for sl in [sl0]:
		var v := _panel(lv)
		var open := Campaign.storyline_open(sl, p)
		v.add_child(UiStyle.text(Loc.t(String(sl.get("title", ""))), 22, UiStyle.TRIM if open else UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		v.add_child(_wrap(Loc.t(String(sl.get("about", ""))), 15, UiStyle.MUTED))
		if not open:
			var req := Campaign.mission(String(sl.get("requires", "")))
			v.add_child(_wrap(Loc.t("Opens after: %s") % Loc.t(String(req.get("title", ""))), 15, UiStyle.MUTED))
			continue
		if (sl.get("missions", []) as Array).is_empty():
			v.add_child(_wrap(Loc.t("The missions are being written."), 15, UiStyle.MUTED))
		for mid in sl.get("missions", []):
			var m := Campaign.mission(String(mid))
			var ok := Campaign.unlocked(String(mid), p)
			var t: String = Loc.t(String(m.get("title", mid))) if ok else Loc.t("(locked)")
			var done: Dictionary = (p["done"] as Dictionary).get(String(mid), {})
			if not done.is_empty():
				t += "   " + Loc.t("(won by %s)") % Loc.t(Campaign.side_name(m, String(done.get("won_by", ""))))
			var b: Button = main._button(t, func() -> void:
				pick = String(mid)
				war_table(main))
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = not ok
			b.name = "Mission_" + String(mid)
			if String(mid) == pick:
				UiStyle.chosen(b)
			v.add_child(b)
	# right: the chosen mission
	var rv := _panel(body)
	rv.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pick != "":
		var m := Campaign.mission(pick)
		var modes := Campaign.modes_of(m)
		if not modes.has(mode):
			mode = "solo"
		var my_side := Campaign.seat_side(m, mode, seat if mode == "versus" else "p1")
		rv.add_child(UiStyle.heading(Loc.t(String(m.get("title", pick))), 32, UiStyle.TRIM))
		var br: Dictionary = m.get("briefing", {}).get(my_side, {})
		var sv := StillView.make(m.get("stills", {}).get(String(br.get("still", "")), {}), _side_col(m, my_side))
		sv.custom_minimum_size = Vector2(0, 220)
		sv.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rv.add_child(sv)
		rv.add_child(_wrap(Loc.t(String(m.get("summary", ""))), 17))
		var mrow := HBoxContainer.new()
		mrow.add_theme_constant_override("separation", 8)
		rv.add_child(mrow)
		for md in Campaign.MODES:
			var b: Button = main._button(Campaign.MODE_LABEL[md], func() -> void:
				mode = md
				war_table(main))
			b.name = "Mode_" + md
			b.custom_minimum_size = Vector2(130, 50)
			b.disabled = not modes.has(md)
			if md == mode:
				UiStyle.chosen(b)
			mrow.add_child(b)
		var about := {"solo": "You against the computer.", "coop": "You and a friend online on the same side, against the computer.",
			"versus": "You and a friend online on opposite sides: the story follows whoever wins."}
		rv.add_child(_wrap(Loc.t(about[mode]), 15, UiStyle.MUTED))
		if mode == "versus":
			var srow := HBoxContainer.new()
			srow.add_theme_constant_override("separation", 8)
			rv.add_child(srow)
			srow.add_child(UiStyle.text(Loc.t("YOU PLAY:"), 16, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
			for st in ["p1", "p2"]:
				var sd := Campaign.seat_side(m, "versus", st)
				var b: Button = main._button(Loc.t(Campaign.side_name(m, sd)).to_upper(), func() -> void:
					seat = st
					war_table(main))
				b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
				b.custom_minimum_size = Vector2(190, 46)
				if st == seat:
					UiStyle.chosen(b, _side_col(m, sd))
				srow.add_child(b)
		var go: Button = main._button("BRIEFING" if mode == "solo" else "OPEN AN ONLINE ROOM", func() -> void:
			if mode == "solo":
				briefing(main, pick)
			else:
				host_online(main, pick, mode, seat if mode == "versus" else "p1"))
		go.name = "Campaign_Go"
		UiStyle.primary(go)
		go.custom_minimum_size = Vector2(0, 60)
		rv.add_child(go)
	var back: Button = main._button("BACK", func() -> void: show(main))
	main._set_back(back)
	back.custom_minimum_size = Vector2(240, 56)
	box.add_child(back)


## CO-OP / VERSUS: host an online room for the mission (the friend joins with the code from ONLINE).
static func host_online(main: Node, mid: String, md: String, st: String) -> void:
	var relay_ok: bool = not Settings.relay_url.contains("YOURNAME") and Settings.relay_url.strip_edges() != ""
	if relay_ok:
		var l := NetLobby.new()
		main.add_child(l)
		main.net_lobby = l
		l.host(Settings.relay_url, NetLink.new_code())
		l.set_campaign(mid, md, st)
	main.show_online()
	var mm: Node = main.menu.get_child(0) if main.menu and main.menu.get_child_count() > 0 else null
	if mm is MultiplayerMenu and main.net_lobby:
		main.net_lobby.changed.connect((mm as MultiplayerMenu)._on_changed)
		main.net_lobby.failed.connect((mm as MultiplayerMenu)._on_failed)


# ------------------------------------------------------------------ the briefing

static func briefing(main: Node, mid: String) -> void:
	var m := Campaign.mission(mid)
	var side := Campaign.seat_side(m, "solo", "p1")
	var br: Dictionary = m.get("briefing", {}).get(side, {})
	var box := _frame(main)
	box.add_child(UiStyle.heading(Loc.t("BRIEFING"), 22, UiStyle.MUTED))
	box.add_child(UiStyle.heading(Loc.t(String(m.get("title", mid))), 40, UiStyle.TRIM))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var sv := StillView.make(m.get("stills", {}).get(String(br.get("still", "")), {}), _side_col(m, side))
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.size_flags_stretch_ratio = 1.3
	body.add_child(sv)
	var v := _panel(body)
	v.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiStyle.text(Loc.t("You lead: %s") % Loc.t(Campaign.side_name(m, side)), 20, _side_col(m, side).lightened(0.35), HORIZONTAL_ALIGNMENT_LEFT, true))
	for t in br.get("text", []):
		v.add_child(_wrap(Loc.t(String(t)), 18))
	v.add_child(UiStyle.text(Loc.t("OBJECTIVES"), 18, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	for o in m.get("objectives", []):
		if String(o.get("side", "")) == side and not bool(o.get("hidden", false)):
			var pre := "-  " if bool(o.get("primary", true)) else "-  " + Loc.t("(optional)") + " "
			v.add_child(_wrap(pre + Loc.t(String(o["text"])), 16, UiStyle.TEXT if bool(o.get("primary", true)) else UiStyle.MUTED))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var back: Button = main._button("BACK", func() -> void: war_table(main))
	main._set_back(back)
	back.custom_minimum_size = Vector2(200, 60)
	row.add_child(back)
	var go: Button = main._button("START", func() -> void:
		Sfx.play_any(["ui/start_match"])
		main.start(Campaign.make_cfg(mid, "solo")))
	go.name = "Briefing_Start"
	go.custom_minimum_size = Vector2(300, 60)
	go.add_theme_font_size_override("font_size", 28)
	UiStyle.primary(go)
	row.add_child(go)


# ------------------------------------------------------------------ the end of a mission

## Over the finished match: VICTORY / DEFEAT (versus: who won), the winners' still and words, where the story goes
## (the next mission, the storylines it opens), and NEXT MISSION / PLAY AGAIN / BATTLE REPORT / CAMPAIGN.
static func mission_end(main: Node, game: Game, winner: int, rp_path: String) -> void:
	var run := game.mission
	var m := run.data
	var mid := run.id
	var win_side := run.winner_side_of(winner) if winner >= 0 else ""
	var mine := run.my_side()
	var nxt := Campaign.record(mid, run.mode, win_side, mine)
	var won := win_side != "" and win_side == mine
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.theme = UiStyle.theme()
	o.process_mode = Node.PROCESS_MODE_ALWAYS
	o.name = "MissionEnd"
	main.ui_layer.add_child(o)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(cc)
	var v := _panel(cc, 820)
	var title := ("VICTORY" if won else "DEFEAT") if run.mode != "versus" else (Loc.t("%s WIN") % Loc.t(Campaign.side_name(m, win_side)).to_upper())
	v.add_child(UiStyle.heading(Loc.t(title), 44, UiStyle.GOOD if won else UiStyle.BAD))
	var db: Dictionary = m.get("debrief", {}).get(win_side, {})
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var sv := StillView.make(m.get("stills", {}).get(String(db.get("still", "")), {}), _side_col(m, win_side))
	sv.custom_minimum_size = Vector2(380, 230)
	h.add_child(sv)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UiStyle.text(Loc.t(String(db.get("title", ""))), 24, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	tv.add_child(_wrap(Loc.t(String(db.get("text", ""))), 17))
	# the objectives as they ended
	for ob in run.objectives_for(mine):
		var mark: String = {"done": "[+] ", "failed": "[x] ", "active": "[ ] "}.get(String(ob["state"]), "")
		tv.add_child(_wrap(mark + Loc.t(String(ob["text"])), 14, UiStyle.GOOD if ob["state"] == "done" else (UiStyle.BAD if ob["state"] == "failed" else UiStyle.MUTED)))
	# where the story goes
	var story := ""
	if won or run.mode == "versus":
		if nxt != "":
			story = Loc.t("The story goes on: %s") % Loc.t(String(Campaign.mission(nxt).get("title", nxt)))
		else:
			var opened: Array = Campaign.opens(mid).map(func(sl: Dictionary) -> String: return Loc.t(String(sl.get("title", ""))))
			story = (Loc.t("New storylines open: %s") % ", ".join(opened)) if not opened.is_empty() else Loc.t("The next mission is being written.")
	else:
		story = Loc.t("Try again: the story waits for a victory.")
	v.add_child(_wrap(story, 17, UiStyle.TRIM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var online: bool = game.net != null
	var btns: Array = []
	if nxt != "" and not online and Campaign.modes_of(Campaign.mission(nxt)).has("solo"):
		btns.append(["NEXT MISSION", func() -> void:
			main._to_menu()
			pick = nxt
			briefing(main, nxt)])
	if not online:
		btns.append(["PLAY AGAIN", func() -> void: main.start()])
	btns.append(["BATTLE REPORT", func() -> void:
		o.queue_free()
		main.show_battle_report(winner, rp_path)])
	btns.append(["CAMPAIGN", func() -> void:
		main._to_menu()
		show(main)])
	for bt in btns:
		var b: Button = main._button(bt[0], bt[1])
		b.custom_minimum_size = Vector2(170, 54)
		b.name = "End_" + String(bt[0]).replace(" ", "_")
		row.add_child(b)


# ------------------------------------------------------------------ the HUB (the storyline's camp, ship or workshop)

## The storyline shown (the one picked, else the first open one).
static func _line_data() -> Dictionary:
	var p := Campaign.progress()
	var open: Array = Campaign.storylines().filter(func(sl: Dictionary) -> bool: return Campaign.storyline_open(sl, p))
	for sl in open:
		if String(sl["id"]) == line:
			return sl
	if open.is_empty():
		return {}
	line = String(open[0]["id"])
	return open[0]


## The CAMPAIGN page: the hub of a storyline (like StarCraft II's ship between missions): its still with HOTSPOTS to
## click (the WAR TABLE: the missions; people: a talk that changes after each mission; rooms: the ARMOURY, a stub),
## the same hotspots as a list beside it (phones, or when a hotspot is hard to see), and tabs for the storylines.
static func show(main: Node) -> void:
	var box := _frame(main)
	var p := Campaign.progress()
	var sl := _line_data()
	var hub: Dictionary = sl.get("hub", {})
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	var t := UiStyle.heading(Loc.t(String(hub.get("title", sl.get("title", "")))), 36, UiStyle.TRIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	for s in Campaign.storylines():
		var open := Campaign.storyline_open(s, p)
		var b: Button = main._button(Loc.t(String(s.get("title", ""))) + ("" if open else "  " + Loc.t("(locked)")), func() -> void:
			line = String(s["id"])
			show(main))
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.name = "Line_" + String(s["id"])
		b.custom_minimum_size = Vector2(150, 46)
		b.add_theme_font_size_override("font_size", 15)
		b.disabled = not open
		if open:
			b.tooltip_text = Loc.t(String(s.get("about", "")))
		else:
			b.tooltip_text = Loc.t("Opens after: %s") % Loc.t(String(Campaign.mission(String(s.get("requires", ""))).get("title", "")))
		if String(s["id"]) == line:
			UiStyle.chosen(b)
		top.add_child(b)
	box.add_child(_wrap(Loc.t(String(sl.get("about", ""))), 15, UiStyle.MUTED))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	# the scene: the still and its hotspots (fractions of the still), a talk box over its bottom
	var scene := Control.new()
	scene.name = "HubScene"
	scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene.size_flags_stretch_ratio = 3.0
	body.add_child(scene)
	var col := Defs.colour_of(int(hub.get("colour", 1)))
	var sv := StillView.make(hub.get("still", {}), col)
	sv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.add_child(sv)
	var talk_box := PanelContainer.new()
	talk_box.name = "HubTalk"
	talk_box.visible = false
	talk_box.add_theme_stylebox_override("panel", UiStyle.box(Color(0.09, 0.07, 0.05, 0.94), UiStyle.TRIM, 2, 10, 12.0))
	var spots: Array = hub.get("hotspots", [])
	var list := _panel(body, 230)
	list.add_child(UiStyle.text(Loc.t("GO TO"), 15, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var btns: Array = []
	for hs in spots:
		var act := func() -> void: _hotspot(main, sl, hs, talk_box, p)
		var hb := Button.new()
		hb.name = "Hotspot_" + String(hs["id"])
		hb.text = Loc.t(String(hs.get("label", "")))
		hb.focus_mode = Control.FOCUS_NONE
		var st := UiStyle.box(Color(0.1, 0.08, 0.05, 0.25), Color(0.95, 0.8, 0.4, 0.75), 3, 10, 6.0)
		var st_h := UiStyle.box(Color(0.95, 0.8, 0.4, 0.28), Color(1, 0.9, 0.55, 1.0), 3, 10, 6.0)
		hb.add_theme_stylebox_override("normal", st)
		hb.add_theme_stylebox_override("hover", st_h)
		hb.add_theme_stylebox_override("pressed", st_h)
		hb.add_theme_font_size_override("font_size", 18 if Settings.pc() else 22)
		hb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		hb.add_theme_constant_override("outline_size", 5)
		hb.pressed.connect(func() -> void:
			Sfx.play_any(["ui/click", "click"])
			act.call())
		scene.add_child(hb)
		btns.append([hb, hs])
		var lb: Button = main._button(String(hs.get("label", "")), act)
		lb.name = "HotspotList_" + String(hs["id"])
		lb.custom_minimum_size = Vector2(0, 52 if Settings.pc() else 62)
		if String(hs.get("kind", "")) == "war_table":
			UiStyle.primary(lb)
		list.add_child(lb)
	scene.add_child(talk_box)
	var place := func() -> void:
		var s: Vector2 = scene.size
		var big := Vector2(110, 60) if Settings.pc() else Vector2(150, 80)     # (a thumb's size at least on a phone)
		for it in btns:
			var r: Array = it[1].get("rect", [0, 0, 0.1, 0.1])
			var sz := Vector2(maxf(float(r[2]) * s.x, big.x), maxf(float(r[3]) * s.y, big.y))
			var pos := Vector2(float(r[0]) * s.x, float(r[1]) * s.y)
			pos = pos.clamp(Vector2.ZERO, (s - sz).max(Vector2.ZERO))
			(it[0] as Button).position = pos
			(it[0] as Button).size = sz
		talk_box.position = Vector2(s.x * 0.05, s.y * 0.58)
		talk_box.size = Vector2(s.x * 0.9, s.y * 0.38)
	scene.resized.connect(place)
	place.call_deferred()
	var back: Button = main._button("BACK", func() -> void: main.show_menu())
	main._set_back(back)
	back.custom_minimum_size = Vector2(0, 56)
	list.add_child(back)


## A hotspot pressed: the war table opens the missions, a person talks, a room shows its page (a stub for now).
static func _hotspot(main: Node, sl: Dictionary, hs: Dictionary, talk_box: PanelContainer, p: Dictionary) -> void:
	match String(hs.get("kind", "")):
		"war_table":
			war_table(main)
		"talk":
			var tk: Dictionary = sl.get("hub", {}).get("talks", {}).get(String(hs.get("talk", "")), {})
			_talk(talk_box, tk, talk_lines(tk, p))
		"room":
			var rm: Dictionary = Campaign.index().get("rooms", {}).get(String(hs.get("room", "")), {})
			_talk(talk_box, {"name": String(rm.get("title", "")), "colour": 3}, [String(rm.get("text", ""))])


## What a person in the hub says now: the entry for the latest finished mission it lists ("after": a mission id,
## "" before any). So the talk changes after each mission.
static func talk_lines(tk: Dictionary, p: Dictionary) -> Array:
	var out: Array = []
	for e in tk.get("entries", []):
		var aft := String(e.get("after", ""))
		if aft == "" or (p["done"] as Dictionary).has(aft):
			out = e.get("lines", [])
	return out


static func _talk(box: PanelContainer, tk: Dictionary, lines: Array) -> void:
	for c in box.get_children():
		c.queue_free()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	var por := StillView.Portrait.new()
	por.custom_minimum_size = Vector2(80, 80)
	por.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	por.set_speaker(String(tk.get("name", "")), Defs.colour_of(int(tk.get("colour", 1))), String(tk.get("portrait", "")))
	h.add_child(por)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UiStyle.text(Loc.t(String(tk.get("name", ""))), 18, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	var txt := _wrap("", 17)
	txt.name = "TalkText"
	txt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(txt)
	var state := {"i": 0}
	var nb := Button.new()
	nb.name = "TalkNext"
	nb.focus_mode = Control.FOCUS_NONE
	nb.custom_minimum_size = Vector2(110, 50)
	nb.size_flags_vertical = Control.SIZE_SHRINK_END
	var show_line := func() -> void:
		txt.text = "..." if lines.is_empty() else Loc.t(String(lines[state["i"]]))
		nb.text = Loc.t("NEXT") if state["i"] < lines.size() - 1 else Loc.t("CLOSE")
	nb.pressed.connect(func() -> void:
		Sfx.play_any(["ui/click", "click"])
		if state["i"] < lines.size() - 1:
			state["i"] += 1
			show_line.call()
		else:
			box.visible = false)
	h.add_child(nb)
	show_line.call()
	box.visible = true
