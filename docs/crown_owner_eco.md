# The Crown computer plays the owner's economy (0.30.9, branch crown-owner-eco)

The owner (2026-11-04 19:46 and 19:57): "First we need a better Crown AI. Can you analyse my log to improve the Crown AI?"
He wants the Crown computer to play his way. His log: `docs/playtests/2026-11-04/human_crown_v_brood_brute_siege_highmoor_0308.txt`
(the owner playing the Crown by hand, about 130 actions a minute, against a Hard Brood on its Brute siege plan, Highmoor; he
held it for 16 minutes and kept pace with the Brood's income). His three newest points came from watching Hard Crown Economy
against Hard Brood Economy on 0.30.8 (pictures `eco_v_eco_1..5` in the same folder):

- **A. No early Barracks without a reason**: "Why did it build a Barracks? It built it too soon; I don't think it scouted
  anything ... If you scout a rush you need a Barracks, but if you don't scout that, why make a Barracks?"
- **B. Base layout**: picture 1 (the computer's base) is "a mess"; picture 2 (his) is "much more organized; pay attention to
  the minimap so you can see my base logic and structure".
- **C. Defend at the wall, not on the high ground**: "the Crown army should have left the high ground for the palisade of
  the natural base; the high ground only makes sense when there is no wall".

Design rules followed (docs/design_principles.md): 2 (the defender's advantage: walls and gates, then the high ground; a
small lead must not decide the game, so no hall the army cannot hold), 3 (meaningful base building: placement that has a
reason, builders with an opportunity cost) and 5 (the owner's extreme-rush anchor: the wall and Musketeers in time against
a scouted rush). No unit or building number was changed; proposals are in section 9.

Pictures: `docs/shots/crown_owner_eco/` (captions in its `captions.md`).

## 1. His game as a timeline

Highmoor, 0.30.8, the owner's Crown against the Hard Brood's Brute siege (seed 935948638). From his match log:

| time | labourers | gold earned | army (value) | what he built |
|---|---|---|---|---|
| 0:36 | | | | the ramp Cottage, and the Gate at 0:37: the ramp is shut |
| 1:00 | 8 | 380 | 0 | the second Farm done 1:14 |
| 2:00 | 13 | 760 | 0 | a Cottage 1:52; the second Town Hall going up (laid ~1:46) |
| 3:00 | 17 | 1,520 | 0 | **the SECOND HALL DONE 2:46, before any Barracks**; a Farm at it 3:01 |
| 4:00 | 25 | 2,280 | 0 | the Mill 3:20, Barracks 3:29 and 3:45, 9 palisade pieces at the natural 3:49 |
| 5:00 | 30 | 3,800 | 240 (4 Musketeers) | the first Musketeer 4:27, the Breeder 4:32, a Farm 4:50, the Foundry 4:56, 22 palisade 4:55-4:59 |
| 6:00 | 32 | 5,320 | 580 (9 Musketeers) | the third Barracks 5:19, three Cottages 5:17-5:26, 13 palisade 5:36-5:42 |
| 7:00 | 38 | 6,840 | 1,360 (17 + 2 Field Cannon) | four Cottages 6:18-6:39, Barracks 4-6 at 6:38-6:53 |
| 8:00 | 42 | 8,740 | 2,080 (29 + 2 guns) | two Churches 7:36-7:41, the second Mill 7:47, gates 7:14 and 8:02 |
| 9:00 | 48 | 10,640 | 2,180 | **the third hall 8:15** |
| 10:00 | 58 | 12,540 | 2,710 | 10 more palisade 9:05; the Brutes die at his natural's palisade 9:36-10:46 |
| 12:00 | 59 | 17,360 | 3,450 (46 Musketeers) | 13 Barracks by 11:12, research from 11:21 (2,000 gold in the bank), the third Mill 11:37 |
| 13:00 | 62 | 19,260 | 2,840 | **the fourth hall 12:25** |

His farms paid 63-72% early against the computer's 44-58%. What not to copy: from 9:00 to 11:00 he sat supply-blocked at
105-114 of 126 with 1,400-2,600 gold unspent, and at 15:20 his four Powder Wagons, parked together by the army, blew up in a
chain and the army fell from 4,755 to 1,320.

He laid his second Barracks (3:45) before the Foundry (4:56), against his own rule FOUNDRY BEFORE THE SECOND BARRACKS,
ALWAYS (CLAUDE.md). The computer keeps the rule (question 1 in section 8).

## 2. What changed

All of it on the Economy and Balanced plans (`AICrown.PLANS[...]["owner"]`), Normal and up. `-- owner:off` on the command
line plays as 0.30.8 (the old openings and milestones, none of the rules below): the "before" games here are that.

### 2.1 No Barracks without a reason (point A)

`scripts/ai_crown.gd` PLANS:
- **Economy**: the ramp Cottage and Gate, the second Farm at 7 labourers, the **second hall at 11 labourers** (laid ~1:30,
  standing ~2:05), the Mill at 15 and the **Barracks at 17 labourers once the second hall is laid** (~3:10; the owner's
  3:29), Musketeers from then on, the Foundry at 21, the Breeder at 23. Milestones after it: the second Barracks right after
  the Foundry, the third at 26 labourers, the fourth at 32, a Church at 38, the Armoury at 42.
- **Balanced**: the same opening, the second Farm after the scout's first look, the Barracks and the Mill at 14 labourers
  after the hall, more Musketeers; **when the scout's first look saw nothing** ("could not see the enemy": its verdict
  "uncertain") the Barracks and the Mill come next (`AICrown._safe_reason`, `_bo_safe`).
- **A scouted rush** (the scout's "rush" verdict, rush evidence) still inserts the wall, the Barracks and the Mill at once,
  soldiers first (`_bo_defence`, both plans); its new hall's gold is no longer held while the rush is feared.
- **The scout leaves at once** (2 s, with four labourers; `AIScout.min_workers`, `OWNER_SCOUT_AT`): it is at the enemy's
  base at ~1:05-1:10 instead of ~1:20, in time to see a rush.
- A wall slot of the new hall takes no Barracks before the plan's own Barracks step (`slot_barracks_ok`, asked by
  `AIExpandWall._fill_slot`).
- **Against the Brood the Balanced plan keeps its Barracks and Mill at 7 labourers** (`bo_brood`): the Brood's fastest
  rush has Raptors at the ramp by ~1:50 and the first look comes at ~1:10; a Barracks laid on the look (tried: 1:11) gave
  the first Musketeer at 2:39 and the gate fell at 2:16 (`tools/test_ai_wall_vs_rush.gd`, the owner's 6-pool anchor).
  The reason is the matchup. The Economy plan against the same rush: section 6.

### 2.2 A Farm at every new hall at once

`AICrown._hall_farm`: the Farm's gold is set aside while the new hall's last fifth goes up, and the Farm is laid the moment
the hall stands, on the spot the layout kept for it (section 3). Measured: 9-19 s after the hall stood (the owner's 15 s;
0.30.8 waited from 3:52 to 5:14 in the eco v eco game).

### 2.3 Cottages ahead of the supply

`AICrown._supply_ahead` replaces the one-at-a-time Cottage: as many Cottages go up at once as the Barracks, Foundries and
halls eat in 26 s (a Cottage's 20 s build and the walk), four at most; in the opening the old margin (two, and two a
Barracks: a Cottage too early is a Musketeer missing against a rush). Measured: blocked with 300+ gold for 0-3 s a game.

### 2.4 The natural's palisade ring by 4-6 minutes, in every matchup

`AICrown.owner_walls` lets AIExpandWall wall the new hall at once (the rule crown-v-brood made for the Brood) in every
matchup, from 45 s after the hall stands; until the ring is closed (85%) its pieces come before the next labourers.

### 2.5 The third hall when the army can hold it; production scaled to the income

- `AICrown.owner_hall_ok`: from the third hall on, the next comes with 40 labourers (50 for the fourth) and an army of
  0.7 times the labourers in supply, or when the best soil is under 35% (the shared rule wanted one hall per 16 labourers:
  the third at 5:50, which took the army's gold and was the first hall lost). It also holds the shared bank's hall.
- `AICrown._scale_prod`: once the milestones are up, a Barracks (a Foundry every fifth) while what the production can spend
  (a Barracks 240 gold a minute, a Foundry 320) is under 85% of the gold earned in the last 90 s, less the labourers' share,
  every Barracks is busy and nothing else is going up. The first Field Cannon's gold no longer holds the production
  milestones back (the tech still waits for it).

### 2.6 The base layout (point B), 2.7 the wall post (point C), 2.8 the wagons

Sections 3 and 4; the wagons: `AICrown._spread_wagons` puts every Powder Wagon at home by a different hall, six tiles apart
at least (one wagon stays by the main hall as before).

## 3. The base layout

`scripts/ai_crown_layout.gd` (AICrownLayout). Every hall of the Crown computer gets a plan the moment it stands:

1. **Its ground**: the cells on the hall's level (off ramps and terrain) joined to it, within 24 tiles (the main) or 14
   (another hall; inside its wall ring when AIExpandWall planned one).
2. **The economy first**: spots for the Farms and the Mill the hall still lacks, nearest the hall; nothing else is laid
   within a tile of them.
3. **A lattice of 5 x 4 blocks**: a block holds one production building (4 x 3: Barracks, Foundry, Breeder, Armoury, or a
   3 x 3 Church) with a one-tile lane on its right and below, or four Cottages packed in a 4 x 4 square. Of the 20 ways to
   lay the lattice the one with the most whole blocks is taken. Blocks off the ground, at a ramp's mouth, touching the hall,
   over an economy spot or within 2 tiles of the walk from the hall to the ramp's top are dropped.
4. **The Cottage block**: on the main, up to six blocks (at most 45%) that sit farthest at the back (away from the map's
   middle and from the ramp) and on the plateau's edge hold the Cottages, filled from the outermost cell in; the rest are
   production rows, nearest the hall first.
5. Nothing is placed where it would cut part of the ground off (Game._plateau_reach).

The ramp Cottage, a new hall's wall slots and the Farms keep their own spots; when the layout has no room the shared search
places the building. `-- layout:off` switches it off.

LAYOUT_PICTURES

## 4. The wall post (point C)

`scripts/ai_crown_hold.gd` section 6 (`_wall_plan`, called first by `hold_top`): when the threat is at a hall whose wall
ring is at least 70% closed, the army goes to the **inside of that wall where it is hit**: the Musketeers on HOLD in rows
1-3.3 tiles behind the palisade nearest the claws (a musket reaches 190 px: over the stakes), the guns 3.6-6.5 tiles
behind them, facing out; labourers mend the most hurt piece of that stretch (the edge post's menders, who run back into the
base when a claw comes). The cliff edge (crown-cliff-edge) is kept for a hall with no wall, the ramp post for the main.
`-- wallpost:off` switches it off.

WALL_PICTURES

## 5. The computer against his numbers

COMPARE_TABLE

## 6. The coached games, before and after

MATRIX_TABLE

## 7. Tests

- `tools/test_crown_owner_eco.gd` (new; Greenhold seed 11, Hard Crown Economy against a Hard Brood Economy that sends no
  army): no Barracks before the second hall without a scouted rush; the second hall by 3:00; every new hall's Farm within
  20 s; never supply-blocked over 15 s at a stretch with 300+ gold; 22 labourers or more at 4:00; the Cottages in the
  layout's Cottage block and the production buildings in its rows (75% or more); eight Raptors put at the natural's
  palisade at 6:30 bring the army inside that wall (the wall post), not to the main's cliff edge. TESTS_RESULT
- Still passing: TESTS_OTHERS

## 8. Open questions (the owner decides)

QUESTIONS

## 9. Proposals (balance, not changed here)

PROPOSALS
