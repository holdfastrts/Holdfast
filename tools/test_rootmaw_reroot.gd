extends SceneTree
## A Rootmaw that gets up to fight keeps its spot (the owner's playtest 2026-11-03, Greenhold, 0.26.2: "it uprooted a
## Rootmaw to fight the Musketeer and then the Musketeer retreated; instead of rooting the Rootmaw again it built another
## entirely new Rootmaw, and the old one got bugged out ... trying to root in the same spot"; docs/raid_micro.md C):
##   godot --headless --fixed-fps 30 --script res://tools/test_rootmaw_reroot.gd
##  [keep]   the Brood's computer on (Hard Economy), the Crown's off. A Musketeer hits one of its rooted Rootmaws: it gets
##           up to fight; while it is up its spot is reserved (no Rootmaw may be planned or rooted there, BroodRoot.plan_of)
##           and no new Rootmaw goes there; the Musketeer gone, it roots again on its own spot.
##  [taken]  the same, but while it is up another creature roots on its spot (forced, as if it had been taken): the
##           Rootmaw roots on another free spot within 40 s, and never keeps walking back to the taken one.
const T := 32.0
var fails := 0
var main: Node
var g: Game
var bai


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


func _start() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(11)
	main.start({"map": "greenhold", "seed": 11, "slots": [
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
		else:
			a.process_mode = Node.PROCESS_MODE_DISABLED
	await wait(75.0)


func _stop() -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _free(p: Vector2) -> Vector2:
	var c := g.cell_of(p)
	for r in 8:
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var m := Vector2i(x, y)
				if g.in_map(m) and g._walkable(m) and g.region_of(m) == g.region_of(c):
					return (Vector2(m) + Vector2(0.5, 0.5)) * T
	return p


## The rooted Rootmaw nearest the Crown.
func _pick_maw() -> Unit:
	var home := g.center_of_team(0)
	var best: Unit = null
	for u in g.units:
		if u.team == 1 and not u.dead and u.kind == BroodNew.MAW and BroodNew.rooted(u) \
				and (best == null or u.position.distance_to(home) < best.position.distance_to(home)):
			best = u
	return best


## Get it up to fight: a Musketeer hitting it (the computer's _nb_maw_guard). Returns the Musketeer.
func _provoke(m: Unit) -> Unit:
	var q := BroodNew.queen(g, 1)
	var away := (m.position - q.position).normalized()
	var mu: Unit = g._add_unit("musketeer", 0, _free(m.position - away * 3.0 * T + away.orthogonal() * 2.0 * T))
	mu.powder = maxf(mu.powder, 10.0)
	mu.cmd_attack(m)
	var hp0 := m.hp
	var until := g.clock + 20.0
	while g.clock < until and not bai.maw_fighting(m):
		await wait(0.25)
	if not bai.maw_fighting(m):
		print("    (provoke) Rootmaw hp %.0f -> %.0f, musketeer %s %s at %.0f px, powder %.0f" % [hp0, m.hp, mu.order, str(mu.target), mu.position.distance_to(m.position), mu.powder])
	return mu


func _maws_near(p: Vector2, r: float, skip: Unit) -> int:
	var n := 0
	for u in g.units:
		if u != skip and u.team == 1 and not u.dead and u.kind == BroodNew.MAW and u.position.distance_to(p) < r:
			n += 1
		elif u.team == 1 and not u.dead and u.kind == "grub" and u.order == "nb_morph" and String(u.nb.get("mk", "")) == BroodNew.MAW \
				and u.order_point.distance_to(p) < r:
			n += 1
	return n


func _case_keep() -> void:
	await _start()
	var m := _pick_maw()
	check(m != null, "[keep] (set-up) the Brood has a rooted Rootmaw")
	if m == null:
		await _stop()
		return
	var spot := m.position
	var mu := await _provoke(m)
	var t_up := g.clock + 8.0
	while g.clock < t_up and m.tesla_mode != "packed":
		await wait(0.25)
	check(bai.maw_fighting(m) and m.tesla_mode == "packed", "[keep] a Musketeer hits the Rootmaw: it gets up to fight (%s)" % m.tesla_mode)
	check(m.nb.has("keep"), "[keep] ... keeping its spot (nb.keep)")
	check(BroodRoot.place_problem(g, 1, BroodNew.MAW, spot, null, true) != "", "[keep] while it is up its spot is reserved (%s)" % BroodRoot.place_problem(g, 1, BroodNew.MAW, spot, null, true))
	var fs = bai._nb_find_spot(BroodNew.queen(g, 1), null)
	var rr := float(Defs.PIT_CLAIM) * T * 2.0
	check(fs == null or (fs as Vector2).distance_to(spot) >= rr, "[keep] ... the computer's next Rootmaw spot is not on it (%s)" % str(fs))
	# the Musketeer leaves (as in the owner's game: it retreated)
	await wait(4.0)
	if is_instance_valid(mu) and not mu.dead:
		mu.cmd_move(g.center_of_team(0))
	var planted := 0
	var until := g.clock + 30.0
	while g.clock < until and not (BroodNew.rooted(m) and not bai.maw_fighting(m)):
		await wait(0.5)
		planted = maxi(planted, _maws_near(spot, rr * 0.5, m))
	print("    keep: rooted %s at %.0f px from its spot, %.0f s; other Rootmaws planned/rooted on its ground: %d" % [BroodNew.rooted(m), m.position.distance_to(spot), g.clock, planted])
	check(BroodNew.rooted(m) and m.position.distance_to(spot) < T, "[keep] the Musketeer gone, it roots again on its own spot (%.0f px off)" % m.position.distance_to(spot))
	check(planted == 0, "[keep] no new Rootmaw was planned on its spot meanwhile (%d)" % planted)
	check(not m.nb.has("keep"), "[keep] rooted again, its reservation is let go")
	await _stop()


func _case_taken() -> void:
	await _start()
	var m := _pick_maw()
	if m == null:
		check(false, "[taken] (set-up) the Brood has a rooted Rootmaw")
		await _stop()
		return
	var spot := m.position
	var mu := await _provoke(m)
	check(bai.maw_fighting(m), "[taken] it gets up to fight")
	# it walks a little away from its spot; something takes the spot (forced: a turtle rooted there by hand)
	await wait(3.0)
	m.cmd_move(m.position + (BroodNew.queen(g, 1).position - m.position).normalized() * 3.0 * T)
	await wait(2.0)
	m.nb.erase("keep")              # (forced: the test's stand-in for a spot lost anyway)
	var tu: Unit = g._add_unit(BroodNew.TURTLE, 1, spot)
	tu.cmd_deploy()
	m.nb["keep"] = spot
	await wait(float(Defs.NB["turtle_switch"]) + 1.0)
	print("    (set-up) the turtle on its spot is rooted: %s" % BroodNew.rooted(tu))
	if is_instance_valid(mu) and not mu.dead:
		mu.take_damage(99999.0, null)
	var tries := 0
	var until := g.clock + 45.0
	var last_pt := Vector2.INF
	while g.clock < until and not BroodNew.rooted(m):
		await wait(0.5)
		if m.order == "nb_root" and m.order_point.distance_to(spot) < T and m.order_point != last_pt:
			tries += 1
			last_pt = m.order_point
	print("    taken: rooted %s at %.0f px from the old spot; tries at the taken spot %d; still fighting %s; notes %s" % [BroodNew.rooted(m), m.position.distance_to(spot), tries, bai.maw_fighting(m), str(bai.note.slice(maxi(0, bai.note.size() - 4)))])
	check(BroodNew.rooted(m) and m.position.distance_to(spot) > T, "[taken] its spot taken, it roots on another free spot within 45 s")
	check(tries <= 1, "[taken] ... and does not keep going back to the taken spot (%d tries)" % tries)
	await _stop()


func _run() -> void:
	await _case_keep()
	await _case_taken()
	print("rootmaw reroot: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(1 if fails > 0 else 0)
