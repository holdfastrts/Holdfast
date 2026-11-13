extends SceneTree
## Ranked tickets across the two languages (scripts/net/ladder_ticket.gd v tools/ladder/tickets.mjs):
##   godot --headless --script res://tools/test_ladder_ticket.gd -- secret:<s> ticket:<made by node for match m_t, seat 1>
## (tools/test_ranked.sh runs it.) A ticket from the ladder is accepted; a doctored, an expired, another match's and an
## unsigned one are refused.
var fails := 0


func check(name: String, ok: bool, extra := "") -> void:
	print("CHECK TICKET %s %s %s" % [name, "OK" if ok else "FAIL", extra])
	if not ok:
		fails += 1


func _initialize() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var i := s.find(":")
		if i > 0:
			a[s.substr(0, i)] = s.substr(i + 1)
	var sec := String(a.get("secret", "s3cret-s3cret-s3cret"))
	var tk := String(a.get("ticket", ""))
	if tk != "":
		var r := LadderTicket.check(tk, sec, "m_t")
		check("node_ticket_accepted", not r.has("error") and int(r.get("seat", -1)) == 1, str(r))
		var parts := tk.split(".")
		var body := parts[0]
		var flipped := body.substr(0, body.length() - 2) + ("A" if body[body.length() - 2] != "A" else "B") + body.right(1)
		check("doctored_body_refused", LadderTicket.check(flipped + "." + parts[1], sec, "m_t").has("error"))
		check("wrong_secret_refused", LadderTicket.check(tk, sec + "x", "m_t").has("error"))
		check("other_match_refused", LadderTicket.check(tk, sec, "m_other").has("error"))
	check("own_ticket_accepted", not LadderTicket.check(LadderTicket.make(sec, "m_t", "76561190000000001", 0), sec, "m_t").has("error"))
	check("expired_refused", String(LadderTicket.check(LadderTicket.make(sec, "m_t", "76561190000000001", 0, -10), sec, "m_t").get("error", "")).contains("expired"))
	check("no_signature_refused", LadderTicket.check("abc", sec, "m_t").has("error"))
	print("TICKET %s" % ("ALL OK" if fails == 0 else "SOME FAILED"))
	quit(0 if fails == 0 else 1)
