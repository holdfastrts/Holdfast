#!/usr/bin/env python3
"""THE OPTIMAL PLAN COACHED (ai-optimal, docs/ai_optimal.md): run each faction's OPTIMAL against each faction's
Economy, Rush, Timing and Balanced (mirrors too) on Highmoor, Redrock Canyon, Thornwood Maze and Greenhold, headless,
with tools/play_ai_optimal.gd, two at a time; then `table` sums them up.
    python3 tools/study/ai_optimal_games.py run OUT [--pass N] [--end 720] [--jobs 2]
    python3 tools/study/ai_optimal_games.py table OUT
A pass plays the 36 pairings once, each on one map (the maps rotate; pass 2 shifts them)."""
import os, re, subprocess, sys, itertools
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FACS = ["crown", "clockwork", "brood"]
PLANS = ["economy", "rush", "timing", "balanced"]
MAPS = ["highmoor", "redrock_canyon", "thornwood_maze", "greenhold"]


def games(p):
    out = []
    i = 0
    for a, b, sb in itertools.product(FACS, FACS, PLANS):
        m = MAPS[(i + p) % len(MAPS)]
        out.append((a, b, sb, m, 11 + i + 100 * p))
        i += 1
    return out


SA = "optimal"


def run_one(g, out, end):
    a, b, sb, m, seed = g
    d = os.path.join(out, "%s_%s_v_%s_%s_%s" % (a, "opt" if SA == "optimal" else SA, b, sb, m))
    if os.path.exists(os.path.join(d, "result.txt")):
        return d
    os.makedirs(d, exist_ok=True)
    cmd = ["timeout", "1500", "godot", "--headless", "--fixed-fps", "30", "--path", ROOT, "--script", "res://tools/play_ai_optimal.gd", "--",
           "a:" + a, "sa:" + SA, "b:" + b, "sb:" + sb, "map:" + m, "seed:%d" % seed, "end:%d" % end, "out:" + d]
    with open(os.path.join(d, "run.out"), "w") as f:
        subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
    return d


def table(out):
    rows = []
    for d in sorted(os.listdir(out)):
        rp = os.path.join(out, d, "result.txt")
        if not os.path.exists(rp):
            continue
        txt = open(rp).read()
        head = txt.split("\n")[0]
        m = re.match(r"map (\S+) seed \d+: P1 (\S+) (\S+) v P2 (\S+) (\S+)", head)
        if not m:
            continue
        mp, a, sa, b, sb = m.groups()
        endl = re.search(r"end (\S+) winner (\S+)", txt)
        last = {}
        for l in txt.split("\n"):
            mm = re.match(r"(\d+:\d+) P(\d) \S+ \S+ \((\S+)\): income (\d+) \| workers (\d+) \| army (\d+) \| halls (\d+)", l)
            if mm:
                last[int(mm.group(2))] = mm.groups()
        picks = [l.split(" ", 2)[2] for l in txt.split("\n") if l.startswith("P1 pick")]
        reads = [l.split(" ", 2)[2] for l in txt.split("\n") if l.startswith("P1 read")]
        w = endl.group(2) if endl else "?"
        if w == "none" and 1 in last and 2 in last:
            # no winner by the end: the side with more income earned and more army is ahead
            s1 = int(last[1][3]) + 2 * int(last[1][5])
            s2 = int(last[2][3]) + 2 * int(last[2][5])
            w = "P1~" if s1 > s2 * 1.1 else ("P2~" if s2 > s1 * 1.1 else "even")
        rows.append((a, b, sb, mp, w, endl.group(1) if endl else "?", last.get(1), last.get(2), picks, reads))
    lines = ["| OPTIMAL | v | plan | map | result | end | income P1/P2 | army P1/P2 | its picks (clock, read -> build) |", "|---|---|---|---|---|---|---|---|---|"]
    won = {}
    for r in rows:
        a, b, sb, mp, w, end, l1, l2, picks, reads = r
        key = a
        won.setdefault(key, [0, 0, 0])
        won[key][0 if w.startswith("P1") else (1 if w.startswith("P2") else 2)] += 1
        pk = "; ".join(re.sub(r"^(\S+) \S+ ", r"\1 ", p).replace(" -> ", "->") for p in picks)
        lines.append("| %s | %s | %s | %s | %s | %s | %s/%s | %s/%s | %s |" % (a, b, sb, mp, w, end, l1[3] if l1 else "?", l2[3] if l2 else "?",
                     l1[5] if l1 else "?", l2[5] if l2 else "?", pk))
    lines.append("")
    for k, v in won.items():
        lines.append("%s OPTIMAL: %d won or ahead, %d lost or behind, %d even" % (k, v[0], v[1], v[2]))
    return "\n".join(lines)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    out = os.path.abspath(sys.argv[2])
    if sys.argv[1] == "run":
        p = int(sys.argv[sys.argv.index("--pass") + 1]) if "--pass" in sys.argv else 0
        end = int(sys.argv[sys.argv.index("--end") + 1]) if "--end" in sys.argv else 720
        jobs = int(sys.argv[sys.argv.index("--jobs") + 1]) if "--jobs" in sys.argv else 2
        only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
        if "--plan" in sys.argv:
            SA = sys.argv[sys.argv.index("--plan") + 1]
        gl = [g for g in games(p) if not only or g[0] == only]
        with ThreadPoolExecutor(jobs) as ex:
            for d in ex.map(lambda g: run_one(g, out, end), gl):
                print("done", d, flush=True)
    else:
        print(table(out))
