extends SceneTree
## ONE RANK OR TWO (crown-line-fight, docs/crown_line_fight.md): a Crown line of N Musketeers laid with Game.line_orders in
## one rank or in two (the enemy force grows with N: the numbers below are for 14) (AICrownLine.lay's ROW_GAP), on HOLD, two Field Cannons set up behind it; an enemy force walks into
## it on an attack-move from 600 px. Per enemy kind and rank count: the value the line killed and lost by the end (60 s or
## one side gone). ranks 0 = the old blob (each man sent to the same point with a little scatter). A measuring tool: it
## changes no rule.
##   godot --headless --fixed-fps 30 --script res://tools/study_line_ranks.gd -- [n:14] [reps:3]
var main: Node
var g: Game


func _initialize() -> void:
	_run.call_deferred()


func _until(clock: float, cond := Callable()) -> void:
	while g.clock < clock and not g.over:
		await physics_frame
		if cond.is_valid() and cond.call():
			return


func _start(fb: String, sd: int) -> void:
	if main != null:
		main.queue_free()
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(sd)
	main.start({"map": "greenhold", "seed": sd, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": fb, "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED


func _spawn(kind: String, t: int, p: Vector2) -> Unit:
	var c: Vector2i = g.nearest_free(g.cell_of(g.on_map(p)), 6)
	return g._add_unit(kind, t, g.cell_center(c))


func _value(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += float(Game.unit_value(u))
	return v


func _dead(list: Array) -> float:
	var v := 0.0
	for e in list:
		if not is_instance_valid(e[0]) or e[0].dead:
			v += e[1]
	return v


func _run() -> void:
	var n := 14
	var reps := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n:"):
			n = int(a.split(":")[1])
		elif a.begins_with("reps:"):
			reps = int(a.split(":")[1])
	var foes := {"brood": ["raptor", 70], "clockwork": ["clock_soldier", 28], "crown": ["musketeer", 22]}
	var T := float(Defs.TILE)
	for fb in foes:
		for ranks in [0, 1, 2]:
			var k_sum := 0.0
			var l_sum := 0.0
			var won := 0
			for r in reps:
				await _start(fb, 7300 + r)
				await _until(1.0)
				var mid := Vector2(Game.W, Game.H) * T * 0.5
				var face := Vector2(1, 0)
				var perp := Vector2(0, 1)
				var mine: Array = []
				for i in n:
					mine.append(_spawn("musketeer", 0, mid - face * 200.0 + perp * (i - n * 0.5) * 20.0))
				if ranks == 0:
					# (the old way: a blob, every man sent to the same point with a little scatter, as AI._army's waves were)
					for u in mine:
						u.cmd_move(mid + Vector2(randf_range(-50, 50), randf_range(-50, 50)))
				var per: int = int(ceil(float(n) / maxi(1, ranks)))
				for rk in ranks:
					var row: Array = mine.slice(rk * per, mini((rk + 1) * per, n))
					var c: Vector2 = mid - face * (0.9 * T * rk)
					var half: float = row.size() * 0.95 * T * 0.5
					g.line_orders(row, PackedVector2Array([c - perp * half, c + perp * half]), false)
				var guns: Array = []
				for i in 2:
					guns.append(_spawn("cannon", 0, mid - face * (2.6 * T) + perp * (i - 0.5) * 1.7 * T))
				await _until(g.clock + 8.0)
				for u in mine:
					u.cmd_hold()
					u.facing = face
				for gu in guns:
					gu.cmd_deploy()
				await _until(g.clock + 4.0)
				var kind: String = foes[fb][0]
				var them: Array = []
				for i in int(foes[fb][1] * n / 14):
					var u := _spawn(kind, 1, mid + face * 600.0 + perp * (i % 6 - 2.5) * 28.0 + face * (i / 6) * 28.0)
					them.append(u)
				var mine_v: Array = (mine + guns).map(func(u) -> Array: return [u, float(Game.unit_value(u))])
				var them_v: Array = them.map(func(u) -> Array: return [u, float(Game.unit_value(u))])
				for u in them:
					u.cmd_move(mid - face * 400.0, true)
				var t0 := g.clock
				await _until(t0 + 60.0, func() -> bool:
					return mine.all(func(u) -> bool: return not is_instance_valid(u) or u.dead) or them.all(func(u) -> bool: return not is_instance_valid(u) or u.dead))
				var k := _dead(them_v)
				var l := _dead(mine_v)
				k_sum += k
				l_sum += l
				if k > l:
					won += 1
				print("   %s %d rank(s) rep %d: killed %d lost %d (%.0f s)" % [fb, ranks, r, int(k), int(l), g.clock - t0])
			print("RESULT %d muskets, %s vs %d %s: %d rank(s) (0 = blob): killed %d lost %d (ratio %.2f), won %d of %d" % [n, fb, int(foes[fb][1] * n / 14), foes[fb][0],
					ranks, int(k_sum), int(l_sum), k_sum / maxf(1.0, l_sum), won, reps])
	quit(0)
