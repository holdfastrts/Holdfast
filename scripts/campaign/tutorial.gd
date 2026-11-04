class_name Tutorial
extends RefCounted
## The TUTORIAL (docs/tutorial.md): lessons built on the campaign's mission engine. The list is campaign/tutorial.json
## (groups of lessons: Basics, then a group per faction); each lesson is a mission (campaign/missions/<id>.json with
## "tutorial": true and "steps", written out by Campaign.expand_steps). The lessons never show in the CAMPAIGN's hub.
## Progress (a tick per finished lesson) is kept in user://tutorial.json.

const INDEX := "res://campaign/tutorial.json"
const PROGRESS := "user://tutorial.json"


static func index() -> Dictionary:
	return Campaign._json(INDEX)


## The groups: [{"id", "title", "faction", "lessons": [ids]}].
static func groups() -> Array:
	return index().get("groups", [])


static func lesson_ids() -> Array:
	var out: Array = []
	for gr in groups():
		for id in gr.get("lessons", []):
			out.append(String(id))
	return out


static func is_lesson(id: String) -> bool:
	return lesson_ids().has(id)


## The lesson after this one in the list ("" none).
static func next_of(id: String) -> String:
	var ids := lesson_ids()
	var i := ids.find(id)
	return String(ids[i + 1]) if i >= 0 and i + 1 < ids.size() else ""


static func progress() -> Dictionary:
	var f := FileAccess.open(PROGRESS, FileAccess.READ)
	if f == null:
		return {"done": {}}
	var d: Variant = JSON.parse_string(f.get_as_text())
	var p: Dictionary = d if d is Dictionary else {}
	if not (p.get("done") is Dictionary):
		p["done"] = {}
	return p


static func done(id: String) -> bool:
	return (progress()["done"] as Dictionary).has(id)


static func mark_done(id: String) -> void:
	var p := progress()
	var e: Dictionary = p["done"].get(id, {})
	e["times"] = int(e.get("times", 0)) + 1
	p["done"][id] = e
	var f := FileAccess.open(PROGRESS, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(p, "\t"))


## Every player-facing string of the lesson list (the translation check).
static func index_strings() -> Array:
	var out: Array = [String(index().get("title", "")), String(index().get("about", ""))]
	for gr in groups():
		out.append(String(gr.get("title", "")))
		out.append(String(gr.get("about", "")))
	return out.filter(func(s: String) -> bool: return s != "")
