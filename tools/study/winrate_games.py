#!/usr/bin/env python3
"""WIN-RATE STUDY (winrate-a/b/c, 2026-11-12): one line per game from tools/qa_match.gd's result.json files, and the
comparison with the 0.33.7 qa-matches study (docs/qa_2026_11_08_matches.md). A measuring tool only.
    python3 tools/study/winrate_games.py games DATA [OLD_DATA] > games.csv
    python3 tools/study/winrate_games.py compare DATA OLD_DATA PAIR[,PAIR]   (markdown: per pairing and per map, now v 0.33.7)
PAIR is the tag's pairing code (crbr, crcw, brcw, crcr, brbr, cwcw). The subject is the first-named faction of the code.
A draw's LEADER: income earned + 2 x army value 10% ahead (the rule of docs/brood_nerf_study.md and the qa-matches study).
Per game: winner, end, leader, income and army at 5:00/8:00/10:00/15:00, halls lost (built), start slot of the subject."""
import os, sys, json, glob, math

CODE = {"cr": "crown", "br": "brood", "cw": "clockwork"}


def mmss(s):
    return "%d:%02d" % (int(s) // 60, int(s) % 60)


def load(data, pairs=None):
    out = []
    for d in sorted(glob.glob(os.path.join(data, "base_*"))):
        f = os.path.join(d, "result.json")
        if not os.path.exists(f):
            continue
        tag = os.path.basename(d)
        pair = tag.split("_")[-2]
        if pairs and pair not in pairs:
            continue
        g = json.load(open(f))
        subj = CODE[pair[:2]]
        facs = [s[0] for s in g["slots"]]
        si = facs.index(subj)          # the subject's player index (in a mirror: player 0 = P1)
        oi = 1 - si
        at = {}
        for r in g["minutes"]:
            at[(r["p"], int(round(r["t"] / 60)))] = r
        sc = [f["income"] + 2 * f["army"] for f in g["final"]]
        if g["winner"] >= 0:
            res = "W" if g["winner"] == si else "L"
            lead = res
        else:
            res = "D"
            lead = "w" if sc[si] > 1.1 * sc[oi] else ("l" if sc[oi] > 1.1 * sc[si] else "=")
        halls = [0, 0]
        for e in g["events"]:
            if e.get("ev") == "hall_lost" and e.get("built"):
                halls[e["p"]] += 1
        row = {"tag": tag, "map": g["map"], "seed": g["seed"], "pair": pair, "version": g.get("version", ""),
               "subj_slot": "P%d" % (g["slots"][si][2] + 1), "res": res, "lead": lead,
               "end": g["end"], "plan_s": g["final"][si].get("plan", ""), "plan_o": g["final"][oi].get("plan", ""),
               "halls_lost_s": halls[si], "halls_lost_o": halls[oi]}
        for m in (5, 8, 10, 15):
            for k, p in (("s", si), ("o", oi)):
                r = at.get((p, m))       # only games still running at that minute (as the qa-matches report)
                row["inc%d_%s" % (m, k)] = r["income"] if r else ""
                row["army%d_%s" % (m, k)] = r["army"] if r else ""
        out.append(row)
    return out


COLS = ["tag", "map", "seed", "pair", "version", "subj_slot", "res", "lead", "end", "plan_s", "plan_o",
        "halls_lost_s", "halls_lost_o"] + ["%s%d_%s" % (a, m, k) for m in (5, 8, 10, 15) for a in ("inc", "army") for k in ("s", "o")]


def ratio(rows, key):
    """mean of the subject's over mean of the opponent's, over the games still running (as the qa-matches report)"""
    v = [(r["%s_s" % key], r["%s_o" % key]) for r in rows if r["%s_s" % key] != "" and r["%s_o" % key] != ""]
    if not v or sum(b for a, b in v) == 0:
        return (float("nan"), 0)
    return (sum(a for a, b in v) / sum(b for a, b in v), len(v))


def binom_p(k, n):
    """two-sided exact binomial test against 1/2"""
    if n == 0:
        return 1.0
    pk = [math.comb(n, i) / 2 ** n for i in range(n + 1)]
    return min(1.0, sum(p for p in pk if p <= pk[k] + 1e-12))


def summary(rows):
    w = sum(r["res"] == "W" for r in rows)
    d = sum(r["res"] == "D" for r in rows)
    l = sum(r["res"] == "L" for r in rows)
    wl = sum(r["lead"] == "W" or r["lead"] == "w" for r in rows)
    ll = sum(r["lead"] == "L" or r["lead"] == "l" for r in rows)
    dec = [r["end"] for r in rows if r["res"] != "D"]
    return w, d, l, wl, ll, (sum(dec) / len(dec) if dec else 0), len(dec)


def compare(data, old, pairs):
    for pair in pairs:
        now = load(data, [pair])
        was = load(old, [pair])
        a, b = CODE[pair[:2]].capitalize(), CODE[pair[2:]].capitalize()
        print("### %s v %s (%s's view)\n" % (a, b, a))
        print("| | games | W-D-L | won or led | lost or trailed | decided: mean length | income 5:00 | 8:00 | 10:00 | 15:00 | army 5:00 | 8:00 | 10:00 | 15:00 | halls lost (%s / %s) |" % (a, b))
        print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
        for name, rows in (("0.33.7 (qa-matches)", was), ("now", now)):
            if not rows:
                continue
            w, d, l, wl, ll, ln, nd = summary(rows)
            cells = ["%.2f (%d)" % ratio(rows, "inc%d" % m) for m in (5, 8, 10, 15)]
            cells += ["%.2f (%d)" % ratio(rows, "army%d" % m) for m in (5, 8, 10, 15)]
            hl = "%d / %d" % (sum(r["halls_lost_s"] for r in rows), sum(r["halls_lost_o"] for r in rows))
            print("| %s | %d | %d-%d-%d | %d | %d | %s (%d) | %s | %s |" % (name, len(rows), w, d, l, wl, ll,
                  mmss(ln) if nd else "-", nd, " | ".join(cells), hl))
        print()
        if now:
            p1 = [r for r in now if r["subj_slot"] == "P1"]
            p2 = [r for r in now if r["subj_slot"] == "P2"]
            for nm, rr in (("%s at P1" % a, p1), ("%s at P2" % a, p2)):
                w, d, l, wl, ll, ln, nd = summary(rr)
                print("- %s: %d games, W-D-L %d-%d-%d, won or led %d, lost or trailed %d" % (nm, len(rr), w, d, l, wl, ll))
            # P1 spot v P2 spot over decided games
            p1w = sum(1 for r in now if (r["res"] == "W" and r["subj_slot"] == "P1") or (r["res"] == "L" and r["subj_slot"] == "P2"))
            p2w = sum(1 for r in now if (r["res"] == "W" and r["subj_slot"] == "P2") or (r["res"] == "L" and r["subj_slot"] == "P1"))
            print("- the P1 start spot won %d, the P2 spot %d (two-sided binomial p = %.2f)" % (p1w, p2w, binom_p(min(p1w, p2w), p1w + p2w)))
            if was:
                w0 = sum(r["res"] == "W" for r in was); w1 = sum(r["res"] == "W" for r in now)
                l0 = sum(r["res"] == "L" for r in was); l1 = sum(r["res"] == "L" for r in now)
                print("- decided games: %s won %d of %d (0.33.7: %d of %d)" % (a, w1, w1 + l1, w0, w0 + l0))
            print()
            print("Per map (round 0, round 1; W/D/L for %s, lower case = a draw it led (w) or trailed (l), = even; then 0.33.7's):\n" % a)
            print("| map | now r0 | now r1 | %s slot r0 / r1 | ends (r0 / r1) | %s income 8:00 ratio (r0 / r1) | 0.33.7 r0 r1 |" % (a, a))
            print("|---|---|---|---|---|---|---|")
            maps = sorted(set(r["map"] for r in now))
            for m in maps:
                rr = {r["tag"].split("_")[-1]: r for r in now if r["map"] == m}
                oo = {r["tag"].split("_")[-1]: r for r in was if r["map"] == m}
                def cell(r):
                    if r is None:
                        return "."
                    return r["res"] if r["res"] != "D" else r["lead"]
                def ir(r):
                    if r is None or r["inc8_s"] == "" or not r["inc8_o"]:
                        return "-"
                    return "%.2f" % (r["inc8_s"] / r["inc8_o"])
                r0, r1 = rr.get("r0"), rr.get("r1")
                print("| %s | %s | %s | %s / %s | %s / %s | %s / %s | %s%s |" % (m, cell(r0), cell(r1),
                      r0["subj_slot"] if r0 else "-", r1["subj_slot"] if r1 else "-",
                      mmss(r0["end"]) if r0 else "-", mmss(r1["end"]) if r1 else "-", ir(r0), ir(r1),
                      cell(oo.get("r0")), cell(oo.get("r1"))))
            print()


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    if sys.argv[1] == "games":
        rows = load(sys.argv[2])
        print(",".join(COLS))
        for r in rows:
            print(",".join(str(r[c]) for c in COLS))
    elif sys.argv[1] == "compare":
        compare(sys.argv[2], sys.argv[3], sys.argv[4].split(","))
