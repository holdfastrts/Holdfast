#!/bin/bash
# (winrate-a) film one Crown game: winrate_film.sh NAME OPPONENT MAP SEED SWAP (swap:1 = the Crown at P2)
# out: /tmp/claude-0/film/NAME (stills every 30 s, coach.txt, story.txt, stats.txt)
cd /home/claude/holdfast
d=/tmp/claude-0/film/$1
date +%s > $d/start.txt
mkdir -p $d
timeout 5400 xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --path . --script res://tools/shot_ai_match.gd -- a:crown b:$2 pa:optimal pb:optimal map:$3 seed:$4 swap:$5 out:$d coach:1 every:30 end:900 > $d/run.out 2>&1
date +%s > $d/end.txt
