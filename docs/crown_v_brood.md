# The Crown computer against the Brood (0.30.6, branch crown-v-brood)

The owner (2026-11-04, three logs in `docs/playtests/2026-11-04/`): "This game is very revealing: the problem with Brood
vs Crown doesn't seem to be economics, it's the Crown AI." No Brood economy nerf until the Crown computer plays properly.
This job looked at his five points and his corner-pocket question, with coached games (Hard Crown v Hard Brood, filmed)
before and after. No unit or building number was changed; balance ideas are in section 7.

Design rules followed (docs/design_principles.md): 1 (counterplay: scout before you commit, answer what you see), 2 (the
defender's advantage, walls and the high ground, while the enemy is bigger; a lost battle must not be a lost game) and 3
(walls and chokes matter when clumping costs: a closed line against a melee swarm).

Pictures: `docs/shots/crown_v_brood/` (captions in its `captions.md`).

## 1. What was wrong, and what changed

### 1.1 The walls ("Crown doesn't wall, it makes 2 houses to the side, this is a pathetic wall")

What the log and the picture show (`crown_econ_ramp_two_cottages_0634.jpg`, Redrock Canyon):
- **The ramp wall itself is closed.** The 0:39 line "walled its ramp with a Cottage (1 pieces)" counts the pieces after
  the Cottage: on Redrock the ramp's mouth is 3 cells wide, the Cottage covers 2 and the Gate the third. Checked with the
  real path finder and bodies, not only the plan's flood fill (new test, section 6): on 8 maps (Redrock Canyon, Thornwood
  Maze, Greenhold, Kestrel Rise, Red Coast, Ashford Crossing, Cinder Steps, Highmoor) six Raptors told to walk from the
  ramp's foot to the main hall never get onto the main's high ground, and a Labourer walks out through the gate in 6-7 s.
  A Cottage is the strongest piece per cell (400 hit points and armour 1 for 2 cells, a palisade 200 per cell).
- **The two houses to the side are the NEW HALL'S wall**, not the ramp's: at 3:22 the computer planned a walled
  expansion (51 ways in, 25 palisade, 2 gates, 8 building slots), built Cottages into two of the slots, and never laid a
  single palisade: the slow wall of the doctrine waits for a saturated hall and an army the clock wants ("workers and army
  before walls"), which never came against the Brood. So two Cottages stood alone in the open (picture 02).
- **The "found no wall plan" spam** (121 lines, 7:36-7:53, every second): a hall whose plan failed got an empty plan with
  no hall in it, which the next think threw away and searched again (the dear search each time). The reason in the owner's
  game: a cell of the ring was taken ("Blocked": a rooted Brood creature or a building on a way in).

Changes (`scripts/ai_expand_wall.gd`):
- **Against the Brood the new hall is walled at once**: the doctrine's two waits are skipped; 8 pieces every 4 s, the
  ones nearest the enemy first. It never takes the gold set aside for a building, a milestone or the first Field Cannon,
  nor a Musketeer's (two while a Barracks stands idle and the army is behind), nor a labourer's while a hall could train
  one (the first try took the Economy plan from 27 labourers at 6:00 to 19). The slot Cottages now stand in a closed line
  of palisade (picture 03). Switch `-- xwbrood:off` for the old rule.
- A hall with no plan keeps its failed plan, is asked again quietly every 30 s, and the match log says once WHY (for
  example "7 with a way in no palisade may close (e.g. (49, 107): Blocked.)").

### 1.2 No blind attacks ("If your enemy is also Economy you can't attack without scouting")

At 7:53: "goes down with its army: no attack for 240 s on two halls and its army (1450) is not behind (0)". The 0 was the
Brood army it had NOT seen: two of the timing's five reasons and the wave check itself (`AICrown._wave_worth`: "nothing
known: it goes") read "nothing seen" as "nothing there". The same second the Brood attacked with 77 supply (5,235) and
caught the Crown in the open. In the coached "before" games the Economy plans went out at 7:50-7:51 knowing 550-700 of a
Brood army that had 2,855-3,005 at 8:00.

Changes (`scripts/ai_crown.gd` "NO BLIND ATTACKS", `scripts/ai_crown_hold.gd` timing):
- Against the Brood **a wave or a timing needs a fresh report**: an enemy soldier in sight, or its main looked at, in the
  last 75 s. Without one the army waits on the high ground and a scout is sent (the scout's next trip at once, past its
  five trips if need be; the riders' loop runs as before). Match log: "the wave waits for a fresh scout report: no enemy
  soldier seen for 121 s and its main not looked at for ...".
- **The Brood army it weighs is a reckoning, never 0**: what it saw in the last two minutes, but never less than a Brood
  of that age has (`BROOD_TABLE`: 100 at 3:00, 450 at 5:00, 700 at 6:00, 1,300 at 7:00, 2,200 at 8:00, 3,000 at 9:00,
  3,800 at 10:00, from the Hard Brood's mobile army in the "before" games, where it was 225-1,050 at 6:00 and 870-3,005 at
  8:00), more for every Rootmaw seen past what such a Brood roots (250 each), less half of what we have killed. A wave
  goes only worth 1.5 times that; the supply cap or a big army is no longer an excuse. The timing goes only worth 1.2 times
  it, with a fresh report.
- **The next hall waits** while the army is out, or while it is under 60% of the reckoning (the owner's game laid its
  third hall at 7:35 with 1,450 against 5,235).
- **The army keeps up with the reckoning**: from 6:00 (or the first Brood soldier seen), while it is under 60% of it,
  a hall trains a labourer only when every Barracks is busy, and when every Barracks and Foundry has been busy 15 s the
  plan's next Foundry or Barracks milestone comes now, whatever its labourer count (the Foundry still before the second
  Barracks), up to one production building for every 9 labourers.
- Switch `-- blind:on` (the old rule), `-- barmy:off` (no army reckoning).

### 1.3 The Horseman rush goes home while winning

Thornwood, 3:35: "rush: SUCCEEDED, mop-up: the riders regroup at home" with 345 killed for 100 lost. The shared rule
(`AI._rush_mode_now`) sends the riders home whenever the Brood's grubs are not seen to fall below three (they sit behind
the rooted creatures), and a force of 12+ supply is to go out later as one group.

Change (`scripts/ai.gd` hooks `_rush_hunt_on` / `_rush_hunt_over`, `scripts/ai_crown.gd`): against the Brood a rush judged
SUCCEEDED **keeps hunting** (mode "hunt": grubs first, the nearest Rootmaw seen when no grub is in sight; fresh Horsemen
join it like a finishing group). It ends when the riders are down to half (and two lost), when the MOBILE armed creatures
at the riders are worth 1.15 times them (the shared verdict's FAILED edge; a rooted Rootmaw, turtle or the Mother does not
chase and is not counted: the first try counted them and ended the hunt in 8 s), or when nothing has died for 75 s. Match
log: "SUCCEEDED, the riders keep hunting while they win (250 killed, 3 riders left, defenders seen 142)", then "the hunt
ends (a real answer: 214 of soldiers against its 165)". Other matchups: the shared mop-up as before.

### 1.4 Balloon harass on RANDOM PLAN against the Brood

`AICrown.random_plan` weighs the plans by the matchup, as the Clockwork's Pendulums: against the Brood Balanced 3, Timing
2, Rush 2, Siege push 2, Economy 1, Dragoon raids 1, **Balloon harass 0** (Mist Toads pull the balloons, Spitters and the
Venom Sire shoot them; in the owner's Redrock game the harass killed one grub in three minutes). Any other matchup: evenly.
A coaching tool can still force it.

### 1.5 The army against the Brood

See 1.2 (the army keeps up with the reckoning) and section 3. The Foundry and the Field Cannon came first against the
Brood already (0.29.2); the first gun came at 6:40-6:54 in the Economy games, the canister fired in every defence filmed.
What the games show is less an army share than an income gap: by 8:00 the Brood had earned 1.5-2.3 times the Crown's
gold in every Economy, Balanced and Timing game (section 3), the same before and after.

## 2. The wall pictures

`01_ramp_wall_redrock.jpg`: the Redrock ramp wall at 7:00 (the Cottage and the Gate close the 3-cell mouth). `02` and
`03`: the new hall's wall before (two Cottages alone) and after (the same Cottages in a palisade line to the cliff).

## 3. The coached games, before and after

Hard Crown v Hard Brood, 10:00 (the Rush 7:00), the Crown on the plan in the first column, `tools/play_crown_v_brood.gd`
(it extends `tools/play_crown_1.gd`). "before" = main at 0.30.5 (920fd463), "after" = this branch. The games are not
exactly repeatable (the same seed played twice parts after a few minutes), so read the patterns, not single numbers.
Army = value (Crown army v the Brood's MOBILE army: no Mother, Rootmaws, turtles, eggs or grubs).

Games: rr = Redrock Canyon, gh = Greenhold, kr = Kestrel Rise, tw = Thornwood Maze; then the Crown's plan and the Brood's
(eco = Economy, bal = Balanced, or the Balloon harass in `rr_bal_eco` (the owner's game), tim = Timing, rush = Rush).
Redrock eco/eco, Thornwood rush/eco and Redrock balloon/eco are the owner's three games (his seeds, the Crown in the
second slot); the others seed 11, 7 or 5.

| game | end | halls lost | halls at end | labourers lost | labourers 8:00 / end | gold by 8:00 | gold the 8th minute | army 6:00 (ours v Brood mobile) | army 8:00 | value killed / lost | first attack | Brood at our 2nd hall |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| rr_eco_eco before | 1000 | 1 | 3 | 20 | 39 / 29 | 7220 | 2280 | 380 v 625 | 1355 v 2855 | 2870 / 4195 | 0751 supply 21 knew 550 (seen 5 s ago) | 0857 |
| rr_eco_eco after | 1000 | 1 | 2 | 29 | 44 / 21 | 7220 | 1900 | 420 v 775 | 1105 v 1740 | 3785 / 2960 | - | 0826 |
| rr_bal_eco before | 1000 | 0 | 3 | 6 | 30 / 25 | 5320 | 760 | 785 v 525 | 1270 v 1975 | 2725 / 815 | - | 0749 |
| rr_bal_eco after | 1000 | 1 | 1 | 12 | 29 / 21 | 5320 | 1140 | 785 v 825 | 1010 v 2375 | 3970 / 2390 | - | 0854 |
| rr_bal_tim before | 1000 | 2 | 0 | 27 | 20 / 0 | 4560 | 760 | 480 v 850 | 935 v 1720 | 3270 / 4765 | - | 0616 |
| rr_bal_tim after | 1000 | 2 | 0 | 34 | 27 / 0 | 4560 | 1140 | 520 v 875 | 1030 v 2195 | 2320 / 5485 | - | 0613 |
| gh_eco_tim before | 1000 | 1 | 1 | 24 | 21 / 22 | 6080 | 760 | 480 v 500 | 1385 v 1040 | 4340 / 2200 | - | 0648 |
| gh_eco_tim after | 1000 | 1 | 2 | 29 | 25 / 20 | 6080 | 760 | 420 v 500 | 1415 v 1115 | 3490 / 2350 | - | 0643 |
| kr_eco_eco before | 1000 | 0 | 4 | 0 | 40 / 45 | 7220 | 2280 | 570 v 865 | 1550 v 3005 | 4925 / 955 | 0750 supply 20 knew 700 (seen 4 s ago) | - |
| kr_eco_eco after | 1000 | 0 | 4 | 4 | 41 / 41 | 7600 | 1900 | 380 v 890 | 1325 v 3420 | 400 / 785 | - | 0918 |
| tw_tim_eco before | 1000 | 0 | 2 | 0 | 19 / 19 | 4560 | 760 | 755 v 370 | 1985 v 2005 | 1045 / 1515 | 0721 supply 22 knew 700 (seen 8 s ago) | - |
| tw_tim_eco after | 1000 | 0 | 2 | 9 | 18 / 18 | 4560 | 760 | 825 v 190 | 2105 v 2245 | 2155 / 2665 | - | 0857 |
| tw_bal_rush before | 1000 | 0 | 2 | 6 | 27 / 35 | 4560 | 1140 | 640 v 225 | 955 v 870 | 1195 / 945 | - | 0815 |
| tw_bal_rush after | 1000 | 0 | 2 | 5 | 25 / 24 | 4560 | 1140 | 600 v 550 | 1050 v 690 | 1690 / 905 | - | 0636 |
| tw_rush_eco before | 0701 | 0 | 2 | 0 | - / 24 | -1 | - | 600 v 1050 | -1 v -1 | 250 / 0 | 0256 supply 9 knew 0 (seen never) | - |
| tw_rush_eco after | 0701 | 0 | 2 | 0 | - / 25 | -1 | - | 500 v 1425 | -1 v -1 | 175 / 0 | 0256 supply 9 knew 0 (seen never) | - |

Read:
- **No blind attack after**: before, three games sent a wave knowing 550-700 of a Brood army of 2,000-3,000 (Redrock
  Economy 7:51, Kestrel Rise Economy 7:50, Thornwood Timing 7:21); after, none went out without a fresh report and an
  edge over the reckoning ("the wave waits on the high ground: 1125 of army against the 2628 it reckons").
- **The walls stand**: after, every new hall's palisade went down in the first minutes ("lays 8 wall pieces at its new
  hall"); before, the Economy games laid none.
- **The outcome is about the same**: halls lost 4 before, 5 after; labourers lost 83 before, 122 after; value killed /
  lost 20,620 / 15,390 before, 17,985 / 17,540 after. The Crown's gold by 8:00 is the same (its farms pay in lumps), the
  Brood's 1.5-2.3 times it in the Economy, Balanced and Timing games and 1.0-1.3 times it after a Horseman rush.
- The Brood's Timing on Redrock (`rr_bal_tim`) takes the 2nd hall at 6:13-6:16 and the main by 10:00 before and after.

## 4. The Horseman rush, again

Rush plan against the Brood's Economy (`tools/play_crown_v_brood.gd coach:rush`). The owner's seed (Thornwood
2103718835) played four times ended FAILED at 3:31-3:34 every time (the Brood's rush evidence came first and it held its
Raptors at home), so other seeds:

| game | verdict | what followed | killed / lost at the end |
|---|---|---|---|
| Thornwood seed 31 | FAILED 3:32 | home | 325 / 0 (5:30) |
| Greenhold seed 31 (hunt 0.9) | SUCCEEDED 3:35 | hunted 8 s: the rooted Rootmaws and the Mother were counted as an answer | 575 / 345 (5:30) |
| Redrock seed 31 | FAILED 3:33 | home | 175 / 0 (5:30) |
| Kestrel Rise seed 31 (hunt 0.9) | SUCCEEDED 3:31 | hunted 13 s, same | 950 / 345 (5:30) |
| Greenhold seed 31 (final) | FAILED 3:40 | home | 350 / 0 (7:00) |
| Kestrel Rise seed 31 (final) | SUCCEEDED 3:34 | hunted 21 s, home on "a real answer: 214 of soldiers against its 165" | 900 / 230 (7:00) |

The hunt now goes on while the riders win and stops on a real answer; against the Hard Brood's Economy that answer
(Raptors laid at once on the rush evidence) comes within half a minute, so the gain over the old mop-up is small in these
games. In the owner's Thornwood seed (the rush judged FAILED, both before and after) the Brood had still earned only 1.0-1.3
times the Crown's gold by 8:00, against 1.5-2.3 times in every game without a rush: the owner's point, the riders at
its grubs are the Crown's strongest answer to the Brood's Economy.

## 5. The experiment: the natural's spot, A (by the ramp) or B (the corner pocket)

The owner (15:23): "For the Crown's optimal natural expansion, I think it could be near the corner of the map, away from
the ramp; ... the easier way to wall is there, using the edge of the map and the high ground as natural barriers; the
problem is that it is far away from the ramp. Is it better or worse?"

- **A** = today's rule (CrownSites v2: 18 tiles, by the ramp's foot, against the border).
- **B** = the CORNER POCKET (`CrownSites._corner`): any legal spot 18 to 34 tiles from the main, on our side by land,
  with room for its economy, scored for the shortest wall: 12 points an open side (`open_sides`), 1 a cell of its MOUTH
  (`CrownSites.mouth`: the open ground 9 tiles out that an army walks in through), 3 a tile from the border, only a
  quarter point a step of the walk from the main's ramp. Selected with `-- nat:corner` on the command line or the match
  cfg `"crown_nat": "corner"`; never a player setting; the default is A.

### 5.1 Measured on the bare map (`tools/measure_crown_corner.gd`)

"wall" = the cells the new hall's wall must close (AIExpandWall's plan: palisade + gates + building slots), "mouth" as
above, "musk" = a Musketeer's walk from the top of the main's ramp to the wall's gate, "foot" = steps from the ramp's foot
to the hall, "raptor" = the Brood Raptors' walk from their main to the nearest way in, "under" = the share of the last 20
tiles of that walk within musket reach of the main's cliff edge, "cover" = the share of the wall's cells within musket
reach of the main's cliff edge, and of the hall's own sides.

| map | variant | spot | tiles from main | wall cells | palisade | gates | building slots | open sides | mouth | musk (s) | foot (steps) | Raptors (s) | under the cliff | wall cover | hall cover | room |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| redrock_canyon | A | (30, 22) | 18.6 | 51 | 25 | 2 | 8 | 4 | 53 | 11 | 8 | 36 | 0% | 17% | 59% | 70% |
| redrock_canyon | B | (20, 2) | 19.9 | 30 | 5 | 2 | 8 | 3 | 20 | 10 | 39 | 45 | 80% | 13% | 59% | 44% |
| thornwood_maze | A | (25, 2) | 17.6 | 31 | 7 | 2 | 8 | 3 | 34 | 10 | 5 | 44 | 0% | 12% | 54% | 43% |
| thornwood_maze | B | (27, 2) | 19.4 | 32 | 7 | 2 | 8 | 3 | 25 | 11 | 5 | 43 | 0% | 12% | 36% | 49% |
| greenhold | A | (1, 24) | 18.6 | 34 | 8 | 2 | 8 | 3 | 21 | 11 | 9 | 39 | 0% | 14% | 40% | 44% |
| greenhold | B | (1, 24) | 18.6 | 34 | 8 | 2 | 8 | 3 | 21 | 11 | 9 | 39 | 0% | 14% | 40% | 44% |
| kestrel_rise | A | (1, 26) | 20.7 | 30 | 7 | 2 | 8 | 3 | 28 | 11 | 5 | 34 | 0% | 13% | 0% | 52% |
| kestrel_rise | B | (1, 26) | 20.7 | 30 | 7 | 2 | 8 | 3 | 28 | 11 | 5 | 34 | 0% | 13% | 0% | 52% |
| red_coast | A | (1, 25) | 19.5 | 34 | 7 | 2 | 8 | 3 | 22 | 8 | 9 | 39 | 0% | 14% | 31% | 46% |
| red_coast | B | (1, 25) | 19.5 | 34 | 7 | 2 | 8 | 3 | 22 | 8 | 9 | 39 | 0% | 14% | 31% | 46% |
| ashford_crossing | A | (2, 26) | 18.6 | 34 | 7 | 2 | 8 | 3 | 22 | 9 | 10 | 51 | 0% | 11% | 50% | 47% |
| ashford_crossing | B | (2, 26) | 18.6 | 34 | 7 | 2 | 8 | 3 | 22 | 9 | 10 | 51 | 0% | 11% | 50% | 47% |
| highmoor | A | (1, 24) | 18.6 | 34 | 8 | 2 | 8 | 3 | 21 | 11 | 9 | 39 | 0% | 14% | 40% | 44% |
| highmoor | B | (1, 24) | 18.6 | 34 | 8 | 2 | 8 | 3 | 21 | 11 | 9 | 39 | 0% | 14% | 40% | 44% |
| cinder_steps | A | (16, 23) | 17.8 | 69 | 44 | 2 | 8 | 4 | 33 | 19 | 9 | 27 | 0% | 13% | 45% | 69% |
| cinder_steps | B | (1, 29) | 21.7 | 30 | 5 | 2 | 8 | 3 | 28 | 11 | 5 | 32 | 0% | 13% | 0% | 52% |

So on six of the eight maps A is already a corner pocket (the v2 rule puts it against the border by the ramp): B picks the
same spot. B differs on **Redrock Canyon** (the main sits mid-top, no border near its ramp: A is in the open below the
ramp, 51 cells of wall and 4 open sides; B is the pocket between the top border and the main's west cliff: 30 cells, only
5 of them palisade, and 80% of the Raptors' last stretch passes under the main's cliff edge) and **Cinder Steps** (A: 69
cells, 44 palisade; B: 30 cells against the left border). On Thornwood Maze B sits two tiles over, the same wall.

The wall's hold against a wave: a palisade has 200 hit points and armour 2, the Gate 300; three Raptors (the most that fit
round one cell) at 6 damage every 0.9 s, 4 after the armour, break a palisade in about 15 s and the Gate in 23 s; a wave
breaks one piece, so what counts is how long the line has to be (how many pieces to keep mended) and whether the
Musketeers shoot the creatures at it: B on Redrock has 5 palisade instead of 25, but its cover from the main's cliff is
about the same (13% of the wall's cells v 17%; the hall's own sides 59% both).

### 5.2 Played (A and B, same maps and seeds)

The Economy plan (it lays its natural first, at 3:23) against the Brood's Rush, Timing and Economy, seed 21, 10:00, on the
two maps where B differs. One game each: the games part after a few minutes, so a single row is a hint, not a proof.

| game | end | halls lost | halls at end | labourers lost | labourers 8:00 / end | gold by 8:00 | gold the 8th minute | army 6:00 (ours v Brood mobile) | army 8:00 | value killed / lost | first attack | Brood at our 2nd hall |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| abA_cs_eco | 1000 | 0 | 3 | 0 | 40 / 43 | 7600 | 1900 | 360 v 1025 | 1255 v 2435 | 100 / 115 | - | - |
| abA_cs_rush | 1000 | 0 | 2 | 4 | 16 / 23 | 4180 | 1140 | 340 v 225 | 960 v 275 | 325 / 430 | - | 0326 |
| abA_cs_tim | 1000 | 1 | 1 | 41 | 19 / 0 | 5320 | 760 | 420 v 1360 | 780 v 1275 | 5640 / 4695 | - | 0555 |
| abA_rr_eco | 1000 | 1 | 1 | 18 | 25 / 22 | 6080 | 1140 | 240 v 250 | 855 v 1515 | 3615 / 2220 | - | 0733 |
| abA_rr_rush | 1000 | 0 | 2 | 8 | 18 / 23 | 3800 | 760 | 360 v 200 | 520 v 525 | 625 / 865 | - | 0953 |
| abA_rr_tim | 1000 | 2 | 1 | 37 | 28 / 0 | 5320 | 760 | 240 v 1230 | 665 v 1635 | 4250 / 5585 | - | 0606 |
| abB_cs_eco | 1000 | 0 | 4 | 0 | 40 / 46 | 6840 | 1520 | 360 v 1010 | 1365 v 2560 | 50 / 115 | - | - |
| abB_cs_rush | 1000 | 0 | 2 | 2 | 23 / 26 | 5320 | 1140 | 460 v 225 | 1560 v 225 | 975 / 260 | - | 0331 |
| abB_cs_tim | 1000 | 2 | 0 | 34 | 27 / 0 | 5320 | 380 | 420 v 1335 | 480 v 1680 | 4635 / 5435 | - | 0600 |
| abB_rr_eco | 1000 | 0 | 3 | 5 | 33 / 42 | 6460 | 2280 | 420 v 250 | 1190 v 690 | 1950 / 725 | - | 0813 |
| abB_rr_rush | 1000 | 0 | 3 | 18 | 17 / 8 | 3800 | 380 | 240 v 200 | 300 v 750 | 1150 / 1795 | - | - |
| abB_rr_tim | 1000 | 2 | 0 | 35 | 1 / 0 | 4560 | 380 | 420 v 1250 | 0 v 2445 | 1150 / 5045 | - | 0832 |

Read:
- **Redrock Economy**: B clearly better: no hall lost (A lost its natural at 7:33), 5 labourers lost against 18, 2,280 gold
  in the 8th minute against 1,140, value killed / lost 1,950 / 725 against 3,615 / 2,220; the Brood reached B's hall at
  8:13, A's at 7:33.
- **Cinder Steps Rush**: B better: 2 labourers lost against 4, 5,320 gold by 8:00 against 4,180, 975 killed for 260 lost
  against 325 for 430.
- **Timing (both maps)**: both lose everything by 10:00. On Redrock the Brood reached B's pocket only at 8:32 (A's natural
  6:06), but its wave went for the main instead and razed it at 8:05 (A's main stood till 9:29): with the natural tucked
  away, the main's ramp is the first thing in the way.
- **Redrock Rush, Cinder Steps Economy**: about even (B lost more labourers on Redrock's Rush, 18 v 8; the same on Cinder
  Steps' Economy).

### 5.3 Verdict

- **Maps where the ramp has no border near it (Redrock Canyon, Cinder Steps): B is better against the Brood's Economy and
  Rush.** Its wall is 30 cells instead of 51-69 (5 palisade instead of 25-44), with three open sides instead of four, the
  Raptors' way to it runs 80% under the main's cliff on Redrock, and the Musketeer's walk from the ramp's top is the same
  (10-11 s, against 8-19 s for A). In the games: no hall lost, a third of the labourers lost, twice the gold in the 8th
  minute on Redrock's Economy; more gold and a better trade on Cinder Steps' Rush.
- **Against the Brood's Timing B does not save the game**: both lose everything by 10:00, and with B the main was razed
  first (8:05 on Redrock against 9:29 with A): the natural at A takes the first blow and buys the main time; tucked away,
  it leaves the main's ramp as the front door. The Timing wave (25 supply at 5:43) beats the Economy plan's army either way.
- **Maps where A is already against the border by the ramp (Greenhold, Red Coast, Kestrel Rise, Ashford Crossing,
  Highmoor, and Thornwood Maze two tiles apart): no difference**, B picks the same spot.
- **Proposal, a combined rule (the owner decides; the default is still A)**: take B when its wall is at most half of A's
  (wall cells) and the Musketeer's walk from the ramp's top to B's gate is no more than 4 s longer than to A's; else A.
  On the eight maps measured that is B on Redrock Canyon and Cinder Steps only. A second idea to test: against a scouted
  Brood Timing (the scout's "rush" or "timing" verdict) keep A, the shield in front of the main.

## 6. Tests

- `tools/test_crown_v_brood.gd` (new): the ramp wall closes the ramp on 5 maps (Raptors kept out, a Labourer gets out
  through the gate; 8 maps when named on the command line); no attack without a fresh scout report and the reckoning is
  never 0; the rush keeps raiding while ahead and goes home when beaten down (against the Crown: the shared mop-up); RANDOM
  PLAN against the Brood never picks the Balloon harass in 2,000 picks; a hall with no wall plan is asked again only every
  30 s, quietly.
- Still passing: `tools/test_crown_build_order.gd`, `test_crown_siege.gd`, `test_crown_balloon.gd`,
  `test_crown_dragoon_raid.gd`, `test_expansion_spots.gd`, `test_cottage_wall_plan.gd` (all PASS on this branch except test_crown_dragoon_raid's long [plan] check, see section 7; its quick checks [table], [strike], [leave], [others] pass).
- Tools: `tools/play_crown_v_brood.gd` (coached games and their summary), `tools/measure_crown_corner.gd` (A/B on the
  bare map), `tools/shot_crown_corner.gd` (the A/B pictures).

## 7. Open questions and proposals (the owner decides)

Open questions:
- **The income gap**: by 8:00 the Hard Brood had earned 1.5-2.3 times the Crown's gold in every game without a Horseman
  rush, before and after; the Crown's gold came in the same lumps in both (its farms pay per harvest). The AI fixes here
  stop the bad decisions (blind waves, walls never laid, riders going home winning) but do not close that gap; the owner
  keeps the Brood's FOOD_BONUS for now. What the Crown computer does best against the Brood's Economy in these games is
  the Horseman rush (the Brood earned only 1.0-1.3 times the Crown's after it).
- **The ramp post's BEAT against the Brood (2.0)**: with it the line stays up while 13 Raptors (325) eat the natural's
  farms and Cottages below (Greenhold 6:28, 585 at home). The walls now help; 1.5 behind a closed natural wall is worth a
  try.
- **The reckoning table** (BROOD_TABLE) was fitted to the Hard Brood of these games; a Normal or Easy Brood has less,
  so the Crown would wait more than it needs against them (the rule is on for Normal and up).
- **test_crown_dragoon_raid [plan]**: DRAGOON_LINE
- **Corner pocket against the Timing**: B moved the Brood's first blow from the natural to the main on Redrock; one game,
  worth more seeds before the owner's call.

Proposals (balance, not changed here; design_principles.md 1 and 2):
- Make the Crown's farms pay smaller and more often (same total): the lumps make every early reserve wait a harvest.
- A palisade next to a Cottage could share the Cottage's armour (1) only while joined, so a closed Crown line is worth a
  little more than its pieces against claws; the Brood's Spitters and Tyrant Challengers still break it.
