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
	"dragoon": {"strategy": "dragoon", "set": {}},     # (crown-builds-a: tools/play_crown_builds_a.gd films the raids)
	# (variants the coach tries: the plan's settings changed; docs/ai_crown_rebuild.md says which were kept)
	"eco_late": {"strategy": "economy", "set": {"labs": 99}},
}
var coach_plan := "economy"
var raid_t := -1.0              # raid:SECONDS:N the coach's staged attack: N Raptors (of the enemy) appear 9 tiles out from the
var raid_n := 24                # Crown's newest hall below its main at that time and go for it (the owner's 6:19 on Thornwood)
var raid_done := false
var me := 0                     # cslot:1 the Crown plays in the second slot (the owner's log had it as P2)
var fo := 1
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
			"cslot":
				me = int(kv[1])
				fo = 1 - me
			"sb": sb = kv[1]
			"hand": hands = kv[1]
			"raid":
				var rp := kv[1].split(":")
				raid_t = float(rp[0])
				raid_n = int(rp[1]) if rp.size() > 1 else 24
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
			var slots: Array = [
				{"who": da, "faction": "crown", "colour": 0, "side": 0, "strategy": String(c["strategy"])},
				{"who": db, "faction": fb, "colour": 1, "side": 1, "strategy": sb}]
			if me == 1:
				# (the Crown in the second slot, as in a log where it was P2: the enemy first, its colour and side kept)
				slots = [{"who": db, "faction": fb, "colour": 1, "side": 0, "strategy": sb},
					{"who": da, "faction": "crown", "colour": 0, "side": 1, "strategy": String(c["strategy"])}]
			main.start({"map": map, "seed": seed_, "slots": slots})
			for a in main.game.ais:
				if a.team == me and a is AICrown:
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
	return (Vector2(g.starts[me]) + Vector2(2.5, 2.0)) * Defs.TILE


func _foe_home() -> Vector2:
	return (Vector2(g.starts[fo]) + Vector2(2.5, 2.0)) * Defs.TILE


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
			if u.team == fo and not u.dead and not u.is_worker() and not BroodNew.is_nb(u.kind):
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
	_cliff_watch()
	if hands.contains("scoutall"):
		pass          # (the shared loop takes the riders it wants: AICrownHold._want)


## THE CLIFF EDGE (0.29.2, docs/crown_cliff_edge.md): the line at the edge (edge_MMSS.png, and 5 s later), the menders
## (mend_MMSS.png, clip_mend), the first Field Cannon and its first canister shot (cannon_MMSS.png), every hall laid / lost.
var _edge_seen := 0
var _mend_seen := false
var cannon_t := -1.0
var canister_t := -1.0
var _halls_seen := {}
var hall_lines: Array = []


var _raid_hall: Building = null
var _raid_k0 := [0, 0]
var _raid_said := false


func _cliff_watch() -> void:
	var ch = _ai.ch
	if _raid_hall != null and not _raid_said and g.clock >= raid_t + 60.0:
		_raid_said = true
		var ok: bool = is_instance_valid(_raid_hall) and not _raid_hall.dead
		hall_lines.append("staged raid of %d Raptors at %s: after 60 s the hall %s; value killed %d by the Crown, %d by the raiders' side" % [raid_n, _mmss(raid_t),
			("stands at %d/%d" % [int(_raid_hall.hp), int(_raid_hall.max_hp)]) if ok else "is LOST",
			int(g.stats[me]["value_killed"]) - int(_raid_k0[0]), int(g.stats[fo]["value_killed"]) - int(_raid_k0[1])])
	if raid_t >= 0.0 and not raid_done and g.clock >= raid_t:
		raid_done = true
		var hall: Building = null
		for h in _ai._halls():
			if h.center().distance_to(_home()) > 10.0 * Defs.TILE and (hall == null or h.center().distance_to(_home()) < hall.center().distance_to(_home())):
				hall = h
		if hall == null:
			say("the staged raid: no hall below the main to go for")
		else:
			var away: Vector2 = (hall.center() - _home()).normalized()
			var at: Vector2 = hall.center() + away * 9.0 * Defs.TILE
			var n := 0
			for i in raid_n:
				var p: Vector2 = at + Vector2(float(i % 6 - 3) * 22.0, float(i / 6 - 2) * 22.0)
				var c: Vector2i = g.nearest_free(g.cell_of(p), 6)
				if c.x < 0:
					continue
				var r: Unit = g._add_unit("raptor", fo, g.cell_center(c))
				r.cmd_attack(hall)
				n += 1
			say("the staged raid: %d Raptors at the hall at %s (%s, %d/%d hp)" % [n, str(hall.cell), "built" if hall.built else "going up", int(hall.hp), int(hall.max_hp)])
			_raid_hall = hall
			_raid_k0 = [int(g.stats[me]["value_killed"]), int(g.stats[fo]["value_killed"])]
			clip("raid", hall.center(), 30, 6, 1.0)
			_later.append([g.clock + 10.0, "raid_%s.png" % _mmss(g.clock), hall.center()])
			_later.append([g.clock + 20.0, "raid_%s.png" % _mmss(g.clock + 10.0), hall.center()])
	if ch.edge_moves > _edge_seen:
		_edge_seen = ch.edge_moves
		var mid := Vector2.ZERO
		for p in ch._edge_spots:
			mid += p
		if not ch._edge_spots.is_empty():
			mid /= float(ch._edge_spots.size())
			say("the line moves to the cliff edge (%d): %s" % [_edge_seen, String(ch.edge_log[-1][1]) if not ch.edge_log.is_empty() else ""])
			var at: Vector2 = mid.lerp(ch._edge_aim, 0.4) if ch._edge_aim != Vector2.INF else mid
			if _edge_seen <= 4:
				_later.append([g.clock + 5.0, "edge_%s.png" % _mmss(g.clock), at])
	if not _mend_seen and ch.mend_sent > 0 and ch._edge_b != null and is_instance_valid(ch._edge_b):
		_mend_seen = true
		say("labourers mend the %s under fire (%d sent)" % [ch._edge_b.kind, ch.mend_sent])
		shot("mend", ch._edge_b, 1.3, 5.0)
		clip("mend", ch._edge_b.center(), 24, 4, 1.3)
	for u in g.army(me):
		if u.kind != "cannon" or u.dead:
			continue
		if cannon_t < 0.0:
			cannon_t = g.clock
			say("the first Field Cannon is out")
		if canister_t < 0.0 and u.mode == "canister" and u.target != null and is_instance_valid(u.target):
			canister_t = g.clock
			say("the cannon fires canister (%s, %s)" % [u.order, "unlimbered" if u.tesla_mode != "packed" else "limbered"])
			shot("cannon", u, 1.4, 5.0)
	for h in _ai._halls():
		if not _halls_seen.has(h):
			_halls_seen[h] = true
			var dd: float = h.center().distance_to(_home()) / Defs.TILE
			hall_lines.append("%s hall laid at %s, %.1f tiles from the main" % [_mmss(g.clock), str(h.cell), dd])
	for h in _halls_seen.keys():
		if is_instance_valid(h) and h.dead and _halls_seen[h]:
			_halls_seen[h] = false
			var how := "LOST" if h.built else "site gone (dropped or razed unbuilt)"
			hall_lines.append("%s hall %s at %s" % [_mmss(g.clock), how, str(h.cell)])
			say("the hall at %s: %s" % [str(h.cell), how])


func _kinds(list: Array) -> String:
	var n := {}
	for u in list:
		n[u.kind] = int(n.get(u.kind, 0)) + 1
	var out: Array = []
	for k in n:
		out.append("%d %s" % [n[k], k])
	return ", ".join(out)


func _minute() -> void:
	var st: Dictionary = g.stats[me]
	var fs: Dictionary = g.stats[fo]
	var labs := g.workers(me)
	var idle := labs.filter(func(u: Unit) -> bool: return u.order == "idle").size()
	var farms := _ai._mine("farm").size()
	var mills := _ai._mine("powder_mill").size()
	var mill_crew := 0
	for m in _ai._mine("powder_mill"):
		mill_crew += m.crew.size()
	var army := g.army(me)
	var foe := g.army(fo).filter(func(u: Unit) -> bool: return not BroodNew.is_nb(u.kind) or not u.is_worker())
	var state := ("opening step %d/%d (reserve %d)" % [_ai.bo_i + 1, _ai._bo_plan.size(), _ai.bo_reserve]) if not _ai.bo_done else "milestones"
	var line := "%s labourers %d (idle %d) | halls %d farms %d mills %d (crew %d) | gold %d powder %d | earned this minute %d gold %d powder | supply %d/%d | army %d (%s) | enemy army %d (%s) | killed %d lost %d | enemy earned %d | %s | attack_at %d%s" % [
		_mmss(g.clock), labs.size(), idle, _ai._halls().size(), farms, mills, mill_crew, int(g.players[me]["gold"]), int(g.players[me]["res2"]),
		int(st["gold"]) - _earned0[0], int(float(st["res2_in"]) - _powder0), g.supply_used(me), int(g.players[me]["cap"]),
		g.army_value(me), _kinds(army), g.army_value(fo), _kinds(foe).left(160), int(st["value_killed"]), int(fs["value_killed"]),
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
	if _ai:
		var c := FileAccess.open(out.path_join("cliff.txt"), FileAccess.WRITE)
		for l in hall_lines:
			c.store_line(l)
		var st: Dictionary = g.stats[me]
		var fs: Dictionary = g.stats[fo]
		c.store_line("first Field Cannon %s, first canister shot %s, cannon first vs the Brood %s" % [_mmss(cannon_t) if cannon_t >= 0.0 else "-",
			_mmss(canister_t) if canister_t >= 0.0 else "-", _mmss(_ai.cannon_first_t) if _ai.cannon_first else "no"])
		c.store_line("edge moves %d, menders sent %d, dodges %d, Crown site picks %d" % [_ai.ch.edge_moves, _ai.ch.mend_sent, _ai.ch.mend_dodges, _ai.site_picks])
		c.store_line("value killed by the Crown %d, by the enemy %d, at %s" % [int(st["value_killed"]), int(fs["value_killed"]), _mmss(g.clock)])
		for l in _ai.ch.edge_log:
			c.store_line("%s %s" % [_mmss(float(l[0])), String(l[1])])
		c.close()
