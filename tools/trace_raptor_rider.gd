extends SceneTree
## brood-rush-coach: a trace of the Raptor v Horseman stand-up (tools/test_raptor_rider_fight.gd's set-up), to see why only a
## few Raptors bite at once. Every 0.25 s: each Raptor's order, target, phase, distance to its target's edge, speed, knock and
## stun; a summary of the share of Raptor time spent in reach / biting / chasing / without a target.
##   godot --headless --fixed-fps 30 --script res://tools/trace_raptor_rider.gd -- [rideby:off] [riders:N] [raptors:N] [seed:N] [verbose]

var main: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_go.call_deferred()


func _alive(a: Array) -> Array:
	return a.filter(func(x): return is_instance_valid(x) and not x.dead)


func _go() -> void:
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split(":")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.get("rideby", "") == "off":
		RideBy.enabled = false
	var nr := int(args.get("riders", "2"))
	var nb := int(args.get("raptors", "10"))
	main.start({"seed": int(args.get("seed", "21")), "map": "greenhold", "sandbox": true, "slots": [{"who": "you", "faction": "crown", "colour": 0, "side": 0}, {"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
	var g = main.game
	await create_timer(0.3).timeout
	g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.set_process(false)
		a.set_physics_process(false)
	var c: Vector2 = Vector2(Game.W, Game.H) * Game.T * 0.5 if args.has("centre") else load("res://tools/test_raptor_rider_fight.gd")._flat_spot(g)
	seed(int(args.get("seed", "21")) + 1000)
	var riders: Array = []
	for i in nr:
		riders.append(g._add_unit("cuirassier", 0, c + Vector2(-20 * (nr - 1) + i * 40, 0)))
	var raps: Array = []
	for i in nb:
		raps.append(g._add_unit("raptor", 1, c + Vector2(randf_range(-70, 70), 220 + randf_range(0, 50))))
	await process_frame
	if args.has("verbose"):
		for u in raps:
			print("spawn %s level %d (centre %d) clear %s walk %s" % [str(u.position - c), g.level_of(u.position), g.level_of(c), str(g.line_clear(u.position, c)), str(g.walkable(u.position) if g.has_method("walkable") else "?")])
	for u in raps:
		u.cmd_move(c, true)
	for r in riders:
		r.cmd_move(c + Vector2(0, 120), true)
	var t := 0.0
	var n := {"samples": 0, "reach": 0, "biting": 0, "notarget": 0, "far": 0, "knocked": 0, "stunned": 0}
	var hp0 := 0.0
	for r in riders:
		hp0 += r.hp
	while t < 60.0:
		await create_timer(0.25).timeout
		t += 0.25
		var rr := _alive(riders)
		var ra := _alive(raps)
		if rr.is_empty() or ra.is_empty():
			break
		var line := "%5.2f riders:" % t
		for r in rr:
			line += " [%s %.0f v%.0f %s]" % [r.order, r.hp, r.velocity.length(), "T" if r.target else "-"]
		line += " | raptors:"
		for x in ra:
			n["samples"] += 1
			var tg: Entity = x.target
			var dd := INF
			for r in rr:
				dd = minf(dd, r.edge_distance(x.position) - x.radius)
			if tg == null:
				n["notarget"] += 1
			if dd <= x._range():
				n["reach"] += 1
			if x.phase != "":
				n["biting"] += 1
			if dd > 200.0:
				n["far"] += 1
			if x.knock.length() > 1.0:
				n["knocked"] += 1
			if x.stun_t > 0.0:
				n["stunned"] += 1
			line += " %s%s%.0f%s" % [x.order.left(2), "T" if tg else "-", dd, "*" if x.phase != "" else ""]
		if args.has("verbose"):
			print(line)
	var s: float = maxf(1.0, n["samples"])
	var hp1 := 0.0
	for r in _alive(riders):
		hp1 += r.hp
	print("RESULT %s riders=%d raptors=%d t=%.1f riders_left=%d raptors_left=%d rider_hp_lost=%.0f | reach %.0f%% biting %.0f%% no-target %.0f%% far(>200) %.0f%% knocked %.0f%% stunned %.0f%%" % [
		"rideby-off" if not RideBy.enabled else "rideby-on", nr, nb, t, _alive(riders).size(), _alive(raps).size(), hp0 - hp1,
		100.0 * n["reach"] / s, 100.0 * n["biting"] / s, 100.0 * n["notarget"] / s, 100.0 * n["far"] / s, 100.0 * n["knocked"] / s, 100.0 * n["stunned"] / s])
	quit()
