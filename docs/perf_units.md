# Big battles: the units' own work (0.26.12, branch perf-units)

The owner: "Game is lagging with many units on screen even in skirmish."
docs/perf_smoke.md (0.26.9) showed the units' 30-a-second tick is 50 to 70% of the game's script time in his phone logs.
This pass looked inside that tick and at the spikes around it, and changed only what keeps the game EXACTLY the same.

## The short answer

- The game plays out exactly the same. Whole-state traces (every unit's place, health and order, every game second) are
  byte-identical before and after in all eight stress scenarios, and in three 7-minute computer matches.
- The fog of war's update (4 times a second) is 15 to 45% lighter on average, and its spikes are mostly smaller.
- The command card of a big selected army (2 to 7 ms a build, 4 times a second) is now built on a frame WITHOUT a game
  tick, so it no longer stacks on top of a tick's frame.
- The units' tick itself: no change that stands out from the measuring noise (about 1% on average). That is the honest
  result: its cost is spread thin over
  hundreds of small checks, and the big pieces left (pushing neighbours apart, chasing, the pictures) can only get
  much cheaper by changing what the game does. Those options are listed at the end for the owner to choose from.

## Where a unit's tick goes (measured)

Timers put inside Unit._tick_unit for the measurement (removed afterwards), in a 600-Raptor melee:

| part of the tick | share |
|---|---|
| its order (attack-move, chasing, the attack itself: _engage, line checks) | about 22% |
| pushing neighbours apart (Game.separation, every 2nd or 3rd tick) | about 15% |
| moving (terrain, rails, gates: the rest of _move) | about 12% |
| its pictures and its redraw check (_animate, _set_anim, the draw key) | about 17% |
| the Brood's speed (research, the swamp) | about 7% |
| everything else (timers, weapons, the many small kind checks) | about 27%, in many small pieces |

In the 120-unit mixed battle (60 Musketeers v 60 Raptors) the order and the move are again the biggest, then the
pictures. The script profiler (tools/gd_script_profiler.py) agrees on the order of the costs but overstates small
functions (it adds about 2 microseconds to every call).

## What changed

1. The fog of war (Game._update_vis). Every unit's sight disk was stamped cell by cell (a 9-tile sight is about 250
   cells); in a crowd the disks overlap almost wholly. Now each disk goes in as its rows (one run of cells per row),
   each side's runs are sorted and merged, and every cell is set once. Setting a seen cell twice is setting it once,
   so the result is the same cells. A disk seen from low ground with high ground near it (where the far cells up a
   cliff stay hidden) still goes the old way; a summed-area table of the high ground answers "any high ground near?"
   in four look-ups. The spectator's explored maps go the old way too. Checked: both ways side by side on every
   fog update of a stress battle and of a 5-minute Greenhold match: the same seen, side, explored and fog-picture grids.
2. The command card (hud.gd _tick_hud). Its timed rebuild (4 a second) waits for a frame without a game tick (one
   frame later at most; after a click, a key or a touch it is still built at once). The game state doesn't change
   between ticks, so the card is the same. On a device where every frame has a tick it is built anyway.
3. Pictures: a sprite's frame, position, scale, texture, frame count and offset are only set when they change. In
   Godot each of these setters updates the drawing even for the same value (and the texture setter signals the
   veteran and horse masks). On a phone that is renderer work for nothing. The animation's frames-per-second table is
   only looked through for a pose in it (a walk looked through all 53 names every step).
4. Pushing neighbours apart: what it asks of the unit itself (its horse, its crew, the Line roster switch) and what
   it asks of a neighbour more than once (its side, its kind, its crew) are read once. Same values, same order.
5. The tick: a few plain questions asked as their fields (deploys, can_roll, is_worker), the Brood's swamp check
   written out, a ready weapon's reload bar worked out without the call.
6. The Brood's research speed bonus (PACK HUNT and the like), asked by every Brood creature every tick: kept per side
   and kind while the side's research is unchanged (research is only ever added). The Brood's overlay check skips
   the units that root, morph or keep no spot without building a list for each.

## The numbers (paired runs)

The machine was shared with other jobs all the time (2 cores, load 4 to 9), so a single run means little: two runs of
the same code an hour apart differ by up to 3 times. Every "before" and "after" below ran AT THE SAME MOMENT: the
merged main of 0.26.11 (a copy of the project) and this branch. 20 seconds of play each, headless (the game's side:
simulation and the scripts that prepare the drawing).

The final code (second pair of runs):

| scenario | | fps avg | 1% low fps | worst frame ms | units ms/tick | game ms/tick | fog ms/tick | fog most in a frame | card build most in a frame | hud/look most | cpu s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| mixed | before | 126.0 | 25.7 | 50.6 | 10.60 | 1.21 | 0.41 | 15.2 | 13.2 | 13.5 | 4.4 |
|  | after | 118.1 | 26.8 | 40.7 | 11.34 | 1.21 | 0.32 | 9.9 | 9.8 | 12.7 | 4.3 |
| clockbrood | before | 122.8 | 17.4 | 74.3 | 10.89 | 0.97 | 0.39 | 13.6 | 13.0 | 13.3 | 4.8 |
|  | after | 131.1 | 18.5 | 75.5 | 10.36 | 0.81 | 0.25 | 17.2 | 37.3 | 37.7 | 4.8 |
| melee | before | 68.4 | 8.2 | 169.5 | 21.34 | 1.60 | 0.37 | 21.0 | 12.1 | 12.7 | 8.2 |
|  | after | 70.9 | 9.0 | 135.3 | 20.95 | 1.48 | 0.21 | 6.0 | 16.0 | 16.6 | 8.2 |
| muskets | before | 82.2 | 19.2 | 68.5 | 16.53 | 1.75 | 0.50 | 14.3 | 9.7 | 13.9 | 7.3 |
|  | after | 82.7 | 18.2 | 87.5 | 16.33 | 1.83 | 0.43 | 9.5 | 10.2 | 10.8 | 7.2 |
| offmelee | before | 88.0 | 11.8 | 149.9 | 16.26 | 1.45 | 0.34 | 9.9 | 11.7 | 12.3 | 6.8 |
|  | after | 86.0 | 11.5 | 142.2 | 16.86 | 1.44 | 0.23 | 9.3 | 14.7 | 15.6 | 6.9 |
| idle | before | 71.8 | 18.8 | 60.6 | 18.59 | 2.51 | 0.77 | 22.1 | 15.3 | 15.7 | 8.5 |
|  | after | 74.9 | 20.1 | 54.7 | 17.86 | 2.08 | 0.48 | 10.1 | 15.4 | 15.9 | 8.3 |
| walk | before | 57.9 | 12.1 | 97.1 | 25.78 | 2.57 | 0.72 | 23.2 | 18.8 | 20.3 | 12.9 |
|  | after | 55.6 | 10.3 | 119.9 | 26.96 | 2.58 | 0.65 | 19.5 | 26.4 | 27.0 | 13.0 |
| grubs | before | 28.5 | 5.6 | 254.7 | 54.94 | 3.65 | 0.69 | 18.6 | 16.3 | 23.3 | 19.1 |
|  | after | 28.9 | 5.8 | 206.3 | 54.67 | 3.34 | 0.51 | 10.7 | 15.6 | 16.3 | 19.0 |

The first pair of runs (the same code without item 6):

| scenario | | fps avg | 1% low fps | worst frame ms | units ms/tick | game ms/tick | fog ms/tick | fog most in a frame | card build most in a frame | hud/look most | cpu s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| mixed | before | 194.1 | 29.7 | 45.3 | 7.03 | 0.77 | 0.22 | 10.2 | 6.9 | 7.2 | 4.1 |
|  | after | 183.9 | 27.1 | 50.0 | 7.42 | 0.69 | 0.22 | 7.6 | 5.7 | 6.4 | 4.1 |
| clockbrood | before | 209.3 | 26.7 | 43.4 | 6.50 | 0.58 | 0.23 | 10.5 | 5.3 | 5.6 | 4.5 |
|  | after | 205.1 | 25.2 | 50.5 | 6.69 | 0.53 | 0.17 | 5.6 | 6.3 | 8.5 | 4.4 |
| melee | before | 48.5 | 7.0 | 169.5 | 30.02 | 2.28 | 0.52 | 18.1 | 24.5 | 25.0 | 8.1 |
|  | after | 48.9 | 7.2 | 173.5 | 29.84 | 2.24 | 0.38 | 23.1 | 25.2 | 25.8 | 8.1 |
| muskets | before | 51.1 | 13.0 | 97.5 | 26.72 | 2.78 | 0.74 | 17.9 | 13.7 | 14.4 | 7.1 |
|  | after | 50.5 | 12.4 | 105.1 | 27.01 | 2.85 | 0.71 | 14.8 | 17.3 | 17.5 | 7.2 |
| offmelee | before | 52.8 | 8.0 | 173.7 | 27.01 | 2.53 | 0.55 | 16.2 | 14.5 | 26.4 | 6.9 |
|  | after | 54.3 | 8.5 | 150.2 | 26.34 | 2.02 | 0.41 | 13.3 | 17.3 | 23.4 | 6.8 |
| idle | before | 43.3 | 13.7 | 102.6 | 31.04 | 3.93 | 1.13 | 25.5 | 16.6 | 23.3 | 8.6 |
|  | after | 45.0 | 13.2 | 104.1 | 29.46 | 3.40 | 0.91 | 15.8 | 23.2 | 25.4 | 8.2 |
| walk | before | 28.6 | 8.4 | 147.6 | 52.33 | 4.85 | 1.31 | 27.9 | 21.9 | 22.5 | 14.2 |
|  | after | 29.7 | 9.2 | 130.1 | 49.79 | 4.79 | 1.06 | 25.5 | 19.6 | 28.6 | 13.7 |
| grubs | before | 19.3 | 4.3 | 312.4 | 80.29 | 5.61 | 0.95 | 23.6 | 35.3 | 36.2 | 20.6 |
|  | after | 19.6 | 4.4 | 287.9 | 78.93 | 5.15 | 0.74 | 14.3 | 39.0 | 39.8 | 20.2 |

What the two pairs say together:

- The fog: lighter in every scenario of the final pair, 15 to 45% per tick on average (0.77 to 0.48 ms with 400 Raptors
  standing, 0.37 to 0.21 in the 600-Raptor melee), and the most it took in one frame went down in 6 of 8
  (22 to 10 ms idle, 21 to 6 melee, 19 to 11 grubs).
- The units' tick: no change that stands out from the noise. Between the two pairs the same scenario moved by -5% to
  +7% either way; on average about 1% lighter. The changes made are real but small next to the whole tick.
- The command card: the build itself costs the same; it now lands on frames without a game tick (the worst frames
  are tick frames). The "most in a frame" column is the build's own cost, and on this shared machine it wanders.
- Frames a second and the worst frame: within the noise, as the units' tick dominates them.

- "units ms a tick": the units' own ticks. "fog": the fog update, per tick on average, and the most it took in one
  frame. "card": the command card's build, the most in one frame (the same build; what changed is which frame it lands on).
- Scenarios: mixed = 60 Musketeers v 60 Raptors; clockbrood = 80 Clockwork (64 Clock Soldiers, 16 Springers) v 80 Brood
  (60 Raptors, 20 Spitters), new in tools/stress_swarm.gd; the others are docs/swarm_perf.md's (200 a side, grubs 300 a side).

## The game plays out the same

- tools/stress_swarm.gd trace:FILE, before and after, byte-identical: mixed, clockbrood, melee, muskets, offmelee,
  idle, walk, grubs (each 20 s, every game second).
- tools/perf_bench.gd trace, before and after, identical over 7 minutes: Greenhold Crown v Brood, Ashford Crossing
  Clockwork v Crown, Kestrel Rise Brood v Clockwork.
- tools/test_wall_stuck.gd: PASS. tools/test_pathing.gd: the same 3 failures as main (rim_click_from_low/brood on
  Greenhold, Kestrel Rise, Frostmere: 10 of 11 arrive). tools/test_ai_harass.gd: passes, or fails "[raid] the riders
  ride home" now and then; main does the same (the test goes by the clock).
- Seen on the way, not from this work (main does it too): on Kestrel Rise with the Brood as player 1 the computer
  throws a script error every tick in AI._hall_first (scripts/ai.gd:2315) and AI._hall_keep (2401): a Dictionary
  indexed with a String, the Brood having no hall building. It floods the log (1 MB in 7 minutes).

## What is left, and the owner's options

These would make big battles much cheaper, but each changes what the game does a little (so the traces would differ),
which is why they are not in this pass:

- Push neighbours apart less often in a big crowd (every 3rd tick for walkers too, every 4th or 5th for standing men):
  about a third of the separation cost. Units would jostle a touch more softly.
- A chasing melee unit looks for its own side of the target (two line checks every tick) only every few ticks.
- Target scans staggered further in a big battle (now every 0.3 to 0.35 s).
- Pictures of units far from the camera's centre stepped less often (the frames keep their pace).
- Capping game ticks per frame on a slow device (docs/perf_smoke.md): the game slows down instead of stuttering.
- The replay's picture (2 to 20 ms with 120 to 600 units, 3 to 5 a second, already on frames without a tick): its
  packing could be done on the next frame. Not done: the replay tests compare the match with the replay right at the
  picture.
- A unit strip's first use loads its texture from disk mid-battle (a one-off spike of up to a few hundred ms on a slow
  machine when a new kind first attacks or dies): loading every unit strip at the start would remove it.

## How to measure again

- `tools/stress_swarm.sh <outdir> [scenarios...]`, or one run:
  `godot --headless --fixed-fps 60 --script res://tools/stress_swarm.gd -- clockbrood n:160 secs:20 trace:/abs/t.txt`
- Before/after must run at the same moment on a shared machine (a copy of the old code beside the new).
