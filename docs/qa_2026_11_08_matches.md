# QA study: computer matches (qa-matches, on 0.33.7)

Part of the owner's "overall study and complete systematic test of the game" (2026-11-07). A measuring job: no rule and
no computer player was changed. 258 games of Hard computer against Hard computer, up to 15:00 each, on 0.33.7 (main at
d5dbc9dd), all 19 two-player maps, the six pairings (the nine matchups counting each side, with the three mirrors),
OPTIMAL on both sides as the base, every other listed plan once against OPTIMAL, and six 4-player games.

## How it was measured

- **Tool**: `tools/qa_match.gd` (new): starts a normal match with any number of computer slots and reads it every 5-10 s.
  It writes a line a minute per player (income earned, spent, bank, workers, army value, halls, supply, units lost,
  buildings lost) and events: halls lost (built or a site), the computer's own first attack and the FIRST ENEMY ARRIVAL in
  each base (300+ army value within 500 px of its buildings: this also catches the Clockwork's pushes, which never set the
  computer's "attacking" flag), STALLS (400+ gold banked and nothing spent for 60 s; no unit made for 90 s under the supply
  cap; an army that stood still for 60 s+ while 300+ enemy value was in its base and under a quarter of it fought), units
  STUCK (on a move order, not fighting, not at the goal, under 8 px of movement in 30 s), the AI STORY lines and every
  script error printed. Runner `tools/study/qa_matches.py`, tables `tools/study/qa_matches_report.py` (all of section
  "Tables" below is its output). Raw data per game: `docs/qa_2026_11_08_matches/data/<tag>/` (result.json, story.txt,
  errors.txt when any). Every game's map and seed are in its result.json, so any game below can be replayed with
  `godot --headless --fixed-fps 30 --script res://tools/qa_match.gd -- map:<map> seed:<seed> slots:<f/plan/side,...> out:<dir>`
  (the games are not deterministic run to run, see the noise note).
- **Base**: 19 maps (the 9 classic maps and the 10 named 1v1 maps) x 6 pairings x 2 seeds = 228 games; between the two
  seeds of a map the sides swap, so each cross pairing played each start spot once per map. Mirrors: the "first" side is
  the P1 start spot.
- **Plans**: each faction's other listed plans once against OPTIMAL (24 games, the opponent faction and the map rotating):
  a small sample, one game per plan, so read it as a hint only.
- **4-player**: three free-for-alls on classic maps (Greenhold, Highmoor, Red Coast) and three 2v2 on team maps (Twin
  Crowns, Jade Wilds, Ember Reach), OPTIMAL everywhere.
- **Draws**: no winner at 15:00. The LEADER of a draw is the side whose income earned + 2 x army value is 10% ahead (the
  rule of docs/brood_nerf_study.md). "Won or led" = won, or led a draw.
- **Time**: about 3.3 minutes of real time a game, two at once, ~8 hours in all. No game crashed or hung (258 of 258
  have a result). The first 11 games ran before the arrival and "hall built" fields existed; they were played again (the
  first copies are kept in `docs/qa_2026_11_08_matches/data_pre_arrival/`, not counted).
- **Noise**: the brood-nerf study found that the same map and seed played twice agrees on the result about 2 times in 3.
  Here, the two seeds of a map (sides swapped) gave the same result for the first-named faction on 6 of 19 maps in Crown
  v Brood, 7 of 19 in Brood v Clockwork, 15 of 19 in Crown v Clockwork (mostly both draws). Per-game income ratios at
  8:00 spread with a standard deviation of 0.14-0.20 in the cross matchups, 0.39 in the Brood mirror. So a single game or a
  single map says little; the matchup totals (38 games each) are what to read.

## The answer in short

| matchup (first-named's view) | games | W-D-L | won or led | income ratio 8:00 | army ratio 8:00 | decided games' mean length |
|---|---|---|---|---|---|---|
| Crown v Brood | 38 | 0-13-25 | 0 of 38 | 0.68 | 0.71 | 13:13 |
| Crown v Clockwork | 38 | 1-34-3 | 4 of 38 | 0.65 | 0.31 | 13:17 |
| Brood v Clockwork | 38 | 14-22-2 | 23 of 38 | 0.79 | 0.80 | 13:00 |
| Crown mirror (P1 spot) | 38 | 2-36-0 | 17 (P2 17, even 4) | 1.0 | | 13:58 (2 games) |
| Brood mirror (P1 spot) | 38 | 14-16-8 | 21 (P2 14, even 3) | 1.0 | | 12:29 |
| Clockwork mirror (P1 spot) | 38 | 0-38-0 | 19 (P2 13, even 6) | 1.0 | | none decided |

1. **The Crown computer is the weak side everywhere.** It won 1 of 76 cross games and led 3 more draws. Against the
   Brood it never won or led (0 of 38: 25 losses, 13 draws all Brood-led); against the Clockwork it lost or trailed 34 of
   38. It earns 0.65-0.68 of its opponent's income at 8:00 and falls further behind (0.48 of the Brood's at 15:00), its
   army is 0.31 of the Clockwork's at 8:00, it holds 1.9 halls at 8:00 against the Brood's 3.4 and the Clockwork's 2.4,
   and it lost 171 built halls (plus 60 hall sites) in 152 sides. On no map does it do well: its best maps (Dune Sea,
   Redrock Canyon, Thornwood Maze, Twin Fords) give it 1 won-or-led of 4.
2. **The Brood beats the Crown and edges the Clockwork.** Brood v Clockwork: 14-22-2, won or led 23 of 38. The Brood
   earns LESS than the Clockwork (0.66 at 5:00, 0.79 at 8:00) but catches up by 10:00 (0.99) and passes it by 15:00
   (1.11), while the Clockwork's army stays bigger (Brood army 0.80 at 8:00, 0.61 at 15:00 in the games still going).
   The Brood wins on its army's efficiency and late economy, not early income.
3. **The Clockwork's economy is the strongest early**: 3,950 income at 5:00 against ~2,420 for the other two, and the
   biggest army at every minute (1,548 at 8:00 against the Brood's 872 and the Crown's 718). It still rarely finishes a
   game: it won 5 of 76 cross games, 0 of 38 mirrors, and its push never sets the computer's "attacking" flag.
4. **Games mostly do not end.** 159 of 228 base games were draws at 15:00, every Clockwork mirror and 36 of 38 Crown
   mirrors. In 29 draws (+2 in other modes) one side had no workers and no army left, often for 2-5 minutes, and 30 had
   a side with no halls: the game was over in all but name and the winner did not finish the last buildings. The
   brood-nerf study found the same (its games were also up to 15:00).
5. **The P1 start spot wins more often**: 44 wins to 25 for P2 over all base games (two-sided binomial p = 0.03), 16-8 in
   the mirrors alone (won or led 118-94 and 57-44). Per map the clearest are Red Coast (P1 won or led 10, P2 2), Frostfang
   (won or led 9-2), Ashfall, Redrock Canyon and Mirewood for P1, Thornwood Maze for P2 (P2 10, P1 2) and
   Amberfall Vale for P2 (7-4). With 12 games a map these are hints to check, not proof (19 maps, so one or two such
   extremes are expected by chance); the overall 44-25 is the stronger signal.
6. **OPTIMAL's Crown nearly always plays Balanced** in the cross games (67 of 76 sides at 5:00) and those sides won or led
   2 of 67. Its other picks (Economy, Dragoon raids, Timing) appear almost only in the mirrors. OPTIMAL's Brood and
   Clockwork picks pay: every Brood side on Brute siege (11) or Spitter timing (9) won or led, Timing 13 of 14; every
   Clockwork side on Economy (12) or the Heavy Works push (7) won or led; their Balanced picks are about even (Brood 27 of
   40, Clockwork 18 of 40).
7. **No crash, two script errors** (see Problems): `ai_crown_siege.gd:501` (a freed anchor, 201 times in one game) and
   `ballista.gd:400` (a null target, 9 times in 3 games).

## Compared with docs/brood_nerf_study.md (0.33.6, FOOD_BONUS 1.2)

0.33.7 changed only the Musketeer's walk art after 0.33.6, so the game is the same; the differences are the maps (19 here,
5 there) and noise.

| | brood-nerf-study at 1.2 (5 maps, 25 games each) | this study, same 5 maps (10 games) | this study, all 19 maps (38 games) |
|---|---|---|---|
| Brood v Crown: Brood W-D-L | 16-9-0 | 8-2-0 | 25-13-0 |
| ... Brood won or led | 25 of 25 | 10 of 10 | 38 of 38 |
| ... Brood income / Crown's at 8:00 | 1.46 | 1.48 | 1.47 (1 / 0.68) |
| Brood v Clockwork: Brood W-D-L | 8-15-2 | 4-6-0 | 14-22-2 |
| ... Brood income / Clockwork's at 8:00 | 0.72 | 0.74 | 0.79 |
| Crown v Clockwork: Crown W-D-L | 5-13-7 | 0-9-1 | 1-34-3 |
| ... Crown income / Clockwork's at 8:00 | 0.65 | 0.62 | 0.65 |

What changed: nothing that is not noise. The income ratios match the nerf study within 0.02-0.07. The Brood still never
loses to the Crown and the Crown still never leads it, on all 19 maps now, not just the five. The one difference worth
saying is that the Crown v Clockwork games are even more often draws here (34 of 38; the nerf study 13 of 25) with the
Clockwork ahead in 31 of them: the Clockwork leads but does not finish.

## Per map, in short

- The Crown has no good map: 0 or 1 won-or-led of 4 cross games on every map; its income ratio at 8:00 is 0.51
  (Frostmere) to 0.85 (Saltmarsh Isles).
- The Brood won or led all 4 of its cross games on Amberfall Vale, Border March, Dune Sea, Frostmere and Redrock Canyon
  (Frostmere: 1.68x its opponents' income at 8:00). Its weakest: Cinder Steps and Hollowfen (2 of 4; the Clockwork's
  maps, as the nerf study also found for Hollowfen).
- The Clockwork's best: Cinder Steps (4 of 4, 1.56x income), Red Coast and Ashfall (3 of 4, 1.68-1.76x); its weakest
  Dune Sea, Redrock Canyon and Twin Fords (1 of 4).
- Start spots: see point 5 above and the per-map table below (P1 spot W-L and won-or-led per map).

## Game length

No base game was decided before 8:00 (the shortest: 9:58, Brood v Clockwork). Decided games ended at 13:00-13:58 on
average. Brood mirrors are the most decisive (22 of 38 decided, 11 before 12:00); Clockwork mirrors never ended, Crown
mirrors twice. See point 4: many draws are dead games the winner did not finish.

## First attacks

- The **Brood** attacks first and early: its own first attack at a median 2:55 (earliest 2:35), but 44 of 151 lost more
  than twice what they killed and razed nothing ("thrown away"), and only 66 of 151 paid. Its first real ARRIVAL in the
  enemy's base (300+ value) comes at a median 8:10, and 50 of 143 arrivals were held cleanly by the defender.
- The **Clockwork** arrives first with a real army: median 6:20 (earliest 4:00), and 74 of 131 arrivals paid.
- The **Crown** arrives last: median 9:00, and in 49 of its 152 sides no 300+ army reached the enemy's base by 15:00;
  when it does arrive it usually pays (83 of 103). Its own first attack (riders, the rush) comes at a median 7:45.

## Plans against OPTIMAL (one game each: hints only)

- **Never won or led**: every Crown plan (Balanced, Rush, Economy, Timing, Dragoon raids, Siege push, Balloon harass): 0
  of 7; the Siege push was even, the others behind or lost (Rush lost to the Brood at 13:31, Dragoon raids lost to the
  Brood at 12:56). The Clockwork's Owl raids, Rush and Springer timing all lost (Springer v Clockwork at 10:12, army
  0.01 of the enemy's at 10:00), as did the Brood's Rush (v Clockwork, 10:23) and Balanced (v Brood).
- **Won**: Clockwork Clock Soldier rush v the Crown (11:34; income 3.3x at 8:00), Brood Brute siege v the Clockwork
  (13:31), Brood Spitter timing v the Brood (14:48). The other Brood and Clockwork plans led their draws.
- Read with the base games: OPTIMAL's own Brute / Spitter / Timing picks for the Brood and Economy / Heavy picks for the
  Clockwork won or led nearly every time; the Crown's Balanced pick almost never.

## 4-player games

All six reached 15:00 without a winner. In each, at least one side was wiped out or close to it (2v2 Jade Wilds: the
Crown and its Brood ally both at 0 army and 0 halls, the other team far ahead; Twin Crowns: the Clockwork's Crown ally at
0; free-for-all Greenhold: the P1 Crown at 0 halls, workers and army). The Crown was the weakest side in five of the six.
15 minutes is too short to decide a 4-player game between these computers; the one 2v2 stall (the Clockwork's army
standing still for 100 s with 1,540 enemy value in its base, Twin Crowns 11:20) and the Musketeers stuck at Twin Crowns
(below) are the 4-player findings.

## Problems seen (with how to replay them)

1. **Dead sides that do not lose, and winners that do not finish** (31 games). A side with no workers and no army (and
   in most cases no halls) stays in the game for up to 5 minutes: e.g. base_frostmere_crcw_r0 (map frostmere, seed 1146:
   the Crown dead from 10:00, 693 gold banked), base_glimmerdeep_crcw_r1 (seed 1180, from 11:00), base_border_march_crcr_r0
   (seed 1124, from 12:00), base_highmoor_crcw_r0 (seed 1106: the Crown had no halls from 11:00 and nothing at all from
   13:00). The winner does not hunt the last buildings, so the game is a draw at 15:00. This inflates every draw count
   above.
2. **The Crown rebuilds a hall on the spot it just lost** while the enemy is still there, and loses the site too: 7
   times, e.g. base_amberfall_vale_crbr_r0 (seed 1154) P1 at (59, 25): built hall lost 11:25, new
   sites lost 12:55 and 13:40; base_frostfang_crcw_r0 (seed 1110) P2 at (106, 54) 7:00 then 8:35; base_saltmarsh_isles_crcr_r1 (seed 1179) P1 at
   (27, 3) 9:25 then 9:40. 60 hall SITES lost in all for the Crown (24 for the Clockwork): gold thrown at a spot the
   enemy holds, which feeds the snowball.
3. **Crown armies stuck in their own main** (82 stuck units in 39 games, nearly all Crown). Groups on an attack-move that
   do not leave their base: base_hollowfen_crcw_r1 (seed 1189) P1: 8 Musketeers at tile (22, 16) from 9:50 to 12:40,
   going to (90, 65); base_thornwood_maze_crcr_r1 (seed 1173) P1: 4 Dragoons at (21, 15) from 8:50 and 4 more plus 2
   Musketeers at (14, 20) from 9:40; 2v2_twin_crowns_1 (seed 7201) P1 Crown: 9 Musketeers at (16, 20) from 11:00;
   base_dune_sea_crcw_r0 (seed 1107) P1: a cannon and a Cuirassier at (20, 15). Same tile, same group, inside the Crown's
   main: most likely its own palisade or gate (or a building) shutting them in. Also 9 Clock Soldiers (4 on Mirewood) and
   13 cannons alone.
4. **Script errors**: `SCRIPT ERROR: Left operand of 'is' is a previously freed instance` at
   `AICrownSiege._siege_set (scripts/ai_crown_siege.gd:501)`, 201 times in base_glimmerdeep_crcr_r0 (seed 1145, the
   Crown's Siege push; `anchor` freed and then tested with `is Building`, the `_alive(anchor)` check before it does not
   cover the later line). `Invalid call. Nonexistent function 'has_tag' in base 'Nil'` at `ballista.gd:400` (`_worth`:
   `e as Unit` is null for an entity that is neither a Building nor a Unit), 9 times in base_amberfall_vale_cwcw_r1,
   base_border_march_cwcw_r0 and base_kestrel_rise_cwcw_r0 (all Clockwork mirrors).
5. **Stalls** (rare): the Crown sat on 400-700 gold for 2-4 minutes after losing its halls (base_frostmere_crcw_r0 240 s,
   base_glimmerdeep_crcw_r1 195 s: nothing left to make it with, or nowhere to build); the Clockwork stopped making units
   for 90-134 s late in 13 games (mostly with an empty bank); armies stood still with the enemy in their base 6 times (the
   longest: base_hollowfen_crcw_r1 P1 Crown at 7:30 for 90 s, 1,015 enemy value in base, 8 units still; this is the same
   group as the stuck Musketeers in point 3). No side stopped spending with money in hand early in a game.
6. **The Clockwork's push is invisible to "attacking"**: AI._attacking is never set by the push (0 of 151 sides), so
   anything reading it (tools, the story, an opponent's logic if any) sees a Clockwork that never attacks. Measured here
   by arrivals instead.
7. **AI STORY lines that do not match the game** (tools/study/qa_matches_report.py checks them against the measured
   numbers):
   - "riders", "fast riders" and "a Horse Breeder or riders early" said of Brood and Clockwork enemies, who have neither
     (1,220 lines in 68 Brood games, 213 in 41 Clockwork games): the Brood calls Raptors riders ("P1 Brood sees 3 riders
     leave the enemy's main", "reads the enemy as AGGRESSIVE (a Horse Breeder or riders early)" against a Brood); the
     Clockwork's push "does not chase 1 fast rider(s)" in a Clockwork mirror.
   - "expands to fresh land: its best base has ONLY 92-100% left" (482 lines, 156 games): the reason given is not one.
   - "holds the top of its ramp: the force below (484) is more than its army (820) can beat" with the force below the
     SMALLER number (205 lines, 74 games), and the same at the walled natural's gate (47 lines). Either the numbers shown
     are not the ones it weighs or the hold is wrong.
   - "puts its army first (A against the B it reckons the enemy has)": the reckoning is off by 1.5x or more against the
     measured enemy army 146 times (105 too low, e.g. reckons 506 when the enemy had 825; 41 too high).
   - "reads the enemy as GREEDY (no army and no production at its base)" while the enemy had 250+ army (24 lines, e.g.
     a Brood at 6:46 with 1,350 enemy army), and "GREEDY (a second base...)" while the enemy had one hall (14 lines).
   - the Crown keeps "reading the enemy as NORMAL (a standard opening)" while it is being destroyed (base_highmoor_crcw_r0
     9:09 and 13:18).

## What to fix first (by the design principles: fairness, then anti-snowball)

1. **The Crown computer** (fairness): it is the only side that cannot win against anyone and does not lead on any map.
   OPTIMAL picks Balanced against the Brood and the Clockwork almost every time and that never works; the picks that do
   work for it (Economy, Timing) only appear in the mirror. Start with what OPTIMAL picks for the Crown in the cross
   matchups and its economy (0.65 of the others' income at 5:00 already), then the hall it rebuilds into the enemy (item 3).
2. **The start spot advantage** (fairness): P1 won 44 to 25 over all games (16-8 in mirrors). Check the start layouts of
   Red Coast, Frostfang, Ashfall, Redrock Canyon and Mirewood (P1 ahead) and Thornwood Maze and Amberfall Vale (P2 ahead)
   with tools/test_start_layout.gd and a mirror-only rerun with more seeds before changing anything.
3. **Rebuilding a hall where it was just lost** (anti-snowball): a beaten side pours its last gold into sites the enemy
   kills, which turns a lost base into a lost game. Wait until the spot is clear, or pick another spot.
4. **Crown units shut in their own main** (stuck groups at the same tiles on Hollowfen, Thornwood Maze, Twin Crowns,
   Dune Sea): replay the four games named above and look at the gate and palisade there.
5. **Dead sides and unfinished games**: a side with no workers, no army and no way to make them (no hall, no money) could
   count as beaten, and the winner should hunt the last buildings; otherwise every study counts finished games as draws.
6. **The two script errors** (ai_crown_siege.gd:501, ballista.gd:400): small guards.
7. **The AI STORY wording**: "riders" for Brood and Clockwork units, "only 100% left", ramp/gate holds whose numbers
   say the opposite, and the army reckoning.
8. The Brood's early raids (a median 2:55, 44 of 151 thrown away) are a cost it can afford today; not urgent while the
   Brood is the strongest side, but they are wasted grubs' worth of biomass.

# Tables (tools/study/qa_matches_report.py)

Games read: 258 (base 228, plans 24, 4-player 6), failed 0. Version(s): 0.33.7.

## Base games: win rates per matchup (OPTIMAL v OPTIMAL)

W-D-L is the first-named faction's (in a mirror: the P1 start spot's). Draws led: who was ahead at 15:00 (income + 2 x army, 10% margin) as first / even / second. Round 0 and round 1 are the two seeds of each map, with the sides swapped between them.

| matchup | games | W-D-L | won or led | draws led (1st/even/2nd) | round 0 W-D-L | round 1 W-D-L | same result both rounds | mean length (decided) |
|---|---|---|---|---|---|---|---|---|
| Crown v Brood | 38 | 0-13-25 | 0 | 0/0/13 | 0-6-13 | 0-7-12 | 6 of 19 maps | 13:13 (25) |
| Crown v Clockwork | 38 | 1-34-3 | 4 | 3/0/31 | 1-16-2 | 0-18-1 | 15 of 19 maps | 13:17 (4) |
| Brood v Clockwork | 38 | 14-22-2 | 23 | 9/3/10 | 8-10-1 | 6-12-1 | 7 of 19 maps | 13:00 (16) |
| Crown v Crown (mirror) | 38 | 2-36-0 | 17 | 15/4/17 | 1-18-0 | 1-18-0 | 17 of 19 maps | 13:58 (2) |
| Brood v Brood (mirror) | 38 | 14-16-8 | 21 | 7/3/6 | 6-9-4 | 8-7-4 | 11 of 19 maps | 12:29 (22) |
| Clockwork v Clockwork (mirror) | 38 | 0-38-0 | 19 | 19/6/13 | 0-19-0 | 0-19-0 | 19 of 19 maps | - |

## Economy ratios (base games, cross matchups)

First-named faction's mean over the second's, over the games still running at that minute (n).

| matchup | income 5:00 | 8:00 | 10:00 | 15:00 | army 5:00 | 8:00 | 10:00 | 15:00 | workers 8:00 | halls 8:00 (1st / 2nd) |
|---|---|---|---|---|---|---|---|---|---|---|
| Crown v Brood | 0.90 (38) | 0.68 (38) | 0.63 (38) | 0.48 (13) | 1.01 (38) | 0.71 (38) | 0.57 (38) | 0.27 (13) | 0.53 | 1.9 / 3.4 |
| Crown v Clockwork | 0.65 (38) | 0.65 (38) | 0.67 (38) | 0.58 (34) | 0.33 (38) | 0.31 (38) | 0.27 (38) | 0.11 (34) | 0.93 | 1.9 / 2.4 |
| Brood v Clockwork | 0.66 (38) | 0.79 (38) | 0.99 (37) | 1.11 (22) | 0.80 (38) | 0.80 (38) | 0.67 (37) | 0.61 (22) | 1.41 | 3.1 / 2.1 |

Spread between games (what is noise): the first-named faction's income ratio per game.

| matchup | income ratio 8:00 min-max (sd) | 10:00 | army ratio 10:00 |
|---|---|---|---|
| Crown v Brood | 0.45-1.01 (sd 0.14) | 0.31-0.96 (sd 0.15) | 0.00-3.06 (sd 0.64) |
| Crown v Clockwork | 0.42-1.07 (sd 0.15) | 0.35-1.48 (sd 0.21) | 0.00-5.29 (sd 0.89) |
| Brood v Clockwork | 0.41-1.25 (sd 0.20) | 0.47-1.50 (sd 0.27) | 0.14-14.57 (sd 3.27) |
| Crown v Crown (P1/P2) | 0.68-1.44 (sd 0.17) | 0.57-2.00 (sd 0.27) | 0.10-6.33 (sd 1.35) |
| Brood v Brood (P1/P2) | 0.88-2.80 (sd 0.39) | 0.72-2.51 (sd 0.42) | 0.06-6.44 (sd 1.95) |
| Clockwork v Clockwork (P1/P2) | 0.86-1.24 (sd 0.07) | 0.90-1.30 (sd 0.09) | 0.00-48.00 (sd 11.10) |

Each faction's own numbers (base games, every opponent): mean income / workers / army / halls.

| faction | games | income 5:00 | 8:00 | 10:00 | 15:00 | workers 8:00 | army 8:00 | army 10:00 | halls 8:00 | halls 15:00 |
|---|---|---|---|---|---|---|---|---|---|---|
| Crown | 152 | 2422 | 5102 | 7665 | 12863 | 26 | 718 | 1147 | 1.9 | 2.2 |
| Brood | 152 | 2420 | 5842 | 9347 | 17423 | 37 | 872 | 1344 | 3.2 | 3.4 |
| Clockwork | 152 | 3950 | 8343 | 11426 | 17979 | 28 | 1548 | 2304 | 2.6 | 3.9 |

## On the brood-nerf-study's five maps (to compare with docs/brood_nerf_study.md, 0.33.6, FOOD_BONUS 1.2)

| matchup (subject first) | games | W-D-L | won or led | income ratio 8:00 | army ratio 8:00 |
|---|---|---|---|---|---|
| Brood v Crown | 10 | 8-2-0 | 10 | 1.48 | 1.64 |
| Brood v Clockwork | 10 | 4-6-0 | 6 | 0.74 | 0.97 |
| Crown v Clockwork | 10 | 0-9-1 | 1 | 0.62 | 0.29 |

## Game length (base games)

| matchup | decided | before 8:00 | 8:00-12:00 | after 12:00 | draws at 15:00 | shortest |
|---|---|---|---|---|---|---|
| Crown v Brood | 25 | 0 | 6 | 19 | 13 | 10:21 |
| Crown v Clockwork | 4 | 0 | 0 | 4 | 34 | 12:06 |
| Brood v Clockwork | 16 | 0 | 2 | 14 | 22 | 9:58 |
| Crown v Crown | 2 | 0 | 0 | 2 | 36 | 13:22 |
| Brood v Brood | 22 | 0 | 11 | 11 | 16 | 10:17 |
| Clockwork v Clockwork | 0 | 0 | 0 | 0 | 38 | - |

## Per map (base games)

Each cell: the first-named faction's results on that map over its two games (W/D/L letters, round 0 then round 1; lower case = a draw it led (w) or trailed (l)). START SPOT: in all of that map's games, wins (and won-or-led) by the P1 spot against the P2 spot.

| map | Cr v Br | Cr v Cw | Br v Cw | Cr v Cr (P1) | Br v Br (P1) | Cw v Cw (P1) | P1 spot W-L (won or led) | mirrors P1 W-L |
|---|---|---|---|---|---|---|---|---|
| amberfall_vale | lL | ll | WW | ld | lL | lw | 2-2 (4-7) | 0-1 |
| ashfall | Ll | ll | lw | ww | lw | wl | 1-0 (8-4) | 0-0 |
| ashford_crossing | Ll | ll | Wd | lw | WL | dw | 2-2 (5-5) | 1-1 |
| border_march | lL | ll | ww | lw | LL | wl | 0-3 (5-7) | 0-2 |
| cinder_steps | LL | ll | lL | dl | WW | lw | 4-1 (6-5) | 2-0 |
| dune_sea | LL | wl | wW | ll | Wl | ww | 2-2 (7-5) | 1-0 |
| frostfang | Ll | Ll | Lw | ww | dW | ww | 4-0 (9-2) | 1-0 |
| frostmere | Ll | ll | WW | ll | WW | ll | 4-1 (5-7) | 2-0 |
| glimmerdeep | LL | ll | lw | lw | WW | ww | 3-1 (7-5) | 2-0 |
| greenhold | LL | ll | Ww | dd | dl | wd | 2-1 (4-4) | 0-0 |
| highmoor | LL | ll | lW | wW | ww | ll | 3-1 (8-4) | 1-0 |
| hollowfen | lL | ll | ld | ll | Ll | dw | 0-2 (4-6) | 0-1 |
| kestrel_rise | LL | Ll | lW | lw | wW | ll | 2-3 (5-7) | 1-0 |
| mirewood | lL | ll | Wl | ww | LW | wd | 3-1 (8-3) | 1-1 |
| red_coast | Ll | ll | Wl | Ww | wW | ww | 3-1 (10-2) | 2-0 |
| redrock_canyon | lL | Wl | ww | lw | WW | dw | 4-0 (8-3) | 2-0 |
| saltmarsh_isles | Ll | ll | lW | wl | wd | ld | 2-0 (6-4) | 0-0 |
| thornwood_maze | Ll | wL | Wl | ll | LL | lw | 1-4 (2-10) | 0-2 |
| twin_fords | lL | wl | Wd | wl | wl | wl | 2-0 (7-4) | 0-0 |

All base games: the P1 spot won 44, the P2 spot 25 (won or led 118 - 94); in the mirrors alone P1 16 - P2 8 (won or led 57 - 44).

Per map, each faction's record in its cross games (won-or-led of games, with the income ratio at 8:00 against its opponents):

| map | Crown | Brood | Clockwork |
|---|---|---|---|
| amberfall_vale | 0 of 4, 0.66 | 4 of 4, 1.37 | 2 of 4, 1.18 |
| ashfall | 0 of 4, 0.61 | 3 of 4, 1.15 | 3 of 4, 1.68 |
| ashford_crossing | 0 of 4, 0.66 | 3 of 4, 1.16 | 2 of 4, 1.39 |
| border_march | 0 of 4, 0.62 | 4 of 4, 1.24 | 2 of 4, 1.43 |
| cinder_steps | 0 of 4, 0.78 | 2 of 4, 1.06 | 4 of 4, 1.56 |
| dune_sea | 1 of 4, 0.78 | 4 of 4, 1.10 | 1 of 4, 1.28 |
| frostfang | 0 of 4, 0.72 | 3 of 4, 0.98 | 3 of 4, 1.52 |
| frostmere | 0 of 4, 0.51 | 4 of 4, 1.68 | 2 of 4, 1.31 |
| glimmerdeep | 0 of 4, 0.66 | 3 of 4, 1.20 | 3 of 4, 1.38 |
| greenhold | 0 of 4, 0.63 | 4 of 4, 1.22 | 2 of 4, 1.46 |
| highmoor | 0 of 4, 0.69 | 3 of 4, 1.00 | 3 of 4, 1.61 |
| hollowfen | 0 of 4, 0.70 | 2 of 4, 0.97 | 3 of 4, 1.61 |
| kestrel_rise | 0 of 4, 0.58 | 3 of 4, 1.28 | 3 of 4, 1.53 |
| mirewood | 0 of 4, 0.76 | 3 of 4, 0.91 | 3 of 4, 1.54 |
| red_coast | 0 of 4, 0.60 | 3 of 4, 1.09 | 3 of 4, 1.76 |
| redrock_canyon | 1 of 4, 0.67 | 4 of 4, 1.21 | 1 of 4, 1.38 |
| saltmarsh_isles | 0 of 4, 0.85 | 3 of 4, 1.07 | 3 of 4, 1.16 |
| thornwood_maze | 1 of 4, 0.61 | 3 of 4, 1.27 | 2 of 4, 1.41 |
| twin_fords | 1 of 4, 0.73 | 3 of 4, 1.05 | 1 of 4, 1.48 |

## First attacks (base games)

The first time a computer marks itself attacking; 90 s later: units lost each side, enemy buildings razed. 'Paid' = it razed a building or killed more units than it lost; 'thrown away' = it lost more than twice what it killed and razed nothing.

| faction | attacks | median time | earliest | paid | thrown away | games with no attack by 15:00 |
|---|---|---|---|---|---|---|
| Crown | 114 | 7:45 | 3:30 | 85 of 113 | 11 | 38 |
| Brood | 151 | 2:55 | 2:35 | 66 of 151 | 44 | 1 |
| Clockwork | 0 | - | - | 0 of 0 | 0 | 151 |

First ENEMY ARRIVAL in each base (300+ enemy army value within 500 px of the side's buildings or rooted creatures; it counts the Clockwork's pushes too, which never mark themselves attacking). 90 s later: units lost by each, the defender's buildings lost. 'Attacker paid' = the defender lost buildings or more units than the attacker.

| attacker | arrivals | median time | earliest | attacker paid | defender held (attacker lost 2x more, no building) | games with no arrival by 15:00 |
|---|---|---|---|---|---|---|
| Crown | 103 | 9:00 | 4:00 | 83 | 6 | 49 |
| Brood | 143 | 8:10 | 4:10 | 61 | 50 | 9 |
| Clockwork | 131 | 6:20 | 4:00 | 74 | 21 | 20 |

## Halls lost (base games)

| faction | games | halls lost (built) | lost unbuilt (sites) | games losing 3+ | most in one game | same spot lost twice or more |
|---|---|---|---|---|---|---|
| Crown | 152 | 171 | 60 | 36 | 7 (base_border_march_crcw_r1) | 7 |
| Brood | 152 | 0 | 0 | 0 | 0 () | 0 |
| Clockwork | 152 | 133 | 24 | 29 | 7 (base_greenhold_brcw_r0) | 0 |

The Brood has no halls: its 'ground' (the Queen plus its rooted expansions) shrank 109 times in 60 of 152 Brood sides (lost or uprooted; the tool cannot tell which); Brood Queens killed (Brood side out of the game): 24.

## Other plans against OPTIMAL (one game each)

| plan | opponent (OPTIMAL) | map | result for the plan | end | income ratio 8:00 | army ratio 10:00 | first attack |
|---|---|---|---|---|---|---|---|
| Brood air | Clockwork | highmoor | draw, led | 15:00 | 1.21 | 0.83 | 7:05 |
| Brood balanced | Brood | thornwood_maze | lost | 11:06 | 0.98 | 0.19 | 7:20 |
| Brood brute | Clockwork | frostfang | won | 13:31 | 0.95 | 1.14 | 10:25 |
| Brood economy | Crown | mirewood | draw, led | 15:00 | 1.34 | 0.88 | 8:40 |
| Brood rush | Clockwork | amberfall_vale | lost | 10:23 | 0.48 | 0.08 | 3:20 |
| Brood spitter | Brood | frostmere | won | 14:48 | 0.84 | 1.45 | 7:00 |
| Brood timing | Brood | saltmarsh_isles | draw, led | 15:00 | 1.01 | 2.91 | 6:00 |
| Brood xrush | Crown | red_coast | draw, led | 15:00 | 0.72 | 0.63 | 2:00 |
| Crown balanced | Crown | greenhold | draw, behind | 15:00 | 0.94 | 2.51 | 9:15 |
| Crown balloon | Crown | twin_fords | draw, behind | 15:00 | 0.55 | 0.66 | 11:10 |
| Crown dragoon | Brood | ashford_crossing | lost | 12:56 | 0.60 | 0.21 | none |
| Crown economy | Clockwork | glimmerdeep | draw, behind | 15:00 | 0.88 | 0.62 | 10:40 |
| Crown rush | Brood | border_march | lost | 13:31 | 0.62 | 0.37 | 3:25 |
| Crown siege | Clockwork | cinder_steps | draw, even | 15:00 | 0.73 | 1.05 | none |
| Crown timing | Crown | dune_sea | draw, behind | 15:00 | 0.69 | 0.66 | 8:10 |
| Clockwork balanced | Clockwork | kestrel_rise | draw, led | 15:00 | 0.95 | 1.66 | none |
| Clockwork cs_rush | Crown | dune_sea | won | 11:34 | 3.27 | 48.42 | none |
| Clockwork economy | Brood | ashfall | draw, led | 15:00 | 1.10 | 8.43 | none |
| Clockwork heavy | Brood | border_march | draw, led | 15:00 | 0.79 | 1.09 | none |
| Clockwork owls | Brood | ashford_crossing | lost | 11:09 | 0.60 | 0.13 | none |
| Clockwork pendulum | Crown | greenhold | draw, led | 15:00 | 1.12 | 1.80 | none |
| Clockwork rush | Crown | hollowfen | lost | 11:30 | 0.71 | 0.00 | none |
| Clockwork springer | Clockwork | glimmerdeep | lost | 10:12 | 0.52 | 0.01 | none |
| Clockwork timing | Clockwork | redrock_canyon | draw, led | 15:00 | 1.04 | 2.66 | none |

## What OPTIMAL picked (base games)

The build each OPTIMAL side was playing at 5:00 and at 15:00 (or the end), and how those sides did.

| faction | build at 5:00 | sides | won or led | at the end (most common) |
|---|---|---|---|---|
| Crown | balanced | 82 | 7 | balanced 65, economy 16 |
| Crown | economy | 23 | 13 | economy 20, siege 2 |
| Crown | dragoon | 19 | 6 | dragoon 14, economy 5 |
| Crown | timing | 14 | 8 | timing 9, economy 4 |
| Crown | siege | 7 | 2 | siege 6, economy 1 |
| Crown | rush | 7 | 2 | rush 5, economy 1 |
| Brood | balanced | 100 | 52 | balanced 67, economy 23 |
| Brood | timing | 25 | 19 | timing 19, brute 4 |
| Brood | brute | 11 | 11 | brute 9, economy 2 |
| Brood | spitter | 9 | 9 | spitter 7, economy 2 |
| Brood | rush | 7 | 5 | balanced 4, economy 3 |
| Clockwork | balanced | 116 | 50 | balanced 98, heavy 10 |
| Clockwork | springer | 13 | 8 | springer 11, heavy 2 |
| Clockwork | economy | 12 | 12 | economy 11, heavy 1 |
| Clockwork | heavy | 7 | 7 | heavy 7 |
| Clockwork | cs_rush | 2 | 0 | cs_rush 2 |
| Clockwork | pendulum | 1 | 1 | pendulum 1 |
| Clockwork | owls | 1 | 0 | owls 1 |

## 4-player games

| game | players (side) | end | winner | income at the end | army at the end | halls at the end |
|---|---|---|---|---|---|---|
| 2v2_ember_reach_1 | P1 Clockwork (0), P2 Crown (0), P3 Brood (1), P4 Clockwork (1) | 15:00 | none | 20811 / 9500 / 15471 / 10613 | 9720 / 0 / 3820 / 2625 | 5 / 1 / 2 / 3 |
| 2v2_jade_wilds_1 | P1 Brood (0), P2 Clockwork (0), P3 Crown (1), P4 Brood (1) | 15:00 | none | 14020 / 15630 / 15080 / 3082 | 2465 / 6745 / 0 / 0 | 3 / 4 / 0 / 0 |
| 2v2_twin_crowns_1 | P1 Crown (0), P2 Brood (0), P3 Clockwork (1), P4 Crown (1) | 15:00 | none | 15460 / 16748 / 12156 / 3800 | 3855 / 3665 / 825 / 0 | 3 / 4 / 1 / 0 |
| ffa_greenhold_1 | P1 Crown (0), P2 Brood (1), P3 Clockwork (2), P4 Crown (3) | 15:00 | none | 7600 / 17280 / 18791 / 8360 | 0 / 1365 / 1960 / 1105 | 0 / 3 / 4 / 2 |
| ffa_highmoor_1 | P1 Brood (0), P2 Clockwork (1), P3 Crown (2), P4 Brood (3) | 15:00 | none | 17374 / 13871 / 10140 / 18866 | 4495 / 0 / 1545 / 1930 | 4 / 1 / 1 / 4 |
| ffa_red_coast_1 | P1 Clockwork (0), P2 Crown (1), P3 Brood (2), P4 Clockwork (3) | 15:00 | none | 17715 / 9760 / 20314 / 14740 | 3735 / 1305 / 4520 / 0 | 4 / 2 / 4 / 0 |

## Problems seen

### Stalls (every game)

bank_unspent: 400+ gold in the bank and nothing spent for 60 s or more; no_units: no unit made for 90 s or more after 2:30 while under the supply cap; army_idle_enemy_in_base: 300+ enemy army value within 500 px of its buildings while its own army (4+ units, 300+ value, under a quarter of it fighting) moved under 40 px (median) in 60 s.

| kind | faction | count | games | longest |
|---|---|---|---|---|
| army_idle_enemy_in_base | Clockwork | 1 | 1 | 100s (2v2_twin_crowns_1 P3 at 11:20, enemy 1540 in base, army 965 (9 units) still) |
| army_idle_enemy_in_base | Crown | 5 | 5 | 90s (base_hollowfen_crcw_r1 P1 at 7:30, enemy 1015 in base, army 535 (8 units) still) |
| bank_unspent | Clockwork | 1 | 1 | 99s (base_frostfang_cwcw_r0 P2 at 13:00, bank 451) |
| bank_unspent | Crown | 9 | 8 | 240s (base_frostmere_crcw_r0 P2 at 11:00, bank 693) |
| no_units | Clockwork | 13 | 13 | 134s (base_dune_sea_crcw_r0 P2 at 12:45, bank 16 supply 6/60) |
| no_units | Crown | 10 | 10 | 275s (base_highmoor_crcw_r0 P2 at 10:25, bank 395 supply 8/24) |

Longest stalls (to replay: map and seed are in the tag's result.json):

- base_highmoor_crcw_r0 (map highmoor seed 1104) P2 Crown 10:25: no_units for 275s (bank 395 supply 8/24)
- plan_cw-cs_rush_v_cr_dune_sea (map dune_sea seed 5122) P2 Crown 6:40: no_units for 259s (bank 0 supply 9/36)
- base_frostmere_crcw_r0 (map frostmere seed 1146) P2 Crown 11:00: bank_unspent for 240s (bank 693)
- base_glimmerdeep_crcw_r1 (map glimmerdeep seed 1180) P2 Crown 11:45: bank_unspent for 195s (bank 540)
- base_red_coast_crbr_r1 (map red_coast seed 1161) P2 Crown 12:00: no_units for 175s (bank 0 supply 41/74)
- base_hollowfen_crcr_r1 (map hollowfen seed 1191) P1 Crown 12:30: no_units for 149s (bank 0 supply 45/78)
- base_red_coast_crcw_r1 (map red_coast seed 1162) P2 Crown 12:30: bank_unspent for 149s (bank 400)
- base_dune_sea_crcw_r0 (map dune_sea seed 1107) P2 Clockwork 12:45: no_units for 134s (bank 16 supply 6/60)
- base_dune_sea_cwcw_r1 (map dune_sea seed 1148) P2 Clockwork 11:30: no_units for 125s (bank 48 supply 10/60)
- base_cinder_steps_crcw_r1 (map cinder_steps seed 1186) P2 Crown 12:50: no_units for 114s (bank 40 supply 1/50)
- base_amberfall_vale_crbr_r1 (map amberfall_vale seed 1191) P2 Crown 12:35: no_units for 109s (bank 0 supply 35/82)
- base_cinder_steps_cwcw_r1 (map cinder_steps seed 1190) P2 Clockwork 13:10: no_units for 109s (bank 93 supply 27/100)
- base_saltmarsh_isles_brcw_r1 (map saltmarsh_isles seed 1178) P2 Clockwork 12:25: no_units for 106s (bank 0 supply 42/100)
- base_frostfang_cwcw_r0 (map frostfang seed 1114) P2 Clockwork 13:15: no_units for 104s (bank 451 supply 4/80)
- plan_cw-timing_v_cw_redrock_canyon (map redrock_canyon seed 5118) P2 Clockwork 13:15: no_units for 104s (bank 0 supply 19/70)
- 2v2_twin_crowns_1 (map twin_crowns seed 7201) P3 Clockwork 11:20: army_idle_enemy_in_base for 100s (enemy 1540 in base, army 965 (9 units) still)
- base_border_march_cwcw_r0 (map border_march seed 1126) P2 Clockwork 13:20: no_units for 99s (bank 9 supply 5/80)
- base_cinder_steps_cwcw_r0 (map cinder_steps seed 1153) P1 Clockwork 13:20: no_units for 99s (bank 42 supply 20/70)
- base_frostfang_cwcw_r0 (map frostfang seed 1114) P2 Clockwork 13:00: bank_unspent for 99s (bank 451)
- base_kestrel_rise_cwcw_r1 (map kestrel_rise seed 1172) P1 Clockwork 13:20: no_units for 99s (bank 60 supply 23/80)
- base_mirewood_cwcw_r0 (map mirewood seed 1123) P2 Clockwork 13:20: no_units for 99s (bank 0 supply 12/100)
- base_redrock_canyon_crcw_r0 (map redrock_canyon seed 1137) P2 Clockwork 10:30: no_units for 96s (bank 53 supply 0/30)
- base_ashford_crossing_crcw_r0 (map ashford_crossing seed 1128) P2 Crown 11:15: no_units for 95s (bank 535 supply 12/24)
- base_ashford_crossing_crcw_r0 (map ashford_crossing seed 1128) P2 Crown 12:00: bank_unspent for 95s (bank 535)
- base_frostfang_crcw_r0 (map frostfang seed 1110) P2 Crown 11:50: bank_unspent for 95s (bank 437)

### Units stuck on a move order (30 s+ without moving 8 px, not fighting, not at the goal)

Total 82 in 39 games.

| unit | faction | count | maps |
|---|---|---|---|
| musketeer | Crown | 26 | twin_crowns 14, hollowfen 8, thornwood_maze 2, ashford_crossing 1 |
| cannon | Crown | 15 | twin_crowns 2, amberfall_vale 2, cinder_steps 2, dune_sea 2 |
| clock_soldier | Clockwork | 9 | mirewood 4, ashford_crossing 2, ember_reach 1, frostfang 1 |
| dragoon | Crown | 8 | thornwood_maze 8 |
| powder_wagon | Crown | 5 | border_march 2, twin_crowns 1, ashfall 1, cinder_steps 1 |
| grub | Brood | 3 | amberfall_vale 2, mirewood 1 |
| cuirassier | Crown | 3 | amberfall_vale 1, ashford_crossing 1, dune_sea 1 |
| spitter | Brood | 3 | ashfall 1, frostmere 1, ashford_crossing 1 |
| cuckoo | Clockwork | 2 | ember_reach 1, ashford_crossing 1 |
| pendulum | Clockwork | 2 | ashford_crossing 1, redrock_canyon 1 |
| springer | Clockwork | 2 | glimmerdeep 2 |
| ballista | Clockwork | 1 | ashfall 1 |
| great_winder | Clockwork | 1 | hollowfen 1 |
| netter | Clockwork | 1 | red_coast 1 |
| brood_mother | Brood | 1 | frostmere 1 |

Spots where units got stuck in more than one case: twin_crowns (16, 20) x9; hollowfen (22, 16) x8; thornwood_maze (14, 20) x6; thornwood_maze (21, 15) x4; twin_crowns (15, 20) x3; twin_crowns (23, 9) x2; dune_sea (20, 15) x2; highmoor (19, 29) x2

Examples: 2v2_ember_reach_1 P4 clock_soldier 8:30 at (67, 32) -> (61, 32) (move); 2v2_ember_reach_1 P4 cuckoo 12:20 at (79, 84) -> (82, 168) (move); 2v2_twin_crowns_1 P1 cannon 8:40 at (21, 15) -> (143, 70) (amove); 2v2_twin_crowns_1 P1 musketeer 11:00 at (16, 20) -> (90, 117) (amove); 2v2_twin_crowns_1 P1 musketeer 11:10 at (16, 20) -> (91, 114) (amove); 2v2_twin_crowns_1 P1 musketeer 11:20 at (16, 20) -> (92, 114) (amove); 2v2_twin_crowns_1 P1 musketeer 11:20 at (15, 20) -> (91, 116) (amove); 2v2_twin_crowns_1 P1 musketeer 11:20 at (16, 20) -> (91, 115) (amove); 2v2_twin_crowns_1 P1 musketeer 11:20 at (16, 20) -> (91, 115) (amove); 2v2_twin_crowns_1 P1 musketeer 11:20 at (16, 20) -> (91, 117) (amove); 2v2_twin_crowns_1 P1 musketeer 11:40 at (23, 9) -> (32, 11) (move); 2v2_twin_crowns_1 P1 musketeer 11:50 at (23, 9) -> (32, 12) (move)

### AI STORY lines that the game does not bear out

| rule | lines | games | example |
|---|---|---|---|
| riders / Horse Breeder named against a Brood enemy (it has neither) | 1220 | 68 | base_amberfall_vale_brbr_r0: `[06:36] P2 Brood finds 3 riders in its land at 6:36: Raptors now, its grubs kept beside them.` |
| expansion: 'its best base has ONLY 90-100% left' (the line gives a reason that is not one) | 482 | 156 | base_amberfall_vale_crcr_r0: `[08:09] P2 Crown expands to fresh land: its best base has only 92% left, so it goes 18 tiles out.` |
| riders / Horse Breeder named against a Clockwork enemy (it has neither) | 213 | 41 | base_amberfall_vale_cwcw_r0: `[06:33] P2 Clockwork's push does not chase 1 fast rider(s) (125): the march goes on.` |
| ramp hold: 'the force below is more than its army can beat' with the force below SMALLER or equal | 205 | 74 | base_amberfall_vale_crbr_r0: `[08:57] P1 Crown holds the top of its ramp: the force below (484) is more than its army (820) can beat.` |
| army first: the enemy army it reckons is off by 1.5x or more (measured bigger) | 105 | 47 | base_amberfall_vale_crcr_r0: `[06:54] P1 Crown puts its army first (255 against the 506 it reckons the enemy has): the labourers and the tech wait.  [measured enemy army 825]` |
| gate hold: 'the force outside is too strong' with the force outside SMALLER or equal | 47 | 32 | base_ashfall_crcr_r1: `[06:19] P1 Crown holds the gate of its walled natural: the force outside (115) is too strong to go out and meet with its army (120).` |
| army first: the enemy army it reckons is off by 1.5x or more (measured smaller) | 41 | 21 | base_amberfall_vale_crcr_r0: `[04:54] P1 Crown puts its army first (0 against the 185 it reckons the enemy has): the labourers and the tech wait.  [measured enemy army 120]` |
| GREEDY (no army) read while the enemy had 250+ army value | 24 | 11 | base_ashford_crossing_brbr_r0: `[06:46] P1 Brood reads the enemy as GREEDY (no army and no production at its base).  [measured 1350]` |
| GREEDY (a second base) read while the enemy had one hall | 14 | 7 | base_border_march_crcr_r0: `[03:12] P2 Crown reads the enemy as GREEDY (a second base and little army).` |

### Script errors and failed games

4 games printed error lines; 0 games failed (no result).

- 201x: `SCRIPT ERROR: Left operand of 'is' is a previously freed instance.  at: AICrownSiege._siege_set (res://scripts/ai_crown_siege.gd:501)` (first in base_glimmerdeep_crcr_r0)
- 9x: `SCRIPT ERROR: Invalid call. Nonexistent function 'has_tag' in base 'Nil'.  at: _worth (res://scripts/ballista.gd:400)` (first in base_amberfall_vale_cwcw_r1)

