extends SceneTree
## START SPOTS PROBE (start-spots study, docs/start_spots_study.md): a MEASURING tool, it changes no rule.
## A mirror match (computers) watched for its first minutes: at the start every unit and building of both sides, the
## second side's mirrored back through the map's centre beside the first's (a mirrored start lines up), then every
## 5 seconds each side's income earned and each worker's job. Prints lines; nothing else.
##   godot --headless --fixed-fps 30 --script res://tools/start_spots_probe.gd -- map:greenhold seed:1 fac:brood end:120 [swap:1] [gear:0]
var main: Node
var g: Game
var map := "greenhold"
var seed_ := 1
var fac := "brood"
var end_t := 120.0
var swap := false
var t := 0.0
var next := 5.0
var started := false
var gear := -1


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
			"swap": swap = kv[1] == "1"
			"gear": gear = int(kv[1])
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0


func _mir(p: Vector2) -> Vector2:
	return Vector2(Game.W, Game.H) * Game.T - p


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var sl: Array = []
		for i in 2:
			sl.append({"who": "hard", "faction": fac, "colour": i, "side": (1 - i) if swap else i, "strategy": "optimal"})
		var cfg := {"map": map, "seed": seed_, "slots": sl}
		if gear >= 0:
			cfg["gear_turn"] = gear == 1      # (gear:0 / gear:1: the TURNING GEARS experiment off / on for this match)
		main.start(cfg)
		return false
	if main.game == null:
		return false
	g = main.game
	g.path_budget_us = 1 << 40
	if not started:
		started = true
		print("PROBE starts ", g.starts, " sides ", g.sides)
		for tm in 2:
			for u in g.units:
				if u.team == tm:
					var p: Vector2 = u.global_position if tm == 0 else _mir(u.global_position)
					print("PROBE t0 p%d unit %s at %s (mirrored for p1)" % [tm, u.kind, p.snapped(Vector2(0.1, 0.1))])
			for b in g.buildings:
				if b.team == tm:
					var c: Vector2 = b.rect().get_center() if tm == 0 else _mir(b.rect().get_center())
					print("PROBE t0 p%d building %s centre %s (mirrored for p1)" % [tm, b.kind, c.snapped(Vector2(0.1, 0.1))])
	if g.clock >= next:
		next += 5.0
		var line := "PROBE %3d" % int(round(g.clock))
		for tm in 2:
			var st: Dictionary = g.stats[tm]
			line += "  p%d income %5d bank %4d workers %2d" % [tm, int(st["gold"]), int(g.players[tm]["gold"]), g.workers(tm).size()]
		print(line)
	if g.clock >= end_t:
		for tm in 2:
			for b in g.buildings:
				if b.team == tm:
					var c: Vector2 = b.rect().get_center() if tm == 0 else _mir(b.rect().get_center())
					print("PROBE end p%d building %s centre %s built %s (mirrored for p1)" % [tm, b.kind, c.snapped(Vector2(0.1, 0.1)), b.built])
		quit(0)
		return true
	return false
