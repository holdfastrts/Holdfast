# Remembered enemy buildings under the fog (0.30.9)

The owner, 2026-11-04: "currently after we scout buildings I don't think they are showing as ghosts in the fog of
war, they should."

## Before

`Game._update_vis` set an enemy building `visible` for good once its CENTRE cell had been seen (`seen_by_human`). It
stayed on screen as the LIVE node: under the fog you watched it being built, its damaged picture, its sails, mill
horse and gear ring turning, its bars; a building razed out of sight collapsed in view (dust and fire effects on
explored ground) and its ruin showed, and its minimap square vanished at once. Pictures:
`docs/shots/fog_ghosts/before_2_left.jpg` (scout gone), `before_3_razed_unseen.jpg` (the Light Works razed and the
Clocktower hurt with nobody of yours there: the ruin and the damage show).

## Now (scripts/fog_memory.gd, `Game.fog_mem`)

- An enemy building shows while ANY of its footprint is seen now. When it goes out of sight its picture is taken
  (every shown Sprite2D part copied: texture, frame, region, flips, offset, place, z; the team material duplicated
  with `tint` 0.74/0.74/0.8, flash off) into one node in the y-sorted world, and the live building is hidden. Its gear
  ring is kept as it stood (`GearNet.ring_items`, drawn by `GearNet._draw`, darker, not turning). No bars.
- The picture goes when any of its footprint is seen again; the live building, its ruin (`FogMemory.ruins`: a dead
  enemy building's ruin shows only while seen) or nothing is what you then see. Razed unseen: no collapse effects.
- Minimap: the pictures as darker squares (`FogMemory.minimap_rects`, hud `_draw_minimap`).
- THE BROOD (choice): a rooted creature (`FogMemory.rooted_like`: a Rootmaw, Mound Turtle, father or the Mother
  rooted, rooting, uprooting, or a cocoon: anything with a footprint) is a building and is remembered the same way,
  rooted where seen. If it uproots out of sight its picture stays until the spot is seen; seen walking elsewhere, the
  old picture goes. Walking creatures are units: shown only while seen, as before.
- SELECTING (choice): a picture is not a thing: it can't be hovered, picked or selected, and an enemy building or
  rooted creature that goes under the fog leaves your selection. A right-click / attack-move there is an order to the
  ground (the walk ends at the nearest reachable spot, pathfinding).
- Unchanged: watching computers through a player's eyes (the old `seen_mask` rule), replays, full vision (FOG: OFF:
  every picture dropped), your own and allied buildings. Pictures are not saved: a loaded game knows no enemy
  building until seen again (as `seen_by_human` already was). The sandbox's player switch drops them.
- Cost: pictures are taken only when something leaves sight; each fog update (4 a second) checks footprints:
  0.3-0.65 ms with ~140 remembered buildings (tools/test_fog_ghosts.gd, headless); taking 138 pictures in one update
  ~15-19 ms once.

## Tests and pictures

- `tools/test_fog_ghosts.gd`: seen, left (hidden, remembered, darker, deselected, not pickable, on the minimap), hurt
  unseen (picture keeps the old look), razed unseen (picture stays, ruin hidden), seen again (picture gone, ruin
  shown), full vision, the Brood (rooted turtle remembered, walking Raptor not, uproot and seen elsewhere), watching
  computers (no pictures), 100+ buildings. `tools/test_fog_grey.gd` updated for the hidden live hall.
- `tools/shot_fog_ghosts.gd`: `docs/shots/fog_ghosts/after_1_seen.jpg`, `after_2_left.jpg`, `after_3_razed_unseen.jpg`.
