extends SceneTree
## A computer Brood against another computer, headless, measured for the Brood's defence (docs/brood_ai_swarm.md):
## the owner's playtest of 2026-11-01 (docs/playtests/ai_clock_v_brood_2026-11-01: a HARD RUSH Clockwork against a
## HARD ECONOMY Brood on Glimmerdeep, seed 123537401) is the default.
##   godot --headless --fixed-fps 30 --script res://tools/run_brood_ai_match.gd -- [foe:clockwork] [fs:rush] \
##       [bs:economy] [map:glimmerdeep] [seed:123537401] [end:480] [log:/abs/log.txt]
## Prints, for the Brood:
##  - every time its Mother uprooted (the clock, what was near her), and the Rootmaws that lost their swamp;
##  - LONE FIGHTS: each second, its army creatures fighting (a target in reach of their sight) with fewer than 2 of
##    their own army fighting within 5 tiles: the "trickle" (Raptors drifting off one by one by sight), summed in
##    creature-seconds, and how many of its army died with no friend fighting near them;
##  - the result (army value, kills, losses) at the end.
var main: Node
var g: Game
var t := 0.0
var foe_f := "clockwork"
var fs := "rush"
var bs := "economy"
var map := "glimmerdeep"
var seed_ := 123537401
var end_t := 480.0
var log_path := ""
var bt := -1                   # the Brood's team
var next_s := 1.0
var lone := 0
var lone_dead := 0
var deaths := 0
var q_mode := ""
var q_ups: Array = []
var _last_lone := {}            # unit -> clock it was last seen fighting alone


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"foe": foe_f = kv[1]
			"fs": fs = kv[1]
			"bs": bs = kv[1]
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"end": end_t = float(kv[1])
			"log": log_path = kv[1]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": foe_f, "colour": 0, "side": 0, "strategy": fs},
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
	var q := BroodNew.queen(g, bt)
	if q != null:
		if q_mode != "" and q_mode == "deployed" and q.tesla_mode != "deployed":
			var near := []
			for u in g.units_near(q.position, 14.0 * Defs.TILE):
				if g.hostile(u.team, bt) and not u.dead:
					near.append(u.kind)
			q_ups.append([g.clock, near])
			print("  %s  the Mother UPROOTS (enemies within 14 tiles: %s)" % [_mmss(g.clock), str(near)])
		q_mode = q.tesla_mode
	if g.clock >= next_s:
		next_s += 1.0
		_sample()
	if g.over or g.clock >= end_t:
		_finish()
		return true
	return false


func _sample() -> void:
	var army := g.units.filter(func(u: Unit) -> bool: return u.team == bt and not u.dead and not u.is_worker() and not BroodNew.is_nb(u.kind))
	var fighting := army.filter(func(u: Unit) -> bool: return is_instance_valid(u.target) and not u.target.dead \
		and u.position.distance_to(u.target.position if u.target is Unit else u.target.center()) < 7.0 * Defs.TILE)
	for u in fighting:
		var n := 0
		for o in fighting:
			if o != u and o.position.distance_to(u.position) < 5.0 * Defs.TILE:
				n += 1
		if n < 2:
			lone += 1
			_last_lone[u] = g.clock
	for u in _last_lone.keys():
		if not is_instance_valid(u):
			_last_lone.erase(u)
			continue
		if u.dead:
			deaths += 1
			if g.clock - float(_last_lone[u]) <= 2.0:
				lone_dead += 1
				var ai = g.ais.filter(func(a) -> bool: return a is AIBroodNew and a.team == bt)
				var squad = ai[0].get("_def") if not ai.is_empty() else null
				var why := "in a wave" if not ai.is_empty() and (ai[0] as AIBroodNew)._wave.has(u) else ("in defence" if squad is Array and (squad as Array).has(u) else "on its own")
				print("  %s  a %s died fighting alone (%s)" % [_mmss(g.clock), u.kind, why])
			_last_lone.erase(u)


func _mmss(c: float) -> String:
	return "%d:%02d" % [int(c) / 60, int(c) % 60]


func _finish() -> void:
	var lines: PackedStringArray = []
	if g.mlog:
		lines = g.mlog.text().split("\n") if g.mlog.has_method("text") else PackedStringArray()
	var swamp := 0
	for l in lines:
		if "lost its swamp" in l and "Brood" in l:
			swamp += 1
	if log_path != "" and not lines.is_empty():
		var f := FileAccess.open(log_path, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(lines))
	var st: Dictionary = g.stats[bt]
	var ft: int = 1 - bt
	print("RESULT %s at %s: Brood army %d, earned %d, killed %d units (%d value), lost %d units | foe army %d | Mother uprooted %d times | Rootmaws lost swamp %d | lone-fight creature-seconds %d, army deaths %d (lone %d)" % [
		"over" if g.over else "time", _mmss(g.clock), g.army_value(bt), int(st.get("gold", 0)), int(st.get("killed", 0)), int(st.get("value_killed", 0)), int(st.get("lost", 0)),
		g.army_value(ft), q_ups.size(), swamp, lone, deaths, lone_dead])
