# Diagonal palisade (0.25.23, branch wall-diag)

The owner (2026-10-31): when a palisade runs diagonally the pieces only touch at their
corners and "it seems like a hole". He made ChatGPT art for it:
`art/redraws/palisade_diagonal_chatgpt.png` (two pieces, "\" and "/", each on a triangle of
dirt) and asked whether the size was right and for something better composed from it.

## The art (tools/import_palisade_diag.py)

The sheet is not used as it is: its stakes are fatter than the straight palisade's, they get
shorter toward the low end (the lower ones are buried deeper in the dirt) and they stand on
a big triangle of ground. So:

- every stake is cut out on its own: a column from its tip down a fixed 330 sheet px (the
  plain wood all of them show), 84 px wide (the stake and its outline); the two big pieces
  are kept and the stray specks round them dropped;
- each is scaled (area average, hard alpha edge, as tools/import_palisade.py does) to the
  straight pieces' stake: 6 px wide, 35 px tip to foot, the grey band ~17 px under the tip
  as in wall_ew_built.png (the bottom few rows, below the sheet's cut, are the lowest wood
  row repeated a little darker); a touch lighter (x1.1 + 5), as the sheet's wood was darker
  than the straight pieces' (median 60 vs 73);
- they are set down again with every foot on the cell's diagonal: "\" on y = x + 4
  (the tile's top-left corner to its bottom-right one, through the point (16, 20) where the
  straight pieces' centre post stands), "/" mirrored (y = 36 - x, with the right-hand
  piece's own stakes so the light falls the same way). 8 stakes a tile, 4 px apart and 4 px
  down each, the nearer (lower) one drawn over the one behind; the 9th would be the next
  tile's first, so 4 pieces in a row join at the corners with no gap and no seam;
- the ground under them is the straight piece's own strip of dirt, column by column, moved
  down to the diagonal (the sheet's triangle of ground is dropped).

Pictures (assets/buildings): `wall_diag_se_built` ("\"), `wall_diag_sw_built` ("/"), their
`_construction` (the front half still short stumps), `_damaged` (two stakes snapped, a bit
darker) and `_destroyed` (stumps) versions, derived from the same stakes;
`wall_diag_half_{nw,ne,se,sw}_built` (the centre to one corner) and `wall_diag_hub_built`
(one stake on the centre). `python3 tools/import_palisade_diag.py --contact DIR` writes 4 in
a row each way and the states beside the straight pieces.

## The links (Game._links_from, Building.wall_piece / wall_extras)

`Building.links` keeps its four bits (N 1, E 2, S 4, W 8) and gets four more: NE 16, SE 32,
SW 64, NW 128. A diagonal bit is set when the diagonal cell has a palisade or gate of the
same side AND neither of the two cells between them has one (otherwise they already join
round the corner). Links are worked out again on load (they were never saved), so saves and
replays are unchanged; `_line_kinds` now looks at a square (the diagonals) instead of a
diamond, and `relink_walls` relinks the eight cells round a change.

What a built piece shows:

- no diagonal bits: as before (the 16 straight pictures);
- only diagonal bits, NW + SE: `wall_diag_se`; NE + SW: `wall_diag_sw`;
- any other mix (a diagonal line's end, a bend, an X, or a piece with straight and diagonal
  neighbours): its straight picture (`wall_post` replaced by the small `wall_diag_hub` when
  it has no straight neighbour) plus one HALF per diagonal neighbour, as extra sprites
  (children of its sprite; the north halves are drawn behind it, the south ones in front).

Construction / damaged / destroyed: a piece joined only diagonally shows its diagonal's
picture; a mixed piece shows its straight one's, without the halves (simple; the straight
pieces' states are cut from the sheet and have no diagonal halves).

A gate is not redrawn: a diagonal wall reaching a gate joins it (the half runs to the
gate's corner), the gate keeps its own picture.

## Blocking

Already sealed before this change, checked: the pathfinder never cuts a corner between two
solid cells (AStarGrid2D DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES), the path smoothing's line test
(7 px margin) sees both pieces, the walkable areas are 4-way, and the movement test
(`_clear_at`, five points round the unit) can't fit even a labourer through the corner: in
tools/test_wall_diag.gd, units pushed straight at the corner with steps of 1 to 12 px came
through 0 times with and without the new guard. The guard is kept anyway, as insurance for
big steps: `Game._wall_corner(a, b, team)` refuses a move from one cell to its diagonal
neighbour when both cells beside the step are palisade (solid 4) or a gate that doesn't let
that side through; only walls and gates, not buildings in general.

## The line tool

Changed in 0.25.25 (docs/wall_drag.md): the player's palisade drag now snaps to 8 ways and
lays exact diagonals corner to corner (`Game.wall_cells`); what follows is how it was, and
how `Game.line_cells` (still used by the test below) works. Before: a 45-degree drag still lays a STAIRCASE (Game.line_cells adds a cell at every
diagonal step), so it never makes corner-only joins. The diagonal look shows where pieces
are laid one by one corner to corner, where two lines meet at a corner, or where the
computer's wall planner leaves such joins. Laying true diagonals with the line tool would
take about half the pieces for the same length (cheaper walls): a balance question for the
owner.

## Test

`tools/test_wall_diag.gd` (headless; with `-- shots` under xvfb it writes
docs/shots/wall_diag/: diagonal.png, diagonal_close.png, mixed_bottom.png (a diagonal into a
straight run east), mixed_top.png (a straight run north into a diagonal), states.png
(damaged and construction)): the links and pictures picked, a filled corner turning back
into a straight corner, units ordered across a 7-piece diagonal walk round it, the push
test, and a gate in a diagonal line (its side walks through, the other side doesn't).
