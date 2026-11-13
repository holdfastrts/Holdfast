extends SceneTree
## THE COMPUTER ALONE, BROOD VERSION (econ-coach-brood; the general one is tools/econ_ai_alone.gd, docs/econ-coach-brood.md): the economy bench's setup (tools/econ_bench.gd: one
## faction alone on a map, the other slot an idle dummy that never moves) with the COMPUTER playing instead of the
## bench's scripted build. The dummy can't be hurt (its health is put back every frame) so the game never ends and the
## computer's own waves cost it what they cost; nothing of the game's rules changes. A measuring tool.
##
##   godot --headless --fixed-fps 30 --script res://tools/econ_ai_alone_brood.gd -- [brood] [plan=optimal] [minutes=15]
##       [map=greenhold] [seed=1] [out=<file.json>] [any switch the computer reads, e.g. nbsupply:off]
##       [vs=<crown|clockwork|brood>] [vsplan=optimal] [side=0|1]
## vs=: a REAL game instead (a Hard computer of that faction on the other side, nothing shielded): the same looks of the
## Brood side, plus its computer's state (grubs pulled off work, short of warriors against riders, under-armed, the
## alarm), to see what the opponent costs it. side=1 puts the Brood in the second start.
##
## Every 5 s it looks (Brood): supply and cap, the bank, her eggs and clutch size, her growth, grubs (at work, idle,
## turning into something, harvesting, on the way in eggs), the posts its rooted Rootmaws offer, Rootmaws (rooted,
## walking), turtles (home, on new ground), army value and supply. A line a minute and a RESULT line (JSON): the primary
## earned that minute and cumulative (the bench's p / p_cum), and that minute's share of looks SUPPLY-BLOCKED (cap under
## 200 and supply within 2 of it), EGGS FULL (her clutch full: laying lost), EGGS LOW (2 or fewer: eggs hold it back),
## the bank (mean and most), idle grubs, posts left empty and grubs over the posts. `firsts`: when things came first;
## `notes`: what the computer said it decided.

const LOOK := 5.0

var main: Node
var g: Game
var ai
var fac := "brood"
var opts := {"minutes": "15", "map": "greenhold", "seed": "1", "plan": "optimal", "out": "", "vs": "", "vsplan": "optimal", "side": "0"}
var me := 0
var t := 0.0
var started := false
var next_min := 60.0
var next_look := LOOK
var rows: Array = []
var looks: Array = []          # this minute's looks
var all_looks: Array = []
var firsts := {}
var last_p := 0.0
var wall0 := 0


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			var kv := a.split("=", true, 1)
			opts[kv[0]] = kv[1]
		elif a in ["brood", "crown", "clockwork"]:
			fac = a
	GroundLayer.study_args(opts)      # (THE GROUND SYSTEM: land.<key>=<n> for a study)
	wall0 = Time.get_ticks_msec()


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(int(opts["seed"]))
		var other := "crown" if fac != "crown" else "clockwork"
		var real := String(opts["vs"]) != ""
		me = int(opts["side"])
		var mine := {"who": "hard", "faction": fac, "colour": 0, "side": 0, "strategy": String(opts["plan"])}
		var foe := {"who": "hard" if real else "you", "faction": String(opts["vs"]) if real else other, "colour": 1, "side": 1,
			"strategy": String(opts["vsplan"]) if real else "balanced"}
		main.start({"map": opts["map"], "seed": int(opts["seed"]), "ground": String(opts.get("ground", "0")) == "1", "slots": [foe, mine] if me == 1 else [mine, foe]})
		g = main.game
		for a in g.ais:
			if a.team == me:
				ai = a
			elif not real:
				a.process_mode = Node.PROCESS_MODE_DISABLED
		started = true
		return false
	if not started or g == null:
		return false
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if String(opts["vs"]) == "":
		_shield()
	if g.clock >= next_look:
		next_look += LOOK
		_look()
	if g.clock >= next_min:
		next_min += 60.0
		_row()
	if g.clock >= float(opts["minutes"]) * 60.0 or g.over:
		_finish()
	return false


## The dummy can't be hurt: its health put back every frame (a big pool, so no single frame's blows can kill).
func _shield() -> void:
	for u in g.units:
		if u.team != me and not u.dead:
			if u.max_hp < 50000.0:
				u.max_hp = 100000.0
			u.hp = u.max_hp
	for b in g.buildings:
		if b.team != me and not b.dead:
			if b.max_hp < 50000.0:
				b.max_hp = 100000.0
			b.hp = b.max_hp


func _first(k: String) -> void:
	if not firsts.has(k):
		firsts[k] = int(g.clock)


func _look() -> void:
	var lk := {"t": int(g.clock), "supply": g.supply_used(me), "cap": int(g.players[me]["cap"]), "bank": int(g.players[me]["gold"]),
		"res2": int(g.players[me].get("res2", 0)), "earned": int(g.stats[me]["gold"])}
	if fac == "brood":
		var q := BroodNew.queen(g, me)
		if q == null:
			return
		lk["eggs"] = int(q.nb.get("eggs", 0))
		lk["eggs_max"] = BroodNew.eggs_max(q)
		lk["growing"] = float(q.nb.get("grow_t", 0.0)) > 0.0
		lk["stage"] = BroodNew.stage(q) + 1
		lk["lay_x"] = snappedf(BroodNew.egg_rate(g, me), 0.01)
		var grubs := 0
		var at_work := 0
		var idle := 0
		var morph := 0
		var harvest := 0
		var other := 0
		var eggs_grub := 0
		var posts := 0
		var maws := 0
		var maws_walk := 0
		var maws_spent := 0
		var turtles := 0
		var turtles_far := 0
		var army := 0.0
		var army_sup := 0
		var far := float(Defs.NB["expansion_tiles"]) * Defs.TILE * 0.9
		var sires := 0
		for u in g.units:
			if u.team != me or u.dead:
				continue
			match u.kind:
				"grub":
					grubs += 1
					if u.order == "gather" and u.home_mine != null and is_instance_valid(u.home_mine):
						at_work += 1
					elif u.order == "nb_morph":
						morph += 1
					elif u.order == "harvest":
						harvest += 1
					elif u.order == "idle" or u.order == "":
						idle += 1
					else:
						other += 1
				BroodNew.EGG:
					if String(u.nb.get("k", "")) == "grub":
						eggs_grub += 1
				BroodNew.MAW:
					if BroodNew.rooted(u):
						maws += 1
						if BroodNew.ground_left(g, u) < 1.0 and float(u.nb.get("food", 0.0)) < 1.0:
							maws_spent += 1
						else:
							posts += BroodNew.crew_max(g, u)
					else:
						maws_walk += 1
				BroodNew.TURTLE:
					if BroodNew.rooted(u):
						turtles += 1
						if u.position.distance_to(q.position) >= far:
							turtles_far += 1
							_first("far_turtle_%d" % turtles_far)
				_:
					if BroodNew.is_father(u.kind):
						sires += 1
					elif u.kind != BroodNew.QUEEN and u.has_attack() and not u.is_worker():
						army += float(Game.unit_value(u))
						army_sup += int(u.d.get("supply", 1))
		lk.merge({"grubs": grubs, "at_work": at_work, "idle": idle, "morph": morph, "harvest": harvest, "other": other,
			"eggs_grub": eggs_grub, "posts": posts, "maws": maws, "maws_walk": maws_walk, "maws_spent": maws_spent,
			"turtles": turtles, "turtles_far": turtles_far, "army": int(army), "army_sup": army_sup, "sires": sires})
		_first("stage_%d" % lk["stage"])
		if ai:
			lk["pulled"] = ai._pulled.size()
			lk["rider_short"] = ai._rider_short()
			lk["riders_on"] = ai._riders_on()
			lk["under_armed"] = ai._under_armed()
			lk["alarm"] = ai._alarm_on()
			lk["threat"] = ai._nb_threat(q) != Vector2.INF
			lk["attacking"] = bool(ai._attacking)
			lk["plan"] = String(ai.strategy)
			lk["lost_grubs"] = int(g.stats[me].get("lost", 0))
			lk["spoils"] = int(float(g.players[me]["res2"]))
			lk["venom_why"] = BroodRoot.morph_problem(g, me, BroodNew.DILO)
			lk["next_father"] = ai._nb_next_father(q)
			lk["morph_keep"] = ai._morph_keep
		_first("maws_%d" % maws)
	lk["blocked"] = lk["cap"] < g.max_supply(me) and lk["supply"] + 2 >= lk["cap"]
	looks.append(lk)
	all_looks.append(lk)


func _share(k: String) -> float:
	if looks.is_empty():
		return 0.0
	return snappedf(float(looks.filter(func(l: Dictionary) -> bool: return bool(l.get(k, false))).size()) / looks.size(), 0.01)


func _mean(f: Callable) -> float:
	if looks.is_empty():
		return 0.0
	var s := 0.0
	for l in looks:
		s += float(f.call(l))
	return snappedf(s / looks.size(), 0.1)


func _row() -> void:
	var p := float(g.stats[me]["gold"])
	var row := {"min": rows.size() + 1, "p": int(p - last_p), "p_cum": int(p), "spent": int(g.stats[me]["spent"]),
		"plan": String(ai.strategy) if ai else "", "blocked": _share("blocked")}
	last_p = p
	if not looks.is_empty():
		var lst: Dictionary = looks[-1]
		for k in lst:
			row["end_" + k] = lst[k]
		row["bank_mean"] = _mean(func(l): return l["bank"])
		row["bank_max"] = looks.map(func(l): return int(l["bank"])).max()
		if fac == "brood":
			row["eggs_full"] = snappedf(float(looks.filter(func(l): return int(l["eggs"]) >= int(l["eggs_max"]) and not l["growing"]).size()) / looks.size(), 0.01)
			row["eggs_low"] = snappedf(float(looks.filter(func(l): return int(l["eggs"]) <= 2).size()) / looks.size(), 0.01)
			row["growing"] = _share("growing")
			row["idle"] = _mean(func(l): return l["idle"] + l["other"])
			row["empty_posts"] = _mean(func(l): return maxi(0, int(l["posts"]) - int(l["at_work"])))
			row["over"] = _mean(func(l): return maxi(0, int(l["grubs"]) - int(l["morph"]) - int(l["harvest"]) - int(l["posts"])))
			row["at_work"] = _mean(func(l): return l["at_work"])
	looks.clear()
	rows.append(row)
	if fac == "brood":
		print("%s min %2d %-9s p %5d cum %6d | grubs %3d work %5.1f idle %4.1f empty %4.1f over %4.1f | maws %2d (+%d walk, %d spent) far %d | eggs %2d/%2d full %.2f low %.2f | sup %3d/%3d blk %.2f | bank %5d (max %5d) army %5d st %d" % [
			fac, row["min"], row["plan"], row["p"], row["p_cum"], row.get("end_grubs", 0), row.get("at_work", 0), row.get("idle", 0),
			row.get("empty_posts", 0), row.get("over", 0), row.get("end_maws", 0), row.get("end_maws_walk", 0), row.get("end_maws_spent", 0),
			row.get("end_turtles_far", 0), row.get("end_eggs", 0), row.get("end_eggs_max", 0), row.get("eggs_full", 0), row.get("eggs_low", 0),
			row.get("end_supply", 0), row.get("end_cap", 0), row["blocked"], row.get("end_bank", 0), row.get("bank_max", 0),
			row.get("end_army", 0), row.get("end_stage", 0)])
	else:
		print("%s min %2d p %5d cum %6d bank %5d sup %d/%d blk %.2f" % [fac, row["min"], row["p"], row["p_cum"], row.get("end_bank", 0),
			row.get("end_supply", 0), row.get("end_cap", 0), row["blocked"]])


func _finish() -> void:
	var notes: Array = []
	if ai and "note" in ai:
		for n in ai.note:
			notes.append([int(n[0]), String(n[1])])
	var res := {"faction": fac, "map": opts["map"], "seed": int(opts["seed"]), "plan": opts["plan"],
		"version": ProjectSettings.get_setting("application/config/version", "dev"), "rows": rows, "firsts": firsts,
		"looks": all_looks, "notes": notes, "args": OS.get_cmdline_user_args(), "wall_s": (Time.get_ticks_msec() - wall0) / 1000.0}
	var js := JSON.stringify(res)
	print("RESULT " + js.substr(0, 400))
	if String(opts["out"]) != "":
		var f := FileAccess.open(String(opts["out"]), FileAccess.WRITE)
		if f:
			f.store_string(js)
	quit()
