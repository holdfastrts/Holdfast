# Winding on the march (0.26.0)

The owner's idea (2026-11-01): "the Winders to be able to wind up soldiers while walking, so the Winder does the wind up
animation walking behind the unit, both walking, and the charge grows back to full and the Winder goes to the next; this
would be helping in the marching across the map moments."

## Before

A Winder winds a Clockwork unit through REPAIR (`Unit._repair`): in reach (radius + 20 px) he stands and cranks, +0.15
charge a second (and mends its health, paid in cogs). A unit that walked on was chased, caught, wound for a moment
standing, left behind, chased again. His REPAIR autocast only looked round while he was IDLE (units under 50% charge).
So on a march across the map nobody was wound: the army ran down (0.012 a second off the gear field: 80 s to empty).

## Now (scripts/winder_walk.gd)

- **Walking behind it.** When the unit he winds is walking (moving > 10 px/s, on the ground), he walks GAP (4) px
  behind it at its pace: its own velocity plus a pull to the spot behind it, capped at his speed. In reach (12 px more
  slack than standing) he keeps cranking while walking; the charge fills at the normal rate (0.15 a second, unchanged)
  and the repair goes on as before (cogs for health). When it stops, he winds it standing, as before.
- **The next one.** When it is full (98%), he takes the next walking construct near him that needs it; when none
  does, he goes back to his own order (the move, attack-move or follow he was on, with its Shift queue).
- **By itself.** A Winder with REPAIR autocast on (the default) on a move, attack-move or follow order looks every
  second for a walking construct of his side within 6 tiles, going his way (heading within ~70 degrees of his), under
  80% charge, off the gear field, not overloaded, not faster than he is, that no other Winder is winding. Lowest
  charge first. The computer's Winders follow the same rule (no AI change here; the AI job sends them with the waves).
- **Pace.** A Clock Soldier (68) or anything slower than a Winder (74) is never slowed. A faster unit wound BY HAND
  goes at his pace while he winds it (`Unit._ww_cap`, never while it fights); the auto pick never chooses one. In the
  gear roster today the only faster constructs fly (Swift, Ornithopter), and flyers are not followed (he can't follow
  them over cliffs): REPAIR on a flyer works as before.
- **His own spring.** A Winder winding on the march cranks his own spring walking too (`self_wind_t` no longer stops
  him while `_ww_on`), so he does not drop behind for 3 s every 90 s.
- **Card.** The soldier's card and bar say "Winding up: N%" while a Winder winds it (`cranked_t`, now set for every
  construct he winds, not only the Wind-up Soldier); the Winder's card text and the REPAIR button's tip say so too.
- **Box select.** A box over the army keeps the Winders winding soldiers (work "repairing" on a unit) in the selection
  (scripts/controls.gd: before, only idle-at-work Winders came along, though the comment said "repairing").

Online: only the host runs it. The guest sees the streamed `work` ("repairing") and the walking, and plays the
walk-wind strip (`Unit._anim_name`: a Winder repairing while moving). Nothing new in snapshots. `_ww_back` is not in
saves: after a load, a Winder in the middle of a march-wind stops when that wind is done instead of rejoining his move.

## Animation

No painted "winding while walking" strip yet. `walk_wind` (assets/units/winder/walk_wind_<view>.png) is CODE-BUILT
by tools/winder_guide/walk_wind.py: the WIND frames above the hips (head, arms, the crank) over the WALK frames' legs
(the walk's swinging hands cut away under the seam). It plays on the WALK beat (`Unit.beat_of`): a ticking step and a
quarter turn of the crank on each step, scaled with his speed. Logged in docs/art_style_inconsistency.md.
Preview: docs/shots/winder_walk/walk_wind_strip_5x.png.

### ChatGPT redraw prompt (one view per request, like the carry and crew strips)

Do one request per view: S, SE, E, NE, N (the west views are the east ones mirrored by the game). Attach these 3
images to each request:
1. `art/redraws/winder_walk_v2.png` (his walk, all views)
2. `art/redraws/winder_wind_v2.png` (his winding, all views)
3. `assets/units/winder/walk_wind_<view>.png` (the code-built pose guide for that view; scale it up 6x, nearest
   neighbour, before attaching)

Prompt (replace VIEW with: front (S) / front three-quarter facing down-right (SE) / side facing right (E) /
back three-quarter facing up-right (NE) / back (N)):

```
I attached 3 images of the same small clockwork robot character, a "Winder": a brass body with a round white clock
face for a head, a wind-up key on his back, red shoulder joints and a red heart.
Image 1 is his WALK animation sheet. Image 2 is his WINDING animation sheet (he turns a small crank held in both hands).
Image 3 is a rough pose guide, cut and pasted from the two: the winding arms on top of the walking legs.

Paint ONE new row of 4 frames, VIEW only: the Winder WALKING while he WINDS, both at once. His legs step exactly as in
his walk (image 1, the same 4-frame step cycle), and his arms are held in front of his chest turning the small steel
crank with the brass knob, a quarter turn further in each frame, as in image 2. He leans very slightly forward as if
following just behind someone. Keep everything else identical to the sheets: the same character, proportions, size,
brass colours, red joints and heart, clock face and key, the same lighting and the same painted pixel-art style.
Same height in every frame, feet on one ground line, the head steady (no bobbing beyond the walk's). No shadow under
the feet, no motion lines, no text, no extra characters.
Flat navy blue background (#1b2440) behind the 4 frames, evenly spaced in one row, each figure fully inside its cell.
```

The answers go to `art/redraws/winder_walk_wind_<view>_chatgpt.png`; an importer like tools/import_winder_carry.py
then replaces the code-built strip (same cell 76x49, anchor 38,43, 4 frames).

## Test (tools/test_winder_walk.gd)

Ashford Crossing, off the gear field, a 1,500 px lane: two groups of 6 Clock Soldiers at 30% charge march side by side;
one has 2 Winders on the same move order. Results (0.26.0):

| | arrives | charge on arrival |
|---|---|---|
| with 2 Winders | 24.5 s | 0.76, 0.80, 0.85, 0.80, 0.76, 0.84 (mean 0.80) |
| without | 28.7 s | 0.03 x5, 0.62 (mean 0.13) |

All 6 were wound on the way; while winding on the move the Winder was behind the soldier in 308 of 314 samples and
within 50 px in 311; the soldiers were never capped (their speed is their own; wound, they are even faster, since a
low charge slows a construct to 75%); the walk-wind strip played in every sample; both Winders went back to their move
and reached its end. Also: REPAIR by hand on a walking soldier (wound walking to 97%, then he stops), a faster unit
by hand (paced at 74 while wound), and the auto pick leaving a faster unit and a flyer alone.
Frames: docs/shots/winder_walk/march_*.jpg (FILM=1 under xvfb-run writes them as PNG; five kept, as JPEG).

## Open

- Tuning: LOW 80%, SCAN 6 tiles, the rate (0.15/s, unchanged). With 2 Winders to 6 soldiers the group arrives at ~80%
  after a 1,500 px march from 30%; more soldiers per Winder arrive lower.
- Winding is still blocked when the side has under 1 cog (the repair's check), even for a unit at full health.
