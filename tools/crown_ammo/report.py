#!/usr/bin/env python3
"""crown-ammo's coached games (tools/play_crown_ammo.gd): branch v main, side by side.
   python3 tools/crown_ammo/report.py BRANCH.jsonl MAIN.jsonl > table.md"""
import json, sys
from collections import defaultdict


def load(p):
    out = {}
    for line in open(p):
        line = line.strip()
        if line:
            r = json.loads(line)
            out[(r["plan"], r["foe"], r["map"], r.get("seed", 1))] = r
    return out


b, m = load(sys.argv[1]), load(sys.argv[2])
for r in b.values():
    r["_new"] = True
keys = sorted(set(b) | set(m), key=lambda k: (k[1], k[0], k[2]))


def g(r, at, k, d="-"):
    if r is None:
        return d
    x = r.get(at, r.get("end", {}))
    if k == "army_val" and r is not None and r.get("_new"):
        return x.get(k, 0) + 10 * x.get("musk", 0)      # (a Musketeer's or Dragoon's 10 powder was in his cost2 on main)
    return x.get(k, d)


print("| plan | foe | map | gold in 8:00 (new / main) | powder in | powder left | army supply 8:00 | army value | killed / lost | halls | out dry / partial | empty-fight s | empty blows | refill errands | powder: arming / refills |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
tot = defaultdict(lambda: [0.0, 0.0, 0])
for k in keys:
    rb, rm = b.get(k), m.get(k)
    at = "m8"
    row = [k[0], k[1], k[2] + ("" if k[3] == 1 else " (seed %d)" % k[3])]
    for f in ["gold_in", "powder_in", "bank2", "army_sup", "army_val"]:
        row.append("%s / %s" % (g(rb, at, f), g(rm, at, f)))
        if rb and rm:
            tot[f][0] += float(g(rb, at, f, 0))
            tot[f][1] += float(g(rm, at, f, 0))
            tot[f][2] += 1
    row.append("%s/%s / %s/%s" % (g(rb, "end", "killed"), g(rb, "end", "lost"), g(rm, "end", "killed"), g(rm, "end", "lost")))
    row.append("%s / %s" % (g(rb, "end", "halls"), g(rm, "end", "halls")))
    row.append("%s / %s" % (g(rb, "end", "dry_out"), g(rb, "end", "partial_out")))
    row.append("%s / %s" % (g(rb, "end", "empty_s"), g(rm, "end", "empty_s")))
    row.append(str(g(rb, "end", "empty_blows")))
    row.append(str(g(rb, "end", "rearm")))
    row.append("%s / %s" % (g(rb, "end", "ammo_powder"), g(rb, "end", "refill_powder")))
    for f in ["empty_s", "killed", "lost"]:
        if rb and rm:
            tot[f][0] += float(g(rb, "end", f, 0))
            tot[f][1] += float(g(rm, "end", f, 0))
            tot[f][2] += 1
    print("| " + " | ".join(str(x) for x in row) + " |")
print()
print("Totals over the games both sides finished (new / main, the change):")
print()
for f, (x, y, n) in tot.items():
    ch = ("%+.0f%%" % ((x - y) / y * 100.0)) if y else "-"
    print("- %s: %.0f / %.0f (%s, %d games)" % (f, x, y, ch, n))
