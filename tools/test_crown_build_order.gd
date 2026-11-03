extends SceneTree
## THE CROWN'S OWN COMPUTER (scripts/ai_crown.gd, docs/ai_crown_rebuild.md): its build orders.
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_build_order.gd [-- plan:economy map:red_coast seed:4291306512]
##  [table]   every plan's steps are well formed (a known step, a building or unit that exists, known triggers), its
##            milestones too, and the four Crown plans are there
##  [order]   a Hard Crown computer on its plan against a Brood that stands still: the build order's steps are done in the
##            plan's order, each only once its trigger was met (the labourers / supply it waited for), none skipped
##  [gold]    THE PLAN OWNS THE GOLD: a step whose trigger is met is paid within PAY_LATE s (its gold is never spent on
##            something else for long)
##  [hands]   the hall keeps training labourers in the opening (at most HALL_IDLE s without one while under the plan's cap)
##  [over]    the opening ends (its last step, the second hall, by HALL_BY on Economy), the milestones take over, and by 6:00
##            it has LAB_MIN labourers, the Barracks, the Mill and the second hall; a Mill gets its crew (MILL_MIN by 6:00)
##  [rush]    the Rush plan (Horse Breeder opening): the first attack goes out with three Horsemen by RUSH_BY and ends the
##            opening
##  [switch]  with `on` false the computer is the shared one (no build order owns the gold)
const PAY_LATE := 45.0
const HALL_IDLE := 30.0
const HALL_BY := 270.0
const LAB_MIN := 26
const MILL_MIN := 4
const RUSH_BY := 300.0
var fails := 0
var main: Node
var g: Game
var ai: AICrown
var plan_name := "economy"
var map := "red_coast"
var seed_ := 4291306512


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"plan": plan_name = kv[1]
				"map": map = kv[1]
				"seed": seed_ = int(kv[1])
	_run.call_deferred()


func wait(s: float) -> void:
	var until := g.clock + s
	while g.clock < until:
		await physics_frame


func _table() -> void:
	var dos := ["wall_cottage", "wall_gate", "build", "army", "labs", "hall", "attack"]
	var ats := ["sup", "labs", "army", "has"]
	var bad: Array = []
	for p in ["economy", "balanced", "timing", "rush"]:
		if not AICrown.PLANS.has(p):
			bad.append("no plan " + p)
	for p in AICrown.PLANS:
		var pl: Dictionary = AICrown.PLANS[p]
		for st in pl["bo"]:
			if not dos.has(String(st["do"])):
				bad.append("%s: step %s" % [p, str(st)])
			if String(st["do"]) == "build" and not Defs.BUILDINGS.has(String(st["k"])):
				bad.append("%s: building %s" % [p, st["k"]])
			if String(st["do"]) == "army" and not Defs.UNITS.has(String(st["k"])):
				bad.append("%s: unit %s" % [p, st["k"]])
			for k in (st.get("at", {}) as Dictionary):
				if not ats.has(k):
					bad.append("%s: trigger %s" % [p, k])
		for m in pl.get("mid", []):
			if not Defs.BUILDINGS.has(String(m[0])):
				bad.append("%s: milestone %s" % [p, m[0]])
	check(bad.is_empty(), "[table] the plans are well formed %s" % ("" if bad.is_empty() else str(bad)))


func _start(strategy: String) -> void:
	if main != null:
		main.queue_free()
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(seed_)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": strategy},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "timing"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
		g.hud.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	ai = null
	for a in g.ais:
		if a.team == 1:
			a.process_mode = Node.PROCESS_MODE_DISABLED      # (the Brood stands still)
		elif a is AICrown:
			ai = a


func _run() -> void:
	_table()
	await _start(plan_name)
	check(ai != null and ai.on, "(set-up) the Crown has its own computer (AICrown) and it is on")
	if ai == null:
		_end()
		return
	var steps: Array = ai._bo_plan
	# what each step waited for, checked when the step is logged
	var triggered_at := {}        # step index -> clock its trigger was first met
	var paid_late := 0.0
	var late_what := ""
	var idle_t := -1.0
	var idle_worst := 0.0
	var mill_best := 0
	while g.clock < 360.0:
		await wait(1.0)
		if not ai.bo_done:
			var i := ai.bo_i
			if i < steps.size() and ai._st_ready(steps[i]) and not triggered_at.has(i):
				triggered_at[i] = g.clock
			if triggered_at.has(i) and ai._st_price(steps[i]) > 0 and String(steps[i]["do"]) != "attack":
				var late: float = g.clock - float(triggered_at[i])
				if late > paid_late:
					paid_late = late
					late_what = ai._st_text(steps[i])
			var labs := g.workers(0).size()
			var queued := 0
			for h in ai._halls():
				queued += h.queue.size()
			if labs + queued < ai.bo_lab_cap and ai.bo_reserve == 0 and int(g.players[0]["gold"]) >= 50 + 10 and queued == 0:
				if idle_t < 0.0:
					idle_t = g.clock
				idle_worst = maxf(idle_worst, g.clock - idle_t)
			else:
				idle_t = -1.0
		var crew := 0
		for m in ai._mine("powder_mill"):
			crew = maxi(crew, m.crew.size())
		mill_best = maxi(mill_best, crew)
	# [order]
	var texts: Array = []
	for st in steps:
		if not (String(st["do"]) in ["army", "labs"]):
			texts.append(ai._st_text(st))
	var logged: Array = []
	for e in ai.bo_log:
		if not String(e[1]).begins_with("a Cottage (supply"):
			logged.append(String(e[1]))
	var in_order := true
	var j := 0
	for l in logged:
		var k := texts.find(l)
		if k < 0:
			continue
		if k < j:
			in_order = false
		j = k
	print("   build order log: %s" % str(ai.bo_log))
	check(in_order and logged.size() >= texts.size() - 1, "[order] the steps were done in the plan's order (%d logged of %d)" % [logged.size(), texts.size()])
	check(not ai.note.any(func(n) -> bool: return String(n[1]).contains("skipped")), "[order] no step was skipped for want of room")
	# each step's trigger was met when it was done (the log line carries the labourers)
	var early := ""
	for e in ai.bo_log:
		for st in steps:
			if ai._st_text(st) == String(e[1]):
				var at: Dictionary = st.get("at", {})
				var labs_then := _labs_at(float(e[0]))
				if at.has("labs") and labs_then >= 0 and labs_then < int(at["labs"]) - 1:
					early = "%s at %d labourers (trigger %d)" % [e[1], labs_then, int(at["labs"])]
	check(early == "", "[order] no step before its trigger %s" % early)
	# [gold]
	check(paid_late <= PAY_LATE, "[gold] a triggered step was paid within %d s (worst %d s: %s)" % [int(PAY_LATE), int(paid_late), late_what])
	# [hands]
	check(idle_worst <= HALL_IDLE, "[hands] the hall trained labourers in the opening (at most %d s idle with gold, worst %d s)" % [int(HALL_IDLE), int(idle_worst)])
	# [over]
	var hall_t := -1.0
	for e in ai.bo_log:
		if String(e[1]).begins_with("Town Hall"):
			hall_t = float(e[0])
	if plan_name == "economy":
		check(hall_t >= 0.0 and hall_t <= HALL_BY, "[over] the second hall laid by %d s (%d s)" % [int(HALL_BY), int(hall_t)])
	check(ai.bo_done, "[over] the opening is over (%s)" % ai.bo_why)
	check(ai._plan_tech(), "[over] the milestones put up the tech now")
	check(g.workers(0).size() >= LAB_MIN, "[over] %d labourers or more at 6:00 (%d)" % [LAB_MIN, g.workers(0).size()])
	check(not ai._mine("barracks").is_empty() and not ai._mine("powder_mill").is_empty() and ai._halls().size() >= 2,
		"[over] the Barracks, the Mill and a second hall by 6:00")
	check(mill_best >= MILL_MIN, "[over] a Mill had %d hands or more (%d)" % [MILL_MIN, mill_best])
	# [rush]
	await _start("rush")
	var out_t := -1.0
	while g.clock < RUSH_BY + 30.0:
		await wait(2.0)
		if ai._attacking and out_t < 0.0:
			out_t = g.clock
			break
	var riders := ai._wave_set.keys().filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and u.kind == "cuirassier").size()
	check(out_t >= 0.0 and out_t <= RUSH_BY and riders >= 3, "[rush] the first attack went by %d s with 3 Horsemen or more (%d s, %d)" % [int(RUSH_BY), int(out_t), riders])
	await wait(3.0)
	check(ai.bo_done, "[rush] ... and it ended the opening (%s)" % ai.bo_why)
	# [switch]
	ai.on = false
	check(not ai.bo_owns() and not ai._plan_tech(), "[switch] with `on` false no build order owns the gold (the shared computer)")
	_end()


func _labs_at(t: float) -> int:
	# (the build order's match log lines carry the labourers: "... (supply S, N labourers, G gold)")
	for l in g.mlog.lines:
		var s := str(l)
		if not s.contains("build order:"):
			continue
		var mm := int(s.substr(1, 2))
		var ss := int(s.substr(4, 2))
		if absf(float(mm * 60 + ss) - t) > 1.0:
			continue
		var i := s.find(" labourers, ")
		if i > 0:
			var j := s.rfind(", ", i - 1)
			return int(s.substr(j + 2, i - j - 2))
	return -1


func _end() -> void:
	print("test_crown_build_order: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
