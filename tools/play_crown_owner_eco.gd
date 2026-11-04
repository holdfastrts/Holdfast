extends "res://tools/play_crown_v_brood.gd"
## THE CROWN COMPUTER AGAINST THE OWNER'S OWN GAME (crown-owner-eco, docs/crown_owner_eco.md): everything of
## tools/play_crown_v_brood.gd (coach:<plan> cslot: b:<faction> sb:<plan> map: seed: out: end:) plus:
##   owner.txt        a line a minute in the owner's numbers (labourers, gold earned, army value, supply-blocked seconds and
##                    those with 300+ gold, Barracks / Foundries / Churches / Mills / halls / Cottages, income a minute) and
##                    the key moments (the 2nd hall laid and done, the first Barracks and why, each new hall's Farm, the
##                    natural's palisade, the wall post and the cliff edge moves, the production added)
##   main_MMSS.png    the main base at MAIN_AT (the owner's picture eco_v_eco_2 is the same view); nat_MMSS.png the natural
##   noshots:1        no pictures (headless measuring runs)
##   godot --headless --fixed-fps 30 --script res://tools/play_crown_owner_eco.gd -- coach:economy b:brood sb:brute \
##       map:highmoor seed:935948638 cslot:1 out:/abs/dir end:600 noshots:1
const MAIN_AT := [240.0, 420.0, 600.0, 840.0]
const DUMP_AT := [300.0, 480.0, 720.0]     # base_MMSS.json: the ground, the buildings and the layout's plan (tools/crown_layout_pics.py)
var _dump_i := 0
var noshots := false
var own_lines: Array = []
var ev_lines: Array = []
var _own_next := 60.0
var blocked := 0.0
var blocked_gold := 0.0
var _last_c := 0.0
var hall2_laid := -1.0
var hall2_done := -1.0
var barracks1 := -1.0
var barracks1_why := ""
var pal_first := -1.0
var _main_i := 0
var _oe_farm_seen := 0
var _oe_wall_seen := 0
var _oe_edge_seen := 0
var _oe_prod_seen := 0
var _oe_sup_seen := 0
var _nat_share := {}


func _initialize() -> void:
	super._initialize()
	noshots = OS.get_cmdline_user_args().has("noshots:1")


func _coach() -> void:
	super._coach()
	if noshots:
		pending.clear()
		clips.clear()
		_later.clear()
	var c: float = g.clock
	var dt := c - _last_c
	_last_c = c
	var cap: int = int(g.players[me]["cap"])
	if g.supply_used(me) >= cap and cap < g.max_supply(me):
		blocked += dt
		if int(g.players[me]["gold"]) >= 300:
			blocked_gold += dt
	var halls: Array = _ai._halls()
	if hall2_laid < 0.0 and halls.size() >= 2:
		hall2_laid = c
		_ev("the 2nd hall is laid (%d labourers)" % g.workers(me).size())
	if hall2_done < 0.0 and halls.filter(func(h: Building) -> bool: return h.built).size() >= 2:
		hall2_done = c
		_ev("the 2nd hall stands")
	if barracks1 < 0.0 and not _ai._mine("barracks").is_empty():
		barracks1 = c
		var sc = _ai.scout
		barracks1_why = "rush scouted (%s)" % sc.rush_evidence() if _ai._defending() else ("after the 2nd hall" if halls.size() >= 2 else "no hall 2 yet, no rush scouted")
		_ev("the first Barracks is laid: %s" % barracks1_why)
	if pal_first < 0.0:
		for b in g.buildings:
			if b.team == me and not b.dead and b.kind == "wall" and b.center().distance_to(_home()) > 12.0 * Defs.TILE:
				pal_first = c
				_ev("the first palisade at a new hall")
				break
	while _oe_farm_seen < _ai.hall_farm_log.size():
		var e: Array = _ai.hall_farm_log[_oe_farm_seen]
		_oe_farm_seen += 1
		_ev("a Farm at a new hall %d s after it stood" % int(float(e[1]) - float(e[0])))
	while _oe_wall_seen < _ai.ch.wall_log.size():
		_ev("WALL POST: " + String(_ai.ch.wall_log[_oe_wall_seen][1]))
		_oe_wall_seen += 1
		shot("wallpost", _ai.ch._edge_aim, 0.9, 30.0)
		_later.append([c + 6.0, "wallpost_%s.png" % _mmss(c + 6.0), _ai.ch._edge_aim])
		if not noshots:
			clip("wallpost", _ai.ch._edge_aim, 40, 6, 1.0)
	while _oe_edge_seen < _ai.ch.edge_log.size():
		_ev("EDGE: " + String(_ai.ch.edge_log[_oe_edge_seen][1]))
		_oe_edge_seen += 1
	while _oe_prod_seen < _ai.prod_log.size():
		var e: Array = _ai.prod_log[_oe_prod_seen]
		_oe_prod_seen += 1
		_ev("more production: %s (income %d/min, production spends %d/min)" % [String(e[1]), int(e[2]), int(e[3])])
	while _oe_sup_seen < _ai.supply_log.size():
		_ev("%d Cottages started at once" % int(_ai.supply_log[_oe_sup_seen][1]))
		_oe_sup_seen += 1
	for at in [240.0, 300.0, 360.0, 420.0]:
		if c >= at and not _nat_share.has(at):
			var best := -1.0
			for id in _ai.xw.plans:
				var p: Dictionary = _ai.xw.plans[id]
				if p.get("ok", false):
					best = maxf(best, _ai.xw.closed_share(p))
			_nat_share[at] = best
	if _main_i < MAIN_AT.size() and c >= MAIN_AT[_main_i]:
		_main_i += 1
		var mh: Building = _ai.main_hall()
		if mh != null and not noshots:
			pending.append(["main_%s.png" % _mmss(c), mh.center() + Vector2(0, 2 * Defs.TILE), 0.62])
			for h in halls:
				if h != mh and h.built:
					pending.append(["nat_%s.png" % _mmss(c), h.center(), 0.7])
					break
	if c >= _own_next:
		_own_next += 60.0
		_own_line(c)
	if _dump_i < DUMP_AT.size() and c >= DUMP_AT[_dump_i]:
		_dump_i += 1
		_dump(c)


func _shoot() -> void:
	if noshots:
		pending.clear()
		return
	super._shoot()


## The main's ground (34 tiles round its start), our buildings there and the layout's planned blocks, for a picture.
func _dump(c: float) -> void:
	var st: Vector2i = g.starts[me]
	var r := 34
	var x0 := maxi(0, st.x - r)
	var y0 := maxi(0, st.y - r)
	var x1 := mini(Game.W, st.x + r)
	var y1 := mini(Game.H, st.y + r)
	var rows: Array = []
	var h0 := int(g.height[g.idx(st + Vector2i(2, 2))])
	for y in range(y0, y1):
		var row := ""
		for x in range(x0, x1):
			var i: int = g.idx(Vector2i(x, y))
			if g.ramp[i] == 1:
				row += "r"
			elif g.water.size() > i and g.water[i] != 0:
				row += "w"
			elif int(g.solid[i]) == 1:
				row += "#"
			elif int(g.height[i]) == h0:
				row += "h"
			else:
				row += "."
		rows.append(row)
	var bl: Array = []
	for b in g.buildings:
		if b.team != me or b.dead:
			continue
		if b.cell.x < x0 - 6 or b.cell.y < y0 - 6 or b.cell.x > x1 or b.cell.y > y1:
			continue
		bl.append({"k": b.kind, "x": b.cell.x - x0, "y": b.cell.y - y0, "w": b.size.x, "h": b.size.y, "built": b.built})
	var plan: Array = []
	if _ai.lay != null:
		for e in _ai.lay.rects():
			var rr: Rect2i = e[0]
			plan.append({"k": e[1], "x": rr.position.x - x0, "y": rr.position.y - y0, "w": rr.size.x, "h": rr.size.y})
	var f := FileAccess.open(out.path_join("base_%s.json" % _mmss(c)), FileAccess.WRITE)
	f.store_string(JSON.stringify({"t": _mmss(c), "map": map, "owner": _ai.owner_on(), "rows": rows, "buildings": bl, "plan": plan}))
	f.close()


func _ev(s: String) -> void:
	ev_lines.append("%s %s" % [_mmss(g.clock), s])


func _own_line(c: float) -> void:
	var a: AICrown = _ai
	own_lines.append("| %s | %d | %d | %d | %d / %d | %d | %d | %d | %d / %d / %d | %d / %d | %d | %d |" % [_mmss(c), g.workers(me).size(),
		int(g.stats[me]["gold"]), g.army_value(me), g.supply_used(me), int(g.players[me]["cap"]), int(blocked), int(blocked_gold),
		int(g.players[me]["gold"]), a._mine("barracks").size(), a._mine("foundry").size(), a._mine("church").size(),
		a._mine("powder_mill").size(), a._halls().size(), a._mine("cottage").size(), int(a.income())])


func _finish() -> void:
	super._finish()
	if _ai == null:
		return
	var f := FileAccess.open(out.path_join("owner.txt"), FileAccess.WRITE)
	f.store_line("%s %s v %s %s, seed %d, crown slot %d, owner rules %s" % [map, coach_plan, fb, sb, seed_, me, str(_ai.owner_on())])
	f.store_line("| time | labourers | gold earned | army value | supply | blocked s | blocked with 300+ gold s | bank | Barracks / Foundry / Church | Mills / halls | Cottages | income/min |")
	f.store_line("|---|---|---|---|---|---|---|---|---|---|---|---|")
	for l in own_lines:
		f.store_line(l)
	f.store_line("2nd hall laid %s done %s | first Barracks %s (%s) | first palisade at a new hall %s | natural wall closed 4:00 %.2f 5:00 %.2f 6:00 %.2f 7:00 %.2f | wall post moves %d | edge moves %d" % [
		_mmss(hall2_laid) if hall2_laid >= 0 else "-", _mmss(hall2_done) if hall2_done >= 0 else "-", _mmss(barracks1) if barracks1 >= 0 else "-", barracks1_why,
		_mmss(pal_first) if pal_first >= 0 else "-", float(_nat_share.get(240.0, -1)), float(_nat_share.get(300.0, -1)), float(_nat_share.get(360.0, -1)), float(_nat_share.get(420.0, -1)),
		_ai.ch.wall_moves, _ai.ch.edge_moves])
	for l in ev_lines:
		f.store_line(l)
	f.close()
