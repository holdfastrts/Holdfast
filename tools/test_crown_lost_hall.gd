extends SceneTree
## NO HALL INTO THE ENEMY THAT JUST TOOK ONE (crown-ai-v2, docs/crown_ai_v2.md; the QA study's item 3: the beaten Crown laid
## new halls on the spot it had just lost while the enemy was still there). A Hard Crown computer (Economy) against a Brood
## whose computer is off, on Greenhold, with gold to spare:
##  1. its natural (the second hall) is razed with Raptors standing by it: the computer notes the loss (AICrown.lost_halls,
##     the match log line, the AI STORY's)
##  2. for WATCH s no hall of its, built or a site, goes down within LOST_NEAR tiles of the lost spot (the shared paths too:
##     _more_halls, the natural's spot), though it has the gold
##  3. a hall asked for on that spot straight (AI._construct) is refused
##  4. REBUILD ONCE: with its main the only hall and a fight at it, no new expansion is laid
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_lost_hall.gd [-- map:greenhold]
const WATCH := 120.0
var main: Node
var g: Game
var ai = null
var fails := 0
var map := "greenhold"


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
	_run.call_deferred()


func _until(clock: float, cond := Callable()) -> void:
	while g.clock < clock and not g.over:
		await physics_frame
		if cond.is_valid() and cond.call():
			return


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(4243)
	main.start({"map": map, "seed": 4243, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "economy"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		if a.team == 1:
			a.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			ai = a
	var home := Vector2(g.starts[0]) * Defs.TILE
	var found: Array = []         # (a lambda captures locals by value: the hall goes into an array)
	await _until(420.0, func() -> bool:
		for h in g.halls_of(0, true):
			if h.center().distance_to(home) > 10.0 * Defs.TILE:
				found.append(h)
				return true
		return false)
	var nat: Building = found[0] if not found.is_empty() else null
	check(nat != null, "the Crown's natural stands (%d s)" % int(g.clock))
	if nat == null:
		_end()
		return
	var cell: Vector2i = nat.cell
	var at := nat.center()
	var raptors: Array = []
	for i in 8:
		raptors.append(g._add_unit("raptor", 1, at + Vector2(-80 + (i % 4) * 50, 110 + (i / 4) * 40)))
	nat.take_damage(9999999.0, null)
	await _until(g.clock + 3.0)
	print("   natural at %s razed at %d s; %d Raptors there" % [str(cell), int(g.clock), raptors.size()])
	check(int(ai.lost_halls) >= 1, "the loss is noted (lost_halls %d)" % int(ai.lost_halls))
	var said := false
	if g.mlog:
		for l in g.mlog.lines:
			if String(l).contains("lost a Town Hall"):
				said = true
	check(said, "the match log says it lost a Town Hall (and the AI STORY tells it)")
	check(ai.lost_ground(cell), "that ground counts as lost")
	# 2. gold to spare, and nothing goes back down there
	var near_sites := 0
	var t_end := g.clock + WATCH
	while g.clock < t_end and not g.over:
		await physics_frame
		if int(g.clock * 30.0) % 15 != 0:
			continue
		if int(g.players[0]["gold"]) < 900:
			g.players[0]["gold"] = 900
		for h in g.halls_of(0, false):
			if (Vector2(h.cell) - Vector2(cell)).length() < ai.LOST_NEAR:
				near_sites += 1
				print("   a hall at %s %d s (built %s)" % [str(h.cell), int(g.clock), str(h.built)])
				h.die()
	check(near_sites == 0, "no hall laid within %d tiles of the lost spot for %d s with the gold to spare (%d)" % [int(ai.LOST_NEAR), int(WATCH), near_sites])
	# 3. asked straight
	var before: int = ai.lost_refused
	g.players[0]["gold"] = 900
	ai._construct(g.faction_hall(0), cell)
	var there := g.halls_of(0, false).filter(func(h: Building) -> bool: return h.cell == cell).size()
	check(there == 0 and int(ai.lost_refused) > before, "a hall asked for on the lost spot is refused (refused %d)" % (int(ai.lost_refused) - before))
	# 4. REBUILD ONCE: the main alone, a fight at it: no expansion
	for h in g.halls_of(0, false):
		if h.center().distance_to(home) > 10.0 * Defs.TILE:
			h.die()
	var mh: Building = null
	for h in g.halls_of(0, true):
		mh = h
	var keep_ok := false
	if mh != null:
		for i in 12:
			g._add_unit("raptor", 1, mh.center() + Vector2(150 + (i % 4) * 25, 90 + (i / 4) * 25))
		await _until(g.clock + 1.5)
		keep_ok = ai.rebuild_keep() and ai._safe_hall_spot() == Vector2i(-1, -1)
		print("   main alone: halls %d, a fight at it %s, rebuild_keep %s" % [g.halls_of(0, false).size(), str(ai._unsafe(mh.center())), str(ai.rebuild_keep())])
	check(keep_ok, "its last hall in a fight: the gold stays to rebuild once (no expansion spot given)")
	_end()


func _end() -> void:
	print("RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
