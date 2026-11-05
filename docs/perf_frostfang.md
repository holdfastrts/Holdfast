# Watching computers on Frostfang: where the frames went (0.31.2, branch perf-frostfang)

The owner's log: docs/playtests/2026-11-05/spectate_clockwork_econ_v_brood_econ_frostfang_0310.txt (0.31.0, Frostfang,
seed 3991229265, P1 HARD Brood ECONOMY against P2 HARD Clockwork ECONOMY, watched on his computer with the spectator's
panels open). 87 frames a second at the start, 42 at minute 6, 25 at minute 7 and 8 at the end (1% low 5, 3.5 physics
steps a frame) with only about 120 units. Busy with, at minute 7: units 297 ms a second, the HUD's drawing 209 (its
"rest" layer 176, 5 redraws a second: about 34 ms a redraw), buildings 58, the fog 41, the computers 35; the Brood
computer's "morphs" 32 to 45 ms in single frames at 7:01-7:02; "hud/pause" 33 ms a second at the very end.

## The short answer

- THE BIGGEST CAUSE WAS THE SPECTATOR'S PANELS (PRODUCTION, ARMY & STRUCTURES, AI STORY). Godot keeps only its last 64
  pieces of shaped text; the panels draw and measure hundreds of them (the AI STORY measured every line it wraps word by
  word: "The", "The Crown", "The Crown sends"...), so EVERY piece of text was shaped again on every redraw. Here: 2.5 ms
  a redraw at minute 1, 18 to 19 ms at minutes 6 to 8; and with the mouse moving the layer was redrawn on every frame
  (its signature held the mouse's position). Now the text is shaped once and kept (scripts/ui/text_cache.gd), each panel
  is on its own layer and is redrawn only when what it shows changes, and the mouse redraws a panel only when it moves
  onto or off one of its buttons. A redraw now costs 0.2 ms (PRODUCTION, 4 a second), 0.6 ms (ARMY & STRUCTURES, about
  3 a second) and 2 to 3 ms (the AI STORY, about once a second); the whole HUD's drawing went from 15 to 21 ms a frame
  (mouse moving, minutes 5 to 10) to 0.3 to 0.5 ms. On the owner's computer that is about 170 ms a second given back.
- THE FOG OF WAR WHILE WATCHING: a match you play stamps the sight of every unit a row at a time (docs/perf_units.md),
  but watching computers it still stamped every cell of every disk, twice (seen, then explored). Watching now uses the
  rows too, and the explored map of each side is marked in the same pass: 4.5 to 8.3 ms an update down to 2.0 to 3.9 ms;
  the very same grids (checked: every side's seen and explored map hashed every 5 game seconds, identical to 0.31.1).
- WHY THE UNITS COST TWICE AS MUCH A UNIT HERE: not the gears, the snow or the winding. It is WHAT the units are. In
  the 7th minute (6:00 to 7:00, 94 to 122 units) the units' tick was: the Brood's grubs gathering 38%, the Clockwork's Winders gathering 16%, the
  Brood's ROOTED creatures (6 Rootmaws, 6 Mound Turtles, the Mother, 3 Sires) 26%, the eggs 2%, the whole army only
  about 15%. A gathering grub costs 53 microseconds a tick and a Winder 36, a standing Raptor 37; a rooted Rootmaw 79,
  a Mound Turtle 66, a Sire 110 to 135, the Mother 135 to 173 (they look for eggs, food and ground every tick, and on
  screen they redo their rooted pictures). His Redrock game (Brood Economy v Crown Balloons, 239 units) had a big army
  and fewer workers for its size. Both Economy computers make the most expensive units there are, per unit.
  The units' tick got about 5% cheaper (the Mother's 20%: below), the game exactly the same.
- THE BROOD COMPUTER'S "MORPHS" SPIKES: what a grub turns into, and where. Its spot finders (the Rootmaw's, the
  turtles', new ground) ask hundreds of spots, each checked against its base layout (BroodLayout). The same spots were
  asked two and three times in one think: the answers are now kept for that think (exact). That saved little: the
  spikes are a few fewer and smaller (25 to 35 ms now and then), not gone. What would remove them changes the computer's
  timing (section 5).
- The game plays out EXACTLY the same: the whole state of the reproduction (every unit, building, resource, and every
  side's fog grids) every 5 game seconds for 10 minutes is the same file, line for line, on 0.31.1 and on this branch
  (13,577 lines); and three stress scenarios (clockbrood, grubs, mixed) every game second.

## 1. The reproduction

tools/perf_bench.gd has a new `spectate`: every player is a computer and you watch, the spectator's VIEW, PRODUCTION,
ARMY & STRUCTURES and AI STORY open, as the owner watches (the mouse moving and the selection changing as before):

    godot --headless --path . --fixed-fps 60 --script res://tools/perf_bench.gd -- frostfang brood clockwork \
        seed:3991229265 strat:economy strat0:economy spectate minutes:10 spike:60 [kinds] [trace:/abs/file]

`kinds` prints each minute the units' ticks by kind and order and the buildings' by kind (Prof.by_kind; off in a real
match); every minute a "PERF each" line gives the calls and the ms a call of the HUD layers, the morphs, the fog and the
buildings. With `spectate`, `trace:` also writes the fog grids. Headless at a fixed 60 frames a second: only the game's
own work is measured (simulation and the scripts that build the drawing, the HUD's _draw included: its draw calls are
recorded headless too); the owner's computer is about twice as slow as this cloud machine at the same scripts.

The reproduction follows his game closely: 94 units at minutes 5 and 6, 122 at 7 (his log: 94, 98, 122), and before the
fix 42 frames a second at minute 6 here too (his: 42).

## 2. Before and after, minute by minute

0.31.1 (main) and this branch run at the same time on the same machine (two cores, so each had one), the same match:

| minute | units | fps before | after | 1% low before | after | worst ms before | after | cpu s before | after |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 20 | 183 | 358 | 9.2 | 13.5 | 2667 | 2155 | 11.0 | 5.8 |
| 2 | 30 | 132 | 354 | 18.8 | 35.5 | 234 | 226 | 17.8 | 6.8 |
| 3 | 43 | 82 | 278 | 18.6 | 49.6 | 81 | 39 | 28.0 | 8.4 |
| 4 | 70 | 70 | 214 | 17.2 | 40.0 | 80 | 60 | 39.7 | 11.0 |
| 5 | 94 | 49 | 148 | 15.4 | 20.1 | 220 | 298 | 69.1 | 15.6 |
| 6 | 94 | 42 | 124 | 16.6 | 16.7 | 344 | 454 | 85.1 | 18.8 |
| 7 | 122 | 38 | 146 | 19.1 | 28.8 | 63 | 66 | 94.4 | 20.1 |
| 8 | 186 | 35 | 112 | 15.6 | 21.1 | 133 | 76 | 103.4 | 28.4 |
| 9 | 156 | 33 | 119 | 14.1 | 24.2 | 250 | 217 | 108.0 | 29.8 |
| 10 | 188 | 34 | 135 | 15.9 | 35.5 | 77 | 41 | 106.0 | 26.3 |

(cpu s: the processor time the whole program used in that game minute. Minute 1's worst frame is the match loading.)

The parts, ms a frame (headless, 60 frames a game second):

| minute | units ms/frame before | after | buildings | after | fog | after | ai | after | HUD drawing | after |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 0.71 | 0.58 | 0.11 | 0.09 | 0.09 | 0.03 | 0.13 | 0.12 | 2.35 | 0.24 |
| 2 | 0.98 | 0.87 | 0.15 | 0.13 | 0.12 | 0.03 | 0.21 | 0.20 | 4.67 | 0.27 |
| 3 | 1.44 | 1.30 | 0.24 | 0.20 | 0.17 | 0.05 | 0.17 | 0.16 | 8.32 | 0.31 |
| 4 | 1.84 | 1.90 | 0.28 | 0.26 | 0.21 | 0.07 | 0.19 | 0.23 | 9.93 | 0.35 |
| 5 | 2.15 | 3.00 | 0.29 | 0.40 | 0.23 | 0.12 | 0.25 | 0.37 | 15.53 | 0.39 |
| 6 | 2.44 | 3.58 | 0.35 | 0.46 | 0.28 | 0.16 | 0.27 | 0.44 | 18.14 | 0.46 |
| 7 | 2.92 | 3.15 | 0.44 | 0.46 | 0.32 | 0.12 | 0.33 | 0.38 | 19.86 | 0.33 |
| 8 | 4.22 | 4.47 | 0.51 | 0.53 | 0.45 | 0.20 | 0.44 | 0.47 | 20.22 | 0.38 |
| 9 | 4.40 | 4.01 | 0.54 | 0.46 | 0.50 | 0.24 | 0.48 | 0.46 | 20.75 | 0.33 |
| 10 | 3.80 | 3.34 | 0.56 | 0.47 | 0.52 | 0.21 | 0.54 | 0.51 | 20.82 | 0.31 |

The units' and buildings' columns of minutes 5 and 6 are noise: the branch's run shared its core with the tests then. The
cleaner measure of the units is by kind, the same minute of two runs that each had a core (the 6th minute, `kinds`):

| kind, order | before, microseconds a tick | after |
|---|---|---|
| all the units' ticks in that minute | 9,032 ms | 8,536 ms (-5.5%) |
| grub gathering | 49 | 46 |
| Raptor attack-moving | 63 | 62 |
| Winder gathering | 40 | 38 |
| Rootmaw, rooted | 55 | 51 |
| Mound Turtle, rooted | 46 | 42 |
| the Brood Mother, rooted | 119 | 93 |
| Tyrannosaur Sire, rooted | 87 | 83 |
| Dilophosaurus Sire, rooted | 62 | 58 |

## 3. Per item

| item | before | after |
|---|---|---|
| spectator panels, one redraw (minutes 6 to 10) | 18 to 20.5 ms ("rest": every frame with the mouse moving, 5 a second with it still) | PRODUCTION 0.23 to 0.34 ms (4 a s), ARMY & STRUCTURES 0.6 to 1.0 ms (3 a s), AI STORY 2.2 to 3.2 ms (about 1 a s), the rest 0.1 to 0.2 ms |
| the HUD's drawing, ms a frame (minutes 5 to 10) | 15.5 to 20.8 | 0.33 to 0.46 |
| fog of war, one update (minutes 6 to 10, 4 a second) | 4.5 to 8.3 ms | 2.0 to 3.9 ms |
| the units' tick, ms a frame (minutes 5 to 7, an earlier pair) | 2.02 / 2.47 / 2.86 | 1.89 / 2.28 / 2.60 |
| the buildings' tick, ms a frame (minutes 5 to 7, the same pair) | 0.29 / 0.36 / 0.43 | 0.25 / 0.31 / 0.38 |
| Brood computer, "morphs", ms a think (minutes 6 to 10) | 2.0 to 3.4 on average, single frames of 30 to 60 | 2.4 to 3.2 on average, single frames of 25 to 35 (a few fewer) |
| "hud/pause" (the menu open, its music list) | its text shaped on every redraw | shaped once (the same text cache) |

The units and buildings rows come from an earlier pair of runs that each had a core to itself (before the last few exact
changes: the footprints, the gear rings and the music list kept).

## 4. What was changed (all exact: the same game)

### 4.1 The HUD (scripts/ui/hud.gd, scripts/ui/spec_panels.gd, scripts/ui/text_cache.gd)

- TextCache: `line(font, s, size)` shapes a TextLine once and keeps it (two generations of 3,000: text that came and
  went is let go); `width`, `draw` (outline and fill at a baseline point, as draw_string_outline / draw_string), `wrap`
  (the AI STORY's word-wrap, kept per text and width). hud._text, the panels' _txt (and its "…" cut, kept) and the music
  list's fitting use it. The same glyphs in the same places.
- The panels each have a HUD layer ("spec prod", "spec army", "spec story", drawn before "rest"; SpecPanels.draw_one),
  each with its own signature (SpecPanels.sig): where it sits, the mouse on its buttons, its dropdown, and what it shows
  (PRODUCTION 4 times a second as before, ARMY & STRUCTURES its numbers (worked out twice a second as before), the AI
  STORY its version and scroll). An open player list is drawn on "rest" (over the panels).
- The mouse: the layers' signatures hold which button the mouse is on (SpecPanels.hover_key, Hud._view_hover), not where
  the mouse is.
- SpecPanels.layout() is worked out once per HUD look (20 a second) and kept (the hover, a press and the drawing use it);
  hud.prod_items once a frame; the top bar's supply once a frame (Hud.supply_of: it counts every unit and was asked for
  every player 20 times a second; the ARMY panel still counts it fresh twice a second).

### 4.2 The fog of war while watching (scripts/game.gd)

`_update_vis` sends every sight disk that hides nothing (no high ground near a low-ground eye) to the row runs while
watching too, and `_fog_runs_flush` marks the side's explored map (explored_by) with the swamp check `_explore` did. A disk
from low ground with high ground near still goes cell by cell (_reveal, _explore), as in a match you play.

### 4.3 The units and buildings (exact)

- GearTurn.near asks the bands' own grid (GearNet.band_maybe): a unit in the big box round a Clockwork base's rings but in
  a cell no band reaches skips the ride's tick (band_at would have said -1: the same tick).
- GearNet.ring_n kept per kind, size and gear (asked 270,000 times in two minutes by the rings' turning, drawing and drive).
- BroodRoot.fp kept per kind and scale (every rooted creature's footprint: its edge for every unit near it).
- BroodRoot.layer (a rooted creature's pictures, at every animation step on screen): its seven node look-ups only when
  its children change; its frame's key an array, not a formatted string.
- WorkerLabels.entities kept for the frame (the cursor, the HUD's hover and the labels' drawing each asked it, every
  unit looked at with a Brood on the map).

### 4.4 The Brood computer (scripts/ai_brood_new.gd, scripts/brood_root.gd)

`_nb_morphs` runs as a MEMO ROUND (BroodRoot.memo_begin / memo_end): place_problem keeps its answers until the grub is
given its order (nothing moves, roots or is ordered meanwhile; checked: nothing it calls before the order changes
anything place_problem reads).

## 5. What is left, for the owner to choose

None of these keeps the game exactly the same; each changes WHEN something is looked at:

1. The Brood's rooted creatures look for things every tick: a Sire looks for eggs in his nest (units_near, sorted) 30
   times a second, the Mother her laying levers, a Rootmaw its ground. Four times a second would cut most of their 79 to
   173 microseconds a tick (about a quarter of the units' work in this match). Eggs would roll into a nest and redden up
   to a quarter second later.
2. The grubs' and Winders' gathering (54% of the units' work here): a walking grub works out its Rootmaw's flank point
   and checks the Rootmaw's ground every tick; every few ticks would do.
3. The Brood computer's spot searches: split one search over several frames (as the Crown's hall pick, 0.30.6). The
   answer would come a few frames later; the spikes (25 to 35 ms) would go.
4. THE CLOCKWORK COMPUTER'S NEXT CLOCKTOWER (the longest single freezes left, in his log too): "ai/build" 304 ms at 1:47
   and 152 ms at 4:49 in his log, 223 and 145 ms here (its spot search, scripts/clock_sites.gd, when it picks where its
   next Clocktower goes), and 45 to 66 ms now and then later. The Crown's hall pick had the same problem and was spread
   over frames in 0.30.6 (it measures the ground ahead, a few ms a frame, and keeps it): the same for the Clockwork is
   the next job. Not done here: it changes when the computer has its answer.
5. Right after each of those two searches his log has a frame of 218 and 418 ms that no part names ("the rest"); here
   too (221 and 298 ms, both versions): the engine's own work, most likely a picture or a shader made the first time (the
   new Clocktower's ghost). Worth a look with the renderer's profiler.

## 6. Tests

- test_gear_turn, test_gear_turn_match, test_brood_new, test_clockwork_eco (check:1 against the Brood and the Crown),
  test_spectator, test_brood_production, test_camera_stays: pass. (test_spectator caught the ARMY panel's supply kept
  from earlier in a frame: it is counted fresh again.)
- tools/stress_swarm.gd traces (clockbrood, grubs, mixed, 20 s): identical to 0.31.1.
- tools/test_perf_armies.sh: PASS (melee x0.92, clockbrood x0.95 of the baseline).
- The boot check (godot --headless --quit-after 300): no script or parse errors.
- test_brood_new_defence does not finish on 0.31.1 either: it stops moving at 5:17 of its third wave (muskets) with the
  processor busy, on main and on this branch alike. Not from this work; worth a look.
- The spectator panels' pictures (tools/shot_spectator.gd): the same panels, the open list over them.
- Godot quits with "Aborted" at the end of a headless run (perf_bench, the tests), on main too.
