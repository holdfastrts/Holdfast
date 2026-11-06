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
var every := 120.0              # (ai-followups) `every:60`: a line per side every so many seconds
var diag := false               # (ai-followups) `diag:1`: the Crown's labourer and army gold every 10 s (to stdout)
var _diag_t := 0.0
var _fw_t := 0.0
var _wave_seen := {}            # (ai-followups) team -> true: where the Crown's line stood when the first enemy wave came
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
			"every": every = float(kv[1])
			"diag": diag = kv[1] == "1"
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
	_first_wave()
	if diag and g.clock >= _diag_t:
		_diag_t += 10.0
		_diag()
	if g.clock >= next_line:
		next_line += every
		for tm in 2:
			lines.append(_side_line(tm))
	if g.over or g.clock >= end_t:
		_finish()
		return true
	return false


## (ai-followups) THE FIRST ENEMY WAVE at a Crown side: armed enemies worth WAVE_V or more within 500 px of its buildings
## (its main's high ground excepted: by its walls, its natural); where its musket line stands then: on the main's high
## ground, within 260 px of a palisade or gate of its own, or elsewhere.
const WAVE_V := 300.0


func _first_wave() -> void:
	if g.clock < _fw_t:
		return
	_fw_t = g.clock + 1.0
	for tm in 2:
		if g.faction_of(tm) != "crown" or _wave_seen.has(tm):
			continue
		var a := _ai(tm)
		if a == null:
			continue
		var foe := 1 - tm
		var v := 0.0
		var at := Vector2.ZERO
		var n := 0
		for u in g.army(foe):
			if u.dead or u.off_field or u.is_worker() or not u.has_attack():
				continue
			var near := false
			for b in g.buildings:
				if b.team == tm and not b.dead and b.center().distance_to(u.position) < 500.0:
					near = true
					break
			if near:
				v += float(Game.unit_value(u))
				at += u.position
				n += 1
		if v < WAVE_V:
			continue
		_wave_seen[tm] = true
		var walls: Array = g.buildings.filter(func(b: Building) -> bool: return b.team == tm and not b.dead and (b.kind == "wall" or b.kind == "gate"))
		var high := 0
		var by_wall := 0
		var other := 0
		for u in g.army(tm):
			if u.dead or not Defs.MUSKETS.has(u.kind):
				continue
			if a.ch.on_main(u.position):
				high += 1
			elif walls.any(func(b: Building) -> bool: return b.center().distance_to(u.position) < 260.0):
				by_wall += 1
			else:
				other += 1
		lines.append("%s P%d FIRSTWAVE enemy %d at %s: muskets %d by its palisade, %d on the main's high ground, %d elsewhere; gate post %s" % [_mmss(g.clock), tm + 1,
			int(v), str(Vector2i(at / maxf(1.0, n) / Defs.TILE)), by_wall, high, other, str(a.ch.gate_live())])


func _diag() -> void:
	for tm in 2:
		var a := _ai(tm)
		if a == null or g.faction_of(tm) != "crown":
			continue
		var q := 0
		for h in a._halls():
			q += h.queue.size()
		print("DIAG %s P%d gold %d res %d bo_res %d bo_i %d/%d done %s labs %d q %d cap %d posts %d army %d sup %d/%d lags %s" % [_mmss(g.clock), tm + 1,
			int(g.players[tm]["gold"]), int(a._reserve), int(a.bo_reserve), int(a.bo_i), (a._bo_plan as Array).size(), str(a.bo_done),
			g.workers(tm).size(), q, int(a.owner_lab_cap()), int(a._posts()), _army_value(tm), g.supply_used(tm), int(g.players[tm]["cap"]),
			str(a.army_lags()) if a.has_method("army_lags") else "-"])


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
