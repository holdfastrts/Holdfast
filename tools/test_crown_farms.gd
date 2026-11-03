extends SceneTree
## CROWN ECONOMY FIRST, THE PHANTOM THREAT, STRAY MUSKETEERS AND THE BROOD READ (the owner's log 2026-11-03, v0.27.0
## Red Coast, Crown HARD ECONOMY v Brood HARD TIMING; docs/ai_crown_transitions.md section 11):
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_farms.gd
## A Hard Crown computer (Economy, Mill opening) on Red Coast (seed 4291306512) against a Brood that stands still:
##  [phantom] a Brood grub standing unseen near a Crown building is no threat (AI._threat), and the army never "holds the
##            top" against it; seen, or with the building just hit, it is one again
##  [farms]   from 2:30 to 6:00 a free Farm slot is never left unbuilt for over FARM_LATE s while the farms are nearly
##            manned (3 posts or fewer free), at most IDLE_MAX labourers stand idle for over IDLE_LATE s, and by 6:00
##            it has LAB_MIN labourers and FARMS_MIN farms
##  [strays]  three Musketeers standing together far from home are not taken as harassers: they walk home
##  [brood]   a scout that saw only the Brood Mother and one far Mound Turtle does not call the Brood greedy (0.27.0 did)
const FARM_LATE := 60.0
const IDLE_MAX := 2
const IDLE_LATE := 30.0
const LAB_MIN := 24              # labourers at 6:00 (0.27.0: 19, on 2 farms)
const FARMS_MIN := 3             # farms at 6:00 (0.27.0: 2, the new hall's first came at 6:20-6:50)
var fails := 0
var main: Node
var g: Game
var ai


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func wait(s: float) -> void:
	var until := g.clock + s
	while g.clock < until:
		await physics_frame


## A walkable spot within 300 px of a Crown building that the Crown does not see (nearest the enemy first).
func _hidden_spot() -> Vector2:
	var foe := Vector2(g.starts[1]) * Defs.TILE
	var best := Vector2.INF
	for b in g.buildings:
		if b.team != 0 or b.dead:
			continue
		var c := g.cell_of(b.center())
		for y in range(c.y - 9, c.y + 10):
			for x in range(c.x - 9, c.x + 10):
				var m := Vector2i(x, y)
				if not g.in_map(m) or not g._walkable(m):
					continue
				var p := (Vector2(m) + Vector2(0.5, 0.5)) * Defs.TILE
				if p.distance_to(b.center()) > 300.0 or g.is_visible_to(0, p):
					continue
				if best == Vector2.INF or p.distance_to(foe) < best.distance_to(foe):
					best = p
	return best


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(4291306512)
	main.start({"map": "red_coast", "seed": 4291306512, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "economy"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "timing"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false           # (as the study's fast mode: six minutes of play in about a minute)
		g.hud.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	for a in g.ais:
		if a.team == 1:
			a.process_mode = Node.PROCESS_MODE_DISABLED      # (the Brood stands still)
		else:
			ai = a
	ai.opening = "mill"
	await wait(3.0)
	check(ai.doctrine() and ai.econ_first_on and ai.phantom_on, "(set-up) the doctrine, economy first and the phantom rule are on")

	# [phantom]
	var spot := _hidden_spot()
	check(spot != Vector2.INF, "(set-up) an unseen spot within 300 px of a Crown building")
	var grub: Unit = g._add_unit("grub", 1, spot)
	grub.auto_work = false          # (it stands where it is put, as the Brood's ramp-watch grub does)
	grub.cmd_stop()
	await wait(1.0)
	check(not g.is_visible_to(0, grub.position), "(set-up) the grub stands unseen at %s" % str(grub.position))
	check(ai._threat() == Vector2.INF, "[phantom] an unseen grub by our buildings is no threat")
	ai.phantom_on = false
	check(ai._threat() != Vector2.INF, "[phantom] (0.27.0 counted it: the check catches the old fault)")
	ai.phantom_on = true
	var near_b: Building = null
	for b in g.buildings:
		if b.team == 0 and not b.dead and b.center().distance_to(grub.position) < 330.0:
			near_b = b
	check(near_b != null, "(set-up) a Crown building within 330 px of the grub")
	if near_b != null:
		near_b.hit_clock = g.clock
		check(ai._threat() != Vector2.INF, "[phantom] the building by it just hit: a threat again (guns from the dark)")
		near_b.hit_clock = -99.0

	# [farms] (the grub stays: it must not hold the army at the top all game)
	var free_since := -1.0
	var free_worst := 0.0
	var idle_since := -1.0
	var idle_worst := 0.0
	while g.clock < 360.0:
		await wait(5.0)
		if g.clock < 150.0:
			continue
		var room := 0
		for f in ai._mine("farm"):
			if f.built and not f.barren():
				room += f.crew_max() - f.crew.size()
		var slot_free: bool = g.econ_count(0, "farm") < g.econ_limit(0, "farm") and room <= 3 and not ai._hall_reserve
		if slot_free:
			if free_since < 0.0:
				free_since = g.clock
			free_worst = maxf(free_worst, g.clock - free_since)
		else:
			free_since = -1.0
		var idle := g.workers(0).filter(func(u: Unit) -> bool: return u.order == "idle").size()
		if idle > IDLE_MAX:
			if idle_since < 0.0:
				idle_since = g.clock
			idle_worst = maxf(idle_worst, g.clock - idle_since)
		else:
			idle_since = -1.0
	print("   at 6:00: %d labourers, %d posts, %d farms (limit %d), %d gold earned, holds %d" % [g.workers(0).size(), ai._posts(),
		g.econ_count(0, "farm"), g.econ_limit(0, "farm"), int(g.stats[0]["gold"]), ai.ch.holds])
	check(free_worst <= FARM_LATE, "[farms] a free Farm slot with the farms nearly manned waited at most %d s (worst %d s)" % [int(FARM_LATE), int(free_worst)])
	check(idle_worst <= IDLE_LATE, "[farms] over %d idle labourers for at most %d s (worst %d s)" % [IDLE_MAX, int(IDLE_LATE), int(idle_worst)])
	check(g.workers(0).size() >= LAB_MIN, "[farms] %d labourers or more at 6:00 (%d)" % [LAB_MIN, g.workers(0).size()])
	check(g.econ_count(0, "farm") >= FARMS_MIN, "[farms] %d farms or more at 6:00 (%d)" % [FARMS_MIN, g.econ_count(0, "farm")])
	check(ai.ch.holds == 0, "[phantom] the army never held the top against the unseen grub (holds %d)" % ai.ch.holds)

	# [strays]
	var mid := (Vector2(g.starts[0]) + Vector2(g.starts[1])) * 0.5 * Defs.TILE
	var trio: Array = []
	for i in 3:
		var c := g.nearest_free(g.cell_of(mid + Vector2(24 * i, 0)), 6)
		trio.append(g._add_unit("musketeer", 0, (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE))
	await wait(4.0)
	check(trio.all(func(u: Unit) -> bool: return not ai.hz().has(u)), "[strays] three Musketeers out together are not taken as harassers")
	var home := g.center_of_team(0)
	var d0: float = (trio[0] as Unit).position.distance_to(home)
	await wait(8.0)
	check((trio[0] as Unit).position.distance_to(home) < d0 - 60.0, "[strays] ... they walk home (%d -> %d px)" % [int(d0), int((trio[0] as Unit).position.distance_to(home))])

	# [brood]
	var sc = ai.scout
	var q: Unit = BroodNew.queen(g, 1)
	var far := Vector2.INF
	for r in range(18, 40):
		var c := g.nearest_free(g.cell_of(q.position + (mid - q.position).normalized() * r * Defs.TILE), 3)
		if c.x >= 0:
			far = (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE
			break
	var turtle: Unit = g._add_unit(BroodNew.TURTLE, 1, far)
	turtle.tesla_mode = "deployed"
	sc._foe = 1
	sc._nb_seen = {q: true, turtle: true}
	sc._seen_b = {}
	sc._hall_seen = true
	sc._army_hist = []
	sc._workers_seen = 0
	sc._cells_seen = {}
	sc._far_army_t = -1.0
	var r1: Dictionary = sc._evaluate()
	check(String(r1["verdict"]) != "greedy", "[brood] the Mother and a far turtle alone are not a greedy Brood (%s: %s)" % [r1["verdict"], r1["reason"]])
	sc.brood_read_on = false
	var r0: Dictionary = sc._evaluate()
	check(String(r0["verdict"]) == "greedy", "[brood] (0.27.0 called it greedy: the check catches the old fault: %s)" % r0["verdict"])
	sc.brood_read_on = true
	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
