# Start spots study (job start-spots, 2026-11-11, version 0.33.11)

The question (owner, 2026-11-11, from docs/qa_2026_11_08_matches.md point 5): the P1 start spot won 44 games to 25 in
the QA match study. Is that real, and why? A study only: no game or computer change. Tools and data:

- `tools/start_spots_geo.gd` + `tools/study/start_spots_geo.sh` + `tools/study/start_spots_geo_report.py`: the
  geometry of every 2-player map (19 maps, 2 seeds, Crown and Clockwork starts), data in `docs/start_spots_study/geo/`.
- `tools/start_spots_match.gd` (tools/qa_match.gd plus a base layout record once a minute) and
  `tools/study/start_spots_games.py`: the mirror games, data in `docs/start_spots_study/data/<tag>/` (result.json,
  layout.json, story.txt, meta.json says which player index stood on spot A).
- `tools/start_spots_probe.gd`: the first minutes of a mirror game, every start unit of side B mirrored back beside
  side A's, income every 5 s.
- `tools/study/start_spots_report.py --qa` writes every table; its full output is `docs/start_spots_study/report.md`.

Words used here. **Spot A** = the map's first start (top or top-left: the old "P1 spot"); **spot B** = its mirror
(bottom or bottom-right). **Index 0** = the first player in the match setup: it is ticked first, its computer thinks
first, its units are made first. In every QA game index 0 stood on spot A, so the two could not be told apart.
**Won or led** = won, or led a 15:00 draw by 10% on income earned + 2 x army value (the QA study's rule). **Classic
maps** = the 9 maps made by the classic generator (Greenhold, Highmoor, Dune Sea, Frostfang, Twin Fords, Ashfall,
Mirewood, Border March, Red Coast); **named maps** = the 10 hand-laid ones (Ashford Crossing, Kestrel Rise, Thornwood
Maze, Redrock Canyon, Saltmarsh Isles, Glimmerdeep, Frostmere, Cinder Steps, Hollowfen, Amberfall Vale).

## The answer in short

1. **The edge is real, but it is a CLASSIC MAP edge, not a "P1" edge.** On the classic maps spot A won or led 37 of 53
   non-even mirror games here (decided 11-4; p = 0.005) and 66 of 101 in the QA study's games (p = 0.003). Together
   103 to 51 (p < 0.0001). On the **named maps it is the other way round**: spot B won or led 38 of 56 here (p = 0.01);
   the QA study had them about even (A 52, B 59). The QA study's overall 44-25 is the classic maps' edge diluted by the
   named maps.
2. **It is the spot, not the player index.** On the named maps half the games put index 0 on spot B (the side number
   trick, MapGen.spot_order). Index 0 won or led 25 of 56 there (p = 0.5): nothing. Spot B won or led 38 of 56 in the
   same games. The early economy numbers follow the spot to the coin whichever index stands on it (see 3). So who
   ticks first or thinks first gives no measurable edge.
3. **The maps are perfect mirrors; the game's START is not.** Every 2-player map is an exact point mirror in every
   terrain layer (height, cliff, ramp, water, trees and rocks: 0 cells off on all 19 maps, both seeds), and its starts,
   naturals and all base sites are mirrored, with equal walks, ramps, room, naturals, thirds and chokes (table below).
   But the starting units and buildings are not mirrored, and the first minutes' income differs by spot, the same in
   every game:
   - **Brood**: the Mother and her Rootmaw are snapped half a tile differently on the two spots, and the grubs' row is
     put two tiles farther out on spot B. Spot A's Brood earns **19% less at 1:00, 15% less at 2:00** (classic maps;
     14% / 10% on named maps), then a different opening follows and on the classic maps spot A ends far ahead (1.39x
     the income at 8:00).
   - **Clockwork**: the starting Winders' row is one Winder (30 px) off the mirror; spot A earns 2% less at 1:00 and
     then **4-6% more from 2:00 to 5:00**, on every map (not from the gears turning: the same with TURNING GEARS off,
     and not from the Winders' row: the same with the row mirrored, a local experiment, not committed).
   - **Crown**: the starting Farm stands one tile off its mirror (on Amberfall Vale 15 tiles: the same side of the
     hall on screen for both); spot B's first harvests land about 15 s sooner, the income is equal at the minute marks
     until 5:00.
   - **The computers use the hall's TOP-LEFT cell as "our base" / "their main" in 29 places** (`Vector2(game.starts[t])
     * Defs.TILE`), while 52 other places use its centre. For spot A that cell is the back corner of its hall, for
     spot B the front corner (toward the enemy): attack goals, scout targets, home posts and "near their main" checks
     are 2-3 tiles different between the spots.
4. **Which maps.** Clearest here: Red Coast (A won or led 11 of 12), Ashfall (10 of 12) and Frostfang (8 of 12) for
   spot A; Ashford Crossing (B 9 of 12), Thornwood Maze (B 8 of 10) and Amberfall Vale (B 8 of 10) for spot B. Mirewood
   and Redrock Canyon (P1 maps in the QA study) did not repeat it (4-6, 5-7), nor did the controls Greenhold (4-5) and
   Kestrel Rise (6-6). With 12 games a map a single map's number is a hint; the classic/named split is the solid part.
5. **The fix is in the code, not in the tiles** (no map has a tile, ramp or resource to move): mirror the start
   exactly, and use the hall's centre in the computers' sums; then run this study again. Details at the end.

## 1. Geometry: every 2-player map is an exact mirror

`tools/start_spots_geo.gd` reads each map at the first frame of a real match. **Terrain mirror** counts the cells whose
height, cliff, ramp, water, terrain or tree/rock kind differs from the point-mirrored cell. Walks are land steps
(ExpansionSpots._steps, 4 ways) from round each hall. **Natural / third** = the side's nearest and second nearest base
site: walk / safety (the enemy's walk minus its own) / room (ExpansionSpots._room). **Choke** = the thinnest band of
near-shortest routes (8 steps slack) on each side's half of the way in. Seed 2300 (2341 gives the same except where
noted); spot A / spot B shown only where they differ: they never do.

| map | terrain mirror (cells off) | starts, naturals, sites mirrored | walk main to main | ramp (width, cells) | main plateau (open cells) | room of the main | natural walk / safe / room | third walk / safe | choke (A half / B half) | start buildings off their mirror (tiles) |
|---|---|---|---|---|---|---|---|---|---|---|
| greenhold | 0 | yes | 138 | 3, 12 | 484 | 0.72 | 22 / 97 / 0.81 | 38 / 55 | 6 / 6 | Crown farm 1, Clockwork 0 |
| highmoor | 0 | yes | 138 | 3, 12 | 484 | 0.72 | 23 / 95 / 0.83 | 40 / 53 (seed 2341: 38 / 55) | 6 / 6 | 1, 0 |
| dune_sea | 0 | yes | 138 | 3, 12 | 484 | 0.72 | 22 / 97 / 0.81 | 38 / 55 | 6 / 6 | 1, 0 |
| frostfang | 0 | yes | 138 | 3, 12 | 484 | 0.72 | 23 / 95 / 0.83 | 38 / 55 | 6 / 6 | 1, 0 |
| twin_fords | 0 | yes | 138 | 3, 12 | 484 | 0.72 | 22 / 97 / 0.81 | 33 / 65 | 6 / 6 | 1, 0 |
| ashfall | 0 | yes | 138 | 3, 12 | 484 | 0.72 | 23 / 95 / 0.83 | 38 / 55 | 6 / 6 | 1, 0 |
| mirewood | 0 | yes | 138 | 3, 12 | 484 | 0.72 | 22 / 97 / 0.81 | 33 / 65 | 6 / 6 | 1, 0 |
| border_march | 0 | yes | 138 | 3, 12 | 484 | 0.72 | 22 / 97 / 0.81 | 33 / 65 | 6 / 6 | 1, 0 |
| red_coast | 0 | yes | 138 | 3, 12 | 484 | 0.72 | 23 / 95 / 0.83 | 38 / 55 | 6 / 6 | 1, 0 |
| ashford_crossing | 0 | yes | 180 | 3, 12 | 506 | 0.76 | 27 / 133 / 0.77 | 51 / 85 | 4 / 4 | 1, 1 |
| kestrel_rise | 0 | yes | 130 | 3, 12 | 372 | 0.55 | 17 / 93 / 0.67 | 38 / 47 | 5 / 5 | 0, Clockwork cog press 6 |
| thornwood_maze | 0 | yes | 156 | 3, 12 | 445 | 0.66 | 20 / 115 / 0.74 | 43 / 63 | 6 / 6 | 1, 0 |
| redrock_canyon | 0 | yes | 136 | 3, 12 | 496 | 0.72 | 24 / 81 / 0.97 | 36 / 87 | 6 / 6 | 0, 6 |
| saltmarsh_isles | 0 | yes | 168 | 3, 12 | 445 | 0.66 | 17 / 133 / 0.63 | 47 / 97 | 7 / 7 | 0, 0 |
| glimmerdeep | 0 | yes | 164 | 3, 12 | 410 | 0.61 | 18 / 126 / 0.73 | 44 / 69 | 5 / 5 | 0, 0 |
| frostmere | 0 | yes | 166 | 3, 12 | 437 | 0.65 | 19 / 127 / 0.75 | 45 / 84 | 6 / 6 | 0, 6 |
| cinder_steps | 0 | yes | 124 | 3, 12 | 420 | 0.62 | 17 / 87 / 0.65 | 37 / 43 | 5 / 5 | 1, 7 |
| hollowfen | 0 | yes | 174 | 3, 12 | 479 | 0.72 | 18 / 136 / 0.72 | 41 / 85 | 7 / 7 | 1, 0 |
| amberfall_vale | 0 | yes | 146 | 3, 12 | 496 | 0.74 | 24 / 94 / 0.96 | 48 / 104 | 5 / 5 | **15**, 6 |

- **Flyers**: the straight line between the halls is the same from both ends on every map (a point mirror).
- **Resources**: each base site's soil / brass / ground is the same, and every site is mirrored, so each side has the
  same amounts at the same walks. Trees and rocks round the halls: mirrored (0 kind cells off).
- **High ground**: the main plateaus are the same size; no natural has main-plateau cells within 10 tiles of its
  middle on any map (the naturals are below and away), the same for both spots.
- **The classic maps are nearly one map**: the same main, ramp, natural and choke at the same walks (138 steps between
  the mains); they differ in biome, random woods (mirrored) and the third bases.
- **"Start buildings off their mirror"**: the starting Farm / Cog Press stands at the same distance from the hall on
  both spots (7.02 tiles on the classic maps) but not on the mirrored cell: the placement's tie-break picks the same
  side ON SCREEN for both (Amberfall Vale: the Crown's Farm goes to the hall's left on both spots, 15 tiles from where
  the mirror would put it; Cinder Steps / Frostmere / Kestrel Rise / Redrock Canyon / Amberfall Vale: the Cog Press 6-7
  tiles). Same distance, so the walk is equal; only the side differs.

## 2. The mirror games

Crown v Crown, Brood v Brood, Clockwork v Clockwork, Hard OPTIMAL both sides, to 15:00, on the 7 suspect maps and 3
controls (Greenhold, Ashford Crossing, Kestrel Rise): 4 rounds x 10 maps x 3 mirrors = **120 games, all finished**
(no crash, no hang; ~2.2 minutes of real time a game, two at once). Every round uses new seeds. On the named maps
rounds 1 and 3 are SWAPPED (index 0 on spot B); on the classic maps index 0 is always on spot A (the classic generator
gives index 0 the first spot whatever the side number, so the swap is not possible there without a game change).

Each cell: spot A's record, W-L in decided games | won or led - trailed or lost - even | two-sided binomial p of the
won-or-led split (small p = unlikely to be chance). The letters per faction are spot A's results by round (W/L won /
lost, w/l led / trailed a draw, d even).

| map | games | spot A | Crown | Brood | Clockwork | index 0 instead |
|---|---|---|---|---|---|---|
| red_coast (classic) | 12 | 4-0 \| 11-1-0 \| 0.01 | wWlw | wWWW | wwww | (same as spot A) |
| ashfall (classic) | 12 | 2-0 \| 10-1-1 \| 0.01 | wlww | wWwW | wwdw | (same) |
| frostfang (classic) | 12 | 4-1 \| 8-3-1 \| 0.23 | Wdwl | wWWW | Lwwl | (same) |
| mirewood (classic) | 12 | 0-2 \| 4-6-2 \| 0.75 | dwll | dLwL | lwwl | (same) |
| greenhold (classic, control) | 12 | 1-1 \| 4-5-3 \| 1.00 | dwdL | Wlld | wllw | (same) |
| redrock_canyon (named) | 12 | 2-2 \| 5-7-0 \| 0.77 | llww | LWWL | lllw | 2-2 \| 5-7-0 |
| thornwood_maze (named) | 12 | 1-3 \| 2-8-2 \| 0.11 | Llll | wLLW | ddll | 1-3 \| 5-5-2 |
| amberfall_vale (named) | 12 | 1-2 \| 2-8-2 \| 0.11 | wdld | WLlL | llll | 3-0 \| 6-4-2 |
| ashford_crossing (named, control) | 12 | 0-5 \| 3-9-0 \| 0.15 | lLlw | LLLL | llww | 3-2 \| 5-7-0 |
| kestrel_rise (named, control) | 12 | 6-1 \| 6-6-0 \| 1.00 | llll | WWLW | lWWW | 2-5 \| 4-8-0 |

| group | games | spot A: W-L \| won-or-led - trailed - even \| p | index 0: the same |
|---|---|---|---|
| all 120 | 120 | 21-17 \| 55-54-11 \| 1.00 | 22-16 \| 62-47-11 \| 0.18 |
| **classic maps** (index 0 = spot A) | 60 | **11-4 \| 37-16-7 \| 0.005** | (same) |
| **named maps, not swapped** (index 0 = A) | 30 | 4-6 \| 8-21-1 \| 0.02 | 4-6 \| 8-21-1 |
| **named maps, swapped** (index 0 = B) | 30 | 6-7 \| 10-17-3 \| 0.25 | 7-6 \| 17-10-3 \| 0.25 |
| named maps, both | 60 | 10-13 \| 18-38-4 \| 0.01 | index 0: 25-31 \| p 0.50 |
| Crown mirrors | 40 | 2-3 \| 14-20-6 \| 0.39 | 3-2 \| 18-16-6 |
| Brood mirrors | 40 | 16-13 \| 22-16-2 \| 0.42 | 18-11 \| 24-14-2 |
| Clockwork mirrors | 40 | 3-1 \| 19-18-3 \| 1.00 | 1-3 \| 20-17-3 |

The QA match study's games read the same way (index 0 was always spot A there; `report.md`, last tables):

| QA study (0.33.7) | games | spot A won or led - trailed - even | p |
|---|---|---|---|
| classic maps, all base games (cross games too) | 108 | 66-35-7 | 0.003 |
| named maps, all base games | 120 | 52-59-9 | 0.57 |
| classic maps, mirrors | 54 | 32-16-6 | 0.03 |
| named maps, mirrors | 60 | 25-28-7 | 0.78 |

**Is it noise?** The classic-map edge: no (103 to 51 over both studies, p < 0.0001). The named-map edge for spot B: 
probably real but smaller and less sure (here p = 0.01, the QA study even; together 70 of 167 for A, p = 0.04).
Single maps: noise is large. The QA study's own check found the same map and seed played twice agree about 2 times in
3; here two P1 maps of the QA study (Mirewood, Redrock Canyon) did not repeat. Red Coast, Ashfall and Frostfang did,
and Thornwood Maze and Amberfall Vale did for spot B.

**Faction by faction**: the Brood mirror carries most of it (classic maps: spot A won or led 14 of 20 Brood games,
with Red Coast, Ashfall and Frostfang 12 of 12; Ashford Crossing: spot B 4 of 4). The Clockwork mirror on the classic
maps: A won or led 13 of 20 (nearly all draws; Red Coast 4 of 4). The Crown mirror shows no clear spot edge
(14-20-6).

## 3. Why: the early game is not mirrored

Spot A's income over spot B's at each minute (geometric mean over the games). The first minutes are close to
deterministic (the same numbers come back game after game), and they **follow the spot, not the index** (the
swapped rows match the unswapped ones):

| faction | games | 1:00 | 2:00 | 3:00 | 5:00 | 8:00 | 12:00 |
|---|---|---|---|---|---|---|---|
| Crown, classic maps | 20 | 1.00 | 1.00 | 1.00 | 0.99 | 0.93 | 0.99 |
| Crown, named, index 0 on A | 10 | 1.00 | 1.00 | 1.00 | 0.96 | 0.90 | 0.76 |
| Crown, named, index 0 on B | 10 | 1.00 | 1.00 | 1.00 | 0.99 | 0.91 | 0.89 |
| Brood, classic maps | 20 | **0.81** | **0.85** | 0.90 | 1.07 | **1.39** | 1.42 |
| Brood, named, index 0 on A | 10 | **0.86** | 0.90 | 0.97 | 1.07 | 1.11 | 1.03 |
| Brood, named, index 0 on B | 10 | **0.86** | 0.90 | 0.99 | 1.00 | 0.95 | 1.07 |
| Clockwork, classic maps | 20 | 0.98 | **1.04** | 1.02 | **1.06** | 1.02 | 1.02 |
| Clockwork, named, index 0 on A | 10 | 0.98 | 1.04 | 1.02 | 1.03 | 1.03 | 1.00 |
| Clockwork, named, index 0 on B | 10 | 0.98 | 1.03 | 1.02 | 1.02 | 0.98 | 0.96 |

What `tools/start_spots_probe.gd` finds at the first frame (spot B's units mirrored back through the map's centre;
on a true mirror they would sit on spot A's):

| faction | spot A | spot B mirrored back | effect |
|---|---|---|---|
| Brood (Greenhold, Thornwood) | Mother (400, 328), Rootmaw (176, 184), grubs in a row at y 374 | Mother (400, 312), Rootmaw (176, 168), grubs at y 438 | the nest is half a tile (16 px) off (BroodRoot.snap of an even footprint) and the grubs start two tiles farther out (the row is placed 22 px past the nest's footprint: BELOW it for spot A, ABOVE it for spot B, and the footprint hangs from the creature's feet, so the two are not mirrors: brood_new.gd `start`). Spot B's first food comes 5 s later but then it earns ~25% faster: 188 v 234 at 1:00 on every classic map |
| Clockwork | Winders at x 276, 306, 336, 366 | x 306, 336, 366, 396 | the row of 4 workers runs -60 to +30 px from the hall's middle for both spots (game.gd `_start_positions`: `Vector2(-60 + i * 30, ±80)`), so it is 30 px off the mirror. The buildings are mirrored exactly (also at 2:05). Mirroring the row in a local copy did NOT remove spot A's +5% at 2:00, nor did TURNING GEARS off: the Clockwork's difference comes from somewhere in its workers' play (left for a follow-up) |
| Crown | labourers 340-430; Farm centre (384, 96) | labourers 370-460; Farm (416, 96) | the same row; the Farm 1 tile off its mirror (the start layout's tie-break); spot B's harvests land ~15 s sooner (45 s v 60 s, 105 v 120, 195 v 210) |

**The computers' base anchor.** 29 places in the computers take the hall's top-left cell as a world point
(`Vector2(game.starts[t]) * Defs.TILE`; ai.gd 8, ai_dragoon_raid.gd 4, ai_cw_push.gd 4, ai_scout.gd 3, ai_crown.gd 3,
ai_crown_hold.gd 3, ai_cw_builds_a.gd 2, ai_expand_wall.gd 1, ai_cw_army.gd 1), where 52 others add the hall's
half size (2.5, 2 tiles). For spot A that cell is behind its hall, for spot B in front of it, so for example the
scout heads for spot A's back corner but spot B's front corner (ai_scout.gd 514), the Clockwork push's goal and its
"within 700 px of their main" check (ai_cw_push.gd 369, 374, 886), "their main" for raids (ai.gd 3584, 3615, 7229,
ai_dragoon_raid.gd 137-138) and several "home" points (ai.gd 1419, 4579, 4648; ai_crown.gd 1215, 2283;
ai_crown_hold.gd 563-565) are 2-3 tiles different between the spots. Not measured one by one (a study job may not
change the computers); they are the next suspects after the start.

**What it does to the games** (means, `report.md`): on the classic maps spot B loses more halls (Crown 21 v 9,
Clockwork 43 v 29), its Brood reads the enemy no sooner but falls behind from 5:00 (spot A's Brood builds more Rootmaws:
6 v 4 at 8:00 in several games). Spot B's base layout on the classic maps stands slightly farther forward (buildings
more than 4 tiles toward the enemy at 4:00: 2.7 v 2.1 on average over the five classic maps), and two mirrored bases differ by 2-3 tiles a building at 4:00
and 3-6 at 8:00 (the "mirror gap" table): the bases are not mirror images. None of these alone explains the classic
v named difference; the start and the anchor are the parts that are certainly not mirrored.

**Why classic and named maps go opposite ways** is not settled. They differ in shape (the classic maps are 110 x 80
with the mains in opposite corners and the enemy diagonal; the named maps mostly tall, the enemy straight below or
above), and every screen-direction rule above (rows that run left to right, footprints that hang from the feet,
"below the nest" / "above the nest", the top-left cell) lands differently on a diagonal and on a vertical map.

## 4. Is "P1" itself an edge (tick order, first think)?

No, not measurably. On the named maps index 0 stood on spot A in 30 games and on spot B in 30: index 0 won or led
25 of 56 non-even games (p = 0.50), while the spot split stayed (B 38 of 56). The early income numbers are identical
to the coin whichever index stands on a spot (Brood 0.86 at 1:00 both ways; the probe on Thornwood Maze: 185 v 234 at
1:00 with index 0 on A, 234 v 185 with index 0 on B). Who is ticked first, thinks first or spawns first changes
nothing that shows here.

## 5. Suggested fixes (for the owner to approve)

No map needs a tile, ramp or resource moved: every map is an exact mirror. The fixes are in the start and in the
computers, then this study again (`python3 tools/study/start_spots_games.py run OUT --rounds 4`, ~4.5 hours on two
CPUs, and `start_spots_report.py`):

1. **Mirror the start exactly** (all maps): build spot B's starting units and buildings as the point mirror of spot A's
   instead of placing each with screen-direction rules:
   - the workers' row (game.gd `_start_positions`, the `Vector2(-60 + i * 30, ±80)` line): mirror the x offsets on the
     lower spot (or centre the row: `(i - (n - 1) / 2.0) * 30`);
   - the Brood's start (brood_new.gd `start`): snap the Mother and the Rootmaw so their footprints are mirrors, and put
     the grubs the same distance from the Mother's feet on both spots (today "below the footprint" v "above the
     footprint");
   - the starting Farm / Cog Press tie-break (Game.find_start_spot): prefer the mirror of what spot A got.
   A test to keep it: every map, every faction, the start units within 0.5 tile of their mirror and the income at
   1:00 / 2:00 / 3:00 within 2% between the spots (`tools/start_spots_probe.gd` already prints both).
2. **One base anchor for the computers**: a `Game.start_mid(t)` (the hall's centre) used in the 29 places listed in
   section 3.
3. **Then look again at the maps**: if spot A still leads on the classic maps, the next suspect is the Clockwork's
   +5% at 2:00 (its workers' play) and any other screen-order tie-break (scans that go left to right and top to
   bottom). Per map, after 1 and 2: Red Coast, Ashfall, Frostfang (spot A ahead), Ashford Crossing, Thornwood Maze,
   Amberfall Vale (spot B ahead) first.
4. **Meanwhile**: in the lobby, a random spot for each player (if it is not random already) keeps a human from always
   getting the better corner; the computer studies should keep swapping spots between the sides, as qa_matches.py does.

## Problems seen

- No crash, no hang in 120 games. Script errors in 7 games (Clockwork mirrors mostly): `Invalid call. Nonexistent
  function 'has_tag' in base 'Nil'` (1-3 times a game) and `Left operand of 'is' is a previously freed instance` (7 times
  in one game); the runner kept only the message, not the line (docs/start_spots_study/data/*/errors.txt).
- The probe and the layout record are measuring tools only; the one game change tried (the Winders' row mirrored) was a
  local, uncommitted copy and was thrown away.
