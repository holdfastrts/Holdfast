extends SceneTree
## THE CROWN MIRROR (crown-v-crown-coach, docs/crown-v-crown-coach.md; scripts/ai_crown_mirror.gd):
##  1. AICrown.mirror() is on for a Crown computer against a Crown, off against the Brood and the Clockwork
##  2. THE RAIDER GETS AN ANSWER: an enemy Horseman among the labourers of a Crown with a Barracks and no soldier: a
##     Musketeer is queued within a few seconds
##  3. THE WAVE MARCHES AS ONE: a wave of 10 Musketeers strung out over the open ground closes up (the log's line, the
##     spread under SPREAD_MAX) before it goes on
##  4. THE TIMING KEEPS ITS TIMING: OPTIMAL's late greedy read keeps the Timing attack in the mirror
##  5. THE WINNER FINISHES: hunt_anyway over a token army only with a big army of its own; hunt_goal is a hall
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_mirror.gd
var main: Node
var g: Game
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _until(clock: float, cond := Callable()) -> void:
	while g.clock < clock and not g.over:
		await physics_frame
		if cond.is_valid() and cond.call():
			return


func _start(fa: String, fb: String, plan := "balanced") -> void:
	if main != null:
		main.queue_free()
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(5151)
	main.start({"map": "greenhold", "seed": 5151, "slots": [
		{"who": "hard", "faction": fa, "colour": 0, "side": 0, "strategy": plan},
		{"who": "hard", "faction": fb, "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false


func _ai(t: int):
	for a in g.ais:
		if a.team == t:
			return a
	return null


func _run() -> void:
	# 1. on in the mirror only
	for fb in ["brood", "clockwork"]:
		await _start("crown", fb)
		await _until(2.0)
		check(_ai(0).mirror() == null, "no mirror play against the %s" % fb)
	await _start("crown", "crown")
	await _until(2.0)
	check(_ai(0).mirror() != null and _ai(1).mirror() != null, "both Crowns play the mirror against a Crown")
	var ai = _ai(0)
	_ai(1).process_mode = Node.PROCESS_MODE_DISABLED
	# 2. the raider: a Horseman among the labourers once a Barracks stands
	await _until(400.0, func() -> bool: return ai._mine("barracks").any(func(b) -> bool: return b.built))
	check(ai._mine("barracks").any(func(b) -> bool: return b.built), "a Barracks stands (%d s)" % int(g.clock))
	for u in g.army(0):
		u.take_damage(99999.0, null)        # (no soldier to meet the raider)
	g.players[0]["gold"] = int(g.players[0]["gold"]) + 600
	var w: Unit = g.workers(0)[0]
	var horse: Unit = g._add_unit("cuirassier", 1, w.position + Vector2(60, 0))
	horse.cmd_hold()
	var t0 := g.clock
	await _until(t0 + 12.0, func() -> bool:
		return ai._mine("barracks").any(func(b) -> bool: return b.queue.has("musketeer")) or g.army(0).any(func(u) -> bool: return u.kind == "musketeer"))
	check(ai._mine("barracks").any(func(b) -> bool: return b.queue.has("musketeer")) or g.army(0).any(func(u) -> bool: return u.kind == "musketeer"),
		"a Musketeer is queued for the raider (%.1f s)" % (g.clock - t0))
	if is_instance_valid(horse) and not horse.dead:
		horse.take_damage(99999.0, null)
	# 4. the timing keeps its timing
	if ai.opt != null:
		ai.opt.current = "timing"
		var keep: Array = ai.opt._punish("crown", 400.0)
		check(keep.is_empty(), "a late greedy read keeps the Timing attack in the mirror (%s)" % str(keep))
		ai.opt.current = "balanced"
		check(not ai.opt._punish("crown", 400.0).is_empty(), "... and still picks for another plan")
	# 5. the hunt: a token army against a big one, a small one against a small one
	var mine: Array = []
	for i in 20:
		mine.append(g._add_unit("musketeer", 0, Vector2(g.starts[0]) * Defs.TILE + Vector2(0, 200)))
	var cm = ai.mirror()
	check(cm.hunt_anyway(1, mine), "a hunt goes on over a token enemy army (20 Musketeers against none)")
	check(not cm.hunt_anyway(1, mine.slice(0, 4)), "not with a small army of its own")
	var goal: Vector2 = cm.hunt_goal(1, Vector2(g.starts[0]) * Defs.TILE)
	check(g.halls_of(1).any(func(h) -> bool: return h.center().distance_to(goal) < 4.0), "the hunt goes for a hall")
	for u in mine:
		u.take_damage(99999.0, null)
	# 3. the march: 10 Musketeers strung out in a line across the open middle, sent as a wave
	var mid := Vector2(Game.W, Game.H) * Defs.TILE * 0.5
	var wave: Array = []
	for i in 10:
		var p: Vector2 = g.on_map(mid + Vector2(-340 + i * 76, 0))
		var c: Vector2i = g.nearest_free(g.cell_of(p), 4)
		wave.append(g._add_unit("musketeer", 0, g.cell_center(c)))
	await _until(g.clock + 1.0)
	ai._attacking = true
	ai._wave_set.clear()
	for u in wave:
		ai._wave_set[u] = true
		u.cmd_move(Vector2(g.starts[1]) * Defs.TILE, true)
	var said0: int = cm.said.size()
	await _until(g.clock + 30.0, func() -> bool: return cm.said.size() > said0)
	var lines: Array = cm.said.slice(said0).map(func(x) -> String: return String(x[1]))
	check(lines.any(func(l: String) -> bool: return l.contains("close up")), "the strung-out wave closes up (%s)" % str(lines))
	for kk in 4:
		await _until(g.clock + 3.0)
		print("   t %.0f regroup %s attacking %s: %s" % [g.clock, str(cm.regrouping()), str(ai._attacking), str(wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead).map(func(u) -> String: return "%s@%d,%d" % [u.order, int(u.position.x / 32), int(u.position.y / 32)]))])
	await _until(g.clock + 16.0, func() -> bool: return not cm.regrouping())
	var last: String = String(cm.said[-1][1]) if not cm.said.is_empty() else ""
	var sp := 99.0
	var k := last.find("together (")
	if k >= 0:
		sp = float(last.substr(k + 10).split(" ")[0])
	check(sp < cm.SPREAD_MAX, "it went on together: %s" % last)
	print("FAILS %d" % fails)
	print("ALL PASS" if fails == 0 else "SOME FAILED")
	quit(1 if fails > 0 else 0)
