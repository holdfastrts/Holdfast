extends SceneTree
## THE SIEGE PUSH (crown-builds-b; scripts/ai_crown_siege.gd, docs/crown_builds_b.md).
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_siege.gd
##  [plan]    "siege" is a Crown plan (AI.STRATEGIES, AICrown.PLANS), not a Brood or Clockwork one; a Hard Crown on it has the
##            push (AICrown.siege) and the shared waves never go
##  [open]    on its plan against a Brood that stands still: the second hall, the Breeder and the Foundry are up and the
##            first gun is trained by OPEN_BY
##  [march]   a push (12 Musketeers, 2 Field Cannons, a Mortar, the Powder Wagon) sent at a Clockwork base that stands still
##            with two Ratchet Turrets: on the march the guns are limbered and behind the line
##  [set]     it sets up: the line on HOLD, the guns unlimbered out of the turrets' reach (TURRET_SAFE)
##  [break]   the guns shoot the turrets first: both down by BREAK_BY s, no gun lost
##  [wagon]   the Powder Wagon is never among the line (WAGON_GAP of a Musketeer at most WAGON_BAD of the time)
##  [back]    a big enemy army comes at it: the push falls back, the guns go home
const T := 32.0
const OPEN_BY := 540.0
const BREAK_BY := 120.0
const TURRET_SAFE := 215.0      # (px) from a turret's middle: its reach (200) and a little
const WAGON_GAP := 110.0        # (px) the wagon's blast radius (Defs.WAGON radius)
const WAGON_BAD := 0.1
var fails := 0
var main: Node
var g: Game
var ai: AICrown


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


func _start(foe: String, foe_plan: String, map: String, seed_: int) -> void:
	if main != null:
		main.queue_free()
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(seed_)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "siege"},
		{"who": "hard", "faction": foe, "colour": 1, "side": 1, "strategy": foe_plan}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
		g.hud.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	ai = null
	for a in g.ais:
		if a.team == 1:
			a.process_mode = Node.PROCESS_MODE_DISABLED      # (the enemy stands still)
		elif a is AICrown:
			ai = a


func _free(p: Vector2) -> Vector2:
	var c := Vector2i(p / T)
	for r in 12:
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var m := Vector2i(x, y)
				if g.in_map(m) and g._walkable(m):
					return (Vector2(m) + Vector2(0.5, 0.5)) * T
	return p


func _gun(k: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(k, 0, _free(p))
	u.harnessed = true
	return u


func _run() -> void:
	# [plan]
	check(AI.strategies_for("crown").has("siege") and not AI.strategies_for("brood").has("siege") and not AI.strategies_for("clockwork").has("siege"),
		"[plan] Siege push is a Crown plan only")
	check(AICrown.PLANS.has("siege") and bool(AICrown.PLANS["siege"].get("siege", false)), "[plan] AICrown.PLANS has the siege plan")
	await _start("brood", "economy", "greenhold", 3)
	check(ai != null and ai.siege != null and ai.siege_on(), "[plan] a Hard Crown on Siege push has its push (AICrown.siege)")
	if ai == null or ai.siege == null:
		_end()
		return
	check(not ai._wave_worth([]), "[plan] the shared waves never go (the push does)")
	# [open]
	var gun_t := -1.0
	while g.clock < OPEN_BY:
		await wait(5.0)
		if gun_t < 0.0 and g.army(0).any(func(u: Unit) -> bool: return u.kind in ["cannon", "mortar"]):
			gun_t = g.clock
	var found := ai._mine("foundry").filter(func(b: Building) -> bool: return b.built).size()
	print("   build order log: %s" % str(ai.bo_log.map(func(e) -> String: return "%d %s" % [int(e[0]), e[1]])))
	check(ai._halls().size() >= 2 and not ai._mine("horse_breeder").is_empty() and found >= 1,
		"[open] the second hall, the Breeder and the Foundry by %d s (halls %d, Foundry %d)" % [int(OPEN_BY), ai._halls().size(), found])
	check(gun_t >= 0.0, "[open] the first gun trained by %d s (%d s)" % [int(OPEN_BY), int(gun_t)])
	# [march] [set] [break] [wagon] against two turrets at a Clockwork base
	await _start("clockwork", "balanced", "greenhold", 3)
	await wait(1.0)
	var sg: AICrownSiege = ai.siege
	var tower: Building = null
	for b in g.buildings:
		if b.team == 1 and b.kind == "clocktower":
			tower = b
	var home: Vector2 = g.center_of_team(0)
	var tc: Vector2 = tower.center()
	var dir: Vector2 = (home - tc).normalized()
	var turrets: Array = []
	for side in [-1.0, 1.0]:
		var p: Vector2 = tc + dir * 6.0 * T + Vector2(-dir.y, dir.x) * side * 3.5 * T
		var c := Vector2i(_free(p) / T)
		turrets.append(g._add_building(Defs.CW_TURRET, 1, c, true))
	await wait(1.0)
	var start: Vector2 = _free(tc + dir * 24.0 * T)
	var men: Array = []
	for i in 12:
		men.append(g._add_unit("musketeer", 0, _free(start + Vector2((i % 4) * 22.0, (i / 4) * 22.0))))
	var guns: Array = [_gun("cannon", start + dir * 90.0), _gun("cannon", start + dir * 90.0 + Vector2(40, 0)), _gun("mortar", start + dir * 120.0)]
	var wagon: Unit = _gun("powder_wagon", start + dir * 200.0)
	await wait(0.5)
	var push: Array = men + guns
	sg._go(push, 1500.0)
	var march_ok := 0
	var march_n := 0
	var set_t := -1.0
	var safe_bad := ""
	var wagon_bad := 0
	var wagon_n := 0
	var broke_t := -1.0
	var t0 := g.clock
	while g.clock - t0 < BREAK_BY + 30.0:
		await wait(0.5)
		var alive_men := men.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
		var alive_guns := guns.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
		if sg.state == "march" and set_t < 0.0 and not alive_men.is_empty() and not alive_guns.is_empty():
			march_n += 1
			var lm := sg._mid(alive_men)
			var gm := sg._mid(alive_guns)
			if alive_guns.all(func(u: Unit) -> bool: return u.tesla_mode == "packed") and gm.distance_to(tc) > lm.distance_to(tc) - 20.0:
				march_ok += 1
		if sg.state == "set" and set_t < 0.0:
			set_t = g.clock
		if set_t >= 0.0:
			for gu in alive_guns:
				if gu.tesla_mode == "deployed":
					for tu in turrets:
						if is_instance_valid(tu) and not tu.dead and gu.position.distance_to(tu.center()) < TURRET_SAFE:
							safe_bad = "%s at %d px from a turret" % [gu.kind, int(gu.position.distance_to(tu.center()))]
			if is_instance_valid(wagon) and not wagon.dead:
				wagon_n += 1
				if alive_men.any(func(u: Unit) -> bool: return u.position.distance_to(wagon.position) < WAGON_GAP):
					wagon_bad += 1
		if broke_t < 0.0 and turrets.all(func(b) -> bool: return not is_instance_valid(b) or b.dead):
			broke_t = g.clock - t0
			break
	check(march_n > 0 and march_ok >= march_n * 0.8, "[march] the guns limbered behind the line on the march (%d of %d looks)" % [march_ok, march_n])
	check(set_t >= 0.0, "[set] it set up (%s)" % str(sg.log.map(func(e) -> String: return "%d %s" % [int(e[0]), e[1]])))
	var on_hold := men.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and u.order == "hold").size()
	check(safe_bad == "", "[set] the guns fired from out of the turrets' reach %s" % safe_bad)
	check(broke_t >= 0.0 and broke_t <= BREAK_BY, "[break] both turrets down by %d s (%d s)" % [int(BREAK_BY), int(broke_t)])
	check(guns.all(func(u) -> bool: return is_instance_valid(u) and not u.dead), "[break] ... with no gun lost (%d left)" % guns.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead).size())
	print("   the line on HOLD when the turrets fell: %d" % on_hold)
	check(wagon_n > 0 and float(wagon_bad) <= float(wagon_n) * WAGON_BAD, "[wagon] the wagon kept out of the line (%d of %d looks within %d px)" % [wagon_bad, wagon_n, int(WAGON_GAP)])
	# [back] a big army comes at it
	if sg.state != "":
		var mid := sg._mid(sg.men.keys())
		for i in 40:
			var u: Unit = g._add_unit("clock_soldier", 1, _free(mid - dir * 260.0 + Vector2((i % 8) * 20.0 - 80.0, (i / 8) * 20.0)))
			u.cmd_move(mid, true)
		var back_t := -1.0
		var t1 := g.clock
		while g.clock - t1 < 40.0:
			await wait(0.5)
			if sg.state == "back" or sg.state == "":
				back_t = g.clock - t1
				break
		check(back_t >= 0.0, "[back] it fell back when a big army came (%s s: %s)" % [str(int(back_t)), str(sg.log.back() if not sg.log.is_empty() else "")])
		await wait(8.0)
		var hm: Vector2 = ai._front()
		var gl := guns.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
		check(gl.is_empty() or gl.all(func(u: Unit) -> bool: return u.order == "move" and u.order_point.distance_to(hm) < 120.0 or u.position.distance_to(hm) < 200.0),
			"[back] ... its guns go home (%d alive)" % gl.size())
	else:
		check(false, "[back] the push was still out to test its retreat")
	_end()


func _end() -> void:
	print("test_crown_siege: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
