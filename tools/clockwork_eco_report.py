#!/usr/bin/env python3
"""clockwork-eco: tables from tools/test_clockwork_eco.gd's json lines (docs/clockwork_eco.md).
   python3 -I tools/clockwork_eco_report.py games.json [more.json ...]
Prints markdown: when things happen, the economy minute by minute (before / after), and the averages."""
import json
import sys


def mmss(s):
    if s is None or s < 0 or s >= 9999:
        return "never"
    s = int(s)
    return "%d:%02d" % (s // 60, s % 60)


def label(r):
    v = "old" if r.get("old") else "new"
    return "%s %s" % (r["cw"].capitalize(), v)


def m(r, k, f):
    mm = r.get("mins", {}).get(str(k))
    if mm is None:
        return None
    return mm.get(f)


def fmt(x):
    return "-" if x is None else str(x)


def main(paths):
    rows = []
    for p in paths:
        with open(p) as fh:
            for line in fh:
                line = line.strip()
                if line:
                    rows.append(json.loads(line))
    rows.sort(key=lambda r: (r["foe"], r["fp"], r["map"], r["cw"], not r.get("old")))
    print("### When things happen\n")
    print("| map | foe | plan | rush seen | 1st Light Works | 1st soldier | 2nd Clocktower laid | up | Mainspring | Escapement | 3rd Clocktower | 2nd's ring (of 9) |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        ms = r["ms"]
        h2 = r.get("hall2", [-1, -1, -1, -1])
        print("| %s | %s %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            r["map"], r["foe"], r["fp"], label(r), mmss(ms.get("rush_seen")), mmss(ms.get("works")), mmss(ms.get("army1")),
            mmss(ms.get("hall2_laid")), mmss(ms.get("hall2")), mmss(ms.get("mainspring_laid")), mmss(ms.get("escapement_laid")),
            mmss(ms.get("hall3_laid")), h2[2] if h2[0] >= 0 else "-"))
    print("\n### The economy, minute by minute (Winders / cogs earned; the enemy's earned)\n")
    print("| map | foe | plan | Winders 2/3/4/5/6/8 | earned 3/4/5/6/8/10 | foe earned 4/6/8/10 | army 4/6/8 (foe) | killed / lost by 10 | bld lost | winner |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        w = "/".join(fmt(m(r, k, "w")) for k in (2, 3, 4, 5, 6, 8))
        e = "/".join(fmt(m(r, k, "earned")) for k in (3, 4, 5, 6, 8, 10))
        fe = "/".join(fmt(m(r, k, "fearned")) for k in (4, 6, 8, 10))
        ar = "/".join("%s (%s)" % (fmt(m(r, k, "army")), fmt(m(r, k, "farmy"))) for k in (4, 6, 8))
        end = r["end"]
        print("| %s | %s %s | %s | %s | %s | %s | %s | %d / %d | %d | %s%s |" % (
            r["map"], r["foe"], r["fp"], label(r), w, e, fe, ar, end["killed"], end["lost"], end["bld_lost"], r["winner"],
            "" if r["winner"] == "none" else " (%s)" % mmss(r["clock"])))
    print("\n### Averages\n")
    print("| foe | plan | games | Winders 4:00 | Winders 6:00 | earned 4:00 | earned 6:00 | earned 8:00 | foe earned 8:00 | 2nd Clocktower laid | killed / lost by 10 | lost games |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    groups = {}
    for r in rows:
        groups.setdefault((r["foe"] + " " + r["fp"], label(r)), []).append(r)

    def avg(lst):
        lst = [x for x in lst if x is not None]
        return "%.0f" % (sum(lst) / len(lst)) if lst else "-"

    def avg1(lst):
        lst = [x for x in lst if x is not None]
        return "%.1f" % (sum(lst) / len(lst)) if lst else "-"
    for (foe, lab), rs in sorted(groups.items()):
        h2 = [r["ms"].get("hall2_laid") for r in rs]
        h2v = [x for x in h2 if x is not None]
        print("| %s | %s | %d | %s | %s | %s | %s | %s | %s | %s | %s / %s | %d |" % (
            foe, lab, len(rs), avg1([m(r, 4, "w") for r in rs]), avg1([m(r, 6, "w") for r in rs]),
            avg([m(r, 4, "earned") for r in rs]), avg([m(r, 6, "earned") for r in rs]), avg([m(r, 8, "earned") for r in rs]),
            avg([m(r, 8, "fearned") for r in rs]), mmss(sum(h2v) / len(h2v)) if h2v else "never",
            avg([r["end"]["killed"] for r in rs]), avg([r["end"]["lost"] for r in rs]), sum(1 for r in rs if r["winner"] == "foe")))


if __name__ == "__main__":
    main(sys.argv[1:])
