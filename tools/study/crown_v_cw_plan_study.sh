#!/bin/bash
# (crown-v-cw-plan-study, docs/crown_v_cw_plan_study.md) Hard OPTIMAL Crown v Hard OPTIMAL Clockwork on the 19 two-player
# maps, three ways: default (today's GREEDY_CLOCK weights), greedyclock:economy, greedyclock:balanced. Round 0 of all
# three first (19 games each), then round 1 (the sides swapped); the data is committed and pushed after each block.
#   tools/study/crown_v_cw_plan_study.sh [PUSH=1]
cd "$(dirname "$0")/../.."
D=docs/crown_v_cw_plan_study/data
OUT=${OUT:-/tmp/cvcps_out}
for r in 0 1; do
  for cfg in default economy balanced; do
    extra=()
    [ "$cfg" != default ] && extra=(--extra "greedyclock:$cfg")
    python3 tools/study/qa_matches.py run "$OUT/$cfg" --data "$D/$cfg" --only crcw19r$r --jobs 2 "${extra[@]}"
    if [ "${PUSH:-1}" = 1 ]; then
      git add "$D/$cfg" tools/study && git commit -q -m "WIP crown-v-cw-plan-study: $cfg round $r data ($(ls $D/$cfg | wc -l) games)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01NtmEZhP1uA8k4DLQ7BYfMz" && git push -q origin crown-v-cw-plan-study
    fi
  done
done
echo ALL DONE
