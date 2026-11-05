extends SceneTree
## THE OPTIMAL PLAN COACHED (ai-optimal, docs/ai_optimal.md): one computer against another, headless (or filmed with
## xvfb and shots:1), measured for the report:
##   godot --headless --fixed-fps 30 --script res://tools/play_ai_optimal.gd -- a:crown sa:optimal b:brood sb:economy \
##       map:highmoor seed:1 end:900 out:/abs/dir [da:hard db:hard] [shots:1]
## Writes <out>/log.txt (the match log), <out>/story.txt (the AI STORY lines of both computers: the match log's lines the
## phrase book turns into narrator sentences), <out>/result.txt: one line per 2 minutes per side (income earned, workers,
## army value, halls), the reads and OPTIMAL's picks, and the end ("winner" team or "none" at the end time).
## shots:1 (with xvfb-run and --rendering-driver opengl3) also saves pick_MMSS.png at each OPTIMAL pick (its base) and
## attack_MMSS.png at the first attack of each side.
var main: Node
var g: Game
var fa := "crown"
var fb := "brood"
var sa := "optimal"
var sb := "economy"
var map := "highmoor"
var seed_ := 1
var end_t := 900.0
var out := "/tmp/ai_optimal"
var da := "hard"
var db := "hard"
var shots := false
var t := 0.0
var next_line := 120.0
var lines: Array = []
var pending: Array = []
var shooting := false
var _picks_seen := {}
var _att_seen := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"a": fa = kv[1]
			"b": fb = kv[1]
			"sa": sa = kv[1]
			"sb": sb = kv[1]
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"end": end_t = float(kv[1])
			"out": out = kv[1]
			"da": da = kv[1]
			"db": db = kv[1]
			"shots": shots = kv[1] == "1"
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0
	if shots:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.render_loop_enabled = false


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": da, "faction": fa, "colour": 0, "side": 0, "strategy": sa},
			{"who": db, "faction": fb, "colour": 1, "side": 1, "strategy": sb}]})
		return false
	if main.game == null:
		return false
	g = main.game
	g.path_budget_us = 1 << 40
	if g.hud:
		g.hud.visible = false
	if g.spectator and g.spectator.process_mode != Node.PROCESS_MODE_DISABLED:
		g.spectator.process_mode = Node.PROCESS_MODE_DISABLED
	if g.controls and g.controls.process_mode != Node.PROCESS_MODE_DISABLED:
		g.controls.process_mode = Node.PROCESS_MODE_DISABLED
	if shooting:
		return false
	if not pending.is_empty():
		_shoot()
		return false
	_watch()
	if g.clock >= next_line:
		next_line += 120.0
		for tm in 2:
			lines.append(_side_line(tm))
	if g.over or g.clock >= end_t:
		_finish()
		return true
	return false


func _ai(tm: int) -> AI:
	for a in g.ais:
		if a.team == tm:
			return a
	return null


func _mmss(c: float) -> String:
	return "%d:%02d" % [int(c) / 60, int(c) % 60]


func _army_value(tm: int) -> int:
	var v := 0
	for u in g.army(tm):
		if not u._k_nb or not (u.kind == BroodNew.QUEEN or BroodNew.rooted(u)):
			v += Game.unit_value(u)
	return v


func _side_line(tm: int) -> String:
	var a := _ai(tm)
	var halls := g.halls_of(tm).size() if g.faction_of(tm) != "brood" else 1 + (BroodNew.expansions(g, BroodNew.queen(g, tm)).size() if BroodNew.queen(g, tm) else 0)
	return "%s P%d %s %s (%s): income %d | workers %d | army %d | halls %d | supply %d" % [_mmss(g.clock), tm + 1, g.faction_of(tm),
		a.plan_key() if a else "?", a.strategy if a else "?", int(g.stats[tm]["gold"]), g.workers(tm).size(), _army_value(tm), halls, g.supply_used(tm)]


func _watch() -> void:
	for tm in 2:
		var a := _ai(tm)
		if a == null:
			continue
		if a.opt != null:
			var n: int = (a.opt.picks as Array).size()
			if int(_picks_seen.get(tm, 0)) < n:
				_picks_seen[tm] = n
				if shots:
					var h := g._own_hall(tm) if g.faction_of(tm) != "brood" else null
					var at: Vector2 = h.global_position if h else (BroodNew.queen(g, tm).position if BroodNew.queen(g, tm) else g.center_of_team(tm))
					pending.append(["pick_P%d_%s.png" % [tm + 1, _mmss(g.clock).replace(":", "")], at, 0.75])
		if a._attacking and not _att_seen.has(tm):
			_att_seen[tm] = g.clock
			if shots:
				var c := Vector2.ZERO
				var n2 := 0
				for u in g.army(tm):
					c += u.position
					n2 += 1
				if n2 > 0:
					pending.append(["attack_P%d_%s.png" % [tm + 1, _mmss(g.clock).replace(":", "")], c / n2, 0.8])


func _shoot() -> void:
	shooting = true
	var p: Array = pending.pop_front()
	var cam: Camera2D = g.camera
	cam.position = p[1]
	cam.zoom = Vector2(p[2], p[2])
	cam.reset_smoothing()
	RenderingServer.render_loop_enabled = true
	for i in 4:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(p[0]))
	RenderingServer.render_loop_enabled = false
	shooting = false


func _finish() -> void:
	var f := FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)
	var story := FileAccess.open(out.path_join("story.txt"), FileAccess.WRITE)
	if g.mlog:
		for l in g.mlog.lines:
			f.store_line(str(l))
			var line := str(l)
			for tm in 2:
				var who: String = g.mlog.who(tm)
				var i := line.find(who)
				if i < 0 or i > 12:
					continue
				var rest := line.substr(i + who.length())
				rest = rest.strip_edges(true, false) if not rest.begins_with("'s ") else rest
				var m := AIStoryLines.match_line(rest)
				if not m.is_empty() and String(m["template"]) != "" and int(m["prio"]) >= 2:
					var args: Array = ["P%d %s" % [tm + 1, g.faction_of(tm).capitalize()]] + (m["args"] as Array)
					var tpl := String(m["template"])
					story.store_line("%s %s" % [line.substr(0, 7), tpl % args if tpl.count("%s") == args.size() else tpl])
	f.close()
	story.close()
	for tm in 2:
		lines.append(_side_line(tm))
	var r := FileAccess.open(out.path_join("result.txt"), FileAccess.WRITE)
	r.store_line("map %s seed %d: P1 %s %s v P2 %s %s" % [map, seed_, fa, sa, fb, sb])
	for l in lines:
		r.store_line(l)
	for tm in 2:
		var a := _ai(tm)
		if a == null:
			continue
		var rd: Array = []
		if a.scout != null:
			rd = a.scout.reads
		elif "reads" in a:
			rd = a.reads
		for x in rd:
			r.store_line("P%d read %s %s [%s]" % [tm + 1, _mmss(float(x[0])), AIRead.word(String(x[1])), String(x[2])])
		if a.opt != null:
			for p in a.opt.picks:
				r.store_line("P%d pick %s %s %s -> %s (%s)" % [tm + 1, _mmss(float(p[0])), String(p[1]), String(p[2]), String(p[3]), String(p[4])])
		if _att_seen.has(tm):
			r.store_line("P%d first attack %s" % [tm + 1, _mmss(float(_att_seen[tm]))])
	r.store_line("end %s winner %s" % [_mmss(g.clock), ("P%d" % (g.winner + 1)) if g.over and g.winner >= 0 else "none"])
	r.close()
	print("done ", out)
