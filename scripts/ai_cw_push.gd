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
const BACK_GW_V2 := 90.0        # (clockwork-ai-v2) ... nearer: by the army's middle, where its wreck look reaches the front
const HEAVY_LAG := 320.0        # the anchor waits for the Ballistas and the Great Winder within this of their spot
const LOOK := 380.0             # px round the front: armed enemies here start a fight
const CALM := 3.0               # s with no armed enemy near the front before the march goes on
const SCREEN_R := 260.0        # px from the anchor: the front meets the enemies within this, holds against the rest
const LEASH := 520.0           # px: a front unit farther than this from the anchor in a fight walks back to it (the plan's
                                # "leash": the Heavy Works push 360, 520 let its Clock Soldiers chase kiting Musketeers off)
const BAL_LEASH := 380.0        # (clockwork-army) a Ballista further than this from the anchor in a fight walks back to it
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
## (ai-followups, the owner's Crown v Clockwork game 0.33.0, 7:05-7:40: the push turned round on its way to the Crown's base
## and walked its anchor back across the map after ONE Horseman, "the whole army chases one rider")
const RIDER_V := 260.0          # fast foes worth less than this in all ...
const RIDER_SHARE := 0.15       # ... and less than this share of the push, every one faster than its front: RIDERS it does
const RIDER_FAST := 1.2         # not chase (this many times the front's speed or more); the march goes on, the front shoots
                                # what comes into its reach
const MARCH_LEASH := 300.0      # px: on the march, a front unit this far from the anchor (after a rider) walks back to it
const KEY_LOW := 0.35           # a hall or Mainspring under this share of its health with enemies at it calls the push home
const CHASE_MAX := 360.0
## (clockwork-ai-v2, the qa study: the Clockwork had the biggest army at every minute and won 5 of 76 cross games, 0 of 38
## mirrors; it held short of the enemy's main with 1,980 against 0 seen, laid siege to every Cottage and Palisade with its
## Ballistas alone, and its games ended as draws with the enemy beaten in all but name) THE PUSH COMMITS when it is clearly
## ahead: from AHEAD_FROM, worth AHEAD_K times the enemy army seen near it lately and times the reckoning of the whole enemy
## army (ai_cw_army.reckon), and at least AHEAD_MIN. Committed, it goes for the enemy's HALLS (the Brood: its Mother, the
## losing condition), it does not hold short of the main for the enemy army it has seen (a walled Crown main still wants the
## plan's "main_min"), and the front breaks buildings with the Ballistas instead of only screening them. It still pulls back
## by the usual rules.        # px: in a fight the anchor walks toward the enemies at most this far from where it began

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
var stats := {"pushes": 0, "sieges": 0, "pieces": 0, "retreats": 0, "goals": 0, "max_out": 0.0, "riders": 0, "leashed": 0, "commits": 0}
var fight_from := Vector2.INF   # (ai-followups) the anchor where the fight began: CHASE_MAX from it at most
var _rider_said := -99.0
const AHEAD_K := 2.0
const AHEAD_MIN := 1200.0
const AHEAD_KEEP := 1.6
const COMMIT_MAIN := 0.75       # committed, the plan's "main_min" for the enemy's main is this share of it (Greenhold: 1,875
                                # held short of a Crown main for four minutes against 187 seen and 381 reckoned)
const AHEAD_FROM := 480.0       # (s) not before this: early on most of the enemy army is unseen and its main walled
var committed := false
var commit_on := not OS.get_cmdline_user_args().has("cwcommit:off")      # (`-- cwcommit:off` as 0.33.11)
## (clockwork-army, scripts/ai_cw_army.gd: the army's own word before a push goes out: stronger than the enemy army it
## reckons, with a fresh report; an empty Callable = the plan's needs alone, as before)
var gate := Callable()
## (clockwork-v-clockwork-coach) THE CLOCKWORK'S HUNT IS ITS PUSH: set by AIClockwork._cw_hunt while the enemy has no army.
## The push then goes out with whatever is at home, stays committed and goes for the enemy's nearest building of any kind.
## (The shared hunt took the army off the push: the escort Winders stopped following it and it walked into the enemy's main
## as a stream; 50 of 78 Clock Soldiers stood run down there, 119 tiles from home, at 14:02, Hollowfen mirror.)
var hunt_on := false
## (clockwork-v-clockwork-coach) THE MARCH DOES NOT WAIT FOR THE GREAT WINDER. It joins the push at once wherever it is
## (clockwork-ai-v2) and sweeps wrecks on its way; the anchor waited for it to come within HEAVY_LAG of its spot. A committed
## push of 30-36 stood 90 s at the enemy's natural while its Great Winder swept wrecks 2,275 px away, at home (Hollowfen
## mirror, round 2, 10:30-12:00). It is unarmed: it catches up. `-- cwgwlag:off` plays it as before.
var gw_nowait_on := not OS.get_cmdline_user_args().has("cwgwlag:off")


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
		if hunt_on and _hunt_launch(home):
			return
		if ready_now(home) and not ai.peaceful and game.clock >= float(cfg.get("not_before", 0.0)) and (not gate.is_valid() or gate.call(home)):
			_launch(home)
		return
	_commit_check()
	if _should_retreat():
		return
	_join()
	if _hunt_parties():
		return
	_pick_goal()
	if goal == Vector2.INF:
		return
	if _siege_tick():
		return
	var foes := _foes_near(anchor, LOOK) + _foes_near(_front_centre(), LOOK * 0.7).filter(func(o: Unit) -> bool: return o.position.distance_to(anchor) >= LOOK)
	if not foes.is_empty() and riders_only(foes):
		# (ai-followups) A FEW FAST RIDERS round the push are no reason to stop: it does not chase them, the march goes on and
		# the front shoots what comes in reach (the leash in _march brings back any that ran after one)
		if game.clock - _rider_said > 20.0:
			_rider_said = game.clock
			stats["riders"] = int(stats["riders"]) + 1
			say("%d fast rider%s (%d value) round it: it does not chase them, the march goes on" % [foes.size(), "" if foes.size() == 1 else "s", int(_value(foes))])
		foes = []
	if not foes.is_empty():
		calm_t = game.clock
		if phase != "fight":
			fight_from = anchor
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
		if u.kind == Defs.GREAT_WINDER_KIND and ai.get("gw_sweep_on") == true:
			units.append(u)     # (clockwork-ai-v2: unarmed, it is the push's at once: _place_heavies walks it to its spot
			continue            # behind the front with a plain move, not an attack-move across the map with the joiners)
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
	if _brk_e != null and is_instance_valid(_brk_e) and _brk_e.dead:
		_break_note(null)
	if goal_e != null and is_instance_valid(goal_e) and not goal_e.dead and (game.clock - path_t < REPATH or (committed and _commit_goal_kept())):
		return
	var old := goal
	goal_e = null
	if committed and _commit_goal():
		pass
	elif _vs_brood():
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
	var at_r := _front_at(front.size())
	var near_n := front.filter(func(u: Unit) -> bool: return u.position.distance_to(anchor) < at_r).size()
	var at := front.is_empty() or float(near_n) >= float(front.size()) * 0.6 or hunt_on      # (hunting: no regrouping, see _hunt_launch)
	var dir := _dir()
	var lag := false
	for h in heavies:
		if h.kind == Defs.GREAT_WINDER_KIND and gw_nowait_on:
			continue          # (clockwork-v-clockwork-coach: the march never waits for the Great Winder, see gw_nowait_on)
		var back := (BACK_GW_V2 if ai.get("gw_sweep_on") == true else BACK_GW) if h.kind == Defs.GREAT_WINDER_KIND else BACK_BAL
		if h.position.distance_to(anchor - dir * back) > HEAVY_LAG:
			lag = true
	lag = _lag_wait(lag, heavies, dir)
	var arrived := path_i >= path.size() or anchor.distance_to(goal) < 160.0 or _goal_in_reach()
	_leash(front)
	if at and not lag and not arrived and _main_goal() and anchor.distance_to(goal) < 1100.0 and ((not committed and _value(units) < foe_mem() * float(cfg.get("main_k", MAIN_K))) or _value(units) < float(cfg.get("main_min", 0.0)) * (COMMIT_MAIN if committed else 1.0)):
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


## (ai-followups) Fast riders only, few and small: every armed foe faster than the push's front (RIDER_FAST times its
## slowest front unit, or more) and worth less than RIDER_V and RIDER_SHARE of the push together.
func riders_only(foes: Array) -> bool:
	if foes.is_empty():
		return false
	var v := _value(foes)
	if v >= RIDER_V or v >= _value(units) * RIDER_SHARE:
		return false
	var slow := INF
	for u in units:
		if _front_kind(u):
			slow = minf(slow, float(u.speed))
	if slow == INF:
		return false
	return foes.all(func(o: Unit) -> bool: return float(o.speed) >= slow * RIDER_FAST)


## (ai-followups) On the march, a front unit led off after a rider (MARCH_LEASH from the anchor) walks back to the block
## (a plain move: it stops chasing).
func _leash(front: Array) -> void:
	for u in front:
		if _guards.has(u) or u.position.distance_to(anchor) < MARCH_LEASH:
			continue
		if u.target == null or not is_instance_valid(u.target) or not (u.target is Unit) or u.target.dead:
			continue          # (only one chasing a foe; one still walking to its place is left be)
		u.cmd_move(anchor, false)
		_orders[u] = [anchor, game.clock]
		stats["leashed"] = int(stats["leashed"]) + 1


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
	if committed and tgt is Building:
		_break_note(tgt)
		var fixers := _break_fixers(tgt, front)
		# (committed: the hall (or what is at the goal) is broken by everyone together, the Ballistas and the front)
		for u in units:
			if fixers.has(u):
				continue
			if _guards.has(u) or u.kind == Defs.GREAT_WINDER_KIND or not u.can_hit(tgt):
				continue
			if u.target != null and is_instance_valid(u.target) and not u.target.dead and u.target is Unit and u.position.distance_to(u.target.position) < 120.0:
				continue
			if u.target != tgt:
				u.cmd_attack(tgt)
		return
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
	if rows_on and n > ROW_N:
		# (clockwork-ai-v2) A BIG FRONT IN ROWS: ROW_N a row across the way, the next rows ROW_GAP behind (a push of 55 Clock
		# Soldiers on one line 260 px wide crowded out past FRONT_AT, never counted as "at" the anchor, and the march stood
		# still for three minutes, Greenhold mirror 12:01-15:00)
		for i in n:
			var u: Unit = front[i]
			if _guards.has(u):
				continue
			var r := i / ROW_N
			var k := i % ROW_N
			var in_row := mini(ROW_N, n - r * ROW_N)
			var off := (float(k) - float(in_row - 1) * 0.5) * 22.0
			var row := -18.0 if u.kind == Defs.SPRINGER or u.kind == Defs.NETTER else (12.0 if u.kind == Defs.PENDULUM else 0.0)
			_order(u, p + side * off + dir * (row - ROW_GAP * float(r)), amove, 50.0)
		return
	for i in n:
		var u: Unit = front[i]
		if _guards.has(u):
			continue
		var off := (float(i) - float(n - 1) * 0.5) * 22.0
		var row := -18.0 if u.kind == Defs.SPRINGER or u.kind == Defs.NETTER else (12.0 if u.kind == Defs.PENDULUM else 0.0)
		_order(u, p + side * clampf(off, -130.0, 130.0) + dir * row, amove, 50.0)


## (clockwork-ai-v2) The front is "at" the anchor within this: FRONT_AT, more for a big front in rows.
const ROW_N := 12
const ROW_GAP := 26.0
var rows_on := not OS.get_cmdline_user_args().has("cwrows:off")


func _front_at(n: int) -> float:
	if not rows_on or n <= ROW_N:
		return FRONT_AT
	return FRONT_AT + ROW_GAP * float((n - 1) / ROW_N) + 20.0


func _place_heavies(heavies: Array, p: Vector2, dir: Vector2) -> void:
	var side := Vector2(-dir.y, dir.x)
	var bi := 0
	for h in heavies:
		if h.kind == Defs.GREAT_WINDER_KIND:
			if ai.has_method("gw_tend") and ai.gw_sweep_on:
				# (clockwork-ai-v2: just behind the front, and between fights it sweeps the wrecks by the push into cogs)
				if ai.gw_tend(h, _front_centre(), -dir):
					continue
				_order(h, p - dir * BACK_GW_V2, false, 50.0)
				continue
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
	var low := not game.on_high(anchor) and not _climb_ok(foes)
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
			# (ai-followups: never more than CHASE_MAX from where the fight began: a foe that keeps out of reach is left)
			var to := anchor.move_toward(fcen, 60.0)
			if fight_from == Vector2.INF or to.distance_to(fight_from) <= CHASE_MAX:
				anchor = to
	_guard_ballistas(front, foes)
	if ai.get("army_g") != null and ai.army_g != null:
		ai.army_g.spring_in(front, foes)      # (clockwork-army: the Springers jump in as the front engages)
	# the Ballistas hold where they are (behind), the Great Winder behind them; (clockwork-army) a Ballista that rolled or was
	# led far from the block walks back behind it (alone they fell to Raptors, 829 px from the anchor, Frostfang 8:19)
	for h in heavies:
		if _heavy(h) and ai.get("army_g") != null and ai.army_g != null and h.position.distance_to(anchor) > BAL_LEASH and not _guards.values().any(func(e) -> bool: return is_instance_valid(e) and e.position.distance_to(h.position) < GUARD_R):
			_order(h, anchor - dir * BACK_BAL, false, 60.0)
	for h in heavies:
		if h.kind == Defs.GREAT_WINDER_KIND:
			if h.order == "cast" or h.order == "mend" or h.order == "sweep" or _gw_busy(h):
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
		say("a %s in the way at %s: %s" % [String(p.d["name"]), _where(p.center()),
			"the Ballistas break it from out of musket reach" if units.any(func(u: Unit) -> bool: return _heavy(u)) else "the front breaks it"])
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
		var fx := _siege_fixers(front)        # (clockwork-v-clockwork-coach: the menders of a building under siege first)
		_place_front(front.filter(func(u: Unit) -> bool: return not fx.has(u)), pc + from * SIEGE_FRONT, -from, false)
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
		if h.order != "cast" and h.order != "mend" and h.order != "sweep" and not _gw_busy(h):
			_order(h, pc + from * (SIEGE_BAL + 70.0), false, 60.0)
	# no Ballista left: the front breaks it itself (the shared siege rules are for waves); committed: the front helps
	if bals.is_empty() or (committed and out_foes.is_empty()):
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
		# (ai-followups) A KEY BUILDING ABOUT TO FALL: a hall or a Mainspring under KEY_LOW of its health with armed enemies
		# at it: home, even for a small raid (a token raid alone never turns the push round: the units at home meet it)
		for b in game.buildings:
			if b.team != team or b.dead or not b.built or not (b.kind == String(ai._f()["hall"]) or b.kind == "mainspring"):
				continue
			if b.hp < b.max_hp * KEY_LOW and not _foes_near(b.center(), 260.0).is_empty():
				_retreat("its %s at %s is about to fall" % [String(b.d["name"]), _where(b.center())])
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


## (clockwork-ai-v2) Is the push clearly ahead (see AHEAD_K)? Said when it changes.
func _commit_check() -> void:
	if not commit_on or phase == "back":
		committed = false
		return
	if hunt_on:
		if not committed:
			committed = true          # (the hunt: the enemy has no army, nothing to weigh)
			path_t = -99.0
			goal_e = null
		return
	var v := _value(units)
	var rk: float = ai.army_g.reckon(true) if ai.get("army_g") != null and ai.army_g != null else 0.0      # (all kills: ai_cw_army._killed_for_reckon)
	var mem := foe_mem()
	var near := _value(_foes_near(_front_centre(), LOOK + 120.0))
	# (once committed it stays so down to AHEAD_KEEP times: a fight's numbers going up and down made it flip every few seconds)
	var ahead := game.clock >= AHEAD_FROM and v >= AHEAD_MIN and v >= maxf(maxf(mem, near), rk) * (AHEAD_KEEP if committed else AHEAD_K)
	if ahead == committed:
		return
	committed = ahead
	if ahead:
		stats["commits"] = int(stats["commits"]) + 1
		path_t = -99.0
		goal_e = null
		_note_once("commit", "is clearly ahead (worth %d, the enemy army seen lately %d, reckoned %d): it presses on to the enemy's halls to finish" % [int(v), int(maxf(mem, near)), int(rk)], 30.0)
	else:
		_note_once("uncommit", "is no longer clearly ahead (worth %d against %d): it marches on with care" % [int(v), int(maxf(mem, near))], 30.0)


## (clockwork-ai-v2) Committed, a hall (or the Mother) aimed at stays the goal until it falls: picked again every REPATH s as
## the nearest to the anchor, the goal swapped between two halls as the anchor moved and the push walked to and fro
## (Cinder Steps mirror, 9:35-13:01).
func _commit_goal_kept() -> bool:
	if hunt_on and goal_e is Building:
		return true
	if goal_e is Building:
		return (goal_e as Building).kind == game.faction_hall(foe)
	return goal_e is Unit and (goal_e as Unit).kind == "brood_mother"


## (clockwork-ai-v2) Committed: the goal is the enemy's nearest hall (the Brood: its Mother, kill her and the game is won).
## False when there is none (the usual goals then).
func _commit_goal() -> bool:
	if hunt_on and _hunt_goal():
		return true
	if _vs_brood():
		var q = BroodNew.queen(game, foe)
		if q != null and is_instance_valid(q) and not q.dead:
			goal_e = q
			goal = (q as Unit).position
			return true
		return false
	var best: Building = null
	var bd := INF
	var hall_kind: String = game.faction_hall(foe)
	for b in game.buildings:
		if b.team != foe or b.dead or b.ghost or b.kind != hall_kind:
			continue
		var dd: float = b.center().distance_to(anchor)
		if dd < bd:
			bd = dd
			best = b
	if best == null:
		return false
	goal_e = best
	goal = best.center()
	return true


## (clockwork-ai-v2) The Great Winder has a job by the push (AIClockwork.gw_tend: mending, or a wreck to sweep, no enemy
## soldier near it): in a fight and at a siege too, not only on the march.
func _gw_busy(h: Unit) -> bool:
	return ai.get("gw_sweep_on") == true and ai.gw_tend(h, _front_centre(), -_dir())


## (clockwork-v-clockwork-coach) The hunt: the push goes out at once with what is at home (MIN_LEFT fighters or more).
## Hunting, the anchor does not wait for 60% of the front to gather at it (CwPush._march): there is no army to meet, and a
## front of 57 after a hall stood regrouping with 13 at its anchor (Greenhold mirror, round 3, 13:03-13:33).
func _hunt_launch(home: Array) -> bool:
	var fighters: Array = home.filter(func(u: Unit) -> bool: return _front_kind(u) or _heavy(u))
	if fighters.size() < MIN_LEFT or ai.peaceful:
		return false
	_launch(home)
	say("hunts: the enemy has no army left: the push goes for its last buildings, its Winders along")
	return true


## (clockwork-v-clockwork-coach) The hunt's goal: the enemy's hall nearest the anchor, then its nearest worker, then its
## nearest building of any kind, then any unit of its.
func _hunt_goal() -> bool:
	var best: Entity = null
	var bd := INF
	var hall_kind: String = game.faction_hall(foe)
	for b in game.buildings:
		if b.team != foe or b.dead or b.ghost:
			continue
		# (its HALLS first: the Winders work round them and a hall makes new ones; a side is beaten once it has no
		# worker, soldier or means left. Hollowfen: the hunt broke the main's small buildings one by one while 32 Winders
		# kept the enemy's other three Clocktowers going to 15:00)
		var dd: float = b.center().distance_to(anchor) + (0.0 if b.kind == hall_kind else 3000.0)
		if dd < bd:
			bd = dd
			best = b
	for u in game.units:
		if u.team != foe or u.dead or u.off_field:
			continue
		# (then its WORKERS, before the rest of its buildings: with no hall and no money its last Winders were all that
		# kept it in the game; the hunt broke Regulators one by one for a minute while 12 of them stood idle, Dune Sea
		# mirror, round 4, 13:07-14:17)
		var dd2: float = u.position.distance_to(anchor) + (1500.0 if u.is_worker() else 4000.0)
		if dd2 < bd:
			bd = dd2
			best = u
	if best == null:
		return false
	goal_e = best
	goal = best.center() if best is Building else (best as Unit).position
	return true


## (clockwork-v-clockwork-coach) THE MENDERS FIRST. A Clocktower under attack is mended by every Winder near it (the repair
## autocast); against the Clockwork the committed push broke a hall in 60-77 s while its Winders stood mending it, and kept
## them. Now, at a building it breaks, up to BREAK_FIX_N of the front go for the enemy Winders within BREAK_FIX_R of it
## (the nearest first, two at most on one), the rest break the building. Against the Clockwork only (the mirror's coaching;
## the Crown's labourers mend too, a later look). `-- cwfixers:off` plays it as 0.33.16.
const BREAK_FIX_R := 220.0
const BREAK_FIX_N := 0.4
var fixers_on := not OS.get_cmdline_user_args().has("cwfixers:off")
var _fixer_of := {}             # front Unit -> the enemy Winder it was sent at


func _break_fixers(tgt: Building, front: Array) -> Dictionary:
	var out := {}
	for u in _fixer_of.keys():
		var w = _fixer_of[u]
		if not is_instance_valid(u) or u.dead or not is_instance_valid(w) or w.dead or w.position.distance_to(tgt.center()) > BREAK_FIX_R + 120.0:
			_fixer_of.erase(u)
	if not fixers_on or foe < 0 or game.faction_of(foe) != "clockwork":
		return out
	var ws: Array = []
	for o in game.units_near(tgt.center(), BREAK_FIX_R):
		if o.team == foe and not o.dead and not o.off_field and o.is_worker():
			ws.append(o)
	if ws.is_empty():
		for u in _fixer_of.keys():
			out[u] = true
		return out
	var cap := maxi(1, int(float(front.size()) * BREAK_FIX_N))
	var per := {}
	for u in _fixer_of.keys():
		per[_fixer_of[u]] = int(per.get(_fixer_of[u], 0)) + 1
		out[u] = true
	ws.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(_front_centre()) < b.position.distance_to(_front_centre()))
	var free: Array = front.filter(func(u: Unit) -> bool: return not _fixer_of.has(u) and not _guards.has(u))
	for w in ws:
		if _fixer_of.size() >= cap:
			break
		while int(per.get(w, 0)) < 2 and _fixer_of.size() < cap and not free.is_empty():
			free.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(w.position) < b.position.distance_to(w.position))
			var u: Unit = free.pop_front()
			if not u.can_hit(w):
				continue
			_fixer_of[u] = w
			per[w] = int(per.get(w, 0)) + 1
			out[u] = true
			u.cmd_attack(w)
	if not out.is_empty():
		_note_once("fixers", "goes for the %d Winders mending the %s first" % [ws.size(), String(tgt.d["name"])], 30.0)
	return out


## (clockwork-v-clockwork-coach) how long the committed push takes to break a building at its goal (said when it falls)
var _brk_e: Building = null
var _brk_t := 0.0


func _break_note(tgt: Building) -> void:
	if _brk_e != null and is_instance_valid(_brk_e) and _brk_e.dead:
		say("the %s at its goal falls after %d s" % [String(_brk_e.d["name"]), int(game.clock - _brk_t)])
		stats["breaks"] = int(stats.get("breaks", 0)) + 1
		_brk_e = null
	if _brk_e != tgt:
		_brk_e = tgt
		_brk_t = game.clock


## (clockwork-v-clockwork-coach) A FEW ON THE CLIFF DO NOT HOLD A WINNING PUSH. The line steps back out of reach of enemies
## shooting down from high ground (made against the Crown's Musketeers on a ramp). In the mirror one Clock Soldier or a
## Springer on the cliff kept a committed push of 44-60 units at the foot of the enemy's main for minutes (Greenhold mirror,
## 10:03-11:26, 4,360 value against 70). Committed against the Clockwork and worth CLIMB_K times what stands up there, it
## goes on up. `-- cwclimb:off` plays it as 0.33.16.
const CLIMB_K := 4.0
var climb_on := not OS.get_cmdline_user_args().has("cwclimb:off")


func _climb_ok(foes: Array) -> bool:
	if not climb_on or not committed or foe < 0 or game.faction_of(foe) != "clockwork":
		return false
	var up := foes.filter(func(o: Unit) -> bool: return game.on_high(o.position))
	return _value(units) >= _value(up) * CLIMB_K


## (clockwork-v-clockwork-coach) At a siege of a building that is no wall (a Clocktower at the goal: "the Ballistas lay
## siege"), the front screening the Ballistas sends its share at the Winders mending it (_break_fixers). Two Ballistas at a
## mended Clocktower in the enemy's main for 79 s did not break it (Dune Sea mirror, 7:41-9:00).
func _siege_fixers(front: Array) -> Dictionary:
	if piece == null or piece.kind == "wall" or piece.kind == "gate" or piece.kind == "cottage":
		return {}
	_break_note(piece)
	return _break_fixers(piece, front)


## (clockwork-v-clockwork-coach) A COMMITTED PUSH WAITS FOR ITS BALLISTAS LAG_MAX s AT MOST. They lagged because they were
## shooting a building 550 px off the way (the attack order of the last goal), and the whole front, every one at its
## anchor, stood still for a minute (Hollowfen mirror, round 2, 13:32-14:02). After LAG_MAX s the lagging ones are walked to
## their spot (a plain move: they stop shooting elsewhere) and the march goes on. Against the Clockwork only.
const LAG_MAX := 12.0
var _lag_t := -1.0


func _lag_wait(lag: bool, heavies: Array, dir: Vector2) -> bool:
	if not lag or not committed or not gw_nowait_on or foe < 0 or game.faction_of(foe) != "clockwork":
		_lag_t = -1.0
		return lag
	if _lag_t < 0.0:
		_lag_t = game.clock
	if game.clock - _lag_t < LAG_MAX:
		return true
	for h in heavies:
		if _heavy(h) and h.position.distance_to(anchor - dir * BACK_BAL) > HEAVY_LAG:
			_order(h, anchor - dir * BACK_BAL, false, 60.0)
	_note_once("lagwait", "does not wait for its Ballistas any more: they walk to it, the march goes on", 30.0)
	return false


## (clockwork-v-clockwork-coach) THE GOAL IN REACH IS THE GOAL REACHED. Committed against the Clockwork, a building goal
## within GOAL_NEAR of the anchor counts as reached: the whole push breaks it (and goes for its menders) at once. The march
## waits for 60% of the front at its anchor, and with the goal that near, half the front was already at it, shooting it on
## its attack-move: the anchor stood 360 px short of a Clocktower for two minutes with 32 soldiers, 16 at the anchor
## (Kestrel Rise mirror, round 3, 8:32-10:18). `-- cwreach:off` plays it as before.
const GOAL_NEAR := 420.0
var reach_on := not OS.get_cmdline_user_args().has("cwreach:off")


func _goal_in_reach() -> bool:
	if not reach_on or not committed or foe < 0 or game.faction_of(foe) != "clockwork":
		return false
	return goal_e is Building and is_instance_valid(goal_e) and not goal_e.dead and anchor.distance_to(goal) < GOAL_NEAR


## (clockwork-v-clockwork-coach) HUNTING PARTIES. Hunting with every enemy hall gone, the block chased the last Winders one
## at a time across the map: Hollowfen mirror, round 4, the enemy had no hall, no army and no cogs from 13:08, and 11 of its
## Winders were still alive at 15:00 (a draw; a side is beaten once it has no worker left, or no means for a minute).
## Now against the Clockwork, hunting with no enemy hall left, the front splits into parties of up to PARTY_N, each sent at
## one of the enemy's last units (its Winders first), the nearest first; the rest break its nearest buildings.
const PARTY_N := 4
var _party_of := {}             # front Unit -> the enemy unit it hunts


func _hunt_parties() -> bool:
	if not hunt_on or foe < 0 or game.faction_of(foe) != "clockwork":
		_party_of.clear()
		return false
	var hall_kind: String = game.faction_hall(foe)
	for b in game.buildings:
		if b.team == foe and not b.dead and not b.ghost and b.kind == hall_kind:
			_party_of.clear()
			return false
	var prey: Array = game.units.filter(func(u: Unit) -> bool: return u.team == foe and not u.dead and not u.off_field)
	prey.sort_custom(func(a: Unit, b: Unit) -> bool: return a.is_worker() and not b.is_worker())
	var front: Array = units.filter(func(u: Unit) -> bool: return _front_kind(u))
	for u in _party_of.keys():
		if not is_instance_valid(u) or u.dead or not front.has(u) or not is_instance_valid(_party_of[u]) or _party_of[u].dead:
			_party_of.erase(u)
	var per := {}
	for u in _party_of:
		per[_party_of[u]] = int(per.get(_party_of[u], 0)) + 1
	var free: Array = front.filter(func(u: Unit) -> bool: return not _party_of.has(u))
	for e in prey:
		while int(per.get(e, 0)) < PARTY_N and not free.is_empty():
			free.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(e.position) < b.position.distance_to(e.position))
			var u: Unit = free.pop_front()
			if not u.can_hit(e):
				continue
			_party_of[u] = e
			per[e] = int(per.get(e, 0)) + 1
	for u in _party_of:
		var e: Unit = _party_of[u]
		if u.target != e:
			u.cmd_attack(e)
	if not free.is_empty():
		var best: Building = null
		var bd := INF
		var c := _centre(free)
		for b in game.buildings:
			if b.team == foe and not b.dead and not b.ghost and b.center().distance_to(c) < bd:
				bd = b.center().distance_to(c)
				best = b
		if best != null:
			for u in free:
				if u.target != best and u.can_hit(best):
					u.cmd_attack(best)
	if not prey.is_empty():
		_note_once("parties", "hunts in parties: %d soldiers after its last %d units" % [_party_of.size(), prey.size()], 30.0)
	return true
