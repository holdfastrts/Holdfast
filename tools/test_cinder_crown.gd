extends SceneTree
## THE CROWN'S TIMING AGAINST THE CLOCKWORK, CINDER STEPS (cinder-crown-ai, docs/cinder_crown_ai.md).
##   godot --headless --fixed-fps 30 --script res://tools/test_cinder_crown.gd [-- map:cinder_steps seed:4412]
##  [table]  the one-hall Timing opening against the Clockwork ("bo_clock1") is well formed: the second hall comes before
##           the attack step, with a time it waits no longer than ("by"), and the labourers go on after it
##  [hall]   a Hard Crown on the Timing attack against a Hard Clockwork OPTIMAL lays its second hall by HALL_BY
##  [labs]   it has LABS_MIN labourers or more at LABS_AT (the old one-hall Timing kept 19-20 to 8:00)
##  [wave]   its first wave, if it goes in the opening, goes only while worth AICrown.CK_EDGE of the army it reckons
##  [end]    the opening is over by AICrown.CK_LATE + a little (attack out, or the window shut)
##  [read]   an empty Clockwork base seen before AIScout.GREEDY_ABSENT_CLOCK is no GREEDY read for the Crown's scout
const HALL_BY := 330.0
const LABS_AT := 450.0
const LABS_MIN := 23
var fails := 0
var main: Node
var g: Game
var cr: AICrown
var map := "cinder_steps"
var seed_ := 4412


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"map": map = kv[1]
				"seed": seed_ = int(kv[1])
	_run.call_deferred()


func wait(s: float) -> void:
	var until := g.clock + s
	while g.clock < until and not g.over:
		await physics_frame


func _start() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(seed_)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "timing"},
		{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "optimal"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
		g.hud.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	for a in g.ais:
		if a is AICrown:
			cr = a


func _table() -> void:
	var bo: Array = AICrown.PLANS["timing"].get("bo_clock1", [])
	var hall_i := -1
	var labs_i := -1
	var att_i := -1
	for i in bo.size():
		var st: Dictionary = bo[i]
		match String(st["do"]):
			"hall":
				hall_i = i
				check((st.get("at", {}) as Dictionary).has("by"), "[table] the second hall has a time it waits no longer than (%s)" % str(st.get("at", {})))
			"labs":
				labs_i = i
			"attack":
				att_i = i
	check(hall_i >= 0 and att_i > hall_i and labs_i > hall_i, "[table] the second hall before the attack, the labourers after it (hall %d, labs %d, attack %d)" % [hall_i, labs_i, att_i])


func _run() -> void:
	_table()
	await _start()
	check(cr != null and cr.cc_vs_clock(), "(set-up) a Crown computer against the Clockwork")
	if cr == null:
		_done()
		return
	var hall_t := -1.0
	var labs_at := 0
	var wave_ok := true
	var wave_t := -1.0
	var bo_end_t := -1.0
	var reads: Array = []
	while g.clock < LABS_AT + 2.0 and not g.over:
		await wait(1.0)
		if hall_t < 0.0 and cr._halls().size() >= 2:
			hall_t = g.clock
		if labs_at == 0 and g.clock >= LABS_AT:
			labs_at = g.workers(0).size() + g.haulers_of(0).size()
		if bo_end_t < 0.0 and cr.bo_done:
			bo_end_t = g.clock
		if wave_t < 0.0 and cr._first_wave:
			wave_t = g.clock
			var mine := 0.0
			for u in g.army(0):
				if cr._wave_set.has(u):
					mine += float(Game.unit_value(u))
			# (the reckoning moves a little in a second: a small margin)
			wave_ok = mine >= cr.foe_reckon() * AICrown.CK_EDGE * 0.85
	check(cr._cc_bo == "bo_clock1", "[set-up] the one-hall Timing opening with the hall behind the army (%s)" % cr._cc_bo)
	check(hall_t >= 0.0 and hall_t <= HALL_BY, "[hall] the second hall laid by %d s (%d s)" % [int(HALL_BY), int(hall_t)])
	check(labs_at >= LABS_MIN, "[labs] %d labourers at %d s (wants %d; the old Timing kept 19-20)" % [labs_at, int(LABS_AT), LABS_MIN])
	check(wave_t < 0.0 or wave_ok, "[wave] the first wave (at %d s) went while ahead of the army it reckons" % int(wave_t))
	if bo_end_t < 0.0:
		await wait(maxf(0.0, AICrown.CK_LATE + 15.0 - g.clock))
		if cr.bo_done:
			bo_end_t = g.clock
	check(bo_end_t >= 0.0 and bo_end_t <= AICrown.CK_LATE + 15.0, "[end] the opening is over by %d s (%d s: %s)" % [int(AICrown.CK_LATE + 15.0), int(bo_end_t), cr.bo_why])
	for r in cr.scout.reads:
		if float(r[0]) < AIScout.GREEDY_ABSENT_CLOCK and String(r[1]) == "greedy" and String(r[2]) == "no army and no production at its base":
			reads.append(r)
	check(reads.is_empty(), "[read] no GREEDY read of an empty Clockwork base before %d s %s" % [int(AIScout.GREEDY_ABSENT_CLOCK), str(reads)])
	_done()


func _done() -> void:
	print("test_cinder_crown: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
