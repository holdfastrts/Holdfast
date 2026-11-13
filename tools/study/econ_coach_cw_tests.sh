#!/bin/bash
# The AI tests and the Clockwork's tests (econ-coach-clockwork, docs/econ-coach-clockwork.md), P at a time, each in its own
# process and user folder, 30 minutes at most; one line a test in OUT/verdicts.txt (PASS / FAIL / NO VERDICT / ERROR).
#   tools/study/econ_coach_cw_tests.sh OUT [P] [extra game args, e.g. cwmacro:off]
cd "$(dirname "$0")/../.."
OUT=${1:-/tmp/cw_tests}
P=${2:-2}
shift 2 2>/dev/null
EXTRA="$*"
GODOT=${GODOT:-godot}
mkdir -p "$OUT"
TESTS=$(ls tools/test_ai_*.gd tools/test_clockwork_*.gd tools/test_cw_ai.gd tools/test_cw_air_ai.gd tools/test_cw_army.gd \
	tools/test_cw_raid_leash.gd tools/test_cw_tier2.gd tools/test_cw_tier3_ai.gd tools/test_clock_ai_swarm.gd \
	tools/test_clock_hall_spot.gd tools/test_gear_ai.gd tools/test_gear_econ.gd tools/test_cw_builders_share.gd \
	tools/test_cw_crate_build.gd tools/test_exhaust.gd 2>/dev/null | grep -v test_clockwork_sounds)
run_one() {
	local t=$1 n
	n=$(basename "$t" .gd)
	[ -s "$OUT/$n.log" ] && return 0
	mkdir -p "$OUT/home_$n"
	XDG_DATA_HOME="$OUT/home_$n" timeout 1800 "$GODOT" --headless --fixed-fps 30 --script "res://$t" -- $EXTRA > "$OUT/$n.log" 2>&1
	local rc=$? v
	if grep -q "SCRIPT ERROR" "$OUT/$n.log"; then v="ERROR"
	elif grep -q -E "^FAIL|RESULT: FAIL|FAILED|^ *FAIL " "$OUT/$n.log"; then v="FAIL"
	elif grep -q -E "PASS" "$OUT/$n.log"; then v="PASS"
	else v="NO VERDICT (rc $rc)"; fi
	echo "$n $v" >> "$OUT/verdicts.txt"
	rm -rf "$OUT/home_$n"
	echo "done $n $v $(date +%H:%M:%S)"
}
export -f run_one
export OUT GODOT EXTRA
printf '%s\n' $TESTS | xargs -P "$P" -I{} bash -c 'run_one "$@"' _ {}
