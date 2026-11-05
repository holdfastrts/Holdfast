extends SceneTree
## THE BROOD COMPUTER'S BASE LAYOUT, measured (docs/brood_layout.md; the owner, 2026-11-04 19:57: "Brood bad base
## design: the turtle-locked units are stuck inside"). A Hard Brood computer against a Hard Crown or Clockwork computer:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/study_brood_layout.gd -- \
##       foe:crown bs:economy map:highmoor seed:3 end:600 out:/abs/dir [off:1] [shots:1] [fs:balanced]
## off:1 = the computer before the fix (BroodLayout.off: no layout check, no alarm swamp rule, no safety net).
## Counts, for the Brood, once a second:
##  - STUCK: its units on foot in a walkable area other than the open map that borders its own rooted creatures
##    (BroodLayout.pockets): summed as unit-seconds, the longest any one unit stayed, and the most at once;
##  - its Rootmaws that went DRY and uprooted (their swamp gone), and the cause: a Mound Turtle of its own that got up
##    within 10 s before, in reach of that Rootmaw ("own turtle"), the Mother getting up ("Mother"), or anything else;
##  - its own Mound Turtles getting up, the spots the whole-map check refused, the safety net's uproots and walk-outs.
## Writes <out>/<tag>.txt (the result line, then each event) and appends the result line to <out>/summary.txt;
## shots:1 also films (needs xvfb): base_<tag>_MMSS.png at 4, 7 and 10 minutes, stuck_<tag>_MMSS.png the first time
## 3+ units have been stuck 5 s.
var main: Node
var g: Game
var t := 0.0
var foe_f := "crown"
var fs := "balanced"
var bs := "economy"
var map := "highmoor"
var seed_ := 3
var end_t := 600.0
var out := "/tmp/brood_layout"
var off := false
var shots := false
var bt := -1
var ai: AIBroodNew = null
var next_s := 1.0
var stuck_sec := 0
var stuck_max := 0
var stuck_long := 0.0
var _stuck_since := {}           # unit -> clock first seen stuck (this run of being stuck)
var events: Array = []
var _modes := {}                 # unit -> its last tesla_mode
var _ups: Array = []             # [clock, kind, position, swamp radius] of its sources getting up
var dry := {"own turtle": 0, "Mother": 0, "other": 0}
var turtle_ups := 0
var mother_ups := 0
var shooting := false
var pending: Array = []
var _shot_stuck := false
var _base_at := [240.0, 420.0, 590.0, 890.0]
var _last_n := 0
var _stages := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"foe": foe_f = kv[1]
			"fs": fs = kv[1]
			"bs": bs = kv[1]
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"end": end_t = float(kv[1])
			"out": out = kv[1]
			"off": off = kv[1] == "1"
			"shots": shots = kv[1] == "1"
	BroodLayout.off = off
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0
	if shots:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.render_loop_enabled = false


func tag() -> String:
	return "%s_%s_%s_s%d_%s" % [map, bs, foe_f, seed_, "before" if off else "after"]


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": foe_f, "colour": 0, "side": 0, "strategy": fs},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": bs}]})
		return false
	if main.game == null:
		return false
	g = main.game
	g.path_budget_us = 1 << 40
	if g.hud:
		g.hud.visible = false
		g.hud.countdown = 0.0
	paused = false
	if g.spectator and g.spectator.process_mode != Node.PROCESS_MODE_DISABLED:
		g.spectator.process_mode = Node.PROCESS_MODE_DISABLED
	if g.controls and g.controls.process_mode != Node.PROCESS_MODE_DISABLED:
		g.controls.process_mode = Node.PROCESS_MODE_DISABLED
	if bt < 0:
		for a in g.ais:
			if a is AIBroodNew:
				ai = a
				bt = a.team
		if bt < 0:
			return false
	if shooting:
		return false
	if not pending.is_empty():
		_shoot()
		return false
	_watch_modes()
	if g.clock >= next_s:
		next_s += 1.0
		_sample()
	if shots and not _base_at.is_empty() and g.clock >= float(_base_at[0]):
		_base_at.pop_front()
		var q := BroodNew.queen(g, bt)
		if q:
			pending.append(["base_%s_%s.png" % [tag(), _mmss(g.clock)], q.position, 0.75])
	if g.over or g.clock >= end_t:
		_finish()
		return true
	return false


## Its creatures getting up (and the Rootmaws that went dry), every tick.
func _watch_modes() -> void:
	for u in g.units:
		if u.team != bt or not BroodNew.ROOTERS.has(u.kind):
			continue
		var was := String(_modes.get(u, u.tesla_mode))
		_modes[u] = u.tesla_mode
		if u.kind == BroodNew.QUEEN:
			var stg := BroodNew.stage(u)
			if int(_stages.get(u, stg)) != stg:
				events.append("%s the Mother grows to stage %d (her nest %s)" % [_mmss(g.clock), stg + 1, str(BroodRoot.fp(u.kind, BroodRoot.scale_of(u))[0])])
			_stages[u] = stg
		if was != u.tesla_mode and u.tesla_mode == "deployed" and g.clock > 5.0:
			events.append("%s a %s roots at %s" % [_mmss(g.clock), u.kind, str(g.cell_of(u.position))])
		if was == u.tesla_mode or u.tesla_mode != "packing" or was != "deployed":
			continue
		if u.kind == BroodNew.TURTLE or u.kind == BroodNew.QUEEN:
			_ups.append([g.clock, u.kind, u.position, BroodNew.swamp_full(u)])
			if u.kind == BroodNew.TURTLE:
				turtle_ups += 1
				events.append("%s a Mound Turtle gets up%s" % [_mmss(g.clock), " (dying)" if u.hp < u.max_hp * 0.25 else ""])
			else:
				mother_ups += 1
				events.append("%s the Mother gets up" % _mmss(g.clock))
		elif u.kind == BroodNew.MAW and bool(u.nb.get("dry", false)):
			var cause := "other"
			for e in _ups:
				if g.clock - float(e[0]) > 10.0:
					continue
				var d: Vector2 = (u.position - (e[2] as Vector2)) / Defs.TILE
				if d.x * d.x + d.y * 1.15 * d.y * 1.15 <= float(e[3]) * float(e[3]) + 4.0:
					cause = "own turtle" if String(e[1]) == BroodNew.TURTLE else "Mother"
			dry[cause] = int(dry[cause]) + 1
			events.append("%s a Rootmaw went dry and uprooted (%s)" % [_mmss(g.clock), cause])


func _sample() -> void:
	var p := BroodLayout.pockets(g, bt)
	var now := {}
	var n := 0
	var mid := Vector2.ZERO
	for r in p:
		for u in p[r]:
			now[u] = true
			n += 1
			mid += (u as Unit).position
			if not _stuck_since.has(u):
				_stuck_since[u] = g.clock
			stuck_long = maxf(stuck_long, g.clock - float(_stuck_since[u]))
	for u in _stuck_since.keys():
		if not now.has(u):
			_stuck_since.erase(u)
	stuck_sec += n
	stuck_max = maxi(stuck_max, n)
	if n > 0 and (int(g.clock) % 10 == 0 or _last_n == 0):
		var what: Array = []
		var touch := BroodLayout._touching(g, bt)
		for r in p:
			var ks: Array = []
			for f in touch.get(r, []):
				ks.append(String((f as Unit).kind))
			var b := BroodLayout.blocker(g, bt, r)
			what.append("%d units in an area of %d cells by %s (the one to get up: %s)" % [(p[r] as Array).size(), int(g._region_size[r]), ", ".join(ks),
				"%s at %s" % [b.kind, str(g.cell_of(b.position))] if b else "none but the Mother"])
		events.append("%s %d of its units shut in by its own creatures: %s" % [_mmss(g.clock), n, "; ".join(what)])
	_last_n = n
	if int(g.clock) % 60 == 0:
		print("%s stuck %d (sum %d)" % [_mmss(g.clock), n, stuck_sec])
	if shots and not _shot_stuck and n >= 3:
		var long := 0
		for u in _stuck_since:
			if g.clock - float(_stuck_since[u]) >= 5.0:
				long += 1
		if long >= 3:
			_shot_stuck = true
			pending.append(["stuck_%s_%s.png" % [tag(), _mmss(g.clock)], mid / float(n), 1.1])
			var q := BroodNew.queen(g, bt)
			if q:
				pending.append(["stuckwide_%s_%s.png" % [tag(), _mmss(g.clock)], q.position.lerp(mid / float(n), 0.4), 0.6])


func _shoot() -> void:
	shooting = true
	var p: Array = pending.pop_front()
	var cam: Camera2D = g.camera
	cam.position = p[1]
	cam.zoom = Vector2(p[2], p[2])
	cam.reset_smoothing()
	RenderingServer.render_loop_enabled = true
	for i in 20:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(p[0]))
	print("SHOT ", p[0])
	RenderingServer.render_loop_enabled = false
	shooting = false


func _mmss(c: float) -> String:
	return "%d:%02d" % [int(c) / 60, int(c) % 60]


func _finish() -> void:
	var res := "RESULT %s %s at %s | stuck unit-seconds %d, most at once %d, longest %.0f s | Rootmaws dry: own turtle %d, Mother %d, other %d | turtles up %d, Mother up %d | refused %d, net uproots %d, walk-outs %d | grubs %d, army %d, foe army %d" % [
		tag(), ("over, side %d won" % g.winner) if g.over else "time", _mmss(g.clock),
		stuck_sec, stuck_max, stuck_long, int(dry["own turtle"]), int(dry["Mother"]), int(dry["other"]), turtle_ups, mother_ups,
		ai.layout_refused if ai else 0, ai.unstuck_uproots if ai else 0, ai.unstuck_passes if ai else 0,
		BroodNew.count_of(g, bt, "grub"), g.army_value(bt), g.army_value(1 - bt)]
	print(res)
	var f := FileAccess.open(out.path_join(tag() + ".txt"), FileAccess.WRITE)
	if f:
		f.store_string(res + "\n" + "\n".join(events) + "\n")
		f.close()
	if g.mlog:
		var lf := FileAccess.open(out.path_join(tag() + "_log.txt"), FileAccess.WRITE)
		if lf:
			lf.store_string(g.mlog.text())
			lf.close()
	var path := out.path_join("summary.txt")
	var s := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if s:
		s.seek_end()
		s.store_line(res)
		s.close()
