#!/usr/bin/env python3
"""CROWN v CLOCKWORK PLAN STUDY (crown-v-cw-plan-study, docs/crown_v_cw_plan_study.md): the Crown OPTIMAL computer's answer
to a GREEDY Clockwork read, three ways (default = today's GREEDY_CLOCK weights, greedyclock:economy, greedyclock:balanced),
from tools/qa_match.gd result.json files. A measuring tool only.
    python3 tools/study/crown_v_cw_plan_report.py DATA_ROOT [round]     (DATA_ROOT/<config>/base_*_crcw_r*/result.json)
"won or led": won, or a draw ahead at the end by income earned + 2 x army value by 10% or more (the qa-matches rule)."""
import json, os, sys, glob, statistics as st

BENCH_P = {5: 4180, 8: 9500, 10: 13180, 15: 24460}     # the Crown bench's primary earned (docs/economy_parity.md)
CONFIGS = ["default", "economy", "balanced"]


def mmss(s):
    return "%d:%02d" % (int(s) // 60, int(s) % 60)


def load(root, cfg, rnd=None):
    out = {}
    for f in sorted(glob.glob(os.path.join(root, cfg, "base_*_crcw_r*", "result.json"))):
        tag = os.path.basename(os.path.dirname(f))
        if rnd is not None and not tag.endswith("_r%s" % rnd):
            continue
        g = json.load(open(f))
        facs = [s[0] for s in g["slots"]]
        c, w = facs.index("crown"), facs.index("clockwork")
        at = {(r["p"], int(round(r["t"] / 60))): r for r in g["minutes"]}
        sc = [f["income"] + 2 * f["army"] for f in g["final"]]
        if g["winner"] >= 0:
            res = "W" if g["winner"] == c else "L"
            lead = res
        else:
            res = "D"
            lead = "w" if sc[c] > 1.1 * sc[w] else ("l" if sc[w] > 1.1 * sc[c] else "=")
        halls = [0, 0]
        first_lost = [None, None]
        for e in g["events"]:
            if e.get("ev") == "hall_lost" and e.get("built"):
                halls[e["p"]] += 1
                if first_lost[e["p"]] is None:
                    first_lost[e["p"]] = e["t"]
        reads = [x for x in g.get("reads", []) if x["p"] == c and "read" in x]
        picks = [x for x in g.get("reads", []) if x["p"] == c and "pick" in x]
        cw_picks = [x for x in g.get("reads", []) if x["p"] == w and "pick" in x]
        cw_reads = [x["read"] for x in g.get("reads", []) if x["p"] == w and "read" in x]
        gp = [x for x in picks if "GREEDY" in x["pick"]]
        greedy_t = gp[0]["t"] if gp else None
        greedy_plan = gp[0]["pick"].split("->")[1].strip().split(" ")[0] if gp else ""
        cplans, wplans = [], []
        for r in g["minutes"]:
            lst = cplans if r["p"] == c else wplans
            if not lst or lst[-1] != r["plan"]:
                lst.append(r["plan"])
        # the Clockwork after the greedy pick: its plans and halls from then
        w_after = []
        if greedy_t is not None:
            for r in g["minutes"]:
                if r["p"] == w and r["t"] >= greedy_t and (not w_after or w_after[-1] != r["plan"]):
                    w_after.append(r["plan"])
        row = {"tag": tag, "map": g["map"], "res": res, "lead": lead, "end": g["end"], "slot": "P%d" % (g["slots"][c][2] + 1),
               "halls_c": halls[c], "halls_w": halls[w], "greedy": greedy_t is not None, "greedy_t": greedy_t,
               "greedy_plan": greedy_plan, "any_greedy_read": any(x["read"] == "GREEDY" for x in reads),
               "first_read": reads[0]["read"] if reads else "", "cplans": ">".join(cplans), "wplans": ">".join(wplans),
               "w_after": ">".join(w_after), "picks": [x["pick"] for x in picks], "cw_picks": [x["pick"] for x in cw_picks],
               "cw_greedy_read": "GREEDY" in cw_reads, "cw_aggr_read": "AGGRESSIVE" in cw_reads,
               "cw_plans_picked": [x["pick"].split("->")[1].strip().split(" ")[0] for x in sorted(cw_picks, key=lambda x: x["t"])],
               "cw_final_plan": g["final"][w].get("plan", ""),
               "first_hall_lost_c": first_lost[c], "score_ratio": sc[c] / max(1, sc[w]),
               "units_lost_c": g["final"][c].get("lost", 0), "units_lost_w": g["final"][w].get("lost", 0)}
        for m in (5, 8, 10, 12, 15):
            for k, p in (("c", c), ("w", w)):
                r = at.get((p, m))
                row["inc%d_%s" % (m, k)] = r["income"] if r else None
                row["army%d_%s" % (m, k)] = r["army"] if r else None
                row["halls%d_%s" % (m, k)] = r["halls"] if r else None
        out[tag] = row
    return out


def mean(v):
    v = [x for x in v if x is not None]
    return (st.mean(v), len(v)) if v else (float("nan"), 0)


def summary(rows):
    rs = list(rows.values())
    w = sum(r["res"] == "W" for r in rs); d = sum(r["res"] == "D" for r in rs); l = sum(r["res"] == "L" for r in rs)
    wl = sum(r["lead"] in ("W", "w") for r in rs); ll = sum(r["lead"] in ("L", "l") for r in rs)
    dec = [r["end"] for r in rs if r["res"] != "D"]
    return dict(n=len(rs), w=w, d=d, l=l, wl=wl, ll=ll, dec=dec, end=st.mean([r["end"] for r in rs]) if rs else 0)


def table(root, rnd):
    data = {c: load(root, c, rnd) for c in CONFIGS}
    data = {c: v for c, v in data.items() if v}
    print("## Results%s\n" % ("" if rnd is None else " (round %s only)" % rnd))
    print("| run | games | W-D-L | won or led | lost or trailed | decided (mean length) | mean end | halls lost Crown / CW | greedy pick fired (plan picked) |")
    print("|---|---|---|---|---|---|---|---|---|")
    for c, rows in data.items():
        s = summary(rows)
        rs = list(rows.values())
        gp = {}
        for r in rs:
            if r["greedy"]:
                gp[r["greedy_plan"]] = gp.get(r["greedy_plan"], 0) + 1
        print("| %s | %d | %d-%d-%d | %d | %d | %d (%s) | %s | %d / %d | %d (%s) |" % (
            c, s["n"], s["w"], s["d"], s["l"], s["wl"], s["ll"], len(s["dec"]), mmss(st.mean(s["dec"])) if s["dec"] else "-",
            mmss(s["end"]), sum(r["halls_c"] for r in rs), sum(r["halls_w"] for r in rs),
            sum(r["greedy"] for r in rs), ", ".join("%s %d" % kv for kv in sorted(gp.items()))))
    print("\n## The Crown's primary income against its bench, and the Clockwork's (mean over games still running)\n")
    print("| run | Crown 5:00 | 8:00 | 10:00 | 15:00 | CW 5:00 | 8:00 | 10:00 | 15:00 |")
    print("|---|---|---|---|---|---|---|---|---|")
    for c, rows in data.items():
        rs = list(rows.values())
        cells = []
        for m in (5, 8, 10, 15):
            v, n = mean([r["inc%d_c" % m] for r in rs])
            cells.append("%d = %.2f (%d)" % (v, v / BENCH_P[m], n) if n else "-")
        for m in (5, 8, 10, 15):
            v, n = mean([r["inc%d_w" % m] for r in rs])
            cells.append("%d (%d)" % (v, n) if n else "-")
        print("| %s | %s |" % (c, " | ".join(cells)))
    print("\n## Army value at 8/10/12 (Crown / Clockwork) and halls standing at 10:00\n")
    print("| run | army 8:00 | 10:00 | 12:00 | halls 10:00 |")
    print("|---|---|---|---|---|")
    for c, rows in data.items():
        rs = list(rows.values())
        cells = []
        for m in (8, 10, 12):
            a, n = mean([r["army%d_c" % m] for r in rs]); b, _ = mean([r["army%d_w" % m] for r in rs])
            cells.append("%d / %d (%d)" % (a, b, n) if n else "-")
        a, n = mean([r["halls10_c"] for r in rs]); b, _ = mean([r["halls10_w"] for r in rs])
        cells.append("%.1f / %.1f" % (a, b) if n else "-")
        print("| %s | %s |" % (c, " | ".join(cells)))
    print("\n## Continuous measures (the results are all at the floor)\n")
    print("| run | Crown score / CW score at the end (income + 2 x army; mean, median) | Crown's first hall lost (games, median time) | units lost Crown / CW (mean) |")
    print("|---|---|---|---|")
    for c, rows in data.items():
        rs = list(rows.values())
        sr = [r["score_ratio"] for r in rs]
        fl = [r["first_hall_lost_c"] for r in rs if r["first_hall_lost_c"] is not None]
        print("| %s | %.2f, %.2f | %d, %s | %d / %d |" % (c, st.mean(sr), st.median(sr), len(fl), mmss(st.median(fl)) if fl else "-",
              st.mean([r["units_lost_c"] for r in rs]), st.mean([r["units_lost_w"] for r in rs])))
    # paired: the same game (map, seed, sides) in two runs
    base = data.get("default")
    if base:
        print("\n## Paired with the default run (the same map, seed and sides)\n")
        print("| run | games paired | better result / same / worse (L < D- < D < D+ < W) | score ratio higher in |")
        print("|---|---|---|---|")
        rank = lambda r: {"L": 0, "l": 1, "=": 2, "w": 3, "W": 4}[r["lead"]]
        for c, rows in data.items():
            if c == "default":
                continue
            pr = [(base[t], rows[t]) for t in rows if t in base]
            b = sum(rank(y) > rank(x) for x, y in pr); e = sum(rank(y) == rank(x) for x, y in pr); wo = sum(rank(y) < rank(x) for x, y in pr)
            hi = sum(y["score_ratio"] > x["score_ratio"] for x, y in pr)
            print("| %s | %d | %d / %d / %d | %d of %d |" % (c, len(pr), b, e, wo, hi, len(pr)))
    print("\n## What the Clockwork did: its reads of the Crown and its OPTIMAL picks\n")
    print("| run | CW read the Crown GREEDY | read it AGGRESSIVE | CW plans picked (all picks) | CW plan at the end |")
    print("|---|---|---|---|---|")
    for c, rows in data.items():
        rs = list(rows.values())
        pk, fp = {}, {}
        for r in rs:
            for x in r["cw_plans_picked"]:
                pk[x] = pk.get(x, 0) + 1
            fp[r["cw_final_plan"]] = fp.get(r["cw_final_plan"], 0) + 1
        print("| %s | %d | %d | %s | %s |" % (c, sum(r["cw_greedy_read"] for r in rs), sum(r["cw_aggr_read"] for r in rs),
              ", ".join("%s %d" % kv for kv in sorted(pk.items(), key=lambda x: -x[1])),
              ", ".join("%s %d" % kv for kv in sorted(fp.items(), key=lambda x: -x[1]))))
    # the games where the greedy answer fired, split
    print("\n## Only the games where the greedy answer fired (in that run)\n")
    print("| run | games | W-D-L | won or led | Crown inc 8:00 | 10:00 | CW inc 10:00 | army 10:00 C / CW | halls lost C / CW |")
    print("|---|---|---|---|---|---|---|---|---|")
    for c, rows in data.items():
        g = {k: r for k, r in rows.items() if r["greedy"]}
        if not g:
            continue
        s = summary(g); rs = list(g.values())
        print("| %s | %d | %d-%d-%d | %d | %d | %d | %d | %d / %d | %d / %d |" % (
            c, s["n"], s["w"], s["d"], s["l"], s["wl"], mean([r["inc8_c"] for r in rs])[0], mean([r["inc10_c"] for r in rs])[0],
            mean([r["inc10_w"] for r in rs])[0], mean([r["army10_c"] for r in rs])[0], mean([r["army10_w"] for r in rs])[0],
            sum(r["halls_c"] for r in rs), sum(r["halls_w"] for r in rs)))
    print("\n## Game by game (Crown's result; + = a draw it led; the greedy pick; the Clockwork's plans after it)\n")
    tags = sorted(set().union(*[set(v) for v in data.values()]))
    print("| game | slot | " + " | ".join(data) + " |")
    print("|---|---|" + "---|" * len(data))
    for t in tags:
        cells = []
        slot = ""
        for c, rows in data.items():
            r = rows.get(t)
            if not r:
                cells.append("-"); continue
            slot = r["slot"]
            s = r["res"] + ("+" if r["lead"] == "w" else ("-" if r["lead"] == "l" else ""))
            s += " %s" % mmss(r["end"]) if r["res"] != "D" else ""
            if r["greedy"]:
                s += " · G@%s %s · CW %s" % (mmss(r["greedy_t"]), r["greedy_plan"], r["w_after"])
            else:
                s += " · %s" % (r["first_read"] or "no read")
            cells.append(s)
        print("| %s | %s | %s |" % (t.replace("base_", "").replace("_crcw", ""), slot, " | ".join(cells)))


if __name__ == "__main__":
    root = sys.argv[1]
    rnd = sys.argv[2] if len(sys.argv) > 2 else None
    table(root, rnd)
