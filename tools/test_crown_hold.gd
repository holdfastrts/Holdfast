extends SceneTree
## THE CROWN HOLDS ITS MAIN AND SCOUTS WITH RIDERS (the owner's doctrine, 2026-11-03; scripts/ai_crown_hold.gd,
## docs/ai_crown_transitions.md section 10):
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_hold.gd
## A Hard Crown computer (Balanced) on Greenhold against a Brood that stands still (its computer off). The test gives the
## Crown 6 Musketeers, a Field Cannon and 2 Horsemen at home, then:
##  [post]    after 40 s the Musketeers stand on HOLD on the main's high ground near the top of its ramp (within POST_R
##            tiles of the ramp's top band), the cannon on HOLD behind them (farther from the ramp than the line's middle)
##  [scout]   one Horseman (of 2) rides the scouting loop and is SCOUT_FAR tiles from home within 60 s; the other stays
##  [below]   30 Raptors (750: they come in pairs at 50) come at a labourer working below the main (at the hall site nearest the ramp's foot): the army
##            (worth less than BEAT times them) holds the top (holds > 0, the Musketeers still on the main) and the
##            labourer runs up onto the main within 30 s (or dies trying: then the check reports it)
const POST_R := 7.0
const SCOUT_FAR := 25.0
const T := 32.0
var fails := 0
var main: Node
var g: Game
var ai


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


func _free(p: Vector2) -> Vector2:
	var c := g.cell_of(p)
	for r in 10:
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var m := Vector2i(x, y)
				if g.in_map(m) and g._walkable(m):
					return (Vector2(m) + Vector2(0.5, 0.5)) * T
	return p


func _run() -> void:
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
			a.process_mode = Node.PROCESS_MODE_DISABLED      # (the Brood stands still)
		else:
			ai = a
	ai.opening = "mill"
	await wait(2.0)
	var ch = ai.ch
	check(ch.active(), "(set-up) the doctrine and the ramp post are on")
	var hall: Vector2 = g.center_of_team(0)
	var muskets: Array = []
	for i in 6:
		muskets.append(g._add_unit("musketeer", 0, _free(hall + Vector2(60 + 20 * i, 80))))
	var gun: Unit = g._add_unit("cannon", 0, _free(hall + Vector2(-60, 90)))
	var riders: Array = []
	for i in 2:
		riders.append(g._add_unit("cuirassier", 0, _free(hall + Vector2(-90 - 30 * i, 60))))
	await wait(40.0)
	# [post]
	var band: Vector2 = ch._bc * T
	check(ch._bc != Vector2.INF, "(set-up) the main's ramp was found")
	var on_hold := 0
	var near := 0
	var mid := Vector2.ZERO
	for u in muskets:
		if u.order == "hold":
			on_hold += 1
		if ch.on_main(u.position) and u.position.distance_to(band) < POST_R * T:
			near += 1
		mid += u.position
	mid /= muskets.size()
	check(on_hold == 6, "[post] the 6 Musketeers stand on HOLD (%d)" % on_hold)
	check(near == 6, "[post] ... on the main near the top of its ramp (%d within %.0f tiles of the band)" % [near, POST_R])
	check(gun.order == "hold" and ch.on_main(gun.position) and gun.position.distance_to(band) > mid.distance_to(band),
			"[post] the cannon on HOLD behind the line (%s, %.1f tiles from the band against the line's %.1f)" % [gun.order, gun.position.distance_to(band) / T, mid.distance_to(band) / T])
	# [scout]
	var scouts: Array = riders.filter(func(u) -> bool: return ch.is_scout(u))
	check(scouts.size() == 1, "[scout] one of the 2 Horsemen scouts (%d)" % scouts.size())
	var far := 0.0
	var t_end := g.clock + 20.0
	while g.clock < t_end:
		await wait(1.0)
		for u in scouts:
			if is_instance_valid(u) and not u.dead:
				far = maxf(far, u.position.distance_to(hall) / T)
	check(far >= SCOUT_FAR, "[scout] the scout rides out (%.0f tiles from home at most)" % far)
	check(ch._wps.size() >= 3, "[scout] its loop has %d spots" % ch._wps.size())
	# [below]: a labourer at the hall site nearest the ramp's foot, and Raptors coming at him
	var foot: Vector2 = (ch._ramp_mid + Vector2(0.5, 0.5)) * T - ch._in * 4.0 * T
	var site := Vector2.INF
	for s in g.base_sites:
		var p: Vector2 = (Vector2(s) + Vector2(2.5, 2.0)) * T
		if g.starts.has(s) or ch.on_main(p):
			continue
		if site == Vector2.INF or p.distance_to(foot) < site.distance_to(foot):
			site = p
	# (a Cottage of ours there: the raid is a threat at our buildings, AI._threat)
	g._add_building("cottage", 0, g.nearest_free(g.cell_of(site) + Vector2i(-3, 0), 8), true)
	var lab: Unit = g._add_unit("labourer", 0, _free(site))
	await wait(2.0)
	var dir := (site - foot).normalized()
	for i in 30:
		var r: Unit = g._add_unit("raptor", 1, _free(site + dir * (5.0 + float(i / 10)) * T + dir.orthogonal() * float(i % 10 - 5) * 20.0))
		r.cmd_move(lab.position, true)
	print("  (the site is %.1f tiles from the ramp's top band)" % (site.distance_to(band) / T))
	var h0: int = ch.holds
	var up := false
	t_end = g.clock + 30.0
	while g.clock < t_end:
		await wait(0.5)
		if is_instance_valid(lab) and not lab.dead and ch.on_main(lab.position):
			up = true
			break
	check(ch.holds > h0, "[below] the army holds the top against the Raptors below (holds %d)" % (ch.holds - h0))
	var stayed: int = muskets.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and ch.on_main(u.position)).size()
	check(stayed >= 5, "[below] the Musketeers stay on the main (%d of 6)" % stayed)
	check(up, "[below] the labourer runs up onto the main (%s)" % ("alive" if is_instance_valid(lab) and not lab.dead else "dead"))
	print("test_crown_hold: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
