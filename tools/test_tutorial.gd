extends SceneTree
## THE TUTORIAL (docs/tutorial.md): every lesson's data checks out (Campaign.problems) and has its Portuguese and
## Spanish, the lessons never show in the CAMPAIGN, the TUTORIAL button sits next to CAMPAIGN; then every lesson is
## PLAYED: for each step the test does what the player would (moves the view, selects, orders, places buildings with
## the game's own calls, lays eggs, roots creatures...), lets the match run (fast) and checks that the step is done
## before the next one starts; the lesson ends won, its tick is saved and the list shows it. The practice games are
## started and their hints checked, and won by destroying the computer.
##   godot --headless --fixed-fps 30 --script res://tools/test_tutorial.gd [-- only=<lesson id>]
## Prints CHECK lines, then "tutorial: N failures"; exit code 1 on a failure. (Leaves user://tutorial.json as it was.)
var main: Node
var fails := 0
var _kept := ""
var only := ""
var g: Game
var r: MissionRun


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://running.txt"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	if FileAccess.file_exists(Tutorial.PROGRESS):
		_kept = FileAccess.get_file_as_string(Tutorial.PROGRESS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.PROGRESS))
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _finish() -> void:
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.PROGRESS))
	if _kept != "":
		var f := FileAccess.open(Tutorial.PROGRESS, FileAccess.WRITE)
		f.store_string(_kept)
		f.close()
	print("tutorial: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _data() -> void:
	var ids := Tutorial.lesson_ids()
	check("lessons listed", ids.size() >= 7, str(ids))
	var texts: Array = Tutorial.index_strings()
	for id in ids:
		var m := Campaign.mission(id)
		var pr := Campaign.problems(m)
		check("lesson %s: data checks out" % id, pr.is_empty(), "; ".join(pr))
		check("lesson %s: is a tutorial, solo" % id, bool(m.get("tutorial", false)) and Campaign.modes_of(m) == ["solo"])
		check("lesson %s: not in the campaign" % id, not Campaign.mission_ids().has(id))
		texts.append_array(Campaign.strings_of(m))
		for st in m.get("steps", []):
			var n := 0
			for ln in st.get("say", []):
				var t := String(ln.get("pc", ln.get("text", ""))) if ln is Dictionary else String(ln)
				n = maxi(n, t.split(" ").size())
			check("lesson %s step %s: short lines (%d words at most 32)" % [id, st.get("id", "?"), n], n <= 32)
	texts.append_array(["TUTORIAL", "START LESSON", "LESSON DONE", "TRY AGAIN", "NEXT LESSON", "YOU WILL LEARN", "LESSON", "Next: %s",
		"Lesson done. Play it again any time.", "Every soldier loses a battle. Try it again."])
	var miss: Array = []
	for t in texts:
		if not LangPt.T.has(t) or not LangEs.T.has(t):
			miss.append(String(t).left(50))
	check("every tutorial text has pt and es", miss.is_empty(), " | ".join(miss))


# ------------------------------------------------------------------ playing a lesson

func _start(id: String) -> void:
	TutorialMenu.start(main, id)
	await process_frame
	await process_frame
	paused = false
	g = main.game
	r = g.mission
	paused = false


## Run the match until the step `sid` is done (its trigger fired), up to `secs` of game time. Lines are skipped as
## a reader would (NEXT).
func _until_done(sid: String, secs := 60.0) -> bool:
	var t0 := g.clock
	var ui := _ui()
	while not r.fired.has("done_" + sid) and g.clock - t0 < secs and not g.over:
		if ui and not ui.queue.is_empty():
			ui.skip_all()
		await physics_frame
	return r.fired.has("done_" + sid)


## Wait for a step to have started (its lines said).
func _until_started(sid: String, secs := 30.0) -> bool:
	var t0 := g.clock
	while not r.fired.has("start_" + sid) and g.clock - t0 < secs and not g.over:
		await physics_frame
	return r.fired.has("start_" + sid)


func _ui() -> MissionUi:
	for n in main.ui_layer.get_children():
		if n is MissionUi:
			return n
	return null


func _mine(kind: String) -> Array:
	return g.units.filter(func(u) -> bool: return u.team == g.human and not u.dead and u.kind == kind)


func _my_b(kind: String) -> Array:
	return g.buildings.filter(func(b) -> bool: return b.team == g.human and not b.dead and b.kind == kind)


func _area_mid(a: String) -> Vector2:
	return r.area_rect(a).get_center()


## Play a lesson: `acts` maps a step id to what the player does there (a Callable, awaited); steps without one are
## only read. Each step must start, then be done after the action.
func _play(id: String, acts: Dictionary, secs := {}) -> void:
	await _start(id)
	check("%s: started" % id, g != null and r != null and r.id == id)
	for st in r.data.get("steps", []):
		var sid := String(st["id"])
		var ok := await _until_started(sid, 40.0)
		check("%s: step %s starts" % [id, sid], ok)
		if not ok:
			return
		if st.has("task"):
			check("%s: step %s shows its task" % [id, sid], r.obj.get("task_" + sid, "") == "active")
		if not r.fired.has("done_" + sid):
			var early: bool = r.cond(st.get("wait", {"talked": true})) and st.has("wait")
			check("%s: step %s not done before the player acts" % [id, sid], not early or bool(st.get("free", false)))
		if acts.has(sid):
			await acts[sid].call()
		ok = await _until_done(sid, float(secs.get(sid, 90.0)))
		check("%s: step %s done" % [id, sid], ok, "" if ok else "(waiting for %s)" % JSON.stringify(st.get("wait", {})))
		if not ok:
			return
	var t0 := g.clock
	while not g.over and g.clock - t0 < 10.0:
		await physics_frame
	check("%s: the lesson is won" % id, g.over and r.winner_side == r.my_side(), "%s %s" % [g.over, r.winner_side])
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	await create_timer(1.6).timeout
	Engine.time_scale = ts
	check("%s: LESSON DONE shows" % id, main.ui_layer.find_child("LessonEnd", true, false) != null)
	check("%s: ticked" % id, Tutorial.done(id))
	main._to_menu()
	await process_frame


# ------------------------------------------------------------------ the lessons

func _basics() -> void:
	var press_hold := func() -> void:
		g.set_selection(r.tagged("recruits"))
		for u in r.tagged("recruits"):
			u.cmd_hold()
	await _play("t01_basics", {
		"camera": func() -> void: g.camera.position += Vector2(400, 0),
		"zoom": func() -> void: g.camera.zoom *= 1.3,
		"select_one": func() -> void: g.set_selection([r.tagged("recruits")[0]]),
		"select_all": func() -> void: g.set_selection(r.tagged("recruits")),
		"move": func() -> void: g.smart_command(r.tagged("recruits"), _area_mid("flag")),
		"attack": func() -> void: g.group_move(r.tagged("recruits"), _area_mid("targets"), true),
		"card": press_hold,
		"minimap": func() -> void: g.hud._minimap_to(g.hud.mini_rect().get_center()),
		"group_set": func() -> void:
			g.set_selection(r.tagged("recruits"))
			g.hud.bar.group_do(0, "set"),
		"group_select": func() -> void:
			g.set_selection([])
			g.hud.bar.group_do(0, ""),
	}, {"move": 60.0, "attack": 90.0})


## Place a building as the player does (BUILD, then a click): the game's own spot finder near the hall picks the
## cell, the given workers go and build it. Returns the site (null: nothing placed, with a FAIL).
func _build(kind: String, workers: Array, near: Building = null, lo := 3, hi := 14) -> Building:
	if near == null:
		near = _my_b(g.faction_hall(g.human))[0]
	var c := g.find_spot(g.human, kind, near, lo, hi)
	var b: Building = g.place_building(g.human, kind, c, workers) if c.x >= 0 else null
	check("placed a %s" % kind, b != null, "at %s, gold %s, problem '%s'" % [c, g.players[g.human]["gold"], g.placement_problem(g.human, kind, c) if c.x >= 0 else "no spot"])
	return b


## Train as the player does (the card's button), waiting for the price as a player would (up to 60 s of game time).
func _train(kind: String, from: String, n := 1) -> void:
	for i in n:
		var why := "?"
		var t0 := g.clock
		while why != "" and g.clock - t0 < 60.0:
			why = g.train(_my_b(from)[0], kind)
			if why != "":
				await physics_frame
		if why != "":
			check("train a %s" % kind, false, why)


func _idle_workers(kind: String, n: int) -> Array:
	var ws := _mine(kind)
	ws.sort_custom(func(a, b) -> bool: return (a.order == "idle") and not (b.order == "idle"))
	return ws.slice(0, n)


func _crown() -> void:
	var lab := func(n: int) -> Array: return _idle_workers("labourer", n)
	await _play("t10_crown", {
		"hall": func() -> void: g.set_selection(r.tagged("hall")),
		"labourer": func() -> void: await _train("labourer", "town_hall"),
		"cottage": func() -> void: _build("cottage", lab.call(2)),
		"mill": func() -> void: _build("powder_mill", lab.call(2)),
		"mill_crew": func() -> void:
			for u in lab.call(3):
				u.cmd_gather(_my_b("powder_mill")[0]),
		"barracks": func() -> void: _build("barracks", lab.call(2)),
		"musketeers": func() -> void: await _train("musketeer", "barracks", 3),
		"wall": func() -> void:
			var ws: Array = lab.call(2)
			var a := Vector2i(7, 19)
			var b := Vector2i(9, 19)
			var n := g.place_line(g.human, "wall", a, b, ws)
			check("laid a palisade across the ramp", n >= 3, str(n))
			var gt := g.place_building(g.human, "gate", Vector2i(8, 19), ws)
			check("put a gate in it", gt != null, g.placement_problem(g.human, "gate", Vector2i(8, 19))),
		"foundry": func() -> void: _build("foundry", lab.call(2)),
		"cannon": func() -> void: await _train("cannon", "foundry"),
		"ridge": func() -> void: g.group_move(_mine("musketeer"), _area_mid("ridge"), false),
	}, {"cottage": 120.0, "mill": 120.0, "barracks": 150.0, "foundry": 160.0, "cannon": 150.0, "wall": 120.0, "raid": 120.0, "mill_crew": 60.0})


func _clockwork() -> void:
	var wind := func(kind: String, n: int) -> void:
		# n Winders onto the building of `kind` with the fewest (taken from wherever they are, the busiest first)
		var bs := _my_b(kind)
		bs.sort_custom(func(a, b) -> bool: return a.crew.size() < b.crew.size())
		var site: Building = bs[0]
		var ws := _mine("winder").filter(func(u) -> bool: return not site.crew.has(u))
		ws.sort_custom(func(a, b) -> bool: return a.order == "idle" and b.order != "idle")
		for u in ws.slice(0, maxi(0, n - site.crew.size())):
			u.cmd_gather(site)
	await _play("t20_clockwork", {
		"tower": func() -> void: g.set_selection(r.tagged("tower")),
		"winder": func() -> void: await _train("winder", "clocktower"),
		"gear_view": func() -> void: g.toggle_gear_view(),
		"gear_view_off": func() -> void: g.toggle_gear_view(),
		"press": func() -> void: _build("cog_press", _idle_workers("winder", 1)),
		"press_crew": func() -> void: wind.call("cog_press", 2),
		"mainspring": func() -> void: _build("mainspring", _idle_workers("winder", 1)),
		"tension": func() -> void: wind.call("mainspring", 2),
		"works": func() -> void: _build("movement_works", _idle_workers("winder", 1)),
		"soldiers": func() -> void: await _train("clock_soldier", "movement_works", 2),
	}, {"press": 150.0, "mainspring": 150.0, "works": 160.0, "tension": 90.0, "press_crew": 60.0})


## A spot where a grub may turn into `k` (BroodRoot.place_problem says ""), searched outward from `around`.
func _root_spot(k: String, around: Vector2, gr: Unit, reach := 14) -> Vector2:
	for rad in range(0, reach + 1):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if maxi(absi(dx), absi(dy)) != rad:
					continue
				var p := BroodRoot.feet_at(k, g.cell_of(around) + Vector2i(dx, dy))
				if BroodRoot.place_problem(g, g.human, k, p, gr) == "":
					return p
	return Vector2.INF


## BUILD on a grub's card, the creature picked and placed: the grub walks there and morphs (the HUD's own order).
func _morph(k: String, around: Vector2, reach := 14) -> void:
	var gr: Unit = _idle_workers("grub", 1)[0]
	var p := _root_spot(k, around, gr, reach)
	check("a spot for a %s" % k, p.is_finite(), "near %s: %s" % [g.cell_of(around), BroodRoot.place_problem(g, g.human, k, BroodRoot.feet_at(k, g.cell_of(around)), gr)])
	if p.is_finite():
		gr.give({"o": "nb_morph", "k": k, "p": p})


func _brood() -> void:
	var q := func() -> Unit: return BroodNew.queen(g, g.human)
	await _play("t30_brood", {
		"mother": func() -> void: g.set_selection([q.call()]),
		"eggs": func() -> void:
			var why := BroodNew.lay(g, q.call(), "grub")
			check("the Mother lays a grub egg", why == "", why),
		"turtle": func() -> void: _morph("mound_turtle", _area_mid("natural")),
		"rootmaw": func() -> void:
			var t: Unit = _mine("mound_turtle")[0]
			var t0 := g.clock
			while g.clock - t0 < 30.0 and not _root_spot("rootmaw", t.position, null, 9).is_finite():
				await physics_frame          # (the turtle's swamp spreads)
			_morph("rootmaw", t.position, 9),
		"rootmaw_crew": func() -> void:
			var maws := _mine("rootmaw").filter(func(u) -> bool: return WorkerLabels.workers(g, u).size() < 2)
			if not maws.is_empty():
				var new_maw: Unit = maws[0]
				var free := _mine("grub").filter(func(gr) -> bool: return gr.home_mine != new_maw)
				for gr in free.slice(0, 2 - WorkerLabels.workers(g, new_maw).size()):
					gr.cmd_gather(new_maw),
		"sire": func() -> void: _morph("tyrannosaur", q.call().position, 12),
		"raptors": func() -> void:
			var why := BroodNew.lay(g, q.call(), "raptor")
			check("the Mother lays a Raptor egg", why == "", why),
	}, {"turtle": 150.0, "rootmaw": 150.0, "sire": 160.0, "raptors": 120.0})


## A practice game: an Easy computer plays, the hints follow what you do, and it ends as a skirmish does (the enemy
## wiped out: a win, the lesson ticked; your own side wiped out: TRY AGAIN, no tick).
func _practice(id: String, worker: String, more_workers: Callable) -> void:
	await _start(id)
	check("%s: started, with a computer" % id, r != null and g.ais.size() == 1, str(g.ais.size()))
	check("%s: the computer is Easy" % id, not g.ais.is_empty() and g.ais[0].difficulty == 0)
	var ok := await _until_started("start", 20.0)
	check("%s: the first hint" % id, ok and r.said_ids.size() >= 2)
	await more_workers.call()
	ok = await _until_done("start", 90.0)
	check("%s: the first hint is done once you have more %ss" % [id, worker], ok)
	ok = await _until_started("build", 20.0)
	check("%s: then the next hint" % id, ok)
	await _until_done("never", 20.0)
	check("%s: not over while the enemy stands" % id, not g.over)
	# the enemy falls: everything of theirs destroyed
	var foe := r.team_index("foe")
	for b in g.buildings.duplicate():
		if b.team == foe and not b.dead:
			b.take_damage(9999999.0, null)
	for u in g.units.duplicate():
		if u.team == foe and not u.dead:
			u.die()
	var t0 := g.clock
	while not g.over and g.clock - t0 < 10.0:
		await physics_frame
	check("%s: the enemy wiped out: won" % id, g.over and g.winner == g.human, "%s %s" % [g.over, g.winner])
	Engine.time_scale = 1.0
	await create_timer(1.6).timeout
	Engine.time_scale = 4.0
	check("%s: LESSON DONE, ticked" % id, main.ui_layer.find_child("LessonEnd", true, false) != null and Tutorial.done(id))
	check("%s: the battle report is offered" % id, main.ui_layer.find_child("End_BATTLE_REPORT", true, false) != null)
	main._to_menu()
	await process_frame


func _menu_checks() -> void:
	main.show_menu()
	await process_frame
	await process_frame
	var b: Dictionary = main.menu_buttons
	check("menu: TUTORIAL and CAMPAIGN side by side", b.has("tutorial") and b.has("campaign") and absf(b["tutorial"].position.y - b["campaign"].position.y) < 1.0)
	b["tutorial"].pressed.emit()
	await process_frame
	await process_frame
	for id in Tutorial.lesson_ids():
		check("the list has %s" % id, main.menu.find_child("Lesson_" + id, true, false) != null)
	check("the list has START LESSON", main.menu.find_child("Lesson_Start", true, false) != null)
	main.show_campaign()
	await process_frame
	CampaignMenu.war_table(main)
	await process_frame
	var leak := false
	for id in Tutorial.lesson_ids():
		leak = leak or main.menu.find_child("Mission_" + id, true, false) != null
	check("no lesson on the CAMPAIGN's war table", not leak)


func _run() -> void:
	await process_frame
	_data()
	await _menu_checks()
	Engine.time_scale = 4.0
	if only == "" or only == "t01_basics":
		await _basics()
		# the list shows the tick, and picks the next lesson not done
		main.show_tutorial()
		await process_frame
		var tick = main.menu.find_child("Tick_t01_basics", true, false)
		check("the list ticks a finished lesson", tick != null and tick.on)
		check("the list picks the next lesson not done", TutorialMenu.pick == "t10_crown", TutorialMenu.pick)
		TutorialMenu.pick = ""
	if only == "" or only == "t10_crown":
		await _crown()
	if only == "" or only == "t20_clockwork":
		await _clockwork()
	if only == "" or only == "t30_brood":
		await _brood()
	if only == "" or only == "practice":
		await _practice("t19_crown_practice", "labourer", func() -> void: await _train("labourer", "town_hall", 3))
		await _practice("t29_clockwork_practice", "winder", func() -> void: await _train("winder", "clocktower", 3))
		await _practice("t39_brood_practice", "grub", func() -> void:
			for i in 3:
				var why := "?"
				var t0 := g.clock
				while why != "" and g.clock - t0 < 60.0:
					why = BroodNew.lay(g, BroodNew.queen(g, g.human), "grub")
					if why != "":
						await physics_frame)
		# a practice game lost: TRY AGAIN, no tick
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.PROGRESS))
		await _start("t19_crown_practice")
		for b in g.buildings.duplicate():
			if b.team == g.human and not b.dead:
				b.take_damage(9999999.0, null)
		var t0 := g.clock
		while not g.over and g.clock - t0 < 10.0:
			await physics_frame
		check("practice lost: over, the computer won", g.over and g.winner != g.human, "%s %s" % [g.over, g.winner])
		Engine.time_scale = 1.0
		await create_timer(1.6).timeout
		Engine.time_scale = 4.0
		check("practice lost: TRY AGAIN, no tick", main.ui_layer.find_child("LessonEnd", true, false) != null and not Tutorial.done("t19_crown_practice"))
		main._to_menu()
		await process_frame
	Engine.time_scale = 1.0
	_finish()
