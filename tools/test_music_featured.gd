extends SceneTree
## The featured music (job music-elevenlabs): the main menu starts with Crown of Ashes (Music.MENU_FIRST), the
## overture shuffle never plays a piece twice in a row and plays the featured theme about WEIGHT times a round, and a
## match's moods hand out featured pieces more often than generated ones without repeating the one just heard.
##   godot --headless --script res://tools/test_music_featured.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var m := Music.new()
	var first: String = m._next_menu()
	check(first == Music.MENU_FIRST, "the first overture is %s (%s)" % [Music.MENU_FIRST, first])
	var last := first
	var twice := false
	var count := {}
	for i in 400:
		var p: String = m._next_menu()
		twice = twice or p == last
		last = p
		count[p] = int(count.get(p, 0)) + 1
	check(not twice, "the menu never plays the same overture twice in a row")
	var others: Array = Music.menu_pieces().filter(func(s: String) -> bool: return s != Music.MENU_FIRST)
	var avg := 0.0
	for s in others:
		avg += float(count.get(s, 0)) / others.size()
	var r := float(count.get(Music.MENU_FIRST, 0)) / maxf(avg, 1.0)
	check(r > 2.0 and r < 4.0, "Crown of Ashes about %dx as often at the menu (%.2f)" % [int(Music.WEIGHT), r])
	check(others.all(func(s: String) -> bool: return count.get(s, 0) > 0), "every other overture still plays")
	# a match: the Crown's calm pool, as the game picks it
	m._faction = "crown"
	m.mode = "faction"
	var n := {}
	var prev := ""
	var rep := false
	for i in 3000:
		var p: String = m._next("peace")
		rep = rep or p == prev
		prev = p
		m._current = p
		n[p] = int(n.get(p, 0)) + 1
	check(not rep, "a calm piece never follows itself")
	var gen: Array = Music.pieces("crown", "peace").filter(func(s: String) -> bool: return not Music.FEATURED.has(s))
	var g := 0.0
	for s in gen:
		g += float(n.get(s, 0)) / gen.size()
	var rf := float(n.get("crown_peace_10", 0)) / maxf(g, 1.0)
	check(rf > 1.8, "Dawn Over the Colony plays more often than a generated calm piece (%.2fx)" % rf)
	check(gen.all(func(s: String) -> bool: return n.get(s, 0) > 0), "every generated calm piece still plays")
	m.free()
	print("%d failed" % fails if fails else "all passed")
	quit(1 if fails else 0)
