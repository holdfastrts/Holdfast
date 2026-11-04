# Balloon harass: the Crown computer's balloon plan (branch crown-builds-c)

The owner (2026-11-03): "Dragoon raids are one thing, balloon harass is another." A separate Crown computer plan,
BALLOON HARASS (pt "Assédio de balões", es "Acoso con globos"): Observation Balloons from the Foundry carry Musketeers over
cliffs and water to strike where the enemy isn't (its workers, the Clockwork's Mainspring and Winders, the Brood's grubs,
Rootmaws and the Mother's nest), several small strikes at different places at once, the balloons' sight used to scout,
the main army holding at home meanwhile. Pick it as a Crown computer's plan (the RANDOM PLAN may pick it too).

Pictures: `docs/shots/crown_builds_c/` (captions in its `captions.md`).

## 1. How it is built

- `scripts/ai_crown_balloon.gd` (AICrownBalloon, a helper like the Clockwork's `ai_springer_raid.gd`): everything the
  harass does. Made by AICrown only on this plan, Normal and up (`AICrown.bl`).
- `scripts/ai_crown.gd`: the plan `PLANS["balloon"]` and a small self-contained block at the end of the file
  (`_balloon_drop` gives way to the harass, `_on_errand` keeps the army's orders off the parties, `_bl_step` the
  "balloons" step). Four one-line hooks at the top of `_st_text`, `_st_done`, `_st_price` and `_st_do` for the new
  "balloons" step, one line in the opening's think (stage 2) and one in `_army_due` (the men in the baskets count). The
  Dragoon (crown-builds-a) and siege (crown-builds-b) jobs add plans to the same file: their plans go next to this one in
  PLANS; the hooks are the only lines in shared functions.
- `scripts/ai.gd`: `STRATEGIES["balloon"]` (name "Balloon harass", `crown_only`) and the `crown_only` test in
  `strategies_for` (the other Crown jobs will want the same two lines: keep one copy at merge).
- `tools/i18n/52_balloon_harass.txt`: the name in pt/es.
- The plan selector's tooltip (main.gd, multiplayer_menu.gd) still says "others play Balanced": left alone here so the
  three Crown branches don't fight over one line; worth rewording at merge ("... Balloon harass is Crown only").

## 2. The build order (triggers, never the clock)

Balanced's safe Musketeer opening with the Foundry where Balanced puts its Horse Breeder. Times are what round B showed on
Hard (8 games), to read the order by, not rules.

| step | trigger | (when) |
|---|---|---|
| the ramp Cottage | 5 supply | 0:00 |
| the ramp Gate | 5 supply | 0:22 |
| the Barracks and the Powder Mill | 7 labourers | 0:42 |
| Musketeers from now on, up to 8 supply | - | the first ~2:05 |
| the second Farm | 9 labourers | 1:49-2:03 |
| the Foundry | 13 labourers | 3:32-3:45 |
| the first balloon | the Foundry stands | rigged 4:29-5:10, out 4:54-5:35 |
| Musketeers again, up to 14 supply | - | with it |
| the second Town Hall | 15 labourers | 5:08-5:45 |
| the second balloon | the Foundry stands | 5:35-6:00 |

Then Balanced's milestones (the second Barracks at 19 labourers, the Breeder at 17, the Armoury at 26, the third Barracks
at 30, the Church at 36 with two halls, a second Foundry at 44 with three) and Balanced's waves (first at 18 supply); the
ramp post on HOLD, the rider scouts and every shared rule play on. A third balloon on two halls with 26 labourers.

## 3. What a party does (scripts/ai_crown_balloon.gd)

- **A party** is a balloon and 3-4 Musketeers from home. It never takes the last 2 Musketeers (5 against the Brood: its
  Timing attack comes at 5:45-6:30). The men walk to an open spot by the hall the balloon hovers over, climb in, and the
  party flies.
- **Targets** are the enemy's economy as our side has seen it: workers seen lately (grubs, Winders, Labourers), Rootmaws,
  the Mother, the Mainspring (rated highest), Cog Presses, Clocktowers, Farms and Mills; with little seen yet, the
  enemy's start and four points on the flanks of its main. Each is rated by the workers seen there (up to 5), against the
  anti-air and the enemy army seen near it and on the way, the distance, a spot struck in the last 100 s, a spot where
  anti-air chased a party off in the last 150 s, and **another party's target** (within 200 px: -60, within 650: -25).
  So two balloons go to two places (picture 03/04: one over the main's Cog Presses, one over the new Clocktower).
- **Anti-air** is remembered where it was seen: anything that can hit a flyer (Swift, Springer, Ratchet Turret, Netter,
  Skywing, Hatchlings, Storm and Venom Challengers and Sires, Musketeers, a cannon on canister), 75 s for a unit, a turret
  till seen gone. The flight goes round it (one waypoint to the side with the least on the way). A party **backs off**
  (flies away from it, toward home, then picks again) when the anti-air near it is worth more than the party (balloon +
  men by their health): a lone Swift or two Skywings it fights, the basket shoots them down.
- **Over the target**, no anti-air near: it **hovers and the basket fires** (Musketeers aboard reach 35% further and
  refill from the balloon's store). The basket shoots the NEAREST enemy, so the balloon hovers right over a worker on the
  side away from anything else (the Mother, a rooted creature, a soldier): round A's first hover sat over the Mother and
  emptied the store into her 2,400 hit points. Nothing in sight: it moves to the workers seen lately nearby; nothing for
  14 s, or 90 s there, or the shots low: the next target.
- Some anti-air near the target but less than the party, and no army within 520 px worth 0.6 of it: it **drops** the men
  on open ground by the workers, on the side away from the anti-air, pulls back out of its reach, and **lifts them out**
  when the defence comes (armed ground enemies worth more than the men), half are hurt, the prey is gone or after 40 s.
  Too much anti-air and an army there: it backs off.
- **Home**: the store under 75% or the balloon under 45% health: home to RESTOCK (the pilot hauls kegs at the Mill, the
  Barracks or the hall); a hurt balloon lets its men off and waits.
- **Defence from the air**: an attack at home worth 180+ (seen) brings a loaded party within 45 tiles, and a big one
  (more than the army at home) brings every loaded party back from anywhere: it hovers over the attackers behind our line
  and the basket fires down (picture 05). Against the Brood this is where most of the harass's kills come from: Raptors,
  Tyrant Challengers and the Rootmaws can't hit a balloon.
- **Scouting**: every flight is a look at the enemy's land (14 tiles of sight), and a balloon with no men to carry
  floats out two thirds of the way to the enemy, off the line with the least anti-air, to watch.
- Fair: it sees only what our side sees (`Game.side_sees`), knows where the enemy started (every computer does); a balloon
  is slow (46), big and seen from far.

## 4. The coached games

`tools/play_crown_c.gd` (it extends `tools/play_crown_1.gd`: everything it films and writes) adds the parties: the first
party forming, the first two flights, the first three strikes (and a clip of the first), drops and lifts, two parties at
two places at once, the defence from the air, a balloon shot down, and `harass.txt` (the numbers, a line a minute, the
log). `tools/play_crown_c_table.py` makes the tables. The comparison games are the same tool on the Balanced plan
(`coach:balanced`), the same opponents, maps and seeds. I looked at the pictures of every game.

The games (side 0 the Crown computer, side 1 the opponent on Hard, 13 minutes):

| game | against (Hard) | map, seed |
|---|---|---|
| 01 | Brood Timing attack | Red Coast 4291306512 (the owner's seed) |
| 02 | Clockwork Balanced | Highmoor 5 |
| 03 | Brood Balanced | Frostfang 3 |
| 04 | Clockwork Timing attack | Ashfall 7 |
| 05 | Brood Economy | Mirewood 3 (rivers) |
| 06 | Clockwork Rush | Red Coast 7 |
| 07 | Brood Rush | Greenhold 3 |
| 08 | Clockwork Economy | Twin Fords 11 (rivers) |

### Round A (the first draft: the Foundry at 10 labourers, Musketeers held at 6 supply until the first balloon)

| game | result | labourers 4/6/8 | gold a minute 6/8 | army 6/8 | enemy army 8 | 2nd hall | killed / lost | first strike | first kill | harass killed (workers) | strikes / drops / lifts | balloons + men lost |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| a01 | L 11:50 | 12/17/0 | 760/0 | 545/590 | 4115 | 05:11 | 1575 / 3650 | 6:20 | 6:21 | 550 (5) | 1 / 0 / 0 | 0+0 |
| a02 | alive 13:00 | 12/15/18 | 760/1140 | 605/1155 | 1460 | 05:06 | 4570 / 1895 | 5:25 | 5:26 | 780 (13) | 4 / 0 / 0 | 1+0 |
| a03 | L 10:48 | 12/17/14 | 760/760 | 545/710 | 3590 | 05:13 | 2675 / 3490 | 6:11 | 6:20 | 2200 (15) | 1 / 0 / 0 | 0+0 |
| a04 | alive 13:00 | 13/16/22 | 760/760 | 605/1305 | 2240 | 05:13 | 2620 / 895 | 5:16 | 5:32 | 1140 (19) | 4 / 1 / 1 | 1+2 |
| a05 | L 10:23 | 12/17/24 | 760/1140 | 610/1190 | 5400 | 05:09 | 2525 / 5305 | 5:57 | 6:06 | 1100 (22) | 3 / 0 / 0 | 0+0 |
| a06 | alive 13:00 | 13/17/26 | 1140/1140 | 605/1335 | 1120 | 07:01 | 4540 / 175 | 5:16 | 5:19 | 2520 (42) | 5 / 0 / 0 | 0+0 |

What the films showed, and what changed:

1. **Every Brood main fell** (a01 11:50, a03 10:48, a05 10:23) where Balanced lives to 13:00 on the same seeds (c01, c03,
   c05 below). The Foundry at 10 labourers and the balloon's 125 gold took two labourers and a third of the gold at 6:00
   (12/17 labourers against Balanced's 14/19, 760 gold a minute against 1,140), and the two parties took eight of the
   line's Musketeers away when the Brood's Timing attack came at 5:45-6:30, 80-100 tiles from home. **Fix**: the Foundry
   at 13 labourers (Balanced's Breeder spot), 8 supply of Musketeers before it; five Musketeers kept at home against the
   Brood; a big attack calls every loaded party home.
2. **The parties defended forever** (a01, r-games): any enemy by a building (a scouting Raptor) counted as an attack.
   **Fix**: an attack worth 180 or more seen.
3. **Turning back into the anti-air** (a02, 6:42-6:58: "turns back", the next target 14 tiles away, again, four times in
   two seconds, then shot down). **Fix**: the party backs off first (away from the anti-air, toward home, 7 s), the spot is
   rated down for 150 s, and the anti-air on the way counts in the rating.
4. **The first hover emptied the basket into the Brood Mother** (test bed): the basket shoots the nearest enemy.
   **Fix**: the hover spot is right over a worker, away from anything else (section 3).
5. **The first party could not board** (a01, a03: "too few aboard" after 40 s; picture: the balloon over a spot of the
   ramp the men did not reach). **Fix**: a boarding spot on ground the men can walk to (the hall's walkable region), the
   men told to board once the balloon is down there.
6. **Against the Clockwork it worked from the start**: a06 killed 4,540 for 175 (42 Winders, picture 02: the basket over
   the Cog Press, its 5 Winders), a02 4,570 / 1,895.

### Round B (the round A fixes)

| game | result | labourers 4/6/8 | gold a minute 6/8 | army 6/8 | enemy army 8 | 2nd hall | killed / lost | first strike | first kill | harass killed (workers) | strikes / drops / lifts | balloons + men lost |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| b01 | alive 13:00 | 15/21/28 | 760/1140 | 785/1250 | 3500 | 05:22 | 6100 / 4845 | 6:11 | 6:14 | 3100 (23) | 4 / 0 / 0 | 0+0 |
| b02 | alive 13:00 | 13/15/19 | 380/760 | 665/1090 | 2030 | 05:09 | 5170 / 215 | 6:08 | 6:08 | 1560 (26) | 12 / 0 / 0 | 0+0 |
| b03 | alive 13:00 | 15/20/21 | 1140/1140 | 785/1270 | 3570 | 05:18 | 12270 / 2435 | 6:39 | 6:44 | 2855 (3) | 2 / 0 / 0 | 0+0 |
| b04 | alive 13:00 | 13/15/19 | 760/760 | 665/1150 | 1960 | 05:11 | 4920 / 425 | 6:10 | 6:14 | 2720 (36) | 5 / 0 / 0 | 0+0 |
| b05 | alive 13:00 | 15/21/30 | 760/1900 | 785/1525 | 4850 | 05:21 | 7365 / 7965 | 6:14 | 6:22 | 2050 (27) | 2 / 0 / 0 | 2+4 |
| b06 | alive 13:00 | 13/16/21 | 760/1140 | 725/740 | 915 | 05:45 | 3765 / 2255 | 7:01 | 7:14 | 120 (2) | 2 / 1 / 1 | 2+1 |
| b07 | alive 13:00 | 13/18/22 | 1140/1520 | 785/1245 | 1475 | 05:35 | 3050 / 50 | 6:47 | 5:41 | 1175 (22) | 5 / 0 / 0 | 0+0 |
| b08 | alive 13:00 | 13/15/16 | 760/760 | 665/855 | 1820 | 05:08 | 5675 / 1535 | 6:15 | 7:50 | 1320 (22) | 4 / 1 / 1 | 1+4 |

Every game alive at 13:00, the Brood games too (a01, a03, a05 had fallen). Against the Brood the trade went from 1,575 /
3,650 to 6,100 / 4,845 on the owner's seed (b01), 12,270 / 2,435 on Frostfang (b03: most of it from the baskets over the
ramp, picture 05).

What it still showed, and what changed:

1. **The army the size of the economy did not see the men in the baskets** (`Game.army` leaves out men aboard): the plan
   trained soldiers before labourers (b02, b08: 15 labourers at 6:00, 16-19 at 8:00, against Balanced's 21-22 and 34).
   **Fix**: `AICrownBalloon.aboard_supply()` counts in `_army_due`.
2. **A drop in the middle of a Clockwork army** (b06 6:53, picture 09: the men set down by the Cog Press with 20 Clock
   Soldiers 300 px away, a Netter's net on the balloon; it was shot down 20 s later). **Fix**: a drop only with no army
   worth 0.6 of the party within 520 px; too much anti-air and an army there: it backs off.

### Round B again on the final code (d) and a variant that was dropped (e)

| game | result | labourers 4/6/8 | gold a minute 6/8 | army 6/8 | enemy army 8 | 2nd hall | killed / lost | first strike | first kill | harass killed (workers) | strikes / drops / lifts | balloons + men lost |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| d01 | alive 13:00 | 15/20/24 | 760/1520 | 785/1530 | 2775 | 05:24 | 8055 / 4650 | 6:32 | 6:41 | 1915 (14) | 4 / 0 / 0 | 0+0 |
| d02 | alive 13:00 | 13/14/19 | 760/1140 | 665/850 | 1730 | 05:05 | 3130 / 2160 | 12:13 | 6:42 | 915 (6) | 1 / 0 / 0 | 2+3 |
| d06 | alive 13:00 | 13/16/25 | 760/1140 | 785/1125 | 1260 | 05:46 | 6275 / 220 | 6:50 | 6:58 | 1800 (30) | 5 / 0 / 0 | 0+0 |
| d08 | alive 13:00 | 13/15/21 | 760/760 | 665/950 | 2030 | 05:09 | 4790 / 50 | 6:08 | 6:11 | 1800 (30) | 14 / 0 / 0 | 0+0 |
| e01 | L 10:23 | 15/17/20 | 380/1140 | 605/705 | 3060 | 04:59 | 4460 / 4510 | 5:58 | 6:11 | 1005 (2) | 1 / 0 / 0 | 0+0 |
| e02 | alive 13:00 | 13/15/19 | 760/760 | 665/580 | 1590 | 05:05 | 3690 / 2575 | 6:09 | 6:13 | 300 (5) | 1 / 0 / 0 | 1+0 |
| e03 | L 9:29 | 15/20/9 | 760/380 | 785/445 | 4645 | 05:22 | 2125 / 4095 | 6:10 | 6:14 | 1175 (7) | 1 / 0 / 0 | 0+0 |
| e08 | alive 13:00 | 13/15/24 | 760/760 | 665/1090 | 1640 | 05:12 | 4845 / 1435 | 6:08 | 6:09 | 960 (16) | 2 / 0 / 0 | 1+4 |

- d01/d02/d06/d08 replay b01/b02/b06/b08 with both fixes: d06 traded 6,275 for 220 (b06 3,765 / 2,255: no balloon lost
  now), d08 4,790 for 50, d01 8,055 / 4,650 on the owner's seed. The labourers against the Clockwork barely moved
  (13/15-16/19-25): the cost is the Foundry and the balloons themselves (section 6, open question 1).
- **e** tried the second balloon at 20 labourers instead of in the opening: no more labourers (15 at 6:00 again), and
  both Brood games fell (e01 10:23, e03 9:29) without the second basket over the ramp. Reverted.

### The Balanced plan on the same games (the comparison)

| game | result | labourers 4/6/8 | gold a minute 6/8 | army 6/8 | enemy army 8 | 2nd hall | killed / lost |
|---|---|---|---|---|---|---|---|
| c01 | alive 13:00 | 14/19/24 | 1140/1140 | 675/890 | 4015 | 05:04 | 7265 / 7530 |
| c02 | alive 13:00 | 14/21/34 | 1140/1900 | 655/1165 | 2370 | 05:02 | 7645 / 2100 |
| c03 | alive 13:00 | 14/19/20 | 1140/1140 | 675/995 | 3480 | 05:02 | 9240 / 7295 |
| c04 | alive 13:00 | 14/21/39 | 1140/1520 | 655/1115 | 2240 | 05:04 | 3615 / 3090 |
| c05 | alive 13:00 | 14/19/32 | 760/1520 | 675/1055 | 4950 | 05:04 | 6050 / 7985 |
| c06 | alive 13:00 | 14/15/30 | 1140/760 | 635/1200 | 1935 | 05:04 | 3485 / 2420 |
| c07 | alive 13:00 | 14/18/23 | 760/760 | 635/990 | 1850 | 04:57 | 4465 / 2225 |
| c08 | alive 13:00 | 14/22/34 | 1140/1520 | 655/1110 | 2170 | 05:02 | 7975 / 1445 |

## 5. The numbers, Balloon harass (round B) against Balanced

| | Balloon harass (b01-b08) | Balanced (c01-c08) |
|---|---|---|
| results at 13:00 | all 8 alive (round A: 3 of 6 lost) | all 8 alive |
| value killed / lost, all 8 games | 48,315 / 19,725 (2.45 to 1) | 49,740 / 34,090 (1.46 to 1) |
| ... against the Brood (01, 03, 05, 07) | 28,785 / 15,295 | 27,020 / 25,035 |
| ... against the Clockwork (02, 04, 06, 08) | 19,530 / 4,430 | 22,720 / 9,055 |
| labourers at 4 / 6 / 8 min (average) | 13.8 / 17.6 / 22.0 | 14.0 / 19.3 / 29.5 |
| gold a minute at 6 / 8 (average) | 810 / 1,140 | 1,045 / 1,280 |
| army value at 6 / 8 (average) (the balloons and the men aboard count) | 732 / 1,141 | 657 / 1,065 |
| the first balloon out | 4:54-5:35 | - |
| the first strike (basket fire at a target, or men down) | 6:08-7:01 | - |
| the first kill by the harass | 5:41-7:50 (b07's first kill was in the defence) | - |
| killed by the harass itself | 120-3,100 a game, 14,900 in all (161 workers) | - |
| balloons lost | 0-2 a game, 5 in all (3 against the Clockwork, b06 and b08; 2 late in b05 against the Brood, 11:20 and 11:43) | - |

Read:
- **It trades far better** than Balanced, against both factions, and against the Clockwork it kills a Winder line again and
  again for almost nothing (b04 36 Winders, d06 and d08 30 each).
- **It costs the economy**: 7.5 fewer labourers at 8:00, about a fifth less gold a minute at 6:00 and a tenth at 8:00. The Foundry (200), two balloons (250 +
  40 powder) and eight Musketeers out of the line are the price; Balanced spends that on its Breeder and labourers.
- **Against the Brood the balloons are the defence as much as the harass**: a loaded basket over the ramp fires down on
  Raptors and Challengers that can't answer; b03's 12,270 killed came mostly from there.

## 6. Open questions (for the owner)

1. **The economy against the Clockwork.** 19-25 labourers at 8:00 against Balanced's 30-39 on the same games. Part of it
   is the price (the Foundry, two balloons), part may be the shared rules that weigh the army at home (`army_short`, the
   army minimum by the clock in `ai.gd` count `Game.army`, which leaves out men aboard): they too hold labourers back while
   eight Musketeers are in the air. I left the shared code alone (the parallel jobs touch it); should the plan count its
   baskets there too?
2. **The Brood has few answers early.** Nothing on the ground hits a balloon; its anti-air is the Skywing, Hatchlings, the
   Storm and Venom Challengers and Sires. In these games the Brood computer did not build them against the balloons (b05 lost its
   two only at 11:20 and 11:43). The harass plan is fair by design_principles 1 only if the Brood computer answers it:
   worth a rule in the Brood AI (scouted balloons -> Skywings or a Storm Sire)?
3. **Drops are rare** (2 drops in round B): the anti-air that makes a drop worth it usually comes with an army. Hovering is
   the stronger play. Should the plan drop on purpose to kill buildings (the Mainspring) with the men on the ground?
   Dropped Musketeers do little to buildings, so I kept it to workers.
4. **The second balloon against the Brood is the ramp's defence.** Should the plan against the Brood keep one basket at
   home on HOLD over the ramp, and harass with the other?
5. **The tooltip** of the plan selector still says only Air rush, Extreme rush and Springer timing are faction-only.

## 7. Proposals (balance: not changed here, the owner decides; design_principles.md 1 and 2)

1. **The basket against the Brood**: a hovering balloon of four Musketeers is untouchable by everything the Brood has
   before its fliers (b03: 12,270 killed for 2,435). If the owner's games show the same, either a ground answer for the
   Brood (the Spitters' acid reaching a low-hovering balloon, or a Rootmaw's spit at flyers over its own swamp), or a
   smaller basket range bonus (35% -> 20%) would keep it a strong harass but not a free one (soft counters before hard).
2. **Telegraph**: a balloon is slow and big, but a computer with no anti-air has nowhere to go. A Brood "warning" when a
   balloon crosses its swamp (like the gate alarm) would give the human player the reaction time the rule asks for.
3. **Lifting out is slow** (the balloon must hover over open ground the men walk to): a man reaching the rope 60 px out
   instead of 42 (Defs.DROPSHIP board) would make drop-and-lift a real tactic for players, not only for the computer.

## 8. Tests

- `tools/test_crown_balloon.gd` (new): the plan is a Crown-only strategy with its name; the harass is made only on it;
  a party forms and boards; five Musketeers stay home against the Brood; the army's orders leave the parties alone; a
  strike within 150 s kills grubs; two parties go to two targets; six Skywings at the target: no hover over them, no
  balloon lost; Balanced has no harass. All pass.
- `tools/test_crown_build_order.gd`: still passes (the "balloons" step added to its list of known steps).
- Boot: `godot --headless --quit-after 300` prints no script or parse error.

## 9. Play it again

    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_crown_c.gd -- \
        coach:balloon b:brood sb:timing map:red_coast seed:4291306512 out:/abs/dir end:780
    python3 -I tools/play_crown_c_table.py /abs/dir1 /abs/dir2 ...       # the table
    godot --headless --fixed-fps 30 --script res://tools/test_crown_balloon.gd [-- trace]
