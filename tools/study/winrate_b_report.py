#!/usr/bin/env python3
"""WIN RATES REPORT, job winrate-b (docs/winrate-b.md): Clockwork v Brood and the Crown mirror, now (this run's data)
against the same games of the 0.33.7 study (docs/qa_2026_11_08_matches/data, the same tags and seeds).
    python3 tools/study/winrate_b_report.py [NEW_DATA] [OLD_DATA] > tables.md
    python3 tools/study/winrate_b_report.py --csv [NEW_DATA] > games.csv
Draw LEADER: income earned + 2 x army value 10% ahead (the old study's rule). In Clockwork v Brood everything is the
Clockwork's view; in the mirror the P1 start spot's (slot 0)."""
import os, sys, json, glob, statistics, math

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
args = [a for a in sys.argv[1:] if not a.startswith("--")]
NEW = args[0] if len(args) > 0 else os.path.join(ROOT, "docs/winrate_2026_11_12/winrate-b/data")
OLD = args[1] if len(args) > 1 else os.path.join(ROOT, "docs/qa_2026_11_08_matches/data")
PAIRS = {"brcw": "Clockwork v Brood", "crcr": "Crown v Crown"}
MAPS = ["greenhold", "highmoor", "dune_sea", "frostfang", "twin_fords", "ashfall", "mirewood", "border_march", "red_coast",
        "ashford_crossing", "kestrel_rise", "thornwood_maze", "redrock_canyon", "saltmarsh_isles", "glimmerdeep",
        "frostmere", "cinder_steps", "hollowfen", "amberfall_vale"]
CHECK = [5, 8, 10, 15]


def mmss(s):
    return "%d:%02d" % (int(s) // 60, int(s) % 60)


def load(data):
    out = {}
    for d in sorted(glob.glob(os.path.join(data, "base_*"))):
        tag = os.path.basename(d)
        pk = tag.split("_")[-2]
        if pk not in PAIRS:
            continue
        f = os.path.join(d, "result.json")
        if not os.path.exists(f):
            continue
        g = json.load(open(f))
        g["tag"], g["pk"] = tag, pk
        g["mapn"] = tag[5:-10]
        g["rnd"] = int(tag[-1])
        g["fac"] = [s[0] for s in g["slots"]]
        g["at"] = {}
        for r in g["minutes"]:
            g["at"][(r["p"], int(round(r["t"] / 60)))] = r
        sc = [f["income"] + 2 * f["army"] for f in g["final"]]
        g["score"] = sc
        if g["winner"] >= 0:
            g["res"], g["lead"] = g["winner"], g["winner"]
        else:
            g["res"] = -1
            g["lead"] = 0 if sc[0] > 1.1 * sc[1] else (1 if sc[1] > 1.1 * sc[0] else -1)
        # the subject: the Clockwork in brcw, slot 0 (P1) in the mirror
        g["a"] = g["fac"].index("clockwork") if pk == "brcw" else 0
        g["halls_lost"] = [len([e for e in g["events"] if e.get("ev") == "hall_lost" and e["p"] == p and e.get("built")])
                           for p in (0, 1)]
        g["sites_lost"] = [len([e for e in g["events"] if e.get("ev") == "hall_lost" and e["p"] == p and not e.get("built")])
                           for p in (0, 1)]
        g["ground_lost"] = [len([e for e in g["events"] if e.get("ev") == "brood_ground_lost" and e["p"] == p]) for p in (0, 1)]
        out[tag] = g
    return out


def row(g, p, minute):
    r = g["at"].get((p, minute))
    if r is None and g["end"] < minute * 60:
        return None
    return r


def letter(g, a):
    if g["res"] == a:
        return "W"
    if g["res"] == 1 - a:
        return "L"
    return "w" if g["lead"] == a else ("l" if g["lead"] == 1 - a else "d")


def wdl(games):
    w = d = l = 0
    led = [0, 0, 0]
    for g in games:
        a = g["a"]
        if g["res"] == a:
            w += 1
        elif g["res"] == -1:
            d += 1
            led[0 if g["lead"] == a else (2 if g["lead"] == 1 - a else 1)] += 1
        else:
            l += 1
    return w, d, l, led


def ratio(games, key, minute, subj=lambda g: g["a"]):
    xa, xb = [], []
    for g in games:
        a = subj(g)
        ra, rb = row(g, a, minute), row(g, 1 - a, minute)
        if ra and rb:
            xa.append(ra[key]); xb.append(rb[key])
    if not xa or sum(xb) == 0:
        return None, 0
    return sum(xa) / sum(xb), len(xa)


def mean_of(games, p_of, key, minute):
    v = [row(g, p_of(g), minute)[key] for g in games if row(g, p_of(g), minute)]
    return (sum(v) / len(v)) if v else None


def binom_p(k, n):
    """two-sided exact binomial p for k of n at 0.5"""
    if n == 0:
        return 1.0
    pr = [math.comb(n, i) / 2 ** n for i in range(n + 1)]
    obs = pr[k]
    return min(1.0, sum(x for x in pr if x <= obs + 1e-12))


def fmt(x, n=2):
    return "-" if x is None else ("%." + str(n) + "f") % x


def csv(new):
    print("tag,map,seed,round,p1_faction,p2_faction,winner_slot,winner_faction,end,draw_leader_slot,"
          + ",".join("%s_%s_%d" % (k, s, m) for m in CHECK for s in ("p1", "p2") for k in ("income", "army"))
          + ",halls_lost_p1,halls_lost_p2,sites_lost_p1,sites_lost_p2,plan_p1_end,plan_p2_end,version")
    for t in sorted(new):
        g = new[t]
        cells = []
        for m in CHECK:
            for p in (0, 1):
                r = row(g, p, m)
                cells += [str(r["income"]) if r else "", str(r["army"]) if r else ""]
        print(",".join(str(x) for x in [t, g["mapn"], g["seed"], g["rnd"], g["fac"][0], g["fac"][1], g["winner"],
              g["fac"][g["winner"]] if g["winner"] >= 0 else "", g["end"], g["lead"] if g["res"] == -1 else ""] + cells
              + [g["halls_lost"][0], g["halls_lost"][1], g["sites_lost"][0], g["sites_lost"][1],
                 g["final"][0]["plan"], g["final"][1]["plan"], g["version"]]))


def main():
    new, old = load(NEW), load(OLD)
    P = print
    vers = sorted({g["version"] for g in new.values()})
    P("Games read: now %d (version %s), 0.33.7 %d (the same tags and seeds)." % (len(new), ", ".join(vers), len([t for t in old if t in new or True])))
    P()
    P("## Win rates")
    P()
    P("W-D-L is the Clockwork's in Clockwork v Brood, the P1 start spot's (slot 0) in the mirror. Draws led: subject / even / other.")
    P()
    P("| pairing | run | games | W-D-L | won or led | draws led | decided | mean length (decided) | decided before 12:00 | p (won or led v trailed, 50%) |")
    P("|---|---|---|---|---|---|---|---|---|---|")
    for pk, name in PAIRS.items():
        for lab, src in (("0.33.7", old), ("now", new)):
            gl = [g for g in src.values() if g["pk"] == pk and (lab == "now" or g["tag"] in new or not new)]
            if lab == "0.33.7":
                gl = [g for g in src.values() if g["pk"] == pk]
            if not gl:
                continue
            w, d, l, led = wdl(gl)
            dec = [g for g in gl if g["res"] >= 0]
            wol, tr = w + led[0], l + led[2]
            P("| %s | %s | %d | %d-%d-%d | %d | %d/%d/%d | %d | %s | %d | %.2f |" % (
                name, lab, len(gl), w, d, l, wol, led[0], led[1], led[2], len(dec),
                mmss(statistics.mean(g["end"] for g in dec)) if dec else "-",
                len([g for g in dec if g["end"] < 720]), binom_p(wol, wol + tr)))
    P()
    # P1 v P2
    P("## The start spots (P1 = slot 0)")
    P()
    P("| pairing | run | P1 wins - P2 wins | P1 won or led - P2 | even | p (won or led) |")
    P("|---|---|---|---|---|---|")
    for pk, name in PAIRS.items():
        for lab, src in (("0.33.7", old), ("now", new)):
            gl = [g for g in src.values() if g["pk"] == pk]
            if not gl:
                continue
            p1w = len([g for g in gl if g["res"] == 0]); p2w = len([g for g in gl if g["res"] == 1])
            p1 = len([g for g in gl if g["lead"] == 0]); p2 = len([g for g in gl if g["lead"] == 1])
            ev = len([g for g in gl if g["lead"] == -1])
            P("| %s | %s | %d - %d | %d - %d | %d | %.2f |" % (name, lab, p1w, p2w, p1, p2, ev, binom_p(p1, p1 + p2)))
    if any(g["pk"] == "brcw" for g in new.values()):
        P()
        P("Clockwork v Brood by the Clockwork's slot (now): ")
        for s in (0, 1):
            gl = [g for g in new.values() if g["pk"] == "brcw" and g["a"] == s]
            w, d, l, led = wdl(gl)
            P("- Clockwork on P%d: %d games, %d-%d-%d, won or led %d, trailed %d" % (s + 1, len(gl), w, d, l, w + led[0], l + led[2]))
    P()
    # economy
    P("## Income and army (means; the subject's over the other's, games still running at that minute)")
    P()
    P("| pairing | run | income 5:00 | 8:00 | 10:00 | 15:00 | army 5:00 | 8:00 | 10:00 | 15:00 |")
    P("|---|---|---|---|---|---|---|---|---|---|")
    for pk, name in PAIRS.items():
        for lab, src in (("0.33.7", old), ("now", new)):
            gl = [g for g in src.values() if g["pk"] == pk]
            if not gl:
                continue
            cells = []
            for key in ("income", "army"):
                for m in CHECK:
                    r, n = ratio(gl, key, m)
                    cells.append("%s (%d)" % (fmt(r), n))
            P("| %s | %s | %s |" % (name, lab, " | ".join(cells)))
    P()
    P("Each side's own means (income earned / army value):")
    P()
    P("| side | run | income 5:00 | 8:00 | 10:00 | 15:00 | army 5:00 | 8:00 | 10:00 | 15:00 | halls lost a game (built + sites) |")
    P("|---|---|---|---|---|---|---|---|---|---|---|")
    sides = [("Clockwork (v Brood)", "brcw", lambda g: g["a"]), ("Brood (v Clockwork)", "brcw", lambda g: 1 - g["a"]),
             ("Crown P1 (mirror)", "crcr", lambda g: 0), ("Crown P2 (mirror)", "crcr", lambda g: 1)]
    for lab0, pk, pf in sides:
        for lab, src in (("0.33.7", old), ("now", new)):
            gl = [g for g in src.values() if g["pk"] == pk]
            if not gl:
                continue
            cells = [fmt(mean_of(gl, pf, k, m), 0) for k in ("income", "army") for m in CHECK]
            hl = statistics.mean(g["halls_lost"][pf(g)] for g in gl); sl = statistics.mean(g["sites_lost"][pf(g)] for g in gl)
            if "Brood" in lab0 and "(v" in lab0 and lab0.startswith("Brood"):
                gr = statistics.mean(g["ground_lost"][pf(g)] for g in gl)
                hs = "ground lost %.1f" % gr
            else:
                hs = "%.1f + %.1f" % (hl, sl)
            P("| %s | %s | %s | %s |" % (lab0, lab, " | ".join(cells), hs))
    P()
    # length
    P("## Game length")
    P()
    P("| pairing | run | decided | before 10:00 | 10:00-12:00 | 12:00-15:00 | draws | shortest |")
    P("|---|---|---|---|---|---|---|---|")
    for pk, name in PAIRS.items():
        for lab, src in (("0.33.7", old), ("now", new)):
            gl = [g for g in src.values() if g["pk"] == pk]
            if not gl:
                continue
            dec = [g for g in gl if g["res"] >= 0]
            P("| %s | %s | %d | %d | %d | %d | %d | %s |" % (name, lab, len(dec), len([g for g in dec if g["end"] < 600]),
              len([g for g in dec if 600 <= g["end"] < 720]), len([g for g in dec if g["end"] >= 720]),
              len(gl) - len(dec), mmss(min(g["end"] for g in dec)) if dec else "-"))
    P()
    # per map
    P("## Per map")
    P()
    P("Letters: round 0 then round 1, the subject's result (W won, L lost, w/l a draw it led/trailed, d even). The Clockwork's slot per round in brackets. Income ratio at 8:00 (the subject's over the other's), the two games' mean.")
    P()
    P("| map | CW v BR 0.33.7 | CW v BR now | CW income 8:00 now | Cr v Cr (P1) 0.33.7 | Cr v Cr now | P1 income 8:00 now | ends now (CW v BR ; Cr v Cr) |")
    P("|---|---|---|---|---|---|---|---|")
    for m in MAPS:
        cells = []
        ends = []
        for pk in PAIRS:
            for src, lab in ((old, "o"), (new, "n")):
                gs = [src.get("base_%s_%s_r%d" % (m, pk, r)) for r in (0, 1)]
                s = "".join(letter(g, g["a"]) if g else "." for g in gs)
                if pk == "brcw":
                    s += " (" + "".join("P%d" % (g["a"] + 1) if g else "." for g in gs) + ")" if lab == "n" else ""
                cells.append(s)
                if lab == "n":
                    rs = []
                    for g in gs:
                        if g:
                            ra, rb = row(g, g["a"], 8), row(g, 1 - g["a"], 8)
                            if ra and rb and rb["income"]:
                                rs.append(ra["income"] / rb["income"])
                    cells.append(fmt(statistics.mean(rs)) if rs else "-")
                    ends.append("/".join(mmss(g["end"]) if g and g["res"] >= 0 else ("-" if g else ".") for g in gs))
        P("| %s | %s | %s |" % (m, " | ".join(cells), " ; ".join(ends)))
    P()
    # same seed, then and now
    P("## The same game then and now (same tag and seed)")
    P()
    for pk, name in PAIRS.items():
        both = [t for t in new if t in old and new[t]["pk"] == pk]
        if not both:
            continue
        sc = {"W": 2, "w": 1, "d": 0, "l": -1, "L": -2}
        up = len([t for t in both if sc[letter(new[t], new[t]["a"])] > sc[letter(old[t], old[t]["a"])]])
        dn = len([t for t in both if sc[letter(new[t], new[t]["a"])] < sc[letter(old[t], old[t]["a"])]])
        same = len(both) - up - dn
        decided_old = len([t for t in both if old[t]["res"] >= 0]); decided_new = len([t for t in both if new[t]["res"] >= 0])
        P("- %s: %d games; the subject did better in %d, worse in %d, the same in %d (sign test p %.2f); decided %d then, %d now."
          % (name, len(both), up, dn, same, binom_p(up, up + dn), decided_old, decided_new))
    P()
    # plans
    P("## What OPTIMAL played (the plan at 5:00 and at the end) and how those sides did (now)")
    P()
    P("| side | plan at 5:00 | sides | won | won or led | lost or trailed | at the end (most common) |")
    P("|---|---|---|---|---|---|---|")
    import collections
    for lab0, pk, fac in (("Clockwork", "brcw", "clockwork"), ("Brood", "brcw", "brood"), ("Crown (mirror)", "crcr", "crown")):
        by = collections.defaultdict(list)
        for g in new.values():
            if g["pk"] != pk:
                continue
            for p in (0, 1):
                if g["fac"][p] != fac:
                    continue
                r = row(g, p, 5)
                by[r["plan"] if r else "?"].append((g, p))
        for plan, lst in sorted(by.items(), key=lambda x: -len(x[1])):
            won = len([1 for g, p in lst if g["res"] == p])
            wol = len([1 for g, p in lst if g["lead"] == p])
            lt = len([1 for g, p in lst if g["lead"] == 1 - p])
            ends = collections.Counter(g["final"][p]["plan"] for g, p in lst)
            P("| %s | %s | %d | %d | %d | %d | %s |" % (lab0, plan, len(lst), won, wol, lt,
              ", ".join("%s %d" % kv for kv in ends.most_common(3))))
    P()
    # per-game list
    P("## Every game (now)")
    P()
    P("| game | seed | P1 / P2 | result | end | income 8:00 P1/P2 | army 8:00 P1/P2 | income 10:00 | army 10:00 | final score P1/P2 | halls lost P1/P2 | plans at the end | 0.33.7 |")
    P("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for t in sorted(new, key=lambda t: (new[t]["pk"], t)):
        g = new[t]

        def rr(m, k):
            a, b = row(g, 0, m), row(g, 1, m)
            return "%s/%s" % (a[k] if a else "-", b[k] if b else "-")
        if g["res"] >= 0:
            res = "P%d %s won" % (g["res"] + 1, g["fac"][g["res"]])
        else:
            res = "draw, " + ("P%d led" % (g["lead"] + 1) if g["lead"] >= 0 else "even")
        o = old.get(t)
        if o:
            ores = ("P%d won %s" % (o["res"] + 1, mmss(o["end"]))) if o["res"] >= 0 else ("draw, " + ("P%d led" % (o["lead"] + 1) if o["lead"] >= 0 else "even"))
        else:
            ores = "-"
        hl = "%d+%d / %d+%d" % (g["halls_lost"][0], g["sites_lost"][0], g["halls_lost"][1], g["sites_lost"][1])
        P("| %s | %d | %s / %s | %s | %s | %s | %s | %s | %s | %d/%d | %s | %s / %s | %s |" % (
            t[5:], g["seed"], g["fac"][0], g["fac"][1], res, mmss(g["end"]), rr(8, "income"), rr(8, "army"),
            rr(10, "income"), rr(10, "army"), g["score"][0], g["score"][1], hl, g["final"][0]["plan"], g["final"][1]["plan"], ores))


if __name__ == "__main__":
    if "--csv" in sys.argv:
        csv(load(NEW))
    else:
        main()
