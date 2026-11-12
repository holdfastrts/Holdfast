#!/usr/bin/env python3
"""CROWN LINE FIGHT (crown-line-fight, docs/crown_line_fight.md): Hard Crown OPTIMAL against Hard Brood, Clockwork and
Crown OPTIMAL, measured with tools/film_line.gd (tools/qa_match.gd's result.json plus every engagement of a Crown army in
engage.json). The qa-matches base tags and seeds (both start slots: round 0 and round 1 swap the sides), 8 maps of
different shapes, so 16 games a matchup. A measuring tool: it changes no rule.
    python3 tools/study/crown_line_fight.py run OUT --data DATA [--only crbr|crcw|crcr|all] [--jobs 2] [--root DIR]
        [--args a,b] [--reverse] [--end 900]
    python3 tools/study/crown_line_fight.py list [--only ...]
A game is done when DATA/<tag>/result.json exists; run again to resume. Kept per game: result.json, story.txt,
engage.json, coach.txt and the Crown's lines of the match log (crownlog.txt)."""
import os, sys, subprocess, shutil
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qa_matches as Q

MAPS = ["greenhold", "dune_sea", "hollowfen", "kestrel_rise", "ashford_crossing", "red_coast", "frostmere", "border_march"]
PAIRS = {"crbr": "_crbr_r", "crcw": "_crcw_r", "crcr": "_crcr_r"}


def queue(only):
    keys = list(PAIRS) if only in ("", "all") else only.split("+")
    out = []
    # interleaved (a cut run still has some of each matchup)
    for r in (0, 1):
        for m in MAPS:
            for k in keys:
                out += [g for g in Q.base(r) if g[1] == m and g[0].endswith(PAIRS[k] + str(r))]
    return out


def run_one(g, out, end, data, root, extra):
    tag, m, seed, slots = g
    dd = os.path.join(data, tag)
    if os.path.exists(os.path.join(dd, "result.json")) or os.path.exists(os.path.join(dd, "FAILED.txt")):
        return tag + " (had)"
    d = os.path.join(out, tag)
    os.makedirs(d, exist_ok=True)
    spec = ",".join("%s/%s/%d" % s for s in slots)
    cmd = ["timeout", "3600", "godot", "--headless", "--fixed-fps", "30", "--path", root, "--script",
           "res://tools/film_line.gd", "--", "map:" + m, "seed:%d" % seed, "end:%d" % end, "out:" + d, "slots:" + spec] + extra
    with open(os.path.join(d, "run.out"), "wb") as f:
        rc = subprocess.call(cmd, stdout=f, stderr=subprocess.STDOUT)
    os.makedirs(dd, exist_ok=True)
    for fn in ("result.json", "story.txt", "engage.json", "coach.txt"):
        if os.path.exists(os.path.join(d, fn)):
            shutil.copy(os.path.join(d, fn), dd)
    if os.path.exists(os.path.join(d, "log.txt")):
        with open(os.path.join(d, "log.txt"), errors="replace") as f, open(os.path.join(dd, "crownlog.txt"), "w") as o:
            for l in f:
                if "Crown" in l and "busy with" not in l:
                    o.write(l)
    errs = []
    with open(os.path.join(d, "run.out"), errors="replace") as f:
        lines = f.read().splitlines()
    for i, l in enumerate(lines):
        if Q.ERR.search(l):
            errs.append(l.strip() + ("  " + lines[i + 1].strip() if i + 1 < len(lines) else ""))
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


if __name__ == "__main__":
    arg = lambda k, dflt: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else dflt
    gl = queue(arg("--only", "all"))
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        for g in gl:
            print(g[0], g[1], g[2], g[3])
        sys.exit(0)
    out = os.path.abspath(sys.argv[2])
    root = os.path.abspath(arg("--root", Q.ROOT))
    extra = [a for a in arg("--args", "").split(",") if a]
    data = os.path.abspath(arg("--data", os.path.join(out, "data")))
    jobs = int(arg("--jobs", "2"))
    end = int(arg("--end", "900"))
    if "--reverse" in sys.argv:
        gl = gl[::-1]
    print("%d games" % len(gl), flush=True)
    with ThreadPoolExecutor(jobs) as ex:
        for t in ex.map(lambda g: run_one(g, out, end, data, root, extra), gl):
            print("done", t, flush=True)
