extends SceneTree
## ECONOMY BENCH (economy-parity, docs/economy_parity.md): measures each faction's ECONOMY DESIGN, not its computer's skill.
## One faction alone on a map (the other slot is an idle dummy that never moves), driven by a SCRIPTED IDEAL BUILD, the
## same plan for every faction:
##   - workers trained without a break (every hall / the Brood Mother's eggs) up to the posts its economy offers,
##     each new worker taking the game's own first post (Game.free_site / BroodNew.free_source; idle or released
##     workers are sent to a free post every 2 s);
##   - the faction's economy buildings as soon as they can be paid (Crown: 2 Farms + a Powder Mill a Town Hall; Clockwork:
##     2 Cog Presses + a Mainspring a Clocktower; Brood: Rootmaws wherever its spot finder has room, while its grubs fill them);
##   - supply buildings just in time (Cottage, Spring Tower, Mound Turtle at home);
##   - the 2nd base at exp1 (4:00) and the 3rd at exp2 (8:00) (Town Hall / Clocktower on the computer's own next hall
##     spot; the Brood: a Mound Turtle on new ground, its far spot finder, then Rootmaws round it); the Brood Mother
##     grows to stage 2 at exp1 (the computer plans do it about then);
##   - NO army, no research, no walls: everything goes into the economy, the rest stays in the bank.
## Buildings are laid where the computer would lay them (its spot finders, called on a computer player whose own
## thinking is switched off) and stand up after their build time without builders (one ideal builder, no walking).
## The secondary resources (powder, Tension) are counted as earned and taken out of the pool every second, so a full
## store never stops them.
##
##   godot --headless --fixed-fps 30 --script res://tools/econ_bench.gd -- <faction> [minutes=20] [map=greenhold]
##       [seed=1] [exp=240,480] [press=big|small] [ground=0|1] [out=<file.json>]
## ground=1: THE GROUND SYSTEM on (docs/ground_system.md); spent Farms / Presses still come down (_recycle).
## groundcap=off drink=N (ground-nocap-study, docs/ground_nocap_study.md): no hall limit on Farms / Presses, N of them a hall.
##
## Prints a line a minute and a final RESULT line (JSON): per minute the primary and secondary earned that minute and
## cumulative, workers, workers at work, halls / Rootmaws, the primary resource left (soil, brass, ground), spending.
## TOTAL VALUE = primary + secondary at 1:1 (a Musketeer is 60 gold + 10 powder, a Clock Soldier 70 cogs, a Springer
## 100 cogs + 25 Tension: one unit of each resource buys about the same fighting power; docs/economy_parity.md).
## (The pre-0.33.26 econ_bench, for the shelved Line's Boilers and Ore Crushers, is in git history.)

const DT := 1.0 / 30.0

var main: Node
var g: Game
var ai
var fac := "crown"
var opts := {"minutes": "20", "map": "greenhold", "seed": "1", "exp": "240,480", "press": "big", "out": "", "ground": "0"}
var t := 0.0
var started := false
var next_min := 60.0
var next_think := 0.0
var next_route := 0.0
var no_room := {}             # "kind@hall" -> clock: no spot found, not looked for again till then
var pending: Array = []        # [done_clock, kind, cell, big]
var exp_times: Array = []
var exp_done := 0
var grew := false
var r2_total := 0.0            # secondary earned (counted here: drained every second)
var last := {"p": 0.0, "s": 0.0, "spent": 0.0}
var rows: Array = []
var firsts := {}
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
		else:
			fac = a
	# (THE GROUND SYSTEM's numbers for a study: land.district=13 land.r.farm=10 land.r.cog_press=11 land.soil=9000...)
	GroundLayer.study_args(opts)
	for s in String(opts["exp"]).split(","):
		if s != "" and s != "auto":
			exp_times.append(float(s))
	wall0 = Time.get_ticks_msec()


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(int(opts["seed"]))
		var other := "crown" if fac != "crown" else "clockwork"
		main.start({"map": opts["map"], "seed": int(opts["seed"]), "ground": String(opts["ground"]) == "1", "ground_nocap": String(opts.get("groundcap", "on")) == "off", "slots": [
			{"who": "hard", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "you", "faction": other, "colour": 1, "side": 1, "strategy": "balanced"}]})
		g = main.game
		for a in g.ais:
			if a.team == 0:
				ai = a
			a.peaceful = true
			a.process_mode = Node.PROCESS_MODE_DISABLED
		started = true
		return false
	if not started or g == null:
		return false
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	_drain()
	if g.clock >= next_think:
		next_think = g.clock + 0.5
		_think()
	if g.clock >= next_route:
		next_route = g.clock + 2.0
		_route()
	if g.clock >= next_min:
		next_min += 60.0
		_row()
	if g.clock >= float(opts["minutes"]) * 60.0:
		_finish()
	return false


# ------------------------------------------------------------------ the secondary: counted and drained

func _drain() -> void:
	match fac:
		"crown":
			pass       # (powder: Game.add_res2 counts it in stats "res2_in"; the bank has no cap that stops a Mill)
		"clockwork":
			var v := g.tension(0)
			if v > 0.0:
				g.add_tension(0, -v)       # (stats "tension_in" counts what was wound; an empty pool never stops the springs)
		"brood":
			pass


func _primary() -> float:
	return float(g.stats[0]["gold"])


func _secondary() -> float:
	if fac == "clockwork":
		return float(g.stats[0].get("tension_in", 0.0))
	return float(g.stats[0]["res2_in"])


# ------------------------------------------------------------------ the scripted build

func _gold() -> int:
	return int(g.players[0]["gold"])


func _halls() -> Array:
	return g.halls_of(0, true)


func _hall_kind() -> String:
	return g.faction_hall(0)


func _workers() -> Array:
	return g.workers(0)


## Posts the economy offers (built buildings and the ones going up), and the workers on the way (in training, in eggs).
func _posts() -> int:
	var n := 0
	if fac == "brood":
		for u in g.units:
			if u.team == 0 and not u.dead and u.kind == BroodNew.MAW and BroodNew.rooted(u):
				n += BroodNew.crew_max(g, u)
			elif u.team == 0 and not u.dead and u.kind == "grub" and u.order == "nb_morph" and String(u.nb.get("mk", "")) == BroodNew.MAW:
				n += int(Defs.NB["maw_crew"])
		return n
	for b in g.buildings:
		if b.team == 0 and not b.dead and b.built and b.crew_max() > 0 and b.haul_cap() <= 0 and not b.barren():
			n += b.crew_max()
	for p in pending:
		n += int(Defs.BUILDINGS[p[1]].get("crew", 0)) if not (p[1] == Defs.GEAR_PRESS) else int(Defs.GEAR["press"]["big" if p[3] else "small"]["crew"])
	return n


func _coming() -> int:
	var n := 0
	if fac == "brood":
		for u in g.units:
			if u.team == 0 and not u.dead and u.kind == BroodNew.EGG and String(u.nb.get("k", "")) == "grub":
				n += 1
		return n
	for h in _halls():
		for k in h.queue:
			if k == Defs.FACTIONS[fac]["worker"]:
				n += 1
	return n


func _think() -> void:
	# finish what is going up
	for p in pending.duplicate():
		if g.clock >= float(p[0]):
			var c: Vector2i = p[2]
			if GearNet.pickable(p[1]):
				g.set_gear_pick(0, p[1], bool(p[3]))
			if g.placement_problem(0, p[1], c) != "":
				c = _spot(p[1])
				if c.x < 0:
					continue          # (no room yet: tried again next time)
			pending.erase(p)
			var b := g._add_building(p[1], 0, c, true)
			if GearNet.pickable(p[1]):
				b.gear_big = bool(p[3])
			if fac != "brood":
				g._recount_supply(0)
			if p[1] == _hall_kind():
				_first("hall_%d" % _halls().size())
	if fac == "brood":
		_think_brood()
		return
	# 1. the next base when its time has come (money kept for it first)
	var saving := 0
	if _exp_due():
		var hk := _hall_kind()
		var price := g.build_price(0, hk)
		if _gold() >= price:
			var spot: Vector2i = _spot(hk)
			if spot.x >= 0 and _lay(hk, spot, false):
				exp_done += 1
				_first("expansion_%d_laid" % exp_done)
		else:
			saving = price
	# 2. supply just in time
	_supply(saving)
	# 3. workers
	var want := _posts()
	var have := _workers().size() + _coming()
	for h in _halls():
		if have >= want:
			break
		if not h.queue.is_empty():
			continue
		var wk: String = Defs.FACTIONS[fac]["worker"]
		if _gold() - saving >= int(g.unit_price(0, wk)[0]) and g.supply_used(0) + 1 <= int(g.players[0]["cap"]):
			if g.train(h, wk) == "":
				have += 1
	# 4. economy buildings: spent ones pulled down (a player frees the hall limit for fresh ground), then each hall's
	#    own quota, the freshest hall first, one going up at a time
	_recycle()
	if pending.any(func(p: Array) -> bool: return Defs.is_econ(String(p[1]))):
		return
	var order: Array = ["farm", "farm", "powder_mill"] if fac == "crown" else [Defs.GEAR_PRESS, Defs.GEAR_PRESS, "mainspring"]
	var halls := _halls()
	halls.sort_custom(func(x: Building, y: Building) -> bool: return _fresh(x) > _fresh(y))
	for h in halls:
		if _fresh(h) <= 0.05:
			continue
		for k in order:
			var per := Defs.econ_per_hall(fac, k)
			if not g.econ_capped(k) and opts.has("drink"):
				per = int(opts["drink"])     # (ground-nocap-study: NO FARM/PRESS LIMIT, drink=N Farms / Presses a hall)
			if _of_hall(k, h) >= per or (g.econ_capped(k) and g.econ_count(0, k) >= g.econ_limit(0, k)):
				continue
			var big: bool = fac == "clockwork" and k == Defs.GEAR_PRESS and String(opts["press"]) == "big"
			if GearNet.pickable(k):
				g.set_gear_pick(0, k, big)
			if _gold() - saving < g.build_price(0, k):
				return
			var key := "%s@%d" % [k, h.serial]
			if float(no_room.get(key, -1.0)) > g.clock:
				continue
			var spot := _spot_by(k, h)
			if spot.x < 0 and big:
				big = false
				g.set_gear_pick(0, k, false)
				spot = _spot_by(k, h)
			if spot.x < 0:
				no_room[key] = g.clock + 15.0
				_first("no_room_" + key)
				continue
			_lay(k, spot, big)
			return


## The share of a hall's primary resource left (soil, raw brass).
func _fresh(h: Building) -> float:
	return h.soil_left() if fac == "crown" else h.lode_left()


## Economy buildings of kind k that belong to hall h (the nearest hall), built or going up.
func _of_hall(k: String, h: Building) -> int:
	var n := 0
	for b in g.buildings:
		if b.team == 0 and not b.dead and b.kind == k and g.nearest_hall(b.center(), 0) == h:
			n += 1
	for p in pending:
		if p[1] == k and _nearest_hall_at(k, p[2]) == h:
			n += 1
	return n


func _nearest_hall_at(k: String, c: Vector2i) -> Building:
	var ctr := (Vector2(c) + Vector2(Defs.BUILDINGS[k]["size"]) * 0.5) * Defs.TILE
	return g.nearest_hall(ctr, 0)


## A spot for kind k that belongs to hall h: the Clockwork's meshing finder round it; the Crown's "behind" search
## round it (its own level first), kept only if h is the nearest hall (else it would draw another hall's soil).
func _spot_by(k: String, h: Building) -> Vector2i:
	var c := Vector2i(-1, -1)
	if fac == "clockwork":
		c = GearEcon.room_spot(g, 0, k, [h], [], h.center(), true, 8)
	else:
		for mode in ["behind", "near"]:
			for ground in [true, false]:
				c = g.find_spot(0, k, h, 3, Defs.ECON_RANGE - 2, mode, ground)
				if c.x >= 0 and _nearest_hall_at(k, c) == h:
					return c
		return Vector2i(-1, -1)
	if c.x >= 0 and _nearest_hall_at(k, c) != h:
		return Vector2i(-1, -1)
	return c


## Spent economy buildings come down (Farms on spent soil, Mills on spent saltpetre, Presses on spent brass): their
## places under the hall limit go to fresh ground. (A FATIGUED Mainspring still winds a little and stays.)
func _recycle() -> void:
	for b in g.buildings:
		if b.team != 0 or b.dead or not b.built or not Defs.is_econ(b.kind) or b.kind == "mainspring":
			continue
		if b.barren():
			if g.ground_layer:
				var hh := g.nearest_hall(b.center(), 0)
				print("  (ground) %d s: a spent %s at %s pulled down, its hall's district %s" % [int(g.clock), b.kind, str(b.cell), str(g.ground_layer.district(hh)) if hh else "-"])
			_first("recycled_" + b.kind)
			g._remove_quietly(b)       # (pulled down; nobody hurt, nothing paid back)


## Where the computer would lay it: its economy spot finder for Farms, Mills, Presses and Mainsprings, its general one else.
func _spot(k: String) -> Vector2i:
	if Defs.is_econ(k):
		return ai._econ_spot(k)
	return ai._find_spot(k)


## Is the next base due? exp=<times>: at those clock times. exp=auto: as soon as the bases there are nearly full
## (workers within 2 of the posts) and nothing is already going up, from 1:00, up to 6 bases (a greedy ideal).
func _exp_due() -> bool:
	if String(opts["exp"]) == "auto":
		if g.clock < 60.0 or exp_done >= 5:
			return false
		if fac == "brood":
			if _morphing(BroodNew.TURTLE) > 0:
				return false
		elif _pending_of(_hall_kind()) > 0:
			return false
		var n := (BroodNew.count_of(g, 0, "grub") - _morphing("")) if fac == "brood" else _workers().size()
		return n + _coming() >= _posts() - 2
	return exp_done < exp_times.size() and g.clock >= float(exp_times[exp_done])


func _pending_of(k: String) -> int:
	return pending.filter(func(p: Array) -> bool: return p[1] == k).size()


func _supply(saving: int) -> void:
	var sk: String = Defs.FACTIONS[fac]["supply"]
	var cap := int(g.players[0]["cap"])
	if cap >= g.max_supply(0) or _pending_of(sk) > 0:
		return
	if g.supply_used(0) + _coming() + 2 + _halls().size() < cap:
		return
	if _gold() - saving < g.build_price(0, sk):
		return
	var spot: Vector2i = _spot(sk)
	if spot.x >= 0:
		_lay(sk, spot, false)


## Pay for a building and stand it up after its build time (no builder walks).
func _lay(k: String, c: Vector2i, big: bool) -> bool:
	if GearNet.pickable(k):
		g.set_gear_pick(0, k, big)
	var price := g.build_price(0, k)
	if _gold() < price or g.placement_problem(0, k, c) != "":
		return false
	g.players[0]["gold"] -= price
	g.stats[0]["spent"] += price
	# (no ghost: the game takes back a site nobody builds. One building of a kind goes up at a time, one ideal builder;
	# if its ground was taken meanwhile it goes up on the next spot found)
	pending.append([g.clock + float(Defs.BUILDINGS[k].get("time", 30.0)), k, c, big])
	_first(k + "_laid")
	return true


func _first(k: String) -> void:
	if not firsts.has(k):
		firsts[k] = int(g.clock)


# ------------------------------------------------------------------ the Brood's build

func _think_brood() -> void:
	var q := BroodNew.queen(g, 0)
	if q == null:
		return
	var saving := 0
	# her growth (stage 2) at the first expansion time
	if not grew and g.clock >= (float(exp_times[0]) if exp_times.size() > 0 else 240.0):
		if BroodNew.grow_problem(g, q) == "":
			BroodNew.grow(g, q)
			grew = true
			_first("grow_2")
		elif BroodNew.stage(q) < 1:
			saving = int(Defs.NB["stages"][1]["cost"])
	# new ground at the expansion times: a Mound Turtle on far ground
	if _exp_due():
		var price := int(g.unit_price(0, BroodNew.TURTLE)[0])
		if _gold() >= price + saving and BroodRoot.morph_problem(g, 0, BroodNew.TURTLE) == "":
			var picks: Array = ai._nb_far_spots(q)
			if picks.is_empty():
				picks = ai._nb_far_spots(q, 40.0)       # (the near ones taken: farther out, as the computer does)
			if not picks.is_empty() and _morph(BroodNew.TURTLE, picks[0]):
				exp_done += 1
				_first("expansion_%d_laid" % exp_done)
		else:
			saving += price
	# supply: a turtle at home
	var cap := int(g.players[0]["cap"])
	var walking_turtle := _morphing(BroodNew.TURTLE)
	if cap < g.max_supply(0) and walking_turtle == 0 and g.supply_used(0) + 4 >= cap:
		if _gold() - saving >= int(g.unit_price(0, BroodNew.TURTLE)[0]) and BroodRoot.morph_problem(g, 0, BroodNew.TURTLE) == "":
			var sp = ai._nb_supply_turtle_spot(q, null)
			if sp == null:
				sp = ai._nb_spot_for(q, BroodNew.TURTLE, null)
			if sp == null:
				var fp: Array = ai._nb_far_spots(q, 40.0)     # (no room at home: a turtle on new ground gives the same supply)
				if not fp.is_empty():
					sp = fp[0]
			if sp != null:
				_morph(BroodNew.TURTLE, sp)
	# grubs: eggs while the Rootmaws have posts
	var want := _posts()
	var grubs := BroodNew.count_of(g, 0, "grub") - _morphing("")
	var have := grubs + _coming()
	while have < want + 1 and _gold() - saving >= int(g.unit_price(0, "grub")[0]):
		if BroodNew.lay(g, q, "grub") != "":
			break
		have += 1
	# spent Rootmaws get up and walk to fresh ground (as the computer does: AIBroodNew._nb_rootmaws)
	for m in g.units:
		if m.team != 0 or m.dead or m.kind != BroodNew.MAW:
			continue
		if BroodNew.rooted(m) and float(m.nb.get("food", 0.0)) < 1.0 and BroodNew.ground_left(g, m) < 1.0:
			BroodNew.uproot(m, true)
			_first("maw_moved")
			continue
		if m.tesla_mode == "packed" and m.order != "nb_root" and m.target == null:
			var goal = ai._nb_find_spot(q, m)
			if goal != null:
				m.give({"o": "nb_root", "p": goal})
	# Rootmaws: one more when the posts are nearly all taken (one walking at a time)
	if _morphing(BroodNew.MAW) == 0 and grubs >= want - 2 and grubs >= 3:
		if _gold() - saving >= int(g.unit_price(0, BroodNew.MAW)[0]) and BroodRoot.morph_problem(g, 0, BroodNew.MAW) == "":
			var sp = ai._nb_spot_for(q, BroodNew.MAW, null)
			if sp != null and _morph(BroodNew.MAW, sp):
				_first("rootmaw_%d" % (BroodNew.count_of(g, 0, BroodNew.MAW) + 1))


func _morphing(k: String) -> int:
	var n := 0
	for u in g.units:
		if u.team == 0 and not u.dead and u.kind == "grub" and u.order == "nb_morph" and (k == "" or String(u.nb.get("mk", "")) == k):
			n += 1
	return n


func _morph(k: String, spot) -> bool:
	var best: Unit = null
	for u in g.units:
		if u.team == 0 and not u.dead and u.kind == "grub" and u.carrying == 0 and u.cocoon <= 0.0 and u.order != "nb_morph" \
				and (best == null or u.position.distance_squared_to(spot) < best.position.distance_squared_to(spot)):
			best = u
	if best == null:
		return false
	best.give({"o": "nb_morph", "k": k, "p": spot})
	return true


# ------------------------------------------------------------------ idle workers back to work

func _route() -> void:
	for u in _workers():
		if u.dead:
			continue
		if fac == "brood":
			if u.order == "nb_morph" or u.cocoon > 0.0:
				continue
			if u.order == "gather" and u.home_mine != null and is_instance_valid(u.home_mine) and not u.home_mine.dead:
				continue
			var src := BroodNew.free_source(g, 0, u.position)
			if src != null:
				u.cmd_gather(src)
			continue
		var hm = u.home_mine
		var ok: bool = u.order == "gather" and hm != null and is_instance_valid(hm) and not hm.dead and hm is Building \
				and hm.haul_cap() <= 0 and not hm.barren()
		if ok:
			continue
		var site := g.free_site(0, u.position)
		if site != null and site.haul_cap() <= 0 and not site.barren():
			u.cmd_gather(site)


# ------------------------------------------------------------------ the record

func _left() -> float:
	var n := 0.0
	if fac == "brood":
		for u in g.units:
			if u.team == 0 and not u.dead and u.kind == BroodNew.MAW and BroodNew.rooted(u):
				n += BroodNew.ground_left(g, u)
		return n
	for h in _halls():
		if fac == "crown":
			n += float(h.soil)
		else:
			n += h.lode_left() * float(Defs.LODE["clocktower"])
	return n


func _row() -> void:
	var p := _primary()
	var s := _secondary()
	var ws := _workers()
	var working := ws.filter(func(u: Unit) -> bool: return u.order == "gather" and u.home_mine != null).size()
	var econ := {}
	if fac == "brood":
		econ["rootmaw"] = BroodNew.count_of(g, 0, BroodNew.MAW)
		econ["turtle"] = BroodNew.count_of(g, 0, BroodNew.TURTLE)
		var q := BroodNew.queen(g, 0)
		econ["stage"] = BroodNew.stage(q) + 1 if q else 0
		econ["lay_x"] = snappedf(BroodNew.egg_rate(g, 0), 0.01)
	else:
		for k in Defs.FACTIONS[fac]["econ"].keys():
			econ[k] = g.econ_count(0, k)
		econ["halls"] = _halls().size()
	var row := {"min": rows.size() + 1, "p": int(p - float(last["p"])), "s": snappedf(s - float(last["s"]), 0.1),
		"p_cum": int(p), "s_cum": snappedf(s, 0.1), "workers": ws.size(), "working": working, "econ": econ,
		"left": int(_left()), "bank": _gold(), "spent": int(g.stats[0]["spent"]), "supply": g.supply_used(0), "cap": int(g.players[0]["cap"])}
	row["value"] = int(row["p"] + row["s"])
	row["value_cum"] = int(p + s)
	row["per_worker"] = snappedf(float(row["value"]) / maxf(1.0, float(working)), 0.1)
	rows.append(row)
	last["p"] = p
	last["s"] = s
	print("%s min %2d  value %5d (+%5d cum %6d)  p %5d s %5.0f  workers %3d (%3d at work, %5.1f each)  %s  left %6d  bank %5d  supply %d/%d" % [
		fac, row["min"], row["value"], row["value"], row["value_cum"], row["p"], row["s"], row["workers"], row["working"],
		row["per_worker"], JSON.stringify(econ), row["left"], row["bank"], row["supply"], row["cap"]])


func _finish() -> void:
	var res := {"faction": fac, "map": opts["map"], "seed": int(opts["seed"]), "exp": exp_times, "press": opts["press"],
		"ground": Defs.ground_on, "version": ProjectSettings.get_setting("application/config/version", "dev"), "rows": rows, "firsts": firsts,
		"wall_s": (Time.get_ticks_msec() - wall0) / 1000.0}
	var js := JSON.stringify(res)
	print("RESULT " + js)
	if String(opts["out"]) != "":
		var f := FileAccess.open(String(opts["out"]), FileAccess.WRITE)
		if f:
			f.store_string(js)
	quit()
