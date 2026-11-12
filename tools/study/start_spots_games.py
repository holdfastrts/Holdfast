#!/usr/bin/env python3
"""START SPOTS (start-spots study, docs/start_spots_study.md): MIRROR games only (Crown v Crown, Brood v Brood,
Clockwork v Clockwork, Hard OPTIMAL both sides, to 15:00) on the maps where the QA match study saw a start-spot edge,
plus control maps. Measuring only: it runs tools/start_spots_match.gd (tools/qa_match.gd plus a base layout record) and
changes no rule.
    python3 tools/study/start_spots_games.py run OUT [--data DATA] [--jobs 2] [--rounds 4] [--facs brood,crown]
    python3 tools/study/start_spots_games.py list [--rounds 4]
Round r plays every map x the three mirrors once (a cut run stays balanced). On NAMED maps the odd rounds SWAP: player
index 0 is given side number 1, which MapGen.spot_order turns into the SECOND start spot, so the spot and the player index
(who ticks first, whose computer thinks first) come apart. Classic maps put index 0 on the first spot whatever the side
number (MapGen._base_spots), so there the two stay together.
The record of each game (DATA/<tag>/meta.json) says which player index stood on spot A (the map's first start)."""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qa_matches as Q
import shutil, subprocess

SUSPECT = ["red_coast", "frostfang", "ashfall", "redrock_canyon", "mirewood", "thornwood_maze", "amberfall_vale"]
CONTROL = ["greenhold", "ashford_crossing", "kestrel_rise"]
MAPS = SUSPECT + CONTROL
FACS = ["crown", "brood", "clockwork"]
SH = {"crown": "cr", "brood": "br", "clockwork": "cw"}


def named(m):
    return m in Q.NAMED_1V1


def run_one(g, out, end, data):
    """qa_matches.run_one with the start-spots tool, also keeping layout.json"""
    tag, m, seed, slots = g
    dd = os.path.join(data, tag)
    if os.path.exists(os.path.join(dd, "result.json")) or os.path.exists(os.path.join(dd, "FAILED.txt")):
        return tag + " (had)"
    d = os.path.join(out, tag)
    os.makedirs(d, exist_ok=True)
    spec = ",".join("%s/%s/%d" % s for s in slots)
    cmd = ["timeout", "3000", os.environ.get("GODOT", "godot"), "--headless", "--fixed-fps", "30", "--path", Q.ROOT,
           "--script", "res://tools/start_spots_match.gd", "--", "map:" + m, "seed:%d" % seed, "end:%d" % end,
           "out:" + d, "slots:" + spec]
    with open(os.path.join(d, "run.out"), "wb") as f:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        n = 0
        for chunk in iter(lambda: p.stdout.read(65536), b""):
            if n < 20_000_000:
                f.write(chunk)
            n += len(chunk)
        rc = p.wait()
    os.makedirs(dd, exist_ok=True)
    for fn in ("result.json", "story.txt", "layout.json"):
        if os.path.exists(os.path.join(d, fn)):
            shutil.copy(os.path.join(d, fn), dd)
    with open(os.path.join(d, "run.out"), errors="replace") as f:
        lines = f.read().splitlines()
    errs = [l.strip() for l in lines if Q.ERR.search(l)]
    if errs:
        seen = {}
        for e in errs:
            seen[e] = seen.get(e, 0) + 1
        with open(os.path.join(dd, "errors.txt"), "w") as f:
            f.write("%d error lines\n" % len(errs))
            for e, c in sorted(seen.items(), key=lambda x: -x[1])[:60]:
                f.write("%5d  %s\n" % (c, e))
    if not os.path.exists(os.path.join(d, "result.json")):
        with open(os.path.join(dd, "FAILED.txt"), "w") as f:
            f.write("no result: exit code %d; last lines:\n%s\n" % (rc, "\n".join(lines[-40:])))
    else:
        shutil.rmtree(d, ignore_errors=True)
    return tag


def queue(rounds):
    out = []
    for r in range(rounds):
        for mi, m in enumerate(MAPS):
            for fi, f in enumerate(FACS):
                seed = 2300 + 41 * r + 3 * mi + fi
                swap = named(m) and r % 2 == 1
                s0 = 1 if swap else 0
                tag = "ss_%s_%s_r%d%s" % (m, SH[f], r, "_swap" if swap else "")
                out.append((tag, m, seed, [(f, "optimal", s0), (f, "optimal", 1 - s0)], swap))
    return out


if __name__ == "__main__":
    arg = lambda k, d: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else d
    rounds = int(arg("--rounds", "4"))
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    if sys.argv[1] == "list":
        for g in queue(rounds):
            print(*g)
        sys.exit(0)
    out = os.path.abspath(sys.argv[2])
    data = os.path.abspath(arg("--data", os.path.join(Q.ROOT, "docs/start_spots_study/data")))
    jobs = int(arg("--jobs", "2"))
    gl = queue(rounds)
    if "--facs" in sys.argv:
        keep = arg("--facs", "").split(",")
        gl = [g for g in gl if g[2] and g[3][0][0] in keep]
    print("%d games" % len(gl), flush=True)
    from concurrent.futures import ThreadPoolExecutor

    def one(g):
        tag, m, seed, slots, swap = g
        r = run_one((tag, m, seed, slots), out, 900, data)
        dd = os.path.join(data, tag)
        if os.path.isdir(dd):
            with open(os.path.join(dd, "meta.json"), "w") as f:
                json.dump({"map": m, "seed": seed, "fac": slots[0][0], "swap": swap,
                           "spotA_index": 1 if swap else 0}, f)
        return r

    with ThreadPoolExecutor(jobs) as ex:
        for t in ex.map(one, gl):
            print("done", t, flush=True)
