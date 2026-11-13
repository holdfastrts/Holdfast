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
	var gv = main.game.ground_view if main.game else null
	print("shot ", name, ("  ghost %.2f best %s %.2f" % [float(gv.ghost_share[1]), str(gv.best_cell), gv.best_share]) if gv and gv.placing_drinker() else "")


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
	var spot := _cell_holding(g, "cog_press", ct.center(), 0.95)
	if spot.x < 0:
		spot = GearEcon.room_spot(g, 0, "cog_press", [ct], [], ct.center(), true, 8)
	if spot.x >= 0:
		_place(g, "cog_press", spot)
		await _snap("clock_press")
	if press:                               # a Press half over the drawn-down brass (owner 2026-11-13: all 3 factions)
		var half_c := _cell_holding(g, "cog_press", press.center(), 0.4)
		if half_c.x >= 0:
			_place(g, "cog_press", half_c)
			await _snap("clock_press_overlap")
	var wc := g.find_spot(0, Defs.CW_WORKS, ct, 4, 12, "near")
	if wc.x >= 0:
		_place(g, Defs.CW_WORKS, wc)
		await _snap("clock_works")
	g.controls.mode = ""
	await _end()
	# ---- the Brood: no ground layer of its own; its Rootmaw circles (free spots) show while it roots something
	g = await _start("brood", "crown")
	# (no Rootmaw circle exists at the start: a Hard Brood computer plays our side for 5 minutes, both sides peaceful)
	for a in g.ais:
		a.peaceful = true
	var bai: AI = AIBroodNew.new()
	bai.game = g
	bai.team = 0
	bai.difficulty = 3
	bai.strategy = "economy"
	bai.peaceful = true
	g.add_child(bai)
	g.ais.append(bai)
	g.process_mode = Node.PROCESS_MODE_INHERIT
	RenderingServer.render_loop_enabled = false
	await _frames(30 * 300)
	RenderingServer.render_loop_enabled = true
	g.ais.erase(bai)
	bai.queue_free()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	print("brood: ", g.nb_spots.size(), " Rootmaw circles")
	var mother: Unit = null
	for u in g.units:
		if u.team == 0 and u.kind == "brood_mother" and not u.dead:
			mother = u
	var mp: Vector2 = mother.position if mother else g.camera.position
	for u in g.units:                       # one Rootmaw uprooted: its drunk ground stays behind as a free circle
		if u.team == 0 and u.kind == "rootmaw" and not u.dead and BroodNew.rooted(u):
			BroodNew.uproot(u, false)
			break
	g.camera.position = mp + Vector2(0, 40)
	g.camera.zoom = Vector2(0.5, 0.5)
	g.controls.mode = "nb_root"
	g.controls.place_kind = "rootmaw"
	g.controls.nb_morph = true
	var gc := BroodRoot.cell_for("rootmaw", mp + Vector2(220, 60), 1.0)
	var gd := INF
	for dy in range(-30, 31, 2):           # a spot a Rootmaw may root on (green ghost), nearest the Mother
		for dx in range(-30, 31, 2):
			var q := mp + Vector2(dx, dy) * float(Game.T)
			var cc := BroodRoot.cell_for("rootmaw", q, 1.0)
			if BroodRoot.place_problem(g, 0, "rootmaw", BroodRoot.feet_at("rootmaw", cc, 1.0), null, false, 1.0) == "":
				var d := q.distance_to(mp)
				if d < gd:
					gd = d
					gc = cc
	g.controls.ghost_cell = gc
	g.ground_view._process(1.0)
	g.ground_view.queue_redraw()
	g.queue_redraw()
	if g.overlay:
		g.overlay.queue_redraw()        # (the rooting ghost and its Rootmaw circle: BroodRoot.draw_overlay)
	await _snap("brood_rootmaw")
	g.controls.mode = ""
	await _end()
	quit()
