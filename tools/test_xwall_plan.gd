extends SceneTree
## The Crown computer's walled-expansion plan (scripts/ai_expand_wall.gd plan_for) made faster in 0.28.1 (perf-stutter):
## it must give EXACTLY the same plan as before (tools/xw_plan_ref.gd is the old code, kept for this test), every cell,
## piece, slot and their order, and take far less time (it made a 130 to 270 ms frame each time the Crown laid a hall).
##   godot --headless --fixed-fps 60 --script res://tools/test_xwall_plan.gd [-- map:cinder_steps seed:3206849968 limit_ms:60]
## A computer Brood against a Hard Crown on RUSH (the owner's lag report); at a few times of the match, plans for the
## Crown's halls and for free hall spots over the map are made by both and compared. Prints PASS or FAIL.
var main: Node
var t := 0.0
var g: Game
var map := "cinder_steps"
var seed_ := 3206849968
var checks := [150.0, 300.0, 420.0, 480.0, 540.0]
var limit_ms := 60.0            # the slowest new plan may take this long (the old one took 120 to 300 ms here)
var fails := 0
var compared := 0
var worst_new := 0.0
var worst_old := 0.0
var new_ms: Array = []
var old_ms: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("limit_ms:"):
			limit_ms = float(a.substr(9))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "brood", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "rush"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	paused = false
	if not checks.is_empty() and g.clock >= float(checks[0]):
		checks.pop_front()
		_check()
	if checks.is_empty() or g.over:
		new_ms.sort()
		old_ms.sort()
		var med := func(a: Array, f: float) -> float: return float(a[int(a.size() * f)]) if not a.is_empty() else 0.0
		print("XWALL compared %d plans, %d different; slowest new %.1f ms, slowest old %.1f ms; median new %.1f old %.1f, 95%% new %.1f old %.1f" % [
			compared, fails, worst_new, worst_old, med.call(new_ms, 0.5), med.call(old_ms, 0.5), med.call(new_ms, 0.95), med.call(old_ms, 0.95)])
		var ok := fails == 0 and compared > 0 and worst_new <= limit_ms
		print("XWALL PASS" if ok else "XWALL FAIL")
		quit(0 if ok else 1)
	return false


func _check() -> void:
	for ai in g.ais:
		if not ai._crown() or not ai.xw.active():
			continue
		var ref = load("res://tools/xw_plan_ref.gd").new(ai)
		var cells: Array = []
		for h in g.halls_of(ai.team, false):
			cells.append([h.cell, h])
		var step := 6
		for y in range(2, g.H - 6, step):
			for x in range(2, g.W - 6, step):
				var c := Vector2i(x, y)
				if g.placement_problem(ai.team, "town_hall", c, true) == "":
					cells.append([c, null])
		for e in cells:
			var t0 := Time.get_ticks_usec()
			var a: Dictionary = ai.xw.plan_for(e[0], e[1])
			var t1 := Time.get_ticks_usec()
			var b: Dictionary = ref.plan_for(e[0], e[1])
			var t2 := Time.get_ticks_usec()
			new_ms.append((t1 - t0) / 1000.0)
			old_ms.append((t2 - t1) / 1000.0)
			worst_new = maxf(worst_new, (t1 - t0) / 1000.0)
			worst_old = maxf(worst_old, (t2 - t1) / 1000.0)
			compared += 1
			a.erase("hall")
			b.erase("hall")
			if var_to_str(a) != var_to_str(b):
				fails += 1
				print("XWALL DIFFERENT at %s (clock %.0f): new ok %s r %s, old ok %s r %s" % [e[0], g.clock, a.get("ok"), a.get("r"), b.get("ok"), b.get("r")])
		print("XWALL %d:%02d %d plans so far, slowest new %.1f ms, old %.1f ms" % [int(g.clock) / 60, int(g.clock) % 60, compared, worst_new, worst_old])
