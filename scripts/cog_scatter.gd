class_name CogScatter
extends Node2D
## SCATTER COGS (the owner's idea, 2026-11-01: "a slow spell for clockwork without magic. The Great Winder could have a
## spell that it throws a lot of cogs and parts from its top in an area of effect, littering the ground with stuff. This
## would make that area a slow field."; numbers in Defs.COG_SCATTER, docs/cog_scatter.md).
## An ability aimed at a spot, through the spells' pipeline (Game.cast_order / Unit.cmd_cast / Game.cast_spell, spell
## "scatter", caster Defs.GREAT_WINDER_KIND): the Great Winder rolls within `range` of the spot, its key arm winds for
## `cast` s (the telegraph: its WIND strip), then THROW: the cogs are paid, its hopper flings `parts` pieces (cogs, bolts,
## springs, nuts, plates) in arcs that land after `flight` s, and the spot is a field in Game.zones (kind "scatter") for
## `time` s more. TICK_ZONE: ENEMY ground units whose feet are in the litter (Game.in_ellipse, `radius`) get Unit.litter_t
## topped up to `linger` s; while it lasts, Unit._tick_unit moves them at `slow` of their speed (not their attacks).
## Flyers are not slowed (`air`), nor the caster's side and allies unless `slows_own`.
## The unit's state: `scatter_ready` (the game clock when its hopper can throw again; saved, streamed online and in
## replays: the card's countdown), `litter_t` (host: slowed s left) and `littered` (slowed now: streamed, for the mark).
##
## THIS NODE (Game.cog_layer, made the first time it is needed: layer()) draws it all, in code, from the gear art
## (GearArt's idler cog, baked small) and lines (docs/art_style_inconsistency.md): the pieces in flight from the hopper
## and, on the ground (this node, z -15: over the area marks, under every unit), the litter lying at the 3/4 angle with a
## glint now and then, fading over its last FADE s; its child `over` (z 3) draws the pieces in the air and a few cogs
## caught round the feet of every slowed unit. It is looks only: show_throw() is called on the host by throw() and on an online
## guest or a replay by NetSession.play_fx (the effect row "k": NetSession.note_scatter); a field's pieces come from a
## random generator seeded by the spot, so every screen shows the same litter. Nothing here uses the game's own random
## numbers.

const S := Defs.COG_SCATTER
const KIND := Defs.GREAT_WINDER_KIND
const SPELL := "scatter"
const FADE := 1.5                # s: the litter fades over its last 1.5 s
const BOUNCE := 0.14             # s: a piece's little hop where it lands
## The hopper's mouth over the machine's feet (game px) by the way it faces; the west views mirror the east (Unit.DIR_FLIP).
## Measured on assets/units/great_winder/idle_<dir>.png (anchor 91, 89).
const MOUTH := {"s": Vector2(-14, -52), "se": Vector2(-18, -54), "e": Vector2(-19, -53), "ne": Vector2(-14, -58), "n": Vector2(10, -60)}
const STEEL := Color(0.56, 0.58, 0.62)
const STEEL_D := Color(0.22, 0.22, 0.26)
const BRASS := Color(0.86, 0.66, 0.3)
const BRASS_D := Color(0.42, 0.28, 0.1)
const COPPER := Color(0.78, 0.42, 0.24)

var game: Game = null
## Each field (looks only): {from, to, team, r, t0 (the clock it was thrown), flight, end (the clock it is gone),
## pieces: [{at (from `to`), kind, rot, size, delay, peak, spin, glint}], dust (the clock the first pieces land)}
var fields: Array = []
var marked := {}                 # Unit -> true: slowed units, with cogs caught round their feet
var over: Node2D = null
var _seen_t := 0.0

static var _cog_tex := {}        # size px -> the idler cog, baked small (null: headless / no art: drawn as a polygon)


# ------------------------------------------------------------------ the rules

## "" when unit u can throw now (the spot aside: it rolls closer by itself), else why not (Game.spell_problem).
static func problem(u: Unit) -> String:
	if u == null or u.dead or u.kind != KIND:
		return "Only a Great Winder can SCATTER COGS."
	var g := u.game
	var left := u.scatter_ready - float(g.clock)
	if left > 0.01:
		return "The hopper is still filling: SCATTER COGS in %d s." % int(ceil(left))
	if int(g.players[u.team]["gold"]) < int(S["cost"]):
		return "Not enough cogs: SCATTER COGS needs %d." % int(S["cost"])
	return ""


## The hopper's mouth in world px (MOUTH for the way it faces).
static func mouth(u: Unit) -> Vector2:
	var dd: Array = Unit.DIR_FLIP[posmod(int(round(u.facing.angle() / (PI / 4.0))), 8)]
	var o: Vector2 = MOUTH[String(dd[0])]
	if bool(dd[1]):
		o.x = -o.x
	return u.position + o


## THE THROW (Game.cast_spell "scatter", when the cast's windup is over): the cogs are paid, the hopper is empty for
## `cooldown` s, the field goes into Game.zones (it slows from the landing: tick_zone), its edge on the ground for as long
## as it lasts (an area mark: the guest and the replay lay it by their fog), and the pieces fly (show_throw; the guest's and the
## replay's from the effect row).
static func throw(g: Game, u: Unit, p: Vector2) -> void:
	var cost := int(S["cost"])
	g.players[u.team]["gold"] -= cost
	g.stats[u.team]["spent"] += cost
	u.scatter_ready = float(g.clock) + float(S["cooldown"])
	u.set_meta("cs_thrown", int(u.get_meta("cs_thrown", 0)) + 1)
	var fl := float(S["flight"])
	var life := float(S["time"])
	var r := float(S["radius"])
	var from := mouth(u)
	if p != u.position:
		u.facing = (p - u.position).normalized()
	g.zones.append({"kind": SPELL, "pos": p, "team": u.team, "age": 0.0, "t": fl + life, "r": r, "land": fl,
		"fx": null, "stage": "", "caster": u})
	g.area_mark("oval", u.team, p, Vector2.ZERO, r, 0.0, "cogs", fl + life, false, true)
	show_throw(g, from, p, u.team, r, fl, life)
	if g.net != null and not g.puppet:
		g.net.note_scatter(from, p, u.team, r, fl, life)       # (online host: the guest sees it fly and lie)
	if g.rec != null and not g.puppet:
		g.rec.note_scatter(from, p, u.team, r, fl, life)
	if u.visible and g.view_rect.has_point(u.position):
		Sfx.play_any(["combat/netter_attack", "combat/springer_jump", "ratchet"], u.position, -3.0)
	if g.mlog:
		var inside := 0
		for o in g.units_near(p, r + 20.0):
			if not o.dead and g.hostile(o.team, u.team) and g.in_ellipse(p, o.position, r):
				inside += 1
		g.mlog.add("%s's Great Winder scattered cogs (%d enemies inside)" % [g.mlog.who(u.team), inside])


## Can the field of side `team` slow unit o? On the ground (or `air`), on the field, an enemy (or anyone: `slows_own`).
static func slows(g: Game, team: int, o: Unit) -> bool:
	if o.dead or o.off_field or o.aboard != null:
		return false
	if o.is_air() and not bool(S["air"]):
		return false
	return bool(S["slows_own"]) or g.hostile(o.team, team)


## A field's tick (Game._tick_zones): nothing while the pieces are in the air; then every unit it slows with its feet in
## the litter is slowed for `linger` s more (topped up each tick: it walks out and is free a moment later).
static func tick_zone(g: Game, z: Dictionary, _delta: float) -> void:
	if float(z["age"]) < float(z["land"]):
		return
	if not z.has("landed"):
		z["landed"] = true
		if g.view_rect.has_point(z["pos"]) and g.mark_seen(int(z["team"]), z["pos"]):
			Sfx.play_any(["combat/netter_hit", "combat/clock_death", "gear_hit"], z["pos"], -4.0)
	var p: Vector2 = z["pos"]
	var r: float = z["r"]
	var team := int(z["team"])
	var linger := float(S["linger"])
	for o in g.units_near(p, r + 24.0):
		if not slows(g, team, o) or not g.in_ellipse(p, o.position, r):
			continue
		if o.litter_t <= 0.0:
			mark(g, o)
		o.litter_t = maxf(o.litter_t, linger)


## Slowed: the speed multiplier for unit u now (Unit._tick_unit: 1.0 when not).
static func speed_mul(u: Unit) -> float:
	return float(S["slow"]) if u.litter_t > 0.0 else 1.0


# ------------------------------------------------------------------ the card

## Its command card button (GreatWinder.card): SCATTER COGS, a spot; the corner shows the price, or the hopper's
## countdown when none of the selected can throw yet.
static func card(hud, list: Array, gws: Array) -> void:
	var game: Game = hud.game
	var ready: Array = gws.filter(func(o: Unit) -> bool: return o.scatter_ready <= float(game.clock) + 0.01)
	var cdl := INF
	for o in gws:
		cdl = minf(cdl, o.scatter_ready - float(game.clock))
	var why := ""
	if ready.is_empty():
		why = problem(gws[0])
		for o in gws:
			if o.scatter_ready - float(game.clock) <= cdl + 0.001:
				why = problem(o)
	elif int(game.players[game.human]["gold"]) < int(S["cost"]):
		why = problem(ready[0])
	hud._tip_for["SCATTER COGS"] = ["Scatter cogs", "Tap a spot within %d tiles (it rolls closer if it must): the key arm winds, then the hopper flings cogs, bolts and springs that litter a circle of %.1f tiles for %d s. Enemies on the ground in the litter move %d%% slower (their attacks are not slowed); flyers and your own units are not slowed. The hopper refills in %d s." % [
		int(round(float(S["range"]) / Defs.TILE)), float(S["radius"]) / Defs.TILE, int(S["time"]),
		int(round((1.0 - float(S["slow"])) * 100.0)), int(S["cooldown"])], "%d cogs  ·  %d s" % [int(S["cost"]), int(S["cooldown"])]]
	var badge := str(int(S["cost"]))
	if ready.is_empty() and cdl > 0.0 and cdl < INF:
		badge = "%ds" % int(ceil(cdl))
	list.append(["ab_scatter", "SCATTER COGS", func() -> void:
		hud.controls.mode = "cast"
		hud.controls.cast_spell = SPELL, why == "", why, badge])


# ------------------------------------------------------------------ the computer

## The Clockwork computer (AI._abilities): a Great Winder that can throw does, on a clump of at least `ai_min` enemy ground
## units it can see within its throw (where they will be when the pieces land): CHARGING (melee units coming at our army,
## our Great Winder or our base) or RUNNING AWAY (moving off from our army while our army is close). Melee counts 1.5, the
## others 1; units already slowed count half. Kept small and in its own function (another job edits the Clockwork AI).
static func ai_tick(g: Game, team: int) -> void:
	var gws: Array = g.units.filter(func(o: Unit) -> bool: return o.team == team and not o.dead and o.kind == KIND \
			and o.order != "cast" and o.net_t <= 0.0 and problem(o) == "")
	if gws.is_empty() or int(g.players[team]["gold"]) < int(S["cost"]) + 20:
		return
	var army: Array = g.army(team).filter(func(o: Unit) -> bool: return o.kind != KIND)
	var c := Vector2.ZERO
	for o in army:
		c += o.position
	if not army.is_empty():
		c /= army.size()
	var hall: Building = g._own_hall(team)
	var lead := float(S["cast"]) + float(S["flight"]) + 0.2
	var r := float(S["radius"])
	for u in gws:
		var reach := float(S["range"])
		var best := Vector2.INF
		var bs := float(S["ai_min"]) - 0.01
		for e in g.units_near(u.position, reach + r):
			if not slows(g, team, e) or e.is_worker() or not g.hostile(e.team, team) or e.velocity.length() < 20.0:
				continue
			if not g.side_sees(team, e.position):
				continue
			var at: Vector2 = e.position + e.velocity * lead
			if at.distance_to(u.position) > reach:
				continue
			var s := 0.0
			for o in g.units_near(at, r + 40.0):
				if not slows(g, team, o) or o.is_worker() or not g.in_ellipse(at, o.position + o.velocity * lead, r):
					continue
				if not g.hostile(o.team, team):
					s -= 1.0               # (slows_own: our own men in there)
					continue
				var v: Vector2 = o.velocity
				if v.length() < 20.0:
					continue
				var melee: bool = o.has_attack() and float(o.d["range"]) < 60.0
				var coming := false
				for t in [u.position, c if not army.is_empty() else u.position, hall.center() if hall else u.position]:
					if v.normalized().dot(((t as Vector2) - o.position).normalized()) > 0.5 and o.position.distance_to(t) < 700.0:
						coming = true
				var going := not army.is_empty() and c.distance_to(o.position) < 360.0 and v.normalized().dot((o.position - c).normalized()) > 0.5
				if not (coming and melee) and not going:
					continue
				var w := 1.5 if melee else 1.0
				s += w * (0.5 if o.litter_t > 0.0 else 1.0)
			if s > bs:
				bs = s
				best = at
		if best != Vector2.INF:
			u.cmd_cast(SPELL, best)
			if g.mlog and not g._first_of.has("%d:ai_cog_scatter" % team):
				g._first_of["%d:ai_cog_scatter" % team] = true
				g.mlog.add("%s's Great Winder throws SCATTER COGS (%.1f enemies in the litter)" % [g.mlog.who(team), bs])
			return               # (one throw a think: the field is down; the next one looks again)


# ------------------------------------------------------------------ the looks

## The layer (made the first time: Game.cog_layer).
static func layer(g: Game) -> CogScatter:
	if g.cog_layer == null or not is_instance_valid(g.cog_layer):
		var l := CogScatter.new()
		l.game = g
		g.cog_layer = l
		g.add_child(l)
	return g.cog_layer


## A slowed unit gets its cogs (Unit.litter_t began; on a guest: its `littered` came on).
static func mark(g: Game, u: Unit) -> void:
	var l := layer(g)
	l.marked[u] = true
	l.set_process(true)


## A throw seen: the pieces fly from the hopper `from` to the spot `to`, land after `flight` s and lie there for `life` s.
static func show_throw(g: Game, from: Vector2, to: Vector2, team: int, r: float, flight: float, life: float) -> void:
	var l := layer(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(int(to.x), int(to.y), team))
	var pieces: Array = []
	var kinds := ["cog", "cog", "cog_s", "cog_s", "bolt", "bolt", "spring", "nut", "plate"]
	var n := int(S["parts"])
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r * 0.94
		var at := Vector2(cos(a) * d, sin(a) * d * Game.FIELD_Y)
		var k: String = kinds[rng.randi() % kinds.size()]
		var dist := from.distance_to(to + at)
		pieces.append({"at": at, "kind": k, "rot": rng.randf() * TAU, "size": rng.randf_range(0.8, 1.2),
			"delay": rng.randf() * 0.22 + float(i) * 0.005, "peak": 26.0 + dist * 0.32 + rng.randf() * 10.0,
			"spin": rng.randf_range(6.0, 14.0) * (1.0 if rng.randf() < 0.5 else -1.0),
			"glint": rng.randf() * TAU if rng.randf() < 0.45 else -1.0, "tint": rng.randf()})
	# a few dark scuffs under the litter: oil and grit where it hit the ground
	var scuffs: Array = []
	for i in 7:
		var a2 := rng.randf() * TAU
		var d2 := sqrt(rng.randf()) * r * 0.7
		scuffs.append([Vector2(cos(a2) * d2, sin(a2) * d2 * Game.FIELD_Y), rng.randf_range(10.0, 20.0)])
	var t0 := float(g.clock)
	l.fields.append({"from": from, "to": to, "team": team, "r": r, "t0": t0, "flight": flight, "end": t0 + flight + life,
		"pieces": pieces, "scuffs": scuffs, "seen": true})
	l.set_process(true)
	l.queue_redraw()


func _ready() -> void:
	z_index = -15                # on the ground: over the area marks (-16), under every unit and building
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	over = Node2D.new()
	over.z_as_relative = false
	over.z_index = 3             # the pieces in the air and the cogs round slowed feet: over the units
	over.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	over.draw.connect(_draw_over)
	add_child(over)


func _process(delta: float) -> void:
	var clk := float(game.clock)
	for f in fields.duplicate():
		if clk >= float(f["end"]):
			fields.erase(f)
	for u in marked.keys():
		if not is_instance_valid(u) or u.dead or not (u.littered or u.litter_t > 0.0):
			marked.erase(u)
	_seen_t -= delta
	if _seen_t <= 0.0:
		_seen_t = 0.25
		for f in fields:
			f["seen"] = game.mark_seen(int(f["team"]), f["to"])
	queue_redraw()
	over.queue_redraw()
	if fields.is_empty() and marked.is_empty():
		set_process(false)


## The litter on the ground.
func _draw() -> void:
	var clk := float(game.clock)
	var vr: Rect2 = game.view_rect.grow(120.0)
	for f in fields:
		if not bool(f["seen"]) or (game.view_rect.size != Vector2.ZERO and not vr.has_point(f["to"])):
			continue
		var t := clk - float(f["t0"])
		var fl := float(f["flight"])
		var fade := clampf((float(f["end"]) - clk) / FADE, 0.0, 1.0)
		var to: Vector2 = f["to"]
		# the scuffs come in with the first pieces down
		var sa := clampf((t - fl * 0.8) / 0.3, 0.0, 1.0) * fade
		if sa > 0.0:
			for sc in f["scuffs"]:
				draw_set_transform(to + (sc[0] as Vector2), 0.0, Vector2(1.0, Game.FIELD_Y * 0.7))
				draw_circle(Vector2.ZERO, float(sc[1]), Color(0.16, 0.12, 0.08, 0.16 * sa))
			draw_set_transform(Vector2.ZERO)
		for pc in f["pieces"]:
			var land := fl + float(pc["delay"])
			if t < land:
				continue
			var at: Vector2 = to + (pc["at"] as Vector2)
			var since := t - land
			var hop := 0.0
			if since < BOUNCE:
				var bf := since / BOUNCE
				hop = 3.0 * 4.0 * bf * (1.0 - bf)
			_piece(self, at - Vector2(0, hop), pc, float(pc["rot"]), true, fade)
			# a glint now and then on the bright pieces
			var gp := float(pc["glint"])
			if gp >= 0.0 and fade > 0.3:
				var gl := pow(maxf(0.0, sin(clk * 1.3 + gp * 3.0)), 30.0)
				if gl > 0.05:
					var q := at + Vector2(-1.5, -1.5)
					var gc := Color(1.0, 0.97, 0.85, gl * fade)
					draw_line(q - Vector2(3.5, 0), q + Vector2(3.5, 0), gc, 1.0, true)
					draw_line(q - Vector2(0, 3.5), q + Vector2(0, 3.5), gc, 1.0, true)
					draw_circle(q, 1.1, gc)
		# the dust where the first pieces hit
		var dt := t - fl
		if dt > 0.0 and dt < 0.45:
			var da := 1.0 - dt / 0.45
			for i in 5:
				var pc2: Dictionary = f["pieces"][i * 5 % (f["pieces"] as Array).size()]
				var q2: Vector2 = to + (pc2["at"] as Vector2)
				draw_set_transform(q2, 0.0, Vector2(1.0, 0.45))
				draw_arc(Vector2.ZERO, 4.0 + dt * 22.0, 0.0, TAU, 16, Color(0.72, 0.64, 0.52, 0.5 * da), 2.0, true)
			draw_set_transform(Vector2.ZERO)


## The pieces in the air, and the cogs caught round slowed feet.
func _draw_over() -> void:
	var clk := float(game.clock)
	var vr: Rect2 = game.view_rect.grow(160.0)
	for f in fields:
		var t := clk - float(f["t0"])
		var fl := float(f["flight"])
		if t > fl + 0.3 or not (bool(f["seen"]) or game.mark_seen(int(f["team"]), f["from"])):
			continue
		if game.view_rect.size != Vector2.ZERO and not vr.has_point(f["to"]) and not vr.has_point(f["from"]):
			continue
		var from: Vector2 = f["from"]
		var to: Vector2 = f["to"]
		for pc in f["pieces"]:
			var tt := t - float(pc["delay"]) * 0.5
			if tt < 0.0 or tt >= fl + float(pc["delay"]) * 0.5:
				continue
			var span := fl + float(pc["delay"]) * 0.5
			var u := clampf(tt / span, 0.0, 1.0)
			var end: Vector2 = to + (pc["at"] as Vector2)
			var q := from.lerp(end, u) - Vector2(0.0, float(pc["peak"]) * 4.0 * u * (1.0 - u))
			_piece(over, q, pc, float(pc["rot"]) + float(pc["spin"]) * tt, false, 1.0)
	for o in marked:
		if not is_instance_valid(o) or not o.visible or o.off_field or o.modulate.a < 0.05:
			continue
		if game.view_rect.size != Vector2.ZERO and not vr.has_point(o.position):
			continue
		var rx := clampf(float(o.radius) * 0.95 + 3.0, 9.0, 20.0)
		var ph := float(o.get_instance_id() % 628) * 0.01
		for i in 3:
			var an := ph + TAU * float(i) / 3.0 + sin(clk * 2.0 + ph) * 0.25
			var q: Vector2 = o.position + Vector2(cos(an) * rx, sin(an) * rx * 0.4 - 1.0)
			_cog(over, q, 3.4 + 0.5 * float(i % 2), clk * (1.5 if i % 2 == 0 else -1.5) + ph, true, 0.95, BRASS if i != 1 else STEEL)


## One piece: a cog (the idler cog of the gear art, baked small), a bolt, a spring, a nut or a brass plate; `flat`: lying
## on the ground (squashed to the 3/4 angle), else tumbling in the air.
static func _piece(ci: CanvasItem, at: Vector2, pc: Dictionary, rot: float, flat: bool, a: float) -> void:
	var s := float(pc["size"])
	var k := String(pc["kind"])
	var tint := float(pc.get("tint", 0.5))
	if flat:
		# its shadow on the ground (it reads on grass and sand alike)
		ci.draw_set_transform(at + Vector2(1.0, 1.6), 0.0, Vector2(1.0, 0.5))
		ci.draw_circle(Vector2.ZERO, (6.0 if k == "cog" or k == "spring" or k == "bolt" else 4.5) * s, Color(0.05, 0.04, 0.02, 0.4 * a))
		ci.draw_set_transform(Vector2.ZERO)
	match k:
		"cog":
			_cog(ci, at, 6.4 * s, rot, flat, a, BRASS if tint < 0.6 else COPPER)
		"cog_s":
			_cog(ci, at, 4.4 * s, rot, flat, a, STEEL if tint < 0.5 else BRASS)
		"nut":
			_nut(ci, at, 3.0 * s, rot, flat, a)
		"bolt":
			_bolt(ci, at, 8.5 * s, rot, flat, a)
		"spring":
			_spring(ci, at, 9.5 * s, rot, flat, a)
		_:
			_plate(ci, at, 4.6 * s, rot, flat, a)


## The gear art's idler cog (GearArt.ring "idler", 8 teeth: the same teeth and boss as the field's free cogs), baked
## down to `px` square once; null without the art (headless).
static func cog_tex(px: int) -> Texture2D:
	if _cog_tex.has(px):
		return _cog_tex[px]
	var t: Texture2D = null
	var rg: Array = GearArt.ring("idler", 8)
	if not rg.is_empty() and rg[0] is Texture2D:
		var img: Image = (rg[0] as Texture2D).get_image()
		if img != null and not img.is_empty():
			img = img.duplicate() as Image
			if img.is_compressed():
				img.decompress()
			img.resize(px, px, Image.INTERPOLATE_LANCZOS)
			t = ImageTexture.create_from_image(img)
	_cog_tex[px] = t
	return t


static func _xf(ci: CanvasItem, at: Vector2, rot: float, flat: bool, sc := 1.0) -> void:
	if flat:
		ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(1.0, 0.55), 0.0, at) * Transform2D(rot, Vector2(sc, sc), 0.0, Vector2.ZERO))
	else:
		# tumbling: squashed along a turning axis
		ci.draw_set_transform_matrix(Transform2D(rot, Vector2(sc, sc * (0.45 + 0.55 * absf(cos(rot * 0.7)))), 0.0, at))


static func _cog(ci: CanvasItem, at: Vector2, r: float, rot: float, flat: bool, a: float, col: Color) -> void:
	var tex := cog_tex(24)
	if tex != null:
		# (the art's ring is brass; a steel one is greyed by the colour)
		var m := Color(1, 1, 1, a) if col == BRASS else (Color(0.82, 0.86, 0.95, a) if col == STEEL else Color(1.0, 0.8, 0.7, a))
		_xf(ci, at, rot, flat, r / 12.0)
		ci.draw_texture_rect(tex, Rect2(-12.0, -12.0, 24.0, 24.0), false, m)
		ci.draw_set_transform(Vector2.ZERO)
		return
	_xf(ci, at, rot, flat)
	var pts := PackedVector2Array()
	for i in 16:
		var an := TAU * float(i) / 16.0
		var rr := r if (i % 2) == 0 else r * 0.74
		pts.append(Vector2(cos(an), sin(an)) * rr)
	var dk := col.darkened(0.55)
	dk.a = a
	var c := col
	c.a = a
	ci.draw_colored_polygon(pts, c)
	pts.append(pts[0])
	ci.draw_polyline(pts, dk, 1.0, true)
	ci.draw_circle(Vector2.ZERO, r * 0.3, dk)
	ci.draw_set_transform(Vector2.ZERO)


static func _nut(ci: CanvasItem, at: Vector2, r: float, rot: float, flat: bool, a: float) -> void:
	_xf(ci, at, rot, flat)
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(Vector2.from_angle(TAU * float(i) / 6.0) * r)
	ci.draw_colored_polygon(pts, Color(STEEL.r, STEEL.g, STEEL.b, a))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(STEEL_D.r, STEEL_D.g, STEEL_D.b, a), 1.0, true)
	ci.draw_circle(Vector2.ZERO, r * 0.42, Color(STEEL_D.r, STEEL_D.g, STEEL_D.b, a))
	ci.draw_set_transform(Vector2.ZERO)


static func _bolt(ci: CanvasItem, at: Vector2, l: float, rot: float, flat: bool, a: float) -> void:
	_xf(ci, at, rot, flat)
	var dk := Color(STEEL_D.r, STEEL_D.g, STEEL_D.b, a)
	ci.draw_line(Vector2(-l * 0.5, 0), Vector2(l * 0.5, 0), dk, 2.6, true)
	ci.draw_line(Vector2(-l * 0.5, 0), Vector2(l * 0.5, 0), Color(STEEL.r, STEEL.g, STEEL.b, a), 1.4, true)
	for i in 3:
		var x := -l * 0.1 + float(i) * l * 0.18
		ci.draw_line(Vector2(x, -0.9), Vector2(x + 0.8, 0.9), dk, 0.8, true)      # (the thread)
	var hpts := PackedVector2Array()
	for i in 6:
		hpts.append(Vector2(-l * 0.5, 0) + Vector2.from_angle(TAU * float(i) / 6.0) * 2.2)
	ci.draw_colored_polygon(hpts, Color(0.66, 0.68, 0.72, a))
	hpts.append(hpts[0])
	ci.draw_polyline(hpts, dk, 0.9, true)
	ci.draw_set_transform(Vector2.ZERO)


static func _spring(ci: CanvasItem, at: Vector2, l: float, rot: float, flat: bool, a: float) -> void:
	_xf(ci, at, rot, flat)
	var pts := PackedVector2Array()
	var turns := 9
	for i in turns + 1:
		var x := -l * 0.5 + l * float(i) / float(turns)
		pts.append(Vector2(x, 1.8 if i % 2 == 0 else -1.8))
	ci.draw_polyline(pts, Color(0.12, 0.1, 0.08, a), 2.2, true)
	ci.draw_polyline(pts, Color(0.8, 0.74, 0.6, a), 1.0, true)
	ci.draw_set_transform(Vector2.ZERO)


static func _plate(ci: CanvasItem, at: Vector2, r: float, rot: float, flat: bool, a: float) -> void:
	_xf(ci, at, rot, flat)
	var pts := PackedVector2Array([Vector2(-r, -r * 0.6), Vector2(r * 0.9, -r * 0.8), Vector2(r, r * 0.5), Vector2(-r * 0.7, r * 0.7)])
	ci.draw_colored_polygon(pts, Color(BRASS.r * 0.9, BRASS.g * 0.9, BRASS.b * 0.9, a))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(BRASS_D.r, BRASS_D.g, BRASS_D.b, a), 1.0, true)
	ci.draw_circle(Vector2(-r * 0.4, -r * 0.1), 0.9, Color(BRASS_D.r, BRASS_D.g, BRASS_D.b, a))
	ci.draw_set_transform(Vector2.ZERO)
