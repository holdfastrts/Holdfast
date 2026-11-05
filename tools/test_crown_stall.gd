extends SceneTree
## THE CROWN'S BUILD ORDER NEVER STALLS (the owner's log docs/playtests/2026-11-05/spectate_crown_econ_stalls_v_brood_econ_
## redcoast_0310.txt, 0.31.0: Red Coast, seed 1347577666, P1 Hard Brood Economy v P2 Hard Crown Economy. The Foundry site
## was dropped a second after it was laid (its builder sent at a Brood grub), the Breeder step waited for "has Foundry" for
## ever: no more production, 7 Musketeers, 68 labourers, 3,400 gold banked). The same game, played to 8:00:
##  [foundry]  a Foundry stands by FOUNDRY_BY
##  [opening]  the opening is over by OPENING_BY (no step waits for ever)
##  [labs]     never more than LABS_MAX labourers while it has two halls or fewer (and no third going up)
##  [bank]     under BANK_MAX gold at 8:00, and under it most of the game from 5:00 (BANK_SHARE of the seconds)
##  [army]     an army worth ARMY_8 or more at 8:00 (the stalled game had 420)
## drop:1 also drops the Foundry's site the moment it is laid (no labourer takes it up): the step must come back and the
## Foundry still stand by FOUNDRY_BY_DROP.
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_stall.gd [-- drop:1 map:red_coast seed:1347577666]
const FOUNDRY_BY := 330.0
const FOUNDRY_BY_DROP := 390.0
const OPENING_BY := 390.0
const LABS_MAX := 50
const BANK_MAX := 1000
const BANK_SHARE := 0.8
const ARMY_8 := 900
const END := 480.0
var fails := 0
var main: Node
var g: Game
var ai: AICrown
var map := "red_coast"
var seed_ := 1347577666
var drop := false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"map": map = kv[1]
				"seed": seed_ = int(kv[1])
				"drop": drop = kv[1] == "1"
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(seed_)
	# (as tools/play_crown_1.gd cslot:1 lays it out, the owner's log: the Brood first, the Crown P2)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard", "faction": "brood", "colour": 1, "side": 0, "strategy": "economy"},
		{"who": "hard", "faction": "crown", "colour": 0, "side": 1, "strategy": "economy"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
		g.hud.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	for a in g.ais:
		if a is AICrown:
			ai = a
	check(ai != null and ai.owner_on(), "(set-up) the Crown computer plays the owner's Economy plan")
	if ai == null:
		_end()
		return
	var me: int = ai.team
	var foundry_t := -1.0
	var opening_t := -1.0
	var labs_top := 0
	var labs_top_t := 0.0
	var bank_n := 0
	var bank_low := 0
	var bank_top := 0
	var dropped := false
	var last_s := -1
	while g.clock < END and not g.over:
		await physics_frame
		if drop and not dropped:
			for b in g.buildings:
				if b.team == me and b.kind == "foundry" and b.ghost and not b.dead:
					dropped = true
					for u in g.workers(me):
						if u.order_target == b:
							u.cmd_stop()
					ai._adopted[b.get_instance_id()] = 99      # (nobody takes it up: the build order must place it again)
					g.site_failed(b, "abandoned")
					print("  (staged) the Foundry site is dropped at %d s" % int(g.clock))
					break
		if foundry_t < 0.0 and ai._mine("foundry").any(func(b: Building) -> bool: return b.built):
			foundry_t = g.clock
		if opening_t < 0.0 and ai.bo_done:
			opening_t = g.clock
		var s := int(g.clock)
		if s == last_s:
			continue
		last_s = s
		var built := ai._halls().filter(func(h: Building) -> bool: return h.built).size()
		var labs := g.workers(me).size()
		if built <= 2 and ai._halls().size() <= 2 and labs > labs_top:      # (a third hall going up: its farms' hands come ahead)
			labs_top = labs
			labs_top_t = g.clock
		if g.clock >= 300.0:
			bank_n += 1
			var gold := int(g.players[me]["gold"])
			bank_top = maxi(bank_top, gold)
			if gold < BANK_MAX:
				bank_low += 1
	var by := FOUNDRY_BY_DROP if drop else FOUNDRY_BY
	print("  foundry stood %d s, opening over %d s (%s), labourers at most %d on two halls (%d s), bank at 8:00 %d (top %d), army %d, stalls %s" % [
		int(foundry_t), int(opening_t), ai.bo_why, labs_top, int(labs_top_t), int(g.players[me]["gold"]), bank_top, g.army_value(me), str(ai.bo_stalls)])
	if drop:
		check(dropped and ai.bo_stalls.any(func(e: Array) -> bool: return String(e[2]) == "site dropped: again"), "[replace] the dropped Foundry site brings its step back")
	check(foundry_t >= 0.0 and foundry_t <= by, "[foundry] a Foundry stands by %d s (%d)" % [int(by), int(foundry_t)])
	check(opening_t >= 0.0 and opening_t <= OPENING_BY, "[opening] the opening is over by %d s (%d: %s)" % [int(OPENING_BY), int(opening_t), ai.bo_why])
	check(labs_top <= LABS_MAX, "[labs] at most %d labourers on two halls (%d)" % [LABS_MAX, labs_top])
	check(int(g.players[me]["gold"]) < BANK_MAX, "[bank] under %d gold at 8:00 (%d)" % [BANK_MAX, int(g.players[me]["gold"])])
	check(bank_n > 0 and float(bank_low) / float(bank_n) >= BANK_SHARE, "[bank] under %d gold %d%% of the time from 5:00 (%d of %d s)" % [BANK_MAX, int(100.0 * BANK_SHARE), bank_low, bank_n])
	check(g.army_value(me) >= ARMY_8, "[army] an army of %d or more at 8:00 (%d)" % [ARMY_8, g.army_value(me)])
	_end()


func _end() -> void:
	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
