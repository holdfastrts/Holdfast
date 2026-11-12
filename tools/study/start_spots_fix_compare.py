#!/usr/bin/env python3
"""START SPOTS FIX (docs/start_spots_fix.md): the start-spots study's mirror games BEFORE the fix (docs/start_spots_study/data,
version 0.33.11) against the same games AFTER it (docs/start_spots_fix/data: same maps, matchups, seeds, length and swaps,
tools/study/start_spots_games.py). Prints markdown tables: spot A's record per map, per group and per faction, before and
after, with the binomial p of each split and Fisher's exact p of the change; the early economy (spot A's income over spot
B's) before and after; the mirror gap of the two bases. Measuring only.
    python3 tools/study/start_spots_fix_compare.py [BEFORE] [AFTER]"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import start_spots_report as R

ROOT = R.ROOT
args = [a for a in sys.argv[1:] if not a.startswith("--")]
BEFORE = args[0] if len(args) > 0 else os.path.join(ROOT, "docs/start_spots_study/data")
AFTER = args[1] if len(args) > 1 else os.path.join(ROOT, "docs/start_spots_fix/data")
NAMED = R.NAMED


def split(outs):
    W, L, wl, ll, d = R.score(outs)
    return wl, ll, d


def fisher(a, b, c, d):
    """two-sided Fisher exact p for the table [[a, b], [c, d]]"""
    n = a + b + c + d
    r1, c1 = a + b, a + c
    if n == 0:
        return 1.0

    def pr(x):
        return math.comb(r1, x) * math.comb(n - r1, c1 - x) / math.comb(n, c1)
    obs = pr(a)
    lo, hi = max(0, c1 - (n - r1)), min(r1, c1)
    return min(1.0, sum(pr(x) for x in range(lo, hi + 1) if pr(x) <= obs + 1e-12))


def cell(outs):
    wl, ll, d = split(outs)
    return "%d-%d-%d (%.0f%%, p %.2f)" % (wl, ll, d, 100.0 * wl / max(1, wl + ll), R.binom_p(wl, wl + ll))


def change(b, a):
    bw, bl, _ = split(b)
    aw, al, _ = split(a)
    return "%.2f" % fisher(bw, bl, aw, al)


def ratio(gs, mm, key="income"):
    rs = []
    for g in gs:
        a = R.at_min(g["res"], g["a"], key, mm)
        b = R.at_min(g["res"], 1 - g["a"], key, mm)
        if a and b:
            rs.append(math.log(a / b))
    return math.exp(sum(rs) / len(rs)) if rs else None


def spread(gs, mm, key="income"):
    """mean absolute log ratio: how far apart the two spots are, whichever leads"""
    rs = []
    for g in gs:
        a = R.at_min(g["res"], g["a"], key, mm)
        b = R.at_min(g["res"], 1 - g["a"], key, mm)
        if a and b:
            rs.append(abs(math.log(a / b)))
    return math.exp(sum(rs) / len(rs)) if rs else None


if __name__ == "__main__":
    B = R.load(BEFORE)
    A = R.load(AFTER)
    keyset = set(g["tag"] for g in A)
    Bm = [g for g in B if g["tag"] in keyset]          # (the same games, when the after run is not complete yet)
    print("## Before (%d games, of them %d also played after) and after (%d games)\n" % (len(B), len(Bm), len(A)))
    print("Spot A's record: won or led - trailed or lost - even (its share of the non-even games, two-sided binomial p); "
          "the last column is Fisher's exact p that before and after differ.\n")
    print("| map | named? | before: spot A | after: spot A | after: Crown / Brood / Clockwork (spot A, by round) | change p |")
    print("|---|---|---|---|---|---|")
    maps = []
    for g in A:
        if g["map"] not in maps:
            maps.append(g["map"])
    for m in maps:
        b = [g["spotA"] for g in Bm if g["map"] == m]
        a = [g["spotA"] for g in A if g["map"] == m]
        per = []
        for f in ("crown", "brood", "clockwork"):
            per.append("".join(g["spotA"] for g in sorted([g for g in A if g["map"] == m and g["fac"] == f], key=lambda g: g["tag"])) or "-")
        print("| %s | %s | %s | %s | %s | %s |" % (m, "yes" if m in NAMED else "no", cell(b), cell(a), " / ".join(per), change(b, a)))
    print()
    groups = [("all", lambda g: True), ("classic maps", lambda g: g["map"] not in NAMED), ("named maps", lambda g: g["map"] in NAMED),
              ("named, index 0 on spot A", lambda g: g["map"] in NAMED and not g["swap"]),
              ("named, index 0 on spot B (swapped)", lambda g: g["swap"]),
              ("Crown mirrors", lambda g: g["fac"] == "crown"), ("Brood mirrors", lambda g: g["fac"] == "brood"),
              ("Clockwork mirrors", lambda g: g["fac"] == "clockwork"),
              ("Brood, classic maps", lambda g: g["fac"] == "brood" and g["map"] not in NAMED),
              ("Brood, named maps", lambda g: g["fac"] == "brood" and g["map"] in NAMED),
              ("Clockwork, classic maps", lambda g: g["fac"] == "clockwork" and g["map"] not in NAMED),
              ("Crown, classic maps", lambda g: g["fac"] == "crown" and g["map"] not in NAMED)]
    print("| group | games | before: spot A | after: spot A | after: player index 0 | change p |")
    print("|---|---|---|---|---|---|")
    for name, cond in groups:
        b = [g["spotA"] for g in Bm if cond(g)]
        a = [g["spotA"] for g in A if cond(g)]
        i0 = [g["idx0"] for g in A if cond(g)]
        print("| %s | %d | %s | %s | %s | %s |" % (name, len(a), cell(b), cell(a), cell(i0), change(b, a)))
    print()
    print("Early economy: spot A's income over spot B's (geometric mean over the games), before -> after. "
          "The second line of each faction is the SPREAD (mean of |log A/B| turned back into a ratio): how far apart the two "
          "spots are whichever one leads (1.00 = equal).\n")
    print("| faction | maps | games | 1:00 | 2:00 | 3:00 | 5:00 | 8:00 | 12:00 |")
    print("|---|---|---|---|---|---|---|---|---|")
    for f in ("crown", "brood", "clockwork"):
        for gname, cond in (("classic", lambda g: g["map"] not in NAMED), ("named", lambda g: g["map"] in NAMED)):
            gb = [g for g in Bm if g["fac"] == f and cond(g)]
            ga = [g for g in A if g["fac"] == f and cond(g)]
            cells, cells2 = [], []
            for mm in (1, 2, 3, 5, 8, 12):
                rb, ra = ratio(gb, mm), ratio(ga, mm)
                sb, sa = spread(gb, mm), spread(ga, mm)
                cells.append("%s -> %s" % ("%.2f" % rb if rb else "-", "%.2f" % ra if ra else "-"))
                cells2.append("%s -> %s" % ("%.2f" % sb if sb else "-", "%.2f" % sa if sa else "-"))
            print("| %s | %s | %d | %s |" % (f, gname, len(ga), " | ".join(cells)))
            print("| (spread) | | | %s |" % " | ".join(cells2))
    print()
    print("Mirror gap of the two mains (tiles from each of spot B's buildings, mirrored back, to the nearest same kind on spot A; "
          "0 = mirror images), before -> after, mean over maps\n")
    print("| faction | 4:00 | 8:00 |")
    print("|---|---|---|")
    for f in ("crown", "brood", "clockwork"):
        cells = []
        for mm in (4, 8):
            vals = []
            for gs in (Bm, A):
                v = [R.mirror_gap(g, mm) for g in gs if g["fac"] == f and g["lay"]]
                v = [x for x in v if x and x[2] > 0]
                vals.append("%.1f" % (sum(x[0] for x in v) / len(v)) if v else "-")
            cells.append(" -> ".join(vals))
        print("| %s | %s |" % (f, " | ".join(cells)))
    print()
    print("Game ends: decided games and 15:00 draws, before -> after\n")
    print("| faction | decided before | after | halls lost spot A / B before | after |")
    print("|---|---|---|---|---|")
    for f in ("crown", "brood", "clockwork"):
        row = []
        for gs in (Bm, A):
            g2 = [g for g in gs if g["fac"] == f]
            row.append("%d of %d" % (sum(1 for g in g2 if g["res"]["winner"] >= 0), len(g2)))
        hl = []
        for gs in (Bm, A):
            h = [0, 0]
            for g in gs:
                if g["fac"] != f:
                    continue
                for e in g["res"]["events"]:
                    if e["ev"] == "hall_lost":
                        h[0 if e["p"] == g["a"] else 1] += 1
            hl.append("%d / %d" % tuple(h))
        print("| %s | %s | %s | %s | %s |" % (f, row[0], row[1], hl[0], hl[1]))
