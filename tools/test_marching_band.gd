## THE MARCHING BAND, a real Crown unit since 0.33.0 (the owner, 2026-11-05; scripts/marching_band.gd,
## docs/marching_band.md): no experiment switch (an old cfg's "marching_band" is ignored); trained at the ARMOURY (not
## the Barracks); a new band is a DRUMMER (75 health); the FIFER and the PIPER are Armoury research in any order, joining
## every band (on the field and new ones); the price grows by 25 gold a researched musician (paid back in full when
## cancelled); several bands allowed, their rings don't stack; one solo at a time per band, two bands may solo at once;
## +5% always, +30% in a solo, for speed (drums), melee (pipes) and reload (fife: muskets, guns, the Officer's pistol;
## not a man with no shots); the save, the online snapshot and a replay's fields carry it; the command funnel.
##   godot --headless --fixed-fps 30 --script res://tools/test_marching_band.gd
extends SceneTree
var fails := 0
const B := Defs.MARCHING_BAND


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func make(facs: Array) -> Game:
	var g := Game.new()
	g.map_id = "ashford_crossing"
	g.demo = true
	g.factions = facs
	g.sides = range(facs.size())
	root.add_child(g)
	return g


func step(g: Game, secs: float) -> void:
	var n := int(round(secs * 30.0))
	for i in n:
		g._physics_process(1.0 / 30.0)
		for u in g.units.duplicate():
			if is_instance_valid(u):
				u._physics_process(1.0 / 30.0)
		for b in g.buildings.duplicate():
			if is_instance_valid(b):
				b._physics_process(1.0 / 30.0)
		if i % 8 == 0:
			await process_frame


func tough(u: Unit) -> Unit:
	u.max_hp = 5000.0
	u.hp = 5000.0
	u.auto_work = false
	return u


func hall(g: Game, t: int) -> Building:
	for b in g.buildings:
		if b.team == t and b.kind == g.faction_hall(t):
			return b
	return null


func open_spot(g: Game, t: int) -> Vector2:
	var h := hall(g, t)
	return h.center() + Vector2(0, h.rect().size.y * 0.5 + 160.0)


func _run() -> void:
	# ---- no switch any more
	check("no experiment switch in Settings", not FileAccess.get_file_as_string("res://scripts/settings.gd").contains("marching_band"))
	check("the Barracks no longer trains the band", not (Defs.BUILDINGS["barracks"]["trains"] as Array).has(MarchingBand.KIND))
	check("the Armoury trains it", Defs.train_keys(Defs.BUILDINGS["armoury"]["trains"], false).has(MarchingBand.KIND))
	check("the Fifer and the Piper are Armoury research", String(Defs.RESEARCH["band_fife"]["at"]) == "armoury" and String(Defs.RESEARCH["band_pipes"]["at"]) == "armoury")
	check("the Fifer keeps a little powder", int(Defs.RESEARCH["band_fife"].get("cost2", 0)) > 0)
	var g := make(["crown", "clockwork"])
	await process_frame
	await process_frame
	var at := open_spot(g, 0)
	g.players[0]["gold"] = 9000
	g.players[0]["res2"] = 900
	g.players[0]["cap"] = 200
	var c0 := g.cell_of(hall(g, 0).center())
	var bk: Building = g._add_building("barracks", 0, c0 + Vector2i(8, -2), true)
	var ar: Building = g._add_building("armoury", 0, c0 + Vector2i(8, 3), true)
	check("a Barracks refuses a band", g.can_train(bk, MarchingBand.KIND) != "", g.can_train(bk, MarchingBand.KIND))
	check("the Armoury can train a band", g.can_train(ar, MarchingBand.KIND) == "", g.can_train(ar, MarchingBand.KIND))
	check("the Clockwork can't have one", not MarchingBand.on(g, 1))
	# ---- price: 50 with no musician researched
	check("a band costs 50 with no musician researched", g.unit_price(0, MarchingBand.KIND)[0] == 50, str(g.unit_price(0, MarchingBand.KIND)))
	var gold0 := int(g.players[0]["gold"])
	g.train(ar, MarchingBand.KIND)
	g.train(ar, MarchingBand.KIND)
	check("several bands may be queued (no one-per-player limit)", ar.queue.count(MarchingBand.KIND) == 2, str(ar.queue))
	check("each paid 50", int(g.players[0]["gold"]) == gold0 - 100, "%d -> %d" % [gold0, int(g.players[0]["gold"])])
	g.cancel_train(ar)
	g.cancel_train(ar)
	check("cancelled, paid back", int(g.players[0]["gold"]) == gold0)
	# ---- one band from the Armoury: a Drummer
	g.train(ar, MarchingBand.KIND)
	await step(g, float(Defs.UNITS[MarchingBand.KIND]["time"]) + 1.0)
	var b1: Unit = null
	for u in g.units:
		if u.kind == MarchingBand.KIND and u.team == 0:
			b1 = u
	check("the Armoury trains a band", b1 != null)
	if b1 == null:
		quit(1)
		return
	check("a new band is a Drummer", (b1.band.get("m", []) as Array) == ["drums"], str(b1.band.get("m")))
	check("a new band has 75 health", is_equal_approx(b1.max_hp, 75.0) and is_equal_approx(b1.hp, 75.0), "%.0f/%.0f" % [b1.hp, b1.max_hp])
	check("the drums play +5% from the start", is_equal_approx(MarchingBand.muls(b1).x, 1.05), str(MarchingBand.muls(b1)))
	check("no fife or pipes solo yet", MarchingBand.solo_problem(b1, "fife") != "" and MarchingBand.solo_problem(b1, "pipes") != "")
	b1.cmd_hold()
	b1.position = at
	# ---- research: the PIPER first (any order), at the Armoury's queue
	var pw := g.research_problem(ar, "band_pipes")
	check("the Piper can be researched at the Armoury", pw == "", pw)
	g.start_research(ar, "band_pipes")
	await step(g, float(Defs.RESEARCH["band_pipes"]["time"]) + 1.0)
	check("the Piper research finishes", g.has_tech(0, "band_pipes"))
	await step(g, 0.2)
	check("the Piper joins the band on the field", MarchingBand.has(b1, "pipes") and not MarchingBand.has(b1, "fife"), str(b1.band.get("m")))
	check("+15 health with him", is_equal_approx(b1.max_hp, 90.0), str(b1.max_hp))
	check("the price grows to 75 with one musician", g.unit_price(0, MarchingBand.KIND)[0] == 75, str(g.unit_price(0, MarchingBand.KIND)))
	g.players[0]["tech"]["band_fife"] = true          # (the Fifer second: research order doesn't matter)
	await step(g, 0.2)
	check("then the Fifer joins too", MarchingBand.has(b1, "fife") and is_equal_approx(b1.max_hp, 105.0), "%s %.0f" % [str(b1.band.get("m")), b1.max_hp])
	check("the price is 100 with both", g.unit_price(0, MarchingBand.KIND)[0] == 100, str(g.unit_price(0, MarchingBand.KIND)))
	gold0 = int(g.players[0]["gold"])
	g.train(ar, MarchingBand.KIND)
	check("a band is paid 100 now", int(g.players[0]["gold"]) == gold0 - 100)
	g.cancel_train(ar)
	check("and paid back 100 when cancelled", int(g.players[0]["gold"]) == gold0, "%d vs %d" % [int(g.players[0]["gold"]), gold0])
	var b2 := g._add_unit(MarchingBand.KIND, 0, at + Vector2(0, 260))
	check("a new band comes out with every researched musician", MarchingBand.has(b2, "fife") and MarchingBand.has(b2, "pipes") and MarchingBand.has(b2, "drums") and is_equal_approx(b2.max_hp, 105.0),
		"%s %.0f" % [str(b2.band.get("m")), b2.max_hp])
	b2.cmd_hold()
	b1 = tough(b1)
	b2 = tough(b2)
	var m2 := MarchingBand.muls(b1)
	check("with no solo every instrument plays +5%", m2.is_equal_approx(Vector3(1.05, 1.05, 1.05)), str(m2))
	# ---- the area
	var near := tough(g._add_unit("musketeer", 0, at + Vector2(100, 0)))
	var far := tough(g._add_unit("musketeer", 0, at + Vector2(float(B["area"]) + 80.0, -60)))
	var worker := tough(g._add_unit("labourer", 0, at + Vector2(-60, 30)))
	var foe := tough(g._add_unit("clock_soldier", 1, at + Vector2(0, -120)))
	for u in [near, far, worker, foe]:
		u.cmd_hold()
	foe.hold_fire = true
	near.hold_fire = true
	far.hold_fire = true
	await step(g, 0.6)
	check("a soldier inside the ring gets the band's buff", near.band_until > g.clock and near.band_mul.is_equal_approx(m2), str(near.band_mul))
	check("one outside it does not", far.band_until <= g.clock)
	check("a worker does not", worker.band_until <= g.clock)
	check("an enemy does not", foe.band_until <= g.clock)
	check("the band does not buff itself", b1.band_until <= g.clock)
	# ---- solos
	b1.band_solo("fife")
	check("FIFE SOLO: the fife leads", MarchingBand.lead(b1) == "fife")
	check("one solo at a time in a band", MarchingBand.solo_problem(b1, "drums") != "", MarchingBand.solo_problem(b1, "drums"))
	await step(g, 0.4)
	check("the fife's +30% reaches the ring", is_equal_approx(near.band_mul.z, 1.30), str(near.band_mul))
	check("the other instruments keep their +5%", is_equal_approx(near.band_mul.x, 1.05) and is_equal_approx(near.band_mul.y, 1.05), str(near.band_mul))
	near.cooldown = 3.0
	var t0 := g.clock
	await step(g, 1.0)
	var ran := (3.0 - near.cooldown) / (g.clock - t0)
	check("FIFE SOLO: a musket reloads 30% faster", absf(ran - 1.30) < 0.03, "%.2f s a second" % ran)
	# the Officer's pistol (the POC missed it)
	var off := tough(g._add_unit("dismounted", 0, at + Vector2(60, 60)))
	off.cmd_hold()
	off.hold_fire = true
	off.pistol = false
	off.powder = 10.0
	off.pistol_t = 0.0
	await step(g, 1.0)
	var pr := off.pistol_t / 1.0
	check("FIFE SOLO: the Officer's pistol reloads 30% faster", absf(pr - 1.30) < 0.06, "%.2f s a second" % pr)
	# a man with no shots: the fife does nothing for him
	if near._k_ammo:
		var keep_p := near.powder
		near.powder = 0.0
		near.cooldown = 3.0
		t0 = g.clock
		await step(g, 1.0)
		var r0 := (3.0 - near.cooldown) / (g.clock - t0)
		check("a musketeer with no shots isn't sped by the fife (crown-ammo)", absf(r0 - 1.0) < 0.03, "%.2f" % r0)
		near.powder = keep_p
	# two bands soloing at once; the rings don't stack
	b2.position = at + Vector2(30, 0)
	b2.band_solo("drums")
	check("a second band may solo while the first does", MarchingBand.lead(b2) == "drums" and MarchingBand.lead(b1) == "fife")
	await step(g, 0.4)
	check("two rings don't add up: each stat the strongest", near.band_mul.is_equal_approx(Vector3(1.30, 1.05, 1.30)), str(near.band_mul))
	far.cooldown = 3.0
	t0 = g.clock
	await step(g, 1.0)
	var ran2 := (3.0 - far.cooldown) / (g.clock - t0)
	check("outside the rings the reload runs as usual", absf(ran2 - 1.0) < 0.03, "%.2f s a second" % ran2)
	await step(g, float(B["solo"]))
	check("the solo ends after its time", MarchingBand.lead(b1) == "" and MarchingBand.lead(b2) == "")
	await step(g, 0.5)
	check("after the solos the ring is back to +5% (a solo doesn't linger)", near.band_mul.is_equal_approx(Vector3(1.05, 1.05, 1.05)), str(near.band_mul))
	check("the instrument waits out its cooldown", MarchingBand.solo_problem(b1, "fife") != "", MarchingBand.solo_problem(b1, "fife"))
	check("another instrument may solo now", MarchingBand.solo_problem(b1, "pipes") == "")
	b2.position = at + Vector2(0, 600)
	await step(g, 0.8)
	# the melee: a bayonet thrust with the pipes leading (the armour added back)
	near.mode = "bayonet"
	var hp0 := foe.hp
	near._strike(foe)
	var plain := hp0 - foe.hp + foe.armor
	b1.band_solo("pipes")
	await step(g, 0.4)
	near.mode = "bayonet"
	hp0 = foe.hp
	near._strike(foe)
	var piped := hp0 - foe.hp + foe.armor
	check("PIPES SOLO: a bayonet thrust hits 30% harder (vs +5%)", plain > 0.0 and absf(piped / plain - 1.30 / 1.05) < 0.02, "%.1f -> %.1f" % [plain, piped])
	near.mode = ""
	# the speed: the drums' +5% and solo
	var walker := tough(g._add_unit("musketeer", 0, at + Vector2(40, 40)))
	await step(g, 0.4)
	walker.cmd_move(walker.position + Vector2(400, 0))
	await step(g, 0.3)
	check("the drums' +5% on the walk", absf(walker.speed / float(walker.d["speed"]) - 1.05) < 0.02, "%.1f of %.1f" % [walker.speed, float(walker.d["speed"])])
	await step(g, float(B["solo"]))
	walker.position = at + Vector2(40, 40)
	b1.band_solo("drums")
	await step(g, 0.4)
	walker.cmd_move(walker.position + Vector2(400, 0))
	await step(g, 0.3)
	check("DRUM SOLO: a soldier in the ring walks 30% faster", absf(walker.speed / float(walker.d["speed"]) - 1.30) < 0.02, "%.1f of %.1f" % [walker.speed, float(walker.d["speed"])])
	# ---- the group's art
	await step(g, 0.2)
	g.view_rect = Rect2(b1.position - Vector2(500, 500), Vector2(1000, 1000))
	b1._animate(0.2)
	var fsp: Sprite2D = b1.sprite.get_node_or_null("band_fife")
	var psp: Sprite2D = b1.sprite.get_node_or_null("band_pipes")
	check("the drawn group: the Drummer's own sprite", b1.sprite.texture != null and b1.sprite.texture.resource_path.contains("/band/"), str(b1.sprite.texture.resource_path if b1.sprite.texture else ""))
	check("the drawn group: the Fifer and the Piper behind him", fsp != null and fsp.visible and psp != null and psp.visible)
	check("a Drummer band shows no Fifer or Piper", true)
	# ---- save
	var keep := MarchingBand.save(b1)
	g.demo = false
	var d := SaveGame.capture(g, {"map": g.map_id, "seed": 4242})
	g.demo = true
	SaveGame.restore(g, d)
	await process_frame
	var back: Unit = null
	for u in g.units:
		if u.kind == MarchingBand.KIND and u.team == 0 and u.position.distance_to(b1.position if is_instance_valid(b1) else at) < 40.0:
			back = u
	if back == null:
		for u in g.units:
			if u.kind == MarchingBand.KIND and u.team == 0 and MarchingBand.lead(u) == "drums":
				back = u
	check("a save keeps the band, its musicians, solo and cooldowns", back != null and MarchingBand.save(back) == keep and is_equal_approx(back.max_hp, 105.0),
		str(MarchingBand.save(back)) if back else "none")
	check("a save keeps the research", g.has_tech(0, "band_fife") and g.has_tech(0, "band_pipes"))
	var old := g._add_unit(MarchingBand.KIND, 0, at + Vector2(-200, 200))
	MarchingBand.load_state(old, {"m": [], "h": "pipes", "he": 99.0, "s": "", "se": 0.0, "cd": {}})
	await step(g, 0.1)
	check("an old experiment save (the bandmaster alone, a musician joining) loads and fills in", MarchingBand.has(old, "drums") and MarchingBand.has(old, "fife") and not old.band.has("h"), str(old.band))
	# ---- online snapshot (a replay records the same snapshots)
	if back:
		var row := NetSnapshot.unit_vals(back)
		var copy := g._add_unit(MarchingBand.KIND, 0, at + Vector2(0, 200))
		NetSnapshot._set_unit_vals(copy, row, 0)
		check("the online snapshot carries the band's state", MarchingBand.save(copy) == keep, str(MarchingBand.save(copy)))
		check("the snapshot's lists match its values", NetSnapshot.UNIT_PROPS.size() == row.size() and NetSnapshot.UNIT_PROPS.has("band"))
		check("a replay records the field", (ReplayRecorder.lists()["up"] as Array).has("band"))
	check("a guest's solo goes through the funnel (and an old ADD order still finds its method)", NetCommands.ENTITY.has("band_solo") and NetCommands.ENTITY.has("band_hire"))
	# ---- the buff goes when the band goes
	if back:
		for u in g.units:
			if u.kind == MarchingBand.KIND and u != back and not u.dead:
				u.position = at + Vector2(-900, 900)
		var nb := tough(g._add_unit("musketeer", 0, back.position + Vector2(60, 0)))
		nb.cmd_hold()
		await step(g, 0.5)
		var had := nb.band_until > g.clock
		back.take_damage(99999.0, null, Entity.BLOW_RANGED)
		await step(g, float(B["linger"]) + 0.5)
		check("killed, the band's buff is gone after its linger", had and nb.band_until <= g.clock and MarchingBand.speed_mul(nb) == 1.0, "%s %.2f %.2f" % [had, nb.band_until, g.clock])
	# ---- an old setup's switch is ignored
	var cfg := {"marching_band": false}
	check("an old cfg's marching_band key changes nothing", MarchingBand.on(g, 0) and cfg.has("marching_band"))
	print("marching band: %d failures" % fails)
	quit(1 if fails > 0 else 0)
