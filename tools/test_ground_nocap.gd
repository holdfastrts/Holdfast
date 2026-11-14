extends SceneTree
## NO FARM/PRESS LIMIT (ground-nocap-study, docs/ground_nocap_study.md; Defs.ground_nocap, only with the ground system on):
##   the switch off: the district's limit as before (2 Farms a Town Hall); on: the player may lay a third (fourth...) Farm by
##   the same hall, the Powder Mill keeps its 1 a hall; a computer gets one more by a hall only while the district's ground,
##   shared out, pays LAND nocap_pay times its price and crew's (Game.nocap_allow); the worker caps grow by the extra crews.
##   godot --headless --fixed-fps 30 --script res://tools/test_ground_nocap.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-78s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _farms_by(g: Game, h: Building) -> int:
	var n := 0
	for b in g.buildings:
		if b.team == 0 and b.kind == "farm" and not b.dead and g.nearest_hall(b.center(), 0) == h:
			n += 1
	return n


## Lays Farms by hall h until it has n (true when it could).
func _fill(g: Game, h: Building, n: int) -> bool:
	var guard := 0
	while _farms_by(g, h) < n and guard < 6:
		guard += 1
		var c := g.find_spot(0, "farm", h, 4, Defs.ECON_RANGE - 2, "behind")
		if c.x < 0:
			return false
		g._add_building("farm", 0, c, true)
	return _farms_by(g, h) >= n


func _run() -> void:
	Defs.ground_on = true
	# ---------------------------------------------------------------- the switch off: the district's limit
	Defs.ground_nocap = false
	var g0 := U.make(root, ["crown", "clockwork"])
	U.step(g0, 0.2)
	var h0 := U.hall(g0, 0)
	_fill(g0, h0, 2)
	var c0 := g0.find_spot(0, "farm", h0, 4, Defs.ECON_RANGE - 2, "behind")
	check("off: a third Farm by the hall finds no spot", c0.x < 0 and g0.econ_capped("farm"))
	g0.queue_free()
	await process_frame

	# ---------------------------------------------------------------- the switch on: the player
	Defs.ground_nocap = true
	var g := U.make(root, ["crown", "clockwork"])
	U.step(g, 0.2)
	var h := U.hall(g, 0)
	check("on: Farms and Cog Presses are not capped, the Mill and Mainspring are", not g.econ_capped("farm") and not g.econ_capped("cog_press")
		and g.econ_capped("powder_mill") and g.econ_capped("mainspring"))
	check("the player's side is not a computer's", not g.is_ai_team(0))
	check("the player lays a third and a fourth Farm by one hall", _fill(g, h, 4), "%d" % _farms_by(g, h))
	var cm := g.find_spot(0, "powder_mill", h, 4, Defs.ECON_RANGE - 2, "behind")
	if cm.x >= 0:
		g._add_building("powder_mill", 0, cm, true)
	var cm2 := g.find_spot(0, "powder_mill", h, 4, Defs.ECON_RANGE - 2, "behind")
	check("...but still one Powder Mill a hall", g.econ_count(0, "powder_mill") == 1 and cm2.x < 0)
	g.queue_free()
	await process_frame

	# ---------------------------------------------------------------- the switch on: a computer's rule
	var g2 := U.make(root, ["crown", "clockwork"])
	U.step(g2, 0.2)
	g2.ais.append({"team": 0})          # (side 0 counts as a computer's for Game.is_ai_team)
	var h2 := U.hall(g2, 0)
	_fill(g2, h2, 2)
	check("a computer: one more by a fresh hall (the ground shared by 3 pays for it)", g2.nocap_allow(0, "farm", h2) == 3,
		"allow %d, district %s" % [g2.nocap_allow(0, "farm", h2), str(g2.ground_layer.district(h2))])
	var gl := g2.ground_layer
	for i in gl.disc(h2.center() / Defs.TILE, GroundLayer.district_r(GroundLayer.SOIL)):
		if gl.kind[i] == GroundLayer.SOIL:
			gl.left[i] *= 0.3            # (the district down to ~30%: 2,700 shared by 3 is under 3 x 500)
	gl._cache.clear()
	gl.rev += 1
	g2._nocap_cache.clear()
	check("...none once the district's ground left would not pay for it", g2.nocap_allow(0, "farm", h2) == 2,
		"allow %d, district %s" % [g2.nocap_allow(0, "farm", h2), str(gl.district(h2))])
	check("no extra Farms yet: no extra hands", g2.nocap_extra(0, "farm") == 0)
	g2.queue_free()
	await process_frame
	Defs.ground_nocap = false
	Defs.ground_on = false
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
