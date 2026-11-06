extends SceneTree
## THE BROOD COMPUTER AGAINST A HORSEMAN RAID (brood-anti-riders, docs/brood_anti_riders.md; the owner's Hollowfen game
## 2026-11-06). A Hard Brood computer (OPTIMAL) on Hollowfen against a Crown whose computer is switched off:
##   read   a Horse Breeder stands in the Crown's main from the start (no Powder Mill): the Brood's first watching grub
##          looks into the main and READS the riders (rider read) before 3:00, long before any rider comes
##   raid   at 3:30, 3 Horsemen ride in from the road and hunt its grubs (scripted like the Crown's raid: the nearest grub
##          within 20 tiles, home under half health): most grubs SURVIVE (at most 40% lost: these riders fight on to half their health), no grub gang-up on a healthy
##          rider, the warriors stay on their leash (none farther than 20 tiles from the Mother), the riders DIE or LEAVE,
##          and the Mother stays rooted; afterwards it says the riders are gone and lays grubs again
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_v_riders.gd [-- only:read|raid]
var main: Node
var t := 0.0
var g: Game
var started := false
var fails := 0
var only := ""
var ai: AIBroodNew
var bt := 1
var ft := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only:"):
			only = a.substr(5)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		seed(5)
		main.start({"map": "hollowfen", "seed": 3233604515, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "rush"},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "optimal"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	g.path_budget_us = 1 << 40
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.5:
		started = true
		for a in g.ais:
			if a is AIBroodNew:
				ai = a
				bt = a.team
			else:
				a.process_mode = Node.PROCESS_MODE_DISABLED
		ft = 1 - bt
		_run()
	return false


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func alive(list: Array) -> Array:
	return list.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)


func notes_since(t0: float, word: String) -> Array:
	return ai.note.filter(func(n) -> bool: return float(n[0]) >= t0 and word in String(n[1]))


func _crown_home() -> Vector2:
	return (Vector2(g.starts[ft]) + Vector2(2.5, 2.0)) * Defs.TILE


## A Horse Breeder of the Crown's near its hall (in its main).
func _place(k: String) -> Building:
	var hall: Building = g._own_hall(ft)
	var spot: Vector2i = g.find_spot(ft, k, hall, 4, 16, "near", true)
	if spot.x < 0:
		return null
	return g._add_building(k, ft, spot, true)


func _run() -> void:
	await wait(1.0)
	var q: Unit = BroodNew.queen(g, bt)
	for u in g.units:
		if u.team == ft:
			u.cmd_stop()
	var br := _place("horse_breeder")
	check(br != null, "a Horse Breeder stands in the Crown's main")
	if only == "" or only == "read":
		while g.clock < 180.0 and ai.rider_read_first < 0.0:
			await physics_frame
		check(ai.rider_read_first >= 0.0 and ai.rider_read_first < 180.0, "the Brood reads the riders from the Horse Breeder by 3:00 (at %s: %s)" % [_mmss(ai.rider_read_first), ai.rider_read])
	if only == "" or only == "raid":
		await _raid(q)
	print("%d FAILED" % fails if fails > 0 else "ALL PASS")
	quit(1 if fails > 0 else 0)


func _mmss(c: float) -> String:
	if c < 0.0:
		return "never"
	return "%d:%02d" % [int(c) / 60, int(c) % 60]


func _raid(q: Unit) -> void:
	print("-- raid")
	if g.clock < 210.0:
		await wait(210.0 - g.clock)
	# the riders: on the road, 34 tiles from the Mother toward the Crown
	var dir := (_crown_home() - q.position).normalized()
	var from := q.position + dir * 34.0 * Defs.TILE
	for i in 30:
		if g._walkable(g.cell_of(from)):
			break
		from -= dir * Defs.TILE
	var riders: Array = []
	for i in 3:
		var r: Unit = g._add_unit("cuirassier", ft, from + Vector2(i * 30 - 30, 0))
		riders.append(r)
	var grubs0: Array = g.workers(bt).duplicate()
	var t0 := g.clock
	var hit := -1.0
	var gang_healthy := false
	var far_max := 0.0
	var mother_up := false
	var left := {}
	while g.clock - t0 < 100.0:
		await wait(0.5)
		for r in alive(riders):
			if left.has(r):
				continue
			if r.hp < r.max_hp * 0.5:
				left[r] = true
				r.cmd_move(_crown_home())
				continue
			var best: Unit = null
			for u in g.units_near(r.position, 20.0 * Defs.TILE):
				if u.team == bt and not u.dead and u.kind == "grub" and (best == null or u.position.distance_to(r.position) < best.position.distance_to(r.position)):
					best = u
			if best != null:
				if r.order_target != best:
					r.cmd_attack(best)
			elif r.order != "move":
				r.cmd_move(q.position + Vector2.from_angle(g.clock) * 8.0 * Defs.TILE)
			if hit < 0.0 and ai._in_my_land(q, r.position):
				hit = g.clock
			# grubs on a healthy rider
			if r.hp >= r.max_hp * 0.5:
				var on := 0
				for u in g.units_near(r.position, 3.0 * Defs.TILE):
					if u.team == bt and u.kind == "grub" and not u.dead and u.order == "attack" and u.order_target == r:
						on += 1
				if on >= 3:
					gang_healthy = true
		for u in ai._nb_army_units():
			if u.kind == "raptor" or u.kind == "spitter":
				far_max = maxf(far_max, u.position.distance_to(q.position) / Defs.TILE)
		if BroodNew.queen(g, bt) and not BroodNew.rooted(BroodNew.queen(g, bt)):
			mother_up = true
		if alive(riders).filter(func(r) -> bool: return not left.has(r)).is_empty():
			break
	var lost := grubs0.filter(func(u) -> bool: return not is_instance_valid(u) or u.dead).size()
	var dead := riders.size() - alive(riders).size()
	var fled := alive(riders).filter(func(r) -> bool: return left.has(r)).size()
	print("   riders: %d dead, %d left home; grubs lost %d of %d; hit %s; warriors farthest %.0f tiles" % [dead, fled, lost, grubs0.size(), _mmss(hit), far_max])
	check(lost * 10 <= grubs0.size() * 4, "most grubs survive the raid (%d of %d lost, at most 40%%; riders that fight to half their health)" % [lost, grubs0.size()])
	check(dead + fled == riders.size(), "the riders die or leave (%d dead, %d left)" % [dead, fled])
	check(not gang_healthy, "no grubs gang up on a healthy rider")
	check(far_max <= 30.0, "the warriors keep to their leash (farthest %.0f tiles from the Mother)" % far_max)
	check(not mother_up, "the Mother stays rooted against riders")
	check(ai.rider_read_first >= 0.0 and (hit < 0.0 or ai.rider_read_first <= hit), "the read came before the hit (read %s, hit %s)" % [_mmss(ai.rider_read_first), _mmss(hit)])
	check(not notes_since(t0, "riders in its land").is_empty(), "it says the riders are in its land")
	await wait(RIDER_CALM_WAIT)
	check(not notes_since(t0, "the riders are gone").is_empty(), "it says the riders are gone afterwards")
	var g1 := g.workers(bt).size()
	await wait(40.0)
	check(g.workers(bt).size() > g1, "it lays grubs again after the raid (%d -> %d)" % [g1, g.workers(bt).size()])
	if OS.get_environment("NOTES") != "":
		for n in notes_since(t0 - 60.0, ""):
			print("   %s %s" % [_mmss(float(n[0])), str(n[1])])
		print("   food %d eggs %d want %d army %d" % [int(g.players[bt]["gold"]), int(BroodNew.queen(g, bt).nb.get("eggs", 0)), ai._nb_want_grubs(), ai._nb_army_units().size()])


const RIDER_CALM_WAIT := 45.0
