extends SceneTree
## THE COMPUTER ALONE (econ-coach-crown, docs/econ-coach-crown.md): the economy bench's setup (tools/econ_bench.gd: one
## faction alone on a map, the other slot an idle dummy that never moves) but the COMPUTER plays instead of the script:
## what share of its economy's design does it reach with nobody in its way?
## The dummy (a human slot nobody plays) is kept standing (its buildings and units healed every half second), so the
## computer's army may walk over and fight it forever but the game never ends; its faction (`foe`) is what the computer's
## scout reads.
##
##   godot --headless --fixed-fps 30 --script res://tools/econ_ai_alone.gd -- <faction> [plan=optimal] [minutes=15]
##       [map=greenhold] [seed=1] [foe=clockwork] [who=hard] [out=<file.json>] [switch=<AI switch>] [ground=0|1]
##
## Prints a line a minute and a final RESULT line (JSON), the bench's row (p, s, p_cum, s_cum, value, value_cum, workers,
## working, econ, halls, left, bank, supply, cap) plus what the computer wastes: idle workers (seconds a minute summed over
## workers), builders, haulers and others, spent Farms still standing, the crew on Farms and Mills against their caps,
## seconds supply-blocked, seconds each production building stood idle, the army's value, money banked, the plan played.

const DT := 1.0 / 30.0

var main: Node
var g: Game
var ai
var fac := "crown"
var opts := {"minutes": "15", "map": "greenhold", "seed": "1", "plan": "optimal", "foe": "clockwork", "who": "hard",
	"out": ""}
var t := 0.0
var started := false
var next_min := 60.0
var next_tick := 0.0
var last := {"p": 0.0, "s": 0.0}
var rows: Array = []
var acc := {}
var halls_at: Array = []
var plans: Array = []
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
		elif not ":" in a:
			fac = a       # (study switches such as line:off pass through to the computer)
	GroundLayer.study_args(opts)      # (THE GROUND SYSTEM: land.<key>=<n> for a study)
	wall0 = Time.get_ticks_msec()
	_reset_acc()


func _reset_acc() -> void:
	acc = {"idle": 0.0, "build": 0.0, "haul": 0.0, "other": 0.0, "gather": 0.0, "blocked": 0.0, "prod_idle": 0.0,
		"prod": 0.0, "farm_crew": 0.0, "farm_cap": 0.0, "mill_crew": 0.0, "mill_cap": 0.0, "spent_farms": 0.0, "n": 0.0,
		"bank": 0.0}


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(int(opts["seed"]))
		var cfg := {"map": opts["map"], "seed": int(opts["seed"]), "ground": String(opts.get("ground", "0")) == "1", "slots": [
			{"who": opts["who"], "faction": fac, "colour": 0, "side": 0, "strategy": opts["plan"]},
			{"who": "you", "faction": opts["foe"], "colour": 1, "side": 1, "strategy": "balanced"}]}
		main.start(cfg)
		g = main.game
		for a in g.ais:
			if a.team == 0:
				ai = a
		started = true
		return false
	if not started or g == null:
		return false
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if g.clock >= next_tick:
		next_tick = g.clock + 0.5
		_tick()
	if g.clock >= next_min:
		next_min += 60.0
		_row()
	if g.clock >= float(opts["minutes"]) * 60.0 or g.over:
		_finish()
	return false


func _workers() -> Array:
	return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and not u.dead and u.is_worker())


func _halls() -> Array:
	var hk: String = Defs.FACTIONS[fac]["hall"]
	return g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and not b.dead and b.kind == hk and b.built)


func _tick() -> void:
	# the dummy stands for ever
	for b in g.buildings:
		if b.team == 1 and not b.dead:
			b.hp = b.max_hp
	for u in g.units:
		if u.team == 1 and not u.dead:
			u.hp = u.max_hp
	var dt := 0.5
	acc["n"] += 1.0
	for u in _workers():
		match u.order:
			"idle":
				acc["idle"] += dt
			"gather":
				if u.home_mine != null:
					acc["gather"] += dt
				else:
					acc["idle"] += dt
			"build":
				acc["build"] += dt
			_:
				if "haul" in u.order or ("haul_job" in u and not u.haul_job.is_empty()):
					acc["haul"] += dt
				else:
					acc["other"] += dt
	var cap := int(g.players[0]["cap"])
	if cap < 200 and g.supply_used(0) >= cap - 1:
		acc["blocked"] += dt
	for b in g.buildings:
		if b.team != 0 or b.dead or not b.built:
			continue
		if b.kind in ["barracks", "foundry"]:
			acc["prod"] += dt
			if b.queue.is_empty():
				acc["prod_idle"] += dt
		elif b.kind == "farm":
			if b.barren():
				acc["spent_farms"] += dt
			else:
				acc["farm_crew"] += float(b.working_crew()) * dt
				acc["farm_cap"] += float(b.crew_max()) * dt
		elif b.kind == "powder_mill":
			acc["mill_crew"] += float(b.working_crew()) * dt
			acc["mill_cap"] += float(b.crew_max()) * dt
	acc["bank"] += float(g.players[0]["gold"]) * dt
	var nh := _halls().size()
	while halls_at.size() < nh:
		halls_at.append(int(g.clock))
	if ai and plans.size() == 0 or (ai and String(plans[-1][1]) != String(ai.strategy)):
		plans.append([int(g.clock), String(ai.strategy)])


func _primary() -> float:
	return float(g.stats[0]["gold"])


func _secondary() -> float:
	if fac == "clockwork":
		return float(g.stats[0].get("tension_in", 0.0))
	return float(g.stats[0]["res2_in"])


func _left() -> float:
	var v := 0.0
	for h in _halls():
		v += h.lode_left() * float(Defs.LODE["clocktower"]) if fac == "clockwork" else float(h.soil)
	return v


func _row() -> void:
	var p := _primary()
	var s := _secondary()
	var ws := _workers()
	var working := ws.filter(func(u: Unit) -> bool: return u.order == "gather" and u.home_mine != null).size()
	var econ := {}
	for k in Defs.FACTIONS[fac]["econ"].keys():
		econ[k] = g.econ_count(0, k)
	econ["halls"] = _halls().size()
	var row := {"min": rows.size() + 1, "p": int(p - float(last["p"])), "s": snappedf(s - float(last["s"]), 0.1),
		"p_cum": int(p), "s_cum": snappedf(s, 0.1), "workers": ws.size(), "working": working, "econ": econ,
		"left": int(_left()), "bank": int(g.players[0]["gold"]), "supply": g.supply_used(0), "cap": int(g.players[0]["cap"]),
		"army": g.army_value(0), "plan": String(ai.strategy) if ai else ""}
	row["value"] = int(row["p"] + row["s"])
	row["value_cum"] = int(p + s)
	var n := maxf(1.0, float(acc["n"]))
	row["idle_s"] = int(acc["idle"])
	row["build_s"] = int(acc["build"])
	row["haul_s"] = int(acc["haul"])
	row["other_s"] = int(acc["other"])
	row["blocked_s"] = int(acc["blocked"])
	row["prod_idle"] = snappedf(float(acc["prod_idle"]) / maxf(1.0, float(acc["prod"])), 0.01)
	row["farm_fill"] = snappedf(float(acc["farm_crew"]) / maxf(1.0, float(acc["farm_cap"])), 0.01)
	row["mill_fill"] = snappedf(float(acc["mill_crew"]) / maxf(1.0, float(acc["mill_cap"])), 0.01)
	row["spent_farms"] = snappedf(float(acc["spent_farms"]) / 30.0, 0.1)
	row["bank_avg"] = int(float(acc["bank"]) / 60.0)
	rows.append(row)
	last["p"] = p
	last["s"] = s
	_reset_acc()
	print("%s %s min %2d  value %5d cum %6d  workers %3d (%3d at work; idle %3ds build %3ds haul %3ds other %3ds)  farms %.2f mills %.2f spentF %.1f  %s  bank %5d  supply %d/%d blk %ds  prod idle %.2f  army %d  %s" % [
		fac, opts["plan"], row["min"], row["value"], row["value_cum"], row["workers"], row["working"], row["idle_s"],
		row["build_s"], row["haul_s"], row["other_s"], row["farm_fill"], row["mill_fill"], row["spent_farms"],
		JSON.stringify(econ), row["bank"], row["supply"], row["cap"], row["blocked_s"], row["prod_idle"], row["army"], row["plan"]])


func _finish() -> void:
	var res := {"faction": fac, "plan": opts["plan"], "map": opts["map"], "seed": int(opts["seed"]), "foe": opts["foe"],
		"version": ProjectSettings.get_setting("application/config/version", "dev"), "rows": rows, "halls_at": halls_at,
		"plans": plans, "wall_s": (Time.get_ticks_msec() - wall0) / 1000.0, "over": g.over}
	var js := JSON.stringify(res)
	print("RESULT " + js)
	if String(opts["out"]) != "":
		var f := FileAccess.open(String(opts["out"]), FileAccess.WRITE)
		if f:
			f.store_string(js)
	quit()
