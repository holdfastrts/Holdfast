# The Crown's Siege push (branch crown-builds-b)

The owner (2026-11-03, "do it all"): a new Crown computer plan, the SIEGE PUSH: Field Cannons and Mortars behind a
Musketeer line, timed to break a Clockwork turtle (Ratchet Turrets, Winders that mend them) or a rooted Brood (Rootmaws,
Mound Turtles, the Brood Mother's nest); the limbered guns escorted, unlimbered out of the defenders' reach, the line
screening them, the guns shooting the right things first, the Powder Wagon kept back, a retreat when the push is lost and
the economy growing behind it. Coached with filmed games, measured against the Crown's Balanced plan.

Pictures: `docs/shots/crown_builds_b/` (captions in its `captions.md`).

## 1. What it is

- A plan the player can pick for a Crown computer: **SIEGE PUSH** in the lobby's PLAN list (pt *Avanço de cerco*, es
  *Avance de asedio*; `AI.STRATEGIES["siege"]`, "crown_only": the Brood and the Clockwork do not get it, and RANDOM PLAN may
  pick it for the Crown).
- The Crown's own computer plays it (`scripts/ai_crown.gd`, `AICrown.PLANS["siege"]`): a written opening build order, then
  milestones, like the other plans (docs/ai_crown_rebuild.md). The shared waves never go on this plan (`"wave": 999`,
  `_wave_worth` says no): the PUSH goes instead.
- The push is its own file, `scripts/ai_crown_siege.gd` (`AICrownSiege`, a helper object like the ramp post's
  `AICrownHold`). `AICrown` owns it (`siege`, made in `_ready` when `siege_on()`) and calls it from five small hooks at the
  end of `ai_crown.gd` (`_army`, `_on_errand`, `_produce`, `_wave_worth`, `_tend_wagon`) plus the gun's gold in
  `_think_stage`. Everything else in `ai_crown.gd` is untouched, so the parallel jobs that add plans to the same file
  (crown-builds-a, crown-builds-c) merge with one conflict at most: their entries and this one at the end of `PLANS`.
- Easy, and `-- crownnew:off`, play the shared computer with the plan's shared numbers (`AI.STRATEGIES["siege"]`: Balanced's,
  a first wave of 18): no push.
- No unit or building was changed (the owner's rule): every number below is the computer's own behaviour.

## 2. The build order

Against the Clockwork (and anyone else) the Economy plan's opening; against the Brood the Balanced plan's safe opening
(`"bo_brood"`: the Economy opening's six Musketeers lost the main to the Brood's Timing attack at 6:00 in round A).
Every step waits for its trigger (labourers or supply, never the clock); its gold is set aside until it is paid.

| step | trigger (Clockwork) | trigger (Brood) |
|---|---|---|
| the ramp Cottage | 5 supply | 5 supply |
| the ramp Gate | 7 labourers | 5 supply |
| the second Farm | 7 labourers | 9 labourers |
| the Barracks, the Powder Mill | 8 labourers | 7 labourers |
| Musketeers from now on, in the opening up to | 6 supply | 8 supply |
| the Horse Breeder (the guns' horses) | 17 labourers (after the hall) | 13 labourers |
| the second Town Hall | 15 labourers | 15 labourers |
| the Foundry | 19 labourers | 17 labourers |

Mill crew in the opening: 2 hands, 4 from 14 labourers, 6 from 18. Then the milestones: a second Barracks at 21 labourers
with two halls, the Armoury at 28, a second Foundry at 30 with two halls, a third Barracks at 34, the Church at 40. The army
is kept at 0.45 supply a labourer (0.55 against the Brood, as every plan).

**The guns come first.** From the Foundry on, `AICrownSiege._gun_want` wants a Field Cannon for every 5 Musketeers (one
more, up to 4) and a Mortar for every 7 (up to 3), once the line has 5 Musketeers (8 against the Brood). While one is
wanted and a Foundry stands idle, its price (and its horse's, when no horse is at hand) is kept from the labourers, the
tech and the Musketeers (`gun_due`, read by `AICrown._think_stage` and `_produce`), for at most 50 s at a time (then 30 s
off: a gun that cannot be had never holds the gold for good) and never while the base is attacked. Without it the first
gun came at 9:00 against a Brood that stood still: the hall's labourers took every coin.

## 3. The push

| part | what it does | numbers (`scripts/ai_crown_siege.gd`) |
|---|---|---|
| GO | guns and line at home, the push worth the enemy army it knows, no enemy force at our buildings for a minute | GUNS_GO 3 (one a cannon), LINE_GO 10 Musketeers, or BIG_GO 50 supply; EDGE 0.75 times the enemy army it knows (1.5 against the Brood), a gun counted 1.5 times its price; QUIET 60 s after an enemy force worth THREAT_MIN 250 was at our buildings; COOL 60 s after a push |
| MARCH | the line in front on attack-move to the next defence it knows (else the enemy's hall); the guns LIMBERED on the line's own trail (where it walked: never over a cliff) 150 px behind it; the line waits on HOLD while its guns are 260 px behind; Horsemen ride by the guns | GUN_TRAIL 150, GUN_LAG 260, WAGON_TRAIL 330 |
| SET UP | a defence (a building, a turret, a rooted creature, a father) within 330 px of the push's main body, or an enemy force worth 30% of the push on it: the line stands on HOLD in a row across the way 245 px in front of the target (190 against rooted creatures: they bite at 22-50 px), the guns unlimber behind it (cannon 385 px from the target, range 430; mortar 300, range 352) at a spot fixed when it set up; against an army the line holds where it stands and the guns fire from where they are | STOP_D 330, ARMY_STOP 0.3, LINE_D 245 / 190, CANNON_D 385, MORTAR_D 300, SPOT_T 25 s |
| THE GUNS' TARGETS | each gun every 4 s (`_pick`): a Ratchet Turret 10, a worker mending or building 9, a rooted creature or father 8 (the Mother 7.5), enemy guns and engines 7, the enemy army 6 (a Mortar only slow things), a wall or gate 4, production and halls 3, other buildings 2; less for the farther; never a shot through our own men (`Game.aoe_worth_it`); a defence it saw but cannot see now is BOMBARDED (attack ground) | - |
| CANISTER | an enemy within 170 px of a cannon: canister at it (not through our line) | CANISTER_R 170 |
| THE WAGON | 150 px behind the guns (330 behind the line on the march), never among the men (its blast, 110 px, kills friends: round B of the rebuild); enemies near it, it backs off along the trail; a gun out of shot walks to it and back | WAGON_BACK 150 |
| ON | the target gone: the enemy army still on the line first, then the next defence within reach, else the march goes on | - |
| BACK | under 45% of what went out is left, or an enemy here worth 1.4 times the push while it is under 75%, or its guns are gone, or an enemy force at home worth 1.3 times the army there: everyone walks home (the guns limber), the wagon too; then the shared computer has them again | RETREAT_K 0.45, RETREAT_FOE 1.4 |
| REINFORCEMENTS | units trained since go out in groups of 6 supply to the push's trail | JOIN_SUP 6 |

The push's MAIN BODY (`_core_mid`): every distance is measured from the densest group of the push, not from the middle of
all of it (with the reinforcements walking out from home in the middle, the push "never saw" a Clocktower its front stood
in: round C, the first d01 Greenhold 11:29).

The AI STORY tells it: "P1 Crown's siege push goes out: 26 supply, 3 guns behind a line of Musketeers.", "... line stands
and its guns unlimber behind it, against the enemy's Clocktower.", "... falls back: the guns limber and go home first."
(`scripts/ai_story_lines.gd`, the texts in `tools/i18n/52_crown_siege.txt`).

## 4. Coaching

The tool is `tools/play_crown_siege.gd` (it extends `tools/play_crown_1.gd`, the rebuild's filmed coach): side 0 the Crown
computer on the siege plan, side 1 the normal computer on Hard. Besides the rebuild's pictures and files it films the push:
`push_out_MMSS.png` and a clip (made into `push_N.gif` by `tools/play_brood_new_gif.py`), `push_set` 8 s and `push_fire`
20 s after it sets up, `push_back`, `push_end`, and writes `siege.txt` (the economy at 4/6/8/10 min, the totals, a line a
push: when it left, its supply and guns, its first contact, what it broke, what it killed and lost, why it ended).
`tools/play_crown_siege_table.py` makes the tables below; `coach:balanced` plays the same game on the Balanced plan for the
comparison.

Each round played the same games: Hard opponents, 13 minutes, the Clockwork on Economy (its fastest army and the turrets
it puts up by 6:00-7:00), Timing and Balanced, the Brood on Economy and Timing, on Greenhold, Red Coast (the owner's seed),
Kestrel Rise, Highmoor and Mirewood. (There is no Clockwork turtle plan to play against: the owner decided on
2026-11-03 that static defence is not a build; the Clockwork computer puts up its turrets by its main, two on Hard.)
"Broke" counts the enemy buildings and rooted creatures that died near the push while it was out.

## 5. The coached rounds

Each game played the code as it stood when it started (the fixes went in while a round was played, as in the rebuild);
which code is said under each table. I looked at the pictures of every game; what they showed is under each table.

### Round A (the first draft; a05-a08 with the field-battle fix)

| game | against | map | result | labourers 4/6/8 | gold earned by 6/8 | army 6/8 (enemy 8) | pushes: out at (supply, guns) -> first contact | what the pushes broke | push killed / lost | game killed / lost |
|---|---|---|---|---|---|---|---|---|---|---|
| a01 | Clockwork economy | Greenhold 3 | alive 13:00 | 17/26/40 | 3800/7220 | 420/1300 (2200) | 7:53 (22, 3), 11:58 (39, 5) | 1 clock soldier | 2225 / 1630 | 3515 / 1680 |
| a02 | Clockwork timing | Red Coast 7 | alive 13:00 | 17/24/32 | 3800/6460 | 480/1610 (2255) | 11:59 (29, 4) | - | 425 / 330 | 4440 / 2825 |
| a03 | Brood economy | Kestrel Rise 2039763518 | alive 13:00 | 16/25/38 | 3800/6460 | 455/1090 (5450) | 8:37 (22, 3) | 2 mound turtle, 4 raptor | 5550 / 110 | 5825 / 225 |
| a04 | Brood timing | Highmoor 1 | alive 13:00 | 16/23/22 | 3040/5320 | 460/595 (4425) | 12:14 (28, 3) | - | 0 / 0 | 1690 / 2425 |
| a05 | Clockwork balanced | Kestrel Rise 5 | alive 13:00 | 15/20/32 | 3040/5320 | 360/1455 (2450) | 11:08 (26, 3) | - | 140 / 680 | 2820 / 2385 |
| a06 | Brood timing | Red Coast 4291306512 | L 9:46 | 16/23/24 | 3040/5320 | 595/835 (4450) | - | - | - | 1800 / 6070 |
| a07 | Clockwork economy | Highmoor 5 | alive 13:00 | 15/25/35 | 3420/6460 | 475/1215 (2300) | 9:12 (29, 3), 12:20 (37, 5) | - | 2470 / 1315 | 4565 / 2150 |
| a08 | Brood economy | Greenhold 11 | L 12:31 | 15/20/27 | 3040/5320 | 580/1280 (4575) | 9:12 (32, 4) | - | 875 / 960 | 4025 / 8480 |

What the films showed, and what was changed:

1. **The push works when it gets there.** a03 (Brood Economy, Kestrel Rise): out at 8:37 with 22 supply and 3 guns, it set
   up against two Mound Turtles closing the Brood's ramp, broke them and four Raptors, and finished on the Brood's own ramp:
   5,550 killed for 110 lost. In the trial game before the round (the same game as a01) the line stood in a row with the
   guns behind it and broke a Clocktower expansion (picture 05).
2. **Against the Brood's Timing attack the Economy opening loses the main** (a06, the owner's Red Coast seed, lost at 9:46;
   a04 Highmoor: 23/22 labourers at 6/8 minutes, 4,425 of Brood army against 595). **Fix**: against the Brood the plan
   opens like Balanced (`"bo_brood"`: the Gate and eight Musketeers before the second hall).
3. **A push went out 28 s after 41 Raptors left the base** (a08 Greenhold, picture 09: caught at the foot of its own ramp,
   then the main fell at 12:31). **Fix**: a push needs 60 s with no enemy force at our buildings, and 1.5 times the Brood
   army it knows (the rebuild's edge for waves against the Brood).
4. **Against the Clockwork the push waited till 11:00-12:00** for 0.9 times the army it knew (a02, a05): the Clockwork on
   Hard always has the bigger army. **Fix**: 0.75 (the guns outrange its defence and the line sets up: the enemy must come
   to it; a gun counts 1.5 times its price).
5. **When the enemy soldier it set up against died, the push set up against a Clocktower 636 px away** and the line walked
   into the Clockwork army (a01, 9:54). **Fix**: the army still on the line comes first, then a defence within reach.

### Round B (the same eight games; b01-b03 before the gun and threat fixes below), and the Balanced plan on them (c01-c08)

| game | against | map | result | labourers 4/6/8 | gold earned by 6/8 | army 6/8 (enemy 8) | pushes: out at (supply, guns) -> first contact | what the pushes broke | push killed / lost | game killed / lost |
|---|---|---|---|---|---|---|---|---|---|---|
| b01 | Clockwork economy | Greenhold 3 | alive 13:00 | 17/26/38 | 3800/6840 | 420/1105 (2310) | 8:15 (22, 3), 11:11 (43, 5) -> 12:41 | - | 2080 / 1285 | 3505 / 1750 |
| b02 | Clockwork timing | Red Coast 7 | alive 13:00 | 17/25/32 | 3800/6080 | 420/1400 (1470) | - | - | - | 2550 / 1105 |
| b03 | Brood economy | Kestrel Rise 2039763518 | alive 13:00 | 15/21/30 | 3040/5700 | 575/1310 (5300) | 11:46 (26, 4) -> 12:34 | 1 rootmaw | 125 / 0 | 2400 / 1525 |
| b04 | Brood timing | Highmoor 1 | L 12:15 | 15/19/27 | 3040/4940 | 695/1170 (4005) | - | - | - | 5945 / 7890 |
| b05 | Clockwork balanced | Kestrel Rise 5 | alive 13:00 | 16/21/31 | 3420/5700 | 660/1675 (2180) | 8:45 (26, 3) -> 9:35 | 1 cog press | 2550 / 1375 | 4020 / 1600 |
| b06 | Brood timing | Red Coast 4291306512 | alive 13:00 | 15/20/23 | 3040/5320 | 635/960 (2500) | 8:30 (25, 3) | - | 1900 / 1190 | 9600 / 3955 |
| b07 | Clockwork economy | Highmoor 5 | alive 13:00 | 17/25/34 | 3800/6460 | 360/1505 (2245) | 8:12 (27, 3) -> 9:39 | 1 clocktower | 4945 / 2015 | 5155 / 2065 |
| b08 | Brood economy | Greenhold 11 | L 12:00 | 15/18/19 | 3040/4560 | 240/1110 (5075) | - | - | - | 3825 / 5470 |
| c01 | Clockwork economy | Greenhold 3 | alive 13:00 | 14/20/33 | 3040/5320 | 580/1175 (2030) | wave 8:34 (18) | - | - | 5225 / 2575 |
| c02 | Clockwork timing | Red Coast 7 | alive 13:00 | 14/18/27 | 3040/5320 | 540/1295 (2225) | wave 8:01 (16) | - | - | 7515 / 1535 |
| c03 | Brood economy | Kestrel Rise 2039763518 | alive 13:00 | 14/19/30 | 3040/5700 | 575/1030 (5300) | wave 9:24 (23) | - | - | 6350 / 5990 |
| c04 | Brood timing | Highmoor 1 | L 11:24 | 14/19/32 | 3040/4940 | 690/935 (4645) | - | - | - | 5390 / 6595 |
| c05 | Clockwork balanced | Kestrel Rise 5 | alive 13:00 | 13/19/31 | 3040/5320 | 400/1105 (2110) | wave 7:57 (18) | - | - | 6310 / 1900 |
| c06 | Brood timing | Red Coast 4291306512 | L 10:26 | 14/19/20 | 3040/4940 | 690/635 (2910) | - | - | - | 4405 / 5360 |
| c07 | Clockwork economy | Highmoor 5 | alive 13:00 | 14/19/34 | 3040/5700 | 580/1210 (2045) | wave 8:51 (22) | - | - | 5290 / 2145 |
| c08 | Brood economy | Greenhold 11 | alive 13:00 | 14/19/33 | 3040/5320 | 690/1220 (4625) | - | - | - | 5850 / 7810 |

What the films showed, and what was changed:

1. **The guns did not unlimber** (b05 Kestrel Rise, picture 08: 20 s after the push set up against a Clocktower its guns
   still stood limbered with their horses, 350 px behind the line): their spot was worked out again every think from the
   target, and against an army it moved with every enemy soldier, so they walked on and on. **Fix**: a gun's spot is fixed
   when the push sets up against a defence (given up after 25 s: it fires from where it is); against an army on the line
   the guns fire from where they stand.
2. **A push never went** (b02 Red Coast): every lone Clockwork raider at a building of ours kept it home. **Fix**: only an
   enemy force worth 250 or more seen on our side does.
3. **Against the Brood a gun's gold held from 4 Musketeers lost the main** (b08 Greenhold: 4 Musketeers from 5:00 to 6:00,
   the Brood at 5,000 of army by 8:00). **Fix**: against the Brood no gun is wanted before 8 Musketeers stand.
4. With the Brood opening the owner's Red Coast seed held (b06: 9,600 killed for 3,955, the Balanced plan lost there at
   10:26, c06).
5. b07 (Highmoor): the guns unlimbered at the foot of our ramp and burnt down the Clocktower the Clockwork had put up below
   it, the line in a row covering them (picture 04); the push traded 4,945 for 2,015.

### Round C (the final code; d04b and d08b again after the last change, the Brood opening's Foundry at 21 labourers), and the Balanced plan on the two new games (e09, e10; c01-c08 above are the others)

| game | against | map | result | labourers 4/6/8 | gold earned by 6/8 | army 6/8 (enemy 8) | pushes: out at (supply, guns) -> first contact | what the pushes broke | push killed / lost | game killed / lost |
|---|---|---|---|---|---|---|---|---|---|---|
| d01 | Clockwork economy | Greenhold 3 | alive 13:00 | 17/26/34 | 3800/6460 | 420/1340 (2325) | 7:46 (22, 3) -> 8:49, 12:44 (41, 5) | - | 930 / 1020 | 2415 / 1900 |
| d02 | Clockwork timing | Red Coast 7 | alive 13:03 | 17/26/36 | 3800/6460 | 420/1415 (2410) | 8:12 (26, 3) -> 9:07, 12:56 (41, 5) | 1 cog press | 3570 / 1490 | 4670 / 1540 |
| d03 | Brood economy | Kestrel Rise 2039763518 | alive 13:00 | 15/20/30 | 3040/5320 | 635/1315 (4900) | 8:43 (27, 3) -> 9:12 | 3 mound turtle, 3 rootmaw | 2650 / 50 | 2775 / 165 |
| d04 | Brood timing | Highmoor 1 | L 11:02 | 15/20/0 | 3040/3800 | 635/0 (3650) | - | - | - | 1200 / 4470 |
| d05 | Clockwork balanced | Kestrel Rise 5 | alive 13:00 | 16/24/37 | 3800/6460 | 535/1305 (2210) | 9:16 (29, 3) -> 10:05, 12:23 (37, 5) | - | 2940 / 1085 | 4420 / 1250 |
| d06 | Brood timing | Red Coast 4291306512 | alive 13:00 | 15/20/24 | 3040/5320 | 635/1355 (4000) | 12:10 (37, 7) | - | 100 / 230 | 9320 / 2250 |
| d07 | Clockwork economy | Highmoor 5 | alive 13:00 | 17/25/34 | 3800/6460 | 360/1355 (2310) | 7:59 (24, 3) -> 9:01, 11:44 (32, 4) -> 12:39 | 1 clocktower | 3295 / 1220 | 3955 / 1625 |
| d08 | Brood economy | Greenhold 11 | L 11:36 | 15/18/32 | 3040/5700 | 355/1200 (5125) | - | - | - | 2750 / 7735 |
| d09 | Clockwork timing | Greenhold 11 | alive 13:00 | 17/25/35 | 3800/6460 | 360/1235 (2230) | 8:26 (25, 3) -> 8:32, 12:14 (30, 4) | - | 2625 / 1700 | 3295 / 1750 |
| d10 | Brood timing | Mirewood 3 | L 11:17 | 15/20/27 | 3040/5320 | 580/995 (4975) | - | - | - | 4295 / 6705 |
| e09 | Clockwork timing | Greenhold 11 | alive 13:00 | 14/20/35 | 3040/5700 | 655/990 (2325) | wave 9:19 (18) | - | - | 5575 / 2150 |
| e10 | Brood timing | Mirewood 3 | L 11:55 | 14/19/21 | 3040/4940 | 695/995 (4525) | - | - | - | 3830 / 6655 |
| d04b | Brood timing | Highmoor 1 | alive 13:00 | 15/19/23 | 3040/4940 | 635/925 (3100) | - | - | - | 11055 / 3930 |
| d08b | Brood economy | Greenhold 11 | L 11:44 | 15/20/29 | 3040/5320 | 630/880 (4450) | - | - | - | 3500 / 7695 |

What the films showed, and what was changed:

1. **The line walked into a Clocktower's gear ring without setting up** (the first d01, Greenhold 11:29: the push's
   middle counted the reinforcements walking out from home 1,000 px back, so the defence never came "near the line"; a gun
   joining from home also held the line back for minutes: 9:46 out, 12:47 first contact). **Fix**: every distance is
   measured from the push's main body; only the guns with it hold the line. Round C was played again from the start on
   that code (the table above).
2. **Against the Brood the Foundry at 17 labourers left 4 Musketeers at 6:00** (d08 Greenhold) **Fix**: at 21 labourers
   against the Brood. With it Highmoor against the Brood's Timing, lost by both plans before (d04 at 11:02, c04 at 11:24), held: 11,055
   killed for 3,930 (d04b). Greenhold seed 11 against the Brood's Economy is still lost (d08b at 11:44; the Balanced plan
   held it, c08).
3. Against the Brood the push sets up at the foot of its nest's ramp and the guns kill what is rooted there (d03: three
   Mound Turtles and three Rootmaws for 50 lost, pictures 06 and 07); the line then went up the ramp beside the Mother.
4. When the push is lost it comes home as it should (d07 10:05, picture 10: the guns limbered and through the gate first).

## 6. The numbers: Siege push against the Balanced plan (final code: round C and its two reruns; Balanced c01-c08, e09-e10)

| | Siege push | Balanced |
|---|---|---|
| against the Clockwork (5 games: Economy x2, Timing x2, Balanced) | | |
| results | 5 alive at 13:00 | 5 alive at 13:00 |
| labourers at 4/6/8 min | 16-17 / 24-26 / 34-37 | 13-14 / 18-20 / 27-35 |
| gold earned by 6 / 8 min | 3,800 / 6,460 (every game) | 3,040 / 5,320-5,700 |
| army at 6 / 8 min | 360-535 / 1,235-1,415 | 400-655 / 990-1,295 |
| the push / first wave leaves | 7:46-9:16 (21-29 supply, 3 guns); first contact 6-63 s later | first wave 7:57-9:19 (16-22 supply) |
| what the pushes broke | a Cog Press (d02), a Clocktower (d07) | - |
| value killed / lost, the 5 games | 18,755 / 8,065 (2.3 to 1) | 29,915 / 10,305 (2.9 to 1) |
| against the Brood (5 games: Economy x2, Timing x3) | | |
| results | 3 alive (Kestrel Rise, Red Coast, Highmoor), 2 lost (Greenhold 11:44, Mirewood 11:17) | 2 alive (Kestrel Rise, Greenhold), 3 lost (Highmoor 11:24, Red Coast 10:26, Mirewood 11:55) |
| labourers at 4/6/8 min | 15 / 19-20 / 23-30 | 14 / 19 / 20-33 |
| value killed / lost, the 5 games | 30,945 / 20,745 | 25,825 / 32,410 |
| the push | out in 1 game of 5 before 12:00 (d03, 8:43: 2,650 killed for 50) | first wave in 1 of 5 (c03, 9:24) |

Read:
- **The economy is better**: the Siege push opens like Economy against the Clockwork, so it has 3-7 more labourers at
  6:00 and 1,000 more gold earned by 8:00 than Balanced in every Clockwork game. Against the Brood (Balanced's opening)
  they are the same.
- **Against the Clockwork the push goes out at 7:45-9:15 and trades well (2.3 to 1), but Balanced kills more**: the
  Clockwork on Hard attacks at 8:00-10:00, and Balanced's army meets it on HOLD at the top of the ramp (the doctrine's ramp
  post), where it kills the most; the push meets it in the open, or comes home for it ("the base is attacked": d01, b01).
  The push breaks the Clockwork's expansions (a Clocktower in b07, d07, the first a01; a Cog Press in b05, d02); it did
  not reach the Clockwork's main turrets in a coached game: the Clockwork army, 2,200-2,400 at 8:00, meets it first.
- **Against the Brood it holds more often** (3 of 5 against 2 of 5) with more killed than lost (30,945 / 20,745 against
  25,825 / 32,410), mostly from the safer opening and the guns at home; the push itself rarely goes (1.5 times the army it
  knows: the Brood on Hard has 4,000-5,000 of army at 8:00), and when it went it was the best trade of all the games
  (a03, d03: two and three Mound Turtles, three Rootmaws, 5,550 / 110 and 2,650 / 50).
- Results are noisy (one game a row, and the same code lost and held Greenhold against the Brood); the timings and the
  economy columns are the solid part.

## 7. Tests

`tools/test_crown_siege.gd` (new), all pass:
- [plan] Siege push is a Crown plan only (`AI.strategies_for`), `AICrown.PLANS` has it, a Hard Crown on it has its push and
  the shared waves never go;
- [open] on its plan against a Brood that stands still: the second hall, the Breeder and the Foundry, and the first gun
  trained by 9:00 (6:56-8:16 in the runs); its opening against the Brood is well formed;
- [march] a push (12 Musketeers, 2 cannons, a Mortar, the wagon) sent at a still Clockwork base with two Ratchet Turrets:
  on the march the guns are limbered and behind the line (24-25 of 25 looks);
- [set] it sets up, and no gun fires from within 215 px of a turret;
- [break] both turrets down in 99-102 s, no gun lost;
- [wagon] the wagon never within 110 px of a Musketeer while set up (0 of 163-169 looks);
- [back] 40 Clock Soldiers come at it: it falls back at once, the guns go home.

`tools/test_crown_build_order.gd` still passes (the plans' table check covers the new plan's steps).
Boot: `godot --headless --quit-after 300` prints no script error.

## 8. Open questions (for the owner)

1. **Should the push wait for the enemy's attack first?** Against the Clockwork on Hard, Balanced kills more by holding the
   ramp when the Clockwork attacks at 8:00-10:00; the push leaves at the same moment and fights in the open or turns home.
   A push that goes only after a held attack (the rebuild's COUNTER after a held rush, `AITransition`) would add the
   ramp's kills to the push's. Which does the owner prefer: the push on its own timing (now), or right after a held attack?
2. **The march is slow**: 50-90 s from the gate to the first defence on the big maps (the guns at 38 px/s, limbered, one at
   a time through a ramp Gate one cell wide). The computer gives a gun a second horse (+12%); a third and fourth (+36%) cost
   a horse each. Should the siege plan harness four?
3. **Clocktowers are poor targets** (2,000 health): the push spends minutes on one; the guns already prefer turrets, the
   workers mending and the production around it when they are in reach. Should the push skip a Clocktower and go for the
   Cog Presses and the Light Works first (the Clockwork's economy, its exposed income: design_principles 2)?
4. **Against the Brood the push rarely goes** (1.5 times the Brood army it knows). When it went it broke the nest at almost
   no cost. Lower the edge against the Brood when the scout saw mostly rooted creatures (the Brood Economy plan), keep it
   against its Timing plan?
5. **There is no Clockwork turtle to break**: the owner ruled on 2026-11-03 that static defence is not a build, so the
   Clockwork computer's turrets (two by 7:00 on Hard, by its main) were the only turrets the push met in a game, and the
   test (`tools/test_crown_siege.gd`) is where it breaks two. When the reactive turrets come (cw-builds-a's merge), the push's
   target order (turrets first, then the menders) is ready for them.
6. **Merging with crown-builds-a / -c**: this branch adds one entry at the end of `AICrown.PLANS` and one at the end of
   `AI.STRATEGIES` (`"siege"`, `"crown_only"` with its filter in `strategies_for`), five hooks at the end of `ai_crown.gd`
   and the gun's gold in `_think_stage`; the lobby tooltip's text gained "Siege push is Crown only" (`main.gd`,
   `multiplayer_menu.gd`, `tools/i18n/52_crown_siege.txt`): a parallel Crown plan will touch the same lines.

## 9. Proposals (balance: not changed here, the owner decides; design_principles.md 1 and 2)

1. **The Powder Wagon's blast** (round B of the rebuild: it killed its own line). The push keeps it 150 px behind the guns
   and out of the line; the guns still stand within its blast (110 px) when they walk back to refill. A smaller blast for
   friends, or kegs that do not go off when the wagon dies to melee, would let it stand by the guns (a punishment that
   matches the mistake).
2. **The Field Cannon outranges every defence by more than double** (430 against a Ratchet Turret's 200, the Rootmaw's 30):
   with spotters it can shell a turret, a Clocktower or a rooted creature where nothing can answer but the army. That is
   the push's point and it is fair while the army can come at the guns (it did in every game). If the owner finds the push
   too strong once the Clockwork has reactive turrets, the turret's range (200 -> 240) is the counter to look at first, not
   the cannon's.
3. **The Mortar's least range (160) and a slow shell** make it a poor field gun: the push gives it only still targets
   (buildings, rooted creatures). No change proposed; noted for the owner's picture of the Mortar.

## 10. Play it again

    # a coached, filmed game on the siege plan (side 0), the opponent on Hard
    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_crown_siege.gd -- \
        b:clockwork sb:economy map:highmoor seed:5 out:/abs/dir end:780 [coach:balanced]
    python3 -I tools/play_brood_new_gif.py /abs/dir            # the clips as GIFs
    python3 -I tools/play_crown_siege_table.py /abs/round_dir   # a round's table
    godot --headless --fixed-fps 30 --script res://tools/test_crown_siege.gd
