extends SceneTree
## THE BALLOON HARASS (scripts/ai_crown_balloon.gd, the Crown computer's Balloon harass plan; docs/crown_builds_c.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_balloon.gd [-- trace]
## A Hard Crown computer on the Balloon harass plan against a Brood that stands still (its computer off): a rooted Rootmaw
## by the Mother with grubs working it. The Crown is given two balloons and eight Musketeers at home.
##  [plan]    the plan is there (a Crown-only strategy with its name) and the harass is made only on it
##  [party]   a party forms (a balloon, 3-4 Musketeers) and the men climb into the basket
##  [strike]  it flies to the Brood's economy and strikes (hover: the basket fires) within STRIKE_BY s, and kills grubs
##  [split]   the second balloon takes the next party to ANOTHER target (SPOT_GAP apart), or waits for men
##  [home]    the harass keeps HOME_KEEP Musketeers at home, and the army's orders leave the parties alone (_on_errand)
##  [aa]      anti-air at the target (four Skywings): the party does not hover over it (it backs off or drops its men away
##            from it) and its balloon is not lost within AA_WATCH s
##  [switch]  the Balanced plan has no harass, and its balloons go on the shared drop as before
const STRIKE_BY := 150.0
const AA_WATCH := 60.0
const T := 32.0
var fails := 0
var main: Node
var g: Game
var ai: AICrown
var q: Unit
var maw: Unit
var grubs: Array = []
var trace := false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	trace = OS.get_cmdline_user_args().has("trace")
	_run.call_deferred()


var _next_trace := 0.0
var _log_seen := 0


func wait(s: float) -> void:
	var until := g.clock + s
	while g.clock < until:
		await physics_frame
		if trace and ai != null and ai.bl != null:
			while _log_seen < ai.bl.log_lines.size():
				print("   %.0f %s" % [float(ai.bl.log_lines[_log_seen][0]), String(ai.bl.log_lines[_log_seen][1])])
				_log_seen += 1
		if trace and g.clock >= _next_trace:
			_next_trace = g.clock + 5.0
			_trace()


func _trace() -> void:
	if ai == null or ai.bl == null:
		return
	for p in ai.bl.parties:
		var b: Unit = p["b"]
		if not is_instance_valid(b):
			continue
		var gd := INF
		for gr in grubs:
			if is_instance_valid(gr) and not gr.dead:
				gd = minf(gd, gr.position.distance_to(b.position))
		print("   t=%.0f party %d %s b=%s %s pass=%d powder %.0f men=%s nearest grub %.0f maw %.0f q %.0f prey %d" % [g.clock, int(p["id"]), String(p["phase"]), str(b.position.round()), b.order, b.passengers.size(), b.powder,
			str((p["men"] as Array).map(func(m) -> String: return "%s/%s/%.0f" % [m.order, "in" if m.aboard else "out", m.powder])), gd,
			maw.position.distance_to(b.position), q.position.distance_to(b.position), ai.bl.prey_seen.size()])


func _start(strategy: String) -> void:
	if main != null:
		main.queue_free()
		await process_frame
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(7)
	main.start({"map": "greenhold", "seed": 7, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": strategy},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
		g.hud.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	ai = null
	_log_seen = 0
	_next_trace = 0.0
	for a in g.ais:
		if a.team == 1:
			a.process_mode = Node.PROCESS_MODE_DISABLED      # (the Brood stands still)
		elif a is AICrown:
			ai = a
	await wait(1.0)
	q = BroodNew.queen(g, 1)
	# a rooted Rootmaw by the Mother, grubs working it
	var home := g.center_of_team(0)
	var side := (home - q.position).normalized().orthogonal()
	maw = g._add_unit(BroodNew.MAW, 1, _root_spot(BroodNew.MAW, q.position + side * 9.0 * T))
	maw.cmd_deploy()
	await wait(float(Defs.NB["turtle_switch"]) + 1.0)
	grubs.clear()
	for i in 5:
		var gr: Unit = g._add_unit("grub", 1, _free(maw.position + side * 2.0 * T + Vector2(float(i - 2) * 20.0, 0)))
		gr.cmd_gather(maw)
		grubs.append(gr)
	for u in g.workers(1):
		if not grubs.has(u):
			grubs.append(u)          # (the Mother's own grubs count too)
	# the Crown: two balloons and eight Musketeers by its hall
	var hall: Building = ai._halls()[0]
	for i in 2:
		g._add_unit("balloon", 0, hall.center() + Vector2(-60 + 120 * i, 120))
	for i in 8:
		g._add_unit("musketeer", 0, _free(hall.center() + Vector2(-90 + 25 * i, 150)))
	await wait(1.0)


func _root_spot(k: String, p: Vector2) -> Vector2:
	for r in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]:
		for i in 16:
			var sp: Vector2 = BroodRoot.snap(k, p + Vector2.from_angle(TAU * i / 16.0) * r * T)
			if BroodRoot.place_problem(g, 1, k, sp, null, false, 1.0, false) == "":
				return sp
	return p


func _free(p: Vector2) -> Vector2:
	var c := g.cell_of(p)
	for r in 8:
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var m := Vector2i(x, y)
				if g.in_map(m) and g._walkable(m):
					return (Vector2(m) + Vector2(0.5, 0.5)) * T
	return p


func _grub_loss() -> float:
	var lost := 0.0
	for gr in grubs:
		lost += 46.0 if (not is_instance_valid(gr) or gr.dead) else gr.max_hp - gr.hp
	return lost


func _run() -> void:
	# [plan]
	check(AI.strategies_for("crown").has("balloon") and not AI.strategies_for("brood").has("balloon") and not AI.strategies_for("clockwork").has("balloon"),
		"[plan] Balloon harass is a Crown-only strategy")
	check(AICrown.PLANS.has("balloon") and String(AI.STRATEGIES["balloon"]["name"]) == "Balloon harass", "[plan] its plan and name are there")
	await _start("balloon")
	check(ai != null and ai.bl != null, "[plan] the harass is made on its plan")
	if ai == null or ai.bl == null:
		_end()
		return
	var bl = ai.bl
	# [party]
	var formed := -1.0
	var boarded := -1.0
	var until := g.clock + 40.0
	while g.clock < until and boarded < 0.0:
		await wait(1.0)
		if formed < 0.0 and not bl.parties.is_empty():
			formed = g.clock
		for p in bl.parties:
			if (p["b"] as Unit).passengers.size() >= 3:
				boarded = g.clock
	check(formed >= 0.0, "[party] a party formed (%.0f s)" % formed)
	check(boarded >= 0.0, "[party] three Musketeers or more climbed into the basket (%.0f s)" % boarded)
	# [home]
	var home_musk := g.army(0).filter(func(u: Unit) -> bool: return u.kind == "musketeer" and not bl.has(u)).size()
	check(home_musk >= bl.HOME_KEEP, "[home] %d Musketeers or more kept at home (%d)" % [bl.HOME_KEEP, home_musk])
	var errand := true
	for p in bl.parties:
		if not ai._on_errand(p["b"]):
			errand = false
	check(errand, "[home] the army's orders leave the parties' balloons alone (_on_errand)")
	# [strike]
	var t0 := g.clock
	var lost0 := _grub_loss()
	until = g.clock + STRIKE_BY
	while g.clock < until and (bl.first_strike < 0.0 or _grub_loss() - lost0 < 1.0):
		await wait(1.0)
	await wait(20.0)
	check(bl.first_strike >= 0.0 and bl.first_strike - t0 <= STRIKE_BY, "[strike] a party struck within %d s (%.0f s)" % [int(STRIKE_BY), bl.first_strike - t0])
	check(_grub_loss() - lost0 >= 46.0, "[strike] ... and the grubs lost health (%.0f)" % (_grub_loss() - lost0))
	print("   harass: %s" % bl.summary())
	# [split]
	var targets: Array = []
	for p in bl.parties:
		if p["at"] != Vector2.INF and String(p["phase"]) != "load":
			targets.append(p["at"])
	var apart := targets.size() < 2 or (targets[0] as Vector2).distance_to(targets[1]) >= 200.0
	check(apart, "[split] two parties out go to different targets (%s)" % str(targets))
	# [aa]
	await _start("balloon")
	bl = ai.bl
	var sky: Array = []
	for i in 4:
		var s: Unit = g._add_unit("skywing", 1, _free(q.position + Vector2(float(i - 2) * 30.0, -60.0)))
		s.cmd_hold()
		sky.append(s)
	var hovered_over := 0.0
	var lost_b := 0
	until = g.clock + 40.0 + AA_WATCH
	while g.clock < until:
		await wait(0.5)
		for p in bl.parties:
			var b: Unit = p["b"]
			if is_instance_valid(b) and not b.dead and String(p["phase"]) == "strike":
				for s2 in sky:
					if is_instance_valid(s2) and not s2.dead and s2.position.distance_to(b.position) < 220.0:
						hovered_over += 0.5
						break
	lost_b = bl.lost_balloons
	print("   harass with anti-air: %s" % bl.summary())
	check(hovered_over <= 3.0, "[aa] no party hovered over the Skywings (%.1f s)" % hovered_over)
	check(lost_b == 0, "[aa] no balloon lost to them (%d)" % lost_b)
	# [switch]
	await _start("balanced")
	check(ai.bl == null, "[switch] the Balanced plan has no balloon harass")
	_end()


func _end() -> void:
	print("test_crown_balloon: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
