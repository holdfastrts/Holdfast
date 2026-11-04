class_name CrownSites
extends RefCounted
## THE CROWN'S EXPANSION SPOTS (docs/expansion_spots.md "The Crown's rule").
## v2 (the owner, 2026-11-04 07:05): "The first should still be in the same place it was before, just closer. As close to
## the edge of the map as possible, because that's good for walling. The second expansion should mirror the first on the
## other side of the main. So they should be as close as possible, 18 tiles, as close as possible to the ramp, because it's
## easier for the army to reach it and for the workers to reach it, and as close as possible to the edge of the map, so
## it's easier to wall it." So for the Crown:
##  - the 2nd base (first expansion): on the side of the main's ramp where the old rating's natural lies (ExpansionSpots
##    .rate_all #1), at the least hall distance from the main (Defs.HALL_SPACING, 18 tiles), the shortest walk from the
##    ramp's foot, against the map's border (fewer sides to wall);
##  - the 3rd base: the same three aims on the OTHER side of the line from the main through its ramp (the mirror of the 2nd);
##  - the 4th base on: as close as possible to the Crown's halls (walls join up), against the border where it may be.
## The cover of the main's high ground (v1, 0.29.2: within musket reach of its cliff edge) is only a tie-breaker now.
## Any free ground counts, not only the map's base sites (a hall's land holds the same fresh reserve anywhere: Game.lode_at_spot).
## Used by the gold EXPANSION SPOTS of a Crown side (ExpansionSpots, Game setup) and by the Crown computer's hall pick
## (AICrown._safe_hall_spot). The map is turned through its middle, so twin spots score the same (ties are broken by where
## the spot lies seen from its own main toward the map's middle, which turns with the map).

const REACH := 200.0            # (px) a Musketeer's 190 plus the bodies: an edge cell this near a side of the hall covers it
const SLACK := 9.0              # (tiles) spots looked at up to HALL_SPACING + SLACK from the nearest hall of ours
const ROOM_MIN := 0.3           # ExpansionSpots._room: the Farms' and the Mill's room round the hall (a spot against the
                                # border has only half its circle on the map: 0.3 is still a Mill and its Farms)
const W_GAP := 2.0              # a point a tile farther than the least distance (from the main: 2nd, 3rd; the nearest hall: 4th on)
const W_WALK := 1.5             # (2nd, 3rd) a point and a half a step of the walk from the main ramp's foot
const WALK_NEAR := 12.0         # (steps) past this walk from the ramp's foot a spot is "far out" (the owner): W_FAR more a step
const W_FAR := 2.0              #   (so the border never pulls a hall round the main's cliff, away from the ramp)
const W_EDGE := 2.0             # a point a tile between the hall and the map's border (past the one free cell)
const W_OPEN := 3.0             # a point an open side (CrownSites.open_sides: a side the wall has to close)
const W_ROOM := 10.0            # the economy room (0..1)
const W_COVER := 3.0            # (2nd, 3rd; tie-breaker) the share of the hall's sides the main's cliff edge covers
const W_TOGETHER := 1.0         # (4th on) a point a tile, the mean distance to the other halls past the minimum
const W_SAFE := 0.1             # half-steps nearer us than the enemy (capped at 40)
const SIDE_BAND := 1.5          # (tiles) from the line main -> ramp's foot: a spot this near the line is on both sides
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



## Which side of the line from the main's middle through its ramp's foot a spot's middle lies on: -1, 1, or 0 within
## SIDE_BAND of the line (or no ramp). The line turns with the map, so twins get the same side.
static func side_of(g: Game, t: int, ramp: Dictionary, mid: Vector2) -> int:
	if ramp.is_empty():
		return 0
	var main_mid := Vector2(g.starts[t]) + Vector2(2.5, 2.0)
	var ax: Vector2 = (ramp["foot"] - main_mid).normalized()
	var x := ax.cross(mid - main_mid)
	if absf(x) <= SIDE_BAND:
		return 0
	return 1 if x > 0.0 else -1


## The main's ramp and the walk field from its foot (from round the main when it has no ramp), kept in `field`.
static func _prep(g: Game, t: int, field: Dictionary) -> void:
	if not field.has("ramp"):
		field["ramp"] = ramp_of(g, t)
	if not field.has("foot_d"):
		var rp: Dictionary = field["ramp"]
		field["foot_d"] = steps_from(g, rp["feet"]) if not rp.is_empty() else ExpansionSpots._steps(g, g.starts[t])


## The side of the old rating's natural (ExpansionSpots.rate_all #1 of team t): the 2nd base goes there. Kept in `field`.
static func natural_side(g: Game, t: int, field: Dictionary) -> int:
	if not field.has("nat_side"):
		var s := 0
		for r in ExpansionSpots.rate_all(g):
			if int(r["team"]) == t and int(r["rank"]) == 1:
				field["nat"] = r["c"]
				s = side_of(g, t, field["ramp"], Vector2(r["c"]) + Vector2(MapGen.HALL) * 0.5)
		field["nat_side"] = s
	return int(field["nat_side"])


## The Crown's best hall spots for team t, given its halls (their middles in tiles; the main first): `n` picks, each one
## with the earlier picks counted as halls. With the main alone the pick is the 2nd base, with two halls the 3rd (on the
## other side of the main's ramp from the second hall), then the 4th on. Each pick: {"c", "team", "rank", "stage" (2, 3,
## 4: the base it is), "score", "room", "share" (cover), "near", "gap" (tiles to the nearest hall), "main" (tiles to the
## main), "walk" (steps from the main ramp's foot), "edge" (tiles to the border), "open" (sides open), "side", "home"
## (steps from the main), "foe" (from the enemy), "ways", "gapw"}. `steps` ([ours, [the enemies'...]]:
## ExpansionSpots._steps maps) may be passed in; `avoid` (cell -> true) skips cells; `check` (a Callable(c) -> bool) adds
## a test of its own (the computer's placement_problem); `field` (edge_field's; also keeps the ramp's walk) may be passed
## in and is kept between calls.
static func pick(g: Game, t: int, halls: Array, n := 2, steps: Array = [], avoid := {}, check := Callable(), field_in = null) -> Array:
	var out: Array = []
	if g.starts.size() <= t or halls.is_empty():
		return out
	# (a caller's field is kept and filled; none: a new one. Not a `{}` default: the caches below would outlive the call)
	var field: Dictionary = field_in if field_in is Dictionary else {}
	if not field.has("f"):
		field.merge(edge_field(g, edge_cells(g, t)), true)
	_prep(g, t, field)
	if steps.is_empty():
		var foes: Array = []
		for o in g.n_players():
			if g.hostile(o, t) and g.starts.size() > o:
				foes.append(ExpansionSpots._steps(g, g.starts[o]))
		steps = [ExpansionSpots._steps(g, g.starts[t]), foes]
	var hs: Array = halls.duplicate()
	if not field.has("room") or int(field.get("room_n", -1)) != g.buildings.size():
		field["room"] = {}      # (the economy room of a spot, kept with the field between calls while no building comes or goes)
		field["room_n"] = g.buildings.size()
	var room_cache: Dictionary = field["room"]
	for k in n:
		var stage := 2 if hs.size() <= 1 else (3 if hs.size() == 2 else 4)
		var want := 0           # (the side wanted: the 2nd the natural's, the 3rd the other side from the second hall)
		if stage == 2:
			want = natural_side(g, t, field)
		elif stage == 3:
			want = -side_of(g, t, field["ramp"], hs[1])
		var rec := {}
		if stage == 2 and corner_on(g):
			rec = _corner(g, t, hs, steps, avoid, check, field, room_cache)
		elif stage == 2:
			rec = _pair(g, t, hs, want, steps, avoid, check, field, room_cache)
		else:
			rec = _best(g, t, hs, stage, want, steps, avoid, check, field, room_cache)
		if rec.is_empty() and want != 0:
			rec = _best(g, t, hs, stage, 0, steps, avoid, check, field, room_cache)     # (nothing legal on that side)
		if rec.is_empty():
			break
		var ways: Array = ExpansionSpots._ways(g, rec["c"])
		rec["ways"] = int(ways[0])
		rec["gapw"] = int(ways[1])
		rec["rank"] = k + 1
		out.append(rec)
		hs.append(Vector2(rec["c"]) + Vector2(MapGen.HALL) * 0.5)
	return out


const PAIR_KEEP := 64           # (2nd base) the best spots kept on each side of the ramp to pair with a 3rd

## The 2nd base as one of a MIRRORED PAIR (the owner: "the second expansion should mirror the first on the other side of
## the main"): the best 2nd (on side `want`, the natural's) and 3rd (the other side) a hall's spacing apart, by the sum of
## their scores; so the 2nd does not take the ground under the ramp that its mirror needs. With no side wanted (the natural
## on the line) both ways round are tried and the 2nd is the better of the pair. Nothing on the other side: the best 2nd.
static func _pair(g: Game, t: int, hs: Array, want: int, steps: Array, avoid: Dictionary, check: Callable, field: Dictionary,
		room_cache: Dictionary) -> Dictionary:
	var best := {}
	var bkey := []
	for w in ([want] if want != 0 else [1, -1]):
		var a := _ranked(g, t, hs, 2, w, steps, avoid, check, field, room_cache, PAIR_KEEP)
		var b := _ranked(g, t, hs, 3, -w, steps, avoid, Callable(), field, room_cache, PAIR_KEEP)
		for ra in a:
			var ma := Vector2(ra["c"]) + Vector2(MapGen.HALL) * 0.5
			for rb in b:
				if ma.distance_to(Vector2(rb["c"]) + Vector2(MapGen.HALL) * 0.5) < Defs.HALL_SPACING:
					continue
				var s := snappedf(float(ra["score"]) + float(rb["score"]), 0.01)
				var b_first := want == 0 and _better(rb["key"], ra["key"])
				var first: Dictionary = rb if b_first else ra
				var key: Array = [s] + (first["key"] as Array)
				if best.is_empty() or _better(key, bkey):
					best = first.duplicate()
					best["stage"] = 2
					best["pair"] = ra["c"] if b_first else rb["c"]
					bkey = key
	if best.is_empty():
		return _best(g, t, hs, 2, want, steps, avoid, check, field, room_cache)
	return best


## The best spot for one stage (2: the 2nd base, 3: the 3rd, 4: the 4th on), on side `want` of the main's ramp (0: any;
## a spot on the line itself is on neither side). Two passes: the cheap terms first (distance, side, bare ground, walk,
## border, open sides), then the dear ones (the walks from the mains, the economy room, the cover, the caller's check) in the
## order of the cheap score, stopping where even a full room and cover could no longer win.
static func _best(g: Game, t: int, hs: Array, stage: int, want: int, steps: Array, avoid: Dictionary, check: Callable,
		field: Dictionary, room_cache: Dictionary) -> Dictionary:
	var r := _ranked(g, t, hs, stage, want, steps, avoid, check, field, room_cache, 1)
	return {} if r.is_empty() else r[0]


## The `keep` best spots for a stage (as _best), best first; each record carries its tie key ("key").
static func _ranked(g: Game, t: int, hs: Array, stage: int, want: int, steps: Array, avoid: Dictionary, check: Callable,
		field: Dictionary, room_cache: Dictionary, keep: int) -> Array:
	var size: Vector2i = MapGen.HALL
	var ramp: Dictionary = field["ramp"]
	var foot_d: PackedFloat32Array = field["foot_d"]
	var main_mid := Vector2(g.starts[t]) + Vector2(2.5, 2.0)
	var axis := (Vector2(Game.W, Game.H) * 0.5 - main_mid).normalized()
	if axis == Vector2.ZERO:
		axis = Vector2.RIGHT
	var starts_mid: Array = []
	for o in g.n_players():
		if g.starts.size() > o:
			starts_mid.append(Vector2(g.starts[o]) + Vector2(2.5, 2.0))
	var cands: Array = []           # [cheap score, c, dist, gap, md, walk, ed, op, side, together]
	var seen := {}
	for hm in (hs if stage == 4 else [main_mid]):
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
				var md := cm.distance_to(main_mid)
				var dist := md if stage < 4 else gap
				if gap < Defs.HALL_SPACING or dist > Defs.HALL_SPACING + SLACK:
					continue
				var side := side_of(g, t, ramp, cm)
				if want != 0 and side != want:
					continue
				var by_start := false
				for sm in starts_mid:
					if cm.distance_to(sm) < Defs.HALL_SPACING:
						by_start = true
				if by_start or not g.in_map(c) or not ground_ok(g, c, size):
					continue
				var walk := ExpansionSpots._foot_d(g, foot_d, c)
				if walk == INF:
					continue
				var ed := edge_d(c, size)
				var op := open_sides(g, c, size)
				var together := maxf(0.0, (sum / float(hs.size())) - Defs.HALL_SPACING)
				var cheap := -W_GAP * (dist - Defs.HALL_SPACING) - W_EDGE * maxf(0.0, float(ed) - 1.0) - W_OPEN * float(op)
				cheap += -(W_WALK * walk + W_FAR * maxf(0.0, walk - WALK_NEAR)) if stage < 4 else -W_TOGETHER * together
				cands.append([cheap, c, dist, gap, md, walk, ed, op, side])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var top := W_ROOM + W_COVER + W_SAFE * 40.0     # (the most the dear terms add)
	var kept: Array = []            # records, best first
	for cd in cands:
		var full := kept.size() >= keep
		if full and float(cd[0]) + top < float(kept[-1]["score"]) - 0.005:
			break
		var c: Vector2i = cd[1]
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
		var cv := cover_of(g, field, c, size)
		var safe := clampf((foe - home) if foe < INF else 40.0, -40.0, 40.0)
		var score := float(cd[0]) + W_ROOM * room + W_SAFE * safe + (W_COVER * float(cv["share"]) if stage < 4 else 0.0)
		score = snappedf(score, 0.01)
		if full and score < float(kept[-1]["score"]) - 0.005:
			continue
		if check.is_valid() and not bool(check.call(c)):
			continue
		var rel := Vector2(c) + Vector2(size) * 0.5 - main_mid
		var key := [score, snappedf(rel.dot(axis), 0.01), snappedf(rel.cross(axis), 0.01)]
		var rec := {"c": c, "team": t, "stage": stage, "score": score, "room": room, "share": float(cv["share"]),
			"near": float(cv["near"]), "gap": float(cd[3]), "main": float(cd[4]), "walk": float(cd[5]), "edge": int(cd[6]),
			"open": int(cd[7]), "side": int(cd[8]), "home": home, "foe": foe, "key": key}
		var at := kept.size()
		while at > 0 and _better(key, kept[at - 1]["key"]):
			at -= 1
		if at < keep:
			kept.insert(at, rec)
			if kept.size() > keep:
				kept.pop_back()
	return kept


static func _better(a: Array, b: Array) -> bool:
	for i in a.size():
		if absf(float(a[i]) - float(b[i])) > 0.005:
			return float(a[i]) > float(b[i])
	return false



## The main's RAMP for team t: the ramp nearest the main hall (as Game.ramp_foot): {"feet": [Vector2i...] (the cells just
## below it, every one as near: a ramp is two or more cells wide), "foot": Vector2 (their middle, in tiles), "top": Vector2};
## empty when the main has no ramp within 30 tiles (a main on the low ground). Distances from the hall's middle, so the
## twin main (the map turned through its middle) gets the twin ramp.
static func ramp_of(g: Game, t: int) -> Dictionary:
	if g.starts.size() <= t or g.height.size() != Game.W * Game.H:
		return {}
	var hc: Vector2i = g.starts[t] + Vector2i(2, 2)
	if not g.in_map(hc):
		return {}
	var mid := Vector2(g.starts[t]) + Vector2(2.5, 2.0)
	var h0 := int(g.height[g.idx(hc)])
	var bd := INF
	var feet: Array = []
	var tops: Array = []
	for y in range(hc.y - 30, hc.y + 31):
		for x in range(hc.x - 30, hc.x + 31):
			var r := Vector2i(x, y)
			if not g.in_map(r) or g.ramp[g.idx(r)] != 1:
				continue
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = r + dd
				if not g.in_map(p) or g.ramp[g.idx(p)] != 0 or int(g.height[g.idx(p)]) != h0:
					continue
				var f := r
				var n := 0
				while g.in_map(f) and g.ramp[g.idx(f)] == 1 and n < 12:
					f -= dd
					n += 1
				if not g.in_map(f) or int(g.height[g.idx(f)]) == h0:
					continue
				var d := (Vector2(p) + Vector2(0.5, 0.5)).distance_to(mid)
				if d < bd - 0.01:
					bd = d
					feet = []
					tops = []
				if d <= bd + 0.01 and not feet.has(f):
					feet.append(f)
					tops.append(p)
	if feet.is_empty():
		return {}
	var fm := Vector2.ZERO
	var tm := Vector2.ZERO
	for i in feet.size():
		fm += Vector2(feet[i]) + Vector2(0.5, 0.5)
		tm += Vector2(tops[i]) + Vector2(0.5, 0.5)
	return {"feet": feet, "foot": fm / feet.size(), "top": tm / feet.size()}


## Steps by land (4 ways, over open ground) from some cells to every cell (INF: none): the walk from the ramp's foot.
static func steps_from(g: Game, cells: Array) -> PackedFloat32Array:
	var W := Game.W
	var n_cells := W * Game.H
	var d := PackedFloat32Array()
	d.resize(n_cells)
	d.fill(INF)
	var q := PackedInt32Array()
	for c in cells:
		if g.in_map(c) and d[g.idx(c)] == INF:
			d[g.idx(c)] = 0.0
			q.append(g.idx(c))
	var head := 0
	while head < q.size():
		var i: int = q[head]
		head += 1
		var nd := d[i] + 1.0
		var x := i % W
		for j in [i + 1 if x + 1 < W else -1, i - 1 if x > 0 else -1, i + W if i + W < n_cells else -1, i - W]:
			if j >= 0 and d[j] == INF and g.solid[j] != 1 and g.cliff[j] == 0:
				d[j] = nd
				q.append(j)
	return d


## Tiles from a hall's footprint to the map's border (0: it touches it; ground_ok keeps one free cell, so 1 is the least).
static func edge_d(c: Vector2i, size: Vector2i) -> int:
	return mini(mini(c.x, c.y), mini(Game.W - (c.x + size.x), Game.H - (c.y + size.y)))


const SHUT := 3                 # (cells) a side is shut when every cell out from it meets the border or blocked ground this near
## How many of a hall's four sides are OPEN (to be walled): a side is shut when, from every cell along it, going straight
## out, the map's border or ground no army walks (solid, cliff) comes within SHUT cells (the hall's free ring and a
## gap a wall piece or two closes).
static func open_sides(g: Game, c: Vector2i, size: Vector2i) -> int:
	var n := 0
	for side in 4:
		var dir: Vector2i = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)][side]
		var cells: Array = []
		if side < 2:
			for y in size.y:
				cells.append(Vector2i(c.x if side == 0 else c.x + size.x - 1, c.y + y))
		else:
			for x in size.x:
				cells.append(Vector2i(c.x + x, c.y if side == 2 else c.y + size.y - 1))
		var shut := true
		for s in cells:
			var hit := false
			for k in range(1, SHUT + 1):
				var p: Vector2i = s + dir * k
				if not g.in_map(p) or g.solid[g.idx(p)] == 1 or g.cliff[g.idx(p)] != 0:
					hit = true
					break
			if not hit:
				shut = false
				break
		if not shut:
			n += 1
	return n


## Every Crown side's two spots on the bare map (its main the only hall): for ExpansionSpots' marks, ranks 1 and 2.
static func rate_sides(g: Game) -> Array:
	var out: Array = []
	for t in g.n_players():
		if g.factions.size() > t and String(g.factions[t]) == "crown" and g.starts.size() > t:
			out.append_array(pick(g, t, [Vector2(g.starts[t]) + Vector2(2.5, 2.0)], 2))
	return out



## THE CORNER POCKET EXPERIMENT (crown-v-brood, the owner 2026-11-04 15:23): `-- nat:corner` on the command line, or the
## match cfg "crown_nat": "corner", picks the Crown's 2nd base in the pocket between the map's border and the main's cliff
## (variant B) instead of by the ramp's foot (variant A, the rule above). Not a player setting.
static func corner_on(g: Game) -> bool:
	if OS.get_cmdline_user_args().has("nat:corner"):
		return true
	return g != null and g.has_meta("crown_nat") and String(g.get_meta("crown_nat")) == "corner"


## Variant B: the 2nd base in a CORNER POCKET (the owner: "near the corner of the map, away from the ramp ... the easier way to
## wall is there, using the edge of the map and the high ground as natural barriers"). Any legal spot 18 to 18 + B_REACH
## tiles from the main, on our side by land, with room for its economy; scored for the shortest wall first: every open
## side (open_sides) and every cell of its MOUTH (mouth: the open ground round it at B_MOUTH_R tiles that an army walks in
## through) costs, the border near it pays, the walk from the main's ramp costs only a little (B_WALK a step).
const B_REACH := 16.0
const B_OPEN := 12.0
const B_MOUTH := 1.0
const B_MOUTH_R := 9.0
const B_EDGE := 3.0
const B_WALK := 0.25
const B_KEEP := 40


static func _corner(g: Game, t: int, hs: Array, steps: Array, avoid: Dictionary, check: Callable, field: Dictionary,
		room_cache: Dictionary) -> Dictionary:
	var size: Vector2i = MapGen.HALL
	var foot_d: PackedFloat32Array = field["foot_d"]
	var main_mid := Vector2(g.starts[t]) + Vector2(2.5, 2.0)
	var starts_mid: Array = []
	for o in g.n_players():
		if g.starts.size() > o:
			starts_mid.append(Vector2(g.starts[o]) + Vector2(2.5, 2.0))
	var cands: Array = []
	var r := int(Defs.HALL_SPACING + B_REACH) + 3
	for y in range(int(main_mid.y) - r, int(main_mid.y) + r + 1):
		for x in range(int(main_mid.x) - r, int(main_mid.x) + r + 1):
			var c := Vector2i(x - size.x / 2, y - size.y / 2)
			if avoid.has(c):
				continue
			var cm := Vector2(c) + Vector2(size) * 0.5
			var gap := INF
			for h2 in hs:
				gap = minf(gap, cm.distance_to(h2))
			var md := cm.distance_to(main_mid)
			if gap < Defs.HALL_SPACING or md > Defs.HALL_SPACING + B_REACH:
				continue
			var by_start := false
			for sm in starts_mid:
				if cm.distance_to(sm) < Defs.HALL_SPACING:
					by_start = true
			if by_start or not g.in_map(c) or not ground_ok(g, c, size):
				continue
			var walk := ExpansionSpots._foot_d(g, foot_d, c)
			if walk == INF:
				continue
			var ed := edge_d(c, size)
			var op := open_sides(g, c, size)
			var cheap := -B_OPEN * float(op) - B_EDGE * maxf(0.0, float(ed) - 1.0) - B_WALK * walk - 0.5 * (md - Defs.HALL_SPACING)
			cands.append([cheap, c, md, walk, ed, op])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var best := {}
	var n := 0
	for cd in cands:
		if n >= B_KEEP:
			break
		var c: Vector2i = cd[1]
		var home := ExpansionSpots._foot_d(g, steps[0], c)
		if home == INF:
			continue
		var foe := INF
		for fs in steps[1]:
			foe = minf(foe, ExpansionSpots._foot_d(g, fs, c))
		if foe <= home + 4.0:
			continue
		if g.lode_at_spot(c, "town_hall") < 0.5:
			continue
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
		n += 1
		var mo := mouth(g, c, size)
		var score := snappedf(float(cd[0]) - B_MOUTH * float(mo) + W_ROOM * room, 0.01)
		var rel := Vector2(c) + Vector2(size) * 0.5 - main_mid
		if best.is_empty() or score > float(best["score"]) + 0.005 or (absf(score - float(best["score"])) <= 0.005 and rel.length() < (Vector2(best["c"]) + Vector2(size) * 0.5 - main_mid).length()):
			best = {"c": c, "team": t, "stage": 2, "score": score, "room": room, "share": 0.0, "near": INF, "gap": 0.0,
				"main": float(cd[2]), "walk": float(cd[3]), "edge": int(cd[4]), "open": int(cd[5]), "side": 0, "home": home,
				"foe": foe, "mouth": mo, "corner": true, "key": [score]}
	return best


## The MOUTH of a hall spot: walking out from round the hall (4 ways, open ground, no cliff), the cells B_MOUTH_R tiles out
## that the walk reaches: the width of open ground the wall has to close (the border, the cliffs and the solid ground close
## the rest). A pocket against the border and a cliff has a narrow mouth; a spot in the open a whole circle.
static func mouth(g: Game, c: Vector2i, size: Vector2i) -> int:
	var mid := Vector2(c) + Vector2(size) * 0.5
	var seen := {}
	var q: Array = []
	for y in range(c.y - 1, c.y + size.y + 1):
		for x in range(c.x - 1, c.x + size.x + 1):
			var p := Vector2i(x, y)
			if g.in_map(p) and g.solid[g.idx(p)] != 1 and g.cliff[g.idx(p)] == 0:
				seen[p] = true
				q.append(p)
	var head := 0
	var n := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		var d := (Vector2(p) + Vector2(0.5, 0.5)).distance_to(mid)
		if d >= B_MOUTH_R:
			n += 1
			continue
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var p2: Vector2i = p + dd
			if seen.has(p2) or not g.in_map(p2):
				continue
			var j := g.idx(p2)
			if g.solid[j] == 1 or g.cliff[j] != 0:
				continue
			seen[p2] = true
			q.append(p2)
	return n
