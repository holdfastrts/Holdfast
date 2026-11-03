# Third wings on the flying Brood (0.26.10 / 0.26.14, corrected in 0.26.16, branch third-wing-2)

The owner (2026-10-30 19:46, "DEEP JOB", and 2026-11-03: "could you remove the third wings with code?"): ChatGPT drew
some Storm line frames with THREE wings. The extra wings are erased in code (tools/fix_third_wing.py), hooked into the
importers so a re-import keeps the fix.

## 0.26.16: "You deleted the wrong wings." (the owner, 2026-11-03)

His marked pictures: docs/shots/third_wing/owner_marks/ (the SE wing beat frame 3 of the Hatchlings and the Storm
Challenger circled; the bottom left of both portraits circled where the "extra wing" had been erased).

**What was wrong.** The 0.26.14 fix read the SE wing beat's frame 3 (the DOWNSTROKE) backwards: the two wings hanging
DOWN (the near wing down-left, the far wing down-right under the head) are the right pair for a downstroke; the wing
raised at the TOP LEFT is the stray one (it belongs to the upstroke frames 1-2 and 4-6 and was drawn in again). The fix
had erased the down-left wing and kept the raised one. In the two portraits the bottom-left shape is the creature's own
near wing, not a second one: erasing it was wrong.

**What changed.**
- SE wing beat frame 3 (walk_se/idle_se 3), Hatchlings and Storm Challenger: the down wing is back; the raised top-left
  wing is erased instead. The cut follows the back along the crest spikes and over the shoulder, and becomes the back's
  dark outline (3 sheet px), so the body reads as whole: a clean downstroke with both wings down.
- Portraits (assets/icons/hatchlings.png, storm_challenger.png): back to the originals, pixel for pixel (no entry left
  in PORTRAITS).
- The other frames the fix had touched were re-checked with the same rule (which two wings make a pair for that pose?).
  None was certain enough to cut, so all are back as drawn (pixel for pixel as before 0.26.10) and listed for the owner
  below.
- Skin masks rebuilt (tools/import_vet_skin.py --only hatchlings / storm_challenger). Anchors, timing and frame counts
  unchanged (art_data.gd untouched).

### For the owner to judge (back as drawn; say which wing goes and it gets a polygon)

| Frame | What is there | Why it was not cut |
| --- | --- | --- |
| Hatchlings death_se/s/e/ne frame 5 (lying dead) | three wing shapes: one stretched far out to the left, one lying diagonally in front of the body down-left, one stretched out to the right | 0.26.14 erased the far-left one. Read the owner's way, the far-left and right wings are the symmetric spread pair and the diagonal front one is the stray, but that one lies across the body's underside and would need the belly repainted; unsure, so restored. |
| Hatchlings death_n frame 1 (hit, falling, seen from behind) | a wing raised at the top left, one raised at the top middle, one hanging at the lower right | 0.26.14 erased the top-middle one (keeping one up, one down). Both raised could be the pair just as well (the body tumbling); unsure, so restored. |
| Storm Sire (pterodactyl) attack_se frame 5 (coming out of the dive) | two left wings, one raised behind the other, plus the right wing up | 0.26.14 erased the one BEHIND. That one is in the same place as the left wing of frame 6 (and frame 4), so it is likely the right one to keep and the front, lower one the stray; but the front one overlaps the body. Unsure, so restored. |

Pictures (docs/shots/third_wing/, rebuilt with `python3 -I tools/fix_third_wing.py --shots docs/shots/third_wing`):
- hatchlings_walk_se.png, storm_challenger_walk_se.png: "original" on top, "fixed" (the game's) below.
- hatchlings_death_*.png, pterodactyl_attack_se.png, *_portrait.png: one row, "original" (what the game shows again).

## The survey (0.26.10)

Checked frame by frame, enlarged: Hatchlings and Storm Challenger, all 5 sheets each (fly 6, bite 6, death 5 in S, SE,
E, NE, N) and the portraits; the Storm Sire's game strips, portrait and the Storm lure's arrival strip; the command icons
showing them (too small for a wing count problem). The retired Skywing was not surveyed.

Already handled before: the Storm Sire's fly E frame 2 (the owner's red pen; dropped by the importer since 0.20).
Not used by the game: the Storm Challenger NE sheet, swoop row frame 2 (three wings; the NE swoop is built from other
frames, import_storm_line.py NE_SWOOP).
Looked at and left as drawn (folded wings read as two): the Storm Challenger's swoop frames 2-3 (SE, S, E) and 2-4 (N),
the Storm Sire's dive frames 2-4 (SE, E), the Storm lure arrival frame 4, the Hatchling's E fly 3 (one wing up, one
down), the Storm Challenger's lying deaths (the long spiked piece at the left is its TAIL).

## How the fix works (tools/fix_third_wing.py)

- `FRAMES`: per (sheet, row, frame) a hand-drawn polygon in the cut-out frame's pixels, read off gridded zooms. Inside
  it the frame becomes transparent; small pieces cut off by it and thin slivers along the cut go too; the creature's
  new edge along the cut gets the sheet's own dark outline.
- `PORTRAITS`: a polygon on the 1254 px portrait, filled from its dark backdrop (empty since 0.26.16).
- Hooks: tools/import_storm_line.py (`ftw.fix_rows`, `ftw.portrait_fixed`) and tools/import_brood_fathers.py (the
  Storm Sire's dive sheet; no entry since 0.26.16). Both importers take the flying frames' anchors from the frames as
  drawn, before the fix, so a body does not jump when a wing is removed.

## What a redraw would still improve

The downstroke now reads right, but where the raised wing was cut the back is a plain outlined hump. A redraw of that
one frame would be cleaner; and the frames in the table above need the owner's call (or a redraw).

ChatGPT prompts (each stands alone; attach the reference images named; flat navy background; PNG download):

**Prompt A: Hatchling south-east downstroke.** Attach: the hatchling SE sheet (art/redraws/hatchling_se_chatgpt.png)
and docs/shots/third_wing/hatchlings_walk_se.png.
> Pixel-art game sprite, same style, colours and size as the attached sheet's first row. One single frame: the olive
> baby pterosaur with the red crest, flying toward the bottom-right (south-east), on the DOWNSTROKE: BOTH wings swept
> down below the body, the near wing hanging down-left in front of the body, the far wing down-right under the head,
> exactly as in frame 3 of the first row. NO wing raised above the back: the back with its red crest spikes is clear
> against the sky. The creature has exactly TWO wings, no more. Same body pose and head as frame 3 of the first row.
> Flat dark navy background (#0f1a2a), no shadow, no text. Download as PNG.

**Prompt B: Storm Challenger south-east downstroke.** Attach: art/redraws/storm_challenger_se_chatgpt.png and
docs/shots/third_wing/storm_challenger_walk_se.png.
> Pixel-art game sprite, same style, colours and size as the attached sheet's first row. One single frame: the olive
> pterosaur with the red head crest and red spikes along its wing edges, flying toward the bottom-right (south-east),
> on the DOWNSTROKE: BOTH wings swept down below the body, the near wing hanging down-left in front, the far wing
> down-right under the head, exactly as in frame 3 of the first row. NO wing raised above the back: only the spine's
> red spikes show there. Exactly TWO wings. Same body and head as frame 3 of the first row. Flat dark navy background
> (#0f1a2a), no shadow, no text. Download as PNG.

(The 0.26.14 portrait prompts were dropped: the portraits were right. Save answers as
art/redraws/hatchling_se_down_chatgpt.png etc.; the importer would then need a line to use them.)
