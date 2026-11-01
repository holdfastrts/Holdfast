# AI Crown transitions: after a held rush, and walls against the army

The owner's playtest, 2026-11-01: AI Crown v AI Crown, v0.25.25, Ashfall (2 players), seed 1864215939
(log and pictures: `docs/playtests/ai_crown_v_crown_2026-11-01/`). P1 green (Hard, Timing attack) opened Powder
Mill and Musketeers; P2 yellow (Hard, Economy) opened a Horse Breeder for a Horseman rush. The owner:

> About wall making, its important, but I think maybe needs more work on how and when, prioritizing resources and
> transitions. Overall the yellow players played better than the green even though the horse rush didn't connect.
> I think that the moment green held the horse rush it should either have expanded or committed to an attack
> immediately, but it didn't do any, it stood there and did a weak attack.

Code: `scripts/ai_transition.gd` (new), hooks in `scripts/ai.gd` (`tr`, `army_short`, `_hall_first`, `_army_first`,
`_wall_urgent`), `scripts/ai_scout.gd` (`timing_wave`), `scripts/ai_expand_wall.gd` (`_lay_pieces`, `keep`).
Study switch `-- tr:off` plays the computer as 0.25.25 did; `-- open<team>:breeder` / `open<team>:mill` fixes a
Crown computer's opening (team 0 = P1) to replay a log's game.

## 1. The game minute by minute (from the log)

Income comes in lumps (a Farm's harvest), so "earned" is the running total at each minute line.

| min | green P1: earned / workers / army (value) | yellow P2: earned / workers / army (value) | what happened |
|---|---|---|---|
| 1 | 380 / 7 / none | 380 / 6 / none | both wall the ramp with a Cottage (stands 0:41 / 0:39) |
| 2 | 380 / 9 / none | 760 / 9 / none | green: Mill 1:19, Barracks 1:26; yellow: Breeder 1:28, Barracks 1:45 |
| 3 | 760 / 9 / 3 Musketeer (180) | 1,140 / 12 / 3 Horse (120) | green's first Musketeer 2:16 |
| 4 | 1,140 / 9 / 6 Musketeer (360) | 1,520 / 13 / 2 Horseman, 2 Horse (310) | 3:44 yellow's 2 Horsemen ride out; 3:50 green sees them: **defensive build** |
| 5 | 1,520 / 9 / 7 Musketeer (420) | 2,280 / 13 / 4 Horseman (500) | **4:15 yellow's rush FAILED**; green builds Breeder 4:36, Armoury 4:47 |
| 6 | 2,280 / **8** / 7 Musk, 1 Horse (460) | 3,040 / 13 / 6 Horseman, Officer (805) | green: Church 5:40, Foundry 5:47 |
| 7 | 2,660 / 9 / 660 | 3,420 / 14 / 845, 330 gold banked | **6:28 green's first attack: 11 supply, turns round at the gate at 6:29** |
| 8 | 3,040 / 10 / 735 | 3,800 / 14 / 730, **2 halls** | 7:22 yellow expands, plans 16 palisade + 2 gates, lays 12 at once |
| 9 | 3,800 / 12 / 885, **supply 34/34** | 4,560 / 18 / 695 | 8:52 green finally expands; 8:55 yellow closes 6 empty slots (16 more pieces) |
| 9:30 | 3,800 / 13 / 940 | 4,560 / 16 / 580 | the owner stopped watching: no winner |

## 2. Where green wasted the window

**The window: 4:15 to about 6:00.** Yellow's rush failed at 4:15 (its riders went home, it switched to "build up").
Green had 6-7 Musketeers behind a standing wall and lost one man. From there it did three things wrong:

1. **It stayed in the defensive build for its full 210 s.** The scout's "rush" verdict (3:50) set `DEFEND_MOD`
   (expansion x2.2 later, tech x1.25 later, labourers x0.85) and a regroup wait of 130 s (no attack before 6:00), and
   nothing ended it early when the rush was beaten. Nothing in the AI noticed "the rush is over and I won it".
2. **Its economy stood still.** Labourers stayed at 8-9 from 2:00 to 7:00 (yellow: 13-14). Green earned 380 gold a
   minute against yellow's 760: half. `_army_first` held labourers back until 6 Musketeers, then the gold went to four
   tech buildings in 70 s (Horse Breeder, Armoury, Church, Foundry), not to a hall or hands. Its second hall came at
   8:52, and only because the soil fell under 65% (`_hall_first`), not by choice. By 9:00 it sat at the supply cap
   (34/34) on one hall.
3. **Its attack was a trickle.** As a Timing plan its wave bar was 999 until the timing (4:30), when
   `AIScout.timing_wave()` set it to **6 supply** (the scout had not sized it: the verdict was "rush", not "greedy").
   The regroup wait held it until 6:00; at 6:28 the 11 supply at home went out, met the walled ramp and pulled back a
   second later ("down in ~7 s, too dear"). Neither an all-in nor an expansion: the worst of both.

What it should have done at about 4:25 (the riders gone, 6 Musketeers v 2 Horsemen and 2 loose Horses, 360 v 310):
the armies were even, so not an attack into a walled ramp; **expand**, with the army at home covering it. By 6:30
(7 Musketeers + a Horseman, 660, against 805 of yellow's riders) a counter was still not clearly ahead. The other
moment was 8:00-9:00, when green's army (735-885) was worth more than yellow's (730-695) and yellow was busy walling
its new hall.

## 3. How yellow's walls competed with its army

Yellow played better but its walls cost it its lead in army:

- At 7:22 it planned its new hall's wall: **16 palisade + 2 gates**, laid 12 at once, then 6 more at 8:28, and at 8:55
  closed 6 empty building slots with **16 more** pieces. About 34 pieces: roughly 32 x 15 + 2 x 50 = **580 gold** in
  90 s, while it earned about 760 a minute.
- `AIExpandWall` runs **first** every think (before labourers and training) and lays pieces "as the gold allows" down
  to nothing, and `keep()` hides up to 100 more gold from the army for the next pieces.
- Its army fell from **845 (7:00) to 730, 695, 580** while the wall went up, and green's army passed it at 8:00.
  The wall was laid whatever the armies looked like: against a bigger enemy army the units should come first.

The main ramp's Cottage wall (2 pieces, 0:22) was right on both sides: cheap, early, and it stopped the rush.
That part is left alone (`tools/test_ai_wall_vs_rush.gd` guards it).

## 4. The fix (0.25.26)

**A held rush picks one transition at once** (`scripts/ai_transition.gd`, Crown computers on Normal and up). While the
scout's verdict is "rush", it watches for the rush being held: no armed enemy within 420 px of our buildings for 10 s
after a fight at home (or 75 s after the verdict with none), and our army worth at least the enemy army seen lately
(the biggest seen in the last 150 s). Then:

- **COUNTER** when our army is worth 1.5 times the enemy's and is 12 supply or more: the regroup wait is lifted and the
  wave bar set to what stands at home (85% of its supply), so the **whole army goes out as one wave** now.
- **EXPAND** otherwise, on one hall: the second hall comes first (`_hall_first` needs 2 halls for 240 s: its gold is
  held, the guards walk over), the army stays home to cover it, and the next wave waits for a **real force**
  (16 supply, or 1.6 times the enemy supply seen plus 4).
- **BUILD** on two halls already: economy and tech come back, the next wave waits for a real force.

In all three the defensive build ends: `AFTER_MOD` (expansion x0.35, labourers x1.1), the scout's wall urge and the
"army before labourers" hold (`_army_first`) are lifted. The match log says which it chose and why, e.g.
`P1 Crown the rush held (no rider near for 10 s), its army 470 against the 360 it saw: expands now, ...`.

**No 6-supply timing wave.** A Crown Timing plan that the scout did not size (`verdict` not "greedy") goes out with
16 supply or 1.6 times the enemy supply seen plus 4, not 6 (`AIScout.timing_wave`).

**Walls yield to the army when it is short** (`AI.army_short()`: our army worth less than 1.1 times the enemy army seen
lately, or an armed enemy near our buildings). A new hall's palisade and gates then wait for gold above 130 (two
Musketeers), go down at most 3 at a time, and `AIExpandWall.keep()` sets no gold aside for them. When the army is
not short, walls are laid as before.

Design rules followed (docs/design_principles.md): 2, the defender's advantage fades so the game moves on (a held rush
is a lead to use, not a reason to turtle); 4, every choice has an opportunity cost (walls against units).

## 5. Before and after (AI v AI, Hard, headless, 15:00)

RESULTS_TABLE

## 6. Open

OPEN_LIST
