# The Clockwork fights as one army (branch clockwork-army)

Short sentences, to be read aloud.

The owner, 2026-11-05 at 09:24, watching the Hard Clockwork on Economy against the Hard Brood on Economy, Frostfang, 0.31.0
(his log: docs/playtests/2026-11-05/spectate_clockwork_econ_v_brood_econ_frostfang_0310.txt, his picture:
clockwork_army_split_0638.jpg): "I think the Clockwork played mostly well, but it could have started massing army a bit
sooner. What really troubled me is that it kept sending 1 or 2 Clock Soldiers to die instead of using the Pendulum and
Springers it had. Most of the time the army has to be together; I don't understand why the Clockwork behaved like that.
It should have massed the army with Winders to repair and wind and squashed the Brood; it could have done that."

No unit, building or research number was changed. Ideas for numbers are proposals at the end.

## The short version

- **What was wrong.** The Clockwork computer had no army of its own. The shared army rules split it over the scout, the
  harass, the guard at the Winders, the one-or-two-at-a-time answers to each raid and a rally at the main; new units
  stayed where they were made; the Winders followed the empty middle of all that, and ran from a fight like any worker.
- **One army.** Now every Clockwork fighter belongs to one army (a plan's own raids aside). It waits together in front of
  the Clocktower nearest the enemy, with its Winders. A raid is met by a group big enough to win, or by the whole army.
  No fighter scouts.
- **It goes out as one block.** Every Clockwork plan now attacks with the Pendulum plan's PUSH: one block at the pace of
  its slowest unit, Winders behind the front and staying with it, fresh units joining as a group, pulling back as one.
- **Only when it is stronger.** It goes out only worth 1.25 times the enemy army it reckons (unknown never counts as
  nothing), with a fresh scout report, and after a failed push only bigger than that one.
- **The kit.** The Springers jump in to shooting range when the front engages. On Economy and Balanced the army grows
  from the moment the second Clocktower's presses are laid.
- **The result** (28 coached games before and 28 after, Hard against Hard, four maps, against the Brood and the Crown):
  fighters fighting alone fell from 9.4 to 4.4 a game (away from its buildings: 5.9 to 2.6), fresh units fighting alone
  first from 1.4 to 0.6 a game, the Winders by the army out from 3.2 to 4.2. The army was 10% bigger at 6:00 and 8:00 and
  8% bigger at 10:00; it lost about 11% less (2,518 against 2,834 by 10:00) and killed about 5% more. No Clockwork base fell
  (before: 2 games ended with no Clocktower left).

## What was wrong

The Clockwork computer had no army of its own. It used the shared computer's army rules (scripts/ai.gd, AI._army), and
those split the army over half a dozen jobs, each taking a unit or two:

- **The scout.** From its second trip with nothing seen, the shared scout takes the fastest idle army unit. For the
  Clockwork that was a Clock Soldier: "sends a Clock Soldier to scout again (trip 3)" at 5:08 in the owner's game. It
  walked alone into the Brood's Raptors.
- **The harass.** A soldier found out alone far from home becomes a harasser (AIHarass.adopt_strays). The Clock Soldier
  was the one exception the shared rule kept as a harasser, so a stray Clock Soldier went on alone at the enemy's workers.
- **The round-5 guard.** Riders at the Winders draw three to eight Clock Soldiers "to the Winders the riders hit" (5:36),
  and with ten soldiers a few hold the ramp. Those groups stood away from the rest.
- **The detachments.** Each raid on a building got "as many soldiers as the visible enemy needs", and a lone fast raider
  (a Raptor pair) up to four catchers on a leash. In practice one or two at a time ran out, chased, came back, ran out.
- **The rally.** What was left waited in front of the main hall, not the forward Clocktower. The Springers, the Netter and
  the Pendulum came out of the Works and Heavy Works where they were made. The owner's picture at 6:38 shows exactly that:
  the Pendulum and Springers by the second base's Works, a few soldiers by the main, Winders fighting riders alone.
- **The waves.** The shared attack sends a wave once it reaches a supply number, and fresh units join it "as a group of 6
  supply": three Clock Soldiers walking across the map to wherever the wave is, fighting what they meet on the way.
- **The escort.** The Winders that wind and mend the army followed the middle of ALL the army, which, split like this, was
  an empty spot between the groups. And a Winder near an enemy ran home like any raided worker (only against a swarm did
  it stay). In the Heavy Works push the Winders by the army were 0.5 on average.
- **No massing.** On Economy the opening's soldiers came only at its last steps (the first at 4:20, five at 5:00).

What the old code did, measured in the coached "before" games below: on average 9.6 times a game a Clockwork fighter fought
with no other fighter of its own within 6 tiles (6.0 of them away from its buildings), and 1.6 fresh units a game had
their first fight alone, away from home.

## The fixes

### One army (scripts/ai_cw_army.gd)

The Clockwork computer (Normal and up, gear mode) now keeps ONE ARMY. Every combat unit belongs to it, except the units a
plan sends on its own errand (the Springer raid, the Clock Soldier rush, the Owl raids). The shared scout, harass, round-5
guard, detachments and rally no longer take any of it.

- **One gathering point.** At home the army stands together in front of the Clocktower nearest the enemy (on that
  Clocktower's ground, the way in). Every unit made walks there. The escort Winders keep it wound and mended there.
- **Raids are met by a group or by the whole army.** An armed raid worth little next to the army is met by the nearest
  units worth 1.5 times the raid, never fewer than three. A raid worth 45% of the army or more is met by the whole army; the
  ones ahead of the rest wait for them on the way; one led off after a runner comes back to the others. When the raid is
  over, or when a defender is led 16 tiles from the buildings, they walk back to the gathering point. If the whole army is
  worth less than 55% of a raid away from the main, it does not walk into it: it holds together at the main's gate.
  Unarmed scouts and loose workers are left to the Winders and the turrets.
- **Reinforcements** made at a Works far from the gathering point walk to it straight away (a muster in the main, where
  they would wait and walk in threes, was tried and measured worse: see "Reading the numbers"; it is off).
- **No fighter scouts.** The scout's second and later trips take a Swift if there is one, else a Winder, never a ground
  fighter.

### It goes out as one block: the push for every plan (scripts/ai_cw_push.gd)

The Pendulum and Heavy Works plans already had a good way to move an army: THE PUSH. One anchor point walks along the path
a step at a time, only when the front is at it and the slow machines are close behind, so the block moves at the pace of
its slowest unit. The front (Clock Soldiers, Pendulums, Springers, Netters) stands in a line at the anchor; the Ballistas
and the Great Winder behind; the escort Winders behind the front. It fights as a line, sieges a wall, pulls back as one,
and fresh units join it as a group walking to the anchor.

Now every Clockwork plan attacks with it: Economy, Balanced, and the Springer timing and Clock Soldier rush after their
openings. Small fixes to the push with it:

- the escort Winders out with the army stay with it in a fight, winding and mending, instead of running home like a
  raided worker (AIClockwork._escort_stays);
- a Spring Ballista led more than 12 tiles from the anchor in a fight walks back behind the block;
- against the Crown, a push without Ballistas goes up to the enemy's main only once it is worth 2,000; until then it holds
  short of the main and kills what is outside (14 Clock Soldiers stood under a Crown main's cliff for two minutes in the
  first test game and lost 1,400);
- the push's own units no longer include the units of the other plans' errands.

### It goes out only stronger than the enemy it knows

Before a push goes out the army's word is asked (AICwArmy.may_launch):

- **The reckoning.** The enemy army it reckons is what it saw in the last two minutes, but never less than an enemy of that
  age has (a table per faction, from the coached games: for the Brood the Crown's crown-v-brood table, raised before 7:00),
  less half of what it has killed. Unknown never counts as nothing. Against the Brood the rooted Rootmaws and Mound Turtles
  it has seen count too, one and a half times: the push's goals are those, and rooted they fight hard.
- **Stronger.** It goes only worth 1.25 times the reckoning (the Pendulum and Heavy Works plans, which have their own
  needs, 1.0 times).
- **A fresh report.** It goes only if an enemy soldier was in sight, or the enemy's main was looked at, in the last 75 s.
  Otherwise it asks the scout to go now and holds.
- **After a failed push.** A push that had to pull back is news too: the next one goes only worth 1.25 times what that one
  had.
- Not while the army at home is busy with a raid, and not into a big swarm before the Pendulums are out (the swarm rule).

Meanwhile it holds at its gathering point, near its bases.

### It uses its kit

- **The Springers jump in** when the front engages: a ready Springer, not hurt, whose nearest enemy is beyond its shot but
  within a jump and a shot, leaps to a spot in shooting reach of it, on our side, where no enemy melee stands close and the
  enemies near the spot are not worth more than our front (AICwArmy.spring_in).
- The Pendulums walk into the thickest knot of enemy foot and the Netters net the most dangerous fighter in reach, as
  before (AI._micro, _pendulum_aim, _netter_aim). They now do it beside the rest of the army.

### It masses sooner

On Economy and Balanced, once the second Clocktower's two presses are laid, every Light Works that stands idle trains a
Clock Soldier at once (after the Winders, before the opening's later steps). Before, the army waited for the opening's
last steps.

## The coached games

Hard Clockwork against a Hard computer, seed 11, 10 minutes, on Frostfang, Highmoor, Cinder Steps and Redrock Canyon:
Economy against the Brood's Economy, Balanced against the Brood's Rush, Pendulums against the Brood's Balanced, Heavy Works
push against the Brood's Timing attack, Economy against the Crown's Economy, Balanced against the Crown's Balanced, Heavy
Works push against the Crown's Balanced. "Before" is the same code with `-- cwarmy:off` (the old army rules). The data:
docs/clockwork_army/games.jsonl; the tables: `python3 tools/clockwork_army_report.py docs/clockwork_army/games.jsonl`.

What the columns mean:
- **alone (all)**: times a Clockwork ground fighter fought (its target in reach, or hit) with no other ground fighter of
  its own within 6 tiles, while it had 4 or more of them (a new time after 5 s without). **alone away**: the ones more than
  12 tiles from every Clockwork building (sent out alone). **1st fight alone**: fresh units whose first fight was alone,
  away from home.
- **Winders with it out**: while the army (the push, else the wave) was more than 20 tiles from every Clocktower, the
  Winders within 10 tiles of its middle, on average (and for how many seconds it was out). It does not count the Winders
  riding a Spring Ballista as its crew, so the Heavy Works push reads low.
- **army**: the army's value (cogs and Tension) at 6:00, 8:00, 10:00, Clockwork against the enemy.

### Averages

| matchup | | games | alone (all) | alone away | 1st fight alone | Winders with it out | army 6:00 | 8:00 | 10:00 | killed | lost | won | fell |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| balanced v brood rush | after | 4 | 2.5 | 0.8 | 0.5 | 6.4 | 857 v 1112 | 2586 v 1887 | 3722 v 1822 | 2602 | 1625 | 0 | 0 |
| balanced v brood rush | before | 4 | 7.2 | 2.5 | 0.2 | 2.8 | 901 v 1281 | 1738 v 1918 | 2300 v 2790 | 1287 | 3163 | 0 | 0 |
| balanced v crown balanced | after | 4 | 7.8 | 7.0 | 1.5 | 5.4 | 1230 v 198 | 3062 v 442 | 5266 v 450 | 3785 | 817 | 0 | 0 |
| balanced v crown balanced | before | 4 | 14.0 | 14.0 | 3.5 | 5.0 | 1221 v 117 | 2870 v 595 | 4803 v 685 | 2675 | 1618 | 0 | 0 |
| economy v brood economy | after | 4 | 1.2 | 0.2 | 0.0 | 5.3 | 712 v 1931 | 2052 v 3738 | 2892 v 5616 | 2635 | 3723 | 0 | 0 |
| economy v brood economy | before | 4 | 13.2 | 2.2 | 0.5 | 8.3 | 553 v 1762 | 1667 v 3476 | 1432 v 4220 | 3883 | 5557 | 0 | 1 |
| economy v crown economy | after | 4 | 5.2 | 3.2 | 1.0 | 4.9 | 1201 v 203 | 3197 v 986 | 4023 v 562 | 4281 | 1992 | 0 | 0 |
| economy v crown economy | before | 4 | 9.8 | 7.8 | 2.8 | 6.2 | 985 v 175 | 3211 v 883 | 5028 v 658 | 3616 | 1047 | 0 | 0 |
| heavy v brood timing | after | 4 | 3.0 | 0.8 | 0.0 | 1.9 | 1350 v 1691 | 1212 v 3566 | 916 v 6461 | 2268 | 4930 | 0 | 0 |
| heavy v brood timing | before | 4 | 8.5 | 5.0 | 1.0 | 0.5 | 1157 v 1687 | 1231 v 3248 | 1212 v 4893 | 3406 | 4320 | 0 | 1 |
| heavy v crown balanced | after | 4 | 7.8 | 4.5 | 0.8 | 1.0 | 1420 v 192 | 2063 v 708 | 2542 v 1061 | 1508 | 1626 | 0 | 0 |
| heavy v crown balanced | before | 4 | 4.8 | 3.2 | 0.5 | 0.7 | 1420 v 213 | 2151 v 1025 | 2705 v 1607 | 1183 | 1450 | 0 | 0 |
| pendulum v brood balanced | after | 4 | 3.0 | 1.8 | 0.2 | 3.6 | 1545 v 1858 | 1890 v 3546 | 1908 v 4757 | 3493 | 2917 | 0 | 0 |
| pendulum v brood balanced | before | 4 | 8.5 | 6.5 | 1.2 | 2.5 | 1337 v 1881 | 1768 v 2981 | 2153 v 4395 | 3567 | 2686 | 0 | 0 |

ALL before: 28 games, alone 9.4, away 5.9, first alone 1.4, Winders out 3.2, army 6/8/10 1082/2091/2805, killed 2802 lost 2834, won 0 fell 2  
ALL after: 28 games, alone 4.4, away 2.6, first alone 0.6, Winders out 4.2, army 6/8/10 1188/2295/3038, killed 2939 lost 2518, won 0 fell 0

### Every game

| map | Clockwork v foe | | alone (all) | alone away | 1st fight alone | Winders with it out | army 6:00 | 8:00 | 10:00 | killed / lost by 10:00 | end |
|---|---|---|---|---|---|---|---|---|---|---|---|
| cinder_steps | balanced v brood rush | before | 3 | 3 | 0 | 5.7 (178 s) | 1085 v 1050 | 2485 v 1450 | 2885 v 1050 | 1850 / 2430 | on |
| cinder_steps | balanced v brood rush | after | 3 | 0 | 0 | 8.7 (99 s) | 980 v 825 | 3120 v 1625 | 3980 v 1350 | 2650 / 1530 | on |
| frostfang | balanced v brood rush | before | 6 | 1 | 0 | 0.8 (39 s) | 840 v 1325 | 1535 v 2550 | 3010 v 3375 | 825 / 2595 | on |
| frostfang | balanced v brood rush | after | 3 | 0 | 0 | 4.0 (4 s) | 630 v 1325 | 2210 v 2000 | 4115 v 2175 | 1740 / 1220 | on |
| highmoor | balanced v brood rush | before | 15 | 1 | 0 | 0.0 (1 s) | 770 v 1350 | 940 v 2075 | 1150 v 3000 | 1425 / 4360 | on |
| highmoor | balanced v brood rush | after | 2 | 1 | 0 | 8.6 (98 s) | 840 v 950 | 2890 v 2425 | 3975 v 2915 | 3030 / 1210 | on |
| redrock_canyon | balanced v brood rush | before | 5 | 5 | 1 | 4.9 (96 s) | 910 v 1400 | 1995 v 1600 | 2155 v 3735 | 1050 / 3270 | on |
| redrock_canyon | balanced v brood rush | after | 2 | 2 | 2 | 4.3 (205 s) | 980 v 1350 | 2125 v 1500 | 2820 v 850 | 2990 / 2540 | on |
| cinder_steps | economy v brood economy | before | 13 | 1 | 1 | never out | 375 v 2100 | 750 v 3375 | 0 v 5405 | 1765 / 7910 | no hall left |
| cinder_steps | economy v brood economy | after | 0 | 0 | 0 | 2.0 (8 s) | 195 v 1900 | 1430 v 3075 | 2840 v 5990 | 1500 / 2945 | on |
| frostfang | economy v brood economy | before | 13 | 1 | 0 | never out | 630 v 1625 | 1275 v 3705 | 70 v 5675 | 3420 / 7605 | on |
| frostfang | economy v brood economy | after | 4 | 0 | 0 | 5.8 (35 s) | 1140 v 2225 | 1355 v 3875 | 140 v 5915 | 2500 / 7125 | on |
| highmoor | economy v brood economy | before | 9 | 6 | 1 | 8.3 (88 s) | 640 v 1675 | 3030 v 3425 | 3735 v 2325 | 6060 / 2805 | on |
| highmoor | economy v brood economy | after | 1 | 1 | 0 | 9.3 (7 s) | 930 v 1675 | 3455 v 4645 | 4730 v 6055 | 2950 / 2145 | on |
| redrock_canyon | economy v brood economy | before | 18 | 1 | 0 | never out | 570 v 1650 | 1615 v 3400 | 1925 v 3475 | 4290 / 3910 | on |
| redrock_canyon | economy v brood economy | after | 0 | 0 | 0 | 4.3 (153 s) | 585 v 1925 | 1970 v 3360 | 3860 v 4505 | 3590 / 2680 | on |
| cinder_steps | heavy v brood timing | before | 11 | 5 | 2 | 0.1 (74 s) | 1210 v 2025 | 720 v 3285 | 0 v 5400 | 3475 / 6630 | no hall left |
| cinder_steps | heavy v brood timing | after | 6 | 0 | 0 | never out | 1420 v 2095 | 665 v 4320 | 0 v 6205 | 3415 / 7280 | on |
| frostfang | heavy v brood timing | before | 11 | 4 | 1 | 0.6 (64 s) | 1000 v 1750 | 1205 v 3610 | 0 v 4280 | 3725 / 5700 | on |
| frostfang | heavy v brood timing | after | 4 | 2 | 0 | 1.9 (14 s) | 1280 v 1150 | 1380 v 2400 | 3245 v 6445 | 1425 / 1770 | on |
| highmoor | heavy v brood timing | before | 8 | 8 | 0 | 0.7 (73 s) | 1070 v 1650 | 1690 v 2550 | 3070 v 5165 | 2475 / 1820 | on |
| highmoor | heavy v brood timing | after | 1 | 0 | 0 | never out | 1350 v 1500 | 485 v 3225 | 420 v 5995 | 2610 / 4585 | on |
| redrock_canyon | heavy v brood timing | before | 4 | 3 | 1 | 0.8 (82 s) | 1350 v 1325 | 1310 v 3550 | 1780 v 4730 | 3950 / 3130 | on |
| redrock_canyon | heavy v brood timing | after | 1 | 1 | 0 | 2.0 (103 s) | 1350 v 2020 | 2320 v 4320 | 0 v 7200 | 1625 / 6085 | on |
| cinder_steps | pendulum v brood balanced | before | 9 | 6 | 2 | 2.2 (135 s) | 1370 v 2100 | 1450 v 3025 | 520 v 5325 | 3025 / 5085 | on |
| cinder_steps | pendulum v brood balanced | after | 2 | 0 | 0 | 3.7 (45 s) | 1125 v 2660 | 870 v 4110 | 0 v 6185 | 3440 / 6485 | on |
| frostfang | pendulum v brood balanced | before | 12 | 11 | 3 | 2.1 (227 s) | 1490 v 1800 | 1715 v 2725 | 3180 v 5365 | 2200 / 1635 | on |
| frostfang | pendulum v brood balanced | after | 4 | 2 | 0 | 3.3 (172 s) | 1685 v 1525 | 2500 v 3375 | 2590 v 6425 | 1325 / 1755 | on |
| highmoor | pendulum v brood balanced | before | 7 | 6 | 0 | 2.9 (264 s) | 1490 v 1650 | 2090 v 2625 | 2990 v 2100 | 5220 / 1460 | on |
| highmoor | pendulum v brood balanced | after | 5 | 4 | 1 | 3.9 (244 s) | 1685 v 1475 | 2090 v 2695 | 2820 v 2995 | 4275 / 1415 | on |
| redrock_canyon | pendulum v brood balanced | before | 6 | 3 | 0 | 2.8 (103 s) | 1000 v 1975 | 1820 v 3550 | 1925 v 4790 | 3825 / 2565 | on |
| redrock_canyon | pendulum v brood balanced | after | 1 | 1 | 0 | 3.6 (124 s) | 1685 v 1775 | 2100 v 4005 | 2225 v 3425 | 4935 / 2015 | on |
| cinder_steps | balanced v crown balanced | before | 10 | 10 | 4 | 5.2 (217 s) | 1220 v 70 | 2240 v 705 | 5580 v 1355 | 965 / 1050 | on |
| cinder_steps | balanced v crown balanced | after | 8 | 8 | 2 | 6.3 (228 s) | 1390 v 185 | 2975 v 440 | 5635 v 0 | 4550 / 750 | on |
| frostfang | balanced v crown balanced | before | 6 | 6 | 2 | 4.4 (234 s) | 1250 v 0 | 3435 v 345 | 4960 v 230 | 2570 / 1095 | on |
| frostfang | balanced v crown balanced | after | 8 | 8 | 0 | 4.9 (267 s) | 1140 v 285 | 3175 v 400 | 5890 v 515 | 3745 / 570 | on |
| highmoor | balanced v crown balanced | before | 32 | 32 | 7 | 5.9 (229 s) | 1180 v 145 | 3065 v 565 | 4930 v 355 | 4340 / 1495 | on |
| highmoor | balanced v crown balanced | after | 4 | 3 | 2 | 6.0 (241 s) | 1195 v 325 | 3255 v 930 | 4490 v 1170 | 1750 / 1070 | on |
| redrock_canyon | balanced v crown balanced | before | 8 | 8 | 1 | 4.6 (228 s) | 1235 v 255 | 2740 v 765 | 3745 v 800 | 2825 / 2835 | on |
| redrock_canyon | balanced v crown balanced | after | 11 | 9 | 2 | 4.5 (242 s) | 1195 v 0 | 2845 v 0 | 5050 v 115 | 5095 / 880 | on |
| cinder_steps | economy v crown economy | before | 10 | 10 | 3 | 5.0 (82 s) | 1110 v 140 | 3295 v 720 | 5140 v 695 | 2595 / 830 | on |
| cinder_steps | economy v crown economy | after | 5 | 4 | 2 | 5.2 (267 s) | 1250 v 140 | 2875 v 850 | 3855 v 0 | 5890 / 2410 | on |
| frostfang | economy v crown economy | before | 10 | 10 | 3 | 6.7 (129 s) | 990 v 140 | 3055 v 710 | 4780 v 495 | 5425 / 1080 | on |
| frostfang | economy v crown economy | after | 5 | 3 | 0 | 4.7 (245 s) | 1250 v 210 | 3600 v 1060 | 3100 v 195 | 3970 / 2845 | on |
| highmoor | economy v crown economy | before | 12 | 8 | 3 | 7.2 (143 s) | 920 v 210 | 3005 v 795 | 5470 v 600 | 4830 / 720 | on |
| highmoor | economy v crown economy | after | 3 | 0 | 0 | 5.9 (251 s) | 1250 v 210 | 3275 v 1240 | 5130 v 1745 | 1855 / 730 | on |
| redrock_canyon | economy v crown economy | before | 7 | 3 | 2 | 6.1 (26 s) | 920 v 210 | 3490 v 1310 | 4725 v 845 | 1615 / 1560 | on |
| redrock_canyon | economy v crown economy | after | 8 | 6 | 2 | 3.8 (231 s) | 1055 v 255 | 3040 v 795 | 4010 v 310 | 5410 / 1985 | on |
| cinder_steps | heavy v crown balanced | before | 3 | 2 | 0 | 0.5 (225 s) | 1420 v 140 | 1970 v 795 | 2355 v 140 | 2125 / 1455 | on |
| cinder_steps | heavy v crown balanced | after | 5 | 1 | 0 | 1.5 (222 s) | 1420 v 0 | 2040 v 330 | 3350 v 185 | 1500 / 630 | on |
| frostfang | heavy v crown balanced | before | 8 | 6 | 2 | 0.9 (153 s) | 1420 v 230 | 1970 v 950 | 3015 v 2285 | 545 / 820 | on |
| frostfang | heavy v crown balanced | after | 1 | 0 | 0 | 0.5 (162 s) | 1420 v 215 | 1970 v 890 | 1535 v 2145 | 390 / 2405 | on |
| highmoor | heavy v crown balanced | before | 5 | 5 | 0 | 1.0 (153 s) | 1420 v 230 | 2420 v 1380 | 2190 v 1800 | 765 / 2275 | on |
| highmoor | heavy v crown balanced | after | 15 | 9 | 3 | 1.1 (191 s) | 1420 v 255 | 2210 v 1145 | 2215 v 1500 | 1300 / 2540 | on |
| redrock_canyon | heavy v crown balanced | before | 3 | 0 | 0 | 0.6 (203 s) | 1420 v 255 | 2245 v 975 | 3260 v 2205 | 1300 / 1250 | on |
| redrock_canyon | heavy v crown balanced | after | 10 | 8 | 0 | 0.8 (234 s) | 1420 v 300 | 2035 v 470 | 3070 v 415 | 2845 / 930 | on |

## Reading the numbers

- **Together.** The thing the owner asked for: fighters fighting alone more than halved (9.4 to 4.4 a game), and away from
  home 5.9 to 2.6. Against the Brood, where it mattered most, it fell from 9.4 to 2.4 a game (Economy against Economy: 13.2
  to 1.2). The ones left are mostly a fighter at the end of a long line in a push against the Crown (Musketeers kite the
  front, the Heavy Works push's guards run out to meet an enemy at a Ballista) and one or two units walking from a far
  Works to the army.
- **The trades.** Better against the Brood's Rush (lost 1,625 against 3,163), Economy against Economy (3,723 against
  5,557) and the Crown's Balanced (817 against 1,618); about the same with the Pendulums; worse with the Heavy Works push
  against the Brood (4,930 against 4,320) and the Economy against the Crown (1,992 against 1,047, but it killed 4,281
  against 3,616). Overall it lost about 11% less and killed about 5% more.
- **The owner's game.** Economy against the Brood's Economy on Frostfang: before, the army stood spread over the main and
  died a few at a time (70 left at 10:00, lost 7,605). After, it held together and met the raids as one; in this run the
  Brood's 92-supply wave still beat it at 9:30 (lost 7,125). In the test run of the same game (tools/test_clockwork_army.gd
  check:1, same code) it ended with 4,320 against the Brood's 7,060, lost 2,295. These games vary a lot from run to run:
  one run of the same game and code lost 1,390, another 8,660. Single games here are anecdotes; the averages are the result.
- **It still does not squash the Brood.** Against the Hard Brood the Brood's army was about twice the Clockwork's at 8:00
  in most games (Economy against Economy: 3,738 against 2,052), so the push rarely went out: the army held at its
  gathering point, which is what the owner's rule asks when it is weaker. The Brood out-earning both Hard computers is the
  open FOOD_BONUS question (CLAUDE.md); the army code cannot close that gap.
- **The muster (tried, off).** Reinforcements made far from the gathering point waiting in the main and walking to the
  army in threes (scripts/ai_cw_army.gd _muster, `-- cwmuster:on`). Measured on 10 games against the Brood it was worse:
  lost 4,507 against 3,818, fought alone 5.8 against 2.7 times a game. The units held in the main were missing from the
  army when the Raptors came and were raided at the muster themselves. It is off.
- **Massing sooner.** The army at 6:00 is 10% bigger, at 8:00 10%. The first soldiers on Economy come right after the
  second Clocktower's presses are laid (3:18 on Frostfang; the owner's game had its first at 4:20). A bug found on the way: the opening's own "6 Clock
  Soldiers" step waited for an idle Works that the massing kept busy, so the opening never ended and the cogs piled up
  (3,650 in the bank at 9:00); the massing's soldiers now count for that step.

## Open questions for the owner

1. **The Clock Soldier harass.** On 2026-10-31 you asked that a Clock Soldier found out alone may harass the workers (the
   shared rule's one exception). With the one army a stray walks back to the army instead. Keep it that way?
2. **Where it gathers.** In front of the Clocktower nearest the enemy (usually the newest). The main is then guarded by its
   turrets, its Winders and the groups sent at raids. Would you rather it gather at the main's ramp until it has a third
   Clocktower?
3. **The Heavy Works push.** Against the Brood it traded worse than before in these games (it was already the weakest plan
   there): its Ballistas are slow and the Brood's Raptors run round the front to them. Worth a job of its own.
4. **The Owls test** failed once in four runs here ("the first Owl sortie by 8:00: never": two cranks were lost at their
   post and the Owls rested 150 s); it passed on the other three, and with `cwarmy:off`. It looks like chance; flagged.
5. **The reckoning tables** (what an enemy of that age has) were fitted to these Hard games. A Normal or Easy enemy has
   less; the Clockwork then waits longer than it needs to (it still goes once it sees them).

## Proposals (numbers: the owner's call; nothing was changed)

- None of the fixes needed a number. The owner's pending Springer proposal (jump range 5 to 6-7 tiles, recharge 10 to 6-7
  s) would let more Springers jump in when the front engages (spring_in finds a Springer within a jump and a shot of its
  target only now and then: the log, which says it at most once in 15 s, has it 0 to 8 times a game).
- The Brood's FOOD_BONUS (1.5 to 0.8), already waiting on you: these games show the Hard Brood's army about twice the
  Hard Clockwork's at 8:00 whatever the Clockwork's army does.

## Tests and tools

- `tools/test_clockwork_army.gd`: one game, measured. `check:1` is the test (Frostfang, the Hard Economy Clockwork against
  the Hard Brood Economy, until:600): at most 2 fights alone away from home, at most 2 first fights alone away from home,
  and the Winders with the army (1.5 or more on average while it is out). `cwarmy:off` plays the old army code.
- `tools/clockwork_army_report.py`: the tables above from the test's json lines.
- `tools/film_clockwork_army.gd`: a filmed game (the army at set times, the push, the Springers' jumps, GIF frames).
- The old tests still pass: test_clockwork_eco, test_clockwork_builds_a (Clock Soldier rush and turtle),
  test_clockwork_builds_b (Pendulums and Heavy Works), test_clockwork_owls, test_clockwork_springer_timing,
  test_ai_wall_vs_rush.

## Pictures

docs/shots/clockwork_army/ (captions.md).
