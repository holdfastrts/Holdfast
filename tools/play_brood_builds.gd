extends "res://tools/play_brood_3.gd"
## THE BROOD'S WRITTEN BUILDS COACHED (brood-builds, docs/brood_builds.md): the Brood computer on SPITTER TIMING or BRUTE
## SIEGE (sb2:spitter / sb2:brute; or sb2:balanced for the comparison) against the Hard Crown or Clockwork, filmed.
## Everything of tools/play_brood_3.gd (the Mother every 3 minutes, fights, waves, the Sires, minutes.txt, the match log)
## plus the build's push filmed:
##   push_out_MMSS.png (the push leaving, 12 s after), clip_push_N (a GIF's frames: tools/play_brood_new_gif.py),
##   push_contact_MMSS.png (the timing's contact, 6 s after), push_break_MMSS.png (the Brutes at the barrier, 10 s after),
##   push_breach_MMSS.png (5 s after the breach), push_back_MMSS.png
##   <out>/builds.txt: the economy at 4/6/8/10 min (food earned, grubs, turtles on new ground, army value, both sides),
##   then one line a push: when it left, its supply and kinds, its Spitters and Brutes, contact, breach, what it broke,
##   value killed, when and why it ended; then the result.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_brood_builds.gd -- \
##       coach:ai sb2:spitter b:crown map:greenhold seed:3 out:/abs/dir end:780

var _logs_seen := 0
var _pushes_n := 0
var _eco_lines: Array = []
var _eco_at := [240.0, 360.0, 480.0, 600.0]


func _process(delta: float) -> bool:
	var r := super._process(delta)
	if g != null and not g.over and _ai != null and _ai.bb != null:
		_watch_push()
	if g != null and not _eco_at.is_empty() and g.clock >= float(_eco_at[0]):
		_eco_at.pop_front()
		_eco_line()
	return r


func _lead() -> Unit:
	var best: Unit = null
	for u in _ai._wave:
		if is_instance_valid(u) and not u.dead:
			if best == null or (u.kind == "brute" and best.kind != "brute") or (u.kind in ["spitter", "venom_challenger"] and best.kind == "raptor"):
				best = u
	return best


func _watch_push() -> void:
	var bb = _ai.bb
	while _logs_seen < bb.log.size():
		var s := String(bb.log[_logs_seen][1])
		_logs_seen += 1
		var lead := _lead()
		var at = lead if lead != null else (bb.barrier_p if bb.barrier_p != Vector2.INF else null)
		if at == null:
			continue
		if s.contains("goes out"):
			_pushes_n += 1
			_later.append([g.clock + 12.0, "push_out_%s.png" % _mmss(g.clock), at])
			if _pushes_n <= 2:
				clip("push_%d" % _pushes_n, lead, 30, 6, 1.0)
		elif s.contains("contact"):
			_later.append([g.clock + 6.0, "push_contact_%s.png" % _mmss(g.clock), at])
			clip("contact_%d" % _pushes_n, lead, 24, 4, 1.1)
		elif s.contains("batter"):
			_later.append([g.clock + 10.0, "push_break_%s.png" % _mmss(g.clock), bb.barrier_p if bb.barrier_p != Vector2.INF else at])
			clip("break_%d" % _pushes_n, bb.barrier_p if bb.barrier_p != Vector2.INF else lead, 30, 5, 1.1)
		elif s.contains("BREACH"):
			_later.append([g.clock + 5.0, "push_breach_%s.png" % _mmss(g.clock), at])
		elif s.contains("falls back"):
			_later.append([g.clock + 2.0, "push_back_%s.png" % _mmss(g.clock), at])


func _eco_line() -> void:
	var q := BroodNew.queen(g, 0)
	var val := 0
	for u in army():
		val += Game.unit_value(u)
	var fv := 0
	for u in g.army(1):
		if not u._k_nb:
			fv += Game.unit_value(u)
	_eco_lines.append("%s food earned %d (foe %d) | grubs %d | turtles on new ground %d | stage %d | army %d (%s) | foe army %d" % [
		_mmss(g.clock), int(g.stats[0]["gold"]), int(g.stats[1]["gold"]), BroodNew.count_of(g, 0, "grub"),
		BroodNew.expansions(g, q).size() if q else 0, (BroodNew.stage(q) + 1) if q else 0, val, _kinds(army()), fv])


func _finish() -> void:
	super._finish()
	var f := FileAccess.open(out.path_join("builds.txt"), FileAccess.WRITE)
	f.store_line("plan %s (%s), brood v %s, %s seed %d" % [strat2, coach_plan, fb, map, seed_])
	for l in _eco_lines:
		f.store_line(l)
	if _ai != null and _ai.bb != null:
		for p in _ai.bb.pushes:
			f.store_line("push %s | %d supply (%s) | spitters %d brutes %d | contact %s | breach %s | broke %s | killed %d | end %s %s" % [
				_mmss(float(p["t0"])), int(p["sup"]), p["kinds"], int(p["spitters"]), int(p["brutes"]),
				_mmss(float(p["contact"])) if float(p["contact"]) >= 0.0 else "-", _mmss(float(p["breach"])) if float(p["breach"]) >= 0.0 else "-",
				str(p["broke"]), int(p.get("killed", int(g.stats[0]["value_killed"]) - int(p["k0"]))),
				_mmss(float(p["end"])) if float(p["end"]) >= 0.0 else "-", p["why"]])
		for l in _ai.bb.log:
			f.store_line("%s %s" % [_mmss(float(l[0])), l[1]])
	var waves := (_ai.note if _ai else []).filter(func(n) -> bool: return String(n[1]).begins_with("attacks with") or String(n[1]).begins_with("pulls back"))
	for n in waves:
		f.store_line("%s %s" % [_mmss(float(n[0])), n[1]])
	f.store_line("result: over %s winner %d at %s | value killed %d lost %d | earned %d foe %d" % [str(g.over), g.winner, _mmss(g.clock),
		int(g.stats[0]["value_killed"]), int(g.stats[1]["value_killed"]), int(g.stats[0]["gold"]), int(g.stats[1]["gold"])])
	f.close()
