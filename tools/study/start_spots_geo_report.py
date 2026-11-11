#!/usr/bin/env python3
"""START SPOTS geometry report (docs/start_spots_study.md): reads tools/start_spots_geo.gd's JSON files and prints one
table row per map and seed: is it a point mirror, and the two spots' numbers side by side (spot A = player index 0
without swap). Measuring only.
    python3 tools/study/start_spots_geo_report.py docs/start_spots_study/geo"""
import json, os, sys, glob

d = sys.argv[1] if len(sys.argv) > 1 else "docs/start_spots_study/geo"
rows = []
for fn in sorted(glob.glob(os.path.join(d, "*.json"))):
    g = json.load(open(fn))
    rows.append(g)


def ab(a, b, fmt="%s"):
    return (fmt % a) if a == b else ("**" + fmt % a + " / " + fmt % b + "**")


print("| map | seed | fac | terrain mirror (cells off) | starts/nats/sites mirrored | walk main-main | ramp width (A / B) | ramp cells | plateau open | room main | natural walk / safe / room | third walk / safe | narrowest choke A half / B half | start buildings off mirror (max tiles) |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for g in rows:
    m = g["mirror"]
    off = sum(m[k] for k in ("height", "cliff", "ramp", "water", "terrain", "kind"))
    a, b = g["sides"]

    def ramp(s):
        return ",".join(str(r["width"]) for r in s["ramps"]) or "-"

    def rcells(s):
        return ",".join(str(r["cells"]) for r in s["ramps"]) or "-"

    def site(s, i):
        if len(s["sites"]) <= i:
            return "-"
        x = s["sites"][i]
        return "%d/%d/%.2f" % (x["home"], x["safe"], x["room"])

    def site2(s, i):
        if len(s["sites"]) <= i:
            return "-"
        x = s["sites"][i]
        return "%d/%d" % (x["home"], x["safe"])

    def choke(s):
        return str(s["chokes"][0][0]) if s["chokes"] else "-"

    lay = max([x[2] for x in g["layout"]] or [0])
    print("| %s | %d | %s | %d %s | %s/%s/%s | %s | %s | %s | %s | %s | %s | %s | %s / %s | %.1f |" % (
        g["map"], g["seed"], g["fac"], off, json.dumps(m["near"]) if off else "",
        m["starts_mirrored"], m["nats_mirrored"], m["sites_mirrored"],
        ab(a["main_walk"], b["main_walk"], "%d"), ab(ramp(a), ramp(b)), ab(rcells(a), rcells(b)),
        ab(a["plateau_open"], b["plateau_open"], "%d"), ab(a["room_main"], b["room_main"], "%.2f"),
        ab(site(a, 0), site(b, 0)), ab(site2(a, 1), site2(b, 1)), choke(a), choke(b), lay))
