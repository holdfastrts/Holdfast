extends RefCounted
## THE CLOCKWORK'S ECONOMY AND BALANCED OPENINGS (clockwork-eco, 0.30.10; docs/clockwork_eco.md).
## The owner, 2026-11-04 20:24, watching Hard Clockwork Economy v Hard Brood Economy on Cinder Steps (0.30.8): "it creates
## a Light Works for no reason very early without scouting any rush. Instead of making a second Clocktower fast it builds a
## force of Clock Soldiers, basically without any reason... minute 4 and it didn't expand yet." In that game the shared
## computer's scout could not see the enemy at 1:02 and PLAYED SAFE (army first): a Light Works at 1:38, a second one at
## 2:21, 7 Clock Soldiers by 3:00, 14 Winders, the second Clocktower laid only at 4:49.
## Now the Economy and Balanced Clockwork computers play a WRITTEN OPENING (AIClockwork's build-order machinery, like the
## Springer timing and the builds of cw-builds-a/b/c), made from the Turret turtle's fast second Clocktower (about 2:05,
## 15-19% more cogs than Balanced) WITHOUT its turrets (the owner's rule: static defence only as a reaction), and from the
## owner's own hand game (Glimmerdeep, 2026-11-04: the Regulator, a Cog Press, the Mainspring, then the second Clocktower,
## then the Works and the tech):
##  - Winders non-stop from every Clocktower, to the saturation of its presses and Mainspring (worker goals per step);
##  - the second Cog Press, a Regulator, then the SECOND CLOCKTOWER as soon as its 400 cogs are there (on the Clockwork's
##    own spot: ClockSites, room for its whole ring);
##  - the Mainspring and its crew, supply ahead of need, the new Clocktower's two presses the moment it stands ("press_new");
##  - only then the military, on the economy's schedule: Balanced a Light Works at once after the Clocktower and a few
##    Clock Soldiers; Economy the Light Works after the new presses, and the Escapement;
##  - NO military on a timer, and none when the scout simply saw nothing ("uncertain": the shared computer played safe
##    there). Military before the schedule only on RUSH EVIDENCE (AIScout verdict "rush": fast rush units seen early, or a
##    big early army): then a Light Works and Clock Soldiers sized to what was seen (urgent(): ahead of every step), and a
##    Ratchet Turret by the ramp only when the rush seen is big (an emergency, the owner's rule); the economy steps go on
##    after them.
## `-- cweco:off` on the command line plays Economy and Balanced on the shared computer as before (for comparisons).

const PLANS := {
	"economy": {
		"workers0": 14,
		"steps": [
			"7 regulator",
			"8 cog_press",
			"workers 16",
			"clocktower",
			"mainspring",
			"crew mainspring 3",
			"15 regulator",
			"workers 24",
			"press_new",
			"press_new",
			"movement_works",
			"21 regulator",
			"workers 28",
			"movement_works",
			"escapement",
			"clock_soldier 6",
			"27 regulator",
			"end",
		],
	},
	"balanced": {
		"workers0": 14,
		"steps": [
			"7 regulator",
			"8 cog_press",
			"workers 15",
			"clocktower",
			"movement_works",
			"mainspring",
			"crew mainspring 3",
			"15 regulator",
			"workers 22",
			"clock_soldier 2",
			"press_new",
			"press_new",
			"movement_works",
			"21 regulator",
			"escapement",
			"clock_soldier 6",
			"workers 26",
			"27 regulator",
			"end",
		],
	},
}

const RUSH_MIN := 3              # Clock Soldiers the rush reaction trains at least
const RUSH_MAX := 8              # ... and at most
const RUSH_K := 1.4              # ... else the supply of army seen times this, plus one
const TURRET_VALUE := 300.0      # a rush seen worth this much (or more): a Ratchet Turret by the ramp too (an emergency)

var ai = null
var game: Game = null
var team := 0
var rush := false                # the rush reaction is on
var rush_at := -1.0
var rush_n := 0
var rush_turret := false
var _works: Building = null
var _turret: Building = null
var _trained := 0
var _said := {}


func _init(a) -> void:
	ai = a
	game = a.game
	team = a.team


static func on() -> bool:
	return not OS.get_cmdline_user_args().has("cweco:off")


func say(s: String) -> void:
	ai.note(s)


## The plan's own steps (AIClockwork._do_step asks here first): {} when the step is not one of these.
func step(i: int, parts: Array) -> Dictionary:
	match String(parts[0]):
		"press_new":
			return _press_new(i)
	return {}


## "press_new": a Cog Press at a Clocktower that stands and has a press short of its two (the newest first). Waits (never
## skipped) while the new Clocktower is going up: AIClockwork._do_build would call it "over the limit" and drop it.
## A press site lost before it stood (the enemy at the new Clocktower: an Extreme rush's Raptors killed eleven in a row on
## Cinder Steps) waits PRESS_RETRY s, and no press goes by a Clocktower with an enemy soldier within PRESS_SAFE px.
const PRESS_RETRY := 25.0
const PRESS_SAFE := 360.0
var _press_lost := {}            # step index -> when its site was last lost


func _press_new(i: int) -> Dictionary:
	if ai._placed.has(i):
		return {"st": "done"}
	if game.clock - float(_press_lost.get(i, -999.0)) < PRESS_RETRY:
		return {"st": "wait"}
	var kind := Defs.GEAR_PRESS
	var cost: int = game.build_price(team, kind)
	if game.econ_count(team, kind) >= game.econ_limit(team, kind):
		# (every standing Clocktower has its two: wait for the new one, unless none is going up)
		var going: bool = ai._halls().any(func(h: Building) -> bool: return not h.built)
		return {"st": "wait"} if going else {"st": "done"}
	if ai._free() < cost:
		return {"st": "money", "cost": cost, "t": 0.0}
	var halls: Array = ai._halls().filter(func(h: Building) -> bool: return h.built)
	halls.sort_custom(func(a: Building, b: Building) -> bool: return a.lode_left() > b.lode_left())
	for h in halls:
		if ai._enemy_near(h.center(), PRESS_SAFE):
			continue            # (the enemy is at that Clocktower: not now)
		var b: Building = null
		if ai.macro != null:
			b = ai.macro.lay_press(h)      # (econ-coach-clockwork: the big ring while it pays)
		else:
			var c: Vector2i = GearEcon.room_spot(game, team, kind, [h], [], Vector2.INF, true)
			if c.x < 0:
				continue
			b = ai._lay(kind, c, false)
		if b != null:
			ai._placed[i] = b
			say("lays a Cog Press by its %s Clocktower at %d supply (step %d: press_new)" % ["new" if h != halls[-1] or halls.size() == 1 else "old", game.supply_used(team), i + 1])
			return {"st": "done"}
	var c2: Vector2i = ai._econ_spot(kind)
	if c2.x >= 0 and not ai._enemy_near(Vector2(c2) * Defs.TILE, PRESS_SAFE):
		var b2: Building = ai._lay(kind, c2, false)
		if b2 != null:
			ai._placed[i] = b2
			return {"st": "done"}
	return {"st": "wait", "cost": cost, "t": 0.0}


## A step's building was lost before it stood (AIClockwork._watch_sites).
func lost(i: int) -> void:
	_press_lost[i] = game.clock


## THE RUSH REACTION (called by AIClockwork._bo_tick before the steps, so its cogs come first): once the scout's verdict is
## "rush" (real evidence), a Light Works (if none), Clock Soldiers sized to what was seen, and a turret by the ramp if the
## rush is big; the steps go on with what is left.
func urgent() -> void:
	if ai.scout == null:
		return
	if not rush and String(ai.scout.verdict) == "rush":
		rush = true
		rush_at = game.clock
		var ra: Array = ai.scout._recent_army()
		rush_n = clampi(int(ceil(float(ra[1]) * RUSH_K)) + 1, RUSH_MIN, RUSH_MAX)
		rush_turret = float(ra[0]) >= TURRET_VALUE
		say("rush evidence (%s): a Light Works and %d Clock Soldiers first%s, then the economy goes on" % [String(ai.scout.reason), rush_n,
			", and a Ratchet Turret by the ramp (%d value of army seen)" % int(ra[0]) if rush_turret else ""])
	if not rush:
		return
	# the Light Works
	var works: Array = ai._mine(ai._works())
	if works.is_empty():
		var cost: int = game.build_price(team, ai._works())
		if ai._gold() < cost:
			ai._hold += cost
			return
		var c: Vector2i = ai._spot(ai._works())
		if c.x >= 0:
			_works = ai._lay(ai._works(), c, false)
			if _works != null:
				say("lays a Light Works against the rush at %d supply" % game.supply_used(team))
		ai._hold += 0 if _works != null else cost
		return
	# the soldiers
	var have: int = game.army(team).filter(func(u: Unit) -> bool: return u.kind == "clock_soldier").size()
	var queued := 0
	for w in works:
		queued += (w.queue as Array).count("clock_soldier")
	var p: Array = game.unit_price(team, "clock_soldier")
	if have + queued < rush_n:
		for w in works:
			if not w.built or not (w.queue as Array).is_empty():
				continue
			if ai._gold() - ai._hold < int(p[0]):
				ai._hold += int(p[0])
				break
			if game.can_train(w, "clock_soldier") == "" and game.train(w, "clock_soldier") == "":
				_trained += 1
	# the emergency turret, once a soldier or two stand
	if rush_turret and _turret == null and have >= 2:
		var r: Dictionary = ai.bta.step(-1, ["turret", "ramp"]) if ai.bta != null else {}
		if String(r.get("st", "")) == "done":
			_turret = ai.bta.turrets_laid[-1][1] if not ai.bta.turrets_laid.is_empty() else null
			if _turret == null:
				rush_turret = false
			say("lays a Ratchet Turret by the ramp against the rush (an emergency)")
		elif String(r.get("st", "")) == "money":
			ai._hold += int(r.get("cost", 0))
