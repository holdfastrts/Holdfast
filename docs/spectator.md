# The spectator overhaul (0.27.0)

The owner's request (2026-11-03): production per player chosen independently of VIEW, a panel of every player's army
and structures, and an AI storytelling device that explains the computers' choices and speaks like a narrator, with a
quick mute.

## What is on screen

Only while watching computers or a replay (`game.spectating()`); a match you play has none of it (no `AIStory`
node, the panels are never made, N does nothing).

| Panel | Where | Its own dropdown | Shows |
|---|---|---|---|
| VIEW (unchanged) | top centre | follow / free / all vision | whose fog and camera |
| PRODUCTION | right column, top | All players / P1..P4 | one row per player: "P1" and its queue icons with bars (`hud.prod_items`) |
| ARMY & STRUCTURES | right column, under it | All players / P1..P4 | name, army value, supply; resources with the painted icons (`assets/ui/stats/res_*.png`, tension icon); unit icons with counts (army, then workers) and building icons with counts (going up: dimmer, "+n", the bar of the furthest along) |
| AI STORY | left column, under the players' resource lines | All AIs / each computer | the story feed, newest first; speaker button = narrator mute |

- Each panel opens and closes by its title; the dropdowns are independent of each other and of VIEW
  (`SpecPanels.team`, `SpecPanels.open`, remembered for the session; on a phone ARMY starts closed).
- The columns keep clear of VIEW, the minimap, the hotkey bar, the selection panel, the command card and a replay's
  bar. Panels in a column share it by water-filling (one that needs little gets it, the rest share); what does not
  fit shows "... more". With four players on a phone that is often the case: pick one player or close a panel.
- AI STORY: the mouse wheel scrolls; on a phone a tap on the feed pages back (and from the oldest to the newest).
- Code: `scripts/ui/spec_panels.gd` (drawn by `hud.gd` `_draw_rest`, input via `_hud_has` / `_press` / the wheel).
  The old PRODUCTION button beside VIEW is gone (`prod_items` stays in hud.gd).

## The AI STORY (`scripts/ai_story.gd`, `scripts/ai_story_lines.gd`)

Sources:
1. The computers' own match-log lines. `AI._physics_process` sets `MatchLog.ai_team` while a computer thinks;
   `MatchLog.add` passes those lines to `AIStory.from_log`, which strips the player prefix and runs the phrase book.
2. The plan at the start (level, strategy and what it means, the Crown's opening) from `game.ais`.
3. A look once a second at each computer's buildings: its first building of each kind ("starts its first Barracks,
   to make Musketeer, Dragoon, Horseman") and each new hall ("starts a new base").
4. New in ai.gd: every attack wave after the first now writes "'s wave N goes out (S supply; the next waits for X)".

The phrase book `AIStoryLines.RULES` is data: `[regex on the line after the player, English template, priority,
tag]`. The template's first `%s` is the player, then the capture groups in order; `""` drops a line. Lines no row
matches are kept as dim details in plain English. To add a new AI line: add a row, and its pt/es to
`tools/i18n/49_spectator.txt` (the test checks every template has both and fits its pattern).

Feed rules (`AIStory`): the same sentence by the same player within 45 s is dropped; details (priority 1) at most
one per player per 6 s; two lines of one player and one tag within 10 s are merged (the newer words, "×2"; never for
priority 3). Priority 3 = big decisions (bright, spoken), 2 = telling (normal, spoken only after 12 s without speech),
1 = details (dim, silent). At most 160 lines are kept.

Replays: every story line goes into the replay being recorded as an event `["ai", team, template, args, prio, tag]`
(also in matches you play against computers, so their replays have it); `ReplayPlayer` tells them at their time,
and a seek rebuilds the story silently. Replays recorded before 0.27.0 say they have no story.

## The narrator (`scripts/narrator.gd`)

Godot's text-to-speech (`DisplayServer.tts_*`, project setting `audio/general/text_to_speech=true`): a voice for the
game's language (pt: pt_BR first), "P1" read as "Player 1". One line at a time (it polls `tts_is_speaking`); more than
2 waiting: the biggest and newest are kept; a line spoken over 9 s is cut for a waiting big one. Not spoken while a
replay runs faster than 2x or is paused. Mute: the speaker button, the N key (free while watching: 0-8 are VIEW),
or Settings > SOUND > SPECTATOR NARRATOR; NARRATOR VOLUME (0-100) and NARRATOR SPEED (0.8x-1.6x) are there too.
No voice (or no speech engine, e.g. Linux without speech-dispatcher): text only, with a note on the panel. A browser
lists its voices late: it looks again every 3 s, 10 times.

## Tests and pictures

- `tools/test_spectator.gd` (headless, ~4 min of a 4-player computer match, the narrator pretended): plans, the
  phrase book (patterns fit, pt/es), a log line rewritten with its reason, replay recording, de-duplication, burst
  limit, merging, the three dropdowns independent of each other and VIEW, panels not overlapping, exact army /
  worker / building / value / supply counts per player, the narrator never overlapping, pile-up and mute, Portuguese
  and Spanish text, and a match you play having none of it. All pass. (Godot aborts at quit after "ALL OK" with exit
  134; other tests, e.g. test_brood_production.gd, do the same: not this work.)
- `tools/shot_spectator.gd`: pictures in `docs/shots/spectator/`: `pc_*.png` (1280x720) and `mobile_*.png`
  (2340x1080, the phone layout): `_all` (all players), `_picks` (each panel on another player, VIEW on a fourth),
  `_dropdown` (the AI STORY's list), `_closed` (ARMY closed), `pc_pt.png` (Portuguese).

## Open

- The narrator's voice was only pretended here (no speech engine on the build machine): to be heard on the owner's
  Windows / Android / browser.
- Some AI lines carry English reasons inside them (the scout's verdicts, a rush's "why"): the common ones are
  translated, the rest stay English in pt/es.
- With four players and all three panels open the columns are full; a phone shows one or two players per panel.
