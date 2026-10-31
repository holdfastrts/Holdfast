extends SceneTree
## DIAGONAL palisade (docs/wall_diag.md): pieces that touch only at their corners join
## diagonally (Game.wall_links bits 16 NE, 32 SE, 64 SW, 128 NW) and show the diagonal
## pictures; nobody walks or squeezes through the corner between them; gates still work.
##   godot --headless --fixed-fps 30 --script res://tools/test_wall_diag.gd
## With pictures (docs/shots/wall_diag/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 \
##       --script res://tools/test_wall_diag.gd -- shots
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var shots := false
const OUT := "res://docs/shots/wall_diag"


func _initialize() -> void:
	shots = "shots" in OS.get_cmdline_user_args()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _open_area(w: int, h: int) -> Vector2i:
	var hall: Building = g.halls_of(0)[0]
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(4, g.H - h - 4):
		for x in range(4, g.W - w - 4):
			var c := Vector2i(x, y)
			var d := Vector2(c).distance_to(Vector2(hall.cell))
			if d < 12.0 or d > bd:
				continue
			var h0: int = g.height[g.idx(c)]
			var ok := true
			for yy in h:
				for xx in w:
					var q := c + Vector2i(xx, yy)
					if g.solid[g.idx(q)] != 0 or g.ramp[g.idx(q)] != 0 or g.height[g.idx(q)] != h0:
						ok = false
						break
				if not ok:
					break
			if ok:
				best = c
				bd = d
	return best


func _pic(b: Building) -> String:
	return b.sprite.texture.resource_path.get_file() if b.sprite.texture else ""


func _extras(b: Building) -> Array:
	var out: Array = []
	for s in b._wall_extra:
		out.append([s.texture.resource_path.get_file().get_basename(), s.show_behind_parent])
	return out


func _wall(c: Vector2i, k := "wall", team := 0) -> Building:
	return g._add_building(k, team, c, true)


## Side of the line through p1 -> p2 (+1 / -1), and whether p projects inside the segment.
func _side(p: Vector2, p1: Vector2, p2: Vector2) -> Array:
	var d := p2 - p1
	var cr := d.x * (p.y - p1.y) - d.y * (p.x - p1.x)
	var along := (p - p1).dot(d) / d.length_squared()
	return [signf(cr), along > 0.04 and along < 0.96]


## A unit walks from `from` to `to` (a right click): does it cross the segment p1-p2 (the
## wall) between its ends, and does it get there?
func _walk(kind: String, team: int, from: Vector2, to: Vector2, p1: Vector2, p2: Vector2, secs := 25.0) -> Dictionary:
	var u: Unit = g._add_unit(kind, team, from)
	await physics_frame
	g.smart_command([u], to, true)
	var side: float = _side(u.position, p1, p2)[0]
	var through := 0
	var walked := 0.0
	var last := u.position
	var n := int(secs * 30)
	for i in n:
		await physics_frame
		if u.dead:
			break
		var s: Array = _side(u.position, p1, p2)
		if s[0] != 0.0 and s[0] != side:
			if s[1]:
				through += 1
			side = s[0]
		walked += u.position.distance_to(last)
		last = u.position
		if u.position.distance_to(to) < 12.0:
			break
	var out := {"through": through, "arrived": u.position.distance_to(to) < 24.0, "walked": walked,
			"end": u.position}
	g.consume_unit(u)
	await physics_frame
	return out


## Shove a unit straight at the corner between two diagonal pieces, every step through
## resolve_terrain (no pathfinder): does it come out on the far side?
func _squeeze(kind: String, team: int, corner: Vector2, dir: Vector2, step: float) -> bool:
	var u: Unit = g._add_unit(kind, team, corner - dir * 20.0)
	await physics_frame
	var r: float = u.radius
	var p: Vector2 = g.resolve_terrain(corner - dir * 20.0, corner - dir * 20.0, r, team)
	for i in 60:
		p = g.resolve_terrain(p + dir * step, p, r, team)
	g.consume_unit(u)
	return (p - corner).dot(dir) > 4.0


func _shoot(name: String, at: Vector2, zoom: float) -> void:
	if not shots:
		return
	var cam: Camera2D = g.camera
	cam.position = at
	cam.zoom = Vector2(zoom, zoom)
	cam.reset_smoothing()
	for i in 6:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_viewport().get_texture().get_image().save_png(OUT.path_join(name))
	print("shot ", OUT.path_join(name))


func _run() -> void:
	g.explored.fill(1)
	if "reveal" in g:
		g.reveal = true
	if g.hud and shots:
		g.hud.visible = false
	for u in g.units.duplicate():
		if u.team != 0:
			g.consume_unit(u)
	var a := _open_area(16, 14)
	check(a.x >= 0, "an open 16x14 field")
	if a.x < 0:
		quit(1)
		return
	var T: float = g.T
	# 1. a "\" line of 7 pieces laid one by one, corner to corner
	var line: Array = []
	for i in 7:
		line.append(_wall(a + Vector2i(4 + i, 3 + i)))
	await physics_frame
	var mid: Building = line[3]
	check(mid.links == 32 | 128, "a middle piece joins NW and SE only (links %d)" % mid.links)
	check(_pic(mid) == "wall_diag_se_built.png", "a middle piece shows the \\ picture (%s)" % _pic(mid))
	check(_extras(mid).is_empty(), "and nothing else")
	var top: Building = line[0]
	check(top.links == 32 and _pic(top) == "wall_diag_hub_built.png"
			and _extras(top) == [["wall_diag_half_se_built", false]],
			"the top end: a centre stake and the half to the SE (%d %s %s)" % [top.links, _pic(top), str(_extras(top))])
	# the old four bits are untouched: an ordinary straight piece beside nothing diagonal
	var lone: Building = _wall(a + Vector2i(1, 12))
	var lone2: Building = _wall(a + Vector2i(2, 12))
	await physics_frame
	check(lone.links == 2 and _pic(lone) == "wall_e_built.png", "a straight piece is as before (%d %s)" % [lone.links, _pic(lone)])
	# 2. "/" pieces
	var sl: Array = []
	for i in 3:
		sl.append(_wall(a + Vector2i(14 - i, 1 + i)))
	await physics_frame
	check(sl[1].links == 16 | 64 and _pic(sl[1]) == "wall_diag_sw_built.png", "a / middle piece (%d %s)" % [sl[1].links, _pic(sl[1])])
	# 3. mixed: a straight run east from the bottom end of the "\" line
	var bot: Building = line[6]
	var east: Building = _wall(bot.cell + Vector2i(1, 0))
	var east2: Building = _wall(bot.cell + Vector2i(2, 0))
	await physics_frame
	check(bot.links == 2 | 128 and _pic(bot) == "wall_e_built.png" and _extras(bot) == [["wall_diag_half_nw_built", true]],
			"the bottom end with a straight run east: its E picture and the NW half behind it (%d %s %s)" % [bot.links, _pic(bot), str(_extras(bot))])
	# a straight run north from the top end too (a T of a straight and a diagonal)
	_wall(top.cell + Vector2i(0, -1))
	_wall(top.cell + Vector2i(0, -2))
	await physics_frame
	check(top.links == 1 | 32 and _pic(top) == "wall_n_built.png" and _extras(top) == [["wall_diag_half_se_built", false]],
			"the top end with a straight run north: its N picture and the SE half in front (%d %s %s)" % [top.links, _pic(top), str(_extras(top))])
	# pictures (before the tests below leave ruins about)
	if shots:
		await _shoot("diagonal.png", g.cell_center(a + Vector2i(8, 6)), 2.0)
		await _shoot("diagonal_close.png", g.cell_center(line[3].cell), 4.0)
		await _shoot("mixed_bottom.png", g.cell_center(bot.cell + Vector2i(0, -1)), 4.0)
		await _shoot("mixed_top.png", g.cell_center(top.cell + Vector2i(0, 0)), 4.0)
		var dmg := line[2] as Building
		dmg.hp = dmg.max_hp * 0.3
		dmg._update_sprite()
		var site: Building = _wall(a + Vector2i(14 - 3, 4))
		site.built = false
		site.progress = 0.4
		site._update_sprite()
		await _shoot("states.png", g.cell_center(a + Vector2i(9, 4)), 3.0)
		dmg.hp = dmg.max_hp
		dmg._update_sprite()
	# a piece filling one of the two cells between diagonal pieces turns them into a corner
	var fill: Building = _wall(line[1].cell + Vector2i(1, 0))
	await physics_frame
	check(line[1].links & 0xF0 == 128 and line[1].links & 2, "a filled corner: the orthogonal link wins (links %d)" % line[1].links)
	check(line[2].links & 128 == 0 and line[2].links & 1, "  and its other piece joins it north (links %d)" % line[2].links)
	fill.die()
	await physics_frame
	await physics_frame
	check(line[1].links == 32 | 128, "the filler gone: diagonal again (links %d)" % line[1].links)
	# damaged / construction: the diagonal's own pictures
	mid.hp = mid.max_hp * 0.3
	mid._update_sprite()
	check(_pic(mid) == "wall_diag_se_damaged.png", "damaged: %s" % _pic(mid))
	mid.hp = mid.max_hp
	mid._update_sprite()
	# 4. the line tool: a 45-degree drag lays a staircase (no corner-only joins), as before
	var drag: Array = g.line_cells(a + Vector2i(0, 0), a + Vector2i(3, 3))
	var corner_only := false
	for i in range(1, drag.size()):
		var d: Vector2i = drag[i] - drag[i - 1]
		if d.x != 0 and d.y != 0:
			corner_only = true
	check(not corner_only, "the line tool's 45-degree line steps orthogonally (%d cells)" % drag.size())
	# 5. blocking: the pathfinder, smoothing and the push
	var p1: Vector2 = Vector2(line[0].cell) * T
	var p2: Vector2 = Vector2(line[6].cell + Vector2i.ONE) * T
	var below: Vector2 = g.cell_center(line[3].cell + Vector2i(-2, 2))
	var above: Vector2 = g.cell_center(line[3].cell + Vector2i(2, -2))
	for k in ["labourer", "musketeer", "cuirassier"]:
		var r: Dictionary = await _walk(k, 0, below, above, p1, p2)
		check(r["through"] == 0 and r["walked"] > 300.0,
				"%s ordered across walks round the wall (through %d, walked %d px, arrived %s)" % [k, r["through"], int(r["walked"]), str(r["arrived"])])
	var corner: Vector2 = Vector2(line[3].cell + Vector2i.ONE) * T     # between pieces 3 and 4
	var dir := Vector2(1, -1).normalized()                             # from below-left to above-right
	var squeezed := 0
	for k in ["labourer", "musketeer", "cuirassier"]:
		for step in [1.0, 2.0, 4.0, 7.0, 12.0]:
			if await _squeeze(k, 0, corner, dir, step):
				squeezed += 1
				print("  squeezed: %s step %s" % [k, step])
	check(squeezed == 0, "nobody squeezes through the corner, pushed straight at it (%d did)" % squeezed)
	check(g._wall_corner(corner + Vector2(-3, 3), corner + Vector2(3, -3)), "Game._wall_corner sees the corner")
	check(not g._wall_corner(g.cell_center(lone.cell + Vector2i(0, -1)), g.cell_center(lone.cell + Vector2i(1, -2))),
			"  and not an open diagonal")
	# 6. a gate in a diagonal line: its own side walks through it, the other side doesn't
	var gc: Vector2i = line[3].cell
	line[3].die()
	await physics_frame
	await physics_frame
	var gate: Building = _wall(gc, "gate")
	await physics_frame
	await physics_frame
	check(line[2].links & 32 != 0 and line[4].links & 128 != 0, "the pieces beside the gate join it diagonally (%d, %d)" % [line[2].links, line[4].links])
	var ga: Vector2 = g.cell_center(gc + Vector2i(0, 2))
	var gb: Vector2 = g.cell_center(gc + Vector2i(0, -2))
	var own: Dictionary = await _walk("musketeer", 0, ga, gb, p1, p2)
	check(own["arrived"] and own["walked"] < 200.0, "its own side walks through the gate (walked %d px)" % int(own["walked"]))
	var foe: Dictionary = await _walk("musketeer", 1, ga, gb, p1, p2, 20.0)
	check(foe["through"] == 0, "the other side doesn't (through %d, walked %d px)" % [foe["through"], int(foe["walked"])])
	gate.die()
	await physics_frame
	line[3] = _wall(gc)
	await physics_frame
	print("wall diag: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
