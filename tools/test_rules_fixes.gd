extends SceneTree
## RULES FIXES (rules-fixes, owner 2026-11-11; docs/rules_fixes.md).
##   godot --headless --fixed-fps 30 --script res://tools/test_rules_fixes.gd
##  [bonus]    a Field Cannon and a Mortar do the same to a building whether told to attack it or to ATTACK GROUND on it,
##             and that is the card's figure (damage x building bonus, + the round shot's splash for the cannon)
##  [card]     ATTACK is not on the card of an unarmed unit (Powder Wagon, Messenger, Balloon, Band, Missionary) and A
##             does not start an attack for them; a mixed selection keeps it
##  [helpless] a side with no workers, no army and no way to make more is beaten after Game.HELPLESS_TIME; a side with
##             a hall and the price of a worker is not; one with a Musketeer is not
##  [anim]     the dismounted Officer reloading and an uprooted Mound Turtle fighting ask for strips that exist
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


func _start(f1: String, f2: String) -> void:
	if main:
		main.queue_free()
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": "greenhold", "seed": 7, "slots": [
		{"who": "you", "faction": f1, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": f2, "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED


func _free_cell(w: int, h: int, from: Vector2i) -> Vector2i:
	for r in range(0, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := from + Vector2i(dx, dy)
				var ok := true
				for y in h + 2:
					for x in w + 2:
						var cc := c + Vector2i(x - 1, y - 1)
						if not g.in_open_map(cc) or not g.is_free(cc):
							ok = false
				if ok:
					return c
	return from


func _run() -> void:
	await _start("crown", "crown")
	await _bonus()
	await _card()
	await _anim()
	await _helpless()
	print("DONE: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


func _shot_on(kind: String, bombard: bool) -> float:
	var mid := Vector2i(g.W / 2, g.H / 2)
	var bc := _free_cell(3, 3, mid)
	var bd: Building = g._add_building("cottage", 1, bc, true)
	bd.max_hp = 99999.0
	bd.hp = 99999.0
	bd.armor = 0
	await process_frame
	var spot := bd.center() + Vector2(260, 0)
	var u: Unit = g._add_unit(kind, 0, spot)
	u.auto_work = false
	if Defs.AMMO.has(kind):
		u.set_ammo(Defs.ammo_full(kind))
	await wait(0.5)
	var hp0 := bd.hp
	if bombard:
		u.cmd_bombard(bd.center())
	else:
		u.cmd_attack(bd)
	var first := -1.0
	var t_end := g.clock + 25.0
	while g.clock < t_end:
		await physics_frame
		if bd.hp < hp0 - 0.01:
			# one shot's whole effect (the ball and its splash land together)
			await wait(0.3)
			first = hp0 - bd.hp
			break
	u.die()
	g._remove_quietly(bd)
	await wait(0.5)
	return first


func _bonus() -> void:
	for k in ["cannon", "mortar"]:
		var d: Dictionary = Defs.UNITS[k]
		var want := UnitStats.building_hit(k, d, float(d["damage"]))
		var a := await _shot_on(k, false)
		var b := await _shot_on(k, true)
		check(a > 0.0 and absf(a - want) < want * 0.15, "[bonus] %s told to attack a building: one shot %.0f (card %.0f)" % [k, a, want])
		check(b > 0.0 and absf(b - want) < want * 0.15, "[bonus] %s ATTACK GROUND on the building: one shot %.0f (card %.0f)" % [k, b, want])


func _labels_for(units: Array) -> Array:
	g.hud.page = ""
	if g.controls.mode != "":
		g.controls.cancel_mode()
	g.set_selection(units)
	await physics_frame
	var out: Array = []
	if g.selected_units().is_empty():
		print("  (nothing selected: demo ", g.demo, " human ", g.human, " ", g.selection.size(), " ", units.map(func(x): return [x.team, x.dead, x.position]), ")")
	for it in g.hud._build_card():
		out.append(String(it[1]))
	return out


func _card() -> void:
	var at := g.cell_center(_free_cell(1, 1, Vector2i(g.W / 2, g.H / 2 + 6)))
	for k in ["powder_wagon", "messenger", "balloon", "band", "band_fifer", "band_piper", "missionary", "mounted_missionary"]:
		if not Defs.UNITS.has(k):
			continue
		var u: Unit = g._add_unit(k, 0, at)
		await process_frame
		var labs: Array = await _labels_for([u])
		check(not labs.has("ATTACK"), "[card] %s: no ATTACK (%s)" % [k, ", ".join(labs)])
		check(not u.armed(), "[card] %s is unarmed" % k)
		u.die()
	var m: Unit = g._add_unit("musketeer", 0, at)
	var w: Unit = g._add_unit("powder_wagon", 0, at + Vector2(30, 0))
	await process_frame
	var labs2: Array = await _labels_for([m, w])
	check(labs2.has("ATTACK"), "[card] a Musketeer and a Powder Wagon together: ATTACK kept")
	g.set_selection([])
	m.die()
	w.die()


func _anim() -> void:
	var at := g.cell_center(_free_cell(1, 1, Vector2i(g.W / 2, g.H / 2 - 6)))
	var off: Unit = g._add_unit("dismounted", 0, at)
	await process_frame
	var fr: Dictionary = ArtData.UNITS[off.art]["frames"]
	check(not BroodNew.has_strip(fr, "reload") and off._anim_or("reload", "idle") == "idle", "[anim] the Officer has no reload strip: idle")
	off.die()
	var tf: Dictionary = ArtData.UNITS["mound_turtle"]["frames"] if ArtData.UNITS.has("mound_turtle") else {}
	check(not BroodNew.has_strip(tf, "attack") and BroodNew.has_strip(tf, "walk"), "[anim] the Mound Turtle: no attack strip, walk/idle used")


func _helpless() -> void:
	await _start("crown", "clockwork")
	# team 1 (the Clockwork): every unit gone, the bank empty: helpless
	for u in g.units.duplicate():
		if u.team == 1 and not u.dead:
			u.die()
	g.players[1]["gold"] = 0
	for b in g.buildings:
		if b.team == 1:
			b.queue.clear()
	await wait(2.0)
	check(g.helpless(1), "[helpless] no units and no gold: helpless")
	if not g.helpless(1):
		for u in g.units:
			if u.team == 1 and not u.dead:
				print("  left: ", u.kind)
		for b in g.buildings:
			if b.team == 1 and not b.dead:
				print("  bld: ", b.kind, " built ", b.built, " q ", b.queue, " trains ", b.d.get("trains", []), " gold ", g.players[1]["gold"])
	# team 0 (the Crown): only its hall and enough gold for a Labourer: not helpless
	for u in g.units.duplicate():
		if u.team == 0 and not u.dead:
			u.die()
	g.players[0]["gold"] = 500
	await wait(1.0)
	check(not g.helpless(0), "[helpless] a hall and the price of a worker: not helpless")
	g.players[0]["gold"] = 0
	var mu: Unit = g._add_unit("musketeer", 0, g.cell_center(_free_cell(1, 1, Vector2i(g.W / 2, g.H / 2))))
	await wait(1.0)
	check(not g.helpless(0), "[helpless] a Musketeer alive: not helpless")
	var t0 := g.clock
	while not g.over and g.clock - t0 < Game.HELPLESS_TIME + 10.0:
		await physics_frame
	check(g.over and g.winner == 0, "[helpless] the helpless side is beaten after %.0f s (over %s, winner %d)" % [g.clock - t0, g.over, g.winner])
	check(g.clock - t0 >= Game.HELPLESS_TIME - 4.0, "[helpless] ... not before its minute")
	mu.die()
