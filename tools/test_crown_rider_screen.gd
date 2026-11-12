extends SceneTree
## THE CROWN'S RIDER SCREEN (crown-rider-screen, docs/crown_rider_screen.md; scripts/ai_crown_screen.gd):
##  1. a MARCHING wave with Horsemen sends some of them AHEAD as a screen: a rider gets well ahead of the wave's head, the
##     screen sees an enemy army before the line meets it (the line forms on the screen's sighting, seconds before contact)
##  2. at contact the riders PULL BACK to the line's flanks and behind it: none stands in front of the muskets
##  3. at home a PICKET stands forward of the army's post on the road toward the enemy, and rides back when a force comes
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_rider_screen.gd
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


func _start(fa: String, fb: String) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(6162)
	main.start({"map": "greenhold", "seed": 6161, "slots": [
		{"who": "hard", "faction": fa, "colour": 0, "side": 0, "strategy": "balanced"},
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


func _spawn(kind: String, t: int, p: Vector2) -> Unit:
	var c: Vector2i = g.nearest_free(g.cell_of(g.on_map(p)), 6)
	return g._add_unit(kind, t, g.cell_center(c))


func _alive(list: Array) -> Array:
	return list.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)


func _run() -> void:
	await _start("crown", "crown")
	await _until(2.0)
	var ai = _ai(0)
	_ai(1).process_mode = Node.PROCESS_MODE_DISABLED
	check(ai.screen() != null and ai.sc.active(), "the Crown computer (Hard) plays the rider screen")
	var sc = ai.sc
	var ln = ai.ln
	ai.ch.scout_on = false      # (the map loop's rider scouts would see the enemy first: the screen is what is tested)
	# 1. THE MARCH: 10 Musketeers, 2 Field Cannons and 3 Horsemen in the open middle, sent as a wave toward the enemy;
	# an enemy force of 8 Musketeers on HOLD 1,100 px ahead (far out of a musket's sight: 256 px)
	var mid := Vector2(Game.W, Game.H) * Defs.TILE * 0.5
	var goal: Vector2 = Vector2(g.starts[1]) * Defs.TILE
	var to_goal: Vector2 = (goal - mid).normalized()
	var start_at: Vector2 = mid - to_goal * 500.0
	var wave: Array = []
	for i in 10:
		wave.append(_spawn("musketeer", 0, start_at + Vector2((i % 5) * 26, (i / 5) * 26)))
	for i in 2:
		wave.append(_spawn("cannon", 0, start_at - to_goal * 60.0 + Vector2(i * 50, 0)))
	var horse: Array = []
	for i in 3:
		var h := _spawn("cuirassier", 0, start_at - to_goal * 30.0 + Vector2(i * 30, 40))
		horse.append(h)
		wave.append(h)
	# the enemy on the road ahead (on the wave's path toward the goal)
	var path: PackedVector2Array = g.find_path(start_at, goal, false, 7.0, 0)
	var foe_at: Vector2 = goal
	var left := 1100.0
	for i in range(1, path.size()):
		var l: float = path[i - 1].distance_to(path[i])
		if l >= left:
			foe_at = path[i - 1] + (path[i] - path[i - 1]).normalized() * left
			break
		left -= l
	var foes: Array = []
	for i in 8:
		var f := _spawn("musketeer", 1, foe_at + Vector2((i % 4) * 26, (i / 4) * 26))
		f.cmd_hold()
		foes.append(f)
	ai.peaceful = true          # (no wave of its own: the test sends this one)
	ai._attacking = true
	ai._wave_set.clear()
	for u in wave:
		ai._wave_set[u] = true
		u.cmd_move(goal, true)
	await _until(g.clock + 1.0)
	if OS.get_cmdline_user_args().has("debug"):
		print("DBG wave=%d attacking=%s rushwave=%s rush=%s picket=%s" % [sc._wave().size(), ai._attacking, ai._rush_wave, ai._rush_state, sc.picket])
		for h in horse:
			print("DBG horse free=%s errand=%s det=%s raid=%s coming=%s order=%s hp=%s in_wave=%s" % [sc._free(h, true), ai._on_errand(h), ai._det.has(h), ai._raiders.has(h), ai._horse_coming(h), h.order, h.hp, ai._wave_set.has(h)])
	var f0: int = ln.forms
	var s0: int = sc.sightings
	var lead_max := 0.0
	var form_t := -1.0
	var contact_t := -1.0
	var contact := func() -> bool:
		for u in _alive(wave):
			if u.kind == "musketeer":
				for o in _alive(foes):
					if o.position.distance_to(u.position) < 215.0:
						return true
		return false
	var t_end: float = g.clock + 90.0
	while g.clock < t_end and not g.over:
		await physics_frame
		# how far the screen rides ahead of the wave's muskets (along the road to the enemy)
		var front := -INF
		for u in _alive(wave):
			if u.kind == "musketeer":
				front = maxf(front, (u.position - start_at).dot(to_goal))
		for r in sc.riders:
			if is_instance_valid(r) and not r.dead:
				lead_max = maxf(lead_max, (r.position - start_at).dot(to_goal) - front)
		if form_t < 0.0 and ln.forms > f0:
			form_t = g.clock
		if contact.call():
			contact_t = g.clock
			break
	print("   the screen said %s" % str(sc.said.slice(0, 4)))
	print("   the line said %s" % str(ln.said.slice(-3)))
	check(sc.sent >= 2, "the wave sends Horsemen ahead as a screen (%d)" % sc.sent)
	check(lead_max > 250.0, "a screen rider rides well ahead of the wave's muskets (%d px)" % int(lead_max))
	check(sc.sightings > s0, "the screen sees the enemy army and the line forms on it (%d)" % (sc.sightings - s0))
	check(form_t > 0.0 and (contact_t < 0.0 or contact_t - form_t >= 4.0),
			"the line formed before contact (formed at %.0f s, contact at %.0f s)" % [form_t, contact_t])
	# 2. AT CONTACT the riders pull back to the line's flanks, out of its fire
	if contact_t > 0.0:
		await _until(g.clock + 7.0)
		var in_fire := 0
		var out := 0
		for r in _alive(horse):
			if sc.riders.has(r):
				out += 1
				if sc._in_fire(r.position, ln) and r.position.distance_to(ln._c) > 40.0:
					in_fire += 1
		print("   at contact +7 s: line %s, %d riders on the screen, %d in front of the muskets; pulled %d" % [ln.st, out, in_fire, sc.pulled])
		check(sc.pulled > 0, "at contact the screen pulls back to the line's flanks (%d)" % sc.pulled)
		check(in_fire == 0, "no rider stands in front of the muskets (%d)" % in_fire)
	check(sc.lost == 0, "no screen rider lost (%d)" % sc.lost)
	sc._release_all("")
	for u in wave + foes:
		if is_instance_valid(u) and not u.dead and not horse.has(u):
			u.take_damage(99999.0, null)
	await _until(g.clock + 1.0)
	ai._attacking = false
	ai._wave_set.clear()
	ln._reset([], goal, "")
	# 3. THE PICKET: at home, a Horseman stands forward of the army's post on the road toward the enemy
	ai.peaceful = false
	ai._attack_at = 99999
	var home: Vector2 = g.halls_of(0)[0].center()
	for h in _alive(horse):
		h.cmd_move(home + Vector2(40, 60))
	await _until(g.clock + 25.0, func() -> bool: return sc.picket != null and sc.picket.position.distance_to(sc._pk["spot"]) < 60.0)
	var post: Vector2 = sc._pk["post"]
	print("   post %s, picket spot %s, picket %s" % [str(post), str(sc._pk["spot"]), str(sc.picket.position if sc.picket else "none")])
	check(sc.picket != null, "a Horseman stands as a picket (%s)" % str(sc.said.slice(-2)))
	if sc.picket != null:
		var d: float = sc.picket.position.distance_to(post)
		var to_foe: float = (Vector2(g.starts[1]) * Defs.TILE).distance_to(sc.picket.position) - (Vector2(g.starts[1]) * Defs.TILE).distance_to(post)
		check(d > 300.0 and to_foe < 0.0, "the picket stands forward of the post toward the enemy (%d px out, %d px nearer the enemy)" % [int(d), int(-to_foe)])
		# a force comes: it rides back
		var pk = sc.picket
		var w0: int = sc.warns.size()
		var ahead: Vector2 = pk.position + (pk.position - post).normalized() * 330.0
		var comers: Array = []
		for i in 5:
			var c := _spawn("musketeer", 1, ahead + Vector2((i % 3) * 26, (i / 3) * 26))
			c.cmd_move(post)
			comers.append(c)
		await _until(g.clock + 6.0, func() -> bool: return sc.warns.size() > w0)
		check(sc.warns.size() > w0, "the picket sees the force coming and warns (%s)" % str(sc.said.slice(-1)))
		await _until(g.clock + 4.0)
		check(is_instance_valid(pk) and not pk.dead and pk.position.distance_to(post) < d - 100.0,
				"the picket rides back toward the post (%d px from it, was %d)" % [int(pk.position.distance_to(post)) if is_instance_valid(pk) else -1, int(d)])
	print("FAILS %d" % fails)
	print("ALL PASS" if fails == 0 else "SOME FAILED")
	quit(1 if fails > 0 else 0)
