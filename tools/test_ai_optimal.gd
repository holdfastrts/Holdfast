extends SceneTree
## THE OPTIMAL PLAN AND THE READS (ai-optimal, docs/ai_optimal.md), end to end:
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_optimal.gd
## Each case: a Hard computer (team 0) against a second player whose own computer is switched off (its workers only
## gather), its base dressed for the case on Greenhold:
##  1. a GREEDY enemy (a second hall, nothing military) is read GREEDY and OPTIMAL punishes it in time: the Crown's
##     OPTIMAL against the Clockwork (the Horseman rush or Balanced's steady waves, picked by 2:30), the Clockwork's against the
##     Crown (the Clock Soldier rush), the Brood's against the Clockwork (the Raptor rush); the build then plays (its
##     Horse Breeder / Light Works / Raptors come)
##  2. NO ARMY FOR NOTHING: a scout killed before it saw anything reads UNKNOWN: the plan's own settings, no Barracks put
##     up for it (the Crown's Balanced used to "play safe"), another scout within a minute
##  3. FIXED PLANS KEEP THEIR PLAN: the Crown's Economy against a greedy enemy races it (it does not turn into a timing
##     attack); against a rush it still defends (the Barracks and the Mill first) and stays the Economy plan
##  4. OPTIMAL NEVER HORSEMAN-RUSHES THE CROWN: its pick against a greedy Crown, 300 times at every early moment, and the
##     lean before scouting; against a greedy Brood read in time it is the Horseman rush (the owner, 2026-11-06), too late
##     for the riders it out-expands (never the Siege push)
##  5. THE COMMON OPENING (crown-optimal-opening): the Barracks, then the second Farm, no Powder Mill before the read, the
##     labourers keep coming, a greedy Brood (its own Economy computer) is read and the Horse Breeder goes down at once
##  6. an AGGRESSIVE read puts the Powder Mill up at once, no Horseman rush
## Prints PASS / FAIL per check and "ALL PASS" at the end (exit 1 on a failure).
var main: Node
var g: Game
var ai: AI
var foe_hall: Building
var fails := 0
var map := "greenhold"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _start(fa: String, strategy: String, fb: String, sb := "balanced", foe_on := false) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(4242)
	main.start({"map": map, "seed": 4242, "slots": [
		{"who": "hard", "faction": fa, "colour": 0, "side": 0, "strategy": strategy},
		{"who": "hard", "faction": fb, "colour": 1, "side": 1, "strategy": sb}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		if a.team == 1:
			if not foe_on:
				a.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			ai = a
	var hs := g.halls_of(1)
	foe_hall = hs[0] if not hs.is_empty() else null


func _stop() -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _until(clock: float, cond := Callable()) -> void:
	while g.clock < clock and not g.over:
		await physics_frame
		if cond.is_valid() and cond.call():
			return


func _log_has(text: String) -> bool:
	if g.mlog:
		for l in g.mlog.lines:
			if String(l).contains(text):
				return true
	return false


func _greedy_dress() -> void:
	# a second hall at its natural and nothing military: an economy on two halls (team 1's computer is off)
	var hall: String = g.faction_hall(1)
	if g.expansions.size() > 1 and g.expansions[1] is Vector2i:
		g._add_building(hall, 1, g.expansions[1], true)


func _run() -> void:
	# ---- 1: a greedy enemy is punished in time
	await _start("crown", "optimal", "clockwork")
	_greedy_dress()
	await _until(170.0, func() -> bool: return not (ai.opt.picks as Array).is_empty())
	var pk: Array = ai.opt.picks[0] if not (ai.opt.picks as Array).is_empty() else [0.0, "", "", "", ""]
	print("   Crown OPTIMAL v a greedy Clockwork: %s" % str(pk))
	check(String(pk[2]) == "GREEDY", "the Crown reads the greedy Clockwork as GREEDY (%s)" % pk[2])
	check(String(pk[3]) in ["rush", "balanced"] and float(pk[0]) <= 150.0, "it punishes it in time: %s at %d s" % [pk[3], int(pk[0])])
	check(ai.strategy == String(pk[3]), "the picked build plays (strategy %s)" % ai.strategy)
	await _until(g.clock + 60.0)
	var built := ai._mine("horse_breeder").size() if ai.strategy == "rush" else ai._mine("barracks").size()
	check(built > 0, "its build is under way a minute later (%s: %d)" % ["Horse Breeder" if ai.strategy == "rush" else "Barracks", built])
	check(_log_has("reads GREEDY") and _log_has("picks"), "the read and the pick are in the match log")
	await _stop()

	await _start("clockwork", "optimal", "crown")
	_greedy_dress()
	await _until(200.0, func() -> bool: return not (ai.opt.picks as Array).is_empty())
	pk = ai.opt.picks[0] if not (ai.opt.picks as Array).is_empty() else [0.0, "", "", "", ""]
	print("   Clockwork OPTIMAL v a greedy Crown: %s" % str(pk))
	check(String(pk[2]) == "GREEDY" and String(pk[3]) in ["cs_rush", "springer"], "the Clockwork punishes a greedy Crown (%s -> %s)" % [pk[2], pk[3]])
	await _until(g.clock + 45.0)
	check(ai._mine(ai._works()).size() > 0, "its Light Works is down (%d)" % ai._mine(ai._works()).size())
	await _stop()

	await _start("brood", "optimal", "clockwork")
	_greedy_dress()
	await _until(200.0, func() -> bool: return not (ai.opt.picks as Array).is_empty())
	pk = ai.opt.picks[0] if not (ai.opt.picks as Array).is_empty() else [0.0, "", "", "", ""]
	print("   Brood OPTIMAL v a greedy Clockwork: %s" % str(pk))
	check(String(pk[2]) == "GREEDY" and String(pk[3]) in ["rush", "timing"], "the Brood punishes a greedy Clockwork (%s -> %s)" % [pk[2], pk[3]])
	await _stop()

	# ---- 2: no army for nothing
	await _start("crown", "balanced", "crown")
	await _until(120.0, func() -> bool: return ai.scout.state == "going" and ai.scout.unit != null and g.clock > 20.0)
	var t_kill := g.clock
	if ai.scout.unit != null:
		ai.scout.unit.die()
	await _until(t_kill + 3.0)
	print("   verdict at %d s: %s (%s)" % [int(g.clock), ai.scout.verdict, ai.scout.reason])
	check(ai.scout.verdict == "uncertain", "a scout killed early reads UNKNOWN (%s)" % ai.scout.verdict)
	check(not ai._safe_on and ai.scout.mod.is_empty() and not ai._army_first(), "UNKNOWN is no reason for an army: no Barracks put first, no army first")
	await _until(t_kill + 60.0, func() -> bool: return ai.scout.trips >= 2)
	check(ai.scout.trips >= 2, "another scout goes within a minute (%d s)" % int(g.clock - t_kill))
	await _stop()

	# ---- 3: fixed plans keep their plan
	await _start("crown", "economy", "crown")
	_greedy_dress()
	await _until(220.0, func() -> bool: return ai.scout.verdict != "pending")
	print("   Economy v greedy: %s (%s)" % [ai.scout.verdict, ai.scout.reason])
	check(ai.scout.verdict == "greedy" and ai.strategy == "economy", "the Economy plan reads GREEDY and stays the Economy plan (strategy %s)" % ai.strategy)
	check(float(ai._s("expand")) <= 0.35 and _log_has("races it"), "it races it: its halls sooner (expand x%s)" % ai._s("expand"))
	await _stop()

	await _start("crown", "economy", "crown")
	var spot := g.find_spot(1, "barracks", foe_hall, 4, 16, "near", true)
	if spot.x >= 0:
		g._add_building("barracks", 1, spot, true)
	spot = g.find_spot(1, "horse_breeder", foe_hall, 4, 16, "near", true)
	if spot.x >= 0:
		g._add_building("horse_breeder", 1, spot, true)
	var at := foe_hall.center()
	for i in 6:
		g._add_unit("cuirassier", 1, at + Vector2(60 + (i % 3) * 30, 90 + (i / 3) * 30))
	await _until(220.0, func() -> bool: return ai.scout.verdict == "rush")
	print("   Economy v a rush: %s (%s)" % [ai.scout.verdict, ai.scout.reason])
	check(ai.scout.verdict == "rush", "the Economy plan reads the rush AGGRESSIVE")
	await _until(g.clock + 8.0)
	check(ai.strategy == "economy" and ai._def_on, "it defends (the Barracks and the Mill first) and stays the Economy plan (strategy %s, defence %s)" % [ai.strategy, ai._def_on])
	await _stop()

	# ---- 4: OPTIMAL never Horseman-rushes the Crown
	await _start("crown", "optimal", "crown")
	var rushes := 0
	for i in 300:
		var c: Array = ai.opt._punish("crown", 40.0 + float(i % 30) * 10.0)
		if not c.is_empty() and String(c[0]) == "rush":
			rushes += 1
	check(rushes == 0, "its pick against a greedy Crown is never the Horseman rush (%d of 300)" % rushes)
	var leans := 0
	for i in 100:
		ai.opt.lean = ""
		if ai.opt.lean_now() == "rush":
			leans += 1
	check(leans == 0, "it never leans to the Horseman rush against the Crown (%d of 100)" % leans)
	_greedy_dress()
	await _until(200.0, func() -> bool: return not (ai.opt.picks as Array).is_empty())
	pk = ai.opt.picks[0] if not (ai.opt.picks as Array).is_empty() else [0.0, "", "", "", ""]
	print("   Crown OPTIMAL v a greedy Crown: %s" % str(pk))
	check(String(pk[3]) != "rush" and ai.opening != "breeder", "against a greedy Crown it punishes with no Horseman rush (%s)" % pk[3])
	await _stop()
	await _start("crown", "optimal", "clockwork")
	var vs_brood := 0
	var late_siege := 0
	for i in 300:
		var c2: Array = ai.opt._punish("brood", 60.0 + float(i % 10) * 10.0)
		if not c2.is_empty() and String(c2[0]) == "rush":
			vs_brood += 1
		var c3: Array = ai.opt._punish("brood", AIOptimal.BREEDER_BY + 5.0 + float(i % 10) * 20.0)
		if not c3.is_empty() and String(c3[0]) == "siege":
			late_siege += 1
	check(vs_brood == 300, "against a greedy Brood read by 2:30 it is the Horse Breeder and the riders (%d of 300; the owner, 2026-11-06)" % vs_brood)
	check(late_siege == 0, "read too late for the riders, it out-expands, never the slow Siege push (%d of 300)" % late_siege)
	var leans_b := 0
	for i in 200:
		ai.opt.lean = ""
		if ai.opt._lean_chance("brood", 60.0) > 0.0:
			leans_b += 1
	check(leans_b == 200, "against the Brood it may lean to the Horseman rush before it scouts (the matchup)")
	await _stop()

	# ---- 5: THE COMMON OPENING (crown-optimal-opening, the owner 2026-11-06): the ramp Cottage, the Gate, the Barracks,
	# the second Farm; no Powder Mill before the read; labourers never stop; a greedy Brood -> the Horse Breeder at once
	await _start("crown", "optimal", "brood", "economy", true)     # (the Brood's own Economy computer: a real greed)
	ai.opt._rng.seed = 7
	if ai.strategy != "optimal":
		ai.strategy = "optimal"           # (no lean before the scout for this case: the read decides)
		ai.opt.current = "optimal"
		ai.opt.picks.clear()
		ai.opt.switched.clear()
		ai.opt_switch("optimal")
	var t_bar := -1.0
	var t_farm := -1.0
	var mill_before := false
	var labs_90 := -1
	while g.clock < 230.0 and (ai.opt.picks as Array).is_empty():
		await physics_frame
		if t_bar < 0.0 and not ai._mine("barracks").is_empty():
			t_bar = g.clock
		if t_farm < 0.0 and ai._mine("farm").size() >= 2:
			t_farm = g.clock
		if not ai._mine("powder_mill").is_empty():
			mill_before = true
		if labs_90 < 0 and g.clock >= 90.0:
			labs_90 = g.workers(0).size()
	pk = ai.opt.picks[0] if not (ai.opt.picks as Array).is_empty() else [0.0, "", "", "", ""]
	if labs_90 < 0:
		await _until(90.0)
		labs_90 = g.workers(0).size()
	print("   Crown OPTIMAL v a Brood: Barracks %d s, Farm 2 %d s, labourers at 1:30 %d, pick %s" % [int(t_bar), int(t_farm), labs_90, str(pk)])
	check(t_bar > 0.0 and t_farm > 0.0 and t_bar <= t_farm, "the common opening: the Barracks, then the second Farm (%d s, %d s)" % [int(t_bar), int(t_farm)])
	check(not mill_before, "no Powder Mill before the scout's read")
	check(labs_90 >= 9, "the labourers keep coming while it waits for the read (%d at 1:30)" % labs_90)
	check(not _log_has("Optimal waited") and not _log_has("OPTIMAL's pick: Optimal waited"), "the pick never waits with the gold in the bank")
	check(String(pk[2]) == "GREEDY" and String(pk[3]) == "rush", "a greedy Brood is punished with the Horseman rush (%s -> %s)" % [pk[2], pk[3]])
	await _until(g.clock + 20.0)
	check(not ai._mine("horse_breeder").is_empty(), "the Horse Breeder goes down at once after the read (%d)" % ai._mine("horse_breeder").size())
	await _stop()

	# ---- 6: an AGGRESSIVE read puts the Powder Mill (and the soldiers) up at once
	await _start("crown", "optimal", "crown")
	spot = g.find_spot(1, "barracks", foe_hall, 4, 16, "near", true)
	if spot.x >= 0:
		g._add_building("barracks", 1, spot, true)
	spot = g.find_spot(1, "horse_breeder", foe_hall, 4, 16, "near", true)
	if spot.x >= 0:
		g._add_building("horse_breeder", 1, spot, true)
	at = foe_hall.center()
	for i in 6:
		g._add_unit("cuirassier", 1, at + Vector2(60 + (i % 3) * 30, 90 + (i / 3) * 30))
	await _until(220.0, func() -> bool: return ai.scout.verdict == "rush")
	var t_read := g.clock
	await _until(g.clock + 25.0, func() -> bool: return not ai._mine("powder_mill").is_empty())
	print("   Crown OPTIMAL v a rush: read %d s, Mill %s, strategy %s" % [int(t_read), str(not ai._mine("powder_mill").is_empty()), ai.strategy])
	check(ai.scout.verdict == "rush" and not ai._mine("powder_mill").is_empty(), "an AGGRESSIVE read: the Powder Mill goes down at once (%d s after the read)" % int(g.clock - t_read))
	check(ai.strategy != "rush" and ai._mine("horse_breeder").is_empty(), "and no Horseman rush (strategy %s)" % ai.strategy)
	await _stop()

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
