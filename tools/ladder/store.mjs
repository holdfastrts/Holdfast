// The ladder's data, in one SQLite file (node:sqlite, built into Node 22.5+: no packages to install).
// Accounts are SteamID64s (a DEV sign-in uses made-up ones, only when the service runs with --dev).
import { DatabaseSync } from "node:sqlite";
import crypto from "node:crypto";
import { START, rate, carryOver } from "./glicko2.mjs";

export const PLACEMENT = 5;             // matches before a player shows on the leaderboard
export const FLAG = { impossible: 5, foreign: 5, flood: 20 };   // a match report this bad is flagged for a look

export function openStore(path) {
  const db = new DatabaseSync(path);
  db.exec(`
    PRAGMA journal_mode = WAL;
    CREATE TABLE IF NOT EXISTS players (sid TEXT PRIMARY KEY, name TEXT, provider TEXT, created INTEGER, last_seen INTEGER, owner TEXT);
    CREATE TABLE IF NOT EXISTS sessions (token TEXT PRIMARY KEY, sid TEXT, expires INTEGER);
    CREATE TABLE IF NOT EXISTS seasons (id INTEGER PRIMARY KEY, name TEXT, start INTEGER);
    CREATE TABLE IF NOT EXISTS ratings (season INTEGER, sid TEXT, r REAL, rd REAL, vol REAL, games INTEGER, wins INTEGER,
      losses INTEGER, draws INTEGER, crown INTEGER DEFAULT 0, brood INTEGER DEFAULT 0, clockwork INTEGER DEFAULT 0,
      PRIMARY KEY (season, sid));
    CREATE TABLE IF NOT EXISTS matches (id TEXT PRIMARY KEY, season INTEGER, created INTEGER, ended INTEGER, state TEXT,
      room TEXT, map TEXT, seed INTEGER, region TEXT, sid0 TEXT, sid1 TEXT, f0 TEXT, f1 TEXT, outcome TEXT, winner INTEGER,
      length REAL, replay TEXT, d0 REAL, d1 REAL, r0 REAL, r1 REAL, note TEXT);
    CREATE TABLE IF NOT EXISTS reports (id INTEGER PRIMARY KEY AUTOINCREMENT, sid TEXT, match TEXT, created INTEGER,
      impossible INTEGER, foreign_units INTEGER, flood INTEGER, cmds INTEGER, detail TEXT, flagged INTEGER, seen INTEGER DEFAULT 0);
    CREATE TABLE IF NOT EXISTS bans (id INTEGER PRIMARY KEY AUTOINCREMENT, sid TEXT, reason TEXT, evidence TEXT, created INTEGER,
      until INTEGER, by TEXT, steam INTEGER DEFAULT 0, lifted INTEGER, lift_reason TEXT);
    CREATE TABLE IF NOT EXISTS appeals (id INTEGER PRIMARY KEY AUTOINCREMENT, sid TEXT, created INTEGER, text TEXT, state TEXT, answer TEXT);
  `);
  if (!db.prepare("SELECT 1 FROM seasons").get()) db.prepare("INSERT INTO seasons (name, start) VALUES (?, ?)").run("Season 1", now());
  return new Store(db);
}

export const now = () => Math.floor(Date.now() / 1000);

class Store {
  constructor(db) { this.db = db; }
  q(sql) { return this.db.prepare(sql); }

  season() { return this.q("SELECT * FROM seasons ORDER BY id DESC LIMIT 1").get(); }
  newSeason(name) { this.q("INSERT INTO seasons (name, start) VALUES (?, ?)").run(name, now()); return this.season(); }

  // ---- accounts and sign-in
  touchPlayer(sid, name, provider, owner = "") {
    const p = this.q("SELECT * FROM players WHERE sid = ?").get(sid);
    if (!p) this.q("INSERT INTO players (sid, name, provider, created, last_seen, owner) VALUES (?, ?, ?, ?, ?, ?)").run(sid, name || `Player ${sid.slice(-4)}`, provider, now(), now(), owner);
    else this.q("UPDATE players SET last_seen = ?, name = COALESCE(?, name) WHERE sid = ?").run(now(), name || null, sid);
    return this.q("SELECT * FROM players WHERE sid = ?").get(sid);
  }
  newSession(sid) {
    const token = crypto.randomBytes(24).toString("hex");
    this.q("INSERT INTO sessions (token, sid, expires) VALUES (?, ?, ?)").run(token, sid, now() + 7 * 86400);
    return token;
  }
  sidOf(token) {
    const s = this.q("SELECT sid, expires FROM sessions WHERE token = ?").get(String(token || ""));
    return s && s.expires > now() ? s.sid : null;
  }
  player(sid) { return this.q("SELECT * FROM players WHERE sid = ?").get(sid); }

  // ---- bans (our own list by SteamID64)
  activeBan(sid) {
    return this.q("SELECT * FROM bans WHERE sid = ? AND lifted IS NULL AND (until IS NULL OR until > ?) ORDER BY id DESC LIMIT 1").get(sid, now());
  }
  ban(sid, reason, evidence, days, by, steam) {
    const until = days > 0 ? now() + Math.round(days * 86400) : null;
    this.q("INSERT INTO bans (sid, reason, evidence, created, until, by, steam) VALUES (?, ?, ?, ?, ?, ?, ?)").run(sid, reason, evidence || "", now(), until, by || "admin", steam ? 1 : 0);
    this.q("DELETE FROM sessions WHERE sid = ?").run(sid);
    return this.activeBan(sid);
  }
  unban(sid, why) {
    const r = this.q("UPDATE bans SET lifted = ?, lift_reason = ? WHERE sid = ? AND lifted IS NULL").run(now(), why || "", sid);
    return r.changes;
  }
  bans(all = false) { return this.q(`SELECT * FROM bans ${all ? "" : "WHERE lifted IS NULL AND (until IS NULL OR until > " + now() + ")"} ORDER BY id DESC`).all(); }
  appeal(sid, text) { this.q("INSERT INTO appeals (sid, created, text, state) VALUES (?, ?, ?, 'open')").run(sid, now(), String(text).slice(0, 2000)); }
  appeals() { return this.q("SELECT * FROM appeals ORDER BY id DESC").all(); }

  // ---- ratings
  rating(sid, season = this.season().id) {
    let r = this.q("SELECT * FROM ratings WHERE season = ? AND sid = ?").get(season, sid);
    if (!r) {
      const prev = this.q("SELECT * FROM ratings WHERE season < ? AND sid = ? ORDER BY season DESC LIMIT 1").get(season, sid);
      const c = prev && prev.games > 0 ? carryOver(prev) : { ...START };
      this.q("INSERT INTO ratings (season, sid, r, rd, vol, games, wins, losses, draws) VALUES (?, ?, ?, ?, ?, 0, 0, 0, 0)").run(season, sid, c.r, c.rd, c.vol);
      r = this.q("SELECT * FROM ratings WHERE season = ? AND sid = ?").get(season, sid);
    }
    return r;
  }
  rank(sid, season = this.season().id) {
    const me = this.rating(sid, season);
    if (me.games < PLACEMENT) return null;
    const above = this.q("SELECT COUNT(*) AS n FROM ratings WHERE season = ? AND games >= ? AND r > ?").get(season, PLACEMENT, me.r).n;
    return above + 1;
  }
  // a player's main faction this season: the one played most
  static mainFaction(r) { const f = [["crown", r.crown], ["brood", r.brood], ["clockwork", r.clockwork]].sort((a, b) => b[1] - a[1]); return f[0][1] > 0 ? f[0][0] : ""; }
  leaderboard(faction = "", limit = 100, season = this.season().id) {
    const rows = this.q(`SELECT ratings.*, players.name FROM ratings JOIN players ON players.sid = ratings.sid
      WHERE season = ? AND games >= ? ORDER BY r DESC`).all(season, PLACEMENT);
    const out = [];
    for (const r of rows) {
      const main = Store.mainFaction(r);
      if (faction && main !== faction) continue;
      out.push({ rank: out.length + 1, sid: r.sid, name: r.name, rating: Math.round(r.r), rd: Math.round(r.rd), games: r.games,
        wins: r.wins, losses: r.losses, draws: r.draws, faction: main });
      if (out.length >= limit) break;
    }
    return out;
  }

  // ---- matches
  newMatch(m) {
    this.q(`INSERT INTO matches (id, season, created, state, room, map, seed, region, sid0, sid1, f0, f1)
      VALUES (?, ?, ?, 'playing', ?, ?, ?, ?, ?, ?, ?, ?)`).run(m.id, this.season().id, now(), m.room, m.map, m.seed, m.region, m.sid0, m.sid1, m.f0, m.f1);
  }
  match(id) { return this.q("SELECT * FROM matches WHERE id = ?").get(id); }
  history(sid, limit = 20) { return this.q("SELECT * FROM matches WHERE sid0 = ? OR sid1 = ? ORDER BY created DESC LIMIT ?").all(sid, sid, limit); }
  playing() { return this.q("SELECT * FROM matches WHERE state = 'playing'").all(); }
  abort(id, note) { this.q("UPDATE matches SET state = 'aborted', ended = ?, note = ? WHERE id = ? AND state = 'playing'").run(now(), note, id); }

  // The match host's result: the ratings move (a win, a loss, a draw; a forfeit is a loss), reports are filed.
  // A no-show or an aborted match moves nothing.
  finish(res) {
    const m = this.match(res.match);
    if (!m || m.state !== "playing") return { error: "no such match in play" };
    const outcome = String(res.outcome || "aborted");
    const facs = (res.players || []).map((p) => String(p.faction || ""));
    let d0 = 0, d1 = 0, r0 = null, r1 = null;
    if (outcome === "win" || outcome === "draw") {
      const w = Number(res.winner_seat);
      const s0 = outcome === "draw" ? 0.5 : w === 0 ? 1 : 0;
      const a = this.rating(m.sid0, m.season), b = this.rating(m.sid1, m.season);
      const na = rate(a, [{ r: b.r, rd: b.rd, s: s0 }]), nb = rate(b, [{ r: a.r, rd: a.rd, s: 1 - s0 }]);
      d0 = na.r - a.r; d1 = nb.r - b.r; r0 = na.r; r1 = nb.r;
      const upd = this.q(`UPDATE ratings SET r = ?, rd = ?, vol = ?, games = games + 1, wins = wins + ?, losses = losses + ?,
        draws = draws + ?, crown = crown + ?, brood = brood + ?, clockwork = clockwork + ? WHERE season = ? AND sid = ?`);
      for (const [sid, n, s, f] of [[m.sid0, na, s0, facs[0] || m.f0], [m.sid1, nb, 1 - s0, facs[1] || m.f1]])
        upd.run(n.r, n.rd, n.vol, s === 1 ? 1 : 0, s === 0 ? 1 : 0, s === 0.5 ? 1 : 0, f === "crown" ? 1 : 0, f === "brood" ? 1 : 0, f === "clockwork" ? 1 : 0, m.season, sid);
    }
    this.q(`UPDATE matches SET state = 'done', ended = ?, outcome = ?, winner = ?, length = ?, replay = ?, map = ?, d0 = ?, d1 = ?,
      r0 = ?, r1 = ?, note = ?, f0 = ?, f1 = ? WHERE id = ?`).run(now(), outcome, Number(res.winner_seat ?? -1), Number(res.length || 0),
      String(res.replay || ""), String(res.map || m.map), d0, d1, r0, r1, String(res.end_note || (res.present ? "present " + JSON.stringify(res.present) : "")),
      facs[0] || m.f0, facs[1] || m.f1, m.id);
    const flagged = [];
    for (const [seat, a] of Object.entries(res.audit || {})) {
      const sid = Number(seat) === 0 ? m.sid0 : m.sid1;
      const bad = (a.impossible || 0) + (a.foreign || 0) + (a.flood || 0);
      if (!bad) continue;
      const flag = (a.impossible || 0) >= FLAG.impossible || (a.foreign || 0) >= FLAG.foreign || (a.flood || 0) >= FLAG.flood ? 1 : 0;
      this.q(`INSERT INTO reports (sid, match, created, impossible, foreign_units, flood, cmds, detail, flagged) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`)
        .run(sid, m.id, now(), a.impossible || 0, a.foreign || 0, a.flood || 0, a.cmds || 0, JSON.stringify(a.why || {}), flag);
      if (flag) flagged.push(sid);
    }
    return { ok: true, d0, d1, flagged };
  }
  reports(all = false) { return this.q(`SELECT * FROM reports ${all ? "" : "WHERE seen = 0"} ORDER BY flagged DESC, id DESC LIMIT 200`).all(); }
  reportsOf(sid) { return this.q("SELECT * FROM reports WHERE sid = ? ORDER BY id DESC").all(sid); }
  markSeen(id) { this.q("UPDATE reports SET seen = 1 WHERE id = ?").run(id); }
}
