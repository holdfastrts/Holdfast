extends SceneTree
## cw-builds-b (docs/clockwork_builds_b.md): the Clockwork computer's PENDULUMS and HEAVY WORKS PUSH plans in a game against a
## Brood or Crown computer, measured:
##   godot --headless --fixed-fps 30 --script res://tools/test_clockwork_builds_b.gd -- \
##       [map:greenhold seed:11 cw:pendulum foe:brood fp:rush dcw:hard dfoe:hard until:600 check:pendulum|heavy json:<file>]
##   (`cwnew:off` plays a slot of these plans as the old computer's Balanced, for comparisons; cw:balanced or cw:rush play the
##   old plans themselves)
## Prints: the milestones (Light Works, Mainspring, Escapement, Heavy Works laid and standing, the 1st/2nd/3rd Pendulum, the
## 1st/2nd Ballista, the Great Winder, the second Clocktower laid, the first push out, the first siege, the first Brood
## Rootmaw/turtle killed, the Mother killed), a line every 30 s, the numbers at 4, 6, 8 and 10 minutes (Winders, cogs
## earned, army value both sides, value killed and lost, the Brood's economy lost: Rootmaws, Mound Turtles, grubs) and the
## winner. check:pendulum (the test, Greenhold 11 v Hard Brood Rush, until:540): the Heavy Works by HEAVY_BY, two
## Pendulums by PEND2_BY, alive at 6:00 with WORKERS_6 Winders, a second Clocktower laid by HALL_BY, the push out by PUSH_BY.
## check:heavy (Greenhold 11 v Hard Crown Balanced, until:600): two Ballistas and the Great Winder by BAL2_BY, a second
## Clocktower by HALL_BY, the push out by PUSH_BY_HEAVY, WORKERS_6 Winders at 6:00.
const HEAVY_BY := 270.0
const PEND2_BY := 390.0
const WORKERS_6 := 16
const HALL_BY := 450.0
const PUSH_BY := 540.0
const BAL2_BY := 480.0
const PUSH_BY_HEAVY := 600.0
var main: Node
var g
var t := 0.0
var map := "greenhold"
var seed_ := 11
var cw_plan := "pendulum"
var foe_fac := "brood"
var foe_plan := "rush"
var dcw := "hard"
var dfoe := "hard"
var until := 600.0
var check := ""
var json_path := ""
var cwt := 0
var ft := 1
var cw = null
var ms := {}
var marks := {}
var next_print := 30.0
var fails := 0
var _ids := {}                  # kind -> {instance id: true} made by the Clockwork
var _brood_alive := {}          # id -> kind (the Brood's economy seen alive)
var brood_lost := {"rootmaw": 0, "mound_turtle": 0, "grub": 0, "tyrannosaur": 0}
var foe_workers_lost := 0
var _foe_workers := {}


func _initialize() -> void:
	if OS.get_cmdline_user_args().is_empty():
		check = "pendulum"      # (qa-tests, 2026-11-08: a bare run is the test, so the suite gets a verdict)
		until = 540.0
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"cw": cw_plan = kv[1]
			"foe": foe_fac = kv[1]
			"fp": foe_plan = kv[1]
			"dcw": dcw = kv[1]
			"dfoe": dfoe = kv[1]
			"until": until = float(kv[1])
			"check": check = kv[1]
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
		ms[k] = snappedf(g.clock, 0.1)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": dcw, "faction": "clockwork", "colour": 0, "side": 0, "strategy": cw_plan},
			{"who": dfoe, "faction": foe_fac, "colour": 1, "side": 1, "strategy": foe_plan}]})
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
	for m in [240.0, 360.0, 480.0, 600.0, 720.0, 900.0]:
		if g.clock >= m and not marks.has(str(int(m))):
			marks[str(int(m))] = _snapshot()
	if g.clock >= until or g.over:
		_finish()
		return true
	return false


func _made(u: Unit) -> int:
	if not _ids.has(u.kind):
		_ids[u.kind] = {}
	_ids[u.kind][u.get_instance_id()] = true
	return (_ids[u.kind] as Dictionary).size()


func _look() -> void:
	for b in g.buildings:
		if b.team != cwt or b.dead:
			continue
		if not b.built:
			if b.kind == "heavy_works":
				_mark("heavy_laid")
			elif b.kind == "clocktower":
				_mark("hall2_laid")
			continue
		match b.kind:
			"movement_works": _mark("works")
			"mainspring": _mark("mainspring")
			"escapement": _mark("escapement")
			"heavy_works": _mark("heavy")
			"clocktower":
				if g.halls_of(cwt).size() >= 2:
					_mark("hall2")
	for u in g.units:
		if u.dead:
			continue
		if u.team == cwt:
			match u.kind:
				Defs.PENDULUM:
					var n := _made(u)
					if n <= 3:
						_mark("pend%d" % n)
				Defs.BALLISTA_KIND:
					var n2 := _made(u)
					if n2 <= 2:
						_mark("bal%d" % n2)
				Defs.GREAT_WINDER_KIND:
					_made(u)
					_mark("gw")
				Defs.SPRINGER, "clock_soldier", Defs.NETTER, Defs.CUCKOO:
					_made(u)
	# the foe's economy: lost = seen alive before, now gone or dead
	var alive := {}
	var wk := {}
	for u in g.units:
		if u.team != ft or u.dead:
			continue
		if u.is_worker():
			wk[u.get_instance_id()] = true
		if brood_lost.has(u.kind):
			alive[u.get_instance_id()] = u.kind
	for id in _brood_alive:
		if not alive.has(id):
			var k: String = _brood_alive[id]
			brood_lost[k] = int(brood_lost[k]) + 1
			if k == "rootmaw" or k == "mound_turtle":
				_mark("econ_kill")
	_brood_alive = alive
	for id in _foe_workers:
		if not wk.has(id):
			foe_workers_lost += 1
	_foe_workers = wk
	if cw.get("push") != null and cw.push != null:
		if cw.push.pushes >= 1:
			_mark("push")
		if int(cw.push.stats["sieges"]) >= 1:
			_mark("siege")
		if int(cw.push.stats["pieces"]) >= 1:
			_mark("piece")


func _army_val(tm: int) -> int:
	var v := 0.0
	for u in g.army(tm):
		v += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("tension", u.d.get("cost2", 0)))
	return int(v)


func _snapshot() -> Dictionary:
	return {"cw_workers": g.worker_count(cwt), "cw_earned": int(g.stats[cwt]["gold"]), "cw_army": _army_val(cwt),
		"cw_halls": g.halls_of(cwt, false).size(), "foe_workers": g.worker_count(ft), "foe_earned": int(g.stats[ft]["gold"]),
		"foe_army": _army_val(ft), "cw_killed": int(g.stats[cwt]["value_killed"]), "cw_lost": int(g.stats[ft]["value_killed"]),
		"foe_workers_lost": foe_workers_lost, "brood_lost": brood_lost.duplicate(), "foe_bld_lost": int(g.stats[ft].get("bld_lost", 0)),
		"pends": _alive(Defs.PENDULUM), "bals": _alive(Defs.BALLISTA_KIND), "gws": _alive(Defs.GREAT_WINDER_KIND),
		"push": (cw.push.phase if cw.get("push") != null and cw.push != null else "-")}


func _alive(kind: String) -> int:
	return g.units.filter(func(u: Unit) -> bool: return u.team == cwt and not u.dead and u.kind == kind).size()


func _print_line() -> void:
	var counts := {}
	for u in g.units:
		if not u.dead and u.team == cwt and not u.is_worker():
			counts[u.kind] = counts.get(u.kind, 0) + 1
	var ph: String = cw.push.phase if cw.get("push") != null and cw.push != null else "-"
	print("t=%s  CW winders %d cogs %d (earned %d) T %d supply %d/%d army %d %s push %s | foe workers %d army %d | killed %d lost %d" % [
		_mmss(g.clock), g.worker_count(cwt), int(g.players[cwt]["gold"]), int(g.stats[cwt]["gold"]), int(g.players[cwt]["res2"]),
		g.supply_used(cwt), int(g.players[cwt]["cap"]), _army_val(cwt), str(counts), ph, g.worker_count(ft), _army_val(ft),
		int(g.stats[cwt]["value_killed"]), int(g.stats[ft]["value_killed"])])


func _finish() -> void:
	var end := _snapshot()
	var who := "none"
	if g.over:
		who = "clockwork" if g.winner == cwt else (foe_fac if g.winner == ft else "none")
	if g.over:
		_mark("over")
	var plan_now: String = cw.strategy
	print("--- %s seed %d  Clockwork %s (%s) v %s %s (%s)%s" % [map, seed_, plan_now, dcw, foe_fac, foe_plan, dfoe,
		"  [cwnew:off]" if OS.get_cmdline_user_args().has("cwnew:off") else ""])
	for k in ["works", "mainspring", "escapement", "heavy_laid", "heavy", "pend1", "pend2", "pend3", "bal1", "bal2", "gw", "hall2_laid", "hall2", "push", "siege", "piece", "econ_kill"]:
		print("  %-11s %s" % [k, _mmss(float(ms.get(k, -1.0)))])
	for m in ["240", "360", "480", "600", "720", "900"]:
		if marks.has(m):
			print("  at %s: %s" % [_mmss(float(m)), str(marks[m])])
	print("  end %s: winner %s, %s" % [_mmss(g.clock), who, str(end)])
	if cw.get("push") != null and cw.push != null:
		print("  push stats %s" % str(cw.push.stats))
	if cw.get("sp_log") != null:
		for e in cw.sp_log:
			print("  [%s] %s" % [_mmss(float(e[0])), String(e[1])])
	if json_path != "":
		var f := FileAccess.open(json_path, FileAccess.READ_WRITE) if FileAccess.file_exists(json_path) else FileAccess.open(json_path, FileAccess.WRITE)
		f.seek_end()
		f.store_line(JSON.stringify({"map": map, "seed": seed_, "cw": cw_plan, "foe": foe_fac, "fp": foe_plan, "dcw": dcw, "dfoe": dfoe,
			"old": OS.get_cmdline_user_args().has("cwnew:off"), "ms": ms, "marks": marks, "end": end, "winner": who, "clock": g.clock,
			"push": (cw.push.stats if cw.get("push") != null and cw.push != null else {})}))
		f.close()
	if check == "pendulum":
		_check(float(ms.get("heavy_laid", 9999.0)) <= HEAVY_BY, "the Heavy Works laid by %s: %s" % [_mmss(HEAVY_BY), _mmss(float(ms.get("heavy_laid", -1.0)))])
		_check(float(ms.get("pend2", 9999.0)) <= PEND2_BY, "two Pendulums out by %s: %s" % [_mmss(PEND2_BY), _mmss(float(ms.get("pend2", -1.0)))])
		var m6: Dictionary = marks.get("360", end)
		_check(int(m6.get("cw_workers", 0)) >= WORKERS_6, "alive with %d Winders at 6:00 (want %d+)" % [int(m6.get("cw_workers", 0)), WORKERS_6])
		_check(float(ms.get("hall2_laid", 9999.0)) <= HALL_BY, "a second Clocktower laid by %s: %s" % [_mmss(HALL_BY), _mmss(float(ms.get("hall2_laid", -1.0)))])
		_check(float(ms.get("push", 9999.0)) <= PUSH_BY, "the push goes out by %s: %s" % [_mmss(PUSH_BY), _mmss(float(ms.get("push", -1.0)))])
		_check(who != foe_fac, "the Clockwork is still in the game: winner %s" % who)
	elif check == "heavy":
		_check(float(ms.get("bal2", 9999.0)) <= BAL2_BY and float(ms.get("gw", 9999.0)) <= BAL2_BY, "two Ballistas and the Great Winder by %s: %s, %s" % [_mmss(BAL2_BY), _mmss(float(ms.get("bal2", -1.0))), _mmss(float(ms.get("gw", -1.0)))])
		var m6b: Dictionary = marks.get("360", end)
		_check(int(m6b.get("cw_workers", 0)) >= WORKERS_6, "the economy grows behind it: %d Winders at 6:00 (want %d+)" % [int(m6b.get("cw_workers", 0)), WORKERS_6])
		_check(float(ms.get("hall2_laid", 9999.0)) <= HALL_BY, "a second Clocktower laid by %s: %s" % [_mmss(HALL_BY), _mmss(float(ms.get("hall2_laid", -1.0)))])
		_check(float(ms.get("push", 9999.0)) <= PUSH_BY_HEAVY, "the push goes out by %s: %s" % [_mmss(PUSH_BY_HEAVY), _mmss(float(ms.get("push", -1.0)))])
	if check != "":
		print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
