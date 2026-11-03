extends "res://tools/shot_ai_match.gd"
## COACHED, FILMED GAMES OF THE CLOCKWORK'S CLOCK SOLDIER RUSH AND TURRET TURTLE (cw-builds-a; scripts/ai_cw_builds_a.gd,
## docs/clockwork_builds_a.md), in the style of tools/play_clockwork_springer.gd. Side 0 is the Clockwork computer on the
## coached plan, side 1 the Crown or the Brood computer.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_clockwork_builds_a.gd -- \
##       coach:rush map:greenhold seed:11 out:/abs/dir [foe:crown|brood] [end:600] [db:hard] [sb:balanced] [set:rush=6]
##   python3 -I tools/play_brood_new_gif.py /abs/dir          (the clip frames into a GIF)
## Everything of tools/shot_ai_match.gd plus:
##   <out>/minutes.txt  a line a minute: Winders, cogs earned (both sides), bank, supply, the army, the rush's phase and
##                      party, turrets, the enemy's workers and their losses, value killed and lost
##   <out>/events.txt   the plan's decisions (AIClockwork.sp_log) and the steps done, with the clock
##   key moments: rush_out_MMSS.png (the party with its Winders), arrive_MMSS.png (3 s after it reaches the base),
##   fight_rush_MMSS.png (12 s after), verdict_MMSS.png, turret_MMSS.png (each turret 8 s after it stands),
##   base_turtle_MMSS.png (the main, the turrets and the second Clocktower when the 2nd turret stands), clip_arrive_NN.png
## Variants (`coach:`): rush, turtle (the plans as written), oldrush (the shared computer's old Rush plan),
## balanced (the shared Balanced), or any of them with `set:key=value,...` (plan settings, e.g. set:rush=6).

const COACH := {
	"rush": {"strategy": "cs_rush", "set": {}},
	"turtle": {"strategy": "turtle", "set": {}},
	"oldrush": {"strategy": "rush", "set": {}},
	"balanced": {"strategy": "balanced", "set": {}},
}

var coach_plan := "rush"
var sb := "balanced"
var foe_fac := "crown"
var sets := {}
var _ai = null
var _min_lines: Array = []
var _next_min := 60.0
var _logged := 0
var _events: Array = []
var _foe_seen := {}
var foe_lost := 0
var _clips: Array = []
var _shots_t := {}
var _turret_seen := {}
var _base_shot := false


func _initialize() -> void:
	super._initialize()
	fa = "clockwork"
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"coach": coach_plan = kv[1]
			"sb": sb = kv[1]
			"foe": foe_fac = kv[1]
			"set":
				for pair in kv[1].split(","):
					var p := pair.split("=", true, 1)
					if p.size() == 2:
						sets[p[0]] = str_to_var(p[1]) if str_to_var(p[1]) != null else p[1]
	fb = foe_fac


func _process(delta: float) -> bool:
	if main.game == null:
		t += delta
		if t > 0.2:
			seed(seed_)
			var c: Dictionary = COACH.get(coach_plan, COACH["rush"])
			main.start({"map": map, "seed": seed_, "slots": [
				{"who": da, "faction": "clockwork", "colour": 0, "side": 0, "strategy": String(c["strategy"])},
				{"who": db, "faction": foe_fac, "colour": 1, "side": 1, "strategy": sb}]})
			for a in main.game.ais:
				if a.team == 0 and a is AIClockwork:
					_ai = a
					var o: Dictionary = (c["set"] as Dictionary).duplicate(true)
					for k in sets:
						o[k] = sets[k]
					if a.bo_on and not o.is_empty():
						a.over = o
						a._make_plan()
					print("COACH variant %s: strategy %s, forced %s" % [coach_plan, String(c["strategy"]), str(o.keys())])
		return false
	g = main.game
	if g.hud and g.hud.countdown > 0.0:
		g.hud.countdown = 0.0
	if paused:
		paused = false
	g.reveal = true          # (the camera sees everything; the computer only what its side sees)
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


func _party_c(b) -> Vector2:
	if b == null or b.party.is_empty():
		return Vector2.INF
	return b._centre(b.party)


func _coach() -> void:
	if Engine.get_physics_frames() % 10 == 0:
		var alive := {}
		for u in g.units:
			if u.team == 1 and not u.dead and u.is_worker():
				alive[u.get_instance_id()] = true
		for id in _foe_seen:
			if not alive.has(id):
				foe_lost += 1
		_foe_seen = alive
		for b in g.buildings:
			if b.team == 0 and not b.dead and b.built and b.kind == "ratchet_turret" and not _turret_seen.has(b):
				_turret_seen[b] = g.clock
				_later.append([g.clock + 8.0, "turret_%s.png" % _mmss(g.clock), b])
		if not _base_shot and _turret_seen.size() >= 2:
			_base_shot = true
			var h: Building = g._own_hall(0)
			if h:
				var tc := Vector2.ZERO
				for b in _turret_seen:
					if is_instance_valid(b):
						tc += b.center()
				tc /= _turret_seen.size()
				pending.append(["base_turtle_%s.png" % _mmss(g.clock), h.center().lerp(tc, 0.5), 0.7])
	if _ai == null:
		return
	var bt = _ai.get("bta")
	while _logged < _ai.sp_log.size():
		var e: Array = _ai.sp_log[_logged]
		_logged += 1
		var line := "%s %s" % [_mmss(float(e[0])), String(e[1])]
		_events.append(line)
		print("EV " + line)
		var s := String(e[1])
		var pc := _party_c(bt)
		if s.begins_with("rush: marching") and pc != Vector2.INF:
			_shot("rush_out", pc, 1.1)
		elif s.begins_with("rush: at the") and pc != Vector2.INF:
			_later.append([g.clock + 3.0, "arrive_%s.png" % _mmss(g.clock), bt.party[0]])
			_later.append([g.clock + 12.0, "fight_rush_%s.png" % _mmss(g.clock), bt.party[0]])
			if not _shots_t.has("clip_arrive"):
				_shots_t["clip_arrive"] = g.clock
				_clips.append(["arrive", pc, 40, 6, 1.2])
		elif (s.begins_with("rush: FAILED") or s.begins_with("rush: SUCCEEDED")) and pc != Vector2.INF:
			_shot("verdict", pc, 1.1)
		elif s.begins_with("rush: ") and s.contains("fresh Clock Soldiers join") and pc != Vector2.INF:
			_shot("reinforce", pc, 1.1, 30.0)
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
	var bt = _ai.get("bta") if _ai else null
	var tur := g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and not b.dead and b.built and b.kind == "ratchet_turret").size()
	_min_lines.append("%s | CW winders %d earned %d bank %d supply %d/%d army %d %s turrets %d | rush %s party %d | foe workers %d (lost %d) earned %d army %d | killed %d lost %d" % [
		_mmss(g.clock), g.worker_count(0), int(g.stats[0]["gold"]), int(g.players[0]["gold"]), g.supply_used(0),
		int(g.players[0]["cap"]), _army_val(0), str(kinds), tur, (bt.phase + "/" + bt.verdict if bt and bt.launched else "-"),
		(bt.party.size() if bt else 0), g.worker_count(1), foe_lost, int(g.stats[1]["gold"]), _army_val(1),
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
	var bt = _ai.get("bta") if _ai else null
	for i in int(c[2]):
		for k in int(c[3]):
			await process_frame
		if i == 0:
			for k in 6:
				await process_frame
		var pc := _party_c(bt)
		if pc != Vector2.INF:
			cam.position = cam.position.lerp(pc, 0.3)
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
	if _ai and _ai.get("step_log") != null:
		for s in _ai.step_log:
			e.store_line("step %s done at %s" % [String(s["step"]), _mmss(float(s["at"]))])
	e.store_line("winner %s at %s; foe workers lost %d" % [str(g.winner) if g.over else "none", _mmss(g.clock), foe_lost])
	e.close()
	quit(0)
