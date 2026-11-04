extends SceneTree
## THE CROWN COMPUTER AGAINST THE BROOD (crown-v-brood, docs/crown_v_brood.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_v_brood.gd [-- maps...]
##  1. THE RAMP WALL CLOSES THE RAMP (the owner's Redrock picture: "a pathetic wall"): on each map the Crown's ramp wall
##     (AI.plan_cottage_wall: the Cottage, the Gate, any palisade) is laid finished; Raptors told to walk from the ramp's
##     foot to the main hall never get onto the main's high ground near it, and a Labourer from the hall walks out
##     through the gate to the ramp's foot (the real path finder and bodies, not the plan's flood fill).
##  2. NO ATTACK WITHOUT A FRESH SCOUT REPORT: against the Brood, an army that has not been seen counts as what a Brood of
##     that age would have (AICrown.foe_estimate > 0 at 8:00 with nothing seen), the wave waits and a scout is asked for
##     when nothing was seen lately (the 7:53 of the owner's log), and the timing never goes on a stale report; a fresh
##     report and a big enough army let it go.
##  3. THE RUSH KEEPS RAIDING WHILE AHEAD: a Horseman rush judged SUCCEEDED against the Brood keeps hunting (mode "hunt");
##     it rides home when the riders are beaten down; against the Crown the shared mop-up as before.
##  4. RANDOM PLAN AGAINST THE BROOD NEVER PICKS THE BALLOON HARASS (2,000 picks); against the Crown it still can.
##  5. A HALL WITH NO WALL PLAN IS ASKED AGAIN QUIETLY (not every think): its failed plan is kept with a retry time.
## Prints PASS / FAIL lines and "crown_v_brood: N failures".
var main: Node
var g: Game
var fails := 0
var maps: Array = ["redrock_canyon", "thornwood_maze", "greenhold", "kestrel_rise", "red_coast"]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		maps = Array(a).filter(func(x) -> bool: return x != "debug")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _start(map: String, foe: String, plan := "economy", fplan := "economy") -> AICrown:
	if main != null:
		main.queue_free()
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(4242)
	main.start({"map": map, "seed": 4242, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": plan},
		{"who": "hard", "faction": foe, "colour": 1, "side": 1, "strategy": fplan}]})
	g = main.game
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	if g.hud:
		g.hud.countdown = 0.0
	await process_frame
	for ai in g.ais:
		if ai.team == 0:
			return ai
	return null


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	var guard := 0
	while g.clock < end and guard < int(sec * 120.0):
		guard += 1
		await physics_frame


func _run() -> void:
	for m in maps:
		await _ramp_wall(m)
	await _blind()
	await _hunt()
	await _random()
	await _no_plan()
	print("crown_v_brood: %d failures" % fails)
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ 1. the ramp wall

func _ramp_wall(map: String) -> void:
	var ai := await _start(map, "brood")
	var bands: Array = ai._ramp_bands()
	var plan: Dictionary = ai.plan_cottage_wall()
	check(not plan.is_empty() and not bands.is_empty(), "%s: a ramp wall plan" % map)
	if plan.is_empty() or bands.is_empty():
		return
	g._add_building("cottage", 0, plan["cottage"], true)
	for e in plan["pieces"]:
		g._add_building(e[0], 0, e[1], true)
	var home := (Vector2(g.starts[0]) + Vector2(2.5, 2.0)) * Defs.TILE
	var hl := int(g.height[g.idx(g.starts[0] + Vector2i(2, 2))])
	# the ramp's foot: a ramp cell's low neighbour, the farthest from home
	var foot := Vector2.INF
	for rc in bands[0]["ramp"]:
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: Vector2i = rc + dd
			if g.in_map(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) < hl and g._walkable(c):
				var p := g.cell_center(c)
				if foot == Vector2.INF or p.distance_to(home) > foot.distance_to(home):
					foot = p
	check(foot != Vector2.INF, "%s: the ramp's foot found" % map)
	if foot == Vector2.INF:
		return
	# the Labourer first (alone: Raptors crowding the gate from below would hold him up)
	var lab: Unit = g._add_unit("labourer", 0, home + Vector2(0, 70))
	lab.cmd_move(foot)
	var out_t := -1.0
	var t0: float = g.clock
	while g.clock - t0 < 30.0 and out_t < 0.0:
		await physics_frame
		if is_instance_valid(lab) and lab.position.distance_to(foot) < 1.5 * Defs.TILE:
			out_t = g.clock - t0
	g.consume_unit(lab)
	var away: Vector2 = (foot - home).normalized()
	var raptors: Array = []
	for i in 6:
		var c: Vector2i = g.nearest_free(g.cell_of(foot + away * (40.0 + 20.0 * (i / 3)) + away.orthogonal() * 22.0 * float(i % 3 - 1)), 6)
		if c.x < 0:
			continue
		var r: Unit = g._add_unit("raptor", 1, g.cell_center(c))
		r.cmd_move(home)
		raptors.append(r)
	var got_in := 0
	t0 = g.clock
	while g.clock - t0 < 30.0:
		await physics_frame
		for r in raptors:
			if is_instance_valid(r) and not r.dead:
				var c: Vector2i = g.cell_of(r.position)
				if g.in_map(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == hl and r.position.distance_to(home) < 12.0 * Defs.TILE:
					got_in += 1
					r.dead = true          # (counted once)
	check(got_in == 0, "%s: no Raptor walks past the ramp wall onto the high ground (%d of %d did)" % [map, got_in, raptors.size()])
	check(out_t >= 0.0, "%s: a Labourer walks out through the gate to the ramp's foot (%s)" % [map, ("%.1f s" % out_t) if out_t >= 0.0 else "never"])


# ------------------------------------------------------------------ 2. no blind attacks

func _blind() -> void:
	var ai := await _start("redrock_canyon", "brood")
	g.clock = 480.0
	ai.ch._last_army_t = -999.0
	ai._base_looked_t = -999.0
	ai.ch._seen.clear()
	var est: float = ai.foe_estimate()
	check(est > 1000.0, "an unseen Brood army at 8:00 is reckoned (%d), not 0" % int(est))
	var army: Array = []
	var home := (Vector2(g.starts[0]) + Vector2(2.5, 2.0)) * Defs.TILE
	for i in 30:
		army.append(g._add_unit("musketeer", 0, home + Vector2(float(i % 6) * 20.0 - 60.0, 90.0 + float(i / 6) * 20.0)))
	var asked0: int = ai.looks_asked
	check(not ai._wave_worth(army), "30 Musketeers do not go out with nothing seen for minutes")
	check(ai.looks_asked > asked0, "... and a scout is asked for")
	ai._attack_at = 999
	ai.ch._two_halls_t = 100.0
	ai.ch._wave_end_t = -999.0
	ai.ch._last_go_t = -999.0
	ai.ch.timing(army)
	check(ai._attack_at == 999, "the timing does not go down on a stale report (attack_at %d)" % ai._attack_at)
	# a fresh look at its main with nothing seen: the reckoning, not 0
	ai._base_looked_t = g.clock
	check(ai.scouted_fresh(), "a look at the enemy main is a fresh report")
	var mine := 0.0
	for u in army:
		mine += float(Game.unit_value(u))
	check(ai._wave_worth(army) == (mine >= ai.foe_estimate() * AICrown.CR_EDGE_BROOD), "a fresh report: the wave goes only worth %.1f times the reckoning (%d v %d)" % [AICrown.CR_EDGE_BROOD, int(mine), int(ai.foe_estimate())])
	for i in 50:
		army.append(g._add_unit("musketeer", 0, home + Vector2(float(i % 8) * 18.0 - 70.0, 200.0 + float(i / 8) * 18.0)))
	check(ai._wave_worth(army), "a fresh report and %d Musketeers: the wave goes" % army.size())
	ai.blind_ok = true
	ai._base_looked_t = -999.0
	check(not ai.blind_guard(), "the switch blind:on plays the old rule")


# ------------------------------------------------------------------ 3. the rush keeps raiding

func _hunt() -> void:
	for foe in ["brood", "crown"]:
		var ai := await _start("thornwood_maze", foe, "rush", "economy")
		var them := (Vector2(g.starts[1]) + Vector2(2.5, 2.0)) * Defs.TILE
		var party: Array = []
		for i in 3:
			var c: Vector2i = g.nearest_free(g.cell_of(them + Vector2(-400.0, float(i) * 30.0)), 8)
			party.append(g._add_unit("cuirassier", 0, g.cell_center(c)))
		g.clock = 200.0
		ai._rush_begin(party, false)
		ai._rush_t0 = 170.0
		ai._wave_value = 300.0
		ai._wave_kill0 = 0
		g.stats[0]["value_killed"] = 345
		var ended: bool = ai._rush_tick(party)
		if foe == "brood":
			check(not ended and ai._rush_mode == "hunt", "against the Brood a SUCCEEDED rush keeps hunting (mode %s, state %s)" % [ai._rush_mode, ai._rush_state])
			for i in 2:
				party[i].dead = true
			var left: Array = party.filter(func(u) -> bool: return not u.dead)
			check(ai._rush_tick(left) and ai._rush_mode == "mop", "the hunt ends when the riders are beaten down (mode %s)" % ai._rush_mode)
		else:
			check(ai._rush_mode != "hunt", "against the Crown the rush mops up as before (mode %s)" % ai._rush_mode)


# ------------------------------------------------------------------ 4. RANDOM PLAN

func _random() -> void:
	for foe in ["brood", "crown"]:
		var ai := await _start("greenhold", foe)
		var allowed: Array = AI.strategies_for("crown")
		var n := {}
		for i in 2000:
			var k: String = ai.random_plan(allowed)
			n[k] = int(n.get(k, 0)) + 1
		if foe == "brood":
			check(int(n.get("balloon", 0)) == 0, "RANDOM PLAN v the Brood never picks the Balloon harass (%s)" % str(n))
		else:
			check(int(n.get("balloon", 0)) > 0, "RANDOM PLAN v the Crown can pick the Balloon harass (%s)" % str(n))


# ------------------------------------------------------------------ 5. no wall plan: asked again quietly

func _no_plan() -> void:
	var ai := await _start("redrock_canyon", "brood")
	var spots: Array = CrownSites.pick(g, 0, [Vector2(g.starts[0]) + Vector2(2.5, 2.0)], 1)
	check(not spots.is_empty(), "a hall spot for the plan test")
	if spots.is_empty():
		return
	var h: Building = g._add_building("town_hall", 0, spots[0]["c"], true)
	var lines0: int = g.mlog.lines.size() if g.mlog else 0
	# a plan that cannot be made (no radius left: R_MAX under R_MIN for this call)
	ai.xw.plans.clear()
	var keep_on: bool = ai.xw.on
	ai.xw.plans[h.get_instance_id()] = {"ok": false, "hall": h, "retry": g.clock + 30.0, "why": "test"}
	for i in 20:
		ai.xw.tick()
	var said := 0
	if g.mlog:
		for i in range(lines0, g.mlog.lines.size()):
			if String(g.mlog.lines[i]).contains("found no wall plan"):
				said += 1
	check(said == 0 and not (ai.xw.plans[h.get_instance_id()] as Dictionary).get("ok", false), "a hall whose plan failed is not asked again every think (%d lines)" % said)
	g.clock += 31.0
	ai.xw.tick()
	check((ai.xw.plans[h.get_instance_id()] as Dictionary).get("ok", false) or float((ai.xw.plans[h.get_instance_id()] as Dictionary).get("retry", 0.0)) > g.clock,
		"... and is asked again after %d s" % int(AIExpandWall_RETRY()))
	ai.xw.on = keep_on


func AIExpandWall_RETRY() -> float:
	return 30.0
