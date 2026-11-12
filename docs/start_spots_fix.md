# Start spots fix (job start-spots-fix, 2026-11-11/12, version 0.33.17)

The owner approved (2026-11-11 22:28) the fixes proposed by docs/start_spots_study.md: mirror the starting units exactly,
give the computers one base anchor (the hall's centre), then run the study again. This job did that, followed every
difference the probe still showed in the first minutes back to its cause and mirrored that too, and played the 120
mirror games again (same maps, matchups, seeds, swaps and length; `docs/start_spots_fix/data`, run 2). An edge left for the
Brood led to a last set of Brood fixes and the 40 Brood mirrors once more (`docs/start_spots_fix/data_run3`, run 3). The
FINAL numbers below are run 2's Crown and Clockwork games (run 3's changes touch only the Brood) and run 3's Brood games.

Words as in the study: **spot A** = the map's first start (top / top-left), **spot B** its mirror; **index 0** = the first
player of the match setup. **Won or led** = won, or led a 15:00 draw by 10% on income + 2 x army value.

## The answer in short

1. **The starts are exact mirrors now**, on every map, faction and player count (tools/test_start_layout.gd checks it
   for every built-in map, 2 players and as many as the map holds, Crown, Clockwork and Brood), and so are the first
   minutes: each side's income matches its twin's to 1-2% until the armies first meet (before: the Brood on spot A earned
   19% less at 1:00 on the classic maps, 14% on the named ones; the Clockwork 2% less at 1:00 and 4-6% more after).
2. **The computers aim at the hall's centre** (`Game.start_mid`) in all 29 places the study listed and two more.
3. **No start-spot edge is left that the games can tell from chance** (final, 120 games):

   | group | games | before (0.33.11): spot A won or led - trailed - even | final | final, player index 0 |
   |---|---|---|---|---|
   | all | 120 | 55-54-11 (50%) | 60-51-9 (54%, p 0.45) | 56-55-9 (50%) |
   | classic maps | 60 | **37-16-7 (70%, p 0.01)** | 31-24-5 (56%, p 0.42) | (the same: index 0 = spot A) |
   | named maps | 60 | **18-38-4 (32%, p 0.01)** | 29-27-4 (52%, p 0.89) | 25-31-4 (45%, p 0.50) |

   The QA study's "P1 44-25" was the classic maps' edge; it is down from 70% to 56% (no longer significant), and the
   named maps' edge for spot B is gone. The per-faction picture: the Crown and the Clockwork mirrors show no spot edge
   (Crown 17-20-3, Clockwork 17-18-5); **the Brood mirror still leans to spot A, 26-13-1 (67%, p 0.05)**, map by map
   rather than one way across the board (section 3).
4. **What is left** is not a screen rule any more but the Brood's (and to a lesser extent everyone's) game following the
   same path on a map every time: two mirrored sides drift apart by a fraction of a pixel at about 8 s, the drift grows
   through the computers' choices, and because the first minutes do not depend on the seed, every round of a map ends
   the same way. Section 3 has the evidence and two proposals.

## 1. What changed

**The idea.** Every rule that picks one of several equal choices by screen order (scan the map top to bottom, left to
right; "the cell below"; a footprint whose feet hang below its middle; a fixed list of directions) gives the two starts of
a mirrored map different answers. Each such choice now runs in the **first start's frame** and is carried back through
the map's mirror, so the first start does exactly what it did before and its mirror twin does the mirror image.

- `Game.start_flip` / `start_canon` (game.gd, "the mirrored start"): at the start of a match the map's terrain is tested
  for its mirrors (point mirror, left-right, top-bottom; height, cliffs, ramps and water must match, trees and rocks to 2%);
  each start that a mirror carries onto an earlier (top-left-most) start gets that flip. 4-player maps get their own flips
  per corner, maps with two point-mirror pairs two sets; a map that is no mirror (campaign, editor) keeps (0, 0) for
  everyone, which is the old behaviour. Helpers: `sym_pt`, `sym_dir`, `sym_rect`, `sym_cell`, `sym_off`, and
  `start_mid(t)` (the hall's centre).
- **The start** (`_start_positions`, `find_start_spot`): the workers' row is laid in the first start's frame (it was
  -60..+30 px on both spots: one worker off the mirror); the starting Farm / Cog Press scan runs in that frame, so ties
  fall the mirrored way (Amberfall Vale's Farm was 15 tiles off its mirror, the Cog Press 6-7 tiles on five maps).
- **The Brood's start** (brood_new.gd `start`, `_maw_start_spot`): the Mother, her Rootmaw and the grubs are placed as the
  first start places them and mirrored back footprint and all (`BroodRoot.feet_k` / `sym_snap`): spot B's nest was half a
  tile off and its grubs two tiles farther out.
- **The computers' anchor**: the 29 places the study listed (plus `AIHunt`'s "their main" and `Game.center_of_team`'s
  fallback) use `Game.start_mid(t)`, the hall's centre, not its top-left cell (the back corner for spot A, the front
  corner for spot B).
- **Walking** (`Game.find_path` / `grid_path`): the pathfinder breaks ties between equally short ways in a fixed order, so
  two mirrored walks took different ways. A mirrored side now asks a mirrored copy of the grid (`_mir_grids`, kept in step
  by `astar_set`), and `nearest_free` / `nearest_free_level` look round in its reading order.
- **Screen-order choices of the game**: where a trained unit steps out (`spawn_trained`: "below the building"), the
  nearest free cell round a building (`approach_point`), the computers' building spots (`find_spot`), the Clockwork's gear
  spots (`GearEcon.room_spot_n` / `room_cells`, `GearNet.ring_spot`, and the fixed directions the Clockwork computer asks it
  for: `AI._sdeg`), the Crown's base lattice and Farm spots (`AICrownLayout`) and its ramp wall (`_ramp_bands`,
  `_wall_off`, `plan_cottage_wall`).
- **The Brood's footprints hang below their middle on screen**, so the Brood's sums from a creature's feet differed by
  spot. Now from the feet the first start's frame would give it (`BroodRoot.anchor`): the swamp's middle (spot B's swamp lay
  a tile and a half off toward its back: its scouting grub left the swamp, and its speed, two seconds early), a Rootmaw
  load's pay by its distance from the Mother (`load_value`: "a load from farther pays more" paid spot A's Rootmaw above
  its Mother more than spot B's below hers), and the Brood computer's spots for Rootmaws, Mound Turtles and fathers. Her
  eggs land on the mirrored side of her nest; units are numbered per side (`Unit.tserial`), so the grubs' places round a
  Rootmaw and the ticks they shove on match.
- **The grubs take food at the Rootmaw's side** (`BroodNew.flank_point`): it was the footprint's screen-left side, which
  faced the Mother on one spot and turned its back on her on the other; it is now the side sideways to the way to the
  Mother (the middle of the two old walks), picked in the first start's frame.
- **The Brood computer** (run 3): its guard posts, rally and stage points round the Mother (`_qp`: her feet as the first
  start reads them; "below her" turned with the start), its turtle spots (`ExpansionSpots.nb_rate` / `_maw_room`: the
  turtle's footprint in a hall spot was rounded and searched in screen order, a tile off its mirror).
- A worker fleeing a raid (`AI._flee_spot`) broke ties at the 500 px cap by a pixel's rounding; now the farthest point
  from the raid wins (tools/test_ai_scout_threat.gd failed by 3 px on that).

**What the probe shows now** (`tools/start_spots_mirror_probe.gd`, the units of the two sides matched one for one and
carried back through the mirror; `tools/start_spots_probe.gd` for the incomes): the two starts are identical at the first
frame on every map and faction (tools/test_start_layout.gd), and

the incomes of the two sides at the minute marks match until their armies first meet (`tools/start_spots_probe.gd`,
seed 2; spot A's income over spot B's):

| faction, map | 1:00 before (study) | 1:00 now | 2:00 now | 3:00 now |
|---|---|---|---|---|
| Brood, Greenhold / Red Coast | 0.81 | 1.01 | 0.98 | 1.01 |
| Brood, Thornwood Maze | 0.86 (named maps) | 1.00 | 1.09 | 1.03 |
| Brood, Kestrel Rise | 0.86 | 1.01 | 0.96 | 0.99 |
| Brood, Amberfall Vale | 0.86 | 1.02 | 0.98 | 1.01 |
| Clockwork, Greenhold | 0.98 (2:00 1.04) | 1.00 | 1.03 | |
| Clockwork, Kestrel Rise | 0.98 | 1.00 | 0.92 | |
| Crown, Red Coast / Amberfall Vale | 1.00 | 1.00 | 1.00 | 1.00 |

(the Clockwork at 2:00 and the Brood's Thornwood at 2:00: the scouts have met and fought by then; see section 3.)

## 2. The study again

Run 2: all 120 games, version 0.33.17 before the last Brood fixes (`tools/study/start_spots_fix_compare.py`; full output
`docs/start_spots_fix/compare_run2.md`, the study's own report `report_run2.md`). Spot A's record, won or led - trailed or
lost - even (its share of the non-even games, two-sided binomial p); "change p" is Fisher's exact test of before against
after.

| map | named? | before: spot A | run 2: spot A | run 2: Crown / Brood / Clockwork by round | change p |
|---|---|---|---|---|---|
| amberfall_vale | yes | 2-8-2 (20%, p 0.11) | 4-8-0 (33%, p 0.39) | lwlL / wLWl / LLlw | 0.65 |
| ashfall | no | 10-1-1 (91%, p 0.01) | 6-3-3 (67%, p 0.51) | dlWl / Wwwl / WddW | 0.28 |
| ashford_crossing | yes | 3-9-0 (25%, p 0.15) | 6-6-0 (50%, p 1.00) | wlLw / wwww / llLL | 0.40 |
| frostfang | no | 8-3-1 (73%, p 0.23) | 7-4-1 (64%, p 0.55) | llwL / LwWw / WWWd | 1.00 |
| greenhold | no | 4-5-3 (44%, p 1.00) | 7-3-2 (70%, p 0.34) | Lwww / wwWd / LwdL | 0.37 |
| kestrel_rise | yes | 6-6-0 (50%, p 1.00) | 3-8-1 (27%, p 0.23) | Llwl / LWLL / WdLL | 0.40 |
| mirewood | no | 4-6-2 (40%, p 0.75) | 7-5-0 (58%, p 0.77) | lwwl / wWWW / LLWL | 0.67 |
| red_coast | no | 11-1-0 (92%, p 0.01) | 9-3-0 (75%, p 0.15) | lLww / WWWW / wwwL | 0.59 |
| redrock_canyon | yes | 5-7-0 (42%, p 0.77) | 10-1-1 (91%, p 0.01) | ldWw / WwWW / WWwW | 0.03 |
| thornwood_maze | yes | 2-8-2 (20%, p 0.11) | 5-6-1 (45%, p 1.00) | ldww / lwlw / WlLL | 0.36 |

| group | games | before: spot A | run 2: spot A | run 2: player index 0 | change p |
|---|---|---|---|---|---|
| all | 120 | 55-54-11 (50%, p 1.00) | 64-47-9 (58%, p 0.13) | 63-48-9 (57%, p 0.18) | 0.34 |
| classic maps | 60 | 37-16-7 (70%, p 0.01) | 36-18-6 (67%, p 0.02) | (the same) | 0.84 |
| named maps | 60 | 18-38-4 (32%, p 0.01) | 28-29-3 (49%, p 1.00) | 27-30-3 (47%, p 0.79) | 0.09 |
| named, index 0 on spot A | 30 | 8-21-1 (28%, p 0.02) | 14-16-0 (47%, p 0.86) | | 0.18 |
| named, index 0 on spot B | 30 | 10-17-3 (37%, p 0.25) | 14-13-3 (52%, p 1.00) | 13-14-3 | 0.41 |
| Crown mirrors | 40 | 14-20-6 (41%, p 0.39) | 17-20-3 (46%, p 0.74) | | 0.81 |
| Brood mirrors | 40 | 22-16-2 (58%, p 0.42) | **30-9-1 (77%, p 0.00)** | 26-13-1 (67%, p 0.05) | 0.09 |
| Clockwork mirrors | 40 | 19-18-3 (51%, p 1.00) | 17-18-5 (49%, p 1.00) | 20-15-5 | 1.00 |
| Brood, classic maps | 20 | 14-4-2 (78%, p 0.03) | 17-2-1 (89%, p 0.00) | (the same) | 0.40 |
| Brood, named maps | 20 | 8-12-0 (40%, p 0.50) | 13-7-0 (65%, p 0.26) | 9-11-0 (45%, p 0.82) | 0.20 |

Early economy, spot A's income over spot B's (geometric mean), before -> run 2:

| faction | maps | 1:00 | 2:00 | 3:00 | 5:00 | 8:00 | 12:00 |
|---|---|---|---|---|---|---|---|
| Crown | classic | 1.00 -> 1.00 | 1.00 -> 1.00 | 1.00 -> 1.00 | 0.98 -> 0.98 | 0.93 -> 0.98 | 0.99 -> 0.96 |
| Crown | named | 1.00 -> 1.00 | 1.00 -> 1.00 | 1.00 -> 1.00 | 0.98 -> 1.01 | 0.91 -> 1.03 | 0.82 -> 0.95 |
| Brood | classic | **0.81 -> 1.01** | 0.85 -> 0.99 | 0.90 -> 1.01 | 1.07 -> 1.03 | **1.38 -> 1.11** | 1.42 -> 1.29 |
| Brood | named | **0.86 -> 1.01** | 0.90 -> 1.01 | 0.98 -> 1.01 | 1.03 -> 1.00 | 1.03 -> 1.05 | 1.05 -> 1.11 |
| Clockwork | classic | 0.98 -> 1.00 | 1.04 -> 1.02 | 1.02 -> 1.01 | 1.06 -> 1.06 | 1.02 -> 1.04 | 1.02 -> 1.05 |
| Clockwork | named | 0.98 -> 1.00 | 1.03 -> 0.98 | 1.02 -> 0.98 | 1.03 -> 0.99 | 1.00 -> 1.00 | 0.98 -> 0.97 |

The mirror gap of the two mains (each of spot B's main buildings, mirrored back, to the nearest same kind on spot A):
Crown 2.3 -> 0.9 tiles at 4:00 (3.6 -> 2.7 at 8:00), Clockwork 2.8 -> 1.1 (5.0 -> 2.0).

**A side effect to know**: the Clockwork mirrors are decided far more often (25 of 40 games, before 4 of 40; halls lost
95 / 82, before 59 / 70). The computers' "their main" was the enemy hall's corner: the Clockwork's push (ai_cw_push.gd
"within 700 px of their main", its goal) now aims at the hall itself and finishes the job. The Crown mirrors: 8 decided
of 40 (5 before).

**Run 2 left the Brood leaning to spot A** (30-9-1, still 17-2 on the classic maps), with its economy equal for five
minutes. The probe found what the last fixes (section 1, the Brood computer's posts and turtle spots) then mirrored:
`tools/start_spots_mirror_probe.gd -- diff:1` showed spot B's Brood rooting its first Mound Turtle a tile off its mirror
(the turtle spot's rounding in ExpansionSpots.nb_rate, 23 against 25 tiles out in the games' stories), and the Brood
computer's guard posts and rally points sat "below the Mother on screen": in front of her for spot A on the classic maps
(the enemy comes from below-right), behind her for spot B. Run 3, the 40 Brood mirrors again with those fixed:

| Brood mirrors | games | before | run 2 | run 3 (final) | run 3, player index 0 |
|---|---|---|---|---|---|
| all | 40 | 22-16-2 (58%) | 30-9-1 (77%, p 0.00) | 26-13-1 (67%, p 0.05) | 19-20-1 (49%) |
| classic maps | 20 | 14-4-2 (78%, p 0.03) | 17-2-1 (89%, p 0.00) | 12-8-0 (60%, p 0.50) | (the same) |
| named maps | 20 | 8-12-0 (40%) | 13-7-0 (65%) | 14-5-1 (74%, p 0.06) | 7-12-1 (37%) |

By map (run 3, spot A by round): Amberfall Vale WwLl, Ashfall lwlW, Ashford Crossing LWWW, Frostfang wlwW, Greenhold
lwlw, Kestrel Rise WWWW, Mirewood WWll, Red Coast lwww, Redrock Canyon WWWW, Thornwood Maze LWld.

**FINAL** (run 2's Crown and Clockwork, run 3's Brood), by map:

| map | before | final |
|---|---|---|
| amberfall_vale | 2-8-2 (20%, p 0.11) | 4-8-0 (33%, p 0.39) |
| ashfall | 10-1-1 (91%, p 0.01) | 5-4-3 (56%, p 1.00) |
| ashford_crossing | 3-9-0 (25%, p 0.15) | 5-7-0 (42%, p 0.77) |
| frostfang | 8-3-1 (73%, p 0.23) | 7-4-1 (64%, p 0.55) |
| greenhold | 4-5-3 (44%, p 1.00) | 6-5-1 (55%, p 1.00) |
| kestrel_rise | 6-6-0 (50%, p 1.00) | 6-5-1 (55%, p 1.00) |
| mirewood | 4-6-2 (40%, p 0.75) | 5-7-0 (42%, p 0.77) |
| red_coast | 11-1-0 (92%, p 0.01) | 8-4-0 (67%, p 0.39) |
| redrock_canyon | 5-7-0 (42%, p 0.77) | **10-1-1 (91%, p 0.01)** |
| thornwood_maze | 2-8-2 (20%, p 0.11) | 4-6-2 (40%, p 0.75) |

and by group in "The answer in short". Redrock Canyon's 10-1 is the one map below p 0.05; with ten maps tested one
such map is expected about two times in five by chance alone (p 0.01 x 10 maps = 0.1 after the Bonferroni correction),
and it was 5-7 before; worth a look in the next study, not proof of a map fault.

## 3. What is left

**The Brood's lean to spot A (26-13-1, p 0.05) and single maps' one-sided records are the same game played again,
not a rule that favours a corner.** The evidence:

- **The early game does not depend on the seed.** The probe on Red Coast with seeds 2, 3 and 9 gives the same incomes to
  the coin until 2:00 (565 / 574 at 2:00 in all three); the rounds of the study use new seeds but replay the same first
  minutes, so the 4 rounds of a map are close to 1 sample, and the 9 classic maps (one shape, "nearly one map", the
  study's section 1) are close to one more. The binomial p values above treat every game as independent and are too
  small for that reason.
- **The two sides drift apart by less than a pixel at about 8 s and the computers' choices grow it.** On Red Coast the
  first difference is a grub's step at 8.5 s (11.69 against 11.87 px/s: the shove of its neighbours, worked out as floating
  point sums in screen order); from there which grub goes to grow the Tyrant Sire's lure, and when, differs by a second,
  the lure lands a tile apart, the rush at 2:48 meets the defence a little differently, and by 7:00 one side earns 10-20%
  more. With the computer turned off (a probe run whose computer script failed to load) the two sides stayed within 2%
  for 7 minutes and earned the same to the coin from 3:30 on.
- **The sign follows the map, not the corner and not the player index.** Red Coast: spot A ahead at 7:00 with seeds 2,
  3 and 9 (1.23, 1.20, 1.02). Thornwood Maze: spot B ahead at 8:00 whichever index stands on it (index 0 on spot A:
  0.61; index 0 on spot B: index 0 ahead 1.24, i.e. spot B again). In run 3 the leaning maps go both ways (Kestrel Rise
  and Redrock Canyon WWWW for spot A, Thornwood Maze LWld) and index 0 is 19-20.

Proposals for the owner (not done here: they change how the game plays or how the studies run):

1. **Studies**: count a map's rounds as one sample unless the early game differs between them; for a fair test, vary
   the early game (a different start for the AI's think timer per seed, or a pixel of random jitter on the first unit
   moves in the study tool) and treat the classic maps as one map.
2. **The game**: let the match seed decide the tiny early differences instead of the map, e.g. a seeded, unseen random
   jitter in the units' shoving or the computers' think timers. Then each game's luck is a coin flip, not the map's;
   the start itself is already a mirror.

Smaller things seen:

- Script errors in the games: `Invalid access to property or key 'team' on a base object of type 'Nil'` in two of run
  2's first games: a slip of this job (BroodNew.crew_max lost its "no Mother" guard), fixed after game 37 (it only struck
  once the Mother was dead). The study's old two (`has_tag` on Nil, "previously freed instance") came once each, as
  before.
- tools/test_ai_expand_wall.gd failed on Ashford Crossing with its seed 7 (36% of the ways in shut 180 s after the hall,
  needs 50%): the same plan as on main, the wall a minute later because the Crown built 3 more soldiers after 5:00 (its
  Brood opponent now stands mirrored). With seed 8 it passes on this branch (71%) and on main too (52%).
- tools/test_ai_cw_horse_raid.gd and tools/test_ai_rush_followup.gd fail on main as well (1 and 13 checks there, 2 and
  12 here).

## Tests

- tools/test_start_layout.gd: PASS (every map, 2 players and the most, every faction; the new mirror check included).
- All 23 tools/test_ai_*.gd: pass except the three above (two fail on main too; expand_wall is the seed-7 case);
  tools/test_ai_scout_threat.gd failed by 3 px before the flee tie-break and passes now. tools/test_ai_brood.gd and
  tools/test_expansion_spots.gd pass after the run-3 Brood fixes.
- Godot ends most headless tests with exit code 134 after ALL PASS: the same on main (a quit-time abort, not a failure).

Tools added: `tools/start_spots_mirror_probe.gd` (the two sides matched unit for unit, the first gap, `diff:1` for
buildings and rooted creatures), `tools/study/start_spots_fix_compare.py` (before / after tables with Fisher's test),
`tools/study/start_spots_games.py --facs` (a subset of the mirrors). Rerun: `GODOT=godot python3
tools/study/start_spots_games.py run OUT --data DATA --jobs 2 --rounds 4`, then `start_spots_fix_compare.py BEFORE DATA`
(about 2.7 hours on two CPUs).
