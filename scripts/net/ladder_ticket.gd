class_name LadderTicket
extends RefCounted
## A seat in a ranked match, signed by the ladder service (tools/ladder/ladder.mjs makeTicket): the match host checks
## it before it seats a guest (NetLobby._ranked_hi). Text: base64url(JSON {"m": match id, "sid": SteamID64, "seat",
## "exp": unix seconds}) + "." + hex HMAC-SHA256(secret, the base64 part). The secret is shared by the ladder and the
## match hosts only (never a client's).


static func _b64url_decode(s: String) -> PackedByteArray:
	var t := s.replace("-", "+").replace("_", "/")
	while t.length() % 4 != 0:
		t += "="
	return Marshalls.base64_to_raw(t)


static func signature(payload: String, secret: String) -> String:
	var c := Crypto.new()
	return c.hmac_digest(HashingContext.HASH_SHA256, secret.to_utf8_buffer(), payload.to_utf8_buffer()).hex_encode()


## For tests and tools: a ticket as the ladder makes it.
static func make(secret: String, match_id: String, sid: String, seat: int, ttl := 600) -> String:
	var body := JSON.stringify({"m": match_id, "sid": sid, "seat": seat, "exp": int(Time.get_unix_time_from_system()) + ttl})
	var b := Marshalls.raw_to_base64(body.to_utf8_buffer()).replace("+", "-").replace("/", "_").rstrip("=")
	return b + "." + signature(b, secret)


## {"sid", "seat", "m"} if the ticket is good for this match, else {"error": why}.
static func check(tk: String, secret: String, match_id: String) -> Dictionary:
	if secret == "":
		return {"error": "the host has no secret"}
	var parts := tk.split(".")
	if parts.size() != 2:
		return {"error": "no ticket"}
	var want: String = signature(parts[0], secret)
	if not _same(want, parts[1].to_lower()):
		return {"error": "a bad signature"}
	var d = JSON.parse_string(_b64url_decode(parts[0]).get_string_from_utf8())
	if not (d is Dictionary) or not d.has("m") or not d.has("sid") or not d.has("seat"):
		return {"error": "a broken ticket"}
	if String(d["m"]) != match_id:
		return {"error": "a ticket for another match"}
	if float(d.get("exp", 0)) < Time.get_unix_time_from_system():
		return {"error": "an expired ticket"}
	return {"sid": String(d["sid"]), "seat": int(d["seat"]), "m": String(d["m"])}


## A comparison that takes as long whatever the first difference (no timing hints about the signature).
static func _same(a: String, b: String) -> bool:
	if a.length() != b.length():
		return false
	var diff := 0
	for i in a.length():
		diff |= a.unicode_at(i) ^ b.unicode_at(i)
	return diff == 0
