#!/usr/bin/env python3
"""clockwork-v-brood-coach (docs/clockwork-v-brood-coach.md): the measuring batch of Hard Clockwork OPTIMAL v Hard Brood
OPTIMAL, to 15:00, with tools/qa_match.gd (headless; changes no rule).
    python3 tools/study/cvb_coach.py run OUT --data DATA [--jobs 2] [--root DIR] [--set main|other]
    python3 tools/study/cvb_coach.py report DATA [DATA ...]
--set main: 8 maps of different shapes x both start slots = 16 games (fixed seeds).
--set other: a small check of each faction's OTHER matchups (Clockwork v Crown, Brood v Crown, both mirrors), 2 maps each.
The report: the Clockwork's W-D-L, won or led (a draw is led by the side whose income earned + 2 x army value at the end is
10% ahead, as docs/brood_nerf_study.md), mean length of the decided games, each side's army and income at 8:00 and 10:00
(medians), halls lost by each side (the Brood: grounds lost), its first attack."""
import json, os, sys, statistics
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import qa_matches as qm

MAPS = ["greenhold", "dune_sea", "hollowfen", "kestrel_rise", "redrock_canyon", "twin_fords", "frostfang", "cinder_steps"]


def main_set():
    out = []
    for mi, m in enumerate(MAPS):
        for sw in (0, 1):
            seed = 3300 + 7 * mi
            s = [("clockwork", "optimal", 0), ("brood", "optimal", 1)]
            if sw:
                s = [("brood", "optimal", 0), ("clockwork", "optimal", 1)]
            out.append(("cvb_%s_w%d" % (m, sw), m, seed, s))
    return out


def other_set():
    out = []
    pairs = [("clockwork", "crown"), ("brood", "crown"), ("clockwork", "clockwork"), ("brood", "brood")]
    for pi, (a, b) in enumerate(pairs):
        for k, m in enumerate(["greenhold", "dune_sea"]):
            s = [(a, "optimal", 0), (b, "optimal", 1)] if k == 0 else [(b, "optimal", 0), (a, "optimal", 1)]
            out.append(("oth_%s_%s_%s" % (a[:2], b[:2], m), m, 4400 + 11 * pi + k, s))
    return out


def at(g, p, t, key):
    best = None
    for x in g["minutes"]:
        if x["p"] == p and x["t"] <= t + 5:
            best = x
    return best[key] if best and best["t"] >= t - 5 else None


def med(xs):
    xs = [x for x in xs if x is not None]
    return int(statistics.median(xs)) if xs else "-"


def report(d):
    games = []
    for tag in sorted(os.listdir(d)):
        p = os.path.join(d, tag, "result.json")
        if os.path.exists(p):
            g = json.load(open(p))
            g["tag"] = tag
            games.append(g)
    cv = [g for g in games if g["tag"].startswith("cvb_")]
    print("## %s: %d games" % (d, len(cv)))
    w = dr = l = led = 0
    lens = []
    cw_i8, br_i8, cw_a8, br_a8, cw_i10, br_i10, cw_a10, br_a10 = [], [], [], [], [], [], [], []
    hl_cw = hl_br = 0
    rows = []
    for g in cv:
        facs = [s[0] for s in g["slots"]]
        c = facs.index("clockwork")
        b = 1 - c
        sc = [f["income"] + 2 * f["army"] for f in g["final"]]
        if g["winner"] >= 0:
            lead = g["winner"]
            if lead == c:
                w += 1
            else:
                l += 1
            lens.append(g["end"])
        else:
            dr += 1
            lead = c if sc[c] > 1.1 * sc[b] else (b if sc[b] > 1.1 * sc[c] else -1)
        if lead == c:
            led += 1
        for (lst, p, t, k) in ((cw_i8, c, 480, "income"), (br_i8, b, 480, "income"), (cw_a8, c, 480, "army"), (br_a8, b, 480, "army"),
                               (cw_i10, c, 600, "income"), (br_i10, b, 600, "income"), (cw_a10, c, 600, "army"), (br_a10, b, 600, "army")):
            lst.append(at(g, p, t, k))
        hlc = sum(1 for e in g["events"] if e.get("ev") in ("hall_lost", "brood_ground_lost") and e["p"] == c)
        hlb = sum(1 for e in g["events"] if e.get("ev") in ("hall_lost", "brood_ground_lost") and e["p"] == b)
        hl_cw += hlc
        hl_br += hlb
        res = ("CW won" if g["winner"] == c else "BR won") if g["winner"] >= 0 else ("draw, %s led" % ("CW" if lead == c else "BR" if lead == b else "nobody"))
        picks = ["P%d %s" % (x["p"] + 1, x["pick"]) for x in g.get("reads", []) if "pick" in x]
        rows.append("| %s | %s | %d:%02d | %s / %s | %s / %s | %d / %d | %s |" % (g["tag"], res, g["end"] // 60, g["end"] % 60,
                    at(g, c, 480, "army"), at(g, b, 480, "army"), at(g, c, 480, "income"), at(g, b, 480, "income"), hlc, hlb,
                    "; ".join(p.split(" (")[0] for p in picks)[:120]))
    print("| game | result | end | army 8:00 CW / BR | income 8:00 CW / BR | halls lost CW / BR | picks |")
    print("|---|---|---|---|---|---|---|")
    for r in rows:
        print(r)
    print()
    print("Clockwork W-D-L %d-%d-%d, won or led %d of %d; decided %d (mean %s); halls lost CW %d, BR %d" % (
        w, dr, l, led, len(cv), len(lens), ("%d:%02d" % (statistics.mean(lens) // 60, statistics.mean(lens) % 60)) if lens else "-", hl_cw, hl_br))
    print("medians: income 8:00 CW %s BR %s; 10:00 CW %s BR %s; army 8:00 CW %s BR %s; 10:00 CW %s BR %s" % (
        med(cw_i8), med(br_i8), med(cw_i10), med(br_i10), med(cw_a8), med(br_a8), med(cw_a10), med(br_a10)))
    oth = [g for g in games if g["tag"].startswith("oth_")]
    if oth:
        print()
        print("other matchups:")
        for g in oth:
            facs = [s[0] for s in g["slots"]]
            sc = [f["income"] + 2 * f["army"] for f in g["final"]]
            res = ("P%d %s won" % (g["winner"] + 1, facs[g["winner"]])) if g["winner"] >= 0 else \
                ("draw, P1 led" if sc[0] > 1.1 * sc[1] else "draw, P2 led" if sc[1] > 1.1 * sc[0] else "draw, even")
            print("  %s (P1 %s, P2 %s): %s at %d:%02d, income P1/P2 %d/%d" % (g["tag"], facs[0], facs[1], res, g["end"] // 60, g["end"] % 60,
                                                                              g["final"][0]["income"], g["final"][1]["income"]))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    arg = lambda k, dflt: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else dflt
    if sys.argv[1] == "report":
        for d in sys.argv[2:]:
            report(d)
        sys.exit(0)
    out = os.path.abspath(sys.argv[2])
    qm.RUN_ROOT = os.path.abspath(arg("--root", qm.ROOT))
    data = os.path.abspath(arg("--data", ""))
    gl = main_set() if arg("--set", "main") == "main" else other_set()
    with ThreadPoolExecutor(int(arg("--jobs", "2"))) as ex:
        for t in ex.map(lambda g: qm.run_one(g, out, 900, data), gl):
            print("done", t, flush=True)
