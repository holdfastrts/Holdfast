extends SceneTree
## CROWN AMMUNITION, NO POWDER LOCK (crown-ammo, the owner 2026-11-05; docs/crown_ammo.md).
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_ammo.gd
##  [req]      the Musketeer and the Officer need no other building (no Powder Mill, no Horse Breeder); the Dragoon and the
##             Horseman (mounted) still need the Horse Breeder
##  [dry]      trained with gold only (an empty bank) a Musketeer comes out with 0 shots and stabs with the bayonet; an Officer
##             with no pistol and no charges fights with the sabre (melee works: the dummy is hurt)
##  [full]     with the bank full a Musketeer comes out with 10 shots and 10 powder leaves the bank; an Officer with his pistol
##             loaded and 4 charges (5 powder)
##  [partial]  with 6 powder he comes out with 6 shots and the bank is empty
##  [toggle]   ARM WITH POWDER off: 0 shots, the bank untouched, and that Barracks refills nobody; on again, it refills
##  [refill]   a dry Musketeer by a Powder Mill fills up shot by shot, the bank paying 1 a shot; with the bank empty it waits
##  [pistol]   a dry Horseman (mounted) at a reloading point gets his pistol loaded and his charges
##  [card]     the card's ammo state: NO AMMO at 0 shots, RELOADING (a bar filling) while he refills and while he reloads
##  [price]    the train button's cost line shows the powder (and "no ammunition" with the toggle off or the bank empty)
const HUD := preload("res://scripts/ui/hud.gd")
var fails := 0
var g: Game
var main: Node
var o := Vector2i.ZERO


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


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": "greenhold", "seed": 7, "slots": [
		{"who": "human", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	var hall: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "town_hall":
			hall = b
	o = hall.cell
	g.players[0]["gold"] = 5000
	g.players[0]["cap"] = 200
	# a Barracks far from the hall (out of its reloading reach), and nothing else: no Mill, no Breeder
	var bar: Building = g._add_building("barracks", 0, _free_cell(3, 3, 12), true)
	await process_frame
	# [req]
	check(g.can_train(bar, "musketeer") == "", "[req] a Musketeer needs no Powder Mill (%s)" % g.can_train(bar, "musketeer"))
	check(g.can_train(bar, "dismounted") == "", "[req] an Officer needs no Horse Breeder (%s)" % g.can_train(bar, "dismounted"))
	check(g.can_train(bar, "dragoon") != "", "[req] a Dragoon still needs a Horse Breeder (%s)" % g.can_train(bar, "dragoon"))
	check(g.can_train(bar, "horseman") != "", "[req] a Horseman still needs a Horse Breeder (%s)" % g.can_train(bar, "horseman"))
	# [price] (the bank empty)
	g.players[0]["res2"] = 0.0
	check(g.ammo_line(0, "musketeer", bar).begins_with("no ammunition"), "[price] empty bank: '%s'" % g.ammo_line(0, "musketeer", bar))
	# [dry]
	var m: Unit = await _train(bar, "musketeer")
	check(m != null and m.ammo_shots() == 0 and m.dry_out, "[dry] gold only: the Musketeer comes out with 0 shots (%s)" % (str(m.ammo_shots()) if m else "none"))
	var off: Unit = await _train(bar, "dismounted")
	_park(m, bar, 0)
	_park(off, bar, 1)
	await wait(4.0)
	check(off != null and not off.pistol and off.powder == 0.0, "[dry] gold only: the Officer comes out with no pistol shot and no charges")
	check(off != null and off.kind == "dismounted" and not off.is_mounted(), "[dry] the Officer walks (no horse)")
	# melee works: a dummy enemy (a labourer of the other side) next to each
	var dummy := g._add_unit("grub", 1, m.position + Vector2(24, 0))
	var hp0 := dummy.hp
	m.give({"o": "attack", "e": dummy})
	await wait(5.0)
	check(not is_instance_valid(dummy) or dummy.dead or dummy.hp < hp0, "[dry] the dry Musketeer fights with the bayonet (mode %s, enemy hp %s -> %s)" % [m.mode, str(hp0), str(dummy.hp) if is_instance_valid(dummy) else "gone"])
	check(m.mode == "bayonet" or not is_instance_valid(dummy) or dummy.dead, "[dry] ... in bayonet mode")
	var dummy2 := g._add_unit("grub", 1, off.position + Vector2(20, 0))
	var hp2 := dummy2.hp
	off.give({"o": "attack", "e": dummy2})
	await wait(5.0)
	check(not is_instance_valid(dummy2) or dummy2.dead or dummy2.hp < hp2, "[dry] the dry Officer fights with the sabre")
	check(float(g.stats[0].get("empty_blows", 0.0)) > 0.0, "[dry] the empty blows are counted (%s)" % str(g.stats[0].get("empty_blows", 0.0)))
	# [card]
	var st := HUD.ammo_state(m)
	check(st["state"] == "no_ammo" and st["weapon"] == "musket", "[card] 0 shots: NO AMMO on a musket (%s)" % str(st))
	check(HUD.ammo_state(off)["state"] == "no_ammo" and HUD.ammo_state(off)["weapon"] == "pistol", "[card] the dry Officer: NO AMMO on a pistol")
	# [full]
	g.players[0]["res2"] = 100.0
	check(g.ammo_line(0, "musketeer", bar).begins_with("10 powder"), "[price] full bank: '%s'" % g.ammo_line(0, "musketeer", bar))
	var m2: Unit = await _train(bar, "musketeer")
	check(m2 != null and m2.ammo_shots() == 10, "[full] with powder: 10 shots (%s)" % (str(m2.ammo_shots()) if m2 else "none"))
	check(absf(float(g.players[0]["res2"]) - 90.0) < 0.01, "[full] ... and 10 powder left the bank (%.1f)" % float(g.players[0]["res2"]))
	var off2: Unit = await _train(bar, "dismounted")
	_park(m2, bar, 2)
	_park(off2, bar, 3)
	check(off2 != null and off2.pistol and int(off2.powder) == 4, "[full] the Officer: pistol loaded and 4 charges")
	check(absf(float(g.players[0]["res2"]) - 85.0) < 0.01, "[full] ... for 5 powder (%.1f)" % float(g.players[0]["res2"]))
	check(HUD.ammo_state(m2)["state"] == "ready" and int(HUD.ammo_state(m2)["shots"]) == 10, "[card] a full Musketeer: ready, 10")
	# [partial]
	g.players[0]["res2"] = 6.0
	check(g.ammo_line(0, "musketeer", bar).begins_with("6 of 10"), "[price] 6 powder: '%s'" % g.ammo_line(0, "musketeer", bar))
	var m3: Unit = await _train(bar, "musketeer")
	_park(m3, bar, 4)
	await wait(4.0)
	check(m3 != null and m3.ammo_shots() == 6, "[partial] 6 powder: 6 shots (%s)" % (str(m3.ammo_shots()) if m3 else "none"))
	check(float(g.players[0]["res2"]) < 0.01, "[partial] ... the bank is empty (%.2f)" % float(g.players[0]["res2"]))
	# [toggle]
	g.players[0]["res2"] = 100.0
	bar.arm_powder = false
	check(g.ammo_line(0, "musketeer", bar).contains("off"), "[price] toggle off: '%s'" % g.ammo_line(0, "musketeer", bar))
	var m4: Unit = await _train(bar, "musketeer")
	check(m4 != null and m4.ammo_shots() == 0 and absf(float(g.players[0]["res2"]) - 100.0) < 0.01, "[toggle] off: 0 shots, the bank untouched")
	m4.cmd_move(bar.center() + Vector2(0, bar.size.y * Defs.TILE * 0.5 + 14))
	await wait(6.0)
	check(m4.ammo_shots() == 0, "[toggle] off: that Barracks refills nobody (%d)" % m4.ammo_shots())
	bar.arm_powder = true
	await wait(3.0)
	check(m4.ammo_shots() > 0, "[toggle] on again: it refills him (%d)" % m4.ammo_shots())
	# [refill] a dry one (the last, emptied; this Barracks off so only the Mill refills) goes to a Powder Mill
	m = m4
	m.powder = 0.0
	bar.arm_powder = false
	var mill: Building = g._add_building("powder_mill", 0, _free_cell(3, 3, 6, bar), true)
	await process_frame
	for u in g.units:
		if u.team == 0 and u != m and u._pmax > 0.0 and u.kind != "powder_wagon":
			u.powder = u._pmax          # (the others full: only he draws on the bank now)
			u.pistol = true if u.has_pistol() else u.pistol
	g.players[0]["res2"] = 4.0
	m.cmd_move(mill.center() + Vector2(0, mill.size.y * Defs.TILE * 0.5 + 14))
	var saw_reload := false
	for i in 120:
		await physics_frame
		if HUD.ammo_state(m)["state"] == "reloading":
			saw_reload = true
	for i in 30 * 6:
		await physics_frame
		if HUD.ammo_state(m)["state"] == "reloading":
			saw_reload = true
	print("  (m at %s, mill at %s cell %s, bar cell %s, dist %.0f)" % [str(m.position), str(mill.center()), str(mill.cell), str(bar.cell), mill.edge_distance(m.position)])
	check(saw_reload, "[card] RELOADING while he refills at the Mill")
	check(m.ammo_shots() == 4 and float(g.players[0]["res2"]) < 0.01, "[refill] 4 powder in the bank: 4 shots, the bank empty (%d, %.2f)" % [m.ammo_shots(), float(g.players[0]["res2"])])
	await wait(3.0)
	check(m.ammo_shots() == 4, "[refill] with the bank empty the refill waits (%d)" % m.ammo_shots())
	g.players[0]["res2"] = 50.0
	await wait(5.0)
	check(m.ammo_shots() == 10 and absf(float(g.players[0]["res2"]) - 44.0) < 0.05, "[refill] 1 powder a shot (%d shots, bank %.2f)" % [m.ammo_shots(), float(g.players[0]["res2"])])
	# [card] RELOADING between shots (the musket's own reload)
	m.cooldown = 2.0
	check(HUD.ammo_state(m)["state"] == "reloading" and float(HUD.ammo_state(m)["frac"]) < 1.0, "[card] RELOADING between shots (%s)" % str(HUD.ammo_state(m)))
	bar.arm_powder = true
	# [pistol] a mounted Horseman with nothing (the Breeder now stands)
	var br: Building = g._add_building("horse_breeder", 0, _free_cell(3, 3, 6, mill), true)
	await process_frame
	g.players[0]["cap"] = 200
	check(g.can_train(bar, "horseman") == "", "[req] with a Horse Breeder the Horseman may be trained (%s)" % g.can_train(bar, "horseman"))
	var h := g._add_unit("cuirassier", 0, mill.center() + Vector2(0, 160))
	h.set_ammo(0)
	check(HUD.ammo_state(h)["state"] == "no_ammo", "[card] the dry Horseman: NO AMMO")
	g.players[0]["res2"] = 50.0
	h.cmd_move(mill.center() + Vector2(0, mill.size.y * Defs.TILE * 0.5 + 16))
	await wait(9.0)
	check(h.pistol and h.is_mounted(), "[pistol] at the Mill his pistol is loaded, in the saddle")
	check(int(h.powder) == 4, "[pistol] ... and his charges filled (%d)" % int(h.powder))
	# [pistol] an Officer reloading his pistol on foot: RELOADING
	off2.pistol = false
	off2.pistol_t = 1.0
	check(HUD.ammo_state(off2)["state"] == "reloading", "[card] RELOADING while the Officer reloads his pistol")
	print("DONE: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


## Walks him out of the Barracks' reloading reach (a row of spots towards the hall, 7 tiles out).
func _park(u: Unit, b: Building, i: int) -> void:
	if u == null:
		return
	var hc: Vector2 = g.cell_center(o)
	var dir := (b.center() - hc).normalized()      # (away from the hall: out of its reach too)
	u.cmd_move(b.center() + dir * 7.0 * Defs.TILE + dir.orthogonal() * (i - 2) * 26.0)


## Trains one at the Barracks and waits for him (the newest unit of that kind on our side).
func _train(b: Building, key: String) -> Unit:
	var before := {}
	for u in g.units:
		before[u] = true
	g.players[0]["cap"] = 200
	var why := g.train(b, key)
	if why != "":
		print("  (train %s: %s)" % [key, why])
		return null
	for i in 30 * 40:
		await physics_frame
		for u in g.units:
			if not before.has(u) and u.team == 0 and not u.dead and u.kind == Defs.train_kind(key):
				print("  (trained %s: %s, %d shots)" % [key, u.kind, u.ammo_shots()])
				return u
	return null


## A free cell for a w x h building about `dist` tiles from the hall (or `from`).
func _free_cell(w: int, h: int, dist: int, from: Building = null) -> Vector2i:
	var c0: Vector2i = from.cell if from else o
	for r in range(dist, dist + 20):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := c0 + Vector2i(dx, dy)
				var ok := true
				for y in h + 2:
					for x in w + 2:
						if not g.is_free(c + Vector2i(x - 1, y - 1)) or not g.in_open_map(c + Vector2i(x - 1, y - 1)):
							ok = false
				if ok:
					return c
	return c0 + Vector2i(dist, 0)
