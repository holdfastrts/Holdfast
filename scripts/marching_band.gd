class_name MarchingBand
extends RefCounted
## THE CROWN'S MARCHING BAND (the owner's idea 2026-10-30; a Crown unit since 0.33.0; INDIVIDUAL MUSICIANS since 0.37.0,
## the owner's redesign of 2026-11-14 02:01-02:08: docs/band_individuals.md, docs/marching_band.md).
##
## There is no band UNIT any more: three musicians, each a unit of his own trained at the ARMOURY:
##   the DRUMMER ("band": his kind keeps the old band's id), the FIFER ("band_fifer"), the PIPER ("band_piper").
## Each has his own instrument, his own always-on SECONDARY (+5%) in his own RING, his own SOLO (+30%, 8 s) and his own
## solo COOLDOWN (45 s). Mechanical, not magic: a drum sets the pace, the pipes stir the blood, the fife keeps time
## for the loading drill.
##   DRUMS: movement speed    PIPES: melee damage (bayonets, sabres)    FIFE: reload speed (muskets, pistols, guns)
## THE SAME INSTRUMENT NEVER ADDS UP: under two drummers a soldier gets the strongest drum only (each stat its strongest).
## A BAND FORMS when a drummer, a fifer and a piper each stand within the others' rings (one of each; with more musicians
## about, the closest set forms it and the rest stay lone): it plays IN STEP and stronger (secondaries 8%, solos 40% for
## 10 s), from ONE ring round the three of them, drawn gold with a small BAND mark; one solo at a time in a band. Its
## Fifer and Piper fall in beside the Drummer, a row, and keep beside him when he walks.
## LONE MUSICIANS play OUT OF STEP: where two lone musicians' rings of DIFFERENT instruments overlap (and they are not a
## band) a soldier gets only the stronger of their buffs, and their rings say "out of step". (The trade: lone musicians
## cover more ground; a band is stronger but three men in one spot.)
## Everything inside a ring of its own side or its allies is covered (soldiers and guns, not workers, horses, wagons,
## medics or musicians). Rings are drawn for everyone who sees the musicians, and every buffed soldier can show what he
## gets over his head (an icon and "+8%": Settings BAND BUFF MARKS; the telegraph, docs/design_principles.md 1).
##
## Each musician's state is in `Unit.band` (saved, sent online, recorded in replays as one field):
##   "id": his number on his side (a band is known by its Drummer's); "se": the clock his solo ends; "cd": the clock he
##   may solo again; "b": the band he is in (its Drummer's id; 0: lone). (Not saved: "oos" out of step, "rwp" his row
##   spot, "esc" his escort.) Clocks are the game clock (Game.clock).
## A 0.33-0.36 BAND (one unit, "m": its instruments) loads as its musicians standing together (SaveGame -> load_state);
## an old FULL replay's band is drawn as before (its musicians as child sprites: group_look).
## The buff on a covered unit: `band_mul` (speed, melee, reload multipliers) until `band_until`, and `band_show` (what
## the markers and the card say: [instrument, percent, flags]).

const KIND := "band"          # the Drummer
const INSTRUMENTS := ["drums", "pipes", "fife"]
## kind -> his instrument.
const MUSICIANS := {"band": "drums", "band_fifer": "fife", "band_piper": "pipes"}
## The row: where the Fifer and the Piper stand beside the Drummer of their band (px on the screen's x, mirrored when he
## faces west): ~20 px wide figures 24 px apart, so no two bodies overlap.
const SIDE := {"fife": 24.0, "pipes": -24.0}
## (legacy: an old FULL replay's band carries its Fifer and Piper as child sprites, here)
const SPOT := {"fife": Vector2(22, 0), "pipes": Vector2(-22, 0)}
## An old save's queued research -> the musician it is now (SaveGame.restore; 0.36.0).
const OLD_QUEUE := {"@band_fife": "band_fifer", "@band_pipes": "band_piper"}
const ART := {"drums": "band", "fife": "band_fifer", "pipes": "band_piper"}
## Marker flags (band_show): from a band, a solo, out of step (not applied).
const F_BAND := 1
const F_SOLO := 2
const F_OOS := 4
const B := Defs.MARCHING_BAND


static func on(g: Game, t: int) -> bool:
	return t >= 0 and t < g.factions.size() and g.factions[t] == "crown"


static func is_musician(u) -> bool:
	return u is Unit and MUSICIANS.has((u as Unit).kind)


static func ins_of(u: Unit) -> String:
	return String(MUSICIANS.get(u.kind, ""))


static func fresh() -> Dictionary:
	return {"id": 0, "se": 0.0, "cd": 0.0, "b": 0}


## The musician unit that plays this instrument.
static func unit_of(ins: String) -> String:
	return String(B[ins]["unit"])


## (legacy) the old research that gave every band this musician ("" for the drums).
static func research_of(ins: String) -> String:
	return String(B[ins].get("research", ""))


## His number on his side (given once; saved). A band is known by its Drummer's.
static func band_id(u: Unit) -> int:
	if u.band.is_empty():
		u.band = fresh()
	var id := int(u.band.get("id", 0))
	if id != 0:
		return id
	var top := 0
	for o in u.game.units:
		if o != u and o.team == u.team and is_musician(o) and not o.band.is_empty():
			top = maxi(top, int(o.band.get("id", 0)))
	u.band["id"] = top + 1
	return top + 1


## The band he is in (its Drummer's id; 0 lone).
static func band_key(u: Unit) -> int:
	return int(u.band.get("b", 0)) if not u.band.is_empty() else 0


static func in_band(u: Unit) -> bool:
	return band_key(u) != 0


## The band's members (the Drummer first), alive, of his side, by its key. [] if he is lone.
static func mates(u: Unit) -> Array:
	var k := band_key(u)
	if k == 0:
		return []
	return members(u.game, u.team, k)


static func members(g: Game, t: int, k: int) -> Array:
	var out: Array = []
	for ins in ["drums", "fife", "pipes"]:
		for o in g.units:
			if o.team == t and not o.dead and ins_of(o) == ins and band_key(o) == k:
				out.append(o)
				break
	return out


## The band's Drummer (null: lone or none).
static func drummer_of(u: Unit) -> Unit:
	for o in mates(u):
		if o.kind == KIND:
			return o
	return null


## Where a band's ring is: the middle of its three.
static func centre(ms: Array) -> Vector2:
	var c := Vector2.ZERO
	for o in ms:
		c += (o as Unit).position
	return c / maxf(1.0, float(ms.size()))


## (legacy band: an old FULL replay's band unit, its instruments in "m")
static func legacy(u: Unit) -> bool:
	return u.band.has("m")


## Does this musician (or a legacy band) have this instrument.
static func has(u: Unit, ins: String) -> bool:
	if legacy(u):
		return (u.band.get("m", []) as Array).has(ins)
	return ins_of(u) == ins


## The instrument he plays a SOLO on now ("" none), by the clock.
static func lead(u: Unit) -> String:
	if u.band.is_empty():
		return ""
	if legacy(u):
		var s := String(u.band.get("s", ""))
		return s if s != "" and u.game.clock < float(u.band.get("se", 0.0)) else ""
	return ins_of(u) if u.game.clock < float(u.band.get("se", 0.0)) else ""


static func solo_left(u: Unit) -> float:
	return maxf(float(u.band.get("se", 0.0)) - u.game.clock, 0.0) if lead(u) != "" else 0.0


static func cooldown_left(u: Unit, _ins := "") -> float:
	if u.band.is_empty() or legacy(u):
		return 0.0
	return maxf(float(u.band.get("cd", 0.0)) - u.game.clock, 0.0)


## The share his instrument gives now: in a band 8% (40% in his solo), alone 5% (30%).
static func share(u: Unit) -> float:
	var ins := ins_of(u)
	if ins == "":
		return 0.0
	var bd := in_band(u)
	if lead(u) != "":
		return float(B["band_lead"]) if bd else float(B[ins]["lead"])
	return float(B["band_second"]) if bd else float(B[ins]["second"])


## How long a solo lasts for him now (a band's is longer).
static func solo_time(u: Unit) -> float:
	return float(B["band_solo"]) if in_band(u) else float(B["solo"])


## Does the music reach this unit: its side or an ally's, a fighting unit or a gun, on the ground.
static func covers(src: Unit, o: Unit) -> bool:
	if o == src or o.dead or o.aboard != null or o.off_field or not src.game.allied(src.team, o.team):
		return false
	return plays_for(o)


## The kinds the music is for: a fighting unit or a gun (not workers, horses, medics, wagons, musicians, flyers).
static func plays_for(o: Unit) -> bool:
	if o.is_worker() or MUSICIANS.has(o.kind) or o.kind == "horse" or o.d.get("medic", false):
		return false
	if o.is_air():
		return false
	return o.has_attack() or o.kind == "dragoon"


# ------------------------------------------------------------------ the tick (host / single player)

static func tick(u: Unit, delta: float) -> void:
	var g := u.game
	if u.band.is_empty() or legacy(u):
		u.band = fresh()
	band_id(u)
	pass_tick(g, true)
	# no orders: he keeps up with the soldiers near him (an escort); a band's Fifer and Piper keep to their Drummer
	if u.order == "idle" and u.queue.is_empty() and u.phase == "" and (u.kind == KIND or not in_band(u)):
		u._band_scan -= delta
		if u._band_scan <= 0.0:
			u._band_scan = 0.5
			var lead_man := escort_pick(u)
			if lead_man:
				u.cmd_follow(lead_man)
				u.band["esc"] = lead_man.get_instance_id()
	look_tick(u, delta)


## ONE PASS A PULSE for the whole match (the first musician to tick runs it): the bands form and break (`form`: the host
## only; a guest and a replay take "b" from the snapshot), the out-of-step marks, the rows, and the buffs on everyone
## in a ring.
static func pass_tick(g: Game, form: bool) -> void:
	var nxt := float(g.get_meta("band_pass", -1.0))
	if g.clock < nxt and g.clock >= nxt - float(B["pulse"]) * 2.0:
		return
	g.set_meta("band_pass", g.clock + float(B["pulse"]))
	var men: Array = []
	for o in g.units:
		if is_musician(o) and not o.dead and not o.off_field and o.aboard == null and not o.band.is_empty() and not legacy(o):
			men.append(o)
	if form:
		form_bands(g, men)
		keep_rows(g, men)
	mark_out_of_step(g, men)
	play_over(g, men)


## Every pulse: is each band still a band (one of each, all three within KEEP x the ring of each other), and do free
## musicians make new ones (the closest sets first)? Returns the number of bands (tests).
static func form_bands(g: Game, men: Array) -> int:
	var r := float(B["area"])
	var keep := r * float(B["keep"])
	var free: Array = []
	var bands := 0
	var seen := {}
	for o in men:
		var k := band_key(o)
		if k == 0:
			free.append(o)
			continue
		var key := "%d:%d" % [o.team, k]
		if seen.has(key):
			continue
		var ms := members(g, o.team, k)
		var ok := ms.size() == 3
		if ok:
			for i in 3:
				for j in range(i + 1, 3):
					if (ms[i] as Unit).position.distance_to((ms[j] as Unit).position) > keep:
						ok = false
		seen[key] = ok
		if ok:
			bands += 1
			continue
		# broken: every one of that key is lone again
		for x in men:
			if x.team == o.team and band_key(x) == k:
				_set_band(x, 0)
				if not free.has(x):
					free.append(x)
	# new bands: every set of one drummer, one fifer, one piper of a side, each within the others' rings
	var sets: Array = []
	for d in free:
		if d.kind != KIND:
			continue
		for f in free:
			if f.kind != "band_fifer" or f.team != d.team or f.position.distance_to(d.position) > r:
				continue
			for p in free:
				if p.kind != "band_piper" or p.team != d.team or p.position.distance_to(d.position) > r or p.position.distance_to(f.position) > r:
					continue
				var sc: float = d.position.distance_to(f.position) + d.position.distance_to(p.position) + f.position.distance_to(p.position)
				sets.append([sc, sets.size(), d, f, p])
	sets.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var used := {}
	for s in sets:
		if used.has(s[2]) or used.has(s[3]) or used.has(s[4]):
			continue
		for i in [2, 3, 4]:
			used[s[i]] = true
		var dr: Unit = s[2]
		var k := band_id(dr)
		for i in [2, 3, 4]:
			_set_band(s[i], k)
		bands += 1
		if g.mlog:
			g.mlog.add("%s: a Marching Band forms (Drummer #%d)" % [g.mlog.who(dr.team), k])
		if dr.team == g.human and dr.visible:
			g.float_text(centre([s[2], s[3], s[4]]) + Vector2(0, -44), Loc.t("BAND!"), Color(1.0, 0.86, 0.45))
		# a new band falls in: idle Fifer and Piper to their places beside the Drummer
		for i in [3, 4]:
			var m: Unit = s[i]
			if m.order == "idle" and m.queue.is_empty():
				_row_move(m, dr, dr.position)
	return bands


static func _set_band(u: Unit, k: int) -> void:
	if band_key(u) == k:
		return
	u.band["b"] = k
	u.band.erase("rwp")
	u.queue_redraw()


## A band's Fifer / Piper beside its Drummer: his place in the row when the Drummer stands at (or walks to) `at`.
static func row_spot(m: Unit, dr: Unit, at: Vector2) -> Vector2:
	var side := float(SIDE.get(ins_of(m), 0.0))
	return at + Vector2(side * (-1.0 if dr.anim_flip else 1.0), 0.0)


static func _row_move(m: Unit, dr: Unit, at: Vector2) -> void:
	var spot := row_spot(m, dr, at)
	if m.position.distance_to(spot) < 10.0:
		return
	m.cmd_move(spot)
	m.band["rwp"] = m.order_point


## THE ROW KEEPS: while a band's Drummer walks, its Fifer and Piper (unless told otherwise: idle, on their row move or
## their escort) walk to their places beside where he is going.
static func keep_rows(g: Game, men: Array) -> void:
	for dr in men:
		if dr.kind != KIND or not in_band(dr):
			continue
		var walking: bool = dr.velocity.length() > 12.0
		if not walking:
			continue
		var at: Vector2 = dr.order_point if dr.order in ["move", "amove"] and dr.order_point.distance_to(dr.position) < 900.0 else dr.position + dr.velocity * 0.8
		for m in mates(dr):
			if m == dr:
				continue
			var mine: bool = m.order == "idle" and m.queue.is_empty()
			mine = mine or (m.order == "move" and m.band.has("rwp") and (m.band["rwp"] as Vector2).distance_to(m.order_point) < 1.0)
			mine = mine or (m.order == "follow" and m.order_target != null and is_instance_valid(m.order_target) and int(m.band.get("esc", 0)) == m.order_target.get_instance_id())
			if not mine:
				continue
			var spot := row_spot(m, dr, at)
			if m.band.has("rwp") and m.order == "move" and (m.band["rwp"] as Vector2).distance_to(spot) < 16.0:
				continue
			_row_move(m, dr, at)


## A group move with a whole band in it (Game.group_move): the Fifer and the Piper go to their places beside the
## Drummer's spot, so the band arrives (and marches) as a row.
static func row_spots(us: Array, spots: Dictionary) -> void:
	for dr in us:
		if not (dr is Unit) or dr.kind != KIND or not in_band(dr) or not spots.has(dr):
			continue
		for m in mates(dr):
			if m != dr and us.has(m):
				spots[m] = row_spot(m, dr, spots[dr])


## Out of step: a lone musician whose ring overlaps the ring of a lone musician of another instrument (allied).
static func mark_out_of_step(g: Game, men: Array) -> void:
	var r2 := float(B["area"]) * 2.0
	for u in men:
		var oos := false
		if not in_band(u):
			for v in men:
				if v != u and not in_band(v) and ins_of(v) != ins_of(u) and g.allied(u.team, v.team) \
						and u.position.distance_to(v.position) < r2:
					oos = true
					break
		if bool(u.band.get("oos", false)) != oos:
			u.band["oos"] = oos
			u.queue_redraw()


## The sources of music now: each band one ring round its three (each instrument at the band's numbers), each lone
## musician his own ring. [{"at", "team", "ins", "v", "band", "solo", "src"}]
static func sources(g: Game, men: Array) -> Array:
	var out: Array = []
	var done := {}
	for u in men:
		if in_band(u):
			var key := "%d:%d" % [u.team, band_key(u)]
			if done.has(key):
				continue
			done[key] = true
			var ms := members(g, u.team, band_key(u))
			var c := centre(ms)
			for m in ms:
				out.append({"at": c, "team": m.team, "ins": ins_of(m), "v": share(m), "band": true, "solo": lead(m) != "", "src": m})
		else:
			out.append({"at": u.position, "team": u.team, "ins": ins_of(u), "v": share(u), "band": false, "solo": lead(u) != "", "src": u})
	return out


## Every covered unit in a ring gets its buffs for a little longer. Returns how many it reached (tests).
static func play_over(g: Game, men: Array) -> int:
	if men.is_empty():
		return 0
	var src := sources(g, men)
	var r2 := float(B["area"]) * float(B["area"])
	var got := {}
	for o in g.units:
		if o.dead or o.off_field or o.aboard != null or not plays_for(o):
			continue
		var es: Array = []
		for s in src:
			if (o.position.distance_squared_to(s["at"]) <= r2) and g.allied(int(s["team"]), o.team):
				es.append(s)
		if not es.is_empty():
			got[o] = es
	for o in got:
		mix(o, got[o])
	return got.size()


## A covered unit's buffs from every ring reaching it: each stat the STRONGEST (the same instrument never adds up);
## LONE musicians of different instruments overlapping here are out of step: only the strongest of their buffs counts
## (a band's ring is never out of step). Sets band_mul, band_until, band_show.
static func mix(o: Unit, es: Array) -> void:
	var best := {}       # ins -> [value, from a band, solo]
	var lone := {}       # ins -> [value, solo] (lone musicians only)
	for s in es:
		var ins := String(s["ins"])
		var v := float(s["v"])
		if bool(s["band"]):
			if not best.has(ins) or v > float(best[ins][0]):
				best[ins] = [v, true, bool(s["solo"])]
		elif not lone.has(ins) or v > float(lone[ins][0]):
			lone[ins] = [v, bool(s["solo"])]
	var dropped := {}
	if lone.size() > 1:
		# out of step: only the strongest lone buff (ties: drums, then fife, then pipes)
		var keep := ""
		for ins in ["drums", "fife", "pipes"]:
			if lone.has(ins) and (keep == "" or float(lone[ins][0]) > float(lone[keep][0])):
				keep = ins
		for ins in lone.keys():
			if ins != keep:
				dropped[ins] = lone[ins]
				lone.erase(ins)
	for ins in lone:
		if not best.has(ins) or float(lone[ins][0]) > float(best[ins][0]):
			best[ins] = [float(lone[ins][0]), false, bool(lone[ins][1])]
	o.band_mul = Vector3(1.0 + float(best["drums"][0]) if best.has("drums") else 1.0,
		1.0 + float(best["pipes"][0]) if best.has("pipes") else 1.0,
		1.0 + float(best["fife"][0]) if best.has("fife") else 1.0)
	o.band_until = o.game.clock + float(B["linger"])
	var show: Array = []
	for ins in ["drums", "fife", "pipes"]:
		if best.has(ins):
			show.append([ins, int(round(float(best[ins][0]) * 100.0)), (F_BAND if best[ins][1] else 0) | (F_SOLO if best[ins][2] else 0)])
		elif dropped.has(ins):
			show.append([ins, int(round(float(dropped[ins][0]) * 100.0)), F_OOS | (F_SOLO if dropped[ins][1] else 0)])
	if show != o.band_show:
		o.band_show = show


## The soldier a musician falls in behind when he has no orders: the nearest MOVING one of his side within his leash.
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

static func speed_mul(o: Unit) -> float:
	return o.band_mul.x if o.band_until > o.game.clock else 1.0


static func melee_mul(o: Unit) -> float:
	return o.band_mul.y if o.band_until > o.game.clock else 1.0


static func reload_mul(o: Unit) -> float:
	return o.band_mul.z if o.band_until > o.game.clock else 1.0


## The card's line for a buffed soldier, grouped by source and size: "Band +8%: speed, reload, melee",
## "Fife SOLO, band +40%: reload", "Pipes +5%: melee (out of step: not counted)".
static func buff_text(o: Unit) -> String:
	if o.band_until <= o.game.clock or o.band_show.is_empty():
		return ""
	var groups: Array = []      # [flags, percent, [instruments]]
	for e in o.band_show:
		var hit := false
		for gr in groups:
			if int(gr[0]) == int(e[2]) and int(gr[1]) == int(e[1]):
				(gr[2] as Array).append(String(e[0]))
				hit = true
		if not hit:
			groups.append([int(e[2]), int(e[1]), [String(e[0])]])
	var parts := PackedStringArray()
	for gr in groups:
		var fl := int(gr[0])
		var ins: Array = gr[2]
		var who := ""
		if fl & F_BAND and ins.size() > 1 and not (fl & F_SOLO):
			who = Loc.t("Band")
		else:
			who = ", ".join(ins.map(func(k) -> String: return Loc.t(String(B[k]["label"]))))
			if fl & F_SOLO:
				who = Loc.t("%s SOLO") % who
			if fl & F_BAND:
				who = Loc.t("%s, band") % who
		var line := "%s +%d%%: %s" % [who, int(gr[1]), ", ".join(ins.map(func(k) -> String: return Loc.t(String(B[k]["short"]))))]
		if fl & F_OOS:
			line = Loc.t("%s (out of step: not counted)") % line
		parts.append(line)
	return " · ".join(parts)


# ------------------------------------------------------------------ orders (Unit.band_solo: the net funnel)

static func solo_problem(u: Unit, ins := "") -> String:
	if not is_musician(u) or legacy(u):
		return "?"
	if ins != "" and ins != ins_of(u):
		return "?"
	var who := String(B[ins_of(u)]["who"])
	if lead(u) != "":
		return "The %s is playing his solo." % who
	for m in mates(u):
		if m != u and lead(m) != "":
			return "The band is already playing a solo."
	var cd := cooldown_left(u)
	if cd > 0.0:
		return "The %s can solo again in %d s." % [who, int(ceil(cd))]
	return ""


static func solo(u: Unit, ins := "") -> String:
	if u.band.is_empty():
		u.band = fresh()
	var why := solo_problem(u, ins)
	if why != "":
		u.game.tell(u.team, why, true)
		return why
	var g := u.game
	u.band["se"] = g.clock + solo_time(u)
	u.band["cd"] = g.clock + float(B["cooldown"])
	g.set_meta("band_pass", -1.0)       # (the solo reaches the ring at once)
	u.queue_redraw()
	if g.mlog:
		g.mlog.add("%s's %s: solo%s" % [g.mlog.who(u.team), String(B[ins_of(u)]["who"]), " (band)" if in_band(u) else ""])
	return ""


## The SOLO button: a plain press makes ONE of the selected musicians of that instrument play (the first free one),
## `all` (Ctrl) every one that can. Each goes through the funnel (Unit.band_solo). Returns how many were asked.
static func solo_pick(list: Array, ins: String, all: bool) -> int:
	var n := 0
	for u in list:
		if is_musician(u) and not u.dead and ins_of(u) == ins and solo_problem(u, ins) == "":
			u.band_solo(ins)
			n += 1
			if not all:
				break
	return n


## SELECT BAND: every member of the bands of the selected musicians.
static func band_members_of(list: Array) -> Array:
	var out: Array = []
	for u in list:
		if not is_musician(u) or u.dead:
			continue
		var ms := mates(u)
		if ms.is_empty():
			ms = [u]
		for m in ms:
			if not out.has(m):
				out.append(m)
	return out


# ------------------------------------------------------------------ the computer

## The computer's musicians (AI._band trains a Drummer, a Fifer and a Piper once it has an Armoury and an army): its
## Fifers and Pipers go to a Drummer of theirs without one of them (forming a band); a band (by its Drummer) keeps
## behind the line; every musician solos where it pays:
##  - FIFE when 3 or more soldiers in the ring are shooting;  - PIPES when half or more of the fighting ones are at
##    the bayonet or the sabre;  - DRUMS to catch a retreating enemy or to get out of a lost fight.
static func ai_tick(g: Game, t: int) -> void:
	var men: Array = []
	for u in g.units:
		if u.team == t and not u.dead and is_musician(u) and not u.band.is_empty() and not legacy(u):
			men.append(u)
	for u in men:
		if u.kind == KIND:
			ai_place(g, t, u)
		elif not in_band(u):
			ai_form_up(g, u, men)
		else:
			# in a band: whatever the army told him, he keeps to his Drummer's row
			var dr := drummer_of(u)
			if dr == null:
				continue
			var off_row: bool = u.position.distance_to(row_spot(u, dr, dr.position)) > 90.0
			if u.order in ["amove", "attack", "patrol"] or (off_row and u.order == "idle"):
				_row_move(u, dr, dr.position)
	var done := {}
	for u in men:
		var key := band_key(u)
		if key != 0:
			if done.has(key):
				continue
			done[key] = true
			ai_solo(g, t, mates(u))
		else:
			ai_solo(g, t, [u])


## A computer's lone Fifer / Piper: to the nearest Drummer of his side whose band lacks his instrument (and no one of it
## nearer to that Drummer is already on his way), at his place in the row.
static func ai_form_up(g: Game, u: Unit, men: Array) -> void:
	var ins := ins_of(u)
	var best: Unit = null
	var bd := INF
	for dr in men:
		if dr.kind != KIND:
			continue
		if in_band(dr):
			continue
		var taken := false
		for o in men:
			if o != u and ins_of(o) == ins and not in_band(o) and o.position.distance_to(dr.position) < u.position.distance_to(dr.position):
				taken = true
				break
		if taken:
			continue
		var dd: float = dr.position.distance_squared_to(u.position)
		if dd < bd:
			bd = dd
			best = dr
	if best == null:
		return
	var spot := row_spot(u, best, best.position)
	if u.position.distance_to(spot) > 40.0 and (u.order != "move" or u.order_point.distance_to(spot) > 60.0):
		u.cmd_move(spot)


## Solos where they pay, for a band (its members) or a lone musician ([him]). One solo at a time in a band.
static func ai_solo(g: Game, t: int, ms: Array) -> void:
	if ms.is_empty():
		return
	for m in ms:
		if lead(m) != "":
			return
	var at := centre(ms)
	var r := float(B["area"])
	var shooting := 0
	var close := 0
	var fighting := 0
	var ours := 0
	var back := 0
	var chasing := 0
	for o: Unit in g.units_near(at, r):
		if o.team != t or not plays_for(o) or o.dead:
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
	for e: Unit in g.units_near(at, r + 120.0):
		if g.hostile(e.team, t) and not e.dead and not e.is_worker() and e.has_attack():
			foes += 1
			for o: Unit in g.units_near(at, r):
				if o.team == t and plays_for(o) and o.velocity.length() > 20.0 and o.velocity.dot(o.position - e.position) > 0.0:
					back += 1
					break
	var wants: Array = []
	if fighting >= 3 and close * 2 >= fighting:
		wants = ["pipes", "fife"] if shooting >= 2 else ["pipes"]
	elif shooting >= 3:
		wants = ["fife", "pipes"] if close >= 1 else ["fife"]
	elif (chasing >= 3) or (foes > ours + 2 and back >= 1 and ours >= 1):
		wants = ["drums"]
	for w in wants:
		for m in ms:
			if ins_of(m) == w and solo_problem(m, w) == "":
				solo(m, w)
				return


## BEHIND THE LINE: a Drummer (his band with him) walks to a spot BEHIND his nearest group of soldiers (70 px back from
## the nearest enemy), so the ring covers the line and the enemy meets the soldiers first; with no enemy about he falls
## in behind them. His orders from the army are overridden.
const AI_BACK := 70.0


static func ai_place(g: Game, t: int, u: Unit) -> void:
	var men: Array = []
	for o: Unit in g.units_near(u.position, 420.0):
		if o.team == t and covers(u, o) and o.kind != "cannon" and o.kind != "mortar":
			men.append(o)
	if men.is_empty():
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

## The sound, the buffs' display and the redraw while the ring pulses (also on an online guest and in a replay:
## NetPuppet, which runs the pass without forming bands). The sound: BandSound (one band, or a few lone musicians).
static func look_tick(u: Unit, delta: float) -> void:
	BandSound.need(u.game)
	if not legacy(u):
		pass_tick(u.game, false)
	u._band_draw_t -= delta
	if u._band_draw_t <= 0.0 and u.visible and u.game.view_rect.has_point(u.position):
		u._band_draw_t = 0.1
		u.queue_redraw()
		if u._band_fx:
			u._band_fx.queue_redraw()


## His ring on the ground (Unit._draw_unit, under him), for everyone who sees him (the telegraph):
##  - a BAND: one ring round the three, drawn by its Drummer: gold, ticks of the three colours, a small BAND mark (the
##    Fifer and the Piper draw none);
##  - a LONE musician: his own ring, plainer (thin, in his instrument's colour), dashed and marked "out of step" where it
##    overlaps a lone musician of another instrument;
##  - in a SOLO: the leading instrument's colour, thicker and pulsing.
static func draw_ring(u: Unit) -> void:
	if legacy(u):
		_draw_ring_legacy(u)
		return
	if u.band.is_empty():
		return
	var r := float(B["area"])
	var pulse := 0.5 + 0.5 * sin(u.game.clock * 5.0)
	if in_band(u):
		if u.kind != KIND:
			return
		var ms := mates(u)
		var at := centre(ms) - u.position
		var ld := ""
		for m in ms:
			if lead(m) != "":
				ld = lead(m)
		var c := Color(1.0, 0.82, 0.3, 0.75)
		if ld != "":
			c = (B[ld]["col"] as Color)
			c.a = 0.65 + 0.3 * pulse
		u.draw_arc(at, r, 0.0, TAU, 96, Color(0.15, 0.09, 0.03, 0.4), 5.0 if ld != "" else 4.0, true)
		u.draw_arc(at, r, 0.0, TAU, 96, c, 3.0 if ld != "" else 2.2, true)
		for i in 24:
			var a := TAU * float(i) / 24.0 + u.game.clock * 0.3
			var k: String = ["drums", "fife", "pipes"][i % 3]
			var cc: Color = B[k]["col"]
			cc.a = 0.8
			var dv := Vector2.from_angle(a)
			u.draw_line(at + dv * (r - 8.0), at + dv * r, cc, 2.0, true)
		_label(u, at + Vector2(0, 26), Loc.t("BAND"), Color(1.0, 0.86, 0.45) if ld == "" else (B[ld]["col"] as Color).lightened(0.2), 12)
		return
	var ins := ins_of(u)
	var col: Color = B[ins]["col"]
	var ld2 := lead(u)
	var oos := bool(u.band.get("oos", false))
	if ld2 != "":
		col.a = 0.6 + 0.3 * pulse
		u.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.15, 0.09, 0.03, 0.35), 4.0, true)
		u.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, col, 2.5, true)
	elif oos:
		col = col.lerp(Color(0.55, 0.55, 0.55), 0.35)
		col.a = 0.7
		for i in 32:
			var a0 := TAU * float(i) / 32.0
			u.draw_arc(Vector2.ZERO, r, a0, a0 + TAU / 64.0, 4, Color(0.15, 0.09, 0.03, 0.35), 3.5, true)
			u.draw_arc(Vector2.ZERO, r, a0, a0 + TAU / 64.0, 4, col, 2.0, true)
	else:
		col.a = 0.45
		u.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.15, 0.09, 0.03, 0.25), 2.5, true)
		u.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, col, 1.2, true)
	if oos:
		_label(u, Vector2(0, -48.0), Loc.t("out of step"), Color(0.85, 0.85, 0.85, 0.95), 11)      # (over his head)


static func _label(ci: CanvasItem, at: Vector2, t: String, col: Color, size: int) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at + Vector2(-w * 0.5, 0)
	ci.draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.8))
	ci.draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## (an old FULL replay's band: its ring as 0.36.0 drew it)
static func _draw_ring_legacy(u: Unit) -> void:
	var ins: Array = u.band.get("m", [])
	if ins.is_empty():
		return
	var r := float(B["area"])
	var ld := lead(u)
	var c := Color(1.0, 0.86, 0.45, 0.6)
	if ld != "":
		c = (B[ld]["col"] as Color)
	u.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.15, 0.09, 0.03, 0.35), 3.0, true)
	u.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, c, 1.5, true)


## The notes rising over a musician in his SOLO, in his instrument's colour (code-drawn over the real art;
## docs/art_style_inconsistency.md). He also bobs (lead_bob).
static func draw_kit(u: Unit, ci: CanvasItem) -> void:
	var ld := lead(u)
	if ld == "" or u.dead:
		return
	var t := u.game.clock
	var n := 4
	for i in n:
		var ph := fmod(t * 0.7 + float(i) / float(n), 1.0)
		var c: Color = B[ld]["col"]
		c.a = (1.0 - ph) * 0.9
		var p := Vector2(-10.0 + 20.0 * float(i) / float(n - 1) + 3.0 * sin(t * 3.0 + i), -40.0 - ph * 22.0)
		ci.draw_circle(p, 2.0, c)
		ci.draw_line(p + Vector2(1.8, 0), p + Vector2(1.8, -6), c, 1.0)


## How high he hops now: a small bob in his solo (0 otherwise). A band's three bob IN STEP (the band's clock), a lone
## musician on his own beat (his offset: out of step).
static func lead_bob(u: Unit, _ins := "") -> float:
	if u.dead or lead(u) == "":
		return 0.0
	return absf(sin(u.game.clock * 9.0 + step_offset(u) * TAU)) * 2.0


## A musician's place against the band's shared beat (0..1 of a beat): 0 in a band (in step); a lone man his own.
static func step_offset(u: Unit) -> float:
	if in_band(u) or u.band.is_empty():
		return 0.0
	return 0.17 + 0.19 * float(int(u.band.get("id", 0)) % 4)


## The walk frame in step: a band's three take the same frame (Unit._animate asks).
static func frame_in_step(u: Unit, n: int, fps: float) -> int:
	return posmod(int(floor(u.game.clock * fps + step_offset(u) * float(n))), maxi(n, 1))


## (legacy) AN OLD FULL REPLAY's band unit: its Fifer and Piper drawn as child sprites of the Drummer, as 0.36.0 did.
static func group_look(u: Unit) -> void:
	var spr := u.sprite
	if spr == null:
		return
	for ins in ["fife", "pipes"]:
		var name: String = "band_" + ins
		var c: Sprite2D = spr.get_node_or_null(name)
		if not legacy(u) or not has(u, ins):
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
		var key := "%s_%s" % [u.anim, u.anim_dir]
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
		var f := posmod(spr.frame + (1 if ins == "fife" else 2), c.hframes) if not u.dead else mini(spr.frame, c.hframes - 1)
		if c.frame != f:
			c.frame = f
		c.position = Vector2(SPOT[ins]) - spr.position


static var _strips := {}


## A number that changes when his drawing should (Unit's redraw key).
static func draw_key(u: Unit) -> int:
	return (8 if lead(u) != "" else 0) + band_key(u) * 3 + (int(u.game.clock * 6.0) % 97) * 16


# ------------------------------------------------------------------ the buff markers over the soldiers' heads

## Settings BAND BUFF MARKS: 0 ALWAYS, 1 SELECTED (selected units, the one under the cursor, and everyone in a ring
## during a solo: the default), 2 OFF.
static func marks_shown(o: Unit) -> bool:
	if o.band_until <= o.game.clock or o.band_show.is_empty() or Settings.band_marks == 2:
		return false
	if Settings.band_marks == 0 or o.selected or o.game.hover_target == o:
		return true
	for e in o.band_show:
		if int(e[2]) & F_SOLO and not (int(e[2]) & F_OOS):
			return true
	return false


## A number that changes when his markers should be redrawn (Unit._draw_key).
static func marks_key(o: Unit) -> int:
	if not marks_shown(o):
		return 0
	var h := 7
	for e in o.band_show:
		h = h * 31 + int(e[1]) * 8 + int(e[2]) + INSTRUMENTS.find(String(e[0])) * 1000
	return (h % 99991) + 1


## Over his head: for each buff, the instrument's small icon and "+8%" (buffs of the same size and kind share one
## number: a band's three icons and one "+8%"); a band's in gold, a lone musician's in white, a solo bigger and in the
## instrument's colour, an out-of-step one grey and struck through. `top`: the health bar's.
static func draw_marks(o: Unit, top: float) -> void:
	if not marks_shown(o):
		return
	var font := ThemeDB.fallback_font
	var groups: Array = []      # [[instruments], percent, flags]
	for e in o.band_show:
		if not groups.is_empty() and int(groups[-1][1]) == int(e[1]) and int(groups[-1][2]) == int(e[2]):
			(groups[-1][0] as Array).append(String(e[0]))
		else:
			groups.append([[String(e[0])], int(e[1]), int(e[2])])
	var items: Array = []
	var w := 0.0
	for gr in groups:
		var fl := int(gr[2])
		var solo_on := (fl & F_SOLO) != 0 and (fl & F_OOS) == 0
		var sz := 13 if solo_on else 10
		var ic := 13.0 if solo_on else 10.0
		var t := "+%d%%" % int(gr[1])
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var iw := ic * float((gr[0] as Array).size()) + 1.0
		items.append([gr[0], fl, sz, ic, t, tw, iw])
		w += iw + tw + 3.0
	var x := -w * 0.5
	var y := top - 5.0
	var oa := o.ov_a(true)      # (OVERLAY OPACITY: the marks see-through, full on the selected and hovered: Entity.ov_a)
	for it in items:
		var fl: int = it[1]
		var ic: float = it[3]
		var col := Color(1, 1, 1)
		if fl & F_OOS:
			col = Color(0.62, 0.62, 0.62, 0.85)
		elif fl & F_SOLO:
			col = (B[String(it[0][0])]["col"] as Color).lightened(0.25)
		elif fl & F_BAND:
			col = Color(1.0, 0.8, 0.25)
		col.a *= oa
		o.draw_rect(Rect2(Vector2(x - 0.5, y - ic - 0.5), Vector2(ic * float((it[0] as Array).size()) + 1.0, ic + 1.0)), Color(0, 0, 0, 0.55 * oa))
		for ins in it[0]:
			var tex: Texture2D = Game.tex("res://assets/icons/ab_band_%s.png" % ins)
			if tex:
				o.draw_texture_rect(tex, Rect2(Vector2(x, y - ic), Vector2(ic, ic)), false, Color(1, 1, 1, 0.45 * oa) if fl & F_OOS else Color(1, 1, 1, oa))
			x += ic
		x += 1.0
		var p := Vector2(x, y - 1.0)
		o.draw_string_outline(font, p, it[4], HORIZONTAL_ALIGNMENT_LEFT, -1, it[2], 5, Color(0, 0, 0, 0.95 * sqrt(oa)))     # (the outline stronger: the number reads on snow and sand)
		o.draw_string(font, p, it[4], HORIZONTAL_ALIGNMENT_LEFT, -1, it[2], col)
		if fl & F_OOS:
			o.draw_line(Vector2(x - float(it[6]), y - ic * 0.5), Vector2(x + float(it[5]), y - ic * 0.5), Color(0.85, 0.3, 0.25, 0.9 * oa), 1.2)
		x += float(it[5]) + 3.0


# ------------------------------------------------------------------ the card

## The train button's note.
static func train_note(_g: Game, _t: int, k := KIND) -> String:
	var ins := String(MUSICIANS.get(k, "drums"))
	return Loc.t("A musician on his own plays +%d%% %s in his ring. A Drummer, a Fifer and a Piper standing together make a BAND: stronger (+%d%%, solos +%d%%) but in one spot.") % [
		int(round(float(B[ins]["second"]) * 100.0)), Loc.t(String(B[ins]["stat_text"])), int(round(float(B["band_second"]) * 100.0)), int(round(float(B["band_lead"]) * 100.0))]


## The selection card's line.
static func card_line(u: Unit) -> String:
	if legacy(u):
		return Loc.t("Plays: %s") % ", ".join((u.band.get("m", []) as Array).map(func(k) -> String: return Loc.t(String(B[k]["label"]))))
	var ins := ins_of(u)
	var a := int(round(float(B["area"]) / Defs.TILE))
	var line := ""
	if in_band(u):
		line = Loc.t("In a BAND: +%d%% %s (solo +%d%%) · in step · %d tiles") % [int(round(float(B["band_second"]) * 100.0)), Loc.t(String(B[ins]["stat_text"])),
			int(round(float(B["band_lead"]) * 100.0)), a]
	else:
		line = Loc.t("Alone: +%d%% %s (solo +%d%%) · %d tiles") % [int(round(float(B[ins]["second"]) * 100.0)), Loc.t(String(B[ins]["stat_text"])),
			int(round(float(B[ins]["lead"]) * 100.0)), a]
		if bool(u.band.get("oos", false)):
			line += " · " + Loc.t("OUT OF STEP with another musician: only the stronger buff counts where their rings meet")
	if lead(u) != "":
		line += " · " + Loc.t("SOLO: %d s") % int(ceil(solo_left(u)))
	elif cooldown_left(u) > 0.0:
		line += " · " + Loc.t("solo again in %d s") % int(ceil(cooldown_left(u)))
	return line


## Its command card (HUD._ability_buttons): each instrument's SOLO (a press: ONE of the selected musicians of it, the
## first free; Ctrl: all of them), and SELECT BAND (every member of their bands).
static func card(hud, list: Array, units: Array) -> void:
	var men := units.filter(func(o: Unit) -> bool: return is_musician(o) and o.team == hud.game.human and not o.dead and not legacy(o))
	if men.is_empty():
		return
	var a := int(round(float(B["area"]) / Defs.TILE))
	for ins in INSTRUMENTS:
		var mine := men.filter(func(o: Unit) -> bool: return ins_of(o) == ins)
		if mine.is_empty():
			continue
		var info: Dictionary = B[ins]
		var lab2 := String(info["label"]).to_upper() + " SOLO"
		hud._tip_for[lab2] = [String(info["solo_title"]), Loc.t("One %s plays his solo (Ctrl: every selected %s): %s +%d%% to your soldiers in his ring (%d tiles) for %d s; in a BAND +%d%% for %d s. Then %d s before he can solo again; one solo at a time in a band.") % [
			Loc.t(String(info["who"])), Loc.t(String(info["who"])), Loc.t(String(info["stat_text"])), int(round(float(info["lead"]) * 100.0)), a, int(B["solo"]),
			int(round(float(B["band_lead"]) * 100.0)), int(B["band_solo"]), int(B["cooldown"])]]
		hud._ctrl_all[lab2] = true
		var free := mine.filter(func(o: Unit) -> bool: return solo_problem(o, ins) == "")
		var u: Unit = free[0] if not free.is_empty() else mine[0]
		var why2 := "" if not free.is_empty() else solo_problem(u, ins)
		var playing := mine.any(func(o: Unit) -> bool: return lead(o) != "")
		var cd := cooldown_left(u)
		var corner := ("%d/%d" % [free.size(), mine.size()]) if mine.size() > 1 and not free.is_empty() else (("%ds" % int(ceil(cd))) if free.is_empty() and cd > 0.0 else "")
		list.append(["ab_band_" + ins, ("~ " if playing else "") + lab2, func() -> void:
			solo_pick(hud.game.selected_units(), ins, hud.all_mod()), why2 == "", why2, corner])
	var banded := men.any(func(o: Unit) -> bool: return in_band(o))
	hud._tip_for["SELECT BAND"] = [Loc.t("Select the band"), Loc.t("Selects the whole band (its Drummer, Fifer and Piper) of each selected musician, so you can order the three as one. A band forms by itself when a Drummer, a Fifer and a Piper stand within each other's rings.")]
	list.append(["ab_band_join", "SELECT BAND", func() -> void:
		hud.game.set_selection(band_members_of(hud.game.selected_units())), banded, "" if banded else Loc.t("Not in a band: stand a Drummer, a Fifer and a Piper together (each within the others' rings)."), ""])


# ------------------------------------------------------------------ save / net

static func save(u: Unit) -> Dictionary:
	if u.band.is_empty():
		return {}
	if legacy(u):
		return u.band.duplicate(true)
	return {"id": int(u.band.get("id", 0)), "se": snappedf(float(u.band.get("se", 0.0)), 0.01), "cd": snappedf(float(u.band.get("cd", 0.0)), 0.01),
		"b": int(u.band.get("b", 0))}


## A musician's state from a save or a snapshot. A 0.33-0.36 BAND (its instruments in "m") loads as its musicians
## standing together (`spawn`: a save; this unit is its Drummer, a Fifer and a Piper are added beside him; `hp`: the old
## band's health, shared out); without `spawn` (an old FULL replay's picture) it stays a legacy band drawn as before.
static func load_state(u: Unit, d: Dictionary, spawn := true, hp := -1.0) -> void:
	if d.has("m") and u.kind == KIND:
		if not spawn:
			u.band = d.duplicate(true)
			if not u.band.has("cd") or not (u.band["cd"] is Dictionary):
				u.band["cd"] = {}
			return
		_convert(u, d, hp)
		return
	u.band = fresh()
	u.band["id"] = int(d.get("id", 0))
	u.band["se"] = float(d.get("se", 0.0))
	u.band["cd"] = float(d.get("cd", 0.0)) if not (d.get("cd") is Dictionary) else 0.0
	u.band["b"] = int(d.get("b", 0))


## An old band unit -> its Drummer (this unit) and a Fifer / Piper per instrument it had (or its side had researched),
## standing beside him in a row (so a band), each with his share of its health, its solo and cooldowns.
static func _convert(u: Unit, d: Dictionary, hp: float) -> void:
	var g := u.game
	var ins: Array = (d.get("m", []) as Array).duplicate()
	for k in ["fife", "pipes"]:
		var rk := research_of(k)
		if not ins.has(k) and rk != "" and u.team >= 0 and u.team < g.players.size() and g.has_tech(u.team, rk):
			ins.append(k)
	if not ins.has("drums"):
		ins.append("drums")
	var old_max := float(B["old_hp"]) + float(B["old_hp_per"]) * float(ins.size())
	var frac := clampf((hp if hp >= 0.0 else old_max) / maxf(old_max, 1.0), 0.05, 1.0)
	var cds: Dictionary = d.get("cd", {}) if d.get("cd") is Dictionary else {}
	var s := String(d.get("s", ""))
	var se := float(d.get("se", 0.0))
	var made: Array = [u]
	u.band = fresh()
	u.max_hp = float(u.d["hp"])
	u.hp = maxf(1.0, u.max_hp * frac)
	for k in ["fife", "pipes"]:
		if not ins.has(k):
			continue
		var m: Unit = g._add_unit(unit_of(k), u.team, u.position + Vector2(SIDE[k], 0.0))
		m.band = fresh()
		m.hp = maxf(1.0, m.max_hp * frac)
		made.append(m)
	for m in made:
		var k := ins_of(m)
		if s == k:
			m.band["se"] = se
		m.band["cd"] = float(cds.get(k, 0.0))
		band_id(m)
	if made.size() == 3:
		var key := band_id(u)
		for m in made:
			m.band["b"] = key
