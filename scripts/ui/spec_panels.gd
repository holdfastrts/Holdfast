class_name SpecPanels
extends RefCounted
## THE SPECTATOR PANELS (the spectator overhaul, 0.27.0; docs/spectator.md): watching computers or a replay, three panels,
## each opened and closed by its title and each with its own player dropdown, independent of each other and of VIEW
## (whose fog you see). Down the right:
##   PRODUCTION           what is being made (units, research, buildings going up, the Brood's eggs and moults)
##   ARMY & STRUCTURES    per player: army value, supply, resources (the painted icons), unit icons with counts (army,
##                        then workers) and building icons with counts (going up: dimmer, with a bar)
## and down the left, under the players' resources:
##   AI STORY             the computers' plans and decisions with their reasons (AIStory), newest first; the speaker
##                        mutes the narrator (also the N key and Settings > SOUND)
## Drawn by the HUD (hud.gd: _draw_rest) on its "rest" layer; only while game.spectating(), never in a match you play.
## Each column stays clear of VIEW, the minimap, the bottom panels, the command card and a replay's bar; the panels of
## a column share it (one that needs little gets it all, the others share the rest and show what fits, "... more").

const HEAD := 30.0             # a panel's title row
const GAP := 6.0
const ROW := 30.0              # a dropdown row
const PANELS := ["prod", "army", "story"]
const COLS := {"right": ["prod", "army"], "left": ["story"]}
const TITLES := {"prod": "PRODUCTION", "army": "ARMY & STRUCTURES", "story": "AI STORY"}

## Remembered for the session (the next match watched opens the same way).
static var open := {"prod": true, "army": true, "story": true}
static var team := {"prod": -1, "army": -1, "story": -1}

var hud
var game: Game
var drop := ""                 # the panel whose player list is open ("" none)
var story_skip := 0            # AI STORY: newest lines scrolled past
var _army := {}                # team -> the ARMY & STRUCTURES numbers (worked out twice a second)
var _army_t := -1.0
var _story_more := false


func _init(h) -> void:
	hud = h
	game = h.game
	if Settings.pc():
		return
	# (a phone: a short column; the ARMY panel starts closed the first time)
	if not _phone_set:
		_phone_set = true
		open["army"] = false


static var _phone_set := false


# ------------------------------------------------------------------ layout

func width() -> float:
	var vs: Vector2 = hud._vs()
	return clampf(vs.x * (0.3 if Settings.pc() else 0.34), 260.0, 380.0)


## A column: [x, top, bottom] (side "right" or "left").
func column(side: String) -> Array:
	var vs: Vector2 = hud._vs()
	var w := width()
	var x := vs.x - w - 8.0 if side == "right" else 8.0
	var top := 42.0
	if side == "left" and game.view_team < 0:
		# (all vision: the players' resource lines at the top left)
		var n := 0
		for t in game.n_players():
			if not game.eliminated[t]:
				n += 1
		top = 4.0 + n * 20.0 + 10.0 + 8.0
	var bottom := vs.y - 8.0
	var vr: Rect2 = hud.view_rect()
	if vr.end.x > x and vr.position.x < x + w:
		top = maxf(top, vr.end.y + 6.0)
	for r in [hud.mini_rect(), hud.card_rect(), hud.panel_rect(), hud.bar.rect(), replay_bar_rect()]:
		var rr: Rect2 = r
		if rr.size == Vector2.ZERO or rr.end.x <= x or rr.position.x >= x + w:
			continue
		if rr.position.y < 160.0:
			top = maxf(top, rr.end.y + 8.0)       # (the minimap at the top)
		else:
			bottom = minf(bottom, rr.position.y - 8.0)
	return [x, top, maxf(bottom, top + COLS[side].size() * (HEAD + GAP) + 40.0)]


## A replay's bar (scripts/ui/replay_bar.gd) in the HUD's units (Rect2() when none).
func replay_bar_rect() -> Rect2:
	if game.replay == null or not is_instance_valid(hud) or hud.get_parent() == null:
		return Rect2()
	for c in hud.get_parent().get_children():
		if c is ReplayBar and c.visible and c.get("_panel") != null:
			var pn: Control = c.get("_panel")
			var sc: float = hud.ui_scale
			return Rect2(pn.global_position / sc, pn.size / sc)
	return Rect2()


## Where each panel sits now: panel -> [header rect, body rect (size 0: closed)].
func layout() -> Dictionary:
	var out := {}
	var w := width()
	for side in COLS:
		var c := column(side)
		var x: float = c[0]
		var ps: Array = COLS[side]
		var avail: float = float(c[2]) - float(c[1]) - ps.size() * (HEAD + GAP)
		var want := {}
		var opened: Array = []
		for p in ps:
			if open[p]:
				opened.append(p)
				want[p] = _want_h(p, w)
		# water-filling: the panels that need little get it all, the rest share what is left
		var give := {}
		var left := maxf(avail, 0.0)
		var rest: Array = opened.duplicate()
		while not rest.is_empty():
			var share := left / rest.size()
			var small: Array = rest.filter(func(p: String) -> bool: return float(want[p]) <= share)
			if small.is_empty():
				for p in rest:
					give[p] = share
				break
			for p in small:
				give[p] = float(want[p])
				left -= float(want[p])
				rest.erase(p)
		var y: float = c[1]
		for p in ps:
			var hr := Rect2(x, y, w, HEAD)
			y += HEAD
			var h: float = float(give.get(p, 0.0))
			var br := Rect2(x, y + 2.0, w, h) if open[p] and h >= 24.0 else Rect2(x, y, w, 0)
			y += br.size.y + GAP + (2.0 if br.size.y > 0.0 else 0.0)
			out[p] = [hr, br]
	return out


const P_ICON := 28.0          # PRODUCTION's icons
const P_ROW := 36.0
const LABEL_W := 34.0         # the "P1" before a player's row
const ICON := 26.0            # ARMY & STRUCTURES' icons
const ICON_STEP := 30.0
const ICON_ROW := 32.0
const SEP := 8.0              # between army, workers and buildings


func _want_h(p: String, w: float) -> float:
	match p:
		"prod":
			var h := 8.0
			for t in teams_of("prod"):
				h += _prod_h(t, w)
			return h
		"army":
			var h := 8.0
			for t in teams_of("army"):
				h += _army_h(t, w)
			return h
		"story":
			return 9999.0           # (it takes the rest)
	return 0.0


func _prod_h(t: int, w: float) -> float:
	var n: int = hud.prod_items(t).size()
	if n == 0:
		return 22.0
	var per := maxi(1, int((w - 16.0 - LABEL_W) / (P_ICON + 4.0)))
	return ceilf(n / float(per)) * P_ROW


## The players a panel shows: its dropdown's pick, or every one still in (the AI STORY: every computer).
func teams_of(p: String) -> Array:
	var t: int = team[p]
	if t >= 0 and t < game.n_players():
		return [t]
	var out: Array = []
	for i in game.n_players():
		if p == "story" or not game.eliminated[i]:
			out.append(i)
	return out


## The dropdown's choices: [label, team, enabled].
func options(p: String) -> Array:
	var out: Array = [[("All AIs" if p == "story" else "All players"), -1, true]]
	var ais: Array = game.ai_story.ai_teams() if game.ai_story else []
	for t in game.n_players():
		if p == "story" and not ais.has(t):
			continue
		out.append([_who(t), t, p == "story" or not game.eliminated[t]])
	return out


func _who(t: int) -> String:
	return "P%d %s" % [t + 1, Loc.t(game.faction_of(t).capitalize())]


func pick_label(p: String) -> String:
	var t: int = team[p]
	if t < 0 or t >= game.n_players():
		return Loc.t("All AIs" if p == "story" else "All players")
	return _who(t)


# ------------------------------------------------------------------ the buttons

## Each panel's pieces now: panel -> {title, speaker (the AI STORY's), drop (its player button), body, all}.
func parts() -> Dictionary:
	var lay := layout()
	var out := {}
	for p in PANELS:
		var hr: Rect2 = lay[p][0]
		var br: Rect2 = lay[p][1]
		var dd_w := minf(150.0, hr.size.x * 0.42)
		var spk_w := 34.0 if p == "story" else 0.0
		var tr := Rect2(hr.position, Vector2(hr.size.x - dd_w - spk_w - 4.0, HEAD))
		out[p] = {"title": tr, "speaker": Rect2(tr.end.x + 2.0, hr.position.y, spk_w, HEAD) if spk_w > 0.0 else Rect2(),
			"drop": Rect2(hr.end.x - dd_w, hr.position.y, dd_w, HEAD), "body": br, "all": hr.merge(br) if br.size.y > 0.0 else hr}
	return out


## The open player list's rows: [rect, team, enabled, label].
func drop_rows() -> Array:
	if drop == "":
		return []
	var hr: Rect2 = layout()[drop][0]
	var w := minf(hr.size.x, 230.0)
	var x := hr.end.x - w
	var y := hr.end.y + 4.0
	var out: Array = []
	for o in options(drop):
		out.append([Rect2(x, y + 1, w, ROW), int(o[1]), bool(o[2]), String(o[0])])
		y += ROW + 2
	return out


# ------------------------------------------------------------------ input

## The press goes to the panels (the HUD asks before it takes a press).
func has_point(pt: Vector2) -> bool:
	if drop != "":
		return true                 # (an open list takes the next press anywhere: it closes it)
	var ps := parts()
	for p in ps:
		if (ps[p]["all"] as Rect2).has_point(pt):
			return true
	return false


func press(pt: Vector2) -> bool:
	if drop != "":
		var was := drop
		for r in drop_rows():
			if (r[0] as Rect2).has_point(pt) and bool(r[2]):
				team[was] = int(r[1])
				if was == "story":
					story_skip = 0
				Sfx.play_any(["ui/click", "click"])
		drop = ""
		return true
	var ps := parts()
	for p in PANELS:
		var q: Dictionary = ps[p]
		if (q["title"] as Rect2).has_point(pt):
			toggle(p)
		elif (q["speaker"] as Rect2).has_point(pt):
			toggle_voice()
		elif (q["drop"] as Rect2).has_point(pt):
			drop = p
		elif p == "story" and not Settings.pc() and (q["body"] as Rect2).has_point(pt):
			# (a phone: a tap on the story pages back through it, and from the oldest to the newest again)
			story_skip = story_skip + 4 if _story_more else 0
		else:
			continue
		Sfx.play_any(["ui/click", "click"])
		return true
	return has_point(pt)


## The mouse wheel over the AI STORY scrolls it (true if used).
func wheel(pt: Vector2, dir: int) -> bool:
	var br: Rect2 = layout()["story"][1]
	if br.size.y <= 0.0 or not br.has_point(pt):
		return has_point(pt)
	if dir < 0 or _story_more:
		story_skip = maxi(0, story_skip + dir)
	return true


func toggle(p: String) -> void:
	open[p] = not open[p]
	drop = ""


## Mute or unmute the narrator (the speaker, the N key). The new state.
func toggle_voice() -> bool:
	var on: bool = game.ai_story.narrator.toggle() if game.ai_story else Settings.narrator
	if hud:
		hud.toast(Loc.t("Narrator on") if on else Loc.t("Narrator muted"), false)
	return on


# ------------------------------------------------------------------ drawing

func draw() -> void:
	var ps := parts()
	var hv: Vector2 = hud._mouse() if Settings.pc() else Vector2(-1, -1)
	var font := UiStyle.bold_font()
	for p in PANELS:
		var q: Dictionary = ps[p]
		var tr: Rect2 = q["title"]
		UiStyle.draw_button(hud._ci, tr, tr.has_point(hv), open[p])
		_txt(font, Vector2(tr.position.x + 10, tr.position.y + 20), ("▾ " if open[p] else "▸ ") + Loc.t(TITLES[p]), 14, UiStyle.TEXT, tr.size.x - 14)
		var sr: Rect2 = q["speaker"]
		if sr.size.x > 0.0:
			UiStyle.draw_button(hud._ci, sr, sr.has_point(hv), false)
			SpeakerIcon.draw_icon(hud._ci, sr.grow(-5), not Settings.narrator, UiStyle.TEXT)
		var dr: Rect2 = q["drop"]
		UiStyle.draw_button(hud._ci, dr, dr.has_point(hv), drop == p)
		var tx := dr.position.x + 8
		if int(team[p]) >= 0:
			hud._ci.draw_rect(Rect2(tx, dr.position.y + 9, 11, 12), game.team_colour(int(team[p])))
			tx += 16
		_txt(font, Vector2(tx, dr.position.y + 20), pick_label(p) + ("  ▴" if drop == p else "  ▾"), 13, UiStyle.TEXT, dr.end.x - tx - 4)
		var br: Rect2 = q["body"]
		if br.size.y > 0.0:
			UiStyle.draw_panel(hud._ci, br, Color(0, 0, 0, 0), 0.82)
			match p:
				"prod":
					_draw_prod(br)
				"army":
					_draw_army(br)
				"story":
					_draw_story(br)
	if drop != "":
		_draw_drop()


func _draw_drop() -> void:
	var rows := drop_rows()
	if rows.is_empty():
		return
	var r0: Rect2 = rows[0][0]
	var hv: Vector2 = hud._mouse() if Settings.pc() else Vector2(-1, -1)
	UiStyle.draw_panel(hud._ci, Rect2(r0.position.x - 4, r0.position.y - 3, r0.size.x + 8, rows.size() * (ROW + 2) + 6), UiStyle.TRIM, 0.97)
	for o in rows:
		var r: Rect2 = o[0]
		var cur: bool = int(o[1]) == int(team[drop])
		UiStyle.draw_button(hud._ci, r, r.has_point(hv) and o[2], cur, o[2])
		var tx := r.position.x + 10
		if int(o[1]) >= 0:
			hud._ci.draw_rect(Rect2(tx, r.position.y + 9, 12, 12), game.team_colour(int(o[1])) if o[2] else Color(0.4, 0.4, 0.4))
			tx += 18
		var lab := Loc.t(String(o[3])) + ("" if o[2] else "  " + Loc.t("(out)"))
		_txt(UiStyle.bold_font(), Vector2(tx, r.position.y + 20), lab, 14, (Color(1, 0.9, 0.55) if cur else UiStyle.TEXT) if o[2] else Color(1, 1, 1, 0.4), r.end.x - tx - 4)


## PRODUCTION: each player's queues (hud.prod_items), one row each: "P1" and its icons.
func _draw_prod(br: Rect2) -> void:
	var per := maxi(1, int((br.size.x - 16.0 - LABEL_W) / (P_ICON + 4.0)))
	var y := br.position.y + 5.0
	var shown := 0
	var teams := teams_of("prod")
	var fb := UiStyle.bold_font()
	for t in teams:
		var items: Array = hud.prod_items(t)
		var h := _prod_h(t, br.size.x)
		if y + minf(h, P_ROW) > br.end.y + 2.0:
			break
		var x0 := br.position.x + 8.0
		hud._ci.draw_rect(Rect2(x0, y + 8, 4, 14), game.team_colour(t))
		_txt(fb, Vector2(x0 + 8, y + 20), "P%d" % (t + 1), 13, UiStyle.TEXT)
		if items.is_empty():
			_txt(UiStyle.body_font(), Vector2(x0 + LABEL_W, y + 16), Loc.t("(nothing in production)"), 12, UiStyle.MUTED, br.end.x - x0 - LABEL_W - 6)
		for i in items.size():
			var it: Array = items[i]
			var r := Rect2(x0 + LABEL_W + (i % per) * (P_ICON + 4), y + 2 + (i / per) * P_ROW, P_ICON, P_ICON)
			if r.end.y + 5 > br.end.y:
				break
			hud._ci.draw_rect(r, Color(0, 0, 0, 0.35))
			var ic: Texture2D = hud._icon(String(it[0]))
			if ic:
				hud._ci.draw_texture_rect(ic, r, false, Color.WHITE if float(it[1]) >= 0.0 else Color(1, 1, 1, 0.55))
			if float(it[1]) >= 0.0:
				hud._ci.draw_rect(Rect2(r.position.x, r.end.y + 1, P_ICON, 4), Color(0, 0, 0, 0.5))
				hud._ci.draw_rect(Rect2(r.position.x, r.end.y + 1, P_ICON * clampf(float(it[1]), 0.0, 1.0), 4), it[2])
		y += h
		shown += 1
	if shown < teams.size():
		_txt(UiStyle.body_font(), Vector2(br.end.x - 60, br.end.y - 4), Loc.t("... more"), 11, UiStyle.MUTED)


## The player's name line at the top of its block (with `note` after it, or its numbers at the right).
func _head_line(t: int, br: Rect2, y: float, note := "", right := "") -> void:
	hud._ci.draw_rect(Rect2(br.position.x + 10, y + 3, 10, 12), game.team_colour(t))
	var name := _who(t)
	_txt(UiStyle.bold_font(), Vector2(br.position.x + 26, y + 14), name + ("   " + note if note != "" else ""), 13, UiStyle.TEXT, br.size.x - 36)
	if right != "":
		var f := UiStyle.bold_font()
		var nw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var rw := f.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		if br.position.x + 26 + nw + 10 + rw < br.end.x - 8:
			_txt(f, Vector2(br.end.x - 8 - rw, y + 14), right, 12, Color(1, 0.88, 0.6))


# ------------------------------------------------------------------ ARMY & STRUCTURES

## One player's numbers: {value, sup, cap, res: [[icon, text]], army: [[kind, n]], workers, buildings: [[kind, n, building
## going up n, best progress]]}.
func army_info(t: int) -> Dictionary:
	if game.clock - _army_t > 0.5 or game.clock < _army_t:
		_army.clear()
		_army_t = game.clock
	if _army.has(t):
		return _army[t]
	var army := {}
	var workers := {}
	for u in game.units:
		if u.team != t or u.dead or u.kind == "horse" or u.kind == BroodNew.EGG:
			continue
		var d: Dictionary = workers if u.is_worker() else army
		d[u.kind] = int(d.get(u.kind, 0)) + 1
	var bld := {}
	for b in game.buildings:
		if b.team != t or b.dead or b.ghost:
			continue
		var e: Array = bld.get(b.kind, [b.kind, 0, 0, 0.0])
		if b.built:
			e[1] = int(e[1]) + 1
		else:
			e[2] = int(e[2]) + 1
			e[3] = maxf(float(e[3]), float(b.progress))
		bld[b.kind] = e
	var pl: Dictionary = game.players[t]
	var fac := game.faction_of(t)
	var res: Array = []
	match fac:
		"crown":
			res = [["res_gold", "%d" % int(pl["gold"])], ["res_powder", "%d" % int(pl["res2"])], ["res_horses", "%d" % game.horses_of(t).size()]]
		"brood":
			res = [["res_food", "%d" % int(pl["gold"])], ["res_spoils", "%d" % int(pl["res2"])]]
		_:
			if Defs.gear_mode:
				res = [["res_cogs", "%d" % int(pl["gold"])], ["tension", "%d" % int(float(pl.get("tension", 0.0)))]]
			else:
				res = [["", "%d ore" % int(pl["gold"])], ["", "%d energy" % int(game.energy[t])]]
	var by_n := func(d: Dictionary) -> Array:
		var out: Array = []
		for k in d:
			out.append([k, d[k]])
		out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and String(a[0]) < String(b[0])))
		return out
	var blist: Array = bld.values()
	blist.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) + int(a[2]) > int(b[1]) + int(b[2]) or (int(a[1]) + int(a[2]) == int(b[1]) + int(b[2]) and String(a[0]) < String(b[0])))
	var info := {"value": game.army_value(t), "sup": game.supply_used(t), "cap": int(pl["cap"]), "res": res,
		"army": by_n.call(army), "workers": by_n.call(workers), "buildings": blist}
	_army[t] = info
	return info


## The icons of one player in one flow: army, then workers, then buildings, a little apart: [x, y, it, building].
func _army_flow(t: int, w: float) -> Array:
	var a := army_info(t)
	var out: Array = []
	var x := 0.0
	var y := 0.0
	var first := true
	for k in ["army", "workers", "buildings"]:
		var list: Array = a[k]
		if list.is_empty():
			continue
		if not first:
			x += SEP
		first = false
		for it in list:
			if x + ICON > w:
				x = 0.0
				y += ICON_ROW
			out.append([x, y, it, k == "buildings", k])
			x += ICON_STEP
	return out


func _army_h(t: int, w: float) -> float:
	var fl := _army_flow(t, w - 20.0)
	var rows := 0.0 if fl.is_empty() else float(fl.back()[1]) / ICON_ROW + 1.0
	return 18.0 + 20.0 + rows * ICON_ROW + 6.0


func _draw_army(br: Rect2) -> void:
	var y := br.position.y + 5.0
	var teams := teams_of("army")
	var shown := 0
	var f := UiStyle.bold_font()
	for t in teams:
		if y + 40.0 > br.end.y:
			break
		var a := army_info(t)
		_head_line(t, br, y, "", Loc.t("army %d · supply %d/%d") % [int(a["value"]), int(a["sup"]), int(a["cap"])])
		y += 18.0
		# resources with the painted icons
		var x := br.position.x + 12.0
		for r in a["res"]:
			var tex: Texture2D = null
			if String(r[0]) == "tension":
				tex = hud._icon("tension")
			elif String(r[0]) != "":
				tex = UnitStats.texture(String(r[0]))
			if tex:
				hud._ci.draw_texture_rect(tex, Rect2(x, y + 1, 17, 17), false)
				x += 20.0
			_txt(f, Vector2(x, y + 14), String(r[1]), 13, Color(1, 0.92, 0.7))
			x += f.get_string_size(String(r[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12.0
		y += 20.0
		var last_k := ""
		var fl := _army_flow(t, br.size.x - 20.0)
		for e in fl:
			var r := Rect2(br.position.x + 10 + float(e[0]), y + float(e[1]), ICON, ICON)
			if r.end.y + 3 > br.end.y:
				break
			if String(e[4]) != last_k and last_k != "" and float(e[0]) > 0.0:
				hud._ci.draw_rect(Rect2(r.position.x - SEP * 0.5 - 2, r.position.y + 4, 1, ICON - 8), Color(1, 1, 1, 0.25))
			last_k = String(e[4])
			_icon_count(r, e[2], bool(e[3]))
		y += (0.0 if fl.is_empty() else float(fl.back()[1]) + ICON_ROW) + 6.0
		shown += 1
	if shown < teams.size():
		_txt(UiStyle.body_font(), Vector2(br.end.x - 60, br.end.y - 4), Loc.t("... more"), 11, UiStyle.MUTED)


## An icon with its count; a building kind going up: dimmer, with the bar of the furthest along.
func _icon_count(r: Rect2, it: Array, bld: bool) -> void:
	hud._ci.draw_rect(r, Color(0, 0, 0, 0.35))
	var ic: Texture2D = hud._icon(String(it[0]))
	var done: int = int(it[1])
	var going: int = int(it[2]) if bld else 0
	if ic:
		hud._ci.draw_texture_rect(ic, r, false, Color.WHITE if done > 0 else Color(1, 1, 1, 0.45))
	if going > 0:
		hud._ci.draw_rect(Rect2(r.position.x, r.end.y + 1, r.size.x, 3), Color(0, 0, 0, 0.55))
		hud._ci.draw_rect(Rect2(r.position.x, r.end.y + 1, r.size.x * clampf(float(it[3]), 0.0, 1.0), 3), Color(0.95, 0.75, 0.3))
	var n := str(done) if going == 0 else ("%d+%d" % [done, going] if done > 0 else "+%d" % going)
	if n != "1":
		var f := UiStyle.bold_font()
		var w := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_txt(f, Vector2(r.end.x - w - 1, r.end.y - 2), n, 12, Color(1, 0.95, 0.75) if going == 0 else Color(1, 0.8, 0.45))


# ------------------------------------------------------------------ AI STORY

func _draw_story(br: Rect2) -> void:
	var st: AIStory = game.ai_story
	var x := br.position.x + 10.0
	var w := br.size.x - 20.0
	var y := br.position.y + 4.0
	var bottom := br.end.y - 4.0
	var f := UiStyle.body_font()
	var fb := UiStyle.bold_font()
	var note := ""
	if st == null or st.ai_teams().is_empty():
		note = "No computers in this match."
	elif game.replay and st.entries.is_empty() and not game.replay.events.any(func(e: Array) -> bool: return String(e[1]) == "ai"):
		note = "This replay has no AI story (it was recorded before 0.27.0)."
	if Settings.narrator and st and not st.narrator.available and not st.narrator.fake:
		bottom -= 16.0
		_txt(f, Vector2(x, br.end.y - 6), Loc.t("No voice for this language here: text only."), 11, UiStyle.MUTED, w)
	if note != "":
		for ln in wrap_text(f, Loc.t(note), 13, w):
			_txt(f, Vector2(x, y + 14), ln, 13, UiStyle.MUTED)
			y += 17.0
		return
	var feed: Array = st.feed(int(team["story"]))
	if feed.is_empty():
		_txt(f, Vector2(x, y + 14), Loc.t("The computers are thinking..."), 13, UiStyle.MUTED, w)
		return
	story_skip = clampi(story_skip, 0, maxi(0, feed.size() - 1))
	var all := int(team["story"]) < 0
	_story_more = false
	if story_skip > 0:
		_txt(f, Vector2(br.end.x - 90, y + 11), "▲ %d" % story_skip, 11, UiStyle.MUTED)
	for i in range(story_skip, feed.size()):
		var e: Dictionary = feed[i]
		var prio := int(e["prio"])
		var size := 13 if prio >= 2 else 12
		var lh := 16.0 if prio >= 2 else 15.0
		var stamp := "%d:%02d" % [int(e["t"]) / 60, int(e["t"]) % 60]
		var lines := wrap_text(fb if prio >= 3 else f, st.text_of(e), size, w - 44.0)
		if y + lines.size() * lh + 2.0 > bottom:
			_story_more = true
			_txt(f, Vector2(br.end.x - 70, bottom + 2), "▼ %d" % (feed.size() - i), 11, UiStyle.MUTED)
			break
		_txt(f, Vector2(x, y + 12), stamp, 11, UiStyle.MUTED)
		if all:
			hud._ci.draw_rect(Rect2(x + 32, y + 3, 6, 11), game.team_colour(int(e["team"])))
		var col: Color = Color(1, 0.9, 0.6) if prio >= 3 else (UiStyle.TEXT if prio == 2 else Color(0.85, 0.82, 0.74, 0.62))
		for ln in lines:
			_txt(fb if prio >= 3 else f, Vector2(x + 44, y + 12), ln, size, col)
			y += lh
		y += 3.0


## Word-wrap s to width w at font size sz.
static func wrap_text(font: Font, s: String, sz: int, w: float) -> Array:
	var out: Array = []
	var line := ""
	for word in s.split(" ", false):
		var tryl := word if line == "" else line + " " + word
		if font.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= w or line == "":
			line = tryl
		else:
			out.append(line)
			line = word
	if line != "":
		out.append(line)
	return out


## Text as it is (already in the game's language), cut with "…" past max_w.
func _txt(font: Font, p: Vector2, s: String, sz: int, col: Color, max_w := -1.0) -> void:
	if max_w > 0.0 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > max_w:
		while s.length() > 1 and font.get_string_size(s + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > max_w:
			s = s.substr(0, s.length() - 1)
		s += "…"
	hud._ci.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 3, Color(0, 0, 0, col.a * 0.75))
	hud._ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
