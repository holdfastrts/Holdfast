extends RefCounted
## CW-BUILDS-C: THE OWL RAIDS (the owner, 2026-11-03: "do it all"; docs/clockwork_builds_c.md). A plan of the Clockwork's
## own computer (scripts/ai_clockwork.gd, AIClockwork) that goes to THE AIR: a Light Works (the Escapement needs it), the
## Mainspring on its big ring, the Escapement, TWO Clock Aviaries (one researches TICKING OWL while the other makes the
## Swifts), the Swifts MORPHED into Ticking Owls, then the OWL RAIDS:
##  - the FLOCK (the Owls) flies to the enemy's economy that our side has seen (a Farm, its Powder Mill, a Town Hall going
##    up, its workers in the field; the Brood's grubs and rooted creatures), on a line AWAY from the guns that can hit
##    flyers (Musketeers, Dragoons, the canister; Hatchlings, Pterodactyls, Challengers...) seen there lately;
##  - the Owls swoop on workers in reach and bomb the soft buildings; an anti-air unit that comes alone, weaker than the
##    flock, is swooped on first (the Owls can beat a few Musketeers); more than that: they fly back;
##  - a construct runs down off its gear field (Defs.WIND_DECAY: empty in about 80 s), so the flock flies home to be wound
##    (0.3 a second on the gear ground) and mended, then out again; it turns back when its wind is only just enough for
##    the way home;
##  - while the base is attacked by enemies that cannot hit flyers (Raptors, Horsemen, Clock Soldiers...) the Owls defend
##    it: those cannot touch them;
##  - a SWIFT (one, or more against enemy flyers) scouts ahead of the flock and over the enemy's main for its economy and
##    its guns, keeping out of their reach; it pecks enemy flyers that come at the Owls.
## After the opening the module keeps the flock topped up (a Swift trained and morphed at home, from what the bank can
## spare: the shared computer plays the economy and the ground army on the plan's STRATEGIES row).
## Self-contained (the parallel jobs cw-builds-a and -b add their plans to scripts/ai_clockwork.gd): AIClockwork only reads
## PLANS here, calls step() for the steps it does not know, tick() every army think, and has() for its units.
## Design rules (docs/design_principles.md): 1, telegraph and counterplay: the Owls are slow (56) and every anti-air unit
## answers them; the computer sees only what its side sees and knows only where the enemy started; 2, anti-snowball: the
## economy keeps growing behind the flock (Winders to 22 in the opening, a second Clocktower). No unit, building or research
## number is changed here.

## THE PLAN (read by AIClockwork as its PLANS are):
##  workers0     Winders at the start
##  flock        Owls the raid wants before it first goes out; flock_keep: topped up to this after the opening
##  scouts       Swifts kept as Swifts (the scout; more against enemy flyers)
## Steps of its own (step()): "morph N" (N Owls morphed from Swifts, safe at home), "owl_raid" (the raid starts).
const PLANS := {
	"owls": {
		"workers0": 14, "flock": 2, "flock_keep": 6, "scouts": 1, "cranks": 2,
		"steps": [
			"7 cog_press",
			"8 movement_works",
			"9 mainspring:big",
			"crew mainspring 6",
			"11 regulator",
			"escapement",
			"workers 18",
			"cuckoo_house",
			"clock_soldier 2",
			"research owl_morph",
			"cuckoo_house",
			"18 regulator",
			"cuckoo 4",
			"morph 2",
			"owl_raid",
			"workers 22",
			"clocktower",
			"end",
		],
		# against the Brood (round A: its Hard computer floods the base with Raptors from 5:00, which cannot hit flyers):
		# a Ratchet Turret and a third Clock Soldier at home before the research, a third Owl before the raid
		"steps_brood": [
			"7 cog_press",
			"8 movement_works",
			"9 mainspring:big",
			"crew mainspring 6",
			"11 regulator",
			"escapement",
			"workers 18",
			"cuckoo_house",
			"clock_soldier 3",
			"ratchet_turret",
			"research owl_morph",
			"cuckoo_house",
			"18 regulator",
			"cuckoo 4",
			"morph 3",
			"owl_raid",
			"workers 22",
			"clocktower",
			"end",
		],
	},
}

const FLEE_K := 0.75            # anti-air seen by the flock worth more than this share of it: the flock flies back
const FIGHT_K := 0.6           # anti-air near worth at most this share of the flock: the Owls swoop on it first
const AA_MEMORY := 40.0         # s an anti-air unit's last seen spot counts as danger
const DANGER_R := 300.0         # px round a target where anti-air counts against it
const STRIKE_R := 260.0         # px round the target point the Owls look for prey
const BACK_HP := 0.45           # the flock's average health share under this: back home
const GO_WIND := 0.9            # out again once every Owl is wound this far
const GO_HP := 0.7              # ... and mended this far (on average)
const WIND_SPARE := 0.12        # wind kept over what the way home takes
const MAX_OUT := 75.0           # s out at most in one go
const BUILD_END := 450.0        # the opening build is over by this clock whatever is left of it
const BIG_ATTACK := 150.0       # value of armed enemies at the base that calls the flock back from anywhere
const SORTIE_MIN := 3           # Owls a sortie wants (2 against an enemy with no anti-air seen near the target)

var ai = null
var game: Game = null
var team := 0
var on := false                 # this is the plan that runs (only the owl plan's computer claims its flyers)
var flock: Array = []           # the Owls
var joining: Array = []         # new Owls on their way to the flock's resting place
var _joined: Dictionary = {}
var swifts: Array = []          # the Swifts (scouts and morphs to be)
var launched := false
var phase := "home"             # "home" (wound and mended at home), "out", "strike", "back", "defend"
var since := 0.0
var target_pt := Vector2.INF
var target_b = null             # the building aimed at (a Building), or null
var foe := -1
var vs_brood := false
var _aa: Dictionary = {}        # enemy anti-air unit -> [position, clock] last seen
var _prey_b: Dictionary = {}    # enemy economy building -> position (seen)
var _prey_w: Dictionary = {}    # enemy worker -> [position, clock] last seen
var _tried: Dictionary = {}     # target key -> clock it was given up (driven off)
var _scout_i := 0
var _scout_pts: Array = []
var _queued_morph := 0
var sorties := 0
var first_owl_t := -1.0         # (the tools read these)
var first_out_t := -1.0
var first_strike_t := -1.0
var kill_log: Array = []        # [clock, kind, value] of what the Owls finished off
var _seen_dead: Dictionary = {}
var _heat: Dictionary = {}       # 256 px square -> clock an armed enemy was last seen in it
var _dbg_t := -1


func _init(a) -> void:
	ai = a
	game = a.game
	team = a.team
	on = PLANS.has(a.strategy)
	foe = -1
	# (the written build against the Brood, unless a coach set the steps)
	if on and not (a.over as Dictionary).has("steps") and PLANS[a.strategy].has("steps_brood"):
		var f: int = a._foe()
		if f >= 0 and game.faction_of(f) == "brood":
			a.steps = (PLANS[a.strategy]["steps_brood"] as Array).duplicate()
			a.done.resize(a.steps.size())
			a.done.fill(false)
			vs_brood = true


func has(u: Unit) -> bool:
	return on and (flock.has(u) or joining.has(u) or swifts.has(u) or cranks.has(u))


func say(s: String) -> void:
	ai.note(s)


## The plan's own steps; {} for any other (AIClockwork reads it as its own then).
func step(_i: int, parts: Array) -> Dictionary:
	if not on:
		return {}
	match String(parts[0]):
		"morph":
			return _do_morph(int(parts[1]))
		"owl_raid":
			if flock.size() >= int(ai.plan.get("flock", 3)):
				launched = true
				_phase("home")
				say("owl raid: the flock is ready (%d Ticking Owls, %d Swifts) at %d supply" % [flock.size(), swifts.size(), game.supply_used(team)])
				return {"st": "done"}
			return {"st": "wait"}
	return {}


## "morph N": N Owls in all (the ones flying and turning count), morphed one by one from the Swifts at home, keeping
## the scouts as Swifts once there are more than N.
func _do_morph(n: int) -> Dictionary:
	_refresh()
	var turning := swifts.filter(func(u: Unit) -> bool: return u.owl_t >= 0.0).size()
	if flock.size() + turning >= n:
		return {"st": "done"} if flock.size() >= n or turning > 0 and flock.size() + turning >= n else {"st": "wait"}
	if not game.has_tech(team, "owl_morph"):
		return {"st": "wait", "cost": 0, "t": 0.0}
	var m: Dictionary = Defs.OWL_MORPH
	var cost := int(m["cost"])
	var tc := float(m["tension"])
	var cand := _morphable()
	if cand.is_empty():
		return {"st": "wait", "cost": 0, "t": 0.0}
	if ai._free_t() < tc:
		return ai._wait_t(cost, tc)
	if ai._free() < cost:
		return {"st": "money", "cost": cost, "t": tc}
	if CwAir.morph_problem(cand[0]) != "":
		return {"st": "wait", "cost": cost, "t": tc}
	CwAir.start_morph(cand[0])
	say("a Swift turns into a Ticking Owl (%d of %d)" % [flock.size() + turning + 1, n])
	return {"st": "done"} if flock.size() + turning + 1 >= n else {"st": "wait", "cost": 0, "t": 0.0}


## Swifts that may be morphed now: not the scout(s) when there are others, at home, nothing armed near.
func _morphable() -> Array:
	var keep := _scouts_wanted()
	var free: Array = swifts.filter(func(u: Unit) -> bool: return u.owl_t < 0.0 and u.kind == Defs.CUCKOO)
	if free.size() <= 0:
		return []
	# (the scouts are the ones farthest out; the morphs the nearest home)
	var home := _home()
	free.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(home) < b.position.distance_to(home))
	var all_sw := free.size()
	var out: Array = []
	for u in free:
		if all_sw - out.size() <= keep and (launched or not ai.bo_on or flock.size() > 0):
			break
		if _armed_near(u.position, 10.0 * Defs.TILE):
			continue
		if u.position.distance_to(home) > 900.0:
			continue
		out.append(u)
	return out


func _scouts_wanted() -> int:
	var n := int(ai.plan.get("scouts", 1))
	var fa: int = ai._foe_air()
	if fa > 0:
		n = maxi(n, mini(4, fa))
	return n


func _armed_near(p: Vector2, r: float) -> bool:
	for o in game.units_near(p, r):
		if not o.dead and not o.off_field and game.hostile(o.team, team) and not o.is_worker() and o.has_attack():
			return true
	return false


# ------------------------------------------------------------------ the think

func _refresh() -> void:
	flock.clear()
	swifts.clear()
	joining.clear()
	for u in game.army(team):
		if u.kind == Defs.OWL:
			# (a new Owl joins the flock where it rests, not out on a sortie: round A, Frostmere, a fresh Owl at home
			# counted in a sortie from the post, 100 tiles away, and turned it back at once)
			if not _joined.has(u):
				if not launched or (phase in ["home", "defend"] and u.position.distance_to(_rest()) < 200.0):
					_joined[u] = true
			if _joined.has(u):
				flock.append(u)
			else:
				joining.append(u)
			if first_owl_t < 0.0:
				first_owl_t = game.clock
				say("the first Ticking Owl flies")
		elif u.kind == Defs.CUCKOO and not (ai.raid != null and ai.raid.has(u)):
			swifts.append(u)


func _phase(p: String) -> void:
	if phase != p:
		phase = p
		since = game.clock


func _home() -> Vector2:
	var h: Array = ai._halls()
	return (h[0] as Building).center() if not h.is_empty() else game.center_of_team(team)


func _foe_hall() -> Vector2:
	return (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE


func tick() -> void:
	if not on or game.over:
		return
	if foe < 0:
		foe = ai._foe()
		if foe < 0:
			return
	_refresh()
	_remember()
	_count_kills()
	# (a written build must never hold the bank for good: round A, Frostmere, its Swifts lost, it waited for one
	# with 3,900 cogs in the bank; the shared computer plays on by BUILD_END at the latest)
	if ai.bo_on and game.clock > BUILD_END:
		ai._end_build("the clock (%d:%02d)" % [int(BUILD_END) / 60, int(BUILD_END) % 60])
	if not ai.bo_on:
		_top_up()
	_swift_tick()
	_crank_tick()
	_join_tick()
	if OS.get_cmdline_user_args().has("owldebug") and int(game.clock) % 10 == 0 and int(game.clock) != _dbg_t:
		_dbg_t = int(game.clock)
		print("ODBG %d phase %s rest %s post %s cranks %s flock %s" % [_dbg_t, phase, str(_rest() != _home()), str(Vector2i(post / Defs.TILE)) if post != Vector2.INF else "-",
			str(cranks.map(func(w): return [int(w.position.distance_to(post)) if post != Vector2.INF else -1, w.order])),
			str(flock.map(func(u): return [int(u.position.distance_to(post)) if post != Vector2.INF else -1, snappedf(u.wind, 0.01), int(u.hp), u.order]))])
		var ords := {}
		for w in game.workers(team):
			var k := "%s/%s" % [w.order, (w.home_mine.kind if w.home_mine != null and is_instance_valid(w.home_mine) else "-")]
			ords[k] = int(ords.get(k, 0)) + 1
		print("ODBG workers %s gold %d" % [str(ords), ai._gold()])
	if flock.is_empty():
		return
	# home defence: enemies at home that cannot hit flyers are the Owls' (they cannot touch them)
	var thr: Vector2 = ai._threat()
	# (round A, Kestrel Rise and Greenhold against the Brood: the flock went raiding while Raptors ate the base: a real
	# attack on the base calls it back from anywhere)
	var big: bool = thr != Vector2.INF and _attack_value(thr) >= BIG_ATTACK
	if thr != Vector2.INF and (phase in ["home", "defend"] or big) and _aa_near(thr, 360.0, 0.0) <= _value(flock) * FIGHT_K \
			and (big or _rest() == _home() or _centre(flock).distance_to(thr) < 900.0 or not launched):
		_defend(thr)
		return
	if phase == "defend":
		_phase("home")
	if not launched:
		_hold_home()
		return
	match phase:
		"home":
			_at_home()
		"out", "strike":
			_out()
		"back":
			_back()


## What our side sees of the enemy now: its anti-air (where it is), its economy buildings and its workers.
func _remember() -> void:
	if Engine.get_physics_frames() % 3 != 0 and not _aa.is_empty():
		pass
	for o in game.units:
		if o.dead or o.off_field or not game.hostile(o.team, team):
			continue
		if not game.is_visible_to(team, o.position):
			continue
		if not o.is_worker() and not o.is_air():
			_heat[Vector2i(int(o.position.x / 256.0), int(o.position.y / 256.0))] = game.clock
		if o.is_worker():
			_prey_w[o] = [o.position, game.clock]
		elif _hits_air(o):
			_aa[o] = [o.position, game.clock]
		elif o.kind == "rootmaw" or o.kind == "egg":
			_prey_w[o] = [o.position, game.clock]
	for k in _aa.keys():
		if not is_instance_valid(k) or k.dead or game.clock - float(_aa[k][1]) > AA_MEMORY * 2.0:
			_aa.erase(k)
	for k in _prey_w.keys():
		if not is_instance_valid(k) or k.dead or game.clock - float(_prey_w[k][1]) > 60.0:
			_prey_w.erase(k)
	for b in game.buildings:
		if b.dead or not game.hostile(b.team, team) or _prey_b.has(b):
			continue
		if b.kind in ["farm", "powder_mill", "town_hall", "horse_breeder", "cottage", "church", "barracks", "foundry", "armoury"] \
				and game.is_visible_to(team, b.center()):
			_prey_b[b] = b.center()
	for b in _prey_b.keys():
		if not is_instance_valid(b) or b.dead:
			_prey_b.erase(b)


## Can this enemy hit a flyer (now or soon: a Musketeer at the bayonet still counts)?
func _hits_air(o: Unit) -> bool:
	return bool(o.d.get("anti_air", false)) or o.kind == "cannon"


## The anti-air near p by value: seen now within r, or seen there in the last AA_MEMORY s (memory weighs `mem`).
func _aa_near(p: Vector2, r: float, mem := 1.0) -> float:
	var v := 0.0
	for k in _aa:
		if not is_instance_valid(k) or k.dead:
			continue
		var seen_now: bool = game.is_visible_to(team, k.position)
		if seen_now:
			if k.position.distance_to(p) < r:
				v += ai._unit_value(k)
		elif mem > 0.0 and game.clock - float(_aa[k][1]) < AA_MEMORY and (_aa[k][0] as Vector2).distance_to(p) < r:
			v += ai._unit_value(k) * mem
	return v


func _value(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += ai._unit_value(u)
	return v


func _centre(list: Array) -> Vector2:
	var c := Vector2.ZERO
	for u in list:
		c += u.position
	return c / maxf(1.0, list.size())


# ------------------------------------------------------------------ the flock's phases

## Before the raid starts: over our base, on the side toward the enemy (they cover the base from enemy flyers' prey).
func _hold_home() -> void:
	var spot := _home().lerp(_foe_hall(), 0.08)
	for u in flock:
		if u.target == null and u.position.distance_to(spot) > 120.0 and (u.order != "move" or u.order_point.distance_to(spot) > 60.0):
			u.cmd_move(spot + Vector2(randf_range(-40, 40), randf_range(-40, 40)))


func _defend(thr: Vector2) -> void:
	if phase != "defend":
		say("the Owls defend the base (enemies by it that cannot hit flyers)")
	_phase("defend")
	for u in flock:
		if u.target != null and is_instance_valid(u.target) and not u.target.dead and u.target is Unit and u.target.position.distance_to(thr) < 400.0:
			continue
		var best: Unit = null
		var bd := INF
		for o in game.units_near(thr, 360.0):
			if o.dead or o.off_field or not game.hostile(o.team, team) or not u.can_hit(o) or not game.is_visible_to(team, o.position):
				continue
			var dd: float = o.position.distance_to(u.position) + (0.0 if ai._armed(o) else 200.0)
			if dd < bd:
				bd = dd
				best = o
		if best != null:
			u.cmd_attack(best)
		else:
			u.cmd_move(thr, true)


## At rest (the crank post, else home): wound and mended, then out to the next target.
func _at_home() -> void:
	var home := _rest()
	var at_post := home != _home()
	var ready := flock.size() >= SORTIE_MIN or (flock.size() >= 2 and game.clock - since > 45.0)
	if vs_brood and _aa.is_empty():
		ready = flock.size() >= 2
	var hp := 0.0
	for u in flock:
		hp += u.hp / u.max_hp
		if u.wind < GO_WIND:
			ready = false
		var there: bool = u.position.distance_to(home) < (90.0 if at_post else 500.0) and (at_post or game.in_field(team, u.position))
		if at_post and not _cranks_there() and not cranks.is_empty():
			# (the way out: the Owls fly over the cranks, who walk at their pace: anything that cannot hit flyers meets
			# the Owls first)
			var cc := _centre(cranks)
			if u.target != null and is_instance_valid(u.target) and not u.target.dead and u.target.position.distance_to(cc) > 360.0:
				u.cmd_move(cc)          # (no chasing a rider away from the cranks)
			if u.target == null or not is_instance_valid(u.target) or u.target.dead:
				var foe_u = _ground_foe_near(cc, 330.0, u)
				if foe_u != null:
					u.cmd_attack(foe_u)
				else:
					# (a little ahead of the cranks toward the post: a crank winding an Owl on the move follows it)
					var lead := cc + (post - cc).normalized() * minf(70.0, cc.distance_to(post))
					if u.position.distance_to(lead) > 40.0 and (u.order != "move" or u.order_point.distance_to(lead) > 30.0):
						u.cmd_move(lead + Vector2(randf_range(-16, 16), randf_range(-16, 16)))
			continue
		if not there:
			if u.order != "move" or u.order_point.distance_to(home) > 80.0:
				u.cmd_move(home + Vector2(randf_range(-30, 30), randf_range(-30, 30)) * (1.0 if at_post else 1.6))
	hp /= maxf(1.0, flock.size())
	if hp < GO_HP:
		ready = false
		if not at_post:
			_mend()
	if game.clock - since < 4.0:
		ready = false
	if at_post and not _cranks_there():
		ready = false
	if not ready:
		return
	if not _pick_target():
		return
	sorties += 1
	if first_out_t < 0.0:
		first_out_t = game.clock
	_phase("out")
	say("out: sortie %d of %d Owls to %s (anti-air seen by it %d)" % [sorties, flock.size(), _target_name(), int(_aa_near(target_pt, DANGER_R))])
	_fly_to(target_pt)


## Hurt Owls at home: a Winder mends them (the nearest free one; a Winder mends and winds Clockwork units).
func _mend() -> void:
	for u in flock:
		if u.hp >= u.max_hp * 0.95:
			continue
		var busy := false
		for w in game.workers(team):
			if w.order == "repair" and w.order_target == u:
				busy = true
				break
		if busy:
			continue
		var best: Unit = null
		var bd := INF
		for w in game.workers(team):
			if w.order == "build" or w.crate_site != null or w.carrying > 0 or ai._held_worker(w) or ai._escort.has(w) or (ai.scout != null and ai.scout.is_scout(w)):
				continue
			if w.order == "repair":
				continue
			if w.home_mine != null and w.home_mine.kind == "mainspring":
				continue
			var dd: float = w.position.distance_to(u.position)
			if dd < bd and dd < 700.0:
				bd = dd
				best = w
		if best != null and best.can_repair(u):
			best.cmd_repair(u)


func _target_name() -> String:
	if target_b != null and is_instance_valid(target_b):
		return "a %s" % String(target_b.d.get("name", target_b.kind))
	return "the workers seen at %d,%d" % [int(target_pt.x / Defs.TILE), int(target_pt.y / Defs.TILE)]


## The best target: a soft building or workers seen, worth the most for the least anti-air seen by it and the way there;
## none known: the enemy's start (the Swift will have looked). False when everything known is too well guarded.
func _pick_target() -> bool:
	var fv := _value(flock)
	var c := _centre(flock)
	var best_s := -INF
	var best_p := Vector2.INF
	var best_b = null
	var cands: Array = []
	for b in _prey_b:
		var w := 2.0
		match String(b.kind):
			"farm":
				w = 3.0
			"powder_mill":
				w = 4.0
			"town_hall":
				w = 5.0 if not b.built else 2.5
			"cottage":
				w = 1.5
			"horse_breeder":
				w = 3.0
			"barracks", "foundry", "armoury", "church":
				w = 1.2
		if not b.built:
			w += 1.5
		cands.append([_prey_b[b], w, b])
	# workers seen lately, grouped roughly (each worker adds to the spot it is near)
	var spots: Array = []
	for k in _prey_w:
		if game.clock - float(_prey_w[k][1]) > 45.0:
			continue
		var p: Vector2 = _prey_w[k][0]
		var put := false
		for s in spots:
			if (s[0] as Vector2).distance_to(p) < 200.0:
				s[1] = float(s[1]) + 1.0
				put = true
				break
		if not put:
			spots.append([p, 1.0])
	for s in spots:
		cands.append([s[0], float(s[1]) * 0.9, null])
	if cands.is_empty():
		cands.append([_foe_hall(), 1.0, null])
	for cd in cands:
		var p: Vector2 = cd[0]
		var key := "%d,%d" % [int(p.x / 160.0), int(p.y / 160.0)]
		var aa := _aa_near(p, DANGER_R)
		if aa > fv * FLEE_K:
			continue
		var path_aa := _path_aa(c, p)
		var s: float = float(cd[1]) * 10.0 - aa / maxf(1.0, fv) * 25.0 - path_aa / maxf(1.0, fv) * 12.0 - c.distance_to(p) / 300.0
		if game.clock - float(_tried.get(key, -999.0)) < 60.0:
			s -= 15.0
		# the wind: there, a while to strike, and home again
		var need: float = (c.distance_to(p) + p.distance_to(_rest())) / 50.0 * Defs.WIND_DECAY + 0.15
		if need > 0.92:
			continue          # (out of the Owls' reach from where they are wound)
		if s > best_s:
			best_s = s
			best_p = p
			best_b = cd[2]
	if best_p == Vector2.INF:
		if game.clock - since > 20.0 and int(game.clock) % 20 == 0:
			say("the flock waits: every target seen is guarded by anti-air")
		return false
	target_pt = best_p
	target_b = best_b
	return true


## Anti-air seen near the straight line from a to b (sampled).
func _path_aa(a: Vector2, b: Vector2) -> float:
	var v := 0.0
	var n := int(a.distance_to(b) / 250.0)
	for i in range(1, n):
		v = maxf(v, _aa_near(a.lerp(b, float(i) / float(n)), 230.0, 0.7))
	return v


## Fly to p, round the anti-air seen on the straight line (one waypoint to the side).
func _fly_to(p: Vector2) -> void:
	var c := _centre(flock)
	var to := p
	if _path_aa(c, p) > 0.0:
		var mid := c.lerp(p, 0.5)
		var side := (p - c).orthogonal().normalized()
		var a := mid + side * 450.0
		var b := mid - side * 450.0
		var wp := a if _aa_near(a, 300.0, 0.7) <= _aa_near(b, 300.0, 0.7) else b
		if _path_aa(c, wp) + _path_aa(wp, p) < _path_aa(c, p):
			to = wp
	for u in flock:
		u.cmd_move(to + Vector2(randf_range(-24, 24), randf_range(-24, 24)))


## Out and striking: on the way, at the target; back when the anti-air comes, the wind runs short, the flock is hurt or
## out too long.
func _out() -> void:
	var c := _centre(flock)
	var fv := _value(flock)
	var aa_now := _aa_near(c, 280.0, 0.0)
	var hp := 0.0
	var wind_low := false
	for u in flock:
		hp += u.hp / u.max_hp
		var need: float = u.position.distance_to(_rest()) / 46.0 * Defs.WIND_DECAY + WIND_SPARE
		if u.wind < need:
			wind_low = true
	hp /= maxf(1.0, flock.size())
	var why := ""
	if aa_now > fv * FLEE_K:
		why = "anti-air comes (%d against %d)" % [int(aa_now), int(fv)]
	elif hp < BACK_HP:
		why = "hurt"
	elif wind_low:
		why = "low on wind"
	elif game.clock - since > MAX_OUT:
		why = "out too long"
	if why != "":
		_go_back(why)
		return
	# on the way: when there, strike
	if phase == "out":
		if c.distance_to(target_pt) < 170.0 or _prey_in_reach(c, 200.0) != null:
			_phase("strike")
			if first_strike_t < 0.0:
				first_strike_t = game.clock
			say("strike: the Owls reach %s" % _target_name())
		else:
			# (a waypoint reached: on to the target)
			var lead: Unit = flock[0]
			if lead.order != "move" or lead.position.distance_to(lead.order_point) < 60.0:
				for u in flock:
					u.cmd_move(target_pt + Vector2(randf_range(-24, 24), randf_range(-24, 24)))
			return
	# striking: anti-air in reach and weak enough: swoop on it first; then workers in reach; then the building aimed at;
	# then anything soft by it; nothing: the next target if the wind allows, else home
	var aa_units: Array = []
	for o in game.units_near(c, 230.0):
		if not o.dead and not o.off_field and game.hostile(o.team, team) and _hits_air(o) and not o.is_air() and game.is_visible_to(team, o.position):
			aa_units.append(o)
	for u in flock:
		var cur = u.target if (u.target != null and is_instance_valid(u.target) and not u.target.dead) else null
		var pick = null
		if not aa_units.is_empty() and aa_now <= fv * FIGHT_K:
			aa_units.sort_custom(func(a: Unit, b: Unit) -> bool: return a.hp < b.hp)
			pick = aa_units[0]
		if pick == null:
			pick = _prey_in_reach(u.position, 150.0)
		if pick == null and target_b != null and is_instance_valid(target_b) and not target_b.dead:
			pick = target_b
		if pick == null:
			pick = _soft_near(target_pt, STRIKE_R)
		if pick == null:
			continue
		if cur == pick or (cur != null and cur is Unit and pick is Building):
			continue
		if u.can_hit(pick):
			u.cmd_attack(pick)
	var busy := flock.any(func(u: Unit) -> bool: return u.target != null and is_instance_valid(u.target) and not u.target.dead)
	if not busy and game.clock - since > 4.0:
		# done here: the next target, if the wind and the flock allow
		var keep_t := target_pt
		if _pick_target() and target_pt != keep_t:
			_phase("out")
			say("on: the Owls fly on to %s" % _target_name())
			_fly_to(target_pt)
		else:
			_go_back("nothing left in reach")


## A worker (or a Brood grub, a rooted creature) of the enemy within r, the nearest.
func _prey_in_reach(p: Vector2, r: float):
	var best = null
	var bd := INF
	for o in game.units_near(p, r):
		if o.dead or o.off_field or not game.hostile(o.team, team) or o.is_air() or not game.is_visible_to(team, o.position):
			continue
		if not (o.is_worker() or o.kind == "rootmaw" or o.kind == "egg"):
			continue
		var dd: float = o.position.distance_to(p)
		if dd < bd:
			bd = dd
			best = o
	return best


## A soft enemy building within r of p (the weakest first).
func _soft_near(p: Vector2, r: float):
	var best = null
	var bh := INF
	for b in game.buildings:
		if b.dead or not game.hostile(b.team, team) or b.center().distance_to(p) > r or b.kind in ["wall", "gate"]:
			continue
		if not game.is_visible_to(team, b.center()):
			continue
		if b.hp < bh:
			bh = b.hp
			best = b
	return best


func _go_back(why: String) -> void:
	var key := "%d,%d" % [int(target_pt.x / 160.0), int(target_pt.y / 160.0)]
	if why.begins_with("anti-air"):
		_tried[key] = game.clock
	var home := _rest()
	say("back: the Owls fly %s (%s)" % ["to the crank post" if home != _home() else "home", why])
	_phase("back")
	# (away from the anti-air on the way: the same detour)
	var c := _centre(flock)
	var to := home
	if _path_aa(c, home) > 0.0:
		var side := (home - c).orthogonal().normalized()
		var a := c.lerp(home, 0.4) + side * 400.0
		var b := c.lerp(home, 0.4) - side * 400.0
		to = a if _aa_near(a, 300.0, 0.7) <= _aa_near(b, 300.0, 0.7) else b
	for u in flock:
		u.cmd_move(to + Vector2(randf_range(-30, 30), randf_range(-30, 30)))


func _back() -> void:
	var home := _rest()
	var at_post := home != _home()
	var all_home := true
	for u in flock:
		if u.position.distance_to(home) > (120.0 if at_post else 420.0) or not (at_post or game.in_field(team, u.position)):
			all_home = false
			if u.order != "move" or u.position.distance_to(u.order_point) < 50.0:
				u.cmd_move(home + Vector2(randf_range(-50, 50), randf_range(-50, 50)))
	if all_home or game.clock - since > 60.0:
		_phase("home")


# ------------------------------------------------------------------ the Swifts

## The scout(s): ahead of the flock while it is out; else round the enemy's main and naturals, out of its anti-air's reach;
## low on wind or hurt: home. Swifts beyond the scouts wait at home (to be morphed).
func _swift_tick() -> void:
	var scouts := _scouts_wanted()
	var n := 0
	var home := _home()
	for s in swifts:
		if s.owl_t >= 0.0:
			continue
		n += 1
		if n > scouts and (ai.bo_on or flock.size() + 1 < int(ai.plan.get("flock_keep", 6))):
			# (waiting to be morphed: at home)
			if s.position.distance_to(home) > 250.0 and (s.order != "move" or s.order_point.distance_to(home) > 80.0):
				s.cmd_move(home)
			continue
		# enemy flyers near the flock or the base: peck them
		var fly = _enemy_flyer_near(_centre(flock) if not flock.is_empty() else home, 420.0)
		if fly != null and s.hp > s.max_hp * 0.35:
			if s.target != fly:
				s.cmd_attack(fly)
			continue
		var need: float = s.position.distance_to(home) / 100.0 * Defs.WIND_DECAY + 0.15
		if s.wind < need or s.hp < s.max_hp * 0.4:
			if s.order != "move" or s.order_point.distance_to(home) > 80.0:
				s.cmd_move(home)
			continue
		if s.order == "move" and s.order_point.distance_to(home) < 80.0 and s.position.distance_to(home) > 200.0 and s.wind < 0.85:
			continue          # (on its way home to be wound)
		var to: Vector2
		if launched and post != Vector2.INF and not _post_seen and game.clock - _post_new_t <= POST_LOOK:
			to = post
		elif launched and phase in ["out", "strike"] and target_pt != Vector2.INF:
			to = target_pt.lerp(_centre(flock), 0.3)
		else:
			to = _scout_point(s)
		# keep out of the anti-air's reach (190 + a margin), from what is seen and remembered
		for k in _aa:
			if not is_instance_valid(k) or k.dead or game.clock - float(_aa[k][1]) > AA_MEMORY:
				continue
			var gp: Vector2 = k.position if game.is_visible_to(team, k.position) else _aa[k][0]
			if gp.distance_to(to) < 250.0:
				to += (to - gp).normalized() * (255.0 - gp.distance_to(to))
		if s.position.distance_to(to) > 40.0 and (s.order != "move" or s.order_point.distance_to(to) > 40.0):
			s.cmd_move(to)


## A loop round the enemy's start, about 9 tiles out, the next point once the last is reached.
func _scout_point(s: Unit) -> Vector2:
	if _scout_pts.is_empty():
		var c := _foe_hall()
		var away := (_home() - c).normalized()
		for i in 8:
			_scout_pts.append(c + away.rotated(float(i) * TAU / 8.0) * 9.0 * Defs.TILE)
		# and the enemy's natural expansion, if known
		if game.expansions.size() > foe and game.expansions[foe] is Vector2i:
			_scout_pts.append((Vector2(game.expansions[foe]) + Vector2(2.5, 2.0)) * Defs.TILE)
	var p: Vector2 = _scout_pts[_scout_i % _scout_pts.size()]
	if s.position.distance_to(p) < 90.0:
		_scout_i += 1
		p = _scout_pts[_scout_i % _scout_pts.size()]
	return p


func _enemy_flyer_near(p: Vector2, r: float):
	for o in game.units_near(p, r):
		if not o.dead and not o.off_field and o.is_air() and game.hostile(o.team, team) and game.is_visible_to(team, o.position):
			return o
	return null


# ------------------------------------------------------------------ after the opening: the flock topped up

var _top_t := 0.0


func _top_up() -> void:
	if game.clock < _top_t:
		return
	_top_t = game.clock + 3.0
	var keep := int(ai.plan.get("flock_keep", 6))
	var turning := swifts.filter(func(u: Unit) -> bool: return u.owl_t >= 0.0).size()
	var plain := swifts.filter(func(u: Unit) -> bool: return u.owl_t < 0.0).size()
	var scouts := _scouts_wanted()
	var gold: int = ai._gold()
	var ten: float = game.tension(team)
	# morph a spare Swift (one at a time) while the bank can spare it
	if flock.size() + joining.size() + turning < keep and plain > scouts and turning == 0 and game.has_tech(team, "owl_morph") \
			and gold >= int(Defs.OWL_MORPH["cost"]) + 40 and ten >= float(Defs.OWL_MORPH["tension"]) + 20.0:
		var cand := _morphable()
		if not cand.is_empty() and CwAir.morph_problem(cand[0]) == "":
			CwAir.start_morph(cand[0])
			say("top-up: a Swift turns into a Ticking Owl (%d Owls)" % (flock.size() + 1))
			return
	# a Swift trained for it (or a lost scout replaced)
	var want_sw := scouts + maxi(0, keep - flock.size() - joining.size() - turning)
	if plain + turning < want_sw and gold >= int(Defs.UNITS[Defs.CUCKOO]["cost"]) + 60 and ten >= 40.0:
		for b in ai._mine(Defs.CW_AIR):
			if b.built and (b.queue as Array).is_empty() and game.can_train(b, Defs.CUCKOO) == "":
				if game.train(b, Defs.CUCKOO) == "":
					break


# ------------------------------------------------------------------ the measure (tools read kill_log)

## Enemies the Owls finished off (the last blow was an Owl's), by value: everything an Owl hit is watched until it dies
## or is hit by someone else.
func _count_kills() -> void:
	for o in game.units:
		if not o.dead and o.last_hit_by == Defs.OWL and o.last_hit_team == team and not _seen_dead.has(o) and game.hostile(o.team, team):
			_seen_dead[o] = [o.kind, int(float(o.d.get("cost", 0)) / maxf(1.0, float(o.d.get("spawn", 1)))), false]
	for b in game.buildings:
		if not b.dead and b.last_hit_by == Defs.OWL and b.last_hit_team == team and not _seen_dead.has(b) and game.hostile(b.team, team):
			_seen_dead[b] = [b.kind, int(b.d.get("cost", 0)), true]
	for k in _seen_dead.keys():
		var e: Array = _seen_dead[k]
		if not is_instance_valid(k) or k.dead:
			if not is_instance_valid(k) or k.last_hit_by == Defs.OWL:
				kill_log.append([game.clock, e[0], e[1]])
				if e[2]:
					say("the Owls destroy a %s" % String(e[0]))
			_seen_dead.erase(k)
		elif k.last_hit_by != Defs.OWL:
			_seen_dead.erase(k)


# ------------------------------------------------------------------ the crank post

## THE CRANK POST: a construct off its gear field runs down in about 80 s and the Owl flies 56 px a second, so from home
## the flock reaches the enemy's main with no wind left to come back (Greenhold: the first sortie turned back half way).
## Two Winders (the CRANKS) walk to a post about POST_NEAR px from the enemy's start, on ground our side can walk, away
## from what of the enemy we have seen; the Owls go out from there and come back there to be wound (0.15 a second each
## Winder) and mended (as the Springer raid's cranks at its cliff foot). Enemies at the post that cannot hit flyers: the Owls
## see them off; anti-air or more: the cranks run home, and the Owls rest at home.
const POST_NEAR := 720.0         # px from the enemy's start (the Owl: 13 s there, 13 s back, about 35 s of striking)
const POST_DANGER := 380.0
const CRANKS_LOST_MAX := 2       # cranks lost: the post is given up for POST_REST s
const POST_REST := 150.0
var cranks_lost := 0
var _post_seen := false          # the scout has looked at the post (the cranks walk out only then, or after POST_LOOK s)
var _post_new_t := -999.0
const POST_LOOK := 25.0
var _lost_at: Dictionary = {}    # (256 px squares where cranks were lost: no post there again)
var cranks: Array = []
var post := Vector2.INF
var _post_t := -999.0
var _post_bad_t := -999.0


func _rest() -> Vector2:
	if post == Vector2.INF or cranks.is_empty() or game.clock - _post_bad_t < 40.0:
		return _home()
	return post


## The cranks are at the post (winding is there).
## The cranks may walk to the post: the scout has looked at it and seen it clear (or no scout, or POST_LOOK s gone).
func _post_cleared() -> bool:
	if _post_seen:
		return true
	if game.clock - _post_new_t > POST_LOOK:
		return true
	for s0 in swifts:
		if s0.owl_t < 0.0 and s0.position.distance_to(post) < 150.0:
			_post_seen = true
			return true
	return swifts.is_empty()


func _cranks_there() -> bool:
	for w in cranks:
		if w.position.distance_to(post) < 140.0:
			return true
	return false


func _pick_cranks() -> void:
	var alive: Array = cranks.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	if alive.size() < cranks.size():
		cranks_lost += cranks.size() - alive.size()
		if post != Vector2.INF:
			_lost_at[Vector2i(int(post.x / 256.0), int(post.y / 256.0))] = true
		say("a crank is lost at the post (%d in all)" % cranks_lost)
		_post_t = -999.0          # (a new post at once)
		if cranks_lost >= CRANKS_LOST_MAX:
			_post_bad_t = game.clock + POST_REST - 40.0
			cranks_lost = 0
			say("too many cranks lost: the Owls rest at home for %d s" % int(POST_REST))
	cranks = alive
	if game.clock - _post_bad_t < 40.0:
		return
	var want := int(ai.plan.get("cranks", 2))
	if cranks.size() >= want:
		return
	var home := _home()
	var labs: Array = game.workers(team).filter(func(u: Unit) -> bool: return not cranks.has(u) and u.order != "build" and u.crate_site == null \
		and not ai._escort.has(u) and not (ai.scout != null and ai.scout.is_scout(u)) and not (ai.raid != null and ai.raid.has(u)) \
		and (u.home_mine == null or u.home_mine.kind != "mainspring"))
	labs.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(home) < b.position.distance_to(home))
	for u in labs.slice(0, want - cranks.size()):
		cranks.append(u)


func _pick_post() -> void:
	var home := _home()
	var fh := _foe_hall()
	var flood: PackedByteArray = ai.raid._walkable() if ai.raid != null else PackedByteArray()
	var hc: Vector2i = game.cell_of(fh)
	var lv := int(game.height[game.idx(hc)]) if game.in_map(hc) else 0
	var ramps: Array = ai.raid._ramp_tops(hc, lv) if ai.raid != null else []
	var to_home := (home - fh).normalized()
	var best := Vector2.INF
	var bs := -INF
	for ai_ in range(-11, 12):
		var dir := to_home.rotated(float(ai_) * deg_to_rad(10.0))
		for ri in range(0, 6):
			var r := POST_NEAR + float(ri) * 80.0
			var p := fh + dir * r
			if p.x < 3.0 * Defs.TILE or p.y < 3.0 * Defs.TILE or p.x > float(game.W - 3) * Defs.TILE or p.y > float(game.H - 3) * Defs.TILE:
				continue
			var c: Vector2i = game.cell_of(p)
			if not game.in_map(c) or not ai.raid._open(c):
				continue
			if flood.size() > 0 and flood[game.idx(c)] == 0:
				continue
			if lv > 0 and int(game.height[game.idx(c)]) >= lv:
				continue          # (not on the enemy's plateau)
			var sc := -absf(r - POST_NEAR) / 120.0 - absf(float(ai_)) * 0.08
			for rp in ramps:
				var dr: float = (rp as Vector2).distance_to(p)
				if dr < 600.0:
					sc -= (600.0 - dr) / 60.0
				# (off the way its army walks out: the line from its ramp toward our base)
				var seg := Geometry2D.get_closest_point_to_segment(p, rp, home)
				var ds: float = seg.distance_to(p)
				if ds < 450.0:
					sc -= (450.0 - ds) / 90.0
			for bd in game.buildings:
				if not bd.dead and game.hostile(bd.team, team) and bd.center().distance_to(p) < 450.0 and game.is_visible_to(team, bd.center()) or (_prey_b.has(bd) and (_prey_b[bd] as Vector2).distance_to(p) < 450.0):
					sc -= 6.0
			for k in _aa:
				if is_instance_valid(k) and game.clock - float(_aa[k][1]) < 90.0 and (_aa[k][0] as Vector2).distance_to(p) < 500.0:
					sc -= 3.0
			# (not at its natural expansions: the map's free hall spots near its start; its army goes there)
			for e in game.expansions:
				if e is Vector2i:
					var ec := (Vector2(e) + Vector2(2.5, 2.0)) * Defs.TILE
					if ec.distance_to(fh) < 1500.0 and ec.distance_to(p) < 560.0:
						sc -= 10.0
			var hq := Vector2i(int(p.x / 256.0), int(p.y / 256.0))
			for hy in range(-2, 3):
				for hx in range(-2, 3):
					var ht := float(_heat.get(hq + Vector2i(hx, hy), -999.0))
					if game.clock - ht < 120.0:
						sc -= 5.0 if absi(hx) <= 1 and absi(hy) <= 1 else 2.0
			if _lost_at.has(Vector2i(int(p.x / 256.0), int(p.y / 256.0))):
				sc -= 12.0
			if sc > bs:
				bs = sc
				best = p
	if OS.get_cmdline_user_args().has("owldebug"):
		print("ODBG post map %dx%d starts %s expansions %s ramps %s best %s" % [game.W, game.H, str(game.starts), str(game.expansions), str(ramps.slice(0, 4).map(func(v): return Vector2i(v / Defs.TILE))), str(Vector2i(best / Defs.TILE)) if best != Vector2.INF else "-"])
	if best != Vector2.INF and (post == Vector2.INF or best.distance_to(post) > 64.0):
		post = best
		_post_seen = false
		_post_new_t = game.clock
		say("the crank post: %d,%d (%d tiles from the enemy's start)" % [int(post.x / Defs.TILE), int(post.y / Defs.TILE), int(post.distance_to(fh) / Defs.TILE)])


## The cranks: at the post, winding and mending the Owls there (the lowest first); danger by it: home for 40 s.
func _crank_tick() -> void:
	if not launched:
		return
	_pick_cranks()
	if post == Vector2.INF or (game.clock - _post_t > 45.0 and phase == "home" and not _cranks_there()):
		_post_t = game.clock
		_pick_post()
	if post == Vector2.INF:
		return
	var danger := false
	var guard: bool = not flock.is_empty() and phase in ["home", "back"] and _centre(flock).distance_to(post) < 500.0
	for o in game.units_near(post, POST_DANGER):
		if o.dead or o.off_field or not game.hostile(o.team, team) or not ai._armed(o) or not game.is_visible_to(team, o.position):
			continue
		if _hits_air(o) or not guard:
			danger = true
			break
		# (ground-only enemies with the flock by the post: the Owls see them off, the cranks keep winding)
		for u in flock:
			if (u.target == null or not is_instance_valid(u.target) or u.target.dead) and u.can_hit(o):
				u.cmd_attack(o)
	if danger and game.clock - _post_bad_t > 40.0:
		_lost_at[Vector2i(int(post.x / 256.0), int(post.y / 256.0))] = true
		var was := post
		_pick_post()
		if post.distance_to(was) < 300.0:
			_post_bad_t = game.clock
			say("the crank post is found: the Winders run home")
		else:
			say("the crank post is found: the Winders go to the new one")
		return
	var home := _home()
	var at_post := game.clock - _post_bad_t >= 40.0
	var need: Array = flock.filter(func(u: Unit) -> bool: return u.position.distance_to(post) < 160.0 and (u.wind < 0.97 or u.hp < u.max_hp * 0.95))
	need.sort_custom(func(a: Unit, b: Unit) -> bool: return a.wind + a.hp / a.max_hp < b.wind + b.hp / b.max_hp)
	for w in cranks:
		if not at_post:
			if w.position.distance_to(home) > 300.0 and (w.order != "move" or w.order_point.distance_to(home) > 80.0):
				w.cmd_move(home)
			continue
		if w.order == "repair" and is_instance_valid(w.order_target) and not w.order_target.dead and flock.has(w.order_target):
			var tu: Unit = w.order_target
			if (tu.wind < 0.99 or tu.hp < tu.max_hp) and tu.position.distance_to(post) < 200.0:
				need.erase(tu)
				continue
		if not need.is_empty() and w.can_repair(need[0]) and w.position.distance_to(post) < 160.0:
			w.cmd_repair(need.pop_front())
			continue
		if w.position.distance_to(post) <= 50.0:
			continue
		# the way out: only with the flock over them (resting, not defending the base, at least 2 Owls), the post looked
		# at; else they wait at home (round A: cranks walking out alone were caught by riders and Raptors)
		var fc: Vector2 = _centre(flock) if not flock.is_empty() else home
		var escorted: bool = flock.size() >= 2 and phase == "home" and _post_cleared()
		if not escorted:
			var hold: Vector2 = home if w.position.distance_to(home) < 600.0 or flock.is_empty() or phase != "home" else fc
			if w.position.distance_to(hold) > 120.0 and (w.order != "move" or w.order_point.distance_to(hold) > 80.0):
				w.cmd_move(hold + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
			elif w.position.distance_to(hold) <= 120.0 and w.order != "move":
				w.cmd_move(w.position)
			continue
		# (on the way: an Owl running down is wound walking: the Winder follows it, winding, WinderWalk)
		if w.order == "repair" and is_instance_valid(w.order_target) and flock.has(w.order_target) and (w.order_target as Unit).wind < 0.95:
			continue
		var low: Array = flock.filter(func(u: Unit) -> bool: return u.wind < 0.75 and u.position.distance_to(w.position) < 200.0 \
			and not cranks.any(func(c2: Unit) -> bool: return c2 != w and c2.order == "repair" and c2.order_target == u))
		if not low.is_empty():
			low.sort_custom(func(a: Unit, b: Unit) -> bool: return a.wind < b.wind)
			if w.can_repair(low[0]):
				w.cmd_repair(low[0])
				continue
		if w.position.distance_to(fc) > 150.0 and w.position.distance_to(post) > 200.0 and fc.distance_to(post) > w.position.distance_to(post):
			# (ahead of the flock: wait for it, a move on the spot: an idle Winder is sent back to work)
			if w.order != "move" or w.order_point.distance_to(w.position) > 30.0:
				w.cmd_move(w.position)
			continue
		if w.order != "move" or w.order_point.distance_to(post) > 40.0:
			w.cmd_move(post + Vector2(randf_range(-20, 20), randf_range(-20, 20)))


## An armed enemy within r of p that unit u can hit and that cannot hit flyers (the Owls' to see off), the nearest.
func _ground_foe_near(p: Vector2, r: float, u: Unit):
	var best = null
	var bd := INF
	for o in game.units_near(p, r):
		if o.dead or o.off_field or not game.hostile(o.team, team) or _hits_air(o) or not u.can_hit(o) or not game.is_visible_to(team, o.position):
			continue
		if not ai._armed(o) and not o.is_worker():
			continue
		var dd: float = o.position.distance_to(p)
		if dd < bd:
			bd = dd
			best = o
	return best


## New Owls fly to where the flock rests (they join it there).
func _join_tick() -> void:
	var to := _rest()
	for u in joining:
		if u.target != null and is_instance_valid(u.target) and not u.target.dead:
			continue
		if u.position.distance_to(to) > 60.0 and (u.order != "move" or u.order_point.distance_to(to) > 60.0):
			u.cmd_move(to + Vector2(randf_range(-30, 30), randf_range(-30, 30)))


## The armed enemies our side sees within 450 px of p, by value.
func _attack_value(p: Vector2) -> float:
	var v := 0.0
	for o in game.units_near(p, 450.0):
		if not o.dead and not o.off_field and game.hostile(o.team, team) and ai._armed(o) and game.is_visible_to(team, o.position):
			v += ai._unit_value(o)
	return v
