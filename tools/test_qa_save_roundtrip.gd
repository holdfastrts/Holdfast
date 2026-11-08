extends SceneTree
## QA UI (docs/qa_2026_11_08_ui.md): does a saved match come back IDENTICAL? For each faction as the player (and a
## 3-player match with all three), a match plays a few minutes with the computers working, then SaveGame.capture()
## takes the whole state (A); it is CONTINUEd the way the main menu does (the save's cfg + "resume") and captured again
## at once (B). A and B are compared field by field (every unit, building, player bank, research, queue...): any
## difference is printed with its path. Then the reloaded match plays on 60 s.
##   godot --headless --fixed-fps 30 --script res://tools/test_qa_save_roundtrip.gd [-- secs:<n>]
## Prints CHECK lines and "save_roundtrip: N failures"; exit code 1 on a failure.
var main: Node
var fails := 0
var secs := 200.0
## keys whose value is about the moment of writing, not the match; "log" (the match log gains its "continued" line),
## a fertilising egg's "redden" and a Brood unit's "m" (worked out again from the save on the next tick / a copy of
## its mode)
const SKIP := ["time", "saved_at", "date", "mem", "ms", "log", "redden", "m", "mref"]


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-64s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("secs:"):
			secs = float(a.substr(5))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _wait(secs_: float) -> void:
	var g = main.game
	var c0: float = g.clock
	var n := 0
	while g.clock < c0 + secs_ and n < int(secs_ * 40) + 200:
		await process_frame
		n += 1


func _diff(a: Variant, b: Variant, path: String, out: Array) -> void:
	if out.size() > 25:
		return
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		if absf(float(a) - float(b)) > 0.011 * maxf(1.0, absf(float(a))):
			out.append("%s: %s -> %s" % [path, str(a), str(b)])
		return
	if typeof(a) != typeof(b):
		out.append("%s: type %s -> %s" % [path, type_string(typeof(a)), type_string(typeof(b))])
		return
	if a is Dictionary:
		for k in a:
			if String(k) in SKIP:
				continue
			if not b.has(k):
				out.append("%s.%s: missing after load" % [path, k])
			else:
				_diff(a[k], b[k], "%s.%s" % [path, k], out)
		for k in b:
			if not a.has(k) and not String(k) in SKIP:
				out.append("%s.%s: new after load (%s)" % [path, k, str(b[k]).substr(0, 60)])
	elif a is Array:
		if a.size() != b.size():
			out.append("%s: %d items -> %d" % [path, a.size(), b.size()])
		for i in mini(a.size(), b.size()):
			_diff(a[i], b[i], "%s[%d]" % [path, i], out)
	elif a != b:
		out.append("%s: %s -> %s" % [path, str(a).substr(0, 60), str(b).substr(0, 60)])


func _norm(d: Dictionary) -> Dictionary:
	# through JSON, as the file is: the same types on both sides; units and buildings in a fixed order (a reload may
	# list them in another order)
	var n: Dictionary = JSON.parse_string(JSON.stringify(d))
	for key in ["units", "buildings"]:
		if n.get(key) is Array:
			var arr: Array = n[key]
			arr.sort_custom(func(a, b) -> bool: return _sort_key(a) < _sort_key(b))
	return n


func _sort_key(e: Variant) -> String:
	if not e is Dictionary:
		return str(e)
	return "%s|%s|%s|%s" % [str(e.get("t", e.get("team", ""))), str(e.get("k", e.get("kind", ""))), str(e.get("c", "")), str(e.get("p", e.get("pos", "")))]


func _run() -> void:
	await process_frame
	var setups := [
		["crown", [{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]],
		["brood", [{"who": "you", "faction": "brood", "colour": 0, "side": 0},
			{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"}]],
		["clockwork", [{"who": "you", "faction": "clockwork", "colour": 0, "side": 0},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]],
		["three", [{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "optimal"},
			{"who": "hard", "faction": "brood", "colour": 2, "side": 2, "strategy": "optimal"}]],
	]
	for su in setups:
		var name: String = su[0]
		main.start({"map": "twin_crowns" if name == "three" else "ashford_crossing", "seed": 11, "slots": su[1]})
		await process_frame
		await process_frame
		paused = false
		await _wait(secs)
		var g = main.game
		var cfg: Dictionary = main.last_cfg.duplicate(true)
		cfg.erase("resume")
		var a := _norm(SaveGame.capture(g, cfg))
		main._autosave()
		var save := SaveGame.peek()
		check("%s: saved at %d:%02d" % [name, int(g.clock) / 60, int(g.clock) % 60], not save.is_empty())
		main._to_menu()
		await process_frame
		await process_frame
		var c2: Dictionary = save["cfg"].duplicate(true)
		c2["resume"] = save
		main.start(c2)
		await process_frame
		g = main.game
		var cfg2: Dictionary = main.last_cfg.duplicate(true)
		cfg2.erase("resume")
		var b := _norm(SaveGame.capture(g, cfg2))
		# a grub on its way to a paid morph is paid back on load (SaveGame: its order isn't kept): expected
		var refunds := {}
		for u in a.get("units", []):
			if u is Dictionary and u.get("mref") is Array:
				refunds[int(u["t"])] = int(refunds.get(int(u["t"]), 0)) + int(u["mref"][0])
		for t in refunds:
			a["players"][t]["gold"] = float(a["players"][t]["gold"]) + refunds[t]
		if not refunds.is_empty():
			print("    (paid morphs refunded on load: %s)" % str(refunds))
		var out: Array = []
		_diff(a, b, "save", out)
		check("%s: the reloaded match captures the same as the saved one" % name, out.is_empty(), "\n    " + "\n    ".join(out))
		var c0: float = g.clock
		await process_frame
		paused = false
		await _wait(60.0)
		check("%s: plays on 60 s" % name, main.game == g and g.clock > c0 + 55.0, "%.1f" % g.clock)
		main._to_menu()
		SaveGame.clear()
		await process_frame
	print("save_roundtrip: %d failures" % fails)
	quit(1 if fails else 0)


## A script error stops _run where it is: never hang the test run (wall-clock time: --fixed-fps runs the game faster).
var _deadline := Time.get_ticks_msec() + 1500000


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("WATCHDOG: gave up after 1500 s")
		quit(2)
	return false
