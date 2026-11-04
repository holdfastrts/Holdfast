#!/usr/bin/env python3
"""Tables for docs/clockwork_builds_c.md from the lines tools/test_clockwork_owls.gd appends with json:<file>.
    python3 -I tools/clockwork_owls_report.py <file.jsonl>"""
import json
import sys


def mmss(s):
    if s is None or s < 0:
        return "never"
    return "%d:%02d" % (int(s) // 60, int(s) % 60)


def main(path):
    rows = [json.loads(l) for l in open(path) if l.strip().startswith("{")]
    rows.sort(key=lambda r: (r["vs"], r["map"], r["seed"], {"owls": 0, "springer": 1, "balanced": 2}.get(r["cw"], 3)))
    print("| map, seed | enemy | plan | Aviary | TICKING OWL | 1st Owl | 3rd Owl | 1st sortie | 1st strike | 2nd hall laid |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        ms = r["ms"]
        print("| %s %d | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (r["map"], r["seed"], r["vs"], r["cw"], mmss(ms.get("aviary")),
              mmss(ms.get("owl_tech")), mmss(ms.get("owl1")), mmss(ms.get("owl3")), mmss(ms.get("sortie")), mmss(ms.get("strike")),
              mmss(ms.get("hall2_laid"))))
    print()
    print("| map, seed | enemy | plan | Winders 4/6/8 min | cogs earned 4/6/8 min | enemy earned 8/10 min | killed / lost by 6:00 | by 8:00 | by 10:00 | Owls killed (value, workers, buildings) | sorties | winner |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    agg = {}
    for r in rows:
        m = r["marks"]
        g = lambda t, k: m.get(t, r["end"]).get(k, 0)
        end = r["end"]
        print("| %s %d | %s | %s | %d / %d / %d | %d / %d / %d | %d / %d | %d / %d | %d / %d | %d / %d | %d, %d, %d | %d | %s%s |" % (
            r["map"], r["seed"], r["vs"], r["cw"], g("240", "cw_workers"), g("360", "cw_workers"), g("480", "cw_workers"),
            g("240", "cw_earned"), g("360", "cw_earned"), g("480", "cw_earned"), g("480", "op_earned"), end["op_earned"],
            g("360", "cw_killed"), g("360", "cw_lost"), g("480", "cw_killed"), g("480", "cw_lost"), end["cw_killed"], end["cw_lost"],
            end.get("owl_killed", 0), end.get("owl_workers", 0), end.get("owl_buildings", 0), r.get("sorties", 0), r["winner"],
            "" if r["clock"] >= 599 else " (%s)" % mmss(r["clock"])))
        a = agg.setdefault((r["cw"], r["vs"]), [])
        a.append(r)
    print()
    print("| plan, enemy | games | Winders 6:00 | earned 6:00 | earned 8:00 | killed / lost by 10:00 | Owls' kills by 10:00 | Clockwork lost the game |")
    print("|---|---|---|---|---|---|---|---|")
    for (cw, vs), a in sorted(agg.items(), key=lambda kv: (kv[0][1], {"owls": 0, "springer": 1, "balanced": 2}.get(kv[0][0], 3))):
        n = len(a)
        av = lambda f: sum(f(r) for r in a) / n
        w6 = av(lambda r: r["marks"].get("360", r["end"])["cw_workers"])
        e6 = av(lambda r: r["marks"].get("360", r["end"])["cw_earned"])
        e8 = av(lambda r: r["marks"].get("480", r["end"])["cw_earned"])
        k = av(lambda r: r["end"]["cw_killed"])
        lo = av(lambda r: r["end"]["cw_lost"])
        ok = av(lambda r: r["end"].get("owl_killed", 0))
        lost = sum(1 for r in a if r["winner"] not in ("none", "clockwork"))
        print("| %s v %s | %d | %.1f | %d | %d | %d / %d | %d | %d |" % (cw, vs, n, w6, e6, e8, k, lo, ok, lost))


main(sys.argv[1])
