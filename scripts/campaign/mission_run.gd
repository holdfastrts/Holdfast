class_name MissionRun
extends Node
## A campaign mission being played (docs/campaign_engine.md): made by Main.start from the mission's data and put on
## the Game (game.mission) before the map is built. It places the teams' starting units and buildings
## (Game._start_positions asks it), keeps the tagged units and buildings, runs the triggers, checks the objectives
## and decides who won (Game._check_end leaves the end to it). Online, the host's runs everything and sends what the
## friend must see (lines, objectives, reveals, pings: "camp" messages); a guest's (`remote`) only shows them.

signal said(line: Dictionary)        # a line of dialogue for this screen: {"id", "who", "name", "side", "text", "still"}
signal objectives_changed
signal pointer_changed               # the TUTORIAL's pointer moved (MissionUi draws it): `pointer`

const TICK := 0.25                   # seconds between trigger and objective checks
const SYNC_EVERY := 2.0              # host: the objectives are sent to the guests again this often (a lost message heals)

var game: Game
var data: Dictionary = {}
var id := ""
var mode := "solo"
var remote := false                  # online guest: the host runs the triggers
var team_ids: Array = []             # team index -> the mission's team id
var player_teams := {}               # team index -> true: a person plays it (never given scripted orders)
var tags := {}                       # tag -> [Entity, ...] (dead ones stay: "all dead" needs them)
var obj := {}                        # objective id -> "hidden" | "active" | "done" | "failed"
var fired := {}                      # trigger id -> game clock when it fired
var _met := {}                       # trigger id -> game clock its condition first held (for "delay")
var reveals: Array = []              # [side index, cell, radius, until (game clock)]
var said_ids: Array = []             # every line said so far, in order (tests, the match log)
var winner_side := ""
var _side_had := {}                  # side id -> true once it had a unit or a building
var _t := 0.0
var _sync_t := 0.0
# the TUTORIAL (docs/tutorial.md): what the player did since the step began ("mark": the camera, the counts, the notes)
var pointer := {}                    # where the teacher points: {"area"}, {"tag"}, {"kind"}, {"ui"} ({} none)
var noted := {}                      # action name -> times since the mark: "minimap", "group_set", "group_select", "hotkey"
var talk_busy := false               # MissionUi: a line is still being read (the "talked" condition waits for it)
var _cam0 := Vector2.ZERO
var _zoom0 := Vector2.ONE
var _base := {}                      # kind -> how many the player had at the mark (the "more" condition)


func setup(m: Dictionary, md: String, cfg: Dictionary, guest := false) -> void:
	data = m
	id = String(m.get("id", ""))
	mode = md
	remote = guest
	team_ids = (m.get("teams", []) as Array).map(func(t: Dictionary) -> String: return String(t["id"]))
	var slots: Array = cfg.get("slots", [])
	for i in slots.size():
		if String(slots[i].get("who", "")) in ["you", "remote"]:
			player_teams[i] = true
	for o in m.get("objectives", []):
		obj[String(o["id"])] = "hidden" if bool(o.get("hidden", false)) else "active"


# ------------------------------------------------------------------ lookups

func team_data(t: int) -> Dictionary:
	return data["teams"][t] if t >= 0 and t < (data["teams"] as Array).size() else {}


func team_index(team_id: String) -> int:
	return team_ids.find(team_id)


func side_of_team(t: int) -> String:
	return String(team_data(t).get("side", ""))


func teams_of_side(side_id: String) -> Array:
	var out: Array = []
	for t in team_ids.size():
		if side_of_team(t) == side_id:
			out.append(t)
	return out


func my_side() -> String:
	return side_of_team(game.human)


func area_rect(name: String) -> Rect2:
	var a: Array = data.get("areas", {}).get(name, [0, 0, 1, 1])
	return Rect2(float(a[0]) * Defs.TILE, float(a[1]) * Defs.TILE, float(a[2]) * Defs.TILE, float(a[3]) * Defs.TILE)


func _where(at: Variant) -> Rect2:
	if at is Array:
		return Rect2(float(at[0]) * Defs.TILE, float(at[1]) * Defs.TILE, Defs.TILE, Defs.TILE)
	return area_rect(String(at))


func _in_mode(it: Dictionary) -> bool:
	return not it.has("modes") or (it["modes"] as Array).has(mode)


func objective(oid: String) -> Dictionary:
	for o in data.get("objectives", []):
		if String(o["id"]) == oid:
			return o
	return {}


## The objectives a side sees, in order: [{data..., "state"}] (hidden ones left out).
func objectives_for(side_id: String) -> Array:
	var out: Array = []
	for o in data.get("objectives", []):
		var st := String(obj.get(String(o["id"]), "hidden"))
		if String(o.get("side", "")) == side_id and st != "hidden":
			var c: Dictionary = o.duplicate()
			c["state"] = st
			if c.has("phone") and not Settings.pc():
				c["text"] = c["phone"]
			out.append(c)
	return out


func line(lid: String) -> Dictionary:
	var ln: Dictionary = data.get("lines", {}).get(lid, {})
	if ln.is_empty():
		return {}
	var who := String(ln.get("who", ""))
	var sp: Dictionary = data.get("speakers", {}).get(who, {})
	var txt := String(ln.get("text", ""))
	if ln.has("phone") and not Settings.pc():
		txt = String(ln["phone"])          # (a line with its own words for a phone: the controls differ)
	return {"id": lid, "who": who, "name": String(sp.get("name", who)), "side": String(sp.get("side", "")),
		"portrait": String(sp.get("portrait", "")), "text": txt, "still": String(ln.get("still", "")),
		"to": String(ln.get("to", ""))}


func still(sid: String) -> Dictionary:
	return data.get("stills", {}).get(sid, {})


# ------------------------------------------------------------------ the start (host; Game._start_positions)

## Before the starting layout: each team with a "hall" gets that spot as its start.
func before_start() -> void:
	for t in team_ids.size():
		var tm := team_data(t)
		if tm.has("hall") and t < game.starts.size():
			game.starts[t] = Vector2i(int(tm["hall"][0]), int(tm["hall"][1]))
		elif tm.has("camera") and t < game.starts.size():
			game.starts[t] = game.cell_of(area_rect(String(tm["camera"])).get_center())


## Does this team get the normal start (hall, economy building, workers)?
func standard_start(t: int) -> bool:
	return String(team_data(t).get("start", "standard")) == "standard"


## After the starting layout: the mission's units and buildings, resources, the hall's tag.
func after_start() -> void:
	for t in team_ids.size():
		var tm := team_data(t)
		if tm.has("hall_tag"):
			for b in game.buildings:
				if b.team == t and b.kind == game.faction_hall(t):
					_tag(String(tm["hall_tag"]), b)
		if not standard_start(t):
			game.players[t]["gold"] = 0
			game.players[t]["res2"] = float(Defs.START_POWDER) if game.factions[t] == "crown" else 0.0
		if tm.has("gold"):
			game.players[t]["gold"] = int(tm["gold"])
		if tm.has("powder"):
			game.players[t]["res2"] = float(tm["powder"])
	for b in data.get("buildings", []):
		if _in_mode(b):
			_place_building(b)
	for u in data.get("units", []):
		if _in_mode(u):
			_spawn(u)
	for t in team_ids.size():
		game._recount_supply(t)


func _place_building(it: Dictionary) -> Building:
	var t := team_index(String(it["team"]))
	var k := String(it["kind"])
	if t < 0 or not Defs.BUILDINGS.has(k):
		return null
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var c := Vector2i(-1, -1)
	if it.get("at") is Array:
		c = Vector2i(int(it["at"][0]), int(it["at"][1]))
	else:
		c = _free_spot(area_rect(String(it.get("at", ""))), size)
	if c.x < 0:
		push_warning("mission %s: no room for a %s" % [id, k])
		return null
	var b := game._add_building(k, t, c, true)
	game.on_building_complete(b)
	if it.has("tag"):
		_tag(String(it["tag"]), b)
	return b


## A footprint of `size` in the area, nearest its middle, on level free ground with a free cell all round.
func _free_spot(r: Rect2, size: Vector2i) -> Vector2i:
	var c0 := game.cell_of(r.position)
	var c1 := game.cell_of(r.end - Vector2(1, 1))
	var mid := r.get_center() / Defs.TILE
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(c0.y, c1.y - size.y + 2):
		for x in range(c0.x, c1.x - size.x + 2):
			var d := (Vector2(x, y) + Vector2(size) * 0.5).distance_squared_to(mid)
			if d >= bd:
				continue
			if _footprint_ok(Vector2i(x, y), size):
				bd = d
				best = Vector2i(x, y)
	return best


func _footprint_ok(c: Vector2i, size: Vector2i) -> bool:
	var h := -1
	for y in range(-1, size.y + 1):
		for x in range(-1, size.x + 1):
			var cc := c + Vector2i(x, y)
			if not game.in_map(cc) or not game._walkable(cc) or game.solid[game.idx(cc)] != 0 or game.ramp[game.idx(cc)] == 1:
				return false
			var hh: int = game.height[game.idx(cc)]
			if h < 0:
				h = hh
			elif hh != h:
				return false
	return true


## Units of a kind for a team in an area (a "units" entry or a "spawn" action): spread over its free cells.
func _spawn(it: Dictionary) -> Array:
	var t := team_index(String(it.get("team", "")))
	var k := String(it.get("kind", ""))
	var out: Array = []
	if t < 0 or not Defs.UNITS.has(k):
		return out
	var n := int(it.get("count", 1))
	var spots := _spots(_where(it.get("at", [0, 0])), n)
	for i in n:
		var u := game._add_unit(k, t, spots[i % spots.size()])
		if it.has("tag"):
			_tag(String(it["tag"]), u)
		out.append(u)
	var ord: Variant = it.get("order", null)
	if ord is String:
		_order(out, {"do": ord})
	elif ord is Dictionary:
		_order(out, ord)
	return out


## `n` places in a rectangle, a cell apart, nearest its middle first (walkable ground; its middle if none).
func _spots(r: Rect2, n: int) -> Array:
	var cells: Array = []
	var c0 := game.cell_of(r.position)
	var c1 := game.cell_of(r.end - Vector2(1, 1))
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var c := Vector2i(x, y)
			if game._walkable(c) and game.solid[game.idx(c)] == 0:
				cells.append(c)
	var mid := r.get_center()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return game.cell_center(a).distance_squared_to(mid) < game.cell_center(b).distance_squared_to(mid))
	var out: Array = []
	for c in cells:
		if (c.x + c.y) % 2 == 0 or cells.size() < n * 2:
			out.append(game.cell_center(c))
			if out.size() >= n:
				break
	if out.is_empty():
		out.append(mid)
	return out


func _tag(tag: String, e: Entity) -> void:
	if not tags.has(tag):
		tags[tag] = []
	tags[tag].append(e)
	e.set_meta("mission_tag", tag)


func tagged(tag: String, alive_only := true) -> Array:
	var out: Array = []
	for e in tags.get(tag, []):
		if is_instance_valid(e) and (not alive_only or not e.dead):
			out.append(e)
	return out


# ------------------------------------------------------------------ the match

func _ready() -> void:
	# the camera starts on this player's team's "camera" area
	var tm := team_data(game.human)
	if tm.has("camera") and game.camera:
		game.camera.position = area_rect(String(tm["camera"])).get_center()


func _physics_process(delta: float) -> void:
	if game == null or remote or game.over or get_tree().paused:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	_run_triggers()
	_check_objectives()
	_sync_t -= TICK
	if _sync_t <= 0.0:
		_sync_t = SYNC_EVERY
		_send({"k": "obj", "o": obj.duplicate()})


func _run_triggers() -> void:
	for tr in data.get("triggers", []):
		var tid := String(tr.get("id", ""))
		if fired.has(tid) or not _in_mode(tr):
			continue
		if not _met.has(tid):
			if not cond(tr.get("when", {})):
				continue
			_met[tid] = game.clock
		if game.clock - float(_met[tid]) < float(tr.get("delay", 0.0)):
			continue
		fire(tr)
		if game.over:
			return


## Run a trigger's actions now (tests call it directly too).
func fire(tr: Dictionary) -> void:
	fired[String(tr.get("id", ""))] = game.clock
	if game.mlog:
		game.mlog.add("(mission) trigger %s" % tr.get("id", ""))
	for a in tr.get("do", []):
		act(a)


## Is a condition true now? (docs/campaign_engine.md lists them.)
func cond(c: Variant) -> bool:
	if not (c is Dictionary):
		return false
	for k in c:
		var v: Variant = c[k]
		var ok := true
		match String(k):
			"time":
				ok = game.clock >= float(v)
			"dead":
				ok = tags.has(String(v)) and tagged(String(v)).is_empty()
			"hurt":
				ok = false
				for e in tagged(String(v), false):
					if e.dead or e.hp < e.max_hp:
						ok = true
			"count":
				var q: Dictionary = v
				var n := count(q)
				ok = (not q.has("at_least") or n >= int(q["at_least"])) and (not q.has("below") or n < int(q["below"]))
			"done":
				ok = obj.get(String(v), "") == "done"
			"failed":
				ok = obj.get(String(v), "") == "failed"
			"fired":
				ok = fired.has(String(v))
			"all":
				for s in v:
					ok = ok and cond(s)
			"any":
				ok = false
				for s in v:
					ok = ok or cond(s)
			"not":
				ok = not cond(v)
			"selected", "camera_moved", "zoomed", "more", "built", "rooted", "crew", "group", "did", "gear_view", \
					"placing", "order", "res", "talked":
				ok = _tutorial_cond(String(k), v)
			_:
				ok = false
		if not ok:
			return false
	return true


## How many living units (horses not counted) match: of a "tag", a "team" or a "side", inside an "area" if given;
## "buildings": true counts their buildings too.
func count(q: Dictionary) -> int:
	var area := area_rect(String(q["area"])) if q.has("area") else Rect2()
	var list: Array = []
	if q.has("tag"):
		list = tagged(String(q["tag"]))
	else:
		var teams: Array = []
		if q.has("team"):
			teams = [team_index(String(q["team"]))]
		elif bool(q.get("mine", false)):
			teams = [game.human]
		elif q.has("side"):
			teams = teams_of_side(String(q["side"]))
		for u in game.units:
			if not u.dead and teams.has(u.team) and u.kind != "horse":
				list.append(u)
		if bool(q.get("buildings", false)):
			for b in game.buildings:
				if not b.dead and not b.ghost and teams.has(b.team):
					list.append(b)
	var kinds: Array = (q["kind"] if q["kind"] is Array else [q["kind"]]) if q.has("kind") else []
	var n := 0
	for e in list:
		if q.has("area") and not area.has_point(e.position if e is Unit else e.center()):
			continue
		if not kinds.is_empty() and not kinds.has(e.kind):
			continue
		n += 1
	return n


## Carry out one action ({name: value}; docs/campaign_engine.md lists them).
func act(a: Dictionary) -> void:
	for k in a:
		var v: Variant = a[k]
		match String(k):
			"say":
				say(v if v is Array else [v])
			"spawn":
				_spawn(v)
			"order":
				var us: Array = []
				if v.has("tag"):
					us = tagged(String(v["tag"]))
				elif v.has("team"):
					var t := team_index(String(v["team"]))
					us = game.units.filter(func(u) -> bool: return u.team == t and not u.dead)
				_order(us.filter(func(e) -> bool: return e is Unit), v)
			"objective":
				set_objective(String(v["id"]), String(v.get("set", "active")))
			"reveal":
				var r := area_rect(String(v["area"]))
				var si := Campaign.side_index(data, String(v.get("side", my_side())))
				var rad := int(ceil(maxf(r.size.x, r.size.y) / Defs.TILE * 0.5)) + 1
				var until := game.clock + float(v.get("secs", 1e9))
				reveals.append([si, game.cell_of(r.get_center()), rad, until])
				game._vis_t = 0.0
				_send({"k": "reveal", "r": [si, game.cell_of(r.get_center()), rad, until]})
			"ping":
				var p := area_rect(String(v["area"])).get_center()
				game._ping(p, Color(1, 0.85, 0.3))
				_send({"k": "ping", "p": p})
			"camera":
				var side := String(v.get("side", ""))
				if side == "" or side == my_side():
					game.camera.position = area_rect(String(v["area"])).get_center()
				_send({"k": "cam", "p": area_rect(String(v["area"])).get_center(), "s": side})
			"give":
				var t := team_index(String(v["team"]))
				if t >= 0:
					game.players[t]["gold"] = int(game.players[t]["gold"]) + int(v.get("gold", 0))
					game.players[t]["res2"] = float(game.players[t]["res2"]) + float(v.get("powder", 0))
			"mark":
				mark()
			"point":
				pointer = v if v is Dictionary else {}
				pointer_changed.emit()
			"win":
				finish(String(v))
			"lose":
				finish(_other_side(String(v)))


## Scripted orders go only to units no person plays (a co-op friend's or versus foe's units are theirs).
func _order(us: Array, v: Dictionary) -> void:
	us = us.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and not player_teams.has(u.team))
	if us.is_empty():
		return
	var p: Vector2 = area_rect(String(v["to"])).get_center() if v.has("to") else Vector2.INF
	match String(v.get("do", "")):
		"attack":
			game.group_move(us, p, true)
		"move":
			game.group_move(us, p, false)
		"hold":
			for u in us:
				u.cmd_hold()
		"stop":
			for u in us:
				u.cmd_stop()
		"patrol":
			for u in us:
				u.cmd_patrol(p)


## Lines of dialogue: shown here (those meant for this player's side) and sent to the friends online.
func say(ids: Array) -> void:
	for lid in ids:
		var ln := line(String(lid))
		if ln.is_empty():
			continue
		said_ids.append(String(lid))
		if game.mlog:
			game.mlog.add("(mission) %s: %s" % [ln["name"], ln["text"]])
		_show(ln)
	_send({"k": "say", "ids": ids})


func _show(ln: Dictionary) -> void:
	if String(ln.get("to", "")) == "" or String(ln["to"]) == my_side():
		said.emit(ln)


func set_objective(oid: String, state: String) -> void:
	if not obj.has(oid) or obj[oid] == state:
		return
	if obj[oid] in ["done", "failed"] and state != "active":
		return
	obj[oid] = state
	if game.mlog:
		game.mlog.add("(mission) objective %s: %s" % [oid, state])
	objectives_changed.emit()
	_send({"k": "obj", "o": obj.duplicate()})


func _check_objectives() -> void:
	for o in data.get("objectives", []):
		var oid := String(o["id"])
		if obj.get(oid, "") != "active":
			continue
		match String(o.get("kind", "manual")):
			"survive":
				if game.clock >= float(o.get("time", 0)):
					set_objective(oid, "done")
			"destroy":
				if tags.has(String(o["tag"])) and tagged(String(o["tag"])).is_empty():
					set_objective(oid, "done")
			"protect":
				if tags.has(String(o["tag"])) and tagged(String(o["tag"])).is_empty():
					set_objective(oid, "failed")
			"reach":
				var q := {"area": String(o["area"])}
				if o.has("tag"):
					q["tag"] = o["tag"]
				elif o.has("team"):
					q["team"] = o["team"]
				else:
					q["side"] = String(o.get("side_units", o["side"]))
				if count(q) >= int(o.get("count", 1)):
					set_objective(oid, "done")
	check_end()


## Who has won: a side whose primary objective failed loses (the other side wins); a side with every primary
## objective met wins (a "protect" one counts as met while it holds; at least one other must be done); a side wiped
## out (no units nor buildings, after having some, and past its "wiped_out" time) loses.
func check_end() -> void:
	if game.over or remote:
		return
	var wiped: Dictionary = data.get("wiped_out", {})
	for sd in Campaign.side_ids(data):
		var alive := count({"side": sd, "buildings": true})
		if alive > 0:
			_side_had[sd] = true
		elif _side_had.has(sd) and wiped.has(sd) and game.clock >= float(wiped[sd]):
			finish(_other_side(sd))
			return
	for sd in Campaign.side_ids(data):
		var prim := objectives_for(sd).filter(func(o: Dictionary) -> bool: return bool(o.get("primary", true)))
		if prim.is_empty():
			continue
		var met := true
		var some_done := false
		for o in prim:
			if o["state"] == "failed":
				finish(_other_side(sd))
				return
			if o["state"] == "done":
				some_done = true
			elif not (o["state"] == "active" and String(o.get("kind", "")) == "protect"):
				met = false
		if met and some_done:
			finish(sd)
			return


func _other_side(sd: String) -> String:
	for s in Campaign.side_ids(data):
		if s != sd:
			return s
	return ""


## The mission is over: `side_id` won. Game.ended goes out (Main shows the mission's end; an online guest learns it
## from the next snapshot).
func finish(side_id: String) -> void:
	if game.over:
		return
	winner_side = side_id
	var w := -1
	for t in team_ids.size():
		if side_of_team(t) == side_id:
			w = t
			break
	# the objectives left open are settled for the screen: the winners' protects held, the losers' are failed
	for o in data.get("objectives", []):
		var oid := String(o["id"])
		if obj[oid] == "active" and String(o.get("kind", "")) == "protect" and String(o["side"]) == side_id:
			obj[oid] = "done"
	if game.mlog:
		game.mlog.add("(mission) %s won" % side_id)
	_send({"k": "obj", "o": obj.duplicate()})
	game.over = true
	game.winner = w
	game.ended.emit(w)


## The winner of a finished match, as a side id (a guest learns the team from the snapshot).
func winner_side_of(team: int) -> String:
	return winner_side if winner_side != "" else side_of_team(team)


# ------------------------------------------------------------------ the TUTORIAL (docs/tutorial.md)

## A step begins: what the player does from now on is measured against this moment.
func mark() -> void:
	noted.clear()
	if game.camera:
		_cam0 = game.camera.position
		_zoom0 = game.camera.zoom
	_base = _my_counts()


## Something the player did that the map can't show (the HUD and the hotkey bar call it): "minimap", "group_set",
## "group_select". Game.note_tutorial passes it on.
func note(what: String) -> void:
	noted[what] = int(noted.get(what, 0)) + 1


## The player's units and buildings by kind (buildings placed but not yet started count: a ghost site).
func _my_counts() -> Dictionary:
	var out := {}
	for u in game.units:
		if u.team == game.human and not u.dead:
			out[u.kind] = int(out.get(u.kind, 0)) + 1
	for b in game.buildings:
		if b.team == game.human and not b.dead:
			out[b.kind] = int(out.get(b.kind, 0)) + 1
	return out


func _kinds(q: Variant) -> Array:
	if q is String:
		return [q]
	if q is Dictionary and q.has("kind"):
		return q["kind"] if q["kind"] is Array else [q["kind"]]
	return ["any"]


func _kind_ok(e: Entity, kinds: Array) -> bool:
	if kinds.has("any") or kinds.has(e.kind):
		return true
	return kinds.has("army") and e is Unit and not (e as Unit).is_worker()


func _need(q: Variant) -> int:
	return int(q.get("count", 1)) if q is Dictionary else 1


func _tutorial_cond(k: String, v: Variant) -> bool:
	match k:
		"selected":
			var sel: Array = game.selection.filter(func(e) -> bool: return is_instance_valid(e) and not e.dead and e.team == game.human)
			if v is Dictionary and bool(v.get("none", false)):
				return sel.is_empty()
			var kinds := _kinds(v)
			return sel.filter(func(e) -> bool: return _kind_ok(e, kinds)).size() >= _need(v)
		"camera_moved":
			return game.camera != null and game.camera.position.distance_to(_cam0) >= float(v)
		"zoomed":
			return game.camera != null and absf(game.camera.zoom.x - _zoom0.x) >= 0.08
		"more":
			var now := _my_counts()
			var n := 0
			for kk in _kinds(v):
				n += int(now.get(kk, 0)) - int(_base.get(kk, 0))
			return n >= _need(v)
		"built":
			var kinds := _kinds(v)
			return game.buildings.filter(func(b) -> bool: return b.team == game.human and not b.dead and b.built and kinds.has(b.kind)).size() >= _need(v)
		"rooted":
			var kinds := _kinds(v)
			return game.units.filter(func(u) -> bool: return u.team == game.human and not u.dead and kinds.has(u.kind) and BroodNew.rooted(u)).size() >= _need(v)
		"crew":
			var kinds := _kinds(v)
			var at_least := int(v.get("at_least", 1)) if v is Dictionary else 1
			var n := 0
			for e in game.buildings + game.units:
				if e.team == game.human and not e.dead and kinds.has(e.kind) and WorkerLabels.workers(game, e).size() >= at_least:
					n += 1
			return n >= _need(v)
		"group":
			for gr in game.groups:
				if (gr as Array).filter(func(x) -> bool: return is_instance_valid(x) and not x.dead).size() >= int(v):
					return true
			return false
		"did":
			var what := String(v.get("name", "")) if v is Dictionary else String(v)
			return int(noted.get(what, 0)) >= _need(v)
		"gear_view":
			return game.gear_net != null and game.gear_net.view == bool(v)
		"placing":
			var c := game.controls
			if c == null:
				return false
			var kinds := _kinds(v)
			return c.mode in ["place", "nb_root"] and (kinds.has("any") or kinds.has(String(c.place_kind)))
		"order":
			var us := tagged(String(v.get("tag", "")))
			return us.filter(func(u) -> bool: return u is Unit and String(u.order) == String(v.get("is", ""))).size() >= _need(v)
		"res":
			var p: Dictionary = game.players[game.human]
			for key in v:          # ("gold", "res2": powder or spoils, "tension": the Clockwork's)
				if float(p.get(String(key), 0)) < float(v[key]):
					return false
			return true
		"talked":
			return not talk_busy
	return false


# ------------------------------------------------------------------ fog: revealed areas (Game._update_vis)

func stamp_reveals() -> void:
	var keep: Array = []
	for r in reveals:
		if game.clock >= float(r[3]):
			continue
		keep.append(r)
		for t in game.n_players():
			if int(game.sides[t]) == int(r[0]):
				game._reveal_air(t, r[1], int(r[2]))
	reveals = keep


# ------------------------------------------------------------------ online

func _send(m: Dictionary) -> void:
	if remote or game == null or game.net == null or not game.net.is_host or game.net.link == null:
		return
	m["t"] = "camp"
	game.net.link.send(m, 0)


## Guest: a message from the host's mission (NetSession._on_message routes "camp" here).
func on_net(m: Dictionary) -> void:
	match String(m.get("k", "")):
		"say":
			for lid in m.get("ids", []):
				var ln := line(String(lid))
				if not ln.is_empty():
					said_ids.append(String(lid))
					_show(ln)
		"obj":
			var o: Variant = m.get("o", {})
			if o is Dictionary and o != obj:
				obj = (o as Dictionary).duplicate()
				objectives_changed.emit()
		"reveal":
			var r: Array = m.get("r", [])
			if r.size() == 4:
				reveals.append(r)
		"ping":
			game._ping(m.get("p", Vector2.ZERO), Color(1, 0.85, 0.3))
		"cam":
			var s := String(m.get("s", ""))
			if s == "" or s == my_side():
				game.camera.position = m.get("p", game.camera.position)
