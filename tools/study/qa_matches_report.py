#!/usr/bin/env python3
"""QA MATCHES REPORT (qa-matches): the tables of docs/qa_2026_11_08_matches.md from the games' result.json files.
    python3 tools/study/qa_matches_report.py [DATA] > tables.md
A draw (no winner at 15:00) has a LEADER when one side's income earned + 2 x army value is 10% ahead (the same rule as
docs/brood_nerf_study.md). Income = gold earned (Brood biomass, Crown gold, Clockwork gold; not powder / Tension)."""
import os, sys, json, glob, statistics, collections

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs/qa_2026_11_08_matches/data")
FN = {"crown": "Crown", "brood": "Brood", "clockwork": "Clockwork"}
ORDER = ["crown", "brood", "clockwork"]


def mmss(s):
    return "%d:%02d" % (int(s) // 60, int(s) % 60)


def load():
    games, failed = [], []
    for d in sorted(glob.glob(os.path.join(DATA, "*"))):
        tag = os.path.basename(d)
        if os.path.exists(os.path.join(d, "FAILED.txt")):
            failed.append((tag, open(os.path.join(d, "FAILED.txt")).read()))
            continue
        f = os.path.join(d, "result.json")
        if not os.path.exists(f):
            continue
        g = json.load(open(f))
        g["tag"] = tag
        g["errors"] = open(os.path.join(d, "errors.txt")).read() if os.path.exists(os.path.join(d, "errors.txt")) else ""
        g["story"] = open(os.path.join(d, "story.txt")).read().splitlines() if os.path.exists(os.path.join(d, "story.txt")) else []
        g["kind"] = tag.split("_")[0]
        g["fac"] = [s[0] for s in g["slots"]]
        g["plan"] = [s[1] for s in g["slots"]]
        g["side"] = [s[2] for s in g["slots"]]
        # minutes: (player, minute) -> row
        g["at"] = {}
        for r in g["minutes"]:
            g["at"][(r["p"], int(round(r["t"] / 60)))] = r
        g["n"] = len(g["slots"])
        if g["n"] == 2:
            sc = [f["income"] + 2 * f["army"] for f in g["final"]]
            if g["winner"] >= 0:
                g["res"] = g["winner"]
                g["lead"] = g["winner"]
            else:
                g["res"] = -1
                g["lead"] = 0 if sc[0] > 1.1 * sc[1] else (1 if sc[1] > 1.1 * sc[0] else -1)
        games.append(g)
    return games, failed


def row(g, p, minute):
    """a player's line at that minute; after a game ends early, its last line (the winner keeps it, the loser 0)"""
    r = g["at"].get((p, minute))
    if r is None and g["end"] < minute * 60:
        return None
    return r


def ratio(games, a_of, key, minute):
    """mean of a's over mean of b's at that minute, over games still running"""
    xa, xb = [], []
    for g in games:
        a = a_of(g)
        ra, rb = row(g, a, minute), row(g, 1 - a, minute)
        if ra and rb:
            xa.append(ra[key])
            xb.append(rb[key])
    if not xa or sum(xb) == 0:
        return None, 0
    return sum(xa) / sum(xb), len(xa)


def per_game_ratio(g, a, key, minute):
    ra, rb = row(g, a, minute), row(g, 1 - a, minute)
    if not ra or not rb or rb[key] == 0:
        return None
    return ra[key] / rb[key]


def wdl(games, a_of):
    w = d = l = 0
    led = [0, 0, 0]
    for g in games:
        a = a_of(g)
        if g["res"] == a:
            w += 1
        elif g["res"] == -1:
            d += 1
            led[0 if g["lead"] == a else (2 if g["lead"] == 1 - a else 1)] += 1
        else:
            l += 1
    return w, d, l, led


def fmt(x, n=2):
    return "-" if x is None else ("%." + str(n) + "f") % x


def spread(vals):
    v = [x for x in vals if x is not None]
    if not v:
        return "-"
    return "%.2f-%.2f (sd %.2f)" % (min(v), max(v), statistics.pstdev(v)) if len(v) > 1 else "%.2f" % v[0]


def pair_key(g):
    a, b = g["fac"]
    ia, ib = ORDER.index(a), ORDER.index(b)
    return (a, b) if ia <= ib else (b, a)

import re
STORY_RULES = []


def _foe_row(g, p, sec):
    if g["n"] != 2:
        return None
    m = max(1, int(round(sec / 60)))
    return row(g, 1 - p, m) or row(g, 1 - p, m - 1)


def _own_row(g, p, sec):
    m = max(1, int(round(sec / 60)))
    return row(g, p, m) or row(g, p, m - 1)


def story_checks(games):
    """AI STORY lines that say something the measured game does not bear out (2-player games). Returns
    {rule: [(game, line), ...]}"""
    hits = collections.defaultdict(list)
    for g in games:
        if g["n"] != 2:
            continue
        for line in g["story"]:
            mt = re.match(r"\[(\d+):(\d+)\] P(\d) (\w+)(.*)", line)
            if not mt:
                continue
            sec = int(mt.group(1)) * 60 + int(mt.group(2))
            p = int(mt.group(3)) - 1
            txt = mt.group(5)
            foe = g["fac"][1 - p]
            fr = _foe_row(g, p, sec)
            orow = _own_row(g, p, sec)
            m = re.search(r"holds the top of its ramp: the force below \((\d+)\) is more than its army \((\d+)\)", txt)
            if m and int(m.group(1)) <= int(m.group(2)):
                hits["ramp hold: 'the force below is more than its army can beat' with the force below SMALLER or equal"].append((g, line))
            m = re.search(r"holds the gate of its walled natural: the force outside \((\d+)\) is too strong to go out and meet with its army \((\d+)\)", txt)
            if m and int(m.group(1)) <= int(m.group(2)):
                hits["gate hold: 'the force outside is too strong' with the force outside SMALLER or equal"].append((g, line))
            m = re.search(r"its best base has only (\d+)% left", txt)
            if m and int(m.group(1)) >= 90:
                hits["expansion: 'its best base has ONLY 90-100% left' (the line gives a reason that is not one)"].append((g, line))
            if foe != "crown" and re.search(r"Horse Breeder or riders|riders (leave|in its land)|against \d+ riders|fast rider", txt):
                hits["riders / Horse Breeder named against a %s enemy (it has neither)" % FN[foe]].append((g, line))
            m = re.search(r"puts its army first \((\d+) against the (\d+) it reckons the enemy has\)", txt)
            if m and fr and fr["army"] > 0:
                r = int(m.group(2)) / fr["army"]
                if r > 1.5 or r < 0.67:
                    hits["army first: the enemy army it reckons is off by 1.5x or more (measured %s)" % ("smaller" if r > 1.5 else "bigger")].append((g, line + "  [measured enemy army %d]" % fr["army"]))
            if "reads the enemy as GREEDY (no army and no production" in txt and fr and fr["army"] >= 250:
                hits["GREEDY (no army) read while the enemy had 250+ army value"].append((g, line + "  [measured %d]" % fr["army"]))
            if "reads the enemy as GREEDY (a second base and little army)" in txt and fr and fr["halls"] < 2:
                hits["GREEDY (a second base) read while the enemy had one hall"].append((g, line))
            if "'s rush worked" in txt:
                e = [x for x in g["events"] if x["ev"] == "first_attack" and x["p"] == p and "lost" in x]
                if e and e[0]["lost"] > e[0]["foe_lost"] and e[0]["foe_bld"] == 0:
                    hits["'rush worked' but its first attack lost more units than it killed and razed nothing"].append((g, line + "  [lost %d killed %d]" % (e[0]["lost"], e[0]["foe_lost"])))
            m = re.search(r"defends its (?:home|Mother) with (\d+) against (\d+)", txt)
            if m and int(m.group(2)) == 0:
                hits["defends against 0"].append((g, line))
    return hits


def main():
    games, failed = load()
    base = [g for g in games if g["kind"] == "base"]
    out = []
    P = out.append
    P("Games read: %d (base %d, plans %d, 4-player %d), failed %d. Version(s): %s." % (
        len(games), len(base), len([g for g in games if g["kind"] == "plan"]),
        len([g for g in games if g["n"] > 2]), len(failed), ", ".join(sorted(set(g["version"] for g in games)))))
    P("")
    # ---------------------------------------------------------------- matchups
    P("## Base games: win rates per matchup (OPTIMAL v OPTIMAL)")
    P("")
    P("W-D-L is the first-named faction's (in a mirror: the P1 start spot's). Draws led: "
      "who was ahead at 15:00 (income + 2 x army, 10% margin) as first / even / second. Round 0 and round 1 are the two "
      "seeds of each map, with the sides swapped between them.")
    P("")
    P("| matchup | games | W-D-L | won or led | draws led (1st/even/2nd) | round 0 W-D-L | round 1 W-D-L | same result both rounds | mean length (decided) |")
    P("|---|---|---|---|---|---|---|---|---|")
    by = collections.defaultdict(list)
    for g in base:
        by[pair_key(g)].append(g)
    keys = [("crown", "brood"), ("crown", "clockwork"), ("brood", "clockwork"), ("crown", "crown"), ("brood", "brood"), ("clockwork", "clockwork")]
    for k in keys:
        gs = by.get(k, [])
        if not gs:
            continue
        mirror = k[0] == k[1]
        a_of = (lambda g: 0) if mirror else (lambda g, k=k: g["fac"].index(k[0]))
        w, d, l, led = wdl(gs, a_of)
        r0 = wdl([g for g in gs if g["tag"].endswith("_r0")], a_of)
        r1 = wdl([g for g in gs if g["tag"].endswith("_r1")], a_of)
        # agreement between rounds per map: same outcome for the first faction (in mirrors: same winning START SPOT)
        maps = collections.defaultdict(dict)
        for g in gs:
            a = a_of(g)
            o = "W" if g["res"] == a else ("D" if g["res"] == -1 else "L")
            maps[g["map"]][g["tag"][-2:]] = o
        both = [m for m in maps.values() if len(m) == 2]
        same = sum(1 for m in both if m["r0"] == m["r1"])
        dec = [g["end"] for g in gs if g["res"] != -1]
        name = "%s v %s" % (FN[k[0]], FN[k[1]]) + (" (mirror)" if mirror else "")
        P("| %s | %d | %d-%d-%d | %d | %d/%d/%d | %d-%d-%d | %d-%d-%d | %s | %s |" % (
            name, len(gs), w, d, l, w + led[0], led[0], led[1], led[2], r0[0], r0[1], r0[2], r1[0], r1[1], r1[2],
            "%d of %d maps" % (same, len(both)) if both else "-", ("%s (%d)" % (mmss(statistics.mean(dec)), len(dec))) if dec else "-"))
    P("")
    # ---------------------------------------------------------------- economy
    P("## Economy ratios (base games, cross matchups)")
    P("")
    P("First-named faction's mean over the second's, over the games still running at that minute (n).")
    P("")
    P("| matchup | income 5:00 | 8:00 | 10:00 | 15:00 | army 5:00 | 8:00 | 10:00 | 15:00 | workers 8:00 | halls 8:00 (1st / 2nd) |")
    P("|---|---|---|---|---|---|---|---|---|---|---|")
    for k in keys[:3]:
        gs = by.get(k, [])
        if not gs:
            continue
        a_of = lambda g, k=k: g["fac"].index(k[0])
        cells = []
        for key in ("income", "army"):
            for m in (5, 8, 10, 15):
                r, nn = ratio(gs, a_of, key, m)
                cells.append("%s (%d)" % (fmt(r), nn))
        rw, _ = ratio(gs, a_of, "workers", 8)
        ha = [row(g, a_of(g), 8)["halls"] for g in gs if row(g, a_of(g), 8) and row(g, 1 - a_of(g), 8)]
        hb = [row(g, 1 - a_of(g), 8)["halls"] for g in gs if row(g, a_of(g), 8) and row(g, 1 - a_of(g), 8)]
        P("| %s v %s | %s | %s | %s / %s |" % (FN[k[0]], FN[k[1]], " | ".join(cells), fmt(rw),
                                               fmt(statistics.mean(ha), 1) if ha else "-", fmt(statistics.mean(hb), 1) if hb else "-"))
    P("")
    P("Spread between games (what is noise): the first-named faction's income ratio per game.")
    P("")
    P("| matchup | income ratio 8:00 min-max (sd) | 10:00 | army ratio 10:00 |")
    P("|---|---|---|---|")
    for k in keys:
        gs = by.get(k, [])
        if not gs:
            continue
        mirror = k[0] == k[1]
        a_of = (lambda g: 0) if mirror else (lambda g, k=k: g["fac"].index(k[0]))
        P("| %s v %s%s | %s | %s | %s |" % (FN[k[0]], FN[k[1]], " (P1/P2)" if mirror else "",
            spread([per_game_ratio(g, a_of(g), "income", 8) for g in gs]),
            spread([per_game_ratio(g, a_of(g), "income", 10) for g in gs]),
            spread([per_game_ratio(g, a_of(g), "army", 10) for g in gs])))
    P("")
    # absolute economy by faction
    P("Each faction's own numbers (base games, every opponent): mean income / workers / army / halls.")
    P("")
    P("| faction | games | income 5:00 | 8:00 | 10:00 | 15:00 | workers 8:00 | army 8:00 | army 10:00 | halls 8:00 | halls 15:00 |")
    P("|---|---|---|---|---|---|---|---|---|---|---|")
    for f in ORDER:
        pl = [(g, p) for g in base for p in range(2) if g["fac"][p] == f]
        def m_(key, mi):
            v = [row(g, p, mi)[key] for g, p in pl if row(g, p, mi)]
            return "%d" % statistics.mean(v) if v else "-"
        def m1(key, mi):
            v = [row(g, p, mi)[key] for g, p in pl if row(g, p, mi)]
            return "%.1f" % statistics.mean(v) if v else "-"
        P("| %s | %d | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (FN[f], len(pl), m_("income", 5), m_("income", 8), m_("income", 10),
          m_("income", 15), m_("workers", 8), m_("army", 8), m_("army", 10), m1("halls", 8), m1("halls", 15)))
    P("")
    # ---------------------------------------------------------------- the brood nerf study's maps
    NERF = ["dune_sea", "greenhold", "red_coast", "hollowfen", "kestrel_rise"]
    P("## On the brood-nerf-study's five maps (to compare with docs/brood_nerf_study.md, 0.33.6, FOOD_BONUS 1.2)")
    P("")
    P("| matchup (subject first) | games | W-D-L | won or led | income ratio 8:00 | army ratio 8:00 |")
    P("|---|---|---|---|---|---|")
    for k, subj in ((("crown", "brood"), "brood"), (("brood", "clockwork"), "brood"), (("crown", "clockwork"), "crown")):
        gs = [g for g in by.get(k, []) if g["map"] in NERF]
        if not gs:
            continue
        a_of = lambda g, f=subj: g["fac"].index(f)
        w, d, l, led = wdl(gs, a_of)
        ri, _ = ratio(gs, a_of, "income", 8)
        ra, _ = ratio(gs, a_of, "army", 8)
        other = k[1] if subj == k[0] else k[0]
        P("| %s v %s | %d | %d-%d-%d | %d | %s | %s |" % (FN[subj], FN[other], len(gs), w, d, l, w + led[0], fmt(ri), fmt(ra)))
    P("")
    # ---------------------------------------------------------------- lengths
    P("## Game length (base games)")
    P("")
    P("| matchup | decided | before 8:00 | 8:00-12:00 | after 12:00 | draws at 15:00 | shortest |")
    P("|---|---|---|---|---|---|---|")
    for k in keys:
        gs = by.get(k, [])
        if not gs:
            continue
        dec = sorted(g["end"] for g in gs if g["res"] != -1)
        P("| %s v %s | %d | %d | %d | %d | %d | %s |" % (FN[k[0]], FN[k[1]], len(dec), len([x for x in dec if x < 480]),
          len([x for x in dec if 480 <= x < 720]), len([x for x in dec if x >= 720]), len(gs) - len(dec), mmss(dec[0]) if dec else "-"))
    P("")
    # ---------------------------------------------------------------- maps
    P("## Per map (base games)")
    P("")
    P("Each cell: the first-named faction's results on that map over its two games (W/D/L letters, round 0 then round 1; "
      "lower case = a draw it led (w) or trailed (l)). START SPOT: in all of that map's games, wins (and won-or-led) by "
      "the P1 spot against the P2 spot.")
    P("")
    P("| map | Cr v Br | Cr v Cw | Br v Cw | Cr v Cr (P1) | Br v Br (P1) | Cw v Cw (P1) | P1 spot W-L (won or led) | mirrors P1 W-L |")
    P("|---|---|---|---|---|---|---|---|---|")
    maps = []
    for g in base:
        if g["map"] not in maps:
            maps.append(g["map"])
    fav = collections.Counter()
    for m in maps:
        cells = []
        for k in keys:
            mirror = k[0] == k[1]
            s = ""
            for r in ("r0", "r1"):
                gg = [g for g in base if g["map"] == m and pair_key(g) == k and g["tag"].endswith(r)]
                if not gg:
                    s += "."
                    continue
                g = gg[0]
                a = 0 if mirror else g["fac"].index(k[0])
                if g["res"] == a:
                    s += "W"
                elif g["res"] == 1 - a:
                    s += "L"
                else:
                    s += "w" if g["lead"] == a else ("l" if g["lead"] == 1 - a else "d")
            cells.append(s)
        gm = [g for g in base if g["map"] == m]
        p1w = sum(1 for g in gm if g["res"] == 0)
        p2w = sum(1 for g in gm if g["res"] == 1)
        p1l = sum(1 for g in gm if g["lead"] == 0)
        p2l = sum(1 for g in gm if g["lead"] == 1)
        mm = [g for g in gm if g["fac"][0] == g["fac"][1]]
        P("| %s | %s | %d-%d (%d-%d) | %d-%d |" % (m, " | ".join(cells), p1w, p2w, p1l, p2l,
          sum(1 for g in mm if g["res"] == 0), sum(1 for g in mm if g["res"] == 1)))
    tot1 = sum(1 for g in base if g["res"] == 0)
    tot2 = sum(1 for g in base if g["res"] == 1)
    l1 = sum(1 for g in base if g["lead"] == 0)
    l2 = sum(1 for g in base if g["lead"] == 1)
    mir = [g for g in base if g["fac"][0] == g["fac"][1]]
    P("")
    P("All base games: the P1 spot won %d, the P2 spot %d (won or led %d - %d); in the mirrors alone P1 %d - P2 %d (won or led %d - %d)." % (
        tot1, tot2, l1, l2, sum(1 for g in mir if g["res"] == 0), sum(1 for g in mir if g["res"] == 1),
        sum(1 for g in mir if g["lead"] == 0), sum(1 for g in mir if g["lead"] == 1)))
    P("")
    # per map: per faction won-or-led across both cross pairings
    P("Per map, each faction's record in its cross games (won-or-led of games, with the income ratio at 8:00 against its opponents):")
    P("")
    P("| map | Crown | Brood | Clockwork |")
    P("|---|---|---|---|")
    for m in maps:
        cells = []
        for f in ORDER:
            pl = [(g, g["fac"].index(f)) for g in base if g["map"] == m and f in g["fac"] and g["fac"][0] != g["fac"][1]]
            wl = sum(1 for g, p in pl if g["lead"] == p)
            rr = [per_game_ratio(g, p, "income", 8) for g, p in pl]
            rr = [x for x in rr if x is not None]
            cells.append("%d of %d, %s" % (wl, len(pl), fmt(statistics.mean(rr)) if rr else "-"))
        P("| %s | %s |" % (m, " | ".join(cells)))
    P("")
    # ---------------------------------------------------------------- first attacks
    P("## First attacks (base games)")
    P("")
    P("The first time a computer marks itself attacking; 90 s later: units lost each side, enemy buildings razed. "
      "'Paid' = it razed a building or killed more units than it lost; 'thrown away' = it lost more than twice what it killed and razed nothing.")
    P("")
    P("| faction | attacks | median time | earliest | paid | thrown away | games with no attack by 15:00 |")
    P("|---|---|---|---|---|---|---|")
    for f in ORDER:
        at = []
        none = 0
        for g in base:
            for p in range(2):
                if g["fac"][p] != f:
                    continue
                e = [x for x in g["events"] if x["ev"] == "first_attack" and x["p"] == p]
                if e:
                    at.append(e[0])
                elif g["end"] >= 600:
                    none += 1
        fin = [e for e in at if "lost" in e]
        paid = sum(1 for e in fin if e["foe_bld"] > 0 or e["foe_lost"] > e["lost"])
        thrown = sum(1 for e in fin if e["foe_bld"] == 0 and e["lost"] > 2 * max(1, e["foe_lost"]))
        ts = sorted(e["t"] for e in at)
        P("| %s | %d | %s | %s | %d of %d | %d | %d |" % (FN[f], len(at), mmss(statistics.median(ts)) if ts else "-", mmss(ts[0]) if ts else "-", paid, len(fin), thrown, none))
    P("")
    # ---------------------------------------------------------------- first arrivals
    P("First ENEMY ARRIVAL in each base (300+ enemy army value within 500 px of the side's buildings or rooted creatures; "
      "it counts the Clockwork's pushes too, which never mark themselves attacking). 90 s later: units lost by each, the "
      "defender's buildings lost. 'Attacker paid' = the defender lost buildings or more units than the attacker.")
    P("")
    P("| attacker | arrivals | median time | earliest | attacker paid | defender held (attacker lost 2x more, no building) | games with no arrival by 15:00 |")
    P("|---|---|---|---|---|---|---|")
    for f in ORDER:
        arr = []
        none = 0
        for g in base:
            for p in range(2):
                if g["fac"][p] != f:
                    continue
                e = [x for x in g["events"] if x["ev"] == "first_arrival" and x["p"] == 1 - p]
                if e:
                    arr.append(e[0])
                elif g["end"] >= 600 and any(x["ev"] == "first_arrival" for x in g["events"]) is not None:
                    none += 1
        ts = sorted(e["t"] for e in arr)
        paid = sum(1 for e in arr if e["own_bld"] > 0 or e["own_lost"] > e["foe_lost"])
        held = sum(1 for e in arr if e["own_bld"] == 0 and e["foe_lost"] > 2 * max(1, e["own_lost"]))
        P("| %s | %d | %s | %s | %d | %d | %d |" % (FN[f], len(arr), mmss(statistics.median(ts)) if ts else "-", mmss(ts[0]) if ts else "-", paid, held, none))
    P("")
    # ---------------------------------------------------------------- halls lost
    P("## Halls lost (base games)")
    P("")
    P("| faction | games | halls lost (built) | lost unbuilt (sites) | games losing 3+ | most in one game | same spot lost twice or more |")
    P("|---|---|---|---|---|---|---|")
    for f in ORDER:
        tot = unb = g3 = mx = rep = 0
        mxg = ""
        ng = 0
        for g in base:
            for p in range(2):
                if g["fac"][p] != f:
                    continue
                ng += 1
                hl = [e for e in g["events"] if e["ev"] == "hall_lost" and e["p"] == p]
                b = [e for e in hl if e.get("built", True)]
                tot += len(b)
                unb += len(hl) - len(b)
                if len(hl) >= 3:
                    g3 += 1
                if len(hl) > mx:
                    mx, mxg = len(hl), g["tag"]
                spots = collections.Counter(e["at"] for e in hl)
                rep += sum(1 for s, c in spots.items() if c >= 2)
        P("| %s | %d | %d | %d | %d | %d (%s) | %d |" % (FN[f], ng, tot, unb, g3, mx, mxg, rep))
    P("")
    bl = [(g, e) for g in base for e in g["events"] if e["ev"] == "brood_ground_lost"]
    P("The Brood has no halls: its 'ground' (the Queen plus its rooted expansions) shrank %d times in %d of %d Brood sides "
      "(lost or uprooted; the tool cannot tell which); Brood Queens killed (Brood side out of the game): %d." % (
      len(bl), len(set((g["tag"], e["p"]) for g, e in bl)), sum(1 for g in base for p in range(2) if g["fac"][p] == "brood"),
      sum(1 for g in base for p in range(2) if g["fac"][p] == "brood" and g["final"][p]["out"])))
    P("")
    # ---------------------------------------------------------------- plans
    plans = [g for g in games if g["kind"] == "plan"]
    if plans:
        P("## Other plans against OPTIMAL (one game each)")
        P("")
        P("| plan | opponent (OPTIMAL) | map | result for the plan | end | income ratio 8:00 | army ratio 10:00 | first attack |")
        P("|---|---|---|---|---|---|---|---|")
        recs = collections.defaultdict(lambda: [0, 0, 0])
        for g in plans:
            p = [i for i in range(2) if g["plan"][i] != "optimal"]
            p = p[0] if p else 0
            r = "won" if g["res"] == p else ("lost" if g["res"] == 1 - p else ("draw, led" if g["lead"] == p else ("draw, behind" if g["lead"] == 1 - p else "draw, even")))
            recs[(g["fac"][p], g["plan"][p])][0 if r.startswith("won") or r == "draw, led" else (2 if r in ("lost", "draw, behind") else 1)] += 1
            e = [x for x in g["events"] if x["ev"] == "first_attack" and x["p"] == p]
            P("| %s %s | %s | %s | %s | %s | %s | %s | %s |" % (FN[g["fac"][p]], g["plan"][p], FN[g["fac"][1 - p]], g["map"], r, mmss(g["end"]),
              fmt(per_game_ratio(g, p, "income", 8)), fmt(per_game_ratio(g, p, "army", 10)), mmss(e[0]["t"]) if e else "none"))
        P("")
    # OPTIMAL's picks
    P("## What OPTIMAL picked (base games)")
    P("")
    P("The build each OPTIMAL side was playing at 5:00 and at 15:00 (or the end), and how those sides did.")
    P("")
    P("| faction | build at 5:00 | sides | won or led | at the end (most common) |")
    P("|---|---|---|---|---|")
    for f in ORDER:
        c = collections.defaultdict(list)
        for g in base:
            for p in range(2):
                if g["fac"][p] != f:
                    continue
                r5 = row(g, p, 5)
                c[r5["plan"] if r5 else "?"].append((g, p))
        for k5, pl in sorted(c.items(), key=lambda x: -len(x[1])):
            wl = sum(1 for g, p in pl if g["lead"] == p)
            ends = collections.Counter(g["final"][p]["plan"] for g, p in pl).most_common(2)
            P("| %s | %s | %d | %d | %s |" % (FN[f], k5, len(pl), wl, ", ".join("%s %d" % e for e in ends)))
    P("")
    # ---------------------------------------------------------------- multi
    multi = [g for g in games if g["n"] > 2]
    if multi:
        P("## 4-player games")
        P("")
        P("| game | players (side) | end | winner | income at the end | army at the end | halls at the end |")
        P("|---|---|---|---|---|---|---|")
        for g in multi:
            pl = ", ".join("P%d %s (%d)" % (i + 1, FN[g["fac"][i]], g["side"][i]) for i in range(g["n"]))
            w = ("P%d %s, side %d" % (g["winner"] + 1, FN[g["fac"][g["winner"]]], g["winner_side"])) if g["winner"] >= 0 else "none"
            P("| %s | %s | %s | %s | %s | %s | %s |" % (g["tag"], pl, mmss(g["end"]), w, " / ".join(str(f["income"]) for f in g["final"]),
              " / ".join(str(f["army"]) for f in g["final"]), " / ".join(str(f["halls"]) for f in g["final"])))
        P("")
    # ---------------------------------------------------------------- problems
    P("## Problems seen")
    P("")
    P("### Stalls (every game)")
    P("")
    P("bank_unspent: 400+ gold in the bank and nothing spent for 60 s or more; no_units: no unit made for 90 s or more "
      "after 2:30 while under the supply cap; army_idle_enemy_in_base: 300+ enemy army value within 500 px of its buildings "
      "while its own army (4+ units, 300+ value, under a quarter of it fighting) moved under 40 px (median) in 60 s.")
    P("")
    stalls = [(g, e) for g in games for e in g["events"] if e["ev"] == "stall"]
    P("| kind | faction | count | games | longest |")
    P("|---|---|---|---|---|")
    sk = collections.defaultdict(list)
    for g, e in stalls:
        sk[(e["kind"], g["fac"][e["p"]])].append((g, e))
    for (kind, f), lst in sorted(sk.items()):
        lg = max(lst, key=lambda x: x[1]["len"])
        P("| %s | %s | %d | %d | %ds (%s P%d at %s, %s) |" % (kind, FN[f], len(lst), len(set(g["tag"] for g, e in lst)), lg[1]["len"],
          lg[0]["tag"], lg[1]["p"] + 1, mmss(lg[1]["t"]), lg[1]["note"]))
    P("")
    P("Longest stalls (to replay: map and seed are in the tag's result.json):")
    P("")
    for g, e in sorted(stalls, key=lambda x: -x[1]["len"])[:25]:
        P("- %s (map %s seed %d) P%d %s %s: %s for %ds (%s)" % (g["tag"], g["map"], g["seed"], e["p"] + 1, FN[g["fac"][e["p"]]],
          mmss(e["t"]), e["kind"], e["len"], e["note"]))
    P("")
    P("### Units stuck on a move order (30 s+ without moving 8 px, not fighting, not at the goal)")
    P("")
    st = [(g, e) for g in games for e in g["events"] if e["ev"] == "stuck"]
    P("Total %d in %d games." % (len(st), len(set(g["tag"] for g, e in st))))
    P("")
    P("| unit | faction | count | maps |")
    P("|---|---|---|---|")
    su = collections.defaultdict(list)
    for g, e in st:
        su[(e["kind"], g["fac"][e["p"]])].append((g, e))
    for (k, f), lst in sorted(su.items(), key=lambda x: -len(x[1]))[:25]:
        P("| %s | %s | %d | %s |" % (k, FN[f], len(lst), ", ".join("%s %d" % x for x in collections.Counter(g["map"] for g, e in lst).most_common(4))))
    P("")
    spots = collections.Counter((g["map"], e["at"]) for g, e in st)
    P("Spots where units got stuck in more than one case: " + "; ".join("%s %s x%d" % (m, a, c) for (m, a), c in spots.most_common(15) if c > 1))
    P("")
    P("Examples: " + "; ".join("%s P%d %s %s at %s -> %s (%s)" % (g["tag"], e["p"] + 1, e["kind"], mmss(e["t"]), e["at"], e["goal"], e["order"]) for g, e in st[:12]))
    P("")
    P("### AI STORY lines that the game does not bear out")
    P("")
    hits = story_checks(games)
    P("| rule | lines | games | example |")
    P("|---|---|---|---|")
    for k, lst in sorted(hits.items(), key=lambda x: -len(x[1])):
        P("| %s | %d | %d | %s: `%s` |" % (k, len(lst), len(set(g["tag"] for g, l in lst)), lst[0][0]["tag"], lst[0][1][:200]))
    P("")
    P("### Script errors and failed games")
    P("")
    er = [g for g in games if g["errors"]]
    P("%d games printed error lines; %d games failed (no result)." % (len(er), len(failed)))
    P("")
    allerr = collections.Counter()
    for g in er:
        for l in g["errors"].splitlines()[1:]:
            c, txt = l.strip().split("  ", 1)
            allerr[txt] += int(c)
    for txt, c in allerr.most_common(15):
        P("- %dx: `%s` (first in %s)" % (c, txt[:300], next(g["tag"] for g in er if txt in g["errors"])))
    for tag, txt in failed:
        P("- FAILED %s: %s" % (tag, txt.splitlines()[0]))
    P("")
    print("\n".join(out))


if __name__ == "__main__":
    main()
