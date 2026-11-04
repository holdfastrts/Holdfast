class_name FogMemory
extends RefCounted
## REMEMBERED ENEMY BUILDINGS UNDER THE FOG (the owner, 2026-11-04: "after we scout buildings I don't think they are
## showing as ghosts in the fog of war, they should"; docs/fog_ghosts.md). As in StarCraft and Age of Empires: an enemy
## building your side has seen stays drawn where it stood, as it LAST looked (its frame, its damage, how far it was
## built, its gear ring, stopped), a little darker, once your eyes leave; the live building is hidden meanwhile (no
## live damage, building progress, animation or bars under the fog). When your side sees any of its footprint again
## the picture goes: the live building shows again, or its ruin, or nothing if the ruin is gone.
## THE BROOD: its ROOTED creatures are its buildings (BroodRoot: a footprint on the grid), so a rooted Rootmaw, Mound
## Turtle, father or Mother (and a grub's cocoon) seen and left is remembered the same way, rooted where it was seen,
## until that spot is seen again (it may have uprooted and walked off meanwhile: the picture stays till you look; a
## creature seen walking elsewhere drops its old picture). Walking creatures are units: shown only while seen.
## A remembered picture is not a thing: it can't be picked or selected (an enemy building that goes under the fog
## leaves your selection), and a right-click there is an order to the ground (move / attack-move to that spot).
## Only your own screen's fog (not watching computers, a replay or full vision: no change there). Pictures are taken
## at a fog update when something goes out of sight (Game._update_vis, four times a second), from its Sprite2D parts.

const TINT := Vector3(0.74, 0.74, 0.8)          # the team shader's tint on a remembered picture (a cold, darker grey)
const MOD := Color(0.74, 0.74, 0.8)              # the same for its parts drawn without the team shader
const MINI_DARK := 0.35                          # a remembered building's minimap square: its team colour this much darker

var g: Game
var mem := {}           # source instance id -> {"node", "cells" (Rect2i), "rect", "team", "gear", "src" (weakref)}
var ruins: Array = []   # dead enemy buildings still lying there (out of Game.buildings): shown only while seen
var _shown_rooted := {}  # a rooted Brood creature's instance id -> true while it is shown (its picture is taken as it goes)


func _init(game: Game) -> void:
	g = game


## Any of the cells in r seen now in hv.
func _seen(hv: PackedByteArray, r: Rect2i) -> bool:
	var x0 := maxi(0, r.position.x)
	var y0 := maxi(0, r.position.y)
	var x1 := mini(g.W, r.end.x)
	var y1 := mini(g.H, r.end.y)
	for y in range(y0, y1):
		var row := y * g.W
		for x in range(x0, x1):
			if hv[row + x] == 1:
				return true
	return false


static func cells_of_rect(r: Rect2) -> Rect2i:
	var T := float(Defs.TILE)
	var a := Vector2i(floori(r.position.x / T), floori(r.position.y / T))
	var b := Vector2i(ceili(r.end.x / T), ceili(r.end.y / T))
	return Rect2i(a, (b - a).max(Vector2i.ONE))


## Is this Brood creature a building now (rooted, rooting, uprooting or a cocoon: it has its footprint)?
static func rooted_like(u: Unit) -> bool:
	return u._k_nb and not u.dead and BroodNew.ROOTERS.has(u.kind) and u.tesla_mode != "packed" and BroodRoot.has_fp(u)


## The fog update's buildings part (your own screen's fog: not watching computers, not full vision). hv: what your side
## sees now; ft: whose eyes (you). Shows the enemy buildings seen now, hides and remembers those that just went out of
## sight, and drops the pictures whose ground is seen again.
func update_buildings(hv: PackedByteArray, ft: int) -> void:
	# pictures whose spot is seen again go (the live thing, if any, shows itself below)
	if not mem.is_empty():
		var changed := false
		for id in mem.keys():
			var r: Dictionary = mem[id]
			if _seen(hv, r["cells"]):
				_forget(id)
				changed = true
		if changed and g.gear_net:
			g.gear_net.queue_redraw()
	for b in g.buildings:
		if g.allied(b.team, ft):
			continue
		if b.ghost:
			b.visible = false            # another side's planned site: unseen
			continue
		var now := _seen(hv, Rect2i(b.cell, b.size))
		if now:
			if not b.seen_by_human:
				b.seen_by_human = true
				g._unknown_dirty = true
			b.visible = true
			if mem.has(b.get_instance_id()):
				_forget(b.get_instance_id())
		else:
			if b.visible and b.seen_by_human:
				remember(b, Rect2i(b.cell, b.size), b.rect())
			b.visible = false
			if b.selected or g.selection.has(b):
				g.selection.erase(b)
				b.selected = false
				b.queue_redraw()
	# ruins: only while seen (a building razed out of sight stays its remembered picture until you look)
	for i in range(ruins.size() - 1, -1, -1):
		var rb = ruins[i]
		if not is_instance_valid(rb):
			ruins.remove_at(i)
			continue
		rb.visible = _seen(hv, Rect2i(rb.cell, rb.size))


## A rooted Brood creature of another side (Game._update_vis's units loop): shown while any of its footprint is seen,
## remembered when it goes out of sight. Returns its visibility.
func rooted_visible(u: Unit, hv: PackedByteArray) -> bool:
	var id := u.get_instance_id()
	var r := BroodRoot.rect_of(u)
	var now := not u.off_field and _seen(hv, cells_of_rect(r))
	if now:
		_shown_rooted[id] = true
		if mem.has(id):
			_forget(id)
		return true
	if _shown_rooted.has(id):
		_shown_rooted.erase(id)
		remember(u, cells_of_rect(r), r)
		if g.selection.has(u):
			g.selection.erase(u)
			u.selected = false
	return false


## Any other unit of another side (walking: not a building now), its visibility just set: it is no longer shown rooted
## (rooting again out of sight is not seeing it), and one seen walking elsewhere drops its old rooted picture.
func walker(u: Unit) -> void:
	var id := u.get_instance_id()
	_shown_rooted.erase(id)
	if u.visible and mem.has(id):
		_forget(id)


## A dead enemy building (Game.on_building_died): its ruin is shown only while seen.
func add_ruin(b: Building) -> void:
	ruins.append(b)


## Full vision now (the sandbox's FOG: OFF, watching with all vision): no pictures; the ruins show.
func clear(show_ruins := true) -> void:
	for id in mem.keys():
		_forget(id)
	_shown_rooted.clear()
	for rb in ruins:
		if is_instance_valid(rb):
			rb.visible = show_ruins
	if g.gear_net:
		g.gear_net.queue_redraw()


func _forget(id: int) -> void:
	var r: Dictionary = mem[id]
	mem.erase(id)
	var n: Node2D = r["node"]
	if is_instance_valid(n):
		n.queue_free()


## Take its picture as it looks now: every Sprite2D part shown, copied (texture, frame, region, flips, offset, place,
## its order and z) under one node in the world (y-sorted at its place, as it was), darker; its gear ring as it stands.
func remember(src: Node2D, cells: Rect2i, rect: Rect2) -> void:
	var id := src.get_instance_id()
	if mem.has(id):
		_forget(id)
	var node := Node2D.new()
	node.name = "FogGhost"
	g.world.add_child(node)
	node.global_transform = src.global_transform
	var inv := src.global_transform.affine_inverse()
	var mats := {}
	_copy_parts(src, src, node, inv, mats)
	var gear: Array = []
	if src is Building and g.gear_net and GearNet.has_gear(src):
		gear = g.gear_net.ring_items(src)
		for it in gear:
			var m: Color = it[5]
			it[5] = Color(m.r * MOD.r, m.g * MOD.g, m.b * MOD.b, m.a)
		g.gear_net.queue_redraw()
	mem[id] = {"node": node, "cells": cells, "rect": rect, "team": int(src.get("team")), "gear": gear, "src": weakref(src)}


func _copy_parts(src: Node2D, n: Node, into: Node2D, inv: Transform2D, mats: Dictionary) -> void:
	for c in n.get_children():
		if not (c is CanvasItem) or not (c as CanvasItem).visible:
			continue
		if c is Sprite2D and (c as Sprite2D).texture != null:
			into.add_child(_copy_sprite(src, c, inv, mats))
		if c.get_child_count() > 0:
			_copy_parts(src, c, into, inv, mats)


func _copy_sprite(src: Node2D, s: Sprite2D, inv: Transform2D, mats: Dictionary) -> Sprite2D:
	var o := Sprite2D.new()
	o.texture = s.texture
	o.hframes = s.hframes
	o.vframes = s.vframes
	o.frame = s.frame
	o.region_enabled = s.region_enabled
	o.region_rect = s.region_rect
	o.region_filter_clip_enabled = s.region_filter_clip_enabled
	o.centered = s.centered
	o.offset = s.offset
	o.flip_h = s.flip_h
	o.flip_v = s.flip_v
	o.transform = inv * s.global_transform
	# its z, its filter, its material and its colour as drawn (what it takes from the parts between it and the building)
	var z := 0
	var col := s.self_modulate
	var filt := CanvasItem.TEXTURE_FILTER_PARENT_NODE
	var mat: Material = null
	var mat_done := false
	var z_done := false
	var p: Node = s
	while p is CanvasItem:
		var ci := p as CanvasItem
		if not z_done:
			z += ci.z_index
			z_done = not ci.z_as_relative          # (an absolute z: that is it)
		col *= ci.modulate
		if filt == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			filt = ci.texture_filter
		if not mat_done and (ci.material != null or not ci.use_parent_material):
			mat = ci.material
			mat_done = true
		if p == src:
			break
		p = p.get_parent()
	o.z_index = z
	o.texture_filter = filt
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader == Entity.TEAM_SHADER:
		if not mats.has(mat):
			var dm := (mat as ShaderMaterial).duplicate() as ShaderMaterial
			var t0 = dm.get_shader_parameter("tint")
			var tv: Vector3 = t0 if t0 is Vector3 else Vector3.ONE
			dm.set_shader_parameter("tint", Vector3(tv.x * TINT.x, tv.y * TINT.y, tv.z * TINT.z))
			dm.set_shader_parameter("flash", 0.0)
			mats[mat] = dm
		o.material = mats[mat]
	else:
		o.material = mat
		col = Color(col.r * MOD.r, col.g * MOD.g, col.b * MOD.b, col.a)
	o.modulate = col
	return o


## The remembered rings in view (GearNet._draw).
func gear_items(vr: Rect2) -> Array:
	var out: Array = []
	for id in mem:
		var gi: Array = mem[id]["gear"]
		if gi.is_empty() or not vr.grow(400.0).intersects(mem[id]["rect"]):
			continue
		out.append_array(gi)
	return out


## The remembered buildings' squares on the minimap (the HUD): [rect in world px, colour].
func minimap_rects() -> Array:
	var out: Array = []
	for id in mem:
		var r: Dictionary = mem[id]
		out.append([r["rect"], g.team_colour(int(r["team"])).darkened(MINI_DARK)])
	return out


## Is there a remembered picture of this thing (tools/test_fog_ghosts.gd)?
func remembers(id: int) -> bool:
	return mem.has(id)
