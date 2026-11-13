// Glicko-2 (Mark Glickman, "Example of the Glicko-2 system", 2013): ratings on the familiar 1500 scale.
// One match = one rating period for both players (the ladder updates after every game, as most online ladders do).
// rate(player, [{r, rd, s}]) -> {r, rd, vol}; s = 1 win, 0.5 draw, 0 loss.
export const START = { r: 1500, rd: 350, vol: 0.06 };
const TAU = 0.5;             // how fast volatility may change (Glickman suggests 0.3 to 1.2)
const SCALE = 173.7178;
const EPS = 0.000001;

const g = (phi) => 1 / Math.sqrt(1 + (3 * phi * phi) / (Math.PI * Math.PI));
const E = (mu, muj, phij) => 1 / (1 + Math.exp(-g(phij) * (mu - muj)));

export function rate(p, games) {
  const mu = (p.r - 1500) / SCALE, phi = p.rd / SCALE, sigma = p.vol;
  if (!games.length) {
    const phiStar = Math.sqrt(phi * phi + sigma * sigma);   // no games: only the uncertainty grows
    return { r: p.r, rd: Math.min(350, phiStar * SCALE), vol: sigma };
  }
  let vInv = 0, delta = 0;
  for (const o of games) {
    const muj = (o.r - 1500) / SCALE, phij = o.rd / SCALE;
    const e = E(mu, muj, phij), gj = g(phij);
    vInv += gj * gj * e * (1 - e);
    delta += gj * (o.s - e);
  }
  const v = 1 / vInv;
  delta *= v;
  // the new volatility (Illinois algorithm, step 5 of the paper)
  const a = Math.log(sigma * sigma);
  const f = (x) => {
    const ex = Math.exp(x), d = phi * phi + v + ex;
    return (ex * (delta * delta - phi * phi - v - ex)) / (2 * d * d) - (x - a) / (TAU * TAU);
  };
  let A = a, B;
  if (delta * delta > phi * phi + v) B = Math.log(delta * delta - phi * phi - v);
  else { let k = 1; while (f(a - k * TAU) < 0) k++; B = a - k * TAU; }
  let fA = f(A), fB = f(B);
  while (Math.abs(B - A) > EPS) {
    const C = A + ((A - B) * fA) / (fB - fA), fC = f(C);
    if (fC * fB <= 0) { A = B; fA = fB; } else fA /= 2;
    B = C; fB = fC;
  }
  const sigmaNew = Math.exp(A / 2);
  const phiStar = Math.sqrt(phi * phi + sigmaNew * sigmaNew);
  const phiNew = 1 / Math.sqrt(1 / (phiStar * phiStar) + 1 / v);
  let muNew = mu;
  for (const o of games) {
    const muj = (o.r - 1500) / SCALE, phij = o.rd / SCALE;
    muNew += phiNew * phiNew * g(phij) * (o.s - E(mu, muj, phij));
  }
  return { r: muNew * SCALE + 1500, rd: Math.max(30, phiNew * SCALE), vol: sigmaNew };
}

// A new season starts from last season's rating pulled halfway back to 1500, with more uncertainty.
export function carryOver(p) {
  if (!p) return { ...START };
  return { r: 1500 + 0.5 * (p.r - 1500), rd: Math.min(350, Math.max(p.rd, 120) + 80), vol: START.vol };
}

// The number shown on the leaderboard: the rating minus twice its uncertainty would be harsher; we show the rating
// itself and keep players in placement off the board.
export const shown = (p) => Math.round(p.r);
