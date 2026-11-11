class_name AICrownMirror
extends RefCounted
## THE CROWN MIRROR (crown-v-crown-coach, the owner 2026-11-11 22:35; docs/crown-v-crown-coach.md): the Crown computer's
## play against another Crown, coached from filmed Hard OPTIMAL v OPTIMAL games. Everything here runs only when the Crown
## computer faces a Crown (AICrown.mirror()); the shared code only calls in (AI._cohesion, AIOptimal._mirror_keep ...).
##
## 1. THE WAVE MARCHES AS ONE (coached: frostmere 11:00, hollowfen 11:45 and 12:45): the wave left in a column (Dragoons and
##    Horsemen ahead, the Musketeers and the guns behind, reinforcements walking alone) and met the enemy's formed line strung
##    out over 7-14 tiles: 1,625 of army fell to 540 against 1,370 in fifteen seconds. Now, while no enemy soldier is in
##    reach of the wave and no siege is on, a wave strung out over SPREAD_MAX holds its head and brings its tail up to its
##    middle, then goes on together; seeing an enemy army ahead it forms up the same way (tighter, FORM_SPREAD) before it
##    walks into musket range. A regroup lasts REGROUP_MAX at most, and the next waits REGROUP_COOL.
## 2. THE FARMS BEFORE THE MILLS (coached: thornwood 1136 and greenhold 1140, the Balanced plan): after its opening the
##    Mill's crew followed the powder bank alone; with two Mills, a Foundry and a Horse Breeder at 14 labourers the Mills
##    took the hands, the farms stood half empty and the gold stopped for one to three minutes (1,900 earned at 4:00 and at
##    5:00; 2,280 from 5:00 to 7:00), no soldier was trained, so the powder was never spent, and a lone Horseman picked the
##    labourers off. Now, with powder in the bank (FARM_POWDER) and a Farm short of half its crew, a hand goes back to the
##    farms (AICrown._mill_feedback steps the crew down, never below one a Mill).
## 3. THE RAIDER GETS AN ANSWER (coached: greenhold 1140, twice): the Balanced plan's Barracks stood from 1:25 and no
##    soldier came out of it until 7:50; from 4:15 one enemy Horseman (the Dragoon plan's scout) rode through the labourers
##    for three minutes (16 -> 3 labourers, the game lost at 9:20) while the gold went to a Horse Breeder, a Foundry, a
##    second Barracks and the natural's wall. Now an armed enemy among the labourers that the soldiers near them cannot
##    meet (ANSWER_EDGE) puts Musketeers in the Barracks queues before anything else (up to ANSWER_MAX at a time); the
##    shared defence sends them at it.

const SPREAD_MAX := 5.0          # (tiles) the wave's mean distance from its middle that calls a regroup on the march
const FORM_SPREAD := 3.0         # (tiles) ... with an enemy army in sight ahead
const DONE_SPREAD := 2.2         # (tiles) a regroup ends when the wave is this close together
const SEE_R := 720.0             # (px) an enemy army this near the wave's middle is "ahead"
const SEE_SHARE := 0.25          # ... when worth this share of the wave at least (a lone scout is not)
const CONTACT_R := 300.0         # (px) an armed enemy this near any man of the wave: it fights, no regroup
const REGROUP_MAX := 14.0        # (s) a regroup ends by then whatever the spread
const REGROUP_COOL := 18.0       # (s) between regroups
const HEAD_R := 2.5              # (tiles) men this near the meeting point (or ahead of it) hold there

var ai = null                     # the AICrown
var game: Game = null
var _until := -1.0                # the regroup on: it ends by this clock
var _next := 0.0                  # no new regroup before this clock
var _point := Vector2.INF
var _why := ""
var said: Array = []              # [clock, text] (the coach's tools read it)


const FARM_POWDER := 30.0         # powder in the bank: enough for three Musketeers


## (2) a built Farm with soil left is short of half its crew while the powder is banked: the Mills give a hand back.
func farms_starved(powder: float) -> bool:
	if powder < FARM_POWDER:
		return false
	for f in ai._mine("farm"):
		if f.built and not f.barren() and f.crew.size() * 2 < f.crew_max():
			return true
	return false


const ANSWER_R := 300.0           # (px) an armed enemy this near a labourer or a hall is at the labourers
const ANSWER_HOME := 700.0        # (px) our soldiers this near it count against it
const ANSWER_EDGE := 1.5          # ... worth this times it: no answer needed
const ANSWER_MAX := 3             # Musketeers in the queues at most for it
var _answer_said := -99.0


## (3) Musketeers for a raider among the labourers that nothing meets.
func raid_answer() -> void:
	if ai.peaceful:
		return
	var foes := {}
	for w in game.workers(ai.team):
		for o in game.units_near(w.position, ANSWER_R):
			if not o.dead and game.hostile(o.team, ai.team) and not o.is_worker() and o.armed() and not o.off_field \
					and not o.is_air() and game.is_visible_to(ai.team, o.position):
				foes[o] = true
	if foes.is_empty():
		return
	var theirs := 0.0
	var at := Vector2.ZERO
	for o in foes:
		theirs += float(Game.unit_value(o))
		at += o.position
	at /= foes.size()
	var ours := 0.0
	for u in game.army(ai.team):
		if u.armed() and u.position.distance_to(at) < ANSWER_HOME:
			ours += float(Game.unit_value(u))
	if ours >= theirs * ANSWER_EDGE:
		return
	var queued := 0
	var free: Array = []
	for b in ai._mine("barracks"):
		if b.built:
			queued += b.queue.count("musketeer")
			if b.queue.size() < 2:
				free.append(b)
	var want := mini(ANSWER_MAX, int(ceil((theirs * ANSWER_EDGE - ours) / 60.0)))
	var n := 0
	for b in free:
		if queued + n >= want:
			break
		if game.train(b, "musketeer") == "":
			n += 1
	if n > 0 and game.clock - _answer_said > 45.0:
		_answer_said = game.clock
		_say("trains %d Musketeer%s first: raiders (%d) at its labourers and no soldier to meet them" % [n, "" if n == 1 else "s", int(theirs)])


func _init(owner) -> void:
	ai = owner
	game = owner.game


func _say(s: String) -> void:
	said.append([snappedf(game.clock, 0.1), s])
	if game.mlog:
		game.mlog.add("%s%s%s" % [game.mlog.who(ai.team), "" if s.begins_with("'s") else " ", s])


static func _value(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += float(Game.unit_value(u))
	return v


## Called every army think while the wave is out (AI._army, attacking): true = the wave is regrouping and its men are
## not to be sent on this think.
func cohesion(wave: Array, target: Vector2) -> bool:
	var ground: Array = wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and not u.is_air() and not u.off_field)
	if ground.size() < 4 or not ai._siege.is_empty():
		return _end(ground, target, "")
	# the BODY: the men within BODY_R of the one with the most others near him (stragglers far behind, a man still at the
	# gate, do not make a strung-out wave: they are called up to the body and not counted)
	var body := _body(ground)
	if body.size() < 4:
		return _end(ground, target, "")
	var c := Vector2.ZERO
	for u in body:
		c += u.position
	c /= body.size()
	var spread := 0.0
	for u in body:
		spread += u.position.distance_to(c)
	spread /= body.size() * Defs.TILE
	# in contact: it fights where it stands
	for u in ground:
		for o in game.units_near(u.position, CONTACT_R):
			if not o.dead and game.hostile(o.team, ai.team) and not o.is_worker() and o.has_attack() and not o.off_field \
					and game.is_visible_to(ai.team, o.position) and o.position.distance_to(u.position) < CONTACT_R:
				return _end(ground, target, "")
	if _until > 0.0:
		if spread <= DONE_SPREAD or game.clock >= _until:
			return _end(ground, target, "goes on together (%.1f tiles apart)" % spread)
		_orders(ground, target)
		return true
	if game.clock < _next:
		return false
	var mine := _value(ground)
	var ahead := 0.0
	for o in game.units_near(c, SEE_R):
		if not o.dead and game.hostile(o.team, ai.team) and not o.is_worker() and o.has_attack() and not o.off_field \
				and game.is_visible_to(ai.team, o.position):
			ahead += float(Game.unit_value(o))
	var want := SPREAD_MAX
	_why = "strung out on the march"
	if ahead >= mine * SEE_SHARE:
		want = FORM_SPREAD
		_why = "forms up before the enemy army ahead (%d)" % int(ahead)
	if spread <= want:
		return false
	_point = _meeting_point(body, c, target)
	_until = game.clock + REGROUP_MAX
	_say("'s wave %s: %d men %.1f tiles apart close up before going on" % [_why, body.size(), spread])
	_orders(ground, target)
	return true


const BODY_R := 12.0             # (tiles)


func _body(ground: Array) -> Array:
	var r2 := pow(BODY_R * Defs.TILE, 2)
	var best: Unit = null
	var bn := -1
	for u in ground:
		var k := 0
		for o in ground:
			if o.position.distance_squared_to(u.position) < r2:
				k += 1
		if k > bn:
			bn = k
			best = u
	return ground.filter(func(o) -> bool: return o.position.distance_squared_to(best.position) < r2)


## Where the wave meets: its middle, pulled to the man nearest it (a cell it can stand on), never past it toward the target.
func _meeting_point(ground: Array, c: Vector2, _target: Vector2) -> Vector2:
	var best: Unit = null
	var bd := INF
	for u in ground:
		var d: float = u.position.distance_to(c)
		if d < bd:
			bd = d
			best = u
	return best.position if best else c


func _orders(ground: Array, target: Vector2) -> void:
	var to_t: float = _point.distance_to(target)
	for u in ground:
		if u.has_method("deploys") and u.deploys() and u.tesla_mode == "deployed":
			continue
		var d: float = u.position.distance_to(_point)
		var ahead: bool = u.position.distance_to(target) < to_t
		if d <= HEAD_R * Defs.TILE or ahead:
			# (the head waits where it is: walking back costs as much as the tail walking up. Riders stop in the saddle: a
			# Dragoon told to hold gets off his horse)
			if u.is_mounted() or u.kind == "dragoon":
				if u.order != "idle":
					u.cmd_stop()
			elif u.order != "hold":
				u.cmd_hold()
		else:
			if not (u.order in ["amove", "d_amove"] and u.order_point.distance_to(_point) < 60.0):
				u.cmd_move(_point + Vector2(randf_range(-40, 40), randf_range(-40, 40)), true)


func _end(ground: Array, target: Vector2, why: String) -> bool:
	if _until <= 0.0:
		return false
	_until = -1.0
	_next = game.clock + REGROUP_COOL
	if why != "":
		_say("'s wave %s" % why)
	for u in ground:
		if u.order in ["hold", "idle"] or (u.order in ["amove", "d_amove"] and u.order_point.distance_to(_point) < 80.0):
			u.cmd_move(target + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)
	return false
