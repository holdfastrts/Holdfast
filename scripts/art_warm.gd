class_name ArtWarm
extends Node
## TEXTURES LOADED AHEAD (0.28.1, perf-stutter; the owner's lag report, 2026-11-03: freezes of 140 to 500 ms).
## A unit's pictures are loaded the first time each strip is shown (Game.tex): the Brood Mother's first ROOT, ROOTED and
## LAY took 15 to 25 ms each to load, twice in one frame made a 100 ms freeze at 0:01, and every kind's first attack,
## death or walk did the same in the middle of a fight. This node loads every strip of every kind standing on the field in
## the background (ResourceLoader's threads), a few at a time, as soon as the kind is seen, so they are in memory before
## they are first shown. Only the kinds in the match (not every faction's whole set: that would be ~150 MB for the Brood
## alone). Looks only: the match plays out the same.

const IN_FLIGHT := 3            # strips loading at once (the rest wait their turn)
const LOOK_EVERY := 0.5         # s between looks for new kinds on the field
## Without threads (the web build): one strip a frame, loaded right here, only when the last frame was quick (or in the
## 3-2-1 countdown): a few slightly longer frames early instead of a freeze when several are first shown at once.
const QUICK_MS := 20.0
const START_MS := 1500          # at most this long loading at the start (the rest in the background)
var threads := OS.has_feature("threads") or not OS.has_feature("web")
var _last_us := 0

var game: Game
var _seen := {}                 # art -> true (its strips are queued)
var _queue: Array = []          # paths still to load
var _loading := {}              # path -> true (requested, not taken yet)
var _look_t := 0.0
var _snd_queue: Array = []      # the sounds (assets/audio), after the pictures; with threads only
## OUTGROWN PICTURES LET GO (qa-perf, 0.33.8): the Brood Mother grows into new art (stages 2 and 3, `art` instead of
## her kind) and her old stage's strips stayed loaded: about 70 MB of pictures a stage (they sit in the graphics memory,
## which a phone shares with everything else). A stage no Mother on the field has shown for RELEASE_AFTER seconds, while a
## Mother is on the field, is dropped from Game's picture cache (only big sets: RELEASE_MB). Pictures only; if it is shown
## again (it isn't: a Mother never grows back) it is loaded again when first shown.
const RELEASE_EVERY := 5.0
const RELEASE_AFTER := 30.0
const RELEASE_MB := 8.0
var _release_t := RELEASE_EVERY
var _unshown := {}              # art -> seconds no unit has shown it (while its kind is on the field showing another)
var released: Array = []        # arts let go, or small enough to keep (not looked at again)
var _art_kind := {}             # art -> the kind that showed it (a kind's own art, and the stages it grew through)
static var _keep: Array = []    # (the sounds loaded ahead stay loaded: Sfx's load() then finds them at once)
## Paths asked for by Game.tex while loading in the background (Game.tex then waits for that one).
static var pending := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# (the effects every fight uses: small, all of them at once)
	for name in ArtData.EFFECTS:
		_add("res://assets/effects/%s.png" % name)
	_look()
	# (the kinds standing at the start are loaded now, while the match is still loading: the Brood Mother roots at once)
	var t0 := Time.get_ticks_msec()
	while not _queue.is_empty() and Time.get_ticks_msec() - t0 < START_MS:
		var p: String = _queue.pop_front()
		if not Game._tex_cache.has(p):
			if p.begins_with(HorseCoat.MASKS):
				_keep.append(load(p))
			else:
				Game._tex_cache[p] = load(p)
	# the sounds: each name's first play loaded its files (Sfx._find), the first fight's many new sounds at once
	if threads and _keep.is_empty():
		_add_sounds("res://assets/audio/")


func _add_sounds(dir: String) -> void:
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			if f != "ambience/":
				_add_sounds(dir + f)
		elif f.ends_with(".wav") or f.ends_with(".ogg"):
			_snd_queue.append(dir + f)


func _exit_tree() -> void:
	# (whatever is still loading is taken so no request is left behind)
	for p in _loading:
		if ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(p)
	_loading.clear()
	pending.clear()


func _process(delta: float) -> void:
	if game == null:
		return
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = LOOK_EVERY
		_look()
	_release_t -= delta
	if _release_t <= 0.0:
		_release_t = RELEASE_EVERY
		_release()
	for p in _loading.keys():
		var st := ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_loading.erase(p)
		pending.erase(p)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			var r := ResourceLoader.load_threaded_get(p)
			if r is Texture2D and not p.begins_with(HorseCoat.MASKS):
				if not Game._tex_cache.has(p):
					Game._tex_cache[p] = r
			elif r != null:
				_keep.append(r)
	if not threads:
		var now := Time.get_ticks_usec()
		var quick := _last_us == 0 or (now - _last_us) / 1000.0 < QUICK_MS or get_tree().paused
		while quick and not _queue.is_empty():
			var p: String = _queue.pop_front()
			if p.begins_with(HorseCoat.MASKS):
				if not ResourceLoader.has_cached(p):
					_keep.append(load(p))
					break
			elif not Game._tex_cache.has(p):
				Game._tex_cache[p] = load(p)
				break
		_last_us = Time.get_ticks_usec()
		return
	while _loading.size() < IN_FLIGHT and not _queue.is_empty():
		var p: String = _queue.pop_front()
		if Game._tex_cache.has(p):
			continue
		if ResourceLoader.load_threaded_request(p, "Texture2D") == OK:
			_loading[p] = true
			if not p.begins_with(HorseCoat.MASKS):
				pending[p] = true
	while _loading.size() < IN_FLIGHT and _queue.is_empty() and not _snd_queue.is_empty():
		var p: String = _snd_queue.pop_front()
		if ResourceLoader.has_cached(p):
			continue
		if ResourceLoader.load_threaded_request(p) == OK:
			_loading[p] = true


## Lets go of a kind's own strips once it has grown out of them (see RELEASE_AFTER).
func _release() -> void:
	var shown := {}
	var kinds := {}
	for u in game.units:
		if is_instance_valid(u):
			shown[u.art] = true
			kinds[u.kind] = true
			if u.art != u.kind and not _art_kind.has(u.art):
				_art_kind[u.art] = u.kind
	# (an art is outgrown when no unit shows it while a unit of its kind is on the field: that kind's own art, or a stage
	# it showed before)
	for a in _art_kind:
		var k: String = _art_kind[a]
		if k != BroodNew.QUEEN:
			continue                 # (only the Mother grows through stages; other art changes (armour) flip back and forth)
		if shown.has(a) or not kinds.has(k) or released.has(a) or not ArtData.UNITS.has(a):
			_unshown.erase(a)
			continue
		_unshown[a] = float(_unshown.get(a, 0.0)) + RELEASE_EVERY
		if float(_unshown[a]) < RELEASE_AFTER:
			continue
		var paths: Array = []
		var mb := 0.0
		for key in ArtData.UNITS[a]["frames"]:
			var p := "res://assets/units/%s/%s.png" % [a, key]
			var tx = Game._tex_cache.get(p)
			if tx is Texture2D:
				paths.append(p)
				mb += (tx as Texture2D).get_width() * (tx as Texture2D).get_height() * 4.0 / 1048576.0
		_unshown.erase(a)
		if mb < RELEASE_MB:
			released.append(a)        # (small: kept, and not looked at again)
			continue
		for p in paths:
			Game._tex_cache.erase(p)
		released.append(a)


## Every kind on the field whose strips aren't queued yet: all its strips into the queue.
func _look() -> void:
	for u in game.units:
		if not is_instance_valid(u) or u.dead:
			continue
		if not _art_kind.has(u.kind):
			_art_kind[u.kind] = u.kind
		for a in [u.art, u.kind]:
			if a != "" and not _seen.has(a):
				_seen[a] = true
				_add_art(a)


func _add_art(a: String) -> void:
	if not ArtData.UNITS.has(a):
		return
	for key in ArtData.UNITS[a]["frames"]:
		_add("res://assets/units/%s/%s.png" % [a, key])
		# (a horse's coat mask for the strip, loaded on its first show too: HorseCoat.mask_for)
		var mp := HorseCoat.MASKS + "%s/%s.png" % [a, key]
		if not _loading.has(mp) and ResourceLoader.exists(mp) and not ResourceLoader.has_cached(mp):
			_queue.append(mp)


func _add(p: String) -> void:
	if Game._tex_cache.has(p) or _loading.has(p) or CwArt.is_placeholder(p) or not ResourceLoader.exists(p):
		return
	_queue.append(p)


## Game.tex's way in: a path loading in the background is waited for (and taken) instead of loaded a second time.
static func take(p: String) -> Texture2D:
	if not pending.has(p):
		return null
	pending.erase(p)
	var r := ResourceLoader.load_threaded_get(p)
	return r as Texture2D
