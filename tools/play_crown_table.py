#!/usr/bin/env python3
"""The coached games of tools/play_crown_1.gd as a table (docs/ai_crown_rebuild.md): one line a game from its folder's
minutes.txt, events.txt, result.txt and the command line in <dir>.out next to it.
    python3 -I tools/play_crown_table.py ROUND_DIR      (every game folder in it, e.g. /tmp/film/A)"""
import os
import re
import sys


def mm(s):
    return "%d:%s" % (int(s[:2]), s[2:])


def game(d, name):
    path = os.path.join(d, name)
    args = ""
    if os.path.exists(path + ".out"):
        for line in open(path + ".out", errors="replace"):
            if line.startswith("COACH plan"):
                args = line.strip()
                break
    mins = {}
    for line in open(os.path.join(path, "minutes.txt")):
        m = re.match(r"(\d{4}) labourers (\d+).*?earned this minute (\d+) gold.*?\| army (\d+) .*?\| enemy army (\d+) .*?killed (\d+) lost (\d+)", line)
        if m:
            mins[int(m.group(1)[:2])] = m.groups()
    ev = open(os.path.join(path, "events.txt")).read()
    res = open(os.path.join(path, "result.txt")).read().split()
    over, winner, clock = res[1] == "true", res[3], float(res[5])
    result = ("W" if winner == "0" else "L") + " %d:%02d" % (int(clock) // 60, int(clock) % 60) if over else "alive at %d:%02d" % (int(clock) // 60, int(clock) % 60)
    log = open(os.path.join(path, "log.txt")).read() if os.path.exists(os.path.join(path, "log.txt")) else ""
    hm = re.search(r"\[(\d\d):(\d\d)\] P1 Crown is expanding", log)
    att = re.search(r"(\d{4}) the first attack goes out \((\d+) supply\)", ev)
    opened = re.search(r"opening over: (.*)", ev)

    def at(minute, i):
        return mins[minute][i] if minute in mins else "-"
    last = mins[max(mins)] if mins else None
    return "| %s | %s | %s | %s/%s/%s | %s/%s | %s/%s | %s | %s | %s | %s | %s | %s |" % (
        name, args.replace("COACH plan ", ""), result, at(4, 1), at(6, 1), at(8, 1), at(6, 2), at(8, 2), at(6, 3), at(8, 3),
        at(8, 4), ("%d:%s" % (int(hm.group(1)), hm.group(2))) if hm else "-", ("%s (%s)" % (mm(att.group(1)), att.group(2))) if att else "-",
        ("%s / %s" % (last[5], last[6])) if last else "-", (opened.group(1)[:60] if opened else "-"), "")


if __name__ == "__main__":
    d = sys.argv[1]
    print("| game | plan | result | labourers 4/6/8 | earned a minute 6/8 | army 6/8 | enemy army 8 | 2nd hall | 1st attack | killed / lost | opening ended | |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for name in sorted(os.listdir(d)):
        if os.path.isdir(os.path.join(d, name)) and os.path.exists(os.path.join(d, name, "result.txt")):
            print(game(d, name))
