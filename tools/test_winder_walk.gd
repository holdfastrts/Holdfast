extends SceneTree
## WINDING ON THE MARCH (docs/winder_walk.md, scripts/winder_walk.gd): two groups of Clock Soldiers with a low charge march
## side by side across the map, off the gear field; one has 2 Winders with it (on the same move order), the other none.
## The Winders wind the walking soldiers from behind them, one after another, and the group arrives wound; they keep
## behind the soldier they wind; the soldiers are not slowed (the wound group arrives no later than the other); the
## Winders play the walk-wind strip and go back to their own move afterwards. Also: a REPAIR order by hand on a walking
## soldier; a faster unit wound by hand goes at the Winder's pace while he winds it.
##   godot --headless --fixed-fps 30 --script res://tools/test_winder_walk.gd
##   (FILM=1: frames to docs/shots/winder_walk/, needs a display: xvfb-run -a godot --rendering-driver opengl3
##    --resolution 1280x720 --script res://tools/test_winder_walk.gd)
const U := preload("res://tools/gear_test_util.gd")
const N := 6
var fails := 0
var film := OS.get_environment("FILM") == "1"


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _open_near(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 6))


## A straight stretch of open, walkable ground at least `len` px long, off the gear field: [from, to].
func _lane(g: Game, avoid: Vector2, len: float, side: float) -> Array:
	var sz := Vector2(g.W * Defs.TILE, g.H * Defs.TILE)
	var best: Array = []
	var bd := -INF
	for yi in range(4, 40):
		var y := sz.y * yi / 44.0
		for xi in range(2, 20):
			var a := Vector2(sz.x * xi / 22.0, y)
			var b := a + Vector2(len, 0)
			var a2 := a + Vector2(0, side)
			var b2 := b + Vector2(0, side)
			if b.x > sz.x - 64 or a2.y > sz.y - 64:
				continue
			var ok := true
			for p in [a, b, a2, b2, (a + b) * 0.5, (a2 + b2) * 0.5]:
				if not g.is_free(g.cell_of(p)) or g.in_field(0, p) or p.distance_to(avoid) < 900.0:
					ok = false
					break
			if not ok or not g.line_clear(a, b, 12.0) or not g.line_clear(a2, b2, 12.0):
				continue
			var dd := minf(a.distance_to(avoid), b.distance_to(avoid))
			if dd > bd:
				bd = dd
				best = [a, b]
	return best


func _run() -> void:
	Settings.charge_bars = true
	var g := U.make(root)
	await process_frame
	await process_frame
	g.human = 0
	g.players[0]["gold"] = 5000
	var hall := U.hall(g, 0)
	for u in g.units.duplicate():
		if u.team == 1:
			u.position = hall.center() + Vector2(-99999, -99999)     # (the enemy's men out of the way: no fights)
	var lane := _lane(g, hall.center(), 1500.0, 260.0)
	check("found an open lane off the gear field", not lane.is_empty())
	if lane.is_empty():
		return _end()
	var a: Vector2 = lane[0]
	var b: Vector2 = lane[1]
	var off := Vector2(0, 260)
	print("lane %s -> %s" % [a, b])
	# the two groups, the same men with the same low charge; the Winders behind the first
	var wound: Array = []
	var bare: Array = []
	for i in N:
		var p := a + Vector2(-(i % 3) * 26.0, (i / 3) * 26.0 - 13.0)
		var s: Unit = g._add_unit("clock_soldier", 0, _open_near(g, p))
		s.wind = 0.3
		wound.append(s)
		var s2: Unit = g._add_unit("clock_soldier", 0, _open_near(g, p + off))
		s2.wind = 0.3
		bare.append(s2)
	var w1: Unit = g._add_unit("winder", 0, _open_near(g, a + Vector2(-90, -20)))
	var w2: Unit = g._add_unit("winder", 0, _open_near(g, a + Vector2(-90, 20)))
	for w in [w1, w2]:
		w.wind = 1.0
		w.auto_work = false
	U.step(g, 0.5)
	# one move order for each group (as a box-select and a right-click would: the Winders come along)
	for i in N:
		wound[i].cmd_move(b + Vector2(-(i % 3) * 26.0, (i / 3) * 26.0 - 13.0))
		bare[i].cmd_move(b + off + Vector2(-(i % 3) * 26.0, (i / 3) * 26.0 - 13.0))
	w1.cmd_move(b + Vector2(-100, -20))
	w2.cmd_move(b + Vector2(-100, 20))
	var t := 0.0
	var arrive_w := -1.0
	var arrive_b := -1.0
	var behind := 0
	var beside := 0
	var winding_samples := 0
	var slowed := 0
	var anim_ww := 0
	var picked := {}
	var min_v_ratio := 1.0
	var reach_b := [INF, INF]
	var frame := 0
	var shots := "res://docs/shots/winder_walk/"
	if film:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
	while t < 60.0:
		U.step(g, 1.0 / 30.0 * 3.0)
		t += 0.1
		reach_b[0] = minf(reach_b[0], w1.position.distance_to(b + Vector2(-100, -20)))
		reach_b[1] = minf(reach_b[1], w2.position.distance_to(b + Vector2(-100, 20)))
		for w in [w1, w2]:
			if w.order == "repair" and w.order_target is Unit and wound.has(w.order_target):
				picked[w.order_target] = true
			if w.work == "repairing" and w._ww_on and w.velocity.length() > 10.0 and w.order_target is Unit:
				var e: Unit = w.order_target
				winding_samples += 1
				var rel: Vector2 = w.position - e.position
				if rel.dot(e.velocity.normalized()) < 0.0:
					behind += 1
				if rel.length() < 50.0:
					beside += 1
				if e._ww_cap_t > 0.0:
					slowed += 1
				var full := float(e.d["speed"]) * lerpf(0.75, 1.0, e.wind)
				if e.velocity.length() > 10.0:
					min_v_ratio = minf(min_v_ratio, e.speed / full)
				if w._anim_name() == "walk_wind":
					anim_ww += 1
		if arrive_w < 0.0 and wound.all(func(s: Unit) -> bool: return s.order == "idle"):
			arrive_w = t
		if arrive_b < 0.0 and bare.all(func(s: Unit) -> bool: return s.order == "idle"):
			arrive_b = t
		if film and int(t * 10.0) % 20 == 0 and frame < 20:
			await _shot(g, w1, shots + "march_%02d.png" % frame)
			frame += 1
		if arrive_w > 0.0 and arrive_b > 0.0 and t > maxf(arrive_w, arrive_b) + 3.0:
			break
	var ww := wound.map(func(s: Unit) -> float: return s.wind)
	var wb := bare.map(func(s: Unit) -> float: return s.wind)
	var mean_w: float = ww.reduce(func(x, y): return x + y, 0.0) / N
	var mean_b: float = wb.reduce(func(x, y): return x + y, 0.0) / N
	print("arrived: with Winders %.1f s (charge %s), without %.1f s (charge %s)" % [arrive_w, _fmt(ww), arrive_b, _fmt(wb)])
	print("winding on the move: %d samples, behind %d, within 50 px %d, walk_wind strip %d, %d soldiers picked" % [winding_samples, behind, beside, anim_ww, picked.size()])
	check("both groups arrived", arrive_w > 0.0 and arrive_b > 0.0, "%.1f / %.1f s" % [arrive_w, arrive_b])
	check("the Winders wound the soldiers while walking", winding_samples > 50, str(winding_samples))
	check("every soldier of the group was wound on the way", picked.size() >= N, "%d of %d" % [picked.size(), N])
	check("the group arrives wound (every one >= 75%)", ww.all(func(x: float) -> bool: return x >= 0.75), _fmt(ww))
	check("much more charge than the group without Winders", mean_w > mean_b + 0.4, "%.2f vs %.2f" % [mean_w, mean_b])
	check("the Winder keeps behind the soldier he winds (>= 90%)", behind >= winding_samples * 0.9, "%d of %d" % [behind, winding_samples])
	check("and close to it (within 50 px, >= 90%)", beside >= winding_samples * 0.9, "%d of %d" % [beside, winding_samples])
	check("the soldiers are never slowed by him (no pace cap)", slowed == 0 and min_v_ratio >= 0.99, "cap %d, speed ratio %.3f" % [slowed, min_v_ratio])
	check("the wound group arrives no later than the other", arrive_w <= arrive_b + 1.0, "%.1f vs %.1f" % [arrive_w, arrive_b])
	check("the Winder plays the walk-wind strip while winding on the move", anim_ww >= winding_samples * 0.8, "%d of %d" % [anim_ww, winding_samples])
	check("the Winders went back to their own move and reached its end", reach_b[0] < 40.0 and reach_b[1] < 40.0, "%.0f, %.0f px" % reach_b)
	# (the other group, run down, out of the way: idle Winders would wind it, standing, by their REPAIR autocast)
	for s0 in bare:
		g.units.erase(s0)
		s0.queue_free()
	U.step(g, 0.2)
	# ---- by hand: REPAIR on a walking soldier
	var s3: Unit = g._add_unit("clock_soldier", 0, _open_near(g, w1.position + Vector2(30, 0)))
	s3.wind = 0.4
	s3.cmd_move(a)
	U.step(g, 0.5)
	w1.cmd_repair(s3)
	var hand_samples := 0
	for i in 60:
		U.step(g, 0.1)
		if w1.work == "repairing" and w1._ww_on and w1.velocity.length() > 10.0:
			hand_samples += 1
	check("by hand: REPAIR on a walking soldier winds it on the move", hand_samples > 20 and s3.wind > 0.9, "%d samples, charge %.2f" % [hand_samples, s3.wind])
	check("by hand: done, and nothing else walking near, he stops", w1.order == "idle", w1.order)
	# ---- by hand, a faster ground unit (a Clock Soldier made fast for the test: the gear roster's only faster
	# constructs fly, and a flyer is not followed): the pair goes at the Winder's pace while he winds it
	var fast: Unit = g._add_unit("clock_soldier", 0, _open_near(g, w2.position + Vector2(30, 0)))
	fast.d = fast.d.duplicate()
	fast.d["speed"] = 110
	fast.wind = 0.3
	fast.cmd_move(b + Vector2(-1400, 0))
	U.step(g, 0.3)
	w2.cmd_repair(fast)
	var capped := 0
	var fv := 0.0
	for i in 40:
		U.step(g, 0.1)
		if fast._ww_cap_t > 0.0:
			capped += 1
			fv = maxf(fv, fast.speed)
	check("by hand, a faster unit: the pair goes at the Winder's pace while he winds it", capped > 10 and fv <= float(w2.d["speed"]) + 2.0,
			"%d ticks, %.0f px/s (Winder %s)" % [capped, fv, w2.d["speed"]])
	# ---- the auto pick leaves a faster unit and a flyer alone
	fast.wind = 0.3
	var sw: Unit = g._add_unit("cuckoo", 0, _open_near(g, w2.position + Vector2(-30, 0)))
	sw.wind = 0.2
	sw.cmd_move(b)
	w2.cmd_move(b + Vector2(-1400, 0))
	U.step(g, 0.5)
	var cand := WinderWalk.pick(w2)
	check("the auto pick leaves a faster unit and a flyer alone", cand != fast and cand != sw, str(cand.kind if cand else "none"))
	_end()


func _fmt(a: Array) -> String:
	return ", ".join(a.map(func(x: float) -> String: return "%.2f" % x))


func _shot(g: Game, w: Unit, path: String) -> void:
	g.camera.position = w.position + Vector2(60, 0)
	g.camera.zoom = Vector2(2.4, 2.4)
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))


func _end() -> void:
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
