#!/bin/bash
# The Clockwork computer alone (econ-coach-clockwork, docs/econ-coach-clockwork.md): every plan x map x peace given, P at a
# time, through tools/econ_alone_cw.gd; one JSON a run in OUT (<plan>_<map>_<seed>_p<peace>.json).
#   tools/study/econ_alone_cw.sh OUT [P] ["plans"] ["maps"] ["seeds"] ["peace"] [extra game args...]
cd "$(dirname "$0")/../.."
OUT=${1:-/tmp/econ_alone_cw}
P=${2:-2}
PLANS=${3:-"optimal economy balanced"}
MAPS=${4:-"greenhold hollowfen"}
SEEDS=${5:-"1"}
PEACE=${6:-"0"}
shift 6 2>/dev/null
EXTRA="$*"
GODOT=${GODOT:-/home/claude/godot}
mkdir -p "$OUT"
jobs=()
for p in $PLANS; do for m in $MAPS; do for s in $SEEDS; do for q in $PEACE; do
	jobs+=("$p $m $s $q")
done; done; done; done
run_one() {
	set -- $1
	local f="$OUT/${1}_${2}_${3}_p${4}.json"
	[ -s "$f" ] && return 0
	timeout 1800 "$GODOT" --headless --fixed-fps 30 --script res://tools/econ_alone_cw.gd -- plan=$1 map=$2 seed=$3 peace=$4 out="$f" $EXTRA \
		2>&1 | grep -E "SCRIPT ERROR|^ERROR" | head -5 > "$OUT/${1}_${2}_${3}_p${4}.err"
	echo "done $1 $2 $3 p$4 $(date +%H:%M:%S)"
}
export -f run_one
export OUT GODOT EXTRA
printf '%s\n' "${jobs[@]}" | xargs -P "$P" -I{} bash -c 'run_one "$@"' _ {}
