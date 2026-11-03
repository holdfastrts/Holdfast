#!/usr/bin/env python3
"""A round of coached siege-push games (tools/play_crown_siege.gd) as a markdown table (docs/crown_builds_b.md).

    python3 -I tools/play_crown_siege_table.py /abs/round_dir [/abs/other_round ...]

Each game folder holds siege.txt (the economy at 4/6/8/10 min, the totals, one line a push) and minutes.txt.
"""
import os
import re
import sys


def mmss(s):
    return s[:2].lstrip("0") + ":" + s[2:] if len(s) == 4 else s


def game(d):
    p = os.path.join(d, "siege.txt")
    if not os.path.exists(p):
        return None
    lines = open(p).read().splitlines()
    head = lines[0]
    m = re.match(r"map (\S+) seed (\d+) vs (\S+) (\S+) \((\S+)\); result (.+) at (\d+)", head)
    row = {"game": os.path.basename(d), "map": m.group(1), "seed": m.group(2), "foe": "%s %s" % (m.group(3).capitalize(), m.group(4)),
           "result": m.group(6), "end": mmss(m.group(7))}
    econ = {}
    pushes = []
    for l in lines[1:]:
        e = re.match(r"econ (\d+) labourers (\d+) gold (\d+) army (\d+) enemy_army (\d+)", l)
        if e:
            econ[int(e.group(1))] = (int(e.group(2)), int(e.group(3)), int(e.group(4)), int(e.group(5)))
        t = re.match(r"total killed (\d+) lost (\d+)", l)
        if t:
            row["killed"], row["lost"] = int(t.group(1)), int(t.group(2))
        if l.startswith("push "):
            q = re.match(r"push t0 (\d+) sup (\d+) guns (\d+) cannons (\d+) line (\d+) value (\d+) end (\S+) why \[(.*)\] killed (-?\d+) lost (-?\d+) broke (\{.*\}) sets (\d+)(?: contact (\d+))?", l)
            if q:
                pushes.append(q.groups())
    row["econ"] = econ
    row["pushes"] = pushes
    return row


def fmt(rows):
    out = ["| game | against | map | result | labourers 4/6/8 | gold earned by 6/8 | army 6/8 (enemy 8) | pushes: out at (supply, guns) -> first contact | what the pushes broke | push killed / lost | game killed / lost |",
           "|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in rows:
        e = r["econ"]
        labs = "/".join(str(e[m][0]) if m in e else "-" for m in (4, 6, 8))
        gold = "/".join(str(e[m][1]) if m in e else "-" for m in (6, 8))
        army = "%s/%s (%s)" % (e.get(6, ("-", "-", "-"))[2], e.get(8, ("-", "-", "-"))[2], e.get(8, ("-",) * 4)[3])
        outs, broke, kl = [], {}, [0, 0]
        for p in r["pushes"]:
            outs.append("%s (%s, %s)%s" % (mmss(p[0]), p[1], p[2], " -> %s" % mmss(p[12]) if p[12] else ""))
            for k, v in eval(p[10].replace("null", "None")).items():
                broke[k] = broke.get(k, 0) + v
            kl[0] += max(0, int(p[8]))
            kl[1] += max(0, int(p[9]))
        res = r["result"] if r["result"] != "alive" else "alive %s" % r["end"]
        out.append("| %s | %s | %s %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            r["game"], r["foe"], r["map"].replace("_", " ").title(), r["seed"], res, labs, gold, army,
            ", ".join(outs) or "-", ", ".join("%d %s" % (v, k.replace("_", " ")) for k, v in broke.items()) or "-",
            "%d / %d" % tuple(kl) if outs else "-", "%d / %d" % (r.get("killed", 0), r.get("lost", 0))))
    return "\n".join(out)


def main():
    rows = []
    for rd in sys.argv[1:]:
        for name in sorted(os.listdir(rd)):
            d = os.path.join(rd, name)
            if os.path.isdir(d):
                r = game(d)
                if r:
                    rows.append(r)
    print(fmt(rows))


if __name__ == "__main__":
    main()
