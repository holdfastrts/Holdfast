extends SceneTree
## The Clockwork computer's SPRINGER TIMING against the Crown computer (docs/clockwork_ai_rebuild.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_clockwork_springer_timing.gd -- \
##       [map:greenhold seed:11 cw:springer cr:balanced dcw:hard dcr:hard until:600 swap:0 check:1 json:<file>]
##   (`cwnew:off` on the command line plays the Clockwork's Springer timing through the old computer: Balanced)
## A Clockwork computer (plan `cw`, default springer) against a Crown computer (plan `cr`) for `until` game seconds, and
## prints:
##  - the milestones: Light Works, Mainspring, Escapement, Clock Aviary, the first Swift, HIGH LEAP, the 4th Springer,
##    READY (the 4th Springer + HIGH LEAP + a Swift), the attack leaving, the first leap up, the second Clocktower;
##  - every 30 s: Winders, cogs earned, Tension, army, the Crown's Labourers;
##  - at 6:00 and 8:00: the Clockwork's Winders, cogs earned and army value; the Crown's Labourers lost;
##  - the end: winner (or none), value killed and lost each way.
## check:1 (the test): READY by READY_BY, the attack leaves, the attack kills at least KILL_MIN Crown workers or
## buildings worth BLD_MIN by 6:30 in this game, at least WORKERS_6 Winders at 6:00, a second Clocktower laid by HALL_BY,
## and no script error (the boot check covers parse errors).
## json:<file> appends one line with every number (the study: docs/clockwork_ai_rebuild.md).
const READY_BY := 330.0
const KILL_MIN := 4
const BLD_MIN := 300
const WORKERS_6 := 16
const HALL_BY := 450.0
var main: Node
var g
var t := 0.0
var map := "greenhold"
var seed_ := 11
var cw_plan := "springer"
var cr_plan := "balanced"
var dcw := "hard"
var dcr := "hard"
var until := 600.0
var swap := false
var check := false
var json_path := ""
var cwt := 0
var crt := 1
var cw = null
var ms := {}                    # milestone -> clock
var marks := {}                 # "360" -> {...}
var next_print := 30.0
var crown_workers_seen := {}    # instance id -> true (alive when last looked)
var crown_workers_lost := 0
var lost_at := {}               # clock mark -> crown workers lost by then
var fails := 0
var sp_made := 0
var _sp_ids := {}
const LEVELS := ["easy", "normal", "hard", "brutal"]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"cw": cw_plan = kv[1]
			"cr": cr_plan = kv[1]
			"dcw": dcw = kv[1]
			"dcr": dcr = kv[1]
			"until": until = float(kv[1])
			"swap": swap = kv[1] == "1"
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
		var a := {"who": dcw, "faction": "clockwork", "colour": 0, "side": 0, "strategy": cw_plan}
		var b := {"who": dcr, "faction": "crown", "colour": 1, "side": 1, "strategy": cr_plan}
		if swap:
			a["side"] = 1
			b["side"] = 0
			cwt = 0
			crt = 1
		main.start({"map": map, "seed": seed_, "slots": [a, b]})
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
	for m in [300.0, 360.0, 480.0, 600.0]:
		if g.clock >= m and not marks.has(str(int(m))):
			marks[str(int(m))] = _snapshot()
	if g.clock >= until or g.over:
		_finish()
		return true
	return false


func _look() -> void:
	for b in g.buildings:
		if b.team != cwt or b.dead or not b.built:
			continue
		match b.kind:
			"movement_works": _mark("works")
			"mainspring": _mark("mainspring")
			"escapement": _mark("escapement")
			"cuckoo_house": _mark("aviary")
			"clocktower":
				if g.halls_of(cwt).size() >= 2:
					_mark("hall2")
	for b in g.buildings:
		if b.team == cwt and not b.dead and b.kind == "clocktower" and not b.built:
			_mark("hall2_laid")
	if g.has_tech(cwt, "high_leap"):
		_mark("high_leap")
	var sp := 0
	for u in g.units:
		if u.dead or u.team != cwt:
			continue
		if u.kind == "springer":
			sp += 1
			if not _sp_ids.has(u.get_instance_id()):
				_sp_ids[u.get_instance_id()] = true
				sp_made += 1
		elif u.kind == "cuckoo":
			_mark("swift")
	if sp_made >= 4:
		_mark("springer4")
	if ms.has("springer4") and ms.has("high_leap") and ms.has("swift"):
		_mark("ready")
	if cw.get("sp_log") != null:
		for e in cw.sp_log:
			var k := String(e[1])
			if k.begins_with("attack:"):
				_mark("attack")
			elif k.begins_with("leap:"):
				_mark("leap")
	# the Crown's workers: lost = seen alive before, now gone or dead
	var alive := {}
	for u in g.units:
		if u.team == crt and not u.dead and u.is_worker():
			alive[u.get_instance_id()] = true
	for id in crown_workers_seen:
		if not alive.has(id):
			crown_workers_lost += 1
	crown_workers_seen = alive


func _army_val(tm: int) -> int:
	var v := 0.0
	for u in g.army(tm):
		v += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("tension", u.d.get("cost2", 0)))
	return int(v)


func _snapshot() -> Dictionary:
	return {"cw_workers": g.worker_count(cwt), "cw_earned": int(g.stats[cwt]["gold"]), "cw_army": _army_val(cwt),
		"cw_halls": g.halls_of(cwt, false).size(), "cr_workers": g.worker_count(crt), "cr_earned": int(g.stats[crt]["gold"]),
		"cr_army": _army_val(crt), "cr_workers_lost": crown_workers_lost, "cw_killed": int(g.stats[cwt]["value_killed"]),
		"cw_lost": int(g.stats[crt]["value_killed"]), "cr_bld_lost": int(g.stats[crt]["bld_lost"])}


func _print_line() -> void:
	var counts := {}
	for u in g.units:
		if not u.dead and u.team == cwt and not u.is_worker():
			counts[u.kind] = counts.get(u.kind, 0) + 1
	print("t=%s  CW winders %d cogs %d (earned %d) T %d supply %d/%d army %s | Crown labourers %d army %d lost workers %d" % [
		_mmss(g.clock), g.worker_count(cwt), int(g.players[cwt]["gold"]), int(g.stats[cwt]["gold"]), int(g.players[cwt]["res2"]),
		g.supply_used(cwt), int(g.players[cwt]["cap"]), str(counts), g.worker_count(crt), _army_val(crt), crown_workers_lost])


func _finish() -> void:
	var end := _snapshot()
	var who := "none"
	if g.over:
		who = "clockwork" if g.winner == cwt else ("crown" if g.winner == crt else "none")
	print("--- %s seed %d  Clockwork %s (%s) v Crown %s (%s)%s" % [map, seed_, cw_plan, dcw, cr_plan, dcr,
		"  [cwnew:off]" if OS.get_cmdline_user_args().has("cwnew:off") else ""])
	for k in ["works", "mainspring", "escapement", "aviary", "swift", "high_leap", "springer4", "ready", "attack", "leap", "hall2_laid", "hall2"]:
		print("  %-11s %s" % [k, _mmss(float(ms.get(k, -1.0)))])
	for m in ["300", "360", "480", "600"]:
		if marks.has(m):
			print("  at %s: %s" % [_mmss(float(m)), str(marks[m])])
	print("  end %s: winner %s, %s" % [_mmss(g.clock), who, str(end)])
	if cw.get("sp_log") != null:
		for e in cw.sp_log:
			print("  [%s] %s" % [_mmss(float(e[0])), String(e[1])])
	if json_path != "":
		var f := FileAccess.open(json_path, FileAccess.READ_WRITE) if FileAccess.file_exists(json_path) else FileAccess.open(json_path, FileAccess.WRITE)
		f.seek_end()
		f.store_line(JSON.stringify({"map": map, "seed": seed_, "cw": cw_plan, "cr": cr_plan, "dcw": dcw, "dcr": dcr,
			"old": OS.get_cmdline_user_args().has("cwnew:off"), "ms": ms, "marks": marks, "end": end, "winner": who, "clock": g.clock}))
		f.close()
	if check:
		_check(float(ms.get("ready", 9999.0)) <= READY_BY, "READY (4 Springers, HIGH LEAP, a Swift) by %s: %s" % [_mmss(READY_BY), _mmss(float(ms.get("ready", -1.0)))])
		_check(ms.has("attack"), "the Springer attack leaves: %s" % _mmss(float(ms.get("attack", -1.0))))
		var m390: Dictionary = marks.get("360", end)
		var hurt: bool = int(end["cr_workers_lost"]) >= KILL_MIN or int(end["cw_killed"]) >= BLD_MIN
		_check(hurt, "the attack hurts: %d Crown workers lost, %d value killed" % [int(end["cr_workers_lost"]), int(end["cw_killed"])])
		_check(int(m390.get("cw_workers", 0)) >= WORKERS_6, "the economy grows behind it: %d Winders at 6:00 (want %d+)" % [int(m390.get("cw_workers", 0)), WORKERS_6])
		_check(float(ms.get("hall2_laid", 9999.0)) <= HALL_BY, "a second Clocktower laid by %s: %s" % [_mmss(HALL_BY), _mmss(float(ms.get("hall2_laid", -1.0)))])
		print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
