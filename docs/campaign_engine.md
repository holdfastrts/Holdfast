# The campaign engine (0.30.0)

The owner's brief (2026-11-03): a campaign that two friends can play together, CO-OP (same side) and VERSUS (each one
side of the same mission; the story follows who won), and SOLO against the computer. Cutscenes are STILL SHOTS with
text, not movies. Dialogue in period words ("zounds", "knave", "by my troth"). Story (owner, later the same day): the
year 2500, technology fallen back to the 17th/18th century (background only); the FIRST MISSION is a quick revolt the
Crown puts down; then the campaign splits into storylines with their own heroes (a Catholic explorer who finds the
Brood; a clockmaker horrified by his Clockwork...). Between missions a HUB per storyline (like StarCraft II's ship):
a scene with hotspots: a war table for the missions, people to talk to, rooms (an armoury, undecided). A fourth,
campaign-only faction (human tribes, design pending) must fit the format later.

This job built the ENGINE and ONE TEST MISSION. The test text is a placeholder; the real story is being written.

## Files

| what | where |
| --- | --- |
| storylines, hubs, rooms | `campaign/campaign.json` |
| missions | `campaign/missions/<id>.json` |
| mission maps (the map editor's format) | `campaign/maps/<name>.json`, map id `campaign:<name>` |
| stills, portraits (when drawn) | e.g. `campaign/stills/<id>.png` (any res:// path a still's `image` names) |
| translations of the campaign's texts | `tools/i18n/campaign/campaign.txt`, `tools/i18n/campaign/<mission>.txt` |
| translations of the pages' own words | `tools/i18n/50_campaign.txt` |
| data, progress, checks | `scripts/campaign/campaign.gd` (Campaign) |
| the running mission | `scripts/campaign/mission_run.gd` (MissionRun, `game.mission`) |
| dialogue box, objectives panel | `scripts/campaign/mission_ui.gd` (MissionUi) |
| hub, war table, briefing, end screen | `scripts/campaign/campaign_menu.gd` (CampaignMenu) |
| placeholder stills and portraits | `scripts/campaign/still_view.gd` (StillView, StillView.Portrait) |
| the test map's generator | `tools/campaign/make_ford_map.py` |
| test | `tools/test_campaign.gd` (`godot --headless --fixed-fps 30 --script res://tools/test_campaign.gd`) |
| screenshots | `tools/shot_campaign.gd` -> `docs/shots/campaign_engine/` |

`campaign/` is exported with the game (`include_filter="campaign/*"` in the Web, Android, Windows and Linux presets:
JSON files are not resources and are left out otherwise). Progress is kept in `user://campaign.json`.

## How the campaign hangs together (campaign.json)

```json
{"title": "THE CAMPAIGN",
 "storylines": [
   {"id": "prologue", "title": "Prologue: The Revolt", "about": "...", "missions": ["p01_revolt"],
    "hub": {"title": "The Crown's Camp", "still": {"caption": "..."}, "colour": 1,
      "hotspots": [
        {"id": "war_table", "kind": "war_table", "label": "WAR TABLE", "rect": [0.08, 0.30, 0.30, 0.34]},
        {"id": "captain", "kind": "talk", "label": "CAPTAIN HALE", "talk": "captain", "rect": [0.68, 0.34, 0.18, 0.42]},
        {"id": "armoury", "kind": "room", "label": "ARMOURY", "room": "armoury", "rect": [0.84, 0.08, 0.14, 0.24]}],
      "talks": {"captain": {"name": "Captain Hale", "colour": 1, "entries": [
        {"after": "", "lines": ["...", "..."]},
        {"after": "p01_revolt", "lines": ["..."]}]}}}},
   {"id": "explorer", "title": "The Explorer", "requires": "p01_revolt", "missions": [], "hub": {...}}],
 "rooms": {"armoury": {"title": "ARMOURY", "text": "..."}}}
```

- A STORYLINE is open when its `requires` mission has been finished (none: open from the start). Its first mission is
  playable when the storyline is open; the next ones when a finished mission leads to them (`next`).
- The HUB: the still fills the scene, each hotspot is a box at `rect` (fractions of the still: x, y, w, h; never
  smaller than a thumb on a phone). The same hotspots are listed beside the scene. Kinds: `war_table` (the
  storyline's missions), `talk` (a person: the talk's `entries`, the one for the latest finished mission it names is
  said), `room` (a page from `rooms`: the ARMOURY is a stub until the owner decides on upgrades between missions).
  The tabs at the top switch storylines; locked ones show what opens them.

## A mission (campaign/missions/p01_revolt.json, shortened)

```json
{"id": "p01_revolt", "title": "The Revolt at the Ford", "summary": "...",
 "map": "campaign:ford_village",
 "modes": ["solo", "coop", "versus"],
 "sides": [{"id": "crown", "name": "The Crown"}, {"id": "rebels", "name": "The Rebels"}],
 "teams": [
   {"id": "column", "side": "crown", "faction": "crown", "colour": 1, "start": "none", "camera": "camp", "gold": 150,
    "control": {"solo": "p1", "coop": "p1", "versus": "p1"}},
   {"id": "horse", "side": "crown", "faction": "crown", "colour": 3, "start": "none",
    "control": {"solo": "script", "coop": "p2", "versus": "script"}},
   {"id": "rebels", "side": "rebels", "faction": "crown", "colour": 0, "start": "standard", "hall": [14, 28],
    "hall_tag": "rebel_hall", "control": {"solo": "script", "coop": "script", "versus": "p2"}}],
 "areas": {"ford": [52, 27, 14, 10], "village": [10, 22, 26, 18]},
 "units": [{"team": "column", "kind": "dismounted", "count": 1, "at": "camp", "tag": "captain"},
           {"team": "rebels", "kind": "musketeer", "count": 4, "at": "village", "tag": "militia", "order": "hold"}],
 "buildings": [{"team": "rebels", "kind": "barracks", "at": "village"}],
 "wiped_out": {"crown": 0, "rebels": 0},
 "objectives": [
   {"id": "burn", "side": "crown", "primary": true, "kind": "destroy", "tag": "rebel_hall", "text": "Burn the rebels' Town Hall."},
   {"id": "captain", "side": "crown", "primary": true, "kind": "protect", "tag": "captain", "text": "Captain Hale must live."},
   {"id": "hold", "side": "rebels", "primary": true, "kind": "survive", "time": 480, "text": "..."}],
 "triggers": [
   {"id": "intro", "when": {"time": 1}, "do": [{"say": ["i1", "i2"]}]},
   {"id": "militia_go", "when": {"fired": "at_ford"}, "delay": 10, "do": [{"order": {"tag": "militia", "do": "attack", "to": "ford_west"}}]},
   {"id": "horse", "when": {"time": 120}, "do": [
      {"spawn": {"team": "horse", "kind": "cuirassier", "count": 4, "at": "east_road", "tag": "relief"}},
      {"order": {"tag": "relief", "do": "attack", "to": "ford_west"}}]}],
 "speakers": {"captain": {"name": "Captain Hale", "side": "crown"}},
 "lines": {"i1": {"who": "captain", "text": "Zounds, Sergeant..."}, "tip1": {"who": "sergeant", "to": "crown", "text": "..."}},
 "stills": {"muster": {"caption": "The Crown's column musters on the east bank at dawn..."}},
 "briefing": {"crown": {"still": "muster", "text": ["...", "..."]}, "rebels": {...}},
 "debrief": {"crown": {"still": "hall_burns", "title": "The revolt is crushed", "text": "..."}, "rebels": {...}},
 "next": {"crown": "", "rebels": ""}}
```

### The parts

- `map`: `campaign:<name>` (a map editor map in `campaign/maps/`) or a built-in map id. Cells are given as [x, y].
- `sides`: the story's sides (two for now: the end logic gives the win to "the other side"). Teams on one side are
  allies.
- `teams`: one per player slot, in order. `faction` (crown / brood / clockwork, or a campaign-only one, below);
  `colour` (palette index: Blue 0, Red 1, Green 2, Yellow 3, Purple 4, Orange 5, Teal 6, Pink 7); `start`:
  `standard` (the normal hall, economy building and workers, at `hall` if given) or `none` (only what the mission
  gives); `hall_tag` tags the standard hall; `gold`, `powder`; `camera`: the area the view starts on.
  `control` per mode: `p1` (you in solo, the host online), `p2` (the friend online; offline it falls back to a
  scripted team), `script` (no computer player: the triggers move it), `ai:<level>:<plan>` (the normal computer
  player, e.g. `ai:hard:balanced`, through the AI's usual interface: Main.start makes it like a skirmish's).
- `areas`: named rectangles [x, y, w, h] in cells.
- `units`, `buildings`: `team`, `kind` (Defs.UNITS / Defs.BUILDINGS keys), `count`, `at` (an area: units spread over
  its free cells, a building takes the free spot nearest its middle; or [x, y]), `tag`, `order` (`"hold"` or an order
  as below), `modes` (only in these modes).
- `wiped_out`: {side: seconds}: after that time a side with no units and no buildings left (having had some) loses.
- `objectives`: `id`, `side`, `primary` (true: decides the mission; false: optional), `text`, `hidden` (until a
  trigger shows it), `kind`:
  - `survive` (`time` in seconds: done then; the panel counts down),
  - `destroy` (`tag`: done when everything with the tag is dead),
  - `protect` (`tag`: failed when everything with the tag is dead; counts as met while it holds),
  - `reach` (`area`, `count`, and `tag`, `team` or `side_units`: done when that many stand in the area),
  - `manual` (only triggers set it).
  The END: a side whose primary objective fails loses (the other side wins); a side with all its visible primaries
  met (at least one done, not only protects) wins. In versus both sides have their own objectives.
- `triggers`: `id`, `when` (a condition), `do` (actions, in order), `delay` (seconds after the condition first held),
  `modes`. Each fires once.
- `speakers`: `name`, `side` (its colour), `portrait` (a picture; none: initials). `lines`: `who`, `text`, `to` (only
  that side sees it: versus), `still` (a still shown in the dialogue box).
- `stills`: `caption`, `image` (optional picture; none: the placeholder). `briefing` and `debrief` per side.
- `next`: {winning side: mission id} or one id (the story's branch by who won; "" = not written yet / the story goes
  on in the storylines this mission opens). Without `next`: the next mission of the same storyline.
- `factions` (optional): CAMPAIGN-ONLY FACTIONS. `{"tribes": {"name": "...", "stand_in": "crown", "campaign_only": true}}`
  lets a team say `"faction": "tribes"`. Such a faction never shows in the skirmish or online lobbies (they list only
  the playable factions, Main.FACS / NetLobby.FACTIONS). Until it exists in the game (Defs.FACTIONS, to be marked
  `"campaign_only": true` and kept out of any list built from Defs.FACTIONS), the match plays its `stand_in`. Nothing of
  the tribes is built yet.

### Conditions (`when`; several keys in one dictionary must all hold)

| key | true when |
| --- | --- |
| `{"time": s}` | the match clock has reached s seconds |
| `{"dead": tag}` | everything with the tag is dead (something had it) |
| `{"hurt": tag}` | anything with the tag has lost health (or died) |
| `{"count": {"tag" or "team" or "side": X, "area": a, "at_least": n, "below": n, "buildings": true}}` | living units (horses not counted; buildings too with `buildings`) |
| `{"done": objective}`, `{"failed": objective}` | that objective's state |
| `{"fired": trigger}` | that trigger has fired |
| `{"all": [...]}`, `{"any": [...]}`, `{"not": {...}}` | combinations |

### Actions (`do`; each one `{name: value}`)

| action | what it does |
| --- | --- |
| `{"say": [line ids]}` | the lines, one after another in the dialogue box (and the match log) |
| `{"spawn": {"team", "kind", "count", "at", "tag", "order"}}` | new units (for a person's team they are simply theirs) |
| `{"order": {"tag" or "team", "do": "attack"/"move"/"hold"/"stop"/"patrol", "to": area}}` | scripted orders; never to a team a person plays |
| `{"objective": {"id", "set": "active"/"hidden"/"done"/"failed"}}` | show or settle an objective |
| `{"reveal": {"area", "side", "secs"}}` | that side sees the area for a while |
| `{"ping": {"area"}}` | a ping on the map |
| `{"camera": {"area", "side"}}` | moves that side's view |
| `{"give": {"team", "gold", "powder"}}` | resources |
| `{"win": side}`, `{"lose": side}` | ends the mission |

`Campaign.problems(mission)` checks all of it (unknown names, kinds, areas, lines, conditions, actions);
tools/test_campaign.gd runs it on every mission.

## How to write a mission

1. Draw the map in the MAP EDITOR, save it, copy `<user folder>/maps/<name>.json` to `campaign/maps/` (the mission
   refers to it as `campaign:<name>`). The map's start spots only matter for `standard` teams without a `hall`.
2. Copy a mission file, set the sides, teams (who plays them in each mode), areas, units, objectives and triggers.
3. Put the mission's id in a storyline's `missions` in `campaign/campaign.json`.
4. Translations: add a `tools/i18n/campaign/<id>.txt` with a block per text (`> English`, `pt ...`, `es ...`), run
   `python3 tools/i18n_build.py`. Every text is its own English key, so a text used twice is translated once.
5. Run `tools/test_campaign.gd` (data checks and translations), then play it from CAMPAIGN.

## In the game

- The DIALOGUE BOX (top right, under the top bar): portrait, name in the side's colour, the line; a still above it
  when the line has one. Lines follow each other by themselves (about 4.5 s, longer for long lines); NEXT and SKIP.
  Nothing is paused, alone or online (a paused solo match holds the line's timer).
- The OBJECTIVES panel (top left, under the resources): primary first as written, `(optional)` ones dimmer; ticked
  when done, crossed when failed, the time left on a survive objective. Its title folds it.
- The END screen: VICTORY / DEFEAT (versus: "<side> WIN"), the winners' still and words, the objectives as they
  ended, where the story goes (the next mission, or the storylines it opens, or "being written"), and NEXT MISSION
  (solo), PLAY AGAIN, BATTLE REPORT (the usual report), CAMPAIGN.
- Progress (`user://campaign.json`): a mission counts when your side won it, or in versus whoever won (the story
  follows the winner on both machines).
- A campaign mission is not autosaved (no CONTINUE): its trigger and objective state is not in the save format yet.

## Co-op and versus (online)

On the war table pick CO-OP or VERSUS (versus: which side you play), then OPEN AN ONLINE ROOM: a room is hosted
(NetLobby.set_campaign) and the ONLINE page shows the campaign room (the mission, who plays which side, START). The
friend joins with the code from ONLINE as usual. The host's game runs the mission (triggers, scripted orders, the
end); the guest's MissionRun only shows what the host sends ("camp" messages through NetSession: lines, objectives,
reveals, pings, camera) and learns the end from the snapshot like any online match. Lines with `to` are shown only to
that side.

What is done and checked: the room's slots and the setups for both machines (tools/test_campaign.gd checks the host's
and the guest's setup and a guest MissionRun fed the host's messages, without a network).
NOT CHECKED: a real two-machine run through the relay (the job's rule was one Godot process at a time; tools/test_online.sh
needs two). That is the first thing to try: host a CO-OP room from CAMPAIGN on one device, join from the other.

## Two Crown sides

The two Crown sides wear their team colours (the Crown column red, the rebels blue in the test mission: the coats
take the colour, docs/shots/campaign_engine/7_mission_dialogue.jpg). That reads well; no art was redrawn. Colours that
are close (red and orange, blue and teal) would be hard to tell apart: pick distant ones.

## Open

- Real online test (above). Online, a friend who leaves is replaced by the normal computer player (as in a skirmish), which may not fit a scripted mission.
- Saving a mission halfway (CONTINUE).
- The story itself, the stills and portraits (art not decided: placeholders drawn in code, docs/art_style_inconsistency.md),
  the hub scenes' art and the ARMOURY's upgrades (stub).
- The campaign-only faction (format ready, faction not built).
- More than two sides in one mission (the end logic hands a loss to "the other side").
- Voice lines for the dialogue (text only).
- Hotspots on the hub are boxes over the placeholder; with real art they would become invisible areas with a glow.

## The TUTORIAL (0.30.0)

The TUTORIAL button's lessons run on this engine: missions with "tutorial": true and "steps" (written out by
Campaign.expand_steps), listed in campaign/tutorial.json and never in the storylines. They add conditions on what the
player did (selected, camera_moved, built, rooted, crew, did...) and the `point` action. See docs/tutorial.md.
