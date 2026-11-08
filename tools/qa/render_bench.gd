extends SceneTree
## qa-perf (0.33.8): the drawing's cost on screen, from a late-game state (a save written by tools/perf_bench.gd
## savestate:FILE). Each view is held FRAMES frames (after a warm-up) and measured: frame time, draw calls, the
## renderer's CPU time, and the game's own drawing parts (Prof).
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 60 \
##       --script res://tools/qa/render_bench.gd -- save:/abs/state.json [spectate] [mobile] [frames:240] [out:/abs/file.json]
##
## Views: army (the biggest crowd of units, zoom 1.5), base (side 1's hall), wide (zoomed out as far as the controls go,
## 0.55, over the biggest crowd), fogged (a corner of the map side 1 hasn't seen). spectate: side 1 is a computer too and the
## spectator panels (VIEW, PRODUCTION, ARMY & STRUCTURES, AI STORY) are open, as the owner watches computer matches.
## On a machine with no graphics card (xvfb) the renderer is llvmpipe, a software rasteriser: its times are far slower
## than any GPU's and are only good for comparing; the draw call counts are what a phone's GPU would get too.

var main: Node
var t := 0.0
var save_path := ""
var spectate := false
var frames := 240
var warm := 40
var out_path := ""
var device := "pc"
var _phase := "boot"
var _views := ["army", "base", "wide", "fogged"]
var _vi := 0
var _n := 0
var _last := 0
var _ms := PackedFloat32Array()
var _dc := 0.0
var _objs := 0.0
var _prims := 0.0
var _rcpu := 0.0
var _rgpu := 0.0
var _prev := {}
var _acc := {}
var _vp: RID
var results: Array = []
const ZONES := ["unit draw", "building draw", "overlay draw", "hud draw", "hud", "hud/minimap", "hud/spec prod", "hud/spec army", "hud/spec story", "silhouettes", "units", "game", "ai", "replay/record"]


class SilentSfx extends Sfx:
	func _find(_name: String) -> Array:
		return []


func _initialize() -> void:
	Settings.load_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("save:"):
			save_path = a.substr(5)
		elif a == "spectate":
			spectate = true
		elif a == "mobile":
			device = "mobile"
		elif a.begins_with("frames:"):
			frames = int(a.substr(7))
		elif a.begins_with("out:"):
			out_path = a.substr(4)
	Settings.device = device
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.add_child(SilentSfx.new())
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0


func _process(delta: float) -> bool:
	t += delta
	var now := Time.get_ticks_usec()
	match _phase:
		"boot":
			if t > 0.3:
				var save = JSON.parse_string(FileAccess.get_file_as_string(save_path))
				var cfg: Dictionary = (save["cfg"] as Dictionary).duplicate(true)
				if spectate:
					for sl in cfg["slots"]:
						if sl["who"] == "you":
							sl["who"] = "hard"
				cfg["resume"] = save
				main.start(cfg)
				if main.game:
					main.game.path_budget_us = 1 << 40
				_vp = root.get_viewport().get_viewport_rid()
				RenderingServer.viewport_set_measure_render_time(_vp, true)
				_phase = "wait"
				_n = 0
		"wait":
			var g: Game = main.game
			if g == null:
				return false
			if g.hud:
				g.hud.countdown = 0.0
			paused = false
			_n += 1
			if _n > 30:
				if spectate and g.hud and g.hud.has_method("open_spectator_panels"):
					g.hud.open_spectator_panels()
				_begin_view()
		"view":
			var g2: Game = main.game
			_n += 1
			if _n > warm:
				_ms.append((now - _last) / 1000.0)
				_dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				_objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
				_prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
				_rcpu += RenderingServer.viewport_get_measured_render_time_cpu(_vp)
				_rgpu += RenderingServer.viewport_get_measured_render_time_gpu(_vp)
				_take()
			elif _n == warm:
				_take()
				_acc.clear()
			_aim(g2)
			if _n >= warm + frames:
				_end_view(g2)
				_vi += 1
				if _vi >= _views.size():
					_finish()
					return true
				_begin_view()
	_last = now
	return false


func _take() -> void:
	Prof.flush()
	for z in Prof.us:
		var d := int(Prof.us[z]) - int(_prev.get(z, 0))
		if d > 0:
			_acc[z] = int(_acc.get(z, 0)) + d
	_prev = Prof.us.duplicate()


func _begin_view() -> void:
	_phase = "view"
	_n = 0
	_ms = PackedFloat32Array()
	_dc = 0.0
	_objs = 0.0
	_prims = 0.0
	_rcpu = 0.0
	_rgpu = 0.0
	_acc.clear()


## The biggest crowd of units: the unit with the most others within 300 px.
func _crowd(g: Game) -> Vector2:
	var best := Vector2(Game.W * Game.T * 0.5, Game.H * Game.T * 0.5)
	var bn := -1
	var k := 0
	for u in g.units:
		k += 1
		if u.dead or k % 3 != 0:
			continue
		var n := g.units_near(u.position, 300.0).size()
		if n > bn:
			bn = n
			best = u.position
	return best


func _aim(g: Game) -> void:
	if _n > 1:
		return
	var v: String = _views[_vi]
	var z := 1.5
	var at := Vector2.ZERO
	match v:
		"army":
			at = _crowd(g)
		"base":
			var hs: Array = g.halls_of(0, false)
			at = hs[0].center() if not hs.is_empty() else _crowd(g)
		"wide":
			at = _crowd(g)
			z = 0.55
		"fogged":
			z = 1.0
			at = Vector2(Game.T * 6, Game.T * 6)
			var best := -1
			for c in [Vector2i(6, 6), Vector2i(Game.W - 7, 6), Vector2i(6, Game.H - 7), Vector2i(Game.W - 7, Game.H - 7)]:
				var e := int(g.explored[g.idx(c)]) if g.explored.size() > 0 else 0
				if best < 0 or e < best:
					best = e
					at = g.cell_center(c)
	g.camera.position = at
	g.camera.zoom = Vector2(z, z)


func _end_view(g: Game) -> void:
	var a := _ms.duplicate()
	a.sort()
	var n := maxi(1, a.size())
	var sm := 0.0
	for x in a:
		sm += x
	var vs: Vector2 = root.get_viewport().get_visible_rect().size
	var r := {"view": _views[_vi], "res": "%dx%d" % [int(vs.x), int(vs.y)], "spectate": spectate, "device": device,
		"frame_ms": sm / n, "p95_ms": a[int(a.size() * 0.95)] if a.size() > 0 else 0.0, "worst_ms": a[a.size() - 1] if a.size() > 0 else 0.0,
		"draw_calls": _dc / n, "objects": _objs / n, "primitives": _prims / n, "render_cpu_ms": _rcpu / n, "render_gpu_ms": _rgpu / n,
		"units": g.units.size(), "buildings": g.buildings.size(), "clock": g.clock}
	for z in ZONES:
		r[z] = float(_acc.get(z, 0)) / 1000.0 / n
	results.append(r)
	print("RENDER %-7s %s | %.1f ms a frame (p95 %.1f, worst %.1f) | %.0f draw calls, %.0f objects, %.0f primitives | renderer cpu %.2f ms gpu %.2f ms | %s" % [
		r["view"], r["res"], r["frame_ms"], r["p95_ms"], r["worst_ms"], r["draw_calls"], r["objects"], r["primitives"], r["render_cpu_ms"], r["render_gpu_ms"],
		", ".join(ZONES.map(func(z) -> String: return "%s %.2f" % [z, r[z]]))])


func _finish() -> void:
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(results, "  "))
		f.close()
