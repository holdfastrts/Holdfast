extends "res://tools/play_crown_1.gd"
## THE BALLOON HARASS, COACHED AND FILMED (crown-builds-c, docs/crown_builds_c.md): tools/play_crown_1.gd (everything it
## films and writes) plus the balloon parties of scripts/ai_crown_balloon.gd:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_crown_c.gd -- \
##       coach:balloon b:brood sb:timing map:red_coast seed:4291306512 out:/abs/dir [end:780] [db:hard]
##   bl_form_MMSS.png    the first party forming at home (the men walking to the basket)
##   bl_fly_MMSS.png     a party on its way (the first two flights)
##   bl_strike_MMSS.png  a party over its target (the first three strikes), and a clip of the first (clip_bl_strike_NN.png)
##   bl_drop_MMSS.png    men on the ground (the first two drops), bl_lift_MMSS.png the lift out
##   bl_split_MMSS.png   two parties at two targets at once (a picture of each)
##   bl_defend_MMSS.png  a party firing down on an attack at home
##   bl_down_MMSS.png    a balloon shot down (where it fell)
##   harass.txt          the harass's numbers (also on every minute line) and its log
## (with coach:balanced etc. the same tool films the other plans, so the comparison games are made the same way)

var _bl_seen := 0
var _shot_n := {}
var _split_t := -999.0
var bl_minutes: Array = []


func _bl():
	return _ai.bl if _ai != null else null


func _count(kind: String, most: int) -> bool:
	var n := int(_shot_n.get(kind, 0))
	if n >= most:
		return false
	_shot_n[kind] = n + 1
	return true


func _coach() -> void:
	super._coach()
	var bl = _bl()
	if bl == null:
		return
	while _bl_seen < bl.log_lines.size():
		var e: Array = bl.log_lines[_bl_seen]
		_bl_seen += 1
		var s := String(e[1])
		say("harass: " + s)
		var p := _party_of(bl, s)
		var b: Unit = p["b"] if not p.is_empty() and is_instance_valid(p["b"]) else null
		if s.contains("forms") and b and _count("form", 1):
			_later.append([g.clock + 8.0, "bl_form_%s.png" % _mmss(g.clock), b])
		elif s.contains("flies to") and b and _count("fly", 2):
			_later.append([g.clock + 12.0, "bl_fly_%s.png" % _mmss(g.clock), b])
		elif s.contains("hovers over") and not s.contains("attack at home") and b and _count("strike", 3):
			_later.append([g.clock + 5.0, "bl_strike_%s.png" % _mmss(g.clock), b])
			clip("bl_strike", b, 30, 5, 1.2)
		elif s.contains("drops its men") and b and _count("drop", 2):
			_later.append([g.clock + 6.0, "bl_drop_%s.png" % _mmss(g.clock), b])
			clip("bl_drop", b, 30, 5, 1.2)
		elif s.contains("lifts its men") and b and _count("lift", 2):
			_later.append([g.clock + 4.0, "bl_lift_%s.png" % _mmss(g.clock), b])
		elif s.contains("attack at home") and b and _count("defend", 2):
			_later.append([g.clock + 6.0, "bl_defend_%s.png" % _mmss(g.clock), b])
		elif s.contains("balloon is down") and _count("down", 2):
			shot("bl_down", _foe_home() if b == null else b.position, 1.0, 5.0)
	# two parties striking at two places at once
	var striking: Array = (bl.parties as Array).filter(func(p: Dictionary) -> bool: return String(p["phase"]) in ["strike", "ground", "drop"])
	if striking.size() >= 2 and g.clock - _split_t > 120.0 and _count("split", 2):
		_split_t = g.clock
		var a: Vector2 = (striking[0]["b"] as Unit).position
		var c: Vector2 = (striking[1]["b"] as Unit).position
		say("harass: two parties strike at once, %d tiles apart" % int(a.distance_to(c) / Defs.TILE))
		pending.append(["bl_split_%s_a.png" % _mmss(g.clock), a, 1.1])
		pending.append(["bl_split_%s_b.png" % _mmss(g.clock), c, 1.1])


func _party_of(bl, s: String) -> Dictionary:
	for p in bl.parties:
		if s.begins_with("party %d " % int(p["id"])) or s.contains("party %d " % int(p["id"])) or s.contains("party %d'" % int(p["id"])):
			return p
	return {}


func _minute() -> void:
	super._minute()
	var bl = _bl()
	if bl == null:
		return
	var l := "%s harass: balloons %d, parties %d (%s) | %s" % [_mmss(g.clock), bl.balloons().size(), bl.parties.size(),
		", ".join((bl.parties as Array).map(func(p: Dictionary) -> String: return "%d:%s/%d" % [int(p["id"]), String(p["phase"]), (p["men"] as Array).size()])),
		bl.summary()]
	bl_minutes.append(l)
	print("BLM " + l)


func _finish() -> void:
	super._finish()
	var bl = _bl()
	var f := FileAccess.open(out.path_join("harass.txt"), FileAccess.WRITE)
	if bl != null:
		f.store_line("SUMMARY " + bl.summary())
		for l in bl_minutes:
			f.store_line(l)
		for e in bl.log_lines:
			f.store_line("%s %s" % [_mmss(float(e[0])), String(e[1])])
	f.close()
