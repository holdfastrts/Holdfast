// The ladder's admin tool: run on the server, it opens the same database file (stop nothing; SQLite takes turns).
//   node tools/ladder/admin.mjs [--db tools/ladder/data/ladder.db] <command> ...
//   ban <steamid64> --reason "<why>" [--evidence <match id or link>] [--days N] [--steam] [--delay]
//        our own ban (refused at sign-in and at the queue); --days: for that long (default: for good); --steam: also
//        Steam's official game ban (needs STEAM_PUBLISHER_KEY and STEAM_APP_ID; a year or more shows on the profile)
//   unban <steamid64> --reason "<why>" [--steam]
//   bans [--all]                      the bans in force (--all: lifted and run out too)
//   reports [--all]                   the match hosts' reports (refused impossible orders, foreign units, floods);
//                                     flagged ones first; --all: those already looked at too
//   seen <report id>                  mark a report as looked at
//   player <steamid64>                rating, matches (with their replays), reports, bans, appeals
//   appeals                           what banned players wrote (POST /appeal)
//   season new "<name>"               start a new season (ratings carry over halfway to 1500)
import path from "node:path";
import { fileURLToPath } from "node:url";
import { openStore, now } from "./store.mjs";
import { steamConfig, steamReady, steamGameBan, steamGameUnban } from "./steam.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);
const flag = (k) => argv.includes("--" + k);
const opt = (k, d) => { const i = argv.indexOf("--" + k); return i >= 0 && i + 1 < argv.length ? argv[i + 1] : d; };
const words = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i].startsWith("--")) { if (!["steam", "all", "delay"].includes(argv[i].slice(2))) i++; continue; }
  words.push(argv[i]);
}
const store = openStore(opt("db", process.env.LADDER_DB || path.join(HERE, "data", "ladder.db")));
const when = (t) => (t ? new Date(t * 1000).toISOString().slice(0, 16).replace("T", " ") : "for good");
const isSid = (s) => /^7656119\d{10}$/.test(String(s));
const die = (m) => { console.error(m); process.exit(1); };

const [cmd, a1, a2] = words;
switch (cmd) {
  case "ban": {
    if (!isSid(a1)) die("ban <steamid64> --reason ...");
    const reason = opt("reason", ""); if (!reason) die("a ban needs --reason");
    const days = Number(opt("days", 0));
    const b = store.ban(a1, reason, opt("evidence", ""), days, process.env.USER || "admin", flag("steam"));
    console.log(`banned ${a1} ${days > 0 ? "until " + when(b.until) : "for good"}: ${reason}`);
    if (flag("steam")) {
      const cfg = steamConfig();
      if (!steamReady(cfg)) die("our ban is in; Steam's needs STEAM_PUBLISHER_KEY and STEAM_APP_ID");
      const r = await steamGameBan(cfg, a1, reason, days > 0 ? days * 86400 : 0, flag("delay"));
      console.log(`Steam game ban asked (report ${r.reportid})`);
    }
    break;
  }
  case "unban": {
    if (!isSid(a1)) die("unban <steamid64> --reason ...");
    const n = store.unban(a1, opt("reason", ""));
    console.log(n ? `unbanned ${a1}` : `${a1} had no ban in force`);
    if (flag("steam")) { await steamGameUnban(steamConfig(), a1); console.log("Steam game ban removed"); }
    break;
  }
  case "bans":
    for (const b of store.bans(flag("all")))
      console.log(`${b.sid}  ${when(b.created)} -> ${b.until ? when(b.until) : "for good"}${b.lifted ? " (lifted " + when(b.lifted) + ": " + b.lift_reason + ")" : ""}${b.steam ? " +Steam" : ""}  ${b.reason}  [${b.evidence}]`);
    break;
  case "reports":
    for (const r of store.reports(flag("all")))
      console.log(`#${r.id} ${r.flagged ? "FLAGGED " : ""}${r.sid} in ${r.match} (${when(r.created)}): impossible ${r.impossible}, foreign units ${r.foreign_units}, flood ${r.flood} of ${r.cmds} orders  ${r.detail}`);
    break;
  case "seen": store.markSeen(Number(a1)); console.log("ok"); break;
  case "player": {
    if (!isSid(a1)) die("player <steamid64>");
    const p = store.player(a1);
    if (!p) die("no such player");
    const r = store.rating(a1);
    console.log(`${p.name} (${a1}, ${p.provider}${p.owner && p.owner !== a1 ? ", copy owned by " + p.owner : ""}), since ${when(p.created)}, last seen ${when(p.last_seen)}`);
    console.log(`${store.season().name}: rating ${Math.round(r.r)} ± ${Math.round(r.rd)}, games ${r.games} (${r.wins}-${r.losses}-${r.draws}), rank ${store.rank(a1) ?? "in placement"}`);
    for (const m of store.history(a1, 20)) {
      const seat = m.sid0 === a1 ? 0 : 1, d = seat ? m.d1 : m.d0;
      console.log(`  ${m.id} ${when(m.created)} ${m.state} ${m.outcome || ""}${m.outcome === "win" ? (m.winner === seat ? " (won)" : " (lost)") : ""} ${m.map} ${Math.round(m.length || 0)}s ${d ? (d > 0 ? "+" : "") + Math.round(d) : ""} replay ${m.replay || "-"}`);
    }
    for (const x of store.reportsOf(a1)) console.log(`  report #${x.id}${x.flagged ? " flagged" : ""} ${x.match}: impossible ${x.impossible}, foreign ${x.foreign_units}, flood ${x.flood}  ${x.detail}`);
    for (const b of store.bans(true).filter((b) => b.sid === a1)) console.log(`  ban ${when(b.created)} -> ${b.until ? when(b.until) : "for good"}${b.lifted ? " lifted" : ""}: ${b.reason} [${b.evidence}]`);
    break;
  }
  case "appeals":
    for (const x of store.appeals()) console.log(`#${x.id} ${x.sid} ${when(x.created)} ${x.state}: ${x.text}`);
    break;
  case "season":
    if (a1 !== "new" || !a2) die('season new "<name>"');
    console.log("new season:", store.newSeason(a2).name);
    break;
  default:
    console.log("commands: ban, unban, bans, reports, seen, player, appeals, season new (see the top of tools/ladder/admin.mjs)");
}
void now;
