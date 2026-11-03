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
##  [edge]    THE CLIFF EDGE (0.29.2): a Town Hall of ours below the main's cliff, at the Crown's own spot (CrownSites.pick,
##            under the edge), and 16 Raptors at it: within EDGE_BY s the musket line has moved to the cliff's edge above it
##            (edge_moves; 4+ Musketeers within EDGE_NEAR px of the hall's side), every one of them stays on the main's level
##            the whole time (never down the ramp), the cannon is on the edge too and on HOLD; 2-4 labourers mend the hall
##            (never more), a mender a Raptor goes for runs (dodges), and once the Raptors are gone the line walks back to
##            the ramp post (within POST_R tiles of the band) and the menders are let go
const POST_R := 7.0
const EDGE_BY := 15.0
const EDGE_NEAR := 230.0
const EDGE_KEEP_WAIT := 8.0
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
	# (the raid is over: the Raptors of [below] go)
	for u in g.army(1):
		if u.kind == "raptor" and not u.dead:
			u.die()
	await wait(EDGE_KEEP_WAIT)
	await _edge_check(muskets, gun, band)
	print("test_crown_hold: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)


func _edge_check(muskets: Array, gun: Unit, band: Vector2) -> void:
	var ch = ai.ch
	var picks: Array = CrownSites.pick(g, 0, [Vector2(g.starts[0]) + Vector2(2.5, 2.0)], 1)
	check(not picks.is_empty() and float(picks[0]["share"]) > 0.2, "[edge] (set-up) the Crown's spot is under the edge (%s)" % (str(picks[0]) if not picks.is_empty() else "none"))
	if picks.is_empty():
		return
	var hall: Building = g._add_building("town_hall", 0, picks[0]["c"], true)
	var lab: Unit = g._add_unit("labourer", 0, _free(hall.center() + Vector2(0, 90)))
	await wait(2.0)
	# (more Musketeers for the edge: 6 on the post already)
	var live: Array = muskets.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var foot: Vector2 = hall.center() + (hall.center() - band).normalized() * 9.0 * T
	var raptors: Array = []
	for i in 16:
		var r: Unit = g._add_unit("raptor", 1, _free(foot + Vector2(float(i % 4 - 2) * 24.0, float(i / 4 - 2) * 24.0)))
		r.cmd_attack(hall)
		raptors.append(r)
	var m0: int = ch.edge_moves
	var t0 := g.clock
	var left_main := 0
	var near_best := 0
	var gun_edge := false
	var menders_max := 0
	var sicced := false
	while g.clock - t0 < 40.0:
		await wait(0.5)
		for u in live:
			if is_instance_valid(u) and not u.dead and g.level_of(u.position) != ch._home_h:
				left_main += 1
				if left_main <= 6:
					var cc: Vector2i = g.cell_of(u.position)
					print("  (off the main: %s at %s cell %s height %d ramp %d cliff %d solid %d, order %s, mode %s, target %s)" % [u.kind, str(u.position), str(cc),
						int(g.height[g.idx(cc)]), int(g.ramp[g.idx(cc)]), int(g.cliff[g.idx(cc)]), int(g.solid[g.idx(cc)]), u.order, u.mode, str(u.target)])
		if g.clock - t0 <= EDGE_BY + 20.0:
			var near := live.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and hall.edge_distance(u.position) < EDGE_NEAR).size()
			near_best = maxi(near_best, near)
			if is_instance_valid(gun) and not gun.dead and hall.edge_distance(gun.position) < EDGE_NEAR + 60.0 and g.level_of(gun.position) == ch._home_h:
				gun_edge = true
		menders_max = maxi(menders_max, ch._menders.size())
		if not sicced and not ch._menders.is_empty():
			# (two Raptors sent at a mender: he must run)
			var w: Unit = ch._menders.keys()[0]
			var n := 0
			for r in raptors:
				if is_instance_valid(r) and not r.dead and n < 2:
					r.cmd_attack(w)
					n += 1
			sicced = n > 0
		if raptors.all(func(r) -> bool: return not is_instance_valid(r) or r.dead) or hall.dead:
			break
	print("  (edge: moves %d, %d Musketeers near the hall at best, menders sent %d, at most %d at once, dodges %d, hall %d/%d%s, %d Raptors left)" % [
		ch.edge_moves - m0, near_best, ch.mend_sent, menders_max, ch.mend_dodges, int(hall.hp), int(hall.max_hp), " DEAD" if hall.dead else "",
		raptors.filter(func(r) -> bool: return is_instance_valid(r) and not r.dead).size()])
	check(ch.edge_moves > m0, "[edge] the line moved to the cliff edge above the hall (%d)" % (ch.edge_moves - m0))
	check(near_best >= mini(4, live.size()), "[edge] ... %d Musketeers within %d px of the hall's side at best" % [near_best, int(EDGE_NEAR)])
	check(left_main == 0, "[edge] no Musketeer stepped off the main's level (%d looks off it)" % left_main)
	check(gun_edge, "[edge] the cannon went to the edge too")
	check(ch.mend_sent >= 2 and menders_max <= 4, "[edge] 2-4 labourers mended the hall (%d sent, at most %d at once)" % [ch.mend_sent, menders_max])
	check(not hall.dead, "[edge] the hall stands (%d / %d)" % [int(hall.hp), int(hall.max_hp)])
	check(not sicced or ch.mend_dodges > 0, "[edge] a mender the Raptors went for ran (dodges %d)" % ch.mend_dodges)
	for r in raptors:
		if is_instance_valid(r) and not r.dead:
			r.die()
	await wait(EDGE_KEEP_WAIT + 12.0)
	var back := live.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and u.position.distance_to(band) < POST_R * T).size()
	var alive := live.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead).size()
	check(back == alive, "[edge] the threat gone, the line is back at the ramp post (%d of %d)" % [back, alive])
	check(ch._menders.is_empty(), "[edge] ... and the menders are let go (%d)" % ch._menders.size())
