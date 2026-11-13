#!/usr/bin/env python3
"""The Clockwork computer alone against the bench (econ-coach-clockwork, docs/econ-coach-clockwork.md).
   python3 tools/study/econ_alone_cw_report.py DIR [DIR2 ...]
Per run: cogs at 5/8/10/12/15 min as a share of the bench's (docs/economy_parity: Greenhold before/fix_clockwork.json,
Hollowfen hollowfen/before_clockwork.json; other maps: Greenhold's, the Clockwork's bases are the same everywhere),
Winders at 8/10/15, halls at 5/8/10/15 (built), and the minute totals of the losses (supply-blocked s, empty-post
Winder-seconds, idle Winder-seconds, hall-idle s). With two DIRs: the same runs side by side (before -> after)."""
import json, os, sys, glob

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "economy_parity")
BENCH = {}
for m, f in (("greenhold", "before/fix_clockwork.json"), ("hollowfen", "hollowfen/before_clockwork.json")):
    p = os.path.join(ROOT, f)
    if os.path.exists(p):
        BENCH[m] = {r["min"]: r["p_cum"] for r in json.load(open(p))["rows"]}
AT = (5, 8, 10, 12, 15)


def load(d):
    out = {}
    for f in sorted(glob.glob(os.path.join(d, "*.json"))):
        try:
            r = json.load(open(f))
        except Exception:
            continue
        out[os.path.basename(f)[:-5]] = r
    return out


def summ(r):
    rows = {x["min"]: x for x in r["rows"]}
    b = BENCH.get(r["map"], BENCH["greenhold"])
    s = {}
    for m in AT:
        if m in rows:
            s["c%d" % m] = rows[m]["p_cum"]
            s["r%d" % m] = rows[m]["p_cum"] / b[m]
    for m in (5, 8, 10, 15):
        if m in rows:
            s["w%d" % m] = rows[m]["workers"]
            s["h%d" % m] = rows[m]["halls"]
            s["a%d" % m] = rows[m]["army"]
    for k in ("blocked", "empty_posts", "idle", "hall_idle"):
        s[k] = sum(x.get(k, 0) for x in r["rows"])
    s["plan"] = r["rows"][-1].get("plan", "") if r["rows"] else ""
    return s


def line(name, s):
    rr = " ".join("%.2f" % s.get("r%d" % m, 0) for m in AT)
    return "%-32s %-9s cogs15 %6d  share %s  W %s  halls %s  army15 %5d  blk %4d empty %6d idle %5d hidle %4d" % (
        name, s["plan"][:9], s.get("c15", 0), rr, "/".join(str(s.get("w%d" % m, "-")) for m in (8, 10, 15)),
        "/".join(str(s.get("h%d" % m, "-")) for m in (5, 8, 10, 15)), s.get("a15", 0), s["blocked"], s["empty_posts"], s["idle"], s["hall_idle"])


def main():
    dirs = sys.argv[1:]
    runs = [load(d) for d in dirs]
    print("share = the computer's cogs / the bench's at %s min" % "/".join(map(str, AT)))
    keys = sorted(set().union(*[set(r) for r in runs]))
    tot = [{} for _ in runs]
    for k in keys:
        for i, r in enumerate(runs):
            if k in r:
                s = summ(r[k])
                print(("  " if i else "") + line(("%s: " % os.path.basename(dirs[i].rstrip("/")) if len(runs) > 1 else "") + k, s))
                for m in AT:
                    tot[i].setdefault(m, []).append(s.get("r%d" % m, 0))
    for i, t in enumerate(tot):
        print("MEAN %-20s %s  (n=%d)" % (os.path.basename(dirs[i].rstrip("/")), " ".join("%.3f" % (sum(t[m]) / len(t[m])) for m in AT if t.get(m)), len(t.get(15, []))))


main()
