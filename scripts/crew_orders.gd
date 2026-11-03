class_name CrewOrders
extends RefCounted
## + WORKER / - WORKER on a crewed building's card (the owner's playtest, 2026-11-03: "In the mobile version there is
## no way to take workers from farms and put them in powder mills"). One press moves one worker, on the phone and
## the computer alike (Game.crew_order, sent to the host online):
##  + WORKER: the nearest worker from the least important job comes to work here: an idle one first, then one off a
##    Farm (a Cog Press), then one off another post of the same kind or a higher tier (Defs.CREW_TIER), haulers last.
##    Builders, repairers, men leading horses or carrying a crate are never taken.
##  - WORKER: one of its crew goes to another post with room (a different kind first, then the nearest; a Town Hall's
##    hauling last). Never made idle: WORK (Unit.auto_work) would only send him straight back here.
## The phone's other way: with workers selected, a TAP on one of your finished crewed buildings sends them to work it
## (Controls._tap; the computer's right click does the same).

## Rank of the job a worker is taken from (lower is taken first); -1: not to be taken.
static func _rank(u: Unit, b: Building) -> int:
	if u.order == "idle":
		return 0
	if u.order != "gather" or not (u.home_mine is Building) or u.home_mine == b:
		return -1
	var hb := u.home_mine as Building
	if hb.dead:
		return 0
	if hb.haul_cap() > 0:
		return 5 if u.haul_job.is_empty() else 6       # (haulers last: one with a job in hand after one without)
	if hb.barren():
		return 1          # (spent land: he earns nothing there)
	return 2 + int(Defs.CREW_TIER.get(hb.kind, 0)) + (1 if hb.kind == b.kind else 0)


## Can worker u work at b at all?
static func _fits(u: Unit, b: Building) -> bool:
	if u.dead or u.off_field or u.aboard != null or u.team != b.team or not u.can_gather() or u.kind == "grub":
		return false
	if not u.led.is_empty() or u.crate_site != null:
		return false
	if b.haul_cap() > 0:
		return u.can_haul()
	return true


## The worker + WORKER takes for b, or null.
static func pick_for(g: Game, b: Building) -> Unit:
	var best: Unit = null
	var br := 99
	var bd := INF
	for u in g.units:
		if u.team != b.team or b.crew.has(u) or not _fits(u, b):
			continue
		var r := _rank(u, b)
		if r < 0:
			continue
		var dd: float = u.position.distance_squared_to(b.center())
		if r < br or (r == br and dd < bd):
			br = r
			bd = dd
			best = u
	return best


## Where - WORKER sends a man of b's crew (another post with room), or null.
static func post_for(g: Game, b: Building, u: Unit) -> Building:
	var best: Building = null
	var bs := INF
	for o in g.buildings:
		if o == b or o.team != b.team or o.dead or not o.built or o.crew_max() <= 0 or o.crew.size() >= o.crew_max():
			continue
		if o.barren():
			continue
		if o.haul_cap() > 0 and not u.can_haul():
			continue
		var s: float = o.center().distance_to(u.position)
		if o.haul_cap() > 0:
			s += 100000.0        # (hauling only when nothing else has room)
		elif o.kind == b.kind:
			s += 50000.0         # (a different job first: a Mill's man goes to a Farm)
		if s < bs:
			bs = s
			best = o
	return best


## The man of b's crew - WORKER moves: one not in the middle of a haul, else the last to come.
static func leaver(b: Building) -> Unit:
	var men: Array = b.crew.filter(func(x) -> bool: return is_instance_valid(x) and not x.dead and not x.off_field)
	if men.is_empty():
		return null
	for i in range(men.size() - 1, -1, -1):
		var m: Unit = men[i]
		if m.haul_job.is_empty():
			return m
	return men[men.size() - 1]


## Why + WORKER (add) or - WORKER can't be pressed for b now ("" = it can).
static func problem(g: Game, b: Building, add: bool) -> String:
	if b == null or b.dead or not b.built or b.crew_max() <= 0:
		return "It takes no workers."
	if add:
		if b.crew.size() >= b.crew_max():
			return "It has all its workers."
		if b.barren():
			return "Its ground is spent: work fresh land."
		if pick_for(g, b) == null:
			return "No worker to spare: train more."
		return ""
	var m := leaver(b)
	if m == null:
		return "Nobody works here."
	if post_for(g, b, m) == null:
		return "No other work with room for him."
	return ""


## Do it (on the host / single player). "" or why not.
static func order(g: Game, b: Building, add: bool) -> String:
	var why := problem(g, b, add)
	if why != "":
		return why
	if add:
		var u := pick_for(g, b)
		u.cmd_gather(b)
		if u.home_mine != b:
			return "It has all its workers."
		return ""
	var m := leaver(b)
	var to := post_for(g, b, m)
	m.cmd_gather(to)
	return ""
