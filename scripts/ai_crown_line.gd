class_name AICrownLine
extends RefCounted
## THE CROWN'S LINE (crown-line-fight, the owner 2026-11-12 07:59: "Maybe there is one thing the Crown isn't doing: the
## drag-to-draw line of Musketeers. This line of fire and cannon placement could help in fights."; docs/crown_line_fight.md).
## A human Crown player drags a LINE for his Musketeers (Game.line_move) so every musket fires at once, and puts his Field
## Cannons behind it where they shoot over it. The computer attack-moved its wave as a blob to a point: the Musketeers met
## the enemy in a clump or a column and only the front rows fired. Now (the Crown computer, Normal and up, the main army
## only: raids, the Horseman rush, the Dragoon raids and the Balloon harass keep their own play):
##  1. THE LINE: Game.line_orders, the very orders of a player's drag: the shooters (Musketeers, Guardsmen, Dragoons,
##     the dismounted) across the approach facing the enemy, one rank (two from RANK2 shooters), LINE_GAP apart, centred
##     on the enemy's direction; the melee (Horsemen, Officers, Pikemen) on the flanks; nobody in front of the muskets.
##  2. THE GUNS: the Field Cannons GUN_BACK behind the line, spread along it, unlimbered there (round shot 430 px reaches
##     over the line and past it); Mortars MORTAR_BACK behind.
##  3. THE MARCH: an attack whose wave sees an enemy army ahead stops out of its reach (FORM_D from the nearest enemy),
##     forms the line facing it, the guns unlimber behind; then the line steps forward on an attack-move (each man to his
##     spot ADVANCE px on, so they arrive together and stop to fire as one); the guns come up behind it. Contact: it
##     fights where it stands (the held line shoots; a line with nothing left in reach steps on: a winning line pushes on);
##     a line losing the trade falls back toward its guns in order (BACK px) and forms again. After the fight it re-forms.
##     Strung out on the march with nothing ahead, the head waits and the tail closes up (SPREAD_MAX).
##  4. THE DEFENCE: a detachment sent to a force at our buildings (AI._defend) with LINE_MIN shooters or more arrives as a
##     line facing it, DEF_D short of it (inside musket reach), not as a blob on the spot.
## Design: docs/design_principles.md 1 (fair: the computer uses the player's own tool, nothing it could not do by hand),
## 4 (battles that carry the weight of the match: formed lines and guns). No unit or economy number changed.
## Study switch: `-- line:off` (the old blob).

const SHOOT_KINDS := ["musketeer", "musketeer_armoured", "dismounted", "dismounted_armoured", "dragoon"]
const GUN_KINDS := ["cannon", "mortar"]
const LINE_MIN := 4             # shooters: fewer than this, no line
## ONE RANK OR TWO, chosen by testing (tools/study_line_ranks.gd: N Musketeers on HOLD with 2 Field Cannons behind, an
## enemy force walking into them; killed / lost over 3 runs each, the blob = the old way):
##              14 muskets: blob   1 rank  2 ranks    24 muskets: blob   1 rank  2 ranks
##   v Raptors              2.82   5.20    3.80                   2.26   2.98    2.47
##   v Clock Soldiers       7.54   10.89   12.25                  3.67   3.17    6.50
##   v Musketeers           2.06   2.54    2.36                   1.17   0.84    1.21
## A line beats the blob every time but one (a 24-man single rank, 730 px wide, against Clock Soldiers or Musketeers who
## come on in a column: they hit one end of it and the far end cannot reach). So: one rank against the Brood's swarm up
## to RANK2_BROOD (a wide front catches more of it), two ranks from RANK2_CLOCK against the Clockwork, from RANK2 in the
## mirror.
const RANK2 := 16               # shooters: from this many, two ranks (the mirror)
const RANK2_BROOD := 26
const RANK2_CLOCK := 12
const LINE_GAP := 0.95          # (tiles) between men in a rank
const ROW_GAP := 0.9            # (tiles) between the ranks
const FLANK := 1.6              # (tiles) the melee beyond each end of the front rank
const GUN_BACK := 2.6           # (tiles) the Field Cannons behind the front rank
const GUN_GAP := 1.7            # (tiles) between guns
const GUN_MIN_BACK := 1.2       # (tiles) a gun at least this far behind the front rank sets up where it stands
const MORTAR_BACK := 6.0        # (tiles) the Mortars behind the front rank (their least range is 5 tiles)
const SEE_R := 760.0            # (px) an armed enemy this near the wave's body is "ahead"
const SEE_SHARE := 0.25         # ... when worth this share of the wave
const FORM_D := 330.0           # (px) the line forms this far from the nearest enemy (a musket reaches 190)
const CONTACT_R := 250.0        # (px) an armed enemy this near a man of the wave: the fight is on
const FORM_MAX := 12.0          # (s) a line not formed by then goes on anyway
const FORMED := 0.75            # share of the shooters at their spots: formed
const AT_SPOT := 30.0           # (px) a man this near his spot is at it
const ADVANCE := 190.0          # (px) the formed line steps this far on when it knows no enemy's place ...
const ADVANCE_TO := 165.0       # (px) ... else to this far from the nearest enemy known (a musket reaches 190) ...
const ADVANCE_FAR := 480.0      # (px) ... at most this far in one step
const STEP_LEN := 128.0         # (px) a step of the formed line and its guns toward an enemy beyond the guns' reach
const STEP_MAX := 12.0          # (s) the line waits this long at most for its guns at a halt
const SET_MAX := 8.0            # (s) ... and for them to set up once in reach
const GUN_SET := 330.0          # (px) an enemy this near the front rank is in the guns' reach from behind it (430 - the
                                # guns' place behind the line - a margin)
const ADVANCE_MAX := 25.0       # (s) an advance not in contact by then fights where it stands
const STEP := 96.0              # (px) ... a line in a fight with nothing in reach steps this far on
const IDLE_PUSH := 4.0          # (s) a held line with nothing in reach this long steps on
const FORM_COOL := 20.0         # (s) between two formings of the same wave
const PIECE_FORM_R := 1100.0    # (px) a siege's piece this near the body: the line forms before it (with guns in the wave)
const APPROACH_R := 900.0       # (px) the wave halts and forms this far from its target (the enemy's base) ...
const APPROACH_MIN := 520.0     # ... unless it is nearer than this already
const SPREAD_MAX := 5.0         # (tiles) the body's mean distance from its middle that calls a close-up on the march
const DONE_SPREAD := 2.4
const CLOSE_MAX := 14.0
const CLOSE_COOL := 18.0
const BODY_R := 12.0            # (tiles)
const LOSE_RATIO := 1.6         # lost / killed in this fight ...
const LOSE_MIN := 260.0         # ... and lost at least this: the line falls back
const BACK := 150.0             # (px) a falling-back line steps this far toward its guns
const BACK_T := 9.0             # (s) it holds there this long before it fights on
const DEF_D := 150.0            # (px) a defence's line stands this far short of the force it meets

var ai = null                    # the AICrown
var game: Game = null
var on := not OS.get_cmdline_user_args().has("line:off")
var said: Array = []             # [clock, text] (tests, the coach)
var forms := 0                   # (tests) lines formed on the march
var def_lines := 0               # (tests) defence lines
var falls := 0                   # (tests) lines that fell back in order
var steps := 0                   # (tests) steps of a formed line with its guns
var deploys := 0                 # (tests) lines deployed at a contact met unformed

# the wave's line
var st := ""                     # "" (marching), "form", "advance", "fight", "back", "close"
var _t0 := 0.0
var _c := Vector2.INF            # the front rank's middle
var _face := Vector2.ZERO        # toward the enemy
var _spot := {}                  # Unit -> his spot in the line
var _last_form := -99.0
var _close_next := 0.0
var _close_pt := Vector2.INF
var _reach_t := 0.0              # the last clock a held shooter had an enemy in reach
var _trade0 := Vector2.ZERO      # (killed, lost) when the fight began
var line_log: Array = []         # [clock, kind, shooters, across px, guns] (tests)


func _init(owner) -> void:
	ai = owner
	game = owner.game


func active() -> bool:
	return on and ai.difficulty >= 1


func _say(s: String) -> void:
	said.append([snappedf(game.clock, 0.1), s])
	if game.mlog:
		game.mlog.add("%s%s%s" % [game.mlog.who(ai.team), "" if s.begins_with("'s") else " ", s])


## Shooters from which the line stands in two ranks, by the enemy (see RANK2).
func rank2() -> int:
	if ai._foe_is("brood"):
		return RANK2_BROOD
	if ai._foe_is("clockwork"):
		return RANK2_CLOCK
	return RANK2


static func shooter(u: Unit) -> bool:
	return u.kind in SHOOT_KINDS


static func is_gun(u: Unit) -> bool:
	return u.kind in GUN_KINDS


func _ok(u) -> bool:
	return is_instance_valid(u) and not u.dead and not u.off_field and not u.is_air()


func _value(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += float(Game.unit_value(u))
	return v


const KNOWN_T := 20.0            # (s) an enemy soldier seen this long ago still counts where it was seen


## The armed enemies in sight within SEE_R of the body, and those seen there in the last KNOWN_T s (AICrownHold._seen).
func _known(body: Array) -> Array:
	var foes: Array = []
	var got := {}
	for u in body:
		for o in game.units_near(u.position, SEE_R):
			if not got.has(o) and _foe_ok(o):
				got[o] = true
				foes.append(o)
	# (crown-rider-screen: the riders ahead and on the flanks are the wave's eyes too, scripts/ai_crown_screen.gd)
	var eyes: Array = ai.sc.eyes() if ai.get("sc") != null and ai.sc.active() else []
	var bc := Vector2.ZERO
	for u in body:
		bc += u.position
	bc /= maxf(1.0, float(body.size()))
	screen_saw = false
	for e in eyes:
		if body.is_empty() or (e as Vector2).distance_to(bc) > SCREEN_R:
			continue
		for o in game.units_near(e, AICrownScreen.EYE_R):
			if not _foe_ok(o):
				continue
			if not _far.has(o):
				# (seen by a rider and not by the wave's own men: the screen's sighting)
				var own := false
				for u in body:
					if u.position.distance_to(o.position) < float(u.d.get("sight", 8)) * Defs.TILE:
						own = true
						break
				if not own:
					_far[o] = true
					screen_saw = true
			if not got.has(o):
				got[o] = true
				foes.append(o)
	for o in foes:
		_mem[o] = [game.clock, o.position]
	var seen: Dictionary = _mem.duplicate()
	if ai.ch != null:
		for o in ai.ch._seen:
			if not seen.has(o) or float(seen[o][0]) < float(ai.ch._seen[o][0]):
				seen[o] = ai.ch._seen[o]
	for o in seen.keys():
		# (crown-rider-screen: an enemy the screen saw is remembered FAR_T s while the line forms and steps on it: the
		# riders keep out of a musket's reach, which is longer than their sight, so they lose sight of what they found)
		var keep_t: float = FAR_T if _far.has(o) and st in ["form", "step", "set", "advance"] else KNOWN_T
		if not is_instance_valid(o) or o.dead or o.off_field or game.clock - float(seen[o][0]) > keep_t:
			_mem.erase(o)
			continue
		if got.has(o):
			continue
		var p: Vector2 = seen[o][1]
		if _far.has(o) and p.distance_to(bc) < SCREEN_R:
			got[o] = true             # (seen by the screen lately, still on the wave's road)
			foes.append(o)
			continue
		for u in body:
			if p.distance_to(u.position) < SEE_R:
				got[o] = true
				foes.append(o)
				break
	for o in _far.keys():
		if not _mem.has(o):
			_far.erase(o)
	return foes


const SCREEN_R := 1300.0         # (px) (crown-rider-screen) an enemy the screen saw this near the body is "ahead"
const SCREEN_SHARE := 0.08       # ... and the line forms before it when it is worth this share of the wave ...
const SCREEN_MIN := 100.0        # ... and this much at least
const FAR_T := 45.0              # (s) ... and remembered this long while the line forms and steps on it
var lost_sight := 0              # (the coach) formings given up: the enemy forgotten
var _far := {}                   # enemy soldier -> true: seen by the screen's riders (scripts/ai_crown_screen.gd)
var screen_saw := false          # (the coach) the screen's riders saw an enemy this think


var _mem := {}                   # enemy soldier -> [clock, position] last seen by the wave


## Where we know an enemy is: where it stands when in sight, else where it was last seen.
func _pos(o: Unit) -> Vector2:
	if game.is_visible_to(ai.team, o.position):
		return o.position
	var a: Array = _mem.get(o, [-99.0, o.position])
	if ai.ch != null and ai.ch._seen.has(o) and float(ai.ch._seen[o][0]) > float(a[0]):
		return ai.ch._seen[o][1]
	return a[1]


func _foe_ok(o: Unit) -> bool:
	return not o.dead and not o.off_field and game.hostile(o.team, ai.team) and not o.is_worker() and o.has_attack() \
			and game.is_visible_to(ai.team, o.position)


# ============================================================ 1-2. the line and its guns

## Lays the line: the front rank's middle `c`, facing `face`; `units` the men and guns to place. attack: the shooters go on
## an attack-move (they stop to fire at what comes in reach). Returns the number of shooters placed.
func lay(units: Array, c: Vector2, face: Vector2, attack: bool, least := LINE_MIN) -> int:
	var shooters: Array = units.filter(func(u) -> bool: return _ok(u) and shooter(u))
	var guns: Array = units.filter(func(u) -> bool: return _ok(u) and is_gun(u))
	var melee: Array = units.filter(func(u) -> bool: return _ok(u) and not shooter(u) and not is_gun(u))
	_spot.clear()
	if shooters.size() < least:
		return 0
	var T := float(Defs.TILE)
	face = face.normalized()
	var perp := Vector2(-face.y, face.x)
	var ranks := 2 if shooters.size() >= rank2() else 1
	var per: int = int(ceil(float(shooters.size()) / ranks))
	var half: float = per * LINE_GAP * T * 0.5
	# the front rank: the men nearest the enemy (they are there first)
	shooters.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.dot(face) > b.position.dot(face))
	var lvl: int = game.level_of(c)
	for r in ranks:
		var mid: Vector2 = c - face * (ROW_GAP * T * r)
		var row: Array = shooters.slice(r * per, mini((r + 1) * per, shooters.size()))
		if row.is_empty():
			continue
		var h2: float = half * float(row.size()) / float(per)
		var pts := PackedVector2Array([mid - perp * h2, mid + perp * h2])
		var got: Dictionary = game.line_orders(row, pts, attack)
		for u in got:
			_spot[u] = got[u]
	# the melee on the flanks, half each side, a little behind the front rank
	for i in melee.size():
		var u: Unit = melee[i]
		var side := 1.0 if i % 2 == 0 else -1.0
		var k: int = i / 2
		var p: Vector2 = c + perp * side * (half + (FLANK + 0.9 * k) * T) - face * (0.6 * T)
		p = _same_level(p, lvl, c)
		_spot[u] = p
		if attack:
			u.cmd_move(p, true)
		else:
			u.cmd_move(p)
	# the guns behind the line, spread along it
	var cannons: Array = guns.filter(func(u: Unit) -> bool: return u.kind == "cannon")
	var mortars: Array = guns.filter(func(u: Unit) -> bool: return u.kind == "mortar")
	_place_guns(cannons, c - face * (GUN_BACK * T), perp, half, lvl, c, attack)
	_place_guns(mortars, c - face * (MORTAR_BACK * T), perp, half, lvl, c, attack)
	line_log.append([snappedf(game.clock, 0.1), st, shooters.size(), int(half * 2.0), guns.size()])
	return shooters.size()


func _place_guns(guns: Array, mid: Vector2, perp: Vector2, half: float, lvl: int, c: Vector2, attack: bool) -> void:
	if guns.is_empty():
		return
	var T := float(Defs.TILE)
	var span: float = minf(half * 0.8, (guns.size() - 1) * GUN_GAP * T * 0.5)
	guns.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.dot(perp) < b.position.dot(perp))
	for i in guns.size():
		var f: float = 0.0 if guns.size() == 1 else -1.0 + 2.0 * float(i) / float(guns.size() - 1)
		var p: Vector2 = _same_level(mid + perp * span * f, lvl, c)
		_spot[guns[i]] = p
		var u: Unit = guns[i]
		if u.position.distance_to(p) < AT_SPOT and u.tesla_mode != "packed":
			continue          # (set up at its spot already)
		if attack:
			u.cmd_move(p, true)
		else:
			u.cmd_move(p)


## p moved toward `back` until it is open ground on level `lvl` (a line's flank or gun spot over a cliff's rim).
func _same_level(p: Vector2, lvl: int, back: Vector2) -> Vector2:
	for k in 9:
		var q: Vector2 = p.lerp(back, k / 8.0)
		var c: Vector2i = game.cell_of(q)
		if game.in_map(c) and game.open_cell(c) and game.level_of(q) == lvl:
			return q
	return back


## Men at their spots stand on HOLD facing the enemy; guns there set up. Returns the share of the shooters at their spots.
func settle(face: Vector2, deploy := true) -> float:
	var n := 0
	var at := 0
	for u in _spot.keys():
		if not _ok(u):
			_spot.erase(u)
			continue
		var sp: Vector2 = _spot[u]
		var there: bool = u.position.distance_to(sp) < AT_SPOT
		if shooter(u):
			n += 1
			if there:
				at += 1
		if not there:
			if u.order == "idle" and u.target == null:
				u.cmd_move(sp)          # (stopped short: on to his spot)
			continue
		if is_gun(u):
			if deploy and u.order == "idle" and u.tesla_mode == "packed":
				u.cmd_deploy()
		elif u.order != "hold" and (u.target == null or u.order in ["move", "idle"]):
			u.cmd_hold()
			if face != Vector2.ZERO:
				u.facing = face
	return float(at) / float(maxi(1, n))


# ============================================================ 3. the march

## Called every army think while the wave is out (AI._army through AICrown._cohesion): true = the line has its men in hand
## this think (the shared loop sends nobody).
func march(wave: Array, target: Vector2) -> bool:
	if not active():
		return false
	var ground: Array = wave.filter(func(u) -> bool: return _ok(u))
	if ground.filter(func(u: Unit) -> bool: return shooter(u)).size() < LINE_MIN:
		return _reset(ground, target, "")
	var pc = ai._siege.get("piece")
	var body := _body(ground)
	var bc := Vector2.ZERO
	for u in body:
		bc += u.position
	bc /= maxi(1, body.size())
	if pc != null and is_instance_valid(pc) and not pc.dead and st == "" and _formed_for != pc and _has_guns(ground) \
			and bc.distance_to(pc.center()) < PIECE_FORM_R and bc.distance_to(pc.center()) > 520.0:
		_formed_for = pc
		return _form_piece(ground, bc, pc)
	if pc != null and is_instance_valid(pc) and not pc.dead and bc.distance_to(pc.center()) < 560.0 \
			and not (st in ["form", "step", "set"] and not _guns_set()):
		return _reset(ground, target, "")       # (at the wall: the siege's own order, once the line's guns are set up)
	# the enemy army ahead (in sight now, or seen in the last KNOWN_T s where it was seen: the scouts' and the army's own
	# eyes, AICrownHold._seen), and the nearest of it; contact only with what is in sight
	var foes := _known(body)
	var contact := false
	var nearest := INF
	var near_o: Unit = null
	for o in foes:
		for u in ground:
			var d: float = _pos(o).distance_to(u.position)
			if d < nearest:
				nearest = d
				near_o = o
			if d < CONTACT_R and not u.is_mounted() and game.is_visible_to(ai.team, o.position):
				contact = true          # (riders skirmishing out ahead are not the line's fight)
	var mine := _value(ground)
	var ahead := _value(foes)
	match st:
		"form", "step", "set":
			return _forming(ground, target, contact, foes)
		"advance":
			if contact:
				return _fight_begin(ground)
			if _all_still(ground) and game.clock - _t0 > 3.0:
				if foes.is_empty():
					return _reset(ground, target, "")
				return _fight_begin(ground)
			if game.clock - _t0 > ADVANCE_MAX:
				return _fight_begin(ground)
			return true
		"fight":
			return _fight(ground, target, foes, contact)
		"back":
			if game.clock - _t0 >= BACK_T or (contact and nearest < 120.0):
				st = "fight"
				_reach_t = game.clock
				return _fight(ground, target, foes, contact)
			settle(_face)
			return true
	if contact:
		return _fight_begin(ground)
	# (crown-rider-screen, coached Dune Sea 1109 9:47-10:06: the screen saw 2-3 Musketeers at the enemy's ramp gate, worth
	# under a quarter of the wave, the line did not form, and the wave walked into the ramp post's whole line unformed: 600
	# lost for 0. What the screen sees counts from SCREEN_SHARE: a few seen up ahead are often the front of more)
	var share := SEE_SHARE
	if foes.any(func(o) -> bool: return _far.has(o)) and ahead >= SCREEN_MIN:
		share = SCREEN_SHARE
	if not foes.is_empty() and ahead >= mine * share and game.clock - _last_form >= FORM_COOL:
		return _form(ground, bc, near_o, foes)
	if st in ["", "close"] and foes.is_empty() and target != Vector2.INF and game.clock - _last_form >= FORM_COOL \
			and (_approach_for == Vector2.INF or _approach_for.distance_to(target) > 300.0) \
			and bc.distance_to(target) < APPROACH_R and bc.distance_to(target) > APPROACH_MIN:
		_approach_for = target
		return _form_approach(ground, bc, target)
	if st == "close":
		var spread := _spread(body, bc)
		if spread <= DONE_SPREAD or game.clock - _t0 > CLOSE_MAX:
			_say("'s wave goes on together (%.1f tiles apart)" % spread)
			return _reset(ground, target, "")
		_close_orders(ground, target)
		return true
	if game.clock >= _close_next and body.size() >= 4:
		var spread2 := _spread(body, bc)
		if spread2 > SPREAD_MAX:
			st = "close"
			_t0 = game.clock
			_close_pt = _head(body, target)
			_say("'s wave strung out on the march: %d men %.1f tiles apart close up before going on" % [body.size(), spread2])
			_close_orders(ground, target)
			return true
	return false


func _form(ground: Array, bc: Vector2, near_o: Unit, foes: Array) -> bool:
	var fc := Vector2.ZERO
	var w := 0.0
	for o in foes:
		var k: float = float(Game.unit_value(o))
		fc += _pos(o) * k
		w += k
	fc = fc / w if w > 0.0 else _pos(near_o)
	_face = (fc - bc).normalized()
	if _face == Vector2.ZERO:
		_face = Vector2.RIGHT
	# the front rank's middle: FORM_D short of the nearest enemy along the line to the enemy's middle, never ahead of where
	# the body's head stands now (it waits there for the rest)
	var nd: float = (_pos(near_o) - bc).dot(_face)
	var fwd: float = clampf(nd - FORM_D, 0.0, 260.0)
	var c: Vector2 = bc + _face * fwd
	var lvl: int = game.level_of(bc)
	c = _same_level(c, lvl, bc)
	_c = c
	st = "form"
	_t0 = game.clock
	_last_form = game.clock
	var n := lay(ground, c, _face, false)
	if n == 0:
		st = ""
		return false
	forms += 1
	var guns: int = ground.filter(func(u: Unit) -> bool: return is_gun(u)).size()
	var by_screen := foes.any(func(o) -> bool: return _far.has(o))
	if by_screen and ai.get("sc") != null:
		ai.sc.sightings += 1
	_say("'s wave forms its line before the enemy army ahead (%d): %d muskets in %d rank%s, %d gun%s behind%s" % [
		int(_value(foes)), n, 2 if n >= rank2() else 1, "s" if n >= rank2() else "", guns, "" if guns == 1 else "s",
		" (its screen saw it %d px off)" % int(nd) if by_screen else ""])
	return true


## A siege ahead (a wall or gate the wave must break, AI._siege_plan): coached, Greenhold 1103 8:05-8:16 (the mirror): the
## wave walked on to the enemy's ramp gate with its guns 30 tiles behind and pulled back from it "too dear" one volley in.
## Now with guns in the wave it forms its line facing the piece FORM_D short of it (or of the enemy soldiers known by it),
## steps up with its guns until they reach the piece, holds while they set up, and only then hands over to the siege.
func _form_piece(ground: Array, bc: Vector2, pc: Building) -> bool:
	var near: Vector2 = pc.center()
	var nd0: float = bc.distance_to(near)
	for o in _known(ground):
		var p: Vector2 = _pos(o)
		if p.distance_to(pc.center()) < 420.0 and p.distance_to(bc) < nd0:
			nd0 = p.distance_to(bc)
			near = p
	_face = (pc.center() - bc).normalized()
	if _face == Vector2.ZERO:
		return false
	_piece_pt = near
	var nd: float = (near - bc).dot(_face)
	var c: Vector2 = _same_level(bc + _face * clampf(nd - FORM_D - 60.0, 0.0, 260.0), game.level_of(bc), bc)
	_c = c
	st = "form"
	_t0 = game.clock
	_last_form = game.clock
	var n := lay(ground, c, _face, false)
	if n == 0:
		st = ""
		_piece_pt = Vector2.INF
		return false
	forms += 1
	var guns: int = ground.filter(func(u: Unit) -> bool: return is_gun(u)).size()
	_say("'s wave forms its line before the enemy's %s: %d muskets in %d rank%s, %d gun%s behind to break it" % [
		pc.d.get("name", pc.kind).to_lower() if pc.d.has("name") else pc.kind, n, 2 if n >= rank2() else 1, "s" if n >= rank2() else "", guns, "" if guns == 1 else "s"])
	return true


## THE HALT BEFORE THE ENEMY'S BASE (the owner's ask: "gather out of the enemy's reach, form the line facing the target,
## then advance in line"): measured in the first 10 games of the after batch, 24 of 28 contacts were met unformed (a musket
## sees 8 tiles, its reach is 6: the enemy is first seen at contact) and deployed under fire; most of them at the enemy's
## natural or main. Now a wave that knows of no enemy ahead halts APPROACH_R from its target (the enemy's base), forms its
## line facing it with the guns behind, and walks on in line with its guns (the steps, the guns set up once the target is
## in their reach), then on alone to musket reach. Once a target (again after a won fight).
func _form_approach(ground: Array, bc: Vector2, target: Vector2) -> bool:
	_face = (target - bc).normalized()
	if _face == Vector2.ZERO:
		return false
	_piece_pt = target
	_c = bc
	st = "form"
	_t0 = game.clock
	_last_form = game.clock
	var n := lay(ground, _c, _face, false)
	if n == 0:
		st = ""
		_piece_pt = Vector2.INF
		return false
	forms += 1
	approaches += 1
	var guns: int = ground.filter(func(u: Unit) -> bool: return is_gun(u)).size()
	_say("'s wave halts out of reach of the enemy's base and forms its line: %d muskets in %d rank%s, %d gun%s behind" % [
		n, 2 if n >= rank2() else 1, "s" if n >= rank2() else "", guns, "" if guns == 1 else "s"])
	return true


var _approach_for := Vector2.INF   # the target the wave last halted before
var approaches := 0                # (tests) halts before the enemy's base


func _has_guns(ground: Array) -> bool:
	return ground.any(func(u: Unit) -> bool: return is_gun(u))


var _formed_for = null           # the siege piece the line last formed before
var _piece_pt := Vector2.INF     # the point the line steps toward (a siege's piece or the enemy by it)


func _forming(ground: Array, target: Vector2, contact: bool, foes: Array) -> bool:
	var reach := _guns_reach(foes)
	if reach and st == "step":
		_guns_down(foes)                         # (the enemy came into the guns' reach mid-step: they set up behind the line now)
	var share := settle(_face, st == "form" or reach)
	if contact:
		return _fight_begin(ground)         # (they came to us: the line shoots where it stands)
	if foes.is_empty() and game.clock - _t0 > 4.0:
		if _piece_pt == Vector2.INF:
			lost_sight += 1
			return _reset(ground, target, "'s line has lost sight of the enemy it formed for: it marches on")
		return _reset(ground, target, "")
	if st == "set":
		if _guns_set() or game.clock - _t0 > SET_MAX:
			_step(foes)
		return true
	var guns_up := _guns_at_spots()
	if (share >= FORMED and (st == "form" or guns_up)) or game.clock - _t0 > (FORM_MAX if st == "form" else STEP_MAX):
		_step(foes)
	return true


## The formed line goes on: while the nearest enemy known is beyond the guns' reach from behind the line, a STEP_LEN step
## of everyone, guns too (packed, they keep up: the line waits for them at each halt); once in their reach the guns set up
## where they are and the line walks on alone to just inside musket reach (an attack-move: they stop to fire as one).
func _step(foes: Array) -> void:
	var nd := INF
	for o in foes:
		nd = minf(nd, (_pos(o) - _c).dot(_face))
	if _piece_pt != Vector2.INF:
		nd = minf(nd, (_piece_pt - _c).dot(_face))
	var on_spots: Array = _spot.keys().filter(func(u) -> bool: return _ok(u))
	var guns: Array = on_spots.filter(func(u: Unit) -> bool: return is_gun(u))
	var men: Array = on_spots.filter(func(u: Unit) -> bool: return not is_gun(u))
	if nd < INF and nd > GUN_SET + 20.0 and not guns.is_empty():
		var step: float = minf(STEP_LEN, nd - GUN_SET)
		for u in men:
			_spot[u] += _face * step
			u.cmd_move(_spot[u], true)
		for u in guns:
			_spot[u] += _face * step
			u.cmd_move(_spot[u])
		_c += _face * step
		st = "step"
		steps += 1
		_t0 = game.clock
		return
	if not guns.is_empty() and st != "set" and not _guns_set():
		# (in the guns' reach: they set up behind the line first, the line holds; then it walks on alone)
		_guns_down(foes)
		st = "set"
		_t0 = game.clock
		return
	var adv := ADVANCE
	if nd < INF:
		adv = clampf(nd - ADVANCE_TO, 0.0, ADVANCE_FAR)
	for u in men:
		_spot[u] += _face * adv
		u.cmd_move(_spot[u], true)
	st = "advance"
	_t0 = game.clock
	_c += _face * adv


## The fight is on (or the enemy in the guns' reach) while the guns roll with the line: a gun behind the front rank sets up
## where it stands; one level with it or ahead goes back behind it first.
func _guns_down(foes: Array = []) -> void:
	if _face == Vector2.ZERO or _c == Vector2.INF:
		return
	var T := float(Defs.TILE)
	var perp := Vector2(-_face.y, _face.x)
	for u in _spot.keys():
		if not _ok(u) or not is_gun(u) or u.tesla_mode != "packed":
			continue
		var back: float = (u.position - _c).dot(_face)
		# (coached, Greenhold 1101 7:11-7:19: three guns set up at the ramp's top 400-590 px behind the line, out of reach
		# of the Clock Soldiers the line fought: one behind the line sets up where it stands only if the enemy is in reach)
		var reach := false
		for o in foes:
			if _pos(o).distance_to(u.position) < float(u.d.get("range", 430)) - 30.0:
				reach = true
				break
		if back < -GUN_MIN_BACK * T and (reach or foes.is_empty()):
			_spot[u] = u.position
			u.cmd_deploy()
		else:
			var side: float = clampf((u.position - _c).dot(perp), -3.0 * T, 3.0 * T)
			var p: Vector2 = _same_level(_c - _face * (GUN_BACK * T) + perp * side, game.level_of(_c), _c)
			_spot[u] = p
			u.cmd_move(p)


## Every gun of the line set up (or none): coached, Greenhold 1103 8:08-8:21 (the mirror): the line formed in the open, walked
## on to the enemy's ramp gate and the siege took it there without its two guns, still rolling 900 px behind; it lost 540
## for 120 at the gate and pulled back. A siege now waits for the line's guns to set up in reach of the gate.
func _guns_set() -> bool:
	for u in _spot:
		if _ok(u) and is_gun(u) and u.tesla_mode != "deployed":
			return false
	return true


## The guns at their spots (or none).
func _guns_at_spots() -> bool:
	for u in _spot:
		if _ok(u) and is_gun(u) and u.position.distance_to(_spot[u]) > AT_SPOT + 14.0:
			return false
	return true


## The nearest enemy known is in the guns' reach from their place behind the line: they set up.
func _guns_reach(foes: Array) -> bool:
	if _piece_pt != Vector2.INF and (_piece_pt - _c).dot(_face) <= GUN_SET + 20.0:
		return true
	for o in foes:
		if (_pos(o) - _c).dot(_face) <= GUN_SET + 20.0:
			return true
	return false


func _fight_begin(ground: Array) -> bool:
	var unprepared := st in ["", "close"]
	if unprepared:
		_deploy(ground)
	else:
		_guns_down(_known(ground))
	st = "fight"
	_t0 = game.clock
	_reach_t = game.clock
	_trade0 = Vector2(float(game.stats[ai.team]["value_killed"]), float(ai._lost_value()))
	# the men still walking to the line stop where they are and fire (an attack-move in place); the held line holds
	# (the men at the line hold it: they shoot what comes in reach and do not walk on into the enemy one by one)
	for u in ground:
		if not shooter(u):
			continue
		if u.order == "move":
			u.cmd_move(u.position, true)
		elif u.order == "idle":
			u.cmd_hold()
			if _face != Vector2.ZERO:
				u.facing = _face
	return false


## Contact without a line formed (an enemy met at a turn of the road, out of a ramp's foot): the shooters already firing
## stay where they are; the rest deploy into a line through them, across the enemy's direction (an attack-move: they stop to
## fire as they come in reach), the melee on the flanks, the guns behind.
func _deploy(ground: Array) -> void:
	var shooters: Array = ground.filter(func(u: Unit) -> bool: return shooter(u))
	var fc := Vector2.ZERO
	var nf := 0
	for u in shooters:
		for o in game.units_near(u.position, 420.0):
			if _foe_ok(o):
				fc += o.position
				nf += 1
	if nf == 0 or shooters.size() < LINE_MIN:
		return
	fc /= nf
	var front: Unit = shooters[0]
	for u in shooters:
		if u.position.distance_to(fc) < front.position.distance_to(fc):
			front = u
	_face = (fc - front.position).normalized()
	if _face == Vector2.ZERO:
		return
	var busy := func(u: Unit) -> bool: return shooter(u) and u.target != null and is_instance_valid(u.target) \
			and u.target.position.distance_to(u.position) < float(u.d.get("range", 190)) + 20.0
	var free: Array = ground.filter(func(u: Unit) -> bool: return not busy.call(u))
	_c = _same_level(front.position - _face * 24.0, game.level_of(front.position), front.position)
	if free.filter(func(u: Unit) -> bool: return shooter(u)).size() < 2:
		return
	var n := lay(free, _c, _face, true, LINE_MIN - 2)
	if n > 0:
		deploys += 1
		_say("'s wave meets the enemy before its line is formed: %d muskets deploy into a line through the %d already firing" % [n, shooters.size() - n])


func _fight(ground: Array, target: Vector2, foes: Array, contact: bool) -> bool:
	settle(_face)
	if foes.is_empty():
		_say("'s line has won the field: it forms up again and goes on")
		_approach_for = Vector2.INF          # (it halts and forms again before the base)
		return _reset(ground, target, "")
	# losing the trade: back toward the guns in order, form again
	var killed: float = float(game.stats[ai.team]["value_killed"]) - _trade0.x
	var lost: float = float(ai._lost_value()) - _trade0.y
	if lost >= LOSE_MIN and lost > killed * LOSE_RATIO and _face != Vector2.ZERO:
		var bc := Vector2.ZERO
		var sh: Array = ground.filter(func(u: Unit) -> bool: return shooter(u))
		if sh.size() >= LINE_MIN:
			for u in sh:
				bc += u.position
			bc /= sh.size()
			var c: Vector2 = _same_level(bc - _face * BACK, game.level_of(bc), bc)
			st = "back"
			_t0 = game.clock
			_c = c
			_trade0 = Vector2(float(game.stats[ai.team]["value_killed"]), float(ai._lost_value()))
			lay(ground.filter(func(u: Unit) -> bool: return not is_gun(u)), c, _face, false)
			falls += 1
			_say("'s line is losing the fight (%d lost for %d): it falls back toward its guns in order and forms again" % [int(lost), int(killed)])
			return true
	# the held line: something in reach keeps it; nothing for IDLE_PUSH s, it steps on toward the enemy (pushes on)
	var held: Array = ground.filter(func(u: Unit) -> bool: return shooter(u) and u.order == "hold")
	var any_reach := false
	for u in held:
		var r: float = float(u.d.get("range", 190)) + 10.0
		for o in foes:
			if _pos(o).distance_to(u.position) < r:
				any_reach = true
				break
		if any_reach:
			break
	if any_reach or held.is_empty():
		_reach_t = game.clock
	elif game.clock - _reach_t > IDLE_PUSH:
		_reach_t = game.clock
		var nf: Unit = null
		var nd := INF
		for o in foes:
			var d: float = _pos(o).distance_to(_c)
			if d < nd:
				nd = d
				nf = o
		if nf != null:
			var dir: Vector2 = (_pos(nf) - _c).normalized()
			if dir != Vector2.ZERO:
				_face = dir
			for u in held:
				u.cmd_move(u.position + _face * STEP, true)
			_c += _face * STEP
	return false       # (the shared loop sends the idle men on: the line's held men stay)


func _reset(ground: Array, target: Vector2, why: String) -> bool:
	if st == "":
		return false
	var was := st
	st = ""
	_spot.clear()
	_piece_pt = Vector2.INF
	if why != "":
		_say(why)
	if was == "close":
		_close_next = game.clock + CLOSE_COOL
	for u in ground:
		if u.order in ["hold", "idle"] and not (is_gun(u) and u.tesla_mode != "packed" and u.target != null):
			u.cmd_move(target + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)
	return false


func _all_still(ground: Array) -> bool:
	for u in ground:
		if shooter(u) and u.order in ["amove", "d_amove", "move"] and u.target == null:
			return false
	return true


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
	if best == null:
		return []
	return ground.filter(func(o) -> bool: return o.position.distance_squared_to(best.position) < r2)


func _spread(body: Array, c: Vector2) -> float:
	var s := 0.0
	for u in body:
		s += u.position.distance_to(c)
	return s / maxf(1.0, body.size() * Defs.TILE)


func _head(body: Array, target: Vector2) -> Vector2:
	var best: Unit = null
	var bd := INF
	for u in body:
		var d: float = u.position.distance_to(target)
		if d < bd:
			bd = d
			best = u
	return best.position if best else target


func _close_orders(ground: Array, target: Vector2) -> void:
	var to_t: float = _close_pt.distance_to(target)
	for u in ground:
		if u.deploys() and u.tesla_mode == "deployed":
			continue
		var d: float = u.position.distance_to(_close_pt)
		if d <= 2.5 * Defs.TILE or u.position.distance_to(target) < to_t:
			if u.is_mounted() or u.kind == "dragoon":
				if u.order != "idle":
					u.cmd_stop()
			elif u.order != "hold":
				u.cmd_hold()
		elif not (u.order in ["amove", "d_amove"] and u.order_point.distance_to(_close_pt) < 60.0):
			u.cmd_move(_close_pt + Vector2(randf_range(-40, 40), randf_range(-40, 40)), true)


func regrouping() -> bool:
	return st in ["close", "form", "step", "set", "back"]


# ============================================================ 4. the defence

## AI._defend's picks for a force at `spot`: with LINE_MIN shooters or more they arrive as a line facing it, DEF_D short of
## it, on an attack-move (the guns behind them). true = sent.
func defend(picks: Array, spot: Vector2) -> bool:
	if not active():
		return false
	var sh: Array = picks.filter(func(u) -> bool: return _ok(u) and shooter(u))
	if sh.size() < LINE_MIN:
		return false
	var bc := Vector2.ZERO
	for u in sh:
		bc += u.position
	bc /= sh.size()
	if bc.distance_to(spot) < DEF_D + 40.0:
		return false        # (already on it: they fight where they are)
	var face: Vector2 = (spot - bc).normalized()
	var lvl: int = game.level_of(spot)
	var c: Vector2 = spot - face * DEF_D
	if game.level_of(c) != lvl and game.level_of(c) != game.level_of(bc):
		c = _same_level(c, lvl, spot)
	var keep := _spot.duplicate()
	var was := st
	var n := lay(picks, c, face, true)
	var placed := _spot.duplicate()
	_spot = keep if was != "" else {}
	if n == 0:
		return false
	for u in placed:
		_def_spot[u] = placed[u]
	def_lines += 1
	if game.clock - _def_said > 20.0:
		_def_said = game.clock
		_say("meets the force at its buildings with a line: %d muskets facing it, %d gun%s behind" % [n,
				picks.filter(func(u) -> bool: return _ok(u) and is_gun(u)).size(), "" if picks.filter(func(u) -> bool: return _ok(u) and is_gun(u)).size() == 1 else "s"])
	return true


var _def_spot := {}             # Unit -> his spot in a defence line (AI._defend leaves him be while he walks to it)
var _def_said := -99.0


## AI._defend's detachment men on their way to a defence line's spot: left be (not sent onto the raid spot).
func def_walking(u: Unit) -> bool:
	if not _def_spot.has(u):
		return false
	if not _ok(u) or u.order == "idle" or u.position.distance_to(_def_spot[u]) < AT_SPOT:
		_def_spot.erase(u)
		return false
	return true
