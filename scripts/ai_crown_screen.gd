class_name AICrownScreen
extends RefCounted
## THE CROWN'S RIDER SCREEN (crown-rider-screen, the owner 2026-11-12 08:03: "This line movement work is great and also
## should be paired with Horsemen on front scouting."; docs/crown_rider_screen.md). The line (scripts/ai_crown_line.gd)
## forms only on what the Crown knows: an enemy in sight or seen in the last 20 s. A musket sees 8 tiles and reaches 6, so
## an enemy army was first seen at contact and most fights began unformed. Now (the Crown computer, Normal and up, the main
## army's waves and the home posts; raids, the Horseman rush and the Balloon harass keep their own riders):
##  1. THE SCREEN: while a wave marches, a few Horsemen (SCREEN_N by the wave's size: its own Horsemen first, then free
##     ones at home; the Barracks trains one when the plan has a Horse Breeder and none is free) ride AHEAD of it along its
##     road (LEAD px past its head) and out on its flanks; what they see is the line's to know (AICrownLine._known: the
##     riders' eyes), so it halts and forms out of reach, facing the enemy, before it walks into it. The riders do not
##     fight the enemy army: they keep sight and keep alive (they back off from what can catch or shoot them, and keep
##     KEEP px from the enemy known).
##  2. AT CONTACT (the line's fight): they pull back to the line's ends and behind it (out of its fire), then work the
##     FLANKS: they ride down enemy workers, the hurt and the stragglers, lone scouts, and what comes at our guns; never
##     into the enemy's mass (a prey with two who can catch or shoot a rider beside it is left alone), on a leash.
##  3. THE PICKET: at home, at the post the army stands at (the natural's gate, the cliff edge, the ramp's top), one rider
##     stands PICKET_D forward on the road toward the enemy; when it sees a force coming it rides back and says so
##     (the army at home has its warning and the knowledge, AICrownHold._seen).
## Design: docs/design_principles.md 1 (fair: what a player does with his riders, nothing the computer could not see),
## 3-4 (scouting reveals strategy; battles with formed lines). No unit or economy number changed.
## Study switch: `-- screen:off` (no screen, no picket, no riders trained for them).

const SCREEN_N := [[20, 2], [40, 3], [9999, 4]]   # [wave supply under this, riders]
const LEAD := 620.0              # (px) the lead rider this far ahead of the wave's head along its road
const FLANK_FWD := 300.0         # (px) the flankers this far ahead along the road ...
const FLANK_SIDE := 430.0        # ... and this far out to each side
const KEEP := 360.0              # (px) a screen rider keeps this far from the nearest enemy soldier known
const EYE_R := 300.0             # (px) a rider's eyes for the line (a Horseman sees 8 tiles = 256 px)
const DANGER_R := 400.0          # (px) enemies this near a rider are weighed
const HURT := 0.3                 # a rider below this share of its hit points leaves the screen
const PICK_HP := 0.45            # ... and none is picked below this (it keeps out of reach: a hurt rider can still see)
const COOL := 60.0               # (s) a rider sent home is not picked again for this long
const ROUTE_EVERY := 3.0         # (s) the wave's road looked up again this often
const FLANK_R := 480.0           # (px) at contact: prey this near a rider's flank post
const FLANK_LEASH := 620.0       # (px) ... and it never rides farther than this from the post
const PREY_GUARDS := 2           # a prey with this many enemies by it that can catch or shoot a rider is left alone
const PICKET_D := 520.0          # (px) the picket this far forward of the post along the road toward the enemy
const PICKET_WARN := 150.0       # value of an armed force the picket warns of (or two soldiers that can catch or shoot it)
const PICKET_BACK := 25.0        # (s) the picket stays back at least this long
const PICKET_EVERY := 20.0       # (s) the picket's spot worked out again this often
const TRAIN_FREE := 3            # the screen and the picket want this many sound Horsemen free for them (the loop's scout too) ...
const TRAIN_MAX := 5             # ... and the Barracks trains for them only while fewer than this are alive and in training

var ai = null
var game: Game = null
var on := not OS.get_cmdline_user_args().has("screen:off")

var riders := {}                 # Unit -> {"role": "lead"/"left"/"right", "back_until", "pt"}
var _cool := {}                  # Unit -> clock until which it is not picked
var picket: Unit = null
var _pk := {"spot": Vector2.INF, "post": Vector2.INF, "back": Vector2.INF, "t": -99.0, "state": "", "until": 0.0}
var _route := PackedVector2Array()
var _route_t := -99.0
var _route_to := Vector2.INF
var _flank_post := {}            # Unit -> its post at contact
var _said := {}                  # text kind -> clock

# (tests, the coach, the report)
var said: Array = []             # [clock, text]
var sent := 0                    # riders put on the screen
var lost := 0                    # screen riders killed on the screen
var picket_lost := 0
var sightings := 0               # enemy armies first seen by the screen (the line formed on them)
var warns: Array = []            # [clock, value] the picket's warnings
var flank_hits := 0              # prey ridden at by the flank work
var pulled := 0                  # times the riders pulled back to the line at contact


func _init(owner) -> void:
	ai = owner
	game = owner.game


func active() -> bool:
	return on and ai.difficulty >= 1 and ai.ln != null and ai.ln.active()


func has(u) -> bool:
	return riders.has(u) or (picket != null and u == picket)


func _say(s: String, kind := "", every := 0.0) -> void:
	if kind != "":
		if game.clock - float(_said.get(kind, -999.0)) < every:
			return
		_said[kind] = game.clock
	said.append([snappedf(game.clock, 0.1), s])
	if game.mlog:
		game.mlog.add("%s%s%s" % [game.mlog.who(ai.team), "" if s.begins_with("'s") else " ", s])


static func _ok(u) -> bool:
	return u != null and is_instance_valid(u) and not u.dead and not u.off_field


## The riders' eyes for the line (AICrownLine._known): where the screen riders and the picket stand.
func eyes() -> Array:
	var out: Array = []
	for u in riders:
		if _ok(u):
			out.append(u.position)
	if _ok(picket):
		out.append(picket.position)
	return out


# ============================================================ every think (AICrown stage 3, before the army)

func tick() -> void:
	for u in riders.keys():
		if not is_instance_valid(u) or u.dead:
			lost += 1
			_say("'s screen rider is lost (%d lost)" % lost)
			riders.erase(u)
			_flank_post.erase(u)
	for u in _cool.keys():
		if not is_instance_valid(u) or float(_cool[u]) < game.clock:
			_cool.erase(u)
	if picket != null and (not is_instance_valid(picket) or picket.dead):
		picket_lost += 1
		_say("'s picket is lost")
		picket = null
	if not active():
		_release_all("")
		_drop_picket()
		return
	_train()
	var wave := _wave()
	short = false
	if wave.is_empty():
		_release_all("the wave is home")
	else:
		_screen(wave)
	_picket_tick()


## The wave the screen rides for: the main army's wave out, with a line to form (not a riders' wave, not the rush).
func _wave() -> Array:
	if not ai._attacking or ai._rush_wave or ai._rush_state == "ongoing":
		return []
	var w: Array = []
	for u in ai._wave_set.keys():
		if _ok(u) and not u.is_air() and not riders.has(u):
			w.append(u)
	if w.filter(func(u: Unit) -> bool: return AICrownLine.shooter(u)).size() < AICrownLine.LINE_MIN:
		return []
	var all: Array = w.duplicate()
	all.append_array(riders.keys().filter(func(u) -> bool: return _ok(u)))
	if ai._cavalry_wave(all):
		return []            # (a riders' wave keeps its own play: the raids)
	return w


func _want(wave: Array) -> int:
	var sup: int = ai._army_supply(wave)
	for e in SCREEN_N:
		if sup < int(e[0]):
			return int(e[1])
	return 2


## A Horseman free for the screen or the picket: not raiding, scouting the loop, harassing, defending, getting on its horse.
func _free(u: Unit, from_wave: bool) -> bool:
	if u.kind != "cuirassier" or not _ok(u) or has(u) or _cool.has(u) or u.hp < u.max_hp * PICK_HP:
		return false
	if ai._raiders.has(u) or ai._det.has(u) or ai._horse_coming(u) or ai._on_errand(u) or ai._patch.has(u):
		return false
	if ai.harass != null and ai.harass.has(u):
		return false
	if ai.get("dr") != null and ai.dr.has(u):
		return false
	if ai.get("siege") != null and ai.siege.has(u):
		return false
	var in_wave: bool = ai._attacking and ai._wave_set.has(u)
	return in_wave if from_wave else not in_wave


var short := false                # a wave out and its screen short of riders (AICrownHold's loop picks no new scout)


func _screen(wave: Array) -> void:
	var want := _want(wave)
	short = riders.size() < want
	if riders.size() < want:
		var head := _head(wave)
		var pool: Array = []
		for u in game.army(ai.team):
			if _free(u, true):
				pool.append(u)
		pool.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(head) < b.position.distance_to(head))
		var home: Array = []
		for u in game.army(ai.team):
			if _free(u, false) and u != picket:
				home.append(u)
		home.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(head) < b.position.distance_to(head))
		pool.append_array(home)
		if ai.ch != null:
			# (the loop's rider scouts: the wave out, its screen comes first; AICrownHold picks again from what is left)
			for u in ai.ch.scouts.keys():
				if _ok(u) and u.hp >= u.max_hp * PICK_HP and not pool.has(u):
					pool.append(u)
		if pool.size() < want - riders.size() and _ok(picket) and ai._threat() == Vector2.INF:
			pool.append(picket)          # (the wave out: the picket rides with it)
		if dbg and pool.is_empty() and game.clock - _dbg_p > 10.0:
			_dbg_p = game.clock
			for u in game.army(ai.team):
				if u.kind == "cuirassier" and not u.dead:
					print("[screen %d] no rider: hp %.2f cool %s raid %s det %s coming %s errand %s scout %s patch %s harass %s dr %s wave %s order %s" % [int(game.clock),
						u.hp / u.max_hp, _cool.has(u), ai._raiders.has(u), ai._det.has(u), ai._horse_coming(u), ai._on_errand(u),
						ai.ch.scouts.has(u), ai._patch.has(u), ai.harass != null and ai.harass.has(u), ai.get("dr") != null and ai.dr.has(u),
						ai._wave_set.has(u), u.order])
		var took := 0
		for u in pool:
			if riders.size() >= want:
				break
			if u == picket:
				picket = null
			if ai.ch != null and ai.ch.scouts.has(u):
				ai.ch.scouts.erase(u)
			riders[u] = {"role": "", "back_until": 0.0, "pt": Vector2.INF}
			ai._wave_set.erase(u)
			sent += 1
			took += 1
		if took > 0:
			_roles()
			_say("'s wave sends %d Horsem%s ahead and to its flanks as a screen (%d out)" % [took, "an" if took == 1 else "en", riders.size()],
					"send", 15.0)
	elif riders.size() > want + 1:
		var extra: Unit = riders.keys()[riders.size() - 1]
		_release(extra, "")
		_roles()
	var ln: AICrownLine = ai.ln
	var contact: bool = ln.st in ["fight", "back"]
	if contact and _flank_post.is_empty() and not riders.is_empty():
		pulled += 1
		_say("'s screen pulls back to the line's flanks at contact", "pull", 10.0)
	if not contact:
		_flank_post.clear()
	_update_route(wave)
	var known: Array = ln._known(ln._body(wave)) if not wave.is_empty() else []
	for u in riders.keys():
		if u.hp < u.max_hp * HURT:
			_release(u, "hurt")
			continue
		if contact:
			_flank(u, wave, ln)
		else:
			_ride(u, wave, known)


func _roles() -> void:
	var order := ["lead", "left", "right", "lead2"]
	var i := 0
	for u in riders:
		riders[u]["role"] = order[mini(i, order.size() - 1)]
		i += 1


func _release(u: Unit, why: String) -> void:
	riders.erase(u)
	_flank_post.erase(u)
	_cool[u] = game.clock + COOL
	if why != "":
		_say("'s screen rider rides back (%s)" % why, "back_" + why, 8.0)
	if _ok(u):
		# (back to the wave's body, or home when the wave is home)
		if ai._attacking and ai.ln != null and ai.ln._c != Vector2.INF and ai.ln._face != Vector2.ZERO and why == "hurt":
			u.cmd_move(ai.ln._c - ai.ln._face * 6.0 * Defs.TILE)
		elif ai._attacking:
			ai._wave_set[u] = true
		else:
			var post: Vector2 = ai._post_spot()
			u.cmd_move(post if post != Vector2.INF else game.center_of_team(ai.team))


func _release_all(why: String) -> void:
	if riders.is_empty():
		return
	for u in riders.keys():
		_release(u, "")
	_cool.clear()
	if why != "":
		_say("'s screen rides home (%s)" % why, "home", 20.0)


# ------------------------------------------------------------ the screen ahead

func _head(wave: Array) -> Vector2:
	var t: Vector2 = ai._wave_target
	var best := Vector2.INF
	var bd := INF
	var body: Array = ai.ln._body(wave)
	for u in (body if not body.is_empty() else wave):
		var d: float = u.position.distance_to(t)
		if d < bd:
			bd = d
			best = u.position
	return best


func _update_route(wave: Array) -> void:
	var t: Vector2 = ai._wave_target
	if game.clock - _route_t < ROUTE_EVERY and _route_to.distance_to(t) < 100.0 and not _route.is_empty():
		return
	_route_t = game.clock
	_route_to = t
	var h := _head(wave)
	if h == Vector2.INF:
		_route = PackedVector2Array()
		return
	_route = game.find_path(h, t, false, 7.0, ai.team)
	if _route.is_empty() or _route[0].distance_to(h) > 64.0:
		_route.insert(0, h)


## The point `dist` px along the wave's road from its head, and the road's direction there.
func _along(dist: float) -> Array:
	if _route.size() < 2:
		var t: Vector2 = ai._wave_target
		var h: Vector2 = _route[0] if _route.size() == 1 else t
		var dir0: Vector2 = (t - h).normalized()
		return [h + dir0 * minf(dist, h.distance_to(t)), dir0]
	var left := dist
	for i in range(1, _route.size()):
		var a: Vector2 = _route[i - 1]
		var b: Vector2 = _route[i]
		var l: float = a.distance_to(b)
		if l >= left:
			return [a + (b - a).normalized() * left, (b - a).normalized()]
		left -= l
	var n := _route.size()
	return [_route[n - 1], (_route[n - 1] - _route[n - 2]).normalized()]


## A rider's place on the screen: the lead on the road ahead, the flankers out to the sides; kept KEEP px from every enemy
## soldier known (pulled back along the road toward the wave).
func _place(role: String, known: Array) -> Vector2:
	var p: Vector2
	if role == "lead" or role == "lead2":
		var a: Array = _along(LEAD if role == "lead" else LEAD * 0.6)
		p = a[0]
		if role == "lead2":
			p += Vector2(-(a[1] as Vector2).y, (a[1] as Vector2).x) * 120.0
	else:
		var a2: Array = _along(FLANK_FWD)
		var dir: Vector2 = a2[1]
		var perp := Vector2(-dir.y, dir.x) * (1.0 if role == "left" else -1.0)
		p = (a2[0] as Vector2) + perp * FLANK_SIDE
	var head: Vector2 = _route[0] if not _route.is_empty() else p
	for k in 6:
		var near := INF
		for o in known:
			near = minf(near, ai.ln._pos(o).distance_to(p))
		if near >= KEEP:
			break
		p = p.lerp(head, 0.25)
	return _open(p, head)


## p, or the nearest open ground to it toward `back` (a flank point on a cliff or in the trees).
func _open(p: Vector2, back: Vector2) -> Vector2:
	for k in 9:
		var q: Vector2 = p.lerp(back, k / 8.0)
		var c: Vector2i = game.cell_of(q)
		if game.in_map(c) and game.open_cell(c) and game.passable(c, ai.team):
			return q
	return back


## What can catch the rider or shoot it from where it stands, near it: their middle (Vector2.INF: none) and how many.
func _danger(u: Unit, at: Vector2 = Vector2.INF) -> Array:
	var p: Vector2 = u.position if at == Vector2.INF else at
	var c := Vector2.ZERO
	var n := 0
	for o in game.units_near(p, DANGER_R):
		if not game.hostile(o.team, ai.team) or o.dead or o.off_field or not Game.fights_back(o):
			continue
		if not game.is_visible_to(ai.team, o.position):
			continue
		var rng := float(o.d.get("range", 0))
		var d: float = o.position.distance_to(p)
		var catches: bool = o.speed >= u.speed * 0.85 and not AIHarass.is_static(o) and d < 300.0
		var shoots: bool = rng >= 80.0 and d < rng + 110.0 and o.can_hit(u)
		var close: bool = d < 120.0
		if catches or shoots or close:
			c += o.position
			n += 1
	for b in game.buildings:
		if b.dead or not b.built or b.kind != Defs.CW_TURRET or not game.hostile(b.team, ai.team):
			continue
		if b.center().distance_to(p) < float(Defs.TURRET["range"]) + 110.0 and game.is_visible_to(ai.team, b.center()):
			c += b.center()
			n += 1
	if n == 0:
		return [Vector2.INF, 0]
	return [c / float(n), n]


func _ride(u: Unit, wave: Array, known: Array) -> void:
	var e: Dictionary = riders[u]
	var dg: Array = _danger(u)
	if int(dg[1]) > 0:
		# (back off toward the wave, away from the danger: the screen keeps alive and keeps sight)
		var head: Vector2 = _route[0] if not _route.is_empty() else game.center_of_team(ai.team)
		var away: Vector2 = (u.position - (dg[0] as Vector2)).normalized()
		var to_head: Vector2 = (head - u.position).normalized()
		var p: Vector2 = _open(u.position + (away + to_head).normalized() * 260.0, head)
		if u.order != "move" or u.order_point.distance_to(p) > 80.0:
			u.cmd_move(p)
		e["back_until"] = game.clock + 3.0
		_say("'s screen rider backs off from the enemy (%d near)" % int(dg[1]), "danger", 6.0)
		return
	if game.clock < float(e["back_until"]):
		return
	var pt := _place(String(e["role"]), known)
	e["pt"] = pt
	if int(_danger(u, pt)[1]) > 0:
		pt = u.position.lerp(_route[0] if not _route.is_empty() else u.position, 0.3)
	var d: float = u.position.distance_to(pt)
	if d > 50.0:
		if u.order != "move" or u.order_point.distance_to(pt) > 60.0:
			u.cmd_move(pt)
	elif u.order != "hold":
		u.cmd_hold()


# ------------------------------------------------------------ at contact: back to the flanks, then the flank work

func _flank(u: Unit, wave: Array, ln: AICrownLine) -> void:
	if not _flank_post.has(u):
		_flank_post[u] = _post_for(riders[u]["role"], ln)
	var post: Vector2 = _flank_post[u]
	if post == Vector2.INF:
		return
	if _in_fire(u.position, ln, 460.0):
		# (coached, Dune Sea 1107 8:17: the lead rider rode back through the line's front, in its fire: out round its end)
		var perp := Vector2(-ln._face.y, ln._face.x)
		var side: float = 1.0 if (u.position - ln._c).dot(perp) >= 0.0 else -1.0
		var end: Vector2 = _open(ln._c + perp * side * (_half(ln) + 5.0 * Defs.TILE) + ln._face * Defs.TILE, post)
		if u.order != "move" or u.order_point.distance_to(end) > 60.0:
			u.cmd_move(end)
		return
	# hurt or too far out: back to the post
	if u.position.distance_to(post) > FLANK_LEASH:
		if u.order != "move" or u.order_point.distance_to(post) > 60.0:
			u.cmd_move(post)
		return
	if u.target != null and is_instance_valid(u.target) and not u.target.dead and u.order == "attack":
		if _prey_ok(u, u.target, ln):
			return
	var prey := _prey(u, post, ln)
	if prey != null:
		u.cmd_attack(prey)
		flank_hits += 1
		_say("'s screen rider rides down %s on the flank" % _what(prey), "prey", 12.0)
		return
	var dg: Array = _danger(u)
	if int(dg[1]) >= 2:
		var p: Vector2 = post.lerp(ln._c - ln._face * 4.0 * Defs.TILE, 0.5)
		if u.order != "move" or u.order_point.distance_to(p) > 60.0:
			u.cmd_move(p)
		return
	if u.position.distance_to(post) > 50.0:
		if u.order != "move" or u.order_point.distance_to(post) > 60.0:
			u.cmd_move(post)
	elif u.order != "hold":
		u.cmd_hold()


static func _what(o: Unit) -> String:
	if o.is_worker():
		return "a worker"
	if o.hp < o.max_hp * 0.4:
		return "a hurt %s" % String(o.d.get("name", o.kind))
	return "a %s" % String(o.d.get("name", o.kind))


## A rider's post at contact: the lead behind the guns, the flankers beyond the ends of the line, a little back.
func _post_for(role: String, ln: AICrownLine) -> Vector2:
	if ln._c == Vector2.INF or ln._face == Vector2.ZERO:
		return Vector2.INF
	var T := float(Defs.TILE)
	var perp := Vector2(-ln._face.y, ln._face.x)
	var half := 3.0 * T
	for s in ln._spot.keys():
		if is_instance_valid(s) and AICrownLine.shooter(s):
			half = maxf(half, absf((ln._spot[s] - ln._c).dot(perp)))
	var p: Vector2
	match role:
		"left":
			p = ln._c + perp * (half + 4.0 * T) - ln._face * 1.5 * T
		"right":
			p = ln._c - perp * (half + 4.0 * T) - ln._face * 1.5 * T
		"lead2":
			p = ln._c + perp * (half + 6.5 * T) - ln._face * 3.0 * T
		_:
			p = ln._c - ln._face * (AICrownLine.GUN_BACK + 3.0) * T - perp * (half + 2.0 * T)
	return _open(p, ln._c - ln._face * 3.0 * T)


func _half(ln: AICrownLine) -> float:
	var perp := Vector2(-ln._face.y, ln._face.x)
	var half := 3.0 * Defs.TILE
	for s in ln._spot.keys():
		if is_instance_valid(s) and AICrownLine.shooter(s):
			half = maxf(half, absf((ln._spot[s] - ln._c).dot(perp)))
	return half


## In front of the line's muskets (between them and the enemy, within its width, `depth` px out): their fire.
func _in_fire(p: Vector2, ln: AICrownLine, depth := 260.0) -> bool:
	if ln._c == Vector2.INF or ln._face == Vector2.ZERO:
		return false
	var perp := Vector2(-ln._face.y, ln._face.x)
	var q: Vector2 = p - ln._c
	return q.dot(ln._face) > -20.0 and q.dot(ln._face) < depth and absf(q.dot(perp)) < _half(ln) + 30.0


func _guards(u: Unit, o: Unit) -> int:
	var n := 0
	for g in game.units_near(o.position, 200.0):
		if g == o or not game.hostile(g.team, ai.team) or g.dead or g.off_field or not Game.fights_back(g):
			continue
		var rng := float(g.d.get("range", 0))
		if (g.speed >= u.speed * 0.85 and not AIHarass.is_static(g)) or (rng >= 80.0 and g.can_hit(u)):
			n += 1
	return n


func _prey_ok(u: Unit, o, ln: AICrownLine) -> bool:
	if not (o is Unit) or not _ok(o) or not game.hostile(o.team, ai.team) or o.is_air() or not u.can_hit(o):
		return false
	if not game.is_visible_to(ai.team, o.position) or _in_fire(o.position, ln):
		return false
	if not _flank_post.has(u) or o.position.distance_to(_flank_post[u]) > FLANK_LEASH:
		return false
	return _guards(u, o) < PREY_GUARDS


## The flank work's prey near the post: what comes at our guns first, then workers, the hurt and stragglers, lone scouts.
func _prey(u: Unit, post: Vector2, ln: AICrownLine) -> Unit:
	var guns: Array = ln._spot.keys().filter(func(g) -> bool: return _ok(g) and AICrownLine.is_gun(g))
	var best: Unit = null
	var bs := -INF
	for o in game.units_near(post, FLANK_R):
		if not _prey_ok(u, o, ln):
			continue
		var s := 0.0
		if o.is_worker():
			s = 3.0
		elif not Game.fights_back(o):
			continue
		else:
			for g in guns:
				if g.position.distance_to(o.position) < 300.0:
					s = 4.0
					break
			if s == 0.0 and o.hp < o.max_hp * 0.4:
				s = 2.5          # (the hurt and the fleeing)
			if s == 0.0:
				var alone := true
				for o2 in game.units_near(o.position, 220.0):
					if o2 != o and game.hostile(o2.team, ai.team) and Game.fights_back(o2) and not o2.dead:
						alone = false
						break
				if alone:
					s = 2.0      # (a straggler, a scout)
		if s <= 0.0:
			continue
		s -= o.position.distance_to(u.position) / 400.0
		if s > bs:
			bs = s
			best = o
	return best


# ============================================================ 3. the picket at home

## Where the army at home stands (the natural's gate, the cliff edge, the ramp's top) and where the picket rides back to.
func _post() -> Array:
	var ch = ai.ch
	if ch == null or not ch.active():
		return [Vector2.INF, Vector2.INF]
	var T := float(Defs.TILE)
	if ch.gate_live() and ch._gate_at != Vector2.INF:
		return [ch._gate_at, ch._gate_back if ch._gate_back != Vector2.INF else ch._gate_at]
	if ch.edge_live():
		var c := Vector2.ZERO
		for s in ch._edge_spots:
			c += s
		c /= float(ch._edge_spots.size())
		return [c, c]
	if ch._bc != Vector2.INF:
		var top: Vector2 = ch._bc * T
		return [top, (ch._bc + ch._in * (ch.GUN_BACK + 2.0)) * T]
	return [Vector2.INF, Vector2.INF]


func _picket_spot() -> void:
	if game.clock - float(_pk["t"]) < PICKET_EVERY and _pk["spot"] != Vector2.INF:
		return
	_pk["t"] = game.clock
	var pp := _post()
	_pk["post"] = pp[0]
	_pk["back"] = pp[1]
	_pk["spot"] = Vector2.INF
	if pp[0] == Vector2.INF or ai._foe() < 0:
		return
	var path: PackedVector2Array = game.find_path(pp[0], ai._enemy_base(), false, 7.0, ai.team)
	if path.size() < 2:
		return
	var left := PICKET_D
	var at: Vector2 = path[path.size() - 1]
	for i in range(1, path.size()):
		var l: float = path[i - 1].distance_to(path[i])
		if l >= left:
			at = path[i - 1] + (path[i] - path[i - 1]).normalized() * left
			break
		left -= l
	_pk["spot"] = _open(at, pp[0])


## The Horseman rush (or the raid party that is the rush) wants every rider (as AICrownHold's scouts: none then).
func _rush_riders() -> bool:
	return ai._rush_state == "ongoing" or (ai.opening == "breeder" and ai.strategy == "rush") or ai._rush_open()


func _drop_picket() -> void:
	if _ok(picket):
		var post: Vector2 = ai._post_spot()
		picket.cmd_move(post if post != Vector2.INF else game.center_of_team(ai.team))
		_cool[picket] = game.clock + 10.0
	picket = null


func _picket_tick() -> void:
	_picket_spot()
	var spot: Vector2 = _pk["spot"]
	if spot == Vector2.INF or _rush_riders() or ai.peaceful:
		_drop_picket()
		return
	if picket == null:
		var best: Unit = null
		for u in game.army(ai.team):
			if _free(u, false) and (best == null or u.position.distance_to(spot) < best.position.distance_to(spot)):
				best = u
		if best == null:
			return
		picket = best
		_pk["state"] = "out"
		_pk["warned"] = false
		_say("sets a Horseman as a picket on the road %d px out from its post" % int(PICKET_D), "picket", 60.0)
	var u: Unit = picket
	if u.hp < u.max_hp * HURT:
		_cool[u] = game.clock + COOL
		_drop_picket()
		return
	var back: Vector2 = _pk["back"]
	# what it sees: an armed force coming
	var v := 0.0
	var n := 0
	for o in game.units_near(u.position, EYE_R + 60.0):
		if not game.hostile(o.team, ai.team) or o.dead or o.off_field or o.is_worker() or not o.has_attack() or o.is_air():
			continue
		if AIHarass.is_static(o) or o.kind in ["horse", "powder_wagon"] or not game.is_visible_to(ai.team, o.position):
			continue
		v += float(Game.unit_value(o))
		n += 1
	var dg0: Array = _danger(u)
	if (v >= PICKET_WARN or (n >= 2 and int(dg0[1]) > 0)) and not bool(_pk.get("warned", false)):
		_pk["state"] = "back"
		_pk["warned"] = true
		_pk["until"] = game.clock + PICKET_BACK
		warns.append([snappedf(game.clock, 0.1), int(v)])
		_say("'s picket sees a force coming (%d: %d soldiers) and rides back to the post" % [int(v), n])
		u.cmd_move(back)
		return
	if _pk["state"] == "back":
		if v > 0.0 or int(dg0[1]) > 0:
			_pk["until"] = game.clock + PICKET_BACK
		if game.clock < float(_pk["until"]) or ai._threat() != Vector2.INF:
			if u.position.distance_to(back) > 60.0 and (u.order != "move" or u.order_point.distance_to(back) > 60.0):
				u.cmd_move(back)
			return
		_pk["state"] = "out"
		_pk["warned"] = false
	if int(dg0[1]) > 0:
		_pk["state"] = "back"
		_pk["until"] = game.clock + 8.0
		u.cmd_move(back)
		return
	if u.position.distance_to(spot) > 50.0:
		if u.order != "move" or u.order_point.distance_to(spot) > 60.0:
			u.cmd_move(spot)
	elif u.order != "hold":
		u.cmd_hold()


# ============================================================ the Barracks

## The screen's own Horseman (every TRAIN_EVERY s, when wants_rider): the shared training reaches the screen's turn only
## when the Barracks are not held for the guns' gold; the screen trains one itself, with gold to spare (TRAIN_SPARE over
## its price), not while the hall plan keeps its gold or the enemy is at home.
const TRAIN_EVERY := 1.0
const TRAIN_SPARE := 40
var _train_t := -99.0
var trained := 0


func _train() -> void:
	if game.clock - _train_t < TRAIN_EVERY:
		return
	_train_t = game.clock
	if not wants_rider() or ai._keeping() or ai._threat() != Vector2.INF:
		return
	for b in ai._mine("barracks"):
		if not b.built or (b.queue as Array).size() >= 2:
			continue
		var hk: String = ai._soldier_key(b, "cuirassier")
		if dbg:
			print("[screen %d] train: key '%s' (%s) gold %d keeping %s" % [int(game.clock), hk, game.can_train(b, Defs.train_key("cuirassier", false)), ai._gold(), ai._keeping()])
		if hk == "" or ai._gold() < int(game.unit_price(ai.team, hk)[0]) + TRAIN_SPARE:
			continue
		if game.train(b, hk) == "":
			trained += 1
			_say("trains a Horseman for its screen and picket", "train", 30.0)
			return

## A Horseman to train for the screen and the picket (AI._produce): the plan has a Horse Breeder, the army is a real one,
## and none is free; TRAIN_MAX at most (alive and in training).
var dbg := OS.get_cmdline_user_args().has("screen:debug")
var _dbg_t := -99.0
var _why := ""
var _dbg_p := -99.0


func wants_rider() -> bool:
	var r := _wants_rider()
	if dbg and game.clock - _dbg_t > 20.0:
		_dbg_t = game.clock
		print("[screen %d t%d] wants_rider %s (%s) riders %d picket %s" % [int(game.clock), ai.team, r, _why, riders.size(), picket != null])
	return r


func _wants_rider() -> bool:
	if not active() or game.clock < 240.0 or _rush_riders():
		_why = "inactive/early/rush"
		return false
	if ai._mine("horse_breeder").filter(func(b: Building) -> bool: return b.built).is_empty():
		return false
	var n := 0
	var free := 0
	var sup := 0
	for u in game.army(ai.team):
		if u.dead:
			continue
		if u.kind == "cuirassier":
			n += 1
			if u.hp >= u.max_hp * PICK_HP and (has(u) or _free(u, false) or _free(u, true) or (ai.ch != null and ai.ch.scouts.has(u))):
				free += 1
		elif AICrownLine.shooter(u):
			sup += int(u.d["supply"])
	for b in ai._mine("barracks"):
		n += (b.queue as Array).count("cuirassier")
		if (b.queue as Array).has("cuirassier"):
			_why = "queued"
			return false
	_why = "n %d free %d sup %d" % [n, free, sup]
	if sup < 8 or n >= TRAIN_MAX or free >= TRAIN_FREE:
		return false
	return true
