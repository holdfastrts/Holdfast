extends RefCounted
## THE CLOCKWORK COMPUTER'S MACRO (econ-coach-clockwork, docs/econ-coach-clockwork.md; the owner 2026-11-13 01:18: "The AI
## must be 100% or as close as possible to what it could do"). How the Clockwork computer runs its economy, measured against
## the economy bench (tools/econ_bench.gd: the faction's design under an ideal scripted build) with the computer alone
## (tools/econ_alone_cw.gd) and in Hard games. NO rule or number of the game changes here: only what the computer does.
## What it lost, and what this does about it:
##  1. WINDERS STOPPED AT 32 (Hard) while its posts grew to 41-46 by 8:00-9:00: the shared cap (AI._workers: 13 a Clocktower,
##     32 at most) counted the 2-10 Winders that walk with the army to wind it (the escorts) and the builder among the 32, so
##     20-25 worked the presses from 9:00 on. Now (want()): every post of its working presses and Mainsprings, plus the
##     escorts, the builder and a press crew ahead for a Clocktower going up, up to MAX_WINDERS.
##  2. A WRITTEN BUILD KEPT ITS OWN SMALL ECONOMY: while an opening build runs (bo_on) only its steps build and its
##     worker goal trains; a build without "press_new" steps (the Clock Soldier rush, the Springer timing...) stood a second
##     Clocktower with no press beside it for minutes (Hollowfen, OPTIMAL -> Clock Soldier rush -> Springer timing: 13 posts
##     the whole game, the main spent at 12:00 and 9,000 cogs at 15:00). Now (bo_tick()): posts left empty get Winders, and
##     a standing Clocktower on fresh brass short of its presses gets one, from the cogs the build's waiting step leaves.
##  3. (in AIClockwork) OPTIMAL's second switch kept no time cap, and the stuck-build hand-over only ran against the Brood.
## `-- cwmacro:off` on the command line plays as before (for comparisons).

const MAX_WINDERS := 54          # Winders at most (Hard; the escorts included): the rest of the 200 supply is the army's
const PRESS_SAFE := 360.0        # no press by a Clocktower with an enemy soldier this near (as BuildsEco)
const LODE_FRESH := 0.15         # a Clocktower with at least this share of its brass still wants its presses
const BIG_HALLS := 3             # Cog Presses on the BIG ring while it has no more Clocktowers than this standing...
const BIG_SUPPLY := 140          # ... and less supply than this (later the small ring's better cogs a Winder count more)

var ai = null
var game: Game = null
var team := 0
var _said := {}


func _init(a) -> void:
	ai = a
	game = a.game
	team = a.team


static func on() -> bool:
	return not OS.get_cmdline_user_args().has("cwmacro:off")


func say(key: String, s: String) -> void:
	if _said.has(key):
		return
	_said[key] = true
	ai.note(s)


## Posts its economy has now: the crews of its Cog Presses and Mainsprings on land that pays, standing and linked or still
## going up (they will need their crew the moment they stand).
func posts() -> int:
	var n := 0
	for b in game.buildings:
		if b.team != team or b.dead or b.ghost:
			continue
		if b.kind != Defs.GEAR_PRESS and b.kind != "mainspring":
			continue
		if b.kind == Defs.GEAR_PRESS and (b.barren() or (b.built and game.gear_net.speed_mult(b) <= 0.0)):
			continue
		n += b.crew_max()
	return n


## Posts with nobody on them now (standing, linked, paying).
func empty_posts() -> int:
	var n := 0
	for b in game.buildings:
		if b.team != team or b.dead or not b.built or (b.kind != Defs.GEAR_PRESS and b.kind != "mainspring"):
			continue
		if b.kind == Defs.GEAR_PRESS and (b.barren() or game.gear_net.speed_mult(b) <= 0.0):
			continue
		n += maxi(0, b.crew_max() - b.working_crew())
	return n


## The Winders it wants (the shared computer's count, AI._lab_want): every post, the escorts that wind the army, a builder,
## a small press's crew ahead for each Clocktower going up; the plan's "workers" share scales the rest (Rush 0.75).
func want(base: int) -> int:
	if ai.difficulty < 2:
		return base
	var esc: int = ai._escort_want(game.army(team)) if Defs.gear_mode else 0
	var pre := 0
	for h in ai._halls():
		if not h.built:
			pre += int(Defs.GEAR["press"]["big" if want_big() else "small"]["crew"])
	var w := posts() + esc + 1 + pre
	var k := float(ai._s("workers"))
	if k < 1.0:
		w = int(ceil(float(w) * k))
	return clampi(maxi(w, base), 0, MAX_WINDERS)


## While a written opening build runs (AIClockwork._bo_tick, after its steps): Winders for posts left empty, and the presses
## of a standing Clocktower that has none (or one), from the cogs the build's waiting step leaves (AIClockwork._free).
func bo_tick() -> void:
	if ai.difficulty < 2 or not Defs.gear_mode:
		return
	_fill_posts()
	_presses()


func _fill_posts() -> void:
	var wk := String(ai._f()["worker"])
	var queued := 0
	for h in ai._halls():
		queued += (h.queue as Array).count(wk)
	var short := empty_posts() - queued - _idle_workers()
	if short <= 0:
		return
	for h in ai._halls():
		if short <= 0 or ai._free() < int(Defs.UNITS[wk]["cost"]):
			return
		if not h.built or not (h.queue as Array).is_empty():
			continue
		if game.supply_used(team) + 1 > int(game.players[team]["cap"]):
			return
		if game.train(h, wk) == "":
			short -= 1
			say("fill", "macro: Winders for the empty posts while the opening build runs (%d posts empty)" % empty_posts())


## THE BIG RING for its presses (econ-coach-clockwork, fix 4): the shared rule laid a big press only with spare Winders
## standing, and with Winders trained for the posts there never were: every computer press was small, two to a Clocktower,
## 26 posts on two bases where the bench's big presses give 38: at most 72% of the bench's cogs a minute until the third
## Clocktower. The big ring costs 25 cogs and 4 s more and takes 8 Winders (10 cogs a second) for the small one's 5 (7.2):
## worth it while Winders are cheap to add, so the first BIG_HALLS Clocktowers' presses go big, the later ones small (at
## the supply cap the small ring's 86 cogs a Winder a minute beat the big one's 75).
func want_big() -> bool:
	if ai.difficulty < 2 or not Defs.gear_mode:
		return false
	if ai._foe_is("brood"):
		# (against the Brood the small ring: its Raptors come early, and the big ring's 25 cogs and three more Winders a press
		# came out of the army: army at 8:00 1,607 -> 1,246 in the 12 Brood games, won or led 11 -> 8 of 12, while the
		# Crown and mirror games gained by it)
		return false
	var built: int = ai._halls().filter(func(h: Building) -> bool: return h.built).size()
	return built <= BIG_HALLS and game.supply_used(team) < BIG_SUPPLY


## A press by Clocktower h: the big ring if wanted and there is room for it, else the small one. The site or null.
func lay_press(h: Building) -> Building:
	var kind := Defs.GEAR_PRESS
	var big := want_big()
	game.set_gear_pick(team, kind, big)
	if big and ai._free() < game.build_price(team, kind):
		big = false
		game.set_gear_pick(team, kind, false)
	var c: Vector2i = GearEcon.room_spot(game, team, kind, [h], [], Vector2.INF, true)
	if c.x < 0 and big:
		big = false
		game.set_gear_pick(team, kind, false)
		c = GearEcon.room_spot(game, team, kind, [h], [], Vector2.INF, true)
	if c.x < 0 or ai._free() < game.build_price(team, kind):
		game.set_gear_pick(team, kind, false)
		return null
	var b: Building = ai._lay(kind, c, big)
	game.set_gear_pick(team, kind, false)
	return b


## Presses its Clocktower h has (not spent).
func presses_of(h: Building) -> int:
	var n := 0
	for b in ai._mine(Defs.GEAR_PRESS):
		if game.lode_hall(b) == h and not b.barren():
			n += 1
	return n


## After the opening (AIClockwork._econ_build, before the shared rules): the freshest standing Clocktower short of its
## presses gets one (big while want_big), one going up at a time (two with Winders idle: presses_more). True when it laid one.
func presses_after() -> bool:
	if ai.difficulty < 2 or not Defs.gear_mode:
		return false
	var kind := Defs.GEAR_PRESS
	if ai._busy_building(kind) or game.econ_count(team, kind) >= game.econ_limit(team, kind):
		return false
	var cost: int = game.build_price(team, kind)
	if ai._gold() < cost or (ai._keeping() and ai._gold() - cost < ai._hall_keep()):
		return false
	var halls: Array = ai._halls().filter(func(h: Building) -> bool: return h.built and h.lode_left() >= LODE_FRESH)
	halls.sort_custom(func(a: Building, b: Building) -> bool: return a.lode_left() > b.lode_left())
	for h in halls:
		if presses_of(h) >= Defs.econ_per_hall("clockwork", kind) or ai._enemy_near(h.center(), PRESS_SAFE):
			continue
		if lay_press(h) != null:
			return true
	return false


func _idle_workers() -> int:
	return game.workers(team).filter(func(u: Unit) -> bool: return (u.order == "idle" or u.order == "") and not ai._escort.has(u) \
		and not ai._held_worker(u) and not (ai.scout != null and ai.scout.is_scout(u))).size()


## A press for a standing Clocktower on fresh brass that is short of its two (the freshest first), one going up at a time,
## unless the build's own next step is a press (it lays it itself).
func _presses() -> void:
	var kind := Defs.GEAR_PRESS
	if ai._busy_building(kind) or game.econ_count(team, kind) >= game.econ_limit(team, kind):
		return
	var seen := 0
	for i in ai.steps.size():
		if ai.done[i]:
			continue
		var head := String(ai.steps[i]).split(" ")
		var h0 := String(head[1] if head.size() >= 2 and String(head[0]).is_valid_int() else head[0])
		if h0 == "press_new" or h0.trim_suffix(":big") == kind:
			return              # (the build lays its own press soon: its opening is left as written)
		seen += 1
		if seen >= 4:
			break
	var cost: int = game.build_price(team, kind)
	if ai._free() < cost:
		return
	var halls: Array = ai._halls().filter(func(h: Building) -> bool: return h.built and h.lode_left() >= LODE_FRESH)
	halls.sort_custom(func(a: Building, b: Building) -> bool: return a.lode_left() > b.lode_left())
	for h in halls:
		var n := 0
		for b in ai._mine(kind):
			if game.lode_hall(b) == h and not b.barren():
				n += 1
		if n >= Defs.econ_per_hall("clockwork", kind):
			continue
		if ai._enemy_near(h.center(), PRESS_SAFE):
			continue
		var b2: Building = lay_press(h)
		if b2 != null:
			ai.note("macro: lays a Cog Press by a Clocktower with %d of its 2 (%d%% brass left) while the opening build runs" % [n, int(h.lode_left() * 100.0)])
			return


## After the opening (AIClockwork._econ_build, after the shared rules): when Winders stand idle for want of posts (a spent
## Clocktower let its crews go) and a Clocktower on fresh brass is short of its presses, a second press goes up at once
## beside the one the shared rules lay (they lay one at a time: 15-37 Winders stood idle for a minute or more at 11:00-13:00).
func presses_more() -> void:
	if ai.difficulty < 2 or not Defs.gear_mode:
		return
	var kind := Defs.GEAR_PRESS
	var going: int = ai._mine(kind).filter(func(b: Building) -> bool: return not b.built).size()
	if going == 0 or going >= 2 or game.econ_count(team, kind) >= game.econ_limit(team, kind):
		return
	if _idle_workers() < 4 or ai._gold() < game.build_price(team, kind):
		return
	var halls: Array = ai._halls().filter(func(h: Building) -> bool: return h.built and h.lode_left() >= LODE_FRESH)
	halls.sort_custom(func(a: Building, b: Building) -> bool: return a.lode_left() > b.lode_left())
	for h in halls:
		var n := 0
		for b in ai._mine(kind):
			if game.lode_hall(b) == h and not b.barren():
				n += 1
		if n >= Defs.econ_per_hall("clockwork", kind) or ai._enemy_near(h.center(), PRESS_SAFE):
			continue
		if lay_press(h) != null:
			say("more", "macro: a second Cog Press at once for the idle Winders (%d idle)" % _idle_workers())
			return


## After the opening (AIClockwork._supply, before the shared rule): the Regulators keep ahead of every Clocktower training
## Winders and every Works training units (the shared margin counted only the Works: the computer stood supply-blocked
## 3-4 minutes in all from 6:00 on, once its Winders came from four or five Clocktowers), two going up at once when tight.
## True when it laid one (or one is going up and that is enough).
func supply() -> bool:
	if ai.difficulty < 2 or not Defs.gear_mode:
		return false
	var cap: int = game.players[team]["cap"]
	if cap >= game.max_supply(team):
		return true
	var used := game.supply_used(team)
	var sup: String = ai._sup()
	var making := 0
	for h in ai._halls():
		if h.built:
			making += 1
	for w in ai._mine(ai._works()) + ai._mine("heavy_works"):
		if w.built:
			making += 3
	var margin := 4 + making
	var building: int = ai._mine(sup).filter(func(b: Building) -> bool: return not b.built).size()
	if cap - used > margin:
		return true
	if building >= (2 if cap - used <= margin / 2 else 1):
		return true
	if ai._gold() < int(Defs.BUILDINGS[sup]["cost"]):
		return true
	ai._construct(sup)
	return true
