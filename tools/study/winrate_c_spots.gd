extends SceneTree
## (winrate-c) Which start spot each player of a match had: starts the match as tools/qa_match.gd does (same seed, slots)
## and prints the start cells, then quits. A measuring tool only.
##   godot --headless --fixed-fps 30 --script res://tools/study/winrate_c_spots.gd -- map:<map> seed:<seed> fac:<faction>
## Prints "SPOTS <map> <seed> <x0>,<y0> <x1>,<y1> A=<index of the player on spot A>" (spot A = the top / top-left start,
## as docs/start_spots_fix.md names it).
var main: Node
var t := 0.0
var map := "greenhold"
var seed_ := 1
var fac := "brood"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"fac": fac = kv[1]
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var sl: Array = []
		for i in 2:
			sl.append({"who": "hard", "faction": fac, "colour": i, "side": i, "strategy": "optimal"})
		main.start({"map": map, "seed": seed_, "slots": sl})
		return false
	if main.game == null:
		return false
	var s: Array = main.game.starts
	var a := 0 if (s[0].y < s[1].y or (s[0].y == s[1].y and s[0].x < s[1].x)) else 1
	print("SPOTS %s %d %d,%d %d,%d A=%d" % [map, seed_, s[0].x, s[0].y, s[1].x, s[1].y, a])
	quit()
	return true
