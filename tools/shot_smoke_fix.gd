extends "res://tools/shot_powder_smoke.gd"
## Pictures and numbers for the smoke fix (docs/perf_smoke.md): the muzzle puffs' edges and fade, the town hall's
## chimney, the powder haze while the camera pans and jumps:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_smoke_fix.gd -- <outdir>
## Prints "SMOKEFIX ..." lines: effects (muzzle puffs) that vanished while still showing, the biggest alpha step of one
## in one frame, and the biggest step of a powder puff's drawn alpha in one frame (the shader's carry-on included).
## Works on the code before the fix too (it reads what each version has).

var _fx_a := {}            # Effect id -> its alpha at the last frame
var fx_pops := 0           # effects gone while their alpha was over 0.1
var fx_step := 0.0         # the biggest alpha change of an effect in one frame
var fx_seen := 0
var puff_step := 0.0       # the biggest change of a puff's drawn alpha in one frame (on screen)
var puff_pops := 0         # puffs on screen whose drawn alpha changed by over 0.08 in one frame
var _pa := PackedFloat32Array()
var _measure := false


func _initialize() -> void:
	PowderSmoke.force = PowderSmoke.THICK
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


## The alpha a puff is drawn with this frame (0: not drawn).
func _drawn(ps: PowderSmoke, j: int, vr: Rect2) -> float:
	if ps._life[j] <= 0.0 or ps._seen[j] <= 0.0:
		return 0.0
	if "_since" in ps:
		var dal: float = ps._dal[j] if "_dal" in ps else 0.0
		return clampf(ps._al[j] + dal * ps._since, 0.0, 1.0)
	return ps._al[j] if vr.has_point(ps._pos[j]) else 0.0      # (before: culled by the view, grown 230 px)


func _frame_stats() -> void:
	if g == null:
		return
	var now := {}
	for e in g.get_children():
		if e is Effect and (e as Effect).texture and (e as Effect).texture.resource_path.ends_with("smoke.png"):
			var id: int = e.get_instance_id()
			var a: float = e.modulate.a if e.visible else 0.0
			if _fx_a.has(id):
				fx_step = maxf(fx_step, absf(a - float(_fx_a[id])))
			else:
				fx_seen += 1
			now[id] = a
	for id in _fx_a:
		if not now.has(id) and float(_fx_a[id]) > 0.1:
			fx_pops += 1
	_fx_a = now
	var ps: PowderSmoke = g.powder_smoke
	if ps == null or ps.cap == 0:
		return
	if _pa.size() != ps.cap:
		_pa.resize(ps.cap)
		_pa.fill(0.0)
	var vr: Rect2 = g.view_rect.grow(110.0)
	var vsz: Vector2 = root.get_viewport().get_visible_rect().size / g.camera.zoom
	var screen := Rect2(g.camera.get_screen_center_position() - vsz * 0.5, vsz).grow(-40.0)
	for j in ps.cap:
		var a := _drawn(ps, j, vr)
		if screen.has_point(ps._pos[j]):
			var d := absf(a - _pa[j])
			puff_step = maxf(puff_step, d)
			if d > 0.08:
				puff_pops += 1
		_pa[j] = a


func _process(delta: float) -> bool:
	var r := super._process(delta)
	if _measure:
		_frame_stats()
	return r


func _burst(name: String, k: int, crop: Rect2i, scale := 2, every := 1) -> void:
	await process_frame
	await process_frame
	for i in k:
		for e in every:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image().get_region(crop)
		img.resize(crop.size.x * scale, crop.size.y * scale, Image.INTERPOLATE_NEAREST)
		img.save_png("%s/%s_%02d.png" % [out, name, i])


func _run() -> void:
	var hall: Building = null
	for b in g.buildings:
		if b.team == g.human and not b.dead and b.kind == "town_hall":
			hall = b
	_ui(false)
	var open := _open_ground(hall)
	for u in g.units.filter(func(u: Unit) -> bool: return not u.dead):
		u.position = hall.center() + Vector2(0, 60)
	# the town hall's chimney smoke, close up
	g.camera.position = hall.global_position + Vector2(0, -70)
	g.camera.zoom = Vector2(2, 2)
	for f in 45:
		await process_frame
	await _burst("chimney", 6, _mid(720, 480), 1, 9)
	var mine: Array = []
	var theirs: Array = []
	for i in 14:
		mine.append(_shooter("musketeer", 0, open + Vector2(-150 + (i % 2) * 14, -200 + i * 30), Vector2.RIGHT))
		theirs.append(_shooter("musketeer", 1, open + Vector2(150 - (i % 2) * 14, -200 + i * 30), Vector2.LEFT))
	var gun := _shooter("cannon", 0, open + Vector2(-230, 10), Vector2.RIGHT)
	g.camera.position = open
	g.camera.zoom = Vector2.ONE
	for f in 30:
		await process_frame
	_measure = true
	for u in mine + [gun]:
		u.cmd_attack(theirs[mine.find(u) % theirs.size()] if u in mine else theirs[7])
	for u in theirs:
		u.cmd_attack(mine[theirs.find(u)])
	await _film(3.0)
	# the muzzle puffs close up: 10 frames in a row (a third of a second) on the left line
	g.camera.position = open + Vector2(-120, -60)
	g.camera.zoom = Vector2(2, 2)
	await _burst("muzzle", 10, _mid(640, 400), 1)
	g.camera.position = open
	g.camera.zoom = Vector2.ONE
	await _film(9.0)
	await _snap("haze_12s", _mid(1000, 600))
	# panning across the haze, then a jump away and back (as a minimap click)
	for i in 16:
		g.camera.position = open + Vector2(-600 + i * 75, 0)
		await process_frame
	await _snap("pan_end", _mid(1000, 600))
	g.camera.position = open + Vector2(3000, 0)
	for i in 4:
		await process_frame
	g.camera.position = open
	await _burst("jump_back", 4, _mid(1000, 600), 1)
	await _film(8.0)
	await _snap("haze_24s", _mid(1000, 600))
	for u in theirs:
		_gone(u)
	for u in mine + [gun]:
		u.cmd_stop()
	await _film(12.0)
	await _snap("after_12s", _mid(1000, 600))
	print("SMOKEFIX effects %d, effects gone while showing %d, effect biggest alpha step %.3f, puff biggest drawn alpha step %.3f, puff jumps over 0.08: %d, puffs made %d" % [
		fx_seen, fx_pops, fx_step, puff_step, puff_pops, g.powder_smoke.made])
	quit(0)
