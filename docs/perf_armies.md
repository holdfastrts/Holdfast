# Big armies: the steady cost of a crowd (0.29.5, branch perf-armies)

The owner, 2026-11-03 21:17: "I got a lot of freezes and lag in this game, I think it is because the Brood had a gigantic
army. We need to find a way to make games streamlined: no lag, no stutter, no freezes, run smoothly." And on 2026-10-28:
"200 Raptors a side... not a lag fest."

His log: docs/playtests/2026-11-03/lag_big_brood_army_cinder_steps_clockwork_v_brood_econ_0283.txt (he plays the
Clockwork against a HARD Brood on ECONOMY, Cinder Steps, seed 607822690, on his computer). In its last minute: 32 frames a
second, 1% low 4, worst frame 330 ms, 230 frames over 50 ms; busy with the units 353 ms a second, the Brood computer 126,
paths 30 + 25.

A parallel job (perf-stutter, merged as 0.29.3) took the single long freezes (pictures loaded the first time, the Crown's
wall plan, the tooltip). This job took the steady cost that grows with the army.

## The short answer

- The biggest part of his lag that was not the units themselves was the BROOD COMPUTER. Late in his game it thought for
  90 to 200 ms in one frame, two or three times a second. Almost all of it was one question asked over and over: "where
  could this Rootmaw root?", hundreds of spots, each spot checked against every unit on the map, twice. It now asks the
  same question with the units listed once, and gives the same answers, spot for spot. That made its thinking about five
  times lighter. Its think is also split into four parts on four ticks in a row (as the other computers already did), so
  no single frame carries all of it.
- In the owner's match replayed here (the same map, seed and plans, a Hard computer in his place), the late game went from
  a 1% low of 5 to 10 frames a second to 15 to 30, and from about 100 frames a minute over 50 ms to one or none. The worst
  frames left come from the Clockwork computer's building searches, which his game did not have (he played the
  Clockwork himself).
- The Clockwork computer had two searches that failed every few seconds for minutes in a crowded base: the spot for its
  Heavy Works' kept ring (90 to 180 ms each, every 5 s) and the spot for a new Clocktower (15 to 20 ms on every think).
  After a search finds no room it now waits 20 s (the ring) or 4 s (the hall) before looking again.
- The units' own tick: the game plays out EXACTLY the same, unit for unit, so only changes that keep it so went in:
  paths shared in the path queue, the turning gears' check skipped far from the gears, the Brood's research speed kept on
  each creature, the silhouettes behind buildings read each picture once. Together they are within the measuring noise on
  this machine (about 1 to 5%). The tick of a unit is a few hundred small checks, and none stands out any more. What is
  left can only get much cheaper by changing what the units do (fewer looks for a target, fewer shoves a second for
  units standing still, a lighter tick for an idle army...). Those are listed at the end, with what each would save, for
  the owner to choose.
- New tools: tools/perf_armies.sh (the army ladder: 50, 100, 200 and 300 units), tools/test_perf_armies.sh (the check:
  ms a tick at 200 units against a baseline, scaled by the machine's own speed), tools/perf_calib.gd (that speed).

## 1. Where the time went

Measured with tools/perf_bench.gd on the owner's match: `cinder_steps clockwork brood seed:607822690 strat:economy`
(a Hard Clockwork computer plays his side; 0.29.4 had a merge leftover in perf_bench.gd that stopped it from running at
all: fixed). Headless, 60 frames a second fixed, one core of the cloud machine.

Late in the match (minute 12, 217 units, 0.29.4):

| part | ms a frame | |
|---|---|---|
| the units' tick | 6.4 to 7.4 | 30 ticks a second, about 30 microseconds a unit a tick |
| the computers | 3.3 to 3.8 | the Brood's 3.3 of it |
| the rest of the game (grid, paths, fog) | 0.5 | |

The Brood computer, timed part by part (new: every part of its think has its own line in the match log, `ai/brood/...`):

    PERF spike 252 ms at 10:55: ai/brood 215.7, ai/brood/rootmaws 199.8, units 27.2, ai/brood/lay 5.1, ...
    PERF spike 192 ms at 10:53: ai/brood 167.9, ai/brood/rootmaws 153.1, ...

`rootmaws`: for every Rootmaw packed up and looking for fresh ground, `_nb_find_spot` tries 80 spots round the Mother and
64 round every far Mound Turtle (16 turtles: over 1,000 spots), and for each spot `BroodRoot.place_problem` walked every
unit on the map twice (other creatures' plans, other Rootmaws' circles) and `BroodNew.swamp_coming` a third time. With 350
units that is about two million looks for one Rootmaw, every 0.4 s, for as long as it finds nothing (spent ground all
round: the late game).

The units, by kind and order (timers in every unit's tick while hunting, taken out after):

| | microseconds a tick |
|---|---|
| a grub gathering | 56 (its gathering 21, its move 21) |
| a Raptor attack-moving | 63 (100 with a target) |
| a Winder gathering | 58 |
| a rooted Mound Turtle / Rootmaw | 38 / 48 |
| a Clock Soldier standing | 50 |
| a Brood egg | 13 |

Inside one Raptor's tick, 300 Raptors standing in view (stress_swarm idle): its move and shove 9, its picture's step 7,
its speed (research, swamp, timers) 6 to 10, its order (looking for a target every 0.35 s) 5.5, the turning gears' check
4.5, its draw check 3.8, everything else 2 to 3 a part. Fighting, its order and move are 30 each and its picture 18 (on
screen). No one part is more than a quarter of the tick.

## 2. What was changed

Every change below keeps the game the same, unit for unit, except 2.2 and 2.3 (the computers' own choices of WHEN to
think and to look again; they never see or do anything they couldn't before).

### 2.1 The Brood computer's spot searches list the units once (exact)

- `BroodRoot.batch_begin(game, team)` / `batch_end()`: between them (one search, nothing moves meanwhile) the units that
  can answer are listed once, in the map's order: the side's units with a plan, the open Rootmaws, the rooted Mothers and
  turtles, the side's turtles and Rootmaws. `place_problem` and `swamp_coming` walk those lists instead of every unit, so
  every answer is the same, word for word. Outside a batch nothing changes.
- `_nb_find_spot`, `_nb_turtle_spot`, `_nb_supply_turtle_spot` run inside a batch.
- Two of place_problem's own no's are asked first in the Rootmaw search (off the swamp and not coming; inside another
  Rootmaw's circle): the same no, without the footprint walk.
- A spot whose score can't beat the best so far no longer asks whether an enemy is near (that only adds to its score).
- `_spot_bad` read the bad spots' text back into points for every spot asked: now once per bad spot.
- The same match before and after (main 0.29.4 and this branch, run at the same time): the whole match's state every 5
  game seconds is the same file, line for line (17,810 lines, 12 minutes).

Before and after, the same match (the exact stage of the work, before 2.2), minutes 8 to 12:

| minute | units | fps before | after | 1% low before | after | worst ms before | after | Brood computer ms a frame before | after |
|---|---|---|---|---|---|---|---|---|---|
| 8 | 159 | 141 | 156 | 13.1 | 28.8 | 150 | 56 | 0.82 | 0.30 |
| 9 | 164 | 87 | 105 | 9.7 | 23.0 | 188 | 114 | 1.65 | 0.40 |
| 10 | 192 | 81 | 91 | 9.6 | 22.3 | 161 | 57 | 1.71 | 0.44 |
| 11 | 209 | 68 | 74 | 5.4 | 10.6 | 324 | 364 | 2.67 | 0.60 |
| 12 | 217 | 70 | 81 | 5.6 | 15.3 | 234 | 150 | 3.31 | 0.67 |

(Minute 11's worst frame, both columns, is the Clockwork computer's building search: 2.3.)

### 2.2 The Brood computer thinks in four parts

`AIBroodNew._tick_ai` ran its whole think (every 0.4 s on Hard) in one tick. It now runs it over four ticks in a row
(`_nb_think_stage`, as `AI._think_stage` does for the Crown and Clockwork computers): what it sees, its Mother and growth;
its Rootmaws, turtles and guards; its fathers, morphs, eggs and spoils; maturing, research, the army and the toads. Each
part sees what the parts before it did, in the same order as before. A think used to be one frame of 15 ms late in the
game (after 2.1); now about four of 3 to 6 ms.

### 2.3 The computers stop asking a failed search every few seconds

- The Clockwork computer keeps room on its gear field for a Heavy Works' big ring (`_keep_heavy_fed`). In a crowded base
  with no room for it, the search (every gear neighbour, every spot round it) took 90 to 180 ms in one frame, every 5 s,
  for minutes (3:08 to 4:49 in this match: 11 frames over 60 ms). After a search with no room it now waits 20 s
  (`KEEP_NONE_WAIT`).
- Every computer looking for its next hall (`_hall_first`) rated every free spot on the map on every think while none was
  free (15 to 20 ms a think late in a game). After a search with no free spot it now waits 4 s (`HALL_NONE_WAIT`).

### 2.4 The units' tick (exact)

- THE PATH QUEUE SHARES PATHS. In one tick's run of the queue (up to 24 paths) the grid only changes by the enemy gates
  each walker shuts for itself and opens again. So the same start cell, goal cell, gates shut and kind of walk give the
  same cells: `Game.find_path` keeps them for the rest of that run (`_pq_cache`) and a blob of Raptors sent to one spot from
  the same cells asks the pathfinder once. The smoothing still starts from each walker's own place. In the owner's match
  10 to 20% of the paths in the fights were shared (`paths 4516 (shared 401)` in perf_bench's minute line).
- THE TURNING GEARS. Every unit asked `GearTurn.tick` every tick whenever a Clockwork side had gear rings. Far from every
  ring (outside the box round all of them) and with nothing of the ride on it (not carried, not stepping off, no rest
  after a give-up) the tick changes nothing, so it isn't asked (`GearTurn.near`).
- THE BROOD'S RESEARCH SPEED (PACK HUNT and the like), asked by every Brood creature every tick: kept on the creature
  while its kind, its side's research (the same dictionary with as many entries: research is only ever added) and
  whether it flies are the same (`Unit._speed_add`). 9.6 -> 6.4 microseconds for that part of a Raptor's tick.
- THE SILHOUETTES of units hidden behind buildings (occluded_look.gd, 10 times a second, your units on screen): each of
  48 samples read the sprite's rect, transform, frame and mask again; now once per sprite (`_prep`, `_opq`). Drawing
  only.

The stress scenarios before and after (main 0.29.4 and this branch, run at the same time; the whole state every game
second): the same file in all six tried.

| scenario | units | trace |
|---|---|---|
| melee | 300 | the same (3,141 lines) |
| clockbrood | 200 | the same (2,748 lines) |
| idle | 300 | the same (6,930 lines) |
| grubs | 300 | the same (4,111 lines) |
| walk | 200 | the same (4,730 lines) |
| mixed | 200 | the same (3,410 lines) |

## 3. The army ladder

tools/perf_armies.sh: the stress scenarios at 50, 100, 200 and 300 units, 20 seconds each, headless. melee = Raptors v
Raptors in view; clockbrood = Clock Soldiers and Springers v Raptors and Spitters in view. "Game's work" is one tick (30 a
second: under 16 ms keeps 60 frames a second). Before (main 0.29.4) and after (this branch) ran at the same time, one a
core. The machine was shared all along: the same code differs by 10 to 25% from run to run.

| run | units | fps before | after | 1% low before | after | game's work ms/tick before | after |
|---|---|---|---|---|---|---|---|
| melee | 50 | 509 | 551 | 120 | 146 | 2.42 | 2.20 |
| melee | 100 | 342 | 343 | 59 | 60 | 3.94 | 3.88 |
| melee | 200 | 197 | 177 | 35 | 31 | 7.42 | 8.21 |
| melee | 300 | 148 | 136 | 20 | 21 | 10.51 | 11.34 |
| clockbrood | 50 | 407 | 326 | 110 | 79 | 3.06 | 3.75 |
| clockbrood | 100 | 295 | 346 | 58 | 83 | 4.82 | 4.05 |
| clockbrood | 200 | 172 | 132 | 34 | 24 | 8.75 | 11.28 |
| clockbrood | 300 | 108 | 109 | 23 | 21 | 14.45 | 14.34 |

These battles have no computers (they are switched off in the stress tool), so 2.1 to 2.3 don't show here; and 2.4's
savings are smaller than this machine's noise. What the ladder says is where a crowd stands now:

- About 30 to 45 microseconds a unit a tick on this machine: 200 units cost 7 to 11 ms a tick, 300 cost 10 to 15.
- The owner's computer: his log has the units at 54 to 56 microseconds a unit tick (353 ms a second for 6,272 unit
  ticks), so his machine runs this code about 1.6 times slower than this cloud core. A 300-unit battle there costs about
  18 to 24 ms a tick: the game can still keep 30 to 50 frames a second, with dips in the clash.
- A phone: estimated 3 to 5 times slower than this machine (not measured: no phone here). 200 units are about 25 to 45 ms
  a tick there: 20 to 30 frames a second in a big fight. 300 units are too many for a phone without the changes in 5.

The raw numbers: docs/perf/armies/ladder_before/, ladder_after/; the owner's match: docs/perf/armies/owner_match_*.csv.

## 4. The check

    tools/test_perf_armies.sh            # PASS / FAIL against tools/perf_armies_baseline.json
    tools/test_perf_armies.sh update     # write this run's numbers as the new baseline

It runs melee and clockbrood at 200 units, prints the game's and the units' ms a tick, the frames a second and the 1%
low, and times a fixed piece of GDScript (tools/perf_calib.gd) before and after, keeping the faster. The game's ms a tick
divided by that time is the score; more than 1.35 times the baseline's score is a FAIL. Run it on a quiet machine, and
again before believing a FAIL (a busy machine makes the battle slower more than the fixed piece).

The baseline (tools/perf_armies_baseline.json, this cloud machine, 0.29.5): the fixed piece 14.4 ms; melee 200 units
6.53 ms a tick (units 6.00), 223 fps, 1% low 35.5, score 0.45; clockbrood 200 units 8.31 ms a tick (units 7.51), 180 fps,
1% low 30.5, score 0.58.

## 5. What is left, and what the owner could choose

### What would change what the units do (each would change the game a little: the owner's call)

Measured costs from section 1; savings are estimates for a 300-unit battle.

1. A unit standing still in a crowd shoves its neighbours every 3rd tick (one walking every 2nd). Every 4th or 5th tick
   for one standing still with nothing in sight: about 5 to 8% of an idle army's tick. Packs would settle a little more
   slowly.
2. A unit with nothing in sight looks for a target every 0.35 s (0.3 on HOLD, 0.6 attack-moving into a wall). Every
   0.5 s when nothing was in sight last time: 3 to 5% of an idle army. It would answer an enemy up to a sixth of a second
   later.
3. A LIGHT TICK for a unit idle or on HOLD, unhurt, nothing in sight, not shoved and not moving: only its timers, its
   look for a target and its shove, the other forty checks skipped until something changes. An idle army of 150 Raptors
   at home (the owner's Brood standing at its natural for minutes) would cost about half. This one needs care: every
   rare state (a net, a stun, the swamp's mending, a research finished, a horse) must wake it.
4. Rooted Brood creatures (Mound Turtles, Rootmaws, the Mother, the fathers: 38 to 75 microseconds each) tick like
   walkers. Most of their tick is for walking units. A rooted creature's own short tick: about 1 ms a tick for a late
   Brood with 25 of them.
5. Pictures in a huge battle on screen step 10 times a second over 160 units in view; 7.5 over 300 would save about 4% of
   the battle's tick (drawing only, the game the same).

### Phones

- Drawing: about 1,000 draw calls with 400 units on screen (docs/swarm_perf.md). Each unit is its own: its shadow and
  bars, then its sprite with its own material (team colour, veteran look). A phone needs them batched: units sharing one
  material per side and look, the shadows and bars drawn in one pass, the sprite strips in atlases. That touches the art
  pipeline (every strip) and the unit shader: its own job.
- The processor: see section 3. The light tick (5.3) is the change that would help a phone's late game most.

### The computers

- The Clockwork computer's first tier-2 buildings (the Mainspring and Escapement searches) still take 80 to 170 ms in one
  frame now and then while its base is crowded (this match: 5 frames between 3:08 and 4:57). They are searches over every
  spot round every gear building, with a room count for what goes beside it; making them cheaper (keeping each spot's
  answer for the length of one search) is the next step.
- The Brood computer's Rootmaw search is still the biggest part of its think (about a third): it could keep its answer
  for a Rootmaw that found nothing until the ground or the swamp changes.

## 6. Tests

- The owner's match before and after 2.1 and 2.4: the same file (17,810 lines). The six stress scenarios: the same files.
- test_determinism (Clockwork v Brood on Hollowfen, 5 minutes, with `budget`): two runs of main 0.29.4 already part at
  20 s, two runs of this branch at 30 s (the test keeps the sounds, which go by the wall clock and draw from the game's
  random numbers, docs/pathfinding_audit.md). Not caused here: the tools that silence the sounds (perf_bench,
  stress_swarm) give the same file run after run, and the same file as main where the computers' timing is unchanged.
- test_replay: ALL OK. test_brood_new: 0 failures. test_clockwork_springer_timing check:1: PASS (0 failed).
- test_crown_farms: PASS. (It failed once with "a free Farm slot waited at most 60 s (worst 60 s)"; main 0.29.4 fails
  the same check at 70 s: it goes by the wall clock and is borderline on both.)
- test_ai_brood: 2 failures (main 0.29.4: 3; the same two, plus "venom by 620 s" on main).
- test_ai_expand: the same failures as main 0.29.4 (the Crown's "new hall within 90 s" and "still earning").
- Boot: no script errors.

## How to run it

    godot --headless --path . --fixed-fps 60 --script res://tools/perf_bench.gd -- cinder_steps clockwork brood \
        seed:607822690 strat:economy minutes:12 spike:60
    tools/perf_armies.sh <outdir> [project:/path/to/another/copy] [secs:20] [render]
    tools/test_perf_armies.sh [update]
