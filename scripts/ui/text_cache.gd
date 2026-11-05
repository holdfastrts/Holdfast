class_name TextCache
extends RefCounted
## Shaped text kept between redraws (perf-frostfang, 0.31.x). Godot's Font keeps only its last 64 shaped strings
## (Font.get_string_size, CanvasItem.draw_string): a HUD layer that draws and measures more than that in one redraw (the
## spectator's PRODUCTION, ARMY & STRUCTURES and AI STORY panels: hundreds of strings, and the AI STORY's word-wrap measures
## every growing line) shaped every one of them again on every redraw: about 30 ms a redraw in the owner's Frostfang log.
## Here each (font, size, text) is shaped once into a TextLine and drawn from it: the same glyphs in the same places.

static var _lines := {}
static var _old := {}         # the generation before (text that came and went is let go two generations on)
static var _wraps := {}
const CAP := 3000


## The shaped line for s in font at size sz.
static func line(font: Font, s: String, sz: int) -> TextLine:
	var key := "%d|%d|%s" % [font.get_instance_id(), sz, s]
	var tl: TextLine = _lines.get(key)
	if tl == null:
		if _lines.size() >= CAP:
			_old = _lines
			_lines = {}
		tl = _old.get(key)
		if tl == null:
			tl = TextLine.new()
			tl.add_string(s, font, sz)
		_lines[key] = tl
	return tl


## Its width (as font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x).
static func width(font: Font, s: String, sz: int) -> float:
	return line(font, s, sz).get_size().x


## draw_string_outline and draw_string at the baseline point p (as CanvasItem.draw_string*), from the kept line.
static func draw(ci: CanvasItem, font: Font, p: Vector2, s: String, sz: int, col: Color, outline: int, outline_col: Color) -> void:
	var tl := line(font, s, sz)
	var at := Vector2(p.x, p.y - tl.get_line_ascent())
	var rid := ci.get_canvas_item()
	if outline > 0:
		tl.draw_outline(rid, at, outline, outline_col)
	tl.draw(rid, at, col)


## s word-wrapped to width w (SpecPanels.wrap_text's lines), kept.
static func wrap(font: Font, s: String, sz: int, w: float) -> Array:
	var key := "%d|%d|%.4f|%s" % [font.get_instance_id(), sz, w, s]
	var out = _wraps.get(key)
	if out == null:
		if _wraps.size() >= CAP:
			_wraps.clear()
		out = []
		var ln := ""
		for word in s.split(" ", false):
			var tryl := word if ln == "" else ln + " " + word
			if font.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= w or ln == "":
				ln = tryl
			else:
				out.append(ln)
				ln = word
		if ln != "":
			out.append(ln)
		_wraps[key] = out
	return out
