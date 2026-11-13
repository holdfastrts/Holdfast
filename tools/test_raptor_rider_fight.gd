extends SceneTree
## The owner's question (2026-11-13, a Hard Brood RUSH on Mirewood): would 10 Raptors beat 2 Horsemen in a stand-up
## fight (no micro), and how does it go when the riders kite (the owner's walk + attack)? Sandbox, no computers.
## brood-rush-coach (docs/brood_rush_coach.md): the fight now happens on a FLAT, OPEN patch of the map (found by
## _flat_spot: the first version put the riders on Greenhold's middle plateau and the Raptors below its cliff, so most
## Raptors were walking round to a ramp), the spawns are seeded, and there are more set-ups:
##   standup  both sides attack-move into each other (the riders ride by: Defs.RIDE_BY, the Cyclone-like loop)
##   stand    the riders stand their ground (HOLD-less idle: they fight standing, no ride-by) and the Raptors come in
##   kite     hit and run by script (the owner's walk + attack)
##   gate     the riders stand behind a one-cell gap in a palisade line (a gate the Raptors come through single file)
## (the Raptors at a wall with riders hitting and running from outside, run by the Brood's own computer:
## tools/test_brood_rush_riders.gd)
## Args: modes:standup,stand,kite  riders:2  raptors:10  trials:6  rideby:off  pack:1 (Pack Hunt researched)
##   set:raptor.hp=38,raptor.damage=7  (a balance number tried for this run only: Defs.UNITS[kind][stat])
##   godot --headless --fixed-fps 30 --script res://tools/test_raptor_rider_fight.gd -- modes:standup,kite riders:3

var main: Node
var args := {}


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_go.call_deferred()


func _alive(a: Array) -> Array:
	return a.filter(func(x): return is_instance_valid(x) and not x.dead)


## A spot on Greenhold where a 640 x 640 px patch is one height level, open ground and clear in straight lines from its
## middle: the fight must not be about a cliff or a ramp.
static func _flat_spot(g) -> Vector2:
	var best := Vector2.INF
	var mid := Vector2(Game.W, Game.H) * Game.T * 0.5
	var step := Game.T * 2
	var y := 360.0
	while y < Game.H * Game.T - 360.0:
		var x := 360.0
		while x < Game.W * Game.T - 360.0:
			var p := Vector2(x, y)
			if (best == Vector2.INF or p.distance_to(mid) < best.distance_to(mid)) and _open(g, p):
				best = p
			x += step
		y += step
	return best


static func _open(g, p: Vector2) -> bool:
	var lv: int = g.level_of(p)
	for i in range(-8, 9):
		for j in range(-8, 9):
			var q := p + Vector2(i, j) * 40.0
			if g.level_of(q) != lv or not g.passable(g.cell_of(q), 0):
				return false
	for k in 16:
		if not g.line_clear(p, p + Vector2.from_angle(k * TAU / 16.0) * 320.0):
			return false
	return true


func _go() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split(":")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.get("rideby", "") == "off":
		RideBy.enabled = false
	if args.has("set"):
		print("(trying %s)" % args["set"])
	var modes: PackedStringArray = str(args.get("modes", "standup,stand,kite")).split(",")
	var nr := int(args.get("riders", "2"))
	var nb := int(args.get("raptors", "10"))
	var trials := int(args.get("trials", "6"))
	for mode in modes:
		var wins := 0
		var lines: Array = []
		var lost_hp := 0.0
		var raps_left := 0
		for trial in trials:
			var r := await _fight(mode, nr, nb, trial)
			if r["raptors"] == 0:
				wins += 1
			lost_hp += r["rider_hp_lost"]
			raps_left += r["raptors"]
			lines.append("  trial %d: %.0fs, riders left %d (hp %s), raptors left %d, rider hp lost %d, raptor time in reach %d%%" % [
				trial, r["t"], r["riders"], str(r["hp"]), r["raptors"], int(r["rider_hp_lost"]), int(r["reach"])])
		print("%s (%d riders v %d raptors%s%s): riders won %d of %d, average rider hp lost %.0f of %d, raptors left %.1f" % [
			mode.to_upper(), nr, nb, ", ride-by off" if not RideBy.enabled else "", ", Pack Hunt" if args.has("pack") else "",
			wins, trials, lost_hp / trials, nr * int(Defs.UNITS["cuirassier"]["hp"]), float(raps_left) / trials])
		for l in lines:
			print(l)
	quit()


func _fight(mode: String, nr: int, nb: int, trial: int) -> Dictionary:
	main.start({"seed": 21 + trial, "map": "greenhold", "sandbox": true, "slots": [{"who": "you", "faction": "crown", "colour": 0, "side": 0}, {"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
	var g = main.game
	await create_timer(0.3).timeout
	g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.set_process(false)
		a.set_physics_process(false)
	if args.has("pack"):
		g.players[1]["tech"]["nb_pack_hunt"] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + trial
	var c := _flat_spot(g)
	var riders: Array = []
	var raps: Array = []
	if mode == "gate":
		# a palisade across the patch, 60 px south of the middle; for "gate" a 2-cell gap in it (the riders stand behind)
		var a: Vector2i = g.cell_of(c + Vector2(-300, 60))
		var b: Vector2i = g.cell_of(c + Vector2(300, 60))
		for cell in g.line_cells(a, b):
			if cell.x == g.cell_of(c).x:
				continue
			g._add_building("wall", 0, cell, true)
	for i in nr:
		var rp := c + Vector2(-20 * (nr - 1) + i * 40, 0)
		riders.append(g._add_unit("cuirassier", 0, rp))
	for i in nb:
		raps.append(g._add_unit("raptor", 1, c + Vector2(rng.randf_range(-70, 70), 220 + rng.randf_range(0, 50))))
	await process_frame
	if args.has("set"):
		# (Defs.UNITS is a constant: the numbers tried go on each unit's own copy of its stats)
		for kv in str(args["set"]).split(","):
			var ks: PackedStringArray = kv.split("=")
			var ku: PackedStringArray = ks[0].split(".")
			for u in riders + raps:
				if u.kind != ku[0]:
					continue
				var dd: Dictionary = u.d.duplicate()
				dd[ku[1]] = float(ks[1])
				u.d = dd
				if ku[1] == "hp":
					u.max_hp = float(ks[1])
					u.hp = u.max_hp
	var hp0 := 0.0
	for r in riders:
		hp0 += r.hp
	for u in raps:
		u.cmd_move(c, true)
	for r in riders:
		if mode == "standup" or mode == "kite":
			r.cmd_move(c + Vector2(0, 120), true)       # (both sides attack-move: a stand-up fight)
	var t := 0.0
	if trial == 0 and mode == str(args.get("modes", "standup,stand,kite")).split(",")[0]:
		await create_timer(0.5).timeout
		print("(raptor speed %.0f, hp %.0f; rider speed %.0f)" % [raps[0].speed, raps[0].hp, riders[0].speed])
	var samples := 0
	var reach := 0
	while t < 90.0:
		await create_timer(0.25).timeout
		t += 0.25
		var rr := _alive(riders)
		var ra := _alive(raps)
		if rr.is_empty() or ra.is_empty():
			break
		for x in ra:
			samples += 1
			var dd := INF
			for r in rr:
				dd = minf(dd, r.edge_distance(x.position) - x.radius)
			if dd <= x._range():
				reach += 1
		if mode == "kite":
			# hit and run: a rider whose sabre is cooling and has a Raptor within 60 px rides away 2 tiles
			for r in rr:
				var near: Unit = null
				var nd := INF
				for x in ra:
					var d: float = r.position.distance_to(x.position)
					if d < nd:
						nd = d
						near = x
				if near == null:
					continue
				if r.cooldown > 0.3 and nd < 60.0:
					r.cmd_move(r.position + (r.position - near.position).normalized() * 64.0, false)
				elif r.cooldown <= 0.05 and (r.order == "move" or r.order == "idle"):
					r.cmd_attack(near)
	var rr2 := _alive(riders)
	var hp1 := 0.0
	for r in rr2:
		hp1 += r.hp
	return {"t": t, "riders": rr2.size(), "hp": rr2.map(func(x): return int(x.hp)), "raptors": _alive(raps).size(),
		"rider_hp_lost": hp0 - hp1, "reach": 100.0 * reach / maxf(1.0, samples)}
