extends SceneTree
## THE BROOD COMPUTER DEFENDS AS A SWARM (docs/brood_ai_swarm.md; the owner's playtest of 2026-11-01). A Hard Brood
## computer (Economy) on Glimmerdeep against a Clockwork whose computer is switched off; Clock Soldiers are put down by
## hand. Each part:
##   swarm    12 Raptors at home, 5 Clock Soldiers come in: the whole lot goes AT ONCE (every Raptor sent within one
##            think of the first), the soldiers die; idle Raptors HOLD at the rally before and after
##   mother   2 Clock Soldiers strike the rooted Mother with nobody to answer: she STAYS ROOTED for 30 s (no Rootmaw
##            loses its swamp); then a Tyrant Sire is laid by hand: he gets up, kills both, and she never got up
##   maw1     1 Clock Soldier strikes a rooted Rootmaw: it uproots, kills it, and roots again on its spot
##   maw4     5 Clock Soldiers strike a rooted Rootmaw: it uproots and backs off toward the Mother
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_ai_defend.gd [-- only:<part>]
var main: Node
var t := 0.0
var g: Game
var started := false
var fails := 0
var only := ""
var ai: AIBroodNew
var bt := 1
var ft := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only:"):
			only = a.substr(5)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		seed(5)
		main.start({"map": "glimmerdeep", "seed": 123537401, "slots": [
			{"who": "hard", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "rush"},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "economy"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.5:
		started = true
		for a in g.ais:
			if a is AIBroodNew:
				ai = a
				bt = a.team
				# (econ-coach-brood: the computer now roots its second Rootmaw at home before the natural's turtle, which
				# fills its home ring by the Rootmaw part below; the opening is not what this test checks: the old order)
				a.maw_first_on = false
			else:
				a.process_mode = Node.PROCESS_MODE_DISABLED
		ft = 1 - bt
		_run()
	return false


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func spot_near(p: Vector2, tiles: float, turn := 0.3) -> Vector2:
	var home: int = g.region_of(g.cell_of(p))
	for i in 48:
		var q: Vector2 = p + Vector2.from_angle(TAU * i / 48.0 + turn) * tiles * Defs.TILE
		var c: Vector2i = g.cell_of(q)
		if g._walkable(c) and g.region_of(c) == home:
			return q
	return p


func soldiers(n: int, at: Vector2) -> Array:
	var out: Array = []
	for i in n:
		var u: Unit = g._add_unit("clock_soldier", ft, at + Vector2((i % 3) * 22 - 22, (i / 3) * 22))
		out.append(u)
	return out


func alive(list: Array) -> Array:
	return list.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)


func notes_since(t0: float, word: String) -> Array:
	return ai.note.filter(func(n) -> bool: return float(n[0]) >= t0 and word in String(n[1]))


func _run() -> void:
	await wait(3.0)
	var q: Unit = BroodNew.queen(g, bt)
	# the Clockwork's own units stay home (its computer is off): stopped
	for u in g.units:
		if u.team == ft:
			u.cmd_stop()
	if only == "" or only == "swarm":
		await _swarm(q)
	if only == "" or only == "mother":
		await _mother(q)
	if only == "" or only == "maw1" or only == "maw4":
		await _maws(q)
	print("%d FAILED" % fails if fails > 0 else "ALL PASS")
	quit(1 if fails > 0 else 0)


func _swarm(q: Unit) -> void:
	print("-- swarm")
	var raptors: Array = []
	for i in 12:
		raptors.append(g._add_unit("raptor", bt, q.position + Vector2(-60 + (i % 6) * 18, BroodNew.drawn_r(q) + 40 + (i / 6) * 18)))
	await wait(12.0)
	var holding := raptors.filter(func(u) -> bool: return u.order == "hold" or u.order == "move")
	check(holding.size() == 12, "idle Raptors at home walk to the rally and HOLD (%d of 12)" % holding.size())
	var t0 := g.clock
	var foes := soldiers(5, spot_near(q.position, 9.0))
	for u in foes:
		u.cmd_hold()
	var sent := {}
	while g.clock - t0 < 30.0 and not alive(foes).is_empty():
		await physics_frame
		for r in raptors:
			if is_instance_valid(r) and not sent.has(r) and (r.order == "amove" or r.target != null):
				sent[r] = g.clock
	var times: Array = sent.values()
	times.sort()
	var spread: float = (float(times[-1]) - float(times[0])) if times.size() > 0 else 99.0
	check(sent.size() >= 11, "the Raptors go at the soldiers together: %d of 12 sent" % sent.size())
	check(spread <= 1.5, "all sent within one think: %.1f s between the first and the last" % spread)
	check(alive(foes).is_empty(), "the 5 Clock Soldiers die (%d left) in %.0f s" % [alive(foes).size(), g.clock - t0])
	var n := notes_since(t0, "defends with")
	print("   %s" % (str(n[0][1]) if not n.is_empty() else "(no defence note)"))
	await wait(10.0)
	var back := alive(raptors).filter(func(u) -> bool: return u.order == "hold" or u.order == "move")
	check(back.size() == alive(raptors).size(), "afterwards back at the rally, holding (%d of %d)" % [back.size(), alive(raptors).size()])
	for r in alive(raptors):
		r.hp = 0.0
		r.die()
	await wait(1.0)


func _mother(q: Unit) -> void:
	print("-- mother")
	# rooted, nothing to answer: no warriors, no Sire
	var t0 := g.clock
	while not BroodNew.rooted(q) and g.clock - t0 < 30.0:
		await wait(0.5)
	q.hp = q.max_hp
	var ups := 0
	var was := q.tesla_mode
	var foes := soldiers(2, spot_near(q.position, 4.0))
	for u in foes:
		u.cmd_attack(q)
	t0 = g.clock
	var swamp0: int = g.mlog.lines.size() if g.mlog else 0
	while g.clock - t0 < 30.0:
		await physics_frame
		if q.tesla_mode != was:
			if was == "deployed":
				ups += 1
			was = q.tesla_mode
	check(ups == 0, "the Mother stays rooted under 2 Clock Soldiers for 30 s (%d uproots, %d of %d health)" % [ups, int(q.hp), int(q.max_hp)])
	var lost := 0
	if g.mlog:
		for i in range(swamp0, g.mlog.lines.size()):
			if "lost its swamp" in g.mlog.lines[i]:
				lost += 1
	check(lost == 0, "no Rootmaw loses its swamp (%d)" % lost)
	# the Tyrant Sire: laid by hand beside her, rooted by the computer; then he answers the harass
	var f: Unit = g._add_unit(BroodNew.FATHER, bt, spot_near(q.position, 5.0, 2.0))
	t0 = g.clock
	while g.clock - t0 < 60.0 and not alive(foes).is_empty():
		await physics_frame
		if q.tesla_mode != was:
			if was == "deployed":
				ups += 1
			was = q.tesla_mode
	check(alive(foes).is_empty(), "the Tyrant Sire kills the harass (%d left, %.0f s)" % [alive(foes).size(), g.clock - t0])
	check(ups == 0, "and the Mother never got up (%d uproots)" % ups)
	t0 = g.clock
	while g.clock - t0 < 40.0 and not BroodNew.rooted(f):
		await wait(0.5)
	check(BroodNew.rooted(f), "the Tyrant Sire roots on his nest again (%.0f s)" % (g.clock - t0))


func _maws(q: Unit) -> void:
	# a Rootmaw rooted by the computer (laid by hand)
	var m: Unit = g._add_unit(BroodNew.MAW, bt, spot_near(q.position, 8.0, 4.0))
	var t0 := g.clock
	while g.clock - t0 < 60.0 and not BroodNew.rooted(m):
		await wait(0.5)
	check(BroodNew.rooted(m), "a Rootmaw is rooted by the computer (%.0f s)" % (g.clock - t0))
	if not BroodNew.rooted(m):
		return
	await wait(3.0)
	if only == "" or only == "maw1":
		print("-- maw1")
		var spot := m.position
		var foes := soldiers(1, spot_near(m.position, 2.5))
		foes[0].cmd_attack(m)
		t0 = g.clock
		var up := false
		while g.clock - t0 < 40.0 and not alive(foes).is_empty():
			await physics_frame
			up = up or m.tesla_mode != "deployed"
		check(up, "struck by a Clock Soldier the Rootmaw uproots")
		check(alive(foes).is_empty() and not m.dead, "and kills it (%.0f s, %d of %d health)" % [g.clock - t0, int(m.hp), int(m.max_hp)])
		t0 = g.clock
		while g.clock - t0 < 30.0 and not BroodNew.rooted(m):
			await wait(0.5)
		check(BroodNew.rooted(m) and m.position.distance_to(spot) < 1.5 * Defs.TILE, "then roots again on its spot (%.0f s, %.0f px off)" % [g.clock - t0, m.position.distance_to(spot)])
		await wait(3.0)
	if only == "" or only == "maw4":
		print("-- maw4")
		var d0 := m.position.distance_to(q.position)
		var foes4 := soldiers(5, spot_near(m.position, 3.0))
		for u in foes4:
			u.cmd_attack(m)
		t0 = g.clock
		var up4 := false
		var closest := d0
		while g.clock - t0 < 12.0 and not m.dead:
			await physics_frame
			up4 = up4 or m.tesla_mode != "deployed"
			closest = minf(closest, m.position.distance_to(q.position))
		check(up4, "struck by 5 Clock Soldiers the Rootmaw uproots")
		check(d0 - closest > 3.0 * Defs.TILE, "and backs off toward the Mother (%.0f tiles closer)" % ((d0 - closest) / Defs.TILE))
