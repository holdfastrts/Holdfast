#!/usr/bin/env python3
"""The tables of docs/clockwork_builds_b.md from the lines tools/test_clockwork_builds_b.gd writes with json:<file>.
    python3 -I tools/clockwork_builds_b_report.py <file.json> [...]
One line a game: the milestones, then the economy and the fights at 6, 8, 10 and 12 minutes, then averages by plan and foe."""
import json
import sys


def mmss(s):
    if s is None or s < 0:
        return "never"
    return "%d:%02d" % (int(s) // 60, int(s) % 60)


def games(paths):
    out = []
    for p in paths:
        for line in open(p, encoding="utf-8"):
            line = line.strip()
            if line:
                out.append(json.loads(line))
    return out


NAMES = {"pendulum": "Pendulums", "heavy": "Heavy Works push", "balanced": "old Balanced", "rush": "old Rush",
         "springer": "Springer timing"}


def label(g):
    return "%s %d" % (g["map"].replace("_", " ").title(), g["seed"])


def foe(g):
    return "%s %s" % (g["foe"].title(), g["fp"])


def main():
    gs = games(sys.argv[1:])
    print("### When the build is ready\n")
    print("| map | foe | plan | Heavy Works laid | stands | 1st Pendulum | 2nd | 3rd | 1st Ballista | 2nd | Great Winder | 2nd hall laid | push out | first wall piece down | first Rootmaw/turtle killed |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for g in gs:
        m = g["ms"]
        print("| %s | %s | %s | %s |" % (label(g), foe(g), NAMES.get(g["cw"], g["cw"]), " | ".join(mmss(m.get(k)) for k in
              ["heavy_laid", "heavy", "pend1", "pend2", "pend3", "bal1", "bal2", "gw", "hall2_laid", "push", "piece", "econ_kill"])))
    print("\n### The economy and the fights\n")
    print("| map | foe | plan | Winders 6:00 / 8:00 / 10:00 | cogs earned 6:00 / 8:00 / 10:00 | foe earned 8:00 / 10:00 | army 8:00 (CW / foe) | killed / lost by 8:00 | by 10:00 | by 12:00 | Brood economy lost by 12:00 (Rootmaws, turtles, grubs) | pushes, retreats | winner |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for g in gs:
        mk = g["marks"]
        e = g["end"]

        def at(k, f):
            return mk.get(k, e).get(f, 0)
        bl = mk.get("720", e)["brood_lost"]
        p = g.get("push", {})
        print("| %s | %s | %s | %d / %d / %d | %d / %d / %d | %d / %d | %d / %d | %d / %d | %d / %d | %d / %d | %s | %s | %s |" % (
            label(g), foe(g), NAMES.get(g["cw"], g["cw"]),
            at("360", "cw_workers"), at("480", "cw_workers"), at("600", "cw_workers"),
            at("360", "cw_earned"), at("480", "cw_earned"), at("600", "cw_earned"),
            at("480", "foe_earned"), at("600", "foe_earned"),
            at("480", "cw_army"), at("480", "foe_army"),
            at("480", "cw_killed"), at("480", "cw_lost"), at("600", "cw_killed"), at("600", "cw_lost"),
            at("720", "cw_killed"), at("720", "cw_lost"),
            ("%d, %d, %d" % (bl["rootmaw"], bl["mound_turtle"], bl["grub"])) if g["foe"] == "brood" else "-",
            ("%d, %d" % (p.get("pushes", 0), p.get("retreats", 0))) if p else "-",
            g["winner"] + (" at " + mmss(g["clock"]) if g["winner"] != "none" else " by " + mmss(g["clock"]))))
    print("\n### Averages\n")
    print("| plan | foe | games | Winders 8:00 | earned 8:00 | earned 10:00 | killed / lost by 10:00 | by 12:00 | Brood economy lost by 12:00 | push out | won / lost / none |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    groups = {}
    for g in gs:
        groups.setdefault((g["cw"], g["foe"]), []).append(g)
    for (cw, fo), lst in sorted(groups.items()):
        n = len(lst)

        def av(k, f):
            return sum(x["marks"].get(k, x["end"]).get(f, 0) for x in lst) / n
        econ = sum(sum(x["marks"].get("720", x["end"])["brood_lost"][k] for k in ["rootmaw", "mound_turtle"]) for x in lst) / n
        grubs = sum(x["marks"].get("720", x["end"])["brood_lost"]["grub"] for x in lst) / n
        pushes = [x["ms"].get("push") for x in lst if x["ms"].get("push") is not None]
        won = sum(1 for x in lst if x["winner"] == "clockwork")
        lost = sum(1 for x in lst if x["winner"] not in ("clockwork", "none"))
        print("| %s | %s | %d | %.1f | %d | %d | %d / %d | %d / %d | %s | %s | %d / %d / %d |" % (
            NAMES.get(cw, cw), fo.title(), n, av("480", "cw_workers"), av("480", "cw_earned"), av("600", "cw_earned"),
            av("600", "cw_killed"), av("600", "cw_lost"), av("720", "cw_killed"), av("720", "cw_lost"),
            ("%.1f Rootmaws/turtles, %.1f grubs" % (econ, grubs)) if fo == "brood" else "-",
            (mmss(sum(pushes) / len(pushes)) + " (%d of %d)" % (len(pushes), n)) if pushes else "never",
            won, lost, n - won - lost))


if __name__ == "__main__":
    main()
