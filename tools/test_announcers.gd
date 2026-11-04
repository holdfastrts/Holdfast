extends SceneTree
## The announcer lines (docs/announcers.md):
##  - every line of the standard set exists for the Crown, the Clockwork and the Brood (assets/voice/announcer/<crown|clock|brood>/<key>.ogg),
##    and each faction's own extra lines for it;
##  - every line the game names in an Sfx.announce(...) call, or as a `line := / line = "..."` in Game.under_attack,
##    is in the standard set or in some faction's extras (a new key added without its recordings fails here);
##  - the Crown's and the Brood's recorded lines play in English in every language (Sfx.english_only), the Clockwork's not.
## Prints a FAIL line for each problem and "announcers: N checks, M failures".
##   godot --headless --script res://tools/test_announcers.gd
const STANDARD := ["unit_ready", "building_done", "research_done", "under_attack", "base_attack", "workers_attack",
	"ally_attack", "expansion", "building_lost", "site_lost", "bad_place", "no_gold", "no_res2", "no_supply",
	"depleted", "victory", "defeat", "paused", "resumed"]
const EXTRA := {"crown": ["no_powder", "horse_stolen"], "clock": [], "brood": ["mother_attack", "sire_lost"]}
var fails := 0
var checked := 0


func _fail(s: String) -> void:
	fails += 1
	print("FAIL ", s)


func _initialize() -> void:
	for fac in EXTRA:
		for key in STANDARD + EXTRA[fac]:
			checked += 1
			var p := "res://assets/voice/announcer/%s/%s.ogg" % [fac, key]
			if not ResourceLoader.exists(p):
				_fail("missing %s" % p)
			elif not (load(p) is AudioStream):
				_fail("not a sound: %s" % p)
	var known := STANDARD.duplicate()
	for fac in EXTRA:
		known.append_array(EXTRA[fac])
	var re := RegEx.new()
	re.compile("Sfx\\.announce\\([^,]+,\\s*\"([a-z_0-9]+)\"")
	var re2 := RegEx.new()
	re2.compile("\\bline :?= \"([a-z_0-9]+)\"")
	var re3 := RegEx.new()
	re3.compile("Sfx\\.announce\\([^,]+,\\s*\"([a-z_0-9]+)\" if [^\"]+ else \"([a-z_0-9]+)\"")
	var used := {}
	for path in _scripts("res://scripts"):
		var src := FileAccess.get_file_as_string(path)
		for r in [re, re2, re3]:
			for m in (r as RegEx).search_all(src):
				for i in range(1, m.get_group_count() + 1):
					if m.get_string(i) != "":
						used[m.get_string(i)] = path
	for key in used:
		checked += 1
		if not known.has(key):
			_fail("%s plays announcer line \"%s\", which has no recordings (add it to docs/announcers.md and here)" % [used[key], key])
	for key in ["mother_attack", "sire_lost", "no_powder", "horse_stolen", "base_attack", "under_attack"]:
		checked += 1
		if not used.has(key):
			_fail("no script plays \"%s\" any more" % key)
	for pair in [["voice/announcer/crown/victory", true], ["voice/announcer/brood/sire_lost", true],
			["voice/announcer/clock/victory", false], ["voice/musketeer/select", false]]:
		checked += 1
		if Sfx.english_only(pair[0]) != pair[1]:
			_fail("Sfx.english_only(%s) should be %s" % pair)
	print("announcers: %d lines named by the scripts: %s" % [used.size(), ", ".join(used.keys())])
	print("announcers: %d checks, %d failures" % [checked, fails])
	quit(1 if fails > 0 else 0)


func _scripts(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + "/" + d))
	return out
