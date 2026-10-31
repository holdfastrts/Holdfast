extends SceneTree
## The player's palisade drag (docs/wall_drag.md): a drag (or two clicks) snaps to the nearest of 8 ways; an exact
## diagonal is one piece per diagonal cell (no staircase); Shift-clicks make corners of a path laid when Shift is let
## go (or on a plain click); a phone's taps snap the same way; the command travels online with its corners.
##   godot --headless --fixed-fps 30 --script res://tools/test_wall_drag.gd
## With pictures (docs/shots/wall_drag/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 \
##       --script res://tools/test_wall_drag.gd -- shots
var main: Node
var t := 0.0
var g
var c                      # Controls
var started := false
var fails := 0
var shots := false
var price := 0
const OUT := "res://docs/shots/wall_drag"


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
			var cc := Vector2i(x, y)
			var d := Vector2(cc).distance_to(Vector2(hall.cell))
			if d < 12.0 or d > bd:
				continue
			var h0: int = g.height[g.idx(cc)]
			var ok := true
			for yy in h:
				for xx in w:
					var q := cc + Vector2i(xx, yy)
					if g.solid[g.idx(q)] != 0 or g.ramp[g.idx(q)] != 0 or g.height[g.idx(q)] != h0:
						ok = false
						break
				if not ok:
					break
			if ok:
				best = cc
				bd = d
	return best


## The screen point over a cell's centre.
func _scr(cell: Vector2i) -> Vector2:
	return g.get_viewport().get_canvas_transform() * g.cell_center(cell)


func _btn(cell: Vector2i, pressed: bool, shift := false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.shift_pressed = shift
	e.position = _scr(cell)
	c._on_input(e)


func _hover(cell: Vector2i) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _scr(cell)
	c._on_input(e)


func _shift_up() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_SHIFT
	e.pressed = false
	c._on_input(e)


func _walls_at(cells: Array) -> int:
	var n := 0
	for cc in cells:
		if g._own_wall_at(0, cc) != null:
			n += 1
	return n


func _all_walls() -> Dictionary:
	var out := {}
	for b in g.buildings:
		if b.kind == "wall" and b.team == 0 and not b.dead:
			out[b.cell] = b
	return out


## The pieces laid since `before`.
func _new_walls(before: Dictionary) -> Array:
	var out: Array = []
	for cc in _all_walls():
		if not before.has(cc):
			out.append(cc)
	return out


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
	c = g.controls
	g.explored.fill(1)
	if "reveal" in g:
		g.reveal = true
	var dev_was: String = Settings.device
	Settings.device = "pc"
	price = int(Defs.BUILDINGS["wall"]["cost"])
	g.players[0]["gold"] = 20000
	var a := _open_area(20, 20)
	check(a.x >= 0, "an open 20x20 field")
	if a.x < 0:
		quit(1)
		return
	g._add_building("cottage", 0, a + Vector2i(17, 17), true)      # (the palisade needs a Cottage)
	# labourers selected: the sites have builders coming (a site nobody comes to is dropped)
	var labs: Array = g.units.filter(func(u) -> bool: return u.team == 0 and u.kind == "labourer")
	g.set_selection(labs)
	# the camera on the field (the clicks are screen points)
	g.camera.position = g.cell_center(a + Vector2i(10, 10))
	g.camera.zoom = Vector2(1.5, 1.5)
	g.camera.reset_smoothing()
	for i in 3:
		await process_frame
	# 0. the snap
	check(Game.snap_wall_end(Vector2i(0, 0), Vector2i(5, 1)) == Vector2i(5, 0), "snap: (5,1) -> east (5,0)")
	check(Game.snap_wall_end(Vector2i(0, 0), Vector2i(1, -6)) == Vector2i(0, -6), "snap: (1,-6) -> north (0,-6)")
	check(Game.snap_wall_end(Vector2i(0, 0), Vector2i(4, 3)) == Vector2i(4, 4), "snap: (4,3) -> the SE diagonal (4,4)")
	check(Game.snap_wall_end(Vector2i(0, 0), Vector2i(-3, 4)) == Vector2i(-4, 4), "snap: (-3,4) -> the SW diagonal (-4,4)")
	check(Game.snap_wall_end(Vector2i(2, 2), Vector2i(2, 2)) == Vector2i(2, 2), "snap: the same cell stays (a single piece)")
	# 1. straight: press, drag, let go
	var before := _all_walls()
	var gold0: int = g.players[0]["gold"]
	var s1 := a + Vector2i(1, 1)
	c.begin_place("wall")
	_hover(s1)
	_btn(s1, true)
	check(c.line_from == s1, "the press marks the start")
	_hover(s1 + Vector2i(5, 1))
	_btn(s1 + Vector2i(5, 1), false)
	var got := _new_walls(before)
	check(got.size() == 6 and _walls_at(range(6).map(func(i): return s1 + Vector2i(i, 0))) == 6,
			"a drag a little off the row lays a straight run of 6 (%d)" % got.size())
	check(gold0 - int(g.players[0]["gold"]) == 6 * price, "it costs 6 pieces (%d)" % (gold0 - int(g.players[0]["gold"])))
	check(c.mode == "", "and the placing ends")
	# 2. two clicks (the old way), north-south
	before = _all_walls()
	var s2 := a + Vector2i(1, 4)
	c.begin_place("wall")
	_hover(s2)
	_btn(s2, true)
	_btn(s2, false)
	check(c.mode == "place" and c.line_from == s2, "a click on the start: still placing")
	_hover(s2 + Vector2i(0, 4))
	_btn(s2 + Vector2i(0, 4), true)
	_btn(s2 + Vector2i(0, 4), false)
	got = _new_walls(before)
	check(got.size() == 5, "a second click lays a column of 5 (%d)" % got.size())
	# 3. diagonal: no staircase
	before = _all_walls()
	gold0 = g.players[0]["gold"]
	var s3 := a + Vector2i(4, 4)
	c.begin_place("wall")
	_hover(s3)
	_btn(s3, true)
	_hover(s3 + Vector2i(4, 3))
	check(c.wall_end() == s3 + Vector2i(4, 4), "the ghost's end snaps to the diagonal")
	var pv: Array = g.wall_path_cells(c.wall_path())
	check(pv.size() == 5, "the ghost shows 5 pieces (%d)" % pv.size())
	if shots:
		await _shoot("ghost_diagonal.png", g.cell_center(s3 + Vector2i(3, 4)), 2.5)
	_btn(s3 + Vector2i(4, 3), false)
	got = _new_walls(before)
	var diag_ok := got.size() == 5
	for i in 5:
		diag_ok = diag_ok and got.has(s3 + Vector2i(i, i))
	check(diag_ok, "a diagonal drag lays 5 pieces corner to corner (%s)" % str(got))
	check(_walls_at([s3 + Vector2i(1, 0), s3 + Vector2i(0, 1), s3 + Vector2i(2, 1), s3 + Vector2i(1, 2)]) == 0, "no staircase cells")
	check(gold0 - int(g.players[0]["gold"]) == 5 * price, "it costs 5 pieces (%d)" % (gold0 - int(g.players[0]["gold"])))
	var mid: Building = g._own_wall_at(0, s3 + Vector2i(2, 2))
	check(mid != null and mid.links == 32 | 128, "the middle piece joins NW and SE (links %d)" % (mid.links if mid else -1))
	# 4. Shift: a straight stretch, then a diagonal, laid when Shift is let go
	before = _all_walls()
	gold0 = g.players[0]["gold"]
	var s4 := a + Vector2i(1, 11)
	c.begin_place("wall")
	_hover(s4)
	_btn(s4, true, true)
	_btn(s4, false, true)
	_hover(s4 + Vector2i(4, 0))
	_btn(s4 + Vector2i(4, 0), true, true)
	_btn(s4 + Vector2i(4, 0), false, true)
	check(c.line_via == [s4 + Vector2i(4, 0)] and _new_walls(before).is_empty(), "Shift-click: a corner, nothing laid yet")
	_hover(s4 + Vector2i(8, 3))
	pv = g.wall_path_cells(c.wall_path())
	check(pv.size() == 9, "the ghost shows the whole path: 5 straight + 4 diagonal (%d)" % pv.size())
	if shots:
		await _shoot("ghost_path.png", g.cell_center(s4 + Vector2i(5, 4)), 2.0)
	_btn(s4 + Vector2i(8, 3), true, true)
	_btn(s4 + Vector2i(8, 3), false, true)
	check(c.line_via.size() == 2, "a second corner")
	_hover(s4 + Vector2i(12, 3))       # (the stretch after the last corner is not laid)
	_shift_up()
	got = _new_walls(before)
	var want: Array = []
	for i in 5:
		want.append(s4 + Vector2i(i, 0))
	for i in range(1, 5):
		want.append(s4 + Vector2i(4 + i, i))
	var path_ok := got.size() == want.size()
	for w in want:
		path_ok = path_ok and got.has(w)
	check(path_ok, "letting go of Shift lays the path to the last corner: %d pieces (%s)" % [got.size(), str(got)])
	check(gold0 - int(g.players[0]["gold"]) == 9 * price, "it costs 9 pieces (%d)" % (gold0 - int(g.players[0]["gold"])))
	check(_walls_at([s4 + Vector2i(5, 0), s4 + Vector2i(4, 1)]) == 0, "no staircase cell at the bend")
	check(c.mode == "", "and the placing ends")
	var bend: Building = g._own_wall_at(0, s4 + Vector2i(4, 0))
	check(bend != null and bend.links == 8 | 32, "the bend joins W and SE (links %d)" % (bend.links if bend else -1))
	# 5. Shift corners, ended by a plain click (the last stretch too)
	before = _all_walls()
	var s5 := a + Vector2i(1, 19)
	c.begin_place("wall")
	_hover(s5)
	_btn(s5, true)
	_btn(s5, false)
	_hover(s5 + Vector2i(3, 0))
	_btn(s5 + Vector2i(3, 0), true, true)
	_btn(s5 + Vector2i(3, 0), false, true)
	_hover(s5 + Vector2i(6, -3))
	_btn(s5 + Vector2i(6, -3), true, false)
	_btn(s5 + Vector2i(6, -3), false, false)
	got = _new_walls(before)
	check(got.size() == 7 and got.has(s5 + Vector2i(6, -3)) and got.has(s5 + Vector2i(5, -2)), "a plain click ends the path: 4 + 3 pieces (%d)" % got.size())
	# 6. gates in a diagonal run: a gate laid on a planned piece still swaps in; a wall dragged past a gate keeps it
	var gc := s3 + Vector2i(2, 2)
	c.begin_place("gate")
	_hover(gc)
	_btn(gc, true)
	_btn(gc, false)
	_btn(gc, true)
	_btn(gc, false)
	check(g._own_gate_at(0, gc) != null, "a gate on a piece of the diagonal swaps in")
	before = _all_walls()
	c.begin_place("wall")
	_hover(s3)
	_btn(s3, true)
	_hover(s3 + Vector2i(4, 4))
	_btn(s3 + Vector2i(4, 4), false)
	check(g._own_gate_at(0, gc) != null, "a wall dragged over the diagonal again keeps the gate")
	# 7. a phone: taps (move the ghost, tap again), the end snaps too
	Settings.device = "phone"
	before = _all_walls()
	var s7 := a + Vector2i(12, 1)
	c.begin_place("wall")
	c._tap(_scr(s7), false)
	c._tap(_scr(s7), false)
	check(c.line_from == s7, "phone: a second tap on the spot marks the start")
	c._tap(_scr(s7 + Vector2i(3, 4)), false)
	c._tap(_scr(s7 + Vector2i(3, 4)), false)
	got = _new_walls(before)
	check(got.size() == 5 and got.has(s7 + Vector2i(4, 4)), "phone: the end snaps to the diagonal, 5 pieces (%d)" % got.size())
	Settings.device = "pc"
	# 8. online: the command with its corners survives the wire and the host's checks
	before = _all_walls()
	var s8 := a + Vector2i(12, 8)
	var args := [0, "wall", s8, s8 + Vector2i(6, 3), [], true, [s8 + Vector2i(3, 0)]]
	var ok := [true]
	var wire: Array = []
	for x in args:
		wire.append(NetCodec.enc(x, ok))
	var msg := NetCodec.unpack(NetCodec.pack({"o": 0, "f": "place_line", "a": wire}))
	var s := NetSession.new()
	s.game = g
	var why := NetCommands._apply(s, 0, msg)
	got = _new_walls(before)
	check(ok[0] and why == "" and got.size() == 7 and got.has(s8 + Vector2i(6, 3)), "online: a guest's path (corner and diagonal) is laid by the host: %d pieces (%s)" % [got.size(), why])
	s.free()
	# bad corners (not cells) are dropped, not a crash
	var n_bad: int = g.place_line(0, "wall", s8 + Vector2i(0, 6), s8 + Vector2i(2, 6), [], false, ["x", 3, null])
	check(n_bad == 3, "nonsense corners are ignored (%d)" % n_bad)
	# pictures of the built walls
	if shots:
		for b in g.buildings:
			if b.kind in ["wall", "gate"] and b.team == 0 and not b.built:
				b.progress = 1.0
				b.built = true
				b.hp = b.max_hp
		for cc in _all_walls():
			g.relink_walls(cc)
		for b in g.buildings:
			if b.kind in ["wall", "gate"] and b.team == 0:
				b._update_sprite()
		await _shoot("built_diagonal.png", g.cell_center(s3 + Vector2i(2, 2)), 3.0)
		await _shoot("built_path.png", g.cell_center(s4 + Vector2i(4, 2)), 2.5)
		await _shoot("built_all.png", g.cell_center(a + Vector2i(9, 9)), 1.3)
	Settings.device = dev_was
	print("wall drag: %d failed" % fails)
	quit(1 if fails > 0 else 0)
