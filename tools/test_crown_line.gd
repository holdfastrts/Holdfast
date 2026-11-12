extends SceneTree
## THE CROWN'S LINE (crown-line-fight, docs/crown_line_fight.md; scripts/ai_crown_line.gd):
##  1. a DEFENDING Crown army forms a line ACROSS the approach of a force at its buildings: the muskets' spots spread
##     across the direction to the force (wider than deep), the guns' spots behind the muskets, and the men get there
##  2. a MARCHING wave that sees an enemy army ahead FORMS its line before contact: when the first enemy comes within
##     contact of a musket, the muskets stand wider than deep across the line to the enemy and the guns are behind them
##  3. `-- line:off` is the old way (no line), and AI.line_orders is what Game.line_move gives a player's drag
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_line.gd
var main: Node
var g: Game
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _until(clock: float, cond := Callable()) -> void:
	while g.clock < clock and not g.over:
		await physics_frame
		if cond.is_valid() and cond.call():
			return


func _start(fa: String, fb: String) -> void:
	if main != null:
		main.queue_free()
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(6161)
	main.start({"map": "greenhold", "seed": 6161, "slots": [
		{"who": "hard", "faction": fa, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": fb, "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false


func _ai(t: int):
	for a in g.ais:
		if a.team == t:
			return a
	return null


func _spawn(kind: String, t: int, p: Vector2) -> Unit:
	var c: Vector2i = g.nearest_free(g.cell_of(g.on_map(p)), 6)
	return g._add_unit(kind, t, g.cell_center(c))


## [across, depth, mean] of points about `face` (two standard deviations, px).
func _shape(pts: Array, face: Vector2) -> Array:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= maxi(1, pts.size())
	var perp := Vector2(-face.y, face.x)
	var sa := 0.0
	var sd := 0.0
	for p in pts:
		sa += pow((p - c).dot(perp), 2)
		sd += pow((p - c).dot(face), 2)
	var k := float(maxi(1, pts.size()))
	return [2.0 * sqrt(sa / k), 2.0 * sqrt(sd / k), c]


func _run() -> void:
	await _start("crown", "crown")
	await _until(2.0)
	var ai = _ai(0)
	_ai(1).process_mode = Node.PROCESS_MODE_DISABLED
	check(ai.line_ai() != null and ai.ln.active(), "the Crown computer (Hard) plays the line")
	# 1. THE DEFENCE: 8 Musketeers and 2 Field Cannons by the main hall, 6 enemy Musketeers on HOLD 11 tiles off on the main
	var hall: Building = g.halls_of(0)[0]
	var home: Vector2 = hall.center()
	var ln = ai.ln
	var mine: Array = []
	for i in 8:
		mine.append(_spawn("musketeer", 0, home + Vector2(-60 + (i % 4) * 30, 90 + (i / 4) * 30)))
	var guns: Array = []
	for i in 2:
		var gu := _spawn("cannon", 0, home + Vector2(-40 + i * 80, 160))
		guns.append(gu)
		mine.append(gu)
	# the force: toward the enemy's side, on the main's level
	var dir: Vector2 = (Vector2(g.starts[1]) - Vector2(g.starts[0])).normalized()
	var at: Vector2 = home
	for k in range(14, 6, -1):
		var q: Vector2 = home + dir.rotated(0.9) * k * Defs.TILE
		if g.open_cell(g.cell_of(q)) and g.level_of(q) == g.level_of(home):
			at = q
			break
	var foes: Array = []
	for i in 6:
		var f := _spawn("musketeer", 1, at + Vector2((i % 3) * 26, (i / 3) * 26))
		f.cmd_hold()
		foes.append(f)
	var d0: int = ln.def_lines
	await _until(g.clock + 8.0, func() -> bool: return ln.def_lines > d0)
	check(ln.def_lines > d0, "the defence goes out as a line (%d)" % (ln.def_lines - d0))
	var spots_m: Array = []
	var spots_g: Array = []
	for u in ln._def_spot:
		if u.kind == "musketeer":
			spots_m.append(ln._def_spot[u])
		elif u.kind == "cannon":
			spots_g.append(ln._def_spot[u])
	var face: Vector2 = (at - home).normalized()
	if spots_m.size() >= 4:
		var sh := _shape(spots_m, face)
		print("   defence spots: %d muskets, across %d px, depth %d px; %d guns" % [spots_m.size(), int(sh[0]), int(sh[1]), spots_g.size()])
		check(sh[0] > 2.0 * maxf(sh[1], 10.0), "the muskets' spots stand across the approach (across %d, depth %d)" % [int(sh[0]), int(sh[1])])
		var behind := spots_g.all(func(p: Vector2) -> bool: return (p - sh[2]).dot(face) < -20.0)
		check(spots_g.size() == 2 and behind, "the guns' spots are behind the muskets (%s)" % str(spots_g.map(func(p: Vector2) -> int: return int((p - sh[2]).dot(face)))))
		var sp: Array = ln._def_spot.duplicate().keys().filter(func(u) -> bool: return u.kind == "musketeer")
		var want: Dictionary = ln._def_spot.duplicate()
		var near := 0
		for kk in 5:
			await _until(g.clock + 2.5)
			var k2 := 0
			for u in sp:
				if is_instance_valid(u) and not u.dead and (u.position.distance_to(want[u]) < 50.0 or u.target != null):
					k2 += 1
			near = maxi(near, k2)
		check(near >= int(sp.size() * 0.6), "the muskets got to the line or are firing from it (%d of %d)" % [near, sp.size()])
	else:
		check(false, "the defence line has its muskets' spots (%d)" % spots_m.size())
	for u in mine + foes:
		if is_instance_valid(u) and not u.dead:
			u.take_damage(99999.0, null)
	ai._end_defence()
	await _until(g.clock + 2.0)
	# 2. THE MARCH: 10 Musketeers and 2 Field Cannons together in the open middle, sent as a wave toward the enemy; an
	# enemy force of 6 Musketeers on HOLD ahead of them
	ai.peaceful = true          # (no wave of its own: the test sends this one)
	var f0: int = ai.ln.forms
	var mid := Vector2(Game.W, Game.H) * Defs.TILE * 0.5
	var goal: Vector2 = Vector2(g.starts[1]) * Defs.TILE
	var to_goal: Vector2 = (goal - mid).normalized()
	var wave: Array = []
	for i in 10:
		wave.append(_spawn("musketeer", 0, mid - to_goal * 300.0 + Vector2((i % 5) * 26, (i / 5) * 26)))
	for i in 2:
		wave.append(_spawn("cannon", 0, mid - to_goal * 360.0 + Vector2(i * 50, 0)))
	var foe_at: Vector2 = mid + to_goal * 420.0
	foes.clear()
	for i in 6:
		var f := _spawn("musketeer", 1, foe_at + Vector2((i % 3) * 26, (i / 3) * 26))
		f.cmd_hold()
		foes.append(f)
	# (a rider out ahead sees them, as the scouts do: the line forms on what the army knows)
	var spotter := _spawn("cuirassier", 0, foe_at - to_goal.rotated(1.2) * 235.0)
	spotter.cmd_hold()
	await _until(g.clock + 3.5)
	ai._attacking = true
	ai._wave_set.clear()
	for u in wave:
		ai._wave_set[u] = true
		u.cmd_move(goal, true)
	var contact := func() -> bool:
		for u in wave:
			if is_instance_valid(u) and not u.dead and u.kind == "musketeer":
				for o in foes:
					if is_instance_valid(o) and not o.dead and o.position.distance_to(u.position) < 215.0:
						return true
		return false
	for kk in 12:
		await _until(g.clock + 1.0, contact)
		print("   t %.1f st %s said %s known %d seen %d spotter vis %s" % [g.clock, ln.st, str(ln.said.slice(-1)), ln._known(wave).size(), ai.ch._seen.size(), str(g.is_visible_to(0, foes[0].position))])
	await _until(g.clock + 60.0, contact)
	check(ln.forms > f0, "the wave formed its line before the enemy ahead (%s)" % str(ln.said.slice(-3)))
	var ms: Array = []
	var gs: Array = []
	for u in wave:
		if is_instance_valid(u) and not u.dead:
			(ms if u.kind == "musketeer" else gs).append(u.position)
	var fc := Vector2.ZERO
	for o in foes:
		fc += o.position
	fc /= foes.size()
	var sh2 := _shape(ms, (fc - _shape(ms, Vector2.RIGHT)[2]).normalized())
	var face2: Vector2 = (fc - sh2[2]).normalized()
	sh2 = _shape(ms, face2)
	var perp2 := Vector2(-face2.y, face2.x)
	print("   (across, along): %s; the line said %s" % [str(ms.map(func(p: Vector2) -> String: return "%d,%d" % [int((p - sh2[2]).dot(perp2)), int((p - sh2[2]).dot(face2))])), str(ln.said.slice(-2))])
	print("   at contact (%.0f s): %d muskets across %d px, depth %d px" % [g.clock, ms.size(), int(sh2[0]), int(sh2[1])])
	check(sh2[0] > 1.5 * maxf(sh2[1], 10.0), "at contact the muskets stand in a line across (across %d, depth %d)" % [int(sh2[0]), int(sh2[1])])
	check(not gs.is_empty() and gs.all(func(p: Vector2) -> bool: return (p - sh2[2]).dot(face2) < 0.0),
			"at contact the guns are behind the line (%s)" % str(gs.map(func(p: Vector2) -> int: return int((p - sh2[2]).dot(face2)))))
	# 3. line_orders is the drag's assignment: one spot each, in order along the line
	var pts := PackedVector2Array([mid + Vector2(-100, 200), mid + Vector2(100, 200)])
	var some: Array = []
	for i in 4:
		some.append(_spawn("musketeer", 0, mid + Vector2(-90 + i * 60, 260)))
	var got: Dictionary = g.line_orders(some, pts, false)
	var xs: Array = some.map(func(u: Unit) -> float: return (got[u] as Vector2).x)
	check(got.size() == 4 and xs == xs.duplicate().map(func(x): return x) and xs[0] < xs[1] and xs[1] < xs[2] and xs[2] < xs[3],
			"line_orders gives each man his own spot in order along the line (%s)" % str(xs))
	print("FAILS %d" % fails)
	print("ALL PASS" if fails == 0 else "SOME FAILED")
	quit(1 if fails > 0 else 0)
