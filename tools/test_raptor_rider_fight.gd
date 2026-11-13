extends SceneTree
## The owner's question (2026-11-13, a Hard Brood RUSH on Mirewood): would 10 Raptors beat 2 Horsemen in a stand-up
## fight (no micro), and how does it go when the riders kite (the owner's walk + attack)? Sandbox, no computers.
##   godot --headless --fixed-fps 30 --script res://tools/test_raptor_rider_fight.gd

var main: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_go.call_deferred()


func _alive(a: Array) -> Array:
	return a.filter(func(x): return is_instance_valid(x) and not x.dead)


func _go() -> void:
	await process_frame
	var res := {}
	for mode in ["standup", "kite"]:
		var wins := 0
		var lines: Array = []
		for trial in 6:
			main.start({"seed": 21 + trial, "map": "greenhold", "sandbox": true, "slots": [{"who": "you", "faction": "crown", "colour": 0, "side": 0}, {"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
			var g = main.game
			await create_timer(0.3).timeout
			g.hud.countdown = 0.0
			paused = false
			for a in g.ais:
				a.set_process(false)
				a.set_physics_process(false)
			var c: Vector2 = Vector2(Game.W, Game.H) * Game.T * 0.5
			var riders: Array = []
			for i in 2:
				riders.append(g._add_unit("cuirassier", 0, c + Vector2(-20 + i * 40, 0)))
			var raps: Array = []
			for i in 10:
				raps.append(g._add_unit("raptor", 1, c + Vector2(randf_range(-70, 70), 220 + randf_range(0, 50))))
			await process_frame
			for u in raps:
				u.cmd_move(c, true)
			for r in riders:
				r.cmd_move(c + Vector2(0, 120), true)      # (both sides attack-move: a stand-up fight)
			var t := 0.0
			while t < 90.0:
				await create_timer(0.25).timeout
				t += 0.25
				var rr := _alive(riders)
				var ra := _alive(raps)
				if rr.is_empty() or ra.is_empty():
					break
				if mode == "kite":
					# hit and run: a rider whose sabre is cooling and has a Raptor within 60 px rides away 2 tiles
					for r in rr:
						var near: Unit = null
						var nd := INF
						for x in ra:
							var d: float = r.position.distance_to(x.position)
							if d < nd:
								nd = d
								near = x
						if near == null:
							continue
						if r.cooldown > 0.3 and nd < 60.0:
							r.cmd_move(r.position + (r.position - near.position).normalized() * 64.0, false)
						elif r.cooldown <= 0.05 and (r.order == "move" or r.order == "idle"):
							r.cmd_attack(near)
			var rr2 := _alive(riders)
			var ra2 := _alive(raps)
			if ra2.is_empty():
				wins += 1
			lines.append("  trial %d: %.0fs, riders left %d (hp %s), raptors left %d" % [trial, t, rr2.size(), str(rr2.map(func(x): return int(x.hp))), ra2.size()])
		print("%s: riders won %d of 6" % [mode.to_upper(), wins])
		for l in lines:
			print(l)
	quit()
