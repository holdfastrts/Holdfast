#!/usr/bin/env python3
"""The Clockwork's games before and after (econ-coach-clockwork, docs/econ-coach-clockwork.md), from qa_match result files.
    python3 tools/study/econ_coach_cw_report.py BEFORE_DATA AFTER_DATA [...]
Per matchup, from the Clockwork's view (the mirror: both sides, W-D-L by the P1 spot): W-D-L, won or led (the qa-matches
rule: income earned + 2 x army value 10% ahead at the end), the Clockwork's cogs earned at 5/8/10/15 (mean), the foe's,
its share of the bench (docs/economy_parity/before/fix_clockwork.json, Greenhold: the Clockwork's bases are the same
rings everywhere), Winders at 8/10/15, Clocktowers at 5/8/10/15, army value at 8/10/15, idle Winders (mean of the
games' averages), and the decided games' length."""
import json, glob, os, sys, statistics as st

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
BENCH = {r["min"]: r["p_cum"] for r in json.load(open(os.path.join(ROOT, "docs/economy_parity/before/fix_clockwork.json")))["rows"]}
MATCH = {"crcw": "Crown v Clockwork", "brcw": "Brood v Clockwork", "cwcw": "Clockwork mirror"}


def at(d, p, t):
    for m in d["minutes"]:
        if m["p"] == p and m["t"] == t:
            return m
    last = None
    for m in d["minutes"]:
        if m["p"] == p and m["t"] <= t:
            last = m
    return last


def score(d, p):
    m = at(d, p, d["end"])
    return float(m["income"]) + 2.0 * float(m["army"]) if m else 0.0


def load(root):
    out = {}
    for f in sorted(glob.glob(os.path.join(root, "*", "result.json"))):
        d = json.load(open(f))
        tag = os.path.basename(os.path.dirname(f))
        k = tag.split("_")[-2]
        if k in MATCH:
            out.setdefault(k, []).append(d)
    return out


def summary(games, k):
    rows = []
    w = dr = l = led = 0
    lens = []
    for d in games:
        sides = [s[2] for s in d["slots"] if s[0] == "clockwork"]
        for p in sides:
            foe = 1 - p
            r = {}
            for t in (300, 480, 600, 900):
                a, b = at(d, p, t), at(d, foe, t)
                r["c%d" % t] = a["income"] if a else 0
                r["f%d" % t] = b["income"] if b else 0
                r["w%d" % t] = a["workers"] if a else 0
                r["h%d" % t] = a["halls"] if a else 0
                r["a%d" % t] = a["army"] if a else 0
            last = at(d, p, d["end"])
            r["idle"] = last.get("idle_w_avg", 0) if last else 0
            rows.append(r)
            if k == "cwcw" and p == 1:
                continue            # (the mirror: income from both sides, the result from the P1 spot's)
            if d.get("winner", -1) >= 0:
                lens.append(d["end"])
                if d["winner"] == p:
                    w += 1
                else:
                    l += 1
            else:
                dr += 1
            if d.get("winner", -1) == p or (d.get("winner", -1) < 0 and score(d, p) > 1.1 * score(d, foe)):
                led += 1
    return rows, (w, dr, l, led), lens


def mean(rows, k):
    v = [r[k] for r in rows]
    return st.mean(v) if v else 0


def main():
    dirs = sys.argv[1:]
    data = [load(x) for x in dirs]
    print("| matchup | data | games | W-D-L | won or led | Clockwork cogs 5:00 / 8:00 / 10:00 / 15:00 (share of the bench) | foe's | Winders 8/10/15 | Clocktowers 5/8/10/15 | army 8/10/15 | idle Winders | decided length |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for k in MATCH:
        for i, dd in enumerate(data):
            g = dd.get(k, [])
            if not g:
                continue
            rows, (w, dr, l, led), lens = summary(g, k)
            c = " / ".join("%d (%.2f)" % (mean(rows, "c%d" % t), mean(rows, "c%d" % t) / BENCH[t // 60]) for t in (300, 480, 600, 900))
            f = " / ".join("%d" % mean(rows, "f%d" % t) for t in (300, 480, 600, 900))
            print("| %s | %s | %d | %d-%d-%d | %d | %s | %s | %s | %s | %s | %.1f | %s |" % (
                MATCH[k], os.path.basename(dirs[i].rstrip("/")), len(g), w, dr, l, led, c, f,
                " / ".join("%.0f" % mean(rows, "w%d" % t) for t in (480, 600, 900)),
                " / ".join("%.1f" % mean(rows, "h%d" % t) for t in (300, 480, 600, 900)),
                " / ".join("%d" % mean(rows, "a%d" % t) for t in (480, 600, 900)),
                mean(rows, "idle"), ("%d:%02d" % divmod(int(st.median(lens)), 60)) if lens else "none"))


main()
