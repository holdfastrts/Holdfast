extends SceneTree
## CROWN V CLOCKWORK, COACHED (crown-v-clockwork-coach, docs/crown-v-clockwork-coach.md): the matchup's own rules.
##   godot --headless --fixed-fps 30 --script res://tools/test_crcw_coach.gd [-- map:greenhold seed:1101]
##  [table]    the Timing attack's opening against the Clockwork ("bo_clock") is well formed: known steps, the second hall,
##             the Foundry before the second Barracks (the owner's rule)
##  [reckon]   the Clockwork reckons a Hard Crown's army at its real size (AICwArmy.TABLES["crown"]: 6:00 >= 450, 7:00 >= 750)
##  [farms]    a Hard Crown on the Timing attack against a Hard Clockwork (the Springer timing): on one hall by default,
##             "bo_clock1" (cinder-crown-ai: its second hall behind the army; the two-hall opening is `-- crcw:twohall`), LABS_MIN labourers at LABS_AT (the Farms before "the army first") and
##             its natural's soil worked
##  [guns]     a Field Cannon by LABS_AT (the guns get the horses)
##  [bank]     the Clockwork's Springer timing keeps less than BANK_MAX cogs in the bank at 4:30-5:30 (before: 1,186 at 5:00)
##  [brood]    against the Brood the Timing attack opens as before ("bo"), no "bank works" line for the Clockwork against it
const LABS_AT := 600.0
const LABS_MIN := 24
const BANK_MAX := 700
var fails := 0
var main: Node
var g: Game
var cr: AICrown
var cw: AIClockwork
var map := "greenhold"
var seed_ := 1101


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
	while g.clock < until:
		await physics_frame


func _start(foe: String, foe_plan: String) -> void:
	if main != null:
		main.queue_free()
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(seed_)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "timing"},
		{"who": "hard", "faction": foe, "colour": 1, "side": 1, "strategy": foe_plan}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
		g.hud.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	cr = null
	cw = null
	for a in g.ais:
		if a is AICrown:
			cr = a
		elif a is AIClockwork:
			cw = a


func _table() -> void:
	var pl: Dictionary = AICrown.PLANS["timing"]
	var bo: Array = pl.get("bo_clock", [])
	var dos := ["wall_cottage", "wall_gate", "build", "army", "labs", "hall", "attack"]
	var bad: Array = []
	var hall := false
	var foundry_i := -1
	var b2_i := -1
	for i in bo.size():
		var st: Dictionary = bo[i]
		if not dos.has(String(st["do"])):
			bad.append(str(st))
		if String(st["do"]) == "hall":
			hall = true
		if String(st["do"]) == "build" and String(st["k"]) == "foundry" and foundry_i < 0:
			foundry_i = i
		if String(st["do"]) == "build" and String(st["k"]) == "barracks" and int(st.get("n", 1)) >= 2 and b2_i < 0:
			b2_i = i
	check(not bo.is_empty() and bad.is_empty() and hall, "[table] the Timing attack's opening against the Clockwork is well formed and lays the second hall %s" % str(bad))
	check(foundry_i >= 0 and b2_i > foundry_i, "[table] the Foundry before the second Barracks (steps %d, %d)" % [foundry_i, b2_i])
	check(int(pl.get("labs_clock", 0)) >= 30, "[table] the labourers for two halls' Farms (labs_clock %d)" % int(pl.get("labs_clock", 0)))
	# (the switch for the two-hall opening is read at start-up; off by default)


func _reckon() -> void:
	var tab: Array = AIClockwork.CwArmy.TABLES["crown"]
	var a: float = AIClockwork.CwArmy.table_at(tab, 360.0)
	var b: float = AIClockwork.CwArmy.table_at(tab, 420.0)
	check(a >= 450.0 and b >= 750.0, "[reckon] a Hard Crown reckoned at 6:00 %d, 7:00 %d" % [int(a), int(b)])


func _natural() -> Building:
	for h in cr._halls():
		if h.built and h != cr.main_hall():
			return h
	return null


func _two() -> void:
	await _start("clockwork", "springer")
	check(cr != null and cw != null, "(set-up) a Crown and a Clockwork computer")
	if cr == null or cw == null:
		return
	check(cr.cc_vs_clock() and cw.cc_vs_crown(), "(set-up) each knows the matchup")
	var bank_worst := 0
	var labs10 := 0
	var nat_soil := -1.0
	var guns := 0
	var nat_t := -1.0
	while g.clock < LABS_AT + 2.0 and not g.over:
		await wait(2.0)
		if nat_t < 0.0 and _natural() != null:
			nat_t = g.clock
		if g.clock >= 270.0 and g.clock <= 330.0:
			bank_worst = maxi(bank_worst, cw._free())
		guns = maxi(guns, g.army(0).filter(func(u: Unit) -> bool: return u.kind == "cannon").size())
	labs10 = g.workers(0).size() + g.haulers_of(0).size()      # (as the match log counts them: the haulers too)
	var nat := _natural()
	if nat != null:
		nat_soil = nat.soil_left()
	if OS.get_cmdline_user_args().has("log"):
		for l in g.mlog.lines:
			print("LOG ", l)
	# (cinder-crown-ai: the one-hall opening is "bo_clock1" now: the second hall behind the army by 4:30; `-- cinder:off` "bo")
	check(cr._cc_bo == ("bo_clock1" if cr.ck_on else "bo") or cr.cc_two, "[farms] the Timing attack opens on one hall by default (%s)" % cr._cc_bo)
	check(g.over or labs10 >= LABS_MIN, "[farms] %d labourers at %d:00 (wants %d; the Timing games had 19-22 at 10:00)" % [labs10, int(LABS_AT / 60.0), LABS_MIN])
	check(nat == null or nat_t > LABS_AT - 180.0 or nat_soil < 0.995, "[farms] a natural standing by %d:00 is worked (stood at %d, %d%% left)" % [int(LABS_AT / 60.0) - 3, int(nat_t), int(nat_soil * 100.0)])
	check(guns >= 1, "[guns] a Field Cannon by %d:00 (most %d)" % [int(LABS_AT / 60.0), guns])
	check(bank_worst < BANK_MAX, "[bank] the Springer timing's free cogs at 4:30-5:30 stay under %d (worst %d)" % [BANK_MAX, bank_worst])


func _brood() -> void:
	await _start("brood", "balanced")
	await wait(20.0)
	check(cr != null and cr._cc_bo == "bo", "[brood] against the Brood the Timing attack opens as before (%s)" % (cr._cc_bo if cr else "?"))
	check(cr != null and not cr.cc_vs_clock(), "[brood] the matchup's rules are off against the Brood")


func _run() -> void:
	_table()
	_reckon()
	await _two()
	await _brood()
	print("test_crcw_coach: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
