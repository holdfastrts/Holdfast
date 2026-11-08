extends SceneTree
## QA UI (docs/qa_2026_11_08_ui.md): press EVERY button of every menu page, one at a time, the page shown fresh before
## each press. Prints "== PRESS <page> <n> '<text>' -> <what happened>" so a SCRIPT ERROR in the log can be traced
## to the button; a press that starts a match is followed by a return to the menu. EXIT is not pressed.
##   godot --headless --fixed-fps 30 --script res://tools/qa_ui_press_all.gd [-- pc|mobile]
var main
var pages := {}
var dead: Array = []


var saved_cfg := ""


func _initialize() -> void:
	if FileAccess.file_exists(Settings.PATH):
		saved_cfg = FileAccess.get_file_as_string(Settings.PATH)       # (put back at the end: the flags get pressed)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://running.txt"))
	Settings.load_all()
	var a := OS.get_cmdline_user_args()
	Settings.device = a[0] if not a.is_empty() else "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	pages = {
		"menu": func() -> void: main.show_menu(),
		"device": func() -> void: main.show_device(),
		"settings_gameplay": func() -> void: main.show_settings("GAMEPLAY"),
		"settings_display": func() -> void: main.show_settings("DISPLAY"),
		"settings_sound": func() -> void: main.show_settings("SOUND"),
		"settings_experimental": func() -> void: main.show_settings("EXPERIMENTAL"),
		"settings_other": func() -> void: main.show_settings("OTHER"),
		"patch_notes": func() -> void: main.show_patch_notes(true),
		"music": func() -> void: main.show_music(),
		"layout": func() -> void: main.show_layout(),
		"anim_viewer": func() -> void: main.show_anim_viewer(),
		"help": func() -> void: main.show_help(),
		"lobby_1v1": func() -> void:
			main._preset("1v1")
			main.lobby["map"] = "random_1v1"
			main.show_skirmish(),
		"lobby_2v2": func() -> void:
			main._preset("2v2")
			main.lobby["map"] = "random_2v2"
			main.show_skirmish(),
		"online": func() -> void: main.show_online(),
		"replays": func() -> void: main.show_replays(),
		"editor_menu": func() -> void: main.show_editor_menu(),
		"logs": func() -> void: main.show_logs(),
		"campaign": func() -> void: main.show_campaign(),
		"tutorial": func() -> void: main.show_tutorial(),
		"map_editor": func() -> void: main.show_map_editor(),
	}
	_run.call_deferred()


func _buttons(n: Node, out: Array) -> void:
	for ch in n.get_children():
		if ch is BaseButton and (ch as Control).is_visible_in_tree() and not (ch as BaseButton).disabled:
			out.append(ch)
		_buttons(ch, out)


func _label(b: BaseButton) -> String:
	var t := ""
	if b is Button:
		t = (b as Button).text
	if t == "":
		t = b.tooltip_text if b.tooltip_text != "" else String(b.name)
	return t.replace("\n", " ").substr(0, 40)


func _run() -> void:
	await process_frame
	for page in pages:
		var show: Callable = pages[page]
		show.call()
		await process_frame
		var bs: Array = []
		_buttons(main, bs)
		var n := bs.size()
		print("== PAGE %s: %d buttons" % [page, n])
		for i in n:
			if main.game != null:
				main._to_menu()
				await process_frame
			show.call()
			await process_frame
			await process_frame
			var cur: Array = []
			_buttons(main, cur)
			if i >= cur.size():
				break
			var b: BaseButton = cur[i]
			var lbl := _label(b)
			if lbl in ["EXIT", "SAIR", "SALIR"] or String(b.name) == "Menu_exit":
				continue
			var hooked := false
			for sig in ["pressed", "toggled", "button_down", "button_up", "gui_input", "item_selected"]:
				if b.has_signal(sig) and not b.get_signal_connection_list(sig).is_empty():
					hooked = true
			if not hooked and not (b is OptionButton or b is MenuButton or b is CheckBox or b is CheckButton) and b.get_script() == null:
				print("   NO HANDLER %s %d '%s'" % [page, i, lbl])
			var before_id: int = main.menu.get_instance_id() if is_instance_valid(main.menu) else 0
			print("== PRESS %s %d '%s'" % [page, i, lbl])
			if b is OptionButton or b is MenuButton:
				b.pressed.emit()
			else:
				b.pressed.emit()
				if b.toggle_mode:
					b.toggled.emit(not b.button_pressed)
			await process_frame
			await process_frame
			var what := "same page"
			if main.game != null:
				what = "a match started"
			elif not is_instance_valid(main.menu) or main.menu.get_instance_id() != before_id:
				what = "new page"
			print("   -> %s" % what)
			# a popup opened by the press: closed again
			for w in root.get_children():
				if w is Window and w.visible and w != root:
					w.hide()
	print("PRESS-ALL DONE")
	if saved_cfg != "":
		var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		f.store_string(saved_cfg)
		f.close()
	quit()


## A script error stops _run where it is: never hang the test run (wall-clock time: --fixed-fps runs the game faster).
var _deadline := Time.get_ticks_msec() + 900000


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("WATCHDOG: gave up after 900 s")
		quit(2)
	return false
