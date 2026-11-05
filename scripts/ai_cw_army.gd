extends RefCounted
## THE CLOCKWORK FIGHTS AS ONE ARMY (clockwork-army; docs/clockwork_army.md). The owner, 2026-11-05 09:24, watching Hard
## Clockwork Economy v Hard Brood Economy on Frostfang (0.31.0): "it kept sending 1 or 2 Clock Soldiers to die instead of
## using the Pendulum and Springers it had. Most of the time the army has to be together... It should have massed the army
## with Winders to repair and wind and squashed the Brood." In that game the shared computer split the Clockwork's army
## over half a dozen jobs: the scout (a Clock Soldier on its third trip), the harass (a Clock Soldier out alone), the round-5
## guard at the Winders, the detachments sent at each raid (one or two at a time), the ramp post, the rally at the main;
## its Springers, Netter and Pendulum stood at the Works where they were made.
## Now the Clockwork computer (Normal and up, gear mode) keeps ONE ARMY:
##  - every combat unit belongs to it by default (the plans' errands aside: the Springer raid, the Clock Soldier rush, the
##    Owl raids); at home it stands together at ONE gathering point, in front of the hall nearest the enemy (a choke on the
##    way in), with its escort Winders winding and mending it (AI._follow_with_escort);
##  - it goes out as one block: THE PUSH (scripts/ai_cw_push.gd, the Pendulum and Heavy Works plans' march) now carries
##    every Clockwork plan's attack: the anchor walks a step at a time only when the front is at it and the slow machines
##    close behind (the pace of the slowest), the Winders behind the front, the retreat as one; fresh units join it as a
##    group walking to it (never one at a time into the enemy);
##  - it goes out only STRONGER than the enemy army it knows (may_launch): the RECKONING is what it saw in the last two
##    minutes, never less than an enemy of that age has (TABLES, from the coached games), less half of what it has killed;
##    and only with a FRESH report (an enemy soldier seen or its main looked at in the last LOOK_FRESH s), else it asks the
##    scout for a look (a Swift or a Winder, never a combat unit) and holds at the gathering point;
##  - raids on the base: an armed raid worth little next to the army is met by a GROUP big enough to win (DEF_MARGIN times
##    its value, never fewer than GROUP_MIN units); a bigger one by the WHOLE army; the defenders walk back to the gathering
##    point when it is over or when they are led too far (LEASH) - no chasing, no lone catchers; unarmed scouts are left to
##    the Winders and turrets;
##  - its kit is used in a fight: the Springers JUMP IN when the front engages (spring_in: to a spot in shooting reach of the
##    enemy just behind their own front, never into a knot of melee), the Pendulums and Netters keep their aims (AI._micro).
## No unit numbers change. `-- cwarmy:off` plays the old army code (the "before" columns of the report).

const LOOK_FRESH := 75.0        # s: a report this old or newer is fresh
const EDGE := 1.25              # the army goes out only worth this many times the reckoning
const EDGE_PLAN := 1.0          # (the plans that have their own push needs: the Pendulums, the Heavy Works push)
const KILL_SHARE := 0.5         # the reckoning less this share of what we have killed
const DEF_MARGIN := 1.5         # a raid is met by this many times its value
const GROUP_MIN := 3            # never fewer defenders than this (unless the army has fewer)
const WHOLE_SHARE := 0.45       # a raid worth this share of the army or more: the whole army meets it
const GIVE_UP := 0.55           # the whole army worth less than this share of the raid: it holds at the main's gate
const LEASH := 520.0            # px from our nearest building: defenders further than this walk back
const STRAY_R := 360.0          # px: in a whole-army defence, one this far from the others and from the raid comes back
const CALM := 6.0               # s with no raid before the defenders walk back
const GATHER_R := 200.0         # px: a unit further than this from the gathering point walks to it
const REGATHER := 12.0          # s between two picks of the gathering point
const MASS_SINCE := 0.0         # (the opening's steady production: AIClockwork._bo_mass)
## The enemy army a Hard computer of that faction has at that age (value; [clock s, value]), from the coached games
## (docs/clockwork_army.md): the Brood's is the Crown's crown-v-brood table, raised before 7:00 (its Rootmaws and Mound
## Turtles fight where the push goes: 10 Clock Soldiers went at 5:23 on the old table and lost 490 for 250); the Crown's and the Clockwork's from the
## "before" games here (the lowest seen, so a weak enemy is not over-feared).
const TABLES := {
	"brood": [[0.0, 0.0], [180.0, 150.0], [300.0, 700.0], [360.0, 1000.0], [420.0, 1400.0], [480.0, 2200.0], [540.0, 3000.0], [600.0, 3800.0], [720.0, 5000.0]],
	"crown": [[0.0, 0.0], [180.0, 50.0], [300.0, 150.0], [360.0, 250.0], [420.0, 400.0], [480.0, 600.0], [600.0, 900.0], [720.0, 1400.0]],
	"clockwork": [[0.0, 0.0], [240.0, 70.0], [300.0, 400.0], [360.0, 800.0], [480.0, 1500.0], [600.0, 2500.0], [720.0, 3500.0]],
}

var ai = null
var game: Game = null
var team := 0
var phase := "gather"           # gather (at the gathering point), defend (the whole army at a raid), out (the push has it)
var gather_pt := Vector2.INF
var _gather_t := -99.0
var _gather_hall: Building = null
var defenders := {}             # Unit -> {"spot", "t0"}: a group sent at a raid
var _calm_t := 0.0
var _seen_t := -999.0           # the last time an armed enemy soldier was in sight
var _base_t := -999.0           # the last time the enemy's main was looked at
var _orders := {}               # Unit -> [point, clock]
var alog: Array = []             # [clock, text]
var _said := {}
var stats := {"groups": 0, "whole": 0, "holds": 0, "looks": 0, "springs": 0, "waits": 0}
var _home: Array = []           # the army at home this think (tests)


static func wanted(a) -> bool:
	return Defs.gear_mode and a.difficulty >= 1 and not OS.get_cmdline_user_args().has("cwarmy:off")


func _init(a) -> void:
	ai = a
	game = a.game
	team = a.team


func has(u: Unit) -> bool:
	return _home.has(u) or defenders.has(u)


func say(s: String, key := "", gap := 0.0) -> void:
	if key != "":
		if game.clock - float(_said.get(key, -999.0)) < gap:
			return
		_said[key] = game.clock
	alog.append([game.clock, s])
	ai.note("army: " + s)


# ------------------------------------------------------------------ what it knows of the enemy

func _foe() -> int:
	return ai._foe()


func _look() -> void:
	var foe := _foe()
	if foe < 0:
		return
	if game.is_visible_to(team, (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE):
		_base_t = game.clock
	for o in game.army(foe):
		if not o.dead and not o.off_field and ai._armed(o) and game.is_visible_to(team, o.position):
			_seen_t = game.clock
			return


func fresh() -> bool:
	return game.clock - _seen_t <= LOOK_FRESH or game.clock - _base_t <= LOOK_FRESH


static func table_at(tab: Array, t: float) -> float:
	if tab.is_empty():
		return 0.0
	for i in range(1, tab.size()):
		var a: Array = tab[i - 1]
		var b: Array = tab[i]
		if t <= float(b[0]):
			var k := (t - float(a[0])) / maxf(1.0, float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), clampf(k, 0.0, 1.0))
	return float(tab[-1][1])


## The enemy army as reckoned: what it saw in the last two minutes (the push's memory), never less than an enemy of that
## age has (TABLES) less KILL_SHARE of what we have killed; plus the Brood's rooted fighters it has seen. Unknown is never 0.
func reckon() -> float:
	var foe := _foe()
	if foe < 0:
		return 0.0
	var seen: float = ai.push.foe_mem() if ai.push != null else 0.0
	var tab: Array = TABLES.get(game.faction_of(foe), TABLES["crown"])
	var floor_v := maxf(0.0, table_at(tab, game.clock) - float(game.stats[team]["value_killed"]) * KILL_SHARE)
	return maxf(seen, floor_v) + _rooted_seen() * ROOTED_K


## The Brood's rooted fighters seen (Rootmaws, Mound Turtles: the push's goals; rooted they fight hard: 16 Clock Soldiers
## lost 700 for 150 at one Rootmaw and the Raptors that came, Frostfang 6:54), alive, as remembered by the push.
const ROOTED_K := 1.5


func _rooted_seen() -> float:
	if ai.push == null:
		return 0.0
	var v := 0.0
	for id in ai.push._brood_seen:
		var e: Dictionary = ai.push._brood_seen[id]
		var u = e["u"]
		if (e["kind"] == "rootmaw" or e["kind"] == "mound_turtle") and is_instance_valid(u) and not u.dead:
			v += ai._unit_value(u)
	return v


## May the army (the push) go out now? Only worth EDGE times the reckoning, with a fresh report (else a look is asked for).
func may_launch(list: Array) -> bool:
	var mine: float = ai.push._value(list)
	var rk := reckon()
	var edge := EDGE_PLAN if ai.plan.has("push") else EDGE
	_note_retreat()
	if _fail_v > 0.0 and mine < _fail_v * AFTER_FAIL:
		stats["waits"] = int(stats["waits"]) + 1
		say("holds at its gathering point: its last push (%d) had to pull back; the next goes worth %d (it has %d)" % [int(_fail_v), int(_fail_v * AFTER_FAIL), int(mine)], "fail", 45.0)
		return false
	if mine < rk * edge:
		stats["waits"] = int(stats["waits"]) + 1
		say("holds at its gathering point: worth %d, the enemy army it reckons %d (it goes at %d)" % [int(mine), int(rk), int(rk * edge)], "weak", 45.0)
		return false
	if not fresh():
		_ask_look()
		say("waits for a fresh scout report before it goes (worth %d, the enemy army it reckons %d)" % [int(mine), int(rk)], "fresh", 45.0)
		return false
	say("goes out: worth %d against the %d it reckons (a report %d s old)" % [int(mine), int(rk), int(game.clock - maxf(_seen_t, _base_t))])
	return true


## A push that had to pull back is news about the enemy too: the next one goes only bigger than it (AFTER_FAIL times what
## went out and joined). (Highmoor, the Economy against the Crown: a push of 16 went out 25 s after one of 30 had pulled
## back, and lost 700 for 60.)
const AFTER_FAIL := 1.25
var _fail_v := 0.0
var _retreats := 0


func _note_retreat() -> void:
	if ai.push == null:
		return
	var r := int(ai.push.stats["retreats"])
	if r > _retreats:
		_retreats = r
		_fail_v = maxf(float(ai.push.value_in), float(ai.push.value0))


func _ask_look() -> void:
	var sc = ai.scout
	if sc == null or sc.state == "going":
		return
	if sc.trips >= AIScout.MAX_TRIPS:
		sc.trips = AIScout.MAX_TRIPS - 1
	if sc.next_trip > game.clock:
		sc.next_trip = game.clock
		stats["looks"] = int(stats["looks"]) + 1


## A scout from the army? Never a ground fighter: a Swift (it flies, it is quick) or nothing (a Winder then).
func scout_pick() -> Unit:
	var best: Unit = null
	for u in game.army(team):
		if u.kind == "cuckoo" and u.order == "idle" and not ai._on_errand(u):
			best = u
	return best


# ------------------------------------------------------------------ the gathering point

## In front of the hall nearest the enemy (the way in), on that hall's ground; picked again every REGATHER s.
func _gather_point() -> Vector2:
	if game.clock - _gather_t < REGATHER and gather_pt != Vector2.INF and _gather_hall != null and is_instance_valid(_gather_hall) and not _gather_hall.dead:
		return gather_pt
	_gather_t = game.clock
	var halls: Array = ai._halls()
	if halls.is_empty():
		gather_pt = game.center_of_team(team)
		return gather_pt
	var foe := _foe()
	var their: Vector2 = Vector2(game.starts[foe]) * Defs.TILE if foe >= 0 else game.center_of_team(team)
	var best: Building = halls[0]
	var bd := INF
	for h in halls:
		if not h.built:
			continue
		var d: float = (h as Building).center().distance_to(their)
		if d < bd:
			bd = d
			best = h
	if best != _gather_hall:
		_gather_hall = best
		say("gathers in front of its Clocktower at %s" % _where(best.center()), "gpt", 30.0)
	gather_pt = ai._rally_front(best)
	return gather_pt


func _where(p: Vector2) -> String:
	var c: Vector2i = game.cell_of(p)
	return "(%d, %d)" % [c.x, c.y]


func _order(u: Unit, p: Vector2, amove: bool, tol: float) -> void:
	var last = _orders.get(u)
	if last != null and (last[0] as Vector2).distance_to(p) < tol and u.order != "idle" and game.clock - float(last[1]) < 8.0:
		return
	if u.order == "idle" and u.position.distance_to(p) < tol:
		return
	u.cmd_move(p, amove)
	_orders[u] = [p, game.clock]


func _value(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += ai._unit_value(u)
	return v


func _centre(list: Array) -> Vector2:
	var c := Vector2.ZERO
	for u in list:
		c += u.position
	return c / maxf(1.0, float(list.size()))


# ------------------------------------------------------------------ the tick (AIClockwork._army, every think)

## `army`: the computer's army not on an errand (the push's, the raids' are not in it).
func tick(army: Array) -> void:
	_look()
	for u in _orders.keys():
		if not is_instance_valid(u) or u.dead:
			_orders.erase(u)
	for u in defenders.keys():
		if not is_instance_valid(u) or u.dead:
			defenders.erase(u)
	var home: Array = army.filter(func(u: Unit) -> bool: return not u.is_worker() and u.has_attack() and not u.is_air() \
		and u.kind != "powder_wagon" and u.order != "sacrifice")
	# (the flyers keep the shared rules: a Swift scouts and fights flyers, an Ornithopter fetches batteries)
	_home = home
	var g := _gather_point()
	# run down off the gear ground: back into a field first (the shared rule; the escort winds the rest)
	var low: Array = home.filter(func(u: Unit) -> bool: return u.wind < 0.2 and not u.runs_on_spring() and not u._in_field and not u.powered_down())
	home = home.filter(func(u: Unit) -> bool: return not low.has(u) and not u.powered_down())
	_to_field(low)
	if _defend(home, g):
		ai._follow_with_escort(home + low if ai.push == null or ai.push.phase == "" or ai.push.phase == "back" else ai.push.units)
		return
	phase = "out" if (ai.push != null and ai.push.phase != "" and ai.push.phase != "back") else "gather"
	for u in home:
		if u.order == "attack" and u.target != null and is_instance_valid(u.target) and not u.target.dead and u.position.distance_to(g) < GATHER_R * 1.5:
			continue          # (fighting something at the gathering point itself)
		if u.position.distance_to(g) > GATHER_R or u.order == "idle" and u.position.distance_to(g) > GATHER_R * 0.6:
			_order(u, ai._home_spot(g), true, 90.0)
		elif u.deploys() and u.order == "idle" and u.tesla_mode == "packed":
			u.cmd_deploy()
	if ai.push == null or ai.push.phase == "" or ai.push.phase == "back":
		ai._follow_with_escort(home + low)     # (the Winders keep the waiting army wound and mended)
	else:
		ai._follow_with_escort(ai.push.units)  # (out: the escort goes with the push, AIClockwork._follow_with_escort)


func _to_field(low: Array) -> void:
	if low.is_empty():
		return
	var fields: Array = game.buildings.filter(func(b: Building) -> bool: return b.team == team and not b.dead and b.built and b.d.has("field"))
	if fields.is_empty():
		return
	for u in low:
		if u.order == "move":
			continue
		var best: Building = fields[0]
		for f in fields:
			if f.center().distance_to(u.position) < best.center().distance_to(u.position):
				best = f
		u.cmd_move(best.center() + Vector2(randf_range(-40, 40), randf_range(-40, 40)))


# ------------------------------------------------------------------ raids on the base

## Armed enemies by our buildings: a group big enough to win, or the whole army; the defenders come back when it is over.
## True when the whole army is busy with it.
func _defend(home: Array, g: Vector2) -> bool:
	var spots: Array = ai._threats()
	var raids: Array = []
	for sp in spots:
		var a: Dictionary = ai._assess(sp)
		if a["unarmed"]:
			continue          # (a scout or loose workers: the Winders and the turrets see to them)
		if a["air_only"] and not home.any(func(u: Unit) -> bool: return ai._hits_air(u)):
			continue
		raids.append(a)
	raids.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["value"]) > float(b["value"]))
	if raids.is_empty():
		if not defenders.is_empty() and game.clock - _calm_t > CALM:
			say("the raid is over: %d defenders walk back to the army" % defenders.size(), "back", 10.0)
			for u in defenders.keys():
				_order(u, ai._home_spot(g), true, 60.0)
			defenders.clear()
		if phase == "defend" and game.clock - _calm_t > CALM:
			phase = "gather"
		return phase == "defend"
	_calm_t = game.clock
	# defenders led too far, or whose raid is gone: back to the army
	for u in defenders.keys():
		var e: Dictionary = defenders[u]
		var still := raids.any(func(a: Dictionary) -> bool: return (a["spot"] as Vector2).distance_to(e["spot"]) < 350.0)
		if not still or ai._home_dist(u.position) > LEASH:
			defenders.erase(u)
			_order(u, ai._home_spot(g), false, 60.0)
	var free: Array = home.filter(func(u: Unit) -> bool: return not defenders.has(u))
	var mine := _value(home)
	var big: Dictionary = raids[0]
	var bv := float(big["value"])
	# THE WHOLE ARMY: the biggest raid is worth a good share of it
	if not home.is_empty() and bv >= mine * WHOLE_SHARE:
		var main_g: Vector2 = ai._post_spot()
		if mine < bv * GIVE_UP and main_g != Vector2.INF and (big["spot"] as Vector2).distance_to(main_g) > 700.0:
			# (far worse off, away from the main: the army holds together at the main's gate, the Winders mend it there)
			if phase != "hold":
				stats["holds"] = int(stats["holds"]) + 1
			phase = "hold"
			say("a raid worth %d at %s is too much for its %d: the army holds together at the main" % [int(bv), _where(big["spot"]), int(mine)], "hold", 30.0)
			for u in home:
				_order(u, ai._home_spot(main_g), u.position.distance_to(main_g) < 300.0, 90.0)
			defenders.clear()
			return true
		if phase != "defend":
			stats["whole"] = int(stats["whole"]) + 1
			say("the whole army (%d units, %d) meets a raid worth %d at %s" % [home.size(), int(mine), int(bv), _where(big["spot"])], "whole", 20.0)
		phase = "defend"
		var c := _centre(home)
		for u in home:
			if u.position.distance_to(c) > STRAY_R and u.position.distance_to(big["spot"]) > STRAY_R:
				_order(u, c, true, 80.0)        # (led off after a runner: back to the others)
				continue
			if u.target != null and is_instance_valid(u.target) and not u.target.dead and u.order == "attack":
				continue
			# (together: the ones far ahead of the rest wait for them on the way; then all go in)
			var p: Vector2 = big["spot"]
			if u.position.distance_to(p) < c.distance_to(p) - 220.0 and u.position.distance_to(p) > 260.0:
				p = u.position
			_order(u, p + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true, 70.0)
		defenders.clear()
		return true
	# A GROUP: each raid gets the nearest free units worth DEF_MARGIN times it, never fewer than GROUP_MIN
	phase = "gather"
	for a in raids:
		var spot: Vector2 = a["spot"]
		var sent: Array = defenders.keys().filter(func(u: Unit) -> bool: return (defenders[u]["spot"] as Vector2).distance_to(spot) < 350.0)
		var got := _value(sent)
		var need := float(a["value"]) * DEF_MARGIN
		if got >= need and sent.size() >= mini(GROUP_MIN, home.size()):
			continue
		var pool: Array = free.filter(func(u: Unit) -> bool: return not (a["air_only"] and not ai._hits_air(u)))
		pool.sort_custom(func(x: Unit, y: Unit) -> bool: return x.position.distance_to(spot) < y.position.distance_to(spot))
		var picks: Array = []
		for u in pool:
			if got >= need and sent.size() + picks.size() >= GROUP_MIN:
				break
			picks.append(u)
			got += ai._unit_value(u)
		if got < need * 0.8 and sent.is_empty():
			continue          # (not enough free to win it: the bigger raids first, the rest stay together)
		for u in picks:
			defenders[u] = {"spot": spot, "t0": game.clock}
			free.erase(u)
			_order(u, spot + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true, 60.0)
		if not picks.is_empty():
			stats["groups"] = int(stats["groups"]) + 1
			say("sends %d units (%d) as a group at a raid worth %d at %s" % [picks.size() + sent.size(), int(got), int(a["value"]), _where(spot)], "group", 10.0)
	return false


# ------------------------------------------------------------------ the kit in a fight

## THE SPRINGERS JUMP IN when the front engages: a Springer that is ready, not hurt, with the nearest enemy beyond its shot
## but within a jump and a shot, leaps to a spot in shooting reach of it (SPRING_AT of its range), on our side, where no
## enemy melee stands close and the enemies near the spot are not worth more than our front near it.
const SPRING_AT := 0.8
const SPRING_MELEE_R := 110.0


func spring_in(list: Array, foes: Array) -> void:
	if foes.is_empty():
		return
	var front_v := _value(list)
	for u in list:
		if u.kind != Defs.SPRINGER or u.hp < u.max_hp * 0.6 or Springer.ready_problem(u) != "":
			continue
		var near_o: Unit = null
		var nd := INF
		for o in foes:
			var dd: float = o.position.distance_to(u.position)
			if dd < nd:
				nd = dd
				near_o = o
		var rng: float = float(u.d["range"])
		var jr := float(Defs.SPRINGER_JUMP["range"])
		if near_o == null or nd <= rng + 10.0 or nd > rng + jr:
			continue
		var land: Vector2 = near_o.position + (u.position - near_o.position).normalized() * rng * SPRING_AT
		var melee := false
		var theirs := 0.0
		for o in foes:
			var od: float = o.position.distance_to(land)
			if od < SPRING_MELEE_R and float(o.d.get("range", 0.0)) < 60.0:
				melee = true
			if od < 260.0:
				theirs += ai._unit_value(o)
		if melee or theirs > front_v * 1.2:
			continue
		var l: Dictionary = Springer.landing(u, land)
		if not l.has("at"):
			continue
		Springer.start(u, l["at"])
		stats["springs"] = int(stats["springs"]) + 1
		say("a Springer jumps in to shoot at a %s" % String(near_o.d["name"]), "spring", 15.0)
