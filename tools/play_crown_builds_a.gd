extends "res://tools/play_crown_1.gd"
## THE DRAGOON RAIDS, COACHED AND FILMED (crown-builds-a, docs/crown_builds_a.md): tools/play_crown_1.gd plus the raids.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_crown_builds_a.gd -- \
##       coach:dragoon b:brood sb:economy map:red_coast seed:4291306512 out:/abs/dir end:720
## (coach:balanced and the other plans too: the same counts, for the comparison.) Adds:
##   <out>/raid.txt     the raid log (DragoonRaid.log_lines) and the totals: enemy workers killed by the whole Crown and by the
##                      raiders, value the raiders killed and lost, groups formed, strikes, leaves, home runs
##   the minute line    + "workers killed W (raid R) | raid killed V lost L | dragoons D (groups G)"
##   key moments        strike_MMSS.png (a group strikes at a site), leave_MMSS.png (it rides off a defender), raid_MMSS.png (a
##                      group on the ride), clip_first_strike (frames for a GIF: tools/play_brood_new_gif.py)
var _track := {}              # enemy Unit -> [worker?, value, hit by a raider?, hit by us?]
var _mine_track := {}         # our raider -> value
var wk_all := 0               # enemy workers killed by us
var wk_raid := 0              # ... by the raiders
var raid_kill := 0            # value the raiders killed
var raid_lost := 0            # value of raiders lost
var _scan_t := 0.0
var _rlog_seen := 0
var _raid_shot_t := -99.0
var wk_at := {}               # "4:00" -> [all, raid]


func _coach() -> void:
	super._coach()
	if g.clock - _scan_t >= 0.5:
		_scan_t = g.clock
		_scan()
	var dr = _ai.dr
	if dr == null:
		return
	while _rlog_seen < dr.log_lines.size():
		var e: Array = dr.log_lines[_rlog_seen]
		_rlog_seen += 1
		var txt := String(e[1])
		say("raid: " + txt)
		var gid := int(txt.get_slice(" ", 1)) if txt.begins_with("group ") else -1
		var grp = null
		for o in dr.groups:
			if int(o["id"]) == gid:
				grp = o
		if grp == null or (grp["units"] as Array).is_empty():
			continue
		var lead: Unit = grp["units"][0]
		if txt.contains("strikes at"):
			shot("strike", lead, 1.25, 25.0)
			clip("first_strike", lead, 30, 4, 1.3)
		elif txt.contains("rides off"):
			shot("leave", lead, 1.15, 25.0)
	if g.clock - _raid_shot_t > 70.0:
		for o in dr.groups:
			if String(o["state"]) == "ride" and not (o["units"] as Array).is_empty():
				_raid_shot_t = g.clock
				shot("raid", o["units"][0], 1.1, 60.0)
				break


func _scan() -> void:
	var dr = _ai.dr
	for u in g.units:
		if not is_instance_valid(u) or u.dead:
			continue
		if u.team == 1:
			var h = u.last_hitter
			var by_raid := false
			var by_us := false
			if is_instance_valid(h) and h is Unit and h.team == 0:
				by_us = true
				by_raid = dr != null and dr.ever.has(h)
			var old: Array = _track.get(u, [u.is_worker(), Game.unit_value(u), false, false])
			_track[u] = [u.is_worker(), Game.unit_value(u), by_raid or (bool(old[2]) and not by_us), by_us or bool(old[3])]
		elif u.team == 0 and dr != null and dr.ever.has(u):
			_mine_track[u] = Game.unit_value(u)
	for u in _track.keys():
		if is_instance_valid(u) and not u.dead:
			continue
		var e: Array = _track[u]
		_track.erase(u)
		if not bool(e[3]):
			continue
		if bool(e[0]):
			wk_all += 1
			if bool(e[2]):
				wk_raid += 1
		if bool(e[2]):
			raid_kill += int(e[1])
	for u in _mine_track.keys():
		if is_instance_valid(u) and not u.dead:
			continue
		raid_lost += int(_mine_track[u])
		_mine_track.erase(u)


func _minute() -> void:
	super._minute()
	var dr = _ai.dr
	var riders := g.army(0).filter(func(u: Unit) -> bool: return u.kind == "dragoon" or (u.kind == "musketeer" and u.auto_mount)).size()
	var extra := " | workers killed %d (raid %d) | raid killed %d lost %d | dragoons %d (groups %d)" % [wk_all, wk_raid, raid_kill, raid_lost, riders, dr.groups.size() if dr != null else 0]
	minutes[minutes.size() - 1] = String(minutes[minutes.size() - 1]) + extra
	wk_at[_mmss(g.clock)] = [wk_all, wk_raid]
	# (where the enemy's workers are: at a work site, at their hall / Mother, on the way; and how many we see)
	var at_site := 0
	var at_home := 0
	var seen := 0
	var n := 0
	for u in g.units:
		if not is_instance_valid(u) or u.dead or u.team != 1 or not u.is_worker():
			continue
		n += 1
		if g.is_visible_to(0, u.position):
			seen += 1
		var near_site := false
		var near_home := false
		for o in g.units_near(u.position, 260.0):
			if o.team == 1 and (o.kind == BroodNew.MAW):
				near_site = true
			if o.team == 1 and o.kind == BroodNew.QUEEN:
				near_home = true
		for b in g.buildings:
			if b.team == 1 and not b.dead and b.center().distance_to(u.position) < 260.0:
				if b.kind == g.faction_hall(1):
					near_home = true
				elif Defs.is_econ(b.kind):
					near_site = true
		if near_home:
			at_home += 1
		elif near_site:
			at_site += 1
	minutes[minutes.size() - 1] = String(minutes[minutes.size() - 1]) + " | enemy workers %d: at a site %d, at home %d, between %d, seen %d" % [n, at_site, at_home, n - at_site - at_home, seen]
	print("RAID " + extra)


func _finish() -> void:
	super._finish()
	var f := FileAccess.open(out.path_join("raid.txt"), FileAccess.WRITE)
	var dr = _ai.dr if _ai else null
	f.store_line("plan %s | workers killed %d (by the raiders %d) | raid value killed %d lost %d" % [coach_plan, wk_all, wk_raid, raid_kill, raid_lost])
	if dr != null:
		f.store_line("groups %d strikes %d leaves %d homes %d" % [int(dr.stats["groups"]), int(dr.stats["strikes"]), int(dr.stats["leaves"]), int(dr.stats["homes"])])
		for e in dr.log_lines:
			f.store_line("%s %s" % [_mmss(float(e[0])), String(e[1])])
	f.close()
