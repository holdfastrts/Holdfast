extends SceneTree
## clockwork-eco: the Clockwork's expansion spots, old (the base-site rating, ExpansionSpots.rate_all) against new
## (ClockSites): how many of the Clocktower's ring buildings fit round each. Prints a line a map.
##   godot --headless --fixed-fps 30 --script res://tools/probe_clock_sites.gd [-- ids...]

func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(ids: Array) -> void:
	if ids.is_empty():
		ids = MapGen.all_ids()
	for id in ids:
		var g := Game.new()
		g.map_id = id
		g.demo = true
		g.factions = ["clockwork", "clockwork"]
		g.sides = [0, 1]
		g.colours = [0, 1]
		root.add_child(g)
		await process_frame
		var t0 := Time.get_ticks_msec()
		var old: Array = ExpansionSpots.rate_all(g).filter(func(s): return int(s["team"]) == 0 and int(s["rank"]) == 1)
		var neu: Array = ClockSites.pick(g, 0, [Vector2(g.starts[0]) + Vector2(2.5, 2.0)], 2)
		var ms := Time.get_ticks_msec() - t0
		var line := "%-18s " % id
		if not old.is_empty():
			var oc: Vector2i = old[0]["c"]
			var of: Array = ClockSites.ring_fit(g, oc, ClockSites._start(oc))
			line += "OLD %s ring %d outer %.2f | " % [str(oc), int(of[0]), ClockSites.outer_room(g, oc)]
		for s in neu:
			line += "NEW#%d %s ring %d outer %.2f walk %d gap %.1f | " % [int(s["rank"]), str(s["c"]), int(s["slots"]), float(s["outer"]), int(s["walk"]), float(s["gap"])]
		print(line + "%d ms" % ms)
		g.queue_free()
		await process_frame
	quit(0)
