#!/usr/bin/env python3
"""QA MATCHES (qa-matches, docs/qa_2026_11_08_matches.md): Hard computer v Hard computer up to 15:00 with
tools/qa_match.gd, measured. A measuring tool: it changes no rule.
    python3 tools/study/qa_matches.py run OUT --data DATA [--jobs 2] [--end 900] [--only base|plans|multi|cw] [--root DIR] [--cwlog] [--reverse]
    python3 tools/study/qa_matches.py list            (the queue, in order)
The queue, in order (a cut run still has balanced data):
  base round 0 and 1: every 2-player map x the six pairings (Crown v Brood, Crown v Clockwork, Brood v Clockwork and the
      three mirrors), OPTIMAL on both sides; round 0 and round 1 swap the sides on each map (and alternate by map), so each
      cross pairing plays each start spot once per map;
  plans: each faction's other listed plans once against OPTIMAL of a rotating faction, the map rotating;
  multi: a few 4-player games (free-for-all on classic maps, 2v2 on team maps).
A game is done when DATA/<tag>/result.json exists; run again to resume. Raw output goes to OUT/<tag>/run.out; the kept
data (result.json, story.txt, errors.txt with every SCRIPT ERROR / ERROR line) to DATA/<tag>/."""
import os, sys, subprocess, shutil, re
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RUN_ROOT = ROOT
KEEP_CW = False
EXTRA = []          # (crown-v-clockwork-coach) more user args for every game, e.g. ["crcw:off"]
CLASSIC = ["greenhold", "highmoor", "dune_sea", "frostfang", "twin_fords", "ashfall", "mirewood", "border_march", "red_coast"]
NAMED_1V1 = ["ashford_crossing", "kestrel_rise", "thornwood_maze", "redrock_canyon", "saltmarsh_isles", "glimmerdeep",
             "frostmere", "cinder_steps", "hollowfen", "amberfall_vale"]
MAPS = CLASSIC + NAMED_1V1
PAIRS = [("crown", "brood"), ("crown", "clockwork"), ("brood", "clockwork"),
         ("crown", "crown"), ("brood", "brood"), ("clockwork", "clockwork")]
SHORT = {"crown": "cr", "brood": "br", "clockwork": "cw"}
PLANS = {
    "crown": ["balanced", "rush", "economy", "timing", "dragoon", "siege", "balloon"],
    "brood": ["balanced", "rush", "economy", "timing", "air", "xrush", "spitter", "brute"],
    "clockwork": ["balanced", "rush", "economy", "timing", "pendulum", "heavy", "springer", "cs_rush", "owls"],
}
FACS = ["crown", "brood", "clockwork"]


def base(r):
    out = []
    for mi, m in enumerate(MAPS):
        for pi, (a, b) in enumerate(PAIRS):
            seed = 1100 + 37 * r + 3 * mi + pi
            swap = (r + mi) % 2 == 1
            s1, s2 = ((b, "optimal"), (a, "optimal")) if swap else ((a, "optimal"), (b, "optimal"))
            tag = "base_%s_%s%s_r%d" % (m, SHORT[a], SHORT[b], r)
            out.append((tag, m, seed, [(s1[0], s1[1], 0), (s2[0], s2[1], 1)]))
    return out


def plans():
    """each other plan of each faction once, against OPTIMAL of a rotating opponent faction (each faction's plans meet
    all three), the map rotating, sides alternating"""
    out = []
    k = 0
    for fi, f in enumerate(FACS):
        for pi, p in enumerate(PLANS[f]):
            o = FACS[(fi + pi) % 3]
            m = MAPS[(k * 7) % len(MAPS)]
            seed = 5100 + k
            swap = k % 2 == 1
            me, foe = (f, p), (o, "optimal")
            s1, s2 = (foe, me) if swap else (me, foe)
            tag = "plan_%s-%s_v_%s_%s" % (SHORT[f], p, SHORT[o], m)
            out.append((tag, m, seed, [(s1[0], s1[1], 0), (s2[0], s2[1], 1)]))
            k += 1
    return out


def multi():
    o = "optimal"
    return [
        ("ffa_greenhold_1", "greenhold", 7101, [("crown", o, 0), ("brood", o, 1), ("clockwork", o, 2), ("crown", o, 3)]),
        ("ffa_highmoor_1", "highmoor", 7102, [("brood", o, 0), ("clockwork", o, 1), ("crown", o, 2), ("brood", o, 3)]),
        ("ffa_red_coast_1", "red_coast", 7103, [("clockwork", o, 0), ("crown", o, 1), ("brood", o, 2), ("clockwork", o, 3)]),
        ("2v2_twin_crowns_1", "twin_crowns", 7201, [("crown", o, 0), ("brood", o, 0), ("clockwork", o, 1), ("crown", o, 1)]),
        ("2v2_jade_wilds_1", "jade_wilds", 7202, [("brood", o, 0), ("clockwork", o, 0), ("crown", o, 1), ("brood", o, 1)]),
        ("2v2_ember_reach_1", "ember_reach", 7203, [("clockwork", o, 0), ("crown", o, 0), ("brood", o, 1), ("clockwork", o, 1)]),
    ]


# (clockwork-ai-v2) the Clockwork's three pairings on 8 maps (its best and worst of the qa study and a few between), the
# same tags and seeds as the base rounds: `--only cw`
CW_MAPS = ["cinder_steps", "red_coast", "ashfall", "greenhold", "frostfang", "dune_sea", "redrock_canyon", "twin_fords"]


def cw():
    return [g for g in base(0) + base(1) if g[1] in CW_MAPS and "cw" in g[0].split("_")[-2]]


# (economy-parity, docs/economy_parity.md) six maps of all kinds, every pairing, both rounds (the sides swapped): 12
# games a pairing, the same tags and seeds as the base rounds: `--only parity`
PARITY_MAPS = ["greenhold", "dune_sea", "frostfang", "ashford_crossing", "hollowfen", "cinder_steps"]


def parity():
    return [g for r in (0, 1) for g in base(r) if g[1] in PARITY_MAPS]


# (econ-coach-crown, docs/econ-coach-crown.md) the parity games with a Crown side: Crown v Brood, Crown v Clockwork and the
# Crown mirror, 12 a pairing: `--only crown` (`--only crcw` / `crbr` / `crcr`: one pairing)
def crown(pair=""):
    if pair:
        return [g for g in parity() if g[0].split("_")[-2] == pair]
    return [g for g in parity() if "cr" in (g[0].split("_")[-2][:2], g[0].split("_")[-2][2:])]


def queue(only=""):
    if only == "crown":
        return crown()
    if only in ("crcw", "crbr", "crcr"):
        return crown(only)
    if only == "cw":
        return cw()
    if only == "parity":
        return parity()
    q = []
    if only in ("", "base"):
        q += base(0) + base(1)
    if only in ("", "plans"):
        q += plans()
    if only in ("", "multi"):
        q += multi()
    if only == "":
        # the 4-player games go in after the first base round so a cut run still has some
        b0 = len(base(0))
        q = q[:b0] + multi() + q[b0:len(q) - len(multi())]
    return q


ERR = re.compile(r"(SCRIPT ERROR|^ERROR|USER ERROR|Invalid|Nonexistent|Cannot call)")


def run_one(g, out, end, data):
    tag, m, seed, slots = g
    dd = os.path.join(data, tag)
    if os.path.exists(os.path.join(dd, "result.json")) or os.path.exists(os.path.join(dd, "FAILED.txt")):
        return tag + " (had)"
    d = os.path.join(out, tag)
    os.makedirs(d, exist_ok=True)
    spec = ",".join("%s/%s/%d" % s for s in slots)
    cmd = ["timeout", "3000", "godot", "--headless", "--fixed-fps", "30", "--path", RUN_ROOT, "--script",
           "res://tools/qa_match.gd", "--", "map:" + m, "seed:%d" % seed, "end:%d" % end, "out:" + d, "slots:" + spec] + EXTRA
    with open(os.path.join(d, "run.out"), "wb") as f:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        n = 0
        for chunk in iter(lambda: p.stdout.read(65536), b""):
            if n < 20_000_000:
                f.write(chunk)
            n += len(chunk)
        rc = p.wait()
    os.makedirs(dd, exist_ok=True)
    for fn in ("result.json", "story.txt"):
        if os.path.exists(os.path.join(d, fn)):
            shutil.copy(os.path.join(d, fn), dd)
    if KEEP_CW and os.path.exists(os.path.join(d, "log.txt")):
        # (clockwork-ai-v2: the Clockwork computer's own lines of the match log: its push, its army, its build)
        with open(os.path.join(d, "log.txt"), errors="replace") as f, open(os.path.join(dd, "cwlog.txt"), "w") as o:
            for l in f:
                if "Clockwork" in l:
                    o.write(l)
    errs = []
    with open(os.path.join(d, "run.out"), errors="replace") as f:
        lines = f.read().splitlines()
    for i, l in enumerate(lines):
        if ERR.search(l):
            errs.append(l.strip() + ("  " + lines[i + 1].strip() if i + 1 < len(lines) else ""))
    if errs:
        with open(os.path.join(dd, "errors.txt"), "w") as f:
            f.write("%d error lines\n" % len(errs))
            seen = {}
            for e in errs:
                seen[e] = seen.get(e, 0) + 1
            for e, c in sorted(seen.items(), key=lambda x: -x[1])[:60]:
                f.write("%5d  %s\n" % (c, e))
    if not os.path.exists(os.path.join(d, "result.json")):
        with open(os.path.join(dd, "FAILED.txt"), "w") as f:
            f.write("no result: exit code %d (timeout = 124); last lines:\n%s\n" % (rc, "\n".join(lines[-40:])))
        # keep the match log tail when a game fails
    else:
        shutil.rmtree(d, ignore_errors=True)
    return tag


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    arg = lambda k, dflt: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else dflt
    if sys.argv[1] == "list":
        for g in queue(arg("--only", "")):
            print(g[0], g[1], g[2], g[3])
        sys.exit(0)
    out = os.path.abspath(sys.argv[2])
    RUN_ROOT = os.path.abspath(arg("--root", ROOT))     # (another checkout to run: a "before" worktree)
    KEEP_CW = "--cwlog" in sys.argv
    if "--extra" in sys.argv:
        EXTRA = arg("--extra", "").split(",")      # (econ-coach-crown) study switches for every game, e.g. greedyclock:economy
    data = os.path.abspath(arg("--data", os.path.join(ROOT, "docs/qa_2026_11_08_matches/data")))
    jobs = int(arg("--jobs", "2"))
    end = int(arg("--end", "900"))
    gl = queue(arg("--only", ""))
    if "--reverse" in sys.argv:
        gl = gl[::-1]       # (a second runner on the same data, from the other end: the two meet in the middle)
    print("%d games" % len(gl), flush=True)
    with ThreadPoolExecutor(jobs) as ex:
        for t in ex.map(lambda g: run_one(g, out, end, data), gl):
            if os.path.exists(os.path.join(out, "STOP")):
                print("STOP seen", flush=True)
            print("done", t, flush=True)
