#!/usr/bin/env python3
"""NO FARM/PRESS LIMIT study (ground-nocap-study, docs/ground_nocap_study.md): Hard OPTIMAL v Hard OPTIMAL games to 15:00
with THE GROUND SYSTEM ON in both arms, the per-hall Farm / Cog Press limit KEPT (`ground:1`) against DROPPED
(`ground:1 groundcap:off`), the same tags and seeds as qa_matches.py's base rounds (so the sides swap between rounds).
    python3 tools/study/ground_nocap.py run OUT DATA [--jobs 2] [--maps a,b,c] [--pairs crcw,crbr,brcw,crcr,cwcw]
    python3 tools/study/ground_nocap.py report DATA
DATA/kept/<tag>/ and DATA/drop/<tag>/ hold result.json (tools/qa_match.gd); a game is done when its result.json exists,
run again to resume. The two arms of a game are queued next to each other, so a cut run stays balanced."""
import os, sys, json, subprocess, shutil, statistics as st
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qa_matches as Q

ROOT = Q.ROOT
MAPS = ["greenhold", "frostfang", "hollowfen", "dune_sea", "cinder_steps", "ashford_crossing"]
PAIRS = ["crcw", "crbr", "brcw", "crcr", "cwcw"]
ARMS = {"kept": ["ground:1"], "drop": ["ground:1", "groundcap:off"]}


def queue(maps, pairs):
    out = []
    for r in (0, 1):
        for m in maps:
            for g in Q.base(r):
                if g[1] == m and g[0].split("_")[-2] in pairs:
                    for arm in ("kept", "drop"):
                        out.append((arm, g))
    return out


def run_one(arm, g, out, data, end=900):
    tag, m, seed, slots = g
    dd = os.path.join(data, arm, tag)
    if os.path.exists(os.path.join(dd, "result.json")) or os.path.exists(os.path.join(dd, "FAILED.txt")):
        return arm + " " + tag + " (had)"
    d = os.path.join(out, arm, tag)
    os.makedirs(d, exist_ok=True)
    spec = ",".join("%s/%s/%d" % s for s in slots)
    cmd = ["timeout", "3600", "godot", "--headless", "--fixed-fps", "30", "--path", ROOT, "--script",
           "res://tools/qa_match.gd", "--", "map:" + m, "seed:%d" % seed, "end:%d" % end, "out:" + d, "slots:" + spec] + ARMS[arm]
    with open(os.path.join(d, "run.out"), "wb") as f:
        rc = subprocess.call(cmd, stdout=f, stderr=subprocess.STDOUT)
    os.makedirs(dd, exist_ok=True)
    errs = []
    with open(os.path.join(d, "run.out"), errors="replace") as f:
        lines = f.read().splitlines()
    for i, l in enumerate(lines):
        if Q.ERR.search(l):
            errs.append(l.strip())
    if errs:
        with open(os.path.join(dd, "errors.txt"), "w") as f:
            seen = {}
            for e in errs:
                seen[e] = seen.get(e, 0) + 1
            for e, c in sorted(seen.items(), key=lambda x: -x[1])[:40]:
                f.write("%5d  %s\n" % (c, e))
    if os.path.exists(os.path.join(d, "result.json")):
        shutil.copy(os.path.join(d, "result.json"), dd)
        if os.path.exists(os.path.join(d, "story.txt")):
            shutil.copy(os.path.join(d, "story.txt"), dd)
        shutil.rmtree(d, ignore_errors=True)
    else:
        with open(os.path.join(dd, "FAILED.txt"), "w") as f:
            f.write("exit %d\n%s\n" % (rc, "\n".join(lines[-40:])))
    return arm + " " + tag


# ------------------------------------------------------------------ the report

FAC = {"crown": "cr", "brood": "br", "clockwork": "cw"}


def load(d):
    out = {}
    if os.path.isdir(d):
        for tag in sorted(os.listdir(d)):
            f = os.path.join(d, tag, "result.json")
            if os.path.exists(f):
                out[tag] = json.load(open(f))
    return out


def row(d, p, t):
    r = [x for x in d["minutes"] if x["p"] == p and x["t"] == t]
    if r:
        return r[0]
    r = [x for x in d["minutes"] if x["p"] == p and x["t"] <= t]
    return r[-1] if r else None


def med(v):
    return st.median(v) if v else float("nan")


def mean(v):
    return st.mean(v) if v else float("nan")


def side_stats(d, p):
    """per side of one game"""
    fac = d["slots"][p][0] if isinstance(d["slots"][p], list) else d["slots"][p]["faction"]
    s = {"fac": fac}
    for m in (5, 8, 10, 12, 15):
        r = row(d, p, m * 60)
        s["inc%d" % m] = r["income"] if r else None
        s["army%d" % m] = r["army"] if r else None
    mins = [x for x in d["minutes"] if x["p"] == p]
    # halls: the most held, when the 2nd / 3rd came up
    s["halls_max"] = max([x["halls"] for x in mins] or [0])
    for k in (2, 3):
        t = [x["t"] for x in mins if x["halls"] >= k]
        s["hall%d" % k] = t[0] if t else None
    s["bld_lost"] = mins[-1]["bld_lost"] if mins else 0
    s["lost"] = mins[-1]["lost"] if mins else 0
    dr = [x.get("drink") for x in mins if x.get("drink")]
    # Farms / Presses: the most in one district, the live ones per hall at 8 and 12 min
    s["most"] = max([x[3] for x in dr] or [0])
    for m in (8, 12):
        r = row(d, p, m * 60)
        if r and r.get("drink") and r["halls"] > 0:
            s["per_hall%d" % m] = r["drink"][0] / r["halls"]
        else:
            s["per_hall%d" % m] = None
    hm = [x["home"] for x in mins if x.get("home", -1) >= 0 and x["t"] >= 300]
    s["home"] = mean(hm) if hm else None
    s["halls_lost"] = len([e for e in d.get("events", []) if e.get("p") == p and e.get("ev") == "hall_lost"])
    return s


def report(data):
    arms = {a: load(os.path.join(data, a)) for a in ("kept", "drop")}
    tags = sorted(set(arms["kept"]) & set(arms["drop"]))
    print("# NO FARM/PRESS LIMIT: Hard OPTIMAL v Hard OPTIMAL to 15:00, ground ON, limit kept v dropped\n")
    print("%d games in each arm (paired: same map, seed and sides)\n" % len(tags))
    # results by pairing, from the first-named faction's view
    print("## Results (W-D-L of the first-named; a mirror: side A = P1)\n")
    print("| pairing | games | kept W-D-L | dropped W-D-L | median length kept / dropped |")
    print("|---|---|---|---|---|")
    pairs = {}
    for tag in tags:
        pk = tag.split("_")[-2]
        pairs.setdefault(pk, []).append(tag)
    for pk in PAIRS:
        if pk not in pairs:
            continue
        line = []
        lens = []
        for a in ("kept", "drop"):
            w = dr = l = 0
            ln = []
            for tag in pairs[pk]:
                d = arms[a][tag]
                f0 = pk[:2]
                facs = [FAC[(s[0] if isinstance(s, list) else s["faction"])] for s in d["slots"]]
                me = facs.index(f0) if pk[:2] != pk[2:] else 0
                ln.append(d["end"])
                if not d["over"]:
                    dr += 1
                elif d["winner"] == me:
                    w += 1
                else:
                    l += 1
            line.append("%d-%d-%d" % (w, dr, l))
            lens.append("%d:%02d" % (int(med(ln)) // 60, int(med(ln)) % 60))
        print("| %s | %d | %s | %s | %s / %s |" % (pk, len(pairs[pk]), line[0], line[1], lens[0], lens[1]))
    # per faction, pooled over its sides
    print("\n## Per faction (every side it played, pooled; medians unless said)\n")
    keys = [("inc5", "income 5:00"), ("inc8", "income 8:00"), ("inc10", "income 10:00"), ("inc12", "income 12:00"),
            ("inc15", "income 15:00"), ("army8", "army value 8:00"), ("army12", "army value 12:00"),
            ("halls_max", "most halls held"), ("hall2", "2nd hall up (s)"), ("hall3", "3rd hall up (s)"),
            ("per_hall8", "Farms/Presses live a hall 8:00"), ("per_hall12", "Farms/Presses live a hall 12:00"),
            ("most", "most in one district"), ("home", "army at home from 5:00 (share, mean)"),
            ("halls_lost", "halls lost (mean)"), ("bld_lost", "buildings lost (mean)")]
    for fac in ("crown", "clockwork", "brood"):
        S = {a: [] for a in arms}
        for a in arms:
            for tag in tags:
                d = arms[a][tag]
                for p in range(len(d["slots"])):
                    s = side_stats(d, p)
                    if s["fac"] == fac:
                        S[a].append(s)
        if not S["kept"]:
            continue
        print("### %s (%d sides)\n" % (fac.capitalize(), len(S["kept"])))
        print("| | kept | dropped | dropped / kept |")
        print("|---|---|---|---|")
        for k, name in keys:
            vals = []
            for a in ("kept", "drop"):
                v = [s[k] for s in S[a] if s.get(k) is not None]
                if k in ("home", "halls_lost", "bld_lost"):
                    vals.append(mean(v))
                elif k in ("hall2", "hall3"):
                    vals.append((med(v), len(v)))
                else:
                    vals.append(med(v))
            if k in ("hall2", "hall3"):
                def f(x):
                    return ("%d:%02d (%d of %d)" % (int(x[0]) // 60, int(x[0]) % 60, x[1], len(S["kept"]))) if x[1] else "-"
                print("| %s | %s | %s | |" % (name, f(vals[0]), f(vals[1])))
            else:
                ratio = (vals[1] / vals[0]) if vals[0] and vals[0] == vals[0] and vals[1] == vals[1] else float("nan")
                print("| %s | %.2f | %.2f | %.2f |" % (name, vals[0], vals[1], ratio) if isinstance(vals[0], float) and vals[0] < 20
                      else "| %s | %.0f | %.0f | %.2f |" % (name, vals[0], vals[1], ratio))
        print()
    # economy parity: median income per faction at 8 / 12 (all sides)
    print("## Parity: median income at 8:00 / 12:00, each faction as a share of the Crown's\n")
    print("| | kept 8:00 | dropped 8:00 | kept 12:00 | dropped 12:00 |")
    print("|---|---|---|---|---|")
    P = {}
    for a in arms:
        for fac in ("crown", "clockwork", "brood"):
            for m in (8, 12):
                v = []
                for tag in tags:
                    d = arms[a][tag]
                    for p in range(len(d["slots"])):
                        s = side_stats(d, p)
                        if s["fac"] == fac and s["inc%d" % m] is not None:
                            v.append(s["inc%d" % m])
                P[(a, fac, m)] = med(v)
    for fac in ("crown", "clockwork", "brood"):
        print("| %s | %.2f | %.2f | %.2f | %.2f |" % (fac.capitalize(), P[("kept", fac, 8)] / P[("kept", "crown", 8)],
              P[("drop", fac, 8)] / P[("drop", "crown", 8)], P[("kept", fac, 12)] / P[("kept", "crown", 12)],
              P[("drop", fac, 12)] / P[("drop", "crown", 12)]))
    errs = sum(1 for a in arms for tag in tags if os.path.exists(os.path.join(data, a, tag, "errors.txt")))
    print("\nGames with an error line: %d" % errs)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    if sys.argv[1] == "report":
        report(sys.argv[2])
        return
    out, data = sys.argv[2], sys.argv[3]
    jobs = 2
    maps, pairs = MAPS, PAIRS
    a = sys.argv[4:]
    for i, x in enumerate(a):
        if x == "--jobs":
            jobs = int(a[i + 1])
        elif x == "--maps":
            maps = a[i + 1].split(",")
        elif x == "--pairs":
            pairs = a[i + 1].split(",")
    q = queue(maps, pairs)
    print("%d games queued" % len(q), flush=True)
    with ThreadPoolExecutor(jobs) as ex:
        for r in ex.map(lambda x: run_one(x[0], x[1], out, data), q):
            print(r, flush=True)


if __name__ == "__main__":
    main()
