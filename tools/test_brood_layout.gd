extends SceneTree
## THE BROOD COMPUTER'S BASE LAYOUT (docs/brood_layout.md; the owner, 2026-11-04 19:57: "the turtle-locked units are
## stuck inside"). One case a run:
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_layout.gd -- case:rule [map:greenhold]
##       the check itself, on a real map, every 3x3 spot a Mound Turtle could root on (the player's rules): each spot the
##       whole-map check lets be really shuts nothing off (rooted for a moment by hand: no own unit leaves the open map,
##       no piece of open ground bigger than a nook is cut off), and each it refuses really would; some are refused
##   godot ... -- case:opening map:<map> [bs:economy] [foe:crown] [end:420]
##       a Hard Brood computer against a Hard computer: after 1:00 no unit of its own stays shut in by its own rooted
##       creatures for more than 15 s, and no more than 60 unit-seconds in all
##   godot ... -- case:alarm [map:thornwood_maze]
##       an Economy Brood: at 4:30 its alarm is set off by hand: no Mound Turtle whose swamp is the only swamp of live
##       rooted Rootmaws gets up (unless dying), and none of its Rootmaws goes dry in the next 40 s because of its own turtle
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
		seed(7)
		main.start({"map": map, "seed": 7, "slots": [
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

func _alarm() -> void:
	await wait_until(270.0)
	var q := BroodNew.queen(g, bt)
	var feeders := {}
	for u in g.units:
		if u.team == bt and u.kind == BroodNew.TURTLE and BroodNew.rooted(u) and not BroodLayout.feeds_maws(g, u).is_empty():
			feeders[u] = BroodLayout.feeds_maws(g, u).size()
	print("at %s: %d turtles feed live Rootmaws (%s)" % [g.clock, feeders.size(), str(feeders.values())])
	check(not feeders.is_empty(), "the Brood has a turtle feeding Rootmaws by 4:30 (else this case proves nothing)")
	ai.alarm_t = g.clock
	ai.alarm_at = q.position.lerp(Vector2(g.starts[1 - bt]) * Defs.TILE, 0.5) if q else Vector2.ZERO
	ai._front_done = false
	ai._front_t = null
	ai._nb_alarm(q)
	var up_feeders := 0
	var dry_own := 0
	var modes := {}
	var ups: Array = []
	var stop := g.clock + 40.0
	while g.clock < stop and not g.over:
		await physics_frame
		ai.alarm_t = maxf(ai.alarm_t, g.clock - 1.0)      # (the alarm stays on)
		for u in g.units:
			if u.team != bt:
				continue
			var was := String(modes.get(u, u.tesla_mode))
			modes[u] = u.tesla_mode
			if was == "deployed" and u.tesla_mode == "packing":
				if u.kind == BroodNew.TURTLE:
					ups.append([g.clock, u.position])
					if feeders.has(u) and u.hp > u.max_hp * AIBroodNew.DYING:
						up_feeders += 1
						print("  %.0f a turtle feeding %d Rootmaws got up" % [g.clock, feeders[u]])
				elif u.kind == BroodNew.MAW and bool(u.nb.get("dry", false)):
					for e in ups:
						if (u.position - (e[1] as Vector2)).length() < (float(Defs.NB["turtle_swamp"]) + 2.0) * Defs.TILE:
							dry_own += 1
							print("  %.0f a Rootmaw went dry after its own turtle got up" % g.clock)
							break
	check(up_feeders == 0, "the alarm got up no turtle feeding live Rootmaws (%d did)" % up_feeders)
	check(dry_own == 0, "no Rootmaw went dry because of its own turtle (%d did)" % dry_own)
	done()
