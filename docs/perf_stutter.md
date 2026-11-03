# Lag, freezes and stutter (0.28.1, branch perf-stutter)

The owner, 2026-11-03 18:52: "The game started to lag, freeze and stutter."
His match log: docs/playtests/2026-11-03/lag_cinder_steps_brood_v_crown_rush_0280.txt (v0.28.0, Cinder Steps,
seed 3206849968, he plays the Brood against a HARD Crown on RUSH, on a computer).

## The short answer

- The average frame rate was fine. The freezes were single frames of a quarter to half a second, and almost all of them
  came from ONE job of the Crown computer: drawing up the wall plan for a new Town Hall (its "walled expansion",
  scripts/ai_expand_wall.gd). His log shows it exactly: the plan at 4:33 (worst frame of minute 5: 289 ms), and two at
  7:20 and 7:52 (worst frame of minute 8: 501 ms, the 7:20 one with 58 ways in). In the same match on this machine the
  plan took 125 to 270 ms in one frame. It now takes about a quarter of that (45 to 80 ms here) and gives exactly the
  same plan, cell for cell.
- The other freezes were pictures loaded the first time they were shown: the Brood Mother's first ROOT, ROOTED and LAY
  pictures took 15 to 25 ms each, two in one frame made a 100 ms freeze at 0:01; every kind's first attack, death or walk
  did the same in a fight. They are now loaded ahead, in the background, as soon as the kind is on the field (and the
  ones standing at the start while the match loads). The sounds are loaded ahead the same way.
- The Crown computer's first search for a hall spot made a 55 ms frame (four or five maps of walking steps at once):
  each of those maps is now worked out about four times faster, the same numbers.
- "hud/look doubled" was the tooltip: the one under the mouse was built again 20 times a second. It is now built 4
  times a second while the mouse stays on the same thing (it still follows the mouse every look).
- The game plays out exactly the same: the whole state of two 9 to 10 minute computer matches (the owner's: Brood v
  Hard Crown Rush on Cinder Steps, seed 3206849968; and Crown v Clockwork on Hollowfen) was written every 5 game seconds
  by 0.28.0 and by this branch, and the files are identical (12,614 and 8,019 lines).
- From now on every match log has a "slow frame" line for each frame over 50 ms, with what took the time, so the next
  freeze names its cause.

## 1. How it was found

tools/perf_bench.gd plays the owner's match (a Hard computer in his place: `brood crown seed:3206849968 strat:rush`;
`strat:` and `strat0:` are new: the computers' plans) and prints every frame slower than `spike:N` ms with the parts of
the game that took the time (scripts/prof.gd). The computer's think got finer parts (`ai/workers/wall`,
`ai/workers/xwall`, `ai/build/supply`, `ai/build/econ`, `ai/brood`), and the slowest single unit tick of a frame is
named. Then the slow parts were timed piece by piece.

    godot --headless --path . --fixed-fps 60 --script res://tools/perf_bench.gd -- cinder_steps brood crown \
        seed:3206849968 strat:rush minutes:9 spike:40 log:/tmp/log.txt

Before (0.28.0 code, headless, this machine):

    PERF spike 106 ms at 0:00  (the first frame)
    PERF spike  96 ms at 0:01: units 92.2 | slowest unit brood_mother 81.5 ms (idle)        <- her pictures, first shown
    PERF spike  62 ms at 4:00: ai/build 58.3                                                 <- the first hall search
    PERF spike 160 ms at 4:35: ai/workers/xwall 153.7                                        <- the wall plan
    PERF spike 286 ms at 7:31: ai/workers/xwall 270.3                                        <- the wall plan
    PERF spike 256 ms at 8:12: ai/workers/xwall 231.5                                        <- the wall plan

| minute | 1% low fps before | after | worst frame before | after |
|---|---|---|---|---|
| 1 | 72 | 126 | 106 ms | 53 ms |
| 5 | 52 | 70 | 160 ms | 54 ms |
| 8 | 21 | 24 | 286 ms | 109 ms |
| 9 | 21 | 23 | 255 ms | 102 ms |

(Headless at a fixed 60 frames a second, so only the game's own work is measured. Minutes 8 and 9 still have 20 or so
frames over 33 ms here, but those are two things that don't happen in the owner's match: the bench lifts the path
queue's 6 ms limit so two runs play out the same, so 24 paths a tick are found in one frame, and player 1 is the Brood
COMPUTER, whose think takes 30 to 75 ms now and then (see "What is left"). His 501 ms freeze was on his machine, about
twice as slow as this one at that job.)

## 2. What caused each spike, and what changed

### The walled expansion plan (the big freezes)

`AIExpandWall.plan_for` (scripts/ai_expand_wall.gd) runs once each time the Crown computer lays a hall: for nine radii
it floods the hall's area, floods the enemy's way in round it, checks every ways-in cell can take palisade and packs the
hall's two Farms and Mill inside, then picks the radius and lays out its building slots. Everything was done with
Dictionaries keyed by cell and helper calls per cell: 125 to 270 ms here.

Now (the same steps, the same order, so the same plan):
- the enemy's reach over the whole map and our own walk to the gate are worked out in map-sized arrays (they were
  Dictionaries of the whole map: 15 and 18 ms each);
- what doesn't change between the radii (which cells may be inside at all, the box round the hall, which of its cells
  the enemy walks, its edge) is worked out once, not nine times; the floods use arrays;
- the ways-in cells' "can palisade go here" and each slot corner's "may the building go here" are asked once per plan;
- the slot search keeps each corner's fixed facts (its ground, the gate, the hall, how much of it is inside) and only
  asks, round after round, which of its cells the slots picked so far took or covered;
- the Farms-and-Mill packing (the dearest part: it sorts every cell of the area by distance three times) is only done
  for the radii that can still win: they are packed from the lowest score without it upwards and the search stops once
  none left can beat (or tie with a smaller radius) the best found. Its sort compares numbers from a table, the same
  comparisons in the same order, so ties come out in the same order too.

tools/test_xwall_plan.gd checks it: it plays the owner's match and, at five times, makes the plan for the Crown's
halls and for every free hall spot on the map (430 or so plans) with the new code and with the old one
(tools/xw_plan_ref.gd, the 0.28.0 file kept for this test), and compares them whole (every cell, piece, slot and
their order). 0 different of 437. Median time new 60 ms, old 211 ms (new / old 0.28); the Crown's own halls: slowest new
100 ms, old 250 ms (this machine is noisy). It fails if any plan differs or the new median is over half the old one,
so the old code fails it.

### Pictures loaded the first time they are shown

`Game.tex` loads a unit's strip the first time it is shown. A Brood Mother strip is a big picture: 15 to 25 ms each.
At 0:01 she roots (ROOT, then ROOTED) and lays (LAY): 50 to 100 ms in one frame. A fight brings every kind's first
attack and death strips at once.

New: scripts/art_warm.gd (ArtWarm, a child of the game). As soon as a kind is on the field (a look every half second),
all its strips (and the horse coat masks for them) are loaded in the background by Godot's loader threads, three at a
time; the effects too. Game.tex takes a strip that is still loading from the loader (it waits for that one) instead
of loading it a second time. The kinds standing at the start are loaded while the match loads (at most 1.5 s). Only
the kinds in the match: the whole Brood set alone would be about 150 MB of pictures. The web build has no threads:
there one strip is loaded per frame, only when the frame before was quick (or in the 3-2-1 countdown).

The sounds (assets/audio, without the ambience) are loaded the same way after the pictures, on computers and phones
with threads: every name's first play loaded its files (Sfx._find), and the first fight plays many new ones at once.

### The first hall search (55 ms)

`AI._safe_hall_spot` asks how far a spot is by land from each side's main and natural (ExpansionSpots._steps, one map
each, kept once made). The first search made four or five at once. `_steps` now works in map indices instead of a
queue of cells: about 4x faster, the same steps. (scripts/expansion_spots.gd; nothing in ai.gd changed for it.)

### The HUD (hud/look 12 -> 25 to 32 ms a second)

hud/look now includes "hud/tip check": 20 times a second the HUD looks at what is under the mouse, and when the
tooltip was showing it built it again from scratch each time (texts, numbers). It is now kept for 250 ms while it is
the same thing under the mouse (TIP_REBUILD_MS in scripts/ui/hud.gd); it still follows the mouse every look.

### Checked and not the cause

- The AI STORY and the narrator only exist when watching computers or a replay; in a match the computer's log lines
  only go through the phrase book into the replay (a few regex matches a line, inside "ai").
- Nothing of the campaign runs in a skirmish (game.mission is null; only its end check is asked).
- The autosave (1 ms a second) and the replay's writing (0.4) are small. The replay's pictures (replay/record, 22 ms a
  second in his minute 8) are within its 3% budget; a keyframe every 10 s is bigger (once 41 ms here, late).
- Music: a new piece is loaded when the music changes (4 to 10 ms here). Left as it is.
- Shaders: the game uses six (the team colour, swamp, fog, silhouettes, powder smoke, add-blend glows). On this machine
  there is no graphics card (software OpenGL), so the cost of compiling one the first time it is drawn can't be
  measured here; the "slow frame" lines now show it as "the rest" if it is big.

## 3. The "slow frame" line in the match log

scripts/match_log.gd, scripts/prof.gd: Prof now also keeps what each frame spent. A frame over 50 ms
(MatchLog.SLOW_FRAME_MS) writes, at most 8 a minute (always when over 150 ms):

    [07:31] slow frame 264 ms: ai 250.2, ai/workers/xwall 248.3, game 2.9, the rest 10.0
    [00:01] slow frame 96 ms: units 92.2 (slowest unit: brood_mother 81.5 ms, idle), the rest 2.0

"the rest" is the time no part of the game timed: drawing on the graphics card, the engine, a shader compiled the first
time, the system.

## 4. Same game

- tools/perf_bench.gd trace:FILE, 0.28.0 and this branch, both identical: Cinder Steps Brood v Hard Crown Rush seed
  3206849968, 10 minutes (three wall plans, the hall searches); Hollowfen Crown v Clockwork seed 4242, 9 minutes.
- tools/test_xwall_plan.gd: 0 different plans of about 430.
- tools/test_replay.gd: ALL OK.
- tools/test_determinism.gd (Cinder Steps, Brood v Crown, 330 s, budget) runs to the end; as on main its HASH lines
  differ between two runs of the same build from 30 s on (docs/aoe_show.md: two runs of main diverge at 30 s too: the
  sounds go by the wall clock). The bench's traces above silence the sounds and are the same-game check.

## 5. What is left

- The wall plan still takes 45 to 90 ms here (perhaps twice that on the owner's machine) once per Crown expansion. The
  rest of it is the Farms-and-Mill packing's sort and the slot search; making it smaller still would mean either a
  slightly different plan (ties broken another way) or the plan arriving a few ticks after the hall is laid: both
  change what the computer does, so they are the owner's call.
- The Brood COMPUTER's think (scripts/ai_brood_new.gd, `ai/brood`) takes 30 to 75 ms every second or so from minute 7
  in the bench. It doesn't run when you play the Brood yourself; against a Brood computer it would. Not changed here
  (other jobs are reworking the computers).
- The first unit of a new kind still loads its first picture when it appears (its other pictures then come in the
  background).
- The web build loads ahead one picture per quick frame and no sounds.
- The units' own work is the biggest steady cost (as in docs/swarm_perf.md): 260 ms a second for 120 units in his
  minute 8. That is not new.
