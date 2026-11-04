extends SceneTree
## THE CROWN'S HALL SPOTS, MEASURED (docs/expansion_spots.md "The Crown's rule"; the owner, 2026-11-04 07:05: "as close as
## possible, 18 tiles, as close as possible to the ramp ... and as close as possible to the edge of the map").
##   godot --headless --fixed-fps 30 --script res://tools/measure_crown_spots.gd -- [maps...] [out:/abs/dir] [tag:after]
##        [remeasure:before]
## Each map 2 players, both Crown, on the bare map. For player 0 (and its twin, player 1, as a check) prints the 2nd, 3rd
## and 4th base CrownSites.pick gives (one at a time, each pick counted as a hall, as the computer picks), the old
## base-site rating's natural (ExpansionSpots.rate_all #1), and for each: tiles to the main's hall, the walk from the main
## ramp's foot, tiles to the map's border, open sides (CrownSites.open_sides) and the side of the main's ramp it lies on.
## With out:, writes <out>/<map>_<tag>.json (the ground round the main and the spots) for tools/draw_crown_spots.py.
## remeasure:TAG takes the spots from <out>/<map>_TAG.json instead of picking (the old rule's spots, measured the same
## way) and writes <map>_TAG.json again.

var failed := 0


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _make(id: String) -> Game:
	var g := Game.new()
	g.map_id = id
	g.demo = true
	g.factions = ["crown", "crown"]
	g.sides = [0, 1]
	g.colours = [0, 1]
	root.add_child(g)
	return g


static func metrics(g: Game, t: int, c: Vector2i, foot_d: PackedFloat32Array, rp: Dictionary) -> Dictionary:
	var size: Vector2i = MapGen.HALL
	var mid := Vector2(c) + Vector2(size) * 0.5
	return {"c": c, "main": mid.distance_to(Vector2(g.starts[t]) + Vector2(2.5, 2.0)), "walk": ExpansionSpots._foot_d(g, foot_d, c),
		"edge": CrownSites.edge_d(c, size), "open": CrownSites.open_sides(g, c, size), "side": CrownSites.side_of(g, t, rp, mid),
		"room": ExpansionSpots._room(g, c)}


func _say(what: String, m: Dictionary) -> String:
	return "%-8s %-10s %5.1f tiles from the main, walk %3s from the ramp's foot, %2d tiles from the border, %d sides open, side %+d, room %.2f" % [
		what, str(m["c"]), float(m["main"]), str(int(m["walk"])) if float(m["walk"]) < INF else "-", int(m["edge"]), int(m["open"]),
		int(m["side"]), float(m["room"])]


func _run(args: Array) -> void:
	var ids: Array = []
	var out := ""
	var tag := "now"
	var re := ""
	for a in args:
		if String(a).begins_with("out:"):
			out = String(a).substr(4)
		elif String(a).begins_with("tag:"):
			tag = String(a).substr(4)
		elif String(a).begins_with("remeasure:"):
			re = String(a).substr(10)
			tag = re
		else:
			ids.append(a)
	if ids.is_empty():
		ids = ["thornwood_maze", "greenhold", "red_coast", "kestrel_rise", "ashford_crossing", "redrock_canyon", "highmoor", "cinder_steps"]
	for id in ids:
		if not MapGen.all_ids().has(id):
			print("no map ", id)
			continue
		var g := _make(id)
		await process_frame
		print("MAP %s (%d x %d)" % [id, Game.W, Game.H])
		var dump := {}
		for t in 2:
			var main_mid := Vector2(g.starts[t]) + Vector2(2.5, 2.0)
			var rp: Dictionary = CrownSites.ramp_of(g, t)
			var foot_d: PackedFloat32Array = CrownSites.steps_from(g, rp["feet"]) if not rp.is_empty() else ExpansionSpots._steps(g, g.starts[t])
			var cells: Array = []
			if re != "":
				if t == 1:
					break
				var d0: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("%s_%s.json" % [id, re])))
				for s in d0["spots"]:
					if String(s["what"]).begins_with("natural"):
						continue
					cells.append(Vector2i(int(s["c"][0]), int(s["c"][1])))
			else:
				var halls: Array = [main_mid]
				var t0 := Time.get_ticks_usec()
				for k in 3:
					var p: Array = CrownSites.pick(g, t, halls, 1)
					if p.is_empty():
						break
					cells.append(p[0]["c"])
					halls.append(Vector2(p[0]["c"]) + Vector2(MapGen.HALL) * 0.5)
				if t == 0:
					print("  (three picks in %d ms)" % ((Time.get_ticks_usec() - t0) / 1000))
					# as the computer asks: its own field and steps kept between calls
					var fld: Dictionary = CrownSites.edge_field(g, CrownSites.edge_cells(g, t))
					var stp: Array = [ExpansionSpots._steps(g, g.starts[t]), [ExpansionSpots._steps(g, g.starts[1 - t])]]
					var ms_: Array = []
					for rep in 3:
						var t1 := Time.get_ticks_usec()
						CrownSites.pick(g, t, [main_mid], 1, stp, {}, Callable(), fld)
						CrownSites.pick(g, t, [main_mid, halls[1]], 1, stp, {}, Callable(), fld)
						ms_.append((Time.get_ticks_usec() - t1) / 1000)
					print("  (the computer's 2nd + 3rd pick, the field kept: %s ms)" % str(ms_))
			var nat: Array = ExpansionSpots.rate_all(g).filter(func(s: Dictionary) -> bool: return int(s["team"]) == t and int(s["rank"]) > 0)
			nat.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rank"]) < int(b["rank"]))
			if t == 0:
				print("  P0 main %s, ramp foot %s" % [str(g.starts[t]), str(rp.get("foot", "-"))])
			var ms: Array = []
			for i in cells.size():
				var m := metrics(g, t, cells[i], foot_d, rp)
				m["what"] = ["2nd", "3rd", "4th"][i]
				ms.append(m)
				if t == 0:
					print("    ", _say(m["what"], m))
			for s in nat:
				var m := metrics(g, t, s["c"], foot_d, rp)
				m["what"] = "natural%d" % int(s["rank"])
				ms.append(m)
				if t == 0:
					print("    ", _say(m["what"], m))
			if t == 1:
				# twin check: player 1's picks are player 0's turned through the middle
				var p0: Array = dump["0"]["spots"]
				for i in cells.size():
					var tw: Vector2i = g._mirror(p0[i]["c"], MapGen.HALL)
					if tw != cells[i]:
						print("    TWIN MISMATCH: P0 %s %s, its twin %s, P1 has %s" % [p0[i]["what"], str(p0[i]["c"]), str(tw), str(cells[i])])
						failed += 1
			dump[str(t)] = {"spots": ms, "main": g.starts[t], "rp": rp}
		if out != "":
			_write(g, out, id, tag, dump["0"])
		g.queue_free()
		await process_frame
	print("measure crown spots: %s" % ("twins OK" if failed == 0 else "%d twin mismatches" % failed))
	quit(0)


func _write(g: Game, out: String, id: String, tag: String, d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var main: Vector2i = d["main"]
	var lo := Vector2i(maxi(0, main.x - 34), maxi(0, main.y - 34))
	var hi := Vector2i(mini(Game.W, main.x + 39), mini(Game.H, main.y + 38))
	var grid: Array = []
	for y in range(lo.y, hi.y):
		var row := ""
		for x in range(lo.x, hi.x):
			var i := g.idx(Vector2i(x, y))
			var ch := "^" if int(g.height[i]) >= 1 else "."
			if g.cliff[i] != 0:
				ch = "#"
			elif g.ramp[i] != 0:
				ch = "/"
			elif g.solid[i] != 0:
				ch = "t"
			row += ch
		grid.append(row)
	var spots: Array = []
	for m in d["spots"]:
		spots.append({"what": m["what"], "c": [m["c"].x, m["c"].y], "main": snappedf(float(m["main"]), 0.1),
			"walk": int(m["walk"]) if float(m["walk"]) < INF else -1, "edge": int(m["edge"]), "open": int(m["open"])})
	var rp: Dictionary = d["rp"]
	var f := FileAccess.open(out.path_join("%s_%s.json" % [id, tag]), FileAccess.WRITE)
	f.store_string(JSON.stringify({"map": id, "tag": tag, "lo": [lo.x, lo.y], "map_size": [Game.W, Game.H], "grid": grid,
		"main": [main.x, main.y], "foot": [int(rp["foot"].x), int(rp["foot"].y)] if not rp.is_empty() else null,
		"size": [MapGen.HALL.x, MapGen.HALL.y], "spots": spots}))
	f.close()
