class_name AIBroodBuilds
extends RefCounted
## THE BROOD'S WRITTEN BUILDS (brood-builds, docs/brood_builds.md): two plans of the Brood computer (AIBroodNew) with a
## push of their own. AIBroodNew owns this (`bb`, made when its plan has a "build") and calls it from small hooks
## (`_nb_army` before a wave leaves and when it has left, `_nb_wave_tick` every think of a wave, `_nb_warrior`,
## `_nb_research`, `_nb_spoils_want`). Everything else is the Brood computer as it is (its economy, its defence, its
## retreat rules): the builds only decide WHEN the first push goes, WHAT it is made of and HOW it walks in.
##
## SPITTER TIMING ("spitter"): the Venom Sire right after the Tyrant Sire, Spitters ahead of Raptors (about one for one),
## the Venom line's Bigger Clutch then Long Spit, the economy growing behind it (grubs on the curve, the natural and a
## turtle on new ground). THE TIMING: the wave leaves at the plan's time (wave_t) once TIMING_SP Spitters stand and Long
## Spit is in (or at the latest TIMING_LATE with what it has). It walks at the Spitters' pace: the Raptors keep just ahead
## of the Spitters' middle (FRONT tiles) instead of running ahead alone; on contact (enemy soldiers or a defence within
## CONTACT tiles of the Spitters) the Raptors go in and the Spitters spit from behind them. A lost fight comes home (the
## Brood computer's retreat rules), and after it the plan plays on (waves every `step` supply).
##
## BRUTE SIEGE ("brute"): her stage 3 early (Brutes need it), BRUTES_GO Brutes and BATTERING HORNS before the push. The
## push finds the BARRIER: the wall piece where the way to its goal is walled off (Game.find_path stops at it), or, with
## no wall in the way, the Ratchet Turret nearest the way in. MARCH: everyone to a gathering spot STAGE_D tiles short of it.
## BREAK: the Brutes batter the barrier, the Spitters spit at what shoots them from SPIT_D tiles, the Raptors wait at the
## gathering spot and only bite what comes out to them. BREACH: the barrier falls: the next barrier on the way (a
## second turret near it, a wall still in the way), or everyone goes in through the gap to the goal. BACK: every Brute
## dead before the breach, or no headway (the barrier under BREAK_HP of its health after BREAK_T s): the wave comes home.

const TIMING_SP := 10            # Spitters (young or mature) before the timing goes
const TIMING_LATE := 480.0       # (s) it goes then with what it has (TIMING_MIN supply at least)
const TIMING_MIN := 16
const FRONT := 2.0               # (tiles) the Raptors keep this far ahead of the Spitters' middle on the march
const CONTACT := 11.0            # (tiles) enemy soldiers or a defence this near the Spitters: the fight starts
const BRUTES_GO := 4             # Brutes before the siege push (and Battering Horns)
const BRUTE_LATE := 180.0        # (s) after wave_t it goes with BRUTES_MIN Brutes, horns or not
const BRUTES_MIN := 2
const STAGE_D := 8.0             # (tiles) the gathering spot short of the barrier (a Musketeer reaches 4 to 5)
const SPIT_D := 5.0              # (tiles) the Spitters stand this far from the barrier (range 165 px, 190 with Long Spit)
const BREAK_T := 70.0            # (s) no headway after this long at the barrier ...
const BREAK_HP := 0.5            # ... the barrier still over this share of its health: back
const NEXT_R := 9.0              # (tiles) a second barrier this near the fallen one is broken too
const BARRIERS := ["wall", "gate", "palisade", "tower", Defs.CW_TURRET]

var ai                           # the AIBroodNew
var game: Game
var kind := ""                   # "spitter" or "brute"
var phase := ""                  # "" (no push of its own), "march", "break", "in" (spitter: "march", "fight")
var barrier: Building = null
var barrier_p := Vector2.INF
var stage_p := Vector2.INF       # the gathering spot short of the barrier
var goal := Vector2.INF          # where the push goes once in
var _t0 := 0.0                   # when the phase began
var _hp0 := 0.0
var _orders_t := 0.0
var _gather_t := 0.0
var timings_done := 0            # the spitter timing went (it plays on as its plan afterwards)
var pushes: Array = []           # one dict a push (the coach and the tests read it): t0, sup, kinds, spitters, brutes,
                                 # contact, breach (clock), broke (kinds), end, why
var cur := {}
var log: Array = []              # [clock, text]


func _init(a, k: String) -> void:
	ai = a
	game = a.game
	kind = k


func say(s: String) -> void:
	log.append([game.clock, s])
	ai.say(s)


func _count(k: String) -> int:
	return BroodNew.count_of(game, ai.team, k)


func spitters() -> int:
	return _count("spitter") + _count("venom_challenger")


# ------------------------------------------------------------------ before a wave leaves

## Does this build decide when the next wave goes (instead of the plan's size, edge and wall rules)?
func decides() -> bool:
	if kind == "spitter":
		return timings_done == 0
	return kind == "brute" and (_count("brute") > 0 or game.clock < float(ai.plan["wave_t"]) + BRUTE_LATE)


## The build's own go: true when its push may leave now (the army gathered is then checked by AIBroodNew as always).
func may_go(q: Unit, army: Array, sup: int) -> bool:
	var t_go := float(ai.plan["wave_t"])
	if kind == "spitter":
		var sp := spitters()
		var long := game.has_tech(ai.team, "nb_long_spit")
		var late := game.clock >= TIMING_LATE
		if game.clock < t_go:
			return false
		if not late and (sp < TIMING_SP or (not long and BroodResearch.in_hand(game, ai.team, "nb_long_spit"))):
			return false
		if sup < (TIMING_MIN if late else int(ai.plan["wave"])) and not late:
			return false
		if sup < TIMING_MIN:
			return false
		# not into a hopeless fight (the Brood's own rule, a little bolder: a timing is meant to hit)
		if ai.seen_army > 0.0 and ai._value_of(army) < ai.seen_army * float(ai.plan.get("edge", 0.6)) * 0.85 and not late:
			return false
		return true
	# the Brute siege
	var br := _count("brute")
	var horns := game.has_tech(ai.team, "nb_battering_horns")
	var late2 := game.clock >= t_go + BRUTE_LATE
	if game.clock < t_go:
		return false
	if br < (BRUTES_MIN if late2 else BRUTES_GO) or (not horns and not late2):
		return false
	if sup < int(ai.plan["wave"]) and not late2:
		return false
	if ai.seen_army > 0.0 and ai._value_of(army) < ai.seen_army * float(ai.plan.get("edge", 0.6)) and not late2:
		return false
	return true


## The wave has left (AIBroodNew._nb_army): the build takes it over.
func started(q: Unit, wave: Array, to: Vector2) -> void:
	goal = to
	_t0 = game.clock
	_orders_t = 0.0
	cur = {"t0": game.clock, "sup": ai._wave_sup, "kinds": ai._kinds_of(wave), "spitters": 0, "brutes": 0,
		"contact": -1.0, "breach": -1.0, "broke": {}, "end": -1.0, "why": "", "v0": ai._wave_v0, "k0": int(game.stats[ai.team]["value_killed"])}
	for u in wave:
		if u.kind in ["spitter", "venom_challenger"]:
			cur["spitters"] += 1
		elif u.kind == "brute":
			cur["brutes"] += 1
	pushes.append(cur)
	if kind == "spitter":
		timings_done += 1
		phase = "march"
		say("spitter timing: goes out at %s: %d supply, %d Spitters behind %d Raptors" % [ai._mmss(), ai._wave_sup,
			cur["spitters"], wave.filter(func(u) -> bool: return u.kind in ["raptor", "tyrant_challenger"]).size()])
		return
	if int(cur["brutes"]) == 0:
		phase = ""
		return
	_find_barrier(q, ai._nb_stage_point(q))
	phase = "march"
	if barrier != null:
		say("brute siege: goes out: %d supply, %d Brutes lead it to the %s" % [ai._wave_sup, cur["brutes"], _name(barrier)])
		ai._wave_target = stage_p
		for u in wave:
			u.cmd_move(stage_p, true)
	else:
		say("brute siege: goes out: %d supply, %d Brutes in front (no wall or turret in its way)" % [ai._wave_sup, cur["brutes"]])


## The wave is over (pulled back, called home, or gone): the build lets go.
func ended(why: String) -> void:
	if not cur.is_empty() and float(cur["end"]) < 0.0:
		cur["end"] = game.clock
		cur["why"] = why
		cur["killed"] = int(game.stats[ai.team]["value_killed"]) - int(cur["k0"])
	phase = ""
	barrier = null


func _name(b: Building) -> String:
	return String(Defs.BUILDINGS.get(b.kind, {}).get("name", b.kind)) if b != null else "?"


# ------------------------------------------------------------------ the wave out

## Every think of a wave out (after the Brood's retreat rules): 0 = the build leaves the wave to the Brood computer,
## 1 = the build steers it this think, 2 = call it back.
func tick(q: Unit, wave: Array, mid: Vector2) -> int:
	if phase == "" or wave.is_empty():
		return 0
	if kind == "spitter":
		return _tick_timing(wave, mid)
	return _tick_siege(q, wave, mid)


## The Spitters' middle and the way on.
func _sp_mid(wave: Array) -> Vector2:
	var m := Vector2.ZERO
	var n := 0
	for u in wave:
		if u.kind in ["spitter", "venom_challenger"]:
			m += u.position
			n += 1
	return m / n if n > 0 else Vector2.INF


func _enemy_near(p: Vector2, r: float, soldiers_only := false) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for u in game.units_near(p, r):
		if game.hostile(u.team, ai.team) and not u.dead and not u.off_field and u.has_attack() and not u.is_worker() \
				and game.is_visible_to(ai.team, u.position):
			var d: float = u.position.distance_to(p)
			if d < bd:
				bd = d
				best = u.position
	if soldiers_only:
		return best
	for b in ai._foe_blds:
		if is_instance_valid(b) and not b.dead and b.kind in [Defs.CW_TURRET, "tower"]:
			var d: float = (ai._foe_blds[b] as Vector2).distance_to(p)
			if d < r and d < bd:
				bd = d
				best = ai._foe_blds[b]
	return best


func _tick_timing(wave: Array, mid: Vector2) -> int:
	var sm := _sp_mid(wave)
	if sm == Vector2.INF:
		phase = ""
		return 0
	var foe := _enemy_near(sm, CONTACT * Defs.TILE)
	if foe != Vector2.INF or sm.distance_to(ai._wave_target) < 6.0 * Defs.TILE:
		# CONTACT: the Raptors go in, the Spitters spit from behind them (both attack-move on what they see)
		phase = ""
		cur["contact"] = game.clock
		var at: Vector2 = foe if foe != Vector2.INF else ai._wave_target
		say("spitter timing: contact at %s, %d tiles out: the Raptors go in, the Spitters spit from behind" % [ai._mmss(),
			int(sm.distance_to(BroodNew.queen(game, ai.team).position) / Defs.TILE) if BroodNew.queen(game, ai.team) else 0])
		for u in wave:
			if u.kind in ["spitter", "venom_challenger"]:
				u.cmd_move(at, true)
			elif u.target == null:
				u.cmd_move(at + (at - sm).normalized() * 1.5 * Defs.TILE, true)
		return 0
	if game.clock < _orders_t:
		return 1
	_orders_t = game.clock + 1.5
	# THE MARCH at the Spitters' pace: the Spitters attack-move on; the rest keep FRONT tiles ahead of their middle
	var dir: Vector2 = (ai._wave_target - sm).normalized()
	var front: Vector2 = sm + dir * FRONT * Defs.TILE
	for u in wave:
		if u.target != null and is_instance_valid(u.target):
			continue
		if u.kind in ["spitter", "venom_challenger"]:
			if u.order == "idle" or u.order == "hold" or u.path_goal.distance_to(ai._wave_target) > 60.0:
				u.cmd_move(ai._wave_target, true)
		else:
			var ahead: float = (u.position - sm).dot(dir)
			if ahead > (FRONT + 1.5) * Defs.TILE or u.position.distance_to(front) > 4.0 * Defs.TILE:
				u.cmd_move(front, true)
			elif u.order == "idle" or u.order == "hold":
				u.cmd_move(front + dir * 1.0 * Defs.TILE, true)
	return 1


## THE BARRIER: the wall piece where the way from `from` to the goal is walled off (the pathfinder's way ends short of
## the goal; the known wall piece nearest that end), else the known Ratchet Turret nearest the way in (within 10 tiles of
## the goal or the straight way to it).
func _find_barrier(q: Unit, from: Vector2) -> void:
	barrier = null
	barrier_p = Vector2.INF
	if goal == Vector2.INF:
		return
	var path := game.find_path(from, goal)
	var end: Vector2 = path[path.size() - 1] if path.size() > 0 else from
	if end.distance_to(goal) > 3.0 * Defs.TILE:
		var bd := 5.0 * Defs.TILE
		for b in ai._foe_blds:
			if is_instance_valid(b) and not b.dead and b.kind in ["wall", "gate", "palisade", "tower"]:
				var d: float = (ai._foe_blds[b] as Vector2).distance_to(end)
				if d < bd:
					bd = d
					barrier = b
	if barrier == null:
		var bd := INF
		for b in ai._foe_blds:
			if is_instance_valid(b) and not b.dead and b.kind == Defs.CW_TURRET:
				var p: Vector2 = ai._foe_blds[b]
				var off := _off_line(p, from, goal)
				if p.distance_to(goal) < 10.0 * Defs.TILE or off < 6.0 * Defs.TILE:
					var d := p.distance_to(from)
					if d < bd:
						bd = d
						barrier = b
	if barrier != null:
		_set_barrier(barrier, from)


func _off_line(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	if ab.length_squared() < 1.0:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _set_barrier(b: Building, from: Vector2) -> void:
	barrier = b
	barrier_p = b.center()
	_hp0 = b.hp
	var dir: Vector2 = (barrier_p - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	stage_p = _open_spot(barrier_p - dir * STAGE_D * Defs.TILE, from)


## A walkable spot near p on the way from `from` (else a little nearer to `from`).
func _open_spot(p: Vector2, from: Vector2) -> Vector2:
	for i in 6:
		var c := game.cell_of(p)
		if ai._nb_on_map(p) and game._walkable(c):
			return p
		p = p.lerp(from, 0.2)
	return from


func _tick_siege(q: Unit, wave: Array, mid: Vector2) -> int:
	var brutes: Array = wave.filter(func(u) -> bool: return u.kind == "brute")
	if barrier == null:
		if phase == "march" and brutes.size() > 0 and mid.distance_to(ai._wave_target) < 16.0 * Defs.TILE and game.clock >= _orders_t:
			# (no barrier known when it left: look again on the way, the scout may not have seen the wall)
			_orders_t = game.clock + 3.0
			_find_barrier(q, mid)
			if barrier != null:
				say("brute siege: a %s bars the way: the Brutes go for it" % _name(barrier))
				ai._wave_target = stage_p
				for u in wave:
					u.cmd_move(stage_p, true)
				return 1
		return 0
	# the barrier fell: THE BREACH
	if not is_instance_valid(barrier) or barrier.dead:
		var was := _name(barrier) if is_instance_valid(barrier) else "barrier"
		var bk: String = barrier.kind if is_instance_valid(barrier) else "wall"
		cur["broke"][bk] = int(cur["broke"].get(bk, 0)) + 1
		var fallen := barrier_p
		barrier = null
		# the next one on the way: a turret near the fallen one, a wall still in the way
		var nxt: Building = null
		var nd := NEXT_R * Defs.TILE
		for b in ai._foe_blds:
			if is_instance_valid(b) and not b.dead and b.kind == Defs.CW_TURRET and (ai._foe_blds[b] as Vector2).distance_to(fallen) < nd:
				nd = (ai._foe_blds[b] as Vector2).distance_to(fallen)
				nxt = b
		if nxt == null:
			_find_barrier(q, stage_p)
			nxt = barrier
			if nxt != null and nxt.center().distance_to(fallen) > 14.0 * Defs.TILE:
				nxt = null          # (a wall far from this one is another way in: go in here)
		if nxt != null and brutes.size() > 0:
			_set_barrier(nxt, stage_p)
			phase = "break"
			_t0 = game.clock
			_orders_t = 0.0
			say("brute siege: the %s falls; the Brutes go on to the %s" % [was, _name(nxt)])
			return 1
		if float(cur["breach"]) < 0.0:
			cur["breach"] = game.clock
		phase = "in"
		say("brute siege: BREACH at %s: the %s falls and the army goes in through the gap" % [ai._mmss(), was])
		var g2: Vector2 = ai._nb_wave_goal(q)
		if g2 != Vector2.INF:
			goal = g2
		ai._wave_target = goal
		for u in wave:
			u.cmd_move(goal, true)
		phase = ""
		return 0
	# BACK: no Brute left before the breach, or no headway
	if brutes.is_empty():
		say("brute siege: falls back: its Brutes are dead and the %s stands (%d hp)" % [_name(barrier), int(barrier.hp)])
		return 2
	if phase == "break" and game.clock - _t0 > BREAK_T and barrier.hp > _hp0 * BREAK_HP:
		say("brute siege: falls back: no headway at the %s in %d s" % [_name(barrier), int(game.clock - _t0)])
		return 2
	if phase == "march":
		var bm := Vector2.ZERO
		for u in brutes:
			bm += u.position
		bm /= brutes.size()
		if bm.distance_to(stage_p) < 3.0 * Defs.TILE or (game.clock - _t0 > 25.0 and mid.distance_to(stage_p) < 4.0 * Defs.TILE) \
				or bm.distance_to(barrier_p) < (STAGE_D - 1.0) * Defs.TILE:
			phase = "break"
			_t0 = game.clock
			_hp0 = barrier.hp
			_orders_t = 0.0
			cur["contact"] = game.clock if float(cur["contact"]) < 0.0 else cur["contact"]
			say("brute siege: the Brutes batter the %s, the Spitters cover them, the Raptors wait for the breach" % _name(barrier))
		else:
			if game.clock >= _orders_t:
				_orders_t = game.clock + 2.0
				for u in wave:
					if (u.order == "idle" or u.order == "hold") and u.target == null:
						u.cmd_move(stage_p, true)
			return 1
	if game.clock < _orders_t:
		return 1
	_orders_t = game.clock + 1.2
	var dir: Vector2 = (barrier_p - stage_p).normalized()
	var spit_p := _open_spot(barrier_p - dir * SPIT_D * Defs.TILE, stage_p)
	for u in wave:
		if u.kind == "brute":
			if u.target != barrier:
				u.cmd_attack(barrier)
		elif u.kind in ["spitter", "venom_challenger", "dilophosaurus", "mist_toad"]:
			if u.target == null and u.position.distance_to(spit_p) > 2.0 * Defs.TILE:
				u.cmd_move(spit_p, true)
		else:
			# Raptors and the rest wait at the gathering spot (they bite what comes out to them)
			if u.target == null and u.position.distance_to(stage_p) > 3.0 * Defs.TILE:
				u.cmd_move(stage_p, true)
			elif u.target != null and is_instance_valid(u.target) and u.target is Unit \
					and (u.target as Unit).position.distance_to(barrier_p) < 3.0 * Defs.TILE and u.position.distance_to(stage_p) > 5.0 * Defs.TILE:
				u.cmd_move(stage_p, false)          # (not into the musket line behind the wall: back to the spot)
	return 1


# ------------------------------------------------------------------ what it lays and researches

## The most Brutes the plan wants at once (AIBroodNew._nb_warrior's cap), 0 = the Brood's own rule.
func brute_cap() -> int:
	return int(ai.plan.get("brutes", 0)) if kind == "brute" else 0


## Research this build wants first (AIBroodNew._nb_research puts them before its own list).
func research_first() -> Array:
	var out: Array = []
	if kind == "spitter":
		var sp := spitters()
		if sp >= 2:
			out.append("nb_clutch_spitter")
		if sp >= 5 and game.has_tech(ai.team, "nb_clutch_spitter"):
			out.append("nb_long_spit")
	elif kind == "brute":
		if _count("brute") >= 2:
			out.append("nb_battering_horns")
	return out


## Spoils it wants in hand (AIBroodNew._nb_spoils_want): Spitter eggs and the line's research; Brutes and the horns.
func spoils_want(q: Unit) -> float:
	if kind == "spitter":
		if BroodNew.count_of(game, ai.team, BroodNew.DILO) > 0 and timings_done == 0:
			return 30.0
		return 0.0
	if kind == "brute" and BroodNew.stage(q) >= 2:
		var need := 0.0
		if _count("brute") < BRUTES_GO:
			need += float(Defs.UNITS["brute"].get("cost2", 20)) * 2.0
		if not game.has_tech(ai.team, "nb_battering_horns"):
			need += float(Defs.RESEARCH["nb_battering_horns"]["cost2"])
		return need
	return 0.0
