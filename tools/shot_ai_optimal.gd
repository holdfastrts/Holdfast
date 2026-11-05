extends SceneTree
## Pictures of the OPTIMAL plan and the reads (ai-optimal, docs/ai_optimal.md): a 1v1 computer match watched as a
## spectator, the AI STORY panel open on the OPTIMAL side, a picture a few seconds after each of its picks (its base) and
## after its first attack (its army), plus pictures at the given times.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_ai_optimal.gd -- \
##       a:crown sa:optimal b:brood sb:economy map:highmoor seed:1 out:/abs/dir [name:crown_v_brood] [end:420] [at:200,300] [lang:en]
## Writes <out>/<name>_pick_N.png, <name>_attack.png, <name>_MMSS.png.
var main: Node
var out := "/tmp/ai_optimal_shots"
var name_ := "game"
var fa := "crown"
var fb := "brood"
var sa := "optimal"
var sb := "economy"
var map := "highmoor"
var seed_ := 1
var end_t := 420.0
var ats: Array = []
var lang := "en"
var story_team := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"name": name_ = kv[1]
			"a": fa = kv[1]
			"b": fb = kv[1]
			"sa": sa = kv[1]
			"sb": sb = kv[1]
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"end": end_t = float(kv[1])
			"lang": lang = kv[1]
			"at":
				for x in kv[1].split(","):
					ats.append(float(x))
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	Loc.set_lang(lang)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.render_loop_enabled = false
	_run.call_deferred()


func _run() -> void:
	await process_frame
	seed(seed_)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard", "faction": fa, "colour": 0, "side": 0, "strategy": sa},
		{"who": "hard", "faction": fb, "colour": 1, "side": 1, "strategy": sb}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	paused = false
	g.path_budget_us = 1 << 40
	if g.ai_story and g.ai_story.narrator:
		g.ai_story.narrator.fake = true
		g.ai_story.narrator.available = true
	if g.spectator:
		g.spectator.process_mode = Node.PROCESS_MODE_DISABLED
	var opt_ai: AI = null
	for a in g.ais:
		if a.opt != null:
			opt_ai = a
			story_team = a.team
	var picks_seen := 0
	var attack_done := false
	var pending: Array = []        # [clock, file, team, focus: "base" | "army"]
	while g.clock < end_t and not g.over:
		await process_frame
		if opt_ai != null and (opt_ai.opt.picks as Array).size() > picks_seen:
			picks_seen = (opt_ai.opt.picks as Array).size()
			pending.append([g.clock + 6.0, "%s_pick_%d.png" % [name_, picks_seen], story_team, "base"])
		if opt_ai != null and opt_ai._attacking and not attack_done:
			attack_done = true
			pending.append([g.clock + 15.0, "%s_attack.png" % name_, story_team, "army"])
		for t in ats.duplicate():
			if g.clock >= float(t):
				ats.erase(t)
				pending.append([g.clock, "%s_%02d%02d.png" % [name_, int(t) / 60, int(t) % 60], story_team, "base"])
		for p in pending.duplicate():
			if g.clock >= float(p[0]):
				pending.erase(p)
				await _shot(g, String(p[1]), int(p[2]), String(p[3]))
	_quit()


func _focus(g: Game, team: int, what: String) -> Vector2:
	if what == "army":
		var c := Vector2.ZERO
		var n := 0
		for u in g.army(team):
			if not u._k_nb or not (u.kind == BroodNew.QUEEN or BroodNew.rooted(u)):
				c += u.position
				n += 1
		if n > 0:
			return c / n
	if g.faction_of(team) == "brood":
		var q := BroodNew.queen(g, team)
		return q.position if q else g.center_of_team(team)
	var h: Building = g._own_hall(team)
	return h.global_position + Vector2(140, 40) if h else g.center_of_team(team)


func _shot(g: Game, file: String, team: int, what: String) -> void:
	var sp: SpecPanels = g.hud.spec_panels() if g.hud else null
	for p in SpecPanels.PANELS:
		SpecPanels.open[p] = p == "story" or p == "army"
		SpecPanels.team[p] = team if p == "story" else -1
	g.camera.position = _focus(g, team, what)
	g.camera.zoom = Vector2(0.75, 0.75)
	g.camera.reset_smoothing()
	if g.hud:
		g.hud._sig.clear()
		g.hud._redraw_t = 0.0
	RenderingServer.render_loop_enabled = true
	for i in 20:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(file))
	print("SHOT ", file, " at ", g.clock)
	RenderingServer.render_loop_enabled = false


func _quit() -> void:
	main._to_menu()
	quit(0)
