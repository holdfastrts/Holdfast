extends SceneTree
## brood-rush-coach (docs/brood_rush_coach.md): the owner's Mirewood playtest (2026-11-13, v0.35.6) as a scripted fight. A
## HARD Brood on RUSH (its own computer runs) has a wave of 10 Raptors at a Crown palisade box (a Cottage inside a ring of
## palisade); 2 Horsemen outside do what the owner did: ride in, strike the nearest Raptor,
## ride off out into the open while the sabre cools, and again. Before (`-- nbchase:on`) the Raptors left the wall and chased
## the riders, who killed them; now the wave keeps at the wall and bites a rider only when he comes into the pack.
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_rush_riders.gd [-- nbchase:on] [-- trials:4] [-- riders:2]
## Prints per trial: Raptors left, rider health lost, Raptor-seconds spent more than 6 tiles from the box, palisade
## pieces and health lost; PASS/FAIL on the new behaviour (unless nbchase:on).
const T := 32.0
var main: Node
var g
var fails := 0
var args := {}


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_go.call_deferred()


func _alive(a: Array) -> Array:
	return a.filter(func(x): return is_instance_valid(x) and not x.dead)


func wait(s: float) -> void:
	var until: float = g.clock + s
	while g.clock < until:
		await physics_frame


func _go() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split(":")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var trials := int(args.get("trials", "4"))
	var nr := int(args.get("riders", "2"))
	var tot := {"raps": 0, "hp": 0.0, "out": 0.0, "wall": 0.0, "pieces": 0, "riders_dead": 0}
	for trial in trials:
		var r: Dictionary = await _trial(trial, nr)
		print("  trial %d: raptors left %d of 10, rider hp lost %d of %d (riders dead %d), raptor-seconds >6 tiles out %.0f, box health lost %d (%d pieces down), cottage %s; let go %d, bites in the pack %d" % [
			trial, r["raps"], int(r["hp"]), nr * 140, r["riders_dead"], r["out"], int(r["wall"]), r["pieces"], "standing" if r["cottage"] else "DOWN", r["letgo"], r["bites"]])
		for k in tot:
			tot[k] += r[k]
	var n := float(trials)
	print("%s (%d riders): raptors left %.1f, rider hp lost %.0f, riders dead %.1f, raptor-seconds out %.0f, box health lost %.0f (%.1f pieces)" % [
		"OLD (chase)" if args.has("nbchase") else "NEW (no chase)", nr, tot["raps"] / n, tot["hp"] / n, tot["riders_dead"] / n, tot["out"] / n, tot["wall"] / n, tot["pieces"] / n])
	if not args.has("nbchase"):
		check(tot["out"] / n < 40.0, "the wave stays at the wall (raptor-seconds more than 6 tiles out: %.0f a trial)" % (tot["out"] / n))
		check(tot["raps"] / n >= 3.0 or tot["riders_dead"] / n >= 1.0, "the riders' hit and run no longer wipes the wave for nothing (raptors left %.1f, riders dead %.1f)" % [tot["raps"] / n, tot["riders_dead"] / n])
		check(tot["wall"] / n > 150.0, "the wave keeps hitting the palisade (%.0f health a trial)" % (tot["wall"] / n))
		print("RESULT: %d failed" % fails)
	quit()


func _trial(trial: int, nr: int) -> Dictionary:
	main.start({"seed": 40 + trial, "map": "greenhold", "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "rush"}]})
	g = main.game
	await create_timer(0.3).timeout
	g.hud.countdown = 0.0
	paused = false
	await wait(2.0)
	var bai = null
	for a in g.ais:
		if a.team == 1:
			bai = a
	var c: Vector2 = load("res://tools/test_raptor_rider_fight.gd")._flat_spot(g)
	var c0: Vector2i = g.cell_of(c)
	var cottage = g._add_building("cottage", 0, c0, true)
	var box: Array = []
	for x in range(c0.x - 3, c0.x + 5):
		for y in range(c0.y - 3, c0.y + 5):
			if x == c0.x - 3 or x == c0.x + 4 or y == c0.y - 3 or y == c0.y + 4:
				var w = g._add_building("wall", 0, Vector2i(x, y), true)
				if w:
					box.append(w)
	var mid: Vector2 = cottage.center()
	if box.size() != 28:
		print("    (the box has %d pieces, not 28)" % box.size())
	var box_hp0 := 0.0
	for w in box:
		box_hp0 += w.hp
	for b in [cottage] + box:
		bai._foe_blds[b] = b.center()
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + trial
	var raps: Array = []
	for i in 10:
		raps.append(g._add_unit("raptor", 1, mid + Vector2(rng.randf_range(-80, 80), 300 + rng.randf_range(0, 60))))
	var riders: Array = []
	for i in nr:
		riders.append(g._add_unit("cuirassier", 0, mid + Vector2(260, 120 + 40 * i)))
	await physics_frame
	bai._attacking = true
	bai._wave = raps.duplicate()
	bai._wave_target = mid
	bai._wave_sup = 10
	bai._wave_v0 = bai._value_of(raps)
	bai._wave_t0 = g.clock
	bai._wave_kills0 = int(g.stats[1]["value_killed"])
	bai._first_out = true
	for u in raps:
		u.cmd_move(mid, true)
	var hp0 := 0.0
	for r in riders:
		hp0 += r.hp
	var t := 0.0
	var out := 0.0
	var sortie := false
	while t < 60.0:
		await wait(0.25)
		t += 0.25
		var rr := _alive(riders)
		var ra := _alive(raps)
		if rr.is_empty() or ra.is_empty() or cottage.dead:
			break
		for x in ra:
			if x.position.distance_to(mid) > 6.0 * T + 4.0 * T:
				out += 0.25
		if args.has("verbose") and int(t * 4) % 2 == 0:
			var ln := "%5.1f riders" % t
			for r in rr:
				ln += " [%s %d d%.0f]" % [r.order, int(r.hp), r.position.distance_to(mid) / T]
			ln += " | "
			for x in ra:
				var tg = x.target
				ln += " %s:%s%.0f" % [x.order.left(2), "-" if tg == null else ("R" if tg is Unit and tg.kind == "cuirassier" else ("W" if tg is Building else String(tg.kind).left(4))), x.position.distance_to(mid) / T]
			print(ln)
		if not sortie:
			var at_wall := 0
			for x in ra:
				if x.position.distance_to(mid) < 6.0 * T:
					at_wall += 1
			sortie = at_wall >= 5 or t > 15.0
			continue
		# the owner's hit and run: ride in at the nearest Raptor when the sabre is ready, ride off out into the open (away
		# from the box and from that Raptor) while it cools
		for r in rr:
			var near: Unit = null
			var nd := INF
			for x in ra:
				var d: float = r.position.distance_to(x.position)
				if d < nd:
					nd = d
					near = x
			if near == null:
				continue
			if r.cooldown > 0.3 and nd < 70.0:
				var away: Vector2 = ((r.position - near.position).normalized() + (r.position - mid).normalized()).normalized()
				r.cmd_move(r.position + away * 96.0, false)
			elif r.cooldown <= 0.05 and (r.order == "move" or r.order == "idle"):
				r.cmd_attack(near)
	if args.has("verbose"):
		for n in bai.note:
			if float(n[0]) >= 2.0:
				print("    note %.1f: %s" % [float(n[0]), str(n[1])])
	var rr2 := _alive(riders)
	var hp1 := 0.0
	for r in rr2:
		hp1 += r.hp
	var box_hp1 := 0.0
	var pieces := 0
	for w in box:
		if is_instance_valid(w) and not w.dead:
			box_hp1 += w.hp
		else:
			pieces += 1
	return {"raps": _alive(raps).size(), "hp": hp0 - hp1, "out": out, "wall": box_hp0 - box_hp1 + (0.0 if not cottage.dead else 0.0),
		"pieces": pieces, "riders_dead": nr - rr2.size(), "cottage": not cottage.dead, "letgo": bai.raid_letgo, "bites": bai.raid_bites}
