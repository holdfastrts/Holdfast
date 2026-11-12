extends SceneTree
## BROOD MIRROR FILM (brood-v-brood-coach, docs/brood-v-brood-coach.md): two Brood computers, filmed and logged for a
## coach to read. A measuring tool only: it starts a normal match and looks at it; it changes no rule.
##   xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 30 --script res://tools/shot_brood_mirror.gd -- \
##       map:greenhold seed:1 out:/abs/dir [end:900] [sa:optimal] [sb:optimal] [shots:1] [every:30] [diff:hard]
## Writes <out>/lines.txt (every `every` s, per side: food, spoils, income, supply, grubs, army by kind, the Mother's stage,
## health and rooting, rooted Sires / Rootmaws / turtles, attacking, wave, defence, value killed / lost),
## <out>/story.txt (both computers' own lines, AIBroodNew.say), <out>/log.txt (the match log), <out>/result.txt,
## and pictures (shots:1): over_<MMSS>.png (the whole map) and mother_<side>_<MMSS>.png every 60 s, fight_<MMSS>.png
## (a fight of 4+ creatures a side, at most every 20 s), mother_hit_<side>_<MMSS>.png (a Mother below 70% health).
const FIGHT_GAP := 20.0
const NEAR := 230.0
var main: Node
var g: Game
var map := "greenhold"
var seed_ := 1
var out := "/tmp/brood_mirror"
var end_t := 900.0
var sa := "optimal"
var sb := "optimal"
var diff := "hard"
var fa := "brood"                # fa:/fb: the factions (the other matchups' check batches: the same lines, no Mother)
var fb := "brood"
var shots := true
var every := 30.0
var t := 0.0
var next_line := 0.0
var next_over := 0.0
var next_fight := 0.0
var last_fight := -999.0
var lines: Array = []
var pending: Array = []
var shooting := false
var _hit_shot := {}
var _notes_n := {}
var story: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"out": out = kv[1]
			"end": end_t = float(kv[1])
			"sa": sa = kv[1]
			"sb": sb = kv[1]
			"diff": diff = kv[1]
			"shots": shots = kv[1] == "1"
			"every": every = float(kv[1])
			"fa": fa = kv[1]
			"fb": fb = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.render_loop_enabled = false


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var slots: Array = []
		var plans := [sa, sb]
		for i in 2:
			slots.append({"who": diff, "faction": [fa, fb][i], "colour": i, "side": i, "strategy": plans[i]})
		main.start({"map": map, "seed": seed_, "slots": slots})
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
	var c: float = g.clock
	_story()
	if c >= next_line:
		next_line = c + every
		for tm in 2:
			lines.append(_line(c, tm))
	if shots:
		if c >= next_over:
			next_over = c + 60.0
			var mid := Vector2(g.W, g.H) * Defs.TILE * 0.5
			var z := minf(1152.0 / (g.W * Defs.TILE), 648.0 / (g.H * Defs.TILE))
			pending.append(["over_%s.png" % _mmss(c), mid, z])
			for tm in 2:
				var q := BroodNew.queen(g, tm)
				if q:
					pending.append(["mother_%d_%s.png" % [tm, _mmss(c)], q.position, 0.7])
		if c >= next_fight:
			next_fight = c + 2.0
			_look_for_fight(c)
		for tm in 2:
			var q := BroodNew.queen(g, tm)
			if q and q.hp < q.max_hp * 0.7 and c - float(_hit_shot.get(tm, -999.0)) > 45.0:
				_hit_shot[tm] = c
				pending.append(["mother_hit_%d_%s.png" % [tm, _mmss(c)], q.position, 0.9])
	if g.over or c >= end_t:
		_finish()
		return true
	return false


func _ai(tm: int):
	for a in g.ais:
		if a.team == tm:
			return a
	return null


func _story() -> void:
	for a in g.ais:
		var n: Array = a.get("note") if a.get("note") is Array else []
		var k := int(_notes_n.get(a.team, 0))
		for i in range(k, n.size()):
			story.append("%s P%d %s" % [_mmss(float(n[i][0])), a.team, str(n[i][1])])
		_notes_n[a.team] = n.size()


func _line(c: float, tm: int) -> String:
	var kinds := {}
	var grubs := 0
	var army_v := 0
	var rooted: Array = []
	var eggs := 0
	for u in g.units:
		if not is_instance_valid(u) or u.dead or u.team != tm:
			continue
		if u.kind == BroodNew.EGG:
			eggs += 1
			continue
		if u.is_worker():
			grubs += 1
			continue
		if BroodNew.ROOTERS.has(u.kind) and BroodNew.rooted(u):
			if u.kind != BroodNew.QUEEN:
				rooted.append(u.kind.left(4))
			continue
		if u.kind == BroodNew.QUEEN:
			continue
		kinds[u.kind] = int(kinds.get(u.kind, 0)) + 1
		army_v += Game.unit_value(u)
	var q := BroodNew.queen(g, tm)
	var qs := "dead"
	if q:
		qs = "stage %d hp%d/%d %s" % [BroodNew.stage(q) + 1, int(q.hp), int(q.max_hp), "rooted" if BroodNew.rooted(q) else "UP"]
	var st: Dictionary = g.stats[tm]
	var a = _ai(tm)
	var ai_s := "-"
	if a:
		var wv = a.get("_wave")
		var df = a.get("_def")
		ai_s = "plan %s att %s wave %d def %d attack_at %d seen_army %d" % [a.strategy, str(a.get("_attacking")), (wv as Array).size() if wv is Array else -1,
			(df as Array).size() if df is Array else -1, int(a.get("_attack_at")) if a.get("_attack_at") != null else -1, int(a.get("seen_army")) if a.get("seen_army") != null else -1]
	return "%s P%d food %d spoils %d income %d sup %d/%d grubs %d eggs %d armyv %d %s | mother %s | rooted %s | killed %d lost %d | %s" % [
		_mmss(c), tm, int(g.players[tm]["gold"]), int(g.players[tm]["res2"]), int(st["gold"]), g.supply_used(tm),
		int(g.players[tm]["cap"]), grubs, eggs, army_v, str(kinds), qs, ",".join(rooted), int(st["value_killed"]), int(st["lost"]), ai_s]


func _mmss(c: float) -> String:
	return "%02d%02d" % [int(c) / 60, int(c) % 60]


func _look_for_fight(c: float) -> void:
	if c - last_fight < FIGHT_GAP:
		return
	var army: Array = []
	for u in g.units:
		if is_instance_valid(u) and not u.dead and not u.is_worker() and u.kind != BroodNew.EGG and u.kind != BroodNew.PILE \
				and not (BroodNew.ROOTERS.has(u.kind) and BroodNew.rooted(u)):
			army.append(u)
	var best := 0
	var at := Vector2.ZERO
	for u in army:
		var mine := 0
		var theirs := 0
		for o in army:
			if o.position.distance_to(u.position) < NEAR:
				if o.team == u.team:
					mine += 1
				else:
					theirs += 1
		var s := mini(mine, theirs)
		if s > best:
			best = s
			at = u.position
	if best >= 4:
		last_fight = c
		pending.append(["fight_%s.png" % _mmss(c), at, 1.0])


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
	_story()
	for tm in 2:
		lines.append(_line(g.clock, tm))
	_save("lines.txt", lines)
	_save("story.txt", story)
	var ll: Array = []
	if g.mlog:
		for l in g.mlog.lines:
			ll.append(str(l))
	_save("log.txt", ll)
	_save("result.txt", ["over %s winner %s clock %.0f map %s seed %d" % [str(g.over), str(g.winner), g.clock, map, seed_]])


func _save(name: String, list: Array) -> void:
	var f := FileAccess.open(out.path_join(name), FileAccess.WRITE)
	for l in list:
		f.store_line(str(l))
	f.close()
