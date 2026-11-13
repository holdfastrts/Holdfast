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
const REDRAW := 0.5                  # seconds between looks at the layer while placing

var game: Game
var tex: ImageTexture = null         # one pixel a tile (the world layer and the minimap's)
var placing := false
var place_kind := ""
var ghost := Vector2i(-1, -1)
var ghost_share := [0.0, 0.0]        # [yield share, value share] of the ghost's circle
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
		queue_redraw()


## Is the viewer placing a building that drinks from the layer (a Farm, a Cog Press)?
func placing_drinker() -> bool:
	return placing and GroundLayer.drinks(place_kind) and ghost.x >= 0


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
		# the faint layer over every district (fainter still while an economy building shows its own circle)
		draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(gl.w, gl.h) * T), false, Color(1, 1, 1, a * (0.28 if placing_drinker() else 0.4)))
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
	elif game.human >= 0 and BroodNew.on(game, game.human):
		# the Brood: the free Rootmaw circles left on the map (rooted ones show their own ground bars)
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
			draw_rect(rc, Color(SPENT, 0.35 * k))           # (no ground of its kind here: counts as spent)
		elif gl._covered(i, own):
			draw_rect(rc, Color(COVER, 0.5 * k))           # (under another building: covered while it stands)
		else:
			draw_rect(rc, Color(tint(f), 0.55 * k))
	var col := tint(float(ghost_share[1]))
	draw_arc(mid * T, r * T, 0, TAU, 96, Color(0, 0, 0, 0.6), 5.0)
	draw_arc(mid * T, r * T, 0, TAU, 96, Color(col, 0.95), 3.0)


## Over the map's lighting (Game._draw_mine_labels): the ghost's "62% of a fresh spot".
func draw_labels(ci: CanvasItem) -> void:
	if not placing_drinker() or game.camera == null:
		return
	var size: Vector2i = Defs.BUILDINGS[place_kind]["size"]
	var T := float(Game.T)
	var mid := GroundLayer.mid_of(ghost, size) * T
	var fs := clampi(int(round(16.0 / maxf(game.camera.zoom.x, 0.3))), 9, 34)
	var font := UiStyle.bold_font()
	var txt := Loc.t("%d%% of a fresh spot") % int(round(float(ghost_share[1]) * 100.0))
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := mid + Vector2(-w * 0.5, -GroundLayer.radius(place_kind) * T - float(fs) * 0.4)
	var col := tint(float(ghost_share[1]))
	var pad := float(fs) * 0.35
	var pill := Rect2(p + Vector2(-pad, -float(fs) * 0.85), Vector2(w + pad * 2.0, float(fs) * 1.15))
	ci.draw_rect(pill, Color(0.05, 0.05, 0.05, 0.72))
	ci.draw_rect(pill, Color(col, 0.8), false, maxf(1.0, float(fs) / 12.0))
	ci.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lightened(0.35))


## The minimap's layer (hud.gd draws it while the player places).
func draw_on_minimap(ci: CanvasItem, m: Rect2) -> void:
	if not placing or tex == null:
		return
	ci.draw_texture_rect(tex, m, false, Color(1, 1, 1, clampf(Settings.ground_alpha + 0.2, 0.3, 0.9)))
