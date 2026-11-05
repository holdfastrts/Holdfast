#!/usr/bin/env python3
"""clockwork-army: the tables of docs/clockwork_army.md from tools/test_clockwork_army.gd json lines.
   python3 tools/clockwork_army_report.py all.jsonl
One row per game (before = `cwarmy:off`, after = the one army), then the averages per matchup."""
import json
import sys
from collections import defaultdict


def mm(d, k, f):
    return int(d.get("mins", {}).get(str(k), {}).get(f, 0))


def main(path):
    rows = {}
    for l in open(path):
        if l.strip():
            r = json.loads(l)
            rows[(r["map"], r["cw"], r["foe"], r["fp"], r["old"])] = r      # (a game run again: its last run)
    rows = list(rows.values())
    rows.sort(key=lambda r: (r["foe"], r["cw"], r["fp"], r["map"], not r["old"]))
    print("| map | Clockwork v foe | | alone (all) | alone away | 1st fight alone | Winders with it out | army 6:00 | 8:00 | 10:00 | killed / lost by 10:00 | end |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    agg = defaultdict(lambda: defaultdict(list))
    for r in rows:
        v = "before" if r["old"] else "after"
        e = r["end"]
        armies = []
        for k in (6, 8, 10):
            if str(k) in r["mins"]:
                armies.append("%d v %d" % (mm(r, k, "army"), mm(r, k, "farmy")))
            else:
                armies.append("-")
        w = r["winders_out"]
        ws = "%.1f (%d s)" % (w, r["out_time"]) if w >= 0 else "never out"
        end = {"clockwork": "Clockwork won", "foe": "lost", "none": "on"}.get(r["winner"], r["winner"])
        if r["winner"] == "none" and e["halls"] == 0:
            end = "no hall left"
        print("| %s | %s v %s %s | %s | %d | %d | %d | %s | %s | %s | %s | %d / %d | %s |" % (
            r["map"], r["cw"], r["foe"], r["fp"], v, r["lone_all"], r["lone_away"], r["first_alone"], ws,
            armies[0], armies[1], armies[2], e["killed"], e["lost"], end))
        key = "%s v %s %s" % (r["cw"], r["foe"], r["fp"])
        a = agg[(key, v)]
        a["lone"].append(r["lone_all"])
        a["away"].append(r["lone_away"])
        a["first"].append(r["first_alone"])
        if w >= 0:
            a["wout"].append(w)
        for k in (6, 8, 10):
            if str(k) in r["mins"]:
                a["a%d" % k].append(mm(r, k, "army"))
                a["f%d" % k].append(mm(r, k, "farmy"))
        a["killed"].append(e["killed"])
        a["lost"].append(e["lost"])
        a["won"].append(1 if r["winner"] == "clockwork" else 0)
        a["fell"].append(1 if r["winner"] == "foe" or e["halls"] == 0 else 0)

    def avg(x):
        return sum(x) / len(x) if x else float("nan")
    print()
    print("| matchup | | games | alone (all) | alone away | 1st fight alone | Winders with it out | army 6:00 | 8:00 | 10:00 | killed | lost | won | fell |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    tot = defaultdict(lambda: defaultdict(list))
    for (key, v) in sorted(agg):
        a = agg[(key, v)]
        print("| %s | %s | %d | %.1f | %.1f | %.1f | %.1f | %d v %d | %d v %d | %d v %d | %d | %d | %d | %d |" % (
            key, v, len(a["lone"]), avg(a["lone"]), avg(a["away"]), avg(a["first"]), avg(a["wout"]),
            avg(a["a6"]), avg(a["f6"]), avg(a["a8"]), avg(a["f8"]), avg(a["a10"]), avg(a["f10"]),
            avg(a["killed"]), avg(a["lost"]), sum(a["won"]), sum(a["fell"])))
        for k in a:
            tot[v][k].extend(a[k])
    print()
    for v in ("before", "after"):
        a = tot[v]
        if not a:
            continue
        print("ALL %s: %d games, alone %.1f, away %.1f, first alone %.1f, Winders out %.1f, army 6/8/10 %d/%d/%d, killed %d lost %d, won %d fell %d" % (
            v, len(a["lone"]), avg(a["lone"]), avg(a["away"]), avg(a["first"]), avg(a["wout"]), avg(a["a6"]), avg(a["a8"]),
            avg(a["a10"]), avg(a["killed"]), avg(a["lost"]), sum(a["won"]), sum(a["fell"])))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/gd/mx/all.jsonl")
