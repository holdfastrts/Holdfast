extends RefCounted
## THE CROWN COMPUTER'S BASE LAYOUT (crown-owner-eco, docs/crown_owner_eco.md). The owner (2026-11-04 19:57, pictures
## eco_v_eco_1 / eco_v_eco_2 in docs/playtests/2026-11-04/): the computer's base is "a mess"; his is "much more organized;
## pay attention to the minimap so you can see my base logic and structure": Cottages packed in tight rows against the
## map's edge at the main's back, production (Barracks, Foundry, Church...) in neat rows in the middle with walk lanes,
## the farms and the Mill by their hall, nothing scattered.
##
## Every hall of the Crown computer (owner plans, Normal and up) gets a PLAN the moment it stands:
##  1. ITS GROUND: the cells joined to the hall on its own level (off the ramps), within MAIN_R tiles (the main) or NAT_R
##     (another hall; inside its wall ring when AIExpandWall planned one).
##  2. THE ECONOMY FIRST: spots for the hall's Farms and its Mill (as many as the hall still lacks), nearest the hall;
##     every other building keeps a tile off them.
##  3. A LATTICE of BLOCK (5 x 4 tiles) anchored on the hall's own corner (the hall is one block): a block holds one
##     production building (4 x 3: Barracks, Foundry, Horse Breeder, Armoury; a Church 3 x 3) with a lane of one tile on its
##     right and below, or four Cottages packed in a 4 x 4 square with the lane on its right. Blocks off the ground, on a
##     ramp's mouth, touching the hall, over an economy spot or across the walk from the hall to the ramp's top are dropped.
##  4. THE COTTAGE BLOCK: on the main, the COT_BLOCKS blocks that sit farthest at the back (away from the map's middle and
##     from the ramp) and have the fewest neighbours (the plateau's edge) hold Cottages, filled from the outermost cell in;
##     the rest hold production, nearest the hall first.
##  5. Nothing is placed where it would cut a part of the ground off (Game._plateau_reach, as find_spot's tight test).
## Buildings the walls ask for (the ramp Cottage, a new hall's wall slots) keep their own spots; when the layout has no
## room left the shared search places the building (AI._find_spot).

var ai = null
var bases: Dictionary = {}      # hall id -> {"hall", "h0", "cot": [cells], "prod": [cells], "farm": [cells], "mill": [cells], "blocks": [[cell, kind]]}
var plans_made := 0
const BLOCK := Vector2i(5, 4)
const MAIN_R := 24
const NAT_R := 14
const COT_BLOCKS := 6
const COT_SHARE := 0.45         # of a main's blocks at most
const PROD_KINDS := ["barracks", "foundry", "horse_breeder", "armoury", "church"]
const RAMP_PATH := 2.0          # (tiles) the walk from the hall to the ramp's top kept this wide each side


func _init(a) -> void:
	ai = a


var game:
	get:
		return ai.game


func tick() -> void:
	for id in bases.keys():
		var h = bases[id]["hall"]
		if h == null or not is_instance_valid(h) or (h as Building).dead:
			bases.erase(id)
	for h in ai._halls():
		if h.built and not bases.has(h.get_instance_id()):
			bases[h.get_instance_id()] = _plan(h)
			plans_made += 1


func _main() -> Building:
	return ai.main_hall()


## The bases, the main first, then by distance from it.
func _order() -> Array:
	var out: Array = bases.values()
	var m: Building = _main()
	var mc: Vector2 = m.center() if m != null else Vector2.ZERO
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["hall"] as Building).center().distance_to(mc) < (b["hall"] as Building).center().distance_to(mc))
	return out


# ------------------------------------------------------------------ the plan

func _plan(h: Building) -> Dictionary:
	var T := float(Defs.TILE)
	var is_main: bool = h == _main()
	var hc: Vector2i = h.cell
	var hsz: Vector2i = h.size
	var mid_cell: Vector2i = hc + hsz / 2
	var h0 := int(game.height[game.idx(mid_cell)])
	var r := MAIN_R if is_main else NAT_R
	var area := _ground(h, h0, r)
	var p := {"hall": h, "h0": h0, "main": is_main, "cot": [], "prod": [], "farm": [], "mill": [], "blocks": []}
	# 2. the economy: the hall's Farms and Mill still to come
	var hr := Rect2i(hc, hsz)
	var kept: Array = [hr.grow(1)]
	var per_farm: int = Defs.econ_per_hall("crown", "farm")
	var per_mill: int = Defs.econ_per_hall("crown", "powder_mill")
	var farms := 0
	var mills := 0
	for b in game.buildings:
		if b.team != ai.team or b.dead or not (b.kind == "farm" or b.kind == "powder_mill"):
			continue
		if game.nearest_hall(b.center(), ai.team) != h:
			continue
		kept.append(Rect2i(b.cell, b.size).grow(1))
		if b.kind == "farm":
			farms += 1
		else:
			mills += 1
	for i in maxi(0, per_farm - farms):
		var c := _econ_cell("farm", h, area, kept)
		if c.x >= 0:
			p["farm"].append(c)
			kept.append(Rect2i(c, Defs.BUILDINGS["farm"]["size"]).grow(1))
	for i in maxi(0, per_mill - mills):
		var c := _econ_cell("powder_mill", h, area, kept)
		if c.x >= 0:
			p["mill"].append(c)
			kept.append(Rect2i(c, Defs.BUILDINGS["powder_mill"]["size"]).grow(1))
	# the walk to the ramp's top (the main) kept open
	var path_a := h.center() / T
	var path_b := Vector2.INF
	if is_main:
		var ro: Dictionary = CrownSites.ramp_of(game, ai.team)
		if not ro.is_empty():
			path_b = ro["top"]
	# 3. the lattice: of the BLOCK.x * BLOCK.y ways to lay it, the one with the most whole blocks
	var map_mid := Vector2(Game.W, Game.H) * 0.5
	var back := (h.center() / T - map_mid)
	back = back.normalized() if back.length() > 0.1 else Vector2.DOWN
	var ramp_top := path_b
	var blocks: Array = []          # [key, cell]
	var valid := {}
	# (start-spots-fix: the lattice is laid in this side's first-start frame and mirrored back (Game.start_flip), so two
	# mirrored mains get mirrored blocks)
	var hc0: Vector2i = game.sym_rect(ai.team, hc, hsz)
	for oy in BLOCK.y:
		for ox in BLOCK.x:
			var bl: Array = []
			var vd := {}
			_lattice(hc0 + Vector2i(ox, oy), h, r, area, kept, path_a, path_b, bl, vd)
			if bl.size() > blocks.size():
				blocks = bl
				valid = vd
	# 4. the Cottage block (the main): at the back, at the edge, far from the ramp
	var scored: Array = []
	for e in blocks:
		var key: Vector2i = e[0]
		var o: Vector2i = e[1]
		var bc := Vector2(o) + Vector2(2, 2)
		var edge := 0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not valid.has(key + d):
				edge += 1
		var bk := (bc - h.center() / T).dot(back)
		var rd := bc.distance_to(ramp_top) if ramp_top != Vector2.INF else 0.0
		scored.append([bk / 5.0 + float(edge) * 1.2 + rd / 8.0, o, bc.distance_to(h.center() / T)])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var n_cot := mini(COT_BLOCKS, int(float(blocks.size()) * COT_SHARE)) if is_main else 0
	var cot_blocks: Array = []
	for i in mini(n_cot, scored.size()):
		cot_blocks.append(scored[i][1])
	for o in cot_blocks:
		# four Cottages, the cells farthest back first
		var cells: Array = [o, o + Vector2i(2, 0), o + Vector2i(0, 2), o + Vector2i(2, 2)]
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (Vector2(a) - h.center() / T).dot(back) > (Vector2(b) - h.center() / T).dot(back))
		for c in cells:
			p["cot"].append(c)
		p["blocks"].append([o, "cottage"])
	var prod: Array = []
	for e in scored:
		if cot_blocks.has(e[1]):
			continue
		prod.append(e)
	prod.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) < float(b[2]))
	for e in prod:
		# (a production building takes the block's front three rows as the first start reads it: the mirror of them on a
		# mirrored side)
		var pc: Vector2i = game.sym_rect(ai.team, game.sym_rect(ai.team, e[1], Vector2i(4, 4)), Vector2i(4, 3))
		p["prod"].append(pc)
		p["blocks"].append([pc, "prod"])
	if game.mlog:
		game.mlog.add("%s's base layout at its %s: %d Cottage spots in %d blocks at the back, %d production rows' spots, %d Farm and %d Mill spots by the hall" % [
			game.mlog.who(ai.team), "main" if is_main else "new hall", (p["cot"] as Array).size(), cot_blocks.size(), (p["prod"] as Array).size(),
			(p["farm"] as Array).size(), (p["mill"] as Array).size()])
	return p


## The whole blocks of the lattice anchored at `anchor` (a cell in this side's first-start frame: Game.sym_rect):
## [key, cell] into `out`, key -> cell into `valid`.
func _lattice(anchor: Vector2i, h: Building, r: int, area: Dictionary, kept: Array, path_a: Vector2, path_b: Vector2, out: Array, valid: Dictionary) -> void:
	var T := float(Defs.TILE)
	var n := r / BLOCK.y + 3
	for by in range(-n, n + 1):
		for bx in range(-n, n + 1):
			var o: Vector2i = game.sym_rect(ai.team, anchor + Vector2i(bx * BLOCK.x, by * BLOCK.y), Vector2i(4, 4))
			var foot := Rect2i(o, Vector2i(4, 4))      # (a Cottage block's 4 x 4; a production building uses the top 4 x 3)
			if (Vector2(o) + Vector2(2, 2)).distance_to(h.center() / T) > float(r):
				continue
			if not _in_area(foot, area):
				continue
			var bad := false
			for k in kept:
				if (k as Rect2i).intersects(foot):
					bad = true
					break
			if bad:
				continue
			if path_b != Vector2.INF and _rect_seg(foot, path_a, path_b) < RAMP_PATH:
				continue
			if _near_ramp(foot):
				continue
			valid[Vector2i(bx, by)] = o
			out.append([Vector2i(bx, by), o])


## The least distance (tiles) from a rect's cells to a segment.
static func _rect_seg(rr: Rect2i, a: Vector2, b: Vector2) -> float:
	var best := INF
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			best = minf(best, _seg_dist(Vector2(x, y) + Vector2(0.5, 0.5), a, b))
	return best


## The hall's ground: cells on its level (no ramp, no terrain) joined to it within r tiles; inside its wall ring if any.
func _ground(h: Building, h0: int, r: int) -> Dictionary:
	var inside: Dictionary = {}
	var wp: Dictionary = ai.xw.plan_of(h)
	if not wp.is_empty():
		inside = wp["inside"]
	var out := {}
	var hr := Rect2i(h.cell, h.size)
	var start := Vector2i(-1, -1)
	for y in range(hr.position.y - 1, hr.end.y + 1):
		for x in range(hr.position.x - 1, hr.end.x + 1):
			var c := Vector2i(x, y)
			if hr.has_point(c) or not game.in_map(c):
				continue
			if _cell_ok(c, h0) and start.x < 0:
				start = c
	if start.x < 0:
		return out
	var hcen := h.center() / float(Defs.TILE)
	var q: Array = [start]
	out[start] = true
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var m: Vector2i = c + d
			if out.has(m) or not game.in_map(m) or hr.has_point(m):
				continue
			if not _cell_ok(m, h0):
				continue
			if (Vector2(m) + Vector2(0.5, 0.5)).distance_to(hcen) > float(r) + 3.0:
				continue
			if not inside.is_empty() and not inside.has(m):
				continue
			out[m] = true
			q.append(m)
	return out


func _cell_ok(c: Vector2i, h0: int) -> bool:
	var i: int = game.idx(c)
	return int(game.height[i]) == h0 and game.ramp[i] == 0 and int(game.solid[i]) != 1 and (game.water.size() <= i or game.water[i] == 0)


func _in_area(r: Rect2i, area: Dictionary) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not area.has(Vector2i(x, y)):
				return false
	return true


func _near_ramp(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if game._near_ramp(Vector2i(x, y)):
				return true
	return false


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## A Farm's or the Mill's spot on the hall's ground, nearest the hall, a tile off what is kept.
func _econ_cell(kind: String, h: Building, area: Dictionary, kept: Array) -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var hcen := h.center() / float(Defs.TILE)
	var mid := Vector2(Game.W, Game.H) * 0.5
	var best := Vector2i(-1, -1)
	var bs := INF
	var rng := Defs.ECON_RANGE - 2
	var k0: Vector2 = game.sym_pt(ai.team, h.center()) / float(Defs.TILE)       # (looked at in this side's first-start frame: start-spots-fix)
	for y in range(int(k0.y) - rng - 6, int(k0.y) + rng + 1):
		for x in range(int(k0.x) - rng - 6, int(k0.x) + rng + 1):
			var c: Vector2i = game.sym_rect(ai.team, Vector2i(x, y), size)
			var cc := Vector2(c) + Vector2(size) * 0.5
			var dd := cc.distance_to(hcen)
			if dd > float(rng) or dd < 4.0:
				continue
			var fr := Rect2i(c, size)
			if not _in_area(fr, area) or _near_ramp(fr):
				continue
			var bad := false
			for k in kept:
				if (k as Rect2i).intersects(fr):
					bad = true
					break
			if bad:
				continue
			var sc := dd - (cc.distance_to(mid) - hcen.distance_to(mid)) * 0.4
			if sc < bs:
				bs = sc
				best = c
	return best


# ------------------------------------------------------------------ what the computer asks

## The layout's next spot for a building of this kind, or (-1, -1). peek: for a spot kept ahead (AICrown._keep_tech).
func slot(kind: String, peek := false) -> Vector2i:
	if bases.is_empty():
		return Vector2i(-1, -1)
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var key := ""
	if kind == "cottage":
		key = "cot"
	elif PROD_KINDS.has(kind):
		key = "prod"
	else:
		return Vector2i(-1, -1)
	for p in _order():
		var reach0 := -1
		var start := Vector2i(-1, -1)
		for c in p[key]:
			if game.placement_problem(ai.team, kind, c, true) != "":
				continue
			if not _clear(c, size):
				continue
			if reach0 < 0:
				start = _start(p)
				if start.x < 0:
					break
				reach0 = game._plateau_reach(start, int(p["h0"]), Vector2i(-1, -1), Vector2i.ZERO)
			if game._plateau_reach(start, int(p["h0"]), c, size) < reach0 - size.x * size.y - 2:
				continue            # (it would cut a part of the ground off)
			return c
	return Vector2i(-1, -1)


## A Farm's or the Mill's spot kept by this hall's plan, if it is still free.
func econ_spot(kind: String, h: Building) -> Vector2i:
	var p: Dictionary = bases.get(h.get_instance_id(), {})
	if p.is_empty():
		return Vector2i(-1, -1)
	var key := "farm" if kind == "farm" else ("mill" if kind == "powder_mill" else "")
	if key == "":
		return Vector2i(-1, -1)
	for c in p[key]:
		if game.placement_problem(ai.team, kind, c, true) == "":
			return c
	return Vector2i(-1, -1)


## The footprint is free of units' buildings and terrain (placement_problem's test), and its lane side is open.
func _clear(c: Vector2i, size: Vector2i) -> bool:
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			if not game.in_map(cc) or int(game.solid[game.idx(cc)]) != 0:
				return false
	return true


func _start(p: Dictionary) -> Vector2i:
	var h: Building = p["hall"]
	return game._free_next_to(game.cell_of(h.center()), int(p["h0"]))


## The planned blocks as rectangles (the coach's pictures).
func rects() -> Array:
	var out: Array = []
	for p in bases.values():
		for e in p["blocks"]:
			out.append([Rect2i(e[0], Vector2i(4, 4) if e[1] == "cottage" else Vector2i(4, 3)), e[1]])
		for c in p["farm"]:
			out.append([Rect2i(c, Defs.BUILDINGS["farm"]["size"]), "farm"])
		for c in p["mill"]:
			out.append([Rect2i(c, Defs.BUILDINGS["powder_mill"]["size"]), "mill"])
	return out
