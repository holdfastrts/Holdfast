extends SceneTree
## EXPANSION SPOTS (scripts/expansion_spots.gd, docs/expansion_spots.md). Every built-in map, with 2 players and with as
## many as it holds:
##  - every player has at least one marked spot, and every side has the same number of each rank,
##  - mirror-fair: each marked spot's twin (the map turned through its middle) is marked too, with the same rank and score,
##  - a marked spot is free, buildable ground for a hall (nobody's start; no blocked cell, no ramp), a base site for the
##    Clockwork; for the Crown (CrownSites, 0.29.2) any ground at the least hall distance from its main (its best no more
##    than CrownSites.SLACK past it) and its two spots a hall's spacing apart; THE CROWN'S RULE v2 (0.29.5, _crown_v2):
##    the 2nd base within 5 tiles of the least distance, on the old natural's side of the main's ramp, the 3rd on the
##    other side, both within CrownSites.WALK_NEAR steps of the ramp's foot (when any legal spot there is), the 2nd as near
##    the map's border as any legal spot on its side as near the main and the ramp (3 tiles of slack); each map is run all-Crown and all-Clockwork
##    (twins are rated by the same rule); a new Crown hall makes its side's marks be worked out again,
##  - THE CLOCKWORK'S RULE (ClockSites, clockwork-eco 0.30.10): a Clockwork side's marks a hall's spacing from its main and
##    each other, with room for CLOCK_RING_MIN of its Clocktower's ring buildings, and on each side's best one the game lets
##    CLOCK_PLACED of the 8 ring buildings be laid (ClockSites.fill_ring); a Clockwork player's own spots are the Clockwork's;
##  - shown to a Crown and a Clockwork player and when watching; hidden for a Brood player, hidden once a building the
##    viewer knows of stands on it, and hidden with Settings.expansion_spots off.
##   godot --headless --fixed-fps 30 --script res://tools/test_expansion_spots.gd [-- ids...]   (prints each map's spots)

var failed := 0


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _make(id: String, facs: Array, demo := true) -> Game:
	var g := Game.new()
	g.map_id = id
	g.demo = demo
	var sides: Array = []
	for i in facs.size():
		sides.append(0 if i < facs.size() / 2 else 1)
	g.factions = facs
	g.sides = sides
	g.colours = range(facs.size())
	root.add_child(g)
	return g


## THE CLOCKWORK'S RULE (clockwork-eco): a marked spot has room for this many of its ring's 3x3 buildings (ClockSites.ring_fit,
## 9 on open ground), and the game itself lets at least CLOCK_PLACED of the 8 kinds of ClockSites.FULL_RING be laid meshing with a
## Clocktower on each side's best spot (ClockSites.fill_ring: the gear rules, the level rule, the margins).
const CLOCK_RING_MIN := 7
const CLOCK_PLACED := 6


## Lay a Clocktower on each side's best Clockwork spot and its ring as the game allows it: at least CLOCK_PLACED of 8.
func _clock_ring_check(g: Game, bad: Array) -> void:
	var best: Array = g.exp_spots.spots.filter(func(s: Dictionary) -> bool: return s.get("clock", false) and int(s["rank"]) == 1)
	for s in best:
		var tw: Building = g._add_building("clocktower", int(s["team"]), s["c"], true)
		var ring: Array = ClockSites.fill_ring(g, int(s["team"]), tw)
		print("    ring at p%d %s: %d of %d laid (%s)" % [int(s["team"]), str(s["c"]), ring.size(), ClockSites.FULL_RING.size(), ", ".join(ring.map(func(e): return String(e[0])))])
		if ring.size() < CLOCK_PLACED:
			bad.append("clockwork p%d %s: only %d of the ring's %d buildings could be laid" % [int(s["team"]), str(s["c"]), ring.size(), ClockSites.FULL_RING.size()])


func _fmt(s: Dictionary) -> String:
	return "p%d #%d %s score %.0f room %d%% ways %d (gap %d) walk %d foe %s" % [int(s["team"]), int(s["rank"]), str(s["c"]), float(s["score"]),
		int(round(float(s["room"]) * 100)), int(s["ways"]), int(s["gap"]), int(s["home"]), str(int(s["foe"])) if float(s["foe"]) < INF else "-"]


func _check_map(g: Game, bad: Array) -> void:
	var sp: Array = g.exp_spots.spots
	var by := {}
	for t in g.n_players():
		by[t] = [0, 0]
	for s in sp:
		by[int(s["team"])][int(s["rank"]) - 1] += 1
	for t in g.n_players():
		if int(by[t][0]) < 1:
			bad.append("player %d has no marked spot" % t)
		if by[t] != by[0] and g.n_players() == 2:
			bad.append("player %d has %s marks, player 0 %s" % [t, str(by[t]), str(by[0])])
	var at := {}
	for s in sp:
		at[s["c"]] = s
	for s in sp:
		var c: Vector2i = s["c"]
		var tw: Vector2i = g._mirror(c, MapGen.HALL)
		if not at.has(tw):
			bad.append("%s is marked, its twin %s is not" % [c, tw])
		elif int(at[tw]["rank"]) != int(s["rank"]) or absf(float(at[tw]["score"]) - float(s["score"])) > 0.01:
			bad.append("%s and its twin %s differ: %s / %s" % [c, tw, _fmt(s), _fmt(at[tw])])
		if g.starts.has(c):
			bad.append("%s is a player's start" % c)
		if not s.get("crown", false) and not s.get("clock", false) and not g.base_sites.has(c):
			bad.append("%s is not a base site" % c)
		if s.get("clock", false):
			# THE CLOCKWORK'S RULE (ClockSites, clockwork-eco 0.30.10): a hall's spacing from its main and the other mark, and
			# room for its Clocktower's ring of buildings on its own level
			var cm := Vector2(c) + Vector2(MapGen.HALL) * 0.5
			var ct := int(s["team"])
			if cm.distance_to(Vector2(g.starts[ct]) + Vector2(2.5, 2.0)) < Defs.HALL_SPACING - 0.01:
				bad.append("clockwork %s: nearer its main than a hall's spacing" % c)
			for o in sp:
				if o != s and int(o["team"]) == ct and cm.distance_to(Vector2(o["c"]) + Vector2(MapGen.HALL) * 0.5) < Defs.HALL_SPACING - 0.01:
					bad.append("clockwork %s and %s are nearer each other than a hall's spacing" % [c, o["c"]])
			if int(s["slots"]) < CLOCK_RING_MIN:
				bad.append("clockwork %s: room for only %d of its ring's buildings (want %d+)" % [c, int(s["slots"]), CLOCK_RING_MIN])
		if s.get("crown", false):
			# THE CROWN'S RULE (CrownSites): at the least hall distance from its main (18) and the 2nd from the 1st too
			var mid := Vector2(c) + Vector2(MapGen.HALL) * 0.5
			var t := int(s["team"])
			var md: float = mid.distance_to(Vector2(g.starts[t]) + Vector2(2.5, 2.0))
			if md < Defs.HALL_SPACING - 0.01 or (int(s["rank"]) == 1 and md > Defs.HALL_SPACING + CrownSites.SLACK):
				bad.append("%s: %.1f tiles from its main" % [c, md])
			for o in sp:
				if o != s and int(o["team"]) == t and mid.distance_to(Vector2(o["c"]) + Vector2(MapGen.HALL) * 0.5) < Defs.HALL_SPACING - 0.01:
					bad.append("%s and %s are nearer each other than a hall's spacing" % [c, o["c"]])
			_crown_v2(g, s, sp, bad)
		for y in MapGen.HALL.y:
			for x in MapGen.HALL.x:
				var cc := c + Vector2i(x, y)
				if not g.in_map(cc) or g.solid[g.idx(cc)] != 0 or g.ramp[g.idx(cc)] != 0:
					bad.append("%s: cell %s is not buildable" % [c, cc])


## THE CROWN'S RULE v2 (the owner, 2026-11-04 07:05): on the bare map, the 2nd base (mark #1) and the 3rd (mark #2) at
## about the least hall distance from the main, on OPPOSITE sides of the line from the main through its ramp's foot (the
## 2nd on the old natural's side), each a short walk from the ramp's foot, and the 2nd as near the map's border as any
## legal spot on its side that is as near the main and the ramp.
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
	var other := Vector2.INF        # (the other mark's middle)
	for o in sp:
		if int(o["team"]) == t and int(o["rank"]) == 3 - rank:
			other = Vector2(o["c"]) + Vector2(MapGen.HALL) * 0.5
	# the legal spots on its side that leave the other mark its place
	var room := {}
	var legal: Array = CrownSites._ranked(g, t, [main_mid], 2, int(s["side"]), steps, {}, Callable(), field, room, 100000).filter(
			func(r: Dictionary) -> bool: return other == Vector2.INF or (Vector2(r["c"]) + Vector2(MapGen.HALL) * 0.5).distance_to(other) >= Defs.HALL_SPACING)
	# (a near one for the 2nd only counts within the 5 tiles this test allows it: on some decorations of the classic 4-player
	# maps the only spots near the ramp are 24.7 tiles out, and the two demands can't both be met; 0.30.5)
	var lim := Defs.HALL_SPACING + (5.0 if rank == 1 else CrownSites.SLACK)
	if float(s["walk"]) > CrownSites.WALK_NEAR and legal.any(func(r: Dictionary) -> bool: return float(r["walk"]) <= CrownSites.WALK_NEAR and float(r["main"]) <= lim + 0.01):
		bad.append("crown #%d %s: %d steps from the ramp's foot (far out)" % [rank, c, int(s["walk"])])
	if rank == 1:
		var ns := CrownSites.natural_side(g, t, field)
		if ns != 0 and int(s["side"]) != ns:
			bad.append("crown #1 %s: not on the old natural's side of the ramp (%d, natural %d)" % [c, int(s["side"]), ns])
		var near_edge := 999
		for r in legal:
			if float(r["main"]) <= md + 0.01 and float(r["walk"]) <= maxf(float(s["walk"]), CrownSites.WALK_NEAR):
				near_edge = mini(near_edge, int(r["edge"]))
		if int(s["edge"]) > near_edge + 3:
			bad.append("crown #1 %s: %d tiles from the border, a spot as near has %d" % [c, int(s["edge"]), near_edge])
	else:
		for o in sp:
			if int(o["team"]) == t and int(o["rank"]) == 1:
				# (only when a legal spot is there: the rule's own fallback, docs/expansion_spots.md 5, "nothing legal there: the
				# best on either side"; on some decorations of the classic 4-player maps a player's other side has none)
				var mid1 := Vector2(o["c"]) + Vector2(MapGen.HALL) * 0.5
				var there := CrownSites._ranked(g, t, [main_mid, mid1], 3, -int(o["side"]), steps, {}, Callable(), field, room, 1)
				if int(o["side"]) * int(s["side"]) != -1 and (int(o["side"]) == 0 or not there.is_empty()):
					bad.append("crown #2 %s is not on the other side of the ramp from #1 %s (%d, %d)" % [c, o["c"], int(s["side"]), int(o["side"])])


func _run(ids: Array) -> void:
	Settings.expansion_spots = true
	if ids.is_empty():
		ids = MapGen.all_ids()
	for id in ids:
		var counts: Array = [2]
		if MapGen.max_players(id) > 2:
			counts.append(MapGen.max_players(id))
		var runs: Array = []
		for n in counts:
			for fac in ["crown", "clockwork"]:
				runs.append([n, fac])
		for rn in runs:
			var n: int = rn[0]
			var facs: Array = []
			for i in n:
				facs.append(rn[1])       # (one faction a run: the twin of a spot is rated by the same rule)
			var g := _make(id, facs)
			await process_frame
			var bad: Array = []
			_check_map(g, bad)
			if rn[1] == "clockwork":
				_clock_ring_check(g, bad)
			print("%-18s %d players %-9s: %d spots  %s" % [id, n, rn[1], g.exp_spots.spots.size(), "ok" if bad.is_empty() else "FAIL"])
			for s in g.exp_spots.spots:
				if int(s["team"]) < 2 or n == 2:
					print("    ", _fmt(s))
			for m in bad.slice(0, 8):
				print("    BAD ", m)
			if not bad.is_empty():
				failed += 1
			g.queue_free()
			await process_frame
	await _viewer_checks()
	print("expansion spots: %s" % ("ALL OK" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed > 0 else 0)


func _expect(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failed += 1


## Who sees them, taken spots, the toggle.
func _viewer_checks() -> void:
	print("viewer checks (ashford_crossing):")
	for fac in ["crown", "clockwork", "brood"]:
		var g := _make("ashford_crossing", [fac, "crown"], false)
		g.human = 0
		await process_frame
		g.exp_spots.refresh()
		var n: int = g.exp_spots.shown.size()
		if fac == "brood":
			# (0.18.0: the Brood of creatures is the only Brood: its own best Mound Turtle spots, ExpansionSpots.nb_pick)
			_expect(n > 0 and g.exp_spots.shown.all(func(sp) -> bool: return sp.has("tc")), "a Brood player sees its turtle spots (%d shown)" % n)
		else:
			_expect(n == g.exp_spots.spots.size() and n > 0, "a %s player sees every spot (%d of %d)" % [fac, n, g.exp_spots.spots.size()])
		if fac == "crown":
			# THE CROWN'S RULE: a hall of ours on our best spot: the marks are worked out again from both halls
			var best0: Dictionary = {}
			for s in g.exp_spots.spots:
				if int(s["team"]) == 0 and int(s["rank"]) == 1:
					best0 = s
			_expect(best0.get("crown", false), "a Crown player's own spots are the Crown's (CrownSites)")
			var h2: Building = g._add_building("town_hall", 0, best0["c"], true)
			g.exp_spots.refresh()
			var mine2: Array = g.exp_spots.shown.filter(func(s: Dictionary) -> bool: return int(s["team"]) == 0)
			var spaced := mine2.all(func(s: Dictionary) -> bool:
				var m := Vector2(s["c"]) + Vector2(MapGen.HALL) * 0.5
				return m.distance_to(h2.center() / float(Defs.TILE)) >= Defs.HALL_SPACING - 0.01 and m.distance_to(Vector2(g.starts[0]) + Vector2(2.5, 2.0)) >= Defs.HALL_SPACING - 0.01)
			_expect(not mine2.is_empty() and spaced and not mine2.any(func(s: Dictionary) -> bool: return s["c"] == best0["c"]),
					"a new Crown hall: the next spots are worked out from both halls (%d shown, spaced %s)" % [mine2.size(), str(spaced)])
			h2.dead = true
		if fac == "clockwork":
			var own_ck := g.exp_spots.spots.filter(func(s: Dictionary) -> bool: return int(s["team"]) == 0)
			_expect(not own_ck.is_empty() and own_ck.all(func(s: Dictionary) -> bool: return s.get("clock", false)), "a Clockwork player's own spots are the Clockwork's (ClockSites)")
			# taken (base-site spots): a hall of ours on our best spot, an unseen enemy building on another, then seen
			var mine: Dictionary = {}
			var other: Dictionary = {}
			for s in g.exp_spots.spots:
				if int(s["team"]) == 0 and int(s["rank"]) == 1:
					mine = s
				elif int(s["team"]) == 1 and int(s["rank"]) == 1:
					other = s
			g._add_building("town_hall", 0, mine["c"], true)
			var eb: Building = g._add_building("town_hall", 1, other["c"], true)
			eb.seen_by_human = false
			g.exp_spots.refresh()
			var cs: Array = g.exp_spots.shown.map(func(s: Dictionary) -> Vector2i: return s["c"])
			_expect(not cs.has(mine["c"]), "our hall on a spot hides it")
			_expect(cs.has(other["c"]), "an enemy hall not yet seen does not hide its spot")
			eb.seen_by_human = true
			g.exp_spots.refresh()
			cs = g.exp_spots.shown.map(func(s: Dictionary) -> Vector2i: return s["c"])
			_expect(not cs.has(other["c"]), "once seen, the enemy hall hides it")
			eb.dead = true
			g.exp_spots.refresh()
			cs = g.exp_spots.shown.map(func(s: Dictionary) -> Vector2i: return s["c"])
			_expect(cs.has(other["c"]), "the spot shows again when the building is gone")
			# a hall built NEAR a spot, not on it, claims it too (the owner, 2026-10-29)
			# (the enemy's spot: our own are worked out again from our halls, ClockSites, so ours would move away)
			var second: Dictionary = {}
			for s in g.exp_spots.spots:
				if int(s["team"]) == 1 and int(s["rank"]) == 2:
					second = s
			if not second.is_empty():
				# (the owner: touching the tinted tiles hides it; completely off them, it still shows)
				var nb: Building = g._add_building("town_hall", 1, second["c"] + Vector2i(MapGen.HALL.x - 1, 0), true)
				nb.seen_by_human = true
				g.exp_spots.refresh()
				cs = g.exp_spots.shown.map(func(s: Dictionary) -> Vector2i: return s["c"])
				_expect(not cs.has(second["c"]), "a hall overlapping the spot by one column hides it")
				nb.dead = true
				var fb: Building = g._add_building("town_hall", 1, second["c"] + Vector2i(MapGen.HALL.x + 1, 0), true)
				fb.seen_by_human = true
				g.exp_spots.refresh()
				cs = g.exp_spots.shown.map(func(s: Dictionary) -> Vector2i: return s["c"])
				_expect(cs.has(second["c"]), "a hall completely off the spot leaves it shown")
				fb.dead = true
				g.exp_spots.refresh()
			Settings.expansion_spots = false
			g.exp_spots.refresh()
			_expect(g.exp_spots.shown.is_empty(), "the setting off hides them all")
			Settings.expansion_spots = true
			g.exp_spots.refresh()
			_expect(not g.exp_spots.shown.is_empty(), "the setting on shows them again")
		g.queue_free()
		await process_frame
	# watching (spectator / replay): shown even with Brood players
	var w := _make("kestrel_rise", ["brood", "brood"], true)
	await process_frame
	w.exp_spots.refresh()
	_expect(w.exp_spots.shown.size() == w.exp_spots.spots.size() and w.exp_spots.shown.size() > 0, "watching: shown (%d)" % w.exp_spots.shown.size())
	w.queue_free()
	await process_frame
