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
## 4. A RAID DOES NOT HOLD THE SIEGE AT HOME (coached: red coast 1164): the Siege push sat at home from 11:00 to 15:00 with
##    2,050-2,880 of army because "an enemy force (465) is at our buildings": riders coming and going at its edge. A force
##    under SMALL_SHARE of the push's own value is the guards' business; the push goes (AICrownSiege._maybe_go).
## 5. THE GUNS SHELL THE HALL (coached: Frostmere 1148 12:11-14:12, Highmoor 1143 12:39-14:30): a wave that had won the
##    field broke palisade after palisade (14 pieces one by one, "down in ~1 s" each, the next one behind it) to walk to a
##    walled hall, while its Field Cannons (430 px: 200 a shot on a building) fired at the same palisades. A human brings
##    the guns up to the hall's wall and shells the hall over it (three cannons take a Town Hall in about 12 s). Now the
##    wave's guns within GUN_NEAR of the target hall go to a spot outside its wall in range of the hall and fire at the
##    hall itself; the siege leaves them alone (AI._siege_skip).
## 7. THE LINE HOLDS OFF WHILE THE GUNS SHELL THE HALL (coached: Greenhold 1103 after fix 5, 8:03: the Timing attack's
##    1,395 against 750 pulled back from the enemy natural's gate "down in ~2 s, too dear under 79 dps of fire": the musket
##    line on the cliff above the gate; the wave went home with its three Field Cannons, which outrange those muskets by
##    240 px). A siege weighed up as lost with BOMBARD_GUNS guns in the wave: the men without guns stand back out of reach
##    (the siege's own retreat spot) and the guns shell the hall for BOMBARD_T s; then the siege is weighed up again (once
##    a hall every BOMBARD_COOL s).
## 6. THE WINNER FINISHES (coached: Frostmere 1148 and Thornwood 1136 after fix 5, 13:21-14:50): the hunt (rules-fixes,
##    scripts/ai_hunt.gd) began and ended every 5-15 s ("the enemy has an army again": one Musketeer out of a Barracks), and
##    went for the nearest building (a Cottage, a palisade) first. In the mirror it goes on over a TOKEN army (under
##    TOKEN_SHARE of ours and under TOKEN_MAX, ours TOKEN_OURS or more) and goes for the halls first, then the rest.

const SPREAD_MAX := 5.0          # (tiles) the wave's mean distance from its middle that calls a regroup on the march
const FORM_SPREAD := 3.0         # (tiles) ... with an enemy army in sight ahead
const DONE_SPREAD := 2.2         # (tiles) a regroup ends when the wave is this close together
const SEE_R := 720.0             # (px) an enemy army this near the wave's middle is "ahead"
const SEE_SHARE := 0.25          # ... when worth this share of the wave at least (a lone scout is not)
const CONTACT_R := 300.0         # (px) an armed enemy this near any man of the wave: it fights, no regroup
const REGROUP_MAX := 14.0        # (s) a regroup ends by then whatever the spread
const REGROUP_COOL := 18.0       # (s) between regroups
const SIEGE_NEAR := 560.0        # (px) the wave's body this near the siege's piece: the siege's own orders, no regroup
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


const GUN_KINDS := ["cannon", "mortar"]
const GUN_NEAR := 900.0           # (px) guns this near the target hall go for it
const GUN_SPOT_STEP := 16         # spots tried round the hall
var gunners := {}                 # gun -> the hall it shells (AI._siege_skip)
var _gun_spot := {}               # gun -> [spot, clock it was picked]
var _gun_said = null


## (5) the wave's guns on the enemy hall over its wall.
func guns_at_hall(wave: Array, target: Vector2, force := false) -> void:
	for gu in gunners.keys():
		if not is_instance_valid(gu) or gu.dead or not wave.has(gu) or not is_instance_valid(gunners[gu]) or gunners[gu].dead:
			gunners.erase(gu)
			_gun_spot.erase(gu)
	if target == Vector2.INF:
		return
	var hall: Building = null
	var hd := INF
	for b in game.buildings:
		if not b.dead and not b.ghost and game.hostile(b.team, ai.team) and b.kind == game.faction_hall(b.team):
			var d: float = b.center().distance_to(target)
			if d < hd:
				hd = d
				hall = b
	if hall == null or hd > 400.0:
		return
	var said := false
	for gu in wave:
		if not is_instance_valid(gu) or gu.dead or not GUN_KINDS.has(gu.kind) or (gu.position.distance_to(hall.center()) > GUN_NEAR and not force and not bombarding()):
			continue
		var rng: float = float(gu.d["range"])
		if not gunners.has(gu):
			said = true
		gunners[gu] = hall
		if hall.edge_distance(gu.position) <= rng - 12.0 and hall.edge_distance(gu.position) >= float(gu.d.get("min_range", 0)) + 8.0:
			if not (gu.order == "attack" and gu.order_target == hall):
				gu.cmd_attack(hall)
			continue
		var sp: Array = _gun_spot.get(gu, [])
		if sp.is_empty() or game.clock - float(sp[1]) > 12.0:
			var spot := _spot_for(gu, hall, rng)
			if spot == Vector2.INF:
				gunners.erase(gu)
				continue
			sp = [spot, game.clock]
			_gun_spot[gu] = sp
		if gu.order != "move" or gu.order_point.distance_to(sp[0]) > 20.0:
			gu.cmd_move(sp[0])
	if said and _gun_said != hall:
		_gun_said = hall
		_say("brings its guns up to shell the enemy hall over its wall")


## A spot in range of the hall (and outside its own minimum range) the gun can walk to: round the hall, the nearest to it.
func _spot_for(gu: Unit, hall: Building, rng: float) -> Vector2:
	var hc: Vector2 = hall.center()
	var half: float = maxf(hall.rect().size.x, hall.rect().size.y) * 0.5
	var best := Vector2.INF
	var bd := INF
	var from: Vector2i = game.cell_of(gu.position)
	var flood: PackedByteArray = ai._flood_from([from], ai.team)
	for k in GUN_SPOT_STEP:
		var a := TAU * k / GUN_SPOT_STEP
		for r in [rng * 0.85, rng * 0.7]:
			var p: Vector2 = hc + Vector2(cos(a), sin(a)) * (float(r) + half * 0.6)
			var c: Vector2i = game.cell_of(p)
			if not game.in_map(c) or flood[game.idx(c)] != 1:
				continue
			if hall.edge_distance(p) > rng - 16.0 or hall.edge_distance(p) < float(gu.d.get("min_range", 0)) + 16.0:
				continue
			if _under_fire(p):
				continue             # (out of reach of the shooters it sees: a gun under the cliff's muskets died, 8:30)
			var d: float = p.distance_to(gu.position)
			if d < bd:
				bd = d
				best = game.cell_center(c)
	return best


const BOMBARD_GUNS := 2
const BOMBARD_T := 40.0
const BOMBARD_COOL := 120.0
var _bomb_until := -1.0
var _bomb_hall = null
var _bomb_back := Vector2.INF
var _bomb_last := {}              # hall -> clock of its last bombardment


func bombarding() -> bool:
	if _bomb_until < 0.0:
		return false
	if not ai._attacking or game.clock >= _bomb_until or _bomb_hall == null or not is_instance_valid(_bomb_hall) or _bomb_hall.dead or gunners.is_empty():
		_bomb_until = -1.0
		if game.clock > 0.0:
			_say("stops shelling: %s" % ("the hall is down" if _bomb_hall == null or not is_instance_valid(_bomb_hall) or _bomb_hall.dead else ("its guns are gone" if gunners.is_empty() else "the time is up")))
		_bomb_hall = null
		return false
	return true


## (7) the siege says pull back: the guns shell the hall instead, the rest out of reach.
func bombard(wave: Array, _piece: Building, back: Vector2, target: Vector2) -> bool:
	var guns: Array = wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and GUN_KINDS.has(u.kind))
	if guns.size() < BOMBARD_GUNS or target == Vector2.INF:
		return false
	var hall: Building = null
	for b in game.buildings:
		if not b.dead and not b.ghost and game.hostile(b.team, ai.team) and b.kind == game.faction_hall(b.team) and b.center().distance_to(target) < 400.0:
			hall = b
	if hall == null or game.clock - float(_bomb_last.get(hall, -999.0)) < BOMBARD_COOL:
		return false
	_bomb_last[hall] = game.clock
	_bomb_hall = hall
	_bomb_until = game.clock + BOMBARD_T
	_bomb_back = back
	_until = -1.0                     # (no regroup meanwhile)
	for u in wave:
		if is_instance_valid(u) and not u.dead and not GUN_KINDS.has(u.kind):
			u.siege_t = 0.0
			u.cmd_move(back + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
			u.wall_flee_t = 10.0      # (a plain walk out of reach, as the siege's own pull-back: on an attack-move the men
			                          # stopped to shoot at the gate under the cliff and died there, Greenhold 1103 8:15)
	_say("holds its line out of reach and shells the enemy hall with %d guns" % guns.size())
	guns_at_hall(wave, hall.center(), true)
	return true


const TOKEN_SHARE := 0.15
const TOKEN_MAX := 450.0
const TOKEN_OURS := 1200.0        # (our army at least: not a 6:00 all-in for one enemy Musketeer)


## (6) the enemy's army is a token beside ours: the hunt goes on.
func hunt_anyway(foe_t: int, army: Array) -> bool:
	var theirs := 0.0
	for u in game.units:
		if AIHunt.fighter(u, foe_t):
			theirs += float(Game.unit_value(u))
	var mine := _value(army)
	return mine >= TOKEN_OURS and theirs < TOKEN_MAX and theirs < mine * TOKEN_SHARE


## (6) the hunt's goal: the enemy's nearest hall, else its nearest building (the shared rule).
func hunt_goal(foe_t: int, from: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for b in game.buildings:
		if b.team == foe_t and not b.dead and not b.ghost and b.kind == game.faction_hall(foe_t):
			var d: float = b.center().distance_to(from)
			if d < bd:
				bd = d
				best = b.center()
	return best if best != Vector2.INF else AIHunt._target(game, foe_t, from)


## A spot in reach of an enemy shooter we see (a Musketeer on the cliff, a gun), with a margin.
func _under_fire(p: Vector2) -> bool:
	for o in game.units_near(p, 300.0):
		if not o.dead and game.hostile(o.team, ai.team) and not o.is_worker() and o.has_attack() and not o.off_field \
				and float(o.d.get("range", 0.0)) >= 100.0 and game.is_visible_to(ai.team, o.position) \
				and o.position.distance_to(p) < float(o.d["range"]) + 50.0:
			return true
	return false


const SMALL_SHARE := 0.25


## (4) the force at our buildings is small beside the push.
func threat_small(near: float, push: float) -> bool:
	return near < push * SMALL_SHARE


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
	if bombarding():
		return true                   # (7: the line stays out of reach, the guns shell: nobody is sent on)
	var ground: Array = wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and not u.is_air() and not u.off_field)
	if ground.size() < 4:
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
	# a siege planned at a wall far off is a march to it: the wave closes up on the way (Dune Sea 1109, 7:00-7:45: the
	# Timing attack walked 70 tiles to the enemy's gate strung out over 11-28 tiles and died at it); at the wall the siege
	# has its own order (the stage, the face, the shooters' spots)
	var pc = ai._siege.get("piece")
	if pc != null and is_instance_valid(pc) and not pc.dead and c.distance_to(pc.center()) < SIEGE_NEAR:
		return _end(ground, target, "")
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


func regrouping() -> bool:
	return _until > 0.0


## Where the wave meets: the body's man nearest the target (its head waits where it stands; everyone behind walks up to it:
## a meeting point in the middle left the head and the tail both holding on either side of it, test_crown_mirror).
func _meeting_point(ground: Array, c: Vector2, target: Vector2) -> Vector2:
	var best: Unit = null
	var bd := INF
	for u in ground:
		var d: float = u.position.distance_to(target)
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
