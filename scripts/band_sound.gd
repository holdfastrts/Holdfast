class_name BandSound
extends Node
## THE MARCHING BAND's SOUND ENGINE (job band-v2, docs/band_v2.md; WHO IS HEARD redone for individual musicians in
## 0.37.0, docs/band_individuals.md; the REPERTOIRE and the PLAYLIST in band-repertoire, docs/band_music.md). One node
## per match (made by the first musician that ticks: BandSound.need), its own players on the SFX bus, so the shared
## sound player (Sfx) is left alone. The rules:
##  - EITHER THE NEAREST BAND OR THE NEAREST FEW LONE MUSICIANS are heard, never both: whichever is nearest the middle
##    of the screen (a solo first), on screen or just off it, seen by your side (Sfx.heard: no music through the fog).
##  - THE MUSICIANS GO THROUGH A PLAYLIST (owner's playtest 2026-11-14 13:18: "no single tune on loop"): one whole tune,
##    then the next, linked by the drums' roll-off (each tune's files begin with it), never the same tune twice in a
##    row. The list is ORDER, in turn; the situation only shapes it (next_tune): while the band's men are FIGHTING the
##    slow air (The Minstrel Boy) is skipped, and if it is playing it stops at its next phrase end (TUNES "phrases",
##    a quick fade) for a march or the quickstep; standing IDLE a while (IDLE_AIR s) the slow air may come next.
##  - A BAND plays IN STEP: all bands share one playlist on one clock (`_band`), so their parts start together and the
##    music does not restart when the heard band changes.
##  - LONE MUSICIANS play OUT OF STEP: each has his own playlist (`_lone_pl`), started a little off the band's clock
##    (STEP_OFF), so two of them together sound like what they are; at most LONE_MAX of them (the nearest) at once,
##    each at the quiet level, so it is never loud chaos. Each plays his own part of whatever tune his playlist is on.
##  - Every instrument has a BACKGROUND part (the always-on file: the Drummer a march beating, snare and bass) played at
##    QUIET_DB, and a SOLO part of the same tune. A SOLO DOES NOT CHANGE THE TUNE: the soloist's part comes forward
##    (LEAD_DB, his solo file at the same place in the same tune), the others stay under it (UNDER_DB) and the game
##    music goes down further (DUCK_SOLO_DB); afterwards both come back smoothly (FADE, DUCK_RATE).
##    Further from the middle of the screen and zoomed out it is quieter; off past CUT px it is silent.
##  - THE GAME MUSIC GIVES WAY TO THE BAND (band-music-v2, owner 2026-11-14: "if we are hovering our camera near the
##    band the game music has to drop down so the main piece is the band's music"): while a band (or lone musicians) is
##    heard the faction/battle music is ducked STRONGLY: DUCK_DB with the band in the middle of the screen, DUCK_SOLO_DB
##    during a heard solo, less the further from the middle (duck_for: none past 640 px) and a little more
##    zoomed in (ZOOM_IN_DB); it moves DUCK_RATE dB a second. An Amplify effect on the "Music" bus, so the players'
##    MUSIC and SOUND volume sliders still set the balance; put back to 0 when the match ends.
## THE MUSIC (tools/audio/make_band_music.py renders it from real samples; docs/band_music.md): every file of a tune is
## [the roll-off][the tune once][a short tail], all six of a tune exactly TUNES[t]["n"] samples long; every file levelled
## by its integrated loudness (always-on -27 LUFS, solo -23, the pipes 1.5 LU back). New tunes: add them to TUNES (the
## numbers the script prints in tools/audio/band_repertoire.json) and to ORDER. Nothing else.

## The repertoire (traditional melodies; our own drum beatings): length in samples at 44.1 kHz, where the tune itself
## starts after the roll-off (s), the phrase ends where it may be cut short (s), its kind.
const TUNES := {
	"grenadiers": {"title": "The British Grenadiers", "n": 1918350, "roll": 4.8, "kind": "march",
		"phrases": [9.0, 13.8, 18.6, 23.4, 28.2, 33.0, 37.8]},
	"scotland": {"title": "Scotland the Brave", "n": 1771617, "roll": 4.3636, "kind": "march",
		"phrases": [13.0909, 21.8182, 30.5455]},
	"garryowen": {"title": "Garry Owen", "n": 1557029, "roll": 2.0339, "kind": "quick",
		"phrases": [5.9322, 10.0, 14.0678, 18.1356, 22.2034, 26.2712, 30.339]},
	"minstrel": {"title": "The Minstrel Boy", "n": 2610090, "roll": 3.4286, "kind": "air",
		"phrases": [16.7143, 30.4286, 44.1429]},
	"godsave": {"title": "God Save the King", "n": 1803690, "roll": 5.0, "kind": "anthem",
		"phrases": [15.0, 25.0, 35.0]},
}
## The playlist, in turn (God Save the King is in the files, not in the list: an extra for later).
const ORDER := ["grenadiers", "scotland", "garryowen", "minstrel"]
## instrument -> [the background (always-on) file's part, the solo file's part]: res://assets/audio/band/<tune>_<part>.ogg
const PARTS := {
	"drums": ["drums", "drums_lead"],
	"fife": ["fife", "fife_lead"],
	"pipes": ["pipes", "pipes_lead"],
}
const QUIET_DB := -9.0      # an instrument playing along (its +5%): its background part (files at -27 LUFS)
const LEAD_DB := -3.0       # the instrument leading a SOLO: its solo part (files at -23 LUFS), clearly forward
const UNDER_DB := -10.0     # the others while one solos (the tune goes on as it was, a touch under)
const CUT := 760.0          # screen px from the middle of the screen past which a band is not heard
const NEAR := 160.0         # screen px within which it is at full level
const ZOOM_OUT := 0.85      # zoomed out further than this: quieter (a band is small on the screen)
const DUCK_DB := -12.0      # the game music while a band is heard in the middle of the screen (the band leads)
const DUCK_SOLO_DB := -16.0 # ... while its solo is heard
const ZOOM_IN_DB := -2.0    # ... and up to this much more zoomed in (zoom 1 -> 2)
const DUCK_RATE := 10.0     # dB a second the music's duck moves by (-12 dB in 1.2 s; smooth, no pumping)
const FADE := 6.0           # dB a tenth of a second the levels move by (no clicks, no jumps)
const CUT_FADE := 0.18      # s: a tune cut short at a phrase end fades out over this before the roll-off
const SWITCH := 90.0        # px: another band (or lone group) must be this much nearer to take over (no flip-flopping)
const LONE_MAX := 3         # lone musicians heard at once at most (the nearest)
const STEP_OFF := [0.23, 0.41, 0.62, 0.79]      # s off the band's clock a lone musician plays (by his number): out of step
const IDLE_AIR := 30.0      # s standing still: the slow air may come next
const FIGHT_FOR := 6.0      # s since a musician was last hit: still fighting
const FIGHT_NEAR := 7.0     # tiles: an enemy this near the musicians = fighting
const SR := 44100.0

## One playlist: the tune it is on, when that tune started (ms, Time.get_ticks_msec), where it is cut short (s; -1
## played to its end), the tune before, and what it knows of its men (fighting, still since).
class Playlist:
	var tune := "grenadiers"
	var start := 0
	var cut := -1.0
	var prev := ""
	var fighting := false
	var still_since := 0
	var where := Vector2.INF
	var played := 0          # tunes played through (tests)

static var me: BandSound

var game: Game
var focus: Unit = null       # the band heard now (its Drummer), or the nearest lone musician heard (null none)
var heard: Array = []        # the musicians heard now
var t0 := 0                  # the band's clock's start (ms)
var _band: Playlist          # every band's playlist (one: bands are in step with each other)
var _lone_pl := {}           # musician instance id -> his own Playlist
var _players := {}           # key -> AudioStreamPlayer: a band's parts "B/<ins>/a" (background) "B/<ins>/b" (solo), the lone slots "L<i>/a" "L<i>/b"
var _target := {}            # key -> the level it is moving to (dB; -80 silent)
var _src := {}               # key -> [Playlist, instrument, solo?]: what the player plays
var _off := {}               # key -> its offset from the band's clock (s; 0 for a band's parts)
var _lone := []              # lone slot i -> [musician, instrument] (or null)
var _streams := {}           # file -> its stream (decoded once, shared)
var _duck := 0.0
var _duck_target := 0.0
var _fx_idx := -1
var _sit_t := 0              # ms: the situation was last looked at (once a second)


## The match's band sound, made on first use (MarchingBand.look_tick; host, online guest and replay alike).
static func need(g: Game) -> BandSound:
	if me != null and is_instance_valid(me) and me.game == g:
		return me
	var n := BandSound.new()
	n.name = "BandSound"
	n.game = g
	g.add_child(n)
	me = n
	return n


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	t0 = Time.get_ticks_msec()
	_band = Playlist.new()
	_band.tune = ORDER[0]
	_band.start = t0
	_band.still_since = t0
	for ins in PARTS:
		_add_player("B/%s/a" % ins)
		_add_player("B/%s/b" % ins)
	for i in LONE_MAX:
		_lone.append(null)
		_add_player("L%d/a" % i)
		_add_player("L%d/b" % i)


## The file of an instrument's part of a tune (res://assets/audio/<file>.ogg).
static func file(tune: String, ins: String, solo: bool) -> String:
	return "band/%s_%s" % [tune, PARTS[ins][1 if solo else 0]]


## A tune's length (s).
static func length(tune: String) -> float:
	return float(TUNES[tune]["n"]) / SR


func _stream(f: String) -> AudioStream:
	if _streams.has(f):
		return _streams[f]
	var st: AudioStream = null
	var path := "res://assets/audio/%s.ogg" % f
	if ResourceLoader.exists(path):
		st = (load(path) as AudioStream).duplicate()
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = false
	_streams[f] = st
	return st


func _add_player(key: String) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	if OS.has_feature("web"):
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	p.volume_db = -80.0
	add_child(p)
	_players[key] = p
	_target[key] = -80.0
	_off[key] = 0.0


func _exit_tree() -> void:
	_set_duck(0.0)
	if me == self:
		me = null


# ---------------------------------------------------------------- the playlist

## The tune after `cur`: the next in ORDER, never `cur` again; FIGHTING skips the slow air; standing IDLE a while
## brings the slow air next (unless it was just played).
static func next_tune(cur: String, fighting: bool, idle: bool, prev := "") -> String:
	if idle and not fighting and cur != "minstrel" and prev != "minstrel" and ORDER.has("minstrel"):
		return "minstrel"
	var i := ORDER.find(cur)
	for k in range(1, ORDER.size() + 1):
		var c: String = ORDER[(i + k) % ORDER.size()] if i >= 0 else ORDER[(k - 1) % ORDER.size()]
		if c == cur:
			continue
		if fighting and String(TUNES[c]["kind"]) == "air":
			continue
		return c
	return ORDER[0] if cur != ORDER[0] else ORDER[1]


## Where a playlist is in its tune now (s).
func pos(pl: Playlist) -> float:
	return float(Time.get_ticks_msec() - pl.start) / 1000.0


## Where its tune ends (s): its length, or the phrase end it is cut short at.
static func end_of(pl: Playlist) -> float:
	return pl.cut if pl.cut > 0.0 else length(pl.tune)


## Moves a playlist on: at its tune's end the next tune (next_tune, by what its men are doing). While they fight the
## slow air is cut short at its next phrase end.
func advance(pl: Playlist) -> void:
	var idle := float(Time.get_ticks_msec() - pl.still_since) / 1000.0 >= IDLE_AIR
	if pl.fighting and pl.cut < 0.0 and String(TUNES[pl.tune]["kind"]) == "air":
		var p := pos(pl)
		for ph in TUNES[pl.tune]["phrases"]:
			if float(ph) > p + CUT_FADE + 0.05:
				pl.cut = float(ph)
				break
	var guard := 0
	while pos(pl) >= end_of(pl) and guard < 64:
		pl.start += int(round(end_of(pl) * 1000.0))
		var nx := next_tune(pl.tune, pl.fighting, idle, pl.prev)
		pl.prev = pl.tune
		pl.tune = nx
		pl.cut = -1.0
		pl.played += 1
		guard += 1


## dB to add for a playlist cut short: down to -60 over its last CUT_FADE s (no click at the phrase end).
func env_db(pl: Playlist) -> float:
	if pl.cut <= 0.0:
		return 0.0
	var left := pl.cut - pos(pl)
	return 0.0 if left >= CUT_FADE else -60.0 * clampf(1.0 - left / CUT_FADE, 0.0, 1.0)


## What the musicians `ms` are doing: hit lately, or an enemy near them = fighting; standing still since when.
func look(pl: Playlist, ms: Array) -> void:
	if ms.is_empty() or game == null:
		return
	var c := MarchingBand.centre(ms)
	var now := Time.get_ticks_msec()
	if pl.where == Vector2.INF or c.distance_to(pl.where) > 6.0:
		pl.where = c
		pl.still_since = now
	var f := false
	for m in ms:
		if is_instance_valid(m) and game.clock - float((m as Unit).hit_clock) < FIGHT_FOR:
			f = true
	if not f:
		var team := int((ms[0] as Unit).team)
		for o in game.units_near(c, FIGHT_NEAR * Defs.TILE):
			if o is Unit and not (o as Unit).dead and game.hostile((o as Unit).team, team):
				f = true
				break
	pl.fighting = f


## A lone musician's own playlist (made the first time he is heard: on the band's tune, a little off its clock).
func lone_list(u: Unit) -> Playlist:
	var k := u.get_instance_id()
	if not _lone_pl.has(k):
		var pl := Playlist.new()
		pl.tune = _band.tune
		pl.start = _band.start - int(offset_of(u) * 1000.0)
		pl.prev = _band.prev
		pl.still_since = Time.get_ticks_msec()
		_lone_pl[k] = pl
		if _lone_pl.size() > 64:        # (forget the long gone)
			for kk in _lone_pl.keys():
				if not is_instance_valid(instance_from_id(kk)):
					_lone_pl.erase(kk)
	return _lone_pl[k]


## Where the band's clock is in its tune now (s); `off`: a lone musician's offset from it. (tests)
func phase(off := 0.0) -> float:
	return pos(_band) + off


## A lone musician's offset from the band's clock (s): out of step, by his number.
static func offset_of(u: Unit) -> float:
	return float(STEP_OFF[int(u.band.get("id", 0)) % STEP_OFF.size()])


## (tests) the band's playlist / a lone musician's.
func band_list() -> Playlist:
	return _band


## The level each player should play at now (all -80 when nothing is heard), and what it plays (_src). Also the music
## duck. Lone slots are (re)assigned to the musicians heard.
func targets() -> Dictionary:
	var out := {}
	for k in _players:
		out[k] = -80.0
	_duck_target = 0.0
	heard = pick()
	focus = heard[0] if not heard.is_empty() else null
	var now := Time.get_ticks_msec()
	var looking := now - _sit_t >= 1000
	if looking:
		_sit_t = now
	if heard.is_empty() or not MarchingBand.in_band(heard[0]):
		if looking:
			_band.fighting = false
			_band.still_since = now      # (idle means a band heard standing still, not a band nobody hears)
			_band.where = Vector2.INF
	if heard.is_empty():
		for i in LONE_MAX:
			_lone[i] = null
		return out
	var solo_on := false
	if MarchingBand.in_band(heard[0]):
		# the band: its parts in step, on the band's playlist
		if looking:
			look(_band, heard)
		var lvl := level(MarchingBand.centre(heard))
		if lvl <= -60.0:
			return out
		var ld := ""
		for m in heard:
			if MarchingBand.lead(m) != "":
				ld = MarchingBand.lead(m)
		for m in heard:
			var ins := MarchingBand.ins_of(m)
			_src["B/%s/a" % ins] = [_band, ins, false]
			_src["B/%s/b" % ins] = [_band, ins, true]
			if ins == ld:
				out["B/%s/b" % ins] = LEAD_DB + lvl
			else:
				out["B/%s/a" % ins] = (UNDER_DB if ld != "" else QUIET_DB) + lvl
		solo_on = ld != ""
		for i in LONE_MAX:
			_lone[i] = null
		_duck_target = duck_for(lvl, solo_on)
		return out
	# lone musicians: each his own part, on his own playlist
	var keep := {}
	for i in LONE_MAX:
		var sl = _lone[i]
		if sl != null and heard.has(sl[0]):
			keep[sl[0]] = i
		else:
			_lone[i] = null
	var best_lvl := -80.0
	for m in heard:
		var i := int(keep.get(m, -1))
		if i < 0:
			i = _lone.find(null)
			if i < 0:
				continue
			_lone[i] = [m, MarchingBand.ins_of(m)]
		var lvl2 := level(m.position)
		best_lvl = maxf(best_lvl, lvl2)
		var ins2 := MarchingBand.ins_of(m)
		var pl := lone_list(m)
		if looking:
			look(pl, [m])
		_src["L%d/a" % i] = [pl, ins2, false]
		_src["L%d/b" % i] = [pl, ins2, true]
		_off["L%d/a" % i] = offset_of(m)
		_off["L%d/b" % i] = offset_of(m)
		if MarchingBand.lead(m) != "":
			out["L%d/b" % i] = LEAD_DB + lvl2
			solo_on = true
		else:
			out["L%d/a" % i] = QUIET_DB + lvl2
	_duck_target = duck_for(best_lvl, solo_on)
	return out


## How far the game music is ducked (dB) under music heard at level `lvl` (level(): 0 in the middle of the screen,
## down to -30 at CUT, less zoomed out): the full DUCK_DB / DUCK_SOLO_DB near the middle, fading out by lvl -24 (640 px
## from the middle), plus up to ZOOM_IN_DB zoomed in.
func duck_for(lvl: float, solo: bool) -> float:
	var near := clampf(1.0 + lvl / 24.0, 0.0, 1.0)
	var d := (DUCK_SOLO_DB if solo else DUCK_DB) * near
	var cam: Camera2D = game.camera if game != null and game.get("camera") != null else null
	if cam != null and is_instance_valid(cam) and cam.zoom.x > 1.0:
		d += ZOOM_IN_DB * clampf(cam.zoom.x - 1.0, 0.0, 1.0) * near
	return d


## (tests) the game music's duck now and where it is moving to (dB).
func duck_now() -> Vector2:
	return Vector2(_duck, _duck_target)


## Who is heard: the nearest BAND (its members) or the nearest LONE_MAX lone musicians, whichever is nearest the middle
## of the screen (a solo counts 400 px nearer); what is heard now keeps it unless the other is SWITCH px nearer.
func pick() -> Array:
	if game == null or not is_instance_valid(game) or Sfx.hush:
		return []
	var bands := {}         # key -> [score, members]
	var lones: Array = []   # [score, musician]
	for u in game.units:
		if not MarchingBand.is_musician(u) or u.dead or not u.visible or u.band.is_empty() or MarchingBand.legacy(u):
			continue
		var d := screen_dist(u.position)
		if d > CUT or not Sfx.heard("band/drums", u.position):
			continue
		var sc := d - (400.0 if MarchingBand.lead(u) != "" else 0.0)
		if MarchingBand.in_band(u):
			var key := "%d:%d" % [u.team, MarchingBand.band_key(u)]
			if not bands.has(key):
				bands[key] = [INF, MarchingBand.mates(u)]
			bands[key][0] = minf(float(bands[key][0]), sc)
		else:
			lones.append([sc, u])
	var best_band: Array = []
	var bb := INF
	var cur_key := ""
	for k in bands:
		if not heard.is_empty() and is_instance_valid(heard[0]) and (bands[k][1] as Array).has(heard[0]):
			cur_key = k
		if float(bands[k][0]) < bb:
			bb = float(bands[k][0])
			best_band = bands[k][1]
	if cur_key != "" and float(bands[cur_key][0]) < bb + SWITCH:
		best_band = bands[cur_key][1]       # (the band heard now keeps it unless another is SWITCH px nearer)
		bb = float(bands[cur_key][0])
	lones.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var bl := float(lones[0][0]) if not lones.is_empty() else INF
	if not best_band.is_empty() and bb <= bl:
		return best_band
	var out: Array = []
	for i in mini(LONE_MAX, lones.size()):
		out.append(lones[i][1])
	return out


## Screen px from the middle of the screen to a place.
func screen_dist(at: Vector2) -> float:
	var cam: Camera2D = game.camera if game.get("camera") != null else null
	if cam == null or not is_instance_valid(cam):
		return 0.0
	return at.distance_to(cam.get_screen_center_position()) * cam.zoom.x


## dB to add for where the music is: 0 near the middle of the screen, down to -30 at CUT; zoomed far out a little less.
func level(at: Vector2) -> float:
	var d := screen_dist(at)
	var db := -30.0 * clampf((d - NEAR) / (CUT - NEAR), 0.0, 1.0)
	var cam: Camera2D = game.camera if game.get("camera") != null else null
	if cam != null and is_instance_valid(cam) and cam.zoom.x < ZOOM_OUT:
		db -= (ZOOM_OUT - cam.zoom.x) * 18.0
	return db


func _process(delta: float) -> void:
	var paused := get_tree().paused or game == null or not is_instance_valid(game)
	_target = {} if paused else targets()
	if paused:
		for f in _players:
			_target[f] = -80.0
		_duck_target = 0.0
	advance(_band)
	var step := FADE * delta * 10.0
	var any := false
	var moved := {}
	for f in _players:
		var p: AudioStreamPlayer = _players[f]
		var want := float(_target.get(f, -80.0))
		var gain := Sfx.gain(p.stream)
		var cur := p.volume_db - gain if p.playing else -80.0
		var src = _src.get(f)
		if src == null:
			if p.playing:
				p.stop()
			continue
		var pl: Playlist = src[0]
		if not moved.has(pl):
			advance(pl)
			moved[pl] = true
		var nv := move_toward(cur, want, step)
		if nv <= -79.0 and want <= -79.0:
			if p.playing:
				p.stop()
			continue
		var st := _stream(file(pl.tune, String(src[1]), bool(src[2])))
		if st == null:
			continue
		var ph := pos(pl)
		if p.stream != st:
			p.stop()
			p.stream = st
		any = true
		p.volume_db = nv + env_db(pl) + Sfx.gain(st)
		if ph >= length(pl.tune) - 0.02:
			continue                 # (the tune's last moment: the next one starts when the playlist moves on)
		if not p.playing:
			p.play(ph)               # (a band's parts on the band's clock; a lone musician on his own playlist)
		elif absf(p.get_playback_position() - ph) > 0.08:
			p.seek(ph)               # (drifted: back where it should be)
	_duck = move_toward(_duck, _duck_target if any else 0.0, DUCK_RATE * delta)
	_set_duck(_duck)


## The game music's duck: an Amplify effect on the Music bus (added once; the volume slider is left alone).
func _set_duck(db: float) -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus < 0:
		return
	if _fx_idx < 0 or _fx_idx >= AudioServer.get_bus_effect_count(bus) or not (AudioServer.get_bus_effect(bus, _fx_idx) is AudioEffectAmplify) \
			or AudioServer.get_bus_effect(bus, _fx_idx).resource_name != "band_duck":
		_fx_idx = -1
		for i in AudioServer.get_bus_effect_count(bus):
			var e := AudioServer.get_bus_effect(bus, i)
			if e is AudioEffectAmplify and e.resource_name == "band_duck":
				_fx_idx = i
		if _fx_idx < 0:
			if absf(db) < 0.01:
				return
			var amp := AudioEffectAmplify.new()
			amp.resource_name = "band_duck"
			AudioServer.add_bus_effect(bus, amp)
			_fx_idx = AudioServer.get_bus_effect_count(bus) - 1
	(AudioServer.get_bus_effect(bus, _fx_idx) as AudioEffectAmplify).volume_db = db


## (tests) the level each player is moving to now.
func levels() -> Dictionary:
	return targets()


## (tests) the offset from the band's clock each player plays at now.
func offsets() -> Dictionary:
	return _off.duplicate()


## (tests) the tune each player plays now ("" none).
func tunes_now() -> Dictionary:
	var out := {}
	for k in _players:
		var s = _src.get(k)
		out[k] = (s[0] as Playlist).tune if s != null else ""
	return out
