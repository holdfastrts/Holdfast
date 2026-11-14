# Replays: units not rendering? (job replay-render, 0.35.8)

The owner, 2026-11-13 (v0.35.6, the web build, Mirewood, Crown against a Hard Brood on RUSH, the replay watched after
surrendering): "in the replay there are characters that are not rendering". His pictures are in
`docs/playtests/2026-11-13_mirewood_*.png`: round the Crown's ramp Cottage and Gate at about 3:17 the Brood's Raptors
looked like health bars, target markers and pink spiky blobs.

## What the pictures show

**The Raptors in his pictures are drawn.** I read the pixels of his screenshots against the Raptor's art:

- the olive pixels round the pink spikes are the Raptor's own painted body colours, at full strength: (96,100,12),
  (130,131,18), (145,141,31) in his picture against (93,96,8), (101,102,13), (112,115,12) in
  `assets/units/raptor/attack_e.png`; the moss under them is greyer and bluer;
- the pink is the key red of the crest and spikes (`team.gdshader`) in the Brood's team pink, also at full strength;
- the tall pink stripes by the Cottage (`docs/shots/replay_render/owner_raptors_from_behind.png`) are Raptors seen
  from behind (`idle_n` / `walk_n`, `raptor_walk_n_art.png`): from the back a Raptor is its spine, and its olive body and
  legs on Mirewood's olive moss are very hard to tell apart;
- the black bars are their health bars (damaged Raptors), the empty red ring the selected Horseman's target.

So nothing in those moments failed to draw: the Raptor reads badly from behind on that ground. That is an art question
for the owner (below), not a replay bug.

## What was looked for, and where

- **Both replay formats** (FULL / LIGHT pictures: `ReplayPlayer`, the game a puppet; MIXED: `ReplayMix`, the game
  played again from keyframes and commands), with the owner's setup: Mirewood, his seed, the Crown against a Hard Brood
  on RUSH, and a match with every unit kind of the factions in it.
- **The web build itself.** `tools/web/build_web.sh` with a throw-away main scene that plays a recorded replay, in
  headless Chromium with WebGL (SwiftShader), next to the desktop (OpenGL 3, the same Compatibility renderer): the
  same units, the same bodies (the pictures matched). Nothing web-only.
- The suspects in the task: the strips and frame counts (every unit's frame is its art's cell; no sliver of a strip),
  the 10 Hz crowd step, the fog in playback (FOG: ALL shows everything; the human's own fog changes nothing in what is
  recorded: the recorder sees all), Brood-only paths (rooting, eggs, hatching, the moult, veterancy skins, the venom
  masks), the team shader's uniforms (no `hide_horse`, no tint, no wash on a Raptor).

## What was wrong, and is fixed

1. **A replay standing still showed stale pictures.** A unit only steps its picture while the world runs and it is on
   screen (`Unit._animate`). Paused, or right after a jump on the timeline (every unit is made anew there, in its first
   picture: standing, facing south), a unit the camera came to kept that old picture until play resumed: a pack of
   Raptors running at a wall stood about facing the viewer (`paused_jump_live_before_after.png`: the match, before,
   after). Now `NetPuppet.pose_in_view` gives every unit in view the pose and heading it has at that moment
   (`Unit.refresh_pose`: its strip and view for what it is doing, its frame, a Brood creature's own look, a horse being
   got on hidden as the rider's strip draws it). The viewers call it when they pause, after a jump, at the end, and
   while paused whenever the camera moves (FULL / LIGHT: `ReplayPlayer._process`; MIXED: `ReplayMix._process`).
   Pictures only: nothing in the match is changed.
2. Three script errors on freed things seen in the long runs (the live game has them too): an Officer choosing pistol
   or sabre against a target freed that tick (`Unit._pick_pistol`), a Missionary whose patient was freed (`_heal`), a
   Winder repairing a building freed meanwhile (`_repair`, `_work_sound`).

## The test

`tools/test_replay_render.gd` (xvfb, OpenGL 3, 1280x720):

    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/test_replay_render.gd \
      -- rec:full|light|mixed a:<faction> b:<faction> [map:<id>] [secs:<n>] [shots:<dir>]

Two Hard computers play on Mirewood (the owner's seed) with two of every unit kind of each side's faction added at 20 s;
the replay is recorded, then watched from the start at 8x as the owner did, stopping every 15 s on the busiest fight,
then once more after a jump while paused, and after a jump back. At each stop:

- **sprites**: every unit on screen has its sprite shown, a strip of `assets/units/`, a frame the size of its art's
  cell, a visible alpha, and the POSE of what it is doing now (not a picture left over from before a pause or a jump);
- **bodies drawn**: the units on screen are looked at in groups of ones clear of each other, with everything else on
  the field made see-through (the ground, buildings, rooted creatures, trees, the other units) and the HUD off: the
  picture with each unit's sprite and without it must differ over at least 15% of the frame's painted pixels. A unit
  that fails is looked at again alone. (Without the clearing, units behind the Brood Mother, a Tyrannosaur's nest, a
  balloon, a tree or a HUD panel looked "missing".)

Results on 0.35.8 (each run about 4 minutes on this 2-CPU machine):

| matchup | FULL | LIGHT | MIXED |
|---|---|---|---|
| Crown v Brood (the owner's) | ALL OK | | ALL OK |
| Clockwork v Crown | ALL OK | ALL OK | |
| Clockwork v Brood | | | ALL OK |

With the pose fix taken out, FULL fails at once (`paused_jump_sprites`: balloons, the band, Venom and Storm Challengers
standing in their first picture). `tools/test_replay.gd` (FULL, LIGHT, MIXED) still passes.

`tools/shot_replay_render.gd` films the owner's case: the match and its replay at the same clocks, the camera on the
Raptors nearest the Crown's hall (`live_<n>.png`, `replay_<n>.png`).

## For the owner

- If you still have that match's replay (the REPLAYS page, 13 November), send the file and the same test can look at
  exactly those moments.
- **The Raptor from behind on Mirewood.** Its back view is its spine; on olive moss its olive body all but disappears,
  so a pack climbing a ramp reads as pink spikes. Options, your call: a darker outline or belly shade on the Raptor's
  `walk_n` / `idle_n` strips (a ChatGPT redraw), a faint team-coloured ring under every unit in replays and for
  spectators, or nothing.
