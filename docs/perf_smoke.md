# Smoke clipping and big-battle lag (0.26.5, branch smoke-perf)

The owner, playtesting 0.26.x on a phone/tablet:
"The game smoke still clipping." "Game is lagging with many units on screen even in skirmish."
"Maybe the smoke is helping the game to lag."
Earlier: the gunpowder fog is "too buggy, clippy and blinky, takes too long to dissipate... should linger, but
something is off with that animation".

## The short answer

- The clipping was real, and it was not the haze: it was the painted muzzle smoke itself.
  Its picture touches the edges of its frames, so every shot's quick puff (and every chimney) had straight, cut-off sides.
  Its edges are now feathered.
- The blinking had four causes, all fixed:
  every shot's quick puff dimmed in one step and then vanished while still showing;
  the haze moved and faded in 20 small jumps a second;
  the haze vanished for a moment and popped back after the camera jumped;
  a puff at the edge of sight faded out and in as the men's sight flickered.
- The smoke lingers exactly as long as before.
- The smoke is not what makes big battles lag. In every log and every test, the units' own work is by far the
  biggest cost. The smoke is a small part of the game's work (about 3 to 4% of a frame in a 100-musket firefight).
  On a phone its real cost is the graphics chip's fill: blending the see-through puffs. That is now about 22% less.
- The panel of a selected army was redrawn 20 times a second and was the interface's biggest cost. It is now 10 times
  a second: 40 to 50% less HUD selection work, about 30% less HUD drawing.
- The game plays out exactly the same: whole-state traces are identical before and after, and with the smoke on and off.

## 1. The clipping and blinking

### What was wrong

1. Cut edges (the "clipping"). assets/effects/smoke.png has 4 frames of 27 x 25. The painted smoke touches the frame's
   edges: frame 0 left and right, frame 1 on three sides, frame 2 on its left, frame 3 top and bottom.
   Every Musketeer, Guardsman, Horseman, cannon and mortar shot spawns this as its quick puff, and the halls,
   barracks, cottages and Clockwork buildings use it for their chimneys. So straight cut lines showed all the time.
   The lingering haze (scripts/powder_smoke.gd) already hid them with a soft circle in its shader; the quick puffs did not.
   Picture: docs/shots/smoke_fix/smoke_sprite_before_top_after_bottom.png.
2. The quick puff's blink. scripts/effect.gd set its alpha to min(alpha, 0.7) at its next-to-last frame (a step down),
   then freed it at about 0.2 alpha (a pop). Every one of the 196 quick puffs in the test scene vanished while still showing.
3. The haze in steps. The puffs were moved and refilled 20 times a second (12 on LIGHT); the screen draws 60.
   A fresh puff pushed along the shot at 30 to 70 px a second jumped 2 to 4 px each step; a fading one stepped in alpha.
4. The haze popping after a camera jump. Only puffs inside the view (plus a margin) were written to the MultiMesh, at
   each tick. After a jump (a minimap tap, a group key pressed twice) the whole haze was missing until the next tick,
   then popped in at full strength. Picture: docs/shots/smoke_fix/jump_back_00_before_left_after_right.jpg
   (the first frame after jumping away and back: no haze on the left, the haze on the right).
5. Blinking at the edge of sight. A puff faded out (1.5 a second) as soon as one look (every 0.25 s) found its cell
   not seen, and back in at the next. Where a moving army's sight edge flickers, puffs there blinked.

### What changed

- tools/fix_smoke_edges.py feathers the painted smoke: each frame's alpha fades to nothing over 6 px toward the sides
  the art touches, and a soft ellipse rounds the corners. The original is kept in art/world/smoke_effect_original.png;
  the tool always starts from it. Noted in docs/art_style_inconsistency.md (a painted strip with room round the puffs is wanted).
- scripts/effect.gd: an effect with 4 or more frames fades smoothly (smoothstep) from the alpha it was given to 0 over
  its last two frames. No step, and nothing vanishes while it shows.
- scripts/powder_smoke.gd:
  - The shader carries each puff on between the ticks. Each instance's custom data holds its velocity (with the wind)
    and its alpha's rate; a "since" uniform (seconds since the last tick) is set each frame. The vertex shader adds
    velocity x since, the alpha adds rate x since. The puffs glide at the screen's rate.
  - Every live puff the watching side sees is written to the MultiMesh, wherever the camera is. Off-screen quads cost
    the graphics card nothing (they are clipped before any pixel is drawn), and no puff pops at the edge or after a jump.
  - A puff fades out only after two looks in a row (half a second) find it out of sight, and more slowly (0.8 a second).
  - Each puff is an octagon round its soft circle, not a square: the shader already faded everything past half the
    width to nothing, so the corners were blended for nothing. 17% less to fill.
  - A dense 96 px square takes new puffs only up to 14 (was 22). Past 8 every puff there is drawn at 8 / count anyway,
    so the cloud looks the same; the extra puffs only cost fill and work.
  - The watching side's sight grid is looked up once per check, not once per puff.

### The numbers (tools/shot_smoke_fix.gd: 14 Musketeers a side and a Field Cannon firing, THICK, panning and jumping the camera)

| | before (0.26.4) | after (0.26.5) |
|---|---|---|
| quick puffs that vanished while still showing | 196 of 196 | 0 of 201 |
| biggest alpha change of a quick puff in one frame (30 fps) | 0.30, then a pop from 0.2 to 0 | 0.34, ending at 0 (a fade over a sixth of a second) |
| biggest change of a haze puff's drawn alpha in one frame, on screen | 0.52 (the camera jump) | 0.11 |
| haze puffs on screen whose alpha jumped by more than 0.08 in one frame | 332 | 5 |
| haze puffs made | 668 | 617 |

tools/test_powder_smoke.gd passes (its volley test: biggest alpha step a tick 0.085, nothing vanishes while showing,
still lingering 5 s after the last volley, under a light haze 10.4 s after, gone after 22.7 s).
Its out-of-sight check waits 2.2 s now (it fades only after half a second, then more slowly).

Pictures in docs/shots/smoke_fix/ (before on the left or on top, after on the right or below):
- smoke_sprite_before_top_after_bottom.png: the painted smoke strip, enlarged.
- jump_back_00_before_left_after_right.jpg: the frame after a camera jump away and back.
- haze_12s, pan_end, haze_24s, after_12s: the firefight at 12 s, after a pan, at 24 s, and 12 s after it stopped.
  The haze looks and lingers the same.
- muzzle_10_frames_before_top_after_bottom.jpg: ten frames in a row at a Musketeer's line.
To film again: `xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_smoke_fix.gd -- <outdir>`
(it prints the SMOKEFIX line; it works on the old code too).

## 2. The lag

### What the owner's logs say

Five phone/tablet logs from 2026-11-01 to 11-03 (docs/playtests/). At the heavy minutes:

| log | minute | fps | units | busy: units ms/s | game | hud draw | buildings | smoke puffs |
|---|---|---|---|---|---|---|---|---|
| ai_clock_v_brood | 8 | 42 | 111 | 353 | 75 | 43 | 37 | 0 |
| human_crown_v_brood_econ | 9 | 54 | 153 | 345 | 52 | 70 | 39 | 147 |
| crown_expand_workers | 10 | 55 | 129 | 312 | 91 | 28 | 29 | 3 |
| ai_crown_v_crown | 10 | 16 | 46 | 238 | 112 | 40 | 86 | 0 |

- "units" (every unit's 30-a-second tick) is always the biggest, 50 to 70% of the script time.
- The smoke's own time in the logs is under 1 ms a second; most heavy minutes had few or no puffs at all.
  So on the processor the smoke is not the lag.
- With the player's army selected, the HUD is next: hud/selection 25 to 38 ms a second, hud/look up to 49.
- The Crown v Crown game at 16 fps with only 46 units had 58 buildings and ran 1.9 game ticks a frame: the device
  was behind, and each slow frame then had to run two ticks.

### How it was measured here

- tools/stress_swarm.gd, new: `mixed` (n/2 Musketeers against n/2 Raptors in view: volleys, smoke and a melee;
  60 against 60 here) and `smoke:<0..3>` (the smoke level). It now also prints the smoke's FILL: the area of the
  puffs drawn on screen, in screens (1.0: every pixel of the screen blended once). Fill is what a phone's graphics chip
  pays for see-through puffs, and it does not depend on the machine's load.
- This cloud machine was shared with several other jobs (load 8 to 9 on 2 cores), and the load changed during the
  day: two runs of the same code an hour apart differed by up to 2.5 times. So every before/after below is a PAIR:
  the old code (a linked copy of the project with the three old scripts) and the new code run at the same moment.
  Each pair was run twice. Raw numbers: docs/perf/smoke/*.json.
- "Rendered" uses llvmpipe, a software renderer on the processor: it shows draw calls and the CPU side, not a phone's GPU.

### The numbers (paired runs, average of the two pairs)

| scenario | | fps avg | frame ms avg | units ms a tick | HUD selection ms a frame | HUD draw ms a frame | smoke ms a frame | smoke fill (screens, avg / most) | puffs alive at most |
|---|---|---|---|---|---|---|---|---|---|
| muskets: 100 v 100 Musketeers, THICK, headless | before | 49.2 | 20.3 | 27.0 | 0.90 | 1.42 | 0.83 | 1.32 / 3.57 | 914 |
| | after | 51.7 | 19.4 | 26.7 | 0.49 | 1.01 | 0.59 | 1.02 / 2.68 | 782 |
| mixed: 60 Musketeers v 60 Raptors, THICK, headless | before | 107.5 | 9.31 | 11.0 | 0.76 | 1.02 | 0.23 | 0.37 / 1.29 | 292 |
| | after | 109.1 | 9.17 | 11.2 | 0.44 | 0.73 | 0.19 | 0.29 / 1.02 | 264 |
| mixed, THICK, rendered (llvmpipe, 1280 x 720) | before | 6.7 | 149.9 | 8.6 | 0.55 | 0.76 | 0.12 | 0.87 / 2.20 | 292 |
| | after | 6.6 | 151.7 | 9.1 | 0.29 | 0.51 | 0.11 | 0.69 / 1.73 | 264 |
| mixed, smoke OFF, rendered | before | 8.1 | 123.4 | 7.9 | 0.48 | 0.66 | - | - | - |
| | after | 8.3 | 121.2 | 7.9 | 0.24 | 0.44 | - | - | - |

- The smoke's share. Smoke OFF against THICK in the same build, rendered: the renderer's own time per frame
  (llvmpipe, "render cpu") goes from about 80 to about 102 ms, and 0.87 screens of puffs are blended on average
  (2.2 at the thickest). On llvmpipe that did not get cheaper with 22% less fill (its cost here is not the pixels).
  On a phone's tiled GPU it is mostly the pixels: about 22% less fill there. Not measured on a phone.
- The smoke's processor work (moving the puffs, filling the buffer): 0.83 to 0.59 ms a frame in the 200-Musketeer
  firefight, 0.23 to 0.19 in mixed: about a quarter less. It was already small next to the units (27 ms a tick).
- The HUD with an army selected: the selection panel 40 to 50% less, all HUD drawing about 30% less.
- The whole frame: 2 to 5% faster in these paired runs. The units' tick is unchanged (this pass did not touch it).
- The game's side is the same: the whole-state traces (tools/stress_swarm.gd trace:FILE, every game second) of
  mixed THICK, mixed OFF, melee and muskets are byte-identical before and after, and mixed THICK equals mixed OFF.
  The draw tick still draws no game random numbers (test_powder_smoke).

### What is left (the real lag)

- The units' tick is still the lag. A profile of the mixed battle (tools/gd_script_profiler.py) puts the time in
  Unit._tick_unit's own lines (hundreds of small checks per unit, 30 times a second), Game.separation (pushing
  neighbours apart, about 90 us a call under the profiler), Unit._animate and _set_anim, Unit._move, then the grid
  rebuild and the fog stamping. The swarm pass (docs/swarm_perf.md) already took the easy part. The next step is a
  lighter tick for units that only stand and fight, and stepping far-off units' separation less often; both touch
  the simulation, so they need the trace checks again. Not done here.
- The fog's unit stamping can spike (67 ms in one frame in the 200-Musketeer firefight on this machine, 4 times a second).
- The command card is rebuilt 4 times a second with an army selected: 2 to 7 ms a build here. A cheaper build (or 2 a
  second while nothing was clicked) is the next HUD win.
- The replay recorder's picture: 3 to 9 ms, 4 or 5 times a second, on frames without a game tick.
- A phone that falls behind runs two game ticks in its next frame (the 1.9 ticks a frame in the Crown v Crown log),
  which makes it fall further behind. Capping the ticks a frame would make the game slow down instead of stutter on
  such a device; it changes how the game keeps time, so it is the owner's call.
- Not measured on a real phone or in the web build: no phone here, and llvmpipe is not a GPU. If THICK still costs too
  much on the phone, its cap (960) or MERGE (14) can go lower, or the phone default can go to FULL.

## Files

- scripts/effect.gd, scripts/powder_smoke.gd, scripts/ui/hud.gd (the selection layer's signature).
- assets/effects/smoke.png (feathered), art/world/smoke_effect_original.png, tools/fix_smoke_edges.py.
- tools/shot_smoke_fix.gd (pictures and the pop counts), tools/stress_swarm.gd (mixed, smoke:N, the fill line).
- tools/test_powder_smoke.gd (the out-of-sight wait).
