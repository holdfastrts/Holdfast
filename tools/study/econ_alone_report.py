#!/usr/bin/env python3
"""The Crown computer ALONE (tools/econ_ai_alone.gd) against the bench (econ-coach-crown, docs/econ-coach-crown.md).
    python3 tools/study/econ_alone_report.py FILE.json [...]"""
import json, sys
BENCH_V = {3: 1903, 5: 4364, 8: 10034, 10: 14079, 12: 18735, 15: 26559}   # bench value (gold + powder), Greenhold 4/8/12
for f in sys.argv[1:]:
    d = json.load(open(f))
    rs = d["rows"]
    def r(m):
        return rs[m - 1] if len(rs) >= m else None
    cells = []
    for m in (5, 8, 10, 15):
        x = r(m)
        if x:
            cells.append("%2d:%5d %.2f w%3d a%4d" % (m, x["value_cum"], x["value_cum"] / BENCH_V[m], x["workers"], x["army"]))
    idle = sum(x["idle_s"] for x in rs[:10]) / 60.0
    blk = sum(x["blocked_s"] for x in rs[:10])
    pi = sum(x["prod_idle"] for x in rs[3:10]) / max(1, len(rs[3:10]))
    ff = sum(x["farm_fill"] for x in rs[2:10]) / max(1, len(rs[2:10]))
    mf = sum(x["mill_fill"] for x in rs[4:10]) / max(1, len(rs[4:10]))
    plans = ">".join(p[1] for p in d["plans"])
    print("%-28s %s | halls %s | idle w-min(0-10) %.1f blk %ds farm %.2f mill %.2f prodidle %.2f spentF15 %.1f | %s" % (
        f.split("/")[-1], "  ".join(cells), [round(t / 60, 1) for t in d["halls_at"]], idle, blk, ff, mf, pi,
        rs[-1]["spent_farms"], plans))
