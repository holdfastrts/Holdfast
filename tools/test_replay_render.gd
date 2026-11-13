extends SceneTree
## Every unit kind is DRAWN when a replay is watched (docs/replay_render.md, the owner's Mirewood playtest 2026-11-13:
## the Brood's Raptors showed only their bars and pink spikes in the replay):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/test_replay_render.gd \
##     [-- rec:full|light|mixed a:<faction> b:<faction> map:<id> shots:<dir>]
## Two Hard computers play while the replay is recorded; at 20 s one of every unit kind of each side's faction is put
## near the middle and sent at the enemy's hall (a fight with every kind in it, many in their attack, leap, charge
## strips). At 40 s the match is ended and its replay watched (Main.start_replay, the viewer as a player sees it), at
## 40 s and again after playing on for 2 s. For every living unit in the viewer:
##   - its sprite is shown (visible in the tree, scale, alpha), has a strip of assets/units/, and the strip's frame
##     size is the art's cell (a wrong hframes shows a sliver of the strip);
##   - its body is really drawn: the unit's own pixels (with and without its sprite, two pictures, compared round it)
##     differ (headless runs skip this check: nothing is drawn).
## shots:<dir> writes the viewer's pictures (one per kind, close up) there.
var main: Node
var g: Game
var stage := "play"
var rec_mode := "full"
var fa := "crown"
var fb := "brood"
var map := "mirewood"
var seed_ := 766992866
var shots := ""
var failed := 0
var t := 0.0
var _spawned := false
var _kinds := {}            # kind -> true: what was spawned
var _live := {}             # kind -> [anim names seen in the match]
var _busy := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("rec:"):
			rec_mode = a.substr(4)
		elif a.begins_with("a:"):
			fa = a.substr(2)
		elif a.begins_with("b:"):
			fb = a.substr(2)
		elif a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("shots:"):
			shots = a.substr(6)
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		failed += 1
	print("CHECK %s %s %s" % [name, "OK" if ok else "FAILED", detail])


func live_kind(k: String) -> bool:
	if Defs.retired(k):
		return false
	var d: Dictionary = Defs.UNITS[k]
	if Defs.cw_roster == false and Defs.CW_KINDS.has(k):
		return false
	if d.get("faction", "") == "brood" and not (BroodNew.hatch_list().has(k) or BroodNew.KINDS.has(k) \
			or (Defs.NB["mature"] as Dictionary).values().has(k) or k in ["grub"]):
		return false
	return ArtData.UNITS.has(Defs.art_for(k, false)) or ArtData.UNITS.has(k)


func _process(delta: float) -> bool:
	t += delta
	if _busy:
		return false
	match stage:
		"play":
			_play()
		"watch":
			_busy = true
			_watch()
	return false


func _hall(tm: int) -> Building:
	for b in g.buildings:
		if b.team == tm and b.kind == g.faction_hall(tm) and not b.dead:
			return b
	return null


func _spawn() -> void:
	var mid := Vector2(Game.W, Game.H) * Game.T * 0.5
	g.input_cmd = true
	for tm in 2:
		var fac := g.faction_of(tm)
		var home := _hall(tm)
		var foe := _hall(1 - tm)
		var c: Vector2 = mid.lerp(home.center(), 0.3) if home else mid
		var i := 0
		for k in Defs.UNITS:
			if String(Defs.UNITS[k].get("faction", "")) != fac or not live_kind(k):
				continue
			_kinds[k] = true
			for j in 3:
				# (three of each: one stands, two go at the enemy's hall)
				var cell := g.nearest_free(g.cell_of(c + Vector2.from_angle(i * 0.9) * (60.0 + 10.0 * i)), 12)
				var u: Unit = g._add_unit(k, tm, g.cell_center(cell))
				i += 1
				if foe and u.has_attack() and j > 0:
					u.cmd_move(foe.center(), true)
	g.input_cmd = false
	print("SPAWNED %d kinds: %s" % [_kinds.size(), ", ".join(PackedStringArray(_kinds.keys()))])


func _play() -> void:
	if t > 0.2 and main.game == null:
		seed(seed_)
		Settings.replay_rec = rec_mode
		ReplayFile.ensure_dir()
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": fa, "colour": 0, "side": 0, "strategy": "rush"},
			{"who": "hard", "faction": fb, "colour": 3, "side": 1, "strategy": "rush"}]})
		Engine.time_scale = 4.0
		return
	if main.game == null:
		return
	g = main.game
	paused = false
	if not _spawned and g.clock >= 20.0:
		_spawned = true
		_spawn()
	if _spawned:
		for u in g.units:
			if is_instance_valid(u) and not u.dead and _kinds.has(u.kind):
				var seen: Array = _live.get(u.kind, [])
				if not seen.has(u.anim):
					seen.append(u.anim)
				_live[u.kind] = seen
	if g.clock >= 34.0 or g.over:
		Engine.time_scale = 1.0
		g.rec.finish(g.winner if g.over else -1)
		var newest: Dictionary = ReplayFile.list()[0]
		print("RECORDED %s (%s), %.1f s" % [String(newest["path"]).get_file(), rec_mode, g.clock])
		main._to_menu()
		main.start_replay(String(newest["path"]))
		stage = "watch"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()


func _units() -> Array:
	var out: Array = []
	for u in g.units:
		if is_instance_valid(u) and not u.dead and not u.off_field and u.aboard == null and u.is_visible_in_tree():
			out.append(u)
	return out


func _watch() -> void:
	await _frames(10)
	g = main.game
	var drawn := DisplayServer.get_name() != "headless"
	var rp = g.replay
	check("viewer_started", rp != null, "rec %s: %s" % [rec_mode, str(rp)])
	if rp == null:
		_end()
		return
	var at: float = maxf(float(rp.length) - 8.0, 1.0)
	rp.seek(at)
	rp.set_playing(true)
	for round_i in 2:
		await _frames(4 if round_i == 0 else 1)
		if round_i == 1:
			var c0: float = g.clock
			var f0 := 0
			while g.clock < c0 + 2.0 and f0 < 600:
				f0 += 1
				await process_frame
		_check_units("t%d" % round_i, drawn)
		if drawn:
			await _pixel_checks("t%d" % round_i)
	_end()


## The sprite of every unit in the viewer: shown, the right strip, the frame size of its art.
func _check_units(tag: String, drawn: bool) -> void:
	var bad := {}
	var n := 0
	for u in _units():
		n += 1
		var s: Sprite2D = u.sprite
		var why := ""
		var asc := float(u.d.get("art_scale", 1.0))
		if s == null or not s.is_visible_in_tree():
			why = "sprite hidden"
		elif s.texture == null:
			why = "no texture"
		elif not s.texture.resource_path.begins_with("res://assets/units/"):
			why = "strip %s" % s.texture.resource_path
		elif absf(s.scale.x) < 0.5 * asc or s.scale.y < 0.5 * asc:
			why = "scale %s" % str(s.scale)
		elif u.modulate.a * s.modulate.a * s.self_modulate.a < 0.3:
			why = "alpha %.2f" % (u.modulate.a * s.modulate.a * s.self_modulate.a)
		else:
			var sa := String(u._anim_art) if u._anim_art != "" else String(u.art)
			if ArtData.UNITS.has(sa):
				var cell: Vector2i = ArtData.UNITS[sa]["cell"]
				var fw := s.texture.get_width() / maxi(s.hframes, 1)
				if absi(fw - cell.x) > 1:
					why = "frame %d px wide (hframes %d of a %d px strip %s), the art's cell is %d" % [fw, s.hframes, s.texture.get_width(), s.texture.resource_path.get_file(), cell.x]
				elif s.frame >= s.hframes * s.vframes:
					why = "frame %d of %d" % [s.frame, s.hframes]
		if why != "":
			bad[u.kind] = "%s (%s)" % [why, u.anim]
	check("%s_sprites" % tag, bad.is_empty(), "%d units; wrong: %s" % [n, str(bad)])


## One unit of each kind on screen: the picture with its sprite and without it differ round it (its body is drawn).
func _pixel_checks(tag: String) -> void:
	var by_kind := {}
	for u in _units():
		if not by_kind.has(u.kind):
			by_kind[u.kind] = u
	var none: Array = []
	var cam: Camera2D = g.camera
	rp_pause(true)
	for k in by_kind:
		var u: Unit = by_kind[k]
		if not is_instance_valid(u) or u.dead:
			continue
		if u._k_nb and (u.nb as Dictionary).has("fpx"):
			continue          # (a rooted Brood creature is drawn in the building layer: BroodNew.draw)
		cam.position = u.global_position
		cam.zoom = Vector2(2.0, 2.0)
		await _frames(2)
		var vr := root.get_viewport().get_canvas_transform() * u.sprite.get_global_transform() * u.sprite.get_rect()
		vr = vr.abs().intersection(Rect2(Vector2.ZERO, root.get_viewport().get_visible_rect().size))
		var with := await _shot()
		u.sprite.visible = false
		await _frames(1)
		var without := await _shot()
		u.sprite.visible = true
		var vis := root.get_viewport().get_visible_rect().size
		var c := Vector2i(with.get_size() / 2)
		var k2 := Vector2(with.get_size()) / vis
		vr = Rect2(vr.position * k2, vr.size * k2)
		var diff := 0
		for y in range(int(vr.position.y), mini(int(vr.end.y), with.get_height())):
			for x in range(int(vr.position.x), mini(int(vr.end.x), with.get_width())):
				var a := with.get_pixel(x, y)
				var b := without.get_pixel(x, y)
				if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.15:
					diff += 1
		if diff < 40:
			none.append("%s (%d px, %s)" % [k, diff, u.anim])
		if shots != "":
			DirAccess.make_dir_recursive_absolute(shots)
			var img := with.get_region(Rect2i(c - Vector2i(160, 120), Vector2i(320, 200)))
			img.save_png(shots.path_join("%s_%s_%s.png" % [rec_mode, tag, k]))
	rp_pause(false)
	check("%s_bodies_drawn" % tag, none.is_empty(), "%d kinds looked at; no body: %s" % [by_kind.size(), str(none)])


func rp_pause(on: bool) -> void:
	if g.replay:
		g.replay.set_playing(not on)


func _end() -> void:
	print("LIVE ANIMS ", _live)
	print("ALL OK" if failed == 0 else "SOME FAILED (%d)" % failed)
	quit(0 if failed == 0 else 1)
