extends SceneTree
## THE MARCHING BAND in a whole match (docs/marching_band.md): a Hard Crown computer against a Hard computer of another
## faction. The Crown computer's bands (AI._band: trained at the Armoury, then its Fifer and Piper trained there, who walk
## over and join (band-v2);
## MarchingBand.ai_tick: its place behind the line and its solos) are watched: when they are trained, when a musician
## first joins, the solos by instrument, how many soldiers its ring reaches in a solo, losses; the match must run.
##   godot --headless --fixed-fps 30 --script res://tools/test_marching_band_match.gd [-- map:<id> seed:<n> minutes:<m> vs:<faction> who:<level> plan:<strategy>]
var main: Node
var t := 0.0
var g
var fails := 0
var map := "ashford_crossing"
var seed_ := 4242
var minutes := 12.0
var vs := "brood"
var plan := "balanced"
var foe_who := "hard"
var researched := {}
var by_ins := {"drums": 0, "fife": 0, "pipes": 0}
var _lead_of := {}
var max_bands := 0
var _seen := {}
var band_at := -1.0
var hired := {}
var solos: Array = []
var covered: Array = []          # soldiers in the ring at each solo's start
var bands_seen := 0
var deaths := 0
var _next_note := 60.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("minutes:"):
			minutes = float(a.substr(8))
		elif a.begins_with("vs:"):
			vs = a.substr(3)
		elif a.begins_with("who:"):
			foe_who = a.substr(4)          # (the other side's level: easy / normal / hard)
		elif a.begins_with("plan:"):
			plan = a.substr(5)


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": plan},
			{"who": foe_who, "faction": vs, "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if g.clock >= _next_note:
		_next_note += 60.0
		var nb := 0
		for u in g.units:
			if u.team == 0 and not u.dead and u.kind == MarchingBand.KIND:
				nb += 1
		print("NOTE %3.0f s: Crown army %d, gold %d, bands %d" % [g.clock, g.army(0).size(), int(g.players[0]["gold"]), nb])
	for u in g.units:
		if u.team == 0 and not u.dead and u.kind == MarchingBand.KIND:
			for ins in ["fife", "pipes"]:
				if not researched.has(ins) and MarchingBand.has(u, ins):
					researched[ins] = g.clock
					print("JOINED a %s at %.0f s" % [ins, g.clock])
		elif u.team == 0 and not u.dead and MarchingBand.MUSICIANS.has(u.kind) and not hired.has(u):
			hired[u] = g.clock
			print("MUSICIAN %s out at %.0f s (%s)" % [u.kind, g.clock, u.order])
	var alive := 0
	for u in g.units:
		if not is_instance_valid(u) or u.kind != MarchingBand.KIND or u.team != 0:
			continue
		if u.dead:
			if _seen.has(u) and _seen[u] == true:
				_seen[u] = false
				deaths += 1
				print("BAND lost at %.0f s" % g.clock)
			continue
		alive += 1
		if not _seen.has(u):
			_seen[u] = true
			bands_seen += 1
			print("BAND #%d trained at %.0f s (%s)" % [bands_seen, g.clock, str(u.band.get("m", []))])
			if band_at < 0.0:
				band_at = g.clock
		var ld := MarchingBand.lead(u)
		if ld != "" and ld != String(_lead_of.get(u, "")):
			var n := 0
			for o in g.units_near(u.position, float(Defs.MARCHING_BAND["area"])):
				if MarchingBand.covers(u, o):
					n += 1
			solos.append([ld, snappedf(g.clock, 1.0)])
			covered.append(n)
			by_ins[ld] = int(by_ins[ld]) + 1
			print("BAND %s solo at %.0f s, %d soldiers in the ring" % [ld, g.clock, n])
		_lead_of[u] = ld
	max_bands = maxi(max_bands, alive)
	if g.clock >= minutes * 60.0 or g.over:
		check("the match ran (or ended)", true, "%.0f s, over %s" % [g.clock, g.over])
		check("the Crown computer trained a band at the Armoury", band_at >= 0.0, "at %.0f s; bands %d, at most %d at once, lost %d" % [band_at, bands_seen, max_bands, deaths])
		check("a musician it trained walked over and joined a band", not researched.is_empty(), str(researched))
		var avg := 0.0
		for n in covered:
			avg += n
		avg = avg / maxf(covered.size(), 1.0)
		check("it played solos", not solos.is_empty(), "%d solos %s (fife %d, pipes %d, drums %d), %.1f soldiers in the ring on average" % [solos.size(), str(solos.slice(0, 10)), by_ins["fife"], by_ins["pipes"], by_ins["drums"], avg])
		print("SUMMARY vs %s (%s) %s seed %d: band %.0f s, fife %s, pipes %s, bands %d (max %d, lost %d), solos fife %d pipes %d drums %d, ring %.1f, ended %.0f s over %s winner %s" % [vs, foe_who, map, seed_, band_at,
			str(researched.get("fife", -1)), str(researched.get("pipes", -1)), bands_seen, max_bands, deaths, by_ins["fife"], by_ins["pipes"], by_ins["drums"], avg, g.clock, g.over, str(g.get("winner"))])
		print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
		quit(1 if fails > 0 else 0)
	return false
