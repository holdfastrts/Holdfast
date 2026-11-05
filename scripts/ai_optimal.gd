class_name AIOptimal
extends RefCounted
## THE OPTIMAL PLAN (ai-optimal, the owner 2026-11-05 09:54; docs/ai_optimal.md): "a plan called OPTIMAL that is adaptive,
## has access to all the plans, and picks from each plan to the adaptive necessities of the matchup". Each faction's own
## computer (AICrown, AIClockwork, AIBroodNew) plays its COMMON OPENING (the Crown's ramp Cottage, Gate and second Farm;
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
const DECIDE_BY := 150.0         # no read by then: a normal game for the matchup
const PUNISH_BY := {"crown": 150.0, "clockwork": 150.0, "brood": 150.0}    # a rush to punish greed only before this
const TOO_LATE := 330.0          # a timing attack to punish greed only before this; later, out-expand it

var ai = null
var game: Game = null
var team := 0
var fac := ""
var current := ""                # the build it plays now (an AI.STRATEGIES key)
var picks: Array = []            # [clock, stage, read, plan, why] of every pick
var switched := {}               # stage -> true once it switched in that stage
var survival_used := false
var lean := ""                   # the build it leaned to before the scout (the matchup or the map)
var log: Array = []              # [clock, text]
var _rng := RandomNumberGenerator.new()
var _held_said := {}


func _init(a, opening_plan: String) -> void:
	ai = a
	game = a.game
	team = a.team
	fac = game.faction_of(team)
	current = opening_plan
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
	return String(AI.STRATEGIES.get(k, AI.STRATEGIES["balanced"])["name"])


func say(s: String) -> void:
	log.append([game.clock, s])
	ai.say("optimal: " + s)


## The plan a NORMAL read leads to, by the matchup (weights), with a little chance in it.
const NORMAL := {
	"crown": {"brood": {"balanced": 3.0, "siege": 2.0, "timing": 2.0},
		"clockwork": {"balanced": 3.0, "economy": 2.0, "dragoon": 2.0, "timing": 1.0},
		"crown": {"economy": 3.0, "balanced": 2.0, "dragoon": 2.0, "siege": 1.0, "timing": 1.0}},
	"clockwork": {"brood": {"pendulum": 3.0, "balanced": 2.0, "owls": 2.0},
		"crown": {"balanced": 2.0, "economy": 2.0, "springer": 2.0, "heavy": 1.0},
		"clockwork": {"balanced": 2.0, "economy": 2.0, "springer": 1.0, "cs_rush": 1.0}},
	"brood": {"crown": {"balanced": 2.0, "spitter": 2.0, "brute": 2.0, "timing": 1.0},
		"clockwork": {"timing": 2.0, "spitter": 2.0, "balanced": 2.0},
		"brood": {"balanced": 2.0, "timing": 2.0, "economy": 1.0, "rush": 1.0}},
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
			if st == "opening" or current in ["economy"]:
				return ["balanced", "defend the rush first, then counter-attack"]
			return []
		"GREEDY":
			return _punish(f, t)
		"DEFENSIVE":
			if st == "opening":
				return ["economy", "out-expand and tech, then a siege"]
			match fac:
				"crown":
					return ["siege", "a siege to break its defences"]
				"clockwork":
					return ["heavy", "a siege to break its defences"]
				"brood":
					return ["brute", "a siege to break its defences"]
		"NORMAL":
			if st != "opening":
				return []        # (a normal read later keeps what it plays)
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
		"dragoon", "owls":
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
			if f == "brood" and early:
				return ["rush", "punish the greed before its army is up"]
			if f == "clockwork" and early and _rng.randf() < 0.35:
				return ["rush", "punish the greed before its army is up"]
			if t < TOO_LATE:
				if f == "crown":
					return ["timing", "Horsemen are no answer to Musketeers: a timing attack"]
				return ["timing", "a timing attack before its economy pays off"]
			return ["economy", "too late to punish: out-expand it"]
		"clockwork":
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


## A read came in (AIScout._apply -> AI.on_read, or the Brood's own _nb_read).
func on_read(verdict: String, saw: String) -> void:
	var read := AIRead.word(verdict)
	if read == "UNKNOWN":
		return                  # (the scout looks again soon: AIScout.rescout_unknown)
	var c := choose(read)
	if c.is_empty():
		say("reads %s [%s]: keeps %s (%s)" % [read, saw, plan_name(current), "what it plays already answers it"])
		return
	_go(String(c[0]), String(c[1]), read, saw)


## No read by DECIDE_BY: a normal game for the matchup (once).
func tick() -> void:
	if picks.is_empty() and game.clock >= DECIDE_BY:
		var c := choose("NORMAL") if stage_of(game.clock) == "opening" else []
		if c.is_empty():
			c = ["balanced", "a normal game"]
		_go(String(c[0]), "no read yet: " + String(c[1]), "UNKNOWN", "too little of its base")


func _go(plan: String, why: String, read: String, saw: String) -> void:
	var st := stage_of(game.clock)
	if not AI.strategies_for(fac).has(plan):
		plan = "balanced"
	if plan == current and not picks.is_empty():
		say("reads %s [%s]: keeps %s (%s)" % [read, saw, plan_name(current), why])
		return
	var survival := read == "AGGRESSIVE" and current == "economy" and not survival_used
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
	if fac != "crown" or foe() != "brood" or ai.difficulty < 1:
		return ""
	var f: int = ai._foe()
	var d: float = Vector2(game.starts[team]).distance_to(Vector2(game.starts[f])) if f >= 0 else 999.0
	var chance := 0.35 if d < 70.0 else 0.2
	if _rng.randf() < chance:
		lean = "rush"
		return "rush"
	return ""


func lean_said(plan: String) -> void:
	switched["opening"] = true
	current = plan
	picks.append([0.0, "opening", "LEAN", plan, "the matchup"])
	say("leans to %s before it scouts (%s)" % [plan_name(plan), "Horsemen are good against the Brood's grubs"])
