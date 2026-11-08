extends SceneTree
## qa-perf (0.33.8): memory over a play session: several computer matches one after another in ONE program (as a phone
## keeps the game open), each played `minutes` of game time, then left to the menu. After each, at the menu, the
## program's memory and the game's caches are printed: what a match leaves behind shows as growth from one match to the
## next (the same match played again should come back to the same level).
##
##   godot --headless --fixed-fps 60 --script res://tools/qa/mem_session.gd -- [minutes:4] [rounds:2]

var main: Node
var t := 0.0
var step := 0
var minutes := 4.0
var rounds := 2
var _menu_t := 0.0
var _phase := "boot"
var _i := 0
var PLAN := [
	["greenhold", "crown", "brood"],
	["ashfall", "clockwork", "clockwork"],
	["dune_sea", "brood", "crown"],
]


class SilentSfx extends Sfx:
	func _find(_name: String) -> Array:
		return []


func _initialize() -> void:
	Settings.load_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("plan:"):
			PLAN = [a.substr(5).split(",")]
		elif a.begins_with("minutes:"):
			minutes = float(a.substr(8))
		elif a.begins_with("rounds:"):
			rounds = int(a.substr(7))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.add_child(SilentSfx.new())


func _rss() -> float:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return -1.0
	while not f.eof_reached():
		var l := f.get_line()
		if l.begins_with("VmRSS:"):
			return float(l.split(":")[1].strip_edges().split(" ")[0]) / 1024.0
	return -1.0


func _report(what: String) -> void:
	var masks: int = OccludedLook._masks.size()
	var mask_mb := 0.0
	for k in OccludedLook._masks:
		var bm: BitMap = OccludedLook._masks[k]
		if bm != null:
			mask_mb += bm.get_size().x * bm.get_size().y / 8.0 / 1048576.0
	var tex_mb := 0.0
	for k in Game._tex_cache:
		var tx: Texture2D = Game._tex_cache[k]
		if tx != null:
			tex_mb += tx.get_width() * tx.get_height() * 4.0 / 1048576.0
	var by := {}
	for k in Game._tex_cache:
		var tx2: Texture2D = Game._tex_cache[k]
		if tx2 != null:
			var dir := String(k).get_base_dir().get_file()
			by[dir] = float(by.get(dir, 0.0)) + tx2.get_width() * tx2.get_height() * 4.0 / 1048576.0
	var ks := by.keys()
	ks.sort_custom(func(a, b) -> bool: return by[a] > by[b])
	print("MEM top textures: ", ", ".join(ks.slice(0, 12).map(func(k) -> String: return "%s %.1f MB" % [k, by[k]])))
	print("MEM %-34s rss %6.0f MB | static %6.0f MB | objects %6d nodes %5d resources %5d orphans %d | textures kept %4d (%.0f MB as RGBA) | masks %d (%.1f MB) | warm keep %d" % [
		what, _rss(), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		Game._tex_cache.size(), tex_mb, masks, mask_mb, ArtWarm._keep.size()])


func _process(delta: float) -> bool:
	t += delta
	match _phase:
		"boot":
			if t > 1.0:
				_report("at the menu, before any match")
				_start()
		"play":
			var g: Game = main.game
			if g != null:
				if g.hud:
					g.hud.countdown = 0.0
				paused = false
				if g.clock >= minutes * 60.0 or g.over:
					_report("in match %d (%s) at %d:%02d" % [_i + 1, " ".join(PLAN[_i % PLAN.size()]), int(g.clock) / 60, int(g.clock) % 60])
					main._to_menu()
					_phase = "menu"
					_menu_t = 0.0
		"menu":
			_menu_t += delta
			if _menu_t > 2.0:
				_report("menu after match %d" % (_i + 1))
				_i += 1
				if _i >= PLAN.size() * rounds:
					return true
				_start()
	return false


func _start() -> void:
	var p: Array = PLAN[_i % PLAN.size()]
	seed(4242)
	main.start({"map": p[0], "seed": 4242, "slots": [
		{"who": "hard", "faction": p[1], "colour": 0, "side": 0},
		{"who": "hard", "faction": p[2], "colour": 1, "side": 1}]})
	if main.game:
		main.game.path_budget_us = 1 << 40
	_phase = "play"
