extends SceneTree
## THE CLOCKWORK COMPUTER ALONE (econ-coach-clockwork, docs/econ-coach-clockwork.md): the economy bench's setup
## (tools/econ_bench.gd: one side alone on a map, the other an idle dummy) with the Hard Clockwork COMPUTER playing instead
## of the scripted ideal build, so its economy can be laid against the bench's curve minute by minute and its macro losses
## found: idle and missing Winders, unfilled posts, spent presses left standing, supply blocks, cogs banked, Clocktowers late.
##
##   godot --headless --fixed-fps 30 --script res://tools/econ_alone_cw.gd -- [plan=optimal] [map=greenhold] [seed=1]
##       [minutes=15] [peace=0] [diff=hard] [out=<file.json>] [any other word: passed on to the game's command line]
##
## The dummy (side 1, the human slot nobody plays, a Crown as in the bench) is kept standing: its buildings are healed every
## second and its bank kept full, so the computer's waves (it is NOT peaceful by default: its scout must read, OPTIMAL picks
## its build from that) never end the game. peace=1 makes the computer peaceful (no attacks, no scout).
## A line a minute and a RESULT line (JSON): per minute cogs (primary) and Tension earned (cumulative), Winders, Winders at
## work, posts (crews of the working presses and Mainsprings), presses (big / small / spent standing), Mainsprings,
## Clocktowers (built / going up), bank, supply / cap, army value; and per minute the seconds supply-blocked, the
## Winder-seconds of posts left empty, idle-Winder seconds, seconds a built Clocktower stood with an empty queue while posts
## were empty, cogs-banked-over-400 seconds.

var main: Node
var g: Game
var ai
var opts := {"plan": "optimal", "map": "greenhold", "seed": "1", "minutes": "15", "peace": "0", "diff": "hard", "out": ""}
var t := 0.0
var started := false
var next_min := 60.0
var next_sec := 1.0
var rows: Array = []
var acc := {}
var firsts := {}
var halls_seen := {}
var wall0 := 0


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			var kv := a.split("=", true, 1)
			opts[kv[0]] = kv[1]
	wall0 = Time.get_ticks_msec()
	_reset_acc()


func _reset_acc() -> void:
	acc = {"blocked": 0.0, "empty_posts": 0.0, "idle": 0.0, "hall_idle": 0.0, "bank400": 0.0}


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(int(opts["seed"]))
		main.start({"map": opts["map"], "seed": int(opts["seed"]), "slots": [
			{"who": String(opts["diff"]), "faction": "clockwork", "colour": 0, "side": 0, "strategy": String(opts["plan"])},
			{"who": "you", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
		g = main.game
		for a in g.ais:
			if a.team == 0:
				ai = a
				a.peaceful = opts["peace"] == "1"
		started = true
		return false
	if not started or g == null:
		return false
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if g.clock >= next_sec:
		next_sec += 1.0
		_second()
	if g.clock >= next_min:
		next_min += 60.0
		_row()
	if g.clock >= float(opts["minutes"]) * 60.0 or g.over:
		_finish()
	return false


func _second() -> void:
	# the dummy stands: healed, its bank full (never "helpless")
	for b in g.buildings:
		if b.team == 1 and not b.dead:
			b.hp = b.max_hp
	g.players[1]["gold"] = 5000
	var ws := g.workers(0)
	var posts := _posts()
	var working := ws.filter(func(u: Unit) -> bool: return u.order == "gather" and u.home_mine != null).size()
	var idle := ws.filter(func(u: Unit) -> bool: return u.order == "" or u.order == "idle" or u.order == "stop").size()
	var cap := int(g.players[0]["cap"])
	if g.supply_used(0) >= cap and cap < g.max_supply(0):
		acc["blocked"] += 1.0
	acc["empty_posts"] += maxf(0.0, float(posts - working))
	acc["idle"] += float(idle)
	if posts > working:
		for h in g.halls_of(0, true):
			if h.built and h.queue.is_empty():
				acc["hall_idle"] += 1.0
	if int(g.players[0]["gold"]) > 400:
		acc["bank400"] += 1.0
	for h in g.halls_of(0, false):
		var id: int = h.get_instance_id()
		if not halls_seen.has(id):
			halls_seen[id] = true
			_first("hall_%d_laid" % halls_seen.size())
		if h.built:
			_first("hall_%d_built_%d" % [halls_seen.size(), id])


func _posts() -> int:
	var n := 0
	for b in g.buildings:
		if b.team == 0 and not b.dead and b.built and b.crew_max() > 0 and b.haul_cap() <= 0 and not b.barren():
			if b.kind == Defs.GEAR_PRESS and g.gear_net.speed_mult(b) <= 0.0:
				continue
			n += b.crew_max()
	return n


func _first(k: String) -> void:
	if not firsts.has(k):
		firsts[k] = int(g.clock)


func _row() -> void:
	var st: Dictionary = g.stats[0]
	var ws := g.workers(0)
	var working := ws.filter(func(u: Unit) -> bool: return u.order == "gather" and u.home_mine != null).size()
	var orders := {}
	for u in ws:
		var o := String(u.order)
		orders[o] = int(orders.get(o, 0)) + 1
	var pb := 0
	var ps := 0
	var pspent := 0
	var ms := 0
	for b in g.buildings:
		if b.team != 0 or b.dead:
			continue
		if b.kind == Defs.GEAR_PRESS:
			if b.barren():
				pspent += 1
			elif b.gear_big:
				pb += 1
			else:
				ps += 1
		elif b.kind == "mainspring":
			ms += 1
	var army := 0.0
	for u in g.army(0):
		army += float(u.d.get("cost", 0)) / maxf(1.0, float(u.d.get("spawn", 1))) + float(Defs.tension_cost(u.d))
	var hb := g.halls_of(0, true).filter(func(h: Building) -> bool: return h.built).size()
	var row := {"min": rows.size() + 1, "p_cum": int(st["gold"]), "s_cum": int(st.get("tension_in", 0.0)), "workers": ws.size(),
		"working": working, "posts": _posts(), "press_big": pb, "press_small": ps, "press_spent": pspent, "mainspring": ms,
		"halls": hb, "halls_all": g.halls_of(0, false).size(), "bank": int(g.players[0]["gold"]), "supply": g.supply_used(0),
		"cap": int(g.players[0]["cap"]), "army": int(army), "orders": orders, "plan": String(ai.strategy) if ai else "",
		"bo": bool(ai.get("bo_on")) if ai else false,
		"escorts": (ai._escort as Array).size() if ai else 0,
		"idle_free": ws.filter(func(u: Unit) -> bool: return u.order == "idle" and ai and not (ai._escort as Array).has(u)).size(),
		"big_pick": g.gear_big_for(0, Defs.GEAR_PRESS)}
	for k in acc:
		row[k] = int(acc[k])
	_reset_acc()
	rows.append(row)
	print("cw %2d  cogs %6d  T %5d  W %2d/%2d at work, posts %2d  press b%d s%d spent%d  ms %d  halls %d/%d  bank %4d  sup %3d/%3d  army %5d  blk %2d empty %4d idle %3d hidle %2d  %s%s" % [
		row["min"], row["p_cum"], row["s_cum"], row["workers"], row["working"], row["posts"], pb, ps, pspent, ms, hb, row["halls_all"],
		row["bank"], row["supply"], row["cap"], row["army"], row["blocked"], row["empty_posts"], row["idle"], row["hall_idle"],
		row["plan"], " (bo)" if row["bo"] else ""])


func _finish() -> void:
	var res := {"plan": opts["plan"], "map": opts["map"], "seed": int(opts["seed"]), "peace": opts["peace"],
		"version": ProjectSettings.get_setting("application/config/version", "dev"), "rows": rows, "firsts": firsts,
		"log": ai.sp_log.map(func(e: Array) -> String: return "%d %s" % [int(e[0]), String(e[1])]) if ai and ai.get("sp_log") != null else [],
		"wall_s": (Time.get_ticks_msec() - wall0) / 1000.0}
	var js := JSON.stringify(res)
	print("RESULT " + js)
	if String(opts["out"]) != "":
		var f := FileAccess.open(String(opts["out"]), FileAccess.WRITE)
		if f:
			f.store_string(js)
	quit()
