class_name Identity
extends RefCounted
## Who the player is, for RANKED play (docs/online_ranked.md "Identity"). The account is the SteamID64:
## - "steam": the Steam build, with GodotSteam (the GDExtension registers the singleton "Steam"; not in this repo, see
##   the doc's "Adding GodotSteam"). The client asks Steam for a Web API ticket (getAuthTicketForWebApi(IDENTITY)) and
##   sends it to the ladder, which asks Steam who it belongs to (ISteamUserAuth/AuthenticateUserTicket). The client
##   never says its own SteamID: the server learns it from Steam.
## - "dev": a test server's DEV sign-in (the ladder runs with --dev): a made-up SteamID64, for tests and local play.
##   Shown only with the command-line switch ranked_dev (or HOLDFAST_RANKED_DEV=1), never in a normal build.
## - "": no identity: the RANKED button stays hidden (Android, web: the friendly online with room codes as before).
## Every Steam call is guarded: a build without GodotSteam runs exactly as before.

const IDENTITY := "triumviwar-ladder"      # must match the ladder's STEAM_IDENTITY


static func steam() -> Object:
	return Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null


static func dev_enabled() -> bool:
	return OS.get_cmdline_user_args().has("ranked_dev") or OS.get_environment("HOLDFAST_RANKED_DEV") == "1"


static func provider() -> String:
	var st := steam()
	if st != null and st.has_method("getAuthTicketForWebApi") and (not st.has_method("loggedOn") or bool(st.call("loggedOn"))):
		return "steam"
	if dev_enabled():
		return "dev"
	return ""


static func available() -> bool:
	return provider() != ""


## The made-up SteamID64 of the DEV sign-in (kept in the settings; a test passes dev_sid:<id> on the command line).
static func dev_id() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("dev_sid:"):
			return a.substr(8)
	if Settings.ranked_dev_id == "":
		var r := RandomNumberGenerator.new()
		r.randomize()
		Settings.ranked_dev_id = "76561190%09d" % r.randi_range(0, 999999999)
		Settings.save_all()
	return Settings.ranked_dev_id


static func display_name() -> String:
	var st := steam()
	if st != null and st.has_method("getPersonaName"):
		return String(st.call("getPersonaName"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("dev_name:"):
			return a.substr(9)
	return "Dev " + dev_id().right(4)


## The sign-in to send to the ladder's /login, handed to `done` ({} if it failed, with "error").
## Steam answers a ticket request later (its signal get_ticket_for_web_api), so this is asynchronous for both.
static func login_body(done: Callable) -> void:
	match provider():
		"dev":
			done.call({"provider": "dev", "id": dev_id(), "name": display_name()})
		"steam":
			var st := steam()
			if not st.has_signal("get_ticket_for_web_api"):
				done.call({"error": "this GodotSteam has no Web API tickets (needs GodotSteam 4.x for Steamworks 1.57+)"})
				return
			var answered := [false]
			var cb := func(_handle, result, _size, buffer) -> void:
				if answered[0]:
					return
				answered[0] = true
				if int(result) != 1:          # (k_EResultOK)
					done.call({"error": "Steam gave no ticket (result %d)" % int(result)})
					return
				done.call({"provider": "steam", "ticket": ticket_hex(buffer), "name": display_name()})
			st.connect("get_ticket_for_web_api", cb, CONNECT_ONE_SHOT)
			st.call("getAuthTicketForWebApi", IDENTITY)
		_:
			done.call({"error": "no ranked identity on this device"})


## Steam's ticket buffer (an Array of bytes or a PackedByteArray) as the hex the Web API wants.
static func ticket_hex(buffer) -> String:
	var b := PackedByteArray()
	if buffer is PackedByteArray:
		b = buffer
	elif buffer is Array:
		for x in buffer:
			b.append(int(x))
	return b.hex_encode()
