extends SceneTree
## EVERY BREEDER BREEDS (the owner's playtest, 2026-11-03: "say I have multiple barracks making Horsemen and multiple
## Horse Breeders available, only 1 Horse Breeder makes horses automatically"). Three Barracks queue Horsemen with no
## horse to hand, three finished Horse Breeders: each breeder gets horses to breed (Game.breeder_with_room picks the
## least busy) and all three are breeding at once. Then the late breeder: two breeders hold all the horses queued, a
## third is finished afterwards: Game.share_breeders hands it a waiting horse. The same for the computer's side
## (team 1, Crown). Last: the Horsemen all ride out.
##   godot --headless --fixed-fps 30 --script res://tools/test_breeders_share.gd
var main: Node
var t := 0.0
var g: Game
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func _breeding(brs: Array) -> int:
	return brs.filter(func(b: Building) -> bool: return b.queue.has("horse")).size()


## Free cells for a w x h building near the team's hall.
func _spot(team: int, size: Vector2i, taken: Array) -> Vector2i:
	var hall: Building = null
	for b in g.buildings:
		if b.team == team and b.kind == "town_hall":
			hall = b
	var c0 := g.cell_of(hall.center())
	for r in range(6, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c := c0 + Vector2i(dx, dy)
				var ok := true
				for y in range(-1, size.y + 1):
					for x in range(-1, size.x + 1):
						var cc := c + Vector2i(x, y)
						if not g.in_map(cc) or not g.is_free(cc) or taken.has(cc):
							ok = false
							break
					if not ok:
						break
				if ok:
					for y in range(-1, size.y + 1):
						for x in range(-1, size.x + 1):
							taken.append(c + Vector2i(x, y))
					return c
	return Vector2i(-1, -1)


func _side(team: int, who: String) -> void:
	g.players[team]["gold"] = 20000
	g.players[team]["res2"] = 2000.0
	g.players[team]["cap"] = 200
	for h in g.horses_of(team).duplicate():
		g.consume_unit(h)
	var taken: Array = []
	var bars: Array = []
	var brs: Array = []
	for i in 3:
		bars.append(g._add_building("barracks", team, _spot(team, Defs.BUILDINGS["barracks"]["size"], taken), true))
	for i in 3:
		brs.append(g._add_building("horse_breeder", team, _spot(team, Defs.BUILDINGS["horse_breeder"]["size"], taken), true))
	for i in 4:
		var cs: Vector2i = _spot(team, Defs.BUILDINGS["cottage"]["size"], taken)
		if cs.x >= 0:
			g._add_building("cottage", team, cs, true)
	for b in g.buildings:
		if b.team == team:
			b.supply()
	await physics_frame
	g.players[team]["cap"] = 200
	g._astar_dirty = true
	await physics_frame
	# each Barracks queues two Horsemen: 6 horses wanted, none to hand
	for b in bars:
		for k in 2:
			var w := g.train(b, "horseman")
			check(w == "", "%s: Horseman queued at a Barracks (%s)" % [who, w])
	var sizes: Array = brs.map(func(b: Building) -> int: return b.queue.size())
	print("%s: breeders' queues %s" % [who, str(sizes)])
	check(_breeding(brs) == 3, "%s: all 3 Horse Breeders breed (queues %s)" % [who, str(sizes)])
	check(sizes.max() - sizes.min() <= 1, "%s: the 6 horses are shared evenly" % who)
	await wait(3.0)
	check(brs.all(func(b: Building) -> bool: return b.prod_t > 0.0), "%s: all three are under way after 3 s" % who)
	var ok := false
	var end: float = g.clock + 120.0
	while g.clock < end:
		var riders := g.units.filter(func(u: Unit) -> bool: return u.team == team and not u.dead and Defs.RIDERS.has(u.kind)).size()
		if riders >= 6:
			ok = true
			break
		await physics_frame
	check(ok, "%s: the 6 Horsemen ride out (%.0f s)" % [who, g.clock - (end - 120.0)])
	# the late breeder: two breeders get all the horses, a third is finished afterwards and takes some over
	for b in brs:
		b.queue.clear()
		b.kits.clear()
		b.prod_t = 0.0
	var late: Building = brs[2]
	late.built = false
	for b in bars:
		var w := g.train(b, "horseman")
		check(w == "", "%s: another Horseman queued (%s)" % [who, w])
	check(late.queue.is_empty() and brs[0].queue.size() + brs[1].queue.size() == 3, "%s: with 2 breeders done they hold the 3 horses" % who)
	late.built = true
	await wait(2.5)
	check(not late.queue.is_empty(), "%s: the breeder finished late takes over a waiting horse (queues %d %d %d)" % [who, brs[0].queue.size(), brs[1].queue.size(), late.queue.size()])
	check(_breeding(brs) == 3, "%s: all 3 breed again" % who)


func _run() -> void:
	g.reveal = true
	await _side(0, "player")
	await _side(1, "computer")
	print("breeders share: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
