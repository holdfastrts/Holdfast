class_name AIStory
extends Node
## THE AI STORY (spectator overhaul 0.27.0, docs/spectator.md): what each computer is planning and why, as short narrator
## sentences, for the AI STORY panel (SpecPanels) and the narrator's voice (Narrator). Only while watching computers
## or a replay (game.spectating): it is made by main.gd next to the Spectator, never in a match you play.
##
## Where the lines come from:
##  - the computers' own match-log lines (AI._say, AIScout, AITransition, AIBroodNew.say...): MatchLog.add hands every
##    line written during an AI's think (MatchLog.ai_team) to AIStory.from_log, which rewrites it with the phrase book
##    (AIStoryLines.RULES) and also writes it into the replay being recorded (event "ai"), so a replay tells it too;
##  - the plan at the start (each AI's level and strategy, the Crown's opening);
##  - a look once a second at what each computer builds: its first building of each kind (tech) and each new hall.
## The feed: newest last, at most MAX. The same player's lines of one tag within MERGE s are merged into one (the
## newer one's words, "×2"); the same sentence again within SAME s is dropped; details (priority 1) at most one per
## player every MINOR_GAP s. Priority 3 lines are spoken; priority 2 only after QUIET s without speech.

const MAX := 160
const MERGE := 10.0
const SAME := 45.0
const MINOR_GAP := 6.0
const QUIET := 12.0
const LOOK := 1.0

var game: Game
var entries: Array = []         # {t, team, text (English template), args, prio, tag, n}
var narrator: Narrator
var silent := false             # (a replay rebuilding its story after a seek: no voice)
var version := 0                # changes with the feed (the HUD redraws)
var dropped := 0                # lines dropped as repeats or bursts (tests)
var merged := 0                 # lines merged into the one before (tests)
var _minor_t := {}              # team -> when its last detail was kept
var _seen := {}                 # team -> {building kind: true} (the look)
var _halls := {}                # team -> halls seen
var _look_t := 0.0
var _planned := false
var _last_voice := -999.0
static var recorded := 0        # lines written into replays being recorded (tests)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	narrator = Narrator.new()
	narrator.name = "Narrator"
	add_child(narrator)


func _process(delta: float) -> void:
	if game == null or game.replay != null:
		return               # (a replay's story comes from its file: ReplayPlayer)
	if not _planned and not game.ais.is_empty():
		_planned = true
		for a in game.ais:
			tell_plan(a.team, String(a.strategy), int(a.difficulty), String(a.opening) if game.faction_of(a.team) == "crown" else "")
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = LOOK
		_look()


# ------------------------------------------------------------------ in

## From MatchLog.add: a line the computer of `team` wrote while it thought.
static func from_log(g: Game, text: String, team: int) -> void:
	if g == null or team < 0 or (g.rec == null and g.ai_story == null):
		return
	var who: String = g.mlog.who(team) if g.mlog else ""
	var rest := text
	if who != "" and rest.begins_with(who):
		rest = rest.substr(who.length())
	rest = rest.strip_edges(true, false) if not rest.begins_with("'s ") else rest
	var m := AIStoryLines.match_line(rest)
	var tpl := "%s: %s"
	var args: Array = [rest]
	var prio := 1
	var tag := "detail"
	if not m.is_empty():
		tpl = String(m["template"])
		args = m["args"]
		prio = int(m["prio"])
		tag = String(m["tag"])
		if tpl == "":
			return             # (a duplicate of another line)
		if tpl.count("%s") != args.size() + 1:
			tpl = "%s: %s"       # (the phrase book and the line disagree: the line as it is)
			args = [rest]
	if g.rec:
		g.rec.note_event("ai", [team, tpl, args, prio, tag])
		recorded += 1
	if g.ai_story:
		g.ai_story.tell(team, tpl, args, prio, tag)


## A replay's recorded line (event "ai": [time, "ai", team, template, args, prio, tag]).
func from_event(e: Array) -> void:
	if e.size() < 7:
		return
	tell(int(e[2]), String(e[3]), e[4] as Array, int(e[5]), String(e[6]), float(e[0]))


## The plan at the start: level and strategy (and the Crown's opening).
func tell_plan(team: int, strategy: String, level: int, opening := "") -> void:
	var tpl: String = AIStoryLines.PLANS.get(strategy, AIStoryLines.PLANS["balanced"])
	var args: Array = [AIStoryLines.LEVELS[clampi(level, 0, 3)]]
	say_live(team, tpl, args, 3, "plan")
	if opening != "":
		var o := "%s opens with a Horse Breeder: it plans an early Horseman rush." if opening == "breeder" else "%s opens with a Powder Mill: Musketeers first, a steady line of fire."
		say_live(team, o, [], 2, "opening")


## A line of the story's own (the plan, the look): told and written into the replay being recorded.
func say_live(team: int, tpl: String, args: Array, prio: int, tag: String) -> void:
	if game.rec:
		game.rec.note_event("ai", [team, tpl, args, prio, tag])
		recorded += 1
	tell(team, tpl, args, prio, tag)


## Add a line to the feed (merged, de-duplicated, rate-limited) and maybe speak it. True if it was kept.
func tell(team: int, tpl: String, args: Array, prio: int, tag: String, at := -1.0) -> bool:
	var t: float = game.clock if at < 0.0 else at
	# the same sentence again soon: dropped
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		if t - float(e["t"]) > SAME:
			break
		if int(e["team"]) == team and String(e["tpl"]) == tpl and e["args"] == args:
			dropped += 1
			return false
	# a detail: at most one per player every MINOR_GAP s
	if prio <= 1:
		if t - float(_minor_t.get(team, -999.0)) < MINOR_GAP:
			dropped += 1
			return false
		_minor_t[team] = t
	# the same player and tag a moment ago: one line (the newer words, the bigger priority)
	for i in range(entries.size() - 1, maxi(-1, entries.size() - 6), -1):
		var e: Dictionary = entries[i]
		if t - float(e["t"]) > MERGE:
			break
		if int(e["team"]) == team and String(e["tag"]) == tag and tag != "detail" and prio <= int(e["prio"]) and prio < 3:
			e["n"] = int(e["n"]) + 1
			if prio == int(e["prio"]):
				e["tpl"] = tpl
				e["args"] = args
				e["t"] = t
			merged += 1
			version += 1
			return true
	var entry := {"t": t, "team": team, "tpl": tpl, "args": args, "prio": prio, "tag": tag, "n": 1}
	entries.append(entry)
	if entries.size() > MAX:
		entries.pop_front()
	version += 1
	_voice(entry)
	return true


func _voice(e: Dictionary) -> void:
	if silent or narrator == null or game == null or not game.spectating():
		return
	if game.replay and (game.replay.speed > 2.0 or not game.replay.playing):
		return               # (fast forward: the voice can't keep up)
	var p := int(e["prio"])
	var now := narrator.now()
	if p >= 3 or (p == 2 and now - _last_voice > QUIET and narrator.queue.is_empty() and not narrator.is_speaking()):
		_last_voice = now
		narrator.say(text_of(e), p)


## Forget everything (a replay's seek: the story is told again up to the new time, silently).
func clear() -> void:
	entries.clear()
	_minor_t.clear()
	version += 1
	if narrator:
		narrator.stop()


# ------------------------------------------------------------------ out

## The player's name as the panel shows it: "P1 Crown".
func who(team: int) -> String:
	return "P%d %s" % [team + 1, Loc.t(game.faction_of(team).capitalize())]


## An entry's sentence in the game's language.
func text_of(e: Dictionary) -> String:
	var args: Array = [who(int(e["team"]))]
	for a in e["args"]:
		var s := String(a)
		if s.is_valid_int() or (s.contains(":") and s.replace(":", "").is_valid_int()):
			args.append(s)
		else:
			args.append(", ".join(Array(s.split(", ")).map(func(x: String) -> String: return Loc.t(x))))
	var tpl := Loc.t(String(e["tpl"]))
	var out := tpl % args if tpl.count("%s") == args.size() else String(e["tpl"]).replace("%s", "?")
	if int(e["n"]) > 1:
		out += "  ×%d" % int(e["n"])
	return out


## The feed for one AI (-1: every one), newest first.
func feed(team := -1) -> Array:
	var out: Array = []
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		if team < 0 or int(e["team"]) == team:
			out.append(e)
	return out


## The teams that are computers (live: game.ais; a replay: the slots that were computers).
func ai_teams() -> Array:
	var out: Array = []
	if game.replay:
		var slots: Array = (game.replay.header.get("cfg", {}) as Dictionary).get("slots", [])
		for t in mini(slots.size(), game.n_players()):
			if String((slots[t] as Dictionary).get("who", "")) in ["easy", "normal", "hard", "brutal"]:
				out.append(t)
		return out
	for a in game.ais:
		if not out.has(a.team):
			out.append(a.team)
	out.sort()
	return out


# ------------------------------------------------------------------ the look

## Each computer's first building of each kind (its tech) and each new hall (an expansion).
func _look() -> void:
	var ais := ai_teams()
	if ais.is_empty():
		return
	var halls := {}
	var fresh: Array = []
	for b in game.buildings:
		if b.dead or b.ghost or not ais.has(b.team):
			continue
		var t: int = b.team
		if b.kind == game.faction_hall(t):
			halls[t] = int(halls.get(t, 0)) + 1
			continue
		if not _seen.has(t):
			_seen[t] = {}
		if (_seen[t] as Dictionary).has(b.kind):
			continue
		_seen[t][b.kind] = true
		if game.clock > 2.0:
			fresh.append(b)
	for t in halls:
		var was := int(_halls.get(t, -1))
		_halls[t] = int(halls[t])
		if was >= 0 and int(halls[t]) > was:
			say_live(t, "%s starts a new base (base %s).", [str(halls[t])], 3, "expand")
	for b in fresh:
		var d: Dictionary = Defs.BUILDINGS.get(b.kind, {})
		var fac: Dictionary = Defs.FACTIONS.get(game.faction_of(b.team), {})
		if d.get("line", false) or (fac.get("econ", {}) as Dictionary).has(b.kind) or (fac.get("econ_line", {}) as Dictionary).has(b.kind) \
				or b.kind == String(fac.get("supply", "")):
			continue          # (walls, the economy, houses: not news)
		var trains: Array = d.get("trains", [])
		var names: Array = []
		for k in trains:
			if Defs.UNITS.has(k) and names.size() < 3 and k != "horse" and not Defs.UNITS[k].get("worker", false):
				names.append(String(Defs.UNITS[k]["name"]))
		if names.is_empty():
			say_live(b.team, "%s starts its first %s: new tech.", [String(d.get("name", b.kind))], 2, "tech")
		else:
			say_live(b.team, "%s starts its first %s, to make %s.", [String(d.get("name", b.kind)), ", ".join(names)], 2, "tech")
