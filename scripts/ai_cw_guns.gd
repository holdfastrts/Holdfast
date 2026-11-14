extends RefCounted
## GUNS WITH A THIN GUARD ARE A TARGET (cinder-clockwork-ai, docs/cinder_clockwork_ai.md). The owner, 2026-11-13, watching
## Hard Crown OPTIMAL v Hard Clockwork OPTIMAL on Cinder Steps (0.35.10): three Crown Field Cannons with two Musketeers by
## them at the top of a ramp, and the Clockwork army beside them "respects" them instead of attacking while the cannons kill
## everything; later (11:49) it still had enough to rush the cannons but pulled back. A gun is deadly at range (round shot
## to 430 px) and worse at mid range (canister to 150 px, x1.5 against light units), but alone it is a slow, weak thing in a
## melee: standing off is the worst choice, closing fast with everything at once the best.
## So when the Clockwork's army (the push, or the whole army defending the base) meets enemy guns whose guard (the armed
## enemies by them that are not guns) is thin next to what it has, it RUSHES THE GUNS: every front unit is sent straight at
## a gun (spread over them, the nearest first), the Springers jump in, the Ballistas shoot the guns; the line no longer steps
## back from guns shooting down from high ground, and the push's loss rules do not pull it back while the rush still wins.
## The Clockwork only (the Crown's guns are the only guns: AI._is_gun). `-- cwguns:off` plays it as before.

const LOOK := 600.0             # px round the front: enemy guns in sight here
const GUARD_R := 300.0          # px: armed enemies (not guns) this near a gun guard it
const K := 2.5                  # it rushes when worth this many times the guard plus half the guns
const K_KEEP := 1.4             # ... and keeps rushing while worth this many times
const MIN_V := 300.0            # never with less than this
const K_HIGH := 3.5             # guns on high ground it is below (up a ramp: one way in, canister down it): far more needed
const GUARD_EXTRA := 150.0      # px: a guard is picked as if this much further than a gun (the guns first, a guard in the way)

static var on := not OS.get_cmdline_user_args().has("cwguns:off")


static func is_gun(o: Unit) -> bool:
	return o.kind == "cannon" or o.kind == "mortar"


## The enemy guns (deployed or limbered) the side sees within r of p.
static func guns_near(game: Game, team: int, p: Vector2, r: float) -> Array:
	var out: Array = []
	for o in game.units_near(p, r):
		if o.dead or o.off_field or not game.hostile(o.team, team) or not is_gun(o) or not game.is_visible_to(team, o.position):
			continue
		out.append(o)
	return out


## The armed enemies (not guns, not workers) the side sees within GUARD_R of any of the guns.
static func guard_of(ai, game: Game, team: int, guns: Array) -> Array:
	var out: Array = []
	for g in guns:
		for o in game.units_near(g.position, GUARD_R):
			if out.has(o) or o.dead or o.off_field or not game.hostile(o.team, team) or is_gun(o) or o.is_worker():
				continue
			if not ai._armed(o) or not game.is_visible_to(team, o.position):
				continue
			out.append(o)
	return out


## A short memory: guns and guards seen in the last MEM_T s still count (up on the high ground they drop in and out of
## sight as the front climbs; the sandbox's rush called itself off 3 s in when the guns went out of sight). `mem`: the
## caller's {Unit: clock}; returns `seen` plus the remembered ones still alive.
const MEM_T := 8.0


static func with_mem(game: Game, mem: Dictionary, seen: Array) -> Array:
	for u in seen:
		mem[u] = game.clock
	var out: Array = seen.duplicate()
	for u in mem.keys():
		if not is_instance_valid(u) or u.dead or game.clock - float(mem[u]) > MEM_T:
			mem.erase(u)
		elif not out.has(u):
			out.append(u)
	return out


static func value(ai, list: Array) -> float:
	var v := 0.0
	for u in list:
		if is_instance_valid(u) and not u.dead:
			v += ai._unit_value(u)
	return v


## What a rush has to beat: the guard, and half the guns (they fire canister as it closes).
static func cost(ai, guns: Array, guard: Array) -> float:
	return value(ai, guard) + 0.5 * value(ai, guns)


## Worth rushing? `keep`: a rush already on goes on at K_KEEP.
static func worth(ai, mine: float, guns: Array, guard: Array, keep: bool, uphill := false) -> bool:
	if not on or guns.is_empty() or mine < MIN_V:
		return false
	var k := K_KEEP if keep else (K_HIGH if uphill else K)
	return mine >= k * cost(ai, guns, guard)


## A rush already on, with its units at the guns: it goes on while worth K_CONTACT times what is left there (turning
## round in canister range is the worst of all; the sandbox's first try did, up the ramp, as the first ones reached them).
const K_CONTACT := 0.8
const CONTACT_R := 160.0


static func at_guns(list: Array, guns: Array) -> bool:
	for u in list:
		if not is_instance_valid(u) or u.dead:
			continue
		for g in guns:
			if u.position.distance_to(g.position) < CONTACT_R:
				return true
	return false


static func keep_on(ai, mine: float, list: Array, guns: Array, guard: Array) -> bool:
	return on and not guns.is_empty() and at_guns(list, guns) and mine >= K_CONTACT * cost(ai, guns, guard)


## Are the guns up on high ground and `from` below it?
static func uphill(game: Game, guns: Array, from: Vector2) -> bool:
	return not game.on_high(from) and guns.any(func(g) -> bool: return game.on_high(g.position))


## Every unit in `list` that can hit one goes at a gun: the nearest, spread so no gun gets far more than its share; the
## Springers jump in first (AICwArmy.spring_in). Ballistas and other slow machines shoot the nearest gun from where they
## are. Returns how many were sent.
static func rush(ai, list: Array, guns: Array, guard: Array = []) -> int:
	var live: Array = guns.filter(func(g) -> bool: return is_instance_valid(g) and not g.dead)
	if live.is_empty():
		return 0
	if ai.get("army_g") != null and ai.army_g != null:
		ai.army_g.spring_in(list, live)
	var per := {}
	var share := ceili(float(list.size()) / float(live.size())) + 1
	var sent := 0
	for u in list:
		if not is_instance_valid(u) or u.dead or u.is_worker() or (u.get("jump") != null and not u.jump.is_empty()):
			continue
		if u.kind == Defs.GREAT_WINDER_KIND:
			continue
		var best: Unit = null
		var bs := INF
		for g in live:
			if not u.can_hit(g):
				continue
			var s: float = u.position.distance_to(g.position) + (400.0 if int(per.get(g, 0)) >= share else 0.0)
			if s < bs:
				bs = s
				best = g
		# (a guard in its way, much nearer than any gun: it cuts that one down first, never walks past it to be bayoneted)
		for o in guard:
			if not is_instance_valid(o) or o.dead or not u.can_hit(o):
				continue
			var s2: float = u.position.distance_to(o.position) + GUARD_EXTRA
			if s2 < bs:
				bs = s2
				best = o
		if best == null:
			continue
		per[best] = int(per.get(best, 0)) + 1
		sent += 1
		if u.order == "attack" and u.order_target == best:
			continue
		if u.order == "attack" and u.order_target is Unit and (live.has(u.order_target) or guard.has(u.order_target)) \
				and is_instance_valid(u.order_target) and not u.order_target.dead:
			continue          # (already on a gun or its guard: no switching back and forth)
		u.cmd_attack(best)
	return sent
