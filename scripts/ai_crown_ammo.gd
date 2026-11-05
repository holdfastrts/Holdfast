extends RefCounted
## THE CROWN COMPUTER AND ITS AMMUNITION (crown-ammo, the owner's rule of 2026-11-05; docs/crown_ammo.md). Powder buys the
## shots a Barracks soldier comes out with (Game.arm_recruit); with none he fights with bayonet or sabre until he refills
## at a Mill, Barracks, Town Hall or Powder Wagon. The computer:
##  1. TRAINS ARMED MEN: a Musketeer or Dragoon is queued only with a full load's powder in the bank (AI._soldier_key asks
##     musket_ok), as before the rule when he cost 10 powder; riders and Officers are queued as before (a dry one has
##     his sabre), and a deliberate rush (the Horse Breeder opening) never waits for powder.
##  2. KEEPS POWDER FOR ITS GUNS (the Barracks' ARM WITH POWDER toggle): off while a Mortar waits in the Foundry's queue
##     or its guns run low, and the bank is under GUN_KEEP; on again at GUN_KEEP + 10.
##  3. SENDS EMPTY MEN TO REFILL BEFORE A FIGHT: a man with a firearm and few shots (under LOW of a load; a dry pistol),
##     not fighting (no enemy within SAFE_R) and within REARM_R of a reloading point (a stocked Powder Wagon counts), walks
##     to it while the bank (or the wagon) has powder, and stays there out of the army's orders (AI._on_errand) until he
##     is full, the powder runs out or MAX_T passes. A deliberate rush's riders are left alone.
## Design: docs/design_principles.md 1 (a punishment matches the mistake: an empty man is a weak man, not a lost one) and
## 2 (powder is exposed income: the Mills and the wagon matter).

const GUN_KEEP := 30.0         # powder kept for the guns while the toggle is off
const LOW := 0.4               # a man under this share of a load goes to refill when he can
const SAFE_R := 10.0           # (tiles) no enemy this near: he may leave to refill
const REARM_R := 22.0          # (tiles) a reloading point within this
const MAX_T := 30.0            # (s) at most this long on a refill errand
const TICK := 2.0              # (s) between looks

var ai                          # the AI (scripts/ai.gd)
var rearming := {}              # Unit -> the clock his errand ends
var _t := 0.0
var sent := 0                   # (statistics: refill errands sent)


func _init(owner) -> void:
	ai = owner


## A Musketeer or Dragoon may be queued at this Barracks: its toggle on and a full load in the bank, or a deliberate rush.
func musket_ok(b: Building, kind: String) -> bool:
	if not Defs.AMMO.has(kind) or String(Defs.AMMO[kind]) != "musket":
		return true
	if ai._rush_open():
		return true
	return b.arm_powder and ai._res2() >= float(Defs.ammo_load(kind))


## The errands and the toggle, on the computer's horse-and-wagon stage (AI._think_stage 4).
func tick() -> void:
	_t -= ai._think_dt
	if _t > 0.0:
		return
	_t = TICK
	_toggle()
	_rearm()


## ARM WITH POWDER at every Barracks: off while the guns need the powder more: a Mortar waits in a Foundry's queue (its
## 20 powder is paid when queued: the next one's) or a gun of ours is under half its shots, and the bank is under GUN_KEEP
## (on again at GUN_KEEP + 10). Not before a gun is wanted: the Musketeers are the line (the first look at the coached
## games: switching it off while a Foundry had no gun yet left the Economy plan with no Musketeers for minutes).
func _toggle() -> void:
	var on := true
	var fd: Array = ai._mine("foundry").filter(func(f: Building) -> bool: return f.built)
	if not fd.is_empty() and not ai._rush_open():
		var guns: Array = ai.game.army(ai.team).filter(func(u: Unit) -> bool: return u.kind == "cannon" or u.kind == "mortar")
		var low_guns: bool = guns.any(func(u: Unit) -> bool: return u.powder < u._pmax * 0.5)
		var mortar_wait: bool = fd.any(func(f: Building) -> bool: return f.queue.has("mortar"))
		var bank: float = ai._res2()
		var was: bool = ai._mine("barracks").all(func(b: Building) -> bool: return b.arm_powder)
		if (low_guns or mortar_wait) and bank < (GUN_KEEP if was else GUN_KEEP + 10.0):
			on = false
	for b in ai._mine("barracks"):
		if b.arm_powder != on:
			b.arm_powder = on


## Empty men to a reloading point; back to the army once full.
func _rearm() -> void:
	var g: Game = ai.game
	var now: float = g.clock
	for u in rearming.keys():
		if not is_instance_valid(u) or u.dead:
			rearming.erase(u)
			continue
		var full: bool = u.ammo_shots() >= u.ammo_max()
		var dry_bank: bool = ai._res2() < 1.0 and not _wagon_near(u)
		if full or now > float(rearming[u]) or (dry_bank and u.order == "idle"):
			rearming.erase(u)
			if u.order == "move":
				u.cmd_stop()
	if ai._res2() < 2.0 and ai._wagon() == null:
		return
	var rush: bool = ai._rush_open()
	for u in g.army(ai.team):
		if rearming.has(u) or u.ammo_weapon() == "" or u.dead or u.off_field or u.aboard != null:
			continue
		if u.kind == "powder_wagon" or ai._on_errand(u) or u.order in ["mount", "dismount"]:
			continue
		if rush and u.has_pistol():
			continue           # (a deliberate rush's riders fight with the sabre)
		var need: bool
		if u.has_pistol():
			need = not u.pistol and u.powder < 1.0
		else:
			need = float(u.ammo_shots()) < float(u.ammo_max()) * LOW
		if not need:
			continue
		if u.target != null and is_instance_valid(u.target) and u.target.edge_distance(u.position) < SAFE_R * Defs.TILE:
			continue
		if _foe_near(u):
			continue
		var at := _point_for(u)
		if at == Vector2.INF:
			continue
		u.cmd_move(at)
		rearming[u] = now + MAX_T
		sent += 1


## A reloading point within REARM_R tiles: a finished Mill, Town Hall or armed Barracks (the bank pays: only with powder in
## it), or our Powder Wagon with powder; where to stand (just beside it). INF: none.
func _point_for(u: Unit) -> Vector2:
	var best := Vector2.INF
	var bd: float = REARM_R * Defs.TILE
	if ai._res2() >= 2.0:
		for b in ai.game.buildings:
			if b.team != ai.team or not b.built or b.dead or not (Defs.POWDER["from"] as Array).has(b.kind):
				continue
			if b.kind == "barracks" and not b.arm_powder:
				continue
			var dd: float = b.edge_distance(u.position)
			if dd < bd:
				bd = dd
				var c: Vector2 = b.center()
				best = c + (u.position - c).normalized() * (float(maxi(b.size.x, b.size.y)) * Defs.TILE * 0.5 + 18.0)
	var w: Unit = ai._wagon()
	if w != null and not w.dead and w.powder >= 4.0 and w.aboard == null:
		var dw := w.position.distance_to(u.position)
		if dw < bd:
			best = w.position + (u.position - w.position).normalized() * 30.0
	return best


func _wagon_near(u: Unit) -> bool:
	var w: Unit = ai._wagon()
	return w != null and not w.dead and w.powder >= 1.0 and w.position.distance_to(u.position) < float(Defs.POWDER["range"]) * Defs.TILE + 16.0


func _foe_near(u: Unit) -> bool:
	for o in ai.game.units_near(u.position, SAFE_R * Defs.TILE):
		if ai.game.hostile(o.team, ai.team) and not o.dead and not o.off_field and o.has_attack():
			return true
	return false
