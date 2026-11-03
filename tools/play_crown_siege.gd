extends "res://tools/play_crown_1.gd"
## THE SIEGE PUSH, COACHED AND FILMED (crown-builds-b, docs/crown_builds_b.md): tools/play_crown_1.gd on the "siege" plan
## (scripts/ai_crown_siege.gd), with the push watched:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_crown_siege.gd -- \
##       b:clockwork sb:economy map:greenhold seed:3 out:/abs/dir [end:780] [coach:balanced]
## Everything of play_crown_1 plus:
##   push_out_MMSS.png        the push leaving (and clip_push frames: python3 -I tools/play_brood_new_gif.py <out>)
##   push_set_MMSS.png        the push set up against a defence (8 s after: the guns unlimbered behind the line)
##   push_fire_MMSS.png       the guns at work (20 s after it set up)
##   push_back_MMSS.png       the push falling back; push_end_MMSS.png when it is over
##   siege.txt                one line a push: when it left, its supply and guns, what it broke, killed / lost, why it ended
##                            + the 4/6/8-minute economy for the round's table (tools/play_crown_siege_table.py)
var _sg_seen := 0
var econ := {}
var _later_p: Array = []         # [clock, file]: a picture of the push set up, when it is due                 # minute -> [labourers, gold earned so far, army value]


func _initialize() -> void:
	super._initialize()
	if not Array(OS.get_cmdline_user_args()).any(func(x: String) -> bool: return x.begins_with("coach:")):
		coach_plan = "siege"
	if not Array(OS.get_cmdline_user_args()).any(func(x: String) -> bool: return x.begins_with("end:")):
		end_t = 780.0


func _coach() -> void:
	super._coach()
	for m in [240, 360, 480, 600]:
		if not econ.has(m) and g.clock >= float(m):
			econ[m] = [g.workers(0).size(), int(g.stats[0]["gold"]), g.army_value(0), g.army_value(1)]
	var sg: AICrownSiege = _ai.siege
	if sg == null:
		return
	# (the pictures of a set-up: between the push's middle and what it shoots at, when they are due)
	for i in range(_later_p.size() - 1, -1, -1):
		if g.clock >= float(_later_p[i][0]):
			var e: Array = _later_p[i]
			_later_p.remove_at(i)
			if sg.state != "" and not sg.men.is_empty():
				var m: Vector2 = sg._mid(sg.men.keys())
				var at: Vector2 = (m + sg.anchor_p) * 0.5 if sg.anchor_p != Vector2.INF else m
				pending.append([e[1], at, 0.9])
	while _sg_seen < sg.log.size():
		var e: Array = sg.log[_sg_seen]
		_sg_seen += 1
		var text := String(e[1])
		say("siege: " + text)
		var any: Unit = null
		for u in sg.men.keys():
			if is_instance_valid(u) and not u.dead:
				any = u
				break
		if text.begins_with("goes out"):
			if any:
				shot("push_out", any, 1.0, 5.0)
				clip("push_%d" % sg.pushes.size(), any, 30, 6, 1.0)
		elif text.begins_with("sets up") and sg.anchor_p != Vector2.INF:
			var mid := (sg.anchor_p + sg._mid(sg.men.keys())) * 0.5 if not sg.men.is_empty() else sg.anchor_p
			_later_p.append([g.clock + 8.0, "push_set_%s.png" % _mmss(g.clock)])
			_later_p.append([g.clock + 20.0, "push_fire_%s.png" % _mmss(g.clock)])
		elif text.begins_with("falls back") and any:
			shot("push_back", any, 1.0, 10.0)
		elif text.begins_with("is over"):
			shot("push_end", _home(), 0.9, 10.0)


func _minute() -> void:
	super._minute()
	var sg: AICrownSiege = _ai.siege if _ai else null
	if sg == null:
		return
	var guns := sg._guns().size()
	minutes[-1] = String(minutes[-1]) + " | push %s (%d men, %d guns)" % [sg.state if sg.state != "" else "home", sg.men.size(), guns]


func _finish() -> void:
	super._finish()
	var f := FileAccess.open(out.path_join("siege.txt"), FileAccess.WRITE)
	f.store_line("map %s seed %d vs %s %s (%s); result %s at %s" % [map, seed_, fb, sb, db, _result(), _mmss(g.clock)])
	for m in [240, 360, 480, 600]:
		if econ.has(m):
			var e: Array = econ[m]
			f.store_line("econ %d labourers %d gold %d army %d enemy_army %d" % [m / 60, e[0], e[1], e[2], e[3]])
	f.store_line("total killed %d lost %d" % [int(g.stats[0]["value_killed"]), int(g.stats[1]["value_killed"])])
	if _ai and _ai.siege:
		var sg: AICrownSiege = _ai.siege
		if not sg.cur.is_empty() and float(sg.cur.get("end", -1.0)) < 0.0:
			sg.cur["killed"] = int(g.stats[0]["value_killed"]) - sg._kill_base
			sg.cur["lost"] = int(g.stats[1]["value_killed"]) - sg._loss_base
			sg.cur["why"] = "still out at the end"
		for p in sg.pushes:
			f.store_line("push t0 %s sup %d guns %d cannons %d line %d value %d end %s why [%s] killed %d lost %d broke %s sets %d" % [
				_mmss(float(p["t0"])), int(p["sup"]), int(p["guns"]), int(p["cannons"]), int(p["line"]), int(p["value"]),
				_mmss(float(p["end"])) if float(p["end"]) >= 0.0 else "-", String(p["why"]), int(p.get("killed", -1)), int(p.get("lost", -1)),
				JSON.stringify(p["broke"]), int(p.get("sets", 0))])
	f.close()


func _result() -> String:
	if not g.over:
		return "alive"
	var w = g.get("winner")
	return "W" if str(w) == "0" else "L (winner %s)" % str(w)
