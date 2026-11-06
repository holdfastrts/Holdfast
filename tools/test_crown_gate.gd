extends SceneTree
## THE NATURAL'S GATE BY THE RAMP (crown-hold, docs/crown_hold.md; the owner 2026-11-06, Dune Sea: the gate went "waaay
## over the top of the palisade in a bad spot", on the far stretch of the wall). For each map, the Hard Crown computer's
## 2nd hall spot (its own rule, AICrown._safe_hall_spot) gets its wall plan (AIExpandWall.plan_for); measured: the gate's
## walk in steps from the foot of the main's ramp, now (the stretch nearest the ramp) and the old way (the ways-in cell
## nearest the enemy by land when the ramp came down inside). The new gate must be at most NEAR_MAX steps from the foot
## and never farther than the old one.
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_gate.gd [-- maps:a,b side:0]
const NEAR_MAX := 14
var maps: Array = ["dune_sea", "greenhold", "red_coast", "ashford_crossing", "highmoor", "thornwood_maze"]
var fails := 0
var rows: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("maps:"):
			maps = a.substr(5).split(",")
	_run.call_deferred()


func _run() -> void:
	for m in maps:
		for side in 2:
			await _case(m, side)
	print("map | side | ramp in | gate now (steps from the ramp foot) | the old gate")
	for r in rows:
		print(r)
	print("RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


func _case(map: String, side: int) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(5)
	var slots: Array = [
		{"who": "hard", "faction": "brood", "colour": 1, "side": 0, "strategy": "economy"},
		{"who": "hard", "faction": "crown", "colour": 0, "side": 1, "strategy": "economy"}]
	if side == 0:
		slots = [{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "economy"},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "economy"}]
	main.start({"map": map, "seed": 5, "slots": slots})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var ai = null
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
		if g.faction_of(a.team) == "crown":
			ai = a
	await physics_frame
	ai._cs_prep()
	var mids: Array = []
	for h in g.halls_of(ai.team):
		mids.append(h.center() / float(Defs.TILE))
	var picks: Array = CrownSites.pick(g, ai.team, mids, 1, ai._cs_steps, {}, Callable(), ai._cs_field)
	var cell: Vector2i = picks[0]["c"] if not picks.is_empty() else Vector2i(-1, -1)
	if cell.x < 0:
		check(false, "[%s side %d] a hall spot" % [map, side])
		main.queue_free()
		await process_frame
		return
	var p: Dictionary = ai.xw.plan_for(cell)
	if not p.get("ok", false):
		print("  [%s side %d] no wall plan at %s (%s)" % [map, side, str(cell), ai.xw.no_plan_why])
		main.queue_free()
		await process_frame
		return
	var mz: Dictionary = ai.xw.main_zone()
	var gates: Array = []
	for e in p["pieces"]:
		if e[0] == "gate":
			gates.append(e[1])
	var now: int = ai.xw.gate_ramp_steps(gates, mz)
	# the old gate: the ways-in cell nearest the enemy by land (ramp inside), else nearest our main
	var ex: Array = p["exposed"]
	var ex_set := {}
	for c in ex:
		ex_set[c] = true
	var foe_d := {}
	if p["ramp_in"]:
		var fr: Dictionary = ai.xw._foe_reach()
		var fd: PackedInt32Array = fr["d"]
		for c in ex:
			for n in [c, c + Vector2i(1, 0), c + Vector2i(-1, 0), c + Vector2i(0, 1), c + Vector2i(0, -1)]:
				if g.in_map(n) and fd[g.idx(n)] >= 0:
					foe_d[n] = fd[g.idx(n)]
		if foe_d.is_empty():
			foe_d[Vector2i(-99, -99)] = 0
	var old_gates: Array = ai.xw._gate_cells(ex, ex_set, cell, Defs.BUILDINGS["town_hall"]["size"], foe_d)
	var old: int = ai.xw.gate_ramp_steps(old_gates, mz)
	rows.append("%s | %d | %s | %d (%s) | %d (%s)" % [map, side, str(p["ramp_in"]), now, str(gates), old, str(old_gates)])
	check(now >= 0 and now <= NEAR_MAX, "[%s side %d] the gate is %d steps from the main's ramp foot (at most %d)" % [map, side, now, NEAR_MAX])
	check(old < 0 or now <= old, "[%s side %d] never farther from the ramp than the old gate (%d, old %d)" % [map, side, now, old])
	main.queue_free()
	await process_frame
	await process_frame
