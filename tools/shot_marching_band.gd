extends SceneTree
## Screenshots of THE MARCHING BAND as individual musicians (0.37.0; scripts/marching_band.gd, docs/band_individuals.md):
## a band (Drummer, Fifer, Piper side by side, its gold ring and BAND mark, its card), lone musicians spread out (their
## own plain rings), a band soloing behind a line (the solo's markers), two lone musicians out of step (dashed rings, the
## grey marker), the buff markers on a 20-man line at normal zoom (ALWAYS, and SELECTED with a few picked).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_marching_band.gd -- <outdir>
var main: Node
var g: Game
var out := ""
var t := 0.0
var started := false


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null and not started:
		main.start({"map": "dune_sea", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "clockwork", "colour": 1, "side": 1}]})
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


func _snap(name: String, wait := 0.4) -> void:
	if wait > 0.0:
		await create_timer(wait).timeout
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


func _men(k: String, at: Vector2) -> Unit:
	var u: Unit = g._add_unit(k, 0, _open(at))
	u.cmd_hold()
	u.max_hp = 9999.0
	u.hp = 9999.0
	return u


func _clear() -> void:
	for u in g.units.duplicate():
		if u.team == 0 and not u.is_worker():
			u.queue_free()
			g.units.erase(u)
	g.set_selection([])
	await _frames(12)


func _run() -> void:
	g.reveal = true
	await _frames(10)
	var zoom0: Vector2 = g.camera.zoom
	print("normal zoom ", zoom0)
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
	var mid := _open(hall.center() + dir * 430.0 + Vector2(dir.y, -dir.x) * 380.0)
	var keep_marks := Settings.band_marks
	# ---- 1. a band: the three side by side, selected, its gold ring and BAND mark; a line in front
	var line: Array = []
	for i in 20:
		line.append(_men("musketeer", mid + Vector2(-190.0 + 20.0 * i, -70.0)))
	var d: Unit = _men("band", mid + Vector2(0, 10))
	var f: Unit = _men("band_fifer", mid + Vector2(24, 10))
	var p: Unit = _men("band_piper", mid + Vector2(-24, 10))
	f.position = d.position + Vector2(24, 0)       # (exactly beside him: the band's row)
	p.position = d.position + Vector2(-24, 0)
	await _frames(30)
	g.set_selection([d, f, p])
	g.camera.position = d.position + Vector2(0, -30)
	g.camera.zoom = Vector2(2.4, 2.4)
	await _frames(10)
	await _snap("1_band_close")
	# ---- 5. the buff markers on a 20-man line at normal zoom (ALWAYS), then SELECTED with three men picked
	Settings.band_marks = 0
	g.set_selection([])
	g.camera.zoom = zoom0
	g.camera.position = mid + Vector2(0, -40)
	await _frames(12)
	await _snap("5a_markers_line_always")
	Settings.band_marks = 1
	g.set_selection([line[9], line[10], line[11]])
	await _frames(12)
	await _snap("5b_markers_line_selected")
	g.set_selection([line[10]])
	g.camera.zoom = Vector2(2.2, 2.2)
	g.camera.position = line[10].position + Vector2(0, 30)
	await _frames(8)
	await _snap("5c_markers_close_and_card")
	# ---- 3. the band soloing (the fife: +40%, the markers bigger, shown on everyone in the ring)
	g.set_selection([])
	f.band_solo("fife")
	g.camera.zoom = zoom0 * 1.4
	g.camera.position = mid + Vector2(0, -30)
	await _frames(15)
	await _snap("3_band_fife_solo")
	await _clear()
	# ---- 2. lone musicians spread along a line: each his own plain ring, not overlapping
	var line2: Array = []
	for i in 30:
		line2.append(_men("musketeer", mid + Vector2(-450.0 + 30.0 * i, -60.0)))
	_men("band", mid + Vector2(-330, 10))
	_men("band_fifer", mid + Vector2(0, 10))
	_men("band_piper", mid + Vector2(330, 10))
	Settings.band_marks = 0
	g.camera.zoom = zoom0 * 0.8
	g.camera.position = mid
	await _frames(20)
	await _snap("2_lone_spread")
	await _clear()
	# ---- 4. out of step: a lone Fifer and a lone Piper whose rings overlap (no drummer): dashed rings, "out of step",
	# and in the overlap a soldier's pipes marker greyed and struck through
	for i in 12:
		_men("musketeer", mid + Vector2(-120.0 + 20.0 * i, -60.0))
	_men("band_fifer", mid + Vector2(-110, 10))
	_men("band_piper", mid + Vector2(110, 10))
	g.camera.zoom = zoom0 * 1.6
	g.camera.position = mid + Vector2(0, -20)
	await _frames(20)
	await _snap("4_out_of_step")
	Settings.band_marks = keep_marks
	print("done")
	quit()
