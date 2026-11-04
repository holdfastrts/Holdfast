# The Crown's expansion spots, v2 (0.29.5): pictures

See docs/expansion_spots.md ("The Crown's rule"). The owner, 2026-11-04 07:05: "The first should still be in the same
place it was before, just closer. As close to the edge of the map as possible ... The second expansion should mirror the
first on the other side of the main ... as close as possible, 18 tiles, as close as possible to the ramp ... I don't know
why you left the second expansion so far out."

Diagrams (`01`-`08`): made by `tools/measure_crown_spots.gd` (2 players, both Crown, the bare map; `remeasure:before` for
the v1 spots, `tag:after` for v2) and `tools/draw_crown_spots.py`. Each shows player 1's main (top-left, or top-middle on
Redrock Canyon; player 2 gets the twins) from above, BEFORE (v1, 0.29.4) on the left and AFTER (v2) on the right: low
ground light, the main's high ground darker, cliffs black, the ramp tan, trees and rocks green; the main hall white, the
ramp's foot a red dot, the old natural (the base-site rating's #1) a dashed purple box; the Crown's 2nd base bright gold,
the 3rd lighter, the 4th faint. Under each panel: tiles from the main, the walk from the ramp's foot (steps), tiles from
the map's border, sides open to wall. The panels start at the map's top-left corner, so the picture's top and left edges
are the map's border.

- `01_thornwood_maze.jpg`: before, the 2nd stood in the open south of the ramp (18 from the border) and the 3rd 30 tiles
  out. After: the 2nd on the top border north of the ramp, beside the old natural (18.0 tiles, 5 steps from the ramp's
  foot, 2 from the border); the 3rd is its mirror south of the ramp (18.4 tiles, 12 steps). In the owner's game (P2,
  bottom-right) these are (86, 82) and (89, 64).
- `02_greenhold.jpg`: before, the 2nd beside the cliff right of the main, 21 steps round from the ramp. After: the 2nd on
  the left border left of the ramp (18.4 tiles, 9 steps, 1 from the border: the old natural pulled in), the 3rd right of
  the ramp (18.4 tiles, 5 steps).
- `03_red_coast.jpg`, `06_highmoor.jpg`: the same shape as Greenhold (the classic highlands main): the 2nd (1, 25) on the
  left border, the 3rd (19, 24) right of the ramp.
- `04_kestrel_rise.jpg`: before, the 2nd 29 steps round the cliff. After: the 2nd on the left border by the ramp (20.6
  tiles, 5 steps, 1 from the border), the 3rd right of the ramp (18.4 tiles, 11 steps).
- `05_ashford_crossing.jpg`: before, the 2nd on the top border 36 steps round the cliff. After: the 2nd on the left
  border (18.4 tiles, 10 steps, 2 from the border), the 3rd right of the ramp (18.4 tiles, 6 steps).
- `07_redrock_canyon.jpg`: the main sits in the middle of the top border, so no border is near the ramp: the 2nd and the
  3rd are an exact mirror pair either side of the ramp (18.4 tiles, 8 steps each). Before, the 2nd was 26 steps round.
- `08_cinder_steps.jpg`: the old natural lies right of the ramp, so the 2nd is there (18.0 tiles, 9 steps, in the open);
  the 3rd on the left border (25.5 tiles: it must stand 18 from the 2nd; 9 steps). Before, the 2nd was 28 steps round.

In game (`tools/shot_expansion_spots.gd close:1`, the new `both_crown_<map>` view: the main and both gold marks at 0:00,
a Crown player against a Clockwork computer):

- `09_ingame_greenhold.jpg`: the two marks either side of the ramp, the left one against the map's edge. Compare
  docs/shots/crown_cliff_edge/11_marks_greenhold_after.jpg (v1: the mark beside the cliff right of the main).
- `10_ingame_thornwood_maze.jpg`: Thornwood Maze, the 2nd on the top border by the ramp, the 3rd below the ramp.
