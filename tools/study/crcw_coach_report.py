#!/usr/bin/env python3
"""crown-v-clockwork-coach: the Crown v Clockwork table from tools/qa_match.gd data folders (one or more):
    python3 tools/study/crcw_coach_report.py DATA [DATA2 ...]
"won or led": won, or ahead at 15:00 by income earned + 2 x army value by 10% or more. The other pairings in a folder
get one line each (W-D-L of the first-named faction)."""
import json, os, sys
from collections import defaultdict


def at(mins, p, t):
    for m in mins:
        if m["p"] == p and m["t"] == t:
            return m
    return None


def side(d):
    f = [s["faction"] if isinstance(s, dict) else s[0] for s in d["slots"]]
    return f


def score(m):
    return m["income"] + 2 * m["army"] if m else 0


def table(folder):
    rows = defaultdict(list)
    for tag in sorted(os.listdir(folder)):
        fn = os.path.join(folder, tag, "result.json")
        if not os.path.exists(fn):
            continue
        d = json.load(open(fn))
        facs = side(d)
        rows[tuple(sorted(facs))].append((tag, d, facs))
    return rows


def crcw(games):
    out = {"W": 0, "D": 0, "L": 0, "led": 0, "len": [], "inc8": [], "inc10": [], "army8": [], "army10": [], "halls8": [],
           "cr_lost": 0, "cw_lost": 0, "plans": defaultdict(int), "cwplans": defaultdict(int), "games": []}
    for tag, d, facs in games:
        cr = facs.index("crown")
        cw = 1 - cr
        w = d.get("winner", -1)
        last = max(m["t"] for m in d["minutes"])
        if w == cr:
            res = "W"
        elif w == cw:
            res = "L"
        else:
            res = "D"
        out[res] += 1
        a, b = at(d["minutes"], cr, last), at(d["minutes"], cw, last)
        led = res == "W" or (res == "D" and score(a) > 1.1 * score(b))
        out["led"] += 1 if led else 0
        if res != "D":
            out["len"].append(d["end"])
        for t, k in ((480, "8"), (600, "10")):
            a, b = at(d["minutes"], cr, t), at(d["minutes"], cw, t)
            if a and b:
                out["inc" + k].append(a["income"] / max(1, b["income"]))
                out["army" + k].append((a["army"], b["army"]))
                if k == "8":
                    out["halls8"].append((a["halls"], b["halls"]))
        for e in d["events"]:
            if e.get("ev") == "hall_lost":
                out["cr_lost" if e["p"] == cr else "cw_lost"] += 1
        m5 = at(d["minutes"], cr, 300)
        if m5:
            out["plans"][m5["plan"]] += 1
        m5 = at(d["minutes"], cw, 300)
        if m5:
            out["cwplans"][m5["plan"]] += 1
        out["games"].append("%s %s%s" % (tag.replace("base_", "").replace("_crcw", ""), res, "+" if led and res == "D" else ""))
    return out


def mean(l):
    return sum(l) / len(l) if l else 0


def show(folder):
    rows = table(folder)
    print("##", folder)
    for k, games in sorted(rows.items()):
        if k == ("clockwork", "crown"):
            o = crcw(games)
            n = len(games)
            print("Crown v Clockwork: %d games, Crown W-D-L %d-%d-%d, won or led %d; decided %d (mean %s)" % (
                n, o["W"], o["D"], o["L"], o["led"], len(o["len"]),
                "%d:%02d" % divmod(int(mean(o["len"])), 60) if o["len"] else "-"))
            print("  income Crown/Clockwork 8:00 %.2f, 10:00 %.2f" % (mean(o["inc8"]), mean(o["inc10"])))
            print("  army 8:00 Crown %d / Clockwork %d; 10:00 %d / %d" % (
                mean([x[0] for x in o["army8"]]), mean([x[1] for x in o["army8"]]),
                mean([x[0] for x in o["army10"]]), mean([x[1] for x in o["army10"]])))
            print("  halls 8:00 Crown %.1f / Clockwork %.1f; halls lost Crown %d, Clockwork %d" % (
                mean([x[0] for x in o["halls8"]]), mean([x[1] for x in o["halls8"]]), o["cr_lost"], o["cw_lost"]))
            print("  Crown plans at 5:00 %s; Clockwork %s" % (dict(o["plans"]), dict(o["cwplans"])))
            print("  " + ", ".join(o["games"]))
        else:
            res = defaultdict(int)
            for tag, d, facs in games:
                w = d.get("winner", -1)
                res["W" if w == 0 else "L" if w == 1 else "D"] += 1
            print("%s: %d games, P1 W-D-L %d-%d-%d" % (" v ".join(k), len(games), res["W"], res["D"], res["L"]))


for f in sys.argv[1:]:
    show(f)
