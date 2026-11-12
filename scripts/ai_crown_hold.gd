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
const ROW_LEN := 6              # muskets in a row (at least: crown-line-fight, up to ROW_MAX in one row, see _row_len)
const ROW_MAX := 12
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
var _slot_mode := "ramp"        # the spots the slots index: "ramp" (the ramp post) or "edge" (the cliff edge, section 5)
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
	if active():
		_mend_tick()


# ============================================================ 5. THE CLIFF EDGE (0.29.2, docs/crown_cliff_edge.md)
# The owner (2026-11-03, Thornwood Maze, watching 0.29.0): "Crown did the right thing holding the high ground, but he could
# have abused the high ground better: the musketeers were behind the wall, far from the limit of the high ground; it could
# have been hugging the high ground, gaining more range to defend the town hall and not lose it. Also sending a few workers
# to repair it and juke around, trying to repair while the musketeers killed the Raptors."
#  - THE EDGE POST: while the army holds the top (hold_top) against a force below that is at a building of ours below the
#    main (not by the ramp: then the ramp post holds as before), the musket line and the guns move to the main's
#    high-ground cells nearest that building, within Musketeer reach of it (the cliff's lip), spread along it, on HOLD,
#    facing down. Only cells joined to the post on the main's level are used (never down the ramp). The enemy below sees
#    up a cliff only a cell (Game._stamp): the line shoots, the claws below cannot climb to it. It walks back to the ramp
#    post EDGE_KEEP s after the threat below is gone.
#  - REPAIR UNDER FIRE: while the edge post guards a hurt building, MEND_MIN-MEND_MAX labourers (never more than
#    MEND_SHARE of them) repair it; one a claw comes at runs to the cliff's foot under the line (or away), and goes back to
#    mend when it is clear. None go when the building falls anyway before the line can kill what is on it (_hopeless),
#    when the force there is HOPELESS times the line, or after MEND_LOSS of them died on it (for MEND_REST s).
# Study switch: `-- edge:off` (the ramp post only, no menders).
const EDGE_RAMP := 6.0          # (tiles) a threat this near the ramp's top: the ramp post holds as before
const EDGE_KEEP := 4.0          # (s) the edge post lasts this long after the last look that wanted it
const EDGE_EVERY := 1.5         # (s) the edge line planned again this often
const EDGE_SHOT := 185.0        # (px) a spot within this of the building's side (the musket's 190, a margin)
const EDGE_GAP := 0.95          # (tiles) between muskets on the edge
const EDGE_GUN_GAP := 1.5       # (tiles) between a gun and anything else
const EDGE_R := 30.0            # (tiles) the main's high ground looked at round its hall
const EDGE_MIN := 4             # musket spots in reach at least (fewer: the line stays where it is)
const MEND_MIN := 2
const MEND_MAX := 4
const MEND_SHARE := 0.2         # of the labourers at most
const MEND_LOSS := 2            # menders dead on one building: no more for MEND_REST s
const MEND_REST := 30.0
const DODGE_R := 70.0           # (px) a claw going for a mender within 3 times this: he runs
const DODGE_CLOSE := 30.0       # (px) ... or any claw this near him (one busy on the building beside him is let be)
const DODGE_T := 1.6            # (s) he runs this long at least before he goes back
const HOPELESS := 3.0           # the force at the building worth this times the line in reach of it: no menders
const MEND_SENT_MAX := 8        # menders sent to one building at most (then a rest of MEND_REST s)
const MEND_SITE_HP := 0.4       # a site going up is mended only above this share of its hit points
var edge_on := not OS.get_cmdline_user_args().has("edge:off")
var _edge_until := -99.0
var _edge_t := -99.0
var _edge_b: Building = null    # the building the edge post guards
var _edge_aim := Vector2.INF    # (px) where it looks
var _edge_spots: Array = []     # musket spots (px), nearest the building first
var _edge_guns: Array = []
var _edge_foot := Vector2.INF   # (px) the low ground under the line: where a mender runs
var edge_moves := 0             # (tests, the coach) times the post moved to an edge
var edge_log: Array = []        # [clock, text]
var _menders := {}              # Unit -> {"dodge": clock until which he runs, "run": bool}
var _mend_b: Building = null
var _mend_lost := 0
var _mend_sent_b := 0
var _mend_stop := -99.0
var _mend_said := -99.0
var mend_sent := 0              # (tests, the coach)
var mend_dodges := 0
var mend_hp := 0.0              # hit points mended (tests, the coach)


func edge_live() -> bool:
	return edge_on and game.clock < _edge_until and not _edge_spots.is_empty()


func is_mender(u: Unit) -> bool:
	return _menders.has(u)


## The main's high-ground cells joined to the ramp post on its level now (buildings, walls and the ramp's top left out).
func _main_cells() -> Array:
	var out: Array = []
	var T := float(Defs.TILE)
	var home := Vector2(game.starts[ai.team]) + Vector2(2.5, 2.0)
	var start: Vector2i = game.cell_of((_bc + _in * LINE_BACK) * T)
	if not game.in_map(start) or int(game.height[game.idx(start)]) != _home_h or not game.passable(start, ai.team):
		start = game.nearest_free(Vector2i(int(home.x), int(home.y) + 3), 6)
	if not game.in_map(start) or int(game.height[game.idx(start)]) != _home_h:
		return out
	var seen := {start: true}
	var q: Array = [start]
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		out.append(p)
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + dd
			if seen.has(n) or not game.in_map(n):
				continue
			var i: int = game.idx(n)
			if int(game.height[i]) != _home_h or game.ramp[i] != 0 or game.cliff[i] != 0 or not game.passable(n, ai.team):
				continue
			if (Vector2(n) + Vector2(0.5, 0.5)).distance_to(home) > EDGE_R:
				continue
			seen[n] = true
			q.append(n)
	return out


## (ai-followups) A building inside a natural with a wall plan (AIExpandWall) that is being laid or stands: its defence is
## the line inside that palisade, not the main's cliff edge (the edge is for the main alone, before there is a walled
## natural, or a building right under the cliff without a wall).
const NATURAL_R := 16.0         # (tiles) round a walled hall
var edge_skips := 0             # (tests) buildings left to the palisade's line
var edge_why := ""              # (tests) what the last edge post was for


func _in_walled_natural(b: Building) -> bool:
	if ai.xw == null:
		return false
	var T := float(Defs.TILE)
	for id in ai.xw.plans:
		var p: Dictionary = ai.xw.plans[id]
		if not p.get("ok", false) or (p["exposed"] as Array).is_empty():
			continue
		var h = p.get("hall")
		if h == null or not is_instance_valid(h) or (h as Building).dead:
			continue
		if ai.xw.closed_share(p) <= _cc_edge_floor():
			continue
		if (h as Building).center().distance_to(b.center()) < NATURAL_R * T:
			edge_skips += 1
			return true
		for sl in p["slots"]:
			# (crown-ai-v2: a building standing IN the wall (a slot: the slots wait for their buildings now) is part of the
			# palisade's line, held from inside it, though its far side may lie past NATURAL_R; test_crown_owner_eco's
			# Raptors at the natural's palisade drew the line to the main's cliff edge above a slot Barracks)
			if sl.get("b") == b:
				edge_skips += 1
				return true
	return false


## Called by hold_top: the threat below is at a building of ours under the main's cliff: the line goes to the edge above it.
func _edge_plan(home: Array, spots: Array) -> void:
	if not edge_on or _bc == Vector2.INF:
		return
	if game.clock - _edge_t < EDGE_EVERY:
		if edge_live():
			_edge_until = game.clock + EDGE_KEEP
		return
	_edge_t = game.clock
	var T := float(Defs.TILE)
	var below: Array = []
	for sp in spots:
		if (sp as Vector2).distance_to(_bc * T) >= EDGE_RAMP * T:
			below.append(sp)
	if below.is_empty():
		return                  # (the fight is at the ramp: the ramp post is the place; an edge post still on runs out)
	# the building it is at: ours, below the main's level, the hall first, a hurt one first
	var hall_k: String = game.faction_hall(ai.team)
	var best: Building = null
	var bs := INF
	var skipped := false
	for b in game.buildings:
		if b.team != ai.team or b.dead or game.level_of(b.center()) == _home_h:
			continue
		if b.kind == "wall" or b.kind == "gate" or _in_walled_natural(b):
			# (ai-followups: a palisade is held from INSIDE it (_wall_plan, the gate post), never from the cliff above: the
			# owner's game 0.33.0, 5:29-5:55, "the cliff edge above its Palisade", 158-182 px off it)
			if below.any(func(sp: Vector2) -> bool: return b.edge_distance(sp) <= 330.0):
				skipped = true
			continue
		for sp in below:
			var d: float = b.edge_distance(sp)
			if d > 330.0:
				continue
			var sc: float = d - (300.0 if b.kind == hall_k else 0.0) - (150.0 if game.clock - b.hit_clock < 5.0 else 0.0)
			if sc < bs:
				bs = sc
				best = b
	if best == null and skipped:
		return                  # (ai-followups: the enemy is at the walled natural: the line there meets it, not the edge)
	var aim: Vector2 = best.center() if best != null else below[0]
	edge_why = ("%s at %s" % [best.kind, str(best.cell)]) if best != null else ("ground at %s" % str(game.cell_of(below[0])))
	# (claws at the ramp too: the edge only when most of them are at the building, the gate holds the rest a while)
	var at_ramp := _armed_value(_bc * T, EDGE_RAMP * T)
	if at_ramp > 0.0 and at_ramp > 0.5 * _armed_value(aim, 330.0):
		return
	# the spots: the main's cells within a musket's reach of it, nearest the claws at it first (they often hit its far
	# side: the cells by its corners reach round it), else nearest it
	var claws: Array = []
	for o in game.units_near(aim, 330.0):
		if game.hostile(o.team, ai.team) and not o.dead and not o.off_field and ai._armed(o) and ai._sighted(o) and not o.is_air():
			claws.append(o.position)
	var cands: Array = []
	for c in _main_cells():
		var p: Vector2 = game.cell_center(c)
		if not on_main(p):
			continue            # (the ramp's top and the far main left out)
		var d: float = best.edge_distance(p) if best != null else INF
		for sp in below:
			d = minf(d, p.distance_to(sp) + 20.0)
		var dc := INF
		for q in claws:
			dc = minf(dc, p.distance_to(q))
		if d <= EDGE_SHOT or dc <= EDGE_SHOT + 15.0:
			cands.append([minf(d + 40.0, dc) if dc < INF else d, p])
	if cands.is_empty():
		_edge_spots.clear()
		_edge_guns.clear()
		_edge_until = -99.0
		return
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and (a[1] as Vector2).x < (b[1] as Vector2).x))
	var n_gun := 0
	var n_musk := 0
	for u in home:
		if u.kind in GUN_KINDS:
			n_gun += 1
		elif u.kind in HOLD_KINDS:
			n_musk += 1
	var guns: Array = []
	var muskets: Array = []
	for e in cands:
		if guns.size() >= n_gun:
			break
		var p: Vector2 = e[1]
		if guns.all(func(q: Vector2) -> bool: return q.distance_to(p) >= EDGE_GUN_GAP * T):
			guns.append(p)
	for e in cands:
		if muskets.size() >= maxi(n_musk, 1):
			break
		var p: Vector2 = e[1]
		if muskets.all(func(q: Vector2) -> bool: return q.distance_to(p) >= EDGE_GAP * T) and guns.all(func(q: Vector2) -> bool: return q.distance_to(p) >= EDGE_GUN_GAP * T * 0.8):
			muskets.append(p)
	if muskets.size() < mini(EDGE_MIN, maxi(1, n_musk)):
		return                  # (a corner of the edge with room for one or two: the line stays where it is)
	var was := edge_live() and not _wall_mode
	_wall_mode = false
	var moved: bool = not was or _edge_b != best or (not _edge_spots.is_empty() and (_edge_spots[0] as Vector2).distance_to(muskets[0]) > 3.0 * T)
	_edge_spots = muskets
	_edge_guns = guns
	_edge_b = best
	_edge_aim = aim
	_edge_until = game.clock + EDGE_KEEP
	_edge_foot = _foot_under(muskets, aim)
	if moved:
		edge_moves += 1
		var what := ("its %s" % String(Defs.BUILDINGS[best.kind]["name"])) if best != null else "the enemy below"
		var txt := "moves its musket line to the cliff edge above %s: %d spots on the high ground, the nearest %d px from it" % [what, muskets.size(), int(float(cands[0][0]))]
		edge_log.append([game.clock, txt])
		_say(txt)


func _armed_value(p: Vector2, r: float) -> float:
	var v := 0.0
	for o in game.units_near(p, r):
		if game.hostile(o.team, ai.team) and not o.dead and not o.off_field and ai._armed(o) and ai._sighted(o):
			v += ai._unit_value(o)
	return v


## The low ground at the cliff's foot under the line, toward the building (a mender runs there: the claws after him are shot).
func _foot_under(line: Array, aim: Vector2) -> Vector2:
	var mid := Vector2.ZERO
	for p in line:
		mid += p
	mid /= float(line.size())
	var dir := (aim - mid).normalized()
	for k in range(1, 12):
		var p := mid + dir * float(k) * Defs.TILE * 0.5
		var c: Vector2i = game.cell_of(p)
		if game.in_map(c) and int(game.height[game.idx(c)]) < _home_h and game.passable(c, ai.team) and game.ramp[game.idx(c)] == 0:
			return game.cell_center(c)
	return Vector2.INF


## REPAIR UNDER FIRE, every think: menders for the building the edge post guards, each dodging the claws.
func _mend_tick() -> void:
	for u in _menders.keys():
		if not is_instance_valid(u) or u.dead:
			_menders.erase(u)
			_mend_lost += 1
	var b: Building = _edge_b
	var ok: bool = edge_on and edge_live() and b != null and is_instance_valid(b) and not b.dead and b.hp < b.max_hp - 1.0 and game.clock >= _mend_stop
	if ok and b != _mend_b:
		_mend_b = b
		_mend_lost = 0
		_mend_sent_b = 0
	var why := ""
	if ok and _mend_lost >= MEND_LOSS:
		ok = false
		_mend_stop = game.clock + MEND_REST
		why = "%d of its menders died there" % _mend_lost
	if ok and _mend_sent_b >= MEND_SENT_MAX and _menders.is_empty():
		ok = false
		_mend_stop = game.clock + MEND_REST
		why = "%d sent to it already" % _mend_sent_b
	if ok and not b.built and b.hp < b.max_hp * MEND_SITE_HP:
		ok = false              # (a site going up, still weak: its builders' business, not a mending party's)
	if ok:
		why = _hopeless(b)
		ok = why == ""
		if not ok:
			_mend_stop = game.clock + MEND_REST * 0.5      # (no coming and going on every look)
	if not ok:
		if not _menders.is_empty():
			if why != "" and game.clock - _mend_said > 20.0:
				_mend_said = game.clock
				_say("calls its menders off (%s)" % why)
			for u in _menders.keys():
				if is_instance_valid(u) and not u.dead:
					u.cmd_stop()        # (idle: the economy puts him back to work)
			_menders.clear()
		return
	var labs: Array = game.workers(ai.team)
	var want: int = MEND_MIN + (1 if b.hp < b.max_hp * 0.6 else 0) + (1 if b.hp < b.max_hp * 0.4 else 0)
	want = mini(mini(want, MEND_MAX), maxi(mini(MEND_MIN, labs.size() / 3), int(float(labs.size()) * MEND_SHARE)))
	if _menders.size() < want:
		var free: Array = labs.filter(func(w: Unit) -> bool:
			return not w.dead and not _menders.has(w) and w.order != "build" and not w.keg and w.crate_site == null \
					and not (ai.scout != null and ai.scout.is_scout(w)) and not ai._escort.has(w) and not ai._fighters.has(w))
		free.sort_custom(func(x: Unit, y: Unit) -> bool: return b.edge_distance(x.position) < b.edge_distance(y.position))
		var first := _menders.is_empty()
		for w in free:
			if _menders.size() >= want:
				break
			_menders[w] = {"dodge": 0.0, "run": false, "hp0": b.hp}
			ai._fled.erase(w)
			mend_sent += 1
			_mend_sent_b += 1
			_mend(w, b)
		if first and not _menders.is_empty():
			_say("sends %d labourers to mend its %s under the line's fire" % [_menders.size(), String(Defs.BUILDINGS[b.kind]["name"])])
	for w in _menders.keys():
		var e: Dictionary = _menders[w]
		var claw := _claw_on(w)
		if claw != null:
			if not bool(e["run"]):
				e["run"] = true
				mend_dodges += 1
			e["dodge"] = game.clock + DODGE_T
			var to := _edge_foot
			if to == Vector2.INF or claw.position.distance_to(to) < w.position.distance_to(to) or w.position.distance_to(to) < 24.0:
				to = w.position + (w.position - claw.position).normalized() * 150.0
				if not game.passable(game.cell_of(to), ai.team):
					to = _edge_foot if _edge_foot != Vector2.INF else (_bc + _in * (GUN_BACK + 2.0)) * Defs.TILE
			if w.order != "move" or w.order_point.distance_to(to) > 40.0:
				w.cmd_move(to)
		elif game.clock >= float(e["dodge"]):
			e["run"] = false
			if not (w.order in ["repair", "build"] and w.order_target == b):
				_mend(w, b)


func _mend(w: Unit, b: Building) -> void:
	if b.built:
		w.cmd_repair(b)
	else:
		w.cmd_build(b)


## An enemy claw at a mender: one going for him within 3 times DODGE_R, or any within DODGE_CLOSE.
func _claw_on(w: Unit) -> Unit:
	for o in game.units_near(w.position, DODGE_R * 3.0):
		if not game.hostile(o.team, ai.team) or o.dead or o.off_field or o.is_worker() or not o.has_attack() or o.is_air():
			continue
		var d: float = o.position.distance_to(w.position)
		if d < DODGE_CLOSE or (o.target == w and d < DODGE_R * 3.0):
			return o
	return null


## Why mending this building is no use now ("" when it is worth it): nothing of ours shoots at what is on it, the force
## there is HOPELESS times the line, or it falls before the line can kill that force.
func _hopeless(b: Building) -> String:
	var foe_v := 0.0
	var foe_hp := 0.0
	var foe_dps := 0.0
	for o in game.units_near(b.center(), 330.0):
		if not game.hostile(o.team, ai.team) or o.dead or o.off_field or not ai._armed(o) or b.edge_distance(o.position) > 120.0:
			continue
		foe_v += ai._unit_value(o)
		foe_hp += o.hp
		foe_dps += maxf(0.5, float(o.d.get("damage", 0)) - float(b.d.get("armor", 0))) / maxf(0.3, float(o.d.get("cooldown", 1.0)))
	if foe_v <= 0.0:
		return ""
	var line_v := 0.0
	var line_dps := 0.0
	for u in game.army(ai.team):
		if u.dead or not u.has_attack() or u.is_worker():
			continue
		var rng := float(u.d.get("range", 0))
		if rng < 100.0 or b.edge_distance(u.position) > rng + 40.0:
			continue
		line_v += ai._unit_value(u)
		line_dps += float(u.d.get("damage", 0)) / maxf(0.5, float(u.d.get("cooldown", 1.0)))
	if line_dps <= 0.0:
		return "nothing of ours shoots at what is on it"
	if foe_v > line_v * HOPELESS:
		return "the force there (%d) is more than %.0f times the line in reach (%d)" % [int(foe_v), HOPELESS, int(line_v)]
	var kill_t := foe_hp / line_dps
	var fall_t := b.hp / maxf(0.1, foe_dps)
	if fall_t < kill_t * 0.5:
		return "it falls in %d s, the line needs %d s" % [int(fall_t), int(kill_t)]
	return ""


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
	var me: Vector2 = game.start_mid(ai.team)
	var foe: int = ai._foe()
	var them: Vector2 = game.start_mid(foe) if foe >= 0 else Vector2.INF
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
## (crown-line-fight) The ramp post's muskets in ONE line across the ramp's top and along the lip either side of it, up to
## ROW_MAX, before a second row: coached, Red Coast 1125 8:06 (Crown v Clockwork), eight Musketeers stood three deep behind
## the ramp's gate (rows of ROW_LEN) while 1,140 of Clockwork burned the Cottage at the natural below; only the front row
## reached. A line wide as its muskets (tools/study_line_ranks.gd: one rank up to 16) brings them all to the lip.
func _row_len() -> int:
	return clampi(_n_musk, ROW_LEN, ROW_MAX) if ai.has_method("line_ai") and ai.line_ai() != null and ai.ln.active() else ROW_LEN


var _n_musk := 0                # the muskets the ramp post was last asked to place


func _layout() -> void:
	if game.clock - _spots_t < 30.0 and not _spots.is_empty() and (_spots.size() >= _n_musk or _spots.size() >= _row_len() * 3):
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
			if placed >= _row_len():
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
	var nm0 := 0
	for u in units:
		if u.kind in HOLD_KINDS:
			nm0 += 1
	if nm0 > _n_musk + 2 or nm0 < _n_musk - 4:
		_spots_t = -999.0       # (crown-line-fight: the row's length follows the muskets: laid again)
	_n_musk = nm0
	_layout()
	var spots_m: Array = _spots
	var spots_g: Array = _gun_spots
	var mode := "ramp"
	if edge_live():
		spots_m = _edge_spots       # (5. THE CLIFF EDGE: the line on the high ground's lip above the threatened building)
		spots_g = _edge_guns
		mode = "wall" if _wall_mode else "edge"      # (or inside a walled hall's palisade: _wall_plan)
	else:
		# (7. THE GATE POST: once there is a walled natural, the army's home is down at its gate, not the main's ramp)
		var nm := 0
		var ng := 0
		for u in units:
			if u.kind in GUN_KINDS:
				ng += 1
			elif u.kind in HOLD_KINDS:
				nm += 1
		_gate_plan(nm, ng)
		if gate_live():
			spots_m = _gate_spots
			spots_g = _gate_guns
			mode = "gate"
	if mode != _slot_mode:
		_slot.clear()
		_slot_mode = mode
	if spots_m.is_empty():
		return units
	var face: Vector2 = -_in if mode == "ramp" else (_gate_face if mode == "gate" else Vector2.INF)
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
			var n: int = spots_g.size() if gun else spots_m.size()
			var got := -9999
			for i in n:
				var key: int = (-1 - i) if gun else i
				if not used.has(key):
					got = key
					break
			if got == -9999:
				# (more than the spots: the extra ones stand with the guns, or join the back row)
				got = (-1 - (used.size() % maxi(1, spots_g.size()))) if (gun and not spots_g.is_empty()) else (used.size() % spots_m.size())
			_slot[u] = got
			used[got] = true
		var s: int = _slot[u]
		var spot: Vector2
		if s < 0:
			spot = spots_g[(-1 - s) % spots_g.size()] if not spots_g.is_empty() else spots_m[spots_m.size() - 1]
		else:
			spot = spots_m[s % spots_m.size()]
		_post(u, spot, face if face != Vector2.INF else (_edge_aim - spot).normalized(), mode != "ramp")
	return rest


func _post(u: Unit, spot: Vector2, face := Vector2.INF, edge := false) -> void:
	spot = game.site_keepout(ai.team, spot, u.radius)      # (crown-hold: a post on a site waiting to start stands beside it)
	if u.target != null and is_instance_valid(u.target) and not u.target.dead and u.order != "move":
		# (busy fighting: left be; on the way to the edge only a fight at hand keeps him: a gun shooting from the ramp post
		# at something far below goes to the edge, where the claws at the building are)
		if not edge or u.target.position.distance_to(u.position) < 200.0 or u.position.distance_to(spot) < 16.0:
			return
	var d: float = u.position.distance_to(spot)
	if d > 16.0:
		if u.order == "move" and u.order_point.distance_to(spot) < 8.0:
			return
		if u.order in ["idle", "hold", "move", "amove"]:
			u.cmd_move(spot)
	elif u.order != "hold":
		u.cmd_hold()
		u.facing = face if face != Vector2.INF and face != Vector2.ZERO else -_in      # (facing down the ramp, or down the cliff)


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
	# (crown-owner-eco, C: an attack on a walled hall's palisade: the army stands inside that wall and shoots over it)
	if _wall_plan(home, spots):
		if not ai._det.is_empty():
			ai._end_defence()
		place(home)
		return true
	if _wall_mode:
		# (crown-ai-v2: the wall post's spots end with it; left on they read as a cliff-edge post (edge_live) for EDGE_KEEP s
		# after the army left the palisade, test_crown_owner_eco's "not the cliff edge of the main" half the runs)
		_edge_spots.clear()
		_edge_guns.clear()
		_edge_until = -99.0
	_wall_mode = false
	var foe := force_at(spots)
	var mine := 0.0
	for u in home:
		mine += ai._unit_value(u)
	if gate_live():
		# (7. THE GATE POST: the army's home is the natural's palisade: a force it beats is met the usual way (AI._defend
		# sizes it); against more it holds the gate, and the labourers run in behind the line)
		if mine >= foe * _beat():
			return false
		if mine >= foe * INSIDE_BEAT and _inside_natural(spots):
			# (crown-v-brood-coach: the force is already INSIDE the natural's wall, at its Mill and Farms: Hollowfen 1188, 8:39,
			# 522 of army stood facing out of the gate while 325 of Raptors and Spitters razed the Powder Mill and two Farms
			# behind it; it is met the usual way when the army is worth as much)
			if game.clock - _inside_said > 30.0:
				_inside_said = game.clock
				_say("turns from its natural's gate to the enemy inside its wall (%d against %d)" % [int(mine), int(foe)])
			return false
		if game.clock - _hold_said > 30.0:
			_hold_said = game.clock
			holds += 1
			_say("holds its natural's gate: the force outside (%d) is too strong to go out to with its army at home (%d), out at %d; the labourers run in behind the line" % [int(foe), int(mine), int(ceil(foe * _beat()))])
		if not ai._det.is_empty():
			ai._end_defence()
		var rest_g := place(home)
		for u in rest_g:
			if u.order == "idle" and u.position.distance_to(_gate_back) > 160.0:
				u.cmd_move(_gate_back, true)
		return true
	if mine >= foe * _beat():
		# (5. THE CLIFF EDGE: a force it could beat below, but the edge covers where it is: it shoots from the high ground
		# instead of going down; the claws below cannot climb to it)
		if not edge_on:
			return false
		_edge_plan(home, spots)
		if not edge_live():
			return false
		if not ai._det.is_empty():
			ai._end_defence()
		place(home)
		return true
	if game.clock - _hold_said > 30.0:
		_hold_said = game.clock
		holds += 1
		_say("holds the top of its ramp: the force below (%d) is more than its army at home (%d) can beat, down at %d; the labourers there run up" % [int(foe), int(mine), int(ceil(foe * _beat()))])
	if not ai._det.is_empty():
		ai._end_defence()
	_edge_plan(home, spots)
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
	if gate_live() and _gate_back != Vector2.INF:
		return _gate_back           # (7. THE GATE POST: in behind the line at the natural's gate)
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
	if ai.has_method("blind_guard") and ai.blind_guard():
		# (crown-v-brood: against the Brood no timing goes on an army it has not seen: a fresh look first, and the enemy
		# army weighed is the reckoning (AICrown.foe_estimate), never the 0 of an army out of sight)
		foe = ai.foe_estimate()
		if not ai.scouted_fresh():
			if sup >= GO_SUP and game.clock - maxf(_two_halls_t, _wave_end_t) >= GO_STALE * 0.5:
				ai.want_look("the timing")
			return
		if sup >= GO_SUP and mine >= maxf(foe, 300.0) * GO_EDGE:
			why = "its army (%d, %d supply) is worth %.1f times the Brood army it reckons (%d; %d seen lately)" % [int(mine), sup, mine / maxf(foe, 300.0), int(foe), int(foe_known())]
		if why == "":
			return
		_last_go_t = game.clock
		ai._attack_at = sup
		ai._regroup_until = 0.0
		go_log.append([game.clock, why])
		_say("goes down with its army: %s" % why)
		return
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
	if ai.has_method("rider_waits") and ai.rider_waits():
		return false        # (AICrown: against the Brood the first horse goes to a Field Cannon)
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
	var ramp: Vector2 = ai.scout._find_ramp(game.start_mid(ai.team)) if ai.scout != null and ai.scout._foe == foe else Vector2.INF
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



# ============================================================ 6. THE WALL POST (crown-owner-eco, docs/crown_owner_eco.md)
# The owner (2026-11-04 19:57, pictures eco_v_eco_3 and _5): "the Crown army should have left the high ground for the
# palisade of the natural base; the high ground only makes sense when there is no wall" and "the Crown is still defending
# the high ground with a low ground attack at its wall". On the owner's plans (AICrown.owner_on), when the threat is at a
# hall whose wall ring (AIExpandWall) is closed at least WALL_CLOSED, the army goes to the INSIDE of that wall where it is
# hit: the muskets in rows WALL_IN tiles behind the palisade nearest the claws (a musket reaches 190 px: well over the
# stakes), the guns WALL_GUN_IN behind them, on HOLD facing out; labourers mend the hurt piece (the edge post's menders,
# REPAIR UNDER FIRE). The cliff edge (5) stays for a hall WITHOUT a wall, the ramp post for the main.
# Study switch: `-- wallpost:off`.
const WALL_CLOSED := 0.7        # share of a hall's ways-in cells closed for its wall to be stood behind
const WALL_NEAR := 9.0          # (tiles) a threat this near a ways-in cell of the plan is "at the wall"
const WALL_IN := Vector2(1.0, 3.3)      # (tiles) the musket rows this far inside the wall's pieces
const WALL_GUN_IN := Vector2(3.6, 6.5)  # (tiles) the guns
const WALL_FRONT := 10.0        # (tiles) the stretch of wall stood behind: pieces this near the claws
var wall_on := not OS.get_cmdline_user_args().has("wallpost:off")
var _wall_mode := false
var _wall_t := -99.0
var _wall_hall: Building = null
var wall_moves := 0             # (tests, the coach)
var wall_log: Array = []        # [clock, text]


func wall_live() -> bool:
	return _wall_mode and edge_live()


func _wall_plan(home: Array, spots: Array) -> bool:
	if not wall_on or not ai.has_method("owner_on") or not ai.owner_on() or ai.xw == null:
		return false
	var T := float(Defs.TILE)
	# the walled hall the threat is at
	var best: Dictionary = {}
	var bd := INF
	for id in ai.xw.plans:
		var p: Dictionary = ai.xw.plans[id]
		if not p.get("ok", false):
			continue
		var h = p.get("hall")
		if h == null or not is_instance_valid(h) or (h as Building).dead:
			continue
		if ai.xw.closed_share(p) < WALL_CLOSED:
			continue
		for c in p["exposed"]:
			var cp: Vector2 = game.cell_center(c)
			for sp in spots:
				var d: float = cp.distance_to(sp)
				if d < bd:
					bd = d
					best = p
	if best.is_empty() or bd > WALL_NEAR * T:
		return false
	if _wall_mode and edge_live() and _wall_hall == best["hall"] and game.clock - _wall_t < EDGE_EVERY:
		_edge_until = game.clock + EDGE_KEEP
		return true
	_wall_t = game.clock
	# the claws at it (or the threat spots)
	var claws: Array = []
	for sp in spots:
		for o in game.units_near(sp, 330.0):
			if game.hostile(o.team, ai.team) and not o.dead and not o.off_field and ai._armed(o) and ai._sighted(o) and not o.is_air():
				if not claws.has(o.position):
					claws.append(o.position)
	if claws.is_empty():
		claws = spots.duplicate()
	# the stretch of wall nearest them
	var front: Array = []
	for c in best["exposed"]:
		var cp: Vector2 = game.cell_center(c)
		var dmin := INF
		for q in claws:
			dmin = minf(dmin, cp.distance_to(q))
		if dmin <= WALL_FRONT * T:
			front.append(cp)
	if front.is_empty():
		return false
	var inside: Dictionary = best["inside"]
	var hall: Building = best["hall"]
	var lvl: int = game.level_of(hall.center())
	var cands_m: Array = []
	var cands_g: Array = []
	for c in inside:
		var i: int = game.idx(c)
		var v := int(game.solid[i])
		if (v != 0 and v != 5) or game.ramp[i] != 0:
			continue
		var p: Vector2 = game.cell_center(c)
		if game.level_of(p) != lvl:
			continue
		var dw := INF
		for f in front:
			dw = minf(dw, p.distance_to(f))
		var dc := INF
		for q in claws:
			dc = minf(dc, p.distance_to(q))
		if dw >= WALL_IN.x * T and dw <= WALL_IN.y * T:
			cands_m.append([dc + dw * 0.5, p])
		elif dw >= WALL_GUN_IN.x * T and dw <= WALL_GUN_IN.y * T:
			cands_g.append([dc, p])
	var srt := func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and (a[1] as Vector2).x < (b[1] as Vector2).x)
	cands_m.sort_custom(srt)
	cands_g.sort_custom(srt)
	var n_gun := 0
	var n_musk := 0
	for u in home:
		if u.kind in GUN_KINDS:
			n_gun += 1
		elif u.kind in HOLD_KINDS:
			n_musk += 1
	var muskets: Array = []
	var guns: Array = []
	for e in cands_g:
		if guns.size() >= n_gun:
			break
		var p: Vector2 = e[1]
		if guns.all(func(q: Vector2) -> bool: return q.distance_to(p) >= EDGE_GUN_GAP * T):
			guns.append(p)
	for e in cands_m:
		if muskets.size() >= maxi(n_musk, 1):
			break
		var p: Vector2 = e[1]
		if muskets.all(func(q: Vector2) -> bool: return q.distance_to(p) >= EDGE_GAP * T):
			muskets.append(p)
	if muskets.size() < mini(EDGE_MIN, maxi(1, n_musk)):
		return false
	# the piece to mend: the most hurt of the stretch's wall, gate or slot building
	var mend: Building = null
	for b in game.buildings:
		if b.team != ai.team or b.dead or b.hp >= b.max_hp - 1.0:
			continue
		var bc: Vector2 = b.center()
		if front.any(func(f: Vector2) -> bool: return f.distance_to(bc) < 2.0 * T):
			if mend == null or b.hp / b.max_hp < mend.hp / mend.max_hp:
				mend = b
	var aim := Vector2.ZERO
	for q in claws:
		aim += q
	aim /= float(claws.size())
	var moved: bool = not wall_live() or _wall_hall != hall or (not _edge_spots.is_empty() and (_edge_spots[0] as Vector2).distance_to(muskets[0]) > 3.0 * T)
	_wall_mode = true
	_wall_hall = hall
	_edge_spots = muskets
	_edge_guns = guns
	_edge_b = mend
	_edge_aim = aim
	_edge_until = game.clock + EDGE_KEEP
	_edge_foot = hall.center()       # (a mender runs back into the base, behind the line)
	if moved:
		wall_moves += 1
		var txt := "moves its army inside the wall of its new hall where it is attacked: %d musket spots %d-%d tiles behind the palisade, %d guns behind them" % [muskets.size(), int(WALL_IN.x), int(WALL_IN.y), guns.size()]
		wall_log.append([game.clock, txt])
		_say(txt)
	return true


# ============================================================ 7. THE GATE POST (crown-hold, 0.33.1, docs/crown_hold.md)
# The owner (2026-11-06, Dune Sea, Hard Crown Economy v Hard Brood Economy, lost at 8:37 to the Brood at its walled
# natural): "if Crown had forces on the palisade probably the brood attack would be holdable". Once the Crown has a WALLED
# NATURAL (an expansion whose wall plan, AIExpandWall, is closed at least GATE_CLOSED and whose gate stands), the army's
# HOME post is DOWN at that palisade: the muskets in rows GATE_IN tiles inside the stretch of wall either side of the gate
# (a lane kept open behind the gate itself, so the army files in and out), the guns GATE_GUN_IN behind them, on HOLD,
# facing out. The ramp post (1) is for the main alone, before there is a walled natural; the cliff edge (5) for a building
# under the cliff without a wall; an attack elsewhere on the palisade moves the line along it (_wall_plan).
# Study switch: `-- gatepost:off`.
const GATE_CLOSED := 0.5        # share of the natural's ways-in cells closed before the army moves down to it (ai-followups: 0.7 -> 0.5,
                                # against the Clockwork the wall seldom reached 0.7 before its first push and the line waited
                                # on the main's high ground; the owner: "it wasn't at the palisade to greet the enemy with fire")
const GATE_EVERY := 20.0        # (s) the gate post planned again this often (buildings and walls change)
const GATE_IN := Vector2(1.2, 3.8)      # (tiles) the musket rows this far inside the wall's pieces
const GATE_GUN_IN := Vector2(3.8, 7.0)  # (tiles) the guns
const GATE_FRONT := 8.0         # (tiles) the stretch of wall stood behind: pieces this near the gate
const GATE_LANE := 1.2          # (tiles) half the lane kept open behind the gate
const GATE_BACK := 7.5          # (tiles) the rally (riders, the rest) this far inside from the gate
var gate_on := not OS.get_cmdline_user_args().has("gatepost:off")
var _gate_t := -99.0
var _gate_hall: Building = null
var _gate_spots: Array = []
var _gate_guns: Array = []
var _gate_face := Vector2.ZERO
var _gate_at := Vector2.INF     # (px) the gate's middle
var _gate_back := Vector2.INF   # (px) inside, behind the line: the rally and the labourers' refuge
var gate_posts := 0             # (tests, the study) times the post was set up at a natural's gate
var gate_log: Array = []        # [clock, text]


## (crown-v-brood-coach) an enemy inside the walled natural is met when the army at home is worth this times it
const INSIDE_BEAT := 1.0
var _inside_said := -99.0


## A threat spot inside the walled natural the army stands at: nearer its hall than the gate is (and on its side).
func _inside_natural(spots: Array) -> bool:
	if _gate_hall == null or not is_instance_valid(_gate_hall) or _gate_at == Vector2.INF:
		return false
	var hc: Vector2 = _gate_hall.center()
	var r: float = hc.distance_to(_gate_at) - float(Defs.TILE)
	for sp in spots:
		if (sp as Vector2).distance_to(hc) < r:
			return true
	return false


func gate_live() -> bool:
	return gate_on and active() and not _gate_spots.is_empty() and _gate_hall != null and is_instance_valid(_gate_hall) \
			and not _gate_hall.dead


## The walled natural the army stands at: the plan of our nearest hall to the main (not the main) whose wall is closed
## GATE_CLOSED and whose gate stands; {} if none.
func _gate_plan_pick() -> Dictionary:
	if ai.xw == null or game.starts.size() <= ai.team:
		return {}
	var home := (Vector2(game.starts[ai.team]) + Vector2(2.5, 2.0)) * float(Defs.TILE)
	var best: Dictionary = {}
	var bd := INF
	for id in ai.xw.plans:
		var p: Dictionary = ai.xw.plans[id]
		if not p.get("ok", false) or (p["exposed"] as Array).is_empty():
			continue
		var h = p.get("hall")
		if h == null or not is_instance_valid(h) or (h as Building).dead or not (h as Building).built:
			continue
		if ai.xw.closed_share(p) < GATE_CLOSED:
			continue
		var gate_up := false
		for e in p["pieces"]:
			if e[0] == "gate":
				var gb: Building = game._own_gate_at(ai.team, e[1])
				if gb != null and gb.built:
					gate_up = true
		if not gate_up:
			continue
		var d: float = (h as Building).center().distance_to(home)
		if d < bd:
			bd = d
			best = p
	return best


## Works out the gate post for `n_musk` muskets and `n_gun` guns (every GATE_EVERY s, or when the walled natural changes).
func _gate_plan(n_musk: int, n_gun: int) -> void:
	if not gate_on:
		return
	if game.clock - _gate_t < (3.0 if _gate_spots.size() < clampi(n_musk, 6, 30) else GATE_EVERY):
		return
	_gate_t = game.clock
	var p := _gate_plan_pick()
	if p.is_empty():
		if not _gate_spots.is_empty():
			_gate_spots.clear()
			_gate_guns.clear()
		return
	var T := float(Defs.TILE)
	var gates: Array = []
	for e in p["pieces"]:
		if e[0] == "gate":
			gates.append(e[1])
	var gp := Vector2.ZERO
	for c in gates:
		gp += game.cell_center(c)
	gp /= float(gates.size())
	var inside: Dictionary = p["inside"]
	var hall: Building = p["hall"]
	var lvl: int = game.level_of(gp)
	# inward: toward the inside cells near the gate
	var inw := Vector2.ZERO
	var nin := 0
	for c in inside:
		var q: Vector2 = game.cell_center(c)
		if q.distance_to(gp) < 4.5 * T:
			inw += q
			nin += 1
	var in_dir: Vector2 = (inw / float(nin) - gp).normalized() if nin > 0 else (hall.center() - gp).normalized()
	if in_dir == Vector2.ZERO:
		in_dir = (hall.center() - gp).normalized()
	# the stretch of wall either side of the gate
	var front: Array = []
	for c in p["exposed"]:
		var cp: Vector2 = game.cell_center(c)
		if cp.distance_to(gp) <= GATE_FRONT * T:
			front.append(cp)
	var keep := {}          # (the wall's empty building slots and our sites waiting: never a post on them)
	for c in ai.xw.reserved():
		keep[c] = true
	var lane_end: Vector2 = gp + in_dir * GATE_BACK * T
	var cands_m: Array = []
	var cands_g: Array = []
	for c in inside:
		var i: int = game.idx(c)
		var v := int(game.solid[i])
		if (v != 0 and v != 5) or game.ramp[i] != 0 or game.cliff[i] != 0 or keep.has(c) or game.side_ghost_at(ai.team, c) != null:
			continue
		var q: Vector2 = game.cell_center(c)
		if game.level_of(q) != lvl:
			continue
		if Geometry2D.get_closest_point_to_segment(q, gp, lane_end).distance_to(q) < GATE_LANE * T:
			continue        # (the lane behind the gate: the army files in and out)
		var dw := INF
		for f in front:
			dw = minf(dw, q.distance_to(f))
		var dg: float = q.distance_to(gp)
		if dw >= GATE_IN.x * T and dw <= GATE_IN.y * T:
			cands_m.append([dg + dw * 0.4, q])
		elif dw >= GATE_GUN_IN.x * T and dw <= GATE_GUN_IN.y * T:
			cands_g.append([dg, q])
	var srt := func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and ((a[1] as Vector2).x < (b[1] as Vector2).x or ((a[1] as Vector2).x == (b[1] as Vector2).x and (a[1] as Vector2).y < (b[1] as Vector2).y)))
	cands_m.sort_custom(srt)
	cands_g.sort_custom(srt)
	var muskets: Array = []
	var guns: Array = []
	for e in cands_g:
		if guns.size() >= maxi(n_gun, 2):
			break
		var q: Vector2 = e[1]
		if guns.all(func(o: Vector2) -> bool: return o.distance_to(q) >= EDGE_GUN_GAP * T):
			guns.append(q)
	for e in cands_m:
		if muskets.size() >= clampi(n_musk, 6, 30):
			break
		var q: Vector2 = e[1]
		if muskets.all(func(o: Vector2) -> bool: return o.distance_to(q) >= EDGE_GAP * T):
			muskets.append(q)
	if muskets.size() < 3:
		_gate_spots.clear()
		_gate_guns.clear()
		return
	var back: Vector2 = lane_end
	if not game.open_cell(game.cell_of(back)):
		back = hall.center() + (gp - hall.center()).normalized() * 3.0 * T
	var moved: bool = _gate_hall != hall or _gate_spots.is_empty() or _gate_at.distance_to(gp) > 2.0 * T
	_gate_hall = hall
	_gate_spots = muskets
	_gate_guns = guns
	_gate_face = -in_dir
	_gate_at = gp
	_gate_back = back
	if moved:
		gate_posts += 1
		var steps: int = int(p.get("gate_ramp", -1))
		var txt := "posts its army at its natural's gate: %d musket spots behind the palisade, %d guns behind them (the gate %s from the foot of its main's ramp)" % [
			muskets.size(), guns.size(), ("%d tiles" % steps) if steps >= 0 else "far"]
		gate_log.append([game.clock, txt])
		_say(txt)


## (AI._army) Where the waiting army's other units (riders, the rest) rally: behind the gate post's line once there is one.
func home_front(fallback: Vector2) -> Vector2:
	return _gate_back if gate_live() and _gate_back != Vector2.INF else fallback


## (crown-v-clockwork-coach) A natural with a wall plan skips the cliff edge once any piece of it stands (ai-followups);
## the gate post comes only at GATE_CLOSED. Between the two the line had no post at all: Kestrel Rise (seed 1131) 6:33-6:59,
## the natural's wall had a few pieces, its hall burned under 11 Clock Soldiers while 8 Musketeers stood idle in the main's
## Farm above (docs/shots/crown-v-clockwork-coach/r4_kestrel_0654_natural_burns_line_idle.jpg). Against the Clockwork the
## cliff edge answers until the wall is closed enough for the gate post.
func _cc_edge_floor() -> float:
	if ai.has_method("cc_vs_clock") and ai.cc_on and ai.cc_vs_clock():
		return GATE_CLOSED - 0.001
	return 0.0
