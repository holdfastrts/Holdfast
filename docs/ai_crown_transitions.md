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

## 4. The fix (0.26.13)

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

**A full wave is not held by the new hall's guards.** Two thirds of the army guarded a new hall until its wall was 85%
closed; with the walls yielding, that kept the rest under the wave bar for minutes. Now, once the whole army reaches the
bar and is not short, two stay as the garrison and the rest go.

**The forced hall is dropped when the enemy shows more** (`want_hall()` only while `army_short()` is false: one study
game, green expanded on a sighting of 230 while yellow's 730 counter-attacked, and lost).

**Repair first** (found by the 0.26.0 ramp-wall fix: on Ashfall the Crown spent its gold on a Musketeer while the gate
was hit, had nothing to mend it with, the gate fell at ~2:30 and 3 labourers died). While a wall piece (palisade, gate,
ramp Cottage) is under 85% with an armed enemy within 160 px, `AI._repair_keep()` holds 80 gold from every spending
stage of the think; `_repair_wall` still sees it. 40 was spent in 20 s and the gate still fell; 80 held it.

Design rules followed (docs/design_principles.md): 2, the defender's advantage fades so the game moves on (a held rush
is a lead to use, not a reason to turtle); 4, every choice has an opportunity cost (walls against units).

## 5. Before and after (AI v AI, Hard, headless, 15:00)

Hard v Hard Crown, P1 Timing attack, P2 Economy (`tools/study/study_game.gd ... end:900`); "before" is `-- tr:off`.
P2's Horse Breeder opening is fixed with `open1:breeder` (the owner's game) except the first pair (both Mill). Army
value at 5:00 / 7:00 / 10:00. Results at 15:00 are the study's power lead. One game per row: the timings are the solid
part, the results are noisy. "Mid" code lacked the last two rules of section 4; "final" is what is committed.

| map | run | P1 green (Mill): held, choice / 1st hall / 1st attack (supply) / army | P2 yellow: held, choice / 1st hall / 1st attack / army | result |
|---|---|---|---|---|
| Ashfall, both Mill | before | - / 9:10 / 4:30 (6) / 340, 570, 970 | - / 7:40 / none / 400, 575, 1085 | P2 lead |
| | after (early) | 5:58 expand / 10:28 / 4:30 (6) / 340, 510, 840 | 4:53 expand / 7:39 / none / 400, 715, 850 | P2 lead |
| Ashfall, P2 Breeder | before | - / 8:12 / 6:20 (10) / 400, 575, 610 | - / 7:28 / none / 425, 845, 120 | P1 lead |
| | after (mid) | 4:27 expand / 5:03 / 14:34 (17) / 460, 460, 790 | 5:29 expand / 6:05 / none / 385, 805, 500 | P1 lead |
| | after (mid, rerun) | 4:07 expand / 5:38 / none / 420, 100, 0 | 5:09 counter / 7:36 / 5:09 (18) / 730, 540, 870 | P2 by gg 10:00 |
| | **after (final)** | 7:12 expand / 7:31 / none / 420, 420, 930 | 6:19 counter / 7:36 / 6:19 (17) / 730, 390, 550 | P1 lead |
| Greenhold, both Breeder | before | - / 6:43 / 5:19 (12) / 425, 615, 690 | - / 7:31 / none / 485, 370, 450 | even |
| | after (mid) | 4:43 counter / 7:44 / 4:43 (15) / 615, 310, 540 | 3:39 expand / 4:24 / none / 500, 615, 1075 | even |
| Highmoor, P2 Breeder | before | - / 8:35 / 5:58 (7) / 420, 160, 535 | - / 7:22 / none / 730, 845, 695 | P2 lead |
| | after (mid) | 4:02 expand / 5:30 / 14:15 (20) / 420, 440, 920 | 5:05 counter / 7:23 / 5:05 (18) / 730, 195, 350 | even |
| Twin Fords, P2 Breeder | before | - / 8:17 / 5:58 (7) / 420, 355, 780 | - / 7:42 / none / 615, 790, 965 | even |
| | after (mid) | 3:47 expand / 3:53 / none / 360, 280, 320 | 5:36 counter / 8:00 / 5:36 (18) / 615, 350, 510 | P2 lead |
| | **after (final)** | - / 7:32 / 11:44 (16) / 400, 920, 940 | 6:49 counter / 7:28 / 6:49 (19) / 730, 675, 735 | even |

- **The trickle is gone**: before, the Timing plan went out with 6-12 supply and turned round at the gate; after,
  first attacks are 15-19 supply.
- **A held rush is followed at once**: the Horseman side, its rush held, counter-attacked with its whole army
  (17-19 supply) within a minute in every game; before it never attacked in 15 minutes.
- **Expansions came 2-4 minutes earlier** after an EXPAND choice (3:53-5:38 against 6:43-9:10).
- **Over-greedy expansions lost games** in the mid code; with the final rule green held both of those maps.
- **Wall test** (`tools/test_ai_wall_vs_rush.gd`, with 0.26.2 merged): default map third Musketeer at 164 s (the known
  "by 160 s" failure; it was 170 s), 1 labourer lost; Ashfall third Musketeer 167 s, **0 labourers lost** (3 before
  the repair reserve).

## 6. Open

- The Musketeer side after EXPAND often made no attack for many minutes (14:34, 14:15, none).
- More games per map are needed to call win rates.
- The wall test's 160 s limit for the third Musketeer still fails by 4-7 s (known).

## 7. The owner's doctrine (2026-11-03)

Two more logs (`docs/playtests/2026-11-03/`): `crown_expand_workers.txt` (AI Crown v AI Brood ECONOMY, Kestrel Rise)
and `human_crown_v_brood_econ.txt` (the owner's own Crown, on a phone with very low APM, held the Brood economy's
first aggression easily: "so crown ai really has to step up"). The owner, verbatim:

> Crown stopped making workers but brood kept making workers. Crown took forever to expand and it tried to wall in
> immediately, this is a mistake: you expand, you keep your forces in the high ground, you saturate the expansion
> first, then you slowly wall in. You always have your main to run with your workers, and the musketeers in the main
> on HOLD with a cannon can hold a lot of attacks until we are ready to go down with the army. While we keep the main
> army on the main base we still scout the map with horsemen to know what our enemy is up to, and if we can we kill
> workers.

**The doctrine, as the Crown computer now plays it** (`AI.doctrine()`: Crown, Normal and up, off under `-- tr:off`):

1. **Never stop making labourers until the halls are saturated.** Why it "stopped" in the Kestrel log: it did not stop,
   it ran out of posts. The labourer target is the posts on its farms and Mills; one hall holds about 14-16, and it had
   one hall until 7:21 (9 labourers at 2:00-3:00, 14 at 6:00, 18 at 8:00, against the Brood's 45 and 58). So the fix is
   the expansion (2), plus labourers **trained ahead** for a hall being saved for or going up (`SAT_PRETRAIN` = 6 over
   the target), so its farms fill the moment they stand.
2. **Expand when the main is saturated, not when its soil runs low.** From 2:30 on, a saturated main (`AI.saturated()`:
   every post filled, one short allowed) with no enemy at its buildings makes `_hall_first` want a second hall now
   (gold held for it). The match log says when the economy is saturated on 1 and on 2 halls.
3. **Saturate first, then wall in slowly.** A new hall's palisade and gates (`AIExpandWall`) are not laid, and no gold
   is set aside for them, until the economy is saturated; then 3 pieces every 10 s at most. **Workers and army before
   walls** (`AI.wall_yield()`): nothing is laid while the army is short of the enemy's or under a minimum for the
   clock (4 supply plus 1 every 30 s, at most 30).
4. **The army stays on the main's high ground.** Once the new hall stands, no part of the army is sent to guard it
   (`_guard_new_hall`); the army waits at the main's rally behind the ramp (as before), and the expansion's labourers
   flee to the main when raided (the existing `_worker_safety`).
5. **Go down only when ready**: sections 4-5 (the whole army when it is clearly bigger, or a real timing; no trickle).

Not done in this pass (left as it was): a HOLD stance order for the Musketeers and a cannon at the ramp (the army
already waits idle at the main's rally), and continuous Horseman scouting (the existing raid and harass code, 0.26.1/
0.26.3, sends Horsemen out after workers; a dedicated 1-2 Horseman scout loop is the next step).

## 8. Where the gold went: the FFA log

`docs/playtests/2026-11-03/ffa3_brood_idle_crown_low.txt` (Ashfall 3-player FFA, Crown HARD BALANCED; the owner: "Why
does Crown stay at low supply forever? They stop making workers and don't make army"). By 9:31 the Crown earned 6,080
and spent 6,019, gold always 0-35 at the minute lines, 211 powder unspent, army never above 470. From the log's events
and the prices:

| what | count | gold | share |
|---|---|---|---|
| labourers | about 34 (trained 40, 6 soldiers) | ~1,700 | 28% |
| buildings: 6 Cottages, 3 Barracks, 3 Farms, 2 Mills, Breeder, Church, Armoury, Foundry, Town Hall | 19 | ~2,550 | 42% |
| walls: the ramp (4 pieces) and the new hall (planned 42 palisade + 2 gates; laid 58 pieces from 6:02 to 9:05, 25 at 8:03 alone) | ~62 | ~1,080 | 18% |
| research (Matchlock, Socket Bayonet) | 2 | ~200 | 3% |
| **army: 4 Musketeers, 2 Horsemen** | 6 | **~470** | **8%** |

So the army starved behind buildings and the expansion's wall: the wall alone cost twice the whole army, laid the
moment the hall stood (65 ways-in cells on a 3-player Ashfall), while the army stayed at 4 Musketeers for 5 minutes.
The labourers did not stop (32 at the end); the army did. Point 3 of the doctrine is the fix: the wall waits for
saturation and for an army that is not short, and goes down a few pieces at a time.

## 9. Doctrine before and after (AI Crown v AI Brood ECONOMY, Hard, 15:00)

Crown (Hard, Economy) slot 1 against the Brood (Hard, Economy), `tools/study/study_game.gd a:crown b:brood pa:economy
pb:economy`; "before" is `-- tr:off`. "Doctrine 1" expanded only on saturation (it never came: farms added posts faster
than the hall trained hands); "doctrine 2" also on a full main from 2:30 (too early: the 400-gold hall at 2:56 starved
the labourers); "final" is the committed code (an unscouted enemy no longer holds the labourers; a full main expands
from 4:00). Labourers and army at the minute lines; wall gold = new-hall pieces laid x 15.

| game | labourers 6:00 / 8:00 / 10:00 | 2nd hall | 1st wall piece at new hall | Crown army 6 / 8 / 10 | Brood army 8 / 10 | wall gold | result |
|---|---|---|---|---|---|---|---|
| Kestrel Rise (2039763518), before | 18 / 22 / 22 | 6:11 | 6:12 | 455 / 495 / 310 | 2775 / 2450 | ~540 | Brood on lead |
| ... doctrine 1 | 14 / 20 / 33 | 5:31 | never | 455 / 630 / 740 | 2875 / 2050 | 0 | Brood on lead |
| ... doctrine 2 | 10 / 14 / 22 | 2:59 | never | 365 / 425 / 895 | 2200 / 2200 | 0 | even |
| **... final** | **20 / 37 / 45** | **3:55** | never | 360 / **1050 / 1435** | 2725 / 2325 | 0 | Brood on lead |
| Mirewood (3), before | 14 / 20 / 24 | 7:20 | 7:20 | 495 / 675 / 80 | 3925 / 4885 | ~750 | **Brood wins 11:16** |
| ... doctrine 1 | 14 / 18 / 26 | 7:40 | never | 520 / 680 / 345 | 3475 / 3815 | 0 | Brood by gg 13:11 |
| ... doctrine 2 | 10 / 14 / 16 | 2:56 | never | 420 / 485 / 80 | 3775 / 4640 | 0 | Brood on lead |
| **... final** | **25 / 39 / 46** | **3:53** | never | 360 / **1110** / 235 | 4240 / 3910 | 0 | Brood on lead (survives to 15:00) |

And the owner's Ashfall Crown v Crown game (seed 1864215939, P2 Horse Breeder), all the code of this branch:

| run | P1 green (Mill): 2nd hall / 1st attack / labourers ~7:00 / army 5, 7, 10 | P2 yellow (Breeder) | result |
|---|---|---|---|
| before (`tr:off`) | 8:12 / 6:20 (10) / - / 400, 575, 610 | 7:28 / none | P1 on lead |
| section 4 only | 7:31 / none / - / 420, 420, 930 | 7:36 / counter 6:19 (17) | P1 on lead |
| **with the doctrine** | **3:53** / 9:30 (17) / 32 / 420, 705, **1635** | 4:32 / counter 6:59 (15) | **P1 wins (12:49, every building razed)** |

Read: the Crown now keeps up in hands (about 38 labourers at 8:00 against 21) and fields twice the army at 8:00; it
still loses on lead to the Brood economy on both maps at 15:00, but no longer dies by 11:16 on Mirewood. Walls: the
expansion was never walled against the Brood (its army counts as bigger, so `wall_yield` holds the wall); that is the
doctrine (main high ground first), but the "slowly wall in" half never came in these games.

Tests: `tools/test_ai_wall_vs_rush.gd` default map: only the known third-Musketeer limit (165 s against 160 s), 1
labourer lost. Ashfall: the result is a coin-flip around the gate holding: final code 0, 4 and 0 labourers lost in three
runs (limit 2); with `tr:off` 3. `tools/test_ai_expand_wall.gd`: all pass on its three maps (its Crown is peaceful, so the doctrine is off there: the wall plan itself is unchanged).

Open (doctrine): the HOLD stance with a cannon at the ramp; a dedicated 1-2 Horseman scout loop; the expansion wall
when the Brood's rooted army keeps `army_short` true all game; `AI.saturated()` (posts minus one) is rarely reached
while farms keep adding posts, so the "saturated" match log line seldom shows.
