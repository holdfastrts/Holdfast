extends SceneTree
## Debug (not a test): the Crown's 2nd/3rd marks over many decoration seeds, with test_expansion_spots' Crown v2 checks.
##   -- maps(comma or "all") players seeds_from seeds_to [detail]
## detail: print the ranked candidates of team 0 with their terms.

func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _make(id: String, n: int, seed: int) -> Game:
	var g := Game.new()
	g.map_id = id
	g.demo = true
	g.rng.seed = seed
	var facs: Array = []
	var sides: Array = []
	for i in n:
		facs.append("crown")
		sides.append(0 if i < n / 2 else 1)
	g.factions = facs
	g.sides = sides
	g.colours = range(n)
	root.add_child(g)
	return g


func _run(args: Array) -> void:
	var ids: Array = MapGen.all_ids() if args[0] == "all" else Array(String(args[0]).split(","))
	var n_arg := int(args[1])
	var s0 := int(args[2])
	var s1 := int(args[3])
	var detail := args.size() > 4
	var nbad := 0
	for id in ids:
		var n := n_arg if n_arg > 0 else MapGen.max_players(id)
		if n > MapGen.max_players(id):
			continue
		for seed in range(s0, s1 + 1):
			var g := _make(id, n, seed)
			await process_frame
			var sp: Array = g.exp_spots.spots
			var line := "%s %dp seed %d:" % [id, n, seed]
			for s in sp:
				if int(s["team"]) == 0:
					line += " #%d %s(w%d e%d o%d m%.1f sc%.1f)" % [s["rank"], s["c"], s["walk"], s["edge"], s["open"], s["main"], s["score"]]
			var bad: Array = []
			for s in sp:
				if s.get("crown", false):
					_crown_v2(g, s, sp, bad)
			print(line, "  ", "ok" if bad.is_empty() else "BAD " + str(bad))
			if not bad.is_empty():
				nbad += 1
			if detail:
				_detail(g, int(args[5]) if args.size() > 5 else 0)
			g.queue_free()
			await process_frame
	print("bad runs: %d" % nbad)
	quit()


func _detail(g: Game, t: int) -> void:
	var field: Dictionary = CrownSites.edge_field(g, CrownSites.edge_cells(g, t))
	CrownSites._prep(g, t, field)
	var main_mid := Vector2(g.starts[t]) + Vector2(2.5, 2.0)
	print("  main ", g.starts[t], " foot ", field["ramp"].get("foot"), " nat side ", CrownSites.natural_side(g, t, field), " nat ", field.get("nat"))
	var steps: Array = [ExpansionSpots._steps(g, g.starts[t]), []]
	for o in g.n_players():
		if g.hostile(o, t):
			steps[1].append(ExpansionSpots._steps(g, g.starts[o]))
	for st in [2, 3]:
		for w in [1, -1]:
			var r := CrownSites._ranked(g, t, [main_mid], st, w, steps, {}, Callable(), field, {}, 15)
			print("  stage %d side %d:" % [st, w])
			for x in r:
				print("     lv %d/%d" % [int(g.height[g.idx(x["c"])]), int(g.height[g.idx(g.starts[t] + Vector2i(2, 2))])], " %s score %.2f walk %d main %.1f edge %d open %d room %.2f share %.2f home %d foe %s" % [x["c"], x["score"], x["walk"], x["main"], x["edge"], x["open"], x["room"], x["share"], x["home"], str(x["foe"])])


## (copied from tools/test_expansion_spots.gd _crown_v2: the walk and border checks)
func _crown_v2(g: Game, s: Dictionary, sp: Array, bad: Array) -> void:
	var t := int(s["team"])
	var rank := int(s["rank"])
	if rank > 2 or g.halls_of(t, false).size() > 1:
		return
	var field: Dictionary = CrownSites.edge_field(g, CrownSites.edge_cells(g, t))
	CrownSites._prep(g, t, field)
	var ramp: Dictionary = field["ramp"]
	var c: Vector2i = s["c"]
	var md := float(s["main"])
	if md > Defs.HALL_SPACING + (5.0 if rank == 1 else CrownSites.SLACK):
		bad.append("crown #%d %s: %.1f tiles from the main" % [rank, c, md])
	if ramp.is_empty():
		return
	var main_mid := Vector2(g.starts[t]) + Vector2(2.5, 2.0)
	var steps: Array = [ExpansionSpots._steps(g, g.starts[t]), []]
	for o in g.n_players():
		if g.hostile(o, t):
			steps[1].append(ExpansionSpots._steps(g, g.starts[o]))
	var other := Vector2.INF
	for o in sp:
		if int(o["team"]) == t and int(o["rank"]) == 3 - rank:
			other = Vector2(o["c"]) + Vector2(MapGen.HALL) * 0.5
	var legal: Array = CrownSites._ranked(g, t, [main_mid], 2, int(s["side"]), steps, {}, Callable(), field, {}, 100000).filter(
			func(r: Dictionary) -> bool: return other == Vector2.INF or (Vector2(r["c"]) + Vector2(MapGen.HALL) * 0.5).distance_to(other) >= Defs.HALL_SPACING)
	var lim := Defs.HALL_SPACING + (5.0 if rank == 1 else CrownSites.SLACK)
	var nears: Array = legal.filter(func(r: Dictionary) -> bool: return float(r["walk"]) <= CrownSites.WALK_NEAR and float(r["main"]) <= lim + 0.01)
	if float(s["walk"]) > CrownSites.WALK_NEAR and not nears.is_empty():
		bad.append("p%d #%d %s far out (%d steps); a near one: %s w%d sc%.1f" % [t, rank, c, int(s["walk"]), nears[0]["c"], nears[0]["walk"], nears[0]["score"]])
	if rank == 1:
		var ns := CrownSites.natural_side(g, t, field)
		if ns != 0 and int(s["side"]) != ns:
			bad.append("p%d #1 %s not on the natural's side" % [t, c])
		var near_edge := 999
		for r in legal:
			if float(r["main"]) <= md + 0.01 and float(r["walk"]) <= maxf(float(s["walk"]), CrownSites.WALK_NEAR):
				near_edge = mini(near_edge, int(r["edge"]))
		if int(s["edge"]) > near_edge + 3:
			bad.append("p%d #1 %s: %d from the border, one as near has %d" % [t, c, int(s["edge"]), near_edge])
	else:
		for o in sp:
			if int(o["team"]) == t and int(o["rank"]) == 1 and int(o["side"]) * int(s["side"]) != -1:
				var mid1 := Vector2(o["c"]) + Vector2(MapGen.HALL) * 0.5
				var there := CrownSites._ranked(g, t, [main_mid, mid1], 3, -int(o["side"]), steps, {}, Callable(), field, {}, 1)
				if int(o["side"]) == 0 or not there.is_empty():
					bad.append("p%d #2 %s not on the other side" % [t, c])
