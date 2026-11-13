// Tickets and signatures shared by the ladder and its tests (the GDScript side: scripts/net/ladder_ticket.gd).
import crypto from "node:crypto";
export const hmacHex = (secret, s) => crypto.createHmac("sha256", secret).update(s).digest("hex");
const b64url = (s) => Buffer.from(s).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
// base64url(JSON {m, sid, seat, exp}) + "." + hex HMAC-SHA256(secret, the base64 part)
export function makeTicket(secret, matchId, sid, seat, ttl = 300) {
  const b = b64url(JSON.stringify({ m: matchId, sid, seat, exp: Math.floor(Date.now() / 1000) + ttl }));
  return b + "." + hmacHex(secret, b);
}
export const sameSig = (a, b) => a.length === b.length && crypto.timingSafeEqual(Buffer.from(a), Buffer.from(b));
