extends SceneTree
## THE CROWN'S AMMUNITION IN COMPUTER GAMES (crown-ammo, docs/crown_ammo.md): a Hard Crown computer on a plan against a
## Hard Brood or Clockwork computer, headless, to `end` s; one JSON line of numbers to `out` (appended). It runs on main
## too (the counters crown-ammo added read 0 there), so the two can be compared.
##   godot --headless --fixed-fps 30 --script res://tools/play_crown_ammo.gd -- plan:balanced foe:brood map:highmoor \
##       seed:1 end:480 out:/abs/file.jsonl
## Numbers: at 4:00, 6:00 and 8:00 (and the end) the Crown's gold and powder earned, the powder in the bank, its army
## (supply and value, Musketeers), the enemy's army supply; at the end its losses and kills, halls standing, the powder
## spent arming recruits and on refills, recruits out dry / partly armed, blows struck by firearm men with no shot, refill
## errands, and EMPTY-FIGHT man-seconds (sampled each second: a Crown firearm man with 0 shots and an enemy within 200 px,
## a musket's reach; counted the same way on main).
var main: Node
var g: Game
var plan := "balanced"
var foe := "brood"
var map := "highmoor"
var seed_ := 1
var end_t := 480.0
var out := ""
var rec := {}
var _next := 1.0
var empty_s := 0.0
var shots_s := 0.0         # (man-seconds of firearm men in a fight with shots)
var ai: AI
var trace := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"plan": plan = kv[1]
				"foe": foe = kv[1]
				"map": map = kv[1]
				"seed": seed_ = int(kv[1])
				"end": end_t = float(kv[1])
				"out": out = kv[1]
				"trace": trace = kv[1] == "1"
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(seed_)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": plan},
		{"who": "hard", "faction": foe, "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
		g.hud.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	for a in g.ais:
		if a.team == 0:
			ai = a
	rec = {"plan": plan, "foe": foe, "map": map, "seed": seed_, "version": str(ProjectSettings.get_setting("application/config/version", ""))}
	var t0 := Time.get_ticks_msec()
	while g.clock < end_t and not g.over:
		await physics_frame
		if g.clock >= _next:
			_next += 1.0
			_sample()
			if trace and int(g.clock) % 20 == 0:
				_trace()
		for m in [240.0, 360.0, 480.0]:
			if g.clock >= m and not rec.has("m%d" % int(m / 60.0)):
				rec["m%d" % int(m / 60.0)] = _snap()
	rec["end"] = _snap()
	rec["over"] = g.over
	rec["wall_s"] = (Time.get_ticks_msec() - t0) / 1000.0
	var line := JSON.stringify(rec)
	print(line)
	if out != "":
		var f := FileAccess.open(out, FileAccess.READ_WRITE if FileAccess.file_exists(out) else FileAccess.WRITE)
		f.seek_end()
		f.store_line(line)
		f.close()
	quit(0)


## trace:1 a line every 20 s: the bank, the Barracks (armed?, queue), the army by kind (dry ones), attacking.
func _trace() -> void:
	var kinds := {}
	for u in g.army(0):
		var k: String = u.kind + ("(dry)" if _firearm(u) and _shots(u) <= 0 else "")
		kinds[k] = int(kinds.get(k, 0)) + 1
	var bars: Array = []
	for b in g.buildings:
		if b.team == 0 and not b.dead and (b.kind == "barracks" or b.kind == "foundry"):
			bars.append("%s%s%s" % [b.kind.left(3), "" if b.get("arm_powder") == null or b.arm_powder else "(OFF)", str(b.queue)])
	print("%4d gold %d powder %.0f %s army %s attacking %s" % [int(g.clock), int(g.players[0]["gold"]), float(g.players[0]["res2"]), " ".join(bars), str(kinds), str(ai._attacking)])


func _firearm(u: Unit) -> bool:
	return u.kind in ["musketeer", "dragoon", "cuirassier", "dismounted", "cannon", "mortar"]


func _shots(u: Unit) -> int:
	if (Defs.PISTOL["kinds"] as Array).has(u.kind):
		return (1 if u.pistol else 0) + int(u.powder + 0.001)
	return int(u.powder + 0.001)


func _sample() -> void:
	for u in g.army(0):
		if not _firearm(u):
			continue
		var near := false
		for o in g.units_near(u.position, 200.0):
			if g.hostile(o.team, 0) and not o.dead and not o.off_field:
				near = true
				break
		if not near:
			continue
		if _shots(u) <= 0:
			empty_s += 1.0
		else:
			shots_s += 1.0


func _snap() -> Dictionary:
	var st: Dictionary = g.stats[0]
	var army := g.army(0)
	var val := 0.0
	var musk := 0
	var dry_now := 0
	var sup := 0
	for u in army:
		val += float(u.d.get("cost", 0)) + float(u.d.get("cost2", 0))
		sup += int(u.d["supply"])
		if u.kind == "musketeer" or u.kind == "dragoon":
			musk += 1
		if _firearm(u) and _shots(u) <= 0:
			dry_now += 1
	var esup := 0
	for u in g.army(1):
		esup += int(u.d["supply"])
	var halls := 0
	for b in g.buildings:
		if b.team == 0 and not b.dead and b.kind == "town_hall" and b.built:
			halls += 1
	return {"t": int(g.clock), "gold_in": int(st.get("gold", 0)), "powder_in": snappedf(float(st.get("res2_in", 0.0)), 0.1),
		"bank2": snappedf(float(g.players[0]["res2"]), 0.1), "gold": int(g.players[0]["gold"]), "army_sup": sup, "army_val": int(val),
		"musk": musk, "dry_now": dry_now, "foe_sup": esup, "lost": int(st.get("lost", 0)), "killed": int(st.get("killed", 0)),
		"halls": halls, "ammo_powder": snappedf(float(st.get("ammo_powder", 0.0)), 0.1), "refill_powder": snappedf(float(st.get("refill_powder", 0.0)), 0.1),
		"dry_out": int(st.get("dry_out", 0.0)), "partial_out": int(st.get("partial_out", 0.0)), "empty_blows": int(st.get("empty_blows", 0.0)),
		"rearm": int(ai.am.sent) if ai != null and "am" in ai else -1, "empty_s": int(empty_s), "shots_s": int(shots_s),
		"trained": int(st.get("trained", 0))}
