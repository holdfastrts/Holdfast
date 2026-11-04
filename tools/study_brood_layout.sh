#!/bin/bash
# The base-layout study (docs/brood_layout.md): every line of tools/study_brood_layout.list (or LIST=file), before and after the fix,
# two games at a time. OUT=/abs/dir [JOBS=2] [END=600] [SHOTS=1] [OFFS="0" (after only)] [LIST=file] tools/study_brood_layout.sh
OUT=${OUT:-/tmp/brood_layout}
JOBS=${JOBS:-2}
END=${END:-600}
SHOTS=${SHOTS:-0}
mkdir -p "$OUT"
cd "$(dirname "$0")/.."
run() {
	local map=$1 bs=$2 foe=$3 fs=$4 seed=$5 off=$6
	local pre=""
	[ "$SHOTS" = "1" ] && pre="xvfb-run -a"
	$pre timeout 3000 godot --headless --fixed-fps 30 $([ "$SHOTS" = "1" ] && echo "--rendering-driver opengl3 --resolution 1280x720") \
		--script res://tools/study_brood_layout.gd -- map:$map bs:$bs foe:$foe fs:$fs seed:$seed end:$END out:$OUT off:$off shots:$SHOTS \
		> "$OUT/run_${map}_${bs}_${foe}_${seed}_${off}.log" 2>&1
}
export -f run
export OUT END SHOTS
grep -v "^#" "${LIST:-tools/study_brood_layout.list}" | grep . | while read map bs foe fs seed; do
	for off in ${OFFS:-1 0}; do echo "$map $bs $foe $fs $seed $off"; done
done | xargs -P "$JOBS" -L 1 bash -c 'run $0 $1 $2 $3 $4 $5'
cat "$OUT/summary.txt"
