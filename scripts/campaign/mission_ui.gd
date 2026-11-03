class_name MissionUi
extends Control
## A campaign mission's screen parts over the HUD: the DIALOGUE BOX (top right, under the top bar: the speaker's
## portrait, name and line, a still when the line has one; lines follow one another by themselves, NEXT and SKIP
## step through them; nothing is paused, alone or online) and the OBJECTIVES panel (top left, under the resources: each
## objective with its box ticked, crossed or open, the time left on a "survive" one; its title folds it away).

var game: Game
var run: MissionRun
var queue: Array = []                # lines waiting
var current: Dictionary = {}
var line_t := 0.0                    # seconds the current line has left
var folded := false
var _box: PanelContainer
var _portrait: StillView.Portrait
var _name: Label
var _text: Label
var _still_holder: Control
var _obj: ObjectivesPanel
var _scale := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_obj = ObjectivesPanel.new()
	_obj.ui = self
	add_child(_obj)
	_build_box()
	run.said.connect(_on_said)
	run.objectives_changed.connect(func() -> void: _obj.queue_redraw())
	get_viewport().size_changed.connect(_layout)
	_layout()


func _pc() -> bool:
	return Settings.pc()


func _build_box() -> void:
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UiStyle.box(Color(0.09, 0.07, 0.05, 0.93), UiStyle.TRIM, 2, 10, 10.0))
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.visible = false
	add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_box.add_child(v)
	_still_holder = Control.new()
	_still_holder.visible = false
	v.add_child(_still_holder)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	_portrait = StillView.Portrait.new()
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(_portrait)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 2)
	h.add_child(tv)
	_name = UiStyle.text("", 16, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tv.add_child(_name)
	_text = UiStyle.text("", 16, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tv.add_child(_text)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	h.add_child(bv)
	for it in [["NEXT", func() -> void: advance()], ["SKIP", func() -> void: skip_all()]]:
		var b := Button.new()
		b.text = it[0]
		b.name = "Dialogue_" + String(it[0])
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(it[1])
		bv.add_child(b)


func _layout() -> void:
	var hud_scale: float = game.hud.ui_scale if game and game.hud else 1.0
	_scale = hud_scale
	var vs := get_viewport_rect().size
	var top := 40.0 * hud_scale
	var fs := int((16 if _pc() else 19) * hud_scale)
	var w := minf(vs.x * (0.42 if _pc() else 0.5), 600.0 * hud_scale)
	_box.position = Vector2(vs.x - w - 8.0 * hud_scale, top)
	_box.custom_minimum_size = Vector2(w, 0)
	_box.size = Vector2(w, 0)
	var ps := 64.0 * hud_scale if _pc() else 76.0 * hud_scale
	_portrait.custom_minimum_size = Vector2(ps, ps)
	_text.custom_minimum_size.x = maxf(120.0, w - ps - 130.0 * hud_scale)      # (a width to wrap at, or the box grows tall)
	_name.add_theme_font_size_override("font_size", fs)
	_text.add_theme_font_size_override("font_size", fs)
	for b in _box.find_children("Dialogue_*", "Button", true, false):
		(b as Button).add_theme_font_size_override("font_size", int(fs * 0.85))
		(b as Button).custom_minimum_size = Vector2(80 * hud_scale, (30 if _pc() else 40) * hud_scale)
	_still_holder.custom_minimum_size = Vector2(w - 24, (w - 24) * 0.42)
	_obj.position = Vector2(8.0 * hud_scale, top)
	_obj.fs = fs - 1
	_obj.queue_redraw()


func _on_said(ln: Dictionary) -> void:
	queue.append(ln)
	if current.is_empty():
		advance()


## The next line now (the current one is done).
func advance() -> void:
	if queue.is_empty():
		current = {}
		_box.visible = false
		return
	current = queue.pop_front()
	var txt := Loc.t(String(current["text"]))
	line_t = maxf(4.5, 2.0 + txt.length() / 14.0)
	_name.text = Loc.t(String(current["name"]))
	_text.text = txt
	var col := _side_colour(String(current.get("side", "")))
	_name.add_theme_color_override("font_color", col.lightened(0.45))
	_portrait.set_speaker(String(current["name"]), col, String(current.get("portrait", "")))
	for c in _still_holder.get_children():
		c.queue_free()
	var sid := String(current.get("still", ""))
	_still_holder.visible = sid != ""
	if sid != "":
		var sv := StillView.make(run.still(sid), col, false)
		sv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_still_holder.add_child(sv)
	_box.visible = true
	_box.size = Vector2(_box.custom_minimum_size.x, 0)
	_box.reset_size.call_deferred()
	Sfx.play_any(["ui/click", "click"], Vector2.INF, -10.0)


## SKIP: this line and every one waiting.
func skip_all() -> void:
	queue.clear()
	advance()


func _process(delta: float) -> void:
	if is_instance_valid(game) and game.over and _box.visible:
		skip_all()             # (the mission's end screen takes over)
	if current.is_empty() or get_tree().paused and not (game and game.net):
		return
	line_t -= delta
	if line_t <= 0.0:
		advance()


## A side's colour: its first team's colour in this match.
func _side_colour(side_id: String) -> Color:
	for t in run.team_ids.size():
		if run.side_of_team(t) == side_id:
			return game.team_colour(t)
	return Color(0.6, 0.55, 0.45)


## The OBJECTIVES panel (drawn by hand: a box per objective).
class ObjectivesPanel extends Control:
	var ui: MissionUi
	var fs := 15
	var _rows_h := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_d: float) -> void:
		if Engine.get_process_frames() % 15 == 0:
			queue_redraw()          # (the time left on a survive objective)

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
				or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			if e.position.y < fs + 14:
				ui.folded = not ui.folded
				queue_redraw()
			accept_event()

	func _draw() -> void:
		var run := ui.run
		var list := run.objectives_for(run.my_side())
		var font := UiStyle.body_font()
		var bold := UiStyle.bold_font()
		var w := clampf(ui.get_viewport_rect().size.x * 0.30, 260.0, 440.0 * ui._scale)
		var rh := fs + 10.0
		var lines: Array = []          # [objective, wrapped lines]
		var total := fs + 14.0
		if not ui.folded:
			for o in list:
				var txt := Loc.t(String(o["text"]))
				if not bool(o.get("primary", true)):
					txt = Loc.t("(optional)") + " " + txt
				if String(o.get("kind", "")) == "survive" and o["state"] == "active":
					var left := maxi(0, int(ceil(float(o.get("time", 0)) - run.game.clock)))
					txt += "  %d:%02d" % [left / 60, left % 60]
				var wrapped := _wrap(font, txt, w - fs - 26)
				lines.append([o, wrapped])
				total += wrapped.size() * (fs + 4) + 6
		size = Vector2(w, total + 6)
		UiStyle.draw_panel(self, Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0), 0.85)
		draw_string(bold, Vector2(10, fs + 6), Loc.t("OBJECTIVES") + ("  +" if ui.folded else "  -"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.TRIM)
		var y := fs + 16.0
		for row in lines:
			var o: Dictionary = row[0]
			var st := String(o["state"])
			var col := UiStyle.TEXT if st == "active" else (UiStyle.GOOD if st == "done" else UiStyle.BAD)
			if not bool(o.get("primary", true)) and st == "active":
				col = UiStyle.MUTED
			var bx := Rect2(10, y + 3, fs - 2, fs - 2)
			draw_rect(bx, Color(0, 0, 0, 0.4))
			draw_rect(bx, col, false, 2.0)
			if st == "done":
				draw_polyline(PackedVector2Array([bx.position + Vector2(2, bx.size.y * 0.5), bx.position + Vector2(bx.size.x * 0.4, bx.size.y - 2),
					bx.position + Vector2(bx.size.x + 2, -2)]), UiStyle.GOOD, 3.0)
			elif st == "failed":
				draw_line(bx.position + Vector2(2, 2), bx.end - Vector2(2, 2), UiStyle.BAD, 3.0)
				draw_line(Vector2(bx.end.x - 2, bx.position.y + 2), Vector2(bx.position.x + 2, bx.end.y - 2), UiStyle.BAD, 3.0)
			for ln in row[1]:
				draw_string(font, Vector2(fs + 18, y + fs), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
				y += fs + 4
			y += 6
		_rows_h = y

	func _wrap(font: Font, txt: String, w: float) -> Array:
		var out: Array = []
		var cur := ""
		for word in txt.split(" "):
			var t := word if cur == "" else cur + " " + word
			if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w and cur != "":
				out.append(cur)
				cur = word
			else:
				cur = t
		if cur != "":
			out.append(cur)
		return out
