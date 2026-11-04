extends RefCounted
## AI TRANSITIONS (the owner's playtest 2026-11-01, AI Crown v AI Crown on Ashfall, v0.25.25; docs/ai_crown_transitions.md).
## Green held a Horseman rush at 4:15 and then sat in its defensive build for minutes: no expansion until 8:52, nine
## labourers for six minutes, and a first attack of 11 supply at 6:28 that turned round at the gate. The owner: "the moment
## green held the horse rush it should either have expanded or committed to an attack immediately".
##
## While the scout's verdict is "rush" (AIScout: a defensive build, DEFEND_MOD), this watches for the rush being HELD: no
## armed enemy near our buildings for QUIET s after a fight at home (or NO_SHOW s after the verdict with none), and our
## army worth at least what the enemy showed lately. Then it picks ONE transition, at once:
##   COUNTER  our army is worth ATTACK_EDGE times the enemy's and is ATTACK_MIN_SUP supply or more: the whole army goes
##            out now, as one wave (the defensive regroup wait is lifted, the bar set to what stands at home), and the
##            economy comes back behind it (AFTER_MOD: a hall soon, labourers);
##   EXPAND   otherwise, one hall only and the land safe: the next hall comes now (AFTER_MOD), the army stays home to
##            cover it, and the next wave waits for a real force (never a trickle: WAVE_MIN, or 1.6 times the enemy's
##            supply seen plus 4);
##   BUILD    already on two halls: the economy and tech come back (AFTER_MOD), the next wave waits for a real force.
## Design: docs/design_principles.md 2 (the defender's advantage fades so the game can move on: a held rush is a lead the
## defender must use, not a reason to turtle) and 4 (the player is the strategist: every choice has an opportunity cost).

const QUIET := 10.0             # s with no armed enemy near our buildings after a fight at home
const NO_SHOW := 75.0           # s after a rush verdict with no fight at home: the rush is not coming (or turned back)
const NEAR := 420.0             # (pixels) an armed enemy this near one of our buildings is still "at the door"
const EVEN := 1.0               # our army worth at least this times the enemy's seen lately: the rush is held
const ATTACK_EDGE := 1.5        # ... this times: counter-attack
const ATTACK_MIN_SUP := 12      # ... and at least this much supply (a smaller force is a trickle)
const WAVE_MIN := 16            # the least supply of the next wave when it expands or builds instead
const AFTER_MOD := {"expand": 0.35, "halls": 3, "workers": 1.1}

var ai = null
## (`-- tr:off` on the command line plays the computer as before (0.25.25), for before/after study games)
var on := not OS.get_cmdline_user_args().has("tr:off")
var done := false               # a transition was picked (once a game)
var choice := ""                # "counter", "expand", "build"
var at := -1.0                  # when
var _fight := false             # an armed enemy came near our buildings since the rush verdict
var _quiet_since := -1.0
var _verdict_t := -1.0
var _next := 0.0


func _init(a) -> void:
	ai = a


var game:
	get:
		return ai.game


func active() -> bool:
	return on and ai._crown() and ai.difficulty >= 1 and not ai.peaceful and ai.scout != null and ai.scout.enabled


## Every army think (AI stage 3, after the scout and before the army).
func tick() -> void:
	if done or not active() or ai.scout.verdict != "rush":
		return
	if game.clock < _next:
		return
	_next = game.clock + 1.0
	if _verdict_t < 0.0 or ai.scout.decided_at > _verdict_t:
		_verdict_t = ai.scout.decided_at
	if _armed_near():
		_fight = true
		_quiet_since = -1.0
		return
	if _quiet_since < 0.0:
		_quiet_since = game.clock
	var quiet: float = game.clock - _quiet_since
	if quiet < QUIET:
		return
	if not _fight and game.clock - _verdict_t < NO_SHOW:
		return
	if ai._attacking:
		return
	ai._horse_watch()
	var foe: float = maxf(ai._horse_seen_value(), float(ai.scout._recent_army()[0]))
	var foe_sup: int = int(ai.scout._recent_army()[1])
	var army: Array = game.army(ai.team).filter(func(u: Unit) -> bool: return u.kind != "powder_wagon" and u.has_attack())
	var mine := 0.0
	for u in army:
		mine += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
	var sup: int = ai._army_supply(army)
	if mine < maxf(foe, 60.0) * EVEN:
		return              # (not held yet: the defence goes on, AIScout.DEFEND_FOR)
	var why := "the rush held (%s), its army %d against the %d it saw" % ["no rider near for %d s" % int(quiet) if _fight else "nothing came", int(mine), int(foe)]
	if mine >= maxf(foe, 60.0) * ATTACK_EDGE and sup >= ATTACK_MIN_SUP and (not ai.has_method("counter_ok") or ai.counter_ok()):
		_pick("counter")
		ai._regroup_until = 0.0
		ai._pull_until = 0.0
		ai._attack_at = maxi(ATTACK_MIN_SUP, int(floor(sup * 0.85)))
		_say("%s: counter-attacks now with its whole army (%d supply), the economy behind it" % [why, sup])
	elif ai._halls().size() <= 1:
		_pick("expand")
		ai._attack_at = maxi(ai._attack_at if ai._attack_at < 999 else 0, maxi(WAVE_MIN, int(ceil(foe_sup * 1.6)) + 4))
		_say("%s: expands now, the army at home covers it; the next attack waits for %d supply" % [why, ai._attack_at])
	else:
		_pick("build")
		ai._attack_at = maxi(ai._attack_at if ai._attack_at < 999 else 0, maxi(WAVE_MIN, int(ceil(foe_sup * 1.6)) + 4))
		_say("%s: back to economy and tech; the next attack waits for %d supply" % [why, ai._attack_at])


## The EXPAND choice: the second hall comes first (AI._hall_first holds the gold for it, the guards walk over), for
## HALL_FOR s after the choice (then the usual rules again). Picked at 5:58 without it, the hall came at 10:28 (Ashfall):
## the Armoury, a Barracks, the Church and four researches took the gold first.
const HALL_FOR := 240.0


func want_hall() -> bool:
	# (not while the enemy has shown a bigger army since (AI.army_short): Ashfall study, green expanded at 5:38 on a sighting
	# of 230 while yellow's 730 counter-attacked at 5:09, and lost the game; the usual hall rules apply then)
	return done and choice == "expand" and game.clock - at < HALL_FOR and not ai.army_short()


func _pick(c: String) -> void:
	done = true
	choice = c
	at = game.clock
	ai.scout.mod = AFTER_MOD.duplicate()
	ai.scout.want_wall = false


## An armed enemy unit (not a worker or a scout) near one of our buildings.
func _armed_near() -> bool:
	for b in game.buildings:
		if b.team != ai.team or b.dead or b.ghost:
			continue
		if b.kind == "wall" or b.kind == "gate":
			continue        # (a rider outside the ramp wall is not in the base: the halls and the rest are what count)
		for u in game.units_near(b.center(), NEAR):
			if game.hostile(u.team, ai.team) and not u.dead and not u.off_field and not u.is_worker() and u.has_attack():
				return true
	return false


func _say(s: String) -> void:
	if game.mlog:
		game.mlog.add("%s %s" % [game.mlog.who(ai.team), s])
