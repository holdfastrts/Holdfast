class_name StillShow
extends Control
## A mission's OPENING and ENDING (campaign-m1): the oil-painting stills one after another, full screen, each with its
## lines under it (the speaker's name in capitals, then the line). A tap (or NEXT, Enter, Space) gives the next line,
## SKIP (Esc) ends it. Each line plays its recorded voice when the file is there (CampaignVoice: campaign/voice/<mission
## voice folder>/<line id>.ogg) and waits for it; with no recording the line stays up for a reading time.
## Mission data: "opening": [{"still": id, "lines": [line ids]}], "ending": {side: [pages]} (Campaign.show_pages).

signal finished

var mission: Dictionary = {}
var pages: Array = []
var _items: Array = []             # [still id, line id or ""] in order
var _i := -1
var _t := 0.0                      # seconds before the next line comes by itself
var _still: StillView
var _still_id := ""
var _name: Label
var _text: Label
var _band: PanelContainer
var _done := false
var shown_ids: Array = []          # (tests) every line shown, in order
var auto := true                   # lines follow by themselves after their time (a tap is quicker)


## Over `parent` (the UI layer): the pages, then `then` (also called when skipped).
static func play(parent: Node, m: Dictionary, pg: Array, then: Callable) -> StillShow:
	var s := StillShow.new()
	s.mission = m
	s.pages = pg
	s.name = "StillShow"
	s.finished.connect(then)
	parent.add_child(s)
	return s


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.015)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for pg in pages:
		var lines: Array = pg.get("lines", [])
		if lines.is_empty():
			_items.append([String(pg.get("still", "")), ""])
		for lid in lines:
			_items.append([String(pg.get("still", "")), String(lid)])
	_band = PanelContainer.new()
	_band.add_theme_stylebox_override("panel", UiStyle.box(Color(0.05, 0.035, 0.02, 0.86), UiStyle.TRIM_DIM, 0, 0, 18.0))
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	_band.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_name = UiStyle.text("", 20, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(_name)
	_text = UiStyle.text("", 22, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.name = "ShowButtons"
	h.add_child(row)
	for it in [["SKIP", func() -> void: finish()], ["NEXT", func() -> void: next()]]:
		var b := Button.new()
		b.text = Loc.t(it[0])
		b.name = "Show_" + String(it[0])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(130, 46)
		b.pressed.connect(it[1])
		row.add_child(b)
	get_viewport().size_changed.connect(_layout)
	_layout()
	next()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var k := clampf(vs.y / 720.0, 0.8, 1.6) * (1.0 if Settings.pc() else 1.2)
	var bh := 150.0 * k
	_band.position = Vector2(0, vs.y - bh)
	_band.size = Vector2(vs.x, bh)
	_band.custom_minimum_size = Vector2(vs.x, bh)
	_name.add_theme_font_size_override("font_size", int(19 * k))
	_text.add_theme_font_size_override("font_size", int(21 * k))
	for b in find_children("Show_*", "Button", true, false):
		(b as Button).custom_minimum_size = Vector2(120, 44) * k
		(b as Button).add_theme_font_size_override("font_size", int(18 * k))
	if _still:
		_fit_still()


## The still fills the screen above the band, keeping its 3:2 shape (cropped, never stretched).
func _fit_still() -> void:
	var vs := get_viewport_rect().size
	var w := vs.x
	var h := w / 1.5
	if h < vs.y:
		h = vs.y
		w = h * 1.5
	_still.position = Vector2((vs.x - w) * 0.5, (vs.y - h) * 0.5 - (vs.y * 0.06 if h > vs.y * 1.02 else 0.0))
	_still.size = Vector2(w, h)


func next() -> void:
	if _done:
		return
	_i += 1
	if _i >= _items.size():
		finish()
		return
	var it: Array = _items[_i]
	if String(it[0]) != _still_id:
		_still_id = String(it[0])
		if _still:
			_still.queue_free()
		_still = StillView.make(mission.get("stills", {}).get(_still_id, {}), Color(0.5, 0.2, 0.6), false)
		add_child(_still)
		move_child(_still, 1)
		_fit_still()
		_still.modulate.a = 0.0
		create_tween().tween_property(_still, "modulate:a", 1.0, 0.6)
	var lid := String(it[1])
	if lid == "":
		_name.text = ""
		_text.text = Loc.t(String(mission.get("stills", {}).get(_still_id, {}).get("caption", "")))
		_t = 4.0
		return
	shown_ids.append(lid)
	var ln: Dictionary = mission.get("lines", {}).get(lid, {})
	var sp: Dictionary = mission.get("speakers", {}).get(String(ln.get("who", "")), {})
	_name.text = Loc.t(String(sp.get("name", ln.get("who", "")))).to_upper()
	_text.text = Loc.t(String(ln.get("text", "")))
	var secs := CampaignVoice.play(self, mission, lid)
	_t = maxf(secs + 0.8, maxf(5.0, 2.5 + _text.text.length() / 13.0))


func finish() -> void:
	if _done:
		return
	_done = true
	CampaignVoice.stop(self)
	finished.emit()
	queue_free()


func _process(delta: float) -> void:
	if _done or not auto:
		return
	_t -= delta
	if _t <= 0.0:
		next()


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		next()
		accept_event()


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match (e as InputEventKey).keycode:
		KEY_ESCAPE:
			finish()
		KEY_ENTER, KEY_SPACE, KEY_KP_ENTER, KEY_RIGHT:
			next()
		_:
			return
	get_viewport().set_input_as_handled()
