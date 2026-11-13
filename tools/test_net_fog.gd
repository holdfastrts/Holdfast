extends SceneTree
## RANKED / ONLINE FOG (docs/online_ranked.md "Fog"): a guest never receives an enemy its side cannot see, keyframes
## included. One process: a host game (two Hard computers) with two guests on opposite sides, as on a dedicated match
## host (NetSession.side_views: one picture per side), ranked's strict mode on; a guest's puppet game for side 1 is fed
## its pictures (it must hold exactly what the host said it holds, and nothing breaks).
##   godot --headless --fixed-fps 30 --script res://tools/test_net_fog.gd [-- secs:300 map:twin_fords]
## Checks, every picture of both sides:
## - every enemy UNIT row: that side sees the unit now, or it is the one last row as it leaves sight (seen the picture
##   before); never one it has not seen (the 0.33 keyframes sent every enemy unit whole: a map hack's dream);
## - every enemy BUILDING row: that side sees some of it now; never another side's planned site;
## - a keyframe's id list names nothing the side was never sent;
## - strict: the enemy's bank is 0 and no battle report before the end; effects only where the side sees.
var main: Node
var t := 0.0
var g: Game
var pg: Game
var hs: NetSession
var gs: NetSession
var secs := 300.0
var map := "twin_fords"
var frames := 0
var fails := 0
var stage := 0
var unit_rows := 0
var enemy_unit_rows := 0
var enemy_bld_rows := 0
var keyframes := 0
var leaks := 0
var id_leaks := 0
var bank_leaks := 0
var stats_leaks := 0
var fx_seen := 0
var fx_leaks := 0
var ever := [{}, {}]                 # per side: every id ever sent to it
var bad_examples: Array = []
var old_leaks := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-58s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("secs:"):
			secs = float(a.substr(5))
		elif a.begins_with("map:"):
			map = a.substr(4)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if stage == 0:
		if t > 0.2 and main.game == null:
			main.start({"map": map, "seed": 777123, "slots": [
				{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
				{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "rush"}]})
			return false
		if main.game == null:
			return false
		g = main.game
		paused = false
		if pg == null:
			_setup()
		frames += 1
		if frames % 2 == 0:
			_snap()
		if g.clock >= secs or g.over:
			stage = 9
			_report()
		return false
	return false


func _setup() -> void:
	hs = NetSession.new()
	hs.game = g
	hs.is_host = true
	hs.go_given = true
	hs.link = NetLink.new()
	hs._m_reset()
	hs.peer_team = {11: 0, 12: 1}        # two guests, one each side: a dedicated host's 1v1
	hs.strict = true
	pg = Game.new()
	pg.puppet = true
	pg.human = 1
	pg.factions = g.factions.duplicate()
	pg.colours = g.colours.duplicate()
	pg.sides = g.sides.duplicate()
	pg.income_mult = g.income_mult.duplicate()
	pg.map_id = g.map_id
	pg.rng.seed = 777123
	root.add_child(pg)
	gs = NetSession.new()
	gs.game = pg
	gs.is_host = false
	gs.go_given = true
	gs.link = NetLink.new()
	gs._m_reset()
	pg.net = gs


func _snap() -> void:
	hs.snap_n += 1
	# effects as the game notes them online (NetSession.note_effect): a puff at some units of each side, seen or not
	var k := 0
	for u in g.units:
		if not u.dead and k < 12 and (u.net_id + hs.snap_n) % 7 == 0:
			hs.fx.append(["e", "dust", u.position, 1.0])
			k += 1
	var vs := hs.side_views()
	if vs.size() != 2:
		check("one picture per side", false, "%d views" % vs.size())
		stage = 9
		return
	for v in vs:
		var side := int(v.sides[0])
		var before: Dictionary = v.was_seen.duplicate()
		var m := NetSnapshot.build(hs, v)
		_check_picture(v, side, before, m)
		if side == 1:
			NetSnapshot.apply(gs, NetCodec.unpack(NetCodec.pack(m)))
	hs.fx = []


func _check_picture(v: NetView, side: int, before: Dictionary, m: Dictionary) -> void:
	var eyes: Array = [side]
	var ev := NetSnapshot._eye_vis(g, eyes)
	var sent: Dictionary = ever[side]
	for row in m["u"]:
		unit_rows += 1
		var id := int(row[0])
		sent[id] = true
		if NetSnapshot._ours(g, int(row[2]), eyes):
			continue
		enemy_unit_rows += 1
		var u = hs.by_id.get(id)
		var seen: bool = u != null and is_instance_valid(u) and NetSnapshot._seen_by(g, u, eyes, ev)
		if not seen and not before.has(id):
			leaks += 1
			if bad_examples.size() < 5:
				bad_examples.append("side %d got unit %d (%s) at %s, unseen%s" % [side, id, row[1], row[3], " in a KEYFRAME" if m.has("ids") else ""])
	for row in m["b"]:
		var id := int(row[0])
		sent[id] = true
		if NetSnapshot._ours(g, int(row[2]), eyes):
			continue
		enemy_bld_rows += 1
		var b = hs.by_id.get(id)
		if b == null or not is_instance_valid(b) or b.ghost or not NetSnapshot._bld_seen(g, b, ev):
			leaks += 1
			if bad_examples.size() < 5:
				bad_examples.append("side %d got building %d (%s), unseen" % [side, id, row[1]])
	if m.has("ids"):
		keyframes += 1
		for u in g.units:
			if not u.dead and not NetSnapshot._ours(g, u.team, eyes) and not NetSnapshot._seen_by(g, u, eyes, ev):
				old_leaks += 1        # (what a 0.33 keyframe sent: every unit whole, unseen enemies too)
		for id in m["ids"]:
			if not sent.has(int(id)):
				id_leaks += 1
	for t2 in g.n_players():
		if g.sides[t2] != side and not g.over:
			var pd: Dictionary = m["pl"][t2]
			if float(pd.get("gold", 0)) != 0.0 or float(pd.get("res2", 0)) != 0.0:
				bank_leaks += 1
	if m.has("stats") and not g.over:
		stats_leaks += 1
	for f in m.get("fx", []):
		fx_seen += 1
		if String(f[0]) == "e":
			var p: Vector2 = f[2]
			if not NetSnapshot._cell_seen(g, g.idx(g.cell_of(g.on_map(p))), ev):
				fx_leaks += 1


func _report() -> void:
	print("FOG game %.0f s on %s: %d unit rows (%d of enemies), %d enemy building rows, %d keyframes per side, %d effects" % [g.clock, g.map_id, unit_rows, enemy_unit_rows, enemy_bld_rows, keyframes / 2, fx_seen])
	print("FOG the 0.33 keyframes would have sent %d rows of enemies the side could not see (%d per keyframe)" % [old_leaks, old_leaks / maxi(keyframes, 1)])
	for e in bad_examples:
		print("  ", e)
	check("the sides met (enemy units were sent at all)", enemy_unit_rows > 0, "%d rows" % enemy_unit_rows)
	check("no enemy row a side could not see (keyframes too)", leaks == 0, "%d leaks" % leaks)
	check("a keyframe's id list names only what the side was sent", id_leaks == 0, "%d ids" % id_leaks)
	check("strict: the enemy's bank is never sent", bank_leaks == 0, "%d" % bank_leaks)
	check("strict: no battle report before the end", stats_leaks == 0, "%d" % stats_leaks)
	check("effects only where the side sees", fx_seen > 0 and fx_leaks == 0, "%d of %d" % [fx_leaks, fx_seen])
	check("the guest holds exactly what the host listed after each keyframe", gs.count_diff_max == 0, "worst %d, %d snapshots off" % [gs.count_diff_max, gs.count_diff_snaps])
	print("FOG %s" % ("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails))
	quit(0 if fails == 0 else 1)
