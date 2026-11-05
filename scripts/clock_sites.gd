class_name ClockSites
extends RefCounted
## THE CLOCKWORK'S EXPANSION SPOTS (clockwork-eco, 0.30.10; docs/clockwork_eco.md "The spot rule").
## The owner, 2026-11-04 20:24: "The Clockwork's optimal expansion spot has to be different than it currently is: the
## Clocktower's gear is very important, Clocktowers need room around them." A Clocktower is the root of a gear field: its
## Cog Presses, its Mainspring, the Regulators and the Works mesh round its big ring (docs/gear_rules.md), and rings mesh
## only on ONE ground level (THE LEVEL RULE). A spot squeezed against a cliff or a ramp has no room for that ring (his
## picture: the 2nd Clocktower against the main's cliff and ramp, nothing could be built round it).
## So a Clockwork spot is good when:
##  1. THE RING FITS: round the Clocktower's ring, the buildings it powers fit, meshing with it directly, on open ground of
##     the hall's own level, off ramps, with a free lane round each (ring_fit: a greedy packing of 3x3 small rings round the
##     tower's ring, every RING_STEP degrees; RING_NEED of them, the two Cog Presses, the Mainspring, a Regulator and two
##     production buildings; a spot short of it pays W_SHORT a building);
##  2. there is room beyond it for the next ring (the Works and the Escapement meshing to the first ring: outer_room, the
##     share of the band round it that is buildable ground of the same level);
##  3. it is near: the least hall distance (Defs.HALL_SPACING) from the main (2nd base) or from its other halls (3rd on),
##     a short walk by land from them (W_WALK a step past the least);
##  4. it is safe: nearer us than the enemy by land (W_SAFE).
## Any free ground counts, not only the map's base sites (a hall's ore is the same fresh reserve anywhere:
## Game.lode_at_spot). Used by the gold EXPANSION SPOTS of a Clockwork side (ExpansionSpots._clock_rule) and by the
## Clockwork computer's hall pick (AIClockwork._safe_hall_spot). The map is turned through its middle; the packing is
## worked in whole degrees from a fixed start, turned with the map (its start is the direction to the map's middle), so
## twin spots score the same.

const RING_KIND := "cog_press"      # the ring's buildings are counted as 3x3 small rings (a Cog Press, Mainspring, Escapement)
const RING_NEED := 8                # of the 9 that fit on open ground: 2 presses, the Mainspring, Regulators, the Works, the Escapement
const RING_STEP := 6.0              # degrees between the angles tried
const W_SHORT := 15.0               # points a building of RING_NEED that does not fit
const W_SLOT := 2.0                 # two points for each building past RING_NEED that fits too (a full ring)
const SLOTS_CAP := 10
const W_OUTER := 50.0               # the share of the outer band that is buildable (0..1): the room to build on beyond the ring
const W_GAP := 0.5                  # half a point a tile farther than the least hall distance from the nearest hall
const W_WALK := 0.5                 # half a point a step of the walk from the main
const W_SAFE := 0.15                # half-steps nearer us than the enemy (capped at 40)
const SLACK := 12.0                 # (tiles) spots looked at up to HALL_SPACING + SLACK from the nearest hall
const GRID := 1                     # (cells) the candidates' spacing
const KEEP := 24                    # the best cheap candidates whose ring is measured


## The Clocktower's ring at cell c (top-left of its 5x4 footprint): [centre in gear space, pitch radius].
static func tower_ring(c: Vector2i) -> Array:
	var T := float(Defs.TILE)
	var size: Vector2i = Defs.BUILDINGS["clocktower"]["size"]
	return [GearNet.gpos(Vector2(c) * T + Vector2(size) * T * 0.5), GearNet.ring_r("clocktower", size, false)]


## A footprint for a ring building: inside the map, free, off ramps and clear of them, its margin free, all on level lv.
static func _foot_ok(g: Game, c: Vector2i, size: Vector2i, lv: int) -> bool:
	if c.x < 1 or c.y < 1 or c.x + size.x >= Game.W or c.y + size.y >= Game.H:
		return false
	for y in range(c.y - 1, c.y + size.y + 1):
		for x in range(c.x - 1, c.x + size.x + 1):
			var i := y * Game.W + x
			if g.solid[i] != 0:
				return false
			var inside := x >= c.x and x < c.x + size.x and y >= c.y and y < c.y + size.y
			if inside and (g.ramp[i] != 0 or g.cliff[i] != 0 or int(g.height[i]) != lv or g._near_ramp(Vector2i(x, y))):
				return false
	return true


## How many ring buildings (3x3 small rings) fit meshing directly with a Clocktower at cell c: a greedy packing round the
## tower's ring, every RING_STEP degrees from `start` (degrees), each ring off the others (Defs.GEAR overlap) and off the
## rings in `rings` ([[gear centre, radius], ...]: buildings standing), each footprint on the tower's level, the mesh point on
## that level (GearNet.joint_ok). Returns [count, [cells]].
static func ring_fit(g: Game, c: Vector2i, start := 0.0, rings: Array = []) -> Array:
	var T := float(Defs.TILE)
	var tr := tower_ring(c)
	var tc: Vector2 = tr[0]
	var tr_r: float = tr[1]
	var tsize: Vector2i = Defs.BUILDINGS["clocktower"]["size"]
	var lv := GearNet.foot_level(g, c, tsize)
	var size: Vector2i = Defs.BUILDINGS[RING_KIND]["size"]
	var r := GearNet.ring_r(RING_KIND, size, false)
	var over := float(Defs.GEAR["overlap"]) * T
	var placed: Array = []          # [gear centre, Rect2i]
	var cells: Array = []
	var trect := Rect2i(c, tsize)
	var a := 0.0
	while a < 360.0 - 0.01:
		var ang := deg_to_rad(start + a)
		a += RING_STEP
		var found := false
		for k in 3:
			var dist := tr_r + r + float(k) * 0.5 * T
			var g2 := tc + Vector2(cos(ang), sin(ang)) * dist
			var world := Vector2(g2.x, g2.y * GearNet.FY)
			var fc := Vector2(world.x / T - float(size.x) * 0.5, world.y / T - float(size.y) * 0.5)
			var c2 := Vector2i(int(floor(fc.x + 0.5)), int(floor(fc.y + 0.5)))
			# (the ring's centre from the cell, as the game works it)
			var gc := GearNet.gpos(Vector2(c2) * T + Vector2(size) * T * 0.5)
			var gap := gc.distance_to(tc) - r - tr_r
			if gap < -over or gap > float(Defs.GEAR["slack"]) * T:
				continue
			var rect := Rect2i(c2, size)
			if rect.grow(1).intersects(trect):
				continue
			var bad := false
			for p in placed:
				if gc.distance_to(p[0]) - 2.0 * r < -over or rect.grow(1).intersects(p[1]):
					bad = true
					break
			if bad:
				continue
			for q in rings:
				if gc.distance_to(q[0]) - r - float(q[1]) < -over:
					bad = true
					break
			if bad or not _foot_ok(g, c2, size, lv):
				continue
			if not GearNet.joint_ok(g, gc, r, tc, tr_r, lv):
				continue
			placed.append([gc, rect])
			cells.append(c2)
			found = true
			break
		if found:
			a += 18.0           # (the next ring building cannot be nearer than this round the tower: skip ahead)
	return [cells.size(), cells]


## The share (0..1) of the band beyond the first ring (where the second ring's buildings go) that is open ground of the
## tower's level, off ramps.
static func outer_room(g: Game, c: Vector2i) -> float:
	var T := float(Defs.TILE)
	var tr := tower_ring(c)
	var tc: Vector2 = tr[0]
	var r0: float = float(tr[1]) + 2.0 * GearNet.ring_r(RING_KIND, Defs.BUILDINGS[RING_KIND]["size"], false)
	var r1 := r0 + 4.0 * T
	var lv := GearNet.foot_level(g, c, Defs.BUILDINGS["clocktower"]["size"])
	var n := 0
	var ok := 0
	var mid := Vector2(tc.x, tc.y * GearNet.FY) / T
	var reach := int(ceil(r1 / T)) + 1
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cc := Vector2i(int(floor(mid.x)) + dx, int(floor(mid.y)) + dy)
			var gp := GearNet.gpos((Vector2(cc) + Vector2(0.5, 0.5)) * T)
			var d := gp.distance_to(tc)
			if d < r0 or d > r1:
				continue
			n += 1
			if not g.in_map(cc):
				continue
			var i := g.idx(cc)
			if g.solid[i] == 0 and g.cliff[i] == 0 and g.ramp[i] == 0 and int(g.height[i]) == lv:
				ok += 1
	return float(ok) / float(maxi(1, n))


## Where the ring's packing starts for a side (degrees): toward the map's middle from the spot, so the start turns with
## the map and twin spots pack alike.
static func _start(c: Vector2i) -> float:
	var mid := Vector2(Game.W, Game.H) * 0.5
	var cm := Vector2(c) + Vector2(MapGen.HALL) * 0.5
	var v := mid - cm
	if v.length() < 0.5:
		return 0.0
	return roundf(rad_to_deg(v.angle()))


## The rings of the buildings standing (gear centre, radius), for a pick in a game under way.
static func rings_of(g: Game) -> Array:
	var out: Array = []
	for b in g.buildings:
		if is_instance_valid(b) and not b.dead and GearNet.has_gear(b):
			out.append([GearNet.b_c(b), GearNet.b_r(b)])
	return out


## The best spots for side t, `n` of them, each at least the hall spacing from every hall in `halls` (tile centres) and
## from the ones picked before it: [{c, team, rank, score, slots, outer, walk, foe, gap}]. `steps`: [ours, [foes...]]
## walks by land (ExpansionSpots._steps), worked out when empty; `avoid`: cells not to take; `check`: a Callable(c) -> bool
## the caller's own test (the computer's placement rules); `rings`: rings of buildings standing (rings_of).
static func pick(g: Game, t: int, halls: Array, n := 2, steps: Array = [], avoid := {}, check := Callable(), rings: Array = []) -> Array:
	var out: Array = []
	if g.starts.size() <= t or halls.is_empty() or g.height.size() != Game.W * Game.H:
		return out
	if steps.is_empty():
		var foes: Array = []
		for o in g.n_players():
			if g.hostile(o, t) and g.starts.size() > o:
				foes.append(ExpansionSpots._steps(g, g.starts[o]))
		steps = [ExpansionSpots._steps(g, g.starts[t]), foes]
	var hs: Array = halls.duplicate()
	var spacing := float(Defs.HALL_SPACING)
	var hsize := MapGen.HALL
	for k in n:
		# cheap pass: every legal cell in the band round our halls, scored without its ring
		var cheap: Array = []
		var lo := Vector2i(Game.W, Game.H)
		var hi := Vector2i(-1, -1)
		for h in hs:
			var hv: Vector2 = h
			lo = Vector2i(mini(lo.x, int(hv.x - spacing - SLACK - 3.0)), mini(lo.y, int(hv.y - spacing - SLACK - 3.0)))
			hi = Vector2i(maxi(hi.x, int(hv.x + spacing + SLACK + 3.0)), maxi(hi.y, int(hv.y + spacing + SLACK + 3.0)))
		lo = Vector2i(maxi(lo.x, 1), maxi(lo.y, 1))
		hi = Vector2i(mini(hi.x, Game.W - hsize.x - 1), mini(hi.y, Game.H - hsize.y - 1))
		for y in range(lo.y, hi.y + 1, GRID):
			for x in range(lo.x, hi.x + 1, GRID):
				var c := Vector2i(x, y)
				var cm := Vector2(c) + Vector2(hsize) * 0.5
				var near := INF
				for h in hs:
					near = minf(near, cm.distance_to(h))
				if near < spacing or near > spacing + SLACK:
					continue
				if avoid.has(c) or not CrownSites.ground_ok(g, c, hsize):
					continue
				var own := ExpansionSpots._foot_d(g, steps[0], c)
				if own == INF:
					continue
				var foe := INF
				for fd in steps[1]:
					foe = minf(foe, ExpansionSpots._foot_d(g, fd, c))
				if foe < INF and foe <= own:
					continue            # (nearer the enemy by land: never)
				var safe := clampf((foe - own) if foe < INF else 60.0, -40.0, 40.0)
				var cs := W_GAP * (near - spacing) + W_WALK * own - W_SAFE * safe
				cheap.append([cs, c, near, own, foe])
		if cheap.is_empty():
			break
		cheap.sort_custom(func(a: Array, b: Array) -> bool:
			if absf(float(a[0]) - float(b[0])) > 0.0001:
				return float(a[0]) < float(b[0])
			return _tie(a[1], b[1]))
		# the ring: measured for the best cheap ones (a far spot with a perfect ring never beats the walk of a near one by
		# more than its ring is worth: W_SHORT a building)
		var best := {}
		var bs := INF
		for i in mini(KEEP * 4, cheap.size()):
			var e: Array = cheap[i]
			if float(e[0]) - float(cheap[0][0]) > W_SHORT * float(RING_NEED) + W_OUTER:
				break
			if float(e[0]) >= bs:
				break           # (the ring can only add: nothing below beats the best already found)
			var c: Vector2i = e[1]
			if check.is_valid() and not bool(check.call(c)):
				continue
			var fit: Array = ring_fit(g, c, _start(c), rings)
			var slots := int(fit[0])
			var outer := outer_room(g, c)
			var sc := float(e[0]) + W_SHORT * maxf(0.0, float(RING_NEED - slots)) - W_SLOT * float(clampi(slots - RING_NEED, 0, SLOTS_CAP - RING_NEED)) \
				+ W_OUTER * (1.0 - outer)
			if sc < bs - 0.0001 or (absf(sc - bs) <= 0.0001 and _tie(c, best["c"])):
				bs = sc
				best = {"c": c, "team": t, "score": sc, "slots": slots, "ring": fit[1], "outer": outer, "gap": float(e[2]) - spacing,
					"walk": float(e[3]), "home": float(e[3]), "foe": float(e[4]), "room": outer, "ways": 0, "clock": true}
		if best.is_empty():
			break
		best["rank"] = k + 1
		out.append(best)
		hs.append(Vector2(best["c"]) + Vector2(hsize) * 0.5)
	return out


## A tie between two cells, the same for twins: the one farther along from the map's middle (turned with the map).
static func _tie(a: Vector2i, b: Vector2i) -> bool:
	var mid := Vector2(Game.W, Game.H) * 0.5 - Vector2(MapGen.HALL) * 0.5
	var va := Vector2(a) - mid
	var vb := Vector2(b) - mid
	if absf(va.length_squared() - vb.length_squared()) > 0.01:
		return va.length_squared() < vb.length_squared()
	return va.angle() < vb.angle()


## Every Clockwork side's two spots on the bare map (ExpansionSpots at the start).
static func rate_sides(g: Game) -> Array:
	var out: Array = []
	for t in g.n_players():
		if g.factions.size() > t and String(g.factions[t]) == "clockwork" and g.starts.size() > t:
			out.append_array(pick(g, t, [Vector2(g.starts[t]) + Vector2(2.5, 2.0)], 2))
	return out


## THE RING AS THE GAME PLACES IT (tests and pictures; changes the game: it adds finished buildings): the kinds in `kinds`,
## each laid where the game itself allows it (Game.placement_problem: the gear rules, the level rule, the margins) with its
## ring meshing directly with the Clocktower `tower` (GearNet.ring_spot, tried every 15 degrees from the map's middle), the
## buildings standing at once. Returns [[kind, cell], ...] for the ones that went in.
const FULL_RING := ["cog_press", "cog_press", "mainspring", "movement_works", "regulator", "movement_works", "escapement", "regulator"]


static func fill_ring(g: Game, t: int, tower: Building, kinds: Array = FULL_RING) -> Array:
	var out: Array = []
	var start := _start(tower.cell)
	for k in kinds:
		g.set_gear_pick(t, k, false)
		var done := false
		for i in 24:
			var deg := start + 15.0 * float(i)
			var c := GearNet.ring_spot(g, t, k, tower, deg, true)
			if c.x < 0 or g.placement_problem(t, k, c, true) != "":
				continue
			var near := false
			for o in out:
				if o[1] == c:
					near = true
			if near:
				continue
			g._add_building(k, t, c, true)
			out.append([k, c])
			done = true
			break
		if not done:
			continue
	if g.gear_net:
		g.gear_net.solve()
	return out
