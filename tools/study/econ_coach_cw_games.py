#!/usr/bin/env python3
"""The Clockwork's games of the economy-parity batch (econ-coach-clockwork, docs/econ-coach-clockwork.md): the 36 games
of `qa_matches.py --only parity` with a Clockwork side (Crown v Clockwork, Brood v Clockwork, the Clockwork mirror; 6 maps x
2 rounds, the qa-matches tags and seeds), Hard OPTIMAL v Hard OPTIMAL to 15:00.
    python3 tools/study/econ_coach_cw_games.py OUT DATA [--jobs 2] [--extra cwmacro:off] [--only crcw|brcw|cwcw] [--reverse]
DATA/<tag>/result.json as qa_matches.py writes it (tools/study/econ_parity_report.py reads it)."""
import os, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qa_matches as q

if __name__ == "__main__":
    out, data = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
    arg = lambda k, d: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else d
    jobs = int(arg("--jobs", "2"))
    if "--extra" in sys.argv:
        q.EXTRA = arg("--extra", "").split(",")
    q.KEEP_CW = True
    gl = [g for g in q.parity() if "cw" in g[0].split("_")[-2]]
    if "--only" in sys.argv:
        gl = [g for g in gl if g[0].split("_")[-2] == arg("--only", "")]     # (a pairing: crcw, brcw or cwcw)
    if "--reverse" in sys.argv:
        gl = gl[::-1]
    print("%d games" % len(gl), flush=True)
    with ThreadPoolExecutor(jobs) as ex:
        for t in ex.map(lambda g: q.run_one(g, out, 900, data), gl):
            print("done", t, flush=True)
