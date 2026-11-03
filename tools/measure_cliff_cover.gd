extends SceneTree
## HOW FAR IS THE CROWN'S NEW HALL FROM ITS OWN CLIFF EDGE? (the owner, 2026-11-03: "the optimal expansion positions will
## be as close as possible to each other because of walls and trying to use the high ground to our advantage")
##   godot --headless --fixed-fps 30 --script res://tools/measure_cliff_cover.gd -- map:thornwood_maze seed:1309500958 crown:1 [out:/abs/dir]
## Starts the map with the Crown in slot `crown` (0 or 1) against the Brood, both computers still, and measures:
##  - the main's CLIFF EDGE (CrownSites.edge_cells: the main's high-ground cells by a drop);
##  - the hall spot the computer picked before (AI._safe_hall_spot, AICrown.sites_on off) and picks now (CrownSites.pick);
##  - every LEGAL low-ground hall spot 18-34 tiles from the main (placement_problem as the computer asks it, its economy room
##    ExpansionSpots._room at least ROOM_MIN), with how close its nearest side comes to the edge and the share of its sides a
##    Musketeer on the edge reaches (CrownSites.REACH);
## prints a table and, with out:, writes <out>/<map>.json (the grid and the spots) for tools/draw_cliff_cover.py.
const ROOM_MIN := 0.35
var main: Node
var g: Game
var map := "thornwood_maze"
var seed_ := 1309500958
var crown := 1
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"crown": crown = int(kv[1])
			"out": out = kv[1]
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(seed_)
	var slots: Array = [{"who": "hard", "faction": "brood", "colour": 1, "side": 0, "strategy": "rush"},
		{"who": "hard", "faction": "crown", "colour": 0, "side": 1, "strategy": "balanced"}]
	if crown == 0:
		slots = [{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "rush"}]
	main.start({"map": map, "seed": seed_, "slots": slots})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	var ai = null
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
		if a.team == crown:
			ai = a
	await physics_frame
	var T := float(Defs.TILE)
	var hall_k := "town_hall"
	var size: Vector2i = Defs.BUILDINGS[hall_k]["size"]
	var home := (Vector2(g.starts[crown]) + Vector2(2.5, 2.0)) * T
	var main_mid := home / T
	var edge: Array = CrownSites.edge_cells(g, crown)
	var field: Dictionary = CrownSites.edge_field(g, edge)
	ai.sites_on = false
	var pick: Vector2i = ai._safe_hall_spot()
	ai.sites_on = true
	var newp: Vector2i = ai._safe_hall_spot()
	var marks: Array = CrownSites.pick(g, crown, [main_mid], 2)
	var h_lv := int(g.height[g.idx(g.starts[crown] + Vector2i(2, 2))])
	print("MAP %s seed %d: the Crown in slot %d, main at %s (level %d), %d edge cells" % [map, seed_, crown, str(g.starts[crown]), h_lv, edge.size()])
	_say_spot("the old pick", pick, field, size, main_mid)
	_say_spot("the new pick", newp, field, size, main_mid)
	for m in marks:
		print("  Crown mark #%d %s: score %.1f, %.1f tiles from the nearest hall, nearest side %.1f tiles from the edge, %d%% covered, room %.2f, ways %d" % [
			int(m["rank"]), str(m["c"]), float(m["score"]), float(m["gap"]), float(m["near"]) / T, int(100.0 * float(m["share"])), float(m["room"]), int(m["ways"])])
	var rows: Array = []
	for y in range(int(main_mid.y) - 36, int(main_mid.y) + 36):
		for x in range(int(main_mid.x) - 36, int(main_mid.x) + 36):
			var c := Vector2i(x, y)
			var mid := Vector2(c) + Vector2(size) * 0.5
			var d := mid.distance_to(main_mid)
			if d < Defs.HALL_SPACING or d > 34.0:
				continue
			if not g.in_map(c) or not g.in_map(c + size - Vector2i.ONE):
				continue
			if g.placement_problem(crown, hall_k, c, true) != "":
				continue
			if int(g.height[g.idx(c + Vector2i(2, 2))]) == h_lv:
				continue        # (on the main's own level: no cliff between)
			var room := ExpansionSpots._room(g, c)
			if room < ROOM_MIN:
				continue
			var cv: Dictionary = CrownSites.cover_of(g, field, c, size)
			rows.append({"c": c, "d": d, "near": cv["near"], "share": cv["share"], "room": room})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["share"]) > float(b["share"]) or (float(a["share"]) == float(b["share"]) and float(a["near"]) < float(b["near"])))
	var covered := rows.filter(func(r: Dictionary) -> bool: return float(r["near"]) <= CrownSites.REACH)
	print("  legal low-ground hall spots 18-34 tiles out (room >= %.2f): %d; with a side in musket reach of the edge: %d; >= 75%% of the sides covered: %d" % [
		ROOM_MIN, rows.size(), covered.size(), rows.filter(func(r: Dictionary) -> bool: return float(r["share"]) >= 0.75).size()])
	for r in rows.slice(0, 6):
		print("    %s  %.1f tiles from the main, nearest side %.1f tiles from the edge, %d%% covered, room %.2f" % [
			str(r["c"]), float(r["d"]), float(r["near"]) / T, int(100.0 * float(r["share"])), float(r["room"])])
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		var lo := Vector2i(int(main_mid.x) - 40, int(main_mid.y) - 40)
		var hi := Vector2i(int(main_mid.x) + 40, int(main_mid.y) + 40)
		var grid: Array = []
		for y in range(lo.y, hi.y):
			var row := ""
			for x in range(lo.x, hi.x):
				var c := Vector2i(x, y)
				if not g.in_map(c):
					row += " "
					continue
				var i := g.idx(c)
				var ch_ := "^" if int(g.height[i]) == 1 else "."
				if g.cliff[i] != 0:
					ch_ = "#"
				elif g.ramp[i] != 0:
					ch_ = "/"
				elif g.solid[i] != 0:
					ch_ = "t" if int(g.height[i]) == 0 else "T"
				row += ch_
			grid.append(row)
		var es: Array = []
		for e in edge:
			es.append([e.x, e.y])
		var f := FileAccess.open(out.path_join("%s.json" % map), FileAccess.WRITE)
		f.store_string(JSON.stringify({"map": map, "lo": [lo.x, lo.y], "grid": grid, "edge": es, "main": [g.starts[crown].x, g.starts[crown].y],
			"old": [pick.x, pick.y], "new": [newp.x, newp.y], "marks": marks.map(func(m): return [m["c"].x, m["c"].y]), "size": [size.x, size.y],
			"reach": CrownSites.REACH / T}))
		f.close()
	quit(0)


func _say_spot(what: String, c: Vector2i, field: Dictionary, size: Vector2i, main_mid: Vector2) -> void:
	if c.x < 0:
		print("  %s: none" % what)
		return
	var cv: Dictionary = CrownSites.cover_of(g, field, c, size)
	print("  %s %s: %.1f tiles from the main, nearest side %.1f tiles from the edge, %d%% of its sides in musket reach, room %.2f" % [what, str(c),
		(Vector2(c) + Vector2(size) * 0.5).distance_to(main_mid), float(cv["near"]) / Defs.TILE, int(100.0 * float(cv["share"])), ExpansionSpots._room(g, c)])
