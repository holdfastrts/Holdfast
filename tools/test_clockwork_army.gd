extends SceneTree
## THE CLOCKWORK FIGHTS AS ONE ARMY (clockwork-army; scripts/ai_cw_army.gd, docs/clockwork_army.md): one game, a Clockwork
## computer against the Brood or the Crown computer, measured for the owner's complaint (2026-11-05: "it kept sending 1 or 2
## Clock Soldiers to die instead of using the Pendulum and Springers it had").
##   godot --headless --fixed-fps 30 --script res://tools/test_clockwork_army.gd -- \
##       [cw:economy|balanced|pendulum|heavy foe:brood|crown fp:economy map:frostfang seed:11 dcw:hard dfoe:hard
##        until:600 check:1 json:<file> log:<file>] [cwarmy:off]
## Measures (every second of game time):
##  - LONE: a Clockwork ground combat unit FIGHTING (its target in reach, or hit in the last 1.5 s) with no friendly ground
##    combat unit within LONE_R (6 tiles), while the Clockwork has 4 or more of them (the last few are not "sent alone"). An episode starts after LONE_GAP s without one; "away" = more than AWAY tiles from
##    every Clockwork building (sent out alone, not a soldier at its own door). The reason it was where it was (the scout,
##    a detachment, the harass, the round-5 guard, a wave, the army group) is written down at the episode's start.
##  - FIRST FIGHTS: each combat unit's first fight: with friends or alone (reinforcements must join before they fight).
##  - WINDERS WITH THE ARMY: while the army is out (the push, else the wave, else all of it; its middle more than OUT tiles
##    from every hall), how many Winders are within FOLLOW_R tiles of its middle (sampled).
##  - the army's value (cogs + Tension) at 6:00 / 8:00 / 10:00, both sides, and the trades (value killed and lost).
## `cwarmy:off` plays the old army code (the "before" columns). check:1 is the test (until:420 is enough):
##  - no combat unit sent alone: at most LONE_AWAY_MAX "away" episodes;
##  - reinforcements join before they fight: at most FIRST_ALONE_MAX first fights alone away from home;
##  - the Winders follow the army: on average WINDERS_MIN or more with it while it is out (when it went out).
const LONE_R := 6.0 * 32.0
const LONE_GAP := 5.0
const AWAY := 12.0 * 32.0
const OUT := 20.0 * 32.0
const FOLLOW_R := 10.0 * 32.0
const LONE_AWAY_MAX := 2
const FIRST_ALONE_MAX := 2
const WINDERS_MIN := 1.5
var main: Node
var g
var t := 0.0
var map := "frostfang"
var seed_ := 11
var cw_plan := "economy"
var foe_fac := "brood"
var fp := "economy"
var dcw := "hard"
var dfoe := "hard"
var until := 600.0
var check := false
var json_path := ""
var log_path := ""
var cwt := 0
var ft := 1
var cw = null
var mins := {}
var fails := 0
var _next := 0.0
var _last_lone := {}            # unit id -> clock it was last seen fighting alone
var lone_all := 0
var lone_away := 0
var lone_secs := 0.0
var lone_why := {}              # reason -> episodes (away)
var lone_kinds := {}            # kind -> episodes (away)
var lone_log: Array = []        # [clock, kind, why, x, y]
var _fought := {}               # unit id -> true once its first fight was counted
var first_alone := 0
var first_with := 0
var out_samples := 0
var out_winders := 0.0
var out_time := 0.0


func _initialize() -> void:
	if OS.get_cmdline_user_args().is_empty():
		check = true      # (qa-tests, 2026-11-08: a bare run is the test, so the suite gets a verdict)
		until = 420.0
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
			"log": log_path = kv[1]
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
	if g.clock >= _next:
		_next = g.clock + 1.0
		_look()
	var m := int(g.clock / 60.0)
	if m >= 1 and not mins.has(m) and g.clock >= m * 60.0:
		mins[m] = _snapshot()
		print("MIN %d %s" % [m, _line(mins[m])])
	if g.clock >= until or g.over:
		_finish()
		return true
	return false


static func combat(u) -> bool:
	return not u.dead and not u.off_field and not u.is_worker() and u.has_attack() and not u.is_air() and u.aboard == null \
		and u.kind != Defs.GREAT_WINDER_KIND and u.kind != "horse"


func _fighting(u) -> bool:
	if g.clock - u.hit_clock < 1.5:
		return true
	var tg = u.target
	if tg == null or not is_instance_valid(tg) or tg.dead or not g.hostile(tg.team, cwt):
		return false
	var r := float(u.d.get("range", 20)) + 60.0
	var tp: Vector2 = tg.center() if tg is Building else tg.position
	return u.position.distance_to(tp) <= r + (40.0 if tg is Building else 0.0)


func _friend_near(u, mine: Array) -> bool:
	for o in mine:
		if o != u and o.position.distance_to(u.position) <= LONE_R:
			return true
	return false


func _home_d(p: Vector2) -> float:
	var best := INF
	for b in g.buildings:
		if b.team == cwt and not b.dead:
			best = minf(best, b.center().distance_to(p))
	return best


## Why a unit stood where it stood: which of the computer's parts had it.
func _why(u) -> String:
	if cw.scout != null and (u == cw.scout.unit or u == cw.scout.sentry):
		return "scout"
	if cw.get("army_g") != null and cw.army_g != null and cw.army_g.has(u):
		return "army:" + String(cw.army_g.phase)
	if cw.get("push") != null and cw.push != null and cw.push.joining.has(u):
		return "push joining"
	if cw.get("push") != null and cw.push != null and cw.push.has(u):
		return "push %s|%d px from its anchor" % [String(cw.push.phase), int(u.position.distance_to(cw.push.anchor)) if cw.push.anchor != Vector2.INF else -1]
	if cw._det.has(u):
		return "detachment"
	if cw.hz().has(u):
		return "harass"
	if cw.r5.busy(u):
		return "r5 guard"
	if cw._wave_set.has(u):
		return "wave"
	if cw._raiders.has(u):
		return "raid"
	if cw._on_errand(u):
		return "plan errand"
	return "rally/" + String(u.order)


func _look() -> void:
	var mine: Array = []
	for u in g.army(cwt):
		if combat(u):
			mine.append(u)
	for u in mine:
		if not _fighting(u):
			continue
		var id: int = u.get_instance_id()
		var alone := not _friend_near(u, mine)
		var away := _home_d(u.position) > AWAY
		if not _fought.has(id):
			_fought[id] = true
			if alone and away:
				first_alone += 1
			else:
				first_with += 1
		if not alone or mine.size() < 4:
			continue          # (with friends, or it is (nearly) all the army there is: not "sent alone")
		lone_secs += 1.0
		if g.clock - float(_last_lone.get(id, -99.0)) > LONE_GAP:
			lone_all += 1
			var w := _why(u) + ("" if away else " @home")
			var wk := w.get_slice("|", 0) + ("" if away or w.ends_with("@home") else " @home")
			lone_why[wk] = int(lone_why.get(wk, 0)) + 1
			lone_kinds[u.kind] = int(lone_kinds.get(u.kind, 0)) + 1
			lone_log.append([snappedf(g.clock, 1.0), u.kind, w, int(u.position.x / 32.0), int(u.position.y / 32.0)])
			if away:
				lone_away += 1
		_last_lone[id] = g.clock
	# the army out: the Winders with it (the push's front when a push is out, the wave when one is out, else all of it)
	var grp: Array = mine
	if cw.get("push") != null and cw.push != null and cw.push.phase != "" and cw.push.phase != "back" and not cw.push.units.is_empty():
		grp = (cw.push.units as Array).filter(func(u) -> bool: return is_instance_valid(u) and combat(u))
	elif cw._attacking:
		grp = mine.filter(func(u) -> bool: return cw._wave_set.has(u))
	if grp.size() >= 4:
		var c := Vector2.ZERO
		for u in grp:
			c += u.position
		c /= float(grp.size())
		var hd := INF
		for h in g.halls_of(cwt, false):
			hd = minf(hd, h.center().distance_to(c))
		if hd > OUT:
			out_samples += 1
			out_time += 1.0
			var n := 0
			for w in g.workers(cwt):
				if not w.dead and w.position.distance_to(c) <= FOLLOW_R:
					n += 1
			out_winders += float(n)


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
		"fhalls": g.halls_of(ft, false).size(), "lone": lone_away}


func _line(s: Dictionary) -> String:
	return "CW winders %d earned %d army %d halls %d supply %d/%d | foe workers %d earned %d army %d halls %d | killed %d lost %d | alone away %d" % [
		int(s["w"]), int(s["earned"]), int(s["army"]), int(s["halls"]), int(s["sup"]), int(s["cap"]), int(s["fw"]),
		int(s["fearned"]), int(s["farmy"]), int(s["fhalls"]), int(s["killed"]), int(s["lost"]), int(s["lone"])]


func _finish() -> void:
	var end := _snapshot()
	var who := "none"
	if g.over:
		who = "clockwork" if g.winner == cwt else ("foe" if g.winner == ft else "none")
	var old := OS.get_cmdline_user_args().has("cwarmy:off")
	var wavg := out_winders / float(out_samples) if out_samples > 0 else -1.0
	print("--- %s seed %d  Clockwork %s%s (%s) v %s %s (%s)" % [map, seed_, cw_plan, " OLD" if old else "", dcw, foe_fac, fp, dfoe])
	print("  end %s: winner %s, %s" % [_mmss(g.clock), who, _line(end)])
	for k in [6, 8, 10]:
		if mins.has(k):
			var s: Dictionary = mins[k]
			print("  %d:00 army %d v %d, killed %d lost %d" % [k, int(s["army"]), int(s["farmy"]), int(s["killed"]), int(s["lost"])])
	print("  fighting alone: %d episodes (%d away from home, %d s in all); first fights alone away %d, with friends or at home %d" % [lone_all, lone_away, int(lone_secs), first_alone, first_with])
	print("  alone by reason %s, by kind %s" % [str(lone_why), str(lone_kinds)])
	for e in lone_log.slice(0, 40):
		print("    [%s] %s alone (%s) at %d,%d" % [_mmss(float(e[0])), e[1], e[2], e[3], e[4]])
	print("  army out %d s, Winders with it on average %.1f" % [int(out_time), wavg])
	if cw.get("army_g") != null and cw.army_g != null:
		for e in (cw.army_g.alog as Array).slice(-40):
			print("  [%s] %s" % [_mmss(float(e[0])), String(e[1])])
	if log_path != "" and g.mlog:
		var lf := FileAccess.open(log_path, FileAccess.WRITE)
		for l in g.mlog.lines:
			lf.store_line(str(l))
		lf.close()
	if json_path != "":
		var f := FileAccess.open(json_path, FileAccess.READ_WRITE) if FileAccess.file_exists(json_path) else FileAccess.open(json_path, FileAccess.WRITE)
		f.seek_end()
		var mm := {}
		for k in mins:
			mm[str(k)] = mins[k]
		f.store_line(JSON.stringify({"map": map, "seed": seed_, "cw": cw_plan, "old": old, "foe": foe_fac, "fp": fp, "dcw": dcw,
			"dfoe": dfoe, "mins": mm, "end": end, "winner": who, "clock": g.clock, "lone_all": lone_all, "lone_away": lone_away,
			"lone_secs": lone_secs, "lone_why": lone_why, "lone_kinds": lone_kinds, "first_alone": first_alone,
			"first_with": first_with, "out_time": out_time, "winders_out": wavg}))
		f.close()
	if check:
		_check(lone_away <= LONE_AWAY_MAX, "no combat unit sent alone: %d episodes away from home (want %d or fewer)" % [lone_away, LONE_AWAY_MAX])
		_check(first_alone <= FIRST_ALONE_MAX, "reinforcements join before they fight: %d first fights alone away from home (want %d or fewer)" % [first_alone, FIRST_ALONE_MAX])
		if out_samples >= 10:
			_check(wavg >= WINDERS_MIN, "the Winders follow the army: %.1f with it on average while it was out (want %.1f+)" % [wavg, WINDERS_MIN])
		else:
			print("SKIP  the Winders follow the army: the army was out only %d s" % out_samples)
		print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
