class_name LadderClient
extends Node
## The game's side of the ladder service (tools/ladder/ladder.mjs, docs/online_ranked.md): sign in, the queue, the
## match found, results and the leaderboard, over plain HTTPS (JSON). One request at a time per call; each answer goes
## to its callback as a Dictionary (an error as {"error": text, "code": http code}).

var base := ""
var token := ""
var me := {}                     # the last profile the ladder sent (rating, games, placement, rank, season)


static func make(parent: Node, url: String) -> LadderClient:
	var c := LadderClient.new()
	c.base = url.strip_edges().rstrip("/")
	c.name = "LadderClient"
	parent.add_child(c)
	return c


func call_api(method: int, path: String, body, done: Callable) -> void:
	var h := HTTPRequest.new()
	h.timeout = 12.0
	add_child(h)
	var headers := ["Content-Type: application/json"]
	if token != "":
		headers.append("Authorization: Bearer " + token)
	h.request_completed.connect(func(res: int, code: int, _hd: PackedStringArray, raw: PackedByteArray) -> void:
		h.queue_free()
		var d = JSON.parse_string(raw.get_string_from_utf8()) if raw.size() > 0 else {}
		if res != HTTPRequest.RESULT_SUCCESS:
			done.call({"error": "Can't reach the ranked server.", "code": 0})
			return
		if not (d is Dictionary):
			d = {}
		if code >= 400:
			d["code"] = code
			if not d.has("error"):
				d["error"] = "The ranked server said no (%d)." % code
		done.call(d))
	var err := h.request(base + path, headers, method, "" if body == null else JSON.stringify(body))
	if err != OK:
		h.queue_free()
		done.call({"error": "Can't reach the ranked server.", "code": 0})


func login(done: Callable) -> void:
	Identity.login_body(func(b: Dictionary) -> void:
		if b.has("error"):
			done.call(b)
			return
		call_api(HTTPClient.METHOD_POST, "/login", b, func(d: Dictionary) -> void:
			if d.has("token"):
				token = String(d["token"])
				me = d
			done.call(d)))


func profile(done: Callable) -> void:
	call_api(HTTPClient.METHOD_GET, "/me", null, func(d: Dictionary) -> void:
		if not d.has("error"):
			me = d
		done.call(d))


func queue(faction: String, region: String, done: Callable) -> void:
	call_api(HTTPClient.METHOD_POST, "/queue", {"faction": faction, "region": region,
		"version": String(ProjectSettings.get_setting("application/config/version", "dev"))}, done)


func poll(done: Callable) -> void:
	call_api(HTTPClient.METHOD_GET, "/queue", null, done)


func cancel(done: Callable) -> void:
	call_api(HTTPClient.METHOD_DELETE, "/queue", null, done)


func match_result(id: String, done: Callable) -> void:
	call_api(HTTPClient.METHOD_GET, "/match/" + id, null, done)


func leaderboard(faction: String, done: Callable) -> void:
	call_api(HTTPClient.METHOD_GET, "/leaderboard" + ("?faction=" + faction if faction != "" else ""), null, done)
