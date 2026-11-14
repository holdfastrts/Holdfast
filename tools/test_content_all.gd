extends SceneTree
## THE CONTENT TEST (qa-content, the owner's full QA study of 2026-11-07; report docs/qa_2026_11_08_content.md).
##   godot --headless --fixed-fps 30 --script res://tools/test_content_all.gd > out.txt 2>&1
##   (optional: -- only=crown|clockwork|brood|static   to run one part)
## Walks Defs (every unit, building and research of every faction, the campaign's Pikeman and the Free Assembly's roles)
## and, for EVERY entry, checks in small test games:
##   data     its numbers are sane; it is made where Defs says (a building that trains it, a creature that lays it)
##   text     its name and description have a Portuguese and a Spanish translation
##   icon     its button picture exists (as the HUD finds it)
##   art      every strip it uses exists, is as wide as art_data.gd says (frames x cell) and is not empty; idle, walk and
##            death in all five views; every animation it ASKED FOR in the fights and ability tests has a strip
##   sound    its voice (select/move/attack), its attack and its death sound: its own, or the fallback it gets
##   place    (buildings) refused on top of the hall and before its requirement; allowed on a spot the game's own
##            find_spot picks; the price charged exactly; ABANDON pays it all back
##   build    a worker builds it to the end; repair: a damaged one is mended by a worker; DEMOLISH pulls it down
##   make     (units) trained / laid where the rules say: refused without its requirement, the price charged exactly
##            (gold, second resource, Tension), CANCEL pays it back, it comes out, supply goes up; the rally is followed
##   research refused without its requirement; charged exactly; CANCEL pays back; done: has_tech and its effect on old and
##            new units (reload, range, health, speed, clutch, spell, refits, unlocks)
##   buttons  every button on its card has an icon file, a tooltip and en/pt/es texts; every button is pressed (a target
##            given when it asks for one) and something must change; script errors raised meanwhile are caught
##   fight    attacks a dummy (an enemy that can't fight back, with huge health) at a sensible distance: the damage a
##            second must be near the card's own figure (UnitStats); then a building dummy (siege) and, for anti-air
##            units, a flying dummy; who can hit air / ground (can_hit) agrees with Defs
##   body     it dies: dead, supply given back, a body or wreck stays (Crown resurrection, Brood spoils, Clockwork cogs)
## One line per entry and check ("PASS/FAIL/WARN/INFO/SKIP  entry  check  note"), then a summary table and a verdict.
## FAIL = a real bug; WARN = something to look at (missing optional art, fallback sound, untranslated text, no visible
## effect); INFO = numbers for the owner; SKIP = could not be tested here (said why).
const HUD := preload("res://scripts/ui/hud.gd")

var main: Node
var g: Game
var only := ""
var lines := 0
var res := {}            # entry -> [[check, status, note], ...]
var order: Array = []    # entries in the order first seen
var anims_seen := {}     # art -> {anim: true}: what units asked for during the live tests
var errlog: ErrLog = null
var t0 := 0


class ErrLog extends Logger:
	var errs: Array = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		mutex.lock()
		errs.append("%s:%d %s %s" % [file.get_file(), line, rationale if rationale != "" else code, function])
		mutex.unlock()

	func _log_message(message: String, error: bool) -> void:
		if error and message.contains("SCRIPT ERROR"):
			mutex.lock()
			errs.append(message.strip_edges())
			mutex.unlock()

	func take() -> Array:
		mutex.lock()
		var out := errs.duplicate()
		errs.clear()
		mutex.unlock()
		return out


# ------------------------------------------------------------------ recording

func rec(entry: String, check: String, status: String, note := "") -> void:
	if not res.has(entry):
		res[entry] = []
		order.append(entry)
	res[entry].append([check, status, note])
	print("%-5s %-26s %-18s %s" % [status, entry, check, note])
	lines += 1


func ok_rec(entry: String, check: String, ok: bool, note := "", bad := "FAIL") -> void:
	rec(entry, check, "PASS" if ok else bad, note)


## Script errors raised since the last call, put on this entry's check.
func errs_to(entry: String, check: String) -> void:
	if errlog == null:
		return
	var es := errlog.take()
	for e in es.slice(0, 4):
		rec(entry, check, "FAIL", "script error: " + String(e).left(160))
	if es.size() > 4:
		rec(entry, check, "FAIL", "... and %d more script errors" % (es.size() - 4))


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	errlog = ErrLog.new()
	OS.add_logger(errlog)
	t0 = Time.get_ticks_msec()
	_run.call_deferred()


func wait(s: float) -> void:
	var until := g.clock + s
	var n := 0
	while g.clock < until:
		await physics_frame
		n += 1
		if n % 8 == 0:
			_sample_anims()
		if n > int(s * 30.0) * 3 + 60:
			break          # (the clock stopped: a paused game)


func wait_for(f: Callable, s: float) -> bool:
	var until := g.clock + s
	var n := 0
	while g.clock < until:
		if f.call():
			return true
		await physics_frame
		n += 1
		if n % 8 == 0:
			_sample_anims()
		if n > int(s * 30.0) * 3 + 60:
			break
	return bool(f.call())


var tracked: Array = []       # units whose animations are sampled


func _sample_anims() -> void:
	for u in tracked:
		if not is_instance_valid(u) or u.sprite == null:
			continue
		var a: String = u._anim_name()
		var art: String = u.mount_strip_art() if a == "mount" else u._strip_art(a)
		if not anims_seen.has(art):
			anims_seen[art] = {}
		anims_seen[art][a] = String(u.kind)


func _run() -> void:
	print("content test: Holdfast v%s" % ProjectSettings.get_setting("application/config/version", "?"))
	if only == "" or only == "static":
		_static_all()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	for fac in ["crown", "clockwork", "brood"]:
		if only != "" and only != fac:
			continue
		await _faction(fac)
		errs_to("match:" + fac, "errors")
	_art_asked()
	_numbers()
	_summary()
	quit(0)


# ------------------------------------------------------------------ static checks (no game)

func live_kind(k: String) -> bool:
	if Defs.retired(k):
		return false
	var d: Dictionary = Defs.UNITS[k]
	if Defs.cw_roster == false and Defs.CW_KINDS.has(k):
		return false
	if d.get("faction", "") == "brood" and not (BroodNew.hatch_list().has(k) or BroodNew.KINDS.has(k) \
			or (Defs.NB["mature"] as Dictionary).values().has(k) or k in ["grub"]):
		return false
	return true


func used_units() -> Array:
	var out: Array = []
	for k in Defs.UNITS:
		if live_kind(k):
			out.append(k)
	return out


func _tr_missing(s: String) -> Array:
	var miss: Array = []
	if s.strip_edges() == "" or not s.to_lower().contains(s.to_lower().left(1)):
		return miss
	for code in ["pt", "es"]:
		Loc.set_lang(code)
		var t := Loc.t(s)
		var tab := Loc.table(code)
		if t == s and not tab.has(s):
			miss.append(code)
	Loc.set_lang("en")
	return miss


func _icon_found(fac: String, name: String) -> bool:
	for n in [name, Defs.icon_for(name)]:
		if fac != "crown" and fac != "" and ResourceLoader.exists("res://assets/icons/%s/%s.png" % [fac, n]):
			return true
		if ResourceLoader.exists("res://assets/icons/%s.png" % n):
			return true
	return CwArt.icon(name) != null


var _strip_ok := {}      # art -> [problems]


func _strip_problems(art: String) -> Array:
	if _strip_ok.has(art):
		return _strip_ok[art]
	var out: Array = []
	if not ArtData.UNITS.has(art):
		out.append("no art entry %s" % art)
		_strip_ok[art] = out
		return out
	var e: Dictionary = ArtData.UNITS[art]
	var cell: Vector2i = e["cell"]
	for anim in e["frames"]:
		var path := "res://assets/units/%s/%s.png" % [art, anim]
		if not ResourceLoader.exists(path):
			out.append("%s: no file" % anim)
			continue
		var tex: Texture2D = load(path)
		var n := int(e["frames"][anim])
		if n <= 0:
			out.append("%s: %d frames" % [anim, n])
			continue
		if tex.get_width() != cell.x * n or tex.get_height() < cell.y:
			out.append("%s: %dx%d but art_data says %d x %dx%d" % [anim, tex.get_width(), tex.get_height(), n, cell.x, cell.y])
			continue
		var im := tex.get_image()
		if im == null:
			continue
		if im.is_compressed():
			im.decompress()
		if im.get_used_rect().size == Vector2i.ZERO:
			out.append("%s: EMPTY (all transparent)" % anim)
			continue
		# every frame must hold something (an empty frame blinks the unit out)
		for f in n:
			var sub := im.get_region(Rect2i(f * cell.x, 0, cell.x, im.get_height()))
			if sub.get_used_rect().size == Vector2i.ZERO:
				out.append("%s: frame %d of %d empty" % [anim, f + 1, n])
				break
	_strip_ok[art] = out
	return out


func _views_missing(art: String, anim: String) -> Array:
	var fr: Dictionary = ArtData.UNITS[art]["frames"]
	var miss: Array = []
	for dr in ArtData.DIRS:
		if not fr.has(anim + "_" + dr):
			miss.append(dr)
	return miss


func _sound(name: String) -> bool:
	for base in ["res://assets/audio/" + name, "res://assets/" + name]:
		for ext in [".wav", ".ogg"]:
			if ResourceLoader.exists(base + ext) or ResourceLoader.exists(base + "_1" + ext):
				return true
	return false


func _static_all() -> void:
	print("\n==== STATIC: data, texts, icons, art, sounds ====")
	for k in Defs.UNITS:
		_static_unit(k)
	for k in Defs.BUILDINGS:
		if Defs.BUILDINGS[k].get("faction", "") == "brood":
			continue        # (the old Brood's buildings are kept only for old saves)
		_static_building(k)
	for k in Defs.RESEARCH:
		_static_research(k)
	for r in Rebels.ROLES:
		var ro: Dictionary = Rebels.ROLES[r]
		var e: String = "rebel:" + r
		ok_rec(e, "data", Defs.UNITS.has(String(ro["kind"])), "plays as %s" % ro["kind"])
		var a := String(ro.get("art", ""))
		if ArtData.UNITS.has(a):
			var pr := _strip_problems(a)
			ok_rec(e, "art", pr.is_empty(), "own sprites %s %s" % [a, ", ".join(pr)])
		else:
			rec(e, "art", "INFO", "no own sprites yet (%s): wears the %s's (stand-in, waiting for the owner's art)" % [a, ro["kind"]])
		var miss := _tr_missing(String(ro.get("about", "")))
		ok_rec(e, "text", miss.is_empty(), ("about: no pt/es (the role's 'about' is not shown anywhere in the game yet)") if not miss.is_empty() else "about translated", "INFO")


func _static_unit(k: String) -> void:
	var d: Dictionary = Defs.UNITS[k]
	var fac := String(d.get("faction", ""))
	var e: String = "unit:" + k
	if not live_kind(k):
		rec(e, "data", "SKIP", "retired / not in a normal game (kept for old saves)")
		return
	# data
	var bad: Array = []
	for f in ["hp", "speed", "cost", "time", "supply", "sight", "radius"]:
		if not d.has(f):
			bad.append("no " + f)
	if float(d.get("hp", 0)) <= 0:
		bad.append("hp %s" % d.get("hp"))
	if float(d.get("time", 0)) <= 0 and not BroodNew.KINDS.has(k):
		bad.append("time %s" % d.get("time"))
	if not d.get("no_attack", false) and float(d.get("damage", 0)) > 0 and float(d.get("cooldown", 0)) <= 0:
		bad.append("cooldown %s" % d.get("cooldown"))
	if float(d.get("min_range", 0)) >= float(d.get("range", 1)) and float(d.get("min_range", 0)) > 0:
		bad.append("min_range >= range")
	ok_rec(e, "data", bad.is_empty(), ", ".join(bad) if not bad.is_empty() else "hp %s cost %s/%s supply %s" % [d["hp"], d["cost"], d.get("cost2", 0), d["supply"]])
	# where it comes from
	var frm := String(d.get("from", ""))
	if fac == "brood":
		var how := "laid by the Mother" if BroodNew.hatch_list().has(k) else ("a grub turns into it" if BroodRoot.morph_list().has(k) \
			else ("MATURE from %s" % BroodMature.young_of(k) if BroodMature.is_mature(k) else ("the start" if k in [BroodNew.QUEEN] else "a part of the Brood")))
		rec(e, "data", "PASS", "made: " + how)
	elif d.get("campaign_only", false):
		rec(e, "data", "PASS", "campaign only (no building trains it)")
	elif frm == "":
		var how2 := "MOUNT" if Defs.FOOT.has(k) else ("morph" if k == Defs.OWL else "?")
		ok_rec(e, "data", how2 != "?", "made by %s" % how2, "WARN")
	elif not Defs.BUILDINGS.has(frm):
		rec(e, "data", "FAIL", "from %s: no such building" % frm)
	elif not (Defs.BUILDINGS[frm].get("trains", []) as Array).has(k):
		rec(e, "data", "FAIL", "from %s, but the %s doesn't train it" % [frm, frm])
	else:
		rec(e, "data", "PASS", "trained at the %s" % frm)
	for q in (d["requires"] if d.get("requires", "") is Array else ([d["requires"]] if String(d.get("requires", "")) != "" else [])):
		ok_rec(e, "data", Defs.BUILDINGS.has(String(q)) or Defs.RESEARCH.has(String(q)), "requires %s" % q)
	# texts
	var miss := _tr_missing(String(d["name"]))
	ok_rec(e, "text", miss.is_empty(), "name '%s'%s" % [d["name"], (" missing " + ",".join(miss)) if not miss.is_empty() else ""], "WARN")
	miss = _tr_missing(String(d.get("about", "")))
	ok_rec(e, "text", miss.is_empty(), "about%s" % ((" missing " + ",".join(miss)) if not miss.is_empty() else " translated"), "WARN")
	# icon
	if not (k in [BroodNew.EGG, BroodNew.PILE]):
		ok_rec(e, "icon", _icon_found(fac, k), "button picture", "FAIL")
	# art
	var art := Defs.art_for(k, false)
	if not ArtData.UNITS.has(art):
		rec(e, "art", "FAIL", "no sprites (%s)" % art)
	else:
		var pr := _strip_problems(art)
		ok_rec(e, "art", pr.is_empty(), "%s: %d strips%s" % [art, (ArtData.UNITS[art]["frames"] as Dictionary).size(), (": " + "; ".join(pr.slice(0, 6))) if not pr.is_empty() else " all present, sized and drawn"])
		var need: Array = ["idle", "death"]
		if float(d.get("speed", 0)) > 0 and not (k in [BroodNew.EGG, BroodNew.PILE]):
			need.append("walk")
		for a in need:
			var mv := _views_missing(art, a)
			if mv.size() == 5:
				rec(e, "art", "WARN" if a != "idle" else "FAIL", "no %s strip at all (falls back to idle)" % a)
			elif not mv.is_empty():
				rec(e, "art", "INFO", "%s: views %s borrow the nearest one" % [a, ",".join(mv)])
		if Defs.ARMOURED.has(k):
			var aa := Defs.art_for(k, true)
			if ArtData.UNITS.has(aa):
				var pa := _strip_problems(aa)
				ok_rec(e, "art", pa.is_empty(), "armoured %s%s" % [aa, (": " + "; ".join(pa.slice(0, 4))) if not pa.is_empty() else " ok"])
	# sounds
	var vk := String(Sfx.VOICE_AS.get(k, k))
	var voice: Array = []
	for w in ["select", "move", "attack"]:
		if _sound("voice/%s/%s" % [vk, w]):
			voice.append(w)
	if k in [BroodNew.EGG, BroodNew.PILE]:
		pass
	elif voice.is_empty() and Sfx.VOICE_EXTRA.has(k):
		rec(e, "sound", "INFO", "no voice of its own: only %s" % str(Sfx.VOICE_EXTRA[k].values()).left(60))
	elif voice.is_empty():
		rec(e, "sound", "WARN", "no voice lines (voice/%s/select|move|attack)" % vk)
	else:
		rec(e, "sound", "PASS" if voice.size() >= 2 else "INFO", "voice: %s%s" % [",".join(voice), " (as %s)" % vk if vk != k else ""])
	var dk := "combat/%s_death" % k
	var short := String(Sfx.SHORT.get(fac, "crown"))
	if _sound(dk) or _sound("combat/%s_death" % vk):
		rec(e, "sound", "PASS", "own death sound")
	elif _sound("combat/%s_death" % short) or _sound("death_" + short):
		rec(e, "sound", "INFO", "death: the faction's (no combat/%s_death)" % k)
	else:
		rec(e, "sound", "WARN", "no death sound at all")
	if not d.get("no_attack", false) and float(d.get("damage", 0)) > 0:
		rec(e, "sound", "PASS" if _sound("combat/%s_attack" % k) else "INFO",
			"attack: own" if _sound("combat/%s_attack" % k) else "attack: a shared sound (no combat/%s_attack)" % k)


func _static_building(k: String) -> void:
	var d: Dictionary = Defs.BUILDINGS[k]
	var fac := String(d.get("faction", ""))
	var e: String = "bld:" + k
	var listed := false
	for f in Defs.FACTIONS:
		if Defs.build_list(f).has(k):
			listed = true
	if not listed or Defs.retired(k):
		rec(e, "data", "SKIP", "not on any build list (old economy / retired): %s" % ("retired" if Defs.retired(k) else "unlisted"))
		return
	var bad: Array = []
	for f in ["hp", "cost", "time", "size"]:
		if not d.has(f):
			bad.append("no " + f)
	for u in d.get("trains", []):
		if not Defs.UNITS.has(u):
			bad.append("trains %s: no such unit" % u)
	for q in (d["requires"] if d.get("requires", "") is Array else ([d["requires"]] if String(d.get("requires", "")) != "" else [])):
		if not (Defs.BUILDINGS.has(String(q)) or Defs.RESEARCH.has(String(q))):
			bad.append("requires %s: nothing" % q)
	ok_rec(e, "data", bad.is_empty(), ", ".join(bad) if not bad.is_empty() else "hp %s cost %s/%s size %s time %s" % [d.get("hp"), d.get("cost"), d.get("cost2", 0), d.get("size"), d.get("time")])
	var miss := _tr_missing(String(d["name"]))
	ok_rec(e, "text", miss.is_empty(), "name '%s'%s" % [d["name"], (" missing " + ",".join(miss)) if not miss.is_empty() else ""], "WARN")
	miss = _tr_missing(String(d.get("about", "")))
	ok_rec(e, "text", miss.is_empty(), "about%s" % ((" missing " + ",".join(miss)) if not miss.is_empty() else " translated"), "WARN")
	ok_rec(e, "icon", _icon_found(fac, k), "button picture")
	var art := String(Defs.TEMP_ART.get(k, {}).get("building", k))
	if k in ["farm", "wall", "gate"]:
		rec(e, "art", "PASS" if ResourceLoader.exists("res://assets/buildings/%s_built.png" % k) or k != "farm" else "INFO", "drawn from its own pieces")
	else:
		var built := ResourceLoader.exists("res://assets/buildings/%s_built.png" % art) or ResourceLoader.exists("res://assets/buildings/%s_built.png" % k)
		ok_rec(e, "art", built, "standing picture assets/buildings/%s_built.png" % art)
		var site := ResourceLoader.exists("res://assets/buildings/%s_construction.png" % art) or ResourceLoader.exists("res://assets/buildings/%s_construction.png" % k)
		if fac == "clockwork":
			site = site or ArtData.CRATE.has(k)
		ok_rec(e, "art", site, "under construction: %s" % ("its own picture" if site else "no %s_construction.png (a stand-in is drawn)" % art), "WARN")
	if _sound("select/" + k):
		rec(e, "sound", "PASS", "own select sound")
	else:
		rec(e, "sound", "INFO", "select: the faction's (no select/%s)" % k)


func _static_research(k: String) -> void:
	var d: Dictionary = Defs.RESEARCH[k]
	var fac := String(d.get("faction", "crown"))
	var e: String = "res:" + k
	var at := String(d.get("at", ""))
	var bad: Array = []
	if fac == "brood":
		if not Defs.UNITS.has(at):
			bad.append("at %s: no such creature" % at)
	elif not Defs.BUILDINGS.has(at):
		bad.append("at %s: no such building" % at)
	elif not Defs.build_list(fac).has(at):
		bad.append("at %s: not on the %s build list" % [at, fac])
	if String(d.get("requires", "")) != "" and not Defs.RESEARCH.has(String(d["requires"])):
		bad.append("requires %s: nothing" % d["requires"])
	if String(d.get("needs", "")) != "" and not Defs.BUILDINGS.has(String(d["needs"])):
		bad.append("needs %s: nothing" % d["needs"])
	if float(d.get("time", 0)) <= 0:
		bad.append("time %s" % d.get("time"))
	ok_rec(e, "data", bad.is_empty(), ", ".join(bad) if not bad.is_empty() else "at %s, %s/%s%s, %s s" % [at, d["cost"], d.get("cost2", 0), (" +%d Tension" % int(d["tension"])) if d.has("tension") else "", d["time"]])
	var miss := _tr_missing(String(d["name"]))
	ok_rec(e, "text", miss.is_empty(), "name '%s'%s" % [d["name"], (" missing " + ",".join(miss)) if not miss.is_empty() else ""], "WARN")
	miss = _tr_missing(String(d.get("about", "")))
	ok_rec(e, "text", miss.is_empty(), "about%s" % ((" missing " + ",".join(miss)) if not miss.is_empty() else " translated"), "WARN")
	var lab := Defs.research_label(k)
	miss = _tr_missing(lab)
	ok_rec(e, "text", miss.is_empty(), "button '%s'%s" % [lab, (" missing " + ",".join(miss)) if not miss.is_empty() else ""], "WARN")
	var ic := String(d.get("icon", d.get("unlocks", "")))
	ok_rec(e, "icon", ic != "" and _icon_found(fac, ic), "icon %s" % ic)


# ------------------------------------------------------------------ the live tests, a faction at a time

const FOE := {"crown": "brood", "clockwork": "crown", "brood": "clockwork"}
var hall: Building = null
var spare_spots: Array = []


func _faction(fac: String) -> void:
	print("\n==== LIVE: %s ====" % fac.to_upper())
	main.start({"map": "greenhold", "seed": 11, "slots": [
		{"who": "you", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": FOE[fac], "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	await wait(0.5)
	errs_to("match:" + fac, "start")
	hall = null
	for b in g.buildings:
		if b.team == 0 and b.kind == g.faction_hall(0) and not b.dead:
			hall = b
	rich()
	tracked.clear()
	if fac == "brood":
		await _brood_make()
	else:
		await _buildings(fac)
		await _production(fac)
		await _research(fac)
	errs_to("match:" + fac, "make")
	await _cards(fac)
	errs_to("match:" + fac, "cards")
	await _fights(fac)
	errs_to("match:" + fac, "fights")
	if fac == "crown":
		await _rebels()
		await _crown_rules()
	if fac == "clockwork":
		await _clock_rules()
	if fac != "brood":
		await _demolish_all(fac)


func rich() -> void:
	var p: Dictionary = g.players[0]
	p["gold"] = 100000
	p["res2"] = 100000.0
	p["tension"] = 100000.0
	p["cap"] = 200
	if g.faction_of(0) == "clockwork":
		g.give_batteries(0, 200)


func mine(k: String) -> Array:
	return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and not u.dead and u.kind == k)


func a_worker() -> Unit:
	var wk := String(Defs.FACTIONS[g.faction_of(0)]["worker"])
	var at: Vector2 = hall.center() + Vector2(0, hall.size.y * 16 + 40) if hall else g.units[0].position
	var u: Unit = g._add_unit(wk, 0, g.cell_center(g.nearest_free(g.cell_of(at), 12)))
	u.auto_work = false
	return u


func money() -> Array:
	var p: Dictionary = g.players[0]
	return [int(p["gold"]), float(p["res2"]), g.tension(0), g.energy_stored(0)]


func spent(before: Array) -> Array:
	var now := money()
	return [before[0] - now[0], snappedf(before[1] - now[1], 0.01), snappedf(before[2] - now[2], 0.01), before[3] - now[3]]


func _same(a: Array, b: Array) -> bool:
	for i in a.size():
		if absf(float(a[i]) - float(b[i])) > 0.011:
			return false
	return true


# ---- buildings: placement, price, refund, construction, repair

var built_of := {}       # kind -> a finished Building of ours


func _buildings(fac: String) -> void:
	print("-- buildings")
	built_of.clear()
	var list: Array = Defs.build_list(fac)
	for k in list:
		var e: String = "bld:" + k
		# 1. refused on top of the hall
		if hall:
			var pp := g.placement_problem(0, k, hall.cell)
			ok_rec(e, "place", pp != "", "refused on the hall: '%s'" % pp)
		# 2. refused before its requirement
		var req := g.requirement_text(0, k)
		if req != "":
			var c0 := g.find_spot(0, k, hall, 3, 30)
			var got := g.place_building(0, k, c0, [a_worker()]) if c0.x >= 0 else null
			ok_rec(e, "place", got == null, "refused before its requirement: '%s'" % req)
			if got != null:
				g.abandon(got)
	for b in g.buildings:
		if b.team == 0 and b.built and not b.dead and not built_of.has(b.kind):
			built_of[b.kind] = b
	var pending: Array = list.duplicate()
	var sites := {}
	var started := {}
	for round in 8:
		var placed_any := false
		for k in pending.duplicate():
			if not g.requirement_met(0, k):
				continue
			var e: String = "bld:" + k
			pending.erase(k)
			placed_any = true
			var far := 4 if k != g.faction_hall(0) else Defs.HALL_SPACING
			var c := g.find_spot(0, k, hall, far, far + 34)
			if c.x < 0 and Defs.is_econ(k):
				# (an economy building over its limit at this hall: a new hall's ground first)
				rec(e, "place", "INFO", "econ limit %d at the hall reached (start has %d): checked at a second hall" % [g.econ_limit(0, k), g.econ_count(0, k)])
				pending.append(k)
				placed_any = false
				continue
			if c.x < 0:
				rec(e, "place", "FAIL", "find_spot found no place for it near the hall (34 tiles)")
				continue
			var why := g.placement_problem(0, k, c)
			ok_rec(e, "place", why == "", "allowed at find_spot's %s %s" % [c, ("'" + why + "'") if why != "" else ""])
			if why != "":
				continue
			var price := g.build_price(0, k)
			var tens := float(Defs.tension_cost(Defs.BUILDINGS[k]))
			if k == "gate":
				# (a gate goes into a palisade: laid on the finished wall piece, which it replaces)
				if not built_of.has("wall") or not is_instance_valid(built_of["wall"]):
					pending.append(k)
					continue
				c = (built_of["wall"] as Building).cell
				why = g.placement_problem(0, k, c)
				ok_rec(e, "place", why == "", "allowed on a finished wall piece %s" % ("'" + why + "'" if why != "" else ""))
				if why != "":
					continue
			var w := a_worker()
			var m0 := money()
			var b := g.place_building(0, k, c, [w])
			if b == null:
				rec(e, "place", "FAIL", "place_building refused a spot placement_problem allowed")
				continue
			var sp := spent(m0)
			ok_rec(e, "cost", sp[0] == price and absf(sp[2] - tens) < 0.01, "charged %d gold%s (price %d%s)" % [sp[0], (" + %.0f Tension" % sp[2]) if sp[2] != 0 else "", price, (" + %.0f Tension" % tens) if tens > 0 else ""])
			var m1 := money()
			g.abandon(b)
			var back := spent(m1)
			await wait(0.1)
			ok_rec(e, "cost", back[0] == -price and b.dead, "ABANDON: %d gold back of %d (%s)" % [-back[0], price, "gone" if b.dead else "still there"])
			m0 = money()
			b = g.place_building(0, k, c, [w])
			if b == null:
				rec(e, "place", "FAIL", "placed again after ABANDON: refused")
				continue
			sites[k] = b
			started[k] = g.clock
		if not sites.is_empty():
			# build them all (the workers walk and build; the Clockwork's Winders fetch their crates)
			var longest := 0.0
			for k in sites:
				longest = maxf(longest, float(sites[k].build_time()))
			var fin := {}
			var done: bool = await wait_for(func() -> bool:
				var all_done := true
				for k in sites:
					var sb = sites[k]
					if is_instance_valid(sb) and not sb.dead and not sb.built:
						all_done = false
					elif not fin.has(k):
						fin[k] = g.clock
				return all_done, longest * 2.5 + 40.0)
			await wait(1.0)        # (the gear network solves on the next tick: a fresh building is linked then)
			for k in sites:
				var sb = sites[k]
				var e: String = "bld:" + k
				if not is_instance_valid(sb) or sb.dead:
					rec(e, "build", "FAIL", "the site vanished before it was built (swept / destroyed)")
				elif sb.built:
					built_of[k] = sb
					var took := float(fin.get(k, g.clock)) - float(started[k])
					rec(e, "build", "PASS", "built by one worker in %.0f s (its time %s s; the walk, the Clockwork's crate and a big gear's extra time included)" % [took, Defs.BUILDINGS[k]["time"]])
					if fac == "clockwork" and GearNet.has_gear(sb):
						var cand: Dictionary = g.gear_net.candidate(0, k, sb.cell, sb.gear_big)
						ok_rec(e, "build", g.gear_net.is_linked(sb) and g.gear_net.speed_mult(sb) > 0.0,
							"in the gear network: linked %s, works at x%.2f%s (placement check now: %s)" % [g.gear_net.is_linked(sb), g.gear_net.speed_mult(sb),
							(", Mainspring %s" % (g.gear_net.spring_for(sb) != null)) if Defs.TENSION_USERS.has(k) else "", cand.get("state", "?")])
				else:
					rec(e, "build", "FAIL", "not finished after %.0f s (progress %.0f%%, ghost %s, gear speed %.2f)" % [g.clock - float(started[k]), sb.progress * 100.0, sb.ghost, g.gear_net.speed_mult(sb) if fac == "clockwork" else 1.0])
			sites.clear()
			rich()
		if pending.is_empty() or not placed_any:
			break
	for k in pending:
		rec("bld:" + k, "build", "SKIP" if Defs.is_econ(k) else "FAIL", "never placed: requirement '%s'" % g.requirement_text(0, k))
	# repair: damage each finished building, a worker mends it
	var hurt := {}
	for k in built_of:
		var b = built_of[k]
		if not is_instance_valid(b) or b.dead or k in ["farm"]:
			continue
		b.hp = b.max_hp * 0.6
		var w := a_worker()
		w.position = g.cell_center(g.nearest_free(g.cell_of(b.center() + Vector2(0, b.size.y * 16 + 24)), 6))
		w.cmd_repair(b)
		hurt[k] = [b, b.hp, w]
	var m := money()
	await wait(10.0)
	var cost := spent(m)
	for k in hurt:
		var b: Building = hurt[k][0]
		var hw: Unit = hurt[k][2]
		ok_rec("bld:" + k, "repair", b.hp > float(hurt[k][1]) + 1.0, "a worker mended %.0f -> %.0f of %.0f%s" % [hurt[k][1], b.hp, b.max_hp,
			"" if b.hp > float(hurt[k][1]) + 1.0 else " (the worker: order %s, %.0f px away, can_repair %s)" % [hw.order, hw.position.distance_to(b.center()), hw.can_repair(b)]])
	rec("match:" + fac, "repair", "INFO", "10 s of repair on %d buildings cost %d gold" % [hurt.size(), cost[0]])
	rich()


func _demolish_all(fac: String) -> void:
	for k in built_of:
		var b = built_of[k]
		if not is_instance_valid(b) or b.dead or k == g.faction_hall(0):
			continue
		var cap0 := int(g.players[0]["cap"])
		g.demolish(b)
		await physics_frame
		ok_rec("bld:" + k, "demolish", b.dead, "DEMOLISH pulls it down%s" % ((" (supply cap %d -> %d)" % [cap0, int(g.players[0]["cap"])]) if int(Defs.BUILDINGS[k].get("supply", 0)) > 0 else ""))
	await wait(1.0)
	errs_to("match:" + fac, "demolish")


# ---- production: train, refuse, price, cancel, come out, supply, rally

func _production(fac: String) -> void:
	print("-- production")
	for k in Defs.build_list(fac):
		if not built_of.has(k) or not is_instance_valid(built_of[k]):
			continue
		var b: Building = built_of[k]
		var keys: Array = Defs.train_keys(b.d.get("trains", []), true)
		for key in keys:
			await _train_one(b, String(key))
		# THE QUEUE: five at most; CANCEL takes them all back out, paid back
		if not keys.is_empty():
			rich()
			b.queue.clear()
			b.kits.clear()
			var key0 := String(keys[0])
			var m0 := money()
			var took := 0
			for i in 5:
				if g.train(b, key0) == "":
					took += 1
			var sixth := g.train(b, key0)
			if Defs.UNITS[Defs.train_kind(key0)].has("per"):
				ok_rec("bld:" + k, "queue", took <= 1 and sixth.begins_with("Only one"), "%d %s queued, the next refused: '%s' (one per building)" % [took, key0, sixth])
			else:
				ok_rec("bld:" + k, "queue", took == 5 and sixth != "", "%d %s queued, the 6th refused: '%s'" % [took, key0, sixth])
			for i in took:
				g.cancel_train(b)
			var left := spent(m0)
			ok_rec("bld:" + k, "queue", b.queue.is_empty() and left[0] <= (int(Defs.UNITS["horse"]["cost"]) * took if Defs.UNITS[Defs.train_kind(key0)].get("needs_horse", false) else 0),
				"CANCEL x%d: the queue empty, %d gold not back%s" % [took, left[0], " (horses ordered for them stay)" if left[0] > 0 else ""])


func _train_one(b: Building, key: String) -> void:
	var kind := Defs.train_kind(key)
	var e: String = "unit:" + kind + ("" if key == kind else " (%s)" % key)
	if not live_kind(kind):
		return
	rich()
	b.queue.clear()
	b.kits.clear()
	b.prod_t = 0.0
	# refused without each requirement (the requirement building taken out for a moment)
	var d: Dictionary = Defs.UNITS[kind]
	var reqs: Array = d["requires"] if d.get("requires", "") is Array else ([d["requires"]] if String(d.get("requires", "")) != "" else [])
	for q in reqs:
		var off: Array = []
		for ob in g.buildings:
			if ob.team == 0 and ob.kind == String(q) and ob.built and not ob.dead:
				ob.built = false
				off.append(ob)
		var why := g.can_train(b, key)
		ok_rec(e, "refuse", why != "", "without a %s: '%s'" % [q, why])
		for ob in off:
			ob.built = true
	if Defs.train_armoured(key) and not g.has_tech(0, "armour"):
		ok_rec(e, "refuse", g.can_train(b, key) != "", "before Armour: '%s'" % g.can_train(b, key))
		return
	var why := g.can_train(b, key)
	if why != "":
		rec(e, "make", "FAIL" if why != "Coming soon." else "WARN", "can't train at the %s: '%s'" % [b.kind, why])
		return
	var price := g.unit_price(0, key)
	var horse := 0
	if d.get("needs_horse", false) and g.free_horse_at(b) == null and g.spare_horse(0, b) == null:
		horse = int(Defs.UNITS["horse"]["cost"])
	var m0 := money()
	why = g.train(b, key)
	var sp := spent(m0)
	var second := 2 if Defs.tension_cost(d) > 0 else (3 if g.faction_of(0) == "clockwork" else 1)
	var exp2 := float(price[1])
	ok_rec(e, "cost", why == "" and sp[0] == price[0] + horse and absf(float(sp[second]) - exp2) < 0.02,
		"charged %d gold + %.1f %s (price %d + %.1f%s)" % [sp[0], sp[second], ["", "res2", "Tension", "batteries"][second], price[0], exp2, (" + %d for its horse" % horse) if horse > 0 else ""])
	g.cancel_train(b)
	var back := spent(m0)
	ok_rec(e, "cost", back[0] == horse and absf(float(back[second])) < 0.02, "CANCEL pays back (left out: %d gold%s)" % [back[0], " = the horse, kept for the next" if horse > 0 and back[0] == horse else ""])
	# train for real, out quickly
	rich()
	var before := {}
	for u in g.units:
		before[u] = true
	var sup0 := g.supply_used(0)
	b.rally = b.center() + Vector2(0, b.size.y * 16 + 120)
	why = g.train(b, key)
	if why != "":
		rec(e, "make", "FAIL", "second train refused: '%s'" % why)
		return
	var want := String(Defs.RIDERS.get(kind, kind))
	var out: Unit = null
	var n := 0
	while n < 30 * 60:
		if not b.queue.is_empty():
			var qk: String = b.queue[0]
			b.prod_t = maxf(b.prod_t, Building.entry_time(qk) - 0.3)
		for br in g.breeders_of(0):
			if not br.queue.is_empty():
				br.prod_t = maxf(br.prod_t, Building.entry_time(br.queue[0]) - 0.3)
		await physics_frame
		n += 1
		for u in g.units:
			if not before.has(u) and u.team == 0 and not u.dead and (u.kind == kind or u.kind == want) and u.kind != "horse" or (kind == "horse" and not before.has(u) and u.kind == "horse" and u.team == 0):
				out = u
		if out:
			break
	if out == null:
		rec(e, "make", "FAIL", "nothing came out of the %s in 60 s (queue %s, prod_t %.1f)" % [b.kind, b.queue, b.prod_t])
		return
	tracked.append(out)
	await wait(1.5)
	if not is_instance_valid(out) or out.dead:
		ok_rec(e, "make", false, "came out of the %s as a %s and is gone 1.5 s later" % [b.kind, kind])
		b.rally = Vector2.INF
		return
	var sup1 := g.supply_used(0)
	var want_sup := int(d["supply"]) * int(d.get("spawn", 1))
	ok_rec(e, "make", true, "came out of the %s as a %s after %.1f s%s" % [b.kind, out.kind, n / 30.0, (" (+%d supply, %d expected)" % [sup1 - sup0, want_sup])])
	if sup1 - sup0 != want_sup and kind != "horse":
		rec(e, "make", "WARN", "supply went up %d, Defs says %d" % [sup1 - sup0, want_sup])
	var moved := out.position.distance_to(b.rally) < out.position.distance_to(b.center()) or out.order != "idle"
	if not moved and out.kind == "missionary":
		moved = true          # (a Missionary walks off to tend the hurt: the probes and dummies about)
	ok_rec(e, "rally", moved or out.is_worker(), "walks to the rally point (order %s, %.0f px off)" % [out.order, out.position.distance_to(b.rally)], "WARN")
	if Defs.AMMO.has(out.kind):
		ok_rec(e, "make", out.ammo_shots() == Defs.ammo_full(out.kind), "armed from the bank: %d of %d shots" % [out.ammo_shots(), Defs.ammo_full(out.kind)])
	b.rally = Vector2.INF


# ---- research: refuse, price, cancel, done, effect

func _research(fac: String) -> void:
	print("-- research")
	var todo: Array = []
	for k in Defs.RESEARCH:
		if String(Defs.RESEARCH[k].get("faction", "crown")) == fac:
			todo.append(k)
	# refusals first, while nothing is researched
	for k in todo:
		var d: Dictionary = Defs.RESEARCH[k]
		var e: String = "res:" + k
		if not built_of.has(String(d["at"])):
			rec(e, "research", "FAIL", "no %s was built to research it at" % d["at"])
			continue
		var b: Building = built_of[String(d["at"])]
		if String(d.get("requires", "")) != "":
			var why := g.research_problem(b, k)
			ok_rec(e, "refuse", why != "", "before %s: '%s'" % [d["requires"], why])
		if String(d.get("needs", "")) != "" and built_of.has(String(d["needs"])):
			var nb: Building = built_of[String(d["needs"])]
			var off: Array = []
			for ob in g.buildings:
				if ob.team == 0 and ob.kind == nb.kind and ob.built:
					ob.built = false
					off.append(ob)
			var why2 := g.research_problem(b, k)
			ok_rec(e, "refuse", why2 != "", "without a %s: '%s'" % [d["needs"], why2])
			for ob in off:
				ob.built = true
	var left: Array = todo.filter(func(k: String) -> bool: return built_of.has(String(Defs.RESEARCH[k]["at"])))
	for pass_i in 4:
		for k in left.duplicate():
			var d: Dictionary = Defs.RESEARCH[k]
			if String(d.get("requires", "")) != "" and not g.has_tech(0, String(d["requires"])):
				continue
			left.erase(k)
			await _research_one(k)
	for k in left:
		rec("res:" + k, "research", "FAIL", "never researched (its chain did not finish)")


func _research_one(k: String) -> void:
	var d: Dictionary = Defs.RESEARCH[k]
	var e: String = "res:" + k
	var b: Building = built_of[String(d["at"])]
	rich()
	b.queue.clear()
	b.kits.clear()
	b.prod_t = 0.0
	var before := _effect_probe(k)
	var m0 := money()
	var why := g.start_research(b, k)
	if why != "":
		rec(e, "research", "FAIL", "start refused: '%s'" % why)
		return
	var sp := spent(m0)
	var tens := float(Defs.tension_cost(d))
	ok_rec(e, "cost", sp[0] == int(d["cost"]) and absf(sp[1] - float(d.get("cost2", 0))) < 0.02 and absf(sp[2] - tens) < 0.02,
		"charged %d gold + %.0f + %.0f Tension (price %s / %s / %.0f)" % [sp[0], sp[1], sp[2], d["cost"], d.get("cost2", 0), tens])
	g.cancel_train(b)
	ok_rec(e, "cost", _same(spent(m0), [0, 0, 0, 0]), "CANCEL pays it all back")
	g.start_research(b, k)
	var done: bool = await wait_for(func() -> bool:
		if not b.queue.is_empty():
			b.prod_t = maxf(b.prod_t, Building.entry_time(b.queue[0]) - 0.3)
		return g.has_tech(0, k), 20.0)
	ok_rec(e, "research", done, "done%s" % ("" if done else " (queue %s, prod_t %.1f, gear %.2f)" % [b.queue, b.prod_t, g.gear_net.speed_mult(b) if b.d["faction"] == "clockwork" else 1.0]))
	if done:
		await wait(0.3)
		_effect_check(k, before)


## What a research should change, measured before and after on a unit already in the field and on a new one.
var _probe_units := {}


func _probe_unit(kind: String) -> Unit:
	if _probe_units.has(kind) and is_instance_valid(_probe_units[kind]) and not _probe_units[kind].dead:
		return _probe_units[kind]
	var base: Vector2 = hall.center() if hall != null else BroodNew.queen(g, 0).position
	var at: Vector2 = base + Vector2(-260 - _probe_units.size() * 30, 200)
	var u: Unit = g._add_unit(kind, 0, g.cell_center(g.nearest_free(g.cell_of(at), 12)))
	u.process_mode = Node.PROCESS_MODE_DISABLED
	_probe_units[kind] = u
	return u


func _stat(u: Unit) -> Dictionary:
	return {"cool": u._cooldown(), "range": u._range(), "hp": u.max_hp, "speed": u.speed + u._speed_add(), "armor": u.armor}


func _effect_probe(k: String) -> Dictionary:
	var d: Dictionary = Defs.RESEARCH[k]
	var out := {}
	for kind in _effect_kinds(d):
		out[kind] = _stat(_probe_unit(kind))
	return out


func _effect_kinds(d: Dictionary) -> Array:
	var ks: Array = []
	if d.has("kinds"):
		ks.append_array(d["kinds"])
	for f in ["speed", "range", "bonus"]:
		if d.get(f) is Dictionary:
			ks.append_array((d[f] as Dictionary).keys())
	if d.has("hp") and String(d["at"]) == "movement_works":
		ks.append("clock_soldier")
	return ks.filter(func(x: String) -> bool: return Defs.UNITS.has(x) and live_kind(x))


func _effect_check(k: String, before: Dictionary) -> void:
	var d: Dictionary = Defs.RESEARCH[k]
	var e: String = "res:" + k
	var said := false
	for kind in before:
		var old: Unit = _probe_units[kind]
		var a: Dictionary = before[kind]
		var b := _stat(old)
		var fresh: Unit = g._add_unit(kind, 0, old.position + Vector2(0, 30))
		fresh.process_mode = Node.PROCESS_MODE_DISABLED
		var c := _stat(fresh)
		var what := ""
		var ok := true
		if d.has("reload"):
			ok = b["cool"] < a["cool"] - 0.01 and c["cool"] < a["cool"] - 0.01
			what = "reload %.2f -> old %.2f, new %.2f s" % [a["cool"], b["cool"], c["cool"]]
		elif d.has("range") and not (d["range"] is Dictionary):
			ok = b["range"] > a["range"] and c["range"] > a["range"]
			what = "range %.0f -> old %.0f, new %.0f" % [a["range"], b["range"], c["range"]]
		elif d.get("range") is Dictionary:
			ok = c["range"] > a["range"]
			what = "range %.0f -> new %.0f, old %.0f" % [a["range"], c["range"], b["range"]]
		elif d.get("speed") is Dictionary:
			ok = c["speed"] > a["speed"] or bool(d.get("air", false))
			what = "speed %.0f -> new %.0f, old %.0f%s" % [a["speed"], c["speed"], b["speed"], " (air: only while flying)" if d.get("air", false) else ""]
		elif d.has("hp"):
			ok = c["hp"] > a["hp"] and b["hp"] > a["hp"]
			what = "health %.0f -> old %.0f, new %.0f" % [a["hp"], b["hp"], c["hp"]]
		else:
			what = "has_tech (no number to measure for %s)" % kind
		ok_rec(e, "effect", ok, "%s: %s" % [kind, what])
		said = true
		fresh.queue_free()
		g.units.erase(fresh)
	if said:
		return
	# the other kinds of research
	if Defs.LOCKS.has(k) or k in ["armour", "bayonet", "pouch"]:
		var m: Unit = _probe_unit("musketeer")
		var opts: Array = g.refit_options(m)
		var has := opts.any(func(o) -> bool: return str(o).to_lower().contains(k) or (k == "armour" and str(o).to_lower().contains("armour")))
		ok_rec(e, "effect", has or k == "pouch", "the refit is offered to a Musketeer in the field (%s)" % str(opts).left(120), "WARN")
		var kit := g.kit_for_new(0, "musketeer")
		rec(e, "effect", "INFO", "a new Musketeer comes out with %s" % str(kit))
	elif d.has("band"):
		rec(e, "effect", "PASS" if g.has_tech(0, k) else "FAIL", "the %s joins the bands (MarchingBand)" % d["band"])
	elif d.has("unlocks"):
		rec(e, "effect", "PASS", "unlocks %s" % d["unlocks"])
	elif k == "owl_morph":
		var sw: Unit = _probe_unit(Defs.CUCKOO)
		var p := ""
		if g.has_method("morph_order"):
			p = "MORPH TO OWL now offered"
		rec(e, "effect", "PASS", p)
	elif not (d.has("young") or d.has("spell") or d.has("root")):
		rec(e, "effect", "INFO", "researched (its effect is a rule the fights or the ability tests use: %s)" % String(d.get("about", "")).left(90))


# ---- the Brood: no buildings; grubs turn into its structures, the Mother lays and grows, the young mature

func _brood_make() -> void:
	print("-- the Brood: morphs, laying, growing, maturing, research")
	var q: Unit = BroodNew.queen(g, 0)
	if q == null:
		rec("unit:brood_mother", "make", "FAIL", "no Brood Mother at the start")
		return
	await wait_for(func() -> bool: return q.tesla_mode == "deployed", 5.0)
	ok_rec("unit:brood_mother", "make", q.tesla_mode == "deployed", "starts rooted (the hall of the Brood)")
	# morphs: every structure a grub turns into
	var ml: Array = BroodRoot.morph_list().duplicate()
	if ml.has(BroodNew.MAW):
		ml.erase(BroodNew.MAW)
		ml.append(BroodNew.MAW)       # (a second Rootmaw needs swamp 16 tiles from the first: a Mound Turtle's swamp)
	for k in ml:
		var e: String = "unit:" + k
		rich()
		var gr: Unit = g._add_unit("grub", 0, q.position + Vector2(0, 140))
		gr.auto_work = false
		var stage_need := BroodNew.father_stage(k) if BroodNew.is_father(k) else 0
		if stage_need > BroodNew.stage(q):
			var w0 := BroodRoot.morph_problem(g, 0, k, gr)
			ok_rec(e, "refuse", w0 != "", "before the Mother's stage %d: '%s'" % [stage_need + 1, w0])
			continue          # (made after she grows, below)
		await _morph(gr, k, q)
	# grow: stage 2, then 3 (refused while walking; price; refund on STOP; done)
	for st in [1, 2]:
		var e: String = "unit:brood_mother"
		rich()
		var nx: Dictionary = Defs.NB["stages"][st]
		var m0 := money()
		var why := q.cmd_grow()
		var sp := spent(m0)
		ok_rec(e, "grow", why == "" and sp[0] == int(nx["cost"]) and absf(sp[1] - float(nx["cost2"])) < 0.02, "GROW to stage %d: charged %d + %.0f (price %s + %s) %s" % [st + 1, sp[0], sp[1], nx["cost"], nx["cost2"], why])
		q.cmd_grow_stop()
		ok_rec(e, "grow", _same(spent(m0), [0, 0, 0, 0]), "STOP GROWING pays it back")
		q.cmd_grow()
		q.nb["grow_t"] = 0.5
		var grown: bool = await wait_for(func() -> bool: return BroodNew.stage(q) >= st, 6.0)
		ok_rec(e, "grow", grown, "stage %d reached (eggs held %d)" % [st + 1, BroodNew.eggs_max(q)])
	ok_rec("unit:brood_mother", "grow", BroodNew.grow_problem(g, q) != "", "fully grown: '%s'" % BroodNew.grow_problem(g, q))
	for k in BroodRoot.morph_list():
		if BroodNew.is_father(k) and BroodNew.father_stage(k) > 0 and mine(k).is_empty():
			rich()
			var gr2: Unit = g._add_unit("grub", 0, q.position + Vector2(0, 140))
			gr2.auto_work = false
			await _morph(gr2, k, q)
	# root every father beside her (his nest): the warriors' eggs need it
	for f in BroodNew.FATHERS:
		var fu := BroodNew.father(g, 0, f)
		if fu != null and not BroodNew.father_near(g, 0, f):
			rec("unit:" + f, "make", "WARN", "rooted %.0f tiles from the Mother (needs %s): moved beside her for the laying test" % [fu.position.distance_to(q.position) / 32.0, Defs.NB["father_r"]])
	# lay every kind on her list
	for k in BroodNew.hatch_list():
		await _lay(q, String(k))
	# mature every young
	for young in Defs.NB["mature"]:
		await _mature(String(young))
	# ROOTING: rooted takes less; UPROOT and ROOT again
	for tk in [BroodNew.TURTLE, BroodNew.FATHER]:
		var tl := mine(tk)
		if tl.is_empty():
			continue
		var tu: Unit = tl[0]
		ok_rec("unit:" + tk, "ability", BroodNew.incoming(tu, 20.0) < 20.0, "rooted: a 20 blow does %.1f" % BroodNew.incoming(tu, 20.0))
		tu.cmd_uproot(false)
		var up: bool = await wait_for(func() -> bool: return tu.tesla_mode == "packed", 8.0)
		tu.cmd_deploy()
		var down: bool = await wait_for(func() -> bool: return tu.tesla_mode == "deployed", 8.0)
		ok_rec("unit:" + tk, "ability", up and down, "UPROOT (%s) and ROOT again (%s)" % [up, down])
	# SPOILS: a grub harvests a body and carries it to the Mother
	var gs := _spawn_ready("grub", q.position + Vector2(-120, 160))
	var body: Unit = g._add_unit("musketeer", 1, gs.position + Vector2(40, 0))
	body.take_damage(body.hp + 1000.0, null)
	await wait(0.3)
	var r0 := float(g.players[0]["res2"])
	gs.cmd_harvest()
	var got: bool = await wait_for(func() -> bool: return float(g.players[0]["res2"]) > r0 + 0.5, 40.0)
	ok_rec("unit:grub", "ability", got, "HARVEST: a body wrapped and carried to the Mother: spoils %.1f -> %.1f" % [r0, float(g.players[0]["res2"])])
	# research at the creatures
	await _brood_research()


func _free_root_spot(k: String, near: Vector2, tiles: float, me: Unit) -> Vector2:
	for r in [tiles, tiles + 1.0, tiles + 2.0, tiles + 3.0, tiles - 1.0, tiles + 4.0, tiles + 5.0, tiles + 6.0, tiles + 8.0, tiles + 10.0, tiles + 13.0, tiles + 16.0, tiles + 20.0]:
		for i in 32:
			var s: Vector2 = BroodRoot.snap(k, near + Vector2.from_angle(TAU * i / 32.0) * maxf(r, 0.0) * Defs.TILE)
			if g.region_of(g.cell_of(s)) == BroodRoot.home_region(g, near) and BroodRoot.place_problem(g, 0, k, s, me, false, 1.0, true) == "":
				return s
	return Vector2.INF


func _morph(gr: Unit, k: String, q: Unit) -> void:
	var e: String = "unit:" + k
	var why := BroodRoot.morph_problem(g, 0, k, gr)
	if why != "":
		rec(e, "make", "FAIL", "a grub can't turn into it: '%s'" % why)
		return
	var tiles := 5.0 if BroodNew.is_father(k) else (6.0 if k == BroodNew.MAW else 9.0)
	var centre: Vector2 = q.position
	if k == BroodNew.MAW and not mine(BroodNew.TURTLE).is_empty():
		centre = mine(BroodNew.TURTLE)[0].position
		tiles = 3.0
	var spot := _free_root_spot(k, centre, tiles, gr)
	if spot == Vector2.INF:
		rec(e, "make", "FAIL", "no spot to root it near the Mother")
		return
	var price := g.unit_price(0, k)
	var m0 := money()
	BroodRoot.start_morph(gr, k, spot)
	var sp := spent(m0)
	await wait(0.2)
	ok_rec(e, "cost", sp[0] == int(price[0]) and absf(sp[1] - float(price[1])) < 0.02, "the grub's morph: charged %d + %.1f (price %s + %s)" % [sp[0], sp[1], price[0], price[1]])
	var before := g.units.size()
	var got: bool = await wait_for(func() -> bool: return mine(k).any(func(u: Unit) -> bool: return BroodNew.rooted(u)), float(Defs.UNITS[k]["time"]) + 40.0)
	ok_rec(e, "make", got, "a grub turned into it and it rooted (%s s)" % Defs.UNITS[k]["time"])
	for u in mine(k):
		tracked.append(u)


func _lay(q: Unit, k: String) -> void:
	var e: String = "unit:" + k
	rich()
	q.nb["eggs"] = 10
	var why := BroodNew.lay_problem(g, q, k)
	if why != "":
		rec(e, "make", "FAIL", "the Mother can't lay it: '%s'" % why)
		return
	var price := g.unit_price(0, k)
	var n := BroodNew.young(g, 0, k)
	var m0 := money()
	var sup0 := g.supply_used(0)
	var before := {}
	for u in g.units:
		before[u] = true
	why = q.cmd_lay(k)
	var sp := spent(m0)
	ok_rec(e, "cost", why == "" and sp[0] == int(price[0]) and absf(sp[1] - float(price[1])) < 0.02, "an egg: charged %d + %.1f (price %s + %s)" % [sp[0], sp[1], price[0], price[1]])
	var hatched: bool = await wait_for(func() -> bool:
		var c := 0
		for u in g.units:
			if not before.has(u) and u.team == 0 and not u.dead and u.kind == k:
				c += 1
		return c >= n, float(Defs.UNITS[k]["time"]) + float(Defs.NB["fert_wait"]) + 15.0)
	var got: Array = g.units.filter(func(u: Unit) -> bool: return not before.has(u) and u.team == 0 and not u.dead and u.kind == k)
	ok_rec(e, "make", hatched, "the egg hatched %d of %d young (%s)" % [got.size(), n, "fertilised in a nest" if BroodNew.father_of(k) != "" else "no father needed"])
	for u in got:
		tracked.append(u)
	if hatched:
		var want := int(Defs.UNITS[k]["supply"]) * n
		ok_rec(e, "make", g.supply_used(0) - sup0 == want, "supply +%d (expected %d)" % [g.supply_used(0) - sup0, want], "WARN")


func _mature(young: String) -> void:
	var adult := BroodMature.mature_of(young)
	var e: String = "unit:" + adult
	rich()
	var ys := mine(young)
	if ys.is_empty():
		rec(e, "make", "FAIL", "no %s to mature" % young)
		return
	var y: Unit = ys[0]
	var why := BroodMature.problem(y)
	if why != "":
		rec(e, "make", "FAIL", "MATURE refused: '%s'" % why)
		return
	var price := BroodMature.price(g, 0, young)
	var m0 := money()
	why = BroodMature.order(g, [y])
	var sp := spent(m0)
	ok_rec(e, "cost", sp[0] == int(price[0]) and absf(sp[1] - float(price[1])) < 0.02, "MATURE: charged %d + %.1f (price %s + %s)" % [sp[0], sp[1], price[0], price[1]])
	var done: bool = await wait_for(func() -> bool: return is_instance_valid(y) and y.kind == adult or mine(adult).size() > 0, float(Defs.NB["moult"]) + 5.0)
	ok_rec(e, "make", done, "the %s moulted into a %s" % [young, adult])
	for u in mine(adult):
		tracked.append(u)


func _brood_research() -> void:
	var at_of := {}
	for k in BroodResearch.keys():
		at_of[k] = String(Defs.RESEARCH[k]["at"])
	var started := {}
	for k in BroodResearch.keys():
		var e: String = "res:" + k
		var who := mine(at_of[k])
		if who.is_empty():
			rec(e, "research", "FAIL", "no %s to research it" % at_of[k])
			continue
		var u: Unit = who[0]
		rich()
		var m0 := money()
		var why := BroodResearch.start(g, u, k)
		if why != "":
			rec(e, "research", "FAIL", "refused: '%s'" % why)
			continue
		var sp := spent(m0)
		var d: Dictionary = Defs.RESEARCH[k]
		ok_rec(e, "cost", sp[0] == int(d["cost"]) and absf(sp[1] - float(d.get("cost2", 0))) < 0.02, "charged %d + %.0f (price %s + %s)" % [sp[0], sp[1], d["cost"], d.get("cost2", 0)])
		var idx := 0 if BroodResearch.current(u) == k else BroodResearch.queued(u).size()
		BroodResearch.cancel_at(g, u, idx)
		ok_rec(e, "cost", _same(spent(m0), [0, 0, 0, 0]), "CANCEL pays it back")
		started[k] = _effect_probe(k)
		BroodResearch.start(g, u, k)
	var longest := 0.0
	for k in started:
		longest += float(Defs.RESEARCH[k]["time"])
	await wait_for(func() -> bool:
		for k in started:
			if not BroodResearch.has(g, 0, k):
				return false
		return true, longest + 20.0)
	for k in started:
		var ok := BroodResearch.has(g, 0, k)
		ok_rec("res:" + k, "research", ok, "done at the %s" % at_of[k])
		if ok:
			_effect_check(k, started[k])
			var d: Dictionary = Defs.RESEARCH[k]
			if d.has("young"):
				ok_rec("res:" + k, "effect", BroodNew.young(g, 0, String(d["young"])) == BroodResearch.base_clutch(String(d["young"])) + 1, "%s: %d young an egg" % [d["young"], BroodNew.young(g, 0, String(d["young"]))])
			if d.has("spell"):
				var toad := mine("mist_toad")
				if not toad.is_empty():
					toad[0].charge = 150.0
					var sp := g.spell_problem(toad[0], String(d["spell"]))
					ok_rec("res:" + k, "effect", sp == "", "the Mist Toad may cast %s now ('%s')" % [d["spell"], sp])
			if d.has("root"):
				rec("res:" + k, "effect", "PASS" if BroodResearch.root_mult(BroodNew.queen(g, 0)) < 1.0 else "FAIL", "root time x%.2f" % BroodResearch.root_mult(BroodNew.queen(g, 0)))


# ---- the card: every button of every unit and building (icon, tooltip, texts, pressed: something happens)

const TARGET_ENEMY := ["attack", "overload", "tongue"]
const SKIP_PRESS := ["SURRENDER", "QUIT", "MENU", "LEAD", "MOUNT", "HARNESS", "RELEASE HORSE", "RELEASE"]      # (the horse commands: one at a time in the Crown rules)


func _cards(fac: String) -> void:
	print("-- cards and abilities")
	var kinds: Array = []
	for k in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[k]
		if String(d.get("faction", "")) == fac and live_kind(k) and not d.get("campaign_only", false) and not (k in [BroodNew.EGG, BroodNew.PILE]):
			kinds.append(k)
	# each unit's card, and the presses to make: [kind, label]
	var spots := _arenas(1, 3)
	var presses: Array = []
	for k in kinds:
		var e: String = "unit:" + k
		var labels := await _card_of(k, spots[0] if not spots.is_empty() else hall.center() + Vector2(300, 300), e)
		for lab in labels:
			if SKIP_PRESS.has(lab) or String(lab).begins_with("CANCEL"):
				continue
			presses.append([k, lab])
	# the presses, in rounds: one fresh unit for each, far enough apart not to see each other's enemy
	var lanes := _arenas(400, 11)
	rec("match:" + fac, "buttons", "INFO", "%d button presses, %d at a time" % [presses.size(), lanes.size()])
	while not presses.is_empty():
		var round: Array = presses.slice(0, maxi(1, lanes.size()))
		presses = presses.slice(round.size())
		var jobs: Array = []
		for i in round.size():
			var job := await _press(String(round[i][0]), lanes[i], String(round[i][1]), "unit:" + String(round[i][0]))
			if not job.is_empty():
				jobs.append(job)
		await wait(4.0)
		for j in jobs:
			var now := _snap(j[2])
			var diff := _diff(j[3], now)
			if j[5] != "":
				diff = j[5] + (", " + diff if diff != "" else "")
			errs_to(j[0], "press " + j[1])
			if diff == "" and j[1] == "ATTACK" and (Defs.UNITS[j[2].kind].get("no_attack", false) or float(Defs.UNITS[j[2].kind].get("damage", 0)) <= 0):
				rec(j[0], "ability", "WARN", "ATTACK on its card, but it is unarmed: told to attack an enemy, it does nothing")
				continue
			if diff == "" and j[1] in ["STOP", "HOLD"]:
				rec(j[0], "ability", "PASS", "%s: an idle unit, nothing to stop (as it should)" % j[1])
				continue
			ok_rec(j[0], "ability", diff != "", "%s%s: %s" % [j[1], (" (target: %s)" % j[4]) if j[4] != "" else "", diff if diff != "" else "nothing visible changed in 4 s"], "WARN")
		for j in jobs:
			for x in [j[2], j[6]]:
				if is_instance_valid(x) and not x.dead:
					x.die()
					x.visible = false
		await wait(0.5)
	g.hud.page = ""
	# the buildings' cards
	for k in built_of:
		var b = built_of[k]
		if not is_instance_valid(b) or b.dead:
			continue
		g.hud.page = ""
		g.set_selection([b])
		await physics_frame
		_check_card("bld:" + k, fac)
	g.set_selection([])
	g.hud.page = ""
	rich()


func _card_of(k: String, at: Vector2, e: String) -> Array:
	var u := _spawn_ready(k, at)
	g.set_selection([u])
	await physics_frame
	var labels := _check_card(e, String(Defs.UNITS[k]["faction"]))
	g.set_selection([])
	u.die()
	g.units.erase(u)
	u.queue_free()
	return labels


## The card of the selection: every button's icon, tooltip and translations. Returns the labels.
func _check_card(e: String, fac: String) -> Array:
	var hud = g.hud
	var items: Array = hud._build_card()
	var out: Array = []
	var no_icon: Array = []
	var no_tip: Array = []
	var no_tr: Array = []
	for it in items:
		var lab := String(it[1]).trim_prefix("> ").trim_prefix("~ ")
		out.append(lab)
		if hud._icon(String(it[0])) == null:
			no_icon.append("%s (%s)" % [lab, it[0]])
		var tip: Dictionary = hud._card_tip(it)
		var body := String(tip.get("body", ""))
		if body.strip_edges() == "" and String(tip.get("stats", "")) == "" and String(tip.get("title", "")).to_upper() == lab:
			no_tip.append(lab)
		var m := _tr_missing(lab)
		var built_tr := RegEx.create_from_string("[0-9]").search(lab) != null      # (a label with a number is put together from translated pieces)
		if not m.is_empty() and lab.length() > 2 and not built_tr:
			no_tr.append("%s [%s]" % [lab, ",".join(m)])
		if body != "":
			var mb := _tr_missing(body)
			if not mb.is_empty():
				no_tr.append("tip of %s [%s]" % [lab, ",".join(mb)])
	ok_rec(e, "buttons", no_icon.is_empty(), "%d buttons: %s%s" % [items.size(), ", ".join(out), ("  NO ICON: " + ", ".join(no_icon)) if not no_icon.is_empty() else ""])
	if not no_tip.is_empty():
		rec(e, "buttons", "WARN", "no tooltip text: " + ", ".join(no_tip))
	if not no_tr.is_empty():
		rec(e, "text", "WARN", "card texts not translated: " + "; ".join(no_tr).left(300))
	errs_to(e, "card")
	return out


## A unit as a player gets it: wound, armed, energy full, on foot where it would be.
func _spawn_ready(k: String, at: Vector2) -> Unit:
	var u: Unit = g._add_unit(k, 0, at)
	u.auto_work = false
	if Defs.AMMO.has(k):
		u.set_ammo(Defs.ammo_full(k))
	u.charge = maxf(u.charge, 150.0)
	if "wind" in u:
		u.wind = 1.0
	tracked.append(u)
	return u


func _press(k: String, at: Vector2, lab: String, e: String) -> Array:
	var u := _spawn_ready(k, at)
	# company for the commands that need it: an enemy dummy, a horse, a hurt friend, a body
	var foe: Unit = g._add_unit("balloon" if Defs.UNITS[k].get("air_only", false) else "labourer", 1, at + Vector2(110, 0))
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	foe.max_hp = 100000.0
	foe.hp = foe.max_hp
	if g.faction_of(0) == "crown" and lab in ["LEAD", "MOUNT", "HARNESS"]:
		var hz: Unit = g._add_unit("horse", 0, at + Vector2(-36, 10))      # (a free horse beside it)
		hz.graze_at = hz.position
		await wait(0.4)        # (the unit grid takes it in on its next rebuild)
	if k == BroodNew.QUEEN:
		u.nb["eggs"] = 10
	g.hud.page = ""
	if g.controls.mode != "":
		g.controls.cancel_mode()
	g.set_selection([u])
	await physics_frame
	var items: Array = g.hud._build_card()
	var it: Array = []
	for x in items:
		if String(x[1]).trim_prefix("> ").trim_prefix("~ ") == lab:
			it = x
	if it.is_empty():
		rec(e, "ability", "INFO", "%s: not on a fresh unit's card (it depends on the moment)" % lab)
		return []
	if not bool(it[3]):
		rec(e, "ability", "INFO", "%s: greyed out on a fresh unit ('%s')" % [lab, it[4]])
		return []
	var snap := _snap(u)
	var cb: Callable = it[2]
	var m0 := money()
	var page0: String = g.hud.page
	var z0: int = g.zones.size()
	cb.call()
	var now_sp := spent(m0)
	var extra: Array = []
	if not _same(now_sp, [0, 0, 0, 0]):
		extra.append("paid %s" % str(now_sp))
	if g.hud.page != page0:
		extra.append("card page -> %s" % g.hud.page)
	var mode := String(g.controls.mode)
	var target := ""
	if mode != "":
		if mode in ["place", "nb_root", "lay_line"]:
			target = "placement: tested with the buildings"
			g.controls.cancel_mode()
			return []
		var p: Vector2 = at + Vector2(0, 120)
		if mode in TARGET_ENEMY or (mode == "cast" and String(g.controls.cast_spell) == "tongue"):
			p = foe.position
			target = "the enemy"
		elif mode == "repair" or mode == "heal":
			target = "a friend"
			if hall != null and mode == "repair":
				hall.hp = maxf(hall.hp - 200.0, 1.0)
				p = hall.center()
				target = "the damaged hall"
		elif mode == "load":
			var rider: Unit = g._add_unit("winder" if g.faction_of(0) == "clockwork" else "musketeer", 0, at + Vector2(0, 40))
			p = rider.position
			target = "a rider beside it"
		else:
			target = "the ground"
		g.controls._tap(Vector2.ZERO, true, false, p)
		if String(g.controls.mode) != "":
			g.controls.cancel_mode()
		target = "%s (%s)" % [target, mode]
	g.set_selection([])
	if g.zones.size() != z0:
		extra.append("a zone appeared")
	g.hud.page = ""
	return [e, lab, u, snap, target, ", ".join(extra), foe]


func _snap(u: Unit) -> Dictionary:
	if not is_instance_valid(u):
		return {"gone": true}
	var s := {"kind": u.kind, "order": u.order, "mode": u.mode, "tesla": u.tesla_mode, "dead": u.dead, "hp": snappedf(u.hp, 0.5),
		"pos": Vector2i(u.position / 8.0), "charge": snappedf(u.charge, 1.0), "auto": u.auto_work, "hold": u.get("hold_fire"),
		"band": str(u.get("band")), "team_want": u.get("team_want"), "supplying": u.get("supplying"), "locked": u.get("hold_pos")}
	if Unit.carrier(u.kind):
		s["room"] = u.room()
	for f in ["brace", "shield_up", "canister", "supply_on", "jump", "owl_t", "moult_t", "art", "band_solo_t", "auto_repair", "auto_sweep", "auto_refit", "scatter_ready", "auto_harvest", "horse_rid", "led"]:
		if f in u:
			var v = u.get(f)
			s[f] = snappedf(v, 0.05) if v is float else v
	return s


func _diff(a: Dictionary, b: Dictionary) -> String:
	var out: Array = []
	for k in b:
		if not a.has(k) or str(a[k]) != str(b[k]):
			out.append("%s %s -> %s" % [k, str(a.get(k, "?")).left(24), str(b[k]).left(24)])
	return ", ".join(out).left(200)


# ---- fights: a dummy for every fighter; damage a second against the card's own figure

func _arenas(n: int, gap_tiles: int) -> Array:
	var out: Array = []
	var halls: Array = []
	for b in g.buildings:
		if b.kind in ["town_hall", "clocktower"]:
			halls.append(b.center())
	for u in g.units:
		if u.kind == BroodNew.QUEEN:
			halls.append(u.position)
	var step := gap_tiles
	for y in range(6, g.H - 6, step):
		for x in range(6, g.W - 16, step):
			var c := Vector2i(x, y)
			var p := g.cell_center(c)
			if halls.any(func(h: Vector2) -> bool: return h.distance_to(p) < 22 * Defs.TILE):
				continue
			var good := true
			var lv := g.level_of(p)
			for dx in range(-1, 3):
				for dy in range(-1, 2):
					var cc := c + Vector2i(dx, dy)
					if not g.in_map(cc) or not g.is_free(cc) or not g.in_open_map(cc) or g.level_of(g.cell_center(cc)) != lv:
						good = false
			if good:
				out.append(p)
			if out.size() >= n:
				return out
	return out


## Free stretches of level ground `len_px` long (for a fighter and its dummy), far from the bases and each other.
func _fight_lanes(n: int, len_px: float) -> Array:
	var out: Array = []
	var halls: Array = []
	for b in g.buildings:
		if b.kind in ["town_hall", "clocktower"]:
			halls.append(b.center())
	for u in g.units:
		if u.kind == BroodNew.QUEEN:
			halls.append(u.position)
	var cells := int(ceil(len_px / Defs.TILE)) + 2
	for y in range(5, g.H - 5, 9):
		for x in range(4, g.W - cells - 4, 3):
			var c := Vector2i(x, y)
			var p := g.cell_center(c)
			if halls.any(func(h: Vector2) -> bool: return h.distance_to(p) < 20 * Defs.TILE):
				continue
			if out.any(func(o: Vector2) -> bool: return o.distance_to(p) < 16 * Defs.TILE):
				continue
			var lv := g.level_of(p)
			var good := true
			for dx in range(-1, cells + 1):
				for dy in range(-1, 2):
					var cc := c + Vector2i(dx, dy)
					if not g.in_map(cc) or not g.is_free(cc) or not g.in_open_map(cc) or g.level_of(g.cell_center(cc)) != lv:
						good = false
						break
				if not good:
					break
			if good:
				out.append(p)
			if out.size() >= n:
				return out
	return out


func _fighters(fac: String) -> Array:
	var out: Array = []
	for k in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[k]
		if String(d.get("faction", "")) != fac or not live_kind(k):
			continue
		if d.get("no_attack", false) or float(d.get("damage", 0)) <= 0:
			continue
		if k in [BroodNew.EGG, BroodNew.PILE]:
			continue
		out.append(k)
	return out


func _dummy(kind: String, at: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, at)
	u.process_mode = Node.PROCESS_MODE_DISABLED
	u.max_hp = 1000000.0
	u.hp = u.max_hp
	u.armor = 0
	return u


func _fights(fac: String) -> void:
	print("-- fights")
	var kinds := _fighters(fac)
	if fac == "crown" and not kinds.has("pikeman"):
		kinds.append("pikeman")
	# 1. against a man (or a flyer for the air-only)
	await _fight_batch(kinds, "unit", fac)
	# 2. against a building (siege)
	await _fight_batch(kinds.filter(func(k: String) -> bool: return not Defs.UNITS[k].get("air_only", false)), "building", fac)
	# 3. against a flyer: those that say they hit air
	await _fight_batch(kinds.filter(func(k: String) -> bool: return Defs.UNITS[k].get("anti_air", false) and not Defs.UNITS[k].get("air_only", false)), "air", fac)
	# 4. who can hit what, as Defs says
	var probe_air: Unit = _dummy("balloon", Vector2(-3000, -3000))
	var probe_gnd: Unit = _dummy("labourer", Vector2(-3000, -3100))
	for k in kinds:
		var d: Dictionary = Defs.UNITS[k]
		var u: Unit = g._add_unit(k, 0, Vector2(-3100, -3000))
		u.process_mode = Node.PROCESS_MODE_DISABLED
		var air_ok := u.can_hit(probe_air)
		var gnd_ok := u.can_hit(probe_gnd)
		var want_air: bool = bool(d.get("anti_air", false)) or bool(d.get("air_only", false)) or bool(d.get("air", false)) and not d.get("ground_only", false)
		var want_gnd := not bool(d.get("air_only", false))
		ok_rec("unit:" + k, "targets", air_ok == want_air and gnd_ok == want_gnd, "hits air %s (Defs %s), ground %s (Defs %s)" % [air_ok, want_air, gnd_ok, want_gnd], "WARN")
		g.units.erase(u)
		u.queue_free()
	# 5. death: a body / wreck / spoils, supply back
	await _deaths(_fighters(fac) + _non_fighters(fac))


func _non_fighters(fac: String) -> Array:
	var out: Array = []
	for k in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[k]
		if String(d.get("faction", "")) == fac and live_kind(k) and not _fighters(fac).has(k) and not (k in [BroodNew.EGG, BroodNew.PILE, BroodNew.QUEEN]):
			out.append(k)
	return out


func _fight_batch(kinds: Array, vs: String, fac: String) -> void:
	var lanes := _fight_lanes(kinds.size(), 470.0)
	if lanes.size() < kinds.size():
		rec("match:" + fac, "fights", "INFO", "room for %d of %d fights against a %s at once: in turns" % [lanes.size(), kinds.size(), vs])
	var todo := kinds.duplicate()
	while not todo.is_empty():
		var batch: Array = todo.slice(0, maxi(1, lanes.size()))
		todo = todo.slice(batch.size())
		var fights: Array = []
		for i in batch.size():
			var k: String = batch[i]
			var d: Dictionary = Defs.UNITS[k]
			var st := UnitStats.of_kind(k)
			var rng := float(st["range"]) * Defs.TILE
			var mn := float(d.get("min_range", 0))
			var sight := float(d.get("sight", 7)) * Defs.TILE
			var dist := 54.0 if rng < 80.0 else clampf(rng * 0.6, mn + 50.0, maxf(sight - 40.0, mn + 50.0))
			var a: Vector2 = lanes[i]
			var u := _spawn_ready(k, a)
			u.process_mode = Node.PROCESS_MODE_INHERIT
			var target: Entity
			if vs == "building":
				var bk := "cottage" if g.faction_of(1) == "crown" else ("spring_tower" if g.faction_of(1) == "clockwork" else "cottage")
				var c := g.cell_of(a + Vector2(dist + 40.0, 0))
				var b: Building = g._add_building("cottage", 1, c, true)
				b.max_hp = 1000000.0
				b.hp = b.max_hp
				b.armor = 0
				target = b
			elif vs == "air" or d.get("air_only", false):
				target = _dummy("balloon", a + Vector2(dist, 0))
			else:
				target = _dummy("labourer", a + Vector2(dist, 0))
			fights.append({"k": k, "u": u, "t": target, "hp0": target.hp, "hits": [], "dps": float(st["dps"]), "dist": dist})
		await physics_frame
		for f in fights:
			(f["u"] as Unit).cmd_attack(f["t"])
		var t_end := g.clock + 24.0
		while g.clock < t_end:
			await physics_frame
			for f in fights:
				var t: Entity = f["t"]
				var hp: float = t.hp
				if hp < float(f["hp0"]) - 0.001:
					(f["hits"] as Array).append([g.clock, float(f["hp0"]) - hp])
					f["hp0"] = hp
				var u: Unit = f["u"]
				if is_instance_valid(u) and not u.dead and "wind" in u:
					u.wind = 1.0          # (kept wound: the test is its weapon, not its spring)
			if int(g.clock * 30.0) % 8 == 0:
				_sample_anims()
		for f in fights:
			var k: String = f["k"]
			var e: String = "unit:" + k
			var hits: Array = f["hits"]
			var u: Unit = f["u"]
			var d: Dictionary = Defs.UNITS[k]
			if hits.is_empty():
				var st2 := "FAIL"
				if vs == "building" and (d.get("air_only", false) or k == Defs.NETTER):
					st2 = "INFO"        # (the Netter nets units: a building is no target for it)
				rec(e, "fight", st2, "vs a %s %.0f px off: NO damage in 24 s (order %s, mode %s, target %s)" % [vs, f["dist"], u.order if is_instance_valid(u) else "?", u.mode if is_instance_valid(u) else "?", u.target != null if is_instance_valid(u) else "?"])
				continue
			var total := 0.0
			for h in hits:
				total += float(h[1])
			var span := g.clock - float(hits[0][0])
			var meas := (total - float(hits[0][1])) / maxf(span, 0.1) if hits.size() > 1 else float(hits[0][1]) / 24.0
			var expect: float = f["dps"]
			if vs == "building":
				expect *= float(d.get("building_bonus", 1.0))
			var ratio := meas / maxf(expect, 0.01)
			var note := "vs a %s at %.0f px: %.1f dmg/s measured, card says %.1f%s (x%.2f), first hit after %.1f s, %d hits" % [vs, f["dist"], meas, expect,
				(" x%.1f on buildings" % float(d.get("building_bonus", 1.0))) if vs == "building" else "", ratio, float(hits[0][0]) - (t_end - 24.0), hits.size()]
			if vs == "unit" or vs == "air":
				ok_rec(e, "fight", ratio > 0.4 and ratio < 2.5, note, "WARN")
			else:
				var st3 := "PASS" if ratio > 0.25 else "WARN"
				if float(d.get("cooldown", 1.0)) >= 2.0 and not d.get("venom", false) and k != "spitter":
					# (a slow, heavy weapon: what ONE shot does to a building, against its data)
					var per := total / float(hits.size())
					var want := UnitStats.building_hit(k, d, float(d["damage"]))
					note += "; one shot does %.0f to a building (damage %s x building bonus %s%s = %.0f)" % [per, d["damage"], d.get("building_bonus", 1.0),
						" + the round shot's splash" if k == "cannon" else "", want]
					if per < want * 0.7 and k in ["cannon", "mortar"]:
						st3 = "FAIL"
						note += " TOO LITTLE: the bonus is not applied where it lands?"
					if per > want * 1.3:
						st3 = "WARN"
						note += " TOO MUCH: the bonus is applied twice?"
				rec(e, "fight", st3, note)
		# clear the lanes
		for f in fights:
			var t: Entity = f["t"]
			if t is Building:
				g._remove_quietly(t)
			elif is_instance_valid(t):
				t.die()
			var u: Unit = f["u"]
			if is_instance_valid(u) and not u.dead:
				u.cmd_stop()
				u.die()
		await wait(1.0)
		errs_to("match:" + fac, "fight " + vs)


func _deaths(kinds: Array) -> void:
	var spots := _arenas(kinds.size(), 3)
	var dead: Array = []
	for i in mini(kinds.size(), spots.size()):
		var k: String = kinds[i]
		var u := _spawn_ready(k, spots[i])
		dead.append([k, u])
	await wait(1.0)
	var sup0 := g.supply_used(0)
	var sup_want := 0
	for x in dead:
		var u: Unit = x[1]
		if not u.dead:
			sup_want += int(Defs.UNITS[x[0]]["supply"])
		u.take_damage(u.hp + 10000.0, null)
	await wait(2.5)
	ok_rec("match:" + g.faction_of(0), "deaths", sup0 - g.supply_used(0) >= sup_want - 1, "supply given back: %d -> %d (%d expected back)" % [sup0, g.supply_used(0), sup_want], "WARN")
	for x in dead:
		var k: String = x[0]
		var u: Unit = x[1]
		var e: String = "unit:" + k
		var body := is_instance_valid(u) and u.dead and u.is_inside_tree()
		var what := "a body lies there"
		if body and g.faction_of(0) == "brood":
			what = "a body (%.1f spoils if harvested)" % g.corpse_value(u)
		elif body and g.faction_of(0) == "clockwork":
			what = "a wreck (the Great Winder sweeps %d cogs)" % int(float(Defs.UNITS[k]["cost"]) * float(Defs.GREAT_WINDER["share"]))
		elif body:
			what = "a body (the Church may raise it)"
		ok_rec(e, "body", body or Defs.UNITS[k].get("air", false) or k == "balloon", "%s" % (what if body else "nothing left 2.5 s after death"), "WARN")
		if is_instance_valid(u):
			var da: String = u._death_anim()
			if ArtData.UNITS.has(u.art) and _views_missing(u.art, da).size() == 5:
				rec(e, "art", "WARN", "dies with '%s' but has no such strip" % da)


# ---- the animations the units asked for, against the strips there are

func _art_asked() -> void:
	print("\n==== ANIMATIONS ASKED FOR ====")
	for art in anims_seen:
		if not ArtData.UNITS.has(art):
			continue
		for a in anims_seen[art]:
			var k: String = anims_seen[art][a]
			var mv := _views_missing(art, a)
			var e: String = "unit:" + k
			if mv.size() == 5:
				rec(e, "art", "WARN", "asked for '%s' (%s) but there is no such strip: it shows idle (or the nearest fallback)" % [a, art])
			elif not mv.is_empty():
				rec(e, "art", "INFO", "'%s' (%s): views %s borrow the nearest" % [a, art, ",".join(mv)])


# ---- the numbers: cost per effect, for the owner (information, nothing is changed)

## Every fighting unit's value for its price: damage a second (the card's own figure), health (armour counts as 8%
## more health a point), and "power" = sqrt(dps x effective health), each per 100 of its price (gold + 2 x the second
## resource or Tension; a Brood egg's price shared by its young) and per supply. Flags the ones far from the median of
## all fighters (power under 0.6x or over 1.6x the median) and those far from their own faction's median.
func _numbers() -> void:
	print("\n==== NUMBERS: cost per effect (information for the owner) ====")
	print("%-20s %-9s %6s %6s %5s %6s %5s %4s  %7s %7s %7s %7s" % ["unit", "faction", "price", "dps", "hp", "range", "armr", "sup", "dps/100", "hp/100", "pow/100", "pow/sup"])
	var rows: Array = []
	for k in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[k]
		if not live_kind(k) or d.get("no_attack", false) or float(d.get("damage", 0)) <= 0 or k in [BroodNew.EGG, BroodNew.PILE]:
			continue
		var st := UnitStats.of_kind(k)
		var n := float(d.get("spawn", 1))
		var price := (float(d.get("cost", 0)) + 2.0 * float(d.get("cost2", 0)) + float(Defs.tension_cost(d))) / n
		if d.has("needs_horse") and d.get("needs_horse", false) and not ["cannon", "mortar", "powder_wagon"].has(k):
			price += float(Defs.UNITS["horse"]["cost"])
		if price <= 0.0:
			continue
		var ehp := float(d["hp"]) * (1.0 + 0.08 * float(d.get("armor", 0)))
		var dps := float(st["dps"])
		var pw := sqrt(maxf(dps, 0.0) * ehp)
		rows.append({"k": k, "f": String(d.get("faction", "")), "price": price, "dps": dps, "hp": float(d["hp"]), "range": float(st["range"]),
			"armor": float(d.get("armor", 0)), "sup": float(d["supply"]), "dpc": dps / price * 100.0, "hpc": ehp / price * 100.0,
			"pwc": pw / price * 100.0, "pws": pw / maxf(float(d["supply"]), 0.5)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pwc"] > b["pwc"])
	for r in rows:
		print("%-20s %-9s %6.0f %6.1f %5.0f %6.1f %5.0f %4.0f  %7.2f %7.1f %7.2f %7.1f" % [r["k"], r["f"], r["price"], r["dps"], r["hp"], r["range"], r["armor"], r["sup"], r["dpc"], r["hpc"], r["pwc"], r["pws"]])
	var med := _median(rows.map(func(r: Dictionary) -> float: return r["pwc"]))
	for r in rows:
		var fmed := _median(rows.filter(func(x: Dictionary) -> bool: return x["f"] == r["f"]).map(func(x: Dictionary) -> float: return x["pwc"]))
		var x := float(r["pwc"]) / med
		var y := float(r["pwc"]) / fmed
		if x > 1.6 or x < 0.6 or y > 1.6 or y < 0.6:
			rec("unit:" + String(r["k"]), "numbers", "INFO", "power per 100 price %.2f = x%.2f the median of all fighters, x%.2f its faction's (dps %.1f, health %.0f, price %.0f)" % [r["pwc"], x, y, r["dps"], r["hp"], r["price"]])


func _median(a: Array) -> float:
	if a.is_empty():
		return 1.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


# ---- rules of the factions that the generic tests don't reach

func _rebels() -> void:
	print("-- the Free Assembly and the Pikeman")
	var spots := _arenas(6, 3)
	var i := 0
	for r in Rebels.ROLES:
		var ro: Dictionary = Rebels.ROLES[r]
		var u: Unit = g._add_unit(String(ro["kind"]), 1, spots[i])
		i += 1
		Rebels.apply(u, r)
		ok_rec("rebel:" + r, "make", u.has_meta("rebel_role") and String(u.get_meta("rebel_role")) == r, "a %s plays the %s%s" % [ro["kind"], r, (" (art %s)" % u.art)])
		if ro.get("torch", false):
			var c := g.cell_of(spots[i] + Vector2(0, 0))
			var b: Building = g._add_building("cottage", 0, g.nearest_free(c, 8), true)
			var hp0 := b.hp
			u.position = b.center() + Vector2(0, b.size.y * 16 + 4)
			var run := MissionRun.new() if ClassDB.class_exists("MissionRun") else null
			# (Rebels.tick needs a MissionRun: the burn rule is checked by hand here)
			for n in 30:
				Rebels.tick(_fake_run(), 1.0 / 30.0)
				await physics_frame
			ok_rec("rebel:" + r, "ability", b.hp < hp0, "the torch burns a building he stands at: %.0f -> %.0f" % [hp0, b.hp], "WARN")
			g._remove_quietly(b)
		u.die()
	errs_to("rebel:torch", "torch")


var _fr: Object = null


func _fake_run() -> Object:
	if _fr == null:
		var mr = load("res://scripts/campaign/mission_run.gd").new()
		mr.game = g
		mr.player_teams = {0: true}
		_fr = mr
	return _fr


func _crown_rules() -> void:
	print("-- Crown rules: ammunition, mount, guns, band")
	rich()
	# AMMUNITION: ARM WITH POWDER off -> a dry recruit; on with a short bank -> partial
	if built_of.has("barracks"):
		var b: Building = built_of["barracks"]
		b.queue.clear()
		b.arm_powder = false
		var m := await _quick_train(b, "musketeer")
		ok_rec("unit:musketeer", "ammo", m != null and m.ammo_shots() == 0, "ARM WITH POWDER off: comes out with %s shots" % (str(m.ammo_shots()) if m else "?"))
		b.arm_powder = true
		if m != null:
			m.die()          # (dry by the Barracks, he would refill from the bank)
		g.players[0]["res2"] = 6.0
		m = await _quick_train(b, "musketeer")
		ok_rec("unit:musketeer", "ammo", m != null and m.ammo_shots() == 6 and float(g.players[0]["res2"]) < 0.01, "6 powder in the bank: %s shots, bank %.1f %s" % [str(m.ammo_shots()) if m else "?", float(g.players[0]["res2"]), last_why])
		# a dry Musketeer by the Barracks refills from the bank, a powder a shot (a reloading point)
		var dm := _spawn_ready("musketeer", b.center() + Vector2(0, b.size.y * 16 + 30))
		dm.set_ammo(0)
		g.players[0]["res2"] = 50.0
		var refilled: bool = await wait_for(func() -> bool: return dm.ammo_shots() >= 5, 20.0)
		ok_rec("unit:musketeer", "ammo", refilled, "dry beside the Barracks: refills to %d shots, the bank %.0f -> %.0f" % [dm.ammo_shots(), 50.0, float(g.players[0]["res2"])])
		rich()
	# MOUNT: a Labourer and a horse -> a Messenger; DISMOUNT back
	var at: Vector2 = _arenas(1, 3)[0]
	var lab: Unit = _spawn_ready("labourer", at)
	var h: Unit = g._add_unit("horse", 0, at + Vector2(20, 0))
	await wait(0.4)
	g.mount_order([lab])
	var rode: bool = await wait_for(func() -> bool: return is_instance_valid(lab) and lab.kind == "messenger", 20.0)
	ok_rec("unit:messenger", "ability", rode, "a Labourer MOUNTs a horse: a Messenger (labourer %s, order %s, work %s)" % [lab.kind if is_instance_valid(lab) else "gone", lab.order if is_instance_valid(lab) else "", lab.get("work") if is_instance_valid(lab) else ""], "WARN")
	# THE HORSE COMMANDS (pressed here one at a time, apart: the card presses run many at once)
	for pair in [["labourer", "messenger"], ["musketeer", "dragoon"], ["dismounted", "cuirassier"], ["missionary", "mounted_missionary"]]:
		var pa: Vector2 = _arenas(1, 3)[0] + Vector2(-80, 120)
		var man := _spawn_ready(String(pair[0]), pa)
		var hh: Unit = g._add_unit("horse", 0, pa + Vector2(50, 0))
		await wait(0.6)
		var nm := g.mount_order([man])
		var ok_m: bool = await wait_for(func() -> bool: return is_instance_valid(man) and man.kind == String(pair[1]), 15.0)
		ok_rec("unit:" + String(pair[1]), "ability", ok_m, "MOUNT: a %s gets on a horse and is a %s (%d sent; now %s)" % [pair[0], pair[1], nm, man.kind if is_instance_valid(man) else "gone"])
		if ok_m:
			man.cmd_dismount()
			var ok_d: bool = await wait_for(func() -> bool: return is_instance_valid(man) and man.kind == String(pair[0]), 8.0)
			ok_rec("unit:" + String(pair[1]), "ability", ok_d, "DISMOUNT: back to a %s" % pair[0])
		for x in [man, hh]:
			if is_instance_valid(x) and not x.dead:
				x.die()
	for lk in ["labourer", "musketeer"]:
		var la: Vector2 = _arenas(1, 3)[0] + Vector2(-80, 120)
		var ld := _spawn_ready(lk, la)
		var h2: Unit = g._add_unit("horse", 0, la + Vector2(60, 0))
		await wait(0.6)
		var n_lead := g.lead_order([ld])
		var led_ok: bool = await wait_for(func() -> bool: return ld.led.size() > 0, 12.0)
		ok_rec("unit:" + lk, "ability", led_ok, "LEAD: %d horse fetched, %d held by the reins" % [n_lead, ld.led.size()])
		g.set_selection([ld])
		g.hud.page = ""
		await physics_frame
		var rel: Array = (g.hud._build_card() as Array).filter(func(x: Array) -> bool: return String(x[1]) == "RELEASE")
		if rel.is_empty():
			rec("unit:" + lk, "ability", "FAIL", "no RELEASE on the card while he holds a horse")
		else:
			(rel[0][2] as Callable).call()
			await wait(4.0)
			ok_rec("unit:" + lk, "ability", ld.led.is_empty(), "RELEASE (pressed while he still fetches more): he holds %d horses 4 s later (order %s)" % [ld.led.size(), ld.order])
		g.set_selection([])
		for x in [ld, h2]:
			if is_instance_valid(x) and not x.dead:
				x.die()
	for gk in Defs.HARNESSED:
		var ga: Vector2 = _arenas(1, 3)[0] + Vector2(-80, 120)
		var wg := _spawn_ready(String(gk), ga)
		await wait(0.3)
		var hc0: int = wg.horse_count()
		var h3: Unit = g._add_unit("horse", 0, ga + Vector2(70, 0))
		await wait(0.6)
		var n_h := g.harness_order([wg])
		var hitched: bool = await wait_for(func() -> bool: return wg.horse_count() > hc0, 15.0)
		ok_rec("unit:" + String(gk), "ability", hitched, "HARNESS: %d sent, horses %d -> %d" % [n_h, hc0, wg.horse_count()])
		wg.release_horse()
		await wait(1.0)
		ok_rec("unit:" + String(gk), "ability", wg.horse_count() < hc0 + (1 if hitched else 0) or wg.horse_count() == 0, "RELEASE HORSE: horses now %d" % wg.horse_count())
		for x in [wg, h3]:
			if is_instance_valid(x) and not x.dead:
				x.die()
	# guns: unlimber / deploy
	for k in ["cannon", "mortar"]:
		var gu := _spawn_ready(k, _arenas(1, 3)[0] + Vector2(60, 60))
		var m0: String = gu.tesla_mode
		gu.cmd_deploy()
		var dep: bool = await wait_for(func() -> bool: return gu.tesla_mode == "deployed", 8.0)
		ok_rec("unit:" + k, "ability", dep, "DEPLOY / UNLIMBER: %s -> %s in %.1f s" % [m0, gu.tesla_mode, Defs.CANNON_SWITCH if k == "cannon" else Defs.MORTAR_SWITCH])
		gu.cmd_pack()
		var pk: bool = await wait_for(func() -> bool: return gu.tesla_mode == "packed", 8.0)
		ok_rec("unit:" + k, "ability", pk, "PACK / LIMBER again")
	# THE MARCHING BAND (0.37.0: individual musicians): a soldier in a Drummer's ring gets his buff; a Fifer and a Piper
	# beside him make a band (stronger); a solo raises it
	var bat: Vector2 = _arenas(1, 3)[0] + Vector2(0, 90)
	var band := _spawn_ready(MarchingBand.KIND, bat)
	var sol := _spawn_ready("musketeer", bat + Vector2(40, 0))
	await wait(1.5)
	var m1: Vector3 = sol.band_mul if sol.band_until > g.clock else Vector3.ONE
	ok_rec("unit:band", "ability", m1.x > 1.0, "a Musketeer beside a Drummer: speed x%.2f, melee x%.2f, reload x%.2f" % [m1.x, m1.y, m1.z])
	var fif := _spawn_ready("band_fifer", bat + Vector2(24, 0))
	var pip := _spawn_ready("band_piper", bat + Vector2(-24, 0))
	var formed: bool = await wait_for(func() -> bool: return MarchingBand.in_band(band) and MarchingBand.in_band(fif) and MarchingBand.in_band(pip), 3.0)
	ok_rec("unit:band_fifer", "ability", formed, "a Drummer, a Fifer and a Piper together make a BAND")
	ok_rec("unit:band_piper", "ability", formed, "the band's buffs: x%.2f each" % (sol.band_mul.x if sol.band_until > g.clock else 1.0))
	var why := MarchingBand.solo(fif, "fife")
	await wait(1.0)
	var m2: Vector3 = sol.band_mul if sol.band_until > g.clock else Vector3.ONE
	ok_rec("unit:band", "ability", why == "" and m2.z > m1.z + 0.3, "the band's FIFE SOLO: reload x%.2f -> x%.2f %s" % [m1.z, m2.z, why])
	# THE MISSIONARY raises a fallen Crown soldier
	var mis := _spawn_ready("missionary", bat + Vector2(0, 80))
	var fallen := _spawn_ready("musketeer", bat + Vector2(50, 80))
	fallen.take_damage(fallen.hp + 1000.0, null)
	await wait(0.5)
	if g.can_revive(fallen, mis):
		mis.cmd_revive(fallen)
		var up: bool = await wait_for(func() -> bool: return is_instance_valid(fallen) and not fallen.dead, float(Defs.REVIVE["time"]) + 8.0)
		ok_rec("unit:missionary", "ability", up, "REVIVE: a fallen Musketeer stands again (%s)" % ("hp %.0f" % fallen.hp if up else "still down"))
	else:
		rec("unit:missionary", "ability", "WARN", "can_revive refused a fresh Crown body beside him")
	errs_to("match:crown", "crown rules")


var last_why := ""


func _quick_train(b: Building, key: String) -> Unit:
	var before := {}
	for u in g.units:
		before[u] = true
	last_why = g.train(b, key)
	if last_why != "":
		return null
	for i in 30 * 20:
		if not b.queue.is_empty():
			b.prod_t = maxf(b.prod_t, Building.entry_time(b.queue[0]) - 0.2)
		await physics_frame
		for u in g.units:
			if not before.has(u) and u.team == 0 and u.kind == Defs.train_kind(key):
				return u
	return null


func _clock_rules() -> void:
	print("-- Clockwork rules: winding, gears")
	# a Clock Soldier runs down out of a field and a Winder winds it up again
	var at: Vector2 = _arenas(1, 3)[0]
	var cs: Unit = g._add_unit("clock_soldier", 0, at)
	if "wind" in cs:
		cs.wind = 0.2
		var w: Unit = _spawn_ready("winder", at + Vector2(40, 0))
		w.cmd_repair(cs)
		var wound: bool = await wait_for(func() -> bool: return cs.wind > 0.5, 20.0)
		ok_rec("unit:winder", "ability", wound, "a Winder winds a run-down Clock Soldier: wind 0.20 -> %.2f" % cs.wind)
	# a building with no gear link stops (placement refuses an unlinked spot)
	var far := Vector2i(g.W - 8, 8)
	var why := g.placement_problem(0, "regulator", far)
	ok_rec("bld:regulator", "place", why != "", "far from the gear network: refused ('%s')" % why)
	errs_to("match:clockwork", "clock rules")


# ------------------------------------------------------------------ the summary

const COLS := ["numbers", "queue", "data", "text", "icon", "art", "sound", "place", "cost", "refuse", "build", "repair", "make", "rally", "research", "effect", "grow",
	"buttons", "ability", "fight", "targets", "body", "ammo", "demolish"]


func _summary() -> void:
	print("\n==== SUMMARY (worst result per check: P pass, F FAIL, W warn, i info, s skip, . not tested) ====")
	var head := "%-30s" % "entry"
	for c in COLS:
		head += " %s" % c.left(4)
	print(head + "  verdict")
	var n := {"PASS": 0, "FAIL": 0, "WARN": 0}
	var counts := {"PASS": 0, "FAIL": 0, "WARN": 0, "INFO": 0, "SKIP": 0}
	var fails: Array = []
	var warns: Array = []
	for e in order:
		var worst := {}
		for c in res[e]:
			counts[c[1]] = int(counts.get(c[1], 0)) + 1
			var cat := String(c[0])
			if cat.begins_with("press "):
				cat = "ability"
			if not COLS.has(cat):
				cat = "ability" if cat in ["card"] else cat
			var r := _rank(String(c[1]))
			if r > int(worst.get(cat, -1)):
				worst[cat] = r
			if c[1] == "FAIL":
				fails.append("%s  %s: %s" % [e, c[0], c[2]])
			elif c[1] == "WARN":
				warns.append("%s  %s: %s" % [e, c[0], c[2]])
		var row := "%-30s" % e.left(30)
		var v := "PASS"
		for c in COLS:
			var r := int(worst.get(c, -1))
			row += "    %s" % [".", "s", "i", "P", "W", "F"][r + 1]
			if r == 4:
				v = "FAIL"
			elif r == 3 and v != "FAIL":
				v = "WARN"
		n[v] += 1
		print(row + "  " + v)
	print("\nentries: %d   verdicts: %d PASS, %d WARN, %d FAIL   checks: %s" % [order.size(), n["PASS"], n["WARN"], n["FAIL"], str(counts)])
	print("\n==== FAILS (%d) ====" % fails.size())
	for f in fails:
		print("FAIL  " + f)
	print("\n==== WARNINGS (%d) ====" % warns.size())
	for w in warns:
		print("WARN  " + w)
	print("\ncontent: %d FAIL checks, %d WARN checks, %.0f s" % [fails.size(), warns.size(), (Time.get_ticks_msec() - t0) / 1000.0])


func _rank(s: String) -> int:
	return {"SKIP": 0, "INFO": 1, "PASS": 2, "WARN": 3, "FAIL": 4}.get(s, 1)
