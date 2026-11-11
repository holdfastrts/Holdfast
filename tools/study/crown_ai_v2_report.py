#!/usr/bin/env python3
"""CROWN AI V2 report (docs/crown_ai_v2.md): the Crown's numbers in Hard v Hard games, BEFORE (the qa-matches base games
on the same maps, seeds and sides, docs/qa_2026_11_08_matches/data, 0.33.7) and AFTER (tools/study/crown_ai_v2.py
measure). A measuring tool only.
    python3 tools/study/crown_ai_v2_report.py AFTER_DATA [BEFORE_DATA]
    python3 tools/study/crown_ai_v2_report.py --plans PLANS_DATA      (the plan sweep: each Crown plan v OPTIMAL)"""
import json, os, sys, collections

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import crown_ai_v2 as C


def load(d, tags=None):
    out = {}
    for t in sorted(os.listdir(d)):
        fn = os.path.join(d, t, "result.json")
        if (tags is None or t in tags) and os.path.exists(fn):
            out[t] = json.load(open(fn))
    return out


def result(d, p):
    """W / L / led / behind / even for player p (a draw's leader: income + 2 x army 10% ahead)"""
    if d.get("winner", -1) is not None and d.get("winner", -1) >= 0 and d.get("winner_side") is not None:
        return "W" if d["slots"][p][2] == d["winner_side"] else "L"
    f = d["final"]
    s = lambda q: f[q]["income"] + 2 * f[q]["army"]
    if s(p) > 1.1 * s(1 - p):
        return "led"
    if s(1 - p) > 1.1 * s(p):
        return "behind"
    return "even"


def at(d, p, t, k):
    a = [m for m in d["minutes"] if m["t"] == t and m["p"] == p]
    return a[0][k] if a else None


def side(d):
    fs = [s[0] for s in d["slots"]]
    p = fs.index("crown") if fs[0] != fs[1] else 0
    return fs[1 - p], p


def table(games, title):
    rows = collections.defaultdict(list)
    for t, d in games.items():
        foe, p = side(d)
        rows[foe].append((t, d, p))
    print("\n### " + title + "\n")
    print("| Crown v | games | W-D-L | won or led | income 5:00 | 8:00 | 10:00 | army 8:00 | halls 8:00 (Crown / foe) | Crown halls lost (built + sites) | same spot lost twice | Crown units stuck |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for foe in ("brood", "clockwork", "crown"):
        g = rows.get(foe, [])
        if not g:
            continue
        res = [result(d, p) for _, d, p in g]
        w = res.count("W"); l = res.count("L"); dr = len(res) - w - l
        wl = w + res.count("led")
        def ratio(tm, k="income"):
            xs = []
            for _, d, p in g:
                a, b = at(d, p, tm, k), at(d, 1 - p, tm, k)
                if a is not None and b:
                    xs.append(a / b)
            return "%.2f" % (sum(xs) / len(xs)) if xs else "-"
        def mean(tm, k, who):
            xs = [at(d, p if who == 0 else 1 - p, tm, k) for _, d, p in g]
            xs = [x for x in xs if x is not None]
            return "%.1f" % (sum(xs) / len(xs)) if xs else "-"
        hl = sum(1 for _, d, p in g for e in d["events"] if e["ev"] == "hall_lost" and e["p"] == p)
        twice = 0
        for _, d, p in g:
            c = collections.Counter(e["at"] for e in d["events"] if e["ev"] == "hall_lost" and e["p"] == p)
            twice += sum(1 for v in c.values() if v >= 2)
        stuck = sum(1 for _, d, p in g for e in d["events"] if e["ev"] == "stuck" and e["p"] == p)
        if foe == "crown":
            hl = sum(1 for _, d, p in g for e in d["events"] if e["ev"] == "hall_lost")
            stuck = sum(1 for _, d, p in g for e in d["events"] if e["ev"] == "stuck")
        print("| %s | %d | %d-%d-%d | %d | %s | %s | %s | %s | %s / %s | %d | %d | %d |" % (foe, len(g), w, dr, l, wl, ratio(300), ratio(480), ratio(600),
              ratio(480, "army"), mean(480, "halls", 0), mean(480, "halls", 1), hl, twice, stuck))
    return rows


def plans_table(games):
    rows = collections.defaultdict(list)
    for t, d in games.items():
        foe, p = side(d)
        rows[(foe, d["slots"][p][1])].append((t, d, p))
    print("| Crown plan | v OPTIMAL | games | results | won or led | income 5:00 | 8:00 | 10:00 | labourers 5:00 (Crown / foe) | halls 8:00 (Crown / foe) |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for (foe, plan) in sorted(rows, key=lambda k: (k[0], k[1])):
        g = rows[(foe, plan)]
        res = [result(d, p) for _, d, p in g]
        def ratio(tm):
            xs = [at(d, p, tm, "income") / at(d, 1 - p, tm, "income") for _, d, p in g if at(d, p, tm, "income") is not None and at(d, 1 - p, tm, "income")]
            return "%.2f" % (sum(xs) / len(xs)) if xs else "-"
        def mean(tm, k, who):
            xs = [at(d, p if who == 0 else 1 - p, tm, k) for _, d, p in g]
            xs = [x for x in xs if x is not None]
            return "%.1f" % (sum(xs) / len(xs)) if xs else "-"
        print("| %s | %s | %d | %s | %d | %s | %s | %s | %s / %s | %s / %s |" % (plan, foe, len(g), " ".join(res), sum(1 for r in res if r in ("W", "led")),
              ratio(300), ratio(480), ratio(600), mean(300, "workers", 0), mean(300, "workers", 1), mean(480, "halls", 0), mean(480, "halls", 1)))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    if sys.argv[1] == "--plans":
        plans_table(load(sys.argv[2]))
        sys.exit(0)
    after = load(sys.argv[1])
    before_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "docs/qa_2026_11_08_matches/data")
    tags = set(g[0] for g in C.measure())
    before = load(before_dir, tags & set(after.keys()) if after else tags)
    table(before, "Before (qa-matches, 0.33.7): %d games" % len(before))
    table(after, "After (crown-ai-v2): %d games" % len(after))
