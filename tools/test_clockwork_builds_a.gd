extends SceneTree
## The Clockwork computer's CLOCK SOLDIER RUSH and TURRET TURTLE (cw-builds-a; scripts/ai_cw_builds_a.gd,
## docs/clockwork_builds_a.md) against the Crown or the Brood computer:
##   godot --headless --fixed-fps 30 --script res://tools/test_clockwork_builds_a.gd -- \
##       [cw:cs_rush|turtle|rush|balanced|economy|springer foe:crown|brood map:greenhold seed:11 fp:balanced dcw:hard dfoe:hard
##        until:600 check:1 json:<file>]
## Prints the milestones (Light Works, the 1st and 5th Clock Soldier, the rush going out, arriving, its verdict; the turrets;
## the second Clocktower laid and standing; the first wave of the old plans), a line every 30 s, the numbers at 4, 6, 8
## and 10 minutes (Winders, cogs earned, army, the enemy's workers and their losses, value killed and lost) and the plan's
## decisions. check:1 is the test for cw:cs_rush (until:480 is enough) or cw:turtle (until:400), Greenhold seed 11 against the
## Hard Crown (the thresholds below); json:<file> appends one line (tools/clockwork_builds_a_report.py makes the tables).
const RUSH_BY := 225.0           # cs_rush: the party goes out by 3:45
const RUSH_JUDGED_BY := 420.0    # ... and is judged by 7:00
const RUSH_WORKERS_6 := 14       # ... and the economy is back on: Winders at 6:00
const RUSH_HALL_BY := 480.0      # ... a second Clocktower laid by 8:00
const TURRETS_BY := 210.0        # turtle: two turrets at the ramp laid by 3:30
const T_HALL_BY := 240.0         # turtle: the second Clocktower laid by 4:00
const T_WORKERS_6 := 22          # turtle: Winders at 6:00
var main: Node
var g
var t := 0.0
var map := "greenhold"
var seed_ := 11
var cw_plan := "cs_rush"
var foe_fac := "crown"
var fp := "balanced"
var dcw := "hard"
var dfoe := "hard"
var until := 600.0
var check := false
var json_path := ""
var cwt := 0
var ft := 1
var cw = null
var ms := {}
var marks := {}
var next_print := 30.0
var seen_w := {}
var foe_w_lost := 0
var my_seen := {}
var my_w_lost := 0
var fails := 0
var _cs := {}
var cs_made := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"cw": cw_plan = kv[1]
			"foe": foe_fac = kv[1]
			"fp": fp = kv[1]
			"dcw": dcw = kv[1]
			"dfoe": dfoe = kv[1]
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
		main.start({"map": map, "seed": seed_, "hidden_plans": true, "slots": [
			{"who": dcw, "faction": "clockwork", "colour": 0, "side": 0, "strategy": cw_plan},
			{"who": dfoe, "faction": foe_fac, "colour": 1, "side": 1, "strategy": fp}]})
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
	var works := 0
	var turrets := 0
	for b in g.buildings:
		if b.team != cwt or b.dead:
			continue
		if not b.built:
			if b.kind == "clocktower":
				_mark("hall2_laid")
			continue
		match b.kind:
			"movement_works":
				works += 1
			"ratchet_turret":
				turrets += 1
			"mainspring": _mark("mainspring")
			"escapement": _mark("escapement")
			"clocktower":
				if g.halls_of(cwt).size() >= 2:
					_mark("hall2")
	for b in g.buildings:
		if b.team == cwt and not b.dead and b.kind == "ratchet_turret":
			_mark("turret_laid")
			if b.built:
				_mark("turret1")
	if works >= 1:
		_mark("works")
	if works >= 2:
		_mark("works2")
	if turrets >= 2:
		_mark("turret2")
	if turrets >= 3:
		_mark("turret3")
	for u in g.units:
		if u.dead or u.team != cwt:
			continue
		if u.kind == "clock_soldier" and not _cs.has(u.get_instance_id()):
			_cs[u.get_instance_id()] = true
			cs_made += 1
	if cs_made >= 1:
		_mark("cs1")
	if cs_made >= 5:
		_mark("cs5")
	if cw.get("_first_wave"):
		_mark("wave1")
	if cw.get("sp_log") != null:
		for e in cw.sp_log:
			var k := String(e[1])
			if k.begins_with("rush: the Clock"):
				_mark("rush")
			elif k.begins_with("rush: at the"):
				_mark("arrive")
			elif k.begins_with("rush: FAILED"):
				_mark("failed")
			elif k.begins_with("rush: SUCCEEDED"):
				_mark("succeeded")
			elif k.begins_with("lays a Ratchet Turret (ramp)") and not ms.has("tr1_laid"):
				ms["tr1_laid"] = float(e[0])
			elif k.begins_with("lays a Ratchet Turret (ramp)"):
				if float(e[0]) > float(ms["tr1_laid"]):
					_mark("tr2_laid")
	var alive := {}
	for u in g.units:
		if u.team == ft and not u.dead and u.is_worker():
			alive[u.get_instance_id()] = true
	for id in seen_w:
		if not alive.has(id):
			foe_w_lost += 1
	seen_w = alive
	var mine := {}
	for u in g.units:
		if u.team == cwt and not u.dead and u.is_worker():
			mine[u.get_instance_id()] = true
	for id in my_seen:
		if not mine.has(id):
			my_w_lost += 1
	my_seen = mine


func _army_val(tm: int) -> int:
	var v := 0.0
	for u in g.army(tm):
		v += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("tension", u.d.get("cost2", 0)))
	return int(v)


func _snapshot() -> Dictionary:
	return {"cw_workers": g.worker_count(cwt), "cw_earned": int(g.stats[cwt]["gold"]), "cw_army": _army_val(cwt),
		"cw_halls": g.halls_of(cwt, false).size(), "foe_workers": g.worker_count(ft), "foe_earned": int(g.stats[ft]["gold"]),
		"foe_army": _army_val(ft), "foe_workers_lost": foe_w_lost, "cw_workers_lost": my_w_lost,
		"cw_killed": int(g.stats[cwt]["value_killed"]), "cw_lost": int(g.stats[ft]["value_killed"]),
		"foe_bld_lost": int(g.stats[ft]["bld_lost"]), "cw_bld_lost": int(g.stats[cwt]["bld_lost"])}


func _print_line() -> void:
	var counts := {}
	for u in g.units:
		if not u.dead and u.team == cwt and not u.is_worker():
			counts[u.kind] = counts.get(u.kind, 0) + 1
	print("t=%s  CW winders %d cogs %d (earned %d) supply %d/%d army %s | foe workers %d army %d lost workers %d | killed %d lost %d" % [
		_mmss(g.clock), g.worker_count(cwt), int(g.players[cwt]["gold"]), int(g.stats[cwt]["gold"]),
		g.supply_used(cwt), int(g.players[cwt]["cap"]), str(counts), g.worker_count(ft), _army_val(ft), foe_w_lost,
		int(g.stats[cwt]["value_killed"]), int(g.stats[ft]["value_killed"])])


func _finish() -> void:
	var end := _snapshot()
	var who := "none"
	if g.over:
		who = "clockwork" if g.winner == cwt else ("foe" if g.winner == ft else "none")
	print("--- %s seed %d  Clockwork %s (%s) v %s %s (%s)" % [map, seed_, cw_plan, dcw, foe_fac, fp, dfoe])
	for k in ["works", "works2", "cs1", "cs5", "rush", "arrive", "failed", "succeeded", "wave1", "tr1_laid", "turret1", "tr2_laid", "turret2", "turret3", "hall2_laid", "hall2", "mainspring", "escapement"]:
		print("  %-11s %s" % [k, _mmss(float(ms.get(k, -1.0)))])
	for m in ["240", "360", "480", "600"]:
		if marks.has(m):
			print("  at %s: %s" % [_mmss(float(m)), str(marks[m])])
	print("  end %s: winner %s, %s" % [_mmss(g.clock), who, str(end)])
	if cw.get("sp_log") != null:
		for e in cw.sp_log:
			print("  [%s] %s" % [_mmss(float(e[0])), String(e[1])])
	if json_path != "":
		var f := FileAccess.open(json_path, FileAccess.READ_WRITE) if FileAccess.file_exists(json_path) else FileAccess.open(json_path, FileAccess.WRITE)
		f.seek_end()
		f.store_line(JSON.stringify({"map": map, "seed": seed_, "cw": cw_plan, "foe": foe_fac, "fp": fp, "dcw": dcw, "dfoe": dfoe,
			"ms": ms, "marks": marks, "end": end, "winner": who, "clock": g.clock}))
		f.close()
	if check:
		var m6: Dictionary = marks.get("360", end)
		if cw_plan == "cs_rush":
			_check(float(ms.get("rush", 9999.0)) <= RUSH_BY, "the rush goes out by %s: %s" % [_mmss(RUSH_BY), _mmss(float(ms.get("rush", -1.0)))])
			_check(ms.has("arrive"), "it reaches the enemy's base: %s" % _mmss(float(ms.get("arrive", -1.0))))
			var judged := minf(float(ms.get("failed", 9999.0)), float(ms.get("succeeded", 9999.0)))
			_check(judged <= RUSH_JUDGED_BY, "it is judged by %s: %s" % [_mmss(RUSH_JUDGED_BY), _mmss(judged if judged < 9999.0 else -1.0)])
			_check(int(m6.get("cw_workers", 0)) >= RUSH_WORKERS_6, "the economy goes on: %d Winders at 6:00 (want %d+)" % [int(m6.get("cw_workers", 0)), RUSH_WORKERS_6])
			_check(float(ms.get("hall2_laid", 9999.0)) <= RUSH_HALL_BY, "a second Clocktower laid by %s: %s" % [_mmss(RUSH_HALL_BY), _mmss(float(ms.get("hall2_laid", -1.0)))])
		elif cw_plan == "turtle":
			_check(float(ms.get("tr2_laid", 9999.0)) <= TURRETS_BY, "two turrets at the ramp laid by %s: %s, %s" % [_mmss(TURRETS_BY), _mmss(float(ms.get("tr1_laid", -1.0))), _mmss(float(ms.get("tr2_laid", -1.0)))])
			_check(float(ms.get("hall2_laid", 9999.0)) <= T_HALL_BY, "a FAST second Clocktower laid by %s: %s" % [_mmss(T_HALL_BY), _mmss(float(ms.get("hall2_laid", -1.0)))])
			_check(int(m6.get("cw_workers", 0)) >= T_WORKERS_6, "it out-econs: %d Winders at 6:00 (want %d+)" % [int(m6.get("cw_workers", 0)), T_WORKERS_6])
			_check(int(m6.get("cw_bld_lost", 0)) == 0, "safe: no building lost by 6:00 (%d)" % int(m6.get("cw_bld_lost", 0)))
		print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
