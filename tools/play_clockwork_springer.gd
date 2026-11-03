extends "res://tools/shot_ai_match.gd"
## COACHED, FILMED GAMES OF THE CLOCKWORK'S SPRINGER TIMING (docs/clockwork_ai_rebuild.md), in the style of the Brood's
## coaching (tools/play_brood_3.gd, docs/brood_new_play_3.md). Side 0 is the Clockwork computer (scripts/ai_clockwork.gd) on
## the Springer timing; the coach STEERS it through its building blocks: each game forces a plan (`coach:<variant>`, the
## variants below; any plan setting changed with `set:key=value,...`), side 1 is the Crown computer.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_clockwork_springer.gd -- \
##       coach:draft map:greenhold seed:11 out:/abs/dir [end:600] [db:hard] [sb:balanced] [set:raid=4]
##   python3 -I tools/play_brood_new_gif.py /abs/dir          (the clip frames into first_leap.gif)
## Everything of tools/shot_ai_match.gd (fight_*.png, base_<team>_MMSS.png, log.txt, ai.txt) plus:
##   <out>/minutes.txt  a line a minute: Winders, cogs earned (both sides), cogs and Tension in the bank, supply, the army,
##                      the raid's phase and Springers, the Crown's Labourers and the ones it lost, value killed and lost
##   <out>/events.txt   what the plan and the raid decided (AIClockwork.sp_log), with the clock
##   key moments: build_MMSS.png (the base when the 4th Springer is out), swift_MMSS.png (the Swift's first look),
##   leap_MMSS.png (1.5 s after each leap in, on the landing), up_MMSS.png (8 s after: the raid up there), out_MMSS.png
##   (each leap out), clip_first_leap_NN.png (frames of the first leap, for the GIF)
## The coach's variants (steps lists for AIClockwork.over["steps"], or plan settings):
##   draft    the plan as it is in scripts/ai_clockwork.gd
##   big      the Mainspring on its BIG gear with 6 Winders (2.6 Tension a second, stores 400)
##   noswift  no Aviary, no Swift: the leap waits for sight it never gets (to show why the Swift is needed)
##   ai       the old computer's Balanced, for comparison (no plan)

const COACH := {
	"draft": {"strategy": "springer", "set": {}},
	"big": {"strategy": "springer", "set": {"steps": ["7 cog_press", "8 movement_works", "9 mainspring:big", "crew mainspring 6",
		"11 regulator", "escapement", "movement_works", "workers 18", "research high_leap", "cuckoo_house", "springer 4",
		"18 regulator", "cuckoo 1", "attack", "workers 22", "clocktower", "end"]}},
	"noswift": {"strategy": "springer", "set": {"steps": ["7 cog_press", "8 movement_works", "9 mainspring", "crew mainspring 3",
		"11 regulator", "escapement", "movement_works", "workers 16", "research high_leap", "springer 4", "18 regulator",
		"attack", "workers 21", "clocktower", "end"]}},
	"ai": {"strategy": "balanced", "set": {}},
}

var coach_plan := "draft"
var sb := "balanced"
var sets := {}
var _ai = null
var _min_lines: Array = []
var _next_min := 60.0
var _logged := 0
var _events: Array = []
var _crown_seen := {}
var crown_lost := 0
var _built_shot := false
var _clips: Array = []
var _shots_t := {}


func _initialize() -> void:
	super._initialize()
	fa = "clockwork"
	fb = "crown"
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"coach": coach_plan = kv[1]
			"sb": sb = kv[1]
			"set":
				for pair in kv[1].split(","):
					var p := pair.split("=", true, 1)
					if p.size() == 2:
						sets[p[0]] = str_to_var(p[1]) if str_to_var(p[1]) != null else p[1]


func _process(delta: float) -> bool:
	if main.game == null:
		t += delta
		if t > 0.2:
			seed(seed_)
			var c: Dictionary = COACH.get(coach_plan, COACH["draft"])
			main.start({"map": map, "seed": seed_, "slots": [
				{"who": da, "faction": "clockwork", "colour": 0, "side": 0, "strategy": String(c["strategy"])},
				{"who": db, "faction": "crown", "colour": 1, "side": 1, "strategy": sb}]})
			for a in main.game.ais:
				if a.team == 0 and a is AIClockwork:
					_ai = a
					var o: Dictionary = (c["set"] as Dictionary).duplicate(true)
					for k in sets:
						o[k] = sets[k]
					if a.bo_on:
						a.over = o
						a._make_plan()
					print("COACH variant %s: strategy %s, forced %s" % [coach_plan, String(c["strategy"]), str(o.keys())])
		return false
	g = main.game
	if g.hud and g.hud.countdown > 0.0:
		g.hud.countdown = 0.0
	if paused:
		paused = false
	g.reveal = true          # (the camera sees everything; the computer only what its side sees: Game.is_visible_to)
	if not g.over:
		_coach()
	if not shooting and pending.is_empty() and not _clips.is_empty():
		_clip_run()
	return super._process(delta)


func _shot(name: String, at, zoom := 1.0, gap := 15.0) -> void:
	if g.clock - float(_shots_t.get(name, -999.0)) < gap:
		return
	_shots_t[name] = g.clock
	pending.append(["%s_%s.png" % [name, _mmss(g.clock)], at.position if at is Unit else at, zoom])


func _coach() -> void:
	if Engine.get_physics_frames() % 10 == 0:
		var alive := {}
		for u in g.units:
			if u.team == 1 and not u.dead and u.is_worker():
				alive[u.get_instance_id()] = true
		for id in _crown_seen:
			if not alive.has(id):
				crown_lost += 1
		_crown_seen = alive
	if _ai == null:
		return
	# the plan's and the raid's decisions, and the shots they call for
	while _logged < _ai.sp_log.size():
		var e: Array = _ai.sp_log[_logged]
		_logged += 1
		var line := "%s %s" % [_mmss(float(e[0])), String(e[1])]
		_events.append(line)
		print("EV " + line)
		var s := String(e[1])
		var r = _ai.raid
		if s.begins_with("leap:") and r != null:
			_later.append([g.clock + 1.5, "leap_%s.png" % _mmss(g.clock), r.land])
			_later.append([g.clock + 8.0, "up_%s.png" % _mmss(g.clock), r.land])
			if not _shots_t.has("clip_first_leap"):
				_shots_t["clip_first_leap"] = g.clock
				_clips.append(["first_leap", r.stage.lerp(r.land, 0.6), 46, 6, 1.25])
		elif s.begins_with("out:") and r != null and r.stage != Vector2.INF:
			_later.append([g.clock + 2.0, "out_%s.png" % _mmss(g.clock), r.stage])
		elif s.begins_with("the Swift looks up") and r != null and r.swift != null:
			_shot("swift", r.swift, 0.9)
	# (shot_ai_match's _later takes [clock, file, Unit or Building]; Vector2 spots are filmed here)
	for i in range(_later.size() - 1, -1, -1):
		var e2: Array = _later[i]
		if e2[2] is Vector2 and g.clock >= float(e2[0]):
			_later.remove_at(i)
			pending.append([e2[1], e2[2], 1.1])
	if not _built_shot and g.units.filter(func(u: Unit) -> bool: return u.team == 0 and not u.dead and u.kind == Defs.SPRINGER).size() >= 4:
		_built_shot = true
		var h: Building = g._own_hall(0)
		if h:
			pending.append(["build_%s.png" % _mmss(g.clock), h.global_position + Vector2(0, -40), 0.8])
	if g.clock >= _next_min:
		_next_min += 60.0
		_minute()


func _army_val(tm: int) -> int:
	var v := 0.0
	for u in g.army(tm):
		v += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("tension", u.d.get("cost2", 0)))
	return int(v)


func _minute() -> void:
	var kinds := {}
	for u in g.army(0):
		kinds[u.kind] = int(kinds.get(u.kind, 0)) + 1
	var r = _ai.raid if _ai else null
	_min_lines.append("%s | CW winders %d earned %d bank %d T %d supply %d/%d army %d %s | raid %s springers %d leaps %d | Crown labourers %d (lost %d) earned %d army %d | killed %d lost %d" % [
		_mmss(g.clock), g.worker_count(0), int(g.stats[0]["gold"]), int(g.players[0]["gold"]), int(g.tension(0)), g.supply_used(0),
		int(g.players[0]["cap"]), _army_val(0), str(kinds), (r.phase if r and r.launched else "-"), (r.springers.size() if r else 0),
		(r.leaps if r else 0), g.worker_count(1), crown_lost, int(g.stats[1]["gold"]), _army_val(1), int(g.stats[0]["value_killed"]),
		int(g.stats[1]["value_killed"])])
	print("MIN " + _min_lines[-1])


func _clip_run() -> void:
	shooting = true
	var c: Array = _clips.pop_front()
	var cam: Camera2D = g.camera
	var keep_pos := cam.position
	var keep_zoom := cam.zoom
	cam.zoom = Vector2(c[4], c[4])
	cam.position = c[1]
	cam.reset_smoothing()
	RenderingServer.render_loop_enabled = true
	for i in int(c[2]):
		for k in int(c[3]):
			await process_frame
		if i == 0:
			for k in 6:
				await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join("clip_%s_%02d.png" % [c[0], i]))
	print("CLIP %s %d frames" % [c[0], int(c[2])])
	RenderingServer.render_loop_enabled = live
	cam.position = keep_pos
	cam.zoom = keep_zoom
	shooting = false


func _finish() -> void:
	super._finish()
	var f := FileAccess.open(out.path_join("minutes.txt"), FileAccess.WRITE)
	for l in _min_lines:
		f.store_line(l)
	f.close()
	var e := FileAccess.open(out.path_join("events.txt"), FileAccess.WRITE)
	for l in _events:
		e.store_line(l)
	if _ai:
		for s in _ai.step_log:
			e.store_line("step %s done at %s" % [String(s["step"]), _mmss(float(s["at"]))])
	e.store_line("winner %s at %s; Crown labourers lost %d" % [str(g.winner) if g.over else "none", _mmss(g.clock), crown_lost])
	e.close()
	quit(0)
