extends SceneTree
## Plays mission 1's night (docs/campaign_m1_build.md) with a passive player (his men only fire back where they stand)
## and prints, every minute, what is left: barns, the manor, the Crown's men, the rebels in the field. A balance check:
## the night must hurt a player who does nothing, and not more than a player who fights can mend.
##   godot --headless --fixed-fps 30 --script res://tools/sim_campaign_m1.gd [-- until=<seconds>]
var main: Node
var until := 490.0
var active := false      # ("active": a simple player: his foot hunt the nearest torch-bearer, else the nearest rebel near
                         # the plantation; the Barracks trains Musketeers while there is gold)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "active":
			active = true
		if a.begins_with("until="):
			until = float(a.substr(6))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://running.txt"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main.start(Campaign.make_cfg("p01_leaf", "solo"))
	await process_frame
	await process_frame
	paused = false
	var g: Game = main.game
	var r: MissionRun = g.mission
	var next := 0.0
	var reb := r.team_index("rebels")
	var think := 0.0
	var seen := {}
	var gov := r.team_index("governor")
	while g.clock < until and not g.over:
		await physics_frame
		if active and g.clock >= think:
			think = g.clock + 1.5
			_play(g, r, gov, reb)
		var bl: Array = r.tags.get("barns", [])
		for k in bl.size():
			var gone: bool = not is_instance_valid(bl[k]) or bl[k].dead
			if gone and not seen.has(k):
				seen[k] = true
				print("SIM t=%4d barn %d burned (last hit by %s)" % [g.clock, k, bl[k].last_hit_by if is_instance_valid(bl[k]) else "?"])
		if g.clock >= next:
			next += 60.0
			var field := g.units.filter(func(u): return not u.dead and u.team == reb and not r.tagged("mass").has(u) and not r.tagged("camp1").has(u) and not r.tagged("camp2").has(u)).size()
			var crown := r.count({"side": "crown"})
			var mh: float = r.tagged("manor")[0].hp if not r.tagged("manor").is_empty() else 0.0
			print("SIM t=%4d barns=%d manor=%d crown=%d rebels_in_field=%d torches=%d" % [g.clock, r.tagged("barns").size(), mh, crown, field,
				g.units.filter(func(u): return not u.dead and u.has_meta("torch")).size()])
	print("SIM end t=%d over=%s winner=%s barns=%d dawn=%s" % [g.clock, g.over, r.winner_side, r.tagged("barns").size(), r.obj.get("dawn")])
	quit()


func _play(g: Game, r: MissionRun, gov: int, reb: int) -> void:
	var zone := r.area_rect("plantation").grow(6 * Defs.TILE)
	var foes: Array = g.units.filter(func(u): return not u.dead and u.team == reb and zone.has_point(u.position))
	var army: Array = g.units.filter(func(u): return not u.dead and u.team == gov and u.kind in ["musketeer", "dismounted"])
	if not foes.is_empty():
		for u in army:
			var best: Unit = null
			var bd := INF
			for f in foes:
				var dd: float = u.position.distance_to(f.position) * (0.4 if f.has_meta("torch") else 1.0)
				if dd < bd:
					bd = dd
					best = f
			if best and (u.target == null or not is_instance_valid(u.target) or u.target.dead or (best.has_meta("torch") and u.target != best)):
				u.cmd_attack(best)
	for b in g.buildings:
		if b.team == gov and not b.dead and b.kind == "barracks" and b.queue.size() < 2 and int(g.players[gov]["gold"]) >= 60:
			g.train(b, "musketeer")
