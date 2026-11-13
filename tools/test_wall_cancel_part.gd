extends SceneTree
## Cancel PART of a planned wall (owner 2026-11-13, Frostfang: "I placed a 3-way section to form a wall, I wanted to cancel
## the ghost of 1 of the 3 ways; when I cancelled 1 section it cancelled all 3"): lay a wall of three stretches (two bends)
## with two Labourers, ABANDON the ghosts of the last stretch, and the other two stretches must stay planned and get built.
##   godot --headless --fixed-fps 30 --script res://tools/test_wall_cancel_part.gd
var main
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_go.call_deferred()


func _walls(g) -> Array:
	return g.buildings.filter(func(b): return b.kind == "wall" and not b.dead and b.team == 0)


func _go() -> void:
	await process_frame
	for mode in ["one piece", "a stretch"]:
		main.start({"seed": 5, "map": "greenhold", "sandbox": true, "slots": [{"who": "you", "faction": "crown", "colour": 0, "side": 0}, {"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
		var g = main.game
		await create_timer(0.3).timeout
		g.hud.countdown = 0.0
		paused = false
		for a in g.ais:
			a.set_process(false)
			a.set_physics_process(false)
		g.players[0]["gold"] = 5000
		var hall = null
		for b in g.buildings:
			if b.team == 0 and b.kind == "town_hall":
				hall = b
		g._add_building("cottage", 0, g.nearest_free(hall.cell + Vector2i(0, -6), 12), true)       # (walls need a Cottage)
		var c0 := Vector2i(-1, -1)
		var best := INF
		for y in range(hall.cell.y - 25, hall.cell.y + 25):
			for x in range(hall.cell.x - 25, hall.cell.x + 25):
				var okr := true
				for yy in range(y - 1, y + 7):
					for xx in range(x - 1, x + 14):
						if not g.in_map(Vector2i(xx, yy)) or not g.is_free(Vector2i(xx, yy)) or g.placement_problem(0, "wall", Vector2i(xx, yy)) != "":
							okr = false
							break
					if not okr:
						break
				var d := Vector2(x, y).distance_to(Vector2(hall.cell))
				if okr and d < best:
					best = d
					c0 = Vector2i(x, y)
		var labs: Array = g.units.filter(func(u): return u.team == 0 and u.kind == "labourer").slice(0, 2)
		var a := c0
		var m1 := c0 + Vector2i(6, 0)
		var m2 := c0 + Vector2i(6, 5)
		var b := c0 + Vector2i(12, 5)
		print("  c0 %s, problem at c0: '%s', walls requirement: '%s', gold %d" % [str(c0), g.placement_problem(0, "wall", c0), g.requirement_text(0, "wall"), int(g.players[0]["gold"])])
		var n: int = g.place_line(0, "wall", a, b, labs, false, [m1, m2])
		await create_timer(0.5).timeout
		var all := _walls(g)
		var third: Array = all.filter(func(w): return w.cell.y == m2.y and w.cell.x > m2.x)
		var keep: Array = all.filter(func(w): return not third.has(w))
		print("%s: laid %d pieces, cancelling %d of the last stretch" % [mode, n, 1 if mode == "one piece" else third.size()])
		var gone: Array = third.slice(0, 1) if mode == "one piece" else third
		g.set_selection(gone)
		for w in gone:
			g.abandon(w)
		await create_timer(12.0).timeout
		var left := keep.filter(func(w): return is_instance_valid(w) and not w.dead)
		check(left.size() == keep.size(), "%s cancelled: the other %d pieces stay planned or built (%d left)" % [mode, keep.size(), left.size()])
		var busy: Array = labs.filter(func(u): return u.order == "build")
		check(not busy.is_empty(), "%s cancelled: the Labourers keep building the rest (%s)" % [mode, str(labs.map(func(u): return u.order))])
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
