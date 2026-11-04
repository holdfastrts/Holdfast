extends SceneTree
## THE DRAGOON RAIDS (crown-builds-a: the Crown computer's plan "dragoon", scripts/ai_crown.gd + scripts/ai_dragoon_raid.gd,
## docs/crown_builds_a.md).
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_dragoon_raid.gd
##  [table]   the plan is there, well formed, and only the Crown may pick it (AI.strategies_for)
##  [strike]  a group of four Dragoons sent to grubs working a rooted Rootmaw (a rooted Mound Turtle on the way in, the
##            Brood's computer off): within STRIKE_IN s the grubs are hurt (GRUB_LOSS hit points or more), the riders got
##            off to shoot, and never set about the turtle or the Rootmaw
##  [leave]   a Tyrant Sire comes at them: within LEAVE_IN s the group rides off (its state "leave" or "home") with the
##            riders back in the saddle by MOUNT_IN s (all but one at most: a horse may have wandered); LIVE_MIN of the four
##            still alive after 20 s
##  [plan]    a Hard Crown on the plan against a Brood that stands still: the Horse Breeder and the second hall by 6:00,
##            four Dragoons or more and a group out (it formed and rode for a site) by PLAN_BY (the Brood's army never comes
##            out here: the group goes after BROOD_WAIT s at home)
##  [others]  the Balanced plan has no raids (no DragoonRaid made)
const STRIKE_IN := 45.0
const GRUB_LOSS := 80.0
const LEAVE_IN := 6.0
const MOUNT_IN := 8.0
const LIVE_MIN := 3
const PLAN_BY := 690.0
const T := Defs.TILE
var fails := 0
var main: Node
var g: Game
var ai: AICrown
var q: Unit
var maw: Unit
var turtle: Unit
var grubs: Array = []
var dir := Vector2.ZERO


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func wait(s: float) -> void:
	var until := g.clock + s
	while g.clock < until:
		await physics_frame


func _start(strategy: String, map: String, seed_: int) -> void:
	if main != null:
		main.queue_free()
		await process_frame
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(seed_)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": strategy},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "economy"}]})
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


func _table() -> void:
	check(AICrown.PLANS.has("dragoon") and AI.STRATEGIES.has("dragoon"), "[table] the plan \"dragoon\" is there (AICrown.PLANS, AI.STRATEGIES)")
	var bad: Array = []
	var pl: Dictionary = AICrown.PLANS.get("dragoon", {})
	for st in pl.get("bo", []):
		if not (String(st["do"]) in ["wall_cottage", "wall_gate", "build", "army", "labs", "hall", "attack"]):
			bad.append(str(st))
		if String(st["do"]) == "build" and not Defs.BUILDINGS.has(String(st["k"])):
			bad.append(str(st))
	for m in pl.get("mid", []):
		if not Defs.BUILDINGS.has(String(m[0])):
			bad.append(str(m))
	check(bad.is_empty() and pl.has("raid"), "[table] its build order and milestones are well formed %s" % ("" if bad.is_empty() else str(bad)))
	check(AI.strategies_for("crown").has("dragoon") and not AI.strategies_for("brood").has("dragoon") and not AI.strategies_for("clockwork").has("dragoon"),
		"[table] only the Crown may pick it")


## A spot near p where a `k` of the Brood's may root.
func _root_spot(k: String, p: Vector2, swamp: bool) -> Vector2:
	for r in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]:
		for i in 16:
			var sp: Vector2 = BroodRoot.snap(k, p + Vector2.from_angle(TAU * i / 16.0) * r * T)
			if BroodRoot.place_problem(g, 1, k, sp, null, false, 1.0, swamp) == "":
				return sp
	return p


func _free(p: Vector2) -> Vector2:
	var c := g.cell_of(p)
	for r in 8:
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var m := Vector2i(x, y)
				if g.in_map(m) and g._walkable(m):
					return (Vector2(m) + Vector2(0.5, 0.5)) * T
	return p


## A walkable spot about `tiles` from p on p's own level (the riders must see the site: no sight up a cliff).
func _level(p: Vector2, tiles: float) -> Vector2:
	var h: int = g.height[g.idx(g.cell_of(p))]
	for r in [tiles, tiles - 1.0, tiles + 1.0, tiles - 2.0, tiles + 2.0]:
		for i in 24:
			var c := g.cell_of(p + Vector2.from_angle(TAU * i / 24.0 + dir.angle()) * r * T)
			if g.in_map(c) and g._walkable(c) and g.height[g.idx(c)] == h:
				return (Vector2(c) + Vector2(0.5, 0.5)) * T
	return _free(p + dir * tiles * T)


func _grub_loss() -> float:
	var lost := 0.0
	for gr in grubs:
		lost += gr.max_hp if (not is_instance_valid(gr) or gr.dead) else gr.max_hp - gr.hp
	return lost


func _brood_line() -> void:
	q = BroodNew.queen(g, 1)
	dir = (g.center_of_team(0) - q.position).normalized()
	var side := dir.orthogonal()
	turtle = g._add_unit(BroodNew.TURTLE, 1, _root_spot(BroodNew.TURTLE, q.position + dir * 15.0 * T, false))
	turtle.cmd_deploy()
	await wait(float(Defs.NB["turtle_switch"]) + 6.0)
	maw = g._add_unit(BroodNew.MAW, 1, _root_spot(BroodNew.MAW, turtle.position - dir * 6.0 * T + side * 5.0 * T, true))
	maw.cmd_deploy()
	await wait(float(Defs.NB["turtle_switch"]) + 1.0)
	grubs.clear()
	for i in 4:
		var gr: Unit = g._add_unit("grub", 1, _free(maw.position - dir * 2.0 * T + side * float(i - 2) * 20.0))
		gr.cmd_gather(maw)
		grubs.append(gr)
	await wait(2.0)


func _run() -> void:
	_table()
	# [strike] / [leave]
	await _start("dragoon", "greenhold", 7)
	check(ai != null and ai.dragoon_plan(), "(set-up) the Crown computer plays the Dragoon raids")
	if ai == null:
		_end()
		return
	ai.peaceful = true                 # (its own army stays at home; the raid is driven by hand below)
	await wait(1.0)
	await _brood_line()
	var DR = AICrown.DragoonRaid
	var dr = DR.new(ai)
	ai.dr = dr
	var party: Array = []
	var start := _level(maw.position, 7.0)
	for i in 4:
		var u: Unit = g._add_unit("dragoon", 0, _free(start + dir.orthogonal() * float(i - 2) * 24.0))
		party.append(u)
	# (the site seen: the Rootmaw in sight of the riders)
	await wait(1.0)
	dr._look_t = -99.0
	dr._look()
	var key := "u%d" % maw.get_instance_id()
	print("   maw %s rooted %s vis %s, riders %s, sites %s" % [maw.position.round(), BroodNew.rooted(maw), g.is_visible_to(0, maw.position), party.map(func(u): return u.position.round()), dr.sites.keys()])
	check(dr.sites.has(key), "(set-up) the riders see the Rootmaw as a site")
	var grp := {"units": party.duplicate(), "state": "ride", "site": key, "t0": g.clock, "t_state": g.clock, "dry_t": 0.0,
		"strikes": 0, "id": 1, "rally": start, "wp": Vector2.INF}
	for u in party:
		dr.member[u] = grp
		dr.ever[u] = true
	dr.groups.append(grp)
	var off := false
	var on_struct := 0
	var frames := 0
	var watched := 0
	var t_end := g.clock + STRIKE_IN
	while g.clock < t_end:
		await physics_frame
		frames += 1
		dr.micro()
		if frames % 30 == 0:
			dr.tick()
			if OS.get_cmdline_user_args().has("trace"):
				print("   t=%.0f %s" % [g.clock, str(party.map(func(u): return "%s/%s/%s/%s" % [u.kind, u.order, u.target.kind if u.target and is_instance_valid(u.target) else "-", u.order_target.kind if u.order_target and is_instance_valid(u.order_target) else "-"] if is_instance_valid(u) and not u.dead else "dead"))])
		for u in party:
			if is_instance_valid(u) and not u.dead:
				if u.kind == "musketeer":
					off = true
				if u.target == turtle or u.target == maw or u.order_target == turtle or u.order_target == maw:
					on_struct += 1
					if on_struct % 60 == 1 and OS.get_cmdline_user_args().has("trace"):
						print("   ON STRUCT %s %s t=%s ot=%s turtle=%s maw=%s" % [u.kind, u.order, u.target, u.order_target, turtle, maw])
		watched += 1
		if _grub_loss() >= GRUB_LOSS * 2.0:
			break
	check(_grub_loss() >= GRUB_LOSS, "[strike] the grubs lost %d hit points or more in %d s (%d)" % [int(GRUB_LOSS), int(STRIKE_IN), int(_grub_loss())])
	check(off, "[strike] the riders got off to shoot")
	check(on_struct <= watched / 10, "[strike] they hardly set about the turtle or the Rootmaw (%d frames of %d)" % [on_struct, watched])
	# [leave]: a Tyrant Sire comes at the nearest rider
	var alive := party.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var near: Unit = alive[0]
	var sire: Unit = g._add_unit(BroodNew.FATHER, 1, _free(near.position + (q.position - near.position).normalized() * 200.0))
	sire.cmd_attack(near)
	var left_t := -1.0
	var mounted_t := -1.0
	var t0 := g.clock
	frames = 0
	while g.clock < t0 + 20.0:
		await physics_frame
		frames += 1
		dr.micro()
		if frames % 30 == 0:
			dr.tick()
			if OS.get_cmdline_user_args().has("trace"):
				print("   t=%.0f %s %s" % [g.clock, String(grp["state"]), str(party.map(func(u): return "%s/%s/%s" % [u.kind, u.order, u.steed.position.distance_to(u.position) if u.steed and is_instance_valid(u.steed) else -1.0] if is_instance_valid(u) and not u.dead else "dead"))])
		var st := String(grp["state"]) if dr.groups.has(grp) else "home"
		if left_t < 0.0 and st in ["leave", "home"] and int(grp["strikes"]) > 0:
			left_t = g.clock - t0
		if left_t >= 0.0 and mounted_t < 0.0:
			var off_n := party.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and u.kind != "dragoon").size()
			var all_up := off_n <= 1        # (one whose horse got away may run for it on foot: Unit's own remount rule)
			if all_up:
				mounted_t = g.clock - t0
	var live := party.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead).size()
	check(left_t >= 0.0 and left_t <= LEAVE_IN, "[leave] the group rides off from the Sire within %d s (%.1f s)" % [int(LEAVE_IN), left_t])
	check(mounted_t >= 0.0 and mounted_t <= MOUNT_IN, "[leave] the riders back in the saddle (all but one at most) within %d s (%.1f s)" % [int(MOUNT_IN), mounted_t])
	check(live >= LIVE_MIN, "[leave] %d of the 4 riders alive after 20 s (%d)" % [LIVE_MIN, live])
	# [plan]
	await _start("dragoon", "red_coast", 4291306512)
	var formed := false
	var rode := false
	var most := 0
	var breeder_t := -1.0
	var hall_t := -1.0
	while g.clock < PLAN_BY:
		await wait(2.0)
		var riders := g.army(0).filter(func(u: Unit) -> bool: return AICrown.DragoonRaid.is_rider(u)).size()
		most = maxi(most, riders)
		if breeder_t < 0.0 and ai._mine("horse_breeder").any(func(b: Building) -> bool: return b.built):
			breeder_t = g.clock
		if hall_t < 0.0 and ai._halls().size() >= 2:
			hall_t = g.clock
		if ai.dr != null:
			formed = formed or int(ai.dr.stats["groups"]) > 0
			rode = rode or ai.dr.log_lines.any(func(e) -> bool: return String(e[1]).contains("rides for"))
	check(breeder_t >= 0.0 and breeder_t <= 360.0 and hall_t >= 0.0 and hall_t <= 360.0, "[plan] the Horse Breeder (%d s) and the second hall (%d s) by 6:00" % [int(breeder_t), int(hall_t)])
	if ai.dr != null and not rode:
		print("   raid log: %s" % str(ai.dr.log_lines.slice(0, 12)))
	check(most >= 4 and formed and rode, "[plan] four Dragoons or more (%d) and a group out by %d s (formed %s, rode %s)" % [most, int(PLAN_BY), str(formed), str(rode)])
	# [others]
	await _start("balanced", "red_coast", 4291306512)
	await wait(300.0)
	check(ai.dr == null and not ai.dragoon_plan(), "[others] the Balanced plan makes no raids")
	_end()


func _end() -> void:
	print("test_crown_dragoon_raid: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
