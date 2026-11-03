# Third wings on the flying Brood (0.26.10, branch third-wing)

The owner (2026-10-30 19:46, "DEEP JOB", and 2026-11-03: "could you remove the third wings with code?"): ChatGPT drew
some Storm line frames with THREE wings. Every frame was checked; the extra wings are now erased in code
(tools/fix_third_wing.py), hooked into the importers so a re-import keeps the fix.

## The survey

Checked frame by frame, enlarged (source sheets cut exactly as the importers cut them, and the game strips):
- Hatchlings: all 5 sheets (fly 6, bite 6, death 5 in S, SE, E, NE, N) = 85 frames, and the portrait.
- Storm Challenger: all 5 sheets = 85 frames, and the portrait.
- Storm Sire (kind `pterodactyl`): every game strip (walk/idle and attack in 5 views, root, rooted, uproot, death SE),
  his portrait, and the Storm lure's arrival strip (lure_pterodactyl/arrive_se, his fly-in to the lure).
- Command icons showing them (nbr_clutch_hatchlings, nbr_updraft, lure_storm): too small to show a wing count problem;
  none seen.
- The retired Skywing was not surveyed (no longer laid; only older saves and replays show it).

### Frames with a third wing (in the game), all fixed

| # | Game strip, frame (from 1) | Sheet, row, frame | The extra wing | Fix |
| --- | --- | --- | --- | --- |
| 1 | hatchlings walk_se 3 and idle_se 3 (same frame) | hatchling_se_chatgpt.png, fly, 3 | the downstroke frame has a near wing raised, a SECOND near wing hanging down at the lower left, and the far wing down under the head | the hanging lower-left wing erased |
| 2 | hatchlings death_se 5 | hatchling_se, death, 5 | lying dead: a second left wing stretched out to the far left beside the folded one | the stretched-out wing erased |
| 3 | hatchlings death_s 5 | hatchling_s, death, 5 | the same | the same |
| 4 | hatchlings death_e 5 | hatchling_e, death, 5 | the same | the same |
| 5 | hatchlings death_ne 5 | hatchling_ne, death, 5 | the same | the same |
| 6 | hatchlings death_n 1 | hatchling_n, death, 1 | falling: a third wing raised at the top middle (left wing, wing at the lower right) | the top middle wing erased |
| 7 | storm_challenger walk_se 3 and idle_se 3 | storm_challenger_se, fly, 3 | as #1: a second near wing hanging down at the lower left | the hanging wing erased (with its red spiked edge) |
| 8 | pterodactyl (Storm Sire) attack_se 5 | pterodactyl_fly_dive_se_chatgpt.png, row 2, 5 | coming out of the dive: two left wings, one raised behind the other | the one behind erased (the front wing's edge kept) |
| 9 | assets/icons/hatchlings.png (card portrait) | hatchling_portrait_chatgpt.png | a second wing ARM with its membrane at the bottom left | painted over with the portrait's own dark backdrop |
| 10 | assets/icons/storm_challenger.png | storm_challenger_portrait_chatgpt.png | the same (a second arm with spikes) | the same |

So: **8 game frames with a third wing (10 counting the walk/idle copies), plus the 2 portraits.**

Already handled before this job: the Storm Sire's fly E frame 2 (the owner's red pen; dropped by the importer since 0.20).

### Not used by the game (no fix needed)
- Storm Challenger NE sheet, swoop row frame 2 (three wings, facing south-east): the NE swoop is built from other
  frames (import_storm_line.py NE_SWOOP).

### Looked at and left as drawn (folded wings, they read as two)
- The Storm Challenger's swoop frames 2-3 (SE, S, E) and 2-4 (N), the Storm Sire's dive frames 2-4 (SE, E) and the
  Storm lure arrival frame 4: the wings are folded back in the dive, so their spiked leading edges stack up with the
  back's spine ridge; at game size they read as two folded wings and a crest. If the owner sees three wings in any of
  these, name the frame and it gets a polygon like the others.
- The Hatchling's E fly 3 (one wing up, one down): two wings.
- The Storm Challenger's lying death frames: the long spiked piece at the left is its TAIL (scaly, the spine's spikes),
  not a wing.

## How the fix works (tools/fix_third_wing.py)

- `FRAMES`: per (sheet, row, frame) a hand-drawn polygon in the cut-out frame's pixels, read off gridded zooms. Inside
  it the frame becomes transparent; small pieces cut off by it and thin slivers along the cut go too; the creature's
  new edge along the cut gets the sheet's own dark outline (2-4 sheet px, about one game pixel).
- Every extra wing lay off the body (over the background or beside the other wing), so nothing had to be painted back
  behind it and no frame had to be replaced by a neighbour.
- `PORTRAITS`: a polygon on the 1254 px portrait, filled from the nearest pixels of its dark backdrop (inside the steel
  frame only), then the importer cuts the 64 px icon as before.
- Hooks: tools/import_storm_line.py (`ftw.fix_rows` on each sheet, `ftw.portrait_fixed` around the portrait) and
  tools/import_brood_fathers.py (the Storm Sire's dive sheet). ANCHORS: both importers take the flying frames' anchors
  (the body's middle) from the frames as drawn, before the fix, so a body does not jump when a wing is removed;
  art_data.gd is unchanged. Timing and frame counts are unchanged.
- The skin masks (veterancy) of the Hatchlings and the Storm Challenger were rebuilt (tools/import_vet_skin.py --only).

Pictures for the owner (before on top, after below, enlarged): docs/shots/third_wing/ (`python3 -I
tools/fix_third_wing.py --shots docs/shots/third_wing` rebuilds them).

## What a redraw would still improve

The code fix leaves two wings everywhere, but two frames are weaker for it:
- The DOWNSTROKE (Hatchling and Storm Challenger SE fly 3): with the hanging near wing gone, only the far wing beats
  down; the near wing stays level as in frames 2 and 4. The beat still reads, but a redraw of that one frame with BOTH
  wings down would be better.
- The two portraits: the bottom left is now plain backdrop beside the chest (a little empty).

ChatGPT prompts (each stands alone; attach the reference images named; flat navy background; PNG download):

**Prompt A: Hatchling south-east downstroke.** Attach: the hatchling SE sheet (art/redraws/hatchling_se_chatgpt.png)
and docs/shots/third_wing/hatchlings_walk_se.png.
> Pixel-art game sprite, same style, colours and size as the attached sheet's first row. One single frame: the olive
> baby pterosaur with the red crest, flying toward the bottom-right (south-east), on the DOWNSTROKE: BOTH wings swept
> down below the body, the near wing down-left in front of the body, the far wing down-right under the head. The
> creature has exactly TWO wings, no more. Same body pose and head as frame 3 of the first row. Flat dark navy
> background (#0f1a2a), no shadow, no text. Download as PNG.

**Prompt B: Storm Challenger south-east downstroke.** Attach: art/redraws/storm_challenger_se_chatgpt.png and
docs/shots/third_wing/storm_challenger_walk_se.png.
> Pixel-art game sprite, same style, colours and size as the attached sheet's first row. One single frame: the olive
> pterosaur with the red head crest and red spikes along its wing edges, flying toward the bottom-right (south-east),
> on the DOWNSTROKE: BOTH wings swept down below the body, the near wing down-left in front, the far wing down-right
> under the head. Exactly TWO wings. Same body and head as frame 3 of the first row. Flat dark navy background
> (#0f1a2a), no shadow, no text. Download as PNG.

**Prompt C1: Hatchling portrait.** Attach: art/redraws/hatchling_portrait_chatgpt.png.
> Redraw this framed portrait in exactly the same style, steel frame and dark backdrop. The baby pterosaur shows its
> head, neck and chest and exactly ONE wing (the raised wing at the top left); no second wing arm and no membrane at the
> bottom left: there, its chest and shoulder. Square, the same size, flat dark navy around the frame. Download as PNG.

**Prompt C2: Storm Challenger portrait.** Attach: art/redraws/storm_challenger_portrait_chatgpt.png.
> Redraw this framed portrait in exactly the same style, steel frame and dark backdrop. The pterosaur shows its head,
> neck and chest and exactly ONE wing (the raised spiked wing at the top left); no second wing arm, spikes or membrane at
> the bottom left: there, its chest and shoulder. Square, the same size, flat dark navy around the frame. Download as PNG.

(Save answers as art/redraws/hatchling_se_down_chatgpt.png etc.; the importer would then need a line to use them.)
