extends SceneTree
## RAID MICRO (owner, 2026-11-03, docs/raid_micro.md: "Crown turned tail and ran too soon; with 3 Horsemen stay there
## and kill more workers... not fight the Tyrant Sire and try to focus on the workers"):
##   godot --headless --fixed-fps 30 --script res://tools/test_raid_kite.gd [-- trace] [-- smart]
##  [kite]    a Brood worker line (its computer off: the test's prop): a rooted Rootmaw on the Mother's swamp, 8 grubs
##            working it, a Tyrant Sire up on his feet that chases the nearest rider all the time. Three Horsemen of the
##            Crown's raid (AI._raid) ride in: in 30 s they kill at least KILLS grubs and lose at most 1 rider (they kite
##            the Sire: they never ride home from him).
##  [swarm]   then 8 Raptors come at them: the raid rides home.
##  [smart]   the same raid against the Brood's own computer (on): it must not throw its Tyrant Sire after the riders
##            (BroodAI: fast riders are not chased with the Sire); grubs flee or gang up. The numbers are printed (both
##            outcomes are honest data, docs/raid_micro.md); the only check: the Sire stays at his nest.
const T := 32.0
const KILLS := 4
var fails := 0
var main: Node
var g: Game
var ai
var bai
var q: Unit
var dir := Vector2.ZERO
var maw: Unit
var grubs: Array = []


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


func _start(brood_on: bool) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(7)
	main.start({"map": "greenhold", "seed": 7, "slots": [
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
			if not brood_on:
				a.process_mode = Node.PROCESS_MODE_DISABLED      # (the Brood stands still: the test's prop)
		else:
			ai = a
			a.process_mode = Node.PROCESS_MODE_DISABLED          # (on again once the raid is set)
	ai.opening = "mill"
	await wait(1.0)
	q = BroodNew.queen(g, 1)
	dir = (g.center_of_team(0) - q.position).normalized()
	# the Brood's own start grubs out of the way (the test sets its own worker line)
	for u in g.units:
		if u.team == 1 and u.kind == "grub" and not u.dead:
			u.take_damage(99999.0, null)
	await wait(0.5)
	# (a rooted Mound Turtle spreads the swamp the Rootmaw needs, 1 tile a second)
	var tu: Unit = g._add_unit(BroodNew.TURTLE, 1, _root_spot(BroodNew.TURTLE, q.position + dir * 6.0 * T + dir.orthogonal() * 5.0 * T, false))
	tu.cmd_deploy()
	var ms := Vector2.INF
	var t0 := g.clock + 30.0
	while g.clock < t0:
		await wait(0.5)
		ms = _root_spot(BroodNew.MAW, q.position + dir * 9.0 * T, true)
		if ms != Vector2.INF:
			break
	maw = g._add_unit(BroodNew.MAW, 1, ms)
	maw.cmd_deploy()
	var t_end := g.clock + 20.0
	while g.clock < t_end and not BroodNew.rooted(maw):
		await wait(0.5)
	check(BroodNew.rooted(maw), "(set-up) the Rootmaw is rooted (%s, %s)" % [maw.tesla_mode, maw.order])
	grubs.clear()
	var side := dir.orthogonal()
	for i in 8:
		var gr: Unit = g._add_unit("grub", 1, _free(maw.position.lerp(q.position, 0.3) + side * float(i - 4) * 18.0))
		gr.cmd_gather(maw)
		grubs.append(gr)
	await wait(3.0)


## A spot near p where a `k` of the Brood's may root (BroodRoot.place_problem).
func _root_spot(k: String, p: Vector2, strict := false) -> Vector2:
	for r in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]:
		for i in 16:
			var sp: Vector2 = BroodRoot.snap(k, p + Vector2.from_angle(TAU * i / 16.0) * r * T)
			if BroodRoot.place_problem(g, 1, k, sp, null, false, 1.0, true) == "":
				return sp
	return Vector2.INF if strict else p


func _free(p: Vector2) -> Vector2:
	var c := g.cell_of(p)
	for r in 8:
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var m := Vector2i(x, y)
				if g.in_map(m) and g._walkable(m):
					return (Vector2(m) + Vector2(0.5, 0.5)) * T
	return p


func _stop() -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _dead_grubs() -> int:
	return grubs.filter(func(x) -> bool: return not is_instance_valid(x) or x.dead).size()


func _alive(list: Array) -> Array:
	return list.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)


func _party() -> Array:
	var party: Array = []
	for i in 3:
		var u: Unit = g._add_unit("cuirassier", 0, _free(maw.position + dir * 11.0 * T + dir.orthogonal() * float(i - 1) * 34.0))
		party.append(u)
	ai._raiders = party.duplicate()
	ai._raid_peak = 3
	ai._raid_block = 0.0
	ai.process_mode = Node.PROCESS_MODE_INHERIT
	return party


## Watch for `secs`; `sire` (when given) is driven to chase the nearest rider (the worst case: a Sire that never lets go).
func _watch(party: Array, secs: float, sire: Unit = null) -> void:
	var until := g.clock + secs
	var next := 0.0
	var tr := OS.get_cmdline_user_args().has("trace")
	while g.clock < until:
		await physics_frame
		if g.clock >= next:
			next = g.clock + 0.5
			if sire != null and is_instance_valid(sire) and not sire.dead:
				var near: Unit = null
				for u in _alive(party):
					if near == null or u.position.distance_to(sire.position) < near.position.distance_to(sire.position):
						near = u
				if near != null and sire.order_target != near:
					sire.cmd_attack(near)
			if tr and int(g.clock * 2.0) % 4 == 0:
				for u in _alive(party):
					print("      t=%.1f %s %s ot=%s hp=%.0f dsire=%.0f pistol=%s" % [g.clock, u.kind, u.order, u.order_target.kind if u.order_target and is_instance_valid(u.order_target) and u.order_target is Unit else "-", u.hp, u.position.distance_to(sire.position) if sire and is_instance_valid(sire) else -1.0, u.pistol])


func _case_kite() -> void:
	await _start(false)
	var sire: Unit = g._add_unit(BroodNew.FATHER, 1, _free(maw.position + dir * 4.0 * T))
	var party := await _party()
	var k0: int = ai.hz().raid_kites
	await _watch(party, 30.0, sire)
	var dead := _dead_grubs()
	var lost := 3 - _alive(party).size()
	var kites: int = ai.hz().raid_kites - k0
	print("    kite: %d grubs killed, %d riders lost, %d kite steps, raiders still out: %d, sire hp %.0f" % [dead, lost, kites, ai._raiders.size(), sire.hp])
	check(dead >= KILLS, "[kite] 3 Horsemen with a Tyrant Sire chasing them kill at least %d grubs in 30 s (%d)" % [KILLS, dead])
	check(lost <= 1, "[kite] ... and lose at most 1 rider (%d)" % lost)
	check(kites > 0, "[kite] ... by keeping away from the Sire (%d kite steps)" % kites)
	# [swarm] eight Raptors come at the party: it rides home
	var alive := _alive(party)
	if alive.size() < 2:
		check(false, "[swarm] two riders alive for the swarm part")
		await _stop()
		return
	sire.take_damage(99999.0, null)
	var home := g.center_of_team(0)
	var c := _mid(alive)
	for i in 8:
		var r: Unit = g._add_unit("raptor", 1, _free(c - dir * 7.0 * T + dir.orthogonal() * float(i - 4) * 16.0))
		r.cmd_attack(alive[i % alive.size()])
	await _watch(alive, 6.0)
	alive = _alive(party)
	var c2 := _mid(alive) if not alive.is_empty() else c
	check(not alive.is_empty() and c2.distance_to(home) < c.distance_to(home) - 150.0, "[swarm] with 8 Raptors coming the raid rides home (%.0f -> %.0f px from home, %d alive)" % [c.distance_to(home), c2.distance_to(home), alive.size()])
	await _stop()


func _case_smart() -> void:
	await _start(true)
	var sire: Unit = g._add_unit(BroodNew.FATHER, 1, _root_spot(BroodNew.FATHER, q.position - dir * 4.0 * T))
	sire.cmd_deploy()
	await wait(float(Defs.NB["turtle_switch"]) + 1.0)
	var nest := sire.position
	var party := await _party()
	var far := 0.0
	var chased := 0
	var until := g.clock + 40.0
	while g.clock < until:
		await wait(0.5)
		if is_instance_valid(sire) and not sire.dead:
			far = maxf(far, sire.position.distance_to(nest))
			for x in [sire.target, sire.order_target]:
				if x is Unit and is_instance_valid(x) and (x as Unit).kind == "cuirassier":
					chased += 1
					break
	print("    smart Brood: %d grubs killed, %d riders lost, Sire went %.0f px from where he was put (%s); its notes: %s" % [_dead_grubs(), 3 - _alive(party).size(), far, sire.tesla_mode if is_instance_valid(sire) else "dead", str(bai.note.slice(maxi(0, bai.note.size() - 8)))])
	check(chased == 0, "[smart] the Brood's computer never sends its Tyrant Sire after the fast riders (%d half-seconds on one)" % chased)
	await _stop()


static func _mid(list: Array) -> Vector2:
	var p := Vector2.ZERO
	for u in list:
		p += (u as Unit).position
	return p / maxf(1.0, list.size())


func _run() -> void:
	if not OS.get_cmdline_user_args().has("smart"):
		await _case_kite()
	if not OS.get_cmdline_user_args().has("kite"):
		await _case_smart()
	print("raid kite: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(1 if fails > 0 else 0)
