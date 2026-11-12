#!/usr/bin/env python3
"""WIN RATES, job winrate-b (docs/winrate-b.md): Clockwork v Brood and the Crown mirror, the SAME base games as
docs/qa_2026_11_08_matches.md (tools/qa_match.gd, Hard OPTIMAL v Hard OPTIMAL, 19 maps x 2 seeds, sides swapped between
the seeds, up to 15:00): the same tags, maps and seeds as the 0.33.7 study, only the two pairings. A measuring tool.
    python3 tools/study/winrate_b.py run OUT [--jobs 2] [--data DIR]
    python3 tools/study/winrate_b.py list
Data: docs/winrate_2026_11_12/winrate-b/data/<tag>/ (result.json, story.txt, errors.txt). Resumable."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qa_matches as qm
from concurrent.futures import ThreadPoolExecutor

ROOT = qm.ROOT
DATA = os.path.join(ROOT, "docs/winrate_2026_11_12/winrate-b/data")
KEEP = ("brcw", "crcr")


def queue():
    q = [g for g in qm.base(0) + qm.base(1) if g[0].split("_")[-2] in KEEP]
    # interleave the two pairings so a cut run is balanced
    a = [g for g in q if "_brcw_" in g[0]]
    b = [g for g in q if "_crcr_" in g[0]]
    out = []
    for x, y in zip(a, b):
        out += [x, y]
    return out


if __name__ == "__main__":
    arg = lambda k, d: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else d
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    if sys.argv[1] == "list":
        for g in queue():
            print(g[0], g[1], g[2], g[3])
        sys.exit(0)
    out = os.path.abspath(sys.argv[2])
    data = os.path.abspath(arg("--data", DATA))
    jobs = int(arg("--jobs", "2"))
    gl = queue()
    print("%d games" % len(gl), flush=True)
    with ThreadPoolExecutor(jobs) as ex:
        for t in ex.map(lambda g: qm.run_one(g, out, 900, data), gl):
            print("done", t, flush=True)
