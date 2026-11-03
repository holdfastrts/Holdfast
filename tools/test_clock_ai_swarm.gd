extends SceneTree
## The Clockwork computer against a swarm of Raptors (clock-ai-swarm, docs/clockwork_ai_swarm.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_clock_ai_swarm.gd [-- map:<id> seed:<n> until:<s> swarm:off]
## A Hard Clockwork computer on the Rush plan against a Hard Brood computer on the Economy plan (the owner's playtest of
## 2026-11-01: Glimmerdeep, seed 123537401), for `until` game seconds (default 450). Prints the picture every 30 s, then:
##  1. AISwarm.is_body: Raptors are swarm bodies; Clock Soldiers, Springers and a Tyrant Sire are not
##  2. the Clockwork lays its Heavy Works by HEAVY_BY (it found "no room by its Mainsprings" all game in the playtest)
##  3. its first Pendulum is out by PEND_BY
##  4. no "rush: SUCCEEDED, N workers left and no defenders" while the Brood had an army (the 4:29 misread)
##  5. while a wave was out in the field (FAR from home), 2+ Winders were with it (within ESCORT_R of its middle) at least
##     ESCORT_SHARE of the time
## `swarm:off` plays the computer as before (expected to fail 2-5: the "before" picture).
const HEAVY_BY := 390.0
const PEND_BY := 450.0
const ESCORT_R := 320.0
const FAR := 1000.0         # (px from our start) a wave this far out is in the field
const ESCORT_SHARE := 0.5
const AISwarm := preload("res://scripts/ai_swarm.gd")
var main: Node
var t := 0.0
var g
var map := "glimmerdeep"
var seed_ := 123537401
var until := 450.0
var next_print := 30.0
var fails := 0
var heavy_t := -1.0
var pend_t := -1.0
var escort_max := 0
var far_n := 0              # (samples of a wave out in the field ...)
var far_ok := 0             # (... with 2+ Winders within ESCORT_R of its middle)
var cw = null
var checked_bodies := false
var log_path := ""


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("until:"):
			until = float(a.substr(6))
		elif a.begins_with("log:"):
			log_path = a.substr(4)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "rush"},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "economy"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if cw == null:
		for ai in g.ais:
			if ai.team == 0:
				cw = ai
		return false
	if heavy_t < 0.0 and g.buildings.any(func(b) -> bool: return b.team == 0 and not b.dead and b.kind == Defs.CW_HEAVY):
		heavy_t = g.clock
	if pend_t < 0.0 and g.units.any(func(u) -> bool: return u.team == 0 and not u.dead and u.kind == Defs.PENDULUM):
		pend_t = g.clock
	if not checked_bodies:
		for u in g.units:
			if u.team == 1 and not u.dead and u.kind == "raptor":
				checked_bodies = true
				_check(AISwarm.is_body(u), "a Raptor is a swarm body")
				for o in g.units:
					if o.team == 0 and not o.dead and not o.is_worker() and AISwarm.is_body(o):
						_check(false, "a %s is not a swarm body" % o.kind)
				for o in g.units:
					if o.team == 1 and not o.dead and o.kind != "raptor" and not o.is_worker() and AISwarm.is_body(o):
						_check(false, "a %s is not a swarm body" % o.kind)
				break
	if cw._attacking and Engine.get_physics_frames() % 15 == 0:
		var wave: Array = cw._wave_set.keys().filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
		if not wave.is_empty():
			var c := Vector2.ZERO
			for u in wave:
				c += u.position
			c /= wave.size()
			var home: Vector2 = Vector2(g.starts[0]) * Defs.TILE
			if c.distance_to(home) > FAR:
				var n := 0
				for w in g.workers(0):
					if w.position.distance_to(c) < ESCORT_R:
						n += 1
				escort_max = maxi(escort_max, n)
				far_n += 1
				if n >= 2:
					far_ok += 1
	if g.clock >= next_print:
		next_print += 30.0
		var counts := {}
		for u in g.units:
			if not u.dead:
				var k := "%d:%s" % [u.team, u.kind]
				counts[k] = counts.get(k, 0) + 1
		var val := [0.0, 0.0]
		for tm in 2:
			for u in g.army(tm):
				val[tm] += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("tension", 0))
		print("t=%d  army value CW %d / Brood %d  %s  attacking=%s escort=%d halls=%d" % [int(g.clock), int(val[0]), int(val[1]),
			str(counts), str(cw._attacking), cw._escort.size(), g.halls_of(0).size()])
	if g.clock >= until or g.over:
		_finish()
		return true
	return false


func _finish() -> void:
	var misread := false
	var no_room := 0
	for l in g.mlog.lines:
		if "workers left and no defenders" in l:
			misread = true
		if "finds no room for a Heavy Works" in l:
			no_room += 1
		if "P1 Clockwork" in l and ("Heavy Works" in l or "swarm" in l or "Pendulum" in l or "rush:" in l or "expan" in l):
			print("  log: " + l)
	print("Heavy Works laid at %s, first Pendulum at %s, \"no room\" lines %d, Winders with a wave in the field: 2+ in %d of %d samples (most %d)" % [
		_mm(heavy_t), _mm(pend_t), no_room, far_ok, far_n, escort_max])
	if log_path != "":
		var f := FileAccess.open(log_path, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(g.mlog.lines))
	_check(heavy_t >= 0.0 and heavy_t <= HEAVY_BY, "the Heavy Works is laid by %s" % _mm(HEAVY_BY))
	_check(pend_t >= 0.0 and pend_t <= PEND_BY, "the first Pendulum is out by %s" % _mm(PEND_BY))
	_check(not misread, "no \"workers left and no defenders\" verdict against the Brood")
	_check(far_n == 0 or float(far_ok) >= float(far_n) * ESCORT_SHARE, "2+ Winders with the wave in the field at least half the time")
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])


func _mm(s: float) -> String:
	if s < 0.0:
		return "never"
	return "%d:%02d" % [int(s) / 60, int(s) % 60]
