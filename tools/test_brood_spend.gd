extends SceneTree
## A banked Brood spends and attacks (the owner's playtests 2026-11-03, docs/raid_micro.md E and F):
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_spend.gd [-- goal] [-- supply]
##  [supply] Thornwood Maze (the owner's seed 3534297060), Hard Crown (Balanced) v Hard Brood (Economy), both computers:
##           on 0.26.2 the Brood sat at 76/76 supply from 6:00 to 12:00 with its food piling up (no room left on the rings
##           round the Mother for a Mound Turtle, and turtles were only laid as expansions). Now it roots SUPPLY TURTLES at
##           home (any legal spot on or beside its swamp): its cap passes 100 by 8:00, and it attacks by 10:00.
##  [goal]   a Brood wave at its goal with nothing left there to fight (the owner's Ashfall FFA: 160/160, 4,000 food,
##           the army stood on the razed Clockwork main for a minute) goes on to the next enemy building it has seen.
const T := 32.0
var fails := 0
var main: Node
var g: Game
var bai


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func wait(s: float) -> void:
	var until := g.clock + s
	while g.clock < until:
		await physics_frame


func _start(map: String, sd: int, crown_on: bool) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(sd)
	main.start({"map": map, "seed": sd, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "economy"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		if a.team == 1:
			bai = a
		elif not crown_on:
			a.process_mode = Node.PROCESS_MODE_DISABLED


func _stop() -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _free(p: Vector2) -> Vector2:
	var c := g.cell_of(p)
	for r in 10:
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var m := Vector2i(x, y)
				if g.in_map(m) and g._walkable(m):
					return (Vector2(m) + Vector2(0.5, 0.5)) * T
	return p


func _case_supply() -> void:
	await _start("thornwood_maze", 3534297060, true)
	var cap_at := {}
	var attacked := -1.0
	var stuck := 0.0                # (seconds at the cap with 1,000+ food and the cap under 160)
	var next := 30.0
	while g.clock < 600.0:
		await wait(1.0)
		var cap := int(g.players[1]["cap"])
		if g.supply_used(1) >= cap - 2 and bai._food() >= 1000 and cap < g.max_supply(1):
			stuck += 1.0
		if attacked < 0.0 and bai._attacking:
			attacked = g.clock
		if g.clock >= next:
			next += 60.0
			cap_at[int(g.clock)] = cap
			print("    t=%.0f supply %d/%d food %d turtles %d attacking %s" % [g.clock, g.supply_used(1), cap, bai._food(), BroodNew.count_of(g, 1, BroodNew.TURTLE), bai._attacking])
	var cap8 := 0
	for k in cap_at:
		if k <= 480:
			cap8 = maxi(cap8, int(cap_at[k]))
	check(cap8 > 100, "[supply] the Economy Brood's supply cap passes 100 by 8:00 (%d; it sat at 76 on 0.26.2)" % cap8)
	check(stuck < 90.0, "[supply] it is not stuck at its cap with food banked (%.0f s)" % stuck)
	check(attacked > 0.0, "[supply] it attacks by 10:00 (first wave at %s; 13:00 on 0.26.2)" % ("%d:%02d" % [int(attacked) / 60, int(attacked) % 60] if attacked > 0.0 else "never"))
	await _stop()


func _case_goal() -> void:
	await _start("greenhold", 5, false)
	await wait(2.0)
	var crown := g.center_of_team(0)
	var q := BroodNew.queen(g, 1)
	var toward := (q.position - crown).normalized()
	# a wave of Raptors on a razed spot 18 tiles out from the Crown's main (nothing there), a Crown Farm it has seen
	var razed := _free(crown + toward * 18.0 * T)
	var wave: Array = []
	for i in 10:
		var r: Unit = g._add_unit("raptor", 1, _free(razed + Vector2(float(i % 5 - 2), float(i / 5)) * 20.0))
		wave.append(r)
	var farm: Building = null
	for b in g.buildings:
		if b.team == 0 and not b.dead and b.kind == "town_hall":
			farm = b
	bai._foe_blds[farm] = farm.center()
	bai._attacking = true
	bai._wave = wave.duplicate()
	bai._wave_target = razed
	bai._wave_v0 = bai._value_of(wave)
	bai._wave_t0 = g.clock
	bai._wave_kills0 = int(g.stats[1]["value_killed"])
	var t0 := g.clock
	var moved := false
	while g.clock < t0 + 8.0:
		await wait(0.5)
		if bai._wave_target.distance_to(farm.center()) < T:
			moved = true
			break
	print("    goal: wave target %s (the hall at %s), notes %s" % [str(bai._wave_target.round()), str(farm.center().round()), str(bai.note.slice(maxi(0, bai.note.size() - 3)))])
	check(moved, "[goal] a wave on a razed goal goes on to the next enemy building it has seen")
	await wait(10.0)
	var c := Vector2.ZERO
	for r in wave:
		c += r.position
	c /= wave.size()
	check(c.distance_to(farm.center()) < razed.distance_to(farm.center()) - 3.0 * T, "[goal] ... and walks there (%.0f -> %.0f px from it)" % [razed.distance_to(farm.center()), c.distance_to(farm.center())])
	await _stop()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("supply"):
		await _case_goal()
	if not args.has("goal"):
		await _case_supply()
	print("brood spend: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(1 if fails > 0 else 0)
