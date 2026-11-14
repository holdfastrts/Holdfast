extends SceneTree
## The music has a piece for every moment: for each faction the opening, skirmish, full battle and
## calm moods each have pieces, every piece named in scripts/music_tracks.gd has its file, and every
## piece given a role in Music.ROLES / OPEN_CALM is a real piece of that faction.
## The owner's ElevenLabs pieces (job music-elevenlabs) are checked in their roles, featured and loadable.
## The Clockwork's opening and skirmish pieces come with its own new set: until that set is in
## (no Clockwork piece has a role yet) those two checks are skipped, not failed.
##   godot --headless --script res://tools/test_music_roles.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var titles: Dictionary = Music.titles()
	check(titles.size() > 30, "music_tracks.gd lists the pieces (%d)" % titles.size())
	# every listed piece has its file (and an import, so the game can load it)
	var missing: Array = []
	for stem in titles:
		var path: String = Music.MUSIC_PATH % stem
		if not FileAccess.file_exists(path) or not FileAccess.file_exists(path + ".import"):
			missing.append(stem)
	check(missing.is_empty(), "every piece in music_tracks.gd has its .ogg and .import %s" % str(missing))
	# roles name real pieces, of a known kind
	for stem in Music.ROLES:
		check(titles.has(stem), "ROLES names a listed piece: " + stem)
		check(Music.ROLES[stem] in ["open", "skirmish"], "ROLES gives %s a known role" % stem)
		check(String(stem).contains("_battle"), "a role piece is a battle piece: " + stem)
	for stem in Music.OPEN_CALM:
		check(titles.has(stem) and String(stem).contains("_peace"), "OPEN_CALM names a calm piece: " + stem)
	# every faction has pieces for every mood
	for f in ["crown", "brood", "clock"]:
		var has_roles := false
		for stem in Music.ROLES:
			if String(stem).begins_with(f + "_"):
				has_roles = true
		for mood in ["open", "skirmish", "battle", "peace"]:
			var got: Array = Music.pieces(f, mood)
			if (mood == "open" or mood == "skirmish") and f == "clock" and not has_roles and got.is_empty():
				print("SKIP  %s %s: the Clockwork's new set is not in yet" % [f, mood])
				continue
			check(not got.is_empty(), "%s has %s pieces (%d): %s" % [f, mood, got.size(), ", ".join(got)])
		# a skirmish or opening piece never turns up as the full battle
		for stem in Music.pieces(f, "battle"):
			check(not Music.ROLES.has(stem), "%s full battle pool has no role piece (%s)" % [f, stem])
	# the Brood's twenty generated pieces in the Crown's shape, plus the owner's four ElevenLabs pieces (one per mood)
	check(Music.all_pieces("brood").size() == 24, "the Brood has 24 pieces (%d)" % Music.all_pieces("brood").size())
	check(Music.pieces("brood", "open").size() >= 3, "the Brood has its three opening pieces")
	check(Music.pieces("brood", "skirmish").size() == 4, "the Brood has four skirmish pieces")
	check(Music.pieces("brood", "battle").size() == 9, "the Brood has nine full battle pieces")
	check(Music.pieces("brood", "peace").size() == 8, "the Brood has eight calm pieces")
	# the ElevenLabs pieces (job music-elevenlabs): each in its role, featured, and the menu theme heard first
	var want := {"crown_battle_12": "open", "crown_battle_13": "skirmish", "crown_battle_14": "battle",
		"crown_peace_10": "peace", "clock_battle_14": "open", "clock_battle_15": "skirmish",
		"clock_battle_16": "battle", "clock_peace_8": "peace", "brood_battle_14": "open",
		"brood_battle_15": "skirmish", "brood_battle_16": "battle", "brood_peace_8": "peace"}
	for stem in want:
		var fk: String = String(stem).get_slice("_", 0)
		check(Music.pieces(fk, want[stem]).has(stem), "%s plays as %s %s" % [stem, fk, want[stem]])
		check(Music.FEATURED.has(stem), "%s is featured" % stem)
	check(Music.menu_pieces().has("menu_11") and Music.MENU_FIRST == "menu_11", "Crown of Ashes is a menu piece, heard first")
	for stem in Music.FEATURED:
		check(titles.has(stem), "FEATURED names a listed piece: " + stem)
		var st: Variant = load(Music.MUSIC_PATH % stem)
		check(st is AudioStreamOggVorbis and not (st as AudioStreamOggVorbis).loop and (st as AudioStream).get_length() > 50.0,
			"%s loads, plays once (no loop), %.0f s" % [stem, (st as AudioStream).get_length() if st else 0.0])
	# the weighted pick: a featured piece about WEIGHT times as often as a generated one
	var pool: Array = ["crown_battle_14", "crown_battle", "crown_battle_2", "crown_battle_3"]
	var n := {}
	for i in 4000:
		var s: String = Music._weighted(pool)
		n[s] = int(n.get(s, 0)) + 1
	var ratio: float = float(n.get("crown_battle_14", 0)) / maxf(1.0, float(n.get("crown_battle", 0)))
	check(ratio > 2.2 and ratio < 4.0, "a featured piece is picked about %.0fx as often (%.2f)" % [Music.WEIGHT, ratio])
	print("%d failed" % fails if fails else "all passed")
	quit(1 if fails else 0)
