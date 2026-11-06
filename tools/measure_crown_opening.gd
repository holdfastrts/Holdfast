extends SceneTree
## THE CROWN OPENING MEASURED (crown-optimal-opening, docs/crown_optimal_opening.md): one computer game, headless, the
## numbers the owner asked about for the Crown's side:
##   godot --headless --fixed-fps 30 --script res://tools/measure_crown_opening.gd -- a:crown sa:optimal b:brood \
##       sb:optimal map:saltmarsh_isles seed:1 end:600 out:/abs/file.json [da:hard db:hard]
## The Crown must be side a (team 0). Writes one JSON line: labourers at each minute 1..6, the second hall laid and
## finished, the Barracks / Mill / Horse Breeder laid, the first Horseman out and when the riders first rode out (the
## plan's attack), what the Horsemen killed by 6:00 and by the end (units, labourers / grubs among them), the supply
## blocks (seconds at the cap before 6:00), OPTIMAL's picks, the result (winner, clock) and both sides' income.
var main: Node
var g: Game
var fa := "crown"
var fb := "brood"
var sa := "optimal"
var sb := "optimal"
var map := "saltmarsh_isles"
var seed_ := 1
var end_t := 600.0
var out := "/tmp/measure.json"
var da := "hard"
var db := "hard"
var t := 0.0
var labs := {}
var foe_workers := {}
var r := {}
var horse_kills := {}           # instance id -> [kills, worker kills] (kept after it dies)
var horse_k6 := 0
var horse_w6 := 0
var blocked := 0.0
var _foe_w_last := {}           # foe worker id -> true (alive last check)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"a": fa = kv[1]
			"b": fb = kv[1]
			"sa": sa = kv[1]
			"sb": sb = kv[1]
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"end": end_t = float(kv[1])
			"out": out = kv[1]
			"da": da = kv[1]
			"db": db = kv[1]
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0


func _ai(tm: int) -> AI:
	for a in g.ais:
		if a.team == tm:
			return a
	return null


func _note(k: String) -> void:
	if not r.has(k):
		r[k] = snappedf(g.clock, 1.0)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": da, "faction": fa, "colour": 0, "side": 0, "strategy": sa},
			{"who": db, "faction": fb, "colour": 1, "side": 1, "strategy": sb}]})
		return false
	if main.game == null:
		return false
	g = main.game
	g.path_budget_us = 1 << 40
	if g.hud:
		g.hud.visible = false
	if g.spectator and g.spectator.process_mode != Node.PROCESS_MODE_DISABLED:
		g.spectator.process_mode = Node.PROCESS_MODE_DISABLED
	if g.controls and g.controls.process_mode != Node.PROCESS_MODE_DISABLED:
		g.controls.process_mode = Node.PROCESS_MODE_DISABLED
	_watch()
	if g.over or g.clock >= end_t:
		_finish()
		return true
	return false


func _watch() -> void:
	var m := int(g.clock / 60.0)
	if m >= 1 and m <= 10 and not labs.has(m):
		labs[m] = g.workers(0).size()
		foe_workers[m] = g.workers(1).size()
	if g.halls_of(0, false).size() >= 2:
		_note("hall2_laid")
	if g.halls_of(0).size() >= 2:
		_note("hall2_done")
	for k in ["barracks", "powder_mill", "horse_breeder", "foundry"]:
		if not r.has(k) and _has(k):
			_note(k)
	var a := _ai(0)
	if a != null and a._attacking:
		_note("first_attack")
	if g.clock < 360.0 and g.supply_used(0) >= int(g.players[0]["cap"]) and int(g.players[0]["cap"]) < g.max_supply(0):
		blocked += 1.0 / 30.0
	for u: Unit in g.army(0):
		if u.kind == "cuirassier":
			_note("first_horseman")
			var id: int = u.get_instance_id()
			horse_kills[id] = u.kills
	if g.clock < 360.0:
		var k6 := 0
		for id in horse_kills:
			k6 += int(horse_kills[id])
		horse_k6 = k6


func _has(k: String) -> bool:
	var ai := _ai(0)
	if ai == null:
		return false
	return not ai._mine(k).is_empty()


func _finish() -> void:
	var k := 0
	for id in horse_kills:
		k += int(horse_kills[id])
	r["map"] = map
	r["seed"] = seed_
	r["a"] = "%s %s" % [fa, sa]
	r["b"] = "%s %s" % [fb, sb]
	r["labs"] = labs
	r["foe_workers"] = foe_workers
	r["horse_kills_6"] = horse_k6
	r["horse_kills"] = k
	r["horsemen"] = horse_kills.size()
	r["blocked_s"] = snappedf(blocked, 1.0)
	r["end"] = snappedf(g.clock, 1.0)
	r["winner"] = g.winner if g.over else -1
	r["income"] = [int(g.stats[0]["gold"]), int(g.stats[1]["gold"])]
	r["army_value_end"] = [_value(0), _value(1)]
	var a := _ai(0)
	if a != null and a.opt != null:
		r["picks"] = (a.opt.picks as Array).map(func(p: Array) -> String: return "%s %s %s->%s" % [_mmss(float(p[0])), p[1], p[2], p[3]])
		r["opt_log"] = (a.opt.log as Array).map(func(p: Array) -> String: return "%s %s" % [_mmss(float(p[0])), p[1]])
	if a != null and a.scout != null:
		r["reads"] = (a.scout.reads as Array).map(func(x: Array) -> String: return "%s %s" % [_mmss(float(x[0])), AIRead.word(String(x[1]))])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_line(JSON.stringify(r))
	f.close()
	if g.mlog:
		var lf := FileAccess.open(out.get_basename() + ".log", FileAccess.WRITE)
		for l in g.mlog.lines:
			lf.store_line(str(l))
		lf.close()
	print("done ", JSON.stringify(r))


func _value(tm: int) -> int:
	var v := 0
	for u in g.army(tm):
		v += Game.unit_value(u)
	return v


func _mmss(c: float) -> String:
	return "%d:%02d" % [int(c) / 60, int(c) % 60]
