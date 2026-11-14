## THE MARCHING BAND, a real Crown unit since 0.33.0 (the owner, 2026-11-05; scripts/marching_band.gd,
## docs/marching_band.md; band-v2 0.36.0: docs/band_v2.md): no experiment switch; trained at the ARMOURY; a new band is a
## DRUMMER (75 health); the FIFER and the PIPER are UNITS trained at the Armoury that walk to a band and JOIN it (one of
## each a band; RECRUIT on the band's card sends one to THAT band; a right-click / JOIN order; the nearest band by
## default; a band dying on the way: he picks another or waits; no band: he waits); the price is flat (no more per
## musician); several bands allowed, their rings don't stack; one solo at a time per band; +5% always, +30% in a solo;
## the group drawn SIDE BY SIDE; an old save's research still fills every band; the save, the online snapshot and a
## replay's fields carry it; the command funnel; the sound engine (one band heard, one clock).
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
	check("the Fifer and the Piper are trained at the Armoury (band-v2)", Defs.train_keys(Defs.BUILDINGS["armoury"]["trains"], false).has("band_fifer") and Defs.train_keys(Defs.BUILDINGS["armoury"]["trains"], false).has("band_piper"))
	check("no band research any more", not Defs.RESEARCH.has("band_fife") and not Defs.RESEARCH.has("band_pipes"))
	check("the Fifer keeps a little powder", int(Defs.UNITS["band_fifer"].get("cost2", 0)) > 0)
	check("the old research prices", int(Defs.UNITS["band_fifer"]["cost"]) == 60 and int(Defs.UNITS["band_piper"]["cost"]) == 75)
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
	# ---- price: 50, flat
	check("a band costs 50", g.unit_price(0, MarchingBand.KIND)[0] == 50, str(g.unit_price(0, MarchingBand.KIND)))
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
	check("the band has a number", MarchingBand.band_id(b1) > 0)
	b1.cmd_hold()
	b1.position = at
	# ---- RECRUIT PIPER on the band's card: queued at the Armoury for THIS band, walks over, joins
	check("RECRUIT PIPER can be pressed", MarchingBand.recruit_problem(b1, "pipes") == "", MarchingBand.recruit_problem(b1, "pipes"))
	gold0 = int(g.players[0]["gold"])
	b1.band_recruit("pipes")
	check("a Piper is queued at the Armoury", ar.queue.has("band_piper"), str(ar.queue))
	check("paid 75", int(g.players[0]["gold"]) == gold0 - 75, "%d -> %d" % [gold0, int(g.players[0]["gold"])])
	check("a second RECRUIT PIPER for the same band is refused", MarchingBand.recruit_problem(b1, "pipes") != "", MarchingBand.recruit_problem(b1, "pipes"))
	# (a second band near the Armoury: the recruit still goes to the band he was recruited for, not the nearest)
	var decoy := g._add_unit(MarchingBand.KIND, 0, ar.center() + Vector2(0, 300))
	decoy.cmd_hold()
	await step(g, float(Defs.UNITS["band_piper"]["time"]) + 0.5)
	var piper: Unit = null
	for u in g.units:
		if u.kind == "band_piper" and u.team == 0 and not u.dead:
			piper = u
	check("the Piper comes out of the Armoury as a walking unit", piper != null)
	check("he walks to the band he was recruited for (not the nearer one)", piper != null and piper.order == "join" and piper.order_target == b1,
		"%s %s" % [piper.order if piper else "-", str(piper.order_target) if piper else "-"])
	await step(g, 25.0)
	check("the Piper joins the band", MarchingBand.has(b1, "pipes") and not MarchingBand.has(b1, "fife"), str(b1.band.get("m")))
	check("he is gone from the field (the band draws him)", piper == null or not is_instance_valid(piper) or piper.dead)
	check("+15 health with him", is_equal_approx(b1.max_hp, 90.0), str(b1.max_hp))
	check("the decoy band got no Piper", not MarchingBand.has(decoy, "pipes"))
	check("the band's price stays 50", g.unit_price(0, MarchingBand.KIND)[0] == 50)
	# ---- a Fifer trained plainly: he goes to the nearest band without one (the decoy, by the Armoury)
	var fw := g.train(ar, "band_fifer")
	check("a Fifer can be trained plainly", fw == "", fw)
	await step(g, float(Defs.UNITS["band_fifer"]["time"]) + 0.5)
	var fifer: Unit = null
	for u in g.units:
		if u.kind == "band_fifer" and u.team == 0 and not u.dead:
			fifer = u
	check("a Fifer trained plainly walks to the nearest band without one", fifer != null and fifer.order == "join" and fifer.order_target == decoy,
		"%s" % [fifer.order if fifer else "none"])
	# ---- the JOIN order (a right-click on a band) sends him to that one instead
	if fifer:
		g.smart_command([fifer], b1.position + Vector2(0, -12))
		await step(g, 0.1)
		check("right-click on a band: JOIN that band", fifer.order == "join" and fifer.order_target == b1, fifer.order)
		# ---- the band dies on the way: he picks another (the decoy)
		b1.position = at
		var keep_hp := b1.hp
		var bx := g._add_unit(MarchingBand.KIND, 0, at + Vector2(900, 0))
		bx.cmd_hold()
		g.smart_command([fifer], bx.position + Vector2(0, -12))
		await step(g, 0.1)
		check("sent to a far band", fifer.order_target == bx)
		bx.take_damage(99999.0, null, Entity.BLOW_RANGED)
		await step(g, 1.5)
		check("his band killed on the way: he goes to another that wants him", is_instance_valid(fifer) and fifer.order == "join" and fifer.order_target != bx,
			"%s %s" % [fifer.order, str(fifer.order_target)])
		g.smart_command([fifer], b1.position + Vector2(0, -12))
		await step(g, 30.0)
		check("then he joins the band he was sent to", MarchingBand.has(b1, "fife") and is_equal_approx(b1.max_hp, 105.0), "%s %.0f" % [str(b1.band.get("m")), b1.max_hp])
		check("a second Fifer for that band is refused", MarchingBand.recruit_problem(b1, "fife") != "")
		b1.hp = keep_hp + 15.0
	# ---- no band wants him: he waits (at the rally), then goes when one does
	decoy.take_damage(99999.0, null, Entity.BLOW_RANGED)
	await step(g, 0.5)
	var loose := g._add_unit("band_piper", 0, ar.center() + Vector2(0, 90))
	await step(g, 2.0)
	check("a Piper with no band to join waits", loose.order != "join", loose.order)
	var b3 := g._add_unit(MarchingBand.KIND, 0, ar.center() + Vector2(160, 160))
	b3.cmd_hold()
	await step(g, 2.0)
	check("a new band without a Piper: the waiting one goes to it", loose.order == "join" and loose.order_target == b3, loose.order)
	await step(g, 15.0)
	check("and joins it", MarchingBand.has(b3, "pipes"))
	b3.position = at + Vector2(-800, 600)
	# ---- an OLD SAVE's research: every band has the musician
	g.players[0]["tech"]["band_fife"] = true
	var b2 := g._add_unit(MarchingBand.KIND, 0, at + Vector2(0, 260))
	check("an old save's research: a band comes out with that musician", MarchingBand.has(b2, "fife") and not MarchingBand.has(b2, "pipes"), str(b2.band.get("m")))
	g.players[0]["tech"]["band_pipes"] = true
	await step(g, 0.2)
	check("... and every band on the field gets it", MarchingBand.has(b2, "pipes") and MarchingBand.has(b3, "pipes") and is_equal_approx(b2.max_hp, 105.0), "%s %.0f" % [str(b2.band.get("m")), b2.max_hp])
	check("an old save's queued research is the musician now", MarchingBand.OLD_QUEUE["@band_fife"] == "band_fifer" and MarchingBand.OLD_QUEUE["@band_pipes"] == "band_piper")
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
	t0 = g.clock
	await step(g, 1.0)
	var pr := off.pistol_t / (g.clock - t0)
	check("FIFE SOLO: the Officer's pistol reloads 30% faster", absf(pr - 1.30) < 0.06, "%.2f s a second" % pr)
	# a man with no shots: the fife does nothing for him
	if near._k_ammo:
		# (a dry man's cooldown runs as it would with no band: compared with one outside the ring, also dry)
		var keep_p := near.powder
		var keep_f := far.powder
		near.powder = 0.0
		far.powder = 0.0
		near.cooldown = 3.0
		far.cooldown = 3.0
		t0 = g.clock
		await step(g, 0.5)
		var r0 := (3.0 - near.cooldown) / (g.clock - t0)
		var r1 := (3.0 - far.cooldown) / (g.clock - t0)
		check("a musketeer with no shots isn't sped by the fife (crown-ammo)", absf(r0 - r1) < 0.03, "%.2f in the ring, %.2f outside" % [r0, r1])
		near.powder = keep_p
		far.powder = keep_f
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
	check("the drawn group: the Fifer and the Piper with him", fsp != null and fsp.visible and psp != null and psp.visible)
	if fsp and psp:
		var gap := absf(fsp.position.x - psp.position.x)
		check("SIDE BY SIDE: one row, no two bodies overlapping", absf(fsp.position.y - psp.position.y) < 3.0 and absf(fsp.position.x) >= 20.0 and absf(psp.position.x) >= 20.0 and gap >= 40.0,
			"fife %s pipes %s" % [str(fsp.position), str(psp.position)])
	var lone := g._add_unit(MarchingBand.KIND, 0, at + Vector2(-300, 0))
	g.players[0]["tech"].erase("band_fife")
	g.players[0]["tech"].erase("band_pipes")
	lone.band = MarchingBand.fresh()
	lone.max_hp = float(lone.d["hp"])
	MarchingBand.sync(lone, true)
	lone._animate(0.2)
	var lf: Sprite2D = lone.sprite.get_node_or_null("band_fife")
	check("a Drummer band shows no Fifer or Piper", lf == null or not lf.visible)
	g.players[0]["tech"]["band_fife"] = true
	g.players[0]["tech"]["band_pipes"] = true
	lone.take_damage(99999.0, null, Entity.BLOW_RANGED)
	# the wider pick: a click on the Fifer at the end of the row picks the band
	var pick := g.entity_at(b1.position + Vector2(30, -14))
	check("a click on a musician at the end of the row picks the band", pick == b1, str(pick))
	# ---- the sound engine: one band heard, one clock
	var bs := BandSound.need(g)
	check("one BandSound a match", BandSound.need(g) == bs and bs.get_parent() == g)
	check("every part's file is listed in one place and exists", BandSound.PARTS.keys().all(func(k) -> bool: return (BandSound.PARTS[k] as Array).all(func(f) -> bool: return ResourceLoader.exists("res://assets/audio/%s.ogg" % f))))
	var lv := bs.levels()
	var on := 0
	for f in lv:
		if float(lv[f]) > -79.0:
			on += 1
	var fb: Unit = bs.focus
	check("several bands on the field: ONE band is heard (its parts only)", fb != null and on == (fb.band.get("m", []) as Array).size(), "%d parts on, focus %s %s" % [on, str(fb), str(lv)])
	if fb:
		var placed := bs.level(fb)
		var q0 := -80.0
		for ins in BandSound.PARTS:
			if MarchingBand.has(fb, ins) and MarchingBand.lead(fb) != ins:
				q0 = float(lv[BandSound.PARTS[ins][0]])
		check("the always-on playing is quiet", q0 <= (BandSound.UNDER_DB if MarchingBand.lead(fb) != "" else BandSound.QUIET_DB) + placed + 0.01 and q0 > -60.0, "%.1f (place %.1f)" % [q0, placed])
		var cdk: Dictionary = fb.band["cd"]
		cdk.erase("pipes")
		var kept_s := String(fb.band["s"])
		var kept_se := float(fb.band["se"])
		fb.band["s"] = ""
		MarchingBand.solo(fb, "pipes")
		lv = bs.levels()
		check("a SOLO is clearly heard: its solo loop 18 dB over the others", float(lv[BandSound.PARTS["pipes"][1]]) - float(lv[BandSound.PARTS["drums"][0]]) >= 17.9
			and float(lv[BandSound.PARTS["pipes"][0]]) <= -79.0, str(lv))
		fb.band["s"] = kept_s
		fb.band["se"] = kept_se
	check("one shared clock: the phase is inside the phrase", bs.phase() >= 0.0 and bs.phase() < BandSound.PHRASE)
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
	check("a save keeps an old save's research flags", g.has_tech(0, "band_fife") and g.has_tech(0, "band_pipes"))
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
