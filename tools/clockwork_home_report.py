#!/usr/bin/env python3
"""Tables for docs/clockwork_home.md from tools/test_clockwork_home.gd's json lines.
   python3 tools/clockwork_home_report.py docs/clockwork_home/games.jsonl"""
import json
import sys


def mmss(s):
    return "%d:%02d" % (int(s) // 60, int(s) % 60)


def row(g):
    eps = g["eps"]
    big = [e for e in eps if e["peak"] >= 600 and not e["out"]]
    share = sum(min(1.0, e["share"]) for e in big) / len(big) if big else None
    ws = [e["with"] for e in big if "with" in e]
    withv = sum(ws) / len(ws) if ws else None
    lw = sum(l[1] for l in g["launches"]) / len(g["launches"]) if g["launches"] else None
    dws = [e["wind0"] for e in eps if e["wind0"] >= 0]
    dw = sum(dws) / len(dws) if dws else None
    m10 = g["mins"].get("10", g["end"])
    return {
        "game": "%s %s v %s %s" % (g["map"], g["cw"], g["foe"], g["fp"]),
        "seed": g["seed"],
        "who": "after" if not g["old"] else "before",
        "idle_wind": g["idle_wind"],
        "field": g["idle_field"],
        "launch_wind": lw,
        "def_wind": dw,
        "eps": len(eps),
        "big": len(big),
        "share": share,
        "with": withv,
        "lost_b": g["lost_b"],
        "killed": m10["killed"],
        "lost": m10["lost"],
        "army10": "%d v %d" % (m10["army"], m10["farmy"]),
        "end": "%s %s" % (g["winner"], mmss(g["clock"])),
    }


def f(x, pct=False):
    if x is None:
        return "-"
    if pct:
        return "%d%%" % round(x * 100)
    return "%.2f" % x


def main():
    rows = [row(json.loads(l)) for l in open(sys.argv[1]) if l.strip()]
    print("| game | seed | | wind at home | on gears | wind as a push goes | wind as a defence starts | attacks (600+) | army that came | army at it | buildings lost | killed / lost by 10:00 | army 10:00 | end |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in sorted(rows, key=lambda r: (r["game"], r["seed"], r["who"] == "after")):
        print("| %s | %s | %s | %s | %s | %s | %s | %d (%d) | %s | %s | %d | %d / %d | %s | %s |" % (
            r["game"], r["seed"], r["who"], f(r["idle_wind"]), f(r["field"], True), f(r["launch_wind"]), f(r["def_wind"]),
            r["eps"], r["big"], f(r["share"], True), f(r["with"], True), r["lost_b"], r["killed"], r["lost"], r["army10"], r["end"]))
    for who in ("before", "after"):
        rs = [r for r in rows if r["who"] == who]
        if not rs:
            continue
        def avg(k):
            v = [r[k] for r in rs if r[k] is not None and r[k] >= 0]
            return sum(v) / len(v) if v else None
        wins = sum(1 for r in rs if r["end"].startswith("clockwork"))
        losses = sum(1 for r in rs if r["end"].startswith("foe"))
        print("\n%s: %d games, wind at home %s, on gears %s, as a push goes %s, as a defence starts %s, army that came to a 600+ attack %s, at it while it was big %s, buildings lost %.1f, killed %d lost %d by 10:00, won %d lost %d" % (
            who.upper(), len(rs), f(avg("idle_wind")), f(avg("field"), True), f(avg("launch_wind")), f(avg("def_wind")),
            f(avg("share"), True), f(avg("with"), True), sum(r["lost_b"] for r in rs) / len(rs), avg("killed"), avg("lost"), wins, losses))


main()
