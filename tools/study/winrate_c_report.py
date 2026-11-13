#!/usr/bin/env python3
"""WIN RATES, the two mirrors (job winrate-c): the tables of docs/winrate-c.md from the games' result.json files, with the
same games of the qa-matches study (0.33.7) beside them.
    python3 tools/study/winrate_c_report.py [NEW_DATA] [OLD_DATA] > tables.md
    python3 tools/study/winrate_c_report.py --csv [NEW_DATA] > games.csv      (one line per game)
The rules are the qa-matches study's (tools/study/qa_matches_report.py): a draw is no winner at 15:00; its LEADER is the
side whose income earned + 2 x army value is 10% ahead; "won or led" = won, or led a draw. In a mirror the first-named
side is P1 (player index 0)."""
import os, sys, json, glob, math, statistics, collections

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
args = [a for a in sys.argv[1:] if not a.startswith("--")]
NEW = args[0] if len(args) > 0 else os.path.join(ROOT, "docs/winrate_2026_11_12/winrate-c/data")
OLD = args[1] if len(args) > 1 else os.path.join(ROOT, "docs/qa_2026_11_08_matches/data")
PAIRS = [("cwcw", "Clockwork v Clockwork"), ("brbr", "Brood v Brood")]
MINS = [5, 8, 10, 15]


def mmss(s):
    return "%d:%02d" % (int(s) // 60, int(s) % 60)


def load(data, pk):
    games = []
    for d in sorted(glob.glob(os.path.join(data, "base_*_%s_r*" % pk))):
        f = os.path.join(d, "result.json")
        if not os.path.exists(f):
            continue
        g = json.load(open(f))
        g["tag"] = os.path.basename(d)
        g["round"] = int(g["tag"][-1])
        g["errors"] = open(os.path.join(d, "errors.txt")).read() if os.path.exists(os.path.join(d, "errors.txt")) else ""
        g["at"] = {}
        for r in g["minutes"]:
            g["at"][(r["p"], int(round(r["t"] / 60)))] = r
        sc = [f["income"] + 2 * f["army"] for f in g["final"]]
        if g["winner"] >= 0:
            g["res"] = g["lead"] = g["winner"]
        else:
            g["res"] = -1
            g["lead"] = 0 if sc[0] > 1.1 * sc[1] else (1 if sc[1] > 1.1 * sc[0] else -1)
        g["halls_lost"] = [0, 0]
        for e in g["events"]:
            if e["ev"] == "hall_lost" and e.get("built", True):
                g["halls_lost"][e["p"]] += 1
            if e["ev"] == "brood_ground_lost":
                g["halls_lost"][e["p"]] += 1
        games.append(g)
    return games


def row(g, p, minute):
    r = g["at"].get((p, minute))
    if r is None and g["end"] >= minute * 60:
        r = g["at"].get((p, minute - 1))
    return r


def binom_two(k, n):
    """two-sided exact binomial p for k of n at 0.5"""
    if n == 0:
        return 1.0
    pk = [math.comb(n, i) / 2 ** n for i in range(n + 1)]
    return min(1.0, sum(x for x in pk if x <= pk[k] + 1e-12))


def fisher(a, b, c, d):
    """two-sided Fisher exact p for [[a, b], [c, d]]"""
    n = a + b + c + d
    r1, c1 = a + b, a + c
    def h(x):
        return math.comb(r1, x) * math.comb(n - r1, c1 - x) / math.comb(n, c1)
    p0 = h(a)
    lo, hi = max(0, c1 - (n - r1)), min(r1, c1)
    return min(1.0, sum(h(x) for x in range(lo, hi + 1) if h(x) <= p0 + 1e-12))


def welch(xa, xb):
    """difference of means and a rough two-sided p (normal approximation of Welch's t)"""
    if len(xa) < 2 or len(xb) < 2:
        return None, None
    ma, mb = statistics.mean(xa), statistics.mean(xb)
    se = math.sqrt(statistics.variance(xa) / len(xa) + statistics.variance(xb) / len(xb))
    if se == 0:
        return ma - mb, 1.0
    z = abs(ma - mb) / se
    return ma - mb, math.erfc(z / math.sqrt(2))


def summary(games):
    s = {}
    s["n"] = len(games)
    s["w"] = sum(1 for g in games if g["res"] == 0)
    s["l"] = sum(1 for g in games if g["res"] == 1)
    s["d"] = sum(1 for g in games if g["res"] == -1)
    s["led"] = [sum(1 for g in games if g["res"] == -1 and g["lead"] == x) for x in (0, -1, 1)]
    s["wol"] = [sum(1 for g in games if g["lead"] == 0), sum(1 for g in games if g["lead"] == -1), sum(1 for g in games if g["lead"] == 1)]
    dec = [g["end"] for g in games if g["res"] >= 0]
    s["dec"] = len(dec)
    s["len"] = statistics.mean(dec) if dec else None
    s["shortest"] = min(dec) if dec else None
    s["b12"] = sum(1 for x in dec if x < 720)
    s["r"] = [[sum(1 for g in games if g["round"] == r and g["res"] == k) for k in (0, -1, 1)] for r in (0, 1)]
    by_map = collections.defaultdict(dict)
    for g in games:
        by_map[g["map"]][g["round"]] = g
    s["same"] = sum(1 for m, d in by_map.items() if len(d) == 2 and d[0]["res"] == d[1]["res"])
    s["maps"] = len(by_map)
    return s


def per_side(games, key, minute):
    v = []
    for g in games:
        for p in range(2):
            r = row(g, p, minute)
            if r and not (g["res"] >= 0 and g["end"] < minute * 60):
                v.append(r[key])
    return v


def gap_ratio(games, key, minute):
    """richer side's over poorer's, per game still running at that minute"""
    v = []
    for g in games:
        a, b = row(g, 0, minute), row(g, 1, minute)
        if a and b and not (g["res"] >= 0 and g["end"] < minute * 60):
            lo, hi = sorted([a[key], b[key]])
            if lo > 0:
                v.append(hi / lo)
    return v


def letter(g):
    if g["res"] == 0:
        return "W"
    if g["res"] == 1:
        return "L"
    return "w" if g["lead"] == 0 else ("l" if g["lead"] == 1 else "d")


def picks(games):
    c = collections.Counter()
    good = collections.Counter()
    for g in games:
        for p in range(2):
            r = row(g, p, 5)
            pl = r["plan"] if r else "?"
            c[pl] += 1
            if g["lead"] == p:
                good[pl] += 1
    return c, good


def first(games, ev):
    v = [e["t"] for g in games for e in g["events"] if e["ev"] == ev]
    return v


def csv_out(new):
    print("pairing,tag,map,seed,round,result,end,leader,p1_score,p2_score," + ",".join(
        "p%d_%s_%d" % (p + 1, k, m) for m in MINS for k in ("income", "army") for p in range(2)) + ",p1_halls_lost,p2_halls_lost,p1_plan5,p2_plan5,p1_plan_end,p2_plan_end,version")
    for pk, name in PAIRS:
        for g in load(new, pk):
            res = "P1" if g["res"] == 0 else ("P2" if g["res"] == 1 else "draw")
            lead = "P1" if g["lead"] == 0 else ("P2" if g["lead"] == 1 else "even")
            sc = [f["income"] + 2 * f["army"] for f in g["final"]]
            cells = []
            for m in MINS:
                for k in ("income", "army"):
                    for p in range(2):
                        r = row(g, p, m)
                        cells.append("" if (r is None or (g["res"] >= 0 and g["end"] < m * 60)) else str(r[k]))
            r5 = [row(g, p, 5) for p in range(2)]
            print(",".join([pk, g["tag"], g["map"], str(g["seed"]), str(g["round"]), res, mmss(g["end"]), lead, str(sc[0]), str(sc[1])]
                           + cells + [str(g["halls_lost"][0]), str(g["halls_lost"][1]),
                                      r5[0]["plan"] if r5[0] else "", r5[1]["plan"] if r5[1] else "",
                                      g["final"][0]["plan"], g["final"][1]["plan"], g["version"]]))


def main():
    P = print
    if "--csv" in sys.argv:
        csv_out(NEW)
        return
    allnew = {pk: load(NEW, pk) for pk, _ in PAIRS}
    allold = {pk: load(OLD, pk) for pk, _ in PAIRS}
    vers = sorted(set(g["version"] for pk in allnew for g in allnew[pk]))
    P("Games read: %s now (version %s), %s in the qa-matches study (0.33.7)." % (
        " + ".join("%d %s" % (len(allnew[pk]), n) for pk, n in PAIRS), ", ".join(vers),
        " + ".join("%d %s" % (len(allold[pk]), n) for pk, n in PAIRS)))
    P("")
    P("## Win rates (P1 = player index 0; the same maps, seeds and tags as 0.33.7)")
    P("")
    P("| pairing | version | games | P1 W-D-L | won or led P1 / even / P2 | draws led P1 / even / P2 | decided | decided before 12:00 | mean length (decided) | shortest | round 0 W-D-L | round 1 W-D-L | same result both rounds |")
    P("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for pk, name in PAIRS:
        for lab, gs in (("0.33.7", allold[pk]), (vers[-1] if vers else "now", allnew[pk])):
            s = summary(gs)
            P("| %s | %s | %d | %d-%d-%d | %d / %d / %d | %d / %d / %d | %d | %d | %s | %s | %d-%d-%d | %d-%d-%d | %d of %d maps |" % (
                name, lab, s["n"], s["w"], s["d"], s["l"], s["wol"][0], s["wol"][1], s["wol"][2], s["led"][0], s["led"][1], s["led"][2],
                s["dec"], s["b12"], mmss(s["len"]) if s["len"] else "-", mmss(s["shortest"]) if s["shortest"] else "-",
                s["r"][0][0], s["r"][0][1], s["r"][0][2], s["r"][1][0], s["r"][1][1], s["r"][1][2], s["same"], s["maps"]))
    P("")
    P("### What is noise (exact tests)")
    P("")
    for pk, name in PAIRS:
        so, sn = summary(allold[pk]), summary(allnew[pk])
        p_spot = binom_two(sn["w"], sn["w"] + sn["l"])
        p_spot_wol = binom_two(sn["wol"][0], sn["wol"][0] + sn["wol"][2])
        p_dec = fisher(so["dec"], so["n"] - so["dec"], sn["dec"], sn["n"] - sn["dec"])
        P("- %s: P1 v P2 among decided games %d-%d (two-sided binomial p %.2f), won or led %d-%d (p %.2f); decided games "
          "0.33.7 %d of %d against now %d of %d (Fisher exact p %.3f)." % (
              name, sn["w"], sn["l"], p_spot, sn["wol"][0], sn["wol"][2], p_spot_wol, so["dec"], so["n"], sn["dec"], sn["n"], p_dec))
    P("")
    P("## Economy and armies (mean per side, games still running at that minute)")
    P("")
    P("| pairing | version | income 5:00 | 8:00 | 10:00 | 15:00 | army 5:00 | 8:00 | 10:00 | 15:00 | richer / poorer income 8:00 (mean, sd) | 10:00 | bigger / smaller army 10:00 (median) |")
    P("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for pk, name in PAIRS:
        for lab, gs in (("0.33.7", allold[pk]), ("now", allnew[pk])):
            inc = [per_side(gs, "income", m) for m in MINS]
            arm = [per_side(gs, "army", m) for m in MINS]
            r8, r10 = gap_ratio(gs, "income", 8), gap_ratio(gs, "income", 10)
            a10 = gap_ratio(gs, "army", 10)
            f = lambda v: ("%d (%d)" % (statistics.mean(v), len(v) // 2)) if v else "-"
            P("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %.2f, %.2f | %.2f | %.2f |" % (
                name, lab, *[f(v) for v in inc], *[f(v) for v in arm],
                statistics.mean(r8) if r8 else 0, statistics.pstdev(r8) if len(r8) > 1 else 0,
                statistics.mean(r10) if r10 else 0, statistics.median(a10) if a10 else 0))
    P("")
    P("Number in brackets: games still running at that minute. Change in the mean income per side at 8:00 and 10:00 (now less 0.33.7, normal-approximation p):")
    P("")
    for pk, name in PAIRS:
        parts = []
        for m in (8, 10):
            dlt, p = welch(per_side(allnew[pk], "income", m), per_side(allold[pk], "income", m))
            parts.append("%d:00 %+d (p %.3f)" % (m, dlt, p) if dlt is not None else "-")
            dlt, p = welch(per_side(allnew[pk], "army", m), per_side(allold[pk], "army", m))
            parts.append("army %d:00 %+d (p %.3f)" % (m, dlt, p) if dlt is not None else "-")
        P("- %s: %s." % (name, ", ".join(parts)))
    P("")
    P("## Per map")
    P("")
    P("Each cell: P1's results on that map, round 0 then round 1 (W won, L lost; lower case a draw P1 led (w), trailed (l), even (d)).")
    P("")
    maps = sorted(set(g["map"] for pk in allnew for g in allnew[pk]) | set(g["map"] for pk in allold for g in allold[pk]))
    P("| map | Cw v Cw 0.33.7 | Cw v Cw now | Br v Br 0.33.7 | Br v Br now | now: ends (Cw / Br) |")
    P("|---|---|---|---|---|---|")
    for m in maps:
        cells = []
        ends = []
        for pk, _ in PAIRS:
            for gs in (allold[pk], allnew[pk]):
                d = {g["round"]: g for g in gs if g["map"] == m}
                cells.append("".join(letter(d[r]) if r in d else "." for r in (0, 1)))
            d = {g["round"]: g for g in allnew[pk] if g["map"] == m}
            ends.append(" ".join(mmss(d[r]["end"]) if r in d and d[r]["res"] >= 0 else "-" for r in (0, 1)))
        P("| %s | %s | %s | %s | %s | %s / %s |" % (m, *cells, *ends))
    P("")
    P("## Every game (now)")
    P("")
    for pk, name in PAIRS:
        P("### %s" % name)
        P("")
        P("| map | seed | rd | result | end | leader | income P1/P2 5:00 | 8:00 | 10:00 | 15:00 | army P1/P2 5:00 | 8:00 | 10:00 | 15:00 | halls lost P1/P2 | plans at 5:00 |")
        P("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
        for g in allnew[pk]:
            res = "P1 won" if g["res"] == 0 else ("P2 won" if g["res"] == 1 else "draw")
            lead = "P1" if g["lead"] == 0 else ("P2" if g["lead"] == 1 else "even")
            def pair(k, m):
                a, b = row(g, 0, m), row(g, 1, m)
                if not a or not b or (g["res"] >= 0 and g["end"] < m * 60):
                    return "-"
                return "%d / %d" % (a[k], b[k])
            r5 = [row(g, p, 5) for p in range(2)]
            P("| %s | %d | %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %d / %d | %s / %s |" % (
                g["map"], g["seed"], g["round"], res, mmss(g["end"]), lead, *[pair("income", m) for m in MINS],
                *[pair("army", m) for m in MINS], g["halls_lost"][0], g["halls_lost"][1],
                r5[0]["plan"] if r5[0] else "?", r5[1]["plan"] if r5[1] else "?"))
        P("")
    P("## Halls lost")
    P("")
    P("| pairing | version | built halls lost (Clockwork) / Brood ground shrank | sides losing 3+ | Brood Mothers killed |")
    P("|---|---|---|---|---|")
    for pk, name in PAIRS:
        for lab, gs in (("0.33.7", allold[pk]), ("now", allnew[pk])):
            tot = sum(sum(g["halls_lost"]) for g in gs)
            g3 = sum(1 for g in gs for p in range(2) if g["halls_lost"][p] >= 3)
            q = sum(1 for g in gs for p in range(2) if g["final"][p]["out"]) if pk == "brbr" else "-"
            P("| %s | %s | %d | %d | %s |" % (name, lab, tot, g3, q))
    P("")
    P("## What OPTIMAL picked (build at 5:00) and how those sides did")
    P("")
    P("| pairing | version | build at 5:00: sides (won or led) |")
    P("|---|---|---|")
    for pk, name in PAIRS:
        for lab, gs in (("0.33.7", allold[pk]), ("now", allnew[pk])):
            c, good = picks(gs)
            P("| %s | %s | %s |" % (name, lab, ", ".join("%s %d (%d)" % (k, v, good[k]) for k, v in c.most_common())))
    P("")
    P("## First attacks and arrivals (median, earliest)")
    P("")
    P("| pairing | version | own first attack | first enemy arrival in a base (300+ value) |")
    P("|---|---|---|---|")
    for pk, name in PAIRS:
        for lab, gs in (("0.33.7", allold[pk]), ("now", allnew[pk])):
            a, b = first(gs, "first_attack"), first(gs, "first_arrival")
            f = lambda v: ("%s, %s (%d)" % (mmss(statistics.median(v)), mmss(min(v)), len(v))) if v else "none"
            P("| %s | %s | %s | %s |" % (name, lab, f(a), f(b)))
    P("")
    P("## Script errors and stalls (now)")
    P("")
    for pk, name in PAIRS:
        errs = [g for g in allnew[pk] if g["errors"]]
        st = [(g, e) for g in allnew[pk] for e in g["events"] if e["ev"] == "stall"]
        P("- %s: games with error lines %d%s; stalls %d%s." % (
            name, len(errs), (" (" + "; ".join("%s: %s" % (g["tag"], g["errors"].splitlines()[1][:140] if len(g["errors"].splitlines()) > 1 else "") for g in errs[:4]) + ")") if errs else "",
            len(st), (" (longest: " + ", ".join("%s P%d %s %s %ds" % (g["tag"], e["p"] + 1, mmss(e["t"]), e.get("kind", ""), e.get("len", 0))
                                                  for g, e in sorted(st, key=lambda x: -x[1].get("for", 0))[:3]) + ")") if st else ""))


if __name__ == "__main__":
    main()
