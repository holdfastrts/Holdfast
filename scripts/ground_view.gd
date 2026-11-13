class_name GroundView
extends Node2D
## THE GROUND SYSTEM, shown (docs/ground_system.md; the owner, 2026-11-13 01:34-01:37). While the player places ANY
## building, the ground layer is tinted FAINTLY on the map (fresh green to spent red; Settings.ground_alpha sets how
## strongly), with the circles of his economy buildings already standing, "so a Barracks or a wall is not put on the best
## ground by mistake". A Farm or Cog Press being placed shows its OWN circle much stronger (each tile by how fresh it is,
## covered tiles grey) and "62% of a fresh spot" over it. The minimap shows the same layer while placing. The Brood keeps
## its Rootmaw circles (its ROOT ghost shows their ground): while a Brood side roots anything, the free circles left on
## the map are tinted the same way. Only ground the viewer has explored. Code-drawn (docs/art_style_inconsistency.md).

const FRESH := Color(0.36, 0.86, 0.32)
const SPENT := Color(0.92, 0.22, 0.16)
const COVER := Color(0.55, 0.55, 0.55)
const NOGROUND := Color(0.08, 0.08, 0.1)
const REDRAW := 0.5                  # seconds between looks at the layer while placing

var game: Game
var tex: ImageTexture = null         # one pixel a tile (the world layer and the minimap's)
var placing := false
var place_kind := ""
var ghost := Vector2i(-1, -1)
var ghost_share := [0.0, 0.0]        # [yield share, value share] of the ghost's circle
var best_cell := Vector2i(-1, -1)    # the best free spot for this building in the viewer's districts (owner: "clear and intuitive")
var best_share := 0.0
var _best_key := ""
const BEST_GAIN := 0.05              # the BEST SPOT mark shows only when it holds at least this much more than the ghost's spot
const GOLD := Color(1.0, 0.82, 0.3)
var _rev := -1
var _t := 0.0


func _ready() -> void:
	z_index = -17
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	if game == null:
		return
	var ctl = game.controls
	var p := false
	var k := ""
	var c := Vector2i(-1, -1)
	if ctl != null and not game.demo and game.human >= 0 and (String(ctl.mode) == "place" or String(ctl.mode) == "nb_root"):
		p = true
		k = String(ctl.place_kind)
		c = ctl.ghost_cell
	var changed := p != placing or k != place_kind or c != ghost
	placing = p
	place_kind = k
	ghost = c
	if not placing:
		if changed:
			queue_redraw()
		return
	_t -= delta
	var gl := game.ground_layer
	if gl != null and (_t <= 0.0 and gl.rev != _rev):
		_t = REDRAW
		_rev = gl.rev
		_make_tex()
		changed = true
	if changed:
		if GroundLayer.drinks(place_kind) and ghost.x >= 0 and gl != null:
			ghost_share = gl.preview(place_kind, ghost)
			var key := "%s/%d/%d" % [place_kind, gl.rev, game.buildings.size()]
			if key != _best_key:
				_best_key = key
				_find_best(gl)
		queue_redraw()


## Is the viewer placing a building that drinks from the layer (a Farm, a Cog Press)?
func placing_drinker() -> bool:
	return placing and GroundLayer.drinks(place_kind) and ghost.x >= 0


## The best spot for place_kind in the viewer's own districts: the cells scored quickly (GroundLayer.quick), the best
## few checked for a legal placement and measured exactly. Only on explored ground. Runs when the layer or the buildings
## change, not as the mouse moves.
func _find_best(gl: GroundLayer) -> void:
	best_cell = Vector2i(-1, -1)
	best_share = 0.0
	var res := GroundLayer.drink_res(place_kind)
	var size: Vector2i = Defs.BUILDINGS[place_kind]["size"]
	var seen_all := game.sees_all() or game.explored.size() != gl.w * gl.h
	var cand: Array = []
	for b in game.buildings:
		if b.dead or b.team != game.human or GroundLayer.hall_res(b.kind) != res:
			continue
		var c0: Vector2 = b.center() / float(Game.T)
		var rr := GroundLayer.district_r(res)
		for dy in range(-int(rr), int(rr) + 1):
			for dx in range(-int(rr), int(rr) + 1):
				if Vector2(dx, dy).length() > rr:
					continue
				var c := Vector2i(int(c0.x) + dx, int(c0.y) + dy) - size / 2
				if not game.in_map(c) or (not seen_all and game.explored[game.idx(c)] == 0):
					continue
				cand.append([gl.quick(place_kind, c), c])
	cand.sort_custom(func(a, b): return a[0] > b[0])
	var found := 0
	for e in cand:
		if found >= 6 or float(e[0]) < 0.05:
			break
		var c: Vector2i = e[1]
		if game.placement_problem(game.human, place_kind, c) != "":
			continue
		found += 1
		var v := float(gl.preview(place_kind, c)[1])
		if v > best_share:
			best_share = v
			best_cell = c


## A word for how good a spot is (the label's first line).
static func verdict(f: float) -> String:
	# (a circle never lies wholly on a district's soil next to its hall: a fresh hall's best Farm spot holds about 70-80%)
	if f >= 0.7:
		return Loc.t("FRESH SPOT")
	if f >= 0.45:
		return Loc.t("GOOD SPOT")
	if f >= 0.25:
		return Loc.t("HALF SPENT")
	if f >= 0.08:
		return Loc.t("POOR SPOT")
	return Loc.t("SPENT")


func _best_shows() -> bool:
	return placing_drinker() and best_cell.x >= 0 and best_cell != ghost and best_share >= float(ghost_share[1]) + BEST_GAIN


static func tint(f: float) -> Color:
	return SPENT.lerp(FRESH, clampf(f, 0.0, 1.0))


## The layer as an image, one pixel a tile, only where the viewer has explored.
func _make_tex() -> void:
	var gl := game.ground_layer
	if gl == null:
		return
	var w := gl.w
	var h := gl.h
	var data := PackedByteArray()
	data.resize(w * h * 4)
	var seen_all := game.sees_all() or game.explored.size() != w * h
	for i in w * h:
		var f := gl.fresh(i)
		if f < 0.0 or (not seen_all and game.explored[i] == 0):
			continue
		var col := tint(f)
		data[i * 4] = int(col.r * 255.0)
		data[i * 4 + 1] = int(col.g * 255.0)
		data[i * 4 + 2] = int(col.b * 255.0)
		data[i * 4 + 3] = 255
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	if tex == null or tex.get_width() != w or tex.get_height() != h:
		tex = ImageTexture.create_from_image(img)
	else:
		tex.update(img)


func _draw() -> void:
	if not placing or game == null:
		return
	var T := float(Game.T)
	var a := Settings.ground_alpha
	var gl := game.ground_layer
	if gl != null and tex != null:
		# the faint layer over every district, tile by tile (fainter still while an economy building shows its own circle)
		var fa := a * (0.28 if placing_drinker() else 0.4)
		var seen_all := game.sees_all() or game.explored.size() != gl.w * gl.h
		for i in gl.kind.size():
			if gl.kind[i] == GroundLayer.NONE or (not seen_all and game.explored[i] == 0):
				continue
			draw_rect(Rect2(Vector2(i % gl.w, i / gl.w) * T, Vector2(T, T)), Color(tint(gl.fresh(i)), fa))
		# the circles of the viewer's own economy buildings (thin), and his halls' districts (thinner)
		for b in game.buildings:
			if b.dead or b.team != game.human:
				continue
			if GroundLayer.drink_res(b.kind) != GroundLayer.NONE:
				draw_arc(b.center(), GroundLayer.radius(b.kind) * T, 0, TAU, 64, Color(tint(b.soil_left() if b.kind == "farm" else b.lode_left()), 0.5 * a + 0.15), 2.0)
			elif GroundLayer.hall_res(b.kind) != GroundLayer.NONE:
				draw_arc(b.center(), GroundLayer.district_r(GroundLayer.hall_res(b.kind)) * T, 0, TAU, 96, Color(1, 1, 1, 0.25 * a + 0.08), 1.5)
		if placing_drinker():
			_draw_ghost_circle(gl, T, a)
			if _best_shows():
				_draw_best(T)
	if game.human >= 0 and BroodNew.on(game, game.human):
		# the Brood: the free Rootmaw circles left on the map (rooted ones show their own ground bars); also with THE GROUND
		# SYSTEM on (it lays no Brood ground: an elif here hid these circles from a Brood player once it was on)
		for id in game.nb_spots:
			var s: Dictionary = game.nb_spots[id]
			if int(s.get("maw", 0)) != 0:
				continue
			var p: Vector2 = s["p"]
			var ci := game.cell_of(p)
			if game.in_map(ci) and not game.sees_all() and game.explored.size() == Game.W * Game.H and game.explored[game.idx(ci)] == 0:
				continue
			var f := clampf(float(s["left"]) / float(Defs.PIT_GROUND), 0.0, 1.0)
			draw_circle(p, float(Defs.PIT_CLAIM) * T, Color(tint(f), 0.3 * a))
			draw_arc(p, float(Defs.PIT_CLAIM) * T, 0, TAU, 64, Color(tint(f), 0.4 * a + 0.2), 2.0)


func _draw_ghost_circle(gl: GroundLayer, T: float, a: float) -> void:
	var size: Vector2i = Defs.BUILDINGS[place_kind]["size"]
	var mid := GroundLayer.mid_of(ghost, size)
	var r := GroundLayer.radius(place_kind)
	var res := GroundLayer.drink_res(place_kind)
	var own := Rect2i(ghost, size)
	var k := clampf(a * 1.6, 0.35, 0.85)
	for i in gl.disc(mid, r):
		var cell := Vector2i(i % gl.w, i / gl.w)
		var rc := Rect2(Vector2(cell) * T, Vector2(T, T)).grow(-1.0)
		var f := gl.fresh(i, res)
		if f < 0.0:
			draw_rect(rc, Color(NOGROUND, 0.45 * k))        # (no ground of its kind here, outside the halls' districts: pays nothing)
		elif gl._covered(i, own):
			draw_rect(rc, Color(COVER, 0.5 * k))           # (under another building: covered while it stands)
		else:
			draw_rect(rc, Color(tint(f), 0.55 * k))
	var col := tint(float(ghost_share[1]))
	draw_arc(mid * T, r * T, 0, TAU, 96, Color(0, 0, 0, 0.6), 5.0)
	draw_arc(mid * T, r * T, 0, TAU, 96, Color(col, 0.95), 3.0)


## The BEST SPOT mark: its footprint outlined in gold and a dotted arrow from the ghost to it.
func _draw_best(T: float) -> void:
	var size: Vector2i = Defs.BUILDINGS[place_kind]["size"]
	var r := Rect2(Vector2(best_cell) * T, Vector2(size) * T)
	draw_rect(r.grow(2.0), Color(0, 0, 0, 0.55), false, 5.0)
	draw_rect(r.grow(2.0), Color(GOLD, 0.95), false, 2.5)
	draw_rect(r, Color(GOLD, 0.12))
	var a := GroundLayer.mid_of(ghost, size) * T
	var b := GroundLayer.mid_of(best_cell, size) * T
	var d := b - a
	var L := d.length()
	if L < T * 2.0:
		return
	var u := d / L
	var s0 := float(size.x) * T * 0.6
	var s1 := L - float(size.x) * T * 0.6
	var t := s0
	while t < s1 - 6.0:
		draw_line(a + u * t, a + u * minf(t + 8.0, s1), Color(GOLD, 0.85), 2.5)
		t += 16.0
	var tip := a + u * s1
	var side := Vector2(-u.y, u.x)
	draw_colored_polygon(PackedVector2Array([tip, tip - u * 14.0 + side * 8.0, tip - u * 14.0 - side * 8.0]), Color(GOLD, 0.95))


## Over the map's lighting (Game._draw_mine_labels): under the ghost, "62%  GOOD SPOT", "of fresh soil in its circle"
## and a bar; over the BEST SPOT mark, "BEST SPOT  94%".
func draw_labels(ci: CanvasItem) -> void:
	if not placing_drinker() or game.camera == null:
		return
	var size: Vector2i = Defs.BUILDINGS[place_kind]["size"]
	var T := float(Game.T)
	var mid := GroundLayer.mid_of(ghost, size) * T
	var fs := clampi(int(round(17.0 / maxf(game.camera.zoom.x, 0.3))), 10, 36)
	var fs2 := int(round(float(fs) * 0.68))
	var font := UiStyle.bold_font()
	var f := float(ghost_share[1])
	var col := tint(f)
	var l1 := "%d%%  %s" % [int(round(f * 100.0)), verdict(f)]
	var l2 := Loc.t("of a whole circle of fresh soil") if GroundLayer.drink_res(place_kind) == GroundLayer.SOIL else Loc.t("of a whole circle of fresh brass")
	# a third line when it helps: this IS the best spot left (no better one to look for), and/or the hall's ground is low
	var l3 := ""
	if best_cell.x >= 0 and f >= best_share - 0.02:
		l3 = Loc.t("the best spot left by your halls")
	if best_cell.x >= 0 and best_share < 0.35:
		l3 = Loc.t("ground running low: expand to a new hall")
	var w1 := font.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w2 := font.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	var w3 := font.get_string_size(l3, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x if l3 != "" else 0.0
	var w := maxf(maxf(w1, w2), w3)
	var pad := float(fs) * 0.4
	var bar_h := maxf(4.0, float(fs) * 0.28)
	var bh := float(fs) + float(fs2) + bar_h + pad * 2.2 + (float(fs2) * 1.15 if l3 != "" else 0.0)
	# BESIDE the building, level with it (never over its own picture or its gear labels, never behind the bottom panel):
	# on its right, or on its left when the right would leave the screen
	var bw := w + pad * 2.0
	var xf := game.get_viewport().get_canvas_transform()
	var vw := float(game.get_viewport().get_visible_rect().size.x)
	var left := mid.x + float(size.x) * T * 0.5 + pad * 1.5
	if (xf * Vector2(left + bw, mid.y)).x > vw - 8.0:
		left = mid.x - float(size.x) * T * 0.5 - pad * 1.5 - bw
	var top := mid.y - bh * 0.5
	var box := Rect2(Vector2(left, top), Vector2(bw, bh))
	mid.x = left + bw * 0.5        # (the lines below centre on the box)
	ci.draw_rect(box, Color(0.05, 0.05, 0.05, 0.78))
	ci.draw_rect(box, Color(col, 0.85), false, maxf(1.5, float(fs) / 10.0))
	var y := top + pad * 0.5 + float(fs) * 0.85
	ci.draw_string_outline(font, Vector2(mid.x - w1 * 0.5, y), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.8))
	ci.draw_string(font, Vector2(mid.x - w1 * 0.5, y), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lightened(0.3))
	y += float(fs2) * 1.05
	ci.draw_string(font, Vector2(mid.x - w2 * 0.5, y), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.88, 0.86, 0.8))
	var bar := Rect2(Vector2(mid.x - w * 0.5, y + pad * 0.45), Vector2(w, bar_h))
	ci.draw_rect(bar, Color(0.2, 0.2, 0.2, 0.9))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(f, 0.0, 1.0), bar_h)), col)
	if l3 != "":
		ci.draw_string(font, Vector2(mid.x - w3 * 0.5, bar.end.y + float(fs2) * 1.05), l3, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, GOLD)
	if _best_shows():
		var bm := GroundLayer.mid_of(best_cell, size) * T
		var lb := Loc.t("BEST SPOT  %d%%") % int(round(best_share * 100.0))
		var wb := font.get_string_size(lb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var pb := Vector2(bm.x - wb * 0.5, bm.y - float(size.y) * T * 0.5 - pad)
		var pill := Rect2(pb + Vector2(-pad * 0.6, -float(fs2) * 0.9), Vector2(wb + pad * 1.2, float(fs2) * 1.2))
		ci.draw_rect(pill, Color(0.05, 0.05, 0.05, 0.78))
		ci.draw_rect(pill, Color(GOLD, 0.9), false, 1.5)
		ci.draw_string(font, pb, lb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, GOLD)


## The minimap's layer (hud.gd draws it while the player places).
func draw_on_minimap(ci: CanvasItem, m: Rect2) -> void:
	if not placing or tex == null:
		return
	ci.draw_texture_rect(tex, m, false, Color(1, 1, 1, clampf(Settings.ground_alpha + 0.2, 0.3, 0.9)))
