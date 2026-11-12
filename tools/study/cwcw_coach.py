#!/usr/bin/env python3
"""(clockwork-v-clockwork-coach, docs/clockwork-v-clockwork-coach.md) The Clockwork mirror measured: Hard Clockwork OPTIMAL v
Hard Clockwork OPTIMAL to 15:00 with tools/qa_match.gd on 8 maps x N seeds. A measuring tool: it changes no rule.
    python3 tools/study/cwcw_coach.py run DATA [--jobs 2] [--seeds 3] [--root DIR] [--maps a,b] [--args x:y,...]
        [--slots clockwork/optimal/0,crown/optimal/1]   (another pairing: the check that the others did not get worse)
    python3 tools/study/cwcw_coach.py report DATA [DATA2 ...]
A game is done when DATA/<tag>/result.json exists; run again to resume. Kept per game: result.json, story.txt,
cwlog.txt (the Clockwork's own match log lines) and errors.txt."""
import os, sys, subprocess, json, re, shutil
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAPS = ["greenhold", "dune_sea", "hollowfen", "kestrel_rise", "cinder_steps", "red_coast", "frostfang", "twin_fords"]
ERR = re.compile(r"(SCRIPT ERROR|USER ERROR|Invalid call|Nonexistent|Cannot call)")


def games(seeds, maps):
    out = []
    for k in range(seeds):
        for m in maps:
            mi = MAPS.index(m) if m in MAPS else 50 + maps.index(m)     # (the seed by the map's place in MAPS: a --maps subset plays the same seeds)
            out.append(("cwcw_%s_s%d" % (m, k), m, 2101 + 100 * k + mi))
    return out


SLOTS = "clockwork/optimal/0,clockwork/optimal/1"


def run_one(g, data, root, extra):
    tag, m, seed = g
    dd = os.path.join(data, tag)
    if os.path.exists(os.path.join(dd, "result.json")):
        return tag + " (had)"
    work = os.path.join("/tmp/cwcw_runs", os.path.basename(os.path.abspath(data)), tag)
    os.makedirs(work, exist_ok=True)
    cmd = ["timeout", "2400", "godot", "--headless", "--fixed-fps", "30", "--path", root, "--script",
           "res://tools/qa_match.gd", "--", "map:" + m, "seed:%d" % seed, "end:900", "out:" + work,
           "slots:" + SLOTS] + extra
    with open(os.path.join(work, "run.out"), "wb") as f:
        subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
    os.makedirs(dd, exist_ok=True)
    for fn in ("result.json", "story.txt"):
        if os.path.exists(os.path.join(work, fn)):
            shutil.copy(os.path.join(work, fn), dd)
    if os.path.exists(os.path.join(work, "log.txt")):
        with open(os.path.join(work, "log.txt"), errors="replace") as f, open(os.path.join(dd, "cwlog.txt"), "w") as o:
            for l in f:
                if "Clockwork" in l and "slow frame" not in l:
                    o.write(l)
    errs = []
    with open(os.path.join(work, "run.out"), errors="replace") as f:
        lines = f.read().splitlines()
    for i, l in enumerate(lines):
        if ERR.search(l):
            errs.append(l.strip() + ("  " + lines[i + 1].strip() if i + 1 < len(lines) else ""))
    with open(os.path.join(dd, "errors.txt"), "w") as o:
        o.write("\n".join(errs[:200]))
    return tag


def side_at(r, p, t):
    best = None
    for m in r["minutes"]:
        if m["p"] == p and m["t"] <= t:
            best = m
    return best


def report(dirs):
    for d in dirs:
        rows = []
        for tag in sorted(os.listdir(d)):
            f = os.path.join(d, tag, "result.json")
            if not os.path.exists(f):
                continue
            r = json.load(open(f))
            end = r["end"]
            win = r["winner_side"] if "winner_side" in r else r["winner"]
            halls = [0, 0]
            for e in r["events"]:
                if e["ev"] == "hall_lost":
                    halls[e["p"]] += 1
            fin = [side_at(r, p, end) for p in (0, 1)]
            # the leader at the end: earned + 2 x army
            sc = [(x["income"] + 2 * x["army"]) if x else 0 for x in fin]
            lead = -1
            if sc[0] > sc[1] * 1.1:
                lead = 0
            elif sc[1] > sc[0] * 1.1:
                lead = 1
            dead = any(x and x["army"] == 0 and x["workers"] <= 3 for x in fin)
            a8 = [side_at(r, p, 480) for p in (0, 1)]
            a10 = [side_at(r, p, 600) for p in (0, 1)]
            att = {}
            for e in r["events"]:
                if e["ev"] == "first_attack" and e["p"] not in att:
                    att[e["p"]] = e["t"]
            # the first minute one side's army is twice the other's (and 1,500 at least): "clearly ahead"
            ahead = None
            for t in range(60, int(end) + 1, 60):
                a = [side_at(r, p, t) for p in (0, 1)]
                if not all(a):
                    continue
                for p in (0, 1):
                    if a[p]["army"] >= 1500 and a[p]["army"] >= 2 * a[1 - p]["army"]:
                        ahead = (t, p)
                        break
                if ahead:
                    break
            errn = 0
            ef = os.path.join(d, tag, "errors.txt")
            if os.path.exists(ef):
                errn = len([l for l in open(ef) if l.strip()])
            rows.append(dict(tag=tag, end=end, win=win, lead=lead, dead=dead, halls=halls,
                             inc8=[x["income"] for x in a8 if x], army8=[x["army"] for x in a8 if x],
                             inc10=[x["income"] for x in a10 if x], army10=[x["army"] for x in a10 if x],
                             att=[att.get(0), att.get(1)], errn=errn, ahead=ahead))
        n = len(rows)
        if n == 0:
            continue
        dec = [x for x in rows if x["win"] is not None and x["win"] >= 0]
        p1w = len([x for x in dec if x["win"] == 0])
        print("== %s: %d games" % (d, n))
        print("  decided %d (P1 %d, P2 %d), mean length of the decided %s" % (len(dec), p1w, len(dec) - p1w,
              ("%d:%02d" % divmod(int(sum(x["end"] for x in dec) / len(dec)), 60)) if dec else "-"))
        und = [x for x in rows if x not in dec]
        print("  draws %d: led by P1 %d, P2 %d, even %d; a side beaten in all but name (no army, 3 workers or fewer) %d" % (
            len(und), len([x for x in und if x["lead"] == 0]), len([x for x in und if x["lead"] == 1]),
            len([x for x in und if x["lead"] == -1]), len([x for x in und if x["dead"]])))
        hl = sum(sum(x["halls"]) for x in rows)
        print("  halls lost %d (P1 %d, P2 %d)" % (hl, sum(x["halls"][0] for x in rows), sum(x["halls"][1] for x in rows)))
        def mean(k, i=None):
            v = [y for x in rows for y in x[k]]
            return int(sum(v) / len(v)) if v else 0
        print("  per side: earned 8:00 %d, 10:00 %d; army 8:00 %d, 10:00 %d" % (mean("inc8"), mean("inc10"), mean("army8"), mean("army10")))
        at = sorted([y for x in rows for y in x["att"] if y is not None])
        print("  first attack: median %s (%d sides of %d)" % (("%d:%02d" % divmod(at[len(at) // 2], 60)) if at else "-", len(at), 2 * n))
        print("  games with script errors: %d" % len([x for x in rows if x["errn"]]))
        ah = [x for x in rows if x["ahead"]]
        fin = [x for x in ah if x in dec and x["win"] == x["ahead"][1]]
        print("  a side clearly ahead (army 2x, 1,500+) in %d games, at %s on average; it won %d of them, %s after (mean)" % (
            len(ah), ("%d:%02d" % divmod(int(sum(x["ahead"][0] for x in ah) / len(ah)), 60)) if ah else "-", len(fin),
            ("%d:%02d" % divmod(int(sum(x["end"] - x["ahead"][0] for x in fin) / len(fin)), 60)) if fin else "-"))
        for x in rows:
            print("    %-28s %s %5s lead %2d halls %s army8 %s army10 %s att %s ahead %s%s" % (x["tag"], "win P%d" % (x["win"] + 1) if x in dec else "draw  ",
                  "%d:%02d" % divmod(int(x["end"]), 60), x["lead"], x["halls"], x["army8"], x["army10"], x["att"],
                  ("P%d %d:%02d" % ((x["ahead"][1] + 1,) + divmod(x["ahead"][0], 60))) if x["ahead"] else "-", " DEAD" if x["dead"] and x not in dec else ""))


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return
    if a[0] == "report":
        report(a[1:])
        return
    data = a[1]
    jobs, seeds, root, maps, extra = 2, 2, ROOT, MAPS, []
    i = 2
    while i < len(a):
        if a[i] == "--jobs":
            jobs = int(a[i + 1]); i += 2
        elif a[i] == "--seeds":
            seeds = int(a[i + 1]); i += 2
        elif a[i] == "--root":
            root = a[i + 1]; i += 2
        elif a[i] == "--maps":
            maps = a[i + 1].split(","); i += 2
        elif a[i] == "--slots":
            global SLOTS
            SLOTS = a[i + 1]; i += 2
        elif a[i] == "--args":
            extra = a[i + 1].split(","); i += 2
        else:
            i += 1
    q = games(seeds, maps)
    os.makedirs(data, exist_ok=True)
    with ThreadPoolExecutor(jobs) as ex:
        for t in ex.map(lambda g: run_one(g, data, root, extra), q):
            print("done", t, flush=True)


if __name__ == "__main__":
    main()
