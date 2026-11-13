extends SceneTree
## THE GROUND SYSTEM (docs/ground_system.md; the owner 2026-11-13 01:34-01:40; scripts/ground_layer.gd, scripts/ground_view.gd):
##   OFF (the default): no layer, the Farm draws its Town Hall's soil as before.
##   ON: a hall lays a DISTRICT of ground (Defs.LAND soil / brass, spread over its open land); a Farm / Cog Press drinks from
##   a CIRCLE round it, evenly, at its full rate while the circle holds ground (the Rootmaw's rule); a circle over spent ground
##   holds less (its "% of a fresh spot"); covered tiles (under a Barracks...) are not drunk; nothing is ever renewed (a hall
##   laid again, a Farm pulled down); a spent Farm no longer counts against the limit, and the limit is its district's;
##   the hall's soil / brass mirror its district; saves round-trip exactly, the net's rows to within a 32nd.
##   godot --headless --fixed-fps 30 --script res://tools/test_ground_system.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-78s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _first(g: Game, t: int, kind: String) -> Building:
	for b in g.buildings:
		if b.team == t and b.kind == kind and not b.dead:
			return b
	return null


func _run() -> void:
	# ---------------------------------------------------------------- off: as before
	Defs.ground_on = false
	var g0 := U.make(root, ["crown", "clockwork"])
	U.step(g0, 0.2)
	check("off: no ground layer", g0.ground_layer == null and g0.land() == null)
	var f0 := _first(g0, 0, "farm")
	var h0 := U.hall(g0, 0)
	var s0 := h0.soil
	var pay0 := g0.harvest(f0)
	check("off: a harvest draws its hall's soil (380)", pay0 == Defs.FARM_YIELD and is_equal_approx(h0.soil, s0 - Defs.FARM_YIELD), "%d, %.0f -> %.0f" % [pay0, s0, h0.soil])
	g0.queue_free()
	await process_frame

	# ---------------------------------------------------------------- on: the districts
	Defs.ground_on = true
	var g := U.make(root, ["crown", "clockwork"])
	U.step(g, 0.2)
	var gl := g.ground_layer
	check("on: the layer is made", gl != null)
	var h := U.hall(g, 0)
	var ct := U.hall(g, 1)
	var dh := gl.district(h)
	var dc := gl.district(ct)
	check("a Town Hall's district holds LAND soil (9,000)", absf(float(dh[1]) - float(Defs.LAND["soil"])) < 1.0 and absf(float(dh[0]) - float(dh[1])) < 1.0, str(dh))
	check("a Clocktower's district holds LAND brass (9,000)", absf(float(dc[1]) - float(Defs.LAND["brass"])) < 1.0, str(dc))
	var soil_tiles := 0
	var brass_tiles := 0
	var on_terrain := 0
	for i in gl.kind.size():
		if gl.kind[i] == GroundLayer.SOIL:
			soil_tiles += 1
		elif gl.kind[i] == GroundLayer.BRASS:
			brass_tiles += 1
		if gl.kind[i] != GroundLayer.NONE and g.solid[i] == 1:
			on_terrain += 1
	check("soil and brass tiles laid, none on cliffs / water / trees", soil_tiles > 100 and brass_tiles > 100 and on_terrain == 0, "%d / %d / %d" % [soil_tiles, brass_tiles, on_terrain])

	# ---------------------------------------------------------------- a Farm drinks its circle
	var farm := _first(g, 0, "farm")
	check("the start Farm stands on fresh ground (holds some, not barren)", gl.held(farm) > 1000.0 and not farm.barren(), "held %.0f, value %.2f" % [gl.held(farm), gl.value(farm)])
	var held0 := gl.held(farm)
	var d0 := float(gl.district(h)[0])
	var pay := g.harvest(farm)
	gl._cache.clear()
	var held1 := gl.held(farm)
	check("a harvest pays in full (380) while its circle holds soil", pay == Defs.FARM_YIELD, str(pay))
	check("...drawn from its circle (and the district), not the hall", absf(held0 - held1 - Defs.FARM_YIELD) < 2.0 and absf(d0 - float(gl.district(h)[0]) - Defs.FARM_YIELD) < 2.0,
		"%.0f -> %.0f" % [held0, held1])
	# evenly: every live tile of its circle lost about the same
	var tiles: PackedInt32Array = gl._of(farm)[0]
	var lo := INF
	var hi := -INF
	for i in tiles:
		if gl.kind[i] == GroundLayer.SOIL and gl.left[i] > 0.0:
			var took := gl.full[i] - gl.left[i]
			lo = minf(lo, took)
			hi = maxf(hi, took)
	check("drawn evenly over its live tiles", hi - lo < 0.01 and hi > 0.0, "%.3f .. %.3f" % [lo, hi])
	# the hall's soil mirrors its district once a second
	gl._tick_t = 0.0
	gl.tick(0.1)
	check("the hall's soil mirrors its district", absf(h.soil / h.reserve() - float(gl.district(h)[0]) / float(gl.district(h)[1])) < 0.001, "%.0f" % h.soil)

	# ---------------------------------------------------------------- spent: barren, pays 0, frees the limit
	for i in tiles:
		if gl.kind[i] == GroundLayer.SOIL:
			gl.left[i] = 0.0
	gl._cache.clear()
	check("a spent circle: barren, value 0", farm.barren() and gl.value(farm) == 0.0)
	check("...its harvest pays 0", g.harvest(farm) == 0)
	var cnt_all := g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and b.kind == "farm" and not b.dead).size()
	check("...and it no longer counts against the limit", g.econ_count(0, "farm") == cnt_all - 1, "%d of %d" % [g.econ_count(0, "farm"), cnt_all])
	check("...nor against its district's", g._district_live(0, "farm", h) == 0)
	var pv := gl.preview("farm", farm.cell)
	check("placing on that spot shows 0% of a fresh spot", float(pv[1]) == 0.0, str(pv))
	# tearing it down renews nothing
	var cell := farm.cell
	g._remove_quietly(farm)
	await process_frame
	gl._cache.clear()
	check("pulled down, the soil is still spent (exhausted means exhausted)", float(gl.preview("farm", cell)[1]) == 0.0)

	# ---------------------------------------------------------------- half a circle over spent ground
	# a spot 10 tiles off: its circle half over the spent one
	var probe := cell + Vector2i(10, 0)
	var half := gl.preview("farm", probe)
	check("a circle partly over spent ground holds less than a fresh one", float(half[1]) < 0.95 and float(half[2]) > 0.0, str(half))

	# ---------------------------------------------------------------- covered ground
	var near := gl.disc(GroundLayer.mid_of(probe, Vector2i(6, 6)), 6.0)
	var free_at := Vector2i(-1, -1)
	for i in near:
		var c := Vector2i(i % gl.w, i / gl.w)
		if g.placement_problem(0, "cottage", c) == "" and gl.kind[i] == GroundLayer.SOIL and gl.left[i] > 0.0:
			free_at = c
			break
	if free_at.x >= 0:
		var before := float(gl.preview("farm", probe)[2])
		var cot := g._add_building("cottage", 0, free_at, true)
		var after := float(gl.preview("farm", probe)[2])
		check("a Cottage on the circle covers its ground (holds less)", after < before, "%.0f -> %.0f" % [before, after])
		g._remove_quietly(cot)
		await process_frame
		check("...and gives it back when it goes", absf(float(gl.preview("farm", probe)[2]) - before) < 1.0)
	else:
		check("a free cell for a Cottage on soil", false)

	# ---------------------------------------------------------------- a hall laid again renews nothing
	var hc := h.cell
	var full_before := float(gl.district(h)[1])
	var left_before := float(gl.district(h)[0])
	gl.found(h)
	check("a hall laid again on its district adds no ground", absf(float(gl.district(h)[0]) - left_before) < 0.5 and absf(float(gl.district(h)[1]) - full_before) < 0.5)

	# ---------------------------------------------------------------- the district limit
	var per := Defs.econ_per_hall("crown", "farm")
	check("the Crown's limit stays %d Farms a hall, now its district's" % per, per == 2 and bool(Defs.LAND["local"]))

	# ---------------------------------------------------------------- Cog Press
	var press := _first(g, 1, "cog_press")
	if press:
		check("the start Cog Press drinks brass from its circle", gl.held(press) > 1000.0 and not press.barren(), "held %.0f" % gl.held(press))
		var hp0 := gl.held(press)
		var got := 0.0
		for k in 10:
			got += g.draw_lode(press, 1.0)
		gl._cache.clear()
		check("its little draws are paid in chunks (LAND bite), all of it", absf(got - 10.0) < 0.01 and absf(hp0 - gl.held(press) - 10.0) < 0.5, "%.2f" % got)
		for i in gl._of(press)[0]:
			if gl.kind[i] == GroundLayer.BRASS:
				gl.left[i] = 0.0
		gl._cache.clear()
		check("spent brass: the press is barren, presses nothing", press.barren() and press.press_rate() == 0.0)
	else:
		check("a start Cog Press", false)

	# ---------------------------------------------------------------- saves, the net
	var sv := gl.save()
	var copy := GroundLayer.new(g)
	copy.load(sv)
	var same := copy.kind == gl.kind and copy.full == gl.full and copy.left == gl.left
	check("a save round-trips exactly", same, "%d tiles, %d chars" % [int(sv["n"]), str(sv).length()])
	var cap := SaveGame.capture(g, {"ground": true}, true)
	check("a saved game (and a MIXED replay's keyframe) carries the layer", cap.has("ground") and int(cap["ground"]["n"]) == int(sv["n"]))
	var sent := {}
	var rows := gl.net_rows(sent, true)
	var guest := GroundLayer.new(g)
	guest.net_apply(rows, true)
	var worst := 0.0
	var kinds_ok := true
	for i in gl.kind.size():
		if gl.kind[i] != guest.kind[i]:
			kinds_ok = false
		if gl.kind[i] != GroundLayer.NONE:
			worst = maxf(worst, absf(gl.fresh(i) - guest.fresh(i)))
	check("the net's keyframe rows give the guest every tile to a 32nd", kinds_ok and worst <= 1.0 / 31.0 + 0.001, "worst %.3f, %d rows" % [worst, rows.size()])
	var f2 := g._add_building("farm", 0, probe, true)
	for k in 6:
		g.harvest(f2)
	var diff := gl.net_rows(sent, false)
	check("...and a change sends only the tiles that moved a step", diff.size() > 0 and diff.size() < rows.size(), "%d of %d" % [diff.size(), rows.size()])
	check("a guest layer never draws", guest.draw(f2, 100.0) == 0.0)

	# ---------------------------------------------------------------- the layer while placing
	g.demo = false
	g.human = 0
	if g.ground_view == null:
		g.ground_view = GroundView.new()
		g.ground_view.game = g
		g.add_child(g.ground_view)
	if g.controls == null:
		var ctl := Controls.new()      # (a demo game has none: one that is never added to the tree, only read)
		ctl.game = g
		g.controls = ctl
	g.controls.mode = "place"
	g.controls.place_kind = "farm"
	g.controls.ghost_cell = probe
	g.ground_view._process(1.0)
	check("placing a Farm: the view shows its circle and a % of a fresh spot", g.ground_view.placing_drinker() and g.ground_view.tex != null,
		"%d%%" % int(round(float(g.ground_view.ghost_share[1]) * 100.0)))
	g.controls.place_kind = "barracks"
	g.ground_view._process(1.0)
	check("placing a Barracks: the faint layer, no circle", g.ground_view.placing and not g.ground_view.placing_drinker())
	g.controls.mode = ""
	Defs.ground_on = false
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
