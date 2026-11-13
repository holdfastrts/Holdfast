#!/usr/bin/env python3
"""ECON-COACH-BROOD (docs/econ-coach-brood.md): the Brood's games of the economy-parity set (tools/study/qa_matches.py
--only parity: 6 maps x 2 rounds, the qa-matches tags and seeds), Hard OPTIMAL v Hard OPTIMAL to 15:00: only the
pairings with a Brood side (Brood v Crown, Brood v Clockwork, the Brood mirror): 36 games. A measuring tool.
    python3 tools/study/econ_coach_brood.py run OUT --data DATA [--jobs 2] [--vs crown|clockwork|brood] [--extra a,b]
    python3 tools/study/econ_coach_brood.py report DATA [DATA2]     (Brood sides: income, workers, supply blocks, banks)
--extra passes switches to every game (e.g. nbsupply:off). The same tags as the win-rate study's data
(docs/winrate_2026_11_12/winrate-*/data), so those games are the BEFORE of main 0.33.25."""
import os, sys, json, glob, statistics as st
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qa_matches as qm

SH = {"crown": "cr", "clockwork": "cw", "brood": "br"}


def games(vs=""):
    out = []
    for g in qm.parity():
        pair = g[0].split("_")[-2]
        if "br" not in pair:
            continue
        if vs and SH[vs] not in pair.replace("br", "", 1) and not (vs == "brood" and pair == "brbr"):
            continue
        out.append(g)
    return out


def load(dirs):
    out = []
    for d in dirs:
        for f in sorted(glob.glob(os.path.join(d, "base_*", "result.json"))):
            r = json.load(open(f))
            if r["map"] not in qm.PARITY_MAPS:
                continue
            out.append((os.path.basename(os.path.dirname(f)), r))
    return out


def sides(data):
    """every Brood side: (tag, foe, result, rows by minute)"""
    out = []
    for tag, r in data:
        facs = [s[0] for s in r["slots"]]
        for p, fac in enumerate(facs):
            if fac != "brood":
                continue
            rows = {m["t"] // 60: m for m in r["minutes"] if m["p"] == p}
            w = r.get("winner")
            res = "D" if w is None or w < 0 else ("W" if w == p else "L")
            out.append((tag, facs[1 - p], res, rows, r, p))
    return out


def report(dirs):
    S = sides(load(dirs))
    print("%d Brood sides from %s" % (len(S), ", ".join(dirs)))
    print("%-10s %3s %8s %6s %6s %6s %6s | %5s %5s %5s | %6s %6s | %6s %7s | %5s %5s" % (
        "v", "n", "W-D-L", "inc5", "inc8", "inc10", "inc15", "wk5", "wk8", "wk10", "army8", "army10", "blk4-6", "bank1k", "maws8", "st2"))
    for foe in ["crown", "clockwork", "brood", "all"]:
        L = [s for s in S if foe == "all" or s[1] == foe]
        if not L:
            continue
        def at(mn, k):
            v = [s[3][mn][k] for s in L if mn in s[3]]
            return st.mean(v) if v else float("nan")
        blk = [1 if s[3][m]["cap"] < 200 and s[3][m]["supply"] + 2 >= s[3][m]["cap"] else 0 for s in L for m in (4, 5, 6) if m in s[3]]
        bank = [1 if x["bank"] >= 1000 and x["supply"] < x["cap"] - 10 else 0 for s in L for mm, x in s[3].items() if mm >= 3]
        wdl = "%d-%d-%d" % (sum(s[2] == "W" for s in L), sum(s[2] == "D" for s in L), sum(s[2] == "L" for s in L))
        st2 = []
        for s in L:
            for e in s[4].get("events", []):
                pass
        print("%-10s %3d %8s %6.0f %6.0f %6.0f %6.0f | %5.1f %5.1f %5.1f | %6.0f %6.0f | %6.2f %7.2f | %5.1f" % (
            foe, len(L), wdl, at(5, "income"), at(8, "income"), at(10, "income"), at(15, "income"), at(5, "workers"), at(8, "workers"),
            at(10, "workers"), at(8, "army"), at(10, "army"), st.mean(blk) if blk else 0, st.mean(bank) if bank else 0, at(8, "maws")))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    arg = lambda k, d: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else d
    if sys.argv[1] == "report":
        report([a for a in sys.argv[2:] if not a.startswith("--")])
        sys.exit(0)
    out = os.path.abspath(sys.argv[2])
    data = os.path.abspath(arg("--data", out + "_data"))
    qm.RUN_ROOT = os.path.abspath(arg("--root", qm.ROOT))
    ex = arg("--extra", "")
    qm.EXTRA = [e for e in ex.split(",") if e]
    gl = games(arg("--vs", ""))
    print("%d games" % len(gl), flush=True)
    with ThreadPoolExecutor(int(arg("--jobs", "2"))) as pool:
        for t in pool.map(lambda g: qm.run_one(g, out, 900, data), gl):
            print("done", t, flush=True)
