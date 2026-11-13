# brood-rush-coach: the Hard Brood's Raptor rush against Horsemen (2026-11-13)

The owner's playtest (v0.35.6, Mirewood, the Crown against a HARD Brood on RUSH; log and pictures in
`docs/playtests/2026-11-13_mirewood_*`): the Brood rushed at 2:37 with 10 Raptors; the owner met them at his ramp wall
with 2 Horsemen; when he rode out of the wall, the Raptors left the wall and chased his riders, and his 2 Horsemen,
hitting and riding off, killed 5 of them; the rest went home at 3:35 ("its rush failed"). After that the Brood stayed
at 8-12 grubs until 6:36 and earned 360 a minute against his 872.

His questions: (1) would the Raptors have won a stand-up fight without micro, and if they can't, is the rush too weak?
(2) the Brood should have kept at the wall instead of chasing his riders; (3) was the Brood so weak because it chose
RUSH?

## The answers in plain words

1. **No, the Raptors do not win the stand-up fight, and it is the numbers, not a bug.** 10 Raptors lose to 2 Horsemen
   in every set-up measured: standing still, riding about on attack-move, kiting, behind a gate, 12 Raptors (the
   equal-cost army), 15 against 3, with Pack Hunt. A Horseman kills a Raptor in exactly two sabre blows (18 damage, 36
   health), so 2 riders kill one Raptor every ~1.6 s, while a Raptor's bite is 5 through the rider's armour once every
   1.35 s and each dead Raptor takes its bites with it. When the riders stand still the Raptors only just lose (the
   riders end on 92 of 280 health); with 12 Raptors they win 4 times in 6. On attack-move the riders win easily, because
   a Horseman on attack-move rides by (the Cyclone-like loop the owner asked for, docs/ride_by.md): he never stands
   still, so the Raptors are in reach only a quarter to two fifths of the time (three quarters when he stands). The
   "Raptors wandering 500 px off" in the first test were the test's own doing: it put the riders on Greenhold's middle
   plateau and the Raptors below its cliff, so they walked round to a ramp. Nothing else was wrong: no knockback, no
   stun, no lost targets (measured 0%). So **yes, the rush is weak against riders, and that is a balance question: a
   proposal is below, nothing applied.**
2. **The Brood now keeps at the wall** (fix 1): a wave creature biting a rider who rides off lets him go once he is
   out of its reach and goes back to the wall or building it was hitting; it bites a rider who comes back into the pack.
   The film and the scripted test show the wave staying at the palisade (Raptor-seconds spent more than 6 tiles out:
   28 -> 4-7 a trial; palisade health it took: 46 -> 186-200). But it does not save the Raptors: against a perfect
   hit-and-run (the test's riders strike when their sabre is ready and ride off at once, every 0.25 s), even ONE
   Horseman kills all 10 Raptors at the wall, losing 84 of his 140 health. Standing at a wall, a Raptor is a target
   for a rider with a longer reach (26 against 22) and a faster horse (112 against 96). The owner's "if the Brood
   stayed at the wall I could not micro" is not what the test shows; his micro still works there, it just wins him
   no ground in the open. Only the numbers can change that.
3. **Mostly the plan.** On Mirewood a Hard Rush Brood against the Hard Crown computer (no rider raid) earned 2,148-2,209
   by 6:00; a Balanced Brood on the same map earns 5,647 by 6:00 with no enemy and 4,283-4,914 against the Crown
   computer (the table below); the owner's game, with his riders in its land from 4:12 to 5:21, 1,854. So of the gap at
   6:00 between a Balanced Brood (4,600 on average) and the owner's game (1,854) about seven eighths (2,420) is the
   plan (the rush's 9 grubs until its wave leaves, then a slow rebuild) and one eighth (330) the riders' raid. The rebuild itself was slow (fix 3): from the failed rush at 3:35 to 6:00 the Brood put a third
   or more of its food (with the grubs they cost) into new Rootmaws and Mound Turtles on new ground while its
   Rootmaws had 4-17 posts without a grub. Now it
   fills the posts first: income at 6:00 558/601 -> 781/843 a minute, earned by 8:00 4,885/4,475 -> 5,517/5,849
   (+13% and +31%).

## The stand-up fight, measured (tools/test_raptor_rider_fight.gd)

The test was reworked: the fight is on a flat, open patch of Greenhold (`_flat_spot`: a 640 x 640 px patch on one
height level, clear in straight lines from its middle), the spawns are seeded, and there are set-ups: `standup` (both
sides attack-move), `stand` (the riders stand their ground: no ride-by), `kite` (scripted hit and run), `gate` (the riders
behind a one-cell gap in a palisade). `set:raptor.hp=38` tries a number on the units of one run. 6 trials each (gate 3).
"Lost" is the riders' health lost, of 140 each.

| set-up | standup (ride-by) | stand (no ride-by) | kite |
|---|---|---|---|
| 2 riders v 10 Raptors (before, on the cliff) | riders 6 of 6 | | riders 6 of 6 |
| 2 v 10, flat ground | riders 6/6, lost 136 of 280 | riders 6/6, lost 188 | riders 6/6, lost 146 |
| 2 v 10, ride-by off | riders 6/6, lost 175 | | |
| 2 v 12 (equal cost: 310 gold v 300 biomass) | riders 6/6, lost 189 | **riders 2/6**, lost 274, 2.7 Raptors left | riders 6/6, lost 170 |
| 2 v 10, Pack Hunt (Raptor 114 > rider 112) | riders 6/6, lost 127 | riders 6/6, lost 194 | riders 6/6, lost 145 |
| 3 v 15 | riders 6/6, lost 201 of 420 | riders 6/6, lost 286 | riders 6/6, lost 206 |
| 2 v 10, gate (one-cell gap) | | riders 3/3, lost 140 | |

The trace (tools/trace_raptor_rider.gd, 2 v 10, every 0.25 s): with ride-by the Raptors are within reach of a rider
19-43% of the time, standing 70-77%; knocked back 0%, stunned 0%, without a target 4%. The pack focused one rider
(the other ended untouched), which is right. A Raptor's cycle is aim 0.1 + strike 0.35 + cooldown 0.9 = 1.35 s for
5 damage (6 less 1 armour); a Horseman's is 0.15 + 0.35 + 1.1 = 1.6 s for 18, plus his one pistol shot (30).

## Fix 1: the raid keeps at its prey (scripts/ai_brood_new.gd `_nb_wave_no_chase`, scripts/unit.gd `_raid_bite_tick`)

On a wave against a non-Brood enemy, a creature biting a RIDER (`is_rider`: Horseman, Cuirassier, Dragoon) who is out of
the pack (farther than 4 tiles from the wave's middle, fewer than 4 of the wave round him) and not clearly beatable (a
lone rider under 45% health within 8 tiles of the pack) lets him go once he is out of its reach. At a raid (an enemy
building within 10 tiles of the pack) it goes back to the nearest building near the raid's spot (the enemy building
nearest the pack's middle, so the pack stays in one place) or a worker; in the open it walks on to the wave's goal.
There it BITES a fighter who comes within its reach (or a lunge of 18 px past it, the rider's longer reach), without
leaving the building (`Unit.raid_bite`). A rider who comes back into the pack is bitten by every creature within
2.5 tiles of him. `-- nbchase:on` plays it as before.

**No walk home from riders**: when every enemy fighter about the wave is a rider, the wave no longer pulls back because
the fight is going badly (a pull-back is a plain walk with its back to faster riders: in the test the riders cut the
walking Raptors down from behind). It still goes home at a quarter of what it took out, or after 150 s without headway.

tools/test_brood_rush_riders.gd (the owner's game scripted: a Hard Brood RUSH computer's wave of 10 Raptors at a
palisade box round a Cottage, 2 Horsemen outside riding in to strike and off into the open while the sabre cools, 4
trials of 60 s; `-- nbchase:on` for before, `-- set:` for numbers, `-- shots:` for the film):

| | Raptors left | rider health lost | riders dead | Raptor-seconds > 6 tiles out | palisade health taken |
|---|---|---|---|---|---|
| before (chase) | 0 | 92 of 280 | 0 | 28 | 46 |
| now | 0 | 61-76 of 280 | 0 | 4-7 | 186-200 |
| now, 1 rider | 0 | 84 of 140 | 0 | 24 | 457 (half a piece down) |
| before, Raptor hp 38 | 0 | 162 | 0.5 | 59 | 69 |
| now, Raptor hp 38 | 0 | 134 | 0 | 11 | 283 |

The film (docs/shots/brood_rush_coach/, a picture every 3 s of trial 0): `chase_*.jpg` before, the Raptors strung out
after the riders away from the palisade; `nochase_*.jpg` now, the Raptors at the palisade. The trade against a perfect
hit-and-run is about the same either way; the Raptors at the wall at least do what they came for.

## Fix 3: the rebuild after a rush (scripts/ai_brood_new.gd `_rebuilding`)

For 150 s after a rush hands over to Balanced (`_rush_to_balanced`: failed, called off or home), while its Rootmaws
have more than 2 posts without a grub, no new Rootmaw and no Mound Turtle on new ground (a supply turtle when supply is
short, and a Sire, still come): the food goes to grubs. `-- nbrebuild:off` plays it as before.

Mirewood, Hard Brood RUSH against the Hard Crown computer (OPTIMAL), tools/econ_ai_alone_brood.gd `vs=crown`; earned a
minute (and in all) at each minute; the rush failed at 3:32-3:34 in all four games:

| | 4:00 | 5:00 | 6:00 | 7:00 | 8:00 | grubs at 6:00 |
|---|---|---|---|---|---|---|
| seed 1 before | 344 | 412 | 558 | 928 | 1,809 (4,885) | 15 |
| seed 1 now | 344 | 460 | 781 | 1,285 | 1,813 (5,517) | 25 |
| seed 2 before | 344 | 427 | 601 | 781 | 1,485 (4,475) | 17 |
| seed 2 now | 340 | 471 | 843 | 1,269 | 2,089 (5,849) | 24 |
| Rush alone (no enemy: its wave never ends, no hand-over) | 358 | 493 | 679 | 756 | 1,163 (4,334) | 19 |
| Balanced, seed 1 (v the Crown computer) | 894 | 1,220 | 1,648 | 1,469 | 2,655 (9,038) | 39 |
| Balanced, seed 2 (v the Crown computer) | 825 | 916 | 1,402 | 1,374 | 2,121 (7,778) | 36 |
| Balanced alone (no enemy) | 895 | 1,715 | 1,888 | 2,265 | 2,413 (10,325) | 46 |
| the owner's game (riders in its land 4:12-5:21) | 358 | 296 | 303 | | | 8 |

## THE BALANCE PROPOSAL (not applied: the owner decides)

The lever is the two-blow kill. **Raptor health 36 -> 38** (any 37+): a Horseman's sabre needs three blows instead of
two. Measured (same tests): stand-still fight 2 v 10 riders win 6 of 6 -> **0 of 6** (5.3 Raptors left); ride-by
stand-up still riders 6 of 6 but they lose 235 of 280 (was 136); kiting riders 6 of 6, losing 232 (was 146); at the
wall against the scripted hit and run the riders lose 134-162 of 280 (was 61-92). It also changes other breakpoints:
the Musketeer's bayonet (18) 2 -> 3 blows, the Pikeman stays at 3, the Clockwork's 12-damage units (Pendulum,
Ornithopter, Rail Rifleman, Tesla Loco) 3 -> 4, the Bulwark 4 -> 5, the Tin Militia 6 -> 7; muskets and cannon do
not change. Smaller alternatives measured: **Raptor damage 6 -> 7** (6 against the rider's armour): riders still win
6 of 6 everywhere (stand: lost 251 of 280), too small alone. **Pack Hunt** (Raptor 114, faster than a rider) does
not change the result (above). A rider-specific change (the sabre 18 -> 17, also 3 blows on a Raptor) would hit the
Horseman against everything else too. Claude's pick: Raptor health 38, then look at the Brood's early game against
the Musketeer's bayonet again.

## Tests (AI and Brood, on this branch)

All AI and Brood tests were run. Pass: test_ai_brood, test_brood_new (289), test_brood_ai_defend, test_brood_builds,
test_brood_fixes, test_brood_fix3, test_brood_far, test_brood_mirror, test_brood_spend, test_brood_paths,
test_brood_layout, test_brood_controls, test_brood_regen_calm, test_brood_production, test_brood_sounds,
test_brood_voices, test_ai_optimal, test_ai_scout, test_ai_scout_threat, test_ai_scout_defence, test_ai_gg_rule,
test_ai_air_defence, test_ai_wall_vs_rush, test_ai_expand, test_ai_expand_wall, test_ai_abandoned_site,
test_ai_crown_bank, test_ai_r5_hold_spots, test_ai_placement, test_ai_round6, test_ai_round6_stall,
test_ai_cw_horse_raid, test_ai_scout_sentry, test_brood_rush_riders (new). Known failures: test_brood_new_defence's
rooted-muskets case (fails on main too), test_crown_dragoon_raid [plan] (known). Failing on this branch and the same
with every change here switched off (`-- nbchase:on nbrebuild:off`, so not from this job): test_ai_rush ("workers
before the Brood Mother", known), test_ai_rush_followup (17, known), test_ai_worker_safety ("two brutes ... do not kill
the workers off", 10 -> 5), test_brood_v_riders ("most grubs survive the raid", 6 of 13 lost). Flaky (passed on a
rerun): test_ai_army_response [crown], test_ai_harass [raid].

## What to look at next

- The balance proposal (Raptor health 38), then the Brood's rush against the Musketeer opening again.
- The rush plan's own economy: 9 grubs until its wave leaves is a gamble by design (docs/econ-coach-brood.md). Against
  a Horse Breeder seen early (the rider read) the RUSH could call itself off like it does against a big army
  (`_rush_to_balanced` "calls its rush off"), since Raptors lose to riders on equal money: not done here (a plan's
  identity: the owner trains against each plan).
- Tools: tools/test_raptor_rider_fight.gd (the stand-up fight, `set:` for numbers), tools/trace_raptor_rider.gd (the
  trace), tools/test_brood_rush_riders.gd (the raid, the film).
