extends SceneTree
## START SPOTS MIRROR PROBE (start-spots-fix, docs/start_spots_fix.md): a MEASURING tool, it changes no rule.
## A mirror match of two computers watched from the first frame: every unit of the second side is matched with the first
## side's unit of the same number (Unit.tserial: units counted per side) and carried back through the map's mirror
## (Game.sym_pt); the first moment a pair stands apart (more than `tol` px, or a different job or load) is printed with
## both, then each side's income every 30 s and the ratio at 1:00 / 2:00 / 3:00. On a fair start the pairs move as one
## until the sides first meet (the scouts) and the incomes match.
##   godot --headless --fixed-fps 30 --script res://tools/start_spots_mirror_probe.gd -- map:greenhold seed:2 fac:brood [end:180] [tol:4] [swap:1]
var main: Node
var g: Game
var map := "greenhold"
var seed_ := 2
var fac := "brood"
var end_t := 180.0
var tol := 4.0
var swap := false
var t := 0.0
var next_look := 0.0
var next_inc := 30.0
var first_gap := ""
var inc := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"fac": fac = kv[1]
			"end": end_t = float(kv[1])
			"tol": tol = float(kv[1])
			"swap": swap = kv[1] == "1"
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0


func _units(tm: int) -> Dictionary:
	var out := {}
	for u in g.units:
		if u.team == tm and not u.dead:
			out[u.tserial] = u
	return out


func _desc(u: Unit, p: Vector2) -> String:
	return "%s #%d %s at %s%s" % [u.kind, u.tserial, u.work if u.order == "gather" else u.order, p.round(), " carrying" if u.carrying > 0 else ""]


func _look() -> void:
	var a := _units(0)
	var b := _units(1)
	for k in a:
		var ua: Unit = a[k]
		if not b.has(k):
			first_gap = "%.1f s: %s has no twin on the other side" % [g.clock, _desc(ua, ua.position)]
			return
		var ub: Unit = b[k]
		# (both carried into the first start's frame of their mirror set: Game.sym_pt is its own inverse)
		var pa: Vector2 = g.sym_pt(0, ua.position)
		var pb: Vector2 = g.sym_pt(1, ub.position)
		if ua.kind != ub.kind or ua.work != ub.work or (ua.carrying > 0) != (ub.carrying > 0) or pa.distance_to(pb) > tol:
			if BroodRoot.has_fp(ua) and BroodRoot.has_fp(ub) and ua.kind == ub.kind:
				continue          # (a rooted creature: its footprint is what mirrors, the test_start_layout check)
			first_gap = "%.1f s: side 0 %s | side 1 %s" % [g.clock, _desc(ua, pa), _desc(ub, pb)]
			return


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var sl: Array = []
		for i in 2:
			sl.append({"who": "hard", "faction": fac, "colour": i, "side": (1 - i) if swap else i, "strategy": "optimal"})
		main.start({"map": map, "seed": seed_, "slots": sl})
		return false
	if main.game == null:
		return false
	g = main.game
	g.path_budget_us = 1 << 40
	if first_gap == "" and g.clock >= next_look:
		next_look += 0.5
		_look()
		if first_gap != "":
			print("MIRROR first gap at ", first_gap)
	if g.clock >= next_inc:
		var ia := int(g.stats[0]["gold"])
		var ib := int(g.stats[1]["gold"])
		inc[int(round(next_inc))] = [ia, ib]
		print("MIRROR %3d s  income side 0 %5d  side 1 %5d  ratio %.3f" % [int(round(next_inc)), ia, ib, float(ia) / maxf(1.0, float(ib))])
		next_inc += 30.0
	if g.clock >= end_t:
		if first_gap == "":
			print("MIRROR no gap in %d s" % int(end_t))
		var parts: PackedStringArray = []
		for s in [60, 120, 180]:
			if inc.has(s):
				parts.append("%d:00 %.3f" % [s / 60, float(inc[s][0]) / maxf(1.0, float(inc[s][1]))])
		print("MIRROR %s %s seed %d starts %s flips %s: %s" % [map, fac, seed_, g.starts, g.start_flip, ", ".join(parts)])
		quit(0)
		return true
	return false
