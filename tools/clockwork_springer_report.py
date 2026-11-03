#!/usr/bin/env python3
"""Tables for docs/clockwork_ai_rebuild.md from the JSON lines written by tools/test_clockwork_springer_timing.gd (json:<file>).
    python3 -I tools/clockwork_springer_report.py <file.jsonl>
"""
import json
import sys


def mmss(s):
    if s is None or s != s or s < 0:
        return "never"
    return "%d:%02d" % (int(s) // 60, int(s) % 60)


def main(path):
    rows = [json.loads(l) for l in open(path) if l.strip()]
    print("| map, seed | Crown | plan | Works | Mainspring | Escapement | HIGH LEAP | 4th Springer | Swift | READY | attack | 1st leap | 2nd hall laid |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        ms = r["ms"]
        print("| %s %d | %s | %s | %s |" % (r["map"], r["seed"], r["dcr"], r["cw"], " | ".join(mmss(ms.get(k)) for k in
              ["works", "mainspring", "escapement", "high_leap", "springer4", "swift", "ready", "attack", "leap", "hall2_laid"])))
    print()
    print("| map, seed | Crown | plan | Winders 6:00 | cogs earned 6:00 | Winders 8:00 | cogs earned 8:00 | army 8:00 (CW / Crown) | Crown workers lost by 6:00 / 10:00 | value killed / lost by 6:00 | by 10:00 | winner |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        m = r["marks"]
        m6, m8, e = m.get("360", {}), m.get("480", {}), r["end"]
        print("| %s %d | %s | %s | %s | %s | %s | %s | %s / %s | %s / %s | %s / %s | %s / %s | %s |" % (r["map"], r["seed"], r["dcr"], r["cw"],
              m6.get("cw_workers"), m6.get("cw_earned"), m8.get("cw_workers"), m8.get("cw_earned"), m8.get("cw_army"), m8.get("cr_army"),
              m6.get("cr_workers_lost"), e.get("cr_workers_lost"), m6.get("cw_killed"), m6.get("cw_lost"), e.get("cw_killed"), e.get("cw_lost"),
              r["winner"] if r["winner"] != "none" else "none by %s" % mmss(r["clock"])))
    # averages, plan against plan
    print()
    for plan in sorted(set(r["cw"] for r in rows)):
        for lv in sorted(set(r["dcr"] for r in rows)):
            rs = [r for r in rows if r["cw"] == plan and r["dcr"] == lv]
            if not rs:
                continue
            def avg(f):
                v = [f(r) for r in rs if f(r) is not None]
                return sum(v) / len(v) if v else float("nan")
            print("%s v %s Crown (%d games): Winders 6:00 %.1f, 8:00 %.1f; earned 6:00 %.0f, 8:00 %.0f; READY %s; killed/lost by 6:00 %.0f/%.0f, by 10:00 %.0f/%.0f; Crown workers lost by 10:00 %.1f" % (
                plan, lv, len(rs), avg(lambda r: r["marks"].get("360", {}).get("cw_workers")), avg(lambda r: r["marks"].get("480", {}).get("cw_workers")),
                avg(lambda r: r["marks"].get("360", {}).get("cw_earned")), avg(lambda r: r["marks"].get("480", {}).get("cw_earned")),
                mmss(avg(lambda r: r["ms"].get("ready"))), avg(lambda r: r["marks"].get("360", {}).get("cw_killed")), avg(lambda r: r["marks"].get("360", {}).get("cw_lost")),
                avg(lambda r: r["end"].get("cw_killed")), avg(lambda r: r["end"].get("cw_lost")), avg(lambda r: r["end"].get("cr_workers_lost"))))


if __name__ == "__main__":
    main(sys.argv[1])
