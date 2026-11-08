#!/bin/bash
# qa-perf (0.33.8): a computer game to 15:00 on EVERY map with tools/perf_bench.gd (docs/qa_2026_11_08_perf.md).
#   tools/qa/perf_matrix.sh <tag> [jobs:1] [minutes:15] [only:<map>,<map>...] [mobile]
# Each run's minute table goes to docs/perf/qa/<tag>/<map>.csv (+ .md), its printout to /tmp/perf_<tag>/<map>.txt.
set -u
TAG=${1:?tag}; shift
JOBS=1; MIN=15; ONLY=""; EXTRA=""
for a in "$@"; do
	case $a in
		jobs:*) JOBS=${a#jobs:};;
		minutes:*) MIN=${a#minutes:};;
		only:*) ONLY=${a#only:};;
		mobile) EXTRA="$EXTRA mobile";;
	esac
done
cd "$(dirname "$0")/../.."
LOG=/tmp/perf_$TAG; mkdir -p "$LOG"
# map | factions (the first half against the second half on team maps)
RUNS=(
"greenhold crown brood" "highmoor crown clockwork" "dune_sea brood clockwork" "frostfang crown crown"
"twin_fords brood brood" "ashfall clockwork clockwork" "mirewood brood crown" "border_march clockwork crown"
"red_coast clockwork brood"
"ashford_crossing crown brood" "kestrel_rise crown clockwork" "thornwood_maze brood clockwork" "redrock_canyon crown crown"
"saltmarsh_isles brood brood" "glimmerdeep clockwork clockwork" "frostmere brood crown" "cinder_steps clockwork crown"
"hollowfen clockwork brood" "amberfall_vale crown brood"
"twin_crowns crown brood clockwork crown 2v2" "jade_wilds brood clockwork crown brood 2v2" "shattered_coast clockwork crown brood clockwork 2v2"
"ember_reach crown clockwork brood crown 2v2" "whitecap_pass brood crown clockwork brood 2v2"
"kingsfield crown brood clockwork clockwork crown brood 2v2" "pinewall_marches brood clockwork crown crown brood clockwork 2v2"
"sundered_realm crown brood clockwork crown brood clockwork crown clockwork 2v2"
)
run_one() {
	local r=$1; local map=${r%% *}
	timeout 5400 godot --headless --path . --fixed-fps 60 --script res://tools/perf_bench.gd -- $r minutes:$MIN spike:60 out:qa/$TAG/$map $EXTRA > "$LOG/$map.txt" 2>&1
	echo "$(date +%H:%M:%S) done $map ($(grep -c 'PERF min' "$LOG/$map.txt") minutes)"
}
n=0
for r in "${RUNS[@]}"; do
	map=${r%% *}
	if [ -n "$ONLY" ] && [[ ",$ONLY," != *",$map,"* ]]; then continue; fi
	run_one "$r" &
	n=$((n+1))
	if [ $((n % JOBS)) -eq 0 ]; then wait; fi
done
wait
