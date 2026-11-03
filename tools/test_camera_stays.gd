extends SceneTree
## THE VIEW STAYS WHERE IT IS PUT (0.27.1, the owner's bug on 0.27.0: "the screen gets locked to the top left of the
## map: I try to move the screen and it keeps going back there"). For each case the view is moved to the middle of the
## map and must stay there (not snap to a corner) over a few seconds of the match:
##  - playing, computer and phone settings;
##  - watching computers: VIEW all, free, following a computer (the follow camera moves, but never to the corner),
##    with the spectator panels open;
##  - a replay: free, and following the recorded camera;
##  - THE CAUSE: on computer controls, edge panning followed Godot's mouse even when no mouse had moved (a touch
##    screen: the mouse sits at (0, 0), the top-left edge), so the view slid to the top-left corner every frame. Now only
##    a real mouse that has moved over the window edge-pans; a finger turns it off; a real mouse at the edge still pans.
##  - the guards: a jump to INF/NaN is ignored, a NaN view or zoom never snaps the view to the corner.
##   godot --headless --fixed-fps 30 --script res://tools/test_camera_stays.gd
var main: Node
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-66s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _corner(g: Game) -> Vector2:
	var cam := g.camera
	var half := g.get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	return Vector2(cam.limit_left, cam.limit_top) + half


## Put the view in the middle and watch it for `n` frames: the worst distance from where it was put, and whether it
## ever came near the top-left corner.
func _watch(g: Game, n: int) -> Array:
	var mid := Vector2(g.W, g.H) * Game.T * 0.5
	g.camera.position = mid
	var worst := 0.0
	var corner := false
	var bad := false
	for i in n:
		await process_frame
		var p: Vector2 = g.camera.position
		if not p.is_finite():
			bad = true
			continue
		worst = maxf(worst, p.distance_to(mid))
		if p.distance_to(_corner(g)) < 60.0:
			corner = true
	return [worst, corner, bad]


func _start(slots: Array) -> Game:
	main.start({"map": "twin_crowns", "seed": 3, "slots": slots})
	await process_frame
	await process_frame
	paused = false
	return main.game


func _quit_match() -> void:
	main._to_menu()
	await _frames(3)


func _run() -> void:
	await process_frame
	var keep_dev := Settings.device
	var keep_narr := Settings.narrator
	Settings.narrator = false
	# ---- playing, computer and phone
	for dev in ["pc", "phone"]:
		Settings.device = dev
		var g: Game = await _start([
			{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "normal", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"}])
		await _frames(30)
		var r: Array = await _watch(g, 150)
		check("playing (%s): the view stays where it is put" % dev, float(r[0]) < 2.0 and not r[1] and not r[2], str(r))
		# panned by the keyboard/drag path: the clamp keeps it
		g.camera.position += Vector2(300, 200)
		var want: Vector2 = g.camera.position
		await _frames(30)
		check("playing (%s): moved again, it stays" % dev, g.camera.position.distance_to(want) < 2.0, str(g.camera.position, want))
		# guards
		g.hud._jump(Vector2.INF)
		await _frames(2)
		check("guard (%s): a jump to INF is ignored" % dev, g.camera.position.distance_to(want) < 2.0, str(g.camera.position))
		g.hud._jump(Vector2(NAN, NAN))
		await _frames(2)
		check("guard (%s): a jump to NaN is ignored" % dev, g.camera.position.distance_to(want) < 2.0, str(g.camera.position))
		g.camera.position = Vector2(NAN, 5)
		await _frames(2)
		check("guard (%s): a NaN view is put back, not to the corner" % dev, g.camera.position.is_finite() and g.camera.position.distance_to(_corner(g)) > 60.0, str(g.camera.position))
		g.camera.zoom = Vector2(NAN, NAN)
		await _frames(2)
		check("guard (%s): a NaN zoom is put back" % dev, g.camera.zoom.is_finite() and g.camera.position.is_finite() and g.camera.position.distance_to(_corner(g)) > 60.0, str(g.camera.zoom, g.camera.position))
		g.camera.zoom = Vector2(1.5, 1.5)
		if dev == "pc":
			# the cause: a real mouse resting at the top-left edge (headless: Godot's mouse is at (0, 0)) still edge-pans...
			var mm := InputEventMouseMotion.new()
			mm.position = Vector2.ZERO
			Input.parse_input_event(mm)
			Input.flush_buffered_events()
			check("edge pan: a mouse that moved counts as real", g.controls._mouse_real)
			var r2: Array = await _watch(g, 30)
			check("edge pan: a real mouse at the top-left edge still pans the view", float(r2[0]) > 50.0, str(r2))
			# the mouse went out by the top-left and the browser never said it came back: moving inside ends the scroll
			g.controls._mouse_inside = false
			g.controls._exit_dir = Vector2(-1, -1)
			var m3 := InputEventMouseMotion.new()
			m3.position = g.get_viewport().get_final_transform() * Vector2(640, 640)      # (window pixels: the event is scaled into the view)
			Input.parse_input_event(m3)
			Input.flush_buffered_events()
			await _frames(2)
			check("edge pan: a lost 'mouse entered' no longer scrolls for good", g.controls._mouse_inside and g.controls._exit_dir == Vector2.ZERO, str(g.controls._mouse_inside, g.controls._exit_dir, g.get_viewport().get_visible_rect()))
			# ...but a finger on the screen (a touch screen on computer controls) is no mouse at an edge
			var tt := InputEventScreenTouch.new()
			tt.index = 0
			tt.position = Vector2(400, 300)
			tt.pressed = true
			Input.parse_input_event(tt)
			tt = tt.duplicate()
			tt.pressed = false
			Input.parse_input_event(tt)
			Input.flush_buffered_events()
			check("edge pan: a finger turns it off", not g.controls._mouse_real)
			r2 = await _watch(g, 150)
			check("edge pan: after a touch the view stays (no slide to the corner)", float(r2[0]) < 2.0 and not r2[1], str(r2))
		await _quit_match()
	Settings.device = keep_dev
	# ---- watching computers
	for dev in ["pc", "phone"]:
		Settings.device = dev
		var g: Game = await _start([
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"}])
		check("watching (%s): spectating" % dev, g.spectating())
		await _frames(30)
		g.spectator.set_mode("all", 0)
		var r: Array = await _watch(g, 150)
		check("watching (%s) VIEW all: the view stays" % dev, float(r[0]) < 2.0 and not r[1] and not r[2], str(r))
		g.spectator.set_mode("free", 0)
		r = await _watch(g, 150)
		check("watching (%s) VIEW free: the view stays" % dev, float(r[0]) < 2.0 and not r[1] and not r[2], str(r))
		var sp: SpecPanels = g.hud.spec_panels()
		for k in SpecPanels.open.keys():
			SpecPanels.open[k] = true
		r = await _watch(g, 150)
		check("watching (%s) panels open: the view stays" % dev, float(r[0]) < 2.0 and not r[1] and not r[2], str(r))
		for k in SpecPanels.open.keys():
			SpecPanels.open[k] = false
		g.spectator.set_mode("follow", 0)
		r = await _watch(g, 300)
		check("watching (%s) following P1: never to the corner" % dev, not r[1] and not r[2], str(r))
		# the user pans while following: it lets go and stays
		g.controls._user_cam()
		r = await _watch(g, 150)
		check("watching (%s) panned off the follow: the view stays" % dev, float(r[0]) < 2.0 and not r[1] and not r[2], str(r, " ", g.spectator.mode))
		if dev == "phone" and g.rec != null:
			# ---- a replay of it
			var path: String = g.rec.finish(-1)
			main._to_menu()
			await _frames(3)
			main.start_replay(path)
			await _frames(5)
			g = main.game
			paused = false
			check("replay: the viewer is open", g != null and g.replay != null)
			g.replay.follow_camera(-1)
			g.replay.set_playing(true)
			r = await _watch(g, 150)
			check("replay free camera: the view stays", float(r[0]) < 2.0 and not r[1] and not r[2], str(r))
			var ct: Array = g.replay.cam_teams()
			if not ct.is_empty():
				g.replay.follow_camera(int(ct[0]))
				r = await _watch(g, 150)
				check("replay following a recorded camera: never NaN", not r[2], str(r))
			g.spectator.set_mode("all", 0, true)
			main._to_menu()
			await _frames(3)
			continue
		await _quit_match()
	Settings.device = keep_dev
	Settings.narrator = keep_narr
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
