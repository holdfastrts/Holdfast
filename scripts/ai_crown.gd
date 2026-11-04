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
var bo_army_first := false       # ... and they come before labourers (the Rush: a hall trains one only when every Barracks is busy)
var bo_log: Array = []           # [clock, step text] of every step done (tests and the coach read it)
var _bo_plan: Array = []         # the opening's steps (fixed at the start: a later change of plan does not change them)
var _plan_of := ""
var _waits := {}                 # step index -> clock it first waited for want of room (logged once)
var siege: AICrownSiege = null   # the siege plan's push (scripts/ai_crown_siege.gd); null on the other plans
const BO_LIMIT := 600.0          # (game seconds) the opening hands over by then whatever is left
## THE BALLOON HARASS (scripts/ai_crown_balloon.gd): made on the Balloon harass plan only (Normal and up)
const AICrownBalloon := preload("res://scripts/ai_crown_balloon.gd")
var bl = null
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
## THE FOUNDRY BEFORE THE SECOND BARRACKS, in every plan and matchup (the owner, DECIDED 2026-11-03 22:33: "even in the
## Horseman rush, the rush is done with 1 Barracks; I don't think there is any case you build the second Barracks before
## the Foundry"): the cannon's canister also hits flyers and its round shot has the longest range in the game. The plans
## below are written so, and _construct holds it for every other caller (the shared rules, the scout's plan, the bank).
const PLANS := {
	# the Economy plan: the second Farm at 7 labourers, the Gate, the Barracks and the Mill at 8, six Musketeers, then the
	# second hall at 15 labourers (about 3:10); the Foundry, then the second Barracks; the army waits on the high ground
	"economy": {"opening": "mill", "labs": 99, "army": 0.4, "mill": [[0, 2], [14, 4], [18, 6]],
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 7}},
			{"do": "wall_gate", "at": {"labs": 7}},
			{"do": "build", "k": "barracks", "at": {"labs": 8}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 8}},
			{"do": "army", "k": "musketeer", "cap": 6},
			{"do": "hall", "n": 2, "at": {"labs": 15}},
		],
		"mid": [["barracks", 1, {}], ["foundry", 1, {"labs": 20, "halls": 2}], ["horse_breeder", 1, {"labs": 20}],
			["barracks", 2, {"labs": 22, "halls": 2}], ["armoury", 1, {"labs": 30}], ["barracks", 3, {"labs": 34}],
			["church", 1, {"labs": 40, "halls": 2}], ["foundry", 2, {"labs": 48, "halls": 3}]],
		"s": {"wave": 34, "step": 10}},
	# Balanced: the safe Musketeer opening (the ramp Cottage and its Gate, the Barracks and the Mill at once: three Musketeers
	# by about 2:30 against a rush, tools/test_ai_wall_vs_rush.gd), the second Farm, the Breeder for a rider scout, the second
	# hall at 15 labourers
	"balanced": {"opening": "mill", "labs": 99, "army": 0.55, "mill": [[0, 3], [13, 5], [16, 6]],
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "wall_gate", "at": {"sup": 5}},
			{"do": "build", "k": "barracks", "at": {"labs": 7}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 7}},
			{"do": "army", "k": "musketeer", "cap": 8},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 9}},
			{"do": "build", "k": "horse_breeder", "at": {"labs": 13}},
			{"do": "hall", "n": 2, "at": {"labs": 15}},
		],
		"mid": [["barracks", 1, {}], ["horse_breeder", 1, {}], ["foundry", 1, {"labs": 18}], ["barracks", 2, {"labs": 18}],
			["armoury", 1, {"labs": 26}], ["barracks", 3, {"labs": 30}], ["church", 1, {"labs": 36, "halls": 2}],
			["foundry", 2, {"labs": 44, "halls": 3}]],
		"s": {"wave": 18, "step": 8}},
	# Timing attack: one hall, the Foundry, the Breeder, the second Barracks (a cannon goes with the wave) and the first wave of
	# 22 supply (about 5:30); the second hall goes down behind it (the milestones)
	"timing": {"opening": "mill", "labs": 19, "army": 0.7, "mill": [[0, 3], [14, 5]],
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "wall_gate", "at": {"sup": 5}},
			{"do": "build", "k": "barracks", "at": {"labs": 7}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 7}},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 9}},
			{"do": "army", "k": "musketeer", "cap": 0},
			{"do": "build", "k": "foundry", "at": {"labs": 13}},
			{"do": "build", "k": "horse_breeder", "at": {"labs": 15}},
			{"do": "build", "k": "barracks", "n": 2, "at": {"labs": 17}},
			{"do": "attack", "n": 22, "at": {"army": 22}},
		],
		"mid": [["foundry", 1, {}], ["horse_breeder", 1, {}], ["barracks", 2, {}], ["armoury", 1, {"labs": 20}],
			["church", 1, {"labs": 30, "halls": 2}], ["barracks", 3, {"labs": 28}], ["foundry", 2, {"labs": 40, "halls": 3}]],
		"s": {"wave": 22, "step": 8, "timing": 0.0, "expand": 0.6}},
	# Rush: the Horse Breeder opening. The ramp Cottage, the Barracks at 7, the Breeder at 8, the second Farm, Horsemen
	# before labourers; the labourers stay at 12 until the first 3 Horsemen are out (about 3:30), then the milestones
	"rush": {"opening": "breeder", "labs": 12, "army": 0.55, "mill": [[0, 2]],
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "build", "k": "barracks", "at": {"labs": 7}},
			{"do": "build", "k": "horse_breeder", "at": {"labs": 8}},
			{"do": "army", "k": "cuirassier", "cap": 0, "first": true},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 9, "army": 3}},
			{"do": "wall_gate", "at": {"labs": 10}},
			{"do": "attack", "n": 9, "at": {"army": 9}},
		],
		"mid": [["barracks", 1, {}], ["horse_breeder", 1, {}], ["powder_mill", 1, {}], ["foundry", 1, {"labs": 16}],
			["barracks", 2, {"labs": 16}], ["armoury", 1, {"labs": 24}], ["church", 1, {"labs": 34, "halls": 2}],
			["barracks", 3, {"labs": 30}]],
		"s": {"wave": 9, "step": 6, "workers": 1.0, "expand": 1.0, "halls": 3}},     # (after the rush, a full economy: the
		# shared Rush settings, 0.75 of the posts and a late hall, held 2 farms' worth of labourers till 6:00, ba3 Red Coast)
	# DRAGOON RAIDS (crown-builds-a, docs/crown_builds_a.md; the raids themselves: scripts/ai_dragoon_raid.gd): the safe
	# Musketeer opening, the Horse Breeder early, the second hall at 15 labourers; then Dragoons (Musketeers on horseback)
	# ride out in groups of four to the enemy's workers while the Musketeer line holds the main's high ground. "raid": the
	# first group once the line has `musk` Musketeers, one more every `per` labourers over `from` (three at most).
	"dragoon": {"opening": "mill", "labs": 99, "army": 0.5, "mill": [[0, 3], [13, 5], [17, 6]],
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "wall_gate", "at": {"sup": 5}},
			{"do": "build", "k": "barracks", "at": {"labs": 7}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 7}},
			{"do": "army", "k": "musketeer", "cap": 8},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 9}},
			{"do": "build", "k": "horse_breeder", "at": {"labs": 13}},
			{"do": "hall", "n": 2, "at": {"labs": 15}},
		],
		# (the owner's rule, 2026-11-03: the Foundry before the second Barracks, always; the job had the Barracks at 18 and the
		# Foundry at 24, unscouted, so it follows Balanced here: both at 18, the Foundry first. Merge 0.29.9)
		"mid": [["barracks", 1, {}], ["horse_breeder", 1, {}], ["foundry", 1, {"labs": 18}], ["barracks", 2, {"labs": 18}],
			["horse_breeder", 2, {"labs": 26, "halls": 2}], ["armoury", 1, {"labs": 28}], ["barracks", 3, {"labs": 32}],
			["church", 1, {"labs": 38, "halls": 2}], ["foundry", 2, {"labs": 46, "halls": 3}]],
		"raid": {"musk": 2, "from": 14, "per": 8},
		"s": {"wave": 30, "step": 10}},
	# SIEGE PUSH (crown-builds-b, docs/crown_builds_b.md, scripts/ai_crown_siege.gd): the Economy plan's opening (the second
	# hall at 15 labourers), then the Breeder (the guns' horses) and the Foundry behind it; then Field Cannons and Mortars behind a
	# Musketeer line go out together to break a turtle (turrets and their menders, rooted creatures). The shared waves never
	# go ("wave" 999): the push does (AICrownSiege).
	"siege": {"opening": "mill", "labs": 99, "army": 0.45, "mill": [[0, 2], [14, 4], [18, 6]], "siege": true,
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 7}},
			{"do": "wall_gate", "at": {"labs": 7}},
			{"do": "build", "k": "barracks", "at": {"labs": 8}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 8}},
			{"do": "army", "k": "musketeer", "cap": 6},
			{"do": "hall", "n": 2, "at": {"labs": 15}},
			{"do": "build", "k": "horse_breeder", "at": {"labs": 17}},
			{"do": "build", "k": "foundry", "at": {"labs": 19}},
		],
		# (against the Brood: the Balanced plan's safe opening, the Gate and eight Musketeers before the second hall: the
		# Economy opening's six lost the main to the Brood's Timing attack at 6:00, coached game a04 Highmoor)
		"bo_brood": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "wall_gate", "at": {"sup": 5}},
			{"do": "build", "k": "barracks", "at": {"labs": 7}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 7}},
			{"do": "army", "k": "musketeer", "cap": 8},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 9}},
			{"do": "build", "k": "horse_breeder", "at": {"labs": 13}},
			{"do": "hall", "n": 2, "at": {"labs": 15}},
			{"do": "build", "k": "foundry", "at": {"labs": 21}},      # (17 left 4 Musketeers at 6:00 on Greenhold, d08)
		],
		"mid": [["barracks", 1, {}], ["horse_breeder", 1, {}], ["foundry", 1, {}], ["barracks", 2, {"labs": 21, "halls": 2}],
			["armoury", 1, {"labs": 28}], ["foundry", 2, {"labs": 30, "halls": 2}], ["barracks", 3, {"labs": 34}],
			["church", 1, {"labs": 40, "halls": 2}]],
		"s": {"wave": 999, "step": 8}},
	# BALLOON HARASS (crown-builds-c, docs/crown_builds_c.md; the harass itself: scripts/ai_crown_balloon.gd): the safe
	# Musketeer opening (Balanced's: the soldiers wait at 8 supply), the Foundry at 13 labourers where Balanced puts its
	# Breeder (round A: at 10 it cost two labourers and a third of the gold at 6:00, and every Brood game) and the first
	# balloon from it, then soldiers again (14 supply), the second hall at 15, the second balloon (tried at 20 labourers
	# in round E: no more labourers, and both Brood games lost without the second basket over the ramp);
	# then the balloons carry Musketeers to the enemy's workers while the army holds at home (Balanced's numbers after it)
	"balloon": {"opening": "mill", "labs": 99, "army": 0.55, "mill": [[0, 3], [13, 5], [16, 6]], "balloons": 2,
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "wall_gate", "at": {"sup": 5}},
			{"do": "build", "k": "barracks", "at": {"labs": 7}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 7}},
			{"do": "army", "k": "musketeer", "cap": 8},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 9}},
			{"do": "build", "k": "foundry", "at": {"labs": 13}},
			{"do": "balloons", "n": 1, "at": {"has": "foundry"}},
			{"do": "army", "k": "musketeer", "cap": 14},
			{"do": "hall", "n": 2, "at": {"labs": 15}},
			{"do": "balloons", "n": 2, "at": {"has": "foundry"}},
		],
		"mid": [["barracks", 1, {}], ["foundry", 1, {}], ["horse_breeder", 1, {"labs": 17}], ["barracks", 2, {"labs": 19}],
			["armoury", 1, {"labs": 26}], ["barracks", 3, {"labs": 30}], ["church", 1, {"labs": 36, "halls": 2}],
			["foundry", 2, {"labs": 44, "halls": 3}]],
		"s": {"wave": 18, "step": 8}},
}


func _init() -> void:
	_make_plan()


func _ready() -> void:
	if not on:
		super._ready()
		return
	# (AI._ready, with the opening from the plan instead of the dice)
	if not strategies_for("crown").has(strategy):
		strategy = "balanced"
	_opened = strategy
	_make_plan()
	opening = String(plan.get("opening", "mill"))
	for a in OS.get_cmdline_user_args():
		if a == "open%d:breeder" % team or a == "open%d:mill" % team:
			opening = a.split(":")[1]          # (study switch, as in AI._ready)
	if game.mlog:
		game.mlog.add("%s opens with a %s" % [game.mlog.who(team), "Horse Breeder (Horseman rush)" if opening == "breeder" else "Powder Mill (Musketeers)"])
	scout = AIScout.new(self)
	var bo_key := "bo_brood" if plan.has("bo_brood") and _foe_is("brood") else "bo"      # (a plan may open otherwise against the Brood)
	_bo_plan = (plan[bo_key] as Array).duplicate(true) if difficulty >= 1 else []
	bo_lab_cap = int(plan.get("labs", 99))
	if _bo_plan.is_empty():
		bo_done = true                         # (Easy: no build order, the shared rules from the start)
	_attack_at = int(_s("wave"))
	if siege_on():
		siege = AICrownSiege.new(self)
	if strategy == "balloon" and difficulty >= 1:
		bl = AICrownBalloon.new(self)
	if opening == "breeder" and strategy == "rush":
		_attack_at = maxi(_attack_at, RUSH_HORSEMEN * int(Defs.UNITS["cuirassier"]["supply"]))
	if game.mlog:
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


## NO COUNTER-ATTACK INTO THE BROOD AFTER A HELD RUSH (AITransition asks; coached games rc_after, rc7_after, Red Coast v the
## Brood's Timing, 0.29.2): the transition weighs our army against the part of the Brood's it saw at our door (475) and,
## with the first Field Cannon adding to ours, sent the whole army out at 6:28-6:31 into 2,400-3,000 of creatures (most of
## them rooted at home, never seen); the line died and the main fell at 9:05-9:31, where the games without the cannon
## never counter-attacked and kept their main. Against the Brood the doctrine holds the high ground and goes down by its
## own timing (AICrownHold.timing, _wave_worth's 1.5 edge over what it knows).
func counter_ok() -> bool:
	return not (on and doctrine() and _foe_is("brood"))


func bo_owns() -> bool:
	return on and not bo_done


func _base_trains_labs() -> bool:
	if bo_owns():
		return false
	return not _army_due()


## (the doctrine's economy-first keeps a labourer's gold from the soldiers; not while the soldiers are due)
func _econ_keep(for_army := false) -> int:
	var k := super(for_army)
	if on and _lab_short and _army_due():
		k = maxi(0, k - int(Defs.UNITS[_f()["worker"]]["cost"]))
	return k


## AN ARMY THE SIZE OF THE ECONOMY (after the opening): while the army's supply is under the plan's share of the labourers
## ("army": economy 0.4, balanced 0.55, timing 0.7; at least ARMY_BROOD against the Brood), a hall trains a labourer only when every Barracks is busy, so the gold
## goes to soldiers first (coached games a01, a12: 30-32 labourers and 420-455 of army at 6:00, the Brood's Timing attack
## at 6:00-6:30 took both halls). Triggered by the economy, not the clock.
const ARMY_BROOD := 0.55
const ARMY_RECKON_T := 360.0     # (s) with no Brood soldier seen yet, the army keeps up with the reckoning from then on
const HOLD_SHARE := 0.6          # (crown-v-brood) the army kept at this share of the Brood army it reckons (AICrown.foe_estimate)
var brood_army_off := OS.get_cmdline_user_args().has("barmy:off")


func _army_due() -> bool:
	if not on or difficulty < 1 or peaceful:
		return false
	var share := float(plan.get("army", 0.5))
	if _foe_is("brood"):
		share = maxf(share, ARMY_BROOD)       # (the Brood's Timing attack comes at 5:45-6:30 with 15-30 creatures: ba3 Red Coast)
	var short: bool = _army_supply(game.army(team)) + (bl.aboard_supply() if bl != null else 0) < int(share * game.workers(team).size())
	if not short and blind_guard() and not brood_army_off:
		# (crown-v-brood: against the Brood the army also keeps up with the Brood army it reckons, HOLD_SHARE of it: behind the
		# walls and on the high ground that line holds; the owner's Redrock game had 300-1,000 against 5,000)
		short = army_behind() and _army_supply(game.army(team)) < int(1.0 * game.workers(team).size())
	if not short:
		return false
	if game.supply_used(team) >= int(game.players[team]["cap"]) - 1:
		return false            # (supply-blocked: the Cottage, not the soldiers)
	return _mine("barracks").any(func(b: Building) -> bool: return b.built and b.queue.is_empty())


func _plan_tech() -> bool:
	return on and bo_done and difficulty >= 1


# ------------------------------------------------------------------ the think

func _think_stage(i: int) -> void:
	if i == 1 and not cannon_first:
		_cannon_check()         # (CANNONS AGAINST THE BROOD, below)
	if not bo_owns():
		if siege != null and i != 2:
			# (the siege plan's next gun: its price is kept from the labourers and the tech, AICrownSiege.gun_due)
			var keep: int = clampi(siege.gun_due(), 0, int(game.players[team]["gold"]))
			game.players[team]["gold"] -= keep
			super(i)
			game.players[team]["gold"] += keep
			return
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
			elif _gun_waiting() and _gun_can():
				_first_gun()        # (the opening's army cap does not hold the first Field Cannon back: rc_after, 6:36)
			pt = _lap("ai/produce", pt)
			ch.tick()
			if difficulty >= 1 and not peaceful:
				_raid()
				if bl != null:
					bl.tick()           # (the balloon harass: scripts/ai_crown_balloon.gd)
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
	if _soldiers_first():
		return
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
	if _defending() and not _def_on:
		_def_on = true
		_bo_defence()
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
			bo_army_first = bool(st.get("first", false))
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


## A RUSH SCOUTED IN THE OPENING (AIScout's verdict "rush", until AITransition calls it held): the plan keeps the gold
## and puts the defence first, the ramp wall, the Barracks and the Mill next if they are not up yet, soldiers from then
## on with no cap, labourers only from gold the Barracks cannot use (_bo_labs) and no new hall until the rush is held.
## (The shared defence it handed over to before cut the labourers to 12 at 4:00 in coached game a05.)
var _def_on := false


func _defending() -> bool:
	return scout != null and scout.verdict == "rush" and opening != "breeder" and not tr.done


func _bo_defence() -> void:
	var first: Array = [{"do": "wall_cottage"}, {"do": "wall_gate"}, {"do": "build", "k": "barracks"}, {"do": "build", "k": "powder_mill"}]
	var ins: Array = []
	for st in first:
		if not _st_done(st):
			ins.append(st)
	for k in ins.size():
		_bo_plan.insert(bo_i + k, ins[k])
	bo_army = true
	bo_army_cap = 0
	say("a rush is scouted: the wall, the Barracks and the Mill first, soldiers before labourers, no new hall till it is held")


## The soldiers come first while a rush is feared: a hall trains a labourer only when every Barracks is busy (gold the
## soldiers cannot use now: no powder, no supply) or the line has DEF_MUSK Musketeers.
const DEF_MUSK := 6


func _soldiers_first() -> bool:
	if bo_army_first and (bo_army_cap <= 0 or _army_supply(game.army(team)) < bo_army_cap):
		return _mine("barracks").any(func(b: Building) -> bool: return b.built and b.queue.is_empty())
	if not _defending():
		return false
	var musk := game.army(team).filter(func(u: Unit) -> bool: return Defs.MUSKETS.has(u.kind)).size()
	if musk >= DEF_MUSK:
		return false
	return _mine("barracks").any(func(b: Building) -> bool: return b.built and b.queue.is_empty())


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
	if String(st["do"]) == "balloons":
		return "balloon %d" % int(st.get("n", 1))
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
	if String(st["do"]) == "balloons":
		return bl == null or bl.balloons().size() + bl.queued() >= int(st.get("n", 1))
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
	if String(st["do"]) == "hall" and _defending():
		return false            # (no new hall while a rush is feared: AITransition says when it is held)
	if String(st["do"]) == "hall" and _hall_waits_gun():
		return false            # (CANNONS AGAINST THE BROOD: the first Field Cannon before the new hall)
	if String(st["do"]) == "hall" and tr.done and tr.choice == "expand":
		return true             # (the rush held: the next hall at once, the doctrine)
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
	if String(st["do"]) == "hall" and _hall_waits_gun():
		return false            # (the gun's gold is not set aside for the hall)
	if at.has("sup") and game.supply_used(team) < int(at["sup"]) - 1:
		return false
	if at.has("labs") and game.workers(team).size() < int(at["labs"]) - 1:
		return false
	return true


func _st_price(st: Dictionary) -> int:
	if String(st["do"]) == "balloons":
		return int(Defs.UNITS["balloon"]["cost"])
	match String(st["do"]):
		"wall_cottage": return int(Defs.BUILDINGS["cottage"]["cost"])
		"wall_gate": return maxi(_wall_cost, 50)
		"build": return int(Defs.BUILDINGS[st["k"]]["cost"])
		"hall": return int(Defs.BUILDINGS[_f()["hall"]]["cost"])
	return 0


## Do the step: "" done (or nothing to pay), "gold" short of its price, "room" no spot for it now, "wait" not yet.
func _st_do(st: Dictionary) -> String:
	if String(st["do"]) == "balloons":
		return _bl_step(st)
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
			if _att_ready_t < 0.0:
				_att_ready_t = game.clock
			elif game.clock - _att_ready_t > ATTACK_WAIT and not _attacking:
				# (the wave was held back: their army is bigger than ours, _wave_worth; the plan expands instead)
				_attack_at = int(_s("wave"))
				_bo_end("the timing was called off: the enemy army it knows is bigger")
			return "wait"
	return ""


const ATTACK_WAIT := 45.0       # (s) an opening's attack held back this long (_wave_worth) is called off
var _att_ready_t := -1.0


## A WAVE GOES ONLY WITH AN EDGE over the enemy army it knows (coached game a03, Kestrel Rise: the Timing plan's 22 supply
## went at 6:59 into a Brood economy with 3,150 of army and died; the shared rule weighed the enemy only for the Clockwork):
## the army ready is worth CR_EDGE_BROOD (the Brood: its creatures rooted at home fight too) or CR_EDGE times the enemy's
## mobile army seen in the last two minutes (AICrownHold.foe_known); nothing known, a big army or the supply cap: it goes.
const CR_EDGE := 1.1
const CR_EDGE_BROOD := 1.5


func _wave_worth(ready: Array) -> bool:
	if siege != null:
		return false              # (the siege plan: its push goes, AICrownSiege._maybe_go)
	if not super(ready):
		return false
	if not on or difficulty < 1 or strategy == "rush" or not doctrine():
		return true
	var mine := 0.0
	for u in ready:
		mine += float(Game.unit_value(u))
	if blind_guard():
		# (crown-v-brood: never out blind, and an army it has not seen is not 0; the cap or a big army is no excuse either)
		if not scouted_fresh():
			want_look("the wave")
			return false
		var est := foe_estimate()
		if mine >= est * CR_EDGE_BROOD:
			return true
		if game.clock - _held_said > 60.0:
			_held_said = game.clock
			say("the wave waits on the high ground: %d of army against the %d it reckons the Brood has (%d seen lately; it wants %.1f times)" % [int(mine), int(est), int(ch.foe_known()), CR_EDGE_BROOD])
		return false
	if _army_supply(ready) >= 60 or game.supply_used(team) >= game.max_supply(team) - 4:
		return true
	var known: float = ch.foe_known()
	if known <= 0.0:
		return true
	var edge := CR_EDGE_BROOD if _foe_is("brood") else CR_EDGE
	if mine >= known * edge:
		return true
	if game.clock - _held_said > 60.0:
		_held_said = game.clock
		say("the wave waits: %d of army against the %d it knows (it wants %.1f times)" % [int(mine), int(known), edge])
	return false


var _held_said := -99.0


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
		game.mlog.add("%s is expanding to fresh land (left at its best hall: %d%%), %d tiles from its main (its build order)" % [game.mlog.who(team),
			int(round(_best_soil() * 100)), int(nb.center().distance_to(Vector2(game.starts[team]) * Defs.TILE) / Defs.TILE)])
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
		return _mill_feedback(mills)
	var labs := game.workers(team).size()
	var per := 0
	for e in plan.get("mill", [[0, 3]]):
		if labs >= int(e[0]):
			per = int(e[1])
	if _defending():
		per = maxi(per, 3)      # (the Musketeers' powder while a rush is feared)
	if per <= 0 or mills == 0:
		return per * maxi(1, mills)
	return mini(per * mills, _mill_feedback(mills))      # (the plan's most; fewer while the powder piles up)


## After the opening the Mill's crew follows the powder bank (coached game a01: with six hands on each Mill 300 powder lay
## unspent while the gold, 0-45 at every minute, held the Musketeers back; the shared rule's 1-3 hands before 5:00 starved
## them the other way): a bank over twice POWDER_WANT sends a hand back to the farms, one under it brings one over (the
## shared _balance_mill moves them, two at a time). POWDER_WANT: 30, and 15 more for each Barracks or Foundry.
const POWDER_WANT := 30.0
const MILL_STEP_T := 8.0         # (s) one hand more or less at most this often (a think each time swung it 6 -> 1 -> 6)
var _mill_n := -1
var _mill_t := -99.0


func _mill_feedback(mills: int) -> int:
	var crew := 0
	for m in _mine("powder_mill"):
		if m.built:
			crew += m.crew.size()
	if _mill_n < 0:
		_mill_n = crew
	if game.clock - _mill_t >= MILL_STEP_T:
		_mill_t = game.clock
		var want := POWDER_WANT + 15.0 * (_mine("barracks").size() + _mine("foundry").size())
		if _res2() > want * 2.0:
			_mill_n = maxi(mills, mini(_mill_n, crew) - 1)
		elif _res2() < want:
			_mill_n = mini(6 * mills, maxi(_mill_n, crew) + 1)
	return clampi(_mill_n, mills, 6 * mills)


## No new hall while the enemy's army is at our buildings or clearly bigger than ours on our side of the map (coached game
## a01, Red Coast 6:36: the third hall was laid 35 tiles out during the Brood's attack, its guards walked out to it and
## died; the hall was dropped). A dry main still goes (the shared rule's "urgent").
func _hall_first() -> bool:
	if not on or not bo_done or difficulty < 1 or _halls().size() < 2:
		return super()
	if _best_soil() >= DRY_LAND and (_threat() != Vector2.INF or ch.foe_near() > ch.home_value() * 1.2):
		_hall_reserve = false
		_saving = false
		return false
	if blind_guard() and _best_soil() >= DRY_LAND and (_attacking or army_behind()):
		# (crown-v-brood: the next hall goes down behind the army at home, not while it is away, and not while the army is
		# under HOLD_SHARE of the Brood army it reckons: the owner's Redrock game laid its third hall at 7:35 with 1,450 of army
		# against 5,235)
		_hall_reserve = false
		_saving = false
		return false
	return super()


## THE ARMY STAYS ON THE MAIN'S HIGH GROUND (the doctrine): no part of it walks out to stand over a hall site being saved
## for or going up (the shared rule sent guards to the staging spot; a01's walked 35 tiles into a Brood attack). The
## labourers build it alone and run home if raided.
func _guard_new_hall(army: Array) -> Array:
	if on and doctrine():
		_guards.clear()
		return army
	return super(army)


## THE POWDER WAGON STAYS BY THE HALL WHILE THE ARMY IS AT HOME (round B, b01 Red Coast 7:59: the wagon stood 120 px
## behind the ramp post, the Raptors at the gate blew it up among the Musketeers on HOLD, friends hurt too, and a minute later
## the line was gone: 706 of army at home to 40). At home the soldiers refill at the Barracks, the Town Hall and the Mill anyway; it goes with the waves.
func _tend_wagon() -> void:
	if siege != null and siege.wagon_busy():
		return                    # (out with the push: AICrownSiege._tend_wagon keeps it behind the guns)
	if not on or _attacking or difficulty < 1:
		super()
		return
	var w := _wagon()
	if w == null:
		return
	var halls := _halls()
	if halls.is_empty():
		return
	var home: Building = halls[0]
	if game.starts.size() > team:
		var st := Vector2(game.starts[team]) * Defs.TILE
		for h in halls:
			if h.built and h.center().distance_to(st) < home.center().distance_to(st):
				home = h
	if w.supplying:
		w.set_supply(false)
	if home.edge_distance(w.position) > 90.0 and w.order != "move":
		w.cmd_move(game.approach_point(home, w.position))


func _research() -> void:
	if _research_off:
		return
	super()


# ------------------------------------------------------------------ the cliff edge (0.29.2, docs/crown_cliff_edge.md)

## THE CROWN'S HALL SPOT (the owner, 2026-11-03 22:25; v2 2026-11-04 07:05): its 2nd and 3rd halls at the least hall
## distance from the main, either side of the main's ramp (the 2nd on the old natural's side, the 3rd its mirror), each a
## short walk from the ramp's foot and against the map's border; its 4th on as close to its other halls as it may
## (CrownSites.pick; _cs_field keeps the ramp's walk and the rooms measured between calls). Not where its builders were chased off lately (_hall_bad), not where the computer may not build
## (placement_problem), not on the enemy's side by land, not with enemy soldiers in sight near it. Nothing found: the shared
## pick. `-- sites:off` (or sites_on false) plays the shared pick (comparison games, tools/measure_cliff_cover.gd).
var sites_on := not OS.get_cmdline_user_args().has("sites:off")
var _cs_field := {}
var _cs_steps: Array = []
var site_picks := 0             # (tests, the coach) halls placed by the Crown's rule


func _safe_hall_spot() -> Vector2i:
	if not on or not sites_on or difficulty < 1 or not doctrine():
		return super()
	var mids: Array = []
	for h in _halls():
		mids.append(h.center() / float(Defs.TILE))
	if mids.is_empty():
		return super()
	if _cs_field.is_empty():
		_cs_field = CrownSites.edge_field(game, CrownSites.edge_cells(game, team))
	if _cs_steps.is_empty():
		var foes: Array = []
		for o in game.enemies_of(team):
			if game.starts.size() > o:
				foes.append(ExpansionSpots._steps(game, game.starts[o]))
		_cs_steps = [ExpansionSpots._steps(game, game.starts[team]), foes]
	var avoid := {}
	for c in _hall_bad:
		if float(_hall_bad[c]) > game.clock:
			avoid[c] = true
	var hall: String = _f()["hall"]
	var check := func(c: Vector2i) -> bool:
		if game.placement_problem(team, hall, c, true) != "":
			return false
		if r6_sites and _enemy_side(c):
			return false
		var cc := (Vector2(c) + Vector2(MapGen.HALL) * 0.5) * float(Defs.TILE)
		for u in game.units_near(cc, 14.0 * Defs.TILE):
			if game.hostile(u.team, team) and not u.dead and not u.is_worker() and u.has_attack() and game.is_visible_to(team, u.position):
				return false
		return true
	var picks: Array = CrownSites.pick(game, team, mids, 1, _cs_steps, avoid, check, _cs_field)
	if picks.is_empty():
		return super()
	site_picks += 1
	return picks[0]["c"]


## The labourers mending a building under the cliff while the line shoots from the edge are not pulled away by the
## workers' flight (AI._raid_workers): AICrownHold dodges them itself.
func _held_worker(u: Unit) -> bool:
	return ch.is_mender(u)


## CANNONS AGAINST THE BROOD (the owner, 2026-11-03: "cannons are so important for the Crown; I think it was a mistake to
## go Horseman"): once the Brood's creatures are seen (any Raptor or other soldier of it) or a rush is scouted against the
## Brood, the Balanced and Economy plans put the Foundry before the Horse Breeder (the Breeder still comes: the gun needs
## its horse) and the first horse goes to a Field Cannon for the ramp post / the cliff edge; the rider scout waits for the
## gun (a labourer scouts meanwhile). Against the Crown and the Clockwork the order stays. `-- cannon:off` plays without it.
var cannon_on := not OS.get_cmdline_user_args().has("cannon:off")
var cannon_first := false
var cannon_first_t := -1.0
const RIDER_WAIT_MAX := 420.0   # (s) from the Brood seen: the waits for the first gun end by then whatever happens


func _cannon_check() -> void:
	if not on or not cannon_on or difficulty < 1 or not (strategy == "balanced" or strategy == "economy") or not _foe_is("brood"):
		return
	var seen := ch.foe_known() > 0.0 or (scout != null and scout.verdict == "rush")
	if not seen:
		# (any creature of the Brood in sight: the scout at its Mother counts; coached game kr_timing, Kestrel Rise v the
		# Brood's Timing: no Raptor was seen before its attack at 6:47, and the cannon came after it)
		for o in game.enemies_of(team):
			if game.faction_of(o) != "brood":
				continue
			for u in game.army(o):
				if not u.dead and game.is_visible_to(team, u.position):
					seen = true
					break
	if not seen:
		return
	cannon_first = true
	cannon_first_t = game.clock
	# the opening: a Horse Breeder step still to come is preceded by the Foundry (at the Breeder's trigger)
	for k in range(bo_i, _bo_plan.size()):
		var st: Dictionary = _bo_plan[k]
		if String(st["do"]) == "build" and String(st["k"]) == "horse_breeder":
			if _mine("foundry").is_empty():
				_bo_plan.insert(k, {"do": "build", "k": "foundry", "at": st.get("at", {})})
				_bo_plan[k + 1]["at"] = {"has": "foundry"}
			break
	# the milestones: the Foundry before the Breeder (the Balanced plan: with no labourer count; the Economy plan, which
	# expands and fills its farms first, keeps its count: its opening has no Breeder, the Foundry is its first milestone
	# after the second Barracks' place, 0.29.2)
	var mid: Array = plan.get("mid", [])
	var fi := -1
	for k in mid.size():
		if String(mid[k][0]) == "foundry" and int(mid[k][1]) == 1 and fi < 0:
			fi = k
	if fi >= 0:
		var fm: Array = mid[fi]
		mid.remove_at(fi)
		var hi2 := -1
		for k in mid.size():
			if String(mid[k][0]) == "horse_breeder":
				hi2 = k
				break
		mid.insert(fi if hi2 < 0 else mini(fi, hi2), ["foundry", 1, fm[2] if strategy == "economy" else {}])
	over["mid"] = mid
	plan["mid"] = mid
	say("the Brood is seen (%s): the Foundry before the Horse Breeder, a Field Cannon for the ramp post first" % ("a rush scouted" if scout != null and scout.verdict == "rush" else ("its army in sight" if ch.foe_known() > 0.0 else "its creatures in sight")))


func _riders_wait() -> bool:
	return rider_waits()


## THE FIRST GUN'S WAIT: against the Brood, until the first Field Cannon is out or ordered, once the Foundry and the
## Breeder stand (GUN_WAIT s at most from then; RIDER_WAIT_MAX s at most from the Brood seen): the opening's new hall (the
## Balanced plan; the Economy plan expands first), the milestones and the riders wait, so its gold comes (coached game
## kr_timing: with the waits counted from the Brood seen at 0:57 a Horseman came at 5:38 and the cannon at 8:17).
const GUN_WAIT := 90.0
var _gun_ready_t := -1.0


func _gun_waiting() -> bool:
	if not cannon_first or game.clock - cannon_first_t > RIDER_WAIT_MAX or not _gun_first():
		return false
	for u in game.army(team):
		if u.kind == "cannon" and not u.dead:
			return false
	if _gun_ready_t < 0.0 and _gun_can():
		_gun_ready_t = game.clock
	return _gun_ready_t < 0.0 or game.clock - _gun_ready_t <= GUN_WAIT


func _first_gun() -> void:
	for f in _mine("foundry"):
		if f.built and f.queue.is_empty() and game.can_train(f, "cannon") == "":
			game.train(f, "cannon")
			return


func _gun_can() -> bool:
	return _mine("foundry").any(func(b: Building) -> bool: return b.built) and _mine("horse_breeder").any(func(b: Building) -> bool: return b.built)


func _hall_waits_gun() -> bool:
	return hall_waits_gun and strategy == "balanced" and _gun_waiting() and _gun_can()


## (off: coached games rc7_after / rc7_nocannon, Red Coast v the Brood's Timing: with the new hall waiting for the gun it
## went down at 5:53 instead of 5:05 and the main fell at 9:51; with the hall first the line held. The gun follows the hall.)
var hall_waits_gun := OS.get_cmdline_user_args().has("hallgun:on")


## THE GUN'S GOLD: the Barracks save for the first Field Cannon and the milestones wait for it (`-- gunsave:off` lets
## the soldiers and the milestones spend as before: the gun then comes from what is left).
var gun_saves := not OS.get_cmdline_user_args().has("gunsave:off")


func _gun_save() -> bool:
	return gun_saves and _gun_first()


func _gun_first() -> bool:
	if not cannon_first:
		return false
	for f in _mine("foundry"):
		if (f.queue as Array).has("cannon"):
			return false
	return true


## THE FOUNDRY BEFORE THE SECOND BARRACKS (the owner's rule, above PLANS): a second Barracks asked for (by a step, a
## milestone, the shared rules or the scout's plan) while no Foundry stands or is going up puts the Foundry up instead.
## `-- foundry1:off` plays without it.
var foundry_rule_on := not OS.get_cmdline_user_args().has("foundry1:off")
var foundry_swaps := 0          # (tests)


func _construct(kind: String, at := Vector2i(-1, -1)) -> void:
	if on and foundry_rule_on and kind == "barracks" and not _mine("barracks").is_empty() and _mine("foundry").is_empty() and game.requirement_met(team, "foundry"):
		foundry_swaps += 1
		super("foundry")
		return
	super(kind, at)


## (AICrownHold.wants_rider asks: against the Brood with the cannon first, the rider waits for the first gun)
func rider_waits() -> bool:
	return _gun_waiting()


# ------------------------------------------------------------------ after the opening: the milestones

func _build_up() -> void:
	super()
	if not _plan_tech() or _hall_reserve or (_cw_active() and not _walled):
		return
	_mid_tick()


func _mid_tick() -> void:
	if gun_saves and _gun_waiting() and _gun_can():
		return                  # (the first Field Cannon's gold first: CANNONS AGAINST THE BROOD)
	var labs := game.workers(team).size()
	var halls := _halls().filter(func(h: Building) -> bool: return h.built).size()
	var army := _army_supply(game.army(team))
	if _threat_prod(labs, halls, army):
		return
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


# ------------------------------------------------------------------ the Dragoon raids (crown-builds-a)
## The plan "dragoon" (docs/crown_builds_a.md): its riders are trained here before the shared soldiers, and ride in the
## groups of scripts/ai_dragoon_raid.gd (out of the army's think: _on_errand). Nothing here runs on another plan.
const DragoonRaid := preload("res://scripts/ai_dragoon_raid.gd")
var dr = null


func dragoon_plan() -> bool:
	return on and strategy == "dragoon" and difficulty >= 1


func _on_errand(u: Unit) -> bool:
	if dr != null and dr.has(u):
		return true
	if siege != null and siege.has(u):
		return true
	if bl != null and bl.has(u):
		return true           # (the harass's balloons and men: the army, the post and the waves leave them be)
	return super(u)


func _tick_ai(delta: float) -> void:
	super(delta)
	if dr != null and not game.over:
		dr.micro()


func _raid() -> void:
	super()
	if dragoon_plan() and not peaceful:
		if dr == null:
			dr = DragoonRaid.new(self)
		dr.tick()


func _produce() -> void:
	if siege != null:
		siege.produce()           # (the guns first: the shared training adds one now and then)
		var keep: int = clampi(siege.gun_due(), 0, int(game.players[team]["gold"]))
		game.players[team]["gold"] -= keep
		super()
		game.players[team]["gold"] += keep
		return
	if not dragoon_plan():
		super()
		return
	var short := _train_dragoons()
	# (the riders short: a Dragoon's gold, horse and all, is kept from the line's Musketeers, unless the enemy is at home)
	var held := 0
	if short and _threat() == Vector2.INF:
		held = clampi(DRAGOON_KEEP, 0, int(game.players[team]["gold"]))
	game.players[team]["gold"] -= held
	super()
	game.players[team]["gold"] += held


## The Dragoons the raids want (DragoonRaid.want), from every Barracks with room, before the line's Musketeers; the plan's
## gold for a step or a milestone is kept from them as from any soldier.
const DRAGOON_KEEP := 100       # (gold) a Dragoon and his horse


## True: the raids want more riders than there are.
func _train_dragoons() -> bool:
	if not bo_done:
		return false            # (the riders come with the second hall: before it the opening's gold is the economy's, round A)
	if _keeping() and _gold() < 30:
		return false
	var army := game.army(team)
	var minimum := mini(40, 6 + int(game.clock / 20.0))     # (the line's minimum, as AI._produce: round B, b06, a milestone's
	if (_saving or (_reserve > 0 and _gold() < _reserve + 60)) and _army_supply(army) >= minimum:     # gold held the riders back till 11:00)
		return false
	var r: Dictionary = plan.get("raid", {"musk": 4, "from": 14, "per": 8})
	var musk := army.filter(func(u: Unit) -> bool: return u.kind == "musketeer" and not u.auto_mount).size()
	var have := army.filter(func(u: Unit) -> bool: return DragoonRaid.is_rider(u)).size()
	for b in _mine("barracks"):
		have += b.queue.count("dragoon")
	var want: int = DragoonRaid.want(game.workers(team).size(), musk, int(r["musk"]), int(r["from"]), int(r["per"]))
	for b in _mine("barracks"):
		if have >= want:
			return false
		if b.built and b.queue.size() < 2 and game.can_train(b, "dragoon") == "":
			if game.train(b, "dragoon") == "":
				have += 1
	return have < want


# ------------------------------------------------------------------ the siege push (scripts/ai_crown_siege.gd)

## The siege plan plays its push (Normal and up, the new computer): the shared waves never go.
func siege_on() -> bool:
	return on and difficulty >= 1 and bool(plan.get("siege", false))


func _army() -> void:
	if siege != null and not peaceful:
		siege.tick()
	super()



# ------------------------------------------------------------------ the balloon harass (crown-builds-c)

## The shared balloon drop (AI._balloon_drop) gives way to the harass on its plan.
func _balloon_drop() -> void:
	if bl != null:
		bl.tick()
		return
	super()


## The "balloons" step: the Foundry rigs one (its price set aside like a building's).
func _bl_step(st: Dictionary) -> String:
	if bl == null:
		return ""
	var c := int(Defs.UNITS["balloon"]["cost"])
	if _gold() < c:
		return "gold"
	if _res2() < float(Defs.UNITS["balloon"].get("cost2", 0)):
		return "wait"
	var n0: int = bl.queued()
	bl.produce(int(st.get("n", 1)))
	return "" if bl.queued() > n0 else "wait"


# ------------------------------------------------------------------ the Crown against the Brood (crown-v-brood)
# docs/crown_v_brood.md. The owner, 2026-11-04: "the problem with Brood vs Crown doesn't seem to be economics, it's the Crown
# AI". Design: docs/design_principles.md 1 (counterplay: scout before you commit, answer what you see) and 2 (the defender's
# advantage: walls and the high ground while the enemy is bigger; a lost battle must not be a lost game).

## A RANDOM PLAN weighed by the matchup (as AIClockwork's Pendulums against the Brood): against the Brood the Balloon
## harass is never picked (Mist Toads pull balloons, Spitters shoot them; the owner's Redrock game: one grub in 3 minutes)
## and the plans that held or hurt the Brood in the coached games come more often. Any other matchup: evenly.
const RANDOM_VS_BROOD := {"balanced": 3.0, "timing": 2.0, "rush": 2.0, "siege": 2.0, "economy": 1.0, "dragoon": 1.0, "balloon": 0.0}


func random_plan(allowed: Array) -> String:
	if not _foe_is("brood"):
		return super.random_plan(allowed)
	var total := 0.0
	for k in allowed:
		total += float(RANDOM_VS_BROOD.get(k, 1.0))
	if total <= 0.0:
		return super.random_plan(allowed)
	var r := randf() * total
	for k in allowed:
		r -= float(RANDOM_VS_BROOD.get(k, 1.0))
		if r < 0.0 and float(RANDOM_VS_BROOD.get(k, 1.0)) > 0.0:
			return String(k)
	for k in allowed:
		if float(RANDOM_VS_BROOD.get(k, 1.0)) > 0.0:
			return String(k)
	return super.random_plan(allowed)


## THE HORSEMAN RUSH KEEPS RAIDING WHILE IT WINS (the owner's Thornwood log: "rush: SUCCEEDED, mop-up: the riders regroup
## at home" at 3:35 with 345 killed for 100 lost). Against the Brood the riders go on hunting grubs (and the rooted
## Rootmaws when no grub is in sight, AIHarass rides past the static ones) until they are beaten down, a real answer is at
## hand, or nothing has died for HUNT_DRY s.
const HUNT_KEEP := 0.5          # the riders end the hunt when down to this share of the party (and at least 2 lost)
const HUNT_ANSWER := 1.15       # ... or the mobile armed creatures at the riders are worth this times them (the shared
                                # rush verdict's FAILED edge; rooted Rootmaws, turtles and the Mother do not chase: not counted)
const HUNT_DRY := 75.0          # ... or nothing has been killed for this long
var _hunt_kill := 0
var _hunt_kill_t := 0.0
var hunt_log: Array = []        # (tests) [clock, text]


func _rush_hunt_on(party: Array) -> bool:
	if not on or difficulty < 1 or not _foe_is("brood") or party.size() < 2:
		return false
	var mine := 0.0
	for u in party:
		mine += _unit_value(u)
	var defv := _hunt_answer(party)
	if defv >= mine * HUNT_ANSWER:
		return false
	_hunt_kill = int(game.stats[team]["value_killed"])
	_hunt_kill_t = game.clock
	_rush_hunt_said = "%d killed, %d riders left, defenders seen %d" % [_hunt_kill - _wave_kill0, party.size(), int(defv)]
	hunt_log.append([game.clock, "on: " + _rush_hunt_said])
	return true


func _rush_hunt_over(party: Array) -> String:
	var why := ""
	var mine := 0.0
	for u in party:
		mine += _unit_value(u)
	var k := int(game.stats[team]["value_killed"])
	if k > _hunt_kill:
		_hunt_kill = k
		_hunt_kill_t = game.clock
	var defv := _hunt_answer(party)
	if party.size() < 2 or (float(party.size()) <= float(_rush_n0) * HUNT_KEEP and _rush_n0 - party.size() >= 2):
		why = "the riders are down to %d of %d" % [party.size(), _rush_n0]
	elif defv >= mine * HUNT_ANSWER and defv >= 100.0:
		why = "a real answer: %d of soldiers against its %d" % [int(defv), int(mine)]
	elif game.clock - _hunt_kill_t > HUNT_DRY:
		why = "nothing killed for %d s" % int(game.clock - _hunt_kill_t)
	if why != "":
		hunt_log.append([game.clock, "over: " + why])
	return why


## The hunt's prey: a grub in sight as before; none in sight, the nearest Rootmaw seen (the Brood's income) instead of the
## middle of its base, where the Mother and the Mound Turtles stand.
func _prey_spot(from: Vector2) -> Vector2:
	var p := super(from)
	if _rush_mode != "hunt" or not _foe_is("brood"):
		return p
	var foe := _foe()
	for o in game.units:
		if not o.dead and not o.off_field and o.team == foe and o.is_worker() and game.is_visible_to(team, o.position):
			return p
	var best := Vector2.INF
	for o in game.army(foe):
		if o.dead or o.kind != "rootmaw" or not _sighted(o):
			continue
		if best == Vector2.INF or o.position.distance_to(from) < best.distance_to(from):
			best = o.position
	return best if best != Vector2.INF else p



## NO BLIND ATTACKS (the owner's Redrock log, 7:53: "goes down with its army: no attack for 240 s on two halls and its army
## (1450) is not behind (0)"; the 0 was the army it had NOT seen, and the Brood's 77 supply (5,235) caught it in the open:
## "If your enemy is also Economy you can't attack without scouting, they got caught in the open"). Against the Brood:
##  - a wave or a timing goes only with a FRESH report: an enemy soldier in sight, or its main looked at, in the last
##    LOOK_FRESH s; else a scout is sent first (the labourer / Musketeer scout, the riders' loop) and the army waits;
##  - the enemy army it weighs is foe_estimate(): what it saw lately, but never less than what a Brood of that age with the
##    Rootmaws it has seen would have (BROOD_TABLE, BROOD_PER_MAW), less a part of what we killed.
## Switch: `-- blind:on` plays the old rule (a study's "before").
var blind_ok := OS.get_cmdline_user_args().has("blind:on")
const LOOK_FRESH := 75.0
var _base_looked_t := -999.0
var _look_said := -99.0
var looks_asked := 0            # (tests)
var _maws_seen := {}            # enemy Rootmaw -> true (the most seen alive at once is kept)
var maws_peak := 0


func blind_guard() -> bool:
	return on and not blind_ok and difficulty >= 1 and _foe_is("brood")


## An enemy soldier in sight, or the enemy's main looked at, in the last LOOK_FRESH s.
func scouted_fresh() -> bool:
	_look_tick()
	return game.clock - ch._last_army_t <= LOOK_FRESH or game.clock - _base_looked_t <= LOOK_FRESH


func _look_tick() -> void:
	var foe := _foe()
	if foe < 0 or game.starts.size() <= foe:
		return
	var their := (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE
	if game.is_visible_to(team, their):
		_base_looked_t = game.clock
	for u in _maws_seen.keys():
		if not is_instance_valid(u) or u.dead:
			_maws_seen.erase(u)
	for u in game.army(foe):
		if not u.dead and u.kind == "rootmaw" and game.is_visible_to(team, u.position):
			_maws_seen[u] = true
	maws_peak = maxi(maws_peak, _maws_seen.size())


## Ask for a look at the enemy: the scout's next trip now (another trip past its five when need be), the riders' loop runs.
func want_look(who: String) -> void:
	if scout != null and scout.state != "going":
		if scout.trips >= AIScout.MAX_TRIPS:
			scout.trips = AIScout.MAX_TRIPS - 1
		scout.next_trip = minf(scout.next_trip, game.clock)
	if game.clock - _look_said > 45.0:
		_look_said = game.clock
		looks_asked += 1
		say("%s waits for a fresh scout report: no enemy soldier seen for %s and its main not looked at for %s" % [who,
			("%d s" % int(game.clock - ch._last_army_t)) if ch._last_army_t > 0.0 else "the whole game",
			("%d s" % int(game.clock - _base_looked_t)) if _base_looked_t > 0.0 else "the whole game"])


## The Brood's army as the Crown reckons it: what it saw in the last two minutes (AICrownHold.foe_known), never less than a
## Brood of that age would have (the Hard Brood's mobile army in the coached games, BROOD_TABLE), more with more Rootmaws
## seen than such a Brood roots (BROOD_PER_MAW a Rootmaw past BROOD_MAWS), less half of what we have killed of it.
## Other matchups: what it saw.
const BROOD_TABLE := [[0.0, 0.0], [180.0, 100.0], [300.0, 450.0], [360.0, 700.0], [420.0, 1300.0], [480.0, 2200.0], [540.0, 3000.0], [600.0, 3800.0], [720.0, 5000.0]]
const BROOD_MAWS := [[0.0, 1.0], [180.0, 4.0], [300.0, 6.0], [480.0, 8.0]]
const BROOD_PER_MAW := 250.0


static func _lerp_table(tab: Array, x: float) -> float:
	if x <= float(tab[0][0]):
		return float(tab[0][1])
	for i in range(1, tab.size()):
		if x <= float(tab[i][0]):
			var a: Array = tab[i - 1]
			var b: Array = tab[i]
			return lerpf(float(a[1]), float(b[1]), (x - float(a[0])) / maxf(1.0, float(b[0]) - float(a[0])))
	return float(tab[-1][1])


func foe_estimate() -> float:
	var known: float = ch.foe_known()
	if not _foe_is("brood"):
		return known
	_look_tick()
	var t := game.clock
	var est := _lerp_table(BROOD_TABLE, t)
	est += maxf(0.0, float(maws_peak) - _lerp_table(BROOD_MAWS, t)) * BROOD_PER_MAW
	est -= 0.5 * float(game.stats[team]["value_killed"])
	return maxf(known, est)



## Under HOLD_SHARE of the Brood army it reckons (against the Brood only).
func army_behind() -> bool:
	if not blind_guard() or brood_army_off:
		return false
	if ch._last_army_t < 0.0 and game.clock < ARMY_RECKON_T:
		return false        # (no Brood soldier seen yet: the reckoning drives the army from ARMY_RECKON_T on)
	return float(game.army_value(team)) < foe_estimate() * HOLD_SHARE


## PRODUCTION FOR THE THREAT (crown-v-brood; the coached Redrock Economy game a1: one Barracks until 7:03, 4 Musketeers at
## 6:00 against 2,225 of Brood): against the Brood, while the army is behind (army_behind) and every Barracks and Foundry is
## busy, the plan's next Foundry or Barracks milestone comes now whatever its labourer count (the Foundry still before the
## second Barracks: AICrown._construct), up to one production building for every PROD_PER labourers. Triggered by the
## threat it reckons, not the clock.
const PROD_PER := 9
const PROD_BUSY := 15.0         # (s) every Barracks and Foundry busy this long first
var _prod_busy_t := -1.0
var threat_builds := 0          # (tests, the coach)


func _threat_prod(labs: int, halls: int, army: int) -> bool:
	if not army_behind():
		_prod_busy_t = -1.0
		return false
	var prod: Array = _mine("barracks") + _mine("foundry")
	if prod.is_empty() or prod.size() >= maxi(2, labs / PROD_PER):
		return false
	for b in prod:
		if not b.built or b.queue.is_empty():
			_prod_busy_t = -1.0
			return false
	if _prod_busy_t < 0.0:
		_prod_busy_t = game.clock
	if game.clock - _prod_busy_t < PROD_BUSY:
		return false
	for m in plan.get("mid", []):
		var k := String(m[0])
		if not k in ["barracks", "foundry"] or _mine(k).size() >= int(m[1]):
			continue
		if not game.requirement_met(team, k) or _busy_building(k):
			return false
		var cost := int(Defs.BUILDINGS[k]["cost"])
		if _gold() < cost:
			_reserve = maxi(_reserve, cost)
			return true
		var n0 := _mine(k).size() + _mine("foundry" if k == "barracks" else "barracks").size()
		_construct(k)
		if _mine("barracks").size() + _mine("foundry").size() > n0:
			threat_builds += 1
			_prod_busy_t = -1.0
			say("milestone for the Brood's army: %s %d now (%d labourers, army %d of the %d it reckons)" % [String(Defs.BUILDINGS[k]["name"]),
				int(m[1]), labs, game.army_value(team), int(foe_estimate())])
		return true
	return false



## Gold the Brood walls (AIExpandWall.brood_walls) leave alone: the first Field Cannon's while it is awaited, the opening's.
func brood_wall_keep() -> int:
	var k := bo_reserve if bo_owns() else 0
	if cannon_first and _gun_waiting():
		k += int(Defs.UNITS["cannon"]["cost"])
	return k



## The mobile armed creatures in sight within HUNT_R of the riders (value): what could catch and fight them.
const HUNT_R := 360.0


func _hunt_answer(party: Array) -> float:
	if party.is_empty():
		return 0.0
	var c := Vector2.ZERO
	for u in party:
		c += u.position
	c /= float(party.size())
	var v := 0.0
	for o in game.units_near(c, HUNT_R):
		if o.dead or o.off_field or not game.hostile(o.team, team) or o.is_worker() or not _armed(o) or AIHarass.is_static(o) or not _sighted(o):
			continue
		v += _unit_value(o)
	return v
