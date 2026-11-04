# The Clockwork computer's builds, set A: the Clock Soldier rush and the Turret turtle (0.28.5, branch cw-builds-a)

Short sentences, to be read aloud.

The owner, 2026-11-03: "do it all". Two new plans for the Clockwork's own computer (scripts/ai_clockwork.gd, the framework
of docs/clockwork_ai_rebuild.md), each a written opening build order, each coached in filmed games like the Springer timing:
1. THE CLOCK SOLDIER RUSH: early Light Works, Clock Soldiers with Winder escorts, a real attack on the enemy's workers, and a
   turn to the economy if it fails, with no trickle of soldiers.
2. THE TURRET TURTLE: Ratchet Turrets at the ramp early, a FAST second Clocktower behind them, then a strong mid-game army.
   Safe against rushes, and out-earning the enemy.

Design rules followed (docs/design_principles.md): rule 5, a rush is a gamble that must lose to a proper defence (a wall
and a few Musketeers) and beat an opponent who did nothing; rule 1, no cheating (the computer sees what its side sees; a
wall counts as seen only when our side sees the enemy's gate or wall); rule 2, retreat is possible and a lost rush is a lost
territory, not a lost game. No unit, building or research number was changed; balance ideas are proposals below.

## THE OWNER'S DECISION ON THE TURTLE (merged as 0.29.6, 2026-11-04)

The owner rejected the Turret turtle AS A STRATEGY (CLAUDE.md, 2026-11-03 21:45): "Good base design should be for all
builds. Static defense isn't a good strategy on its own: it is either a desperate attempt to hold a rush or a later
security against harass so you can concentrate your army."

- What was merged: the Clock Soldier rush, as a plan anyone can pick (and RANDOM PLAN).
- The Turret turtle is NOT offered: its row in AI.STRATEGIES is marked "hidden", so no lobby (skirmish or online), no
  RANDOM PLAN and no computer picks it; a hidden plan sent by a guest or found in a slot plays Balanced. Only the coaching
  tools here (tools/test_clockwork_builds_a.gd, tools/play_clockwork_builds_a.gd) can still run it, through a match cfg with
  "hidden_plans". Its code (scripts/ai_cw_builds_a.gd, PLANS["turtle"] in scripts/ai_clockwork.gd) and this doc are kept
  for now.
- Worth knowing: in these coached games it was the STRONGEST Clockwork plan (the most Winders and cogs against the Hard
  Crown, the only Clockwork plan that lost no game to the Hard Brood by 10:00; numbers below). Much of that likely comes
  from its base layout and fast second Clocktower, not from the turrets as such.
- What is to become SHARED rules for every Clockwork plan (a later job): its base layout (production behind the hall, the
  Regulator and buildings toward the ramp) and turrets only as a REACTION: an emergency against a scouted or arriving
  rush, and later at expansions and worker lines against harass so the army can leave home. The fast second Clocktower
  may become the Clockwork's Economy plan.

## The short version

- **Turret turtle: the best Clockwork plan in these games.** Two turrets by the ramp's top at about 1:50 and 2:15, the
  second Clocktower laid at about 2:05 (Balanced: 3:36 to 4:07). Against the Hard Crown it had 25.7 Winders at 6:00
  (Balanced 22.7) and earned 15% more cogs by 6:00 and 19% more by 8:00. It lost no building to the Crown. Against the
  Hard Brood it was the only Clockwork plan that lost no game by 10:00 (Balanced lost 2 of 3, the old Rush 2 of 3, the
  Clock Soldier rush 3 of 3); it killed 4,111 value there, against 2,325 for Balanced.
- **Clock Soldier rush: on time, and it hurts the Crown's economy, but against the Hard Crown it never breaks in.** Six
  Clock Soldiers leave at 2:43 to 2:53 and reach the Crown's ramp at 3:26 to 3:43. The Hard Crown walls its ramp with a Cottage and a gate by
  about 0:40, and when its scout sees the two Works (about 1:25) it switches to defence. So in every measured game the rush was called FAILED at the wall, at
  3:52 to 4:03. It now walks away cheaply: by 10:00 it lost 1,075 value, against 2,115 for the old Balanced plan. And the
  Crown, busy defending, earned 37% less gold by 8:00 than against Balanced (4,306 against 6,840). In one filmed game on
  Kestrel Rise (round A) the soldiers did get in: the Crown was left with one Labourer at 6:00.
- **Against the Brood the rush loses.** By 3:40 the Hard Brood has 450 to 600 value of creatures, and a rooted defender on
  its ramp. The rush dies there, and the Clockwork lost all three measured games by 10:00 (so did the old Balanced plan in two
  of three). See "What is weak".
- (As written by the job, before the owner's decision above:) both plans could be picked as a Clockwork computer's plan:
  "Clock Soldier rush" (pt "Ataque de Soldados-Relógio", es "Ataque de Soldados Reloj") and "Turret turtle" (pt "Tartaruga
  de Torretas", es "Tortuga de Torretas"). Since the merge only the Clock Soldier rush is offered. The old plans play as before.

## The architecture

- Everything new lives in its own file, `scripts/ai_cw_builds_a.gd` (the rush party, the turret and relay placement, the
  plans' own steps), made by AIClockwork as `bta`. In `scripts/ai_clockwork.gd` the additions are self-contained: the two
  PLANS entries, one dispatch line in `_do_step` (`bta.step(i, parts)` for the steps it knows), `bta.tick()` in `_army`, and
  `bta.has(u)` in `_on_errand` / `_held_worker`. The Springer raid, cw-builds-b and cw-builds-c should merge round it.
- New build-order steps (besides the shared ones: supply numbers, buildings, `workers N`, units, `end`):
  - `rush`: the rush party goes out, once the plan's `rush` Clock Soldiers stand at home.
  - `rush_over`: waits until the rush is judged (FAILED or SUCCEEDED). The steps after it are the economy.
  - `turret ramp` / `turret hall2`: a Ratchet Turret by the top of the main's ramp, or on the enemy's side of the newest
    Clocktower (it waits until that Clocktower stands).
  - `ramp_regulator`: the plan's Regulator, laid toward the ramp's top: a stepping stone for the gear field.
  - `works_back`: the Light Works on the far side of the main Clocktower from its ramp.
- After `end` the shared computer plays on, on the plan's row in `AI.STRATEGIES`: the rush on Balanced numbers (its failed
  rush has already held the waves back: no wave for 90 to 150 seconds, and not before 24 supply), the turtle on its own
  row: first wave at 24 supply (Balanced 14), waves 10 apart, expansions a little sooner (0.8), tech a little sooner (0.9),
  15% more Winders.

## The Clock Soldier rush ("cs_rush")

### The build order

| # | step | what it means |
|---|---|---|
| 1 | 6 movement_works | the first Light Works at 6 supply (about 0:13; done 0:55) |
| 2 | 7 cog_press | the second Cog Press (the income for two Works) |
| 3 | 9 regulator | supply |
| 4 | 9 movement_works | the second Light Works |
| 5 | workers 12 | Winders up to 12 (11 before) |
| 6 | clock_soldier 6 | six Clock Soldiers from both Works |
| 7 | rush | the party goes out: the six, and two Winders to wind and mend them |
| 8 | 16 regulator | supply |
| 9 | clock_soldier 6 | six more; they follow the party three at a time, never one by one |
| 10 | rush_over | waits for the verdict |
| 11 | turret ramp | a turret at home (the army is out or lost) |
| 12 | mainspring | the Mainspring, and three Winders on it |
| 13 | workers 20 | the economy |
| 14 | clocktower | the expansion |
| 15 | escapement | tech |
| 16 | end | the shared computer plays on |

### The rush (scripts/ai_cw_builds_a.gd)

- GATHER a little in front of home, then MARCH on the enemy's economy (its nearest hall, or an open expansion the shared
  computer has found). A force met on the way that is stronger than the party: FAILED at once, home whole.
- THE WALL. Once our side sees the enemy's gate or wall near the party (or the way in is shut), the party asks: is it
  HELD? Held means two or more workers mending it, or guns seen near it worth more than 60% of the party. A held wall is
  not charged. The soldiers drop targets they cannot reach (a Musketeer behind the wall) and back off out of the muskets'
  reach. If nothing is being killed outside the wall for 20 seconds (at most 40), the rush is FAILED.
- A thin wall (no menders, few guns) is broken: the soldiers attack-move and the unit's own wall rule hacks the piece.
- UP THERE: each soldier cuts down a worker who is mending a wall or gate within 7 tiles first (repair is not nerfed: it is
  to be dealt with), then the nearest worker seen within 10 tiles that it can walk to, staying near the party. Fights with
  soldiers go on. With no worker in sight: on to the economy.
- THE CRANKS: the two Winders keep about 90 px behind the party, toward home. They wind the most run-down soldier and mend
  the hurt, and step away from armed enemies.
- THE VERDICT, from facts, as the shared rush's: FAILED when it is losing the trade (lost 35% of what it sent and killed
  less than half of that), beaten back (two or fewer left), facing a defence worth 30% more than the party, no headway in 90
  seconds, or out of time at 150 seconds. SUCCEEDED when it has killed 80% of what it sent. Succeeded, it keeps hunting,
  and with no worker left it hits the nearest building, all on the same one. It goes home at two left.
- THE WATCH AT THE FOOT. After a held wall, a party of four or more does not walk straight home: for up to 75 seconds it
  stands out along the enemy's ramp, 6 tiles from its foot, and kills the workers who come out (the expansion's builders)
  and whatever it can reach. It leaves when the enemy's army comes out stronger. The Crown's Musketeers did come out to
  chase it in the films, and fought in the open.
- FAILED also tells the shared computer: no wave for 90 to 150 seconds, and none smaller than 24 supply. That is the
  "no trickling".

## The Turret turtle ("turtle")

### The build order

| # | step | what it means |
|---|---|---|
| 1 | 7 cog_press | the second Cog Press |
| 2 | 8 ramp_regulator | the Regulator, toward the ramp's top |
| 3 | works_back | the Light Works behind the Clocktower, room kept for a Mainspring |
| 4 | turret ramp | the first turret by the ramp's top (about 1:50) |
| 5 | workers 16 | |
| 6 | clocktower | the FAST second Clocktower (laid at about 2:05) |
| 7 | turret ramp | the second turret, pushed aside by the first one's 4-tile circle (about 2:15) |
| 8 | clock_soldier 2 | two Clock Soldiers |
| 9 | workers 22 | |
| 10 | turret hall2 | a turret by the new Clocktower, once it stands |
| 11 | mainspring | |
| 12 | crew mainspring 3 | |
| 13 | escapement | |
| 14 | workers 26 | |
| 15 | end | the shared computer plays on, on the turtle's numbers |

### Where the turrets go

A turret must stay linked to the gear field to fire, and its ring must mesh with a gear building of ours on the same ground
level. Its reach is 200 px (6.25 tiles). Two turrets' 4-tile circles may not overlap.
- The target is one tile in from the top of the main's ramp. Every gear building of ours on that level is tried (the 8
  nearest), and the turret goes where its ring meshes with one and lies nearest the target.
- Round A showed the gear field ended short of the ramp: the Light Works had been laid right above the ramp, its big ring
  took the room, and the turret stood about 300 px from the ramp's top, out of reach (picture 6). So the turtle now lays its
  Regulator toward the ramp first (a stepping stone for the field) and its Works behind the Clocktower. The first turret then
  stood 50 to 142 px from its target on every map (Kestrel Rise and Frostmere 50, Greenhold 142).
- The second ramp turret is pushed aside by the first one's circle. On all three maps it ended 270 to 279 px from its target: it covers the main's flank, not the ramp. The turret by the second Clocktower then stands near the ramp's
  foot, so the ramp is still covered from above and below.

## The coached games

### Round A (filmed: Greenhold, Kestrel Rise, Frostmere; Crown and Brood)

What the films showed, and what was changed:
- The first rush build had one Cog Press and two Works: the Winders stopped at 8 and the soldiers came no sooner (first one
  at 1:43 either way). Now the second press comes first: 2,600 cogs earned by 4:00, as Balanced.
- The Hard Crown walls its ramp with a Cottage and a gate by about 0:40, and sees the two Works by 1:25. The rush hit the
  gate under three Musketeers and lost five of six for nothing (pictures 2 and 13). Now: the held-wall rule, the back-off,
  the watch at the foot.
- "Held" flickered as the menders came and went: the party stayed 50 to 70 seconds at the wall. Now it stays held for 8
  seconds after the last sign, and the 20-second clock starts once.
- Fresh soldiers walked into the held wall to join the party. Now none join while it is held.
- Two soldiers chased a lone scout Labourer across the map. Now the party keeps together.
- On Kestrel Rise the rush got in and killed eleven Labourers, then stood for three minutes on an empty spot: its target was
  worked out once, at the start, and that building was gone. Now the target is worked out again every 8 seconds, and a
  successful party with no worker in sight hits the nearest building.
- Against the Brood the soldiers died on the Brood's ramp to a rooted defender and Raptors, then the shared computer was
  overrun. Now: a stronger force met on the way ends the rush at once, a losing trade ends it early, and after the rush a
  turret and the Mainspring come before the expansion. It still loses (below).
- The turtle's turrets stood out of reach of the ramp (picture 6): the Regulator and the Works moved (above).

### Round B (the measured games)

Hard Clockwork against the Hard Crown or Brood computer on Balanced, seed 11, 10 minutes, Greenhold, Kestrel Rise and
Frostmere. The old Balanced and old Rush plans in the same games for comparison. tools/test_clockwork_builds_a.gd,
tables by tools/clockwork_builds_a_report.py. One game per row: fights vary a lot from game to game.

"Foe workers lost" counts the enemy's workers that disappeared: for the Brood that includes grubs that became creatures, so
it means little there.

### When things happen

| map, seed | foe | plan | Works | 5th soldier | rush out | arrives | verdict | 1st turret | 2nd turret | 2nd hall laid | 2nd hall up | Mainspring |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| frostmere 11 | brood | old Balanced | 1:38 | 2:35 | 4:38 (wave) | never | never | 5:23 | 7:35 | 4:10 | 5:19 | 4:19 |
| frostmere 11 | brood | Clock Soldier rush | 0:55 | 2:34 | 2:53 | 3:43 | FAILED 3:58 | 3:32 | 7:20 | 4:19 | 5:32 | 4:00 |
| frostmere 11 | brood | old Rush | 1:35 | 2:33 | 2:47 (wave) | never | never | 4:58 | never | 5:01 | 6:10 | 4:09 |
| frostmere 11 | brood | Turret turtle | 1:50 | 4:00 | never | never | never | 2:24 | 2:52 | 2:04 | 3:14 | 3:26 |
| greenhold 11 | brood | old Balanced | 1:37 | 2:37 | 5:31 (wave) | never | never | 5:19 | 7:17 | 4:02 | 5:12 | 4:13 |
| greenhold 11 | brood | Clock Soldier rush | 0:55 | 2:32 | 2:53 | 3:42 | FAILED 3:56 | 3:28 | 7:08 | 4:03 | 5:12 | 3:56 |
| greenhold 11 | brood | old Rush | 1:33 | 2:33 | 2:57 (wave) | never | never | 6:06 | 7:03 | 5:13 | 6:22 | 5:01 |
| greenhold 11 | brood | Turret turtle | 1:50 | 4:00 | never | never | never | 2:25 | 2:53 | 2:05 | 3:15 | 3:25 |
| kestrel_rise 11 | brood | old Balanced | 1:37 | 2:35 | never | never | never | 5:15 | never | 3:58 | 5:09 | 4:10 |
| kestrel_rise 11 | brood | Clock Soldier rush | 0:55 | 2:34 | 2:48 | 3:54 | FAILED 4:19 | 3:28 | never | 4:29 | 5:39 | 4:05 |
| kestrel_rise 11 | brood | old Rush | 1:35 | 2:34 | 2:48 (wave) | never | never | 5:20 | never | 5:17 | 6:27 | 4:23 |
| kestrel_rise 11 | brood | Turret turtle | 1:50 | 3:57 | never | never | never | 2:23 | 2:52 | 2:06 | 3:14 | 3:17 |
| frostmere 11 | crown | old Balanced | 1:38 | 2:35 | 7:24 (wave) | never | never | 4:34 | 7:48 | 3:36 | 4:46 | 3:48 |
| frostmere 11 | crown | Clock Soldier rush | 0:55 | 2:34 | 2:52 | 3:43 | FAILED 4:03 | 3:37 | never | 4:30 | 5:43 | 4:12 |
| frostmere 11 | crown | old Rush | 1:35 | 2:34 | 2:45 (wave) | never | never | 4:45 | 7:37 | 4:46 | 5:56 | 4:02 |
| frostmere 11 | crown | Turret turtle | 1:50 | 5:31 | 7:40 (wave) | never | never | 2:24 | 2:56 | 2:14 | 3:24 | 3:31 |
| greenhold 11 | crown | old Balanced | 1:37 | 2:37 | 8:38 (wave) | never | never | 4:38 | 8:01 | 3:36 | 4:46 | 3:47 |
| greenhold 11 | crown | Clock Soldier rush | 0:55 | 2:34 | 2:45 | 3:34 | FAILED 4:02 | 3:20 | never | 4:07 | 5:22 | 3:59 |
| greenhold 11 | crown | old Rush | 1:33 | 2:33 | 2:43 (wave) | never | never | 5:06 | never | 5:11 | 6:25 | 4:09 |
| greenhold 11 | crown | Turret turtle | 1:50 | 4:01 | 8:54 (wave) | never | never | 2:23 | 2:48 | 2:04 | 3:15 | 3:22 |
| kestrel_rise 11 | crown | old Balanced | 1:38 | 2:35 | 8:12 (wave) | never | never | 5:22 | 7:48 | 4:07 | 5:18 | 4:20 |
| kestrel_rise 11 | crown | Clock Soldier rush | 0:55 | 2:35 | 2:46 | 3:26 | FAILED 3:52 | 3:59 | 9:02 | 4:19 | 5:30 | 4:17 |
| kestrel_rise 11 | crown | old Rush | 1:35 | 2:32 | 2:45 (wave) | never | never | 5:13 | 7:53 | 4:18 | 5:26 | 4:20 |
| kestrel_rise 11 | crown | Turret turtle | 1:48 | 3:57 | 8:06 (wave) | never | never | 2:23 | 2:47 | 2:04 | 3:15 | 3:21 |

### Economy and fights

| map, seed | foe | plan | Winders 4/6/8 | cogs earned 4/6/8 | foe earned 4/6/8 | foe workers lost 4/6/10 | killed / lost by 6:00 | by 10:00 | buildings lost (CW / foe) | winner |
|---|---|---|---|---|---|---|---|---|---|---|
| frostmere 11 | brood | old Balanced | 15 / 22 / 16 | 2775 / 4383 / 6503 | 2479 / 5326 / 9049 | 7 / 14 / 24 | 150 / 1190 | 1125 / 7735 | 18 / 0 | foe |
| frostmere 11 | brood | Clock Soldier rush | 14 / 18 / 0 | 2435 / 3675 / 5140 | 2421 / 4356 / 7209 | 7 / 11 / 21 | 0 / 420 | 225 / 6170 | 17 / 0 | foe |
| frostmere 11 | brood | old Rush | 12 / 18 / 0 | 2324 / 3932 / 5064 | 2328 / 4638 / 7730 | 7 / 11 / 21 | 100 / 420 | 150 / 6090 | 15 / 0 | foe |
| frostmere 11 | brood | Turret turtle | 17 / 27 / 22 | 2786 / 5307 / 7069 | 2509 / 5933 / 9944 | 8 / 14 / 23 | 100 / 420 | 3995 / 5240 | 7 / 0 | none by 10:00 |
| greenhold 11 | brood | old Balanced | 15 / 20 / 27 | 2752 / 4409 / 6580 | 2318 / 5485 / 9044 | 7 / 12 / 25 | 575 / 210 | 3675 / 5840 | 3 / 0 | none by 10:00 |
| greenhold 11 | brood | Clock Soldier rush | 15 / 19 / 10 | 2586 / 3872 / 5624 | 2262 / 4590 / 7423 | 7 / 11 / 25 | 50 / 420 | 525 / 7030 | 19 / 0 | foe |
| greenhold 11 | brood | old Rush | 10 / 17 / 3 | 2259 / 3794 / 4970 | 2294 / 4495 / 6732 | 6 / 11 / 22 | 100 / 840 | 1325 / 5410 | 10 / 0 | none by 10:00 |
| greenhold 11 | brood | Turret turtle | 17 / 27 / 20 | 2777 / 5423 / 8201 | 2595 / 6104 / 10534 | 7 / 13 / 22 | 500 / 550 | 5390 / 5710 | 9 / 0 | none by 10:00 |
| kestrel_rise 11 | brood | old Balanced | 15 / 20 / 22 | 2795 / 4489 / 5829 | 2652 / 5458 / 9597 | 7 / 12 / 24 | 0 / 210 | 2175 / 6820 | 15 / 0 | foe |
| kestrel_rise 11 | brood | Clock Soldier rush | 14 / 16 / 10 | 2381 / 3721 / 5121 | 2422 / 4445 / 7300 | 7 / 10 / 22 | 400 / 770 | 1375 / 6150 | 15 / 0 | foe |
| kestrel_rise 11 | brood | old Rush | 10 / 17 / 0 | 2289 / 3900 / 4745 | 2190 / 4059 / 6468 | 7 / 10 / 18 | 200 / 700 | 300 / 5780 | 14 / 0 | foe |
| kestrel_rise 11 | brood | Turret turtle | 17 / 25 / 16 | 2796 / 5195 / 6990 | 2890 / 6353 / 10737 | 9 / 14 / 24 | 350 / 340 | 2950 / 6690 | 10 / 0 | none by 10:00 |
| frostmere 11 | crown | old Balanced | 15 / 23 / 30 | 2687 / 4409 / 6845 | 1900 / 3800 / 6460 | 1 / 1 / 2 | 165 / 60 | 870 / 2080 | 0 / 0 | none by 10:00 |
| frostmere 11 | crown | Clock Soldier rush | 13 / 17 / 21 | 2287 / 3348 / 5459 | 1520 / 2280 / 3800 | 0 / 0 / 0 | 240 / 280 | 655 / 875 | 0 / 3 | none by 10:00 |
| frostmere 11 | crown | old Rush | 12 / 17 / 24 | 2276 / 3921 / 6168 | 1140 / 2280 / 3800 | 1 / 1 / 4 | 50 / 420 | 1405 / 1685 | 0 / 2 | none by 10:00 |
| frostmere 11 | crown | Turret turtle | 17 / 24 / 30 | 2715 / 4788 / 7538 | 1900 / 3800 / 6460 | 1 / 2 / 3 | 100 / 180 | 1285 / 1825 | 0 / 2 | none by 10:00 |
| greenhold 11 | crown | old Balanced | 15 / 23 / 25 | 2675 / 4392 / 7077 | 1900 / 3800 / 7220 | 1 / 1 / 4 | 50 / 180 | 1945 / 1710 | 0 / 1 | none by 10:00 |
| greenhold 11 | crown | Clock Soldier rush | 14 / 21 / 25 | 2595 / 4169 / 6286 | 1520 / 3800 / 6080 | 1 / 1 / 1 | 50 / 340 | 360 / 1710 | 0 / 0 | none by 10:00 |
| greenhold 11 | crown | old Rush | 12 / 17 / 21 | 2180 / 3758 / 5339 | 1520 / 2660 / 4940 | 3 / 4 / 4 | 200 / 460 | 695 / 1330 | 0 / 1 | none by 10:00 |
| greenhold 11 | crown | Turret turtle | 17 / 27 / 34 | 2753 / 5217 / 8414 | 1900 / 3800 / 6460 | 1 / 2 / 2 | 100 / 120 | 940 / 2160 | 1 / 0 | none by 10:00 |
| kestrel_rise 11 | crown | old Balanced | 15 / 22 / 23 | 2741 / 4402 / 6595 | 1900 / 3800 / 6840 | 1 / 1 / 1 | 50 / 70 | 575 / 2555 | 0 / 2 | none by 10:00 |
| kestrel_rise 11 | crown | Clock Soldier rush | 13 / 19 / 29 | 2266 / 3573 / 5755 | 1520 / 2280 / 3040 | 1 / 1 / 3 | 350 / 140 | 1165 / 640 | 0 / 5 | none by 10:00 |
| kestrel_rise 11 | crown | old Rush | 15 / 20 / 30 | 2400 / 4083 / 6730 | 1520 / 1900 / 3800 | 1 / 1 / 3 | 50 / 0 | 350 / 480 | 0 / 2 | none by 10:00 |
| kestrel_rise 11 | crown | Turret turtle | 17 / 26 / 31 | 2745 / 5155 / 8393 | 1900 / 3800 / 7220 | 1 / 1 / 4 | 50 / 300 | 690 / 1785 | 0 / 4 | none by 10:00 |

### Averages

| plan | foe | games | Winders 6:00 | earned 4:00 | earned 6:00 | earned 8:00 | foe earned 8:00 | killed / lost by 10:00 | CW buildings lost | won / lost |
|---|---|---|---|---|---|---|---|---|---|---|
| old Balanced | brood | 3 | 20.7 | 2774 | 4427 | 6304 | 9230 | 2325 / 6798 | 12.0 | 0 / 2 |
| Clock Soldier rush | brood | 3 | 17.7 | 2467 | 3756 | 5295 | 7310 | 708 / 6450 | 17.0 | 0 / 3 |
| old Rush | brood | 3 | 17.3 | 2290 | 3875 | 4926 | 6976 | 591 / 5760 | 13.0 | 0 / 2 |
| Turret turtle | brood | 3 | 26.3 | 2786 | 5308 | 7420 | 10405 | 4111 / 5880 | 8.7 | 0 / 0 |
| old Balanced | crown | 3 | 22.7 | 2701 | 4401 | 6839 | 6840 | 1130 / 2115 | 0.0 | 0 / 0 |
| Clock Soldier rush | crown | 3 | 19.0 | 2382 | 3696 | 5833 | 4306 | 726 / 1075 | 0.0 | 0 / 0 |
| old Rush | crown | 3 | 18.0 | 2285 | 3920 | 6079 | 4180 | 816 / 1165 | 0.0 | 0 / 0 |
| Turret turtle | crown | 3 | 25.7 | 2737 | 5053 | 8115 | 6713 | 971 / 1923 | 0.3 | 0 / 0 |


### Reading the numbers

- Turtle against the Crown: more Winders at 4, 6 and 8 minutes than any other plan, 8,115 cogs earned by 8:00 (Balanced
  6,839). It lost one building in three games. Its first wave goes at 7:40 to 8:54 (Balanced 7:24 to 8:38) and is bigger;
  on Kestrel Rise it burned down the Crown's expansion (picture 11).
- Turtle against the Brood: the Brood still out-earns it (it out-earns every Clockwork plan), and its Raptor waves reached the
  natural in every game. But the turrets and the army held (pictures 9 and 10): 8.7 buildings lost on average, against 12
  for Balanced and 17 for the rush, and no game lost by 10:00.
- Rush against the Crown: the rush itself kills little (0 to 300 value), but the Crown's income falls behind: 4,306 gold
  earned by 8:00 against 6,840 when the Crown played Balanced. The Clockwork pays for it too (5,833 cogs against 6,839), and
  ends with fewer losses than Balanced (1,075 against 2,115 by 10:00).
- The old Rush plan (the shared computer) has its first wave at 2:43 to 2:57, about when the new rush leaves, but it fights
  with 17 to 18 Winders at 6:00 and never stops to read the wall.

## What is weak, and open questions for the owner

1. **The rush against the Brood.** By 3:40 the Hard Brood has 450 to 600 value of creatures and a rooted defender on its
   ramp; six Clock Soldiers cannot win there, and the Clockwork then loses the game (so does the old Balanced plan in two of
   three games). Should the computer not pick the Clock Soldier rush against the Brood (the "later: the computer picks its
   build by matchup" job)? For now RANDOM PLAN may still pick it.
2. **The rush against the Hard Crown never breaks in.** The Crown walls its ramp by 0:40 when it scouts the two Works. That
   is design rule 5 working (a rush must lose to a proper defence). Against a Crown that does not wall (Easy, Normal, or the
   owner by hand) it should do much better: not measured here.
3. Repairing workers: the soldiers cut down menders they can reach (2 in one game), but a mender stands behind the gate,
   out of a sword's reach. Only a ranged unit (a Springer) can shoot him there. A rush with two Springers would need the
   Mainspring and the Escapement first (about 3:30): a different build, maybe a "Springer-supported rush" job.
4. The second ramp turret (270 to 279 px from the target on all three maps) cannot reach the ramp's top: it covers the flank. Would the owner
   rather have it by the second Clocktower at once?
5. The turtle's mid game is the shared computer's (Balanced rules on the turtle's numbers): the milestone rules are not
   written yet.

## Proposals (balance: the owner's call; nothing was changed)

1. **Clock Soldier rush timing.** Six Clock Soldiers need about 2:30 even with two Works. If the owner wants a rush that
   arrives before the Hard Crown's wall, the Light Works would have to be cheaper (150 to 120 cogs) or a Clock Soldier quicker
   to make (16 s to 13 s). Not recommended without the owner's playtest: the Crown's early wall is the counter design rule 5
   asks for.
2. **The Ratchet Turret's circle (4 tiles).** With it, two turrets cannot both cover a narrow ramp's top. A 3-tile circle
   would let two turrets guard one ramp. A turtle with two turrets at 1:50 and 2:15 is already safe in these games, so this
   is only about how it looks.
3. **The Brood's early army.** Every Clockwork plan, old or new, earned about 30% less than the Hard Brood by 8:00, and three
   of the four plans lost two or three of their three games against it. That is a matchup question for the cw-builds-b job (Pendulums against the
   Brood), noted here for the owner.

## Pictures

docs/shots/clockwork_builds_a/ (captions.md says what each shows).

## Tools

- `tools/test_clockwork_builds_a.gd`: one game, a Clockwork plan against the Crown or Brood computer. Milestones, a line
  every 30 seconds, numbers at 4, 6, 8 and 10 minutes, the plan's decisions. `check:1` is the test: for `cw:cs_rush`
  (until:480) the rush leaves by 3:45, reaches the base, is judged by 7:00, 14+ Winders at 6:00, a second Clocktower by
  8:00; for `cw:turtle` (until:400) two ramp turrets by 3:30, the second Clocktower by 4:00, 22+ Winders at 6:00, no
  building lost by 6:00. `json:<file>` appends a line for `tools/clockwork_builds_a_report.py`.
- `tools/play_clockwork_builds_a.gd`: the coached, filmed game (`coach:rush|turtle|oldrush|balanced`, `foe:crown|brood`,
  `set:key=value`). It writes minutes.txt, events.txt, and pictures of the rush going out, arriving, the verdict,
  reinforcements, each turret, the base when two turrets stand, and the frames of the rush's arrival for a GIF
  (`tools/play_brood_new_gif.py`).

    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_clockwork_builds_a.gd -- \
        coach:rush foe:crown map:greenhold seed:11 out:/some/folder end:540
