class_name ReplayMix
extends ReplayPlayer
## Watching a MIXED replay (format 3, docs/replay_mixed.md): the game here is a real one, not a puppet. The keyframe
## before the time asked is put on the map (SaveGame.restore, every unit and building with its recorded id), and the
## match is played on from it by the game's own code: the recorded commands are given at their times, the computers'
## AI plays its side again, and at each next keyframe whatever drifted is put right (every unit glides to where the
## keyframe has it, health, orders, resources, buildings and their queues are set as they were; what the viewer's
## game made that the match didn't have goes, what it is missing comes).
##
## The computers: their AI is not run again. Its decisions are recorded instead (ReplayMixRecorder._diffs: twice a
## second, each computer unit's new order, each computer building's new queue and rally, each new building), and
## given here at their times as a player's commands are. (Running the AI again was tried first: a fresh AI after
## each seek, and an AI that simply decides differently from the one in the match, drifted three times as far: in a
## big battle 95% of units within 263 px after 10 s, against 82 px with the recorded decisions. The AI orders units
## directly, not through the command funnel, so its orders are read off the units rather than caught as commands.)
## A replay without them (recorded before they were added) makes the AI anew at each seek.
##
## Speed: the game's own ticks run faster (Engine.physics_ticks_per_second x speed, each tick still 1/30 s), so 4x
## is four times the work. A seek fast-forwards from the keyframe the same way, as fast as the device can, silently.

const GLIDE_T := 0.5             # a corrected unit glides to its keyframe place in this long
const SNAP := 360.0              # ...unless it is farther than this: it is put there
const FF := 40.0                 # a seek runs the game forward at most this fast
const BASE_TPS := 30
const WORK_STEPS := ["to_site", "to_hall", "mining", "manning"]

var keys: Array = []             # [{t0, t1, data}] (ReplayFile.T_KEY)
var cmd_list: Array = []         # every command: [clock, who, function, args]
var applying := false            # a recorded command is being given (Game.net_forward lets it through)
var cmd_i := 0                   # the next command to give
var next_key := 1                # the next keyframe to correct at
var ff_to := -1.0                # fast-forwarding (a seek) to this time
var ff_ms := 0.0                 # how long the last seek took (real ms)
var corr_ms := 0.0               # how long the last correction took
var n_corrections := 0
var n_run := 0                   # commands given
var n_lost := 0                  # commands whose unit or target couldn't be found
var corr_on := true              # tests: off measures the drift without the keyframes' correction
var last_drift: Array = []       # the last correction: each unit's distance from its keyframe place (px)
var _by_nid := {}                # id -> entity (the keyframe's, and the ones found for the commands)
var _nest: Array = []
var _nest_clk := 0.0
var _outer := ""
var _glides := {}                # unit -> [offset still to go, time left]
var _ff_t0 := 0
var _was_playing := true
var _inc_t := -999.0
var _slots: Array = []
var _resume := false             # a seek reached its time in the middle of a frame: held there till the next


static func play_mixed(g: Game, d: Dictionary) -> ReplayMix:
	var p := ReplayMix.new()
	p.game = g
	p.is_host = false
	p.go_given = true
	p.lead_on = false
	p._m_reset()
	p.name = "ReplayPlayer"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.process_physics_priority = -1000          # (first in each tick: the commands and corrections before the game's own)
	p.data = d
	p.header = d["header"]
	p.footer = d.get("footer", {})
	p.keys = d["keys"]
	p.cmd_list = d.get("cmds", [])
	p.events = d.get("events", [])
	p.me = int(p.header.get("me", -1))
	p.view_only = false
	p.rate = 0.0
	p._slots = (p.header.get("cfg", {}) as Dictionary).get("slots", [])
	p.start_t = float(p.keys[0]["t0"])
	p.length = float(p.footer.get("len", 0.0)) if not p.footer.is_empty() else float(p.keys.back()["t1"])
	p.length = maxf(p.length, float(p.keys.back()["t1"]))
	if not p.cmd_list.is_empty():
		p.length = maxf(p.length, float(p.cmd_list.back()[0]))
	var ver := String(p.header.get("game_version", "?"))
	if ver != String(ProjectSettings.get_setting("application/config/version", "dev")):
		p.version_note = Loc.t("Recorded on v%s: some things may look different.") % ver
	g.replay = p                 # (game.net stays null: this game is the real thing, not an online guest)
	# (pausing a mixed replay pauses the game itself: the camera, the selection and the minimap still work)
	for n in [g.controls, g.spectator, g.camera]:
		if n is Node:
			(n as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	g.add_child(p)
	p.set_speed(1.0)
	p.seek(p.start_t)
	return p


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = BASE_TPS
	Engine.max_physics_steps_per_frame = 8
	Sfx.hush = false


func _process(_delta: float) -> void:
	if _resume:
		_resume = false
		get_tree().paused = not playing
	if get_tree().paused and ff_to < 0.0 and game and game.camera:
		# (paused, nothing is stepped: units the camera comes to take their pose as they are now, replay-render)
		var key := Rect2(game.camera.get_screen_center_position(), game.camera.zoom)
		if key != _pose_view:
			_pose_view = key
			NetPuppet.pose_in_view(game)
	if ff_to >= 0.0:
		changed.emit()           # (the bar shows the seek going)


# ------------------------------------------------------------------ controls

func set_playing(on: bool) -> void:
	if on and at_end:
		seek(start_t)
	playing = on
	if ff_to < 0.0:
		get_tree().paused = not on
	_pose_view = Rect2()       # (paused: the units in view take their pose as they are, replay-render)
	changed.emit()


func set_speed(x: float) -> void:
	speed = x
	if ff_to < 0.0:
		_rate(x)
	changed.emit()


## The game runs x times as fast, each tick as long as in the match (1/30 s): more ticks a second, not longer ones.
func _rate(x: float) -> void:
	Engine.physics_ticks_per_second = maxi(1, roundi(BASE_TPS * x))
	Engine.time_scale = x
	Engine.max_physics_steps_per_frame = clampi(int(ceil(x)) * 4, 8, 120)


func _freeze(on: bool) -> void:
	if is_inside_tree():
		get_tree().paused = on


func seeking() -> bool:
	return ff_to >= 0.0


# ------------------------------------------------------------------ each tick

func _physics_process(delta: float) -> void:
	if game == null or get_tree().paused:
		return
	var clk := game.clock
	while next_key < keys.size() and float(keys[next_key]["t0"]) <= clk + 0.0005:
		var kd := _key(next_key)
		_give_cmds(clk, int(kd.get("seq", cmd_i)))     # (the commands that came before it were in it)
		if corr_on:
			_correct(kd)
		cmd_i = maxi(cmd_i, int(kd.get("seq", cmd_i)))
		next_key += 1
	_give_cmds(clk, cmd_list.size())
	_glide(delta)
	play_t = clk
	rclk = clk
	_post_events(clk)
	if cam_team >= 0:
		_camera()
	if clk - _inc_t >= 1.0:
		_inc_t = clk
		_note_income(clk)
	if ff_to >= 0.0 and clk >= ff_to - 0.0005:
		_ff_end()
	if ff_to < 0.0 and clk >= length - 0.001 and not at_end:
		at_end = true
		playing = false
		get_tree().paused = true
		changed.emit()


func _give_cmds(clk: float, upto: int) -> void:
	while cmd_i < mini(upto, cmd_list.size()) and float(cmd_list[cmd_i][0]) <= clk + 0.0005:
		var c: Array = cmd_list[cmd_i]
		cmd_i += 1
		if not _nest.is_empty():
			if String(c[2]) == String(_nest[0]) and absf(float(c[0]) - _nest_clk) < 0.0005:
				_nest.pop_front()
				continue         # (called by the one before it: run then already)
			_nest.clear()
		_give(c)


## One recorded command, as the player gave it.
func _give(c: Array) -> void:
	var fn := String(c[2])
	if fn == "#b":
		_new_building(c[3])          # (its id is in it: it isn't looked up)
		return
	var who = game if typeof(c[1]) == TYPE_INT else _dec(c[1])
	if who == null or not is_instance_valid(who) or (who is Entity and (who as Entity).dead):
		n_lost += 1
		return
	if not (c[3] is Array):
		n_lost += 1
		return
	var args: Array = []
	for x in c[3]:
		args.append(_dec(x))         # (an argument that is gone stays as null in its place; inside a list it is left out)
	_nest = []
	_nest_clk = float(c[0])
	_outer = fn
	applying = true
	game.net_quiet = true        # (no ring on the ground, no voice: as an online guest's order on the host)
	if fn.begins_with("#"):
		_decision(fn, args)
	elif fn.begins_with("@"):
		if (args as Array).size() == 1:
			(who as Object).set(fn.substr(1), args[0])
	elif (who as Object).has_method(fn):
		(who as Object).callv(fn, args)
	game.net_quiet = false
	applying = false
	n_run += 1


## A computer's decision (ReplayMixRecorder._diffs): a unit's new order, a building's queue and rally.
func _decision(fn: String, a: Array) -> void:
	match fn:
		"#x":
			var x = a[0] if not a.is_empty() else null
			if x is Unit and is_instance_valid(x) and not x.dead and not _away(x):
				x.hp = 0.0
				x.die()
		"#o":
			var u = a[0]
			if not (u is Unit) or not is_instance_valid(u) or u.dead or _away(u):
				n_lost += 1
				return
			_order(u, String(a[1]), a[2], a[3])
		"#q":
			var b = a[0]
			if not (b is Building) or not is_instance_valid(b) or b.dead:
				n_lost += 1
				return
			_set_queue(b, a[1], a[2])
			b.rally = a[3]
			b.worker_rally = a[4]


## A computer's new building (a site it placed): made here with its id, unless the place is taken.
func _new_building(a: Array) -> void:
	var nid := int(a[5])
	var e = _by_nid.get(nid)
	if e != null and is_instance_valid(e) and not e.dead:
		return
	var k := String(a[0])
	if not Defs.BUILDINGS.has(k):
		return
	var c: Vector2i = a[2]
	for b in game.buildings:
		if is_instance_valid(b) and not b.dead and b.team == int(a[1]) and b.kind == k and b.cell == c:
			if b.net_id == 0:
				b.net_id = nid
				_by_nid[nid] = b
			return
	if game.placement_problem(int(a[1]), k, c) != "":
		n_lost += 1
		return
	var nb := _make_building({"k": k, "t": int(a[1]), "c": [c.x, c.y], "built": bool(a[3]), "ghost": bool(a[4]), "nid": nid})
	if nb:
		_by_nid[nid] = nb
		game._astar_dirty = true


## Game.net_forward while a command runs: the funnel calls it calls in turn were recorded after it, and are skipped.
func nested(fn: String) -> void:
	if not applying:
		return
	if _outer != "" and fn == _outer:
		_outer = ""              # (the command's own first line)
		return
	_nest.append(fn)


func _dec(v):
	if v is Dictionary:
		if v.size() == 1 and v.has("r") and v["r"] is Array:
			return _ref(v["r"])
		var od := {}
		for k in v:
			od[k] = _dec(v[k])
		return od
	if v is Array:
		var out: Array = []
		for x in v:
			var y = _dec(x)
			if x is Dictionary and (x as Dictionary).has("r") and y == null:
				continue         # (a unit of a list that is gone here: left out, as online)
			out.append(y)
		return out
	return v


## An entity of a command: by its id, else (the viewer's game made it without one) the nearest of its kind and side
## near where it was, which takes the id from then on.
func _ref(r: Array):
	var id := int(r[0])
	if _by_nid.has(id):
		var e = _by_nid[id]
		return e if e != null and is_instance_valid(e) and not e.dead else null      # (known, and gone: not another one)
	var k := String(r[1])
	var t := int(r[2])
	var p := Vector2(float(r[3]), float(r[4]))
	var best: Entity = null
	var bd := 260.0 * 260.0
	var list: Array = game.buildings if Defs.BUILDINGS.has(k) and not Defs.UNITS.has(k) else game.units
	for x in list:
		if not is_instance_valid(x) or x.dead or x.net_id != 0 or x.team != t or String(x.kind) != k:
			continue
		var d2: float = x.position.distance_squared_to(p)
		if d2 < bd:
			bd = d2
			best = x
	if best == null:
		return null
	best.net_id = id
	_by_nid[id] = best
	return best


func _key(i: int) -> Dictionary:
	return ReplayFile.unpack_key(keys[i]["data"])


# ------------------------------------------------------------------ the keyframes put right

## The match as the keyframe has it, on the running game: what both have is set as the keyframe says (units glide),
## what only the viewer's game has goes, what only the keyframe has is made.
func _correct(kd: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	var d: Dictionary = kd.get("save", {})
	if d.is_empty():
		return
	n_corrections += 1
	last_drift = []
	_set_players(d)
	if d.has("ground") and game.land():
		game.ground_layer.load(d["ground"])      # (THE GROUND SYSTEM: the keyframe's soil and brass, exactly)
	var live := {}
	for e in game.buildings + game.units:
		if is_instance_valid(e) and not e.dead and e.net_id != 0:
			live[e.net_id] = e
	# buildings
	var want_b := {}
	for bd in d.get("buildings", []):
		want_b[int(bd.get("nid", 0))] = bd
	var spare_b := {}            # kind:team:cell -> a building of the viewer's own (no id) that may be the keyframe's
	for b in game.buildings.duplicate():
		if not is_instance_valid(b) or b.dead:
			continue
		if b.net_id == 0:
			spare_b["%s:%d:%d:%d" % [b.kind, b.team, b.cell.x, b.cell.y]] = b
		elif not want_b.has(b.net_id):
			_drop_building(b)
	var changed_b := false
	for nid in want_b:
		var bd: Dictionary = want_b[nid]
		var b = live.get(nid)
		if b is Building and (b.kind != String(bd["k"]) or b.cell != Vector2i(int(bd["c"][0]), int(bd["c"][1]))):
			_drop_building(b)
			b = null
		if b == null:
			var sk := "%s:%d:%d:%d" % [String(bd["k"]), int(bd["t"]), int(bd["c"][0]), int(bd["c"][1])]
			b = spare_b.get(sk)
			if b != null:
				spare_b.erase(sk)
				b.net_id = int(nid)
		if b != null and (bool(b.built) != bool(bd["built"]) or bool(b.ghost) != bool(bd.get("ghost", false))):
			_drop_building(b)
			b = null
		if b == null:
			b = _make_building(bd)
			changed_b = true
			if b == null:
				continue
		_set_building(b, bd)
		_by_nid[int(nid)] = b
	for sk in spare_b:
		_drop_building(spare_b[sk])
		changed_b = true
	# units
	var want_u := {}
	for ud in d.get("units", []):
		want_u[int(ud.get("nid", 0))] = ud
	var spare_u := {}            # kind:team -> the viewer's own units with no id
	for u in game.units.duplicate():
		if not is_instance_valid(u) or u.dead or _away(u):
			continue
		if u.net_id == 0:
			var sk := "%s:%d" % [u.kind, u.team]
			if not spare_u.has(sk):
				spare_u[sk] = []
			spare_u[sk].append(u)
		elif not want_u.has(u.net_id):
			_drop_unit(u)
	var made: Array = []
	for nid in want_u:
		var ud: Dictionary = want_u[nid]
		var k := SaveGame._kind(String(ud["k"]))
		var u = live.get(nid)
		if u is Unit and (u.kind != k or u.team != int(ud["t"])):
			_drop_unit(u)
			u = null
		var at := SaveGame._to_v2(ud["p"])
		if u == null:
			var cand: Array = spare_u.get("%s:%d" % [k, int(ud["t"])], [])
			var bi := -1
			var bdist := 260.0
			for i in cand.size():
				var dd: float = (cand[i] as Unit).position.distance_to(at)
				if dd < bdist:
					bdist = dd
					bi = i
			if bi >= 0:
				u = cand[bi]
				cand.remove_at(bi)
				u.net_id = int(nid)
		if u == null:
			if not Defs.UNITS.has(k):
				continue
			u = game._add_unit(k, int(ud["t"]), at)
			u.net_id = int(nid)
			made.append(u)
			_set_unit_new(u, ud)
		elif not _away(u):
			var off: Vector2 = at - u.position
			last_drift.append(off.length())
			if off.length() > SNAP:
				u.position = at
				u.reset_physics_interpolation()
				game.note_move(u)
				_glides.erase(u)
			elif off.length() > 0.5:
				_glides[u] = [off, GLIDE_T]
		u.hp = minf(float(ud["hp"]), u.max_hp)
		_by_nid[int(nid)] = u
	for sk in spare_u:
		for u in spare_u[sk]:
			_drop_unit(u)
	for nid in want_u:
		var u = _by_nid.get(int(nid))
		if u is Unit and is_instance_valid(u) and not u.dead:
			_set_order(u, want_u[nid])
	for t in game.n_players():
		game._recount_supply(t)
	if changed_b:
		game._astar_dirty = true
		game.fog_base_dirty = true
	game.over = bool(kd.get("over", false)) and game.over
	corr_ms = (Time.get_ticks_usec() - t0) / 1000.0


## A unit the keyframe doesn't list on its own: in a balloon, taken to a building, off the field a moment.
func _away(u: Unit) -> bool:
	return u.off_field or u.aboard != null or (u.kind == "horse" and is_instance_valid(u.into) and u.into is Building)


func _set_players(d: Dictionary) -> void:
	for t in mini(game.players.size(), (d.get("players", []) as Array).size()):
		var p: Dictionary = d["players"][t]
		for k in p:
			game.players[t][k] = Array(p[k]) if k == "split" else p[k]
		game.players[t]["gold"] = int(p["gold"])
		game.players[t]["cap"] = int(p["cap"])
	for t in mini(game.stats.size(), (d.get("stats", []) as Array).size()):
		var st: Dictionary = d["stats"][t]
		for k in st:
			game.stats[t][k] = st[k]
	for t in mini(game.eliminated.size(), (d.get("eliminated", []) as Array).size()):
		game.eliminated[t] = bool(d["eliminated"][t])


func _drop_unit(u: Unit) -> void:
	_glides.erase(u)
	if u.net_id != 0:
		_by_nid[u.net_id] = null         # (gone: a command naming it later finds nothing, not another one)
	NetSnapshot._unit_gone(game, u)


func _drop_building(b: Building) -> void:
	if b.net_id != 0:
		_by_nid[b.net_id] = null
	NetSnapshot._building_gone(game, b, false)


func _make_building(bd: Dictionary) -> Building:
	var k := String(bd["k"])
	if not Defs.BUILDINGS.has(k):
		return null
	var c := Vector2i(int(bd["c"][0]), int(bd["c"][1]))
	var b := game._add_building(k, int(bd["t"]), c, bool(bd["built"]), bool(bd.get("ghost", false)))
	b.net_id = int(bd.get("nid", 0))
	if k == "gate" or bool(Defs.BUILDINGS[k].get("line", false)):
		game.relink_walls(c)
	return b


## What a building's saved row says, as SaveGame.restore puts it (the parts that change in a match).
func _set_building(b: Building, bd: Dictionary) -> void:
	b.progress = float(bd["progress"])
	b.hp = minf(float(bd["hp"]), b.max_hp) if b.max_hp > 0.0 else float(bd["hp"])
	_set_queue(b, bd["queue"], bd.get("kits", []))
	b.prod_t = float(bd["prod_t"])
	b.auto_train = SaveGame._kind(String(bd.get("auto", "")))
	b.auto_refit = bool(bd.get("ar", false))
	b.batteries = int(bd.get("bat", 0))
	b.stock = float(bd.get("stock", 0.0))
	b.growth = float(bd["growth"])
	b.gold_acc = float(bd["gold_acc"])
	b.seeded = bool(bd["seeded"])
	if b.kind == "town_hall" or b.kind == "clocktower":
		b.soil = float(bd.get("soil", b.soil))
	if bd.has("lode") and b.lode_full() > 0.0:
		b.lode = float(bd["lode"])
	b.rally = SaveGame._to_v2(bd["rally"]) if bd["rally"] != null else Vector2.INF
	b.worker_rally = SaveGame._to_v2(bd["wrally"]) if bd["wrally"] != null else Vector2.INF


func _set_queue(b: Building, qa, ka) -> void:
	var q: Array = Array(qa) if qa is Array else []
	if str(q) == str(b.queue):
		return
	var kits: Array = Array(ka) if ka is Array else []
	var keep_t := not b.queue.is_empty() and not q.is_empty() and str(b.queue[0]) == str(q[0])
	var pt := b.prod_t
	b.queue = []
	b.kits = []
	for qi in q.size():
		var x := String(q[qi]) if String(q[qi]).begins_with("@") else SaveGame._kind(String(q[qi]))
		if Defs.RESEARCH.has(x.substr(1)) if x.begins_with("@") else Defs.UNITS.has(x):
			b.add_entry(x, kits[qi] if qi < kits.size() and kits[qi] is Dictionary else {})
	if keep_t:
		b.prod_t = pt                # (the one being made goes on where it was)


## A unit the keyframe has and the viewer's game didn't: made as the save makes it (its main values).
func _set_unit_new(u: Unit, ud: Dictionary) -> void:
	if Defs.ARMOURED.has(u.kind) and ud.get("kit") is Dictionary:
		u.set_kit(ud["kit"])
	u.facing = SaveGame._to_v2(ud["f"])
	u.wind = float(ud.get("wind", u.wind))
	u.charge = float(ud.get("charge", u.charge))
	u.mode = String(ud.get("mode", u.mode))
	u.carrying = int(ud.get("carry", 0))
	u.powder = float(ud.get("pw", u.powder))
	u.auto_work = bool(ud.get("auto", u.auto_work))
	u.kills = int(ud.get("kills", 0))


## The order it had in the keyframe, given again when the viewer's game has it doing something else.
func _set_order(u: Unit, ud: Dictionary) -> void:
	var o = ud.get("o")
	if not (o is Array) or (o as Array).size() < 3 or _away(u):
		return
	var ord := String(o[0])
	var p := SaveGame._to_v2(o[1])
	var tgt = _by_nid.get(int(o[2])) if int(o[2]) != 0 else null
	_order(u, ord, p, tgt)
	# a worker: the step of its round it was at (on its way, at work, carrying back) and what it carries
	var wk = ud.get("wk")
	if ord == "gather" and u.order == "gather" and wk is Array and String(wk[0]) in WORK_STEPS:
		u.work = String(wk[0])
		u.work_t = float(wk[1])
		u.carrying = int(ud.get("carry", u.carrying))
		u.load_f = float(ud.get("lf", u.load_f))


## Give `u` order `ord` (to point p or target tgt) unless it has it already.
func _order(u: Unit, ord: String, p: Vector2, tgt) -> void:
	if tgt != null and (not is_instance_valid(tgt) or tgt.dead):
		tgt = null
	match ord:
		"move", "amove", "patrol":
			if u.order != ord or u.order_point.distance_to(p) > 48.0:
				u._start({"o": ord, "p": p})
		"attack", "build", "repair", "gather":
			var now = u.order_target if u.order_target != null and is_instance_valid(u.order_target) else (u.home_mine if ord == "gather" else null)
			if tgt != null and (u.order != ord or now != tgt):
				u._start({"o": ord, "e": tgt})
		"hold":
			if u.order != "hold":
				u._start({"o": "hold"})
		"idle":
			if u.order in ["move", "amove", "attack"]:
				u.cmd_stop()


## Corrected units on their way to their keyframe places (as well as walking where the game takes them).
func _glide(delta: float) -> void:
	if _glides.is_empty():
		return
	var gone: Array = []
	for u in _glides:
		if not is_instance_valid(u) or u.dead:
			gone.append(u)
			continue
		var gl: Array = _glides[u]
		var step := minf(delta, float(gl[1]))
		u.position += (gl[0] as Vector2) * (step / GLIDE_T)
		game.note_move(u)
		gl[1] = float(gl[1]) - step
		if float(gl[1]) <= 0.0001:
			gone.append(u)
	for u in gone:
		_glides.erase(u)


# ------------------------------------------------------------------ seeking

## Jump to match time `t`: the keyframe before it is put on the map, the computers' AI made anew, and the game runs
## forward to t as fast as it can (no sound).
func seek(t: float) -> void:
	t = clampf(t, start_t, length)
	var back := t < play_t
	var k := 0
	for i in keys.size():
		if float(keys[i]["t0"]) <= t + 0.001:
			k = i
	_ff_t0 = Time.get_ticks_usec()
	var kd := _key(k)
	var cam_p := game.camera.position
	var cam_z := game.camera.zoom
	_clear_world()
	_glides.clear()
	_by_nid.clear()
	_fresh_ais()
	var d: Dictionary = kd.get("save", {})
	d["camera"] = [cam_p.x, cam_p.y]
	d["zoom"] = cam_z.x
	Sfx.hush = true
	SaveGame.restore(game, d)
	game.camera.position = cam_p
	game.camera.zoom = cam_z
	game.over = false
	for e in game.buildings + game.units:
		if is_instance_valid(e) and e.net_id != 0:
			_by_nid[e.net_id] = e
	for ud in d.get("units", []):
		var u = _by_nid.get(int(ud.get("nid", 0)))
		if u is Unit:
			_set_order(u, ud)
	cmd_i = int(kd.get("seq", 0))
	next_key = k + 1
	_nest = []
	play_t = game.clock
	rclk = game.clock
	_income = {}
	_inc_t = -999.0
	_cams = {}
	at_end = false
	# the chat and the AI STORY up to t; the recorded cameras up to t
	_ev = 0
	if game.chat:
		game.chat.lines.clear()
	if game.ai_story:
		game.ai_story.clear()
		game.ai_story.silent = true
	while _ev < events.size() and float(events[_ev][0]) <= t:
		var e: Array = events[_ev]
		_ev += 1
		_past_event(e, t)
	if game.ai_story:
		game.ai_story.silent = false
	if back:
		for ex in game.explored_by:
			(ex as PackedByteArray).fill(0)
	game.swamp_dirty = true
	game.fog_base_dirty = true
	game._rebuild_hash()
	game.refresh_fog()
	for u in game.units:
		u.reset_physics_interpolation()
	if t - game.clock > 0.02:
		ff_to = t
		_was_playing = playing
		_rate(FF)
		get_tree().paused = false
	else:
		ff_to = -1.0
		Sfx.hush = false
		ff_ms = (Time.get_ticks_usec() - _ff_t0) / 1000.0
		get_tree().paused = not playing
	if cam_team >= 0:
		_camera()
	changed.emit()


func _ff_end() -> void:
	ff_to = -1.0
	Sfx.hush = false
	_rate(speed)
	ff_ms = (Time.get_ticks_usec() - _ff_t0) / 1000.0
	playing = _was_playing
	get_tree().paused = true     # (the frame's other ticks, already counted at FF, don't run: it stops on the time)
	_resume = true
	_pose_view = Rect2()         # (the jump's units in view take their pose: replay-render)
	changed.emit()


func _past_event(e: Array, t: float) -> void:
	match String(e[1]):
		"ai":
			if game.ai_story:
				game.ai_story.from_event(e)
		"chat":
			if game.chat and float(e[0]) > t - Chat.SHOW_SECS:
				game.chat.post(int(e[2]), String(e[3]))
		"cam":
			_cam_ev(e)


func _post_events(t: float) -> void:
	while _ev < events.size() and float(events[_ev][0]) <= t:
		var e: Array = events[_ev]
		_ev += 1
		var kind := String(e[1])
		if kind == "cam":
			_cam_ev(e)
		elif ff_to >= 0.0:
			_past_event(e, ff_to)
		elif kind == "chat" and game.chat:
			game.chat.post(int(e[2]), String(e[3]))
		elif kind == "ai" and game.ai_story:
			game.ai_story.from_event(e)
		elif kind == "out" and game.hud and int(e[2]) < game.n_players():
			game.hud.toast(Loc.t("P%d %s is out.") % [int(e[2]) + 1, game.faction_of(int(e[2])).capitalize()], false)
		elif kind == "end":
			end_winner = int(e[2])
			if game.hud:
				var w := int(e[2])
				game.hud.toast(Loc.t("%s wins") % ("P%d %s" % [w + 1, game.faction_of(w).capitalize()]) if w >= 0 and w < game.n_players() else Loc.t("no winner"), false)


## A recorded camera (twice a second when it moved): the view glides from the last one.
func _cam_ev(e: Array) -> void:
	var team := int(e[2])
	var v = e[3]
	if not (v is Vector3):
		return
	var c: Array = _cams.get(team, [[], [], null])
	var was = c[2] if c[2] != null else v
	var was_t: float = float(c[1][0]) if not (c[1] as Array).is_empty() else float(e[0])
	_cams[team] = [[was_t, was], [float(e[0]) + 0.5, v], v]


## The computers' AI: none when the replay has their decisions (ReplayMixRecorder._diffs); else made anew for each
## computer side (as Main makes it at the start of a match).
func _fresh_ais() -> void:
	for ai in game.ais:
		if is_instance_valid(ai):
			ai.queue_free()
	game.ais.clear()
	if header.has("auto_teams"):
		return
	var cfg: Dictionary = header.get("cfg", {})
	for t in _slots.size():
		var sl: Dictionary = _slots[t]
		var lvl := ["easy", "normal", "hard", "brutal"].find(String(sl.get("who", "")))
		if lvl < 0 or t >= game.n_players():
			continue
		var f := game.faction_of(t)
		var ai: AI = AIBroodNew.new() if f == "brood" else (AIClockwork.new() if f == "clockwork" else (AICrown.new() if f == "crown" else AI.new()))
		ai.game = game
		ai.team = t
		ai.difficulty = lvl
		var strat := String(sl.get("strategy", "balanced"))
		if not AI.strategies_for(f).has(strat):
			strat = "balanced"
		ai.strategy = strat
		ai.peaceful = bool(cfg.get("lab", false))
		game.add_child(ai)
		game.ais.append(ai)


# ------------------------------------------------------------------ the observer bar

func _note_income(clk: float) -> void:
	for t in game.n_players():
		var h: Array = _income.get(t, [])
		h.append([clk, int(game.stats[t]["gold"]), int(float(game.stats[t].get("res2_in", 0.0)))])
		while h.size() > 2 and float(h[1][0]) < clk - 60.0:
			h.pop_front()
		_income[t] = h
