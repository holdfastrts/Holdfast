#!/usr/bin/env python3
"""ECON COACH CROWN (econ-coach-crown, docs/econ-coach-crown.md): the Crown computer's economy in real games, against the
bench's design (tools/econ_bench.gd, Greenhold 4/8/12, primary only as the games count it).
    python3 tools/study/econ_coach_crown.py DATA [DATA ...]      (directories of qa_match game folders with result.json)
Per matchup: the Crown's primary income at 5/8/10/15 against the bench, halls over time, workers, idle workers, the plans
it played, its read picks, results."""
import json, os, sys, statistics as st
BENCH_P = {5: 4180, 8: 9500, 10: 13180, 15: 24460}     # the bench's primary earned (docs/economy_parity.md section 3)
SH = {"crown": "cr", "brood": "br", "clockwork": "cw"}


def games(dirs):
    for d in dirs:
        for tag in sorted(os.listdir(d)):
            f = os.path.join(d, tag, "result.json")
            if os.path.exists(f):
                yield tag, json.load(open(f))


def at(rows, p, t):
    r = [x for x in rows if x["p"] == p and x["t"] == t]
    return r[0] if r else None


def main(dirs):
    by = {}
    for tag, d in games(dirs):
        facs = [s[0] for s in d["slots"]]
        if "crown" not in facs:
            continue
        for p, f in enumerate(facs):
            if f != "crown":
                continue
            o = facs[1 - p]
            key = "cr v " + SH[o]
            if o == "crown" and p == 1:
                key = "cr v cr (P2)"
            elif o == "crown":
                key = "cr v cr (P1)"
            res = "D" if not d["over"] else ("W" if d["winner"] == p else "L")
            row = {"res": res, "end": d["end"]}
            for m in (3, 5, 8, 10, 12, 15):
                r = at(d["minutes"], p, m * 60)
                if r:
                    row["inc%d" % m] = r["income"]
                    row["halls%d" % m] = r["halls"]
                    row["w%d" % m] = r["workers"]
                    row["army%d" % m] = r["army"]
                    row["idle%d" % m] = r.get("idle_w_avg", 0)
                    row["bank%d" % m] = r["bank"]
            plans = []
            for r in d["minutes"]:
                if r["p"] == p and (not plans or plans[-1] != r["plan"]):
                    plans.append(r["plan"])
            row["plans"] = ">".join(plans)
            row["picks"] = [x.get("pick") for x in d.get("reads", []) if x["p"] == p and "pick" in x]
            row["reads"] = [x.get("read") for x in d.get("reads", []) if x["p"] == p and "read" in x][:2]
            by.setdefault(key, []).append(row)
    for k in sorted(by):
        rs = by[k]
        w = sum(1 for r in rs if r["res"] == "W"); dr = sum(1 for r in rs if r["res"] == "D"); l = len(rs) - w - dr
        print("\n== %s: %d games  W-D-L %d-%d-%d" % (k, len(rs), w, dr, l))
        for m in (5, 8, 10, 15):
            v = [r["inc%d" % m] for r in rs if "inc%d" % m in r]
            if not v:
                continue
            h = [r["halls%d" % m] for r in rs if "halls%d" % m in r]
            wk = [r["w%d" % m] for r in rs if "w%d" % m in r]
            ar = [r["army%d" % m] for r in rs if "army%d" % m in r]
            idl = [r["idle%d" % m] for r in rs if "idle%d" % m in r]
            bk = [r["bank%d" % m] for r in rs if "bank%d" % m in r]
            print("  %2d:00 income %6d (%.2f of bench, n=%d)  halls %.1f  workers %.0f  idle %.1f  army %5d  bank %5d" % (
                m, st.mean(v), st.mean(v) / BENCH_P[m], len(v), st.mean(h), st.mean(wk), st.mean(idl), st.mean(ar), st.mean(bk)))
        pl = {}
        for r in rs:
            pl[r["plans"]] = pl.get(r["plans"], 0) + 1
        print("  plans:", sorted(pl.items(), key=lambda x: -x[1])[:8])
        pk = {}
        for r in rs:
            for x in r["picks"]:
                x = x.split(" (")[0]
                pk[x] = pk.get(x, 0) + 1
        print("  picks:", sorted(pk.items(), key=lambda x: -x[1])[:8])


if __name__ == "__main__":
    main(sys.argv[1:])
