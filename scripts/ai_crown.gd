class_name AICrown
extends AI
## THE CROWN'S OWN COMPUTER (0.29.0, docs/ai_crown_rebuild.md), like the Brood's (scripts/ai_brood_new.gd). The shared
## computer (scripts/ai.gd) still does the hands, the soldiers and every module that works: the scout and its reads, the
## raids and their micro, the ramp post on HOLD and the rider scouts (ai_crown_hold.gd), the new hall's slow wall
## (ai_expand_wall.gd), the transitions after a held rush (ai_transition.gd), the retreat and the gg. What is new:
##  - a REAL OPENING BUILD ORDER per plan (PLANS[...]["bo"]): an ordered list of steps, each triggered by supply, labourers,
##    army or what stands ("the second Farm at 8 labourers"), never by the clock (the farms pay in lumps and the land runs
##    out: docs/exhaust_economy.md). THE PLAN OWNS THE GOLD in the opening: the next step's price is set aside before
##    anything else may spend (the labourers, the soldiers, the horses only spend what is left), so nothing else needs to
##    hide gold. A Cottage comes first whenever the supply is about to block.
##  - the opening ends when its last step is done (the second hall down, or the first attack out), when a rush is scouted
##    (the shared anti-rush defence takes over: the wall, Musketeers first, then the counter) or at BO_LIMIT;
##  - then MILESTONE RULES per plan (PLANS[...]["mid"]): the Barracks, Breeder, Foundry, Armoury and Church come at so many
##    labourers / halls / army supply, in order, instead of the shared clock rule; the waves and expansions follow the
##    plan's settings (PLANS[...]["s"], read through _s) and the owner's doctrine (AI.doctrine, docs/ai_crown_transitions.md
##    sections 7-11): expand, keep the army on the high ground, saturate then slowly wall, Musketeers on HOLD with a
##    cannon at the ramp, scout with Horsemen, kill workers, counter or expand at once after holding a rush.
## THE MARCHING BAND (an experiment, Defs.marching_band, off by default) is never relied on; its hook in AI._produce keeps
## working when it is on, and a plan may ask for it later with a "build"-style step on "band" (see _st_do).
## `-- crownnew:off` on the command line plays the Crown as the 0.27.2 shared computer, for comparison games.

var on := not OS.get_cmdline_user_args().has("crownnew:off")
var plan := {}                   # this game's plan: PLANS[strategy] + `over` (a coach's tool sets `over`)
var over := {}
var note: Array = []             # [clock, text] of what it decided (tests and tools read it)
var bo_i := 0                    # the next step of the opening
var bo_done := false             # the opening is over: the milestones and the shared rules play on
var bo_why := ""                 # why it ended
var bo_reserve := 0              # gold set aside for the next step (nothing else may spend it)
var bo_army := false             # soldiers are trained in the opening (an "army" step came)
var bo_army_cap := 0             # ... up to this much army supply (0: no cap)
var bo_lab_cap := 99             # labourers in the opening at most
var bo_log: Array = []           # [clock, step text] of every step done (tests and the coach read it)
var _bo_plan: Array = []         # the opening's steps (fixed at the start: a later change of plan does not change them)
var _plan_of := ""
var _waits := {}                 # step index -> clock it first waited for want of room (logged once)
const BO_LIMIT := 600.0          # (game seconds) the opening hands over by then whatever is left
const LAB_COST := 50

## THE PLANS. Steps ("do"):
##   wall_cottage   the ramp Cottage (AI._cottage_wall: the first Cottage at the ramp is part of the wall)
##   wall_gate      the Gate (and any palisade piece) beside it: the ramp is sealed
##   build k [n]    a building of kind k until it has n (economy kinds by its hall: AI._econ_spot)
##   army k [cap]   soldiers are trained from here on (the shared AI._produce picks Musketeers / Horsemen), up to `cap`
##                  army supply in the opening (0: no cap)
##   labs n         the opening trains labourers up to n (from here on)
##   hall n         the next Town Hall (the safest rated site, three builders) until it has n halls
##   attack n       the first wave goes with n army supply; the opening ends when it is out
## Triggers ("at"): sup (supply used), labs (labourers), army (army supply), has (a building of that kind standing).
## A step whose trigger is a moment away (sup / labs within one or two) already has its gold set aside.
## "mid" (after the opening): [kind, how many, {trigger}] in order; one is put up a think.
## "s": the shared plan settings it plays with (AI.STRATEGIES keys: wave, step, expand, halls, tech, workers).
const PLANS := {
	# the Economy plan: the second Farm at once, the Mill and the Barracks, a few Musketeers, then the second hall at
	# 15 labourers (about 2:45); the army waits on the high ground while the halls fill
	"economy": {"opening": "mill", "labs": 99, "mill": [[0, 2], [14, 4], [18, 6]],
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 7}},
			{"do": "wall_gate", "at": {"labs": 7}},
			{"do": "build", "k": "barracks", "at": {"labs": 8}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 8}},
			{"do": "army", "k": "musketeer", "cap": 5},
			{"do": "hall", "n": 2, "at": {"labs": 15}},
		],
		"mid": [["barracks", 1, {}], ["horse_breeder", 1, {"labs": 20}], ["foundry", 1, {"labs": 26, "halls": 2}],
			["barracks", 2, {"labs": 28}], ["armoury", 1, {"labs": 32}], ["church", 1, {"labs": 40, "halls": 2}],
			["barracks", 3, {"labs": 40}], ["foundry", 2, {"labs": 48, "halls": 3}]],
		"s": {"wave": 34, "step": 10}},
	# Balanced: the safe Musketeer opening (the ramp Cottage and its Gate, the Barracks and the Mill at once: three Musketeers
	# by about 2:30 against a rush, tools/test_ai_wall_vs_rush.gd), the second Farm, the Breeder for a rider scout, the second
	# hall at 17 labourers
	"balanced": {"opening": "mill", "labs": 99, "mill": [[0, 3], [13, 5], [16, 6]],
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "wall_gate", "at": {"sup": 5}},
			{"do": "build", "k": "barracks", "at": {"labs": 5}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 5}},
			{"do": "army", "k": "musketeer", "cap": 8},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 8}},
			{"do": "build", "k": "horse_breeder", "at": {"labs": 14}},
			{"do": "hall", "n": 2, "at": {"labs": 17}},
		],
		"mid": [["barracks", 1, {}], ["horse_breeder", 1, {}], ["barracks", 2, {"labs": 22}], ["foundry", 1, {"labs": 24}],
			["armoury", 1, {"labs": 28}], ["church", 1, {"labs": 36, "halls": 2}], ["barracks", 3, {"labs": 34}],
			["foundry", 2, {"labs": 44, "halls": 3}]],
		"s": {"wave": 18, "step": 8}},
	# Timing attack: one hall, two Barracks, the Breeder, the Foundry (a cannon goes with the wave) and the first wave of
	# 22 supply (about 5:30); the second hall goes down behind it (the milestones)
	"timing": {"opening": "mill", "labs": 19, "mill": [[0, 3], [12, 6]],
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "wall_gate", "at": {"sup": 5}},
			{"do": "build", "k": "barracks", "at": {"labs": 5}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 5}},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 8}},
			{"do": "army", "k": "musketeer", "cap": 0},
			{"do": "build", "k": "barracks", "n": 2, "at": {"labs": 13}},
			{"do": "build", "k": "horse_breeder", "at": {"labs": 15}},
			{"do": "build", "k": "foundry", "at": {"labs": 17}},
			{"do": "attack", "n": 22, "at": {"army": 22}},
		],
		"mid": [["barracks", 2, {}], ["horse_breeder", 1, {}], ["foundry", 1, {}], ["armoury", 1, {"labs": 20}],
			["church", 1, {"labs": 30, "halls": 2}], ["barracks", 3, {"labs": 28}], ["foundry", 2, {"labs": 40, "halls": 3}]],
		"s": {"wave": 22, "step": 8, "timing": 0.0, "expand": 0.6}},
	# Rush: the Horse Breeder opening. The ramp Cottage, the Barracks at 7, the Breeder at 8, the second Farm, Horsemen
	# nonstop; the labourers stay at 12 until the first 3 Horsemen are out (about 3:00), then the milestones
	"rush": {"opening": "breeder", "labs": 12, "mill": [[0, 2]],
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "build", "k": "barracks", "at": {"labs": 7}},
			{"do": "build", "k": "horse_breeder", "at": {"labs": 8}},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 9}},
			{"do": "army", "k": "cuirassier", "cap": 0},
			{"do": "wall_gate", "at": {"labs": 10}},
			{"do": "attack", "n": 9, "at": {"army": 9}},
		],
		"mid": [["barracks", 1, {}], ["horse_breeder", 1, {}], ["powder_mill", 1, {}], ["barracks", 2, {"labs": 16}],
			["foundry", 1, {"labs": 22}], ["armoury", 1, {"labs": 24}], ["church", 1, {"labs": 34, "halls": 2}],
			["barracks", 3, {"labs": 30}]],
		"s": {"wave": 9, "step": 6}},
}


func _init() -> void:
	_make_plan()


func _ready() -> void:
	super._ready()
	if not on:
		return
	_make_plan()
	opening = String(plan.get("opening", "mill"))
	for a in OS.get_cmdline_user_args():
		if a == "open%d:breeder" % team or a == "open%d:mill" % team:
			opening = a.split(":")[1]          # (study switch, as in AI._ready)
	_bo_plan = (plan["bo"] as Array).duplicate(true) if difficulty >= 1 else []
	bo_lab_cap = int(plan.get("labs", 99))
	if _bo_plan.is_empty():
		bo_done = true                         # (Easy: no build order, the shared rules from the start)
	_attack_at = int(_s("wave"))
	if opening == "breeder" and strategy == "rush":
		_attack_at = maxi(_attack_at, RUSH_HORSEMEN * int(Defs.UNITS["cuirassier"]["supply"]))
	if game.mlog:
		game.mlog.add("%s opens (its plan) with a %s" % [game.mlog.who(team), "Horse Breeder (Horseman rush)" if opening == "breeder" else "Powder Mill (Musketeers)"])
		game.mlog.add("%s's plan: %s, a build order of %d steps (scripts/ai_crown.gd)" % [game.mlog.who(team), STRATEGIES.get(strategy, STRATEGIES["balanced"])["name"], _bo_plan.size()])


func _make_plan() -> void:
	_plan_of = strategy
	plan = (PLANS.get(strategy, PLANS["balanced"]) as Dictionary).duplicate(true)
	for k in over:
		plan[k] = over[k]


func say(s: String) -> void:
	note.append([game.clock, s])
	if game.mlog:
		game.mlog.add("%s's plan: %s" % [game.mlog.who(team), s])


## The plan's settings first (a scout's report still changes them: AIScout.mod), then the shared ones.
func _s(key: String) -> Variant:
	if not on:
		return super(key)
	if scout != null and scout.mod.has(key):
		return scout.mod[key]
	if strategy != _plan_of and PLANS.has(strategy):
		_make_plan()
	var ps: Dictionary = plan.get("s", {})
	if ps.has(key):
		return ps[key]
	return super(key)


## THE RAMP POST GOES DOWN ONLY WITH AN EDGE (AICrownHold._beat): a value count of Musketeers against Raptors flatters the
## muskets in the open (coached game a01, Red Coast 7:20: twelve Musketeers sent down to the expansion one by one were eaten
## by twenty Raptors; behind the gate the same line killed 2,200). Against the Brood it goes down at HOLD_BEAT_BROOD.
const HOLD_BEAT_BROOD := 2.0


func hold_beat() -> float:
	if on and _foe_is("brood"):
		return float(plan.get("beat_brood", HOLD_BEAT_BROOD))
	return 1.3


func bo_owns() -> bool:
	return on and not bo_done


func _base_trains_labs() -> bool:
	return not bo_owns()


func _plan_tech() -> bool:
	return on and bo_done and difficulty >= 1


# ------------------------------------------------------------------ the think

func _think_stage(i: int) -> void:
	if not bo_owns():
		super(i)
		return
	var pt := Time.get_ticks_usec()
	# THE PLAN OWNS THE GOLD: the next step's price is out of reach of everything else this stage
	var held: int = clampi(bo_reserve, 0, int(game.players[team]["gold"]))
	game.players[team]["gold"] -= held
	match i:
		0:
			xw.tick()
			_workers()          # (the shared hands: posts, safety, the Mill's share; it trains none in the opening)
			game.players[team]["gold"] += held
			held = 0
			_bo_labs()
			_lap("ai/workers", pt)
		1:
			_keep_tech()
			game.players[team]["gold"] += held
			held = 0
			_bo_tick()
			_tend_wall()        # (the ramp wall's crew kept at it, as the shared _build_up does)
			_lap("ai/build", pt)
		2:
			if bo_army and (bo_army_cap <= 0 or _army_supply(game.army(team)) < bo_army_cap):
				_research_off = true
				_produce()
				_research_off = false
			pt = _lap("ai/produce", pt)
			ch.tick()
			if difficulty >= 1 and not peaceful:
				_raid()
			_lap("ai/raid", pt)
		3:
			scout.tick()
			tr.tick()
			_army()
			_lap("ai/army", pt)
		4:
			_tend_wagon()
			_horses()
			_loose_horses()
			if difficulty >= 1:
				_abilities()
			if difficulty >= 2:
				_micro()
			_gg_tick()
			_lap("ai/micro", pt)
	game.players[team]["gold"] += held


var _research_off := false


## Labourers in the opening: every hall keeps one coming while the gold left after the plan's reserve pays for it.
func _bo_labs() -> void:
	var labs := game.workers(team).size()
	var queued := 0
	for h in _halls():
		queued += h.queue.count(_f()["worker"])
	var free := _gold() - bo_reserve
	for h in _halls():
		if not h.built or labs + queued >= bo_lab_cap or free < LAB_COST:
			continue
		if h.queue.size() >= (2 if free >= 3 * LAB_COST else 1):
			continue
		if game.train(h, _f()["worker"]) == "":
			queued += 1
			free -= LAB_COST


## The opening: the supply first, then the next step; its gold is set aside until it can be paid.
func _bo_tick() -> void:
	if scout != null and scout.verdict == "rush" and opening != "breeder":
		_bo_end("a rush was scouted: the shared defence (the wall, Musketeers first, then the counter)")
		return
	if _attacking:
		_bo_end("the first attack is out")
		return
	if game.clock >= BO_LIMIT:
		_bo_end("time: %d steps of %d done" % [bo_i, _bo_plan.size()])
		return
	if _halls().filter(func(h: Building) -> bool: return h.built).is_empty():
		return
	bo_reserve = 0
	if _supply_due():
		var c := int(Defs.BUILDINGS["cottage"]["cost"])
		if _gold() >= c:
			_construct("cottage")
			if _mine("cottage").any(func(b: Building) -> bool: return not b.built):
				_bo_log("a Cottage (supply %d/%d)" % [game.supply_used(team), int(game.players[team]["cap"])])
				return
		bo_reserve = c
		return
	while bo_i < _bo_plan.size():
		var st: Dictionary = _bo_plan[bo_i]
		if _st_done(st):
			_bo_next(st)
			continue
		if String(st["do"]) == "army":
			bo_army = true
			bo_army_cap = int(st.get("cap", 0))
			_bo_next(st)
			continue
		if String(st["do"]) == "labs":
			bo_lab_cap = int(st["n"])
			_bo_next(st)
			continue
		if not _st_ready(st):
			if _st_near(st):
				bo_reserve = _st_price(st)
			return
		var r := _st_do(st)
		if r == "":
			if _st_done(st):
				_bo_next(st)
				continue
			return
		if r == "gold":
			bo_reserve = _st_price(st)
		elif r == "room" and not _waits.has(bo_i):
			_waits[bo_i] = game.clock
			say("no room for step %d (%s) yet" % [bo_i + 1, _st_text(st)])
		if r == "room" and game.clock - float(_waits.get(bo_i, game.clock)) > 60.0:
			say("step %d (%s) skipped: no room" % [bo_i + 1, _st_text(st)])
			bo_i += 1
			continue
		return
	_bo_end("the build order is done")


func _bo_next(st: Dictionary) -> void:
	_bo_log(_st_text(st))
	bo_i += 1


func _bo_log(text: String) -> void:
	bo_log.append([game.clock, text])
	if game.mlog:
		game.mlog.add("%s's build order: %s (supply %d, %d labourers, %d gold)" % [game.mlog.who(team), text, game.supply_used(team), game.workers(team).size(), _gold()])


func _bo_end(why: String) -> void:
	if bo_done:
		return
	bo_done = true
	bo_why = why
	bo_reserve = 0
	say("the opening is over (%s): the milestones take over" % why)


## A Cottage is due: the supply is about to block (two left, more with Barracks training), none going up.
func _supply_due() -> bool:
	var cap: int = game.players[team]["cap"]
	if cap >= game.max_supply(team) or _mine("cottage").is_empty():
		return false            # (the first Cottage is the ramp's: a step of its own)
	if _busy_building("cottage"):
		return false
	var prod := _mine("barracks").filter(func(b: Building) -> bool: return b.built).size()
	var margin := 2 + 2 * prod + (2 if opening == "breeder" and prod > 0 else 0)
	return cap - game.supply_used(team) <= margin


# ------------------------------------------------------------------ the steps

func _st_text(st: Dictionary) -> String:
	match String(st["do"]):
		"wall_cottage": return "the ramp Cottage"
		"wall_gate": return "the ramp Gate"
		"build": return "%s %d" % [String(Defs.BUILDINGS[st["k"]]["name"]), int(st.get("n", 1))]
		"army": return "%s from now on%s" % [String(Defs.UNITS[st["k"]]["name"]) + "s" if Defs.UNITS.has(st["k"]) else "soldiers", (" (up to %d supply)" % int(st["cap"])) if int(st.get("cap", 0)) > 0 else ""]
		"labs": return "labourers up to %d" % int(st["n"])
		"hall": return "Town Hall %d" % int(st.get("n", 2))
		"attack": return "the first attack (%d supply)" % int(st["n"])
	return String(st["do"])


func _st_done(st: Dictionary) -> bool:
	match String(st["do"]):
		"wall_cottage":
			return _walled or not _cw_active() or (not _cw_plan.is_empty() and _cw_cottage() != null)
		"wall_gate":
			return _walled
		"build":
			var k := String(st["k"])
			if Defs.is_econ(k) and game.econ_count(team, k) >= game.econ_limit(team, k):
				return true
			return _mine(k).size() >= int(st.get("n", 1))
		"hall":
			return _halls().size() >= int(st.get("n", 2))
		"attack":
			return _attacking
		"army", "labs":
			return false
	return true


func _st_ready(st: Dictionary) -> bool:
	var at: Dictionary = st.get("at", {})
	if at.has("sup") and game.supply_used(team) < int(at["sup"]):
		return false
	if at.has("labs") and game.workers(team).size() < int(at["labs"]):
		return false
	if at.has("army") and _army_supply(game.army(team)) < int(at["army"]):
		return false
	if at.has("has") and _mine(String(at["has"])).filter(func(b: Building) -> bool: return b.built).is_empty():
		return false
	return true


## The trigger is a moment away: its gold is set aside already (the hall trains a labourer every 12 s).
func _st_near(st: Dictionary) -> bool:
	var at: Dictionary = st.get("at", {})
	if at.has("army") or at.has("has"):
		return false
	if at.has("sup") and game.supply_used(team) < int(at["sup"]) - 1:
		return false
	if at.has("labs") and game.workers(team).size() < int(at["labs"]) - 1:
		return false
	return true


func _st_price(st: Dictionary) -> int:
	match String(st["do"]):
		"wall_cottage": return int(Defs.BUILDINGS["cottage"]["cost"])
		"wall_gate": return maxi(_wall_cost, 50)
		"build": return int(Defs.BUILDINGS[st["k"]]["cost"])
		"hall": return int(Defs.BUILDINGS[_f()["hall"]]["cost"])
	return 0


## Do the step: "" done (or nothing to pay), "gold" short of its price, "room" no spot for it now, "wait" not yet.
func _st_do(st: Dictionary) -> String:
	match String(st["do"]):
		"wall_cottage", "wall_gate":
			if _cw_active():
				_cottage_wall()
			elif not _walled:
				_wall_off()
			if _st_done(st):
				return ""
			return "gold" if _gold() < _st_price(st) else "wait"
		"build":
			var k := String(st["k"])
			var cost := int(Defs.BUILDINGS[k]["cost"])
			if not game.requirement_met(team, k):
				return "wait"
			if _gold() < cost:
				return "gold"
			var spot := _econ_spot(k) if Defs.is_econ(k) else _find_spot(k)
			if spot.x < 0:
				return "room"
			var n0 := _mine(k).size()
			_construct(k, spot)
			return "" if _mine(k).size() > n0 else "wait"
		"hall":
			return _bo_hall()
		"attack":
			_attack_at = int(st["n"])
			bo_army = true
			bo_army_cap = 0
			return "wait"
	return ""


## The second hall of the opening: the safest rated site (AI._safe_hall_spot), three labourers build it together.
func _bo_hall() -> String:
	var hall: String = _f()["hall"]
	var cost := int(Defs.BUILDINGS[hall]["cost"])
	if _gold() < cost:
		return "gold"
	var spot := _safe_hall_spot()
	if spot.x < 0:
		return "room"
	var site := (Vector2(spot) + Vector2(Defs.BUILDINGS[hall]["size"]) * 0.5) * Defs.TILE
	if _unsafe(site):
		return "wait"           # (a fight there: its builders would run)
	var labs := game.workers(team).filter(func(u: Unit) -> bool: return u.order != "build" and not u.dead and not (scout != null and scout.is_scout(u)))
	labs.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(site) < b.position.distance_squared_to(site))
	var builders: Array = labs.slice(0, 3)
	if builders.is_empty():
		return "wait"
	var nb: Building = game.place_building(team, hall, spot, builders)
	if nb == null:
		return "room"
	_new_hall = nb
	_guards.clear()
	if game.mlog:
		game.mlog.add("%s is expanding to fresh land (its build order), %d tiles from its main" % [game.mlog.who(team),
			int(nb.center().distance_to(Vector2(game.starts[team]) * Defs.TILE) / Defs.TILE)])
	return ""


## THE MILL'S CREW (the whole army's powder: a Musketeer costs 10, a hand on the Mill grinds ~20 a minute, Defs.MILL_RATE):
## the plan says how many hands each Mill gets at so many labourers ("mill": [[labourers, hands a Mill], ...]); the shared
## rule kept 1-3 on it until 5:00, so the Musketeers waited for powder (about 20 a minute: 2 Musketeers) while gold piled up.
## After the opening every Mill gets its full crew (powder piling up with no gold sends two back to the farms, as before).
func _mill_cap() -> int:
	if not on or difficulty < 1 or (bo_done and scout != null and scout.verdict == "rush" and game.clock < 300.0):
		return super()
	if _mine("barracks").is_empty() and not bo_done:
		return 0
	var mills := _mine("powder_mill").filter(func(m: Building) -> bool: return m.built).size()
	if bo_done:
		if _res2() > 300.0 and _gold() < 150:
			return super()
		return 6 * mills          # (a full crew on every Mill: the shared 99 sent nobody over, _balance_mill)
	var labs := game.workers(team).size()
	var per := 0
	for e in plan.get("mill", [[0, 3]]):
		if labs >= int(e[0]):
			per = int(e[1])
	return per * maxi(1, mills)


func _research() -> void:
	if _research_off:
		return
	super()


# ------------------------------------------------------------------ after the opening: the milestones

func _build_up() -> void:
	super()
	if not _plan_tech() or _hall_reserve or (_cw_active() and not _walled):
		return
	_mid_tick()


func _mid_tick() -> void:
	var labs := game.workers(team).size()
	var halls := _halls().filter(func(h: Building) -> bool: return h.built).size()
	var army := _army_supply(game.army(team))
	for m in plan.get("mid", []):
		var k := String(m[0])
		if _mine(k).size() >= int(m[1]):
			continue
		var at: Dictionary = m[2]
		if labs < int(at.get("labs", 0)) or halls < int(at.get("halls", 0)) or army < int(at.get("army", 0)):
			continue
		if not game.requirement_met(team, k) or _busy_building(k):
			continue
		var cost := int(Defs.BUILDINGS[k]["cost"])
		if _gold() < cost:
			_reserve = maxi(_reserve, cost)     # (the milestone's gold: the soldiers wait for it once the army has its minimum)
			return
		var n0 := _mine(k).size()
		_construct(k)
		if _mine(k).size() > n0:
			say("milestone: %s %d (%d labourers, %d halls, army %d supply)" % [String(Defs.BUILDINGS[k]["name"]), int(m[1]), labs, halls, army])
		return
