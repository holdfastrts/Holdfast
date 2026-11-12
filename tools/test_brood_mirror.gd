extends SceneTree
## THE BROOD MIRROR (brood-v-brood-coach, docs/brood-v-brood-coach.md): two Hard Brood computers (OPTIMAL) on Greenhold
## to 5:00, checking the decisions the coaching fixed:
##  - an enemy Raptor is no rider (AIBroodNew.is_rider), so no rider read and no "riders in its land" in the mirror
##  - the other Brood's normal opening is not read GREEDY (_nb_brood_greedy: a third base early is greed, two are not)
##  - both economies grow: 25 grubs or more each by 5:00 (the rider lockdown kept them at 8-10)
##  - the mirror's OPTIMAL dice hold no Rush (AIOptimal.NORMAL["brood"]["brood"])
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_mirror.gd [-- map:greenhold seed:1]
## Prints PASS / FAIL per check and "ALL PASS" at the end (exit 1 on a failure).
var main: Node
var g: Game
var t := 0.0
var map := "greenhold"
var seed_ := 1
var fails := 0
var done := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() == 2 and kv[0] == "map":
			map = kv[1]
		elif kv.size() == 2 and kv[0] == "seed":
			seed_ = int(kv[1])
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var slots: Array = []
		for i in 2:
			slots.append({"who": "hard", "faction": "brood", "colour": i, "side": i, "strategy": "optimal"})
		main.start({"map": map, "seed": seed_, "slots": slots})
		return false
	if main.game == null:
		return false
	g = main.game
	g.path_budget_us = 1 << 40
	if g.clock < 300.0 or done:
		return done
	done = true
	var raptor: Unit = null
	for u in g.units:
		if u.kind == "raptor" and not u.dead:
			raptor = u
			break
	_check(raptor != null, "Raptors on the field by 5:00")
	if raptor:
		_check(not AIBroodNew.is_rider(raptor), "an enemy Raptor is no rider")
	_check(not (AIOptimal.NORMAL["brood"]["brood"] as Dictionary).has("rush"), "OPTIMAL's mirror dice hold no Rush")
	for a in g.ais:
		var lines: Array = []
		for n in a.note:
			lines.append(String(n[1]))
		var riders := lines.filter(func(s: String) -> bool: return s.contains("rider") or s.contains("guards its grubs"))
		var greedy := lines.filter(func(s: String) -> bool: return s.begins_with("scouted: GREEDY"))
		_check(riders.is_empty(), "P%d: no rider read or rider guard against the other Brood (%d lines)" % [a.team + 1, riders.size()])
		_check(greedy.is_empty(), "P%d: the other Brood's opening is not read GREEDY (%d)" % [a.team + 1, greedy.size()])
		_check(not a._nb_brood_greedy(2, 0), "P%d: a Mother and one turtle on new ground are no greed" % (a.team + 1))
		_check(a._nb_brood_greedy(3, 0) or a.seen_army >= 150.0, "P%d: a third base early with little army is" % (a.team + 1))
		var grubs := BroodNew.count_of(g, a.team, "grub")
		_check(grubs >= 25, "P%d: its economy grows (%d grubs at 5:00)" % [a.team + 1, grubs])
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
	return true
