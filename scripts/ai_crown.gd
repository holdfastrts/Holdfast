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
## THE MARCHING BAND (a real unit since 0.33.0): AI._band trains it at the Armoury (army 10+, a second at 30+) and
## researches its Fifer and Piper, keeping the gold back for them; MarchingBand.ai_tick keeps it behind the line and plays
## its solos.
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
var cm: AICrownMirror = null     # (crown-v-crown-coach) the mirror's coached play (scripts/ai_crown_mirror.gd); null unless the foe is a Crown


## (crown-v-crown-coach) the Crown computer against another Crown (the new computer): AICrownMirror plays
## the mirror's coached decisions (Normal and up). `-- mirror:off` on the command line plays the mirror as before (comparison games).
func mirror() -> AICrownMirror:
	if cm == null and on and difficulty >= 1 and _foe_is("crown") and not OS.get_cmdline_user_args().has("mirror:off"):
		cm = AICrownMirror.new(self)
	return cm


func _cohesion(wave: Array) -> bool:
	return mirror() != null and cm.cohesion(wave, _wave_target)


func _guns_at_hall(wave: Array) -> void:
	if mirror() != null:
		cm.guns_at_hall(wave, _wave_target)


func _siege_skip(u: Unit) -> bool:
	return cm != null and cm.gunners.has(u)


func _siege_paused() -> bool:
	return cm != null and (cm.regrouping() or cm.bombarding())


func _siege_hold_off(wave: Array, piece: Building, back: Vector2) -> bool:
	return mirror() != null and cm.bombard(wave, piece, back, _wave_target)


func _hunt_anyway(foe_t: int, army: Array) -> bool:
	return mirror() != null and cm.hunt_anyway(foe_t, army)


func _hunt_goal(foe_t: int, from: Vector2) -> Vector2:
	if mirror() != null:
		return cm.hunt_goal(foe_t, from)
	return super(foe_t, from)
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
	# the Economy plan, THE OWNER'S OWN OPENING (crown-owner-eco, docs/crown_owner_eco.md; his Highmoor game 0.30.8: the ramp
	# Cottage and its Gate at 0:36, the second Farm, the SECOND HALL DONE AT 2:46 before any Barracks, a Farm at the new hall
	# at once, the Mill, then the Barracks at 3:29): no Barracks on a timer. The Barracks comes after the second hall, or at
	# once when the scout sees a rush coming (_bo_defence inserts it: the shared anti-rush defence); then the Foundry before
	# the second Barracks (the owner's rule), the Breeder for the guns' horses
	"economy": {"opening": "mill", "labs": 99, "army": 0.4, "mill": [[0, 2], [17, 4], [22, 6]],
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "wall_gate", "at": {"sup": 5}},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 7}},
			{"do": "hall", "n": 2, "at": {"labs": 11}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 15, "halls": 2}},
			{"do": "build", "k": "barracks", "at": {"labs": 17, "halls": 2}},
			{"do": "army", "k": "musketeer", "cap": 6},
			{"do": "build", "k": "foundry", "at": {"labs": 21}},
			{"do": "build", "k": "horse_breeder", "at": {"labs": 23}},
		],
		"mid": [["barracks", 1, {}], ["foundry", 1, {}], ["horse_breeder", 1, {}], ["barracks", 2, {"halls": 2}],
			["barracks", 3, {"labs": 26}], ["barracks", 4, {"labs": 32}], ["church", 1, {"labs": 38, "halls": 2}],
			["armoury", 1, {"labs": 42}], ["foundry", 2, {"labs": 44, "halls": 3}]],
		"bo_old": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 7}},
			{"do": "wall_gate", "at": {"labs": 7}},
			{"do": "build", "k": "barracks", "at": {"labs": 8}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 8}},
			{"do": "army", "k": "musketeer", "cap": 6},
			{"do": "hall", "n": 2, "at": {"labs": 15}},
		],
		"mid_old": [["barracks", 1, {}], ["foundry", 1, {"labs": 20, "halls": 2}], ["horse_breeder", 1, {"labs": 20}],
			["barracks", 2, {"labs": 22, "halls": 2}], ["armoury", 1, {"labs": 30}], ["barracks", 3, {"labs": 34}],
			["church", 1, {"labs": 40, "halls": 2}], ["foundry", 2, {"labs": 48, "halls": 3}]],
		"s": {"wave": 34, "step": 10}, "owner": true},
	# Balanced: the owner's opening too (crown-owner-eco: "if you scout a rush you need a Barracks, but if you don't scout
	# that, why make a Barracks?"): the ramp Cottage and its Gate, the second Farm, the second hall at 11 labourers; the
	# Barracks and the Mill come right behind the hall (sooner than the Economy plan's), more Musketeers, the Breeder for a
	# rider scout; a scouted rush puts the Barracks and the Mill up at once (_bo_defence; tools/test_ai_wall_vs_rush.gd)
	"balanced": {"opening": "mill", "labs": 99, "army": 0.55, "mill": [[0, 3], [16, 5], [20, 6]],
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "wall_gate", "at": {"sup": 5}},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 7}},
			{"do": "hall", "n": 2, "at": {"labs": 11}},
			{"do": "build", "k": "barracks", "at": {"labs": 14, "halls": 2}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 14, "halls": 2}},
			{"do": "army", "k": "musketeer", "cap": 8},
		],
		# (the Breeder and the Foundry are milestones: an opening that went on to them kept the army at 8 supply till 6:30)
		# (against the Brood: the Barracks and the Mill at 7 labourers as before. The Brood's fastest rush has Raptors at our
		# ramp by ~1:50 and the scout's first look comes at ~1:10: a Barracks laid on what it sees is up at ~1:50 and its first
		# Musketeer comes at ~2:40, after the gate fell (tools/test_ai_wall_vs_rush.gd, the owner's 6-pool anchor). The
		# reason is the matchup: the second hall at 12 labourers right behind them)
		"bo_brood": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "wall_gate", "at": {"sup": 5}},
			{"do": "build", "k": "barracks", "at": {"labs": 7}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 7}},
			{"do": "army", "k": "musketeer", "cap": 8},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 9}},
			{"do": "hall", "n": 2, "at": {"labs": 12}},
		],
		"mid": [["barracks", 1, {}], ["foundry", 1, {}], ["barracks", 2, {}], ["horse_breeder", 1, {}],
			["barracks", 3, {"labs": 24}], ["barracks", 4, {"labs": 30}], ["armoury", 1, {"labs": 30}],
			["church", 1, {"labs": 36, "halls": 2}], ["foundry", 2, {"labs": 42, "halls": 3}]],
		"bo_old": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "wall_gate", "at": {"sup": 5}},
			{"do": "build", "k": "barracks", "at": {"labs": 7}},
			{"do": "build", "k": "powder_mill", "at": {"labs": 7}},
			{"do": "army", "k": "musketeer", "cap": 8},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 9}},
			{"do": "build", "k": "horse_breeder", "at": {"labs": 13}},
			{"do": "hall", "n": 2, "at": {"labs": 15}},
		],
		"mid_old": [["barracks", 1, {}], ["horse_breeder", 1, {}], ["foundry", 1, {"labs": 18}], ["barracks", 2, {"labs": 18}],
			["armoury", 1, {"labs": 26}], ["barracks", 3, {"labs": 30}], ["church", 1, {"labs": 36, "halls": 2}],
			["foundry", 2, {"labs": 44, "halls": 3}]],
		"s": {"wave": 18, "step": 8}, "owner": true},
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
		# (OPTIMAL's punish of a greedy Brood, crown-optimal-opening: picked on the read from the common opening, whose
		# Barracks, Farm and Gate stand already: the Breeder at once, Horsemen before labourers but the labourers never capped
		# (the hall keeps one coming while the Barracks is busy), the riders out at 9 supply, and the second hall right
		# behind the raid with the Powder Mill: the opening goes on past the attack to lay them, _bo_after_attack)
		"bo_opt": [
			{"do": "build", "k": "horse_breeder"},
			{"do": "army", "k": "cuirassier", "cap": 0, "first": true},
			{"do": "labs", "n": 99},
			{"do": "attack", "n": 9, "at": {"army": 9}},
			{"do": "build", "k": "powder_mill"},          # (the riders' pistols and the Musketeers after: without it the
			# army stood at 12 supply till 7:00 for want of powder and the Brood's Raptors took both halls at 8:20, Greenhold)
			{"do": "hall", "n": 2, "at": {"labs": 13}},
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
	# OPTIMAL (ai-optimal, scripts/ai_optimal.gd): THE COMMON OPENING, the owner's (crown-optimal-opening, 2026-11-06 09:17,
	# docs/crown_optimal_opening.md): "the powder mill was a mistake. It could have made barracks because you don't know if
	# the enemy is rushing, but after the barracks it should've been a Farm. After scouting, then a decision on powder mill
	# or horse breeder." The ramp Cottage, the Gate, the BARRACKS (a rush is not ruled out yet), the second FARM, the scout out
	# at once; NO Powder Mill and no soldiers before the read (a seen rush puts the Mill and the soldiers first: _bo_defence;
	# a gold-only Musketeer comes out with his bayonet, crown-ammo). The build order then waits at "pick" while the
	# labourers keep coming (the gold goes to them and to the Cottages ahead, never kept for the pick) until OPTIMAL picks a
	# build from the read; that build's steps take over (opt_switch): the Mill for Musketeer play, the Horse Breeder for
	# riders. The same in every matchup (it was the Barracks, the Mill and 4 Musketeers against the Brood: one labourer in
	# the whole second minute, the second hall at 4:45, docs/playtests/2026-11-06/crown_optimal_slow_expand_log.txt).
	"optimal": {"opening": "mill", "labs": 99, "army": 0.5, "mill": [[0, 3], [16, 5], [20, 6]],
		"bo": [
			{"do": "wall_cottage", "at": {"sup": 5}},
			{"do": "wall_gate", "at": {"sup": 5}},
			{"do": "build", "k": "barracks", "at": {"labs": 7}},
			{"do": "build", "k": "farm", "n": 2, "at": {"labs": 8}},
			{"do": "pick"},
		],
		"mid": [["barracks", 1, {}], ["foundry", 1, {}], ["barracks", 2, {}], ["horse_breeder", 1, {}],
			["barracks", 3, {"labs": 24}], ["armoury", 1, {"labs": 30}], ["church", 1, {"labs": 36, "halls": 2}]],
		"s": {"wave": 18, "step": 8}, "owner": true},
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
	if strategy == "optimal":
		# OPTIMAL (scripts/ai_optimal.gd): the common opening (PLANS["optimal"]: the ramp Cottage, the Gate, the Barracks, the second Farm,
		# then the pick), or the Horseman rush when it leans to it before scouting (the matchup, the map)
		opt = AIOptimal.new(self, "optimal")
		var ln: String = opt.lean_now() if on else ""
		if ln != "":
			strategy = ln
	_opened = strategy
	_make_plan()
	opening = String(plan.get("opening", "mill"))
	for a in OS.get_cmdline_user_args():
		if a == "open%d:breeder" % team or a == "open%d:mill" % team:
			opening = a.split(":")[1]          # (study switch, as in AI._ready)
	if game.mlog and opt == null:
		# (ai-optimal story audit: the owner's plans open with the second hall, the Barracks and the Mill after it; "a Powder
		# Mill: Musketeers first" was wrong there. OPTIMAL tells its own opening)
		var what := "Horse Breeder (Horseman rush)" if opening == "breeder" else ("its economy (the second hall before the Barracks)" if owner_on() else "Powder Mill (Musketeers)")
		game.mlog.add("%s opens with %s%s" % [game.mlog.who(team), "" if owner_on() and opening != "breeder" else "a ", what])
	scout = AIScout.new(self)
	if opt != null and difficulty >= 1 and not peaceful:
		scout.enabled = true            # (OPTIMAL always scouts, its Horseman rush too: the read is how it picks)
		scout.mod = {}
		scout.next_trip = OWNER_SCOUT_AT
		scout.min_workers = 4
		if strategy != "optimal":
			opt.lean_said(strategy)
		say("OPTIMAL: the common opening (the ramp Cottage, the Gate, the Barracks, the second Farm), a scout at once, then it picks its build from what it sees")
	if owner_on():
		# (crown-owner-eco: no Barracks without a reason, so the scout leaves at once to see a rush in time: a Brood that
		# rushes has its Tyrant Sire by 0:40, our labourer walks there in ~50 s)
		scout.next_trip = OWNER_SCOUT_AT
		scout.min_workers = 4
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
	if game.mlog and strategy != "optimal":
		# (OPTIMAL's common opening is not a plan of its own: the line comes when it picks, opt_switch)
		game.mlog.add("%s's plan: %s, a build order of %d steps (scripts/ai_crown.gd)" % [game.mlog.who(team), STRATEGIES.get(strategy, STRATEGIES["balanced"])["name"], _bo_plan.size()])


var _opened_from := ""            # (opt_switch) the build it played before the pick: "optimal" = the common opening


## OPTIMAL's pick (scripts/ai_optimal.gd): play build k from where the game stands. In the opening its build order takes
## over from the next step (the steps already done are passed by: _st_done); after the opening its milestones and its own
## parts (the siege push, the balloons, the Dragoon raids, the Horseman rush) play on.
func opt_switch(k: String) -> bool:
	if not on or not PLANS.has(k):
		return super(k)
	_opened_from = strategy
	strategy = k
	_opened = k
	over.erase("mid")             # (the cannon rule's milestones were the old plan's: _cannon_check looks again)
	cannon_first = false
	_make_plan()
	opening = String(plan.get("opening", "mill"))
	if difficulty >= 1 and not bo_done:
		var key := "bo_brood" if plan.has("bo_brood") and _foe_is("brood") else "bo"
		if plan.has("bo_opt") and opt != null and _opened_from == "optimal":
			key = "bo_opt"         # (the build's own version for a pick from the common opening: the Rush's punish)
		_bo_plan = _bo_plan.slice(0, bo_i) + (plan[key] as Array).duplicate(true)
		bo_lab_cap = int(plan.get("labs", 99))
		if not _def_on:
			bo_army = false
			bo_army_cap = 0
		bo_army_first = false
		_waits.clear()
		_att_ready_t = -1.0
	_attack_at = int(_s("wave"))
	if k == "rush" and opening == "breeder":
		_attack_at = maxi(_attack_at, RUSH_HORSEMEN * int(Defs.UNITS["cuirassier"]["supply"]))
	if siege == null and siege_on():
		siege = AICrownSiege.new(self)
	if k == "balloon" and bl == null and difficulty >= 1:
		bl = AICrownBalloon.new(self)
	if game.mlog:
		game.mlog.add("%s's plan: %s, a build order of %d steps from here (scripts/ai_crown.gd)" % [game.mlog.who(team), STRATEGIES[k]["name"], maxi(0, _bo_plan.size() - bo_i)])
	return true


func _make_plan() -> void:
	_plan_of = strategy
	plan = (PLANS.get(strategy, PLANS["balanced"]) as Dictionary).duplicate(true)
	if OS.get_cmdline_user_args().has("owner:off") and plan.has("bo_old"):
		plan["bo"] = plan["bo_old"]          # (crown-owner-eco off: the 0.30.8 opening and milestones, for "before" games)
		plan["mid"] = plan["mid_old"]
		plan.erase("owner")
		if strategy == "balanced":
			plan.erase("bo_brood")
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
	if wall_throttle() and _labs_queued() > 0 and _gold() < LAB_COST + WALL_LAB_KEEP:
		return false
	return not _army_due()


func _labs_queued() -> int:
	var n := 0
	for h in _halls():
		n += h.queue.count(_f()["worker"])
	return n


## THE NATURAL'S WALL ON TIME (crown-ai-v2, docs/crown_ai_v2.md; the QA tests' items 4 and 13: 10-28% of the natural's
## ways in shut 180 s after its hall stood, the ring not closed by 6:30): the palisade was planned at once and then lost
## every coin to the next labourer (gold 0-30 from 4:00 to 7:30 while the labourers went 14 -> 34). The owner's own game
## slowed his labourers while he laid his ring (26 at 4:00, 30 at 5:00, 32 at 6:00, the ring 3:49-5:42). So while a
## walled hall's plan has pieces to lay (AIExpandWall.keep: after the hall's first Farm, the owner's plans' wall time)
## and nothing more urgent stands (a rush defended, the army far behind), ONE labourer at a time is trained (a second
## only from gold over WALL_LAB_KEEP), and the wall's next pieces' gold is kept from the soldiers and the steps: the
## wall's batches (AIExpandWall._lay_pieces, laid first in the think) get the rest. (Every labourer held for the wall
## left 18 at 4:00 instead of 22+, test_crown_owner_eco.) Switch: `-- wallfirst:off`.
const WALL_LAB_KEEP := 60
var wall_first_on := not OS.get_cmdline_user_args().has("wallfirst:off")


func wall_first() -> bool:
	if not on or not wall_first_on or difficulty < 1 or xw == null or not xw.active() or not owner_on():
		return false
	if _defending() or army_lags():
		return false
	if game.workers(team).size() < WALL_FIRST_LABS and not _wall_hall_waited():
		return false            # (the labourers' ramp first, as the owner's: 26 at 4:00, then his ring)
	return xw.keep() > 0


## (crown-ai-v2) one hall's labourers: the owner's ring went down after his 26th labourer (3:49); a natural laid early (1:35
## in test_crown_owner_eco) waits for them or for WALL_FIRST_WAIT s after it stood. The labourers are slowed to one at a
## time only past WALL_FIRST_LABS (wall_throttle): before that the wall's gold is only kept from the soldiers and the steps
## (21 labourers at 4:00 instead of 22+ when they were slowed from the wait on, test_crown_owner_eco)
const WALL_FIRST_LABS := 22
const WALL_FIRST_WAIT := 100.0


func wall_throttle() -> bool:
	return game.workers(team).size() >= WALL_FIRST_LABS and wall_first()


func _wall_hall_waited() -> bool:
	for id in xw.plans:
		var p: Dictionary = xw.plans[id]
		if not p.get("ok", false):
			continue
		var bt := float(p.get("built_t", -1.0))
		if bt >= 0.0 and game.clock - bt >= WALL_FIRST_WAIT:
			return true
	return false


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
	if short and owner_labs(game.workers(team).size()):
		short = false           # (crown-owner-eco: labourers non-stop to two halls' worth; the Brood's reckoning below still counts)
	if not short and army_lags():
		short = true            # (ai-followups: far behind the enemy's army: the soldiers before more labourers)
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
	if i == 2 and mirror() != null:
		cm.raid_answer()        # (crown-v-crown-coach: a raider at the labourers with no soldier to meet it: Musketeers first)
	if i == 1:
		_owner_tick()           # (crown-owner-eco: the layout, the new hall's Farm, the wagons)
		_finish_sites()
		_lost_halls_crown()     # (crown-ai-v2: a hall lost is remembered, its ground waits)
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
	# (crown-ai-v2, THE NATURAL'S WALL ON TIME: the gold for its next pieces is out of reach of the steps, the soldiers and
	# the research too, as AI._hide_kept does after the opening; laid in stage 0 by xw.tick. Its Gate (50) never came out of
	# the 20-30 gold the other stages left, Cinder Steps)
	var wall_hold := 0
	if i != 0 and wall_first():
		wall_hold = clampi(xw.keep(), 0, int(game.players[team]["gold"]))
		game.players[team]["gold"] -= wall_hold
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
			if bo_army and (bo_army_cap <= 0 or _army_supply(game.army(team)) < bo_army_cap) and not _breeder_first():
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
	game.players[team]["gold"] += held + wall_hold


var _research_off := false


## THE RUSH TRAINS RIDERS, NOT A DRY MUSKETEER WHILE THE BREEDER GOES UP (crown-optimal-opening: OPTIMAL's punish trained
## a Musketeer with no powder at 1:54, 60 gold short of a labourer, before its Horse Breeder stood): no soldiers in the
## Rush's opening until a Horse Breeder stands, unless a rush is being defended.
func _breeder_first() -> bool:
	return strategy == "rush" and opening == "breeder" and not _def_on and not _mine("horse_breeder").any(func(b: Building) -> bool: return b.built)


## Labourers in the opening: every hall keeps one coming while the gold left after the plan's reserve pays for it.
func _bo_labs() -> void:
	var labs := game.workers(team).size()
	var queued := 0
	for h in _halls():
		queued += h.queue.count(_f()["worker"])
	var free := _gold() - bo_reserve
	if _soldiers_first():
		return
	var wall_keep := WALL_LAB_KEEP if wall_throttle() else 0
	var top := mini(bo_lab_cap, owner_lab_cap())      # (the owner's plans: never past the halls' saturation)
	for h in _halls():
		if not h.built or labs + queued >= top or free < LAB_COST + (wall_keep if queued > 0 else 0):
			continue      # (crown-ai-v2: while the natural's palisade comes first, one labourer at a time, above)
		if h.queue.size() >= (2 if free >= 3 * LAB_COST + wall_keep else 1):
			continue
		if game.train(h, _f()["worker"]) == "":
			queued += 1
			free -= LAB_COST


## The opening: the supply first, then the next step; its gold is set aside until it can be paid.
func _bo_tick() -> void:
	if _defending() and not _def_on:
		_def_on = true
		_bo_defence()
	elif not _def_on and not _safe_on and _safe_reason() != "":
		_safe_on = true
		_bo_safe()
	if _attacking and not _bo_after_attack():
		_bo_end("the first attack is out")
		return
	if game.clock >= BO_LIMIT:
		_bo_end("time: %d steps of %d done" % [bo_i, _bo_plan.size()])
		return
	if _halls().filter(func(h: Building) -> bool: return h.built).is_empty():
		return
	bo_reserve = 0
	if owner_on():
		# (crown-owner-eco: the Cottages ahead of the supply, and a Farm at a new hall at once, before the next step)
		if _supply_ahead() and _sup_want > 0:
			bo_reserve = _sup_want
			return
		var hf := _hall_farm()
		if hf > 0:
			bo_reserve = hf
			return
	if _supply_due():
		var c := int(Defs.BUILDINGS["cottage"]["cost"])
		if _gold() >= c:
			_construct("cottage")
			if _mine("cottage").any(func(b: Building) -> bool: return not b.built):
				_bo_log("a Cottage (supply %d/%d)" % [game.supply_used(team), int(game.players[team]["cap"])])
				return
		bo_reserve = c
		return
	_bo_replace_dropped()
	while bo_i < _bo_plan.size():
		var st: Dictionary = _bo_plan[bo_i]
		if _st_done(st):
			_bo_next(st)
			continue
		if _bo_stalled(st):
			continue                # (moved to the back or dropped: the next step goes on)
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
			_step_t = -1.0
			continue
		return
	_bo_end("the build order is done")


## THE OPENING GOES ON PAST THE RAID (crown-optimal-opening: OPTIMAL's punish of a greedy Brood, PLANS["rush"]["bo_opt"]):
## when the riders are out and a hall or build step waits behind the attack step, the opening passes the attack and lays
## them; the labourers come first again. False when none is left (the attack ends the opening, as before).
func _bo_after_attack() -> bool:
	if strategy != "rush" or _opened_from != "optimal":
		return false
	if not _bo_plan.slice(bo_i).any(func(st: Dictionary) -> bool: return String(st["do"]) in ["hall", "build"] and not _st_done(st)):
		return false
	if not _raid_out:
		_raid_out = true
		bo_army_first = false       # (no more riders before labourers: the hall's gold; the raid's losses are made good)
		bo_army_cap = maxi(_army_supply(game.army(team)), 1)
		say("the riders are out: the second hall right behind the raid")
	return true


var _raid_out := false


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
	_step_t = -1.0
	# (ai-optimal story audit: it said "the wall, the Barracks and the Mill first" when all three stood already)
	var names: Array = ins.map(func(st: Dictionary) -> String: return "the wall" if String(st["do"]).begins_with("wall") else "the %s" % String(Defs.BUILDINGS[st["k"]]["name"]))
	var uniq: Array = []
	for n in names:
		if not uniq.has(n):
			uniq.append(n)
	say("a rush is scouted: %ssoldiers before labourers, no new hall till it is held" % ((", ".join(uniq) + " first, ") if not uniq.is_empty() else ""))


## THE BALANCED PLAN PLAYS SAFE ON A BLIND LOOK (crown-owner-eco): the owner's plans build no Barracks without a reason;
## on Balanced a first look at the enemy that saw nothing of its army or economy ("could not see the enemy": the scout's
## verdict "uncertain") before SAFE_BY is one (a Brood rush keeps its Raptors out of sight till 1:13; the Economy plan takes
## that risk). The Barracks and the Mill come next and the soldiers from then on; no soldiers-first, the hall still comes.
const SAFE_BY := 200.0
const LOOK_WAIT := 100.0         # (s) a step waiting for the scout's first look goes by then anyway
var _safe_on := false


func _safe_reason() -> String:
	if not owner_on() or strategy != "balanced" or scout == null or game.clock > SAFE_BY or not _mine("barracks").is_empty():
		return ""
	if scout.verdict == "uncertain" and not scout.absence_on:
		return "the scout could not see the enemy's army or economy"     # (ai-optimal: no longer: no army for nothing)
	return ""


func _bo_safe() -> void:
	var ins: Array = []
	for st in [{"do": "build", "k": "barracks"}, {"do": "build", "k": "powder_mill"}]:
		if not _st_done(st):
			ins.append(st)
	for k in ins.size():
		_bo_plan.insert(bo_i + k, ins[k])
	bo_army = true
	_step_t = -1.0
	say("plays safe (%s): the Barracks and the Mill next, then Musketeers" % _safe_reason())


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
	if String(st["do"]) == "build":
		_bo_built.append(st)    # (watched: a site dropped before it began brings its step back, _bo_replace_dropped)
	bo_i += 1
	_step_t = -1.0


## A STEP NEVER BLOCKS THE PLAN (owner's log 2026-11-05, Red Coast 0.31.0: the Foundry step was laid at 4:13, its builder
## was pulled into a fight with a Brood grub a second later, the site was dropped "nobody was coming" and refunded; the
## Horse Breeder step behind it waited for "has Foundry" for ever, so the opening never ended: no milestones, no more
## Barracks, the army capped at 6 supply, labourers to 68 and 3,400 gold in the bank at 9:00). Now:
##  - a build step whose site was dropped before it began comes back (BO_REPLACE times a kind at most);
##  - a step that has waited STEP_STALL s with the gold for it in the bank (a trigger it cannot reach, a "has" building
##    that is not there, no room, no builder) goes to the back of the plan once, then is dropped; it is logged once.
const STEP_STALL := 45.0
const BO_REPLACE := 3
var _bo_built: Array = []        # build steps done (their site was laid): watched until their building began
var _bo_replaced := {}           # kind -> times its step came back
var _bo_moved := {}              # step (its text) -> true: it went to the back once already
var _step_t := -1.0              # (clock) the current step could go from (-1: it cannot go now)
var bo_stalls: Array = []        # [clock, step text, what happened] (tests, the coach)


func _bo_replace_dropped() -> void:
	for st in _bo_built.duplicate():
		var k := String(st["k"])
		if _st_done(st):
			if _mine(k).all(func(b: Building) -> bool: return b.built or b.progress > 0.0 or not b.ghost):
				_bo_built.erase(st)     # (begun: no longer at risk of being dropped)
			continue
		_bo_built.erase(st)
		if int(_bo_replaced.get(k, 0)) >= BO_REPLACE:
			continue
		_bo_replaced[k] = int(_bo_replaced.get(k, 0)) + 1
		var again: Dictionary = st.duplicate(true)
		again.erase("at")           # (its trigger was met already: at once)
		_bo_plan.insert(bo_i, again)
		_step_t = -1.0
		bo_stalls.append([game.clock, _st_text(st), "site dropped: again"])
		say("the %s site was dropped before it began: step %d comes back" % [String(Defs.BUILDINGS[k]["name"]), bo_i + 1])


## A trigger the step can never meet as things stand: a "has" building with none standing or going up and no step before
## it to make one, or more labourers than the halls' saturation lets it train (owner_lab_cap).
func _st_never(st: Dictionary) -> bool:
	var at: Dictionary = st.get("at", {})
	if at.has("has") and _mine(String(at["has"])).is_empty():
		var made := false
		for k in range(bo_i, _bo_plan.size()):
			var o: Dictionary = _bo_plan[k]
			if o == st:
				break
			if String(o["do"]) == "build" and String(o.get("k", "")) == String(at["has"]):
				made = true
		return not made
	if at.has("labs") and int(at["labs"]) > owner_lab_cap():
		return true
	return false


## (the stall clock runs only while the step could go: its trigger met, or a trigger it can never meet, and its gold in
## the bank; a step waiting for its labourers or its gold is not stalled)
func _bo_stalled(st: Dictionary) -> bool:
	if String(st["do"]) in ["attack", "army", "labs", "pick"]:
		return false            # (the attack has its own call-off, ATTACK_WAIT; OPTIMAL's pick waits for the read and keeps
		# no gold: the labourers and the Cottages spend it meanwhile; it was "Optimal waited 45 s with the gold in the bank" at
		# 1:29, moved to the back, crown-optimal-opening; AIOptimal.tick plays a normal game if no read comes by DECIDE_BY)
	var could := _gold() >= _st_price(st) and (_st_ready(st) or _st_never(st))
	if not could:
		_step_t = -1.0
		return false
	if _step_t < 0.0:
		_step_t = game.clock
	if game.clock - _step_t < STEP_STALL:
		return false
	var txt := _st_text(st)
	_step_t = -1.0
	_bo_plan.remove_at(bo_i)
	if _bo_moved.has(txt):
		bo_stalls.append([game.clock, txt, "dropped"])
		say("step %s dropped: it waited %d s with the gold in the bank (the milestones see to it)" % [txt, int(STEP_STALL)])
		return true
	_bo_moved[txt] = true
	_bo_plan.append(st)
	bo_stalls.append([game.clock, txt, "to the back"])
	_step_t = -1.0
	say("step %s waited %d s with the gold in the bank: the next steps first, it is tried again later" % [txt, int(STEP_STALL)])
	return true


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
	if owner_on():
		return false            # (crown-owner-eco: _bo_tick calls _supply_ahead itself)
	var cap: int = game.players[team]["cap"]
	if cap >= game.max_supply(team) or _mine("cottage").is_empty():
		return false            # (the first Cottage is the ramp's: a step of its own)
	if _busy_building("cottage"):
		return false
	return cap - game.supply_used(team) <= _supply_margin()       # (crown-optimal-opening: the same lead as _supply_ahead)


# ------------------------------------------------------------------ the steps

func _st_text(st: Dictionary) -> String:
	if String(st["do"]) == "balloons":
		return "balloon %d" % int(st.get("n", 1))
	if String(st["do"]) == "pick":
		return "OPTIMAL's pick: %s" % String(STRATEGIES[strategy]["name"])
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
	if String(st["do"]) == "pick":
		return opt == null or strategy != "optimal"      # (OPTIMAL has picked: the build's steps follow)
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
	if at.has("halls") and _halls().size() < int(at["halls"]):
		return false            # (crown-owner-eco: the Barracks after the second hall is laid)
	if at.has("look") and scout != null and scout.verdict == "pending" and game.clock < LOOK_WAIT:
		return false            # (crown-owner-eco: after the scout's first look)
	return true


## The trigger is a moment away: its gold is set aside already (the hall trains a labourer every 12 s).
func _st_near(st: Dictionary) -> bool:
	var at: Dictionary = st.get("at", {})
	if at.has("army") or at.has("has"):
		return false
	if at.has("halls") and _halls().size() < int(at["halls"]):
		return false
	if at.has("look") and scout != null and scout.verdict == "pending" and game.clock < LOOK_WAIT:
		return false
	if String(st["do"]) == "hall" and _hall_waits_gun():
		return false            # (the gun's gold is not set aside for the hall)
	if String(st["do"]) == "hall" and _defending():
		return false            # (crown-owner-eco: no hall's gold kept from the soldiers while a rush is feared)
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
	if String(st["do"]) == "pick":
		return "wait"
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
		if _res2() > want * 2.0 or (mirror() != null and cm.farms_starved(_res2())):
			_mill_n = maxi(mills, mini(_mill_n, crew) - 1)      # (crown-v-crown-coach: farms_starved, the mirror only)
		elif _res2() < want:
			_mill_n = mini(6 * mills, maxi(_mill_n, crew) + 1)
	return clampi(_mill_n, mills, 6 * mills)


## No new hall while the enemy's army is at our buildings or clearly bigger than ours on our side of the map (coached game
## a01, Red Coast 6:36: the third hall was laid 35 tiles out during the Brood's attack, its guards walked out to it and
## died; the hall was dropped). A dry main still goes (the shared rule's "urgent").
func _hall_first() -> bool:
	if not on or not bo_done or difficulty < 1 or _halls().size() < 2:
		return super()
	if not owner_hall_ok():
		# (crown-owner-eco: the third hall when the two are full, not at a labourer count of 16 a hall: his third at 8:15 with
		# 42 labourers on two halls; the computer's at 5:50 with 33 took the army's gold and was the first lost)
		_hall_reserve = false
		_saving = false
		return false
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


## NO HALL INTO THE ENEMY THAT JUST TOOK ONE (crown-ai-v2, docs/crown_ai_v2.md; the QA study's item 3: the beaten Crown
## laid a new hall on the spot it had just lost while the enemy was still there, seven times, and lost the site too:
## Amberfall Vale built hall lost 11:25, new sites lost 12:55 and 13:40; 60 hall sites lost in 152 games). Design rule 2
## (anti-snowball: a lost base must not become a lost game): every hall of ours that disappears (built, or a site razed)
## is noted (AI.note_lost_site: its spot waits LOST_HALL_WAIT s and the ground round it counts as the enemy's); the
## Crown's own pick leaves anything within LOST_NEAR tiles of it while it waits, and after that only takes it with no
## enemy soldier in sight there. And it keeps the gold to REBUILD ONCE: with one hall left and that hall in danger (a fight
## at it), no new expansion is laid: the gold stays for the main if it falls. Switch: `-- lostwait:off`.
var lost_wait_on := not OS.get_cmdline_user_args().has("lostwait:off")
var _hall_ids := {}             # instance id -> [cell, built] of every hall of ours (built or a site) last think
var lost_halls := 0             # (tests, the study) halls of ours lost (built or sites)


func _lost_halls_crown() -> void:
	if not on or not lost_wait_on:
		return
	var now := {}
	for h in game.halls_of(team, false):
		now[h.get_instance_id()] = [h.cell, h.built]
	for id in _hall_ids:
		if now.has(id):
			continue
		var b = instance_from_id(id)
		if b != null and is_instance_valid(b) and not (b as Building).dead:
			continue
		var c: Vector2i = _hall_ids[id][0]
		if bool(_hall_ids[id][1]) or _site_was_hit(c):
			note_lost_site(c)
			lost_halls += 1
			_last_lost_t = game.clock
			if game.mlog:
				game.mlog.add("%s lost a Town Hall%s at %s: that ground waits %d s and then only with no enemy there" % [
					game.mlog.who(team), "" if bool(_hall_ids[id][1]) else " (unfinished)", str(c), int(LOST_HALL_WAIT)])
	_hall_ids = now


## An unfinished hall that vanished: razed by the enemy, or given up because raiders chased its builders off (both say
## the enemy holds that ground: Frostmere, a site given up at 9:50 was laid again and lost at 13:35); only a site dropped
## because the ground stayed blocked (AI.site_failed "blocked") is no loss.
func _site_was_hit(c: Vector2i) -> bool:
	return not (_bad_sites.has(c) and float((_bad_sites[c] as Array)[1]) > game.clock)


## A hall spot by ground we lost lately: no until the wait is over (LOST_HALL_WAIT), then only with no enemy soldier seen
## near it (LOST_NEAR tiles).
func lost_ground(c: Vector2i) -> bool:
	if not lost_wait_on:
		return false
	var cc := Vector2(c) + Vector2(MapGen.HALL) * 0.5
	for l in _lost_spots:
		if cc.distance_to(Vector2(l) + Vector2(MapGen.HALL) * 0.5) < LOST_NEAR:
			if float(_lost_spots[l]) > game.clock:
				return true
	return false


## An armed enemy soldier in sight within 14 tiles of a hall spot (the Crown's own pick checks this too).
func _foe_at_site(c: Vector2i) -> bool:
	var cc := (Vector2(c) + Vector2(MapGen.HALL) * 0.5) * float(Defs.TILE)
	for u in game.units_near(cc, 14.0 * Defs.TILE):
		if game.hostile(u.team, team) and not u.dead and not u.is_worker() and u.has_attack() and game.is_visible_to(team, u.position):
			return true
	return false


## THE ARMY BEFORE THE NEXT HALL AFTER A LOSS: a hall lost lately (LOST_HALL_WAIT) while the army is far behind the
## enemy's it reckons (under LAG_SHARE of foe_reckon, the Brood's foe_estimate): no new hall, the gold goes to the army (Frostmere v the Clockwork: after
## its natural fell at 8:50 the Crown laid four more sites on four spots in five minutes and lost every one).
var _last_lost_t := -999.0


func _beaten_back() -> bool:
	if game.clock - _last_lost_t > LOST_HALL_WAIT or game.halls_of(team, false).is_empty():
		return false
	var est: float = foe_estimate() if _foe_is("brood") else foe_reckon()
	return est > 0.0 and float(game.army_value(team)) < est * LAG_SHARE


## REBUILD ONCE: one hall left and a fight at it: no new expansion while it lasts.
func rebuild_keep() -> bool:
	if not lost_wait_on or lost_halls == 0:
		return false
	var hs := game.halls_of(team, false)
	if hs.size() != 1:
		return false
	return _foe_at_site((hs[0] as Building).cell)


func _safe_hall_spot() -> Vector2i:
	if not owner_hall_ok():
		return Vector2i(-1, -1)     # (crown-owner-eco: the shared bank's hall waits too)
	if on and rebuild_keep():
		return Vector2i(-1, -1)     # (crown-ai-v2: the last hall is in a fight: its gold stays to rebuild once)
	if not on or not sites_on or difficulty < 1 or not doctrine():
		return super()
	var mids: Array = []
	for h in _halls():
		mids.append(h.center() / float(Defs.TILE))
	if mids.is_empty():
		return super()
	_cs_prep()
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
		if lost_ground(c):
			return false        # (crown-ai-v2: ground where a hall of ours was just lost)
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


## The walks from the mains (ours, the enemies') over the bare land, once a game.
func _cs_prep() -> void:
	if _cs_steps.is_empty():
		var foes: Array = []
		for o in game.enemies_of(team):
			if game.starts.size() > o:
				foes.append(ExpansionSpots._steps(game, game.starts[o]))
		_cs_steps = [ExpansionSpots._steps(game, game.starts[team]), foes]


const CS_WARM_US := 3000        # (µs) the hall pick's work ahead on a quiet tick
var _cs_warm_done := -1         # (the ground's change count when it was last all measured)

## THE HALL PICK WORKED AHEAD (0.30.5, the owner's 0.30.4 log: the 2nd hall pick was a 586 ms frame): on a tick with no
## think part to run, a few ms of CrownSites.warm (the cliff edge, the walks, the old natural, the 2nd and 3rd candidates'
## rooms, best first), so _safe_hall_spot finds them measured. The same picks: a pick measures anything missing itself.
func _cs_warm() -> void:
	if not on or not sites_on or difficulty < 1 or not doctrine() or _halls().size() > 2:
		return
	if _cs_warm_done == game.solid_log.size():
		return
	if _cs_steps.is_empty():
		_cs_prep()          # (a tick of its own)
		return
	if CrownSites.warm(game, team, _cs_field, _cs_steps, CS_WARM_US):
		_cs_warm_done = game.solid_log.size()


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
	var fstep := false
	for k in range(bo_i, _bo_plan.size()):
		var st: Dictionary = _bo_plan[k]
		if String(st["do"]) == "build" and String(st["k"]) == "foundry":
			fstep = true            # (the plan has its own Foundry step before the Breeder: not a second one)
		if String(st["do"]) == "build" and String(st["k"]) == "horse_breeder":
			if fstep:
				_bo_plan[k]["at"] = {"has": "foundry"}
			elif _mine("foundry").is_empty():
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
	if on and lost_wait_on and kind == String(_f()["hall"]) and at.x >= 0 and (lost_ground(at) or rebuild_keep() or _foe_at_site(at) or _beaten_back()):
		# (crown-ai-v2: every hall path comes here, the shared ones too (_more_halls' ground round a hall, the natural's
		# spot): not on ground where a hall was just lost, nor while the last hall is in a fight. The Border March game
		# laid its hall site twice more on the spot it lost at 13:25, through _more_halls' find_spot)
		lost_refused += 1
		return
	super(kind, at)


var lost_refused := 0           # (tests, the study) hall sites refused on lost ground


## A PRODUCTION OR ECONOMY SITE NOBODY IS COMING TO (Game.sweep_ghosts asks): its builder was pulled off (the owner's Red
## Coast log: the Foundry's labourer was sent at a Brood grub a second after it was laid, and the site was dropped): the
## nearest free labourer takes it up, SITE_ADOPT times at most, unless enemies stand there (then it goes, refunded).
const SITE_ADOPT := 3
const ADOPT_KINDS := ["barracks", "foundry", "horse_breeder", "armoury", "church", "powder_mill", "farm"]


func adopt_site(b: Building) -> bool:
	if super(b):
		return true
	if not on or peaceful or difficulty < 1 or not ADOPT_KINDS.has(b.kind):
		return false
	var id := b.get_instance_id()
	if int(_adopted.get(id, 0)) >= SITE_ADOPT or _unsafe(b.center()):
		return false
	var best: Unit = null
	var bd := INF
	for u in game.workers(team):
		if u.dead or u.order == "build" or u.order == "attack" or _escort.has(u) or (scout != null and scout.is_scout(u)) or _held_worker(u):
			continue
		var dd: float = u.position.distance_to(b.center()) + (150.0 if u.carrying > 0 else 0.0)
		if dd < bd:
			bd = dd
			best = u
	if best == null:
		return false
	_adopted[id] = int(_adopted.get(id, 0)) + 1
	best.give({"o": "build", "e": b})
	if game.mlog and int(_adopted[id]) == 1:
		game.mlog.add("%s sends another Labourer to its %s site (its builder was pulled away)" % [game.mlog.who(team), String(b.d["name"])])
	return true


## A BEGUN BUILDING NOBODY WORKS ON ANY MORE (its builder fled, fought or died) is finished: the nearest free labourer
## goes back to it, unless enemies stand there. A Crown building only grows while a Labourer works on it, and a half-built
## Foundry or Barracks held the milestones and the production scaling back for good (they wait while one "is going up":
## Red Coast v the Clockwork, 0.31.0 tests: a Foundry begun at 5:04 still unfinished when it was razed at 8:55).
const FINISH_AFTER := 6.0        # (s) a begun site left alone this long gets a labourer
var _alone := {}                 # building id -> clock it was first seen with nobody on it
var finish_log: Array = []       # [clock, kind] (tests)


func _finish_sites() -> void:
	if not on or peaceful or difficulty < 1:
		return
	var sent := 0
	for b in game.buildings:
		if b.team != team or b.dead or b.built or b.ghost or Defs.BUILDINGS[b.kind].get("line", false):
			continue
		var id: int = b.get_instance_id()
		var worked := false
		for u in game.workers(team):
			if not u.dead and u.order == "build" and u.order_target == b:
				worked = true
				break
		if worked:
			_alone.erase(id)
			continue
		if not _alone.has(id):
			_alone[id] = game.clock
			continue
		if game.clock - float(_alone[id]) < FINISH_AFTER or sent >= 2 or _unsafe(b.center()):
			continue
		var best: Unit = null
		var bd := INF
		for u in game.workers(team):
			if u.dead or u.order == "build" or u.order == "attack" or _escort.has(u) or (scout != null and scout.is_scout(u)) or _held_worker(u) or _fled.has(u):
				continue
			var dd: float = u.position.distance_to(b.center()) + (150.0 if u.carrying > 0 else 0.0)
			if dd < bd:
				bd = dd
				best = u
		if best == null:
			return
		best.cmd_build(b)
		_alone.erase(id)
		sent += 1
		finish_log.append([game.clock, b.kind])
		if game.mlog:
			game.mlog.add("%s sends a Labourer to finish its %s (nobody was working on it)" % [game.mlog.who(team), String(b.d["name"])])


## MASS CANNONS FIRST (crown-hold, the owner 2026-11-06: "probably 3 to 4 cannon before mortar"): a Foundry and a Horse
## Breeder stand, the line has GUN_LINE_FIRST Musketeers, fewer than CANNONS_FIRST Field Cannons are out or queued and the
## enemy is not at home: the tech milestones (Church, Armoury...) wait for the guns' gold (production does not), as the
## Barracks do (AI._produce). `-- gunmass:off` plays without it.
var gun_mass := not OS.get_cmdline_user_args().has("gunmass:off")


func guns_short() -> bool:
	if not gun_mass or difficulty < 1 or not _gun_can() or _threat() != Vector2.INF:
		return false
	var cannons := 0
	var muskets := 0
	for u in game.army(team):
		if u.kind == "cannon":
			cannons += 1
		elif Defs.MUSKETS.has(u.kind):
			muskets += 1
	for f in _mine("foundry"):
		cannons += f.queue.count("cannon")
	return cannons < CANNONS_FIRST and muskets >= GUN_LINE_FIRST


## (AICrownHold.wants_rider asks: against the Brood with the cannon first, the rider waits for the first gun)
func rider_waits() -> bool:
	return _gun_waiting()


# ------------------------------------------------------------------ after the opening: the milestones

func _build_up() -> void:
	super()
	if not _plan_tech() or _hall_reserve or (_cw_active() and not _walled):
		return
	_mid_tick()


var _mid_fail := {}             # milestone kind -> clock it first could not be placed (logged once)


func _mid_tick() -> void:
	var gun_hold := gun_saves and _gun_waiting() and _gun_can()
	var guns_short := guns_short()
	if gun_hold and not owner_on():
		return                  # (the first Field Cannon's gold first: CANNONS AGAINST THE BROOD)
	var labs := game.workers(team).size()
	var halls := _halls().filter(func(h: Building) -> bool: return h.built).size()
	var army := _army_supply(game.army(team))
	if _threat_prod(labs, halls, army):
		return
	var lags := army_lags(labs)
	for m in plan.get("mid", []):
		var k := String(m[0])
		if _mine(k).size() >= int(m[1]):
			continue
		if (gun_hold or guns_short) and not (k == "barracks" or k == "foundry" or k == "horse_breeder"):
			continue
		if lags and not _mid_ok_lagging(k):
			continue            # (ai-followups: the army far behind: no tech, and no more Barracks than the gold keeps busy)            # (crown-owner-eco: the gun's gold holds the tech back, not the production; crown-hold: the
			# first AI.CANNONS_FIRST Field Cannons too)
		var at: Dictionary = m[2]
		if labs < int(at.get("labs", 0)) or halls < int(at.get("halls", 0)) or army < int(at.get("army", 0)):
			continue
		if not game.requirement_met(team, k) or _busy_building(k):
			continue
		var cost := int(Defs.BUILDINGS[k]["cost"])
		if _gold() < cost:
			_reserve = maxi(_reserve, cost)     # (the milestone's gold: the soldiers wait for it once the army has its minimum)
			return
		var n0 := _mine(k).size() + _mine("foundry").size()
		_construct(k)
		if _mine(k).size() + _mine("foundry").size() > n0:
			say("milestone: %s %d (%d labourers, %d halls, army %d supply)" % [String(Defs.BUILDINGS[k]["name"]), int(m[1]), labs, halls, army])
			return
		# (no spot or no builder now: the next milestone is not held up by it, it is tried again next think)
		if not _mid_fail.has(k):
			_mid_fail[k] = game.clock
			say("milestone %s %d could not be placed now: the next ones go on" % [String(Defs.BUILDINGS[k]["name"]), int(m[1])])
	if not gun_hold:
		_scale_prod()           # (crown-owner-eco: every milestone up: more production as the income grows)


## (ai-followups) While the army lags the enemy's (army_lags): the Church, the Armoury and the like wait; a Barracks or a
## Foundry only when every one of its kind standing is busy (one idle means the gold, not the buildings, is short) or the
## bank holds LAG_BANK more than its price; the first Foundry and the Horse Breeder (the guns' horses) always.
const LAG_BANK := 150
var mid_held := 0               # (tests) milestones held back while the army lagged
var _mid_held_said := -99.0


func _mid_ok_lagging(k: String) -> bool:
	if k == "horse_breeder" or (k == "foundry" and _mine("foundry").is_empty()):
		return true
	if k == "barracks" or k == "foundry":
		# (its own kind all busy, or gold in the bank beyond its price: the buildings, not the gold, are short)
		if _mine(k).all(func(b: Building) -> bool: return b.built and not b.queue.is_empty()):
			return true
		if _gold() >= int(Defs.BUILDINGS[k]["cost"]) + LAG_BANK:
			return true
	mid_held += 1
	if game.clock - _mid_held_said > 60.0:
		_mid_held_said = game.clock
		say("milestone %s waits: the army is far behind the enemy's (%d against the %d it reckons)" % [String(Defs.BUILDINGS[k]["name"]), game.army_value(team), int(foe_reckon())])
	return false


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
	var quiet := _stage >= STAGES and _think - delta > 0.0     # (no think part runs this tick)
	super(delta)
	if dr != null and not game.over:
		dr.micro()
	if quiet and game != null and not game.over:
		var pt := Time.get_ticks_usec()
		_cs_warm()
		_lap("ai/sites_warm", pt)


func _raid() -> void:
	super()
	if dragoon_plan() and not peaceful:
		if dr == null:
			dr = DragoonRaid.new(self)
		dr.tick()


## (ai-followups) THE NATURAL'S WALL KEEPS ITS FEW COINS while the army comes first (army_lags): the soldiers took every coin
## and the palisade waited till 6:23 on the owner's seed (it was laid from 3:58 before): the line it should stand behind was
## not there when the Clockwork's first push came. WALL_KEEP gold is kept from the soldiers while a walled expansion's plan
## is under AICrownHold.GATE_CLOSED closed (a palisade piece costs 15, a gate 50).
## MEASURED AND LEFT OFF (study switch `-- wallkeep:on`): in 8 games against the Clockwork and the Brood the Crown's army at
## 8:00 was smaller with it (650 / 0 / 370 against 1,015 / 530 / 525 on Dune Sea, Greenhold, Red Coast v the Clockwork) and
## the line still met the first push without a gate post: the palisade it bought came too late either way.
const WALL_KEEP := 65
var wall_keep_on := OS.get_cmdline_user_args().has("wallkeep:on")


func _wall_keep() -> int:
	if not wall_keep_on or xw == null or not army_lags() or _threat() != Vector2.INF:
		return 0
	for id in xw.plans:
		var p: Dictionary = xw.plans[id]
		if not p.get("ok", false) or (p["exposed"] as Array).is_empty():
			continue
		var h = p.get("hall")
		if h == null or not is_instance_valid(h) or (h as Building).dead or not (h as Building).built:
			continue
		if xw.closed_share(p) < AICrownHold.GATE_CLOSED:
			return clampi(WALL_KEEP, 0, int(game.players[team]["gold"]))
	return 0


func _produce() -> void:
	var wk := _wall_keep()
	game.players[team]["gold"] -= wk
	_produce_crown()
	game.players[team]["gold"] += wk


func _produce_crown() -> void:
	if siege != null:
		siege.produce()           # (the guns first: the shared training adds one now and then)
		var keep: int = clampi(siege.gun_due(), 0, int(game.players[team]["gold"]))
		game.players[team]["gold"] -= keep
		super._produce()
		game.players[team]["gold"] += keep
		return
	if not dragoon_plan():
		super._produce()
		return
	var short := _train_dragoons()
	# (the riders short: a Dragoon's gold, horse and all, is kept from the line's Musketeers, unless the enemy is at home)
	var held := 0
	if short and _threat() == Vector2.INF:
		held = clampi(DRAGOON_KEEP, 0, int(game.players[team]["gold"]))
	game.players[team]["gold"] -= held
	super._produce()
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
		if b.built and b.queue.size() < 2 and game.can_train(b, "dragoon") == "" and am.musket_ok(b, "dragoon"):
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
	# (crown-ai-v2: not the opening's step gold: the wall is laid in the opening's think stage 0, where that gold is out of
	# reach already (_think_stage `held`); counted twice it kept 60 + twice a hall's 400 from every piece, so the natural's
	# palisade waited for the opening to end: 10-28% shut 180 s after the hall stood, test_ai_expand_wall)
	var k := 0
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


# ------------------------------------------------------------------ THE OWNER'S ECONOMY (crown-owner-eco)
## The owner's own Crown game (docs/playtests/2026-11-04/human_crown_v_brood_brute_siege_highmoor_0308.txt, Highmoor, Hard
## Brood Brute siege; docs/crown_owner_eco.md): "First we need a better Crown AI ... play my way." On the Economy and
## Balanced plans (PLANS[...]["owner"]), Normal and up; `-- owner:off` plays as 0.30.8:
##  - no Barracks on a timer: the opening's Barracks comes after the second hall (the plans) or when the scout sees a rush
##    (_bo_defence), and no wall slot of the new hall takes a Barracks before that (slot_barracks_ok);
##  - A FARM AT EVERY NEW HALL AT ONCE (_hall_farm): its gold set aside as the hall nears completion, laid the moment it
##    stands (his 3:01 farm at the 2:46 hall; the computer's new hall waited 3:52 -> 5:14);
##  - COTTAGES AHEAD OF THE SUPPLY (_supply_ahead): as many going up at once as the production eats in the time one takes
##    to build, so it is never blocked with gold in the bank (his own mistake: 105-114/126 for two minutes, 2,600 unspent);
##  - THE NATURAL'S PALISADE RING by 4-6 minutes in every matchup (owner_walls: the Brood rule of AIExpandWall, a minute
##    after the hall stands; his ring went down 3:49-5:42);
##  - PRODUCTION SCALED TO THE INCOME (_scale_prod): Barracks (a Foundry every few) while what they can spend is under the
##    gold coming in (his 3 Barracks by 5:19, 6 by 6:53, 13 by 11:12 on ~1,500 gold a minute); research from the bank;
##  - THE BASE LAYOUT (scripts/ai_crown_layout.gd): Cottages packed at the back edge, production in rows with lanes, farms
##    and the Mill by their hall;
##  - Powder Wagons spread out at home, never parked together (his four blew up in a chain at 15:20).
const AICrownLayout := preload("res://scripts/ai_crown_layout.gd")
var owner_off := OS.get_cmdline_user_args().has("owner:off")
var layout_off := OS.get_cmdline_user_args().has("layout:off")
var lay = null                   # AICrownLayout (made on the first think)
var hall_farm_log: Array = []    # [hall stood at, farm laid at] (tests, the coach)
var _hall_farm_seen := {}        # hall id -> clock it stood
var supply_log: Array = []       # [clock, cottages going up at once] when two or more were started together (the coach)
var prod_log: Array = []         # [clock, kind, income a minute, what the production can spend a minute]
const HALL_FARM_NEAR := 0.8      # a hall this far built: its Farm's gold is set aside already
const SUPPLY_LEAD := 26.0        # (s) a Cottage's build (20 s) and its builder's walk: the supply ahead covers this long
const SUPPLY_MAX_AT_ONCE := 4
const PROD_SPEND := {"barracks": 240.0, "foundry": 320.0}      # gold a minute one keeps busy (a Musketeer 60 / 15 s; a gun 170 / 32 s)
const PROD_SHARE := 0.85         # production for this share of the gold coming in (the rest: labourers, buildings, research)
const PROD_FOUNDRY_EVERY := 5    # a Foundry for every so many Barracks
const PROD_MAX_BARRACKS := 14
const OWNER_SCOUT_AT := 2.0      # (s) the first scout leaves (AIScout.START_AT 18 on the other plans)
const OWNER_HALL3_LABS := 40     # labourers on two halls before the third (two halls' posts: 4 Farms of 8, 2 Mills of 6 = 44)
const OWNER_HALL3_SOIL := 0.35   # ... or the best soil under this


## THE NEXT HALL WHEN THE HALLS ARE FULL AND THE ARMY CAN HOLD THEM (the owner's third at 8:15 with 42 labourers and 29
## Musketeers, his fourth at 12:25; the computer's at 5:50 and 7:30 took the army's gold and were the first lost): from the
## third hall on, OWNER_HALL3_LABS labourers and an army of OWNER_HALL_ARMY times them, or the best soil under
## OWNER_HALL3_SOIL. The opening's second hall is not held.
const OWNER_HALL_ARMY := 0.7


func owner_hall_ok() -> bool:
	if not owner_on() or _halls().size() < 2:
		return true
	if _best_soil() < OWNER_HALL3_SOIL:
		return true
	var labs := game.workers(team).size()
	return labs >= OWNER_HALL3_LABS + 10 * (_halls().size() - 2) and _army_supply(game.army(team)) >= int(OWNER_HALL_ARMY * labs)


## LABOURERS NON-STOP up to two halls' worth (the owner's 38 at 7:00, 42 at 8:00): the shared holds that wait for the army
## first (AIRound5.hold_labourers against the Clockwork) let them come on the owner's plans, unless a rush is feared or the
## enemy is at our buildings.
func owner_labs(labs: int) -> bool:
	if army_lags(labs):
		return false            # (ai-followups: past one hall's hands, the army first while it is far behind the enemy's)
	return owner_on() and labs < mini(OWNER_HALL3_LABS, owner_lab_cap()) and not _defending() and _threat() == Vector2.INF


## THE ARMY CATCHES UP (ai-followups, the owner's Hard Crown OPTIMAL v Hard Clockwork game 0.33.0: 44 labourers and an army
## of 455 at 7:00 against the Clockwork's 31 Winders and 1,490; Barracks 2-4, a Church and an Armoury went up with "army 3-4
## supply"; it never sent a wave): once the second hall stands and LAG_LABS labourers work, the army must be worth LAG_SHARE
## of the enemy army it reckons (foe_reckon); while it is not, the labourers wait for the soldiers (the army's share of the
## spending rises), and the tech milestones wait (_mid_tick). Against the Brood the crown-v-brood reckoning does this.
const LAG_LABS := 22            # (one hall's farms and Mill hands, and a few builders)
const LAG_SHARE := 0.6
const LAG_FROM := 210.0         # (s) not before this (the opening's gold is the economy's)
var lag_off := OS.get_cmdline_user_args().has("armylag:off")     # (study switch: `-- armylag:off` plays as 0.33.0)
var lag_said := -99.0
var lag_time := 0.0             # (tests, the report) seconds the labourers and the tech waited for the army
var _lag_t := -1.0


func army_lags(labs := -1) -> bool:
	if lag_off or not on or difficulty < 1 or peaceful or _foe_is("brood") or game.clock < LAG_FROM:
		return false
	if labs < 0:
		labs = game.workers(team).size()
	if labs < LAG_LABS or _halls().filter(func(h: Building) -> bool: return h.built).size() < 2:
		return false
	var mine := float(game.army_value(team))
	var est := foe_reckon()
	var lags := est > 0.0 and mine < est * (LAG_PRESS if pressure() else LAG_SHARE)
	if lags:
		if _lag_t >= 0.0:
			lag_time += maxf(0.0, game.clock - _lag_t)
		_lag_t = game.clock
		if game.clock - lag_said > 60.0:
			lag_said = game.clock
			say("the army first: %d of army against the %d it reckons the enemy has (it wants %d%%): the labourers and the tech wait for the soldiers" % [int(mine), int(est), int(LAG_SHARE * 100.0)])
	else:
		_lag_t = -1.0
	return lags


## (ai-followups) The natural's wall is defence too: while the labourers wait for the army (army_lags) the expansion is not
## waited on to saturate before its palisade goes down (it would never saturate: AIExpandWall waited till 8:56 on Dune Sea).
func wall_sat() -> bool:
	if army_lags():
		return true
	return super()


## A GREEDY READ IS PRESSURE, NOT MORE LABOURERS (ai-followups: the owner's game read GREEDY at 1:38, picked Balanced "steady
## waves punish the greed" and had no army at 4:00 with 23 labourers): while OPTIMAL's last pick answered a GREEDY read with
## a plan that attacks (Balanced, Timing, the Horseman rush), the army keeps LAG_PRESS of the enemy's (not LAG_SHARE).
const LAG_PRESS := 0.9


func pressure() -> bool:
	if opt == null or (opt.picks as Array).is_empty():
		return false
	var last: Array = (opt.picks as Array)[-1]
	return String(last[2]) == "GREEDY" and String(last[3]) in ["balanced", "timing", "rush"]


## The enemy's army as reckoned for the army's share (not the Brood: foe_estimate): what it saw in the last two minutes,
## never less than LAG_TABLE of that age (the lowest a Hard Clockwork or Crown had in the coached games: the Clockwork 280
## at 4:00, 490 at 5:00, 840 at 6:00, 1,490 at 7:00 in the owner's game), less half of what we have killed.
const LAG_TABLE := {
	"clockwork": [[0.0, 0.0], [240.0, 150.0], [300.0, 350.0], [360.0, 600.0], [420.0, 950.0], [480.0, 1400.0], [600.0, 2300.0], [720.0, 3200.0]],
	"crown": [[0.0, 0.0], [240.0, 100.0], [300.0, 250.0], [360.0, 400.0], [420.0, 600.0], [480.0, 850.0], [600.0, 1300.0], [720.0, 1800.0]],
}


func foe_reckon() -> float:
	var known: float = ch.foe_known() if ch != null else 0.0
	var foe := _foe()
	if foe < 0:
		return known
	var tab: Array = LAG_TABLE.get(game.faction_of(foe), [])
	if tab.is_empty():
		return known
	var est := _lerp_table(tab, game.clock) - 0.5 * float(game.stats[team]["value_killed"])
	return maxf(known, est)


## LABOURERS STOP AT SATURATION (the owner, 2026-11-05: "Eventually you stop at a good number with base saturation: 2 bases
## saturated and a few haulers, maybe 45 to 50 labourers"; his log had 68 on two halls, 23 of them idle at 8:00): the
## posts of the halls' farms and Mills plus OWNER_SPARE_LABS (builders, haulers), SAT_PRETRAIN more while a hall is going
## up (its farms' hands trained ahead), and never over OWNER_LAB_MAX on two halls (OWNER_LAB_PER_HALL more a hall after).
const OWNER_SPARE_LABS := 4
const OWNER_LAB_MAX := 48
const OWNER_LAB_PER_HALL := 14
var lab_cap_off := OS.get_cmdline_user_args().has("labcap:off")


func owner_lab_cap() -> int:
	if not owner_on() or lab_cap_off:
		return 999
	var built := _halls().filter(func(h: Building) -> bool: return h.built).size()
	var going := _hall_reserve or _busy_building(_f()["hall"])
	var top := OWNER_LAB_MAX + OWNER_LAB_PER_HALL * maxi(0, built - 2) + (SAT_PRETRAIN if going and built >= 2 else 0)
	var cap := _posts() + OWNER_SPARE_LABS + (SAT_PRETRAIN if going else 0)
	return mini(cap, top)


func _lab_want(want: int) -> int:
	if not owner_on() or lab_cap_off:
		return want
	if difficulty < 2:
		return mini(want, owner_lab_cap())     # (Normal keeps its smaller economy)
	return owner_lab_cap()


func owner_on() -> bool:
	return on and not owner_off and difficulty >= 1 and bool(plan.get("owner", false))


func _layout_on() -> bool:
	return owner_on() and not layout_off


## (AIExpandWall._fill_slot asks) a wall slot of a new hall may take a Barracks: not in the owner's opening before its own
## Barracks step or a scouted rush ("why make a Barracks if you don't scout a rush?").
func slot_barracks_ok() -> bool:
	if not owner_on() or bo_done or not _mine("barracks").is_empty() or _defending():
		return true
	for k in range(bo_i, _bo_plan.size()):
		var st: Dictionary = _bo_plan[k]
		if String(st["do"]) == "build" and String(st["k"]) == "barracks":
			return _st_ready(st)
	return true


## (AIExpandWall.brood_walls asks) the natural is walled at once in every matchup on the owner's plans, from a while after
## the hall stands (the labourers and the hall's Farm first: his ring went down a minute after the hall).
const OWNER_WALL_AFTER := 45.0


func owner_walls() -> bool:
	if not owner_on():
		return false
	for h in _halls():
		if h.built and float(_hall_farm_seen.get(h.get_instance_id(), 1e9)) + OWNER_WALL_AFTER <= game.clock:
			return true
	return false


## The main hall (nearest our start).
func main_hall() -> Building:
	var best: Building = null
	if game.starts.size() <= team:
		return null
	var st := Vector2(game.starts[team]) * Defs.TILE
	for h in _halls():
		if best == null or h.center().distance_to(st) < best.center().distance_to(st):
			best = h
	return best


func _farms_at(h: Building) -> int:
	var n := 0
	for f in _mine("farm"):
		if game.nearest_hall(f.center(), team) == h:
			n += 1
	return n


## A FARM AT EVERY NEW HALL AT ONCE. Returns the gold to set aside (0: nothing due).
func _hall_farm() -> int:
	if not owner_on() or game.econ_count(team, "farm") >= game.econ_limit(team, "farm"):
		return 0
	var cost := int(Defs.BUILDINGS["farm"]["cost"])
	for h in _halls():
		var id: int = h.get_instance_id()
		if h.built and not _hall_farm_seen.has(id):
			_hall_farm_seen[id] = game.clock
		if h == main_hall() or _land(h) < DRY_LAND or _farms_at(h) > 0:
			continue
		if not h.built:
			if h.progress >= HALL_FARM_NEAR:
				return cost      # (its gold kept while the last stretch goes up)
			continue
		if _gold() < cost:
			return cost
		var spot := Vector2i(-1, -1)
		if lay != null:
			spot = lay.econ_spot("farm", h)
		if spot.x < 0:
			spot = game.find_spot(team, "farm", h, 4, Defs.ECON_RANGE - 2, "behind", true)
		if spot.x < 0:
			spot = game.find_spot(team, "farm", h, 4, Defs.ECON_RANGE - 2, "behind")
		if spot.x < 0:
			continue
		var n0 := _mine("farm").size()
		_construct("farm", spot)
		if _mine("farm").size() > n0:
			hall_farm_log.append([float(_hall_farm_seen.get(id, game.clock)), game.clock])
			say("a Farm at its new hall at once (%d s after it stood)" % int(game.clock - float(_hall_farm_seen.get(id, game.clock))))
			return 0
		return cost
	return 0


## THE SUPPLY THE PRODUCTION EATS WHILE A COTTAGE GOES UP (SUPPLY_LEAD s), plus two: the halls' labourers, the Barracks'
## soldiers, the Breeder's Horsemen (3 supply in 22 s), the Foundry's guns. In the opening at least the old margin (two,
## two a Barracks, one a hall after the first), and only that while a rush is being held (_def_on). Every plan's opening uses it (crown-optimal-opening: the Siege push's
## opening was blocked at 18/18 at 3:00 in the owner's game, its Cottage laid at 15/18 and done at 3:03, the margin two
## a Barracks did not cover the 20 s build with the hall and the Barracks both training).
func _supply_margin() -> int:
	var rate := 0.0
	var nb := 0
	for b in _mine("barracks"):
		if b.built:
			rate += 1.0 / 15.0
			nb += 1
	for b in _mine("horse_breeder"):
		if b.built:
			rate += 3.0 / 22.0
	for b in _mine("foundry"):
		if b.built:
			rate += 4.0 / 32.0
	var nh := 0
	for h in _halls():
		if h.built:
			rate += 1.0 / 12.0
			nh += 1
	var margin := 2 + int(ceil(rate * SUPPLY_LEAD))
	if not bo_done:
		# (the opening's old margin is the floor: the gold of a Cottage too early is a Musketeer missing against a rush,
		# tools/test_ai_wall_vs_rush.gd)
		margin = maxi(margin, 2 + 2 * nb + nh - 1)
		if _def_on or _defending():
			# (ai-followups: against a rush in the opening the old margin alone: the rate's bigger lead kept a Cottage's
			# gold from the Musketeers, one Musketeer by 2:40 instead of three, tools/test_ai_wall_vs_rush.gd)
			margin = 2 + 2 * nb + nh - 1
	return margin


## COTTAGES AHEAD OF THE SUPPLY: the supply the production and the halls eat in SUPPLY_LEAD s, plus two; as many Cottages
## going up at once as that takes (SUPPLY_MAX_AT_ONCE at most). True when one was started or is wanted (its gold: `want`).
var _sup_want := 0


func _supply_ahead() -> bool:
	_sup_want = 0
	var cap: int = game.players[team]["cap"]
	var top: int = game.max_supply(team)
	if cap >= top or _mine("cottage").is_empty():
		return false
	var margin := _supply_margin()
	var going := _mine("cottage").filter(func(b: Building) -> bool: return not b.built).size()
	var ahead := cap + 8 * going
	if ahead - game.supply_used(team) > margin or ahead >= top or going >= SUPPLY_MAX_AT_ONCE:
		return false
	var cost := int(Defs.BUILDINGS["cottage"]["cost"])
	var started := 0
	while ahead - game.supply_used(team) <= margin and ahead < top and going < SUPPLY_MAX_AT_ONCE:
		if _gold() < cost:
			_sup_want = cost
			break
		var n0 := _mine("cottage").size()
		_construct("cottage")
		if _mine("cottage").size() <= n0:
			break
		going += 1
		started += 1
		ahead += 8
	if started >= 2:
		supply_log.append([game.clock, started])
	return started > 0 or _sup_want > 0


func _supply() -> void:
	if owner_on():
		_supply_ahead()
		return
	super()


## PRODUCTION SCALED TO THE INCOME (after the milestones): a Barracks (every PROD_FOUNDRY_EVERY-th time a Foundry) while what
## the production can spend a minute is under PROD_SHARE of the gold earned in the last minute and a half, every Barracks
## and Foundry is busy, and nothing else is going up.
var _inc_samples: Array = []     # [clock, gold earned so far]


func income() -> float:
	var earned := float(game.stats[team]["gold"])
	if _inc_samples.is_empty() or game.clock - float(_inc_samples[-1][0]) >= 5.0:
		_inc_samples.append([game.clock, earned])
	while _inc_samples.size() > 2 and game.clock - float(_inc_samples[1][0]) >= 90.0:
		_inc_samples.pop_front()
	var a: Array = _inc_samples[0]
	var dt := game.clock - float(a[0])
	if dt < 30.0:
		return 0.0
	return (earned - float(a[1])) * 60.0 / dt


const OWNER_BANK_HIGH := 700
const OWNER_BANK_WAIT := 15.0
var _rich_t := -1.0


func _rich() -> bool:
	if _gold() < OWNER_BANK_HIGH:
		_rich_t = -1.0
		return false
	if _rich_t < 0.0:
		_rich_t = game.clock
	return game.clock - _rich_t >= OWNER_BANK_WAIT


func _scale_prod() -> void:
	if not owner_on() or _hall_reserve or _saving:
		return
	var inc := income()
	if inc <= 0.0:
		return
	var nb := _mine("barracks").size()
	var nf := _mine("foundry").size()
	if nb == 0 or _busy_building("barracks") or _busy_building("foundry"):
		return
	var spend := nb * float(PROD_SPEND["barracks"]) + nf * float(PROD_SPEND["foundry"])
	# (labourers still coming: their gold is not the soldiers')
	var lab_spend := 0.0
	if game.workers(team).size() < mini(_posts(), owner_lab_cap()):
		lab_spend = 250.0 * _halls().filter(func(h: Building) -> bool: return h.built).size()
	# A BIG BANK IS SPENT (the owner's log, Red Coast 0.31.0: 3,000-3,400 gold from 9:00 on two halls): over OWNER_BANK_HIGH
	# for OWNER_BANK_WAIT s, more production whatever the income says
	var rich := _rich()
	if spend >= (inc - lab_spend) * PROD_SHARE and not rich:
		return
	var idle := false
	for b in _mine("barracks") + _mine("foundry"):
		if b.built and (b.queue as Array).is_empty():
			idle = true
	if idle and _gold() < 600:
		return                  # (a free Barracks with no gold to use it: more would idle too)
	var k := "foundry" if nb >= PROD_FOUNDRY_EVERY * nf else "barracks"
	if rich and _mine("church").is_empty() and game.requirement_met(team, "church") and nb >= 3:
		k = "church"            # (the bank's third sink after the Barracks and the Foundry)
	if k == "barracks" and nb >= PROD_MAX_BARRACKS:
		return
	if _gold() < int(Defs.BUILDINGS[k]["cost"]) + 60:
		return
	var n0 := _mine(k).size()
	_construct(k)
	if _mine(k).size() > n0:
		prod_log.append([game.clock, k, int(inc), int(spend)])
		say("more production: %s %d (income %d a minute, the production spends %d)" % [String(Defs.BUILDINGS[k]["name"]), _mine(k).size(), int(inc), int(spend)])


## BUILDINGS BY THE LAYOUT (scripts/ai_crown_layout.gd): a new hall's wall slot first (AIExpandWall), then the layout's
## slot for the kind, then the shared search. (AI._find_spot holds the spots that stayed blocked lately round this.)
func _find_spot_any(kind: String) -> Vector2i:
	if _layout_on() and lay != null:
		var xs: Vector2i = xw.slot_for(kind)
		if xs.x >= 0:
			return xs
		var sp: Vector2i = lay.slot(kind)
		if sp.x >= 0:
			return sp
	return super(kind)


func _econ_spot(kind: String) -> Vector2i:
	if _layout_on() and lay != null and (kind == "farm" or kind == "powder_mill"):
		var halls := _halls().filter(func(h: Building) -> bool: return h.built)
		if kind == "farm":
			halls.sort_custom(func(a: Building, b: Building) -> bool: return a.soil_left() > b.soil_left())
		else:
			halls.sort_custom(func(a: Building, b: Building) -> bool: return a.lode_left() > b.lode_left())
		for h in halls:
			var inside: Vector2i = xw.inside_spot(kind, h)
			if inside.x >= 0:
				return inside
			var sp: Vector2i = lay.econ_spot(kind, h)
			if sp.x >= 0:
				return sp
	return super(kind)


## The tech kept on the main's plateau (AI._keep_tech) is kept in the layout's next production slot instead.
func _keep_tech() -> void:
	if not _layout_on() or lay == null:
		super()
		return
	if _mine("barracks").is_empty():
		return
	if not game.ai_keep.has(team):
		game.ai_keep[team] = {}
	var keeps: Dictionary = game.ai_keep[team]
	for k in KEY_TECH:
		if not _mine(k).is_empty():
			keeps.erase(k)
			continue
		if keeps.has(k) and game.placement_problem(team, k, keeps[k]["cell"], true) == "":
			continue
		keeps.erase(k)
		var sp: Vector2i = lay.slot(k, true)
		if sp.x >= 0:
			keeps[k] = {"cell": sp, "t": game.clock}


## POWDER WAGONS SPREAD OUT (his four parked together blew up in a chain at 15:20 and took the army with them): at home
## each wagon stands by a different hall, WAGON_GAP apart at least, and never by the ramp post's line.
const WAGON_GAP := 6.0           # (tiles)


func _wagons() -> Array:
	var out: Array = []
	for u in game.units:
		if u.team == team and not u.dead and u.kind == "powder_wagon":
			out.append(u)
	return out


func _spread_wagons() -> void:
	var ws := _wagons()
	if ws.size() < 2 or _attacking:
		return
	var halls := _halls().filter(func(h: Building) -> bool: return h.built)
	if halls.is_empty():
		return
	var T := float(Defs.TILE)
	var taken: Array = []
	var k := 0
	for w in ws:
		if w == _wagon():
			taken.append(w.position)
			continue
		var h: Building = halls[(k + 1) % halls.size()]
		k += 1
		var spot: Vector2 = game.approach_point(h, h.center() + Vector2(0, 3 * T).rotated(float(k) * 2.1))
		for t in taken:
			if (t as Vector2).distance_to(spot) < WAGON_GAP * T:
				spot += ((spot - h.center()).normalized() if spot != h.center() else Vector2.RIGHT) * WAGON_GAP * T
		taken.append(spot)
		if w.position.distance_to(spot) > 60.0 and (w.order != "move" or w.order_point.distance_to(spot) > 60.0):
			w.cmd_move(spot)


## (stage 1 of the think, every plan on the owner's rules)
func _owner_tick() -> void:
	if not owner_on():
		return
	if lay == null and _layout_on():
		lay = AICrownLayout.new(self)
	if lay != null:
		lay.tick()
	if bo_done:
		_hall_farm()
		_spread_wagons()
