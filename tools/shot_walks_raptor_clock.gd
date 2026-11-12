extends SceneTree
## Films the Clock Soldier's and the Raptor's new walks (the owner's ChatGPT sheets, job walks-raptor-clock): eight of
## the unit on open ground, each walking out from the middle in one of the eight directions, the camera still at zoom 3,
## 14 shots 1/15 s apart into docs/shots/walks_raptor_clock/<unit>_NN.png (tools/shot_walks_raptor_clock.py makes the GIFs).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1000x1000 --fixed-fps 30 --script res://tools/shot_walks_raptor_clock.gd -- unit=clock_soldier
const U := preload("res://tools/gear_test_util.gd")
const OUT := "res://docs/shots/walks_raptor_clock/"


func _initialize() -> void:
	_run.call_deferred()


func _open(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	return g.cell_center(c) if g.is_free(c) else g.cell_center(g.nearest_free(c, 6))


## The middle of an open disc of ground (radius px), away from both halls.
func _spot(g: Game, rad: float) -> Vector2:
	var sz := Vector2(g.W * Defs.TILE, g.H * Defs.TILE)
	var halls := []
	for t in 2:
		var h = U.hall(g, t)
		if h != null:
			halls.append(h.center())                # (the Brood has no hall: its Queen is a unit)
	for yi in range(3, 20):
		for xi in range(3, 20):
			var a := Vector2(sz.x * xi / 22.0, sz.y * yi / 22.0)
			if a.x < rad + 64 or a.y < rad + 64 or a.x + rad > sz.x - 64 or a.y + rad > sz.y - 64:
				continue
			var ok := halls.all(func(h: Vector2) -> bool: return a.distance_to(h) > 800.0)
			for k in 16:
				var p := a + Vector2.RIGHT.rotated(TAU * k / 16.0) * rad
				if not g.is_free(g.cell_of(p)) or not g.line_clear(a, p, 14.0):
					ok = false
			if ok:
				return a
	return Vector2(-1, -1)


func _run() -> void:
	var kind := "clock_soldier"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("unit="):
			kind = a.substr(5)
	var fac := "clockwork" if kind == "clock_soldier" else "brood"
	var g := U.make(root, [fac, "crown"])
	await process_frame
	await process_frame
	g.human = 0
	for u in g.units.duplicate():
		u.position += Vector2(-99999, -99999)          # (everyone else out of the picture)
	var a := _spot(g, 240.0)
	if a.x < 0:
		print("no open ground found")
		quit(1)
		return
	var men := []
	for k in 8:
		var dir := Vector2.RIGHT.rotated(TAU * k / 8.0)
		var u: Unit = g._add_unit(kind, 0, _open(g, a + dir * 16.0))
		men.append([u, dir])
	g.camera.position = a
	g.camera.zoom = Vector2(3.0, 3.0)
	U.step(g, 0.3)
	for m in men:
		m[0].cmd_move(a + m[1] * 400.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	U.step(g, 0.05)
	for i in 4:
		g.camera.position = a
		await process_frame                      # (the camera settles on the spot first)
	for k in 14:
		g.camera.position = a
		g.camera.zoom = Vector2(3.0, 3.0)
		await process_frame
		await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(
				ProjectSettings.globalize_path(OUT + "%s_%02d.png" % [kind, k]))
		var line := "shot %d:" % k
		for m in men:
			line += " %s" % m[0]._anim_name()
		print(line)
		U.step(g, 1.0 / 15.0)
	quit(0)
