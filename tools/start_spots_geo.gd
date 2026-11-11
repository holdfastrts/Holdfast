extends SceneTree
## START SPOTS GEOMETRY (start-spots study, docs/start_spots_study.md): a MEASURING tool, it changes no rule.
## Starts a normal 2-player match (computers, like tools/qa_match.gd), reads the map at the first frame and writes one
## JSON line per side with the start spot's geometry, plus a whole-map mirror check (every terrain layer at a cell
## against the point-mirrored cell) and the starting buildings against their mirror.
##   godot --headless --script res://tools/start_spots_geo.gd -- map:red_coast seed:1100 fac:crown out:/abs/file.json [swap:1]
## swap:1 gives player index 0 the side number 1 (on named maps that hands it the second spot: MapGen.spot_order).
var main: Node
var g: Game
var map := "greenhold"
var seed_ := 1
var fac := "crown"
var out := "/tmp/geo.json"
var swap := false
var t := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"fac": fac = kv[1]
			"out": out = kv[1]
			"swap": swap = kv[1] == "1"
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var sl: Array = []
		for i in 2:
			var side := (1 - i) if swap else i
			sl.append({"who": "hard", "faction": fac, "colour": i, "side": side, "strategy": "optimal"})
		main.start({"map": map, "seed": seed_, "slots": sl})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.starts.size() < 2 or g.buildings.is_empty() and fac != "brood":
		return false
	_measure()
	return true


func _mid(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(MapGen.HALL) * 0.5


func _mirror_cell(c: Vector2i) -> Vector2i:
	return Vector2i(Game.W - 1 - c.x, Game.H - 1 - c.y)


func _nearer(c: Vector2i) -> int:
	var d0 := (Vector2(c) + Vector2(0.5, 0.5)).distance_to(_mid(g.starts[0]))
	var d1 := (Vector2(c) + Vector2(0.5, 0.5)).distance_to(_mid(g.starts[1]))
	return 0 if d0 < d1 else 1


## Every terrain layer against the point mirror: how many cells differ, and near whose start (a cell nearer P0's start
## that differs from its twin).
func _mirror_check() -> Dictionary:
	var res := {}
	var layers := {"height": g.height, "cliff": g.cliff, "ramp": g.ramp, "water": g.water}
	var near_cnt := {}
	var examples: Array = []
	for name in layers.keys() + ["terrain", "kind"]:
		var n := 0
		for y in Game.H:
			for x in Game.W:
				var c := Vector2i(x, y)
				var m := _mirror_cell(c)
				if g.idx(c) >= g.idx(m):
					continue
				var a
				var b
				if name == "terrain":
					a = int(g.solid[g.idx(c)] == 1)
					b = int(g.solid[g.idx(m)] == 1)
				elif name == "kind":
					a = String(g._terrain_kind.get(g.idx(c), ""))
					b = String(g._terrain_kind.get(g.idx(m), ""))
				else:
					a = int(layers[name][g.idx(c)])
					b = int(layers[name][g.idx(m)])
				if a != b:
					n += 1
					var who := _nearer(c)
					var key := "%s_near_p%d" % [name, who]
					near_cnt[key] = int(near_cnt.get(key, 0)) + 1
					if examples.size() < 12:
						examples.append([name, [c.x, c.y], str(a), str(b)])
		res[name] = n
	res["near"] = near_cnt
	res["examples"] = examples
	res["starts_mirrored"] = g.starts[1] == g._mirror(g.starts[0], MapGen.HALL)
	res["nats_mirrored"] = g.expansions.size() >= 2 and g.expansions[1] == g._mirror(g.expansions[0], MapGen.HALL)
	var sites_ok := true
	for c in g.base_sites:
		if not g.base_sites.has(g._mirror(c, MapGen.HALL)):
			sites_ok = false
	res["sites_mirrored"] = sites_ok
	return res


## The starting buildings of each side against the other side's mirrored: [kind, P0 cell, P1 cell mirrored back, off].
func _layout_check() -> Array:
	var o: Array = []
	for b in g.buildings:
		if b.team != 0:
			continue
		var best: Building = null
		var bd := INF
		for b2 in g.buildings:
			if b2.team != 1 or b2.kind != b.kind:
				continue
			var back := g._mirror(Vector2i(b2.cell), b2.size)
			var d := Vector2(back).distance_to(Vector2(b.cell))
			if d < bd:
				bd = d
				best = b2
		o.append([b.kind, [b.cell.x, b.cell.y], snappedf(bd, 0.01)])
	return o


## The main's plateau: the hall's level, joined to it without a ramp.
func _plateau(t: int) -> Dictionary:
	var c0: Vector2i = g.starts[t] + Vector2i(2, 2)
	var h0 := int(g.height[g.idx(c0)])
	var seen := {c0: true}
	var q: Array = [c0]
	var head := 0
	var ramps := {}
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + dd
			if seen.has(n) or not g.in_map(n):
				continue
			var i := g.idx(n)
			if g.ramp[i] == 1:
				ramps[n] = true
				continue
			if int(g.height[i]) != h0 or g.cliff[i] != 0 or g.water[i] != 0:
				continue
			seen[n] = true
			q.append(n)
	var open := 0
	for c in seen:
		if g.solid[g.idx(c)] != 1:
			open += 1
	# the ramps touching it: group the ramp cells (8 ways), and grow each group over all its ramp cells
	var groups: Array = []
	var done := {}
	for r in ramps:
		if done.has(r):
			continue
		var cells: Array = []
		var st: Array = [r]
		done[r] = true
		while not st.is_empty():
			var p: Vector2i = st.pop_back()
			cells.append(p)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := p + Vector2i(dx, dy)
					if g.in_map(n) and g.ramp[g.idx(n)] == 1 and not done.has(n):
						done[n] = true
						st.append(n)
		var mn := Vector2i(9999, 9999)
		var mx := Vector2i(-1, -1)
		var sum := Vector2.ZERO
		var top := 0
		for p in cells:
			mn = Vector2i(mini(mn.x, p.x), mini(mn.y, p.y))
			mx = Vector2i(maxi(mx.x, p.x), maxi(mx.y, p.y))
			sum += Vector2(p)
			if ramps.has(p):
				top += 1
		var ctr := sum / cells.size() + Vector2(0.5, 0.5)
		var dir := (ctr - _mid(g.starts[t]))
		groups.append({"cells": cells.size(), "top_edge": top, "box": [mx.x - mn.x + 1, mx.y - mn.y + 1],
			"width": mini(mx.x - mn.x + 1, mx.y - mn.y + 1), "dir": [snappedf(dir.x, 0.1), snappedf(dir.y, 0.1)],
			"dist": snappedf(dir.length(), 0.1)})
	return {"level": h0, "cells": seen.size(), "open": open, "ramps": groups, "set": seen}


## The chokes on the way in: walking the shortest land route from each main, at every step the WIDTH of the band of
## cells that are that many steps from the main and on a route at most 8 steps longer than the shortest (a choke is
## where that band is thin). Per side: the three narrowest [width, steps from its own main] in its own half.
func _chokes(d0: PackedFloat32Array, d1: PackedFloat32Array) -> Array:
	var best := INF
	for i in d0.size():
		if d0[i] < INF and d1[i] < INF:
			best = minf(best, d0[i] + d1[i])
	var cnt: Array = [{}, {}]
	for i in d0.size():
		if d0[i] < INF and d1[i] < INF and d0[i] + d1[i] <= best + 8.0:
			for h in 2:
				var k := int(d0[i]) if h == 0 else int(d1[i])
				if float(k) < best * 0.5 and k >= 8:
					cnt[h][k] = int(cnt[h].get(k, 0)) + 1
	var o: Array = []
	for h in 2:
		var l: Array = []
		for k in cnt[h]:
			l.append([cnt[h][k], k])
		l.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		o.append(l.slice(0, 3))
	return [best, o]


func _open_c(c: Vector2i) -> bool:
	return g.in_map(c) and g.solid[g.idx(c)] != 1 and g.cliff[g.idx(c)] == 0


## The narrowest of the four directions' open runs through a cell (horizontal, vertical, two diagonals).
func _width_at(c: Vector2i) -> int:
	var best := 999
	for dv in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var n := 1
		for sgn in [1, -1]:
			var p: Vector2i = c
			for k in 40:
				p += dv * sgn
				if not _open_c(p):
					break
				n += 1
		best = mini(best, n)
	return best


func _measure() -> void:
	var dist: Array = [ExpansionSpots._steps(g, g.starts[0]), ExpansionSpots._steps(g, g.starts[1])]
	var lines: Array = []
	var rated := ExpansionSpots.rate_all(g, dist)
	var ch := _chokes(dist[0], dist[1])
	var plats: Array = [_plateau(0), _plateau(1)]
	for t in 2:
		var o := 1 - t
		var me: Vector2i = g.starts[t]
		var sites: Array = []
		for c in g.base_sites:
			if c == g.starts[0] or c == g.starts[1]:
				continue
			var hd := ExpansionSpots._foot_d(g, dist[t], c)
			var fd := ExpansionSpots._foot_d(g, dist[o], c)
			if hd >= fd:
				continue        # the other side's site
			var sc := -1.0
			for r in rated:
				if r["c"] == c:
					sc = snappedf(float(r["score"]), 0.1)
			# high-ground cover: cells of the main's plateau within 6 / 10 tiles of the site's middle
			var cov6 := 0
			var cov10 := 0
			var pl: Dictionary = plats[t]["set"]
			for p in pl:
				var dd := (Vector2(p) + Vector2(0.5, 0.5)).distance_to(_mid(c))
				if dd <= 10.0:
					cov10 += 1
					if dd <= 6.0:
						cov6 += 1
			sites.append({"c": [c.x, c.y], "home": hd, "foe": fd, "safe": fd - hd, "room": snappedf(ExpansionSpots._room(g, c), 0.01),
				"ways": ExpansionSpots._ways(g, c), "score": sc, "cover6": cov6, "cover10": cov10,
				"natural": g.expansions.size() > t and g.expansions[t] == c})
		sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["home"]) < float(b["home"]))
		var trees := 0
		var rocks := 0
		for y in range(me.y - 15, me.y + 20):
			for x in range(me.x - 15, me.x + 20):
				var c := Vector2i(x, y)
				if g.in_map(c) and (Vector2(c) + Vector2(0.5, 0.5)).distance_to(_mid(me)) <= 15.0:
					var k := String(g._terrain_kind.get(g.idx(c), ""))
					if k == "tree":
						trees += 1
					elif k == "rock":
						rocks += 1
		var pl2: Dictionary = plats[t]
		var ramps: Array = pl2["ramps"]
		var bld: Array = []
		for b in g.buildings:
			if b.team == t:
				bld.append([b.kind, [b.cell.x, b.cell.y], snappedf((b.rect().get_center() / Game.T).distance_to(_mid(me)), 0.01)])
		lines.append({"p": t, "start": [me.x, me.y], "mid": [snappedf(_mid(me).x, 0.1), snappedf(_mid(me).y, 0.1)],
			"main_walk": ExpansionSpots._foot_d(g, dist[t], g.starts[o]),
			"fly": snappedf(_mid(me).distance_to(_mid(g.starts[o])), 0.1),
			"room_main": snappedf(ExpansionSpots._room(g, me), 0.01), "plateau": pl2["cells"], "plateau_open": pl2["open"],
			"ramps": ramps, "sites": sites, "trees15": trees, "rocks15": rocks, "chokes": ch[1][t], "buildings": bld})
	var res := {"map": map, "seed": seed_, "fac": fac, "swap": swap, "size": [Game.W, Game.H], "side_numbers": g.sides,
		"path_len": ch[0], "mirror": _mirror_check(), "layout": _layout_check(), "sides": lines}
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(res))
	f.close()
	print("GEO DONE ", map, " ", seed_)
	quit(0)
