extends SceneTree
## THE CROWN'S HALL PICK, TIMED (CrownSites.pick, as AICrown._safe_hall_spot calls it: its field and steps kept between
## calls, the computer's placement check). A frame of the computer's must stay short (the owner's 0.30.4 log: 586 ms).
##   godot --headless --script res://tools/time_crown_pick.gd [-- map_id seed [pieces]]
## Prints each call's ms and pick: the 2nd base cold (the first call: the ramp's walk, the old natural), warm (the same
## call again), after a Farm by the main; the computer's way (CrownSites.warm in 3 ms pieces first: how many ticks, the
## longest; `pieces` prints the first ones); after a Farm ON the best spot with no work ahead; the 3rd base with the 2nd
## built. Each pick is checked against one worked out from nothing (a new field and new walks): the kept field must not
## change the pick; and ExpansionSpots._room against the walk it replaced on every third spot of the map. Exit 1 if any differ.

var failed := 0


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _call(g: Game, what: String, halls: Array, steps: Array, check: Callable, field: Dictionary) -> Array:
	var t0 := Time.get_ticks_usec()
	var p: Array = CrownSites.pick(g, 0, halls, 1, steps, {}, check, field)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var fresh: Array = CrownSites.pick(g, 0, halls, 1, [], {}, check, null)
	var same: bool = p.size() == fresh.size() and (p.is_empty() or (p[0]["c"] == fresh[0]["c"] and absf(float(p[0]["score"]) - float(fresh[0]["score"])) < 0.001))
	if not same:
		failed += 1
	print("  %-28s %7.1f ms -> %s score %s  %s" % [what, ms, str(p[0]["c"]) if not p.is_empty() else "-",
		str(p[0]["score"]) if not p.is_empty() else "-", "same as fresh" if same else "DIFFERS from fresh %s" % str(fresh[0]["c"] if not fresh.is_empty() else "-")])
	return p


func _warm(g: Game, wf: Dictionary, steps: Array, what: String) -> void:
	var calls := 0
	var worst := 0.0
	var total := 0.0
	while true:
		var t0 := Time.get_ticks_usec()
		var done := CrownSites.warm(g, 0, wf, steps, 3000)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		calls += 1
		worst = maxf(worst, ms)
		total += ms
		if calls <= 6 and OS.get_cmdline_user_args().has("pieces"):
			print("    piece %d: %.1f ms" % [calls, ms])
		if done or calls > 2000:
			break
	print("  work ahead (%s): %d ticks, longest %.1f ms, all %.1f ms" % [what, calls, worst, total])


func _run(args: Array) -> void:
	var id: String = args[0] if args.size() > 0 else "redrock_canyon"
	var g := Game.new()
	g.map_id = id
	g.demo = true
	g.rng.seed = int(args[1]) if args.size() > 1 else 7
	g.factions = ["crown", "brood"]
	g.sides = [0, 1]
	g.colours = [0, 1]
	root.add_child(g)
	await process_frame
	var t := 0
	var check := func(c: Vector2i) -> bool: return g.placement_problem(t, "town_hall", c, true) == ""
	var main_mid := Vector2(g.starts[t]) + Vector2(2.5, 2.0)
	var t0 := Time.get_ticks_usec()
	var field: Dictionary = CrownSites.edge_field(g, CrownSites.edge_cells(g, t))
	var steps: Array = [ExpansionSpots._steps(g, g.starts[t]), [ExpansionSpots._steps(g, g.starts[1])]]
	print("%s seed %d: edge field and walks %.1f ms (once a game)" % [id, g.rng.seed, (Time.get_ticks_usec() - t0) / 1000.0])
	var p := _call(g, "2nd cold", [main_mid], steps, check, field)
	p = _call(g, "2nd warm", [main_mid], steps, check, field)
	g._add_building("farm", t, g.starts[t] + Vector2i(7, 0), true)
	p = _call(g, "2nd after a Farm by the main", [main_mid], steps, check, field)
	# THE COMPUTER'S WAY (AICrown._cs_warm): the work done ahead in 3 ms pieces on its quiet ticks, then the pick
	var wf := {}
	_warm(g, wf, steps, "a new field")
	_call(g, "2nd after the work ahead", [main_mid], steps, check, wf)
	g._add_building("farm", t, g.starts[t] + Vector2i(2, -6), true)
	_call(g, "2nd, a Farm, no work ahead", [main_mid], steps, check, wf)
	g._add_building("farm", t, p[0]["c"] + Vector2i(6, 1), true)
	_warm(g, wf, steps, "a Farm by the best spot")
	_call(g, "2nd after the work ahead", [main_mid], steps, check, wf)
	# (no work ahead: what a pick made before it has caught up costs)
	var best: Vector2i = p[0]["c"]
	var fb: Building = g._add_building("farm", t, best + Vector2i(1, 1), true)
	_call(g, "2nd, a Farm on the best spot", [main_mid], steps, check, field)
	fb.dead = true
	g._mark(fb.cell, fb.size, 0)
	p = _call(g, "2nd, that Farm gone", [main_mid], steps, check, field)
	var h2: Building = g._add_building("town_hall", t, p[0]["c"], true)
	var hs := [main_mid, h2.center() / float(Defs.TILE)]
	_call(g, "3rd (2nd built)", hs, steps, check, field)
	_call(g, "3rd warm", hs, steps, check, field)
	# the economy room: the span fill (ExpansionSpots._room) against the walk it replaced, over the whole map
	var n := 0
	var bad := 0
	var t_new := 0
	var t_old := 0
	for y in range(0, Game.H - MapGen.HALL.y + 1, 3):
		for x in range(0, Game.W - MapGen.HALL.x + 1, 3):
			var c := Vector2i(x, y)
			var a0 := Time.get_ticks_usec()
			var ra := ExpansionSpots._room(g, c)
			var a1 := Time.get_ticks_usec()
			var rb := ExpansionSpots._room_walk(g, c)
			t_new += a1 - a0
			t_old += Time.get_ticks_usec() - a1
			n += 1
			if absf(ra - rb) > 0.0000001:
				bad += 1
				if bad <= 5:
					print("  ROOM DIFFERS at %s: %.4f / %.4f" % [str(c), ra, rb])
	print("  economy room: %d spots, %d differ; %.3f ms a spot (the walk: %.3f ms)" % [n, bad, t_new / 1000.0 / n, t_old / 1000.0 / n])
	failed += bad
	print("time_crown_pick: %s" % ("ALL SAME" if failed == 0 else "%d DIFFER" % failed))
	quit(1 if failed > 0 else 0)
