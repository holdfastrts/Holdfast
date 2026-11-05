extends RefCounted
## THE PUSH (cw-builds-b, the owner's "do it all", 2026-11-03; docs/clockwork_builds_b.md): the Clockwork computer's slow,
## hard-to-stop push with its heavy machines, run by AIClockwork (scripts/ai_clockwork.gd) for two plans:
##  - PENDULUMS (against the Brood): Pendulums and Clock Soldiers in front, the escort Winders behind them; it walks to the
##    Brood's economy (its rooted Rootmaws and Mound Turtles, the grubs at them) and then to the Brood Mother.
##  - HEAVY WORKS PUSH: Clock Soldiers in front, Spring Ballistas behind them, the Great Winder behind those; against the
##    Crown it walks to its expansion or its main and SIEGES a wall from out of musket reach (the Ballistas reach 300, a
##    Musketeer 190); against the Brood the same as the Pendulums.
## How it moves: one ANCHOR point walks along the path to the goal, a step at a time, only when the front line is at it and
## the slow machines are close behind (so the block keeps together at the speed of its slowest machine). The FRONT (Clock
## Soldiers, Pendulums, Springers) stands at the anchor; the Ballistas BACK_BAL px behind it on the path; the Great Winder
## BACK_GW px behind; the escort Winders (AI._follow_with_escort) wind and mend behind the front.
## FIGHT: armed enemies near the front: the anchor stops, the front attack-moves at them; the Ballistas hold and shoot
## (Ballista.pick), and an enemy that reaches a Ballista is met by the two nearest front units while it rolls back.
## SIEGE: a wall or gate in the way (the path to the goal is walled): the front stands SIEGE_FRONT px from the piece (out of
## musket reach), the Ballistas SIEGE_BAL px (in their reach), aimed at the piece; when it falls the march goes on.
## RETREAT: the push is worth less than RETREAT_K of the armed enemies near it and has lost a third of what went out, or it
## has fewer than MIN_LEFT fighters: home, where it gathers again (the next push needs a little more).
## Reinforcements: fighters made after it left gather at home and join as a group of JOIN_SUPPLY supply or more.
## No cheating: it sees what its side sees (Game.is_visible_to) and knows where the enemy started (every computer does).

const STEP := 200.0             # px the anchor walks at a time
const FRONT_AT := 140.0         # the front is "at" the anchor within this
const BACK_BAL := 120.0         # px the Ballistas stand behind the anchor
const BACK_GW := 190.0          # px the Great Winder stands behind it
const HEAVY_LAG := 320.0        # the anchor waits for the Ballistas and the Great Winder within this of their spot
const LOOK := 380.0             # px round the front: armed enemies here start a fight
const CALM := 3.0               # s with no armed enemy near the front before the march goes on
const SCREEN_R := 260.0        # px from the anchor: the front meets the enemies within this, holds against the rest
const LEASH := 520.0           # px: a front unit farther than this from the anchor in a fight walks back to it (the plan's
                                # "leash": the Heavy Works push 360, 520 let its Clock Soldiers chase kiting Musketeers off)
const GUARD_R := 130.0          # an enemy this close to a Ballista: it rolls back, two front units meet it
const SIEGE_SEE := 340.0        # a wall or gate this close ahead of the anchor stops the march: the siege
const SIEGE_FRONT := 215.0      # the front stands this far from the piece (a Musketeer reaches 190 from behind it)
const SIEGE_BAL := 255.0        # the Ballistas this far (they reach 300)
const SIEGE_MAX := 150.0        # s at one piece at most
const GRIND := 0.4             # retreat when less than this share of what went out (and joined) is left
const OUTNUMBERED := 1.4       # retreat at once from armed enemies near worth this many times the push
const MAIN_K := 1.3            # it goes for the enemy's main only worth this many times the enemy army seen lately (else it holds)
const RETREAT_K := 0.65         # retreat when the push is worth less than this share of the armed enemies near it ...
const LOST_SHARE := 0.33        # ... and it has lost this share of what went out
const MIN_LEFT := 3             # fewer fighters than this left: home
const JOIN_SUPPLY := 6          # reinforcements join as a group of this much supply or more
const REPATH := 8.0             # s between two paths to the goal

var ai = null
var game: Game = null
var team := 0
var cfg := {}                   # the plan's "push" settings: {"need": {kind: n}, "min_supply", "vs_brood": {...}}
var units: Array = []           # the push (fighters, the Great Winder)
var phase := ""                 # "" (gathering at home), "march", "fight", "siege", "back"
var launched := false
var pushes := 0
var since := 0.0
var anchor := Vector2.INF
var goal := Vector2.INF
var goal_e = null               # the Unit or Building aimed at (Brood: a Rootmaw, a turtle, the Mother)
var path := PackedVector2Array()
var path_i := 0
var path_t := -99.0
var piece: Building = null      # the wall or gate being sieged
var piece_t := 0.0
var value0 := 0.0               # what went out (value)
var kill0 := 0                  # value killed when it went out
var need_up := 0                # supply the next push needs above the plan's (after a retreat)
var calm_t := 0.0
var foe := -1
var _orders := {}               # Unit -> [point, clock] the last move given (not given again and again)
var _brood_seen := {}           # id -> {"u", "p", "kind", "t"}: rooted Brood creatures and grubs seen
var _guards := {}               # front Unit -> the enemy it was sent to meet at a Ballista
var log_t := {}
var stats := {"pushes": 0, "sieges": 0, "pieces": 0, "retreats": 0, "goals": 0, "max_out": 0.0}
## (clockwork-army, scripts/ai_cw_army.gd: the army's own word before a push goes out: stronger than the enemy army it
## reckons, with a fresh report; an empty Callable = the plan's needs alone, as before)
var gate := Callable()


func _init(a, settings: Dictionary) -> void:
	ai = a
	game = a.game
	team = a.team
	cfg = settings


func has(u: Unit) -> bool:
	return units.has(u) or joining.has(u)


func say(s: String) -> void:
	ai.note("push: " + s)


func _phase(p: String) -> void:
	if phase != p:
		phase = p
		since = game.clock


# ------------------------------------------------------------------ who goes

func _front_kind(u: Unit) -> bool:
	return u.kind == "clock_soldier" or u.kind == Defs.PENDULUM or u.kind == Defs.SPRINGER or u.kind == Defs.NETTER


func _heavy(u: Unit) -> bool:
	return u.kind == Defs.BALLISTA_KIND


## The army at home the push may take: ground fighters and the Great Winder, not the Springer raid's, not a harasser, not
## a flyer, not a run-down statue.
func _home_army() -> Array:
	var out: Array = []
	for u in game.army(team):
		if u.is_air() or u.powered_down() or units.has(u):
			continue
		if not (_front_kind(u) or _heavy(u) or u.kind == Defs.GREAT_WINDER_KIND):
			continue
		if ai.raid != null and ai.raid.has(u):
			continue
		if ai.harass != null and ai.harass.has(u):
			continue
		if ai.r5 != null and ai.r5.busy(u):
			continue
		if ai._on_errand(u) and not joining.has(u):
			continue          # (clockwork-army: the Clock Soldier rush's and the Owl raids' units too, not only the Springer raid's)
		out.append(u)
	return out


func _count(list: Array, kind: String) -> int:
	return list.filter(func(u: Unit) -> bool: return u.kind == kind).size()


## The plan's army is there: every kind it needs, and the supply.
func ready_now(list: Array) -> bool:
	var need: Dictionary = cfg.get("need", {})
	if _vs_brood() and cfg.has("need_brood"):
		need = cfg["need_brood"]
	for k in need:
		var have := _count(list, String(k))
		if k == "front":
			have = list.filter(func(u: Unit) -> bool: return _front_kind(u) and u.kind != Defs.PENDULUM).size()
		if have < int(need[k]):
			return false
	return ai._army_supply(list) >= int(cfg.get("min_supply", 16)) + need_up


func _vs_brood() -> bool:
	return foe >= 0 and game.faction_of(foe) == "brood"


# ------------------------------------------------------------------ the tick (AIClockwork._army, every think)

func tick() -> void:
	foe = ai._foe()
	if foe < 0:
		return
	_remember_brood()
	units = units.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	for g in _guards.keys():
		if not is_instance_valid(g) or g.dead or not units.has(g):
			_guards.erase(g)
	if phase == "" or phase == "back":
		if phase == "back":
			_go_back()
			return
		var home := _home_army()
		if OS.get_cmdline_user_args().has("pushdebug") and int(game.clock) % 30 == 0:
			var kinds := {}
			for u in home:
				kinds[u.kind] = int(kinds.get(u.kind, 0)) + 1
			var why := []
			for u in game.army(team):
				if u.kind == Defs.PENDULUM and not home.has(u):
					why.append("pd%s r5%s hz%s w%.2f o%s" % [u.powered_down(), ai.r5.busy(u), ai.harass != null and ai.harass.has(u), u.wind, u.order])
			print("PUSHDBG %d home %s supply %d need %s up %d army %d out %s" % [int(game.clock), str(kinds), ai._army_supply(home), str(cfg.get("need")), need_up, game.army(team).size(), str(why)])
		if ready_now(home) and not ai.peaceful and game.clock >= float(cfg.get("not_before", 0.0)) and (not gate.is_valid() or gate.call(home)):
			_launch(home)
		return
	if _should_retreat():
		return
	_join()
	_pick_goal()
	if goal == Vector2.INF:
		return
	if _siege_tick():
		return
	var foes := _foes_near(anchor, LOOK) + _foes_near(_front_centre(), LOOK * 0.7).filter(func(o: Unit) -> bool: return o.position.distance_to(anchor) >= LOOK)
	if not foes.is_empty():
		calm_t = game.clock
		if phase != "fight":
			_phase("fight")
			_note_once("fight", "meets %d armed enemies (%d value) at %s" % [foes.size(), int(_value(foes)), _where(_front_centre())], 15.0)
		_fight(foes)
		return
	if phase == "fight" and game.clock - calm_t < CALM:
		_hold_line()
		return
	_phase("march")
	_march()


func _launch(list: Array) -> void:
	units = list.duplicate()
	launched = true
	pushes += 1
	stats["pushes"] = pushes
	value0 = _value(units)
	value_in = value0
	stats["max_out"] = maxf(float(stats["max_out"]), value0)
	kill0 = int(game.stats[team]["value_killed"])
	anchor = _centre(units)
	path = PackedVector2Array()
	path_t = -99.0
	goal = Vector2.INF
	goal_e = null
	piece = null
	_orders.clear()
	_phase("march")
	var kinds := {}
	for u in units:
		kinds[u.kind] = int(kinds.get(u.kind, 0)) + 1
	say("push %d goes out: %d units, %d supply, %d value %s" % [pushes, units.size(), ai._army_supply(units), int(value0), str(kinds)])


## Fresh fighters at home join as a group, walking to the anchor; they count as the push's once they are near it (JOIN_R).
## (Counted at once, the ones still on the road dragged the front's middle home: the anchor never moved again, and the push
## fed them into the Brood's nest a few at a time for four minutes, Greenhold 11.)
const JOIN_R := 360.0
var joining: Array = []
var value_in := 0.0             # what went out, the reinforcements that arrived included


func _join() -> void:
	joining = joining.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	for u in joining.duplicate():
		if u.position.distance_to(anchor) < JOIN_R:
			joining.erase(u)
			units.append(u)
			value_in += _value([u])
		else:
			_order(u, anchor, true, 80.0)
	var home := _home_army().filter(func(u: Unit) -> bool: return not joining.has(u))
	if home.is_empty() or ai._army_supply(home) < JOIN_SUPPLY:
		return
	if ai._threat() != Vector2.INF:
		return          # (the base is attacked: they stay for it)
	for u in home:
		joining.append(u)
		_order(u, anchor, true, 60.0)
	say("%d fresh units walk out to join it (%d supply)" % [home.size(), ai._army_supply(home)])


# ------------------------------------------------------------------ where it goes

## The Brood's rooted creatures and grubs seen (their economy), remembered while they live.
## The enemy's army seen lately: every armed unit seen in the last MEM_T s that still lives, each once (the push's own
## count; an army is never all in sight at once).
const MEM_T := 120.0
var _mem := {}                  # id -> [Unit, value, clock]


func _remember_army() -> void:
	for o in game.army(foe):
		if o.off_field or not ai._armed(o) or BroodNew.rooted(o) or not game.is_visible_to(team, o.position):
			continue
		_mem[o.get_instance_id()] = [o, ai._unit_value(o), game.clock]
	for id in _mem.keys():
		var e: Array = _mem[id]
		if not is_instance_valid(e[0]) or e[0].dead or game.clock - float(e[2]) > MEM_T:
			_mem.erase(id)


func foe_mem() -> float:
	var v := 0.0
	for id in _mem:
		v += float(_mem[id][1])
	return v


func _remember_brood() -> void:
	# (every think: gated on the frame count it ran one think in six, and the Rootmaws by the Mother were never "seen")
	_remember_army()
	if not _vs_brood():
		return
	for u in game.units:
		if u.dead or u.team != foe or u.off_field:
			continue
		if not (u.kind == "rootmaw" or u.kind == "mound_turtle" or u.kind == "brood_mother" or u.kind == "grub" or u.kind == "tyrannosaur"):
			continue
		if game.is_visible_to(team, u.position):
			_brood_seen[u.get_instance_id()] = {"u": u, "p": u.position, "kind": u.kind, "t": game.clock}
	for id in _brood_seen.keys():
		var e: Dictionary = _brood_seen[id]
		if not is_instance_valid(e["u"]) or e["u"].dead:
			_brood_seen.erase(id)


## The goal: against the Brood its economy first (a rooted Rootmaw or Mound Turtle, the nearest to the anchor; grubs where
## three or more were seen together), then the Mother; against the others the shared computer's target (an open
## expansion or economy building first, else the main: AI._enemy_base).
func _pick_goal() -> void:
	if goal_e != null and is_instance_valid(goal_e) and not goal_e.dead and game.clock - path_t < REPATH:
		return
	var old := goal
	goal_e = null
	if _vs_brood():
		var best = null
		var bd := INF
		var mother = null
		for id in _brood_seen:
			var e: Dictionary = _brood_seen[id]
			var u: Unit = e["u"]
			if u.kind == "brood_mother":
				mother = u
				continue
			if u.kind == "grub":
				continue
			if u.kind != "tyrannosaur" and not BroodNew.rooted(u):
				continue
			var dd: float = (e["p"] as Vector2).distance_to(anchor)
			if u.kind == "rootmaw":
				dd -= 400.0          # (the economy first)
			if dd < bd:
				bd = dd
				best = u
		if best == null:
			# (grubs: three or more seen together lately)
			for id in _brood_seen:
				var e2: Dictionary = _brood_seen[id]
				if e2["kind"] != "grub" or game.clock - float(e2["t"]) > 40.0:
					continue
				var near := 0
				for id2 in _brood_seen:
					var e3: Dictionary = _brood_seen[id2]
					if e3["kind"] == "grub" and (e3["p"] as Vector2).distance_to(e2["p"]) < 200.0:
						near += 1
				var d2: float = (e2["p"] as Vector2).distance_to(anchor)
				if near >= 3 and d2 < bd:
					bd = d2
					best = e2["u"]
		if best == null:
			best = mother
		if best != null:
			goal_e = best
			goal = (best as Unit).position
		else:
			goal = Vector2(game.starts[foe]) * Defs.TILE
	else:
		goal = ai._enemy_base()
		if _done_goals.any(func(q: Vector2) -> bool: return q.distance_to(goal) < 200.0):
			# (nothing seen there any more: the enemy's start, then its other halls the side knows)
			goal = Vector2(game.starts[foe]) * Defs.TILE
			for b in game.buildings:
				if b.team == foe and not b.dead and not b.ghost and game.side_sees(team, b.center()) \
						and not _done_goals.any(func(q: Vector2) -> bool: return q.distance_to(b.center()) < 200.0):
					goal = b.center()
					break
	if old == Vector2.INF or old.distance_to(goal) > 120.0:
		path_t = -99.0
		stats["goals"] = int(stats["goals"]) + 1
		var what := String(goal_e.d["name"]) if goal_e != null else "the enemy's base"
		_note_once("goal", "heads for %s at %s" % [what, _where(goal)], 20.0)


## The path from the anchor to the goal (walled: up to the wall, Game.find_path's siege path).
func _repath() -> void:
	if game.clock - path_t < REPATH and not path.is_empty():
		return
	path_t = game.clock
	path = game.find_path(anchor, goal, true)
	path_i = 0
	if path.is_empty():
		path = PackedVector2Array([anchor, goal])


func _dir() -> Vector2:
	# the way the march goes here (along the path), for "behind"
	var nxt := goal
	for i in range(path_i, path.size()):
		if path[i].distance_to(anchor) > 40.0:
			nxt = path[i]
			break
	var d := nxt - anchor
	return d.normalized() if d.length() > 1.0 else (goal - anchor).normalized()


# ------------------------------------------------------------------ the march

func _march() -> void:
	_repath()
	var front: Array = units.filter(func(u: Unit) -> bool: return _front_kind(u))
	var heavies: Array = units.filter(func(u: Unit) -> bool: return _heavy(u) or u.kind == Defs.GREAT_WINDER_KIND)
	var near_n := front.filter(func(u: Unit) -> bool: return u.position.distance_to(anchor) < FRONT_AT).size()
	var at := front.is_empty() or float(near_n) >= float(front.size()) * 0.6
	var dir := _dir()
	var lag := false
	for h in heavies:
		var back := BACK_GW if h.kind == Defs.GREAT_WINDER_KIND else BACK_BAL
		if h.position.distance_to(anchor - dir * back) > HEAVY_LAG:
			lag = true
	var arrived := path_i >= path.size() or anchor.distance_to(goal) < 160.0
	if at and not lag and not arrived and _main_goal() and anchor.distance_to(goal) < 1100.0 and (_value(units) < foe_mem() * float(cfg.get("main_k", MAIN_K)) or _value(units) < float(cfg.get("main_min", 0.0))):
		# THE MAIN WAITS: the enemy's main (its army's home) only with the strength for it: the push holds here, on the ground
		# it took, and the reinforcements join it (Greenhold 11: the push razed the Crown's expansion, walked on up to its
		# main and met its whole army, 25 Musketeers, at the ramp: 3,100 value lost in a minute). The plan's "main_min": the
		# least value it goes in with whatever it has seen (the army in a main is mostly unseen: 8 Clock Soldiers walked up
		# to a Crown ramp at 7:11 having seen one Musketeer, and died)
		_note_once("contain", "holds short of the enemy's main: worth %d, the enemy's army seen lately %d" % [int(_value(units)), int(foe_mem())], 40.0)
		at = false
	if at and not lag and not arrived:
		_advance()
		dir = _dir()
		arrived = path_i >= path.size() or anchor.distance_to(goal) < 160.0
	if arrived:
		_assault(front)
	else:
		_arrive_t = -1.0
		_place_front(front, anchor, dir, true)
	_place_heavies(heavies, anchor, dir)


## At the goal (the end of the path): the front goes for the goal itself (a Brood creature), else for the enemy's buildings
## seen near it, the nearest first; nothing left there for ARRIVE_IDLE s: the goal is done, the next one is picked.
const ARRIVE_IDLE := 12.0
var _arrive_t := -1.0
var _done_goals: Array = []


func _assault(front: Array) -> void:
	if _arrive_t < 0.0:
		_arrive_t = game.clock
		_note_once("arrive", "is at its goal %s: the front goes in" % _where(goal), 20.0)
	var tgt: Entity = null
	if goal_e != null and is_instance_valid(goal_e) and not goal_e.dead:
		tgt = goal_e
	else:
		var bd := 420.0
		for b in game.buildings:
			if b.dead or b.ghost or not game.hostile(b.team, team) or not game.side_sees(team, b.center()):
				continue
			var dd: float = b.center().distance_to(goal)
			if dd < bd:
				bd = dd
				tgt = b
	if tgt == null:
		if game.clock - _arrive_t > ARRIVE_IDLE:
			_done_goals.append(goal)
			say("nothing left at %s: on to the next goal" % _where(goal))
			goal = Vector2.INF
			goal_e = null
			path_t = -99.0
			_arrive_t = -1.0
		else:
			_place_front(front, goal, _dir(), true)
		return
	_arrive_t = game.clock
	if tgt is Building and units.any(func(u: Unit) -> bool: return _heavy(u)):
		# (a building with Ballistas along: they break it from out of musket reach, the front screens them, as at a wall;
		# the front alone at a Crown main walked up its ramp away from its Ballistas and died there, Greenhold 11 7:30)
		piece = tgt
		piece_t = game.clock
		stats["sieges"] = int(stats["sieges"]) + 1
		_phase("siege")
		say("the Ballistas lay siege to the %s at %s" % [String(tgt.d["name"]), _where(tgt.center())])
		return
	for u in front:
		if _guards.has(u) or not u.can_hit(tgt):
			continue
		if u.target != null and is_instance_valid(u.target) and not u.target.dead and u.target is Unit and u.target.kind != "brood_mother" \
				and not BroodNew.rooted(u.target) and u.position.distance_to(u.target.position) < 120.0:
			continue          # (fighting a defender beside it: on with that first; not the Mother when the goal is her Rootmaw)
		if u.target != tgt:
			u.cmd_attack(tgt)


func _advance() -> void:
	var left := STEP
	var p := anchor
	while left > 0.0 and path_i < path.size():
		var nxt := path[path_i]
		var d := p.distance_to(nxt)
		if d <= left:
			p = nxt
			left -= d
			path_i += 1
		else:
			p = p + (nxt - p).normalized() * left
			left = 0.0
	anchor = p          # (never past the path's end: a goal behind a cliff or a footprint is reached by the front itself)


## The front in a loose line across the way at point p (attack-move: it fights what it meets).
func _place_front(front: Array, p: Vector2, dir: Vector2, amove: bool) -> void:
	var side := Vector2(-dir.y, dir.x)
	var n := front.size()
	for i in n:
		var u: Unit = front[i]
		if _guards.has(u):
			continue
		var off := (float(i) - float(n - 1) * 0.5) * 22.0
		var row := -18.0 if u.kind == Defs.SPRINGER or u.kind == Defs.NETTER else (12.0 if u.kind == Defs.PENDULUM else 0.0)
		_order(u, p + side * clampf(off, -130.0, 130.0) + dir * row, amove, 50.0)


func _place_heavies(heavies: Array, p: Vector2, dir: Vector2) -> void:
	var side := Vector2(-dir.y, dir.x)
	var bi := 0
	for h in heavies:
		if h.kind == Defs.GREAT_WINDER_KIND:
			if h.order == "cast" or ((h.order == "mend" or h.order == "sweep") and h.position.distance_to(p) < 420.0):
				continue      # (its autocasts: SCATTER COGS, MEND, SWEEP near the push)
			_order(h, p - dir * BACK_GW, false, 70.0)
			continue
		var off := (float(bi % 3) - 1.0) * 46.0
		bi += 1
		_order(h, p - dir * BACK_BAL + side * off, true, 60.0)


## Give a move only when it differs from the last one given (or that one is old and the unit stands about).
func _order(u: Unit, p: Vector2, amove: bool, tol: float) -> void:
	var last = _orders.get(u)
	if last != null and (last[0] as Vector2).distance_to(p) < tol and (u.order != "idle" or game.clock - float(last[1]) < 3.0):
		if u.order == "idle" and u.position.distance_to(p) > tol * 1.5:
			pass
		else:
			return
	if u.position.distance_to(p) < 24.0 and u.order == "idle":
		_orders[u] = [p, game.clock]
		return
	u.cmd_move(p, amove)
	_orders[u] = [p, game.clock]


# ------------------------------------------------------------------ fights

func _foes_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	for o in game.units_near(p, r):
		if o.dead or o.off_field or not game.hostile(o.team, team) or o.is_worker() or not game.is_visible_to(team, o.position):
			continue
		if not ai._armed(o) or BroodNew.rooted(o):
			continue
		out.append(o)
	return out


func _fight(foes: Array) -> void:
	var front: Array = units.filter(func(u: Unit) -> bool: return _front_kind(u))
	var heavies: Array = units.filter(func(u: Unit) -> bool: return _heavy(u) or u.kind == Defs.GREAT_WINDER_KIND)
	var fcen := _centre(foes)
	# THE SCREEN: the front meets what comes within SCREEN_R of the line, else it holds the line in front of the machines
	# (the Ballistas outrange the Musketeers: charging them only fed the Clock Soldiers to the muskets one by one, 7:34
	# Greenhold 11); a foe that keeps out of reach is the Ballistas' (or the front walks on once it is calm)
	# (not up a cliff: enemies on high ground the anchor is below are not chased up the ramp into their main; the line steps
	# back out of their reach instead. 8 Clock Soldiers ran up a Crown ramp after 3 Musketeers and died there in 20 s,
	# Greenhold 11 7:06)
	var low := not game.on_high(anchor)
	var above: Array = foes.filter(func(o: Unit) -> bool: return low and game.on_high(o.position))
	var close: Array = foes.filter(func(o: Unit) -> bool: return o.position.distance_to(anchor) < SCREEN_R and not above.has(o))
	if close.is_empty() and not above.is_empty():
		var ac := _centre(above)
		if ac.distance_to(anchor) < 300.0:
			anchor = anchor + (anchor - ac).normalized() * 90.0
			_note_once("cliff", "enemies shoot down from high ground: the line steps back out of their reach", 30.0)
	var ccen := _centre(close) if not close.is_empty() else Vector2.INF
	var dir := _dir()
	for u in front:
		if _guards.has(u):
			continue
		if u.position.distance_to(anchor) > float(cfg.get("leash", LEASH)):
			_order(u, anchor, false, 60.0)        # (too far after a chase: back to the block, not on into the fog)
			continue
		if u.target != null and is_instance_valid(u.target) and not u.target.dead and u.position.distance_to(u.target.position) < 220.0:
			continue
		if ccen != Vector2.INF:
			_order(u, ccen, true, 60.0)
	if close.is_empty():
		_place_front(front, anchor, dir, true)
		# (nothing in reach of the line: when no machine of ours reaches them either, it walks on toward them)
		var reach := units.any(func(u: Unit) -> bool: return _heavy(u) and foes.any(func(o: Unit) -> bool: return o.position.distance_to(u.position) < float(u.d["range"]) + 30.0))
		if not reach and game.clock - since > 6.0 and fcen.distance_to(anchor) > 80.0:
			anchor = anchor.move_toward(fcen, 60.0)
	_guard_ballistas(front, foes)
	if ai.get("army_g") != null and ai.army_g != null:
		ai.army_g.spring_in(front, foes)      # (clockwork-army: the Springers jump in as the front engages)
	# the Ballistas hold where they are (behind), the Great Winder behind them
	for h in heavies:
		if h.kind == Defs.GREAT_WINDER_KIND:
			if h.order == "cast" or h.order == "mend" or h.order == "sweep":
				continue
			var gw_spot := anchor - dir * BACK_GW
			if h.position.distance_to(fcen) < 200.0:
				gw_spot = h.position + (h.position - fcen).normalized() * 120.0
			_order(h, gw_spot, false, 70.0)


## An enemy at a Ballista: it rolls back toward the Great Winder (or home), the two nearest front units meet that enemy.
func _guard_ballistas(front: Array, foes: Array) -> void:
	for g in _guards.keys():
		var e = _guards[g]
		if not is_instance_valid(e) or e.dead or g.position.distance_to(e.position) > 400.0:
			_guards.erase(g)
	for b in units.filter(func(u: Unit) -> bool: return _heavy(u)):
		var near_e: Unit = null
		var nd := GUARD_R
		for o in foes:
			var dd: float = o.position.distance_to(b.position)
			if dd < nd and float(o.d.get("range", 0.0)) < 80.0:
				nd = dd
				near_e = o
		if near_e == null:
			continue
		var away: Vector2 = (b.position - near_e.position).normalized()
		_order(b, b.position + away * 140.0, false, 40.0)
		var sent := _guards.values().filter(func(x) -> bool: return x == near_e).size()
		if sent >= 2:
			continue
		var cand: Array = front.filter(func(u: Unit) -> bool: return not _guards.has(u) and u.can_hit(near_e))
		cand.sort_custom(func(a: Unit, c: Unit) -> bool: return a.position.distance_to(near_e.position) < c.position.distance_to(near_e.position))
		for u in cand.slice(0, 2 - sent):
			_guards[u] = near_e
			u.cmd_attack(near_e)
		_note_once("guard", "an enemy reaches a Spring Ballista: it rolls back, the front meets it", 30.0)


## No enemy near now but one was: the line holds where it is a few seconds (no chasing into the fog).
func _hold_line() -> void:
	var front: Array = units.filter(func(u: Unit) -> bool: return _front_kind(u))
	for u in front:
		if u.order == "idle" and u.position.distance_to(anchor) > 260.0:
			_order(u, anchor, true, 60.0)


# ------------------------------------------------------------------ the siege (a wall or gate in the way)

func _siege_tick() -> bool:
	if piece != null and (not is_instance_valid(piece) or piece.dead):
		say("the %s falls after %d s; the march goes on" % [String(piece.d["name"]), int(game.clock - piece_t)])
		stats["pieces"] = int(stats["pieces"]) + 1
		piece = null
		path_t = -99.0
		_phase("march")
		return false
	if piece == null:
		var p := _piece_ahead()
		if p == null:
			return false
		piece = p
		piece_t = game.clock
		stats["sieges"] = int(stats["sieges"]) + 1
		_phase("siege")
		say("a %s in the way at %s: the Ballistas break it from out of musket reach" % [String(p.d["name"]), _where(p.center())])
	if game.clock - piece_t > SIEGE_MAX:
		say("the %s held for %d s: the push goes home" % [String(piece.d["name"]), int(SIEGE_MAX)])
		_retreat("the siege took too long")
		return true
	var foes := _foes_near(_front_centre(), LOOK * 0.8)
	var pc := piece.center()
	var from := (anchor - pc).normalized() if anchor.distance_to(pc) > 1.0 else -_dir()
	var front: Array = units.filter(func(u: Unit) -> bool: return _front_kind(u))
	var bals: Array = units.filter(func(u: Unit) -> bool: return _heavy(u))
	var side := Vector2(-from.y, from.x)
	# enemies come out (not shooting over the wall from behind it): the front meets them, the Ballistas keep at the piece
	var out_foes: Array = foes.filter(func(o: Unit) -> bool: return o.position.distance_to(pc) > 90.0 and o.position.distance_to(pc + from * SIEGE_FRONT) < 260.0)
	if not out_foes.is_empty():
		for u in front:
			if not _guards.has(u):
				_order(u, _centre(out_foes), true, 60.0)
		_guard_ballistas(front, out_foes)
	else:
		_place_front(front, pc + from * SIEGE_FRONT, -from, false)
	var bi := 0
	for b in bals:
		var off := (float(bi % 3) - 1.0) * 50.0
		bi += 1
		var spot := pc + from * SIEGE_BAL + side * off
		if b.position.distance_to(spot) > 50.0 and b.target != piece:
			_order(b, spot, false, 40.0)
		elif b.target != piece and b.position.distance_to(pc) < float(b.d["range"]) + 40.0:
			b.cmd_attack(piece)
	for h in units.filter(func(u: Unit) -> bool: return u.kind == Defs.GREAT_WINDER_KIND):
		if h.order != "cast" and h.order != "mend" and h.order != "sweep":
			_order(h, pc + from * (SIEGE_BAL + 70.0), false, 60.0)
	# no Ballista left: the front breaks it itself (the shared siege rules are for waves)
	if bals.is_empty():
		for u in front:
			if u.target != piece and u.can_hit(piece):
				u.cmd_attack(piece)
	anchor = pc + from * SIEGE_FRONT
	return true


## A wall or gate of the enemy's within SIEGE_SEE of the anchor, on the way (the goal's path is walled), that the side sees.
func _piece_ahead() -> Building:
	_repath()
	if path.is_empty():
		return null
	var best: Building = null
	var bd := SIEGE_SEE
	for b in game.buildings:
		# (a wall, a gate, or a Cottage in the way: the Crown plugs its ramp with one)
		if b.dead or not b.built or not game.hostile(b.team, team) or not (b.kind == "wall" or b.kind == "gate" or b.kind == "cottage"):
			continue
		var bc: Vector2 = b.center()
		var dd: float = bc.distance_to(anchor)
		if dd > bd or not game.side_sees(team, bc):
			continue
		# on the way: near the path ahead
		var on_way := false
		var near_way := 90.0 if (b.kind == "wall" or b.kind == "gate") else 50.0
		for i in range(path_i, mini(path.size(), path_i + 40)):
			if path[i].distance_to(bc) < near_way:
				on_way = true
				break
		if not on_way and bc.distance_to(goal) > anchor.distance_to(goal):
			continue
		if not on_way:
			continue
		bd = dd
		best = b
	return best


# ------------------------------------------------------------------ retreat and home

func _should_retreat() -> bool:
	var fighters: Array = units.filter(func(u: Unit) -> bool: return u.kind != Defs.GREAT_WINDER_KIND)
	if fighters.size() < MIN_LEFT:
		_retreat("only %d fighters left" % fighters.size())
		return true
	var now := _value(units)
	var foes := _foes_near(_front_centre(), LOOK + 120.0)
	var fv := _value(foes)
	if now < value_in * GRIND:
		_retreat("it has lost %d of the %d that went out and joined" % [int(value_in - now), int(value_in)])
		return true
	if fv > now * OUTNUMBERED and fv > 300.0:
		_retreat("the enemy's army comes, worth %d against its %d" % [int(fv), int(now)])
		return true
	if now < value_in * (1.0 - LOST_SHARE) and now < fv * RETREAT_K:
		_retreat("worth %d against %d near it, %d of %d lost" % [int(now), int(fv), int(value_in - now), int(value_in)])
		return true
	# a big attack on the base while it is far out: home to meet it
	var th: Vector2 = ai._threat()
	if th != Vector2.INF and ai._home_dist(_front_centre()) > 1200.0:
		var at_home := _foes_near(th, 450.0)
		if _value(at_home) > maxf(350.0, ai._guard_value() * 1.5):
			_retreat("the base is attacked (%d value at %s)" % [int(_value(at_home)), _where(th)])
			return true
	return false


func _retreat(why: String) -> void:
	stats["retreats"] = int(stats["retreats"]) + 1
	var left := _value(units)
	say("pulls back (%s): %d value left of %d, killed %d since it went out" % [why, int(left), int(value0), int(game.stats[team]["value_killed"]) - kill0])
	need_up = mini(need_up + 4, 20)
	piece = null
	_phase("back")
	_go_back()


func _go_back() -> void:
	var home: Vector2 = ai._home_spot(ai._front()) if not ai._halls().is_empty() else Vector2(game.starts[team]) * Defs.TILE
	units.append_array(joining.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead))
	joining.clear()
	var all_home := true
	for u in units:
		if u.position.distance_to(home) > 300.0:
			all_home = false
			_order(u, home, false, 80.0)
	if all_home or game.clock - since > 90.0:
		units.clear()
		_orders.clear()
		_guards.clear()
		_phase("")
		say("is home again: it gathers for the next push (it waits for %d more supply)" % need_up)


# ------------------------------------------------------------------ small things

func _front_centre() -> Vector2:
	var front: Array = units.filter(func(u: Unit) -> bool: return _front_kind(u))
	return _centre(front) if not front.is_empty() else (_centre(units) if not units.is_empty() else anchor)


func _centre(list: Array) -> Vector2:
	if list.is_empty():
		return Vector2.INF
	var c := Vector2.ZERO
	for u in list:
		c += u.position
	return c / list.size()


func _value(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += float(u.d.get("cost", 0)) / maxf(1.0, float(u.d.get("spawn", 1))) + float(Defs.tension_cost(u.d))
	return v


func _where(p: Vector2) -> String:
	var c: Vector2i = game.cell_of(p)
	return "(%d, %d)" % [c.x, c.y]


func _note_once(key: String, s: String, gap: float) -> void:
	if game.clock - float(log_t.get(key, -999.0)) < gap:
		return
	log_t[key] = game.clock
	say(s)


## The goal is the enemy's main: its start (a Crown or Clockwork main hall, the Brood Mother's nest).
func _main_goal() -> bool:
	return foe >= 0 and goal.distance_to(Vector2(game.starts[foe]) * Defs.TILE) < 700.0
