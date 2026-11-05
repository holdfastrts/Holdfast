## THE MIST TOAD's spells behind research (the owner, 2026-11-05; docs/marching_band.md "The Mist Toad"): FOG and MIASMA
## are researched at the Venom Sire (the Dilophosaurus, Defs.RESEARCH nb_fog / nb_miasma, the Brood Mother's stage 3 like
## the Toad); TONGUE is free. A Toad with energy can't cast FOG or MIASMA until it's researched (Game.spell_problem), can
## after; the research is the Brood's (BroodResearch at the Dilophosaurus).
##   godot --headless --fixed-fps 30 --script res://tools/test_toad_research.gd
extends SceneTree
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-66s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for k in ["nb_fog", "nb_miasma"]:
		check("%s is a Brood research at the Venom Sire" % k, Defs.RESEARCH.has(k) and String(Defs.RESEARCH[k]["at"]) == "dilophosaurus" and String(Defs.RESEARCH[k]["faction"]) == "brood")
		check("%s needs the Mother's stage 3, as the Toad" % k, int(Defs.RESEARCH[k].get("stage", 0)) == BroodNew.unit_stage("mist_toad"), str(Defs.RESEARCH[k].get("stage")))
		check("%s is cheap and quick" % k, int(Defs.RESEARCH[k]["cost"]) <= 75 and float(Defs.RESEARCH[k]["time"]) <= 30.0)
	check("the Venom Sire's research list has them", BroodResearch.keys_at("dilophosaurus").has("nb_fog") and BroodResearch.keys_at("dilophosaurus").has("nb_miasma"))
	check("no research for TONGUE", Game.spell_research("tongue") == "" and Game.spell_research("fog") == "nb_fog" and Game.spell_research("miasma") == "nb_miasma")
	var g := Game.new()
	g.map_id = "ashford_crossing"
	g.demo = true
	g.factions = ["brood", "crown"]
	g.sides = [0, 1]
	root.add_child(g)
	await process_frame
	await process_frame
	var at := Vector2(1600, 1600)
	var toad: Unit = g._add_unit("mist_toad", 0, at)
	toad.charge = 200.0
	check("FOG refused before the research", g.spell_problem(toad, "fog") != "", g.spell_problem(toad, "fog"))
	check("MIASMA refused before the research", g.spell_problem(toad, "miasma") != "", g.spell_problem(toad, "miasma"))
	var foe: Unit = g._add_unit("musketeer", 1, at + Vector2(80, 0))
	check("TONGUE needs no research", toad.can_tongue(foe) if toad.has_method("can_tongue") else true)
	g.players[0]["tech"]["nb_fog"] = true
	check("FOG once researched", g.spell_problem(toad, "fog") == "", g.spell_problem(toad, "fog"))
	check("MIASMA still locked", g.spell_problem(toad, "miasma") != "")
	g.players[0]["tech"]["nb_miasma"] = true
	check("MIASMA once researched", g.spell_problem(toad, "miasma") == "", g.spell_problem(toad, "miasma"))
	# the Brood computer wants them once it has Toads (the source: its research list puts them first)
	var src := FileAccess.get_file_as_string("res://scripts/ai_brood_new.gd")
	check("the Brood computer researches FOG and MIASMA once it has Toads", src.contains("want.push_front(\"nb_fog\")") and src.contains("line.call(\"mist_toad\") >= 1"))
	print("toad research: %d failures" % fails)
	quit(1 if fails > 0 else 0)
