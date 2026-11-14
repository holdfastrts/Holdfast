class_name BandSound
extends Node
## THE MARCHING BAND's SOUND ENGINE (job band-v2, the owner 2026-11-13: "all of it is a cacophony"; docs/band_v2.md).
## One node per match (made by the first band that ticks: BandSound.need), its own players on the SFX bus, so the shared
## sound player (Sfx) is left alone. The rules:
##  - ONE BAND IS HEARD AT A TIME: the band nearest the middle of the screen (a band playing a SOLO first), on screen or
##    just off it, seen by your side (Sfx.heard: no music through the fog). Others are silent: never two copies of a loop.
##  - ONE CLOCK: every part is a loop of the same length (PHRASE) on one shared clock (the real time since the node was
##    made, wrapped at the phrase), so the parts always start together and in step, and the music does not restart when
##    the heard band changes (it moves on to the other band in the same bar).
##  - The ALWAYS-ON playing is quiet (QUIET_DB); a SOLO is clearly heard (LEAD_DB) with the other parts under it
##    (UNDER_DB). Further from the middle of the screen and zoomed out it is quieter; off past CUT px it is silent.
##  - The GAME MUSIC is ducked a little while a band is heard (DUCK_DB), more during a heard solo (DUCK_SOLO_DB): an
##    Amplify effect on the "Music" bus, put back to 0 when the match ends.
## THE MUSIC (job band-music, docs/band_music.md): Scotland the Brave in G, 16 bars of 4/4 at 98 beats a minute, rendered
## from real samples by tools/audio/make_band_music.py. New music: change PARTS (one file per part: the always-on loop
## and the solo loop of each instrument) and PHRASE / BPM / BARS below; every file must be exactly PHRASE s long, in one
## key and tempo. Nothing else.

## One place for the band's files (res://assets/audio/<name>.ogg): instrument -> [always-on loop, solo loop].
const PARTS := {
	"drums": ["band/drums", "band/drums_lead"],
	"fife": ["band/fife", "band/fife_lead"],
	"pipes": ["band/pipes", "band/pipes_lead"],
}
const BPM := 98.0           # the files' tempo (quarter notes a minute)
const BARS := 16            # bars of 4/4 in one loop (Scotland the Brave, Part 1 and Part 2)
const PHRASE := BARS * 4 * 60.0 / BPM   # s: every loop's length (39.18 s = 1,728,000 samples at 44.1 kHz)
const QUIET_DB := -15.0     # an instrument playing along (its +5%): quiet, under the fight
const LEAD_DB := -1.0       # the instrument leading a SOLO: clearly heard
const UNDER_DB := -19.0     # the others while one solos
const CUT := 760.0          # screen px from the middle of the screen past which a band is not heard
const NEAR := 160.0         # screen px within which it is at full level
const ZOOM_OUT := 0.85      # zoomed out further than this: quieter (a band is small on the screen)
const DUCK_DB := -2.5       # the game music while a band is heard
const DUCK_SOLO_DB := -6.0  # ... while its solo is heard
const FADE := 6.0           # dB a tenth of a second the levels move by (no clicks, no jumps)
const SWITCH := 90.0        # px: another band must be this much nearer to take over (no flip-flopping)

static var me: BandSound

var game: Game
var focus: Unit = null       # the band heard now (null none)
var t0 := 0                  # the shared clock's start (ms)
var _players := {}           # file name -> AudioStreamPlayer (looping, all started in step)
var _target := {}            # file name -> the level it is moving to (dB; -80 silent)
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
			var p := AudioStreamPlayer.new()
			p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
			if OS.has_feature("web"):
				p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
			var path := "res://assets/audio/%s.ogg" % f
			if ResourceLoader.exists(path):
				var st: AudioStream = (load(path) as AudioStream).duplicate()
				if st is AudioStreamOggVorbis:
					(st as AudioStreamOggVorbis).loop = true
				elif st is AudioStreamWAV:
					(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
					(st as AudioStreamWAV).loop_end = int(PHRASE * (st as AudioStreamWAV).mix_rate)
				p.stream = st
			p.volume_db = -80.0
			add_child(p)
			_players[f] = p
			_target[f] = -80.0


func _exit_tree() -> void:
	_set_duck(0.0)
	if me == self:
		me = null


## Where the shared clock is in the phrase now (s).
func phase() -> float:
	return fmod(float(Time.get_ticks_msec() - t0) / 1000.0, PHRASE)


## The level the heard band's parts should play at, per file (all -80 when nothing is heard). Also the music duck.
func targets() -> Dictionary:
	var out := {}
	for f in _players:
		out[f] = -80.0
	_duck_target = 0.0
	focus = pick()
	if focus == null:
		return out
	var lvl := level(focus)
	if lvl <= -60.0:
		return out
	var ld := MarchingBand.lead(focus)
	for ins in PARTS:
		if not MarchingBand.has(focus, ins):
			continue
		var files: Array = PARTS[ins]
		if ins == ld:
			out[files[1]] = LEAD_DB + lvl
		else:
			out[files[0]] = (UNDER_DB if ld != "" else QUIET_DB) + lvl
	_duck_target = (DUCK_SOLO_DB if ld != "" else DUCK_DB) * clampf(1.0 + lvl / 20.0, 0.0, 1.0)
	return out


## The band to hear: the nearest the middle of the screen, a soloing band first; the one heard now keeps it unless
## another is SWITCH px nearer.
func pick() -> Unit:
	if game == null or not is_instance_valid(game) or Sfx.hush:
		return null
	var best: Unit = null
	var bs := INF
	var cur := INF
	for u in game.units:
		if u.kind != MarchingBand.KIND or u.dead or not u.visible or u.band.get("m", []).is_empty():
			continue
		var d := screen_dist(u)
		if d > CUT or not Sfx.heard("band/drums", u.position):
			continue
		var sc := d - (400.0 if MarchingBand.lead(u) != "" else 0.0)
		if u == focus:
			cur = sc
		if sc < bs:
			bs = sc
			best = u
	if focus != null and is_instance_valid(focus) and cur < INF and best != focus and bs > cur - SWITCH:
		return focus
	return best


## Screen px from the middle of the screen to the band.
func screen_dist(u: Unit) -> float:
	var cam: Camera2D = game.camera if game.get("camera") != null else null
	if cam == null or not is_instance_valid(cam):
		return 0.0
	return u.position.distance_to(cam.get_screen_center_position()) * cam.zoom.x


## dB to add for where the band is: 0 near the middle of the screen, down to -30 at CUT; zoomed far out a little less.
func level(u: Unit) -> float:
	var d := screen_dist(u)
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
			p.play(phase())          # (in step with the shared clock: every part, every band)
		elif absf(p.get_playback_position() - phase()) > 0.08 and absf(p.get_playback_position() - phase()) < PHRASE - 0.08:
			p.seek(phase())          # (drifted: back in step)
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


## (tests) the level each file is moving to now.
func levels() -> Dictionary:
	return targets()
