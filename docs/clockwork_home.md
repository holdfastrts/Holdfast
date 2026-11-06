# The Clockwork army rests on its gears and defends its base (branch clockwork-home, 0.33.1)

Short sentences, to be read aloud.

The owner, 2026-11-06, watching the Hard Brood OPTIMAL against the Hard Clockwork OPTIMAL on Kestrel Rise (seed
2537549191, 0.33.0; his log: docs/playtests/2026-11-06/clockwork_v_brood_kestrel_log.txt, his picture:
clockwork_army_away_from_base.jpg): "Very interesting game, Clockwork reacted correctly to the rush and held it." Two
requests:

1. **Winding while idle.** When the army is not attacking it lets its soldiers wind down. It should stand on its gears
   (the gear ground winds a construct 0.3 a second), with the Winders topping up the rest.
2. **Defending its base.** At 9:58 the army ball hung at its gathering point at the top, (70, 45), while the base below
   was attacked; from 9:16 it sent pieces ("sends 4 units", "sends 13 units", "sends 7 units", "sends 6 units"). When the
   base is attacked by more than a token raid the WHOLE army must go, with its Winders, and come home after.

No unit, building or research number was changed. Only the Clockwork computer (scripts/ai_cw_army.gd); nothing in the
shared computer (scripts/ai.gd) and nothing the Crown jobs touch.

## The short version

- **Where it waits.** The army now waits where the enemy's way in reaches the base: the path from the enemy's main to the
  middle of our halls, at the first point by our gear ground. Before, it waited in front of the Clocktower nearest the
  enemy's main in a straight line. On Kestrel Rise that was the newest Clocktower, in the north, while the Brood came in
  from the west.
- **It rests on its gears.** Each unit has its own spot at the edge of the gear ground there. A unit run down to 80% steps
  onto the gears for two or three seconds and walks back, a few at a time. The Winders wind the rest, as before.
- **The whole army defends the base.** The raids on the base are counted together. Anything more than a token raid (12%
  of the army, kept between 150 and 300) is met by the whole army with its Winders, and it stays until the base is calm.
  Then it walks back to its gears.
- **The numbers** (22 games below, 11 before and 11 after): the army waited at 0.91 wind on average, against 0.81 before
  (its lowest unit 0.48 against 0.12 against the Brood); it went out on a push at 0.94 (0.86) and into a defence at 0.91
  (0.77). In the attacks on the base that peaked at 600 or more, 88% of the army was at the fight while it was big, against
  47% before. Against the Brood it lost 1.3 buildings a game against 3.9, and 2,094 of its value by 10:00 against 3,137.

## What was wrong, and why

### The idle army wound down

- A Clockwork construct off its gear ground runs down at 0.012 a second (empty in about 80 s). On its gear ground it winds
  0.3 a second.
- The army waited at its gathering point: `AI._rally_front` of the chosen Clocktower, 15% of the way toward the enemy's
  main, with a scatter of 60 px. A Clocktower's ring is about 150 px across its pitch circle. So the army stood just off
  its gear ground, all the time.
- Only the escort Winders wound it, and they wind a unit only under 45% (under 20% from anywhere). So the waiting army
  sat between 0.45 and 1.0, at 0.82 on average, and as low as 0.22 in one game.
- Standing ON the gear ground is not simple either. The whole gear ground is a turning toothed band, except the still
  floor plate in each ring's hole, which the building covers nearly all of. A unit left on a band is carried round with
  the teeth (about a tile a second), and the computer walks its own idle units off a band after one second
  (docs/gear_turn.md). So an army sent to stand on the band would be walked off it, or ride round the Clocktower.

### The army waited away from the fight

- **The gathering point moved to (70, 45)** at 8:56, when the third Clocktower was finished: the old rule picks the
  Clocktower nearest the enemy's main in a straight line, and the new one in the north was a little nearer than the second
  base. But the Brood's way in on that map is from the west: its raids came in at (48, 50), (51, 55), (57, 67), (69, 54).
  So the army stood at the far end of the base from the fight.
- **The raids were met in pieces.** Each raid spot (enemies within 330 px of a building, 300 px apart) was judged on its
  own. The whole army went only when one spot alone was worth 45% of the army. A swarm of 65 Raptors (1,625) comes in at
  several buildings at once, so after the first spot each was "small": groups of 4, 13, 7 and 6. And as soon as the
  biggest spot fell under 45%, the army went back to group mode and the rest of it walked back to the gathering point.

## The fixes (scripts/ai_cw_army.gd, the "clockwork-home" section)

### The gathering point on the way in (`_gather_home`)

- The path from the enemy's main to the middle of our built halls (the pathfinder's, so it goes round cliffs and through
  ramps). Walking it from the enemy's end, the first open point within 40 gear px of one of our rings' tooth tips, on that
  ring's ground level, is the gathering point. That is between the base and the way the enemy comes, at the gear ground.
- If the path never comes that near (it can end short), the edge of the ring of the hall nearest the enemy, toward it.
- It is picked again every 30 s, at once when a hall is added or lost, never in a fight. The AI STORY: "the army rests on
  its gears at (x, y), where the enemy's way in reaches the base".

### The rest spots and topping up (`_build_spots`, `_rest`)

- Round the gathering point (520 px), spots are laid on every ring of ours on its level: first the still floor plate in a
  ring's hole when there is room (a unit there is wound for good), then three rows just outside the band (18, 44, 70 gear px
  past the teeth), 26 px apart, nearest first. A spot on or at the edge of a band is never used (it would ride).
- Each unit keeps its own spot. The big machines, which the gears do not carry (the Spring Ballista), get a spot on the
  band itself.
- A unit at its spot under 80% wind walks onto the band beside it (the middle of the band), stays until 98% (or 12 s), and
  walks back. At most a third of the army (at least 3) tops up at once, the lowest first, and never with an enemy within
  300 px. The step-off rule of the turning gears does the rest: after one second standing it walks the unit off, and by
  then it has gained 0.5 or more. The AI STORY, at most once a minute: "the army rests on its gears: 2 run-down units
  step onto the gears to wind".
- The escort Winders keep winding and mending it as before.

### The whole army defends the base (`_defend`)

- The raids are counted together: all the armed raid spots by our buildings.
- A **token raid** is worth less than 12% of the army (kept between 150 and 300; a Raptor is 25, a Clock Soldier 70) and
  less than 45% of it. Only a token raid gets a group (1.5 times its value, at least 3 units); the rest of the army stays
  on its gears. "a small raid worth 75 at (89, 52), far from the army: sends 3 units (210) at it, the rest stays on its
  gears".
- Anything more and **the whole army defends the base** with its Winders, going to the biggest raid (one nearly as big and
  much nearer first). It stays together until the base has been calm for 6 s (a raid shrunk to a token one is left to a
  group after 15 s). "the whole army defends the base (29 units, 2438, with its Winders) against a raid worth 1516 at (46,
  55)", then "the base is calm again: the army walks back to rest on its gears".
- **Far stronger than the whole army** (the army worth less than 55% of the raid, as 0.33.0's rule) and more than 600 px
  from its gathering point: it does not walk out into it, it holds together on its gears, wound and mended there, and
  meets it when it comes. (0.33.0 held at the main's gate instead.)
- The push out still comes home when the base is attacked hard (unchanged: ai_cw_push.gd).

`-- cwhome:off` plays 0.33.0's gathering point and raid answers (the "before" columns).

## The games

Hard Clockwork OPTIMAL against a Hard Brood OPTIMAL or Crown OPTIMAL, 12 minutes, the Clockwork in the second slot as in the
owner's game. Kestrel Rise with the owner's seed (2537549191), 7 and 3; Frostfang 11 and 12, Highmoor 11, Cinder Steps 11;
against the Crown Kestrel Rise, Frostfang, Redrock Canyon and Highmoor. The owner's game does not replay exactly from its
seed (the computers' choices and timings drift), so each run of it is another game on that map and start.

What the columns mean:
- **wind at home**: the army's constructs at home (no push out, no attack on the base), their average wind, every second.
  **on gears**: the share of that time they stood on gear ground.
- **as a push goes / as a defence starts**: the army's average wind at those moments.
- **attacks (600+)**: attacks on the base (armed enemies within 330 px of our buildings worth 300 or more, until 10 s under
  100); in brackets the ones that peaked at 600 or more with the push at home.
- **army that came**: of those, the share of the army (value) that came within 420 px of the attackers at some point.
  **army at it**: the share of the army at the attackers on average, while they were worth 300 or more. This is the one
  that tells pieces from the whole: groups sent one after another all "come" in the end, but few are there at once.
- **buildings lost**, **killed / lost by 10:00** (value), the armies at 10:00, the end.

| game | seed | | wind at home | on gears | wind as a push goes | wind as a defence starts | attacks (600+) | army that came | army at it | buildings lost | killed / lost by 10:00 | army 10:00 | end |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cinder_steps optimal v brood optimal | 11 | before | 0.80 | 4% | 0.88 | 0.85 | 2 (2) | 89% | 77% | 3 | 1650 / 4360 | 710 v 1650 | none 12:00 |
| cinder_steps optimal v brood optimal | 11 | after | 0.90 | 8% | 0.92 | 0.91 | 2 (2) | 92% | 73% | 0 | 1300 / 4000 | 545 v 2400 | none 12:00 |
| frostfang optimal v brood optimal | 11 | before | 0.81 | 3% | 0.88 | 0.66 | 3 (3) | 96% | 71% | 4 | 2575 / 4165 | 70 v 3950 | none 12:00 |
| frostfang optimal v brood optimal | 11 | after | 0.88 | 6% | 0.89 | 0.90 | 2 (1) | 86% | 91% | 1 | 3900 / 1640 | 2405 v 2625 | none 12:00 |
| frostfang optimal v brood optimal | 12 | before | 0.73 | 2% | 0.75 | 0.34 | 1 (1) | 100% | 28% | 2 | 1250 / 1580 | 2945 v 2900 | none 12:00 |
| frostfang optimal v brood optimal | 12 | after | 0.93 | 10% | 0.96 | 0.99 | 1 (1) | 94% | 96% | 2 | 1650 / 1370 | 2580 v 1825 | none 12:00 |
| frostfang optimal v crown optimal | 11 | before | 0.84 | 7% | 0.91 | - | 0 (0) | - | - | 0 | 1545 / 1730 | 2105 v 1050 | none 12:00 |
| frostfang optimal v crown optimal | 11 | after | 0.92 | 18% | 1.00 | 0.88 | 2 (0) | - | - | 0 | 1210 / 2625 | 1040 v 1175 | none 12:00 |
| highmoor optimal v brood optimal | 11 | before | 0.82 | 3% | - | - | 0 (0) | - | - | 2 | 1600 / 1160 | 3035 v 3475 | none 12:00 |
| highmoor optimal v brood optimal | 11 | after | 0.92 | 8% | - | 0.88 | 1 (0) | - | - | 3 | 800 / 1490 | 2925 v 1875 | none 12:00 |
| highmoor optimal v crown optimal | 11 | before | 0.77 | 9% | 0.77 | - | 0 (0) | - | - | 1 | 1065 / 1335 | 2675 v 1460 | none 12:00 |
| highmoor optimal v crown optimal | 11 | after | 0.87 | 14% | 1.00 | 0.88 | 1 (0) | - | - | 1 | 2465 / 1750 | 2000 v 405 | none 12:00 |
| kestrel_rise optimal v brood optimal | 3 | before | 0.82 | 2% | - | 0.77 | 1 (1) | 84% | 35% | 0 | 2075 / 740 | 3160 v 2475 | none 12:00 |
| kestrel_rise optimal v brood optimal | 3 | after | 0.91 | 12% | - | 0.93 | 3 (3) | 90% | 87% | 1 | 1975 / 2045 | 1805 v 2685 | none 12:00 |
| kestrel_rise optimal v brood optimal | 7 | before | 0.81 | 3% | 0.91 | 0.81 | 1 (1) | 100% | 25% | 16 | 1250 / 5345 | 0 v 2975 | foe 11:36 |
| kestrel_rise optimal v brood optimal | 7 | after | 0.90 | 11% | - | 0.95 | 4 (2) | 95% | 91% | 2 | 2600 / 2345 | 1560 v 3220 | none 12:00 |
| kestrel_rise optimal v brood optimal | 2537549191 | before | 0.83 | 5% | 0.88 | 0.83 | 3 (2) | 98% | - | 0 | 1825 / 4615 | 450 v 1700 | none 12:00 |
| kestrel_rise optimal v brood optimal | 2537549191 | after | 0.91 | 9% | 0.90 | 0.89 | 3 (2) | 84% | 92% | 0 | 1625 / 1770 | 1600 v 1625 | none 12:00 |
| kestrel_rise optimal v crown optimal | 2537549191 | before | 0.79 | 9% | 0.79 | 0.91 | 1 (0) | - | - | 2 | 1140 / 2555 | 2640 v 1575 | none 12:00 |
| kestrel_rise optimal v crown optimal | 2537549191 | after | 0.90 | 11% | 0.87 | - | 0 (0) | - | - | 2 | 1435 / 3460 | 2575 v 925 | none 12:00 |
| redrock_canyon optimal v crown optimal | 11 | before | 0.93 | 11% | 1.00 | 1.00 | 2 (0) | - | - | 1 | 685 / 2695 | 1530 v 1410 | none 12:00 |
| redrock_canyon optimal v crown optimal | 11 | after | 0.93 | 19% | 0.95 | 0.90 | 1 (0) | - | - | 0 | 1535 / 940 | 3140 v 990 | none 12:00 |


BEFORE: 11 games, wind at home 0.81, on gears 5%, as a push goes 0.86, as a defence starts 0.77, army that came to a 600+ attack 94%, at it while it was big 47%, buildings lost 2.8, killed 1514 lost 2752 by 10:00, won 0 lost 1
  
AFTER: 11 games, wind at home 0.91, on gears 11%, as a push goes 0.94, as a defence starts 0.91, army that came to a 600+ attack 90%, at it while it was big 88%, buildings lost 1.1, killed 1863 lost 2130 by 10:00, won 0 lost 0

## Reading the numbers

- **Wound.** Every game waited better wound: 0.88 to 0.93 at home against 0.73 to 0.93 before (0.91 against 0.81 on
  average). It still stands on gear ground only about a tenth of the time (the top-ups); the rest of the time it stands
  beside it and runs down from 98% to 80% in about 15 s, then steps on again. The biggest gain is when it matters: a
  defence starts at 0.91 against 0.77 (Frostfang 12: 0.99 against 0.34, the old army had run down by the time the Brood
  came at 11:34).
- **The whole army.** The share of the army at an attack while it was big is the measure that tells pieces from the whole
  (groups sent one after another all "come" in the end, but few are there at once): 88% against 47% on average a game
  (the attacks one by one: 87% of 11 against 57% of 8). Kestrel Rise 7 before is the owner's picture again: one attack
  from 7:53 to the end, 25% of the army at it, 16 buildings lost and the game.
- **Against the Brood** (7 games each): buildings lost 1.3 a game against 3.9, its value lost by 10:00 2,094 against
  3,137, killed 1,978 against 1,746; its army at 10:00 1,917 against 1,481 and at 12:00 2,566 against 1,327. No Clockwork
  base fell after (before: Kestrel Rise 7, at 11:36).
- **Against the Crown** (4 games each) the Crown rarely attacked the base (no attack of 600 or more in any of these games);
  the numbers are about the same (buildings lost 0.8 against 1.0, lost by 10:00 2,193 against 2,078), the army at 12:00
  3,502 against 2,891.
- **Single games are anecdotes.** The same map, seed and code give a different game each run (the owner's Kestrel Rise
  seed: before, one run lost every hall by 10:22, another held with no building lost). The averages are the result.
- **The owner's game** (Kestrel Rise 2537549191, after): the army rests on its gears at (74, 71), then (70, 57) and (73, 60)
  as the halls come, on the west side where the Brood comes in; the 9:43 and 11:18 attacks were met by the whole army
  (90% and 93% of it at the fight) and no building was lost.
- **What did not work** (kept out): holding on the gears when the raid is worth more than 1.25 times the army (Claude's
  choices, 3) and a gathering point picked again whenever any ring changed (it moved 5 times in the fight at Frostfang 12:
  now it stays put in a fight and only moves when a hall comes or goes).

## Claude's choices for the owner

1. **On the gears, or beside them.** The gear ground is a turning band all round, except the still plates the buildings
   nearly fill. Standing on a band carries a unit round with the teeth, and the computer walks its idle units off a band
   (your rule). So the army rests on spots just outside the bands, and its units step on to wind when they are down to
   80%: on average 0.91. The other way would be to let the resting army ride round its Clocktower: wound all the time, but
   moving all the time. Say if you want that.
2. **What a token raid is**: under 12% of the army, never more than 300 (12 Raptors, 4 Clock Soldiers), and under 45% of
   it. You said "split only for a truly small raid far from the army"; a small raid near the army is met by a group too
   (the army is right there; 28 units chasing one Raptor round the base was the alternative).
3. **Holding when far weaker.** When the raid is worth nearly twice the whole army and far from its gathering point, the
   army holds on its gears instead of walking into it. I tried it at "the raid is worth more than 1.25 times the army":
   in 7 games against the Brood it lost more buildings (6.3 a game against 1.3 with the 0.55 rule; that try also had the
   gathering point that moved in fights: docs/clockwork_home/tried_hold08.jsonl): holding while the Raptors ate the
   Winders and the presses cost more than meeting them. So it is the old 0.55 again.
4. **The gathering point is not a choke.** It is where the enemy's path from its main meets our gear ground. A raid from
   another side (a drop, a second path) is still met: the whole army walks to it.

## Open questions

1. The Hard Brood still out-earns the Hard Clockwork (its army about 1.5 to 2 times the Clockwork's at 8:00 in most of
   these games); the waiting army is better wound now, but it waits because it is weaker. The open FOOD_BONUS question.
2. The owner's game does not replay from its seed. A seeded replay of a computer game would need the computers to be
   deterministic (docs/pathfinding_audit.md: "match determinism" is left).

## Tests and tools

- `tools/test_clockwork_home.gd`: one game, measured (the columns above). `check:1` is the test (Kestrel Rise, the owner's
  seed, 12 minutes): the idle army's average wind 0.8 or more, and every attack on the base that peaked at 600 or more (with
  the push at home) drew 70% or more of the army, with 60% or more of it at the fight at once on average while it was big. `cwhome:off` plays 0.33.0.
- `tools/clockwork_home_report.py`: the tables above from its json lines (docs/clockwork_home/games.jsonl).
- Run on 0.33.1 and passing: test_clockwork_home (check:1, the owner's seed: wind at home 0.91, two attacks with 95% and
  96% of the army coming, 85% and 82% at the fight at once), test_clockwork_army (check:1: 1 fight alone away from home,
  0 first fights alone, 8.2 Winders with the army out), test_ai_optimal (ALL PASS), test_gear_turn (PASS), test_files (0
  failures), test_i18n (PASS).
