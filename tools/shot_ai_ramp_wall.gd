extends SceneTree
## The Crown computers' ramp walls (Cottage + Gate + only the palisade that closes a gap), filmed at the top of each
## main's ramp once they stand (owner's playtest 2026-11-01: a useless palisade beside the Cottage on Ashfall):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_ai_ramp_wall.gd -- \
##       [map:ashfall] [seed:1864215939] [at:55] [tag:after] [out:res://docs/shots/ai_ramp_wall]
## Writes <out>/<map>_<tag>_team<N>.png.
var main: Node
var g: Game
var map := "ashfall"
var seed_ := 1864215939
var at := 55.0
var tag := "after"
var out := "res://docs/shots/ai_ramp_wall"
var t := 0.0
var mids: Array = []
var done := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"at": at = float(kv[1])
			"tag": tag = kv[1]
			"out": out = kv[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "timing"},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "economy"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.visible = false
	if g.spectator:
		g.spectator.process_mode = Node.PROCESS_MODE_DISABLED
	if g.controls:
		g.controls.process_mode = Node.PROCESS_MODE_DISABLED
	if mids.is_empty() and g.ais.size() >= 2:
		for a in g.ais:
			var bands: Array = a._ramp_bands()
			mids.append((bands[0]["mid"] as Vector2) * Defs.TILE + Vector2(Defs.TILE, Defs.TILE) * 0.5 if not bands.is_empty() else Vector2.ZERO)
	if g.clock >= at and not done:
		done = true
		_shoot()
	return false


func _shoot() -> void:
	var cam: Camera2D = g.camera
	for i in mids.size():
		cam.position = mids[i] + Vector2(0, -24)
		cam.zoom = Vector2(2.0, 2.0)
		cam.reset_smoothing()
		for f in 20:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		var p := ProjectSettings.globalize_path(out).path_join("%s_%s_team%d.png" % [map, tag, i])
		img.save_png(p)
		print("SHOT ", p)
	quit(0)
