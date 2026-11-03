#!/usr/bin/env python3
"""The coached Balloon harass games' table (docs/crown_builds_c.md): python3 -I tools/play_crown_c_table.py <dir> [<dir> ...]
Each <dir> is a tools/play_crown_c.gd game folder (minutes.txt, harass.txt, result.txt, events.txt)."""
import os, re, sys


def mins(d):
    out = {}
    p = os.path.join(d, "minutes.txt")
    if not os.path.exists(p):
        return out
    for l in open(p):
        m = re.match(r"(\d\d)00 labourers (\d+).*?earned this minute (\d+) gold.*?\| army (\d+) .*?\| enemy army (\d+) .*?killed (\d+) lost (\d+)", l)
        if m:
            out[int(m.group(1))] = dict(labs=int(m.group(2)), gold=int(m.group(3)), army=int(m.group(4)), foe=int(m.group(5)), k=int(m.group(6)), l=int(m.group(7)))
    return out


def row(d):
    name = os.path.basename(d.rstrip("/"))
    mm = mins(d)
    res = open(os.path.join(d, "result.txt")).read().split() if os.path.exists(os.path.join(d, "result.txt")) else []
    clock = int(float(res[5])) if len(res) > 5 else 0
    win = res[3] if len(res) > 3 else "?"
    r = "alive %d:%02d" % (clock // 60, clock % 60) if res and res[1] == "false" else ("W" if win == "0" else "L") + " %d:%02d" % (clock // 60, clock % 60)
    g = lambda m, k: str(mm[m][k]) if m in mm else "-"
    last = mm[max(mm)] if mm else {"k": 0, "l": 0}
    h = ""
    hp = os.path.join(d, "harass.txt")
    if os.path.exists(hp):
        s = open(hp).readline()
        m = re.search(r"strikes (\d+) \(drops (\d+), lifts (\d+)\), first strike (\S+), first kill (\S+), killed (\d+) \((\d+) workers\), lost (\d+) balloons and (\d+) men", s)
        if m:
            h = "%s | %s | %s (%s) | %s / %s / %s | %s+%s" % (m.group(4), m.group(5), m.group(6), m.group(7), m.group(1), m.group(2), m.group(3), m.group(8), m.group(9))
    hall = "-"
    ep = os.path.join(d, "events.txt")
    if os.path.exists(ep):
        for l in open(ep):
            if "build order: Town Hall 2" in l:
                hall = l[:2] + ":" + l[2:4]
                break
    return "| %s | %s | %s/%s/%s | %s/%s | %s/%s | %s | %s | %s / %s | %s |" % (name, r, g(4, "labs"), g(6, "labs"), g(8, "labs"), g(6, "gold"), g(8, "gold"),
        g(6, "army"), g(8, "army"), g(8, "foe"), hall, last["k"], last["l"], h or "-")


print("| game | result | labourers 4/6/8 | gold a minute 6/8 | army 6/8 | enemy army 8 | 2nd hall | killed / lost | first strike, first kill, harass killed (workers), strikes / drops / lifts, balloons+men lost |")
print("|---|---|---|---|---|---|---|---|---|")
for d in sys.argv[1:]:
    print(row(d))
