class_name AIClockwork
extends AI
## THE CLOCKWORK'S COMPUTER OF ITS OWN (the owner, 2026-11-03; docs/clockwork_ai_rebuild.md). The first step of rebuilding
## the Clockwork computer the way the Brood's was (scripts/ai_brood_new.gd): it extends the shared computer (scripts/ai.gd),
## so the good shared parts (the scout, the swarm rules, worker safety, the escorts, home defence, the micro, gg) keep
## working, and it adds PLANS of its own, each a REAL OPENING BUILD ORDER:
##  - an ordered list of steps, each triggered by SUPPLY ("9 mainspring": at 9 supply, a Mainspring) or by what exists (a
##    step whose building or Tension is not there yet waits), never by the clock: the income comes in lumps and the economy
##    keeps changing;
##  - the plan OWNS the gold while the opening runs: the next step's cogs (and Tension) are put by first; Winders are
##    trained only from what is left over; the shared computer's own building, training and research are off meanwhile
##    (no hiding of gold);
##  - after its "end" step (the attack has left, the expansion is laid) it hands over to the shared computer's rules, on the
##    plan's STRATEGIES row (Balanced numbers) - the milestone rules of later jobs will take this place.
## Only ONE plan is new so far, the SPRINGER TIMING (the owner's, 2026-11-03: "as soon as possible, 4 Springers that can jump
## and 1 flying unit that can scout... It isn't an all-in, the economy is still being built behind this"): a Light Works,
## a Mainspring and an Escapement, a second Works, HIGH LEAP, a Clock Aviary, 4 Springers and a Swift; the Springers and
## the Swift go to the SPRINGER RAID (scripts/ai_springer_raid.gd): the Swift gives the sight of a landing spot on the enemy's
## high ground, away from its guns; the Springers leap up, shoot the workers, leap out when hurt or when the defence comes, are
## wound up again by two Winders at the cliff foot and leap in again elsewhere (the Blink-stalker idea).
## The other Clockwork plans play exactly as before (the shared computer). `-- cwnew:off` on the command line plays the
## Springer timing as the old computer's Balanced, for comparisons.
## No cheating: it knows where the enemy started (as every computer does) and otherwise only what its side sees.

const SpringerRaid := preload("res://scripts/ai_springer_raid.gd")
## (cw-builds-a: the Clock Soldier rush and the Turret turtle, scripts/ai_cw_builds_a.gd, docs/clockwork_builds_a.md)
const BuildsA := preload("res://scripts/ai_cw_builds_a.gd")
var bta = null
## (cw-builds-c: the Owl raids, scripts/ai_cw_builds_c.gd, docs/clockwork_builds_c.md)
const BuildsC := preload("res://scripts/ai_cw_builds_c.gd")
var btc = null
## (clockwork-eco: the Economy and Balanced openings, scripts/ai_cw_eco.gd, docs/clockwork_eco.md)
const BuildsEco := preload("res://scripts/ai_cw_eco.gd")
var bte = null
var eco_on := BuildsEco.on()

## THE PLANS. "steps": the build order, read in order (see _do_step):
##   "N kind[:big]"         at N supply (used, queued included), lay a building (a Clockwork building kind)
##   "kind[:big]"           lay it as soon as it is allowed and paid for
##   "workers N"            from now on, keep the Clocktowers training Winders up to N (from the cogs left over)
##   "crew mainspring N"    keep N Winders on each fresh Mainspring (Tension first: the presses fill first by themselves)
##   "research key"         start a research (where it is made)
##   "unit N"               train N of that unit (every building that can make it, one in each queue at a time)
##   "attack"               the raid takes the Springers and the Swift once the plan's raid force is out (ai_springer_raid)
##   "end"                  the opening is over: the shared computer plays on
##   (cw-builds-a, scripts/ai_cw_builds_a.gd: "rush", "rush_over", "turret ramp|hall2", "ramp_regulator", "works_back")
## A step waiting for a building or for Tension does not stop the next ones: they may go with the cogs left after its price
## (a player reads ahead the same way); a step waiting for COGS, or for its supply, stops the reading there.
##  workers0       Winders at the start of the build (before the "workers" steps)
##  raid           Springers the raid wants before it goes; raid_winders: the Winders at the cliff foot that wind them
##  raid_keep      Springers the raid is topped up to from the army at home, after the opening (re-supply)
##  decoys         Clock Soldiers the raid takes for its diversion at the enemy's ramp
## The Springer timing's Mainspring is on its BIG ring with 6 Winders (2.6 Tension a second, stores 400): Tension is what
## holds the plan back (HIGH LEAP 100, the Aviary 50, 4 Springers 100, the Swift 15: 265 in about two minutes); the small
## ring (2.0 a second with 3) made it ready at 4:41 on Greenhold, the big one at 4:19.
const PLANS := {
	"springer": {
		"workers0": 14, "raid": 4, "raid_winders": 2, "raid_keep": 6, "decoys": 4,
		"steps": [
			"7 cog_press",
			"8 movement_works",
			"9 mainspring:big",
			"crew mainspring 6",
			"11 regulator",
			"escapement",
			"movement_works",
			"workers 18",
			"research high_leap",
			"cuckoo_house",
			"springer 4",
			"18 regulator",
			"cuckoo 1",
			"clock_soldier 4",
			"attack",
			"workers 21",
			"clocktower",
			"end",
		],
	},
	# THE CLOCK SOLDIER RUSH (cw-builds-a; scripts/ai_cw_builds_a.gd, docs/clockwork_builds_a.md): two Light Works early,
	# Clock Soldiers from both; the first `rush` go at the enemy's workers with `rush_winders` Winders to wind them; fresh
	# ones follow in groups; once the rush is judged the build turns to the economy (no trickling).
	"cs_rush": {
		"workers0": 11, "rush": 6, "rush_winders": 2,
		"steps": [
			"6 movement_works",
			"7 cog_press",
			"9 regulator",
			"9 movement_works",
			"workers 12",
			"clock_soldier 6",
			"rush",
			"16 regulator",
			"clock_soldier 6",
			"rush_over",
			"turret ramp",
			"mainspring",
			"crew mainspring 3",
			"workers 20",
			"clocktower",
			"escapement",
			"end",
		],
	},
	# THE TURRET TURTLE (cw-builds-a): a Ratchet Turret each side of the main's ramp top, a FAST second Clocktower behind
	# them and a turret by it, then the Mainspring and the Escapement; the shared computer plays on with a later, bigger
	# first wave (the "turtle" row of AI.STRATEGIES).
	"turtle": {
		"workers0": 14,
		"steps": [
			"7 cog_press",
			"8 ramp_regulator",
			"works_back",
			"turret ramp",
			"workers 16",
			"clocktower",
			"turret ramp",
			"clock_soldier 2",
			"workers 22",
			"turret hall2",
			"mainspring",
			"crew mainspring 3",
			"escapement",
			"workers 26",
			"end",
		],
	},
}
## cw-builds-b (docs/clockwork_builds_b.md): the PENDULUMS against the Brood and the HEAVY WORKS PUSH (PLANS_B, the push:
## scripts/ai_cw_push.gd). Kept apart from PLANS so the builds of the other jobs merge cleanly.
const PLANS_B := preload("res://scripts/ai_cw_builds_b.gd").PLANS

var cw_on := not OS.get_cmdline_user_args().has("cwnew:off")
var plan := {}
var over := {}                  # (a coach or a tool forces plan settings: tools/play_clockwork_springer.gd)
var bo_on := false              # the opening build runs
var steps: Array = []
var done: Array = []
var step_log: Array = []        # {"step", "at"} when each step was done
var sp_log: Array = []          # [clock, text]: what the plan and the raid decided (tests and tools read it)
var raid = null
var worker_goal := 0
var spring_crew := 0
var _placed := {}               # step index -> the Building laid for it (watched until it stands; lost: laid again)
var _stood := {}                # step index -> true once its building stood
var _queued := {}               # step index -> units queued for it
var _hold := 0                  # cogs put by for the steps waiting
var _hold2 := 0.0               # Tension put by
var _bo_t := 0.0


func _ready() -> void:
	super()
	if strategy == "springer" and not cw_on:
		strategy = "balanced"
		_opened = "balanced"
		_attack_at = int(_s("wave"))
		note("cwnew:off: the Springer timing plays as the old computer's Balanced")
		return
	if not (PLANS.has(strategy) or PLANS_B.has(strategy) or BuildsC.PLANS.has(strategy) or _eco_plan()) or not Defs.gear_mode:
		return
	_make_plan()
	_b_ready()          # (cw-builds-b: the push, scripts/ai_cw_push.gd)
	bo_on = true
	if scout != null and not _eco_plan():
		scout.enabled = false          # (the plan does not change on what a scout sees while it runs; its Swift scouts)
	# (clockwork-eco: the Economy and Balanced openings keep the scout: rush evidence is their only reason for an early army)
	note("plays the %s: the opening build (%d steps)" % [String(STRATEGIES[strategy]["name"]), steps.size()])


## clockwork-eco: Economy and Balanced play a written opening (ai_cw_eco.gd) unless `-- cweco:off`.
func _eco_plan() -> bool:
	return eco_on and BuildsEco.PLANS.has(strategy)


## (clockwork-eco) While the Economy or Balanced opening runs it owns the gold: the scout's "play safe" Works (AIScout
## _defence: two Light Works for a scout that saw nothing) are not built; rush evidence is answered by the plan (bte.urgent).
func bo_owns() -> bool:
	return bo_on and _eco_plan()


## (clockwork-eco) After the opening, an enemy the scout could not see is still no reason for two Works at once: only rush
## evidence is (AIScout._defence asks).
func eco_calm() -> bool:
	return _eco_plan()


func _make_plan() -> void:
	if _eco_plan():
		plan = (BuildsEco.PLANS[strategy] as Dictionary).duplicate(true)
	else:
		plan = ((PLANS[strategy] if PLANS.has(strategy) else (PLANS_B[strategy] if PLANS_B.has(strategy) else BuildsC.PLANS[strategy])) as Dictionary).duplicate(true)
	for k in over:
		plan[k] = over[k]
	steps = (plan["steps"] as Array).duplicate()
	done.resize(steps.size())
	done.fill(false)
	worker_goal = int(plan["workers0"])
	raid = SpringerRaid.new(self)
	bta = BuildsA.new(self)
	btc = BuildsC.new(self)
	bte = BuildsEco.new(self)


func note(s: String) -> void:
	sp_log.append([game.clock if game else 0.0, s])
	if game and game.mlog:
		game.mlog.add("%s's Clockwork: %s" % [game.mlog.who(team), s])


## The plan's own Springers (the raid's), its Swift and its Winders at the cliff foot are not the shared computer's.
func _on_errand(u: Unit) -> bool:
	return super._on_errand(u) or (raid != null and raid.has(u)) or (bta != null and bta.has(u)) or (btc != null and btc.has(u)) or (push != null and push.has(u))


func _held_worker(u: Unit) -> bool:
	return (raid != null and raid.has(u)) or (bta != null and bta.has(u)) or (btc != null and btc.has(u))


# ------------------------------------------------------------------ the shared computer's parts, off while the build runs

func _s(key: String) -> Variant:
	if bo_on:
		match key:
			"workers":
				return 0.0          # (the build trains its Winders itself: _train_workers)
			"wave", "timing":
				return 99999
	return super._s(key)


func _econ_build() -> void:
	if not bo_on:
		super._econ_build()


func _produce() -> void:
	if not bo_on:
		_b_keep()           # (cw-builds-b: the plan's heavy machines first, after the opening)
		super._produce()


func _research() -> void:
	if not bo_on:
		super._research()


func _supply() -> void:
	if not bo_on:
		super._supply()


func _build_up() -> void:
	if bo_on:
		_bo_tick()
	else:
		super._build_up()


func _army() -> void:
	if bo_on or push != null:
		_attack_at = 99999
	if raid != null:
		raid.tick()
	if bta != null:
		bta.tick()
	if push != null:
		push.tick()
		_b_rewind()
	if btc != null:
		btc.tick()
	super._army()


# ------------------------------------------------------------------ the build order

func _bo_tick() -> void:
	_watch_sites()
	_crew_springs()
	_hold = 0
	_hold2 = 0.0
	_supply_guard()
	if bte != null and _eco_plan():
		bte.urgent()            # (clockwork-eco: the rush reaction, ahead of every step)
		# (clockwork-eco: Winders NON-STOP from every Clocktower, one in each queue, before the steps put cogs by: the old
		# order saved 400 cogs for the Clocktower with the Winders stopped at 9 for a minute; the owner's own game kept
		# them coming, 12 at 2:00, 17 at 3:00)
		_train_workers()
	var ahead := 0
	var i := 0
	while i < steps.size() and ahead < 3:
		if done[i]:
			i += 1
			continue
		var r := _do_step(i)
		var st := String(r["st"])
		if st == "done":
			done[i] = true
			step_log.append({"step": steps[i], "at": snappedf(game.clock, 0.1)})
			if String(steps[i]) == "end":
				_end_build("its end step")
				return
			i += 1
			continue
		if st == "supply":
			break
		if ahead == 0:
			# (the first step held up puts its price by; the ones read past it only go with what is left, they put
			# nothing by: a far step waiting for a building that is not even laid must not starve the Winders)
			_hold += int(r.get("cost", 0))
			_hold2 += float(r.get("t", 0.0))
		if st == "money":
			break
		ahead += 1          # (waiting for a building or for Tension: the next step may go with the cogs left)
		i += 1
	if not done.has(false):
		_end_build("the last step")
		return
	_train_workers()


func _end_build(why: String) -> void:
	bo_on = false
	if scout != null:
		scout.enabled = difficulty >= 1 and not peaceful
	_attack_at = maxi(int(super._s("wave")), _army_supply(game.army(team).filter(func(u: Unit) -> bool: return not _on_errand(u))) + 4)
	note("the opening build is over (%s) at %d supply: the computer plays on (%s numbers)" % [why, game.supply_used(team), String(STRATEGIES[strategy]["name"])])


## The cogs (and Tension) free now: what is in the bank less what the waiting steps have put by.
func _free() -> int:
	return _gold() - _hold


func _free_t() -> float:
	return game.tension(team) - _hold2


## One step: {"st": "done" | "supply" (its supply is not reached) | "money" (its cogs) | "wait" (a building or Tension),
## "cost", "t"}.
func _do_step(i: int) -> Dictionary:
	var s := String(steps[i])
	var parts := s.split(" ")
	if parts.size() >= 2 and parts[0].is_valid_int():
		if game.supply_used(team) < int(parts[0]):
			return {"st": "supply"}
		parts = parts.slice(1)
	var head := String(parts[0])
	match head:
		"end":
			# (only once every step before it is done: the attack has gone, the expansion is laid)
			for j in i:
				if not done[j]:
					return {"st": "wait"}
			return {"st": "done"}
		"workers":
			worker_goal = int(parts[1])
			return {"st": "done"}
		"crew":
			spring_crew = int(parts[2])
			_crew_springs()
			return {"st": "done"}
		"research":
			return _do_research(String(parts[1]))
		"attack":
			return {"st": "done"} if raid.launch() else {"st": "wait"}
	if bta != null:
		var ra: Dictionary = bta.step(i, parts)
		if not ra.is_empty():
			return ra
	if bte != null:
		var re: Dictionary = bte.step(i, parts)
		if not re.is_empty():
			return re
	if btc != null:
		var rc: Dictionary = btc.step(i, parts)
		if not rc.is_empty():
			return rc
	if parts.size() >= 2 and Defs.UNITS.has(head):
		return _do_units(i, head, int(parts[1]))
	var big := head.ends_with(":big")
	var kind := head.trim_suffix(":big")
	if Defs.BUILDINGS.has(kind):
		return _do_build(i, kind, big)
	push_warning("AIClockwork: unknown step " + s)
	return {"st": "done"}


func _do_build(i: int, kind: String, big: bool) -> Dictionary:
	if _placed.has(i):
		return {"st": "done"}
	if GearNet.pickable(kind):
		game.set_gear_pick(team, kind, big)
	var cost := game.build_price(team, kind)
	var tc := float(Defs.tension_cost(Defs.BUILDINGS[kind]))
	if Defs.is_econ(kind) and game.econ_count(team, kind) >= game.econ_limit(team, kind):
		note("%s: over the limit, skipped" % kind)
		return {"st": "done"}
	if not game.requirement_met(team, kind):
		return _wait_req()
	if _free_t() < tc:
		return _wait_t(cost, tc)
	if _free() < cost:
		return {"st": "money", "cost": cost, "t": tc}
	var spot := _spot(kind)
	if spot.x < 0:
		return {"st": "wait", "cost": cost, "t": tc}
	var b := _lay(kind, spot, big)
	if b == null:
		return {"st": "wait", "cost": cost, "t": tc}
	_placed[i] = b
	if kind == "mainspring" and plan.has("push") and not _b_spring.is_empty() and _b_spring[0] == spot:
		_keep_heavy(spot, _b_spring[1])        # (cw-builds-b: the Escapement's and the Heavy Works' spots by it are kept)
	note("lays a %s at %d supply (step %d: %s)" % [String(Defs.BUILDINGS[kind]["name"]), game.supply_used(team), i + 1, String(steps[i])])
	return {"st": "done"}


## Where a building of the build goes (the shared computer's placement: a Mainspring with room round it for the Escapement,
## the Tension users anywhere its gear network reaches, by the Mainspring first).
func _spot(kind: String) -> Vector2i:
	match kind:
		"cog_press":
			return _econ_spot(kind)
		"mainspring":
			var c := _spring_spot()
			_b_spring = [c, _spring_users.duplicate()] if c.x >= 0 and _spring_heavy else []
			return c if c.x >= 0 else _any_gear_spot(kind)
		"heavy_works":
			return _b_heavy_spot()
		"escapement", "cuckoo_house":
			if kind == "escapement" and not _kept(kind).is_empty():
				return _kept(kind)["cell"]
			for sp in _mine("mainspring"):
				if not sp.dead:
					var c2 := GearEcon.room_spot(game, team, kind, [sp])
					if c2.x >= 0:
						return c2
			return _any_gear_spot(kind)
		"clocktower":
			if sites_on:
				return _safe_hall_spot()        # (clockwork-eco: the Clockwork's own spot, room for its ring: ClockSites)
			if game.expansions.size() > team and game.expansions[team] is Vector2i and game.placement_problem(team, kind, game.expansions[team], true) == "":
				return game.expansions[team]
			return _safe_hall_spot()
	var f := _find_spot(kind)
	return f if f.x >= 0 else _any_gear_spot(kind)


## AI._construct, returning the site (the nearest free Winder; the trip is by a Clocktower, where he fetches the crate).
func _lay(kind: String, spot: Vector2i, big: bool) -> Building:
	var best: Unit = null
	var bd := INF
	var target := Vector2(spot) * Defs.TILE
	var towers: Array = _halls().filter(func(h: Building) -> bool: return h.built)
	for u in game.workers(team):
		if u.order == "build" or u.crate_site != null or _escort.has(u) or (scout != null and scout.is_scout(u)) or _held_worker(u):
			continue
		var trip: float = u.position.distance_to(target)
		if not towers.is_empty():
			trip = INF
			for h in towers:
				trip = minf(trip, u.position.distance_to(h.center()) + h.center().distance_to(target))
		var dd: float = trip + (0.0 if u.order == "idle" else 150.0) + (200.0 if u.carrying > 0 else 0.0) \
			+ (300.0 if u.home_mine != null and u.home_mine.kind == "mainspring" else 0.0)
		if dd < bd:
			bd = dd
			best = u
	if best == null:
		return null
	return game.place_building(team, kind, spot, [best], false, 1 if big else (0 if GearNet.pickable(kind) else -1))


func _do_research(key: String) -> Dictionary:
	var info: Dictionary = Defs.RESEARCH[key]
	var cost := int(info["cost"])
	var tc := float(info.get("tension", 0))
	if game.has_tech(team, key) or game.researching(team, key):
		return {"st": "done"}
	for b in _mine(String(info["at"])):
		if b.built and (b.queue as Array).is_empty() and _maker_ok(game.research_problem(b, key)):
			if _free_t() < tc:
				return _wait_t(cost, tc)
			if _free() < cost:
				return {"st": "money", "cost": cost, "t": tc}
			if game.research_problem(b, key) != "":
				return _wait_req()
			game.start_research(b, key)
			note("researches %s" % String(info["name"]).to_upper())
			return {"st": "done"}
	return _wait_req()


## Waiting for a building (its requirement, a free maker): nothing is put by for it yet (the cogs come in faster than a
## building stands up; the Winders would wait for nothing).
func _wait_req() -> Dictionary:
	return {"st": "wait", "cost": 0, "t": 0.0}


## Waiting for Tension: its cogs are put by only when the Tension is due within TENSION_SOON s (the Mainsprings' rate).
const TENSION_SOON := 12.0


func _wait_t(cost: int, tc: float) -> Dictionary:
	var short := tc - _free_t()
	var rate := game.tension_rate(team)
	var soon := rate > 0.05 and short / rate < TENSION_SOON
	return {"st": "wait", "cost": cost if soon else 0, "t": tc}


## A maker's problem that only money or Tension will solve ("" or a price message).
func _maker_ok(why: String) -> bool:
	return why == "" or why.begins_with("Not enough") or why.begins_with("Need more") or why.contains("Tension") and not why.contains("Mainspring")


## Train n of a unit: at every building that can make it, one in its queue at a time (the Tension comes as it is wound).
func _do_units(i: int, kind: String, n: int) -> Dictionary:
	var q := int(_queued.get(i, 0))
	var p := game.unit_price(team, kind)
	var from := String(Defs.UNITS[kind]["from"])
	var makers := 0
	for b in _mine(from):
		if q >= n:
			break
		if not b.built or not _maker_ok(game.can_train(b, kind)):
			continue
		makers += 1
		if not (b.queue as Array).is_empty():
			continue
		if _free() < int(p[0]) or _free_t() < float(p[1]):
			break
		if game.can_train(b, kind) == "" and game.train(b, kind) == "":
			q += 1
			if q == n:
				note("%d %s queued (step %d)" % [n, String(Defs.UNITS[kind]["name"]), i + 1])
	_queued[i] = q
	if q >= n:
		return {"st": "done"}
	if makers == 0:
		return _wait_req()
	if _free_t() < float(p[1]):
		return _wait_t(int(p[0]), float(p[1]))
	if _free() < int(p[0]):
		return {"st": "money", "cost": int(p[0]), "t": float(p[1])}
	return _wait_req()          # (every maker busy)


## A laid building lost before it stood (its site cancelled or destroyed): its step is laid again.
func _watch_sites() -> void:
	for i in _placed.keys():
		if _stood.has(i):
			continue
		var b = _placed[i]
		if not is_instance_valid(b) or b.dead:
			_placed.erase(i)
			done[i] = false
			if bte != null:
				bte.lost(i)         # (clockwork-eco: a press lost to the enemy waits before it is laid again)
			note("its %s was lost before it stood: laid again (step %d)" % [String(steps[i]), i + 1])
		elif b.built:
			_stood[i] = true


## Supply-blocked with no Regulator going up: one now, ahead of the build (a player would).
func _supply_guard() -> void:
	var cap: int = game.players[team]["cap"]
	if cap >= game.max_supply(team) or game.supply_used(team) < cap - 2 or _busy_building(_sup()):
		return
	var cost := int(Defs.BUILDINGS[_sup()]["cost"])
	if _gold() < cost:
		_hold += cost
		return
	var c := _spot(_sup())
	if c.x >= 0 and _lay(_sup(), c, false) != null:
		note("supply blocked at %d/%d: a Regulator first" % [game.supply_used(team), cap])


## Winders for the build: one at a time in each Clocktower's queue, from the cogs left over after the steps' price.
func _train_workers() -> void:
	var w := String(_f()["worker"])
	var have := game.workers(team).size()
	for h in _halls():
		have += (h.queue as Array).count(w)
	if OS.get_cmdline_user_args().has("cwdebug") and int(game.clock) % 15 == 0:
		print("DBG %d have %d goal %d gold %d hold %d free %d queues %s cap %d used %d" % [int(game.clock), have, worker_goal, _gold(), _hold, _free(), str(_halls().map(func(h): return h.queue)), int(game.players[team]["cap"]), game.supply_used(team)])
	for h in _halls():
		if have >= worker_goal or _free() < int(Defs.UNITS[w]["cost"]):
			return
		if not h.built or not (h.queue as Array).is_empty():
			continue
		if game.train(h, w) == "":
			have += 1


## "crew mainspring N": each fresh Mainspring keeps N Winders (taken from the presses, the nearest first).
func _crew_springs() -> void:
	if spring_crew <= 0:
		return
	for sp in _mine("mainspring"):
		if not sp.built or sp.fatigued():
			continue
		var want := mini(spring_crew, sp.crew_max())
		var short: int = want - sp.crew.size()
		if short <= 0:
			continue
		var labs: Array = game.workers(team).filter(func(u: Unit) -> bool: return u.order != "build" and u.crate_site == null \
			and u.home_mine != sp and u.carrying == 0 and not _held_worker(u) and not _escort.has(u) and not (scout != null and scout.is_scout(u)))
		labs.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(sp.center()) < b.position.distance_to(sp.center()))
		for u in labs.slice(0, short):
			u.cmd_gather(sp)


# ------------------------------------------------------------------ cw-builds-b: the push plans (docs/clockwork_builds_b.md)
## PENDULUMS (against the Brood) and the HEAVY WORKS PUSH: their opening builds are in scripts/ai_cw_builds_b.gd (PLANS_B);
## after the opening the PUSH (scripts/ai_cw_push.gd) takes the army out as one slow block once the plan's machines are
## there, and the plan's KEEP rule keeps its Heavy Works making the machines it is built round.

const CwPush := preload("res://scripts/ai_cw_push.gd")
var push = null
var _b_spring: Array = []           # [cell, users]: the Mainspring spot _spring_spot found with room for both


func _b_ready() -> void:
	if PLANS_B.has(strategy) and not plan.has("raid"):
		raid = null             # (the push plans run no Springer raid; the Owl raids use the raid's map helpers: merge 0.29.8)
	if plan.has("push"):
		push = CwPush.new(self, plan["push"])


## Its waves are the push's: the shared computer sends none (it still defends at home).
func _push_anyway(ready: Array) -> bool:
	return false if push != null else super._push_anyway(ready)


## The escort Winders (and the Great Winder, the Ballistas' crew) go with the push while it is out.
func _follow_with_escort(army: Array) -> void:
	if push != null and push.phase != "" and push.phase != "back" and not push.units.is_empty():
		super._follow_with_escort(push.units.filter(func(u: Unit) -> bool: return u.kind != Defs.GREAT_WINDER_KIND))
		return
	super._follow_with_escort(army)


## The Heavy Works' spot: the one kept for it by the Mainspring, else by any Mainspring's network (AI._heavy_spot).
func _b_heavy_spot() -> Vector2i:
	var keep := _kept(Defs.CW_HEAVY)
	if not keep.is_empty():
		var kc: Vector2i = keep["cell"]
		if game.placement_problem(team, Defs.CW_HEAVY, kc, true) == "":
			var st: Dictionary = game.gear_net.candidate(team, Defs.CW_HEAVY, kc)
			if st["state"] == "ok" and st.get("spring") != null:
				return kc
	var c := _heavy_spot()
	if c.x < 0:
		c = _heavy_spot_fed()
	return c


## After the opening, the plan's own mix first, then the shared computer trains the rest (Springers, Netters, the air):
##  - the HEAVY WORKS keeps n of each kind ("keep": [[kind, n], ...], in order; against the Brood "keep_brood" when the plan
##    has one): the first one short is trained when its cogs and Tension are there, and its cogs are kept from the Clock
##    Soldiers while its Tension is due within TENSION_SOON s;
##  - the LIGHT WORKS keeps the FRONT: Clock Soldiers up to "front" (+ FRONT_STEP for each push gone out).
## (The shared computer's own rules made Springers and a Ballista, few Clock Soldiers: the push waited till 11:00, and against
## the Crown the Ballistas stood at home with no one in front of them.)
const FRONT_STEP := 2


func _b_keep() -> void:
	if not plan.has("keep"):
		return
	var keep: Array = plan["keep"]
	if _foe() >= 0 and game.faction_of(_foe()) == "brood" and plan.has("keep_brood"):
		keep = plan["keep_brood"]
	var army := game.army(team)
	var queued := func(k: String) -> int:
		var n := army.filter(func(u: Unit) -> bool: return u.kind == k).size()
		for w in _mine(Defs.CW_HEAVY) + _mine(_works()):
			n += (w.queue as Array).count(k)
		return n
	var hold := 0
	for hw in _mine(Defs.CW_HEAVY):
		if not hw.built or not (hw.queue as Array).is_empty() or game.gear_net.spring_for(hw) == null:
			continue
		for e in keep:
			var k := String(e[0])
			var n := int(e[1])
			if k == Defs.PENDULUM and _sw():
				n = maxi(n, swm().pend_want() if swm().on() else 0)
			if queued.call(k) >= n:
				continue
			var why := game.can_train(hw, k)
			if why == "":
				game.train(hw, k)
			elif _maker_ok(why):
				var p := game.unit_price(team, k)
				var short := float(p[1]) - game.tension(team)
				var rate := game.tension_rate(team)
				if short <= 0.0 or (rate > 0.05 and short / rate < TENSION_SOON):
					hold = maxi(hold, int(p[0]))
			break           # (the first one short waits for its cogs and Tension: not the next)
	var want: int = int(plan.get("front", 0)) + (int(push.pushes) * FRONT_STEP if push != null else 0)
	var soldiers: int = queued.call("clock_soldier")
	# (the push's own front first, whatever the heavy machine waits for: then the rest, after its cogs)
	var first: int = int((plan.get("push", {}) as Dictionary).get("need", {}).get("front", 0))
	for w in _mine(_works()):
		if soldiers >= want or _gold() - (hold if soldiers >= first else 0) < int(Defs.UNITS["clock_soldier"]["cost"]):
			break
		if w.built and (w.queue as Array).size() < 2 and game.can_train(w, "clock_soldier") == "" and game.train(w, "clock_soldier") == "":
			soldiers += 1
	if hold > 0:
		_reserve = maxi(_reserve, hold)        # (the shared computer's training keeps it too)


## A machine at home run down (or nearly) off the gear ground with no enemy beside it: the nearest free Winder walks out and
## winds it (REPAIR winds first). (Pendulums that chased Raptors past the gear field froze there for good: the shared
## escort winds only while no threat holds the army at home, and the Brood kept one there for minutes. Greenhold 11, 8:30.)
const REWIND_AT := 0.25
const REWIND_MAX := 3
var _rewinders := {}            # Winder -> the machine he winds
var _rewind_t := {}             # machine -> when a Winder was last sent to it


func _b_rewind() -> void:
	for w in _rewinders.keys():
		var m = _rewinders[w]
		if not is_instance_valid(w) or w.dead or not is_instance_valid(m) or m.dead or w.order != "repair" or (m.wind >= 0.95 and not m.powered_down()):
			if is_instance_valid(w) and not w.dead and w.order == "repair":
				w.cmd_stop()
			_rewinders.erase(w)
	if _rewinders.size() >= REWIND_MAX:
		return
	var busy := _rewinders.values()
	for u in game.army(team):
		if _rewinders.size() >= REWIND_MAX:
			return
		if u.is_air() or u.runs_on_spring() or String(u.d["faction"]) != "clockwork" or busy.has(u) or (push != null and push.has(u)):
			continue
		if not (u.powered_down() or (u.wind < REWIND_AT and not u._in_field)) or _home_dist(u.position) > 1600.0 or _enemy_near(u.position, 300.0):
			continue
		if game.clock - float(_rewind_t.get(u, -99.0)) < 12.0:
			continue          # (one sent lately: he is on his way, or was pulled off by the worker rules)
		_rewind_t[u] = game.clock
		var best: Unit = null
		var bd := INF
		for w in game.workers(team):
			if _rewinders.has(w) or w.order == "build" or w.crate_site != null or _escort.has(w) or _held_worker(w) or (scout != null and scout.is_scout(w)):
				continue
			var dd: float = w.position.distance_to(u.position)
			if dd < bd:
				bd = dd
				best = w
		if best != null and best.can_repair(u):
			best.cmd_repair(u)
			_rewinders[best] = u
			busy.append(u)
			if game.clock - float(_rewind_t.get("said", -99.0)) > 20.0:
				_rewind_t["said"] = game.clock
				note("a Winder walks out to wind a run-down %s" % String(u.d["name"]))


## RANDOM PLAN (cw-builds-b): against the Brood the Pendulums half the time (its staple is the Raptor swarm, which the
## Pendulums' blades answer: the owner's playtests), else evenly among the rest.
const PENDULUM_VS_BROOD := 0.5


func random_plan(allowed: Array) -> String:
	var brood := false
	for t in game.enemies_of(team):
		if game.faction_of(t) == "brood":
			brood = true
	if brood and allowed.has("pendulum") and randf() < PENDULUM_VS_BROOD:
		return "pendulum"
	return super.random_plan(allowed)


# ------------------------------------------------------------------ clockwork-eco: the Clockwork's own hall spot
## THE CLOCKWORK'S HALL SPOT (the owner, 2026-11-04 20:24: "Clocktowers need room around them"; ClockSites,
## docs/clockwork_eco.md): its next Clocktower where its gear ring and the ring of buildings it powers fit on open ground of
## its own level, near its halls, on our side by land; not where its builders were chased off or a hall was lost lately
## (_hall_bad), not where the computer may not build, not by enemy soldiers in sight. Nothing found: the shared pick.
## `-- clocksites:off` plays the shared pick (comparisons).
var sites_on := not OS.get_cmdline_user_args().has("clocksites:off")
var _ck_steps: Array = []
var _ck_t := -99.0
var _ck_key := ""
var _ck_pick := Vector2i(-1, -1)
var site_picks := 0             # (tests, the coach) halls placed by the Clockwork's rule
const CK_CACHE := 4.0           # (s) a pick is kept this long while the halls are the same


func _safe_hall_spot() -> Vector2i:
	if not sites_on or not Defs.gear_mode or difficulty < 1:
		return super()
	var mids: Array = []
	var key := ""
	for h in _halls():
		mids.append(h.center() / float(Defs.TILE))
		key += str(h.cell)
	if mids.is_empty():
		return super()
	key += "/%d/%d" % [_hall_bad.size(), _lost_spots.size()]      # (a spot lost lately: worked out again at once)
	var hall: String = _f()["hall"]
	if key == _ck_key and game.clock - _ck_t < CK_CACHE and _ck_pick.x >= 0 and game.placement_problem(team, hall, _ck_pick, true) == "" \
			and float(_hall_bad.get(_ck_pick, -1.0)) <= game.clock:
		return _ck_pick
	if _ck_steps.is_empty():
		var foes: Array = []
		for o in game.enemies_of(team):
			if game.starts.size() > o:
				foes.append(ExpansionSpots._steps(game, game.starts[o]))
		_ck_steps = [ExpansionSpots._steps(game, game.starts[team]), foes]
	var avoid := {}
	for c in _hall_bad:
		if float(_hall_bad[c]) > game.clock:
			avoid[c] = true
	var foe_pts: Array = _foe_ground()
	var check := func(c: Vector2i) -> bool:
		if game.placement_problem(team, hall, c, true) != "":
			return false
		if r6_sites and _enemy_side(c):
			return false
		var cm := Vector2(c) + Vector2(MapGen.HALL) * 0.5
		for fp in foe_pts:
			if cm.distance_to(fp) < LOST_NEAR:
				return false            # (by an enemy hall, or where we lost one lately)
		var cc := cm * float(Defs.TILE)
		for u in game.units_near(cc, 14.0 * Defs.TILE):
			if game.hostile(u.team, team) and not u.dead and not u.is_worker() and u.has_attack() and game.is_visible_to(team, u.position):
				return false
		return true
	var picks: Array = ClockSites.pick(game, team, mids, 1, _ck_steps, avoid, check, ClockSites.rings_of(game))
	_ck_t = game.clock
	_ck_key = key
	if picks.is_empty():
		_ck_pick = Vector2i(-1, -1)
		return super()
	_ck_pick = picks[0]["c"]
	site_picks += 1
	if game.clock - float(_said_t.get("site", -99.0)) > 30.0:
		_said_t["site"] = game.clock
		note("its next Clocktower's spot: %s, room for %d of its ring's buildings (%d%% open ground beyond), %d steps from its halls" % [
			str(_ck_pick), int(picks[0]["slots"]), int(round(float(picks[0]["outer"]) * 100.0)), int(picks[0]["walk"])])
	return _ck_pick

var _said_t := {}


## Any free ground holds a fresh reserve for a Clocktower (Game.lode_at_spot), not only the map's base sites: the
## Clockwork's own spots are often off them.
func _lode_value(c: Vector2i) -> float:
	if sites_on and Defs.gear_mode and not game.base_sites.has(_site_alias.get(c, c)):
		return game.lode_at_spot(c, _f()["hall"]) * 16.0
	return super(c)
