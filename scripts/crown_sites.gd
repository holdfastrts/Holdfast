class_name CrownSites
extends RefCounted
## THE CROWN'S EXPANSION SPOTS (the owner, DECIDED 2026-11-03 22:25; docs/expansion_spots.md "The Crown's rule"): "As Crown
## I think the optimal expansion positions will be as close as possible to each other because of walls and trying to use
## the high ground to our advantage." So for the Crown:
##  - the 2nd and 3rd bases go at the MINIMUM hall distance (Defs.HALL_SPACING, 18 tiles) from its halls, close together,
##    and UNDER COVER of the main's high ground: within Musketeer reach (REACH) of a high-ground EDGE cell of the main, so
##    the line on the cliff's edge (AICrownHold's edge post) shoots over the new hall, and the walls can join up;
##  - the 4th base on: the same, as close as possible to the Crown's other halls, without the main's high ground.
## Any free ground counts, not only the map's base sites (a hall's land holds the same fresh reserve anywhere: Game.lode_at_spot).
## Used by the gold EXPANSION SPOTS of a Crown side (ExpansionSpots, Game setup) and by the Crown computer's hall pick
## (AICrown._safe_hall_spot). The map is turned through its middle, so twin spots score the same (ties are broken by where
## the spot lies seen from its own main toward the map's middle, which turns with the map).

const REACH := 200.0            # (px) a Musketeer's 190 plus the bodies: an edge cell this near a side of the hall covers it
const SLACK := 9.0              # (tiles) spots looked at up to HALL_SPACING + SLACK from the nearest hall of ours
const ROOM_MIN := 0.45          # ExpansionSpots._room: the Farms' and the Mill's room round the hall
const W_ROOM := 40.0
const W_COVER := 60.0           # (the 2nd and 3rd bases) the share of the hall's sides the edge covers
const W_GAP := 3.0              # a point a tile farther than the minimum from the nearest hall
const W_TOGETHER := 1.0         # a point a tile, the mean distance to the other halls past the minimum
const W_WAYS := 4.0             # a way in past the first (ExpansionSpots._ways)
const W_SAFE := 0.2             # half-steps nearer us than the enemy (capped at 40)
const COVER_HALLS := 2          # cover counts while the Crown has this many halls or fewer (picking its 2nd or 3rd)
const EDGE_R := 30.0            # (tiles) the main's high ground looked at round its hall


## The main's high-ground EDGE (cells, Vector2i): cells on the main hall's level, joined to it on that level (not over a
## ramp), within EDGE_R tiles, with lower ground within two cells (the cliff's lip). None when the main is not on high ground.
static func edge_cells(g: Game, t: int) -> Array:
	var out: Array = []
	if g.starts.size() <= t or g.height.size() != Game.W * Game.H:
		return out
	var hc: Vector2i = g.starts[t] + Vector2i(2, 2)
	if not g.in_map(hc):
		return out
	var h := int(g.height[g.idx(hc)])
	if h <= 0:
		return out
	var mid := Vector2(g.starts[t]) + Vector2(2.5, 2.0)
	var seen := {hc: true}
	var q: Array = [hc]
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		var i := g.idx(p)
		var lip := false
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var n := p + Vector2i(dx, dy)
				if g.in_map(n) and int(g.height[g.idx(n)]) < h and g.ramp[g.idx(n)] == 0:
					lip = true
		if lip and g.solid[i] == 0 and not g._near_ramp(p):
			out.append(p)
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2: Vector2i = p + dd
			if seen.has(n2) or not g.in_map(n2):
				continue
			var j := g.idx(n2)
			if int(g.height[j]) != h or g.ramp[j] != 0 or g.cliff[j] != 0 or g.solid[j] == 1:
				continue
			if (Vector2(n2) + Vector2(0.5, 0.5)).distance_to(mid) > EDGE_R:
				continue
			seen[n2] = true
			q.append(n2)
	return out


## Distance (px) from every cell's middle to the nearest edge cell's middle (INF where far), a chamfer pass over a box.
static func edge_field(g: Game, edge: Array) -> Dictionary:
	var f := PackedFloat32Array()
	f.resize(Game.W * Game.H)
	f.fill(INF)
	if edge.is_empty():
		return {"f": f}
	var lo := Vector2i(Game.W, Game.H)
	var hi := Vector2i(-1, -1)
	for c in edge:
		f[g.idx(c)] = 0.0
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var pad := int(REACH / Defs.TILE) + 4
	lo = Vector2i(maxi(0, lo.x - pad), maxi(0, lo.y - pad))
	hi = Vector2i(mini(Game.W - 1, hi.x + pad), mini(Game.H - 1, hi.y + pad))
	var T := float(Defs.TILE)
	var dg := T * 1.41421
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var i := y * Game.W + x
			var v := f[i]
			if x > lo.x: v = minf(v, f[i - 1] + T)
			if y > lo.y:
				v = minf(v, f[i - Game.W] + T)
				if x > lo.x: v = minf(v, f[i - Game.W - 1] + dg)
				if x < hi.x: v = minf(v, f[i - Game.W + 1] + dg)
			f[i] = v
	for y in range(hi.y, lo.y - 1, -1):
		for x in range(hi.x, lo.x - 1, -1):
			var i := y * Game.W + x
			var v := f[i]
			if x < hi.x: v = minf(v, f[i + 1] + T)
			if y < hi.y:
				v = minf(v, f[i + Game.W] + T)
				if x < hi.x: v = minf(v, f[i + Game.W + 1] + dg)
				if x > lo.x: v = minf(v, f[i + Game.W - 1] + dg)
			f[i] = v
	return {"f": f}


## How well the edge covers a hall at cell c: "near" (px, its nearest side to an edge cell) and "share" (0..1, the cells
## just round its sides, where an attacker stands, within REACH of an edge cell).
static func cover_of(g: Game, field: Dictionary, c: Vector2i, size: Vector2i) -> Dictionary:
	var f: PackedFloat32Array = field["f"]
	var near := INF
	var n := 0
	var ok := 0
	for y in range(c.y - 1, c.y + size.y + 1):
		for x in range(c.x - 1, c.x + size.x + 1):
			if x >= c.x and x < c.x + size.x and y >= c.y and y < c.y + size.y:
				continue
			var cc := Vector2i(x, y)
			if not g.in_map(cc):
				continue
			n += 1
			var d := f[g.idx(cc)]
			near = minf(near, d)
			if d <= REACH:
				ok += 1
	return {"near": near, "share": float(ok) / float(maxi(1, n))}


## The bare ground lets a hall stand at c: its cells and the ring round them free, on one level, no ramp near (the computer
## keeps its ramps clear), inside the map.
static func ground_ok(g: Game, c: Vector2i, size: Vector2i) -> bool:
	if c.x < 1 or c.y < 1 or c.x + size.x >= Game.W or c.y + size.y >= Game.H:
		return false
	var lv := int(g.height[g.idx(c)])
	for y in range(c.y - 1, c.y + size.y + 1):
		for x in range(c.x - 1, c.x + size.x + 1):
			var i := y * Game.W + x
			if g.solid[i] != 0 or g.cliff[i] != 0 or g.ramp[i] != 0:
				return false
			var inside := x >= c.x and x < c.x + size.x and y >= c.y and y < c.y + size.y
			if inside and (int(g.height[i]) != lv or g._near_ramp(Vector2i(x, y))):
				return false
	return true


## The Crown's best hall spots for team t, given its halls (their middles in tiles; the main first): `n` picks, each one
## with the earlier picks counted as halls (the 3rd base close to the 2nd). Each pick: {"c", "team", "rank", "score",
## "room", "share" (cover), "near", "gap" (tiles to the nearest hall), "home" (steps from the main), "foe" (from the enemy),
## "ways", "gapw"}. `steps` ([ours, [the enemies'...]]: ExpansionSpots._steps maps) may be passed in; `avoid` (cell -> true)
## skips cells; `check` (a Callable(c) -> bool) adds a test of its own (the computer's placement_problem).
static func pick(g: Game, t: int, halls: Array, n := 2, steps: Array = [], avoid := {}, check := Callable(), field := {}) -> Array:
	var out: Array = []
	if g.starts.size() <= t or halls.is_empty():
		return out
	var size: Vector2i = MapGen.HALL
	if field.is_empty():
		field = edge_field(g, edge_cells(g, t))
	if steps.is_empty():
		var foes: Array = []
		for o in g.n_players():
			if g.hostile(o, t) and g.starts.size() > o:
				foes.append(ExpansionSpots._steps(g, g.starts[o]))
		steps = [ExpansionSpots._steps(g, g.starts[t]), foes]
	var main_mid := Vector2(g.starts[t]) + Vector2(2.5, 2.0)
	var axis := (Vector2(Game.W, Game.H) * 0.5 - main_mid).normalized()
	if axis == Vector2.ZERO:
		axis = Vector2.RIGHT
	var starts_mid: Array = []
	for o in g.n_players():
		if g.starts.size() > o:
			starts_mid.append(Vector2(g.starts[o]) + Vector2(2.5, 2.0))
	var hs: Array = halls.duplicate()
	var room_cache := {}
	for k in n:
		var best := {}
		var bkey := []
		var seen := {}
		for hm in hs:
			var hmv: Vector2 = hm
			var r := int(Defs.HALL_SPACING + SLACK) + 3
			for y in range(int(hmv.y) - r, int(hmv.y) + r + 1):
				for x in range(int(hmv.x) - r, int(hmv.x) + r + 1):
					var c := Vector2i(x - size.x / 2, y - size.y / 2)
					if seen.has(c) or avoid.has(c):
						continue
					seen[c] = true
					var cm := Vector2(c) + Vector2(size) * 0.5
					var gap := INF
					var sum := 0.0
					for h2 in hs:
						var dd := cm.distance_to(h2)
						gap = minf(gap, dd)
						sum += dd
					if gap < Defs.HALL_SPACING or gap > Defs.HALL_SPACING + SLACK:
						continue
					var by_start := false
					for sm in starts_mid:
						if cm.distance_to(sm) < Defs.HALL_SPACING:
							by_start = true
					if by_start or not g.in_map(c) or not ground_ok(g, c, size):
						continue
					var home := ExpansionSpots._foot_d(g, steps[0], c)
					if home == INF:
						continue
					var foe := INF
					for fs in steps[1]:
						foe = minf(foe, ExpansionSpots._foot_d(g, fs, c))
					if foe <= home + 4.0:
						continue        # (on the enemy's side, or no nearer us)
					if g.lode_at_spot(c, "town_hall") < 0.5:
						continue        # (a fallen hall drew its land out)
					var room: float
					if room_cache.has(c):
						room = room_cache[c]
					else:
						room = ExpansionSpots._room(g, c)
						room_cache[c] = room
					if room < ROOM_MIN:
						continue
					if check.is_valid() and not bool(check.call(c)):
						continue
					var cv := cover_of(g, field, c, size)
					var share: float = cv["share"] if hs.size() <= COVER_HALLS else 0.0
					var together := (sum / float(hs.size())) - Defs.HALL_SPACING
					var safe := clampf((foe - home) if foe < INF else 40.0, -40.0, 40.0)
					var score := W_ROOM * room + W_COVER * share - W_GAP * (gap - Defs.HALL_SPACING) - W_TOGETHER * maxf(0.0, together) \
							+ W_SAFE * safe
					score = snappedf(score, 0.01)
					# (more precise tests only for the leaders: the ways in are a flood fill)
					if not best.is_empty() and score < float(best["score"]) - 0.005:
						continue        # (the ways in only take away: it cannot win)
					var ways: Array = ExpansionSpots._ways(g, c)
					score = snappedf(score - W_WAYS * maxf(0.0, float(ways[0]) - 1.0), 0.01)
					var rel := cm - main_mid
					var key := [score, snappedf(rel.dot(axis), 0.01), snappedf(rel.cross(axis), 0.01)]
					if best.is_empty() or _better(key, bkey):
						bkey = key
						best = {"c": c, "team": t, "rank": k + 1, "score": score, "room": room, "share": float(cv["share"]),
							"near": float(cv["near"]), "gap": gap, "home": home, "foe": foe, "ways": int(ways[0]), "gapw": int(ways[1])}
		if best.is_empty():
			break
		out.append(best)
		hs.append(Vector2(best["c"]) + Vector2(size) * 0.5)
	return out


static func _better(a: Array, b: Array) -> bool:
	for i in a.size():
		if absf(float(a[i]) - float(b[i])) > 0.005:
			return float(a[i]) > float(b[i])
	return false


## Every Crown side's two spots on the bare map (its main the only hall): for ExpansionSpots' marks, ranks 1 and 2.
static func rate_sides(g: Game) -> Array:
	var out: Array = []
	for t in g.n_players():
		if g.factions.size() > t and String(g.factions[t]) == "crown" and g.starts.size() > t:
			out.append_array(pick(g, t, [Vector2(g.starts[t]) + Vector2(2.5, 2.0)], 2))
	return out
