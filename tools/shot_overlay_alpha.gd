extends SceneTree
## Pictures for OVERLAY OPACITY (docs/overlay_alpha.md): a big mixed battle (Musketeers, Horsemen, a band behind the
## line with its buff marks shown ALWAYS, veterans of every rank, hurt men, a stunned one, Raptors and Spitters against
## them), the same frame with the overlays solid (before, opacity 100%) and see-through (after, the default 60%); three
## men selected and one under the mouse (full strength). One map per run (grass, sand, snow, moss).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_overlay_alpha.gd -- <outdir> <map> <tag>
##   (a phone: --resolution 1280x592)
var main: Node
var g: Game
var out := ""
var map := "ashford_crossing"
var tag := "desktop"
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		map = a[1]
	if a.size() > 2:
		tag = a[2]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null and not started:
		main.start({"map": map, "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
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


func _snap(name: String) -> void:
	await create_timer(0.3).timeout
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _open(p: Vector2) -> Vector2:
	var c: Vector2i = g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 8))


func _man(k: String, team: int, at: Vector2, kills := 0, hurt := 1.0) -> Unit:
	var u: Unit = g._add_unit(k, team, _open(at))
	if u == null:
		return null
	u.auto_work = false
	u.hold_fire = true
	u.cmd_hold()
	u.max_hp = 9999.0
	u.hp = 9999.0 * hurt
	u.kills = kills
	return u


func _run() -> void:
	g.reveal = true
	await _frames(10)
	var zoom0: Vector2 = g.camera.zoom
	var hall: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "town_hall":
			hall = b
	for u in g.units.duplicate():
		if u.is_worker():
			u.auto_work = false
			u.cmd_stop()
			u.position = hall.center() + Vector2(-200, -60)
	var dir := (Vector2(Game.W, Game.H) * 16.0 - hall.center()).normalized()
	var mid := _open(hall.center() + dir * 430.0 + Vector2(dir.y, -dir.x) * 300.0)
	var keep_marks := Settings.band_marks
	var keep_a := Settings.overlay_alpha
	Settings.band_marks = 0          # (ALWAYS: every buffed man shows his marks)
	var hurts := [1.0, 0.85, 0.6, 0.4, 0.95, 0.2, 0.7, 1.0, 0.5, 0.3]
	var kills := [0, 16, 0, 33, 0, 55, 20, 0, 41, 0]
	var line: Array = []
	for row in 2:
		for i in 22:
			var j := i + row * 22
			line.append(_man("musketeer", 0, mid + Vector2(-260.0 + 24.0 * i, -60.0 + 26.0 * row), kills[j % 10], hurts[(j * 7) % 10]))
	for i in 6:
		_man("cuirassier", 0, mid + Vector2(-330.0 + (i % 2) * 30.0, -80.0 + 34.0 * (i / 2)), [0, 18, 35, 0, 60, 0][i], hurts[i + 2])
	var d: Unit = _man("band", 0, mid + Vector2(0, 40))
	var f: Unit = _man("band_fifer", 0, mid + Vector2(24, 40))
	var p: Unit = _man("band_piper", 0, mid + Vector2(-24, 40))
	f.position = d.position + Vector2(24, 0)
	p.position = d.position + Vector2(-24, 0)
	# the Brood across the field
	for i in 26:
		var k := "raptor" if i % 3 != 2 else "spitter"
		_man(k, 1, mid + Vector2(-260.0 + 21.0 * i, -170.0 - 26.0 * float(i % 2)), [0, 0, 22, 0, 31, 0, 0, 52][i % 8], hurts[(i * 3) % 10])
	await _frames(40)
	# one stunned man, three selected, one under the mouse
	(line[30] as Unit).stun(60.0, true)
	g.set_selection([line[8], line[9], line[10]])
	g.hover_target = line[14]
	g.camera.zoom = zoom0
	g.camera.position = mid + Vector2(-20, -50)
	for alpha in [1.0, Settings.OVERLAY_DEFAULT]:
		Settings.overlay_alpha = alpha
		await _frames(12)
		g.hover_target = line[14]
		await _snap("%s_%s_%s" % [tag, map, "before_100" if alpha == 1.0 else "after_60"])
	# a closer look at the line
	g.camera.zoom = zoom0 * 1.7
	g.camera.position = (line[10] as Unit).position + Vector2(0, -10)
	for alpha in [1.0, Settings.OVERLAY_DEFAULT]:
		Settings.overlay_alpha = alpha
		await _frames(12)
		g.hover_target = line[14]
		await _snap("%s_%s_close_%s" % [tag, map, "before_100" if alpha == 1.0 else "after_60"])
	Settings.band_marks = keep_marks
	Settings.overlay_alpha = keep_a
	print("done")
	quit()
