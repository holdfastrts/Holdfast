extends "res://tools/shot_ai_match.gd"
## clockwork-eco: a FILMED game of the Clockwork's Economy or Balanced opening (scripts/ai_cw_eco.gd), side 0 the Clockwork
## computer, side 1 the Crown or the Brood computer; for the pictures and the GIF of docs/clockwork_eco.md.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/film_clockwork_eco.gd -- \
##       cw:economy b:brood fp:economy map:cinder_steps seed:11 out:/abs/dir end:480 [gif:100-260:4] [at:240,480]
## Everything of tools/shot_ai_match.gd plus:
##   eco_MMSS.png      the main and the second Clocktower at each `at:` time (seconds)
##   rush_MMSS.png     5 s and 40 s after the plan saw rush evidence (its Light Works and soldiers)
##   gif_NN.png        the second Clocktower's spot from gif:<from>-<to>:<every> (seconds): its laying and its ring
##   events.txt        the plan's decisions (AIClockwork.sp_log)
var cw_plan := "economy"
var fp := "economy"
var gif_from := -1.0
var gif_to := -1.0
var gif_dt := 4.0
var at_list: Array = []
var _ai = null
var _gif_next := -1.0
var _gif_i := 0
var _hall2_at := Vector2.INF
var _rush_shot := false
var _logged := 0
var _events: Array = []


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
			main.start({"map": map, "seed": seed_, "slots": [
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


func _hall2() -> Vector2:
	for b in g.buildings:
		if b.team == 0 and not b.dead and b.kind == "clocktower" and b.cell != g.starts[0]:
			return b.center()
	if _ai != null and _ai._ck_pick.x >= 0:
		return (Vector2(_ai._ck_pick) + Vector2(2.5, 2.0)) * Defs.TILE
	return Vector2.INF


func _coach() -> void:
	if _ai != null:
		while _logged < _ai.sp_log.size():
			var e: Array = _ai.sp_log[_logged]
			_logged += 1
			_events.append("%s %s" % [_mmss(float(e[0])), String(e[1])])
			print("EV " + _events[-1])
		if not _rush_shot and _ai.bte != null and _ai.bte.rush:
			_rush_shot = true
			var h: Building = g._own_hall(0)
			_later.append([g.clock + 5.0, "rush_%s.png" % _mmss(g.clock + 5.0), h])
			_later.append([g.clock + 40.0, "rush_%s.png" % _mmss(g.clock + 40.0), h])
	var h2 := _hall2()
	if h2 != Vector2.INF:
		_hall2_at = h2
	if _gif_next >= 0.0 and g.clock >= _gif_next and g.clock <= gif_to:
		_gif_next += gif_dt
		var tgt: Vector2 = _hall2_at if _hall2_at != Vector2.INF else g._own_hall(0).center()
		pending.append(["gif_%03d.png" % _gif_i, tgt + Vector2(0, -10), 0.9])
		_gif_i += 1
	if not at_list.is_empty() and g.clock >= float(at_list[0]):
		var c := float(at_list.pop_front())
		var main_c: Vector2 = g._own_hall(0).center()
		var mid := main_c if _hall2_at == Vector2.INF else main_c.lerp(_hall2_at, 0.5)
		pending.append(["eco_%s.png" % _mmss(c), mid, 0.6])
	if g.clock >= end_t - 0.5 and _ai != null:
		var f := FileAccess.open(out.path_join("events.txt"), FileAccess.WRITE)
		f.store_string("\n".join(_events) + "\n")
		f.close()
