extends SceneTree
## Units at a HALF-BUILT enemy palisade (docs/wall_stuck.md; the owner's playtest of 2026-11-01: five Musketeers
## stood pressed against a half-built diagonal wall "forever" though its north end was open).
## An enemy wall with built pieces, a piece going up and two pieces only planned at its far end (the way round open):
## soldiers sent past it (move, attack-move; Musketeers with shots and dry ones, Horsemen, Raptors; an enemy man
## behind the wall) get round the open end in time and never stand hacking at a piece of it; men started pressed
## against it don't freeze. A diagonal wall and a straight one. Then the same wall finished and closed to the map's
## edge... (not needed: tools/test_wall_diag.gd, test_wall_drag.gd and test_pathing.gd keep the blocking).
##   godot --headless --fixed-fps 30 --script res://tools/test_wall_stuck.gd
## With pictures (docs/shots/wall_stuck/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 \
##       --script res://tools/test_wall_stuck.gd -- shots
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var shots := false
const OUT := "res://docs/shots/wall_stuck"
const LIMIT := 40.0           # seconds to get round the wall's open end


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
			if d < 14.0 or d > bd:
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


## The enemy's half-built wall along `cells` (from its open end): the first two only planned, the third going up,
## the rest built.
func _lay(cells: Array) -> Array:
	var out: Array = []
	for i in cells.size():
		var b: Building
		if i < 2:
			b = g._add_building("wall", 1, cells[i], false, true)        # planned (a ghost: not solid)
		elif i == 2:
			b = g._add_building("wall", 1, cells[i], false)              # going up (solid, not built)
			b.progress = 0.3
		else:
			b = g._add_building("wall", 1, cells[i], true)
		out.append(b)
	return out


func _clear_wall(pieces: Array) -> void:
	for b in pieces:
		if is_instance_valid(b) and not b.dead:
			b.die()
	await physics_frame
	await physics_frame
	for b in g.buildings.duplicate():
		if b.dead and (b.kind == "wall") and b.team == 1:
			b.queue_free()
	for u in g.units.duplicate():
		if u.team != 0 or not u.is_worker():
			g.consume_unit(u)
	await physics_frame


## A squad of `n` `kind`s at `from`, sent to `to` (attack-move or move); an enemy labourer standing behind the wall
## at `prey` (or none). Returns how long the last one took to get within 60 px of `to` (INF: not all in time), how
## many ever stood hitting a wall piece, and how long the longest stand (no headway) lasted.
func _squad(kind: String, n: int, from: Vector2, to: Vector2, amove: bool, prey: Vector2, dry := false, pressed := false, wall_dir := Vector2.ZERO, film := "") -> Dictionary:
	var us: Array = []
	for i in n:
		var p := from + Vector2(float(i % 3) * 22.0 - 22.0, float(i / 3) * 22.0)
		if pressed:
			p = from + wall_dir.orthogonal() * (float(i) - float(n - 1) * 0.5) * 22.0
		var u: Unit = g._add_unit(kind, 0, p)
		if dry and u._pmax > 0.0:
			u.powder = 0.0
		us.append(u)
	var foe: Unit = null
	if prey != Vector2.INF:
		foe = g._add_unit("labourer", 1, prey)
		foe.hp = 1.0                  # (one blow: the point is getting at him, not the fight)
		foe.set_physics_process(false)     # (he stands there: he doesn't run off home, or go to mend the wall)
	await physics_frame
	if amove:
		for u in us:
			u.cmd_move(to + (u.position - from) * 0.5, true)
	else:
		g.smart_command(us, to, true)
	var hacked := {}
	var arrived := {}
	var last := {}
	var still := {}
	var worst := 0.0
	var took := INF
	var steps := int(LIMIT * 30.0)
	for s in steps:
		await physics_frame
		if film != "" and (s == 90 or s == 180):
			await _shoot("%s_%ds.png" % [film, s / 30], from.lerp(to, 0.45), 2.0)
		var all_in := true
		for u: Unit in us:
			if u.dead:
				continue
			if is_instance_valid(u.target) and u.target is Building and u.target.kind == "wall":
				hacked[u] = true
			if u.position.distance_to(to) < 60.0:
				arrived[u] = true
			if not arrived.has(u):
				all_in = false
			# no headway: under 8 px in a second, while it still has somewhere to go
			if s % 30 == 0:
				if last.has(u) and u.position.distance_to(last[u]) < 8.0 and not arrived.has(u) and not (is_instance_valid(u.target) and u.cooldown > 0.0 and not (u.target is Building)):
					still[u] = float(still.get(u, 0.0)) + 1.0
					worst = maxf(worst, still[u])
				else:
					still[u] = 0.0
				last[u] = u.position
		if all_in:
			took = float(s) / 30.0
			break
	var out := {"took": took, "hacked": hacked.size(), "worst": worst, "arrived": arrived.size(), "n": us.size(),
			"foe_dead": foe == null or foe.dead}
	if took == INF:
		for u: Unit in us:
			if not u.dead and not arrived.has(u):
				print("    left behind: %s at %s order %s target %s goal %s path %d/%d stuck %.1f" % [u.kind, str(u.position.round()), u.order,
						(u.target.kind + (" (built)" if u.target is Building and u.target.built else "")) if is_instance_valid(u.target) else "-",
						str(u.path_goal.round()), u.path_i, u.path.size(), u.stuck_t])
	if shots and took == INF:
		await _shoot("stuck_%s_%s.png" % [kind, "amove" if amove else "move"], from.lerp(to, 0.5), 2.0)
	for u in us:
		if is_instance_valid(u) and not u.dead:
			g.consume_unit(u)
	if foe and is_instance_valid(foe) and not foe.dead:
		g.consume_unit(foe)
	await physics_frame
	return out


func _cases(label: String, cells: Array, from: Vector2, to: Vector2, prey: Vector2, wall_dir: Vector2) -> void:
	var cases := [
		["musketeer", 5, true, false, false],
		["musketeer", 5, true, true, false],       # out of shots: bayonets
		["musketeer", 5, false, false, false],
		["cuirassier", 4, true, false, false],
		["musketeer", 5, true, true, true],         # started pressed against the wall
		["cuirassier", 4, true, false, true],
	]
	for cs in cases:
		var pieces := _lay(cells)
		await physics_frame
		var start: Vector2 = from
		if cs[4]:
			start = g.cell_center(cells[cells.size() - 2]) - wall_dir * 22.0
		var film := ("%s_dry_musketeers_amove" % label) if cs[0] == "musketeer" and cs[2] and cs[3] and not cs[4] else ""
		var r: Dictionary = await _squad(cs[0], cs[1], start, to, cs[2], prey, cs[3], cs[4], wall_dir, film)
		var what := "%s: %d %s%s%s%s" % [label, cs[1], "dry " if cs[3] else "", cs[0], " (attack-move)" if cs[2] else " (move)", " pressed against it" if cs[4] else ""]
		check(r["took"] < LIMIT and r["hacked"] == 0 and r["worst"] < 4.0,
				"%s get round the open end (all in: %s s, %d/%d there, %d hit the wall, longest stand %d s, the man behind it %s)" % [
				what, "never" if r["took"] == INF else str(snappedf(r["took"], 0.1)), r["arrived"], r["n"], r["hacked"], int(r["worst"]),
				"dead" if r["foe_dead"] else "alive"])
		await _clear_wall(pieces)


func _run() -> void:
	g.explored.fill(1)
	if "reveal" in g:
		g.reveal = true
	if g.hud and shots:
		g.hud.visible = false
	for u in g.units.duplicate():
		if u.team != 0 or not u.is_worker():
			g.consume_unit(u)
	var a := _open_area(22, 22)
	check(a.x >= 0, "an open 22x22 field")
	if a.x < 0:
		quit(1)
		return
	# 1. a "\" diagonal, its open end to the north-west (the playtest's wall): the men come from the south-west and
	# are sent north-east, past it
	var diag: Array = []
	for i in 9:
		diag.append(a + Vector2i(6 + i, 4 + i))
	var dfrom: Vector2 = g.cell_center(a + Vector2i(6, 15))
	var dto: Vector2 = g.cell_center(a + Vector2i(19, 5))
	var dprey: Vector2 = g.cell_center(a + Vector2i(12, 8))
	if shots:
		var pieces := _lay(diag)
		await physics_frame
		var us: Array = []
		for i in 5:
			us.append(g._add_unit("musketeer", 0, g.cell_center(diag[5]) + Vector2(-20, 14) + Vector2(i * 5 - 10, -i * 5 + 10)))
		await physics_frame
		await _shoot("half_built_diagonal.png", g.cell_center(diag[4]), 2.5)
		for u in us:
			g.consume_unit(u)
		await _clear_wall(pieces)
	await _cases("diagonal", diag, dfrom, dto, dprey, Vector2(1, -1).normalized())
	# 2. a straight north-south wall, its open end to the north: the men come from the west, sent east
	var straight: Array = []
	for i in 10:
		straight.append(a + Vector2i(11, 2 + i))
	var sfrom: Vector2 = g.cell_center(a + Vector2i(6, 10))
	var sto: Vector2 = g.cell_center(a + Vector2i(19, 10))
	var sprey: Vector2 = g.cell_center(a + Vector2i(13, 9))
	await _cases("straight", straight, sfrom, sto, sprey, Vector2(1, 0))
	# 3. the wall finished all the way and joined to a closed box: nobody walks through it (they may break it)
	var box: Array = []
	for i in 9:
		box.append(g._add_building("wall", 1, a + Vector2i(8 + i, 8), true))
		box.append(g._add_building("wall", 1, a + Vector2i(8 + i, 16), true))
	for i in 7:
		box.append(g._add_building("wall", 1, a + Vector2i(8, 9 + i), true))
		box.append(g._add_building("wall", 1, a + Vector2i(16, 9 + i), true))
	await physics_frame
	var inside: Vector2 = g.cell_center(a + Vector2i(12, 12))
	var outside: Vector2 = g.cell_center(a + Vector2i(3, 12))
	var us2: Array = []
	for i in 4:
		us2.append(g._add_unit("musketeer", 0, outside + Vector2(0, i * 20 - 30)))
	await physics_frame
	g.smart_command(us2, inside, true)
	var got_in := 0
	for s in 20 * 30:
		await physics_frame
	for u in us2:
		var c: Vector2i = g.cell_of(u.position)
		if c.x > a.x + 8 and c.x < a.x + 16 and c.y > a.y + 8 and c.y < a.y + 16:
			got_in += 1
		g.consume_unit(u)
	check(got_in == 0, "a finished, closed palisade still keeps them out (%d got in)" % got_in)
	# 4. walled out for real (the box shut, one piece of it still going up): an attack-move into it breaks a piece,
	# the one going up too (it is solid: before, nobody would hit it and they pushed at it for good)
	for b in box:
		if b.cell == a + Vector2i(8, 12):
			b.die()
	await physics_frame
	await physics_frame
	var site: Building = g._add_building("wall", 1, a + Vector2i(8, 12), false)
	site.progress = 0.5
	await physics_frame
	for k in ["cuirassier", "musketeer"]:
		var us3: Array = []
		for i in 4:
			us3.append(g._add_unit(k, 0, outside + Vector2(0, i * 20 - 30)))
		await physics_frame
		for u in us3:
			u.cmd_move(inside, true)
		var hit := 0
		var hit_site := false
		for s in 20 * 30:
			await physics_frame
			for u in us3:
				if not u.dead and is_instance_valid(u.target) and u.target is Building and u.target.kind == "wall":
					hit += 1
					if u.target == site:
						hit_site = true
		for u in us3:
			if is_instance_valid(u) and not u.dead:
				g.consume_unit(u)
		await physics_frame
		check(hit > 0, "%ss on an attack-move into a shut palisade break a piece of it (%s; the piece going up %s)" % [k, "yes" if hit > 0 else "no", "too" if hit_site else "not"])
	print("wall stuck: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
