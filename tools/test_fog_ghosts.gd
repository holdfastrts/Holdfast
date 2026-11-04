extends SceneTree
## REMEMBERED ENEMY BUILDINGS under the fog (scripts/fog_memory.gd, docs/fog_ghosts.md): an enemy building seen and
## left stays as its last-seen picture (the live one hidden: no live building progress, damage or ruin), on the
## minimap too; razed unseen, the picture stays; seen again, the picture goes (the ruin shows, or the live building).
## A rooted Brood creature is remembered the same way; a walking one is not. Not pickable. Watching computers: no
## pictures. And the cost with 100+ enemy buildings.
##   godot --headless --fixed-fps 30 --script res://tools/test_fog_ghosts.gd
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _make(facs: Array, demo := false) -> Game:
	Defs.line_mode = false
	Defs.gear_mode = true
	Defs.cw_roster = false
	var g := Game.new()
	g.map_id = "ashford_crossing"
	g.demo = demo
	g.factions = facs
	g.sides = range(facs.size())
	root.add_child(g)
	return g


func _hall(g: Game, t: int) -> Building:
	for b in g.buildings:
		if b.team == t and b.kind == g.faction_hall(t) and not b.dead:
			return b
	return null


func _spot(g: Game, t: int, kind: String, near: Vector2i, rmin := 6) -> Vector2i:
	for r in range(rmin, 20):
		for a in 32:
			var c := near + Vector2i(roundi(cos(a * TAU / 32.0) * r), roundi(sin(a * TAU / 32.0) * r))
			if g.placement_problem(t, kind, c, true) == "":
				return c
	return Vector2i(-1, -1)


func _free(g: Game, c: Vector2i, sz: Vector2i) -> bool:
	for y in sz.y:
		for x in sz.x:
			if not g.is_free(c + Vector2i(x, y)):
				return false
	return true


func _move(g: Game, u: Unit, p: Vector2) -> void:
	u.position = p
	g.note_move(u)
	g._update_vis()


func _ghost_node(g: Game, id: int) -> Node2D:
	return g.fog_mem.mem[id]["node"] if g.fog_mem.mem.has(id) else null


func _sprites(n: Node) -> Array:
	return n.get_children().filter(func(c) -> bool: return c is Sprite2D) if n != null else []


func _run() -> void:
	await _buildings()
	await _brood()
	await _spectator()
	await _perf()
	print("FOG GHOSTS: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


func _buildings() -> void:
	var g := _make(["crown", "clockwork"])
	await process_frame
	await process_frame
	g._update_vis()
	var hive := _hall(g, 1)
	var hc := g.cell_of(hive.center())
	var c := _spot(g, 1, "regulator", hc)
	var b := g._add_building("regulator", 1, c, true)
	var cs := _spot(g, 1, "cuckoo_house", hc, 8)
	var site := g._add_building("cuckoo_house", 1, cs, false)
	site.progress = 0.3
	site._update_sprite()
	g._update_vis()
	check("an enemy building never seen: hidden, nothing remembered", not b.visible and not g.fog_mem.remembers(b.get_instance_id()))
	var away := Vector2(g.W, g.H) * Game.T * 0.5
	var scout := g._add_unit("musketeer", 0, b.center() + Vector2(0, 90))
	scout.max_hp = 99999.0
	scout.hp = 99999.0
	g._update_vis()
	check("seen now: the live building shows, no picture", b.visible and b.seen_by_human and not g.fog_mem.remembers(b.get_instance_id()))
	check("the site seen too", site.visible)
	g.set_selection([b])
	var bid := b.get_instance_id()
	var sid := site.get_instance_id()
	var frame0: int = site.sprite.frame
	var tex0: Texture2D = site.sprite.texture
	# ---- vision leaves
	_move(g, scout, away)
	check("vision gone: the live building is hidden", not b.visible and not site.visible)
	check("... and remembered (its picture under the fog)", g.fog_mem.remembers(bid) and g.fog_mem.remembers(sid))
	var gn := _ghost_node(g, bid)
	check("the picture stands where the building stood, with its parts", gn != null and gn.global_position.distance_to(b.global_position) < 0.5 and _sprites(gn).size() >= 1, str(_sprites(gn).size()))
	var mat := (_sprites(gn)[0] as Sprite2D).material as ShaderMaterial if _sprites(gn).size() > 0 else null
	check("drawn darker (the team shader's tint)", mat != null and (mat.get_shader_parameter("tint") as Vector3).x < 0.9)
	check("left the selection (a picture is not a thing)", not g.selection.has(b))
	check("not pickable on the map", g.entity_at(b.center()) != b)
	var mini := g.fog_mem.minimap_rects()
	check("on the minimap as its square", mini.any(func(r) -> bool: return (r[0] as Rect2).is_equal_approx(b.rect())), str(mini.size()))
	# ---- hurt unseen (its damaged picture live): the picture keeps how it looked
	var btex0: Texture2D = b.sprite.texture
	b.hp = b.max_hp * 0.3
	b._update_sprite()
	site.progress = 0.95
	g._update_vis()
	var ss: Array = _sprites(gn)
	check("hurt unseen: the live picture is the damaged one", b.sprite.texture != btex0)
	check("... the remembered picture keeps its last seen look", ss.size() > 0 and (ss[0] as Sprite2D).texture == btex0)
	var sg := _ghost_node(g, sid)
	check("a site's picture keeps its look as last seen", sg != null and _sprites(sg).size() > 0 and (_sprites(sg)[0] as Sprite2D).texture == tex0 and (_sprites(sg)[0] as Sprite2D).frame == frame0)
	# ---- razed unseen: the picture stays, the ruin is not shown
	b.hp = 0.0
	b.die()
	g._update_vis()
	check("razed unseen: the picture stays", g.fog_mem.remembers(bid) and is_instance_valid(gn))
	check("... the ruin is not shown", is_instance_valid(b) and not b.visible)
	check("... still on the minimap", g.fog_mem.minimap_rects().any(func(r) -> bool: return (r[0] as Rect2).is_equal_approx(b.rect())))
	# ---- vision returns
	_move(g, scout, b.center() + Vector2(0, 90))
	check("seen again: the picture goes", not g.fog_mem.remembers(bid) and not g.fog_mem.remembers(sid))
	check("... the ruin shows (it is there)", is_instance_valid(b) and b.visible)
	check("... the live site shows as it is now", site.visible)
	await process_frame
	check("... its picture node freed", not is_instance_valid(gn))
	# ---- full vision (FOG: OFF): no pictures
	_move(g, scout, away)
	check("left again: the site remembered", g.fog_mem.remembers(sid))
	g.reveal = true
	g._update_vis()
	check("full vision: no pictures, everything live", g.fog_mem.mem.is_empty() and site.visible)
	g.queue_free()
	await process_frame


func _brood() -> void:
	var g := _make(["crown", "brood"])
	await process_frame
	await process_frame
	g._update_vis()
	var q := BroodNew.queen(g, 1)
	var k := BroodNew.TURTLE
	var p := BroodRoot.snap(k, q.position + Vector2(260, 160))
	var turtle := g._add_unit(k, 1, p)
	turtle.tesla_mode = "deployed"
	turtle.nb["m"] = "deployed"
	BroodRoot.footprint_on(g, turtle, false)
	var raptor := g._add_unit("raptor", 1, q.position + Vector2(-200, 160))
	raptor.process_mode = Node.PROCESS_MODE_DISABLED
	turtle.process_mode = Node.PROCESS_MODE_DISABLED
	var away := Vector2(g.W, g.H) * Game.T * 0.5
	var scout := g._add_unit("musketeer", 0, turtle.position + Vector2(0, 120))
	scout.max_hp = 99999.0
	scout.hp = 99999.0
	scout.process_mode = Node.PROCESS_MODE_DISABLED
	g._update_vis()
	check("Brood: a rooted Mound Turtle seen: shown", turtle.visible and not g.fog_mem.remembers(turtle.get_instance_id()))
	_move(g, scout, raptor.position + Vector2(0, 60))
	check("Brood: a walking Raptor seen", raptor.visible)
	_move(g, scout, away)
	check("Brood: the rooted turtle left: hidden and remembered", not turtle.visible and g.fog_mem.remembers(turtle.get_instance_id()))
	check("Brood: the walking Raptor left: hidden, not remembered", not raptor.visible and not g.fog_mem.remembers(raptor.get_instance_id()))
	# it uproots and walks off unseen: the picture stays till the spot is looked at; seen walking elsewhere, it goes
	var tid := turtle.get_instance_id()
	BroodRoot.footprint_off(g, turtle)
	turtle.tesla_mode = "packed"
	turtle.nb["m"] = "packed"
	turtle.position = raptor.position + Vector2(80, 0)
	g._update_vis()
	check("Brood: uprooted out of sight: the picture stays", g.fog_mem.remembers(tid))
	_move(g, scout, turtle.position + Vector2(0, 60))
	check("Brood: seen walking elsewhere: the old picture goes", turtle.visible and not g.fog_mem.remembers(tid))
	g.queue_free()
	await process_frame


func _spectator() -> void:
	var g := _make(["crown", "clockwork"], true)
	await process_frame
	await process_frame
	g.view_team = 0
	g._update_vis()
	var hive := _hall(g, 1)
	var scout := g._add_unit("musketeer", 0, hive.center() + Vector2(0, 150))
	scout.process_mode = Node.PROCESS_MODE_DISABLED
	g._update_vis()
	_move(g, scout, Vector2(g.W, g.H) * Game.T * 0.5)
	check("watching computers: no pictures (no change there)", g.fog_mem.mem.is_empty() and hive.visible)
	g.queue_free()
	await process_frame


func _perf() -> void:
	var g := _make(["crown", "clockwork"])
	await process_frame
	await process_frame
	g._update_vis()
	var made: Array = []
	var sz: Vector2i = Defs.BUILDINGS["regulator"]["size"]
	for y in range(4, g.H - 4, sz.y + 1):
		for x in range(4, g.W - 4, sz.x + 1):
			if made.size() >= 140:
				break
			var c := Vector2i(x, y)
			if g.explored[g.idx(c)] == 0 and _free(g, c, sz):
				made.append(g._add_building("regulator", 1, c, true))
	# everything seen once (a flyer's tour), then left: every one remembered
	for b in made:
		b.seen_by_human = true
		b.visible = true
	var t0 := Time.get_ticks_usec()
	g._update_vis()
	var snap_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var hidden := made.filter(func(b) -> bool: return not b.visible)
	var all_kept := hidden.all(func(b) -> bool: return g.fog_mem.remembers(b.get_instance_id()))
	check("%d enemy buildings out of sight remembered at once" % hidden.size(), hidden.size() >= 100 and all_kept, "%d pictures (of %d made; the rest in sight), %.1f ms for that one update" % [g.fog_mem.mem.size(), made.size(), snap_ms])
	var n := 40
	t0 = Time.get_ticks_usec()
	for i in n:
		g.fog_mem.update_buildings(g._human_vis, g.human)
	var each := (Time.get_ticks_usec() - t0) / 1000.0 / n
	t0 = Time.get_ticks_usec()
	for i in n:
		g._update_vis()
	var whole := (Time.get_ticks_usec() - t0) / 1000.0 / n
	check("the remembering part of a fog update stays cheap (< 1.5 ms)", each < 1.5, "%.3f ms of %.2f ms per update (4 a second)" % [each, whole])
	g.queue_free()
	await process_frame
