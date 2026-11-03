extends RefCounted
## THE DRAGOON RAIDS (the owner, 2026-11-03: "Dragoon raids are one thing, balloon harass is another"; the Crown
## computer's plan "dragoon", scripts/ai_crown.gd, docs/crown_builds_a.md). A mobile mid-game build whose identity is the
## raid: Musketeers on horseback (a Powder Mill and a Horse Breeder) ride out in SEVERAL SMALL GROUPS at once to the
## enemy's workers (Brood grubs at their Rootmaws, Clockwork Winders, Labourers), dismount to shoot where it pays, mount
## and ride off before the army arrives, while the Musketeer line holds the main's high ground (the doctrine).
## Each group:
##   gather  the riders meet at the main's front (never one by one into the enemy's land)
##   ride    a plain ride (mounted) to its site, round the side away from the enemy's main and its army
##   strike  at the site: each rider picks the worker it can shoot (AIHarass.pick_prey), dismounts (0.8 s), fires, mounts
##           again for the next; a slow defender close is stepped away from (AIHarass.kite_from)
##   leave   a real defender coming (a Sire or the Mother on her feet, a pack of fast melee, shooters or an army worth more
##           than the group, AIHarass.outmatched): every rider mounts and rides off AT ONCE, the site is HOT for HOT_FOR s,
##           and the group goes on to another site (hit and run), or home when it is hurt, short of shot or cut down
##   home    back to the main to refill its powder and mend; there it is let go and the next group forms
## Sites: enemy halls and economy buildings, the Brood's Rootmaws and Mother, remembered once SEEN (no cheating), the
## enemy's natural expansion and base sites on its side as guesses (an empty guess is struck off for EMPTY_FOR s). The best
## site: workers there, far from the enemy's main (an undefended expansion), no army seen near it lately, not another
## group's site, not hot.
## Self-contained (one file, one preload in ai_crown.gd) so the parallel Crown plans (crown-builds-b, -c) merge cleanly.

const GROUP := 4                # riders a group sets out with (GROUP_MIN at least)
const GROUP_MIN := 3
const MAX_GROUPS := 3
const GATHER_R := 260.0         # (px) a rider this close to the rally point has gathered
const GATHER_MAX := 25.0        # (s) the group goes with those who came
const DANGER_R := 470.0         # (px) armed enemies this close are weighed (a dismounted rider needs 0.8 s to mount again)
const ARRIVE_R := 300.0         # (px) at the site: it strikes
const STRIKE_MAX := 50.0        # (s) at most at one site, then on to the next (hit and run)
const STRIKE_DRY := 14.0        # (s) nothing to shoot there this long: on to the next
const HOT_FOR := 90.0           # (s) a site a group was chased from is left be
const EMPTY_FOR := 150.0        # (s) a guessed site found empty is left be
const ARMY_MEMORY := 60.0       # (s) an enemy army seen this long ago still counts for the choice of site
const ARMY_NEAR := 650.0        # (px) a site with a remembered army this close is not picked (unless nothing else)
const HOME_HP := 0.5            # the group goes home below this share of its hit points
const HURT_HP := 0.3            # a rider below this goes home alone
const DRY_POWDER := 0.3         # the group goes home with this share of its shot left
const MAX_OUT := 240.0          # (s) out at most this long
const FAST_X := 0.8             # a melee enemy at least this share of the group's speed catches it
const PACK := 3                 # fast melee in this number (and at least the group's) is a pack: the group leaves
const MAIN_R := 1000.0         # (px) a site this close to the enemy's main is near its army (picked last)
const NO_SITE_WAIT := 45.0      # (s) no site worth a ride: no group forms again for this long
const HANDS_MEMORY := 90.0     # (s) a worker seen this long ago still says where they walk
const MAX_LEAVES := 2           # chased off this often on one sortie: home (round A: groups rode from pack to pack)
const BROOD_WAIT := 75.0        # (s) against the Brood a group waits at home this long for its army to come out
const OUT_V := 250.0            # (value) the enemy's army on our side of the map this big: it is out, the raids go
const SLOW_X := 1.5             # slow defenders worth this much more than the group: it leaves too
const MAIN_NO := 750.0          # (px) a site this close to the enemy's main is never picked (unless its army is out)
const LOOK_T := 2.0             # (s) between looks at the map (sites, armies)

var ai                          # the AICrown
var game: Game
var groups: Array = []          # {"units", "state", "site", "t0", "t_state", "dry_t", "strikes", "id"}
var member := {}                # Unit -> its group
var ever := {}                  # Unit -> true: every rider that went on a raid (the coach counts their kills)
var sites := {}                 # key -> {"p": Vector2, "kind", "seen": clock, "workers": int, "guess": bool}
var hot := {}                   # site key -> clock until which it is left be
var armies: Array = []          # [clock, position, value] of enemy armies seen
var hands: Array = []           # [clock, position] of enemy workers seen (the haul lines: where to wait for them)
var log_lines: Array = []       # [clock, text] (tests and the coach read it)
var stats := {"groups": 0, "strikes": 0, "leaves": 0, "homes": 0}
var _look_t := -99.0
var _next_id := 1
var _form_after := 0.0          # (clock) no group forms before this (NO_SITE_WAIT)


func _init(a) -> void:
	ai = a
	game = a.game


func has(u: Unit) -> bool:
	return member.has(u)


func say(msg: String) -> void:
	log_lines.append([game.clock, msg])
	if game.mlog:
		game.mlog.add("%s's Dragoon raid: %s" % [game.mlog.who(ai.team), msg])


# ------------------------------------------------------------------ who rides

## A rider: a Dragoon, or a Musketeer of ours that dismounted from one (he mounts again by himself).
static func is_rider(u: Unit) -> bool:
	return u.kind == "dragoon" or (u.kind == "musketeer" and u.auto_mount and u.steed != null and is_instance_valid(u.steed) and not u.steed.dead)


## The Dragoons at home free to form a group.
func pool() -> Array:
	var out: Array = []
	for u in game.army(ai.team):
		if u.dead or u.off_field or member.has(u) or u.kind != "dragoon":
			continue
		if ai._wave_set.has(u) and ai._attacking:
			continue
		if ai._raiders.has(u) or ai._det.has(u) or (ai.harass != null and ai.harass.has(u)) or ai.ch.is_scout(u):
			continue
		if ai.scout != null and ai.scout.is_scout(u):
			continue
		if u.hp < u.max_hp * 0.7 or (u._pmax > 0.0 and u.powder < u._pmax * 0.7):
			continue                # (mending, refilling)
		out.append(u)
	return out


# ------------------------------------------------------------------ the map: sites and armies

func _look() -> void:
	if game.clock - _look_t < LOOK_T:
		return
	_look_t = game.clock
	var foe: int = ai._foe()
	if foe < 0:
		return
	var t: int = ai.team
	var hall: String = game.faction_hall(foe)
	# economy buildings and halls seen
	for b in game.buildings:
		if b.dead or b.ghost or b.team != foe or not (b.kind == hall or Defs.is_econ(b.kind)):
			continue
		if not game.target_seen(t, b, b.center()):
			continue
		var key := "b%d" % b.get_instance_id()
		sites[key] = {"p": b.center(), "kind": b.kind, "seen": game.clock, "workers": int(sites.get(key, {}).get("workers", 0)), "guess": false, "e": b}
	# the Brood's Rootmaws and Mother (its workers haul between them)
	for o in game.units:
		if o.dead or o.team != foe or not (o.kind == BroodNew.MAW or o.kind == BroodNew.QUEEN):
			continue
		if not game.is_visible_to(t, o.position) and not (ai.scout != null and ai.scout._nb_seen.has(o)):
			continue
		var key := "u%d" % o.get_instance_id()
		sites[key] = {"p": o.position, "kind": o.kind, "seen": game.clock, "workers": int(sites.get(key, {}).get("workers", 0)), "guess": false, "e": o}
	# the guesses: its natural and the base sites on its side of the map (struck off once seen empty)
	var their: Vector2 = Vector2(game.starts[foe]) * Defs.TILE if game.starts.size() > foe else Vector2.INF
	var mine: Vector2 = Vector2(game.starts[t]) * Defs.TILE if game.starts.size() > t else Vector2.INF
	if their != Vector2.INF:
		var cells: Array = []
		if game.expansions.size() > foe:
			cells.append(game.expansions[foe])
		for bs in game.base_sites:
			var p: Vector2 = (Vector2(bs) + Vector2(2.5, 2.0)) * Defs.TILE
			if mine == Vector2.INF or p.distance_to(their) < p.distance_to(mine) * 0.85:
				cells.append(bs)
		for c in cells:
			if c is Vector2i and c.x >= 0 and not game.starts.has(c):
				var key := "g%d_%d" % [c.x, c.y]
				if not sites.has(key):
					sites[key] = {"p": (Vector2(c) + Vector2(2.5, 2.0)) * Defs.TILE, "kind": "guess", "seen": -999.0, "workers": 0, "guess": true}
	# workers seen: counted at the nearest site; dead sites dropped
	for key in sites.keys():
		var s: Dictionary = sites[key]
		if s.has("e") and (not is_instance_valid(s["e"]) or s["e"].dead):
			sites.erase(key)
			continue
		if game.is_visible_to(t, s["p"]):
			var n := 0
			for o in game.units_near(s["p"], 420.0):
				if o.team == foe and not o.dead and o.is_worker():
					n += 1
			s["workers"] = n
			if s["guess"] and n == 0 and not _site_has_building(s["p"], foe):
				hot[key] = game.clock + EMPTY_FOR          # (a guess found empty)
	# workers seen (any of our eyes: scouts, the line, the riders)
	hands = hands.filter(func(a: Array) -> bool: return game.clock - float(a[0]) < HANDS_MEMORY)
	for o in game.units:
		if o.team == foe and not o.dead and not o.off_field and o.is_worker() and game.is_visible_to(t, o.position):
			hands.append([game.clock, o.position])
	if hands.size() > 400:
		hands = hands.slice(hands.size() - 400)
	# armies seen (a value at a spot), for the choice of site
	armies = armies.filter(func(a: Array) -> bool: return game.clock - float(a[0]) < ARMY_MEMORY)
	var seen_army: Array = []
	for o in game.units:
		if o.dead or o.team != foe or not AIHarass.is_defender(o) or not game.is_visible_to(t, o.position):
			continue
		seen_army.append(o)
	var used := {}
	for o in seen_army:
		if used.has(o):
			continue
		var v := 0.0
		var c := Vector2.ZERO
		var n := 0
		for p in seen_army:
			if not used.has(p) and p.position.distance_to(o.position) < 300.0:
				used[p] = true
				v += float(Game.unit_value(p))
				c += p.position
				n += 1
		if n > 0 and v >= 150.0:
			armies.append([game.clock, c / n, v])


func _site_has_building(p: Vector2, foe: int) -> bool:
	for b in game.buildings:
		if not b.dead and not b.ghost and b.team == foe and b.center().distance_to(p) < 400.0:
			return true
	for o in game.units_near(p, 400.0):
		if o.team == foe and not o.dead and AIHarass.is_static(o):
			return true
	return false


## The best site for a group setting out from `from` (Vector2.INF: none worth it).
func pick_site(from: Vector2, g: Dictionary) -> String:
	var foe: int = ai._foe()
	if foe < 0:
		return ""
	var their: Vector2 = Vector2(game.starts[foe]) * Defs.TILE if game.starts.size() > foe else from
	var taken := {}
	for o in groups:
		if o != g and String(o["site"]) != "":
			taken[String(o["site"])] = true
	var best := ""
	var bs := -INF
	var out: bool = ai.ch.foe_near() >= OUT_V              # (its army on our side: the main is open)
	for key in sites:
		var s: Dictionary = sites[key]
		if float(hot.get(key, -1.0)) > game.clock:
			continue
		var p: Vector2 = s["p"]
		var sc := 0.0
		sc += minf(float(s["workers"]), 8.0) * 60.0
		var hn := 0
		for h in hands:
			if (h[1] as Vector2).distance_to(p) < 700.0:
				hn += 1
		sc += minf(float(hn), 20.0) * 12.0
		if not s["guess"]:
			sc += 150.0
		sc += minf(p.distance_to(their), 1800.0) * 0.35        # (far from its main: an expansion)
		sc -= p.distance_to(from) * 0.15
		var dm: float = p.distance_to(their)
		if dm < MAIN_NO and not out:
			continue                                           # (its main: its army and its turrets; round A a05)
		if dm < MAIN_R:
			sc -= 400.0 + (MAIN_R - dm) * 0.6                   # (its main and the foot of its ramp: the army is there)
		for a in armies:
			var d: float = (a[1] as Vector2).distance_to(p)
			if d < ARMY_NEAR:
				sc -= 300.0 + float(a[2]) * 0.5
		for o in taken:
			if sites.has(o) and (sites[o]["p"] as Vector2).distance_to(p) < 600.0:
				sc -= 400.0                                    # (another group is there: spread)
		if sc > bs:
			bs = sc
			best = key
	return best


# ------------------------------------------------------------------ the tick (each army think)

var _dt := 1.0
var _last_tick := -1.0


func tick() -> void:
	_dt = clampf(game.clock - _last_tick, 0.0, 3.0) if _last_tick >= 0.0 else 1.0
	_last_tick = game.clock
	_look()
	# the groups lose their dead
	for g in groups:
		g["units"] = (g["units"] as Array).filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and not u.off_field)
	for g in groups.duplicate():
		if (g["units"] as Array).is_empty():
			_drop(g)
	_form()
	for g in groups.duplicate():
		_steer(g)


## A new group: GROUP riders free at home (GROUP_MIN when a group is short), at most MAX_GROUPS out.
func _form() -> void:
	if groups.size() >= MAX_GROUPS or ai.peaceful or game.clock < _form_after:
		return
	var p := pool()
	if p.size() < GROUP:
		return
	var front: Vector2 = ai._front()
	p.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(front) < b.position.distance_to(front))
	var g := {"units": p.slice(0, GROUP), "state": "gather", "site": "", "t0": game.clock, "t_state": game.clock, "dry_t": 0.0,
		"strikes": 0, "id": _next_id, "rally": front}
	_next_id += 1
	for u in g["units"]:
		member[u] = g
		ever[u] = true
	groups.append(g)
	stats["groups"] += 1
	say("group %d forms with %d Dragoons" % [int(g["id"]), (g["units"] as Array).size()])


func _drop(g: Dictionary) -> void:
	for u in g["units"]:
		member.erase(u)
	groups.erase(g)


func _state(g: Dictionary, state: String) -> void:
	g["state"] = state
	g["t_state"] = game.clock


func _center(units: Array) -> Vector2:
	var c := Vector2.ZERO
	for u in units:
		c += u.position
	return c / maxf(1.0, units.size())


func _hp(units: Array) -> float:
	var h := 0.0
	for u in units:
		h += u.hp / u.max_hp
	return h / maxf(1.0, units.size())


func _powder(units: Array) -> float:
	var p := 0.0
	var n := 0
	for u in units:
		if u._pmax > 0.0:
			p += u.powder / u._pmax
			n += 1
	return p / n if n > 0 else 1.0


func _home() -> Vector2:
	var hs: Array = ai._halls()
	return hs[0].center() if not hs.is_empty() else game.center_of_team(ai.team)


## The danger near the group: "" none, else why it must leave.
func danger(units: Array, c: Vector2) -> String:
	var foes: Array = []
	for o in game.units_near(c, DANGER_R):
		if not game.hostile(o.team, ai.team) or not AIHarass.is_defender(o) or not game.is_visible_to(ai.team, o.position):
			continue
		foes.append(o)
	for u in units:
		var h = u.last_hitter
		if is_instance_valid(h) and h is Unit and not h.dead and game.clock - u.hit_clock < 2.0 and AIHarass.is_defender(h) and not foes.has(h):
			foes.append(h)
	if foes.is_empty():
		return ""
	var sp := 112.0
	var fast := 0
	var shooters := 0
	for o in foes:
		if AIHarass.is_big(o):
			return String(Defs.UNITS[o.kind]["name"])
		if float(o.d.get("range", 0)) >= AIHarass.SHOOTER_R:
			shooters += int(o.d["supply"])
		elif o.speed >= sp * FAST_X:
			fast += 1
	if fast >= maxi(PACK, units.size()):
		return "a pack of %d" % fast
	var real := foes.filter(func(o: Unit) -> bool: return not AIHarass.is_slow(o, units))
	if not real.is_empty() and ai.hz().outmatched(units, real):
		return "an army worth more"
	# (slow ones too, in number: a Dragoon on foot is slower than a Clock Soldier; round A a05, a group rode into the
	# Clockwork's main past 30 of them, "slow" each, and died)
	var all_v := 0.0
	for o in foes:
		all_v += ai._unit_value(o)
	if all_v > ai.hz().strength(units) * SLOW_X:
		return "an army (%d)" % int(all_v)
	return ""


## Where to ride away to: from the danger toward home, 600 px.
func _away(c: Vector2) -> Vector2:
	var foes := Vector2.ZERO
	var n := 0
	for o in game.units_near(c, DANGER_R + 100.0):
		if game.hostile(o.team, ai.team) and AIHarass.is_defender(o):
			foes += o.position
			n += 1
	var home := _home()
	var dir := (home - c).normalized()
	if n > 0:
		var away := (c - foes / n).normalized()
		dir = (away * 0.6 + dir * 0.4).normalized()
	var p := c + dir * 600.0
	return game.resolve_terrain(p, p, 14.0, ai.team)


func _move_all(units: Array, p: Vector2, spread := 50.0) -> void:
	for u in units:
		if u.order == "mount" or u.order == "dismount":
			continue            # (getting on or off: the order after it is set already, or the next tick gives one)
		var q := p + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		if u.order != "move" or u.order_point.distance_to(p) > spread * 2.5:
			u.cmd_move(q)


## A way round to the site: a waypoint beside the straight ride, on the side away from the enemy's main and the armies
## it remembers (Vector2.INF: ride straight).
func _waypoint(from: Vector2, to: Vector2) -> Vector2:
	var foe: int = ai._foe()
	if foe < 0:
		return Vector2.INF
	var bad: Array = []
	if game.starts.size() > foe:
		bad.append(Vector2(game.starts[foe]) * Defs.TILE)
	for a in armies:
		bad.append(a[1])
	var mid := (from + to) * 0.5
	var near := false
	for b in bad:
		if Geometry2D.get_closest_point_to_segment(b, from, to).distance_to(b) < 700.0:
			near = true
	if not near:
		return Vector2.INF
	var side := (to - from).orthogonal().normalized()
	var best := Vector2.INF
	var bs := -INF
	for k in [-1.0, 1.0]:
		var p: Vector2 = mid + side * k * minf(900.0, from.distance_to(to) * 0.45)
		var c := game.cell_of(p)
		if not game._walkable(c):
			continue
		var sc := 0.0
		for b in bad:
			sc += minf(p.distance_to(b), 1500.0)
		if sc > bs:
			bs = sc
			best = p
	return best


func _steer(g: Dictionary) -> void:
	var units: Array = g["units"]
	var c := _center(units)
	var home := _home()
	var st := String(g["state"])
	var out := game.clock - float(g["t0"])
	# the hurt go home alone; a group cut to one goes home
	for u in units.duplicate():
		if u.hp < u.max_hp * HURT_HP and st != "home":
			units.erase(u)
			member.erase(u)
			u.cmd_move(home + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
	if units.is_empty():
		_drop(g)
		return
	if st == "gather":
		var rally: Vector2 = g["rally"]
		var there := units.filter(func(u: Unit) -> bool: return u.position.distance_to(rally) < GATHER_R)
		if (there.size() == units.size() or game.clock - float(g["t_state"]) > GATHER_MAX) and _may_go(g):
			g["units"] = there if there.size() >= GROUP_MIN else units
			for u in units:
				if not (g["units"] as Array).has(u):
					member.erase(u)
			_go(g, c)
			return
		_move_all(units, rally, 60.0)
		return
	if st != "home":
		var why := ""
		if units.size() < 2 and (g["units"] as Array).size() < 2:
			why = "cut down to one"
		elif _hp(units) < HOME_HP:
			why = "hurt"
		elif _powder(units) < DRY_POWDER:
			why = "short of shot"
		elif out > MAX_OUT:
			why = "out %d s" % int(out)
		if why != "":
			say("group %d rides home (%s)" % [int(g["id"]), why])
			stats["homes"] += 1
			_state(g, "home")
			st = "home"
	if st == "home":
		if c.distance_to(home) < 450.0:
			say("group %d is home: let go" % int(g["id"]))
			_drop(g)
			return
		var d := danger(units, c)
		_move_all(units, home if d == "" else _away(c), 70.0)
		return
	# riding or striking: a real defender coming and it leaves at once
	var d2 := danger(units, c) if st != "leave" else ""
	if d2 != "":
		var key := String(g["site"])
		if key != "":
			hot[key] = game.clock + HOT_FOR
		stats["leaves"] += 1
		g["leaves"] = int(g.get("leaves", 0)) + 1
		say("group %d rides off from %s (%s)" % [int(g["id"]), _site_name(key), d2])
		g["flee"] = _away(c)
		g["flee_t"] = game.clock
		_state(g, "leave")
		st = "leave"
	if st == "leave":
		var fp: Vector2 = g["flee"]
		if danger(units, c) != "":
			if c.distance_to(fp) < 150.0 or game.clock - float(g["flee_t"]) > 8.0:
				g["flee"] = _away(c)
				g["flee_t"] = game.clock
			_move_all(units, g["flee"], 60.0)
			return
		if c.distance_to(fp) > 200.0 and game.clock - float(g["t_state"]) < 6.0:
			_move_all(units, fp, 60.0)
			return
		if int(g.get("leaves", 0)) >= MAX_LEAVES:
			say("group %d rides home (chased off %d times)" % [int(g["id"]), int(g["leaves"])])
			stats["homes"] += 1
			_state(g, "home")
			return
		_go(g, c)                      # (clear of it: on to another site)
		return
	var key2 := String(g["site"])
	if not sites.has(key2) or float(hot.get(key2, -1.0)) > game.clock:
		_go(g, c)
		return
	var sp: Vector2 = sites[key2]["p"]
	if st == "ride":
		var wp = g.get("wp", Vector2.INF)
		if wp != Vector2.INF and c.distance_to(wp) < 250.0:
			g["wp"] = Vector2.INF
			wp = Vector2.INF
		if c.distance_to(sp) < ARRIVE_R:
			_state(g, "strike")
			g["dry_t"] = 0.0
			g["strikes"] = int(g["strikes"]) + 1
			stats["strikes"] += 1
			say("group %d strikes at %s" % [int(g["id"]), _site_name(key2)])
			st = "strike"
		else:
			_move_all(units, wp if wp != Vector2.INF else sp, 50.0)
			return
	# strike: each rider shoots the worker it can get, the slow defenders stepped away from
	var foes: Array = []
	for o in game.units_near(c, DANGER_R):
		if game.hostile(o.team, ai.team) and AIHarass.is_defender(o) and AIHarass.is_slow(o, units):
			foes.append(o)
	var any := false
	# (FOCUS: every rider in reach shoots the same worker: three muskets kill a grub or a Winder in one volley)
	var w0 = g.get("tgt")
	if not (w0 is Unit) or not is_instance_valid(w0) or w0.dead or not game.is_visible_to(ai.team, w0.position) or w0.position.distance_to(c) > PREY_R * Defs.TILE:
		w0 = prey(units[0])
		g["tgt"] = w0
	var stand := _stand(key2, sp)
	for u in units:
		if u.dead or u.order == "mount" or u.order == "dismount":
			any = true
			continue
		if not foes.is_empty() and ai.hz().kite_from(u, foes, sp):
			any = true
			continue
		var w: Unit = w0 if w0 is Unit and is_instance_valid(w0) and w0.position.distance_to(u.position) < PREY_R * Defs.TILE else prey(u)
		if w != null:
			any = true
			if u.order not in ["attack", "d_attack"] or u.order_target != w:
				u.cmd_attack(w)
		elif AIHarass.is_static(u.target) or (u.position.distance_to(stand) > 120.0 and (u.order != "move" or u.order_point.distance_to(stand) > 120.0)):
			u.cmd_move(stand + Vector2(randf_range(-50, 50), randf_range(-50, 50)))     # (never at a rooted creature or a building)
	if not any:
		g["dry_t"] = float(g["dry_t"]) + _dt
	else:
		g["dry_t"] = 0.0
	if float(g["dry_t"]) >= STRIKE_DRY or game.clock - float(g["t_state"]) > STRIKE_MAX:
		if sites[key2]["guess"] or float(g["dry_t"]) >= STRIKE_DRY:
			hot[key2] = game.clock + (EMPTY_FOR if int(sites[key2]["workers"]) == 0 else HOT_FOR * 0.5)
		_go(g, c)


## On to the next site (or home with none).
func _go(g: Dictionary, c: Vector2) -> void:
	var key := pick_site(c, g)
	if key == "":
		if String(g["state"]) != "home":
			say("group %d finds no site worth it: home" % int(g["id"]))
			_state(g, "home")
			_form_after = game.clock + NO_SITE_WAIT
		return
	g["site"] = key
	var p: Vector2 = sites[key]["p"]
	g["wp"] = _waypoint(c, p)
	_state(g, "ride")
	say("group %d rides for %s%s" % [int(g["id"]), _site_name(key), " (round the side)" if g["wp"] != Vector2.INF else ""])
	_move_all(g["units"], g["wp"] if g["wp"] != Vector2.INF else p, 50.0)


func _site_name(key: String) -> String:
	if not sites.has(key):
		return "a site"
	var s: Dictionary = sites[key]
	var k := String(s["kind"])
	var nm := "a likely expansion" if k == "guess" else (String(Defs.UNITS[k]["name"]) if Defs.UNITS.has(k) else (String(Defs.BUILDINGS[k]["name"]) if Defs.BUILDINGS.has(k) else k))
	var p: Vector2 = s["p"]
	return "%s at %d,%d" % [nm, int(p.x / Defs.TILE), int(p.y / Defs.TILE)]


## How many Dragoons the plan wants out (the groups' riders): none before the Mill and the Breeder stand, then a group
## once the line has `musk_min` Musketeers, one more group every `per` labourers over `from`, MAX_GROUPS at most.
static func want(labs: int, musk: int, musk_min: int, from: int, per: int) -> int:
	if musk < musk_min:
		return 0
	var n := 1 + maxi(0, (labs - from) / maxi(1, per))
	return GROUP * mini(MAX_GROUPS, n)


## The worker this rider shoots (AIHarass.pick_prey, for a Dragoon: in the saddle he "can't hit", he gets off to): the
## nearest prey it can see within PREY_R tiles, the ones in reach of an armed defender counted farther, the one it is
## after kept unless another is clearly better.
const PREY_R := 11.0
func prey(u: Unit) -> Unit:
	var best: Unit = null
	var bs := INF
	var near: Array = game.units_near(u.position, PREY_R * Defs.TILE + 120.0)
	var biters: Array = near.filter(func(o: Unit) -> bool:
		return game.hostile(o.team, ai.team) and AIHarass.is_defender(o) and o.can_hit(u))
	for o in near:
		if not game.hostile(o.team, ai.team) or not AIHarass.is_prey(o) or o.is_air() or o.untouchable() or not game.is_visible_to(ai.team, o.position):
			continue
		var s: float = o.position.distance_to(u.position)
		if s > PREY_R * Defs.TILE:
			continue
		for b in biters:
			if b.position.distance_to(o.position) <= float(b.d["range"]) + b.radius + 60.0:
				s += 400.0
		if o == u.order_target:
			s -= 90.0
		if s < bs:
			bs = s
			best = o
	return best


## Where a group waits at a site with nothing in sight: on the workers' path, 5 tiles from the site toward what they haul to
## (a Rootmaw's grubs walk to the Mother; a press's or farm's hands to their hall), else at the site.
func _stand(key: String, sp: Vector2) -> Vector2:
	var s: Dictionary = sites.get(key, {})
	var foe: int = ai._foe()
	if foe < 0 or s.is_empty():
		return sp
	var to := Vector2.INF
	if String(s["kind"]) == BroodNew.MAW:
		var q = BroodNew.queen(game, foe)
		if q != null:
			to = q.position
	else:
		var bd := INF
		for b in game.buildings:
			if b.team == foe and not b.dead and not b.ghost and b.kind == game.faction_hall(foe) and b.center().distance_to(sp) < bd and b.center().distance_to(sp) > 100.0:
				bd = b.center().distance_to(sp)
				to = b.center()
	# (the workers seen lately near the site: where they walk; else 5 tiles toward what they haul to)
	var best := Vector2.INF
	var bd := INF
	for h in hands:
		var hp: Vector2 = h[1]
		var d := hp.distance_to(sp)
		if d < 600.0 and d > 60.0 and game.clock - float(h[0]) < 40.0 and d < bd and (to == Vector2.INF or hp.distance_to(to) > 500.0):
			bd = d
			best = hp
	if best != Vector2.INF:
		return best
	if to == Vector2.INF or to.distance_to(sp) < 6.0 * Defs.TILE:
		return sp
	return sp + (to - sp).normalized() * minf(10.0 * Defs.TILE, to.distance_to(sp) * 0.4) * (0.5 if int(game.clock / 8.0) % 2 == 0 else 1.0)


## Every physics tick (AICrown._tick_ai): a rider on foot who picked a structure by himself (a Musketeer standing idle
## fires at what is near: a rooted Mound Turtle, a building) is put back on a worker, or sent to the group's spot; one
## on foot while the group leaves gets back on.
func micro() -> void:
	for g in groups:
		var st := String(g["state"])
		if st == "gather":
			continue
		for u in g["units"]:
			if not is_instance_valid(u) or u.dead or u.kind == "dragoon" or u.order == "mount" or u.order == "dismount":
				continue
			if st == "leave":
				if u.order != "move":
					u.cmd_move(g["flee"])         # (on his horse if it is near: Unit._try_remount)
				if u.kind != "dragoon" and u.order == "move" and u.steed != null and is_instance_valid(u.steed) and not u.steed.dead \
						and u.steed.position.distance_to(u.position) < 12.0 * Defs.TILE and Unit.horse_free_for(u.steed, u):
					u.cmd_mount(u.steed, {"o": "move", "p": g["flee"]})     # (his horse wandered off: he runs to it)
				continue
			if not AIHarass.is_static(u.target) and not AIHarass.is_static(u.order_target):
				continue
			if st != "strike":
				u.cmd_move(_home() if st == "home" else sites.get(String(g["site"]), {}).get("p", _home()))
				continue
			var w = g.get("tgt")
			if not (w is Unit) or not is_instance_valid(w) or w.dead or w.position.distance_to(u.position) > PREY_R * Defs.TILE:
				w = prey(u)
			if w != null:
				u.cmd_attack(w)
			elif sites.has(String(g["site"])):
				u.cmd_move(_stand(String(g["site"]), sites[String(g["site"])]["p"]))


## May a gathered group set out? Against the Brood (its Raptor packs stay round its Rootmaws: round A, a01-a03, every
## site had a pack within seconds) it goes when the Brood's army is out on our side of the map (THE COUNTER-RAID: the
## doctrine's line holds the high ground while the riders hit the grubs it left), or after BROOD_WAIT s at home.
func _may_go(g: Dictionary) -> bool:
	var foe: int = ai._foe()
	if foe < 0 or game.faction_of(foe) != "brood":
		return true
	if ai.ch.foe_near() >= OUT_V:
		if not g.get("counter", false):
			g["counter"] = true
			say("group %d goes while the enemy's army is on our side (a counter-raid)" % int(g["id"]))
		return true
	return game.clock - float(g["t_state"]) > BROOD_WAIT
