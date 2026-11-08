extends SceneTree
## QA of the screens a player clicks (docs/qa_2026_11_08_ui.md): every menu page, the skirmish setup, Settings' tabs,
## the in-game HUD of each faction, the in-game menu, a spectated match and the end screen, one language and one
## device at a time. For each screen it saves a picture and checks the Controls on it:
##  - CUT: a Label / Button whose text is wider than its box while it clips or trims (part of the words hidden);
##  - OFF: a visible text control reaching outside the window, not inside a scrolling or clipping parent;
##  - OVERLAP: two text controls covering each other (neither inside the other);
##  - SQUEEZED: a wrapping Label so narrow that it breaks words letter by letter;
##  - EN: English the translation tables don't have (Loc.track; pt/es only).
## The HUD's own drawing (hud.gd draw_string) is not a Control: only the pictures show it.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/qa_ui_audit.gd -- <outdir> <en|pt|es> <pc|mobile> [maps]
## Writes <outdir>/<tag>_<screen>.jpg and prints lines "QA <screen> <KIND> <detail>"; SCRIPT ERRORs land in the log
## between "== SCREEN <name>" lines.
var main
var out := ""
var tag := ""
var lang := "en"
var maps := false
var counts := {}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	lang = a[1]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://running.txt"))
	Settings.load_all()
	Settings.device = a[2]
	Settings.language = lang
	Loc.set_lang(lang)
	Settings.apply()
	maps = a.size() > 3 and a[3] == "maps"
	var vs := Vector2(DisplayServer.window_get_size())
	tag = "%s_%s_%dx%d" % [lang, a[2], int(vs.x), int(vs.y)]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _begin(name: String) -> void:
	print("== SCREEN ", name)
	Loc.misses.clear()


func _snap(name: String, wait := 0.5) -> void:
	await create_timer(wait).timeout
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s_%s.jpg" % [out, tag, name], 0.82)
	_audit(name)


func _report(name: String, kind: String, detail: String) -> void:
	print("QA %s %s %s" % [name, kind, detail])
	counts[kind] = counts.get(kind, 0) + 1


func _shown(c: Control) -> String:
	var t := ""
	if c is Label:
		t = (c as Label).text
	elif c is Button:
		t = (c as Button).text
	elif c is RichTextLabel:
		t = (c as RichTextLabel).get_parsed_text()
	if c.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED and not c is RichTextLabel:
		t = c.atr(t)
	return t


## The part of c's rect not hidden by a scrolling or clipping parent.
func _vis_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p != null and not (p is Window or p is CanvasLayer):
		if p is ScrollContainer or (p is Control and (p as Control).clip_contents):
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	return r


func _clipped_by_parent(c: Control) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer or (p is Control and (p as Control).clip_contents):
			return true
		if p is Window or p is CanvasLayer:
			break
		p = p.get_parent()
	return false


func _path(c: Node) -> String:
	var s := String(c.name)
	var p := c.get_parent()
	var n := 0
	while p != null and n < 3:
		s = String(p.name) + "/" + s
		p = p.get_parent()
		n += 1
	return s


func _audit(name: String) -> void:
	var vp := root.get_visible_rect()
	var texts: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if not n is Control:
			continue
		var c := n as Control
		if not c.is_visible_in_tree() or c.modulate.a < 0.05:
			continue
		if not (c is Label or c is Button or c is RichTextLabel):
			continue
		var t := _shown(c)
		if t.strip_edges() == "":
			continue
		var r := c.get_global_rect()
		if r.size.x < 1 or r.size.y < 1:
			continue
		texts.append(c)
		var f: Font = c.get_theme_font("font") if not c is RichTextLabel else c.get_theme_font("normal_font")
		var fs: int = c.get_theme_font_size("font_size") if not c is RichTextLabel else c.get_theme_font_size("normal_font_size")
		var one := t.replace("\n", " ").substr(0, 60)
		# CUT
		if c is Label:
			var l := c as Label
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF and (l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
				var w := 0.0
				for ln in t.split("\n"):
					w = maxf(w, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
				if w > r.size.x + 2:
					_report(name, "CUT", "%s '%s' text %d > box %d" % [_path(c), one, int(w), int(r.size.x)])
			elif l.autowrap_mode != TextServer.AUTOWRAP_OFF:
				var longest := 0.0
				for word in t.split(" ", false):
					longest = maxf(longest, f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
				if longest > r.size.x + 2 and t.length() > 3:
					_report(name, "SQUEEZED", "%s '%s' word %d > box %d" % [_path(c), one, int(longest), int(r.size.x)])
		elif c is Button:
			var b := c as Button
			var st: StyleBox = b.get_theme_stylebox("normal")
			var mx := 0.0
			if st:
				mx = st.get_margin(SIDE_LEFT) + st.get_margin(SIDE_RIGHT)
			var icon_w := 0.0
			if b.icon != null and not b.expand_icon:
				icon_w = b.icon.get_width() + b.get_theme_constant("h_separation")
			var w := 0.0
			for ln in t.split("\n"):
				w = maxf(w, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
			if (b.clip_text or b.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING) and b.autowrap_mode == TextServer.AUTOWRAP_OFF and w + mx + icon_w > r.size.x + 3:
				_report(name, "CUT", "%s button '%s' text %d > room %d" % [_path(c), one, int(w), int(r.size.x - mx - icon_w)])
		# OFF screen
		if not vp.grow(2).encloses(r) and not _clipped_by_parent(c):
			_report(name, "OFF", "%s '%s' rect %s" % [_path(c), one, str(r)])
	# OVERLAP between text controls
	for i in texts.size():
		var a: Control = texts[i]
		var ra := _vis_rect(a)
		for j in range(i + 1, texts.size()):
			var b: Control = texts[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var rb := _vis_rect(b)
			var x := ra.intersection(rb)
			if x.get_area() <= 0:
				continue
			var small := minf(ra.get_area(), rb.get_area())
			if x.get_area() > 0.25 * small and x.size.x > 6 and x.size.y > 6:
				_report(name, "OVERLAP", "'%s' x '%s'" % [_shown(a).replace("\n", " ").substr(0, 40), _shown(b).replace("\n", " ").substr(0, 40)])
	if lang != "en":
		for k in Loc.misses:
			_report(name, "EN", "'%s'" % String(k).replace("\n", "\\n").substr(0, 90))
	Loc.misses.clear()


func _run() -> void:
	Loc.track = true
	await process_frame
	_begin("device")
	main.show_device()
	await _snap("device")
	_begin("menu")
	main.show_menu()
	await _snap("menu")
	for t in main.SETTINGS_TABS:
		_begin("settings_" + t)
		main.show_settings(t)
		await _snap("settings_" + String(t).to_lower())
		# the tab's list scrolled to the bottom
		var sc: ScrollContainer = _first_scroll(main.menu)
		if sc != null and sc.get_v_scroll_bar().max_value > sc.size.y + 4:
			sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
			await _snap("settings_" + String(t).to_lower() + "_end", 0.2)
	_begin("patch_notes")
	main.show_patch_notes(true)
	await _snap("patch_notes")
	_begin("music")
	main.show_music()
	await _snap("music")
	_begin("layout")
	main.show_layout()
	await _snap("layout")
	_begin("anim_viewer")
	main.show_anim_viewer()
	await _snap("anim_viewer", 1.0)
	for k in main.HELP:
		_begin("help_" + k)
		main.show_help(k)
		await _snap("help_" + String(k).to_lower())
	for p in ["1v1", "2v2", "FFA", "1v3", "4v4"]:
		_begin("lobby_" + p)
		main._preset(p)
		main.lobby["map"] = main._preset_pool(p)
		main.show_skirmish()
		await _snap("lobby_" + p.to_lower())
	if maps:
		for mid in MapGen.all_ids():
			_begin("lobby_map_" + mid)
			var mode := MapGen.mode_of(mid)
			main._preset(mode if mode in ["1v1", "2v2", "3v3", "4v4"] else "1v1")
			main.lobby["map"] = mid
			main.show_skirmish()
			await _snap("lobby_map_" + mid, 0.25)
	_begin("online")
	main.show_online()
	await _snap("online")
	_begin("replays")
	main.show_replays()
	await _snap("replays")
	_begin("editor_menu")
	main.show_editor_menu()
	await _snap("editor_menu")
	_begin("logs")
	main.show_logs()
	await _snap("logs")
	_begin("campaign")
	main.show_campaign()
	await _snap("campaign", 1.0)
	_begin("tutorial")
	main.show_tutorial()
	await _snap("tutorial")
	_begin("map_editor")
	main.show_map_editor()
	await _snap("map_editor", 1.0)
	main.show_menu()
	await process_frame
	# ---- a match of each faction
	for fac in ["crown", "brood", "clockwork"]:
		_begin("match_" + fac)
		main.start({"map": "greenhold", "seed": 5, "slots": [
			{"who": "you", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "easy", "faction": "crown" if fac != "crown" else "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
		await process_frame
		await process_frame
		var g = main.game
		g.hud.countdown = 0.0
		paused = false
		Engine.time_scale = 6.0
		await create_timer(60.0 / 6.0, true, false, true).timeout
		Engine.time_scale = 1.0
		var halls = g.halls_of(g.human)
		if not halls.is_empty():
			g.camera.position = halls[0].center() + Vector2(120, -40)
			g.set_selection([halls[0]])
		await _snap("hud_%s_hall" % fac)
		var us = g.workers(g.human)
		if not us.is_empty():
			g.set_selection([us[0]])
			await _snap("hud_%s_worker" % fac)
			g.set_selection(us)
			await _snap("hud_%s_workers" % fac)
		g.hud.toggle_menu(true)
		await _snap("hud_%s_menu" % fac)
		g.hud.toggle_menu(false)
		g.hud.set_paused(true)
		await _snap("hud_%s_paused" % fac)
		g.hud.set_paused(false)
		if fac == "clockwork":
			g.over = true
			g._sample_stats()
			main._on_end(g.human)
			_begin("report")
			await _snap("report", 1.8)
		else:
			main._autosave()
			main._to_menu()
			await process_frame
			if fac == "crown":
				_begin("menu_continue")
				await _snap("menu_continue")
	# ---- a spectated match: the AI STORY and the panels
	main.show_menu()
	await process_frame
	_begin("spectate")
	main.start({"map": "twin_crowns", "seed": 7, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "optimal"},
		{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "optimal"},
		{"who": "normal", "faction": "brood", "colour": 2, "side": 2, "strategy": "rush"},
		{"who": "normal", "faction": "crown", "colour": 3, "side": 3, "strategy": "economy"}]})
	await process_frame
	await process_frame
	paused = false
	Engine.time_scale = 6.0
	await create_timer(90.0 / 6.0, true, false, true).timeout
	Engine.time_scale = 1.0
	await _snap("spectate")
	print("QA-SUMMARY %s %s" % [tag, str(counts)])
	quit()


func _first_scroll(n: Node) -> ScrollContainer:
	if n == null:
		return null
	for ch in n.get_children():
		if ch is ScrollContainer and (ch as ScrollContainer).is_visible_in_tree():
			return ch
		var s := _first_scroll(ch)
		if s != null:
			return s
	return null
