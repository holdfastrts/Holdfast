class_name WinderWalk
extends RefCounted
## WINDING ON THE MARCH (the owner's idea, 2026-11-01; docs/winder_walk.md): a Winder winds a Clockwork soldier that is
## WALKING from just behind it, both walking, at the soldier's pace; its charge fills at the normal rate (as a standing
## wind: 0.15 a second); then he goes to the next one of the march that needs it, and once none does, back to his own
## order (his move, attack-move or follow), so he keeps up with the army.
## - By hand: REPAIR (right-click) on a walking construct. When it stops he winds it standing, as before.
## - By itself (his REPAIR autocast, on by default): a Winder on a move, attack-move or follow order looks every RESCAN s
##   for a walking construct of his side within SCAN tiles, going his way, with less than LOW charge and not as fast as
##   he is, that no other Winder is winding; the lowest charge first. The computer's Winders do the same (the unit rule).
## - Pace: he matches its speed from GAP px behind it (its own velocity plus a pull to the spot behind it). If it is
##   faster than he is (only by hand: the auto pick leaves those), the pair goes at his pace while he winds it
##   (Unit._ww_cap); a unit in a fight is never slowed. A soldier slower than him is never slowed.
## - His own spring: he winds it walking too (Unit.self_wind_t no longer stops him while _ww_on).
## Only the host runs this; a guest sees it through the streamed `work` ("repairing") and the walking: the Winder's
## WALK_WIND strip (assets/units/winder/walk_wind_*, built in code by tools/winder_guide/walk_wind.py).

const LOW := 0.8            # the auto pick: a walking construct below this charge
const SCAN := 6.0           # tiles: how far round him he looks
const RESCAN := 1.0         # s between two looks
const GAP := 4.0            # px between the soldier's back and him
const SLACK := 12.0         # px more than a standing repair's reach (radius + 20) that still winds on the move
const MOVING := 10.0        # px/s: walking (Unit._anim_name's `moving`)
const PULL := 3.0           # 1/s: how hard he closes on the spot behind it


## Is `e` walking (a construct the Winder winds on the move)? Flyers are not followed (a Winder can't follow them).
static func walking(e: Unit) -> bool:
	return e.velocity.length() > MOVING and not e.is_air() and not e.dead


## One tick of the Winder `u` winding the walking `e`: walk behind it at its pace, wind it while in reach.
static func tick(u: Unit, e: Unit, delta: float) -> Vector2:
	u._ww_on = true
	var dir := e.velocity.normalized()
	var goal := e.position - dir * (e.radius + u.radius + GAP)
	var reach := e.edge_distance(u.position) < u.radius + 20.0 + SLACK
	var far := u.position.distance_to(goal) > 140.0
	if reach:
		u.work = "repairing"
		u.path = PackedVector2Array()
		if not u._repair_step(e, delta):
			return Vector2.ZERO        # (out of cogs: he has stopped)
		if u.speed < e.speed and e.target == null:
			e._ww_cap = u.speed        # (a faster unit: the pair goes at his pace while he winds it)
			e._ww_cap_t = 0.25
	else:
		u.work = ""
	if far:
		return u._walk_to(goal, delta)
	var want := e.velocity + (goal - u.position) * PULL
	if want.length() > u.speed:
		want = want.normalized() * u.speed
	if want.length() < MOVING * 0.5 and reach:
		u.facing = (e.position - u.position).normalized()
	return want


## His REPAIR autocast on the march: the walking construct near him that needs it most, and off he goes to wind it,
## keeping his order to go back to.
static func auto(u: Unit, delta: float) -> void:
	u._ww_scan -= delta
	if u._ww_scan > 0.0:
		return
	u._ww_scan = RESCAN
	if u.target != null or u.crate_site != null or u.self_wind_t > 0.0 or u.game.players[u.team]["gold"] < 1:
		return
	var c := pick(u)
	if c == null:
		return
	var back := {"o": u.order, "p": u.order_point, "t": u.order_target, "q": u.queue.duplicate()}
	u.cmd_repair(c)
	u._ww_back = back


## The walking construct near `u` that he should wind next (null: none).
static func pick(u: Unit) -> Unit:
	var near: Array = u.game.units_near(u.position, SCAN * Defs.TILE)
	var taken := {}
	for w in near:
		if w != u and w.kind == "winder" and w.team == u.team and w.order == "repair" and is_instance_valid(w.order_target):
			taken[w.order_target] = true
	var my_speed := float(u.d["speed"])
	var my_dir := u.velocity.normalized() if u.velocity.length() > MOVING else Vector2.ZERO
	var best: Unit = null
	var bs := INF
	for o in near:
		if o.team != u.team or o.dead or o.off_field or not o.has_charge() or taken.has(o) or o.aboard != null:
			continue
		if o.wind >= LOW or o._in_field or o.overclock_t > 0.0 or not walking(o):
			continue
		if float(o.d["speed"]) > my_speed + 0.5:
			continue           # (it would leave him behind)
		if my_dir != Vector2.ZERO and o.velocity.normalized().dot(my_dir) < 0.3:
			continue           # (not going his way: not his march)
		var s: float = o.wind * 1000.0 + o.position.distance_to(u.position) * 0.5
		if s < bs:
			bs = s
			best = o
	return best


## The one he wound is done: the next walking one near him, else back to his own order. False: nothing to do (he stops).
static func go_on(u: Unit) -> bool:
	var back: Dictionary = u._ww_back
	var nx := pick(u) if u.game.players[u.team]["gold"] >= 1 else null
	if nx != null:
		u.cmd_repair(nx)
		u._ww_back = back
		return true
	if back.is_empty():
		return false
	var o := String(back["o"])
	var t = back["t"]
	if o == "follow" and t != null and is_instance_valid(t) and not t.dead:
		u.cmd_follow(t)
	elif o == "move" or o == "amove":
		u.cmd_move(back["p"], o == "amove")
	else:
		return false
	u.queue = (back["q"] as Array).duplicate()
	u._ww_scan = RESCAN
	return true
