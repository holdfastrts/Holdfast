# Laying palisade: straight, diagonal and bent (0.25.25, branch wall-drag)

The owner (2026-10-31): "Currently a human player can only make straight walls because when
we click and drag it makes a straight line. Allow us to make diagonals, and also segments
using shift."

## What the controls do now (palisade and gates, the Crown)

Computer:

- **Press where the wall starts, drag, let go where it ends**, or click the start and click
  the end (the old way still works). The end turns to the nearest of 8 ways from the start:
  along the row, along the column, or an exact 45-degree diagonal (`Game.snap_wall_end`).
- **A diagonal is one piece per diagonal cell**, corner to corner (`Game.wall_cells`): no
  staircase cell at each step, so it shows the diagonal palisade art (docs/wall_diag.md) and
  costs one piece per cell it crosses (4 cells across = 5 pieces, not 9).
- **Shift: a path of several stretches.** With the start given, each Shift-click (or a drag
  let go with Shift held) ends the stretch being drawn and makes a corner; the next stretch
  starts there and snaps on its own (straight, then diagonal, then straight...). The ghost
  shows the whole path. It goes down:
  - when **Shift is let go**: the path up to the last corner (the stretch still following
    the mouse is dropped), as a **queued** order, as every Shift order in this game is (the
    labourers build it piece after piece after what they are already doing); or
  - on a **plain click** (no Shift): the whole path including the last stretch, given at
    once (the labourers drop what they were doing and build its pieces in order).
  This follows how Shift works for buildings here (Shift keeps the placing open while it is
  held; letting Shift go ends it), with the corners in place of the extra sites.
  A Shift-click on the start itself (no length) adds no corner. At most 32 corners.
- Right click or Esc cancels the whole path, as before.
- The hint line says it: "Click where the wall starts (drag: straight or diagonal)", "Click
  where it ends (Shift-click: a corner)", then "Shift-click: another corner; let go of Shift
  or click to lay it".

Phone: as before (move the ghost, tap again or START; then the end, tap again or END); the
end snaps to the 8 ways the same, so diagonals work. There is no Shift on a phone (no queue
toggle in the game), so a phone lays one stretch at a time; a bend is two walls one after
the other. (A BEND button on the card could give phones corners: not done, ask the owner.)

## The ghost

`Game._draw_overlay_all`: every piece of the path (`wall_path_cells(controls.wall_path())`),
green where it can go, red where it can't (blocked, or the gold runs out partway), each
showing the picture it will have with its neighbours, the diagonal halves at the ends and
bends included (`Building.wall_extras`). Under the end: "N pieces: X gold" (the green ones:
what will be laid and paid), orange when some are red. Your own gates the path crosses are
kept (not drawn, not paid), as `place_line` keeps them.

## The command (online, replays)

Still one `Game.place_line(t, k, a, b, builders, queued, via)`: `via` is new, the corners
between a and b (an Array of Vector2i, default empty: old calls unchanged). It travels as
any other argument (NetCodec: var_to_bytes); the host drops anything in `via` that isn't a
cell, takes 32 corners and 400 cells at most. Replays are pictures of the match
(snapshots), not commands, so they show whatever was laid. Gates: laying gates as a line
uses the same path; a gate on a planned piece swaps in as before.

`Game.line_cells` (the staircase) is unchanged: only `wall_cells` (the player's palisade)
lays exact diagonals. The computer (scripts/ai_expand_wall.gd) places its pieces one by
one and is untouched.

## Balance note

A diagonal wall now costs about 0.7 of the pieces of a staircase over the same ground
(5 pieces instead of 9 for 4 cells across). docs/wall_diag.md raised this; the owner asked
for diagonals, so it is in.

## Test

`tools/test_wall_drag.gd` (headless; `-- shots` under xvfb writes docs/shots/wall_drag/):
the snap, a straight drag, two clicks, a diagonal drag (5 pieces, no staircase cells, cost =
pieces, the middle one linked NW+SE), a Shift path (straight then diagonal, laid on letting
Shift go, 9 pieces, no staircase cell at the bend), a Shift path ended by a plain click, a
gate in a diagonal run, phone taps, and the command through the online packing and the
host's checks.

Pictures: `ghost_diagonal.png`, `ghost_path.png` (the ghosts), `built_diagonal.png`,
`built_path.png`, `built_all.png` (the walls finished).
