#!/usr/bin/env python3
"""clockwork-ai-v2 (docs/clockwork_ai_v2.md): the Clockwork computer's games, before and after, side by side.
    python3 tools/study/cw_v2_report.py DATA_DIR [DATA_DIR ...]      (each a --data dir of tools/study/qa_matches.py --only cw)
For each dir and each of the Clockwork's three pairings (v the Crown, v the Brood, the mirror): the Clockwork's W-D-L, won or
led (a draw is led by the side whose income earned + 2 x army value at the end is 10% ahead: docs/brood_nerf_study.md), the
mean length of the decided games, the Great Winder's cogs swept (Clockwork sides that had one), the idle Winders (the mean
count over the 5 s looks after 4:00), its STALLS (qa_match.gd: money unspent 60 s, no unit for 90 s) and its first attacks
(the shared "attacking" flag), the enemy's halls lost (the Brood: grounds lost). Mirrors are counted for the P1 side (and both sides' sweeps)."""
import json, os, sys

PAIRS = [("crcw", "v the Crown"), ("brcw", "v the Brood"), ("cwcw", "mirror (P1)")]


def load(d):
    out = []
    for tag in sorted(os.listdir(d)):
        p = os.path.join(d, tag, "result.json")
        if not os.path.exists(p):
            continue
        g = json.load(open(p))
        g["tag"] = tag
        cl = os.path.join(d, tag, "cwlog.txt")
        g["cwlog"] = open(cl, errors="replace").read().splitlines() if os.path.exists(cl) else None
        g["errors"] = os.path.exists(os.path.join(d, tag, "errors.txt"))
        g["pair"] = tag.split("_")[-2]
        sc = [f["income"] + 2 * f["army"] for f in g["final"]]
        if g["winner"] >= 0:
            g["lead"] = g["winner"]
        else:
            g["lead"] = 0 if sc[0] > 1.1 * sc[1] else (1 if sc[1] > 1.1 * sc[0] else -1)
        out.append(g)
    return out


def cw_side(g):
    facs = [s[0] for s in g["slots"]]
    if facs[0] == facs[1]:
        return 0
    return facs.index("clockwork")


def table(d):
    games = load(d)
    lines = ["%s (%d games)" % (d, len(games)), "",
             "| pairing | games | W-D-L | won or led | decided games' mean length | GW cogs swept (sides with one) | idle Winders (mean after 4:00) | stalls (money / no units) | first attack (median) | enemy halls lost | own halls lost | games it committed (won) | games with script errors |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for key, name in PAIRS:
        gs = [g for g in games if g["pair"] == key]
        if not gs:
            continue
        w = dr = l = led = 0
        lens = []
        sweeps = []
        idle = []
        st_m = st_u = 0
        atts = []
        halls_lost = 0
        own_lost = 0
        commits = None
        commit_won = 0
        errs = 0
        for g in gs:
            errs += 1 if g["errors"] else 0
            if g["cwlog"] is not None:
                who = "P%d Clockwork" % (cw_side(g) + 1)
                if any("is clearly ahead" in l and who in l for l in g["cwlog"]):
                    commits = (commits or 0) + 1
                    commit_won += 1 if g["winner"] == cw_side(g) else 0
                elif commits is None:
                    commits = 0
            me = cw_side(g)
            foe = 1 - me
            if g["winner"] == me:
                w += 1
            elif g["winner"] < 0:
                dr += 1
            else:
                l += 1
            if g["lead"] == me:
                led += 1
            if g["winner"] >= 0:
                lens.append(g["end"])
            sides = [0, 1] if key == "cwcw" else [me]
            for s in sides:
                f = g["final"][s]
                if f.get("gw_cogs", 0) > 0 or any(r["p"] == s and r.get("gw_cogs", 0) > 0 for r in g["minutes"]):
                    sweeps.append(max([f.get("gw_cogs", 0)] + [r.get("gw_cogs", 0) for r in g["minutes"] if r["p"] == s]))
            idle.append(g["final"][me].get("idle_w_avg", 0))
            for e in g["events"]:
                if e.get("p") == me and e.get("ev") == "stall":
                    if e.get("kind") == "bank_unspent":
                        st_m += 1
                    elif e.get("kind") == "no_units":
                        st_u += 1
                if e.get("p") == me and e.get("ev") == "first_attack":
                    atts.append(e["t"])
                if e.get("p") == foe and e.get("ev") == "hall_lost" and e.get("built"):
                    halls_lost += 1
                if e.get("p") == me and e.get("ev") == "hall_lost" and e.get("built"):
                    own_lost += 1
                if e.get("p") == foe and e.get("ev") == "brood_ground_lost":
                    halls_lost += int(e["from"]) - int(e["to"])     # (the Brood: its Mother's grounds)
        mm = lambda s: "%d:%02d" % (s // 60, s % 60)
        atts.sort()
        lines.append("| %s | %d | %d-%d-%d | %d of %d | %s | %s | %.1f | %d / %d | %s (%d games) | %d | %d | %s | %d |" % (
            name, len(gs), w, dr, l, led, len(gs), mm(int(sum(lens) / len(lens))) + " (%d)" % len(lens) if lens else "none",
            "%d sides, mean %d, max %d" % (len(sweeps), sum(sweeps) / len(sweeps), max(sweeps)) if sweeps else "none",
            sum(idle) / max(1, len(idle)), st_m, st_u, mm(atts[len(atts) // 2]) if atts else "none", len(atts), halls_lost, own_lost,
            "%d (%d)" % (commits, commit_won) if commits is not None else "-", errs))
    return "\n".join(lines)


if __name__ == "__main__":
    for d in sys.argv[1:]:
        print(table(d))
        print()
