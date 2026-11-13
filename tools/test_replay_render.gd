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
var secs := 230.0
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
		elif a.begins_with("secs:"):
			secs = float(a.substr(5))
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
		var c: Vector2 = mid.lerp(home.center(), 0.8) if home else mid
		var i := 0
		for k in Defs.UNITS:
			if String(Defs.UNITS[k].get("faction", "")) != fac or not live_kind(k):
				continue
			_kinds[k] = true
			for j in 2:
				# (two of each, by their own hall: the computer takes them into its army)
				var cell := g.nearest_free(g.cell_of(c + Vector2.from_angle(i * 0.9) * (60.0 + 10.0 * i)), 12)
				g._add_unit(k, tm, g.cell_center(cell))
				i += 1

	g.input_cmd = false
	print("SPAWNED %d kinds: %s" % [_kinds.size(), ", ".join(PackedStringArray(_kinds.keys()))])


func _play() -> void:
	if t > 0.2 and main.game == null:
		seed(seed_)
		Settings.replay_rec = rec_mode
		ReplayFile.ensure_dir()
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": fa, "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": fb, "colour": 3, "side": 1, "strategy": "rush"}]})
		Engine.time_scale = 8.0
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
	if g.clock >= secs or g.over:
		Engine.time_scale = 1.0
		g.rec.finish(g.winner if g.over else -1)
		var newest: Dictionary = ReplayFile.list()[0]
		print("RECORDED %s (%s), %.1f s" % [String(newest["path"]).get_file(), rec_mode, g.clock])
		stage = "wait"
		if g.over:
			# (the end screen comes up a moment after the end: let it, then leave it as a player would)
			for i in 240:
				await process_frame
				if main.ui_layer.get_children().any(func(c) -> bool: return c.has_signal("watch_replay")):
					break
		main._to_menu()
		await process_frame
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
	# watched as the owner did: from the start at 8x, looking at the fight every WATCH_EVERY s of match time
	rp.seek(float(rp.start_t))
	rp.set_playing(true)
	rp.set_speed(8.0)
	var next := 20.0
	var guard := 0
	while guard < 20000:
		guard += 1
		await process_frame
		if g.clock >= next or bool(rp.at_end):
			var last := bool(rp.at_end)
			rp.set_speed(1.0)
			await _moment("t%03d" % int(g.clock), drawn)
			next = g.clock + WATCH_EVERY
			if last or bool(rp.at_end):
				break
			rp.set_playing(true)
			rp.set_speed(8.0)
	# and after a jump back
	rp.seek(float(rp.length) * 0.6)
	rp.set_playing(true)
	await _frames(20)
	await _moment("seek", drawn)
	_end()


const WATCH_EVERY := 15.0


## Pause, look at the fight (else the busiest spot), check every unit on screen.
func _moment(tag: String, drawn: bool) -> void:
	var rp = g.replay
	await _frames(6)           # (a few ticks at 1x: the units in view take their strips)
	var end := bool(rp.at_end)
	rp.set_playing(false)
	g.camera.position = _busy_spot()
	g.camera.zoom = Vector2(1.6, 1.6)
	await _frames(3)
	if not bool(rp.at_end):
		rp.set_playing(true)       # (one more tick in view, then still)
		await _frames(3)
		rp.set_playing(false)
	_check_units(tag, drawn)
	if drawn:
		await _bodies(tag)


## Where the most units of both sides are near each other (the fight), else the most units.
func _busy_spot() -> Vector2:
	var best := g.camera.position
	var bn := -1
	var us := _units()
	for u in us:
		var n := 0
		var both := {}
		for v in us:
			if v.position.distance_to(u.position) < 260.0:
				n += 1
				both[v.team] = true
		n += 100 if both.size() > 1 else 0
		if n > bn:
			bn = n
			best = u.position
	return best


static var _opaque := {}      # "texture id:frame" -> its opaque pixels


func _opaque_px(s: Sprite2D) -> int:
	var k := "%d:%d" % [s.texture.get_instance_id(), s.frame]
	if _opaque.has(k):
		return _opaque[k]
	var img := s.texture.get_image()
	var n := 0
	if img:
		if img.is_compressed():
			img.decompress()
		var fw := img.get_width() / maxi(s.hframes, 1)
		var x0 := (s.frame % maxi(s.hframes, 1)) * fw
		for y in img.get_height():
			for x in range(x0, x0 + fw):
				if img.get_pixel(x, y).a > 0.5:
					n += 1
	_opaque[k] = n
	return n


## Every unit's body on screen is really drawn: the picture with every unit sprite and without them differ over it by
## a fair share of its frame's opaque pixels (as many screen pixels as the zoom makes them).
func _bodies(tag: String) -> void:
	var vp := root.get_viewport()
	var vis := vp.get_visible_rect().size
	# (the HUD's layers off and every unit looked at drawn over the world: a unit standing behind the Mother or a
	# building, or under a panel, is not "missing")
	var layers: Array = []
	for cl in root.find_children("*", "CanvasLayer", true, false):
		if (cl as CanvasLayer).visible:
			layers.append(cl)
			(cl as CanvasLayer).visible = false
	# (only units clear of one another; everything else on the field hidden for the two pictures: buildings, rooted
	# creatures, units not looked at. Nothing can stand in front of a unit looked at, so no body means not drawn.)
	var cands: Array = []
	for u in _units():
		if BroodNew.rooted(u) or BroodRoot.in_cocoon(u):
			continue          # (a rooted Brood creature is drawn in the building layer: BroodNew.draw)
		var r: Rect2 = vp.get_canvas_transform() * u.sprite.get_global_transform() * u.sprite.get_rect()
		r = r.abs()
		if Rect2(Vector2(8, 8), vis - Vector2(16, 16)).encloses(r):
			cands.append([u, r])
	var looked: Array = []
	for e in cands:
		var clear := true
		for f in cands:
			if f != e and (e[1] as Rect2).intersects(f[1]):
				clear = false
				break
		if clear:
			looked.append(e)
	var hidden: Array = []
	var keep := {}
	for e in looked:
		keep[e[0]] = true
	for n in g.world.get_children():
		if n is CanvasItem and (n as CanvasItem).visible and not keep.has(n) and (n is Unit or n is Building):
			hidden.append(n)
			(n as CanvasItem).visible = false
	await _frames(2)
	var with := await _shot()
	var k2 := Vector2(with.get_size()) / vis
	for i in looked.size():
		var r: Rect2 = looked[i][1]
		looked[i] = [looked[i][0], Rect2(r.position * k2, r.size * k2)]
	for e in looked:
		(e[0] as Unit).sprite.visible = false
	await _frames(2)
	var without := await _shot()
	for e in looked:
		(e[0] as Unit).sprite.visible = true
	for n in hidden:
		if is_instance_valid(n):
			(n as CanvasItem).visible = true
	for cl in layers:
		(cl as CanvasLayer).visible = true
	var none: Array = []
	for e in looked:
		var u: Unit = e[0]
		var r: Rect2 = e[1]
		var diff := 0
		for y in range(maxi(int(r.position.y), 0), mini(int(r.end.y), with.get_height())):
			for x in range(maxi(int(r.position.x), 0), mini(int(r.end.x), with.get_width())):
				var a := with.get_pixel(x, y)
				var b := without.get_pixel(x, y)
				if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.12:
					diff += 1
		var want := _opaque_px(u.sprite) * absf(u.sprite.global_scale.x * u.sprite.global_scale.y) * g.camera.zoom.x * g.camera.zoom.y * k2.x * k2.y
		if diff < want * 0.25:
			none.append("%s#%d (%s_%s, %d of %d px)" % [u.kind, u.net_id, u.anim, u.anim_dir, diff, int(want)])
	check("%s_bodies_drawn" % tag, none.is_empty(), "%d units looked at; no body: %s" % [looked.size(), str(none)])
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		with.save_png(shots.path_join("%s_%s.png" % [rec_mode, tag]))


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
		if why == "" and not BroodNew.rooted(u) and g.view_rect.has_point(u.position):
			# (its pose is what it is doing now: not a picture left over from before a pause or a jump)
			var want := String(u._anim_name())
			var sa := String(u._anim_art) if u._anim_art != "" else String(u.art)
			var drawn_want := ArtData.UNITS.has(sa) and (ArtData.UNITS[sa]["frames"] as Dictionary).keys().any(func(k) -> bool: return String(k).begins_with(want + "_"))
			if want != u.anim and drawn_want and want != "mount":
				why = "pose %s, doing %s" % [u.anim, want]
		if why != "":
			bad[u.kind] = "%s (%s)" % [why, u.anim]
	check("%s_sprites" % tag, bad.is_empty(), "%d units; wrong: %s" % [n, str(bad)])


func rp_pause(on: bool) -> void:
	if g.replay:
		g.replay.set_playing(not on)


func _end() -> void:
	print("LIVE ANIMS ", _live)
	print("ALL OK" if failed == 0 else "SOME FAILED (%d)" % failed)
	quit(0 if failed == 0 else 1)
