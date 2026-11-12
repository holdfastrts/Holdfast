# Economy parity (job economy-parity, 0.33.26, branch `economy-parity`, NOT merged)

The owner (2026-11-12 21:04): "I would like all economies to be about the same level of resources per minute, but
instead of buffing the Crown maybe we should nerf the other factions." He also wants a SLOWER game overall and asked
which RTS the current pace resembles.

Design rules followed (docs/design_principles.md): section 1 (fairness: the same income at the same build, measured,
not guessed), section 2 (depletion forces expansion: a base still runs out when it did), and the owner's own rule for this
job (no Crown buff). docs/exhaust_economy.md's rules (no trickle, spent means spent, the floors) are untouched.

**The branch changes two numbers** (and the texts that quote them): the Clockwork's Cog Press 7.2 -> 6.4 cogs a second
small, 10 -> 8.9 big, and a Clocktower's raw brass 9,000 -> 8,000. The Brood was measured and left alone (a FOOD_BONUS
cut was tried and taken back: section 4). Nothing of the Crown changed. **The owner must approve before it is merged** (section 8).

__SUMMARY__

## 1. The bench: the design, not the computer

`tools/econ_bench.gd` (new; the old bench of the shelved Line's Boilers and Ore Crushers is in git history) plays ONE
faction alone on a map (the other slot is an idle dummy) with a SCRIPTED IDEAL BUILD, the same for every faction:

- workers without a break from every hall (the Brood: eggs from the Mother) up to the posts its economy offers; each new
  worker takes the game's own first post (Game.free_site / BroodNew.free_source); idle or released workers are sent to a
  free post every 2 s;
- the economy buildings as soon as they can be paid, each hall its own quota (Crown: 2 Farms + a Powder Mill; Clockwork:
  2 Cog Presses on the big ring + a Mainspring; Brood: Rootmaws wherever its spot finder has room, one walking at a time,
  while its grubs fill them); spent ones pulled down (a player frees the hall limit for fresh ground; the Brood's spent
  Rootmaws get up and walk to fresh ground, as its computer does);
- supply just in time (Cottage, Spring Tower, a Mound Turtle);
- the next bases at fixed times: **4:00, 8:00 and 12:00** for the Crown and the Clockwork (Town Hall / Clocktower on the
  computer's own next hall spot); the Brood's "base" is a Mound Turtle on new ground (its far spot finder) and Rootmaws round
  it; the Mother grows to stage 2 at 4:00;
- no army, research or walls: the rest stays in the bank. Buildings are laid where the computer would lay them (its own
  spot finders, on a computer player whose thinking is off) and stand after their build time (one ideal builder, no walk).

**Common value**: primary + secondary at 1 : 1 (gold + powder, cogs + Tension, biomass + spoils): a Musketeer is 60 gold +
10 powder, a Clock Soldier 70 cogs, a Springer 100 cogs + 25 Tension, a Raptor egg 50 biomass for two: a unit of any
resource buys about the same fighting value. Secondary resources are taken out of the pool every second, so a full store
never stops them. Map Greenhold, seed 1 (a second map, Dune Sea, in section 2.3).

### The Brood's clock

With the same clock the Brood is far behind (0.58 of the Crown at 5:00), because its home holds only two Rootmaws (their
circles of ground may not overlap) and its first base is new ground: a Mound Turtle (a grub and 100 biomass) where the
others pay a 400 hall. In real games the Brood takes it at once: the Hard computers' median (the qa-matches games) is a
far turtle at 0:00-1:00, the third ground at 6:00, the fourth at 10:00, against the Clockwork's 4:00 / 7:00 / 11:00 and the
Crown's 5:00 (and rarely a third). So the Brood is benched on **its natural clock, 1:00, 6:00, 10:00**, the Crown and
the Clockwork on 4:00 / 8:00 / 12:00 (a good player's; the Clockwork computer's own is nearly that). The same-clock Brood
row is kept in the table for reference. A greedy run (`exp=auto`: the next base whenever the bases are nearly full) is in
docs/economy_parity/before/auto_*.json: it only shows that every economy runs away without an army to pay for (the
Clockwork fastest), so it is not used for parity.

## 2. Before and after

![The curves](economy_parity/curves.png)

### 2.1 Value earned, cumulative (Greenhold)

| Greenhold | 3:00 | 5:00 | 8:00 | 10:00 | 12:00 | 15:00 | 20:00 |
|---|---|---|---|---|---|---|---|
| Crown (unchanged; 4/8/12) | 1,903 | 4,364 | 10,034 | 14,079 | 18,735 | 26,559 | 36,866 |
| Clockwork before (4/8/12) | 2,361 (1.24) | 4,634 (1.06) | 10,455 (1.04) | 14,860 (1.06) | 19,829 (1.06) | 27,126 (1.02) | 37,469 (1.02) |
| **Clockwork after** | 2,113 (1.11) | 4,157 (0.95) | 9,377 (0.93) | 13,342 (0.95) | 17,791 (0.95) | 24,351 (0.92) | 33,680 (0.91) |
| Brood (unchanged; its clock 1/6/10) | 1,436 (0.75) | 4,344 (1.00) | 9,237 (0.92) | 14,074 (1.00) | 18,728 (1.00) | 25,585 (0.96) | 37,674 (1.02) |
| Brood with FOOD_BONUS 1.0 (option, not applied) | 1,428 (0.75) | 4,133 (0.95) | 8,741 (0.87) | 13,307 (0.95) | 17,826 (0.95) | 24,608 (0.93) | 35,556 (0.96) |
| Brood on the same clock 4/8/12 (reference) | 1,416 (0.74) | 2,523 (0.58) | 7,074 (0.71) | 10,245 (0.73) | 14,673 (0.78) | 21,374 (0.80) | 32,540 (0.88) |

(in brackets: the share of the Crown's.) The target was within about 10% at 5, 8, 10 and 15 minutes.

**Reading it.** By design, BEFORE this branch, the Crown and the Clockwork were already within 6% of each other at every
point from 5:00 (the Clockwork 24% ahead at 3:00: its start Cog Press pays steadily while the Crown's Farm pays in 380-gold
lumps), and the Brood, on its own clock, within 8%. The big gaps of the computer games (the Clockwork 1.4-1.6 x the Crown,
the Brood 1.2-1.35 x late) are not in the economies' design: they are in how much of it each COMPUTER gets (section 3).

### 2.2 Per minute, per worker, running out

| | per minute at 3 / 5 / 8 / 10 / 15 / 20 | workers at 5 / 8 / 10 / 15 | value a worker a minute at 5 / 10 / 15 |
|---|---|---|---|
| Crown (unchanged; 4/8/12) | 1,143 / 1,248 / 2,816 / 1,955 / 2,797 / 1,363 | 22 / 44 / 40 / 72 | 57 / 49 / 50 |
| Clockwork before (4/8/12) | 1,103 / 1,132 / 2,423 / 1,997 / 2,442 / 1,406 | 20 / 35 / 43 / 49 | 71 / 67 / 56 |
| **Clockwork after** | 991 / 1,016 / 2,176 / 1,803 / 2,217 / 1,273 | 20 / 35 / 43 / 49 | 64 / 60 / 50 |
| Brood (unchanged; its clock 1/6/10) | 589 / 1,867 / 1,589 / 2,354 / 2,068 / 2,123 | 36 / 59 / 59 / 69 | 53 / 44 / 30 |

- **A base, saturated**: Crown 2 Farms (8 each) + a Mill (6) = 22 labourers for 1,140 gold + ~100-110 powder a minute
  (Farm: 380 gold every 40 s with 8 hands, 71 a labourer a minute; a Mill hand ~17 powder a minute); Clockwork 2 big
  Presses (8 each) + a Mainspring (3 on its small ring) = 19 Winders for 1,200 cogs + ~110 Tension a minute before (75
  cogs a Winder a minute on a big press, 86 on a small one), 1,068 cogs after (67 / 77); Brood 2 Rootmaws, 6 grubs each near the Mother
  (36 biomass a grub a minute near, up to 2.2 times far, more grubs far: +1 a 3 tiles past 8 tiles, up to 12).
- **Workers come at very different speeds**: one labourer or Winder every 12 s from each hall; the Mother lays an egg
  every 6 s (x1.0 to x1.9 with her growth, expansions and harvest veterancy): the Brood fills new ground two or three
  times as fast, which is why its curve jumps right after each expansion.
- **Running out** (the "left" column of the data): a Crown hall's 9,000 soil lasts ~7.9 minutes of two full Farms, a
  Clocktower's brass ~7.5 minutes of two full big Presses (9,000 / 1,200 before, 8,000 / 1,068 after: the same), a
  Rootmaw's 3,000 ground ~12.5 minutes near, ~6 far. Every base in the bench was spent by 12-13 minutes after it began:
  the 20:00 points need a 5th base the schedule did not give, which is why all curves bend after 17:00.
- **Infrastructure for one saturated base** (what it costs before it pays): Crown 400 hall + 200 Farms + 100 Mill + 22
  labourers (1,100) = 1,800; Clockwork 400 + 2 x 165 big Presses + 140 Mainspring + 19 Winders (1,140) = 2,010; Brood a far
  Mound Turtle 150 (grub + 100) + 2 Rootmaws 250 + 14-20 grubs (700-1,000) = 1,100-1,400. The Brood's ground is the
  cheapest to take and to fill (section 5).

### 2.3 A second map (Hollowfen)

(The classic maps share their main and natural layout: Dune Sea gave Greenhold's numbers to the cog, so the second map
is a named 1v1 map, Hollowfen.)

| Hollowfen | 3:00 | 5:00 | 8:00 | 10:00 | 12:00 | 15:00 | 20:00 |
|---|---|---|---|---|---|---|---|
| Crown | 1,903 | 4,364 | 10,026 | 14,072 | 18,718 | 26,164 | 36,856 |
| Clockwork before | 2,362 (1.24) | 4,634 (1.06) | 10,439 (1.04) | 14,778 (1.05) | 19,684 (1.05) | 26,911 (1.03) | 37,386 (1.01) |
| **Clockwork after** | 2,113 (1.11) | 4,157 (0.95) | 9,365 (0.93) | 13,273 (0.94) | 17,669 (0.94) | 24,172 (0.92) | 33,612 (0.91) |
| Brood (unchanged; 1/6/10) | 1,039 (0.55) | 3,429 (0.79) | 7,559 (0.75) | 11,667 (0.83) | 16,261 (0.87) | 22,096 (0.84) | 31,085 (0.84) |
| Brood with FOOD_BONUS 1.0 (option) | 1,027 (0.54) | 3,270 (0.75) | 7,227 (0.72) | 11,113 (0.79) | 15,365 (0.82) | 20,847 (0.80) | 29,138 (0.79) |

The Crown and the Clockwork are map-proof (their bases are the same rings and squares everywhere). **The Brood is not**:
on Hollowfen its home and its new ground hold fewer Rootmaws, and it earns 0.75-0.87 of the Crown. So by design the
Brood's economy is at most even with the Crown's (Greenhold) and behind it on a tighter map (Hollowfen). That is why the
Brood was NOT nerfed here (section 4): FOOD_BONUS 1.0, tried first, would have put it 20-28% under the Crown on Hollowfen.

## 3. Design against the computer: who gets what out of its economy

Primary income only (the games' statistic: gold, biomass, cogs), the computer games (docs/qa_2026_11_08_matches.md, 0.33.7,
all 228 base games) against the bench's ideal build (before this branch):

| | 5:00 | 8:00 | 10:00 | 15:00 |
|---|---|---|---|---|
| Crown: games / bench | 2,422 / 4,180 = **0.58** | 5,102 / 9,500 = **0.54** | 7,665 / 13,180 = **0.58** | 12,863 / 24,460 = **0.53** |
| Clockwork: games / bench | 3,951 / 4,354 = **0.91** | 8,343 / 9,796 = **0.85** | 11,427 / 13,865 = **0.82** | 17,979 / 25,087 = **0.72** |
| Brood: games / bench | 2,421 / 4,344 = **0.56** | 5,842 / 9,237 = **0.63** | 9,347 / 14,074 = **0.66** | 17,423 / 25,585 = **0.68** |

The games have enemies (raids, lost workers, money for the army), so no computer reaches 1.0; but the CLOCKWORK computer
gets 72-91% of its design and the CROWN computer 53-58%, all game long. The whole Clockwork-Crown gap of the games (1.4-1.6x)
is there: by design the two were within 6%. Where the Crown computer loses it (from the games' data and the bench):

1. **It expands late and rarely**: its second hall at a median 5:00 (the Clockwork's 4:00), a third almost never by 15:00
   (1.9 halls at 8:00, 2.2 at 15:00; the Clockwork 2.6 and 3.9). The bench's Crown with a hall at 4:00, 8:00, 12:00
   earns twice what the computer does.
2. **Spent Farms keep their place under the hall limit.** A Farm on spent soil still counts against "2 Farms a Town Hall"
   (Game.econ_count counts every Farm), and the computer pulls down spent Mills and Presses (AI._recycle_spent) but not
   Farms. With its main spent and two fresh halls, it may lay only 4 Farms where 6 would work (the bench found it: its
   third hall stood with no Farm until the spent ones were pulled down). A human player who does not know to demolish a
   barren Farm falls into the same trap.
3. **Its labourers do more than farm**: they build the palisade and the gate, haul horses and powder, and 6 a Mill work
   for ~17 powder a minute each (a Farm hand makes 71 gold). Its workers earned 37 a minute each at 8:00 in the games,
   the Clockwork's 53 and the Brood's 34 (the bench: 50-64, 60-70 and ~45).

So **the parity the owner wants in the games needs the Crown computer fixed**, not more nerfs: to bring the games'
Clockwork down to the Crown computer's income it would take about -30% on the cogs, which would leave the Clockwork's design
30% under the Crown's once the Crown is played well (by the owner, or a better computer).

## 4. What each change does (the proposal, applied)

- **Cog Press 7.2 -> 6.4 (small, 5 Winders), 10 -> 8.9 (big, 8)**: -11% on every cog. Per Winder 1.28 (small) and 1.11 a
  second (big), was 1.44 and 1.25. The Clockwork falls from 1.02-1.06 of the Crown to 0.91-0.95 from 5:00 on and keeps its
  early lead at 3:00 (1.11, was 1.24), the identity the owner asked to keep: strong early, a little behind later.
- **Raw brass 9,000 -> 8,000 a Clocktower** (-11%, with the rate): a base runs dry at the same minute as before (about 7.5
  minutes of two full big presses), so the expansion pressure (design rule 2) is unchanged; without it a slower press
  would make each Clocktower last longer and the Clockwork would catch up late.
- **The Brood: no change.** FOOD_BONUS 1.2 -> 1.0 (a far Rootmaw x2.0 instead of x2.2) was applied first: on Greenhold
  it took the Brood from 0.92-1.00 of the Crown to 0.87-0.95, on Hollowfen from 0.75-0.87 to 0.72-0.82. A nerf that puts
  a faction 20-28% under the reference on some maps is not parity, so it was taken back before the game batch (the data
  stays in docs/economy_parity/after/ and hollowfen/ as "option_food_bonus_1.0"). The Brood's lead in the computer games
  is not its income design (section 3) but its computer's better use of it against a weak Crown computer, and its army
  per resource (section 5).
- Not changed: the Winder (60), the Mainspring and Tension (already the Clockwork's tech brake, docs/exhaust_economy.md),
  everything of the Brood (FOOD_RATE, FOOD_BONUS, maw_fill, PIT_GROUND, egg time, laying levers) and of the Crown.

**Equal income is not equal strength** (section 5): the branch does not change a unit price; a proposal is there.

## 5. Army per resource

Equal income is not equal strength. Three measures, none of them changed here:

**a. Equal-cost fights** (the existing tool tools/study_raptor_spitter.gd, run on this branch's base 0.33.25, 4 jittered
seeds a config; data docs/economy_parity/before/fights/). Open ground, the attacker attack-moves into a line on HOLD:

| fight (equal cost, ~1,200 or ~2,000 a side) | result | value left |
|---|---|---|
| Raptors (Brood, 50 an egg of 2) into 15 / 25 Musketeers (mid kit) | Brood 3 of 4 at 1,200, 4 of 4 at 2,000 | Brood 17% / 33%, Crown 13% / 0% |
| Clock Soldiers (70) into Musketeers, no gun | Crown 4 of 4 at 1,200 and at 2,000 | Crown 87-92%, Clockwork 0% |
| Clock Soldiers into Musketeers + 1 Field Cannon | Crown 4 of 4 | Crown 90% |

The Raptor swarm is the most cost-efficient army in the open (it beats an equal-cost Musketeer line, older study:
docs/raptor_spitter_study.md), and the Crown line on HOLD is the most efficient defence (a Clock Soldier wave walking into
it dies). These are one-sided set pieces (an attacker into a waiting line), not a measure of whole armies.

**b. What is not army.** To keep 1,000 of core army in the field each faction also pays for supply and production:

| | core unit (value a supply) | supply for 1,000 of it | production | overhead |
|---|---|---|---|---|
| Crown | Musketeer 60 + 10 powder (70) | 14 supply = 1.75 Cottages, 175 | a Barracks 150 | ~33% |
| Clockwork | Clock Soldier 70 (70) | 14 supply = 1.4 Spring Towers, 140 | a Light Works 150 | ~29% |
| Brood | Raptor 25 (25) | 40 supply = 3.3 Mound Turtles (grub + 100), 500 | a Tyrant Sire (grub + 150), 200 | ~70% |

Per resource the Raptor army costs the Brood MORE in supply, and at the 200 supply cap a Raptor army is worth ~5,000
against ~14,000 of Musketeers. The Brood's real edge is earlier: its **economy** costs less to build (a saturated base
~1,100-1,400 against the Crown's ~1,800 and the Clockwork's ~2,000, section 2.2), its expansions are a 150 turtle, its
eggs fill new ground two to three times as fast as a hall trains, and it has no Barracks to build. In the games that shows
as more army per income in the early and middle game (crown_v_brood_coach.md: at equal income at 8:00 the Brood had
about twice the Crown's army, half of the Crown's gold being in buildings; here: army value / income earned at 5:00 is
0.19 for the Brood, 0.15 the Clockwork, 0.08 the Crown).

**c. The proposal for a unit/price change (NOT applied; the owner decides, after the Crown computer's fixes):**
- Do nothing to unit prices now: the Brood's lead in the games is mostly the Crown computer (section 3), and the Raptor
  already pays supply heavily.
- If the Brood still comes out ahead once the Crown computer expands on time, the quiet lever is the price of its ground,
  not its army: the **Mound Turtle 100 -> 125** (its expansions and its supply cost 25 more; ~+15% on a new base, +17% on
  supply) or the **Rootmaw 75 -> 100**. Both slow how fast the Brood turns income into more income (design rule 2: a quiet
  brake on the leader's growth) without making its army weaker per biomass.
- The Clockwork needs no unit change: its army per income in the games (0.15-0.20) is its computer spending well, and the
  -11% on cogs lowers it with the income.

## 6. The computer games (Hard OPTIMAL v Hard OPTIMAL, 15:00)

__GAMES__

## 7. The pace

__PACE__

## 8. What the owner must decide

__DECIDE__

## How to run it

- Bench: `godot --headless --fixed-fps 30 --script res://tools/econ_bench.gd -- <crown|clockwork|brood> minutes=20
  exp=240,480,720 [map=greenhold] [seed=1] [press=big|small] [out=file.json]` (`exp=auto`: greedy expansions). About 2-4
  minutes of real time a run. The data of this study: docs/economy_parity/before/ and after/ (one JSON a run).
- Games: `python3 tools/study/qa_matches.py run OUT --data DATA --only parity --jobs 2` (72 games: 6 maps x 6 pairings x
  2 rounds, the qa-matches tags and seeds; `--root DIR` runs another checkout, e.g. main). Tables and pace:
  `python3 tools/study/econ_parity_report.py DATA [DATA2 ...]`; chart: `python3 tools/study/econ_parity_chart.py AFTER BEFORE`.
- Equal-cost fights: `tools/study_raptor_spitter.gd` (existing), configs A_1200, A_2000, X_*.
