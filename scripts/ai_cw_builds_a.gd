extends RefCounted
## THE CLOCKWORK COMPUTER'S BUILDS, SET A (the owner, 2026-11-03: "do it all"; docs/clockwork_builds_a.md): two plans of
## AIClockwork (scripts/ai_clockwork.gd) besides the Springer timing, each a written opening build order coached in filmed
## games. Everything they need beyond the shared build-order steps lives here, so other plans' branches merge cleanly:
##
## THE CLOCK SOLDIER RUSH (plan "cs_rush"): an early Light Works (two), Clock Soldiers out of both, the first RUSH_N of them
## go out with two Winders (the CRANKS: they wind and mend the soldiers behind the fight; a construct runs down in about
## 80 s off its gear field), straight at the enemy's workers. Steps of its own:
##   "rush"        the party goes out (once plan "rush" Clock Soldiers stand at home)
##   "rush_over"   waits until the rush is judged (FAILED or SUCCEEDED); the economy steps after it are the transition
## Up there the soldiers cut down the workers in reach (the ones REPAIRING a wall or gate first: repair is not nerfed, the
## owner 2026-10-27, it is to be dealt with), else go for the next worker seen, else the economy (the hall's ground); a wall
## or gate in the way is broken by the unit's own wall rule (attack-move). Fresh soldiers made after it left join only as a
## group of REINF_GROUP (no trickling). The verdict, from facts: FAILED (beaten back, the defence worth more, no headway)
## = everyone home, no wave before a real army (the shared computer's regroup), the build goes on with the economy;
## SUCCEEDED = it keeps hunting, and goes home when it is down to PARTY_MIN.
##
## THE TURRET TURTLE (plan "turtle"): Ratchet Turrets at the choke (the top of the main's ramp, one each side: their 4-tile
## circles may not overlap), a FAST second Clocktower behind them, a turret by it, then the economy and a strong mid-game
## army (its STRATEGIES row: a later, bigger first wave). Step of its own:
##   "turret ramp"   a Ratchet Turret by the top of the main's ramp (the first on one side, the next on the other)
##   "turret hall2"  a Ratchet Turret on the enemy's side of the newest Clocktower
## Telegraph and fairness (design_principles 1): no cheating, it sees what its side sees and knows where the enemy started.

const RUSH_N := 5                # Clock Soldiers the rush waits for (plan "rush" overrides)
const REINF_GROUP := 3           # fresh soldiers join the party only this many at once
const PARTY_MIN := 2             # the party goes home when it is down to this many
const HUNT_R := 10.0             # tiles: a worker seen this close is hunted
const MENDER_R := 7.0            # tiles: a worker mending a piece this close is cut down first
const FLEE_K := 1.3              # the defence worth more than this share of the party (and nothing gained): FAILED
const CRANK_BACK := 90.0         # px: the cranks keep this far behind the party's middle, toward home

var ai = null
var game: Game = null
var team := 0

# ---- the rush
var party: Array = []
var cranks: Array = []
var reinf: Array = []            # fresh soldiers walking out to the party as a group
var phase := ""                  # "", "gather", "march", "fight", "home", "over"
var since := 0.0
var launched := false
var verdict := ""                # "", "failed", "succeeded"
var why := ""
var n0 := 0
var value0 := 0.0
var joined := 0.0
var kill0 := 0
var t_arrive := -1.0             # first in the enemy's main (the fight began)
var foe := -1
var prey := Vector2.INF
var menders_cut := 0
var _last_kill := 0
var _last_kill_t := 0.0

# ---- the turtle
var turrets_laid: Array = []     # [kind of target, Building]


func _init(a) -> void:
	ai = a
	game = a.game
	team = a.team


func has(u: Unit) -> bool:
	return party.has(u) or cranks.has(u) or reinf.has(u)


func say(s: String) -> void:
	ai.note(s)


## A build-order step of this file ({"st": ...} as AIClockwork._do_step), or {} when the head is not one of ours.
func step(i: int, parts: Array) -> Dictionary:
	match String(parts[0]):
		"rush":
			return {"st": "done"} if launch() else {"st": "wait"}
		"rush_over":
			return {"st": "done"} if (launched and verdict != "") else {"st": "wait"}
		"turret":
			return _turret_step(i, String(parts[1]) if parts.size() > 1 else "ramp")
		"ramp_regulator":
			return _relay_step(i)
		"works_back":
			return _works_back_step(i)
	return {}


func _home() -> Vector2:
	var h: Array = ai._halls()
	return (h[0] as Building).center() if not h.is_empty() else game.center_of_team(team)


func _foe_hall() -> Vector2:
	return (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE


func _centre(list: Array) -> Vector2:
	var c := Vector2.ZERO
	for u in list:
		c += u.position
	return c / maxf(1.0, list.size())


func _value(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += ai._unit_value(u)
	return v


func _value_cost(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += _cost(u)
	return v


func _cost(u: Unit) -> float:
	return float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))


## The armed enemies our side sees within r of p, by value.
func _foe_near(p: Vector2, r: float) -> float:
	var v := 0.0
	for o in game.units_near(p, r):
		if o.dead or o.off_field or not game.hostile(o.team, team) or not ai._armed(o) or not game.is_visible_to(team, o.position):
			continue
		v += ai._unit_value(o)
	return v


func _home_soldiers() -> Array:
	return game.army(team).filter(func(u: Unit) -> bool: return u.kind == "clock_soldier" and not u.dead and not has(u) \
		and not ai._on_errand(u) and u.position.distance_to(_home()) < 900.0)


# ------------------------------------------------------------------ THE RUSH

## The "rush" step: the party goes out once the plan's Clock Soldiers stand at home.
func launch() -> bool:
	if launched:
		return true
	var want := int(ai.plan.get("rush", RUSH_N))
	var cs := _home_soldiers()
	if cs.size() < want:
		return false
	foe = ai._foe()
	if foe < 0:
		return false
	party = cs
	n0 = party.size()
	value0 = 0.0
	for u in party:
		value0 += _cost(u)
	kill0 = int(game.stats[team]["value_killed"])
	_last_kill = kill0
	_last_kill_t = game.clock
	_pick_cranks()
	launched = true
	_phase("gather")
	say("rush: the Clock Soldier rush goes out (%d Clock Soldiers, %d Winders to wind them) at %d supply" % [party.size(), cranks.size(), game.supply_used(team)])
	return true


func _phase(p: String) -> void:
	phase = p
	since = game.clock


func _pick_cranks() -> void:
	cranks = cranks.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var want := int(ai.plan.get("rush_winders", 2))
	if cranks.size() >= want:
		return
	var home := _home()
	var labs: Array = game.workers(team).filter(func(u: Unit) -> bool: return not cranks.has(u) and u.order != "build" and u.crate_site == null \
		and not ai._escort.has(u) and not (ai.scout != null and ai.scout.is_scout(u)) and not ai._held_worker(u) \
		and (u.home_mine == null or u.home_mine.kind != "mainspring"))
	labs.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(home) < b.position.distance_to(home))
	for u in labs.slice(0, want - cranks.size()):
		cranks.append(u)


func tick() -> void:
	if not launched or game.over or phase == "over":
		return
	party = party.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	cranks = cranks.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	reinf = reinf.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	if party.is_empty() and phase != "home":
		_judge_now("the party is dead" if verdict == "" else "")
		_go_home_now()
	match phase:
		"gather":
			_gather()
		"march":
			_march()
		"fight":
			_fight()
		"home":
			_home_tick()
	if phase in ["march", "fight"]:
		_reinforce()
	_crank_tick()


func _gather() -> void:
	var pt := _home().lerp(_foe_hall(), 0.2)
	var c := _centre(party)
	var spread := 0.0
	for u in party:
		spread = maxf(spread, u.position.distance_to(c))
		if u.position.distance_to(pt) > 100.0 and (u.order != "move" or u.order_point.distance_to(pt) > 80.0):
			u.cmd_move(pt + Vector2(randf_range(-40, 40), randf_range(-40, 40)), true)
	if (c.distance_to(pt) < 140.0 and spread < 140.0) or game.clock - since > 25.0:
		_phase("march")
		prey = _prey()
		say("rush: marching on the enemy's economy (%d Clock Soldiers)" % party.size())


## Where the workers are: the enemy's nearest hall (its economy round it); the open target of the shared computer when it
## has one (an unwalled expansion).
func _prey() -> Vector2:
	var p: Vector2 = ai._enemy_base()
	return p if p != Vector2.INF else _foe_hall()


func _march() -> void:
	var c := _centre(party)
	for u in party:
		if u.target != null and is_instance_valid(u.target) and not u.target.dead:
			continue
		if u.order == "idle" or u.order_point.distance_to(prey) > 120.0:
			u.cmd_move(prey + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)
	# (a force on the way it cannot beat: the rush is over before it starts, everyone home whole)
	var met := _foe_near(c, 300.0)
	if met > _value(party) * FLEE_K + 60.0:
		_fail("it met a stronger force on the way (%d against %d)" % [int(met), int(_value(party))])
		return
	# in the enemy's main (or in a fight near it): the fight begins
	var near_home := c.distance_to(prey) < 14.0 * Defs.TILE
	if near_home or _foe_near(c, 260.0) > 0.0 and c.distance_to(prey) < 22.0 * Defs.TILE:
		_phase("fight")
		if t_arrive < 0.0:
			t_arrive = game.clock
			say("rush: at the enemy's base (%d Clock Soldiers; defence seen %d)" % [party.size(), int(_foe_near(c, 320.0))])
	elif game.clock - since > 120.0:
		_judge_now("it never got there")


func _fight() -> void:
	var T := Defs.TILE
	var c := _centre(party)
	_wall_check(c)
	for u in party:
		_hunt(u, T)
	if game.clock - since > 3.0:
		_verdict(c)


## THE WALL (what the films showed: the Hard Crown walls its ramp by 0:40 and mends the piece with two or three
## Labourers, 20+ hp a second each, more than five Clock Soldiers take off it). Once in front of the enemy's base: if the
## way in is shut (a wall or a shut gate) and it is held (menders at it, or guns behind it worth more than WALL_HELD of
## the party), the party does not throw itself at it: it hunts what is outside the wall (workers out there, an expansion)
## for a little while, then calls the rush FAILED and walks home whole. A thin wall (no mender, little behind it) is broken.
const WALL_HELD := 0.6
const WALL_LOOK := 20.0         # s it hunts outside a held wall before it gives up
var walled := false             # the way in is shut
var held := false               # ... and held
var held_t := -1.0
var _wall_t := -99.0


func _wall_check(c: Vector2) -> void:
	if verdict != "" or game.clock - _wall_t < 2.0 or party.is_empty():
		return
	_wall_t = game.clock
	var lead: Unit = party[0]
	for u in party:
		if u.position.distance_to(prey) < lead.position.distance_to(prey):
			lead = u
	walled = not lead._walk_reaches_point(prey)
	if not walled:
		held = false
		return
	var menders := 0
	var pieces := 0
	for b in game.buildings:
		if b.dead or not game.hostile(b.team, team) or b.center().distance_to(c) > 12.0 * Defs.TILE or not game.is_visible_to(team, b.center()):
			continue
		pieces += 1
	for o in game.units_near(c, 12.0 * Defs.TILE):
		if not o.dead and o.is_worker() and game.hostile(o.team, team) and o.order == "repair" and o.order_target is Building and game.is_visible_to(team, o.position):
			menders += 1
	var defv := _foe_near(c, 360.0)
	var was := held
	# (held once: it stays held until the wall is left unmended and nearly unguarded for a while, no flicker)
	var hold_now := menders >= 2 or defv > _value(party) * WALL_HELD
	if hold_now:
		_held_seen = game.clock
	held = hold_now or (was and game.clock - _held_seen < 8.0)
	if held and not was:
		held_t = game.clock
		say("rush: the way in is walled and held (%d menders, %d value of guns seen): it hunts outside the wall a little, then home" % [menders, int(defv)])
	if held and game.clock - held_t > WALL_LOOK and (game.clock - _last_kill_t > 10.0 or game.clock - held_t > 45.0):
		_fail("the way in is walled and held (%d menders, %d value of guns behind it)" % [menders, int(defv)])


var _held_seen := -99.0


## Enemy workers our side sees within 14 tiles that the party can walk to (outside the wall).
func _outside_prey(c: Vector2) -> Array:
	if party.is_empty():
		return []
	var out: Array = []
	for o in game.units_near(c, 14.0 * Defs.TILE):
		if o.dead or o.off_field or not o.is_worker() or not game.hostile(o.team, team) or not game.is_visible_to(team, o.position):
			continue
		if (party[0] as Unit)._walk_reaches_point(o.position):
			out.append(o)
		if out.size() >= 3:
			break
	return out


## One soldier: a mender at a piece in reach first, then a worker seen nearby (if no soldier is on him), else the fight
## goes on, else on to the prey's ground on attack-move (a wall in the way is broken by the unit's own wall rule). Before a
## held wall: only the workers outside it, else it waits out of the guns' reach.
func _hunt(u: Unit, T: float) -> void:
	var tgt = u.target if u.target != null and is_instance_valid(u.target) and not u.target.dead else null
	var fighting: bool = tgt is Unit and not (tgt as Unit).is_worker()
	var best: Unit = null
	var bs := INF
	var c := _centre(party)
	for o in game.units_near(u.position, HUNT_R * T):
		if o.dead or o.off_field or not o.is_worker() or not game.hostile(o.team, team) or not u.can_hit(o) or not game.is_visible_to(team, o.position):
			continue
		if o.position.distance_to(c) > HUNT_R * T * 1.2:
			continue          # (the party keeps together: no chasing a lone scout across the map)
		if walled and not u._walk_reaches_point(o.position):
			continue
		var d: float = o.position.distance_to(u.position)
		var mending: bool = o.order == "repair" and o.order_target is Building and d < MENDER_R * T
		var s: float = d - (1000.0 if mending else 0.0)
		if s < bs:
			bs = s
			best = o
	if best != null and (not fighting or (best.order == "repair" and best.position.distance_to(u.position) < 2.5 * T)):
		if u.order != "attack" or u.order_target != best:
			if best.order == "repair":
				menders_cut += 1
			u.cmd_attack(best)
		return
	if fighting:
		return
	if held:
		# (before a held wall: back out of the muskets' reach, toward home, and wait for the verdict)
		var back := c + (_home() - c).normalized() * 160.0
		if u.position.distance_to(back) > 80.0 and (u.order != "move" or u.order_point.distance_to(back) > 60.0):
			u.cmd_move(back + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
		return
	if u.order == "idle" or (u.order == "move" and u.order_point.distance_to(prey) > 160.0) or (u.order == "attack" and u.order_target is Unit and (u.order_target as Unit).is_worker() and (u.order_target as Unit).dead):
		u.cmd_move(prey + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)


## The verdict from facts (as the shared rush's, scripts/ai.gd _rush_verdict).
func _verdict(c: Vector2) -> void:
	var gained := float(int(game.stats[team]["value_killed"]) - kill0)
	if int(game.stats[team]["value_killed"]) > _last_kill:
		_last_kill = int(game.stats[team]["value_killed"])
		_last_kill_t = game.clock
	var wv := maxf(1.0, value0 + joined)
	var mine := _value(party)
	var defv := _foe_near(c, 320.0)
	var t := game.clock - t_arrive
	var lost := maxf(0.0, value0 + joined - _value_cost(party) - _value_cost(reinf))
	if verdict == "":
		if lost >= wv * 0.35 and gained < lost * 0.5:
			_fail("losing the trade (%d lost for %d killed)" % [int(lost), int(gained)])
		elif party.size() <= PARTY_MIN and gained < wv * 0.8:
			_fail("beaten back (%d of %d left; %d value killed for %d sent)" % [party.size(), n0, int(gained), int(wv)])
		elif defv >= 100.0 and defv > mine * FLEE_K and gained < wv * 0.6 and t > 8.0:
			_fail("the defence is worth more (%d against %d; %d killed)" % [int(defv), int(mine), int(gained)])
		elif t > 90.0 and gained < wv * 0.3:
			_fail("no headway in %d s (%d killed)" % [int(t), int(gained)])
		elif gained >= wv * 0.8:
			verdict = "succeeded"
			why = "%d value killed for %d sent" % [int(gained), int(wv)]
			say("rush: SUCCEEDED (%s): it keeps hunting the workers" % why)
		elif t > 150.0:
			if gained >= wv * 0.5:
				verdict = "succeeded"
				why = "%d value killed for %d sent in %d s" % [int(gained), int(wv), int(t)]
				say("rush: SUCCEEDED (%s)" % why)
			else:
				_fail("out of time (%d killed in %d s)" % [int(gained), int(t)])
		return
	# succeeded: home when it is down to a few, when the defence is too much, or after a long time without a kill
	if party.size() <= PARTY_MIN or (defv > mine * FLEE_K and defv >= 100.0) or game.clock - _last_kill_t > 60.0:
		say("rush: the party comes home (%d left; %d value killed in all)" % [party.size(), int(gained)])
		_go_home_now()


func _fail(w: String) -> void:
	verdict = "failed"
	why = w
	say("rush: FAILED (%s): everyone home; no wave before a real army, the economy goes on" % w)
	# (the shared computer's failed-rush rules: no wave for a while, and only a proper one: _rush_failed)
	ai._regroup_until = maxf(ai._regroup_until, game.clock + ai._lv([150.0, 120.0, 90.0]))
	ai._attack_at = maxi(ai._attack_at, 24)
	ai._failed += 1
	_go_home_now()


func _judge_now(w: String) -> void:
	if verdict == "" and w != "":
		var gained := float(int(game.stats[team]["value_killed"]) - kill0)
		if gained >= (value0 + joined) * 0.8:
			verdict = "succeeded"
			why = "%d value killed" % int(gained)
			say("rush: SUCCEEDED (%s), %s" % [why, w])
		else:
			_fail(w)


func _go_home_now() -> void:
	if phase == "home" or phase == "over":
		return
	_phase("home")
	var pt := _home_spot()
	for u in party + reinf:
		u.cmd_move(pt + Vector2(randf_range(-50, 50), randf_range(-50, 50)))
	reinf.clear()


func _home_spot() -> Vector2:
	return ai._home_spot(ai._front())


## Home: once there (or after a while) the soldiers go back to the shared army and the cranks to work.
func _home_tick() -> void:
	var pt := _home_spot()
	var back := party.filter(func(u: Unit) -> bool: return u.position.distance_to(pt) < 260.0)
	if back.size() >= party.size() or game.clock - since > 45.0:
		say("rush: over (%s); %d Clock Soldiers back to the army, %d value killed in all, %d menders cut at" % [verdict, party.size(), int(game.stats[team]["value_killed"]) - kill0, menders_cut])
		party.clear()
		for w in cranks:
			w.cmd_stop()
		cranks.clear()
		_phase("over")


## Fresh soldiers made after the party left walk out to it, REINF_GROUP at a time (never one by one).
func _reinforce() -> void:
	if verdict == "failed":
		return
	if not reinf.is_empty():
		var c := _centre(party) if not party.is_empty() else prey
		var rc := _centre(reinf)
		if rc.distance_to(c) < 200.0:
			for u in reinf:
				party.append(u)
			say("rush: %d fresh Clock Soldiers join (now %d)" % [reinf.size(), party.size()])
			reinf.clear()
			return
		for u in reinf:
			if u.target != null and is_instance_valid(u.target) and not u.target.dead:
				continue
			if u.order == "idle" or u.order_point.distance_to(c) > 150.0:
				u.cmd_move(c + Vector2(randf_range(-40, 40), randf_range(-40, 40)), true)
		return
	var fresh := _home_soldiers()
	if fresh.size() >= REINF_GROUP and (verdict == "" or party.size() > PARTY_MIN):
		for u in fresh:
			reinf.append(u)
			joined += _cost(u)


## The cranks: behind the party (toward home), winding the most run-down soldier and mending the hurt; out of the way of
## armed enemies.
func _crank_tick() -> void:
	if phase in ["home", "over"] or party.is_empty():
		if phase == "home":
			for w in cranks:
				if w.position.distance_to(_home()) > 300.0 and (w.order != "move" or w.order_point.distance_to(_home()) > 100.0):
					w.cmd_move(_home())
		return
	if cranks.size() < int(ai.plan.get("rush_winders", 2)) and game.clock - since > 5.0 and phase == "gather":
		_pick_cranks()
	var c := _centre(party)
	var dir := (_home() - c).normalized() if _home().distance_to(c) > 1.0 else Vector2.ZERO
	var spot := c + dir * CRANK_BACK
	var need: Array = party.filter(func(u: Unit) -> bool: return u.position.distance_to(c) < 360.0 and (u.wind < 0.6 or u.hp < u.max_hp * 0.6))
	need.sort_custom(func(a: Unit, b: Unit) -> bool: return a.wind + a.hp / a.max_hp < b.wind + b.hp / b.max_hp)
	for w in cranks:
		if _foe_near(w.position, 140.0) > 0.0:
			var away: Vector2 = w.position + dir * 160.0
			if w.order != "move" or w.order_point.distance_to(away) > 60.0:
				w.cmd_move(away)
			continue
		if w.order == "repair" and is_instance_valid(w.order_target) and not w.order_target.dead and party.has(w.order_target):
			if (w.order_target as Unit).wind < 0.95 or w.order_target.hp < w.order_target.max_hp * 0.9:
				continue
		while not need.is_empty() and _foe_near(need[0].position, 110.0) > 0.0:
			need.pop_front()          # (not into the fight)
		if not need.is_empty() and w.can_repair(need[0]):
			w.cmd_repair(need.pop_front())
			continue
		if w.position.distance_to(spot) > 70.0 and (w.order != "move" or w.order_point.distance_to(spot) > 50.0):
			w.cmd_move(spot + Vector2(randf_range(-20, 20), randf_range(-20, 20)))


# ------------------------------------------------------------------ THE TURTLE

## "turret ramp" / "turret hall2": a Ratchet Turret at the choke, meshing with a gear building of ours (it must stay linked
## to the gear field to fire).
func _turret_step(i: int, where: String) -> Dictionary:
	var k := Defs.CW_TURRET
	if ai._placed.has(i):
		return {"st": "done"}
	var cost := game.build_price(team, k)
	if not game.requirement_met(team, k):
		return ai._wait_req()
	if ai._free() < cost:
		return {"st": "money", "cost": cost, "t": 0.0}
	if _turret_target(where) == Vector2.INF:
		return ai._wait_req()          # (the new Clocktower is not up yet)
	var spot := turret_spot(where)
	if OS.get_cmdline_user_args().has("cwdebug"):
		var hh: Array = ai._halls()
		print("DBG turret %s target %s ramp_top %s hall %s spot %s" % [where, str(_turret_target(where)), str(game.ramp_top(hh[0]) * Defs.TILE) if not hh.is_empty() else "-", str((hh[0] as Building).center()) if not hh.is_empty() else "-", str(Vector2(spot) * Defs.TILE)])
	if spot.x < 0:
		say("turret %s: no spot found, skipped" % where)
		return {"st": "done"}
	game.set_gear_pick(team, k, false)
	var b: Building = ai._lay(k, spot, false)
	if b == null:
		return {"st": "wait", "cost": cost, "t": 0.0}
	ai._placed[i] = b
	turrets_laid.append([where, b])
	var tgt := _turret_target(where)
	say("lays a Ratchet Turret (%s) at %d supply, %d px from the choke (step %d)" % [where, game.supply_used(team),
		int((Vector2(spot) * Defs.TILE + Vector2(Defs.TILE, Defs.TILE)).distance_to(tgt)) if tgt != Vector2.INF else -1, i + 1])
	return {"st": "done"}


## "ramp_regulator": the plan's Regulator (supply, needed anyway) laid toward the top of the main's ramp, meshing with the
## gear building nearest it: a stepping stone that carries the gear field out to the choke, so the turrets that mesh with it
## stand where they cover the ramp (the first films: the field ended 9 tiles short of it, the turret did not reach).
func _relay_step(i: int) -> Dictionary:
	var k: String = ai._sup()
	if ai._placed.has(i):
		return {"st": "done"}
	var cost := game.build_price(team, k)
	if ai._free() < cost:
		return {"st": "money", "cost": cost, "t": 0.0}
	var tgt := _turret_target("ramp")
	var spot := _gear_spot(k, tgt) if tgt != Vector2.INF else Vector2i(-1, -1)
	if spot.x < 0:
		spot = ai._spot(k)
	if spot.x < 0:
		return {"st": "wait", "cost": cost, "t": 0.0}
	var b: Building = ai._lay(k, spot, false)
	if b == null:
		return {"st": "wait", "cost": cost, "t": 0.0}
	ai._placed[i] = b
	say("lays a Regulator toward the ramp (the gear field's stepping stone) at %d supply (step %d)" % [game.supply_used(team), i + 1])
	return {"st": "done"}


## The ground the turret is to cover: the top of the main's ramp (from inside), or the newest Clocktower's side toward the
## enemy.
func _turret_target(where: String) -> Vector2:
	var T := float(Defs.TILE)
	var halls: Array = ai._halls()
	if halls.is_empty():
		return Vector2.INF
	var main: Building = halls[0]
	if game.starts.size() > team:
		var home := Vector2(game.starts[team]) * T
		for h in halls:
			if (h as Building).center().distance_to(home) < main.center().distance_to(home):
				main = h
	var f: int = ai._foe()
	var enemy := (Vector2(game.starts[f]) + Vector2(2.5, 2.0)) * T if f >= 0 else main.center()
	if where == "hall2":
		var all: Array = game.halls_of(team, true)
		var newest: Building = null
		for h in all:
			if h != main and not h.dead:
				newest = h
		if newest == null:
			return Vector2.INF
		var rt2 := game.ramp_top(newest)
		if rt2 != Vector2.INF and (rt2 * T).distance_to(newest.center()) < 12.0 * T and game.level_of(rt2 * T) == game.level_of(newest.center()):
			return rt2 * T + (newest.center() - rt2 * T).normalized() * 1.5 * T
		return newest.center() + (enemy - newest.center()).normalized() * 5.0 * T
	var rt := game.ramp_top(main)
	if rt == Vector2.INF:
		return main.center() + (enemy - main.center()).normalized() * 7.0 * T
	var top := rt * T
	# (one tile in from the ramp's top: every turret goes as near it as the gear field and the 4-tile circles allow; the
	# second one is pushed aside by the first one's circle)
	return top + (main.center() - top).normalized() * 1.0 * T


## Our first Clocktower (the main).
func _main_hall() -> Building:
	var halls: Array = ai._halls()
	if halls.is_empty():
		return null
	var main: Building = halls[0]
	if game.starts.size() > team:
		var home := Vector2(game.starts[team]) * Defs.TILE
		for h in halls:
			if (h as Building).center().distance_to(home) < main.center().distance_to(home):
				main = h
	return main


## "works_back": the Light Works on the far side of the main Clocktower from its ramp (room left by the ramp for the
## Regulator and the turrets: the first films had the Works' ring right over the ramp's top, and no turret could stand
## near it), with room kept for a Mainspring by it.
func _works_back_step(i: int) -> Dictionary:
	var k: String = ai._works()
	if ai._placed.has(i):
		return {"st": "done"}
	var cost := game.build_price(team, k)
	if ai._free() < cost:
		return {"st": "money", "cost": cost, "t": 0.0}
	var main := _main_hall()
	if main == null:
		return ai._wait_req()
	var T := float(Defs.TILE)
	var rt := game.ramp_top(main)
	var spot := Vector2i(-1, -1)
	if rt != Vector2.INF:
		var away := main.center() + (main.center() - rt * T).normalized() * 7.0 * T
		game.set_gear_pick(team, k, false)
		spot = GearEcon.room_spot(game, team, k, [main], ["mainspring"], away, true, 14)
	if spot.x < 0:
		spot = ai._spot(k)
	if spot.x < 0:
		return {"st": "wait", "cost": cost, "t": 0.0}
	var b: Building = ai._lay(k, spot, false)
	if b == null:
		return {"st": "wait", "cost": cost, "t": 0.0}
	ai._placed[i] = b
	say("lays a Light Works behind the Clocktower, away from the ramp, at %d supply (step %d)" % [game.supply_used(team), i + 1])
	return {"st": "done"}


## The best cell for a turret: meshing with one of our built gear buildings, as near the target as the field allows.
func turret_spot(where: String) -> Vector2i:
	var tgt := _turret_target(where)
	if tgt == Vector2.INF:
		return Vector2i(-1, -1)
	return _gear_spot(Defs.CW_TURRET, tgt)


## A cell for a building of `k` meshing with one of our built gear buildings, as near `tgt` as the field allows.
func _gear_spot(k: String, tgt: Vector2) -> Vector2i:
	var lv := game.level_of(tgt)
	var gears: Array = game.buildings.filter(func(b: Building) -> bool: return b.team == team and not b.dead and b.built \
		and GearNet.has_gear(b) and game.level_of(b.center()) == lv)
	gears.sort_custom(func(a: Building, b: Building) -> bool: return a.center().distance_to(tgt) < b.center().distance_to(tgt))
	var best := Vector2i(-1, -1)
	var bd := INF
	game.set_gear_pick(team, k, false)
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	for g in gears.slice(0, 8):
		var c := GearEcon.room_spot(game, team, k, [g], [], tgt, true, 14)
		if c.x < 0:
			continue
		var d := (Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5).distance_to(tgt)
		if d < bd:
			bd = d
			best = c
	return best
