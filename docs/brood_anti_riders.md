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
   once. Seeing soldiers, a grub that is not hurt **backs off 10 tiles and comes back** when they have gone, instead of
   walking home.
3. **The answer while riders are about** (`_riders_on`: the read for up to 3 minutes before they come, or 2+ riders in
   its land in the last 40 s):
   - **Raptors in time**: the Tyrant Sire's lure goes down at once; while its army at home is worth less than the riders
     it expects (`_rider_need`: the riders seen alive, at least 3 while it reads a rush, 115 each; 60% of it before they
     are seen on the road or in its land) its eggs are warriors, the Mother's growth waits and no Sire researches
     (Bigger Clutch at 3:29-3:31 had stopped every Raptor egg for 40 s in two games).
   - **Grubs to safety**: a grub a rider comes within 8 tiles of (5 outside a raid), and the grubs of a Rootmaw a rider
     is at, run to the warriors' guard (or the Mother); grubs working next to a guard of 200 or more only run from a
     rider right at them. They go back to work once their Rootmaw is clear (8 s, at most 40 s).
   - **No gang-ups**, except on a lone rider under half its health with 6 grubs or more in reach, or as a last resort
     with no warriors at home (8 grubs or more a rider).
   - **The warriors guard the grubs, no chase** (`_nb_defend_riders`, for a group that is mostly riders): at the
     threatened Rootmaw when they beat the riders there clearly, else by the Mother on their side; they go for riders
     within 12 tiles of the guard or at a grub and walk back past 15 tiles (a Horseman at 112 outruns a Raptor at 96).
     The Sires stay on their nests.
   - **The Mother stays rooted** against riders while her warriors there are worth half of them (her swamp feeds the
     Rootmaws round her); with no warriors she still gets up and fights for the grubs huddled by her.
   - No wave goes out while riders are in its land.
4. **The recovery**: no 2 riders in its land for 40 s and it says `the riders are gone: its grubs back to work, back to
   its plan`; the warriors wanted fall back to the plan's own (`_under_armed`), grubs on the curve again, no grub cap.
   A lone rider afterwards is a harass (the guard and the grubs' own flight), not a new lockdown.

The AI STORY tells it (scripts/ai_story_lines.gd, tools/i18n/58_brood_anti_riders.txt in pt and es): the read and what
it saw, the riders in its land, the guard, the riders gone.

## Numbers

RESULTS_HERE

## Tests

- `tools/test_brood_v_riders.gd` (new): a Hard Brood OPTIMAL on Hollowfen, the Crown's computer off. **read**: a Horse
  Breeder in the Crown's main; the first watcher reads the riders by 3:00. **raid**: at 3:30 three Horsemen ride in and
  hunt grubs (scripted like the Crown's raid: the nearest grub within 20 tiles, home under half health): at most 3 grubs
  lost, the riders die or leave, no grubs on a healthy rider, the warriors within 22 tiles of the Mother, the Mother
  rooted, the read before the hit, the story lines, and grubs laid again after.
- `tools/measure_brood_v_riders.gd` (new): one line of numbers per game (see above).
- Run and passing: TESTS_HERE

## Claude's choices for the owner

- **No Mound Turtle in front of the worker lines.** The job asked for one on the read. A rooted Mound Turtle does not
  bite and riders ride round it; the only turtle the code moved (the ALARM's, in front of the natural) uprooted a turtle
  that fed the Rootmaws' swamp. What protects the swamp is the Mother staying rooted (above) and the ALARM no longer
  counting riders. Say if you want a turtle rooted by the Rootmaws anyway (a body in the riders' way).
- **Raptors, not Spitters, as the answer.** Raptors are the cheapest real answer and come from the Tyrant Sire every
  opening has (2 for 50 food); Spitters need the Venom Sire (200 food and 25 spoils) and the Horseman has a 1.3 bonus
  against them. With riders about the old rule (a Spitter for every Raptor once the Venom Sire stands) stays. The Mist
  Toad's TONGUE comes too late (her stage 3) to matter against a 3:40 rush.
- **How many Raptors**: the riders it expects (at least 3) at 115 each, 60% of it before they are seen coming; about
  8 Raptors before, 14 once they come. Less and the riders win the fights at the grubs; more and the Brood's economy at
  4:00 falls behind the riders' damage.
- **The read from one Horseman** before 4:00 counts. A Crown that is not rushing seldom has a Horseman out that early
  (its rider scouts wait for the first gun against the Brood); if it does, the cost is a few Raptors early.
- The watcher's look round the main is for the Crown only (the Clockwork's watcher already explores its main).

## Open questions

- A human Crown that walls its ramp in the first minute (the owner did: a Gate piece at 0:40) shuts the look out: the
  read then comes from the riders leaving past the foot of the ramp (20-40 s before they arrive), not from the Horse
  Breeder.
- The Crown computer's riders mostly kite the guard (few are killed): the rush fails (its own log says "FAILED: the
  defenders are worth more") but costs the Crown little. A Brood that wants to punish it needs Spitters or the Toad.
