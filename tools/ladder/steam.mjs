// Steam Web API, server side only (the publisher key never leaves this machine). Every call takes a `fetch`
// so the tests can answer with recorded responses (tools/ladder/fixtures/) instead of the network.
//   STEAM_PUBLISHER_KEY  the publisher Web API key (Steamworks: Users & Permissions > Manage Groups > Web API key)
//   STEAM_APP_ID         the game's App ID
//   STEAM_IDENTITY       the identity string the client passed to getAuthTicketForWebApi (default "triumviwar-ladder")
// Docs: partner.steamgames.com/doc/webapi/ISteamUserAuth, /ISteamUser, /ICheatReportingService.
const PARTNER = "https://partner.steam-api.com";
export const IDENTITY = process.env.STEAM_IDENTITY || "triumviwar-ladder";

export function steamConfig(env = process.env) {
  return { key: env.STEAM_PUBLISHER_KEY || "", appid: env.STEAM_APP_ID || "", identity: env.STEAM_IDENTITY || IDENTITY };
}
export const steamReady = (cfg) => cfg.key !== "" && cfg.appid !== "";

const isSteamId64 = (s) => /^7656119\d{10}$/.test(String(s));

async function getJson(fetchFn, url) {
  const res = await fetchFn(url, { method: "GET" });
  if (!res.ok) throw new Error(`Steam answered HTTP ${res.status}`);
  return res.json();
}
async function postForm(fetchFn, url, fields) {
  const body = new URLSearchParams();
  for (const [k, v] of Object.entries(fields)) body.set(k, String(v));
  const res = await fetchFn(url, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: body.toString() });
  if (!res.ok) throw new Error(`Steam answered HTTP ${res.status}`);
  return res.json();
}

// A client's ticket (hex, from GodotSteam getAuthTicketForWebApi(identity)) -> {sid, owner} or throws with a reason
// the player may read. Refuses a ticket Steam rejects, a publisher-banned account, and an account without the game.
export async function verifyTicket(cfg, ticketHex, fetchFn = fetch) {
  if (!steamReady(cfg)) throw new Error("Steam sign-in is not set up on this server");
  if (!/^[0-9a-fA-F]{16,4096}$/.test(ticketHex || "")) throw new Error("not a Steam ticket");
  const q = new URLSearchParams({ key: cfg.key, appid: cfg.appid, ticket: ticketHex, identity: cfg.identity });
  const a = await getJson(fetchFn, `${PARTNER}/ISteamUserAuth/AuthenticateUserTicket/v1/?${q}`);
  const r = a && a.response;
  if (!r) throw new Error("Steam gave no answer");
  if (r.error) throw new Error(`Steam refused the ticket (${r.error.errorcode}: ${r.error.errordesc})`);
  const p = r.params || {};
  if (p.result !== "OK" || !isSteamId64(p.steamid)) throw new Error("Steam refused the ticket");
  if (p.publisherbanned) throw new Error("this Steam account is banned from this game");
  const owns = await checkOwnership(cfg, p.steamid, fetchFn);
  if (!owns.ownsapp) throw new Error("this Steam account does not own the game");
  return { sid: String(p.steamid), owner: String(p.ownersteamid || p.steamid), vac: !!p.vacbanned };
}

export async function checkOwnership(cfg, sid, fetchFn = fetch) {
  const q = new URLSearchParams({ key: cfg.key, steamid: sid, appid: cfg.appid });
  const a = await getJson(fetchFn, `${PARTNER}/ISteamUser/CheckAppOwnership/v4/?${q}`);
  const o = (a && a.appownership) || {};
  return { ownsapp: o.result === "OK" && !!o.ownsapp, owner: String(o.ownersteamid || sid) };
}

// Steam's own game ban (a ban of a year or more shows on the player's Steam profile). Steam needs a cheat report first
// (ReportPlayerCheating gives the report id the ban refers to). durationSecs: how long, as the admin asked; check the
// Steamworks ICheatReportingService page for how a permanent ban is asked for before the first real one.
// delay: let Steam apply it later (so a cheater can't tell which match caught him).
export async function steamGameBan(cfg, sid, why, durationSecs, delay = false, fetchFn = fetch) {
  if (!steamReady(cfg)) throw new Error("no Steam publisher key / App ID set");
  if (!isSteamId64(sid)) throw new Error("not a SteamID64");
  const rep = await postForm(fetchFn, `${PARTNER}/ICheatReportingService/ReportPlayerCheating/v1/`, {
    key: cfg.key, steamid: sid, appid: cfg.appid, steamidreporter: 0, appdata: 0, heuristic: false, detection: true,
    playerreport: false, noreportid: false, gamemode: 0, suspicionstarttime: 0, severity: 0 });
  const reportid = rep && rep.response && rep.response.reportid;
  if (!reportid) throw new Error("Steam gave no report id");
  const ban = await postForm(fetchFn, `${PARTNER}/ICheatReportingService/RequestPlayerGameBan/v1/`, {
    key: cfg.key, steamid: sid, appid: cfg.appid, reportid, cheatdescription: String(why).slice(0, 200),
    duration: Math.max(0, Math.floor(durationSecs)), delayban: !!delay, flags: 0 });
  return { reportid: String(reportid), answer: ban && ban.response };
}

export async function steamGameUnban(cfg, sid, fetchFn = fetch) {
  if (!steamReady(cfg)) throw new Error("no Steam publisher key / App ID set");
  const a = await postForm(fetchFn, `${PARTNER}/ICheatReportingService/RemovePlayerGameBan/v1/`, { key: cfg.key, steamid: sid, appid: cfg.appid });
  return a && a.response;
}
