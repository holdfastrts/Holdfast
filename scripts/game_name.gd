class_name GameName
## The game's shown name, from ONE place: project.godot application/config/name (also the window
## title, the web page title and loading page through $GODOT_PROJECT_NAME in tools/web/shell.html,
## and the Android app name, as export_presets.cfg leaves package/name empty). A rename is that one line
## (plus README.md). The user data folder does NOT follow it: config/custom_user_dir_name stays
## "Pocket RTS" so settings, replays and saves carry over.
##
## The match log's first line is "<name> vX.Y.Z match log"; old logs start "Holdfast vX.Y.Z match log"
## (the name until 0.14.102) or "Working Title for RTS vX.Y.Z match log" (until 0.33.29): is_log_header() accepts all.

const FALLBACK := "Triumviwar"
## The subtitle (owner, 2026-11-13: "Triumviwar: Is All Lost?"), shown with the name on the big headings only (the main
## menu, the device page); the window, the app, logs and replays use the short name.
const SUBTITLE := "Is All Lost?"
## Earlier names, for reading old match logs and replays.
const OLD_NAMES := ["Working Title for RTS", "Holdfast"]


static func title() -> String:
	return String(ProjectSettings.get_setting("application/config/name", FALLBACK))


## The name for big headings (the main menu, the device page).
static func heading() -> String:
	return (title() + ": " + SUBTITLE).to_upper()


## True for the first line of a match log, under the current name or an old one.
static func is_log_header(line: String) -> bool:
	if not " match log" in line:
		return false
	for n in [title()] + OLD_NAMES:
		if line.begins_with(String(n) + " v"):
			return true
	return false


## The font size for a heading of the name: `biggest` for a short name ("HOLDFAST"), smaller for a
## long one so it clears the language flags on the main menu.
static func heading_size(biggest: int) -> int:
	return clampi(int(biggest * 13.0 / maxf(1.0, heading().length())), biggest * 5 / 9, biggest)
