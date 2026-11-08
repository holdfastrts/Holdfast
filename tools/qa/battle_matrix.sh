#!/bin/bash
# qa-perf (0.33.8): the big battles, every faction pairing (mirrors too) at 100 and 200 a side, tools/stress_swarm.gd "pair".
#   tools/qa/battle_matrix.sh <outdir> [render] [mobile] [secs:40] [sizes:100,200]
# Each run: <outdir>/<a>_<b>_<n>[_render][_mobile].json (+ .txt, + .trace: the whole state every game second, so a
# later build can be checked for the same battle with cmp).
set -u
OUT=${1:?outdir}; shift
RENDER=0; MOBILE=""; SECS="secs:40"; SIZES="100 200"; RES="1920x1080"
for a in "$@"; do
	case $a in
		render) RENDER=1;;
		mobile) MOBILE=mobile;;
		secs:*) SECS=$a;;
		sizes:*) SIZES=${a#sizes:}; SIZES=${SIZES//,/ };;
		res:*) RES=${a#res:};;
	esac
done
mkdir -p "$OUT"
cd "$(dirname "$0")/../.."
for n in $SIZES; do
for p in "crown crown" "brood brood" "clockwork clockwork" "crown brood" "crown clockwork" "brood clockwork"; do
	set -- $p
	tag=${1}_${2}_$n
	[ $RENDER = 1 ] && tag=${tag}_render_$RES
	[ -n "$MOBILE" ] && tag=${tag}_mobile
	args="pair a:$1 b:$2 n:$n $SECS $MOBILE out:$OUT/$tag.json"
	if [ $RENDER = 1 ]; then
		timeout 2400 xvfb-run -a -s "-screen 0 ${RES}x24" godot --path . --rendering-driver opengl3 --resolution $RES --fixed-fps 60 \
			--script res://tools/stress_swarm.gd -- $args shot:$OUT/$tag.png > $OUT/$tag.txt 2>&1
	else
		timeout 2400 godot --headless --path . --fixed-fps 60 --script res://tools/stress_swarm.gd -- $args trace:$OUT/$tag.trace > $OUT/$tag.txt 2>&1
	fi
	echo "$(date +%H:%M:%S) $tag: $(grep -E '^SWARM pair' $OUT/$tag.txt | head -c 300)"
done
done
