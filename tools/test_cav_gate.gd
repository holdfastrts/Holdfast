extends SceneTree
## HORSEMEN BREAK A SHUT GATE (the owner's playtest 2026-11-01, AI Crown v AI Crown on Ashfall, 0.25.25: "at the ramp
## the horsemen didn't attack the gate. They kept galloping to it and got stuck in it, not attacking it"; docs/cav_gate.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_cav_gate.gd [-- shots docs/shots/cav_gate]
## On Ashfall (the playtest's seed) the green Crown's own ramp wall is laid (AI.plan_cottage_wall: Cottage, palisade, gate),
## a Labourer works behind it, and the green army is away. Yellow's riders start down the ramp:
##  1. ATTACK-MOVE past the gate to the green hall: a rider strikes a wall piece within 20 s;
##  2. ATTACK the Labourer behind the gate: a rider strikes a wall piece within 20 s;
##  3. the computer's HUNT (AI._hunt every second, the raid's and the cavalry wave's way of riding at the workers, which
##     used a plain move): a rider strikes a wall piece within 20 s;
##  4. the computer's RAID, whole: yellow's Hard AI runs, its party (4 Horsemen, each with his pistol) set as raiders,
##     green's AI off and no green soldier: a piece of the wall is brought down (under 12% of its hit points) within 90 s;
##  5. the same with two green Labourers mending from behind the wall (on the high ground: the riders below can't see
##     them, game._stamp): the raid breaks through, or gives the wall up within 45 s and rides off (none left at it);
##  6. the same with a Labourer mending from the ramp side, where the riders see him: he is shot or cut, and a piece
##     goes down within 90 s.
## Prints PASS / FAIL lines and "cav_gate: N failures".
var main: Node
var g
var t := 0.0
var begun := false
var started := false
var fails := 0
var shots := ""
var green: AI
var yellow: AI
var pieces: Array = []
var gate: Building
var hall: Building
var foot := Vector2.ZERO
var dir := Vector2.ZERO
var flv := 0
var inside := Vector2.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("shots") and args.find("shots") + 1 < args.size():
		shots = args[args.find("shots") + 1]
		DirAccess.make_dir_recursive_absolute(shots)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if not begun and t > 0.2:
		begun = true
		seed(1864215939)
		main.start({"map": "ashfall", "seed": 1864215939, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "timing"},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "economy"}]})
		for ai in main.game.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
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


func _free_near(p: Vector2, lv: int, r := 8.0) -> Vector2:
	for k in 14:
		for i in maxi(1, k * 6):
			var q: Vector2 = p + Vector2.from_angle(TAU * i / maxf(1.0, k * 6.0)) * k * 8.0
			var c: Vector2i = g.cell_of(q)
			if g.in_map(c) and g._walkable(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == lv and g._clear_at(q, r, 1):
				return q
	return p


## (no piece is ever let fall: a piece brought under BROKEN of its hit points counts as broken and is made whole again)
const BROKEN := 0.12
const RAID_GIVE_UP := 45.0       # (s) at the latest a raid that can't break in rides off


func _wall_up() -> void:
	for b in pieces:
		if is_instance_valid(b) and not b.dead:
			b.hp = b.max_hp


var plan := {}


func _lay() -> void:
	pieces = [g._add_building("cottage", 0, plan["cottage"], true)]
	for e in plan["pieces"]:
		pieces.append(g._add_building(e[0], 0, e[1], true))
	gate = null
	for b in pieces:
		if is_instance_valid(b) and not b.dead and b.kind == "gate":
			gate = b


func _struck() -> bool:
	for u in g.units:
		if u.team == 1 and not u.dead and u.phase != "" and is_instance_valid(u.target) and pieces.has(u.target):
			return true
	return pieces.any(func(b) -> bool: return is_instance_valid(b) and b.hp < b.max_hp)


func _riders(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(g._add_unit("cuirassier", 1, _free_near(foot + dir * (260.0 + 20.0 * (i % 2)) + dir.orthogonal() * 26.0 * float(i - n / 2), flv, 14.0)))
	return out


func _gone(list: Array) -> void:
	for u in list:
		if is_instance_valid(u) and not u.dead:
			g.consume_unit(u)


func _run() -> void:
	for a in g.ais:
		if a.team == 0:
			green = a
		else:
			yellow = a
	plan = green.plan_cottage_wall()
	var bands: Array = green._ramp_bands()
	var band: Array = bands[0]["band"]
	var rampc: Array = bands[0]["ramp"]
	var bc := Vector2.ZERO
	for c in band:
		bc += g.cell_center(c)
	bc /= band.size()
	var rc := Vector2.ZERO
	for c in rampc:
		rc += g.cell_center(c)
	rc /= rampc.size()
	dir = (rc - bc).normalized()
	_lay()
	check(gate != null, "0. green's wall at its ramp, with a gate (%d pieces)" % pieces.size())
	if gate == null:
		_end()
		return
	var lv := int(g.height[g.idx(band[0])])
	foot = rc
	for i in 40:
		var q: Vector2 = rc + dir * (i * 16.0)
		var c: Vector2i = g.cell_of(q)
		if g.in_map(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) < lv:
			foot = q
			break
	flv = int(g.height[g.idx(g.cell_of(foot))])
	for b in g.buildings:
		if b.team == 0 and b.kind == "town_hall":
			hall = b
	inside = _free_near(gate.center() - dir * 110.0, lv, 8.0)
	# green's men: its soldiers gone (the army away); its Labourers stay at work in the base
	for u in g.units.duplicate():
		if u.team == 0 and not u.is_worker():
			g.consume_unit(u)
	# a Labourer standing just behind the gate (the prey the riders see)
	var lab: Unit = g._add_unit("labourer", 0, inside)
	lab.auto_work = false
	lab.cmd_hold()
	await wait(0.5)
	# --- 1-3: one rider at a time, each way
	for how in ["amove", "attack", "hunt"]:
		await _wall_up()
		var rs := _riders(2)
		await wait(0.3)
		for u in rs:
			if how == "amove":
				u.cmd_move(hall.center(), true)
			elif how == "attack":
				u.cmd_attack(lab)
		var hit := false
		var end: float = g.clock + 20.0
		var nxt := 0.0
		while g.clock < end:
			if how == "hunt" and g.clock >= nxt:
				nxt = g.clock + 1.0
				for u in rs:
					if is_instance_valid(u) and not u.dead:
						yellow._hunt(u, lab.position)
			if _struck():
				hit = true
				break
			await physics_frame
		var u0: Unit = rs[0]
		check(hit, "%s. Horsemen %s: %s (rider 0: order %s, target %s, %d px from the gate)" % [
			{"amove": "1", "attack": "2", "hunt": "3"}[how], {"amove": "ATTACK-MOVE past the gate", "attack": "ATTACK the Labourer behind the gate", "hunt": "the computer's hunt for the Labourer behind the gate"}[how],
			"strike the wall" if hit else "never strike it in 20 s", u0.order, (u0.target.kind if is_instance_valid(u0.target) else "none"), int(gate.edge_distance(u0.position))])
		if hit and shots and how == "hunt":
			await _shoot("hunt_strikes_gate")
		_gone(rs)
		await wait(0.3)
	# --- 4-6: the computer's raid, whole (yellow's AI thinks; green's is off)
	for mode in ["none", "inside", "outside"]:
		await _wall_up()
		var rs := _riders(4)
		var menders: Array = []
		if mode == "inside":
			# (two hands, as the computer sends (AI.REPAIR_HANDS), behind the wall on the high ground: hidden from the riders
			# below, game._stamp)
			for k in 2:
				menders.append(g._add_unit("labourer", 0, _free_near(gate.center() - dir * (50.0 + 20.0 * k), lv, 8.0)))
		elif mode == "outside":
			menders.append(g._add_unit("labourer", 0, _free_near(gate.center() + dir * 44.0, flv, 8.0)))
		for m in menders:
			m.auto_work = false
		yellow.process_mode = Node.PROCESS_MODE_INHERIT
		yellow._raiders.clear()
		for u in rs:
			yellow._raiders.append(u)
		yellow._raid_peak = rs.size()
		yellow._raid_block = 0.0
		yellow._raid_home = 0.0
		yellow._raid_piece = null       # (a fresh party, as _raid forms one)
		yellow.raid_wall_said = ""
		yellow.raid_wall_log.clear()
		var limit := 90.0
		var t0: float = g.clock
		var broke := false
		var hurt := false
		var shot_taken := false
		var gave_up := -1.0
		while g.clock < t0 + limit:
			for m in menders:
				if is_instance_valid(m) and not m.dead:
					var p = pieces.filter(func(b) -> bool: return is_instance_valid(b) and not b.dead and b.hp < b.max_hp)
					if not p.is_empty() and m.order != "repair":
						p.sort_custom(func(x, y) -> bool: return x.hp / x.max_hp < y.hp / y.max_hp)
						m.cmd_repair(p[0])
				if not is_instance_valid(m) or m.dead or m.hp < m.max_hp:
					hurt = true
			var low = pieces.filter(func(b) -> bool: return is_instance_valid(b) and not b.dead and b.hp < b.max_hp * BROKEN)
			if not low.is_empty():
				broke = true
				break
			if gave_up < 0.0 and (yellow.raid_wall_said == "home" or yellow.raid_wall_said == "elsewhere"):
				gave_up = g.clock - t0
			if gave_up >= 0.0 and g.clock - t0 > gave_up + 10.0:
				break                   # (gone: does any still stand at the wall?)
			if shots and not shot_taken and _struck() and g.clock > t0 + 5.0:
				shot_taken = true
				await _shoot("raid_" + mode)
			await physics_frame
		var left := rs.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
		for l in yellow.raid_wall_log:
			print("    [%d] raid %s" % [int(l[0] - t0), l[1]])
		var at_wall := left.filter(func(u) -> bool: return gate.edge_distance(u.position) < 120.0).size()
		var n: String = {"none": "4", "inside": "5", "outside": "6"}[mode]
		var what: String = {"none": "at an unmanned wall", "inside": "against two menders hidden behind it", "outside": "against a mender out on the ramp side"}[mode]
		if mode == "inside":
			# (it can't see them: it breaks through anyway, or gives the wall up and rides off; it never stands at it)
			check(broke or (gave_up >= 0.0 and gave_up <= RAID_GIVE_UP and at_wall == 0), "%s. the raid %s breaks through or gives up and rides off: %s (%d riders left, %d still at the wall)" % [
				n, what, ("a piece is down in %d s" % int(g.clock - t0)) if broke else (("gave up at %d s" % int(gave_up)) if gave_up >= 0.0 else "neither in %d s" % int(limit)), left.size(), at_wall])
		else:
			check(broke, "%s. the raid (4 Horsemen) %s breaks through: %s in %d s (%d riders left)" % [n, what, "a piece is down" if broke else "nothing down",
				int(g.clock - t0), left.size()])
		if mode == "outside":
			check(hurt, "6b. the mender the riders can see is shot or cut")
		yellow.process_mode = Node.PROCESS_MODE_DISABLED
		yellow._raiders.clear()
		_gone(rs)
		_gone(menders)
		await wait(0.3)
	# --- 7: a cavalry WAVE (the Horseman rush's wave, AI._army: its riders hunt the workers, AI._hunt, and the wave's
	# siege weighs the wall up, AI._siege_tick): 4 Horsemen sent at the walled base, no defender: a piece is down in 90 s
	await _wall_up()
	var wv := _riders(4)
	yellow.process_mode = Node.PROCESS_MODE_INHERIT
	yellow._raiders.clear()
	yellow._raid_block = 99999.0
	yellow._attack_at = 999
	yellow._attacking = true
	yellow._wave_set.clear()
	for u in wv:
		yellow._wave_set[u] = true
	var t1: float = g.clock
	var broke7 := false
	while g.clock < t1 + 90.0:
		if pieces.any(func(b) -> bool: return is_instance_valid(b) and not b.dead and b.hp < b.max_hp * BROKEN):
			broke7 = true
			break
		if shots and g.clock > t1 + 8.0 and g.clock < t1 + 8.05:
			await _shoot("wave")
		await physics_frame
	var w0: Unit = wv[0]
	check(broke7, "7. a cavalry wave (4 Horsemen) at the walled base, no defender, breaks through: %s in %d s (rider 0: order %s, target %s, %d px from the gate; wave %s)" % [
		"a piece is down" if broke7 else "nothing down", int(g.clock - t1), w0.order, (w0.target.kind if is_instance_valid(w0.target) else "none"),
		int(gate.edge_distance(w0.position)), "out" if yellow._attacking else "over"])
	yellow.process_mode = Node.PROCESS_MODE_DISABLED
	_gone(wv)
	_end()


func _shoot(name: String) -> void:
	g.camera.position = gate.center() + dir * 40.0
	g.camera.zoom = Vector2(1.6, 1.6)
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])


func _end() -> void:
	print("cav_gate: %d failures" % fails)
	quit(1 if fails > 0 else 0)
