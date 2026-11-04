extends "res://tools/play_crown_1.gd"
## THE CROWN COMPUTER AGAINST THE BROOD, COACHED AND FILMED (docs/crown_v_brood.md). Everything of tools/play_crown_1.gd
## (coach:<plan> cslot:1 b:brood sb:<brood plan> map: seed: out: end:) plus:
##   ramp_MMSS.png      the main's ramp wall at 1:30, 4:00 and 7:00 (the wall's cells and their state go to wall.txt)
##   natural_MMSS.png   the second hall a few seconds after it is laid
##   summary.txt        one line of numbers for the tables: halls lost, labourers lost, gold earned by 8:00, army at 6:00 /
##                      8:00 (ours, the enemy's mobile army), the first attack out (time, supply, what it knew), the enemy's
##                      first arrival at our second hall, the natural variant (A / B)
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_crown_v_brood.gd -- \
##       coach:economy cslot:1 b:brood sb:economy map:redrock_canyon seed:2554909278 out:/abs/dir end:600 [-- nat:corner]
const RAMP_AT := [90.0, 240.0, 420.0]
var _ramp_i := 0
var _labs_seen := {}
var labs_lost := 0
var halls_lost := 0
var earned_8 := -1
var army_6 := [-1, -1]
var army_8 := [-1, -1]
var first_att := ""
var raid_arrive := -1.0
var _nat_shot := false
var wall_lines: Array = []
var _band0 := {}


func _coach() -> void:
	super._coach()
	var c: float = g.clock
	if _band0.is_empty():
		var bands: Array = _ai._ramp_bands()        # (once, before anything stands on the ramp's band)
		_band0 = bands[0] if not bands.is_empty() else {"band": [], "mid": Vector2(CrownSites.ramp_of(g, me).get("top", Vector2.ZERO))}
	if _ramp_i < RAMP_AT.size() and c >= RAMP_AT[_ramp_i]:
		_ramp_i += 1
		var mid: Vector2 = (_band0["mid"] as Vector2 + Vector2(0.5, 0.5)) * Defs.TILE
		pending.append(["ramp_%s.png" % _mmss(c), mid, 1.6])
		_wall_note(_band0)
	for u in g.workers(me):
		_labs_seen[u] = true
	for u in _labs_seen.keys():
		if not is_instance_valid(u) or u.dead:
			_labs_seen.erase(u)
			labs_lost += 1
	if earned_8 < 0 and c >= 480.0:
		earned_8 = int(g.stats[me]["gold"])
		army_8 = [g.army_value(me), _mobile(fo)]
	if army_6[0] < 0 and c >= 360.0:
		army_6 = [g.army_value(me), _mobile(fo)]
	if first_att == "" and _ai._attacking:
		var ch = _ai.ch
		first_att = "%s supply %d knew %d (seen %s)" % [_mmss(c), _ai._army_supply(_ai._wave_set.keys().filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)),
			int(ch.foe_known()), ("%d s ago" % int(c - ch._last_army_t)) if ch._last_army_t > 0.0 else "never"]
	if not _nat_shot:
		for h in _ai._halls():
			if h.center().distance_to(_home()) > 10.0 * Defs.TILE:
				_nat_shot = true
				_later.append([c + 8.0, "natural_%s.png" % _mmss(c), h])
	if raid_arrive < 0.0:
		for h in _ai._halls():
			if h.center().distance_to(_home()) > 10.0 * Defs.TILE:
				for o in g.units_near(h.center(), 9.0 * Defs.TILE):
					if o.team == fo and not o.dead and not o.is_worker() and not BroodNew.is_nb(o.kind):
						raid_arrive = c
						break


func _mobile(t: int) -> int:
	var v := 0
	for u in g.army(t):
		if u.dead or u.is_worker() or BroodNew.is_nb(u.kind) or u.kind in ["brood_mother", "rootmaw", "mound_turtle", "egg"]:
			continue
		v += Game.unit_value(u)
	return v


func _wall_note(b0: Dictionary) -> void:
	var cells: Array = []
	for c in b0["band"]:
		var w = g._own_wall_at(me, c)
		var gt = g._own_gate_at(me, c)
		cells.append("%s:%s" % [str(c), "gate" if gt != null else ("wall" if w != null else ("free" if g.is_free(c) else "building"))])
	wall_lines.append("%s band %d: %s" % [_mmss(g.clock), (b0["band"] as Array).size(), ", ".join(cells)])


func _finish() -> void:
	super._finish()
	if _ai == null:
		return
	for h in _halls_seen.keys():
		if is_instance_valid(h) and h.dead and h.built:
			halls_lost += 1
	var f := FileAccess.open(out.path_join("summary.txt"), FileAccess.WRITE)
	f.store_line("end %s | halls lost %d | labourers lost %d | gold earned by 8:00 %d | army 6:00 %d v %d mobile | army 8:00 %d v %d mobile | first attack %s | enemy at our 2nd hall %s | natural %s | over %s winner %s" % [
		_mmss(g.clock), halls_lost, labs_lost, earned_8, army_6[0], army_6[1], army_8[0], army_8[1], first_att if first_att != "" else "-",
		_mmss(raid_arrive) if raid_arrive >= 0.0 else "-", "B (corner)" if OS.get_cmdline_user_args().has("nat:corner") else "A (ramp)", str(g.over), str(g.get("winner"))])
	for l in wall_lines:
		f.store_line(l)
	f.close()
