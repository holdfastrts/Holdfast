#!/bin/bash
# THE ARMY PERF CHECK (docs/perf_armies.md): the game's work a tick with 200 units fighting, headless, and whether it got
# much slower than the last time it was set.
#   tools/test_perf_armies.sh [update] [secs:20]
# Two battles of 200 units in view (tools/stress_swarm.gd): melee (100 Raptors a side) and clockbrood (100 Clock Soldiers
# and Springers against 100 Raptors and Spitters). Each prints the units' and the whole game's ms a tick. The machine's
# speed is measured too (tools/perf_calib.gd: a fixed piece of GDScript), and the check compares the game's ms a tick
# divided by it with tools/perf_armies_baseline.json: more than LIMIT times the baseline is a FAIL (the exit code is 1).
# "update" writes this run's numbers as the new baseline (after a change that is meant to cost more, or to save).
# A machine busy with other work makes the numbers worse: run it on a quiet machine, and run it again before believing a FAIL.
set -u
cd "$(dirname "$0")/.."
UPDATE=0; SECS="secs:20"
for a in "$@"; do
	case $a in
		update) UPDATE=1;;
		secs:*) SECS=$a;;
	esac
done
OUT=$(mktemp -d)
CAL=$(timeout 300 godot --headless --path . --script res://tools/perf_calib.gd 2>&1 | grep -E "^CALIB" | awk '{print $2}')
for run in "melee n:100" "clockbrood n:200"; do
	set -- $run
	timeout 1800 godot --headless --path . --fixed-fps 60 --script res://tools/stress_swarm.gd -- $1 $2 $SECS out:"$OUT/$1.json" 2>&1 | grep -E "^SWARM $1|SCRIPT ERROR" | cut -c1-240
done
CAL2=$(timeout 300 godot --headless --path . --script res://tools/perf_calib.gd 2>&1 | grep -E "^CALIB" | awk '{print $2}')
python3 - "$OUT" "$CAL" "$CAL2" "$UPDATE" <<'PY'
import json, sys, os
out, cal1, cal2, update = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
LIMIT = 1.35
try:
	cal = min(float(cal1), float(cal2))
except ValueError:
	print("PERF CHECK: could not time the machine (tools/perf_calib.gd)"); sys.exit(1)
base_path = "tools/perf_armies_baseline.json"
base = json.load(open(base_path)) if os.path.exists(base_path) else {}
now = {"calib_ms": cal}
fail = False
print("PERF CHECK machine: %.2f ms for the fixed GDScript work (a smaller number is a faster machine)" % cal)
for s in ["melee", "clockbrood"]:
	p = os.path.join(out, s + ".json")
	if not os.path.exists(p):
		print("PERF CHECK %s: no result (the run failed)" % s); fail = True; continue
	r = json.load(open(p))
	sim = r["sim_ms_per_tick"]; units = r["ms/tick units"]
	ratio = sim / cal
	now[s] = {"sim_ms_per_tick": sim, "units_ms_per_tick": units, "ratio": ratio, "fps": r["fps"], "low1_fps": r["low1_fps"]}
	line = "PERF CHECK %s, 200 units: the game's work %.2f ms a tick (units %.2f), %.1f fps, 1%% low %.1f fps, %.2f machine units" % (s, sim, units, r["fps"], r["low1_fps"], ratio)
	if s in base:
		b = base[s]["ratio"]
		verdict = "OK" if ratio <= b * LIMIT else "FAIL"
		if verdict == "FAIL":
			fail = True
		line += " | baseline %.2f: %s (x%.2f)" % (b, verdict, ratio / b)
	print(line)
if update:
	json.dump(now, open(base_path, "w"), indent=1)
	print("PERF CHECK baseline written: " + base_path)
print("PERF CHECK " + ("FAIL" if fail else "PASS"))
sys.exit(1 if fail else 0)
PY
rc=$?
rm -rf "$OUT"
exit $rc
