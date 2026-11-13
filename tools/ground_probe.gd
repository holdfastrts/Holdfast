extends SceneTree
## THE GROUND SYSTEM probe (docs/ground_system.md): a bench run (tools/econ_bench.gd's scripted build is not used: this
## only starts a match with the ground on and the computer playing peacefully) that prints, every `every` s, each Farm /
## Cog Press's circle (yield share, what it holds of a fresh one, distance to its hall) and each hall's district.
##   godot --headless --fixed-fps 30 --script res://tools/ground_probe.gd -- [crown|clockwork] [map=greenhold] [secs=300] [every=60]

var main: Node
var g: Game
var fac := "crown"
var opts := {"map": "greenhold", "secs": "300", "every": "60", "seed": "1"}
var t := 0.0
var next := 0.0


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			var kv := a.split("=", true, 1)
			opts[kv[0]] = kv[1]
		else:
			fac = a


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(int(opts["seed"]))
		main.start({"map": opts["map"], "seed": int(opts["seed"]), "ground": true, "slots": [
			{"who": "hard", "faction": fac, "colour": 0, "side": 0, "strategy": String(opts.get("plan", "optimal"))},
			{"who": "you", "faction": "crown" if fac != "crown" else "clockwork", "colour": 1, "side": 1}]})
		g = main.game
		for a in g.ais:
			a.peaceful = true
		return false
	if g == null:
		return false
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if g.clock >= next:
		next += float(opts["every"])
		report()
	if g.clock >= float(opts["secs"]):
		quit()
	return false


func report() -> void:
	var gl := g.ground_layer
	print("--- %d s" % int(g.clock))
	var dk := "farm" if fac == "crown" else "cog_press"
	print("  %s count %d limit %d" % [dk, g.econ_count(0, dk), g.econ_limit(0, dk)])
	for h in g.halls_of(0):
		var d := gl.district(h)
		var sp := g.find_spot(0, dk, h, 4, Defs.ECON_RANGE - 2, "behind", true)
		print("  hall %s at %s: district %d / %d, live %s here %d, a spot %s (%s)" % [h.kind, str(h.cell), int(d[0]), int(d[1]), dk, g._district_live(0, dk, h), str(sp),
			g.placement_problem(0, dk, sp) if sp.x >= 0 else "none"])
	for b in g.buildings:
		if b.team == 0 and not b.dead and GroundLayer.drink_res(b.kind) != GroundLayer.NONE:
			var hall := g.nearest_hall(b.center(), 0)
			print("  %s at %s built %s: share %.2f value %.2f crew %d, %.1f tiles from its hall" % [b.kind, str(b.cell), str(b.built),
				gl.share(b), gl.value(b), b.working_crew(), b.center().distance_to(hall.center()) / Defs.TILE if hall else -1.0])
	print("  gold earned %d" % int(g.stats[0]["gold"]))
