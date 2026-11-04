class_name BroodLayout
extends RefCounted
## THE BROOD COMPUTER'S BASE LAYOUT (the owner, 2026-11-04 19:57: "Brood bad base design: the turtle-locked units are
## stuck inside"; docs/brood_layout.md). A rooted creature takes a building's footprint on the grid (BroodRoot), so the
## computer's Mound Turtles, Rootmaws, Sires and the Mother's nest, with the cliffs and the map's edge, could close a
## pocket its own grubs and warriors could not walk out of. Here:
##  - closes(): before the computer roots a creature (BroodRoot.place_problem with ai = true, for every spot finder),
##    would that footprint cut any ground off from the open map? The ground is looked at in LANES TWO TILES WIDE (a
##    2x2 block of free cells is a "node": a corridor narrower than 2 tiles is no lane), in a window round the spot,
##    before and after; any piece of open ground that loses its way out is a "no" (a nook of up to TINY nodes against a
##    cliff with none of its side in it is let be). exact() does the same on the whole map, for the spot finally picked.
##  - feeds_maws(): the live rooted Rootmaws whose only swamp a source (a Mound Turtle) spreads: the alarm never gets
##    such a turtle up (the owner's Thornwood log 2026-11-04 3:23-3:42: its own Rootmaws went dry and uprooted).
##  - pockets() / blocker() / exit_cell(): a safety net for what still gets shut in (the Mother rooting back on her
##    home, a creature rooted before the rule): its own units in a pocket bordered by its own rooted creatures; the
##    creature that shuts it (not the Mother) uproots and goes elsewhere, else they walk out through their own
##    creatures (BroodRoot's pass).
## Nothing here changes a unit's numbers: only where the computer roots and what it gets up.

const T := Defs.TILE
const MARGIN := 16           # cells round a footprint the quick check looks at
const TINY := 4              # 2x2 nodes: a nook cut off this small, with none of its side in it, is let be
const RING := 2              # a footprint with this many free cells all round can't cut anything off
static var off := false      # (tools/study_brood_layout.gd off:1: the computer as it was before, for the numbers)


# ------------------------------------------------------------------ the whole map, in 2-wide lanes (cached)

static var _g: Game = null
static var _ver := -1
static var _free := PackedByteArray()      # 1: a free cell (free_i)
static var _open := PackedByteArray()       # 1: the 2x2 block of cells with this top-left cell is all free
static var _comp := PackedInt32Array()      # its piece of ground (4-way through open blocks), -1 not open
static var _main := -1                      # the biggest piece: the open map
static var _rver := -1
static var _rg: Game = null
static var _rmain := -1                     # the biggest walkable area of Game's own regions (1-wide)


## Free ground for the lanes: open ground, crop rows, gates (as Game's regions count it).
static func free_i(g: Game, i: int) -> bool:
	var v := int(g.solid[i])
	return v == 0 or v == 3 or v == 5


static func _sync(g: Game) -> void:
	var ver := g.solid_log.size()
	if _g == g and _ver == ver and _comp.size() == Game.W * Game.H:
		return
	_g = g
	_ver = ver
	var W := Game.W
	var H := Game.H
	var n := W * H
	_free.resize(n)
	for i in n:
		var v := int(g.solid[i])
		_free[i] = 1 if v == 0 or v == 3 or v == 5 else 0
	_open.resize(n)
	_open.fill(0)
	for y in H - 1:
		for x in W - 1:
			var i := y * W + x
			if _free[i] == 1 and _free[i + 1] == 1 and _free[i + W] == 1 and _free[i + W + 1] == 1:
				_open[i] = 1
	_comp.resize(n)
	_comp.fill(-1)
	var stack := PackedInt32Array()
	stack.resize(n)
	var best := -1
	var best_n := 0
	var id := 0
	for s in n:
		if _open[s] == 0 or _comp[s] >= 0:
			continue
		var top := 1
		stack[0] = s
		_comp[s] = id
		var cnt := 0
		while top > 0:
			top -= 1
			var c := stack[top]
			cnt += 1
			var x := c % W
			for j in [c - 1 if x > 0 else -1, c + 1 if x < W - 2 else -1, c - W, c + W]:
				if j < 0 or j >= n or _open[j] == 0 or _comp[j] >= 0:
					continue
				_comp[j] = id
				stack[top] = j
				top += 1
		if cnt > best_n:
			best_n = cnt
			best = id
		id += 1
	_main = best


## Game's biggest walkable area (its regions: 1-wide, 4-way): where a unit has a way out to the rest of the map.
static func main_region(g: Game) -> int:
	var ver := g.solid_log.size()
	if _rver == ver and _rg == g and _rmain >= 0 and not g._region_dirty:
		return _rmain
	g.region_of(Vector2i.ZERO)          # (works the regions out if they changed)
	var best := -1
	var bn := -1
	for r in g._region_size.size():
		if int(g._region_size[r]) > bn:
			bn = int(g._region_size[r])
			best = r
	_rmain = best
	_rver = ver
	_rg = g
	return best


# ------------------------------------------------------------------ would this footprint close a pocket?

## The cells planned for side t's other creatures (each one's plan: BroodRoot.plan_of), blocked in both pictures.
static func _plan_cells(g: Game, t: int, me: Unit) -> Dictionary:
	var out := {}
	for o in (BroodRoot._bt_plans if BroodRoot.in_batch(g, t) else g.units):
		if o == me or o.dead or o.team != t:
			continue
		var pl := BroodRoot.plan_of(o)
		if pl.is_empty():
			continue
		var k := String(pl[0])
		var sc: float = BroodRoot.scale_of(o) if o.kind == k else 1.0
		var c := BroodRoot.cell_for(k, pl[1], sc)
		var sz: Vector2i = BroodRoot.fp(k, sc)[0]
		for y in sz.y:
			for x in sz.x:
				var cc := c + Vector2i(x, y)
				if g.in_map(cc):
					out[g.idx(cc)] = true
	# HER NEST GROWS (the Cinder Steps study game, Economy against the Crown, seed 11: at 8:08 her stage 3 nest closed
	# the gap between a Rootmaw, a turtle and the cliff, and 95 units were shut in): the ground her last stage's nest will
	# take round her rooted feet is kept as taken
	var q := BroodNew.queen(g, t)
	if q != null and q != me and BroodNew.rooted(q):
		var st: Array = Defs.NB["stages"]
		var sc := float((st[st.size() - 1] as Dictionary)["scale"])
		var c := BroodRoot.cell_for(q.kind, q.position, sc)
		var sz: Vector2i = BroodRoot.fp(q.kind, sc)[0]
		for y in sz.y:
			for x in sz.x:
				var cc := c + Vector2i(x, y)
				if g.in_map(cc):
					out[g.idx(cc)] = true
	return out


static func _mine(me: Unit) -> Dictionary:
	var out := {}
	if me != null and BroodRoot.has_fp(me):
		for i in me.nb.get("fpc", []):
			out[int(i)] = true
	return out


## Why a `k` of side t rooted with its feet at p would shut ground off from the open map ("" = it would not). The
## quick check (a window round the spot). me: the one rooting (its own cells count as free: it gets up from them).
static func closes(g: Game, t: int, k: String, p: Vector2, me: Unit = null, sc := 1.0) -> String:
	return _check(g, t, k, p, me, sc, false)


## The same on the whole map: for the spot the computer finally picked.
static func exact(g: Game, t: int, k: String, p: Vector2, me: Unit = null, sc := 1.0) -> String:
	return _check(g, t, k, p, me, sc, true)


static func _check(g: Game, t: int, k: String, p: Vector2, me: Unit, sc: float, whole: bool) -> String:
	if off:
		return ""
	_sync(g)
	var W := Game.W
	var H := Game.H
	p = BroodRoot.snap(k, p, sc)
	var c := BroodRoot.cell_for(k, p, sc)
	var sz: Vector2i = BroodRoot.fp(k, sc)[0]
	var foot := Rect2i(c, sz)
	var plan := _plan_cells(g, t, me)
	var mine := _mine(me)
	# the quick yes: free ground two cells wide all round it, so every lane round it stays
	var ring := Rect2i(c - Vector2i(RING, RING), sz + Vector2i(RING, RING) * 2)
	var all_free := true
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			if foot.has_point(Vector2i(x, y)):
				continue
			if x < 0 or y < 0 or x >= W or y >= H:
				all_free = false
				break
			var i := y * W + x
			if not ((free_i(g, i) or mine.has(i)) and not plan.has(i)):
				all_free = false
				break
		if not all_free:
			break
	if all_free:
		return ""
	# the window (block coordinates, inclusive), or the whole map
	var x0 := 0
	var y0 := 0
	var x1 := W - 2
	var y1 := H - 2
	if not whole:
		x0 = maxi(0, c.x - MARGIN)
		y0 = maxi(0, c.y - MARGIN)
		x1 = mini(W - 2, c.x + sz.x - 1 + MARGIN)
		y1 = mini(H - 2, c.y + sz.y - 1 + MARGIN)
	var ww := x1 - x0 + 1
	var wh := y1 - y0 + 1
	var n := ww * wh
	var ob := PackedByteArray()          # open before
	var oa := PackedByteArray()          # open after
	ob.resize(n)
	oa.resize(n)
	var fr := _free.duplicate()          # (free cells: the grid's, its own cells free, the plans' shut)
	for i in mine:
		fr[int(i)] = 1
	for i in plan:
		fr[int(i)] = 0
	for ly in wh:
		var y := y0 + ly
		for lx in ww:
			var x := x0 + lx
			var i := y * W + x
			if fr[i] == 0 or fr[i + 1] == 0 or fr[i + W] == 0 or fr[i + W + 1] == 0:
				continue
			var j := ly * ww + lx
			ob[j] = 1
			# (a block touching the footprint is shut after)
			if not (x + 1 >= foot.position.x and x <= foot.end.x - 1 and y + 1 >= foot.position.y and y <= foot.end.y - 1):
				oa[j] = 1
	# where the ways out are: a window's edge block with an open block of the open map just outside it; on the whole
	# map, the open map's blocks far from the spot (the biggest piece, before)
	var seeds_b := PackedInt32Array()
	var seeds_a := PackedInt32Array()
	if whole:
		var far := Rect2i(c - Vector2i(MARGIN, MARGIN), sz + Vector2i(MARGIN, MARGIN) * 2)
		var got := false
		for ly in wh:
			for lx in ww:
				var j := ly * ww + lx
				if ob[j] == 1 and oa[j] == 1 and _comp[ly * W + lx] == _main and not far.has_point(Vector2i(lx, ly)):
					seeds_b.append(j)
					seeds_a.append(j)
					got = true
					break
			if got:
				break
		if not got:
			return ""          # (no open map away from it to speak of)
	else:
		for ly in wh:
			for lx in ww:
				if lx != 0 and ly != 0 and lx != ww - 1 and ly != wh - 1:
					continue
				var j := ly * ww + lx
				if ob[j] == 0:
					continue
				var x := x0 + lx
				var y := y0 + ly
				var outside := false
				for dv in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var ox: int = x + dv.x
					var oy: int = y + dv.y
					if ox < x0 or oy < y0 or ox > x1 or oy > y1:
						if ox >= 0 and oy >= 0 and ox <= W - 2 and oy <= H - 2 and _comp[oy * W + ox] == _main:
							outside = true
							break
				if outside:
					seeds_b.append(j)
					if oa[j] == 1:
						seeds_a.append(j)
	var rb := _flood(ob, ww, wh, seeds_b)
	var ra := _flood(oa, ww, wh, seeds_a)
	# the ground that had a way out and lost it (still open: not under the footprint)
	var lost := PackedByteArray()
	lost.resize(n)
	var any := false
	for j in n:
		if rb[j] == 1 and oa[j] == 1 and ra[j] == 0:
			lost[j] = 1
			any = true
	if not any:
		return ""
	# its own units in it (a grub, a warrior: the creature rooting itself is a footprint after)
	var who := {}
	for u in g.units_near(Vector2(foot.get_center()) * T, (MARGIN + maxi(sz.x, sz.y)) * T * 1.5) if not whole else g.units:
		if u == me or u.dead or u.team != t or u.is_air() or u._k_still or BroodRoot.has_fp(u) or u.off_field:
			continue
		var uc := g.cell_of(u.position)
		for d in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
			var bc: Vector2i = uc + d - Vector2i(x0, y0)
			if bc.x < 0 or bc.y < 0 or bc.x >= ww or bc.y >= wh:
				continue
			var j := bc.y * ww + bc.x
			if lost[j] == 1:
				who[j] = int(who.get(j, 0)) + 1
				break
	# each cut-off piece: too big, or with its own side in it
	var seen := PackedByteArray()
	seen.resize(n)
	var stack := PackedInt32Array()
	for s in n:
		if lost[s] == 0 or seen[s] == 1:
			continue
		seen[s] = 1
		stack.clear()
		stack.append(s)
		var cnt := 0
		var units := 0
		while not stack.is_empty():
			var j: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			cnt += 1
			units += int(who.get(j, 0))
			var lx := j % ww
			for jj in [j - 1 if lx > 0 else -1, j + 1 if lx < ww - 1 else -1, j - ww, j + ww]:
				if jj < 0 or jj >= n or lost[jj] == 0 or seen[jj] == 1:
					continue
				seen[jj] = 1
				stack.append(jj)
		if units > 0:
			return "It would shut %d of its own in." % units
		if cnt > TINY:
			return "It would close a pocket (keep a way out two tiles wide)."
	return ""


static func _flood(open: PackedByteArray, ww: int, wh: int, seeds: PackedInt32Array) -> PackedByteArray:
	var n := ww * wh
	var r := PackedByteArray()
	r.resize(n)
	var stack := PackedInt32Array()
	stack.resize(n)
	var top := 0
	for s in seeds:
		if open[s] == 1 and r[s] == 0:
			r[s] = 1
			stack[top] = s
			top += 1
	while top > 0:
		top -= 1
		var j := stack[top]
		var lx := j % ww
		if lx > 0 and open[j - 1] == 1 and r[j - 1] == 0:
			r[j - 1] = 1
			stack[top] = j - 1
			top += 1
		if lx < ww - 1 and open[j + 1] == 1 and r[j + 1] == 0:
			r[j + 1] = 1
			stack[top] = j + 1
			top += 1
		if j - ww >= 0 and open[j - ww] == 1 and r[j - ww] == 0:
			r[j - ww] = 1
			stack[top] = j - ww
			top += 1
		if j + ww < n and open[j + ww] == 1 and r[j + ww] == 0:
			r[j + ww] = 1
			stack[top] = j + ww
			top += 1
	return r


# ------------------------------------------------------------------ the swamp a source holds

## The rooted Rootmaws of src's side that stand on src's swamp and on no other source's: they go dry (and uproot) if
## src gets up. Swamp as Game._update_swamp lays it (an oval, 1.15 tall), at the radius each source has reached.
static func feeds_maws(g: Game, src: Unit) -> Array:
	var out: Array = []
	if src == null or src.dead or not BroodNew.rooted(src):
		return out
	var srcs := BroodNew.swamp_sources(g, src.team)
	var mine := [src.position / T, minf(BroodNew.swamp_full(src), float(src.nb.get("swr", 0.0)))]
	for m in g.units:
		if m.dead or m.team != src.team or m.kind != BroodNew.MAW or m.tesla_mode == "packed":
			continue
		var mc := Vector2(g.cell_of(m.position)) + Vector2(0.5, 0.5)
		if not _in_swamp(mc, mine):
			continue
		var other := false
		for s in srcs:
			if ((s[0] as Vector2) - (mine[0] as Vector2)).length() < 0.01:
				continue          # (src itself)
			if _in_swamp(mc, s):
				other = true
				break
		if not other:
			out.append(m)
	return out


static func _in_swamp(cell_mid: Vector2, src: Array) -> bool:
	var dx: float = cell_mid.x - (src[0] as Vector2).x
	var dy: float = (cell_mid.y - (src[0] as Vector2).y) * 1.15
	var r: float = src[1]
	return dx * dx + dy * dy <= r * r


# ------------------------------------------------------------------ the safety net: its own shut in

## Is this a unit of side t that can be shut in (on foot, not rooted, not an egg or a pile)?
static func walker(u: Unit, t: int) -> bool:
	return not u.dead and u.team == t and not u.is_air() and not u._k_still and not u.off_field \
			and not BroodRoot.has_fp(u) and not BroodRoot.in_cocoon(u) and u.nb_pass <= 0.0


## Region id -> its units: side t's walkers in a walkable area other than the open map that borders one of side t's
## rooted creatures (shut in by its own: pockets the enemy's walls make are not counted).
static func pockets(g: Game, t: int) -> Dictionary:
	var main := main_region(g)
	var out := {}
	var by_region := {}
	for u in g.units:
		if not walker(u, t):
			continue
		var r := g.region_of(g.cell_of(u.position))
		if r < 0 or r == main:
			continue
		if not by_region.has(r):
			by_region[r] = []
		by_region[r].append(u)
	if by_region.is_empty():
		return out
	var touch := _touching(g, t)
	for r in by_region:
		if touch.has(r):
			out[r] = by_region[r]
	return out


## Is cell c in a walkable area shut in by side t's own rooted creatures (not the open map)?
static func own_pocket(g: Game, c: Vector2i, t: int) -> bool:
	if off:
		return false
	var r := g.region_of(c)
	if r < 0 or r == main_region(g):
		return false
	return _touching(g, t).has(r)


## Out on the open map for a unit of side t walking out through its own creatures (BroodRoot.pass_move, exit_point).
static func out_ok(g: Game, c: Vector2i, t: int) -> bool:
	return g.in_open_map(c) and not own_pocket(g, c, t)


static var _tg: Game = null
static var _tver := -1
static var _tt := -1
static var _tfp := -1
static var _tcache := {}


## Region id -> the rooted creatures of side t whose footprints border it.
static func _touching(g: Game, t: int) -> Dictionary:
	g.region_of(Vector2i.ZERO)
	if _tg == g and _tver == g.solid_log.size() and _tt == t and _tfp == g.nb_fp.size():
		return _tcache
	_tg = g
	_tver = g.solid_log.size()
	_tt = t
	_tfp = g.nb_fp.size()
	var out := {}
	_tcache = out
	for f in g.nb_fp:
		if not is_instance_valid(f) or f.dead or f.team != t or not BroodRoot.has_fp(f):
			continue
		var r := BroodRoot.rect_of(f)
		var c0 := Vector2i(int(r.position.x / T), int(r.position.y / T))
		var sz := Vector2i(int(round(r.size.x / T)), int(round(r.size.y / T)))
		for y in range(c0.y - 1, c0.y + sz.y + 1):
			for x in range(c0.x - 1, c0.x + sz.x + 1):
				var inside := x >= c0.x and x < c0.x + sz.x and y >= c0.y and y < c0.y + sz.y
				if inside or not g.in_map(Vector2i(x, y)):
					continue
				var rg := g.region_of(Vector2i(x, y))
				if rg < 0:
					continue
				if not out.has(rg):
					out[rg] = []
				if not (out[rg] as Array).has(f):
					out[rg].append(f)
	return out


## The creature to get up so pocket r opens onto the open map: one of side t's rooted creatures bordering both (not the
## Mother; not one in its cocoon or busy with research; a Rootmaw first, then a Sire, then a Mound Turtle that feeds no
## Rootmaw, then any turtle). null if none: they walk out through their own creatures instead.
static func blocker(g: Game, t: int, r: int) -> Unit:
	var main := main_region(g)
	var touch := _touching(g, t)
	if not touch.has(r) or not touch.has(main):
		return null
	var best: Unit = null
	var bs := 99
	for f in touch[r]:
		if not (touch[main] as Array).has(f):
			continue
		var u := f as Unit
		if u.kind == BroodNew.QUEEN or BroodRoot.in_cocoon(u) or BroodResearch.busy(u) or u.tesla_mode != "deployed":
			continue
		var s := 9
		if u.kind == BroodNew.MAW:
			s = 0
		elif BroodNew.is_father(u.kind):
			s = 1
		elif u.kind == BroodNew.TURTLE:
			s = 2 if feeds_maws(g, u).is_empty() else 3
		if s < bs:
			bs = s
			best = u
	return best


## The nearest cell of the open map (Game's biggest walkable area) reached from p through free ground and side t's own
## rooted creatures. Vector2.INF if none near.
static func exit_cell(g: Game, p: Vector2, t: int) -> Vector2:
	var main := main_region(g)
	var start := g.cell_of(p)
	if not g.in_map(start):
		return Vector2.INF
	g.region_of(start)          # (the regions worked out first: region_of below reads them as they are)
	var W := Game.W
	var seen := PackedByteArray()
	seen.resize(W * Game.H)
	var q := PackedInt32Array([g.idx(start)])
	seen[q[0]] = 1
	var head := 0
	while head < q.size() and head < 6000:
		var i := q[head]
		head += 1
		var v := int(g.solid[i])
		var free := (v == 0 or v == 5) and g.cliff[i] == 0
		if head > 1 and free and g._region[i] == main:
			return g.cell_center(Vector2i(i % W, i / W))
		var x := i % W
		for ni in [i - 1 if x > 0 else -1, i + 1 if x < W - 1 else -1, i - W, i + W]:
			if ni < 0 or ni >= seen.size() or seen[ni] == 1:
				continue
			seen[ni] = 1
			var nv := int(g.solid[ni])
			if ((nv == 0 or nv == 5) and g.cliff[ni] == 0) or BroodRoot.own_cell(g, ni, t):
				q.append(ni)
	return Vector2.INF


## How many of side t's units stand shut in by its own rooted creatures (the study's "stuck unit seconds", sampled
## once a second).
static func stuck_count(g: Game, t: int) -> int:
	var n := 0
	var p := pockets(g, t)
	for r in p:
		n += (p[r] as Array).size()
	return n
