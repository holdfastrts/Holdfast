#!/bin/sh
# RANKED end to end on one computer (docs/online_ranked.md): a local relay, the ladder service with the DEV sign-in, the
# match host it starts (headless, no player of its own), and two headless players with scripted commands.
#   tools/test_ranked.sh            (needs godot on the PATH or GODOT=..., and node 22.5+)
# Checks: sign-in, queue, match found, the match played through the match host, one side
# surrenders and the other wins, both ratings move, the replay is stored, a banned SteamID is refused at sign-in and at
# the queue, the cheating player's orders for units it does not own are refused / stripped and its flood dropped, and
# logged against its SteamID; no picture ever gave a player an enemy its side could not see (keyframes included).
cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-godot}
RPORT=${RPORT:-8811}
LPORT=${LPORT:-8812}
OUT=${TMPDIR:-/tmp}/holdfast_ranked_$$
mkdir -p "$OUT"
export LADDER_SECRET="test-secret-$(date +%s)-0123456789"
export LADDER_MAPS=${LADDER_MAPS:-hollowfen}
export LADDER_SERVER_ARGS="fogaudit maxsecs:400"
A=76561190000000101
B=76561190000000202
C=76561190000000303
FAIL=0
ok() { echo "CHECK SCRIPT $1 OK $2"; }
bad() { echo "CHECK SCRIPT $1 FAIL $2"; FAIL=1; }

# the ladder's own tests and the tickets across the two languages
node tools/ladder/test_ladder.mjs 2>/dev/null | grep "CHECK\|LADDER" | tee "$OUT/unit.log"
grep -q "LADDER ALL OK" "$OUT/unit.log" || FAIL=1
TK=$(cd tools/ladder && node -e 'import("./tickets.mjs").then(m=>console.log(m.makeTicket("s3cret-s3cret-s3cret","m_t","76561190000000009",1)))')
"$GODOT" --headless --script res://tools/test_ladder_ticket.gd -- secret:s3cret-s3cret-s3cret ticket:$TK 2>&1 | grep "CHECK\|TICKET" | tee "$OUT/ticket.log"
grep -q "TICKET ALL OK" "$OUT/ticket.log" || FAIL=1

node tools/relay/local_relay.mjs $RPORT > "$OUT/relay.log" 2>&1 &
RELAY=$!
node tools/ladder/ladder.mjs --dev --port $LPORT --relay ws://127.0.0.1:$RPORT --godot "$GODOT" --db "$OUT/ladder.db" \
	--out "$OUT" --max-matches 2 > "$OUT/ladder.log" 2>&1 &
LADDER=$!
sleep 2
L=http://127.0.0.1:$LPORT

# a banned player: refused at sign-in
node tools/ladder/admin.mjs --db "$OUT/ladder.db" ban $C --reason "test: map hack" --evidence "m_test" > "$OUT/admin.log" 2>&1
CODE=$(curl -s -o "$OUT/c.json" -w "%{http_code}" -X POST $L/login -d "{\"provider\":\"dev\",\"id\":\"$C\"}")
[ "$CODE" = 403 ] && grep -q banned "$OUT/c.json" && ok banned_login_refused "$(cat "$OUT/c.json")" || bad banned_login_refused "$CODE $(cat "$OUT/c.json")"
# signed in, then banned: refused at the queue
node tools/ladder/admin.mjs --db "$OUT/ladder.db" unban $C --reason "test" >> "$OUT/admin.log" 2>&1
TOK=$(curl -s -X POST $L/login -d "{\"provider\":\"dev\",\"id\":\"$C\"}" | sed -n 's/.*"token":"\([0-9a-f]*\)".*/\1/p')
node tools/ladder/admin.mjs --db "$OUT/ladder.db" ban $C --reason "test: speed hack" --days 7 >> "$OUT/admin.log" 2>&1
CODE=$(curl -s -o "$OUT/c2.json" -w "%{http_code}" -X POST -H "Authorization: Bearer $TOK" $L/queue -d '{"faction":"crown"}')
[ -n "$TOK" ] && { [ "$CODE" = 403 ] || [ "$CODE" = 401 ]; } && ok banned_queue_refused "$(cat "$OUT/c2.json")" || bad banned_queue_refused "token '$TOK' code $CODE"
# the dev sign-in is refused by a server without --dev (checked on the same code path: provider unknown is refused)
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST $L/login -d '{"provider":"steam","ticket":"00"}')
[ "$CODE" = 401 ] && ok steam_without_key_refused "$CODE" || bad steam_without_key_refused "$CODE"

# the match: Alice (crown) cheats and wins, Bruno (brood) plays fair and surrenders
"$GODOT" --headless --script res://tools/test_ranked_client.gd -- ranked_dev ladder:$L dev_sid:$A dev_name:Alice \
	faction:crown role:a cheat expect:win > "$OUT/a.log" 2>&1 &
PA=$!
sleep 1
"$GODOT" --headless --script res://tools/test_ranked_client.gd -- ranked_dev ladder:$L dev_sid:$B dev_name:Bruno \
	faction:brood role:b surrender_at:${SURRENDER_AT:-80} expect:loss > "$OUT/b.log" 2>&1 &
PB=$!
wait $PA
wait $PB
sleep 2
MATCH=$(sed -n 's/.*\[ladder\] match \(m_[a-z0-9]*\):.*/\1/p' "$OUT/ladder.log" | head -1)
[ -n "$MATCH" ] && ok match_made "$MATCH" || bad match_made "no match in the ladder's log"
[ -f "$OUT/$MATCH.hfr" ] && ok replay_stored "$(ls -la "$OUT/$MATCH.hfr" | awk '{print $5}') bytes" || bad replay_stored "no $OUT/$MATCH.hfr"
if [ -f "$OUT/$MATCH.json" ]; then
	node -e '
const r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const say = (n, ok, x) => console.log(`CHECK SCRIPT ${n} ${ok ? "OK" : "FAIL"} ${x}`);
say("result_win_for_seat_0", r.outcome === "win" && r.winner_seat === 0, `${r.outcome} seat ${r.winner_seat} (${r.end_note}) at ${r.length}s on ${r.map}`);
const a = r.audit["0"] || {};
say("foreign_order_refused_and_logged", a.impossible >= 1, JSON.stringify(a.why || {}));
say("foreign_unit_stripped_and_logged", a.foreign >= 1, `foreign ${a.foreign}`);
say("flood_dropped_and_logged", a.flood >= 1, `flood ${a.flood} of ${a.cmds} orders`);
const b = r.audit["1"] || {};
say("fair_player_clean", !b.impossible && !b.foreign && !b.flood, JSON.stringify(b));
say("fog_no_leak", r.fog && r.fog.leaks === 0 && r.fog.pictures > 0, JSON.stringify(r.fog));
say("fog_sides_met", r.fog && r.fog.enemy_rows > 0, `${r.fog && r.fog.enemy_rows} enemy rows checked`);
console.log("CPU", JSON.stringify(r.cpu));
' "$OUT/$MATCH.json" | tee "$OUT/checks.log"
	grep -q FAIL "$OUT/checks.log" && FAIL=1
else
	bad result_written "no $OUT/$MATCH.json"
fi
node tools/ladder/admin.mjs --db "$OUT/ladder.db" player $A > "$OUT/player_a.txt" 2>&1
grep -q "flagged\|impossible" "$OUT/player_a.txt" && ok report_filed_for_cheater "$(grep -c 'impossible' "$OUT/player_a.txt") report(s)" || bad report_filed_for_cheater "$(cat "$OUT/player_a.txt" | head -5)"
node tools/ladder/admin.mjs --db "$OUT/ladder.db" player $B > "$OUT/player_b.txt" 2>&1
grep -q "games 1" "$OUT/player_a.txt" && grep -q "games 1" "$OUT/player_b.txt" && ok ratings_updated "$(grep rating "$OUT/player_a.txt" | head -1) / $(grep rating "$OUT/player_b.txt" | head -1)" || bad ratings_updated "$(head -3 "$OUT/player_a.txt")"

kill $LADDER $RELAY 2>/dev/null
grep -h "CHECK\|RESULT\|ALL OK\|SOME FAILED\|TIMEOUT\|SCRIPT ERROR" "$OUT/a.log" "$OUT/b.log"
grep -h "\[match\|REPORT" "$OUT/ladder.log" | head -20
echo "(full logs in $OUT)"
if [ $FAIL = 0 ] && ! grep -q "SOME FAILED\|TIMEOUT\|SCRIPT ERROR\|CHECK.*FAIL" "$OUT/a.log" "$OUT/b.log" "$OUT/ladder.log"; then echo "RANKED ALL OK"; else echo "RANKED SOME FAILED"; exit 1; fi
