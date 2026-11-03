class_name AICrownSiege
extends RefCounted
## THE SIEGE PUSH (crown-builds-b, docs/crown_builds_b.md): the Crown computer's "siege" plan. Field Cannons and Mortars
## behind a line of Musketeers, sent out to break a defended position: a Clockwork base with Ratchet Turrets and Winders
## that mend it, or a Brood nest of rooted creatures (Rootmaws, Mound Turtles, the Brood Mother). AICrown (scripts/ai_crown.gd)
## owns it (`siege`) and calls it from its think; everything here is the push itself:
##  - GO: the guns (GUNS_GO, at least one cannon) and the line (LINE_GO Musketeers) at home, the army worth the enemy army it
##    knows (EDGE / EDGE_BROOD), nothing at our buildings; never into a bigger army (the doctrine), at most every COOL s.
##  - MARCH: the line goes first on attack-move; the guns follow LIMBERED on the line's trail (GUN_TRAIL px behind it); the
##    line waits while the guns lag (GUN_LAG); the Powder Wagon follows far behind (WAGON_TRAIL), never among the men (its
##    blast kills friends: docs/ai_crown_rebuild.md round B).
##  - SET UP (contact: a defence within STOP_D of the line, or an enemy force on it): the line stands on HOLD in a row
##    LINE_D in front of the target (out of a turret's reach), the guns unlimber behind it (cannon CANNON_D, mortar MORTAR_D
##    from the target, both inside their range and out of the turrets'), the wagon WAGON_BACK behind the guns.
##  - WHAT THE GUNS SHOOT FIRST (_pick): turrets, the workers mending (Winders, Labourers), rooted creatures and fathers,
##    enemy guns and engines, the enemy army near the line (a cannon switches to CANISTER when it closes), walls and gates
##    in the way, then any building. A gun out of shot walks back to the wagon and returns.
##  - ON: when nothing is left within reach, the push marches on to the next defence it knows, then the enemy's hall.
##  - BACK: the push is lost (under RETREAT_K of what went out, a bigger enemy army on it, the guns gone) or the base is in
##    danger: the guns limber and go home first, the line covers, then everyone is the shared computer's again.
## Reinforcements from home join in groups of JOIN_SUP supply. Nothing here changes a unit's numbers (no balance change).

const GUNS := ["cannon", "mortar"]
const GUNS_GO := 3              # guns at home before the push (at least one Field Cannon)
const LINE_GO := 10             # Musketeers (or Guardsmen) at home before the push
const BIG_GO := 50              # (supply) a push this big goes whatever the guns
const EDGE := 0.75              # the push worth this many times the enemy army it knows (the guns outrange its defence, and the
                                # line sets up: the enemy must come to it; 0.9 kept it home till 11:00-12:00 in round A)
const EDGE_BROOD := 1.5         # (the Brood's swarm comes at the guns in the open: AICrown.CR_EDGE_BROOD; 1.2 lost a08 Greenhold)
const QUIET := 60.0             # (s) nothing at our buildings this long before a push goes (a08: out 28 s after 41 Raptors left)
const GUN_WEIGHT := 1.5         # a gun counts this many times its price for the push's worth (it outranges the defence)
const COOL := 60.0              # (s) after a push came back
const STOP_D := 330.0           # (px) a defence this near the line: set up
const ARMY_STOP_D := 360.0      # (px) an enemy force this near the line, worth ARMY_STOP of ours: set up and fight it there
const ARMY_STOP := 0.3
const LINE_D := 245.0           # (px) the line stands this far in front of the target (a turret reaches 200)
const LINE_D_BROOD := 190.0     # (rooted creatures bite at 22-50 px: closer, so the line covers the guns)
const CANNON_D := 385.0         # (px) a cannon unlimbers this far from its target (range 430)
const MORTAR_D := 300.0         # (px) a mortar (range 352, least 160)
const WAGON_BACK := 150.0       # (px) the wagon behind the guns
const GUN_TRAIL := 150.0        # (px) the guns behind the line on the march
const WAGON_TRAIL := 330.0
const GUN_LAG := 260.0          # (px) the line waits while its guns are this far behind
const CANISTER_R := 170.0       # (px) an enemy this near a cannon: canister
const RETREAT_K := 0.45         # the push is lost under this share of what went out ...
const RETREAT_FOE := 1.4        # ... or the enemy near it is worth this many times it while it is under 0.75 of what went out
const JOIN_SUP := 6
const REACH := 470.0            # (px) a target this far from a gun's spot is out of its reach (re-anchor)

var ai                          # the AICrown
var game: Game
var state := ""                 # "" home, "march", "set", "back"
var men := {}                   # unit -> true: the push
var trail: Array = []           # the line's middle, a point every TRAIL_STEP px of the way (newest last)
var anchor = null               # the target set up against (Building or Unit)
var anchor_p := Vector2.INF
var v0 := 0.0                   # what went out (grows with reinforcements)
var t0 := 0.0
var _next_go := 0.0
var _threat_t := -999.0         # the last time an enemy was at our buildings (seen while at home)
var _orders_t := 0.0
var _pick_t := {}               # gun -> clock of its last pick
var _back_t := 0.0
var _set_t := 0.0
var pushes: Array = []          # one dict a push: t0, sup, guns, line, value, kills (kind -> n), end, why, lost, killed
var cur := {}                   # the push going on
var log: Array = []             # [clock, text] (the coach and the tests read it)
var _kill_base := 0
var _loss_base := 0
const TRAIL_STEP := 40.0


func _init(a) -> void:
	ai = a
	game = a.game


func say(s: String) -> void:
	log.append([game.clock, s])
	if game.mlog:
		game.mlog.add("%s's siege push: %s" % [game.mlog.who(ai.team), s])


func has(u: Unit) -> bool:
	return men.has(u)


func active() -> bool:
	return state != ""


func _alive(u) -> bool:
	return u != null and is_instance_valid(u) and not u.dead


func _brood() -> bool:
	return ai._foe_is("brood")


# ------------------------------------------------------------------ the think

func tick() -> void:
	for u in men.keys():
		if not _alive(u) or u.off_field:
			men.erase(u)
	if state == "":
		_maybe_go()
		return
	var line := _line()
	var guns := _guns()
	if line.is_empty() and guns.is_empty():
		_end("the push is gone")
		return
	var mid := _core_mid(line if not line.is_empty() else guns)
	_crumb(mid)
	_watch_broke(mid)
	if state == "back":
		_back(mid)
		return
	_join()
	var why := _lost(mid)
	if why != "":
		_retreat(why)
		return
	if state == "march":
		_march(line, guns, mid)
	elif state == "set":
		_siege_set(line, guns, mid)
	_tend_wagon(guns, mid)


## WHAT THE PUSH BROKE: every enemy building and rooted creature it came within BROKE_R of while out, that died since.
const BROKE_R := 520.0
var _near := {}


func _watch_broke(mid: Vector2) -> void:
	for e in _near.keys():
		if not is_instance_valid(e) or e.dead:
			var k: String = String(_near[e])
			cur["broke"][k] = int(cur["broke"].get(k, 0)) + 1
			_near.erase(e)
	for b in _known_buildings():
		if b.edge_distance(mid) < BROKE_R and b.built:
			_near[b] = b.kind
	for u in _visible_foes(mid, BROKE_R):
		if _static_target(u):
			_near[u] = u.kind


## The units at home that may go: not raiding, scouting, harassing, nor on another errand.
func _home_army() -> Array:
	return game.army(ai.team).filter(func(u: Unit) -> bool:
		return not men.has(u) and not u.dead and not u.off_field and u.has_attack() and u.kind != "powder_wagon" and not u.is_air() \
			and not ai._raiders.has(u) and not ai._on_errand(u) and not (ai.harass != null and ai.harass.has(u)) and u.order != "mount" \
			and not ai._horse_coming(u) and not u.is_worker())


func _maybe_go() -> void:
	if game.clock < _next_go or ai.peaceful or ai._foe() < 0:
		return
	_next_go = game.clock + 2.0
	var home := _home_army()
	var guns := home.filter(func(u: Unit) -> bool: return GUNS.has(u.kind))
	var cannons := guns.filter(func(u: Unit) -> bool: return u.kind == "cannon").size()
	var muskets := home.filter(func(u: Unit) -> bool: return Defs.MUSKETS.has(u.kind)).size()
	var sup: int = ai._army_supply(home)
	var big := sup >= BIG_GO or game.supply_used(ai.team) >= game.max_supply(ai.team) - 4
	if not big and (guns.size() < GUNS_GO or cannons < 1 or muskets < LINE_GO):
		return
	var mine := 0.0
	for u in home:
		mine += float(Game.unit_value(u)) * (GUN_WEIGHT if GUNS.has(u.kind) else 1.0)
	# an enemy force at our buildings (not a lone scout or a raider the guards see off): the push stays, and QUIET s after
	var near: float = ai.ch.foe_near()
	if ai._threat() != Vector2.INF and near >= THREAT_MIN:
		_threat_t = game.clock
		_stay("an enemy force (%d) is at our buildings" % int(near))
		return
	if game.clock - _threat_t < QUIET:
		_stay("an enemy force was at our buildings %d s ago" % int(game.clock - _threat_t))
		return
	var known: float = ai.ch.foe_known()
	var edge := EDGE_BROOD if _brood() else EDGE
	if known > 0.0 and mine < known * edge and not big:
		if game.clock - _stay_t > 60.0:
			_stay_t = game.clock
			say("waits: %d of army against the %d it knows (it wants %.1f times)" % [int(mine), int(known), edge])
		return
	_go(home, mine)


const THREAT_MIN := 250.0       # (value) an enemy force this big seen on our side keeps the push home
var _stay_t := -99.0


func _stay(why: String) -> void:
	if game.clock - _stay_t > 60.0:
		_stay_t = game.clock
		say("stays home: " + why)


func _go(home: Array, value: float) -> void:
	men.clear()
	for u in home:
		men[u] = true
	state = "march"
	t0 = game.clock
	v0 = value
	trail.clear()
	anchor = null
	anchor_p = Vector2.INF
	var st: Dictionary = game.stats[ai.team]
	_kill_base = int(st["value_killed"])
	var fe: int = ai._foe()
	_loss_base = int(game.stats[fe]["value_killed"]) if fe >= 0 else 0
	var g := home.filter(func(u: Unit) -> bool: return GUNS.has(u.kind))
	cur = {"t0": game.clock, "sup": ai._army_supply(home), "value": int(value), "guns": g.size(),
		"cannons": g.filter(func(u: Unit) -> bool: return u.kind == "cannon").size(),
		"line": home.size() - g.size(), "broke": {}, "end": -1.0, "why": "", "sets": 0}
	pushes.append(cur)
	say("goes out: %d supply (%d guns, %d in the line), worth %d" % [cur["sup"], g.size(), home.size() - g.size(), int(value)])
	_orders_t = 0.0


func _line() -> Array:
	return men.keys().filter(func(u: Unit) -> bool: return not GUNS.has(u.kind))


func _guns() -> Array:
	return men.keys().filter(func(u: Unit) -> bool: return GUNS.has(u.kind))


func _mid(list: Array) -> Vector2:
	var s := Vector2.ZERO
	for u in list:
		s += u.position
	return s / maxf(1.0, float(list.size()))


func _value(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += float(Game.unit_value(u))
	return v


## The middle of the push's MAIN BODY: the units within CORE_R of the one with the most of them near it (nearest the enemy
## on a tie). The reinforcements walking out from home are part of the push, and with them in the middle the push never
## "saw" the Clocktower its front stood in (round C, d01 Greenhold 11:29: the line walked into the gear ring).
const CORE_R := 300.0


func _core_mid(list: Array) -> Vector2:
	if list.is_empty():
		return ai._front()
	var goal: Vector2 = anchor_p if anchor_p != Vector2.INF else ai._enemy_base()
	var best: Unit = null
	var bs := -INF
	for u in list:
		var n := 0
		for o in list:
			if u.position.distance_squared_to(o.position) < CORE_R * CORE_R:
				n += 1
		var sc: float = float(n) * 10000.0 - u.position.distance_to(goal)
		if sc > bs:
			bs = sc
			best = u
	return _mid(list.filter(func(u: Unit) -> bool: return u.position.distance_to(best.position) < CORE_R))


func _crumb(mid: Vector2) -> void:
	if trail.is_empty() or (trail[-1] as Vector2).distance_to(mid) >= TRAIL_STEP:
		trail.append(mid)
		if trail.size() > 60:
			trail.pop_front()


## The point of the line's trail `back` px behind its newest point (where the line walked: never over a cliff).
func _behind(back: float) -> Vector2:
	if trail.is_empty():
		return ai._front()
	var left := back
	var i := trail.size() - 1
	while i > 0:
		var seg: float = (trail[i] as Vector2).distance_to(trail[i - 1])
		if seg >= left:
			return (trail[i] as Vector2).lerp(trail[i - 1], left / maxf(1.0, seg))
		left -= seg
		i -= 1
	return trail[0]


## Reinforcements: units trained since at home go out as a group (never one by one).
func _join() -> void:
	if ai._threat() != Vector2.INF:
		return
	var home := _home_army()
	if ai._army_supply(home) < JOIN_SUP:
		return
	var to := _behind(GUN_TRAIL * 0.5)
	for u in home:
		men[u] = true
		v0 += float(Game.unit_value(u))
		u.cmd_move(to + Vector2(randf_range(-40, 40), randf_range(-40, 40)), not GUNS.has(u.kind))
	say("%d supply joins it" % ai._army_supply(home))


# ------------------------------------------------------------------ targets

## An enemy thing a push sets up against: a building we have seen, a rooted creature, a turret; or the enemy army on us.
func _static_target(e) -> bool:
	if e is Building:
		return not e.dead and not e.ghost
	if e is Unit:
		return not e.dead and (BroodNew.rooted(e) or BroodNew.FATHERS.has(e.kind) and e.tesla_mode == "deployed")
	return false


func _known_buildings() -> Array:
	var out: Array = []
	var fe: int = ai._foe()
	for b in game.buildings:
		if b.dead or b.ghost or not game.hostile(b.team, ai.team):
			continue
		if ai.scout != null and (ai.scout._seen_b.has(b) or game.is_visible_to(ai.team, b.center())):
			out.append(b)
		elif b.team == fe and b.kind == game.faction_hall(fe):
			out.append(b)        # (the shared computer goes for the enemy's halls by what it knows of the map: _enemy_base)
	return out


func _visible_foes(p: Vector2, r: float) -> Array:
	var out: Array = []
	for u in game.units_near(p, r):
		if not u.dead and not u.off_field and game.hostile(u.team, ai.team) and game.is_visible_to(ai.team, u.position):
			out.append(u)
	return out


## How much a gun wants to shoot `e` (0: not at all).
func _score(gun: Unit, e) -> float:
	if e is Building:
		var b: Building = e
		if b.kind == Defs.CW_TURRET:
			return 10.0
		if b.kind == "wall" or b.kind == "gate":
			return 4.0
		if b.d.get("trains", []).size() > 0 or b.kind == game.faction_hall(b.team):
			return 3.0
		return 2.0
	var u: Unit = e
	if u.is_worker():
		return 9.0 if u.order in ["repair", "build"] else (2.5 if gun.kind == "cannon" else 0.0)
	if BroodNew.rooted(u) or (BroodNew.FATHERS.has(u.kind) and u.tesla_mode == "deployed"):
		return 8.0 if u.kind != BroodNew.QUEEN else 7.5
	if gun.kind == "mortar":
		return 5.0 if u.speed < 45.0 else 0.0       # (a shell takes long to fall: slow and still things only)
	if GUNS.has(u.kind) or u.kind in ["steam_walker", "stormcaller", "tesla_cart", "great_winder", Defs.CW_HEAVY]:
		return 7.0
	return 6.0


func _pick(gun: Unit, from: Vector2) -> Variant:
	var rng := float(gun.d["range"]) + 30.0
	var best = null
	var bs := 0.0
	for e in _visible_foes(from, rng):
		if e.is_air():
			continue
		if not _static_target(e) and not game.aoe_worth_it(gun, e):
			continue          # (our own men in the ball's path or the shell's burst: AI never orders that)
		var s := _score(gun, e) - from.distance_to(e.position) / 400.0
		if s > bs:
			bs = s
			best = e
	for b in _known_buildings():
		if b.edge_distance(from) > rng:
			continue
		var s := _score(gun, b) - from.distance_to(b.center()) / 400.0
		if s > bs:
			bs = s
			best = b
	return best


func _pos(e) -> Vector2:
	return e.center() if e is Building else e.position


## The next thing to set up against, nearest the line: a known defence or building within `r`.
func _next_anchor(mid: Vector2, r: float) -> Variant:
	var best = null
	var bd := r
	for b in _known_buildings():
		var dd: float = b.edge_distance(mid)
		if dd < bd:
			bd = dd
			best = b
	for u in _visible_foes(mid, r):
		if _static_target(u) and u.position.distance_to(mid) < bd:
			bd = u.position.distance_to(mid)
			best = u
	return best


## The nearest of an enemy force on the line worth ARMY_STOP of the push, or null.
func _army_on(mid: Vector2) -> Variant:
	var foes := _visible_foes(mid, ARMY_STOP_D).filter(func(u: Unit) -> bool: return not u.is_worker() and not u.is_air())
	if foes.is_empty() or _value(foes) < _value(men.keys()) * ARMY_STOP:
		return null
	var a: Unit = foes[0]
	for f in foes:
		if f.position.distance_to(mid) < a.position.distance_to(mid):
			a = f
	return a


# ------------------------------------------------------------------ the march

func _march(line: Array, guns: Array, mid: Vector2) -> void:
	# contact: a defence near, or the enemy army on the line
	var a = _next_anchor(mid, STOP_D)
	if a == null:
		a = _army_on(mid)
	if a != null:
		_set_up(a, mid)
		return
	if game.clock < _orders_t:
		return
	_orders_t = game.clock + 2.0
	var goal: Vector2 = ai._enemy_base()
	var nb = _next_anchor(mid, 99999.0)
	if nb != null:
		goal = _pos(nb)
	# (the guns with the main body: a gun walking out from home as a reinforcement does not hold the line back)
	var near_guns := guns.filter(func(g: Unit) -> bool: return g.position.distance_to(mid) < 700.0)
	var gmid := _mid(near_guns) if not near_guns.is_empty() else (_mid(guns) if not guns.is_empty() else mid)
	var lag := gmid.distance_to(mid) > GUN_LAG and not guns.is_empty()
	for u in line:
		if u.kind == "cuirassier":
			# (the riders keep by the guns: the Brood's Raptors and the Clockwork's Springers go for them)
			if u.position.distance_to(gmid) > 120.0 and u.target == null:
				u.cmd_move(gmid + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)
			continue
		if lag:
			if u.order != "hold" and u.target == null:
				u.cmd_hold()
		elif u.order in ["idle", "hold"] or u.order_point.distance_to(goal) > 120.0:
			u.cmd_move(goal + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)
	var tp := _behind(GUN_TRAIL)
	for g in guns:
		if g.position.distance_to(tp) > 70.0 and (g.order in ["idle", "hold"] or g.order_point.distance_to(tp) > 60.0):
			g.cmd_move(tp + Vector2(randf_range(-30, 30), randf_range(-30, 30)))


# ------------------------------------------------------------------ set up

var _gspot := {}                # gun -> its spot against the defence set up against
const SPOT_T := 25.0            # (s) a gun not at its spot by then fires from where it is (it walks into range itself)
var _said_what := ""
var _said_t := -99.0


func _set_up(a, mid: Vector2) -> void:
	var was: bool = state == "set"
	anchor = a
	anchor_p = _pos(a)
	state = "set"
	_set_t = game.clock
	_orders_t = 0.0
	_pick_t.clear()
	_gspot.clear()
	cur["sets"] = int(cur.get("sets", 0)) + 1
	if not cur.has("contact"):
		cur["contact"] = game.clock
	var what: String = String(a.d["name"] if a.d.has("name") else a.kind)
	if not was or what != _said_what or game.clock - _said_t > 20.0:
		_said_what = what
		_said_t = game.clock
		say("sets up against %s %s (%d px off)" % ["a" if a is Building else "the", what, int(anchor_p.distance_to(mid))])


## A walkable spot near `p` (the nearest open cell), on the line's side.
func _spot(p: Vector2) -> Vector2:
	var c: Vector2i = game.cell_of(p)
	if game.in_map(c) and game.open_cell(c):
		return p
	var f: Vector2i = game.nearest_free(c, 4)
	return game.cell_center(f) if f.x >= 0 else p


func _siege_set(line: Array, guns: Array, mid: Vector2) -> void:
	# the anchor gone: the next within reach, else march on
	var alive: bool = _alive(anchor) and (not (anchor is Building) or not anchor.ghost)
	if alive and anchor is Unit and not _static_target(anchor):
		alive = game.is_visible_to(ai.team, anchor.position) and anchor.position.distance_to(mid) < ARMY_STOP_D + 150.0
	if not alive:
		if anchor is Building or (anchor is Unit and not _alive(anchor)):
			var k: String = String(anchor.kind) if anchor != null and is_instance_valid(anchor) else "?"
			if k == "?":
				pass
		var nx = _army_on(mid)          # (the enemy army still on the line first: the fight goes on where it is)
		if nx == null:
			nx = _next_anchor(mid, STOP_D + 60.0)
		if nx != null:
			_set_up(nx, mid)
		else:
			state = "march"
			anchor = null
			_orders_t = 0.0
			return
	anchor_p = _pos(anchor)
	var out := (mid - anchor_p)
	if out.length() < 1.0:
		out = ai._front() - anchor_p
	out = out.normalized()
	var side := Vector2(-out.y, out.x)
	var brood := _brood()
	var line_d := LINE_D_BROOD if brood else LINE_D
	if anchor is Unit and not _static_target(anchor):
		line_d = 0.0        # (a field battle: the line stands where it is)
	if game.clock >= _orders_t:
		_orders_t = game.clock + 3.0
		# the line: a row on HOLD across the way, the riders at the guns' flanks
		var gmid := _mid(guns) if not guns.is_empty() else mid
		var row: Array = line.filter(func(u: Unit) -> bool: return u.kind != "cuirassier")
		row.sort_custom(func(p: Unit, q: Unit) -> bool: return (p.position - anchor_p).dot(side) < (q.position - anchor_p).dot(side))
		for i in row.size():
			var u: Unit = row[i]
			var spot: Vector2
			if line_d > 0.0:
				var off := (float(i) - (row.size() - 1) * 0.5) * 22.0
				var depth := float(i % 2) * 18.0
				spot = _spot(anchor_p + out * (line_d + depth) + side * off)
			else:
				spot = u.position
			if u.position.distance_to(spot) > 30.0:
				if u.order != "move" or u.order_point.distance_to(spot) > 20.0:
					u.cmd_move(spot)
			elif u.order != "hold":
				u.cmd_hold()
		var riders: Array = line.filter(func(u: Unit) -> bool: return u.kind == "cuirassier")
		for i in riders.size():
			var r: Unit = riders[i]
			var foes := _visible_foes(gmid, 220.0).filter(func(e: Unit) -> bool: return not e.is_air())
			if not foes.is_empty() and r.target == null:
				r.cmd_attack(foes[0])        # (something at the guns: the riders run it down)
			elif foes.is_empty() and r.position.distance_to(gmid) > 110.0:
				r.cmd_move(gmid + side * (90.0 if i % 2 == 0 else -90.0))
	for g in guns:
		_gun(g, out, side, guns.find(g), guns.size())


## One gun: to its spot behind the line, then its pick; canister when they close in; out of shot, to the wagon.
func _gun(g: Unit, out: Vector2, side: Vector2, i: int, n: int) -> void:
	var wagon: Unit = ai._wagon()
	if g.powder < 1.0 and _alive(wagon) and wagon.powder >= 4.0:
		if g.position.distance_to(wagon.position) > 70.0 and (g.order != "move" or g.order_point.distance_to(wagon.position) > 50.0):
			g.cmd_move(wagon.position + out * 40.0)
		return
	# its spot behind the line (against a defence: fixed when the push set up, so the gun is not sent on and on; against an
	# army on the line there is none, the gun fires from where it is and walks into range by itself)
	var spot := Vector2.INF
	if _static_target(anchor):
		if not _gspot.has(g):
			var d := CANNON_D if g.kind == "cannon" else MORTAR_D
			var off := (float(i) - (n - 1) * 0.5) * 46.0
			_gspot[g] = _spot(anchor_p + out * d + side * off)
		spot = _gspot[g]
	# canister: enemies at the gun
	if g.kind == "cannon":
		var close := _visible_foes(g.position, CANISTER_R).filter(func(e: Unit) -> bool: return not e.is_air() and (not e.is_worker() or e.target != null))
		if not close.is_empty():
			if g.mode != "canister":
				g.set_canister(true)
			close = close.filter(func(e: Unit) -> bool: return game.aoe_worth_it(g, e))      # (not through our own line)
		if not close.is_empty():
			if g.order != "attack" or not _alive(g.order_target) or not close.has(g.order_target):
				g.cmd_attack(close[0])
			return
		elif g.mode == "canister":
			g.set_canister(false)
	if spot != Vector2.INF and g.position.distance_to(spot) > 60.0 and g.tesla_mode == "packed" and game.clock - _set_t < SPOT_T:
		if g.order != "move" or g.order_point.distance_to(spot) > 40.0:
			g.cmd_move(spot)
		return
	if game.clock - float(_pick_t.get(g, -99.0)) < 4.0 and g.order in ["attack", "bombard"]:
		return
	_pick_t[g] = game.clock
	var t = _pick(g, g.position)
	if t == null:
		t = anchor
	if not _alive(t):
		return
	var p := _pos(t)
	if t is Unit and not _static_target(t):
		if g.order_target != t:
			g.cmd_attack(t)
	elif g.order != "bombard" or g.order_point.distance_to(p) > 8.0:
		if t is Building and game.is_visible_to(ai.team, p):
			if g.order_target != t:
				g.cmd_attack(t)
		else:
			g.cmd_bombard(p)        # (a defence it saw but cannot see now: the spot)


# ------------------------------------------------------------------ the wagon

## The Powder Wagon keeps WAGON_BACK behind the guns (WAGON_TRAIL on the march), never among the line: destroyed, it blows
## up with friends (docs/ai_crown_rebuild.md round B); enemies near it, it backs off along the trail.
func _tend_wagon(guns: Array, mid: Vector2) -> void:
	var w: Unit = ai._wagon()
	if not _alive(w):
		return
	var to: Vector2
	if state == "set" and not guns.is_empty() and anchor_p != Vector2.INF:
		var gm := _mid(guns)
		to = _spot(gm + (gm - anchor_p).normalized() * WAGON_BACK)
	else:
		to = _behind(WAGON_TRAIL)
	if not _visible_foes(w.position, 200.0).filter(func(e: Unit) -> bool: return not e.is_worker()).is_empty():
		to = _behind(WAGON_TRAIL + 200.0)
	if w.position.distance_to(to) > 60.0 and (w.order != "move" or w.order_point.distance_to(to) > 50.0):
		w.cmd_move(to)


func wagon_busy() -> bool:
	return state in ["march", "set"]


# ------------------------------------------------------------------ the end

## Why the push is lost ("" while it is not).
func _lost(mid: Vector2) -> String:
	var now := _value(men.keys())
	if now < v0 * RETREAT_K:
		return "%d of the %d that went out is left" % [int(now), int(v0)]
	var foes := _visible_foes(mid, 520.0).filter(func(u: Unit) -> bool: return not u.is_worker())
	var fv := _value(foes)
	if fv > now * RETREAT_FOE and now < v0 * 0.75:
		return "the enemy here (%d) is worth %.1f times the push (%d)" % [int(fv), fv / maxf(1.0, now), int(now)]
	if _guns().is_empty() and int(cur.get("guns", 0)) > 0 and now < v0 * 0.7:
		return "its guns are lost"
	var thr: Vector2 = ai._threat()
	if thr != Vector2.INF and ai.ch.foe_near() > ai.ch.home_value() * 1.3 + 150.0:
		return "the base is attacked (%d near home)" % int(ai.ch.foe_near())
	return ""


func _retreat(why: String) -> void:
	state = "back"
	_back_t = game.clock
	cur["why"] = why
	say("falls back: %s" % why)
	var home: Vector2 = ai._front()
	for u in men:
		var p: Vector2 = home + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		u.cmd_move(p)          # (guns limber and go: the line walks back with them, not fighting on)
	var w: Unit = ai._wagon()
	if _alive(w):
		w.cmd_move(home)


func _back(mid: Vector2) -> void:
	var home: Vector2 = ai._front()
	var far := men.keys().filter(func(u: Unit) -> bool: return u.position.distance_to(home) > 300.0)
	if far.is_empty() or game.clock - _back_t > 60.0:
		_end(String(cur.get("why", "back home")))


func _end(why: String) -> void:
	if not cur.is_empty() and float(cur.get("end", -1.0)) < 0.0:
		cur["end"] = game.clock
		if String(cur.get("why", "")) == "":
			cur["why"] = why
		var st: Dictionary = game.stats[ai.team]
		cur["killed"] = int(st["value_killed"]) - _kill_base
		var fe: int = ai._foe()
		cur["lost"] = (int(game.stats[fe]["value_killed"]) - _loss_base) if fe >= 0 else 0
		say("is over (%s): killed %d, lost %d, broke %s" % [why, int(cur["killed"]), int(cur["lost"]), str(cur["broke"])])
	state = ""
	men.clear()
	_near.clear()
	anchor = null
	_next_go = game.clock + COOL
	cur = {}


## The guns the plan wants trained before the line's next Musketeer: GUN_SHARE of the Musketeers as guns, a Mortar for
## every two cannons (AICrown._produce calls it before the shared training).
const CANNONS_MAX := 4
const GUN_LINE := 5             # Musketeers before the first gun is wanted
const GUN_LINE_BROOD := 8
const MORTARS_MAX := 3


func produce() -> void:
	var w := _gun_want()
	if w.is_empty():
		return
	var k: String = w[0]
	var f: Building = w[1]
	if ai._gold() >= int(Defs.UNITS[k]["cost"]) + int(w[2]) and game.train(f, k) == "":
		_due_since = -1.0
		say("trains a %s" % String(Defs.UNITS[k]["name"]))


## THE GUNS COME FIRST: while a gun is wanted and a Foundry stands idle, its price is kept from everything else (the
## labourers, the tech, the Musketeers): AICrown._think_stage / _produce. At most DUE_HOLD s at a time (a gun that cannot be
## had, no horse or no powder, never holds the gold for good), never while the base is attacked.
const DUE_HOLD := 50.0
const DUE_REST := 30.0
var _due_since := -1.0
var _due_rest := 0.0
var _due_t := -1.0
var _due_v := 0


func gun_due() -> int:
	if game.clock == _due_t:
		return _due_v
	_due_t = game.clock
	_due_v = 0
	if game.clock < _due_rest or ai._threat() != Vector2.INF:
		return 0
	var w := _gun_want()
	if w.is_empty():
		_due_since = -1.0
		return 0
	if _due_since < 0.0:
		_due_since = game.clock
	elif game.clock - _due_since > DUE_HOLD:
		_due_since = -1.0
		_due_rest = game.clock + DUE_REST
		return 0
	_due_v = int(Defs.UNITS[w[0]]["cost"]) + int(w[2])
	return _due_v


## [kind, Foundry] of the next gun the push wants, or [] (none wanted, no idle Foundry, no powder for it).
func _gun_want() -> Array:
	if ai._res2() < 20.0:
		return []
	var army: Array = game.army(ai.team)
	var cannons := 0
	var mortars := 0
	var muskets := 0
	for u in army:
		if u.kind == "cannon":
			cannons += 1
		elif u.kind == "mortar":
			mortars += 1
		elif Defs.MUSKETS.has(u.kind):
			muskets += 1
	for f in ai._mine("foundry"):
		if not f.built:
			continue
		cannons += f.queue.count("cannon")
		mortars += f.queue.count("mortar")
	var want_c := clampi(1 + muskets / 5, 1, CANNONS_MAX)
	var want_m := clampi(muskets / 7, 0, MORTARS_MAX)
	if muskets < (GUN_LINE_BROOD if _brood() else GUN_LINE):
		return []          # (the line first: against the Brood a gun's gold held from 4 Musketeers lost the main, b08 Greenhold)
	var k := ""
	if cannons < want_c:
		k = "cannon"
	elif mortars < want_m:
		k = "mortar"
	if k == "":
		return []
	for f in ai._mine("foundry"):
		if f.built and f.queue.is_empty():
			var why: String = game.can_train(f, k)
			if why == "" or why.begins_with("Not enough gold"):
				var extra := 0
				if game.free_horse_at(f) == null and game.spare_horse(ai.team, f) == null:
					extra = int(Defs.UNITS["horse"]["cost"])        # (no horse to hand: a Breeder trains one, paid now)
				return [k, f, extra]
	return []
