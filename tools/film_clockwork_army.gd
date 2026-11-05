extends "res://tools/shot_ai_match.gd"
## clockwork-army: a FILMED game of the Clockwork computer's one army (scripts/ai_cw_army.gd), side 0 the Clockwork computer,
## side 1 the Brood or the Crown computer; for the pictures and the GIF of docs/clockwork_army.md.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/film_clockwork_army.gd -- \
##       cw:economy b:brood fp:economy map:frostfang seed:11 out:/abs/dir end:600 [gif:300-420:3] [at:360,480] [cwarmy:off]
## Everything of tools/shot_ai_match.gd plus:
##   army_MMSS.png    the Clockwork's army at each `at:` time (seconds): framed on all its ground fighters (zoomed out to fit)
##   push_MMSS.png    the push 15 s after it goes out, and its fights (at most one every 25 s)
##   spring_MMSS.png  a second after Springers jump in
##   gif_NN.png       from gif:<from>-<to>:<every> (seconds): the army (the push when it is out), for the GIF
##   events.txt       the plan's and the army's decisions (AIClockwork.sp_log)
var cw_plan := "economy"
var fp := "economy"
var gif_from := -1.0
var gif_to := -1.0
var gif_dt := 3.0
var at_list: Array = []
var _ai = null
var _gif_next := -1.0
var _gif_i := 0
var _logged := 0
var _events: Array = []
var _push_n := 0
var _push_fight_t := -99.0
var _springs := 0


func _initialize() -> void:
	super._initialize()
	fa = "clockwork"
	shot_frames = 8
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"cw": cw_plan = kv[1]
			"fp": fp = kv[1]
			"gif":
				var p := kv[1].split(":")
				var r := p[0].split("-")
				gif_from = float(r[0])
				gif_to = float(r[1])
				if p.size() > 1:
					gif_dt = float(p[1])
				_gif_next = gif_from
			"at":
				for x in kv[1].split(","):
					at_list.append(float(x))


func _process(delta: float) -> bool:
	if main.game == null:
		t += delta
		if t > 0.2:
			seed(seed_)
			main.start({"map": map, "seed": seed_, "hidden_plans": true, "slots": [
				{"who": da, "faction": "clockwork", "colour": 0, "side": 0, "strategy": cw_plan},
				{"who": db, "faction": fb, "colour": 1, "side": 1, "strategy": fp}]})
			for a in main.game.ais:
				if a.team == 0 and a is AIClockwork:
					_ai = a
		return false
	g = main.game
	if g.hud and g.hud.countdown > 0.0:
		g.hud.countdown = 0.0
	if paused:
		paused = false
	g.reveal = true
	if not g.over and not shooting:
		_coach()
	return super._process(delta)


## The army's ground fighters: their middle and the zoom that fits them all (at most 0.35 out, at least 1.0 in).
func _army_frame() -> Array:
	var pts: Array = []
	for u in g.army(0):
		if not u.dead and not u.is_worker() and u.has_attack() and not u.is_air():
			pts.append(u.position)
	if pts.is_empty():
		return [g._own_hall(0).center() if g._own_hall(0) else Vector2.ZERO, 0.8]
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	var vs: Vector2 = root.get_viewport().get_visible_rect().size
	var z := minf(vs.x / maxf(1.0, r.size.x + 500.0), vs.y / maxf(1.0, r.size.y + 400.0))
	return [r.get_center(), clampf(z, 0.35, 1.0)]


func _push_at() -> Vector2:
	if _ai != null and _ai.push != null and _ai.push.phase != "" and _ai.push.phase != "back" and not _ai.push.units.is_empty():
		return _ai.push._front_centre()
	return Vector2.INF


func _coach() -> void:
	if _ai != null:
		while _logged < _ai.sp_log.size():
			var e: Array = _ai.sp_log[_logged]
			_logged += 1
			_events.append("%s %s" % [_mmss(float(e[0])), String(e[1])])
			print("EV " + _events[-1])
		if _ai.push != null and int(_ai.push.pushes) > _push_n:
			_push_n = int(_ai.push.pushes)
			_later.append([g.clock + 15.0, "push_%s.png" % _mmss(g.clock + 15.0), Vector2.INF])
		if _ai.push != null and _ai.push.phase == "fight" and g.clock - _push_fight_t > 25.0:
			_push_fight_t = g.clock
			pending.append(["push_%s.png" % _mmss(g.clock), _ai.push._front_centre(), 1.0])
		if _ai.get("army_g") != null and _ai.army_g != null and int(_ai.army_g.stats["springs"]) > _springs:
			_springs = int(_ai.army_g.stats["springs"])
			for u in g.army(0):
				if u.kind == Defs.SPRINGER and not (u.jump as Dictionary).is_empty():
					_later.append([g.clock + 0.6, "spring_%s.png" % _mmss(g.clock), u])
					break
	for i in range(_later.size() - 1, -1, -1):
		var e: Array = _later[i]
		if e[2] is Vector2 and e[2] == Vector2.INF and g.clock >= float(e[0]):
			_later.remove_at(i)
			var p := _push_at()
			if p != Vector2.INF:
				pending.append([e[1], p, 0.9])
	if _gif_next >= 0.0 and g.clock >= _gif_next and g.clock <= gif_to:
		_gif_next += gif_dt
		var p := _push_at()
		if p != Vector2.INF:
			pending.append(["gif_%03d.png" % _gif_i, p, 0.75])
		else:
			var f := _army_frame()
			pending.append(["gif_%03d.png" % _gif_i, f[0], maxf(0.6, float(f[1]))])
		_gif_i += 1
	if not at_list.is_empty() and g.clock >= float(at_list[0]):
		var c := float(at_list.pop_front())
		var f2 := _army_frame()
		pending.append(["army_%s.png" % _mmss(c), f2[0], f2[1]])
	if g.clock >= end_t - 0.5 and _ai != null:
		var fe := FileAccess.open(out.path_join("events.txt"), FileAccess.WRITE)
		fe.store_string("\n".join(_events) + "\n")
		fe.close()
