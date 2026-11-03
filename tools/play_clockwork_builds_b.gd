extends "res://tools/shot_ai_match.gd"
## COACHED, FILMED GAMES OF THE CLOCKWORK'S PENDULUMS AND HEAVY WORKS PUSH (cw-builds-b, docs/clockwork_builds_b.md), in the
## style of the Springer timing's coaching (tools/play_clockwork_springer.gd) and the Brood's (docs/brood_new_play_3.md).
## Side 0 is the Clockwork computer (scripts/ai_clockwork.gd) on plan `cw` (pendulum, heavy, or an old plan to compare);
## side 1 a computer of faction `foe` on plan `fp`. The coach steers the plan through its settings: `set:key=value,...`
## (any key of the plan in scripts/ai_cw_builds_b.gd: steps, push, keep, front; a value in Godot's text form).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_clockwork_builds_b.gd -- \
##       cw:pendulum foe:brood fp:rush map:greenhold seed:11 out:/abs/dir [end:720] [da:hard db:hard] [set:front=10]
##   python3 -I tools/play_brood_new_gif.py /abs/dir          (the clip frames into first_push_fight.gif)
## Everything of tools/shot_ai_match.gd (fight_*.png, base_<team>_MMSS.png, log.txt, ai.txt) plus:
##   <out>/minutes.txt  a line a minute: Winders, cogs earned (both sides), bank, Tension, supply, the army by kind, the push's
##                      phase, the foe's workers and army, value killed and lost, the Brood's economy lost
##   <out>/events.txt   what the plan and the push decided (AIClockwork.sp_log), with the clock
##   key moments: heavy_MMSS.png (the base when the Heavy Works stands), out_MMSS.png (the army as each push goes out),
##   march_MMSS.png (the push on the march, every 30 s), siege_MMSS.png and fall_MMSS.png (a wall piece under fire, and
##   when it falls), back_MMSS.png (a retreat), goal_MMSS.png (a new goal), clip_first_push_fight_NN.png (the GIF frames)

var cw_plan := "pendulum"
var fp := "rush"
var sets := {}
var _ai = null
var _min_lines: Array = []
var _next_min := 60.0
var _logged := 0
var _events: Array = []
var _clips: Array = []
var _shots_t := {}
var _heavy_shot := false
var _march_t := 0.0


func _initialize() -> void:
	super._initialize()
	fa = "clockwork"
	fb = "brood"
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"cw": cw_plan = kv[1]
			"foe": fb = kv[1]
			"fp": fp = kv[1]
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
			main.start({"map": map, "seed": seed_, "slots": [
				{"who": da, "faction": "clockwork", "colour": 0, "side": 0, "strategy": cw_plan},
				{"who": db, "faction": fb, "colour": 1, "side": 1, "strategy": fp}]})
			for a in main.game.ais:
				if a.team == 0 and a is AIClockwork:
					_ai = a
					if a.bo_on and not sets.is_empty():
						a.over = sets.duplicate(true)
						a._make_plan()
						a._b_ready()
					print("COACH plan %s v %s %s, forced %s" % [cw_plan, fb, fp, str(sets.keys())])
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
	if _ai == null:
		return
	var p = _ai.get("push")
	while _logged < _ai.sp_log.size():
		var e: Array = _ai.sp_log[_logged]
		_logged += 1
		var line := "%s %s" % [_mmss(float(e[0])), String(e[1])]
		_events.append(line)
		print("EV " + line)
		var s := String(e[1])
		if p == null:
			continue
		if s.contains("goes out:"):
			_shot("out", p._front_centre(), 0.8, 5.0)
		elif s.contains("in the way at"):
			_shot("siege", p.piece.center() if p.piece != null else p._front_centre(), 1.0, 5.0)
		elif s.contains("falls after"):
			_shot("fall", p.anchor, 1.0, 5.0)
		elif s.contains("pulls back"):
			_shot("back", p._front_centre(), 1.0, 5.0)
		elif s.contains("heads for"):
			_shot("goal", p.goal, 0.9, 30.0)
		elif s.contains("meets") and not _shots_t.has("clip_first_push_fight"):
			_shots_t["clip_first_push_fight"] = g.clock
			_clips.append(["first_push_fight", p._front_centre(), 46, 6, 1.1])
	if not _heavy_shot and g.buildings.any(func(b: Building) -> bool: return b.team == 0 and not b.dead and b.built and b.kind == "heavy_works"):
		_heavy_shot = true
		for b in g.buildings:
			if b.team == 0 and b.kind == "heavy_works" and b.built and not b.dead:
				pending.append(["heavy_%s.png" % _mmss(g.clock), b.center(), 0.9])
				break
	if p != null and (p.phase == "march" or p.phase == "fight" or p.phase == "siege") and g.clock - _march_t >= 30.0:
		_march_t = g.clock
		pending.append(["march_%s.png" % _mmss(g.clock), p._front_centre(), 1.0])
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
	var p = _ai.get("push") if _ai else null
	var where := ""
	if p != null and p.phase != "":
		where = " anchor %s front %s goal %s" % [str(g.cell_of(p.anchor)), str(g.cell_of(p._front_centre())), str(g.cell_of(p.goal)) if p.goal != Vector2.INF else "-"]
	_min_lines.append("%s | CW winders %d earned %d bank %d T %d supply %d/%d army %d %s | push %s (%d out)%s | foe workers %d earned %d army %d | killed %d lost %d" % [
		_mmss(g.clock), g.worker_count(0), int(g.stats[0]["gold"]), int(g.players[0]["gold"]), int(g.tension(0)), g.supply_used(0),
		int(g.players[0]["cap"]), _army_val(0), str(kinds), (p.phase if p != null else "-"), (p.pushes if p != null else 0), where,
		g.worker_count(1), int(g.stats[1]["gold"]), _army_val(1), int(g.stats[0]["value_killed"]), int(g.stats[1]["value_killed"])])
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
	e.store_line("winner %s at %s" % [str(g.winner) if g.over else "none", _mmss(g.clock)])
	e.close()
	quit(0)
