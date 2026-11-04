extends SceneTree
## THE BAR STACK (bars audit, 2026-11-04; docs/bars_audit.md): every bar, label and badge over a building or a rooted
## Brood creature stands ABOVE its picture, close to it, each in its own row.
##   xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 30 --script res://tools/test_bars_audit.gd
## (a display is needed only for the pictures' sizes; --headless works too)
##  1. Crown and Clockwork (gear mode): every kind of the build list, finished and hurt, and a site: Building.sprite_top is
##     the picture's real top (its first painted row; the Farm's sails, the turret's head), the health bar's bottom edge
##     is above it by at most CLOSE px, and the work bar, the coil gauge, the worker label (WorkerLabels.layout's plate),
##     the gear badge and the padlock each sit above the one below, none overlapping;
##  2. the Mainspring's coil: its spring shortens as the side's Tension rises (empty longest, full shortest);
##  3. the Brood: the Mother rooted at stages 1, 2 and 3 (grown where she is, as in a match), a Rootmaw on her swamp, a
##     Mound Turtle and the three Sires: the health bar just above the picture's top (BroodRoot.strip_top), close to it;
##     the egg line, the Sires' lines and the Rootmaw's label above it; the Mother's bar does not move while she lays.
## Prints PASS / FAIL lines and "bars_audit: N failures".
var main: Node
var g
var t := 0.0
var started := false
var fails := 0
var phase := 0
const CLOSE := 9.0          # px: the most a health bar may float above its picture (the gap, and TOP_SLACK)
const BROOD_CLOSE := 9.0    # (the gap, and the TOP_SLACK a picture a little lower keeps)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _faction() -> String:
	return ["crown", "clockwork", Defs.BROOD_NEW][phase]


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "dune_sea", "seed": 5, "slots": [
			{"who": "you", "faction": _faction(), "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown" if phase != 0 else "clockwork", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.6:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL  " + what)
	return


func pass_line(what: String) -> void:
	print("PASS  " + what)


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func _clear_spot(w: int, h: int) -> Vector2i:
	var mid := Vector2i(Game.W / 2 - w / 2, Game.H / 2 - h / 2)
	var best := Vector2i(10, 10)
	var bd := INF
	for y in range(1, Game.H - h - 1, 2):
		for x in range(1, Game.W - w - 1, 2):
			var c := Vector2i(x, y)
			var dd := Vector2(c - mid).length()
			if dd >= bd:
				continue
			var ok := true
			for yy in h:
				for xx in w:
					var cc := c + Vector2i(xx, yy)
					if not g._walkable(cc) or not g.is_free(cc) or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != g.height[g.idx(c)]:
						ok = false
						break
				if not ok:
					break
			if ok:
				bd = dd
				best = c
	return best


func _run() -> void:
	await wait(0.3)
	g.reveal = true
	if phase < 2:
		await _buildings()
	else:
		await _brood()
	phase += 1
	if phase < 3:
		# the next faction: a fresh match
		main.game.queue_free()
		main.game = null
		started = false
		t = 0.0
		return
	print("bars_audit: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## The first painted row of a texture (independent of Game._tex_top).
func _img_top(tex: Texture2D) -> float:
	var img := tex.get_image()
	if img == null:
		return 0.0
	if img.is_compressed():
		img.decompress()
	return float(img.get_used_rect().position.y)


func _buildings() -> void:
	var f := _faction()
	var kinds: Array = Defs.build_list(f)
	var o := _clear_spot(64, 34)
	var x := 2
	var y := 4
	var rowh := 0
	var placed: Array = []
	for k in kinds + [kinds[1]]:
		var sz: Vector2i = Defs.BUILDINGS[k]["size"]
		if x + sz.x > 62:
			x = 2
			y += rowh + 5
			rowh = 0
		var site := placed.size() == kinds.size()
		var b: Building = g._add_building(k, g.human, o + Vector2i(x, y), not site)
		if site:
			b.progress = 0.4
		placed.append(b)
		x += sz.x + 4
		rowh = maxi(rowh, sz.y)
	await process_frame
	if g.gear_net:
		g.gear_net.solve()
	for b in placed:
		if b.built:
			b.hp = b.max_hp * 0.6
	await wait(1.0)
	g.camera.position = Vector2((o.x + 32) * Defs.TILE, (o.y + 17) * Defs.TILE)
	g.camera.zoom = Vector2(0.4, 0.4)
	await process_frame
	g.update_view_rect()
	var bad := 0
	for b in placed:
		var n0 := fails
		var nm := "%s %s%s" % [f, b.kind, "" if b.built else " (site)"]
		var s: Dictionary = b.bar_slots()
		var top := float(s["top"])
		# the picture's real top
		if b.sprite and b.sprite.texture and b.kind != "farm":
			var real: float = b.sprite.position.y + (b.full_offset().y + _img_top(b.sprite.texture)) * b.sprite.scale.y
			if b.turret and b.turret.head.visible and b.turret.head.texture:
				real = minf(real, b.turret.head.position.y - b.turret.head.texture.get_height() * 0.5 + _img_top(b.turret.head.texture))
			check(top <= real + 0.5 and top >= real - Building.TOP_SLACK - 0.5, "%s: the stack starts at the picture's top (%.0f, the picture %.0f)" % [nm, top, real])
		var w := float(s["w"])
		var h := Entity.BAR_H_BIG if w > Entity.BAR_BIG_W else Entity.BAR_H
		var hp_b := float(s["hp"]) + h + 1.0
		check(hp_b <= top and hp_b >= top - CLOSE, "%s: the health bar just above the picture (its bottom %.0f, the top %.0f)" % [nm, hp_b, top])
		var below := float(s["hp"]) - 1.0          # (the top edge of what is under the next row)
		if s.has("work"):
			check(float(s["work"]) + Building.WORK_H + 1.0 <= below, "%s: the work bar above the health bar" % nm)
			below = float(s["work"]) - 1.0
		elif not b.built or b.kind == "farm" or not (b.d.get("trains", []) as Array).is_empty():
			check(false, "%s: keeps a row for its work bar" % nm)
		if b.kind == "mainspring" and Defs.gear_mode:
			check(s.has("coil"), "%s: has a coil gauge row" % nm)
			if s.has("coil"):
				check(float(s["coil"]) + CoilGauge.H + 1.0 <= below, "%s: the coil gauge above the bars" % nm)
				below = float(s["coil"]) - 1.0
		check(float(s["label"]) <= below, "%s: the worker label's row above the bars" % nm)
		var L: Dictionary = WorkerLabels.layout(g, b)
		if not L.is_empty():
			var lr: Rect2 = L["rect"]
			var lb: float = lr.end.y - b.global_position.y
			check(absf(lb - float(s["label"])) < 0.6, "%s: the worker label's plate on its row (%.1f, the row %.1f)" % [nm, lb, float(s["label"])])
			check(lb <= below, "%s: the worker label above the bars and gauge" % nm)
			check(float(s["badge"]) <= lr.position.y - b.global_position.y, "%s: the gear badge's row above the worker label" % nm)
		check(float(s["lock"]) <= float(s["badge"]), "%s: the padlock's row on top" % nm)
		if fails > n0:
			bad += 1
	if bad == 0:
		pass_line("%s: every building's bars stand above its picture, close, one row each (%d buildings)" % [f, placed.size()])
	if f == "clockwork":
		await _coil()


func _coil() -> void:
	var l0 := CoilGauge.length(67.0, 0.0)
	var l5 := CoilGauge.length(67.0, 0.5)
	var l1 := CoilGauge.length(67.0, 1.0)
	check(l0 > l5 and l5 > l1 and l1 >= float(CoilGauge.TURNS) * CoilGauge.TIGHT - 0.01, "the coil presses as Tension rises (%.0f / %.0f / %.0f px)" % [l0, l5, l1])
	var sp: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == "mainspring" and b.built:
			sp = b
	if sp:
		var cap := GearEcon.tension_cap(g, g.human)
		g.players[g.human]["tension"] = cap * 0.5
		await wait(2.0)
		check(absf(sp._coil_f - 0.5) < 0.02, "the coil gauge reads the side's Tension of its store (%.2f at half)" % sp._coil_f)
		check(sp.coil_shown(), "the owner sees the coil gauge")
	if fails == 0:
		pass_line("the Mainspring's coil gauge presses with Tension")


## Rooted as a match roots it (cmd_deploy); where that spot is refused (a neighbour too close), set rooted in place.
func _hand_root(list: Array) -> void:
	for u in list:
		if u.tesla_mode != "packed":
			continue
		u.facing = BroodNew.SE
		u.position = BroodRoot.snap(u.kind, u.position, BroodRoot.scale_of(u))
		u.tesla_mode = "deployed"
		u.nb["m"] = "deployed"
		BroodRoot.footprint_on(g, u, false)
		if u.kind == BroodNew.MAW:
			BroodNew._claim(g, u)
			u.nb["food"] = 90.0
		BroodNew.recount(g, u.team)


func _brood() -> void:
	for u in g.units.duplicate():
		if u.team == g.human:
			g.consume_unit(u)
	var o := _clear_spot(64, 24)
	var kinds: Array = [BroodNew.QUEEN, BroodNew.QUEEN, BroodNew.QUEEN, BroodNew.MAW, BroodNew.TURTLE, BroodNew.FATHER, BroodNew.DILO, BroodNew.PTERO]
	var xs := [6.0, 25.0, 44.0, 11.0, 14.0, 30.0, 50.0, 60.0]
	var ys := [9.0, 9.0, 9.0, 9.0, 20.0, 20.0, 20.0, 20.0]
	var us: Array = []
	for i in kinds.size():
		var u: Unit = g._add_unit(kinds[i], g.human, Vector2((o.x + xs[i]) * Defs.TILE, (o.y + ys[i]) * Defs.TILE))
		u.cmd_hold()
		us.append(u)
	g.camera.position = Vector2((o.x + 32) * Defs.TILE, (o.y + 12) * Defs.TILE)
	g.camera.zoom = Vector2(0.4, 0.4)
	await process_frame
	g.update_view_rect()
	for i in 3:
		us[i].cmd_deploy()
	await wait(9.0)
	_hand_root(us.slice(0, 3))
	g.swamp_dirty = true
	await wait(4.0)
	for u in us.slice(3):
		u.cmd_deploy()
	await wait(1.0)
	_hand_root(us.slice(3))
	g.players[g.human]["gold"] = 99999
	g.players[g.human]["res2"] = 99999
	for step in 2:
		for i in range(step + 1, 3):
			if BroodNew.grow(g, us[i]) == "":
				us[i].nb["grow_t"] = 0.3
		await wait(2.0)
	await wait(6.0)
	for u in us:
		u.hp = u.max_hp * 0.6
	# the Mothers lay: the bar must not move
	var lo := [0.0, 0.0, 0.0]
	var hi := [-1e9, -1e9, -1e9]
	for k in 2:
		for i in 3:
			us[i].nb["eggs"] = maxi(int(us[i].nb.get("eggs", 0)), 4)
			BroodNew.lay(g, us[i], "grub")
		for fr in 90:
			await process_frame
			for i in 3:
				var bt: float = us[i].bar_top()
				lo[i] = minf(lo[i], bt)
				hi[i] = maxf(hi[i], bt)
	await wait(1.0)
	var bad := 0
	for i in us.size():
		var u: Unit = us[i]
		var n0 := fails
		var nm := "%s%s" % [u.kind, (" stage %d" % (BroodNew.stage(u) + 1)) if u.kind == BroodNew.QUEEN else ""]
		check(u.tesla_mode == "deployed", "%s: rooted (%s)" % [nm, u.tesla_mode])
		var st := BroodRoot.strip_top(u) - u.position.y
		var cur := BroodRoot.body_rect(u).position.y - u.position.y
		var top: float = u.bar_top()
		var bw := maxf(u.radius * 2.0, 16.0)
		var h := Entity.BAR_H_BIG if bw > Entity.BAR_BIG_W else Entity.BAR_H
		var hb := top + h + 1.0
		check(hb <= st and hb <= cur, "%s: the health bar above its picture (its bottom %.0f, the strip's top %.0f, now %.0f)" % [nm, hb, st, cur])
		check(hb >= st - BROOD_CLOSE, "%s: the health bar close to its picture (its bottom %.0f, the top %.0f)" % [nm, hb, st])
		var s: Dictionary = BroodNew.stack(u, top)
		var below := top - 1.0 - ((Entity.SUB_H + 1.0) if u.has_attack() else 0.0)
		for key in ["food", "ground", "nest"]:
			if s.has(key):
				check(float(s[key]) + 3.5 <= below, "%s: its %s bar above the health bar" % [nm, key])
				below = float(s[key]) - 0.5
		if s.has("text"):
			check(float(s["text"]) <= below, "%s: its line above its bars" % nm)
		if u.kind == BroodNew.QUEEN:
			var er := EggTip.label_rect(u)
			check(er.end.y - EggTip.HIT_GROW - u.position.y <= below + 0.5, "%s: the egg line above her health bar" % nm)
			check(hi[i] - lo[i] < 0.5, "%s: her bar stays put while she lays (%.0f..%.0f)" % [nm, lo[i], hi[i]])
		if u.kind == BroodNew.MAW:
			var L: Dictionary = WorkerLabels.layout(g, u)
			if not L.is_empty():
				var lr: Rect2 = L["rect"]
				check(lr.end.y - u.position.y <= below + 0.5 - (3.5 if s.has("dry") else 0.0), "%s: its worker label above its bars" % nm)
				check(float(s["prog"]) + 6.0 <= lr.position.y - u.position.y, "%s: the progress bar's row above its label" % nm)
		if fails > n0:
			bad += 1
	if bad == 0:
		pass_line("brood: the rooting creatures' bars stand just above their pictures (the Mother at stages 1-3 too), one row each")
