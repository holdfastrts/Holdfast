extends SceneTree
## Screenshots of the Great Winder's SCATTER COGS (scripts/cog_scatter.gd, docs/cog_scatter.md) in the CLOCKWORK LAB: the
## card with the button and its tooltip, the windup (its key arm), the throw (the pieces in the air from its hopper), the
## littered field with enemy Musketeers walking through it slowed (the cogs round their feet) beside their twins outside,
## a close look at the litter, and the litter fading. Helpers copied from tools/shot_great_winder_sweep.gd.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_cog_scatter.gd -- <outdir>
var main: Node
var g
var out := ""
var t := 0.0
var started := false
const K := Defs.GREAT_WINDER_KIND


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start_lab()
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		_run()
	return false


func _snap(name: String) -> void:
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _cam(p: Vector2, z: float) -> void:
	g.camera.position = p
	g.camera.zoom = Vector2(z, z)
	await _frames(4)


func _ui(on: bool) -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = on


func _open(p: Vector2) -> Vector2:
	var c: Vector2i = g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 8))


func _wait(cond: Callable, secs: float) -> void:
	var t0: float = g.clock
	while not cond.call() and g.clock - t0 < secs:
		await physics_frame


func _open_ground(hall: Building) -> Vector2:
	var near_b := func(c: Vector2i) -> bool:
		for bd in g.buildings:
			if not bd.dead and Vector2(bd.cell - c).length() < 13.0:
				return true
		return false
	var best := Vector2i(-1, -1)
	var bd2 := INF
	for y in range(18, Game.H - 18, 2):
		for x in range(24, Game.W - 24, 2):
			var c := Vector2i(x, y)
			var d := Vector2(c - hall.cell).length()
			if d >= bd2 or d < 24.0 or near_b.call(c) or g.in_field(g.human, g.cell_center(c)):
				continue
			var ok := true
			for yy in range(-6, 7):
				for xx in range(-12, 13):
					var cc := c + Vector2i(xx, yy)
					if not g.in_map(cc) or not g._walkable(cc) or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != g.height[g.idx(c)] or g.solid[g.idx(cc)] != 0:
						ok = false
						break
				if not ok:
					break
			if ok:
				best = c
				bd2 = d
	return g.cell_center(best) if best.x >= 0 else hall.center() + Vector2(0, 300)


func _man(kind: String, p: Vector2, team: int) -> Unit:
	var u: Unit = g._add_unit(kind, team, _open(p))
	u.auto_work = false
	u.d = u.d.duplicate()
	u.d["damage"] = 0
	u.cmd_hold()
	return u


func _run() -> void:
	_ui(false)
	var hall: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == "clocktower":
			hall = b
	var at := _open_ground(hall)
	g.players[g.human]["gold"] = 2000
	g.reveal = true            # (the enemy walkers in view: no fog in the pictures)
	var gw: Unit = g._add_unit(K, g.human, _open(at + Vector2(-170, 40)))
	gw.auto_repair = false
	gw.auto_sweep = false
	gw.facing = Vector2(1, -0.2).normalized()
	gw.cmd_stop()
	var guard: Array = []
	for i in 3:
		var s := _man("clock_soldier", at + Vector2(-230, -40 + i * 45), g.human)
		s.wind = 1.0
		guard.append(s)
	# the enemy: a file walking through the spot, their twins walking beside it outside
	var spot := at + Vector2(60, 0)
	var inside: Array = []
	var outside: Array = []
	for i in 4:
		inside.append(_man("musketeer", spot + Vector2(140 + (i % 2) * 26, -30 + i * 20), 1))
		outside.append(_man("musketeer", spot + Vector2(140 + (i % 2) * 26, 150 + i * 20), 1))
	await _frames(20)
	# the card
	g.set_selection([gw])
	await _cam(at + Vector2(-20, 20), 1.6)
	_ui(true)
	await _frames(10)
	await _snap("0_card_scatter_cogs")
	_ui(false)
	# the throw
	g.cast_order([gw], CogScatter.SPELL, spot)
	await _wait(func() -> bool: return gw.phase == "cast", 3.0)
	await _frames(6)
	await _snap("1_windup_key_arm")
	await _wait(func() -> bool: return g.cog_layer != null and not g.cog_layer.fields.is_empty(), 3.0)
	await _frames(8)
	await _snap("2_throw_mid_air")
	await _frames(4)
	await _snap("2b_throw_coming_down")
	await _frames(30)
	await _snap("3_littered_field")
	# the enemies walk west through it (and beside it)
	for u in inside + outside:
		u.cmd_move(u.position + Vector2(-520, 0))
	await _frames(60)
	await _snap("4_littered_field_slowed_enemies")
	var d_in := 0.0
	var d_out := 0.0
	for i in 4:
		d_in += 140.0 + (i % 2) * 26 - ((inside[i] as Unit).position.x - spot.x)
		d_out += 140.0 + (i % 2) * 26 - ((outside[i] as Unit).position.x - spot.x)
	print("walked in 2 s: inside %.0f px, outside %.0f px (%.2f)" % [d_in / 4.0, d_out / 4.0, d_in / maxf(d_out, 1.0)])
	await _cam(spot + Vector2(0, 0), 3.0)
	await _frames(20)
	await _snap("5_close_litter_slowed_feet")
	await _cam(at + Vector2(-20, 20), 1.6)
	# the litter fades at the end
	await _wait(func() -> bool: return g.cog_layer.fields.is_empty() or g.clock > float(g.cog_layer.fields[0]["end"]) - 0.9, 20.0)
	await _snap("6_litter_fading")
	print("done")
	quit(0)
