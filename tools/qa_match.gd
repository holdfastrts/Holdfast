extends SceneTree
## QA MATCHES (qa-matches, docs/qa_2026_11_08_matches.md): computers against computers, headless, MEASURED, any number of
## players (1v1, free-for-all, 2v2). A measuring tool only: it starts a normal match and reads it; it changes no rule.
##   godot --headless --fixed-fps 30 --script res://tools/qa_match.gd -- map:greenhold seed:1 end:900 out:/abs/dir \
##       slots:crown/optimal/0,brood/optimal/1  [diff:hard]
## A slot is faction/plan/side (same side = allies: 2v2 is crown/optimal/0,brood/optimal/0,clockwork/optimal/1,...).
## Writes <out>/result.json (setup, end, winner, a line a minute per player, events: halls lost, first attacks and how
## they went, STALLS: a player with money that spends nothing for a minute, no unit made for 90 s, an army standing still
## while the enemy is in its base, units stuck on a move order), <out>/story.txt (the AI STORY lines) and
## <out>/log.txt (the match log).
var main: Node
var g: Game
var map := "greenhold"
var seed_ := 1
var end_t := 900.0
var out := "/tmp/qa_match"
var diff := "hard"
var slots: Array = []           # [faction, plan, side]
var t := 0.0
var next_min := 60.0
var next_s5 := 5.0
var next_s10 := 10.0
var minutes: Array = []
var events: Array = []
var n := 0
# per player trackers
var _halls_seen: Array = []     # instance id -> [kind, tile]
var _brood_exp: Array = []      # last expansions count (Brood)
var _att: Array = []            # first attack record
var _spent_last: Array = []     # [spent, since]
var _trained_last: Array = []   # [trained, since]
var _stall_open: Array = []     # key -> start time
var _army_snaps: Array = []     # per player: Array of {id: pos} every 10 s (last 7)
var _unit_last: Dictionary = {} # unit id -> [pos, order_point, since]
var _stuck_seen: Dictionary = {} # unit id -> true (reported)
var _enemy_in_since: Array = []
var _arr: Array = []            # per victim: the first enemy arrival in its base (300+ army value within 500 px)
var _gw_cogs: Array = []        # (clockwork-ai-v2) per player: Great Winder id -> cogs it swept (a dead one's kept)
var _idle_w: Array = []         # (clockwork-ai-v2) per player: [sum of idle workers over the 5 s looks, looks]


func _initialize() -> void:
	var spec := "crown/optimal/0,brood/optimal/1"
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"end": end_t = float(kv[1])
			"out": out = kv[1]
			"diff": diff = kv[1]
			"slots": spec = kv[1]
	for s in spec.split(","):
		var p := s.split("/")
		slots.append([p[0], p[1] if p.size() > 1 else "optimal", int(p[2]) if p.size() > 2 else slots.size()])
	n = slots.size()
	for i in n:
		_halls_seen.append({})
		_brood_exp.append(-1)
		_att.append({})
		_spent_last.append([0, 0.0])
		_trained_last.append([0, 0.0])
		_stall_open.append({})
		_army_snaps.append([])
		_enemy_in_since.append(-1.0)
		_arr.append({})
		_gw_cogs.append({})
		_idle_w.append([0, 0])
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var sl: Array = []
		for i in n:
			sl.append({"who": diff, "faction": slots[i][0], "colour": i, "side": slots[i][2], "strategy": slots[i][1]})
		main.start({"map": map, "seed": seed_, "slots": sl})
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
	if g.clock >= next_s5:
		next_s5 += 5.0
		_every5()
	if g.clock >= next_s10:
		next_s10 += 10.0
		_every10()
	if g.clock >= next_min:
		next_min += 60.0
		for tm in n:
			minutes.append(_side(tm))
	if g.over or g.clock >= end_t:
		_finish()
		return true
	return false


func _mmss(c: float) -> String:
	return "%d:%02d" % [int(c) / 60, int(c) % 60]


func _ai(tm: int) -> AI:
	for a in g.ais:
		if a.team == tm:
			return a
	return null


func _army_units(tm: int) -> Array:
	var o: Array = []
	for u in g.army(tm):
		if u.dead or u.off_field or u.is_worker() or not u.has_attack():
			continue
		if u._k_nb and (u.kind == BroodNew.QUEEN or BroodNew.rooted(u)):
			continue
		o.append(u)
	return o


func _army_value(tm: int) -> int:
	var v := 0
	for u in g.army(tm):
		if not u._k_nb or not (u.kind == BroodNew.QUEEN or BroodNew.rooted(u)):
			v += Game.unit_value(u)
	return v


func _halls(tm: int) -> int:
	if g.faction_of(tm) != "brood":
		return g.halls_of(tm).size()
	var q := BroodNew.queen(g, tm)
	return (1 + BroodNew.expansions(g, q).size()) if q else 0


func _alive(tm: int) -> bool:
	return not g.eliminated[tm]


func _side(tm: int) -> Dictionary:
	var a := _ai(tm)
	var st: Dictionary = g.stats[tm]
	var maws := 0
	if g.faction_of(tm) == "brood":
		for u in g.units:
			if u.team == tm and u.kind == BroodNew.MAW and not u.dead and BroodNew.rooted(u):
				maws += 1
	return {"t": int(round(g.clock)), "p": tm, "plan": a.strategy if a else "?", "income": int(st["gold"]),
		"spent": int(st["spent"]), "bank": int(g.players[tm]["gold"]), "workers": g.workers(tm).size(),
		"army": _army_value(tm), "halls": _halls(tm), "supply": g.supply_used(tm), "cap": int(g.players[tm]["cap"]),
		"lost": int(st["lost"]), "bld_lost": int(st["bld_lost"]), "trained": int(st["trained"]), "maws": maws,
		"res2": int(st.get("res2_in", 0.0)), "out": not _alive(tm), "gw_cogs": _gw_sum(tm),
		"idle_w": g.workers(tm).filter(func(w: Unit) -> bool: return w.order == "idle").size(),
		"idle_w_avg": snappedf(float(_idle_w[tm][0]) / maxf(1.0, float(_idle_w[tm][1])), 0.1),
		"push": _push_phase(tm), "crown": _crown_econ(tm, a)}


## (econ-coach-crown) every 5 s, when built Farms have 2+ free posts and a built hall trains nothing: why (the gold under a
## labourer's price, the army share's hold, the build order, or another hold); counted per minute in "crown"."why"
var _why := {}


func _crown_why(tm: int) -> void:
	var a = _ai(tm)
	if a == null:
		return
	var free := 0
	for b in g.buildings:
		if b.team == tm and not b.dead and b.built and b.kind == "farm" and b.soil_left() > 0.0:
			free += maxi(0, b.crew_max() - b.crew.size())
	var idle_hall := false
	for h in g.halls_of(tm):
		if h.built and h.queue.is_empty():
			idle_hall = true
	var w: Dictionary = _why.get(tm, {})
	w["looks"] = int(w.get("looks", 0)) + 1
	if free < 2 or not idle_hall:
		_why[tm] = w
		return
	var k := "hold"
	if a.has_method("bo_owns") and a.bo_owns():
		k = "bo"
	elif int(g.players[tm]["gold"]) < 50:
		k = "gold"
	elif a.has_method("_army_due") and a._army_due():
		k = "army_due"
	w[k] = int(w.get(k, 0)) + 1
	_why[tm] = w


## (econ-coach-crown) the Crown's economy in detail: built Farms on live soil and spent ones, Mills, the posts they offer,
## the labourers on Farms and Mills, the computer's labourer cap and the seconds its labourers waited for the army
func _crown_econ(tm: int, a) -> Dictionary:
	if g.faction_of(tm) != "crown":
		return {}
	var d := {"farms": 0, "farms_spent": 0, "mills": 0, "posts": 0, "on_farms": 0, "on_mills": 0}
	for b in g.buildings:
		if b.team != tm or b.dead or not b.built:
			continue
		if b.kind == "farm":
			if b.soil_left() <= 0.0:
				d["farms_spent"] += 1
				continue
			d["farms"] += 1
			d["posts"] += b.crew_max()
			d["on_farms"] += b.working_crew()
		elif b.kind == "powder_mill":
			d["mills"] += 1
			d["posts"] += b.crew_max()
			d["on_mills"] += b.working_crew()
	var others := {}
	for w in g.workers(tm):
		var site = w.home_mine
		if w.order == "gather" and site is Building and ((site as Building).kind == "farm" or (site as Building).kind == "powder_mill"):
			continue
		var k := String(w.order)
		if a != null and a._fled.has(w):
			k = "fled"
		elif a != null and a.scout != null and a.scout.is_scout(w):
			k = "scout"
		elif k == "gather" and site is Building:
			k = "gather_" + (site as Building).kind
		others[k] = int(others.get(k, 0)) + 1
	d["others"] = others
	d["why"] = _why.get(tm, {})
	_why[tm] = {}
	if a != null and a.has_method("owner_lab_cap"):
		d["lab_cap"] = a.owner_lab_cap()
		d["lag_s"] = int(a.lag_time)
		d["farms_pulled"] = int(a.get("farms_pulled") if a.get("farms_pulled") != null else 0)
	return d


## (clockwork-ai-v2) cogs the side's Great Winders have swept so far
func _gw_sum(tm: int) -> int:
	var s := 0
	for v in (_gw_cogs[tm] as Dictionary).values():
		s += int(v)
	return s


## (clockwork-ai-v2) the Clockwork computer's push phase ("" at home)
func _push_phase(tm: int) -> String:
	var a := _ai(tm)
	if a == null or not ("push" in a) or a.push == null:
		return ""
	return String(a.push.phase)


## base points: its buildings, and for the Brood its Queen and rooted creatures
func _base_points(tm: int) -> Array:
	var pts: Array = []
	for b in g.buildings:
		if b.team == tm and not b.dead:
			pts.append(b.center())
	if g.faction_of(tm) == "brood":
		for u in g.units:
			if u.team == tm and not u.dead and u._k_nb and (u.kind == BroodNew.QUEEN or BroodNew.rooted(u)):
				pts.append(u.position)
	return pts


func _enemy_value_in_base(tm: int) -> int:
	var pts := _base_points(tm)
	var v := 0
	for e in g.enemies_of(tm):
		for u in _army_units(e):
			for p in pts:
				if (p as Vector2).distance_to(u.position) < 500.0:
					v += Game.unit_value(u)
					break
	return v


func _stall(tm: int, key: String, on: bool, note: String, min_len: float) -> void:
	var open: Dictionary = _stall_open[tm]
	if on and not open.has(key):
		open[key] = [g.clock, note]
	elif not on and open.has(key):
		var s: Array = open[key]
		open.erase(key)
		if g.clock - float(s[0]) >= min_len:
			events.append({"t": int(s[0]), "p": tm, "ev": "stall", "kind": key, "len": int(g.clock - float(s[0])), "note": s[1]})


func _every5() -> void:
	for u in g.units:
		if u.kind == Defs.GREAT_WINDER_KIND and u.team >= 0 and u.team < n:
			_gw_cogs[u.team][u.get_instance_id()] = int(u.get_meta("gw_cogs", 0))
	for tm in n:
		if not _alive(tm):
			continue
		if g.clock > 240.0:
			_idle_w[tm][0] += g.workers(tm).filter(func(w: Unit) -> bool: return w.order == "idle").size()
			_idle_w[tm][1] += 1
		if g.faction_of(tm) == "crown":
			_crown_why(tm)
		# halls lost (Crown / Clockwork halls; the Brood: its Queen and expansion count)
		var seen: Dictionary = _halls_seen[tm]
		var now := {}
		if g.faction_of(tm) != "brood":
			for h in g.halls_of(tm, false):
				now[h.get_instance_id()] = true
				if seen.has(h.get_instance_id()) and h.built:
					seen[h.get_instance_id()][2] = true
				if not seen.has(h.get_instance_id()):
					seen[h.get_instance_id()] = [String(h.kind), str(Vector2i(h.center() / Defs.TILE)), bool(h.built if "built" in h else true)]
			for id in seen.keys():
				if not now.has(id):
					var inst = instance_from_id(id)
					var died: bool = inst == null or (inst is Entity and inst.dead)
					events.append({"t": int(g.clock), "p": tm, "ev": "hall_lost" if died else "hall_gone", "kind": seen[id][0], "at": seen[id][1], "built": seen[id][2]})
					seen.erase(id)
		else:
			var c := _halls(tm)
			if _brood_exp[tm] >= 0 and c < _brood_exp[tm]:
				events.append({"t": int(g.clock), "p": tm, "ev": "brood_ground_lost", "from": _brood_exp[tm], "to": c})
			_brood_exp[tm] = c
		# money and no spending; no production
		var st: Dictionary = g.stats[tm]
		var sp := int(st["spent"])
		if sp != int(_spent_last[tm][0]):
			_spent_last[tm] = [sp, g.clock]
		var bank := int(g.players[tm]["gold"])
		_stall(tm, "bank_unspent", g.clock - float(_spent_last[tm][1]) >= 60.0 and bank >= 400, "bank %d" % bank, 60.0)
		var tr := int(st["trained"])
		if tr != int(_trained_last[tm][0]):
			_trained_last[tm] = [tr, g.clock]
		var capped: bool = g.supply_used(tm) >= int(g.players[tm]["cap"]) - 1
		_stall(tm, "no_units", g.clock > 150.0 and g.clock - float(_trained_last[tm][1]) >= 90.0 and not capped, "bank %d supply %d/%d" % [bank, g.supply_used(tm), int(g.players[tm]["cap"])], 90.0)
		# first attack
		var a := _ai(tm)
		if a and a._attacking and _att[tm].is_empty():
			var foes := g.enemies_of(tm)
			var fv := 0
			var fl := 0
			var fb := 0
			for e in foes:
				fv += _army_value(e)
				fl += int(g.stats[e]["lost"])
				fb += int(g.stats[e]["bld_lost"])
			_att[tm] = {"t": int(g.clock), "army": _army_value(tm), "foe_army": fv, "lost0": int(st["lost"]), "foe_lost0": fl, "foe_bld0": fb, "done": false}
		elif not _att[tm].is_empty() and not _att[tm]["done"] and g.clock >= float(_att[tm]["t"]) + 90.0:
			var r: Dictionary = _att[tm]
			r["done"] = true
			var fl2 := 0
			var fb2 := 0
			var fv2 := 0
			for e in g.enemies_of(tm) if not g.enemies_of(tm).is_empty() else []:
				fl2 += int(g.stats[e]["lost"])
				fb2 += int(g.stats[e]["bld_lost"])
				fv2 += _army_value(e)
			r["army90"] = _army_value(tm)
			r["foe_army90"] = fv2
			r["lost"] = int(st["lost"]) - int(r["lost0"])
			r["foe_lost"] = fl2 - int(r["foe_lost0"])
			r["foe_bld"] = fb2 - int(r["foe_bld0"])
			events.append({"t": int(r["t"]), "p": tm, "ev": "first_attack", "army": r["army"], "foe_army": r["foe_army"],
				"army90": r["army90"], "foe_army90": fv2, "lost": r["lost"], "foe_lost": r["foe_lost"], "foe_bld": r["foe_bld"]})


func _every10() -> void:
	for tm in n:
		if not _alive(tm):
			continue
		# army standing still while the enemy is in its base
		var snap := {}
		var engaged := 0
		var au := _army_units(tm)
		for u in au:
			snap[u.get_instance_id()] = u.position
			if u.target != null and is_instance_valid(u.target) and not u.target.dead:
				engaged += 1
		var snaps: Array = _army_snaps[tm]
		snaps.append(snap)
		if snaps.size() > 7:
			snaps.pop_front()
		var ev := _enemy_value_in_base(tm)
		var still := false
		if snaps.size() == 7 and au.size() >= 4 and _army_value(tm) >= 300:
			var old: Dictionary = snaps[0]
			var ds: Array = []
			for id in snap:
				if old.has(id):
					ds.append((snap[id] as Vector2).distance_to(old[id]))
			if ds.size() >= 4:
				ds.sort()
				still = float(ds[ds.size() / 2]) < 40.0
		_arrival(tm, ev)
		_stall(tm, "army_idle_enemy_in_base", ev >= 300 and still and engaged * 4 < au.size(),
			"enemy %d in base, army %d (%d units) still" % [ev, _army_value(tm), au.size()], 60.0)
	# units stuck on a move order (moved under 8 px in 30 s with the same order point)
	for u in g.units:
		if u.dead or u.team < 0 or u.off_field:
			continue
		var id: int = u.get_instance_id()
		if u.order != "move" and u.order != "amove":
			_unit_last.erase(id)
			continue
		if u.target != null and is_instance_valid(u.target) and not u.target.dead:
			_unit_last.erase(id)
			continue
		var l = _unit_last.get(id)
		if l == null or (l[1] as Vector2).distance_to(u.order_point) > 4.0 or (l[0] as Vector2).distance_to(u.position) > 8.0:
			_unit_last[id] = [u.position, u.order_point, g.clock]
			continue
		if u.position.distance_to(u.order_point) < 48.0:
			continue
		if g.clock - float(l[2]) >= 30.0 and not _stuck_seen.has(id):
			_stuck_seen[id] = true
			events.append({"t": int(l[2]), "p": u.team, "ev": "stuck", "kind": String(u.kind), "order": u.order,
				"at": str(Vector2i(u.position / Defs.TILE)), "goal": str(Vector2i(u.order_point / Defs.TILE)), "dbg": _stuck_dbg(u)})


## (crown-ai-v2) what a stuck unit stands in: its path and the ground round it, 11 x 11 cells (. free, # terrain,
## B building, G gate (g: an enemy's), W wall, f field, u another unit of its side, * the unit; a gate or wall of its own
## side in capitals), 21 x 21 cells.
func _stuck_dbg(u: Unit) -> Dictionary:
	var c := Vector2i(u.position / Defs.TILE)
	var rows: Array = []
	var mine := {}
	for o in g.units_near(u.position, 11.0 * Defs.TILE):
		if o.team == u.team and not o.dead:
			mine[Vector2i(o.position / Defs.TILE)] = true
	for dy in range(-10, 11):
		var r := ""
		for dx in range(-10, 11):
			var q := c + Vector2i(dx, dy)
			if not g.in_map(q):
				r += " "
				continue
			if dx == 0 and dy == 0:
				r += "*"
				continue
			var s: int = g.solid[g.idx(q)]
			if s == 0 and mine.has(q):
				r += "u"
				continue
			match s:
				0: r += "."
				1: r += "#"
				2: r += "B"
				3: r += "G" if g._own_gate_at(u.team, q) != null else "g"
				4: r += "W" if g._own_wall_at(u.team, q) != null else "w"
				5: r += "f"
				_: r += "?"
		rows.append(r)
	var pend := ""
	if u.path.size() > 0:
		pend = str(Vector2i(u.path[u.path.size() - 1] / Defs.TILE))
	return {"path": u.path.size(), "path_i": u.path_i, "pending": u.path_pending, "path_end": pend,
		"passable": g.passable(c, u.team), "grid": rows}


## THE FIRST ARRIVAL of an enemy army in a player's base (whatever the attacker's computer calls it: the Clockwork's
## push never marks itself attacking): when, how big, and 90 s later what each side lost (units; the victim's buildings).
func _lost_units(ts: Array) -> int:
	var k := 0
	for e in ts:
		k += int(g.stats[e]["lost"])
	return k


func _arrival(tm: int, ev: int) -> void:
	var r: Dictionary = _arr[tm]
	var foes := g.enemies_of(tm)
	if r.is_empty() and ev >= 300:
		var fv := 0
		for e in foes:
			fv += _army_value(e)
		r.merge({"t": int(g.clock), "value": ev, "foe_army": fv, "own_army": _army_value(tm), "v_lost0": int(g.stats[tm]["lost"]),
			"v_bld0": int(g.stats[tm]["bld_lost"]), "a_lost0": _lost_units(foes), "done": false})
	elif not r.is_empty() and not r["done"] and g.clock >= float(r["t"]) + 90.0:
		r["done"] = true
		events.append({"t": int(r["t"]), "p": tm, "ev": "first_arrival", "value": r["value"], "foe_army": r["foe_army"],
			"own_army": r["own_army"], "own_lost": int(g.stats[tm]["lost"]) - int(r["v_lost0"]), "own_bld": int(g.stats[tm]["bld_lost"]) - int(r["v_bld0"]),
			"foe_lost": _lost_units(foes) - int(r["a_lost0"]), "own_army90": _army_value(tm), "foe_army90": foes.reduce(func(acc, e): return acc + _army_value(e), 0)})


func _finish() -> void:
	for tm in n:
		var open: Dictionary = _stall_open[tm]
		for key in open.keys():
			_stall(tm, key, false, "", 60.0 if key != "no_units" else 90.0)
		if not _att[tm].is_empty() and not _att[tm]["done"]:
			events.append({"t": int(_att[tm]["t"]), "p": tm, "ev": "first_attack", "army": _att[tm]["army"], "foe_army": _att[tm]["foe_army"], "unfinished": true})
	var f := FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)
	var story := FileAccess.open(out.path_join("story.txt"), FileAccess.WRITE)
	if g.mlog:
		for l in g.mlog.lines:
			f.store_line(str(l))
			var line := str(l)
			for tm in n:
				var who: String = g.mlog.who(tm)
				var i := line.find(who)
				if i < 0 or i > 12:
					continue
				var rest := line.substr(i + who.length())
				rest = rest.strip_edges(true, false) if not rest.begins_with("'s ") else rest
				var m := AIStoryLines.match_line(rest)
				if not m.is_empty() and String(m["template"]) != "" and int(m["prio"]) >= 2:
					var args: Array = ["P%d %s" % [tm + 1, g.faction_of(tm).capitalize()]] + (m["args"] as Array)
					var tpl := String(m["template"])
					story.store_line("%s %s" % [line.substr(0, 7), tpl % args if tpl.count("%s") == args.size() else tpl])
	f.close()
	story.close()
	var endl: Array = []
	for tm in n:
		endl.append(_side(tm))
	var reads: Array = []
	for tm in n:
		var a := _ai(tm)
		if a == null:
			continue
		var rd: Array = []
		if a.scout != null:
			rd = a.scout.reads
		elif "reads" in a:
			rd = a.reads
		for x in rd:
			reads.append({"p": tm, "t": int(float(x[0])), "read": AIRead.word(String(x[1])), "why": String(x[2])})
		if a.opt != null:
			for p in a.opt.picks:
				reads.append({"p": tm, "t": int(float(p[0])), "pick": "%s %s -> %s (%s)" % [String(p[1]), String(p[2]), String(p[3]), String(p[4])]})
	var res := {"map": map, "seed": seed_, "version": ProjectSettings.get_setting("application/config/version", ""),
		"slots": slots, "end": int(round(g.clock)), "over": g.over,
		"winner": g.winner if g.over else -1, "winner_side": (g.sides[g.winner] if g.over and g.winner >= 0 else -1),
		"minutes": minutes, "final": endl, "events": events, "reads": reads}
	var r := FileAccess.open(out.path_join("result.json"), FileAccess.WRITE)
	r.store_string(JSON.stringify(res))
	r.close()
	print("done ", out)
