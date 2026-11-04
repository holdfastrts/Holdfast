#!/bin/bash
# Every case of tools/test_brood_layout.gd (docs/brood_layout.md): the rule on two maps, the opening on the five study
# maps, the alarm. Writes OUT/<case>.txt (OUT=/tmp/test_brood_layout by default) and prints each result line.
OUT=${OUT:-/tmp/test_brood_layout}
mkdir -p "$OUT"
cd "$(dirname "$0")/.."
one() {
	timeout 2400 godot --headless --fixed-fps 30 --script res://tools/test_brood_layout.gd -- "$@" > "$OUT/$(echo "$@" | tr ' :' '__').txt" 2>&1
	grep -E "^(PASS|FAIL)|ALL PASS|FAILED" "$OUT/$(echo "$@" | tr ' :' '__').txt"
}
one case:rule map:greenhold
one case:rule map:redrock_canyon
for m in highmoor redrock_canyon thornwood_maze greenhold cinder_steps; do
	one case:opening map:$m bs:economy foe:crown
done
one case:opening map:redrock_canyon bs:spitter foe:clockwork seed:5 end:600
one case:opening map:cinder_steps bs:economy foe:crown fs:economy seed:11 end:600
one case:alarm
