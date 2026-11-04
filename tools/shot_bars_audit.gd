extends SceneTree
## THE BARS AUDIT (docs/bars_audit.md): every bar, label and indicator over a faction's buildings and rooted creatures,
## laid out side by side on clear ground, hurt (so the health bar shows), some training, one site going up, then filmed
## at three zooms. Also the Mainspring's coil gauge (empty / half / full / fatigued) and the Brood Mother at stages 1-3.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_bars_audit.gd -- <outdir> <crown|clockwork|brood|coil|mother> [prefix]
## Prints, for every entity, its sprite's visible top and the lowest and highest of its indicators (world y).
var main: Node
var g
var out := ""
var what := "crown"
var pre := ""
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	what = a[1] if a.size() > 1 else "crown"
	pre = a[2] if a.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _faction() -> String:
	match what:
		"crown":
			return "crown"
		"clockwork", "coil":
			return "clockwork"
	return Defs.BROOD_NEW


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "dune_sea", "seed": 5, "slots": [
			{"who": "you", "faction": _faction(), "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown" if _faction() != "crown" else "clockwork", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.6:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


## Clear level ground (cells) w x h nearest the map's middle.
func _clear_spot(w: int, h: int) -> Vector2i:
	var mid := Vector2i(Game.W / 2 - w / 2, Game.H / 2 - h / 2)
	var best := Vector2i(10, 10)
	var bd := INF
	for y in range(1, Game.H - h - 1, 2):
		for x in range(1, Game.W - w - 1, 2):
			var c := Vector2i(x, y)
			var dd := Vector2(c - mid).length()
			if dd >= bd:
				continue
			var ok := true
			for yy in h:
				for xx in w:
					var cc := c + Vector2i(xx, yy)
					if not g._walkable(cc) or not g.is_free(cc) or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != g.height[g.idx(c)]:
						ok = false
						break
				if not ok:
					break
			if ok:
				bd = dd
				best = c
	return best


func _snap(name: String, wait := 0.5) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [out, pre, name])


func _look(p: Vector2, z: float) -> void:
	g.camera.position = p
	g.camera.zoom = Vector2(z, z)
	await process_frame
	g.camera.reset_smoothing()
	g.update_view_rect()
	for b in g.buildings:
		b.queue_redraw()
	for u in g.units:
		u.queue_redraw()


func _clean() -> void:
	for b in g.buildings.duplicate():
		if b.team == g.human:
			g._mark(b.cell, b.size, 0)
			g.buildings.erase(b)
			b.queue_free()
	for u in g.units.duplicate():
		if u.team == g.human:
			g.consume_unit(u)


func _run() -> void:
	await create_timer(0.3).timeout
	g.reveal = true
	Settings.health_bars = 0
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	match what:
		"crown", "clockwork":
			await _buildings()
		"brood":
			await _brood()
		"coil":
			await _coil()
		"mother":
			await _mother()
	quit()


## Every building kind of the faction in rows, hurt, the trainers training, plus one site going up.
func _buildings() -> void:
	var f := _faction()
	var kinds: Array = Defs.build_list(f)
	_clean()
	var o := _clear_spot(64, 34)
	var x := 2
	var y := 4
	var rowh := 0
	var placed: Array = []
	for k in kinds + [kinds[1]]:
		var sz: Vector2i = Defs.BUILDINGS[k]["size"]
		if x + sz.x > 62:
			x = 2
			y += rowh + 5
			rowh = 0
		var site := placed.size() == kinds.size()
		var b: Building = g._add_building(k, g.human, o + Vector2i(x, y), not site)
		if site:
			b.progress = 0.4
		placed.append(b)
		x += sz.x + 4
		rowh = maxi(rowh, sz.y)
	await process_frame
	if g.gear_net:
		g.gear_net.solve()
	for b in placed:
		if b.built:
			b.hp = b.max_hp * 0.6
			var tr: Array = Defs.BUILDINGS[b.kind].get("trains", [])
			if not tr.is_empty() and Defs.UNITS.has(tr[0]):
				b.queue = [tr[0]]
				b.prod_t = Building.entry_time(tr[0]) * 0.45
		b.queue_redraw()
	await create_timer(1.0).timeout
	_report(placed, [])
	var mid := Vector2((o.x + 32) * Defs.TILE, (o.y + 17) * Defs.TILE)
	await _look(mid, 0.55)
	await _snap("all_z055")
	# close-ups, a few buildings at a time
	var i := 0
	for b in placed:
		await _look(b.global_position + Vector2(0, -50), 2.0)
		await _snap("z2_%02d_%s" % [i, b.kind], 0.25)
		i += 1
	await _look(placed[0].global_position + Vector2(160, -40), 1.0)
	await _snap("z1_a")
	await _look(placed[placed.size() / 2].global_position + Vector2(0, -40), 1.0)
	await _snap("z1_b")


## The Brood's rooting creatures (the Mother at stage 1, a Rootmaw, a Mound Turtle, the Sires on their nests), rooted
## and hurt, and a food pile.
func _brood() -> void:
	_clean()
	var o := _clear_spot(64, 24)
	var kinds: Array = [BroodNew.QUEEN, BroodNew.MAW, BroodNew.TURTLE, BroodNew.FATHER, BroodNew.DILO, BroodNew.PTERO]
	var us: Array = []
	var i := 0
	var xs := [6.0, 11.0, 24.0, 34.0, 44.0, 54.0]      # (the Rootmaw on the Mother's swamp)
	for k in kinds:
		var u: Unit = g._add_unit(k, g.human, Vector2((o.x + xs[i]) * Defs.TILE, (o.y + 14.0) * Defs.TILE))
		u.cmd_hold()
		us.append(u)
		i += 1
	await create_timer(0.3).timeout
	_root(us[0])
	g.swamp_dirty = true
	await create_timer(9.0).timeout          # (her swamp spreads: the Rootmaw roots on it)
	for u in us.slice(1):
		_root(u)
	await create_timer(8.0).timeout
	for u in us:
		u.hp = u.max_hp * 0.6
	await create_timer(0.5).timeout
	_report([], us)
	var mid := Vector2((o.x + 32) * Defs.TILE, (o.y + 12) * Defs.TILE)
	await _look(mid, 0.6)
	await _snap("all_z06")
	i = 0
	for u in us:
		await _look(u.position + Vector2(0, -60), 2.0)
		await _snap("z2_%02d_%s" % [i, u.kind], 0.3)
		await _look(u.position + Vector2(0, -60), 1.0)
		await _snap("z1_%02d_%s" % [i, u.kind], 0.3)
		i += 1


func _root(u: Unit) -> void:
	u.cmd_deploy()         # (rooting as in a match: it sinks in, then plays its rooted loop)
	if u.tesla_mode != "packed":
		return
	print("%s: rooted by hand" % u.kind)
	u.facing = BroodNew.SE
	u.position = BroodRoot.snap(u.kind, u.position, BroodRoot.scale_of(u))
	u.tesla_mode = "deployed"
	u.nb["m"] = "deployed"
	BroodRoot.footprint_on(g, u, false)
	if u.kind == BroodNew.MAW:
		BroodNew._claim(g, u)
		u.nb["food"] = 90.0
	BroodNew.recount(g, u.team)


## The Mother at her three stages, rooted, side by side.
func _mother() -> void:
	_clean()
	var o := _clear_spot(56, 18)
	var ms: Array = []
	for i in 3:
		var m: Unit = g._add_unit(BroodNew.QUEEN, g.human, Vector2((o.x + 8.0 + i * 19.0) * Defs.TILE, (o.y + 13.0) * Defs.TILE))
		m.cmd_hold()
		ms.append(m)
	await create_timer(0.3).timeout
	for m in ms:
		_root(m)
	await create_timer(8.0).timeout
	g.players[g.human]["gold"] = 99999
	g.players[g.human]["res2"] = 99999
	# (as in a match: she GROWS where she is rooted, stage by stage, and lays: her laying show rears her up)
	for step in 2:
		for i in range(step + 1, 3):
			var why: String = BroodNew.grow(g, ms[i])
			if why == "":
				ms[i].nb["grow_t"] = 0.3
			else:
				print("grow: ", why)
		await create_timer(2.0).timeout
	for m in ms:
		m.hp = m.max_hp * 0.7
	var lo := [0.0, 0.0, 0.0]
	for k in 2:
		for m in ms:
			m.nb["eggs"] = maxi(int(m.nb.get("eggs", 0)), 4)
			var why2: String = BroodNew.lay(g, m, "grub")
			if why2 != "":
				print("lay: ", why2)
		for f in 120:
			await process_frame
			for i in 3:
				lo[i] = minf(lo[i], ms[i].bar_top())
	await create_timer(2.0).timeout
	for i in 3:
		print("stage %d: bar top now %.0f, highest while laying %.0f" % [BroodNew.stage(ms[i]) + 1, ms[i].bar_top(), lo[i]])
	_report([], ms)
	await _look(Vector2((o.x + 27.0) * Defs.TILE, (o.y + 9.0) * Defs.TILE), 0.8)
	await _snap("mother_stages")
	for i in 3:
		await _look(ms[i].position + Vector2(0, -60 - 40 * i), 1.5)
		await _snap("mother_stage%d" % (i + 1), 0.3)


## A Mainspring by a Clocktower at four Tension levels: empty, half, full, and fatigued (its Clocktower's spring life spent).
func _coil() -> void:
	var tower: Building = null
	var spring: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == "clocktower":
			tower = b
	if tower == null:
		print("no Clocktower")
		return
	for deg in [0, 60, 120, 180, 240, 300]:
		var cs: Vector2i = GearNet.ring_spot(g, g.human, "mainspring", tower, float(deg), true)
		if cs.x >= 0:
			spring = g._add_building("mainspring", g.human, cs, true)
			break
	if spring == null:
		print("no Mainspring spot")
		return
	g.gear_net.solve()
	await create_timer(0.5).timeout
	var cap: float = GearEcon.tension_cap(g, g.human)
	print("tension cap %s" % cap)
	var hall: Building = g.soil_hall(spring)
	var life: float = hall.soil if hall else 0.0
	for st in [["empty", 0.0, false], ["half", 0.5, false], ["full", 1.0, false], ["fatigued", 0.3, true]]:
		g.players[g.human]["tension"] = cap * float(st[1])
		if hall:
			hall.soil = 0.0 if st[2] else life
		spring.queue_redraw()
		await create_timer(1.2).timeout
		await _look(spring.global_position + Vector2(0, -60), 2.0)
		await _snap("coil_" + String(st[0]), 0.6)
		await _look(spring.global_position + Vector2(0, -60), 1.0)
		await _snap("coil_z1_" + String(st[0]), 0.4)


## For each one: its sprite's visible top and its indicators' rects (world space).
func _report(bs: Array, us: Array) -> void:
	for b in bs:
		var top: float = b.global_position.y + b.bar_top()
		print("%-18s built=%s top %.0f  (pos.y %.0f)" % [b.kind, b.built, top, b.global_position.y])
	for u in us:
		print("%-18s top %.0f (pos.y %.0f) stage %d" % [u.kind, u.position.y + u.bar_top(), u.position.y, int(u.nb.get("stage", 0))])
