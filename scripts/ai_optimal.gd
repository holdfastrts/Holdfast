class_name AIOptimal
extends RefCounted
## THE OPTIMAL PLAN (ai-optimal, the owner 2026-11-05 09:54; docs/ai_optimal.md): "a plan called OPTIMAL that is adaptive,
## has access to all the plans, and picks from each plan to the adaptive necessities of the matchup". Each faction's own
## computer (AICrown, AIClockwork, AIBroodNew) plays its COMMON OPENING (the Crown's ramp Cottage, Gate, Barracks and second Farm;
## the Clockwork's economy opening; the Brood's Balanced economy opening), scouts early, and on each READ of a scout report
## (AIRead: GREEDY / NORMAL / AGGRESSIVE / DEFENSIVE / UNKNOWN) picks one of ALL its faction's builds by the read, the
## matchup and the map (choose()), then plays that build's own code (ai.opt_switch: the build order from where it stands,
## its raids or its push). It re-reads every scout trip and SWITCHES AT MOST ONCE A STAGE (opening, middle, late), never
## flip-flopping; the one exception is survival (a rush read while it plays a greedy build). Every read and pick goes to
## the match log, and the AI STORY tells it: what it saw -> what it makes of it -> what it does.
## The choices (the owner's words, 2026-11-05):
##  v AGGRESSIVE  defend first, then counter (the faction's Balanced build: its rush defence and the counter-attack after)
##  v GREEDY      punish while it can arrive in time (Crown: the Horseman rush against the Brood, sometimes the Clockwork,
##                NEVER the Crown: a timing attack there; Clockwork: the Clock Soldier rush, later the Springer timing;
##                Brood: the Raptor rush, the Spitter timing against a walled Crown), or out-expand when it is too late
##  v NORMAL      a normal game, a timing or an economic race by matchup, with a little chance in it (not predictable)
##  v DEFENSIVE   out-expand and tech (Economy) in the opening; a siege build in the middle (Siege push, Heavy Works push,
##                Brute siege)
##  v UNKNOWN     no pick: the scout looks again soon. With no read by DECIDE_BY it plays a normal game for the matchup.

const MIDDLE := 270.0            # (game seconds) the opening stage ends, the middle begins
const LATE := 600.0
const DECIDE_BY := 180.0         # no read by then: a normal game for the matchup
const UNKNOWN_WAIT := 45.0       # ... or this long after a first UNKNOWN with no read since
const PUNISH_BY := {"crown": 150.0, "clockwork": 150.0, "brood": 150.0}    # a rush to punish greed only before this
const TOO_LATE := 330.0          # a timing attack to punish greed only before this; later, out-expand it
const BREEDER_BY := 165.0        # the Crown's Horse Breeder answers a greedy Brood read before this (crown-optimal-opening)
const RIDERS_V_BROOD := 1.0      # (crown-ai-v2) the share of greedy Brood reads the Crown answers with the riders (else out-expand).
                                 # Measured at 0.5 (32 games, docs/crown_ai_v2.md): the Economy race won or led 0 of 9 against the
                                 # Brood, the riders 0 of 7, as the riders alone did before (0 of 16): no gain over the owner's rule,
                                 # so his rule plays every time again; the knob stays for a study
const RIDERS_V_CLOCK := 0.15     # (crown-ai-v2) ... and of greedy Clockwork reads, early (was 0.35; the riders' plan won or led 0 of 2)
## (crown-ai-v2) a greedy Clockwork otherwise: the Timing attack won or led 3 of 4 plan games against Hard Clockwork OPTIMAL,
## the Economy race and Balanced 1 of 4, the balloons 1 of 2 (docs/crown_ai_v2.md)
const GREEDY_CLOCK := {"timing": 3.0, "economy": 1.0, "balloon": 1.0}
## (study switch, tools/measure_crown_opening.gd: `-- greedybrood:economy` (or siege, or another plan) makes the Crown
## answer a greedy Brood with that plan instead of the riders, to measure them; docs/crown_optimal_opening.md)
static var GREEDY_BROOD_TRY := _arg("greedybrood:")
## (econ-coach-crown, study switch: `-- greedyclock:economy` answers a greedy Clockwork with that plan, to measure the picks'
## economies against each other; docs/econ-coach-crown.md)
static var GREEDY_CLOCK_TRY := _arg("greedyclock:")


static func _arg(pre: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(pre):
			return a.substr(pre.length())
	return ""

var ai = null
var game: Game = null
var team := 0
var fac := ""
var current := ""                # the build it plays now (an AI.STRATEGIES key)
var opening_plan := ""           # the common opening's
var picks: Array = []            # [clock, stage, read, plan, why] of every pick
var switched := {}               # stage -> true once it switched in that stage
var survival_used := false
var unknown_t := -1.0            # when the first UNKNOWN came
var lean := ""                   # the build it leaned to before the scout (the matchup or the map)
var log: Array = []              # [clock, text]
var _rng := RandomNumberGenerator.new()
var _held_said := {}
var riders_v_brood := RIDERS_V_BROOD     # (tests set it: 1.0 plays the riders' punish every time)


func _init(a, opening_plan: String) -> void:
	ai = a
	game = a.game
	team = a.team
	fac = game.faction_of(team)
	current = opening_plan
	self.opening_plan = opening_plan
	_rng.seed = hash([randi(), team])      # (from the match's seeded dice: the same match picks the same)


static func stage_of(t: float) -> String:
	if t < MIDDLE:
		return "opening"
	if t < LATE:
		return "middle"
	return "late"


func foe() -> String:
	var f: int = ai._foe()
	return game.faction_of(f) if f >= 0 else ""


func plan_name(k: String) -> String:
	if k == "optimal":
		return "the common opening"
	return String(AI.STRATEGIES.get(k, AI.STRATEGIES["balanced"])["name"])


func say(s: String) -> void:
	log.append([game.clock, s])
	ai.say("optimal: " + s)


## The plan a NORMAL read leads to, by the matchup (weights), with a little chance in it.
## (crown-ai-v2, docs/crown_ai_v2.md: the Crown's cross picks MEASURED. The QA study (0.33.7): OPTIMAL's Crown played Balanced
## at 5:00 in 67 of 76 cross games and those won or led 2; every Crown plan against Hard Brood and Clockwork OPTIMAL on
## four maps: against the Brood nothing won or led; only the Economy plan kept its income even (1.03 of the Brood's at 5:00,
## 0.91 at 8:00) and the fixed Horseman rush held to 15:00 3 times of 4; Balanced, Timing, the Siege push, the raids lost
## every time (a NORMAL read of the Brood, rare, leans to the Economy race). Against the Clockwork the Timing attack won or
## led 3 of 4, the others 0-1, and 4 of 11 in the OPTIMAL games after: the Clockwork gets the Timing attack first)
const NORMAL := {
	"crown": {"brood": {"economy": 3.0, "balanced": 1.0},
		"clockwork": {"timing": 3.0, "economy": 1.0, "balloon": 1.0},
		"crown": {"economy": 3.0, "balanced": 2.0, "dragoon": 2.0, "siege": 1.0, "timing": 1.0}},
	"clockwork": {"brood": {"pendulum": 3.0, "balanced": 2.0, "owls": 2.0},
		"crown": {"balanced": 2.0, "economy": 2.0, "springer": 2.0, "heavy": 1.0},
		"clockwork": {"balanced": 3.0, "economy": 2.0, "springer": 1.0}},
	"brood": {"crown": {"balanced": 2.0, "spitter": 2.0, "brute": 2.0, "timing": 1.0},
		"clockwork": {"timing": 2.0, "spitter": 2.0, "balanced": 2.0},
		# (brood-v-brood-coach, docs/brood-v-brood-coach.md: no Rush in the mirror: its 10 Raptors at 2:51 met the other
		# Brood's rush evidence, Raptors and Mother and came home with half, and the rusher was behind all game: it lost 4,
		# trailed 1 and led 1 of 6 against Economy turned Balanced in the measuring batch's first seed)
		"brood": {"balanced": 2.0, "timing": 2.0, "economy": 1.0}},
}


func _weighted(w: Dictionary) -> String:
	var total := 0.0
	for k in w:
		total += float(w[k])
	var r := _rng.randf() * total
	for k in w:
		r -= float(w[k])
		if r < 0.0:
			return String(k)
	return String(w.keys()[0])


## [plan, why] for a read now (why: a fixed phrase, tools/i18n/55_ai_optimal.txt); [] for no pick.
func choose(read: String) -> Array:
	var f := foe()
	var t := game.clock
	var st := stage_of(t)
	match read:
		"AGGRESSIVE":
			if st == "opening" or current in ["economy", "rush", "cs_rush"]:
				return ["balanced", "defend against the rush before it counter-attacks"]
			return []
		"GREEDY":
			return _punish(f, t)
		"DEFENSIVE":
			if _mirror_turrets():
				return []         # (clockwork-v-clockwork-coach: see _mirror_turrets)
			if st == "opening":
				return ["economy", "out-expand and tech up before a siege"]
			match fac:
				"crown":
					return ["siege", "a siege to break its defences"]
				"clockwork":
					return ["heavy", "a siege to break its defences"]
				"brood":
					return ["brute", "a siege to break its defences"]
		"NORMAL":
			if fac == "crown" and f == "brood" and _lean_only():
				return ["economy", "an economic race"]       # (econ-coach-crown: the lean was no read; see _lean_only)
			if st != "opening" or not picks.is_empty():
				return []        # (a normal read later keeps what it plays: the dice are thrown once, no flip-flop)
			var w: Dictionary = (NORMAL.get(fac, {}) as Dictionary).get(f, {"balanced": 1.0})
			var k := _weighted(w)
			return [k, _normal_why(k)]
	return []


func _normal_why(k: String) -> String:
	match k:
		"economy":
			return "an economic race"
		"timing", "springer", "spitter":
			return "a timing attack"
		"dragoon", "owls", "balloon":
			return "raids on its workers"
		"siege", "heavy", "brute":
			return "a siege to break its defences"
		"pendulum":
			return "the Pendulums answer its swarm"
		"rush", "cs_rush":
			return "an early rush"
	return "a normal game"


## GREEDY: punish while a rush can arrive in time, else a timing attack, else out-expand it.
func _punish(f: String, t: float) -> Array:
	var early := t < float(PUNISH_BY.get(fac, 150.0))
	match fac:
		"crown":
			if f == "brood":
				# (the owner, 2026-11-06 09:17, crown-optimal-opening: "In that particular game I think horse breeder to punish
				# the greed." Not the Siege push any more: it put 8 Musketeers, the Farm and the Breeder before the second hall,
				# no punish and the hall at 4:45. MEASURED (docs/crown_optimal_opening.md, 4 maps x 3 seeds v the Brood's
				# OPTIMAL, 4 maps v its Economy, to 15:00): the Horse Breeder at the read (~1:36) has the first Horseman at
				# 2:30-2:55 and the riders out at 3:34-4:04, after the Brood's first Raptors (3:14-3:22) every time, yet the
				# raid kills grubs and keeps the Brood's income down: the Crown held to 15:00 in 6 of 16 games; out-expanding
				# (the Economy plan's hall at 2:22) and the Siege push held in none (losses at 10:28-14:42). Read too late for
				# the riders (BREEDER_BY): out-expand it.)
				if GREEDY_BROOD_TRY != "":
					return [GREEDY_BROOD_TRY, _normal_why(GREEDY_BROOD_TRY)]     # (study switch)
				# (crown-ai-v2: the Brood roots a Mound Turtle on new ground at 0:00 in every plan, so "a second base and little
				# army" is the read of 35 of 38 Brood games, its standard opening as much as its greed; the riders answered every
				# one and the Crown won or led none (QA study). The Economy race was tried on half of them (RIDERS_V_BROOD 0.5)
				# and did no better: the owner's rule, the Horse Breeder, again; the knob is kept)
				if t < BREEDER_BY and _rng.randf() < riders_v_brood and _true_greed_brood():
					return ["rush", "punish the greed: the Horse Breeder at once, the riders before its army"]
				if t < BREEDER_BY:
					return ["economy", "out-expand it: its early ground is its usual opening"]
				return ["economy", "too late for the riders: out-expand it"]
			if f == "clockwork" and early and _rng.randf() < RIDERS_V_CLOCK:
				return ["rush", "punish the greed before its army is up"]
			if f == "clockwork" and GREEDY_CLOCK_TRY != "":
				return [GREEDY_CLOCK_TRY, _normal_why(GREEDY_CLOCK_TRY)]     # (study switch, econ-coach-crown)
			if f == "clockwork":
				# (coached: the one-hall Timing attack lost the race to a Clockwork economy, 9,500 to 16,600 earned by 12:00
				# on Highmoor. crown-ai-v2: Balanced's waves, picked here in 24 of 38 QA games, won or led 2 of 33; in the plan
				# games against Hard Clockwork OPTIMAL on four maps the Timing attack won or led 3 of 4: GREEDY_CLOCK)
				var k := _weighted(GREEDY_CLOCK)
				return [k, "out-expand it" if k == "economy" else _normal_why(k)]
			if f == "crown" and _mirror_keep():
				return []            # (crown-v-crown-coach: the Timing attack keeps its timing)
			if t < TOO_LATE:
				if f == "crown":
					return ["timing", "Horsemen are no answer to Musketeers: a timing attack"]
				return ["timing", "a timing attack before its economy pays off"]
			return ["economy", "too late to punish: out-expand it"]
		"clockwork":
			if f == "clockwork":
				# (coached games, 0.32.0: the Clock Soldier rush on a greedy Clockwork ended behind both times, 9,000-9,300
				# earned against 11,800-12,500, where Balanced in the same seat was even or close: the mirror's Clock Soldiers
				# come at 2:00 whatever it plays. Balanced's steady waves on two Clocktowers)
				return ["balanced", "steady waves punish the greed"]
			if early:
				return ["cs_rush", "punish the greed before its army is up"]
			if t < TOO_LATE:
				return ["springer", "a timing attack before its economy pays off"]
			return ["economy", "too late to punish: out-expand it"]
		"brood":
			if early and f != "crown":
				return ["rush", "punish the greed before its army is up"]
			if t < TOO_LATE:
				return ["spitter" if f == "crown" else "timing", "a timing attack before its economy pays off"]
			return ["economy", "too late to punish: out-expand it"]
	return []


## THE RIDERS ONLY FOR A TRULY GREEDY BROOD (econ-coach-crown, docs/econ-coach-crown.md): the Brood's standard opening, the
## Mother and one Mound Turtle on new ground at 0:00 (every Brood plan but the rushes), read "a second base and little army"
## in 35 of 38 games, and the Horseman rush that answered it failed 33 of 38 times (docs/winrate_2026_11_12.md), the riders
## costing the Crown its economy (16 labourers held, the Breeder and Horsemen before the second hall). The owner's rule stays
## (v a greedy Brood the Horse Breeder to punish) for a TRUE greed: more than its standard opening, two grounds beyond the
## Mother's (TRUE_GREED_HALLS halls in the scout's count) or TRUE_GREED_MAWS Rootmaws seen. Else it out-expands it, as the
## rule's own fallback did.
## MEASURED AND NOT KEPT AS THE DEFAULT (econ-coach-crown, 11 games against the 11 of the win-rate study): the Economy race
## earned +20% by 8:00-10:00 (0.60 -> 0.73 of the bench) but stood with 0-60 of army till 6:00, the Brood's economy was left
## alone and its army at 8:00 doubled (1,000-2,600 against 800-1,500), and the Crown lost 8 where it had lost 6. The riders'
## worth against the Brood is in the BROOD's economy, not the Crown's: the owner's rule plays every greedy read again; this
## stays a study switch, `-- truegreed:on`.
const TRUE_GREED_HALLS := 3
const TRUE_GREED_MAWS := 5
var true_greed_off := not OS.get_cmdline_user_args().has("truegreed:on")


func _true_greed_brood() -> bool:
	if true_greed_off or ai.scout == null:
		return true
	var r: Dictionary = ai.scout._evaluate()
	var halls := int(r.get("halls", 0))
	var econ := int(r.get("econ", 0))
	var truly := halls >= TRUE_GREED_HALLS or econ >= TRUE_GREED_MAWS
	say("the Brood's greed checked: %d grounds, %d Rootmaws seen: %s" % [halls, econ, "more than its usual opening" if truly else "its usual opening"])
	return truly


## LEANED, NOT BOUND (econ-coach-crown): the lean to the Horseman rush before the scout (the matchup, 20-35% of the Crown's
## games against the Brood) no longer uses up the opening's switch: a read of the Brood that is not a true greed (NORMAL,
## or its usual far turtle) turns it to the Economy race once, while the Breeder is the only rider building yet (BREEDER_BY).
## A study switch with truegreed:on (measured with it, not the default): `-- leanfree:on`.
var lean_free_off := not OS.get_cmdline_user_args().has("leanfree:on")


func _lean_only() -> bool:
	return not lean_free_off and picks.size() == 1 and String(picks[0][2]) == "LEAN" and current == "rush" and game.clock < BREEDER_BY


## (crown-v-crown-coach) THE TIMING KEEPS ITS TIMING in the Crown mirror: a greedy read after TOO_LATE turned the Timing
## attack into the Economy race just as its army stood ready (greenhold 1103, 6:31: 1,305 of army against 610, picked
## "too late to punish: out-expand it", and the army sat at home on one hall). A greedy enemy is what the timing is for:
## it keeps its plan and goes.
func _mirror_keep() -> bool:
	return fac == "crown" and current == "timing" and not OS.get_cmdline_user_args().has("mirror:off")


## A read came in (AIScout._apply -> AI.on_read, or the Brood's own _nb_read).
func on_read(verdict: String, saw: String) -> void:
	var read := AIRead.word(verdict)
	if read == "UNKNOWN":
		if unknown_t < 0.0:
			unknown_t = game.clock
		return                  # (the scout looks again soon: AIScout.rescout_unknown)
	var c := choose(read)
	if c.is_empty():
		say("reads %s [%s]: keeps %s (%s)" % [read, saw, plan_name(current), "what it plays already answers it"])
		return
	_go(String(c[0]), String(c[1]), read, saw)


## No read by DECIDE_BY: a normal game for the matchup (once).
func tick() -> void:
	# (no read by DECIDE_BY, or an UNKNOWN that the next look did not settle within UNKNOWN_WAIT: the common opening's gold
	# piled up while it waited, 308 gold at 1:55 against a walled Crown in the coached games)
	var due := game.clock >= DECIDE_BY or (unknown_t >= 0.0 and game.clock >= unknown_t + UNKNOWN_WAIT)
	if picks.is_empty() and due and current == opening_plan:
		var c := choose("NORMAL") if stage_of(game.clock) == "opening" else []
		if c.is_empty():
			c = ["balanced", "a normal game"]
		_go(String(c[0]), String(c[1]), "UNKNOWN", "no read yet")


func _go(plan: String, why: String, read: String, saw: String) -> void:
	var st := stage_of(game.clock)
	if not AI.strategies_for(fac).has(plan):
		plan = "balanced"
	if plan == current:
		# (no change: it is no switch, a later read in this stage may still change the build)
		if picks.is_empty():
			picks.append([snappedf(game.clock, 0.1), st, read, plan, why])
		say("reads %s [%s]: keeps %s (%s)" % [read, saw, plan_name(current), why])
		return
	# (survival: a rush read while it plays a greedy build or its own early rush, which has no wall gate and no line yet)
	var survival := read == "AGGRESSIVE" and current in ["economy", "rush", "cs_rush"] and plan in ["balanced"] and not survival_used
	if switched.has(st) and not survival:
		if not _held_said.has(st):
			_held_said[st] = true
			say("reads %s [%s]: keeps %s (it switched once this stage already; %s waits)" % [read, saw, plan_name(current), plan_name(plan)])
		return
	if plan != current and not ai.opt_switch(plan):
		say("reads %s [%s]: keeps %s (%s cannot be played from here)" % [read, saw, plan_name(current), plan_name(plan)])
		return
	if survival and switched.has(st):
		survival_used = true
	switched[st] = true
	current = plan
	picks.append([snappedf(game.clock, 0.1), st, read, plan, why])
	say("reads %s [%s]: picks %s (%s)" % [read, saw, plan_name(plan), why])


## Before the scout: a lean from the matchup and the map (the owner: "it could decide on a Horseman rush based on the map
## or the matchup"). Only the Crown against the Brood leans to its Horseman rush (short rush distance, more often);
## it counts as the opening's pick.
func lean_now() -> String:
	if ai.difficulty < 1 or OS.get_cmdline_user_args().has("optlean:off"):
		return ""                # (optlean:off: the tests and studies of the common opening, tools/test_ai_wall_vs_rush.gd)
	var f: int = ai._foe()
	var d: float = Vector2(game.starts[team]).distance_to(Vector2(game.starts[f])) if f >= 0 else 999.0
	if _rng.randf() < _lean_chance(foe(), d):
		lean = "rush"
		return "rush"
	return ""


## The chance to lean to the Horseman rush before scouting: against the Brood only, more on a short map (start to start
## in tiles).
func _lean_chance(f: String, dist: float) -> float:
	if fac != "crown" or f != "brood":
		return 0.0
	return 0.35 if dist < 70.0 else 0.2


func lean_said(plan: String) -> void:
	if lean_free_off or fac != "crown" or foe() != "brood":
		switched["opening"] = true       # (econ-coach-crown: the Crown's lean against the Brood leaves the switch to the read)
	current = plan
	picks.append([0.0, "opening", "LEAN", plan, "the matchup"])
	say("leans to %s before it scouts (%s)" % [plan_name(plan), "Horsemen are good against the Brood's grubs"])


## (clockwork-v-clockwork-coach) THE CLOCKWORK'S TURRETS ARE NO TURTLE. The Clockwork computer lays Ratchet Turrets only as
## an answer (a rush, a raid at an expansion: the owner's rule, "static defence is not a build"), so in the mirror a
## DEFENSIVE read is a few reactive turrets, not a turtle to siege. It switched the middle game to the Heavy Works push and
## its written build: no soldiers while it saved for Ballistas and a Great Winder, 874 cogs in the bank at 8:06 and 1,915 at
## 9:06 while the enemy's push (1,990) broke its army of 1,450 at home (Cinder Steps mirror, round 5, 7:52-9:24; the game
## lost at 13:14). In the mirror after the opening a DEFENSIVE read keeps what it plays. `-- optturrets:off` as before.
func _mirror_turrets() -> bool:
	if fac != "clockwork" or foe() != "clockwork" or stage_of(game.clock) == "opening":
		return false
	return not OS.get_cmdline_user_args().has("optturrets:off")
