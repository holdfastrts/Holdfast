class_name VetChevrons
extends Node2D
## VETERANCY CHEVRONS (the owner, 2026-11-14; docs/vet_chevrons.md): ONE chevron over every unit with kills, every
## faction (Crown, Clockwork, Brood, guns, workers, flyers, the campaign's rebels): BRONZE from Defs.VET["bronze"]
## kills, SILVER from ["silver"], GOLD from ["gold"]; nothing under bronze. Centred just ABOVE where the unit's health
## bar is drawn (Unit.bar_top: a Springer's leap, a flyer's height, a mounted man, a big machine's taller bar), ALWAYS
## shown whether the bar shows or not (the owner: "it would be priority for microing and target fire"). A dead body
## shows the chevron its kills earned too. It is only a label: the damage bonus stays +1% a kill (Defs.VET per_kill).
##
## Each veteran (alive or a body) carries one small Sprite2D child, "VetChevron" (z 3, absolute: over every unit and
## the flyers, under the stun stars and the fog clouds), so the engine moves and culls it with the unit and hides it
## with the unit in the fog: nothing is redrawn each frame. This layer (Game.vet_layer) makes and keeps those
## sprites: their place is worked out again for a tenth of them each frame (a bar hardly moves; a Springer in the air
## every frame) and for all of them when the zoom changes. SCREEN SIZE: the chevron is about SCREEN_W px wide on the
## screen at every zoom (a little smaller zoomed far out), so it stays readable over a zoomed-out army without hiding
## a close-up sprite. Art: the owner's sheet (art/ui/vet_chevrons_chatgpt.png) cut by tools/import_vet_chevrons.py into
## assets/ui/vet_<rank>.png; without the files a chevron drawn in code (chevron_image) stands in
## (docs/art_style_inconsistency.md). Drawn from a 4x copy with mipmaps: smooth at any size, never blurred into mush.

const RANKS := ["", "bronze", "silver", "gold"]
const ART := "res://assets/ui/vet_%s.png"
const SCREEN_W := 15.0           # its width on the screen at the usual zoom (px)
const SCREEN_MIN := 11.0         # zoomed far out it shrinks to this
const ZOOM_FULL := 1.2           # at this zoom and closer it is SCREEN_W wide
const GAP := 2.0                 # screen px between it and the health bar's top edge
const SCAN := 0.25               # seconds between looks over every unit for new veterans (the kills setter adds them at once too)

var game: Node = null
var vets := {}                   # Unit -> its chevron sprite (or null until made): every unit (alive or a body) with a rank
var _list: Array = []            # (the keys of vets, for the slices)
var _air := {}                   # veterans in a leap now: placed every frame
var _scan_t := 0.0
var _frame := 0
var _zoom := -1.0
const SLICE := 10                # a tenth of the chevrons placed again each frame (each 6 times a second)

static var _tex := {}            # rank -> true once the atlas is made (load_tex)
static var from_files := false   # (tests) the owner's art, not the code-drawn stand-in


## The rank a number of kills earns: 0 none, 1 bronze, 2 silver, 3 gold.
static func rank(kills: int) -> int:
	if kills >= int(Defs.VET["gold"]):
		return 3
	if kills >= int(Defs.VET["silver"]):
		return 2
	if kills >= int(Defs.VET["bronze"]):
		return 1
	return 0


## The rank in words for the unit card ("Veteran (bronze): 17 kills, +17% damage"); under bronze just the kills.
static func rank_text(kills: int) -> String:
	var pct := int(round(minf(kills * float(Defs.VET["per_kill"]), float(Defs.VET["max"])) * 100.0))
	match rank(kills):
		3:
			return Loc.t("Veteran (gold): %d kills, +%d%% damage") % [kills, pct]
		2:
			return Loc.t("Veteran (silver): %d kills, +%d%% damage") % [kills, pct]
		1:
			return Loc.t("Veteran (bronze): %d kills, +%d%% damage") % [kills, pct]
	if kills == 1:
		return Loc.t("1 kill, +1% damage")
	return Loc.t("%d kills, +%d%% damage") % [kills, pct]


## Does this viewer see the spoils NUMBER on bodies? Only the side that harvests them (a Brood player) and those who
## watch (computers v computers, spectators, replays).
static func number_shown(g: Node) -> bool:
	if g == null:
		return false
	if g.get("demo") or g.get("replay") != null:
		return true
	var h := int(g.get("human"))
	var f: Array = g.get("factions")
	if h < 0 or h >= f.size():
		return true
	return Defs.base_faction(String(f[h])) == "brood"


## A unit's kills reached a rank (Unit.kills): drawn from now on (alive and, later, as a body).
static func note(u: Unit) -> void:
	if u == null or u.game == null or rank(u.kills) == 0:
		return
	var l = u.game.get("vet_layer")
	if l != null and not l.vets.has(u):
		l.vets[u] = null
		l._list.append(u)


func _ready() -> void:
	load_tex()


func _process(delta: float) -> void:
	var _p0 := Time.get_ticks_usec()
	_frame += 1
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN
		_scan()
	if _list.is_empty():
		return
	var sz := world_size()
	var all := not is_equal_approx(sz.x, _zoom)
	_zoom = sz.x
	if all:
		for u in _list:
			place(u, sz)
	else:
		for i in range(_frame % SLICE, _list.size(), SLICE):
			place(_list[i], sz)
		for u in _air.keys():
			place(u, sz)
	Prof.add("vet chevrons", _p0)


## Every unit with a rank, alive or a body (loaded games, an online guest's puppets and a replay's set kills without the
## layer being told: they are found here).
func _scan() -> void:
	for u in vets.keys():
		if not is_instance_valid(u) or u.is_queued_for_deletion():
			vets.erase(u)
			_air.erase(u)
	if game != null:
		for l in [game.units, game.corpses]:
			for u in l:
				if is_instance_valid(u) and u.kills >= int(Defs.VET["bronze"]) and not vets.has(u):
					vets[u] = null
	_list = vets.keys()


## Puts (or makes, or takes away) one unit's chevron: its rank, size and place over its health bar.
func place(u, sz: Vector2) -> void:
	if not is_instance_valid(u):
		return
	var spr = vets.get(u)
	var r := rank(u.kills)
	if r == 0 or _tex.is_empty():
		if spr != null and is_instance_valid(spr):
			spr.queue_free()
		vets[u] = null
		return
	if spr == null or not is_instance_valid(spr):
		spr = Sprite2D.new()
		spr.name = "VetChevron"
		spr.z_index = 3
		spr.z_as_relative = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		u.add_child(spr)
		vets[u] = spr
	if spr.texture != _atlas:
		spr.texture = _atlas
		spr.region_enabled = true
	var rr: Rect2 = _rects[r]
	if spr.region_rect != rr:
		spr.region_rect = rr
	# (set only what changed: a moved sprite costs the engine a transform update)
	var vis: bool = not u.off_field and u.aboard == null
	if spr.visible != vis:
		spr.visible = vis
	var sc := sz.x / float(_cell.x)
	if spr.scale.x != sc:
		spr.scale = Vector2(sc, sc)
	var np := Vector2(0.0, bottom_of(u, GAP * sz.x / SCREEN_W) - sz.y * 0.5)
	if spr.position != np:
		spr.position = np
	if u.jump.is_empty():
		_air.erase(u)
	else:
		_air[u] = true


## Its size on the field (world px) at the camera's zoom now.
func world_size() -> Vector2:
	var z := 1.5
	if game != null and game.get("camera") != null:
		z = maxf(float(game.camera.zoom.x), 0.05)
	var sw := clampf(SCREEN_W * sqrt(minf(z / ZOOM_FULL, 1.0)), SCREEN_MIN, SCREEN_W)
	var asp := float(_cell.y) / float(_cell.x) if _cell.x > 0 else 11.0 / 15.0
	return Vector2(sw, sw * asp) / z


## Where its bottom edge goes over the unit (unit space, up is negative).
static func bottom_of(u: Unit, gap: float) -> float:
	if u.dead:
		# a body: just over the picture as it lies (the frame's used rect), over the spoils number where that shows
		var br := BroodRoot.body_rect(u) if u.sprite != null else Rect2()
		var y := br.position.y - u.position.y - gap if br.size.y > 2.0 else -14.0
		if u.game != null and u.game.corpses.has(u) and number_shown(u.game):
			y = minf(y, Unit.NUMBER_Y - gap)
		return y
	var lifted: float = Springer.lift(u) if not u.jump.is_empty() else 0.0
	var top: float = u.bar_top(lifted)
	if u._k_nb and BroodNew.ROOTERS.has(u.kind) and u._nb_top > -9000.0:
		top -= Entity.SUB_H + 1.0          # (a rooting creature's reload bar goes ABOVE its health bar)
	if u.acid_t > 0.0:
		top -= 3.0                         # (the acid strip over the bar)
	if u.has_meta("mission_name"):
		top -= 13.0                        # (a campaign's named man: his name over the bar)
	return top - 1.0 - gap


## (tests) Every chevron placed now, then what shows: [rank, its rect on the field, alpha] for every ranked unit and
## body seen (the fog: Unit.visible; a balloon's passenger, a man off the field being bandaged: not).
func entries() -> Array:
	_scan()
	var sz := world_size()
	for u in _list:
		place(u, sz)
	var out: Array = []
	for u in _list:
		var spr = vets.get(u)
		if spr == null or not is_instance_valid(u) or not u.visible or not spr.visible or u.modulate.a < 0.05:
			continue
		var tsz: Vector2 = spr.region_rect.size * spr.scale
		out.append([rank(u.kills), Rect2(u.position + spr.position - tsz * 0.5, tsz), u.modulate.a])
	return out


## The three chevrons: the owner's art when its files are there, else the ones drawn in code. One ATLAS (so a crowd of
## chevrons of every rank is one batch), each a 4x copy with mipmaps (drawn at about 11 to 15 screen px), PAD
## transparent pixels between them so the small mipmaps don't bleed one into the next.
const PAD := 16
static var _atlas: ImageTexture = null
static var _cell := Vector2i.ZERO
static var _rects := {}          # rank -> its rect in the atlas


static func load_tex() -> void:
	if _atlas != null:
		return
	from_files = true
	var imgs := {}
	for r in [1, 2, 3]:
		var img: Image = null
		var p := ART % RANKS[r]
		if ResourceLoader.exists(p):
			var t: Texture2D = load(p)
			img = t.get_image() if t else null
			if img != null and img.is_compressed():
				img.decompress()
		if img == null or img.is_empty():
			img = chevron_image(r)
			from_files = false
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
		imgs[r] = img
		_cell = Vector2i(maxi(_cell.x, img.get_width()), maxi(_cell.y, img.get_height()))
	var at := Image.create(PAD + 3 * (_cell.x + PAD), _cell.y + 2 * PAD, false, Image.FORMAT_RGBA8)
	at.fill(Color(0, 0, 0, 0))
	for r in [1, 2, 3]:
		var img: Image = imgs[r]
		var o := Vector2i(PAD + (r - 1) * (_cell.x + PAD), PAD)
		at.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), o + (_cell - img.get_size()) / 2)
		_rects[r] = Rect2(o, _cell)
	at.generate_mipmaps()
	_atlas = ImageTexture.create_from_image(at)
	_tex = {1: true, 2: true, 3: true}


## The stand-in drawn in code: a 15 x 11 pixel chevron (point up), a dark outline, metal shading (light on the upper
## left edge, dark on the lower right) in bronze, silver or gold.
static func chevron_image(r: int) -> Image:
	var w := 15
	var h := 11
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramps := {1: [Color(0.36, 0.17, 0.05), Color(0.80, 0.45, 0.16), Color(1.0, 0.74, 0.42)],
		2: [Color(0.42, 0.44, 0.47), Color(0.78, 0.80, 0.82), Color(1.0, 1.0, 1.0)],
		3: [Color(0.62, 0.38, 0.02), Color(0.98, 0.80, 0.12), Color(1.0, 0.98, 0.70)]}
	var ramp: Array = ramps[r]
	var edge := Color(0.06, 0.04, 0.03)
	# the band: |x - 7| between y - 4 and y - 0.5 ... a V of thickness 3 rising to the middle
	for y in h:
		for x in w:
			var dx := absf(x - 7.0)
			var inner := float(y) - 1.0 - dx             # 0 on the band's upper edge
			var inside := inner >= 0.0 and inner < 4.0 and y >= 1 and y <= h - 2 and dx <= 6.0
			if inside:
				var t := clampf(1.0 - inner / 3.0, 0.0, 1.0)
				var c: Color = (ramp[0] as Color).lerp(ramp[1], clampf(t * 2.0, 0.0, 1.0))
				if t > 0.6 and x <= 7:
					c = (ramp[1] as Color).lerp(ramp[2], (t - 0.6) / 0.4)
				img.set_pixel(x, y, c)
	# the outline: any empty pixel touching the band
	var band := img.duplicate()
	for y in h:
		for x in w:
			if band.get_pixel(x, y).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and band.get_pixel(q.x, q.y).a > 0.0:
					img.set_pixel(x, y, edge)
					break
	return img
