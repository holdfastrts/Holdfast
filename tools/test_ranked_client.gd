extends SceneTree
## One player of the ranked end-to-end test (tools/test_ranked.sh): signs in to the ladder with the DEV identity, queues,
## joins the match host's room with its ticket and plays a scripted match through the real game (Main, NetLobby,
## NetSession as a guest), then asks the ladder for the result.
##   godot --headless --script res://tools/test_ranked_client.gd -- ranked_dev ladder:http://127.0.0.1:8790 \
##       dev_sid:76561190000000001 dev_name:Alice faction:crown role:a [cheat] [surrender_at:75]
## role a / b only name the player in the output. cheat: once the match runs, order an id it does not own (refused),
## give a move order listing an enemy unit with its own (the enemy is stripped), and flood 70 orders in one second (the
## extra ones dropped): the match host must log all three against this SteamID. surrender_at:<s>: give up at that game
## time (the other player wins). Both walk their units to the middle of the map so the sides meet (the fog check).
var main: Node
var args := {}
var t := 0.0
var step := "boot"
var lad: LadderClient
var g: Game
var match_id := ""
var results := {}
var _busy := false
var _poll_t := 0.0
var _cheated := false
var _walked := false
var _end_t := 0.0


func check(name: String, ok: bool, extra := "") -> void:
	results[name] = ok
	print("CHECK %s %s %s %s" % [String(args.get("role", "?")).to_upper(), name, "OK" if ok else "FAIL", extra])


func _initialize() -> void:
	Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		var i := a.find(":")
		args[a.substr(0, i) if i > 0 else a] = a.substr(i + 1) if i > 0 else "1"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > float(args.get("limit", "420")):
		print("TIMEOUT in %s" % step)
		_finish()
		return false
	match step:
		"boot":
			if t > 0.5:
				check("identity_dev_available", Identity.available() and Identity.provider() == "dev")
				lad = LadderClient.make(main, String(args["ladder"]))
				main.ladder = lad
				step = "login"
				_busy = true
				lad.login(func(d: Dictionary) -> void:
					_busy = false
					check("login", d.has("token"), str(d.get("error", "")))
					step = "queue" if d.has("token") else "done"
					if step == "done":
						_finish())
		"queue":
			if not _busy:
				_busy = true
				lad.queue(String(args.get("faction", "random")), "eu", func(d: Dictionary) -> void:
					_busy = false
					check("queued", String(d.get("state", "")) == "searching", str(d))
					step = "searching")
		"searching":
			_poll_t -= delta
			if _poll_t <= 0.0 and not _busy:
				_poll_t = 1.0
				_busy = true
				lad.poll(func(d: Dictionary) -> void:
					_busy = false
					if String(d.get("state", "")) == "found":
						check("match_found", true, "match %s, seat %d, room %s, vs %s" % [d["match"], int(d["seat"]), d["room"], d["opponent"]])
						match_id = String(d["match"])
						_join(d))
		"joining":
			if main.game != null:
				g = main.game
				step = "playing"
				t = 0.0
		"playing":
			_play(delta)
		"result":
			_poll_t -= delta
			if _poll_t <= 0.0 and not _busy:
				_poll_t = 1.5
				_busy = true
				lad.match_result(match_id, func(d: Dictionary) -> void:
					_busy = false
					if String(d.get("state", "")) == "done":
						print("RESULT %s %s" % [String(args.get("role", "")).to_upper(), JSON.stringify(d)])
						var want := String(args.get("expect", ""))
						if want != "":
							check("ladder_result_" + want, String(d.get("result", "")) == want, "got %s" % d.get("result"))
						check("rating_changed", int(d.get("delta", 0)) != 0 and d.get("rating") != null, "delta %s, rating %s" % [d.get("delta"), d.get("rating")])
						check("result_text_shown", RankedMenu.result_text(d) != "", RankedMenu.result_text(d).replace("\n", " | "))
						_finish())
	return false


func _join(d: Dictionary) -> void:
	var l := NetLobby.new()
	main.add_child(l)
	main.net_lobby = l
	l.ticket = String(d["ticket"])
	if args.has("badticket"):
		l.ticket = l.ticket.substr(0, l.ticket.length() - 4) + "beef"
	l.failed.connect(func(why: String) -> void:
		print("LOBBY FAILED: ", why)
		if args.has("badticket"):
			check("forged_ticket_refused", why.contains("refused"), why)
			_finish())
	l.start_now.connect(func(cfg: Dictionary) -> void:
		main.ranked_match = match_id
		main.start(cfg))
	l.join(String(d["relay"]), String(d["room"]))
	step = "joining"


func _mine() -> Array:
	return g.units.filter(func(u: Unit) -> bool: return u.team == g.human and not u.dead)


func _play(delta: float) -> void:
	if g == null or g.net == null:
		return
	var s: NetSession = g.net
	if g.over:
		_end_t += delta
		if _end_t > 3.0:
			check("match_ended", true, "winner %d, me %d, at %.0f s" % [g.winner, g.human, g.clock])
			step = "result"
			_poll_t = 2.0
		return
	if not s.go_given or g.clock < 3.0:
		return
	if not _walked and not _mine().is_empty():
		_walked = true
		var mid := Vector2(g.W, g.H) * 0.5 * float(Defs.TILE)
		g.group_move(_mine(), mid, false)
		print("%s walks %d units to the middle" % [String(args.get("role", "")).to_upper(), _mine().size()])
	if args.has("cheat") and not _cheated and g.clock > 8.0:
		_cheated = true
		_cheat(s)
	if args.has("surrender_at") and g.clock >= float(args["surrender_at"]):
		args.erase("surrender_at")
		print("%s surrenders at %.0f s" % [String(args.get("role", "")).to_upper(), g.clock])
		g.player_surrender()


## What a hacked client might send: an order for a unit it does not own, its own move order with an enemy's id in the
## list, and a flood of orders. The host refuses / strips / drops them and counts them against this SteamID.
func _cheat(s: NetSession) -> void:
	var foe_id := 1
	while s.by_id.has(foe_id) and is_instance_valid(s.by_id[foe_id]) and s.by_id[foe_id].team == g.human:
		foe_id += 1
	print("CHEAT orders id %d (not its own)" % foe_id)
	s.send_cmd({"o": foe_id, "f": "cmd_stop", "a": []})
	var mine := _mine()
	var ids: Array = []
	for u in mine:
		ids.append({"e": u.net_id})
	ids.append({"e": foe_id})
	print("CHEAT moves its own units with id %d slipped into the list" % foe_id)
	s.send_cmd({"o": 0, "f": "group_move", "a": [ids, Vector2(g.W, g.H) * 0.5 * float(Defs.TILE), false, false]})
	if not mine.is_empty():
		print("CHEAT floods 70 orders")
		for i in 70:
			s.send_cmd({"o": mine[0].net_id, "f": "cmd_stop", "a": []})


func _finish() -> void:
	var ok := true
	for k in results:
		ok = ok and results[k]
	print("%s %s" % [String(args.get("role", "?")).to_upper(), "ALL OK" if ok else "SOME FAILED"])
	step = "done"
	if main.net_lobby:
		main.net_lobby.dispose()
	quit(0)
