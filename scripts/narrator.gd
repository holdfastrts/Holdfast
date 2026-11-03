class_name Narrator
extends Node
## THE SPECTATOR'S NARRATOR (0.27.0, docs/spectator.md): reads the AI STORY's important lines out loud with the system's
## text-to-speech (DisplayServer.tts_*: Windows, Android and browsers with voices; project setting
## audio/general/text_to_speech). One line at a time, never two over each other; when lines pile up the older ones are
## dropped (the newest and the biggest kept) and a line spoken too long is cut for a big new one. Settings: SPECTATOR
## NARRATOR (on/off, the N key and the speaker on the AI STORY panel), NARRATOR VOLUME, NARRATOR SPEED.
## No voice for the game's language: text only (`available` false, the panel says so).
## `fake` (tests, a machine without voices): speaking is pretended, a line lasts FAKE_CPS characters a second.

const PILE := 2               # lines waiting at most: older ones go
const CUT_AFTER := 9.0        # s: a line spoken this long is cut when a big one (priority 3) waits
const FAKE_CPS := 16.0
const LOOK_AGAIN := 3.0       # s between looks for a voice (a browser lists its voices late)

var queue: Array = []         # [text, prio, added]
var speaking := ""            # the line being spoken ("" none)
var spoken_at := 0.0          # (Time) when it began
var available := false        # a voice for the language exists
var voice := ""
var fake := false
var history: Array = []       # [start, end, text] each line spoken (tests: none overlap)
var dropped := 0
var _fake_end := 0.0
var _voice_lang := ""
var _look_t := 0.0
var _tries := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # (a pause doesn't cut a sentence; the queue waits with the game)
	_find_voice()


func _exit_tree() -> void:
	stop()


static func tts_on() -> bool:
	return bool(ProjectSettings.get_setting("audio/general/text_to_speech", false)) and DisplayServer.get_name() != "headless" \
		and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) and not _no_engine


## (a system without a speech engine at all, e.g. Linux without speech-dispatcher: asked once, never again)
static var _no_engine := false


## A voice for the game's language (pt: Brazilian first).
func _find_voice() -> void:
	_voice_lang = Loc.lang
	available = fake
	voice = ""
	if fake or not tts_on():
		return
	var want: Array = {"en": ["en_US", "en_GB", "en"], "pt": ["pt_BR", "pt"], "es": ["es_ES", "es_MX", "es"]}.get(Loc.lang, ["en"])
	for code in want:
		var vs := DisplayServer.tts_get_voices_for_language(code)
		if not vs.is_empty():
			voice = vs[0]
			available = true
			return
	# (some systems name languages differently: any voice whose language starts with the code)
	var all := DisplayServer.tts_get_voices()
	for v in all:
		if String(v.get("language", "")).to_lower().begins_with(Loc.lang):
			voice = String(v.get("id", ""))
			available = voice != ""
			return
	if all.is_empty() and not OS.has_feature("web"):
		_no_engine = true          # (no voices at all, and only a browser lists them late)


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Queue a line (priority 3 big, 2 telling). Muted or without a voice it is not kept.
func say(text: String, prio := 3) -> void:
	if not Settings.narrator or not available:
		return
	queue.append([_spoken_form(text), prio, now()])
	if queue.size() > PILE:
		# the pile: keep the biggest, the newest first among equals
		var keep := queue.duplicate()
		keep.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and float(a[2]) > float(b[2])))
		keep = keep.slice(0, PILE)
		dropped += queue.size() - keep.size()
		queue = queue.filter(func(x: Array) -> bool: return keep.has(x))
	_next()


## "P1" said as "Player 1" (in the language).
static func _spoken_form(text: String) -> String:
	var rx := RegEx.new()
	rx.compile("\\bP(\\d)\\b")
	var out := text
	for m in rx.search_all(text):
		out = out.replace(m.get_string(0), Loc.t("Player %d") % int(m.get_string(1)))
	return out


func is_speaking() -> bool:
	if speaking == "":
		return false
	if fake:
		return now() < _fake_end
	return DisplayServer.tts_is_speaking()


func _process(delta: float) -> void:
	if _voice_lang != Loc.lang:
		_find_voice()
	if not available and not fake and _tries < 10 and tts_on():
		_look_t -= delta
		if _look_t <= 0.0:
			_look_t = LOOK_AGAIN
			_tries += 1
			_find_voice()
	if speaking != "" and not is_speaking():
		_done()
	if speaking != "" and not queue.is_empty() and now() - spoken_at > CUT_AFTER and queue.any(func(x: Array) -> bool: return int(x[1]) >= 3):
		_cut()
	_next()


func _next() -> void:
	if speaking != "" and not is_speaking():
		_done()             # (the last line ended since the last frame)
	if speaking != "" or queue.is_empty() or not Settings.narrator:
		return
	var it: Array = queue.pop_front()
	speaking = String(it[0])
	spoken_at = now()
	history.append([spoken_at, -1.0, speaking])
	if fake:
		_fake_end = spoken_at + maxf(0.6, speaking.length() / FAKE_CPS * 1.0 / maxf(Settings.narrator_rate, 0.25))
	else:
		DisplayServer.tts_speak(speaking, voice, clampi(Settings.narrator_volume, 0, 100), 1.0, clampf(Settings.narrator_rate, 0.5, 2.0))


func _done() -> void:
	if not history.is_empty() and float(history.back()[1]) < 0.0:
		history.back()[1] = now()
	speaking = ""


func _cut() -> void:
	if not fake:
		DisplayServer.tts_stop()
	_fake_end = 0.0
	_done()


## Silence now: what is said stops and the queue is emptied (mute, the end of the match).
func stop() -> void:
	queue.clear()
	if speaking != "":
		_cut()
	elif not fake and available and tts_on():
		DisplayServer.tts_stop()


## The mute button and the N key: the narrator on or off (kept in Settings).
func toggle() -> bool:
	Settings.narrator = not Settings.narrator
	Settings.save_all()
	if not Settings.narrator:
		stop()
	return Settings.narrator
