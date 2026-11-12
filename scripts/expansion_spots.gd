class_name ExpansionSpots
extends Node2D
## EXPANSION SPOTS (docs/expansion_spots.md; the owner, 2026-10-27: "a few tiles in a different colour in each map
## showing the best expansion places"). The best free hall spots of each side are tinted on the ground: the hall's
## footprint (5 x 4 cells), each cell a pale gold tile with a thin dark-and-gold border round the whole spot. A side's
## best spot is a little brighter than its second.
##
## How a spot is picked (rate(), once per match, from the bare map): every free base site (Game.base_sites that is
## nobody's start) belongs to the side whose main is the fewest steps away by land. It is scored by the room for an
## economy round it (open, buildable cells on the hall's own ground level within Defs.ECON_RANGE: the Crown's Farms
## and Mill, the Clockwork's gear field, which meshes only on one level), the ways in (gaps through which an army
## walks up to it), the walk from its own main, and how much nearer it is to its own main than to the enemy's. The
## two best of each side are marked. The map is turned through its middle, so twin spots score the same.
## A CROWN side's marks follow its own rule instead (0.29.2, v2 0.29.5, CrownSites: the least hall distance from the main,
## either side of its ramp, near the ramp's foot and against the map's border; _crown_rule below). A CLOCKWORK side's
## follow its own too (0.30.10, ClockSites: room for the Clocktower's ring of buildings on its own level; _clock_rule).
## The Brood's are its Mound Turtle spots (nb_pick).
##
## Shown to every player (a Brood player sees its best Mound Turtle spots, nb_pick), with a small label (_label), and when watching
## (spectator, replay). A spot hides once a building the viewer knows of stands on it (his own and his allies', an
## enemy's once seen), and when its lode was drawn out by a hall that fell there. Settings.expansion_spots turns them
## off. No per-frame drawing: the tiles are drawn once and redrawn only when a spot is taken or freed, or while the
## player places a hall (the spots then a touch brighter). Code-drawn (docs/art_style_inconsistency.md).

const PICKS := 2                       # spots marked per side
const GOLD := Color(1.0, 0.78, 0.32)   # warm gold: team-neutral, reads on grass, sand, snow and ash
const SHADE := Color(0.3, 0.18, 0.04)  # the brown wash under it
const EXIT_R := 12.0                   # tiles: the ring round a spot where its ways in are counted
const CHECK := 0.5                     # seconds between looks for a taken spot

var game: Game
## [{c: hall cell, team, rank (1 best, 2 next), score, room (0..1), ways, home, foe}]
var spots: Array = []
var all: Array = []                    # every free base site rated (rate_all), for the computer
var shown: Array = []                  # the spots drawn now (tests)
var _t := 0.0
var _placing := false


func _ready() -> void:
	_crown_rule()
	_clock_rule()
	refresh()


# ------------------------------------------------------------------ the Crown's own spots (0.29.2)

## THE CROWN'S RULE (the owner, 2026-11-03 22:25, v2 2026-11-04 07:05; CrownSites, docs/expansion_spots.md): a Crown
## side's spots are not the base sites rated above but its own: the 2nd hall at the least hall distance from the main on
## the old natural's side of its ramp, the 3rd its mirror on the other side, both near the ramp's foot and against the
## map's border; from the 4th on as close as it may be to its halls. Rated on the bare map
## at the start; worked out again when the side's halls change (for the viewer's own side and its allies; for every side
## while watching: an enemy's new hall is not given away by its marks). The Clockwork and the rest keep the base-site rating.
var crown_on := not OS.get_cmdline_user_args().has("crownspots:off")
var _crown_halls := {}           # team -> the key of its halls when its spots were worked out


func _crown_rule() -> void:
	if not crown_on or game == null:
		return
	var crown_t := {}
	for t in game.n_players():
		if game.factions.size() > t and String(game.factions[t]) == "crown":
			crown_t[t] = true
	if crown_t.is_empty():
		return
	spots = spots.filter(func(s: Dictionary) -> bool: return not crown_t.has(int(s["team"])))
	for s in CrownSites.rate_sides(game):
		s["crown"] = true
		spots.append(s)


func _crown_update() -> void:
	if not crown_on or game == null:
		return
	for t in game.n_players():
		if game.factions.size() <= t or String(game.factions[t]) != "crown":
			continue
		if not (game.demo or game.replay != null or (game.human >= 0 and game.allied(t, game.human))):
			continue
		var halls: Array = game.halls_of(t, false)
		var key := ""
		for h in halls:
			key += str(h.cell)
		if not _crown_halls.has(t) and halls.size() <= 1:
			_crown_halls[t] = key
			continue            # (the main alone: the start's rating stands)
		if String(_crown_halls.get(t, "-")) == key:
			continue
		_crown_halls[t] = key
		var mids: Array = []
		for h in halls:
			mids.append(h.center() / float(Defs.TILE))
		if mids.is_empty():
			continue
		spots = spots.filter(func(s: Dictionary) -> bool: return int(s["team"]) != t)
		for s in CrownSites.pick(game, t, mids, PICKS):
			s["crown"] = true
			spots.append(s)


# ------------------------------------------------------------------ the Clockwork's own spots (clockwork-eco, 0.30.10)

## THE CLOCKWORK'S RULE (the owner, 2026-11-04 20:24: "Clocktowers need room around them... 3 different optimal expansion
## spots, one for each race"; ClockSites, docs/clockwork_eco.md): a Clockwork side's spots are where its Clocktower's ring
## and the ring of buildings it powers fit on open ground of its own level, near its halls and safe. Rated on the bare map
## at the start; worked out again when the side's halls change (the viewer's side and its allies; every side while
## watching), as the Crown's. `-- clocksites:off` keeps the base-site rating for the Clockwork (comparisons).
var clock_on := not OS.get_cmdline_user_args().has("clocksites:off")
var _clock_halls := {}


func _clock_rule() -> void:
	if not clock_on or game == null:
		return
	var ck := {}
	for t in game.n_players():
		if game.factions.size() > t and String(game.factions[t]) == "clockwork":
			ck[t] = true
	if ck.is_empty():
		return
	spots = spots.filter(func(s: Dictionary) -> bool: return not ck.has(int(s["team"])))
	for s in ClockSites.rate_sides(game):
		spots.append(s)


func _clock_update() -> void:
	if not clock_on or game == null:
		return
	for t in game.n_players():
		if game.factions.size() <= t or String(game.factions[t]) != "clockwork":
			continue
		if not (game.demo or game.replay != null or (game.human >= 0 and game.allied(t, game.human))):
			continue
		var halls: Array = game.halls_of(t, false)
		var key := ""
		for h in halls:
			key += str(h.cell)
		if not _clock_halls.has(t) and halls.size() <= 1:
			_clock_halls[t] = key
			continue            # (the main alone: the start's rating stands)
		if String(_clock_halls.get(t, "-")) == key:
			continue
		_clock_halls[t] = key
		var mids: Array = []
		for h in halls:
			mids.append(h.center() / float(Defs.TILE))
		if mids.is_empty():
			continue
		spots = spots.filter(func(s: Dictionary) -> bool: return int(s["team"]) != t)
		var hall: String = game.faction_hall(t)
		var check := func(c: Vector2i) -> bool: return game.placement_problem(t, hall, c, true) == ""
		for s in ClockSites.pick(game, t, mids, PICKS, [], {}, check, ClockSites.rings_of(game)):
			spots.append(s)


## Should the spots show at all, for this viewer.
func active() -> bool:
	if not Settings.expansion_spots or game == null or game.edit_mode:
		return false
	if game.demo or game.replay != null:
		return true
	if game.human < 0 or game.human >= game.n_players():
		return false
	return true          # (the Brood expands with Mound Turtles: its turtle spots, nb_pick)


## The viewer plays the Brood: its spots are the best TURTLE spots (nb_pick), not hall spots.
func _nb_view() -> bool:
	return not game.demo and game.replay == null and game.human >= 0 and BroodNew.on(game, game.human)


func _process(delta: float) -> void:
	var p := _placing_hall()
	_t -= delta
	if p != _placing or _t <= 0.0:
		_t = CHECK
		_placing = p
		refresh()


## Work out which spots show now; redraw only if that changed (or the placing look did).
func refresh() -> void:
	_crown_update()
	_clock_update()
	var now: Array = []
	if active():
		if _nb_view():
			now = nb_pick(game, game.human, self)
		else:
			for s in spots:
				if not _taken(s["c"]):
					now.append(s)
	var key := str(_placing)
	for s in now:
		key += str(s["c"]) + str(s.get("tc", "")) + str(s["rank"])
	if key != _key:
		_key = key
		shown = now
		queue_redraw()


var _key := "-"


func _placing_hall() -> bool:
	var ctl = game.controls if game else null
	if ctl == null or game.demo or game.human < 0:
		return false
	if String(ctl.mode) == "nb_root" and String(ctl.place_kind) == BroodNew.TURTLE:
		return true           # (the Brood placing a Mound Turtle)
	return String(ctl.mode) == "place" and String(ctl.place_kind) == game.faction_hall(game.human)


## A building the viewer knows of stands on the spot's tinted tiles (touches the overlay at all), or a rooted Mound Turtle
## / Brood Mother's footprint touches them (the owner, 2026-10-29: "if it touches the overlay it should vanish; if it's
## completely off the overlay it should still show"), or a hall fell there and drew its lode out.
func _taken(c: Vector2i) -> bool:
	var r := Rect2i(c, MapGen.HALL)
	for b in game.buildings:
		if b.dead or not Rect2i(Vector2i(b.cell), b.size).intersects(r):
			continue
		if (b.visible and not b.ghost) if game.demo else game.knows_building(game.human, b):
			return true
	# the Brood's base pieces rooted on the tiles: a Mound Turtle or the Brood Mother (one the viewer sees, or its own)
	var pr := Rect2(Vector2(r.position) * float(Defs.TILE), Vector2(r.size) * float(Defs.TILE))
	var mid := pr.get_center()
	for u in game.units_near(mid, 14.0 * float(Defs.TILE)):
		if u.dead or u.tesla_mode == "packed" or not (u.kind == BroodNew.TURTLE or u.kind == BroodNew.QUEEN):
			continue
		if not u.nb.has("fpx") or not BroodRoot.rect_of(u).grow(-1.0).intersects(pr):
			continue
		if game.demo or game.allied(u.team, game.human) or game.is_visible_to(game.human, u.position):
			return true
	for k in ["town_hall", "clocktower"]:
		if game.lode_at_spot(c, k) < 0.25:
			return true
	return false


func _draw() -> void:
	for s in shown:
		if s.has("tc"):
			_tile(s["tc"], int(s["rank"]) == 1, BroodRoot.fp(BroodNew.TURTLE)[0])      # (a Mound Turtle's footprint)
			if _placing:
				# while placing a turtle: how far its swamp would reach (a faint gold ring)
				var T := float(Game.T)
				var mid := (Vector2(s["tc"]) + Vector2(BroodRoot.fp(BroodNew.TURTLE)[0]) * 0.5) * T
				draw_arc(mid, float(Defs.NB["turtle_swamp"]) * T, 0, TAU, 72, Color(GOLD, 0.45 if int(s["rank"]) == 1 else 0.3), 2.0)
		else:
			_tile(s["c"], int(s["rank"]) == 1)


func _tile(c: Vector2i, best: bool, size: Vector2i = MapGen.HALL) -> void:
	var T := float(Game.T)
	var k := 1.5 if _placing else 1.0
	var fill := (0.3 if best else 0.2) * k
	var edge := (0.85 if best else 0.55) * minf(k, 1.15)
	for y in size.y:
		for x in size.x:
			var p := Vector2(c + Vector2i(x, y)) * T
			var cell := Rect2(p + Vector2(2, 2), Vector2(T - 4, T - 4))
			draw_rect(cell, Color(SHADE, fill * 0.6))      # (a light brown wash first: the gold then reads on snow and sand too)
			draw_rect(cell, Color(GOLD, fill))
	var r := Rect2(Vector2(c) * T, Vector2(size) * T).grow(-1.0)
	draw_rect(r, Color(0, 0, 0, 0.35 * edge), false, 3.5)
	draw_rect(r, Color(GOLD, edge), false, 1.75 if best else 1.25)


## THE LABEL (the owner, 22:09: the spots must READ as such; 2026-10-29: every one reads "OPTIMAL EXPANSION SPOT"; was "EXPANSION SPOT"
## on the next, small, on the tinted ground near its bottom edge. Shown while the camera is zoomed in to a normal view
## or nearer (LABEL_ZOOM; zoomed out the gold squares speak for themselves and words would clutter), and always while
## placing a hall or a Mound Turtle. Its size follows the zoom so it stays about LABEL_PX on screen.
const LABEL_ZOOM := 0.85
const LABEL_PX := 15.0


## The label's font size in map pixels now (0: not shown).
func _label_size() -> int:
	if game == null or game.camera == null:
		return 0
	var z := game.camera.zoom.x
	if z < LABEL_ZOOM and not _placing:
		return 0
	return clampi(int(round(LABEL_PX / maxf(z, 0.3))), 7, 20)


## Drawn on the game's overlay (Game._draw_mine_labels, as the workers' counts): over the map's lighting, so it reads
## on dark maps too; only the spots on screen.
func draw_labels(ci: CanvasItem) -> void:
	var fs := _label_size()
	if fs <= 0:
		return
	for s in shown:
		var sz: Vector2i = BroodRoot.fp(BroodNew.TURTLE)[0] if s.has("tc") else MapGen.HALL
		var c: Vector2i = Vector2i(s["tc"]) if s.has("tc") else Vector2i(s["c"])
		if game.view_rect.grow(200.0).has_point((Vector2(c) + Vector2(sz) * 0.5) * float(Game.T)):
			_label(ci, c, sz, int(s["rank"]) == 1, fs)


func _label(ci: CanvasItem, c: Vector2i, size: Vector2i, best: bool, fs: int) -> void:
	var T := float(Game.T)
	var font := UiStyle.bold_font()
	var txt := Loc.t("OPTIMAL EXPANSION SPOT")      # (every shown spot: the owner, 2026-10-29)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := Rect2(Vector2(c) * T, Vector2(size) * T)
	var p := Vector2(r.get_center().x - w * 0.5, r.end.y - float(fs) * 0.45)
	var a := 1.0 if _placing else (0.95 if best else 0.8)
	# a dark pill under it (the ground under the tint is often dark and busy), then the words in gold
	var pad := float(fs) * 0.35
	var pill := Rect2(p + Vector2(-pad, -float(fs) * 0.85), Vector2(w + pad * 2.0, float(fs) * 1.15))
	ci.draw_rect(pill, Color(0.08, 0.05, 0.0, 0.62 * a))
	ci.draw_rect(pill, Color(GOLD, 0.55 * a), false, maxf(1.0, float(fs) / 12.0))
	ci.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(GOLD.lightened(0.4 if best else 0.2), a))


## The minimap's marks (hud.gd draws them): small gold squares on the spots shown now.
func draw_on_minimap(ci: CanvasItem, m: Rect2) -> void:
	var k := m.size / Vector2(Game.W, Game.H)
	for s in shown:
		var mid := m.position + ((Vector2(s["tc"]) + Vector2(BroodRoot.fp(BroodNew.TURTLE)[0]) * 0.5) if s.has("tc") else (Vector2(s["c"]) + Vector2(MapGen.HALL) * 0.5)) * k
		var h := 2.5 if int(s["rank"]) == 1 else 2.0
		ci.draw_rect(Rect2(mid - Vector2(h, h), Vector2(h, h) * 2.0), Color(0, 0, 0, 0.6), false, 2.0)
		ci.draw_rect(Rect2(mid - Vector2(h, h), Vector2(h, h) * 2.0), Color(GOLD, 0.95 if int(s["rank"]) == 1 else 0.7), false, 1.0)


# ------------------------------------------------------------------ the Brood's turtle spots

## THE BROOD (the owner, 21:28: "no expansion spots shown for the Brood"): it expands by rooting a MOUND TURTLE
## on new ground (its swamp lets Rootmaws root there; 15+ tiles from the Mother and from the turtles that already count,
## it makes her lay faster: BroodNew.expansions). Its spots are its side's free base sites (rated as the hall spots:
## room, ways in, walk, safety: rate_all), each with the turtle's 3x3 footprint placed in it (nb_rate) and scored up for
## the Rootmaw circles that fit round it on its level, inside the turtle's swamp. Shown now (nb_pick): the PICKS best
## that are fresh ground, at least expansion_tiles from the Mother and from every turtle that already counts, and not
## taken (a building or a rooted creature on the spot, a turtle of the side rooted there, its Rootmaw ground spent).
var nb_cands := {}          # team -> [{c, team, tc (the turtle's top-left cell), maws, score, ...}], best first


## The side's candidate turtle spots, rated once (from the base sites' hall ratings and the ground).
static func nb_rate(g: Game, t: int, all_sites: Array) -> Array:
	var out: Array = []
	var fs: Vector2i = BroodRoot.fp(BroodNew.TURTLE)[0]
	for s in all_sites:
		if int(s["team"]) != t:
			continue
		var c: Vector2i = s["c"]
		# (start-spots-fix: worked out in side t's first-start frame and mirrored back, Game.start_flip: the footprint's
		# rounding and the order of the cells looked at fell the other way on a mirrored start, a tile off its mirror)
		var mid: Vector2 = g.sym_pt(t, (Vector2(c) + Vector2(MapGen.HALL) * 0.5) * Defs.TILE) / Defs.TILE
		var tc := Vector2i(-1, -1)
		# the turtle's footprint in the hall spot (its middle first, then round it): level, open ground, no ramp
		for r in 4:
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if tc.x >= 0 or (absi(dx) != r and absi(dy) != r):
						continue
					var cc := g.sym_rect(t, Vector2i(int(mid.x - fs.x * 0.5), int(mid.y - fs.y * 0.5)) + Vector2i(dx, dy), fs)
					if _ground_ok(g, cc, fs):
						tc = cc
		if tc.x < 0:
			continue
		var maws := _maw_room(g, tc, fs, t)
		if maws < 1:
			continue           # (room for a turtle and a Rootmaw circle; since 0.24.7's 8-tile circles one fits round a turtle)
		var e: Dictionary = s.duplicate()
		e["tc"] = tc
		e["maws"] = maws
		e["score"] = float(s["score"]) + 12.0 * float(maws)
		out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["score"]) - float(b["score"])) > 0.001:
			return float(a["score"]) > float(b["score"])
		return float(a["home"]) < float(b["home"]))
	return out


## A footprint of `sz` at `c` on open, level ground with no ramp (the terrain only).
static func _ground_ok(g: Game, c: Vector2i, sz: Vector2i) -> bool:
	var lv := -999
	for y in sz.y:
		for x in sz.x:
			var cc := c + Vector2i(x, y)
			if not g.in_map(cc):
				return false
			var i := g.idx(cc)
			if g.solid[i] == 1 or g.cliff[i] != 0 or g.ramp[i] != 0:
				return false
			if lv == -999:
				lv = int(g.height[i])
			elif int(g.height[i]) != lv:
				return false
	return true


## How many Rootmaw circles fit round a turtle at `tc` (greedy, their middles PIT_CLAIM x 2 tiles apart, inside its
## swamp, on its level, clear of its footprint).
static func _maw_room(g: Game, tc: Vector2i, fs: Vector2i, t := -1) -> int:
	# (start-spots-fix: the circles are laid in side t's first-start frame and mirrored back)
	var mid := Vector2(g.sym_rect(t, tc, fs)) + Vector2(fs) * 0.5
	var lv := int(g.height[g.idx(tc)])
	var ms: Vector2i = BroodRoot.fp(BroodNew.MAW)[0]
	var apart := float(Defs.PIT_CLAIM) * 2.0
	var reach := float(Defs.NB["turtle_swamp"]) - 1.5
	var got: Array = []
	var trect := Rect2i(tc, fs).grow(1)
	for ring in [3.5, 5.5, 7.5]:
		if ring > reach:
			break
		for i in 16:
			var p: Vector2 = mid + Vector2.from_angle(TAU * i / 16.0 + ring * 0.3) * ring
			var mc := g.sym_rect(t, Vector2i(int(p.x - ms.x * 0.5), int(p.y - ms.y * 0.5)), ms)
			if Rect2i(mc, ms).intersects(trect) or not _ground_ok(g, mc, ms) or int(g.height[g.idx(mc)]) != lv:
				continue
			if got.all(func(o: Vector2) -> bool: return o.distance_to(p) >= apart):
				got.append(p)
	return got.size()


## The turtle spots shown now for side t (the PICKS best still good), ranked 1, 2.
static func nb_pick(g: Game, t: int, es: ExpansionSpots) -> Array:
	if not es.nb_cands.has(t):
		es.nb_cands[t] = nb_rate(g, t, es.all)
	var q := BroodNew.queen(g, t)
	var far := float(Defs.NB["expansion_tiles"]) * Defs.TILE
	var counted: Array = BroodNew.expansions(g, q) if q != null else []
	var out: Array = []
	for s in es.nb_cands[t]:
		if out.size() >= PICKS:
			break
		var feet := BroodRoot.feet_at(BroodNew.TURTLE, s["tc"])
		if q != null and q.position.distance_to(feet) < far:
			continue
		if counted.any(func(o: Unit) -> bool: return o.position.distance_to(feet) < far):
			continue
		var taken := false
		for u in g.units_near(feet, 7.0 * Defs.TILE):
			if u.team == t and u.kind == BroodNew.TURTLE and not u.dead and u.tesla_mode != "packed":
				taken = true          # (a turtle of the side already rooted there)
		if taken or es._taken(s["c"]) or BroodRoot.place_problem(g, t, BroodNew.TURTLE, feet).begins_with("Blocked"):
			continue
		var spent := false
		for id in g.nb_spots:
			var sp: Dictionary = g.nb_spots[id]
			if (sp["p"] as Vector2).distance_to(feet) < float(Defs.NB["turtle_swamp"]) * Defs.TILE and float(sp["left"]) < float(Defs.PIT_GROUND) * 0.5:
				spent = true           # (not fresh ground: Rootmaws drew it out)
		if spent:
			continue
		var e: Dictionary = s.duplicate()
		e["rank"] = out.size() + 1
		out.append(e)
	return out


# ------------------------------------------------------------------ rating

## Rate every free base site from the bare map (call before any building stands) and keep each side's best.
static func rate(g: Game) -> Array:
	return rate_all(g).filter(func(s: Dictionary) -> bool: return int(s["rank"]) > 0)


## Every free base site rated, each side's best PICKS ranked 1, 2 (the rest rank 0): the computer's hall choice uses all of
## them (AI._site_bonus, docs/ai_round6.md). `dist_in`: each player's _steps from its start, when worked out already
## (CrownSites.warm does one a tick).
static func rate_all(g: Game, dist_in: Array = []) -> Array:
	var out: Array = []
	var n := g.n_players()
	if n < 1 or g.starts.size() < n:
		return out
	var dist: Array = dist_in if dist_in.size() == n else []
	if dist.is_empty():
		for t in n:
			dist.append(_steps(g, g.starts[t]))
	var mine := {}               # team -> [{c, ...}]
	for c in g.base_sites:
		if g.starts.slice(0, n).has(c):
			continue
		var best_t := -1
		var bd := INF
		var tie := false
		for t in n:
			var d := _foot_d(g, dist[t], c)
			if d < bd:
				bd = d
				best_t = t
				tie = false
			elif d == bd:
				tie = tie or not g.allied(t, best_t)
		if best_t < 0 or tie or bd == INF:
			continue
		var foe := INF
		for o in n:
			if g.hostile(o, best_t):
				foe = minf(foe, _foot_d(g, dist[o], c))
		var room := _room(g, c)
		var ways := _ways(g, c)
		var safe := clampf((foe - bd) if foe < INF else 60.0, -40.0, 60.0)
		var score := 100.0 * room - bd + 0.5 * safe - 6.0 * maxf(0.0, float(ways[0]) - 1.0) - 0.25 * maxf(0.0, float(ways[1]) - 8.0)
		if not mine.has(best_t):
			mine[best_t] = []
		mine[best_t].append({"c": c, "team": best_t, "score": score, "room": room, "ways": int(ways[0]),
			"gap": int(ways[1]), "home": bd, "foe": foe})
	for t in mine:
		var list: Array = mine[t]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if absf(float(a["score"]) - float(b["score"])) > 0.001:
				return float(a["score"]) > float(b["score"])
			return float(a["home"]) < float(b["home"]))
		for i in list.size():
			var s: Dictionary = list[i]
			s["rank"] = i + 1 if i < PICKS else 0
			out.append(s)
	return out


## Steps by land (4 ways) from round a hall at `c` to every cell (INF: none).
static func _steps(g: Game, c: Vector2i) -> PackedFloat32Array:
	# (0.28.1, perf-stutter: the same steps, worked in map indices: with a Vector2i queue each map took ~15 ms, and the
	# Crown computer's first hall search asked for four or five at once, a 55 ms frame)
	var W := Game.W
	var H := Game.H
	var n_cells := W * H
	var d := PackedFloat32Array()
	d.resize(n_cells)
	d.fill(INF)
	var solid: PackedByteArray = g.solid
	var cliff: PackedByteArray = g.cliff
	var q := PackedInt32Array()
	for y in MapGen.HALL.y:
		for x in MapGen.HALL.x:
			var cc := c + Vector2i(x, y)
			if g.in_map(cc):
				d[g.idx(cc)] = 0.0
				q.append(g.idx(cc))
	var head := 0
	while head < q.size():
		var i: int = q[head]
		head += 1
		var nd := d[i] + 1.0
		var x := i % W
		if x + 1 < W and d[i + 1] == INF and solid[i + 1] != 1 and cliff[i + 1] == 0:
			d[i + 1] = nd
			q.append(i + 1)
		if x > 0 and d[i - 1] == INF and solid[i - 1] != 1 and cliff[i - 1] == 0:
			d[i - 1] = nd
			q.append(i - 1)
		if i + W < n_cells and d[i + W] == INF and solid[i + W] != 1 and cliff[i + W] == 0:
			d[i + W] = nd
			q.append(i + W)
		if i - W >= 0 and d[i - W] == INF and solid[i - W] != 1 and cliff[i - W] == 0:
			d[i - W] = nd
			q.append(i - W)
	return d


## Land an army walks over (the bare map: no buildings yet).
static func _open(g: Game, c: Vector2i) -> bool:
	var i := g.idx(c)
	return g.solid[i] != 1 and g.cliff[i] == 0


static func _foot_d(g: Game, d: PackedFloat32Array, c: Vector2i) -> float:
	var best := INF
	for y in MapGen.HALL.y:
		for x in MapGen.HALL.x:
			var cc := c + Vector2i(x, y)
			if g.in_map(cc):
				best = minf(best, d[g.idx(cc)])
	return best


static func _mid(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(MapGen.HALL) * 0.5


## 0..1: the open, buildable ground on the spot's own level, joined to it, within a hall's economy reach.
## (0.30.5: worked over a byte grid of the reach's box, filled row by row: the same cells as the walk it replaced
## (_room_walk, kept for a spot over the map's edge and for tools/time_crown_pick.gd's check), ~0.7 ms a spot before,
## and the Crown's hall pick measures dozens.)
static func _room(g: Game, c: Vector2i) -> float:
	var W := Game.W
	var H := Game.H
	if c.x < 0 or c.y < 0 or c.x + MapGen.HALL.x > W or c.y + MapGen.HALL.y > H or g.height.size() != W * H:
		return _room_walk(g, c)
	var mid := _mid(c)
	var lv := int(g.height[g.idx(c + Vector2i(2, 2))])
	var reach := float(Defs.ECON_RANGE)
	var r2 := reach * reach
	var solid: PackedByteArray = g.solid
	var ramp: PackedByteArray = g.ramp
	var cliff: PackedByteArray = g.cliff
	var height: PackedByteArray = g.height
	var bx0 := maxi(0, int(floor(mid.x - reach - 0.5)))
	var bx1 := mini(W - 1, int(ceil(mid.x + reach - 0.5)))
	var by0 := maxi(0, int(floor(mid.y - reach - 0.5)))
	var by1 := mini(H - 1, int(ceil(mid.y + reach - 0.5)))
	var bw := bx1 - bx0 + 1
	var bh := by1 - by0 + 1
	# 1: the room's ground (the hall's own cells, or open ground on its level with the cell's middle within reach)
	var ok := PackedByteArray()
	ok.resize(bw * bh)
	for y in range(by0, by1 + 1):
		var dy := y + 0.5 - mid.y
		var dy2 := dy * dy
		var row := y * W
		var brow := (y - by0) * bw - bx0
		var hall_row := y >= c.y and y < c.y + MapGen.HALL.y
		for x in range(bx0, bx1 + 1):
			if hall_row and x >= c.x and x < c.x + MapGen.HALL.x:
				ok[brow + x] = 1
				continue
			var dx := x + 0.5 - mid.x
			if dx * dx + dy2 > r2:
				continue
			var i := row + x
			if solid[i] == 0 and ramp[i] == 0 and cliff[i] == 0 and int(height[i]) == lv:
				ok[brow + x] = 1
	# the part joined to the hall (4 ways): a run along a row at a time; 2 marks a cell counted
	var count := 0
	var stack := PackedInt32Array([c.x - bx0, c.y - by0])
	while not stack.is_empty():
		var n := stack.size()
		var sy: int = stack[n - 1]
		var sx: int = stack[n - 2]
		stack.resize(n - 2)
		var base := sy * bw
		if ok[base + sx] != 1:
			continue
		var xl := sx
		while xl > 0 and ok[base + xl - 1] == 1:
			xl -= 1
		var xr := sx
		while xr < bw - 1 and ok[base + xr + 1] == 1:
			xr += 1
		for x in range(xl, xr + 1):
			ok[base + x] = 2
		count += xr - xl + 1
		if sy > 0:
			var nb := base - bw
			var inside := false
			for x in range(xl, xr + 1):
				var o := ok[nb + x] == 1
				if o and not inside:
					stack.append(x)
					stack.append(sy - 1)
				inside = o
		if sy < bh - 1:
			var nb2 := base + bw
			var inside2 := false
			for x in range(xl, xr + 1):
				var o2 := ok[nb2 + x] == 1
				if o2 and not inside2:
					stack.append(x)
					stack.append(sy + 1)
				inside2 = o2
	return clampf(float(count) / (PI * reach * reach), 0.0, 1.0)


## (_room as it was: a walk from the hall's cells, Vector2i keys; for a spot over the map's edge, and the check)
static func _room_walk(g: Game, c: Vector2i) -> float:
	var mid := _mid(c)
	var lv := int(g.height[g.idx(c + Vector2i(2, 2))]) if g.height.size() == Game.W * Game.H else 0
	var reach := float(Defs.ECON_RANGE)
	var seen := {}
	var q: Array = []
	for y in MapGen.HALL.y:
		for x in MapGen.HALL.x:
			var cc := c + Vector2i(x, y)
			seen[cc] = true
			q.append(cc)
	var head := 0
	var count := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		count += 1
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2: Vector2i = p + dd
			if seen.has(n2) or not g.in_map(n2):
				continue
			var i := g.idx(n2)
			if (Vector2(n2) + Vector2(0.5, 0.5)).distance_to(mid) > reach:
				continue
			if g.solid[i] != 0 or g.ramp[i] != 0 or g.cliff[i] != 0 or (lv >= 0 and g.height.size() > i and int(g.height[i]) != lv):
				continue
			seen[n2] = true
			q.append(n2)
	return clampf(float(count) / (PI * reach * reach), 0.0, 1.0)


## [ways in, cells of gap]: the separate openings (8-joined runs of open land) just outside EXIT_R that the land
## round the spot (walked from it within EXIT_R) leads out through.
static func _ways(g: Game, c: Vector2i) -> Array:
	var mid := _mid(c)
	var seen := {}
	var q: Array = []
	for y in MapGen.HALL.y:
		for x in MapGen.HALL.x:
			var cc := c + Vector2i(x, y)
			seen[cc] = true
			q.append(cc)
	var exits := {}
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2: Vector2i = p + dd
			if seen.has(n2) or not g.in_map(n2) or not _open(g, n2):
				continue
			if (Vector2(n2) + Vector2(0.5, 0.5)).distance_to(mid) > EXIT_R:
				exits[n2] = true
				continue
			seen[n2] = true
			q.append(n2)
	# group the exit cells
	var groups := 0
	var done := {}
	for e in exits:
		if done.has(e):
			continue
		groups += 1
		var st: Array = [e]
		done[e] = true
		while not st.is_empty():
			var p: Vector2i = st.pop_back()
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n2 := p + Vector2i(dx, dy)
					if exits.has(n2) and not done.has(n2):
						done[n2] = true
						st.append(n2)
	return [groups, exits.size()]
