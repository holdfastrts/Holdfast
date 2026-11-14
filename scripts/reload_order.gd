class_name ReloadOrder
extends RefCounted
## RELOAD (the owner, 2026-11-13 23:59: "for every gunpowder unit we should have a command to reload / grab powder, meaning
## if the unit is 5/10 we give the command and it goes to the powder wagon or any powder source and gets to 10/10";
## docs/reload_command.md). A command on the card of every unit whose firearm uses powder (Unit.ammo_weapon: Musketeers,
## Guardsmen, Dragoons, Horsemen, Cuirassiers, Officers, Field Cannons, Mortars), shown while any selected one is below a
## full load. Each one:
##  1. picks the NEAREST powder source that can fill it NOW (by walking: the few nearest in a line are pathed and the
##     shortest walk wins): a Powder Mill, Barracks (ARM WITH POWDER on) or Town Hall while the bank holds a shot's powder,
##     a Powder Wagon or a dropped keg holding a shot (Unit._take_shots is where the shots come from);
##  2. walks there (a crowd spreads round the source: each new one takes the next place on a ring) and stands until full;
##     the refill itself is the usual one (Unit._powder_tick): nothing new is paid or given here;
##  3. if the source runs dry (nothing came in for DRY_T s) it tries the next one; none left: it stops with a message;
##  4. full, it walks BACK to where it was when the reload began (Claude's choice: a reload in battle is a trip to the
##     wagon behind the line and back), then on to its Shift-queued orders.
## The order is {"o": "reload"} through Unit.give (plain or Shift-queued), so it goes online (NetCommands "give") and into
## replays like any other order; Unit.rl keeps the trip (back, sources found dry, the clock), saved as "rld".

const DRY_T := 3.0           # (s) standing in reach and no shot came in: that source is dry
const TRIP_T := 120.0        # (s) at most this long on the trip there (a source it can't reach: it gives up)
const BACK_MIN := 40.0       # (px) nearer than this to where it started: no walk back
const PATH_TRIES := 3        # the sources nearest in a line that are pathed to find the nearest by walking
const PATH_SPAN := 1.6       # ... only those within this many times the nearest's distance in a line
const RING_GAP := 22.0       # (px) between two men round a source


## Has a firearm that uses powder and is below a full load (and can go: not riding in a basket, not off the field).
static func wants(u: Unit) -> bool:
	if u == null or u.dead or u.off_field or u.aboard != null:
		return false
	return u.ammo_weapon() != "" and u.ammo_max() > 0 and u.ammo_shots() < u.ammo_max()


## Powder a shot costs this unit (Defs.POWDER "cost"; a cannon's shot is dearer).
static func _cost(u: Unit) -> float:
	return float(Defs.POWDER["cost"].get(u.kind, 1.0))


## `src` can give this unit a shot now.
static func can_fill(u: Unit, src) -> bool:
	if src == null or not is_instance_valid(src) or src.dead or src.team != u.team:
		return false
	var per := _cost(u) / float(Defs.POWDER["cost"]["musketeer"])
	if src is Building:
		var b := src as Building
		if not b.built or not (Defs.POWDER["from"] as Array).has(b.kind) or (b.kind == "barracks" and not b.arm_powder):
			return false
		return float(u.game.players[u.team]["res2"]) >= _cost(u)
	if src is Unit:
		var w := src as Unit
		return w.kind == "powder_wagon" and not w.off_field and w.aboard == null and w.powder >= per
	if src is PowderKeg:
		return (src as PowderKeg).powder >= per * 0.999
	return false


static func _spot(src) -> Vector2:
	return (src as Building).center() if src is Building else (src as Node2D).position


## Every source that can fill `u` now, but those in `skip`.
static func sources(u: Unit, skip: Array = []) -> Array:
	var g: Game = u.game
	var out: Array = []
	for b in g.buildings:
		if not skip.has(b) and can_fill(u, b):
			out.append(b)
	for o in g.units:
		if o.kind == "powder_wagon" and not skip.has(o) and can_fill(u, o):
			out.append(o)
	for k in g.kegs:
		if not skip.has(k) and can_fill(u, k):
			out.append(k)
	return out


## The nearest source by walking (the PATH_TRIES nearest in a line are pathed; one already in reach wins at once); null: none.
static func nearest(u: Unit, skip: Array = []) -> Variant:
	var all := sources(u, skip)
	if all.is_empty():
		return null
	for s in all:
		if _in_reach(u, s):
			return s
	all.sort_custom(func(a, b) -> bool: return _spot(a).distance_squared_to(u.position) < _spot(b).distance_squared_to(u.position))
	if u.is_air():
		return all[0]
	# (only the ones not much farther in a line than the nearest are worth a path: a button press may send a hundred)
	var d0 := _spot(all[0]).distance_to(u.position)
	var tries: Array = all.slice(0, PATH_TRIES).filter(func(s) -> bool: return _spot(s).distance_to(u.position) <= d0 * PATH_SPAN + 64.0)
	if tries.size() <= 1:
		return all[0]
	var best = null
	var bd := INF
	for s in tries:
		var to: Vector2 = u.game.approach_point(s, u.position) if s is Building else _spot(s)
		var p := u.game.find_path(u.position, to, false, u._path_margin(), u.team)
		if p.is_empty():
			continue
		var l := u.position.distance_to(p[0])
		for j in range(1, p.size()):
			l += p[j - 1].distance_to(p[j])
		l += p[p.size() - 1].distance_to(to)
		if l < bd:
			bd = l
			best = s
	return best if best != null else all[0]


## Close enough to `src` for Unit._take_shots to take from it.
static func _in_reach(u: Unit, src) -> bool:
	var reach := float(Defs.POWDER["range"]) * Defs.TILE
	if src is Building:
		return (src as Building).edge_distance(u.position) < reach
	return (src as Node2D).position.distance_to(u.position) < reach + 16.0


## Where `u` stands by `src`: the side facing it, the next free place on a ring round it (the others already on their way).
static func stand_point(u: Unit, src) -> Vector2:
	var c := _spot(src)
	var r := 30.0
	if src is Building:
		var b := src as Building
		r = float(maxi(b.size.x, b.size.y)) * Defs.TILE * 0.5 + 20.0
	var n := 0
	var base := u.position - c
	for o in u.game.units:
		if o != u and o.team == u.team and not o.dead and o.order == "reload" and o.order_target == src:
			if n == 0 and o.rl.get("dir") is Vector2:
				base = o.rl["dir"]          # (the crowd's places all go round from the first one's side)
			n += 1
	var ring := n / 8
	r += float(ring) * RING_GAP
	var step := RING_GAP / r
	var k := n % 8
	var off := float((k + 1) / 2) * step * (1.0 if k % 2 == 1 else -1.0)
	var dir := base
	if dir.length() < 1.0:
		dir = Vector2.DOWN
	if not u.rl.is_empty():
		u.rl["dir"] = dir
	var p := c + dir.normalized().rotated(off) * r
	return u.game.on_map(p)


## Give the order (Unit._start "reload"): false when it is full or nothing can fill it (the order it had stays).
## `back`: where it returns afterwards (INF: where it stands now).
static func start(u: Unit, back := Vector2.INF) -> bool:
	if not wants(u):
		return false
	if not u.can_roll():
		return false            # (a gun with no horse can't go: a hauler brings it a keg, Unit.needs_keg)
	var src = nearest(u)
	if src == null:
		return false
	u._reset_work()
	u.order = "reload"
	u.order_target = src
	u.target = null
	u.rl = {"back": u.position if back == Vector2.INF else back, "skip": [], "wait": 0.0, "t": 0.0}
	u.order_point = stand_point(u, src)
	u.repath_t = 1.5
	u.path = PackedVector2Array()
	if not _in_reach(u, src):
		u._request_path(u.order_point)
	return true


## The order's step (Unit's order match): where it wants to go.
static func tick(u: Unit, delta: float) -> Vector2:
	if u.rl.is_empty():
		u.rl = {"back": u.position, "skip": [], "wait": 0.0, "t": 0.0}
	if u.ammo_shots() >= u.ammo_max():
		_finish(u)
		return Vector2.ZERO
	var src = u.order_target
	u.rl["t"] = float(u.rl["t"]) + delta
	if not can_fill(u, src) or float(u.rl["wait"]) > DRY_T:
		_next_source(u, src)
		return Vector2.ZERO
	if _in_reach(u, src):
		u.path = PackedVector2Array()
		if u.refilling():
			u.rl["wait"] = 0.0
		else:
			u.rl["wait"] = float(u.rl["wait"]) + delta
		return Vector2.ZERO
	u.rl["wait"] = 0.0
	if float(u.rl["t"]) > TRIP_T:
		u.game.tell(u.team, "Couldn't reach the powder: stopped.")
		_end(u)
		return Vector2.ZERO
	if u.deploys() and u.tesla_mode != "packed":
		if u.tesla_mode == "deployed":
			u.cmd_pack()        # (a gun limbers up to go)
		return Vector2.ZERO
	if src is Unit and u.repath_t <= 0.0:
		u.order_point = stand_point(u, src)       # (a wagon may roll on: follow it)
	return u._walk_to(u.order_point, delta)


## That source can't fill it: the next nearest, or stop with a message.
static func _next_source(u: Unit, dry) -> void:
	var skip: Array = u.rl["skip"]
	if dry != null and not skip.has(dry):
		skip.append(dry)
	var src = nearest(u, skip)
	if src == null:
		u.game.tell(u.team, "No more powder to reload from: the bank and the wagons are empty.")
		_end(u)
		return
	u.order_target = src
	u.order_point = stand_point(u, src)
	u.rl["wait"] = 0.0
	u.path = PackedVector2Array()
	if not _in_reach(u, src):
		u._request_path(u.order_point)


## Full: back where it was, then on to the queued orders.
static func _finish(u: Unit) -> void:
	var back: Vector2 = u.rl.get("back", Vector2.INF)
	u.rl = {}
	if back != Vector2.INF and u.position.distance_to(back) > BACK_MIN and u.can_roll():
		u._keep_queue = true
		u.cmd_move(back)
		u._keep_queue = false
		if u.order == "move":
			return
	_end(u)


## Stop where it stands (the queue goes on).
static func _end(u: Unit) -> void:
	u.rl = {}
	u.order = "idle"
	u.order_target = null
	u.target = null
	u.path = PackedVector2Array()
	u.leash_from = u.position
	if not u.queue.is_empty():
		u._next_order()


# ------------------------------------------------------------------ the command card

## RELOAD on the card (HUD._ability_buttons): every selected unit below a full load goes (Shift: after its orders).
static func card(hud, list: Array, units: Array) -> void:
	var guns := units.filter(func(u: Unit) -> bool: return u.team == hud.game.human and u.ammo_weapon() != "" and u.ammo_max() > 0)
	if guns.is_empty():
		return
	var low := guns.filter(func(u: Unit) -> bool: return wants(u))
	var have := 0
	var full := 0
	for u in guns:
		have += u.ammo_shots()
		full += u.ammo_max()
	var src = null
	if not low.is_empty():
		src = nearest_in_line(low[0])
	var where := Loc.t("No powder to reload from now.") if src == null else Loc.t("Nearest powder: %s.") % Loc.t(source_name(src))
	hud._tip_for["RELOAD"] = ["Reload", Loc.t("Each one below a full load walks to the nearest powder that can fill it now (a Powder Wagon, a keg, or a Mill, Barracks or Town Hall while the bank has powder), stays until full, then walks back to where it was. Shift: after its other orders.") + " " + where,
		"%d/%d" % [have, full]]
	list.append(["ab_reload", "RELOAD", func() -> void:
		var q: bool = Settings.pc() and Input.is_key_pressed(KEY_SHIFT)
		var sent := 0
		for u in hud.game.selected_units():
			if wants(u) and u.team == hud.game.human and (q or sources(u).size() > 0):
				u.give({"o": "reload"}, q)
				sent += 1
		if sent > 0:
			hud.toast("Off to reload: they come back once full.")
		else:
			hud.toast("No Powder Wagon, keg, or Mill, Barracks or Town Hall with powder to reload from."),
		not low.is_empty(), "They are all full.", "%d/%d" % [have, full]])


## The nearest source in a line (the card's tooltip: no pathing every frame).
static func nearest_in_line(u: Unit) -> Variant:
	var best = null
	var bd := INF
	for s in sources(u):
		var dd := _spot(s).distance_squared_to(u.position)
		if dd < bd:
			bd = dd
			best = s
	return best


static func source_name(src) -> String:
	if src is PowderKeg:
		return "a powder keg"
	if src is Unit:
		return "the Powder Wagon"
	match (src as Building).kind:
		"powder_mill":
			return "the Powder Mill"
		"barracks":
			return "the Barracks"
	return "the Town Hall"
