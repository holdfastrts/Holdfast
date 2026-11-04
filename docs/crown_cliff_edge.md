# The Crown holds the cliff edge (0.29.2, branch crown-cliff-edge)

The owner's playtest (2026-11-03, watching 0.29.0; `docs/playtests/2026-11-03/crown_hall_lost_below_cliff_thornwood_0290.txt`
and its screenshot): Thornwood Maze, seed 1309500958, Hard Crown Balanced (P2) v Hard Brood Rush. The Crown expanded at
4:53 to a hall below its main's cliff, 20 tiles out; at 5:49 and 6:19 it held the top of its ramp against the Brood (350,
then 625) with its Musketeers behind the ramp wall, far from the cliff's edge; the Raptors razed the new Town Hall at 6:23.

The owner: "Crown did the right thing holding the high ground, but he could have abused the high ground better: the
musketeers were behind the wall, far from the limit of the high ground; it could have been hugging the high ground,
gaining more range to defend the town hall and not lose it. Also sending a few workers to repair it and juke around,
trying to repair while the musketeers killed the Raptors." And: "cannons are so important for the Crown; I think it was a
mistake to go Horseman. Why did it go Horseman instead of cannon?" Then (22:19-22:33) the expansion spots and the Foundry
rule below.

Why it went Horseman: the Balanced build order had the Horse Breeder at 13 labourers (for the rider scout of the doctrine)
and the Foundry only in the milestones at 22 labourers, which a rushed economy never reached; and nothing changed when it
scouted 8 Raptors at 3:08.

Design: docs/design_principles.md 2 (the defender's advantage, high ground and walls; a lost battle is lost territory, not a
lost game) and 1 (counterplay: the menders run from the claws, the cliff blocks the claws but not the muskets).

## What changed

### 1. The line on the cliff edge (scripts/ai_crown_hold.gd, section 5)

- While the Crown holds the top of its ramp against a force below that is at one of its buildings under the main's cliff
  (not at the ramp: then the ramp post holds as before; if there are Raptors at the ramp too, the edge only when most of
  them are at the building), the Musketeers and the guns move to the main's high-ground cells within a musket's reach of
  that building, nearest the Raptors on it first (they often hit its far side: the cells by its corners reach round it),
  spread along the lip (0.95 tiles apart, the guns 1.5), on HOLD, facing down. Only cells joined to the post on the main's
  level are used (never the ramp). At least 4 musket spots in reach, or it stays where it is.
- The high ground's advantage is kept: units on the low ground see a cliff's top only one cell in (`Game._stamp`), and the
  Raptors cannot climb; the line never steps down. When the force below could be beaten in the open (the old rule sent
  the army down), it now stays on the edge when the edge covers the fight: it shoots from above instead.
- A gun busy shooting from the ramp post at something far below is moved to the edge too; a fight at hand keeps a man.
- It walks back to the ramp post 4 s after the threat below is gone.
- Match log: `P2 Crown moves its musket line to the cliff edge above its Town Hall: 12 spots on the high ground, the
  nearest 81 px from it`.

### 2. Repair under fire

- While the edge post guards a hurt building, 2 labourers mend it (3 below 60% of its hit points, 4 below 40%; never more
  than a fifth of the labourers), the nearest first; a site still going up is helped only above 40% of its hit points.
- JUKE: a mender a Raptor goes for (it targets him within 210 px, or any claw within 30 px) runs to the cliff's foot under
  the line (or straight away from it if the Raptor is between), and goes back to mend 1.6 s after it is clear.
- No menders when it is no use: nothing of ours in reach shoots at what is on the building, the force there is 3 times the
  line in reach, or the building falls before the line can kill that force (its hit points against the claws' damage, the
  line's damage against their hit points); then a rest of 15 s. After 2 menders died on one building, or 8 were sent to it,
  none for 30 s. The workers' flight leaves menders alone (`AICrown._held_worker`).
- Match log: `sends 3 labourers to mend its Town Hall under the line's fire`, `calls its menders off (it falls in 4 s, the
  line needs 8 s)`.

### 3. Cannons against the Brood; the Foundry before the second Barracks (scripts/ai_crown.gd)

- Once any Brood creature is in sight (the labourer scout at its Mother counts) or a rush is scouted, the Balanced plan
  puts the Foundry before the Horse Breeder in its opening (the Foundry at the Breeder's trigger, the Breeder when the
  Foundry stands: the gun needs a horse), and the milestones the Foundry before the Breeder (the Economy plan keeps its
  Foundry's labourer count: it expands first).
- The Foundry's first gun is a Field Cannon, before a Mortar or a Powder Wagon; while it waits for its gold (90 s at most
  once the Foundry and the Breeder stand) the Barracks save for it, the milestones wait and no Horseman is trained; the
  opening's army cap does not hold it back (`AICrown._first_gun`). The rider scout comes after the gun (a labourer scouts
  meanwhile). (The new hall waiting for the gun too was tried and is off, `-- hallgun:on`: it put the hall at 5:53 instead
  of 5:05 on Red Coast.)
- No counter-attack into the Brood after a held rush (`AICrown.counter_ok`, asked by AITransition): with the cannon's
  value added, the transition sent the whole army out at 6:28-6:31 on Red Coast into 2,400-3,000 of creatures it had not
  seen, and lost it; the doctrine holds the high ground and goes down by its own timing.
- The cannon goes to the ramp post's gun spot, or to the edge with the line; its canister (`AI._abilities`: 3+ enemies in
  150 px) fires into the Raptors. Seen in game: rc_after 7:51 and tw_raid_a 7:53 "the cannon fires canister (unlimbered)".
- THE OWNER'S RULE (22:33): in every plan and every matchup the Foundry comes before the second Barracks (docs/ai_crown_rebuild.md
  section 2, "Crown doctrine lines"). Every plan's table is written so; `AICrown._construct` turns any other call for a
  second Barracks with no Foundry into the Foundry.
- Against the Crown and the Clockwork the opening order is unchanged except for that rule.

### 4. The Crown's own expansion spots (scripts/crown_sites.gd, docs/expansion_spots.md "The Crown's rule")

The 2nd and 3rd halls at the least hall distance (18 tiles), close together, under the main's cliff edge; the 4th on as
close as it may be to the other halls. The gold marks a Crown side sees and the Crown computer's hall pick both use it.

Measured on the bare map (tools/measure_cliff_cover.gd): on all four maps a legal hall spot right under the cliff existed;
the old pick stood 7-10 tiles from the edge, out of musket reach, with none of its sides covered; the new spot is 18.0-18.1
tiles from the main, its nearest side 2.0-2.4 tiles from the edge, 45-63% of its sides in musket reach.

## Coached games (tools/play_crown_1.gd, Hard v Hard, the Crown Balanced v the Brood; "before" = the switches below off)

The games are not exactly repeatable (the same seed played twice differs after a few minutes), so one game per row and
the solid parts are the timings and the "what happened". "Killed / lost" is army and building value (the match stats)
at the end. Staged raid: `raid:SECONDS:N` puts N Raptors 9 tiles out from the Crown's newest hall below the main, going
for it (25 Raptors is the owner's 625 at 6:19).

| game | run | 2nd hall (tiles from the main) | what happened to it | first cannon / canister | edge moves, menders (dodges) | killed / lost |
|---|---|---|---|---|---|---|
| Thornwood v Rush (owner's seed, Crown P2), 9:00 | before | 4:57 (23) | stood | none | - | 2,025 / 325 |
| | after | 5:44 (18) site razed 5:53; 6:14 (18) | stood | 5:32 / 5:56 | 5, 0 | 2,375 / 170 |
| ... + raid of 25 at 6:45, 8:00 | before | 4:53 (23) | at 290 hp from the Brood's own attack at 6:45, **razed 6:49** (picture 01) | none | - | 1,400 / 925 |
| | after | 5:44 site razed; 6:33 (18) | the raid hit it going up: **stood, 1,600/1,600** 60 s later (raid: 325 killed, 0 lost) | 5:32 / 7:53 | 4, 0 | 2,275 / 460 |
| ... + raid of 10 at 7:20, 8:20 | after | 6:30 (18) | **stood, 1,556/1,600** | 5:32 / 5:57 | 5, 8 (1) | 1,875 / 370 |
| Greenhold v Rush + raid of 25 at 6:45, 8:00 | before | 4:57 (22) | **razed 7:08** | none | - | 1,600 / 715 |
| | after | 6:08 (18) site razed 6:18; 6:58 (18) | stood | 5:43 / - | 3, 0 | 2,150 / 210 |
| ... + raid of 10 at 7:20, 8:20 | after | 6:04 (18) | **stood, 243/1,600** (the Raptors on its far side, out of musket reach) | 5:40 / - | 4, 4 (2) | 2,025 / 450 |
| Kestrel Rise v Rush, 9:00 | before | 4:15 (20) | stood | 7:50 / - | - | 1,925 / 975 |
| | after | 6:06 (18) | stood | 5:39 / - | 0, 0 | 1,575 / 285 |
| Kestrel Rise v Timing, 10:00 | before | 5:04 (20) | **razed 7:42** | none | - | 1,450 / 1,625 |
| | after | 5:57 (18) | stood, a 3rd at 9:15 | 5:43 / 7:08 | 1, 0 | 1,700 / 620 |
| Red Coast v Timing (owner's 0.27 seed), 10:00 | before | 5:05 (23) | razed 8:41, **main stood** | none | - | 2,590 / 1,815 |
| | after (3 runs) | 5:04-6:38 (18) | **main razed 8:59 / 9:05 / 9:41** | 5:37-6:36 / 7:41-7:56 | 0-1, 0 | 2,075-4,075 / 3,915-5,325 |
| Red Coast seed 7 v Timing, 10:00 | before | 5:05 (23) | razed 8:28, **main stood** | none | - | 4,925 / 2,080 |
| | after (3 runs) | 5:05-6:25 (18) | **main razed 9:08 / 9:11 / 9:51** | 5:34-5:59 | 1, 0 | 1,825-4,500 / 4,750-5,655 |
| | after, no cannon first (`cannon:off`) | 5:05 (18) | **both halls stood** (picture 12) | 8:52 | 19, 8 (17) | **5,100 / 1,380** |
| | after, the gun's gold not saved (`gunsave:off`) | 5:02 (18) | 2nd razed 9:28, main stood | 6:01 / 8:26 | 14, 3 (2) | 5,100 / 4,020 |
| Red Coast (owner's seed) | after, `gunsave:off` | 5:04 (18) | main razed 8:44 (gg 9:29) | none | 3, 0 | 1,870 / 5,345 |

Read:
- **The cliff edge works where the attack is under it**: the line spreads on the lip (pictures 02, 04, 12), the cannon
  unlimbers there and fires canister (03), the new hall under the cliff stood against the staged raids that razed the old
  far hall, and on Red Coast seed 7 without the cannon-first the line held the edge 19 times with 17 dodges by its menders
  and traded 5,100 for 1,380.
- **The owner's own situation** (Thornwood, a raid at the new hall at 6:45): before, the hall at the old spot was razed at
  6:49 with the line behind the ramp wall (01), as in his game; after, the hall under the edge stood.
- **The cannon now comes at 5:32-5:59** against the Brood (never before 7:50 before) and fires canister in most games.
- **But against the Brood's Timing attack on Red Coast the cannon-first costs the main**: 6 of 6 runs with the gun's gold
  saved lost the main at 8:59-9:51; both runs before kept it; the same code without the cannon-first kept everything.
  The Foundry, the Breeder and the gun (about 610 gold between 3:30 and 6:00) and the Barracks saving for the gun leave the
  line short when 3,000-4,000 of creatures come at 7:30-8:30. Kestrel Rise v Timing went the other way (the hall razed
  before, everything stood after). Left ON as the owner asked; **his call** (proposals below).
- Expansions under the cliff are also more often razed as sites (Thornwood 5:44-5:53, Greenhold 6:08-6:18): the Brood's
  attack comes at that time; the site has few hit points and its builders run.

Proposals for the owner (not done):
1. Against the Brood's Timing (a big army before 7:00 seen, or Red Coast-like open maps), the cannon after the second
   Barracks' worth of Musketeers, not before: keep the Foundry before the Breeder but do not save the Barracks' gold for
   the gun (`gunsave:off`) - one run each way so far, more games needed.
2. The new hall's wall (ai_expand_wall.gd) should close the side away from the cliff first: that side is out of musket
   reach (45-63% of a hall's sides are covered).

## Tests

- `tools/test_crown_hold.gd` [edge] (new): Greenhold, a Town Hall of ours at the Crown's own spot under the edge and 16
  Raptors at it: the line moves to the edge above it (4+ Musketeers within 230 px of the hall, on the cliff's lip), none
  steps off the main's level, the cannon goes too; 2-4 labourers mend it at once; a mender two Raptors are sent at runs;
  the hall stands; the Raptors gone, the line is back at the ramp post and the menders are let go.
- `tools/test_crown_build_order.gd` [table]: every plan puts the Foundry before its second Barracks; [foundry]: in the
  game, no second Barracks before the Foundry.
- `tools/test_expansion_spots.gd`: every map run all-Crown and all-Clockwork (twins rated by one rule, mirror-fair); the
  Crown's spots at the least hall distance from the main and a hall's spacing apart; a new Crown hall makes the marks be
  worked out again from both halls.
- `tools/test_crown_farms.gd`: passes; its [farms] check (a free Farm slot waits at most 60 s) sits at the edge (worst 60 s
  in 2 of 5 runs printed as a fail, 58-60 s otherwise; it was 65 s once while the Economy plan also took the Foundry early,
  which is now left to its milestones). `tools/test_ai_wall_vs_rush.gd`: ALL PASS (the third Musketeer in time on both maps).

## Switches (study, comparison games)

`-- edge:off` (no edge post, no menders), `-- cannon:off` (no cannon first), `-- gunsave:off` (the cannon first, but the
Barracks and milestones do not save for it), `-- hallgun:on` (the new hall waits for the gun), `-- foundry1:off` (no Foundry
rule in _construct; the plan tables are changed for good), `-- sites:off` (the shared hall pick), `-- crownspots:off` (the
old gold marks for the Crown). The "before" games: edge, cannon, foundry1, sites and crownspots off (plays as 0.29.1 but
for the plan tables; the before games in the table were played before the no-counter rule was added). Of the Red Coast
"after" runs the first of each seed counter-attacked at 6:28-6:31 (before the no-counter rule), the later ones did not;
all lost the main.

## Tools

- `tools/measure_cliff_cover.gd` + `tools/draw_cliff_cover.py`: the main's edge, the old and the new hall spots, the musket
  reach, as a picture.
- `tools/play_crown_1.gd`: `cslot:1` (the Crown in the second slot, as in a log where it was P2), `raid:SECONDS:N` (the
  coach's staged attack: N Raptors 9 tiles out from the Crown's newest hall below its main, going for it), and per game
  `cliff.txt` (halls laid and lost, the first cannon and canister shot, edge moves, menders, value traded, the staged
  raid's outcome) and pictures `edge_MMSS.png`, `mend_MMSS.png`, `cannon_MMSS.png`, `raid_MMSS.png`.

## Open

- The Brood's attack often comes while the new hall is a site going up (5:25-6:20 on Thornwood): a site has few hit
  points and the line cannot save it; its builders run (the shared worker safety) and the site is dropped or razed.
- Red Coast v the Brood's Timing with the cannon first (above): the owner's call.
- The far side of a hall under the cliff is out of musket reach (45-63% of its sides covered): the cannon's round shot (430)
  reaches it, the walls of the new hall (ai_expand_wall.gd) should close that side first.
- No spot covers a hall on all sides; a hall hugging the cliff at one cell would, but the ring round a hall must be free.

Pictures: `docs/shots/crown_cliff_edge/` (captions.md).
