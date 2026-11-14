## OVERLAY OPACITY (docs/overlay_alpha.md; the owner's playtest 2026-11-14): the bars, chevrons and marks over units
## and buildings are see-through by Settings.overlay_alpha (marks x Entity.MARK_K), full on the selected and the one
## under the mouse, a hurt health bar a little stronger; the setting saves and loads and resets. Also part B (the hall
## texts with NO FARM/PRESS LIMIT on) and part C (a Farm / Cog Press away from every hall says why, with the ground
## system on).
##   godot --headless --fixed-fps 30 --script res://tools/test_overlay_alpha.gd
## Prints CHECK lines and "overlay_alpha: N failures"; exit code 1 on a failure. The player's settings file is put back.
extends SceneTree
var fails := 0
var saved_cfg := ""


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	if FileAccess.file_exists(Settings.PATH):
		saved_cfg = FileAccess.get_file_as_string(Settings.PATH)
	_run.call_deferred()


func make(facs: Array) -> Game:
	var g := Game.new()
	g.map_id = "ashford_crossing"
	g.demo = true
	g.factions = facs
	g.sides = range(facs.size())
	root.add_child(g)
	return g


func hall(g: Game, t: int) -> Building:
	for b in g.buildings:
		if b.team == t and b.kind == g.faction_hall(t) and not b.dead:
			return b
	return null


func _run() -> void:
	Settings.load_all()
	var keep := Settings.overlay_alpha
	# ---- the setting
	Settings.reset()
	check("default OVERLAY OPACITY 0.6", is_equal_approx(Settings.overlay_alpha, 0.6), str(Settings.overlay_alpha))
	Settings.overlay_alpha = 0.45
	Settings.save_all()
	Settings.overlay_alpha = 0.9
	Settings._loaded = false
	Settings.load_all()
	check("saved and read back (0.45)", is_equal_approx(Settings.overlay_alpha, 0.45), str(Settings.overlay_alpha))
	var cfg := ConfigFile.new()
	cfg.load(Settings.PATH)
	cfg.set_value("ui", "overlay_alpha", 0.05)
	cfg.save(Settings.PATH)
	Settings._loaded = false
	Settings.load_all()
	check("a value under 30% read back as 30%", is_equal_approx(Settings.overlay_alpha, 0.3), str(Settings.overlay_alpha))
	Settings.reset()
	check("RESET SETTINGS puts it back to 0.6", is_equal_approx(Settings.overlay_alpha, 0.6))

	# ---- a match: the units' and buildings' overlay opacity
	var g := make(["crown", "clockwork"])
	await process_frame
	await process_frame
	var h := hall(g, 0)
	var at := h.center() + Vector2(0, h.rect().size.y * 0.5 + 120.0)
	var u := g._add_unit("musketeer", 0, at)
	var v := g._add_unit("musketeer", 0, at + Vector2(40, 0))
	u.auto_work = false
	v.auto_work = false
	await process_frame
	check("a unit: the bars at the setting (0.6)", is_equal_approx(u.ov_a(), 0.6), str(u.ov_a()))
	check("a unit: the marks fainter (0.6 x 0.85 = 0.51)", is_equal_approx(u.ov_a(true), 0.6 * Entity.MARK_K), str(u.ov_a(true)))
	u.selected = true
	check("selected: full (bars and marks)", u.ov_a() == 1.0 and u.ov_a(true) == 1.0)
	u.selected = false
	g.hover_target = u
	check("under the mouse: full", u.ov_a() == 1.0 and u.ov_a(true) == 1.0)
	check("  the one beside it stays see-through", is_equal_approx(v.ov_a(), 0.6))
	g.hover_target = null
	Settings.overlay_alpha = 0.4
	check("the setting moved to 0.4: the bars follow", is_equal_approx(u.ov_a(), 0.4))
	Settings.overlay_alpha = 0.6
	u.hp = u.max_hp
	var full_a := u.health_a()
	u.hp = u.max_hp * 0.5
	var half_a := u.health_a()
	u.hp = u.max_hp * 0.1
	var low_a := u.health_a()
	check("the health bar: stronger the more hurt (full %.2f, half %.2f, 10%% %.2f)" % [full_a, half_a, low_a], is_equal_approx(full_a, 0.6) and half_a > full_a and low_a > half_a and low_a < 1.0)
	u.selected = true
	check("  selected and hurt: full", u.health_a() == 1.0)
	u.selected = false
	u.hp = u.max_hp
	check("a building: its bars at the setting, full when selected", is_equal_approx(h.ov_a(), 0.6) and (func() -> bool:
		h.selected = true
		var r := h.ov_a() == 1.0
		h.selected = false
		return r).call())
	check("Entity.ova: alpha times a", Entity.ova(Color(1, 0.5, 0.2, 0.8), 0.5).is_equal_approx(Color(1, 0.5, 0.2, 0.4)))

	# the redraw: a unit is redrawn when the mouse comes onto it or the setting changes (its _ov_k)
	g.camera.position = u.position
	g.update_view_rect()
	u._physics_process(1.0 / 30.0)
	var k0 := u._ov_k
	g.hover_target = u
	u._physics_process(1.0 / 30.0)
	var k1 := u._ov_k
	g.hover_target = null
	Settings.overlay_alpha = 0.8
	u._physics_process(1.0 / 30.0)
	var k2 := u._ov_k
	Settings.overlay_alpha = 0.6
	check("redrawn on hover and on a new setting (_ov_k %d -> %d -> %d)" % [k0, k1, k2], k0 != k1 and k1 != k2 and k0 != k2)

	# the veterancy chevron: the same opacity, full when selected or hovered
	u.kills = 20
	VetChevrons.note(u)
	var sz: Vector2 = g.vet_layer.world_size()
	g.vet_layer._scan()
	g.vet_layer.place(u, sz)
	var spr: Sprite2D = g.vet_layer.vets.get(u)
	check("a chevron is made", spr != null)
	if spr != null:
		check("  see-through at the setting (0.6)", is_equal_approx(spr.self_modulate.a, 0.6), str(spr.self_modulate.a))
		u.selected = true
		g.vet_layer.place(u, sz)
		check("  selected: full", spr.self_modulate.a == 1.0)
		u.selected = false
		g.hover_target = u
		g.vet_layer._process(1.0 / 30.0)
		check("  under the mouse: full at once (not waiting for its slice)", spr.self_modulate.a == 1.0)
		g.hover_target = null
		g.vet_layer._process(1.0 / 30.0)
		check("  the mouse leaves: back to 0.6", is_equal_approx(spr.self_modulate.a, 0.6))
		Settings.overlay_alpha = 0.35
		g.vet_layer._process(1.0 / 30.0)
		check("  the setting changes: every chevron follows at once", is_equal_approx(spr.self_modulate.a, 0.35))
		Settings.overlay_alpha = 0.6

	# ---- part C: a Farm away from every hall, the ground system on / off
	var far := Vector2i(-1, -1)
	for y in range(2, Game.H - 6, 3):
		for x in range(2, Game.W - 6, 3):
			var c := Vector2i(x, y)
			var mid := (Vector2(c) + Vector2(Defs.BUILDINGS["farm"]["size"]) * 0.5) * Game.T
			var close := false
			for b in g.halls_of(0):
				if b.center().distance_to(mid) <= (Defs.ECON_RANGE + 4) * Game.T:
					close = true
			if not close and g.placement_problem(0, "barracks", c) == "":
				far = c
				break
		if far.x >= 0:
			break
	check("a free spot far from the Town Hall found", far.x >= 0)
	var was_on := Defs.ground_on
	Defs.ground_on = false
	var off_msg := g.placement_problem(0, "farm", far)
	Defs.ground_on = true
	var on_msg := g.placement_problem(0, "farm", far)
	Defs.ground_on = was_on
	check("ground system off: 'Must be near your Town Hall.'", off_msg == "Must be near your Town Hall.", off_msg)
	check("ground system on: 'No soil here: Farms draw on the soil of a Town Hall's district.'", on_msg == Game.NO_GROUND_MSG[GroundLayer.SOIL], on_msg)
	g.queue_free()
	await process_frame

	# ---- part B: the hall texts
	var gw := Defs.ground_on
	var nc := Defs.ground_nocap
	Defs.ground_on = false
	Defs.ground_nocap = false
	var th_off := Defs.short_of("town_hall")
	var ab_off := Defs.about_of("town_hall")
	var ct_off := Defs.about_of("clocktower")
	check("experiment off: the Town Hall 'Allows 2 Farms'", th_off.contains("Allows 2 Farms") and ab_off.contains("allows 2 Farms") and ct_off.contains("Allows 2 Cog Presses"))
	Defs.ground_on = true
	Defs.ground_nocap = false
	check("ground system without NO LIMIT: unchanged", Defs.short_of("town_hall") == th_off)
	Defs.ground_nocap = true
	var texts := [Defs.short_of("town_hall"), Defs.about_of("town_hall"), Defs.tip("town_hall"), Defs.about_of("clocktower"),
		Defs.nocap_text("Haulers %d/%d · Soil: %d%% (%d gold)%s · Saltpetre: %d%% (%d powder)%s · allows 2 Farms and 1 Powder Mill nearby"),
		Defs.nocap_text("Brass: %d left%s · Spring life: %d left%s · allows 2 Cog Presses and 1 Mainspring nearby")]
	var bad: Array = texts.filter(func(t: String) -> bool: return t.contains("2 Farms") or t.contains("2 Cog Presses"))
	check("NO FARM/PRESS LIMIT on: no hall text says '2 Farms' / '2 Cog Presses'", bad.is_empty(), str(bad))
	check("  the Town Hall: Farms limited by its district's soil, still 1 Mill", String(texts[1]).contains("limited only by the soil of its district") and String(texts[1]).contains("1 Powder Mill"))
	check("  the Clocktower: Cog Presses limited by its district's brass, still 1 Mainspring", String(texts[3]).contains("limited only by the brass of its district") and String(texts[3]).contains("1 Mainspring"))
	# translated, and the card's line still short
	var miss: Array = []
	var long: Array = []
	for lang in ["pt", "es"]:
		Loc.set_lang(lang)
		for t in texts:
			var tr := Loc.t(String(t))
			if tr == String(t):
				miss.append("%s: %s" % [lang, String(t).left(50)])
		for w in ["No soil here: Farms draw on the soil of a Town Hall's district.", "No brass here: Cog Presses draw on the brass of a Clocktower's district.", "OVERLAY OPACITY"]:
			if Loc.t(w) == w:
				miss.append("%s: %s" % [lang, w])
		if Loc.t(String(texts[0])).length() > Defs.SHORT_MAX:
			long.append(lang)
	Loc.set_lang("en")
	check("translated in pt and es (texts, the refusals, the setting)", miss.is_empty(), str(miss))
	check("the card's line within %d characters in every language" % Defs.SHORT_MAX, long.is_empty() and String(texts[0]).length() <= Defs.SHORT_MAX, str(long))
	Defs.ground_on = gw
	Defs.ground_nocap = nc

	Settings.overlay_alpha = keep
	if saved_cfg != "":
		var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		f.store_string(saved_cfg)
		f.close()
	elif FileAccess.file_exists(Settings.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	print("overlay_alpha: %d failures" % fails)
	quit(1 if fails > 0 else 0)
