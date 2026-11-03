extends SceneTree
## Films the Crown Labourer walking SOUTH, SOUTH-EAST and EAST side by side at game size (the v4 walks, docs/art_redraw_queue.md
## item 8): three men on open ground, one move order each, 8 shots a few ticks apart into docs/shots/labourer_walk_v4/.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_labourer_walk.gd
const U := preload("res://tools/gear_test_util.gd")
const OUT := "res://docs/shots/labourer_walk_v4/"


func _initialize() -> void:
	_run.call_deferred()


func _open(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	return g.cell_center(c) if g.is_free(c) else g.cell_center(g.nearest_free(c, 6))


## An open square of ground (side px), away from both halls.
func _spot(g: Game, side: float) -> Vector2:
	var sz := Vector2(g.W * Defs.TILE, g.H * Defs.TILE)
	var halls := [U.hall(g, 0).center(), U.hall(g, 1).center()]
	for yi in range(3, 20):
		for xi in range(3, 20):
			var a := Vector2(sz.x * xi / 22.0, sz.y * yi / 22.0)
			if a.x + side > sz.x - 64 or a.y + side > sz.y - 64:
				continue
			var ok := halls.all(func(h: Vector2) -> bool: return a.distance_to(h) > 700.0)
			for dx in [0.0, side * 0.5, side]:
				for dy in [0.0, side * 0.5, side]:
					if not g.is_free(g.cell_of(a + Vector2(dx, dy))):
						ok = false
			if ok and g.line_clear(a, a + Vector2(0, side), 12.0) and g.line_clear(a, a + Vector2(side, side), 12.0) \
					and g.line_clear(a + Vector2(80, 0), a + Vector2(80 + side, 0), 12.0):
				return a
	return Vector2(-1, -1)


func _run() -> void:
	var g := U.make(root, ["crown", "crown"])
	await process_frame
	await process_frame
	g.human = 0
	for u in g.units.duplicate():
		u.position += Vector2(-99999, -99999)          # (everyone else out of the picture)
	var a := _spot(g, 260.0)
	if a.x < 0:
		print("no open ground found")
		quit(1)
		return
	var s: Unit = g._add_unit("labourer", 0, _open(g, a + Vector2(0, 0)))
	var se: Unit = g._add_unit("labourer", 0, _open(g, a + Vector2(40, 0)))
	var e: Unit = g._add_unit("labourer", 0, _open(g, a + Vector2(80, 40)))
	U.step(g, 0.3)
	s.cmd_move(a + Vector2(0, 260))
	se.cmd_move(a + Vector2(40 + 220, 220))
	e.cmd_move(a + Vector2(80 + 260, 40))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	U.step(g, 0.6)
	for k in 8:
		g.camera.position = a + Vector2(80, 70)              # (fixed: the men walk across the picture)
		g.camera.zoom = Vector2(3.0, 3.0)
		await process_frame
		await process_frame
		var img := root.get_viewport().get_texture().get_image()
		var c := Rect2i(Vector2i(240, 60), Vector2i(800, 600))
		img.get_region(c).save_png(ProjectSettings.globalize_path(OUT + "walk_%02d.png" % k))
		print("shot %d: s %s %s, se %s %s, e %s %s" % [k, s._anim_name(), s.position, se._anim_name(), se.position, e._anim_name(), e.position])
		U.step(g, 0.1)
	quit(0)
