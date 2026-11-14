## VETERANCY CHEVRONS (scripts/vet_chevrons.gd, docs/vet_chevrons.md): one chevron over every unit with kills, every
## faction: bronze from 15, silver from 30, gold from 50 (Defs.VET); centred just above the health bar, shown with or
## without the bar; bodies keep theirs; the spoils number on bodies only for a Brood player and those who watch; no
## more hat-trim / skin veterancy colours (the venom line's colours stay); saves, an online guest and a replay (both
## NetSnapshot) show them; a crowd of veterans costs little.
##   godot --headless --fixed-fps 30 --script res://tools/test_vet_chevrons.gd
extends SceneTree
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-66s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func make(facs: Array) -> Game:
	var g := Game.new()
	g.map_id = "ashford_crossing"
	g.demo = true
	g.factions = facs
	g.sides = range(facs.size())
	root.add_child(g)
	return g


func step(g: Game, secs: float) -> void:
	var n := int(round(secs * 30.0))
	for i in n:
		g._physics_process(1.0 / 30.0)
		for u in g.units.duplicate():
			if is_instance_valid(u):
				u._physics_process(1.0 / 30.0)
		g.vet_layer._process(1.0 / 30.0)
		if i % 8 == 0:
			await process_frame


func spot(g: Game, t: int) -> Vector2:
	for b in g.buildings:
		if b.team == t and b.kind == g.faction_hall(t):
			return b.center() + Vector2(0, b.rect().size.y * 0.5 + 110.0)
	var q := BroodNew.queen(g, t)
	return q.position + Vector2(0, BroodRoot.rect_of(q).size.y * 0.5 + 150.0)


func calm(u: Unit) -> Unit:
	if u == null:
		return null
	u.auto_work = false
	u.max_hp = 9000.0
	u.hp = 9000.0
	return u


## The entry drawn for this unit (or null).
func entry_of(g: Game, u: Unit) -> Variant:
	var sz: Vector2 = g.vet_layer.world_size()
	for e in g.vet_layer.entries():
		var r: Rect2 = e[1]
		if absf(r.get_center().x - u.position.x) < 0.01 and r.position.y < u.position.y + 2.0 and r.position.y > u.position.y - 260.0 and r.size.is_equal_approx(sz):
			if absf(r.end.y - (u.position.y + VetChevrons.bottom_of(u, VetChevrons.GAP * sz.x / VetChevrons.SCREEN_W))) < 0.01:
				return e
	return null


func _run() -> void:
	# ---- the ranks
	var want := {0: 0, 14: 0, 15: 1, 29: 1, 30: 2, 49: 2, 50: 3, 80: 3}
	var ok := true
	for k in want:
		if VetChevrons.rank(k) != want[k]:
			ok = false
			print("  rank(%d) = %d, want %d" % [k, VetChevrons.rank(k), want[k]])
	check("ranks: none under 15, bronze 15-29, silver 30-49, gold from 50", ok)
	check("Defs.VET: bronze 15, silver 30, gold 50; the bonus +1% a kill to +50%", int(Defs.VET["bronze"]) == 15 and int(Defs.VET["silver"]) == 30 and int(Defs.VET["gold"]) == 50
		and is_equal_approx(float(Defs.VET["per_kill"]), 0.01) and is_equal_approx(float(Defs.VET["max"]), 0.5))
	check("the card: 'Veteran (bronze): 17 kills, +17% damage'", VetChevrons.rank_text(17) == "Veteran (bronze): 17 kills, +17% damage", VetChevrons.rank_text(17))
	check("the card: silver, gold (the bonus stops at +50%), under bronze just the kills",
		VetChevrons.rank_text(30) == "Veteran (silver): 30 kills, +30% damage" and VetChevrons.rank_text(64) == "Veteran (gold): 64 kills, +50% damage"
		and VetChevrons.rank_text(3) == "3 kills, +3% damage" and VetChevrons.rank_text(1) == "1 kill, +1% damage")
	check("the bonus stays fluid: 17 kills +17%, 64 kills +50%", is_equal_approx(UnitStats._vet(17), 1.17) and is_equal_approx(UnitStats._vet(64), 1.5))
	VetChevrons.load_tex()
	check("the owner's chevrons are used (assets/ui/vet_*.png)", VetChevrons.from_files)
	var ci := VetChevrons.chevron_image(2)
	check("the code-drawn stand-in: 15 x 11 with an outline", ci.get_width() == 15 and ci.get_height() == 11 and ci.get_used_rect().size.x >= 13)

	# ---- every faction, guns, workers, flyers, a rebel: a chevron from bronze, nothing under it
	var g := make(["crown", "clockwork", "brood"])
	await process_frame
	await process_frame
	g.camera.position = spot(g, 0)
	g.camera.zoom = Vector2(1.5, 1.5)
	g.update_view_rect()
	g.view_rect = Rect2()          # (the test's units stand at three bases: every one counts as in view)
	var kinds := {0: ["musketeer", "labourer", "cannon", "horseman", "balloon", "mortar"], 1: ["winder", "clock_soldier", "springer", "ticking_owl", "cuckoo", "pendulum"],
		2: ["raptor", "grub", "spitter", "brute", "skywing", "mist_toad"]}
	var all: Array = []
	for t in kinds:
		var at := spot(g, t)
		var i := 0
		for k in kinds[t]:
			if not Defs.UNITS.has(k):
				print("  (no unit kind %s in this version)" % k)
				continue
			var u := calm(g._add_unit(k, t, at + Vector2(-150 + i * 60, 0)))
			i += 1
			if u != null:
				all.append(u)
	var reb := calm(g._add_unit("musketeer", 0, spot(g, 0) + Vector2(0, 90)))
	Rebels.apply(reb, "militia")
	all.append(reb)
	await step(g, 0.3)
	g.view_rect = Rect2()          # (the ticks set it to the camera's view again)
	var bad: Array = []
	for u in all:
		u.kills = 14
	g.vet_layer._scan()
	for u in all:
		if entry_of(g, u) != null:
			bad.append("%s at 14" % u.kind)
	check("no chevron under 15 kills (%d units of every faction)" % all.size(), bad.is_empty(), str(bad))
	for n in [15, 29, 30, 49, 50]:
		bad.clear()
		for u in all:
			u.kills = n
		for u in all:
			var e: Variant = entry_of(g, u)
			if e == null or int(e[0]) != VetChevrons.rank(n):
				bad.append(u.kind)
				if n == 15:
					print("  %s vis %s tree %s aboard %s mod %.2f off %s in vets %s pos %s bottom %.1f" % [u.kind, u.visible, u.is_visible_in_tree(), u.aboard, u.modulate.a, u.off_field, g.vet_layer.vets.has(u), u.position, VetChevrons.bottom_of(u, 1.0)])
		check("%d kills: every unit shows the %s chevron, centred just over its bar" % [n, VetChevrons.RANKS[VetChevrons.rank(n)]], bad.is_empty(), str(bad))
	# above the health bar whether it shows or not
	var m: Unit = all[0]
	m.hp = m.max_hp
	var e0: Variant = entry_of(g, m)
	m.hp = m.max_hp * 0.5
	var e1: Variant = entry_of(g, m)
	check("the chevron shows with the bar hidden (untouched) and drawn (hurt), at the same place", e0 != null and e1 != null and (e0[1] as Rect2).is_equal_approx(e1[1]))
	check("it sits above the bar's top edge", e0 != null and (e0[1] as Rect2).end.y <= m.position.y + m.bar_top() - 1.0)
	# a Springer in the air: it rises with him
	var sp: Unit = null
	for u in all:
		if u.kind == "springer":
			sp = u
	if sp != null:
		var y0: float = VetChevrons.bottom_of(sp, 1.0)
		sp.jump = {"from": sp.position, "to": sp.position + Vector2(200, 0), "t": 0.5, "crouch": 0.2, "air": 0.6, "land": 0.2, "peak": 60.0}
		var lifted: float = Springer.lift(sp)
		var y1: float = VetChevrons.bottom_of(sp, 1.0)
		sp.jump = {}
		check("a Springer's leap lifts it", lifted <= 0.0 or y1 < y0 - 1.0, "lift %.1f: %.1f -> %.1f" % [lifted, y0, y1])
	# screen size: the same on screen at the usual zoom and closer; a little smaller far out, never bigger on the field
	g.camera.zoom = Vector2(1.5, 1.5)
	var w15: float = g.vet_layer.world_size().x * 1.5
	g.camera.zoom = Vector2(2.6, 2.6)
	var w26: float = g.vet_layer.world_size().x * 2.6
	g.camera.zoom = Vector2(0.55, 0.55)
	var w05: float = g.vet_layer.world_size().x * 0.55
	check("screen size: %.1f px at 1.5x and 2.6x, %.1f px at 0.55x" % [w15, w05], is_equal_approx(w15, VetChevrons.SCREEN_W) and is_equal_approx(w26, VetChevrons.SCREEN_W)
		and w05 >= VetChevrons.SCREEN_MIN - 0.01 and w05 < w15)
	g.camera.zoom = Vector2(1.5, 1.5)
	# fog: a unit not seen shows none
	m.visible = false
	check("an unseen unit (the fog) shows no chevron", entry_of(g, m) == null)
	m.visible = true

	# ---- no more trim / skin veterancy colours; the venom line's colours still on
	var mat := m.sprite.material as ShaderMaterial
	check("a Crown soldier: no vet_level on his material (the trim stays black)", mat != null and mat.get_shader_parameter("vet_level") == null and int(mat.get_shader_parameter("vet_style")) == 1)
	check("the shader has no veterancy level any more", not FileAccess.get_file_as_string("res://shaders/team.gdshader").contains("vet_level"))
	var spit: Unit = null
	var rap: Unit = null
	for u in all:
		if u.kind == "spitter":
			spit = u
		if u.kind == "raptor":
			rap = u
	if spit != null:
		var sm := spit.sprite.material as ShaderMaterial
		check("the venom line keeps its colours (venom_swap and its mask)", bool(sm.get_shader_parameter("venom_swap")) and sm.get_shader_parameter("venom_mask") != null)
		check("the venom mask is the one of the strip shown", sm.get_shader_parameter("venom_mask") == VetLook.mask_for(spit.sprite.texture, VetLook.VENOM))
		check("a gold Spitter is not recoloured (vet_style 0)", int(sm.get_shader_parameter("vet_style") if sm.get_shader_parameter("vet_style") != null else 0) == 0)
	if rap != null:
		var rm := rap.sprite.material as ShaderMaterial
		check("a gold Raptor's skin is as painted (vet_style 0)", int(rm.get_shader_parameter("vet_style") if rm.get_shader_parameter("vet_style") != null else 0) == 0)

	# ---- bodies: the same chevron; the spoils number only for a Brood player and those who watch
	var body := calm(g._add_unit("musketeer", 0, spot(g, 0) + Vector2(120, 140)))
	body.kills = 35
	await step(g, 0.1)
	body.hp = 0.0
	body.die()
	await step(g, 2.0)
	var be: Variant = entry_of(g, body) if is_instance_valid(body) else null
	check("a body shows its chevron (35 kills: silver)", be != null and int(be[0]) == 2)
	check("the body lies where the Brood can harvest it (a Brood side in the match)", g.corpses.has(body))
	if be != null:
		check("its chevron sits over the spoils number (a computers' game shows it)", (be[1] as Rect2).end.y <= body.position.y + Unit.NUMBER_Y)
	check("computers v computers: the number shows", VetChevrons.number_shown(g))
	g.demo = false
	g.human = 0
	check("a Crown player: no number", not VetChevrons.number_shown(g))
	g.human = 1
	check("a Clockwork player: no number", not VetChevrons.number_shown(g))
	g.human = 2
	check("a Brood player: the number", VetChevrons.number_shown(g))
	g.human = 0
	var rp := ReplayPlayer.new()
	g.replay = rp
	check("a replay: the number", VetChevrons.number_shown(g))
	g.replay = null
	rp.free()
	g.demo = true

	# ---- saves keep the kills and their chevrons
	var sv := calm(g._add_unit("musketeer", 0, spot(g, 0) + Vector2(-120, 140)))
	sv.kills = 31
	g.demo = false
	var d := SaveGame.capture(g, {"map": g.map_id, "seed": 4242})
	g.demo = true
	SaveGame.restore(g, d)
	await process_frame
	await process_frame
	g.vet_layer._scan()
	var back: Unit = null
	for u in g.units:
		if u.kind == "musketeer" and u.team == 0 and u.position.distance_to(spot(g, 0) + Vector2(-120, 140)) < 4.0:
			back = u
	check("a save keeps the kills and the silver chevron", back != null and back.kills == 31 and g.vet_layer.vets.has(back) and entry_of(g, back) != null)
	g.queue_free()
	await process_frame

	# ---- online (the guest) and replays (they play through the same snapshots): the chevrons show
	var h := make(["crown", "brood"])
	var gu := Game.new()
	gu.map_id = h.map_id
	gu.demo = true
	gu.factions = ["crown", "brood"]
	gu.sides = [0, 1]
	gu.puppet = true
	root.add_child(gu)
	await process_frame
	await process_frame
	var sh := NetSession.attach(h, NetLink.new(), true, 0, {1: 1})
	var sg := NetSession.attach(gu, NetLink.new(), false, 1, {})
	sh.set_process(false)
	var hu := calm(h._add_unit("musketeer", 0, spot(h, 1) + Vector2(80, 0)))      # (in the guest's sight: snapshots are cut per side)
	var hr := calm(h._add_unit("raptor", 1, spot(h, 1)))
	hu.kills = 52
	hr.kills = 16
	sh.snap_n = 1
	NetSnapshot.apply(sg, NetCodec.unpack(NetCodec.pack(NetSnapshot.build(sh))))
	await process_frame
	gu.view_rect = Rect2()
	gu.vet_layer._scan()
	var gm: Unit = null
	var gr: Unit = null
	for u in gu.units:
		if u.net_id == hu.net_id:
			gm = u
		if u.net_id == hr.net_id:
			gr = u
	print("  guest: %s %s / %s units" % [gm, gr, gu.units.size()])
	check("the online guest gets the kills (gold and bronze)", gm != null and gr != null and gm.kills == 52 and gr.kills == 16)
	var ge: Variant = entry_of(gu, gm) if gm != null else null
	var gre: Variant = entry_of(gu, gr) if gr != null else null
	check("the guest draws their chevrons (gold, bronze)", ge != null and gre != null and int(ge[0]) == 3 and int(gre[0]) == 1)
	gu.demo = false
	gu.human = 1
	check("the guest's number rule by its own side (a Brood guest sees it)", VetChevrons.number_shown(gu))
	gu.human = 0
	check("... a Crown guest does not", not VetChevrons.number_shown(gu))
	h.queue_free()
	gu.queue_free()
	await process_frame

	# ---- a crowd: 400 veterans in view cost little to lay out
	var g2 := make(["crown", "brood"])
	await process_frame
	await process_frame
	g2.view_rect = Rect2()
	var at2 := spot(g2, 0)
	for i in 400:
		var u := g2._add_unit("musketeer" if i % 2 == 0 else "raptor", i % 2, at2 + Vector2((i % 20) * 20 - 200, (i / 20) * 20 - 200))
		if u:
			u.auto_work = false
			u.kills = 15 + i % 40
	var n: int = g2.vet_layer.entries().size()
	var t0 := Time.get_ticks_usec()
	for k in 60:
		g2.vet_layer._process(1.0 / 60.0)
	var per := float(Time.get_ticks_usec() - t0) / 60.0 / 1000.0
	check("400 veterans: %d chevrons, %.3f ms a frame to keep them placed" % [n, per], n == 400 and per < 0.5)
	var kids := 0
	for u in g2.units:
		if u.get_node_or_null("VetChevron") != null:
			kids += 1
	check("each veteran carries its own chevron sprite (moved and culled by the engine)", kids == 400)
	g2.queue_free()
	await process_frame
	print("RESULT %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
