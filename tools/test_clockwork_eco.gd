extends SceneTree
## THE CLOCKWORK'S ECONOMY AND BALANCED OPENINGS (clockwork-eco; scripts/ai_cw_eco.gd, scripts/clock_sites.gd,
## docs/clockwork_eco.md): one game, a Clockwork computer against the Crown or the Brood computer.
##   godot --headless --fixed-fps 30 --script res://tools/test_clockwork_eco.gd -- \
##       [cw:economy|balanced foe:crown|brood fp:economy map:cinder_steps seed:11 dcw:hard dfoe:hard until:600 check:1
##        json:<file>] [cweco:off] [clocksites:off]
## Prints the milestones (the 2nd Clocktower laid and standing, the Mainspring, the first Light Works, the first Clock
## Soldier, the rush reaction), a line a minute (Winders, cogs earned, army, both sides) and the plan's decisions.
## `cweco:off` plays the old computer (the shared Economy/Balanced) for the "before" columns; `clocksites:off` the old
## hall spot. json:<file> appends one line (tools/clockwork_eco_report.py makes the tables).
## check:1 is the test (until:300 is enough):
##  - no Light Works and no Clock Soldier before the 2nd Clocktower is laid, unless the scout saw a rush first;
##  - the 2nd Clocktower laid by HALL_BY (2:45) when no rush was seen;
##  - WINDERS_4 Winders or more at 4:00 (set from the coached games: docs/clockwork_eco.md);
##  - the 2nd Clocktower's ring fits: RING_MIN or more of its ring's buildings (ClockSites.ring_fit) at the spot it took.
## rush:1 makes the foe a scripted early rush (the Brood's fastest plan, xrush; the Crown's Rush): then the test wants the
## rush answered (a Light Works laid within RUSH_ANSWER s of the evidence) and the Clockwork alive with a Clocktower at the end.
const HALL_BY := 165.0
const WINDERS_4 := 19
const RING_MIN := 7
const RUSH_ANSWER := 45.0
var main: Node
var g
var t := 0.0
var map := "cinder_steps"
var seed_ := 11
var cw_plan := "economy"
var foe_fac := "brood"
var fp := "economy"
var dcw := "hard"
var dfoe := "hard"
var until := 600.0
var check := false
var rush := false
var json_path := ""
var cwt := 0
var ft := 1
var cw = null
var ms := {}
var mins := {}
var fails := 0
var hall2_cell := Vector2i(-1, -1)
var hall2_ring := -1
var hall2_outer := -1.0
var _cs := {}


func _initialize() -> void:
	if OS.get_cmdline_user_args().is_empty():
		check = true      # (qa-tests, 2026-11-08: a bare run is the test, so the suite gets a verdict)
		until = 300.0
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
			"rush": rush = kv[1] == "1"
			"json": json_path = kv[1]
	if rush:
		fp = "xrush" if foe_fac == "brood" else "rush"      # (the Brood's fastest plan; the Crown's Rush)
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
	var m := int(g.clock / 60.0)
	if m >= 1 and not mins.has(m) and g.clock >= m * 60.0:
		mins[m] = _snapshot()
		print("MIN %d %s" % [m, _line(mins[m])])
	if g.clock >= until or g.over:
		_finish()
		return true
	return false


func _look() -> void:
	for b in g.buildings:
		if b.team != cwt or b.dead:
			continue
		if b.kind == "clocktower" and b != g._own_hall(cwt) and b.cell != g.starts[cwt]:
			_mark("hall2_laid")
			if hall2_cell.x < 0:
				hall2_cell = b.cell
				hall2_ring = _ring_without(b)
				hall2_outer = ClockSites.outer_room(g, b.cell)
			if b.built:
				_mark("hall2")
		if b.kind == "clocktower" and g.halls_of(cwt, false).size() >= 3:
			_mark("hall3_laid")
		if b.kind == Defs.CW_WORKS:
			_mark("works")
		if b.kind == "mainspring":
			_mark("mainspring_laid")
		if b.kind == "escapement":
			_mark("escapement_laid")
		if b.kind == Defs.CW_TURRET:
			_mark("turret_laid")
	for u in g.units:
		if u.dead or u.team != cwt:
			continue
		if not u.is_worker() and u.has_attack() and not _cs.has(u.get_instance_id()):
			_cs[u.get_instance_id()] = true
			_mark("army1")
	if cw.get("bte") != null and cw.bte.rush:
		ms["rush_seen"] = cw.bte.rush_at
	elif cw.get("scout") != null and String(cw.scout.verdict) == "rush":
		_mark("rush_seen")


## The ring room of a laid Clocktower's spot, as if the Clocktower were not there (its footprint and its own buildings
## are what ring_fit would count as blocked otherwise): measured on a copy of the solid map without its cells.
func _ring_without(b: Building) -> int:
	var keep := {}
	for y in b.size.y:
		for x in b.size.x:
			var i: int = g.idx(b.cell + Vector2i(x, y))
			keep[i] = g.solid[i]
			g.solid[i] = 0
	var f: Array = ClockSites.ring_fit(g, b.cell, ClockSites._start(b.cell))
	for i in keep:
		g.solid[i] = keep[i]
	return int(f[0])


func _army_val(tm: int) -> int:
	var v := 0.0
	for u in g.army(tm):
		v += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("tension", u.d.get("cost2", 0)))
	return int(v)


func _snapshot() -> Dictionary:
	return {"w": g.worker_count(cwt), "earned": int(g.stats[cwt]["gold"]), "army": _army_val(cwt),
		"halls": g.halls_of(cwt, false).size(), "sup": g.supply_used(cwt), "cap": int(g.players[cwt]["cap"]),
		"fw": g.worker_count(ft), "fearned": int(g.stats[ft]["gold"]), "farmy": _army_val(ft),
		"killed": int(g.stats[cwt]["value_killed"]), "lost": int(g.stats[ft]["value_killed"]),
		"bld_lost": int(g.stats[cwt]["bld_lost"])}


func _line(s: Dictionary) -> String:
	return "CW winders %d earned %d army %d halls %d supply %d/%d | foe workers %d earned %d army %d | killed %d lost %d bld lost %d" % [
		int(s["w"]), int(s["earned"]), int(s["army"]), int(s["halls"]), int(s["sup"]), int(s["cap"]), int(s["fw"]),
		int(s["fearned"]), int(s["farmy"]), int(s["killed"]), int(s["lost"]), int(s["bld_lost"])]


func _finish() -> void:
	var end := _snapshot()
	var who := "none"
	if g.over:
		who = "clockwork" if g.winner == cwt else ("foe" if g.winner == ft else "none")
	var old := OS.get_cmdline_user_args().has("cweco:off")
	print("--- %s seed %d  Clockwork %s%s (%s) v %s %s (%s)" % [map, seed_, cw_plan, " OLD" if old else "", dcw, foe_fac, fp, dfoe])
	for k in ["rush_seen", "works", "army1", "hall2_laid", "mainspring_laid", "hall2", "escapement_laid", "turret_laid", "hall3_laid"]:
		print("  %-16s %s" % [k, _mmss(float(ms.get(k, -1.0)))])
	print("  hall2 at %s: ring %d, outer %.2f" % [str(hall2_cell), hall2_ring, hall2_outer])
	print("  end %s: winner %s, %s" % [_mmss(g.clock), who, _line(end)])
	if cw.get("sp_log") != null:
		for e in cw.sp_log:
			print("  [%s] %s" % [_mmss(float(e[0])), String(e[1])])
	if json_path != "":
		var f := FileAccess.open(json_path, FileAccess.READ_WRITE) if FileAccess.file_exists(json_path) else FileAccess.open(json_path, FileAccess.WRITE)
		f.seek_end()
		var mm := {}
		for k in mins:
			mm[str(k)] = mins[k]
		f.store_line(JSON.stringify({"map": map, "seed": seed_, "cw": cw_plan, "old": old, "sites_old": OS.get_cmdline_user_args().has("clocksites:off"),
			"foe": foe_fac, "fp": fp, "dcw": dcw, "dfoe": dfoe, "ms": ms, "mins": mm, "end": end, "winner": who, "clock": g.clock,
			"hall2": [hall2_cell.x, hall2_cell.y, hall2_ring, hall2_outer]}))
		f.close()
	if check:
		var rs := float(ms.get("rush_seen", 9999.0))
		var h2 := float(ms.get("hall2_laid", 9999.0))
		var mil := minf(float(ms.get("works", 9999.0)), float(ms.get("army1", 9999.0)))
		if not rush:
			_check(mil >= minf(h2, rs), "no Light Works or soldier before the 2nd Clocktower without rush evidence: military %s, 2nd Clocktower %s, rush seen %s" % [
				_mmss(mil if mil < 9999.0 else -1.0), _mmss(h2 if h2 < 9999.0 else -1.0), _mmss(rs if rs < 9999.0 else -1.0)])
			if rs >= 9999.0 or rs > HALL_BY:
				_check(h2 <= HALL_BY, "the 2nd Clocktower laid by %s: %s" % [_mmss(HALL_BY), _mmss(h2 if h2 < 9999.0 else -1.0)])
			var w4: int = int((mins.get(4, end) as Dictionary)["w"])
			_check(w4 >= WINDERS_4, "%d Winders at 4:00 (want %d+)" % [w4, WINDERS_4])
			_check(hall2_ring >= RING_MIN, "the 2nd Clocktower's ring fits: %d of its ring's buildings at %s (want %d+)" % [hall2_ring, str(hall2_cell), RING_MIN])
		else:
			var works := float(ms.get("works", 9999.0))
			_check(rs < 9999.0, "the rush is seen: %s" % _mmss(rs if rs < 9999.0 else -1.0))
			_check(works <= rs + RUSH_ANSWER, "a Light Works within %d s of the evidence: %s" % [int(RUSH_ANSWER), _mmss(works if works < 9999.0 else -1.0)])
			_check(g.halls_of(cwt, false).size() >= 1 and not (g.over and g.winner == ft), "alive with a Clocktower at %s" % _mmss(g.clock))
		print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
