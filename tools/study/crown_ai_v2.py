#!/usr/bin/env python3
"""CROWN AI V2 (crown-ai-v2, docs/crown_ai_v2.md): Hard computer games measured with tools/qa_match.gd, for the Crown
computer's fixes. A measuring tool: it changes no rule.
    python3 tools/study/crown_ai_v2.py run OUT --data DATA --only plans|measure [--jobs 2] [--end 900]
    python3 tools/study/crown_ai_v2.py list --only plans|measure
  plans:   every Crown plan against Hard Brood OPTIMAL and Hard Clockwork OPTIMAL on a few maps, sides alternating
           (what OPTIMAL should pick for the Crown in the cross matchups);
  measure: Crown OPTIMAL against Brood OPTIMAL and Clockwork OPTIMAL on 8 maps, 2 seeds each (sides swapped), plus the
           Crown mirror as a control: the SAME maps, seeds and sides as the qa-matches base games
           (docs/qa_2026_11_08_matches/data), so those games are the "before"."""
import os, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qa_matches as Q

MEASURE_MAPS = ["greenhold", "highmoor", "dune_sea", "red_coast", "thornwood_maze", "hollowfen", "frostmere",
                "amberfall_vale"]
PLAN_MAPS = ["border_march", "ashford_crossing", "kestrel_rise", "glimmerdeep"]
CROWN_PLANS = ["balanced", "rush", "economy", "timing", "dragoon", "siege", "balloon"]


def measure():
    out = []
    for r in (0, 1):
        for g in Q.base(r):
            tag, m, seed, slots = g
            fs = sorted(s[0] for s in slots)
            if m in MEASURE_MAPS and "crown" in fs and fs != ["brood", "clockwork"]:
                out.append(g)
    return out


def plans(maps=None, which=None):
    """which: {opponent: [plans]} (default: every Crown plan against both)"""
    out = []
    k = 0
    for m in (maps or PLAN_MAPS):
        for o in ("brood", "clockwork"):
            for p in CROWN_PLANS:
                if which is not None and p not in which.get(o, []):
                    k += 1
                    continue
                seed = 8100 + k
                me, foe = ("crown", p), (o, "optimal")
                s1, s2 = (foe, me) if k % 2 else (me, foe)
                tag = "plan_cr-%s_v_%s_%s" % (p, Q.SHORT[o], m)
                out.append((tag, m, seed, [(s1[0], s1[1], 0), (s2[0], s2[1], 1)]))
                k += 1
    return out


def queue(only):
    if only == "measure":
        return measure()
    if only == "plans":
        return plans()
    if only.startswith("plans:"):
        return plans(only[6:].split("+"))
    if only.startswith("pick:"):          # pick:map1+map2:brood=economy+rush,clockwork=economy+balloon
        _, ms, w = only.split(":", 2)
        which = {kv.split("=")[0]: kv.split("=")[1].split("+") for kv in w.split(",")}
        return plans(ms.split("+"), which)
    if only.startswith("one:"):          # one:map:seed:f/p/s,f/p/s
        _, m, seed, spec = only.split(":", 3)
        slots = [tuple(x.split("/")[:2]) + (int(x.split("/")[2]),) for x in spec.split(",")]
        return [("one_%s_%s" % (m, seed), m, int(seed), slots)]
    return []


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    arg = lambda k, dflt: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else dflt
    gl = queue(arg("--only", "measure"))
    if sys.argv[1] == "list":
        for g in gl:
            print(g[0], g[1], g[2], g[3])
        sys.exit(0)
    out = os.path.abspath(sys.argv[2])
    data = os.path.abspath(arg("--data", os.path.join(out, "data")))
    jobs = int(arg("--jobs", "2"))
    end = int(arg("--end", "900"))
    print("%d games" % len(gl), flush=True)
    with ThreadPoolExecutor(jobs) as ex:
        for t in ex.map(lambda g: Q.run_one(g, out, end, data), gl):
            print("done", t, flush=True)
