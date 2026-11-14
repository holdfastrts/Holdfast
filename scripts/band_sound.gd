class_name BandSound
extends Node
## THE MARCHING BAND's SOUND ENGINE (job band-v2, docs/band_v2.md; WHO IS HEARD redone for individual musicians in
## 0.37.0, docs/band_individuals.md). One node per match (made by the first musician that ticks: BandSound.need), its own
## players on the SFX bus, so the shared sound player (Sfx) is left alone. The rules:
##  - EITHER THE NEAREST BAND OR THE NEAREST FEW LONE MUSICIANS are heard, never both: whichever is nearest the middle
##    of the screen (a solo first), on screen or just off it, seen by your side (Sfx.heard: no music through the fog).
##  - A BAND plays IN STEP: its parts on one shared clock (the real time since the node was made, wrapped at the phrase),
##    so they start together, and the music does not restart when the heard band changes.
##  - LONE MUSICIANS play OUT OF STEP: each his own part, a little off the shared clock (his own offset: STEP_OFF), so
##    two of them together sound like what they are, a cacophony; at most LONE_MAX of them (the nearest) at once, each
##    at the quiet level, so it is never loud chaos.
##  - The ALWAYS-ON playing is quiet (QUIET_DB); a SOLO is clearly heard (LEAD_DB) with the others under it
##    (UNDER_DB). Further from the middle of the screen and zoomed out it is quieter; off past CUT px it is silent.
##  - The GAME MUSIC is ducked a little while music is heard (DUCK_DB), more during a heard solo (DUCK_SOLO_DB): an
##    Amplify effect on the "Music" bus, put back to 0 when the match ends.
## NEW BAND MUSIC (the music job): change PARTS (one file per part: the always-on loop and the solo loop of each
## instrument) and PHRASE / BPM below; every file must be exactly PHRASE s long, in one key and tempo. Nothing else.

## One place for the band's files (res://assets/audio/<name>.ogg): instrument -> [always-on loop, solo loop].
const PARTS := {
	"drums": ["band/drums", "band/drums_lead"],
	"fife": ["band/fife", "band/fife_lead"],
	"pipes": ["band/pipes", "band/pipes_lead"],
}
const PHRASE := 4.0         # s: every loop's length (two bars of 4/4 at BPM)
const BPM := 120.0          # (for the music job: the files' tempo; the engine only needs PHRASE)
const BARS := 2
const QUIET_DB := -15.0     # an instrument playing along (its +5%): quiet, under the fight
const LEAD_DB := -1.0       # the instrument leading a SOLO: clearly heard
const UNDER_DB := -19.0     # the others while one solos
const CUT := 760.0          # screen px from the middle of the screen past which a band is not heard
const NEAR := 160.0         # screen px within which it is at full level
const ZOOM_OUT := 0.85      # zoomed out further than this: quieter (a band is small on the screen)
const DUCK_DB := -2.5       # the game music while a band is heard
const DUCK_SOLO_DB := -6.0  # ... while its solo is heard
const FADE := 6.0           # dB a tenth of a second the levels move by (no clicks, no jumps)
const SWITCH := 90.0        # px: another band (or lone group) must be this much nearer to take over (no flip-flopping)
const LONE_MAX := 3         # lone musicians heard at once at most (the nearest)
const STEP_OFF := [0.23, 0.41, 0.62, 0.79]      # s off the shared clock a lone musician plays (by his number): out of step

static var me: BandSound

var game: Game
var focus: Unit = null       # the band heard now (its Drummer), or the nearest lone musician heard (null none)
var heard: Array = []        # the musicians heard now
var t0 := 0                  # the shared clock's start (ms)
var _players := {}           # key -> AudioStreamPlayer (looping): a band's parts by file name, the lone slots "L<i>/a" (always-on) "L<i>/b" (solo)
var _target := {}            # key -> the level it is moving to (dB; -80 silent)
var _off := {}               # key -> its offset from the shared clock (s; 0 for a band's parts)
var _lone := []              # lone slot i -> [musician, instrument] (or null)
var _streams := {}           # file -> its looping stream
var _duck := 0.0
var _duck_target := 0.0
var _fx_idx := -1


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
	for ins in PARTS:
		for f in PARTS[ins]:
			_add_player(f, _stream(f))
	for i in LONE_MAX:
		_lone.append(null)
		_add_player("L%d/a" % i, null)
		_add_player("L%d/b" % i, null)


func _stream(f: String) -> AudioStream:
	if _streams.has(f):
		return _streams[f]
	var st: AudioStream = null
	var path := "res://assets/audio/%s.ogg" % f
	if ResourceLoader.exists(path):
		st = (load(path) as AudioStream).duplicate()
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		elif st is AudioStreamWAV:
			(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(st as AudioStreamWAV).loop_end = int(PHRASE * (st as AudioStreamWAV).mix_rate)
	_streams[f] = st
	return st


func _add_player(key: String, st: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	if OS.has_feature("web"):
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	p.stream = st
	p.volume_db = -80.0
	add_child(p)
	_players[key] = p
	_target[key] = -80.0
	_off[key] = 0.0


func _exit_tree() -> void:
	_set_duck(0.0)
	if me == self:
		me = null


## Where the shared clock is in the phrase now (s); `off`: a lone musician's offset from it.
func phase(off := 0.0) -> float:
	return fmod(float(Time.get_ticks_msec() - t0) / 1000.0 + off, PHRASE)


## A lone musician's offset from the shared clock (s): out of step, by his number.
static func offset_of(u: Unit) -> float:
	return float(STEP_OFF[int(u.band.get("id", 0)) % STEP_OFF.size()])


## The level each player should play at now (all -80 when nothing is heard). Also the music duck. Lone slots are
## (re)assigned to the musicians heard.
func targets() -> Dictionary:
	var out := {}
	for k in _players:
		out[k] = -80.0
	_duck_target = 0.0
	heard = pick()
	focus = heard[0] if not heard.is_empty() else null
	if heard.is_empty():
		for i in LONE_MAX:
			_lone[i] = null
		return out
	var solo_on := false
	if MarchingBand.in_band(heard[0]):
		# the band: its parts in step
		var lvl := level(MarchingBand.centre(heard))
		if lvl <= -60.0:
			return out
		var ld := ""
		for m in heard:
			if MarchingBand.lead(m) != "":
				ld = MarchingBand.lead(m)
		for m in heard:
			var ins := MarchingBand.ins_of(m)
			var files: Array = PARTS[ins]
			if ins == ld:
				out[files[1]] = LEAD_DB + lvl
			else:
				out[files[0]] = (UNDER_DB if ld != "" else QUIET_DB) + lvl
		solo_on = ld != ""
		for i in LONE_MAX:
			_lone[i] = null
		_duck_target = (DUCK_SOLO_DB if solo_on else DUCK_DB) * clampf(1.0 + lvl / 20.0, 0.0, 1.0)
		return out
	# lone musicians: each his own part, off the shared clock
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
		var pa: AudioStreamPlayer = _players["L%d/a" % i]
		var pb: AudioStreamPlayer = _players["L%d/b" % i]
		var fa: AudioStream = _stream(String(PARTS[ins2][0]))
		if pa.stream != fa:
			pa.stop()
			pa.stream = fa
			pb.stop()
			pb.stream = _stream(String(PARTS[ins2][1]))
		_off["L%d/a" % i] = offset_of(m)
		_off["L%d/b" % i] = offset_of(m)
		if MarchingBand.lead(m) != "":
			out["L%d/b" % i] = LEAD_DB + lvl2
			solo_on = true
		else:
			out["L%d/a" % i] = QUIET_DB + lvl2
	_duck_target = (DUCK_SOLO_DB if solo_on else DUCK_DB) * clampf(1.0 + best_lvl / 20.0, 0.0, 1.0)
	return out


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
	var step := FADE * delta * 10.0
	var any := false
	for f in _players:
		var p: AudioStreamPlayer = _players[f]
		if p.stream == null:
			continue
		var ph := phase(float(_off.get(f, 0.0)))
		var want := float(_target.get(f, -80.0))
		var gain := Sfx.gain(p.stream)
		var cur := p.volume_db - gain if p.playing else -80.0
		var nv := move_toward(cur, want, step)
		if nv <= -79.0:
			if p.playing:
				p.stop()
			continue
		any = true
		p.volume_db = nv + gain
		if not p.playing:
			p.play(ph)               # (a band's parts on the shared clock; a lone musician on his own offset from it)
		elif absf(p.get_playback_position() - ph) > 0.08 and absf(p.get_playback_position() - ph) < PHRASE - 0.08:
			p.seek(ph)               # (drifted: back where it should be)
	_duck = move_toward(_duck, _duck_target if any else 0.0, step * 0.5)
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


## (tests) the offset from the shared clock each player plays at now.
func offsets() -> Dictionary:
	return _off.duplicate()
