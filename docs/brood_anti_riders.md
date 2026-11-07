# The Brood computer against the Horseman rush (brood-anti-riders, 0.33.5)

The owner played his Horseman rush (Crown, by hand) against the Hard Brood OPTIMAL on Hollowfen
(v0.33.3, seed 3233604515; log: `docs/playtests/2026-11-06/brood_v_horseman_rush_hollowfen_log.txt`) and said:
"I think the Brood needs to improve its defensive strategy against the Horseman rush." The rule it must follow
(docs/design_principles.md, section 5): a rush is a gamble; it must beat an opponent who does nothing and lose to a
proper defence.

## What was wrong, and why

| In the log | Why (the code before) |
|---|---|
| **A late read.** UNKNOWN at 3:00, NORMAL at 3:49 ("0 production, 115 of army seen"), one second before 3 riders hit at 3:50. | The OPTIMAL Brood's watching grub went to the **foot of the Crown's ramp** and never looked into the main, so the Horse Breeder (done at 1:15) and the missing Powder Mill were never seen. Riders seen at the foot did not count either: the rush evidence counted fast units only **22 tiles from the enemy's start**, and the foot of the ramp is nearer than that. A watcher that saw any soldier walked **home** (it was gone from the foot for a minute and more). |
| **The defence ran away from the grubs.** "pulls its defenders back to the Mother: 100 against 345". | The home defence met any group the same way: too strong away from the Mother, the warriors fell back to the **far side** of her, and the grubs at the Rootmaws stayed in the field. |
| **Workers fighting cavalry.** "9 grubs gang up on a Horseman" (4:12); the Brood lost 25 units in that minute and killed 1; workers 21 -> 15 -> 13. | Grubs ganged up whenever 5 or more were near a rider and won on paper with 60% of their health to lose: a Horseman's sabre still kills one in three blows, and the next rider came along. |
| **Swamps lost.** Two Rootmaws uprooted at 4:08 and 4:10. | The Mother got up for the riders (a "big" attack at her with no army near), and her swamp went with her. |
| **No turtle, wrong turtle.** "ALARM: no Mound Turtle gets up: its turtles feed the Rootmaws' swamp" (4:41), one rooted in front of the natural at 5:14. | The ALARM (an army out of the enemy's main) counted the riders and tried to root a turtle in front of the natural, which does nothing against riders: a rooted turtle does not bite and riders ride round it. |
| **No recovery.** "holds its army at home and lays warriors" for minutes: 31 then 51 Raptors by 7:00 on 13 workers. | Riders set the generic RUSH evidence: grubs capped at 14 before 5:00, warriors before grubs, the army held home, for 3 minutes from the last sighting, and the alarm renewed itself each time a rider showed. |

## What changed (scripts/ai_brood_new.gd, Brood only)

1. **The rider read** (`_nb_riders_seen`, `rider_read`). Before 5:30, from what its creatures see:
   an enemy **Horse Breeder before 4:00 with no Powder Mill seen** (or the Mill seen after it), **riders out of the
   enemy's main** (past the foot of its ramp: one before 4:00, two later), **a Horseman** (or two horses) before 4:00, or
   at worst riders in its land. It says `rider read: ...` and reads AGGRESSIVE ("a Horse Breeder or riders early"):
   OPTIMAL plays Balanced and defends first. Riders no longer set the generic rush evidence or the ALARM.
2. **The watcher looks** (`_nb_watch_scout`). Against the Crown, the first watching grub walks **round the Crown's
   main once** (the hall, its sides, its back) before it settles at the foot of the ramp; a walled ramp ends the look at
   once. Against the Crown the first watcher goes at 0:40 in every eco plan (the Economy's went at 1:10 and arrived
   after the Breeder was hidden behind a Horseman). Seeing soldiers, a grub that is not hurt **backs off 10 tiles and
   comes back** when they have gone (its look round the main goes on), instead of walking home.
3. **The answer while riders are about** (`_riders_on`: the read for up to 3 minutes before they come, or 2+ riders in
   its land in the last 40 s):
   - **Raptors in time**: the Tyrant Sire's lure goes down 45 s before the plan's own time (not at the read: food spent
     at 1:40 cost 4-5 grubs at 3:00); once he stands, while its army at home is worth less than the riders it expects
     (`_rider_need`: the riders seen alive, at least 3 while it reads a rush, 115 each; half of it until they are seen
     on the road or in its land) its eggs are warriors and the Mother's growth waits. No Sire researches before the
     riders have come or while it is short (Bigger Clutch at 3:29-3:33 had stopped every Raptor egg for 40 s in three
     games), and the Venom Sire (with riders about it came at once) waits for the Raptors it is short of.
   - **Grubs to safety**: a grub a rider comes within 8 tiles of (5 outside a raid), and the grubs of a Rootmaw a rider
     is at, run to the warriors' guard (or the Mother); grubs working next to a guard of 200 or more only run from a
     rider right at them. They go back to work once their Rootmaw is clear (8 s, at most 40 s).
   - **No gang-ups**, except on a lone rider under half its health with 6 grubs or more in reach, or as a last resort
     with no warriors at home (8 grubs or more a rider).
   - **The warriors guard the grubs, no chase** (`_nb_defend_riders`, for a group that is mostly riders): at the
     threatened Rootmaw when they beat the riders there clearly, else by the Mother on their side; they go for riders
     within 12 tiles of the guard or at a grub and walk back past 15 tiles (a Horseman at 112 outruns a Raptor at 96).
     Worth 2.5 times the riders or more, the guard pushes them off its land (20 tiles, leash 24) and the grubs run only
     from a rider right at them (two riders kited 17 Raptors round Dune Sea for two minutes and kept the grubs running).
     The Sires stay on their nests.
   - **The Mother stays rooted** against riders while her warriors there are worth half of them (her swamp feeds the
     Rootmaws round her); with no warriors she still gets up and fights for the grubs huddled by her.
   - No wave goes out while it is short of warriors against them. A lone rider (or an Officer) by the Mother no longer
     stops the grub eggs when the warriors there beat it.
4. **The recovery**: no 2 riders in its land for 40 s and it says `the riders are gone: its grubs back to work, back to
   its plan`; the warriors wanted fall back to the plan's own (`_under_armed`), grubs on the curve again, no grub cap.
   A lone rider afterwards is a harass (the guard and the grubs' own flight), not a new lockdown. The generic RUSH
   evidence (an army near the Mother, fast warriors) now lays warriors first, caps the grubs and stops new ground only
   while its army at home is short of 1.2 times the biggest enemy army seen since (300 at least), not for 3 minutes
   flat; an Officer (a Horseman off his horse) is not counted as rush evidence.

The AI STORY tells it (scripts/ai_story_lines.gd, tools/i18n/58_brood_anti_riders.txt in pt and es): the read and what
it saw, the riders in its land, the guard, the riders gone.

## Numbers

`tools/measure_brood_v_riders.gd`: a Hard Crown on its Horseman rush plan against a Hard Brood, OPTIMAL and Economy,
on Hollowfen (the owner's seed 3233604515 and seed 7), Dune Sea, Greenhold and Red Coast (seeds 1 and 2), 10 minutes
each: 0.33.4 (before) against 0.33.5 (after). "Lost" counts the Brood's units lost from the riders' first arrival to two
minutes after; "read before the hit" for 0.33.4 is its rush evidence (it had no rider read).

| averages (8 games each) | OPTIMAL 0.33.4 | OPTIMAL 0.33.5 | Economy 0.33.4 | Economy 0.33.5 |
|---|---|---|---|---|
| read before the riders' hit | +6 s (-2 to +13) | **+136 s** (128 to 139) | +5 s (-1 to +10) | **+138 s** (129 to 158) |
| units lost in the raid (grubs) | 11.2 (7.8) | 8.9 (**4.8**) | 11.4 (6.4) | 11.5 (6.4) |
| riders killed / sent by 8:00 | 2.4 / 5.1 | 1.2 / 4.1 | 2.0 / 5.5 | 1.4 / 4.5 |
| grubs at 5:00 | 18.1 | 18.6 | 17.5 | 19.8 |
| grubs at 8:00 | 32.0 | **45.6** | 38.4 | **53.5** |
| mobile army at 8:00 | 1,654 | 617 | 1,379 | 702 |
| food earned by 10:00 | 9,966 | **10,737** (+8%) | 11,074 | **11,747** (+6%) |
| the Crown's gold by 10:00 | 6,698 | 6,080 | 6,460 | 6,080 |

The read now comes from the first watcher's look round the Crown's main at 1:33-1:41 (the Horse Breeder, no Powder
Mill), more than two minutes before the riders arrive (3:43-4:12). The Crown computer's own log calls its rush FAILED
("the defenders are worth more than the riders") in most games. Fewer riders die: they meet a guard and ride off
instead of riding into a Raptor ball in the field; the guard does not chase them. The Brood's army at 8:00 is smaller
because it no longer lays Raptors for three minutes after the riders have gone: the food went into grubs (+40% at 8:00)
and the income at 10:00 is higher.

Game by game (before -> after):

| map, seed | Brood plan | read before the hit (s) | lost in the raid (grubs) | riders killed / made | grubs 5:00 | grubs 8:00 | army 8:00 | food earned by 10:00 |
|---|---|---|---|---|---|---|---|---|
| hollowfen 3233604515 | optimal | -2 -> +128 | 12 (7) -> 9 (7) | 4/5 -> 2/3 | 21 -> 24 | 28 -> 54 | 1900 -> 840 | 9251 -> 11705 |
| hollowfen 7 | optimal | +0 -> +139 | 17 (12) -> 8 (6) | 2/5 -> 1/5 | 16 -> 22 | 27 -> 54 | 1675 -> 1135 | 8048 -> 11007 |
| dune_sea 1 | optimal | +13 -> +136 | 7 (7) -> 8 (2) | 2/5 -> 1/4 | 16 -> 14 | 28 -> 38 | 1625 -> 250 | 9198 -> 9306 |
| dune_sea 2 | optimal | +13 -> +137 | 10 (6) -> 17 (5) | 2/5 -> 2/5 | 18 -> 15 | 39 -> 47 | 1525 -> 425 | 12341 -> 11448 |
| greenhold 1 | optimal | +13 -> +137 | 11 (5) -> 6 (4) | 0/4 -> 1/4 | 18 -> 16 | 25 -> 40 | 1375 -> 75 | 8521 -> 9793 |
| greenhold 2 | optimal | +12 -> +137 | 7 (5) -> 8 (4) | 0/4 -> 1/4 | 21 -> 17 | 48 -> 42 | 1175 -> 625 | 12633 -> 9991 |
| red_coast 1 | optimal | -1 -> +134 | 17 (11) -> 6 (5) | 6/7 -> 1/4 | 16 -> 16 | 25 -> 41 | 1600 -> 290 | 8716 -> 10436 |
| red_coast 2 | optimal | -2 -> +136 | 9 (9) -> 9 (5) | 3/6 -> 1/4 | 19 -> 25 | 36 -> 49 | 2355 -> 1295 | 11017 -> 12213 |
| hollowfen 3233604515 | economy | -1 -> +136 | 14 (9) -> 23 (11) | 3/6 -> 3/5 | 25 -> 15 | 48 -> 50 | 1195 -> 350 | 11616 -> 12534 |
| hollowfen 7 | economy | +9 -> +129 | 11 (6) -> 4 (4) | 2/4 -> 1/3 | 17 -> 19 | 46 -> 55 | 1175 -> 275 | 12221 -> 10550 |
| dune_sea 1 | economy | +7 -> +158 | 14 (6) -> 9 (7) | 4/6 -> 1/4 | 15 -> 25 | 41 -> 57 | 1200 -> 1005 | 11148 -> 12190 |
| dune_sea 2 | economy | +10 -> +138 | 8 (6) -> 9 (6) | 1/8 -> 1/6 | 16 -> 20 | 44 -> 56 | 1140 -> 690 | 11529 -> 12165 |
| greenhold 1 | economy | +6 -> +135 | 12 (5) -> 20 (6) | 1/5 -> 4/7 | 16 -> 14 | 33 -> 51 | 1475 -> 325 | 10917 -> 11359 |
| greenhold 2 | economy | +7 -> +136 | 11 (5) -> 11 (6) | 1/4 -> 0/4 | 15 -> 20 | 26 -> 52 | 1495 -> 850 | 8695 -> 12410 |
| red_coast 1 | economy | +0 -> +136 | 11 (6) -> 10 (6) | 2/6 -> 0/3 | 20 -> 24 | 35 -> 55 | 1950 -> 980 | 11060 -> 11748 |
| red_coast 2 | economy | -1 -> +139 | 10 (8) -> 6 (5) | 2/5 -> 1/4 | 16 -> 21 | 34 -> 52 | 1405 -> 1140 | 11406 -> 11022 |

A Brood that ignores the rush is what 0.33.4 was: it read the rush as it hit and lost 7-17 units, 5-12 of them grubs,
in two minutes (the owner's game: 25 units and 8 of 21 grubs). The rush still hurts that Brood.

Against the Crown's OPTIMAL (it walls its ramp at once, reads the Brood as GREEDY and then builds the Horse Breeder and
sends its riders: the punish it plays against the Brood), 4 maps, seed 1 (Hollowfen: the owner's seed), 10 minutes:

| averages (4 games each) | OPTIMAL 0.33.4 | OPTIMAL 0.33.5 | Economy 0.33.4 | Economy 0.33.5 |
|---|---|---|---|---|
| read before the riders' hit | -1 s | +44 s (-1 to +152) | +5 s | +44 s (-2 to +157) |
| units lost in the raid (grubs) | 11.2 (7.2) | 11.5 (8.2) | 14.8 (8.0) | 11.2 (7.0) |
| grubs at 5:00 / 8:00 | 22.2 / 39.5 | 26.5 / 53.2 | 23.0 / 40.2 | 27.0 / 55.8 |
| food earned by 10:00 | 10,855 | **13,475** (+24%) | 11,666 | **12,790** (+10%) |

Here the walled ramp keeps the watcher's look out (its Breeder goes down after the read, behind the wall), so the read
comes from the riders leaving past the foot of the ramp (+7 to +14 s) or at the hit; the raid costs about what it cost
before, but the Brood's economy comes back sooner (grubs on the curve again, no three minutes of Raptors only).
These 8 games ran on the final code (with the watcher's quick return, below); the 16 rush games above ran on the code
just before it (the only change after them: a watcher that walked home unhurt goes out again 20 s later, not 60, until
the riders are read).

To 15:00 (the Crown's rush plan against the Brood's OPTIMAL; the smaller army at 8:00 is no weakness later):

| map, seed | 0.33.4 | 0.33.5 |
|---|---|---|
| Hollowfen 3233604515 | the Brood wins at 10:00 | the Brood wins at 13:14 |
| Dune Sea 1 | no winner at 15:00 | the Brood wins at 14:20 |
| Greenhold 1 | no winner at 15:00 | the Brood wins at 11:52 |

## Tests

- `tools/test_brood_v_riders.gd` (new): a Hard Brood OPTIMAL on Hollowfen, the Crown's computer off. **read**: a Horse
  Breeder in the Crown's main; the first watcher reads the riders by 3:00. **raid**: at 3:30 three Horsemen ride in and
  hunt grubs (scripted like the Crown's raid: the nearest grub within 20 tiles, home under half health): at most 3 grubs
  lost, the riders die or leave, no grubs on a healthy rider, the warriors within 22 tiles of the Mother, the Mother
  rooted, the read before the hit, the story lines, and grubs laid again after.
- `tools/measure_brood_v_riders.gd` (new): one line of numbers per game (see above).
- Run and passing: `tools/test_brood_v_riders.gd` ALL PASS (read at 1:41; 6 of 15 grubs lost to riders
  that fight on to half their health, 1 rider dead and 2 sent home), `tools/test_files.gd` (1303 checks, 0 failures),
  `tools/test_i18n.gd` PASS, `tools/test_brood_new.gd` (0 failures), `tools/test_ai_optimal.gd` ALL PASS,
  `tools/test_ai_scout.gd` ALL PASS.

## Claude's choices for the owner

- **No Mound Turtle in front of the worker lines.** The job asked for one on the read. A rooted Mound Turtle does not
  bite and riders ride round it; the only turtle the code moved (the ALARM's, in front of the natural) uprooted a turtle
  that fed the Rootmaws' swamp. What protects the swamp is the Mother staying rooted (above) and the ALARM no longer
  counting riders. Say if you want a turtle rooted by the Rootmaws anyway (a body in the riders' way).
- **Raptors, not Spitters, as the answer.** Raptors are the cheapest real answer and come from the Tyrant Sire every
  opening has (2 for 50 food); Spitters need the Venom Sire (200 food and 25 spoils) and the Horseman has a 1.3 bonus
  against them. With riders about the old rule (a Spitter for every Raptor once the Venom Sire stands) stays. The Mist
  Toad's TONGUE comes too late (her stage 3) to matter against a 3:40 rush.
- **How many Raptors**: the riders it expects (at least 3) at 115 each, half of it before they are seen coming; about
  7 Raptors before, 14 once they come (60% from the read cost the Economy plan 15% of its income by 10:00). Less and the riders win the fights at the grubs; more and the Brood's economy at
  4:00 falls behind the riders' damage.
- **The read from one Horseman** before 4:00 counts. A Crown that is not rushing seldom has a Horseman out that early
  (its rider scouts wait for the first gun against the Brood); if it does, the cost is a few Raptors early.
- The watcher's look round the main is for the Crown only (the Clockwork's watcher already explores its main).

## Open questions

- A Crown that walls its ramp in the first minute (the owner did: a Gate piece at 0:40; the Crown's OPTIMAL does too)
  shuts the look out: the read then comes from the riders leaving past the foot of the ramp (7-14 s before they arrive
  in the measured games), or only at the hit when the watcher was away. A watcher standing farther out on the road, or a
  second one at the natural, would see them sooner; not tried.
- The Brood's mobile army at 8:00 is about half of what it was (it no longer lays Raptors for minutes after the riders
  have gone). In the three 15-minute games it won every time, sooner than before; against a Crown that times a real army
  at 8:00 this needs watching.
- The Crown computer's riders mostly kite the guard (few are killed): the rush fails (its own log says "FAILED: the
  defenders are worth more") but costs the Crown little. A Brood that wants to punish it needs Spitters or the Toad.
