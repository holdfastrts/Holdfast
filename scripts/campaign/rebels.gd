class_name Rebels
extends RefCounted
## THE FREE ASSEMBLY (campaign mission 1, docs/campaign_m1_build.md): a minor, non-playable side, GREEN AND BLACK.
## Until the owner's own rebel art arrives, its men are STAND-INS: Crown units in the rebels' team colour, given a ROLE
## here. Everything the rebels are is in this one table, so the real sprites can replace the stand-ins without touching
## the mission:
##   - a mission's "units" entry or "spawn" action says "as": "<role>" (and its "kind" is the role's own kind);
##   - MissionRun.apply_role puts the role on the unit: its sprites (ART, if the folder is in), its name over the bar,
##     its torch.
## To drop in the owner's sprites for a role: put the strips in assets/units/<art>/ (<anim>_<dir>.png, the same
## animation names as the stand-in's kind: a militiaman needs a Musketeer's idle/walk/aim/fire/reload/melee/death),
## and add the art's cell, anchor and frame counts to RebelArt.ART (scripts/campaign/rebel_art.gd). The role then
## wears them; nothing else changes.

## role -> {kind: the Defs unit it plays as, art: its own sprites (used once listed in ART), name: shown over its bar,
## torch: burns enemy buildings it stands at}
const ROLES := {
	"militia": {"kind": "musketeer", "art": "rebel_militia", "about": "Free Assembly militia: a musket and a green cockade."},
	"torch": {"kind": "labourer", "art": "rebel_torch", "torch": true, "about": "A torch-bearer: sets barns and houses alight."},
	"pikeman": {"kind": "pikeman", "art": "rebel_pikeman", "about": "A pike from the farm armouries."},
	"varenne": {"kind": "dismounted", "art": "rebel_varenne", "name": "Etienne Varenne", "about": "The Free Assembly's orator."},
}

const TORCH_DPS := 11.0              # a torch-bearer's fire on a building he stands at, per second (armour ignored)
const TORCH_REACH := 26.0            # how close to a building's edge he must be
const TORCH_SEEK := 3.0              # seconds between a scripted torch-bearer's looks for the next building


static func role(r: String) -> Dictionary:
	return ROLES.get(r, {})


## A unit becomes a rebel of this role (its art if drawn, its name, its torch).
static func apply(u: Unit, r: String) -> void:
	var ro := role(r)
	if ro.is_empty() or u == null:
		return
	u.set_meta("rebel_role", r)
	var a := String(ro.get("art", ""))
	if a != "" and ArtData.UNITS.has(a):      # (RebelArt.ART lists the sprite sets that are in)
		u.art = a
		if u.sprite:
			u._set_anim(u.anim if u.anim != "" else "idle", true)
	if ro.has("name"):
		u.set_meta("mission_name", String(ro["name"]))
	if bool(ro.get("torch", false)):
		u.set_meta("torch", true)
	u.queue_redraw()


## Every tick (MissionRun): torch-bearers burn the enemy building they stand at; the scripted ones (no person plays
## them) walk on to the nearest enemy building when they have nothing to burn.
static func tick(run: MissionRun, dt: float) -> void:
	var g := run.game
	for u in g.units:
		if u.dead or not u.has_meta("torch"):
			continue
		var best: Building = null
		var bd := INF
		for b in g.buildings:
			if b.dead or b.ghost or not g.hostile(b.team, u.team):
				continue
			var dd: float = b.edge_distance(u.position)
			if dd < bd:
				bd = dd
				best = b
		if best == null:
			continue
		if bd <= TORCH_REACH:
			best.take_damage(TORCH_DPS * dt, u)
			if randf() < dt * 0.8:
				g.spawn_effect("fire", best.center() + Vector2(randf_range(-30, 30), randf_range(-20, 20)), 0.8)
			continue
		if run.player_teams.has(u.team):
			continue
		var t := float(u.get_meta("torch_t", 0.0)) - dt
		if t <= 0.0 and (u.velocity.length() < 5.0 or u.order != "move"):
			t = TORCH_SEEK
			# (to the near edge of the building, not its middle: he must stand at it)
			var half := float(maxi(best.size.x, best.size.y)) * Defs.TILE * 0.5
			var p: Vector2 = best.center() + (u.position - best.center()).normalized() * (half * 0.75 + 4.0)
			g.group_move([u], p, false)
		u.set_meta("torch_t", t)
