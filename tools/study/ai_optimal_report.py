#!/usr/bin/env python3
"""The report's table (docs/ai_optimal.md section 5): OPTIMAL's coached games next to the same games played by Balanced
(tools/study/ai_optimal_games.py run OUT and run BASE --plan balanced).
    python3 tools/study/ai_optimal_report.py OUT BASE"""
import os, re, sys

def load(d):
    out = {}
    for x in sorted(os.listdir(d)):
        rp = os.path.join(d, x, "result.txt")
        if not os.path.exists(rp):
            continue
        txt = open(rp).read()
        m = re.match(r"map (\S+) seed \d+: P1 (\S+) (\S+) v P2 (\S+) (\S+)", txt.split("\n")[0])
        if not m:
            continue
        mp, a, sa, b, sb = m.groups()
        last = {}
        for l in txt.split("\n"):
            mm = re.match(r"(\d+:\d+) P(\d) \S+ \S+ \((\S+)\): income (\d+) \| workers (\d+) \| army (\d+) \| halls (\d+)", l)
            if mm:
                last[int(mm.group(2))] = (int(mm.group(4)), int(mm.group(6)), int(mm.group(7)))
        e = re.search(r"end (\S+) winner (\S+)", txt)
        w = e.group(2) if e else "?"
        if w == "none" and 1 in last and 2 in last:
            s1 = last[1][0] + 2 * last[1][1]
            s2 = last[2][0] + 2 * last[2][1]
            w = "ahead" if s1 > s2 * 1.1 else ("behind" if s2 > s1 * 1.1 else "even")
        elif w == "P1":
            w = "WON"
        elif w == "P2":
            w = "LOST"
        picks = []
        for l in txt.split("\n"):
            if l.startswith("P1 pick"):
                p = l.split(" ")
                why = l[l.find("(") + 1:l.rfind(")")]
                picks.append("%s %s->%s" % (p[2], p[4], p[6]))
        out[(a, b, sb, mp)] = {"w": w, "end": e.group(1) if e else "?", "l": last, "picks": picks}
    return out

def score(r):
    return {"WON": 2, "ahead": 1, "even": 0, "behind": -1, "LOST": -2}.get(r["w"], 0)

if __name__ == "__main__":
    opt = load(sys.argv[1])
    base = load(sys.argv[2]) if len(sys.argv) > 2 else {}
    rows = ["| OPTIMAL | v | its plan | map | OPTIMAL: result, earned / foe, army / foe at the end | its picks (clock read->build) | Balanced in the same seat |",
            "|---|---|---|---|---|---|---|"]
    tot = {}
    for k in sorted(opt):
        a, b, sb, mp = k
        r = opt[k]
        l = r["l"]
        s = "%s %s, %s / %s, %s / %s" % (r["w"], r["end"], l.get(1, ("?",))[0], l.get(2, ("?",))[0], l.get(1, ("?", "?"))[1], l.get(2, ("?", "?"))[1])
        bs = "-"
        if k in base:
            br = base[k]
            bl = br["l"]
            bs = "%s %s, %s / %s, %s / %s" % (br["w"], br["end"], bl.get(1, ("?",))[0], bl.get(2, ("?",))[0], bl.get(1, ("?", "?"))[1], bl.get(2, ("?", "?"))[1])
            t = tot.setdefault(a, [0, 0, 0, 0])
            t[0] += score(r)
            t[1] += score(br)
            t[2] += 1
        t2 = tot.setdefault(a, [0, 0, 0, 0])
        t2[3] += 1
        rows.append("| %s | %s | %s | %s | %s | %s | %s |" % (a, b, sb, mp, s, "; ".join(r["picks"]), bs))
    rows.append("")
    for a, t in tot.items():
        n = sum(1 for k in opt if k[0] == a)
        won = sum(1 for k in opt if k[0] == a and opt[k]["w"] in ("WON", "ahead"))
        lost = sum(1 for k in opt if k[0] == a and opt[k]["w"] in ("LOST", "behind"))
        line = "- %s OPTIMAL: won or ahead in %d of %d, lost or behind in %d" % (a, won, n, lost)
        if t[2]:
            bw = sum(1 for k in base if k[0] == a and k in opt and base[k]["w"] in ("WON", "ahead"))
            line += "; Balanced in the same %d games: won or ahead in %d (score %+d for OPTIMAL against %+d for Balanced: won 2, ahead 1, even 0, behind -1, lost -2)" % (t[2], bw, t[0], t[1])
        rows.append(line)
    print("\n".join(rows))
