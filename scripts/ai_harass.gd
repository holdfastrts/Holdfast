class_name AIHarass
extends RefCounted
## THE COMPUTER'S HARASS (owner, 2026-10-31, Hard Clockwork v Hard Brood on Highmoor, 0.24.21: "clockwork ai sent 1 clock
## soldier to harass and stopped to attack a turtle, instead of stopping he should have pushed and scouted and tried to
## harass the worker line of brood, forcing brood to uproot the tyrant to deal with it"). docs/ai_harass.md.
##
## A small party out in the enemy's land (a Clock Soldier that chased a scout out of our base, the Crown's raiding
## Horsemen, a soldier scout) is steered here, never left on a bare attack-move (which hits the nearest thing):
##  - it does NOT lock onto STRUCTURES: buildings, walls, turrets and ROOTED Brood creatures (Mound Turtles, Rootmaws, a
##    rooted Sire or Mother, eggs): it walks past them (a plain move) unless they block its only way (stuck: then it
##    breaks through) or nothing else is in reach;
##  - its prey is the WORKERS (grubs, Labourers, Winders) and units that can't fight back, those away from defenders
##    first (no rooted creature attacks: a grub loading at its Rootmaw stands still for it); with none in sight it keeps walking to the worker line (the enemy's workers or economy, else its base);
##  - a REAL DEFENDER (a Sire or the Mother on her feet, or armed units worth more than the party) makes it pull back
##    for a few seconds, then it comes back; a weaker armed unit that reaches it is fought;
##  - hurt, run down (a construct out of wind) or out too long, it goes home and is let go.
## Orders are refreshed every think (about once a second). A big army push keeps its own targeting (AI._army).

const LONE_FAST := 95.0         # a soldier slower than this (a Musketeer) found out alone comes home, not harass
const MAX_UNITS := 3            # the most units harassing at once (strays adopted by adopt_strays)
const STRAY_FROM := 900.0       # (pixels from our nearest building) an army unit out alone this far is a stray
const PREY_R := 12.0            # (tiles) how far a harasser looks for workers
const DANGER_R := 330.0         # (pixels) armed enemies this close to the party count as its danger
const BACK_FOR := 6.0           # (s) a pull-back lasts this long, then it comes back
const MAX_BACKS := 3            # pulled back this often: it goes home
const HOME_HP := 0.35           # below this share of its hit points it goes home
const MAX_TIME := 150.0         # (s) out this long: home
const STUCK_FOR := 3.0          # (s) a plain walk that gets nowhere this long: it breaks through what is in the way
## RAID MICRO (owner, 2026-11-03, docs/raid_micro.md: "with 3 Horsemen stay there and kill more workers... not fight the
## Tyrant Sire and try to focus on the workers"): a defender much slower than the party (a Tyrant Sire, the Mother or a
## Rootmaw on foot against Horsemen) is KITED, not fled: the party steps away from its bite and rides on to grubs it
## can't reach in time. Only a threat that can catch it (fast units in number, shooters) or low health sends it home.
const SLOW_SHARE := 0.74        # a melee defender at most this share of the party's slowest speed is slow (kited)
const SHOOTER_R := 100.0        # (px) a defender with this reach or more is a shooter: never kited
const KITE_GAP := 80.0          # (px) kept between a rider and a slow defender's bite
const SWARM_X := 2.0            # catchers (fast enough to catch it) at least twice the party's number weigh double
## Behind in economy (the enemy's workers it has seen far outnumber ours): the raid must do damage, it stays longer.
const PRESS_HP := 0.25
const PRESS_BACKS := 5
const PRESS_TIME := 240.0

var ai: AI
var game: Game
var units := {}                 # Unit -> {"t0", "back_until", "backs", "goal", "home" (walking home), "last_pos", "still"}
var done := {}                  # Unit -> clock until which it is not adopted again
var log_lines: Array = []       # [clock, text] (tests read it)
var _last_t := -1.0
var _dt := 1.0                  # (s) since the last tick


func _init(a: AI) -> void:
	ai = a
	game = a.game


func _say(u: Unit, msg: String) -> void:
	log_lines.append([game.clock, msg])
	if game.mlog:
		game.mlog.add("%s's %s %s" % [game.mlog.who(ai.team), String(Defs.UNITS[u.kind]["name"]), msg])


# ------------------------------------------------------------------ what is what

## A thing that stands still for the fight: a building (walls, turrets) or a rooted Brood creature (Mound Turtle,
## Rootmaw, a rooted Sire or Mother, a cocoon), an egg or a food pile.
static func is_static(e) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	if e is Building:
		return true
	if not (e is Unit):
		return false
	var u := e as Unit
	if u.kind == BroodNew.EGG or u.kind == BroodNew.PILE:
		return true
	return bool(u.d.get("new_brood", false)) and u.tesla_mode != "packed"


## Prey: a worker, or a unit on its feet that can't fight back (not a loose horse, not a structure).
static func is_prey(e) -> bool:
	if not (e is Unit) or e.dead or e.off_field or e.aboard != null or is_static(e):
		return false
	return e.is_worker() or (not Game.fights_back(e) and e.kind != "horse")


## A real defender: an armed enemy on its feet (a worker or a rooted creature is not).
static func is_defender(e) -> bool:
	return Game.fights_back(e) and not e.off_field and not is_static(e)


## A defender the party never stands against: a Sire (a father) or the Brood Mother on her feet.
static func is_big(e) -> bool:
	return is_defender(e) and (bool(e.d.get("father", false)) or e.kind == BroodNew.QUEEN)


## The party's slowest speed (what a defender must match to catch it).
static func party_speed(party: Array) -> float:
	var sp := INF
	for u in party:
		if is_instance_valid(u) and not u.dead:
			sp = minf(sp, u.speed)
	return 0.0 if sp == INF else sp


## A defender the party outruns: melee, at most SLOW_SHARE of its speed (a Tyrant Sire, the Mother, a Rootmaw on foot
## against Horsemen; never against a Clock Soldier or a Musketeer).
static func is_slow(o: Unit, party: Array) -> bool:
	return float(o.d.get("range", 0)) < SHOOTER_R and o.speed <= party_speed(party) * SLOW_SHARE


# ------------------------------------------------------------------ the measures

## The party's strength (the computer's own measure: value, less when hurt).
func strength(party: Array) -> float:
	var v := 0.0
	for u in party:
		v += ai._unit_value(u)
	return v


## The armed enemies on their feet near `c` it can see (or that just hit one of the party).
func defenders_near(c: Vector2, party: Array) -> Array:
	var out: Array = []
	for o in game.units_near(c, DANGER_R):
		if not game.hostile(o.team, ai.team) or not is_defender(o) or not game.is_visible_to(ai.team, o.position):
			continue
		if party.any(func(u: Unit) -> bool: return o.can_hit(u)):
			out.append(o)
	for u in party:
		var h = u.last_hitter
		if is_instance_valid(h) and h is Unit and not h.dead and game.clock - u.hit_clock < 2.0 and is_defender(h) and not out.has(h):
			out.append(h)
	return out


## Too strong to stand against: a Sire or the Mother on her feet, or armed units worth more than the party. Slow
## defenders the party outruns are left out (kited: kite_from); catchers in number weigh double (SWARM_X).
func outmatched(party: Array, foes: Array) -> bool:
	var real := foes.filter(func(o: Unit) -> bool: return not is_slow(o, party))
	if real.is_empty():
		return false
	var theirs := 0.0
	var sp := party_speed(party)
	var catchers := 0
	for o in real:
		if is_big(o):
			return true
		theirs += ai._unit_value(o)
		if o.speed >= sp * 0.8:
			catchers += 1
	if catchers >= party.size() * SWARM_X:
		theirs *= 2.0
	return theirs > strength(party) * 1.05


## The slow defenders among `foes` (kited).
func slow_of(party: Array, foes: Array) -> Array:
	return foes.filter(func(o: Unit) -> bool: return is_slow(o, party))


## Behind in economy: the enemy's workers it has seen (its scout's count, or in sight now) are well over ours. The raid
## then has to do damage: it stays longer and goes home later (PRESS_*).
func pressing() -> bool:
	var foe: int = ai._foe()
	if foe < 0:
		return false
	var seen := 0
	for o in game.units:
		if o.team == foe and not o.dead and o.is_worker() and game.is_visible_to(ai.team, o.position):
			seen += 1
	if ai.scout != null:
		seen = maxi(seen, ai.scout._workers_seen)
	var mine := 0
	for o in game.units:
		if o.team == ai.team and not o.dead and o.is_worker():
			mine += 1
	return seen >= mine * 1.3 + 3


## A step away from the nearest slow defender about to bite `u` (a plain move: the pistol is kept for a grub), on open
## ground, leaning toward `toward` (prey or the worker line) when that is not into its jaws. False: none close.
func kite_from(u: Unit, slows: Array, toward: Vector2) -> bool:
	var s: Unit = null
	var sd := INF
	for o in slows:
		var gap: float = o.position.distance_to(u.position) - (float(o.d["range"]) + o.radius + u.radius)
		if gap < sd:
			sd = gap
			s = o
	if s == null or sd > KITE_GAP:
		return false
	var away := (u.position - s.position).normalized()
	var best := Vector2.INF
	var bs := -INF
	for i in 12:
		var d := Vector2.from_angle(TAU * i / 12.0)
		if d.dot(away) < -0.1:
			continue
		var p := u.position + d * 170.0
		var open := true
		for k in range(1, 6):
			if not game._walkable(game.cell_of(u.position.lerp(p, k / 5.0))):
				open = false
				break
		if not open:
			continue
		var sc: float = p.distance_to(s.position) + d.dot(away) * 40.0
		if toward != Vector2.INF:
			sc += d.dot((toward - u.position).normalized()) * 60.0
		if sc > bs:
			bs = sc
			best = p
	if best == Vector2.INF:
		best = u.position + away * 170.0
	if u.order != "move" or u.order_point.distance_to(best) > 50.0:
		u.cmd_move(best)
	return true


## The best worker (or unarmed unit) for `u` to go after: the nearest it can see within PREY_R tiles, the ones in reach
## of an armed defender counted farther (no rooted creature attacks: a grub loading at its Rootmaw is fair game).
func pick_prey(u: Unit) -> Unit:
	var best: Unit = null
	var bs := INF
	var near: Array = game.units_near(u.position, PREY_R * Defs.TILE + 120.0)
	var biters: Array = near.filter(func(o: Unit) -> bool:
		return game.hostile(o.team, ai.team) and is_defender(o) and o.can_hit(u))
	for o in near:
		if not game.hostile(o.team, ai.team) or not is_prey(o) or not u.can_hit(o) or not game.is_visible_to(ai.team, o.position):
			continue
		var s: float = o.position.distance_to(u.position)
		if s > PREY_R * Defs.TILE:
			continue
		for b in biters:
			if b.position.distance_to(o.position) <= float(b.d["range"]) + b.radius + u.radius + 30.0:
				s += 400.0
			elif is_slow(b, [u]) and b.position.distance_to(o.position) <= float(b.d["range"]) + b.radius + u.radius + KITE_GAP + b.speed * 1.5:
				s += 300.0      # (a slow defender would reach it before it is cut down: one farther from it first)
		# one walking away as fast as it is is not caught: the ones standing (a grub loading at its Rootmaw) or coming
		# towards it first; the one it is after already is kept unless another is clearly better (no to and fro)
		if o.velocity.length() > 10.0 and o.velocity.dot(o.position - u.position) > 0.0 and float(o.d["speed"]) >= float(u.d["speed"]) * 0.9:
			s += 160.0
		if o == u.order_target:
			s -= 90.0
		if s < bs:
			bs = s
			best = o
	return best


## Where the worker line is: the enemy's workers it can see (the farther from their main the better), else its economy
## buildings, else the Brood's Rootmaws or Mother it has seen, else its base (AI._prey_spot).
func work_line(from: Vector2) -> Vector2:
	var p: Vector2 = ai._prey_spot(from)
	var foe: int = ai._foe()
	if foe >= 0 and game.faction_of(foe) == "brood":
		# (the Brood has no economy buildings: its grubs walk between the Rootmaws and the Mother)
		var best := Vector2.INF
		var bd := INF
		var best_q := false
		var seen_worker := false
		for o in game.units:
			if o.team == foe and not o.dead and o.is_worker() and game.is_visible_to(ai.team, o.position) and not ai.raid_spot_bad(o.position):
				seen_worker = true
				break
		if not seen_worker:
			for o in game.units:
				if o.team != foe or o.dead or not (o.kind == BroodNew.MAW or o.kind == BroodNew.QUEEN):
					continue
				if not game.is_visible_to(ai.team, o.position) and not (ai.scout != null and ai.scout._nb_seen.has(o)):
					continue
				var dd: float = o.position.distance_to(from)
				if ai.raid_spot_bad(o.position):
					dd += 100000.0      # (crown-v-brood-coach: chased off there lately: another Rootmaw first)
				elif o.kind == BroodNew.QUEEN:
					dd += 1500.0        # (the Mother's ground is where the Raptors wait: an outlying Rootmaw first)
				if dd < bd:
					bd = dd
					best = o.position
					best_q = o.kind == BroodNew.QUEEN
			if best != Vector2.INF:
				p = best
				if best_q and ai.has_method("raid_v_brood") and ai.raid_v_brood():
					# (crown-v-brood-coach: at the Mother the raid waits 6 tiles out on the riders' side, where the grubs walk in
					# with their food: never at the Mother herself, test_ai_rush "workers before the Brood Mother")
					p = best + (from - best).normalized() * 6.0 * Defs.TILE
	return p


## One of the Crown's raiders (AI._raid) with a slow defender near: a step away from its bite, else the grub it can't
## reach in time (an attack order: the loaded pistol goes at the grub, never at the Sire), else a plain ride on to the
## worker line (no attack-move, which would pick the Sire). Always true (the orders are given here).
func raid_step(u: Unit, slows: Array, goal: Vector2) -> bool:
	if u.dead or u.off_field or u.order == "mount" or u.order == "dismount":
		return true
	var w := pick_prey(u)
	if kite_from(u, slows, w.position if w else goal):
		if game.clock - float(_raid_kite_t) > 8.0:
			_say(u, "keeps away from %s (the raid stays)" % String(Defs.UNITS[slows[0].kind]["name"]))
		_raid_kite_t = game.clock
		raid_kites += 1
		return true
	if w:
		if u.order != "attack" or u.order_target != w:
			u.cmd_attack(w)
		return true
	if u.position.distance_to(goal) > 120.0 and (u.order != "move" or u.order_point.distance_to(goal) > 120.0):
		u.cmd_move(goal + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	return true


var _raid_kite_t := -99.0
var raid_kites := 0              # (tests) kite steps the raid took


# ------------------------------------------------------------------ one unit, one step

## Steer one harassing unit for a second: pull back from a real defender, go after prey, fight a weak defender in its
## face, else walk on (never stopping at a structure). Returns "back", "prey", "fight", "walk" or "stuck".
func steer(u: Unit, party: Array, goal: Vector2, home: Vector2, e: Dictionary) -> String:
	var foes := defenders_near(u.position, party)
	if outmatched(party, foes):
		var away := Vector2.ZERO
		for o in foes:
			away += (u.position - o.position).normalized()
		var dir := (home - u.position).normalized()
		if away != Vector2.ZERO:
			dir = (dir + away.normalized()).normalized()
		if e.get("back_until", 0.0) < game.clock:
			e["backs"] = int(e.get("backs", 0)) + 1
			_say(u, "pulls back from %s" % String(Defs.UNITS[foes[0].kind]["name"]))
		e["back_until"] = game.clock + BACK_FOR
		u.cmd_move(u.position + dir * 260.0)
		return "back"
	if float(e.get("back_until", 0.0)) > game.clock:
		if u.order == "idle":
			u.cmd_move(u.position + (home - u.position).normalized() * 160.0)
		return "back"
	var w := pick_prey(u)
	# a slow defender (a Sire, the Mother, a Rootmaw on foot against riders) about to bite: a step away, toward the prey
	# it can't reach in time; the party stays (RAID MICRO, docs/raid_micro.md)
	var slows := slow_of(party, foes)
	if not slows.is_empty() and kite_from(u, slows, w.position if w else goal):
		if float(e.get("kite_t", -99.0)) < game.clock - 8.0:
			_say(u, "keeps away from %s" % String(Defs.UNITS[slows[0].kind]["name"]))
		e["kite_t"] = game.clock
		e["kites"] = int(e.get("kites", 0)) + 1
		return "kite"
	if w:
		if u.order != "attack" or u.order_target != w:
			u.cmd_attack(w)
		e["still"] = 0.0
		return "prey"
	# an armed enemy it can beat is in its face: it fights it (it does not turn its back); a slow one is not fought
	foes = foes.filter(func(o: Unit) -> bool: return not slows.has(o))
	if not foes.is_empty():
		var f: Unit = foes[0]
		if u.order != "attack" or u.order_target == null or not is_instance_valid(u.order_target) or u.order_target.dead or is_static(u.order_target):
			u.cmd_attack(f)
		return "fight"
	# walk on to the worker line, past structures (a plain move); stuck there: break through
	var lp: Vector2 = e.get("last_pos", u.position)
	if lp.distance_to(u.position) < 12.0:
		e["still"] = float(e.get("still", 0.0)) + _dt
	else:
		e["still"] = 0.0
	e["last_pos"] = u.position
	if float(e["still"]) >= STUCK_FOR and u.position.distance_to(goal) > 140.0:
		if not (u.order == "amove" or u.order == "attack"):
			u.cmd_move(goal, true)      # (the way is shut: it breaks what is in it)
			e["still"] = 0.0
			e["stuck_t"] = game.clock
		return "stuck"
	if game.clock - float(e.get("stuck_t", -99.0)) < 6.0 and u.order == "attack" and is_static(u.order_target):
		return "stuck"
	var tgt = u.target if u.target != null and is_instance_valid(u.target) else null
	var wrong: bool = u.order == "idle" or u.order == "amove" or (u.order == "attack" and is_static(u.order_target)) \
		or (tgt != null and is_static(tgt)) or u.order_point.distance_to(goal) > 160.0
	if wrong and u.position.distance_to(goal) > 120.0:
		u.cmd_move(goal + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	elif u.position.distance_to(goal) <= 120.0:
		e["goal_done"] = true
	return "walk"


# ------------------------------------------------------------------ the party

func has(u: Unit) -> bool:
	return units.has(u)


## Take a unit on (a stray chaser, a lone survivor out in the field). False if it may not.
func add(u: Unit, why: String) -> bool:
	if units.has(u):
		return true
	if units.size() >= MAX_UNITS or float(done.get(u, -1.0)) > game.clock:
		return false
	units[u] = {"t0": game.clock, "back_until": 0.0, "backs": 0, "home": false, "last_pos": u.position, "still": 0.0}
	u.remove_meta("ai_scout")
	_say(u, "goes on to harass the workers (%s)" % why)
	return true


func _let_go(u: Unit) -> void:
	units.erase(u)
	done[u] = game.clock + 60.0


## Army units out alone far from home, chasing or wandering (not in a wave, a detachment, a guard, the Crown's raid, the
## scout or on an errand): they become harassers instead of standing at the first thing they meet.
func adopt_strays(army: Array) -> void:
	if ai.difficulty < 1 or ai.peaceful or ai._foe() < 0:
		return
	for u in army:
		if units.size() >= MAX_UNITS:
			return
		if units.has(u) or u.dead or u.off_field or u.is_air() or u.deploys() or not u.has_attack() or u.is_worker():
			continue
		if not (u.order == "amove" or u.order == "attack" or u.order == "idle"):
			continue
		if ai._wave_set.has(u) or ai._det.has(u) or ai._raiders.has(u) or ai._on_errand(u) or (ai.scout != null and (u == ai.scout.unit or u == ai.scout.sentry)):
			continue
		if ai._clock() and ai.r5.busy(u):
			continue
		if float(u.d.get("speed", 0)) < 55.0 or ai._home_dist(u.position) < STRAY_FROM:
			continue
		# A LONE SLOW SOLDIER COMES HOME (the owner's playtest 2026-11-03, Greenhold: a Crown Musketeer that had chased
		# something out was taken as a harasser, alone, 2:35-4:29, and only got itself chased about: "usually it would be a
		# bad idea"). Riders harass; a slow one (a Musketeer, anything that can't outrun a Raptor) found out alone walks home,
		# unless it is clearly safe (no armed enemy seen within 15 tiles). The Clockwork's Clock Soldier is the exception the
		# owner asked for on 2026-10-31 (docs/ai_harass.md): it harasses as before.
		# STRAY MUSKETEERS (the owner's log 2026-11-03, v0.27.0 Red Coast 4:18: three Musketeers out together were each "not
		# alone" and went on to harass as a group): the Crown's slow soldiers are never harassers, alone or not, safe or not.
		var crown_slow: bool = ai._crown() and u.speed < LONE_FAST and not OS.get_cmdline_user_args().has("strays:off")      # (study switch: `-- strays:off` as 0.27.0)
		if crown_slow or (not ai._clock() and u.speed < LONE_FAST and _alone(u) and not _clearly_safe(u)):
			if float(done.get(u, -1.0)) <= game.clock:
				done[u] = game.clock + 30.0
				_say(u, "comes home (out alone, too slow to harass)")
			var post: Vector2 = ai._post_spot()
			u.cmd_move(post if post != Vector2.INF else game.center_of_team(ai.team))
			continue
		add(u, "out alone")


## No friend of its army within 400 px.
func _alone(u: Unit) -> bool:
	for o in game.units_near(u.position, 400.0):
		if o != u and o.team == ai.team and not o.dead and not o.is_worker() and o.has_attack():
			return false
	return true


## No armed enemy on its feet seen within 15 tiles.
func _clearly_safe(u: Unit) -> bool:
	for o in game.units_near(u.position, 15.0 * Defs.TILE):
		if game.hostile(o.team, ai.team) and is_defender(o) and game.is_visible_to(ai.team, o.position):
			return false
	return true


## Every army think: each harasser steers (see steer); hurt, run down, out too long or driven back too often, it goes
## home and is let go when there.
func tick() -> void:
	_dt = clampf(game.clock - _last_t, 0.0, 3.0) if _last_t >= 0.0 else 1.0
	_last_t = game.clock
	if units.is_empty():
		return
	var party: Array = []
	for u in units.keys():
		if not is_instance_valid(u) or u.dead:
			units.erase(u)
			continue
		party.append(u)
	if party.is_empty():
		return
	var post: Vector2 = ai._post_spot()
	var home: Vector2 = post if post != Vector2.INF else game.center_of_team(ai.team)
	var c := Vector2.ZERO
	for u in party:
		c += u.position
	c /= party.size()
	var goal := work_line(c)
	var press := pressing()
	for u in party:
		var e: Dictionary = units[u]
		if not e["home"]:
			var why := ""
			if u.hp < u.max_hp * (PRESS_HP if press else HOME_HP):
				why = "hurt"
			elif ai._clock() and u.wind < 0.25 and not u.runs_on_spring() and not u._in_field:
				why = "running down"
			elif game.clock - float(e["t0"]) > (PRESS_TIME if press else MAX_TIME):
				why = "out long enough"
			elif int(e["backs"]) >= (PRESS_BACKS if press else MAX_BACKS) and float(e["back_until"]) < game.clock:
				why = "driven back too often"
			if why != "":
				e["home"] = true
				_say(u, "goes home (%s)" % why)
		if e["home"]:
			if ai._home_dist(u.position) < 300.0:
				_let_go(u)
				u.cmd_move(home, true)
			elif u.order != "move" or u.order_point.distance_to(home) > 120.0:
				u.cmd_move(home)
			continue
		var g := goal
		if e.get("goal_done", false):
			# (at the worker line and nothing to hunt: a loop round the enemy's base, then the line again)
			g = ai._enemy_base() + Vector2.from_angle(fmod(game.clock * 0.05, TAU)) * 6.0 * Defs.TILE
			if u.position.distance_to(g) < 140.0:
				e["goal_done"] = false
		e["state"] = steer(u, party, g, home, e)
