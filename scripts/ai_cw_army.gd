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
const HOLD_K := 0.55            # (clockwork-home) worth less than this share of the raid: it holds on its gears instead
const HOLD_FAR := 600.0         # (px from the gathering point: a raid nearer is met where it is)
const LEASH := 520.0            # px from our nearest building: defenders further than this walk back
const STRAY_R := 360.0          # px: in a whole-army defence, one this far from the others and from the raid comes back
const CALM := 6.0               # s with no raid before the defenders walk back
const GATHER_R := 200.0         # px: a unit further than this from the gathering point walks to it
const REGATHER := 12.0          # s between two picks of the gathering point
const TOKEN_SHARE := 0.12       # (clockwork-home) a TOKEN raid (all its spots together) is worth less than this share of
const TOKEN_MIN := 150.0        # the army, kept between these (a Raptor is 25, a Clock Soldier 70): a group meets it, the
const TOKEN_MAX := 300.0        # rest stays on its gears; anything more and the whole army defends the base
const STAY_DEFEND := 15.0       # s the whole army stays at a raid that has shrunk to a token one (then a group finishes it)
var _big_t := -99.0
const MASS_SINCE := 0.0         # (the opening's steady production: AIClockwork._bo_mass)
## The enemy army a Hard computer of that faction has at that age (value; [clock s, value]), from the coached games
## (docs/clockwork_army.md): the Brood's is the Crown's crown-v-brood table, raised before 7:00 (its Rootmaws and Mound
## Turtles fight where the push goes: 10 Clock Soldiers went at 5:23 on the old table and lost 490 for 250); the Crown's and the Clockwork's from the
## "before" games here (the lowest seen, so a weak enemy is not over-feared). (clockwork-ai-v2: the Brood's from 7:00 cut to
## the Hard Brood's army in the qa study's 152 Brood sides (0.33.7, the strongest quarter: 900 at 7:00, 1,150 at 8:00, 1,880
## at 10:00, 2,730 at 12:00); it was about twice that (5,000 at 12:00), 1.8 to 3.5 times the Brood's real army in the
## before games, and the Clockwork's army waited at home against the Brood until it was out-grown. Its rooted creatures
## seen still count on top, _rooted_seen.)
const TABLES := {
	"brood": [[0.0, 0.0], [180.0, 150.0], [300.0, 700.0], [360.0, 1000.0], [420.0, 1100.0], [480.0, 1300.0], [540.0, 1600.0], [600.0, 1900.0], [720.0, 2700.0], [840.0, 3100.0]],
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
var stats := {"groups": 0, "whole": 0, "holds": 0, "looks": 0, "springs": 0, "waits": 0, "leashed": 0}
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
	if _wave_at_door():
		return false
	if _counter_ok(mine):
		return true
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


## (clockwork-v-brood-coach, docs/clockwork-v-brood-coach.md, round 1) THE COUNTER-PUSH: against the Brood, a wave HELD at
## home is the moment to go. When the whole army's defence of the base has killed COUNTER_KILL or more and the base is calm
## again, for COUNTER_T s the push may go out worth COUNTER_K times the enemy army it has seen lately (alive), at least
## COUNTER_MIN, whatever the last failed push or the reckoning's table say (the table does not know the wave just died).
## (Greenhold 11, 12:45: the Brood's wave of 2,570 pulled back with 620 left; the Clockwork held at its gathering point
## with 2,595 for two minutes, "its last push (2800) had to pull back; the next goes worth 3500", while the Brood rebuilt
## to 3,785.) `-- cvbcounter:off` plays it as before.
const COUNTER_KILL := 600.0
const COUNTER_T := 75.0
const COUNTER_K := 1.4
const COUNTER_MIN := 900.0
const COUNTER_TAB := 0.7
var counter_on := not OS.get_cmdline_user_args().has("cvbcounter:off")
var _def_vk := -1.0             # value killed when the whole-army defence began
var _held_t := -999.0           # when a defence that killed COUNTER_KILL or more ended
var _held_v := 0.0
var counters := 0


## (round 2, Greenhold 11, 8:44: the push went out "against the 1,822 it reckons (a report 0 s old)" into the Brood's wave
## of 56 supply just reaching the base, met it in the open in front of its own gears and pulled back 12 s later having
## lost 1,555 of 2,420.) Against the Brood the push does not go while an enemy army worth DOOR_V or more is in sight
## within DOOR_R px of its buildings: the army meets it on its gears first, then counter-attacks (_counter_ok).
const DOOR_R := 900.0
const DOOR_V := 300.0


func _wave_at_door() -> bool:
	if not counter_on:
		return false
	var foe := _foe()
	if foe < 0 or game.faction_of(foe) != "brood":
		return false
	var v := 0.0
	for o in game.army(foe):
		if o.dead or o.off_field or not ai._armed(o) or BroodNew.rooted(o) or o.is_air() or not game.is_visible_to(team, o.position):
			continue
		if ai._home_dist(o.position) < DOOR_R:
			v += ai._unit_value(o)
	if v < DOOR_V:
		return false
	say("holds at its gathering point: a Brood army of %d is at its door; it meets it on its gears first" % int(v), "door", 30.0)
	return true


func _held_note() -> void:
	var vk := float(game.stats[team]["value_killed"])
	if phase == "defend":
		if _def_vk < 0.0:
			_def_vk = vk
		return
	if _def_vk >= 0.0:
		if vk - _def_vk >= COUNTER_KILL:
			_held_t = game.clock
			_held_v = vk - _def_vk
		_def_vk = -1.0


func _counter_ok(mine: float) -> bool:
	if not counter_on or game.clock - _held_t > COUNTER_T:
		return false
	var foe := _foe()
	if foe < 0 or game.faction_of(foe) != "brood":
		return false
	var seen: float = ai.push.foe_mem() if ai.push != null else 0.0
	# (round 2, Greenhold 11 at 12:03: a counter of 950 went out against "135 seen alive" while the Brood had 1,500 coming:
	# at least COUNTER_TAB of the reckoning's table for that minute too)
	var tab: Array = TABLES.get("brood", [])
	if mine < maxf(maxf(COUNTER_MIN, seen * COUNTER_K), table_at(tab, game.clock) * COUNTER_TAB):
		return false
	_held_t = -999.0
	_fail_v = 0.0
	counters += 1
	say("counter-attacks: its defence killed %d, it goes out worth %d against the %d it has seen alive lately" % [int(_held_v), int(mine), int(seen)])
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
## (clockwork-home: on the edge of its gear ground where the enemy's way in reaches the base: _gather_home)
func _gather_point() -> Vector2:
	if home_on:
		var hp := _gather_home()
		if hp != Vector2.INF:
			return hp
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


# ------------------------------------------------------------------ clockwork-home: the army rests on its gears

## THE ARMY RESTS ON ITS GEARS (the owner, 2026-11-06, Hard Brood OPTIMAL v Hard Clockwork OPTIMAL, Kestrel Rise 0.33.0:
## the idle army wound down; at 9:58 it waited at its gathering point by the newest Clocktower, (70, 45), while the base
## below was attacked and only pieces of it went; docs/clockwork_home.md):
##  - THE GATHERING POINT is where the enemy's way in (the path from its main to the middle of our base) first reaches our
##    gear ground, on that ground's level: between the base and the way enemies come, not in front of the Clocktower that
##    happens to be nearest the enemy's main in a straight line (Kestrel Rise: the third Clocktower, north, while the Brood
##    came in from the west);
##  - each unit has its own REST SPOT round it at the gear ground's edge: on a still floor plate inside a ring when there is
##    room (wound there for good), else just outside the toothed band (a band turns and would carry it round; the computer
##    walks its idle units off a band: docs/gear_turn.md); the big machines (not carried) stand on the band itself;
##  - TOPPING UP: a unit at its spot run down under TOP_AT steps onto the band (0.3 a second on the gear ground: two or
##    three seconds fill it), a few at a time, and walks back; the escort Winders wind the rest as before.
## `-- cwhome:off` plays 0.33.0's gathering point and raid answers (the "before" columns).
var home_on := not OS.get_cmdline_user_args().has("cwhome:off")
const ENTRY_NEAR := 40.0        # gear px past the band's tips: where the path counts as at the gear ground
const HOME_REPICK := 30.0       # s between two picks of the gathering point (sooner when a hall comes or goes; never in a fight)
const SPOT_R := 520.0           # px: rest spots on the rings within this of the gathering point
const SPOT_GAP := 26.0          # px between two rest spots
const SPOT_TOL := 40.0          # px: a unit this near its spot is at rest
const TOP_AT := 0.8             # wind under which a resting unit steps onto the gears to top up
const TOP_FULL := 0.98          # it walks back once wound this far
const TOP_MAX := 12.0           # s a top-up may take at most
var _home_key := ""
var _spots_v := -1
var _home_t := -99.0
var _spots: Array = []          # [{p, fp (a point on the band beside it), field (on a still plate: wound there)}]
var _bspots: Array = []         # the band spots for the big machines (not carried)
var _spot_of := {}              # Unit -> index into _spots (or -1 - index into _bspots)
var _topping := {}              # Unit -> clock it went to top up
var home_stats := {"tops": 0, "picks": 0}


func _my_bands() -> Array:
	var out: Array = []
	if game.gear_net == null:
		return out
	for bd in game.gear_net.bands:
		var b = bd[0]
		if is_instance_valid(b) and not b.dead and b.team == team:
			out.append(bd)
	return out


## The gathering point on the enemy's way in, at the edge of our gear ground (INF: none found, the old pick).
func _gather_home() -> Vector2:
	var halls: Array = ai._halls().filter(func(h: Building) -> bool: return h.built and not h.dead)
	var bands := _my_bands()
	if halls.is_empty() or bands.is_empty() or _foe() < 0:
		return Vector2.INF
	var key := ""
	for h in halls:
		key += str(h.get_instance_id()) + ","
	if gather_pt != Vector2.INF and (key == _home_key and game.clock - _home_t < HOME_REPICK or phase == "defend" or phase == "hold"):
		if game.gear_net.version != _spots_v and phase != "defend" and phase != "hold":
			_spots_v = game.gear_net.version
			_build_spots(gather_pt, bands)       # (a ring more or less: the spots again, the point stays)
		return gather_pt
	_spots_v = game.gear_net.version
	_home_key = key
	_home_t = game.clock
	var mid := Vector2.ZERO
	for h in halls:
		mid += (h as Building).center()
	mid /= float(halls.size())
	var their: Vector2 = (Vector2(game.starts[_foe()]) + Vector2(2.5, 2.0)) * Defs.TILE
	var path: PackedVector2Array = game.find_path(their, mid)
	var pick := Vector2.INF
	var prev := their
	for i in path.size():
		var a: Vector2 = prev
		var b: Vector2 = path[i]
		prev = b
		var n := maxi(1, int(a.distance_to(b) / 16.0))
		for k in n + 1:
			var p := a.lerp(b, float(k) / float(n))
			var bd = _ring_near(p, bands)
			if bd != null:
				pick = p
				break
		if pick != Vector2.INF:
			break
	if pick == Vector2.INF:
		pick = _edge_toward(halls, bands, their)
	if pick == Vector2.INF:
		return Vector2.INF
	home_stats["picks"] = int(home_stats["picks"]) + 1
	var moved := gather_pt == Vector2.INF or gather_pt.distance_to(pick) > 96.0
	gather_pt = pick
	_build_spots(pick, bands)
	if moved:
		say("the army rests on its gears at %s, where the enemy's way in reaches the base" % _where(pick), "gpt", 30.0)
	return gather_pt


## (no way in found: the path ends short of the gear ground) The edge of the ring of the hall nearest the enemy's main,
## toward it.
func _edge_toward(halls: Array, bands: Array, their: Vector2) -> Vector2:
	var best: Building = null
	for h in halls:
		if best == null or (h as Building).center().distance_to(their) < best.center().distance_to(their):
			best = h
	for bd in bands:
		if bd[0] != best:
			continue
		var cg: Vector2 = bd[1]
		var dir := (GearNet.gpos(their) - cg).normalized()
		var lv := GearNet.b_level(best)
		for a: float in [0.0, 0.4, -0.4, 0.8, -0.8, 1.2, -1.2, 1.6, -1.6]:
			var q := cg + dir.rotated(a) * (float(bd[3]) + ENTRY_NEAR * 0.5)
			var w := Vector2(q.x, q.y * Game.FIELD_Y)
			var c: Vector2i = game.cell_of(w)
			if game.in_map(c) and _spot_ok(w, lv, game.region_of(c)):
				return w
	return Vector2.INF


## A ring of ours whose band's tips are within ENTRY_NEAR (gear px) of p, on p's ground level; else null.
func _ring_near(p: Vector2, bands: Array):
	var c: Vector2i = game.cell_of(p)
	if not game.in_map(c) or not game.open_cell(c):
		return null
	var g := GearNet.gpos(p)
	for bd in bands:
		if g.distance_to(bd[1]) <= float(bd[3]) + ENTRY_NEAR and GearNet.b_level(bd[0]) == game.height[game.idx(c)]:
			return bd
	return null


func _spot_ok(w: Vector2, lv: int, reg: int) -> bool:
	var c: Vector2i = game.cell_of(w)
	if not game.in_map(c) or not game.open_cell(c) or game.height[game.idx(c)] != lv or game.region_of(c) != reg:
		return false
	return game._clear_at(w, 14.0, -2)


## The rest spots round the gathering point: still plates first, then rows just outside the bands; nearest first.
func _build_spots(gp: Vector2, bands: Array) -> void:
	_spots = []
	_bspots = []
	_spot_of.clear()
	var gc: Vector2i = game.cell_of(gp)
	var lv: int = game.height[game.idx(gc)]
	var reg: int = game.region_of(gc)
	var fy := Game.FIELD_Y
	var net = game.gear_net
	var cand: Array = []            # [score, spot]
	var bcand: Array = []
	for bd in bands:
		var cg: Vector2 = bd[1]
		var r_in := float(bd[2])
		var r_out := float(bd[3])
		var cw := Vector2(cg.x, cg.y * fy)
		if cw.distance_to(gp) - r_out > SPOT_R or GearNet.b_level(bd[0]) != lv:
			continue
		var rp := r_out - 6.0
		for rr: float in [r_in - 14.0, r_out + 18.0, r_out + 44.0, r_out + 70.0, (r_in + rp) * 0.5]:
			if rr < 20.0:
				continue
			var steps := maxi(8, int(TAU * rr / SPOT_GAP))
			for k in steps:
				var dir := Vector2.RIGHT.rotated(TAU * float(k) / float(steps))
				var q := cg + dir * rr
				var w := Vector2(q.x, q.y * fy)
				if w.distance_to(gp) > SPOT_R or not _spot_ok(w, lv, reg):
					continue
				var on_band: bool = net.band_at(w, 0.0) >= 0
				var in_f: bool = net.in_field(team, w)
				if rr == (r_in + rp) * 0.5:
					if on_band and in_f:
						bcand.append([w.distance_to(gp), {"p": w}])
					continue
				if net.band_at(w, 10.0) >= 0:
					continue          # (on a band, or at its edge: it would ride)
				var fpg := cg + dir * ((r_in + rp) * 0.5)
				var fpw := Vector2(fpg.x, fpg.y * fy)
				var plate := in_f and rr < r_in
				cand.append([w.distance_to(gp) - (90.0 if plate else 0.0), {"p": w, "fp": fpw, "field": plate}])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	bcand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for e in cand:
		var s: Dictionary = e[1]
		if _spots.any(func(o: Dictionary) -> bool: return (o["p"] as Vector2).distance_to(s["p"]) < SPOT_GAP * 0.85):
			continue
		_spots.append(s)
		if _spots.size() >= 90:
			break
	for e in bcand:
		var s: Dictionary = e[1]
		if _bspots.any(func(o: Dictionary) -> bool: return (o["p"] as Vector2).distance_to(s["p"]) < 40.0):
			continue
		_bspots.append(s)
		if _bspots.size() >= 12:
			break


## The rest spot of this unit (kept while the gathering point stands); {} when there is none free.
func _spot_for(u: Unit) -> Dictionary:
	var s := _spot_pick(u, not GearTurn.carriable(u) and not u.is_air())
	if s.is_empty() and not GearTurn.carriable(u):
		s = _spot_pick(u, false)
	return s


func _spot_pick(u: Unit, big: bool) -> Dictionary:
	var have = _spot_of.get(u)
	if have != null:
		var i := int(have)
		if i >= 0 and i < _spots.size():
			return _spots[i]
		if i < 0 and -1 - i < _bspots.size():
			return _bspots[-1 - i]
	var used := {}
	for x in _spot_of:
		used[_spot_of[x]] = true
	var list: Array = _bspots if big else _spots
	var best := -1
	var bd := INF
	for i in list.size():
		var key := (-1 - i) if big else i
		if used.has(key):
			continue
		# (the nearest free spot to the gathering point first: they fill from the way in outwards)
		var d: float = float(i) * 1000.0 + (list[i]["p"] as Vector2).distance_to(u.position) * 0.01
		if d < bd:
			bd = d
			best = i
	if best < 0:
		return {}
	_spot_of[u] = (-1 - best) if big else best
	return list[best]


## At home: each to its rest spot; the run-down ones top up on the band a few at a time.
func _rest(home: Array, g: Vector2, waiting: Dictionary) -> void:
	for u in _spot_of.keys():
		if not is_instance_valid(u) or u.dead or not home.has(u):
			_spot_of.erase(u)
	for u in _topping.keys():
		if not is_instance_valid(u) or u.dead or not home.has(u):
			_topping.erase(u)
	var cap := maxi(3, home.size() / 3)
	var want: Array = []
	for u in home:
		if waiting.has(u):
			continue
		if u.order == "attack" and u.target != null and is_instance_valid(u.target) and not u.target.dead and u.position.distance_to(g) < GATHER_R * 1.5:
			continue          # (fighting something at the gathering point itself)
		var s := _spot_for(u)
		if s.is_empty():
			if u.position.distance_to(g) > GATHER_R or u.order == "idle" and u.position.distance_to(g) > GATHER_R * 0.6:
				_order(u, ai._home_spot(g), _amove_home(u), 90.0)
			continue
		var sp: Vector2 = s["p"]
		var dist: float = u.position.distance_to(sp)
		if _topping.has(u):
			if u.wind >= TOP_FULL or game.clock - float(_topping[u]) > TOP_MAX or ai._enemy_near(u.position, 300.0):
				_topping.erase(u)
				_order(u, sp, false, 16.0)
			elif u.order == "idle" and not u._in_field:
				_order(u, s["fp"], false, 12.0)      # (walked off the band before it was full: once more)
			continue
		if dist > SPOT_TOL:
			_order(u, sp, dist > GATHER_R and _amove_home(u), 16.0)
			continue
		if u.deploys() and u.order == "idle" and u.tesla_mode == "packed":
			u.cmd_deploy()
		if s.has("fp") and not bool(s.get("field", false)) and u.wind < TOP_AT and not u.runs_on_spring() and not u._in_field \
				and u.order == "idle":
			want.append(u)
	want.sort_custom(func(a: Unit, b: Unit) -> bool: return a.wind < b.wind)
	for u in want:
		if _topping.size() >= cap or ai._enemy_near(u.position, 300.0):
			break
		_topping[u] = game.clock
		home_stats["tops"] = int(home_stats["tops"]) + 1
		_order(u, _spots[int(_spot_of[u])]["fp"], false, 12.0)
	if not want.is_empty():
		say("the army rests on its gears: %d run-down units step onto the gears to wind" % mini(want.size(), cap), "tops", 60.0)


## (clockwork-ai-v2) A unit out far from our buildings walks home with a PLAIN move: an attack-move from out there stops
## at the first enemy on the way, a ROOTED Mound Turtle included (test_ai_harass [clock]: 40 s at one). Nearer home the
## walk back is an attack-move, as before (raiders by the base are met on the way).
const FAR_PLAIN := 640.0


func _amove_home(u: Unit) -> bool:
	return ai._home_dist(u.position) < FAR_PLAIN


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
	var defending := _defend(home, g)
	_held_note()
	if defending:
		ai._follow_with_escort(home + low if ai.push == null or ai.push.phase == "" or ai.push.phase == "back" else ai.push.units)
		return
	phase = "out" if (ai.push != null and ai.push.phase != "" and ai.push.phase != "back") else "gather"
	var waiting := _muster(home, g)
	if home_on and not _spots.is_empty():
		_rest(home, g, waiting)
		if ai.push == null or ai.push.phase == "" or ai.push.phase == "back":
			ai._follow_with_escort(home + low)
		else:
			ai._follow_with_escort(ai.push.units)
		return
	for u in home:
		if waiting.has(u):
			continue
		if u.order == "attack" and u.target != null and is_instance_valid(u.target) and not u.target.dead and u.position.distance_to(g) < GATHER_R * 1.5:
			continue          # (fighting something at the gathering point itself)
		if u.position.distance_to(g) > GATHER_R or u.order == "idle" and u.position.distance_to(g) > GATHER_R * 0.6:
			_order(u, ai._home_spot(g), _amove_home(u), 90.0)
		elif u.deploys() and u.order == "idle" and u.tesla_mode == "packed":
			u.cmd_deploy()
	if ai.push == null or ai.push.phase == "" or ai.push.phase == "back":
		ai._follow_with_escort(home + low)     # (the Winders keep the waiting army wound and mended)
	else:
		ai._follow_with_escort(ai.push.units)  # (out: the escort goes with the push, AIClockwork._follow_with_escort)


## REINFORCEMENTS WALK TOGETHER (an experiment, off: see muster_on): a unit made far from the gathering point (more than MUSTER_FAR) first waits at the
## MUSTER, in front of the main hall, and they walk to the army as a group of GROUP_MIN or more (or MUSTER_SUPPLY supply).
## (One at a time across the base from the main's Works to a third Clocktower, they met the Raptor raids alone: 16 times in
## one game, Cinder Steps.) Returns the units waiting there (the gathering orders leave them be).
const MUSTER_FAR := 640.0
const MUSTER_R := 220.0
const MUSTER_SUPPLY := 6
const MUSTER_MAX := 50.0        # s a unit waits at the muster at most (then it goes anyway)
## (OFF unless `-- cwmuster:on`: tried and measured, docs/clockwork_army.md "The muster": with it on, 10 games against the
## Brood lost more (4,507 against 3,818 by 10:00) and fought alone more often (5.8 against 2.7 a game): the units held in
## the main were missing from the army when the Raptors came, and were raided at the muster themselves.)
var muster_on := OS.get_cmdline_user_args().has("cwmuster:on")
var _walking := {}              # Unit -> true: let go from the muster, on its way to the army
var _mustered := {}             # Unit -> clock it reached the muster


func _muster(home: Array, g: Vector2) -> Dictionary:
	var waiting := {}
	if not muster_on:
		return waiting
	var m: Vector2 = ai._post_spot()
	for u in _walking.keys():
		if not is_instance_valid(u) or u.dead or u.position.distance_to(g) < GATHER_R:
			_walking.erase(u)
	for u in _mustered.keys():
		if not is_instance_valid(u) or u.dead:
			_mustered.erase(u)
	if m == Vector2.INF or m.distance_to(g) < MUSTER_FAR:
		return waiting
	var far: Array = home.filter(func(u: Unit) -> bool: return not _walking.has(u) and not defenders.has(u) \
		and u.position.distance_to(g) > MUSTER_FAR and u.position.distance_to(m) < g.distance_to(m))
	if far.is_empty():
		return waiting
	var at_m: Array = far.filter(func(u: Unit) -> bool: return u.position.distance_to(m) < MUSTER_R)
	for u in at_m:
		if not _mustered.has(u):
			_mustered[u] = game.clock
	var oldest := INF
	for u in at_m:
		oldest = minf(oldest, float(_mustered[u]))
	if at_m.size() >= GROUP_MIN or ai._army_supply(at_m) >= MUSTER_SUPPLY or (not at_m.is_empty() and game.clock - oldest > MUSTER_MAX):
		for u in at_m:
			_walking[u] = true
			_mustered.erase(u)
			_order(u, ai._home_spot(g), true, 90.0)
		say("%d fresh units walk from the main to the army together" % at_m.size(), "muster", 30.0)
		far = far.filter(func(u: Unit) -> bool: return not at_m.has(u))
	for u in far:
		waiting[u] = true
		if u.position.distance_to(m) > MUSTER_R * 0.6:
			_order(u, ai._home_spot(m), true, 90.0)
	return waiting


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
			if home_on:
				say("the base is calm again: the army walks back to rest on its gears", "calm", 20.0)
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
	var whole := bv >= mine * WHOLE_SHARE
	if home_on:
		# (clockwork-home) THE WHOLE ARMY DEFENDS THE BASE unless the raid is a token one far from it: the raids counted
		# together (a swarm comes in at several buildings at once: Kestrel Rise 9:16-9:56 was one attack of 65 Raptors met by
		# groups of 4, 13, 7 and 6), and once it has gone it stays until the base is calm again
		var total := 0.0
		for a in raids:
			total += float(a["value"])
		var c0 := _centre(home) if not home.is_empty() else g
		var token := total < clampf(mine * TOKEN_SHARE, TOKEN_MIN, TOKEN_MAX) and total < mine * WHOLE_SHARE
		if not token:
			_big_t = game.clock
		whole = not token or (phase == "defend" and game.clock - _big_t < STAY_DEFEND)
		bv = maxf(bv, total)
		if whole:
			# (the raid to go to: the biggest; one nearly as big and much nearer first)
			for a in raids:
				if float(a["value"]) >= float(big["value"]) * 0.6 and (a["spot"] as Vector2).distance_to(c0) < (big["spot"] as Vector2).distance_to(c0) - 300.0:
					big = a
	# THE WHOLE ARMY: the biggest raid is worth a good share of it
	if not home.is_empty() and whole:
		var main_g: Vector2 = ai._post_spot()
		if home_on and mine < bv * HOLD_K and (big["spot"] as Vector2).distance_to(g) > HOLD_FAR and not _spots.is_empty():
			# (clockwork-home) FAR STRONGER THAN THE WHOLE ARMY (as 0.33.0's rule at the main), away from its gathering point: it
			# does not walk out into it; it holds together on its gears, wound and mended there, and meets it when it comes.
			# (Tried at 0.8 of the raid: 7 games against the Brood lost more buildings, 6.3 a game against 1.3: holding while the
			# Raptors ate the Winders and presses cost more than meeting them.)
			if phase != "hold":
				stats["holds"] = int(stats["holds"]) + 1
			phase = "hold"
			say("a raid worth %d at %s is far stronger than its %d: the whole army holds together on its gears at %s, the Winders mend it" % [int(bv), _where(big["spot"]), int(mine), _where(g)], "hold", 30.0)
			for u in home:
				var sp := _spot_for(u)
				var to: Vector2 = sp["p"] if not sp.is_empty() else ai._home_spot(g)
				if u.order == "attack" and u.target != null and is_instance_valid(u.target) and not u.target.dead and u.position.distance_to(g) < GATHER_R * 1.5:
					continue          # (fighting at the gathering point itself)
				_order(u, to, u.position.distance_to(to) < 300.0, 40.0)
			defenders.clear()
			return true
		if not home_on and mine < bv * GIVE_UP and main_g != Vector2.INF and (big["spot"] as Vector2).distance_to(main_g) > 700.0:
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
			if home_on:
				say("the whole army defends the base (%d units, %d, with its Winders) against a raid worth %d at %s" % [home.size(), int(mine), int(bv), _where(big["spot"])], "whole", 20.0)
			else:
				say("the whole army (%d units, %d) meets a raid worth %d at %s" % [home.size(), int(mine), int(bv), _where(big["spot"])], "whole", 20.0)
		phase = "defend"
		var c := _centre(home)
		for u in home:
			if ai._home_dist(u.position) > LEASH and u.target != null and is_instance_valid(u.target) and u.target is Unit \
					and not u.target.dead and ai._home_dist(u.target.position) > LEASH * 0.7:
				# (ai-followups: THE CHASE ENDS at the leash: a unit led out after a fast rider leaving the base walks back
				# to the gathering point, not on across the map; the owner's Crown v Clockwork game 0.33.0, 7:18)
				_order(u, ai._home_spot(g), false, 60.0)
				stats["leashed"] = int(stats.get("leashed", 0)) + 1
				say("gives up a chase %d px out from its buildings: back to its gathering point" % int(ai._home_dist(u.position)), "leash", 20.0)
				continue
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
			if home_on:
				say("a small raid worth %d at %s, far from the army: sends %d units (%d) at it, the rest stays on its gears" % [int(a["value"]), _where(spot), picks.size() + sent.size(), int(got)], "group", 10.0)
			else:
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
