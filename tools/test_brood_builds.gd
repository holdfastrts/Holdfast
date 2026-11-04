extends SceneTree
## THE BROOD'S WRITTEN BUILDS (brood-builds, docs/brood_builds.md; scripts/ai_brood_builds.gd). Three checks, one per run:
##   case:picks   (instant) the lobby offers SPITTER TIMING and BRUTE SIEGE for the Brood only, RANDOM PLAN can pick
##                either, and a Brood computer on each gets its plan and its push (AIBroodNew.bb); the others get none
##   case:timing  a Hard Brood on Spitter timing against a Hard Crown (or foe:clockwork): THE TIMING LANDS: the push
##                leaves between TIMING_FROM and TIMING_BY with at least TIMING_SP Spitters, Long Spit is in by then,
##                it reaches contact, and its economy kept growing (grubs, a turtle on new ground) before it left
##   case:breach  a Hard Brood on Brute siege against a Hard Crown that walls (or foe:clockwork: its turrets): the push
##                leaves with Brutes and Battering Horns by SIEGE_BY, THE BREACH IS MADE (a wall piece, gate or turret
##                broken by the push and the army sent in) by BREACH_BY
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_builds.gd -- case:timing [foe:crown] [map:greenhold] [seed:3]
var main: Node
var t := 0.0
var g
var case_ := "picks"
var foe := "crown"
var map := "greenhold"
var seed_ := 3
var fails := 0
var ai: AIBroodNew
var _grubs_at_go := 0
var _far_at_go := 0
var _long_at_go := false

const TIMING_FROM := 345.0
const TIMING_BY := 540.0
const TIMING_SP := 8
const SIEGE_BY := 720.0
const BREACH_BY := 900.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"case": case_ = kv[1]
			"foe": foe = kv[1]
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _process(delta: float) -> bool:
	t += delta
	if case_ == "picks":
		if t > 0.2:
			_picks()
			print("%d failures" % fails)
			quit()
		return false
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "brood", "colour": 0, "side": 0, "strategy": "spitter" if case_ == "timing" else "brute"},
			{"who": "hard", "faction": foe, "colour": 1, "side": 1, "strategy": "balanced"}]})
		for a in main.game.ais:
			if a is AIBroodNew and a.team == 0:
				ai = a
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if ai.bb != null and ai.bb.pushes.size() > 0 and _grubs_at_go == 0:
		_grubs_at_go = BroodNew.count_of(g, 0, "grub")
		_far_at_go = BroodNew.expansions(g, BroodNew.queen(g, 0)).size() if BroodNew.queen(g, 0) else 0
		_long_at_go = g.has_tech(0, "nb_long_spit")
	var end := TIMING_BY + 90.0 if case_ == "timing" else BREACH_BY
	var done: bool = case_ == "timing" and ai.bb != null and ai.bb.pushes.size() > 0 and float(ai.bb.pushes[0]["contact"]) >= 0.0
	done = done or (case_ == "breach" and ai.bb != null and ai.bb.pushes.any(func(p) -> bool: return float(p["breach"]) >= 0.0))
	if g.clock >= end or g.over or done:
		_report()
		quit()
	return false


func _picks() -> void:
	var b := AI.strategies_for("brood")
	check(b.has("spitter") and b.has("brute"), "the Brood's plans offer Spitter timing and Brute siege (%s)" % str(b))
	check(not AI.strategies_for("crown").has("spitter") and not AI.strategies_for("clockwork").has("brute"), "the Crown and the Clockwork don't get them")
	check(AI.listed_strategies().has("spitter") and AI.listed_strategies().has("brute"), "the lobby's PLAN list has them")
	check(String(AI.STRATEGIES["spitter"]["name"]) == "Spitter timing" and String(AI.STRATEGIES["brute"]["name"]) == "Brute siege", "their names")
	check(tr("Spitter timing") != "" and LangPt.T.has("Spitter timing") and LangEs.T.has("Brute siege"), "their names in pt and es")
	var picked := {}
	var a := AI.new()
	for i in 400:
		picked[a.random_plan(b)] = true
	a.free()
	check(picked.has("spitter") and picked.has("brute"), "RANDOM PLAN can pick either (%d plans picked in 400)" % picked.size())
	for s in ["spitter", "brute", "balanced"]:
		var n := AIBroodNew.new()
		n.strategy = s
		n._make_plan()
		var want: String = s if s != "balanced" else ""
		check(String(n.plan.get("build", "")) == want, "a Brood computer on %s gets build '%s'" % [s, want])
		n.free()
	check(AIStoryLines.PLANS.has("spitter") and AIStoryLines.PLANS.has("brute"), "the AI story tells both plans")
	var m := AIStoryLines.match_line("'s Brood: brute siege: BREACH at 9:12: the Palisade falls and the army goes in through the gap")
	check(not m.is_empty() and String(m["template"]).contains("break through"), "the story tells the breach")


func _report() -> void:
	print("Brood %s against a Hard %s, %s seed %d, at %s:" % ["Spitter timing" if case_ == "timing" else "Brute siege", foe, map, seed_, ai._mmss()])
	for l in (ai.bb.log if ai.bb else []):
		print("  %s %s" % [ai._mmss_of(float(l[0])) if ai.has_method("_mmss_of") else str(int(l[0])), l[1]])
	check(ai.bb != null, "the computer has its build's push")
	if ai.bb == null:
		return
	var p: Dictionary = ai.bb.pushes[0] if ai.bb.pushes.size() > 0 else {}
	if case_ == "timing":
		check(not p.is_empty() and float(p["t0"]) >= TIMING_FROM and float(p["t0"]) <= TIMING_BY,
			"the timing leaves between %d and %d s (at %s)" % [int(TIMING_FROM), int(TIMING_BY), str(int(p["t0"])) if not p.is_empty() else "never"])
		check(not p.is_empty() and int(p["spitters"]) >= TIMING_SP, "with at least %d Spitters (%s)" % [TIMING_SP, str(p.get("spitters", 0))])
		check(_long_at_go or (not p.is_empty() and float(p["t0"]) >= 470.0), "Long Spit is in when it leaves (or it is the late go)")
		check(not p.is_empty() and float(p["contact"]) >= 0.0, "it reaches contact (at %s)" % str(int(p.get("contact", -1))))
		check(_grubs_at_go >= 25 and _far_at_go >= 1, "the economy grew behind it: %d grubs and %d turtles on new ground when it left" % [_grubs_at_go, _far_at_go])
	else:
		check(not p.is_empty() and float(p["t0"]) <= SIEGE_BY and int(p["brutes"]) >= 2,
			"the siege push leaves with Brutes by %d s (%s, %s Brutes)" % [int(SIEGE_BY), str(int(p["t0"])) if not p.is_empty() else "never", str(p.get("brutes", 0))])
		check(g.has_tech(0, "nb_battering_horns"), "Battering Horns researched")
		var br: Array = ai.bb.pushes.filter(func(x) -> bool: return float(x["breach"]) >= 0.0)
		check(not br.is_empty() and float(br[0]["breach"]) <= BREACH_BY, "THE BREACH is made by %d s (%s; broke %s)" % [int(BREACH_BY),
			str(int(br[0]["breach"])) if not br.is_empty() else "never", str(br[0]["broke"]) if not br.is_empty() else str(p.get("broke", {}))])
	print("%d failures" % fails)
