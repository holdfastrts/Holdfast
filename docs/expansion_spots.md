# Expansion spots (0.14.95)

The owner asked, on 2026-10-27: "Make the most optimal expansion spots clear in the maps, so people can easily expand to an area that is interesting for base building." Then: "Just make the map positions clear, focusing on Crown and Clockwork for now. Maybe a few tiles in a different colour in each map showing the best expansion places." Not for the Brood: "for Brood it rarely makes sense to change the capital."

## What is shown

- The best free hall spots are tinted on the ground. A spot is the hall's footprint, 5 by 4 cells. That is where a Town Hall or a Clocktower goes.
- Each cell is a warm gold tile over a light brown wash, with a thin dark and gold border round the spot. It reads on grass, heath, sand and snow.
- Each side gets two spots. Its best spot is a little brighter, with a thicker border. The second is fainter.
- The tiles lie on the ground, under units and buildings. The fog covers them like the rest of the ground.
- A spot hides once a building you know of stands on it: yours, an ally's, or an enemy's you have seen. It shows again if that building is gone. A spot hides too when a fallen hall drew its lode out.
- While you place a Town Hall or a Clocktower, the spots are a touch brighter.
- The minimap shows a small gold square on each spot.
- A LABEL on each spot (the owner, 22:09, 0.15.16: the spots must read as such): "OPTIMAL EXPANSION SPOT" on the best, "EXPANSION SPOT" on the second (pt PONTO DE EXPANSÃO IDEAL / PONTO DE EXPANSÃO, es PUNTO DE EXPANSIÓN ÓPTIMO / PUNTO DE EXPANSIÓN), small gold words on a dark pill at the spot's bottom edge. Shown while the camera is at a normal zoom or nearer (0.85 and up) and always while you place a hall or a Mound Turtle; zoomed out it gives way (the gold tiles and minimap squares speak for themselves and the words would clutter). Its size follows the zoom (about 15 px on screen). It is drawn on the game's overlay, as the workers' counts, so it reads on dark maps (ExpansionSpots.draw_labels, from Game._draw_mine_labels). No tooltips.
- Shown to a Crown or a Clockwork player, and when watching (spectator, replay). Not shown to an old-Brood player (it rarely moves its capital).
- THE NEW BROOD (0.15.16; the owner, 21:28 and 22:09) sees its best MOUND TURTLE spots instead (ExpansionSpots.nb_pick): its side's free base sites rated as above, each with the turtle's 3x3 footprint placed in it on level open ground and scored up for the Rootmaw circles that fit round it inside the turtle's swamp (at least 2). Shown: the two best that are fresh ground (no Rootmaw drew half of it out), 15+ tiles from the Mother and from every turtle that already counts as an expansion, with no building or rooted turtle of the side on them. The tint is the turtle's footprint; while placing a Mound Turtle the spots are brighter, each with a faint gold ring for the swamp it would spread, and labelled.
- Settings: SHOW EXPANSION SPOTS, on by default. Portuguese: MOSTRAR LOCAIS DE EXPANSÃO. Spanish: MOSTRAR LUGARES DE EXPANSIÓN.
- Cost: the spots are rated once, when the map is made. The tiles are drawn once. They are redrawn only when a spot is taken or freed, or when you start or stop placing a hall. A look for taken spots runs twice a second over a handful of spots.

## How spots are picked

Code: `scripts/expansion_spots.gd`, `ExpansionSpots.rate`. It runs on the bare map, before any building stands.

1. The candidates are the map's base sites (`Game.base_sites`) that are nobody's start. On a named map an empty main counts too.
2. Each candidate belongs to the side whose main is the fewest steps away by land. A tie between enemies belongs to nobody.
3. Each candidate gets a score:
   - Room: the open, buildable cells joined to the spot on its own ground level, within a hall's economy reach (14 tiles). This is the room for the Crown's Farms and Mill, and for the Clockwork's gear field, which meshes only on one level. Worth up to 100 points.
   - Walk: minus one point per step from its own main.
   - Safety: plus half a point per step it is farther from the enemy's main than from its own (capped).
   - Ways in: minus 6 points for each way in after the first. A way in is a gap in the open land 12 tiles round the spot. Minus a little more for a very wide open front.
4. The two best of each side are marked.

Since 0.30.10 this rating is no side's marks any more, only the computer's list of base sites (AI round 6). The Brood has
its own (Mound Turtle spots, above). The Crown has its own since 0.29.2, redone in 0.29.5 (below). The Clockwork has its
own since 0.30.10 (below, and docs/clockwork_eco.md).

## The Clockwork's rule (0.30.10; the owner, 2026-11-04 20:24)

The owner: "The Clockwork's optimal expansion spot has to be different than it currently is: the Clocktower's gear is very
important, Clocktowers need room around them. So we have 3 different optimal expansion spots, one for each race." Code:
`scripts/clock_sites.gd` (ClockSites), used by the marks (ExpansionSpots._clock_rule, _clock_update) and by the Clockwork
computer's next Clocktower (AIClockwork._safe_hall_spot).

- Candidates: every cell where a Clocktower may stand (any free ground, not only base sites), 18 to 30 tiles from the
  nearest of the side's halls, and nearer the side than the enemy by land.
- THE RING: round the Clocktower's big ring, 3x3 buildings on their small rings (a Cog Press, the Mainspring, the
  Escapement...) are packed one after another, each meshing with the tower's ring directly, each on open ground of the
  Clocktower's own level, off ramps, with its free lane round it, and each off the others' rings. Open ground holds 9.
  A spot short of 8 pays 15 points for each one missing; 2 points back for the 9th.
- THE ROOM BEYOND: the share of the 4-tile band outside that ring (where the next buildings go) that is open ground of the
  same level: up to 50 points.
- Near and safe: half a point a tile past the least hall distance, half a point a step of the walk from the main, and a
  little for being nearer us than the enemy.
- Two marks a side (the 2nd a hall's spacing from the 1st). Worked out again when the side's halls change.
- tools/test_expansion_spots.gd checks every map: the marks have room for 7+ of the ring, and on each side's best spot the
  game itself lets at least 6 of 8 ring buildings be laid (ClockSites.fill_ring).

## The Crown's rule (v2, 0.29.5; the owner, 2026-11-04 07:05)

The owner, first (2026-11-03 22:25): "As Crown I think the optimal expansion positions will be as close as possible to
each other because of walls and trying to use the high ground to our advantage." Then, on the spots that gave (v1,
0.29.2, below): "The first should still be in the same place it was before, just closer. As close to the edge of the map
as possible, because that's good for walling. The second expansion should mirror the first on the other side of the
main. So they should be as close as possible, 18 tiles, as close as possible to the ramp, because it's easier for the
army to reach it and for the workers to reach it, and as close as possible to the edge of the map, so it's easier to wall
it. I don't know why you left the second expansion so far out."

Code: `scripts/crown_sites.gd` (`CrownSites.pick`), used by the gold marks of a Crown side (`ExpansionSpots._crown_rule`,
`_crown_update`) and by the Crown computer's hall pick (`AICrown._safe_hall_spot`). Each faction keeps its own rule.

1. The candidates are any free ground, not only the map's base sites: every hall's land holds the same fresh reserve.
   A spot needs its 5 x 4 cells and the ring round them free, on one level, no ramp within two cells (the computer keeps
   its ramps clear), the economy room round it on its own level (`_room` 30% or more: a spot against the border has
   only half its circle on the map; 30% is still a Mill and its Farms), at least 18 tiles from every hall
   (`Defs.HALL_SPACING`, unchanged), no nearer the enemy by land than us (4 steps of margin), and no lode drawn out by a
   fallen hall.
2. THE MAIN'S RAMP: the ramp nearest the main hall (`CrownSites.ramp_of`); its FOOT is the cells just below it. The
   LINE runs from the main hall's middle through the foot; it splits the ground round the main into two SIDES
   (`CrownSites.side_of`; a spot within 1.5 tiles of the line is on neither).
3. Each spot is scored on the owner's three aims, all three for every stage:
   - close: minus 2 a tile past the least distance (from the MAIN for the 2nd and 3rd; from the nearest hall for the 4th
     on), looked at up to 9 tiles past it; the 2nd 10 more, once, past 5 tiles (0.30.5);
   - near the ramp (2nd and 3rd): minus 1.5 a step of the walk from the ramp's foot (`CrownSites.steps_from`), and past
     12 steps ("far out": so the border never pulls a hall round the main's cliff, away from the ramp) 10 once (0.30.5)
     and 2 more a step;
   - against the border: minus 2 a tile between the hall and the map's border (past the one free cell its ring needs),
     and minus 3 an OPEN side (`CrownSites.open_sides`: a side is shut when the border or ground no army walks comes
     within 3 cells of every cell along it; a hall against the border has 3 open sides);
   - small terms: + 10 x room, + 3 x the share of its sides the main's cliff edge covers (v1's cover, now only a
     tie-breaker), + a little for being farther from the enemy; ties go by where the spot lies seen from the main
     toward the map's middle (it turns with the map).
4. **The 2nd base** (first expansion): on the side of the line where the old rating's natural lies (`ExpansionSpots
   .rate_all` #1, the rule above: "the same place it was before"), picked as one of a MIRRORED PAIR: the best 2nd and the
   best 3rd on the other side a hall's spacing apart, by the sum of their scores (`CrownSites._pair`), so the 2nd never
   takes the ground below the ramp that its mirror needs. The natural on the line itself: both ways round are tried.
5. **The 3rd base**: the other side of the line from the Crown's second hall (wherever that was built), same aims.
   Nothing legal there: the best on either side.
6. **The 4th base on**: as close as possible to the Crown's halls (2 a tile past 18 from the nearest, 1 a tile of the
   mean distance to the others past 18), against the border where it may be (the same border and open-side terms).
7. The marks are worked out on the bare map at the start, and again whenever the side's halls change (for your own side
   and your allies; for every side while watching: an enemy's new hall is not given away by its marks).

The Crown computer picks the same spot (one pick at a time, its own halls counted, built or not), skipping a spot where
its builders were just chased off, where it may not build, on the enemy's side by land, or with enemy soldiers in sight
within 14 tiles; nothing found: the shared pick. Its line holds the cliff edge above a hall under attack there
(docs/crown_cliff_edge.md); a hall against the border below the main's cliff is still often within the line's reach.

Cost: the old (v1) search took 0.8-1.5 s of the computer's frame for its 2nd and 3rd hall; v2 took 0.15-0.35 s for the
first, then 30-100 ms, and 220 ms again after every building (the owner's 0.30.4 log, Redrock Canyon: one frame of
626 ms at 5:14, 586 ms of it the 2nd hall pick). 0.30.5 (tools/time_crown_pick.gd, Redrock Canyon, 2 players): the
field keeps each spot's cheap terms, its economy room and its walks, and drops only what lay near ground that changed
(`Game.solid_log`, written by `Game._mark`; a room only on its own level and within its reach); the 2nd/3rd candidates
are kept in their cheap order; `ExpansionSpots._room` fills a byte grid row by row (0.23 ms a spot, the walk it replaced
0.83, the same room on every spot); and the computer works ahead on its quiet ticks (`CrownSites.warm`,
`AICrown._cs_warm`, 3 ms a tick, each piece at most ~14 ms; about 85 ticks for a new game, 25 after a building by the
candidates). The 2nd hall pick, measured ahead: 6-12 ms (before: 55-65 ms the same call again, 220 ms after a
building); the 3rd: 10 ms, then 2 ms (25 ms). Left: a pick made before the work ahead has caught up (the first ~3 s of
a game, or ~1 s after a building right by the best spots) still measures what is missing itself: 45-130 ms (before
130-285 ms). The picks are the same as working everything out afresh (the timing tool checks each one).

### Measured (tools/measure_crown_spots.gd, 2 players, both Crown, player 1's top-left main; player 2 gets the twins)

"walk" = steps from the main ramp's foot; "border" = tiles from the hall to the map's border; "open" = sides open to wall.
Before = v1 (0.29.4); after = v2.

| map | base | before: spot, from main, walk, border, open | after: spot, from main, walk, border, open |
|---|---|---|---|
| Thornwood Maze | 2nd | (23, 18), 18.0, 9, 18, 4 | (25, 2), 18.0, 5, 2, 3 (top border, north of the ramp, by the natural) |
| | 3rd | (38, 8), 30.0, 10, 8, 4 | (22, 20), 18.4, 12, 20, 4 (south of the ramp) |
| | 4th | (18, 37), 30.7, 33, 18, 4 | (43, 2), 35.5 (18 from the 2nd), 20, 2, 3 |
| Greenhold | 2nd | (27, 14), 18.0, 21, 14, 4 | (1, 24), 18.4, 9, 1, 3 (left border, left of the ramp) |
| | 3rd | (6, 26), 18.4, 5, 6, 4 | (19, 24), 18.4, 5, 19, 4 (right of the ramp) |
| | 4th | (23, 32), 27.3, 16, 23, 4 | (2, 42), 34.9 (18 from the 2nd), 25, 2, 3 |
| Red Coast | 2nd | (27, 14), 18.0, 21, 14, 4 | (1, 25), 19.2, 9, 1, 3 |
| | 3rd | (6, 26), 18.4, 5, 6, 4 | (19, 24), 18.4, 5, 19, 4 |
| Kestrel Rise | 2nd | (24, 8), 18.1, 29, 8, 3 | (1, 26), 20.6, 5, 1, 3 (left border by the ramp) |
| | 3rd | (12, 23), 18.0, 4, 12, 4 | (18, 20), 18.4, 11, 18, 4 |
| Ashford Crossing | 2nd | (27, 5), 18.4, 36, 5, 3 | (2, 26), 18.4, 10, 2, 3 |
| | 3rd | (9, 27), 18.0, 3, 9, 4 | (21, 23), 18.4, 6, 21, 3 |
| Highmoor | 2nd | (28, 9), 18.0, 27, 9, 3 | (1, 25), 19.2, 9, 1, 3 |
| | 3rd | (6, 26), 18.4, 5, 6, 4 | (19, 24), 18.4, 5, 19, 4 |
| Redrock Canyon | 2nd | (56, 12), 18.0, 26, 12, 4 | (30, 22), 18.4, 8, 22, 4 (no border near: the main sits mid-top) |
| | 3rd | (28, 21), 18.6, 11, 21, 4 | (48, 22), 18.4, 8, 22, 4 (the exact mirror) |
| Cinder Steps | 2nd | (24, 12), 18.4, 28, 12, 4 | (16, 23), 18.0, 9, 16, 4 (right of the ramp, the old natural's side) |
| | 3rd | (12, 26), 19.0, 4, 12, 4 | (1, 33), 25.5, 9, 1, 3 (left border; 18 from the 2nd) |

So the "far out" spot is gone: before, one of the two spots was 21-36 steps round the main's cliff from the ramp
(on Thornwood Maze 30 tiles from the main); now both are 5-12 steps from the ramp's foot, 18-21 tiles from the main (Cinder Steps' 3rd 25.5: it must stand
18 from the 2nd), one either side of the ramp. The 2nd is against the border (1-2 tiles) on six of the eight maps; on
Redrock Canyon and Cinder Steps no border is near the ramp on its side. On the classic maps (Greenhold, Red Coast,
Highmoor) the 2nd is the old natural pulled in to 18 tiles and onto the left border; the 3rd is its mirror right of the
ramp, in the open (no border near that side of the ramp; the top border east of the main is 30+ steps round the cliff).
Thornwood Maze (the owner's game as P2): his twins are (86, 82) on the bottom border by the natural and (89, 64) north of
the ramp.

Pictures: docs/shots/crown_spots_v2/ (captions.md). Tested by tools/test_expansion_spots.gd (each map: the 2nd within
21 tiles of the main and on the old natural's side, both within 12 steps of the ramp's foot, on opposite sides of the
line, the 2nd no more than 3 tiles farther from the border than any legal spot on its side as near the main and the ramp).

0.30.5: the test failed now and then (Highmoor 4 players, "#1 (25, 18): 15 steps from the ramp's foot (far out)"): the
decorations are rolled from each match's seed, so the picks change from game to game (12 seeds of every map: 6 bad runs
of 324 at the most players, all on the classic 4-player maps; none at 2 players). On those maps the low ground under the
ramp is shared by both sides, and on some seeds the best 3rd ((3, 25) on Highmoor seed 14) is within 18 tiles of every
good 2nd near the ramp; the mirrored pair then takes a 2nd farther along under the main's cliff. Three kinds:
- a 2nd or 3rd 13-14 steps out beat a spot of 12 next to it: 1-2 steps past the line cost only 2-4 points. Now crossing
  the "far out" line costs 10 points once (`CrownSites.W_FAR_STEP`).
- with that alone, the 2nd went to a near spot 24.7 tiles from the main (Twin Fords and Mirewood seed 9; Dune Sea on the
  first try): now the 2nd also pays 10 once past 5 tiles over the least distance (`GAP_NEAR`, `W_GAP_STEP`), the
  test's own limit for it.
- where the only spots within 12 steps that leave the 3rd its place lie past those 5 tiles, the test's two demands can't
  both be met: Highmoor seed 14's (25, 18) is on the low ground under the main's cliff, 18.0 tiles from the main and 21
  steps from it by land, 15 from the ramp's foot; the near one, (21, 29), is 23.7 tiles out and 25 steps from the main.
  The test now counts a nearer spot for the 2nd only within its 5 tiles, so (25, 18) stays. Likewise the 3rd on the
  other side of the ramp is asked only when that side has a legal spot (the rule's own fallback, 5 above; Greenhold and
  Mirewood 4p, players 2 and 3 on some seeds, have none there).
Checked over 12 seeds of every map, 2 players and the most (tools/dbg_crown_spots.gd): no bad run. Picks changed in 8 of
324 runs at the most players (the classic 4-player maps, mostly a 2nd 15 steps out moved to 12, or a 3rd of 13-15 to
11-12), none at 2 players.

### v1 (0.29.2, replaced): under the main's cliff

The 2nd and 3rd halls at the least hall distance from the Crown's halls, close together, under cover of the main's high
ground (Score: 40 x room + 60 x the share of the hall's sides within musket reach of the main's cliff edge - 3 a tile past
18 - 1 a tile of the mean distance to the other halls...). It put the 2nd beside the cliff away from the ramp (21-36 steps
round) on most maps, and the 3rd 18 tiles from both. Its measurements (tools/measure_cliff_cover.gd) are in
docs/crown_cliff_edge.md section 4; its pictures in docs/shots/crown_cliff_edge/06-11.

Resources: every hall's land holds the same fresh reserve on a new map. So resources do not change the pick at the start. A spot whose lode a fallen hall drew out is hidden.

The maps are turned through their middle, so twin spots get the same score. The test checks this on every map.

## Each map's spots (2 players; walk in steps, ways in)

Since 0.15.0 every map is bigger and has more base sites (docs/map_sizes.md). The two marked spots of each side:

Classic maps (made anew each match, 2 corners; 4 free sites per side, natural included):
- Greenhold, Dune Sea: the natural below the ramp (22 steps, 2 ways, 81%); then the open ground right of the main (38 steps, 1 way, 99%). The owner's drawing (2026-10-28): the natural moved up to the foot of the ramp, a site in the bottom-left corner and one just right of the bottom-left pond. Those two score lower (the corner is cramped by the pond and the edge, the pond site is far), so they are not marked.
- Highmoor, Frostfang, Ashfall, Red Coast: the natural (23 steps, 2 ways, 83%); then the open ground right of the main (38 steps, 1 way, 91%).
- Twin Fords, Mirewood, Border March: the open ground in front of the main (33 steps, 1 way, 99%); then the natural (22 steps, 2 ways, 81%).
- With 4 players every classic map marks the corner's two sites: the natural by its east ramp (23 steps, 2 ways, 78%) and the open ground below it (35 steps, 1 way, about 95%).

Named maps (best, then second):
- Ashford Crossing: the natural (27 steps, 2 ways, 77%); then the third along the top (54 steps, 1 way, 98%).
- Kestrel Rise: the natural (17 steps, 2 ways, 67%); then the new site in front of the main (38 steps, 2 ways, 95%).
- Thornwood Maze: the natural (20 steps, 3 ways, 74%); then the new site between the pine walls (43 steps, 6 ways, 96%).
- Redrock Canyon: the new natural in front of the ramp (24 steps, 1 way, 97%); then the old natural on the left (36 steps, 1 way, 99%).
- Saltmarsh Isles: the natural (17 steps, 1 way, 63%); then the third on the home island (49 steps, 2 ways, 89%).
- Glimmerdeep: the inner third (44 steps, 2 ways, 98%); then the natural (18 steps, 4 ways, 73%).
- Frostmere: the new site right of the main (45 steps, 1 way, 98%); then the natural (19 steps, 4 ways, 75%).
- Cinder Steps: the new site in front of the main (37 steps, 1 way, 93%); then the natural (17 steps, 2 ways, 65%).
- Hollowfen: the new site along the top (41 steps, 1 way, 99%); then the natural (18 steps, 3 ways, 72%).
- Amberfall Vale: the new natural in front of the ramp (24 steps, 1 way, 96%); then the new site in the top-left (48 steps, 1 way, 99%).
- Twin Crowns: the new site along the top (46 steps, 1 way, 99%); then the natural (19 steps, 2 ways, 70%).
- Jade Wilds: the new site below the natural (43 steps, 2 ways, 98%); then the natural (19 steps, 4 ways, 74%).
- Shattered Coast: the natural (19 steps, 2 ways, 82%); then the third along the top (52 steps, 1 way, 80%).
- Ember Reach: the natural (19 steps, 3 ways, 81%); then the new site below it (49 steps, 1 way, 99%).
- Whitecap Pass: the natural (19 steps, 2 ways, 70%); then the new site along the top (54 steps, 1 way, 99%).
- Kingsfield: the natural (19 steps, 2 ways, 76%); then the new site along the top (47 steps, 1 way, 99%).
- Pinewall Marches: the natural (19 steps, 5 ways, 80%); then the new site below it (47 steps, 4 ways, 97%).
- The Sundered Realm: the new site along the top (43 steps, 1 way, 99%); then the natural (19 steps, 2 ways, 69%).

In team games each player gets his own two spots, from the sites nearest his main.

## Unfair or weak sites found

- FIXED: on the classic river maps (Twin Fords, Mirewood, Border March) with 2 players, the fords were not the same on both sides. The river's wiggle is not its own twin, and a ford laid over river already drawn stayed water. One side's natural had 4 more cells of open front and 1% more room. Now every ford cell and its twin are open ford on both sides (`MapGen._rivers`). This makes those fords a little wider.
- Thornwood Maze: the natural has 6 ways in, and the second spot is far (61 steps) and close to the enemy (78 steps). Expanding there is weak. Not changed.
- Redrock Canyon: the third has 6 ways in. Not changed.
- Classic maps with 4 players: the corner natural was cramped (about 63% room). On the bigger maps (0.15.0) it has 78%.
- Hollowfen and Kingsfield: the natural and a third score almost the same. Both are marked.

## Pictures

`docs/shots/expansion_spots/`:
- `<map>.jpg`: every built-in map, fog lifted, a Crown player against a Clockwork computer (re-made for the bigger maps of 0.15.0; the old ones are in docs/shots/map_sizes/, side by side with the new).
- `close_crown_<map>.jpg`, `close_clockwork_<map>.jpg`: in game, with the HUD and minimap, for Ashford Crossing, Frostmere and Greenhold.
- `place_crown_<map>.jpg`, `place_clockwork_<map>.jpg`: the same while placing a hall (the spots a touch brighter).
- The labels (0.15.16): `docs/shots/brood_fixes_2/spots_crown_label.png`, `spots_crown_placing.png`, `spots_crown_far.png` (zoomed out: no words), `spots_clockwork_label.png`, and the new Brood's `spots_new_brood.png`, `spots_new_brood_placing.png`, `spots_new_brood_far.png` (tools/shot_expansion_spots.gd now also writes `label_<faction>_<map>.png`; the new Brood's from tools/shot_brood_structures.gd fixes2).

Made by `tools/shot_expansion_spots.gd`. Tested by `tools/test_expansion_spots.gd`.
