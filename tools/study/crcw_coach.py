#!/usr/bin/env python3
"""CROWN V CLOCKWORK COACH (crown-v-clockwork-coach, docs/crown-v-clockwork-coach.md): Hard Crown OPTIMAL v Hard Clockwork
OPTIMAL measured with tools/qa_match.gd (the qa-matches base tags and seeds, both start slots), plus a small batch of each
faction's other matchups as a control. A measuring tool: it changes no rule.
    python3 tools/study/crcw_coach.py run OUT --data DATA [--only measure|others|one:map:seed] [--jobs 2] [--root DIR] [--reverse] [--args a,b]
    python3 tools/study/crcw_coach.py list [--only ...]"""
import os, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qa_matches as Q

MAPS = ["greenhold", "dune_sea", "hollowfen", "kestrel_rise", "ashford_crossing", "red_coast", "frostmere", "border_march"]
OTHER_MAPS = ["greenhold", "kestrel_rise", "frostmere"]


def measure():
    return [g for r in (0, 1) for g in Q.base(r) if g[1] in MAPS and g[0].endswith("_crcw_r%d" % r)]


def others():
    """the Crown v the Brood and the Clockwork v the Brood (and both mirrors) on three maps, round 0"""
    keep = ("_crbr_r0", "_brcw_r0", "_crcr_r0", "_cwcw_r0")
    return [g for g in Q.base(0) if g[1] in OTHER_MAPS and g[0].endswith(keep)]


def queue(only):
    if only == "measure":
        return measure()
    if only == "others":
        return others()
    if only.startswith("one:"):
        _, m, seed = only.split(":")
        return [g for r in (0, 1) for g in Q.base(r) if g[1] == m and g[0].endswith("_crcw_r%d" % r) and str(g[2]) == seed]
    return []


if __name__ == "__main__":
    arg = lambda k, dflt: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else dflt
    gl = queue(arg("--only", "measure"))
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        for g in gl:
            print(g[0], g[1], g[2], g[3])
        sys.exit(0)
    out = os.path.abspath(sys.argv[2])
    Q.RUN_ROOT = os.path.abspath(arg("--root", Q.ROOT))
    Q.KEEP_CW = True
    Q.EXTRA = [a for a in arg("--args", "").split(",") if a]      # (e.g. --args crcw:onehall)
    data = os.path.abspath(arg("--data", os.path.join(out, "data")))
    jobs = int(arg("--jobs", "2"))
    end = int(arg("--end", "900"))
    if "--reverse" in sys.argv:
        gl = gl[::-1]       # (a second runner on the same data, from the other end)
    print("%d games" % len(gl), flush=True)
    with ThreadPoolExecutor(jobs) as ex:
        for t in ex.map(lambda g: Q.run_one(g, out, end, data), gl):
            print("done", t, flush=True)
