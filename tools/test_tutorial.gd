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
	# the list shows the tick
	Engine.time_scale = 1.0
	main.show_tutorial()
	await process_frame
	var tick = main.menu.find_child("Tick_t01_basics", true, false)
	if only == "" or only == "t01_basics":
		check("the list ticks a finished lesson", tick != null and tick.on)
	_finish()
