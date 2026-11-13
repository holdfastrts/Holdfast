#!/usr/bin/env python3
"""ECONOMY PARITY (economy-parity, docs/economy_parity.md): the AI-game batch's tables and the game's PACE, from
tools/qa_match.gd result files (the same format as docs/qa_2026_11_08_matches/data).
    python3 tools/study/econ_parity_report.py DATA_DIR [DATA_DIR2 ...]     (several = one table each, side by side)
    python3 tools/study/econ_parity_report.py --json DATA_DIR               (the numbers as JSON, for the doc's charts)
Only two-player games with OPTIMAL on both sides are read.
- W-D-L: the first-named faction's view (mirrors: the P1 start spot's); a draw is no winner at the end; its LEADER is the
  side whose primary income earned + 2 x army value is 10% ahead (the qa-matches rule).
- income: primary resource earned (gold, biomass, cogs), cumulative, per faction, all its games.
- PACE: first attack (the computer's own first_attack event, the earliest of the two), first arrival (300+ army value in
  an enemy base), FIRST BIG FIGHT (the first minute in which the two sides together lose 1,000+ army value: the drop of
  army value plus what was trained meanwhile is not known per minute, so it is read as the fall of the two armies' value
  together by 500+ in a minute, or 20+ units lost together in a minute), first expansion (a second hall; the Brood: a third
  ground, its first far turtle being part of its start), 100 / 150 supply, game length (decided games), and draws."""
import json, glob, os, sys, statistics as st, collections

PAIRS = [("crown", "brood"), ("crown", "clockwork"), ("brood", "clockwork"),
         ("crown", "crown"), ("brood", "brood"), ("clockwork", "clockwork")]


def load(root):
    games = []
    for f in sorted(glob.glob(os.path.join(root, "*", "result.json"))):
        d = json.load(open(f))
        if len(d["slots"]) != 2 or any(s[1] != "optimal" for s in d["slots"]):
            continue
        d["tag"] = os.path.basename(os.path.dirname(f))
        games.append(d)
    return games


def rows(d, p):
    return [m for m in d["minutes"] if m["p"] == p]


def at(rs, t, k):
    for m in rs:
        if m["t"] >= t - 5:
            return m[k]
    return rs[-1][k] if rs else 0


def first_t(rs, pred):
    for m in rs:
        if pred(m):
            return m["t"]
    return None


def leader(d):
    if d.get("winner_side", -1) >= 0:
        return d["winner_side"]
    sc = []
    for p in range(2):
        rs = rows(d, p)
        sc.append(rs[-1]["income"] + 2 * rs[-1]["army"] if rs else 0)
    if sc[0] > 1.1 * sc[1]:
        return 0
    if sc[1] > 1.1 * sc[0]:
        return 1
    return -1


def mean(v):
    v = [x for x in v if x is not None]
    return st.mean(v) if v else None


def median(v):
    v = [x for x in v if x is not None]
    return st.median(v) if v else None


def fmt_t(s):
    if s is None:
        return "-"
    return "%d:%02d" % (int(s) // 60, int(s) % 60)


def analyse(games):
    out = {"pairs": {}, "income": {}, "pace": {}, "faction_pace": {}}
    inc = collections.defaultdict(lambda: collections.defaultdict(list))
    fpace = collections.defaultdict(lambda: collections.defaultdict(list))
    for a, b in PAIRS:
        gs = [d for d in games if sorted([d["slots"][0][0], d["slots"][1][0]]) == sorted([a, b])]
        w = dr = l = led = 0
        ratios = collections.defaultdict(list)
        army8 = []
        pace = collections.defaultdict(list)
        for d in gs:
            pa = 0 if d["slots"][0][0] == a else 1
            pb = 1 - pa
            win = d.get("winner_side", -1)
            if win < 0:
                dr += 1
            elif win == pa:
                w += 1
            else:
                l += 1
            ld = leader(d)
            if ld == pa:
                led += 1
            ra, rb = rows(d, pa), rows(d, pb)
            for t in (300, 480, 600, 900):
                ia, ib = at(ra, t, "income"), at(rb, t, "income")
                if ib > 0 and (ra and ra[-1]["t"] >= t - 5) and (rb and rb[-1]["t"] >= t - 5):
                    ratios[t].append(ia / ib)
            if at(rb, 480, "army") > 0:
                army8.append(at(ra, 480, "army") / at(rb, 480, "army"))
            ev = d["events"]
            fa = [e["t"] for e in ev if e["ev"] == "first_attack"]
            fr = [e["t"] for e in ev if e["ev"] == "first_arrival"]
            pace["first_attack"].append(min(fa) if fa else None)
            pace["first_arrival"].append(min(fr) if fr else None)
            # the first big fight: both armies together fall 500+ in a minute, or 20+ units lost together
            big = None
            n = min(len(ra), len(rb))
            for i in range(1, n):
                da = ra[i - 1]["army"] - ra[i]["army"]
                db = rb[i - 1]["army"] - rb[i]["army"]
                dl = (ra[i]["lost"] - ra[i - 1]["lost"]) + (rb[i]["lost"] - rb[i - 1]["lost"])
                if (max(0, da) + max(0, db) >= 500) or dl >= 20:
                    big = ra[i]["t"]
                    break
            pace["big_fight"].append(big)
            pace["length"].append(d["end"] if win >= 0 else None)
            pace["draw"].append(1 if win < 0 else 0)
            for p in (pa, pb) if a != b else (0, 1):
                fac = d["slots"][p][0]
                rs = rows(d, p)
                for t in (120, 180, 240, 300, 360, 480, 600, 720, 900):
                    if rs and rs[-1]["t"] >= t - 5:
                        inc[fac][t].append(at(rs, t, "income"))
                        fpace[fac]["workers_%d" % t].append(at(rs, t, "workers"))
                        fpace[fac]["army_%d" % t].append(at(rs, t, "army"))
                need = 3 if fac == "brood" else 2
                fpace[fac]["expand"].append(first_t(rs, lambda m: m["halls"] >= need))
                fpace[fac]["supply100"].append(first_t(rs, lambda m: m["supply"] >= 100))
                fpace[fac]["supply150"].append(first_t(rs, lambda m: m["supply"] >= 150))
        out["pairs"]["%s v %s" % (a, b)] = {"games": len(gs), "wdl": [w, dr, l], "led": led,
            "ratio": {t: (round(mean(v), 2) if v else None) for t, v in ratios.items()},
            "army8": round(mean(army8), 2) if army8 else None,
            "pace": {k: (median(v) if k != "draw" else sum(v)) for k, v in pace.items()},
            "pace_n": {k: len([x for x in v if x is not None]) for k, v in pace.items()}}
    for fac in inc:
        out["income"][fac] = {t: round(mean(v)) for t, v in sorted(inc[fac].items())}
        out["faction_pace"][fac] = {k: (round(mean(v)) if k.startswith(("workers", "army")) else median(v)) for k, v in fpace[fac].items()}
        out["faction_pace"][fac]["n_supply150"] = len([x for x in fpace[fac]["supply150"] if x is not None])
        out["faction_pace"][fac]["n_sides"] = len(fpace[fac]["expand"])
    allp = collections.defaultdict(list)
    for d in games:
        ev = d["events"]
        fa = [e["t"] for e in ev if e["ev"] == "first_attack"]
        allp["first_attack"].append(min(fa) if fa else None)
        fr = [e["t"] for e in ev if e["ev"] == "first_arrival"]
        allp["first_arrival"].append(min(fr) if fr else None)
        allp["length"].append(d["end"] if d.get("winner_side", -1) >= 0 else None)
    out["pace"] = {k: median(v) for k, v in allp.items()}
    out["pace"]["decided"] = len([x for x in allp["length"] if x is not None])
    out["pace"]["games"] = len(games)
    return out


def show(name, r):
    print("== %s (%d games, %d decided)" % (name, r["pace"]["games"], r["pace"]["decided"]))
    print("| matchup | games | W-D-L | won or led | income ratio 5:00 / 8:00 / 10:00 / 15:00 | army 8:00 | first attack | first arrival | first big fight | decided length |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for k, v in r["pairs"].items():
        rt = " / ".join("%.2f" % v["ratio"][t] if v["ratio"].get(t) else "-" for t in (300, 480, 600, 900))
        pc = v["pace"]
        print("| %s | %d | %d-%d-%d | %d | %s | %s | %s | %s | %s | %s |" % (k, v["games"], *v["wdl"], v["led"], rt,
              "%.2f" % v["army8"] if v["army8"] else "-", fmt_t(pc["first_attack"]), fmt_t(pc["first_arrival"]),
              fmt_t(pc["big_fight"]), fmt_t(pc["length"])))
    print("\nincome earned (cumulative, all games):")
    for fac, v in r["income"].items():
        print("  %-9s %s" % (fac, "  ".join("%s %d" % (fmt_t(t), x) for t, x in v.items())))
    print("\nper faction: first expansion, 100 / 150 supply (median), workers and army (mean) at 5:00 / 8:00 / 10:00:")
    for fac, v in r["faction_pace"].items():
        print("  %-9s expand %s  supply100 %s  supply150 %s (%d of %d sides)  workers %s/%s/%s  army %s/%s/%s" % (fac,
              fmt_t(v["expand"]), fmt_t(v["supply100"]), fmt_t(v["supply150"]), v["n_supply150"], v["n_sides"],
              v.get("workers_300"), v.get("workers_480"), v.get("workers_600"), v.get("army_300"), v.get("army_480"), v.get("army_600")))
    print()


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    res = {a: analyse(load(a)) for a in args}
    if "--json" in sys.argv:
        print(json.dumps(res, indent=1))
    else:
        for a, r in res.items():
            show(a, r)
