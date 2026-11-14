## THE MARCHING BAND as INDIVIDUAL MUSICIANS (0.37.0, the owner 2026-11-14; scripts/marching_band.gd,
## docs/band_individuals.md): a Drummer, a Fifer and a Piper, each trained at the Armoury, each with his own ring, +5%,
## solo (+30%, 8 s) and cooldown; the same instrument never adds up; a BAND forms when one of each stand within each
## other's rings (the nearest set), breaks when they part, plays stronger (+8%, solos +40% for 10 s, one solo at a
## time) and in step; lone musicians of different instruments overlapping are out of step (only the stronger buff);
## SOLO plain = one, Ctrl = all; the sound's who-is-heard rule; the buff markers' values; the row; saves (new and a
## 0.33-0.36 band unit), the online snapshot, the replay field, the command funnel.
##   godot --headless --fixed-fps 30 --script res://tools/test_marching_band.gd
extends SceneTree
var fails := 0
const B := Defs.MARCHING_BAND


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-74s %s %s" % [name, "ok" if ok else "FAIL", detail])
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


func frames(n: int) -> void:
	for i in n:
		await process_frame


## The band's duck on the Music bus now (dB; 0 when none).
func music_duck() -> float:
	var bus := AudioServer.get_bus_index("Music")
	if bus < 0:
		return 0.0
	for i in AudioServer.get_bus_effect_count(bus):
		var e := AudioServer.get_bus_effect(bus, i)
		if e is AudioEffectAmplify and e.resource_name == "band_duck":
			return (e as AudioEffectAmplify).volume_db
	return 0.0


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


func man(g: Game, k: String, p: Vector2) -> Unit:
	var u := tough(g._add_unit(k, 0, p))
	u.cmd_hold()
	return u


func clear(g: Game) -> void:
	for u in g.units.duplicate():
		if MarchingBand.is_musician(u) and not u.dead:
			u.take_damage(99999.0, null, Entity.BLOW_RANGED)


func _run() -> void:
	# ---- the three musicians: units of their own at the Armoury, no research, no band unit
	var tr: Array = Defs.train_keys(Defs.BUILDINGS["armoury"]["trains"], false)
	check("the Armoury trains the Drummer, the Fifer and the Piper", tr.has("band") and tr.has("band_fifer") and tr.has("band_piper"))
	check("the Barracks trains no musician", not (Defs.BUILDINGS["barracks"]["trains"] as Array).has("band"))
	check("no band research", not Defs.RESEARCH.has("band_fife") and not Defs.RESEARCH.has("band_pipes"))
	check("the old band's kind is the Drummer", String(Defs.UNITS["band"]["name"]) == "Drummer")
	check("FIFE NO POWDER: the Fifer costs gold only, 70", int(Defs.UNITS["band_fifer"].get("cost2", 0)) == 0 and int(Defs.UNITS["band_fifer"]["cost"]) == 70)
	check("prices 50 / 70 / 75", int(Defs.UNITS["band"]["cost"]) == 50 and int(Defs.UNITS["band_piper"]["cost"]) == 75)
	check("1 supply each", ["band", "band_fifer", "band_piper"].all(func(k) -> bool: return int(Defs.UNITS[k]["supply"]) == 1))
	check("health 40 / 35 / 35", int(Defs.UNITS["band"]["hp"]) == 40 and int(Defs.UNITS["band_fifer"]["hp"]) == 35 and int(Defs.UNITS["band_piper"]["hp"]) == 35)
	check("no JOIN or RECRUIT left in the band code", not FileAccess.get_file_as_string("res://scripts/marching_band.gd").contains("func recruit(") and not FileAccess.get_file_as_string("res://scripts/marching_band.gd").contains("func join_run("))
	var g := make(["crown", "clockwork"])
	await process_frame
	await process_frame
	var at := open_spot(g, 0)
	g.players[0]["gold"] = 9000
	g.players[0]["res2"] = 900
	g.players[0]["cap"] = 200
	var c0 := g.cell_of(hall(g, 0).center())
	g._add_building("barracks", 0, c0 + Vector2i(8, -2), true)
	var ar: Building = g._add_building("armoury", 0, c0 + Vector2i(8, 3), true)
	check("the Clockwork can't have them", not MarchingBand.on(g, 1))
	# ---- training each
	var res0 := float(g.players[0]["res2"])
	for k in ["band", "band_fifer", "band_piper"]:
		var gold0 := int(g.players[0]["gold"])
		var why := g.train(ar, k)
		check("the Armoury trains a %s" % String(Defs.UNITS[k]["name"]), why == "" and int(g.players[0]["gold"]) == gold0 - int(Defs.UNITS[k]["cost"]), why)
	check("no powder paid for the Fifer", is_equal_approx(float(g.players[0]["res2"]), res0))
	await step(g, 18.0 * 3.0 + 2.0)
	var trained := {}
	for u in g.units:
		if u.team == 0 and MarchingBand.is_musician(u) and not u.dead:
			trained[u.kind] = u
	check("all three came out as units", trained.size() == 3, str(trained.keys()))
	for k in trained:
		var u: Unit = trained[k]
		check("%s: his own state, a number" % k, MarchingBand.band_id(u) > 0 and is_equal_approx(u.max_hp, float(Defs.UNITS[k]["hp"])))
	clear(g)
	await step(g, 0.5)

	# ---- a lone drummer's ring; the same instrument never adds up
	var d1 := man(g, "band", at)
	var near := man(g, "musketeer", at + Vector2(100, 0))
	var far := man(g, "musketeer", at + Vector2(float(B["area"]) + 80.0, -60))
	var worker := man(g, "labourer", at + Vector2(-60, 30))
	var foe := tough(g._add_unit("clock_soldier", 1, at + Vector2(0, -120)))
	foe.cmd_hold()
	for u in [near, far, foe]:
		u.hold_fire = true
	await step(g, 0.6)
	check("a lone drummer: +5% speed in his ring", near.band_until > g.clock and near.band_mul.is_equal_approx(Vector3(1.05, 1.0, 1.0)), str(near.band_mul))
	check("outside it nothing", far.band_until <= g.clock)
	check("a worker gets nothing", worker.band_until <= g.clock)
	check("the musician doesn't buff himself", d1.band_until <= g.clock)
	var d2 := man(g, "band", at + Vector2(40, 0))
	d2.band_solo("drums")
	check("the drum solo: he leads", MarchingBand.lead(d2) == "drums" and is_equal_approx(MarchingBand.solo_left(d2), float(B["solo"])))
	await step(g, 0.4)
	check("SAME INSTRUMENT NEVER ADDS UP: two drums, the strongest only (+30%)", near.band_mul.is_equal_approx(Vector3(1.30, 1.0, 1.0)), str(near.band_mul))
	check("the solo's own cooldown", MarchingBand.solo_problem(d2, "drums") != "" and MarchingBand.solo_problem(d1, "drums") == "")
	# the drum's speed on a walk
	near.cmd_move(near.position + Vector2(300, 0))
	await step(g, 0.3)
	check("DRUM SOLO: a soldier walks 30% faster", absf(near.speed / float(near.d["speed"]) - 1.30) < 0.02, "%.1f of %.1f" % [near.speed, float(near.d["speed"])])
	near.position = at + Vector2(100, 0)
	near.cmd_hold()
	d2.take_damage(99999.0, null, Entity.BLOW_RANGED)
	await step(g, float(B["linger"]) + 0.5)
	check("the solo's drummer killed: back to the other's +5%", near.band_mul.is_equal_approx(Vector3(1.05, 1.0, 1.0)), str(near.band_mul))

	# ---- the OUT OF STEP rule: a lone Fifer and a lone Piper overlapping (no band)
	d1.position = at + Vector2(-1200, 0)
	var f1 := man(g, "band_fifer", at + Vector2(60, 60))
	var p1 := man(g, "band_piper", at + Vector2(140, 60))
	await step(g, 0.6)
	check("a Fifer and a Piper alone are no band", not MarchingBand.in_band(f1) and not MarchingBand.in_band(p1))
	check("their rings say OUT OF STEP", bool(f1.band.get("oos", false)) and bool(p1.band.get("oos", false)))
	check("in the overlap only the stronger buff counts (tie: the fife)", near.band_mul.is_equal_approx(Vector3(1.0, 1.0, 1.05)), str(near.band_mul))
	var oos_mark := near.band_show.any(func(e) -> bool: return String(e[0]) == "pipes" and int(e[2]) & MarchingBand.F_OOS)
	check("the marker shows the pipes greyed (out of step)", oos_mark, str(near.band_show))
	check("the card says so", MarchingBand.buff_text(near).contains("out of step"), MarchingBand.buff_text(near))
	p1.band_solo("pipes")
	await step(g, 0.4)
	check("the piper's solo (+30%) is now the stronger: it counts, the fife doesn't", near.band_mul.is_equal_approx(Vector3(1.0, 1.30, 1.0)), str(near.band_mul))
	# the pipes on a bayonet thrust
	foe.position = near.position + Vector2(20, 0)
	near.mode = "bayonet"
	var hp0 := foe.hp
	near._strike(foe)
	var piped := hp0 - foe.hp + foe.armor
	near.mode = ""
	var lonely := man(g, "musketeer", at + Vector2(-700, 400))
	foe.position = lonely.position + Vector2(20, 0)
	lonely.mode = "bayonet"
	hp0 = foe.hp
	lonely._strike(foe)
	var plain := hp0 - foe.hp + foe.armor
	lonely.mode = ""
	check("PIPES SOLO: a bayonet thrust hits 30% harder", plain > 0.0 and absf(piped / plain - 1.30) < 0.02, "%.1f -> %.1f" % [plain, piped])
	foe.position = at + Vector2(0, -400)
	# far apart they are not out of step
	p1.position = at + Vector2(60 + float(B["area"]) * 2.0 + 30.0, 60)
	await step(g, 0.5)
	check("rings apart: not out of step", not bool(f1.band.get("oos", false)) and not bool(p1.band.get("oos", false)))

	# ---- A BAND FORMS: a drummer, a fifer and a piper within each other's rings
	await step(g, float(B["solo"]))
	d1.position = at + Vector2(0, 0)
	f1.position = at + Vector2(24, 4)
	p1.position = at + Vector2(-24, -4)
	await step(g, 0.6)
	check("A BAND FORMS: one of each within each other's rings", MarchingBand.in_band(d1) and MarchingBand.in_band(f1) and MarchingBand.in_band(p1)
		and MarchingBand.band_key(f1) == MarchingBand.band_id(d1) and MarchingBand.band_key(p1) == MarchingBand.band_id(d1))
	check("a band is never out of step", not bool(f1.band.get("oos", false)))
	check("the band's buffs: +8% each instrument", near.band_mul.is_equal_approx(Vector3(1.08, 1.08, 1.08)), str(near.band_mul))
	check("the markers: three, in the band's colours (flag BAND), 8% each", near.band_show.size() == 3 and near.band_show.all(func(e) -> bool: return int(e[1]) == 8 and int(e[2]) & MarchingBand.F_BAND), str(near.band_show))
	check("the card lists them with their source", MarchingBand.buff_text(near).to_lower().contains("band") and MarchingBand.buff_text(near).contains("+8%"), MarchingBand.buff_text(near))
	f1.band_solo("fife")
	check("a band's solo lasts 10 s", is_equal_approx(MarchingBand.solo_left(f1), float(B["band_solo"])))
	check("ONE SOLO AT A TIME in a band", MarchingBand.solo_problem(d1, "drums") != "", MarchingBand.solo_problem(d1, "drums"))
	await step(g, 0.4)
	check("a band's solo: +40%", near.band_mul.is_equal_approx(Vector3(1.08, 1.08, 1.40)), str(near.band_mul))
	check("the solo's marker is flagged SOLO and 40", near.band_show.any(func(e) -> bool: return String(e[0]) == "fife" and int(e[1]) == 40 and int(e[2]) & MarchingBand.F_SOLO))
	near.cooldown = 3.0
	var t0 := g.clock
	await step(g, 1.0)
	var ran := (3.0 - near.cooldown) / (g.clock - t0)
	check("the band's FIFE SOLO: a musket reloads 40% faster", absf(ran - 1.40) < 0.03, "%.2f s a second" % ran)
	# buff markers: shown in a solo even unselected (Settings SELECTED), hidden when OFF, always when ALWAYS
	var keep_set := Settings.band_marks
	Settings.band_marks = 1
	check("markers (SELECTED): shown on everyone in a ring during a solo", MarchingBand.marks_shown(near) and MarchingBand.marks_key(near) != 0)
	Settings.band_marks = 2
	check("markers OFF: none", not MarchingBand.marks_shown(near))
	await step(g, float(B["band_solo"]))
	Settings.band_marks = 1
	check("markers (SELECTED) after the solo: only on the selected / hovered", not MarchingBand.marks_shown(near))
	near.selected = true
	check("... the selected one shows them", MarchingBand.marks_shown(near))
	near.selected = false
	Settings.band_marks = 0
	check("markers ALWAYS: everyone in a ring", MarchingBand.marks_shown(near))
	Settings.band_marks = keep_set

	# ---- the band breaks as they move apart, re-forms when they meet
	p1.position = at + Vector2(-float(B["area"]) * float(B["keep"]) - 60.0, 0)
	await step(g, 0.5)
	check("THE BAND BREAKS when one walks out of the others' rings", not MarchingBand.in_band(d1) and not MarchingBand.in_band(p1) and not MarchingBand.in_band(f1))
	check("broken: the drummer and fifer alone are out of step", bool(d1.band.get("oos", false)) and bool(f1.band.get("oos", false)))
	p1.position = at + Vector2(-float(B["area"]) * 1.05, 0)
	await step(g, 0.5)
	check("a little beyond the ring it doesn't re-form (only within the ring)", not MarchingBand.in_band(p1))
	p1.position = at + Vector2(-60, 0)
	await step(g, 0.5)
	check("it re-forms when he comes back", MarchingBand.in_band(p1) and MarchingBand.in_band(d1))
	f1.position = at + Vector2(0, 20)
	p1.position = at + Vector2(-float(B["area"]) * 1.08, 0)
	await step(g, 0.5)
	check("a formed band holds a little past the ring (no flicker at the edge)", MarchingBand.in_band(p1))
	p1.position = at + Vector2(-24, 0)
	# ---- the nearest set forms it: a second drummer further off stays lone
	var d3 := man(g, "band", at + Vector2(90, 90))
	await step(g, 0.5)
	check("with an extra drummer about, the closer one keeps the band; the other is lone", MarchingBand.in_band(d1) and not MarchingBand.in_band(d3))
	clear(g)
	await step(g, 0.5)
	var fa := man(g, "band_fifer", at + Vector2(30, 0))
	var pa := man(g, "band_piper", at + Vector2(-30, 0))
	var dfar := man(g, "band", at + Vector2(0, 140))
	var dnear := man(g, "band", at + Vector2(0, 20))
	await step(g, 0.5)
	check("a new band picks the nearest set", MarchingBand.in_band(dnear) and not MarchingBand.in_band(dfar) and MarchingBand.band_key(fa) == MarchingBand.band_id(dnear))

	# ---- the row: a group move with the whole band; the row keeps while the drummer walks
	var spots := {dnear: at + Vector2(400, 0), fa: at + Vector2(380, 40), pa: at + Vector2(430, -30)}
	MarchingBand.row_spots([dnear, fa, pa], spots)
	check("a group move: the Fifer and Piper side by side with the Drummer", (spots[fa] as Vector2).y == (spots[dnear] as Vector2).y and absf((spots[fa] as Vector2).x - (spots[dnear] as Vector2).x) == 24.0
		and absf((spots[pa] as Vector2).x - (spots[dnear] as Vector2).x) == 24.0 and (spots[fa] as Vector2).x != (spots[pa] as Vector2).x, str(spots))
	dfar.position = at + Vector2(0, 900)
	fa.cmd_stop()
	pa.cmd_stop()
	dnear.cmd_move(at + Vector2(300, 0))
	await step(g, 6.0)
	check("the Drummer walks: his Fifer and Piper keep beside him (still a band)", MarchingBand.in_band(fa) and MarchingBand.in_band(pa)
		and fa.position.distance_to(dnear.position) < 60.0 and pa.position.distance_to(dnear.position) < 60.0,
		"%.0f %.0f" % [fa.position.distance_to(dnear.position), pa.position.distance_to(dnear.position)])
	check("SELECT BAND: the three", MarchingBand.band_members_of([fa]).size() == 3)

	# ---- the SOLO button: plain = one, Ctrl = all
	clear(g)
	await step(g, 0.5)
	var fx1 := man(g, "band_fifer", at + Vector2(0, 0))
	var fx2 := man(g, "band_fifer", at + Vector2(500, 0))
	var dx := man(g, "band", at + Vector2(1000, 0))
	var sel := [fx1, fx2, dx]
	check("a plain SOLO press: ONE musician of that instrument plays", MarchingBand.solo_pick(sel, "fife", false) == 1 and MarchingBand.lead(fx1) == "fife" and MarchingBand.lead(fx2) == "")
	check("a second plain press: the next free one", MarchingBand.solo_pick(sel, "fife", false) == 1 and MarchingBand.lead(fx2) == "fife")
	fx1.band["se"] = 0.0
	fx1.band["cd"] = 0.0
	fx2.band["se"] = 0.0
	fx2.band["cd"] = 0.0
	check("Ctrl + SOLO: EVERY selected musician of that instrument plays", MarchingBand.solo_pick(sel, "fife", true) == 2 and MarchingBand.lead(fx1) == "fife" and MarchingBand.lead(fx2) == "fife")
	check("... the drummer is not touched by the fife's button", MarchingBand.lead(dx) == "")
	check("a guest's solo goes through the funnel (an old RECRUIT / ADD order still finds its method)", NetCommands.ENTITY.has("band_solo") and NetCommands.ENTITY.has("band_hire") and NetCommands.ENTITY.has("band_recruit"))

	# ---- THE SOUND: who is heard
	clear(g)
	await step(g, 0.5)
	var cam := Camera2D.new()
	g.add_child(cam)
	var cam0: Camera2D = g.camera
	g.camera = cam
	cam.position = at
	cam.make_current()
	await process_frame
	var bs := BandSound.need(g)
	check("one BandSound a match", BandSound.need(g) == bs)
	check("every part's file of every tune is listed in one place and exists", BandSound.TUNES.keys().all(func(t) -> bool: return BandSound.PARTS.keys().all(func(k) -> bool: return [false, true].all(func(so) -> bool: return ResourceLoader.exists("res://assets/audio/%s.ogg" % BandSound.file(t, k, so))))))
	var sd := man(g, "band", at + Vector2(0, 0))
	var sf := man(g, "band_fifer", at + Vector2(24, 0))
	var sp := man(g, "band_piper", at + Vector2(-24, 0))
	var lone_d := man(g, "band", at + Vector2(600, 300))
	for u in [sd, sf, sp, lone_d]:
		u.visible = true
	await step(g, 0.5)
	var lv := bs.levels()
	var band_on := 0
	var lone_on := 0
	for k in lv:
		if float(lv[k]) > -79.0:
			if String(k).begins_with("L"):
				lone_on += 1
			else:
				band_on += 1
	check("a band near the middle: the BAND is heard (its three parts, in step), no lone musician", band_on == 3 and lone_on == 0 and bs.heard.size() == 3, "%d band, %d lone %s" % [band_on, lone_on, str(lv)])
	check("a band's parts on the shared clock (no offset)", BandSound.PARTS.keys().all(func(k) -> bool: return is_equal_approx(float(bs.offsets()["B/%s/a" % k]), 0.0)))
	var tn := bs.tunes_now()
	var band_tune := bs.band_list().tune
	check("... all three on the band's playlist, the same tune", ["drums", "fife", "pipes"].all(func(k) -> bool: return String(tn["B/%s/a" % k]) == band_tune), str(tn))
	# THE GAME MUSIC GIVES WAY TO THE BAND (band-music-v2): ducked strongly while the band is centred, smoothly
	if AudioServer.get_bus_index("Music") < 0:          # (the Music node makes the bus in a real game)
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	var dn := bs.duck_now()
	check("the music gives way: a band in the middle of the screen ducks the game music %.0f dB" % BandSound.DUCK_DB, absf(dn.y - BandSound.DUCK_DB) < 0.6, str(dn))
	await frames(48)
	dn = bs.duck_now()
	check("... reached smoothly within 1.6 s (%.0f dB a second, no jump)" % BandSound.DUCK_RATE, absf(dn.x - dn.y) < 0.3, str(dn))
	check("... on the Music bus (an Amplify effect: the volume sliders untouched)", music_duck() < -10.0, "%.1f dB" % music_duck())
	var before := bs.levels()
	var tune_before := bs.band_list().tune
	sf.band_solo("fife")
	await frames(2)
	dn = bs.duck_now()
	check("... more during a solo (%.0f dB)" % BandSound.DUCK_SOLO_DB, absf(dn.y - BandSound.DUCK_SOLO_DB) < 0.8, str(dn))
	var during := bs.levels()
	tn = bs.tunes_now()
	check("a SOLO does not change the tune: the fife's solo part of the tune playing comes forward", bs.band_list().tune == tune_before and String(tn["B/fife/b"]) == tune_before and float(during["B/fife/b"]) > float(before["B/fife/a"]) + 4.0 and float(during["B/fife/a"]) < -79.0, "%s -> %s, %s" % [str(before), str(during), str(tn)])
	check("... the others go on under it (the drums' and the pipes' background parts still heard)", float(during["B/drums/a"]) > -30.0 and float(during["B/pipes/a"]) > -30.0, str(during))
	sf.band["se"] = 0.0
	sf.band["cd"] = 0.0
	cam.position = at + Vector2(360, 0)
	await frames(2)
	dn = bs.duck_now()
	check("... less with the band off to the side of the screen", dn.y > BandSound.DUCK_DB + 2.0 and dn.y < -1.0, str(dn))
	cam.position = at + Vector2(4000, 0)
	await frames(2)
	dn = bs.duck_now()
	check("the camera leaves: the music comes back up, smoothly (no jump)", dn.y == 0.0 and dn.x < -8.0, str(dn))
	await frames(60)
	dn = bs.duck_now()
	check("... all the way within 2 s", dn.x > -0.1 and music_duck() > -0.1, "%s, bus %.1f dB" % [str(dn), music_duck()])
	cam.position = at
	await frames(2)
	sd.take_damage(99999.0, null, Entity.BLOW_RANGED)
	await step(g, 0.5)
	lv = bs.levels()
	band_on = 0
	lone_on = 0
	for k in lv:
		if float(lv[k]) > -79.0:
			if String(k).begins_with("L"):
				lone_on += 1
			else:
				band_on += 1
	check("no band: the nearest lone musicians are heard, each his own part (at most %d)" % BandSound.LONE_MAX, band_on == 0 and lone_on >= 2 and lone_on <= BandSound.LONE_MAX, "%d band, %d lone" % [band_on, lone_on])
	var offs := {}
	for i in BandSound.LONE_MAX:
		var k := "L%d/a" % i
		if float(lv.get(k, -80.0)) > -79.0:
			offs[k] = float(bs.offsets()[k])
	var distinct := {}
	for k in offs:
		distinct[snappedf(offs[k], 0.001)] = true
	check("lone musicians play OUT OF STEP: off the shared clock, not together", offs.size() >= 2 and offs.values().all(func(v) -> bool: return v > 0.0) and distinct.size() == offs.size(), str(offs))
	for i in 4:
		man(g, "band_piper", at + Vector2(-100 + i * 50, 100)).visible = true
	await step(g, 0.4)
	lv = bs.levels()
	lone_on = 0
	for k in lv:
		if float(lv[k]) > -79.0:
			lone_on += 1
	check("the cap: never more than %d lone musicians heard" % BandSound.LONE_MAX, lone_on <= BandSound.LONE_MAX, str(lone_on))
	# a LONE DRUMMER plays his own background part (owner's playtest 2026-11-14: he used to be next to silent)
	for u in g.units.duplicate():
		if MarchingBand.is_musician(u) and not u.dead:
			u.take_damage(99999.0, null, Entity.BLOW_RANGED)
	await step(g, 0.5)
	var ldr := man(g, "band", at)
	ldr.visible = true
	await step(g, 0.5)
	lv = bs.levels()
	tn = bs.tunes_now()
	var dk := ""
	for i in BandSound.LONE_MAX:
		if float(lv.get("L%d/a" % i, -80.0)) > -79.0:
			dk = "L%d/a" % i
	check("a LONE DRUMMER is heard: his background beating, at the background level, on a tune of the list", dk != "" and absf(float(lv[dk]) - BandSound.QUIET_DB) < 0.5 and BandSound.ORDER.has(String(tn[dk])) and ResourceLoader.exists("res://assets/audio/%s.ogg" % BandSound.file(String(tn[dk]), "drums", false)), "%s %s" % [str(lv), str(tn)])
	g.camera = cam0
	cam.queue_free()

	# ---- SAVES: a new one keeps every musician's state; an old 0.33-0.36 band unit becomes its musicians
	clear(g)
	await step(g, 0.5)
	var vd := man(g, "band", at)
	var vf := man(g, "band_fifer", at + Vector2(24, 0))
	var vp := man(g, "band_piper", at + Vector2(-24, 0))
	await step(g, 0.5)
	vf.band_solo("fife")
	var keep := {"d": MarchingBand.save(vd), "f": MarchingBand.save(vf), "p": MarchingBand.save(vp)}
	g.demo = false
	var dsave := SaveGame.capture(g, {"map": g.map_id, "seed": 4242})
	g.demo = true
	SaveGame.restore(g, dsave)
	await process_frame
	var back := {}
	for u in g.units:
		if u.team == 0 and MarchingBand.is_musician(u) and not u.dead and u.position.distance_to(at) < 40.0:
			back[MarchingBand.ins_of(u)] = u
	check("a save keeps each musician: his number, solo, cooldown, band", back.size() == 3 and MarchingBand.save(back["drums"]) == keep["d"] and MarchingBand.save(back["fife"]) == keep["f"] and MarchingBand.save(back["pipes"]) == keep["p"],
		"%s vs %s" % [str(keep), str(back.values().map(func(u) -> Dictionary: return MarchingBand.save(u)))])
	# an old band unit (0.36.0: one unit, three instruments, 105 health, wounded to 70), a Fife solo under way
	clear(g)
	await step(g, 0.5)
	var old_at := at + Vector2(0, 200)
	var od := {"k": "band", "t": 0, "p": [old_at.x, old_at.y], "hp": 70.0, "band": {"m": ["drums", "fife", "pipes"], "s": "fife", "se": g.clock + 5.0, "cd": {"fife": g.clock + 40.0}, "id": 3}}
	var ou := g._add_unit("band", 0, old_at)
	ou.hp = 40.0
	MarchingBand.load_state(ou, od["band"], true, float(od["hp"]))
	var conv := {}
	for u in g.units:
		if u.team == 0 and MarchingBand.is_musician(u) and not u.dead and u.position.distance_to(old_at) < 40.0:
			conv[MarchingBand.ins_of(u)] = u
	check("AN OLD BAND UNIT loads as its three musicians, standing together", conv.size() == 3, str(conv.keys()))
	if conv.size() == 3:
		check("... already a band", MarchingBand.in_band(conv["drums"]) and MarchingBand.band_key(conv["fife"]) == MarchingBand.band_id(conv["drums"]))
		check("... its wounds shared out (70 of 105: two thirds each)", absf(conv["drums"].hp / conv["drums"].max_hp - 2.0 / 3.0) < 0.02 and absf(conv["fife"].hp / conv["fife"].max_hp - 2.0 / 3.0) < 0.02, "%.1f %.1f" % [conv["drums"].hp, conv["fife"].hp])
		check("... its solo goes on with the Fifer, his cooldown kept", MarchingBand.lead(conv["fife"]) == "fife" and MarchingBand.cooldown_left(conv["fife"]) > 30.0)
	var ou2 := g._add_unit("band", 0, at + Vector2(400, 200))
	g.players[0]["tech"]["band_pipes"] = true
	MarchingBand.load_state(ou2, {"m": ["drums"], "s": "", "se": 0.0, "cd": {}}, true, 60.0)
	var n2 := 0
	for u in g.units:
		if u.team == 0 and u.kind == "band_piper" and not u.dead and u.position.distance_to(ou2.position) < 40.0:
			n2 += 1
	check("an old band with an old save's PIPES research: a Piper comes with it", n2 == 1)
	g.players[0]["tech"].erase("band_pipes")
	# ---- the online snapshot (a replay records the same) and an old replay's band picture
	var vb: Unit = conv.get("fife") if conv.size() == 3 else g._add_unit("band_fifer", 0, at)
	var row := NetSnapshot.unit_vals(vb)
	var copy := g._add_unit("band_fifer", 0, at + Vector2(0, 500))
	NetSnapshot._set_unit_vals(copy, row, 0)
	check("the online snapshot carries a musician's state", MarchingBand.save(copy) == MarchingBand.save(vb), str(MarchingBand.save(copy)))
	check("the snapshot's lists match its values", NetSnapshot.UNIT_PROPS.size() == row.size() and NetSnapshot.UNIT_PROPS.has("band"))
	check("a replay records the field", (ReplayRecorder.lists()["up"] as Array).has("band"))
	var pic := g._add_unit("band", 0, at + Vector2(-500, 500))
	MarchingBand.load_state(pic, {"m": ["drums", "fife", "pipes"], "s": "", "se": 0.0, "cd": {}}, false)
	g.view_rect = Rect2(pic.position - Vector2(500, 500), Vector2(1000, 1000))
	pic._animate(0.2)
	var lf: Sprite2D = pic.sprite.get_node_or_null("band_fife")
	check("an old FULL replay's band picture is drawn as before (its Fifer and Piper with it)", MarchingBand.legacy(pic) and lf != null and lf.visible)
	copy.take_damage(99999.0, null, Entity.BLOW_RANGED)
	pic.take_damage(99999.0, null, Entity.BLOW_RANGED)
	# ---- killed, the buff goes after its linger
	clear(g)
	await step(g, 0.5)
	var kd := man(g, "band", at)
	var ks := man(g, "musketeer", at + Vector2(50, 0))
	await step(g, 0.5)
	var had := ks.band_until > g.clock
	kd.take_damage(99999.0, null, Entity.BLOW_RANGED)
	await step(g, float(B["linger"]) + 0.5)
	check("killed, his buff is gone after its linger", had and ks.band_until <= g.clock and MarchingBand.speed_mul(ks) == 1.0)
	check("an old cfg's marching_band switch is not read", not FileAccess.get_file_as_string("res://scripts/settings.gd").contains("marching_band"))
	print("marching band: %d failures" % fails)
	quit(1 if fails > 0 else 0)
