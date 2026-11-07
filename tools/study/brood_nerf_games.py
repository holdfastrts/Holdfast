#!/usr/bin/env python3
"""THE BROOD NERF STUDY (brood-nerf-study, docs/brood_nerf_study.md): Hard computers, OPTIMAL on both sides (a few with
the Brood on Economy), Crown v Brood and Clockwork v Brood at FOOD_BONUS 1.5 (before 0.33.6) and 1.2 (now), and Crown v
Clockwork as the control (the bonus does not touch it), on the five 2-player maps, up to 15:00, with
tools/play_ai_optimal.gd (`fb:` overrides Game.food_bonus for the run; `every:60` writes a line a minute).
    python3 tools/study/brood_nerf_games.py run OUT [--rounds 3] [--jobs 2] [--end 900]
    python3 tools/study/brood_nerf_games.py table OUT        (the raw rows; the report: brood_nerf_report.py)
The queue goes round by round (seed round 0 of every matchup and map first) so a cut run still has paired games.
Sides swap by round and map: the Brood (or the Clockwork in the control) is P2 on even (round + map index), P1 on odd."""
import os, sys, subprocess, shutil
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAPS = ["dune_sea", "greenhold", "red_coast", "hollowfen", "kestrel_rise"]
# (name, other faction, brood or second faction, plan of the second, bonus values)
MATCHUPS = [
    ("cvb", "crown", "brood", "optimal", ["1.2", "1.5"]),
    ("kvb", "clockwork", "brood", "optimal", ["1.2", "1.5"]),
    ("cvk", "crown", "clockwork", "optimal", ["1.2"]),
]
EXTRA = [("cvbe", "crown", "brood", "economy", ["1.2", "1.5"])]     # the Brood on Economy: one round only


def games(rounds):
    out = []
    for r in range(rounds):
        for mu in MATCHUPS + (EXTRA if r == 0 else []):
            name, fa, fb, plan, bonuses = mu
            for mi, m in enumerate(MAPS):
                seed = 301 + 17 * r + mi
                swap = (r + mi) % 2 == 1
                for b in bonuses:
                    out.append((name, fa, fb, plan, m, seed, b, swap))
    return out


def run_one(g, out, end, data):
    name, fa, fb, plan, m, seed, b, swap = g
    tag = "%s_%s_s%d_fb%s" % (name, m, seed, b)
    d = os.path.join(out, tag)
    if os.path.exists(os.path.join(d, "result.txt")):
        return tag
    os.makedirs(d, exist_ok=True)
    s1 = (fb, plan) if swap else (fa, "optimal")
    s2 = (fa, "optimal") if swap else (fb, plan)
    cmd = ["timeout", "2400", "godot", "--headless", "--fixed-fps", "30", "--path", ROOT, "--script",
           "res://tools/play_ai_optimal.gd", "--", "a:" + s1[0], "sa:" + s1[1], "b:" + s2[0], "sb:" + s2[1], "map:" + m,
           "seed:%d" % seed, "end:%d" % end, "out:" + d, "every:60", "fb:" + b]
    with open(os.path.join(d, "run.out"), "w") as f:
        subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
    if data:
        dd = os.path.join(data, tag)
        os.makedirs(dd, exist_ok=True)
        for fn in ("result.txt", "story.txt"):
            if os.path.exists(os.path.join(d, fn)):
                shutil.copy(os.path.join(d, fn), dd)
        if not os.path.exists(os.path.join(d, "result.txt")):
            open(os.path.join(dd, "STALLED.txt"), "w").write("no result (timeout or crash)\n")
    return tag


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    out = os.path.abspath(sys.argv[2])
    arg = lambda k, dflt: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else dflt
    if sys.argv[1] == "run":
        rounds = int(arg("--rounds", "3"))
        jobs = int(arg("--jobs", "2"))
        end = int(arg("--end", "900"))
        data = arg("--data", "")
        gl = games(rounds)
        print("%d games" % len(gl), flush=True)
        with ThreadPoolExecutor(jobs) as ex:
            for t in ex.map(lambda g: run_one(g, out, end, data), gl):
                print("done", t, flush=True)
