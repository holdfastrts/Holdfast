class_name Settings
## Player settings kept in user://settings.cfg: which device the game is played on
## ("pc" or "mobile"; "" = not asked yet) and, on mobile, what a one-finger drag does.

const PATH := "user://settings.cfg"

static var device := ""
static var drag_mode := "box"        # mobile: "box" = drag selects, "pan" = drag moves the view
static var fullscreen := true         # web on a phone: play full screen (Esc no longer leaves it in Chrome/Edge)
static var window_full := false       # computer: FULL SCREEN (Settings > DISPLAY, F11, Alt+Enter): the window fills the screen (apply_window)
static var ui_size := 0               # 0 = automatic, else a percentage (100-200)
static var grid_keys := false         # computer: command card keys by position (QWER / ASDF / ZXCV) instead of by name
static var tooltips := true           # hover tooltips (computer) and the "?" help button (phone)
static var build_grid := true         # show the planning grid while placing a building
static var area_marks := true         # area attacks lay their shape on the ground where they strike (GroundMarks)
static var powder_smoke := -1         # black powder smoke (PowderSmoke): -1 = not chosen (THICK for now), 0 off, 1 light, 2 full, 3 thick
static var expansion_spots := true    # the best expansion spots tinted on the ground (ExpansionSpots; Crown and Clockwork)
static var health_bars := 0           # BARS: 0 = ONLY WHEN NOT FULL (the default: health when hurt, charge and powder when not full), 1 = ALWAYS (every bar)
static var band_marks := 1            # BAND BUFF MARKS: 0 ALWAYS, 1 SELECTED (selected units, the one under the cursor, everyone in a ring during a solo), 2 OFF (MarchingBand.draw_marks)
static var charge_bars := true        # SHOW CHARGE BARS: a thin charge bar over own Clockwork units not fully wound (Unit._draw_unit)
static var gear_turn := true          # TURNING GEARS (experiment, on for now): a Clockwork ring's band carries units round (GearTurn); from the next match
static var ground_system := false     # THE GROUND SYSTEM (experiment, off by default): soil and brass on the map round each hall (GroundLayer); from the next match
static var ground_alpha := 0.35       # how strongly the ground layer is drawn while placing any building (0.1 to 1)
static var mini_alpha := 0.6          # how solid the minimap is drawn (0.2 to 1)
static var relay_url := "wss://pocketrts-relay.salgarellius-rts.workers.dev"   # online: the relay (tools/relay/README.md)
static var ladder_url := ""           # RANKED: the ladder service (tools/ladder/ladder.mjs); "" = not set up (docs/online_ranked.md)
static var ranked_dev_id := ""        # RANKED with the DEV sign-in (a test server only): a made-up SteamID64, kept
static var ranked_faction := "random" # RANKED: the faction last queued with
static var language := "en"           # "en", "pt" or "es" (Loc)
static var cw_lab := false            # the Clockwork roster prototype in every Clockwork match (docs/clockwork_units_prototype.md)
static var replays_keep := 30         # replays kept (the newest; KEEP ones are never deleted)
static var replay_rec := ""           # REPLAY RECORDING: "mixed", "full", "light", "off"; "" = not chosen (replay_mode: LIGHT on a phone, FULL elsewhere)
static var narrator := true           # SPECTATOR NARRATOR: the AI STORY read out loud while watching computers (Narrator; N mutes)
static var narrator_volume := 80      # NARRATOR VOLUME (0-100, the system voice's own volume)
static var narrator_rate := 1.1       # NARRATOR SPEED (0.5-2: 1 is the voice's normal pace)
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		device = cfg.get_value("input", "device", "")
		drag_mode = cfg.get_value("input", "drag_mode", "box")
		ui_size = cfg.get_value("input", "ui_size", 0)
		fullscreen = cfg.get_value("input", "fullscreen", true)
		window_full = bool(cfg.get_value("display", "fullscreen", false))
		grid_keys = cfg.get_value("input", "grid_keys", false)
		tooltips = cfg.get_value("input", "tooltips", true)
		build_grid = cfg.get_value("input", "build_grid", true)
		area_marks = bool(cfg.get_value("ui", "area_marks", true))
		powder_smoke = clampi(int(cfg.get_value("ui", "powder_smoke", -1)), -1, 3)
		expansion_spots = bool(cfg.get_value("ui", "expansion_spots", true))
		charge_bars = bool(cfg.get_value("ui", "charge_bars", true))
		health_bars = clampi(int(cfg.get_value("ui", "health_bars", 0)), 0, 1)
		band_marks = clampi(int(cfg.get_value("ui", "band_marks", 1)), 0, 2)
		gear_turn = bool(cfg.get_value("ui", "gear_turn", true))
		ground_system = bool(cfg.get_value("ui", "ground_system", false))
		ground_alpha = clampf(float(cfg.get_value("ui", "ground_alpha", 0.35)), 0.1, 1.0)
		mini_alpha = clampf(float(cfg.get_value("input", "mini_alpha", 0.6)), 0.2, 1.0)
		relay_url = String(cfg.get_value("online", "relay_url", relay_url))
		if relay_url.contains("YOURNAME") or relay_url.strip_edges() == "":
			relay_url = "wss://pocketrts-relay.salgarellius-rts.workers.dev"     # (an old placeholder saved earlier)
		ladder_url = String(cfg.get_value("online", "ladder_url", ladder_url))
		ranked_dev_id = String(cfg.get_value("online", "ranked_dev_id", ""))
		ranked_faction = String(cfg.get_value("online", "ranked_faction", "random"))
		language = str(cfg.get_value("ui", "language", "en"))
		cw_lab = bool(cfg.get_value("ui", "cw_lab", false))
		replays_keep = clampi(int(cfg.get_value("ui", "replays_keep", 30)), 5, 200)
		replay_rec = String(cfg.get_value("ui", "replay_rec", ""))
		if not REPLAY_MODES.has(replay_rec):
			replay_rec = ""
		narrator = bool(cfg.get_value("ui", "narrator", true))
		narrator_volume = clampi(int(cfg.get_value("ui", "narrator_volume", 80)), 0, 100)
		narrator_rate = clampf(float(cfg.get_value("ui", "narrator_rate", 1.1)), 0.5, 2.0)
	Loc.set_lang(language)
	apply()


static func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)          # keep the other sections (audio)
	cfg.set_value("input", "device", device)
	cfg.set_value("input", "drag_mode", drag_mode)
	cfg.set_value("input", "ui_size", ui_size)
	cfg.set_value("input", "fullscreen", fullscreen)
	cfg.set_value("display", "fullscreen", window_full)
	cfg.set_value("input", "grid_keys", grid_keys)
	cfg.set_value("input", "tooltips", tooltips)
	cfg.set_value("input", "build_grid", build_grid)
	cfg.set_value("ui", "area_marks", area_marks)
	cfg.set_value("ui", "powder_smoke", powder_smoke)
	cfg.set_value("ui", "expansion_spots", expansion_spots)
	cfg.set_value("ui", "charge_bars", charge_bars)
	cfg.set_value("ui", "health_bars", health_bars)
	cfg.set_value("ui", "band_marks", band_marks)
	cfg.set_value("ui", "gear_turn", gear_turn)
	cfg.set_value("ui", "ground_system", ground_system)
	cfg.set_value("ui", "ground_alpha", ground_alpha)
	cfg.set_value("input", "mini_alpha", mini_alpha)
	cfg.set_value("online", "relay_url", relay_url)
	cfg.set_value("online", "ladder_url", ladder_url)
	cfg.set_value("online", "ranked_dev_id", ranked_dev_id)
	cfg.set_value("online", "ranked_faction", ranked_faction)
	cfg.set_value("ui", "language", language)
	cfg.set_value("ui", "cw_lab", cw_lab)
	cfg.set_value("ui", "replays_keep", replays_keep)
	cfg.set_value("ui", "replay_rec", replay_rec)
	cfg.set_value("ui", "narrator", narrator)
	cfg.set_value("ui", "narrator_volume", narrator_volume)
	cfg.set_value("ui", "narrator_rate", narrator_rate)
	cfg.save(PATH)


static func set_device(d: String) -> void:
	device = d
	apply()
	save_all()


## How big the in-game interface is drawn: phones get it 50% bigger unless set otherwise.
static func ui_scale_now() -> float:
	if ui_size > 0:
		return ui_size / 100.0
	return 1.0 if pc() else 1.5


## The powder smoke drawn now: as the player set it, or, never chosen, THICK on every platform
## (the owner's experiment, 2026-10-27: the smoke over everything, "a bit annoying"; before it:
## full on a computer, light on a phone or in a browser).
const POWDER_SMOKE_DEFAULT := 3
static func powder_smoke_level() -> int:
	if powder_smoke >= 0:
		return powder_smoke
	return POWDER_SMOKE_DEFAULT


## REPLAY RECORDING (docs/replays.md "Lighter recording"): how a match is recorded. FULL: 5 pictures a second (the
## recorder's own rate), LIGHT: 2 a second (the viewer glides between them), OFF: no replay of a skirmish, a campaign
## mission or a watched match (online still records, at LIGHT: the friends get the host's replay). MIXED (0.29.5,
## docs/replay_mixed.md): the commands and a keyframe every 10 s, the replay plays the match again from them; the
## default on a phone (LIGHT was before), where recording pictures costs the most.
const REPLAY_MODES := ["mixed", "full", "light", "off"]
static func replay_mode() -> String:
	if REPLAY_MODES.has(replay_rec):
		return replay_rec
	return "mixed" if phone_device() else "full"


## The game runs on a phone or tablet (the Android app, a mobile export), not a phone's browser (the web keeps FULL).
static func phone_device() -> bool:
	return OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS"


## Settings > OTHER > RESET SETTINGS: every choice back to how it starts, except the device,
## the language, the online relay and the sound (it has its own mute buttons and bars).
static func reset() -> void:
	ui_size = 0
	grid_keys = false
	tooltips = true
	build_grid = true
	area_marks = true
	powder_smoke = -1
	expansion_spots = true
	charge_bars = true
	health_bars = 0
	band_marks = 1
	gear_turn = true
	ground_system = false
	ground_alpha = 0.35
	mini_alpha = 0.6
	cw_lab = false
	replays_keep = 30
	replay_rec = ""
	narrator = true
	narrator_volume = 80
	narrator_rate = 1.1
	drag_mode = "box"
	save_all()


## The game can switch its window to full screen here (the desktop program, or a browser on a
## computer, where it has to come from a click). Not the Android app (always full screen).
static func can_window_full() -> bool:
	return OS.has_feature("pc") or (OS.has_feature("web") and pc())


## Is the window full screen now? (The browser's Esc can leave it without the game knowing.)
static func window_is_full() -> bool:
	if not can_window_full() or DisplayServer.get_name() == "headless":
		return window_full
	var now := DisplayServer.window_get_mode()
	return now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Puts the window in full screen or a window as window_full says (the desktop program at start,
## and the FULL SCREEN toggle; on the web only from inside a click).
static func apply_window() -> void:
	if not can_window_full() or DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if window_full else DisplayServer.WINDOW_MODE_WINDOWED
	var now := DisplayServer.window_get_mode()
	var is_full := now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_full != window_full:
		DisplayServer.window_set_mode(want)


static func pc() -> bool:
	return device == "pc"


## On a computer the mouse is a mouse; on a phone touches stay touches (and a mouse,
## if any, pretends to be a finger so the phone controls can be tried on a desktop).
static func apply() -> void:
	Input.emulate_touch_from_mouse = not pc()


## The game language ("en", "pt", "es"): switches the text at once and is remembered.
static func set_language(code: String) -> void:
	language = code if Loc.LANGS.has(code) else "en"
	Loc.set_lang(language)
	save_all()
