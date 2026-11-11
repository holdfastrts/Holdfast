#!/usr/bin/env python3
"""START SPOTS report (docs/start_spots_study.md): reads the mirror games (docs/start_spots_study/data/<tag>/
result.json, meta.json, layout.json) and prints the tables: per map and per faction, spot A (the map's first start, top /
left) against spot B, and player index 0 against index 1, won / led / even; the base layouts of the two spots.
Also reads the QA match study's mirror games (docs/qa_2026_11_08_matches/data, index 0 = spot A always) with --qa.
A draw's LEADER: income earned + 2 x army value 10% ahead (docs/qa_2026_11_08_matches.md). Measuring only.
    python3 tools/study/start_spots_report.py [DATA] [--qa]"""
import json, os, sys, glob, math

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else os.path.join(ROOT, "docs/start_spots_study/data")
QA = os.path.join(ROOT, "docs/qa_2026_11_08_matches/data")
NAMED = ["ashford_crossing", "kestrel_rise", "thornwood_maze", "redrock_canyon", "saltmarsh_isles", "glimmerdeep",
         "frostmere", "cinder_steps", "hollowfen", "amberfall_vale"]


def outcome(res):
    """per player index: 'W' won, 'L' lost, 'w' led a draw, 'l' trailed, 'd' even"""
    if res["winner"] >= 0:
        return ["W" if i == res["winner"] else "L" for i in range(2)]
    sc = [f["income"] + 2 * f["army"] for f in res["final"]]
    if sc[0] > 1.1 * sc[1]:
        return ["w", "l"]
    if sc[1] > 1.1 * sc[0]:
        return ["l", "w"]
    return ["d", "d"]


def at_min(res, p, key, mm):
    for r in res["minutes"]:
        if r["p"] == p and r["t"] == mm * 60:
            return r.get(key)
    return None


def load(data, qa=False, qa_cross=False):
    games = []
    for dd in sorted(glob.glob(os.path.join(data, "*"))):
        rf = os.path.join(dd, "result.json")
        if not os.path.exists(rf):
            continue
        res = json.load(open(rf))
        tag = os.path.basename(dd)
        if qa:
            if not tag.startswith("base_") or len(res["slots"]) != 2:
                continue
            fac = res["slots"][0][0]
            if res["slots"][1][0] != fac:
                if not qa_cross:
                    continue
                fac = res["slots"][0][0] + "-" + res["slots"][1][0]
            meta = {"map": res["map"], "fac": fac, "swap": False, "spotA_index": 0}
        else:
            meta = json.load(open(os.path.join(dd, "meta.json")))
        lay = None
        lf = os.path.join(dd, "layout.json")
        if os.path.exists(lf):
            lay = json.load(open(lf))
        o = outcome(res)
        a = meta["spotA_index"]
        games.append({"tag": tag, "map": meta["map"], "fac": meta["fac"], "swap": meta["swap"], "a": a, "res": res,
                      "out": o, "spotA": o[a], "idx0": o[0], "lay": lay})
    return games


def score(outs):
    """W-L (decided), won-or-led - trailed-or-lost, even"""
    W = sum(1 for x in outs if x == "W")
    L = sum(1 for x in outs if x == "L")
    wl = sum(1 for x in outs if x in "Ww")
    ll = sum(1 for x in outs if x in "Ll")
    d = sum(1 for x in outs if x == "d")
    return W, L, wl, ll, d


def binom_p(k, n):
    """two-sided exact binomial p for k of n at 1/2"""
    if n == 0:
        return 1.0
    pk = [math.comb(n, i) / 2 ** n for i in range(n + 1)]
    obs = pk[k]
    return min(1.0, sum(p for p in pk if p <= obs + 1e-12))


def fmt(outs):
    W, L, wl, ll, d = score(outs)
    return "%d-%d | %d-%d-%d | %.2f" % (W, L, wl, ll, d, binom_p(wl, wl + ll))


def layout_metrics(g, mm):
    """per spot (A, B): the mean 'frontness' of its buildings (tiles toward the enemy's hall along the line between the
    halls, from its own hall), how many stand in front (> 4 tiles forward), the mean sideways offset (+ = to the left
    looking at the enemy), and its army centre's frontness"""
    lay = g["lay"]
    if not lay:
        return None
    row = None
    for r in lay["rows"]:
        if r["t"] <= mm * 60 + 5:
            row = r
    if row is None:
        return None
    st = lay["starts"]
    mids = [(s[0] + 2.5, s[1] + 2.0) for s in st]
    out = []
    for spot in (0, 1):
        p = g["a"] if spot == 0 else 1 - g["a"]
        me, foe = mids[p], mids[1 - p]
        dx, dy = foe[0] - me[0], foe[1] - me[1]
        ln = math.hypot(dx, dy)
        ux, uy = dx / ln, dy / ln
        fr, side, front = [], [], 0
        for b in row["p"][p]["b"]:
            if b[0] in ("wall", "gate", "palisade"):
                continue
            vx, vy = b[1] - me[0], b[2] - me[1]
            f = vx * ux + vy * uy
            s = vx * uy - vy * ux     # + = left of the line looking at the enemy (screen y down)
            if math.hypot(vx, vy) > 30:
                continue           # (an expansion's buildings: not the main's layout)
            fr.append(f)
            side.append(s)
            if f > 4:
                front += 1
        ac = row["p"][p]["army_c"]
        af = None
        if ac:
            af = (ac[0] - me[0]) * ux + (ac[1] - me[1]) * uy
        out.append({"n": len(fr), "front_mean": sum(fr) / len(fr) if fr else 0, "in_front": front,
                    "side_mean": sum(side) / len(side) if side else 0, "army_front": af,
                    "army_v": row["p"][p]["army_v"]})
    return out


def mirror_gap(g, mm):
    """how far spot B's main buildings stand from where spot A's mirrored ones are: each of B's buildings (mirrored back
    through the map's centre) to the nearest unused A building of the same kind, mean tiles (0 = mirrored bases); and
    the share of buildings with no partner of the same kind"""
    lay = g["lay"]
    if not lay:
        return None
    row = None
    for r in lay["rows"]:
        if r["t"] <= mm * 60 + 5:
            row = r
    if row is None:
        return None
    W, H = lay["size"]
    pa, pb = g["a"], 1 - g["a"]
    ma = (lay["starts"][pa][0] + 2.5, lay["starts"][pa][1] + 2.0)
    mb = (lay["starts"][pb][0] + 2.5, lay["starts"][pb][1] + 2.0)
    A = [b for b in row["p"][pa]["b"] if math.hypot(b[1] - ma[0], b[2] - ma[1]) <= 30]
    B = [b for b in row["p"][pb]["b"] if math.hypot(b[1] - mb[0], b[2] - mb[1]) <= 30]
    used = set()
    ds = []
    lone = 0
    for b in B:
        x, y = W - b[1], H - b[2]
        best, bi = None, None
        for i, a in enumerate(A):
            if i in used or a[0] != b[0]:
                continue
            d = math.hypot(a[1] - x, a[2] - y)
            if best is None or d < best:
                best, bi = d, i
        if bi is None:
            lone += 1
        else:
            used.add(bi)
            ds.append(best)
    return (sum(ds) / len(ds) if ds else 0.0, lone, len(B))


if __name__ == "__main__":
    games = load(DATA) if os.path.isdir(DATA) else []
    print("## %d mirror games\n" % len(games))
    print("Per map: spot A's view (W-L decided | won-or-led - trailed - even | two-sided binomial p of won-or-led)\n")
    print("| map | named? | games | spot A | Crown | Brood | Clockwork | index 0 (all) |")
    print("|---|---|---|---|---|---|---|---|")
    maps = []
    for g in games:
        if g["map"] not in maps:
            maps.append(g["map"])
    for m in maps:
        gs = [g for g in games if g["map"] == m]
        per = []
        for f in ("crown", "brood", "clockwork"):
            o = [g["spotA"] for g in gs if g["fac"] == f]
            per.append("".join(o) or "-")
        print("| %s | %s | %d | %s | %s | %s | %s | %s |" % (m, "yes" if m in NAMED else "no", len(gs), fmt([g["spotA"] for g in gs]),
              per[0], per[1], per[2], fmt([g["idx0"] for g in gs])))
    print()
    print("| group | games | spot A: W-L / won-or-led-trailed-even / p | index 0: same |")
    print("|---|---|---|---|")
    groups = [("all", games), ("suspect P1 maps", [g for g in games if g["map"] in ("red_coast", "frostfang", "ashfall", "redrock_canyon", "mirewood")]),
              ("suspect P2 maps", [g for g in games if g["map"] in ("thornwood_maze", "amberfall_vale")]),
              ("controls", [g for g in games if g["map"] in ("greenhold", "ashford_crossing", "kestrel_rise")]),
              ("classic maps (index 0 = spot A)", [g for g in games if g["map"] not in NAMED]),
              ("named maps, not swapped", [g for g in games if g["map"] in NAMED and not g["swap"]]),
              ("named maps, SWAPPED (index 0 on spot B)", [g for g in games if g["swap"]])]
    for f in ("crown", "brood", "clockwork"):
        groups.append((f + " mirrors", [g for g in games if g["fac"] == f]))
    for name, gs in groups:
        print("| %s | %d | %s | %s |" % (name, len(gs), fmt([g["spotA"] for g in gs]), fmt([g["idx0"] for g in gs])))
    print()
    # income at 8:00 and 10:00, spot A over spot B
    print("| group | income A/B 5:00 | 8:00 | 10:00 | army A/B 8:00 | 10:00 |")
    print("|---|---|---|---|---|---|")
    for name, gs in groups:
        cells = []
        for key, mm in (("income", 5), ("income", 8), ("income", 10), ("army", 8), ("army", 10)):
            rs = []
            for g in gs:
                a = at_min(g["res"], g["a"], key, mm)
                b = at_min(g["res"], 1 - g["a"], key, mm)
                if a is not None and b is not None and a + b > 0:
                    rs.append(math.log((a + 1) / (b + 1)))
            cells.append("%.2f (n %d)" % (math.exp(sum(rs) / len(rs)), len(rs)) if rs else "-")
        print("| %s | %s |" % (name, " | ".join(cells)))
    print()
    print("Early economy, spot A's income over spot B's (geometric mean over games; the same seeds' early minutes repeat, so these are close to deterministic)\n")
    print("| faction | group | games | 1:00 | 2:00 | 3:00 | 5:00 | 8:00 | 12:00 |")
    print("|---|---|---|---|---|---|---|---|---|")
    for f in ("crown", "brood", "clockwork"):
        for gname, cond in (("not swapped", lambda g: not g["swap"]), ("swapped (index 0 on B)", lambda g: g["swap"])):
            gs = [g for g in games if g["fac"] == f and cond(g)]
            if not gs:
                continue
            cells = []
            for mm in (1, 2, 3, 5, 8, 12):
                rs = []
                for g in gs:
                    a = at_min(g["res"], g["a"], "income", mm)
                    b = at_min(g["res"], 1 - g["a"], "income", mm)
                    if a and b:
                        rs.append(math.log(a / b))
                cells.append("%.3f" % math.exp(sum(rs) / len(rs)) if rs else "-")
            print("| %s | %s | %d | %s |" % (f, gname, len(gs), " | ".join(cells)))
    print()
    print("Timings by spot (mean seconds; n = games where both sides have it): the first scout READ, the first attack, the first arrival in the enemy base (300+ army value)\n")
    print("| faction | group | first read A / B | first attack A / B | first arrival A / B | halls lost A / B |")
    print("|---|---|---|---|---|---|")
    for f in ("crown", "brood", "clockwork"):
        for gname, cond in (("not swapped", lambda g: not g["swap"]), ("swapped", lambda g: g["swap"]), ("all", lambda g: True)):
            gs = [g for g in games if g["fac"] == f and cond(g)]
            if not gs:
                continue
            cells = []
            for kind in ("read", "first_attack", "first_arrival"):
                pa, pb = [], []
                for g in gs:
                    a = g["a"]
                    if kind == "read":
                        ts = [[x["t"] for x in g["res"]["reads"] if x["p"] == p and "read" in x] for p in (a, 1 - a)]
                    else:
                        ts = [[e["t"] for e in g["res"]["events"] if e["ev"] == kind and e["p"] == p] for p in (a, 1 - a)]
                    if ts[0] and ts[1]:
                        pa.append(min(ts[0]))
                        pb.append(min(ts[1]))
                cells.append("%d / %d (n %d)" % (sum(pa) / len(pa), sum(pb) / len(pb), len(pa)) if pa else "-")
            hl = [0, 0]
            for g in gs:
                for e in g["res"]["events"]:
                    if e["ev"] == "hall_lost":
                        hl[0 if e["p"] == g["a"] else 1] += 1
            cells.append("%d / %d" % tuple(hl))
            print("| %s | %s | %s |" % (f, gname, " | ".join(cells)))
    print()
    print("Base layouts (main only, buildings within 30 tiles of the hall): spot A / spot B means\n")
    print("| map | minute | buildings | frontness (tiles toward the enemy) | buildings > 4 tiles in front | sideways (+ left) | army centre frontness |")
    print("|---|---|---|---|---|---|---|")
    for m in maps + ["ALL"]:
        gs = [g for g in games if (g["map"] == m or m == "ALL") and g["lay"]]
        for mm in (4, 8):
            ms = [layout_metrics(g, mm) for g in gs]
            ms = [x for x in ms if x]
            if not ms:
                continue

            def mean(k, s):
                v = [x[s][k] for x in ms if x[s][k] is not None]
                return sum(v) / len(v) if v else float("nan")
            print("| %s | %d | %.1f / %.1f | %.1f / %.1f | %.1f / %.1f | %.1f / %.1f | %.1f / %.1f |" % (
                m, mm, mean("n", 0), mean("n", 1), mean("front_mean", 0), mean("front_mean", 1), mean("in_front", 0),
                mean("in_front", 1), mean("side_mean", 0), mean("side_mean", 1), mean("army_front", 0), mean("army_front", 1)))
    print()
    print("Mirror gap: spot B's main buildings mirrored back onto spot A's (mean tiles to the nearest same-kind building; 0 = the two bases are mirror images)\n")
    print("| map | Crown 4:00 | 8:00 | Brood 4:00 | 8:00 | Clockwork 4:00 | 8:00 |")
    print("|---|---|---|---|---|---|---|")
    for m in maps:
        cells = []
        for f in ("crown", "brood", "clockwork"):
            for mm in (4, 8):
                v = [mirror_gap(g, mm) for g in games if g["map"] == m and g["fac"] == f and g["lay"]]
                v = [x for x in v if x and x[2] > 0]
                cells.append("%.1f" % (sum(x[0] for x in v) / len(v)) if v else "-")
        print("| %s | %s |" % (m, " | ".join(cells)))
    if "--qa" in sys.argv:
        q = load(QA, qa=True)
        print("\n## QA match study mirrors (index 0 = spot A): %d games\n" % len(q))
        print("| map | spot A |")
        print("|---|---|")
        for m in sorted(set(g["map"] for g in q)):
            print("| %s | %s |" % (m, fmt([g["spotA"] for g in q if g["map"] == m])))
        print("| ALL | %s |" % fmt([g["spotA"] for g in q]))
        qc = load(QA, qa=True, qa_cross=True)
        print("\nQA match study, ALL base games (cross games too; index 0 = spot A): %d games\n" % len(qc))
        print("| group | games | spot A: W-L / won-or-led-trailed-even / p |")
        print("|---|---|---|")
        for name, gs in (("classic maps", [g for g in qc if g["map"] not in NAMED]), ("named maps", [g for g in qc if g["map"] in NAMED]),
                         ("classic mirrors", [g for g in q if g["map"] not in NAMED]), ("named mirrors", [g for g in q if g["map"] in NAMED]),
                         ("all", qc)):
            print("| %s | %d | %s |" % (name, len(gs), fmt([g["spotA"] for g in gs])))
