// THE LADDER SERVICE for ranked play (docs/online_ranked.md). One small Node program (no packages: node:http,
// node:sqlite, node:child_process; Node 22.5+) beside the match hosts: sign-in (Steam, or a DEV sign-in for tests),
// the 1v1 queue, Glicko-2 ratings with placement matches and seasons, match records, the ban list and the reports the
// match hosts send. It starts a match host (tools/server/match_server.gd) for every match it makes.
//
//   node tools/ladder/ladder.mjs [--dev] [--port 8790] [--db ladder.db] [--relay ws://127.0.0.1:8799]
//        [--godot godot] [--project <game folder>] [--max-matches 4] [--out <dir for results and replays>]
// Environment: LADDER_SECRET (shared with the match hosts: signs tickets and results; required),
//   STEAM_PUBLISHER_KEY / STEAM_APP_ID (Steam sign-in; without them only --dev sign-in works),
//   LADDER_RELAY_PUBLIC (the relay address the players use, if not the same as --relay),
//   LADDER_APPEAL (where a banned player is told to appeal), LADDER_MAPS (comma list of ranked maps).
// --dev: anyone may sign in as any made-up SteamID64 (tests, local play). NEVER on a public server.
import http from "node:http";
import crypto from "node:crypto";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { openStore, now, PLACEMENT } from "./store.mjs";
import { steamConfig, steamReady, verifyTicket } from "./steam.mjs";
import { hmacHex, makeTicket as mkTicket, sameSig } from "./tickets.mjs";
import fs from "node:fs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);
const opt = (k, d) => { const i = argv.indexOf("--" + k); return i >= 0 && i + 1 < argv.length ? argv[i + 1] : d; };
const DEV = argv.includes("--dev");
const PORT = Number(opt("port", process.env.PORT || 8790));
const RELAY = opt("relay", process.env.LADDER_RELAY || "ws://127.0.0.1:8799");
const RELAY_PUBLIC = process.env.LADDER_RELAY_PUBLIC || RELAY;
const GODOT = opt("godot", process.env.GODOT || "godot");
const PROJECT = opt("project", path.resolve(HERE, "../.."));
const MAX_MATCHES = Number(opt("max-matches", process.env.LADDER_MAX_MATCHES || 4));
const OUT = path.resolve(opt("out", process.env.LADDER_OUT || path.join(HERE, "data")));
const SECRET = process.env.LADDER_SECRET || "";
const APPEAL = process.env.LADDER_APPEAL || "https://github.com/holdfastrts/holdfast/issues (title: Ranked ban appeal)";
const MAPS = (process.env.LADDER_MAPS || "random_1v1").split(",").map((s) => s.trim()).filter(Boolean);
const FACTIONS = ["crown", "brood", "clockwork", "random"];
const VERSION_FILE = path.join(PROJECT, "project.godot");
if (!SECRET || SECRET.length < 16) { console.error("LADDER_SECRET must be set (16 characters or more)"); process.exit(1); }

const store = openStore(opt("db", path.join(OUT, "ladder.db")));
const steam = steamConfig();
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), "[ladder]", ...a);

// ------------------------------------------------------------------ tickets and signatures (tickets.mjs)
const hmac = (s) => hmacHex(SECRET, s);
const makeTicket = (matchId, sid, seat) => mkTicket(SECRET, matchId, sid, seat);

// ------------------------------------------------------------------ the queue
const queue = new Map();     // sid -> {sid, faction, region, joined, rating}
const found = new Map();     // sid -> {match, seat, ticket, opponent}  (until the player asks, or the match ends)
const procs = new Map();     // match id -> child process
const ROOM_ABC = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const roomCode = () => Array.from(crypto.randomBytes(10), (b) => ROOM_ABC[b % ROOM_ABC.length]).join("");

// The rating window a waiting player accepts: 150 points, growing 15 a second; other regions after 30 s.
const windowOf = (e, t) => 150 + 15 * (t - e.joined);
function pairUp() {
  if (procs.size >= MAX_MATCHES) return;
  const t = now();
  const list = [...queue.values()].sort((a, b) => a.joined - b.joined);
  const taken = new Set();
  for (const a of list) {
    if (taken.has(a.sid) || procs.size >= MAX_MATCHES) continue;
    let best = null, bestGap = Infinity;
    for (const b of list) {
      if (b === a || taken.has(b.sid)) continue;
      const gap = Math.abs(a.rating - b.rating);
      const regionOk = a.region === b.region || (t - a.joined >= 30 && t - b.joined >= 30);
      if (!regionOk || gap > Math.max(windowOf(a, t), windowOf(b, t))) continue;
      if (gap < bestGap) { best = b; bestGap = gap; }
    }
    if (best) { taken.add(a.sid); taken.add(best.sid); startMatch(a, best); }
  }
}

function startMatch(a, b) {
  queue.delete(a.sid); queue.delete(b.sid);
  const id = "m_" + Date.now().toString(36) + crypto.randomBytes(3).toString("hex");
  const m = { id, room: roomCode(), map: MAPS[crypto.randomInt(MAPS.length)], seed: crypto.randomInt(2 ** 31 - 1),
    region: a.region, sid0: a.sid, sid1: b.sid, f0: a.faction, f1: b.faction };
  store.newMatch(m);
  const args = ["--headless", "--path", PROJECT, "--script", "res://tools/server/match_server.gd", "--",
    `relay:${RELAY}`, `room:${m.room}`, `match:${id}`, `secret:${SECRET}`, `ladder:http://127.0.0.1:${PORT}`,
    `map:${m.map}`, `seed:${m.seed}`, `f0:${m.f0}`, `f1:${m.f1}`, `sid0:${m.sid0}`, `sid1:${m.sid1}`, `out:${OUT}`];
  const p = spawn(GODOT, args, { stdio: ["ignore", "pipe", "pipe"] });
  procs.set(id, p);
  const tag = `[match ${id}]`;
  p.stdout.on("data", (d) => { for (const l of String(d).split("\n")) if (l.includes("[server]") || l.includes("SCRIPT ERROR")) console.log(tag, l.trim().slice(0, 300)); });
  p.stderr.on("data", (d) => { const s = String(d).trim(); if (s.includes("ERROR")) console.log(tag, s.slice(0, 300)); });
  p.on("exit", (code) => {
    procs.delete(id);
    const mm = store.match(id);
    if (mm && mm.state === "playing") { store.abort(id, `match host exited (${code}) without a result`); log(`${id} aborted: host exited ${code}`); }
    for (const sid of [m.sid0, m.sid1]) if (found.get(sid)?.match === id) found.get(sid).over = true;
  });
  for (const [seat, me, them] of [[0, a, b], [1, b, a]]) {
    const p2 = store.player(them.sid);
    found.set(me.sid, { match: id, seat, ticket: makeTicket(id, me.sid, seat), relay: RELAY_PUBLIC, room: m.room,
      map: m.map, opponent: { name: p2?.name || "?", faction: them.faction, rating: Math.round(them.rating) } });
  }
  log(`match ${id}: ${a.sid} (${a.faction}) v ${b.sid} (${b.faction}), room ${m.room}`);
}
setInterval(pairUp, 1000);

// ------------------------------------------------------------------ HTTP
const send = (res, code, obj) => {
  res.writeHead(code, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Authorization, Content-Type", "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS" });
  res.end(JSON.stringify(obj));
};
const readBody = (req) => new Promise((ok) => { let b = ""; req.on("data", (d) => { b += d; if (b.length > 1e6) req.destroy(); }); req.on("end", () => ok(b)); });
const banned = (res, ban) => send(res, 403, { error: "banned", reason: ban.reason, until: ban.until, appeal: APPEAL });
const isSid = (s) => /^7656119\d{10}$/.test(String(s));

function me(req) {
  const h = String(req.headers.authorization || "");
  return h.startsWith("Bearer ") ? store.sidOf(h.slice(7)) : null;
}

function profile(sid) {
  const r = store.rating(sid);
  const season = store.season();
  return { sid, name: store.player(sid)?.name, season: season.name, rating: Math.round(r.r), rd: Math.round(r.rd),
    games: r.games, wins: r.wins, losses: r.losses, draws: r.draws, placement: Math.max(0, PLACEMENT - r.games), rank: store.rank(sid) };
}

async function route(req, res) {
  const url = new URL(req.url, "http://x");
  const p = url.pathname;
  if (req.method === "OPTIONS") return send(res, 204, {});
  if (p === "/health") return send(res, 200, { ok: true, dev: DEV, steam: steamReady(steam), matches: procs.size, queue: queue.size });
  if (p === "/login" && req.method === "POST") {
    let d; try { d = JSON.parse(await readBody(req)); } catch { return send(res, 400, { error: "bad request" }); }
    let sid, name = String(d.name || "").replace(/[^\p{L}\p{N} _.\-]/gu, "").slice(0, 24) || null, owner = "";
    if (d.provider === "dev") {
      if (!DEV) return send(res, 403, { error: "the dev sign-in is off on this server" });
      if (!isSid(d.id)) return send(res, 400, { error: "not a SteamID64" });
      sid = String(d.id);
    } else if (d.provider === "steam") {
      try { const v = await verifyTicket(steam, String(d.ticket || "")); sid = v.sid; owner = v.owner; }
      catch (e) { return send(res, 401, { error: String(e.message || e) }); }
    } else return send(res, 400, { error: "unknown sign-in" });
    const ban = store.activeBan(sid);
    if (ban) { log(`login refused, banned: ${sid}`); return banned(res, ban); }
    store.touchPlayer(sid, name, d.provider, owner);
    return send(res, 200, { token: store.newSession(sid), ...profile(sid) });
  }
  if (p === "/leaderboard") {
    const f = String(url.searchParams.get("faction") || "");
    const rows = store.leaderboard(FACTIONS.includes(f) ? f : "", 100);
    const sid = me(req);
    return send(res, 200, { season: store.season().name, faction: f, rows: rows.map(({ sid: _s, ...r }) => r),
      you: sid ? { ...profile(sid), rank_here: rows.find((r) => r.sid === sid)?.rank || null } : null });
  }
  if (p === "/internal/result" && req.method === "POST") {
    const body = await readBody(req);
    if (!sameSig(hmac(body), String(req.headers["x-ladder-sig"] || ""))) return send(res, 403, { error: "bad signature" });
    let r; try { r = JSON.parse(body); } catch { return send(res, 400, { error: "bad result" }); }
    const out = store.finish(r);
    log(`result ${r.match}: ${r.outcome} seat ${r.winner_seat} (${r.length}s) ${JSON.stringify(out)}`);
    for (const sid of out.flagged || []) log(`REPORT flagged ${sid} in ${r.match}: see the admin CLI (reports)`);
    return send(res, 200, out);
  }
  // ---- signed in from here
  const sid = me(req);
  if (!sid) return send(res, 401, { error: "sign in first" });
  const ban = store.activeBan(sid);
  if (ban) { queue.delete(sid); return banned(res, ban); }
  if (p === "/me") return send(res, 200, { ...profile(sid), history: store.history(sid, 10).map((m) => matchView(m, sid)) });
  if (p === "/queue" && req.method === "POST") {
    let d = {}; try { d = JSON.parse(await readBody(req) || "{}"); } catch { /* defaults */ }
    const faction = FACTIONS.includes(d.faction) ? d.faction : "random";
    if (d.version && d.version !== gameVersion()) return send(res, 409, { error: `the ranked servers run version ${gameVersion()}` });
    const live = found.get(sid);
    if (live && !live.over) return send(res, 409, { error: "you are already in a match" });
    found.delete(sid);
    queue.set(sid, { sid, faction, region: String(d.region || "eu").slice(0, 8), joined: now(), rating: store.rating(sid).r });
    return send(res, 200, { state: "searching", secs: 0 });
  }
  if (p === "/queue" && req.method === "DELETE") { queue.delete(sid); return send(res, 200, { state: "idle" }); }
  if (p === "/queue") {
    const f = found.get(sid);
    if (f && !f.over) return send(res, 200, { state: "found", ...f });
    const q = queue.get(sid);
    return send(res, 200, q ? { state: "searching", secs: now() - q.joined, players: queue.size } : { state: "idle" });
  }
  const mm = p.match(/^\/match\/([A-Za-z0-9_]+)$/);
  if (mm) {
    const m = store.match(mm[1]);
    if (!m || (m.sid0 !== sid && m.sid1 !== sid)) return send(res, 404, { error: "no such match" });
    return send(res, 200, matchView(m, sid));
  }
  if (p === "/appeal" && req.method === "POST") {
    let d = {}; try { d = JSON.parse(await readBody(req)); } catch { /* empty */ }
    store.appeal(sid, String(d.text || ""));
    return send(res, 200, { ok: true });
  }
  return send(res, 404, { error: "no such page" });
}

// One match as a player sees it: the result and their rating change.
function matchView(m, sid) {
  const seat = m.sid0 === sid ? 0 : 1;
  const r = m.outcome === "draw" ? "draw" : m.outcome === "win" ? (m.winner === seat ? "win" : "loss") : m.outcome || "";
  return { id: m.id, state: m.state, result: r, map: m.map, length: m.length, faction: seat ? m.f1 : m.f0,
    opp_faction: seat ? m.f0 : m.f1, opponent: store.player(seat ? m.sid0 : m.sid1)?.name || "?",
    delta: Math.round((seat ? m.d1 : m.d0) || 0), rating: (seat ? m.r1 : m.r0) == null ? null : Math.round(seat ? m.r1 : m.r0),
    placement: Math.max(0, PLACEMENT - store.rating(sid).games), ended: m.ended };
}

let _ver = "";
function gameVersion() {
  if (_ver) return _ver;
  try { const m = require_text(VERSION_FILE).match(/config\/version="([^"]+)"/); _ver = m ? m[1] : "dev"; } catch { _ver = "dev"; }
  return _ver;
}
const require_text = (f) => fs.readFileSync(f, "utf8");

// A match host that never reported (crashed, killed): its match is aborted after an hour and a half.
setInterval(() => { for (const m of store.playing()) if (!procs.has(m.id) && now() - m.created > 5400) store.abort(m.id, "no result"); }, 60000);

fs.mkdirSync(OUT, { recursive: true });
for (const m of store.playing()) store.abort(m.id, "the ladder restarted");
http.createServer((req, res) => route(req, res).catch((e) => { log("error", e); send(res, 500, { error: "server error" }); }))
  .listen(PORT, () => log(`listening on ${PORT}${DEV ? " (DEV sign-in ON: never on a public server)" : ""}; steam ${steamReady(steam) ? "on" : "off"}; relay ${RELAY}; ${MAX_MATCHES} matches at once`));
