extends SceneTree
## The Clockwork computer's OWL RAIDS (cw-builds-c; scripts/ai_cw_builds_c.gd, docs/clockwork_builds_c.md) against the Crown
## or the Brood computer:
##   godot --headless --fixed-fps 30 --script res://tools/test_clockwork_owls.gd -- \
##       [map:greenhold seed:11 cw:owls vs:crown op:balanced dcw:hard dop:hard until:600 check:1 json:<file>]
## A Clockwork computer (plan `cw`, default owls; `cw:balanced` or `cw:springer` for the comparison) against a computer of
## faction `vs` (crown or brood) on plan `op`, for `until` game seconds. It prints:
##  - the milestones: Escapement, first Clock Aviary, TICKING OWL researched, the first Owl, the raid ready, the first
##    sortie out, the first strike, the second Clocktower laid;
##  - every 30 s: Winders, cogs earned, Tension, army, the enemy's workers;
##  - at 4, 6, 8 and 10 minutes: Winders, cogs earned, army value, the enemy's workers lost, value killed and lost;
##  - what the Owls finished off (kind, value, clock) and the plan's decisions.
## check:1 (the test; Greenhold seed 11 against the Hard Crown, until:480 is enough): the first Owl by OWL_BY, the raid
## ready (its flock out of the opening) by RAID_BY, the first sortie by OUT_BY (after the crank post is set up), at least
## WORKERS_6 Winders at 6:00 (the economy keeps growing), a second Clocktower laid by HALL_BY.
const OWL_BY := 330.0
const RAID_BY := 360.0
const OUT_BY := 480.0
const WORKERS_6 := 18
const HALL_BY := 450.0
var main: Node
var g
var t := 0.0
var map := "greenhold"
var seed_ := 11
var cw_plan := "owls"
var vs := "crown"
var op := "balanced"
var dcw := "hard"
var dop := "hard"
var until := 600.0
var check := false
var json_path := ""
var cwt := 0
var opt := 1
var cw = null
var ms := {}
var marks := {}
var next_print := 30.0
var op_workers_seen := {}
var op_workers_lost := 0
var fails := 0


func _initialize() -> void:
	if OS.get_cmdline_user_args().is_empty():
		check = true      # (qa-tests, 2026-11-08: a bare run is the test, so the suite gets a verdict)
		until = 480.0
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"cw": cw_plan = kv[1]
			"vs": vs = kv[1]
			"op": op = kv[1]
			"dcw": dcw = kv[1]
			"dop": dop = kv[1]
			"until": until = float(kv[1])
			"check": check = kv[1] == "1"
			"json": json_path = kv[1]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _mmss(s: float) -> String:
	if s < 0.0:
		return "never"
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


func _mark(k: String) -> void:
	if not ms.has(k):
		ms[k] = g.clock


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": dcw, "faction": "clockwork", "colour": 0, "side": 0, "strategy": cw_plan},
			{"who": dop, "faction": vs, "colour": 1, "side": 1, "strategy": op}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if cw == null:
		for ai in g.ais:
			if ai.team == cwt:
				cw = ai
		return false
	if Engine.get_physics_frames() % 10 == 0:
		_look()
	if g.clock >= next_print:
		next_print += 30.0
		_print_line()
	for m in [240.0, 360.0, 480.0, 600.0]:
		if g.clock >= m and not marks.has(str(int(m))):
			marks[str(int(m))] = _snapshot()
	if g.clock >= until or g.over:
		_finish()
		return true
	return false


func _look() -> void:
	for b in g.buildings:
		if b.team != cwt or b.dead:
			continue
		if b.built:
			match b.kind:
				"escapement": _mark("escapement")
				"cuckoo_house": _mark("aviary")
				"clocktower":
					if g.halls_of(cwt).size() >= 2:
						_mark("hall2")
		elif b.kind == "clocktower":
			_mark("hall2_laid")
	if g.has_tech(cwt, "owl_morph"):
		_mark("owl_tech")
	var owls := 0
	for u in g.units:
		if u.dead or u.team != cwt:
			continue
		if u.kind == "ticking_owl":
			owls += 1
		elif u.kind == "cuckoo":
			_mark("swift")
	if owls >= 1:
		_mark("owl1")
	if owls >= 3:
		_mark("owl3")
	var b = cw.get("btc")
	if b != null:
		if b.launched:
			_mark("raid")
		if b.first_out_t >= 0.0:
			_mark("sortie")
		if b.first_strike_t >= 0.0:
			_mark("strike")
	var alive := {}
	for u in g.units:
		if u.team == opt and not u.dead and u.is_worker():
			alive[u.get_instance_id()] = true
	for id in op_workers_seen:
		if not alive.has(id):
			op_workers_lost += 1
	op_workers_seen = alive


func _army_val(tm: int) -> int:
	var v := 0.0
	for u in g.army(tm):
		v += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("tension", u.d.get("cost2", 0)))
	return int(v)


func _owl_kills() -> Array:
	var b = cw.get("btc")
	return b.kill_log if b != null else []


func _snapshot() -> Dictionary:
	var ok := 0
	var ow := 0
	var ob := 0
	for k in _owl_kills():
		ok += int(k[2])
		if g.workers(opt).size() >= 0 and String(k[1]) in ["labourer", "grub", "winder"]:
			ow += 1
		elif Defs.BUILDINGS.has(String(k[1])):
			ob += 1
	return {"cw_workers": g.worker_count(cwt), "cw_earned": int(g.stats[cwt]["gold"]), "cw_army": _army_val(cwt),
		"cw_halls": g.halls_of(cwt, false).size(), "op_workers": g.worker_count(opt), "op_earned": int(g.stats[opt]["gold"]),
		"op_army": _army_val(opt), "op_workers_lost": op_workers_lost, "cw_killed": int(g.stats[cwt]["value_killed"]),
		"cw_lost": int(g.stats[opt]["value_killed"]), "op_bld_lost": int(g.stats[opt]["bld_lost"]),
		"owl_killed": ok, "owl_workers": ow, "owl_buildings": ob}


func _print_line() -> void:
	var counts := {}
	for u in g.units:
		if not u.dead and u.team == cwt and not u.is_worker():
			counts[u.kind] = counts.get(u.kind, 0) + 1
	var b = cw.get("btc")
	print("t=%s  CW winders %d cogs %d (earned %d) T %d supply %d/%d army %s owls:%s | %s workers %d army %d lost workers %d" % [
		_mmss(g.clock), g.worker_count(cwt), int(g.players[cwt]["gold"]), int(g.stats[cwt]["gold"]), int(g.tension(cwt)),
		g.supply_used(cwt), int(g.players[cwt]["cap"]), str(counts), (b.phase if b != null else "-"), vs, g.worker_count(opt),
		_army_val(opt), op_workers_lost])


func _finish() -> void:
	var end := _snapshot()
	var who := "none"
	if g.over:
		who = "clockwork" if g.winner == cwt else (vs if g.winner == opt else "none")
	print("--- %s seed %d  Clockwork %s (%s) v %s %s (%s)" % [map, seed_, cw_plan, dcw, vs, op, dop])
	for k in ["escapement", "aviary", "swift", "owl_tech", "owl1", "owl3", "raid", "sortie", "strike", "hall2_laid", "hall2"]:
		print("  %-11s %s" % [k, _mmss(float(ms.get(k, -1.0)))])
	for m in ["240", "360", "480", "600"]:
		if marks.has(m):
			print("  at %s: %s" % [_mmss(float(m)), str(marks[m])])
	print("  end %s: winner %s, %s" % [_mmss(g.clock), who, str(end)])
	for k in _owl_kills():
		print("  OWL KILL %s %s %d" % [_mmss(float(k[0])), String(k[1]), int(k[2])])
	if cw.get("sp_log") != null:
		for e in cw.sp_log:
			print("  [%s] %s" % [_mmss(float(e[0])), String(e[1])])
	if json_path != "":
		var f := FileAccess.open(json_path, FileAccess.READ_WRITE) if FileAccess.file_exists(json_path) else FileAccess.open(json_path, FileAccess.WRITE)
		f.seek_end()
		var b = cw.get("btc")
		f.store_line(JSON.stringify({"map": map, "seed": seed_, "cw": cw_plan, "vs": vs, "op": op, "dcw": dcw, "dop": dop,
			"ms": ms, "marks": marks, "end": end, "winner": who, "clock": g.clock, "kills": _owl_kills(),
			"sorties": (b.sorties if b != null else 0)}))
		f.close()
	if check:
		_check(float(ms.get("owl1", 9999.0)) <= OWL_BY, "the first Ticking Owl by %s: %s" % [_mmss(OWL_BY), _mmss(float(ms.get("owl1", -1.0)))])
		_check(float(ms.get("raid", 9999.0)) <= RAID_BY, "the Owl raid is ready by %s: %s" % [_mmss(RAID_BY), _mmss(float(ms.get("raid", -1.0)))])
		_check(float(ms.get("sortie", 9999.0)) <= OUT_BY, "the first Owl sortie by %s: %s" % [_mmss(OUT_BY), _mmss(float(ms.get("sortie", -1.0)))])
		var m6: Dictionary = marks.get("360", end)
		_check(int(m6.get("cw_workers", 0)) >= WORKERS_6, "the economy grows behind it: %d Winders at 6:00 (want %d+)" % [int(m6.get("cw_workers", 0)), WORKERS_6])
		_check(float(ms.get("hall2_laid", 9999.0)) <= HALL_BY, "a second Clocktower laid by %s: %s" % [_mmss(HALL_BY), _mmss(float(ms.get("hall2_laid", -1.0)))])
		print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
