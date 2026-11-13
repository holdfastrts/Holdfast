class_name RankedMenu
extends Control
## RANKED (docs/online_ranked.md): sign in (Steam, or a test server's DEV sign-in), pick a faction and FIND A MATCH;
## the queue screen (searching, time, CANCEL); a match found connects to the server's match host (both players are
## its guests); afterwards the result with the rating change (result_panel, on the battle report); the LEADERBOARD.
## Shown on the ONLINE page only when this device has a ranked identity (Identity.available()).

const FACS := ["crown", "brood", "clockwork", "random"]
const REGIONS := ["eu", "na", "sa", "asia"]
const REGION_LABEL := {"eu": "EUROPE", "na": "N. AMERICA", "sa": "S. AMERICA", "asia": "ASIA"}
const POLL := 1.5

var main: Node
var state := "signin"            # signin, home, searching, found, connecting, board, error
var note := ""                   # a line under the heading (an error, a ban's reason)
var region := "eu"
var board_faction := ""
var board := {}
var found := {}
var _box: VBoxContainer
var _clock: Label
var _t := 0.0
var _poll_t := 0.0
var _busy := false


static func client(m: Node) -> LadderClient:
	if m.ladder == null or not is_instance_valid(m.ladder):
		m.ladder = LadderClient.make(m, Settings.ladder_url)
	if Settings.ladder_url.strip_edges() != "":
		m.ladder.base = Settings.ladder_url.strip_edges().rstrip("/")
	return m.ladder


func build(start_state := "") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 30)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	add_child(m)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	m.add_child(_box)
	var c := client(main)
	if start_state == "board":
		state = "board"
		_load_board("")
	elif c.token != "":
		state = "home"
		c.profile(func(_d: Dictionary) -> void: _redraw())
	else:
		_sign_in()
	_redraw()


func _sign_in() -> void:
	if Settings.ladder_url.strip_edges() == "":
		state = "home"
		return
	state = "signin"
	client(main).login(func(d: Dictionary) -> void:
		if d.has("error"):
			state = "error"
			note = _error_text(d)
		else:
			state = "home"
			note = ""
		_redraw())


func _error_text(d: Dictionary) -> String:
	if String(d.get("error", "")) == "banned":
		var until := int(d.get("until", 0)) if d.get("until") != null else 0
		var when := Loc.t("for good") if until <= 0 else (Loc.t("until %s") % Time.get_date_string_from_unix_time(until))
		return Loc.t("You are banned from ranked play %s: %s. To appeal: %s") % [when, String(d.get("reason", "")), String(d.get("appeal", ""))]
	return Loc.t(String(d.get("error", "Something went wrong.")))


func _process(delta: float) -> void:
	_t += delta
	if state == "searching" or state == "found":
		if is_instance_valid(_clock):
			_clock.text = "%d:%02d" % [int(_t) / 60, int(_t) % 60]
		_poll_t -= delta
		if _poll_t <= 0.0 and not _busy and state == "searching":
			_poll_t = POLL
			_busy = true
			client(main).poll(_on_poll)


func _on_poll(d: Dictionary) -> void:
	_busy = false
	if state != "searching":
		return
	if d.has("error"):
		note = _error_text(d)
		state = "error" if int(d.get("code", 0)) == 403 else "home"
		_redraw()
		return
	match String(d.get("state", "")):
		"found":
			found = d
			state = "found"
			_redraw()
			_connect()
		"starting":
			if not found.has("opponent"):
				found = d
				_redraw()             # (shown on the searching screen: a match is found, its server is starting)
		"idle":
			state = "home"
			_redraw()


## The match host waits in the room the ladder named: join it as a guest with our ticket; the host's "start" starts it.
func _connect() -> void:
	if main.net_lobby:
		main.net_lobby.dispose()
	var l := NetLobby.new()
	main.add_child(l)
	main.net_lobby = l
	l.ticket = String(found.get("ticket", ""))
	l.failed.connect(func(why: String) -> void:
		if state == "found":
			state = "home"
			note = Loc.t("The match could not start: %s") % Loc.t(why)
			_redraw())
	l.start_now.connect(func(cfg: Dictionary) -> void:
		main.ranked_match = String(found.get("match", ""))
		state = "playing"
		main.start(cfg))
	l.join(String(found.get("relay", Settings.relay_url)), String(found.get("room", "")))


func _redraw() -> void:
	if _box == null:
		return
	for c in _box.get_children():
		c.queue_free()
	var head := UiStyle.heading("RANKED" if state != "board" else "LEADERBOARD", 42, UiStyle.TRIM)
	_box.add_child(head)
	var me: Dictionary = client(main).me
	if not me.is_empty() and state != "board":
		var line := "%s · %s" % [String(me.get("name", "")), Loc.t(String(me.get("season", "")))]
		var rk := String(me.get("rank", "")) if me.get("rank") != null else ""
		if int(me.get("placement", 0)) > 0:
			line += " · " + Loc.t("PLACEMENT: %d matches left") % int(me.get("placement", 0))
		else:
			line += " · " + Loc.t("RATING %d") % int(me.get("rating", 1500)) + ("" if rk == "" else " · #" + rk)
		line += " · " + Loc.t("%d won, %d lost") % [int(me.get("wins", 0)), int(me.get("losses", 0))]
		_box.add_child(UiStyle.text(line, 18, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if note != "":
		var n := UiStyle.text(note, 17, UiStyle.BAD, HORIZONTAL_ALIGNMENT_CENTER)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(n)
	var cc := CenterContainer.new()
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(cc)
	var pn := PanelContainer.new()
	pn.custom_minimum_size.x = 720
	cc.add_child(pn)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pn.add_child(v)
	match state:
		"signin":
			v.add_child(UiStyle.text("Signing in...", 22, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		"home", "error":
			_draw_home(v)
		"searching":
			v.add_child(UiStyle.text("SEARCHING FOR AN OPPONENT", 26, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
			_clock = UiStyle.text("0:00", 40, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_CENTER)
			v.add_child(_clock)
			if found.has("opponent"):
				v.add_child(UiStyle.text("MATCH FOUND: starting the match server...", 20, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_CENTER))
			var nb := UiStyle.text("You play %s. A match is found for a rating close to yours; the wider the wait, the wider the search." % Loc.t(Settings.ranked_faction.to_upper()), 16, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			nb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(nb)
			var cancel: Button = main._button("CANCEL", func() -> void:
				state = "home"
				client(main).cancel(func(_d: Dictionary) -> void: pass)
				_redraw())
			cancel.custom_minimum_size = Vector2(0, 58)
			v.add_child(cancel)
		"found":
			v.add_child(UiStyle.text("MATCH FOUND", 30, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_CENTER))
			var o: Dictionary = found.get("opponent", {})
			v.add_child(UiStyle.text(Loc.t("Against %s (%s, rating %d)") % [String(o.get("name", "?")), Loc.t(String(o.get("faction", "random")).to_upper()), int(o.get("rating", 1500))], 20, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
			v.add_child(UiStyle.text("Connecting to the match server...", 18, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		"board":
			_draw_board(v)
	if state != "searching" and state != "found":
		var back: Button = main._button("BACK", func() -> void:
			if state == "board":
				state = "home"
				_redraw()
			else:
				main.show_online())
		main._set_back(back)
		back.custom_minimum_size = Vector2(240, 58)
		_box.add_child(back)


func _draw_home(v: VBoxContainer) -> void:
	var nt := UiStyle.text("Ranked 1v1 on our servers: the match runs on a server, not on either player's device, so neither side can see through the fog or fake a result. Your rating moves with every match (the first 5 are placement matches).", 16, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	nt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nt)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	lrow.add_child(UiStyle.text("LADDER ADDRESS", 16, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	var le := LineEdit.new()
	le.text = Settings.ladder_url
	le.placeholder_text = "https://ladder.example.com"
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size = Vector2(0, 46)
	le.text_submitted.connect(func(t: String) -> void:
		Settings.ladder_url = t.strip_edges()
		Settings.save_all()
		client(main).token = ""
		_sign_in()
		_redraw())
	UiStyle.touch_text(le, "LADDER ADDRESS")
	lrow.add_child(le)
	v.add_child(lrow)
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 8)
	frow.alignment = BoxContainer.ALIGNMENT_CENTER
	for f in FACS:
		var b: Button = main._button(f.to_upper(), func() -> void:
			Settings.ranked_faction = f
			Settings.save_all()
			_redraw())
		b.toggle_mode = true
		b.button_pressed = Settings.ranked_faction == f
		b.custom_minimum_size = Vector2(160, 52)
		frow.add_child(b)
	v.add_child(frow)
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 8)
	rrow.alignment = BoxContainer.ALIGNMENT_CENTER
	for r in REGIONS:
		var b2: Button = main._button(REGION_LABEL[r], func() -> void:
			region = r
			_redraw())
		b2.toggle_mode = true
		b2.button_pressed = region == r
		b2.custom_minimum_size = Vector2(150, 44)
		rrow.add_child(b2)
	v.add_child(rrow)
	var go: Button = main._button("FIND A MATCH", func() -> void: find_match())
	UiStyle.primary(go)
	go.custom_minimum_size = Vector2(0, 64)
	go.disabled = client(main).token == ""
	v.add_child(go)
	var lb: Button = main._button("LEADERBOARD", func() -> void:
		state = "board"
		_load_board(board_faction)
		_redraw())
	lb.custom_minimum_size = Vector2(0, 54)
	lb.disabled = Settings.ladder_url.strip_edges() == ""
	v.add_child(lb)
	if client(main).token == "" and state == "error":
		var again: Button = main._button("SIGN IN AGAIN", func() -> void:
			_sign_in()
			_redraw())
		v.add_child(again)


func find_match() -> void:
	note = ""
	_busy = true
	client(main).queue(Settings.ranked_faction, region, func(d: Dictionary) -> void:
		_busy = false
		if d.has("error"):
			note = _error_text(d)
			state = "error" if int(d.get("code", 0)) == 403 else "home"
		else:
			state = "searching"
			found = {}
			_t = 0.0
			_poll_t = POLL
		_redraw())


func _load_board(f: String) -> void:
	board_faction = f
	client(main).leaderboard(f, func(d: Dictionary) -> void:
		board = d
		if state == "board":
			_redraw())


func _draw_board(v: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	for f in ["", "crown", "brood", "clockwork"]:
		var b: Button = main._button("ALL" if f == "" else f.to_upper(), func() -> void:
			_load_board(f)
			_redraw())
		b.toggle_mode = true
		b.button_pressed = board_faction == f
		b.custom_minimum_size = Vector2(150, 46)
		tabs.add_child(b)
	v.add_child(tabs)
	if board.has("error"):
		v.add_child(UiStyle.text(_error_text(board), 18, UiStyle.BAD, HORIZONTAL_ALIGNMENT_CENTER))
		return
	v.add_child(UiStyle.text(Loc.t(String(board.get("season", ""))), 18, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var you = board.get("you")
	if you is Dictionary:
		var yl := Loc.t("You: placement, %d matches left") % int(you.get("placement", 0)) if int(you.get("placement", 0)) > 0 else Loc.t("You: #%s, rating %d") % [str(you.get("rank_here")) if you.get("rank_here") != null else "-", int(you.get("rating", 1500))]
		v.add_child(UiStyle.text(yl, 18, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_CENTER))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(680, 380)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var rows: Array = board.get("rows", [])
	if rows.is_empty():
		list.add_child(UiStyle.text("Nobody has finished their placement matches yet.", 17, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	for r in rows:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var cells := ["#%d" % int(r["rank"]), String(r["name"]), Loc.t(String(r.get("faction", "")).to_upper()), str(int(r["rating"])), "%d-%d" % [int(r["wins"]), int(r["losses"])]]
		var widths := [70, 260, 150, 80, 90]
		for i in cells.size():
			var l := UiStyle.text(cells[i], 17, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
			l.custom_minimum_size.x = widths[i]
			l.clip_text = true
			h.add_child(l)
		list.add_child(h)


## On the battle report of a ranked match: the result from the ladder, with the rating change (it asks until the match
## host has reported, a few seconds after the end).
static func result_panel(m: Node, match_id: String) -> Control:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.custom_minimum_size = Vector2(520, 0)
	var v := VBoxContainer.new()
	p.add_child(v)
	var l := UiStyle.text("RANKED: waiting for the server's result...", 20, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var tries := [0]
	var ask := [Callable()]
	ask[0] = func() -> void:
		if not is_instance_valid(p):
			return
		client(m).match_result(match_id, func(d: Dictionary) -> void:
			if not is_instance_valid(l):
				return
			if String(d.get("state", "")) == "playing" and tries[0] < 20:
				tries[0] += 1
				p.get_tree().create_timer(1.5, true, false, true).timeout.connect(ask[0])
				return
			l.text = result_text(d)
			client(m).profile(func(_x: Dictionary) -> void: pass))
	ask[0].call()
	return p


static func result_text(d: Dictionary) -> String:
	if d.has("error"):
		return Loc.t("RANKED: %s") % Loc.t(String(d["error"]))
	var head: String = {"win": "VICTORY", "loss": "DEFEAT", "draw": "DRAW"}.get(String(d.get("result", "")), "NO RESULT")
	var s := Loc.t(head)
	if d.get("rating") != null:
		var delta := int(d.get("delta", 0))
		s += "  " + ("+%d" % delta if delta >= 0 else str(delta)) + "  →  " + str(int(d["rating"]))
	if int(d.get("placement", 0)) > 0:
		s += "\n" + Loc.t("PLACEMENT: %d matches left") % int(d.get("placement", 0))
	return s
