class_name AIHunt
extends RefCounted
## THE HUNT (rules-fixes 3, owner 2026-11-11 "dead sides should lose, winners hunt"; docs/rules_fixes.md): the QA study
## (docs/qa_2026_11_08_matches.md point 4) saw 29 games where one side had no workers and no army for minutes and the
## winner sat at home until the 15:00 draw. Now a computer whose enemy has no fighting unit left (and has had one, or the
## game is past HUNT_AFTER) sends its army out to the enemy's buildings, nearest first, then to its last units (the
## Brood's Mother), and keeps re-sending the idle ones until the enemy fields an army again. The computer knows where
## the enemy's buildings are (as _enemy_base does), so no separate scouting is needed. Called from AI._army and
## AIBroodNew._nb_army after their defence; true = the army is hunting (the wave logic waits).

const EVERY := 5.0              # s between looks
const HUNT_AFTER := 480.0       # with no enemy army ever seen, the hunt may start from 8:00
const MIN_UNITS := 3            # a hunt needs at least this many fighters
const LEASH := 260.0            # a hunter going somewhere farther than this from the target is re-sent

var ai: AI
var on := false
var _next := 0.0
var _had_army := {}             # foe team -> true once it had a fighting unit
var _goal := Vector2.INF


func _init(owner: AI) -> void:
	ai = owner


## A fighting unit of team t: armed, not a worker, not a horse.
static func fighter(u: Unit, t: int) -> bool:
	return u.team == t and not u.dead and u.kind != "horse" and not u.is_worker() and u.armed()


static func has_army(game: Game, t: int) -> bool:
	for u in game.units:
		if fighter(u, t):
			return true
	return false


func tick(army: Array) -> bool:
	var game: Game = ai.game
	if game.clock < _next:
		return on
	_next = game.clock + EVERY
	var foe: int = ai._foe()
	if foe < 0 or ai.peaceful:
		return _stop("")
	if has_army(game, foe) and not ai._hunt_anyway(foe, army):
		_had_army[foe] = true
		return _stop("the enemy has an army again")
	if has_army(game, foe):
		_had_army[foe] = true          # (crown-v-crown-coach: a hunt on anyway over a token army, AI._hunt_anyway)
	if not _had_army.has(foe) and game.clock < HUNT_AFTER:
		return false
	var hunters: Array = army.filter(func(u: Unit) -> bool: return fighter(u, ai.team) and not BroodRoot.fixed(u) and u.order != "sacrifice")
	if hunters.size() < MIN_UNITS:
		return _stop("too few to hunt with")
	_goal = ai._hunt_goal(foe, game.center_of_team(ai.team))
	if _goal == Vector2.INF:
		return _stop("")
	if not on:
		on = true
		if game.mlog:
			game.mlog.add("%s hunts: the enemy has no army left (%d units go for its last buildings)" % [game.mlog.who(ai.team), hunters.size()])
	for u in hunters:
		var busy: bool = u.order in ["amove", "move", "d_amove"] and u.order_point.distance_to(_goal) < LEASH
		if u.target != null and is_instance_valid(u.target) and not u.target.dead:
			busy = true             # (already fighting something: it finishes it first)
		if not busy:
			u.cmd_move(_goal + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)
	return true


func _stop(why: String) -> bool:
	if on and ai.game.mlog and why != "":
		ai.game.mlog.add("%s ends the hunt: %s" % [ai.game.mlog.who(ai.team), why])
	on = false
	return false


## Where to go: the enemy's nearest building, else its nearest unit (the Brood's Mother, a last worker), else its start.
static func _target(game: Game, foe: int, from: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for b in game.buildings:
		if b.team == foe and not b.dead and not b.ghost:
			var dd: float = b.center().distance_to(from)
			if dd < bd:
				bd = dd
				best = b.center()
	if best != Vector2.INF:
		return best
	for u in game.units:
		if u.team == foe and not u.dead and not u.off_field and u.kind != "horse":
			var dd: float = u.position.distance_to(from)
			if dd < bd:
				bd = dd
				best = u.position
	if best != Vector2.INF:
		return best
	return Vector2(game.starts[foe]) * Defs.TILE if foe < game.starts.size() else Vector2.INF
