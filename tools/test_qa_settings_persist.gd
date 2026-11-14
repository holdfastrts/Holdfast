extends SceneTree
## QA UI (docs/qa_2026_11_08_ui.md): EVERY Settings row, through the page itself, on the computer and the phone:
## its control is used the way a player would (a button pressed, a slider moved, the relay address typed), and then
##  - something changes (the setting, the sound volume, or the page it opens);
##  - the change is in settings.cfg: the settings are read again from the file (Settings.load_all) and come back the
##    same; the volumes are read back by the music player's own loading;
##  - RESET (pressed twice) puts the choices back to how they start, and keeps language, device, relay and sound;
##  - the LANGUAGE flags switch the language, which is saved too.
## The player's settings file is put back at the end.
##   godot --headless --script res://tools/test_qa_settings_persist.gd
## Prints CHECK lines and "settings_persist: N failures"; exit code 1 on a failure.
var main
var fails := 0
var saved_cfg := ""
const OPENS := ["layout", "patch_notes", "anim_viewer", "music_player", "device"]
const SKIP := ["window_full", "fullscreen", "reset", "language"]     # (the display mode: tools/test_settings_tabs.gd under xvfb; reset and language below)


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-64s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	if FileAccess.file_exists(Settings.PATH):
		saved_cfg = FileAccess.get_file_as_string(Settings.PATH)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func snap() -> Dictionary:
	return {"device": Settings.device, "drag_mode": Settings.drag_mode, "fullscreen": Settings.fullscreen,
		"window_full": Settings.window_full, "ui_size": Settings.ui_size, "grid_keys": Settings.grid_keys,
		"tooltips": Settings.tooltips, "build_grid": Settings.build_grid, "area_marks": Settings.area_marks,
		"powder_smoke": Settings.powder_smoke, "expansion_spots": Settings.expansion_spots,
		"health_bars": Settings.health_bars, "charge_bars": Settings.charge_bars, "gear_turn": Settings.gear_turn,
		"ground_system": Settings.ground_system, "ground_nocap": Settings.ground_nocap, "ground_alpha": snappedf(Settings.ground_alpha, 0.01),
		"mini_alpha": snappedf(Settings.mini_alpha, 0.01), "overlay_alpha": snappedf(Settings.overlay_alpha, 0.01), "relay_url": Settings.relay_url, "language": Settings.language,
		"cw_lab": Settings.cw_lab, "replays_keep": Settings.replays_keep, "replay_rec": Settings.replay_rec,
		"narrator": Settings.narrator, "narrator_volume": Settings.narrator_volume,
		"narrator_rate": snappedf(Settings.narrator_rate, 0.01)}


func vols() -> Dictionary:
	var d := {}
	for w in ["music", "sound", "ambience"]:
		d[w] = [snappedf(Music.me.get_volume(w), 0.01), Music.me.is_muted(w)]
	return d


func reload() -> Dictionary:
	Settings._loaded = false
	Settings.load_all()
	return snap()


func diff(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for k in a:
		if a[k] != b.get(k):
			out.append("%s %s->%s" % [k, str(a[k]), str(b.get(k))])
	return out


func rows_of(tab: String) -> Dictionary:
	main.show_settings(tab)
	var d := {}
	var rows: Node = main.menu.find_child("Rows", true, false)
	if rows == null:
		return d
	for r in rows.get_children():
		if r.has_meta("setting"):
			d[String(r.get_meta("setting"))] = r
	return d


func _find(n: Node, cls: String) -> Node:
	for ch in n.get_children():
		if ch.is_class(cls) and (ch as CanvasItem).visible:
			return ch
		var f := _find(ch, cls)
		if f != null:
			return f
	return null


func _run() -> void:
	await process_frame
	for device in ["pc", "mobile"]:
		Settings.device = device
		Settings.save_all()
		for tab in main.SETTINGS_TABS:
			var ids: Array = rows_of(tab).keys()
			for id in ids:
				if id in SKIP:
					continue
				var row: Node = rows_of(tab).get(id)
				if row == null:
					continue
				var s0 := snap()
				var v0 := vols()
				var page0: Node = main.menu
				var what := ""
				var sl := _find(row, "HSlider") as HSlider
				var le := _find(row, "LineEdit") as LineEdit
				if sl != null:
					var nv := sl.min_value + 0.35 * (sl.max_value - sl.min_value)
					if absf(sl.value - nv) < sl.step:
						nv = sl.min_value + 0.7 * (sl.max_value - sl.min_value)
					sl.value = nv
					what = "slider"
				elif le != null:
					le.text = "wss://example.invalid/qa-" + device
					le.text_changed.emit(le.text)
					what = "typed"
				else:
					var b := _find(row, "Button") as Button
					if b == null:
						check("%s %s/%s: has a control" % [device, tab, id], false)
						continue
					b.pressed.emit()
					what = "pressed"
				await process_frame
				var s1 := snap()
				var v1 := vols()
				if id in OPENS:
					var opened: bool = main.menu != page0 and is_instance_valid(main.menu)
					if id == "layout":       # (the layout editor goes straight on the UI layer)
						opened = main.ui_layer.get_children().any(func(n: Node) -> bool: return n is LayoutEditor)
					check("%s %s/%s: %s opens its page" % [device, tab, id, what], opened)
					continue
				var ch := diff(s0, s1)
				var vch := diff(v0, v1)
				check("%s %s/%s: %s changes it" % [device, tab, id, what], not ch.is_empty() or not vch.is_empty(), str(ch + vch))
				if not ch.is_empty():
					var s2 := reload()
					check("%s %s/%s: saved (read back from settings.cfg)" % [device, tab, id], diff(s1, s2).is_empty(), str(diff(s1, s2)))
				if not vch.is_empty():
					await create_timer(1.0).timeout       # (the music player saves 0.6 s after the last change)
					var cfg := ConfigFile.new()
					cfg.load(Settings.PATH)
					# the volumes are kept by the music player in the [audio] section
					var fv := {}
					for w in ["music", "sound", "ambience"]:
						var vk: String = {"music": "music_vol", "sound": "sound_vol", "ambience": "amb_vol"}[w]
						fv[w] = [snappedf(float(cfg.get_value("audio", vk, -1.0)), 0.01), not bool(cfg.get_value("audio", w, true))]
					var ok := diff(v1, fv).is_empty()
					check("%s %s/%s: volume saved" % [device, tab, id], ok, str(diff(v1, fv)))
				# a toggle pressed twice comes back (no stuck setting)
				if what == "pressed" and not ch.is_empty():
					var row2: Node = rows_of(tab).get(id)
					var b2 := _find(row2, "Button") as Button if row2 else null
					if b2 != null and not id in ["replays_keep", "replay_rec", "ui_size", "powder_smoke", "narrator_rate"]:
						b2.pressed.emit()
						await process_frame
						check("%s %s/%s: pressed again, back as it was" % [device, tab, id], diff(s0, snap()).is_empty(), str(diff(s0, snap())))
	# ---- the language flags
	Settings.device = "pc"
	main.show_settings("GAMEPLAY")
	await process_frame
	var lang_row: Node = rows_of("GAMEPLAY").get("language")
	var flags: Array = []
	if lang_row:
		for n in lang_row.find_children("*", "BaseButton", true, false):
			flags.append(n)
	check("language: three flags", flags.size() == 3, str(flags.size()))
	if flags.size() == 3:
		(flags[1] as BaseButton).pressed.emit()
		await process_frame
		check("language: the second flag switches to Portuguese", Settings.language == "pt" and Loc.lang == "pt", Settings.language)
		check("language: saved", reload()["language"] == "pt")
		var lr2: Node = rows_of("GAMEPLAY").get("language")
		var fl2 := lr2.find_children("*", "BaseButton", true, false)
		(fl2[0] as BaseButton).pressed.emit()
		await process_frame
		check("language: back to English", Settings.language == "en" and Loc.lang == "en")
	# ---- RESET, armed then pressed
	Settings.tooltips = false
	Settings.ui_size = 150
	Settings.narrator_rate = 1.6
	Settings.relay_url = "wss://example.invalid/keep"
	Settings.save_all()
	var r := rows_of("OTHER").get("reset") as Node
	(_find(r, "Button") as Button).pressed.emit()
	await process_frame
	check("reset: the first press only arms it", not Settings.tooltips and Settings.ui_size == 150)
	r = rows_of("OTHER").get("reset")
	(_find(r, "Button") as Button).pressed.emit()
	await process_frame
	var s := reload()
	check("reset: choices back to the start, saved", s["tooltips"] == true and s["ui_size"] == 0 and is_equal_approx(float(s["narrator_rate"]), 1.1), str(s))
	check("reset: the relay address stays", s["relay_url"] == "wss://example.invalid/keep")
	# put the player's file back
	if saved_cfg != "":
		var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		f.store_string(saved_cfg)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	print("settings_persist: %d failures" % fails)
	quit(1 if fails else 0)


## A script error stops _run where it is: never hang the test run (wall-clock time: --fixed-fps runs the game faster).
var _deadline := Time.get_ticks_msec() + 300000


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("WATCHDOG: gave up after 300 s")
		quit(2)
	return false
