class_name AIBroodNew
extends AI
## THE BROOD'S COMPUTER (scripts/brood_new.gd, docs/brood_new.md; the only Brood since 0.18.0). Rewritten in 0.22.0 from
## the coached games of docs/brood_new_play_3.md (how it plays, its profiles and its numbers: docs/brood_ai.md):
##  - a BUILD ORDER per profile (PLANS: Extreme rush, Rush, Timing attack, Balanced, Economy, Air rush): when the Tyrant
##    Sire's lure goes down, how many grubs, when the Mother grows, when the Venom and Storm Sires come, how far it
##    expands (Mound Turtles on new ground), when it researches what, and when it attacks with what;
##  - the Mother stays rooted at home and grows on time (food saved for it, spoils kept for her stage 3); she gets up only
##    to fight off an attack at her nest (BroodNew.mother_guard);
##  - the STRUCTURE-UNITS come from grubs (scripts/brood_root.gd): Mound Turtles for supply ahead of need round her, and
##    on NEW GROUND for expansions (the best turtle spots, ExpansionSpots.nb_pick) with Rootmaws following them; the
##    Sires through their lures beside her (the Storm Sire first when the enemy has flyers);
##  - grubs: enough to crew the rooted Rootmaws, never more than the plan's cap;
##  - warriors by the lines it has (Raptors, Brutes; Spitters, Mist Toads; Hatchlings only against flyers it has SEEN);
##    young MATURE into Challengers when food piles up or before a push; spoils come from bodies (HARVEST) and from
##    SACRIFICE of spare Raptors at home, only for what they are wanted for;
##  - research in an order (Bigger Clutch early, Pack Hunt before the first attack, Battering Horns before sieges,
##    Quick Roots mid game...);
##  - a SCOUT (a grub, later a Raptor) looks at the enemy's base; what it and every creature sees is remembered (the fog
##    of war: Game.is_visible_to): an early army or fast riders = RUSH evidence (it holds its army at home, delays its
##    growth and lays warriors), enemy flyers = the Storm Sire first, a wall = Brutes and Battering Horns;
##  - DEFENCE AS A SWARM (0.25.27, docs/brood_ai_swarm.md): the army at home HOLDS at a rally (no fights picked by
##    sight); enemies at home get a squad sized to them, sent all at once (the Tyrant Sire for a small harass with no
##    warriors to spare, everything near her at the Mother); too strong away from her, the army falls back to her side;
##    the Mother gets up only for a real reason (_nb_mother_up); a rooted Rootmaw struck uproots and bites back or backs
##    off, then roots again (_nb_maw_guard); a wave out is called home when the attack at her is big;
##  - WAVES: the army gathers at a staging point on the way, attacks together, the new hatched join only in groups, and
##    it RETREATS when the fight is lost (what it sees against what it has); Hatchlings stay home unless the enemy flies.
## No cheating: it knows where the enemy started (as every computer does) and otherwise only what its creatures see.

var _nb_think := 0.0
var _wave: Array = []
var plan := {}                   # this game's build order: PLANS[strategy] + `over` (tools set `over` to coach it)
var over := {}                   # (tools/play_brood_3.gd, tools/measure_brood_ai.gd: settings forced for a coached game)
var note: Array = []             # [clock, text] of what it decided (tests and tools read it)
var held: Array = []             # creatures it leaves alone (a coach's hand orders: tools/play_brood_3.gd)

## THE PROFILES (docs/brood_ai.md has the timelines; docs/ai_build_timelines.md the table). Times in game seconds.
##  sire_g / sire_t   the Tyrant Sire's lure goes down with this many grubs, or at this time (and 2 Rootmaws)
##  grubs0            grubs held at this many until the first wave has left (0: no hold)
##  grubs             the most grubs at any time
##  maws              Rootmaws wanted: [base, one more every N s, at most]
##  grow              [stage 2 from, stage 3 from]: food saved for it from then on
##  venom / storm     the Venom / Storm Sire's lure from this time (needs 3 Rootmaws; the Storm Sire needs stage 2)
##  far               [[time, how many far turtles by then], ...] (expansions on new ground)
##  wave / wave_t     first attack: this much army supply, not before wave_t; step: each next wave this much more
##  pack              Pack Hunt before the first attack (it waits for it once it has the army)
##  mix               warrior mix: "tyrant" (Raptors, Brutes), "venom" (Spitters ahead), "mixed"
##  mature            mature young into Challengers: "push" (before a wave), "bank" (food piling up), "" (never early)
##  home_guard        Raptors kept home when a wave leaves (after the first)
##  drone             grubs a minute on the curve that comes before warriors (from the 5 it starts with)
##  maws0 / ahead0    a rush: Rootmaws before the first wave; supply kept ahead for it (the turtle right after the Sire)
##  eco               the owner's economic build (2026-10-30, docs/brood_eco.md): the natural first, far Rootmaws, grubs
##                    nonstop, her growth when eggs hold it back, the watching grub and the alarm
##  spoils_bank       spoils kept wanted (Raptors laid and offered up for them): the Air rush's Storm line
##  storm_want        Hatchlings kept to mature into Storm Challengers
##  edge              a wave goes only with this share of the biggest enemy army seen lately (0.6; 0.3 against the
##                    Clockwork), or at the supply cap
## Settings only a tool or a coach sets (tools/play_brood_3.gd): "sire_leads" (a Sire walks with the waves:
## "dilophosaurus" was the owner's good idea, the Tyrant Sire a bad one), "storm_want" (Hatchlings kept to mature into
## Storm Challengers), "mother_free" (the computer leaves its Mother alone: the coach's Mother rush).
const PLANS := {
	"xrush": {"drone": 0.0, "sire_g": 5, "sire_t": 0.0, "grubs0": 6, "maws0": 1, "ahead0": 7, "grubs": 26, "maws": [2, 150.0, 6], "grow": [420.0, 780.0],
		"venom": 600.0, "storm": 900.0, "far": [[240.0, 1], [420.0, 2]], "wave": 8, "wave_t": 0.0, "step": 4, "pack": false,
		"mix": "tyrant", "mature": "bank", "home_guard": 0},
	"rush": {"drone": 3.0, "sire_g": 7, "sire_t": 40.0, "grubs0": 9, "maws0": 2, "grubs": 28, "maws": [2, 120.0, 7], "grow": [330.0, 660.0],
		"venom": 330.0, "storm": 720.0, "far": [[270.0, 1], [420.0, 2], [600.0, 3]], "wave": 10, "wave_t": 0.0, "step": 6, "pack": false,
		"mix": "tyrant", "mature": "bank", "home_guard": 2},
	"timing": {"drone": 6.0, "sire_g": 11, "sire_t": 120.0, "grubs0": 0, "grubs": 46, "maws": [2, 90.0, 8], "grow": [210.0, 540.0],
		"venom": 420.0, "storm": 660.0, "far": [[0.0, 1], [360.0, 2]], "eco": true, "wave": 24, "wave_t": 330.0, "step": 10, "pack": true,
		"mix": "tyrant", "mature": "push", "home_guard": 3},
	"balanced": {"drone": 7.0, "sire_g": 13, "sire_t": 150.0, "grubs0": 0, "grubs": 54, "maws": [2, 80.0, 10], "grow": [240.0, 480.0],
		"venom": 360.0, "storm": 540.0, "far": [[0.0, 1], [300.0, 2], [540.0, 3]], "eco": true, "wave": 22, "wave_t": 390.0, "step": 10, "pack": true,
		"mix": "mixed", "mature": "push", "home_guard": 3},
	"economy": {"drone": 8.0, "sire_g": 14, "sire_t": 165.0, "grubs0": 0, "grubs": 58, "maws": [2, 70.0, 11], "grow": [200.0, 420.0],
		"venom": 420.0, "storm": 480.0, "far": [[0.0, 1], [240.0, 2], [480.0, 3]], "eco": true, "wave": 34, "wave_t": 510.0, "step": 12,
		"pack": true, "mix": "venom", "mature": "push", "home_guard": 4},
	"air": {"drone": 6.0, "sire_g": 11, "sire_t": 110.0, "grubs0": 0, "grubs": 44, "maws": [2, 85.0, 9], "grow": [180.0, 420.0],
		"venom": 600.0, "storm": 150.0, "far": [[0.0, 1], [360.0, 2]], "eco": true, "spoils_bank": 120.0, "storm_want": 8, "wave": 18, "wave_t": 420.0, "step": 8, "pack": false,
		"mix": "tyrant", "mature": "push", "home_guard": 3},
	# THE WRITTEN BUILDS (brood-builds, scripts/ai_brood_builds.gd, docs/brood_builds.md): "build" names the push of its own.
	# SPITTER TIMING: the Venom Sire right after the Tyrant Sire, Spitters ahead (one a Raptor), the line's Bigger Clutch and
	# Long Spit, the timing at 6:30 once 10 Spitters stand; the economy grows behind it (an eco plan: grubs on the curve,
	# the natural and new ground)
	"spitter": {"drone": 7.0, "sire_g": 12, "sire_t": 140.0, "grubs0": 0, "grubs": 50, "maws": [2, 80.0, 10], "grow": [240.0, 540.0],
		"venom": 210.0, "storm": 660.0, "far": [[0.0, 1], [300.0, 2], [540.0, 3]], "eco": true, "wave": 22, "wave_t": 390.0, "step": 8, "pack": false,
		"mix": "venom", "mature": "push", "home_guard": 3, "build": "spitter"},
	# BRUTE SIEGE: her stage 3 early (Brutes need it), 4 Brutes and Battering Horns, then the push breaks the wall or the
	# turret line in the way and the army goes in through the breach
	"brute": {"drone": 7.0, "sire_g": 12, "sire_t": 140.0, "grubs0": 0, "grubs": 50, "maws": [2, 80.0, 10], "grow": [190.0, 360.0], "grow_now": true,
		"venom": 300.0, "storm": 720.0, "far": [[0.0, 1], [300.0, 2], [540.0, 3]], "eco": true, "wave": 28, "wave_t": 450.0, "step": 10, "pack": false,
		"mix": "mixed", "mature": "push", "home_guard": 3, "build": "brute", "brutes": 6},
}
## The written build's push (scripts/ai_brood_builds.gd), when this game's plan has one ("build").
const BroodBuilds := preload("res://scripts/ai_brood_builds.gd")
var bb = null                    # (an AIBroodBuilds, or null)


## (a computer made by hand, as the tests do, has its plan from the start: Balanced until it is told otherwise)
func _init() -> void:
	_make_plan()


func _ready() -> void:
	if not strategies_for("brood").has(strategy):
		strategy = "balanced"
	if strategy == "optimal":
		# OPTIMAL (scripts/ai_optimal.gd): the common opening is Balanced's economy (the natural, grubs on the curve), a grub
		# into the enemy's main early, then it picks its build from what it sees
		strategy = "balanced"
		opt = AIOptimal.new(self, "balanced")
	_opened = strategy
	_make_plan()
	if game.mlog:
		game.mlog.add("%s plays the Brood (%s)" % [game.mlog.who(team), STRATEGIES.get(plan_key(), STRATEGIES["balanced"])["name"]])
	if opt != null:
		say("OPTIMAL: the common opening (Balanced's economy), a grub into the enemy's main early, then it picks its build from what it sees")


## OPTIMAL's pick: the next think makes the build's plan (_nb_think_stage: `strategy != _plan_of`); its times run from the
## game's clock, so what is already past comes at once.
func opt_switch(k: String) -> bool:
	if not PLANS.has(k):
		return false
	strategy = k
	_opened = k
	return true


## This game's plan: the profile, eased by the level (Easy is slower and smaller), then what a tool forced (`over`).
var _plan_of := ""               # (the strategy the plan was made for: a tool or test that sets `strategy` later gets its plan)


func _make_plan() -> void:
	_plan_of = strategy
	plan = (PLANS.get(strategy, PLANS["balanced"]) as Dictionary).duplicate(true)
	if difficulty == 0:
		plan["wave_t"] = float(plan["wave_t"]) + 120.0
		plan["grubs"] = int(plan["grubs"]) - 6
		plan["grow"] = [float(plan["grow"][0]) + 90.0, float(plan["grow"][1]) + 150.0]
		plan["pack"] = false
	# against the Clockwork, steady Raptor pressure from about 5:00 (round 3: g20 traded 11,020 for 4,345 with small early
	# waves of Pack Hunt Raptors; holding home for a big army only let the richer Clockwork grow): smaller, earlier waves
	if game == null:
		_attack_at = int(plan["wave"])
		return
	if _foe_is("crown") and String(plan["mix"]) == "tyrant" and not strategy in ["xrush", "rush"]:
		plan["mix"] = "mixed"          # (the Crown walls its ramp: claws alone never go in, the wall rule waits for Spitters)
	if _foe_is("clockwork") and plan.has("build"):
		plan["edge"] = 0.4            # (the written builds keep their own timing against the Clockwork's bigger early army)
	elif _foe_is("clockwork") and not strategy in ["xrush", "rush"]:
		plan["wave"] = mini(int(plan["wave"]), 14)
		plan["wave_t"] = minf(float(plan["wave_t"]), 300.0 if difficulty > 0 else 420.0)
		plan["step"] = mini(int(plan["step"]), 4)
		plan["edge"] = 0.3
		plan["pack"] = false          # (Pack Hunt comes when it comes: the waves don't wait for it)
		plan["grubs"] = mini(int(plan["grubs"]), 44)      # (brood-eco: 54 grubs earned more against the Crown, but against the
		                                                  # Clockwork's early army the extra grubs were an army it lacked)
	for k in over:
		plan[k] = over[k]
	_attack_at = int(plan["wave"])
	if plan.has("build"):
		if bb == null or bb.kind != String(plan["build"]):
			bb = BroodBuilds.new(self, String(plan["build"]))
	else:
		bb = null


func say(s: String) -> void:
	note.append([game.clock, s])
	if game.mlog:
		game.mlog.add("%s's Brood: %s" % [game.mlog.who(team), s])


func _tick_ai(delta: float) -> void:
	if game == null or game.over:
		return
	_nb_think -= delta
	if _nb_stage < NB_STAGES:
		_nb_think_stage(_nb_stage)      # (a think goes on over the next ticks, a part each: docs/perf_armies.md)
		_nb_stage += 1
		return
	if _nb_think > 0.0:
		return
	_nb_think = [1.6, 1.0, 0.6, 0.4][clampi(difficulty, 0, 3)]
	if opt != null:
		opt.tick()
	_nb_think_stage(0)
	_nb_stage = 1


## A think in parts on consecutive physics ticks, as the other computers' (AI._think_stage): in one tick a late-game think
## made a long frame every 0.4 s (126 ms a second in the owner's Cinder Steps log, 2026-11-03). Each part sees what the
## parts before it did, in the same order as before.
const NB_STAGES := 4
var _nb_stage := NB_STAGES


func _nb_think_stage(i: int) -> void:
	var _pb := Time.get_ticks_usec()
	if i == 0 and strategy != _plan_of and PLANS.has(strategy):
		var aa := _attack_at
		_make_plan()
		_attack_at = mini(aa, _attack_at) if aa > 0 else _attack_at
	var q := BroodNew.queen(game, team)
	if q == null:
		_nb_stage = NB_STAGES
		return
	match i:
		0:
			_lap_nb("observe", _nb_observe.bind(q))
			if int(q.nb.get("eggs", 0)) <= EGG_LOW and float(q.nb.get("grow_t", 0.0)) <= 0.0:
				_egg_low_t = game.clock          # (her clutch run down: eggs hold the Brood back, _nb_grow_time)
			_lap_nb("root_watch", _nb_root_watch)
			if difficulty >= 1:
				_lap_nb("scout", _nb_scout.bind(q))
			_lap_nb("mother", _nb_mother.bind(q))
			_lap_nb("grow", _nb_grow.bind(q))
		1:
			_lap_nb("maw_guard", _nb_maw_guard.bind(q))
			_lap_nb("rootmaws", _nb_rootmaws.bind(q))
			_lap_nb("turtles", _nb_turtles.bind(q))
			_lap_nb("unstick", _nb_unstick.bind(q))
			_lap_nb("grubs_vs_riders", _nb_grubs_vs_riders.bind(q))
			if _eco():
				_lap_nb("alarm", _nb_alarm.bind(q))
		2:
			_lap_nb("father", _nb_father.bind(q))
			_lap_nb("morphs", _nb_morphs.bind(q))
			_lap_nb("lay", _nb_lay.bind(q))
			_lap_nb("essence", _nb_essence.bind(q))
		3:
			_lap_nb("mature", _nb_mature.bind(q))
			_lap_nb("research", _nb_research.bind(q))
			_lap_nb("army", _nb_army.bind(q))
			if difficulty >= 1:
				_spells()           # (the Mist Toads' FOG and TONGUE, as the old Brood's computer: AI._toad)
	Prof.add("ai/brood", _pb)


## One part of the think, timed for the match log's lag lines (ai/brood/<part>).
func _lap_nb(part: String, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	f.call()
	Prof.add("ai/brood/" + part, t0)


func in_wave(u: Unit) -> bool:
	return _attacking and _wave.has(u)


func _nb_mine(k: String) -> Array:
	return game.units.filter(func(u: Unit) -> bool: return u.team == team and not u.dead and u.kind == k)


func _food() -> int:
	return int(game.players[team]["gold"])


func _spoils() -> float:
	return float(game.players[team]["res2"])


# ------------------------------------------------------------------ what it knows of the enemy (the fog of war)

## What its creatures have SEEN (Game.is_visible_to): the enemy's flyers, its army's value (the most seen lately, fading),
## fast riders early (rush evidence), a wall, where its buildings stand. Never what it can't see.
var seen_air := 0               # the most enemy flyers seen at once lately
var _air_t := -999.0
var seen_army := 0.0            # the biggest enemy army value seen lately (fades)
var seen_wall := false
var riders_n := 0               # the most fast enemy riders (Horsemen...) seen at once lately (is_rider)
var riders_t := -999.0          # when riders were last seen
var rush_seen := ""             # rush evidence: what was seen ("" = none)
var rush_t := -1.0
var _rush_v := 0.0                # (the biggest enemy army seen since the rush evidence)
var _foe_blds := {}             # enemy building -> its centre (seen standing)
var _foe_near_home := 0.0       # enemy army value seen near the Mother now
var _obs_t := 0.0
const ALARM_FOR := 75.0
var alarm_t := -999.0              # when the alarm was last seen (an army out of the enemy's main)
var alarm_at := Vector2.ZERO       # where it was seen


func _alarm_on() -> bool:
	return game.clock - alarm_t < ALARM_FOR


## THE OWNER'S BUILD, its brake: grubs nonstop, but never with an army far smaller than the enemy army its creatures saw
## lately (the watching grub in the Clockwork's main sees it gather). In the first games of this round the Brood had 40
## grubs and no army at 7:00, and a Clockwork army of 2,000 took its Tyrant Sire and a third of its grubs. Warriors
## first (with 16 grubs or more) while its army is under this share of what it saw (0.7 against the Clockwork, which
## comes early; 0.3 against the others).
func _under_armed() -> bool:
	if not _eco() or game.clock < 150.0:
		return false
	var need := seen_army * (0.7 if _foe_is("clockwork") else 0.3) if seen_army >= 200.0 else 0.0
	if _foe_is("clockwork"):
		# (brood-ai-tune, round B g08/g10: a rush turned Balanced grew 6 to 47 grubs with 3 Raptors from 3:00 to 8:00, its
		# watching grub saw little of the Clockwork army gathering in its main, and 1,600 of Clock Soldiers took the
		# Mother. What every player knows of the Clockwork's tempo is a floor: 2 of army a second from 2:00, up to 800)
		need = maxf(need, clampf((game.clock - 120.0) * 2.0, 0.0, 800.0))
	elif _foe_is("crown"):
		need = maxf(need, clampf((game.clock - 180.0) * 0.8, 0.0, 500.0))      # (round D g07: 3 Raptors from 4:00 to 8:00
		                                                                          # while the Crown's army grew in its main)
	return need > 0.0 and _value_of(_nb_army_units()) < need


func _nb_observe(q: Unit) -> void:
	if game.clock - _obs_t < 1.0:
		return
	var dt := game.clock - _obs_t
	_obs_t = game.clock
	seen_army = maxf(0.0, seen_army - dt * 1.0)        # (fades: 60 a minute)
	var air := 0
	var val := 0.0
	var out := 0.0                  # (value seen OUT of the enemy's own base: an army on the move)
	var home := 0.0
	var fast := 0
	var fast_home := 0
	var foe := _foe()
	var fst: Vector2 = (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE if foe >= 0 else Vector2.INF
	var past := 0.0                 # (value seen past the foot of its ramp: an army that has left its main)
	var past_at := Vector2.ZERO
	var riders_now := 0
	var fast_riders := 0            # (brood-anti-riders: the fast ones out of its base that are riders)
	var riders_out := 0             # (riders past the foot of the enemy's ramp: out of its main, on the road)
	var riders_land := 0            # (riders in its own land: by the Mother, a rooted creature or its grubs)
	var horses := 0
	var home_foot := 0.0            # (the army near the Mother less its riders)
	var out_r := 22.0 * Defs.TILE
	if _foot != Vector2.INF and fst != Vector2.INF:
		out_r = minf(out_r, _foot.distance_to(fst) + 3.0 * Defs.TILE)
	for u in game.units:
		if u.dead or u.off_field or u.team < 0 or not game.hostile(u.team, team) or not game.is_visible_to(team, u.position):
			continue
		if u.kind == "horse":
			horses += 1             # (brood-anti-riders: horses early are riders to come)
		if u.is_worker() or u.kind == "horse" or u.kind == "messenger" or not u.has_attack() or u.kind == BroodNew.EGG:
			continue
		if u._k_nb and (u.kind == BroodNew.QUEEN or BroodNew.rooted(u)):
			_foe_nb_seen[u] = true          # (the enemy Brood's "buildings": the read counts them, _nb_read)
			continue
		var v := float(Game.unit_value(u))
		val += v
		var away: bool = fst == Vector2.INF or u.position.distance_to(fst) > 22.0 * Defs.TILE
		if away:
			out += v
		if (fst == Vector2.INF or u.position.distance_to(fst) > out_r) and not is_rider(u):
			past += v               # (riders: the rider read and the rider defence, not the alarm: brood-anti-riders)
			past_at += u.position * v
		if u.is_air():
			air += 1
		if float(u.d.get("speed", 0)) >= 95.0 and not u.is_air() and away:
			fast += 1
			if is_rider(u):
				fast_riders += 1
		elif float(u.d.get("speed", 0)) >= 95.0 and not u.is_air() and game.clock < 150.0 and not is_rider(u):
			fast_home += 1          # (ai-optimal: fast warriors already at its base this early: a rush getting ready)
		if is_rider(u):
			riders_now += 1
			_rider_seen[u] = game.clock
			if fst == Vector2.INF or u.position.distance_to(fst) > out_r:
				riders_out += 1
			if _in_my_land(q, u.position):
				riders_land += 1
		if u.position.distance_to(_qp(q)) < 24.0 * Defs.TILE:
			home += v
			if not is_rider(u) and u.kind != "dismounted":
				home_foot += v          # (an Officer is a Horseman off his horse: the riders' business, not a rush)
	_foe_near_home = home
	if _attacking and not _explore_cands.is_empty():
		_nb_mark_explored()          # (the wave sweeping for what is left: what it passes counts as looked at)
	if riders_now > 0:
		riders_n = maxi(riders_n if game.clock - riders_t < 180.0 else 0, riders_now)
		riders_t = game.clock
	seen_army = maxf(seen_army, val)
	if air > 0:
		seen_air = maxi(seen_air, air)
		_air_t = game.clock
	elif game.clock - _air_t > 180.0:
		seen_air = 0
	for b in game.buildings:
		if b.dead or not game.hostile(b.team, team) or b.ghost or _foe_blds.has(b):
			continue
		if game.is_visible_to(team, b.center()):
			_foe_blds[b] = b.center()
			if b.kind in ["wall", "gate", "palisade"]:
				seen_wall = true
	for b in _foe_blds.keys():
		if not is_instance_valid(b) or b.dead:
			_foe_blds.erase(b)
	# THE ALARM (the owner's build: the watching grub sees an attack coming): an army out of the enemy's main, big
	# enough to hurt (200, and 40% of its own army), at any time: for ALARM_FOR s it lays warriors, holds its army at
	# home (gathered at the natural), pulls the grubs back from Rootmaws the enemy comes near and roots a Mound Turtle in
	# front of the natural (_nb_alarm)
	if _eco() and past >= 200.0 and past >= _value_of(_nb_army_units()) * 0.4 and not _attacking:
		if game.clock - alarm_t > ALARM_FOR:
			say("ALARM: an enemy army of %d out of its main at %s: warriors, grubs pulled back, a turtle in front" % [int(past), _mmss()])
		alarm_t = game.clock
		alarm_at = past_at / past
	_nb_riders_seen(riders_now, riders_out, riders_land, horses)
	_nb_read(fst)
	# rush evidence (before 4:30; what it saw OUT of the enemy's base: an army in its own base is no rush): fast riders
	# in numbers, an army near home, or a big army on the move very early
	if rush_seen == "" and game.clock < 270.0:
		var why := ""
		if fast - fast_riders >= 2:
			why = "%d fast riders seen at %s" % [fast, _mmss()]      # (riders alone: the rider read below, brood-anti-riders)
		elif fast_home >= 2:
			why = "%d fast warriors at its base at %s" % [fast_home, _mmss()]
		elif home_foot >= 150.0:
			why = "an army (%d) near the Mother at %s" % [int(home_foot), _mmss()]
		elif out >= 300.0 and game.clock < 210.0:
			why = "an army of %d on the move at %s" % [int(out), _mmss()]
		if why != "":
			rush_seen = why
			rush_t = game.clock
			_rush_v = seen_army
			say("rush evidence: %s: holds its army at home and lays warriors" % why)


## THE READ (ai-optimal, scripts/ai_read.gd): what its creatures saw of the enemy, read as GREEDY / NORMAL / AGGRESSIVE /
## DEFENSIVE (the Brood has no AIScout; UNKNOWN is simply no read yet). Once a second, a new read at most every
## READ_GAP s (a rush at once). A fixed plan keeps its identity (its rush evidence already defends: _rush_on); OPTIMAL
## picks its build from it (AIOptimal.on_read).
const READ_GAP := 75.0
var read := "pending"           # AIScout's verdict keys: rush, greedy, balanced, defensive
var read_t := -999.0
var read_saw := ""
var reads: Array = []           # [clock, verdict, saw]
var _foe_nb_seen := {}          # enemy Brood rooted creature or Mother -> true
var _base_seen_t := -1.0        # when the enemy's start was first in sight


func _nb_read(fst: Vector2) -> void:
	if difficulty < 1 or peaceful or fst == Vector2.INF:
		return
	var foe := _foe()
	if foe < 0:
		return
	if _base_seen_t < 0.0 and game.is_visible_to(team, fst):
		_base_seen_t = game.clock
	var hall_kind: String = game.faction_hall(foe)
	var halls := 0
	var exp_seen := 0
	var mil := 0
	var defs := 0
	for b in _foe_blds.keys():
		if not is_instance_valid(b) or b.dead:
			continue
		if b.kind == hall_kind:
			halls += 1
			if b.center().distance_to(fst) > 8.0 * Defs.TILE:
				exp_seen += 1           # (a hall away from its start: an expansion, its main seen or not)
		elif AIScout.MILITARY.has(b.kind):
			mil += 1
		elif AIRead.DEFENCES.has(b.kind):
			defs += 1
	if game.faction_of(foe) != "brood":
		halls = maxi(halls, 1 + exp_seen)     # (its main stands whether it was seen or not; the Brood's Mother counts below)
	var fq := BroodNew.queen(game, foe)
	for nu in _foe_nb_seen.keys():
		if not is_instance_valid(nu) or nu.dead:
			_foe_nb_seen.erase(nu)
			continue
		if nu.kind == BroodNew.QUEEN:
			halls += 1
		elif BroodNew.is_father(nu.kind):
			mil += 1
		elif nu.kind == BroodNew.TURTLE:
			if fq != null and fq.position.distance_to(nu.position) >= float(Defs.NB["expansion_tiles"]) * Defs.TILE:
				halls += 1
		elif nu.kind != BroodNew.MAW and nu.has_attack():
			defs += 1
	var v := ""
	var seen := ""
	if _riders_on() and rider_read_t >= 0.0 and game.clock < RIDER_READ_BY and not _rider_over:
		v = "rush"
		seen = "a Horse Breeder or riders early"      # (brood-anti-riders: the rider read, _nb_riders_seen)
	elif _rush_on():
		v = "rush"
		seen = "fast rush units early" if rush_seen.contains("riders") or rush_seen.contains("warriors") else ("an army near its home" if rush_seen.contains("near") else "its army on the move early")
	elif defs >= 2 or (defs >= 1 and halls <= 1 and game.clock < 300.0):
		v = "defensive"
		seen = "turrets or rooted defenders"
	elif halls >= 2 and seen_army < 150.0 and mil <= 1:
		v = "greedy"
		seen = "a new base by its natural" if _base_seen_t < 0.0 else "a second base and little army"
	elif _base_seen_t >= 0.0 and mil == 0 and seen_army < 50.0:
		if game.clock < AIScout.GREEDY_ABSENT_FROM or game.clock - _base_seen_t < 6.0:
			return              # (its base only just in sight: a moment more before the absence says anything)
		v = "greedy"
		seen = "no army and no production at its base"
	elif _base_seen_t >= 0.0 or mil >= 1 or seen_army >= 50.0:
		v = "balanced"
		seen = "a standard opening"
	if v == "" or v == read:
		return
	if read != "pending" and game.clock - read_t < READ_GAP and v != "rush":
		return
	read = v
	read_t = game.clock
	read_saw = seen
	reads.append([game.clock, v, seen])
	var why := "%d halls, %d production, %d static defences, %d of army seen" % [halls, mil, defs, int(seen_army)]
	var head := "scouted: %s [%s] (%s)" % [AIRead.word(v), seen, why]
	var pname := String(STRATEGIES.get(strategy, STRATEGIES["balanced"])["name"])
	if opt != null:
		say("%s: OPTIMAL picks its build from this" % head)
	else:
		match v:
			"rush":
				say("%s: a rush is coming; defends first: its army home, warriors laid" % head)
			"greedy":
				say("%s: it is all economy; keeps to its %s plan" % [head, pname])
			"defensive":
				say("%s: it turtles; keeps to its %s plan" % [head, pname])
			_:
				say("%s: keeps to its %s plan" % [head, pname])
	on_read(v, seen)


## A fast enemy rider on the ground (a Horseman, a Cuirassier: speed 95 or more, melee): the Tyrant Sire (64) never
## catches one, so he is not sent after it (the owner's playtest 2026-11-03: "I was able to juke it"); grubs flee or gang
## up, Raptors and Spitters answer it (docs/raid_micro.md D).
static func is_rider(u: Unit) -> bool:
	return not u.is_air() and u.has_attack() and not u.is_worker() and float(u.d.get("speed", 0)) >= 95.0 \
		and float(u.d.get("range", 0)) < 100.0 and not u._k_nb


## Riders seen in the last 3 minutes (2 or more: a rider raid or rush).
func riders_about() -> bool:
	return riders_n >= 2 and game.clock - riders_t < 180.0


# ------------------------------------------------------------------ the Horseman rush (brood-anti-riders)

## THE RIDER READ AND THE RIDER DEFENCE (brood-anti-riders, docs/brood_anti_riders.md). The owner's Hollowfen game
## (2026-11-06, v0.33.3, his Horseman rush on the Hard Brood OPTIMAL): it read NORMAL one second before 3 riders hit it,
## pulled its Raptors behind the Mother and left its grubs in the field, sent 9 grubs at a Horseman, lost 25 creatures in a
## minute for 1 rider, then laid nothing but Raptors for three minutes (51 Raptors on 13 grubs). Now:
##  - THE READ comes from what its creatures see, before the riders arrive: an enemy Horse Breeder early with no Powder
##    Mill seen, a Horseman (or horses) at its base early, riders out of the enemy's main (the watching grub at the foot
##    of its ramp sees them leave). Not the generic rush evidence (no grub cap, no army held for three minutes).
##  - THE ANSWER while the riders are about (the read, or riders in its land): the Tyrant Sire's lure at once, Raptors
##    until its army at home beats the riders it expects on paper (_rider_need), then grubs again; grubs a rider comes
##    near run to the warriors (or the Mother) early, never at a rider unless they massively outnumber a lone hurt one;
##    the warriors GUARD the grubs (the threatened site when they win there clearly, else by the Mother) and bite only
##    riders that come at them, never chasing past a leash (a rider outruns a Raptor: 112 against 96); the Mother stays
##    rooted (her swamp feeds the Rootmaws round her) unless she is about to fall.
##  - THE RECOVERY: no rider in its land for RIDER_CALM s and the raid is over: the grubs go back to work and the
##    laying goes back to the plan.
var rider_read_t := -1.0         # when it read the riders (the read, or riders in its land first)
var rider_read := ""             # what it saw
var rider_read_first := -1.0     # (the study: its first rider read)
var _rider_seen := {}            # enemy rider -> when last seen
var _rider_land_t := -999.0      # riders last seen in its land
var _rider_out_t := -999.0       # riders last seen out of the enemy's main
var _rider_hit_t := -1.0         # riders first in its land (this raid)
var _rider_calm_said := true
var _rider_over := false         # (a raid met and over: the read of the rush is spent)
var _breeder_t := -1.0           # when it first saw an enemy Horse Breeder
var _mill_t := -1.0              # ... a Powder Mill
var _rider_guard := Vector2.INF  # where the warriors guard the grubs
var _rider_def_t := -99.0
var rider_raids := 0             # (the study: raids met)
const RIDER_READ_BY := 330.0     # a read of the riders before 5:30 (later riders are a raid, not a rush)
const RIDER_EARLY := 240.0       # one rider or a Horse Breeder before 4:00 is a rider opening
const RIDER_FOR := 180.0         # the read holds this long while no rider comes
const RIDER_CALM := 40.0         # no rider in its land this long: the raid is over
const RIDER_LAND_R := 10.0       # tiles from its Mother, a rooted creature or a grub: "in its land"
const RIDER_FLEE := 8.0          # tiles: grubs a rider comes this near run (5 outside a rider raid)
const RIDER_GUARD_R := 12.0      # tiles from the guard: riders the warriors go for
const RIDER_LEASH := 15.0        # tiles from the guard: no warrior chases farther
const RIDER_V := 115.0           # (a Horseman's value: the riders it expects before it has seen them all)
const RIDER_PRE := 0.5           # the share of the warriors wanted before the riders are seen coming


## Riders about: read and not come yet (RIDER_FOR s), or in its land lately.
func _riders_on() -> bool:
	if game.clock - _rider_land_t < RIDER_CALM:
		return true
	return rider_read_t >= 0.0 and _rider_hit_t < 0.0 and game.clock - rider_read_t < RIDER_FOR


## The riders it expects (seen alive in the last 3 minutes, at least 3 while it reads a rush) as a value.
func _rider_need() -> float:
	var n := 0
	for r in _rider_seen.keys():
		if not is_instance_valid(r) or r.dead:
			_rider_seen.erase(r)
			continue
		if game.clock - float(_rider_seen[r]) < 180.0:
			n += 1
	if rider_read_t >= 0.0 and game.clock < RIDER_READ_BY + 60.0:
		n = maxi(n, 3)
	# (just in time: before the riders are seen on the road or in its land, part of it (the grubs grow meanwhile: the
	# whole of it from the read cost the Hollowfen games 10 grubs at 4:00); the rest once they are seen coming)
	var share := 1.0 if game.clock - _rider_land_t < RIDER_CALM or game.clock - _rider_out_t < 60.0 else RIDER_PRE
	return float(n) * RIDER_V * share


## Short of warriors against the riders it expects (its army at home, not out on a wave).
func _rider_short() -> bool:
	if not _riders_on():
		return false
	var home := _nb_army_units().filter(func(u: Unit) -> bool: return not _wave.has(u) and u.kind != "hatchlings")
	return _value_of(home) < _rider_need()


## In its land: near its Mother, one of its rooted Rootmaws or one of its grubs.
func _in_my_land(q: Unit, p: Vector2) -> bool:
	if q != null and p.distance_to(_qp(q)) < HOME_R * Defs.TILE:
		return true
	for u in game.units_near(p, RIDER_LAND_R * Defs.TILE):
		if u.team == team and not u.dead and (u.kind == "grub" or (u.kind == BroodNew.MAW and BroodNew.rooted(u))):
			return true          # (its grubs and its Rootmaws: a turtle staking new ground far out is no worker line)
	return false


func _nb_riders_seen(riders_now: int, riders_out: int, riders_land: int, horses: int) -> void:
	var c := game.clock
	if riders_out > 0:
		_rider_out_t = c
	for b in _foe_blds.keys():
		if not is_instance_valid(b) or b.dead:
			continue
		if b.kind == "horse_breeder" and _breeder_t < 0.0:
			_breeder_t = c
		elif b.kind == "powder_mill" and _mill_t < 0.0:
			_mill_t = c
	if riders_land >= 2:          # (a lone rider is a harass: the guard and the grubs' own flight answer it, no lockdown)
		if _rider_calm_said:
			_rider_calm_said = false
			_rider_hit_t = c
			rider_raids += 1
			if rider_read_t < 0.0:
				_rider_read_now("%d riders in its land at %s" % [riders_land, _mmss()])
			say("riders in its land (%d): grubs to the warriors, the warriors guard them, no chase" % riders_land)
		_rider_land_t = c
	elif not _rider_calm_said and c - _rider_land_t > RIDER_CALM:
		_rider_calm_said = true
		_rider_hit_t = -1.0
		_rider_over = true
		rider_read_t = minf(rider_read_t, c - RIDER_FOR)          # (the read is spent: the next riders read again)
		say("the riders are gone: its grubs back to work, back to its plan")
	if rider_read_t >= 0.0 or c >= RIDER_READ_BY or peaceful:
		return
	var why := ""
	if _breeder_t >= 0.0 and _breeder_t < RIDER_EARLY and (_mill_t < 0.0 or _mill_t > _breeder_t):
		why = "a Horse Breeder at %s and no Powder Mill" % _mmss_at(_breeder_t)
	elif riders_out >= (1 if c < RIDER_EARLY else 2):
		why = "%d riders out of its main at %s" % [riders_out, _mmss()]
	elif riders_now > 0 and c < RIDER_EARLY:
		why = "a Horseman at %s" % _mmss()
	elif horses >= 2 and c < RIDER_EARLY:
		why = "%d horses at %s" % [horses, _mmss()]
	if why != "":
		_rider_read_now(why)


func _rider_read_now(why: String) -> void:
	rider_read_t = game.clock
	if rider_read_first < 0.0:
		rider_read_first = game.clock
	rider_read = why
	say("rider read: %s: Raptors now, its grubs kept by them, no chase" % why)


func _mmss_at(c: float) -> String:
	return "%d:%02d" % [int(c) / 60, int(c) % 60]


## THE WARRIORS GUARD THE GRUBS (a group of riders only, at home): the guard is the threatened site (the rooted creature
## of its own nearest the riders) when the warriors beat the riders there clearly, else the Mother's side toward them. They
## go for riders within RIDER_GUARD_R tiles of the guard or at its grubs, and walk back past RIDER_LEASH tiles.
func _nb_defend_riders(q: Unit, army: Array, group: Array) -> bool:
	var at := _mid(group)
	var avail: Array = army.filter(func(u: Unit) -> bool: return u.moult_t < 0.0 and not held.has(u) and u.kind != "hatchlings" \
		and not BroodNew.is_father(u.kind))
	for u in _def.duplicate():
		if BroodNew.is_father((u as Unit).kind):
			_def.erase(u)
			(u as Unit).cmd_stop()          # (a Sire never catches a rider: back to his nest)
	var site: Unit = q
	for u in game.units_near(at, 20.0 * Defs.TILE):
		if u.team == team and not u.dead and u.kind == BroodNew.MAW and BroodNew.rooted(u) \
				and u.position.distance_to(at) < site.position.distance_to(at):
			site = u
	var guard: Vector2 = _qp(q) + (at - _qp(q)).normalized() * (BroodNew.drawn_r(q) + 40.0)
	if site != q and _fight_wins(avail, group, 0.4):
		guard = site.position + (at - site.position).normalized() * (site.radius + 30.0)
	if not _nb_on_map(guard) or not game._walkable(game.cell_of(guard)):
		guard = _qp(q) + game.sym_dir(team, Vector2(0, BroodNew.drawn_r(q) + 40.0))
	_rider_guard = guard
	_rally = guard
	# (strong: worth 2.5 times the riders or more: it pushes them off its land, a wider reach and leash: two riders kited a
	# guard of 17 Raptors round Dune Sea for two minutes and kept its grubs running)
	var strong := _value_of(avail) >= _value_of(group) * 2.5
	var reach := (RIDER_GUARD_R + 8.0 if strong else RIDER_GUARD_R) * Defs.TILE
	var leash := (RIDER_LEASH + 9.0 if strong else RIDER_LEASH) * Defs.TILE
	var near: Array = group.filter(func(r: Unit) -> bool: return r.position.distance_to(guard) < reach or _grub_near(r.position, 5.0))
	_def = avail
	_def_at = at
	for u in avail:
		var cu := u as Unit
		if cu.position.distance_to(guard) > leash:
			if cu.order != "move" or cu.path_goal.distance_to(guard) > 120.0:
				cu.cmd_move(guard)          # (the leash: back to the grubs, a plain walk)
			continue
		if near.is_empty():
			if cu.target != null and cu.position.distance_to(guard) > 6.0 * Defs.TILE:
				cu.cmd_move(guard)
			elif cu.position.distance_to(guard) > 4.0 * Defs.TILE and cu.order != "move":
				cu.cmd_move(guard, true)
			continue
		var best: Unit = null
		for r in near:
			if best == null or (r as Unit).position.distance_to(cu.position) < best.position.distance_to(cu.position):
				best = r
		if cu.order != "attack" or cu.order_target != best:
			if cu.target == null or not is_instance_valid(cu.target) or not group.has(cu.target):
				cu.cmd_attack(best)
	if game.clock - _rider_def_t > 20.0:
		_rider_def_t = game.clock
		say("guards its grubs with %d (%d) against %d riders at %s: no chase past %d tiles" % [avail.size(), int(_value_of(avail)), group.filter(func(o) -> bool: return is_rider(o)).size(),
			"the Mother" if site == q or guard.distance_to(_qp(q)) < 6.0 * Defs.TILE else "its %s" % String(Defs.UNITS[site.kind]["name"]), int(RIDER_LEASH)])
	return true


## Every enemy fighter near the Mother (13 tiles) is a rider or an Officer.
func _riders_only_near(q: Unit) -> bool:
	for u in game.units_near(_qp(q), 13.0 * Defs.TILE):
		if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_worker() \
				and not is_rider(u) and u.kind != "dismounted":
			return false
	return true


func _grub_near(p: Vector2, tiles: float) -> bool:
	for u in game.units_near(p, tiles * Defs.TILE):
		if u.team == team and not u.dead and (u.kind == "grub" or u.kind == BroodNew.QUEEN):
			return true
	return false


## The enemy flyers it has seen lately (the most at once): what it knows, not every flyer on the map.
func _nb_foe_air() -> int:
	return seen_air


## The enemy walls itself in (a wall seen, or the Crown, which walls its ramp in its first minute).
func _wall_foe() -> bool:
	if seen_wall:
		return true
	var foe := _foe()
	return foe >= 0 and game.faction_of(foe) == "crown"


func _mmss() -> String:
	return "%d:%02d" % [int(game.clock) / 60, int(game.clock) % 60]


## Rush evidence that still counts (for 3 minutes, and only while the enemy army is not beaten).
func _rush_on() -> bool:
	return rush_seen != "" and game.clock - rush_t < 180.0


## The rush evidence and its army at home short of what it saw (1.2 times the biggest enemy army seen since, 300 at
## least): only then its eggs are warriors first, its grubs capped and no new ground taken (brood-anti-riders: the owner's
## Hollowfen game laid Raptors for three minutes, 51 of them on 13 grubs, long after the riders had gone).
func _rush_short() -> bool:
	if not _rush_on():
		return false
	_rush_v = maxf(_rush_v, seen_army)
	var home := _nb_army_units().filter(func(u: Unit) -> bool: return not _wave.has(u) and u.kind != "hatchlings")
	return _value_of(home) < maxf(_rush_v * 1.2, 300.0)


## THE SCOUT (Normal and up, not the Extreme rush): a grub at about 1:10 walks to the enemy's start and round it, then
## home (a grub is cheap and its trip reveals the opening); at about 4:30 a Raptor looks again (its army, a wall,
## flyers, an expansion). It runs home from soldiers that come at it.
var _scout: Unit = null
var _scout_trips := 0
var _scout_pts: Array = []
var _scout_i := 0
var _scout_t0 := 0.0


func _nb_scout(q: Unit) -> void:
	if strategy == "xrush" or peaceful:
		return
	var foe := _foe()
	if foe < 0:
		return
	if _eco():
		_nb_watch_scout(q, foe)
		return
	if _scout != null and (not is_instance_valid(_scout) or _scout.dead):
		_scout = null
	if _scout == null:
		var due := 70.0 if _scout_trips == 0 else (270.0 if _scout_trips == 1 else 9999.0)
		if game.clock < due or _scout_trips >= 2:
			return
		var pick: Unit = null
		if _scout_trips == 0:
			for u in _nb_mine("grub"):
				if u.carrying == 0 and u.order == "gather" and u.cocoon <= 0.0:
					pick = u
					break
		else:
			for u in _nb_army_units():
				if u.kind == "raptor" and not _wave.has(u) and not _def.has(u) and u.target == null:
					pick = u
					break
		if pick == null:
			return
		var st := (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE
		var toward := (_qp(q) - st).normalized()
		_scout_pts = [st + toward * 9.0 * Defs.TILE, st, st + toward.orthogonal() * 7.0 * Defs.TILE, st - toward * 6.0 * Defs.TILE,
			st - toward.orthogonal() * 7.0 * Defs.TILE, _qp(q)]
		_scout_i = 0
		_scout = pick
		_scout_trips += 1
		_scout_t0 = game.clock
		_scout_go(pick, _scout_pts[0])
		say("sends a %s to scout" % Defs.UNITS[pick.kind]["name"])
		return
	# on the road: next point; home after the loop, after 100 s, or when hurt by soldiers
	var hurt := _scout.hp < _scout.max_hp * 0.6
	if hurt or game.clock - _scout_t0 > 100.0 or _scout_i >= _scout_pts.size():
		if _scout.position.distance_to(_qp(q)) > 10.0 * Defs.TILE:
			if _scout.order != "move" or _scout.path_goal.distance_to(_qp(q)) > 200.0:
				_scout.cmd_move(_qp(q))
			return
		_scout.remove_meta("ai_scout")
		_scout.cmd_stop()        # (home: back to work; WORK finds a grub a Rootmaw)
		_scout = null
		return
	# a Raptor scout harasses on its loop: a worker in reach is bitten, a rooted creature (the Brood's own kind, in a
	# mirror) or a building its attack-move took up is walked past (scripts/ai_harass.gd)
	if not _scout.is_worker():
		var prey := hz().pick_prey(_scout)
		if prey != null and prey.position.distance_to(_scout.position) < 6.0 * Defs.TILE:
			if _scout.order != "attack" or _scout.order_target != prey:
				_scout.cmd_attack(prey)
			return
		if (_scout.order == "attack" and AIHarass.is_static(_scout.order_target)) or (_scout.target != null and is_instance_valid(_scout.target) and AIHarass.is_static(_scout.target)):
			_scout.cmd_move(_scout_pts[_scout_i])
			return
		if _scout.order == "attack":
			_scout_go(_scout, _scout_pts[_scout_i])      # (its prey dead: on with the loop)
			return
	if _scout.position.distance_to(_scout_pts[_scout_i]) < 3.0 * Defs.TILE or _scout.order == "idle":
		_scout_i += 1
		if _scout_i < _scout_pts.size():
			_scout_go(_scout, _scout_pts[_scout_i])


## THE COMPUTER (ALMOST) NEVER USES PLAIN MOVE (owner, 2026-10-30): a Raptor scout goes on attack-move, marked
## "ai_scout" (it bites only what fights back, Unit._pick_target: not every building on its loop); a grub (a worker)
## walks. Going home hurt stays a plain walk (a retreat).
func _scout_go(u: Unit, p: Vector2) -> void:
	if u.is_worker():
		u.cmd_move(p)
		return
	u.set_meta("ai_scout", true)
	u.cmd_move(p, true)


## THE WATCHING GRUB (the owner's build, 2026-10-30 07:15: scouting for a safe economy): from about 1:10 a grub stays
## out on watch for the whole game, to see a rush or a timing attack coming:
##  - against the CROWN it PATROLS at the bottom of the enemy's ramp (a little out from its foot, to and fro across it):
##    everything that leaves the Crown's main walks past it;
##  - against the CLOCKWORK (or any other) it EXPLORES the enemy's main, round and round (what it trains, how big its
##    army is, where it gathers).
## Hurt, or soldiers close to it, it runs home and goes back to work; another grub goes out after WATCH_GAP s (at most
## WATCH_MAX in a game: a grub is an egg and 50 food).
const WATCH_GAP := 60.0
const OPT_WATCH_AT := 40.0      # (OPTIMAL: its first watching grub goes this early, the read is how it picks)
const WATCH_MAX := 4
var _watch_n := 0
var _watch_next := 70.0
var _watch_flee := false
var _watch_peek := false            # (the first watcher's look into the Crown's main, brood-anti-riders)
var _peek_pts: Array = []           # (its points round the main)
var _watch_back := Vector2.INF      # (backing off from soldiers, to come back)
var _watch_back_t := 0.0
var _foot := Vector2.INF            # the foot of the enemy's ramp (pixels), found once
var _foot_dir := Vector2.ZERO       # out from its foot, away from the enemy's main


func _nb_watch_scout(q: Unit, foe: int) -> void:
	if _scout != null and (not is_instance_valid(_scout) or _scout.dead):
		_scout = null
		_watch_flee = false
		_watch_peek = false
		_watch_back = Vector2.INF
		_watch_next = game.clock + WATCH_GAP
	var st := (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE
	if _scout == null:
		var first_opt := (opt != null or _foe_is("crown")) and _watch_n == 0      # (brood-anti-riders: early against the Crown too, its Horse Breeder)
		if (game.clock < (OPT_WATCH_AT if first_opt else _watch_next)) or _watch_n >= WATCH_MAX or BroodNew.count_of(game, team, "grub") < (6 if first_opt else 8):
			return
		var pick: Unit = null
		for u in _nb_mine("grub"):
			if u.carrying == 0 and u.order == "gather" and u.cocoon <= 0.0 and (pick == null \
					or u.position.distance_squared_to(st) < pick.position.distance_squared_to(st)):
				pick = u
		if pick == null:
			return
		_scout = pick
		_watch_n += 1
		_scout_trips += 1
		_scout_t0 = game.clock
		_watch_flee = false
		_scout_i = 0
		if _foe_is("crown"):
			if _foot == Vector2.INF:
				_find_foe_foot(foe, q)
			var c: Vector2 = _foot + _foot_dir * 5.0 * Defs.TILE if _foot != Vector2.INF else st
			var side := _foot_dir.orthogonal() * 3.0 * Defs.TILE
			_scout_pts = [c + side, c - side]
			if _foot != Vector2.INF:
				# (ai-optimal: the walled Crown's read is its next hall: a second hall early is greed. The Crown puts it at
				# the least hall distance from its main, by the foot of its ramp, the third its mirror on the other side
				# (docs/expansion_spots.md, "The Crown's rule"): the watcher looks at both on its rounds)
				var hc := st
				var fd := (_foot - hc).normalized()
				for ang in [-0.9, 0.9]:
					var pt: Vector2 = hc + fd.rotated(ang) * float(Defs.HALL_SPACING) * Defs.TILE
					var cc := Vector2i(pt / Defs.TILE)
					if game.in_map(cc) and game.solid[game.idx(cc)] == 0:
						_scout_pts.append(pt)
			# (brood-anti-riders: the first watcher walks up into its main once on the way, while its ramp is still open: a
			# Horse Breeder and no Powder Mill there is the rider rush, read a minute and more before the riders come)
			if _watch_n == 1:
				var tw := (_qp(q) - st).normalized()
				_peek_pts = [st, st + tw.orthogonal() * 6.0 * Defs.TILE, st - tw * 5.0 * Defs.TILE, st - tw.orthogonal() * 6.0 * Defs.TILE]
				_watch_peek = true
		else:
			var toward := (_qp(q) - st).normalized()
			_scout_pts = [st + toward * 8.0 * Defs.TILE, st + toward.orthogonal() * 7.0 * Defs.TILE, st - toward * 6.0 * Defs.TILE,
				st - toward.orthogonal() * 7.0 * Defs.TILE, st]
		pick.auto_work = false
		pick.cmd_move(_peek_pts[0] if _watch_peek else _scout_pts[0])
		say("sends a Grub to %s" % ("watch the foot of the enemy's ramp" if _foe_is("crown") else "explore the enemy's main"))
		return
	# danger: hurt, or soldiers close: home, back to work
	if not _watch_flee:
		var close := false
		for u in game.units_near(_scout.position, 6.5 * Defs.TILE):
			if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_worker() \
					and game.is_visible_to(team, u.position):
				close = true
				break
		if close or _scout.hp < _scout.max_hp * 0.7:
			_watch_flee = true
			if _scout.hp < _scout.max_hp * 0.7:
				_watch_peek = false
				_watch_back = Vector2.INF
				_scout.cmd_move(_qp(q))
			else:
				# (brood-anti-riders: not hurt, it backs off a little and comes back to its watch: going home it left the
				# foot of the ramp empty for a minute and more, and the riders left unseen)
				_watch_back = _scout.position + (_qp(q) - _scout.position).normalized() * 10.0 * Defs.TILE
				_watch_back_t = game.clock
				_scout.cmd_move(_watch_back)
			return
	elif _watch_back != Vector2.INF:
		var threat := false
		for u in game.units_near(_scout.position, 9.0 * Defs.TILE):
			if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_worker() \
					and game.is_visible_to(team, u.position):
				threat = true
				break
		if _scout.hp < _scout.max_hp * 0.7:
			_watch_back = Vector2.INF
			_watch_peek = false
			_scout.cmd_move(_qp(q))
		elif not threat and game.clock - _watch_back_t > 5.0:
			_watch_back = Vector2.INF
			_watch_flee = false
			_scout.cmd_move(_peek_pts[0] if _watch_peek and not _peek_pts.is_empty() else _scout_pts[_scout_i])     # (its look round the main goes on)
		elif threat and (_scout.position.distance_to(_watch_back) < 1.5 * Defs.TILE or _scout.order == "idle"):
			_watch_back = Vector2.INF          # (still hunted there: home)
			_watch_peek = false
			_scout.cmd_move(_qp(q))
		return
	else:
		if _scout.position.distance_to(_qp(q)) < 10.0 * Defs.TILE or _scout.order == "idle":
			_scout.auto_work = true
			_scout.cmd_stop()          # (home: back to work)
			_scout = null
			_watch_flee = false
			_watch_next = game.clock + (20.0 if _foe_is("crown") and game.clock < RIDER_READ_BY and rider_read_t < 0.0 else WATCH_GAP)      # (brood-anti-riders: home unhurt before the riders are read: the next goes soon; Dune Sea, the foot was empty from 3:00 to 4:00 and the riders left at 3:37 unseen)
		elif _scout.order != "move":
			_scout.cmd_move(_qp(q))
		return
	# on watch: to and fro (the Crown's ramp foot), or round its main
	if _watch_peek:
		if not _peek_pts.is_empty() and (_scout.position.distance_to(_peek_pts[0]) < 3.0 * Defs.TILE or _scout.order == "idle"):
			_peek_pts.pop_front()
			if not _peek_pts.is_empty():
				_scout.cmd_move(_peek_pts[0])
		if _peek_pts.is_empty() or game.clock - _scout_t0 > 110.0:
			_watch_peek = false          # (its main looked round, or shut: down to the foot of its ramp)
			_scout_i = 0
			_scout.cmd_move(_scout_pts[0])
		return
	if _scout.position.distance_to(_scout_pts[_scout_i]) < 1.5 * Defs.TILE or _scout.order == "idle":
		_scout_i = (_scout_i + 1) % _scout_pts.size()
		_scout.cmd_move(_scout_pts[_scout_i])


## The foot of the ramp up to the enemy's main nearest to us (Game.ramp_foot's walk through a ramp, from the enemy's
## plateau), and the way out from it.
func _find_foe_foot(foe: int, q: Unit) -> void:
	var hc := Vector2i(Vector2(game.starts[foe]) + Vector2(2.5, 2.0))
	if not game.in_map(hc):
		return
	var h0 := int(game.height[game.idx(hc)])
	var best := Vector2.INF
	var bd := INF
	for y in range(hc.y - 30, hc.y + 31):
		for x in range(hc.x - 30, hc.x + 31):
			var r := Vector2i(x, y)
			if not game.in_map(r) or game.ramp[game.idx(r)] != 1:
				continue
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = r + dd
				if not game.in_map(p) or game.ramp[game.idx(p)] != 0 or int(game.height[game.idx(p)]) != h0:
					continue
				var f := r
				var steps := 0
				while game.in_map(f) and game.ramp[game.idx(f)] == 1 and steps < 12:
					f += -dd
					steps += 1
				if not game.in_map(f) or int(game.height[game.idx(f)]) == h0:
					continue
				var fp := (Vector2(f) + Vector2(0.5, 0.5)) * Defs.TILE
				var d := fp.distance_to(_qp(q))
				if d < bd:
					bd = d
					best = fp
					_foot_dir = Vector2(-dd).normalized()
	_foot = best


## THE ALARM'S REACTIONS (the owner's build; the alarm itself: _nb_observe) and, at any time, grubs pulled back:
##  - the grubs of a Rootmaw that enemy soldiers come near (9 tiles; not the Rootmaws by the Mother, where the army
##    fights) run to the Mother and wait there, then go back to work once the enemy has gone (or after 40 s);
##  - with the alarm on and a natural taken: a Mound Turtle from home (only with 12 supply to spare: rooted, it gives
##    the supply back) walks out in front of the natural, toward the enemy, and roots there (a tank in its way, very hard to
##    hurt); one at a time, it stays there. (Not ON the ramp: a rooted turtle closes it, and the natural's grubs walk up it.)
var _pulled := {}                  # grub -> [its Rootmaw, when]
var _front_t: Unit = null          # the turtle rooting (rooted) in front of the natural
var _front_done := false
var _front_kept_t := -99.0
const DYING := 0.25               # (a turtle under a quarter of its health may get up anyway: it would be lost with its swamp)


func _nb_alarm(q: Unit) -> void:
	# grubs pulled back from a Rootmaw with enemy soldiers at it
	for u in _nb_mine("grub"):
		if u.order != "gather" or u == _scout or _pulled.has(u):
			continue
		var m = u.home_mine
		if m == null or not is_instance_valid(m) or (m as Unit).position.distance_to(_qp(q)) < 14.0 * Defs.TILE:
			continue
		if _foe_near((m as Unit).position, 9.0 * Defs.TILE) or _foe_near(u.position, 6.0 * Defs.TILE):
			_pulled[u] = [m, game.clock]
			u.auto_work = false
			u.cmd_move(_qp(q))
	# (pulled grubs go back to work: _nb_pull_back)
	# a turtle in front of the natural
	if _front_t != null and (not is_instance_valid(_front_t) or _front_t.dead):
		_front_t = null
	if _front_t != null:
		if BroodNew.rooted(_front_t):
			_front_done = true
			say("a Mound Turtle roots in front of the natural")
			_front_t = null
		elif _front_t.tesla_mode == "packed" and _foe_near(_front_t.position, 7.0 * Defs.TILE) and _front_may_root_here():
			_front_t.cmd_deploy()          # (brood-ai-tune, round C g10: enemies reached it on its way: it roots where it is,
			                               # a tank in their way, instead of walking on through them uprooted)
		elif _front_t.tesla_mode == "packed" and _front_t.order != "nb_root" and _front_t.order != "move":
			var fs = _nb_front_spot(q)
			if fs != null:
				_root_to(_front_t, fs)
			else:
				_front_t = null
		return
	if _front_done or not _alarm_on():
		return
	if _nb_threat(q) != Vector2.INF or _foe_near_home >= 150.0:
		return          # (brood-ai-tune, round C g10: the attack is already at home: a turtle got up at 6:33 and walked into
		                # 12 Clock Soldiers at the Mother, its 12 supply gone while it walked; it stays rooted now)
	var cap := int(game.players[team]["cap"])
	if cap - game.supply_used(team) < int(Defs.NB["turtle_supply"]) + 2:
		return
	var spot = _nb_front_spot(q)
	if spot == null:
		return
	var far := float(Defs.NB["expansion_tiles"]) * Defs.TILE * 0.9
	var pick: Unit = null
	var kept := 0
	for t in _nb_mine(BroodNew.TURTLE):
		if BroodNew.rooted(t) and t.position.distance_to(_qp(q)) < far and not held.has(t) \
				and (pick == null or t.position.distance_to(spot) < pick.position.distance_to(spot)):
			# (brood-layout, the owner's Thornwood log 2026-11-04 3:23-3:42: never a turtle whose swamp is the only swamp
			# of live rooted Rootmaws: they would go dry and uproot; unless it is dying anyway)
			if not BroodLayout.off and not BroodLayout.feeds_maws(game, t).is_empty() and t.hp > t.max_hp * DYING:
				kept += 1
				continue
			pick = t
	if pick == null:
		if kept > 0 and game.clock - _front_kept_t > 30.0:
			_front_kept_t = game.clock
			say("ALARM: no Mound Turtle gets up: its turtles feed the Rootmaws' swamp")
		return
	_front_t = pick
	BroodNew.uproot(pick, false)
	say("ALARM: a Mound Turtle gets up to root in front of the natural")


## GRUBS AGAINST RIDERS (the owner's playtest 2026-11-03, Glimmerdeep: his Horsemen killed "a gigantic number of
## workers"; "they need to use the workers to fight"): grubs a rider is at (within 5 tiles) gang up on it when they win
## on paper (_fight_wins, 5 grubs or more: a Horseman's sabre kills one in three blows while six bite him), else run to
## the nearest rooted Mound Turtle, warriors or the Mother (no rooted creature bites, but warriors and the Mother do,
## and a rider among them is in reach of more); they go back to work when the rider is gone (_pulled, _nb_alarm's rule
## for every profile: _nb_pull_back).
const RIDER_R := 5.0
var _gang_t := -99.0


func _nb_grubs_vs_riders(q: Unit) -> void:
	_nb_pull_back(q)
	var riders: Array = []
	for u in game.units_near(_qp(q), (HOME_R + 14.0) * Defs.TILE):
		if game.hostile(u.team, team) and not u.dead and not u.off_field and is_rider(u) and game.is_visible_to(team, u.position):
			riders.append(u)
	if riders.is_empty():
		return
	# (brood-anti-riders: during a rider raid the grubs run sooner, from farther, and to the warriors that guard them)
	var raid := _riders_on()
	if raid and _value_of(_nb_army_units().filter(func(u: Unit) -> bool: return not _wave.has(u))) >= _value_of(riders) * 2.5:
		raid = false          # (warriors worth 2.5 times the riders here: the grubs run only from a rider right at them)
	var flee_r := (RIDER_FLEE if raid else RIDER_R) * Defs.TILE
	var guard_v := 0.0
	for u in _nb_army_units():
		if u.position.distance_to(_qp(q)) < 18.0 * Defs.TILE and u.moult_t < 0.0 and u.kind != "hatchlings":
			guard_v += float(Game.unit_value(u))
	for r in riders:
		var near: Array = []
		for u in game.units_near(r.position, flee_r):
			if u.team == team and not u.dead and u.kind == "grub" and u != _scout and u.order != "nb_morph":
				near.append(u)
		if raid:
			# grubs at a Rootmaw the rider is at, even out of its reach yet
			for m in game.units_near(r.position, RIDER_FLEE * Defs.TILE):
				if m.team != team or m.dead or m.kind != BroodNew.MAW:
					continue
				for u in _nb_mine("grub"):
					if u.home_mine == m and not near.has(u) and u != _scout and u.order != "nb_morph" and u.position.distance_to(m.position) < 6.0 * Defs.TILE:
						near.append(u)
		if raid and guard_v >= 200.0:
			# (grubs working by the warriors' guard are covered: only a rider right at them makes them run)
			var gp: Vector2 = _rider_guard if _rider_guard != Vector2.INF else _qp(q)
			near = near.filter(func(u: Unit) -> bool: return u.position.distance_to(r.position) < RIDER_R * Defs.TILE \
				or u.position.distance_to(gp) > 10.0 * Defs.TILE)
		if near.is_empty():
			continue
		var foes: Array = riders.filter(func(o: Unit) -> bool: return o.position.distance_to(r.position) < RIDER_R * Defs.TILE)
		# GANG UP only when they MASSIVELY outnumber a lone hurt rider (the owner's Hollowfen game, 4:12: 9 grubs at a
		# Horseman, and the grubs fell three blows each): 6 grubs or more in its reach, the rider alone and under half its
		# health, and a win on paper losing under a third of their health
		var close: Array = near.filter(func(u: Unit) -> bool: return u.position.distance_to(r.position) < RIDER_R * Defs.TILE)
		# (and as a last resort with no warriors at home to run to: 8 grubs or more for each rider, a win on paper losing
		# under a third: the riders kill them anyway, Dune Sea seed 2 lost all 21 at the Mother)
		var last := guard_v < 60.0 and close.size() >= 8 * foes.size() and _fight_wins(close, foes, 0.33)
		if (close.size() >= 6 and foes.size() == 1 and r.hp < r.max_hp * 0.5 and _fight_wins(close, foes, 0.33)) or last:
			for u in close:
				if u.order != "attack" or not (u.order_target is Unit and foes.has(u.order_target)):
					u.auto_work = false
					_pulled[u] = [u.home_mine, game.clock]
					u.cmd_attack(r)
			if game.clock - _gang_t > 10.0:
				say("%d grubs gang up on a %s" % [close.size(), String(Defs.UNITS[r.kind]["name"])])
			_gang_t = game.clock
			continue
		var safe := _nb_safe_for_grubs(q, r.position)
		for u in near:
			if _pulled.has(u) and u.order == "move":
				continue
			if raid and u.position.distance_to(safe) < 3.0 * Defs.TILE:
				continue          # (already by the warriors)
			_pulled[u] = [u.home_mine, game.clock]
			u.auto_work = false
			u.cmd_move(safe)


## Where a grub runs from a rider at `from`: during a rider raid, to the warriors that guard the grubs (or the Mother);
## else the nearest of its warriors in a group, a rooted Mound Turtle or the Mother, not past the rider.
func _nb_safe_for_grubs(q: Unit, from: Vector2) -> Vector2:
	if _riders_on():
		var g2 := _rider_guard if _rider_guard != Vector2.INF and _rider_guard.distance_to(from) > 4.0 * Defs.TILE else _qp(q)
		var nearby := 0
		for u in game.units_near(g2, 6.0 * Defs.TILE):
			if u.team == team and not u.dead and not u.is_worker() and u.has_attack() and not u._k_nb:
				nearby += 1
		if nearby >= 3 or g2 == _qp(q):
			return g2
		return _qp(q)
	var best: Vector2 = _qp(q)
	var bd := _qp(q).distance_to(from) * 1.3
	for u in game.units_near(from, 16.0 * Defs.TILE):
		if u.team != team or u.dead:
			continue
		var ok: bool = (u.kind == BroodNew.TURTLE and BroodNew.rooted(u)) or (not u.is_worker() and u.has_attack() and not u._k_nb)
		if not ok:
			continue
		var d: float = u.position.distance_to(from)
		if d < 3.0 * Defs.TILE:
			continue          # (that one is where the rider is)
		if d < bd:
			bd = d
			best = u.position
	return best


## Grubs pulled off their work (by the alarm or a rider) go back once nothing is near their Rootmaw (8 s), or after 40 s.
func _nb_pull_back(_q: Unit) -> void:
	for u in _pulled.keys():
		if not is_instance_valid(u) or u.dead:
			_pulled.erase(u)
			continue
		var m = _pulled[u][0]
		var mp: Vector2 = (m as Unit).position if m != null and is_instance_valid(m) and not (m as Unit).dead else u.position
		var gone: bool = not _foe_near(mp, 11.0 * Defs.TILE) and not _foe_near(u.position, 6.0 * Defs.TILE)
		if (gone and game.clock - float(_pulled[u][1]) > 8.0) or game.clock - float(_pulled[u][1]) > 40.0:
			_pulled.erase(u)
			u.auto_work = true
			if m != null and is_instance_valid(m) and not (m as Unit).dead and BroodNew.rooted(m):
				u.cmd_gather(m)
			else:
				u.cmd_stop()


## (brood-layout) The front turtle met by enemies on its way roots where it stands only where the computer may root a
## turtle (BroodRoot.place_problem for the computer: not on or by a ramp, no pocket closed, BroodLayout): in the
## Redrock Canyon study game (Spitter timing against the Clockwork, seed 5) it rooted at its main's ramp at 5:42 and
## shut its whole base in, 42 units at once, 69 by 10:00. Elsewhere it walks on to its spot.
var _front_ok := [Vector2i(-1, -1), -99.0, false]      # (the last answer: its cell, when, yes or no: asked at most every 2 s a cell)


func _front_may_root_here() -> bool:
	if BroodLayout.off:
		return true
	var p := _front_t.position
	var c := game.cell_of(p)
	if _front_ok[0] == c and game.clock - float(_front_ok[1]) < 2.0:
		return bool(_front_ok[2])
	var ok := BroodRoot.place_problem(game, team, BroodNew.TURTLE, p, _front_t, true) == "" \
			and BroodLayout.exact(game, team, BroodNew.TURTLE, p, _front_t) == ""
	_front_ok = [c, game.clock, ok]
	return ok


## In front of the natural: 6 tiles out from its turtle toward the enemy (or where the alarm saw the army), on a spot a
## turtle may root (not on a ramp: BroodRoot.place_problem for the computer).
func _nb_front_spot(q: Unit):
	var nat: Unit = null
	for u in BroodNew.expansions(game, q):
		if nat == null or u.position.distance_to(_qp(q)) < nat.position.distance_to(_qp(q)):
			nat = u
	if nat == null:
		return null
	var foe := _foe()
	var toward: Vector2 = (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE if foe >= 0 else alarm_at
	var dir := (toward - nat.position).normalized()
	for dist in [6.0, 5.0, 7.0, 4.0, 8.0]:
		for turn in [0.0, 0.35, -0.35, 0.7, -0.7]:
			var p: Vector2 = BroodRoot.snap(BroodNew.TURTLE, nat.position + dir.rotated(turn) * dist * Defs.TILE)
			if not _nb_on_map(p) or not game._walkable(game.cell_of(p)) or _spot_bad(p):
				continue
			if BroodRoot.place_problem(game, team, BroodNew.TURTLE, p, _front_t, true) == "":
				return p
	return null


## The Mother: rooted at home; she CANNOT ATTACK while rooted, so when enemies reach her she uproots and fights, and
## roots again once it is really calm (BroodNew.mother_guard). Only its own Mother: never the player's.
var _q_guard := {}


func _nb_mother(q: Unit) -> void:
	if q.team != team or bool(plan.get("mother_free", false)):
		return          # (mother_free: a coach walks her itself, tools/play_brood_3.gd)
	_q_guard["stay"] = _nb_mother_up(q) == ""
	BroodNew.mother_guard(game, q, _q_guard, [1.6, 1.0, 0.6, 0.4][clampi(difficulty, 0, 3)])


## THE MOTHER GETS UP ONLY FOR A REAL REASON (the owner's playtest, 2026-11-01: two Clock Soldiers near her got her up
## at 3:03; her swamp went with her and two Rootmaws lost theirs and uprooted, and she got up again at 3:30). Rooted she
## has 3 more armour and takes a quarter less: two Clock Soldiers need five minutes to bring her down, and her squad or
## the Tyrant Sire comes for them (_nb_defend). The reasons (docs/brood_ai_swarm.md), "" = none, she stays rooted:
##  "big"   a real attack at her (MOTHER_BIG value or more within 8 tiles of her body) that the army near her (14 tiles)
##          does not match: she is the strongest fighter it has;
##  "alone" she is under 80% health, enemies strike her and nobody of hers fights them near her;
##  "last"  a last stand: under 40% health with enemies at her.
## Never for a scout, a lone raider, a small harass, flyers, or enemies only passing near.
const MOTHER_BIG := 250.0


func _nb_mother_up(q: Unit) -> String:
	var at := 0.0
	var strikes := false
	var riders_at := true            # (only riders at her)
	for u in game.units_near(_qp(q), 14.0 * Defs.TILE):
		if not game.hostile(u.team, team) or u.dead or u.off_field or u.is_air() or not u.has_attack():
			continue
		if q.edge_distance(u.position) > 8.0 * Defs.TILE and u.target != q:
			continue
		if not u.is_worker():
			at += float(Game.unit_value(u))
			if not is_rider(u):
				riders_at = false
		if u.target == q:
			strikes = true
	if at <= 0.0 and not strikes:
		return ""
	if strikes and q.hp < q.max_hp * 0.4:
		return "last"
	var mine := 0.0
	var fighting := false
	for u in _nb_army_units():
		if u.position.distance_to(_qp(q)) < 14.0 * Defs.TILE:
			mine += float(Game.unit_value(u))
			if is_instance_valid(u.target) and not u.target.dead:
				fighting = true
	for fk in BroodNew.FATHERS:
		var f := BroodNew.father(game, team, fk)
		if f and f.tesla_mode == "packed" and is_instance_valid(f.target) and f.position.distance_to(_qp(q)) < 14.0 * Defs.TILE:
			fighting = true
			mine += float(Game.unit_value(f))
	if riders_at and mine >= at * 0.5:
		return ""          # (brood-anti-riders: riders alone with her warriors there do not get her up: she never catches one,
		                   # and her swamp feeds the Rootmaws round her (two lost theirs at 4:08 and 4:10 in the owner's
		                   # Hollowfen game). With no warriors she still gets up: her grubs huddle by her)
	if at >= MOTHER_BIG and mine < at:
		return "big"
	if strikes and q.hp < q.max_hp * 0.8 and not fighting:
		return "alone"
	return ""


# ------------------------------------------------------------------ the economy

func _nb_wanted_maws() -> int:
	var m: Array = plan["maws"]
	var n := mini(int(m[0]) + int(game.clock / float(m[1])), int(m[2]))
	n = mini(n, 2 + BroodNew.count_of(game, team, "grub") / 5)        # (no Rootmaw without grubs to crew it)
	if _rush_short():
		n = mini(n, 2)
	if int(plan["grubs0"]) > 0 and not _first_out:
		n = mini(n, int(plan.get("maws0", 2)))      # (a rush: the first wave before more ground)
	return n


var _first_out := false         # (the first wave has left)


## Supply ahead of need: one more Mound Turtle while the supply is within a few of the cap (more ahead later, when she
## lays faster), counting the ones on their way (cocoons, grubs going to turn into one, turtles walking to their spot).
func _nb_short() -> bool:
	var cap := int(game.players[team]["cap"])
	if cap >= game.max_supply(team):
		return false
	var coming := 0
	for u in game.units:
		if u.team == team and not u.dead and ((u.kind == BroodNew.TURTLE and not BroodNew.rooted(u)) \
				or (u.kind == "grub" and u.order == "nb_morph" and String(u.nb.get("mk", "")) == BroodNew.TURTLE)):
			coming += int(Defs.NB["turtle_supply"])
	var ahead := 3 + int(game.clock / 60.0)
	if _food() >= 500:
		ahead += 12          # (food piling up: a turtle more ahead, the eggs it buys will be laid)
	if _eco() and game.clock > 75.0 and _nb_far_have(BroodNew.queen(game, team)) < _nb_far_wanted():
		ahead += 2          # (the next turtle walks out to new ground: it roots later than one at home; not in the first
		                    # minute, when every 50 food is a grub: the first turtle at 0:32 cost a minute of grubs)
	if bb != null:
		ahead += bb.supply_ahead()          # (the written build: its Spitters hatch three to an egg)
	if int(plan["grubs0"]) > 0 and not _first_out:
		ahead = int(plan.get("ahead0", 3))          # (the Extreme rush: the turtle right after the Sire, so its Raptors never wait for supply)
	return game.supply_used(team) + ahead >= cap + coming


## Far turtles wanted by now (the plan's expansions), none while a rush is on.
func _nb_far_wanted() -> int:
	if _rush_short():
		return 0
	var n := 0
	for e in plan["far"]:
		if game.clock >= float(e[0]):
			n = int(e[1])
	if _eco() and _nb_egg_bound():
		n = maxi(n, mini(_nb_far_have(BroodNew.queen(game, team)) + 1, int(Defs.NB["expansion_max"])))
		# (brood-ai-tune: eggs hold it back: the next turtle on new ground now, +15% laying each, up to 3)
	return mini(n, int(Defs.NB["expansion_max"]))


func _nb_far_have(q: Unit) -> int:
	var n := 0
	var far := float(Defs.NB["expansion_tiles"]) * Defs.TILE
	for u in game.units:
		if u.team == team and not u.dead and u.kind == BroodNew.TURTLE and u.position.distance_to(_qp(q)) >= far * 0.9:
			n += 1
		elif u.team == team and not u.dead and u.kind == "grub" and u.order == "nb_morph" and String(u.nb.get("mk", "")) == BroodNew.TURTLE \
				and u.order_point.distance_to(_qp(q)) >= far * 0.9:
			n += 1
	return n


## THE STRUCTURE-UNITS COME FROM GRUBS (the owner, 19:19; scripts/brood_root.gd): one at a time, the computer picks
## what it needs (a Mound Turtle for supply, a Sire's lure, a turtle on new ground, more Rootmaws), a spot that passes
## the same ROOT placement checks as the player's ghost (BroodRoot.place_problem, keeping its ramps clear), and the
## grub nearest it.
var _morph_keep := 0             # food kept for the structure-unit it saves for (a grub on its way has paid already)


func _nb_morphs(q: Unit) -> void:
	BroodRoot.memo_begin()          # (its spot finders ask the same spots again: kept till the order is given, perf-frostfang)
	_nb_morphs_go(q)
	BroodRoot.memo_end()


func _nb_morphs_go(q: Unit) -> void:
	_morph_keep = 0
	var walking := 0
	for u in game.units:
		if u.team == team and not u.dead and u.kind == "grub" and u.order == "nb_morph":
			walking += 1
	# one at a time; a second only with food to spare (brood-eco: with the owner's economy the food came faster than one
	# grub at a time could turn it into turtles, and 900+ food sat for minutes at the supply cap)
	if walking >= 2 or (walking == 1 and _food() - _morph_keep < 400):
		return
	var grubs := BroodNew.count_of(game, team, "grub")
	var maws := BroodNew.count_of(game, team, BroodNew.MAW)
	var k := ""
	var spot = null
	var tyrant := BroodNew.count_of(game, team, BroodNew.FATHER) > 0
	if not tyrant and (grubs >= int(plan["sire_g"]) or game.clock > float(plan["sire_t"]) or _rush_on() or _alarm_on() \
			or (_riders_on() and game.clock > float(plan["sire_t"]) - 45.0)) and maws >= 1:      # (brood-anti-riders: riders read: his lure 45 s before the plan's time, in time for Raptors at 3:00, not at the read)
		k = BroodNew.FATHER         # (the first Sire: the warriors' line)
	elif _nb_short():
		k = BroodNew.TURTLE
		if _nb_far_have(q) < _nb_far_wanted() or (_food() >= 300 and _nb_far_have(q) < int(Defs.NB["expansion_max"]) + 2):
			var fp := _nb_far_spots(q)          # (a turtle on new ground gives the same supply: forward first, when one is free and safe;
			if not fp.is_empty():               # else one at home, _nb_supply_turtle_spot)
				spot = fp[0]
	elif _nb_next_father(q) != "":
		k = _nb_next_father(q)
	elif _under_armed() and _army_supply_now() < 30 and maws >= 4:
		pass          # (brood-ai-tune: under-armed, warriors before more ground: round B g07 had 3 Raptors from 4:00 to 8:00
		              # while every 100 food went into Rootmaws and turtles on new ground and the Crown's army reached 1,360)
	elif maws < _nb_wanted_maws() and (maws < 3 or not _nb_saving_growth(q)) and _nb_maw_room(q):
		# (brood-ai-tune: no "100 food in hand" gate any more: the rushes spent every 50 food on Raptors, so their third
		# Rootmaw waited from 2:00 to 8:30 and the grubs stood at 14; now the food is kept for it like any structure)
		k = BroodNew.MAW
	elif _nb_far_have(q) < _nb_far_wanted() and not _nb_saving_growth(q):          # (her stage before more ground: the Economy plan never grew her)
		var picks := _nb_far_spots(q)
		if not picks.is_empty():
			k = BroodNew.TURTLE
			spot = picks[0]
	if k == "" and maws < _nb_wanted_maws() and not _nb_saving_growth(q) and not _nb_maw_room(q) and not (_under_armed() and _army_supply_now() < 30) \
			and _nb_far_have(q) < 6:
		var more := _nb_far_spots(q, 40.0)    # (0.24.7: no room left for a Rootmaw: one more turtle on new ground makes room,
		                                      # farther out than the planned expansions)
		if not more.is_empty():
			k = BroodNew.TURTLE
			spot = more[0]
	if k != "" and BroodRoot.morph_problem(game, team, k).begins_with("Need more supply"):
		k = BroodNew.TURTLE          # (a Sire takes more supply than his grub: a turtle first)
		spot = null
	if k == "" or grubs < 3:
		return
	var why := BroodRoot.morph_problem(game, team, k)
	if why != "":
		if why.begins_with("Not enough") and _food() < int(game.unit_price(team, k)[0]):
			_morph_keep += int(game.unit_price(team, k)[0])      # (saving for it: the eggs wait; only when FOOD is what is short:
			                                                    # food kept for a Sire whose spoils were short stalled eggs and Rootmaws)
		return
	if spot == null:
		spot = _nb_spot_for(q, k, null)
	if spot == null:
		return
	var best: Unit = null
	for u in game.units:
		if u.team == team and not u.dead and u.kind == "grub" and u.carrying == 0 and u.cocoon <= 0.0 and u.order != "nb_morph" \
				and u != _scout and (best == null or u.position.distance_squared_to(spot) < best.position.distance_squared_to(spot)):
			best = u
	if best != null and not _layout_ok(k, spot, null):
		return
	if best != null:
		BroodRoot.memo_end()
		best.give({"o": "nb_morph", "k": k, "p": spot})      # (it pays at once: BroodRoot.start_morph)
		if BroodNew.is_father(k):
			say("a grub goes to grow the %s" % BroodRoot.lure_name(k))
		elif k == BroodNew.TURTLE and (spot as Vector2).distance_to(_qp(q)) >= float(Defs.NB["expansion_tiles"]) * Defs.TILE * 0.9:
			_far_sent[str((spot as Vector2).round())] = game.clock
			_far_last = game.clock
			say("a grub goes to root a Mound Turtle on new ground, %d tiles out" % int((spot as Vector2).distance_to(_qp(q)) / Defs.TILE))


## Room for one more Rootmaw (0.24.7: its 8-tile circles leave 2 or 3 round her and one round each turtle; with none
## free the next branch (a turtle on new ground) gets its turn instead of the morph waiting for a spot for ever).
## Checked at most every 5 s.
var _room_t := -99.0
var _room := true


func _nb_maw_room(q: Unit) -> bool:
	if game.clock - _room_t >= 5.0:
		_room_t = game.clock
		_room = _nb_find_spot(q, null) != null
	return _room


## The best free turtle spots on new ground (ExpansionSpots.nb_pick: room for Rootmaws, ways in, walk, safety), reachable.
var _far_sent := {}               # far spot -> when a grub was last sent there (a grub killed on the way: not again soon)
var _far_last := -999.0


func _nb_far_spots(q: Unit, reach := 0.0) -> Array:
	var out: Array = []
	if game.exp_spots == null or game.clock - _far_last < 45.0:
		return out
	var picks: Array = _nb_eco_sites(q) if _eco() else ExpansionSpots.nb_pick(game, team, game.exp_spots)
	for s in picks:
		var p := BroodRoot.feet_at(BroodNew.TURTLE, s["tc"])
		if BroodRoot.place_problem(game, team, BroodNew.TURTLE, p, null, true) != "":
			continue
		if game.clock - float(_far_sent.get(str(p.round()), -999.0)) < 180.0:
			continue          # (tried lately: the grub did not get there)
		if p.distance_to(_qp(q)) > (reach if reach > 0.0 else (28.0 if _eco() and not BroodNew.expansions(game, q).is_empty() else 30.0)) * Defs.TILE:
			continue          # (too far to guard: near the enemy's side)
		if _foe_near(p, 12.0 * Defs.TILE):
			continue
		out.append(p)
	return out


## THE OWNER'S BUILD (2026-10-30 07:15, docs/brood_eco.md): the plan's "eco" (every profile but the rushes). The first
## Mound Turtle goes on the NATURAL expansion (the nearest turtle spot by walk that counts as new ground), the third
## Rootmaw at the natural's FAR edge (the farther a load comes, the more it pays and the more grubs a Rootmaw takes:
## Game.food_at, BroodNew.crew_max), grubs nonstop, the second turtle on the THIRD expansion with a Rootmaw there.
func _eco() -> bool:
	return bool(plan.get("eco", false))


## The turtle spots on new ground in WALK order (the natural first, then the third), free and fresh as nb_pick has them
## (ExpansionSpots: its candidates, rated once; nb_pick's tests, without its "two best" cut).
func _nb_eco_sites(q: Unit) -> Array:
	var es: ExpansionSpots = game.exp_spots
	ExpansionSpots.nb_pick(game, team, es)          # (rates the candidates once)
	var far := float(Defs.NB["expansion_tiles"]) * Defs.TILE
	var counted: Array = BroodNew.expansions(game, q)
	var out: Array = []
	for s in es.nb_cands.get(team, []):
		var feet := BroodRoot.feet_at(BroodNew.TURTLE, s["tc"])
		if _qp(q).distance_to(feet) < far or counted.any(func(o: Unit) -> bool: return o.position.distance_to(feet) < far):
			continue
		var taken := false
		for u in game.units_near(feet, 7.0 * Defs.TILE):
			if u.team == team and u.kind == BroodNew.TURTLE and not u.dead and u.tesla_mode != "packed":
				taken = true
		if taken or es._taken(s["c"]) or BroodRoot.place_problem(game, team, BroodNew.TURTLE, feet).begins_with("Blocked"):
			continue
		var spent := false
		for id in game.nb_spots:
			var sp: Dictionary = game.nb_spots[id]
			if (sp["p"] as Vector2).distance_to(feet) < float(Defs.NB["turtle_swamp"]) * Defs.TILE and float(sp["left"]) < float(Defs.PIT_GROUND) * 0.5:
				spent = true
		if not spent:
			out.append(s)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["home"]) < float(b["home"]))
	return out


func _foe_near(p: Vector2, r: float) -> bool:
	for u in game.units_near(p, r):
		if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_worker() and game.is_visible_to(team, u.position):
			return true
	return false


## The later Sires, in the plan's order and time: the Storm Sire first when the enemy flies (it needs her stage 2 and
## 50 spoils), else the Venom Sire at the plan's time, the Storm Sire at his. One of each.
func _nb_next_father(q: Unit) -> String:
	if BroodNew.count_of(game, team, BroodNew.FATHERS[0]) == 0 or BroodNew.count_of(game, team, BroodNew.MAW) < 2:
		return ""
	if _rush_on() and game.clock < 300.0 and not riders_about():
		return ""          # (warriors first while a rush is on; against riders the Venom Sire's Spitters are the answer)
	var order: Array = [BroodNew.DILO, BroodNew.PTERO]
	var storm_t := float(plan["storm"])
	if seen_air >= 2:
		order = [BroodNew.PTERO, BroodNew.DILO]
		storm_t = 0.0
	for f in order:
		var at := _sire_at(f) if f == BroodNew.DILO else minf(storm_t, _sire_at(f))
		if game.clock < at or BroodNew.count_of(game, team, f) > 0:
			continue
		if f == BroodNew.DILO and bb != null and bb.sire_first() and BroodRoot.morph_problem(game, team, f) == "Not enough biomass.":
			return f          # (the written build: the food is saved for him, _nb_morphs)
		if BroodNew.stage(q) < BroodNew.father_stage(f) or BroodRoot.morph_problem(game, team, f) != "":
			if f == BroodNew.PTERO and seen_air >= 2:
				return ""          # (wait for him: her stage 2 and his spoils come first)
			continue
		return f
	return ""


func _nb_spot_for(q: Unit, k: String, me: Unit):
	match k:
		BroodNew.TURTLE:
			return _nb_turtle_spot(q, me)
		BroodNew.MAW:
			return _nb_find_spot(q, me)
	return _nb_father_spot(q, me, k)


## Mound Turtles root a few tiles round the Mother, spread out (their swamp joins hers), never on the ramps.
func _nb_turtle_spot(q: Unit, me: Unit):
	BroodRoot.batch_begin(game, team)          # (a search batch: the same answers, the units listed once)
	var r = _nb_turtle_spot_go(q, me)
	BroodRoot.batch_end()
	return r


func _nb_turtle_spot_go(q: Unit, me: Unit):
	var home := BroodRoot.home_region(game, _qp(q))
	# (start-spots-fix: the ring is laid in this side's first-start frame, as the first start always laid it, and each spot
	# mirrored back: BroodRoot.feet_k / sym_snap)
	var qk := BroodRoot.feet_k(game, team, q)
	for ring in [7.0, 9.0, 11.0, 13.0]:
		for i in 12:
			var pr: Vector2 = qk + Vector2.from_angle(TAU * i / 12.0 + ring) * ring * Defs.TILE
			var p_k: Vector2 = BroodRoot.snap(BroodNew.TURTLE, pr)
			var p: Vector2 = BroodRoot.sym_snap(game, team, BroodNew.TURTLE, pr)
			var c: Vector2i = game.sym_rect(team, game.cell_of(p_k), Vector2i.ONE)
			if not _nb_on_map(p_k) or not game._walkable(c) or game.region_of(c) != home:
				continue
			if BroodRoot.place_problem(game, team, BroodNew.TURTLE, p, me, true) != "" or _spot_bad(p):
				continue
			var ok := true
			for o in BroodRoot._bt_mine:
				if o != me and o.team == team and (o.kind == BroodNew.TURTLE or o.kind == BroodNew.MAW) and not o.dead and BroodRoot.feet_k(game, team, o).distance_to(p_k) < 5.0 * Defs.TILE:
					ok = false
					break
			if ok:
				return p
	return _nb_supply_turtle_spot(q, me)


## SUPPLY TURTLES (the owner's playtest 2026-11-03, Thornwood Maze: the Economy Brood sat at 76/76 supply from 6:00 to
## 12:00 with 11,000 food banked; the owner: "building turtles are necessary to expand the supply, not only to expand...
## if they need more supply, they can build turtles in their base as well"). With no room left on the rings round the
## Mother, a turtle roots ANYWHERE legal on or beside its own swamp: round the Mother farther out, round each rooted
## turtle (home or new ground), packed closer (3 tiles from the others instead of 5), on any level ground it can walk
## to; the spot nearest the Mother first, away from the enemy. docs/raid_micro.md F.
func _nb_supply_turtle_spot(q: Unit, me: Unit):
	BroodRoot.batch_begin(game, team)          # (a search batch: the same answers, the units listed once)
	var r = _nb_supply_turtle_spot_go(q, me)
	BroodRoot.batch_end()
	return r


func _nb_supply_turtle_spot_go(q: Unit, me: Unit):
	var centres: Array = [BroodRoot.feet_k(game, team, q)]        # (start-spots-fix: in this side's first-start frame)
	for t in _nb_mine(BroodNew.TURTLE):
		if t != me and BroodNew.rooted(t):
			centres.append(BroodRoot.feet_k(game, team, t))
	var qreg := game.region_of(game.cell_of(_qp(q)))
	var qk := BroodRoot.feet_k(game, team, q)
	var best = null
	var bs := INF
	for cpos in centres:
		for ring in [5.0, 7.0, 9.0, 11.0, 13.0, 15.0, 17.0]:
			for i in 16:
				var pr: Vector2 = (cpos as Vector2) + Vector2.from_angle(TAU * i / 16.0 + ring * 0.37) * ring * Defs.TILE
				var p_k: Vector2 = BroodRoot.snap(BroodNew.TURTLE, pr)
				var p: Vector2 = BroodRoot.sym_snap(game, team, BroodNew.TURTLE, pr)
				var c: Vector2i = game.sym_rect(team, game.cell_of(p_k), Vector2i.ONE)
				if not _nb_on_map(p_k) or not game._walkable(c) or _spot_bad(p):
					continue
				var s := p_k.distance_to(qk) + (0.0 if game.region_of(c) == qreg else 300.0)
				if s >= bs:
					continue
				if _foe_near(p, 10.0 * Defs.TILE):
					continue
				if BroodRoot.place_problem(game, team, BroodNew.TURTLE, p, me, true) != "":
					continue
				var ok := true
				for o in BroodRoot._bt_mine:
					if o != me and o.team == team and (o.kind == BroodNew.TURTLE or o.kind == BroodNew.MAW) and not o.dead and o.position.distance_to(p) < 3.0 * Defs.TILE:
						ok = false
						break
				if ok:
					bs = s
					best = p
		if best != null and cpos == _qp(q):
			break          # (round the Mother found one: the nearest is good enough)
	return best


## A father's nest: beside the Mother, three quarters of his reach out (clear of her nest and of the other fathers'),
## the spot nearest him.
func _nb_father_spot(q: Unit, me: Unit, k: String = BroodNew.FATHER):
	var home := BroodRoot.home_region(game, _qp(q))
	var reach := float(Defs.NB["father_r"]) * Defs.TILE
	var qk := BroodRoot.feet_k(game, team, q)        # (start-spots-fix: in this side's first-start frame, mirrored back)
	var from: Vector2 = BroodRoot.feet_k(game, team, me) if me != null else qk + Vector2(0, reach)
	for frac in [0.75, 0.6, 0.9, 0.5, 1.0]:
		var best = null
		var best_k := Vector2.INF
		for i in 24:
			var pr: Vector2 = qk + Vector2.from_angle(TAU * i / 24.0) * reach * frac
			var p_k: Vector2 = BroodRoot.snap(k, pr)
			var p: Vector2 = BroodRoot.sym_snap(game, team, k, pr)
			var c: Vector2i = game.sym_rect(team, game.cell_of(p_k), Vector2i.ONE)
			if not _nb_on_map(p_k) or not game._walkable(c) or game.region_of(c) != home:
				continue
			if BroodRoot.place_problem(game, team, k, p, me, true) != "" or BroodRoot.rect_for(k, p).intersects(_nb_mother_ground(q)) or _spot_bad(p):
				continue
			if best == null or p_k.distance_to(from) < best_k.distance_to(from):
				best = p
				best_k = p_k
		if best != null:
			return best
	return null


## A Mound Turtle that is up (it was uprooted): walked to a spot and rooted there (ROOT like BUILD).
func _nb_turtles(q: Unit) -> void:
	for t in _nb_mine(BroodNew.TURTLE):
		if t.tesla_mode != "packed" or t.order == "nb_root" or t.target != null or held.has(t) or t == _front_t:
			continue
		var goal = _nb_turtle_spot(q, t)
		if goal != null:
			_root_to(t, goal)


func _nb_rootmaws(q: Unit) -> void:
	for m in _nb_mine(BroodNew.MAW):
		if BroodNew.rooted(m) and float(m.nb.get("food", 0.0)) < 1.0 and BroodNew.ground_left(game, m) < 1.0:
			BroodNew.uproot(m, true)          # spent: off to fresh ground
			continue
		if m.tesla_mode != "packed" or m.target != null or m.order == "nb_root" or held.has(m) or _maw_fight.has(m):
			continue
		var goal = _nb_find_spot(q, m)
		if goal != null:
			_root_to(m, goal)        # (it walks there and roots on that spot)


## ROOT a creature at a spot (ROOT like BUILD). A spot it was sent to lately and never rooted on (blocked, or no way to
## it: a Tyrant Sire walked to the same unreachable nest for five minutes in a test game, and no Raptor was laid) is
## left alone for 3 minutes; the spot finders skip it (_spot_bad).
var _root_last := {}            # creature id -> [spot, clock]
var _nb_bad_spots := {}            # spot (rounded) -> until when


func _root_to(u: Unit, p: Vector2) -> void:
	var id: int = u.get_instance_id()
	if not _layout_ok(u.kind, p, u):
		return
	var last = _root_last.get(id)
	if last != null and (last[0] as Vector2).distance_to(p) < Defs.TILE and game.clock - float(last[1]) < 40.0:
		_nb_bad_spots[str(p.round())] = game.clock + 180.0
		_root_last.erase(id)
		return
	if last == null or (last[0] as Vector2).distance_to(p) >= Defs.TILE:
		_root_last[id] = [p, game.clock]
	u.give({"o": "nb_root", "p": p})


## A creature on its way to root for more than 30 s (it can't get there: jostled on a crowded spot, a path that never
## ends) is stopped and the spot left alone; it is sent somewhere else on the next think.
var _root_since := {}           # creature id -> [spot, clock first seen on its way there]


func _nb_root_watch() -> void:
	var seen := {}
	for u in game.units:
		if u.team != team or u.dead or u.order != "nb_root":
			continue
		var id: int = u.get_instance_id()
		seen[id] = true
		var r = _root_since.get(id)
		if r == null or (r[0] as Vector2).distance_to(u.order_point) > 1.0:
			_root_since[id] = [u.order_point, game.clock]
		elif game.clock - float(r[1]) > 30.0:
			_nb_bad_spots[str(u.order_point.round())] = game.clock + 180.0
			_root_since.erase(id)
			u.cmd_stop()
	for id in _root_since.keys():
		if not seen.has(id):
			_root_since.erase(id)


var _bad_at := {}                  # (a bad spot's key -> its point, read once: str_to_var for every spot asked was slow)


## THE BASE LAYOUT (brood-layout; the owner, 2026-11-04 19:57: "the turtle-locked units are stuck inside"): the spot a
## spot finder picked (each already passed BroodRoot.place_problem's quick check round the spot) is checked once on the
## whole map (BroodLayout.exact); one that would shut ground or its own units off is left alone for a minute, and the
## finder picks another on the next think.
var layout_refused := 0             # (the study: spots refused by the whole-map check)


func _layout_ok(k: String, p: Vector2, me: Unit) -> bool:
	var why := BroodLayout.exact(game, team, k, p, me, BroodRoot.scale_of(me) if me != null and me.kind == k else 1.0)
	if why == "":
		return true
	_nb_bad_spots[str(p.round())] = game.clock + 60.0
	layout_refused += 1
	say("layout: not a %s there (%s)" % [String(Defs.UNITS[k]["name"]) if Defs.UNITS.has(k) else k, why])
	return false


## THE SAFETY NET (brood-layout): its own units shut in a pocket by its own rooted creatures (the Mother rooted back on
## her home, a creature rooted before the rule, a cocoon opening): the rooted creature that closes the pocket on the
## open map (a Rootmaw first, then a Sire, then a Mound Turtle feeding no Rootmaw; never the Mother) UPROOTS, keeping
## its food, and the computer roots it elsewhere (its spot finders now keep the way open); with none, the units walk out
## through their own creatures (BroodRoot's pass). Every 3 s.
var _unstick_t := -99.0
var unstuck_uproots := 0           # (the study)
var unstuck_passes := 0
var _in_pocket := {}               # units seen in a pocket on the last check


func _nb_unstick(_q: Unit) -> void:
	if BroodLayout.off or game.clock - _unstick_t < 3.0:
		return
	_unstick_t = game.clock
	var pk := BroodLayout.pockets(game, team)
	var seen := {}
	for r in pk.keys():
		# (only a pocket seen on two checks in a row: a unit pushed aside by a creature rooting by it, a hatchling in the
		# nest, is out again by itself in a moment)
		var again := false
		for u in pk[r]:
			seen[u] = true
			if _in_pocket.has(u):
				again = true
		if not again:
			pk.erase(r)
	_in_pocket = seen
	for r in pk:
		var units: Array = pk[r]
		var b := BroodLayout.blocker(game, team, r)
		if b != null and not held.has(b):
			if b.kind == BroodNew.MAW:
				BroodNew.uproot(b, false)
			elif b.kind == BroodNew.TURTLE:
				BroodNew.uproot(b, false)
			else:
				b.cmd_uproot(false)
			_nb_bad_spots[str(b.position.round())] = game.clock + 120.0       # (not rooted there again)
			unstuck_uproots += 1
			say("layout: a %s uproots to let %d of its own out of a pocket" % [String(Defs.UNITS[b.kind]["name"]), units.size()])
			continue
		var sent := 0
		var ex := BroodLayout.exit_cell(game, (units[0] as Unit).position, team)      # (one way out for the pocket)
		if ex == Vector2.INF:
			continue
		for u in units:
			var cu := u as Unit
			var goal := cu.path_goal
			cu.nb_pass = BroodRoot.PASS_TIME
			if cu.order == "idle" or cu.order == "" or goal == Vector2.INF:
				cu.cmd_move(ex)
			else:
				cu._request_path(goal)
			sent += 1
		if sent > 0:
			unstuck_passes += sent
			say("layout: %d of its own walk out of a pocket through its rooted creatures" % sent)


func _spot_bad(p: Vector2) -> bool:
	for k in _nb_bad_spots.keys():
		if game.clock > float(_nb_bad_spots[k]):
			_nb_bad_spots.erase(k)
			_bad_at.erase(k)
			continue
		var v = _bad_at.get(k)
		if v == null and not _bad_at.has(k):
			v = str_to_var("Vector2" + String(k))
			_bad_at[k] = v
		if v is Vector2 and (v as Vector2).distance_to(p) < 2.0 * Defs.TILE:
			return true
	return false


## Inside the map, a tile in from its edge (Game.cell_of clamps a point off the map to the edge cell: a spot out
## there was taken for the edge's walkable cell, and the creature walked to the edge and stood stuck on its way).
func _nb_on_map(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, Vector2(Game.W, Game.H) * Defs.TILE).grow(-Defs.TILE).has_point(p)


## Fresh ground: a Rootmaw rooted there would have at least a third of a full ground (BroodNew.ground_at: what the
## ROOT ghost shows and what the Rootmaw gets), not spent ground.
func _nb_spot_ok(p: Vector2) -> bool:
	return BroodNew.ground_at(game, p) >= float(Defs.PIT_GROUND) / 3.0


## A Rootmaw's spot: on the swamp round the Mother first, then round the turtles on new ground (their swamp; a far
## turtle with Rootmaws round it is a real expansion), on fresh ground, a little away from the enemy.
func _nb_find_spot(q: Unit, m: Unit):
	BroodRoot.batch_begin(game, team)          # (a search batch: the same answers, the units listed once)
	var r = _nb_find_spot_go(q, m)
	BroodRoot.batch_end()
	return r


func _nb_find_spot_go(q: Unit, m: Unit):
	# (start-spots-fix: the rings are laid in this side's first-start frame, as the first start always laid them, and each
	# spot mirrored back: BroodRoot.feet_k / sym_snap)
	var centres: Array = [[_qp(q), [8.0, 11.0, 14.0, 17.0, 20.0], BroodRoot.feet_k(game, team, q)]]
	var far := float(Defs.NB["expansion_tiles"]) * Defs.TILE * 0.9
	for t in _nb_mine(BroodNew.TURTLE):
		if BroodNew.rooted(t) and t.position.distance_to(_qp(q)) >= far:
			centres.append([t.position, [4.5, 6.0, 7.5, 8.5], BroodRoot.feet_k(game, team, t)])
	var qk := BroodRoot.feet_k(game, team, q)
	var from: Vector2 = BroodRoot.feet_k(game, team, m) if m != null else qk
	var best = null
	var bs := INF
	for ci in centres.size():
		var cpos: Vector2 = centres[ci][0]
		var h := int(game.height[game.idx(game.cell_of(cpos))])
		var home := BroodRoot.home_region(game, cpos)
		for ring in centres[ci][1]:
			for i in 16:
				var pr: Vector2 = (centres[ci][2] as Vector2) + Vector2.from_angle(TAU * i / 16.0 + ring * 0.13) * ring * Defs.TILE
				var p_k: Vector2 = BroodRoot.snap(BroodNew.MAW, pr)
				var p: Vector2 = BroodRoot.sym_snap(game, team, BroodNew.MAW, pr)
				var c: Vector2i = game.sym_rect(team, game.cell_of(p_k), Vector2i.ONE)
				if not _nb_on_map(p_k) or not game._walkable(c) or game.region_of(c) != home:
					continue
				# (the ROOT checks: its footprint, on its side's swamp, its circle clear of the others' and of their plans)
				# (or where the swamp is spreading to, 1 tile a second: it will be there when the grub is)
				var soon := not BroodNew.on_swamp(game, team, p) and BroodNew.swamp_coming(game, team, p)
				# (quick no's first: off the swamp and not coming, or in another Rootmaw's circle, are place_problem's own
				# no's, so the answer is the same; it only skips the footprint walk for them)
				if not soon and not BroodNew.on_swamp(game, team, p):
					continue
				if _maw_circle_taken(p, m):
					continue
				if not _nb_spot_ok(p) or BroodRoot.place_problem(game, team, BroodNew.MAW, p, m, true, 1.0, not soon) != "" or _spot_bad(p):
					continue
				var s := p_k.distance_to(qk) * (1.0 if ci == 0 else 0.6) + (60.0 if int(game.height[game.idx(c)]) != h else 0.0) + p_k.distance_to(from) * 0.3
				if _eco():
					# (the owner's build: a Rootmaw at the FAR edge of the ground it roots on, the expansions first: a load
					# from farther pays more and the Rootmaw takes more grubs; its draw is the same, so fewer eggs make it pay)
					s = -p_k.distance_to(qk) * 0.5 + (0.0 if ci > 0 else 400.0) + (60.0 if int(game.height[game.idx(c)]) != h else 0.0) + p_k.distance_to(from) * 0.1
				var foe := _nb_nearest_foe_pos(p)
				if foe != Vector2.INF:
					s -= foe.distance_to(p) * 0.15         # (a little away from the enemy)
				if s >= bs:
					continue          # (the enemy near only adds to it: no better than the best whatever it says)
				if _foe_near(p, 10.0 * Defs.TILE):
					s += 2000.0
				if s < bs:
					bs = s
					best = p
	return best


## Inside an open Rootmaw's circle or a planned one's (BroodRoot.place_problem's Rootmaw rule, in a search batch).
func _maw_circle_taken(p: Vector2, me: Unit) -> bool:
	var rr := float(Defs.PIT_CLAIM) * Defs.TILE * 2.0
	for o in BroodRoot._bt_maws:
		if o == me or o.dead:
			continue
		if o.kind == BroodNew.MAW and o.tesla_mode != "packed" and o.position.distance_to(p) < rr:
			return true
		if o.team == team:
			var pl := BroodRoot.plan_of(o)
			if not pl.is_empty() and String(pl[0]) == BroodNew.MAW and (pl[1] as Vector2).distance_to(p) < rr:
				return true
	return false


func _nb_nearest_foe_pos(p: Vector2) -> Vector2:
	var best := Vector2.INF
	for o in game.enemies_of(team):
		var c: Vector2 = (Vector2(game.starts[o]) + Vector2(2.5, 2.0)) * Defs.TILE
		if best == Vector2.INF or c.distance_to(p) < best.distance_to(p):
			best = c
	return best


# ------------------------------------------------------------------ the Sires

## Each Sire: walked (flown) to a nest spot beside the Mother (ROOT like BUILD) and rooted there (he is one of the
## Brood's barracks: the eggs of his line are fertilised and hatch in it). Rooted too far from her (she moved), he gets
## up and follows.
func _nb_father(q: Unit) -> void:
	for fk in BroodNew.FATHERS:
		var f := BroodNew.father(game, team, fk)
		if f != null:
			_nb_one_father(q, f)


func _nb_one_father(q: Unit, f: Unit) -> void:
	if f in _wave or BroodRoot.in_cocoon(f) or _def.has(f):
		return          # (in the defence squad: _nb_defend gets him up and sends him; he roots again after)
	var d := f.position.distance_to(_qp(q))
	var reach := float(Defs.NB["father_r"]) * Defs.TILE
	var threat := _nb_threat(q) != Vector2.INF
	if f.tesla_mode == "deployed":
		if d > reach or (threat and _nb_sires_needed(q)):
			f.cmd_uproot(false)       # (no rooted creature attacks: to fight off a real attack at the Mother he gets up)
		return
	if threat and _nb_sires_needed(q):
		return          # (uprooted, he fights with the others: _nb_army; a scout or a few raiders near her do not keep him off his nest)
	if f.tesla_mode == "packed" and d > 14.0 * Defs.TILE and f.order != "move" and f.order != "nb_root":
		# (on a leash: an enemy he chased off from her could lead him across the map, and while he is away her
		# warrior eggs wait for him; seen in a 0.18.0 match, the Tyrannosaur 62 tiles off with 1,600 food banked)
		f.cmd_move(_qp(q))
		return
	if f.tesla_mode == "packed" and f.target != null and not _nb_sires_needed(q):
		f.cmd_stop()          # (a fight he picked up by himself, nothing at the Mother: back to his nest)
	if f.tesla_mode != "packed" or f.target != null or f.order == "nb_root":
		return
	var spot = _nb_father_spot(q, f, f.kind)
	if spot != null:
		_root_to(f, spot)
	elif d > 14.0 * Defs.TILE and f.order != "move":
		f.cmd_move(_qp(q))       # (on a leash: by her, never off after a scout)


# ------------------------------------------------------------------ eggs

## GROW her (the owner's tiers, 12:20: Hatchlings and the Storm Sire need her stage 2; Brutes, Mist Toads and Storm
## Challengers stage 3): from the plan's times it SAVES for it (_nb_saving_growth: warriors only out of what is above
## the price) and grows her once the price is there; never while enemies are at her or a rush is on.
func _nb_grow(q: Unit) -> void:
	if BroodNew.grow_problem(game, q) != "" or _nb_threat(q) != Vector2.INF or BroodResearch.busy(q):
		return
	var st := BroodNew.stage(q)
	if st >= (Defs.NB["stages"] as Array).size() - 1 or game.clock < _grow_at(st):
		return
	if _rush_on() and st == 0:
		return
	if _eco() and ((_alarm_on() and _value_of(_nb_army_units()) < seen_army * 0.8) or (seen_army >= 500.0 and _value_of(_nb_army_units()) < seen_army * 0.5)):
		return          # (brood-ai-tune: not 45-60 s without eggs while an enemy army is on its way, or one twice hers was
		                # seen lately: round B g07 grew to stage 3 at 9:36 with 1,075 of army against 2,440 seen, and fell)
	if not _nb_grow_time(q):
		return
	if BroodNew.count_of(game, team, BroodNew.FATHER) == 0:
		return          # (the Tyrant Sire first: without him no warriors at all)
	var nx: Dictionary = Defs.NB["stages"][st + 1]
	if _food() >= int(nx["cost"]) + _morph_keep and _spoils() >= float(nx.get("cost2", 0)):
		if BroodNew.grow(game, q) == "":
			say("grows the Mother to stage %d" % (st + 2))


## Food kept back for her next stage (from the plan's time on): warrior eggs only out of what is above it. Grubs and
## supply go on. Her stage 3 also wants its spoils (kept by _nb_spoils_keep).
## THE OWNER'S BUILD: her growth only once EGGS are what holds the Brood back (her clutch run down: EGG_LOW or fewer in
## the last EGG_BOUND s), or GROW_LATE s after the plan's time at the latest. In the first coached games of this round
## her clutch sat FULL (10 eggs) until 8:00: food, not eggs, held the Brood back, and 300 food and 45 s without laying
## for her stage 2 only took a minute of grubs away. (The Air rush keeps its times: the Storm line needs her stages.)
const EGG_LOW := 2
const EGG_BOUND := 45.0
const GROW_LATE := 240.0
var _egg_low_t := -999.0


## When her next stage may come: the plan's time, or at once in an eco plan whose eggs hold it back (brood-ai-tune:
## on today's economy Balanced was egg-bound from 4:30 and sat at stage 2 with 9,000 food for the rest of the game).
func _grow_at(st: int) -> float:
	var at := float(plan["grow"][mini(st, 1)])
	if _eco() and _nb_egg_bound() and not (int(plan["grubs0"]) > 0 and not _first_out):
		return minf(at, game.clock)
	return at


func _nb_grow_time(q: Unit) -> bool:
	if not _eco() or strategy == "air" or bool(plan.get("grow_now", false)):
		return true
	var st := BroodNew.stage(q)
	return game.clock - _egg_low_t < EGG_BOUND or game.clock >= float(plan["grow"][mini(st, 1)]) + GROW_LATE


func _nb_growth_keep(q: Unit) -> int:
	var st := BroodNew.stage(q)
	if st >= (Defs.NB["stages"] as Array).size() - 1 or float(q.nb.get("grow_t", 0.0)) > 0.0 or _rush_on():
		return 0
	if game.clock < _grow_at(st) or BroodNew.count_of(game, team, BroodNew.FATHER) == 0 or not _nb_grow_time(q):
		return 0
	var need2 := float(Defs.NB["stages"][st + 1].get("cost2", 0))
	if need2 > 0.0 and _spoils() < need2 * 0.6:
		return 0          # (her spoils are far off: saving food for her meanwhile only starves the army, round 2's trap)
	return int(Defs.NB["stages"][st + 1]["cost"])


func _nb_saving_growth(q: Unit) -> bool:
	return _nb_growth_keep(q) > 0 and _food() < _nb_growth_keep(q)


## Spoils kept for what comes first: her stage 3 (from its time), the Storm Sire (when wanted).
## EGG-BOUND (brood-ai-tune, 0.27.3): her clutch has run down (EGG_LOW or fewer) in the last EGG_BOUND s. On today's
## economy (far Rootmaws paying up to x2.5 since 0.24.28) the eco plans out-earn her laying from about 4:30: from then
## on EGGS, not food, hold the Brood back, and what lays faster comes first: her stages, the Sires (each +20% beside
## her), the turtles on new ground (+15% each, up to 3). These come by that state (as a build order goes by supply),
## the plan's clock only as the latest time.
func _nb_egg_bound() -> bool:
	return game.clock > 90.0 and game.clock - _egg_low_t < EGG_BOUND          # (not the opening's 3 eggs)


## RICH: egg-bound with food piling up. The food goes into what needs no egg: maturing, Brutes, research, the Sires
## and her stages, and Raptors offered up for the spoils those want (an offered-up pair gives its egg back).
func _nb_rich() -> bool:
	return _nb_egg_bound() and _food() >= RICH_FOOD


const RICH_FOOD := 600


## When a later Sire's lure is due: the plan's time, or as soon as eggs hold the Brood back (each Sire beside her lays
## 20% faster; his line opens too), or riders are about (the Venom Sire's Spitters answer them).
func _sire_at(f: String) -> float:
	var at := float(plan["venom"]) if f == BroodNew.DILO else float(plan["storm"])
	if f == BroodNew.DILO and riders_about() and not _rider_short():
		return 0.0          # (brood-anti-riders: the Raptors it is short of come first, the Venom Sire's 200 food after)
	if f == BroodNew.PTERO and bb != null and bb.hold_storm():
		return at          # (the written build: the Storm Sire waits for its push, unless flyers are seen)
	if _nb_egg_bound() and BroodNew.count_of(game, team, BroodNew.FATHER) > 0 and not (int(plan["grubs0"]) > 0 and not _first_out):
		return minf(at, game.clock)
	return at


func _nb_spoils_keep(q: Unit) -> float:
	var keep := 0.0
	# (brood-ai-tune, 0.27.3: a big bank used to return 0 here, "never sit on food for spoils". On today's economy the
	# bank is the rule from 5:00 on, so the Venom Sire's 25 spoils and her stage 3's 75 were never kept and no Raptor
	# was ever offered up for them: Balanced, Timing and Economy got no Venom Sire and no stage 3 in 15 minutes. The
	# spoils are kept now whatever the bank; food is never what waits for them)
	var st := BroodNew.stage(q)
	if bb != null and bb.spoils_first():
		st = -1          # (the written build: its own line's spoils before her stage 3's: the first Spitter timing trial
		                 # kept 75 for her stage 3 and laid no Spitter in the minute before its timing)
	if st == 1 and _nb_egg_bound() and _food() >= int(Defs.NB["stages"][2]["cost"]) - 150:
		keep = maxf(keep, float(Defs.NB["stages"][2]["cost2"]))
	if st == 1 and game.clock >= float(plan["grow"][1]) - 60.0 and _food() >= int(Defs.NB["stages"][2]["cost"]) - 150:
		keep = maxf(keep, float(Defs.NB["stages"][2]["cost2"]))      # (only once her food is nearly there: else the spoils work meanwhile)
	if st >= 1 and BroodNew.count_of(game, team, BroodNew.PTERO) == 0 and (seen_air >= 2 or game.clock >= float(plan["storm"]) - 30.0):
		keep = maxf(keep, float(Defs.UNITS[BroodNew.PTERO].get("cost2", 0)))
	if BroodNew.count_of(game, team, BroodNew.DILO) == 0 and _sire_at(BroodNew.DILO) - 45.0 <= game.clock and float(Defs.UNITS[BroodNew.DILO].get("cost2", 0)) > 0.0:
		keep = maxf(keep, float(Defs.UNITS[BroodNew.DILO].get("cost2", 0)))      # (the Venom Sire's spoils, when he costs any)
	if bb != null:
		keep = maxf(keep, bb.spoils_keep(q))          # (the written build: the Brutes' and their horns' spoils)
	return keep


## SPOILS (her stage 3, the Storm Sire, research, Brutes, Spitters, Hatchlings, maturing): grubs HARVEST the bodies near
## home (two at most, while there are bodies); and while that is not enough for what is wanted NOW, a Raptor at home
## (not in a wave, a home guard always kept) is offered up at the Mother (SACRIFICE), one every 4 s at most; none
## during an attack on her.
var _nb_offer_t := 0.0


func _nb_spoils_want(q: Unit) -> float:
	var want := _nb_spoils_keep(q)
	if BroodNew.count_of(game, team, BroodNew.FATHER) > 0 and game.clock >= 150.0 and not game.has_tech(team, "nb_clutch_raptor"):
		want = maxf(want, float(Defs.RESEARCH["nb_clutch_raptor"]["cost2"]) + 2.0)
	if bool(plan["pack"]) and not game.has_tech(team, "nb_pack_hunt") and _army_supply_now() * 10 >= _attack_at * 5:
		want = maxf(want, float(Defs.RESEARCH["nb_pack_hunt"]["cost2"]) + 2.0)
	if BroodNew.stage(q) >= 2 and (seen_wall or BroodNew.count_of(game, team, "brute") >= 2) and not game.has_tech(team, "nb_battering_horns"):
		want = maxf(want, float(Defs.RESEARCH["nb_battering_horns"]["cost2"]))
	if BroodNew.stage(q) >= 2:
		want = maxf(want, 45.0)          # (Brutes and Challengers)
	if _wall_foe() and BroodNew.count_of(game, team, BroodNew.DILO) > 0:
		want = maxf(want, 25.0)          # (against a wall: Spitters, 5 spoils an egg)
	if float(plan.get("spoils_bank", 0.0)) > 0.0 and BroodNew.count_of(game, team, BroodNew.FATHER) > 0 and game.clock >= 150.0:
		want = maxf(want, float(plan["spoils_bank"]))     # (the air rush: the Storm line's spoils, from offered-up Raptors)
	if _nb_rich() and BroodNew.stage(q) >= 1 and not _attacking:
		want = maxf(want, RICH_SPOILS)
	if bb != null:
		want = maxf(want, bb.spoils_want(q))          # (the written build: Spitter eggs, Brutes and their horns)          # (rich: spoils for maturing, Brutes and the lines' research)
	return want


const RICH_SPOILS := 80.0


## Raptors to be laid for spoils: the plan banks spoils ("spoils_bank": the Air rush) or its Storm Sire / her stage 3
## waits for them, and the spare Raptors at home are not enough to cover what is short.
func _nb_feed_raptors(q: Unit) -> bool:
	if _rush_on():
		return false
	# (the spoils kept for a Sire or her stage 3 are fed even while a wave is out: its Raptors are all in the wave, so
	# none at home was offered and Balanced's stage 3 waited for the wave to end; brood-ai-tune, test_ai_brood)
	if _nb_spoils_keep(q) <= 0.0 and ((float(plan.get("spoils_bank", 0.0)) <= 0.0 and not _nb_rich()) or _attacking):
		return false
	var short := _nb_spoils_want(q) - _spoils()
	if short <= 0.0:
		return false
	var spare := _nb_mine("raptor").filter(func(u: Unit) -> bool: return u.position.distance_to(_qp(q)) < 16.0 * Defs.TILE \
		and not _wave.has(u)).size() - maxi(2, int(plan["home_guard"]))
	return float(spare) * float(Game.sacrifice_value("raptor")) < short


func _nb_essence(q: Unit) -> void:
	var want := _nb_spoils_want(q)
	var have := _spoils()
	var grubs := _nb_mine("grub")
	var bodies := game.corpses.filter(func(c) -> bool: return is_instance_valid(c) and c.position.distance_to(_qp(q)) < 22.0 * Defs.TILE)
	var harvesting := grubs.filter(func(u: Unit) -> bool: return u.order == "harvest")
	if not bodies.is_empty() and _nb_threat(q) == Vector2.INF:
		for u in grubs:
			if harvesting.size() >= mini(5, 2 + bodies.size() / 4):        # (bodies pay double since 0.22.4 and each harvest feeds her veterancy)
				break
			if u.order == "gather" and u.carrying == 0 and not harvesting.has(u) and u != _scout:
				u.cmd_harvest()
				harvesting.append(u)
	elif bodies.is_empty():
		for u in harvesting:
			if u.cocoon <= 0.0:
				u.cmd_stop()          # (no bodies left: back to work, WORK finds it a Rootmaw)
	if have >= want or game.clock < _nb_offer_t or _nb_threat(q) != Vector2.INF or _rush_on() \
			or (int(plan["grubs0"]) > 0 and not _first_out):          # (a rush keeps every Raptor for its first wave)
		return
	var raptors := _nb_mine("raptor").filter(func(u: Unit) -> bool: return u.position.distance_to(_qp(q)) < 16.0 * Defs.TILE \
		and u.target == null and u.order != "sacrifice" and not _wave.has(u) and u != _scout)      # (at home, not fighting)
	if raptors.size() <= maxi(2, int(plan["home_guard"])):
		return
	for u in raptors:
		if u.can_sacrifice():
			u.cmd_sacrifice()
			_nb_offer_t = game.clock + 4.0
			return


## Her eggs: grubs and warriors only (the structure-units come from grubs: _nb_morphs).
func _nb_lay(q: Unit) -> void:
	var eggs := int(q.nb.get("eggs", 0))
	if eggs <= 0:
		return
	var food := _food()
	var grubs := BroodNew.count_of(game, team, "grub")
	var want_grubs := _nb_want_grubs()
	var k := ""
	# saving up for a structure-unit the economy needs: warriors only out of what is above its price
	var keep := _morph_keep          # (the structure-unit it saves for, or the one a grub is walking to: _nb_morphs)
	if _nb_short():
		keep = maxi(keep, 100)
	elif BroodNew.count_of(game, team, BroodNew.FATHER) == 0 and grubs >= int(plan["sire_g"]) - 1:
		keep = maxi(keep, int(Defs.UNITS[BroodNew.FATHER]["cost"]))          # (the Tyrant Sire's lure first)
	keep = maxi(keep, _nb_growth_keep(q) + (_morph_keep if _nb_growth_keep(q) > 0 else 0))
	var any_father := BroodNew.FATHERS.any(func(f) -> bool: return BroodNew.father_near(game, team, f))
	# grubs on the plan's curve ("drone": grubs a minute, from the 5 it starts with) come before warriors, unless the enemy
	# is at the Mother or a rush is on; above the curve only with food to spare
	var curve := 5.0 + game.clock / 60.0 * float(plan.get("drone", 4.0))
	var danger := _nb_threat(q) != Vector2.INF or _rush_short() or ((_alarm_on() or _under_armed()) and grubs >= 16)
	var rider_short := _rider_short() and BroodNew.father_near(game, team, BroodNew.FATHER)
	# (brood-anti-riders: with no Tyrant Sire yet no Raptor can be laid: grubs meanwhile, his lure's food kept; holding the
	# eggs from the read at 1:38 to his hatching at 2:25 cost the Economy games 4-5 grubs at 3:00)
	if danger and not rider_short and not _rush_short() and _nb_threat(q) != Vector2.INF and _riders_only_near(q) \
			and _value_of(_nb_army_units().filter(func(u: Unit) -> bool: return not _wave.has(u))) >= maxf(_foe_near_home * 1.3, 150.0):
		danger = false          # (brood-anti-riders: only riders (or Officers) by the Mother and warriors enough: the grubs go
		                        # on; a lone rider hovering there laid Raptors for minutes on 11 grubs, Hollowfen seed 7)
	if rider_short:
		danger = true           # (brood-anti-riders: Raptors until its army at home beats the riders it expects)
		keep = mini(keep, _morph_keep)          # (her growth waits; the Sire's lure does not)
		if BroodNew.count_of(game, team, BroodNew.FATHER) == 0:
			keep = maxi(keep, int(Defs.UNITS[BroodNew.FATHER]["cost"]))
	# (brood-ai-tune: the alarm's "warriors before grubs" only with 16 grubs or more: a Rush turned Balanced against the
	# Clockwork saw its army out every minute from 4:41, so the alarm never went off and its grubs stood at 9 to 14 until
	# 12:00, on a third of the Clockwork's income)
	if bb != null and bb.sire_first() and keep > 0 and grubs >= 10 and food - keep < 50:
		curve = 0.0          # (the written build: its Sire's food first, the grub curve after him)
	if grubs < want_grubs and (grubs < 6 or not any_father or (grubs < curve and not danger) or food - keep >= 200):
		k = "grub"
	# SPOILS FROM RAPTORS (the owner, 07:15: the Storm line and the Air rush are paid by offering Raptors up): while the
	# spoils wanted now are short and too few spare Raptors stand at home to offer, a Raptor egg comes before the grub
	# curve (with 12 grubs or more); _nb_essence offers them up as they hatch
	if k == "grub" and grubs >= 12 and _nb_feed_raptors(q) and BroodNew.father_near(game, team, BroodNew.FATHER) and food - keep >= 50:
		k = "raptor"
	if k == "" and any_father:
		k = _nb_warrior(food - keep)
	if k == "" or BroodNew.lay_problem(game, q, k) != "":
		if grubs < want_grubs and BroodNew.lay_problem(game, q, "grub") == "" and (food - 50 >= keep - (_nb_growth_keep(q) if grubs * 10 < want_grubs * 7 else 0) or grubs < 6):
			k = "grub"
		else:
			return
	if k == "grub" and food - 50 < keep - (_nb_growth_keep(q) if grubs * 10 < want_grubs * 7 else 0) and grubs >= 6:
		return          # (the workforce is far short: grubs come before her growth's savings)
	BroodNew.lay(game, q, k)


## Grubs wanted: a crew for each rooted Rootmaw (and those on their way), a couple to turn into things; held at the
## plan's early count until the first wave has left (a rush), never above its cap.
func _nb_want_grubs() -> int:
	var crew := 0
	for m in _nb_mine(BroodNew.MAW):
		crew += BroodNew.crew_max(game, m) if BroodNew.rooted(m) else 3
	var n := maxi(crew + 2, 6)
	if int(plan["grubs0"]) > 0 and not _first_out:
		n = mini(n, int(plan["grubs0"]))
	if _rush_short() and game.clock < 300.0:
		n = mini(n, 14)
	if bb != null:
		n = mini(n, bb.grub_cap())          # (the written build: grubs held until its push)
	return mini(n, int(plan["grubs"]))


## Which warrior egg out of `spend` food (what is above the reserve): a mix by the lines it has (each line only while
## its Sire is rooted beside her and not researching) and by her stage; the plan's mix decides the share of Spitters.
## HATCHLINGS only against enemy flyers it has SEEN (they bite only flyers: docs/storm_line.md), about two for each, and
## at her stage 3 a few more to mature into Storm Challengers. A Brute now and then at stage 3 (more against a wall), a
## Mist Toad per 12 army supply (up to 3).
func _nb_warrior(spend: int) -> String:
	var q := BroodNew.queen(game, team)
	var st := BroodNew.stage(q) if q else 0
	var spoils := _spoils() - _nb_spoils_keep(q)
	var trex := BroodNew.father_near(game, team, BroodNew.FATHER) and not BroodResearch.line_busy(game, team, BroodNew.FATHER)
	var dilo := BroodNew.father_near(game, team, BroodNew.DILO) and not BroodResearch.line_busy(game, team, BroodNew.DILO)
	var ptero := BroodNew.father_near(game, team, BroodNew.PTERO) and st >= BroodNew.unit_stage("hatchlings") and not BroodResearch.line_busy(game, team, BroodNew.PTERO)
	var toads_ok := dilo and st >= BroodNew.unit_stage("mist_toad")
	var brutes_ok := trex and st >= BroodNew.unit_stage("brute")
	var raptors := BroodNew.count_of(game, team, "raptor") + BroodNew.count_of(game, team, "tyrant_challenger")
	var spitters := BroodNew.count_of(game, team, "spitter") + BroodNew.count_of(game, team, "venom_challenger")
	var toads := BroodNew.count_of(game, team, "mist_toad")
	var brutes := BroodNew.count_of(game, team, "brute")
	var hatch := BroodNew.count_of(game, team, "hatchlings")
	var storm := BroodNew.count_of(game, team, "storm_challenger")
	var army := _army_supply_now()
	var price := func(k: String) -> Array: return game.unit_price(team, k)
	if ptero and spoils >= float(price.call("hatchlings")[1]) and spend >= int(price.call("hatchlings")[0]):
		var air := hatch + storm * 2
		if (seen_air > 0 and air < mini(HATCH_MAX, seen_air * HATCH_PER_FLYER)) \
				or (st >= BroodNew.unit_stage("storm_challenger") and hatch + storm < STORM_WANT and raptors + spitters >= 6) \
				or (hatch + storm < int(plan.get("storm_want", 0))):          # (the air plan: Hatchlings to mature into Storm Challengers)
			return "hatchlings"
	if toads_ok and spoils >= 25.0 and spend >= 100 and toads < mini(3, army / 12):
		return "mist_toad"
	var bcap: int = bb.brute_cap() if bb != null else 0
	if brutes_ok and (_spoils() if bcap > 0 else spoils) >= 20.0 and spend >= 150 and ((bcap > 0 and brutes < bcap) \
			or (brutes < (6 if seen_wall else 4) and brutes * 6 < raptors + spitters + 2)):
		return "brute"
	var venom_share := {"tyrant": 4, "mixed": 2, "venom": 1}.get(String(plan["mix"]), 2) as int      # (one Spitter for this many Raptors)
	if _wall_foe() and String(plan["mix"]) != "tyrant":
		venom_share = 1          # (round 3: Raptors alone die on a musket wall; Spitters reach the shooters)
	if riders_about():
		venom_share = 1          # (riders about: Spitters shoot what the Sire can't catch, docs/raid_micro.md D)
	var sp_price: Array = price.call("spitter")
	if dilo and spoils >= float(sp_price[1]) and spend >= int(sp_price[0]) and (not trex or spitters * venom_share < raptors + 2):
		return "spitter"
	if dilo and bb != null and bb.save_for_spitters(spitters, raptors) and spoils >= float(sp_price[1]):
		return ""          # (the written build: food is kept for the next Spitter egg, not spent on Raptors meanwhile)
	if brutes_ok and bb != null and bb.save_for_brutes(q) and _spoils() >= 20.0 and spend < 150:
		return ""          # (the written build: food is kept for the next Brute)
	if trex and spend >= int(price.call("raptor")[0]):
		return "raptor"
	if dilo and spoils >= float(sp_price[1]) and spend >= int(sp_price[0]):
		return "spitter"
	return ""


## MATURE (YOUNG AND MATURE, scripts/brood_mature.gd): young units resting near home (no target, not in a wave) mature
## when food piles up (the plan's "bank") or while an attack gathers ("push": the wave's young first), up to
## MATURE_EACH a think, keeping MATURE_KEEP food back; at most half of each young kind (both forms matter: the young
## ones' numbers, the mature ones' toughness). Hatchlings all mature when no enemy flyer was seen (they are useless
## against the ground), half with flyers about.
const MATURE_FOOD := 300
const MATURE_KEEP := 150
const MATURE_EACH := 2
## The Storm line (docs/storm_line.md): Hatchlings for each enemy flyer seen, at most; the Storm line it keeps at her stage 3
const HATCH_PER_FLYER := 2
const HATCH_MAX := 16
const STORM_WANT := 4


func _nb_mature(q: Unit) -> void:
	if _nb_saving_growth(q) or BroodNew.stage(q) < 1:
		return
	var food := _food()
	var push: bool = String(plan["mature"]) == "push" and _army_supply_now() * 10 >= _attack_at * 7 and not _attacking
	if food < (MATURE_FOOD if not push else 200):
		return
	var each := MATURE_EACH * (2 if _nb_rich() else 1)          # (rich and egg-bound: food that no egg can take)
	var n := 0
	for yk in Defs.NB["mature"]:
		var mk := String(Defs.NB["mature"][yk])
		if BroodNew.stage(q) < BroodNew.unit_stage(mk):
			continue
		var young := _nb_mine(String(yk))
		var grown := _nb_mine(mk).size()
		var all_up: bool = yk == "hatchlings" and seen_air == 0
		for u in young:
			if n >= each or (grown * 2 >= young.size() + grown and not all_up):
				break
			if u.moult_t >= 0.0 or (u.target != null and is_instance_valid(u.target)) or in_wave(u) or u == _scout \
					or u.position.distance_to(_qp(q)) > 22.0 * Defs.TILE:
				continue
			var p := BroodMature.price(game, team, u.kind)
			if _food() - int(p[0]) < MATURE_KEEP + _morph_keep or _spoils() - float(p[1]) < _nb_spoils_keep(q) or BroodMature.problem(u) != "":
				continue
			BroodMature.start(u)
			n += 1
			grown += 1


# ------------------------------------------------------------------ research

## THE BROOD'S RESEARCH (scripts/brood_research.gd), sensibly and without starving the army (docs/design_principles.md 4:
## every choice an opportunity cost): never with enemies at her or while saving for her growth; only with the price
## and a reserve in hand; ONE Sire researching at a time (a Sire researching fathers nothing, so the army keeps coming
## from the others; the Tyrant Sire's research only while the Mother has eggs stocked); the Mother's alongside. In order:
##  - BIGGER CLUTCH on the Raptors early (from about 2:30, once a few Raptors stand);
##  - PACK HUNT before the first attack (the plan's "pack": the army at half the wave) or while attacking;
##  - BATTERING HORNS before a siege: her stage 3 with Brutes, or a wall seen;
##  - the Venom line's BIGGER CLUTCH once Spitters are laid (4), SLITHER and LONG SPIT with 6 of the line;
##  - the Storm line's BIGGER CLUTCH with 4 Hatchlings and flyers seen (3 or more); UPDRAFT with 4 of the line;
##  - QUICK ROOTS mid game (her stage 2, from 8:00), SWAMP MENDING later (from 10:00, food to spare).
const RES_KEEP := 100


func _nb_research(q: Unit) -> void:
	if _nb_threat(q) != Vector2.INF or (_nb_saving_growth(q) and BroodNew.stage(q) == 0) or peaceful or (_rush_on() and game.clock < 300.0):
		return
	if _rider_short() or (_riders_on() and _rider_hit_t < 0.0):
		return          # (brood-anti-riders: a Sire researching fathers no eggs: Bigger Clutch at 3:31-3:33 cost two
		                # Hollowfen games their Raptors while the riders came; it waits till they have come and its
		                # warriors are enough)
	var food := _food()
	var spoils := _spoils()
	var keep := RES_KEEP + (150 if difficulty == 0 else 0) + _morph_keep
	var st := BroodNew.stage(q)
	var keep2 := _nb_spoils_keep(q)
	var sup := _army_supply_now()
	var sire_busy := BroodNew.FATHERS.any(func(f) -> bool: return BroodResearch.busy(BroodNew.father(game, team, f)))
	var line := func(k: String) -> int: return BroodNew.count_of(game, team, k)
	var soon: bool = _attacking or sup * 10 >= _attack_at * 5
	var want: Array = []
	if not sire_busy and bb != null:
		want.append_array(bb.research_first())          # (the written build's research first)
	if not sire_busy and not (bb != null and bb.research_only()):
		if bool(plan["pack"]) and soon and line.call("raptor") + line.call("tyrant_challenger") >= 6:
			want.append("nb_pack_hunt")
		if game.clock >= (210.0 if strategy in ["rush", "xrush"] else 150.0) and line.call("raptor") >= 4:
			want.append("nb_clutch_raptor")
		if (soon or _attacking) and line.call("raptor") + line.call("tyrant_challenger") >= 10:
			want.append("nb_pack_hunt")
		if st >= 2 and (line.call("brute") >= 2 or seen_wall):
			want.append("nb_battering_horns")
		if line.call("spitter") >= 4:
			want.append("nb_clutch_spitter")
		if line.call("spitter") + line.call("venom_challenger") >= 6:
			want.append("nb_long_spit")
			want.append("nb_slither")
		if line.call("hatchlings") >= 4 and seen_air >= 3:
			want.append("nb_clutch_hatchlings")
		if line.call("hatchlings") + line.call("storm_challenger") >= 4:
			want.append("nb_updraft")
	# THE MIST TOAD's spells (Defs.RESEARCH nb_fog, nb_miasma at the Dilophosaurus) once it has Toads: FOG first (its use
	# in a fight: AI._toad), MIASMA after; cheap, and wanted even while another Sire researches (a Toad without them is a lick)
	if line.call("mist_toad") >= 1:
		want.push_front("nb_miasma")
		want.push_front("nb_fog")
	if st >= 1 and game.clock >= 480.0:
		want.append("nb_quick_roots")
	if st >= 1 and game.clock >= 600.0 and food >= 400:
		want.append("nb_swamp_mending")
	for key in want:
		if game.has_tech(team, key) or BroodResearch.in_hand(game, team, key):
			continue
		var info: Dictionary = Defs.RESEARCH[key]
		# (the army's own research, Bigger Clutch, Pack Hunt and Battering Horns, never waits for her stage's spoils)
		var k2 := 0.0 if key in ["nb_clutch_raptor", "nb_pack_hunt", "nb_battering_horns"] or (bb != null and bb.research_first().has(key)) else keep2
		if food < int(info["cost"]) + keep or spoils < float(info.get("cost2", 0)) + k2:
			continue
		var at: String = info["at"]
		var who: Unit = q if at == BroodNew.QUEEN else BroodNew.father(game, team, at)
		if who == null or BroodResearch.busy(who) or BroodResearch.problem(game, who, key) != "":
			continue
		if BroodResearch.start(game, who, key) == "":
			say("researches %s" % String(info.get("name", key)))
		return


# ------------------------------------------------------------------ the army

func _nb_army_units() -> Array:
	return game.units.filter(func(u: Unit) -> bool: return u.team == team and not u.dead and not u.is_worker() \
		and not BroodNew.is_nb(u.kind) and u.kind != "horse")


func _army_supply_now() -> int:
	var s := 0
	for u in _nb_army_units():
		if u.kind != "hatchlings" or seen_air > 0:
			s += int(u.d["supply"])
	return s


func _value_of(list: Array) -> float:
	var v := 0.0
	for u in list:
		if is_instance_valid(u) and not u.dead:
			v += float(Game.unit_value(u))
	return v


## An enemy near the Mother (13 tiles), or Vector2.INF.
func _nb_threat(q: Unit) -> Vector2:
	for u in game.units_near(_qp(q), 13.0 * Defs.TILE):
		if game.hostile(u.team, team) and not u.dead and not u.off_field:
			return u.position
	return Vector2.INF


## The attack at her is more than a scout or a lone rider (its Sires get up for it).
func _nb_threat_big(q: Unit) -> bool:
	var v := 0.0
	for u in game.units_near(_qp(q), 14.0 * Defs.TILE):
		if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_worker():
			v += float(Game.unit_value(u))
	return v >= 120.0


## The Sires get up for an attack at the Mother only when it is big and her army can't hold it alone (a Sire away from
## his nest fathers nothing, and a dead one stops his line for minutes: round 3's games lost their Tyrant Sire this way).
## Fast riders are left out: the Sire never catches one (docs/raid_micro.md D; the owner: "keep the Tyrant rooted").
func _nb_sires_needed(q: Unit) -> bool:
	if not _nb_threat_big(q):
		return false
	var v := 0.0
	for u in game.units_near(_qp(q), 14.0 * Defs.TILE):
		if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_worker() and not is_rider(u):
			v += float(Game.unit_value(u))
	return v >= 120.0 and _foe_near_home > _value_of(_nb_army_units()) * 0.8


## The staging point: a little out from the Mother toward the enemy, on her ground (the army gathers there and goes
## together).
func _nb_stage_point(q: Unit) -> Vector2:
	var foe := _foe()
	if _riders_on() and not _attacking:
		# (brood-anti-riders: riders about: the army waits by the grubs, where the riders hunt, not out at the natural)
		if _rider_guard != Vector2.INF and game.clock - _rider_land_t < RIDER_CALM:
			return _rider_guard
		var to: Vector2 = (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE if foe >= 0 else _qp(q) + game.sym_dir(team, Vector2(0, 1))
		var gp: Vector2 = _qp(q) + (to - _qp(q)).normalized() * (BroodNew.drawn_r(q) + 60.0)
		if _nb_on_map(gp) and game._walkable(game.cell_of(gp)):
			return gp
	if _eco() and _alarm_on() and not _attacking:
		# (the alarm: the army waits at the natural, where an attack lands first, a little toward where it was seen)
		var nat: Unit = null
		for u in BroodNew.expansions(game, q):
			if nat == null or u.position.distance_to(_qp(q)) < nat.position.distance_to(_qp(q)):
				nat = u
		if nat != null:
			var p: Vector2 = nat.position + (alarm_at - nat.position).normalized() * 3.0 * Defs.TILE
			if _nb_on_map(p) and game._walkable(game.cell_of(p)):
				return p
			return BroodRoot.anchor(game, nat) + game.sym_dir(team, Vector2(0, nat.radius + 40.0))
	var tgt: Vector2 = _qp(q) + game.sym_dir(team, Vector2(0, BroodNew.drawn_r(q) + 110.0))
	if foe >= 0:
		var st := (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE
		var p: Vector2 = _qp(q) + (st - _qp(q)).normalized() * 9.0 * Defs.TILE
		var c := game.cell_of(p)
		if _nb_on_map(p) and game._walkable(c) and game.region_of(c) == BroodRoot.home_region(game, _qp(q)):
			tgt = p
	return tgt


## Where a wave goes: the nearest enemy building it has seen (its creatures saw it), else the enemy's start.
func _nb_wave_goal(q: Unit) -> Vector2:
	var foe := _foe()
	if foe < 0:
		return Vector2.INF
	var best := (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE
	var bd := best.distance_to(_qp(q))
	for b in _foe_blds:
		if is_instance_valid(b) and not b.dead and b.team == foe and not (b.kind in ["wall", "gate", "palisade", "tower"]):
			# (not a wall piece: claws on a wall under musket fire was round 3's costliest mistake; a hall, a farm, an
			# expansion: the army goes round to them and fights what comes out)
			var d: float = (_foe_blds[b] as Vector2).distance_to(_qp(q))
			if d < bd:
				bd = d
				best = _foe_blds[b]
	return best


## An enemy building (not a wall piece) standing within r of p that its creatures see or have seen.
func _foe_bld_near(p: Vector2, r: float) -> bool:
	for b in _foe_blds:
		if is_instance_valid(b) and not b.dead and (_foe_blds[b] as Vector2).distance_to(p) < r and not (b.kind in ["wall", "gate", "palisade"]):
			return true
	return false


## The wave's next target once its goal is razed: the WEAKEST enemy still in the game (fewest supply; in a free-for-all
## the one it can finish), its nearest building the Brood has seen, else that enemy's centre, else its start. Vector2.INF:
## no enemy left.
func _nb_next_goal(q: Unit, from: Vector2) -> Vector2:
	var foes: Array = game.enemies_of(team).filter(func(t: int) -> bool: return game.center_of_team(t) != Vector2.ZERO or game.supply_used(t) > 0)
	if foes.is_empty():
		return Vector2.INF
	foes.sort_custom(func(a: int, b: int) -> bool: return game.supply_used(a) < game.supply_used(b))
	for f in foes:
		var best := Vector2.INF
		var bd := INF
		for b in _foe_blds:
			if is_instance_valid(b) and not b.dead and b.team == f and not (b.kind in ["wall", "gate", "palisade", "tower"]):
				var d: float = (_foe_blds[b] as Vector2).distance_to(from)
				if d < bd and d > 5.0 * Defs.TILE:
					bd = d
					best = _foe_blds[b]
		if best != Vector2.INF:
			return best
	# (brood-ai-tune: nothing but wall pieces seen, or nothing at all. The game goes on while any building stands, walls
	# too; the old fallback was the enemy's "centre" (the middle of its scattered buildings, often open ground) and its
	# start, and a wave at the cap with 10,000 food walked between the two every 4 s for four minutes without a kill)
	var wall := _nb_wall_piece(from, foes)
	if wall != null:
		return _foe_blds[wall]
	return _nb_explore_point(from, foes)


## The nearest wall piece (wall, gate, palisade, tower) of an enemy still in the game that its creatures have seen.
func _nb_wall_piece(from: Vector2, foes: Array = []) -> Building:
	var best: Building = null
	var bd := INF
	for b in _foe_blds:
		if is_instance_valid(b) and not b.dead and (foes.is_empty() or foes.has(b.team)) and b.kind in ["wall", "gate", "palisade", "tower"]:
			var d: float = (_foe_blds[b] as Vector2).distance_to(from)
			if d < bd:
				bd = d
				best = b
	return best


## Nothing of the enemy known: look for it (no cheating: places round its start, then round the map, it has not seen
## lately), the nearest first.
var _explored := {}


var _explore_cands: Array = []


## The places it looks: round the enemy starts (10, 18, 26 tiles), then a grid over the whole map (every 10
## tiles; 10 since the hunt: a Raptor sees 7), walkable ones only. Marked seen as its creatures see them (_nb_mark_explored, every think).
func _nb_explore_cands(foes: Array) -> Array:
	if _explore_cands.is_empty():
		var pts: Array = []
		for f in foes:
			if game.starts.size() <= f:
				continue
			var st := (Vector2(game.starts[f]) + Vector2(2.5, 2.0)) * Defs.TILE
			pts.append(st)
			for r in [10.0, 18.0, 26.0]:
				for i in 8:
					pts.append(st + Vector2.from_angle(TAU * i / 8.0) * r * Defs.TILE)
		for gx in range(5, Game.W - 2, 10):
			for gy in range(5, Game.H - 2, 10):
				pts.append((Vector2(gx, gy) + Vector2(0.5, 0.5)) * Defs.TILE)
		for p in pts:
			if _nb_on_map(p) and game._walkable(game.cell_of(p)):
				_explore_cands.append(p)
	return _explore_cands


func _nb_mark_explored() -> void:
	for p in _explore_cands:
		if game.is_visible_to(team, p):
			_explored[str(game.cell_of(p))] = game.clock


var _nb_hunting := false
var _pack_of := {}                # wave creature -> its pack (the hunt)
var _pack_at := {}                # pack -> the place it is sent to
var _hunt_step_t := 0.0


## Anything of an enemy still in the game known (a building it has seen standing, a wall piece too).
func _nb_foe_known() -> bool:
	for b in _foe_blds:
		if is_instance_valid(b) and not b.dead and game.hostile(b.team, team):
			return true
	return false


## Every 3 s: a pack at its place (or idle there) gets the nearest place not looked at lately that no other pack has.
func _nb_hunt_step(now: bool) -> void:
	if not now and game.clock - _hunt_step_t < 3.0:
		return
	_hunt_step_t = game.clock
	_nb_mark_explored()
	var members := {}
	for u in _wave:
		if is_instance_valid(u) and not u.dead:
			var k: int = int(_pack_of.get(u, 0))
			if not members.has(k):
				members[k] = []
			members[k].append(u)
	var taken: Array = []
	for k in _pack_at:
		taken.append(_pack_at[k])
	for k in members:
		var pk: Array = members[k]
		var c := Vector2.ZERO
		for u in pk:
			c += (u as Unit).position
		c /= maxf(1.0, pk.size())
		var at: Vector2 = _pack_at.get(k, Vector2.INF)
		var arrived := at == Vector2.INF or c.distance_to(at) < 5.0 * Defs.TILE \
			or pk.all(func(u) -> bool: return (u as Unit).order == "idle" or (u as Unit).order == "hold") \
			or game.clock - float(_explored.get(str(game.cell_of(at)), -999.0)) < 150.0
		if not arrived:
			continue
		taken.erase(at)
		var p := _nb_explore_point_not(c, taken)
		if p == Vector2.INF:
			p = _nb_explore_point_not(c, [])
		if p == Vector2.INF:
			continue
		_pack_at[k] = p
		taken.append(p)
		for u in pk:
			if (u as Unit).target == null or (u as Unit).order in ["idle", "hold", "move"]:
				(u as Unit).cmd_move(p, true)


## Creatures that joined the wave during the hunt go with the nearest pack.
func _nb_hunt_join(_army: Array) -> void:
	for u in _wave:
		if _pack_of.has(u) or _pack_at.is_empty():
			continue
		var best := -1
		var bd := INF
		for k in _pack_at:
			var d: float = (u as Unit).position.distance_to(_pack_at[k])
			if d < bd:
				bd = d
				best = k
		_pack_of[u] = best
		(u as Unit).cmd_move(_pack_at[best], true)


## The nearest place not looked at lately, at least 12 tiles from the places other packs were sent.
func _nb_explore_point_not(from: Vector2, taken: Array) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for p in _explore_cands:
		if game.clock - float(_explored.get(str(game.cell_of(p)), -999.0)) < 150.0:
			continue
		if taken.any(func(o: Vector2) -> bool: return o.distance_to(p) < 12.0 * Defs.TILE):
			continue
		var d: float = (p as Vector2).distance_to(from)
		if d < bd:
			bd = d
			best = p
	return best


func _nb_explore_point(from: Vector2, foes: Array) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	_nb_explore_cands(foes)
	_nb_mark_explored()
	for p in _explore_cands:
		var c := game.cell_of(p)
		if game.clock - float(_explored.get(str(c), -999.0)) < 150.0:
			continue
		var d: float = (p as Vector2).distance_to(from)
		if d > 6.0 * Defs.TILE and d < bd:
			bd = d
			best = p
	return best


var _wave_v0 := 0.0              # the wave's value when it left
var _wave_t0 := 0.0
var _wave_kills0 := 0
var _retreat_until := 0.0
var _gather_t := -1.0


func _nb_army(q: Unit) -> void:
	var army := _nb_army_units()
	if _scout != null:
		army.erase(_scout)
	# a wave out is called home when the attack at the Mother is big and the creatures at home can't hold it
	if _attacking and _nb_threat(q) != Vector2.INF and _nb_sires_needed(q):
		var home_v := _value_of(army.filter(func(u: Unit) -> bool: return not _wave.has(u)))
		if _foe_near_home > home_v * 0.8:
			say("calls its wave home: an attack at the Mother (%d)" % int(_foe_near_home))
			_wave_end_nb(q, false)
	# DEFENCE AS A SWARM (docs/brood_ai_swarm.md): enemies at home are fought by a squad sized to them, all at once
	if _nb_defend(q, army.filter(func(u: Unit) -> bool: return not _wave.has(u))):
		if not _attacking:
			_nb_hold_rest(army)
			return
	if hunt == null:
		hunt = AIHunt.new(self)
	if not _attacking and hunt.tick(army):
		return                  # (rules-fixes 3: the enemy has no army left, ours goes for its last buildings: ai_hunt.gd)
	var sup := 0
	for u in army:
		if u.kind != "hatchlings" or seen_air > 0:
			sup += int(u.d["supply"])
	if _attacking:
		_nb_wave_tick(q, army)
		return
	var home := _nb_stage_point(q)
	_rally = home
	# everyone gathers at the staging point and HOLDS there (no drifting off one by one by sight: _nb_hold_rest)
	_nb_hold_rest(army)
	# BANKED AT THE CAP (the owner's playtests 2026-11-03: a Brood at its supply cap with thousands of food sat at home
	# while the enemy outgrew it): its army goes, whatever the plan's wave time or size says (12 supply at least)
	var capped0 := game.supply_used(team) >= mini(int(game.players[team]["cap"]), game.max_supply(team)) - 6
	var banked := capped0 and _food() >= 1500 and sup >= 12
	if peaceful or game.clock < _retreat_until or (not banked and (game.clock < float(plan["wave_t"]) or _rush_on() or _alarm_on() \
			or _rider_short())):
		return
	var by_build: bool = bb != null and bb.decides() and not banked
	if by_build and not bb.may_go(q, army, sup):
		return
	if sup < _attack_at and not banked and not by_build:
		return
	# not into a hopeless fight: its army's value against the biggest enemy army it has seen lately (fading; 0.6 of it is
	# enough: round 3's best game, g20, traded 11,020 for 4,345 with Pack Hunt Raptors against a bigger Clockwork army), unless
	# it is at its supply cap (then it must spend its army) or this is a rush's first wave (a gamble by design)
	var mine_v := _value_of(army)
	var capped := game.supply_used(team) >= mini(int(game.players[team]["cap"]), game.max_supply(team)) - 6
	var first_rush := int(plan["grubs0"]) > 0 and not _first_out
	if first_rush and seen_army >= maxf(mine_v * 2.0, 400.0):
		# CALLED OFF (brood-ai-tune, round A g08: the Rush's 10 Raptors went at 3:00 into a Clockwork army of 560 and
		# lost; the 9-grub economy behind it never came back and the Brood fell at 8:46): its scout saw an army twice
		# its own, so the Raptors stay home as its defence and the economy starts now
		_rush_to_balanced("calls its rush off: an enemy army of %d seen against its %d" % [int(seen_army), int(mine_v)])
		return
	if not first_rush and not capped and not by_build and mine_v < seen_army * float(plan.get("edge", 0.6)):
		return
	# a wall seen (the Crown's ramp wall): not with claws alone (round 3: Raptor waves into Musketeers behind a wall lost
	# three to four times what they killed); Brutes with Battering Horns or a real line of Spitters first, or at the cap
	if seen_wall and not first_rush and not capped and not by_build:
		var br := BroodNew.count_of(game, team, "brute")
		var sp := BroodNew.count_of(game, team, "spitter") + BroodNew.count_of(game, team, "venom_challenger")
		if not ((br >= 2 and game.has_tech(team, "nb_battering_horns")) or sp >= 8):
			return
	if bool(plan["pack"]) and not by_build and not game.has_tech(team, "nb_pack_hunt") and (BroodResearch.in_hand(game, team, "nb_pack_hunt") \
			or (game.clock < float(plan["wave_t"]) + 60.0 and BroodNew.father_near(game, team, BroodNew.FATHER))):
		return          # (Pack Hunt first: it is coming, or wanted and a minute's grace)
	var stage2 := BroodNew.stage(q) >= 2 and seen_wall and not game.has_tech(team, "nb_battering_horns") and BroodResearch.in_hand(game, team, "nb_battering_horns")
	if stage2:
		return          # (Battering Horns before a siege of a wall)
	# gathered? most of the army near the staging point (or waited 25 s)
	var near := 0
	for u in army:
		if u.position.distance_to(home) < 9.0 * Defs.TILE:
			near += int(u.d["supply"])
	if _gather_t < 0.0:
		_gather_t = game.clock
	if near * 10 < sup * 7 and game.clock - _gather_t < 25.0:
		return
	_gather_t = -1.0
	var goal := _nb_wave_goal(q)
	if goal == Vector2.INF:
		return
	_wave_target = goal
	_wave = army.filter(func(u: Unit) -> bool: return (u.kind != "hatchlings" or seen_air > 0) and u.moult_t < 0.0)
	# a home guard stays (not on the first wave of a rush)
	var guard := int(plan["home_guard"]) if _first_out else 0
	for u in _wave.duplicate():
		if guard <= 0:
			break
		if u.kind == "raptor":
			_wave.erase(u)
			guard -= 1
	_wave_sup = 0
	for u in _wave:
		_wave_sup += int(u.d["supply"])
	_wave_v0 = _value_of(_wave)
	_wave_t0 = game.clock
	_wave_kills0 = int(game.stats[team]["value_killed"])
	_attacking = true
	_first_out = true
	# a Sire may lead the wave (the plan's "sire_leads": he gets up from his nest and walks with it; his line lays no
	# eggs meanwhile)
	var lead := String(plan.get("sire_leads", ""))
	if lead != "":
		var f := BroodNew.father(game, team, lead)
		if f and not BroodRoot.in_cocoon(f) and not BroodResearch.busy(f):
			if f.tesla_mode == "deployed":
				f.cmd_uproot(false)
			_wave.append(f)
	for u in _wave:
		u.cmd_move(goal, true)
	say("attacks with %d supply (%s)" % [_wave_sup, _kinds_of(_wave)])
	if bb != null:
		bb.started(q, _wave, goal)          # (the written build's push: its march, its siege)
	if game.mlog:
		game.mlog.add("%s's Brood attacks with %d supply" % [game.mlog.who(team), _wave_sup])


## A wave out: keep it going at the goal; new ones join only as a group (6+ supply gathered at the staging point);
## RETREAT when the fight is lost: what is left is under half of what went and what it sees ahead is stronger, or it
## made no headway for long.
func _nb_wave_tick(q: Unit, army: Array) -> void:
	_wave = _wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var left := _value_of(_wave)
	var ahead := 0.0
	var mid := Vector2.ZERO
	for u in _wave:
		mid += u.position
	if not _wave.is_empty():
		mid /= _wave.size()
		for u in game.units_near(mid, 12.0 * Defs.TILE):
			if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_worker() and game.is_visible_to(team, u.position):
				ahead += float(Game.unit_value(u))
	var gained := int(game.stats[team]["value_killed"]) - _wave_kills0
	var lost := _wave_v0 - left
	if _wave.is_empty() or (left < _wave_v0 * 0.5 and ahead > left * 1.2) or left < _wave_v0 * 0.25 \
			or (left < _wave_v0 * 0.7 and ahead > left * 1.6 and gained < lost * 0.5) \
			or (game.clock - _wave_t0 > 150.0 and gained < lost * 0.5 and ahead > left):
		say("pulls back: %d of %d left, %d ahead (killed %d)" % [int(left), int(_wave_v0), int(ahead), gained])
		_wave_end_nb(q, gained < _wave_v0 * 0.6)
		return
	# THE WRITTEN BUILD'S PUSH (scripts/ai_brood_builds.gd): the timing's march at the Spitters' pace, the Brutes' siege
	if bb != null:
		var steer: int = bb.tick(q, _wave, mid)
		if steer == 2:
			_wave_end_nb(q, gained < _wave_v0 * 0.6)
			return
		if steer == 1:
			_nb_join_fresh(army)
			_nb_hold_rest(army)
			return
	# THE HUNT (brood-ai-tune): packs sweep for a building it has not seen; once anything of the enemy is seen again the
	# wave gathers on it
	if _nb_hunting:
		if _nb_foe_known():
			_nb_hunting = false
			_pack_of.clear()
			var found := _nb_next_goal(q, mid)
			if found != Vector2.INF:
				_wave_target = found
				for u in _wave:
					u.cmd_move(_wave_target, true)
				say("found the enemy again: its wave gathers there (%d tiles)" % int(mid.distance_to(found) / Defs.TILE))
		else:
			_nb_hunt_step(false)
			_nb_hunt_join(army)
			_nb_hold_rest(army)
			return
	# AT THE GOAL WITH NOTHING TO FIGHT (the owner's playtest 2026-11-03, Ashfall FFA: the Brood razed the Clockwork's
	# main and its whole army, 160/160 supply and 4,000 food banked, stood on that spot for a minute while the
	# Clockwork's new hall stood a few screens away): the wave goes on to the next target (_nb_next_goal)
	if not _wave.is_empty() and mid.distance_to(_wave_target) < 7.0 * Defs.TILE and ahead <= 0.0 and not _foe_bld_near(mid, 9.0 * Defs.TILE):
		var nxt := _nb_next_goal(q, mid)
		var wall := _nb_wall_piece(mid)
		if wall != null and (_foe_blds[wall] as Vector2).distance_to(mid) < 12.0 * Defs.TILE and (_foe_blds[wall] as Vector2).distance_to(nxt) < 1.0:
			# only wall pieces left near: tear them down (claws on an empty wall cost nothing: no musket line behind it)
			for u in _wave:
				if u.target == null or u.order == "idle" or u.order == "hold" or u.order == "move":
					u.cmd_attack(wall)
		elif nxt != Vector2.INF and not _nb_foe_known() and _wave.size() >= 16:
			# nothing of the enemy known at all: the wave splits into packs of 8 that sweep the nearest places not looked
			# at lately, each its own (a hidden cottage kept the Crown alive for four minutes against 135 Raptors)
			_nb_hunting = true
			_pack_of.clear()
			var packs := _wave.size() / 8
			for i in packs:
				for u in _wave.slice(i * 8, (i + 1) * 8 if i < packs - 1 else _wave.size()):
					_pack_of[u] = i
			_pack_at.clear()
			_nb_hunt_step(true)
			say("nothing of the enemy in sight: its wave splits into %d packs to look for it" % packs)
		elif nxt != Vector2.INF and nxt.distance_to(_wave_target) > 5.0 * Defs.TILE:
			_wave_target = nxt
			say("its wave goes on to the next target (%d tiles on)" % int(mid.distance_to(nxt) / Defs.TILE))
			for u in _wave:
				if u.target == null or u.order == "idle" or u.order == "hold":
					u.cmd_move(_wave_target, true)
	for u in _wave:
		if u.order == "idle" and u.target == null:
			u.cmd_move(_wave_target, true)
	_nb_join_fresh(army)
	_nb_hold_rest(army)


## Reinforcements: a group gathered at home (6 supply or more) joins the wave out.
func _nb_join_fresh(army: Array) -> void:
	var home := _rally
	var fresh := army.filter(func(u: Unit) -> bool: return not _wave.has(u) and not _def.has(u) and (u.order == "idle" or u.order == "hold") \
		and u.target == null and u.moult_t < 0.0 and (u.kind != "hatchlings" or seen_air > 0) and u.position.distance_to(home) < 9.0 * Defs.TILE)
	var fs := 0
	for u in fresh:
		fs += int(u.d["supply"])
	if fs >= 6 and not _def_on():
		for u in fresh:
			_wave.append(u)
			u.cmd_move(_wave_target, true)


## The wave is over (pulled back or called home): back to the staging point; a lost wave makes the next bigger and
## gives it time to build (a failed rush becomes a Balanced game).
func _wave_end_nb(q: Unit, failed: bool) -> void:
	if bb != null:
		bb.ended("failed" if failed else "home")
	_attacking = false
	_nb_hunting = false
	_pack_of.clear()
	_pack_at.clear()
	var home := _nb_stage_point(q)
	for u in _wave:
		if is_instance_valid(u) and not u.dead:
			u.cmd_move(home)
	_wave.clear()
	_attack_at += int(plan["step"])
	if failed:
		_attack_at = maxi(_attack_at, int(ceil(_wave_sup * 1.3)))
		_retreat_until = game.clock + 60.0
		if strategy in ["rush", "xrush"]:
			_rush_to_balanced("its rush failed: it builds up (economy, tech) and comes back in force")
	elif strategy in ["rush", "xrush"]:
		# (brood-ai-tune, round A g10: an Extreme rush whose first wave paid for itself stayed on the rush plan, whose
		# grub curve is 0 a minute: 6 grubs until 8:00 and 3,187 food earned by 10:00 against the Clockwork's 7,545. The
		# rush is an opening: once its first wave is home, it plays Balanced and keeps up the pressure)
		_rush_to_balanced("its rush is home (killed more than it lost): Balanced from now on")
		_retreat_until = game.clock + 120.0          # (round C g13: a second wave of 14 Raptors at 5:30 into the Clockwork
		                                             # lost all but 4 and the economy behind it never grew: two minutes to build)


## A rush over (failed, or called off before it left): the Balanced plan from now on, expanding at once.
func _rush_to_balanced(why: String) -> void:
	strategy = "balanced"
	_plan_of = strategy
	var keep_wave := _attack_at
	plan = (PLANS["balanced"] as Dictionary).duplicate(true)
	for k in over:
		plan[k] = over[k]
	plan["wave_t"] = 0.0
	# (brood-ai-tune: the rush's own far list was kept here (one turtle on new ground at 10:00), and with no room
	# left round her for a third Rootmaw the economy stood at 2 Rootmaws and 14 grubs until 10:00: the expansions
	# now come from the failed rush on, a minute and a half apart)
	plan["far"] = [[game.clock, 1], [game.clock + 90.0, 2], [game.clock + 180.0, 3]]
	_attack_at = maxi(keep_wave, 20)
	_retreat_until = game.clock + 90.0
	_first_out = true
	say(why)


func _kinds_of(list: Array) -> String:
	var c := {}
	for u in list:
		c[u.kind] = int(c.get(u.kind, 0)) + 1
	var parts: Array = []
	for k in c:
		parts.append("%d %s" % [c[k], k])
	return ", ".join(parts)


## The ground the Mother roots on at home (her footprint at her stage, one tile round it): a Sire never nests there,
## even while she is up fighting, or she could not root again when it is calm.
func _nb_mother_ground(q: Unit) -> Rect2:
	var home: Vector2 = _q_guard.get("home", _qp(q))
	return BroodRoot.rect_for(BroodNew.QUEEN, home, BroodRoot.scale_of(q)).grow(Defs.TILE)


# ------------------------------------------------------------------ defence as a swarm (docs/brood_ai_swarm.md)

## THE OWNER'S PLAYTEST (2026-11-01, Clockwork rush v Brood economy, 5:23): idle Raptors at the staging point went for
## Clock Soldiers one by one as each saw them (an idle creature picks its own fight in sight, Unit "idle"), and each
## Raptor hatched went on attack-move into the fight alone: a trickle, eaten one at a time. Now:
##  - idle army creatures at home walk to the RALLY (the staging point) and HOLD there: they fight only what reaches
##    their claws, never by sight;
##  - enemies at home (HOME_R tiles of the Mother, or SITE_R of one of its rooted creatures) are looked at as a group
##    (the one nearest the Mother, DEF_CLUSTER_R round it), and a DEFENCE SQUAD sized to it goes all at once: the nearest
##    creatures until the fight is won on paper (_fight_wins), the Tyrant Sire for a small harass with no warriors to
##    spare, the whole army for a bigger attack, and at the Mother everything near her joins at once;
##  - an attack too strong for what it has, away from the Mother: nobody goes; the rally falls back to the Mother (her
##    side of the fight) and the army gathers there;
##  - creatures hatched or come home meanwhile join the squad at once near the fight (JOIN_R), otherwise from the rally
##    only as a group (JOIN_GROUP supply);
##  - the squad stops when nothing is left at home (no chase across the map: DEF_LEASH) and goes back to the rally.
const HOME_R := 26.0
const SITE_R := 9.0
const DEF_CLUSTER_R := 10.0
const JOIN_R := 12.0
const JOIN_GROUP := 4
const DEF_LEASH := 14.0
const SMALL_HARASS := 250.0         # (value: up to three Clock Soldiers or Musketeers, two Horsemen)
var _def: Array = []                # the defence squad
var _def_at := Vector2.INF          # where it fights (the group it was sent at)
var _rally := Vector2.INF           # where the army at home gathers and holds


func _def_on() -> bool:
	return not _def.is_empty()


## The enemies at home its creatures see (fighters only; flyers only when it has Hatchlings to hit them).
func _nb_home_foes(q: Unit) -> Array:
	var sites: Array = [_qp(q)]
	for u in game.units:
		if u.team == team and not u.dead and BroodNew.ROOTERS.has(u.kind) and BroodNew.rooted(u) and u != q:
			sites.append(u.position)
	var anti_air := BroodNew.count_of(game, team, "hatchlings") > 0
	var out: Array = []
	for u in game.units_near(_qp(q), (HOME_R + 40.0) * Defs.TILE):
		if u.dead or u.off_field or u.team < 0 or not game.hostile(u.team, team) or not u.has_attack() or u.is_worker():
			continue
		if u.kind == BroodNew.EGG or (u.is_air() and not anti_air) or not game.is_visible_to(team, u.position):
			continue
		if u.position.distance_to(_qp(q)) < HOME_R * Defs.TILE:
			out.append(u)
			continue
		for s in sites:
			if (s as Vector2).distance_to(u.position) < SITE_R * Defs.TILE:
				out.append(u)
				break
	return out


## The group to answer: the enemy nearest the Mother and every enemy at home within DEF_CLUSTER_R tiles of it.
func _nb_cluster(q: Unit, foes: Array) -> Array:
	var first: Unit = null
	for u in foes:
		if first == null or u.position.distance_to(_qp(q)) < first.position.distance_to(_qp(q)):
			first = u
	if first == null:
		return []
	var c: Array = []
	for u in foes:
		if u.position.distance_to(first.position) < DEF_CLUSTER_R * Defs.TILE:
			c.append(u)
	return c


static func _mid(list: Array) -> Vector2:
	var p := Vector2.ZERO
	for u in list:
		p += (u as Unit).position
	return p / maxf(1.0, list.size())


## Does this group of its creatures beat that group of enemies in a stand-up fight? (On paper: its hits pooled, each
## enemy killed in turn while the rest hit back; armour off each blow. `margin`: the share of its health it may lose.)
## Its own armour is its kind's (a rooted creature's extra armour is gone once it is up).
static func _fight_wins(mine: Array, foes: Array, margin := 0.6) -> bool:
	if mine.is_empty():
		return false
	if foes.is_empty():
		return true
	var hp := 0.0
	var my_armor := 0.0
	for u in mine:
		hp += (u as Unit).hp
		my_armor += float((u as Unit).d.get("armor", 0))
	my_armor /= mine.size()
	var their: Array = []
	var their_dps := 0.0
	for f in foes:
		var fu := f as Unit
		var dps := maxf(1.0, float(fu.d.get("damage", 0)) - my_armor) / maxf(0.3, float(fu.d.get("cooldown", 1.0)))
		their.append([fu.hp, dps, fu.armor])
		their_dps += dps
	their.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var taken := 0.0
	for e in their:
		var my_dps := 0.0
		for u in mine:
			var mu := u as Unit
			my_dps += maxf(1.0, float(mu.d.get("damage", 0)) - float(e[2])) / maxf(0.3, float(mu.d.get("cooldown", 1.0)))
		taken += their_dps * float(e[0]) / maxf(0.1, my_dps)
		their_dps -= float(e[1])
	return taken < hp * margin


## Defence: true while it is answering (or holding back from) enemies at home.
func _nb_defend(q: Unit, army: Array) -> bool:
	_rally = _nb_stage_point(q)
	_def = _def.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var foes := _nb_home_foes(q)
	var group := _nb_cluster(q, foes)
	if group.is_empty():
		if _def_on():
			_nb_stand_down(q)
		return false
	var rv := _value_of(group.filter(func(o) -> bool: return is_rider(o)))
	if rv > 0.0 and (rv >= _value_of(group) * 0.6 or (_riders_on() and rv >= _value_of(group) * 0.4)):
		return _nb_defend_riders(q, army, group)          # (brood-anti-riders: mostly riders: guard the grubs, no chase)
	var at := _mid(group)
	var e := _value_of(group)
	var at_mother := at.distance_to(_qp(q)) < 14.0 * Defs.TILE
	var air := group.any(func(f) -> bool: return (f as Unit).is_air())
	var avail := army.filter(func(u: Unit) -> bool: return u.moult_t < 0.0 and not held.has(u) and (u.kind != "hatchlings" or air))
	if _def_on():
		# the squad fights on; the ones near join at once, the rest from the rally as a group
		_def_at = at
		var join: Array = []
		var at_rally: Array = []
		var rs := 0
		for u in avail:
			if _def.has(u):
				continue
			if u.position.distance_to(at) < JOIN_R * Defs.TILE or (at_mother and u.position.distance_to(_qp(q)) < 16.0 * Defs.TILE):
				join.append(u)
			elif u.position.distance_to(_rally) < 9.0 * Defs.TILE:
				at_rally.append(u)
				rs += int(u.d["supply"])
		if rs >= JOIN_GROUP or not _fight_wins(_def, group, 0.9):
			join.append_array(at_rally)
		for u in join:
			_def.append(u)
			u.cmd_move(at, true)
		# A SIRE ON A LEASH (brood-ai-tune, round A g05: the Tyrant Sire got up for a Cuirassier and a Musketeer at 9:13,
		# then chased riders that kept out of his reach (they kite slow defenders since 0.27.0) for minutes; no Raptor egg
		# was laid meanwhile, her clutch sat full at 19/20 and 4,000 food piled up): he goes home to his nest once only
		# riders are left, once he is SIRE_LEASH tiles from her, or after SIRE_OUT s, unless the fight is at the Mother
		for u in _def.duplicate():
			var su := u as Unit
			if not BroodNew.is_father(su.kind) or (at_mother and _nb_sires_needed(q)):
				continue
			if not _sire_out.has(su):
				_sire_out[su] = game.clock
			var riders_only := group.all(func(o) -> bool: return is_rider(o))
			if riders_only or su.position.distance_to(_qp(q)) > SIRE_LEASH * Defs.TILE or game.clock - float(_sire_out[su]) > SIRE_OUT:
				_def.erase(su)
				_sire_out.erase(su)
				_sire_home_t[su] = game.clock
				su.cmd_move(_qp(q))          # (_nb_one_father roots him on his nest again)
				say("the %s goes back to his nest (%s)" % [String(Defs.UNITS[su.kind]["name"]), "only riders left" if riders_only else "too far from her"])
		# losing it away from the Mother: back to her (a lost fight is lost ground, not the army)
		if not at_mother and not _fight_wins(_def, group, 1.0) and not _fight_wins(avail, group, 1.0):
			say("pulls its defenders back to the Mother: %d against %d" % [int(_value_of(_def)), int(e)])
			_rally = _nb_fallback(q, at)
			_nb_stand_down(q)
			return true
		for u in _def:
			var cu := u as Unit
			if cu.tesla_mode == "deployed":
				continue
			var far: bool = cu.position.distance_to(at) > DEF_LEASH * Defs.TILE and cu.position.distance_to(_qp(q)) > HOME_R * Defs.TILE
			if far or (cu.target == null and (cu.order == "idle" or cu.order == "hold" or cu.order == "move")):
				cu.cmd_move(at, true)
		return true
	# a new squad: the nearest until the fight is won on paper
	avail.sort_custom(func(a, b) -> bool: return (a as Unit).position.distance_to(at) < (b as Unit).position.distance_to(at))
	var squad: Array = []
	if e <= SMALL_HARASS:
		for u in avail:
			squad.append(u)
			if squad.size() >= 2 and _fight_wins(squad, group):
				break
		var all_riders := group.all(func(o) -> bool: return is_rider(o))
		if not _fight_wins(squad, group) and at.distance_to(_qp(q)) < 22.0 * Defs.TILE and not all_riders:
			var f := BroodNew.father(game, team, BroodNew.FATHER)
			if f and not BroodRoot.in_cocoon(f) and not BroodResearch.busy(f) and not _wave.has(f) and game.clock - float(_sire_home_t.get(f, -999.0)) > 40.0:
				squad.append(f)       # (the Tyrant Sire: 1,000 health, a terrible bite; he roots again after)
	elif at_mother or _fight_wins(avail, group, 0.8):
		squad = avail
		if at_mother and _nb_sires_needed(q) and not group.all(func(o) -> bool: return is_rider(o)):
			for fk in BroodNew.FATHERS:
				var f2 := BroodNew.father(game, team, fk)
				if f2 and not BroodRoot.in_cocoon(f2) and not _wave.has(f2):
					squad.append(f2)
	if squad.is_empty() or (not at_mother and not _fight_wins(squad, group, 1.0)):
		# too strong to meet away from her: the army gathers on her side and waits (no trickle)
		_rally = _nb_fallback(q, at)
		return true
	_def = squad
	_def_at = at
	for u in _def:
		var cu := u as Unit
		if cu.tesla_mode == "deployed":
			cu.cmd_uproot(false)          # (a Sire: sent on once he is up, above; _nb_one_father leaves him be meanwhile)
		else:
			cu.cmd_move(at, true)
	say("defends with %d (%s, %d) against %d (%s) at %s" % [_def.size(), _kinds_of(_def), int(_value_of(_def)), int(e), _kinds_of(group), "the Mother" if at_mother else "home"])
	return true


const SIRE_LEASH := 16.0
const SIRE_OUT := 30.0
var _sire_out := {}               # Sire -> when he joined the defence squad
var _sire_home_t := {}            # Sire -> when he was sent home (not sent out again for 40 s)


func in_defence(u: Unit) -> bool:
	return _def.has(u)


## The rally when an attack at home is too strong to meet: on the Mother's far side from it.
func _nb_fallback(q: Unit, from: Vector2) -> Vector2:
	var p: Vector2 = _qp(q) + (_qp(q) - from).normalized() * (BroodNew.drawn_r(q) + 70.0)
	if _nb_on_map(p) and game._walkable(game.cell_of(p)):
		return p
	return _qp(q) + game.sym_dir(team, Vector2(0, BroodNew.drawn_r(q) + 70.0))


func _nb_stand_down(_q: Unit) -> void:
	for u in _def:
		if not is_instance_valid(u) or u.dead:
			continue
		if BroodNew.FATHERS.has(u.kind):
			u.cmd_stop()              # (back to his nest: _nb_one_father)
			_sire_out.erase(u)
		elif not _wave.has(u):
			u.cmd_move(_rally)
	_def.clear()
	_def_at = Vector2.INF


## Idle army creatures at home: to the rally and HOLD there (no fight picked by sight).
func _nb_hold_rest(army: Array) -> void:
	if _rally == Vector2.INF:
		return
	for u in army:
		if _wave.has(u) or _def.has(u) or u == _scout or held.has(u) or u.target != null or u.moult_t >= 0.0:
			continue
		if u.order != "idle" and u.order != "hold":
			continue
		if u.position.distance_to(_rally) > 200.0:
			u.cmd_move(_rally)
		elif u.order == "idle":
			u.cmd_hold()


# ------------------------------------------------------------------ a rooted Rootmaw under attack

## THE OWNER'S PLAYTEST (2026-11-01, 5:23): a Rootmaw rooted at the expansion sat taking blows from one or two Clock
## Soldiers (no rooted creature attacks). Now a rooted Rootmaw struck (or its grubs struck beside it) by enemies it
## beats on paper (_fight_wins, uprooted: its armour off) UPROOTS keeping its food (HAUL) and bites back; against more
## than it beats it uproots SPILLING its food (a pile its grubs collect: at full speed, 80, it outruns a Clock
## Soldier's 68) and backs off to the Mother. Either way it roots again on its own spot once nothing is near it for
## MAW_SAFE s.
const MAW_SAFE := 4.0
var _maw_fight := {}                # Rootmaw -> {"spot", "mode": "fight" / "back", "t", "calm"}
var _maw_calm_t := 0.0


func maw_fighting(m: Unit) -> bool:
	return _maw_fight.has(m)


func _nb_maw_guard(q: Unit) -> void:
	var dt := clampf(game.clock - _maw_calm_t, 0.0, 2.0)
	_maw_calm_t = game.clock
	for m in _nb_mine(BroodNew.MAW):
		if _maw_fight.has(m) or held.has(m) or not BroodNew.rooted(m) or BroodRoot.in_cocoon(m):
			continue
		if game.clock - m.hit_clock > 2.0:
			var grub_hit := false
			for u in game.units_near(m.position, 4.0 * Defs.TILE):
				if game.hostile(u.team, team) and not u.dead and is_instance_valid(u.target) and u.target is Unit \
						and (u.target as Unit).team == team and (u.target as Unit).kind == "grub":
					grub_hit = true
					break
			if not grub_hit:
				continue
		var foes := _maw_foes(m)
		if foes.is_empty():
			continue
		var win := _fight_wins([m], foes, 0.8)
		_maw_fight[m] = {"spot": m.position, "mode": "fight" if win else "back", "t": game.clock, "calm": 0.0}
		m.nb["keep"] = m.position         # (its spot stays its own while it fights: BroodRoot.plan_of)
		BroodNew.uproot(m, not win)
		say("a Rootmaw under attack uproots to %s (%s)" % ["fight back" if win else "back off", _kinds_of(foes)])
	for m in _maw_fight.keys():
		if not is_instance_valid(m) or m.dead:
			_maw_fight.erase(m)
			continue
		var s: Dictionary = _maw_fight[m]
		if m.tesla_mode != "packed":
			if BroodNew.rooted(m) and game.clock - float(s["t"]) > 3.0:
				_maw_fight.erase(m)          # (rooted again: done)
				m.nb.erase("keep")
			continue
		var spot: Vector2 = s["spot"]
		var foes := _maw_foes(m)
		var near_spot := false
		for u in game.units_near(spot, 7.0 * Defs.TILE):
			if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_air() and not u.is_worker():
				near_spot = true
				break
		if foes.is_empty() and not near_spot:
			s["calm"] = float(s["calm"]) + dt
			if float(s["calm"]) >= MAW_SAFE and m.order != "nb_root":
				if BroodRoot.place_problem(game, team, BroodNew.MAW, spot, m, true) != "":
					# (its spot really got taken (a creature stands on it, another's plan): let go; _nb_rootmaws finds it the
					# nearest free spot on the next think, never the same one again)
					_maw_fight.erase(m)
					m.nb.erase("keep")
					_nb_bad_spots[str(spot.round())] = game.clock + 60.0
					say("a Rootmaw's spot was taken while it fought: it roots elsewhere")
					continue
				_root_last.erase(m.get_instance_id())
				_root_to(m, spot)            # (back on its own spot: its ground kept what was left)
		else:
			s["calm"] = 0.0
		if game.clock - float(s["t"]) > 90.0:
			_maw_fight.erase(m)              # (its spot still taken: _nb_rootmaws finds it another)
			m.nb.erase("keep")
			continue
		if foes.is_empty():
			continue
		if s["mode"] == "fight" and not _fight_wins([m], foes, 0.9):
			s["mode"] = "back"
		if s["mode"] == "fight":
			if m.position.distance_to(spot) > 8.0 * Defs.TILE:
				m.cmd_move(spot)            # (no chase: back to its spot)
			elif m.target == null or m.order == "idle" or m.order == "move" or m.order == "nb_root":
				var near: Unit = foes[0]
				for f in foes:
					if (f as Unit).position.distance_to(m.position) < near.position.distance_to(m.position):
						near = f
				m.cmd_attack(near)
		else:
			var back := _nb_fallback(q, _mid(foes))
			if m.order != "move" or m.order_point.distance_to(back) > 3.0 * Defs.TILE:
				m.cmd_move(back)


## The enemies about a Rootmaw (ground fighters within 6 tiles).
func _maw_foes(m: Unit) -> Array:
	var out: Array = []
	for u in game.units_near(m.position, 6.0 * Defs.TILE):
		if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_air() and not u.is_worker():
			out.append(u)
	return out


## (start-spots-fix) The Mother's place for the computer's sums: her feet as the first start of its mirror set reads them,
## carried back (BroodRoot.anchor; for that first start, her feet). Her footprint hangs from her feet ON SCREEN, so the plain
## feet put a mirrored side's posts and rally points on the other side of her nest.
func _qp(q: Unit) -> Vector2:
	return BroodRoot.anchor(game, q)
