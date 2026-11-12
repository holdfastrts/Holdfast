extends "res://tools/qa_match.gd"
## FILM FOR A COACH (crown-v-crown-coach, docs/crown-v-crown-coach.md): tools/qa_match.gd's measured match, plus
##  - a MAP every 15 s (map_MMSS.png, 3 px a cell; works headless): ground (high ground lighter, cliffs dark, water blue),
##    each side's buildings in its colour (walls and gates darker, sites hollow), soldiers as bright dots, workers dim,
##    each army's centre as a ring, the clock and both armies' value in the corner;
##  - a line every 15 s in <out>/coach.txt: per side its plan, bank, labourers, army value and kinds, halls, attacking,
##    the army's centre (cells) and how far it is from its own main and from the enemy's;
##  - with shots:1 (run under xvfb with opengl3), camera pictures: each army every 30 s (army_<team>_MMSS.png), each hall
##    every 120 s (base_<team>_<n>_MMSS.png), and the fights (fight_MMSS.png: the most units of both sides together).
##   godot --headless --fixed-fps 30 --script res://tools/film_coach.gd -- map:greenhold seed:1 end:900 out:/abs/dir \
##       slots:crown/optimal/0,crown/optimal/1 [shots:1]
## A measuring tool: it changes no rule.
const CELL := 3
var _shots := false
var _next_map := 0.0
var _next_army := 30.0
var _next_base := 120.0
var _last_fight := -99.0
var _next_fcheck := 0.0
var _pending: Array = []
var _shooting := false
var _coach: Array = []
var _bg: Image = null
var _army_every := 30.0
var _focus0 := -1.0           # focus:MMSS-MMSS: in that window the armies every focus_every s (default 5)
var _focus1 := -1.0
var _focus_every := 5.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "shots:1":
			_shots = true
		elif a.begins_with("army_every:"):
			_army_every = float(a.split(":")[1])
		elif a.begins_with("focus_every:"):
			_focus_every = float(a.split(":")[1])
		elif a.begins_with("focus:"):
			var w := a.split(":")[1].split("-")
			_focus0 = int(w[0]) / 100 * 60 + int(w[0]) % 100
			_focus1 = int(w[1]) / 100 * 60 + int(w[1]) % 100
	super._initialize()
	RenderingServer.render_loop_enabled = false


func _process(delta: float) -> bool:
	if _shooting:
		return false
	if g != null and not _pending.is_empty():
		_shoot()
		return false
	var done: bool = super._process(delta)
	if g == null or done:
		if done and g != null:
			_write_coach()
		return done
	var c: float = g.clock
	_siege_dump(c)
	if c >= _next_map:
		_next_map += 15.0
		_map_png(c)
		_coach_line(c)
	if _shots:
		if c >= _next_army:
			_next_army += _focus_every if c >= _focus0 - 1.0 and c < _focus1 else _army_every
			for tm in n:
				var p = _army_centre(tm)
				if p != null:
					_pending.append(["army_%d_%s.png" % [tm, _mm(c)], p, 1.0])
		if c >= _next_base:
			_next_base += 120.0
			for tm in n:
				var k := 0
				for h in g.halls_of(tm):
					_pending.append(["base_%d_%d_%s.png" % [tm, k, _mm(c)], h.center() + Vector2(0, -30), 0.75])
					k += 1
		if c >= _next_fcheck:
			_next_fcheck = c + 2.0
			_fight(c)
	return false


## A new siege piece of a computer: the ground round it as text (siege_MMSS_t<team>.txt): '#' rock, '~' water, '^' high
## ground, '/' ramp, 'P' the piece, 'H' a hall, 'W' a wall or palisade, 'G' a gate, 'B' another building, 'a' an attacker,
## 'd' a defender soldier, 'w' a defender worker, 'T' the wave's target.
var _siege_seen := {}


func _siege_dump(c: float) -> void:
	for a in g.ais:
		var sg = a.get("_siege")
		if not (sg is Dictionary) or sg.is_empty() or not is_instance_valid(sg.get("piece")):
			continue
		var pc: Building = sg["piece"]
		if _siege_seen.get(a.team) == pc.get_instance_id():
			continue
		_siege_seen[a.team] = pc.get_instance_id()
		var c0: Vector2i = pc.cell - Vector2i(14, 14)
		var grid := {}
		for b in g.buildings:
			if b.dead:
				continue
			var ch := "B"
			if b == pc:
				ch = "P"
			elif b.kind == g.faction_hall(b.team):
				ch = "H"
			elif b.kind.contains("gate"):
				ch = "G"
			elif b.kind.contains("palisade") or b.kind.contains("wall"):
				ch = "W"
			for y in b.size.y:
				for x in b.size.x:
					grid[b.cell + Vector2i(x, y)] = ch if b.team != a.team else ch.to_lower()
		for u in g.units:
			if u.dead or u.off_field:
				continue
			var cc: Vector2i = g.cell_of(u.position)
			if u.team == a.team and not u.is_worker():
				grid[cc] = "a"
			elif u.team != a.team and u.team >= 0:
				grid[cc] = "w" if u.is_worker() else "d"
		var tg: Vector2i = g.cell_of(a._wave_target) if a._wave_target != Vector2.INF else Vector2i(-99, -99)
		var lines: Array = ["%s team %d siege on %s at %s, target %s" % [_mmss(c), a.team, pc.kind, str(pc.cell), str(tg)]]
		for y in range(c0.y, c0.y + 29):
			var row := ""
			for x in range(c0.x, c0.x + 29):
				var cc := Vector2i(x, y)
				if not g.in_map(cc):
					row += " "
					continue
				var i: int = g.idx(cc)
				if grid.has(cc):
					row += grid[cc]
				elif cc == tg:
					row += "T"
				elif g.water[i] != 0:
					row += "~"
				elif g.solid[i] == 1:
					row += "#"
				elif g.ramp[i] != 0:
					row += "/"
				elif g.height[i] != 0:
					row += "^"
				else:
					row += "."
			lines.append(row)
		var f := FileAccess.open(out.path_join("siege_%s_t%d.txt" % [_mm(c), a.team]), FileAccess.WRITE)
		for l in lines:
			f.store_line(l)
		f.close()


func _mm(c: float) -> String:
	return "%02d%02d" % [int(c) / 60, int(c) % 60]


## the centre of the side's biggest group of soldiers (within 400 px of the soldier with the most others near it)
func _army_centre(tm: int):
	var us := _army_units(tm)
	if us.is_empty():
		return null
	var best: Unit = null
	var bn := -1
	for u in us:
		var k := 0
		for o in us:
			if o.position.distance_squared_to(u.position) < 160000.0:
				k += 1
		if k > bn:
			bn = k
			best = u
	var s := Vector2.ZERO
	var m := 0
	for o in us:
		if o.position.distance_squared_to(best.position) < 160000.0:
			s += o.position
			m += 1
	return s / m


func _fight(c: float) -> void:
	if c - _last_fight < 20.0:
		return
	var all: Array = []
	for tm in n:
		all.append(_army_units(tm))
	var best := 0
	var at := Vector2.ZERO
	for u in all[0]:
		var mine := 0
		var theirs := 0
		for o in all[0]:
			if o.position.distance_squared_to(u.position) < 62500.0:
				mine += 1
		for o in all[1]:
			if o.position.distance_squared_to(u.position) < 90000.0:
				theirs += 1
		if mini(mine, theirs) > best:
			best = mini(mine, theirs)
			at = u.position
	if best >= 4:
		_last_fight = c
		_pending.append(["fight_%s.png" % _mm(c), at, 1.1])


func _shoot() -> void:
	_shooting = true
	var p: Array = _pending.pop_front()
	var cam: Camera2D = g.camera
	cam.position = p[1]
	cam.zoom = Vector2(p[2], p[2])
	cam.reset_smoothing()
	RenderingServer.render_loop_enabled = true
	for i in 20:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(p[0]))
	RenderingServer.render_loop_enabled = false
	_shooting = false


func _ground() -> Image:
	if _bg != null:
		return _bg
	_bg = Image.create(Game.W * CELL, Game.H * CELL, false, Image.FORMAT_RGB8)
	for y in Game.H:
		for x in Game.W:
			var i: int = y * Game.W + x
			var col := Color(0.30, 0.42, 0.25)
			if g.water[i] != 0:
				col = Color(0.20, 0.35, 0.65)
			elif g.solid[i] == 1:
				col = Color(0.16, 0.16, 0.14)
			elif g.height[i] != 0:
				col = Color(0.50, 0.58, 0.40)
			if g.ramp[i] != 0:
				col = Color(0.62, 0.55, 0.38)
			_bg.fill_rect(Rect2i(x * CELL, y * CELL, CELL, CELL), col)
	return _bg


func _map_png(c: float) -> void:
	var img: Image = _ground().duplicate()
	var cols := [Color(0.25, 0.55, 1.0), Color(1.0, 0.3, 0.25)]
	for b in g.buildings:
		if b.dead or b.team < 0 or b.team > 1:
			continue
		var col: Color = cols[b.team]
		if b.kind in ["palisade", "stone_wall", "gate", "wall"] or b.kind.contains("wall") or b.kind.contains("gate"):
			col = col.darkened(0.45)
		var r := Rect2i(b.cell.x * CELL, b.cell.y * CELL, b.size.x * CELL, b.size.y * CELL)
		if b.built:
			img.fill_rect(r, col)
		else:
			img.fill_rect(r, col.darkened(0.6))
		if b.kind == g.faction_hall(b.team):
			img.fill_rect(Rect2i(r.position + Vector2i(CELL, CELL), Vector2i(CELL, CELL)), Color.WHITE)
	for u in g.units:
		if u.dead or u.team < 0 or u.team > 1 or u.aboard != null:
			continue
		var cc: Vector2i = g.cell_of(u.position)
		var col: Color = cols[u.team]
		if u.is_worker():
			img.fill_rect(Rect2i(cc.x * CELL + 1, cc.y * CELL + 1, 2, 2), Color(0.9, 0.9, 1.0) if u.team == 0 else Color(1.0, 0.75, 0.75))
		else:
			img.fill_rect(Rect2i(cc.x * CELL, cc.y * CELL, CELL, CELL), col.lightened(0.55) if u.team == 0 else Color(1, 0.85, 0.2))
	for tm in n:
		var p = _army_centre(tm)
		if p != null:
			var cc: Vector2i = g.cell_of(p)
			for k in 24:
				var a := TAU * k / 24.0
				var q := Vector2i((Vector2(cc) * CELL + Vector2(cos(a), sin(a)) * 12).round())
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
					img.set_pixelv(q, Color.WHITE)
	img.save_png(out.path_join("map_%s.png" % _mm(c)))


func _coach_line(c: float) -> void:
	var parts: Array = []
	for tm in n:
		var a := _ai(tm)
		var kinds := {}
		for u in _army_units(tm):
			kinds[u.kind] = int(kinds.get(u.kind, 0)) + 1
		var p = _army_centre(tm)
		var home: Building = g._own_hall(tm)
		var foe: Building = g._own_hall(1 - tm)
		var cell := "-"
		var dh := -1
		var df := -1
		if p != null:
			cell = str(g.cell_of(p))
			if home:
				dh = int(p.distance_to(home.center()) / Game.T)
			if foe:
				df = int(p.distance_to(foe.center()) / Game.T)
		var jobs := {}
		for w in g.workers(tm):
			jobs[w.order] = int(jobs.get(w.order, 0)) + 1
		var wv := ""
		if a and a._attacking:
			var ws: Array = a._wave_set.keys().filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
			var wc := Vector2.ZERO
			for u in ws:
				wc += u.position
			if not ws.is_empty():
				wc /= ws.size()
				var spread := 0.0
				for u in ws:
					spread += u.position.distance_to(wc)
				var sg = a.get("_siege")
				wv = " WAVE %d at %s spread %d siege %s" % [ws.size(), str(g.cell_of(wc)), int(spread / ws.size() / Game.T),
					("%s %d%%" % [sg["piece"].kind, int(100 * sg["piece"].hp / sg["piece"].max_hp)]) if sg is Dictionary and not sg.is_empty() and is_instance_valid(sg.get("piece")) else "-"]
		parts.append("P%d %s bank %d/%d lab %d army %d %s halls %d att %s at %s (home %d, foe %d) jobs %s" % [tm + 1,
			a.strategy if a else "?", int(g.players[tm]["gold"]), int(g.players[tm].get("powder", 0)), g.workers(tm).size(),
			_army_value(tm), str(kinds), g.halls_of(tm).size(), (str(a._attacking) + wv) if a else "-", cell, dh, df, str(jobs)])
	_coach.append("%s | %s" % [_mmss(c), " | ".join(parts)])


func _write_coach() -> void:
	var f := FileAccess.open(out.path_join("coach.txt"), FileAccess.WRITE)
	for l in _coach:
		f.store_line(l)
	f.close()
