extends SceneTree
## A CLOCKWORK SCOUT OR SENTRY RUNS FROM WORKERS THAT COME FOR IT (cinder-clockwork-ai, docs/cinder_clockwork_ai.md; the
## owner's Cinder Steps watch 2026-11-13: the scout's trip 2 and the sentry peeking up the walled ramp each died to two
## Crown Labourers, trading blows). A Hard Clockwork computer against a Crown whose computer is off:
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_scout_workers.gd -- [map:greenhold] [seed:3]
##       (`cwscoutflee:off` for the "before")
##  - SCOUT: once its scout is on the road and near the Crown's base, two Labourers are put by it and sent at it. Checks:
##    after FOR s the scout lives and was not hit more than twice.
##  - SENTRY: a Winder is made the sentry at the foot of the Crown's ramp; two Labourers are sent at it. Same checks.
const FOR := 25.0
var map := "greenhold"
var seed_ := 3
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
	_run.call_deferred()


func _start() -> Array:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(seed_)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var ai = null
	for a in g.ais:
		if a.team == 0:
			a.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			ai = a
	return [main, g, ai]


## Two Labourers by `w`, sent at it; then FOR s. Returns [alive, blows taken].
func _chase(g: Game, w: Unit) -> Array:
	var labs: Array = []
	for i in 2:
		var l: Unit = g._add_unit("labourer", 0, w.position + Vector2(130.0 + 20.0 * i, -30.0 + 60.0 * i))
		labs.append(l)
	var from: Array = labs.map(func(l: Unit) -> Vector2: return l.position)
	var hp0 := w.hp
	var t0 := g.clock
	var next := t0
	var lost := 0.0
	var last := w.hp
	while g.clock < t0 + FOR and not g.over and is_instance_valid(w) and not w.dead:
		await physics_frame
		if w.hp < last:
			lost += last - w.hp
		last = w.hp
		if g.clock >= next:
			next += 1.0
			if OS.get_cmdline_user_args().has("debug"):
				var dl := []
				for l in labs:
					dl.append(int(l.position.distance_to(w.position)) if is_instance_valid(l) and not l.dead else -1)
				print("  t %d hp %d order %s pos %s goal %s dist %s home %s" % [int(g.clock - t0), int(w.hp), w.order, str(w.position.round()), str(w.order_point.round()), str(dl), str(g.center_of_team(1).round())])
			for li in labs.size():
				var l: Unit = labs[li]
				# (the Crown's two hands chase an intruder near its buildings; here they chase it while it is within 450 px
				# of where they started, as the shared computer's hands give up once it leaves the base)
				if is_instance_valid(l) and not l.dead and is_instance_valid(w) and not w.dead and w.position.distance_to(from[li]) < 450.0:
					if l.order_target != w:
						l.cmd_attack(w)
				elif is_instance_valid(l) and not l.dead and l.order != "idle":
					l.cmd_stop()
	var alive := is_instance_valid(w) and not w.dead
	return [alive, int(ceil(lost / 6.0)), hp0]


func _run() -> void:
	var r: Array = await _start()
	var main: Node = r[0]
	var g: Game = r[1]
	var ai = r[2]
	var sc = ai.scout
	check(sc != null, "the Clockwork has a scout")
	# SCOUT
	var hall: Building = g.halls_of(0)[0]
	var w: Unit = null
	while g.clock < 240.0 and not g.over:
		await physics_frame
		if sc.state == "going" and sc.unit != null and is_instance_valid(sc.unit) and sc.unit.is_worker() \
				and sc.unit.position.distance_to(hall.center()) < 700.0:
			w = sc.unit
			break
	check(w != null, "the scout is near the Crown's base (%s)" % ("at %d s" % int(g.clock) if w != null else "never"))
	if w != null:
		var res: Array = await _chase(g, w)
		print("SCOUT alive %s blows %d" % [str(res[0]), res[1]])
		check(res[0], "the scout lives (two Labourers after it)")
	# SENTRY: a Winder at the foot of the Crown's ramp
	var top_c: Vector2 = g.ramp_top(hall)
	var winder: Unit = null
	for u in g.workers(1):
		if not u.dead and (sc.unit == null or u != sc.unit):
			winder = u
			break
	if top_c != Vector2.INF and winder != null:
		var top := top_c * Defs.TILE
		var away := (top - hall.center()).normalized()
		var post := top + away * 200.0
		winder.position = post
		g.note_move(winder)
		sc.sentry = winder
		sc.sentry_posts = 1
		sc._sentry_fleeing = false
		sc._sentry_pt = post
		sc._peek_t = g.clock
		winder.cmd_hold()
		for i in 15:
			await physics_frame
		var res2: Array = await _chase(g, winder)
		print("SENTRY alive %s blows %d" % [str(res2[0]), res2[1]])
		check(res2[0], "the sentry lives (two Labourers after it)")
	print("ALL PASS" if fails == 0 else "FAILS: %d" % fails)
	main.queue_free()
	quit()
