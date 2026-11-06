extends SceneTree
## THE ARMY RESTS ON ITS GEARS AND DEFENDS ITS BASE AS ONE (clockwork-home; scripts/ai_cw_army.gd, docs/clockwork_home.md):
## one game, a Clockwork computer against the Brood or the Crown computer, measured for the owner's two requests
## (2026-11-06, Kestrel Rise 0.33.0: the idle army wound down; the army waited at its gathering point while the base was hit
## and only pieces of it went).
##   godot --headless --fixed-fps 30 --script res://tools/test_clockwork_home.gd -- \
##       [cw:optimal foe:brood fp:optimal map:kestrel_rise seed:2537549191 cwslot:1 dcw:hard dfoe:hard until:600
##        check:1 json:<file> log:<file>] [cwhome:off]
## Measures (every second of game time):
##  - WIND AT HOME: the army at home (not out with the push, no raid on), its constructs' average wind and the share standing
##    on gear ground; the army's average wind when a push goes out and when an attack on the base starts.
##  - ATTACKS ON THE BASE: an episode starts when the armed enemies within 330 px of our buildings are worth BIG or more and
##    ends after QUIET s under SMALL; for each: its peak, the share of our army (value) that came within NEAR px of one of
##    them (it fought), the most of it within NEAR at one moment, the buildings lost meanwhile.
##  - the end: winner and time, buildings lost, army values at 6:00 / 8:00 / 10:00, the trades.
## `cwhome:off` plays 0.33.0's gathering point and raid answers (the "before" columns). check:1 is the test:
##  - the idle army stays wound: its average wind at home WIND_MIN or more;
##  - a real attack draws the whole army: in every episode that peaked at WHOLE_PEAK or more, DEFEND_MIN or more of the army
##    (value) came to it.
const BIG := 300.0
const SMALL := 100.0
const QUIET := 10.0
const NEAR := 420.0
const WIND_MIN := 0.8
const WHOLE_PEAK := 600.0
const DEFEND_MIN := 0.7
var main: Node
var g
var t := 0.0
var map := "kestrel_rise"
var seed_ := 2537549191
var cw_plan := "optimal"
var foe_fac := "brood"
var fp := "optimal"
var dcw := "hard"
var dfoe := "hard"
var cwslot := 1
var until := 600.0
var check := false
var json_path := ""
var log_path := ""
var cwt := 1
var ft := 0
var cw = null
var mins := {}
var fails := 0
var _next := 0.0
var idle_n := 0
var idle_wind := 0.0
var idle_field := 0.0
var idle_secs := 0
var launches: Array = []        # [clock, avg wind, units]
var _push_was := ""
var eps: Array = []             # episodes
var ep = null
var _quiet_t := 0.0
var _bld := {}                  # our buildings alive (id -> kind)
var lost_bld := 0
var min_wind := 1.0


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
			"cwslot": cwslot = int(kv[1])
			"until": until = float(kv[1])
			"check": check = kv[1] == "1"
			"json": json_path = kv[1]
			"log": log_path = kv[1]
	cwt = cwslot
	ft = 1 - cwslot
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
		var cws := {"who": dcw, "faction": "clockwork", "colour": cwslot, "side": cwslot, "strategy": cw_plan}
		var fs := {"who": dfoe, "faction": foe_fac, "colour": 1 - cwslot, "side": 1 - cwslot, "strategy": fp}
		main.start({"map": map, "seed": seed_, "hidden_plans": true, "slots": [cws, fs] if cwslot == 0 else [fs, cws]})
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


static func winds(u) -> bool:
	return combat(u) and String(u.d["faction"]) == "clockwork" and not u.runs_on_spring()


func _avg_wind(list: Array) -> float:
	var n := 0
	var w := 0.0
	for u in list:
		if is_instance_valid(u) and winds(u):
			n += 1
			w += u.wind
	return w / float(n) if n > 0 else -1.0


func _val(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += cw._unit_value(u)
	return v


func _look() -> void:
	# our buildings: lost ones
	var now := {}
	for b in g.buildings:
		if b.team == cwt and not b.dead and b.built:
			now[b.get_instance_id()] = b.kind
	for id in _bld:
		if not now.has(id):
			lost_bld += 1
			if ep != null:
				ep["lost_b"] = int(ep["lost_b"]) + 1
	_bld = now
	var mine: Array = []
	for u in g.army(cwt):
		if combat(u):
			mine.append(u)
	var push = cw.get("push")
	var out: bool = push != null and push.phase != "" and push.phase != "back"
	# a push goes out
	var pp: String = push.phase if push != null else ""
	if push != null and (_push_was == "" or _push_was == "back") and pp != "" and pp != "back":
		launches.append([g.clock, _avg_wind(push.units), push.units.size()])
	_push_was = pp
	# attacks on the base
	var foes: Array = []
	var seen := {}
	for b in g.buildings:
		if b.team != cwt or b.dead:
			continue
		for o in g.units_near(b.center(), 330.0):
			if g.hostile(o.team, cwt) and not o.dead and not o.off_field and cw._armed(o) and not seen.has(o):
				seen[o] = true
				foes.append(o)
	var fv := _val(foes)
	var army_g = cw.get("army_g")
	if ep == null and fv >= BIG:
		ep = {"t0": g.clock, "t1": g.clock, "peak": fv, "came": {}, "pool": {}, "army0": _val(mine), "most": 0.0, "with_n": 0, "with_s": 0.0, "lost_b": 0,
			"wind0": _avg_wind(mine.filter(func(u) -> bool: return cw._home_dist(u.position) < 900.0)), "out": out, "army_max": _val(mine)}
		_quiet_t = g.clock
	if ep != null:
		ep["peak"] = maxf(float(ep["peak"]), fv)
		ep["army_max"] = maxf(float(ep["army_max"]), _val(mine))
		var at := 0.0
		for u in mine:
			(ep["pool"] as Dictionary)[u] = cw._unit_value(u)
			for o in foes:
				if u.position.distance_to(o.position) < NEAR:
					(ep["came"] as Dictionary)[u] = cw._unit_value(u)
					at += cw._unit_value(u)
					break
		ep["most"] = maxf(float(ep["most"]), at / maxf(1.0, _val(mine)))
		if fv >= BIG:
			ep["with_n"] = int(ep["with_n"]) + 1
			ep["with_s"] = float(ep["with_s"]) + at / maxf(1.0, _val(mine))
		if fv >= SMALL:
			_quiet_t = g.clock
			ep["t1"] = g.clock
		elif g.clock - _quiet_t > QUIET:
			_close_ep()
	# the army at home: its wind
	if not out and ep == null and (army_g == null or army_g.phase == "gather"):
		var home: Array = mine.filter(func(u) -> bool: return winds(u) and cw._home_dist(u.position) < 900.0)
		if home.size() >= 3:
			idle_secs += 1
			for u in home:
				idle_n += 1
				idle_wind += u.wind
				min_wind = minf(min_wind, u.wind)
				if u._in_field:
					idle_field += 1.0


func _close_ep() -> void:
	var came := 0.0
	for u in ep["came"]:
		came += float(ep["came"][u])
	var pool := 0.0
	for u in ep["pool"]:
		pool += float(ep["pool"][u])
	ep["share"] = came / maxf(1.0, pool)
	ep["with"] = float(ep["with_s"]) / maxf(1.0, float(ep["with_n"]))
	ep.erase("came")
	ep.erase("pool")
	eps.append(ep)
	ep = null


func _army_val(tm: int) -> int:
	var v := 0.0
	for u in g.army(tm):
		v += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("tension", u.d.get("cost2", 0)))
	return int(v)


func _snapshot() -> Dictionary:
	return {"w": g.worker_count(cwt), "earned": int(g.stats[cwt]["gold"]), "army": _army_val(cwt),
		"halls": g.halls_of(cwt, false).size(), "sup": g.supply_used(cwt), "cap": int(g.players[cwt]["cap"]),
		"fw": g.worker_count(ft), "farmy": _army_val(ft), "fhalls": g.halls_of(ft, false).size(),
		"killed": int(g.stats[cwt]["value_killed"]), "lost": int(g.stats[ft]["value_killed"]), "lost_b": lost_bld}


func _line(s: Dictionary) -> String:
	return "CW winders %d earned %d army %d halls %d supply %d/%d | foe workers %d army %d halls %d | killed %d lost %d | buildings lost %d" % [
		int(s["w"]), int(s["earned"]), int(s["army"]), int(s["halls"]), int(s["sup"]), int(s["cap"]), int(s["fw"]),
		int(s["farmy"]), int(s["fhalls"]), int(s["killed"]), int(s["lost"]), int(s["lost_b"])]


func _finish() -> void:
	if ep != null:
		_close_ep()
	var end := _snapshot()
	var who := "none"
	if g.over:
		who = "clockwork" if g.winner == cwt else ("foe" if g.winner == ft else "none")
	var old := OS.get_cmdline_user_args().has("cwhome:off")
	var iw := idle_wind / float(idle_n) if idle_n > 0 else -1.0
	var inf := idle_field / float(idle_n) if idle_n > 0 else -1.0
	print("--- %s seed %d  Clockwork %s%s (%s) v %s %s (%s)" % [map, seed_, cw_plan, " OLD" if old else "", dcw, foe_fac, fp, dfoe])
	print("  end %s: winner %s, %s" % [_mmss(g.clock), who, _line(end)])
	for k in [6, 8, 10, 12]:
		if mins.has(k):
			var s: Dictionary = mins[k]
			print("  %d:00 army %d v %d, killed %d lost %d, buildings lost %d" % [k, int(s["army"]), int(s["farmy"]), int(s["killed"]), int(s["lost"]), int(s["lost_b"])])
	print("  wind at home: %.2f on average (lowest %.2f), %d%% of the time on gear ground, %d s at home" % [iw, min_wind, int(inf * 100.0), idle_secs])
	var lw := 0.0
	for l in launches:
		lw += float(l[1])
		print("  push out at %s: %d units, wind %.2f" % [_mmss(float(l[0])), int(l[2]), float(l[1])])
	var shares: Array = []
	var dw := 0.0
	for e in eps:
		print("  base attacked %s-%s: peak %d, army %d, came %d%% (most at once %d%%, at it while it was big %d%%), wind at the start %.2f, buildings lost %d%s" % [
			_mmss(float(e["t0"])), _mmss(float(e["t1"])), int(e["peak"]), int(e["army0"]), int(float(e["share"]) * 100.0),
			int(float(e["most"]) * 100.0), int(float(e["with"]) * 100.0), float(e["wind0"]), int(e["lost_b"]), " (the push was out)" if e["out"] else ""])
		shares.append(float(e["share"]))
		dw += float(e["wind0"])
	if cw.get("army_g") != null and cw.army_g != null:
		for e in (cw.army_g.alog as Array).slice(-30):
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
		f.store_line(JSON.stringify({"map": map, "seed": seed_, "cw": cw_plan, "old": old, "foe": foe_fac, "fp": fp,
			"mins": mm, "end": end, "winner": who, "clock": g.clock, "idle_wind": iw, "idle_field": inf, "idle_secs": idle_secs,
			"min_wind": min_wind, "launches": launches, "eps": eps, "lost_b": lost_bld}))
		f.close()
	if check:
		if idle_secs >= 60:
			_check(iw >= WIND_MIN, "the idle army stays wound: %.2f on average at home (want %.2f+)" % [iw, WIND_MIN])
		else:
			print("SKIP  the idle army stays wound: only %d s at home" % idle_secs)
		var big_eps := eps.filter(func(e) -> bool: return float(e["peak"]) >= WHOLE_PEAK and not e["out"])
		if big_eps.is_empty():
			print("SKIP  a base attack draws the whole army: no attack of %d+ on the base" % int(WHOLE_PEAK))
		for e in big_eps:
			_check(float(e["share"]) >= DEFEND_MIN, "the attack at %s (peak %d) drew %d%% of the army (want %d%%+)" % [
				_mmss(float(e["t0"])), int(e["peak"]), int(float(e["share"]) * 100.0), int(DEFEND_MIN * 100.0)])
		print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
