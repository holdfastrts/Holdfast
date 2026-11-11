extends SceneTree
## THE OWNER'S ECONOMY (crown-owner-eco, docs/crown_owner_eco.md): a Hard Crown computer on the Economy plan against a
## Hard Brood on its Economy plan.
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_owner_eco.gd [-- map:greenhold seed:11 plan:economy]
##  [barracks] no Barracks before the second hall is laid unless the scout saw a rush
##  [hall]     the second hall is laid by HALL_BY without a rush
##  [farm]     a new hall gets its Farm within FARM_IN s of standing
##  [supply]   never supply-blocked more than BLOCK_MAX s at a stretch with 300 gold or more in the bank (to 6:30)
##  [labs]     LABS_4 labourers or more at 4:00
##  [layout]   the Cottages (but the ramp's and the new hall's wall slots) stand in the layout's Cottage block, and the
##             production buildings in its production rows
##  [wall]     Raptors put at the natural's palisade at 6:30: the army goes INSIDE that wall (the wall post), not to the cliff
##             edge of the main
const HALL_BY := 180.0
const FARM_IN := 20.0
const BLOCK_MAX := 15.0
const LABS_4 := 22
const RAID_AT := 390.0
const RAID_N := 8
var fails := 0
var main: Node
var g: Game
var ai: AICrown
var map := "greenhold"
var seed_ := 11
var plan_name := "economy"


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"map": map = kv[1]
				"seed": seed_ = int(kv[1])
				"plan": plan_name = kv[1]
	_run.call_deferred()


func wait(s: float) -> void:
	var until := g.clock + s
	while g.clock < until:
		await physics_frame


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(seed_)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": plan_name},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "economy"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
		g.hud.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	for a in g.ais:
		if a is AICrown:
			ai = a
		elif a.team == 1:
			a.peaceful = true            # (the Brood builds its economy but sends no army: the test stages the attack)
	check(ai != null and ai.owner_on(), "(set-up) the Crown computer plays the owner's rules")
	if ai == null:
		_end()
		return
	var barracks_t := -1.0
	var barracks_ok := true
	var barracks_why := ""
	var hall2_t := -1.0
	var block_run := 0.0
	var block_worst := 0.0
	var labs4 := -1
	var last := 0.0
	while g.clock < RAID_AT:
		await physics_frame
		var dt := g.clock - last
		last = g.clock
		if hall2_t < 0.0 and ai._halls().size() >= 2:
			hall2_t = g.clock
		if barracks_t < 0.0 and not ai._mine("barracks").is_empty():
			barracks_t = g.clock
			barracks_ok = ai._halls().size() >= 2 or ai.scout.verdict == "rush"
			barracks_why = "%d halls, the scout's verdict %s" % [ai._halls().size(), ai.scout.verdict]
		var cap: int = int(g.players[0]["cap"])
		if g.supply_used(0) >= cap and cap < g.max_supply(0) and int(g.players[0]["gold"]) >= 300:
			block_run += dt
			block_worst = maxf(block_worst, block_run)
		else:
			block_run = 0.0
		if labs4 < 0 and g.clock >= 240.0:
			labs4 = g.workers(0).size()
	check(barracks_t >= 0.0 and barracks_ok, "[barracks] the first Barracks came after the second hall or a scouted rush (at %d s: %s)" % [int(barracks_t), barracks_why])
	check(hall2_t >= 0.0 and hall2_t <= HALL_BY, "[hall] the second hall was laid by %d s (%d s)" % [int(HALL_BY), int(hall2_t)])
	var farm_worst := -1.0
	for e in ai.hall_farm_log:
		farm_worst = maxf(farm_worst, float(e[1]) - float(e[0]))
	check(not ai.hall_farm_log.is_empty() and farm_worst <= FARM_IN, "[farm] every new hall got its Farm within %d s (%s)" % [int(FARM_IN), str(ai.hall_farm_log)])
	check(block_worst <= BLOCK_MAX, "[supply] supply-blocked with 300+ gold at most %d s at a stretch (worst %.0f s)" % [int(BLOCK_MAX), block_worst])
	check(labs4 >= LABS_4, "[labs] %d labourers or more at 4:00 (%d)" % [LABS_4, labs4])
	_layout_check()
	await _wall_check()
	_end()


func _layout_check() -> void:
	var cot := {}
	var prod := {}
	for p in ai.lay.bases.values():
		for c in p["cot"]:
			cot[c] = true
		for c in p["prod"]:
			prod[c] = true
	var ramp_c: Building = ai._cw_cottage()
	var slots := {}
	for id in ai.xw.plans:
		var p: Dictionary = ai.xw.plans[id]
		if p.get("ok", false):
			for s in p["slots"]:
				slots[s["cell"]] = true
	var n := 0
	var in_block := 0
	for b in ai._mine("cottage"):
		if b == ramp_c or slots.has(b.cell):
			continue
		n += 1
		if cot.has(b.cell):
			in_block += 1
	var np := 0
	var in_rows := 0
	for k in ["barracks", "foundry", "horse_breeder", "armoury", "church"]:
		for b in ai._mine(k):
			if slots.has(b.cell):
				continue
			np += 1
			if prod.has(b.cell):
				in_rows += 1
			else:
				print("   not in the rows: %s at %s (built %s)" % [k, str(b.cell), str(b.built)])
	print("   layout: %d of %d Cottages in the Cottage block, %d of %d production buildings in the rows" % [in_block, n, in_rows, np])
	check(n >= 2 and float(in_block) >= 0.75 * float(n), "[layout] the Cottages stand in the layout's Cottage block (%d of %d)" % [in_block, n])
	check(np >= 2 and float(in_rows) >= 0.75 * float(np), "[layout] the production buildings stand in the layout's rows (%d of %d)" % [in_rows, np])


func _wall_check() -> void:
	var nat: Dictionary = {}
	for id in ai.xw.plans:
		var p: Dictionary = ai.xw.plans[id]
		print("   wall plan: ok %s, closed %.2f, %s" % [str(p.get("ok", false)), ai.xw.closed_share(p) if p.get("ok", false) else -1.0, String(p.get("why", ""))])
		if p.get("ok", false) and ai.xw.closed_share(p) >= ai.xw.CLOSED_SHARE:
			nat = p
			break
	check(not nat.is_empty(), "[wall] the natural has a closed palisade ring by %d s" % int(RAID_AT))
	if nat.is_empty():
		return
	var hall: Building = nat["hall"]
	var inside: Dictionary = nat["inside"]
	# the wall piece farthest from our main, and the open ground 5 tiles outside it
	var home := (Vector2(g.starts[0]) + Vector2(2.5, 2.0)) * Defs.TILE
	var piece: Building = null
	for b in g.buildings:
		if b.team == 0 and not b.dead and b.kind == "wall" and b.center().distance_to(hall.center()) < 20.0 * Defs.TILE:
			if piece == null or b.center().distance_to(home) > piece.center().distance_to(home):
				piece = b
	check(piece != null, "[wall] a palisade piece of the natural to attack")
	if piece == null:
		return
	var out: Vector2 = piece.center() + (piece.center() - hall.center()).normalized() * 5.0 * Defs.TILE
	var n := 0
	for i in RAID_N:
		var c: Vector2i = g.nearest_free(g.cell_of(out + Vector2(float(i % 4 - 2) * 24.0, float(i / 4) * 24.0)), 5)
		if c.x < 0 or inside.has(c):
			continue
		var r: Unit = g._add_unit("raptor", 1, g.cell_center(c))
		r.cmd_attack(piece)
		n += 1
	print("   %d Raptors put at the natural's palisade at %s" % [n, str(piece.cell)])
	var best_in := 0.0
	var edge_seen := false
	var wall_seen := false
	var main_h: int = g.level_of(home)
	for k in 30:
		await wait(1.0)
		var ch = ai.ch
		if ch.wall_live():
			wall_seen = true
		elif ch.edge_live():
			if not edge_seen:
				print("   the cliff edge for: %s" % ch.edge_why)
			edge_seen = true
		var musk: Array = g.army(0).filter(func(u: Unit) -> bool: return u.kind in ["musketeer", "musketeer_armoured"] and not u.dead)
		if musk.is_empty():
			continue
		var at_wall := 0
		for u in musk:
			if inside.has(g.cell_of(u.position)) and g.level_of(u.position) != main_h:
				at_wall += 1
		best_in = maxf(best_in, float(at_wall) / float(musk.size()))
	check(wall_seen, "[wall] the army took the wall post at the natural (%d moves)" % ai.ch.wall_moves)
	check(not edge_seen, "[wall] ... not the cliff edge of the main")
	check(best_in >= 0.6, "[wall] most Musketeers stood inside the natural's wall (best %.0f%%)" % (best_in * 100.0))


func _end() -> void:
	print("test_crown_owner_eco: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
