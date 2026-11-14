class_name MarchingBand
extends RefCounted
## THE CROWN'S MARCHING BAND (the owner's idea 2026-10-30; a real Crown unit since 0.33.0, the owner's decisions of
## 2026-11-05; docs/marching_band.md).
##
## A 17th-century band that follows the soldiers and plays them into battle. Trained at the ARMOURY; a new band is a
## DRUMMER. The FIFER and the PIPER (band-v2, the owner 2026-11-13) are UNITS of their own (Defs.UNITS "band_fifer",
## "band_piper"), trained one at a time at the Armoury: each comes out, walks to a band of its side that has no such
## musician yet and JOINS it (as an Officer walks to his horse and gets on): from then he is part of the band (its art,
## +15 health, his instrument and its solo). One of each a band. Which band: the one RECRUIT FIFER / PIPER on a band's
## card was pressed on, a band he is right-clicked onto (JOIN), else the nearest that wants him; with none he waits at the
## Armoury's rally point and goes as soon as a band wants him. A band that dies drops nothing (its musicians die with it).
## (An old save's or replay's research "band_fife" / "band_pipes" still gives every band of that side the musician.)
## SEVERAL bands may play (like cannons); their rings don't add up (each stat takes the strongest). Every instrument it
## has always plays its SECONDARY (+5%); an instrument's SOLO (8 s, then 45 s before it may solo again) puts it in the
## LEAD (+30%). ONE SOLO AT A TIME PER BAND (two bands may solo at once). Mechanical, not magic: a drum sets the pace, the
## pipes stir the blood, the fife keeps time for the loading drill.
##   DRUMS: movement speed    PIPES: melee damage (bayonets, sabres)    FIFE: reload speed (muskets, pistols, guns)
## Everything inside its RING (Defs.MARCHING_BAND "area") of its own side and its allies is covered (soldiers and guns,
## not workers, horses, wagons, medics or the band). The ring is drawn on the ground for everyone who sees the band
## (the telegraph: docs/design_principles.md 1), in the leading instrument's colour during a solo. It is unarmed and
## fragile (60 + 15 health a musician): kill it and the music stops (the risk that pays for the buffs).
##
## Drawn as a GROUP THAT GROWS (group_look): the Drummer is the unit's sprite (art "band"), the Fifer and the Piper are
## child sprites (arts "band_fifer", "band_piper", tools/import_band.py) standing SIDE BY SIDE with him in a row (SPOT),
## each once he is in. Its sound: BandSound (scripts/band_sound.gd: one band heard at a time, on one shared clock).
##
## The state lives on the band unit in `Unit.band` (saved, sent online and recorded in replays as one field):
##   "m": the instruments it has; "s": the instrument playing a solo ("" none), "se": the clock it ends; "cd":
##   {instrument: the clock it may solo again}; "id": the band's number on its side (a RECRUIT's musician finds it by it).
##   Clocks are the game clock (Game.clock). (Old saves' "h"/"he", of the 0.23 experiment, are ignored.)
## The buff a covered unit gets is on that unit: `band_mul` (speed, melee, reload multipliers) until `band_until`.

const KIND := "band"
const INSTRUMENTS := ["drums", "pipes", "fife"]
## Where each musician stands in the group, in the sprite's own (SE, unmirrored) space: SIDE BY SIDE in a row with the
## Drummer in the middle (the owner, 2026-11-13: "put the sprites side by side ... so we can see the musicians
## together"): the figures are ~20 px wide, 22 px apart, so no two bodies overlap. Mirrored with the sprite.
const SPOT := {"fife": Vector2(22, 0), "pipes": Vector2(-22, 0)}
## The musicians as units (band-v2): kind -> the instrument he brings.
const MUSICIANS := {"band_fifer": "fife", "band_piper": "pipes"}
## An old save's queued research -> the musician it is now (SaveGame.restore).
const OLD_QUEUE := {"@band_fife": "band_fifer", "@band_pipes": "band_piper"}
const ART := {"drums": "band", "fife": "band_fifer", "pipes": "band_piper"}
const B := Defs.MARCHING_BAND


static func on(g: Game, t: int) -> bool:
	return t >= 0 and t < g.factions.size() and g.factions[t] == "crown"


static func fresh() -> Dictionary:
	return {"m": [], "s": "", "se": 0.0, "cd": {}}


## The old research that brought this musician ("" for the Drummer: every band has him).
static func research_of(ins: String) -> String:
	return String(B[ins].get("research", ""))


## The musician unit that brings this instrument ("" for the drums).
static func unit_of(ins: String) -> String:
	return String(B[ins].get("unit", ""))


## Is this musician in EVERY band of this side by itself: the Drummer always; the others only for an old save's or
## replay's research (band-v2: they are trained and walk over now).
static func available(g: Game, t: int, ins: String) -> bool:
	var rk := research_of(ins)
	return rk == "" or (t >= 0 and t < g.players.size() and g.has_tech(t, rk))


## The Drummer (and an old save's researched musicians) are in the band (each +15 health). True if one joined.
static func sync(u: Unit, quiet := false) -> bool:
	var g := u.game
	if u.band.is_empty():
		u.band = fresh()
	band_id(u)
	var joined := false
	for ins in ["drums", "fife", "pipes"]:
		if has(u, ins) or not available(g, u.team, ins):
			continue
		_add(u, ins, 1.0, quiet)
		joined = true
	return joined


## A musician in the band: +15 health (the share of it he walked in with), his instrument.
static func _add(u: Unit, ins: String, hp_share: float, quiet: bool) -> void:
	var g := u.game
	(u.band["m"] as Array).append(ins)
	u.max_hp += float(B["hp_per"])
	u.hp = minf(u.max_hp, u.hp + float(B["hp_per"]) * clampf(hp_share, 0.0, 1.0))
	if not quiet and ins != "drums" and u.team == g.human and u.visible:
		g.float_text(u.position + Vector2(0, -40), Loc.t("+ %s") % Loc.t(String(B[ins]["who"])), Color(1.0, 0.9, 0.5))
	u.queue_redraw()


## The band's number on its side (given once; saved in its state): a RECRUIT's musician walks to the band with it.
static func band_id(u: Unit) -> int:
	if u.band.is_empty():
		u.band = fresh()
	var id := int(u.band.get("id", 0))
	if id != 0:
		return id
	var top := 0
	for o in u.game.units:
		if o.kind == KIND and o != u and not o.band.is_empty():
			top = maxi(top, int(o.band.get("id", 0)))
	u.band["id"] = top + 1
	return top + 1


static func by_id(g: Game, t: int, id: int) -> Unit:
	if id == 0:
		return null
	for o in g.units:
		if o.kind == KIND and o.team == t and not o.dead and not o.band.is_empty() and int(o.band.get("id", 0)) == id:
			return o
	return null


static func has(u: Unit, ins: String) -> bool:
	return (u.band.get("m", []) as Array).has(ins)


## The instrument leading now ("" none), by the clock (a solo ends at "se").
static func lead(u: Unit) -> String:
	var s := String(u.band.get("s", ""))
	if s != "" and u.game.clock < float(u.band.get("se", 0.0)):
		return s
	return ""


static func solo_left(u: Unit) -> float:
	return maxf(float(u.band.get("se", 0.0)) - u.game.clock, 0.0) if lead(u) != "" else 0.0


static func cooldown_left(u: Unit, ins: String) -> float:
	return maxf(float((u.band.get("cd", {}) as Dictionary).get(ins, 0.0)) - u.game.clock, 0.0)


## The share an instrument gives now: its full buff leading, a small share as a secondary, nothing if it isn't there.
static func share(u: Unit, ins: String) -> float:
	if not has(u, ins):
		return 0.0
	return float(B[ins]["lead"]) if lead(u) == ins else float(B[ins]["second"])


## The band's three multipliers now (speed, melee, reload rate).
static func muls(u: Unit) -> Vector3:
	return Vector3(1.0 + share(u, "drums"), 1.0 + share(u, "pipes"), 1.0 + share(u, "fife"))


## Does the band's music reach this unit: its side or an ally's, a fighting unit or a gun (not workers, horses, medics,
## wagons, the band itself), on the ground.
static func covers(band: Unit, o: Unit) -> bool:
	if o == band or o.dead or o.aboard != null or o.off_field or not band.game.allied(band.team, o.team):
		return false
	return plays_for(o)


## The kinds the music is for: a fighting unit or a gun (not workers, horses, medics, wagons, a band, flyers).
static func plays_for(o: Unit) -> bool:
	if o.is_worker() or o.kind == KIND or MUSICIANS.has(o.kind) or o.kind == "horse" or o.d.get("medic", false):
		return false
	if o.is_air():
		return false
	return o.has_attack() or o.kind == "dragoon"


# ------------------------------------------------------------------ the tick (host / single player)

static func tick(u: Unit, delta: float) -> void:
	var g := u.game
	if u.band.is_empty():
		u.band = fresh()
	# the Drummer (and an old save's researched musicians) are in it
	sync(u)
	if String(u.band.get("s", "")) != "" and g.clock >= float(u.band.get("se", 0.0)):
		u.band["s"] = ""
		u.queue_redraw()
	# the music over the ring, a few times a second
	u._band_t -= delta
	if u._band_t <= 0.0:
		u._band_t = float(B["pulse"])
		play_over(u)
	# no orders: it keeps up with the soldiers near it (an escort, like the Missionary's)
	if u.order == "idle" and u.queue.is_empty() and u.phase == "":
		u._band_scan -= delta
		if u._band_scan <= 0.0:
			u._band_scan = 0.5
			var lead_man := escort_pick(u)
			if lead_man:
				u.cmd_follow(lead_man)
	look_tick(u, delta)


## Every covered unit in the ring gets the band's buff for a little longer (the strongest band's, if two overlap).
## Returns how many it reached (tests).
static func play_over(u: Unit) -> int:
	var m := muls(u)
	if m == Vector3.ONE:
		return 0
	var g := u.game
	var until := g.clock + float(B["linger"])
	var n := 0
	var id := u.get_instance_id()
	for o: Unit in g.units_near(u.position, float(B["area"])):
		if not covers(u, o):
			continue
		o.band_src[id] = [m, until]
		mix(o)
		n += 1
	return n


## A covered unit's buff from every band reaching it: each stat the STRONGEST band's (rings don't add up), until the
## last of them lapses. (Each band's own entry is replaced on its every pass, so a solo that ended stops counting.)
static func mix(o: Unit) -> void:
	var now := o.game.clock
	var mul := Vector3.ONE
	var until := -1.0
	for k in o.band_src.keys():
		var e: Array = o.band_src[k]
		if float(e[1]) <= now:
			o.band_src.erase(k)
			continue
		var m: Vector3 = e[0]
		mul = Vector3(maxf(mul.x, m.x), maxf(mul.y, m.y), maxf(mul.z, m.z))
		until = maxf(until, float(e[1]))
	o.band_mul = mul
	o.band_until = until


## The soldier the band falls in behind when it has no orders: the nearest MOVING one of its side within its leash
## (none moving: it stays where it is).
static func escort_pick(u: Unit) -> Unit:
	var best: Unit = null
	var bd := INF
	for o: Unit in u.game.units_near(u.position, float(B["leash"])):
		if o.team != u.team or not covers(u, o) or o.velocity.length() < 12.0:
			continue
		var dd := o.position.distance_squared_to(u.position)
		if dd < bd:
			bd = dd
			best = o
	return best


# ------------------------------------------------------------------ the buffs, asked by Unit

## The speed multiplier on `o` now.
static func speed_mul(o: Unit) -> float:
	return o.band_mul.x if o.band_until > o.game.clock else 1.0


static func melee_mul(o: Unit) -> float:
	return o.band_mul.y if o.band_until > o.game.clock else 1.0


static func reload_mul(o: Unit) -> float:
	return o.band_mul.z if o.band_until > o.game.clock else 1.0


# ------------------------------------------------------------------ the musicians (band-v2): recruit, walk, join

## Does this band want this musician: of the side, alive, without one, nobody else (but `except`) walking to it with one.
static func wants(band: Unit, ins: String, except: Unit = null) -> bool:
	if band == null or not is_instance_valid(band) or band.dead or band.kind != KIND or band.off_field:
		return false
	if has(band, ins):
		return false
	return coming(band, ins, except) == null


## The musician of `ins` walking to this band now (null none).
static func coming(band: Unit, ins: String, except: Unit = null) -> Unit:
	for o in band.game.units:
		if o != except and not o.dead and MUSICIANS.get(o.kind, "") == ins and o.order == "join" and o.order_target == band:
			return o
	return null


## The band a musician goes to: the one asked for (`prefer`: a band's id) if it still wants him, else the nearest of
## his side that does (null: none, he waits).
static func pick_band(m: Unit, prefer := 0) -> Unit:
	var ins := String(MUSICIANS.get(m.kind, ""))
	if ins == "":
		return null
	var g := m.game
	var asked := by_id(g, m.team, prefer)
	if asked != null and wants(asked, ins, m):
		return asked
	var best: Unit = null
	var bd := INF
	for o in g.units:
		if o.kind != KIND or o.team != m.team or not wants(o, ins, m):
			continue
		var dd: float = o.position.distance_squared_to(m.position)
		if dd < bd:
			bd = dd
			best = o
	return best


## Send musician `m` to `band` (the JOIN order; `tell`: the player hears why not).
static func start_join(m: Unit, band: Unit, tell := false) -> bool:
	var ins := String(MUSICIANS.get(m.kind, ""))
	if ins == "" or m.dead or band.team != m.team or not wants(band, ins, m):
		if tell and ins != "" and band.kind == KIND and band.team == m.team and m.team == m.game.human:
			m.game.tell(m.team, "That band has a %s already (or one on his way)." % String(B[ins]["who"]), true)
		return false
	m._reset_work()
	m.order = "join"
	m.order_target = band
	m.target = null
	m.repath_t = 0.0
	return true


## Walking to his band; there, he joins it. A band gone (dead, or it got one meanwhile): he stops and looks again.
static func join_run(m: Unit, delta: float) -> Vector2:
	var band := m.order_target as Unit
	var ins := String(MUSICIANS.get(m.kind, ""))
	if band == null or not is_instance_valid(band) or not wants(band, ins, m):
		m.cmd_stop()
		m._band_scan = 0.0        # (straight on to another band, if one wants him)
		return Vector2.ZERO
	if m.position.distance_to(band.position) < m.radius + band.radius + 12.0:
		join(m, band)
		return Vector2.ZERO
	return m._walk_to(band.position, delta)


## He is in the band: his instrument, +15 health (as hale as he was), and he is taken off the field (the band draws him).
static func join(m: Unit, band: Unit) -> void:
	var g := m.game
	var ins := String(MUSICIANS[m.kind])
	var was_sel := g.selection.has(m)
	_add(band, ins, m.hp / maxf(m.max_hp, 1.0), false)
	if g.mlog:
		g.mlog.add("%s's band #%d: a %s joined" % [g.mlog.who(band.team), band_id(band), String(B[ins]["who"])])
	if band.team == g.human and band.visible:
		Sfx.play_any(["ui/click", "click"], band.position)
	g.consume_unit(m)
	if was_sel and not g.selection.has(band):
		g.selection.append(band)


## A loose musician (no order): every "join" s he looks for a band that wants him and walks to it. The computer's
## musicians go whatever they were told (its army's orders sweep them along).
static func musician_tick(m: Unit, delta: float) -> void:
	if m.order == "join":
		return
	m._band_scan -= delta
	if m._band_scan > 0.0:
		return
	m._band_scan = float(B["join"])
	var idle := m.order == "idle" and m.queue.is_empty()
	if not idle and not m.game.ais.any(func(a) -> bool: return a.team == m.team):
		return
	var band := pick_band(m, int(m.band.get("to", 0)) if not m.band.is_empty() else 0)
	if band != null:
		start_join(m, band)


## Out of the Armoury: to the band asked for (RECRUIT), else the nearest that wants him, else to the rally to wait.
static func on_spawn(m: Unit, b: Building, kit: Dictionary) -> void:
	var to := int(kit.get("band", 0))
	if to != 0:
		m.band = {"to": to}      # (a musician's own note: the band he was recruited for)
	var band := pick_band(m, to)
	if band != null and start_join(m, band):
		return
	if is_instance_valid(b.rally_target) and b.rally_target is Unit and (b.rally_target as Unit).kind == KIND \
			and start_join(m, b.rally_target):
		return
	if b.rally != Vector2.INF:
		m.cmd_move(b.rally + Vector2(randf_range(-20, 20), randf_range(-20, 20)), true)


## The Armoury a RECRUIT queues at: the nearest built one of the side that may train him now (null none).
static func armoury_for(band: Unit, ins: String) -> Building:
	var g := band.game
	var best: Building = null
	var bd := INF
	for b in g.buildings:
		if b.team != band.team or b.dead or not b.built or not (b.d.get("trains", []) as Array).has(unit_of(ins)):
			continue
		if g.can_train(b, unit_of(ins)) != "":
			continue
		var dd: float = b.center().distance_squared_to(band.position) + 4000.0 * b.queue.size()
		if dd < bd:
			bd = dd
			best = b
	return best


## Is a musician of `ins` already queued for this band (by its id) somewhere?
static func queued_for(band: Unit, ins: String) -> bool:
	var id := band_id(band)
	var k := unit_of(ins)
	for b in band.game.buildings:
		if b.team != band.team or b.dead:
			continue
		for i in b.queue.size():
			if String(b.queue[i]) == k and i < b.kits.size() and int((b.kits[i] as Dictionary).get("band", 0)) == id:
				return true
	return false


## Why RECRUIT FIFER / PIPER can't be pressed on this band now ("" it can).
static func recruit_problem(band: Unit, ins: String) -> String:
	var who := String(B[ins]["who"])
	if has(band, ins):
		return "This band has its %s." % who
	if coming(band, ins) != null or queued_for(band, ins):
		return "A %s is on his way to this band." % who
	var g := band.game
	var any := false
	for b in g.buildings:
		if b.team == band.team and not b.dead and b.built and (b.d.get("trains", []) as Array).has(unit_of(ins)):
			any = true
			var why := g.can_train(b, unit_of(ins))
			if why != "":
				return why
	if not any:
		return "Build an Armoury: the %s is trained there." % who
	return ""


## RECRUIT FIFER / PIPER: one queued at the nearest Armoury, for THIS band (it walks to it when it comes out).
static func recruit(band: Unit, ins: String) -> String:
	if not ["fife", "pipes"].has(ins):
		return "?"
	var why := recruit_problem(band, ins)
	if why != "":
		band.game.tell(band.team, why, true)
		return why
	var a := armoury_for(band, ins)
	if a == null:
		return "no armoury"
	var g := band.game
	g.train_band_id = band_id(band)
	why = g.train(a, unit_of(ins))
	g.train_band_id = 0
	if why != "":
		g.tell(band.team, why, true)
	return why


# ------------------------------------------------------------------ orders (Unit.band_solo: the net funnel)

static func solo_problem(u: Unit, ins: String) -> String:
	if not INSTRUMENTS.has(ins):
		return "?"
	if not has(u, ins):
		return "No %s in the band yet. Train one at the Armoury (RECRUIT on the band's card)." % String(B[ins]["who"])
	if lead(u) != "":
		return "The band is already playing a solo."
	var cd := cooldown_left(u, ins)
	if cd > 0.0:
		return "The %s can solo again in %d s." % [String(B[ins]["who"]), int(ceil(cd))]
	return ""


static func solo(u: Unit, ins: String) -> String:
	if u.band.is_empty():
		u.band = fresh()
	var why := solo_problem(u, ins)
	if why != "":
		u.game.tell(u.team, why, true)
		return why
	var g := u.game
	u.band["s"] = ins
	u.band["se"] = g.clock + float(B["solo"])
	(u.band["cd"] as Dictionary)[ins] = g.clock + float(B["cooldown"])
	u._band_t = 0.0                  # (the lead reaches the ring at once)
	u._sound_t = 0.0
	u.queue_redraw()
	if g.mlog:
		g.mlog.add("%s's band: %s solo" % [g.mlog.who(u.team), ins])
	return ""


# ------------------------------------------------------------------ the computer

## The computer's bands (AI._band: its army ~10 strong for the first, 30+ for a second; then their Fifer and Piper):
## each keeps behind the line (its escort) and plays its solos where they pay:
##  - FIFE when 3 or more of the soldiers in its ring are shooting;
##  - PIPES when half or more of the fighting ones are at the bayonet or the sabre;
##  - DRUMS to catch a retreating enemy (our men chasing, the enemy's backs turned) or to get out of a lost fight
##    (more enemies than ours round the band, ours falling back).
static func ai_tick(g: Game, t: int) -> void:
	for u in g.units:
		if u.team == t and not u.dead and u.kind == KIND:
			ai_band(g, t, u)


static func ai_band(g: Game, t: int, u: Unit) -> void:
	if u.band.is_empty():
		u.band = fresh()
	ai_place(g, t, u)
	if lead(u) != "":
		return
	var shooting := 0
	var close := 0
	var fighting := 0
	var ours := 0
	var back := 0          # ours walking away from the enemy (a retreat)
	var chasing := 0       # ours walking after a target that walks away
	for o: Unit in g.units_near(u.position, float(B["area"])):
		if o.team != t or not covers(u, o):
			continue
		ours += 1
		if o.target != null and is_instance_valid(o.target) and not o.target.dead:
			fighting += 1
			var tgt: Entity = o.target
			if o.mode == "bayonet" or o.mode == "sabre" or o._range() < 60.0:
				close += 1
			elif o.phase != "" or o.cooldown > 0.0:
				shooting += 1
			if tgt is Unit and (tgt as Unit).velocity.length() > 20.0 and o.velocity.length() > 20.0 \
					and (tgt as Unit).velocity.dot(tgt.position - o.position) > 0.0:
				chasing += 1
	var foes := 0
	for e: Unit in g.units_near(u.position, float(B["area"]) + 120.0):
		if g.hostile(e.team, t) and not e.dead and not e.is_worker() and e.has_attack():
			foes += 1
			for o: Unit in g.units_near(u.position, float(B["area"])):
				if o.team == t and covers(u, o) and o.velocity.length() > 20.0 and o.velocity.dot(o.position - e.position) > 0.0:
					back += 1
					break
	var want := ""
	if fighting >= 3 and close * 2 >= fighting:
		want = "pipes"
	elif shooting >= 3:
		want = "fife"
	elif (chasing >= 3) or (foes > ours + 2 and back >= 1 and ours >= 1):
		want = "drums"
	if want != "" and solo_problem(u, want) == "":
		solo(u, want)
	elif want == "pipes" and solo_problem(u, "fife") == "" and shooting >= 2:
		solo(u, "fife")
	elif want == "fife" and fighting >= 3 and close >= 1 and solo_problem(u, "pipes") == "":
		solo(u, "pipes")


## BEHIND THE LINE: the band walks to a spot BEHIND its nearest group of soldiers (their middle, 70 px back from the
## nearest enemy), so the ring covers the line and the enemy meets the soldiers first; with no enemy about it falls in
## behind them (its escort, tick). Its orders from the army (an attack-move with the soldiers) are overridden.
const AI_BACK := 70.0


static func ai_place(g: Game, t: int, u: Unit) -> void:
	var men: Array = []
	for o: Unit in g.units_near(u.position, 420.0):
		if o.team == t and covers(u, o) and o.kind != "cannon" and o.kind != "mortar":
			men.append(o)
	if men.is_empty():
		# far from the soldiers (just trained, or left behind): to the nearest of them
		var best: Unit = null
		var bd := INF
		for o: Unit in g.army(t):
			if covers(u, o):
				var dd := o.position.distance_squared_to(u.position)
				if dd < bd:
					bd = dd
					best = o
		if best and (u.order != "follow" or u.order_target != best):
			u.cmd_follow(best)
		return
	var mid := Vector2.ZERO
	for o in men:
		mid += o.position
	mid /= float(men.size())
	var foe: Unit = null
	var fd := INF
	for e: Unit in g.units_near(mid, 520.0):
		if g.hostile(e.team, t) and not e.dead and not e.is_worker() and not e.off_field and e.aboard == null:
			var dd := e.position.distance_squared_to(mid)
			if dd < fd:
				fd = dd
				foe = e
	if foe == null:
		if u.order == "amove" or u.order == "attack" or (u.order == "move" and u.position.distance_to(mid) > 220.0):
			u.cmd_move(mid)
		return
	var back := (mid - foe.position).normalized()
	var spot := mid + back * AI_BACK
	var cell := Vector2i(floori(spot.x / Defs.TILE), floori(spot.y / Defs.TILE))
	if not g.passable(cell, t):
		spot = mid
	if u.position.distance_to(spot) > 36.0 and (u.order != "move" or u.order_point.distance_to(spot) > 30.0):
		u.cmd_move(spot)


# ------------------------------------------------------------------ the look and the sound (host, guest, replay)

## The sound and the redraw while the ring pulses (also on an online guest and in a replay: NetPuppet). The sound is the
## match's BandSound (scripts/band_sound.gd): one band heard at a time, every part on one shared clock.
static func look_tick(u: Unit, delta: float) -> void:
	BandSound.need(u.game)
	u._band_draw_t -= delta
	if u._band_draw_t <= 0.0 and u.visible and u.game.view_rect.has_point(u.position):
		u._band_draw_t = 0.1
		u.queue_redraw()
		if u._band_fx:
			u._band_fx.queue_redraw()


## Its ring on the ground (Unit._draw_unit, under it): gold, in the leading instrument's colour and pulsing during a solo;
## little ticks round it, one colour per instrument it has. Drawn for everyone who sees the band (the telegraph).
static func draw_ring(u: Unit) -> void:
	if u.band.get("m", []).is_empty():
		return
	var r := float(B["area"])
	var ld := lead(u)
	var pulse := 0.5 + 0.5 * sin(u.game.clock * 5.0)
	var c := Color(1.0, 0.86, 0.45, 0.6)
	if ld != "":
		c = (B[ld]["col"] as Color)
		c.a = 0.6 + 0.3 * pulse
	# (a true circle: the reach is measured flat on the map, as the Great Winder's; a dark edge under it reads on sand)
	u.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.15, 0.09, 0.03, 0.35), 4.0 if ld != "" else 3.0, true)
	u.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, c, 2.5 if ld != "" else 1.5, true)
	var ins: Array = u.band.get("m", [])
	for i in 24:
		if ins.is_empty():
			break
		var a := TAU * float(i) / 24.0 + u.game.clock * 0.3
		var k: String = ins[i % ins.size()]
		var cc: Color = B[k]["col"]
		cc.a = 0.7
		var dv := Vector2.from_angle(a)
		u.draw_line(dv * (r - 7.0), dv * r, cc, 2.0, true)


## The notes rising over the band during a SOLO, in the leading instrument's colour (drawn in code over the real art;
## docs/art_style_inconsistency.md). The leading musician himself stands out by a bob (lead_bob, group_look).
static func draw_kit(u: Unit, ci: CanvasItem) -> void:
	var ld := lead(u)
	if ld == "" or u.dead:
		return
	var t := u.game.clock
	var at: Vector2 = Vector2.ZERO
	if ld != "drums":
		at = SPOT[ld] * Vector2(-1.0 if u.anim_flip else 1.0, 1.0)
	var n := 4
	for i in n:
		var ph := fmod(t * 0.7 + float(i) / float(n), 1.0)
		var c: Color = B[ld]["col"]
		c.a = (1.0 - ph) * 0.9
		var p := at + Vector2(-10.0 + 20.0 * float(i) / float(n - 1) + 3.0 * sin(t * 3.0 + i), -40.0 - ph * 22.0)
		ci.draw_circle(p, 2.0, c)
		ci.draw_line(p + Vector2(1.8, 0), p + Vector2(1.8, -6), c, 1.0)


## How high the musician `ins` hops now: a small bob while his instrument leads (0 otherwise).
static func lead_bob(u: Unit, ins: String) -> float:
	if u.dead or lead(u) != ins:
		return 0.0
	return absf(sin(u.game.clock * 9.0)) * 2.0


## THE GROUP (the art: tools/import_band.py): the Fifer and the Piper as child sprites of the Drummer's, SIDE BY SIDE with
## him in a row (SPOT), each only once he is in the band, in the same pose and frame (they mirror with him: children of the
## sprite). Called by Unit._animate after the Drummer's frame is set. The leader of a solo bobs and stands a little
## bigger.
static func group_look(u: Unit) -> void:
	var spr := u.sprite
	if spr == null:
		return
	for ins in ["fife", "pipes"]:
		var name: String = "band_" + ins
		var c: Sprite2D = spr.get_node_or_null(name)
		if not has(u, ins):
			if c:
				c.visible = false
			continue
		if c == null:
			c = Sprite2D.new()
			c.name = name
			c.centered = false
			c.use_parent_material = true
			c.show_behind_parent = true
			spr.add_child(c)
		c.visible = true
		var art: String = String(ART[ins])
		var frames: Dictionary = ArtData.UNITS[art]["frames"]
		var key := "%s_%s" % [u.anim, u.anim_dir]       # (the Drummer's pose and view: only SE is drawn so far)
		if not frames.has(key):
			key = "%s_se" % u.anim
		if not frames.has(key):
			key = "idle_se"
		var ck := art + "/" + key
		var e = _strips.get(ck)
		if e == null:
			var tx := Game.tex("res://assets/units/%s/%s.png" % [art, key])
			var cell: Vector2i = ArtData.UNITS[art]["cell"]
			e = [tx, int(frames[key]), -Vector2(ArtData.UNITS[art]["anchor"]) - Vector2(0, tx.get_height() - cell.y)]
			_strips[ck] = e
		if c.texture != e[0]:
			c.texture = e[0]
		if c.hframes != int(e[1]):
			c.hframes = int(e[1])
		c.offset = e[2]
		# (in step with the Drummer, but a frame apart, so the three don't march as one)
		var f := posmod(spr.frame + (1 if ins == "fife" else 2), c.hframes) if not u.dead else mini(spr.frame, c.hframes - 1)
		if c.frame != f:
			c.frame = f
		var bob := lead_bob(u, ins)
		c.position = Vector2(SPOT[ins]) - spr.position + Vector2(0, -bob)
		var sc := 1.12 if bob > 0.0 or (lead(u) == ins and not u.dead) else 1.0
		c.scale = Vector2(sc, sc)


static var _strips := {}


## The row's middle (x, from the Drummer) and half its width, in px, for its shadow and selection ring (Unit._draw).
static func ring_span(u: Unit) -> Vector2:
	var lo := -12.0
	var hi := 12.0
	var fl := -1.0 if u.anim_flip else 1.0
	for ins in ["fife", "pipes"]:
		if has(u, ins):
			var x: float = SPOT[ins].x * fl
			lo = minf(lo, x - 12.0)
			hi = maxf(hi, x + 12.0)
	return Vector2((lo + hi) * 0.5, (hi - lo) * 0.5 + 3.0)


## A number that changes when the drawing should (Unit's redraw key).
static func draw_key(u: Unit) -> int:
	var ld := lead(u)
	return (u.band.get("m", []) as Array).size() + (8 if ld != "" else 0) + (int(u.game.clock * 6.0) % 97) * 16


## The train button's note: who comes out and where he goes.
static func train_note(g: Game, t: int, k := KIND) -> String:
	if MUSICIANS.has(k):
		var ins := String(MUSICIANS[k])
		var n := 0
		for o in g.units:
			if o.kind == KIND and o.team == t and not o.dead and wants(o, ins):
				n += 1
		var who := Loc.t(String(B[ins]["who"]))
		if n == 0:
			return Loc.t("He walks to a band without a %s and joins it; none wants one now, so he waits at the rally point.") % who
		return Loc.t("He walks to the nearest band without a %s and joins it (%d want one).") % [who, n]
	return Loc.t("Comes out as a Drummer. Train a Fifer and a Piper here too: they walk to a band and join it.")


## The selection card's line.
static func card_line(u: Unit) -> String:
	if MUSICIANS.has(u.kind):
		var ins := String(MUSICIANS[u.kind])
		if u.order == "join" and is_instance_valid(u.order_target):
			return Loc.t("Walking to a Marching Band to join it (%s).") % Loc.t(String(B[ins]["label"]))
		return Loc.t("No band to join: every band has a %s. Waiting.") % Loc.t(String(B[ins]["who"])) if pick_band(u) == null \
			else Loc.t("Off to join a Marching Band.")
	var ins: Array = u.band.get("m", [])
	var a := int(round(float(B["area"]) / Defs.TILE))
	var parts := PackedStringArray()
	for k in ins:
		parts.append(Loc.t(String(B[k]["label"])))
	var line := Loc.t("Plays: %s · %d tiles") % [", ".join(parts) if not parts.is_empty() else "-", a]
	var ld := lead(u)
	if ld != "":
		line += " · " + Loc.t("%s SOLO: %d s") % [Loc.t(String(B[ld]["label"])), int(ceil(solo_left(u)))]
	return line


## Its command card (HUD._ability_buttons): each instrument's SOLO, and RECRUIT FIFER / PIPER (one queued at the nearest
## Armoury for this band). Several bands selected: a SOLO plays on the first of them that can, a RECRUIT is for the first
## that wants him. A loose Fifer / Piper: JOIN BAND (the nearest band that wants him; or right-click a band).
static func card(hud, list: Array, units: Array) -> void:
	var men := units.filter(func(o: Unit) -> bool: return MUSICIANS.has(o.kind) and o.team == hud.game.human and not o.dead)
	if not men.is_empty():
		hud._tip_for["JOIN BAND"] = ["Join a band", "He walks to the nearest Marching Band of yours without his instrument and joins it (+15 health to the band, his instrument and its solo). Or right-click a band to send him to that one."]
		var any := men.any(func(m: Unit) -> bool: return pick_band(m) != null)
		list.append(["ab_band_join", "JOIN BAND", func() -> void:
			for m in men:
				var bd := pick_band(m)
				if bd != null:
					m.give({"o": "join", "e": bd}), any, "" if any else "No band wants him: every band has one already, or you have none (train a Marching Band at the Armoury).", ""])
	var bands := units.filter(func(o: Unit) -> bool: return o.kind == KIND and o.team == hud.game.human and not o.dead)
	if bands.is_empty():
		return
	var a := int(round(float(B["area"]) / Defs.TILE))
	for ins in INSTRUMENTS:
		var info: Dictionary = B[ins]
		var stat := String(info["stat_text"])
		var lab2 := String(info["label"]).to_upper() + " SOLO"
		hud._tip_for[lab2] = [String(info["solo_title"]), "The %s leads for %d s: %s +%d%% to your soldiers within %d tiles of the band (always +%d%% while it plays). Then %d s before it can solo again; one solo at a time in each band." % [
			String(info["label"]).to_lower(), int(B["solo"]), stat, int(round(float(info["lead"]) * 100.0)), a, int(round(float(info["second"]) * 100.0)), int(B["cooldown"])]]
		# the band that would play it: the first selected one free to (else the first, for its reason and countdown)
		var u: Unit = bands[0]
		for o in bands:
			if solo_problem(o, ins) == "":
				u = o
				break
		var why2 := solo_problem(u, ins)
		var cd := cooldown_left(u, ins)
		var corner := ("%ds" % int(ceil(solo_left(u)))) if lead(u) == ins else (("%ds" % int(ceil(cd))) if cd > 0.0 else "")
		list.append(["ab_band_" + ins, ("~ " if lead(u) == ins else "") + lab2, func() -> void:
			u.band_solo(ins), why2 == "", why2, corner])
	# RECRUIT FIFER / PIPER (band-v2): for the first selected band that has none and none coming
	for ins in ["fife", "pipes"]:
		var info: Dictionary = B[ins]
		var k := unit_of(ins)
		var lab := "RECRUIT " + String(info["who"]).to_upper()
		var price := hud.game.unit_price(hud.game.human, k) as Array
		var cost := (Loc.t("%d gold, %d powder") % [int(price[0]), int(price[1])]) if int(price[1]) > 0 else (Loc.t("%d gold") % int(price[0]))
		hud._tip_for[lab] = [Loc.t("Recruit a %s") % Loc.t(String(info["who"])), Loc.t("A %s is trained at your nearest Armoury (%s, %d s) and walks to THIS band to join it (+15 health to the band, +5%% %s in its ring and the %s SOLO). One %s a band.") % [
			Loc.t(String(info["who"])), cost, int(Defs.UNITS[k]["time"]), Loc.t(String(info["stat_text"])), Loc.upper(Loc.t(String(info["label"]))), Loc.t(String(info["who"]))]]
		var u: Unit = bands[0]
		for o in bands:
			if recruit_problem(o, ins) == "":
				u = o
				break
		var why := recruit_problem(u, ins)
		list.append([k, lab, func() -> void:
			u.band_recruit(ins), why == "", why, ""])


# ------------------------------------------------------------------ save / net

static func save(u: Unit) -> Dictionary:
	if u.band.is_empty():
		return {}
	var cd := {}
	for k in u.band.get("cd", {}):
		cd[k] = snappedf(float(u.band["cd"][k]), 0.01)
	return {"m": (u.band.get("m", []) as Array).duplicate(), "s": String(u.band.get("s", "")), "se": snappedf(float(u.band.get("se", 0.0)), 0.01), "cd": cd,
		"id": int(u.band.get("id", 0))}


## (an old save's "h"/"he", a musician being taken on in the 0.23 experiment, are dropped; one without "id" gets one)
static func load_state(u: Unit, d: Dictionary) -> void:
	u.band = fresh()
	for k in d.get("m", []):
		if INSTRUMENTS.has(String(k)) and not (u.band["m"] as Array).has(String(k)):
			(u.band["m"] as Array).append(String(k))
	u.band["s"] = String(d.get("s", ""))
	u.band["se"] = float(d.get("se", 0.0))
	var cd: Dictionary = d.get("cd", {})
	for k in cd:
		u.band["cd"][String(k)] = float(cd[k])
	if int(d.get("id", 0)) != 0:
		u.band["id"] = int(d["id"])
	u.max_hp = float(u.d["hp"]) + float(B["hp_per"]) * (u.band["m"] as Array).size()
