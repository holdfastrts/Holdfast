class_name StillView
extends Control
## A still shot of a campaign mission (the briefing, a line of dialogue, the end): its picture when the mission names
## one ("image": res://campaign/stills/<id>.png ...) or, until the art is decided, a PLACEHOLDER drawn in code (a
## parchment card with a landscape, the side's banner and the still's caption; logged in docs/art_style_inconsistency.md).

var still: Dictionary = {}           # {"caption", "image"?}
var colour := Color(0.75, 0.2, 0.2)  # the side's colour (its banner on the placeholder)
var show_caption := true
var _tex: Texture2D = null


static func make(st: Dictionary, col: Color, caption := true) -> StillView:
	var v := StillView.new()
	v.still = st
	v.colour = col
	v.show_caption = caption
	var img := String(st.get("image", ""))
	if img != "" and ResourceLoader.exists(img):
		v._tex = load(img)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _tex:
		draw_texture_rect(_tex, r, false)
		return
	# the placeholder: a parchment card, a dawn sky, two hills, a banner on its pole
	draw_rect(r, Color("#d9c49a"))
	var sky := Rect2(r.position + Vector2(8, 8), r.size - Vector2(16, 16))
	var top := Color("#e7c98f")
	var low := Color("#b98a52")
	var steps := 24
	for i in steps:
		var y0 := sky.position.y + sky.size.y * 0.62 * i / steps
		draw_rect(Rect2(sky.position.x, y0, sky.size.x, sky.size.y * 0.62 / steps + 1), top.lerp(low, float(i) / steps))
	var base_y := sky.position.y + sky.size.y * 0.62
	draw_rect(Rect2(sky.position.x, base_y, sky.size.x, sky.end.y - base_y), Color("#6f6a3a"))
	for h in [[0.25, 0.20, Color("#55552f")], [0.7, 0.28, Color("#4a4a2a")]]:
		var cx: float = sky.position.x + sky.size.x * float(h[0])
		var rad: float = sky.size.x * float(h[1])
		var pts := PackedVector2Array()
		for k in 17:
			var a := PI + PI * k / 16.0
			pts.append(Vector2(cx + cos(a) * rad, base_y + 2 + sin(a) * rad * 0.35))
		draw_colored_polygon(pts, h[2])
	# the banner
	var px := sky.position.x + sky.size.x * 0.72
	var py := base_y - sky.size.y * 0.30
	draw_line(Vector2(px, base_y - sky.size.y * 0.05), Vector2(px, py), Color("#2a1e12"), maxf(2.0, size.x / 160.0))
	var fw := sky.size.x * 0.12
	var fh := sky.size.y * 0.12
	draw_colored_polygon(PackedVector2Array([Vector2(px, py), Vector2(px + fw, py + fh * 0.15), Vector2(px + fw * 0.85, py + fh * 0.55),
		Vector2(px + fw, py + fh), Vector2(px, py + fh * 0.9)]), colour)
	draw_rect(sky, Color("#3b2a17"), false, 2.0)
	draw_rect(r, Color("#7a5a30"), false, 3.0)
	var font := UiStyle.body_font()
	var fs := clampi(int(size.y / 14.0), 11, 20)
	draw_string(UiStyle.bold_font(), sky.position + Vector2(10, fs + 6), Loc.t("PLACEHOLDER STILL"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, Color(0.25, 0.16, 0.08, 0.8))
	if show_caption:
		var cap := Loc.t(String(still.get("caption", "")))
		var ch := float(fs) * 2.6
		var box := Rect2(sky.position.x + 10, sky.end.y - ch - 6, sky.size.x - 20, ch)
		draw_rect(Rect2(box.position - Vector2(4, 2), box.size + Vector2(8, 4)), Color(0.12, 0.09, 0.05, 0.55))
		draw_multiline_string(font, box.position + Vector2(0, fs), cap, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, fs, -1, Color(1, 0.95, 0.82))


## A speaker's portrait: the picture the mission names ("portrait") or a placeholder: a framed oval in the side's
## colour with the speaker's initials.
class Portrait extends Control:
	var who_name := ""
	var colour := Color(0.6, 0.2, 0.2)
	var tex: Texture2D = null

	func set_speaker(nm: String, col: Color, path := "") -> void:
		who_name = nm
		colour = col
		tex = load(path) if path != "" and ResourceLoader.exists(path) else null
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#2a2016"))
		if tex:
			draw_texture_rect(tex, r.grow(-3), false)
		else:
			var c := r.get_center()
			var pts := PackedVector2Array()
			for k in 32:
				var a := TAU * k / 32.0
				pts.append(c + Vector2(cos(a) * r.size.x * 0.40, sin(a) * r.size.y * 0.44))
			draw_colored_polygon(pts, colour.darkened(0.35))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#c9a24a"), 2.0)
			var init := ""
			for w in Loc.t(who_name).split(" ", false):
				init += w.left(1)
			init = init.right(2).to_upper()
			var fs := int(minf(r.size.y, r.size.x) * 0.36)
			draw_string(UiStyle.title_font(), Vector2(r.position.x, c.y + fs * 0.36), init, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(1, 0.94, 0.8))
		draw_rect(r, Color("#c9a24a"), false, 2.0)
