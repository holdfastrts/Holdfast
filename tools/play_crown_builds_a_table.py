#!/usr/bin/env python3
"""The coached games table for docs/crown_builds_a.md (crown-builds-a, the Dragoon raids).

    python3 -I tools/play_crown_builds_a_table.py /abs/round_dir [names...]

Each game folder (tools/play_crown_builds_a.gd out:) has minutes.txt, events.txt, raid.txt and result.txt. One table row a
game: the result, labourers at 4/6/8 min, gold earned a minute at 6/8, the army at 6/8, the enemy army at 8, the second
hall, the first raid group out, enemy workers killed by 8:00 and by the end (by the raiders in brackets), the value the
raiders killed / lost, and the value killed / lost by the whole Crown at the end.
"""
import os
import re
import sys


def minute(lines, mm):
    for l in lines:
        if l.startswith(mm):
            return l
    return ""


def num(pat, s, default="-"):
    m = re.search(pat, s)
    return m.group(1) if m else default


def row(d):
    name = os.path.basename(d.rstrip("/"))
    try:
        mins = open(os.path.join(d, "minutes.txt")).read().splitlines()
    except OSError:
        return None
    ev = open(os.path.join(d, "events.txt")).read() if os.path.exists(os.path.join(d, "events.txt")) else ""
    res = open(os.path.join(d, "result.txt")).read() if os.path.exists(os.path.join(d, "result.txt")) else ""
    raid = open(os.path.join(d, "raid.txt")).read() if os.path.exists(os.path.join(d, "raid.txt")) else ""
    plan = num(r"plan (\w+)", raid, "?")
    over = "true" in num(r"over (\w+)", res, "false")
    win = num(r"winner (-?\d+)", res, "-1")
    clock = int(float(num(r"clock (\d+)", res, "0")))
    if over:
        result = ("W" if win == "0" else "L") + " %d:%02d" % (clock // 60, clock % 60)
    else:
        result = "alive %d:%02d" % (clock // 60, clock % 60)
    labs = "/".join(num(r"labourers (\d+)", minute(mins, m)) for m in ("0400", "0600", "0800"))
    gold = "/".join(num(r"earned this minute (\d+) gold", minute(mins, m)) for m in ("0600", "0800"))
    army = "/".join(num(r"\| army (\d+)", minute(mins, m)) for m in ("0600", "0800"))
    earmy = num(r"enemy army (\d+)", minute(mins, "0800"))
    hall = num(r"(\d{4}) build order: Town Hall 2", ev)
    hall = hall[:2] + ":" + hall[2:] if hall != "-" else "-"
    grp = num(r"(\d{4}) raid: group 1 forms", ev)
    grp = grp[:2] + ":" + grp[2:] if grp != "-" else "-"
    w8 = minute(mins, "0800")
    wk8 = "%s (%s)" % (num(r"workers killed (\d+)", w8), num(r"workers killed \d+ \(raid (\d+)\)", w8))
    last = mins[-1] if mins else ""
    wk_end = "%s (%s)" % (num(r"workers killed (\d+)", raid), num(r"by the raiders (\d+)", raid))
    rkl = "%s / %s" % (num(r"raid value killed (\d+)", raid), num(r"raid value killed \d+ lost (\d+)", raid))
    kl = "%s / %s" % (num(r"killed (\d+) lost", last), num(r"killed \d+ lost (\d+)", last))
    strikes = num(r"strikes (\d+)", raid, "0")
    leaves = num(r"leaves (\d+)", raid, "0")
    return "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s/%s | %s |" % (
        name, plan, result, labs, gold, army, earmy, hall, grp, wk8, wk_end, rkl, strikes, leaves, kl)


def main():
    root = sys.argv[1]
    names = sys.argv[2:] or sorted(n for n in os.listdir(root) if os.path.isdir(os.path.join(root, n)))
    print("| game | plan | result | labourers 4/6/8 | gold a minute 6/8 | army 6/8 | enemy army 8 | 2nd hall | 1st raid group | workers killed by 8:00 (raid) | workers killed at the end (raid) | raid killed / lost | strikes/leaves | killed / lost |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for n in names:
        r = row(os.path.join(root, n))
        if r:
            print(r)


if __name__ == "__main__":
    main()
