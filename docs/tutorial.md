# The tutorial (0.30.0)

The owner (2026-11-04): "We should have a TUTORIAL button and a CAMPAIGN button. People who want to learn the game
press Tutorial. Campaign is for people who know how to play and want the story."

So the main menu has TUTORIAL beside CAMPAIGN (the grid is now 4 x 3: TUTORIAL, CAMPAIGN, SKIRMISH, ONLINE / HOW TO
PLAY, REPLAYS, EDITOR, SETTINGS / CONTINUE, EXIT). HOW TO PLAY stays. The campaign is unchanged (its prologue need not
teach any more).

The lessons are built on the campaign's mission engine (docs/campaign_engine.md): each lesson is a mission file with
"tutorial": true and a list of STEPS. They are listed in their own file (campaign/tutorial.json), never in the
campaign's storylines, so the CAMPAIGN never shows them.

## The lessons

Every lesson is played on Kestrel Rise (small, a high main base with one ramp). The teacher speaks in the dialogue box,
one short line at a time; the last line of a step stays up until the next step, so the instruction can be read again.
The step's TASK stays on the LESSON panel (top left), with the last task ticked above it. A gold POINTER shows where
to look. Computer and phone get their own words where the controls differ ("Right-click" / "Tap", "the mouse wheel" /
"pinch").

### The Basics (t01_basics; the Crown, Sergeant Holt)

Five Musketeers and no base (the controls are the same for every faction).

| step | the player | done when |
| --- | --- | --- |
| camera | moves the view (edge, arrow keys, middle button / two fingers) | the camera moved 260 px |
| zoom | zooms (wheel / pinch) | the zoom changed |
| select_one | clicks / taps one Musketeer (ring on them) | one is selected |
| select_all | drags a box / double-taps | all five are selected |
| move | right-clicks / taps by the gold ring | 4 stand in the ring |
| attack | attacks three bandits (shown for a minute) | the bandits are dead |
| card | presses HOLD on the command card or H (frame on the card) | 3 are on HOLD |
| minimap | clicks / taps the minimap (frame on it) | the minimap was used |
| group_set | Ctrl+1 / holds 1 on the bar (frame on the bar) | a group holds 3 |
| group_select | presses / taps 1 | a group was called |
| end | reads | (the lesson is won) |

### The Crown (t10_crown; Sergeant Holt)

The normal Crown start (Town Hall, Farm, 4 Labourers), plus a Horse Breeder. A little gold comes from "the treasury"
at the Barracks, the Musketeers (and 30 powder), the Foundry and the cannon, so the lesson doesn't wait on harvests.

hall (select the Town Hall), labourer (train one), soil (reads: harvests, soil runs out), cottage (build one: supply),
mill (a Powder Mill), mill_crew (2 Labourers in it; saltpetre runs out), barracks, musketeers (3), wall (palisade and a
gate across the top of the ramp: 3 pieces and a finished gate), foundry, cannon (a Field Cannon, its horse from the
Breeder), ridge (3 Musketeers on the high ground over the ramp), raid (4 enemy Musketeers come up the ramp: beat them;
they can't see up the cliff), end.

### The Clockwork (t20_clockwork; Master Tock)

The normal Clockwork start (Clocktower, a Cog Press, 4 Winders). tower (select it), winder (train one), gear_view
(open the GEAR VIEW: ` or the card's button), gear_view_off (close it: green turns, red stopped), press (a second Cog
Press, SMALL or BIG GEAR with G, meshing), press_crew (2 Winders on each press), mainspring, tension (Winders on it until
10 Tension), works (a Light Works), soldiers (2 Clock Soldiers), end (machines run down away from a Clocktower or a
Spring Tower; Winders wind and repair them).

### The Brood (t30_brood; The Old Hunger)

The normal Brood start (the Mother rooted, a Rootmaw, 5 grubs). mother (select her: if she dies you lose), eggs (pick
GRUB on her card), food (reads), turtle (a grub's BUILD: a Mound Turtle at the foot of the ramp: supply, swamp, new
ground), rootmaw (a Rootmaw on the turtle's swamp), rootmaw_crew (2 grubs on each Rootmaw), sire (a Tyrant Sire rooted
beside her; 150 food given), raptors (a Raptor egg from her: 2 Raptors hatch), end (rooted creatures never fight;
UPROOT, GROW, guard her).

### The practice games (t19_crown_practice, t29_clockwork_practice, t39_brood_practice)

A whole game against an Easy computer (Crown v Clockwork, Clockwork v Brood, Brood v Crown), ended as a skirmish is
("normal_end": true: destroy every enemy building, or kill the Brood Mother). The steps are hints that follow what
the player does: more workers, the first production building, an army of 6 (10 Raptors), then where the enemy is
(an arrow to the far corner). At 7:00 a line says the land runs out: expand. Lost, the end says TRY AGAIN (no tick)
and offers PLAY AGAIN; won, LESSON DONE and the BATTLE REPORT.

## Progress

A lesson won is kept in `user://tutorial.json` ({"done": {id: {"times": n}}}): the list shows a tick, chooses the first
lesson not done, and after a lesson its NEXT LESSON button starts the next one in the list.

## Files

| what | where |
| --- | --- |
| the lesson list | `campaign/tutorial.json` (groups: id, title, faction, lessons) |
| the lessons | `campaign/missions/t*.json` |
| texts (pt, es) | `tools/i18n/campaign/tutorial.txt` (the lessons), `tools/i18n/51_tutorial.txt` (the pages' words) |
| list and progress | `scripts/campaign/tutorial.gd` (Tutorial) |
| the TUTORIAL page, LESSON DONE | `scripts/campaign/tutorial_menu.gd` (TutorialMenu) |
| steps written out | `Campaign.expand_steps` (scripts/campaign/campaign.gd) |
| the tutorial's conditions, `mark`, `point` | `MissionRun` (scripts/campaign/mission_run.gd) |
| pointer, held last line, the LESSON panel | `MissionUi` (scripts/campaign/mission_ui.gd) |
| what the map can't show | `Game.note_tutorial` (called by the minimap and the group bar) |
| test | `tools/test_tutorial.gd` (`godot --headless --fixed-fps 30 --script res://tools/test_tutorial.gd [-- only=<id>]`) |
| screenshots | `tools/shot_tutorial.gd` -> `docs/shots/tutorial/` |

## How a lesson is written

```json
{"id": "t10_crown", "tutorial": true, "title": "...", "summary": "...", "learn": ["...", "..."],
 "map": "kestrel_rise", "modes": ["solo"],
 "sides": [{"id": "you", "name": "The Crown"}, {"id": "raiders", "name": "Raiders"}],
 "teams": [{"id": "you", "side": "you", "faction": "crown", "colour": 1, "start": "standard", "hall_tag": "hall", "control": "p1"},
           {"id": "raiders", "side": "raiders", "faction": "crown", "colour": 0, "start": "none", "control": "script"}],
 "areas": {"ramp_top": [6, 17, 5, 3]},
 "speakers": {"teacher": {"name": "Sergeant Holt", "side": "you"}}, "teacher": "teacher",
 "steps": [
   {"id": "cottage",
    "say": ["Men need room. A Cottage gives supply.",
            {"pc": "Select a Labourer, press BUILD (B)...", "phone": "Select a Labourer, tap BUILD..."}],
    "task": "Build a Cottage.",
    "point": {"kind": "labourer"},
    "do": [{"give": {"team": "you", "gold": 100}}],
    "wait": {"built": {"kind": "cottage"}}}],
 "debrief": {"you": {"text": "..."}}}
```

A STEP: `id`; `say` (lines: a text, or {"pc", "phone"}, or the id of a line in "lines"; spoken by `who` or the lesson's
`teacher`); `task` (the LESSON panel's line, a text or {"pc", "phone"}); `point` (below); `do` (actions when it
starts: any mission action); `wait` (a condition: when it holds the step is done; none: done once its lines are read);
`then` (actions when it is done); `delay` (seconds before it starts, 1 by default), `after` (seconds the condition must
have held, 0.6). The steps run one after another; when the last one is done the lesson is won (`"steps_end": "win"`,
the default; `""` lets the match go on to its normal end, as the practice games do with `"normal_end": true`).

Campaign.expand_steps writes them out as the engine's own parts: lines "<step>_<n>", a hidden task objective
"task_<step>" (kind manual, "task": true: not optional, never decides the end), and the triggers "start_<step>" (after
"done_<previous>": `mark`, the lines, the task, the pointer, `do`) and "done_<step>" (the wait: the pointer off, the task
ticked, `then`). Each step's `wait` is measured from its start (`mark`: the camera, the zoom, the counts, the noted
actions).

### Conditions the tutorial adds (any mission may use them)

| key | true when |
| --- | --- |
| `{"selected": {"kind": k or [ks] or "any" or "army", "count": n}}`, `{"selected": {"none": true}}` | the player has n of that selected (or nothing) |
| `{"camera_moved": px}` | the view moved that far since the step began |
| `{"zoomed": true}` | the zoom changed since the step began |
| `{"more": {"kind", "count"}}` | the player has n more of that kind than when the step began (a placed site counts) |
| `{"built": {"kind", "count"}}` | n finished buildings of that kind |
| `{"rooted": {"kind", "count"}}` | n rooted Brood creatures of that kind |
| `{"crew": {"kind", "at_least", "count"}}` | n of the player's buildings (or Rootmaws) of that kind have that many workers |
| `{"group": n}` | a control group holds n |
| `{"did": "minimap" / "group_set" / "group_select"}` | the player did it since the step began (Game.note_tutorial) |
| `{"gear_view": true/false}` | the GEAR VIEW is open / shut |
| `{"placing": kind}` | the player is placing that building (or rooting that creature) |
| `{"order": {"tag", "is", "count"}}` | n tagged units have that order ("hold", "idle", ...) |
| `{"res": {"gold": n, "res2": n, "tension": n}}` | the player has that much |
| `{"talked": true}` | the dialogue box has nothing left to read |
| `{"count": {..., "mine": true, "kind": k}}` | (count gains "mine": the player's team, and "kind") |

### Actions it adds

| action | what it does |
| --- | --- |
| `{"point": {"area": a}}`, `{"point": {"tag": t}}`, `{"point": {"kind": k}}` | a gold ring and an arrow on the map (the player's first of that kind); out of view or behind the HUD: an arrow at the edge |
| `{"point": {"ui": "card" / "minimap" / "hotbar" / "top" / "objectives"}}` | a gold frame and an arrow at that part of the HUD |
| `{"point": {}}` | no pointer |
| `{"mark": true}` | the step's start (each step does it by itself) |

## Adding a step

1. Put it in the lesson's `steps` where it belongs (short lines: one thing at a time, 32 words at most a line; the
   test checks).
2. Give its `wait` a condition the player's own action makes true, and check that it is NOT true before (the test
   checks that too).
3. Add its texts to `tools/i18n/campaign/tutorial.txt` (`> English`, `pt ...`, `es ...`) and run
   `python3 tools/i18n_build.py`.
4. In `tools/test_tutorial.gd`, give the step its action in that lesson's `_play` call (what the player does, with
   the game's own calls: `g.train`, `_build` / `place_building`, `smart_command`, `BroodNew.lay`, a grub's
   `nb_morph` order...). Run the test for that lesson: `-- only=t10_crown`.
5. Adding a lesson: a mission file, its id in a group of `campaign/tutorial.json`.

## Notes

- The tests drive every lesson with real game calls at 4x speed: buildings are placed by the game's own spot finder
  and built by the workers, units trained at the buildings, eggs laid by the Mother, creatures rooted by grubs, the
  raid fought by the player's units. The practice games are checked for their computer, their first hints, the win
  (enemy wiped out) and the loss (TRY AGAIN, no tick).
- Godot 4.7 aborts at the very end of a headless test run (after the last line is printed: exit code 134); it does the
  same on main with tools/test_campaign.gd, so it is not the tutorial's.
- Open: voice for the teachers, drawn portraits (placeholders: initials), a Basics with another faction's units (the
  Clockwork's run down off their field and the Brood's need a Mother, so the Basics uses the Crown).
