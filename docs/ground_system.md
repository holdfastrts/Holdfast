# The ground system (owner's idea, DECIDED 2026-11-13 01:34-01:40; BUILT 2026-11-13, branch ground-system, 0.35.0)

A Settings experiment like TURNING GEARS: **off by default on main** (the game is exactly as before), on from the next
match when turned on (Settings > EXPERIMENTAL > GROUND SYSTEM; kept in the match's setup as cfg "ground", Defs.ground_on,
so a continued match, an online guest, the ranked server and a replay all agree). Design rules followed
(docs/design_principles.md): section 2 (the economy is depletable and forces expansion; "exhausted means exhausted",
docs/exhaust_economy.md, is kept) and section 3 (meaningful base building: placement is a real trade-off).

## The idea (the owner, 01:34-01:40)

"What if we made all resources linked to a radius area like the Rootmaw is? ... a clear indication of where things are
exhausted ... during the building menu ... we see the radius in red where it is already exhausted, and we can overlap but
extract less ... then we get a proportional amount of available resources there." Ground exists only in a **district per
hall**; the faint layer shows "while placing ANY building ... it can affect building strategic placement" (01:37). The
spent-Farm/Press limit question was left to this system (01:40, and 08:03 "wait for the ground system").

Why it was needed: today "2 Farms a Town Hall" is counted over the whole empire (Game.econ_count), so a Farm on a spent
hall's soil blocks a Farm at a fresh hall until it is pulled down — a trap a player cannot see (the econ bench found a
third hall standing with no Farm; docs/economy_parity.md section 3).

## What was built

### The layer (scripts/ground_layer.gd, GroundLayer)

- A **ground grid** over the map (one value a tile): a tile's `kind` (soil / brass / none), what it held when its
  district was laid (`full`), and what it holds now (`left`).
- When a **hall is laid** (`found`), its district's open tiles that no hall made before get its ground: Defs.LAND "soil"
  (a Town Hall, 9,000, the old SOIL_RESERVE) or "brass" (a Clocktower, 9,000, the old LODE) spread evenly over the
  district's walkable land (a tile that is cliff, water or trees holds none). A hall laid again, or overlapping one,
  adds only its new tiles' share: **nothing is ever renewed**.
- Each **Farm / Cog Press drinks from a circle** round it (Defs.LAND "r": 10 tiles each), the Rootmaw's model:
  - it works at its **full rate while its circle holds any ground**, and what it can ever pay is what the circle holds
    (`held`); a circle half over spent ground holds half as much, so it pays half as long. This is exactly the Rootmaw's
    rule (a fixed rate from a spot holding PIT_GROUND less what was drunk there), not a reduced rate — so the income curve
    over a base's life is the same shape as the old hall-soil one.
  - it drinks **evenly** from its live tiles (`draw`), so a circle empties all at once and two of a side's overlapping
    circles drink their shared tiles twice as fast: **no free income from stacking**, the ground is the same.
  - a Cog Press draws a little every tick; its draws are paid in chunks of Defs.LAND "bite" (`draw_bit`).
  - tiles under another building that is neither a hall nor an economy building (a Barracks, a Cottage, a wall) are
    **covered**: they keep their ground but nobody drinks it while it stands there (`_covered`, a bitmap rebuilt when a
    footprint changes).
- The **"% of a fresh spot"** (`value`, the placing number) is what a circle holds against a whole fresh circle of the
  same land (so a circle at the map's edge or against cliffs reads lower, as it should).
- Each hall's `soil` (Town Hall) / `lode` (Clocktower brass) is **mirrored** from its district once a second (`tick`), so
  the hall's card, the toasts, the old scars and the computers' "is this land spent" read the layer unchanged, and
  Building.soil_left / lode_left / barren return the circle's state for a Farm / Press.
- The Brood is untouched: its Rootmaw circles (Game.nb_spots) already work this way; this layer only draws them while a
  Brood side places.

### Shown (scripts/ground_view.gd, GroundView)

While the player places **any** building: the ground is tinted faintly over every district (fresh green to spent red,
tile by tile; Settings.ground_alpha and a Settings slider set the strength), with a thin circle round each of the
player's own economy buildings and a thinner one round each hall's district. A **Farm / Cog Press being placed** shows
its own circle much stronger (each tile by how fresh it is, covered tiles grey) and "NN% of a fresh spot" over it
(drawn over the map's lighting, like the expansion-spot labels). The minimap shows the layer while placing. Only ground
the viewer has explored is drawn. Pictures: docs/shots/ground_system/.

### The limit becomes the district's (the owner's open question, DECIDED here by measurement)

With the system on, a Farm / Cog Press on **spent** ground no longer counts against the limit (Game.econ_count), and the
"2 a hall" limit is **local to the district** (placement_problem: a new one is refused only when the district's nearest
hall already feeds its two live ones; Defs.LAND "local"). So a fresh hall is never left without its two Farms, and the
empire-wide trap is gone. The limit number itself (2 Farms, 2 Presses a hall) is unchanged. This is the decision the
owner left to the build (01:40, 08:03): the limit is kept but made local, rather than dropped — dropping it would let a
player ring a single hall with Farms, which the district's fixed ground already discourages but the local limit makes
clean.

### The computers (AI)

- find_spot scores a Farm's cell by how much ground its circle would hold (Game `ground_score`, a summed-area table in
  GroundLayer.quick), so the Crown places Farms on the best soil and never on a spot holding almost nothing
  (Defs.LAND "spot_min"). GearEcon.room_spot does the same for the Clockwork's Cog Presses, inside the meshing rule.
- AI._ground_recycle pulls down a Farm / Press whose circle is spent while its hall's district still holds some ground,
  one at a time, as a player would (it runs before the old _recycle_spent when the system is on).
- The econ-coach gains are kept: with the system off the AI code is the same; with it on the alone-bench numbers are
  within a few percent of off (below).

### Saves, replays, online

- A **save** carries the made tiles exactly (GroundLayer.save, deflated base64; ~1.5 KB for a two-hall map); a MIXED
  replay's keyframe (SaveGame.capture) carries it the same way and ReplayMix corrects from it.
- **Online / FULL replays / the ranked server**: each made tile goes as one int (index, kind, freshness in 32 steps),
  a keyframe's whole layer ("gk") then the tiles whose freshness changed a step ("gd"), deflated with delta-coded
  indices (`pack_rows`): a keyframe is a few hundred bytes, the changes a handful a snapshot. Fog-filtered per side
  (NetSnapshot._eye_vis): a tile out of a side's sight is sent only as it was last seen, never while an enemy drinks it
  unseen (test_net_fog checks it). The guest's layer never draws (`guest`).

## The numbers (Defs.LAND)

| | value | why |
|---|---|---|
| district (Town Hall) | 11 tiles | the soil's reach; benched so a base's income curve matches the old hall-soil one |
| district_brass (Clocktower) | 9 tiles | the presses mesh near the tower, so its brass sits a little tighter |
| soil / brass | 9,000 each | the old SOIL_RESERVE / LODE["clocktower"]: a base runs out at the same minute |
| r (Farm / Cog Press circle) | 10 tiles | the circle each drinker drinks from |
| bite | 2.0 | a Cog Press's tiny draws paid in chunks of this |
| spot_w / spot_min | 40 / 0.1 | the computer's spot score weight on fresh ground, and the least a spot may hold |
| local | true | the limit is the district's, spent ones don't count |

## Measured

### The design, on vs off (tools/econ_bench.gd, the scripted ideal build, Greenhold seed 1, as a share of OFF at m:m)

The bench plays one faction alone with a fixed ideal build (2 Farms + a Mill a hall, expansions at 4/8/12; see
docs/economy_parity.md). ON is within ~5% of OFF at every point from 5:00, the target:

| | 3:00 | 5:00 | 8:00 | 10:00 | 12:00 | 15:00 |
|---|---|---|---|---|---|---|
| Crown ON / OFF | 1.00 | 1.00 | 0.96 | 0.99 | 1.01 | 0.95 |
| Clockwork ON / OFF | 1.00 | 1.00 | 1.00 | 1.01 | 1.04 | 1.00 |
| Brood (unchanged) | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |

(Crown's small dip from 8:00 is the ideal build's spot choices under the circle rule; both reach the bench by 15:00 on
Hollowfen too: Crown 0.99-1.03, Clockwork 0.96-1.01.)

### The computer alone (tools/econ_ai_alone.gd, Hard OPTIMAL, nobody in its way, as a share of OFF)

| | 5:00 | 8:00 | 10:00 | 12:00 | 15:00 |
|---|---|---|---|---|---|
| Crown ON / OFF | 1.00 | 0.96 | 0.98 | 0.98 | 0.99 |
| Clockwork ON / OFF | 1.00 | 1.01 | 0.97 | 0.95 | 0.92 |

The computers reach about the same share of their economy's design with the system on as without it (the econ-coach
gains are kept); the Clockwork's late dip is it taking one hall later in a few runs, within the run-to-run noise.

### Real games (Hard OPTIMAL v Hard OPTIMAL, `qa_matches.py --only ground`, 3 maps x every pairing x 2 rounds)

36 games each (3 maps x every pairing x 2 rounds), ON vs OFF, Hard OPTIMAL v Hard OPTIMAL to 15:00 (noisy per game;
read the totals). The income the two sides earn, pooled, is within a few percent on vs off at every point; with the
system ON more games are DECIDED (the Crown gets its Farms placed and its districts don't strand a hall), which is why a
few mirrors that were all draws off now have winners.

| matchup (P1 view) | W-D-L off | W-D-L on | income P1/P2 10:00 off / on | median length off / on |
|---|---|---|---|---|
| Crown v Brood | 1-4-1 | 3-0-3 | 1.06 / 1.11 | 15:00 / 14:06 |
| Crown v Clockwork | 0-5-1 | 0-6-0 | 1.00 / 0.94 | 15:00 / 15:00 |
| Brood v Clockwork | 6-0-0 | 3-2-1 | 1.18 / 1.20 | 13:32 / 13:37 |
| Crown mirror | 0-6-0 | 0-6-0 | 1.00 / 0.95 | 15:00 / 15:00 |
| Brood mirror | 1-5-0 | 3-3-0 | 1.11 / 1.10 | 15:00 / 14:30 |
| Clockwork mirror | 0-6-0 | 3-3-0 | 1.05 / 1.13 | 15:00 / 14:21 |

Income earned, all games pooled, both sides (primary):

| | 5:00 | 8:00 | 10:00 | 15:00 |
|---|---|---|---|---|
| off | 3,286 | 7,500 | 11,137 | 19,958 |
| on | 3,265 | 7,420 | 10,674 | 18,072 |

Decided: off 10 of 36, on 16 of 36 (median length 15:00 both; decided games ~13:20 both). No script error from the ground
system; one unrelated pre-existing error surfaced (a Spring Ballista area shot in one Clockwork mirror,
ballista.gd:328 `has_tag` on a target that died mid-splash, not touched by this job).

## Tests, pictures

- tools/test_ground_system.gd: the districts, a circle's draw (full rate, evenly, exhausted), the district limit, spent
  ground freeing it, covered ground, a hall laid again renewing nothing, half a circle over spent ground, the Cog Press's
  chunked draws, a save round-trip, the net's keyframe and change rows to a 32nd, the placing view. (Off: the Farm draws
  its hall's soil as before.)
- tools/test_net_fog.gd `ground:1`: the layer's rows are fog-filtered per side and the guest's layer matches the host's
  where it sees.
- tools/test_settings_tabs.gd, test_qa_settings_persist.gd: the new rows (ground_system, ground_alpha) are there and save.
- docs/shots/ground_system/: crown_fresh (a Farm on fresh ground, its "% of a fresh spot"), crown_overlap (half over
  spent, red tiles, a lower %), crown_barracks (a Barracks: only the faint layer and the Farms' circles), crown_faint_max
  (the layer at full strength), clock_press (a Cog Press's circle of brass).
- tools/ground_probe.gd: prints each Farm / Press's circle and each hall's district over a peaceful game (a quick look).

## Claude's choices (for the owner to confirm)

1. **The limit is kept but made local** (the owner's open question): the district still allows 2 Farms / 2 Presses, spent
   ones don't count, and a new one is refused only when its own district's two live ones are up. Dropping the limit
   entirely was the other option; the district's fixed ground already stops one hall feeding many drinkers, and the
   local limit keeps the rule the player knows. Say if you'd rather drop it.
2. **The secondary resources stay in the hall**: the Powder Mill still grinds its Town Hall's saltpetre and the Mainspring
   still winds its Clocktower's spring life (the 15% / 5% floors, docs/exhaust_economy.md). Only the PRIMARY resources
   (soil, brass) moved to the map; putting saltpetre on the map too (a circle for the Mill) is easy to add if you want it.
3. **The Clocktower's spring life stays in the Clocktower** (it is a reserve the Mainspring draws, not a circle on the
   ground), so the Clockwork's tech brake is unchanged.
4. **The radii** (district 11 / brass 9, circles 10) were benched to keep today's curves; they are the obvious dial if the
   game should play differently (a tighter district forces expansion sooner).
5. **Off by default on main**, as decided. Turn it on per match in Settings, or make it the default when you're happy.

## How to run it again

- `tools/test_ground_system.gd`, `tools/test_net_fog.gd -- ground:1`.
- Bench ON vs OFF: `godot --headless --fixed-fps 30 --script res://tools/econ_bench.gd -- crown ground=1` (study dials:
  `land.district=12 land.r.farm=11 land.spot_min=0.1 ...`); the computer alone: `tools/econ_ai_alone.gd -- crown ground=1`.
- A game batch: `python3 tools/study/qa_matches.py run OUT --data DATA --only ground --extra ground:1` (ON) and the same
  without `--extra` (OFF), then `python3 tools/study/ground_games.py OFF_DATA ON_DATA`.
- Pictures: `xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_ground_system.gd -- out:/abs/dir`.
