extends SceneTree
## RELOAD (the owner 2026-11-13; scripts/reload_order.gd, docs/reload_command.md).
##   godot --headless --fixed-fps 30 --script res://tools/test_reload_command.gd
##  [trip]     a half-empty Musketeer walks to the Powder Mill, fills up and comes back where he was
##  [full]     a full one is not sent (the order is refused, the button greys)
##  [none]     no source (an empty bank, no wagon): nobody goes, and the card says why
##  [dry]      the nearest source (a wagon) runs dry: on to the next (the Mill); the last runs dry: he stops with a message
##  [group]    a crowd spreads round the source (no two on one spot) and all come back full
##  [cannon]   a set-up Field Cannon limbers, refills and comes back
##  [queue]    Shift: the reload waits behind a move, and a move queued behind the reload follows it
##  [net]      a guest's RELOAD reaches the host through the order funnel (NetCommands "give"); no callables
##  [save]     saved mid-trip, loaded: on its way again, with the same place to come back to
const HUD := preload("res://scripts/ui/hud.gd")
var fails := 0
var g: Game
var main: Node
var o := Vector2i.ZERO
var hall: Building


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


func wait_for(f: Callable, s: float) -> bool:
	var until := g.clock + s
	var frames := int(s * 30.0) + 60          # (the game's clock may stop: never wait for ever)
	while g.clock < until and frames > 0:
		frames -= 1
		if f.call():
			return true
		await physics_frame
	return f.call()


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
	for b in g.buildings:
		if b.team == 0 and b.kind == "town_hall":
			hall = b
	o = hall.cell
	g.players[0]["gold"] = 5000
	g.players[0]["cap"] = 200
	g.players[0]["res2"] = 200.0
	var mill: Building = g._add_building("powder_mill", 0, _free_cell(3, 3, 14), true)
	await process_frame
	var away := (mill.center() - hall.center()).normalized()
	var spot := mill.center() + away * 9.0 * Defs.TILE        # (out of the hall's and the Mill's reach)
	spot = g.cell_center(g.nearest_free(g.cell_of(spot), 6))

	# [trip]
	var m := g._add_unit("musketeer", 0, spot)
	await physics_frame
	m.set_ammo(5)
	check(ReloadOrder.wants(m), "[trip] 5/10: he wants a reload")
	check(ReloadOrder.nearest(m) == mill, "[trip] the nearest powder is the Mill (%s)" % str(ReloadOrder.nearest(m)))
	var bank0 := float(g.players[0]["res2"])
	m.give({"o": "reload"})
	check(m.order == "reload" and m.order_target == mill, "[trip] the order: off to the Mill (%s)" % m.order)
	var ok := await wait_for(func() -> bool: return m.ammo_shots() >= 10, 40.0)
	check(ok, "[trip] full at the Mill (%d/%d)" % [m.ammo_shots(), m.ammo_max()])
	check(absf(bank0 - float(g.players[0]["res2"]) - 5.0) < 0.05, "[trip] the bank paid 5 (%.2f)" % (bank0 - float(g.players[0]["res2"])))
	ok = await wait_for(func() -> bool: return m.order == "idle", 40.0)
	check(ok and m.position.distance_to(spot) < 40.0, "[trip] back where he was (%.0f px off, %s)" % [m.position.distance_to(spot), m.order])

	# [full]
	check(not ReloadOrder.wants(m), "[full] full: no reload wanted")
	m.give({"o": "reload"})
	check(m.order == "idle", "[full] a full man is not sent (%s)" % m.order)
	var list: Array = []
	ReloadOrder.card(g.hud, list, [m])
	check(list.size() == 1 and list[0][1] == "RELOAD" and not list[0][3] and String(list[0][4]) != "", "[full] the button is there but greyed: %s" % (str(list[0].slice(1, 6)) if not list.is_empty() else "none"))
	check(HUD.FIXED_KEYS.get("RELOAD", "") == "R", "[card] RELOAD's key is R")
	check(ResourceLoader.exists("res://assets/icons/ab_reload.png"), "[card] its icon")
	var lone := g._add_unit("labourer", 0, spot)
	list = []
	ReloadOrder.card(g.hud, list, [lone])
	check(list.is_empty(), "[card] no RELOAD on a card with no firearm")

	# [none]
	g.players[0]["res2"] = 0.0
	m.set_ammo(2)
	check(ReloadOrder.nearest(m) == null, "[none] an empty bank and no wagon: nothing can fill him")
	g.set_selection([m])
	list = []
	ReloadOrder.card(g.hud, list, [m])
	(list[0][2] as Callable).call()
	check(m.order != "reload", "[none] RELOAD sends nobody (%s)" % m.order)
	check(String(g.hud._msg).begins_with("No Powder Wagon"), "[none] ... and says why: '%s'" % g.hud._msg)

	# [dry] a wagon nearer than the Mill with 3 shots, the bank with a little powder: the wagon, then the Mill
	m.set_ammo(0)
	var wpos := spot + away.orthogonal() * 3.0 * Defs.TILE
	var wag := g._add_unit("powder_wagon", 0, g.cell_center(g.nearest_free(g.cell_of(wpos), 6)))
	await physics_frame
	wag.powder = 3.0
	g.players[0]["res2"] = 30.0
	check(ReloadOrder.nearest(m) == wag, "[dry] the nearest powder is the wagon (%s)" % str(ReloadOrder.nearest(m)))
	m.give({"o": "reload"})
	ok = await wait_for(func() -> bool: return wag.powder < 0.01, 30.0)
	check(ok and m.ammo_shots() >= 3, "[dry] he empties the wagon (%d shots, wagon %.1f)" % [m.ammo_shots(), wag.powder])
	ok = await wait_for(func() -> bool: return m.order == "reload" and m.order_target == mill, 10.0)
	check(ok, "[dry] ... then goes on to the Mill (%s, %s)" % [m.order, str(m.order_target)])
	ok = await wait_for(func() -> bool: return m.ammo_shots() >= 10, 40.0)
	check(ok, "[dry] ... and fills up there (%d)" % m.ammo_shots())
	await wait_for(func() -> bool: return m.order == "idle", 40.0)
	# the last source runs dry: he stops with a message
	g.players[0]["res2"] = 0.0
	wag.powder = 2.0
	m.set_ammo(0)
	g._notify_t = 0
	m.give({"o": "reload"})
	ok = await wait_for(func() -> bool: return m.order != "reload", 40.0)
	check(ok and m.ammo_shots() == 2, "[dry] the only wagon runs dry: he takes its 2 shots and stops (%d, %s)" % [m.ammo_shots(), m.order])
	check(String(g.hud._msg).begins_with("No more powder"), "[dry] ... with a message: '%s'" % g.hud._msg)
	g.consume_unit(wag)
	g.players[0]["res2"] = 300.0

	# [group]
	var men: Array = []
	for i in 6:
		var u := g._add_unit("musketeer", 0, spot + away.orthogonal() * (i - 2.5) * 24.0)
		men.append(u)
	await physics_frame
	for u in men:
		u.set_ammo(3)
		u.give({"o": "reload"})
	var pts: Array = men.map(func(u: Unit) -> Vector2: return u.order_point)
	var apart := true
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			if (pts[i] as Vector2).distance_to(pts[j]) < 12.0:
				apart = false
	check(apart, "[group] six places round the source, none shared")
	ok = await wait_for(func() -> bool: return men.all(func(u: Unit) -> bool: return u.ammo_shots() >= 10 and u.order == "idle"), 60.0)
	check(ok, "[group] all six full and back (%s)" % str(men.map(func(u: Unit) -> String: return "%d %s" % [u.ammo_shots(), u.order])))
	var home := men.all(func(u: Unit) -> bool: return u.position.distance_to(spot) < 140.0)
	check(home, "[group] ... back by where they started")
	for u in men:
		g.consume_unit(u)

	# [cannon] set up, 2 of 8 shots
	var gun := g._add_unit("cannon", 0, spot + away.orthogonal() * -2.0 * Defs.TILE)
	await physics_frame
	var gspot := gun.position
	gun.powder = 2.0
	gun.tesla_mode = "deployed"
	check(ReloadOrder.wants(gun), "[cannon] 2/8: a reload wanted")
	gun.give({"o": "reload"})
	check(gun.order == "reload", "[cannon] the order is taken (%s)" % gun.order)
	ok = await wait_for(func() -> bool: return gun.tesla_mode == "packed", 10.0)
	check(ok, "[cannon] it limbers to go")
	ok = await wait_for(func() -> bool: return gun.ammo_shots() >= 8, 60.0)
	check(ok, "[cannon] full at the Mill (%d/%d)" % [gun.ammo_shots(), gun.ammo_max()])
	ok = await wait_for(func() -> bool: return gun.order == "idle", 60.0)
	check(ok and gun.position.distance_to(gspot) < 60.0, "[cannon] back where it stood (%.0f px)" % gun.position.distance_to(gspot))
	# a gun with no horse can't go
	gun.harnessed = false
	gun.powder = 1.0
	gun.give({"o": "reload"})
	check(gun.order != "reload", "[cannon] with no horse it can't go (%s)" % gun.order)
	gun.harnessed = true

	# [queue] Shift: a move first, then the reload, then a move
	m.set_ammo(4)
	var a := spot + away.orthogonal() * 4.0 * Defs.TILE
	var b2 := spot - away.orthogonal() * 4.0 * Defs.TILE
	m.give({"o": "move", "p": a})
	m.give({"o": "reload"}, true)
	m.give({"o": "move", "p": b2}, true)
	check(m.order == "move" and m.queue.size() == 2, "[queue] the reload waits behind the move (%s, %d queued)" % [m.order, m.queue.size()])
	ok = await wait_for(func() -> bool: return m.order == "reload", 30.0)
	check(ok, "[queue] then he goes to reload")
	ok = await wait_for(func() -> bool: return m.ammo_shots() >= 10, 40.0)
	check(ok, "[queue] full")
	ok = await wait_for(func() -> bool: return m.order == "idle" and m.queue.is_empty(), 60.0)
	check(ok and m.position.distance_to(b2) < 50.0, "[queue] back to where the reload began, then on to the queued move (%.0f px off)" % m.position.distance_to(b2))

	# [net] the host runs a guest's RELOAD
	check(NetCommands.ENTITY.has("give"), "[net] RELOAD goes as an order (give) through the online funnel")
	var hs := NetSession.new()
	hs.game = g
	hs.is_host = true
	hs.peer_team = {5: 0}
	var nm := g._add_unit("musketeer", 0, spot)
	await physics_frame
	nm.set_ammo(1)
	hs.assign(nm)
	hs.by_id = {nm.net_id: nm}
	var why := NetCommands.apply(hs, 5, {"o": nm.net_id, "f": "give", "a": [{"o": "reload"}, false]})
	check(why == "" and nm.order == "reload", "[net] the host sends the guest's man to reload (%s, %s)" % [why if why != "" else "ok", nm.order])
	nm.cmd_stop()
	g.consume_unit(nm)

	# [save] mid-trip
	m.set_ammo(1)
	var sp := m.position
	m.give({"o": "reload"})
	await wait(1.5)
	check(m.order == "reload", "[save] on his way")
	print("  (over %s, demo %s)" % [g.over, g.demo])
	var d := SaveGame.capture(g, {"map": "greenhold", "seed": 7}, true)      # (the test match counts as a demo: taken as a replay keyframe is)
	var rows: Array = Array(d.get("units", [])).filter(func(ud) -> bool: return ud is Dictionary and ud.has("rld"))
	check(rows.size() == 1 and Vector2(float(rows[0]["rld"][0]), float(rows[0]["rld"][1])).distance_to(sp) < 1.0, "[save] the save keeps the trip (%d)" % rows.size())
	var g2 := Game.new()
	g2.map_id = "greenhold"
	g2.demo = true
	g2.factions = ["crown", "brood"]
	g2.sides = [0, 1]
	root.add_child(g2)
	await process_frame
	await process_frame
	SaveGame.restore(g2, d)
	await process_frame
	var back: Array = g2.units.filter(func(u: Unit) -> bool: return u.kind == "musketeer" and u.position.distance_to(m.position) < 24.0)
	print("  (musketeers loaded: %s; ours at %s)" % [str(g2.units.filter(func(u: Unit) -> bool: return u.kind == "musketeer").map(func(u: Unit) -> String: return "%s %s" % [str(u.position), u.order])), str(m.position)])
	check(back.size() == 1 and back[0].order == "reload" and (back[0].rl["back"] as Vector2).distance_to(sp) < 1.0, "[save] loaded: on his way to reload again, same place to come back to (%s)" % (back[0].order if back.size() == 1 else str(back.size())))
	g2.queue_free()
	print("DONE: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


## A free cell for a w x h building about `dist` tiles from the hall.
func _free_cell(w: int, h: int, dist: int) -> Vector2i:
	for r in range(dist, dist + 20):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := o + Vector2i(dx, dy)
				var ok := true
				for y in h + 2:
					for x in w + 2:
						if not g.is_free(c + Vector2i(x - 1, y - 1)) or not g.in_open_map(c + Vector2i(x - 1, y - 1)):
							ok = false
				if ok:
					return c
	return o + Vector2i(dist, 0)
