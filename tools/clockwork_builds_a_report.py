#!/usr/bin/env python3
"""Tables for docs/clockwork_builds_a.md from the json lines of tools/test_clockwork_builds_a.gd (json:<file>).
    python3 -I tools/clockwork_builds_a_report.py <file.json> [more.json ...]"""
import json
import sys

NAMES = {"cs_rush": "Clock Soldier rush", "turtle": "Turret turtle", "rush": "old Rush", "balanced": "old Balanced",
         "springer": "Springer timing", "economy": "old Economy"}


def mmss(s):
    if s is None or s < 0:
        return "never"
    s = int(s)
    return "%d:%02d" % (s // 60, s % 60)


def load(paths):
    rows = []
    for p in paths:
        for line in open(p):
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def mk(r, m, k):
    return r["marks"].get(m, r["end"]).get(k, 0)


def main():
    rows = load(sys.argv[1:])
    rows.sort(key=lambda r: (r["foe"], r["map"], r["seed"], r["cw"]))
    print("### When things happen\n")
    print("| map, seed | foe | plan | Works | 5th soldier | rush out | arrives | verdict | 1st turret | 2nd turret | 2nd hall laid | 2nd hall up | Mainspring |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        ms = r["ms"]
        v = "never"
        if "failed" in ms:
            v = "FAILED " + mmss(ms["failed"])
        elif "succeeded" in ms:
            v = "SUCCEEDED " + mmss(ms["succeeded"])
        ro = mmss(ms.get("rush", ms.get("wave1", -1)))
        if "rush" not in ms and "wave1" in ms:
            ro += " (wave)"
        print("| %s %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            r["map"], r["seed"], r["foe"], NAMES.get(r["cw"], r["cw"]), mmss(ms.get("works", -1)), mmss(ms.get("cs5", -1)),
            ro, mmss(ms.get("arrive", -1)), v, mmss(ms.get("turret1", -1)), mmss(ms.get("turret2", -1)),
            mmss(ms.get("hall2_laid", -1)), mmss(ms.get("hall2", -1)), mmss(ms.get("mainspring", -1))))
    print("\n### Economy and fights\n")
    print("| map, seed | foe | plan | Winders 4/6/8 | cogs earned 4/6/8 | foe earned 4/6/8 | foe workers lost 4/6/10 | killed / lost by 6:00 | by 10:00 | buildings lost (CW / foe) | winner |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        e = r["end"]
        print("| %s %d | %s | %s | %d / %d / %d | %d / %d / %d | %d / %d / %d | %d / %d / %d | %d / %d | %d / %d | %d / %d | %s |" % (
            r["map"], r["seed"], r["foe"], NAMES.get(r["cw"], r["cw"]),
            mk(r, "240", "cw_workers"), mk(r, "360", "cw_workers"), mk(r, "480", "cw_workers"),
            mk(r, "240", "cw_earned"), mk(r, "360", "cw_earned"), mk(r, "480", "cw_earned"),
            mk(r, "240", "foe_earned"), mk(r, "360", "foe_earned"), mk(r, "480", "foe_earned"),
            mk(r, "240", "foe_workers_lost"), mk(r, "360", "foe_workers_lost"), e["foe_workers_lost"],
            mk(r, "360", "cw_killed"), mk(r, "360", "cw_lost"), e["cw_killed"], e["cw_lost"],
            e["cw_bld_lost"], e["foe_bld_lost"], r["winner"] if r["winner"] != "none" else "none by %s" % mmss(r["clock"])))
    print("\n### Averages\n")
    print("| plan | foe | games | Winders 6:00 | earned 4:00 | earned 6:00 | earned 8:00 | foe earned 8:00 | killed / lost by 10:00 | CW buildings lost | won / lost |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    keys = sorted(set((r["cw"], r["foe"]) for r in rows), key=lambda k: (k[1], k[0]))
    for k in keys:
        rs = [r for r in rows if (r["cw"], r["foe"]) == k]
        n = len(rs)
        avg = lambda f: sum(f(r) for r in rs) / n
        won = sum(1 for r in rs if r["winner"] == "clockwork")
        lost = sum(1 for r in rs if r["winner"] == "foe")
        print("| %s | %s | %d | %.1f | %d | %d | %d | %d | %d / %d | %.1f | %d / %d |" % (
            NAMES.get(k[0], k[0]), k[1], n, avg(lambda r: mk(r, "360", "cw_workers")), avg(lambda r: mk(r, "240", "cw_earned")),
            avg(lambda r: mk(r, "360", "cw_earned")), avg(lambda r: mk(r, "480", "cw_earned")), avg(lambda r: mk(r, "480", "foe_earned")),
            avg(lambda r: r["end"]["cw_killed"]), avg(lambda r: r["end"]["cw_lost"]), avg(lambda r: r["end"]["cw_bld_lost"]), won, lost))


main()
