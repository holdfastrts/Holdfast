class_name VetLook
## The masks the team shader recolours a sprite by (no veterancy any more: since 0.36.x veterancy is the chevron over
## the unit, VetChevrons; the owner, 2026-11-14: "drop the hat and skin colors, only the chevrons").
## A Crown soldier's small trim (the lace of his tricorne, the band of his felt hat, the comb and brim of his helmet)
## stays drawn BLACK as every soldier's always was under 25 kills: shaders/team.gdshader through a mask per sprite
## strip, assets/units/trim_masks/<art>/ (tools/import_vet_trim.py). The Brood's skin is as painted.
## THE VENOM LINE (Defs.VENOM_SWAP: the belly and a flank stripe in the team colour) has its own mask per strip,
## assets/units/venom_masks/<art>/ (tools/import_venom_colours.py), set here too.

const STYLES := {"crown": 1}
const VENOM := 3          # (the venom line's own masks: only a mask folder)
const DIRS := {1: "res://assets/units/trim_masks/", VENOM: "res://assets/units/venom_masks/"}


## Does this unit wear the venom line's colours (its art: a Venom Challenger drawn as the Venom Sire too)?
static func venom(u: Unit) -> bool:
	return Defs.VENOM_SWAP.has(u.art) or Defs.VENOM_SWAP.has(u.kind)

static var _masks := {}       # "style:strip path" -> its mask (or null)


static func style_of(u: Unit) -> int:
	return int(STYLES.get(String(u.d.get("faction", "")), 0))


## Sets the unit's masks (when it is made, loaded or raised).
static func apply(u: Unit) -> void:
	if u.sprite == null:
		return
	var m := u.sprite.material as ShaderMaterial
	if m == null:
		return
	var st := style_of(u)
	m.set_shader_parameter("vet_style", st)
	m.set_shader_parameter("venom_swap", venom(u))
	if st > 0 or venom(u):
		update_mask(u)


## The mask for the strip the unit's sprite shows now (on every change of strip).
static func update_mask(u: Unit) -> void:
	var m := u.sprite.material as ShaderMaterial
	if m == null:
		return
	if style_of(u) > 0:
		m.set_shader_parameter("vet_mask", mask_for(u.sprite.texture, style_of(u)))
	if venom(u):
		m.set_shader_parameter("venom_mask", mask_for(u.sprite.texture, VENOM))


static func mask_for(t: Texture2D, st: int) -> Texture2D:
	if t == null or not DIRS.has(st):
		return null
	# (asked on every change of strip, of every unit on screen: by the texture's id first, no text built)
	var ik := t.get_instance_id() * 4 + st
	var hit = _by_id.get(ik, false)
	if hit is bool:
		hit = _mask_slow(t, st)
		_by_id[ik] = hit
	return hit


static var _by_id := {}


static func _mask_slow(t: Texture2D, st: int) -> Texture2D:
	var p := t.resource_path
	var k := "%d:%s" % [st, p]
	if not _masks.has(k):
		var mp: String = String(DIRS[st]) + p.trim_prefix("res://assets/units/")
		_masks[k] = load(mp) if p.begins_with("res://assets/units/") and ResourceLoader.exists(mp) else null
	return _masks[k]
