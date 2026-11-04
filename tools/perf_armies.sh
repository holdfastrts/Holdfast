#!/bin/bash
# THE ARMY LADDER (docs/perf_armies.md): the swarm stress scenarios (tools/stress_swarm.gd) at 50, 100, 200 and 300 units,
# headless, and a table of the game's work a tick, frames a second and the 1% lows.
#   tools/perf_armies.sh <outdir> [secs:20] [project:/path/to/a/copy] [render] [scen...]
# scen: melee (Raptors v Raptors in view) and clockbrood (Clock Soldiers and Springers v Raptors and Spitters in view) by
# default. project: run another copy of the game (an older version, for a before/after pair: run both at once, one a core).
set -u
OUT=${1:?outdir}; shift
mkdir -p "$OUT"
SECS="secs:20"; PROJ="$(cd "$(dirname "$0")/.." && pwd)"; RENDER=0; SCENS=()
for a in "$@"; do
	case $a in
		secs:*) SECS=$a;;
		project:*) PROJ=${a#project:};;
		render) RENDER=1;;
		*) SCENS+=("$a");;
	esac
done
[ ${#SCENS[@]} -eq 0 ] && SCENS=(melee clockbrood)
for s in "${SCENS[@]}"; do
	for units in 50 100 200 300; do
		n=$((units / 2))
		[ "$s" = clockbrood ] && n=$units          # (clockbrood's n is both sides together)
		tag=${s}_${units}
		[ $RENDER = 1 ] && tag=${tag}_render
		if [ $RENDER = 1 ]; then
			timeout 1800 xvfb-run -a godot --path "$PROJ" --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 60 \
				--script res://tools/stress_swarm.gd -- $s n:$n $SECS out:"$OUT/$tag.json" 2>&1 | grep -E "^SWARM (melee|clockbrood)|SCRIPT ERROR" | head -c 4000
		else
			timeout 1800 godot --headless --path "$PROJ" --fixed-fps 60 \
				--script res://tools/stress_swarm.gd -- $s n:$n $SECS out:"$OUT/$tag.json" 2>&1 | grep -E "^SWARM (melee|clockbrood)|SCRIPT ERROR" | head -c 4000
		fi
	done
done
python3 - "$OUT" <<'PY'
import json, sys, glob, os
print("| run | units | fps avg | 1% low fps | worst ms | battle fps | game's work ms/tick | units ms/tick | cpu s |")
print("|---|---|---|---|---|---|---|---|---|")
rows = []
for f in glob.glob(sys.argv[1] + "/*.json"):
	r = json.load(open(f)); name = os.path.basename(f)[:-5]
	rows.append((name.split("_")[0], int(name.split("_")[1]), name, r))
for s, u, name, r in sorted(rows):
	bf = 1000.0 / r["fight_avg_ms"] if r.get("fight_avg_ms") else 0
	print("| %s | %d | %.1f | %.1f | %.1f | %.1f | %.2f | %.2f | %.1f |" % (name, u, r["fps"], r["low1_fps"], r["worst_ms"], bf, r["sim_ms_per_tick"], r["ms/tick units"], r["cpu_s"]))
PY
