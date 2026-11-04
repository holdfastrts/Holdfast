# Campaign mission 1, "The Leaf and the Fire": what was built (campaign-m1, 0.31.0)

The owner's approved script (docs/campaign_mission1.md) as a playable mission, on the campaign engine
(docs/campaign_engine.md). It replaces the placeholder p01_revolt as the PROLOGUE in campaign/campaign.json (the old
mission file stays as the engine's test bed for tools/test_campaign.gd; it is no longer in any storyline).

## Files

| what | where |
| --- | --- |
| the mission | `campaign/missions/p01_leaf.json` (written by `tools/campaign/make_m1_mission.py`: edit the script, run it) |
| the map | `campaign/maps/virginia_leaf.json`, map id `campaign:virginia_leaf` (written by `tools/campaign/make_virginia_map.py`; can be opened in the MAP EDITOR) |
| the stills | `campaign/stills/p01_01.jpg` .. `p01_06.jpg` (1280 x 853 JPEGs made from art/campaign/stills/p01_*.png, which stay in art/ and out of the game) |
| the rebels (roles, torches) | `scripts/campaign/rebels.gd` (Rebels), their sprite sets `scripts/campaign/rebel_art.gd` (RebelArt.ART) |
| the opening and ending shows | `scripts/campaign/still_show.gd` (StillShow) |
| voice lines | `scripts/campaign/campaign_voice.gd` (CampaignVoice); the list to record: `docs/campaign_mission1_voice.md` |
| texts pt / es | `tools/i18n/campaign/p01_leaf.txt` (then `python3 tools/i18n_build.py`) |
| test | `tools/test_campaign_m1.gd` (`godot --headless --fixed-fps 30 --script res://tools/test_campaign_m1.gd`) |
| balance check | `tools/sim_campaign_m1.gd` (`-- active`: a simple player bot; without it the player does nothing) |
| screenshots | `tools/shot_campaign_m1.gd` -> `docs/shots/campaign_m1/` (captions.md) |

## The mission, as built

- OPENING (before the match, from the briefing's START): the five stills full screen, the lines under them with the
  speaker's name in capitals (THE KING, TOMASZ, LORD FAIRLEIGH). Lines move on by themselves after a reading time (or the
  length of the recording), a tap / NEXT / Enter gives the next, SKIP / Esc ends it.
- PART 1, NIGHT (the scene tinted dark blue: a CanvasModulate on the world, never the HUD). The Governor's team (Crown,
  PURPLE): the manor (Town Hall), the chapel (Church), five drying barns (Farms), a Barracks, a Powder Mill (so
  Musketeers can be trained), three Cottages; 10 Musketeers, 2 Field Cannons, 4 Labourers, Lord Fairleigh (an Officer,
  named over his bar) and Tomasz (a Missionary, named); 500 gold, 150 powder. Seven waves come out of the woods at the
  field edges (0:25, 1:25, 2:30, 3:45, 5:00, 6:25, 7:20), attack-moving on the plantation; Varenne appears at 2:20 at the
  north-east edge with three pikemen, shouts, and walks off to the fort 40 s later. Lines on triggers: Varenne's slogans,
  Ruggieri's answers, Tomasz on the dead, Ruggieri and Fairleigh on the burning leaf (the smoking), a barn hit, the first
  barn lost, the manor hit, Lauds at 7:20 (the light turns to dawn over 40 s).
- DAWN (8:00): with at least three barns standing, the night's rebels fall back to the fort, 6 more Musketeers and 300
  gold / 100 powder arrive, the camps objective shows. With fewer than three: "The leaf is ash..." and the mission is lost.
  The light turns to day 90 s later.
- PART 2, THE ROAD: two camps (9 and 11 men, holding). When the first is down: Hollins Farm (a loyal Farm, yellow) with
  six families and four raiders and a torch-bearer burning it; Tomasz and Fairleigh speak and the CHOICE appears (a
  panel with two buttons; 2 minutes, then MARCH ON is taken):
  - SAVE THE FAMILIES: the optional objective "Save the families at Hollins Farm" (done when the raiders are dead and
    a family lives; the families walk to the plantation); the fort gets 6 militia + 4 pikemen more and two palisade
    pieces before its gate (dug in); at the gate Ruggieri says so. The charge breaks below 8 left.
  - MARCH ON: 40 s later the farm burns down with the families, Tomasz remembers. The charge breaks below 6 left.
  The flag `families` = `save` / `leave` is kept in the progress (Campaign.flag("p01_leaf", "families")) for a later
  mission: a condition `{"past": {"p01_leaf.families": "save"}}`.
- PART 3, THE GATE: both camps down shows "Bring the army before the fort's gate" (6 men in the area before it). There:
  Ruggieri "They are massing...", Fairleigh "Bring the guns up. Load canister.", Ruggieri's tip, and the POINTER frames
  the CANISTER button on a selected cannon's card (the command card when no cannon is selected). 22 s later Varenne's
  last speech and "Canister. On my word."; 6 s later the mass (22, or 32 dug in) charges out of the gate, with Varenne
  and the night's survivors (also at once if the player fires on the mass first). "Fire." when four of them are in the
  kill zone. The charge broken: won.
- ENDING (a Crown win): the canister still with Tomasz's and the King's lines, then the end screen.
- LOSING: the manor falls, every barn burns, or fewer than three barns at dawn.

## The Free Assembly: stand-ins, and how to swap in the real art

A campaign-only faction `free_assembly` (the mission's "factions": stand_in "crown"), colour GREEN (palette 2). Each
rebel is a Crown unit given a ROLE (`"as": "<role>"` on a unit or spawn; Rebels.ROLES):

| role | plays as | stand-in look | its own art (when drawn) |
| --- | --- | --- | --- |
| militia | Musketeer | the Musketeer in green | `assets/units/rebel_militia/` |
| torch | Labourer + a torch (burns enemy buildings he stands at: 6 a second, armour ignored; scripted ones walk to the nearest enemy building) | the Labourer in green with a flame drawn in code | `assets/units/rebel_torch/` |
| pikeman | Pikeman (below) | the old Pikeman strips in green | `assets/units/rebel_pikeman/` |
| varenne | Officer, named "Etienne Varenne" over his bar | the Officer in green | `assets/units/rebel_varenne/` |

TO SWAP IN THE OWNER'S SPRITES: cut the strips like any unit's (`<anim>_<dir>.png`, dirs s, se, e, ne, n; the west is
mirrored) into the folder in the last column, with the animation names the stand-in's unit uses (a militiaman: the
Musketeer's idle, walk, aim, fire, reload, melee, death; the torch-bearer: the Labourer's idle, walk, mine, death; the
pikeman: idle, walk, attack, death; Varenne: the Officer's idle, walk, aim, fire, melee, death), then add the art's
`cell`, `anchor` and frame counts to `RebelArt.ART` (scripts/campaign/rebel_art.gd). The role wears it from then on;
nothing in the mission changes. The team colour still swaps the two key reds of the sheet (shaders/team.gdshader): draw
the green and black of the Free Assembly as painted and keep the key reds out of the art (or draw the coats in the key
reds to have them tinted green). If the owner draws the torch-bearer with a torch in hand, take the code-drawn flame off
(Unit._draw_mission_marks).

## The Pikeman, back for the campaign only

The retired Crown Pikeman (the Musketeer's bayonet took his job) is a unit kind again, `pikeman` in Defs.UNITS with
`"campaign_only": true` and no building that trains him (no lobby, AI or command card shows him). His strips came back
from `old units obsolete for now/pikeman/units/` into `assets/units/pikeman/` (the old `thrust` strips are named
`attack`, so the unit plays "plain_attack": walk, attack, idle; `brace` came too, unused), with his icon
(`assets/icons/pikeman.png`) and voice (`assets/voice/pikeman/`). His old numbers were lost with the repository's
history (the oldest commit already had him retired), so these are NEW: 85 hp, armour 1, speed 58, reach 46 (a bayonet's
26), 13 damage every 1.5 s, double against horses and horsemen, 0.4 against buildings (a pike is little use on a wall:
in the balance runs pikemen were burning the barns), supply 1. The drawing problems the 2026-10-24 audit found in his
strips are still there (docs/animation_audit_units.md): walk_s and walk_se have 2 frames, walk_n's feet barely move, a
doubled pike shaft in walk_ne. The owner's rebel pikeman (from art/crown/pikeman.png) replaces them.

## The engine, extended (docs/campaign_engine.md has the full list)

- `opening` / `ending` (stills with lines, StillShow); `voice` (the voice folder); `light` (the start's light);
  `expansion_spots: false` (no gold expansion marks in a story mission).
- Units and spawns: `as` (a rebel role), `name` (shown over the bar).
- Actions: `choice`, `flag`, `light` (night / dusk / dawn / day, over `secs`), `build` (a building during the mission),
  `hurt` (damage to a tag). The pointer: `{"ui": "card", "icon": "<button icon>"}` frames one button of the card.
- Conditions: `flag` (this mission's), `past` (a flag a finished mission left).
- Campaign.record keeps the mission's flags; Campaign.flag reads them.

## Co-op and versus

- CO-OP: the second player commands team "guns" (blue): Ruggieri's two cannons and three Musketeers (in solo the
  Governor has the cannons). The host runs the mission: the CHOICE is the host's (the guest sees the lines; the guest's
  screen does not show the panel). The light reaches the guest ("light" camp message).
- VERSUS: the second player is the Free Assembly. The waves, Varenne, the camps and the fort's mass spawn as the rebel
  player's own units (scripted orders never touch a player's units: he leads them himself); his objective is to burn
  the manor (and, optional, every barn); his own lines (r_intro, r_dawn_v). If the host plays the rebels, the Crown's
  CHOICE is the guest's and is not shown to him: the default (MARCH ON) is taken. NOT CHECKED on two devices (as for
  the whole engine: docs/campaign_engine.md "Open"); checked here: the seats and a full offline run of each mode's start.

## Balance (tools/sim_campaign_m1.gd)

A passive player (his men only fire where they stand) loses the night at about 5 minutes. A simple bot (its foot
hunt the nearest torch-bearer, else the nearest rebel; the Barracks trains Musketeers; the cannons do nothing) ends
the night with 2 to 4 barns: a close run for a careless player, safe for one who guards the north barns and uses the
guns. See the numbers at the end of this file.

## Screenshots

`docs/shots/campaign_m1/` (captions.md): the opening's still with its line, the night defence, the choice, the
canister charge, the ending.

## Open questions for the owner

1. The rebels' art: the four roles above (militia, torch-bearer, pikeman, Varenne); a rebel banner (green and black)
   would help the camps and the fort read as theirs.
2. The hub ("The Governor's House") uses the plantation still (p01_03) and two talks (Tomasz, Fairleigh): a hub
   painting of its own?
3. The CHOICE's wording and effect (10 more rebels and two palisade pieces when you save the families): enough of a
   cost? Should saving them give something back later (the families' sons in a later mission)?
4. Difficulty: the night is tuned for a careful player (see Balance). Easier: fewer torch-bearers, or "two barns".
5. The Pikeman's numbers are new (the old ones were lost): confirm or change.
6. The night tint: the CanvasModulate also darkens the fog's black; on a phone the night may be too dark (try it).
7. Voice: the King's lines (k_*) are the owner's ElevenLabs recordings; the others too, or text only?

### The balance runs (0.31.0, after the tuning: torch 6 a second, pikemen 0.4 against buildings, 10 Musketeers)

`godot --headless --fixed-fps 30 --script res://tools/sim_campaign_m1.gd -- active`, three runs: dawn with 3, 3 and 3
barns standing (two barns burned in each, by militia musket fire in the big wave at 5:00-6:35), the manor untouched,
19 to 29 Crown men left. Before the tuning (torch 11 a second, 8 Musketeers) the same bot lost one run in three and a
passive player lost the night at about 5 minutes.
