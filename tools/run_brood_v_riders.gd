extends SceneTree
## A HARD CROWN HORSEMAN RUSH AGAINST A HARD BROOD, headless and measured (brood-anti-riders, docs/brood_anti_riders.md):
## the owner's game of 2026-11-06 (docs/playtests/2026-11-06/brood_v_horseman_rush_hollowfen_log.txt: Hollowfen, seed
## 3233604515, his Horsemen v the Brood OPTIMAL) replayed with a computer Crown rushing.
##   godot --headless --fixed-fps 30 --script res://tools/run_brood_v_riders.gd -- [map:hollowfen] [seed:3233604515] \
##       [cs:rush] [bs:optimal] [end:600] [log:/abs/log.txt]
## Prints one RESULT line:
##   left    the first rider (is_rider) off the Crown's main (off its plateau or 22 tiles out)
##   seen    when the Brood's alarm for riders came (AIBroodNew.riders_alarm_t; before brood-anti-riders its first alarm)
##   arrive  the first rider within 14 tiles of the Mother or a rooted Brood creature
##   warn    arrive - seen (the warning the Brood had; negative = it saw them after they arrived)
##   raid    from arrive to 90 s later: Brood grubs lost, other Brood units lost, riders killed
##   grubs at 5:00 and 8:00, biomass earned at 10:00, the winner (or "time")
var main: Node
var g: Game
var t := 0.0
var map := "hollowfen"
var seed_ := 3233604515
var cs := "rush"
var bs := "optimal"
var end_t := 600.0
var log_path := ""
var trace := false
var bt := -1
var ct := -1
var ai: AIBroodNew = null
var left_t := -1.0
var seen_t := -1.0
var arrive_t := -1.0
var raid_grubs := 0
var raid_other := 0
var raid_riders := 0
var grubs_5 := -1
var grubs_8 := -1
var earned_10 := -1
var army_8 := -1
var _alive := {}               # unit -> [team, kind, rider]
var next_s := 1.0
var _h0 := -1
var _st := Vector2.ZERO


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"cs": cs = kv[1]
			"bs": bs = kv[1]
			"end": end_t = float(kv[1])
			"log": log_path = kv[1]
			"trace": trace = kv[1] == "1"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": cs},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": bs}]})
		return false
	if main.game == null:
		return false
	g = main.game
	g.path_budget_us = 1 << 40
	if g.hud:
		g.hud.visible = false
	if bt < 0:
		for i in g.factions.size():
			if g.factions[i] == "brood":
				bt = i
			else:
				ct = i
		for a in g.ais:
			if a is AIBroodNew:
				ai = a
		_st = (Vector2(g.starts[ct]) + Vector2(2.5, 2.0)) * Defs.TILE
		var hc := Vector2i(Vector2(g.starts[ct]) + Vector2(2.5, 2.0))
		_h0 = int(g.height[g.idx(hc)])
	if g.clock >= next_s:
		next_s += 1.0
		_sample()
	if g.over or g.clock >= end_t:
		_finish()
		return true
	return false


func _sample() -> void:
	var c := g.clock
	# deaths since the last sample
	for u in _alive.keys():
		if is_instance_valid(u) and not u.dead:
			continue
		var info: Array = _alive[u]
		_alive.erase(u)
		if arrive_t >= 0.0 and c - arrive_t <= 90.0:
			if int(info[0]) == bt:
				if String(info[1]) == "grub":
					raid_grubs += 1
				else:
					raid_other += 1
			elif bool(info[2]):
				raid_riders += 1
	for u in g.units:
		if u.dead or u.off_field or _alive.has(u) or u.kind == "horse":
			continue
		_alive[u] = [u.team, u.kind, u.team == ct and AIBroodNew.is_rider(u)]
	# the riders
	var q := BroodNew.queen(g, bt)
	for u in g.units:
		if u.dead or u.off_field or u.team != ct or not AIBroodNew.is_rider(u):
			continue
		if left_t < 0.0:
			var cc := g.cell_of(u.position)
			if (g.in_map(cc) and int(g.height[g.idx(cc)]) != _h0 and g.ramp[g.idx(cc)] == 0) or u.position.distance_to(_st) > 22.0 * Defs.TILE:
				left_t = c
				print("  %s  a rider leaves the Crown's main" % _mmss(c))
		if arrive_t < 0.0 and q != null:
			var near: bool = u.position.distance_to(q.position) < 14.0 * Defs.TILE
			if not near:
				for b in g.units_near(u.position, 14.0 * Defs.TILE):
					if b.team == bt and not b.dead and BroodNew.rooted(b):
						near = true
						break
			if near:
				arrive_t = c
				print("  %s  riders arrive at the Brood" % _mmss(c))
	if seen_t < 0.0 and ai != null:
		if "riders_alarm_t" in ai:
			if float(ai.get("riders_alarm_t")) > 0.0:
				seen_t = float(ai.get("riders_alarm_t"))
		elif ai.alarm_t > 0.0 and left_t >= 0.0:
			seen_t = ai.alarm_t          # (before brood-anti-riders: the shared alarm)
		if seen_t >= 0.0:
			print("  %s  the Brood's alarm for the riders" % _mmss(seen_t))
	if trace and ai != null and int(c) % 5 == 0 and c < 420.0:
		var sc = ai.get("_scout")
		var sp := "none"
		if sc != null and is_instance_valid(sc) and not sc.dead:
			sp = "%s %s at (%d,%d) order %s" % [sc.kind, "FLEE" if ai.get("_watch_flee") else "watch", int(sc.position.x / Defs.TILE), int(sc.position.y / Defs.TILE), sc.order]
		var rs: Array = []
		for u in g.units:
			if not u.dead and u.team == ct and AIBroodNew.is_rider(u):
				rs.append("(%d,%d)%s" % [int(u.position.x / Defs.TILE), int(u.position.y / Defs.TILE), "v" if g.is_visible_to(bt, u.position) else ""])
		var ft = ai.get("_foot")
		var hist := {}
		for u in g.units:
			if not u.dead and u.team == bt and u.kind == "grub":
				var pl: Dictionary = ai.get("_pulled")
				var k: String = u.order + (("R" if (pl[u] as Array).size() > 2 else "*") if pl.has(u) else "")
				hist[k] = int(hist.get(k, 0)) + 1
		var fr: Array = []
		for u in g.units:
			if not u.dead and u.team == ct and not u.is_worker() and u.has_attack() and u.kind != "horse":
				var qq := BroodNew.queen(g, bt)
				if qq != null and u.position.distance_to(qq.position) < 30.0 * Defs.TILE:
					fr.append("%s@%d" % [u.kind, int(u.position.distance_to(qq.position) / Defs.TILE)])
		print("  %s grubs %s food %d | foes near Mother %s | threat %s" % [_mmss(c), str(hist), int(g.players[bt]["gold"]), str(fr), str(ai.call("_riders_threat")) if ai.has_method("_riders_threat") else "-"])
		print("  %s trace: scout %s | foot %s | riders %s | alarm %.0f" % [_mmss(c), sp, str(Vector2i(ft / Defs.TILE)) if ft != Vector2.INF else "-", " ".join(rs), ai.alarm_t])
	if grubs_5 < 0 and c >= 300.0:
		grubs_5 = BroodNew.count_of(g, bt, "grub")
	if grubs_8 < 0 and c >= 480.0:
		grubs_8 = BroodNew.count_of(g, bt, "grub")
		army_8 = g.army_value(bt)
	if earned_10 < 0 and c >= 600.0:
		earned_10 = int(g.stats[bt].get("gold", 0))


func _mmss(c: float) -> String:
	if c < 0.0:
		return "-"
	return "%d:%02d" % [int(c) / 60, int(c) % 60]


func _finish() -> void:
	if log_path != "" and g.mlog and g.mlog.has_method("text"):
		var f := FileAccess.open(log_path, FileAccess.WRITE)
		if f:
			f.store_string(g.mlog.text())
	var warn := "-"
	if seen_t >= 0.0 and arrive_t >= 0.0:
		warn = "%d" % int(arrive_t - seen_t)
	var who := "time"
	if g.over:
		who = "brood" if g.winner == bt else ("crown" if g.winner == ct else str(g.winner))
	print("RESULT map %s seed %d cs %s bs %s | left %s seen %s arrive %s warn %s | raid: grubs lost %d, other lost %d, riders killed %d | grubs 5:00 %d 8:00 %d | army 8:00 %d | earned 10:00 %d | brood lost %d killed %d | end %s %s" % [
		map, seed_, cs, bs, _mmss(left_t), _mmss(seen_t), _mmss(arrive_t), warn, raid_grubs, raid_other, raid_riders,
		grubs_5, grubs_8, army_8, earned_10, int(g.stats[bt].get("lost", 0)), int(g.stats[bt].get("killed", 0)), who, _mmss(g.clock)])
