extends RefCounted
## THE SPRINGER RAID (the owner's Springer timing, 2026-11-03; docs/clockwork_ai_rebuild.md): the Clockwork computer's
## Blink-stalker play, run by AIClockwork (scripts/ai_clockwork.gd) for its Springer timing plan.
##  - The raid force: the plan's Springers (4), its Swift and two Winders (the CRANKS) who wind and mend the Springers at the
##    cliff foot (a construct runs down in about 80 s off its gear field: the leaps must come back to them).
##  - A LANDING SPOT: open ground on the enemy main's high ground, a jump from low ground our side can walk to (the STAGE,
##    at the cliff foot), near its workers and economy (what our side has seen; the hall when nothing yet), away from its
##    walls, its gate and the guns seen lately, and away from the spots already used.
##  - The Swift flies over the stage: a Springer leaps UP only where its side sees (HIGH LEAP), and nothing on the low
##    ground sees up the cliff; the Swift does. It keeps back from the enemy's guns seen near it.
##  - LEAP IN together when all are wound and their springs ready and the armed enemies seen by the landing are worth less
##    than they are; up there they shoot the workers first, then the soft buildings (its Powder Mill, Farms...).
##  - LEAP OUT (down: always allowed) to the cranks when one is hurt (below RAID_HURT), when the defence comes (armed enemies
##    near worth more than RAID_FLEE of them), when they run low on wind, or when there is nothing left to shoot; a Springer
##    whose spring is still winding (10 s) walks to the cliff edge meanwhile.
##  - At the foot they are wound and mended, then LEAP IN AGAIN ELSEWHERE (another landing spot, away from where the
##    defenders were last seen). Two or fewer left (or the defence comes down to the foot): home, re-supplied from the army
##    at home (after the opening), then out again.
## Telegraph: the crouch before every leap is the game's own (Defs.SPRINGER_JUMP); no cheating: it sees only what its side
## sees (Game.is_visible_to / side_sees), and knows where the enemy started (every computer does).

const RAID_HURT := 0.45          # a Springer under this share of its health leaps out
const RAID_FLEE := 1.3           # armed enemies by the raid worth more than this share of it: all leap out
const RAID_WIND_OUT := 0.3       # leap out under this much wind
const RAID_GO_WIND := 0.75       # leap in again once wound this far
const RAID_MAX := 40.0           # seconds up there at most in one go
const LAND_GAP := 160.0          # px: a new landing spot this far from the used ones
const REACH := 125.0             # px: the stage's distance to the landing at most (the jump is 160: room for a group round the stage)
const SCAN := 20                 # tiles round the enemy's hall searched for landing spots

var ai = null
var game: Game = null
var team := 0
var springers: Array = []
var swift: Unit = null
var cranks: Array = []
var phase := ""                  # "", "gather", "march", "set", "raid", "out", "home"
var since := 0.0
var stage := Vector2.INF
var land := Vector2.INF
var used: Array = []             # landing spots used (Vector2), the newest last
var foe := -1
var leaps := 0                   # leaps in
var outs := 0                    # leaps out
var kill0 := 0                   # value killed when the raid went out
var log_t := {}
var _flood := PackedByteArray()
var _flood_t := -999.0
var _guns: Dictionary = {}       # enemy armed unit -> [position, clock] last seen (to land away from them)
var _econ: Dictionary = {}       # enemy economy building -> position (seen)
var _swift_seen := false         # the Swift has had its first look at the enemy main
var _known_at_pick := 0           # economy buildings and guns known when the spot was picked
var launched := false


func _init(a) -> void:
	ai = a
	game = a.game
	team = a.team


func has(u: Unit) -> bool:
	return u == swift or springers.has(u) or cranks.has(u)


func say(s: String) -> void:
	ai.note(s)


## The "attack" step: the raid takes its force once the plan's Springers and the Swift are out and HIGH LEAP is done (or
## nearly: it walks out while the research ends). True once it has gone.
func launch() -> bool:
	if launched:
		return true
	var want := int(ai.plan.get("raid", 4))
	var sp: Array = _home_springers()
	var sw: Array = game.army(team).filter(func(u: Unit) -> bool: return u.kind == Defs.CUCKOO and not u.dead)
	if sp.size() < want or sw.is_empty() or not (game.has_tech(team, "high_leap") or game.researching(team, "high_leap")):
		return false
	foe = ai._foe()
	if foe < 0:
		return false
	springers = sp.slice(0, want)
	swift = sw[0]
	_pick_cranks()
	launched = true
	kill0 = int(game.stats[team]["value_killed"])
	_phase("gather")
	say("attack: the Springer raid goes out (%d Springers, a Swift, %d Winders) at %d supply" % [springers.size(), cranks.size(), game.supply_used(team)])
	return true


func _home_springers() -> Array:
	return game.army(team).filter(func(u: Unit) -> bool: return u.kind == Defs.SPRINGER and not u.dead and not springers.has(u) \
		and not (ai._wave_set.has(u) and ai._attacking))


func _pick_cranks() -> void:
	cranks = cranks.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var want := int(ai.plan.get("raid_winders", 2))
	if cranks.size() >= want:
		return
	var home := _home()
	var labs: Array = game.workers(team).filter(func(u: Unit) -> bool: return not cranks.has(u) and u.order != "build" and u.crate_site == null \
		and not ai._escort.has(u) and not (ai.scout != null and ai.scout.is_scout(u)) and (u.home_mine == null or u.home_mine.kind != "mainspring"))
	labs.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(home) < b.position.distance_to(home))
	for u in labs.slice(0, want - cranks.size()):
		cranks.append(u)


func _phase(p: String) -> void:
	phase = p
	since = game.clock


func _home() -> Vector2:
	var h: Array = ai._halls()
	return (h[0] as Building).center() if not h.is_empty() else game.center_of_team(team)


func _foe_hall() -> Vector2:
	return (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE


# ------------------------------------------------------------------ the think

func tick() -> void:
	if not launched or game.over:
		return
	springers = springers.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	cranks = cranks.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	if swift != null and (not is_instance_valid(swift) or swift.dead):
		swift = null
		say("the Swift is lost")
	_remember()
	_resupply()
	if springers.is_empty():
		if phase != "home":
			say("out: the raid is wiped out (%d value killed in all)" % (int(game.stats[team]["value_killed"]) - kill0))
			_phase("home")
		_crank_home()
		return
	match phase:
		"gather":
			_gather()
		"march":
			_march()
		"set":
			_ready_to_leap()
		"raid":
			_raid()
		"out":
			_out()
		"home":
			_go_home()
	_swift_tick()
	_crank_tick()


## What our side sees of the enemy: its armed units (where the guns are) and its economy buildings.
func _remember() -> void:
	for o in game.units_near(_foe_hall(), float(SCAN + 8) * Defs.TILE):
		if o.dead or o.off_field or o.team != foe or o.is_worker() or not ai._armed(o):
			continue
		if game.is_visible_to(team, o.position):
			_guns[o] = [o.position, game.clock]
	for k in _guns.keys():
		if not is_instance_valid(k) or k.dead or game.clock - float(_guns[k][1]) > 60.0:
			_guns.erase(k)
	for b in game.buildings:
		if b.team != foe or b.dead or _econ.has(b):
			continue
		if b.kind in ["farm", "powder_mill", "town_hall", "horse_breeder", "barracks", "cottage", "church"] and game.is_visible_to(team, b.center()):
			_econ[b] = b.center()
	for b in _econ.keys():
		if not is_instance_valid(b) or b.dead:
			_econ.erase(b)


## After the opening: fresh Springers at home top the raid up to the plan's raid_keep while it is out (they walk to the
## stage in a pair), and a lost crank is replaced.
func _resupply() -> void:
	if ai.bo_on and phase != "home":
		return
	var keep := int(ai.plan.get("raid_keep", 6))
	if springers.size() >= keep:
		return
	var home := _home()
	var fresh: Array = _home_springers().filter(func(u: Unit) -> bool: return u.position.distance_to(home) < 700.0 and u.target == null)
	if fresh.size() < 2 and not (phase == "home" and fresh.size() >= 1):
		return
	var join: Array = fresh.slice(0, keep - springers.size())
	for u in join:
		springers.append(u)
		if phase in ["out", "set", "march"] and stage != Vector2.INF:
			u.cmd_move(stage + Vector2(randf_range(-16, 16), randf_range(-16, 16)))
	say("re-supply: %d Springers join the raid (now %d)" % [join.size(), springers.size()])
	_pick_cranks()


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


## The armed enemies our side has seen in the last 30 s whose last seen spot is within r of p, by value (where the guns
## were: they do not vanish when the Swift looks away).
func _guns_near(p: Vector2, r: float) -> float:
	var v := 0.0
	for k in _guns:
		if is_instance_valid(k) and not k.dead and game.clock - float(_guns[k][1]) < 30.0 and (_guns[k][0] as Vector2).distance_to(p) < r:
			v += ai._unit_value(k)
	return v


## The armed enemies our side sees within r of p, by value.
func _foe_near(p: Vector2, r: float) -> float:
	var v := 0.0
	for o in game.units_near(p, r):
		if o.dead or o.off_field or not game.hostile(o.team, team) or not ai._armed(o) or not game.is_visible_to(team, o.position):
			continue
		v += ai._unit_value(o)
	return v


# ------------------------------------------------------------------ the phases

func _gather() -> void:
	var pt := _home().lerp(_foe_hall(), 0.18)
	var c := _centre(springers)
	var spread := 0.0
	for u in springers:
		spread = maxf(spread, u.position.distance_to(c))
		if u.position.distance_to(pt) > 120.0 and (u.order != "move" or u.order_point.distance_to(pt) > 80.0):
			u.cmd_move(pt + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
	if c.distance_to(pt) < 160.0 and spread < 160.0 or game.clock - since > 40.0:
		if _pick_spot():
			_phase("march")
			for u in springers:
				u.cmd_move(stage + Vector2(randf_range(-16, 16), randf_range(-16, 16)))


func _march() -> void:
	var c := _centre(springers)
	# (a fight on the way it cannot win: home)
	if _foe_near(c, 280.0) > _value(springers) * 1.2 + 60.0:
		say("out: the raid meets a stronger force on the way (%d against %d): home" % [int(_foe_near(c, 280.0)), int(_value(springers))])
		_phase("home")
		return
	var there := 0
	for u in springers:
		if u.position.distance_to(stage) < 80.0:
			there += 1
		elif u.order != "move" or u.order_point.distance_to(stage) > 60.0:
			u.cmd_move(stage + Vector2(randf_range(-16, 16), randf_range(-16, 16)))
	if there >= maxi(1, springers.size() - 1) or game.clock - since > 50.0:
		for u in springers:
			if u.position.distance_to(stage) < 100.0:
				u.cmd_hold()
		_phase("set")


## At the foot: the leap goes when the Swift shows the spot, the springs are ready and the defence by it is weaker.
func _ready_to_leap() -> void:
	var c := _centre(springers)
	if game.clock - since > 60.0 or (springers.size() <= 2 and int(ai.plan.get("raid", 4)) > 2):
		say("out: no leap after %d s at the foot (%d Springers): home" % [int(game.clock - since), springers.size()])
		_phase("home")
		return
	if _foe_near(stage, 240.0) > _value(springers) * 1.0 + 60.0:
		say("out: the defence comes down to the cliff foot (%d): home" % int(_foe_near(stage, 240.0)))
		_phase("home")
		return
	if _econ.size() + _guns.size() != _known_at_pick and game.clock - since > 2.0:
		# (the Swift has shown more of its main since the spot was picked: a better spot may be elsewhere)
		var old_land := land
		var old_stage := stage
		if _pick_spot(true) and land.distance_to(old_land) > 200.0:
			say("the Swift's sight moves the landing spot")
			_phase("march")
			for u in springers:
				u.cmd_move(stage + Vector2(randf_range(-16, 16), randf_range(-16, 16)))
			return
		land = old_land
		stage = old_stage
	if not game.has_tech(team, "high_leap") and game.on_high(land) and not game.on_high(stage):
		return                    # (the research ends soon: they wait at the foot)
	var ready: Array = springers.filter(func(u: Unit) -> bool: return Springer.ready_problem(u) == "" and u.position.distance_to(land) < float(Defs.SPRINGER_JUMP["range"]) + 20.0)
	if ready.size() < mini(springers.size(), int(ai.plan.get("raid", 4))) and game.clock - since < 25.0:
		for u in springers:
			if u.position.distance_to(stage) > 60.0 and (u.order != "move" or u.order_point.distance_to(stage) > 40.0):
				u.cmd_move(stage + Vector2(randf_range(-20, 20), randf_range(-20, 20)))
		return
	if ready.size() < 2:
		if game.clock - since > 45.0:
			_phase("gather")              # (they cannot get at it from here: another spot)
		return
	if not game.side_sees(team, land):
		if game.clock - since > 30.0 and swift == null:
			say("out: no sight of the landing spot (no Swift): home")
			_phase("home")
		return
	var theirs := _foe_near(land, 240.0)
	var coming := maxf(_foe_near(land, 460.0), _guns_near(land, 620.0))   # (Musketeers walk 620 px in about 10 s, a spring's wind: they would be there before it can leap out)
	if theirs * 1.1 > _value(ready) or coming > _value(ready) * RAID_FLEE + 40.0:
		# (guns by the spot: another spot, away from them)
		if game.clock - since > 6.0:
			say("the landing spot is guarded (%d of armed enemies by it): another spot" % int(theirs))
			used.append(land)
			if _pick_spot():
				_phase("march")
			else:
				_phase("home")
		return
	var n := 0
	for u in ready:
		var l: Dictionary = Springer.landing(u, land + Vector2(randf_range(-28, 28), randf_range(-28, 28)))
		if not l.has("at"):
			l = Springer.landing(u, land)
		if l.has("at") and game.level_of(l["at"]) >= game.level_of(land):
			Springer.start(u, l["at"])
			n += 1
	if n == 0:
		if game.clock - since > 20.0:
			used.append(land)
			_phase("gather")
		return
	leaps += 1
	used.append(land)
	say("leap: %d Springers leap in at %s (%d armed enemies' worth by it)%s" % [n, str((land / Defs.TILE).round()), int(theirs), " [%d]" % leaps])
	_phase("raid")


func _raid() -> void:
	var up: Array = springers.filter(func(u: Unit) -> bool: return game.level_of(u.position) >= game.level_of(land) or not u.jump.is_empty())
	var below: Array = springers.filter(func(u: Unit) -> bool: return not up.has(u))
	for u in below:
		if u.position.distance_to(stage) > 60.0 and u.order != "move":
			u.cmd_move(stage)
	if up.is_empty():
		_phase("out")
		return
	var c := _centre(up)
	var theirs := _foe_near(c, 260.0)
	var mine := _value(up)
	var wind := 1.0
	for u in up:
		wind = minf(wind, u.wind)
	var why := ""
	if theirs > mine * RAID_FLEE + 40.0:
		why = "the defence comes (%d against %d)" % [int(theirs), int(mine)]
	elif wind < RAID_WIND_OUT:
		why = "low on wind"
	elif game.clock - since > RAID_MAX:
		why = "time"
	var prey := 0
	for u in up:
		if not u.jump.is_empty():
			continue
		var leave: bool = why != "" or u.hp < u.max_hp * RAID_HURT
		if leave:
			_leap_out(u)
			continue
		if _shoot(u):
			prey += 1
	if why == "" and prey == 0 and game.clock - since > 12.0:
		why = "nothing left to shoot by the spot"
	if why != "":
		if not log_t.has("out%d" % leaps):
			log_t["out%d" % leaps] = true
			outs += 1
			say("out: leap out (%s) after %d s up there; %d value killed by the raid so far" % [why, int(game.clock - since), int(game.stats[team]["value_killed"]) - kill0])
		for u in up:
			if u.jump.is_empty():
				_leap_out(u)
	if springers.all(func(u: Unit) -> bool: return game.level_of(u.position) < game.level_of(land) and u.jump.is_empty()):
		_phase("out")


## Down to the cranks at the foot (a down leap needs no sight); a spring still winding: walk to the edge over the stage.
func _leap_out(u: Unit) -> void:
	if Springer.ready_problem(u) == "":
		var at := _down_spot(u)
		if at != Vector2.INF:
			Springer.start(u, at)
			return
	var edge := land.lerp(stage, 0.45)
	if u.position.distance_to(edge) > 30.0 and (u.order != "move" or u.order_point.distance_to(edge) > 20.0):
		u.cmd_move(edge)


## A spot down the cliff within a jump of u, on ground our side can walk (the stage's side first); INF: none.
func _down_spot(u: Unit) -> Vector2:
	var l: Dictionary = Springer.landing(u, stage + Vector2(randf_range(-24, 24), randf_range(-24, 24)))
	if l.has("at") and game.level_of(l["at"]) < game.level_of(u.position):
		return l["at"]
	var fl := _walkable()
	var c0: Vector2i = game.cell_of(u.position)
	var r := int(float(Defs.SPRINGER_JUMP["range"]) / Defs.TILE)
	var best := Vector2.INF
	var bd := INF
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c: Vector2i = c0 + Vector2i(dx, dy)
			if not _open(c) or int(game.height[game.idx(c)]) >= game.level_of(u.position) or fl[game.idx(c)] == 0:
				continue
			var q := game.cell_center(c)
			if q.distance_to(u.position) > float(Defs.SPRINGER_JUMP["range"]) - 8.0:
				continue
			var d := q.distance_to(stage) if stage != Vector2.INF else 0.0
			if d < bd:
				l = Springer.landing(u, q)
				if l.has("at") and game.level_of(l["at"]) < game.level_of(u.position):
					bd = d
					best = l["at"]
	return best


## Up there, near the landing (LEASH: within a jump of the edge, ready to leap out): the armed enemies in reach first,
## the most hurt (focus fire: a Musketeer reloads slowly, four Springers kill one in about three seconds), then the
## workers, then the soft buildings (its Powder Mill, Farms, the Breeder; a building still going up first).
const LEASH := 210.0


func _shoot(u: Unit) -> bool:
	var best: Entity = null
	var bs := INF
	for o in game.units_near(u.position, u._range() + 120.0):
		if o.dead or o.off_field or o.is_air() or not game.hostile(o.team, team) or not u.can_hit(o):
			continue
		if not game.is_visible_to(team, o.position):
			continue
		var dd: float = o.position.distance_to(u.position)
		var sc: float
		if ai._armed(o):
			if dd > u._range() + 20.0:
				continue
			sc = o.hp / maxf(1.0, o.max_hp) * 100.0 - 400.0
		else:
			if o.position.distance_to(land) > LEASH:
				continue
			sc = dd
		if sc < bs:
			bs = sc
			best = o
	if best == null:
		for b in game.buildings:
			if b.team != foe or b.dead or not game.hostile(b.team, team) or b.kind in ["wall", "gate"]:
				continue
			var dd: float = b.edge_distance(u.position)
			if b.center().distance_to(land) > LEASH + 60.0 or not game.is_visible_to(team, b.center()):
				continue
			var w: float = dd + (0.0 if b.kind in ["powder_mill", "farm", "horse_breeder"] else 120.0) + (0.0 if b.built else -60.0)
			if w < bs:
				bs = w
				best = b
	if best == null:
		if u.position.distance_to(land) > LEASH and (u.order != "move" or u.order_point.distance_to(land) > 40.0):
			u.cmd_move(land)
		return false
	if u.order != "attack" or u.order_target != best:
		u.cmd_attack(best)
	return true


## At the foot: the cranks wind and mend them, then in again elsewhere.
func _out() -> void:
	var c := _centre(springers)
	if _foe_near(c, 260.0) > _value(springers) + 60.0:
		say("out: the defence follows them down (%d): home" % int(_foe_near(c, 260.0)))
		_phase("home")
		return
	var rest := _rest()
	for u in springers:
		if u.jump.is_empty() and u.position.distance_to(rest) > 70.0 and (u.order != "move" or u.order_point.distance_to(rest) > 50.0) and u.target == null:
			u.cmd_move(rest + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	var fit: Array = springers.filter(func(u: Unit) -> bool: return u.hp >= u.max_hp * 0.6 and u.wind >= RAID_GO_WIND)
	if springers.size() <= 2 and game.clock - since > 6.0:
		say("out: %d Springers left: home to be topped up" % springers.size())
		_phase("home")
		return
	var waited := game.clock - since
	if (fit.size() >= springers.size() or (fit.size() >= 2 and waited > 25.0)) and waited > 4.0:
		# (the defence has walked off from the spot they left (the Swift watches it): back in at the same place, no walk)
		if game.side_sees(team, land) and _foe_near(land, 460.0) < _value(fit) * 0.5 and _guns_near(land, 300.0) < _value(fit) * 0.5:
			say("the defence has left the landing spot: back in there")
			_phase("set")
			for u in springers:
				u.cmd_move(stage + Vector2(randf_range(-16, 16), randf_range(-16, 16)))
			return
		if _pick_spot():
			_phase("march")
			for u in springers:
				u.cmd_move(stage + Vector2(randf_range(-16, 16), randf_range(-16, 16)))
		else:
			_phase("home")
	elif waited > 70.0:
		_phase("home")


## Where they are wound between leaps: back from the foot of the cliff, out of reach of the guns at its edge.
func _rest() -> Vector2:
	if stage == Vector2.INF or land == Vector2.INF:
		return _centre(springers)
	var p := stage + (stage - land).normalized() * 150.0
	var c := game.cell_of(p)
	if _open(c) and game.level_of(p) == game.level_of(stage):
		return p
	return stage + (stage - land).normalized() * 60.0


func _go_home() -> void:
	var pt := _home().lerp(_foe_hall(), 0.12)
	for u in springers:
		if not u.jump.is_empty():
			continue
		# (chased: a jump toward home, on the flat or down, is the quickest way out of reach)
		if Springer.ready_problem(u) == "" and _foe_near(u.position, 220.0) > 0.0:
			var l: Dictionary = Springer.landing(u, u.position + (pt - u.position).normalized() * float(Defs.SPRINGER_JUMP["range"]))
			if l.has("at") and game.level_of(l["at"]) <= game.level_of(u.position):
				Springer.start(u, l["at"])
				continue
		if u.position.distance_to(pt) > 140.0 and (u.order != "move" or u.order_point.distance_to(pt) > 100.0):
			u.cmd_move(pt + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
	var c := _centre(springers)
	var fit := springers.filter(func(u: Unit) -> bool: return u.hp >= u.max_hp * 0.7 and u.wind > 0.8)
	if c.distance_to(pt) < 200.0 and fit.size() >= mini(3, int(ai.plan.get("raid", 4))) and game.clock - since > 15.0 \
			and (swift != null or _swift_back()):
		say("the raid goes out again (%d Springers)" % springers.size())
		_phase("gather")


## A new Swift at home takes the lost one's place; none: one is made at the Clock Aviary (the shared computer makes Swifts
## only against flyers).
func _swift_back() -> bool:
	for u in game.army(team):
		if u.kind == Defs.CUCKOO and not u.dead and not ai._on_errand(u):
			swift = u
			return true
	if ai.bo_on:
		return false
	for b in ai._mine(Defs.CW_AIR):
		if b.built and (b.queue as Array).is_empty() and game.can_train(b, Defs.CUCKOO) == "":
			if game.train(b, Defs.CUCKOO) == "":
				say("a new Swift for the raid")
			break
	return false


# ------------------------------------------------------------------ the Swift and the cranks

func _swift_tick() -> void:
	if swift == null:
		_swift_back()
		return
	var to := _home().lerp(_foe_hall(), 0.3)
	if phase in ["march", "set", "raid", "out"] and stage != Vector2.INF:
		# over the stage, a little back from the cliff (it sees up the cliff from the air), clear of the guns seen
		var back := (stage - land).normalized() if land != Vector2.INF else Vector2.ZERO
		to = stage + back * 40.0
		for k in _guns:
			var gp: Vector2 = _guns[k][0]
			if gp.distance_to(to) < 210.0:
				to += (to - gp).normalized() * (215.0 - gp.distance_to(to))
	elif phase == "gather":
		to = _centre(springers)
	if not _swift_seen and stage != Vector2.INF and swift.position.distance_to(stage) < 120.0 and phase == "set":
		_swift_seen = true
		say("the Swift looks up onto the enemy main (%d economy buildings, %d guns seen)" % [_econ.size(), _guns.size()])
	if swift.hp < swift.max_hp * 0.35 or swift.wind < 0.25:
		to = _home()
	if swift.position.distance_to(to) > 30.0 and (swift.order != "move" or swift.order_point.distance_to(to) > 25.0):
		swift.cmd_move(to)


## The cranks: at the stage (or with the Springers on the way), winding and mending them; home while the raid is home.
func _crank_tick() -> void:
	if cranks.size() < int(ai.plan.get("raid_winders", 2)) and not ai.bo_on:
		_pick_cranks()
	var spot := stage if phase in ["march", "set", "raid", "out"] and stage != Vector2.INF else _centre(springers)
	if phase in ["march", "set", "raid"] and land != Vector2.INF:
		spot = stage + (stage - land).normalized() * 50.0
	elif phase == "out":
		spot = _rest()
	var danger := _foe_near(spot, 200.0) > 0.0 and phase != "out"
	var need: Array = springers.filter(func(u: Unit) -> bool: return u.jump.is_empty() and game.level_of(u.position) == game.level_of(spot) \
		and u.position.distance_to(spot) < 260.0 and (u.wind < 0.97 or u.hp < u.max_hp * 0.95))
	need.sort_custom(func(a: Unit, b: Unit) -> bool: return a.wind + a.hp / a.max_hp < b.wind + b.hp / b.max_hp)
	for w in cranks:
		if danger and w.position.distance_to(spot) < 220.0:
			var away := spot + (spot - land).normalized() * 160.0 if land != Vector2.INF else _home()
			if w.order != "move" or w.order_point.distance_to(away) > 40.0:
				w.cmd_move(away)
			continue
		if w.order == "repair" and is_instance_valid(w.order_target) and not w.order_target.dead and springers.has(w.order_target):
			if (w.order_target as Unit).wind < 0.99 or w.order_target.hp < w.order_target.max_hp:
				continue
		if not need.is_empty() and w.can_repair(need[0]):
			w.cmd_repair(need.pop_front())
			continue
		if w.position.distance_to(spot) > 60.0 and (w.order != "move" or w.order_point.distance_to(spot) > 40.0):
			w.cmd_move(spot + Vector2(randf_range(-20, 20), randf_range(-20, 20)))


func _crank_home() -> void:
	for w in cranks:
		w.cmd_stop()
	cranks.clear()       # (back to the presses: the shared computer finds them a post)


# ------------------------------------------------------------------ the landing spot

## Where our side can walk (from our main hall; the enemy's gates shut).
func _walkable() -> PackedByteArray:
	if game.clock - _flood_t > 30.0 or _flood.is_empty():
		_flood_t = game.clock
		var h: Array = ai._halls()
		var from: Vector2i = game.cell_of(_home())
		var cells: Array = []
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				cells.append(from + Vector2i(dx, dy))
		_flood = ai._flood_from(cells, team)
	return _flood


func _open(c: Vector2i) -> bool:
	if not game.in_map(c):
		return false
	var i := game.idx(c)
	var sv: int = game.solid[i]
	return (sv == 0 or sv == 5) and game.water[i] == 0 and game.cliff[i] == 0


## The tops of the ramps up to the enemy's main (ramp cells touching its plateau), as positions; the map's shape.
var _ramps_cache: Array = []
var _ramps_done := false


func _ramp_tops(hc: Vector2i, lv: int) -> Array:
	if _ramps_done:
		return _ramps_cache
	_ramps_done = true
	for y in range(-SCAN - 6, SCAN + 7):
		for x in range(-SCAN - 6, SCAN + 7):
			var c: Vector2i = hc + Vector2i(x, y)
			if not game.in_map(c) or game.ramp[game.idx(c)] != 1:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = c + d
				if game.in_map(p) and game.ramp[game.idx(p)] == 0 and int(game.height[game.idx(p)]) == lv:
					_ramps_cache.append(game.cell_center(c))
					break
	if OS.get_cmdline_user_args().has("cwdebug"):
		print("DBG ramps hall %s level %d: %d ramp-top cells %s" % [str(hc), lv, _ramps_cache.size(), str(_ramps_cache.map(func(v): return Vector2i(v / Defs.TILE)).slice(0, 12))])
	return _ramps_cache


## The best landing spot and its stage (false: none). Near what our side knows of its economy (its hall when nothing is
## known), away from the guns seen lately and from its walls and gate, away from the spots used, the stage reachable.
func _pick_spot(quiet := false) -> bool:
	_known_at_pick = _econ.size() + _guns.size()
	var prev_stage := stage if phase in ["out", "set", "march"] else Vector2.INF
	var walk_from := prev_stage if prev_stage != Vector2.INF else _centre(springers)
	var fl := _walkable()
	var hc: Vector2i = game.cell_of(_foe_hall())
	var lv := int(game.height[game.idx(hc)]) if game.in_map(hc) else 0
	var ramps := _ramp_tops(hc, lv)
	var targets: Array = []
	for b in _econ:
		if not (b.kind in ["barracks", "cottage", "church", "town_hall"]):
			targets.append(_econ[b])
	if targets.is_empty():
		# (nothing of its economy seen yet: a Crown's Farms and Mill stand behind its hall, away from its ramp, and the
		# workers with them: the guess is that side of the hall; the map's shape is no secret)
		var g0 := _foe_hall()
		if not ramps.is_empty():
			var rc := Vector2.ZERO
			for r in ramps:
				rc += r
			rc /= ramps.size()
			g0 += (g0 - rc).normalized() * 160.0
		targets.append(g0)
	var walls: Array = []
	for b in game.buildings:
		if b.team != foe or b.dead or not (b.kind in ["wall", "gate"]):
			continue
		if game.side_sees(team, b.center()) or (ai.scout != null and ai.scout._seen_b.has(b)):
			walls.append(b.center())
	var best := Vector2.INF
	var best_stage := Vector2.INF
	var bs := INF
	var reach_c := int(ceil(REACH / Defs.TILE))
	for dy in range(-SCAN, SCAN + 1, 1):
		for dx in range(-SCAN, SCAN + 1, 1):
			var c: Vector2i = hc + Vector2i(dx, dy)
			if not _open(c) or int(game.height[game.idx(c)]) != lv:
				continue
			if lv == 0:
				continue          # (a main on low ground: no leap; handled below)
			# (only cells near the plateau's edge: a low cell 3 cells away in some direction; the inside is skipped quickly)
			var edge := false
			for o in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(-2, -2)]:
				var e: Vector2i = c + o
				if game.in_map(e) and int(game.height[game.idx(e)]) < lv:
					edge = true
					break
			if not edge:
				continue
			var p := game.cell_center(c)
			# the stage: the nearest low cell our side can walk to, within a jump
			var st := Vector2.INF
			var sd := INF
			for ey in range(-reach_c, reach_c + 1):
				for ex in range(-reach_c, reach_c + 1):
					var l: Vector2i = c + Vector2i(ex, ey)
					if not _open(l) or int(game.height[game.idx(l)]) >= lv or fl[game.idx(l)] == 0:
						continue
					var q := game.cell_center(l)
					var d := q.distance_to(p)
					if d < 70.0 or d > REACH:
						continue
					# (a stage with room round it for the four of them)
					if d < sd:
						sd = d
						st = q
			if st == Vector2.INF:
				continue
			var s := 0.0
			var td := INF
			for tp in targets:
				td = minf(td, p.distance_to(tp))
			s += td
			for k in _guns:
				if game.clock - float(_guns[k][1]) > 15.0:
					continue           # (where they were a while ago is not where they are)
				var gd: float = p.distance_to(_guns[k][0])
				if gd < 520.0:
					s += (520.0 - gd) * 1.0
			for w in walls:
				var wd: float = p.distance_to(w)
				if wd < 320.0:
					s += (320.0 - wd) * 1.5
			for r in ramps:
				var rd: float = p.distance_to(r)
				if rd < 460.0:
					s += (460.0 - rd) * 2.0
				# (and the walk to the stage keeps clear of the ramp: its foot is where the defence comes out and stands)
				var wd2 := Geometry2D.get_closest_point_to_segment(r, walk_from, st).distance_to(r)
				if wd2 < 420.0:
					s += (420.0 - wd2) * 1.5       # (the ramp's top: its wall, its gate, its guards)
			for u in used:
				var ud: float = p.distance_to(u)
				if ud < LAND_GAP:
					s += (LAND_GAP - ud) * 3.0
			if prev_stage != Vector2.INF:
				s += p.distance_to(prev_stage) * 0.8      # (the next spot along the same cliff: a short walk, out of the way)
			if s < bs:
				bs = s
				best = p
				best_stage = st
	if best == Vector2.INF:
		if lv == 0:
			# (an enemy main on low ground: walk in and jump about on the flat; the landing spot is its economy)
			best = targets[0]
			best_stage = best.lerp(_home(), 120.0 / maxf(1.0, best.distance_to(_home())))
		else:
			say("finds no landing spot on the enemy's high ground")
			return false
	land = best
	stage = best_stage
	if not quiet:
		var rmin := INF
		for r in ramps:
			rmin = minf(rmin, land.distance_to(r))
		say("picks a landing spot at %s (stage %s; %d tiles from the ramp's top, its hall %d)" % [str((land / Defs.TILE).floor()), str((stage / Defs.TILE).floor()),
			int(rmin / Defs.TILE) if rmin < INF else -1, int(land.distance_to(_foe_hall()) / Defs.TILE)])
	return true
