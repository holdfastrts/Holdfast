// The ladder's own tests, no network, no game:  node tools/ladder/test_ladder.mjs
// Glicko-2 against Glickman's worked example, the Steam calls against the fixtures (recorded answer shapes), tickets,
// and the store: a match result moves both ratings, files the cheat report, and a ban is in force until lifted.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { rate, carryOver } from "./glicko2.mjs";
import { verifyTicket, steamGameBan } from "./steam.mjs";
import { makeTicket, hmacHex } from "./tickets.mjs";
import { openStore, PLACEMENT } from "./store.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
let fails = 0;
const check = (name, ok, extra = "") => { console.log(`CHECK ${name} ${ok ? "OK" : "FAIL"} ${extra}`); if (!ok) fails++; };
const fx = (f) => JSON.parse(fs.readFileSync(path.join(HERE, "fixtures", f), "utf8"));
const fakeFetch = (routes, seen = []) => async (url, init) => {
  seen.push({ url, init });
  for (const [part, file] of routes) if (url.includes(part)) return { ok: true, status: 200, json: async () => fx(file) };
  return { ok: false, status: 404, json: async () => ({}) };
};

// ---- Glicko-2: the paper's example (r 1500 rd 200 vs 1400/30 win, 1550/100 loss, 1700/300 loss)
const g = rate({ r: 1500, rd: 200, vol: 0.06 }, [{ r: 1400, rd: 30, s: 1 }, { r: 1550, rd: 100, s: 0 }, { r: 1700, rd: 300, s: 0 }]);
check("glicko2_paper_example", Math.abs(g.r - 1464.06) < 0.1 && Math.abs(g.rd - 151.52) < 0.1 && Math.abs(g.vol - 0.05999) < 0.0001, `${g.r.toFixed(2)} ${g.rd.toFixed(2)} ${g.vol.toFixed(5)}`);
const w = rate({ r: 1500, rd: 350, vol: 0.06 }, [{ r: 1500, rd: 350, s: 1 }]);
check("glicko2_new_player_win_moves_a_lot", w.r > 1600 && w.rd < 350, `${w.r.toFixed(0)}`);
const co = carryOver({ r: 1900, rd: 60, vol: 0.06 });
check("season_carry_over_halfway", co.r === 1700 && co.rd > 60, JSON.stringify(co));

// ---- Steam, with recorded answers
const cfg = { key: "K", appid: "4000000", identity: "triumviwar-ladder" };
const seen = [];
const ok = await verifyTicket(cfg, "14000000a1b2c3d4e5f60708", fakeFetch([["AuthenticateUserTicket", "auth_ok.json"], ["CheckAppOwnership", "owns_yes.json"]], seen));
check("steam_ticket_ok", ok.sid === "76561198000000001", JSON.stringify(ok));
check("steam_ticket_sends_identity_and_key", seen[0].url.includes("identity=triumviwar-ladder") && seen[0].url.includes("key=K") && seen[0].url.includes("partner.steam-api.com"), seen[0].url);
const refused = async (routes, want) => { try { await verifyTicket(cfg, "14000000a1b2c3d4e5f60708", fakeFetch(routes)); return "accepted"; } catch (e) { return String(e.message).includes(want) ? "ok" : e.message; } };
check("steam_bad_ticket_refused", (await refused([["AuthenticateUserTicket", "auth_error.json"]], "refused")) === "ok");
check("steam_publisher_banned_refused", (await refused([["AuthenticateUserTicket", "auth_publisherbanned.json"]], "banned")) === "ok");
check("steam_no_game_refused", (await refused([["AuthenticateUserTicket", "auth_ok.json"], ["CheckAppOwnership", "owns_no.json"]], "does not own")) === "ok");
check("steam_not_set_up_refused", await verifyTicket({ key: "", appid: "" }, "00").then(() => false, () => true));
check("steam_garbage_ticket_refused", await verifyTicket(cfg, "not hex!", fakeFetch([])).then(() => false, () => true));
const bseen = [];
const ban = await steamGameBan(cfg, "76561198000000001", "map hack", 365 * 86400, true, fakeFetch([["ReportPlayerCheating", "report_ok.json"], ["RequestPlayerGameBan", "ban_ok.json"]], bseen));
const banBody = new URLSearchParams(bseen[1].init.body);
check("steam_game_ban_report_then_ban", ban.reportid === "1234567890123" && bseen[1].url.includes("RequestPlayerGameBan") && banBody.get("reportid") === "1234567890123" && banBody.get("delayban") === "true" && banBody.get("duration") === String(365 * 86400), bseen.map((s) => s.url.split("/")[4]).join(" -> "));

// ---- tickets (the GDScript side, LadderTicket, is checked by tools/test_ladder_ticket.gd with a ticket made here)
const t = makeTicket("s3cret-s3cret-s3cret", "m_1", "76561190000000001", 1);
const [b64, sig] = t.split(".");
check("ticket_signed", sig === hmacHex("s3cret-s3cret-s3cret", b64));
check("ticket_body", JSON.parse(Buffer.from(b64.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString()).seat === 1);

// ---- the store
const dbp = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "ladder-")), "t.db");
const st = openStore(dbp);
const A = "76561190000000001", B = "76561190000000002";
st.touchPlayer(A, "Alice", "dev"); st.touchPlayer(B, "Bruno", "dev");
st.newMatch({ id: "m_x", room: "ROOMROOMRO", map: "hollowfen", seed: 1, region: "eu", sid0: A, sid1: B, f0: "crown", f1: "brood" });
const res = st.finish({ match: "m_x", outcome: "win", winner_seat: 0, length: 300, replay: "/x/m_x.hfr", map: "hollowfen",
  players: [{ faction: "crown" }, { faction: "brood" }], audit: { 0: { cmds: 90, impossible: 6, foreign: 1, flood: 30, why: { "not yours": 6 } } } });
check("result_moves_ratings", res.d0 > 0 && res.d1 < 0, JSON.stringify(res));
check("result_files_flagged_report", res.flagged.includes(A) && st.reports().length === 1);
check("result_only_once", st.finish({ match: "m_x", outcome: "win", winner_seat: 1 }).error !== undefined);
check("placement_not_on_board", st.leaderboard().length === 0 && st.rank(A) === null);
for (let i = 0; i < PLACEMENT; i++) {
  st.newMatch({ id: "m_" + i, room: "R", map: "m", seed: 1, region: "eu", sid0: A, sid1: B, f0: "crown", f1: "brood" });
  st.finish({ match: "m_" + i, outcome: "win", winner_seat: 0, players: [{ faction: "crown" }, { faction: "brood" }] });
}
const lb = st.leaderboard();
check("leaderboard_after_placement", lb.length === 2 && lb[0].sid === A && lb[0].faction === "crown" && st.rank(A) === 1, JSON.stringify(lb.map((r) => [r.name, r.rating, r.faction])));
check("leaderboard_by_faction", st.leaderboard("brood").length === 1 && st.leaderboard("clockwork").length === 0);
st.ban(A, "test", "m_x", 0, "t", false);
check("ban_in_force", !!st.activeBan(A));
st.unban(A, "appeal accepted");
check("unban_lifts_it", !st.activeBan(A));
st.ban(B, "short", "", -1, "t", false);   // (days < 0 never happens from the CLI; a 0 or less is for good)
check("ban_for_good", !!st.activeBan(B) && st.activeBan(B).until === null);
st.newSeason("Season 2");
const s2 = st.rating(A);
check("new_season_carries_over", s2.games === 0 && s2.r > 1500 && s2.r < st.rating(A, 1).r, `${s2.r.toFixed(0)} from ${st.rating(A, 1).r.toFixed(0)}`);

console.log(fails ? `LADDER ${fails} FAILED` : "LADDER ALL OK");
process.exit(fails ? 1 : 0);
