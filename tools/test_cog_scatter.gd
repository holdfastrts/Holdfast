extends SceneTree
## SCATTER COGS (the Great Winder's slow field: scripts/cog_scatter.gd, Defs.COG_SCATTER, docs/cog_scatter.md): ordered
## through the spells' pipeline (Game.cast_order "scatter"), the Winder winds up, pays its cogs and throws; once the pieces
## land, ENEMY ground units in the litter walk about 40% slower (Defs.COG_SCATTER "slow"), one walking beside it outside
## does not, a flyer over it does not, a Clockwork unit of its own side does not; the field ends after its time; the
## hopper's cooldown and the price are kept (a second throw too soon, or with too few cogs, is refused); its looks (the
## pieces in the air and the litter) are on the layer; a save keeps the cooldown; online, a guest's order reaches the host
## through the command funnel, the guest gets the cooldown and the slowed mark in the snapshot rows (which replays record)
## and sees the throw from the effect row; the computer throws it on a clump of charging melee, not on a standing one.
##   godot --headless --fixed-fps 30 --script res://tools/test_cog_scatter.gd
const U := preload("res://tools/gear_test_util.gd")
const K := Defs.GREAT_WINDER_KIND
const S := Defs.COG_SCATTER
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-78s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root, ["clockwork", "crown"])
	await process_frame
	await process_frame
	_card(g)
	_slow(g)
	await _save(g)
	g.queue_free()
	await process_frame
	await _online()
	await _computer()
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ helpers

func _clear(g: Game) -> void:
	for u in g.units.duplicate():
		if is_instance_valid(u) and not u.is_worker():
			g.units.erase(u)
			g.selection.erase(u)
			u.queue_free()
	for u in g.units:
		u.auto_work = false
		u.auto_repair = false
		u.cmd_stop()
	g.zones.clear()


func _spot(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	return g.cell_center(c if g.is_free(c) else g.nearest_free(c, 6))


## Open, flat ground away from the halls: a box of 700 x 500 px with nothing in it.
func _open(g: Game) -> Vector2:
	var hall := U.hall(g, 0)
	for r in [800.0, 1000.0, 1200.0, 600.0, 1400.0]:
		for deg in range(0, 360, 15):
			var p: Vector2 = g.on_map(hall.center() + Vector2.from_angle(deg_to_rad(deg)) * r)
			var ok := true
			var lv := g.level_of(p)
			for dx in range(-350, 351, 50):
				for dy in range(-250, 251, 50):
					var q: Vector2 = p + Vector2(dx, dy)
					var c := g.cell_of(q)
					if not g.in_map(c) or not g.is_free(c) or g.level_of(q) != lv or g.water[g.idx(c)] != 0:
						ok = false
			if ok:
				return g.cell_center(g.cell_of(p))
	return g.cell_center(g.cell_of(g.on_map(hall.center() + Vector2(900, 0))))


func _gw(g: Game, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(K, 0, p)
	u.auto_repair = false
	u.auto_sweep = false
	u.cmd_stop()
	g.camera.position = p
	g.view_rect = Rect2(p - Vector2(900, 600), Vector2(1800, 1200))
	return u


func _man(g: Game, kind: String, team: int, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, team, p)
	u.auto_work = false
	u.auto_repair = false
	u.d = u.d.duplicate()
	u.d["damage"] = 0
	u.cmd_stop()
	return u


## The Winder throws at p (the order, the windup, the throw): steps until the field is in Game.zones.
func _throw(g: Game, gw: Unit, p: Vector2) -> Dictionary:
	g.cast_order([gw], CogScatter.SPELL, p)
	for i in 120:
		U.step(g, 1.0 / 30.0)
		for z in g.zones:
			if z["kind"] == CogScatter.SPELL:
				return z
	return {}


# ------------------------------------------------------------------ the card

func _card(g: Game) -> void:
	check("Defs: range 6 tiles, radius 2.5 tiles, 40% slower, 15 s, 40 cogs, 25 s", is_equal_approx(float(S["range"]), 6.0 * Defs.TILE)
		and is_equal_approx(float(S["radius"]), 2.5 * Defs.TILE) and is_equal_approx(float(S["slow"]), 0.6) and is_equal_approx(float(S["time"]), 15.0)
		and int(S["cost"]) == 40 and is_equal_approx(float(S["cooldown"]), 25.0) and not bool(S["slows_own"]) and not bool(S["air"]))
	check("the Great Winder casts it (Game.CASTERS)", String(Game.CASTERS.get("scatter", "")) == K and Game.spell_info("scatter") == S)
	check("the card has a fixed key (C)", String(load("res://scripts/ui/hud.gd").FIXED_KEYS.get("SCATTER COGS", "")) == "C")
	check("translated (pt, es)", Loc.table("pt").has("SCATTER COGS") and Loc.table("es").has("SCATTER COGS"))


# ------------------------------------------------------------------ the slow

func _slow(g: Game) -> void:
	_clear(g)
	var at := _open(g)
	var gw := _gw(g, at + Vector2(-200, -120))
	g.players[0]["gold"] = 1000
	var spot := at
	# the walkers: an enemy through the middle, its twin outside (the control), a flyer over the middle, our own soldier
	var foe: Unit = _man(g, "musketeer", 1, spot + Vector2(-60, 0))
	var twin: Unit = _man(g, "musketeer", 1, spot + Vector2(-60, 200))
	var flyer: Unit = _man(g, "balloon", 1, spot + Vector2(-50, -10))
	var own: Unit = _man(g, "clock_soldier", 0, spot + Vector2(-60, 30))
	own.wind = 1.0
	check("the balloon flies (is_air)", flyer.is_air())
	var gold0 := int(g.players[0]["gold"])
	var z := _throw(g, gw, spot)
	check("the order: it winds up and throws (a field in Game.zones)", not z.is_empty())
	if z.is_empty():
		return
	check("the throw costs %d cogs" % int(S["cost"]), int(g.players[0]["gold"]) == gold0 - int(S["cost"]), "%d -> %d" % [gold0, int(g.players[0]["gold"])])
	check("the hopper empties for %d s" % int(S["cooldown"]), absf(gw.scatter_ready - float(g.clock) - float(S["cooldown"])) < 0.1, "%.2f" % (gw.scatter_ready - g.clock))
	check("the pieces fly (the layer has the field, %d pieces)" % int(S["parts"]), g.cog_layer != null and g.cog_layer.fields.size() == 1
		and (g.cog_layer.fields[0]["pieces"] as Array).size() == int(S["parts"]))
	U.step(g, 0.2)
	check("nobody is slowed while the pieces are in the air", foe.litter_t <= 0.0)
	# a second throw at once: refused (the hopper)
	var n0 := g.zones.size()
	g.cast_order([gw], CogScatter.SPELL, spot + Vector2(40, 0))
	U.step(g, 1.0)
	check("a second throw too soon is refused (cooldown)", g.zones.size() == n0 and gw.order != "cast", CogScatter.problem(gw))
	U.step(g, float(S["flight"]))
	# now walk: everybody east, the same way
	for u in [foe, twin, own]:
		u.cmd_move(u.position + Vector2(600, 0))
	flyer.cmd_move(flyer.position + Vector2(600, 0))
	U.step(g, 0.5)
	var p0 := {foe: foe.position, twin: twin.position, flyer: flyer.position, own: own.position}
	var still_in: bool = g.in_ellipse(spot, foe.position, float(S["radius"]))
	U.step(g, 0.8)
	still_in = still_in and g.in_ellipse(spot, foe.position, float(S["radius"]))
	var d_foe: float = foe.position.distance_to(p0[foe])
	var d_twin: float = twin.position.distance_to(p0[twin])
	var ratio := d_foe / maxf(d_twin, 0.001)
	check("the enemy walked inside the litter the whole time", still_in)
	check("the enemy in the litter is about 40%% slower (%.2f of its twin's pace outside)" % ratio, absf(ratio - float(S["slow"])) < 0.06, "%.1f vs %.1f px" % [d_foe, d_twin])
	check("the twin outside is not slowed", twin.litter_t <= 0.0 and not twin.littered)
	check("it shows: slowed (streamed `littered`, the cogs round its feet)", foe.littered and g.cog_layer.marked.has(foe))
	check("the flyer over it is not slowed", flyer.litter_t <= 0.0)
	check("our own Clock Soldier in it is not slowed", own.litter_t <= 0.0 and g.in_ellipse(spot, p0[own], float(S["radius"])))
	# the field lasts its time, then it is gone
	var cam := foe
	foe.cmd_stop()
	foe.position = spot
	cam.cmd_hold()
	U.step(g, float(S["time"]) - 3.0)
	check("still slowed near the end of its %d s" % int(S["time"]), foe.litter_t > 0.0)
	U.step(g, 3.5)
	check("after its time the field is gone and nobody is slowed", not g.zones.any(func(zz) -> bool: return zz["kind"] == "scatter") and foe.litter_t <= 0.0 and not foe.littered)
	U.step(g, 1.0)
	g.cog_layer._process(1.0 / 30.0)          # (its frame: U.step runs the game's ticks only)
	check("and its looks are gone", g.cog_layer.fields.is_empty())
	# the cooldown runs out (25 s from the throw: 16+ s gone): wait and throw again; too few cogs: refused
	U.step(g, float(S["cooldown"]) - float(S["time"]) - float(S["flight"]) - 2.0)
	g.players[0]["gold"] = int(S["cost"]) - 1
	check("ready again after the cooldown, but with %d cogs it is refused" % (int(S["cost"]) - 1), gw.scatter_ready <= g.clock and CogScatter.problem(gw).begins_with("Not enough cogs"), CogScatter.problem(gw))
	g.cast_order([gw], CogScatter.SPELL, spot)
	U.step(g, 1.5)
	check("no throw without the cogs", not g.zones.any(func(zz) -> bool: return zz["kind"] == "scatter") and int(g.players[0]["gold"]) == int(S["cost"]) - 1)
	g.players[0]["gold"] = 500
	# out of range: it rolls closer first
	var far := gw.position + Vector2(float(S["range"]) + 120.0, 0)
	g.cast_order([gw], CogScatter.SPELL, far)
	var z2 := {}
	for i in 600:
		U.step(g, 1.0 / 30.0)
		for zz in g.zones:
			if zz["kind"] == "scatter":
				z2 = zz
		if not z2.is_empty():
			break
	check("a spot out of reach: it rolls within %d tiles, then throws" % int(round(float(S["range"]) / Defs.TILE)), not z2.is_empty() and gw.position.distance_to(far) <= float(S["range"]) + 2.0,
		"%.0f px" % gw.position.distance_to(far))
	set_meta("gw_pos", gw.position)


func _save(g: Game) -> void:
	var gw: Unit = null
	for u in g.units:
		if u.kind == K and not u.dead:
			gw = u
	var left := gw.scatter_ready - g.clock
	g.demo = false              # (a demo is never saved)
	var d := SaveGame.capture(g, {"map": g.map_id, "seed": 1})
	g.demo = true
	d = JSON.parse_string(JSON.stringify(d))          # (as the file keeps it)
	var g2 := Game.new()
	g2.map_id = g.map_id
	g2.demo = true
	g2.factions = g.factions
	g2.sides = [0, 1]
	root.add_child(g2)
	await process_frame
	await process_frame
	SaveGame.restore(g2, d)
	await process_frame
	var back: Array = g2.units.filter(func(u: Unit) -> bool: return u.kind == K)
	check("a save keeps the hopper's countdown", back.size() == 1 and absf((back[0].scatter_ready - g2.clock) - left) < 0.1,
		"%.2f vs %.2f" % [(back[0].scatter_ready - g2.clock) if not back.is_empty() else -1.0, left])
	g2.queue_free()
	await process_frame


# ------------------------------------------------------------------ online

func _online() -> void:
	var h := U.make(root, ["clockwork", "crown"])
	var gu := Game.new()
	gu.map_id = h.map_id
	gu.demo = true
	gu.factions = ["clockwork", "crown"]
	gu.sides = [0, 1]
	gu.puppet = true
	root.add_child(gu)
	await process_frame
	await process_frame
	var sh := NetSession.attach(h, NetLink.new(), true, 0, {5: 0})
	var sg := NetSession.attach(gu, NetLink.new(), false, 1, {})
	sh.set_process(false)
	var sync := func() -> void:
		sh.snap_n = 1
		var m := NetSnapshot.build(sh)
		NetSnapshot.apply(sg, NetCodec.unpack(NetCodec.pack(m)))
	var at := _open(h)
	var gw: Unit = _gw(h, at + Vector2(-150, 0))
	h.players[0]["gold"] = 500
	var foe: Unit = _man(h, "musketeer", 1, at)
	sync.call()
	# a guest's order through the funnel
	check("the order is in the online command funnel", NetCommands.GAME.has("cast_order"))
	sh.assign(gw)
	var why := NetCommands.apply(sh, 5, {"o": 0, "f": "cast_order", "a": [[{"e": gw.net_id}], "scatter", at]})
	check("the host runs a guest's SCATTER COGS", why == "" and gw.order == "cast" and gw.cast_spell == "scatter", why)
	sh.fx.clear()
	for i in 60:
		U.step(h, 1.0 / 30.0)
		if gw.scatter_ready > 0.0:
			break
	check("the host threw it (paid, cooldown)", gw.scatter_ready > h.clock and int(h.players[0]["gold"]) == 500 - int(S["cost"]))
	var rows: Array = sh.fx.filter(func(f: Array) -> bool: return f[0] == "k")
	check("the throw goes to the guest as an effect row", rows.size() == 1)
	U.step(h, float(S["flight"]) + 0.2)
	check("the host's enemy in it is slowed", foe.littered)
	sync.call()                 # (the snapshot carries the effect rows: NetSnapshot.apply plays them)
	var gg: Unit = null
	var gf: Unit = null
	for u in gu.units:
		if u.net_id == gw.net_id:
			gg = u
		if u.net_id == foe.net_id:
			gf = u
	check("the guest gets the hopper's countdown", gg != null and absf(gg.scatter_ready - gw.scatter_ready) < 0.02)
	check("the guest's copy of the enemy shows slowed", gf != null and gf.littered and gu.cog_layer != null and gu.cog_layer.marked.has(gf))
	check("the guest sees the throw and the litter (looks only)", gu.cog_layer != null and gu.cog_layer.fields.size() == 1 and gu.zones.is_empty())
	check("the check lists match", NetSnapshot.check_lists(gw, null) == "", NetSnapshot.check_lists(gw, null))
	check("replays carry it (snapshot properties; the effect row)", NetSnapshot.UNIT_PROPS.has("scatter_ready") and NetSnapshot.UNIT_PROPS.has("littered") and ReplayRecorder.new().has_method("note_scatter"))
	sg.queue_free()
	sh.queue_free()
	h.queue_free()
	gu.queue_free()
	await process_frame


# ------------------------------------------------------------------ the computer

func _computer() -> void:
	var g := U.make(root, ["clockwork", "brood"])
	await process_frame
	await process_frame
	_clear(g)
	var at := _open(g)
	var gw: Unit = _gw(g, at)
	g.players[0]["gold"] = 1000
	# a standing clump: no throw
	var pack: Array = []
	for i in 6:
		var rp: Unit = _man(g, "raptor", 1, at + Vector2(170 + (i % 3) * 18, -20 + (i / 3) * 22))
		rp.d["damage"] = Defs.UNITS["raptor"]["damage"]       # (armed: melee counts)
		rp.cmd_hold()
		pack.append(rp)
	U.step(g, 0.3)
	CogScatter.ai_tick(g, 0)
	check("the computer does not throw on a clump standing still", gw.order != "cast")
	# the clump charges at it: a throw, ahead of them
	for e in pack:
		e.cmd_move(gw.position + Vector2(0, (e as Unit).position.y - at.y))
	U.step(g, 0.4)
	var sees := pack.all(func(e: Unit) -> bool: return g.side_sees(0, e.position))
	CogScatter.ai_tick(g, 0)
	check("on %d charging Raptors it throws SCATTER COGS (they are seen: %s)" % [pack.size(), sees], gw.order == "cast" and gw.cast_spell == "scatter")
	if gw.order == "cast":
		var mid := Vector2.ZERO
		for e in pack:
			mid += (e as Unit).position
		mid /= pack.size()
		check("aimed ahead of them, toward it", gw.cast_at.distance_to(gw.position) < mid.distance_to(gw.position), "%.0f vs %.0f" % [gw.cast_at.distance_to(gw.position), mid.distance_to(gw.position)])
	g.queue_free()
	await process_frame
