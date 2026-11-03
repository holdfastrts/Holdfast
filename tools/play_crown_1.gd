extends "res://tools/shot_ai_match.gd"
## THE CROWN'S OWN COMPUTER, COACHED AND FILMED (docs/ai_crown_rebuild.md), in the style of tools/play_brood_3.gd: side 0 is
## the Crown computer (scripts/ai_crown.gd) on a FORCED PLAN (`coach:<plan>`, any plan setting changed with
## `set:key=value,...`, the coach's hand orders on top), side 1 the normal computer.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_crown_1.gd -- \
##       coach:economy b:brood sb:timing map:red_coast seed:4291306512 out:/abs/dir [end:900] [db:hard] [set:labs=18]
## Everything of tools/shot_ai_match.gd (fight_MMSS_x_y.png, base_<team>_MMSS.png, log.txt, result.txt) plus:
##   <out>/minutes.txt  a line a minute: labourers (idle), farms / Mills / halls, gold and powder banked and earned that
##                      minute, supply, the Crown's army (value, by kind) and the enemy's, kills and losses, the plan's state
##   <out>/events.txt   the build order's steps and the plan's decisions, the coach's hand orders, the key moments
##   key moments: bo_hall_MMSS.png (the second hall laid), scout_MMSS.png (the labourer scout at the enemy), rider_MMSS.png
##   (a Horseman scout out), hold_MMSS.png (the ramp post holding), defence_MMSS.png (an enemy force at home), wave_MMSS.png,
##   clip_first_attack (frames: python3 -I tools/play_brood_new_gif.py <out> makes first_attack.gif), clip_defence
## Coach's hand orders (`hand:`): "post" draws the ramp post's spots once in events.txt; none moves a unit unless asked:
##   hand:scoutall  every Horseman over two rides the scout loop too (the shared AICrownHold loop)
## Plans: economy, balanced, timing, rush (the computer's own), plus the coach's variants below.
const COACH := {
	"economy": {"strategy": "economy", "set": {}},
	"balanced": {"strategy": "balanced", "set": {}},
	"timing": {"strategy": "timing", "set": {}},
	"rush": {"strategy": "rush", "set": {}},
	# (variants the coach tries: the plan's settings changed; docs/ai_crown_rebuild.md says which were kept)
	"eco_late": {"strategy": "economy", "set": {"labs": 99}},
}
var coach_plan := "economy"
var sb := "balanced"
var sets := {}
var hands := ""
var _ai: AICrown = null
var events: Array = []
var minutes: Array = []
var _next_min := 60.0
var _earned0 := [0, 0]
var _powder0 := 0.0
var _bo_seen := 0
var _note_seen := 0
var _scout_shot := false
var _rider_shot := false
var _holds_seen := 0
var _def_t := -999.0
var _att_seen := false
var _shots_t := {}
var clips: Array = []


func _initialize() -> void:
	super._initialize()
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"coach": coach_plan = kv[1]
			"sb": sb = kv[1]
			"hand": hands = kv[1]
			"set":
				for pair in kv[1].split(","):
					var p := pair.split("=", true, 1)
					if p.size() == 2:
						sets[p[0]] = str_to_var(p[1]) if str_to_var(p[1]) != null else p[1]
	if not Array(OS.get_cmdline_user_args()).any(func(x: String) -> bool: return x.begins_with("end:")):
		end_t = 900.0


func _process(delta: float) -> bool:
	if main.game == null:
		t += delta
		if t > 0.2:
			seed(seed_)
			var c: Dictionary = COACH.get(coach_plan, COACH["economy"])
			main.start({"map": map, "seed": seed_, "slots": [
				{"who": da, "faction": "crown", "colour": 0, "side": 0, "strategy": String(c["strategy"])},
				{"who": db, "faction": fb, "colour": 1, "side": 1, "strategy": sb}]})
			for a in main.game.ais:
				if a.team == 0 and a is AICrown:
					_ai = a
					var o: Dictionary = (c["set"] as Dictionary).duplicate(true)
					for k in sets:
						o[k] = sets[k]
					_ai.over = o
					_ai._make_plan()
					print("COACH plan %s: strategy %s, forced %s" % [coach_plan, String(c["strategy"]), str(o)])
		return false
	g = main.game
	if g.hud and g.hud.countdown > 0.0:
		g.hud.countdown = 0.0
	g.reveal = true          # (the camera sees everything; the computers only what their own side sees)
	if not g.over and _ai != null:
		_coach()
	if not shooting and pending.is_empty() and not clips.is_empty():
		_clip_run()
		return false
	return super._process(delta)


func say(s: String) -> void:
	var l := "%s %s" % [_mmss(g.clock), s]
	events.append(l)
	print("EV " + l)


func shot(name: String, at, zoom := 1.0, gap := 20.0) -> void:
	if g.clock - float(_shots_t.get(name, -999.0)) < gap:
		return
	_shots_t[name] = g.clock
	pending.append(["%s_%s.png" % [name, _mmss(g.clock)], at.position if at is Unit else (at.center() if at is Building else at), zoom])


func clip(name: String, who, frames := 30, step := 4, zoom := 1.2) -> void:
	if _shots_t.has("clip_" + name):
		return
	_shots_t["clip_" + name] = g.clock
	clips.append([name, who, frames, step, zoom])


func _home() -> Vector2:
	return (Vector2(g.starts[0]) + Vector2(2.5, 2.0)) * Defs.TILE


func _foe_home() -> Vector2:
	return (Vector2(g.starts[1]) + Vector2(2.5, 2.0)) * Defs.TILE


# ------------------------------------------------------------------ the coach

func _coach() -> void:
	if g.clock >= _next_min:
		_next_min += 60.0
		_minute()
	# the build order's steps and the plan's notes, as they come
	while _bo_seen < _ai.bo_log.size():
		var e: Array = _ai.bo_log[_bo_seen]
		_bo_seen += 1
		say("build order: %s" % String(e[1]))
		if String(e[1]).begins_with("Town Hall"):
			for h in _ai._halls():
				if not h.built:
					_later.append([g.clock + 6.0, "bo_hall_%s.png" % _mmss(g.clock), h])
	while _note_seen < _ai.note.size():
		say("plan: %s" % String(_ai.note[_note_seen][1]))
		_note_seen += 1
	# the labourer scout at the enemy's base
	var su = _ai.scout.unit if _ai.scout != null else null
	if not _scout_shot and su is Unit and is_instance_valid(su) and not su.dead and su.position.distance_to(_foe_home()) < 14.0 * Defs.TILE:
		_scout_shot = true
		say("the scout is at the enemy's base")
		shot("scout", su, 1.0)
	# a Horseman scout out on the map
	if not _rider_shot:
		for u in _ai.ch.scouts.keys():
			if is_instance_valid(u) and not u.dead and u.position.distance_to(_home()) > 30.0 * Defs.TILE:
				_rider_shot = true
				say("a Horseman scouts the map")
				shot("rider", u, 1.1)
				break
	# the ramp post holding the top
	if _ai.ch.holds > _holds_seen:
		_holds_seen = _ai.ch.holds
		if _holds_seen <= 3:
			var p: Vector2 = _ai.ch._bc * Defs.TILE if _ai.ch._bc != Vector2.INF else _home()
			say("the ramp post holds the top (%d)" % _holds_seen)
			shot("hold", p, 1.1, 10.0)
	# an enemy force at home
	var thr: Vector2 = _ai._threat()
	if thr != Vector2.INF and g.clock - _def_t > 60.0:
		var n := 0
		for u in g.units_near(thr, 400.0):
			if u.team == 1 and not u.dead and not u.is_worker() and not BroodNew.is_nb(u.kind):
				n += 1
		if n >= 5:
			_def_t = g.clock
			say("an enemy force at home (%d soldiers)" % n)
			shot("defence", thr, 1.1, 30.0)
			clip("defence", thr, 24, 4, 1.15)
	# the first attack: a clip of it on the way and a picture when it gets there
	if _ai._attacking and not _att_seen:
		_att_seen = true
		var lead: Unit = null
		for u in _ai._wave_set.keys():
			if is_instance_valid(u) and not u.dead:
				lead = u
				break
		if lead:
			say("the first attack goes out (%d supply)" % _ai._army_supply(_ai._wave_set.keys().filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)))
			clip("first_attack", lead, 30, 5, 1.1)
			_later.append([g.clock + 40.0, "wave_%s.png" % _mmss(g.clock), lead])
	if hands.contains("scoutall"):
		pass          # (the shared loop takes the riders it wants: AICrownHold._want)


func _kinds(list: Array) -> String:
	var n := {}
	for u in list:
		n[u.kind] = int(n.get(u.kind, 0)) + 1
	var out: Array = []
	for k in n:
		out.append("%d %s" % [n[k], k])
	return ", ".join(out)


func _minute() -> void:
	var st: Dictionary = g.stats[0]
	var fs: Dictionary = g.stats[1]
	var labs := g.workers(0)
	var idle := labs.filter(func(u: Unit) -> bool: return u.order == "idle").size()
	var farms := _ai._mine("farm").size()
	var mills := _ai._mine("powder_mill").size()
	var mill_crew := 0
	for m in _ai._mine("powder_mill"):
		mill_crew += m.crew.size()
	var army := g.army(0)
	var foe := g.army(1).filter(func(u: Unit) -> bool: return not BroodNew.is_nb(u.kind) or not u.is_worker())
	var state := ("opening step %d/%d (reserve %d)" % [_ai.bo_i + 1, _ai._bo_plan.size(), _ai.bo_reserve]) if not _ai.bo_done else "milestones"
	var line := "%s labourers %d (idle %d) | halls %d farms %d mills %d (crew %d) | gold %d powder %d | earned this minute %d gold %d powder | supply %d/%d | army %d (%s) | enemy army %d (%s) | killed %d lost %d | enemy earned %d | %s | attack_at %d%s" % [
		_mmss(g.clock), labs.size(), idle, _ai._halls().size(), farms, mills, mill_crew, int(g.players[0]["gold"]), int(g.players[0]["res2"]),
		int(st["gold"]) - _earned0[0], int(float(st["res2_in"]) - _powder0), g.supply_used(0), int(g.players[0]["cap"]),
		g.army_value(0), _kinds(army), g.army_value(1), _kinds(foe).left(160), int(st["value_killed"]), int(fs["value_killed"]),
		int(fs["gold"]) - _earned0[1], state, _ai._attack_at, " ATTACKING" if _ai._attacking else ""]
	_earned0 = [int(st["gold"]), int(fs["gold"])]
	_powder0 = float(st["res2_in"])
	minutes.append(line)
	print("MIN " + line.left(300))


func _clip_run() -> void:
	shooting = true
	var c: Array = clips.pop_front()
	var cam: Camera2D = g.camera
	var keep_pos := cam.position
	var keep_zoom := cam.zoom
	cam.zoom = Vector2(c[4], c[4])
	RenderingServer.render_loop_enabled = true
	var who = c[1]
	for i in int(c[2]):
		if who is Unit and is_instance_valid(who) and not who.dead:
			cam.position = who.position + Vector2(0, -30)
		elif who is Vector2:
			cam.position = who
		cam.reset_smoothing()
		for k in int(c[3]):
			await process_frame
		if i == 0:
			for k in 6:
				await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join("clip_%s_%02d.png" % [c[0], i]))
	print("CLIP %s %d frames" % [c[0], int(c[2])])
	RenderingServer.render_loop_enabled = live
	cam.position = keep_pos
	cam.zoom = keep_zoom
	shooting = false


func _finish() -> void:
	super._finish()
	var f := FileAccess.open(out.path_join("minutes.txt"), FileAccess.WRITE)
	for l in minutes:
		f.store_line(l)
	f.close()
	var e := FileAccess.open(out.path_join("events.txt"), FileAccess.WRITE)
	for l in events:
		e.store_line(l)
	if _ai:
		e.store_line("opening over: %s" % _ai.bo_why)
	e.close()
