#!/usr/bin/env python3
"""Tables for docs/brood_builds.md from the coached games of tools/play_brood_builds.gd.

    python3 tools/brood_builds_table.py DIR [DIR ...]

Each DIR holds one game folder per game (a01, b02, ...), each with its builds.txt. Prints a markdown table:
the game, plan, opponent, map and seed, the result (W at the time, D alive at 13:00, L), food earned by 6/8/10 min
against the enemy's income, the army at 8:00 against the enemy's, the first push (when, supply, Spitters / Brutes,
contact, breach and what it broke, what it killed, how it ended) and the game's value killed / lost.
"""
import os
import re
import sys


def mmss(s):
    return s[:2].lstrip("0").rjust(1, "0") + ":" + s[2:] if len(s) == 4 and s.isdigit() else s


def parse(path):
    d = {"eco": {}, "pushes": []}
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        m = re.match(r"plan (\w+) \((\w+)\), brood v (\w+), (\w+) seed (\d+)", line)
        if m:
            d.update(plan=m.group(1), foe=m.group(3), map=m.group(4), seed=m.group(5))
            continue
        m = re.match(r"(\d{4}) food earned (\d+) \(foe (\d+)\) \| grubs (\d+) \| turtles on new ground (\d+) \| stage (\d+) \| army (\d+) \(.*\) \| foe army (\d+)", line)
        if m:
            d["eco"][m.group(1)] = dict(food=int(m.group(2)), foe=int(m.group(3)), grubs=int(m.group(4)), far=int(m.group(5)),
                                         stage=int(m.group(6)), army=int(m.group(7)), foe_army=int(m.group(8)))
            continue
        if line.startswith("push "):
            f = [x.strip() for x in line[5:].split("|")]
            p = {"t": f[0], "sup": f[1].split(" ")[0], "sp": re.search(r"spitters (\d+)", f[2]).group(1),
                 "br": re.search(r"brutes (\d+)", f[2]).group(1), "contact": f[3].split(" ")[1], "breach": f[4].split(" ")[1],
                 "broke": f[5][6:].strip(), "killed": f[6].split(" ")[1], "end": f[7][4:].strip()}
            d["pushes"].append(p)
            continue
        m = re.match(r"result: over (\w+) winner (-?\d+) at (\d{4}) \| value killed (\d+) lost (\d+) \| earned (\d+) foe (\d+)", line)
        if m:
            over, win, at = m.group(1) == "true", int(m.group(2)), m.group(3)
            d["result"] = ("W " + mmss(at)) if over and win == 0 else ("L " + mmss(at)) if over else "D"
            d["killed"], d["lost"] = int(m.group(4)), int(m.group(5))
    return d


def broke(s):
    s = s.strip("{} ")
    if not s:
        return "-"
    return ", ".join("%s %s" % (v.strip(), k.strip().strip('"').replace("_", " ")) for k, v in (x.split(":") for x in s.split(",")))


def main():
    rows = []
    for top in sys.argv[1:]:
        for g in sorted(os.listdir(top)):
            p = os.path.join(top, g, "builds.txt")
            if os.path.isfile(p):
                rows.append((g, parse(p)))
    print("| game | plan | against | map, seed | result | food 6/8/10 (enemy) | army 8:00 (enemy) | first push: out (supply, Spitters, Brutes) | contact | breach (broke) | push killed | end | game killed / lost |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for g, d in rows:
        e = d["eco"]
        food = "/".join(str(e.get(k, {}).get("food", "-")) for k in ("0600", "0800", "1000"))
        foe = "/".join(str(e.get(k, {}).get("foe", "-")) for k in ("0600", "0800", "1000"))
        army = "%s (%s)" % (e.get("0800", {}).get("army", "-"), e.get("0800", {}).get("foe_army", "-"))
        p = d["pushes"][0] if d["pushes"] else None
        if p:
            push = "%s (%s, %s, %s)" % (mmss(p["t"]), p["sup"], p["sp"], p["br"])
            contact = mmss(p["contact"])
            br = "%s (%s)" % (mmss(p["breach"]), broke(p["broke"])) if p["breach"] != "-" else "-"
            killed = p["killed"]
            et = p["end"].split(" ")
            if et[0] == "-":
                end = "out to the end"
            else:
                end = "%s %s" % ({"home": "came home", "failed": "lost, came home"}.get(et[1] if len(et) > 1 else "", ""), mmss(et[0]))
        else:
            push, contact, br, killed, end = "-", "-", "-", "-", "-"
        print("| %s | %s | %s | %s %s | %s | %s (%s) | %s | %s | %s | %s | %s | %s | %d / %d |" % (
            g, d.get("plan", "?"), d.get("foe", "?"), d.get("map", "?").replace("_", " ").title(), d.get("seed", "?"),
            d.get("result", "?"), food, foe, army, push, contact, br, killed, end, d.get("killed", 0), d.get("lost", 0)))


if __name__ == "__main__":
    main()
