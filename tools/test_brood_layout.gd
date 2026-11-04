extends SceneTree
## THE BROOD COMPUTER'S BASE LAYOUT (docs/brood_layout.md; the owner, 2026-11-04 19:57: "the turtle-locked units are
## stuck inside"). One case a run:
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_layout.gd -- case:rule [map:greenhold]
##       the check itself, on a real map, every 3x3 spot a Mound Turtle could root on (the player's rules): each spot the
##       whole-map check lets be really shuts nothing off (rooted for a moment by hand: no own unit leaves the open map,
##       no piece of open ground bigger than a nook is cut off), and each it refuses really would; some are refused
##   godot ... -- case:opening map:<map> [bs:economy] [foe:crown] [end:420] [seed:7]
##       a Hard Brood computer against a Hard computer: after 1:00 no unit of its own stays shut in by its own rooted
##       creatures for more than 15 s, and no more than 60 unit-seconds in all
##   godot ... -- case:alarm [map:thornwood_maze]
##       the alarm's turtle, set up by hand (see _alarm): a turtle whose swamp is the only swamp under a live rooted
##       Rootmaw stays rooted (the alarm takes another), the Rootmaw keeps its swamp; a dying one may go
## tools/test_brood_layout.sh runs every case (the five study maps for the opening).
var main: Node
var t := 0.0
var g: Game
var started := false
var fails := 0
var case_ := "rule"
var map := "greenhold"
var bs := "economy"
var foe := "crown"
var end_t := 420.0
var seed_ := 7
var bt := 1
var ai: AIBroodNew = null


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"case": case_ = kv[1]
			"map": map = kv[1]
			"bs": bs = kv[1]
			"foe": foe = kv[1]
			"end": end_t = float(kv[1])
			"seed": seed_ = int(kv[1])
			"off": BroodLayout.off = kv[1] == "1"      # (the computer before the fix: the cases should fail)
	if case_ == "alarm" and map == "greenhold":
		map = "thornwood_maze"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": foe, "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": bs}]})
		return false
	if main.game == null:
		return false
	g = main.game
	g.path_budget_us = 1 << 40
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
	paused = false
	if not started and t > 0.5:
		started = true
		for a in g.ais:
			if a is AIBroodNew:
				ai = a
				bt = a.team
		match case_:
			"rule": _rule()
			"opening": _opening()
			"alarm": _alarm()
			_:
				print("unknown case ", case_)
				quit(1)
	return false


func wait_until(c: float) -> void:
	while g.clock < c and not g.over:
		await physics_frame


func done() -> void:
	print("%s: %s (%d failure%s)" % [case_, "ALL PASS" if fails == 0 else "FAILED", fails, "" if fails == 1 else "s"])
	quit(0 if fails == 0 else 1)


# ------------------------------------------------------------------ rule

func _main_nodes() -> int:
	BroodLayout._sync(g)
	var n := 0
	for i in BroodLayout._comp.size():
		if BroodLayout._comp[i] == BroodLayout._main:
			n += 1
	return n


func _rule() -> void:
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_until(3.0)
	var k := BroodNew.TURTLE
	var spots_ok := 0
	var spots_no := 0
	var bad_ok := 0
	var bad_no := 0
	var base := _main_nodes()
	_base_comp = BroodLayout._comp.duplicate()
	_base_main = BroodLayout._main
	var walkers: Array = g.units.filter(func(u: Unit) -> bool: return BroodLayout.walker(u, bt))
	var mr := BroodLayout.main_region(g)
	for y in range(2, Game.H - 4, 1):
		for x in range(2, Game.W - 4, 1):
			var c := Vector2i(x, y)
			var p := BroodRoot.feet_at(k, c)
			if BroodRoot.place_problem(g, bt, k, p, null, false) != "":
				continue
			# (only near something: in the open every spot is let be by the quick yes)
			var why := BroodLayout.exact(g, bt, k, p, null)
			if why == "" and _open_round(c):
				spots_ok += 1
				continue          # (free ground two cells wide all round: nothing to verify)
			# root it for a moment by hand: its footprint on the grid
			var cells: Array = []
			for yy in 3:
				for xx in 3:
					var cc := c + Vector2i(xx, yy)
					if g.solid[g.idx(cc)] == 0:
						cells.append(cc)
						g._mark(cc, Vector2i.ONE, 2)
			var after := _main_nodes()
			var under := 0
			for yy in range(-1, 3):
				for xx in range(-1, 3):
					var nc := c + Vector2i(xx, yy)
					if g.in_map(nc) and _was_main(nc):
						under += 1
			var lost := base - after - under
			var shut := 0
			var mr2 := BroodLayout.main_region(g)
			for u in walkers:
				var cell := g.cell_of(u.position)
				if g.region_of(cell) != mr2 and not (Rect2i(c, Vector2i(3, 3)).has_point(cell)):
					shut += 1
			for cc in cells:
				g._mark(cc, Vector2i.ONE, 0)
			BroodLayout._sync(g)
			if why == "":
				spots_ok += 1
				if shut > 0 or lost > 3 * BroodLayout.TINY:
					bad_ok += 1
					if bad_ok <= 5:
						print("  let be but shuts off: %s (lost %d blocks, %d units)" % [str(c), lost, shut])
			else:
				spots_no += 1
				if lost <= 0 and shut == 0:
					bad_no += 1
					if bad_no <= 5:
						print("  refused but shuts nothing: %s (%s)" % [str(c), why])
	print("spots let be %d, refused %d" % [spots_ok, spots_no])
	check(spots_no > 0, "some spots are refused on %s (narrow ground)" % map)
	check(bad_ok == 0, "every spot let be shuts nothing off (%d did)" % bad_ok)
	check(bad_no <= spots_no / 10, "the spots refused really would shut ground off (%d of %d did not)" % [bad_no, spots_no])
	check(BroodLayout.main_region(g) == mr, "the grid is as it was")
	done()


func _open_round(c: Vector2i) -> bool:
	for yy in range(-2, 5):
		for xx in range(-2, 5):
			var nc := c + Vector2i(xx, yy)
			if not g.in_map(nc) or not BroodLayout.free_i(g, g.idx(nc)):
				return false
	return true


var _base_comp := PackedInt32Array()
var _base_main := -1


func _was_main(nc: Vector2i) -> bool:
	if _base_comp.is_empty():
		return false
	return _base_comp[g.idx(nc)] == _base_main


# ------------------------------------------------------------------ opening

func _opening() -> void:
	var since := {}
	var longest := 0.0
	var total := 0
	var who := ""
	while g.clock < end_t and not g.over:
		await wait_until(floorf(g.clock) + 1.0)
		if g.clock < 60.0:
			continue
		var p := BroodLayout.pockets(g, bt)
		var now := {}
		for r in p:
			for u in p[r]:
				now[u] = true
				total += 1
				if not since.has(u):
					since[u] = g.clock
				if g.clock - float(since[u]) > longest:
					longest = g.clock - float(since[u])
					who = "%s at %s" % [(u as Unit).kind, str(g.cell_of((u as Unit).position))]
		for u in since.keys():
			if not now.has(u):
				since.erase(u)
	print("%s %s v %s: stuck unit-seconds %d, longest %.0f s (%s); refused %d, net uproots %d, walk-outs %d" % [map, bs, foe, total, longest, who,
		ai.layout_refused, ai.unstuck_uproots, ai.unstuck_passes])
	check(longest <= 15.0, "no unit of its own shut in by its creatures for more than 15 s (longest %.0f)" % longest)
	check(total <= 60, "no more than 60 unit-seconds shut in (%d)" % total)
	done()


# ------------------------------------------------------------------ alarm

## A spot `tiles` from p toward `dir` (or about) where a `k` of side bt may root (the player's rules).
func root_spot(k: String, p: Vector2, dir: Vector2, tiles: float, swamp := true) -> Vector2:
	for r in [tiles, tiles + 1.0, tiles - 1.0, tiles + 2.0, tiles - 2.0]:
		for turn in [0.0, 0.2, -0.2, 0.4, -0.4, 0.6, -0.6]:
			var s2: Vector2 = BroodRoot.snap(k, p + dir.rotated(turn) * r * Defs.TILE)
			if g.region_of(g.cell_of(s2)) == BroodRoot.home_region(g, p) and BroodRoot.place_problem(g, bt, k, s2, null, false, 1.0, swamp) == "":
				return s2
	return Vector2.INF


func rooted_one(k: String, at: Vector2) -> Unit:
	var u: Unit = g._add_unit(k, bt, at)
	u.cmd_deploy()
	return u


## The alarm's turtle, set up by hand (the computers switched off; the Brood computer's alarm called directly): a
## natural turtle on new ground; a turtle F at home on the side of the front spot (the nearest to it) whose swamp is
## the only swamp under a Rootmaw rooted beyond the Mother's; a turtle S at home on the other side that feeds nothing.
## Before the fix the alarm got F up and the Rootmaw went dry; now it must take S.
func _alarm() -> void:
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_until(6.0)
	var q := BroodNew.queen(g, bt)
	var foe_at: Vector2 = (Vector2(g.starts[1 - bt]) + Vector2(2.5, 2.0)) * Defs.TILE
	var to_foe := (foe_at - q.position).normalized()
	var side := to_foe.rotated(PI * 0.5)
	var nat_at := root_spot(BroodNew.TURTLE, q.position, to_foe.rotated(0.9), 17.0)
	if nat_at == Vector2.INF:
		nat_at = root_spot(BroodNew.TURTLE, q.position, to_foe.rotated(-0.9), 17.0)
	check(nat_at != Vector2.INF, "a natural turtle spot")
	var nat := rooted_one(BroodNew.TURTLE, nat_at)
	await wait_until(g.clock + 4.0)
	var fs = ai._nb_front_spot(q)
	check(fs != null, "the alarm has a front spot")
	if fs == null:
		done()
		return
	var dir: Vector2 = ((fs as Vector2) - q.position).normalized()
	var f_at := root_spot(BroodNew.TURTLE, q.position, dir, 9.0)
	var f := rooted_one(BroodNew.TURTLE, f_at)
	var s_at := root_spot(BroodNew.TURTLE, q.position, -dir, 9.0)
	var s2 := rooted_one(BroodNew.TURTLE, s_at)
	await wait_until(g.clock + 18.0)          # (rooted, their swamp grown)
	# the Rootmaw: on F's swamp, off the Mother's and the natural's (the sources as Game lays them, full grown)
	var m_at := Vector2.INF
	var others: Array = []
	for o in [q, nat, s2]:
		others.append([o.position / Defs.TILE, BroodNew.swamp_full(o) + 0.5])
	for r in [8.0, 7.0, 9.0, 6.0]:
		for i in 24:
			var c2: Vector2 = BroodRoot.snap(BroodNew.MAW, f.position + Vector2.from_angle(TAU * i / 24.0) * r * Defs.TILE)
			var mid := Vector2(g.cell_of(c2)) + Vector2(0.5, 0.5)
			if others.any(func(src: Array) -> bool: return BroodLayout._in_swamp(mid, src)):
				continue
			if BroodRoot.place_problem(g, bt, BroodNew.MAW, c2, null, false) == "":
				m_at = c2
				break
		if m_at != Vector2.INF:
			break
	var m: Unit = null
	if m_at != Vector2.INF:
		m = rooted_one(BroodNew.MAW, m_at)
	await wait_until(g.clock + 5.0)
	var feeds := BroodLayout.feeds_maws(g, f)
	print("natural %s, front spot %s, F %s, S %s, Rootmaw %s; F feeds %d, S feeds %d" % [str(g.cell_of(nat.position)), str(g.cell_of(fs)),
		str(g.cell_of(f.position)), str(g.cell_of(s2.position)), str(g.cell_of(m.position)) if m else "none", feeds.size(), BroodLayout.feeds_maws(g, s2).size()])
	check(m != null and BroodNew.rooted(m) and feeds.has(m), "set up: F's swamp is the only swamp under a rooted Rootmaw")
	check(BroodLayout.feeds_maws(g, s2).is_empty(), "set up: S feeds no Rootmaw")
	check(f.position.distance_to(fs) < s2.position.distance_to(fs), "set up: F is the turtle nearest the front spot")
	ai.alarm_t = g.clock
	ai.alarm_at = fs
	ai._front_done = false
	ai._front_t = null
	ai._nb_alarm(q)
	print("the alarm picked: %s" % ("F" if ai._front_t == f else ("S" if ai._front_t == s2 else str(ai._front_t))))
	await wait_until(g.clock + 12.0)
	check(f.tesla_mode == "deployed", "F, feeding the Rootmaw, stays rooted (%s)" % f.tesla_mode)
	check(ai._front_t == s2 or s2.tesla_mode != "deployed", "the alarm took S, the turtle feeding nothing")
	check(m != null and not m.dead and m.tesla_mode == "deployed", "the Rootmaw kept its swamp and stays rooted")
	# a dying F may go (it would be lost with its swamp anyway)
	if s2.tesla_mode != "deployed":
		ai._front_t = null
		ai._front_done = false
		f.hp = f.max_hp * 0.2
		ai.alarm_t = g.clock
		ai._nb_alarm(q)
		check(ai._front_t == f, "a dying F may get up for the alarm")
	done()
