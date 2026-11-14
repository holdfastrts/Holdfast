extends SceneTree
## Film a computer-against-computer match: screenshots of the fights as they happen and of each side's base at set
## times, plus the match log. For looking closely at a few games (2026-10-27, Crown v Clockwork).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_ai_match.gd -- \
##       a:crown b:clockwork map:greenhold seed:11 swap:0 out:/abs/dir [end:1800] [da:hard db:normal]
## Writes <out>/fight_MMSS_<x>_<y>.png (a fight: where the most units of both sides meet, at most one every FIGHT_GAP s),
## <out>/base_<team>_MMSS.png (each main at BASE_AT), <out>/log.txt (the match log) and <out>/result.txt.
var FIGHT_GAP := 25.0        # gap:N seconds between fight shots (crown-v-brood-coach: from:T, the gap only after T)
const FIGHT_MIN := 4            # units of each side near each other
const NEAR := 230.0
const BASE_AT := [180.0, 360.0, 600.0, 900.0]
var main: Node
var g: Game
var fa := "crown"
var fb := "clockwork"
var map := "greenhold"
var seed_ := 1
var swap := false
var out := "/tmp/ai_match"
var end_t := 1800.0
var norepair := false        # norepair:1 the walls and gates are never repaired (repair orders cancelled, autocast off)
var noretreat := false       # noretreat:1 a computer's siege is never called off (AI.siege_no_retreat)
var noopen := false          # noopen:1 the Clockwork's waves go for the main hall only (no open targets: AI.open_targets_on)
var da := "hard"             # da:/db: the computers' difficulty (easy, normal, hard, brutal) for a: and b:
var db := "hard"
var pa := "balanced"         # pa:/pb: the computers' plans (crown-v-clockwork-coach: pa:optimal pb:optimal)
var pb := "balanced"
var every := 0.0             # every:N each side's main and its army filmed every N s (base_<team>_MMSS, army_<team>_MMSS)
var _next_every := 0.0
var gap_from := 0.0
var gap_n := 25.0
var coach := false           # coach:1 (crown-v-brood-coach) a status line every 15 s (coach.txt), the Crown army filmed
                             # every 30 s (army_MMSS.jpg), the bases every 2 minutes; pictures as jpg
var next_status := 15.0
var next_army := 30.0
var next_raid := 0.0
var status_lines: Array = []
var _next_stat := 15.0      # (clockwork-v-brood-coach) with every:N, a stats line per side every 15 s (stats.txt)
var stat_lines: Array = []
var ground := false
var nocap := false
var minwave := 0             # minwave:N only a siege by a wave of at least N units is watched (the flags start with it)
var siege_end := false       # siege_end:1 stop once the first siege has played out, writing siege.txt
var _siege_t0 := -1.0
var _siege_next := 0.0
var _siege_wave: Array = []
var _siege_def: Array = []
var _siege_def_w := 0
var _siege_piece: Building = null
var _siege_breach := -1.0
var _siege_cancel := 0
var _siege_team := -1
var _siege_lines: Array = []
var live := false            # live:1 keeps drawing every frame (slow; for checking the shots)
var t := 0.0
var last_fight := -999.0
var next_check := 0.0
var base_i := 0
var next_wind := 30.0
var wind_lines: Array = []
var pending: Array = []        # [file, camera position, zoom]
var shooting := false
var _draws := 0
var shot_frames := 30
func _count_draw() -> void:
	_draws += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"a": fa = kv[1]
			"b": fb = kv[1]
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"swap": swap = kv[1] == "1"
			"out": out = kv[1]
			"end": end_t = float(kv[1])
			"live": live = kv[1] == "1"
			"norepair": norepair = kv[1] == "1"
			"noretreat": noretreat = kv[1] == "1"
			"siege_end": siege_end = kv[1] == "1"
			"minwave": minwave = int(kv[1])
			"noopen": noopen = kv[1] == "1"
			"da": da = kv[1]
			"db": db = kv[1]
			"pa", "sa": pa = kv[1]      # (sa:/sb: clockwork-v-clockwork-coach's names for the same)
			"pb", "sb": pb = kv[1]
			"every": every = float(kv[1])
			"coach": coach = kv[1] == "1"
			"gap": gap_n = float(kv[1])
			"from": gap_from = float(kv[1])
			"ground": ground = kv[1] == "1"          # (THE GROUND SYSTEM on, docs/ground_system.md)
			"groundcap": nocap = kv[1] == "off"      # (NO FARM/PRESS LIMIT, docs/ground_nocap_study.md)
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.render_loop_enabled = live     # (drawn only for the shots: the match runs many times faster)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var facs := [fb, fa] if swap else [fa, fb]
		var whos := [db, da] if swap else [da, db]
		var plans := [pb, pa] if swap else [pa, pb]
		var slots: Array = []
		for i in 2:
			slots.append({"who": whos[i], "faction": facs[i], "colour": i, "side": i, "strategy": plans[i]})
		main.start({"map": map, "seed": seed_, "slots": slots, "ground": ground, "ground_nocap": nocap})
		return false
	if main.game == null:
		return false
	g = main.game
	g.path_budget_us = 1 << 40        # (no time limit on the path queue: the same match every run, like tools/perf_bench.gd)
	if not g.gear_net.draw.is_connected(_count_draw):
		g.gear_net.draw.connect(_count_draw)
	if g.hud:
		g.hud.visible = false
	if g.spectator and g.spectator.process_mode != Node.PROCESS_MODE_DISABLED:
		g.spectator.process_mode = Node.PROCESS_MODE_DISABLED     # (the director camera would move it off the shot)
	if g.controls and g.controls.process_mode != Node.PROCESS_MODE_DISABLED:
		g.controls.process_mode = Node.PROCESS_MODE_DISABLED       # (the mouse sits in a corner under xvfb: edge scrolling)
	_siege_watch()
	if noopen:
		for a in g.ais:
			a.open_targets_on = false
	if noretreat:
		for a in g.ais:
			a.siege_no_retreat = true      # (from the start: a siege the computer would call off at once plays out too)
	if norepair and _siege_t0 >= 0.0:
		for u in g.units:
			if is_instance_valid(u) and not u.dead and u.is_worker():
				u.auto_repair = false
				if u.order == "repair" and is_instance_valid(u.order_target) and u.order_target is Building:
					u.cmd_stop()
					_siege_cancel += 1
	if siege_end and _siege_t0 >= 0.0 and _siege_over():
		_siege_report()
		_finish()
		return true
	if shooting:
		return false
	if not pending.is_empty():
		_shoot()
		return false
	var c: float = g.clock
	if coach:
		_coach_tick(c)
	if base_i < BASE_AT.size() and c >= BASE_AT[base_i]:
		for tm in 2:
			var h: Building = g._own_hall(tm)
			if h:
				pending.append(["base_%d_%s.png" % [tm, _mmss(c)], h.global_position + Vector2(0, -40), 0.8])
			elif g.faction_of(tm) == "brood" and BroodNew.queen(g, tm):
				pending.append(["base_%d_%s.png" % [tm, _mmss(c)], BroodNew.queen(g, tm).position, 0.8])
		base_i += 1
	if every > 0.0 and c >= _next_every:
		_next_every = c + every
		_every_shots(c)
	if every > 0.0 and c >= _next_stat:
		_next_stat = c + 15.0
		for tm in 2:
			stat_lines.append(_stat_line(c, tm))
	if c >= next_check:
		next_check = c + 2.0
		_look_for_fight(c)
	_event_shots(c)
	if c >= next_wind:
		next_wind = c + 30.0
		_wind_line(c)
	if g.over or c >= end_t:
		_finish()
		return true
	return false


## Every 30 s, the Clockwork army's wind (a Clock Soldier runs down in ~80 s off its gear ground and then stands still):
## how many are run down (statues), low (under 0.2), on gear ground, and how far the run-down ones are from their main.
func _wind_line(c: float) -> void:
	for tm in 2:
		if g.factions[tm] != "clockwork":
			continue
		var n := 0
		var down := 0
		var low := 0
		var field := 0
		var far := 0.0
		var home: Building = g._own_hall(tm)
		for u in g.units:
			if not is_instance_valid(u) or u.dead or u.team != tm or u.is_worker() or u.is_air():
				continue
			n += 1
			if u.powered_down():
				down += 1
				if home:
					far += u.position.distance_to(home.center()) / Game.T
			elif u.wind < 0.2:
				low += 1
			if u._in_field:
				field += 1
		wind_lines.append("%s clockwork army %d: run down %d (avg %.0f tiles from the main), low %d, on gear ground %d" % [_mmss(c), n, down, far / maxf(1, down), low, field])
		_ai_line(c, tm)


## Every 30 s, the Clockwork computer's tech and army (written to <out>/ai.txt): cogs, Tension (and what the Mainsprings
## store), its Works (how many may make Springers, and why the first one may not), the Escapement, the army by kind, the wave.
var ai_lines: Array = []
var nets_seen := {}          # Netter id -> nets fired (the last count seen)
var jumps_seen := {}         # Springer id -> jumps


func _ai_line(c: float, tm: int) -> void:
	var works := 0
	var springer_works := 0
	var why_not := ""
	var esc := "none"
	var queues: Array = []
	var springs := 0
	var store := 0.0
	var army := {}
	for b in g.buildings:
		if b.dead or b.team != tm:
			continue
		if b.kind == Defs.CW_WORKS:
			works += 1
			queues.append("%s%s" % [str(b.queue.size()), ("/" + g.can_train(b, "clock_soldier").left(24)) if b.built and g.can_train(b, "clock_soldier") != "" else ""])
			if b.built:
				var w: String = g.can_train(b, Defs.SPRINGER)
				if w == "" or w.begins_with("Not enough") or w.begins_with("Need more") or w.begins_with("Supply"):
					springer_works += 1
				elif why_not == "":
					why_not = w.left(70)
		elif b.kind == Defs.CW_TECH:
			esc = ("working" if g.has_working(tm, Defs.CW_TECH) else "idle") if b.built else "building"
		elif b.kind == "mainspring":
			springs += 1
	for u in g.units:
		if is_instance_valid(u) and not u.dead and u.team == tm and not u.is_worker():
			army[u.kind] = int(army.get(u.kind, 0)) + 1
			if u.kind == Defs.NETTER:
				nets_seen[u.get_instance_id()] = u.nets
			elif u.kind == Defs.SPRINGER:
				jumps_seen[u.get_instance_id()] = u.jumps
	var nets := 0
	for k in nets_seen:
		nets += int(nets_seen[k])
	var jumps := 0
	for k in jumps_seen:
		jumps += int(jumps_seen[k])
	var ai = null
	for a in g.ais:
		if a.team == tm:
			ai = a
	ai_lines.append("%s cogs %d tension %d | works %d (springers at %d%s) q %s springs %d escapement %s | army %s | nets %d jumps %d | attacking %s siege %s reserve %d" % [_mmss(c),
		int(g.players[tm]["gold"]), int(g.tension(tm)), works, springer_works, (": " + why_not.left(30)) if why_not != "" else "", str(queues), springs, esc, str(army), nets, jumps,
		str(ai._attacking) if ai else "-", ("on" if ai and not ai._siege.is_empty() else "-"), ai._reserve if ai else 0])
	if ai:
		# (why a wave does not go out: the supply it waits for, the army's supply, a threat at home, detachments out)
		ai_lines[-1] += " | attack_at %d army sup %d threat %s det %d" % [ai._attack_at, ai._army_supply(g.army(tm)), str(ai._threat()), ai._det.size()]


## What each soldier in a fight shot is doing (written to <out>/why.txt): its order, what it is after, whether it can
## get at it (walk there with the gates shut) and the AI's siege, to see why an army stands where it stands.
var why: Array = []


func _why_lines(file: String, at: Vector2) -> void:
	if not file.begins_with("fight"):
		return
	why.append("== %s" % file)
	for a in g.ais:
		var sg = a.get("_siege")
		why.append("  team %d attacking %s wave_target %s siege %s" % [a.team, str(a.get("_attacking")), str(a.get("_wave_target")),
			("piece %s at %s stage %s" % [sg["piece"].kind, str(sg["piece"].center()), str(sg["stage"])]) if sg is Dictionary and not sg.is_empty() and is_instance_valid(sg.get("piece")) else "-"])
	for u in g.units:
		if not is_instance_valid(u) or u.dead or u.is_worker() or u.position.distance_to(at) > 500.0:
			continue
		var c = g.cell_of(u.position)
		var tg = u.target
		var ts := "-"
		if is_instance_valid(tg) and not tg.dead:
			var tc = g.cell_of(tg.position if tg.is_unit() else tg.center())
			ts = "%s(t%d) h%d d%.0f canget %s walk %s" % [tg.kind, tg.team, g.height[g.idx(tc)] if g.in_map(tc) else -1, tg.edge_distance(u.position), str(u._can_get_at(tg)), str(u._walk_reaches(tg))]
		why.append("  t%d %s %s h%d v%.0f order %s ot %s goal %s path %d/%d siege %.1f wind %.2f -> %s" % [u.team, u.kind, str(u.position.round()), g.height[g.idx(c)] if g.in_map(c) else -1, u.velocity.length(), u.order,
			(u.order_target.kind if is_instance_valid(u.order_target) else "-"), str(u.path_goal.round()) if u.path_goal != Vector2.INF else "-", u.path_i, u.path.size(), u.siege_t, u.wind, ts])


## The first siege: who was in the wave and the defence when it began, the piece, when it fell.
func _siege_watch() -> void:
	for a in g.ais:
		var sg = a.get("_siege")
		if _siege_t0 < 0.0 and sg is Dictionary and not sg.is_empty() and is_instance_valid(sg.get("piece")) \
				and a._wave_set.keys().filter(func(u) -> bool: return is_instance_valid(u) and not u.dead).size() >= minwave:
			_siege_t0 = g.clock
			_siege_team = a.team
			_siege_piece = sg["piece"]
			for u in a._wave_set.keys():
				if is_instance_valid(u) and not u.dead:
					_siege_wave.append(u)
			for u in g.units:
				if is_instance_valid(u) and not u.dead and u.team != a.team and u.team >= 0:
					if u.is_worker():
						_siege_def_w += 1
					else:
						_siege_def.append(u)
			_siege_lines.append("%s siege begins: team %d's wave of %d (%s) at the %s (%d hp) at %s; defenders %d soldiers (%s), %d workers" % [_mmss(g.clock), a.team, _siege_wave.size(), _kinds(_siege_wave), _siege_piece.kind, int(_siege_piece.hp), str(_siege_piece.center()), _siege_def.size(), _kinds(_siege_def), _siege_def_w])
	if _siege_t0 >= 0.0 and _siege_breach < 0.0 and g.clock >= _siege_next:
		_siege_next = g.clock + 3.0
		var at_face := 0
		var hitting := 0
		for u in _siege_wave:
			if is_instance_valid(u) and not u.dead and is_instance_valid(_siege_piece):
				if _siege_piece.edge_distance(u.position) < 30.0:
					at_face += 1
				if u.target == _siege_piece and u.phase != "":
					hitting += 1
		var defn := 0
		for u in _siege_def:
			if is_instance_valid(u) and not u.dead and is_instance_valid(_siege_piece) and u.position.distance_to(_siege_piece.center()) < 300.0:
				defn += 1
		_siege_lines.append("  %s +%ds: gate %d hp, wave alive %d, at the gate %d, swinging %d, defenders within 300 px %d" % [_mmss(g.clock), int(g.clock - _siege_t0), int(_siege_piece.hp) if is_instance_valid(_siege_piece) and not _siege_piece.dead else 0, _alive(_siege_wave), at_face, hitting, defn])
	if _siege_t0 >= 0.0 and _siege_breach < 0.0 and (not is_instance_valid(_siege_piece) or _siege_piece.dead):
		_siege_breach = g.clock
		_siege_lines.append("%s the %s falls (%d s after the start); wave alive %d, defenders alive %d" % [_mmss(g.clock), "gate", int(g.clock - _siege_t0), _alive(_siege_wave), _alive(_siege_def)])


func _alive(list: Array) -> int:
	return list.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead).size()


func _kinds(list: Array) -> String:
	var n := {}
	for u in list:
		if is_instance_valid(u):
			n[u.kind] = int(n.get(u.kind, 0)) + 1
	var out: Array = []
	for k in n:
		out.append("%d %s" % [n[k], k])
	return ", ".join(out)


## Over: the wave is (almost) gone, or the attacker stopped attacking, or 5 minutes.
func _siege_over() -> bool:
	if g.over or g.clock - _siege_t0 > 300.0:
		return true
	var a = null
	for x in g.ais:
		if x.team == _siege_team:
			a = x
	return _alive(_siege_wave) <= 2 or (a != null and not a._attacking and g.clock - _siege_t0 > 20.0)


func _siege_report() -> void:
	var dead_b: Array = []
	for l in g.mlog.lines:
		var t := str(l)
		if t.contains(" lost a ") and t.contains("to P%d" % (_siege_team + 1)):
			dead_b.append(t)
	_siege_lines.append("%s over (%d s): wave alive %d of %d (%s); defenders alive %d of %d; defender workers now %d; attacker still attacking %s; repairs cancelled %d; defender repair spend %d" % [_mmss(g.clock), int(g.clock - _siege_t0), _alive(_siege_wave), _siege_wave.size(), _kinds(_siege_wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)), _alive(_siege_def), _siege_def.size(), g.workers(1 - _siege_team).size(), str(g.ais.filter(func(x) -> bool: return x.team == _siege_team)[0]._attacking), _siege_cancel, int(float(g.stats[1 - _siege_team].get("repair", 0.0)))])
	_siege_lines.append("buildings the attacker destroyed during the game: %d" % dead_b.size())
	for t in dead_b:
		_siege_lines.append("  " + t)
	var f := FileAccess.open(out.path_join("siege.txt"), FileAccess.WRITE)
	for l in _siege_lines:
		f.store_line(l)
	f.close()


## (crown-v-clockwork-coach) every:N: each side's main hall and the middle of its army (its largest group of soldiers)
func _every_shots(c: float) -> void:
	for tm in 2:
		var h: Building = g._own_hall(tm)
		if h and c > 1.0:
			pending.append(["base_%d_%s.png" % [tm, _mmss(c)], h.global_position + Vector2(0, -40), 0.8])
		var army: Array = []
		for u in g.units:
			if is_instance_valid(u) and not u.dead and u.team == tm and not u.is_worker():
				army.append(u)
		if army.size() < 3:
			continue
		var best: Unit = null
		var bn := 0
		for u in army:
			var k := 0
			for o in army:
				if o.position.distance_to(u.position) < 300.0:
					k += 1
			if k > bn:
				bn = k
				best = u
		var mid := Vector2.ZERO
		var m := 0
		for o in army:
			if o.position.distance_to(best.position) < 300.0:
				mid += o.position
				m += 1
		pending.append(["army_%d_%s.png" % [tm, _mmss(c)], mid / maxf(1, m), 0.9])


func _mmss(c: float) -> String:
	return "%02d%02d" % [int(c) / 60, int(c) % 60]


func _look_for_fight(c: float) -> void:
	FIGHT_GAP = gap_n if c >= gap_from else 25.0
	if c - last_fight < FIGHT_GAP:
		return
	var army: Array = []
	for u in g.units:
		if is_instance_valid(u) and not u.dead and u.kind != String(Defs.FACTIONS[g.factions[u.team]]["worker"]):
			army.append(u)
	var best := 0
	var at := Vector2.ZERO
	for u in army:
		var mine := 0
		var theirs := 0
		for o in army:
			if o.position.distance_to(u.position) < NEAR:
				if o.team == u.team:
					mine += 1
				else:
					theirs += 1
		var s := mini(mine, theirs)
		if s > best:
			best = s
			at = u.position
	if best >= FIGHT_MIN:
		last_fight = c
		pending.append(["fight_%s_%d_%d.png" % [_mmss(c), int(at.x), int(at.y)], at, 1.15])


## A Clockwork computer's moments worth a picture (leap_<MMSS>.png: Springers leaping up, a second after they set off;
## siege_<MMSS>.png: a siege begun, 8 s on), at most one of each kind every 20 s.
var _leap_n := {}
var _siege_on := {}
var _later: Array = []        # [clock, file, at]
var _event_t := {}


func _event_shots(c: float) -> void:
	for a in g.ais:
		var lp = a.get("_leapt")
		if lp is Dictionary:
			var n: int = lp.size()
			if n > int(_leap_n.get(a.team, 0)) and c - float(_event_t.get("leap", -99.0)) > 20.0:
				for u in lp.keys():
					if is_instance_valid(u) and not u.dead:
						_later.append([c + 1.0, "leap_%s.png" % _mmss(c), u])
						_event_t["leap"] = c
						break
			_leap_n[a.team] = n
		var sg = a.get("_siege")
		var on: bool = sg is Dictionary and not sg.is_empty() and is_instance_valid(sg.get("piece"))
		if on and not bool(_siege_on.get(a.team, false)) and c - float(_event_t.get("siege", -99.0)) > 20.0:
			_later.append([c + 8.0, "siege_%s.png" % _mmss(c), sg["piece"]])
			_event_t["siege"] = c
		_siege_on[a.team] = on
	for i in range(_later.size() - 1, -1, -1):
		var e: Array = _later[i]
		if c >= float(e[0]):
			_later.remove_at(i)
			var who = e[2]
			if who is Vector2:
				pending.append([e[1], who, 1.15])       # (a spot: tools/play_crown_1.gd's cliff edge)
			elif is_instance_valid(who) and not who.dead:
				var at: Vector2 = who.position if who is Unit else who.center()
				pending.append([e[1], at, 1.15])


func _shoot() -> void:
	shooting = true
	var p: Array = pending.pop_front()
	var cam: Camera2D = g.camera
	var keep_pos := cam.position
	var keep_zoom := cam.zoom
	cam.position = p[1]
	cam.zoom = Vector2(p[2], p[2])
	cam.reset_smoothing()
	RenderingServer.render_loop_enabled = true     # (drawn normally for a few frames: get_image() gives the last frame drawn)
	for i in shot_frames:
		await process_frame
	print("SHOT %s zoom %s at %s view %s gearvis %s draws %d" % [p[0], str(cam.zoom), str(cam.get_screen_center_position()), str(g.view_rect), str(g.gear_net.is_visible_in_tree()), _draws])
	var img := root.get_viewport().get_texture().get_image()
	if coach:
		img.save_jpg(out.path_join(String(p[0]).replace(".png", ".jpg")), 0.85)
	else:
		img.save_png(out.path_join(p[0]))
	_why_lines(p[0], p[1])
	RenderingServer.render_loop_enabled = live
	cam.position = keep_pos
	cam.zoom = keep_zoom
	shooting = false


func _army_of(tm: int) -> Array:
	var o: Array = []
	for u in g.army(tm):
		if u.dead or u.off_field or u.is_worker() or not u.has_attack() or u.is_air():
			continue
		if u._k_nb and (u.kind == BroodNew.QUEEN or BroodNew.rooted(u)):
			continue
		o.append(u)
	return o


## the densest group's middle (the unit with the most own units within 300 px, then their mean)
func _mid(list: Array) -> Vector2:
	var best: Unit = list[0]
	var bn := -1
	for u in list:
		var n := 0
		for o in list:
			if o.position.distance_to(u.position) < 300.0:
				n += 1
		if n > bn:
			bn = n
			best = u
	var s := Vector2.ZERO
	var k := 0
	for o in list:
		if o.position.distance_to(best.position) < 300.0:
			s += o.position
			k += 1
	return s / maxf(1, k)


func _stat_line(c: float, tm: int) -> String:
	var st: Dictionary = g.stats[tm]
	var v := 0
	var kinds := {}
	for u in _army_of(tm):
		v += Game.unit_value(u)
		kinds[u.kind] = int(kinds.get(u.kind, 0)) + 1
	var rooted := 0
	if g.faction_of(tm) == "brood":
		for u in g.units:
			if u.team == tm and not u.dead and u._k_nb and BroodNew.rooted(u):
				rooted += 1
	var halls := g.halls_of(tm).size()
	if g.faction_of(tm) == "brood":
		var q := BroodNew.queen(g, tm)
		halls = (1 + BroodNew.expansions(g, q).size()) if q else 0
	var au := _army_of(tm)
	var at := _mid(au) if au.size() > 0 else Vector2.ZERO
	var a = null
	for x in g.ais:
		if x.team == tm:
			a = x
	return "%s P%d %s %s income %d bank %d workers %d army %d (%s) rooted %d halls %d supply %d/%d lost %d bld_lost %d at %s%s" % [_mmss(c),
		tm + 1, g.faction_of(tm), a.strategy if a else "?", int(st["gold"]), int(g.players[tm]["gold"]), g.workers(tm).size(), v,
		str(kinds), rooted, halls, g.supply_used(tm), int(g.players[tm]["cap"]), int(st["lost"]), int(st["bld_lost"]), str(at.round()),
		(" push %s" % String(a.push.phase)) if a and ("push" in a) and a.push != null else ""]


func _finish() -> void:
	if every > 0.0:
		var sf := FileAccess.open(out.path_join("stats.txt"), FileAccess.WRITE)
		for l in stat_lines:
			sf.store_line(l)
		sf.close()
		var story := FileAccess.open(out.path_join("story.txt"), FileAccess.WRITE)
		if g.mlog:
			for l in g.mlog.lines:
				var line := str(l)
				for tm in 2:
					var who: String = g.mlog.who(tm)
					var i := line.find(who)
					if i < 0 or i > 12:
						continue
					var rest := line.substr(i + who.length())
					rest = rest.strip_edges(true, false) if not rest.begins_with("'s ") else rest
					var m := AIStoryLines.match_line(rest)
					if not m.is_empty() and String(m["template"]) != "" and int(m["prio"]) >= 2:
						var args: Array = ["P%d %s" % [tm + 1, g.faction_of(tm).capitalize()]] + (m["args"] as Array)
						var tpl := String(m["template"])
						story.store_line("%s %s" % [line.substr(0, 7), tpl % args if tpl.count("%s") == args.size() else tpl])
		story.close()
	var f := FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)
	if g.mlog:
		for l in g.mlog.lines:
			f.store_line(str(l))
	f.close()
	var yf := FileAccess.open(out.path_join("why.txt"), FileAccess.WRITE)
	for l in why:
		yf.store_line(l)
	yf.close()
	var wf := FileAccess.open(out.path_join("wind.txt"), FileAccess.WRITE)
	for l in wind_lines:
		wf.store_line(l)
	wf.close()
	var af := FileAccess.open(out.path_join("ai.txt"), FileAccess.WRITE)
	for l in ai_lines:
		af.store_line(l)
	af.close()
	if coach:
		var cf := FileAccess.open(out.path_join("coach.txt"), FileAccess.WRITE)
		for l in status_lines:
			cf.store_line(l)
		cf.close()
	var r := FileAccess.open(out.path_join("result.txt"), FileAccess.WRITE)
	r.store_line("over %s winner %s clock %.0f" % [str(g.over), str(g.get("winner")), g.clock])
	r.close()


## (crown-v-brood-coach) THE COACH'S EYES: a status line per side every 15 s, the Crown's army filmed every 30 s, the
## mains every 2 minutes.
func _coach_tick(c: float) -> void:
	if c >= next_status:
		next_status = c + 15.0
		for tm in 2:
			status_lines.append(_status(tm, c))
	if c >= next_raid and c < 480.0:
		next_raid = c + 10.0
		for tm in 2:
			if g.faction_of(tm) != "crown":
				continue
			var home: Building = g._own_hall(tm)
			var riders: Array = _mobile(tm).filter(func(u) -> bool: return u.kind in ["cuirassier", "dragoon"] and home != null and u.position.distance_to(home.center()) > 35.0 * Game.T)
			if riders.size() >= 2:
				pending.append(["raid_%s.png" % _mmss(c), _centre(riders), 1.0])
	if c >= next_army:
		next_army = c + 30.0
		for tm in 2:
			if g.faction_of(tm) != "crown":
				continue
			var au := _mobile(tm)
			if au.size() >= 3:
				pending.append(["army_%s.png" % _mmss(c), _centre(au), 0.9])
		if int(c) % 120 < 30 and c > 100.0:
			for tm in 2:
				var h: Building = g._own_hall(tm)
				var at: Vector2 = h.global_position + Vector2(0, -40) if h else Vector2.ZERO
				if g.faction_of(tm) == "brood":
					var q = BroodNew.queen(g, tm)
					at = q.position if q else at
				if at != Vector2.ZERO:
					pending.append(["base_%d_%s.png" % [tm, _mmss(c)], at, 0.75])


func _mobile(tm: int) -> Array:
	var o: Array = []
	for u in g.army(tm):
		if u.dead or u.off_field or u.is_worker() or not u.has_attack():
			continue
		if u._k_nb and (u.kind == BroodNew.QUEEN or BroodNew.rooted(u)):
			continue
		o.append(u)
	return o


func _centre(list: Array) -> Vector2:
	var s := Vector2.ZERO
	for u in list:
		s += u.position
	return s / maxf(1.0, list.size())


func _status(tm: int, c: float) -> String:
	var st: Dictionary = g.stats[tm]
	var au := _mobile(tm)
	var val := 0
	var kinds := {}
	for u in au:
		val += Game.unit_value(u)
		kinds[u.kind] = int(kinds.get(u.kind, 0)) + 1
	var ks: Array = []
	for k in kinds:
		ks.append("%d %s" % [kinds[k], k])
	var halls := 0
	if g.faction_of(tm) == "brood":
		var q = BroodNew.queen(g, tm)
		halls = (1 + BroodNew.expansions(g, q).size()) if q else 0
	else:
		halls = g.halls_of(tm).size()
	var where := "-"
	if not au.is_empty():
		var ctr := _centre(au)
		var home: Building = g._own_hall(tm)
		var dh := ctr.distance_to(home.center()) / Game.T if home else -1.0
		var de := 9999.0
		for e in g.enemies_of(tm):
			for b in g.buildings:
				if b.team == e and not b.dead:
					de = minf(de, ctr.distance_to(b.center()) / Game.T)
			for u in g.units:
				if u.team == e and not u.dead and u._k_nb and (u.kind == BroodNew.QUEEN or BroodNew.rooted(u)):
					de = minf(de, ctr.distance_to(u.position) / Game.T)
		where = "centre %s, %d tiles from its main hall, %d from the enemy's nearest base" % [str(g.cell_of(ctr)), int(dh), int(de)]
	var a = null
	for x in g.ais:
		if x.team == tm:
			a = x
	var extra := ""
	if a:
		extra = " | plan %s attacking %s" % [str(a.strategy), str(a.get("_attacking"))]
	var pw := ""
	if g.faction_of(tm) == "crown":
		pw = " powder %d" % int(float(g.players[tm]["res2"]))
		var busy := {}
		var tot := {}
		for b in g.buildings:
			if b.team == tm and not b.dead and b.built and b.kind in ["town_hall", "barracks", "foundry", "horse_breeder"]:
				tot[b.kind] = int(tot.get(b.kind, 0)) + 1
				if not b.queue.is_empty():
					busy[b.kind] = int(busy.get(b.kind, 0)) + 1
		var bs: Array = []
		for k in tot:
			bs.append("%s %d/%d" % [k, int(busy.get(k, 0)), tot[k]])
		extra += " | busy: " + ", ".join(bs)
		var fc := 0
		var fm := 0
		var mc := 0
		var nf := 0
		for b in g.buildings:
			if b.team == tm and not b.dead and b.built and b.kind == "farm":
				fc += b.crew.size()
				fm += b.crew_max()
				nf += 1
			elif b.team == tm and not b.dead and b.built and b.kind == "powder_mill":
				mc += b.crew.size()
		var ords := {}
		for w in g.workers(tm):
			ords[w.order] = int(ords.get(w.order, 0)) + 1
		extra += " | farms %d crew %d/%d, mills crew %d, orders %s" % [nf, fc, fm, mc, str(ords)]
		if a and a.has_method("foe_estimate"):
			# (the Crown computer's own reckoning: why it trains labourers or not)
			extra += " | reckons %d, army_due %s, owner_labs %s, behind %s, threat %s, reserve %d" % [int(a.foe_estimate()), str(a._army_due()), str(a.owner_labs(g.workers(tm).size())), str(a.army_behind()), str(a._threat() != Vector2.INF), int(a._reserve)]
	return "%s P%d %s: earned %d bank %d%s | workers %d supply %d/%d halls %d | army %d (%s) | killed %d lost %d (value) | army at %s%s" % [_mmss(c), tm + 1, g.faction_of(tm), int(st["gold"]), int(g.players[tm]["gold"]), pw, g.workers(tm).size(), g.supply_used(tm), int(g.players[tm]["cap"]), halls, val, ", ".join(ks), int(st["value_killed"]), _lost_value(tm), where, extra]


## the value the side lost: what its enemies killed of it
func _lost_value(tm: int) -> int:
	var v := 0
	for e in g.enemies_of(tm):
		v += int(g.stats[e]["value_killed"])
	return v
