#!/usr/bin/env python3
"""CROWN V BROOD COACH report (docs/crown_v_brood_coach.md): reads the result.json files written by tools/qa_match.gd
(through tools/study/crown_v_brood_coach.py) and prints, per game and per group, the Crown's side against its foe.
    python3 tools/study/crown_v_brood_coach_report.py DATA [DATA2 ...] [--games] [--md]
"Won or led": won, or a draw at the end whose income + 2 x army is 10% ahead (as docs/crown_ai_v2.md)."""
import json, os, sys


def at(mins, p, t):
    best = None
    for m in mins:
        if m["p"] == p and m["t"] <= t + 1:
            best = m
    return best


def one(d):
    r = json.load(open(os.path.join(d, "result.json")))
    slots = r["slots"]
    facs = [s["faction"] if isinstance(s, dict) else s[0] for s in slots]
    if "crown" not in facs:
        return None
    me = facs.index("crown")
    if facs == ["crown", "crown"]:
        me = 0
    foe = 1 - me
    mins = r["minutes"]
    end = r["end"]
    w = r.get("winner")
    res = "D"
    if r.get("over") and w is not None and w >= 0:
        res = "W" if w == me else "L"
    last_me, last_foe = at(mins, me, end), at(mins, foe, end)
    if res == "D" and last_me and last_foe:
        sm = last_me["income"] + 2 * last_me["army"]
        sf = last_foe["income"] + 2 * last_foe["army"]
        res = "led" if sm > 1.1 * sf else ("behind" if sf > 1.1 * sm else "even")
    o = {"tag": os.path.basename(d), "map": r["map"], "foe": facs[foe], "slot": me, "res": res, "end": end}
    for t in (240, 300, 360, 480, 600):
        a, b = at(mins, me, t), at(mins, foe, t)
        if a and b and a["t"] >= t - 1:
            o["w%d" % t] = (a["workers"], b["workers"])
            o["inc%d" % t] = a["income"] / max(1, b["income"])
            o["army%d" % t] = (a["army"], b["army"])
            o["halls%d" % t] = (a["halls"], b["halls"])
            o["plan%d" % t] = a["plan"]
    lost = [e for e in r["events"] if e.get("ev") == "hall_lost" and e.get("p") == me]
    o["halls_lost"] = len(lost)
    o["first_hall_lost"] = min([e["t"] for e in lost], default=-1)
    return o


def mmss(t):
    return "%d:%02d" % (t // 60, t % 60) if t >= 0 else "-"


def main():
    dirs = [a for a in sys.argv[1:] if not a.startswith("--")]
    games = []
    for D in dirs:
        for tag in sorted(os.listdir(D)):
            p = os.path.join(D, tag)
            if os.path.exists(os.path.join(p, "result.json")):
                g = one(p)
                if g:
                    games.append(g)
    if "--games" in sys.argv:
        print("| game | res | end | plan 5:00 | labourers 4/6/8 (Crown/foe) | income 5:00 / 8:00 | army 8:00 | halls 8:00 | halls lost (first) |")
        print("|---|---|---|---|---|---|---|---|---|")
        for g in games:
            ws = " ".join("%d/%d" % g["w%d" % t] if "w%d" % t in g else "-" for t in (240, 360, 480))
            print("| %s | %s | %s | %s | %s | %.2f / %s | %s | %s | %d (%s) |" % (
                g["tag"], g["res"], mmss(g["end"]), g.get("plan300", "-"), ws, g.get("inc300", 0),
                ("%.2f" % g["inc480"]) if "inc480" in g else "-",
                ("%d/%d" % g["army480"]) if "army480" in g else "-", ("%d/%d" % g["halls480"]) if "halls480" in g else "-",
                g["halls_lost"], mmss(g["first_hall_lost"])))
    groups = {}
    for g in games:
        k = g["foe"] + (" (" + g["tag"].split("_v_")[0].replace("plan_cr-", "") + " v " + g["tag"].split("_v_")[1].split("_")[0] + ")" if g["tag"].startswith("plan_") else "")
        groups.setdefault(k, []).append(g)
    print()
    print("| Crown v | games | W-D-L | won or led | labourers 6:00 (Crown/foe) | 8:00 | income 5:00 | 8:00 | 10:00 | army 8:00 (sum ratio) | halls 8:00 | halls lost | lost games end |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for k in sorted(groups):
        gl = groups[k]
        W = sum(g["res"] == "W" for g in gl)
        L = sum(g["res"] == "L" for g in gl)
        D = len(gl) - W - L
        wl = sum(g["res"] in ("W", "led") for g in gl)
        avg = lambda key, i=None: (sum((g[key][i] if i is not None else g[key]) for g in gl if key in g) / max(1, sum(key in g for g in gl)))
        a0 = sum(g["army480"][0] for g in gl if "army480" in g)
        a1 = sum(g["army480"][1] for g in gl if "army480" in g)
        ends = [g["end"] for g in gl if g["res"] == "L"]
        print("| %s | %d | %d-%d-%d | %d | %.1f / %.1f | %.1f / %.1f | %.2f | %.2f | %.2f | %.2f | %.1f / %.1f | %d | %s |" % (
            k, len(gl), W, D, L, wl, avg("w360", 0), avg("w360", 1), avg("w480", 0), avg("w480", 1), avg("inc300"),
            avg("inc480"), avg("inc600"), a0 / max(1, a1), avg("halls480", 0), avg("halls480", 1),
            sum(g["halls_lost"] for g in gl), mmss(int(sum(ends) / len(ends))) if ends else "-"))


if __name__ == "__main__":
    main()
