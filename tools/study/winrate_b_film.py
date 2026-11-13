#!/usr/bin/env python3
"""A film's numbers (job winrate-b): tools/shot_ai_match.gd's stats.txt as a table every N seconds, plus the AI STORY's
waves, reads and losses, for the coach's notes.
    python3 tools/study/winrate_b_film.py FILM_DIR [--every 60] [--story]"""
import os, sys, re

d = sys.argv[1]
every = int(sys.argv[sys.argv.index("--every") + 1]) if "--every" in sys.argv else 60
rows = {}
for l in open(os.path.join(d, "stats.txt")):
    m = re.match(r"(\d\d)(\d\d) (P\d) (\w+) (\w+) income (\d+) bank (\d+) workers (\d+) army (\d+) \((.*?)\) rooted (\d+) "
                 r"halls (\d+) supply (\d+)/(\d+) lost (\d+) bld_lost (\d+) at \(([-\d.]+), ([-\d.]+)\)(.*)", l)
    if not m:
        continue
    t = int(m.group(1)) * 60 + int(m.group(2))
    rows.setdefault(t, {})[m.group(3)] = m
print("| clock | side | plan | income | bank | workers | army | army kinds | halls | supply | units lost | buildings lost |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|")
nxt = 0
for t in sorted(rows):
    if t < nxt and t != max(rows):
        continue
    nxt = (t // every + 1) * every
    for p in sorted(rows[t]):
        m = rows[t][p]
        kinds = m.group(10).replace('"', "").replace(" ", "")
        print("| %d:%02d | %s %s | %s | %s | %s | %s | %s | %s | %s | %s/%s | %s | %s |" % (
            t // 60, t % 60, p, m.group(4), m.group(5), m.group(6), m.group(7), m.group(8), m.group(9), kinds,
            m.group(12), m.group(13), m.group(14), m.group(15), m.group(16)))
if "--story" in sys.argv and os.path.exists(os.path.join(d, "story.txt")):
    print()
    keys = re.compile(r"reads|picks|switch|attack|wave|pulls back|falls back|lost|is out|beaten|hunts|counter|push|"
                      r"retreat|breaks|holds|moves house|recall", re.I)
    for l in open(os.path.join(d, "story.txt")):
        if keys.search(l):
            print(l.rstrip())
