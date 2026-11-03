extends RefCounted
## THE CLOCKWORK COMPUTER AGAINST A SWARM (owner's playtest 2026-11-01, Hard Clockwork Rush v Hard Brood Economy, Glimmerdeep,
## 0.25.25: "Clockwork misread the situation entirely, brood had a mass of Raptors and Clockwork expanded without a plan to
## deal with the mass of Raptors, it should have gone Pendulum. Clockwork is still attacking without a few Winders with it to
## repair and rewind."). docs/clockwork_ai_swarm.md.
##
## Gear-mode Clockwork only. What it counts, every 2 s, of the enemy army in sight: its value, and the SWARM in it (cheap
## light melee: Raptors, value 40 or less a body, reach 40 px or less). Every fighter seen (not rooted) counts for MEMORY s while it lives.
## A swarm is ON when SWARM_MIN or more such bodies are known and they are at least half of the fighters known. Then:
##  - the counter first: the Heavy Works, then Pendulums (their blades cut every enemy in the arc, light ones hardest):
##    pend_want() of them, before the Ballista and the Great Winder, without waiting for three Springers (AI._produce);
##  - a turret more at home (AI._turrets);
##  - no expansion while the swarm seen is clearly bigger than our army and fewer than PEND_READY Pendulums are out
##    (AI._hall_first), unless the main runs dry (design_principles 2: depletion still forces it in the end);
##  - no new wave into it on those terms either (hold_attack), unless the supply is near its cap.
## (The escort Winders of every wave: AI._escort_want and AI._wave_escort; not here.)

const MEMORY := 120.0           # (s) the biggest army seen lately counts this long
const SWARM_MIN := 10           # light melee bodies seen (alive, in the last MEMORY s) to call it a swarm
const SWARM_SHARE := 0.5        # ... and at least this share of the fighters seen (by count: a Tyrant Sire or the Mother
                                # outweighs 13 Raptors by value)
const BODY_VALUE := 40.0        # a swarm body is worth this or less (Raptors: 25)
const BODY_REACH := 40.0        # ... and fights within this reach (melee)
const OUTMATCHED := 1.3         # the enemy army seen is worth this many times ours (plus 100): clearly bigger
const PEND_READY := 2           # Pendulums out before it expands or attacks into a swarm

var ai
var game
var _t := -99.0
var _seen := {}                 # instance id -> {"u", "t" last seen, "v" value, "body"}: the enemy fighters seen lately
var _n := 0                     # swarm bodies among them
var _n_t := -999.0              # (when last counted)
var _v := 0.0                   # their value
var _sv := 0.0                  # ... the swarm's part of it
var _m := 0                     # all the fighters seen lately
var _said := false
var _said_hold := -999.0
var log_lines: Array = []       # [clock, text] (tests read it)


func _init(a) -> void:
	ai = a
	game = a.game


## Is this enemy unit a swarm body (cheap light melee)?
static func is_body(u: Unit) -> bool:
	var v := float(u.d.get("cost", 50)) / maxf(1.0, float(u.d.get("spawn", 1)))
	return u.has_tag("light") and v <= BODY_VALUE and float(u.d.get("range", 0.0)) <= BODY_REACH and not u.is_air() \
			and u.has_attack()


func tick() -> void:
	if game.clock - _t < 2.0:
		return
	_t = game.clock
	var foe: int = ai._foe()
	if foe < 0:
		return
	# (every enemy fighter seen in the last MEMORY s that is still alive, each once: an army is never all in sight at once;
	# in the owner's game it saw 13 Raptors at once while 30 were out)
	for u in game.army(foe):
		if u.off_field or not game.is_visible_to(ai.team, u.position) or not ai._armed(u) or BroodNew.rooted(u):
			continue          # (a rooted creature is the Brood's building: not its army)
		_seen[u.get_instance_id()] = {"u": u, "t": game.clock,
				"v": float(u.d.get("cost", 50)) / maxf(1.0, float(u.d.get("spawn", 1))), "body": is_body(u)}
	var n := 0
	var m := 0
	var v := 0.0
	var sv := 0.0
	for id in _seen.keys():
		var e: Dictionary = _seen[id]
		if not is_instance_valid(e["u"]) or e["u"].dead or game.clock - float(e["t"]) > MEMORY or BroodNew.rooted(e["u"]):
			_seen.erase(id)
			continue
		v += float(e["v"])
		m += 1
		if e["body"]:
			n += 1
			sv += float(e["v"])
	_n = n
	_m = m
	_v = v
	_sv = sv
	_n_t = game.clock
	if on() and not _said:
		_said = true
		_note("sees a swarm (%d light melee, %d value of fighters seen): the Heavy Works and Pendulums first, a turret more at home" % [_n, int(_v)])


## A swarm was seen lately.
func on() -> bool:
	if game.clock - _n_t > MEMORY:
		return false
	return _n >= SWARM_MIN and float(_n) >= float(_m) * SWARM_SHARE


## How many Pendulums it wants against the swarm: 2, and one more for every 10 bodies seen, at most 6.
func pend_want() -> int:
	return clampi(2 + _n / 10, PEND_READY, 6)


func pendulums() -> int:
	var n := 0
	for u in game.army(ai.team):
		if u.kind == Defs.PENDULUM and not u.dead:
			n += 1
	return n


## The swarm seen is clearly bigger than our army.
func outmatched() -> bool:
	return on() and _v > ai._guard_value() * OUTMATCHED + 100.0


## Not now: a swarm clearly bigger than our army and the counter not out yet.
func not_ready() -> bool:
	return outmatched() and pendulums() < PEND_READY


## The expansion waits (AI._hall_first); logged once a minute.
func hold_expand() -> bool:
	# (the counter first: a swarm seen, its tier-2 time come and no Heavy Works laid yet: the tech's and the yard's cogs
	# before a hall's)
	# (not when its main has no room for the yard at all: the new hall's field is then where it goes, AI._tier3)
	var yard: bool = on() and ai._mine(Defs.CW_HEAVY).is_empty() and not ai._heavy_no_room \
			and (game.has_working(ai.team, Defs.CW_TECH) or not ai._mine("mainspring").is_empty() or game.clock >= ai._tier2_at())
	if not yard and not not_ready():
		return false
	if game.clock - _said_hold > 60.0:
		_said_hold = game.clock
		if yard:
			_note("holds its expansion: a swarm seen (%d light melee), its tech and the Heavy Works first" % _n)
		else:
			_note("holds its expansion: the swarm seen (%d value) outmatches its army (%d), %d of %d Pendulums out" % [int(_v), int(ai._guard_value()), pendulums(), PEND_READY])
	return true


## No new wave into a bigger swarm before the Pendulums are out (unless the supply is near its cap).
func hold_attack() -> bool:
	if not not_ready():
		return false
	return game.supply_used(ai.team) < game.max_supply(ai.team) - 8


func _note(s: String) -> void:
	log_lines.append([game.clock, s])
	if game.mlog:
		game.mlog.add("%s %s" % [game.mlog.who(ai.team), s])
