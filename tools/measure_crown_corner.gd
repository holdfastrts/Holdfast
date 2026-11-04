extends SceneTree
## THE NATURAL'S SPOT, A (by the ramp's foot, CrownSites v2) AGAINST B (the corner pocket, CrownSites._corner), measured on
## the bare map (crown-v-brood, docs/crown_v_brood.md section 5; the owner, 2026-11-04 15:23: "is it better or worse?"):
##   godot --headless --script res://tools/measure_crown_corner.gd [-- maps...]
## Player 1 (the first slot) is the Crown, player 2 the Brood. For each map and variant, the Crown's 2nd base and:
##   walls     the cells its wall must close (AIExpandWall.plan_for: the ways in at the best radius), and of them palisade /
##             gates / building slots; open sides (CrownSites.open_sides); mouth (CrownSites.mouth)
##   musk      a Musketeer's walk from the top of the main's ramp to the wall's gate (s), the ramp's foot to it (steps)
##   raptor    the Brood's Raptors' walk from their main to the nearest way in (s); "under" = the share of the last 20 tiles of
##             that walk within musket reach of the main's cliff edge (the line already standing there shoots them)
##   cover     the share of the wall's cells within musket reach of the main's cliff edge; the hall's own sides (cover_of)
## Writes a table (tab separated) to stdout and to the file after `out:` if given.
var main: Node
var g: Game
var rows: Array = []
var maps: Array = ["redrock_canyon", "thornwood_maze", "greenhold", "kestrel_rise", "red_coast", "ashford_crossing", "highmoor", "cinder_steps"]
var outf := ""


func _initialize() -> void:
	var a := Array(OS.get_cmdline_user_args())
	var m: Array = []
	for x in a:
		if String(x).begins_with("out:"):
			outf = String(x).substr(4)
		else:
			m.append(x)
	if not m.is_empty():
		maps = m
	_run.call_deferred()


func _run() -> void:
	rows.append("map\tvariant\tspot\tmain_d\twall_cells\tpalisade\tgates\tslots\topen\tmouth\tmusk_s\tfoot_steps\traptor_s\tunder\tcover_wall\tcover_hall\troom")
	for m in maps:
		for v in ["A", "B"]:
			await _one(m, v)
	for r in rows:
		print(r)
	if outf != "":
		var f := FileAccess.open(outf, FileAccess.WRITE)
		for r in rows:
			f.store_line(r)
		f.close()
	quit()


func _one(map: String, v: String) -> void:
	if main != null:
		main.queue_free()
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var cfg := {"map": map, "seed": 4242, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "economy"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "economy"}]}
	if v == "B":
		cfg["crown_nat"] = "corner"
	main.start(cfg)
	g = main.game
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	var ai: AICrown = null
	for a in g.ais:
		if a.team == 0:
			ai = a
	var t := 0
	var mainm := Vector2(g.starts[t]) + Vector2(2.5, 2.0)
	var picks: Array = CrownSites.pick(g, t, [mainm], 1)
	if picks.is_empty():
		rows.append("%s\t%s\tnone" % [map, v])
		return
	var c: Vector2i = picks[0]["c"]
	var size: Vector2i = MapGen.HALL
	var plan: Dictionary = ai.xw.plan_for(c)
	var ex: Array = plan.get("exposed", [])
	var nw := 0
	var ng := 0
	for e in plan.get("pieces", []):
		if e[0] == "wall":
			nw += 1
		else:
			ng += 1
	var slots := (plan.get("slots", []) as Array).size()
	# the walks: steps by land (4 ways), a tile a step
	var ramp := CrownSites.ramp_of(g, t)
	var gate := c + size / 2
	for e in plan.get("pieces", []):
		if e[0] == "gate":
			gate = e[1]
			break
	var top: Vector2i = Vector2i(ramp["top"]) if not ramp.is_empty() else g.starts[t]
	var from_top := CrownSites.steps_from(g, [top])
	var musk_steps: float = from_top[g.idx(gate)] if g.in_map(gate) else INF
	var foot_steps := ExpansionSpots._foot_d(g, CrownSites.steps_from(g, ramp["feet"]) if not ramp.is_empty() else from_top, c)
	var foe_d := CrownSites.steps_from(g, [g.starts[1] + Vector2i(2, 2)])
	var way := gate
	var best := INF
	for e in ex:
		var d: float = foe_d[g.idx(e)]
		if d < best:
			best = d
			way = e
	if ex.is_empty():
		best = foe_d[g.idx(c)]
	var field := CrownSites.edge_field(g, CrownSites.edge_cells(g, t))
	var f: PackedFloat32Array = field["f"]
	# the Raptors' last 20 tiles: walk back down the steps from the way in
	var under := 0
	var n := 0
	var p := way
	for k in 20:
		if not g.in_map(p):
			break
		n += 1
		if f[g.idx(p)] <= CrownSites.REACH:
			under += 1
		var nxt := p
		var nd: float = foe_d[g.idx(p)]
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + dd
			if g.in_map(q) and foe_d[g.idx(q)] < nd:
				nd = foe_d[g.idx(q)]
				nxt = q
		if nxt == p:
			break
		p = nxt
	var cov := 0
	for e in ex:
		if f[g.idx(e)] <= CrownSites.REACH:
			cov += 1
	var hall_cov := CrownSites.cover_of(g, field, c, size)
	var ms := float(Defs.UNITS["musketeer"]["speed"])
	var rs := float(Defs.UNITS["raptor"]["speed"])
	rows.append("%s\t%s\t%s\t%.1f\t%d\t%d\t%d\t%d\t%d\t%d\t%.0f\t%.0f\t%.0f\t%d%%\t%d%%\t%d%%\t%d%%" % [map, v, str(c), Vector2(c + size / 2).distance_to(mainm),
		ex.size(), nw, ng, slots, CrownSites.open_sides(g, c, size), CrownSites.mouth(g, c, size),
		musk_steps * Defs.TILE / ms if musk_steps < INF else -1.0, foot_steps, best * Defs.TILE / rs if best < INF else -1.0,
		int(100.0 * under / maxf(1.0, n)), int(100.0 * cov / maxf(1.0, ex.size())), int(100.0 * float(hall_cov["share"])), int(100.0 * float(picks[0]["room"]))])
