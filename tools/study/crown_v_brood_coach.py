#!/usr/bin/env python3
"""CROWN V BROOD COACH (crown-v-brood-coach, docs/crown_v_brood_coach.md): Hard computer games measured with
tools/qa_match.gd for the Crown computer's play against the Brood. A measuring tool: it changes no rule.
    python3 tools/study/crown_v_brood_coach.py run OUT --data DATA --only measure|plans|controls [--jobs 2] [--end 900] [--root DIR]
    python3 tools/study/crown_v_brood_coach.py list --only ...
  measure:  Crown OPTIMAL v Brood OPTIMAL, the 16 games of docs/crown_ai_v2.md (8 maps, 2 seeds, sides swapped);
  plans:    Crown OPTIMAL / Economy / Rush / Balanced v the Brood's Economy and Rush plans on 3 maps (sides alternating);
  controls: Crown OPTIMAL v Clockwork OPTIMAL (6) and the Crown mirror (4), to check nothing else got worse."""
import os, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qa_matches as Q
import crown_ai_v2 as C

PLAN_MAPS = ["kestrel_rise", "hollowfen", "dune_sea"]
CROWN = ["optimal", "economy", "rush", "balanced"]
BROOD = ["economy", "rush"]
CTRL_CW = ["greenhold", "dune_sea", "hollowfen"]
CTRL_CR = ["greenhold", "dune_sea", "hollowfen", "frostmere"]


def measure():
    return [g for g in C.measure((0,)) if "crbr" in g[0]]


QUICK_MAPS = ["greenhold", "dune_sea", "hollowfen", "frostmere"]


def quick():
    """(a coaching round's check) Crown OPTIMAL v Brood OPTIMAL, round 0 of 4 measure maps"""
    return [g for g in measure() if g[1] in QUICK_MAPS and g[0].endswith("_r0")]


def plans():
    out = []
    k = 0
    for m in PLAN_MAPS:
        for b in BROOD:
            for p in CROWN:
                me, foe = ("crown", p), ("brood", b)
                s1, s2 = (foe, me) if k % 2 else (me, foe)
                out.append(("plan_cr-%s_v_br-%s_%s" % (p, b, m), m, 9300 + k, [(s1[0], s1[1], 0), (s2[0], s2[1], 1)]))
                k += 1
    return out


def controls():
    out = []
    for g in C.measure((0,)):
        if ("crcw" in g[0] and g[1] in CTRL_CW) or ("crcr" in g[0] and g[1] in CTRL_CR):
            out.append(g)
    return out


def queue(only):
    q = []
    for part in only.split("+"):
        q += {"measure": measure, "plans": plans, "controls": controls, "quick": quick}[part]()
    return q


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
    Q.RUN_ROOT = os.path.abspath(arg("--root", Q.ROOT))
    data = os.path.abspath(arg("--data", os.path.join(out, "data")))
    jobs = int(arg("--jobs", "2"))
    end = int(arg("--end", "900"))
    print("%d games" % len(gl), flush=True)
    with ThreadPoolExecutor(jobs) as ex:
        for t in ex.map(lambda g: Q.run_one(g, out, end, data), gl):
            print("done", t, flush=True)
