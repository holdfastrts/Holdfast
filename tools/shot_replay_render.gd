extends SceneTree
## Pictures of the owner's case (docs/replay_render.md): Mirewood, the Crown against a Hard Brood on RUSH, recorded,
## then the same moments in the live match and in its replay, close up on the Brood's Raptors at the Crown's base:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_replay_render.gd \
##     -- <outdir> [rec:full|light|mixed] [at:<secs>]
## Writes live_<n>.png (during the match) and replay_<n>.png (the viewer at the same clock, the camera on the same spot).
var main
var out := "/tmp/shots_replay_render"
var rec_mode := "full"
var at := 200.0
var spots: Array = []           # [clock, camera position] of each live picture


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("rec:"):
			rec_mode = a.substr(4)
		elif a.begins_with("at:"):
			at = float(a.substr(3))
		else:
			out = a
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name))
	print("wrote ", out.path_join(name))


## The Brood's warriors nearest the Crown's hall: where the rush is.
func _rush_spot(g: Game) -> Vector2:
	var hall: Vector2 = Vector2.ZERO
	for b in g.buildings:
		if b.team == 0 and b.kind == g.faction_hall(0):
			hall = b.center()
	var best := Vector2.INF
	var bd := INF
	for u in g.units:
		if is_instance_valid(u) and not u.dead and u.team == 1 and u.kind in ["raptor", "brute", "spitter", "tyrant_challenger"]:
			var dd: float = u.position.distance_to(hall)
			if dd < bd:
				bd = dd
				best = u.position
	return best


func _anims(g: Game) -> Dictionary:
	var c := {}
	for u in g.units:
		if is_instance_valid(u) and not u.dead and u.kind == "raptor" and g.view_rect.has_point(u.position):
			var k := "%s_%s%s ph=%s" % [u.anim, u.anim_dir, "F" if u.anim_flip else "", u.phase]
			c[k] = int(c.get(k, 0)) + 1
	return c


## The Brood Mother (her swamp round her).
func _mother(g: Game) -> Vector2:
	for u in g.units:
		if is_instance_valid(u) and not u.dead and u.kind == BroodNew.QUEEN:
			return u.position + Vector2(-250, 0)
	return Vector2.INF


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	seed(766992866)
	Settings.replay_rec = rec_mode
	main.start({"map": "mirewood", "seed": 766992866, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "brood", "colour": 3, "side": 1, "strategy": "rush"}]})
	await process_frame
	var g: Game = main.game
	Engine.time_scale = 6.0
	var n := 0
	while g.clock < at + 60.0 and not g.over:
		await process_frame
		if g.clock >= at + n * 15.0 and n < 4:
			var p := _rush_spot(g) if n % 2 == 0 else _mother(g)
			if p.is_finite():
				Engine.time_scale = 0.0001
				get_root().get_tree().paused = false
				g.camera.position = p
				g.camera.zoom = Vector2(2.0, 2.0)
				spots.append([g.clock, p])
				print("LIVE %.1f %s" % [g.clock, _anims(g)])
				await _shot("live_%d.png" % n)
				Engine.time_scale = 6.0
			n += 1
	Engine.time_scale = 1.0
	g.rec.finish(g.winner if g.over else -1)
	var newest: Dictionary = ReplayFile.list()[0]
	main._to_menu()
	await process_frame
	main.start_replay(String(newest["path"]))
	for i in 10:
		await process_frame
	g = main.game
	var rp = g.replay
	for i in spots.size():
		rp.seek(float(spots[i][0]) - 1.5)
		rp.set_playing(true)
		while g.clock < float(spots[i][0]):
			await process_frame
		rp.set_playing(false)
		g.camera.position = spots[i][1]
		g.camera.zoom = Vector2(2.0, 2.0)
		await _shot("replay_%d.png" % i)
		print("REPLAY %.1f %s" % [g.clock, _anims(g)])
	quit(0)
