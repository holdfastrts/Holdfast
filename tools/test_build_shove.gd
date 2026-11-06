extends SceneTree
## SITES KEEP CLEAR (crown-hold, docs/crown_hold.md; the owner's playtest of 2026-11-06, Dune Sea: "couldn't start a
## Church/Barracks: the spot was blocked (refunded)" six times between 6:41 and 7:47: the soldiers shoved off a site walked
## back onto it). Soldiers on HOLD, idle, or sent back to a guard post inside a placed footprint clear it (a margin round
## it too), do not walk back in while the site waits, and the building starts: for the player's sites and the computer's.
## And a computer site that stayed blocked is not placed on the same spot again (AI._bad_sites).
##   godot --headless --fixed-fps 30 --script res://tools/test_build_shove.gd
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "greenhold", "seed": 4243, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "economy"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if started and g.clock > 600.0:
		print("RESULT: FAIL (timed out)")
		quit(1)
		return true
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func _ai(tm: int):
	for a in g.ais:
		if a.team == tm:
			return a
	return null


## Soldiers of team `tm` standing on the footprint of a `kind` at `spot` (a 3 x 2 block over its middle).
func _squad(tm: int, kind: String, spot: Vector2i, n: int) -> Array:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var mid: Vector2 = (Vector2(spot) + Vector2(size) * 0.5) * Defs.TILE
	var out: Array = []
	for i in n:
		var p: Vector2 = mid + Vector2((i % 3 - 1) * 26.0, (i / 3 - 0.5) * 26.0)
		out.append(g._add_unit("musketeer", tm, p))
	return out


func _on_site(b: Building, list: Array) -> int:
	var n := 0
	var r: Rect2 = b.rect()
	for u in list:
		if is_instance_valid(u) and not u.dead and r.grow(u.radius * 0.7).has_point(u.position):
			n += 1
	return n


## One case: `how` = "hold", "idle" or "guard" (the post is given again every second, as the computer's posts and a
## player's guard rally are). Returns the building (started or not).
func _case(tm: int, kind: String, how: String) -> void:
	var hall: Building = g.halls_of(tm)[0]
	var spot: Vector2i = g.find_spot(tm, kind, hall, 4, 14, "near")
	check(spot.x >= 0, "P%d %s: a spot for a %s" % [tm + 1, how, kind])
	if spot.x < 0:
		return
	var men := _squad(tm, kind, spot, 6)
	var posts: Array = []
	for u in men:
		posts.append(u.position)
		if how == "hold" or how == "guard":
			u.cmd_hold()
	await wait(0.5)
	g.players[tm]["gold"] = 5000
	var lab: Unit = g._add_unit("labourer", tm, hall.center() + Vector2(0, hall.rect().size.y * 0.5 + 30.0))
	var b: Building = g.place_building(tm, kind, spot, [lab])
	if b == null:
		print("  (placement: '%s', requirement %s, gold %d)" % [g.placement_problem(tm, kind, spot), str(g.requirement_met(tm, kind)), int(g.players[tm]["gold"])])
	check(b != null and b.ghost, "P%d %s: the %s is placed over %d soldiers" % [tm + 1, how, kind, men.size()])
	if b == null:
		return
	var a = _ai(tm)
	var back := 0
	var ok_t := -1.0
	var t0: float = g.clock
	while g.clock - t0 < 25.0:
		if how == "guard":
			# (sent back to their posts every second: the player's rally, or the computer's HOLD post)
			for i in men.size():
				var u: Unit = men[i]
				if u.dead:
					continue
				if tm == 1 and a != null:
					a.ch._post(u, posts[i], Vector2.UP)
				elif u.order != "move" or u.order_point.distance_to(posts[i]) > 8.0:
					u.cmd_move(posts[i])
		await wait(1.0)
		if b.dead:
			break
		if not b.ghost and ok_t < 0.0:
			ok_t = g.clock - t0
		if ok_t >= 0.0:
			back = maxi(back, _on_site(b, men))
		if ok_t >= 0.0 and g.clock - t0 > ok_t + 4.0:
			break
	check(not b.dead and not b.ghost, "P%d %s: the %s starts (in %.1f s; %s)" % [tm + 1, how, kind, ok_t, "dropped as blocked" if b.dead else "still a ghost" if b.ghost else "standing"])
	var holding := 0
	var clear := 0
	for u in men:
		if u.dead:
			continue
		if u.order == "hold":
			holding += 1
		if not b.rect().grow(4.0).has_point(u.position):
			clear += 1
	check(clear == men.size(), "P%d %s: every soldier clear of the footprint (%d / %d)" % [tm + 1, how, clear, men.size()])
	if how == "hold":
		check(holding == men.size(), "P%d hold: each holds again where it stepped to (%d / %d on HOLD)" % [tm + 1, holding, men.size()])
	for u in men:
		g.consume_unit(u)
	g.consume_unit(lab)
	await wait(0.3)


func _run() -> void:
	g.explored.fill(1)
	await wait(1.0)
	# (the Barracks needs a Cottage, the Church a Barracks: both stand already, out of the way)
	for tm in 2:
		var h: Building = g.halls_of(tm)[0]
		for k in ["cottage", "barracks"]:
			var c: Vector2i = g.find_spot(tm, k, h, 3, 20, "behind")
			if c.x >= 0:
				g._add_building(k, tm, c, true)
	for tm in 2:
		for how in ["hold", "idle", "guard"]:
			await _case(tm, "barracks" if how != "idle" else "church", how)
	# the computer: a site that stayed blocked is not placed on the same spot again
	var a = _ai(1)
	var k := "barracks"
	var s1: Vector2i = a._find_spot(k)
	check(s1.x >= 0, "the computer finds a spot for a Barracks")
	if s1.x >= 0:
		var fake: Building = g.place_building(1, k, s1, [])
		if fake != null:
			g.site_failed(fake, "blocked")
		var s2: Vector2i = a._find_spot(k)
		check(s2.x >= 0 and s2 != s1, "after a blocked site the computer looks elsewhere (%s, then %s)" % [str(s1), str(s2)])
	# a move into a waiting site is turned aside (the keep-out point)
	var hall: Building = g.halls_of(0)[0]
	var sp: Vector2i = g.find_spot(0, "barracks", hall, 4, 14, "near")
	if sp.x >= 0:
		g.players[0]["gold"] = 5000
		var gb: Building = g.place_building(0, "barracks", sp, [])
		if gb == null:
			check(false, "a waiting site for the keep-out check")
			print("RESULT: FAIL (%d failed)" % (fails))
			quit(1)
			return
		var mid: Vector2 = gb.rect().get_center()
		var q: Vector2 = g.site_keepout(0, mid, 10.0)
		check(not gb.rect().grow(10.0).has_point(q), "a point on a waiting site is moved outside it (%s -> %s)" % [str(mid), str(q)])
		check(g.site_keepout(0, mid + Vector2(600, 0), 10.0) == mid + Vector2(600, 0), "a point away from sites is left as it is")
		check(g.site_keepout(1, mid, 10.0) == mid, "an enemy's site does not turn the other side's men aside")
	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
