class_name TutorialMenu
extends RefCounted
## The TUTORIAL pages (docs/tutorial.md): the list of lessons (Basics, then the Crown, the Clockwork and the Brood,
## each ending with a practice game against an Easy computer), the chosen lesson with START, and over a finished
## lesson its end (a tick, NEXT LESSON, PLAY AGAIN, TUTORIAL). Each lesson is a mission of the campaign's engine.

static var pick := ""            # the lesson chosen on the list


static func _accent(gr: Dictionary) -> Color:
	var f := String(gr.get("faction", ""))
	return UiStyle.accent(f) if UiStyle.ACCENT.has(f) else UiStyle.TRIM


static func show(main: Node) -> void:
	var box := CampaignMenu._frame(main)
	var ids := Tutorial.lesson_ids()
	if pick == "" or not ids.has(pick):
		pick = ""
		for id in ids:
			if not Tutorial.done(id):
				pick = id          # (the first lesson not done yet)
				break
		if pick == "" and not ids.is_empty():
			pick = ids[0]
	var t := UiStyle.heading(Loc.t(String(Tutorial.index().get("title", "TUTORIAL"))), 36, UiStyle.TRIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(t)
	box.add_child(CampaignMenu._wrap(Loc.t(String(Tutorial.index().get("about", ""))), 15, UiStyle.MUTED))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	# left: the lessons, group by group
	var sc := ScrollContainer.new()
	sc.name = "LessonList"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.x = 400 if Settings.pc() else 430
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	for gr in Tutorial.groups():
		var v := CampaignMenu._panel(lv)
		v.add_theme_constant_override("separation", 6)
		v.add_child(UiStyle.text(Loc.t(String(gr.get("title", ""))), 20, _accent(gr).lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT, true))
		for lid in gr.get("lessons", []):
			var id := String(lid)
			var m := Campaign.mission(id)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			v.add_child(row)
			var tick := Tick.new()
			tick.name = "Tick_" + id
			tick.on = Tutorial.done(id)
			tick.custom_minimum_size = Vector2(30, 30)
			tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(tick)
			var b: Button = main._button(Loc.t(String(m.get("title", id))), func() -> void:
				pick = id
				show(main))
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.name = "Lesson_" + id
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size.y = 46 if Settings.pc() else 58
			if id == pick:
				UiStyle.chosen(b, _accent(gr))
			row.add_child(b)
	# right: the chosen lesson
	var rv := CampaignMenu._panel(body)
	rv.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pick != "":
		var m := Campaign.mission(pick)
		var gr: Dictionary = {}
		for g in Tutorial.groups():
			if (g.get("lessons", []) as Array).has(pick):
				gr = g
		rv.add_child(UiStyle.text(Loc.t(String(gr.get("title", ""))), 18, _accent(gr).lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT, true))
		var h := UiStyle.heading(Loc.t(String(m.get("title", pick))), 32, UiStyle.TRIM)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rv.add_child(h)
		rv.add_child(CampaignMenu._wrap(Loc.t(String(m.get("summary", ""))), 18))
		var learn: Array = m.get("learn", [])
		if not learn.is_empty():
			rv.add_child(UiStyle.text(Loc.t("YOU WILL LEARN"), 16, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
			for x in learn:
				rv.add_child(CampaignMenu._wrap("-  " + Loc.t(String(x)), 16))
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rv.add_child(sp)
		if Tutorial.done(pick):
			rv.add_child(UiStyle.text(Loc.t("Lesson done. Play it again any time."), 16, UiStyle.GOOD, HORIZONTAL_ALIGNMENT_LEFT))
		var go: Button = main._button("START LESSON", func() -> void: start(main, pick))
		go.name = "Lesson_Start"
		UiStyle.primary(go)
		go.custom_minimum_size = Vector2(0, 62)
		go.add_theme_font_size_override("font_size", 26)
		rv.add_child(go)
	var back: Button = main._button("BACK", func() -> void: main.show_menu())
	main._set_back(back)
	back.custom_minimum_size = Vector2(240, 56)
	box.add_child(back)


static func start(main: Node, id: String) -> void:
	pick = id
	Sfx.play_any(["ui/start_match"])
	main.start(Campaign.make_cfg(id, "solo"))


## Over a finished lesson: LESSON DONE with a tick (or, a practice game lost, TRY AGAIN), its closing words, and NEXT
## LESSON / PLAY AGAIN / TUTORIAL (and the battle report after a practice game).
static func lesson_end(main: Node, game: Game, winner: int, rp_path: String) -> void:
	var run := game.mission
	var m := run.data
	var id := run.id
	var win_side := run.winner_side_of(winner) if winner >= 0 else ""
	var won := win_side != "" and win_side == run.my_side()
	if won:
		Tutorial.mark_done(id)
	var nxt := Tutorial.next_of(id)
	if won and nxt != "":
		pick = nxt             # (back on the list, the next lesson is the one chosen)
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.theme = UiStyle.theme()
	o.process_mode = Node.PROCESS_MODE_ALWAYS
	o.name = "LessonEnd"
	main.ui_layer.add_child(o)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(cc)
	var v := CampaignMenu._panel(cc, 640)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(top)
	if won:
		var tick := Tick.new()
		tick.on = true
		tick.custom_minimum_size = Vector2(54, 54)
		top.add_child(tick)
	top.add_child(UiStyle.heading(Loc.t("LESSON DONE" if won else "TRY AGAIN"), 44, UiStyle.GOOD if won else UiStyle.BAD))
	v.add_child(UiStyle.text(Loc.t(String(m.get("title", id))), 24, UiStyle.TRIM))
	var db: Dictionary = m.get("debrief", {}).get(run.my_side(), {})
	var words := String(db.get("text", "")) if won else String(m.get("lost", "Every soldier loses a battle. Try it again."))
	if words != "":
		var l := CampaignMenu._wrap(Loc.t(words), 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	if won and nxt != "":
		v.add_child(UiStyle.text(Loc.t("Next: %s") % Loc.t(String(Campaign.mission(nxt).get("title", nxt))), 17, UiStyle.MUTED))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var btns: Array = []
	if won and nxt != "":
		btns.append(["NEXT LESSON", func() -> void:
			main._to_menu()
			start(main, nxt)])
	btns.append(["PLAY AGAIN", func() -> void: main.start()])
	if bool(m.get("normal_end", false)):
		btns.append(["BATTLE REPORT", func() -> void:
			o.queue_free()
			main.show_battle_report(winner, rp_path)])
	btns.append(["TUTORIAL", func() -> void:
		main._to_menu()
		show(main)])
	for bt in btns:
		var b: Button = main._button(bt[0], bt[1])
		b.custom_minimum_size = Vector2(170, 56)
		b.name = "End_" + String(bt[0]).replace(" ", "_")
		if bt[0] == "NEXT LESSON":
			UiStyle.primary(b)
		row.add_child(b)


## A tick box drawn in code (no font has to carry the mark).
class Tick extends Control:
	var on := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		draw_rect(r, Color(0, 0, 0, 0.35))
		draw_rect(r, UiStyle.GOOD if on else UiStyle.MUTED, false, 2.0)
		if on:
			var p := r.position
			var s := r.size
			draw_polyline(PackedVector2Array([p + Vector2(s.x * 0.18, s.y * 0.52), p + Vector2(s.x * 0.42, s.y * 0.78),
				p + Vector2(s.x * 0.86, s.y * 0.2)]), UiStyle.GOOD, maxf(3.0, s.x * 0.13), true)
