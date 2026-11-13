class_name GroundLayer
extends RefCounted
## THE GROUND SYSTEM (the owner, 2026-11-13 01:34-01:40, docs/ground_system.md; a Settings experiment like TURNING GEARS:
## Settings.ground_system, kept in the match's setup as cfg "ground", Defs.ground_on). Off, the game is exactly as before.
##
## On: the Crown's soil and the Clockwork's brass lie ON THE MAP, tile by tile, in a DISTRICT round every hall (a Town
## Hall's soil, a Clocktower's brass: Defs.GROUND "district" tiles round its middle, a fixed amount each, spread over the
## district's open land when the hall is laid; tiles another hall made before keep what they hold: nothing is ever
## renewed). Every Farm and Cog Press DRINKS FROM A CIRCLE round it (Defs.GROUND "r"), the Brood's Rootmaw's model:
##   - it works at its full rate while its circle holds any ground, and what it can ever pay is what its circle holds: a
##     circle half over spent ground holds half as much, so it pays half as long (the owner's "proportional amount"; the
##     Rootmaw's own rule: a fixed rate from a spot holding PIT_GROUND less what was drunk there). Its "% of a fresh spot"
##     is what its circle holds against a fresh circle of the same land; tiles under another building (a Barracks, a
##     Cottage, a wall) are covered: they keep their ground but nobody drinks it while it stands there;
##   - it drinks EVENLY from its live tiles, so a circle empties all at once (as the hall's soil did) and two overlapping
##     circles drink the tiles they share twice as fast (no free income from stacking: the ground is the same);
##   - what it pays is what it drew (a tile's last drop pays only what is left: exhausted means exhausted).
## The Brood keeps its own circles (Game.nb_spots, BroodNew): this layer only draws them while a Brood side places.
## The secondary resources stay in the hall (the Mill's saltpetre, the Mainspring's spring life; Claude's choice, the doc).
## The hall's own `soil` (Town Hall) / `lode` (Clocktower brass) mirror what is left in its district (tick, once a second),
## so its card, the toasts, the computers' "is this land spent" and the old scars read the layer without knowing it.

const NONE := 0
const SOIL := 1
const BRASS := 2
const EPS := 0.01               # a tile with less than this is spent (no crumbs left counting as live ground)

var g: Game
var w := 0
var h := 0
var kind := PackedByteArray()   # NONE / SOIL / BRASS
var full := PackedFloat32Array()   # what the tile held when its district was laid
var left := PackedFloat32Array()   # what it holds now
var rev := 0                    # changes whenever the ground does (drawn: the faint layer and the minimap redraw)
var guest := false              # an online guest / a replay: values come from the host (NetSnapshot "gd"), never drawn here
var _cache := {}                # building instance id -> [tiles, disc, cover key, alive share, value share, clock]
var _cover_key := 0             # Game._mark bumps it (a footprint changed: covers are looked at again)
var _tick_t := 0.0
var _debt := {}                 # building instance id -> what it owes the ground (a Cog Press draws in little bites: paid in chunks)


func _init(game: Game) -> void:
	g = game
	w = game.W
	h = game.H
	kind.resize(w * h)
	full.resize(w * h)
	left.resize(w * h)


# ------------------------------------------------------------------ which buildings, which ground

## The resource a hall lays (SOIL / BRASS), NONE for anything else.
static func hall_res(k: String) -> int:
	return SOIL if k == "town_hall" else (BRASS if k == "clocktower" else NONE)


## The resource a building drinks from the layer (Farm: soil, Cog Press: brass), NONE for anything else.
static func drink_res(k: String) -> int:
	return SOIL if k == "farm" else (BRASS if k == "cog_press" else NONE)


static func drinks(k: String) -> bool:
	return Defs.ground_on and drink_res(k) != NONE


## Radius (tiles) of a hall's district of this ground (LAND "district"; the Clockwork's brass may have its own,
## "district_brass").
static func district_r(res: int) -> float:
	if res == BRASS and Defs.LAND.has("district_brass"):
		return float(Defs.LAND["district_brass"])
	return float(Defs.LAND["district"])


## A study's numbers from a tool's command line (land.district=11 land.r.farm=10 land.spot_min=0.1 ...).
static func study_args(opts: Dictionary) -> void:
	for k in opts.keys():
		if String(k).begins_with("land."):
			var path := String(k).substr(5).split(".")
			if path.size() == 1:
				Defs.LAND[path[0]] = float(opts[k]) if String(opts[k]).is_valid_float() else (String(opts[k]) == "true")
			else:
				(Defs.LAND[path[0]] as Dictionary)[path[1]] = float(opts[k])


## Radius (tiles) of the circle a building of this kind drinks from.
static func radius(k: String) -> float:
	return float((Defs.LAND["r"] as Dictionary).get(k, 8.0))


# ------------------------------------------------------------------ discs

## The tiles whose middles lie within r tiles of c (in tiles, not px), on the map.
func disc(c: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r2 := r * r
	for y in range(int(floor(c.y - r)), int(ceil(c.y + r)) + 1):
		if y < 0 or y >= h:
			continue
		var dy := float(y) + 0.5 - c.y
		for x in range(int(floor(c.x - r)), int(ceil(c.x + r)) + 1):
			if x < 0 or x >= w:
				continue
			var dx := float(x) + 0.5 - c.x
			if dx * dx + dy * dy <= r2:
				out.append(y * w + x)
	return out


## A building's middle in tiles (cell + size / 2).
static func mid_of(cell: Vector2i, size: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(size) * 0.5


## Covered: under a building that is neither a hall nor an economy building (a Barracks, a Cottage, a wall, a gate...):
## its ground is kept but nobody drinks it while it stands there. The halls and the economy buildings are the land's own
## (a Farm's fields are its ground). `own` is kept for the callers (a footprint never covers its own circle).
var _cover := PackedByteArray()
var _cover_at := -1


func _covered(i: int, _own := Rect2i()) -> bool:
	if _cover_at != _cover_key:
		_build_cover()
	return _cover[i] != 0


func _build_cover() -> void:
	_cover_at = _cover_key
	_cover.resize(w * h)
	_cover.fill(0)
	for b in g.buildings:
		if b.dead or b.ghost or hall_res(b.kind) != NONE or Defs.is_econ(b.kind) or Defs.BUILDINGS[b.kind].get("faction", "") == "brood":
			continue
		for y in b.size.y:
			for x in b.size.x:
				var c: Vector2i = b.cell + Vector2i(x, y)
				if c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
					_cover[c.y * w + c.x] = 1


## Land: a tile that is not terrain (cliff, water, trees, rock): ground can lie there.
func is_land(i: int) -> bool:
	return g.solid[i] != 1 or kind[i] != NONE


# ------------------------------------------------------------------ districts

## A hall is laid: its district's tiles that no hall made before get its ground (Defs.GROUND "soil" / "brass" spread
## evenly over the district's open land: a tile that is terrain (cliff, water, trees, rock) holds none). A hall laid where
## another stood (or overlapping it) adds only its new tiles' share: nothing is ever renewed.
func found(b: Building) -> void:
	if guest:
		return
	var res := hall_res(b.kind)
	if res == NONE:
		return
	var tiles := disc(mid_of(b.cell, b.size), district_r(res))
	var land := 0
	for i in tiles:
		if g.solid[i] != 1:
			land += 1
	if land == 0:
		return
	var per := float(Defs.LAND["soil" if res == SOIL else "brass"]) / float(land)
	for i in tiles:
		if kind[i] != NONE or g.solid[i] == 1:
			continue
		kind[i] = res
		full[i] = per
		left[i] = per
	rev += 1
	_cache.clear()


## [left, full] of a hall's district (its kind of ground within the district's radius).
func district(b: Building) -> Array:
	var res := hall_res(b.kind)
	var lt := 0.0
	var ft := 0.0
	for i in disc(b.center() / Defs.TILE, district_r(res)):
		if kind[i] == res:
			lt += left[i]
			ft += full[i]
	return [lt, ft]


# ------------------------------------------------------------------ a drinker's circle

## [tiles, alive share (live uncovered tiles / the circle's land tiles), value share (what it holds of a fresh circle,
## the "% of a fresh spot"), what it holds] of a circle of kind k's ground round c (tiles), `own` its footprint.
func measure(res: int, c: Vector2, r: float, own: Rect2i) -> Array:
	var tiles := disc(c, r)
	if tiles.is_empty():
		return [tiles, 0.0, 0.0, 0.0]
	var alive := 0
	var val := 0.0
	var amt := 0.0
	var n := 0
	for i in tiles:
		if not is_land(i):
			continue              # (cliffs, water, trees: no ground there, and none missing)
		n += 1
		if kind[i] != res or left[i] <= EPS or _covered(i, own):
			continue
		alive += 1
		amt += left[i]
		val += clampf(left[i] / full[i], 0.0, 1.0) if full[i] > 0.0 else 0.0
	if n == 0:
		return [tiles, 0.0, 0.0, 0.0]
	# (the "% of a fresh spot" is against a whole fresh circle: one at the map's edge or against cliffs holds less)
	return [tiles, alive / float(n), val / (PI * r * r), amt]


## The building's circle, looked at again once a second (or when a footprint changed).
func _of(b: Building) -> Array:
	var id := b.get_instance_id()
	var c = _cache.get(id)
	if c != null and int(c[2]) == _cover_key and g.clock - float(c[5]) < 1.0:
		return c
	var m := measure(drink_res(b.kind), b.center() / Defs.TILE, radius(b.kind), Rect2i(b.cell, b.size))
	c = [m[0], m[3], _cover_key, m[1], m[2], g.clock]
	_cache[id] = c
	return c


## The share (0..1) of a Farm / Cog Press's circle's land that still holds its ground (uncovered).
func share(b: Building) -> float:
	return float(_of(b)[3])


## What its circle still holds (gold / cogs; uncovered tiles): it works in full while this is above 0.
func held(b: Building) -> float:
	return float(_of(b)[1])


## What its circle still holds of a fresh circle (0..1).
func value(b: Building) -> float:
	return float(_of(b)[4])


## Draw `v` from the building's circle, evenly from its live tiles (a tile with less than its part gives what it has,
## the rest is taken from the others); returns what was drawn (all of it while the circle holds enough).
func draw(b: Building, v: float) -> float:
	if v <= 0.0 or guest:
		return 0.0
	var res := drink_res(b.kind)
	var own := Rect2i(b.cell, b.size)
	var tiles: PackedInt32Array = _of(b)[0]
	var live := PackedInt32Array()
	for i in tiles:
		if kind[i] == res and left[i] > EPS and not _covered(i, own):
			live.append(i)
	var got := 0.0
	var need := v
	var guard := 0
	while need > 0.0001 and not live.is_empty() and guard < 8:
		guard += 1
		var per := need / float(live.size())
		var still := PackedInt32Array()
		for i in live:
			var take := minf(left[i], per)
			left[i] -= take
			got += take
			if left[i] <= EPS:
				got += left[i]           # (the crumb goes with it)
				left[i] = 0.0
			else:
				still.append(i)
		need = v - got
		live = still
	if got > 0.0:
		rev += 1
		var c = _cache.get(b.get_instance_id())
		if c != null:
			c[5] = -INF              # (looked at again next time: its share may have fallen)
	return got


## A Cog Press draws a little every tick: its draws add up and are paid in chunks of Defs.GROUND "bite" (what it pays
## comes in a moment later). Returns what it pays now.
func draw_bit(b: Building, v: float) -> float:
	var id := b.get_instance_id()
	var owed := float(_debt.get(id, 0.0)) + v
	if owed < float(Defs.LAND["bite"]):
		_debt[id] = owed
		return 0.0
	_debt[id] = 0.0
	return draw(b, owed)


func forget(b: Building) -> void:
	_cache.erase(b.get_instance_id())
	_debt.erase(b.get_instance_id())


func covers_changed() -> void:
	_cover_key += 1


# ------------------------------------------------------------------ the halls' mirrors

## Once a second: each hall's `soil` (Town Hall) / `lode` (Clocktower brass) = what its district holds, on its old scale
## (the hall's card, the toasts, the computers' "dry land" read it as before).
func tick(delta: float) -> void:
	if guest:
		return
	_tick_t -= delta
	if _tick_t > 0.0:
		return
	_tick_t = 1.0
	for b in g.buildings:
		if b.dead or not b.built:
			continue
		var res := hall_res(b.kind)
		if res == NONE:
			continue
		var d := district(b)
		var share := clampf(float(d[0]) / float(d[1]), 0.0, 1.0) if float(d[1]) > 0.0 else 0.0
		if res == SOIL:
			b.soil = share * b.reserve()
			g._soil_check(b)
		else:
			b.lode = share * b.lode_full()
			g._lode_check(b)


# ------------------------------------------------------------------ placing (the ghost's circle, the faint layer)

## [alive share, value share, what it would hold] a building of kind k would have at cell c (the placement ghost's number).
func preview(k: String, c: Vector2i) -> Array:
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var m := measure(drink_res(k), mid_of(c, size), radius(k), Rect2i(c, size))
	return [m[1], m[2], m[3]]


## How fresh a tile is (0 spent .. 1 fresh), -1 where there is no ground of `res` (any kind when res is NONE).
func fresh(i: int, res := NONE) -> float:
	if kind[i] == NONE or (res != NONE and kind[i] != res):
		return -1.0
	return clampf(left[i] / full[i], 0.0, 1.0) if full[i] > 0.0 else 0.0


## Summed-area tables of how fresh the ground of `res` is (uncovered tiles) and of the land: find_spot scores many cells.
var _sat := PackedFloat32Array()
var _sat_land := PackedFloat32Array()
var _sat_res := -1
var _sat_rev := -1
var _sat_key := -1


func _build_sat(res: int) -> void:
	if _sat_res == res and _sat_rev == rev and _sat_key == _cover_key:
		return
	_sat_res = res
	_sat_rev = rev
	_sat_key = _cover_key
	var w1 := w + 1
	_sat.resize(w1 * (h + 1))
	_sat.fill(0.0)
	_sat_land.resize(w1 * (h + 1))
	_sat_land.fill(0.0)
	for y in h:
		var run := 0.0
		var lrun := 0.0
		for x in w:
			var i := y * w + x
			if is_land(i):
				lrun += 1.0
				if kind[i] == res and left[i] > EPS and not _covered(i) and full[i] > 0.0:
					run += clampf(left[i] / full[i], 0.0, 1.0)
			_sat[(y + 1) * w1 + x + 1] = _sat[y * w1 + x + 1] + run
			_sat_land[(y + 1) * w1 + x + 1] = _sat_land[y * w1 + x + 1] + lrun


## Quick: what a circle of kind k at cell c would hold of a whole fresh one (a square of the circle's area, from the table).
func quick(k: String, c: Vector2i) -> float:
	var res := drink_res(k)
	_build_sat(res)
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var m := mid_of(c, size)
	var half := radius(k) * 0.886         # (sqrt(pi) / 2: the square with the circle's area)
	var x0 := clampi(int(round(m.x - half)), 0, w)
	var x1 := clampi(int(round(m.x + half)), 0, w)
	var y0 := clampi(int(round(m.y - half)), 0, h)
	var y1 := clampi(int(round(m.y + half)), 0, h)
	var w1 := w + 1
	var s := _sat[y1 * w1 + x1] - _sat[y0 * w1 + x1] - _sat[y1 * w1 + x0] + _sat[y0 * w1 + x0]
	return clampf(s / (4.0 * half * half), 0.0, 1.0)      # (against a whole fresh circle, as measure's)


# ------------------------------------------------------------------ saves (exact) and the net (quantised)

## A saved game: the made tiles, exactly (deflated, base64).
func save() -> Dictionary:
	var ids := PackedInt32Array()
	var ks := PackedByteArray()
	var fs := PackedFloat32Array()
	var ls := PackedFloat32Array()
	for i in kind.size():
		if kind[i] != NONE:
			ids.append(i)
			ks.append(kind[i])
			fs.append(full[i])
			ls.append(left[i])
	return {"w": w, "h": h, "n": ids.size(), "i": _pack(ids.to_byte_array()), "k": _pack(ks), "f": _pack(fs.to_byte_array()), "l": _pack(ls.to_byte_array())}


func load(d: Dictionary) -> void:
	kind.fill(0)
	full.fill(0.0)
	left.fill(0.0)
	if int(d.get("w", 0)) != w or int(d.get("h", 0)) != h:
		return
	var ids := _unpack(String(d.get("i", ""))).to_int32_array()
	var ks := _unpack(String(d.get("k", "")))
	var fs := _unpack(String(d.get("f", ""))).to_float32_array()
	var ls := _unpack(String(d.get("l", ""))).to_float32_array()
	for j in mini(ids.size(), mini(ks.size(), mini(fs.size(), ls.size()))):
		var i := ids[j]
		if i >= 0 and i < kind.size():
			kind[i] = ks[j]
			full[i] = fs[j]
			left[i] = ls[j]
	rev += 1
	_cache.clear()


static func _pack(b: PackedByteArray) -> String:
	if b.is_empty():
		return ""
	var z := b.compress(FileAccess.COMPRESSION_DEFLATE)
	return "%d:%s" % [b.size(), Marshalls.raw_to_base64(z)]


static func _unpack(s: String) -> PackedByteArray:
	if s == "" or not ":" in s:
		return PackedByteArray()
	var parts := s.split(":", true, 1)
	return Marshalls.base64_to_raw(parts[1]).decompress(int(parts[0]), FileAccess.COMPRESSION_DEFLATE)


## The net (online snapshots, FULL replays, the ranked server): each made tile as one int, index << 8 | kind << 5 | how
## fresh in 32 steps (0 only when spent). What the guest draws needs no more.
const Q := 31


func q_of(i: int) -> int:
	if kind[i] == NONE:
		return 0
	var f := clampf(left[i] / full[i], 0.0, 1.0) if full[i] > 0.0 else 0.0
	return (i << 8) | (int(kind[i]) << 5) | (0 if left[i] <= EPS else maxi(1, int(ceil(f * Q))))


## Rows that changed since `sent` (a Dictionary index -> row the view last got; updated); every one it knows when `all`.
## FOG (ranked, docs/online_ranked.md): `eye_vis` (NetSnapshot._eye_vis: the view's sides' sight, empty = sees all) keeps a
## tile's news to the sides that see it now: a tile out of sight is sent only as it was last seen (in a keyframe), never
## while an enemy drinks it unseen.
func net_rows(sent: Dictionary, all: bool, eye_vis: Array = []) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in kind.size():
		if kind[i] == NONE:
			continue
		if not eye_vis.is_empty() and not NetSnapshot._cell_seen(g, i, eye_vis):
			if all and sent.has(i):
				out.append(int(sent[i]))          # (as it was last seen)
			continue
		var r := q_of(i)
		if all or int(sent.get(i, -1)) != r:
			sent[i] = r
			out.append(r)
	return out


## Rows as they go on the wire: the tile numbers as steps from the one before (rows come in tile order), deflated: a
## keyframe's whole layer is a few hundred bytes.
static func pack_rows(rows: PackedInt32Array) -> PackedByteArray:
	var d := PackedInt32Array()
	d.resize(rows.size())
	var prev := 0
	for j in rows.size():
		var i := rows[j] >> 8
		d[j] = ((i - prev) << 8) | (rows[j] & 255)
		prev = i
	var raw := d.to_byte_array()
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(raw.compress(FileAccess.COMPRESSION_DEFLATE))
	return out


static func unpack_rows(b) -> PackedInt32Array:
	if b is PackedInt32Array:
		return b
	if not (b is PackedByteArray) or (b as PackedByteArray).size() < 4:
		return PackedInt32Array()
	var bb: PackedByteArray = b
	var d := bb.slice(4).decompress(int(bb.decode_u32(0)), FileAccess.COMPRESSION_DEFLATE).to_int32_array()
	var prev := 0
	for j in d.size():
		var i := prev + (d[j] >> 8)
		d[j] = (i << 8) | (d[j] & 255)
		prev = i
	return d


## A guest takes rows (a keyframe's `all` rows first clears what it had).
func net_apply(rows: PackedInt32Array, all: bool) -> void:
	guest = true
	if all:
		kind.fill(0)
		full.fill(0.0)
		left.fill(0.0)
	for r in rows:
		var i := r >> 8
		if i < 0 or i >= kind.size():
			continue
		kind[i] = (r >> 5) & 7
		full[i] = 1.0
		left[i] = float(r & 31) / float(Q)
	rev += 1
	_cache.clear()
