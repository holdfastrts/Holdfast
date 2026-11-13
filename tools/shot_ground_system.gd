extends SceneTree
## Pictures of THE GROUND SYSTEM (docs/ground_system.md) for docs/shots/ground_system/:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_ground_system.gd -- \
##       out:/abs/dir [map:greenhold]
## A Crown player (the ground on) whose main has been farmed a while (its start Farm's circle drawn down: harvests taken
## by hand), then:
##   crown_fresh.png    placing a Farm on fresh ground: its circle strong, "% of a fresh spot" over it;
##   crown_overlap.png  placing a Farm half over the spent circle: red tiles, a lower %;
##   crown_barracks.png placing a Barracks: only the faint layer (fresh green, spent red) and the Farms' circles;
##   crown_faint_max.png the same with the layer at full strength (Settings.ground_alpha 1.0);
##   clock_press.png    a Clockwork player placing a Cog Press (its circle of brass).
var main: Node
var out := ""
var map := "greenhold"
var t := 0.0
var busy := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"map": map = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.ground_alpha = 0.35
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.3 and not busy:
		busy = true
		_run()
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _start(me: String, foe: String) -> Game:
	var slots: Array = [{"who": "you", "faction": me, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "normal", "faction": foe, "colour": 1, "side": 1, "strategy": "balanced"}]
	main.start({"map": map, "seed": 7, "slots": slots, "ground": true})
	await _frames(5)
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	await _frames(20)
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.camera.process_mode = Node.PROCESS_MODE_ALWAYS
	if g.controls:
		g.controls.process_mode = Node.PROCESS_MODE_DISABLED
	if g.ground_view:
		g.ground_view.process_mode = Node.PROCESS_MODE_ALWAYS
	return g


func _end() -> void:
	var g: Game = main.game
	main.game = null
	g.queue_free()
	await _frames(3)


func _snap(name: String) -> void:
	await _frames(20)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("shot ", name)


func _place(g: Game, kind: String, cell: Vector2i) -> void:
	g.controls.mode = "place"
	g.controls.place_kind = kind
	g.controls.ghost_cell = cell
	g.ground_view._rev = -1
	g.ground_view._t = 0.0
	g.ground_view._process(1.0)
	g.ground_view.queue_redraw()
	g.queue_redraw()
	if g.overlay:
		g.overlay.queue_redraw()        # (the "% of a fresh spot" is drawn over the map's lighting)
	if g.hud:
		g.hud.queue_redraw()


func _first(g: Game, t2: int, kind: String) -> Building:
	for b in g.buildings:
		if b.team == t2 and b.kind == kind and not b.dead:
			return b
	return null


## The best free cell for kind near `around` whose circle holds about `want` (0..1) of a fresh one.
func _cell_holding(g: Game, kind: String, around: Vector2, want: float) -> Vector2i:
	var gl := g.ground_layer
	var best := Vector2i(-1, -1)
	var bd := INF
	var c0 := g.cell_of(around)
	for y in range(c0.y - 14, c0.y + 15):
		for x in range(c0.x - 14, c0.x + 15):
			var c := Vector2i(x, y)
			if g.placement_problem(0, kind, c) != "":
				continue
			var v := float(gl.preview(kind, c)[1])
			var d := absf(v - want) * 40.0 + Vector2(c - c0).length() * 0.2
			if d < bd:
				bd = d
				best = c
	return best


func _run() -> void:
	# ---- the Crown
	var g := await _start("crown", "clockwork")
	var farm := _first(g, 0, "farm")
	for i in 12:
		g.harvest(farm)                 # (its circle drawn down: what about 8 minutes of a full crew would do)
	g.ground_layer._cache.clear()
	g.ground_layer.tick(5.0)
	var h := g.halls_of(0)[0] as Building
	g.camera.position = h.center() + Vector2(0, 40)
	g.camera.zoom = Vector2(0.62, 0.62)
	var fresh := _cell_holding(g, "farm", h.center(), 0.9)
	_place(g, "farm", fresh)
	await _snap("crown_fresh")
	var half := _cell_holding(g, "farm", farm.center(), 0.4)
	_place(g, "farm", half)
	await _snap("crown_overlap")
	var bc := g.find_spot(0, "barracks", h, 4, 12, "near")
	_place(g, "barracks", bc)
	await _snap("crown_barracks")
	Settings.ground_alpha = 1.0
	_place(g, "barracks", bc)
	await _snap("crown_faint_max")
	Settings.ground_alpha = 0.35
	g.controls.mode = ""
	await _end()
	# ---- the Clockwork
	g = await _start("clockwork", "crown")
	var press := _first(g, 0, "cog_press")
	if press:
		for i in 400:
			g.ground_layer.draw(press, 10.0)
		g.ground_layer._cache.clear()
	var ct := g.halls_of(0)[0] as Building
	g.camera.position = ct.center() + Vector2(0, 40)
	g.camera.zoom = Vector2(0.62, 0.62)
	var spot := GearEcon.room_spot(g, 0, "cog_press", [ct], [], ct.center(), true, 8)
	if spot.x >= 0:
		_place(g, "cog_press", spot)
		await _snap("clock_press")
	g.controls.mode = ""
	await _end()
	quit()
