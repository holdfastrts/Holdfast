extends SceneTree
## GUNS WITH A THIN GUARD (cinder-clockwork-ai, docs/cinder_clockwork_ai.md; the owner's Cinder Steps watch 2026-11-13: three
## Crown Field Cannons and two Musketeers at the top of a ramp, the Clockwork army beside them not attacking).
## A staged scene: a Hard Clockwork computer (Balanced) against a Crown whose computer is off. At START s a Clockwork army
## (SOLDIERS Clock Soldiers and SPRINGERS Springers) is put at the foot of the Crown main's ramp and sent out as the push; at
## the top of the ramp stand GUNS deployed Field Cannons with GUARD Musketeers in front of them (the Crown's bank full of
## powder). FOR s later it reads what is left.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_gun_rush.gd -- [map:greenhold] [seed:5] [guard:2] [guns:3]
##       [soldiers:16] [springers:4] [for:90] [check:1]  (and `cwguns:off cwfinish:off` for the "before")
## Prints a RESULT line (guns and guard left, the Clockwork's value lost, the push's phase and gun rushes); with check:1
## (the thin guard) it checks the guns fall and the push does not pull back.
var map := "greenhold"
var seed_ := 5
var n_guard := 2
var n_guns := 3
var n_sold := 16
var n_spr := 4
var for_t := 90.0
var do_check := false
var place := "ramp"           # ramp: the guns at the top of the Crown main's ramp; field: on the low ground, the army 520 px off
var fails := 0
const START := 5.0


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
			"guard": n_guard = int(kv[1])
			"guns": n_guns = int(kv[1])
			"soldiers": n_sold = int(kv[1])
			"springers": n_spr = int(kv[1])
			"for": for_t = float(kv[1])
			"check": do_check = kv[1] == "1"
			"place": place = kv[1]
	_run.call_deferred()


func _run() -> void:
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
	while g.clock < START:
		await physics_frame
	g.players[0]["gold"] = 5000
	g.players[0]["powder"] = 2000
	var hall: Building = g.halls_of(0)[0]
	var top_c: Vector2 = g.ramp_top(hall)
	check(top_c != Vector2.INF, "the Crown's main has a ramp")
	var top: Vector2 = top_c * Defs.TILE
	var inward: Vector2 = (hall.center() - top).normalized()
	# the foot of the ramp: walk outward from the top until the level changes, then 3 tiles more
	var h0 := int(g.height[g.idx(Vector2i(top_c))])
	var foot := top
	for i in 30:
		foot = top - inward * Defs.TILE * float(i)
		var c := g.cell_of(foot)
		if g.in_map(c) and int(g.height[g.idx(c)]) != h0 and g.ramp[g.idx(c)] == 0:
			break
	foot -= inward * Defs.TILE * 4.0
	var side := Vector2(-inward.y, inward.x)
	if place == "field":
		# the guns on the low ground 6 tiles out from the foot, facing out; the army 520 px further out
		top = foot - inward * Defs.TILE * 6.0
		foot = top - inward * 520.0
	var guns: Array = []
	for i in n_guns:
		var gu: Unit = g._add_unit("cannon", 0, top + inward * 70.0 + side * (float(i) - (n_guns - 1) * 0.5) * 40.0)
		gu.cmd_deploy()
		guns.append(gu)
	var guard: Array = []
	for i in n_guard:
		guard.append(g._add_unit("musketeer", 0, top + inward * 25.0 + side * (float(i) - (n_guard - 1) * 0.5) * 26.0))
	var army: Array = []
	for i in n_sold:
		army.append(g._add_unit("clock_soldier", 1, foot - inward * float(i / 6) * 30.0 + side * (float(i % 6) - 2.5) * 28.0))
	for i in n_spr:
		army.append(g._add_unit("springer", 1, foot - inward * 110.0 + side * (float(i) - (n_spr - 1) * 0.5) * 34.0))
	for i in 60:
		await physics_frame
	var push = ai.push
	check(push != null, "the Clockwork has its push")
	if push == null:
		print("FAILS: %d" % fails)
		quit()
		return
	push.cfg["main_min"] = 0.0
	push._launch(army)
	var v0 := 0.0
	for u in army:
		v0 += ai._unit_value(u)
	var pulled := false
	var t0 := g.clock
	var guns_dead_at := -1.0
	while g.clock < t0 + for_t and not g.over:
		await physics_frame
		if push.phase == "back" or (push.phase == "" and push.units.is_empty()):
			pulled = true
		if OS.get_cmdline_user_args().has("debug") and int(g.clock * 30.0) % 30 == 0:
			var alive := army.filter(func(x) -> bool: return is_instance_valid(x) and not x.dead)
			var orders := {}
			var wind := 0.0
			for u in alive:
				orders[u.order] = int(orders.get(u.order, 0)) + 1
				wind += u.wind
			var cen := Vector2.ZERO
			for u in alive:
				cen += u.position
			cen /= maxf(1.0, alive.size())
			var md := INF
			var on_gun := 0
			for u in alive:
				for x in guns:
					if is_instance_valid(x) and not x.dead:
						md = minf(md, u.position.distance_to(x.position))
						if u.order_target == x:
							on_gun += 1
			var lv := {}
			for u in alive:
				var c := g.cell_of(u.position)
				var key := "h%d%s" % [int(g.height[g.idx(c)]), "r" if g.ramp[g.idx(c)] == 1 else ""]
				lv[key] = int(lv.get(key, 0)) + 1
			var gl := []
			for x in guns:
				if is_instance_valid(x) and not x.dead:
					var c2 := g.cell_of(x.position)
					gl.append("h%d %s" % [int(g.height[g.idx(c2)]), x.tesla_mode])
			print("   mind-to-gun %d on-gun %d levels %s guns %s" % [int(md), on_gun, str(lv), str(gl)])
			print("t %d alive %d wind %.2f orders %s phase %s centre-top %d anchor-top %d guns %d guard %d" % [int(g.clock - t0), alive.size(), wind / maxf(1.0, alive.size()), str(orders), push.phase, int(cen.distance_to(top)), int(push.anchor.distance_to(top)) if push.anchor != Vector2.INF else -1,
				guns.filter(func(x) -> bool: return is_instance_valid(x) and not x.dead).size(), guard.filter(func(x) -> bool: return is_instance_valid(x) and not x.dead).size()])
		if guns_dead_at < 0.0 and guns.all(func(x) -> bool: return not is_instance_valid(x) or x.dead):
			guns_dead_at = g.clock - t0
	var guns_left := guns.filter(func(x) -> bool: return is_instance_valid(x) and not x.dead).size()
	var guard_left := guard.filter(func(x) -> bool: return is_instance_valid(x) and not x.dead).size()
	var v1 := 0.0
	for u in army:
		if is_instance_valid(u) and not u.dead:
			v1 += ai._unit_value(u)
	print("RESULT map %s guns %d guard %d army %d+%d: guns left %d (all down at %s), guard left %d, Clockwork lost %d of %d, pulled back %s, gun rushes %d" % [
		map, n_guns, n_guard, n_sold, n_spr, guns_left, ("%d s" % int(guns_dead_at)) if guns_dead_at >= 0.0 else "never",
		guard_left, int(v0 - v1), int(v0), str(pulled), int(push.stats.get("gun_rush", 0))])
	if OS.get_cmdline_user_args().has("debug"):
		for e in ai.sp_log:
			if float(e[0]) >= t0:
				print("  [%d] %s" % [int(float(e[0]) - t0), e[1]])
	print("KILLS crown %s  clockwork %s" % [str(g.stats[0]["kills_by"]), str(g.stats[1]["kills_by"])])
	if do_check:
		check(guns_left == 0, "the guns fall (%d of %d left)" % [guns_left, n_guns])
		check(not pulled or guns_left == 0, "the push does not pull back while the guns stand")
		check(v0 - v1 < v0 * 0.6, "it does not lose most of its army (%d of %d)" % [int(v0 - v1), int(v0)])
		print("ALL PASS" if fails == 0 else "FAILS: %d" % fails)
	quit()
