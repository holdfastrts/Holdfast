class_name HubScene
extends Control
## A hub drawn as a LAYERED PAINTING (owner's choice 2026-11-11, docs/campaign_hub_art.md): the room as the
## background, each person a cut-out layer on it, the desk drawn over the person who sits behind it, and the life done
## in code: candle flames that glow and flicker, pipe smoke that rises and drifts, a slow breath in each person.
## The data is a json (campaign/hub/<hub>.json, written by tools/import_hub_<hub>.py): the room, the layers in the
## room's pixels, "fx". The picture keeps its shape (it covers the box, cropping the overflow evenly);
## image_rect() turns a hotspot's fractions of the picture into this box's pixels.
## fx (all in the room's pixels; a hub uses the ones it names): "candles" [[x, y]], "smoke" / "match" [x, y] (Rome's
## pipe), "lamps" [[x, y, radius, [r, g, b]]] (a lantern's halo that flickers), "glows" [[x, y, radius, [r, g, b]]]
## (a slow pulse, each on its own beat: the jars), "glints" [{"ellipse": [cx, cy, rx, ry], "period": s (negative
## turns the other way), "color": [r, g, b], "size": px}] (a gleam running round a brass ring), "mist" {"rect":
## [x, y, w, h], "color": [r, g, b], "rain": 0..1} (mist drifting and rain falling inside a window), "breathe".

var data: Dictionary = {}
var highlight := ""                  # the layer the pointer is over: drawn a little brighter
var highlight_rect := Rect2()        # or, for a hotspot with no layer, its rect (this box's pixels)
var _room: Texture2D = null
var _tex := {}                       # layer id -> Texture2D
var _t := 0.0
var _smoke: Array = []               # [pos (room px), vel, age, life, size]
var _puff := 0.0
var _glow: GradientTexture2D = null
var _mist: MistView = null


## Mist and rain inside a window: its own box (clipped to the window), over the room.
class MistView extends Control:
	var hub: HubScene
	var cfg: Dictionary

	func _draw() -> void:
		var f := hub._fit()
		var k: float = f[0]
		var r: Array = cfg.get("rect", [0, 0, 1, 1])
		var w := float(r[2])
		var h := float(r[3])
		var c: Array = cfg.get("color", [0.7, 0.8, 0.7])
		var t := hub._t
		# mist: wide soft banks drifting slowly sideways, thickening and thinning
		for i in 6:
			var sp := 6.0 + 3.0 * float(i % 3)
			var x := fposmod(float(i) * w * 0.37 + t * sp, w * 1.6) - w * 0.3
			var y := h * (0.25 + 0.13 * float(i)) + sin(t * 0.21 + float(i)) * h * 0.04
			var rad := w * (0.32 + 0.06 * float(i % 2))
			var a := 0.13 + 0.06 * sin(t * 0.33 + float(i) * 1.7)
			var col := Color(float(c[0]), float(c[1]), float(c[2]), a)
			draw_texture_rect(hub._glow, Rect2((Vector2(x, y) - Vector2(rad, rad * 0.55)) * k, Vector2(rad, rad * 0.55) * 2.0 * k), false, col)
		# rain: thin streaks falling a little aslant
		var rain := float(cfg.get("rain", 0.0))
		if rain <= 0.0:
			return
		var n := int(90.0 * rain)
		for i in n:
			var sd := float(i) * 12.9898
			var px := fposmod(sin(sd) * 43758.5453, 1.0) * (w + 40.0) - 20.0
			var spd := 520.0 + 180.0 * fposmod(sin(sd * 1.7) * 9123.17, 1.0)
			var py := fposmod(fposmod(sin(sd * 2.3) * 3141.59, 1.0) * h + t * spd, h + 30.0) - 15.0
			var ln := 14.0 + 10.0 * fposmod(sin(sd * 3.1) * 777.7, 1.0)
			var p0 := Vector2(px, py)
			var p1 := p0 + Vector2(-ln * 0.18, ln)
			draw_line(p0 * k, p1 * k, Color(0.85, 0.92, 0.9, 0.16 + 0.1 * fposmod(sd, 1.0)), maxf(1.0, k * 1.2))


static func make(path: String) -> HubScene:
	var v := HubScene.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.clip_contents = true
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			v.data = d
	var room := String(v.data.get("room", ""))
	if room != "" and ResourceLoader.exists(room):
		v._room = load(room)
	for l in v.data.get("layers", []):
		var img := String(l.get("image", ""))
		if img != "" and ResourceLoader.exists(img):
			v._tex[String(l["id"])] = load(img)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	v._glow = GradientTexture2D.new()
	v._glow.gradient = g
	v._glow.fill = GradientTexture2D.FILL_RADIAL
	v._glow.fill_from = Vector2(0.5, 0.5)
	v._glow.fill_to = Vector2(1.0, 0.5)
	v._glow.width = 64
	v._glow.height = 64
	var mist: Dictionary = v.data.get("fx", {}).get("mist", {})
	if not mist.is_empty():
		v._mist = MistView.new()
		v._mist.hub = v
		v._mist.cfg = mist
		v._mist.clip_contents = true
		v._mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(v._mist)
	return v


func ok() -> bool:
	return _room != null


func _ready() -> void:
	resized.connect(queue_redraw)


func _room_size() -> Vector2:
	var s: Array = data.get("size", [1, 1])
	return Vector2(float(s[0]), float(s[1]))


## The scale and offset that put the room's pixels into this box (cover: fills it, keeps its shape).
func _fit() -> Array:
	var rs := _room_size()
	var k := maxf(size.x / rs.x, size.y / rs.y)
	var fo: Array = data.get("focus", [0.5, 0.5])
	return [k, (size - rs * k) * Vector2(float(fo[0]), float(fo[1]))]


## A rect given as fractions of the picture [x, y, w, h], in this box's pixels.
func image_rect(r: Array) -> Rect2:
	var f := _fit()
	var rs := _room_size()
	var k: float = f[0]
	return Rect2(f[1] + Vector2(float(r[0]) * rs.x, float(r[1]) * rs.y) * k, Vector2(float(r[2]) * rs.x, float(r[3]) * rs.y) * k)


func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	_t += dt
	var fx: Dictionary = data.get("fx", {})
	if fx.has("smoke"):
		_puff -= dt
		if _puff <= 0.0:
			_puff = randf_range(0.10, 0.18)
			var p: Array = fx["smoke"]
			_smoke.append([Vector2(float(p[0]) + randf_range(-2, 2), float(p[1])), Vector2(randf_range(-4, 3), randf_range(-30, -22)),
				0.0, randf_range(4.0, 5.5), randf_range(6.0, 9.0)])
		for s in _smoke:
			s[2] += dt
			# a lazy curl: the wisp leans one way, then the other, and slows as it rises
			s[1].x += sin(_t * 0.9 + float(s[3]) * 3.0) * 6.0 * dt
			s[0] += s[1] * dt
			s[1] *= 1.0 - 0.18 * dt
		_smoke = _smoke.filter(func(s: Array) -> bool: return float(s[2]) < float(s[3]))
	if _mist:
		var f := _fit()
		var r: Array = fx["mist"].get("rect", [0, 0, 1, 1])
		_mist.position = f[1] + Vector2(float(r[0]), float(r[1])) * float(f[0])
		_mist.size = Vector2(float(r[2]), float(r[3])) * float(f[0])
		_mist.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if _room == null:
		return
	var f := _fit()
	var k: float = f[0]
	var o: Vector2 = f[1]
	var rs := _room_size()
	# the candles breathe light into the whole room, a little
	var fx: Dictionary = data.get("fx", {})
	var warm := 1.0 + float(fx.get("flicker", 0.025)) * sin(_t * 7.3) * sin(_t * 2.1)
	draw_texture_rect(_room, Rect2(o, rs * k), false, Color(warm, warm, warm * 0.98))
	var breathe: Dictionary = fx.get("breathe", {})
	for l in data.get("layers", []):         # the shadows first, under everyone
		if l.has("shadow"):
			var sh: Array = l["shadow"]
			var c := o + Vector2(float(sh[0]), float(sh[1])) * k
			var e := Vector2(float(sh[2]), float(sh[3])) * k
			draw_texture_rect(_glow, Rect2(c - e, e * 2.0), false, Color(0, 0, 0, 0.6))
	for l in data.get("layers", []):
		var id := String(l["id"])
		if l.has("shadow"):
			continue
		var tex: Texture2D = _tex.get(id)
		if tex == null:
			continue
		var pos := Vector2(float(l["pos"][0]), float(l["pos"][1]))
		var sz := Vector2(float(l["size"][0]), float(l["size"][1]))
		# breath: a slow rise of the chest, the feet (the layer's bottom) stay put
		var amp := float(breathe.get(id, 0.0))
		var b := 1.0 + amp * (0.5 + 0.5 * sin(_t * TAU / 4.6 + float(id.length())))
		var r := Rect2(o + (pos + Vector2(0, sz.y * (1.0 - b))) * k, Vector2(sz.x, sz.y * b) * k)
		var lit := 1.18 if highlight == id else 1.0
		draw_texture_rect(tex, r, false, Color(lit * warm, lit * warm, lit * warm * 0.98))
		if id == "king":
			_draw_fire(fx, k, o)
	# the candles' flames: a warm halo that wavers
	for c in fx.get("candles", []):
		var p := o + Vector2(float(c[0]), float(c[1])) * k
		var fl := 0.8 + 0.2 * sin(_t * 11.0 + float(c[0])) * sin(_t * 5.3 + float(c[1]))
		_halo(p, 34.0 * k * fl, Color(1.0, 0.72, 0.35, 0.32 * fl))
		_halo(p, 9.0 * k, Color(1.0, 0.9, 0.6, 0.55 * fl))
	# lanterns and lamps: a wider halo that wavers, each on its own beat
	var i := 0
	for l in fx.get("lamps", []):
		var p := o + Vector2(float(l[0]), float(l[1])) * k
		var c: Array = l[3]
		var fl := 0.82 + 0.18 * sin(_t * (9.0 + float(i)) + float(l[0])) * sin(_t * (4.1 + 0.7 * float(i)) + float(l[1]))
		_halo(p, float(l[2]) * k * (0.9 + 0.1 * fl), Color(float(c[0]), float(c[1]), float(c[2]), 0.30 * fl))
		_halo(p, float(l[2]) * 0.3 * k, Color(1.0, 0.92, 0.7, 0.45 * fl))
		i += 1
	# glows (the jars): a slow swell and fade, out of step with each other
	i = 0
	for g in fx.get("glows", []):
		var p := o + Vector2(float(g[0]), float(g[1])) * k
		var c: Array = g[3]
		var pu := 0.5 + 0.5 * sin(_t * TAU / (5.0 + 0.9 * float(i % 4)) + float(i) * 2.3)
		_halo(p, float(g[2]) * k * (0.92 + 0.12 * pu), Color(float(c[0]), float(c[1]), float(c[2]), 0.08 + 0.17 * pu))
		i += 1
	# glints: a gleam running round a brass ring (an ellipse: the ring seen at a slant), a short fading trail behind
	for gl in fx.get("glints", []):
		var e: Array = gl.get("ellipse", [0, 0, 1, 1])
		var per := float(gl.get("period", 8.0))
		var c: Array = gl.get("color", [1.0, 0.9, 0.6])
		var sz := float(gl.get("size", 10.0))
		var a0 := _t * TAU / per
		for j in 6:
			var a := a0 - float(j) * 0.035 * signf(per)
			var p := o + Vector2(float(e[0]) + float(e[2]) * cos(a), float(e[1]) + float(e[3]) * sin(a)) * k
			var fade := 1.0 - float(j) / 6.0
			# brightest where the ring faces the light (its near side), dim at the back
			var face := 0.55 + 0.45 * maxf(sin(a), 0.0)
			_halo(p, sz * k * (1.0 + 0.6 * fade), Color(float(c[0]), float(c[1]), float(c[2]), 0.6 * fade * face))
		var ph := o + Vector2(float(e[0]) + float(e[2]) * cos(a0), float(e[1]) + float(e[3]) * sin(a0)) * k
		_halo(ph, sz * 0.45 * k, Color(1, 1, 0.92, 0.95 * (0.55 + 0.45 * maxf(sin(a0), 0.0))))
	# a hotspot with no layer of its own (the map on the desk, the letter): a soft gold wash while pointed at
	if highlight_rect.size != Vector2.ZERO:
		draw_rect(highlight_rect, Color(1.0, 0.85, 0.45, 0.10 + 0.04 * sin(_t * 4.0)))
		draw_rect(highlight_rect, Color(1.0, 0.85, 0.45, 0.5), false, 2.0)


## The match's flame (over the King's layer, under the desk) and the smoke above the pipe.
func _draw_fire(fx: Dictionary, k: float, o: Vector2) -> void:
	if fx.has("match"):
		var m := o + Vector2(float(fx["match"][0]), float(fx["match"][1])) * k
		var fl := 0.75 + 0.25 * sin(_t * 17.0) * sin(_t * 6.1)
		_halo(m, 22.0 * k * fl, Color(1.0, 0.65, 0.3, 0.55 * fl))
		_halo(m, 6.0 * k, Color(1.0, 0.95, 0.7, 0.95))
	for s in _smoke:
		var a := float(s[2]) / float(s[3])
		var rad := (float(s[4]) + 34.0 * a) * k
		var alpha := 0.42 * sin(minf(a * 3.0, 1.0) * PI * 0.5) * (1.0 - a)
		_halo(o + (s[0] as Vector2) * k, rad, Color(0.86, 0.84, 0.8, alpha))


func _halo(p: Vector2, rad: float, c: Color) -> void:
	draw_texture_rect(_glow, Rect2(p - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false, c)
