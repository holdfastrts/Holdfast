extends SceneTree
## AI round 6 (docs/ai_round6.md): the Clockwork computer's army does not sit at home for good.
##  [threat] a Clocktower of its own stands by the enemy's main with three enemy Labourers beside it (any enemy unit near
##           any of its buildings was a "threat": the whole army stayed in defence, 0.14.100 Kestrel Rise 12:17-20:00).
##           A big army still goes out (since clockwork-army: the push's block).
##  [ahead]  after a pull-back the bar for the next wave is high (999 here); an army far bigger than anything it has seen
##           goes out anyway (the push ignores the old wave bar).
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_round6_stall.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _case(kind: String, on: bool) -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(14)
	main.start({"map": "kestrel_rise", "seed": 14, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var cw = null
	for a in g.ais:
		if a.team == 0:
			a.process_mode = Node.PROCESS_MODE_DISABLED      # (the Crown stands still: the test's prop)
		else:
			cw = a
	cw.r6 = on
	cw.r6_cw = on
	cw.r6_cr = on
	while g.clock < 3.0:
		await physics_frame
	var hall: Building = g.halls_of(1)[0]
	var front: Vector2 = cw._rally_front(hall)
	for i in 40:
		g._add_unit("clock_soldier", 1, front + Vector2(randf_range(-80, 80), randf_range(-80, 80)))
	if kind == "threat":
		# a Clocktower of the Clockwork's on the Crown's natural, three Crown Labourers by it
		var c: Vector2i = g.expansions[0]
		var b := g._add_building("clocktower", 1, c, true)
		for i in 3:
			var lab: Unit = g._add_unit("labourer", 0, b.center() + Vector2(90 + i * 20, 60))
			lab.process_mode = Node.PROCESS_MODE_DISABLED      # (they stand there, as the Crown's farmers did under its cliff)
	else:
		cw._attack_at = 999
	var went := false
	while g.clock < 240.0:      # (was 60 s: since clockwork-army the push first waits for a fresh scout report, AICwArmy.may_launch)
		await physics_frame
		# (since clockwork-army, 0.29.x, every Clockwork plan attacks with the push's block (scripts/ai_cw_push.gd) and the old
		# wave flag stays off: the push launching is "the army goes out")
		if cw._attacking or (cw.push != null and cw.push.launched):
			went = true
			break
	print("  %s r6 %s: threat %s, attack_at %d, army supply %d, attacking %s" % [kind, str(on), str(cw._threat()), cw._attack_at, cw._army_supply(g.army(1)), str(went)])
	main.queue_free()
	await process_frame
	await process_frame
	return went


func _run() -> void:
	# (the "before round 6 it stays home" half is gone: the old wave logic it compared against no longer runs the
	# Clockwork's attacks since clockwork-army; the push goes out whatever the round 6 switches say)
	for kind in ["threat", "ahead"]:
		var after: bool = await _case(kind, true)
		check(after, "[%s] the army goes out (the push launches within 240 s)" % kind)
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
