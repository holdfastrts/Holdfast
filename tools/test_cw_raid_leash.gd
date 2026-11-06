extends SceneTree
## A LONE RIDER DOES NOT TURN THE CLOCKWORK'S ARMY ROUND (ai-followups, docs/ai_followups.md; the owner's Hard Crown OPTIMAL
## v Hard Clockwork game 0.33.0: at 7:05-7:40 the Clockwork's push broke off its attack and its whole army ran after one
## Horseman). Two staged scenes on one map, a Hard Clockwork computer (Balanced) against a Crown whose computer is off:
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_raid_leash.gd -- [map:greenhold] [seed:5] [scene:all|push|home]
##  - PUSH: once the Clockwork's push is out and marching (more than OUT px from its buildings), a Horseman raids its base
##    (by its Clocktower) and another rides round the push, always staying just out of its reach and drawing it back toward
##    the Clockwork's base. Checks: the push does not go home for the raid; its anchor never walks back after the rider more
##    than PUSH_BACK px (the march goes on: it is nearer its goal after FOR s than when the rider came by PROGRESS px, or at it); no front
##    unit is further than STRAY px from the anchor for more than STRAY_T s in a row.
##  - HOME: the army at home (no push out); a Horseman rides into the base by a Cog Press, then rides off across the map
##    away from it. Checks: after FOR s no Clockwork soldier is further than CHASE_MAX px from its nearest building.
const OUT := 900.0
const FOR := 40.0
const PUSH_BACK := 450.0
const PROGRESS := 200.0
const STRAY := 700.0
const STRAY_T := 8.0
const CHASE_MAX := 900.0
var fails := 0
var map := "greenhold"
var seed_ := 5
var scene := "all"


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
			"scene": scene = kv[1]
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


func _home_d(g: Game, p: Vector2) -> float:
	var best := INF
	for b in g.buildings:
		if b.team == 1 and not b.dead and not b.ghost:
			best = minf(best, b.center().distance_to(p))
	return best


func _soldiers(g: Game) -> Array:
	return g.army(1).filter(func(u: Unit) -> bool: return not u.dead and not u.is_worker() and u.has_attack() and not u.is_air())


## A rider that keeps just out of reach of `from` (its nearest enemy soldier), drifting toward `lure`.
func _kite(g: Game, h: Unit, lure: Vector2) -> void:
	if not is_instance_valid(h) or h.dead:
		return
	var near: Unit = null
	for u in _soldiers(g):
		if near == null or u.position.distance_to(h.position) < near.position.distance_to(h.position):
			near = u
	var to := lure
	if near != null and near.position.distance_to(h.position) < 230.0:
		to = h.position + (h.position - near.position).normalized() * 160.0 + (lure - h.position).normalized() * 60.0
	elif near != null and near.position.distance_to(h.position) > 380.0:
		to = near.position + (h.position - near.position).normalized() * 300.0
	h.hp = h.max_hp           # (the test's rider is never caught: it is the bait)
	h.cmd_move(to)


func _scene_push() -> void:
	var r: Array = await _start()
	var main: Node = r[0]
	var g: Game = r[1]
	var ai = r[2]
	var t_out := -1.0
	while g.clock < 720.0 and not g.over:
		await physics_frame
		if ai.push != null and ai.push.phase == "march" and ai.push.units.size() >= 4 and _home_d(g, ai.push._front_centre()) > OUT:
			t_out = g.clock
			break
	check(t_out > 0.0, "the Clockwork's push is out and marching (%s)" % ("at %d s" % int(t_out) if t_out > 0.0 else "never"))
	if t_out < 0.0:
		main.queue_free()
		return
	var push = ai.push
	var hall: Building = g.halls_of(1)[0]
	var home := hall.center()
	var raider: Unit = g._add_unit("cuirassier", 0, home + (push.anchor - home).normalized() * 200.0)
	var dir: Vector2 = (push.anchor - home).normalized()
	var bait: Unit = g._add_unit("cuirassier", 0, push.anchor - dir * 330.0)     # (behind it, toward its home: it draws it back)
	var goal0: Vector2 = push.goal
	var a0: Vector2 = push.anchor
	var d0: float = a0.distance_to(goal0) if goal0 != Vector2.INF else INF
	var back_most := 0.0
	var went_home := false
	var stray_run := {}
	var stray_bad := 0.0
	var t0 := g.clock
	var next := t0
	while g.clock < t0 + FOR and not g.over:
		await physics_frame
		if push.phase == "back" or push.phase == "":
			went_home = true
		if g.clock < next:
			continue
		next += 0.5
		# the raider walks about the Clocktower; the bait draws the push home
		if is_instance_valid(raider) and not raider.dead:
			raider.hp = raider.max_hp
			raider.cmd_move(home + Vector2(randf_range(-150, 150), randf_range(-150, 150)))
		_kite(g, bait, home)
		if push.anchor != Vector2.INF:
			back_most = maxf(back_most, a0.distance_to(home) - push.anchor.distance_to(home))
		for u in push.units:
			if not is_instance_valid(u) or u.dead or not push._front_kind(u):
				continue
			if u.position.distance_to(push.anchor) > STRAY:
				stray_run[u] = float(stray_run.get(u, 0.0)) + 0.5
				stray_bad = maxf(stray_bad, float(stray_run[u]))
			else:
				stray_run[u] = 0.0
	var d1: float = push.anchor.distance_to(goal0) if goal0 != Vector2.INF and push.anchor != Vector2.INF else INF
	print("PUSH %s seed %d: out at %d s; went home %s; anchor walked back %d px; goal %d -> %d px; longest stray %.1f s; riders ignored %d, leashed %d" % [map, seed_, int(t_out),
		str(went_home), int(back_most), int(d0), int(d1), stray_bad, int(push.stats.get("riders", -1)), int(push.stats.get("leashed", -1))])
	check(not went_home, "the push does not go home for one Horseman at its base")
	check(back_most < PUSH_BACK, "the push's anchor does not walk back after the bait (%d px, at most %d)" % [int(back_most), int(PUSH_BACK)])
	check(d1 <= d0 - PROGRESS or d1 < 200.0 or push.goal != goal0, "the march goes on toward its goal (%d -> %d px, at least %d nearer)" % [int(d0), int(d1), int(PROGRESS)])
	check(stray_bad <= STRAY_T, "no front unit chases off from the block for long (%.1f s, at most %d)" % [stray_bad, int(STRAY_T)])
	main.queue_free()
	await process_frame


func _scene_home() -> void:
	var r: Array = await _start()
	var main: Node = r[0]
	var g: Game = r[1]
	var ai = r[2]
	while g.clock < 330.0 and not g.over:
		await physics_frame
	var press: Building = null
	for b in g.buildings:
		if b.team == 1 and b.kind == Defs.GEAR_PRESS and b.built and not b.dead:
			press = b
	var home: Vector2 = g.halls_of(1)[0].center()
	var soldiers := _soldiers(g)
	check(press != null and soldiers.size() >= 2, "a Cog Press and %d soldiers at home at %d s" % [soldiers.size(), int(g.clock)])
	if press == null or soldiers.is_empty():
		main.queue_free()
		return
	var far: Vector2 = Vector2(g.W, g.H) * float(Defs.TILE) - home       # (the far corner from its base)
	var h: Unit = g._add_unit("cuirassier", 0, press.center() + Vector2(60, 0))
	var t0 := g.clock
	var next := t0
	var worst := 0.0
	while g.clock < t0 + FOR + 25.0 and not g.over:
		await physics_frame
		if g.clock < next:
			continue
		next += 0.5
		if is_instance_valid(h) and not h.dead:
			h.hp = h.max_hp
			if g.clock < t0 + 6.0:
				h.cmd_attack(press)
			else:
				h.cmd_move(far)
		if g.clock > t0 + FOR:
			for u in _soldiers(g):
				if ai.push != null and ai.push.has(u):
					continue
				worst = maxf(worst, _home_d(g, u.position))
	print("HOME %s seed %d: %d soldiers at home; the rider rode off at %d s; furthest soldier from its buildings after %d s: %d px; leashed %d" % [map, seed_,
		soldiers.size(), int(t0 + 6.0), int(FOR), int(worst), int(ai.army_g.stats.get("leashed", 0)) if ai.army_g != null else -1])
	check(worst <= CHASE_MAX, "the army gives up the chase: none further than %d px from its buildings (%d)" % [int(CHASE_MAX), int(worst)])
	main.queue_free()
	await process_frame


func _run() -> void:
	if scene == "all" or scene == "push":
		await _scene_push()
	if scene == "all" or scene == "home":
		await _scene_home()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
