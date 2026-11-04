class_name Campaign
extends RefCounted
## The campaign's data (docs/campaign_engine.md): the chapter list (campaign/campaign.json), the missions
## (campaign/missions/<id>.json), their maps (campaign/maps/<name>.json, the map editor's format, map id
## "campaign:<name>") and the player's progress (user://campaign.json). The running mission is MissionRun.

const DIR := "res://campaign"
const PROGRESS := "user://campaign.json"
const MODES := ["solo", "coop", "versus"]
const MODE_LABEL := {"solo": "SOLO", "coop": "CO-OP", "versus": "VERSUS"}
## A team's "control" per mode: "p1" (the first player: you in solo, the host online), "p2" (the friend online),
## "script" (the mission's triggers move it: no computer player), or "ai:<level>:<plan>" (the normal computer).

static var _cache := {}


static func _json(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	var out: Dictionary = d if d is Dictionary else {}
	_cache[path] = out
	return out


static func index() -> Dictionary:
	return _json(DIR + "/campaign.json")


## The storylines (campaign.json "storylines"): each {id, title, about, missions: [ids in order], requires: a mission
## id that opens it ("" or none: open from the start)}. The campaign branches by storylines (e.g. after the prologue,
## one line per hero), and inside a storyline by each mission's "next" (who won).
static func storylines() -> Array:
	return index().get("storylines", [])


## Every mission id, storyline by storyline.
static func mission_ids() -> Array:
	var out: Array = []
	for sl in storylines():
		for id in sl.get("missions", []):
			out.append(String(id))
	return out


static func storyline_of(id: String) -> Dictionary:
	for sl in storylines():
		if (sl.get("missions", []) as Array).has(id):
			return sl
	return {}


## Is this storyline open? (Its "requires" mission is done, or it has none.)
static func storyline_open(sl: Dictionary, p: Dictionary = {}) -> bool:
	if p.is_empty():
		p = progress()
	var req := String(sl.get("requires", ""))
	return req == "" or (p["done"] as Dictionary).has(req)


## The storylines a finished mission opens (their "requires").
static func opens(id: String) -> Array:
	return storylines().filter(func(sl: Dictionary) -> bool: return String(sl.get("requires", "")) == id)


static func mission(id: String) -> Dictionary:
	var path := "%s/missions/%s.json" % [DIR, id]
	var m := _json(path)
	if m.has("steps") and not m.has("_expanded"):
		expand_steps(m)          # (a TUTORIAL lesson: its steps become lines, tasks and triggers: docs/tutorial.md)
	return m


## A lesson's STEPS (docs/tutorial.md) written out as the engine's own parts, once, in place: each step's lines
## (inline texts get ids "<step>_<n>"), its task (an objective of kind "manual" with "task": true, hidden until the
## step starts), and two triggers: "start_<step>" (after the step before it is done: says the lines, shows the task,
## points, runs its "do", and marks the camera, the counts and the noted actions so its wait is measured from here)
## and "done_<step>" (its "wait" holds: the task is ticked, the pointer goes, "then" runs). After the last step the
## lesson is won ("steps_end": "win", the default) or the match goes on to its normal end ("").
static func expand_steps(m: Dictionary) -> void:
	m["_expanded"] = true
	var side := String(m.get("tutorial_side", ""))
	if side == "":
		side = String((m.get("sides", [{}]) as Array)[0].get("id", ""))
	var teacher := String(m.get("teacher", "teacher"))
	if not m.has("lines"):
		m["lines"] = {}
	if not m.has("objectives"):
		m["objectives"] = []
	if not m.has("triggers"):
		m["triggers"] = []
	var steps: Array = m["steps"]
	var prev := ""
	for i in steps.size():
		var st: Dictionary = steps[i]
		var sid := String(st.get("id", "s%d" % i))
		var ids: Array = []
		var n := 0
		for ln in st.get("say", []):
			if ln is String and (m["lines"] as Dictionary).has(ln):
				ids.append(ln)
				continue
			n += 1
			var lid := "%s_%d" % [sid, n]
			var e := {"who": String(st.get("who", teacher))}
			if ln is Dictionary:
				e["text"] = String(ln.get("pc", ln.get("text", "")))
				if ln.has("phone"):
					e["phone"] = String(ln["phone"])
			else:
				e["text"] = String(ln)
			m["lines"][lid] = e
			ids.append(lid)
		var start_do: Array = [{"mark": true}]
		if not ids.is_empty():
			start_do.append({"say": ids})
		if st.has("task"):
			var tk: Variant = st["task"]
			var o := {"id": "task_" + sid, "side": side, "kind": "manual", "primary": false, "task": true, "hidden": true,
				"text": String(tk.get("pc", tk.get("text", ""))) if tk is Dictionary else String(tk)}
			if tk is Dictionary and tk.has("phone"):
				o["phone"] = String(tk["phone"])
			m["objectives"].append(o)
			start_do.append({"objective": {"id": "task_" + sid, "set": "active"}})
		start_do.append({"point": st.get("point", {})})
		start_do.append_array(st.get("do", []))
		var when: Dictionary = {"fired": "done_" + prev} if prev != "" else {"time": 0.5}
		m["triggers"].append({"id": "start_" + sid, "when": when, "delay": float(st.get("delay", 0.5 if prev == "" else 1.0)), "do": start_do, "step": sid})
		var wait: Variant = st.get("wait", {"talked": true})
		var done_do: Array = [{"point": {}}]
		if st.has("task"):
			done_do.append({"objective": {"id": "task_" + sid, "set": "done"}})
		done_do.append_array(st.get("then", []))
		m["triggers"].append({"id": "done_" + sid, "when": {"all": [{"fired": "start_" + sid}, wait]}, "delay": float(st.get("after", 0.6)), "do": done_do})
		prev = sid
	if prev != "" and String(m.get("steps_end", "win")) == "win":
		m["triggers"].append({"id": "lesson_won", "when": {"fired": "done_" + prev}, "delay": 1.5, "do": [{"win": side}]})


static func map_data(name: String) -> Dictionary:
	return _json("%s/maps/%s.json" % [DIR, name])


static func modes_of(m: Dictionary) -> Array:
	return (m.get("modes", ["solo"]) as Array).filter(func(x) -> bool: return MODES.has(String(x)))


static func side_ids(m: Dictionary) -> Array:
	return (m.get("sides", []) as Array).map(func(s: Dictionary) -> String: return String(s["id"]))


static func side_index(m: Dictionary, side_id: String) -> int:
	return side_ids(m).find(side_id)


static func side_name(m: Dictionary, side_id: String) -> String:
	for s in m.get("sides", []):
		if String(s["id"]) == side_id:
			return String(s.get("name", side_id))
	return side_id


static func control_of(team: Dictionary, mode: String) -> String:
	var c: Variant = team.get("control", "script")
	if c is Dictionary:
		return String((c as Dictionary).get(mode, "script"))
	return String(c)


## CAMPAIGN-ONLY FACTIONS (e.g. the human tribes, planned, design pending): a mission declares them in "factions":
## {"tribes": {"name": "...", "stand_in": "crown", "campaign_only": true}}; a team may then say "faction": "tribes".
## They never appear in the skirmish or online lobbies (those list Main.FACS / NetLobby.FACTIONS, playable factions
## only). Until the faction exists in Defs.FACTIONS (with "campaign_only": true) the match plays its "stand_in".
static func engine_faction(m: Dictionary, f: String) -> String:
	if Defs.FACTIONS.has(f):
		return f
	return String(m.get("factions", {}).get(f, {}).get("stand_in", "crown"))


static func faction_known(m: Dictionary, f: String) -> bool:
	return Defs.FACTIONS.has(f) or Defs.FACTIONS.has(String(m.get("factions", {}).get(f, {}).get("stand_in", "")))


## The side a player seat plays in this mode ("p1" / "p2"): the side of its first team ("" none).
static func seat_side(m: Dictionary, mode: String, seat: String) -> String:
	for tm in m.get("teams", []):
		if control_of(tm, mode) == seat:
			return String(tm["side"])
	return ""


## The match setup Main.start takes: the map, one slot per team (who / faction / colour / side), and "campaign".
## `host_seat`: the seat this machine plays ("p1" normally; online versus the host may take "p2"). `online`: the
## other seat is a friend ("remote"); offline only "p1" teams are yours and a "p2" team falls back to its solo control.
static func make_cfg(id: String, mode: String, host_seat := "p1", online := false) -> Dictionary:
	var m := mission(id)
	var slots: Array = []
	for tm in m.get("teams", []):
		var ctl := control_of(tm, mode)
		var slot := {"faction": engine_faction(m, String(tm.get("faction", "crown"))), "colour": int(tm.get("colour", Defs.COLOUR_RANDOM)),
			"side": maxi(0, side_index(m, String(tm["side"]))), "team_id": String(tm["id"])}
		if ctl == host_seat:
			slot["who"] = "you"
		elif ctl == "p1" or ctl == "p2":
			slot["who"] = "remote" if online else "script"
		elif ctl.begins_with("ai"):
			var p := ctl.split(":")
			slot["who"] = p[1] if p.size() > 1 and ["easy", "normal", "hard", "brutal"].has(p[1]) else "normal"
			slot["strategy"] = p[2] if p.size() > 2 else "balanced"
		else:
			slot["who"] = "script"
		slots.append(slot)
	return {"map": String(m.get("map", "random")), "slots": slots, "campaign": {"mission": id, "mode": mode, "seat": host_seat}}


# ------------------------------------------------------------------ progress

static func progress() -> Dictionary:
	var f := FileAccess.open(PROGRESS, FileAccess.READ)
	if f == null:
		return {"reached": [], "done": {}}
	var d: Variant = JSON.parse_string(f.get_as_text())
	var p: Dictionary = d if d is Dictionary else {}
	if not p.has("reached"):
		p["reached"] = []
	if not p.has("done"):
		p["done"] = {}
	return p


static func save_progress(p: Dictionary) -> void:
	var f := FileAccess.open(PROGRESS, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(p, "\t"))


## Open to play: the first mission of an open storyline, any mission a finished one led to, any mission already
## finished.
static func unlocked(id: String, p: Dictionary = {}) -> bool:
	if p.is_empty():
		p = progress()
	var sl := storyline_of(id)
	if not sl.is_empty() and storyline_open(sl, p) and String((sl["missions"] as Array)[0]) == id:
		return true
	return (p["reached"] as Array).has(id) or (p["done"] as Dictionary).has(id)


## The mission after `id` when `side_id` won it ("" none: not written yet). "next" is {side: id} (the story's branch
## by who won) or one id for every outcome; without it, the next mission of the same storyline. ("" also when the
## story goes on in the storylines this mission opens: `opens`.)
static func next_of(id: String, side_id: String) -> String:
	var m := mission(id)
	if m.has("next"):
		var n: Variant = m["next"]
		if n is Dictionary:
			return String((n as Dictionary).get(side_id, ""))
		return String(n)
	var ids: Array = storyline_of(id).get("missions", [])
	var i := ids.find(id)
	return String(ids[i + 1]) if i >= 0 and i + 1 < ids.size() else ""


## A mission ended: who won (the side id), in which mode, and which side this player played. A win for your side (or
## any end of a versus match: the story follows who won) unlocks the branch it leads to.
static func record(id: String, mode: String, winner_side: String, my_side: String) -> String:
	var p := progress()
	var counts := winner_side != "" and (winner_side == my_side or mode == "versus")
	var nxt := next_of(id, winner_side) if counts else ""
	if counts:
		var done: Dictionary = p["done"]
		var e: Dictionary = done.get(id, {})
		e["won_by"] = winner_side
		e["mode"] = mode
		e["played"] = int(e.get("played", 0)) + 1
		done[id] = e
		if nxt != "" and not (p["reached"] as Array).has(nxt):
			(p["reached"] as Array).append(nxt)
		save_progress(p)
	return nxt


# ------------------------------------------------------------------ text

## Every player-facing string of campaign.json: storylines, hubs (hotspots, talks), rooms.
static func index_strings() -> Array:
	var out: Array = [String(index().get("title", ""))]
	for sl in storylines():
		out.append_array([String(sl.get("title", "")), String(sl.get("about", ""))])
		var hub: Dictionary = sl.get("hub", {})
		out.append(String(hub.get("title", "")))
		out.append(String(hub.get("still", {}).get("caption", "")))
		for hs in hub.get("hotspots", []):
			out.append(String(hs.get("label", "")))
		for k in hub.get("talks", {}):
			var tk: Dictionary = hub["talks"][k]
			out.append(String(tk.get("name", "")))
			for e in tk.get("entries", []):
				for ln in e.get("lines", []):
					out.append(String(ln))
	for k in index().get("rooms", {}):
		out.append_array([String(index()["rooms"][k].get("title", "")), String(index()["rooms"][k].get("text", ""))])
	return out.filter(func(s: String) -> bool: return s != "")


## Every player-facing string of a mission (the translation check: tools/test_campaign.gd).
static func strings_of(m: Dictionary) -> Array:
	var out: Array = [String(m.get("title", "")), String(m.get("summary", ""))]
	for s in m.get("sides", []):
		out.append(String(s.get("name", "")))
		if s.has("about"):
			out.append(String(s["about"]))
	for o in m.get("objectives", []):
		out.append(String(o.get("text", "")))
		out.append(String(o.get("phone", "")))
	for k in m.get("speakers", {}):
		out.append(String(m["speakers"][k].get("name", "")))
	for k in m.get("lines", {}):
		out.append(String(m["lines"][k].get("text", "")))
		out.append(String(m["lines"][k].get("phone", "")))
	for k in m.get("stills", {}):
		out.append(String(m["stills"][k].get("caption", "")))
	for k in m.get("briefing", {}):
		for t in m["briefing"][k].get("text", []):
			out.append(String(t))
	for k in m.get("debrief", {}):
		out.append(String(m["debrief"][k].get("title", "")))
		out.append(String(m["debrief"][k].get("text", "")))
	for x in m.get("learn", []):
		out.append(String(x))          # (a TUTORIAL lesson's list of what it teaches, and its words after a loss)
	out.append(String(m.get("lost", "")))
	return out.filter(func(s: String) -> bool: return s != "")


## What is wrong with a mission's data ([] = nothing): names that point nowhere, unknown kinds, conditions and actions.
static func problems(m: Dictionary) -> Array:
	var out: Array = []
	if m.is_empty():
		return ["the mission file is missing or not valid JSON"]
	var sides := side_ids(m)
	var teams: Array = (m.get("teams", []) as Array).map(func(t: Dictionary) -> String: return String(t["id"]))
	var areas: Dictionary = m.get("areas", {})
	var lines: Dictionary = m.get("lines", {})
	var objs: Array = (m.get("objectives", []) as Array).map(func(o: Dictionary) -> String: return String(o["id"]))
	var trig: Array = (m.get("triggers", []) as Array).map(func(t: Dictionary) -> String: return String(t.get("id", "")))
	var mp := String(m.get("map", ""))
	if mp.begins_with("campaign:") and map_data(mp.substr(9)).is_empty():
		out.append("map %s: no file campaign/maps/%s.json" % [mp, mp.substr(9)])
	elif not mp.begins_with("campaign:") and not MapData.NAMED.has(mp) and not MapGen.MAPS.has(mp):
		out.append("map %s: unknown" % mp)
	for tm in m.get("teams", []):
		if not sides.has(String(tm.get("side", ""))):
			out.append("team %s: unknown side %s" % [tm["id"], tm.get("side")])
		if not faction_known(m, String(tm.get("faction", "crown"))):
			out.append("team %s: unknown faction" % tm["id"])
		if tm.has("camera") and not areas.has(String(tm["camera"])):
			out.append("team %s: unknown camera area %s" % [tm["id"], tm["camera"]])
		for md in modes_of(m):
			var c := control_of(tm, md)
			if not (c in ["p1", "p2", "script"] or c.begins_with("ai")):
				out.append("team %s: unknown control %s" % [tm["id"], c])
	for md in modes_of(m):
		if seat_side(m, md, "p1") == "":
			out.append("mode %s: no team for p1" % md)
		if md != "solo" and seat_side(m, md, "p2") == "":
			out.append("mode %s: no team for p2" % md)
	if m.has("modes") and (m["modes"] as Array).has("versus") and seat_side(m, "versus", "p1") == seat_side(m, "versus", "p2"):
		out.append("versus: p1 and p2 are on the same side")
	for list_key in ["units", "buildings"]:
		for it in m.get(list_key, []):
			if not teams.has(String(it.get("team", ""))):
				out.append("%s: unknown team %s" % [list_key, it.get("team")])
			var k := String(it.get("kind", ""))
			if (list_key == "units" and not Defs.UNITS.has(k)) or (list_key == "buildings" and not Defs.BUILDINGS.has(k)):
				out.append("%s: unknown kind %s" % [list_key, k])
			if it.get("at") is String and not areas.has(String(it["at"])):
				out.append("%s: unknown area %s" % [list_key, it["at"]])
	for k in lines:
		var ln: Dictionary = lines[k]
		if not (m.get("speakers", {}) as Dictionary).has(String(ln.get("who", ""))):
			out.append("line %s: unknown speaker %s" % [k, ln.get("who")])
		if ln.has("to") and not sides.has(String(ln["to"])):
			out.append("line %s: unknown side %s" % [k, ln["to"]])
		if ln.has("still") and not (m.get("stills", {}) as Dictionary).has(String(ln["still"])):
			out.append("line %s: unknown still %s" % [k, ln["still"]])
	for o in m.get("objectives", []):
		if not sides.has(String(o.get("side", ""))):
			out.append("objective %s: unknown side" % o["id"])
		if not ["survive", "destroy", "protect", "reach", "manual"].has(String(o.get("kind", ""))):
			out.append("objective %s: unknown kind %s" % [o["id"], o.get("kind")])
		if o.has("area") and not areas.has(String(o["area"])):
			out.append("objective %s: unknown area" % o["id"])
	for tr in m.get("triggers", []):
		_check_cond(tr.get("when", {}), "trigger %s" % tr.get("id", "?"), out, sides, teams, areas, objs, trig)
		for a in tr.get("do", []):
			_check_action(a, "trigger %s" % tr.get("id", "?"), out, m, sides, teams, areas, lines, objs)
	for k in m.get("briefing", {}):
		if not sides.has(String(k)):
			out.append("briefing: unknown side %s" % k)
	for k in m.get("debrief", {}):
		if not sides.has(String(k)):
			out.append("debrief: unknown side %s" % k)
	return out


static func _check_cond(c: Variant, where: String, out: Array, sides: Array, teams: Array, areas: Dictionary, objs: Array, trig: Array) -> void:
	if not (c is Dictionary) or (c as Dictionary).is_empty():
		out.append("%s: no condition" % where)
		return
	for k in c:
		match String(k):
			"time", "dead", "hurt":
				pass
			# the TUTORIAL's conditions (what the player did: docs/tutorial.md)
			"selected", "camera_moved", "zoomed", "more", "built", "rooted", "crew", "group", "did", "gear_view", \
					"placing", "order", "res", "talked":
				var q: Variant = c[k]
				if q is Dictionary and q.has("kind"):
					for kk in (q["kind"] if q["kind"] is Array else [q["kind"]]):
						if not (String(kk) in ["any", "army"] or Defs.UNITS.has(String(kk)) or Defs.BUILDINGS.has(String(kk))):
							out.append("%s: %s of unknown kind %s" % [where, k, kk])
			"all", "any":
				for s in c[k]:
					_check_cond(s, where, out, sides, teams, areas, objs, trig)
			"not":
				_check_cond(c[k], where, out, sides, teams, areas, objs, trig)
			"count":
				var q: Dictionary = c[k]
				if q.has("area") and not areas.has(String(q["area"])):
					out.append("%s: unknown area %s" % [where, q["area"]])
				if q.has("side") and not sides.has(String(q["side"])):
					out.append("%s: unknown side %s" % [where, q["side"]])
				if q.has("team") and not teams.has(String(q["team"])):
					out.append("%s: unknown team %s" % [where, q["team"]])
			"done", "failed":
				if not objs.has(String(c[k])):
					out.append("%s: unknown objective %s" % [where, c[k]])
			"fired":
				if not trig.has(String(c[k])):
					out.append("%s: unknown trigger %s" % [where, c[k]])
			_:
				out.append("%s: unknown condition %s" % [where, k])


static func _check_action(a: Variant, where: String, out: Array, m: Dictionary, sides: Array, teams: Array, areas: Dictionary, lines: Dictionary, objs: Array) -> void:
	if not (a is Dictionary) or (a as Dictionary).size() != 1:
		out.append("%s: an action must be one {name: value}" % where)
		return
	var k := String((a as Dictionary).keys()[0])
	var v: Variant = a[k]
	match k:
		"say":
			for id in v:
				if not lines.has(String(id)):
					out.append("%s: unknown line %s" % [where, id])
		"spawn":
			if not teams.has(String(v.get("team", ""))):
				out.append("%s: spawn for unknown team" % where)
			if not Defs.UNITS.has(String(v.get("kind", ""))):
				out.append("%s: spawn of unknown kind %s" % [where, v.get("kind")])
			if v.get("at") is String and not areas.has(String(v["at"])):
				out.append("%s: unknown area %s" % [where, v["at"]])
		"order":
			if not ["attack", "move", "hold", "stop", "patrol"].has(String(v.get("do", ""))):
				out.append("%s: unknown order %s" % [where, v.get("do")])
			if v.has("to") and not areas.has(String(v["to"])):
				out.append("%s: unknown area %s" % [where, v["to"]])
		"objective":
			if not objs.has(String(v.get("id", ""))):
				out.append("%s: unknown objective %s" % [where, v.get("id")])
		"reveal", "ping", "camera":
			if not areas.has(String(v.get("area", ""))):
				out.append("%s: unknown area %s" % [where, v.get("area")])
		"give":
			if not teams.has(String(v.get("team", ""))):
				out.append("%s: give to unknown team" % where)
		"win", "lose":
			if not sides.has(String(v)):
				out.append("%s: unknown side %s" % [where, v])
		"mark":
			pass
		"point":
			if v is Dictionary and v.has("area") and not areas.has(String(v["area"])):
				out.append("%s: point at unknown area %s" % [where, v["area"]])
			if v is Dictionary and v.has("ui") and not ["minimap", "card", "hotbar", "top", "groups", "objectives"].has(String(v["ui"])):
				out.append("%s: point at unknown ui %s" % [where, v["ui"]])
			if v is Dictionary and v.has("kind") and not (Defs.UNITS.has(String(v["kind"])) or Defs.BUILDINGS.has(String(v["kind"]))):
				out.append("%s: point at unknown kind %s" % [where, v["kind"]])
		_:
			out.append("%s: unknown action %s" % [where, k])
