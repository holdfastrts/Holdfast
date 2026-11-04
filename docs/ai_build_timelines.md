# AI build timelines (the computer's opening, per faction and plan)

Anchor: the owner's hand-played Brood extreme rush (docs/design_principles.md section 5): Spawning
Den done 1:01, first Raptors 1:13, 8 Raptors (200 value) by about 2:00, first hit 2:00-2:30. Every plan is
calibrated against it under the current (halved) economy. Numbers below are measured, not hoped for.

## How the numbers were made

`tools/run_ai_timelines.sh [map] [seed]` runs `tools/measure_ai_timelines.gd` for every faction and plan
(Hard AI, Ashford Crossing, seed 4242) against a Hard Crown on Balanced that defends but never attacks
(`peaceful`), so each row is the plan's own build, not a fight it was dragged into. Columns: first
military production building done, first soldier, first attack leaving, then workers / army value
(cost of the armed units alive; Raptors count 25 each) at 2:00, 3:00, 4:00, 5:00. "never" means no
attack by 7:00 (a Timing Attack waits while the foe it has seen is stronger; Balanced pushes later).
Runs vary a little from game to game (random choices): read the numbers to +-20 s and +-1 unit.

| Faction | Plan | Production building | First soldier | First attack | 2:00 | 3:00 | 4:00 | 5:00 |
|---|---|---|---|---|---|---|---|---|
| Crown | Rush (Horsemen) | Barracks 1:19 | 2:06 | 3:52 | 8 / 0 | 7 / 115 | 11 / 345 | 13 / 115 |
| Crown | Balanced | Barracks 1:20 | 1:55 | never (6:00+) | 9 / 75 | 9 / 115 | 10 / 230 | 12 / 115 |
| Crown | Economy | Barracks 1:20 | 1:55 | never | 9 / 115 | 11 / 115 | 13 / 230 | 17 / 230 |
| Crown | Timing attack | Barracks 1:20 | 2:47 | never (waits for a weaker foe) | 10 / 0 | 12 / 115 | 13 / 115 | 16 / 345 |
| Clockwork | Rush | Assembly Works 2:17 | 2:30 | 2:44 | 9 / 0 | 12 / 225 | 15 / 525 | 15 / 730 |
| Clockwork | Balanced | Assembly Works 2:20 | 2:34 | 5:06 | 8 / 0 | 10 / 150 | 15 / 675 | 17 / 1655 |
| Clockwork | Economy | Assembly Works 2:16 | 2:30 | 5:11 | 8 / 0 | 11 / 225 | 16 / 700 | 20 / 1615 |
| Clockwork | Timing attack | Assembly Works 2:16 | 2:30 | 5:07 | 8 / 0 | 11 / 225 | 16 / 600 | 20 / 1525 |

(The Crown's and the Clockwork's own opening logic was only touched where noted below.)

## What each plan is for, and how it is built

### Brood (the Brood of creatures, 0.27.3: scripts/ai_brood_new.gd, docs/brood_ai.md, docs/brood_eco.md, docs/brood_ai_tune.md)
The old Brood's rows (Spawning Den openings) are gone with it (0.18.0). Today's Brood has no buildings: its Tyrant Sire
on his nest is its barracks, made from a grub's lure (150 food, 30 s since 0.22.2). Measured by
`tools/test_ai_brood.gd -- profile:<p>` (Hard Brood against a peaceful Hard Crown on Greenhold, seed 3; 0.22.5): the
times each milestone came. Since 0.22.9 every profile but the rushes plays the owner's economic build (docs/brood_eco.md):
the natural first, the third Rootmaw at its far edge, grubs first, the Sires and her stage 2 later on purpose.

| Plan | Scout (watch) | Natural turtle | 3rd Rootmaw | Tyrant Sire | 8 Raptors | Stage 2 | Venom Sire | Storm Sire | Stage 3 | First research | First attack | Food by 6:00 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Extreme rush | after the rush | 3:15 | 4:01 | 0:31 | 1:43 | 8:20 | 8:01 | - | 9:38 | 8:20 | 1:55 | 1,974 |
| Rush | 1:10 | 0:33 | 3:44 | 1:44 | 2:48 | 8:03 | 7:43 | - | 9:23 | 8:02 | 3:03 | 2,406 |
| Timing attack | 1:10 | 0:33 | 2:02 | 2:33 | 5:04 | 6:42 | 6:36 | 8:14 | 8:56 | 4:55 | 6:04 | 5,171 |
| Balanced | 1:10 | 0:33 | 1:58 | 2:51 | 5:26 | 5:11 | 6:12 | 8:50 | 8:53 | 6:08 | 7:20 | 4,860 |
| Economy | 1:10 | 0:33 | 1:49 | 3:12 | 5:23 | 5:15 | 6:19 | - | 7:05 | 6:13 | 7:56 | 5,730 |
| Air rush | 1:10 | 0:33 | 1:58 | 2:34 | 5:53 | 5:04 | 6:39 | 5:45 | 8:43 | 5:46 | 7:00 | 4,587 |

(0.27.3, brood-ai-tune, docs/brood_ai_tune.md: measured with tools/measure_brood_ai.gd against a peaceful Hard Crown on
Greenhold seed 3. Today's economy is about twice 0.22.5's; her stages and the later Sires now come as soon as her eggs
run short, the rushes turn Balanced once their first wave is home. The 0.22.5 row for comparison: the natural at 1:07,
her stage 2 at 8:38 to 8:57, the Venom Sire at 8:07 to 8:25, food by 6:00 2,000 to 2,600.)
(0.22.0, for comparison: the Tyrant Sire at 1:36 to 2:23, her stage 2 at 5:00 to 7:22, a far turtle at 4:56 to
6:12, no watching grub; the Extreme rush's 8 Raptors at 2:40.)

- **Extreme rush**: the Tyrant Sire's lure at once, 6 grubs, one Rootmaw, a supply turtle right after him, every egg
  Raptors; the 8 go together. The owner's yardstick (8 Raptors by 2:00, hitting 2:00-2:30) is MET on today's economy
  (0.27.3): 8 Raptors at 1:43, the wave leaves at 1:55. Against the Hard Crown it fails (the ramp wall stands at 0:38)
  and against the Hard Clockwork it meets its first Clock Soldiers; once its first wave is home it plays Balanced.
- **Rush**: 9 grubs held until 10 Raptors leave (about 3:00), then Balanced's economy (called off if its scout saw an
  army twice its own).
- **Timing attack / Balanced / Economy / Air rush**: grubs first on a curve (6 to 8 a minute), her stages, the later
  Sires and the turtles on new ground as soon as her eggs run short (the plan's clock as the latest time), Pack Hunt before the first wave (except against the Clockwork, which gets smaller
  waves from 5:00). Against the Crown no wave goes into its wall with claws alone (Spitters or Brutes with Battering
  Horns first, or the supply cap), so its first attack against a walled Crown comes late or at the cap.
- Its scouting decides: an army on the move early means hold and lay warriors; enemy flyers mean the Storm Sire first.

### Crown
- Since 0.29.0 the Crown has its own computer (scripts/ai_crown.gd) with a real build order per plan, triggered by
  labourers and supply: docs/ai_crown_rebuild.md section 2 has each plan's steps and the times they came on Hard. In short:
  Economy: the ramp Cottage, the second Farm and the Gate at 7 labourers, Barracks and Mill at 8, the first Musketeer
  2:48-3:33, the second hall at 15 labourers (3:08-3:25). Balanced and Timing: the ramp Cottage and Gate, Barracks and Mill
  at 7 labourers (0:43), the first Musketeer 2:02-2:16, the second Farm at 9; Balanced expands at 15 labourers (4:00-5:05),
  Timing adds a second Barracks, the Breeder and the Foundry and attacks with 22 supply (7:00-7:30). Rush: Barracks 0:36,
  Breeder 0:49, the first Horseman 1:52-2:04, three out at 2:56-3:13 (`tools/test_crown_build_order.gd`).
- Since 0.30.9 (crown-owner-eco, docs/crown_owner_eco.md) Economy and Balanced play THE OWNER'S OPENING: the ramp Cottage
  and Gate, the second Farm at 7 labourers, the SECOND HALL at 11 labourers (laid ~1:30, standing ~2:05), a Farm at it at
  once; Economy: the Mill at 15, the Barracks at 17 after the hall (~3:10), Musketeers from then on, the Foundry at 21, the
  Breeder at 23; Balanced: the Barracks and the Mill at 14 after the hall (the Foundry, the second Barracks and the Breeder
  are milestones), or right after the scout's first look when it saw nothing. A scouted rush puts the Barracks and the Mill
  up at once (both plans); against the Brood Balanced keeps the Barracks and the Mill at 7 labourers (its fastest rush
  comes before any look). The scout leaves at the start on both plans.
- Counter-play to a Brood rush: the wall and 3 Musketeers by 2:40 (`tools/test_ai_wall_vs_rush.gd`: 2:38 default map,
  2:32 Ashfall).
- (Before 0.29.0: Rush = Horse Breeder opening, 3 Horsemen out by ~3:30; Balanced / Economy / Timing opened with the
  Barracks at ~1:20.)

### Clockwork
- The first Assembly Works used to wait for `clock / tech factor`, so Rush (factor 2.0) was the slowest to
  open. It now goes down by the clock for every plan (Hard 1:00 with 7 Winders) and the Winders wait for
  its 200 gold. Rush attacks at ~2:44 with the first wind-ups, a counterpart of the Brood rush with much
  weaker punch (wind-ups are slow). Counter-play sketch: a Crown wall + 3 Musketeers or Brood Raptors in
  the swamp both beat early wind-ups; not yet covered by a dedicated test.

### Clockwork: the Springer timing (0.28.0, scripts/ai_clockwork.gd, docs/clockwork_ai_rebuild.md)
A written build order by supply (not by the clock), the plan owning its gold until the attack has left and the
expansion is laid. Measured on 0.28.0, Hard Clockwork against the Hard Crown computer, Greenhold, Kestrel Rise and Frostmere
(seeds 11 and 12): Light Works 1:35-1:38, Mainspring (big ring) 2:01-2:04, Escapement 2:33-2:37, HIGH LEAP 3:38-3:42,
the 4th Springer 4:11-4:15, the Swift 4:17-4:23 (READY), the raid out 4:17-4:33, first leap in 5:24-5:38, the second
Clocktower laid 4:51-5:14; 20 Winders at 6:00, 25 at 8:00. `tools/test_clockwork_springer_timing.gd`.

## Tests that keep this honest
- `tools/test_ai_brood.gd [profile:xrush|rush|timing|balanced|economy|air]`: the Brood table above, each milestone by
  its latest time (about a minute's margin), no food bank over 900 for a minute, grubs at the plan's cap.
- `tools/test_ai_wall_vs_rush.gd`: the Crown's wall and 3 Musketeers against the Brood computer's Extreme rush.
- `tools/measure_ai_timelines.gd` / `run_ai_timelines.sh`: the table above.

## Known limits
- Brood Rush against a Crown Rush is a gamble: Raptors (36 hp, 6 damage) do little against Cuirassiers,
  and a lost wave can leave the Brood wiped out by 4:30 on some seeds. That is the intended risk of a
  rush, but the Brood could keep its Raptors home when it sees Horsemen. Open.
- The Crown AI banks 1-2k gold by 4:30 in these runs (not touched here).

## After the first rush resolves (patch 0.13.2, tools/test_ai_rush_followup.gd)
The Horseman rush (Crown, Horse Breeder opening, as a raiding party or as the Rush plan's first wave),
the Brood Raptor rushes and the Rush plan of any faction are judged from facts (`AI._rush_verdict`):
riders alive, enemy value killed against the rush's worth, armed defenders seen, enemy workers seen,
time since it began. ONGOING changes nothing.
- FAILED (riders dead or beaten back, defenders alive, no headway): the riders ride home, new cavalry
  stay home as defence, no raiding party re-forms for 150-240 s, the plan becomes a normal build and
  the next attack waits for a proper force (usual army-size rules, regroup time).
- SUCCEEDED, few workers (3 or fewer seen) and no defenders ("finish"): fresh cavalry may ride out,
  but only as a group of 2+.
- SUCCEEDED otherwise ("mop"): the riders regroup at the rally point, the economy goes on (normal
  Musketeer and cavalry mix), and ONE force of at least 12 supply (more for bigger defences) goes out.
- Always: units trained after a wave left wait at home and join only as a group (2+ units, and 6+
  supply in an ordinary wave); a party cut down to one rider sends him home. Scouts are the only
  units that go alone.
