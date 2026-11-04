extends "res://tools/shot_ai_match.gd"
## COACHED, FILMED GAMES OF THE CLOCKWORK'S OWL RAIDS (cw-builds-c; scripts/ai_cw_builds_c.gd, docs/clockwork_builds_c.md), in
## the style of tools/play_clockwork_springer.gd. Side 0 is the Clockwork computer on the Owl raids (or `coach:<variant>`),
## side 1 the Crown or the Brood computer (`vs:crown|brood`, plan `sb:`, difficulty `db:`).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_clockwork_owls.gd -- \
##       coach:draft vs:crown map:greenhold seed:11 out:/abs/dir [end:600] [db:hard] [sb:balanced] [set:flock=3]
##   python3 -I tools/play_brood_new_gif.py /abs/dir          (the clip frames into <moment>.gif)
## Everything of tools/shot_ai_match.gd (fight_*.png, base_<team>_MMSS.png, log.txt, ai.txt) plus:
##   <out>/minutes.txt  a line a minute: Winders, cogs earned (both sides), bank, Tension, supply, the army, the flock's
##                      phase and Owls, the enemy's workers and the ones it lost, value killed and lost, the Owls' kills
##   <out>/events.txt   what the plan and the flock decided (AIClockwork.sp_log), with the clock
##   key moments: owl_MMSS.png (the first Owl), map_MMSS.png (the whole map when the crank post is chosen), post_MMSS.png
##   (the cranks and the flock at the post), out_MMSS.png (8 s into each sortie, on the flock), strike_MMSS.png (2 s into a
##   strike), back_MMSS.png (each turn back), kill_MMSS.png (a building the Owls destroy), clip_first_strike_NN.png
## The coach's variants:
##   draft    the plan as it is in scripts/ai_cw_builds_c.gd
##   nopost   no crank post (the flock rests at home: to show why the post is needed)
##   ai       the old computer's Balanced, for comparison (no plan)

const COACH := {
	"draft": {"strategy": "owls", "set": {}},
	"nopost": {"strategy": "owls", "set": {"cranks": 0}},
	"ai": {"strategy": "balanced", "set": {}},
}

var coach_plan := "draft"
var vs := "crown"
var sb := "balanced"
var sets := {}
var _ai = null
var _min_lines: Array = []
var _next_min := 60.0
var _logged := 0
var _events: Array = []
var _op_seen := {}
var op_lost := 0
var _clips: Array = []
var _shots_t := {}
var _owl_shot := false


func _initialize() -> void:
	super._initialize()
	fa = "clockwork"
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"coach": coach_plan = kv[1]
			"vs": vs = kv[1]
			"sb": sb = kv[1]
			"set":
				for pair in kv[1].split(","):
					var p := pair.split("=", true, 1)
					if p.size() == 2:
						sets[p[0]] = str_to_var(p[1]) if str_to_var(p[1]) != null else p[1]
	fb = vs


func _process(delta: float) -> bool:
	if main.game == null:
		t += delta
		if t > 0.2:
			seed(seed_)
			var c: Dictionary = COACH.get(coach_plan, COACH["draft"])
			main.start({"map": map, "seed": seed_, "slots": [
				{"who": da, "faction": "clockwork", "colour": 0, "side": 0, "strategy": String(c["strategy"])},
				{"who": db, "faction": vs, "colour": 1, "side": 1, "strategy": sb}]})
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


func _flock_at() -> Vector2:
	var b = _ai.btc if _ai else null
	if b == null or b.flock.is_empty():
		return Vector2.INF
	return b._centre(b.flock)


func _coach() -> void:
	if Engine.get_physics_frames() % 10 == 0:
		var alive := {}
		for u in g.units:
			if u.team == 1 and not u.dead and u.is_worker():
				alive[u.get_instance_id()] = true
		for id in _op_seen:
			if not alive.has(id):
				op_lost += 1
		_op_seen = alive
	if _ai == null:
		return
	var b = _ai.btc
	while _logged < _ai.sp_log.size():
		var e: Array = _ai.sp_log[_logged]
		_logged += 1
		var line := "%s %s" % [_mmss(float(e[0])), String(e[1])]
		_events.append(line)
		print("EV " + line)
		var s := String(e[1])
		if b == null:
			continue
		if s.begins_with("out:"):
			_later.append([g.clock + 8.0, "out_%s.png" % _mmss(g.clock), "flock"])
		elif s.begins_with("strike:"):
			_later.append([g.clock + 2.5, "strike_%s.png" % _mmss(g.clock), "flock"])
			if not _shots_t.has("clip_first_strike"):
				_shots_t["clip_first_strike"] = g.clock
				_clips.append(["first_strike", _flock_at(), 40, 6, 1.3])
		elif s.begins_with("back:"):
			_later.append([g.clock + 1.0, "back_%s.png" % _mmss(g.clock), "flock"])
		elif s.begins_with("the crank post:"):
			_shot("map", Vector2(g.W, g.H) * Defs.TILE * 0.5, 0.3, 120.0)
			_later.append([g.clock + 40.0, "post_%s.png" % _mmss(g.clock), b.post])
		elif s.begins_with("the Owls destroy"):
			_shot("kill", _flock_at(), 1.1, 10.0)
		elif s.begins_with("the Owls defend"):
			_later.append([g.clock + 3.0, "defend_%s.png" % _mmss(g.clock), "flock"])
	for i in range(_later.size() - 1, -1, -1):
		var e2: Array = _later[i]
		if g.clock < float(e2[0]):
			continue
		if e2[2] is Vector2:
			_later.remove_at(i)
			pending.append([e2[1], e2[2], 1.1])
		elif e2[2] is String and e2[2] == "flock":
			_later.remove_at(i)
			var at := _flock_at()
			if at != Vector2.INF:
				pending.append([e2[1], at, 1.15])
	if not _owl_shot and b != null and not b.flock.is_empty():
		_owl_shot = true
		pending.append(["owl_%s.png" % _mmss(g.clock), (b.flock[0] as Unit).position, 1.3])
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
	var b = _ai.btc if _ai else null
	var ok := 0
	if b != null:
		for k in b.kill_log:
			ok += int(k[2])
	_min_lines.append("%s | CW winders %d earned %d bank %d T %d supply %d/%d army %d %s | flock %s owls %d sorties %d owl-kills %d | %s workers %d (lost %d) earned %d army %d | killed %d lost %d" % [
		_mmss(g.clock), g.worker_count(0), int(g.stats[0]["gold"]), int(g.players[0]["gold"]), int(g.tension(0)), g.supply_used(0),
		int(g.players[0]["cap"]), _army_val(0), str(kinds), (b.phase if b and b.launched else "-"), (b.flock.size() if b else 0),
		(b.sorties if b else 0), ok, vs, g.worker_count(1), op_lost, int(g.stats[1]["gold"]), _army_val(1),
		int(g.stats[0]["value_killed"]), int(g.stats[1]["value_killed"])])
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
		var at := _flock_at()
		if at != Vector2.INF:
			cam.position = cam.position.lerp(at, 0.3)
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
		if _ai.btc != null:
			for k in _ai.btc.kill_log:
				e.store_line("owl kill %s %s %d" % [_mmss(float(k[0])), String(k[1]), int(k[2])])
	e.store_line("winner %s at %s; %s workers lost %d" % [str(g.winner) if g.over else "none", _mmss(g.clock), vs, op_lost])
	e.close()
	quit(0)
