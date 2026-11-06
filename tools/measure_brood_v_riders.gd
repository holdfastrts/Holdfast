extends SceneTree
## THE BROOD AGAINST THE HORSEMAN RUSH, MEASURED (brood-anti-riders, docs/brood_anti_riders.md): a Hard Crown on its
## Horseman rush (or OPTIMAL) against a Hard Brood (OPTIMAL or Economy), headless; one line of numbers:
##   godot --headless --fixed-fps 30 --script res://tools/measure_brood_v_riders.gd -- map:hollowfen seed:3233604515 \
##       sa:rush sb:optimal end:600 [out:/abs/file.txt] [log:/abs/log.txt]
## The numbers (the Brood is P2):
##   read    when the Brood read the riders (its rush evidence / rider read), "-" never
##   hit     when the first Crown rider came within 12 tiles of the Mother or a rooted creature of the Brood
##   gap     hit - read (s): the warning it had
##   lost    Brood units lost in the raid (from the hit to 2 minutes after), of them grubs
##   riders  Crown riders (Horsemen / Cuirassiers) killed by 8:00, and how many it trained by then
##   w5 w8   Brood workers (grubs) at 5:00 and 8:00
##   inc10   Brood food earned by 10:00 (and the Crown's gold)
##   army8   Brood army value at 8:00 (its mobile army)
##   end     winner and the clock
var main: Node
var g: Game
var map := "hollowfen"
var seed_ := 3233604515
var sa := "rush"
var sb := "optimal"
var end_t := 600.0
var out := ""
var log_path := ""
var t := 0.0
var bt := 1
var ct := 0
var hit_t := -1.0
var _alive := {}
var lost := 0
var lost_grubs := 0
var riders_dead := 0
var riders_made := {}
var w5 := -1
var w8 := -1
var army8 := -1
var inc10 := -1
var cinc10 := -1
var _sec := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"sa": sa = kv[1]
			"sb": sb = kv[1]
			"end": end_t = float(kv[1])
			"out": out = kv[1]
			"log": log_path = kv[1]
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": sa},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": sb}]})
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
	if g.clock >= _sec:
		_sec = g.clock + 0.5
		_watch()
	if g.over or g.clock >= end_t:
		_finish()
		return true
	return false


func _ai(tm: int) -> AI:
	for a in g.ais:
		if a.team == tm:
			return a
	return null


func _watch() -> void:
	var c := g.clock
	var q := BroodNew.queen(g, bt)
	# the Crown's riders: made, dead
	for u in g.units:
		if u.team == ct and not u.dead and AIBroodNew.is_rider(u) and not riders_made.has(u):
			riders_made[u] = c
		if u.team == bt and not u.dead and not _alive.has(u):
			_alive[u] = u.kind
	for u in riders_made.keys():
		if riders_made[u] is float and (not is_instance_valid(u) or u.dead):
			riders_made[u] = "dead"
			if c < 480.0:
				riders_dead += 1
	for u in _alive.keys():
		if not is_instance_valid(u) or u.dead:
			var k: String = _alive[u]
			_alive.erase(u)
			if hit_t >= 0.0 and c - hit_t <= 120.0 and k != BroodNew.EGG:
				lost += 1
				if k == "grub":
					lost_grubs += 1
	if hit_t < 0.0 and q != null:
		for u in g.units:
			if u.team != ct or u.dead or not AIBroodNew.is_rider(u):
				continue
			var near: bool = u.position.distance_to(q.position) < 12.0 * Defs.TILE
			if not near:
				for b in g.units_near(u.position, 12.0 * Defs.TILE):
					if b.team == bt and not b.dead and BroodNew.ROOTERS.has(b.kind) and BroodNew.rooted(b):
						near = true
						break
			if near:
				hit_t = c
				break
	if w5 < 0 and c >= 300.0:
		w5 = g.workers(bt).size()
	if w8 < 0 and c >= 480.0:
		w8 = g.workers(bt).size()
		var v := 0
		for u in g.army(bt):
			if u.dead or u.is_worker() or u.kind == BroodNew.QUEEN or u.kind == BroodNew.EGG or BroodNew.ROOTERS.has(u.kind):
				continue
			v += Game.unit_value(u)
		army8 = v
	if inc10 < 0 and c >= 600.0:
		inc10 = int(g.stats[bt]["gold"])
		cinc10 = int(g.stats[ct]["gold"])


func _mmss(c: float) -> String:
	if c < 0.0:
		return "-"
	return "%d:%02d" % [int(c) / 60, int(c) % 60]


func _finish() -> void:
	var a = _ai(bt)
	var read_t := -1.0
	if a != null:
		read_t = float(a.rider_read_t) if "rider_read_t" in a and float(a.rider_read_t) >= 0.0 else (float(a.rush_t) if a.rush_seen != "" else -1.0)
	var made_by8 := 0
	for u in riders_made.keys():
		made_by8 += 1
	var gap := "-"
	if read_t >= 0.0 and hit_t >= 0.0:
		gap = "%+d" % int(hit_t - read_t)
	if inc10 < 0:
		inc10 = int(g.stats[bt]["gold"])
		cinc10 = int(g.stats[ct]["gold"])
	var line := "%s seed %d crown:%s brood:%s | read %s hit %s gap %s | lost %d (grubs %d) | riders killed %d of %d | w5 %d w8 %d | army8 %d | inc10 %d (crown %d) | end %s %s" % [
		map, seed_, sa, sb, _mmss(read_t), _mmss(hit_t), gap, lost, lost_grubs, riders_dead, made_by8, w5, w8, army8, inc10, cinc10,
		_mmss(g.clock), ("P%d" % (g.winner + 1)) if g.over and g.winner >= 0 else "none"]
	print("RESULT ", line)
	if out != "":
		var f := FileAccess.open(out, FileAccess.READ_WRITE if FileAccess.file_exists(out) else FileAccess.WRITE)
		f.seek_end()
		f.store_line(line)
		f.close()
	if log_path != "" and g.mlog:
		var lf := FileAccess.open(log_path, FileAccess.WRITE)
		for l in g.mlog.lines:
			lf.store_line(str(l))
		lf.close()
