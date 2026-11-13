extends SceneTree
## A DEDICATED MATCH HOST for ranked play (docs/online_ranked.md): the same Game, headless, with no player of its own;
## both sides are guests who join through the relay with the ladder's signed tickets. It ends the match, keeps the
## replay as evidence and reports the result (and each player's refused-order counts) to the ladder service.
##
##   godot --headless --path <project> --script res://tools/server/match_server.gd -- \
##       relay:ws://127.0.0.1:8799 room:R7K2Q9XW match:m_123 secret:<shared secret> \
##       ladder:http://127.0.0.1:8790 map:hollowfen seed:12345 f0:crown f1:brood sid0:7656... sid1:7656... \
##       [out:<dir for result + replay>] [maxsecs:3600] [noshow:90]
## The ladder service (tools/ladder/ladder.mjs) starts it for every match it makes; it can be run by hand for tests.
## It joins the relay as the room's HOST: an outbound connection, so a match host needs no open port, no certificate and
## works behind any NAT; the relay already carries wss:// to browsers and phones (why not our own WebSocket: see the doc).
## Exit code 0 when a result was reported (or written), 1 on a setup error.

var args := {}
var main: Node
var lobby: NetLobby
var g: Game
var t := 0.0
var phase := "boot"                 # boot, seating, playing, ending, done
var result := {}
var _end_t := 0.0
var _posted := false
var _post_done := false
var _http: HTTPRequest
var _cpu_ms := 0.0                  # this process's frame time spent (Performance monitors), over the match
var _cpu_peak := 0.0                # the busiest second (ms of work in one second of real time)
var _cpu_sec := 0.0
var _sec_t := 0.0
var _real := 0.0
var _forfeit := -1


func _initialize() -> void:
	Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		var i := a.find(":")
		if i > 0:
			args[a.substr(0, i)] = a.substr(i + 1)
		else:
			args[a] = "1"
	for k in ["relay", "room", "match", "secret", "sid0", "sid1"]:
		if not args.has(k):
			printerr("match_server: missing %s:..." % k)
			quit(1)
			return
	if String(args["room"]).length() < 8:
		printerr("match_server: a ranked room code must be 8 to 12 letters")
		quit(1)
		return
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	root.add_child(_http)
	_http.request_completed.connect(_on_posted)
	print("[server] match %s: room %s on %s" % [args["match"], args["room"], args["relay"]])


func _process(delta: float) -> bool:
	_real += delta
	t += delta
	_cpu_tick(delta)
	match phase:
		"boot":
			if t >= 0.5:
				_open_room()
		"seating":
			_seating()
		"playing":
			_playing()
		"ending":
			_ending(delta)
		"done":
			return true
	return false


# ------------------------------------------------------------------ the room

func _open_room() -> void:
	phase = "seating"
	t = 0.0
	lobby = NetLobby.new()
	main.add_child(lobby)
	main.net_lobby = lobby
	lobby.failed.connect(func(why: String) -> void: print("[server] relay: ", why))
	lobby.ranked = {"secret": args["secret"], "match": args["match"], "seats": {String(args["sid0"]): "0", String(args["sid1"]): "1"}}
	lobby.same_delay = false        # (no player here: no host's orders to hold back)
	lobby.host(String(args["relay"]), String(args["room"]))
	lobby.map = String(args.get("map", "random_1v1"))
	lobby.slots = [
		{"who": "remote", "faction": String(args.get("f0", "random")), "colour": 0, "side": 0, "peer": -1},
		{"who": "remote", "faction": String(args.get("f1", "random")), "colour": 4, "side": 1, "peer": -1}]


func _seating() -> void:
	var seated := 0
	for s in lobby.slots:
		if int(s.get("peer", -1)) >= 0:
			seated += 1
	if seated == 2:
		_start()
		return
	if t >= float(args.get("noshow", "90")):
		var here: Array = []
		for i in lobby.slots.size():
			if int(lobby.slots[i].get("peer", -1)) >= 0:
				here.append(i)
		print("[server] no-show: seated %s" % [here])
		_finish({"outcome": "no_show", "present": here})


func _start() -> void:
	var cfg := lobby.make_cfg()
	cfg["seed"] = int(args.get("seed", str(randi())))
	main.start(cfg)
	g = main.game
	g.dedicated = true
	var s: NetSession = g.net
	s.strict = true                   # (the enemy's bank and battle report: not before the end)
	s.flood_max = NetSession.FLOOD_MAX
	if g.hud:
		g.hud.start_countdown(3.0)    # (the 3-2-1 here too, held until both guests have loaded: NetSession "go")
		g.hud.count_hold = true
	s.link.notice.connect(_on_notice)
	g.ended.connect(_on_ended)
	phase = "playing"
	t = 0.0
	print("[server] match started: %s, %s v %s, seed %d" % [g.map_id, g.faction_of(0), g.faction_of(1), int(cfg["seed"])])


## A guest who leaves a ranked match loses it (the prototype has no reconnect: docs/online_ranked.md).
func _on_notice(d: Dictionary) -> void:
	if String(d.get("t", "")) != "leave" or g == null or g.over:
		return
	var team: int = g.net.peer_team.get(int(d.get("id", -1)), -1)
	if team < 0:
		return
	print("[server] seat %d left: it forfeits" % team)
	_forfeit = team
	g.player_surrender(team)


func _playing() -> void:
	if g.over:
		return                         # (_on_ended takes it from here)
	if g.clock >= float(args.get("maxsecs", "3600")):
		print("[server] time limit: a draw")
		g.over = true
		g.winner = -1
		g.end_note = "time_limit"
		g.ended.emit(-1)


func _on_ended(winner: int) -> void:
	if phase != "playing":
		return
	phase = "ending"
	_end_t = 0.0
	var outcome := "draw" if winner < 0 else "win"
	result = {"outcome": outcome, "winner_seat": winner if winner >= 0 else -1, "end_note": g.end_note,
		"forfeit_seat": _forfeit}
	print("[server] match over: %s %s (%s)" % [outcome, winner, g.end_note])


func _ending(delta: float) -> void:
	_end_t += delta
	# (Main._on_end has written the replay and started sending it to both guests; give it time to get out)
	var s: NetSession = g.net
	var sending: bool = s != null and s.rp_out.size() > 0 and s.rp_pos < s.rp_out.size()
	if (_end_t >= 2.0 and not sending) or _end_t >= 25.0:
		if result.has("outcome") and not result.has("replay"):
			_finish(result)


# ------------------------------------------------------------------ the result

func _finish(r: Dictionary) -> void:
	if _posted:
		return
	_posted = true
	phase = "done" if not args.has("ladder") else "ending"
	r["match"] = String(args["match"])
	r["version"] = String(ProjectSettings.get_setting("application/config/version", "dev"))
	r["players"] = [{"sid": String(args["sid0"]), "seat": 0, "faction": String(args.get("f0", ""))},
		{"sid": String(args["sid1"]), "seat": 1, "faction": String(args.get("f1", ""))}]
	r["length"] = snappedf(g.clock, 0.1) if g != null else 0.0
	r["map"] = g.map_id if g != null else String(args.get("map", ""))
	if g != null:
		r["players"][0]["faction"] = g.faction_of(0)
		r["players"][1]["faction"] = g.faction_of(1)
	var rp: String = String(main.get("last_replay")) if main.get("last_replay") != null else ""
	var out_dir := String(args.get("out", "user://ranked"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	if rp != "" and FileAccess.file_exists(rp):
		var dest := out_dir.path_join("%s.hfr" % args["match"])
		DirAccess.copy_absolute(rp, dest)
		r["replay"] = ProjectSettings.globalize_path(dest)
	else:
		r["replay"] = ""
	# what each seat sent that a fair client never would (NetSession.audit, by relay id -> by seat)
	var aud := {}
	if g != null and g.net != null:
		for pr in g.net.audit:
			var team: int = g.net.peer_team.get(int(pr), -1)
			if team >= 0:
				aud[str(team)] = g.net.audit[pr]
	r["audit"] = aud
	r["cpu"] = {"ms_per_s": snappedf(_cpu_ms / maxf(_real, 0.001), 0.1), "peak_ms_per_s": snappedf(_cpu_peak, 0.1),
		"real_s": snappedf(_real, 0.1)}
	var body := JSON.stringify(r)
	var f := FileAccess.open(out_dir.path_join("%s.json" % args["match"]), FileAccess.WRITE)
	if f:
		f.store_string(body)
		f.close()
	print("[server] RESULT ", body)
	if args.has("ladder"):
		var url := String(args["ladder"]).rstrip("/") + "/internal/result"
		var sig := LadderTicket.signature(body, String(args["secret"]))
		var err := _http.request(url, ["Content-Type: application/json", "X-Ladder-Sig: " + sig], HTTPClient.METHOD_POST, body)
		if err != OK:
			print("[server] could not reach the ladder (%d): the result stays in %s" % [err, out_dir])
			_done()
	else:
		_done()


func _on_posted(_res: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	print("[server] ladder answered %d %s" % [code, body.get_string_from_utf8().substr(0, 200)])
	_done()


func _done() -> void:
	if _post_done:
		return
	_post_done = true
	phase = "done"
	if lobby and lobby.link:
		lobby.link.close("over")
	quit(0)


# ------------------------------------------------------------------ measuring

## The work this process did (Godot's frame-time monitors: game ticks and frames), per second of real time.
func _cpu_tick(delta: float) -> void:
	var ms := (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	_cpu_ms += ms
	_cpu_sec += ms
	_sec_t += delta
	if _sec_t >= 1.0:
		_cpu_peak = maxf(_cpu_peak, _cpu_sec / _sec_t)
		_cpu_sec = 0.0
		_sec_t = 0.0

