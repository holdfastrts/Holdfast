#!/usr/bin/env python3
"""THE BROOD NERF STUDY's tables (docs/brood_nerf_study.md) from the games tools/study/brood_nerf_games.py played:
    python3 tools/study/brood_nerf_report.py docs/brood_nerf_study/data > tables.md
The SUBJECT of a game is the Brood (cvb, cvbe, kvb) or the Crown (cvk, the control). Win / draw / loss are the subject's;
a game with no winner at 15:00 is a draw, and its LEADER is the side whose income earned + 2 x army value is 10% ahead
(the same rule as ai_optimal_games.py). Income = gold earned (the Crown's powder and the Clockwork's Tension are not in it:
the same measure the earlier studies used)."""
import os, re, sys, statistics as st

NAMES = {"cvb": "Crown v Brood (OPTIMAL v OPTIMAL)", "cvbe": "Crown OPTIMAL v Brood ECONOMY",
         "kvb": "Clockwork v Brood (OPTIMAL v OPTIMAL)", "cvk": "Crown v Clockwork (control; Crown's view)"}
SUBJ = {"cvb": "brood", "cvbe": "brood", "kvb": "brood", "cvk": "crown"}
LINE = re.compile(r"(\d+):(\d+) P(\d) (\S+) \S+ \((\S+)\): income (\d+) \| workers (\d+) \| army (\d+) \| halls (\d+) \| supply (\d+) \| maws (\d+)")


def parse(d):
    rp = os.path.join(d, "result.txt")
    if not os.path.exists(rp):
        return None
    txt = open(rp).read()
    m = re.match(r"(\w+?)_(.+)_s(\d+)_fb([\d.]+)$", os.path.basename(d))
    mu, mp, seed, fb = m.group(1), m.group(2), int(m.group(3)), m.group(4)
    at = {}
    fac = {}
    strat = {}
    for l in txt.split("\n"):
        x = LINE.match(l)
        if x:
            t = int(x.group(1)) * 60 + int(x.group(2))
            p = int(x.group(3))
            fac[p] = x.group(4)
            at[(t, p)] = dict(income=int(x.group(6)), workers=int(x.group(7)), army=int(x.group(8)), halls=int(x.group(9)),
                              supply=int(x.group(10)), maws=int(x.group(11)), strat=x.group(5))
            strat.setdefault(p, []).append(x.group(5))
    e = re.search(r"end (\d+):(\d+) winner (\S+)", txt)
    end = int(e.group(1)) * 60 + int(e.group(2))
    win = e.group(3)
    sp = [p for p in fac if fac[p] == SUBJ[mu]][0]
    op = 3 - sp
    last = max(t for (t, p) in at)
    res = "W" if win == "P%d" % sp else ("L" if win == "P%d" % op else "D")
    lead = ""
    if res == "D":
        s1 = at[(last, sp)]["income"] + 2 * at[(last, sp)]["army"]
        s2 = at[(last, op)]["income"] + 2 * at[(last, op)]["army"]
        lead = "subj" if s1 > 1.1 * s2 else ("opp" if s2 > 1.1 * s1 else "even")
    picks = re.findall(r"P%d pick (\S+) \S+ \S+ -> (\S+)" % sp, txt)
    return dict(mu=mu, map=mp, seed=seed, fb=fb, sp=sp, op=op, at=at, end=end, res=res, lead=lead, opp=fac[op],
                picks=picks, strat=strat.get(sp, []))


def val(g, t, side, k):
    v = g["at"].get((t, g[side]))
    return None if v is None else v[k]


def ratio(g, t, k):
    a, b = val(g, t, "sp", k), val(g, t, "op", k)
    if a is None or b is None or b == 0:
        return None
    return a / b


def rmean(s, t, k):
    """The ratio of the means (games that have both sides at t): steadier than a mean of ratios when one side has ~0."""
    pr = [(val(g, t, "sp", k), val(g, t, "op", k)) for g in s]
    pr = [p for p in pr if p[0] is not None and p[1] is not None]
    if not pr or sum(p[1] for p in pr) == 0:
        return "-"
    return "%.2f" % (sum(p[0] for p in pr) / sum(p[1] for p in pr))


def mean(xs, f="%.2f"):
    xs = [x for x in xs if x is not None]
    return (f % st.mean(xs)) if xs else "-"


def spread(xs, f="%.2f"):
    xs = [x for x in xs if x is not None]
    if len(xs) < 2:
        return "-"
    return (f + "-" + f + " (sd " + f + ")") % (min(xs), max(xs), st.stdev(xs))


def mmss(s):
    return "%d:%02d" % (s // 60, s % 60)


def main(data):
    gs = [g for g in (parse(os.path.join(data, d)) for d in sorted(os.listdir(data))) if g]
    stalled = [d for d in sorted(os.listdir(data)) if os.path.exists(os.path.join(data, d, "STALLED.txt"))]
    out = []
    keys = [k for k in ["cvb", "cvbe", "kvb", "cvk"] if any(g["mu"] == k for g in gs)]
    out.append("## Summary per matchup and bonus\n")
    out.append("Win / draw / loss are the subject's (the Brood; the Crown in the control). Draws: who led at 15:00 "
               "(income + 2 x army, 10% margin) as subject / even / opponent. Ratios are the subject's mean over its opponent's mean (games still running at that time).\n")
    out.append("| matchup | bonus | games | W-D-L | draws led (subj/even/opp) | mean length (decided games) | income ratio 5:00 / 8:00 / 10:00 | army ratio 8:00 / 10:00 |")
    out.append("|---|---|---|---|---|---|---|---|")
    for k in keys:
        for fb in ["1.5", "1.2"]:
            s = [g for g in gs if g["mu"] == k and g["fb"] == fb]
            if not s:
                continue
            w = sum(g["res"] == "W" for g in s); d = sum(g["res"] == "D" for g in s); l = sum(g["res"] == "L" for g in s)
            dl = [sum(g["lead"] == x for g in s) for x in ("subj", "even", "opp")]
            dec = [g["end"] for g in s if g["res"] != "D"]
            out.append("| %s | %s | %d | %d-%d-%d | %d/%d/%d | %s (%d) | %s / %s / %s | %s / %s |" % (
                NAMES[k], fb, len(s), w, d, l, dl[0], dl[1], dl[2], mmss(int(st.mean(dec))) if dec else "-", len(dec),
                rmean(s, 300, "income"), rmean(s, 480, "income"), rmean(s, 600, "income"), rmean(s, 480, "army"),
                rmean(s, 600, "army")))
    out.append("\n## The Brood's economy at 8:00 (Brood games)\n")
    out.append("| matchup | bonus | Brood income 5:00 / 8:00 / 10:00 | opponent's | Brood army 8:00 / 10:00 | opponent's | Brood halls / Rootmaws / grubs at 8:00 |")
    out.append("|---|---|---|---|---|---|---|")
    for k in keys:
        if k == "cvk":
            continue
        for fb in ["1.5", "1.2"]:
            s = [g for g in gs if g["mu"] == k and g["fb"] == fb]
            if not s:
                continue
            f0 = "%.0f"
            out.append("| %s | %s | %s / %s / %s | %s / %s / %s | %s / %s | %s / %s | %s / %s / %s |" % (
                NAMES[k], fb, *[mean([val(g, t, "sp", "income") for g in s], f0) for t in (300, 480, 600)],
                *[mean([val(g, t, "op", "income") for g in s], f0) for t in (300, 480, 600)],
                *[mean([val(g, t, "sp", "army") for g in s], f0) for t in (480, 600)],
                *[mean([val(g, t, "op", "army") for g in s], f0) for t in (480, 600)],
                *[mean([val(g, 480, "sp", x) for g in s], "%.1f") for x in ("halls", "maws", "workers")]))
    out.append("\n## Spread between seeds (what is noise)\n")
    out.append("| matchup | bonus | income ratio 8:00, min-max (sd) | income ratio 10:00 | army ratio 10:00 |")
    out.append("|---|---|---|---|---|")
    for k in keys:
        for fb in ["1.5", "1.2"]:
            s = [g for g in gs if g["mu"] == k and g["fb"] == fb]
            if s:
                out.append("| %s | %s | %s | %s | %s |" % (NAMES[k], fb, spread([ratio(g, 480, "income") for g in s]),
                           spread([ratio(g, 600, "income") for g in s]), spread([ratio(g, 600, "army") for g in s])))
    # the control's twins: same map and seed, the bonus cannot touch the game, so their gap is pure run-to-run noise
    tw = {}
    for g in gs:
        if g["mu"] == "cvk":
            tw.setdefault((g["map"], g["seed"]), {})[g["fb"]] = g
    diffs = []
    same = 0
    for kk, v in tw.items():
        if len(v) == 2:
            a, b = v["1.2"], v["1.5"]
            r1, r2 = ratio(a, 480, "income"), ratio(b, 480, "income")
            if r1 and r2:
                diffs.append(abs(r1 - r2))
            same += a["res"] == b["res"]
    if diffs:
        out.append("\nControl twins (Crown v Clockwork, same map and seed, run twice; the bonus does not enter): %d pairs, "
                   "the same result in %d; the Crown's income ratio at 8:00 differs by %.2f on average (max %.2f) between "
                   "the twins. The game is not deterministic run to run, so this is the noise floor of one game.\n"
                   % (len(diffs), same, st.mean(diffs), max(diffs)))
    out.append("\n## Per map (subject's W-D-L; income ratio at 8:00)\n")
    out.append("| map | " + " | ".join("%s %s" % (k, fb) for k in keys for fb in ("1.5", "1.2")) + " |")
    out.append("|---|" + "---|" * (2 * len(keys)))
    for mp in ["dune_sea", "greenhold", "red_coast", "hollowfen", "kestrel_rise"]:
        cells = []
        for k in keys:
            for fb in ("1.5", "1.2"):
                s = [g for g in gs if g["mu"] == k and g["fb"] == fb and g["map"] == mp]
                if not s:
                    cells.append("-")
                    continue
                cells.append("%d-%d-%d, %s" % (sum(g["res"] == "W" for g in s), sum(g["res"] == "D" for g in s),
                                               sum(g["res"] == "L" for g in s), mean([ratio(g, 480, "income") for g in s])))
        out.append("| %s | %s |" % (mp, " | ".join(cells)))
    out.append("\n## Every game\n")
    out.append("| game | subject P | result | end | draw leader | income 8:00 subj/opp | army 8:00 | army 10:00 | Brood halls/maws/grubs 8:00 | subject's builds |")
    out.append("|---|---|---|---|---|---|---|---|---|---|")
    for g in sorted(gs, key=lambda g: (g["mu"], g["map"], g["seed"], g["fb"])):
        bi = "sp" if g["mu"] != "cvk" else None
        hm = "%s/%s/%s" % (val(g, 480, bi, "halls"), val(g, 480, bi, "maws"), val(g, 480, bi, "workers")) if bi else "-"
        bl = []
        for x in g["strat"]:
            if not bl or bl[-1] != x:
                bl.append(x)
        out.append("| %s %s s%d fb%s | P%d | %s | %s | %s | %s/%s | %s/%s | %s/%s | %s | %s |" % (
            g["mu"], g["map"], g["seed"], g["fb"], g["sp"], g["res"], mmss(g["end"]), g["lead"] or "",
            val(g, 480, "sp", "income"), val(g, 480, "op", "income"), val(g, 480, "sp", "army"), val(g, 480, "op", "army"),
            val(g, 600, "sp", "army"), val(g, 600, "op", "army"), hm, ">".join(bl)))
    if stalled:
        out.append("\nStalled or crashed (no result): " + ", ".join(stalled))
    print("\n".join(out))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "docs/brood_nerf_study/data")
