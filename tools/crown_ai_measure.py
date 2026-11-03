#!/usr/bin/env python3
"""THE CROWN'S OWN COMPUTER, measured (docs/ai_crown_rebuild.md): headless study games (tools/study/study_game.gd), the
Crown in slot 0, and a table of what matters: labourers, gold earned and army at 4/6/8 min, the second hall, the first
Horseman, the first attack, the result. Games run two at a time.
    python3 -I tools/crown_ai_measure.py OUT_DIR run NAME "pa:economy b:brood pb:timing map:red_coast seed:4291306512" [end:720] [extra args...]
    python3 -I tools/crown_ai_measure.py OUT_DIR table      (every game in OUT_DIR, one line each)
A run's extra arguments go to the game as they are (crownnew:off plays the 0.27.2 computer, open0:mill fixes its opening)."""
import csv
import json
import os
import re
import subprocess
import sys


def run(out, name, args):
    os.makedirs(out, exist_ok=True)
    cmd = ["godot", "--headless", "--fixed-fps", "30", "--script", "res://tools/study/study_game.gd", "--", "a:crown", "fast:1",
           "out:" + out, "id:" + name] + args
    if not any(a.startswith("end:") for a in args):
        cmd.append("end:720")
    with open(os.path.join(out, name + ".cmd"), "w") as f:
        f.write(" ".join(cmd) + "\n")
    with open(os.path.join(out, name + ".out"), "w") as f:
        subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, timeout=1800)


def mmss(t):
    return "-" if t is None else "%d:%02d" % (int(t) // 60, int(t) % 60)


def first(log, pat):
    for line in log:
        m = re.match(r"\[(\d+):(\d+)\] (.*)", line)
        if m and re.search(pat, m.group(3)):
            return int(m.group(1)) * 60 + int(m.group(2))
    return None


def row(out, name):
    g = json.load(open(os.path.join(out, "games", name + ".json")))
    ts = {}
    with open(os.path.join(out, "ts", name + ".csv")) as f:
        for r in csv.reader(f):
            if r and r[0] == name:
                ts[(int(r[1]), int(r[2]))] = r
    log = open(os.path.join(out, "logs", name + ".log")).read().splitlines()

    def at(t, col, team=0):
        r = ts.get((t, team))
        return r[col] if r else "-"
    hall2 = first(log, r"^P1 Crown is expanding")
    horse = first(log, r"^P1 Crown got its first Horseman")
    attack = first(log, r"^P1 Crown's (first attack goes out|wave)")
    musk = first(log, r"^P1 Crown got its first Musketeer")
    res = "%s %s %s" % (g["winner_faction"] or "-", g["cause"], mmss(g["end_t"]))
    cmd = open(os.path.join(out, name + ".cmd")).read()
    return {"name": name, "labs": "/".join(at(t, 11) for t in (240, 360, 480)), "earned": "/".join(at(t, 6) for t in (240, 360, 480)),
            "powder": "/".join(at(t, 7) for t in (240, 360, 480)),
            "army": "/".join(at(t, 13) for t in (240, 360, 480)), "foe": "/".join(at(t, 13, 1) for t in (360, 480)),
            "hall2": mmss(hall2), "musk": mmss(musk), "horse": mmss(horse), "attack": mmss(attack), "result": res,
            "old": "crownnew:off" in cmd}


def table(out):
    names = sorted(f[:-5] for f in os.listdir(os.path.join(out, "games")) if f.endswith(".json"))
    print("| game | labourers 4/6/8 | earned 4/6/8 | powder in 4/6/8 | army 4/6/8 | enemy army 6/8 | 1st Musketeer | 2nd hall | 1st Horseman | 1st attack | result |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    for n in names:
        try:
            r = row(out, n)
        except Exception as e:  # (a game still running)
            continue
        print("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (r["name"], r["labs"], r["earned"], r["powder"], r["army"], r["foe"],
              r["musk"], r["hall2"], r["horse"], r["attack"], r["result"]))


if __name__ == "__main__":
    out = sys.argv[1]
    if sys.argv[2] == "run":
        run(out, sys.argv[3], sys.argv[4].split() + sys.argv[5:])
    else:
        table(out)
