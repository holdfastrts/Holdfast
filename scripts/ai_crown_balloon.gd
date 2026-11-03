extends RefCounted
## THE BALLOON HARASS (the owner, 2026-11-03: "Dragoon raids are one thing, balloon harass is another"; branch
## crown-builds-c, docs/crown_builds_c.md): the Crown computer's own plan of Observation Balloons from the Foundry carrying
## Musketeers over cliffs and water to strike where the enemy is not. Run by AICrown (scripts/ai_crown.gd) for its
## Balloon harass plan (`bl`, made only on that plan); the rest of the computer plays as Balanced (the main army holds the
## ramp post on HOLD at home, or goes out on its own waves at the same time).
##  - A PARTY is one balloon and up to four Musketeers from home (never the last HOME_KEEP of them). Each party goes to its
##    own TARGET, as far as it can from the other parties' targets and from the spots struck lately: several small strikes
##    at once at different places, to split the enemy's attention.
##  - TARGETS are the enemy's economy as its side has seen it: its workers (grubs, Winders, Labourers), the Brood's rooted
##    Rootmaws and its Mother's nest, the Clockwork's Mainspring, Cog Presses and Clocktowers, a Crown's Farms and Mills;
##    the enemy's start when nothing is known yet. Rated by the workers seen there lately and what the building feeds,
##    against the enemy army and the anti-air seen near it.
##  - ANTI-AIR is remembered where it was seen (AA_MEM s; a Ratchet Turret until seen gone): every unit that can hit a
##    flyer (Swifts, Springers, Ratchet Turrets, Skywings, Hatchlings, the Storm and Venom Challengers and Sires, Musketeers,
##    Cannon on canister). The flight goes round it (one waypoint to the side with the least of it on the way) and a
##    balloon backs off from it, unless its basket outguns it (a lone Swift or two: the basket shoots them down).
##  - Over the target: with no anti-air near, it HOVERS and the Musketeers fire from the basket (35% further, refilled from
##    the balloon's store) at the workers below, keeping the prey nearest so the basket picks it; with anti-air near, it
##    DROPS them on open ground by the workers and pulls back out of its reach, then LIFTS them out when the defence comes,
##    they are hurt, or the prey is gone. Then the next target, or home to RESTOCK powder (the pilot hauls kegs at a Mill,
##    Barracks or Town Hall) and out again.
##  - At home under attack, a loaded balloon near home hovers over the fight behind our line: the basket fires down too.
##  - The balloons' sight (14 tiles) is the scouting: every flight looks at the enemy's land; an empty balloon with no men
##    to carry floats out to watch the enemy's next hall sites from the safe side.
## Telegraphed and fair: a balloon is slow (46), big and seen from far; it sees only what its side sees (Game.side_sees);
## it knows where the enemy started (every computer does).

const HOME_KEEP := 2             # Musketeers kept at home at least (the ramp post) when a party is formed
const PARTY_MIN := 3             # a party goes with this many Musketeers or more
const PARTY_MAX := 4             # (Defs.DROPSHIP capacity)
const AA_MEM := 75.0             # (s) an anti-air unit seen this long ago is still feared where it was
const AA_MARGIN := 110.0         # (px) kept beyond an anti-air unit's reach
const HOVER_D := 170.0           # (px) the balloon hovers this far from its prey (the basket reaches 256)
const BASKET_R := 250.0
const FLEE_K := 1.0              # anti-air near worth more than this share of the party: back off
const STRIKE_MAX := 90.0         # (s) at one target at most
const NO_PREY := 14.0            # (s) nothing to shoot this long: the next target
const DROP_MAX := 40.0           # (s) on the ground at most before the lift
const LIFT_T := 22.0             # (s) the men walking to the balloon at most
const LOW_SHOTS := 14.0          # the basket's shots (store + men) under this: home to restock
const HURT := 0.45               # a balloon under this share of its health goes home and lets its men off
const SPOT_GAP := 650.0          # (px) the parties' targets this far apart at least (else rated down)
const USED_GAP := 360.0          # (px) a spot struck lately is rated down within this
const USED_FOR := 100.0          # (s) ... for this long
const DEFEND_R := 45.0           # (tiles) a loaded party this near home helps defend it
const FIRST_AT := 0.0            # (s) no strike before this (the plan's first balloon decides it)

var ai = null
var game: Game = null
var team := 0
var parties: Array = []          # [{b, men, phase, since, at, mode, wp, id, t0}]
var aa := {}                     # enemy anti-air (Unit or Building) -> [position, clock, value, reach]
var econ := {}                   # enemy economy seen (Building or rooted Unit) -> [position, clock, kind]
var prey_seen := {}              # enemy worker -> [position, clock]
var used: Array = []             # [position, clock] of the spots struck
var watched := {}                # enemy unit near a party -> true (its death is counted if a party killed it)
var log_lines: Array = []        # [clock, text] (the coach and the test read it)
# the numbers the coach and the doc report
var first_strike := -1.0         # the first shot from a basket at a target, or the first men on the ground there
var first_kill := -1.0
var strikes := 0                 # targets struck (hover or drop)
var drops := 0
var lifts := 0
var killed_value := 0
var killed_workers := 0
var lost_balloons := 0
var lost_men := 0
var trained := 0
var _seen_t := -99.0
var _next_id := 1
var _scout_b: Unit = null


func _init(a) -> void:
	ai = a
	game = a.game
	team = a.team


func has(u) -> bool:
	if u == _scout_b:
		return true
	for p in parties:
		if p["b"] == u or (p["men"] as Array).has(u):
			return true
	return false


func say(s: String) -> void:
	log_lines.append([game.clock, s])
	ai.say(s)


## How many balloons the plan keeps: its "balloons" (2), one more on two halls with LABS_3 labourers (at most 3).
const LABS_3 := 26


func want() -> int:
	var n := int(ai.plan.get("balloons", 2))
	if ai._halls().size() >= 2 and game.workers(team).size() >= LABS_3:
		n += 1
	return mini(n, 3)


func balloons() -> Array:
	return game.units.filter(func(u: Unit) -> bool: return u.team == team and not u.dead and u.kind == "balloon")


func queued() -> int:
	var n := 0
	for f in ai._mine("foundry"):
		n += (f.queue as Array).count("balloon")
	return n


## The Foundry rigs the plan's balloons (before its cannon: the shared _produce may queue those behind).
func produce(upto := -1) -> void:
	var w := want() if upto < 0 else upto
	if balloons().size() + queued() >= w:
		return
	for f in ai._mine("foundry"):
		if not f.built or (f.queue as Array).size() >= 1:
			continue
		if game.can_train(f, "balloon") != "":
			continue
		if game.train(f, "balloon") == "":
			trained += 1
			say("the Foundry rigs a balloon (%d of %d)" % [balloons().size() + queued(), w])
			return


# ------------------------------------------------------------------ what the side sees

func _foe() -> int:
	return ai._foe()


func _aa_of(o) -> float:
	## its reach against a flyer (px), 0: none
	if o is Unit:
		var u: Unit = o
		if u.dead or u.off_field:
			return 0.0
		if u.kind == "cannon":
			return float(u.d.get("range", 0.0)) if u.mode == "canister" else 0.0
		if u.d.get("anti_air", false) or u.d.get("air_only", false):
			return maxf(float(u.d.get("range", 0.0)), 60.0)
		return 0.0
	if o is Building:
		var b: Building = o
		if b.dead or not b.built:
			return 0.0
		if b.d.get("anti_air", false):
			return maxf(float(b.d.get("range", 0.0)), 8.0 * Defs.TILE)
	return 0.0


func _look() -> void:
	if game.clock - _seen_t < 1.0:
		return
	_seen_t = game.clock
	var foe := _foe()
	if foe < 0:
		return
	for u in game.units:
		if u.team != foe or u.dead or u.off_field:
			continue
		if not game.side_sees(team, u.position):
			continue
		var r := _aa_of(u)
		if r > 0.0:
			aa[u] = [u.position, game.clock, float(Game.unit_value(u)), r]
		if u.is_worker():
			prey_seen[u] = [u.position, game.clock]
		elif BroodNew.is_nb(u.kind) and (u.kind == BroodNew.MAW or u.kind == BroodNew.QUEEN):
			econ[u] = [u.position, game.clock, u.kind]
	for b in game.buildings:
		if b.team != foe or b.dead or b.ghost:
			continue
		if not game.side_sees(team, b.center()):
			continue
		var r2 := _aa_of(b)
		if r2 > 0.0:
			aa[b] = [b.center(), game.clock, float(int(b.d.get("cost", 100))), r2]
		if Defs.is_econ(b.kind) or b.kind == game.faction_hall(foe):
			econ[b] = [b.center(), game.clock, b.kind]
	# forget the dead, the old and what is seen gone
	for k in aa.keys():
		var e: Array = aa[k]
		var gone: bool = not is_instance_valid(k) or k.dead
		if gone or (k is Unit and game.clock - float(e[1]) > AA_MEM):
			aa.erase(k)
	for k in econ.keys():
		if not is_instance_valid(k) or k.dead:
			econ.erase(k)
	for k in prey_seen.keys():
		if not is_instance_valid(k) or k.dead or game.clock - float(prey_seen[k][1]) > 60.0:
			prey_seen.erase(k)


## Anti-air near a point: the value of what could hit a balloon there (seen lately).
func aa_at(p: Vector2, extra := 0.0) -> float:
	var v := 0.0
	for k in aa:
		var e: Array = aa[k]
		var pos: Vector2 = k.position if (k is Unit and is_instance_valid(k) and game.side_sees(team, k.position)) else e[0]
		if pos.distance_to(p) < float(e[3]) + AA_MARGIN + extra:
			v += float(e[2])
	return v


## Anti-air along a flight (sampled every 3 tiles).
func aa_line(a: Vector2, b: Vector2) -> float:
	var n := maxi(1, int(a.distance_to(b) / (3.0 * Defs.TILE)))
	var v := 0.0
	for i in n + 1:
		v += aa_at(a.lerp(b, float(i) / float(n)))
	return v


## The enemy army seen near a point (armed, mobile, not workers).
func army_at(p: Vector2, r := 420.0) -> float:
	var foe := _foe()
	var v := 0.0
	for u in game.units_near(p, r):
		if u.team == foe and not u.dead and not u.off_field and not u.is_worker() and u.has_attack() and not u.d.get("air_only", false) \
				and game.side_sees(team, u.position) and not AIHarass.is_static(u):
			v += float(Game.unit_value(u))
	return v


func _party_value(p: Dictionary) -> float:
	var v := 0.0
	var b: Unit = p["b"]
	if is_instance_valid(b) and not b.dead:
		v += float(Game.unit_value(b)) * b.hp / b.max_hp
	for m in p["men"]:
		if is_instance_valid(m) and not m.dead:
			v += float(Game.unit_value(m)) * m.hp / m.max_hp
	return v


# ------------------------------------------------------------------ targets

func _targets() -> Array:
	## [position, base score, what]
	var out: Array = []
	var foe := _foe()
	if foe < 0:
		return out
	for k in econ:
		var e: Array = econ[k]
		var kind := String(e[2])
		var s := 15.0
		match kind:
			"mainspring": s = 45.0
			"rootmaw": s = 30.0
			"brood_mother": s = 20.0
			"cog_press", "farm", "powder_mill": s = 20.0
		out.append([e[0], s, kind])
	if out.is_empty():
		out.append([(Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE, 12.0, "their start"])
	return out


func _prey_near(p: Vector2, r := 420.0) -> int:
	var n := 0
	for k in prey_seen:
		if (prey_seen[k][0] as Vector2).distance_to(p) < r:
			n += 1
	return n


func _pick_target(party: Dictionary) -> Vector2:
	var b: Unit = party["b"]
	var best := Vector2.INF
	var bs := -INF
	var val := _party_value(party)
	for t in _targets():
		var p: Vector2 = t[0]
		var s: float = float(t[1]) + 8.0 * float(_prey_near(p))
		var aav := aa_at(p)
		s -= aav / maxf(val, 1.0) * 60.0
		if aav >= val * FLEE_K:
			s -= 80.0               # (too much anti-air to hover there: only a drop would do)
		s -= army_at(p, 500.0) / maxf(val, 1.0) * 25.0
		for o in parties:
			if o != party and o["at"] != Vector2.INF and (o["at"] as Vector2).distance_to(p) < SPOT_GAP:
				s -= 30.0
		for u in used:
			if (u[0] as Vector2).distance_to(p) < USED_GAP and game.clock - float(u[1]) < USED_FOR:
				s -= 25.0
		s -= b.position.distance_to(p) / 160.0
		if s > bs:
			bs = s
			best = p
	return best


## The way there: straight, or by one waypoint to the side with the least anti-air on the way.
func _route(a: Vector2, b: Vector2) -> Vector2:
	var straight := aa_line(a, b)
	if straight <= 0.0:
		return Vector2.INF
	var mid := (a + b) * 0.5
	var perp := (b - a).orthogonal().normalized()
	var best := Vector2.INF
	var bv := straight
	var size := Vector2(Game.W, Game.H) * Defs.TILE
	for k in [400.0, -400.0, 800.0, -800.0, 1200.0, -1200.0]:
		var w: Vector2 = (mid + perp * k).clamp(Vector2(64, 64), size - Vector2(64, 64))
		var v := aa_line(a, w) + aa_line(w, b) + absf(k) * 0.02
		if v < bv:
			bv = v
			best = w
	return best


# ------------------------------------------------------------------ the parties

func _home() -> Vector2:
	var halls: Array = ai._halls()
	var st := (Vector2(game.starts[team]) + Vector2(2.5, 2.0)) * Defs.TILE
	var best: Vector2 = st
	var bd := INF
	for h in halls:
		if h.built and h.center().distance_to(st) < bd:
			bd = h.center().distance_to(st)
			best = h.center()
	return best


## A spot for boarding: open ground by the hall, on the side away from the ramp... the hall's own side is good enough.
func _board_spot() -> Vector2:
	var home := _home()
	var reg := game.region_of(game.cell_of(home + Vector2(0, 90)))
	for r in [100.0, 140.0, 180.0, 230.0, 290.0]:
		for k in 12:
			var p: Vector2 = home + Vector2.RIGHT.rotated(TAU * k / 12.0) * r
			var c := game.cell_of(p)
			if game._clear_at(p, 16.0, team) and game.passable(c, team) and (reg < 0 or game.region_of(c) == reg):
				return p
	return home + Vector2(0, 110)


func _free_men() -> Array:
	var home := _home()
	var all: Array = game.army(team).filter(func(u: Unit) -> bool: return u.kind == "musketeer" and not u.dead and not has(u))
	var pool: Array = all.filter(func(u: Unit) -> bool:
		return u.hp >= u.max_hp * 0.7 and u.position.distance_to(home) < 30.0 * Defs.TILE and u.order in ["idle", "amove", "hold", "move"] \
			and u.target == null and not ai._raiders.has(u) and not ai._det.has(u) and not (ai._attacking and ai._wave_set.has(u)) \
			and not (ai.harass != null and ai.harass.has(u)) and not ai._on_errand(u))
	pool.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(home) < b.position.distance_to(home))
	var room := all.size() - HOME_KEEP
	return pool.slice(0, clampi(room, 0, PARTY_MAX))


func tick() -> void:
	if ai.difficulty < 1 or ai.peaceful:
		return
	_look()
	_count_kills()
	if not ai.bo_owns():
		produce()           # (in the opening its "balloons" steps rig them, their gold set aside)
	parties = parties.filter(func(p: Dictionary) -> bool: return _alive(p))
	# a new party for every balloon not in one
	for b in balloons():
		if has(b) and b != _scout_b:
			continue
		if b.hp < b.max_hp * HURT:
			_rest(b)
			continue
		var men := _free_men()
		if men.size() < PARTY_MIN or game.clock < FIRST_AT:
			_watch(b)
			continue
		if b == _scout_b:
			_scout_b = null
		var p := {"b": b, "men": men.duplicate(), "phase": "", "since": game.clock, "at": Vector2.INF, "mode": "", "wp": Vector2.INF,
			"id": _next_id, "t0": game.clock, "prey_t": game.clock, "struck": false}
		_next_id += 1
		parties.append(p)
		_phase(p, "load")
		var spot := _board_spot()
		b.cmd_move(spot)
		for m in men:
			m.cmd_move(spot + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
		say("party %d forms: a balloon and %d Musketeers" % [p["id"], men.size()])
	for p in parties:
		_party(p)


func _alive(p: Dictionary) -> bool:
	if p["phase"] == "done":
		return false
	var b: Unit = p["b"]
	p["men"] = (p["men"] as Array).filter(func(u) -> bool:
		if is_instance_valid(u) and not u.dead:
			return true
		lost_men += 1
		return false)
	if not is_instance_valid(b) or b.dead:
		lost_balloons += 1
		say("party %d: its balloon is down" % p["id"])
		for m in p["men"]:
			if is_instance_valid(m) and not m.dead and not m.off_field:
				m.cmd_move(_home())
		return false
	if (p["men"] as Array).is_empty() and p["phase"] != "home":
		_phase(p, "home")
		b.cmd_move(_home())
	return true


func _phase(p: Dictionary, ph: String) -> void:
	p["phase"] = ph
	p["since"] = game.clock


func _aboard(p: Dictionary) -> Array:
	return (p["men"] as Array).filter(func(u: Unit) -> bool: return u.aboard == p["b"])


func _on_ground(p: Dictionary) -> Array:
	return (p["men"] as Array).filter(func(u: Unit) -> bool: return u.aboard == null and not u.off_field)


func _shots(p: Dictionary) -> float:
	var b: Unit = p["b"]
	var n := b.powder
	for m in p["men"]:
		n += m.powder
	return n


func _party(p: Dictionary) -> void:
	var b: Unit = p["b"]
	var t := game.clock - float(p["since"])
	# home under attack: a loaded party near home fires down on the attackers from behind our line
	if p["phase"] in ["fly", "home", "load"] and not _aboard(p).is_empty():
		var thr: Vector2 = ai._threat()
		if thr != Vector2.INF and b.position.distance_to(_home()) < DEFEND_R * Defs.TILE and aa_at(thr) < _party_value(p) * FLEE_K:
			_phase(p, "defend")
			p["at"] = thr
			say("party %d hovers over the attack at home: the basket fires down" % p["id"])
	match String(p["phase"]):
		"load":
			var walking: Array = (p["men"] as Array).filter(func(u: Unit) -> bool: return u.aboard == null)
			var spot := _board_spot()
			if b.position.distance_to(spot) < 40.0 and b.velocity.length() < 4.0:
				for m in walking:
					if m.order != "board":
						game.load_order([m], [b])
			elif b.order != "move" or (b.order_point as Vector2).distance_to(spot) > 30.0:
				b.cmd_move(spot)
			if walking.is_empty() or t > 40.0:
				var ab := _aboard(p)
				for m in walking:
					if is_instance_valid(m):
						m.cmd_stop()
				p["men"] = ab
				if ab.size() < 2:
					_release(p, "too few aboard")
					return
				_go(p)
		"fly":
			_fly(p)
		"strike":
			_strike(p)
		"drop":
			_drop(p)
		"ground":
			_ground(p)
		"lift":
			_lift(p)
		"defend":
			_defend(p)
		"home":
			_go_home(p)


## Off to the next target (or home when the basket is low or the balloon hurt).
func _go(p: Dictionary) -> void:
	var b: Unit = p["b"]
	if b.hp < b.max_hp * HURT or _shots(p) < LOW_SHOTS:
		_phase(p, "home")
		b.cmd_move(_home())
		return
	var at := _pick_target(p)
	if at == Vector2.INF:
		_phase(p, "home")
		b.cmd_move(_home())
		return
	p["at"] = at
	p["struck"] = false
	p["wp"] = _route(b.position, at)
	_phase(p, "fly")
	b.cmd_move(p["wp"] if p["wp"] != Vector2.INF else _approach(p, at))
	say("party %d flies to %s (%d tiles%s)" % [p["id"], _what_at(at), int(b.position.distance_to(at) / Defs.TILE), ", round the anti-air" if p["wp"] != Vector2.INF else ""])


func _what_at(p: Vector2) -> String:
	for t in _targets():
		if (t[0] as Vector2).distance_to(p) < 4.0:
			var k := String(t[2])
			if Defs.BUILDINGS.has(k):
				return "the " + String(Defs.BUILDINGS[k]["name"])
			if Defs.UNITS.has(k):
				return "the " + String(Defs.UNITS[k]["name"])
			return k
	return "a spot"


## The hover point: HOVER_D from the target on the side away from the enemy army and its anti-air.
func _approach(p: Dictionary, at: Vector2) -> Vector2:
	var b: Unit = p["b"]
	var best := at
	var bv := INF
	for k in 8:
		var q: Vector2 = at + Vector2.RIGHT.rotated(TAU * k / 8.0) * HOVER_D
		var v := aa_at(q) * 3.0 + army_at(q, 300.0) + q.distance_to(b.position) * 0.05
		if v < bv:
			bv = v
			best = q
	return best


func _danger(p: Dictionary) -> bool:
	var b: Unit = p["b"]
	var v := aa_at(b.position, 40.0)
	return v > _party_value(p) * FLEE_K * (1.0 if not _aboard(p).is_empty() else 0.3)


func _fly(p: Dictionary) -> void:
	var b: Unit = p["b"]
	var at: Vector2 = p["at"]
	if _danger(p):
		used.append([at, game.clock])
		say("party %d turns back: anti-air on the way (%d of it)" % [p["id"], int(aa_at(b.position, 40.0))])
		_go(p)
		return
	if p["wp"] != Vector2.INF:
		if b.position.distance_to(p["wp"]) < 80.0:
			p["wp"] = Vector2.INF
			b.cmd_move(_approach(p, at))
		elif b.order != "move":
			b.cmd_move(p["wp"])
		return
	if b.position.distance_to(at) < HOVER_D + 140.0:
		strikes += 1
		used.append([at, game.clock])
		p["prey_t"] = game.clock
		var aa_near := aa_at(at)
		if aa_near > 0.0 and army_at(at, 300.0) < _party_value(p):
			_phase(p, "drop")
			var spot := _drop_spot(p, at)
			b.cmd_unload(spot)
			say("party %d drops its men by %s (anti-air near: %d)" % [p["id"], _what_at(at), int(aa_near)])
		else:
			_phase(p, "strike")
			say("party %d hovers over %s: the basket fires" % [p["id"], _what_at(at)])
		return
	if b.order != "move" or game.clock - float(p["since"]) > 4.0 and b.velocity.length() < 2.0:
		b.cmd_move(_approach(p, at))


## Where the basket's fire picks the workers first: the basket shoots the NEAREST enemy it sees, so the balloon hovers
## right over a worker on the side away from anything else (the Mother, a rooted creature, a soldier), out of the
## anti-air's reach.
func _hover_at(p: Dictionary, prey: Array) -> Vector2:
	var b: Unit = p["b"]
	var foe := _foe()
	var others: Array = []
	for u in game.units_near(b.position, BASKET_R + 500.0):
		if u.team == foe and not u.dead and not u.off_field and not u.is_worker() and not u.is_air() and game.side_sees(team, u.position):
			others.append(u.position)
	var best: Vector2 = (prey[0] as Unit).position
	var bv := INF
	var list := prey.duplicate()
	list.sort_custom(func(a: Unit, c: Unit) -> bool: return a.position.distance_to(b.position) < c.position.distance_to(b.position))
	for u in list.slice(0, 6):
		for k in 8:
			var q: Vector2 = (u as Unit).position + Vector2.RIGHT.rotated(TAU * k / 8.0) * 45.0
			var dp: float = q.distance_to((u as Unit).position)
			var v := aa_at(q) * 4.0 + army_at(q, BASKET_R) * 0.5 + q.distance_to(b.position) * 0.08
			for o in others:
				var dd: float = (o as Vector2).distance_to(q)
				if dd < dp + 60.0:
					v += 300.0          # (it would shoot that instead)
				elif dd < BASKET_R:
					v += 20.0
			if v < bv:
				bv = v
				best = q
	return best


func _prey(at: Vector2, r := 520.0) -> Array:
	var foe := _foe()
	var out: Array = []
	for u in game.units_near(at, r):
		if u.team == foe and not u.dead and not u.off_field and u.is_worker() and game.side_sees(team, u.position):
			out.append(u)
	return out


func _strike(p: Dictionary) -> void:
	var b: Unit = p["b"]
	var t := game.clock - float(p["since"])
	if _danger(p) or b.hp < b.max_hp * HURT:
		say("party %d pulls back from %s (%s)" % [p["id"], _what_at(p["at"]), "anti-air" if _danger(p) else "the balloon is hurt"])
		_go(p)
		return
	var prey := _prey(b.position, 420.0)
	if prey.is_empty():
		prey = _prey(p["at"])
	if not prey.is_empty():
		p["prey_t"] = game.clock
		if not p["struck"]:
			p["struck"] = true
			if first_strike < 0.0:
				first_strike = game.clock
				say("the first strike: party %d over %s" % [p["id"], _what_at(p["at"])])
		var hv := _hover_at(p, prey)
		if b.position.distance_to(hv) > 40.0:
			b.cmd_move(hv)
		for u in prey:
			watched[u] = true
	else:
		# nothing in sight here: the nearest workers seen lately near the target (a grub line, a Winder at a press)
		var near := Vector2.INF
		var nd := 900.0
		for k in prey_seen:
			var pp: Vector2 = prey_seen[k][0]
			if pp.distance_to(p["at"]) < nd and aa_at(pp) < _party_value(p) * FLEE_K:
				nd = pp.distance_to(p["at"])
				near = pp
		if near != Vector2.INF and b.position.distance_to(near) > HOVER_D:
			if b.order != "move" or (b.order_point as Vector2).distance_to(near) > 120.0:
				b.cmd_move(b.position.move_toward(near, b.position.distance_to(near) - HOVER_D * 0.7))
		elif b.order != "move" or b.velocity.length() < 2.0:
			b.cmd_move(_approach(p, p["at"]))
	if game.clock - float(p["prey_t"]) > NO_PREY or t > STRIKE_MAX or _shots(p) < LOW_SHOTS:
		_go(p)


## A drop spot: open ground beside the prey, on the side away from the anti-air.
func _drop_spot(p: Dictionary, at: Vector2) -> Vector2:
	var prey := _prey(at)
	var c := at
	if not prey.is_empty():
		c = Vector2.ZERO
		for u in prey:
			c += u.position
		c /= float(prey.size())
	var best := c
	var bv := INF
	for k in 8:
		var q: Vector2 = c + Vector2.RIGHT.rotated(TAU * k / 8.0) * 90.0
		if not game._clear_at(q, 14.0, team):
			continue
		var v := aa_at(q) + army_at(q, 260.0) * 2.0
		if v < bv:
			bv = v
			best = q
	return best


func _drop(p: Dictionary) -> void:
	var b: Unit = p["b"]
	var t := game.clock - float(p["since"])
	if b.hp < b.max_hp * HURT and b.work != "dropping":
		b.cmd_unload(b.position)
	if _aboard(p).is_empty():
		drops += 1
		if first_strike < 0.0:
			first_strike = game.clock
			say("the first strike: party %d's men on the ground by %s" % [p["id"], _what_at(p["at"])])
		p["struck"] = true
		_phase(p, "ground")
		p["prey_t"] = game.clock
		b.cmd_move(_wait_spot(p))
		return
	if t > 25.0 and b.order != "unload":
		b.cmd_unload(b.position)


## The balloon waits out of the anti-air's reach, near the men.
func _wait_spot(p: Dictionary) -> Vector2:
	var men := _on_ground(p)
	var c: Vector2 = p["at"]
	if not men.is_empty():
		c = Vector2.ZERO
		for m in men:
			c += m.position
		c /= float(men.size())
	var best := c
	var bv := INF
	for k in 8:
		for r in [220.0, 340.0]:
			var q: Vector2 = c + Vector2.RIGHT.rotated(TAU * k / 8.0) * r
			var v: float = aa_at(q) * 5.0 + army_at(q, 300.0) + r * 0.2
			if v < bv:
				bv = v
				best = q
	return best


func _ground(p: Dictionary) -> void:
	var b: Unit = p["b"]
	var t := game.clock - float(p["since"])
	var men := _on_ground(p)
	if men.is_empty():
		_go(p)
		return
	var c := Vector2.ZERO
	var hurt := 0
	for m in men:
		c += m.position
		if m.hp < m.max_hp * 0.5:
			hurt += 1
	c /= float(men.size())
	var mv := 0.0
	for m in men:
		mv += float(Game.unit_value(m)) * m.hp / m.max_hp
	var prey := _prey(c, 360.0)
	if not prey.is_empty():
		p["prey_t"] = game.clock
		for m in men:
			if m.target == null or not (m.target is Unit) or not (m.target as Unit).is_worker():
				var best: Unit = null
				var bd := INF
				for u in prey:
					var dd: float = u.position.distance_to(m.position)
					if dd < bd:
						bd = dd
						best = u
				if best:
					m.cmd_attack(best)
			if m.target is Unit:
				watched[m.target] = true
		for u in prey:
			watched[u] = true
	var threat := army_at(c, 330.0)
	if threat > mv * 1.1 or hurt * 2 > men.size() or t > DROP_MAX or game.clock - float(p["prey_t"]) > 10.0:
		_phase(p, "lift")
		b.cmd_move(_lift_spot(p))
		say("party %d lifts its men out (%s)" % [p["id"], "the defence comes" if threat > mv * 1.1 else ("they are hurt" if hurt * 2 > men.size() else "nothing left to shoot")])
		return
	if b.position.distance_to(_wait_spot(p)) > 120.0 and (b.order != "move" or b.velocity.length() < 2.0):
		b.cmd_move(_wait_spot(p))


func _lift_spot(p: Dictionary) -> Vector2:
	var men := _on_ground(p)
	if men.is_empty():
		return (p["b"] as Unit).position
	var c := Vector2.ZERO
	for m in men:
		c += m.position
	c /= float(men.size())
	var reg := game.region_of(game.cell_of(men[0].position))
	for r in [0.0, 40.0, 70.0, 110.0, 160.0]:
		for k in (1 if r == 0.0 else 8):
			var q: Vector2 = c + Vector2.RIGHT.rotated(TAU * k / 8.0) * r
			var qc := game.cell_of(q)
			if game._clear_at(q, 14.0, team) and game.passable(qc, team) and game.region_of(qc) == reg:
				return q
	return c


func _lift(p: Dictionary) -> void:
	var b: Unit = p["b"]
	var t := game.clock - float(p["since"])
	var men := _on_ground(p)
	if men.is_empty() or t > LIFT_T:
		for m in men:
			m.cmd_move(_home())          # (the ones left behind walk home)
		p["men"] = _aboard(p)
		lifts += 1
		_go(p)
		return
	var spot := _lift_spot(p)
	if b.position.distance_to(spot) > 30.0:
		if b.order != "move" or (b.order_point as Vector2).distance_to(spot) > 60.0:
			b.cmd_move(spot)
		for m in men:
			if m.order != "move":
				m.cmd_move(spot)
	else:
		for m in men:
			if m.order != "board":
				game.load_order([m], [b])


func _defend(p: Dictionary) -> void:
	var b: Unit = p["b"]
	var thr: Vector2 = ai._threat()
	if thr == Vector2.INF or _danger(p) or b.hp < b.max_hp * HURT:
		_go(p)
		return
	# over the attackers, a little behind our side of them
	var q: Vector2 = thr + (_home() - thr).normalized() * 110.0
	if b.position.distance_to(q) > 50.0 and (b.order != "move" or (b.order_point as Vector2).distance_to(q) > 80.0):
		b.cmd_move(q)
	for u in game.units_near(b.position, BASKET_R):
		if game.hostile(u.team, team) and not u.dead:
			watched[u] = true


func _go_home(p: Dictionary) -> void:
	var b: Unit = p["b"]
	var home := _home()
	if b.position.distance_to(home) > 220.0 and b.order != "restock":
		if b.order != "move" or b.velocity.length() < 2.0:
			b.cmd_move(home)
		p["since"] = game.clock
		return
	if b.hp < b.max_hp * HURT or (p["men"] as Array).is_empty():
		_release(p, "home")
		return
	# (the pilot hauls kegs at the Mill, the Barracks or the hall: the men aboard refill from the store)
	var low: bool = b.powder < b._pmax * 0.75
	if low and game.clock - float(p["since"]) < 45.0:
		if b.order != "restock" and (b.order == "idle" or b.velocity.length() < 2.0):
			b.cmd_restock()
		return
	_go(p)


## The party is over: the men get off at home and go back to the army; the balloon waits.
func _release(p: Dictionary, why: String) -> void:
	var b: Unit = p["b"]
	if is_instance_valid(b) and not b.dead:
		if not b.passengers.is_empty():
			b.cmd_unload(_board_spot())
		else:
			b.cmd_move(_board_spot())
	for m in p["men"]:
		if is_instance_valid(m) and not m.dead and m.aboard == null:
			m.cmd_stop()
	_phase(p, "done")
	say("party %d is over (%s)" % [p["id"], why])


func _rest(b: Unit) -> void:
	if not b.passengers.is_empty():
		if b.order != "unload":
			b.cmd_unload(_board_spot())
		return
	if b.position.distance_to(_home()) > 220.0 and b.order != "move":
		b.cmd_move(_home())


## A balloon with no men: it floats out to look at the enemy's land from the safe side (its sight is the scouting), and
## comes home when anti-air is near or when men are ready for it.
func _watch(b: Unit) -> void:
	if not b.passengers.is_empty():
		if b.order != "unload":
			b.cmd_unload(_board_spot())
		return
	var foe := _foe()
	if foe < 0:
		return
	if aa_at(b.position, 60.0) > 0.0:
		b.cmd_move(_home())
		return
	if _scout_b != null and _scout_b != b and is_instance_valid(_scout_b) and not _scout_b.dead:
		if b.position.distance_to(_board_spot()) > 120.0 and b.order != "move":
			b.cmd_move(_board_spot())
		return
	_scout_b = b
	if b.order == "move" and b.velocity.length() > 2.0:
		return
	# a look-out point: between the two bases, toward the enemy, two thirds of the way, off the line with the least anti-air
	var a := _home()
	var e: Vector2 = (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE
	var best := a.lerp(e, 0.55)
	var bv := INF
	for k in [0.0, 500.0, -500.0, 900.0, -900.0]:
		var q: Vector2 = a.lerp(e, 0.62) + (e - a).orthogonal().normalized() * k
		q = q.clamp(Vector2(64, 64), Vector2(Game.W, Game.H) * Defs.TILE - Vector2(64, 64))
		var v := aa_at(q, 100.0) * 4.0 + army_at(q, 400.0) + absf(k) * 0.05
		if v < bv:
			bv = v
			best = q
	if b.position.distance_to(best) > 60.0:
		b.cmd_move(best)


# ------------------------------------------------------------------ the count

func _count_kills() -> void:
	var mine := {}
	for p in parties:
		mine[p["b"]] = true
		for m in p["men"]:
			mine[m] = true
	for u in watched.keys():
		if not is_instance_valid(u):
			watched.erase(u)
			continue
		if not (u is Unit):
			watched.erase(u)
			continue
		if u.dead:
			var by = u.last_hitter
			var ours: bool = by != null and is_instance_valid(by) and (mine.has(by) or (by is Unit and (by as Unit).aboard != null and mine.has((by as Unit).aboard)))
			if not ours and by is Unit and is_instance_valid(by) and (by as Unit).team == team and (by as Unit).kind == "musketeer" and (by as Unit).aboard != null:
				ours = true
			if ours:
				killed_value += Game.unit_value(u)
				if u.is_worker():
					killed_workers += 1
				if first_kill < 0.0:
					first_kill = game.clock
					say("the first kill of the balloon harass: %s" % String(u.d["name"]))
			watched.erase(u)


func summary() -> String:
	return "strikes %d (drops %d, lifts %d), first strike %s, first kill %s, killed %d (%d workers), lost %d balloons and %d men" % [
		strikes, drops, lifts, _mmss(first_strike), _mmss(first_kill), killed_value, killed_workers, lost_balloons, lost_men]


func _mmss(t: float) -> String:
	if t < 0.0:
		return "-"
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
