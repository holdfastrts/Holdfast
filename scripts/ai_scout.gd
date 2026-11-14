class_name AIScout
extends RefCounted
## The computer's scouting and what it makes of it (design_principles.md section 3: buildings
## reveal strategy fairly; scouting and counter-scouting).
##
## Unless its plan is a rush (or the air rush), which acts from the first second, a Normal or
## Hard computer sends one worker to look at the enemy's base first, and plays a plain opening
## (no early greed) until the scout reports. What it sees decides:
##   rush      the enemy has an early army, or a minimal economy with several production
##             buildings: a defensive game (army first, walls where the faction has them,
##             hold, counter when the army is bigger)
##   greedy    an expansion up early and little or no army, or a full economy with no
##             military building at all: a TIMING ATTACK sized and timed from what was seen
##   balanced  neither: carry on with the plan it was given
##   uncertain the scout was denied (killed, walled out, no path) or saw too little: that is
##             not proof of anything. It plays SAFE (an army and walls, expands without
##             greed) and sends a scout again a minute or two later.
## It only uses what its own side can see (Game.is_visible_to: the fog of war), remembers the
## enemy buildings it has seen, and revises its decision from new sightings, but at most once
## every REDECIDE seconds so it does not flip-flop. Its decisions go to the match log.

const START_AT := 18.0          # (game seconds) the first scout leaves, once it has a few workers
const MIN_WORKERS := 5
const REDECIDE := 75.0          # the least time between two decisions
const RECENT := 150.0           # an army sighting counts for this long
const RESCOUT_DENIED := 85.0    # a denied scout: the next one goes after this long
const RESCOUT_REFRESH := 170.0  # otherwise a fresh look (new hall, new tech) every so often
const MAX_TRIPS := 5
const SHOOTER_MARGIN := 80.0    # (pixels) how far outside a shooter's range the scout stands off
const MELEE_MARGIN := 70.0      # ... and outside an armed melee soldier's reach
const WATCH_FOR := 50.0         # how long it watches the ramp from its stand-off spot
const MAX_FLEES := 3            # driven back this often: it goes home
const DANGER_FOR := 30.0        # a shooter seen this long ago still counts when picking a stand-off spot
const DEFEND_FOR := 210.0       # how long a defensive game lasts before the verdict is looked at again
## Production and tech buildings: seeing them says "this enemy builds an army".
const MILITARY := ["barracks", "horse_breeder", "foundry", "armoury",
	"assembly_works", "engine_hall", "capacitor_works", "movement_works", "escapement", "cuckoo_house"]
## What a minute of a rush looks like, per faction: the army value seen before 6:00 that counts as a rush
## (the Brood's cheap bodies come early whatever it plays: it takes much more).
const RUSH_VALUE := {"crown": 300.0, "clockwork": 360.0, "brood": 800.0}
## When a timing attack hits by default (game seconds), per faction: a Crown musket / horse
## line, a Brood swarm (earlier: it hatches fast), a Clockwork power spike (later: its
## Engine Hall and Pylon first).
const TIMING_AT := {"crown": 330.0, "brood": 290.0, "clockwork": 400.0}
const TIMING_MIN_SUP := {"crown": 14, "brood": 20, "clockwork": 12}
## What a plain opening leaves out until the scout has reported.
const PENDING_MOD := {"expand": 1.0, "halls": 3, "workers": 1.0}
const SAFE_MOD := {"expand": 1.4, "halls": 3, "tech": 1.0, "workers": 1.0}
const DEFEND_MOD := {"expand": 2.2, "halls": 2, "tech": 1.25, "workers": 0.85}

var ai: AI
var game: Game
var enabled := false
var passive := false            # (not enabled: still reads the rush from what its side's units see; AIClockwork's written builds)
var state := "wait"             # wait, going, done
var verdict := "pending"        # pending, balanced, rush, greedy, uncertain
var reason := ""
var decided_at := -999.0
var unit: Unit = null           # the scout on the road
var trips := 0
var next_trip := START_AT
var min_workers := MIN_WORKERS   # (crown-owner-eco: the owner's plans send the first scout at once, AICrown._ready)
var sent_at := 0.0
var last_end := 0.0
var mod := {}                   # overrides for AI._s()
var want_wall := false
var timing_target := 0          # supply a scouted timing attack waits for
var defend_until := 0.0
var log_lines: Array = []
## What the scout has learned about the enemy's army (kept across trips; read by the build and
## defence logic: AIScout.proof_not_horse_rush(), enemy_has_ranged()).
var foe_kinds_seen := {}        # armed unit kind -> true
var foe_ranged_seen := false    # a shooter (range beyond a bayonet's reach) was seen
var foe_max_range := 0.0        # the longest weapon range seen (pixels)
var foe_nonhorse_seen := false  # a SLOW armed soldier of a faction whose rush is mounted (the Crown): not a horse rush
var foe_rush_seen := {}         # fast rush unit kind -> {"count" (most seen at once), "first" (clock), "last", "speed", "pos"}
var foe_first_military := -1.0  # when an armed soldier or a military building was first seen
var foe_rush_logged := false
var foe_early_prod := {}        # military building kind -> clock it was first seen
## Production buildings that this early (game seconds) are an opening that goes for units at once. (The Brood has no
## buildings: its Tyrant Sire rooted on his nest is its barracks, BroodNew.is_father; seen this early, it rushes.)
const EARLY_PROD := {"tyrannosaur": 130.0, "assembly_works": 100.0, "movement_works": 100.0, "horse_breeder": 110.0}
## (ai-optimal: a Horse Breeder by 1:50 is the Horseman rush's; every other Crown plan has its Breeder from 2:00 on. The
## coached game c-v-c rush Redrock 1:30 read a Barracks and a Breeder with no Horseman out yet as NORMAL)
## THE BROOD'S BUILDINGS ARE CREATURES (0.18.0): rooted, the Brood Mother is its hall, a Rootmaw an economy building, a
## Sire a production building, and a Mound Turtle rooted far from her an expansion (BroodNew.expansion_counts). The
## scout counts what it saw of them as it counts buildings (_nb_seen); BROOD_ECON_CAP is the Rootmaws of a full early
## economy (the computer roots 2, then one more every 100 s).
const BROOD_ECON_CAP := 3
var _nb_seen := {}              # enemy rooted Brood creature (or its Mother, rooted or not) -> true
var standoff_log: Array = []    # (the stand-off spots chosen; tests read it)       # (what went to the match log; tests read it)

var _foe := -1
var _wps: Array = []
var _wp_i := 0
var _seen_b := {}               # enemy building -> true (alive when last looked)
var _army_hist: Array = []      # [clock, value, supply] of what the enemy army looked like
var _workers_seen := 0
var _far_army_t := -1.0         # when part of its army was last seen out in the field
var _plateau: Array = []
var _cells_seen := {}
var _hall_seen := false
var _stuck := 0.0
var _mode := "route"            # route, flee (backing out of shooters' range), watch (standing off)
var _flees := 0
var _flee_t := 0.0
var _watch_pt := Vector2.ZERO
var _watch_until := 0.0
var _danger := {}               # armed enemy unit -> [position, clock] (seen lately)
var _ramp_pt := Vector2.INF     # the ramp up to the enemy's main nearest to us (pixels)
## The sentry: one cheap worker that keeps watch at the foot of a walled ramp (see _sentry_tick).
var sentry: Unit = null
var sentry_posts := 0           # how many sentries were posted (a lost one is replaced, a few times)
var sentry_flees := 0
var sentry_losses := 0
var denied_trips := 0           # trips that ended blocked / driven off / lost before the enemy's hall was seen
var sentry_log: Array = []      # ([clock, text] of what it did; tests read it)
var _sentry_next := 0.0
var _sentry_pt := Vector2.INF
var _sentry_fleeing := false


func _init(a: AI) -> void:
	ai = a
	game = a.game
	enabled = a.difficulty >= 1 and not a.peaceful and not (a.strategy in ["rush", "air", "xrush"])
	if enabled:
		mod = PENDING_MOD.duplicate() if a.strategy != "balanced" else {}


func _log_has_text(text: String) -> bool:
	return log_lines.any(func(l) -> bool: return String(l).contains(text))


## (AI._resume: the worker safety let the scout flee with the others; it goes back to its trip, not to work)
func resume_trip(u: Unit) -> void:
	if u == unit and state == "going" and _wp_i < _wps.size():
		_stuck = 0.0
		_go(u, _wps[_wp_i])
	elif u == sentry:
		u.cmd_stop()


func is_scout(u: Unit) -> bool:
	return (unit != null and u == unit) or (sentry != null and u == sentry)


func _say(msg: String) -> void:
	var line := "%s %s" % [game.mlog.who(ai.team) if game.mlog else "P%d" % (ai.team + 1), msg]
	log_lines.append(line)
	if game.mlog:
		game.mlog.add(line)


func _faction() -> String:
	return game.faction_of(ai.team)


# ------------------------------------------------------------------ the think

func tick() -> void:
	if game.over:
		return
	if not enabled:
		if passive and ai._foe() >= 0:
			# (no scout of its own: what its units see still says a rush is coming, ai-optimal: survival always)
			_foe = ai._foe()
			_observe()
			_check_rush_units()
		_sentry_alone()
		return
	var foe := ai._foe()
	if foe < 0:
		return
	if foe != _foe:
		_foe = foe
		_seen_b.clear()
		_nb_seen.clear()
		_army_hist.clear()
		_cells_seen.clear()
		_plateau = []
		_workers_seen = 0
		_hall_seen = false
		_danger.clear()
		_ramp_pt = Vector2.INF
		foe_kinds_seen.clear()
		foe_ranged_seen = false
		foe_max_range = 0.0
		foe_nonhorse_seen = false
		foe_rush_seen.clear()
		foe_first_military = -1.0
		foe_rush_logged = false
		foe_early_prod.clear()
	_observe()
	_check_rush_units()
	if state == "going":
		_follow()
	elif state == "wait" or state == "done":
		if verdict == "pending" and game.clock > 260.0 and trips == 0 and state == "wait":
			_apply("uncertain", "no scout got out", "no scout got out")
		if trips < MAX_TRIPS and game.clock >= next_trip and not _busy_with_foe():
			_send()
	_redecide()
	_defence()
	_sentry_tick()


## The enemy is in our base right now (a scout would only be a waste).
func _busy_with_foe() -> bool:
	return ai._threat() != Vector2.INF


# ------------------------------------------------------------------ the scout

func _send() -> void:
	var u := _pick()
	if u == null:
		next_trip = game.clock + 10.0
		return
	var home := game.center_of_team(ai.team)
	_wps = _route(home)
	if _wps.is_empty():
		next_trip = game.clock + 30.0
		return
	unit = u
	if u.is_worker():
		# (ai-optimal: the WORK autocast took an idle scout back to a post on the way, Unit's idle think: the trip ended
		# "pulled away" at 28% of the enemy's main and the story said "could not see the enemy". A scout is not for work)
		u.auto_work = false
	state = "going"
	trips += 1
	sent_at = game.clock
	_wp_i = 0
	_hall_seen = false
	_stuck = 0.0
	_mode = "route"
	_flees = 0
	_go(u, _wps[0])
	var what: String = Defs.UNITS[u.kind]["name"]
	_say("sends a %s to scout%s" % [what, "" if trips == 1 else " again (trip %d)" % trips])


## The scout: from the second denied trip on, the first army unit that is fast; else a worker
## that is not carrying anything (a farmer at the hall).
func _pick() -> Unit:
	if trips >= 2 and verdict == "uncertain":
		var best: Unit = ai.scout_from_army()       # (clockwork-army: the Clockwork's own pick, never a ground fighter)
		if best:
			return best
	var labs: Array = game.workers(ai.team)
	if labs.size() < min_workers and game.clock < 200.0:
		return null
	var pick: Unit = null
	for u in labs:
		if u.order == "build" or u.carrying > 0 or ai._escort.has(u) or u == sentry or ai._held_worker(u):
			continue
		if pick == null or (u.order == "idle" and pick.order != "idle"):
			pick = u
	return pick


## Points to walk: a stand-off point toward us, the hall, then a loop round it.
func _route(home: Vector2) -> Array:
	var st := Vector2(game.starts[_foe]) + Vector2(2.5, 2.0)
	var toward := (home / Defs.TILE - st).normalized()
	if toward == Vector2.ZERO:
		toward = Vector2.RIGHT
	var pts: Array = [st + toward * 9.0]
	_nat_i = -1
	_nat_tried = false
	if game.expansions.size() > _foe and game.expansions[_foe] is Vector2i:
		pts.append(Vector2(game.expansions[_foe]) + Vector2(2.5, 2.0))      # (its natural expansion)
		_nat_i = 1
	pts.append(st + toward * 3.0)
	for off in [Vector2(-9, -8), Vector2(9, -8), Vector2(9, 8), Vector2(-9, 8)]:
		pts.append(st + off)
	var out: Array = []
	var nat := _nat_i
	_nat_i = -1
	for k in pts.size():
		var c := _free_near(Vector2i((pts[k] as Vector2).round()))
		if c.x >= 0:
			if k == nat:
				_nat_i = out.size()
			out.append((Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE)
	return out


var _nat_i := -1                # the natural's waypoint (a scout shut out of the main still goes there)
var _nat_tried := false


func _free_near(c: Vector2i) -> Vector2i:
	for r in range(0, 6):
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var m := Vector2i(x, y)
				if game.in_map(m) and game.solid[game.idx(m)] == 0:
					return m
	return Vector2i(-1, -1)


func _follow() -> void:
	if unit == null or not is_instance_valid(unit) or unit.dead:
		_finish("killed")
		return
	if unit.order == "gather" or unit.order == "build":
		if debug_trips:
			_say("scout pulled away: order %s target %s at %s" % [unit.order, str(unit.order_target), str(unit.position)])
		_finish("pulled away")        # (another part of the computer used it)
		return
	var limit: float = 70.0 + 1.8 * game.center_of_team(ai.team).distance_to(game.start_mid(_foe)) / maxf(20.0, float(unit.d["speed"]))
	if game.clock - sent_at > limit:
		_finish("timeout")
		return
	if _avoid():
		return
	# Held up at a gate or wall on the ramp: a scout is no fighter, but it may break at the
	# structure in its way (the timeout still ends the trip). It does not turn on units.
	if unit.order == "attack" and unit.target is Building and not unit.target.dead:
		return
	var wp: Vector2 = _wps[_wp_i]
	# A soldier scout harasses on its loop (owner, 2026-10-31: "pushed and scouted and tried to harass the worker
	# line"): a worker in reach is attacked; a rooted creature its attack-move took up is walked past (ai_harass.gd).
	if not unit.is_worker() and unit.has_attack():
		var prey := ai.hz().pick_prey(unit)
		if prey != null and prey.position.distance_to(unit.position) < 6.0 * Defs.TILE:
			if unit.order != "attack" or unit.order_target != prey:
				unit.cmd_attack(prey)
			_stuck = 0.0
			return
		if (unit.order == "attack" and AIHarass.is_static(unit.order_target)) or (unit.target != null and AIHarass.is_static(unit.target) and not (unit.target is Building)):
			_pass_until = game.clock + 4.0
			_go(unit, wp)
			return
		if unit.order == "attack" and unit.order_target is Unit and (unit.order_target.dead or (unit.order_target as Unit).is_worker()):
			_go(unit, wp)          # (its prey dead or out of reach: on with the loop)
			return
	# on past a point before standing on it (it must never idle: the workers' code takes idlers)
	if unit.position.distance_to(wp) < 110.0:
		_wp_i += 1
		_stuck = 0.0
		if _wp_i >= _wps.size():
			_finish("done")
			return
		_go(unit, _wps[_wp_i])
		return
	if unit.order == "idle":
		_stuck += 1.0
		if _stuck > 2.0 and game.clock - sent_at > 8.0:
			var wall := _blocker()
			if wall != null:
				unit.cmd_attack(wall)
				_stuck = 0.0
				return
			if _nat_i > _wp_i and not _nat_tried:
				# (ai-optimal: shut out of the main, it still looks at the natural: a Crown always walls its ramp, and its
				# second hall there is the read, GREEDY or not)
				_nat_tried = true
				_wp_i = _nat_i
				_stuck = 0.0
				_go(unit, _wps[_wp_i])
				return
			_finish("blocked")
			return
		_go(unit, wp)


## THE COMPUTER (ALMOST) NEVER USES PLAIN MOVE (owner, 2026-10-30: a scouting Musketeer on a
## MOVE order was killed by one Raptor without firing back). A soldier scouts on ATTACK-MOVE,
## marked "ai_scout" so it fires only at enemies that fight back (Unit._pick_target), not at
## every hall and worker on its loop; a worker scout (no fighter) still walks, and both keep the
## flee logic (_avoid: backing out of a guarded spot is a plain move).
var _pass_until := 0.0          # a soldier scout walks (plain move) past a rooted creature until then


func _go(u: Unit, p: Vector2) -> void:
	if u.is_worker() or game.clock < _pass_until:
		u.cmd_move(p)
		return
	u.set_meta("ai_scout", true)
	u.cmd_move(p, true)


## An armed soldier scout can't outrun this threat (as fast or faster) or outweighs it: it
## turns and fights instead of being run down with its back turned.
func _stands(thr: Array) -> bool:
	if unit.is_worker() or not unit.has_attack():
		return false
	var mine := float(Game.unit_value(unit)) + unit.hp
	var theirs := 0.0
	var faster := false
	for e in thr:
		theirs += float(Game.unit_value(e)) + e.hp
		if float(e.d["speed"]) >= float(unit.d["speed"]) * 0.95:
			faster = true
	return thr.size() <= 2 and (faster or theirs <= mine)


## The nearest wall or gate of the enemy's right by the scout (what holds it up).
func _blocker() -> Building:
	# (NOT unit.has_attack(): that is false for every worker, and a worker is the scout; it hurts
	# a wall all the same, if slowly: damage less armour, at least 1 a blow)
	if float(unit.d["damage"]) <= 0.0 or unit.d.get("no_attack", false):
		return null
	var best: Building = null
	var bd := 170.0
	for b in game.buildings:
		if b.team != _foe or b.dead or not b.built or not unit.can_hit(b) or not (b.kind in ["gate", "palisade", "wall", "stone_wall"] or b.d.get("wall", false)):
			continue
		var dd: float = b.center().distance_to(unit.position)
		if dd < bd:
			bd = dd
			best = b
	return best


func _finish(how: String) -> void:
	state = "done"
	last_end = game.clock
	if unit != null and is_instance_valid(unit) and not unit.dead:
		var home := game.center_of_team(ai.team)
		unit.remove_meta("ai_scout")
		if unit.is_worker():
			unit.auto_work = true          # (home: back to work)
		# (driven off: a retreat, a plain walk home; otherwise a soldier walks home on attack-move)
		unit.cmd_move(home, how != "driven off" and not unit.is_worker())
	unit = null
	_observe()
	if how in ["blocked", "driven off", "timeout"] and not _hall_seen:
		denied_trips += 1        # (shut out: the sentry's reason to watch the ramp)
	var r := _evaluate()
	trip_log.append([game.clock, how, int(_coverage() * 100.0), _hall_seen, String(r["verdict"])])
	if debug_trips:
		_say("scout trip %d ends (%s): saw %d%% of its main, hall seen %s, read %s" % [trips, how, int(_coverage() * 100.0), str(_hall_seen), AIRead.word(String(r["verdict"]))])
	# A scout that was stopped before it saw anything decisive proves nothing (a wall, a
	# few guards): uncertainty, not a rush. What it did see before it fell still counts.
	if how in ["killed", "blocked", "timeout", "driven off"] and r["verdict"] == "uncertain":
		r["saw"] = "the scout was %s" % _how_short(how)
	if how in ["killed", "blocked", "timeout", "pulled away", "driven off"] and r["verdict"] == "balanced" and (not _hall_seen or _coverage() < 0.3):
		if how == "blocked" and int(r["walls"]) >= (DEF_WALLS_CROWN if _foe_faction() == "crown" else 2):
			# (every Crown walls its ramp in its first minute: only a wall all round says DEFENSIVE there)
			# (a wall that keeps the scout out is a read too: DEFENSIVE, ai-optimal)
			r = {"verdict": "defensive", "reason": "a wall shut the scout out (%d wall pieces seen)" % int(r["walls"]), "saw": "a walled ramp that kept the scout out"}
		else:
			r = {"verdict": "uncertain", "reason": "the scout was %s before it saw the base" % _how_text(how), "saw": "the scout was %s" % _how_short(how)}
			_say("scout %s: it saw nothing to go on, will look again soon" % _how_text(how))
	next_trip = game.clock + (rescout_unknown() if r["verdict"] == "uncertain" else RESCOUT_REFRESH)
	# (at most one change of mind every REDECIDE seconds; the first report always counts, and so does the first read after
	# an UNKNOWN: it was no decision)
	if verdict == "pending" or verdict == "uncertain" or game.clock - decided_at >= REDECIDE:
		_apply(r["verdict"], r["reason"], String(r.get("saw", "")))


## (the saw phrase of a denied trip: AIRead.SAW)
func _how_short(how: String) -> String:
	match how:
		"killed":
			return "killed"
		"blocked":
			return "blocked"
		"driven off":
			return "driven off"
	return "turned back"


## UNKNOWN is no reason for an army (the owner, 2026-11-05): the next scout goes soon instead, a minute after the last
## (a soldier from the second denied trip on, _pick).
const RESCOUT_UNKNOWN := 35.0


func rescout_unknown() -> float:
	return RESCOUT_UNKNOWN if absence_on else RESCOUT_DENIED


func _how_text(how: String) -> String:
	match how:
		"killed":
			return "killed"
		"blocked":
			return "blocked (walled out or no path)"
		"timeout":
			return "lost on the way"
		"driven off":
			return "driven off by the enemy's guns"
	return "turned back"


# ------------------------------------------------------------------ what it sees

func _observe() -> void:
	if _foe < 0:
		return
	var t := ai.team
	var hall_kind: String = game.faction_hall(_foe)
	for b in game.buildings:
		if b.team != _foe or b.dead or b.ghost:
			continue
		if game.is_visible_to(t, b.center()):
			_seen_b[b] = true
			if EARLY_PROD.has(b.kind) and not foe_early_prod.has(b.kind):
				foe_early_prod[b.kind] = game.clock
			if b.kind == hall_kind and b == _nearest_start_hall(b):
				_hall_seen = true
	for b in _seen_b.keys():
		if not is_instance_valid(b) or b.dead:
			_seen_b.erase(b)
	for nu in _nb_seen.keys():
		if not is_instance_valid(nu) or nu.dead or (nu.kind != BroodNew.QUEEN and not BroodNew.rooted(nu)):
			_nb_seen.erase(nu)
	var value := 0.0
	var sup := 0
	var workers := 0
	var st: Vector2 = game.start_mid(_foe)
	var rush_now := {}
	for u in game.units:
		if u.team != _foe or u.dead or u.off_field or u.aboard != null:
			continue
		if not game.is_visible_to(t, u.position):
			continue
		if u.is_worker():
			workers += 1
			continue
		if u._k_nb:
			# (the Brood: its rooted creatures are its buildings, its Mother its hall; eggs and food piles are nothing)
			if u.kind == BroodNew.QUEEN or BroodNew.rooted(u):
				_nb_seen[u] = true
				if u.kind == BroodNew.QUEEN:
					_hall_seen = true
				elif EARLY_PROD.has(u.kind) and not foe_early_prod.has(u.kind):
					foe_early_prod[u.kind] = game.clock
			if u.kind == BroodNew.QUEEN or u._k_still or BroodNew.rooted(u):
				continue
		_learn(u)
		# (ai-optimal story audit: fast soldiers seen AT HOME in their own base after the first minutes are its defence, not a
		# rush: our Horsemen raiding the Brood at 3:58 saw 4 Raptors there and the read said AGGRESSIVE, "a rush is coming")
		var mine := game.center_of_team(ai.team)
		var at_home: bool = game.clock > HOME_RUSH_BY and (u.position.distance_to(st) < HOME_R * Defs.TILE \
			or u.position.distance_to(st) < u.position.distance_to(mine))     # (on its own half: not coming at us)
		if _is_rush_unit(u) and not at_home:
			rush_now[u.kind] = int(rush_now.get(u.kind, 0)) + 1
			var e: Dictionary = foe_rush_seen.get(u.kind, {"count": 0, "first": game.clock, "last": game.clock, "speed": float(u.d["speed"]), "pos": u.position})
			e["last"] = game.clock
			e["pos"] = u.position
			foe_rush_seen[u.kind] = e
		if u.kind == "horse" or u.kind == "messenger":
			continue
		value += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
		sup += int(u.d["supply"])
		if u.position.distance_to(st) > 20.0 * Defs.TILE:
			_far_army_t = game.clock
	for k in rush_now:
		foe_rush_seen[k]["count"] = maxi(int(foe_rush_seen[k]["count"]), int(rush_now[k]))
	_workers_seen = maxi(_workers_seen, workers)
	if sup > 0 or (_army_hist.is_empty() and _hall_seen):
		_army_hist.append([game.clock, value, sup])
		if _army_hist.size() > 60:
			_army_hist.pop_front()
	# how much of the enemy's main we have looked at
	if _plateau.is_empty():
		_plateau = game.mapgen.main_area(game.starts[_foe])
	if state == "going" and unit != null and is_instance_valid(unit) and unit.position.distance_to(st) < 26.0 * Defs.TILE:
		for c in _plateau:
			if game.vis[t][game.idx(c)] == 1:
				_cells_seen[c] = true


# ------------------------------------------------------------------ danger and stand-off

static func _is_horseman(u: Unit) -> bool:
	return u.kind in ["horse", "messenger", "dragoon", "cuirassier", "mounted_missionary"] or u.d.get("mounted", false)


## What each faction rushes with (fast units that arrive long before an army would). Anything
## else armed and quick (Defs speed >= RUSH_SPEED) counts too.
const RUSH_KINDS := {
	"brood": ["raptor", "skywing", "storm_challenger"],
	"crown": ["cuirassier", "dragoon"],
	"clockwork": ["ornithopter"],
}
const RUSH_SPEED := 95.0
## Fast soldiers seen within HOME_R tiles of their own start count as rush evidence only before HOME_RUSH_BY (then they are
## a defence at home).
const HOME_R := 20.0
const HOME_RUSH_BY := 150.0
## Before this (game seconds) fast soldiers in numbers are the enemy's opening, not a raid.
const EARLY_RUSH_BY := 270.0


func _foe_faction() -> String:
	return game.faction_of(_foe) if _foe >= 0 else ""


## Is this a rush unit of the enemy's faction (fast, armed, and not a lone horse or messenger)?
func _is_rush_unit(u: Unit) -> bool:
	if u.kind == "horse" or u.kind == "messenger" or u.is_worker() or not u.has_attack():
		return false
	if RUSH_KINDS.get(_foe_faction(), []).has(u.kind):
		return true
	return float(u.d.get("speed", 0)) >= RUSH_SPEED


## True once the scout has seen a SLOW armed foot soldier of a faction whose rush is mounted
## (only the Crown: its Horsemen and Dragoons are the rush, a Musketeer line is the standard
## opening). Never set against the Brood or Clockwork: their quick units (Raptors, Skywings,
## Ornithopters) are the rush itself, see rush_units_seen().
func proof_not_horse_rush() -> bool:
	return foe_nonhorse_seen


func enemy_has_ranged() -> bool:
	return foe_ranged_seen


## The most fast rush soldiers of the enemy seen at once so far.
func rush_units_seen() -> int:
	var n := 0
	for k in foe_rush_seen:
		n += int(foe_rush_seen[k]["count"])
	return n


## Evidence of a rush from what was seen: fast units in numbers (or any, very early), or a
## great deal of army very early. "rush", or "" when there is none.
func rush_evidence() -> String:
	# (a Light Works up by 1:40 is every Clockwork's ordinary opening, not a rush: two of them by 2:30 is)
	var works_early := 0
	for b in game.buildings:
		if b.team == _foe and not b.dead and not b.ghost and b.kind == "movement_works" and _seen_b.has(b):
			works_early += 1
	if works_early >= 2 and game.clock <= 150.0:
		rush_saw = "two Light Works very early"
		return "two Light Works already up at %d:%02d" % [int(game.clock) / 60, int(game.clock) % 60]
	for k in foe_early_prod:
		if k == "movement_works":
			continue
		if float(foe_early_prod[k]) <= float(EARLY_PROD[k]):
			rush_saw = "a production building very early"
			return "a %s already up at %d:%02d" % [String((Defs.BUILDINGS if Defs.BUILDINGS.has(k) else Defs.UNITS)[k]["name"]), int(foe_early_prod[k]) / 60, int(foe_early_prod[k]) % 60]
	var n := 0
	var first := INF
	for k in foe_rush_seen:
		if game.clock - float(foe_rush_seen[k]["last"]) > 240.0:
			continue          # (old news: the verdict may be looked at again)
		n += int(foe_rush_seen[k]["count"])
		first = minf(first, float(foe_rush_seen[k]["first"]))
	if n <= 0:
		return ""
	if first <= EARLY_RUSH_BY and (n >= 2 or first <= 150.0):
		rush_saw = "fast rush units early"
		return "%d fast %s seen at %d:%02d" % [n, _rush_names(), int(first) / 60, int(first) % 60]
	return ""


func _rush_names() -> String:
	var names: Array = []
	for k in foe_rush_seen:
		names.append(String(Defs.UNITS[k]["name"]))
	return " and ".join(names)


## How the enemy opened, from what was seen: "rush" (fast units or a big early army), "standard"
## (the base and its army seen, nothing fast), "unknown" (too little seen).
func foe_opening() -> String:
	if rush_evidence() != "":
		return "rush"
	if verdict == "rush":
		return "rush"
	if _hall_seen and (_coverage() >= 0.35 or foe_nonhorse_seen) and game.clock >= 90.0:
		return "standard"
	return "unknown"


## When the enemy's seen rush units could reach our base (game seconds), or INF when none was
## seen lately. From the nearest one to our hall at its own speed (a straight line: the path is
## no shorter).
func rush_eta() -> float:
	var best := INF
	var home := game.center_of_team(ai.team)
	for k in foe_rush_seen:
		var e: Dictionary = foe_rush_seen[k]
		if game.clock - float(e["last"]) > 40.0:
			continue
		var d := home.distance_to(e["pos"] as Vector2)
		best = minf(best, float(e["last"]) + d / maxf(40.0, float(e["speed"])))
	return best


## A rush seen is a rush: defend at once (escalation never waits for REDECIDE).
func _check_rush_units() -> void:
	var ev := rush_evidence()
	if ev == "" or verdict == "rush":
		return
	_apply("rush", ev, rush_saw)


## Remember an armed enemy unit in sight: what it is, and where the guns are.
func _learn(u: Unit) -> void:
	if not u.has_attack() or u.kind == "horse":
		return
	var rng := float(u.d["range"])
	if foe_first_military < 0.0:
		foe_first_military = game.clock
	if not foe_kinds_seen.has(u.kind):
		foe_kinds_seen[u.kind] = true
		var fac := _foe_faction()
		if _is_rush_unit(u):
			# (ai-optimal story audit: only early is a fast unit a sign of a rush; Raptors first seen at 5:25 said "a sign of
			# a Brood rush" in the owner's Frostfang log)
			# (one fast rider after 2:30 is a rider scout, not a rush: rush_evidence wants two then; the coached games told
			# "a sign of a Crown rush" for the Crown's rider scout at 3:30)
			var pack := 0
			for o in game.units_near(u.position, 400.0):
				if o.team == u.team and o.kind == u.kind and not o.dead and game.is_visible_to(ai.team, o.position):
					pack += 1
			if game.clock <= HOME_RUSH_BY or (game.clock <= EARLY_RUSH_BY and pack >= 2):
				_say("saw an enemy %s (fast, a %s rush unit): evidence of a rush" % [String(Defs.UNITS[u.kind]["name"]), fac.capitalize()])
			else:
				_say("saw an enemy %s (fast): raiders to watch for" % String(Defs.UNITS[u.kind]["name"]))
		elif fac == "crown" and not _is_horseman(u) and not foe_nonhorse_seen:
			foe_nonhorse_seen = true
			if game.clock <= EARLY_RUSH_BY:
				_say("saw an enemy %s: a slow foot soldier, the Crown's standard opening (a horse rush would show Horsemen)" % String(Defs.UNITS[u.kind]["name"]))
	if rng > 40.0:
		foe_ranged_seen = true
	foe_max_range = maxf(foe_max_range, rng)
	_danger[u] = [u.position, game.clock]


## Armed enemy units that cover the scout right now (its position is within their weapon
## range plus a margin), seen or the ones that just hit it.
func _threats() -> Array:
	var out: Array = []
	if unit == null or not is_instance_valid(unit) or unit.dead:
		return out
	var cands: Array = game.units_near(unit.position, 520.0)
	if is_instance_valid(unit.last_hitter) and unit.last_hitter is Unit and game.clock - unit.hit_clock < 3.0 and not cands.has(unit.last_hitter):
		cands.append(unit.last_hitter)
	for e in cands:
		if not (e is Unit) or e.dead or e.off_field or e.aboard != null or not game.hostile(e.team, ai.team):
			continue
		if (not e.has_attack() and not _worker_after(e, unit)) or e.kind == "horse" or not e.can_hit(unit):
			continue
		if AIHarass.is_static(e):
			continue             # (a rooted Mound Turtle or Rootmaw does not chase: walked past, never fought; ai_harass.gd)
		if e != unit.last_hitter and not game.is_visible_to(ai.team, e.position):
			continue
		var rng := float(e.d["range"])
		var reach: float = rng + e.radius + unit.radius + (SHOOTER_MARGIN if rng > 40.0 else MELEE_MARGIN)
		if e.position.distance_to(unit.position) <= reach:
			out.append(e)
			_learn(e)
	return out


## (cinder-clockwork-ai, docs/cinder_clockwork_ai.md) A WORKER IS A THREAT TOO when it comes for ours. Unit.has_attack() is
## false for every worker, so the threat lists above never counted one: the owner's Cinder Steps game (0.35.10, 2:36-2:49)
## lost the Clockwork's scout (trip 2) and its sentry peeking up the walled ramp to two Crown Labourers each, the Winders
## trading blows on their hold or move orders (a Winder is no better than a Labourer, and two beat it). A worker scout or
## sentry now flees from an enemy worker that is after it: one that hit it lately, or whose target (or order) is it, within
## WORKER_R. Workers going about their work are not threats (a scout walks past the enemy's workers to see the base).
## The Clockwork only (the Crown's own scouting is another job's); `-- cwscoutflee:off` plays it as before.
const WORKER_R := 200.0
var worker_flee_on := not OS.get_cmdline_user_args().has("cwscoutflee:off")


## Workers after it (no soldier): a stand-off spot by the ramp would be among them; it runs straight away from them, home-
## ward, RUN_FROM px (they give up once it is out of their base).
const RUN_FROM := 320.0


func _run_from_workers(me: Unit, thr: Array) -> Vector2:
	var c := Vector2.ZERO
	for e in thr:
		c += e.position
	c /= maxf(1.0, float(thr.size()))
	var away := (me.position - c).normalized()
	var home := (game.center_of_team(ai.team) - me.position).normalized()
	var dir := (away * 1.0 + home * 0.6).normalized()
	if dir == Vector2.ZERO:
		dir = home
	var cc := _free_near(Vector2i((me.position + dir * RUN_FROM) / Defs.TILE))
	return (Vector2(cc) + Vector2(0.5, 0.5)) * Defs.TILE if cc.x >= 0 else me.position + dir * RUN_FROM


func _worker_after(e: Unit, me: Unit) -> bool:
	if not worker_flee_on or me == null or not me.is_worker() or not e.is_worker() or float(e.d.get("damage", 0.0)) <= 0.0 \
			or _faction() != "clockwork":
		return false
	if e.position.distance_to(me.position) > WORKER_R:
		return false
	if e == me.last_hitter and game.clock - me.hit_clock < 4.0:
		return true
	return e.target == me or e.order_target == me


func _reach_of(e: Unit) -> float:
	var rng := float(e.d["range"])
	return rng + e.radius + unit.radius + (SHOOTER_MARGIN if rng > 40.0 else MELEE_MARGIN)


## Where to stand off: outside every known shooter's reach (the ones in sight and the ones
## seen lately), as close as it can be to the foot of the enemy's ramp while still seeing it
## (a ring at its own sight radius round the ramp), off the enemy's high ground, near us.
## Else straight back from the shooters.
func _standoff_point(thr: Array) -> Vector2:
	var guns: Array = []
	for e in _danger.keys():
		if not is_instance_valid(e) or e.dead or game.clock - float(_danger[e][1]) > DANGER_FOR:
			_danger.erase(e)
			continue
		guns.append([e.position if game.is_visible_to(ai.team, e.position) else _danger[e][0], _reach_of(e)])
	for e in thr:
		if not guns.any(func(g: Array) -> bool: return g[0] == e.position):
			guns.append([e.position, _reach_of(e)])
	var home := game.center_of_team(ai.team)
	if _ramp_pt == Vector2.INF:
		_ramp_pt = _find_ramp(home)
	var best := Vector2.INF
	var bs := INF
	if _ramp_pt != Vector2.INF:
		var ring: float = maxf(2.0, float(unit.d["sight"]) - 1.0) * Defs.TILE
		var st := Vector2(game.starts[_foe])
		var h0 := int(game.height[game.idx(Vector2i(st + Vector2(2.5, 2.0)))])
		for k in 16:
			var c := _free_near(Vector2i((_ramp_pt + Vector2.from_angle(TAU * k / 16.0) * ring) / Defs.TILE))
			if c.x < 0:
				continue
			var p := (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE
			if guns.any(func(g: Array) -> bool: return p.distance_to(g[0]) <= float(g[1]) + 8.0):
				continue
			var score := p.distance_to(home) + (0.0 if int(game.height[game.idx(c)]) != h0 else 4000.0)
			if score < bs:
				bs = score
				best = p
	if best == Vector2.INF:
		var from := Vector2.ZERO
		var need := 0.0
		for g in guns:
			from += g[0]
			need = maxf(need, float(g[1]))
		from /= maxf(1.0, float(guns.size()))
		var away := (unit.position - from).normalized()
		if away == Vector2.ZERO:
			away = (home - unit.position).normalized()
		var c := _free_near(Vector2i((from + away * (need + 40.0)) / Defs.TILE))
		best = (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE if c.x >= 0 else home
	return best


## The ramp cell up to the enemy's main that is nearest to us (pixels), or INF.
func _find_ramp(home: Vector2) -> Vector2:
	var st := Vector2i(Vector2(game.starts[_foe]) + Vector2(2.5, 2.0))
	var best := Vector2.INF
	var bd := INF
	for y in range(st.y - 30, st.y + 31):
		for x in range(st.x - 30, st.x + 31):
			var c := Vector2i(x, y)
			if game.in_map(c) and game.ramp[game.idx(c)] == 1:
				var p := (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE
				if p.distance_to(home) < bd:
					bd = p.distance_to(home)
					best = p
	return best


## Shooters (or any armed soldier) cover the scout: back out of their range, stand off where
## it still sees the ramp, and watch. Driven back again after it has proof of foot soldiers,
## or too often, it goes home. True while this is handling the scout.
func _avoid() -> bool:
	var thr := _threats()
	if not thr.is_empty() and _stands(thr):
		# (one or two it can't run from: it fights them where it stands, then goes on)
		_stuck = 0.0
		if not (unit.order == "attack" and thr.has(unit.order_target)):
			unit.cmd_attack(thr[0])
		return true
	if not thr.is_empty():
		if _mode != "flee":
			if _flees >= MAX_FLEES or (foe_nonhorse_seen and _flees >= 1):
				_finish("driven off")
				return true
			_flees += 1
			_flee_t = -1.0
			_say("scout under guard (%s), backing out of range" % String(Defs.UNITS[thr[0].kind]["name"]))
		_mode = "flee"
		if game.clock - _flee_t >= 1.0:
			_flee_t = game.clock
			_watch_pt = _run_from_workers(unit, thr) if thr.all(func(e: Unit) -> bool: return e.is_worker()) else _standoff_point(thr)
			standoff_log.append(_watch_pt)
			unit.cmd_move(_watch_pt)
		return true
	if _mode == "flee":
		# (hold a little short of the spot, before it arrives: an idle worker is taken for work)
		if unit.position.distance_to(_watch_pt) < 70.0 or unit.order == "idle":
			_mode = "watch"
			_watch_until = game.clock + WATCH_FOR
			unit.cmd_hold()
		return true
	if _mode == "watch":
		if game.clock >= _watch_until:
			_finish("done")
		return true
	return false


func _nearest_start_hall(b: Building) -> Building:
	return b if b.center().distance_to(game.start_mid(_foe)) < 8.0 * Defs.TILE else null


func _coverage() -> float:
	if _plateau.is_empty():
		return 0.0
	return float(_cells_seen.size()) / float(_plateau.size())


## The best army the enemy showed in the last RECENT seconds: [value, supply].
func _recent_army() -> Array:
	var v := 0.0
	var s := 0
	for h in _army_hist:
		if game.clock - float(h[0]) <= RECENT:
			v = maxf(v, float(h[1]))
			s = maxi(s, int(h[2]))
	return [v, s]


## What the sightings say: {"verdict", "reason", "saw", "halls", "econ", "mil", "walls", "defs", "value", "sup"}.
## THE READ (ai-optimal, the owner 2026-11-05: "the absence of army or buildings is already information"): the verdict is
## one of five reads (AIRead.NAME): rush = AGGRESSIVE, greedy = GREEDY, balanced = NORMAL, defensive = DEFENSIVE,
## uncertain = UNKNOWN. "saw" is a short fixed phrase of what the scout saw (AIRead.SAW: the story tells it, translated).
func _evaluate() -> Dictionary:
	var halls := 0
	var econ := 0
	var mil := 0
	var walls := 0
	var defs := 0
	var hall_kind: String = game.faction_hall(_foe)
	var exp_seen := 0
	for b in _seen_b.keys():
		if b.kind == hall_kind:
			halls += 1
			if b != _nearest_start_hall(b):
				exp_seen += 1           # (a hall away from its start: an expansion, whether its main was seen or not)
		elif Defs.is_econ(b.kind):
			econ += 1
		elif MILITARY.has(b.kind):
			mil += 1
		elif b.kind == "wall" or b.kind == "gate":
			walls += 1
		elif AIRead.DEFENCES.has(b.kind):
			defs += 1
	var nq := BroodNew.queen(game, _foe) if not _nb_seen.is_empty() else null
	for nu in _nb_seen.keys():
		if not is_instance_valid(nu) or nu.dead:
			continue
		if nu.kind == BroodNew.QUEEN:
			halls += 1
		elif nu.kind == BroodNew.MAW:
			econ += 1
		elif BroodNew.is_father(nu.kind):
			mil += 1
		elif nu.kind == BroodNew.TURTLE and nq != null and nq.position.distance_to(nu.position) >= float(Defs.NB["expansion_tiles"]) * Defs.TILE:
			halls += 1          # (a Mound Turtle rooted on new ground: the Brood's expansion)
		elif nu.kind != BroodNew.TURTLE and nu.has_attack():
			defs += 1           # (a warrior rooted to hold ground: the Brood's static defence)
	var raw_halls := halls
	halls = maxi(halls, 1 + exp_seen)     # (its main stands whether the scout got in or not)
	var fac: String = game.faction_of(_foe)
	var econ_cap := BROOD_ECON_CAP if fac == "brood" else 0
	for k in Defs.econ_of(fac):
		econ_cap += int(Defs.econ_of(fac)[k])
	var ra := _recent_army()
	var value: float = ra[0]
	var sup: int = ra[1]
	var thr: float = RUSH_VALUE.get(fac, 400.0)
	var clock := game.clock
	var out := {"verdict": "balanced", "reason": "", "saw": "a standard opening", "halls": halls, "econ": econ, "mil": mil, "walls": walls, "defs": defs, "value": value, "sup": sup}
	var cov := _coverage()
	var ev := rush_evidence()
	var known: float = ai.ch.foe_known() if ai.ch != null and fac == "brood" and brood_read_on else 0.0
	var nums := "%d halls, %d economy, %d military buildings, %d supply of army" % [halls, econ, mil, sup]
	if ev != "":
		out["verdict"] = "rush"
		out["reason"] = ev
		out["saw"] = rush_saw
	elif clock < RUSH_READ_BY and ((value >= thr and (clock < 240.0 or _far_army_t >= 0.0 and clock - _far_army_t < 60.0)) or (_far_army_t >= 0.0 and clock - _far_army_t < 60.0 and value >= thr * (0.4 if clock < 240.0 else 1.0))):
		# (an army at home after 4:00 is its defence, not a rush: only an army out of its base counts then, ai-optimal)
		out["verdict"] = "rush"
		out["reason"] = "early army (%d supply) in or out of its base" % sup
		out["saw"] = "a big early army"
	elif mil >= 2 and econ <= econ_cap and halls <= 1 and clock < 240.0 and value > 0.0:
		out["verdict"] = "rush"
		out["reason"] = "%d production buildings, %d economy buildings, %d supply of army" % [mil, econ, sup]
		out["saw"] = "production buildings and a thin economy"
	elif mil >= 1 and halls <= 1 and econ < econ_cap - 1 and clock < 180.0 and _hall_seen and value >= thr * 0.5:
		out["verdict"] = "rush"
		out["reason"] = "a production building, a thin economy and %d supply of army" % sup
		out["saw"] = "production buildings and a thin economy"
	elif defs >= DEF_TURRETS or (defs >= 1 and halls <= 1 and clock < 300.0) or (walls >= (DEF_WALLS_CROWN if fac == "crown" else DEF_WALLS) and halls <= 1 and value < thr * 0.5):
		# (DEFENSIVE: static defence early, or one base walled all round with little army out: it turtles)
		out["verdict"] = "defensive"
		out["reason"] = "%d static defences, %d wall pieces, %s" % [defs, walls, nums]
		out["saw"] = "turrets or rooted defenders" if defs > 0 else "walls all round one base"
	elif halls >= 2 and value < thr * 0.5 and mil <= 1 and not (fac == "brood" and brood_read_on and (known >= thr * 0.5 or not _brood_seen_enough())):
		# (the Brood: the Mother and a far turtle alone are no greed: its Rootmaws, grubs and army may be anywhere, the
		# owner's Red Coast log; THE BROOD READ below)
		out["verdict"] = "greedy"
		out["reason"] = _brood_reason(halls, econ, mil, sup) if fac == "brood" and brood_read_on else nums
		out["saw"] = "a second base and little army"
	elif absence_on and _hall_seen and mil == 0 and value <= 0.0 and known <= 0.0 and clock >= GREEDY_ABSENT_FROM \
			and cov >= (BROOD_LOOK_COV if fac == "brood" else ABSENT_COV) and not (fac == "brood" and brood_read_on and not _brood_seen_enough()):
		# (THE ABSENCE IS INFORMATION, the owner 2026-11-05: its base looked at and no army and no production building, at a
		# time a rush or a normal opening would have one: it is putting everything into its economy)
		out["verdict"] = "greedy"
		out["reason"] = "its base seen (%d%%) at %d:%02d: no army, no production building; %d economy buildings, %d workers, %d wall pieces" % [
			int(cov * 100.0), int(clock) / 60, int(clock) % 60, econ, _workers_seen, walls]
		out["saw"] = "no army and no production at its base"
	elif fac == "brood" and brood_read_on and not _brood_seen_enough():
		# (THE BROOD READ: what the scout saw is too little to call it greedy: see _brood_seen_enough)
		out["reason"] = _brood_reason(halls, econ, mil, sup)
		if not _hall_seen and cov < 0.35:
			out["verdict"] = "uncertain"
			out["saw"] = "too little of its base"
	elif clock >= 210.0 and econ >= econ_cap and mil == 0 and value <= 0.0 and cov >= 0.55 and _workers_seen >= 10 and not (fac == "brood" and brood_read_on):
		out["verdict"] = "greedy"
		out["reason"] = "a full economy (%d buildings, %d workers), no military building, no army" % [econ, _workers_seen]
		out["saw"] = "a full economy and no military building"
	elif not _hall_seen and cov < 0.35 and raw_halls == 0:
		out["verdict"] = "uncertain"
		out["reason"] = "it saw too little of the base"
		out["saw"] = "too little of its base"
	else:
		out["reason"] = _brood_reason(halls, econ, mil, sup) if fac == "brood" and brood_read_on else nums
	return out


## (ai-optimal) The read's thresholds. DEFENSIVE: this many static defences seen (turrets, rooted defenders), or one
## seen on a single base before 5:00, or this many wall pieces round a single base with little army. GREEDY by absence:
## its base looked at (this share of its main, the Brood's BROOD_LOOK_COV) and nothing military from this time on (a rush
## has its production by then: the Crown's Barracks at ~0:55, the Clockwork's Light Works at ~0:40, the Brood's Sire at ~0:20).
const DEF_TURRETS := 2
const DEF_WALLS := 8
const DEF_WALLS_CROWN := 24
## (ai-optimal) An army seen is a RUSH read only before 5:00 (was 6:40): later an army on the move is the mid game (the
## home defence answers it); the coached game Crown OPTIMAL v Clockwork Economy read 6 Clock Soldiers out at 5:34 as a
## rush and its Timing attack put its Barracks and Mill "first" again and was called off.
const RUSH_READ_BY := 300.0     # (every Crown walls its ramp and each new hall: 8-12 pieces is its normal game)
const ABSENT_COV := 0.4
const GREEDY_ABSENT_FROM := 55.0
## (study switch: `-- absence:off` reads as 0.31: an empty base is no read, the scout looks again)
var absence_on := not OS.get_cmdline_user_args().has("absence:off")
## The fixed phrase of the rush evidence last found (rush_evidence sets it).
var rush_saw := "fast rush units early"


## THE BROOD READ (the owner's log 2026-11-03, v0.27.0 Red Coast 5:05: "scouted: greedy economy (2 halls, 0 economy
## buildings, 0 military buildings, 0 supply of army)" from a look that saw the Mother and one far Mound Turtle, while the
## Brood had 4 rooted Rootmaws, a Tyrant Sire and 15 Raptors; the Crown switched to a timing attack and was hit at 6:06).
## The Brood has no buildings: its economy is its Rootmaws and grubs, its army its loose creatures (often out of its base),
## its tech its Sires. A "greedy" call needs a look at that economy: BROOD_LOOK_MAWS rooted Rootmaws or BROOD_LOOK_GRUBS
## grubs seen, and the army looked for: its Mother's ground seen (BROOD_LOOK_COV) or an army of the Brood seen in the last
## 120 s (AICrownHold.foe_known, which also counts the army met outside its base).
const BROOD_LOOK_MAWS := 2
const BROOD_LOOK_GRUBS := 8
const BROOD_LOOK_COV := 0.45
var brood_read_on := not OS.get_cmdline_user_args().has("broodread:off")      # (study switch: `-- broodread:off` plays as 0.27.0)


func _brood_maws() -> int:
	var n := 0
	for nu in _nb_seen.keys():
		if is_instance_valid(nu) and not nu.dead and nu.kind == BroodNew.MAW:
			n += 1
	return n


func _brood_seen_enough() -> bool:
	if _brood_maws() < BROOD_LOOK_MAWS and _workers_seen < BROOD_LOOK_GRUBS:
		return false
	if _coverage() >= BROOD_LOOK_COV:
		return true
	return ai.ch != null and ai.ch.army_known_lately()


## The Brood as the scout saw it: its Mother and expansions (far turtles), its economy (Rootmaws, grubs), Sires, army.
func _brood_reason(halls: int, econ: int, mil: int, sup: int) -> String:
	var known: float = ai.ch.foe_known() if ai.ch != null else 0.0
	return "the Mother%s, %d Rootmaw%s and %d grubs seen, %d Sire%s, %d supply of army seen near its base%s" % [
		"" if halls <= 1 else " and %d turtle%s on new ground" % [halls - 1, "" if halls == 2 else "s"],
		econ, "" if econ == 1 else "s", _workers_seen, mil, "" if mil == 1 else "s", sup,
		", %d of army known" % int(known) if known > 0.0 else ""]


# ------------------------------------------------------------------ deciding

## Later sightings can change the decision, but never twice within REDECIDE seconds.
func _redecide() -> void:
	if verdict == "pending" or game.clock - decided_at < REDECIDE:
		return
	if state == "going":
		return
	if verdict == "rush" and game.clock < defend_until:
		return        # (a defence is held for its time; a smaller sighting is no reason to drop it)
	var r := _evaluate()
	if r["verdict"] != verdict and not (r["verdict"] == "balanced" and verdict == "uncertain" and _coverage() < 0.35 and not _hall_seen):
		_apply(r["verdict"], r["reason"], String(r.get("saw", "")))


func _apply(v: String, why: String, seen := "") -> void:
	var was := verdict
	if seen == "":
		seen = AIRead.default_saw(v)
	if v == was:
		reason = why
		saw = seen
		return
	verdict = v
	reason = why
	saw = seen
	decided_at = game.clock
	reads.append([game.clock, v, seen])
	var fac := _faction()
	# undo what the last decision changed
	mod = {}
	want_wall = false
	if was == "greedy" and ai.strategy == "timing" and ai._opened != "timing" and not ai._attacking and not ai.adaptive():
		ai.strategy = ai._opened
		ai._attack_at = maxi(int(ai._s("wave")), ai._army_supply(game.army(ai.team)) + 2) if ai._attack_at >= 999 else ai._attack_at
	# THE READ (ai-optimal): what it saw -> what it makes of it -> what it does. A fixed plan keeps its identity (the owner:
	# "if I chose an AI to go economic ... it would default to trying to outpace in an economic race"): survival always (a
	# rush is defended), the obvious answers, and otherwise its own plan. OPTIMAL (ai.adaptive()) picks its build itself
	# from the read (scripts/ai_optimal.gd), after this.
	var head := "scouted: %s [%s] (%s)" % [AIRead.word(v), seen, why]
	var pname: String = ai.opt.plan_name(ai.strategy) if ai.adaptive() else String(AI.STRATEGIES.get(ai.strategy, AI.STRATEGIES["balanced"])["name"])
	match v:
		"balanced":
			if ai.strategy != ai._opened and ai._opened != "timing" and not ai.adaptive():
				ai.strategy = ai._opened
				pname = String(AI.STRATEGIES.get(ai.strategy, AI.STRATEGIES["balanced"])["name"])
			_say("%s: %s" % [head, "OPTIMAL picks its build from this" if ai.adaptive() else "keeps to its %s plan" % pname])
		"rush":
			mod = DEFEND_MOD.duplicate()
			want_wall = true
			defend_until = game.clock + DEFEND_FOR
			var ra := _recent_army()
			# hold at home until the army is a match for what was seen, then counter
			ai._attack_at = maxi(maxi(ai._attack_at, 16), int(ceil(float(ra[1]) * 1.4)) + 6)
			ai._regroup_until = maxf(ai._regroup_until, game.clock + float(ai._lv([200.0, 160.0, 130.0])))
			_say("%s: %s is coming; switching to a defensive build: defends first, army and %s, then a counter-attack" % [head, "a rush" if game.clock <= EARLY_RUSH_BY else "an attack", "walls" if fac == "crown" else "production"])
		"greedy":
			var strong := seen != "no army and no production at its base"
			if ai.adaptive():
				_say("%s: OPTIMAL picks its build from this" % head)
			elif ai.strategy == "timing" or (ai.strategy == "balanced" and strong):
				# (Balanced and Timing punish a real greed, an expansion or a full economy with no army: the timing attack)
				var plan := _timing_plan(_evaluate())
				timing_target = plan["target"]
				mod = {"timing": plan["at"], "expand": 1.0 if fac == "brood" else 1.2, "halls": 3, "tech": 0.6 if fac == "clockwork" else 0.75, "workers": 1.0}
				if not ai._attacking:
					ai.strategy = "timing"
					ai._attack_at = 999
				_say("%s: it is all economy; switches to a timing attack at %d:%02d (%d supply)" % [head, int(plan["at"]) / 60, int(plan["at"]) % 60, timing_target])
			elif ai.strategy == "economy":
				mod = {"expand": RACE_EXPAND, "halls": 4}
				_say("%s: it is all economy; races it: more bases sooner" % head)
			else:
				_say("%s: it is all economy; keeps to its %s plan" % [head, pname])
		"defensive":
			if ai.adaptive():
				_say("%s: OPTIMAL picks its build from this" % head)
			elif ai.strategy in ["economy", "balanced"]:
				mod = {"expand": RACE_EXPAND if ai.strategy == "economy" else 0.7, "tech": 0.85}
				_say("%s: it turtles; out-expands it and techs up" % head)
			else:
				_say("%s: it turtles; keeps to its %s plan" % [head, pname])
		"uncertain":
			# (UNKNOWN is no reason for an army: the owner's "could not see the enemy: playing safe" -> an army for nothing)
			_say("could not see the enemy [%s] (%s): that proves nothing; no army for it, keeps to %s and looks again soon" % [seen, why, pname if ai.adaptive() else "its %s plan" % pname])
	ai.on_read(v, seen)


## (ai-optimal) The Economy plan's answer to a greedy or a turtling enemy: the race, its next halls sooner (x the time).
const RACE_EXPAND := 0.3
var saw := ""                   # the read's fixed phrase (AIRead.SAW)
var reads: Array = []           # [clock, verdict, saw] of every read (tests and the coach read it)
var trip_log: Array = []        # [clock, how it ended, % of its main seen, hall seen, read] of every trip
var debug_trips := OS.get_cmdline_user_args().has("scoutlog:on")


## When a timing attack goes and how big it is: the more economy and the less army was seen
## the earlier it hits (before the economy pays off), and the force is 1.6 times what was
## seen (army and walls) plus a margin: never into a clearly stronger defence.
func _timing_plan(r: Dictionary) -> Dictionary:
	var fac := _faction()
	var base: float = TIMING_AT.get(fac, 360.0)
	var greed: float = clampf(0.35 * (int(r["halls"]) - 1) + 0.1 * maxf(0.0, float(int(r["econ"]) - 3)) + (0.3 if float(r["value"]) < 40.0 else 0.0), 0.0, 1.0)
	var at: float = maxf(base * (1.0 - 0.35 * greed), game.clock + 30.0)
	var seen: float = float(r["sup"]) + float(int(r["walls"])) / 6.0 * 1.5
	var target: int = int(ceil(seen * 1.6)) + 4
	target = clampi(target, int(TIMING_MIN_SUP.get(fac, 12)), 60)
	return {"at": at, "target": target, "greed": greed}


## The supply a timing attack goes out with (AI._army): what the scout worked out; it comes
## down a little the longer the timing has passed, so it does go.
func timing_wave() -> int:
	if verdict != "greedy" and ai.tr.on and _faction() == "crown":
		# (AI TRANSITIONS: a Crown timing plan the scout did not size goes out with a real force, never 6 supply (3 Musketeers
		# at a walled ramp: 0.25.25 Ashfall, out at 4:30 and back at 4:38; the owner's game, 11 supply at 6:28, turned round at
		# the gate). After a scouted rush, AITransition picks the moment)
		return maxi(int(TIMING_MIN_SUP["crown"]) + 2, int(ceil(float(_recent_army()[1]) * 1.6)) + 4)
	if timing_target <= 0 or verdict != "greedy":
		return 6
	var late: float = maxf(0.0, game.clock - float(mod.get("timing", 0.0)) - 90.0)
	var f: float = clampf(1.0 - late / 300.0, 0.6, 1.0)
	return maxi(int(TIMING_MIN_SUP.get(_faction(), 12)) - 2, int(round(timing_target * f)))


## A scouted timing attack holds if our army is not worth enough against what the enemy
## showed lately (a clearly stronger defence is not attacked into).
func timing_ok(value: float) -> bool:
	if verdict != "greedy":
		return true
	var ra := _recent_army()
	return value >= float(ra[0]) * 1.2


# ------------------------------------------------------------------ acting on it

## A defensive or a safe game builds production earlier and walls the ramp (Crown only: the
## other factions have no walls).
func _defence() -> void:
	if verdict != "rush" and (verdict != "uncertain" or absence_on):
		return          # (ai-optimal: an enemy not seen is no reason for an army: only a rush is)
	if ai.bo_owns():
		return          # (the Crown's build order owns the gold in its opening: scripts/ai_crown.gd)
	if verdict == "uncertain" and ai.eco_calm():
		return          # (clockwork-eco: the Clockwork's Economy and Balanced: an enemy not seen is no reason for two Works)
	if ai._hall_reserve or ai._saving:
		return
	# (the wall first, it is cheap and must stand before the enemy is here)
	if want_wall and not ai._walled and _faction() == "crown" and ai._wall_wanted():
		ai._wall_off()
		if not ai._walled:
			return          # (saving for it)
	var plan := {}
	match _faction():
		"crown":
			plan = {"barracks": 1 if game.clock < 200.0 else (2 if ai.difficulty < 2 else 3)}
			if verdict == "uncertain" and ai._econ_wait():
				plan["barracks"] = 1        # (CROWN ECONOMY FIRST: an enemy not seen is no reason for three Barracks while the farms want hands; 0.27.0 Red Coast built its 2nd at 4:17, 3rd at 6:09)
		"clockwork":
			plan = {ai._works(): 2}
	for k in plan:
		if ai._mine(k).size() < int(plan[k]) and not ai._busy_building(k) and game.requirement_met(ai.team, k) \
				and ai._gold() >= int(Defs.BUILDINGS[k]["cost"]) and (ai._mine(k).size() > 0 or ai._gold() >= int(Defs.BUILDINGS[k]["cost"]) + 30):
			ai._construct(k)
			return


# ------------------------------------------------------------------ the sentry at a walled ramp

const SENTRY_FROM := 100.0      # (game seconds) the earliest a sentry is posted
const SENTRY_WALLS := 2         # wall pieces seen by the ramp that make it "walled"
const SENTRY_MAX_POSTS := 4
const SENTRY_RETRY := 60.0      # a lost sentry is replaced after this long
const SENTRY_MIN_WORKERS := 7
const SENTRY_MARGIN := 10.0     # (pixels) outside a gun's range: it sees a gun only inside its own sight, so no more


## A scout that is not enabled (a rush plan) still posts a sentry once the plan has fallen back
## to a normal game.
func _sentry_alone() -> void:
	if ai.difficulty < 1 or ai.peaceful or ai.strategy in ["rush", "air", "xrush"] or game.clock < SENTRY_FROM:
		return
	var foe := ai._foe()
	if foe < 0:
		return
	_foe = foe
	_observe()
	_sentry_tick()


## The enemy's ramp is walled: wall or gate pieces seen near it, or a scout shut out of a Crown base
## (walls stand on the high ground and are rarely seen from below). Only the Crown builds walls.
func foe_ramp_walled() -> bool:
	if _foe < 0:
		return false
	if _ramp_pt == Vector2.INF:
		_ramp_pt = _find_ramp(game.center_of_team(ai.team))
	if _ramp_pt == Vector2.INF:
		return false
	var n := 0
	for b in _seen_b.keys():
		if is_instance_valid(b) and not b.dead and (b.kind in ["gate", "palisade", "wall", "stone_wall"] or b.d.get("wall", false)) \
				and b.center().distance_to(_ramp_pt) < 12.0 * Defs.TILE:
			n += 1
	return n >= SENTRY_WALLS or (denied_trips >= 1 and _foe_faction() == "crown")


## Once the foe has walled its ramp the scout is shut out and the computer goes blind. One worker
## (a grub, a labourer) then stands at the foot of the ramp, just inside its own sight of it and
## outside every gun it knows of, and keeps watching: the wall, the Musketeers behind it. It backs
## away from any armed unit that reaches it and comes back when they are gone. Cheap: one worker,
## one post at a time; a lost one is replaced up to SENTRY_MAX_POSTS times.
func _sentry_tick() -> void:
	if sentry != null and (not is_instance_valid(sentry) or sentry.dead):
		sentry = null
		_sentry_pt = Vector2.INF
		_sentry_next = game.clock + SENTRY_RETRY
		sentry_losses += 1        # (the next one stands further back)
		_sentry_log("lost")
	if sentry == null:
		if game.clock < maxf(SENTRY_FROM, _sentry_next) or sentry_posts >= SENTRY_MAX_POSTS or state == "going" or _busy_with_foe():
			return
		if not foe_ramp_walled() or game.workers(ai.team).size() < SENTRY_MIN_WORKERS:
			return
		var u := _pick()
		if u == null:
			_sentry_next = game.clock + 10.0
			return
		sentry = u
		sentry_posts += 1
		_sentry_fleeing = false
		_sentry_pt = _sentry_spot(sentry, [])
		sentry.cmd_move(_sentry_pt)
		_peek_t = game.clock + 20.0         # (clockwork-ai-v2: its first peek once it has stood at its post a while)
		_peek_on = false
		_say("posts a %s at the foot of the walled ramp to keep watch" % String(Defs.UNITS[u.kind]["name"]))
		_sentry_log("posted")
		return
	if sentry.order == "gather" or sentry.order == "build":
		sentry = null            # (another part of the computer used it)
		_sentry_next = game.clock + 10.0
		return
	if _busy_with_foe():
		sentry = null            # (the enemy is at home: back to work)
		_sentry_next = game.clock + 30.0
		return
	if _sentry_peek():
		return
	var thr := _sentry_threats()
	if not thr.is_empty():
		if not _sentry_fleeing:
			_sentry_fleeing = true
			sentry_flees += 1
			_say("the sentry backs away from a %s" % String(Defs.UNITS[thr[0].kind]["name"]))
			_sentry_log("fled")
		_sentry_pt = _run_from_workers(sentry, thr) if thr.all(func(e: Unit) -> bool: return e.is_worker()) else _sentry_spot(sentry, thr)
		sentry.cmd_move(_sentry_pt)
		return
	if _sentry_fleeing:
		_sentry_fleeing = false
		_sentry_pt = _sentry_spot(sentry, [])
		sentry.cmd_move(_sentry_pt)
		return
	# (hold the post; an idle worker would be taken for work)
	if sentry.position.distance_to(_sentry_pt) > 90.0:
		if sentry.order == "idle":
			sentry.cmd_move(_sentry_pt)
	elif sentry.order != "hold" and (sentry.order == "idle" or sentry.position.distance_to(_sentry_pt) < 50.0):
		sentry.cmd_hold()


## (clockwork-ai-v2, the qa study: the Clockwork's sentry saw the guard behind the wall in 1 of 29 ten-second windows) THE
## PEEK. Its post is outside every gun it knows of with a margin, and a Winder's sight (7 tiles, 224 px) is just about a
## Musketeer's reach with that margin (222 px): from there it sees nothing, and from the low ground the high ground behind
## the wall is hidden anyway. So the Clockwork's sentry (accepting some risk) walks in up the ramp every SENTRY_PEEK s; the
## moment it sees an armed enemy (or after SENTRY_PEEK_T s, or hurt) it backs off to its post. Its sight is a little longer
## than a Musketeer's real reach (190 px + the two radii: 222 against 224), so a careful peek mostly sees before it is shot.
const SENTRY_PEEK := 22.0
const SENTRY_PEEK_T := 7.0
const SENTRY_PEEK_IN := 4.0     # tiles from the ramp's foot toward the enemy's main: where it walks to
var sentry_peeks := 0
var sentry_peek_seen := 0
var _peek_t := -99.0            # when the last peek began
var _peek_on := false
var _peek_hp := 0.0


func _sentry_peek() -> bool:
	if not ai._clock() or _ramp_pt == Vector2.INF or OS.get_cmdline_user_args().has("cwpeek:off"):
		return false
	if _peek_on:
		var seen := _sentry_sees_armed()
		var hit := sentry.hp < _peek_hp - 0.1 or sentry.hp < sentry.max_hp * 0.5
		# (cinder-clockwork-ai: an enemy worker coming for it ends the peek too, before it lands a blow)
		if not hit and _sentry_threats().any(func(e: Unit) -> bool: return e.is_worker()):
			hit = true
		if seen or game.clock - _peek_t > SENTRY_PEEK_T or hit:
			_peek_on = false
			if hit:
				_peek_t = game.clock + SENTRY_PEEK      # (shot at: the next peek waits twice as long)
			if seen:
				sentry_peek_seen += 1
				_sentry_log("peek: saw")
			_sentry_pt = _sentry_spot(sentry, _sentry_threats())
			sentry.cmd_move(_sentry_pt)
			return true
		return true
	if _sentry_fleeing or game.clock - _peek_t < SENTRY_PEEK or sentry.hp < sentry.max_hp * 0.5 \
			or sentry.position.distance_to(_sentry_pt) > 60.0 or sentry.order == "move" or not _sentry_threats().is_empty():
		return false
	_peek_on = true
	_peek_t = game.clock
	_peek_hp = sentry.hp
	sentry_peeks += 1
	var st := (Vector2(game.starts[_foe]) + Vector2(2.5, 2.0)) * Defs.TILE
	var c := _free_near(Vector2i((_ramp_pt + (st - _ramp_pt).normalized() * SENTRY_PEEK_IN * Defs.TILE) / Defs.TILE))
	sentry.cmd_move((Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE if c.x >= 0 else _ramp_pt)
	if sentry_peeks == 1:
		_say("the sentry peeks up the walled ramp now and then (it backs off at once when it sees the guard)")
	_sentry_log("peek")
	return true


## An armed enemy soldier the side sees within the sentry's sight.
func _sentry_sees_armed() -> bool:
	var r := float(sentry.d["sight"]) * Defs.TILE
	for e in game.units_near(sentry.position, r):
		if e is Unit and not e.dead and not e.off_field and game.hostile(e.team, ai.team) and e.has_attack() and not e.is_worker() \
				and game.is_visible_to(ai.team, e.position):
			return true
	return false


func _sentry_log(what: String) -> void:
	sentry_log.append([game.clock, what])


## Armed enemy units that can reach the sentry soon (weapon range plus a margin).
func _sentry_threats() -> Array:
	var out: Array = []
	for e in game.units_near(sentry.position, 520.0):
		if not (e is Unit) or e.dead or e.off_field or e.aboard != null or not game.hostile(e.team, ai.team):
			continue
		if (not e.has_attack() and not _worker_after(e, sentry)) or e.kind == "horse" or not e.can_hit(sentry) or not game.is_visible_to(ai.team, e.position):
			continue
		var rng := float(e.d["range"])
		if e.position.distance_to(sentry.position) <= rng + e.radius + sentry.radius + (SENTRY_MARGIN if rng > 40.0 else MELEE_MARGIN):
			out.append(e)
			_learn(e)
	return out


## The watch post: on a ring at the sentry's sight round the foot of the ramp, outside every known
## gun's reach, off the enemy's high ground, the nearest to home. If every spot is covered, the one
## farthest from the guns.
func _sentry_spot(u: Unit, thr: Array) -> Vector2:
	var home := game.center_of_team(ai.team)
	if _ramp_pt == Vector2.INF:
		_ramp_pt = _find_ramp(home)
	if _ramp_pt == Vector2.INF:
		return u.position
	var guns: Array = []
	for e in _danger.keys():
		if not is_instance_valid(e) or e.dead or game.clock - float(_danger[e][1]) > DANGER_FOR:
			_danger.erase(e)
			continue
		var rng := float(e.d["range"])
		guns.append([_danger[e][0], rng + e.radius + u.radius + (SENTRY_MARGIN if rng > 40.0 else MELEE_MARGIN)])
	for e in thr:
		var rng := float(e.d["range"])
		guns.append([e.position, rng + e.radius + u.radius + (SENTRY_MARGIN if rng > 40.0 else MELEE_MARGIN)])
	var st := Vector2(game.starts[_foe])
	var h0 := int(game.height[game.idx(Vector2i(st + Vector2(2.5, 2.0)))])
	var ring: float = maxf(2.0, float(u.d["sight"]) - 2.0) * Defs.TILE + 45.0 * sentry_losses
	var best := Vector2.INF
	var bs := INF
	var safest := Vector2.INF
	var safe_d := -INF
	for k in 16:
		var c := _free_near(Vector2i((_ramp_pt + Vector2.from_angle(TAU * k / 16.0) * ring) / Defs.TILE))
		if c.x < 0:
			continue
		var p := (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE
		if int(game.height[game.idx(c)]) == h0:
			continue
		var slack := INF
		for g in guns:
			slack = minf(slack, p.distance_to(g[0]) - float(g[1]))
		if slack > safe_d:
			safe_d = slack
			safest = p
		if slack <= 8.0:
			continue
		var score := p.distance_to(home)
		if score < bs:
			bs = score
			best = p
	if best == Vector2.INF:
		best = safest if safest != Vector2.INF else home
	return best
