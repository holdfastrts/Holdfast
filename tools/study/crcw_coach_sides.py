#!/usr/bin/env python3
"""crown-v-clockwork-coach: each side's coached numbers from tools/qa_match.gd data folders (Crown v Clockwork games only):
    python3 tools/study/crcw_coach_sides.py DATA [DATA2 ...]"""
import json, os, sys
from statistics import median


def at(d, p, t):
    for m in d["minutes"]:
        if m["p"] == p and m["t"] == t:
            return m
    return None


for folder in sys.argv[1:]:
    rows = {"cr_wk10": [], "cr_wk8": [], "cw_bank5": [], "cw_army5": [], "cr_first": [], "cw_first": [], "cr_halls10": [],
            "cw_first_t": [], "cr_first_t": []}
    for tag in sorted(os.listdir(folder)):
        fn = os.path.join(folder, tag, "result.json")
        if not os.path.exists(fn) or "_crcw_" not in tag:
            continue
        d = json.load(open(fn))
        f = [s["faction"] if isinstance(s, dict) else s[0] for s in d["slots"]]
        cr, cw = f.index("crown"), f.index("clockwork")
        for t, k in ((480, "cr_wk8"), (600, "cr_wk10")):
            m = at(d, cr, t)
            if m:
                rows[k].append(m["workers"])
        m = at(d, cr, 600)
        if m:
            rows["cr_halls10"].append(m["halls"])
        m = at(d, cw, 300)
        if m:
            rows["cw_bank5"].append(m["bank"])
            rows["cw_army5"].append(m["army"])
        for e in d["events"]:
            if e["ev"] == "first_attack":
                k = "cr" if e["p"] == cr else "cw"
                rows[k + "_first"].append((e["lost"], e["foe_lost"]))
                rows[k + "_first_t"].append(e["t"])
    def tr(l):
        return "%d lost for %d killed (%d attacks)" % (sum(x[0] for x in l), sum(x[1] for x in l), len(l)) if l else "-"
    print("##", folder)
    print("  Crown labourers 8:00 median %s, 10:00 median %s; halls 10:00 mean %.1f" % (
        median(rows["cr_wk8"]) if rows["cr_wk8"] else "-", median(rows["cr_wk10"]) if rows["cr_wk10"] else "-",
        sum(rows["cr_halls10"]) / max(1, len(rows["cr_halls10"]))))
    print("  Clockwork at 5:00: bank median %s (max %s), army median %s" % (
        median(rows["cw_bank5"]), max(rows["cw_bank5"]), median(rows["cw_army5"])))
    print("  first attacks: the Crown's %s (median at %s s); the Clockwork's %s (median at %s s)" % (
        tr(rows["cr_first"]), median(rows["cr_first_t"]) if rows["cr_first_t"] else "-", tr(rows["cw_first"]),
        median(rows["cw_first_t"]) if rows["cw_first_t"] else "-"))
