extends SceneTree
## How fast this machine runs GDScript (docs/perf_armies.md): a fixed piece of work much like a unit's tick (dictionary
## look-ups by text, float and vector sums, little calls on an object, arrays walked), timed five times, the fastest kept.
## tools/test_perf_armies.sh divides the units' ms a tick by it, so the check means the same on a slow and a fast machine.
##   godot --headless --script res://tools/perf_calib.gd        -> "CALIB <ms>"


class Dummy:
	var d := {"speed": 80.0, "range": 20.0, "sight": 8, "damage": 6.0, "kind": "raptor"}
	var position := Vector2(100, 100)
	var velocity := Vector2.ZERO
	var hp := 50.0
	var team := 1

	func step(delta: float, others: Array) -> float:
		var speed := float(d["speed"])
		if String(d["kind"]) == "raptor":
			speed *= 1.1
		var push := Vector2.ZERO
		for o in others:
			var dv: Vector2 = position - o.position
			var l := dv.length()
			if l < 30.0 and l > 0.01 and o.team == team:
				push += dv / l * (30.0 - l)
		velocity = velocity.lerp(push.normalized() * speed, clampf(delta * 12.0, 0.0, 1.0))
		position += velocity * delta
		hp = minf(50.0, hp + 0.1 * delta)
		return speed


func _init() -> void:
	var units: Array = []
	for i in 40:
		var u := Dummy.new()
		u.position = Vector2(100 + (i % 8) * 9.0, 100 + (i / 8) * 9.0)
		u.team = i % 2
		units.append(u)
	var best := INF
	for rep in 5:
		var t0 := Time.get_ticks_usec()
		var acc := 0.0
		for it in 60:
			for u in units:
				acc += u.step(1.0 / 30.0, units)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		best = minf(best, ms)
		if acc < 0.0:
			print(acc)
	print("CALIB %.3f" % best)
	quit()
