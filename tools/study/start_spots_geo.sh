#!/bin/bash
# START SPOTS geometry sweep (docs/start_spots_study.md): tools/start_spots_geo.gd on every 2-player map, a few seeds,
# the Crown and the Clockwork (their starting buildings), and the named maps with swap:1 too. Measuring only.
#   tools/study/start_spots_geo.sh OUTDIR
OUT=${1:-docs/start_spots_study/geo}
mkdir -p "$OUT"
MAPS="greenhold highmoor dune_sea frostfang twin_fords ashfall mirewood border_march red_coast ashford_crossing kestrel_rise thornwood_maze redrock_canyon saltmarsh_isles glimmerdeep frostmere cinder_steps hollowfen amberfall_vale"
for m in $MAPS; do
  for s in 2300 2341; do
    for f in crown clockwork; do
      fn="$OUT/${m}_${s}_${f}.json"
      [ -f "$fn" ] || timeout 200 ${GODOT:-godot} --headless --fixed-fps 30 --script res://tools/start_spots_geo.gd -- map:$m seed:$s fac:$f out:$(realpath -m "$fn") > /dev/null 2>&1
    done
  done
done
