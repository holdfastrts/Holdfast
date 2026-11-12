extends "res://tools/film_coach.gd"
## FILM THE CROWN'S LINE (crown-line-fight, docs/crown_line_fight.md): tools/film_coach.gd's coached film (map every 15 s,
## coach.txt, shots:1 for camera pictures) plus every ENGAGEMENT of a Crown army, written to <out>/engage.json:
##  - an engagement starts when a Crown shooter (Musketeer, Guardsman, dismounted Dragoon: a musket's reach) has an armed
##    enemy within CONTACT px after QUIET s without one, and ends after QUIET s without contact;
##  - at its start: the shooters within NEAR px of the contact, their SHAPE (across: how wide they stand across the line
##    to the enemy, depth: how deep along it; px, two standard deviations each) and how many were on HOLD or still moving;
##  - first volley: how many of those shooters fired in the first 5 s (their powder went down);
##  - the guns (Field Cannons, Mortars) within GUN_NEAR px: unlimbered, behind the shooters (on our side of their middle),
##    and how many fired in the engagement;
##  - traded: the value of the enemy army units killed and of ours lost near it (every unit that came within JOIN px of
##    the contact while it lasted counts).
##   godot --headless --fixed-fps 30 --script res://tools/film_line.gd -- map:greenhold seed:1 end:900 out:/abs/dir \
##       slots:crown/optimal/0,brood/optimal/1 [shots:1]
## A measuring tool: it changes no rule.
const CONTACT := 215.0
const NEAR := 520.0
const JOIN := 700.0
const GUN_NEAR := 900.0
const QUIET := 12.0
const SHOOTERS := ["musketeer", "musketeer_armoured", "dismounted", "dismounted_armoured", "dragoon"]
const GUNS := ["cannon", "mortar"]
var _next_eng := 0.0
var _eng: Dictionary = {}       # team -> the open engagement
var _engs: Array = []           # finished engagements


func _process(delta: float) -> bool:
	var done: bool = super._process(delta)
	if g != null and not done and g.clock >= _next_eng:
		_next_eng = g.clock + 0.5
		for tm in n:
			if g.faction_of(tm) == "crown":
				_track(tm)
	if done and g != null:
		for tm in _eng.keys():
			_close(tm)
		var f := FileAccess.open(out.path_join("engage.json"), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(_engs, " "))
	return done


func _foes(tm: int) -> Array:
	var o: Array = []
	for t2 in n:
		if g.hostile(t2, tm):
			o.append_array(_army_units(t2))
	return o


func _track(tm: int) -> void:
	var mine: Array = _army_units(tm)
	var shooters: Array = mine.filter(func(u: Unit) -> bool: return u.kind in SHOOTERS)
	var foes := _foes(tm)
	var touching: Array = []
	for u in shooters:
		for o in foes:
			if o.position.distance_to(u.position) < CONTACT and not o.is_air():
				touching.append(u)
				break
	var e: Dictionary = _eng.get(tm, {})
	var c: float = g.clock
	if touching.is_empty():
		if not e.is_empty() and c - float(e["last"]) > QUIET:
			_close(tm)
		return
	var mid := Vector2.ZERO
	for u in touching:
		mid += u.position
	mid /= touching.size()
	if e.is_empty():
		e = {"t0": c, "last": c, "at": mid, "mine": {}, "foe": {}, "p0": {}, "fired5": -1, "gun_p0": {}, "guns_fired": {}}
		var near: Array = shooters.filter(func(u: Unit) -> bool: return u.position.distance_to(mid) < NEAR)
		var sc := Vector2.ZERO
		for u in near:
			sc += u.position
			e["p0"][u.get_instance_id()] = [u, u.powder]
		sc /= maxi(1, near.size())
		var fc := Vector2.ZERO
		var nf := 0
		for o in foes:
			if o.position.distance_to(mid) < NEAR + 200.0:
				fc += o.position
				nf += 1
		var dir := (fc / maxi(1, nf) - sc).normalized() if nf > 0 else Vector2.RIGHT
		var perp := Vector2(-dir.y, dir.x)
		var sa := 0.0
		var sd := 0.0
		var held := 0
		var moving := 0
		for u in near:
			var q: Vector2 = u.position - sc
			sa += q.dot(perp) * q.dot(perp)
			sd += q.dot(dir) * q.dot(dir)
			if u.order == "hold":
				held += 1
			elif u.order in ["move", "amove", "d_amove"] and not u.velocity.is_zero_approx():
				moving += 1
		var k := float(maxi(1, near.size()))
		e["n"] = near.size()
		e["across"] = int(2.0 * sqrt(sa / k))
		e["depth"] = int(2.0 * sqrt(sd / k))
		e["held"] = held
		e["moving"] = moving
		e["in_reach0"] = _in_reach(near, foes)
		e["foe_val0"] = int(_val(foes.filter(func(o: Unit) -> bool: return o.position.distance_to(mid) < NEAR + 200.0)))
		e["mine_val0"] = int(_val(mine.filter(func(u: Unit) -> bool: return u.position.distance_to(mid) < NEAR + 200.0)))
		var gs: Array = []
		for u in mine:
			if u.kind in GUNS and u.position.distance_to(sc) < GUN_NEAR:
				e["gun_p0"][u.get_instance_id()] = [u, u.powder]
				gs.append({"kind": u.kind, "set": u.tesla_mode == "deployed", "behind": (u.position - sc).dot(dir) < -20.0,
						"from_line": int((u.position - sc).dot(dir))})
		e["guns0"] = gs
		e["sc"] = sc
		e["dir"] = dir
		e["clock"] = _mmss(c)
		_eng[tm] = e
	e["last"] = c
	e["at"] = mid
	if int(e["fired5"]) < 0 and c - float(e["t0"]) >= 5.0:
		var fired := 0
		var reach := 0
		var near2: Array = []
		for id in e["p0"]:
			var pr: Array = e["p0"][id]
			var u = pr[0]
			if is_instance_valid(u) and not u.dead:
				near2.append(u)
				if u.powder < float(pr[1]) - 0.01:
					fired += 1
			elif not is_instance_valid(u) or u.dead:
				fired += 0
		e["fired5"] = fired
		e["in_reach5"] = _in_reach(near2, foes)
	for id in e["gun_p0"]:
		var gp: Array = e["gun_p0"][id]
		if is_instance_valid(gp[0]) and not gp[0].dead and gp[0].powder < float(gp[1]) - 0.01:
			e["guns_fired"][id] = true
	for u in mine:
		if u.position.distance_to(mid) < JOIN:
			e["mine"][u.get_instance_id()] = [u, Game.unit_value(u)]
	for o in foes:
		if o.position.distance_to(mid) < JOIN:
			e["foe"][o.get_instance_id()] = [o, Game.unit_value(o)]


func _in_reach(list: Array, foes: Array) -> int:
	var k := 0
	for u in list:
		var r: float = float(u.d.get("range", 190)) + 20.0
		for o in foes:
			if o.position.distance_to(u.position) < r:
				k += 1
				break
	return k


func _val(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += Game.unit_value(u)
	return v


func _dead_value(d: Dictionary) -> int:
	var v := 0.0
	for id in d:
		var pr: Array = d[id]
		if not is_instance_valid(pr[0]) or pr[0].dead:
			v += float(pr[1])
	return int(v)


func _close(tm: int) -> void:
	var e: Dictionary = _eng.get(tm, {})
	_eng.erase(tm)
	if e.is_empty():
		return
	var lost := _dead_value(e["mine"])
	var killed := _dead_value(e["foe"])
	if lost + killed < 60:
		return          # (a skirmish with a scout: not a fight)
	_engs.append({"team": tm, "t": int(e["t0"]), "clock": e["clock"], "len": int(float(e["last"]) - float(e["t0"])),
			"cell": [int((e["sc"] as Vector2).x / Defs.TILE), int((e["sc"] as Vector2).y / Defs.TILE)],
			"n": e["n"], "across": e["across"], "depth": e["depth"], "held": e["held"], "moving": e["moving"],
			"in_reach0": e["in_reach0"], "fired5": e["fired5"], "in_reach5": e.get("in_reach5", -1),
			"mine_val0": e["mine_val0"], "foe_val0": e["foe_val0"], "guns": e["guns0"],
			"guns_fired": (e["guns_fired"] as Dictionary).size(), "killed": killed, "lost": lost,
			"home": _near_home(tm, e["sc"])})


func _near_home(tm: int, p: Vector2) -> bool:
	for h in g.halls_of(tm):
		if h.center().distance_to(p) < 900.0:
			return true
	return false
