#!/usr/bin/env python3
"""WIN RATES, the two mirrors (job winrate-c, docs/winrate-c.md): the Clockwork mirror and the Brood mirror played on the
SAME design, maps, seeds and tags as the qa-matches study (docs/qa_2026_11_08_matches.md, tools/study/qa_matches.py):
Hard OPTIMAL v Hard OPTIMAL, the 19 two-player maps x 2 seeds (round 0 and round 1), up to 15:00. A measuring tool only.
    python3 tools/study/winrate_c.py run OUT [--jobs 2] [--only cwcw|brbr]
    python3 tools/study/winrate_c.py list
Data goes to docs/winrate_2026_11_12/winrate-c/data/<tag>/ (result.json, story.txt, errors.txt). A game is done when its
result.json exists: run again to resume. The queue alternates the two mirrors so a cut run has both."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qa_matches as qm
from concurrent.futures import ThreadPoolExecutor

DATA = os.path.join(qm.ROOT, "docs/winrate_2026_11_12/winrate-c/data")


def queue(only=""):
    games = [g for g in qm.base(0) + qm.base(1) if g[0].split("_")[-2] in ("brbr", "cwcw")]
    if only:
        games = [g for g in games if g[0].split("_")[-2] == only]
    br = [g for g in games if "_brbr_" in g[0]]
    cw = [g for g in games if "_cwcw_" in g[0]]
    out = []
    for i in range(max(len(br), len(cw))):
        out += cw[i:i + 1] + br[i:i + 1]
    return out


if __name__ == "__main__":
    arg = lambda k, d: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else d
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    q = queue(arg("--only", ""))
    if sys.argv[1] == "list":
        for g in q:
            print(g[0], g[1], g[2], g[3])
        sys.exit(0)
    out = os.path.abspath(sys.argv[2])
    os.makedirs(DATA, exist_ok=True)
    print("%d games" % len(q), flush=True)
    with ThreadPoolExecutor(int(arg("--jobs", "2"))) as ex:
        for t in ex.map(lambda g: qm.run_one(g, out, 900, DATA), q):
            print("done", t, flush=True)
