extends SceneTree
## The fight sounds' voice pool (late-game-sound, docs/late_game_sound.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_sound_pool.gd
## A big battle's din, played on Sfx's own clock (Sfx.test_clock), must never cut a sound still sounding except by
## taking a player on purpose (counted), never sound more than POOL_MAX at once or SAME_MAX copies of one sound, and
## a voice-tier sound always gets a player. The old shared players are run the same way for the numbers.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var sfx := Sfx.new()
	root.add_child(sfx)
	_run.call_deferred(sfx)


## A late battle's din: the sounds of the cinder steps log at its busiest seconds, ~25 a second.
const DIN := ["combat/clock_soldier_attack", "combat/clock_soldier_attack", "combat/clock_soldier_attack", "combat/springer_attack",
	"combat/musketeer_attack", "combat/musketeer_attack", "combat/cannon_attack", "combat/cannon_hit", "combat/crown_death",
	"combat/clock_soldier_death", "combat/pendulum_attack", "combat/great_winder_step", "work/hoe", "work/winder_crank"]


func _din(sfx: Sfx, legacy: bool) -> Dictionary:
	Sfx.legacy = legacy
	Sfx.n_started = 0
	Sfx.n_cut = 0
	Sfx.n_dropped = 0
	Sfx.n_stolen = 0
	Sfx.live_max = 0
	sfx._last.clear()
	sfx._starts.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	seed(7)
	var worst_same := 0
	var early_reuse := 0
	for ms in range(0, 60000, 33):          # a minute at 30 frames a second
		Sfx.test_clock = 100000 + ms
		for k in 2:                         # a couple of tries a frame (the cap and gaps keep ~20-25 a second)
			if rng.randf() < 0.5:
				var nm: String = DIN[rng.randi() % DIN.size()]
				var before := {}
				if not legacy:
					for i in sfx._pool.size():
						before[i] = sfx._pinfo[i].duplicate()
				var stolen0 := Sfx.n_stolen
				Sfx.play(nm)
				if not legacy and Sfx.n_stolen == stolen0:
					for i in before:
						var b: Array = before[i]
						if int(b[2]) > Sfx.test_clock and int(sfx._pinfo[i][1]) == Sfx.test_clock and sfx._pinfo[i] != b:
							early_reuse += 1
		if not legacy:
			var per := {}
			for x in sfx._pinfo:
				if int(x[2]) > Sfx.test_clock:
					per[x[0]] = int(per.get(x[0], 0)) + 1
			for v in per.values():
				worst_same = maxi(worst_same, v)
	return {"started": Sfx.n_started, "cut": Sfx.n_cut, "dropped": Sfx.n_dropped, "stolen": Sfx.n_stolen, "live_max": Sfx.live_max,
		"worst_same": worst_same, "early_reuse": early_reuse, "players": sfx._players.size() + sfx._pool.size()}


func _run(sfx: Sfx) -> void:
	check(not sfx._find("combat/clock_soldier_attack").is_empty(), "the fight sounds load")
	var old := _din(sfx, true)
	print("old shared players: ", old)
	var new := _din(sfx, false)
	print("voice pool:         ", new)
	check(old["cut"] > old["started"] / 4, "the old way cut many sounds short (%d of %d)" % [old["cut"], old["started"]])
	check(new["early_reuse"] == 0, "the pool never takes a sounding player without counting it")
	check(new["live_max"] <= Sfx.POOL_MAX, "at most %d sounding at once (%d)" % [Sfx.POOL_MAX, new["live_max"]])
	check(new["worst_same"] <= Sfx.SAME_MAX, "at most %d copies of one sound (%d)" % [Sfx.SAME_MAX, new["worst_same"]])
	check(new["stolen"] < new["started"] / 4, "players taken from sounding ones are rare (%d of %d)" % [new["stolen"], new["started"]])
	check(new["started"] >= old["started"] * 0.8, "the pool keeps most of the sounds (%d v %d)" % [new["started"], old["started"]])
	# a voice-tier sound always finds a player, even in a full pool
	Sfx.test_clock += 10
	var before := Sfx.n_started
	Sfx.play("horse/neigh")
	check(Sfx.n_started == before + 1 or sfx._find("horse/neigh").is_empty(), "a horse call gets a player in a full pool")
	Sfx.test_clock = -1
	Sfx.legacy = false
	print("FAILS %d" % fails)
	quit(1 if fails > 0 else 0)
