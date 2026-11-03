extends RefCounted
## THE CROWN HOLDS ITS MAIN AND SCOUTS WITH RIDERS (the owner's doctrine, 2026-11-03; docs/ai_crown_transitions.md
## section 10). The owner: "you expand, you keep your forces in the high ground, you saturate the expansion first, then you
## slowly wall in. You always have your main to run with your workers, and the musketeers in the main on HOLD with a cannon
## can hold a lot of attacks until we are ready to go down with the army. While we keep the main army on the main base we
## still scout the map with horsemen to know what our enemy is up to, and if we can we kill workers."
## 0.26.13 did the economy and the timings (AI.doctrine). This does the rest, for the Crown computer on Normal and up:
##  1. THE RAMP POST: the army at home stands on HOLD at the top of the main's ramp: the muskets in a line across it
##     (a lane left open in front of the gate), the guns behind them; it goes down only to attack, or to meet a force at
##     the expansion that it beats (BEAT). Against more, it holds the top and the expansion's labourers run up to it.
##  2. THE RIDER SCOUTS: one Horseman (two from 4) rides a loop round the map's hall sites and the foot of the enemy's
##     ramp; what it sees feeds the AI's picture (AIScout's sightings, the army counts); it hands itself to the harass
##     (AIHarass, the 0.26.7 raid micro) when it finds workers it can take, and comes home hurt or chased.
##  3. LIKE WITH LIKE FOR THE WALL: the new hall's slow wall compares the army at home with the enemy's MOBILE army seen
##     on our side of the map (a rooted Brood creature is a building, not an army coming at us), and waits for a
##     near-saturated economy (posts keep coming as farms go up: AI.saturated alone was rarely reached).
##  4. A TIMING AFTER THE EXPANSION: on two halls, the army goes down when it is worth clearly more than the enemy army
##     known, when it is big (GO_BIG) and not clearly behind, or big and the enemy has hidden its army, when the enemy is
##     seen taking a third hall, or when it has
##     not attacked for a long time and is not behind (never a trickle: GO_MIN supply at least).
## Design: docs/design_principles.md 2 (the defender's advantage, high ground and walls, early; the game moves on: the
## army goes down when ready), 3 (builders worth harassing: the scouts kill workers) and 4 (scouting reveals strategy).
## Study switches: `-- hold:off` (no ramp post, no timing), `-- hscout:off` (no rider scouts), `-- tr:off` (none of it).

const BEAT := 1.3              # the home army goes down to an expansion only worth this times the force there
const LINE_BACK := 2.6          # (tiles) the musket line stands this far behind the ramp's top band (behind its wall)
const GUN_BACK := 5.0           # (tiles) the guns this far
const LINE_GAP := 0.95          # (tiles) between muskets in the line
const ROW_GAP := 0.9            # (tiles) between rows
const ROW_LEN := 6              # muskets in a row
const LANE := 0.9               # (tiles) half the lane kept open in front of the gate
const HOLD_KINDS := ["musketeer", "musketeer_armoured", "dismounted", "dismounted_armoured"]
const GUN_KINDS := ["cannon", "mortar"]

const SCOUT_R := 330.0          # (px) armed enemies this near a scout are weighed
const SCOUT_HURT := 0.5         # a scout below this share of its hit points rides home
const SCOUT_PICK_HP := 0.75     # ... and none is picked below this
const SPOT_R := 110.0           # (px) a waypoint this close is reached
const SPOT_BAD := 75.0          # (s) a waypoint where a scout was chased off is skipped this long
const STUCK_T := 10.0           # (s) no progress this long: the next waypoint
const PREY_R := 9.0             # (tiles) enemy workers this near a scout can be hunted
const COOL := 45.0              # (s) a scout handed to the harass or sent home is not taken again for this long
const REPORT_EVERY := 75.0      # (s) the match log's scouting report

const SEEN_FOR := 120.0         # (s) an enemy soldier seen this long ago still counts in the army known
const NEAR_FOR := 90.0          # (s) ... and on our side of the map
const WALL_EDGE := 1.1          # the home army must be worth this times the enemy army seen on our side for the slow wall
const WALL_SAT := 0.85          # labourers at this share of the posts, the second hall up WALL_SAT_T s: saturated enough
const WALL_SAT_T := 90.0

const GO_MIN := 18              # the least supply a timing goes out with
const GO_SUP := 24              # army supply ...
const GO_EDGE := 1.2            # ... and worth this times the enemy army known: it goes down
const GO_BIG := 32              # supply: goes down when not clearly behind (GO_EVEN) ...
const GO_BLIND := 32            # ... or when the enemy army has not been seen for SEEN_FOR s
const GO_STALE := 240.0         # (s) on two halls with no attack this long: goes when not behind (GO_EVEN)
const GO_EVEN := 0.9
const GO_COOL := 90.0           # (s) after a wave, before the next timing

var ai = null
var on := not OS.get_cmdline_user_args().has("hold:off")
var scout_on := not OS.get_cmdline_user_args().has("hscout:off")

# the ramp post
var _geo_done := false
var _bc := Vector2.INF          # (cells) the middle of the ramp's top band
var _ramp_mid := Vector2.INF    # (cells) the middle of the ramp
var _in := Vector2.ZERO         # unit vector from the band into the main
var _home_h := 0
var _home_reg := -1
var _ramp_cells: Array = []
var _spots: Array = []          # musket spots (pixels), front row first
var _gun_spots: Array = []
var _spots_t := -999.0
var _slot := {}                 # Unit -> slot index (musket spots) or -1 - index (gun spots)
var _hold_said := -999.0
var holds := 0                  # (tests, the study) times the post held the top against a bigger force below

# the rider scouts
var scouts := {}                # Unit -> {"i": waypoint index, "dir": 1/-1, "back_until", "best_d", "best_t", "t0"}
var _cool := {}                 # Unit -> clock until which it is not picked
var _wps: Array = []            # the loop (pixels)
var _wps_done := false
var _bad := {}                  # waypoint index -> clock until which it is skipped
var _report_t := 0.0
var handoffs := 0               # (tests, the study)
var scout_log: Array = []       # [clock, text]

# what we know of the enemy army
var _seen := {}                 # enemy mobile soldier -> [clock, position, value]
var _seen_t := -99.0
var _last_army_t := -999.0      # when an enemy soldier was last in sight

# the timing
var _was_attacking := false
var _wave_end_t := -999.0
var _last_go_t := -999.0
var _two_halls_t := -1.0
var go_log: Array = []          # [clock, why]


func _init(a) -> void:
	ai = a


var game:
	get:
		return ai.game


func active() -> bool:
	return on and ai.doctrine()


func scouting() -> bool:
	return scout_on and ai.doctrine()


func _say(s: String) -> void:
	if game.mlog:
		game.mlog.add("%s %s" % [game.mlog.who(ai.team), s])


# ============================================================ every think (AI stage 2, before the raid)

func tick() -> void:
	if not ai.doctrine():
		return
	_watch()
	if not _geo_done:
		_geometry()     # (early: AI._ramp_bands skips cells a wall stands on)
	var nh: int = ai._halls().filter(func(h: Building) -> bool: return h.built).size()
	if nh >= 2 and _two_halls_t < 0.0:
		_two_halls_t = game.clock
	if _was_attacking and not ai._attacking:
		_wave_end_t = game.clock
	_was_attacking = ai._attacking
	if scouting():
		_scouts()


# ============================================================ what we know of the enemy army

## Every 3 s: each enemy soldier on its feet in sight (not a worker, a horse, a wagon, or a rooted Brood creature, which
## is a building) is noted with where and when.
func _watch() -> void:
	if game.clock - _seen_t < 3.0:
		return
	_seen_t = game.clock
	for u in _seen.keys():
		if not is_instance_valid(u) or u.dead or game.clock - float(_seen[u][0]) > SEEN_FOR:
			_seen.erase(u)
	for f in game.enemies_of(ai.team):
		for u in game.army(f):
			if u.dead or u.off_field or u.is_worker() or not u.has_attack() or u.kind in ["horse", "powder_wagon"]:
				continue
			if AIHarass.is_static(u):
				continue
			if not game.is_visible_to(ai.team, u.position):
				continue
			_seen[u] = [game.clock, u.position, float(Game.unit_value(u))]
			_last_army_t = game.clock


## The enemy army we know of: every soldier seen in the last SEEN_FOR s, each once.
func foe_known() -> float:
	var v := 0.0
	for u in _seen:
		v += float(_seen[u][2])
	return v


## The enemy army seen on our side of the map lately (nearer our main than its own, or near one of our halls).
func foe_near() -> float:
	var me: Vector2 = Vector2(game.starts[ai.team]) * Defs.TILE
	var foe: int = ai._foe()
	var them: Vector2 = Vector2(game.starts[foe]) * Defs.TILE if foe >= 0 else Vector2.INF
	var halls: Array = ai._halls()
	var v := 0.0
	for u in _seen:
		var e: Array = _seen[u]
		if game.clock - float(e[0]) > NEAR_FOR:
			continue
		var p: Vector2 = e[1]
		var ours := them == Vector2.INF or p.distance_to(me) < p.distance_to(them)
		if not ours:
			for h in halls:
				if (h as Building).center().distance_to(p) < 22.0 * Defs.TILE:
					ours = true
					break
		if ours:
			v += float(e[2])
	return v


func army_known_lately() -> bool:
	return game.clock - _last_army_t <= SEEN_FOR


## Our army at home (not out in a wave, raiding or scouting).
func home_value() -> float:
	var v := 0.0
	for u in game.army(ai.team):
		if u.dead or not u.has_attack() or u.kind == "powder_wagon" or ai._raiders.has(u) or scouts.has(u) or (ai._attacking and ai._wave_set.has(u)):
			continue
		if ai.harass != null and ai.harass.has(u):
			continue
		v += float(Game.unit_value(u))
	return v


# ============================================================ 3. the slow wall: like with like

## The new hall's wall waits (AI.wall_yield): the army at home is worth less than WALL_EDGE times the enemy's mobile army
## seen on our side of the map, or an armed enemy is at our buildings.
func wall_short() -> bool:
	if ai.tr._armed_near():
		return true
	return home_value() < foe_near() * WALL_EDGE


## Saturated enough for the slow wall: AI.saturated(), or the second hall up for WALL_SAT_T s with labourers at WALL_SAT of
## the posts (farms going up add posts faster than the halls train hands: AI.saturated alone came seldom).
func sat_for_wall() -> bool:
	if ai.saturated():
		return true
	if _two_halls_t < 0.0 or game.clock - _two_halls_t < WALL_SAT_T:
		return false
	return float(game.workers(ai.team).size()) >= float(ai._posts()) * WALL_SAT


# ============================================================ 1. the ramp post

func _geometry() -> void:
	_geo_done = true
	if game.starts.size() <= ai.team:
		return
	var home := Vector2(game.starts[ai.team]) + Vector2(2.5, 2.0)
	var hc := Vector2i(int(home.x), int(home.y))
	if not game.in_map(hc):
		return
	_home_h = int(game.height[game.idx(hc)])
	_home_reg = game.region_of(hc)
	var bands: Array = ai._ramp_bands()
	if bands.is_empty():
		return
	var band: Array = bands[0]["band"]
	_ramp_cells = bands[0]["ramp"]
	_ramp_mid = bands[0]["mid"]
	var bc := Vector2.ZERO
	for c in band:
		bc += Vector2(c) + Vector2(0.5, 0.5)
	_bc = bc / float(band.size())
	_in = (home - _bc).normalized()
	if _in == Vector2.ZERO:
		_in = (_bc - (_ramp_mid + Vector2(0.5, 0.5))).normalized() * -1.0


## The cell is on the main's high ground (its level and area, inside the ramp's top).
func on_main(p: Vector2) -> bool:
	var c: Vector2i = game.cell_of(p)
	if not game.in_map(c) or int(game.height[game.idx(c)]) != _home_h or int(game.ramp[game.idx(c)]) != 0:
		return false
	if _home_reg >= 0 and game.region_of(c) != _home_reg:
		return false
	var home := (Vector2(game.starts[ai.team]) + Vector2(2.5, 2.0)) * Defs.TILE
	if p.distance_to(home) > 26.0 * Defs.TILE:
		return false
	for rc in _ramp_cells:
		if Vector2(c).distance_to(Vector2(rc)) < 1.6:
			return false        # (the top of the ramp, outside the wall)
	return true


func _spot_ok(p: Vector2) -> bool:
	var c: Vector2i = game.cell_of(p)
	return game.in_map(c) and game.open_cell(c) and int(game.height[game.idx(c)]) == _home_h and int(game.ramp[game.idx(c)]) == 0 \
			and (_home_reg < 0 or game.region_of(c) == _home_reg)


## The line's spots across the ramp's top, behind its wall, with a lane open in front of the gate (worked out again every
## 30 s: the wall and buildings change).
func _layout() -> void:
	if game.clock - _spots_t < 30.0 and not _spots.is_empty():
		return
	_spots_t = game.clock
	_spots.clear()
	_gun_spots.clear()
	if _bc == Vector2.INF:
		return
	var T := float(Defs.TILE)
	var perp := Vector2(-_in.y, _in.x)
	# the lane: in front of our gate in the ramp wall, else the ramp's middle
	var lane_at: Vector2 = _bc
	var best := INF
	for b in game.buildings:
		if b.team == ai.team and not b.dead and b.kind == "gate":
			var gc: Vector2 = b.center() / T
			var d: float = gc.distance_to(_bc)
			if d < 5.0 and d < best:
				best = d
				lane_at = gc
	var lane_off: float = (lane_at - _bc).dot(perp)
	for row in 3:
		var back: float = LINE_BACK + ROW_GAP * row
		var placed := 0
		for k in 24:
			if placed >= ROW_LEN:
				break
			# (outwards from the middle, alternating sides)
			var side: float = (float(k / 2) + 0.5) * LINE_GAP * (1.0 if k % 2 == 0 else -1.0)
			if absf(side - lane_off) < LANE:
				continue
			var p: Vector2 = (_bc + _in * back + perp * side) * T
			if _spot_ok(p) and _spots.all(func(q: Vector2) -> bool: return q.distance_to(p) > T * 0.7):
				_spots.append(p)
				placed += 1
	for k in 3:
		var p2: Vector2 = (_bc + _in * GUN_BACK + perp * (float(k) - 1.0) * 1.6) * T
		if _spot_ok(p2):
			_gun_spots.append(p2)


## The waiting army takes its places at the ramp post: muskets on HOLD in the line, guns on HOLD behind it. Returns the
## units it does not place (horsemen and the rest wait at the rally as before).
func place(units: Array) -> Array:
	if not active():
		return units
	_layout()
	if _spots.is_empty():
		return units
	for u in _slot.keys():
		if not is_instance_valid(u) or u.dead or not units.has(u):
			_slot.erase(u)
	var used := {}
	for u in _slot:
		used[_slot[u]] = true
	var rest: Array = []
	for u in units:
		var gun: bool = u.kind in GUN_KINDS
		if not (u.kind in HOLD_KINDS or gun):
			rest.append(u)
			continue
		if not _slot.has(u):
			var n: int = _gun_spots.size() if gun else _spots.size()
			var got := -9999
			for i in n:
				var key: int = (-1 - i) if gun else i
				if not used.has(key):
					got = key
					break
			if got == -9999:
				# (more than the spots: the extra ones stand with the guns, or join the back row)
				got = (-1 - (used.size() % maxi(1, _gun_spots.size()))) if (gun and not _gun_spots.is_empty()) else (used.size() % _spots.size())
			_slot[u] = got
			used[got] = true
		var s: int = _slot[u]
		var spot: Vector2
		if s < 0:
			spot = _gun_spots[(-1 - s) % _gun_spots.size()] if not _gun_spots.is_empty() else _spots[_spots.size() - 1]
		else:
			spot = _spots[s % _spots.size()]
		_post(u, spot)
	return rest


func _post(u: Unit, spot: Vector2) -> void:
	if u.target != null and is_instance_valid(u.target) and not u.target.dead and u.order != "move":
		return          # (busy fighting: left be)
	var d: float = u.position.distance_to(spot)
	if d > 16.0:
		if u.order == "move" and u.order_point.distance_to(spot) < 8.0:
			return
		if u.order in ["idle", "hold", "move", "amove"]:
			u.cmd_move(spot)
	elif u.order != "hold":
		u.cmd_hold()
		u.facing = -_in      # (facing down the ramp)


## A threat while the army waits at home. On the main's high ground: the usual defence (false). Below (the expansion, the
## ramp's foot): the army goes down only to a force it beats by BEAT (false: AI._defend sizes it); against more it holds
## the top (true: AI._defend is skipped), and the labourers below run up to it (refuge).
func hold_top(army: Array, spots: Array) -> bool:
	if not active() or _bc == Vector2.INF:
		return false
	var home: Array = army.filter(func(u: Unit) -> bool: return not (ai._attacking and ai._wave_set.has(u)))
	if home.is_empty():
		return false
	for sp in spots:
		if on_main(sp):
			return false
	var foe := force_at(spots)
	var mine := 0.0
	for u in home:
		mine += ai._unit_value(u)
	if mine >= foe * _beat():
		return false
	if game.clock - _hold_said > 30.0:
		_hold_said = game.clock
		holds += 1
		_say("holds the top of its ramp: the force below (%d) is more than its army at home (%d) can beat; the labourers there run up" % [int(foe), int(mine)])
	if not ai._det.is_empty():
		ai._end_defence()
	var rest := place(home)
	var front: Vector2 = (_bc + _in * (GUN_BACK + 1.0)) * float(Defs.TILE)
	for u in rest:
		if u.order == "idle" and u.position.distance_to(front) > 160.0 and _spot_ok(front):
			u.cmd_move(front, true)
	return true


## BEAT, or what the computer's own plan says (AICrown.hold_beat: against a melee swarm in the open the value count flatters
## a musket line, so it goes down only with a bigger edge).
func _beat() -> float:
	return float(ai.hold_beat()) if ai.has_method("hold_beat") else BEAT


## The enemy force at these spots: the armed enemies in sight (or seen a moment ago) within FORCE_R of any of them, each
## once (AI._assess looks 300 px round one unit: a line of 12 Raptors counted as 6); nothing seen: AI.DEF_UNSEEN, or the army
## seen on our side lately if more; only unarmed ones (a scout): 0.
const FORCE_R := 450.0


func force_at(spots: Array) -> float:
	var got := {}
	var v := 0.0
	var seen_any := false
	for sp in spots:
		for o in game.units_near(sp, FORCE_R):
			if got.has(o) or not game.hostile(o.team, ai.team) or o.dead or o.off_field or not ai._sighted(o):
				continue
			seen_any = true
			if not ai._armed(o):
				continue        # (a scout or a worker: nothing to hold the top against)
			got[o] = true
			v += ai._unit_value(o)
	if not seen_any:
		v = maxf(float(ai.DEF_UNSEEN), foe_near())
	return v


## Where a labourer below the main runs from a raid the army will not come down to meet: up the ramp, behind the line.
## Vector2.INF when he should run as before (on the main, or the army goes down to meet it).
func refuge(w: Unit, centre: Vector2) -> Vector2:
	if not active() or _bc == Vector2.INF or on_main(w.position):
		return Vector2.INF
	var foe: float = force_at([centre])
	if home_value() >= foe * _beat():
		return Vector2.INF
	var p: Vector2 = (_bc + _in * (GUN_BACK + 2.0)) * float(Defs.TILE)
	return p if _spot_ok(p) else Vector2.INF


# ============================================================ 4. the timing after the expansion

## Called by AI._army before its wave check while the army waits: on two halls, the moment to go down. Lowers the wave bar
## to what stands at home when it is time (the rest of the wave rules apply as before).
func timing(ready: Array) -> void:
	if not active() or ai._attacking or ai.peaceful or _two_halls_t < 0.0:
		return
	if game.clock - _wave_end_t < GO_COOL or game.clock - _last_go_t < GO_COOL:
		return
	var sup: int = ai._army_supply(ready)
	if sup < GO_MIN or sup >= ai._attack_at:
		return
	var mine := 0.0
	for u in ready:
		mine += float(Game.unit_value(u))
	var foe := foe_known()
	var why := ""
	if army_known_lately() and sup >= GO_SUP and mine >= maxf(foe, 300.0) * GO_EDGE:
		why = "its army (%d, %d supply) is worth %.1f times the enemy army it knows (%d)" % [int(mine), sup, mine / maxf(foe, 300.0), int(foe)]
	elif army_known_lately() and sup >= GO_BIG and mine >= foe * GO_EVEN:
		why = "its army is big (%d supply, %d) and not behind the enemy army it knows (%d)" % [sup, int(mine), int(foe)]
	elif not army_known_lately() and sup >= GO_BLIND:
		why = "its army is big (%d supply) and the enemy army has not been seen for %d s" % [sup, int(game.clock - _last_army_t)]
	elif _foe_halls() >= 3 and mine >= foe * GO_EVEN:
		why = "the enemy is taking a third hall (%d seen) and its army (%d) is not behind (%d)" % [_foe_halls(), int(mine), int(foe)]
	elif game.clock - maxf(_two_halls_t, _wave_end_t) >= GO_STALE and mine >= foe * GO_EVEN:
		why = "no attack for %d s on two halls and its army (%d) is not behind (%d)" % [int(game.clock - maxf(_two_halls_t, _wave_end_t)), int(mine), int(foe)]
	if why == "":
		return
	_last_go_t = game.clock
	ai._attack_at = sup
	ai._regroup_until = 0.0
	go_log.append([game.clock, why])
	_say("goes down with its army: %s" % why)


func _foe_halls() -> int:
	if ai.scout == null or ai._foe() < 0:
		return 0
	var hk: String = game.faction_hall(ai._foe())
	var n := 0
	for b in ai.scout._seen_b.keys():
		if is_instance_valid(b) and not b.dead and b.kind == hk:
			n += 1
	return n


# ============================================================ 2. the rider scouts

func is_scout(u: Unit) -> bool:
	return scouts.has(u)


## No Horseman yet (none alive, none in training) while the doctrine scouts: the Barracks trains one first (AI._produce).
## Kestrel Rise study: the Breeder stood at 4:12 and the first Horseman came at 7:23 (a 30% pick at each Barracks).
func wants_rider() -> bool:
	if not scouting() or game.clock < 150.0:
		return false
	for u in game.army(ai.team):
		if u.kind == "cuirassier" and not u.dead:
			return false
	for b in ai._mine("barracks"):
		if (b.queue as Array).has("cuirassier"):
			return false
	return true


func _want() -> int:
	var n := 0
	for u in game.army(ai.team):
		if u.kind == "cuirassier" and not u.dead:
			n += 1
	if n <= 0:
		return 0
	return 1 if n < 4 else 2


## The loop: the map's hall sites (not our main or our halls, not the enemy's main), and the foot of the enemy's ramp,
## in order round the middle of the map.
func _loop() -> void:
	if _wps_done:
		return
	var foe: int = ai._foe()
	if foe < 0:
		return
	_wps_done = true
	var T := float(Defs.TILE)
	var pts: Array = []
	var hall_off := Vector2(MapGen.HALL) * 0.5
	for s in game.base_sites:
		var c: Vector2i = s
		if game.starts.has(c):
			continue
		var p: Vector2 = (Vector2(c) + hall_off) * T
		var q := _open_near(p)
		if q != Vector2.INF:
			pts.append(q)
	# the foot of the enemy's ramp (outside its main, toward us)
	var es := (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * T
	var ramp: Vector2 = ai.scout._find_ramp(Vector2(game.starts[ai.team]) * T) if ai.scout != null and ai.scout._foe == foe else Vector2.INF
	if ramp != Vector2.INF:
		var foot := _open_near(ramp + (ramp - es).normalized() * 4.0 * T)
		if foot != Vector2.INF:
			pts.append(foot)
	if pts.is_empty():
		return
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= float(pts.size())
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return (a - mid).angle() < (b - mid).angle())
	_wps = pts


func _open_near(p: Vector2) -> Vector2:
	var c0: Vector2i = game.cell_of(p)
	for r in 5:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := c0 + Vector2i(dx, dy)
				if game.in_map(c) and game.open_cell(c) and game.in_open_map(c):
					return game.cell_center(c)
	return Vector2.INF


func _scouts() -> void:
	for u in scouts.keys():
		if not is_instance_valid(u) or u.dead:
			scouts.erase(u)
	for u in _cool.keys():
		if not is_instance_valid(u) or float(_cool[u]) < game.clock:
			_cool.erase(u)
	_loop()
	if _wps.is_empty():
		return
	var want := _want()
	if ai._rush_state == "ongoing" or (ai.opening == "breeder" and ai.strategy == "rush") or ai._rush_open():
		want = 0       # (a Horseman rush or the raid party that is the rush: every rider rides with it)
	while scouts.size() > want:
		_release(scouts.keys()[scouts.size() - 1], "")
	if scouts.size() < want:
		_pick(want)
	for u in scouts.keys():
		_ride(u)
	_report()


func _pick(want: int) -> void:
	var home: Vector2 = game.center_of_team(ai.team)
	var pool: Array = game.army(ai.team).filter(func(u: Unit) -> bool:
		return u.kind == "cuirassier" and not u.dead and not scouts.has(u) and not _cool.has(u) and u.hp >= u.max_hp * SCOUT_PICK_HP \
				and not ai._raiders.has(u) and not ai._det.has(u) and not (ai._attacking and ai._wave_set.has(u)) and not ai._horse_coming(u) \
				and not ai._on_errand(u) and not (ai.harass != null and ai.harass.has(u)) and not (ai.scout != null and ai.scout.is_scout(u)) \
				and u.order in ["idle", "move", "amove", "hold"] and u.target == null)
	pool.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(home) < b.position.distance_to(home))
	for u in pool:
		if scouts.size() >= want:
			break
		# (the second rider rides the loop the other way round, from the far side)
		var dir := 1 if scouts.is_empty() else -1
		var i := _nearest_wp(u.position) if scouts.is_empty() else (_nearest_wp(u.position) + _wps.size() / 2) % _wps.size()
		scouts[u] = {"i": i, "dir": dir, "back_until": 0.0, "best_d": INF, "best_t": game.clock, "t0": game.clock}
		_log("sends a Horseman to scout the map (a loop of %d spots: the hall sites and the foot of the enemy's ramp)" % _wps.size())


func _nearest_wp(p: Vector2) -> int:
	var best := 0
	for i in _wps.size():
		if (_wps[i] as Vector2).distance_to(p) < (_wps[best] as Vector2).distance_to(p):
			best = i
	return best


func _release(u: Unit, why: String) -> void:
	scouts.erase(u)
	_cool[u] = game.clock + COOL
	if why != "":
		_log("'s scout rides home (%s)" % why)
	if is_instance_valid(u) and not u.dead:
		var post: Vector2 = ai._post_spot()
		u.cmd_move(post if post != Vector2.INF else game.center_of_team(ai.team))


func _log(s: String) -> void:
	scout_log.append([game.clock, s])
	if game.mlog:
		game.mlog.add("%s%s%s" % [game.mlog.who(ai.team), "" if s.begins_with("'") else " ", s])


## One scout, every think: chased or hurt it rides home (or away from the danger); workers it can take: it hands itself
## to the harass; else on round the loop.
func _ride(u: Unit) -> void:
	var e: Dictionary = scouts[u]
	if u.hp < u.max_hp * SCOUT_HURT:
		_release(u, "hurt")
		return
	# danger: what can catch it, or shoot it from where it stands
	var danger := Vector2.ZERO
	var n_danger := 0
	for o in game.units_near(u.position, SCOUT_R):
		if not game.hostile(o.team, ai.team) or o.dead or o.off_field or not AIHarass.is_defender(o):
			continue
		if not game.is_visible_to(ai.team, o.position):
			continue
		var rng := float(o.d.get("range", 0))
		var catches: bool = o.speed >= u.speed * 0.85
		var shoots: bool = rng >= 100.0 and o.position.distance_to(u.position) < rng + 90.0 and o.can_hit(u)
		if catches or shoots:
			danger += o.position
			n_danger += 1
	if n_danger > 0:
		danger /= float(n_danger)
		_bad[int(e["i"])] = game.clock + SPOT_BAD
		if n_danger >= 3 or u.hp < u.max_hp * 0.7:
			_release(u, "chased")
			return
		var away: Vector2 = u.position + (u.position - danger).normalized() * 260.0
		if not game.passable(game.cell_of(away), ai.team):
			away = game.center_of_team(ai.team)
		e["back_until"] = game.clock + 5.0
		_next_wp(e)
		u.cmd_move(away)
		return
	if game.clock < float(e["back_until"]):
		return
	# workers it can take: the harass hunts them (the raid micro)
	var prey := _prey(u)
	if prey != Vector2.INF:
		var foes: Array = ai.hz().defenders_near(prey, [u])
		if not ai.hz().outmatched([u], foes) and ai.hz().add(u, "the scout found workers"):
			scouts.erase(u)
			_cool[u] = game.clock + COOL
			handoffs += 1
			_log("'s scout found workers to hunt: it hands over to the raid")
			return
	var wp: Vector2 = _wps[int(e["i"])]
	var d: float = u.position.distance_to(wp)
	if d < SPOT_R or game.clock - float(e["best_t"]) > STUCK_T:
		_next_wp(e)
		wp = _wps[int(e["i"])]
		d = u.position.distance_to(wp)
	if d < float(e["best_d"]) - 30.0:
		e["best_d"] = d
		e["best_t"] = game.clock
	if u.order != "move" or u.order_point.distance_to(wp) > 40.0:
		u.cmd_move(wp)


func _next_wp(e: Dictionary) -> void:
	var n := _wps.size()
	var i: int = int(e["i"])
	for k in n:
		i = posmod(i + int(e["dir"]), n)
		if float(_bad.get(i, -1.0)) < game.clock:
			break
	e["i"] = i
	e["best_d"] = INF
	e["best_t"] = game.clock


## Enemy workers in sight near the scout, away from their defenders: where they are (Vector2.INF: none).
func _prey(u: Unit) -> Vector2:
	var c := Vector2.ZERO
	var n := 0
	for o in game.units_near(u.position, PREY_R * Defs.TILE):
		if game.hostile(o.team, ai.team) and not o.dead and not o.off_field and o.is_worker() and game.is_visible_to(ai.team, o.position):
			c += o.position
			n += 1
	if n < 2:
		return Vector2.INF
	return c / float(n)


func _report() -> void:
	if game.clock - _report_t < REPORT_EVERY or scouts.is_empty():
		return
	_report_t = game.clock
	var tech := []
	if ai.scout != null:
		for b in ai.scout._seen_b.keys():
			if is_instance_valid(b) and not b.dead and AIScout.MILITARY.has(b.kind) and not tech.has(b.kind):
				tech.append(b.kind)
	_log("'s scouts know: an enemy army of %d (seen in the last %d s), %d enemy hall%s, tech %s" % [int(foe_known()), int(SEEN_FOR),
			_foe_halls(), "" if _foe_halls() == 1 else "s", ", ".join(PackedStringArray(tech)) if not tech.is_empty() else "none seen"])
