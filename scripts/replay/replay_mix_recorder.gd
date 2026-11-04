class_name ReplayMixRecorder
extends ReplayRecorder
## A MIXED replay (docs/replay_mixed.md), StarCraft 2's way plus keyframes: instead of pictures of every unit a few times
## a second it keeps
##   - every player's COMMANDS, with their game times (everything a player orders goes through the command funnel,
##     Game.net_forward / net_set: NetCommands), and
##   - one KEYFRAME, the whole match as a save keeps it (SaveGame.capture, with each unit's and building's id and its
##     order), every KEY_SECS.
## Watching it (ReplayMix) puts the keyframe before the time asked on the map and runs the real game from there with
## the recorded commands; each next keyframe corrects whatever drifted. The computers' decisions are not commands (their
## AI orders units directly): twice a second what changed in their units' orders and their buildings' queues is
## written down with the commands (_diffs), and the viewer gives those instead of running the AI.
## Recording costs a keyframe every 10 s, a look at the computers' units twice a second, and the commands.

const FORMAT_MIXED := 3
## Commands written as [clock, kind, who, function, args]; an entity in them as {"r": [id, kind, team, x, y]} (the
## viewer finds it by its id, or by kind, side and place when the viewer's game made it with no id: ReplayMix._ref).

var cmds: Array = []             # since the last keyframe: [clock, who, fn, args]
var n_cmds := 0                  # every entry so far, the computers' too (a keyframe says how many came before it: the viewer goes on from there)
var n_player := 0                # ...of which the players' own commands
var n_dropped := 0               # commands that couldn't be written (a Callable in them: a Shift-queued card button)
var key_us := 0                  # building the keyframes (SaveGame.capture), in all
var pack_us := 0                 # ...packing and writing them
var cmd_us := 0                  # ...writing down the commands
var bytes_keys := 0
var bytes_cmds := 0
var _key_due := false
## The computers' decisions (their AI orders units directly, not through the funnel): every DIFF_SECS each computer
## unit's order and each computer building's queue is looked at, and what changed is written down with the commands
## ("#o" an order, "#q" a queue and rally, "#b" a new building). The viewer runs no AI: it gives these instead.
const DIFF_SECS := 0.5
var auto_teams: Array = []       # the sides no person plays (computers, a mission's scripted side)
var diff_us := 0                 # ...looking for them
var n_diffs := 0
var _diff_t := -999.0
var _osig := {}                  # unit -> [order, x, y, target]
var _bsig := {}                  # building -> [its queue's hash, rally, worker rally]
var _auto := PackedByteArray()   # team -> 1 for a computer side
var _gone := {}                  # the dead whose death is written down
var _camrec_t := -999.0
var _cfg := {}


## Start a mixed recording of `g` (a skirmish, a watched match, a campaign mission, an online host: never a guest,
## whose game simulates nothing).
static func start_mixed(g: Game, cfg: Dictionary, me: int) -> ReplayMixRecorder:
	var r := ReplayMixRecorder.new()
	r.rate = 0.0
	r.game = g
	r.is_host = true
	r.my_team = me
	r.go_given = true
	r.fx_max = 0                 # (no pictures: the effects the game reports for them are dropped at once)
	r._m_reset()
	r.name = "ReplayRecorder"
	r.path = ReplayFile.new_path("")
	var c := cfg.duplicate(true)
	c.erase("net")
	c.erase("resume")
	r._cfg = c
	var names: Array = []
	for t in g.n_players():
		var nm := "P%d %s" % [t + 1, g.faction_of(t).capitalize()]
		var who := String((c.get("slots", []) as Array)[t].get("who", "")) if t < (c.get("slots", []) as Array).size() else ""
		if t == me:
			nm += " (you)"
		elif who in ["easy", "normal", "hard", "brutal"]:
			nm += " (%s AI)" % who
		names.append(nm)
		if not (who in ["you", "remote"]) and t != me:
			r.auto_teams.append(t)
	r.header = {"format": FORMAT_MIXED, "mode": "mixed", "game_version": String(ProjectSettings.get_setting("application/config/version", "dev")),
		"cfg": c, "me": me, "names": names, "date": int(Time.get_unix_time_from_system()), "map_name": g.map_name,
		"online": "host" if g.net != null else "", "view_only": false, "sandbox": g.sandbox, "cw_roster": Defs.cw_roster,
		"rate": 0.0, "key_secs": KEY_SECS, "t0": snappedf(g.clock, 0.01),
		"auto_teams": r.auto_teams, "diff_secs": DIFF_SECS}
	if String(c.get("map", "")).begins_with("custom:"):
		r.header["custom_map"] = MapGen.load_custom(String(c["map"]).substr(7))
	r.written = ReplayFile.begin(r.path, r.header)
	if r.written:
		ReplayFile.write_meta(r.path, ReplayFile.meta_from(r.header, {}, r.path))
	r.process_physics_priority = -1000
	g.rec = r
	g.add_child(r)
	r.key()                      # (the start, before the first tick: the viewer starts here)
	return r


func _physics_process(_delta: float) -> void:
	if done or not written:
		return
	if game.clock - last_key >= KEY_SECS - 0.0005:
		_key_due = true
	if game.clock - _diff_t >= DIFF_SECS - 0.0005 and not auto_teams.is_empty():
		_diff_t = game.clock
		_diffs()
	# the recording player's camera, twice a second when it moved ("follow my camera")
	if game.clock - _camrec_t >= 0.5:
		_camrec_t = game.clock
		var cam := Vector3(snappedf(game.camera.position.x, 1.0), snappedf(game.camera.position.y, 1.0), snappedf(game.camera.zoom.x, 0.01))
		if cam != _cam_was:
			_cam_was = cam
			events.append([snappedf(game.clock, 0.01), "cam", my_team, cam])
		for ct in _cams_new:
			events.append([snappedf(game.clock, 0.01), "cam", int(ct), _cams_new[ct]])
		_cams_new = {}


## The keyframe is taken on a frame with no game tick when there is one (as the pictures were: ReplayRecorder._process).
func _process(_delta: float) -> void:
	var pf := Engine.get_physics_frames()
	var ticked := pf != _pf_seen
	_pf_seen = pf
	if not _key_due or done or not written:
		return
	_due_frames += 1
	if ticked and _due_frames < 3:
		return
	_key_due = false
	_due_frames = 0
	key()


## Never pictures (ReplayRecorder.record): a keyframe is this recording's only snapshot.
func record(_force_key := false) -> void:
	pass


# ------------------------------------------------------------------ the commands

## A command ran (Game.net_forward / net_set, a player's own or an online guest's): written down with its time.
func note_cmd(who: Object, fn: String, args: Array) -> void:
	if done or not written:
		return
	var t0 := Time.get_ticks_usec()
	var ok := [true]
	var w = 0 if who == game else _enc(who, ok)
	var a: Array = []
	for x in args:
		a.append(_enc(x, ok))
	if ok[0]:
		cmds.append([snappedf(game.clock, 0.0001), w, fn, a])
		n_cmds += 1
		n_player += 1
	else:
		n_dropped += 1
	cmd_us += Time.get_ticks_usec() - t0
	cost_us += Time.get_ticks_usec() - t0


## An argument as it can be written: an entity by its id (with its kind, side and place, so the viewer finds one its
## own game made), lists and dictionaries element by element; a Callable or another object can't be.
func _enc(v, ok: Array):
	if v is Entity:
		if not is_instance_valid(v):
			return null
		assign(v)
		var e: Entity = v
		return {"r": [e.net_id, String(e.get("kind")), e.team, roundi(e.position.x), roundi(e.position.y)]}
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(_enc(x, ok))
		return out
	if v is Dictionary:
		var od := {}
		for k in v:
			od[k] = _enc(v[k], ok)
		return od
	if v is Object or v is Callable or v is Signal:
		ok[0] = false
		return null
	return v


## The computers' new orders, queues and buildings since the last look.
func _diffs() -> void:
	var t0 := Time.get_ticks_usec()
	var clk := snappedf(game.clock, 0.0001)
	var ok := [true]
	if _auto.size() != game.n_players():
		_auto.resize(game.n_players())
		for t in game.n_players():
			_auto[t] = 1 if auto_teams.has(t) else 0
	for b in game.buildings:
		if not is_instance_valid(b) or b.dead or b.team < 0 or _auto[b.team] == 0:
			continue
		var sig := [b.queue.hash(), b.rally, b.worker_rally]
		var bw = _bsig.get(b.get_instance_id())
		if bw != null and bw[0] == sig[0] and bw[1] == sig[1] and bw[2] == sig[2]:
			continue
		if bw == null and b.net_id == 0:
			assign(b)
			cmds.append([clk, 0, "#b", [String(b.kind), b.team, b.cell, bool(b.built), bool(b.ghost), b.net_id]])
			n_diffs += 1
			n_cmds += 1
		_bsig[b.get_instance_id()] = sig
		cmds.append([clk, 0, "#q", [_enc(b, ok), b.queue.duplicate(), _enc(b.kits.map(func(kt): return SaveGame._kit_save(kt)), ok), b.rally, b.worker_rally]])
		n_diffs += 1
		n_cmds += 1
	for u in game.units:
		if u.dead:
			# a death, any side's: the replay's unit falls then too (in a big fight the replay's own fight would
			# otherwise keep it standing until the next keyframe, and the fights around it go differently)
			var did: int = u.get_instance_id()
			if not _gone.has(did):
				_gone[did] = true
				cmds.append([clk, 0, "#x", [_enc(u, ok)]])
				n_diffs += 1
				n_cmds += 1
			continue
		if u.off_field:
			continue
		var tm: int = u.team
		if tm < 0 or _auto[tm] == 0 or u.aboard != null:
			continue
		var uid: int = u.get_instance_id()
		var was = _osig.get(uid)
		var op: Vector2 = u.order_point
		if was != null and was[0] == u.order and (was[1] as Vector2).distance_squared_to(op) < 256.0:
			# (the same order, to within half a tile: a new target only counts for work, not in a fight, where a unit
			# picks the next one itself)
			if u.order != "gather" and u.order != "build" and u.order != "repair":
				continue
			var tn: int = u.order_target.get_instance_id() if u.order_target != null and is_instance_valid(u.order_target) else 0
			if tn == int(was[2]):
				continue
		var ot = u.order_target if u.order_target != null and is_instance_valid(u.order_target) else null
		_osig[uid] = [u.order, op, ot.get_instance_id() if ot != null else 0]
		if u.order == "idle" and (was == null or (was[0] in ["move", "amove"] and u.position.distance_squared_to(was[1]) < 4096.0)):
			continue             # (new and idle, or there: it stops by itself in the replay too)
		cmds.append([clk, 0, "#o", [_enc(u, ok), u.order, op.round(), _enc(ot, ok) if ot is Entity else null]])
		n_diffs += 1
		n_cmds += 1
	diff_us += Time.get_ticks_usec() - t0
	cost_us += Time.get_ticks_usec() - t0


# ------------------------------------------------------------------ the keyframes

## The whole match now (SaveGame.capture with every id and order), written with the commands and events before it.
func key() -> void:
	if done or not written:
		return
	var t0 := Time.get_ticks_usec()
	for b in game.buildings:
		if is_instance_valid(b) and not b.dead:
			assign(b)
	for u in game.units:
		if is_instance_valid(u) and not u.dead:
			assign(u)
	if _osig.size() > game.units.size() + 64:
		var live := {}
		for u in game.units:
			live[u.get_instance_id()] = true
		for k in _osig.keys():
			if not live.has(k):
				_osig.erase(k)          # (units gone since)
	if _gone.size() > 256:
		var bodies := {}
		for u in game.units:
			bodies[u.get_instance_id()] = true
		for k in _gone.keys():
			if not bodies.has(k):
				_gone.erase(k)          # (bodies cleared away)
	var d := SaveGame.capture(game, _cfg, true)
	if d.is_empty():
		return
	d.erase("cfg")
	d.erase("log")
	d.erase("saved_at")
	var kd := {"clk": game.clock, "seq": n_cmds, "save": d, "elim": game.eliminated.duplicate(), "over": game.over,
		"net_next": game.net_next}
	var b := var_to_bytes(kd)
	var tb := Time.get_ticks_usec()
	key_us += tb - t0
	_flush_cmds()
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, b.size())
	out.append_array(b.compress(FileAccess.COMPRESSION_ZSTD))
	ReplayFile.append(path, ReplayFile.T_KEY, game.clock, game.clock, out)
	bytes_keys += out.size() + ReplayFile.REC_HEAD
	bytes_file += out.size() + ReplayFile.REC_HEAD
	bytes_raw += b.size()
	pack_us += Time.get_ticks_usec() - tb
	last_key = game.clock
	last_clk = game.clock
	n_keys += 1
	n_frames += 1
	for t in game.n_players():
		if t < _out.size() and game.eliminated[t] and not _out[t]:
			note_event("out", [t])
	_out = game.eliminated.duplicate()
	var us := Time.get_ticks_usec() - t0
	cost_us += us
	Prof.add("replay/key", t0)
	recorded.emit()


## The commands (and events) since the last keyframe, written before the next one.
func _flush_cmds() -> void:
	if not events.is_empty():
		ReplayFile.append(path, ReplayFile.T_EVENTS, float(events[0][0]), float(events.back()[0]), var_to_bytes(events))
		events = []
	if cmds.is_empty():
		return
	var raw := var_to_bytes(cmds)
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, raw.size())
	b.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	ReplayFile.append(path, ReplayFile.T_CMDS, float(cmds[0][0]), float(cmds.back()[0]), b)
	bytes_cmds += b.size() + ReplayFile.REC_HEAD
	bytes_file += b.size() + ReplayFile.REC_HEAD
	cmds = []


func flush() -> void:
	_flush_cmds()


func finish(winner: int, left := false) -> String:
	if done:
		return path if written else ""
	if written:
		note_event("end", [winner, game.end_note, int(game.end_quitter)])
		_flush_cmds()
		var footer := {"winner": winner, "len": snappedf(game.clock, 0.01), "note": game.end_note, "quit": int(game.end_quitter),
			"left": left, "frames": n_keys, "cmds": n_cmds}
		var fb := var_to_bytes(footer)
		ReplayFile.append(path, ReplayFile.T_FOOT, game.clock, game.clock, fb)
		bytes_file += fb.size() + ReplayFile.REC_HEAD
		ReplayFile.write_meta(path, ReplayFile.meta_from(header, footer, path))
		ReplayFile.prune(Settings.replays_keep)
	done = true
	return path if written else ""


func cost_line() -> String:
	var secs := maxf(game.clock - float(header.get("t0", 0.0)), 1.0)
	return "MIXED keyframes %d, commands %d (%d dropped), computers' orders %d, recording %.2f ms per match second (keyframes %.2f, packing %.2f, commands %.3f, computers' orders %.2f), file %.0f KB (%.0f KB a minute; keyframes %.0f KB, commands %.0f KB)" % [
		n_keys, n_player, n_dropped, n_diffs, cost_us / 1000.0 / secs, key_us / 1000.0 / secs, pack_us / 1000.0 / secs, cmd_us / 1000.0 / secs, diff_us / 1000.0 / secs,
		bytes_file / 1024.0, bytes_file / 1024.0 / secs * 60.0, bytes_keys / 1024.0, bytes_cmds / 1024.0]
