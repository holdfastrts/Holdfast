# Two Clockwork computer plans built round the Heavy Works (branch cw-builds-b)

Short sentences, to be read aloud.

The owner, 2026-11-03: "do it all". This job wrote two new plans for the Clockwork computer, in the framework of the
Springer timing (docs/clockwork_ai_rebuild.md): a written opening build, then rules for the middle game.

1. PENDULUMS: the answer to the Brood's Raptor swarms. The owner's playtests: "it should have gone Pendulum".
2. HEAVY WORKS PUSH: a slow, hard-to-stop push with Spring Ballistas and a Great Winder behind Clock Soldiers.

Design rules followed (docs/design_principles.md): 2, anti-snowball (the economy keeps growing behind the push; a push
can always retreat, and does, before it is wiped out; the enemy's main is attacked only with the strength for it);
1, fairness (the computer sees only what its side sees; it knows only where the enemy started). No unit, building or
research number was changed. The balance ideas are proposals for the owner, at the end.

## The short version

- PENDULUMS AGAINST THE BROOD WORK. In 9 games against the Hard Brood (Rush, Extreme rush, Timing, Balanced, Economy;
  Greenhold, Kestrel Rise, Frostmere, Highmoor) the Clockwork WON 3 (at 10:43, 11:16 and 11:36: the Brood Mother killed), lost 1
  and 5 had no winner by 12:00. The old Balanced plan, on the same maps and seeds: won 0 of 6, lost 2. The old Rush: won 0
  of 2, lost 1.
- The tech comes on time, every game: the Heavy Works laid at 2:52 to 2:58 and standing by 3:48, the first Pendulum at
  4:18 to 4:36, three by 5:29 to 5:49. (The old Balanced plan against the Brood: its first Pendulum at 7:23 to 11:19, in
  4 games of 6; never a second.)
- The economy grows behind it: 23.9 Winders at 8:00 (the old Balanced 12.8: the Brood's Raptors killed its Winders),
  6,261 cogs earned by 8:00 and 9,010 by 10:00 (old Balanced 5,286 and 6,516).
- The fights: by 12:00 it killed 4,719 value and lost 4,196, on average (old Balanced: 2,788 and 5,036). The push goes
  out at 5:41 to 8:41 (6:40 on average) and, in 7 games of 9, killed Rootmaws, Mound Turtles or a father in the Brood's
  nest (the first at 7:49 to 9:59); 24 grubs dead by 12:00 on average.
- Not good enough against the Brood's ECONOMY plan: its Raptor mass (3,145 to 4,995 army value at 8:00, against the
  Clockwork's 1,800) beat the push twice in each game, and won one of the two by 11:44. The old plans died to it too.
- THE HEAVY WORKS PUSH AGAINST THE CROWN IS A SMALL STEP, NOT A WIN. In 6 games against the Hard Crown (5 on Balanced, 1
  on Rush) no game had a winner by 12:00, the same as the old Balanced plan. What changed: two Ballistas and the Great
  Winder by 5:20 to 5:41, the push out at 5:24 to 5:44; it razed 4.5 Crown buildings by 12:00 (old Balanced 3.3, mostly
  the Crown's new Town Hall and Mills); it lost 3,353 value by 12:00 for 2,499 killed (old Balanced lost 4,778 for 2,472);
  and it kept its economy: 35.8 Winders at 12:00 (old Balanced 29.2). The Crown still earned as much (12,710 gold by 12:00,
  against 12,666), with 46 to 50 Labourers.
- Against the Brood the Heavy Works push did not work (2 games: no push went out, lost 5,300 for 2,602). The Pendulums are
  the Brood plan; a RANDOM PLAN computer picks them half the time against the Brood.
- No siege of a wall happened in the measured games: the push holds short of a walled main (THE MAIN WAITS), and the
  Crown's expansions it reached were not walled yet. The Ballistas did lay siege to a Crown Town Hall from out of musket
  reach. The coached game that sent it straight to the Crown's main (pictures 10) shows why it waits: its front went up
  the ramp onto the plateau and died there.

## Where the code is

- `scripts/ai_cw_builds_b.gd`: the two plans (their opening builds and settings). Kept apart from the Springer timing's
  `PLANS` so the parallel jobs (cw-builds-a, cw-builds-c) merge cleanly. `AIClockwork.PLANS_B` reads it.
- `scripts/ai_cw_push.gd`: THE PUSH, the middle game of both plans.
- `scripts/ai_clockwork.gd`: small hooks (marked cw-builds-b) and a block at the end: the plan's own mix after the
  opening (`_b_keep`), the Heavy Works' kept spot (`_b_heavy_spot`), the rewind of run-down machines at home
  (`_b_rewind`), the escort following the push, and the RANDOM PLAN pick.
- `scripts/ai.gd`: the two rows in `AI.STRATEGIES` ("pendulum", "heavy"; Clockwork only) and `AI.random_plan`.
- `scripts/main.gd`: one line, a computer on RANDOM PLAN asks its own `random_plan`.
- Names: "Pendulums" (pt Pêndulos, es Péndulos), "Heavy Works push" (pt Avanço da Oficina Pesada, es Avance del Taller
  Pesado): `tools/i18n/52_cw_builds_b.txt`.
- RANDOM PLAN: a Clockwork computer facing the Brood picks the Pendulums half the time, else evenly among its plans.
- The other plans (Balanced, Rush, Economy, Timing attack, the Springer timing) play as before.

## The build orders

As in the Springer timing, steps are read in order, as a player reads a written build. A number in front is the supply it
waits for. A step waiting for a building or for Tension lets the next steps go with the cogs left over. A step waiting for
cogs, or for its supply, stops the reading there. The plan owns the cogs while it runs.

### Pendulums

| # | step | what it means |
|---|---|---|
| 1 | 7 cog_press | the second Cog Press at 7 supply |
| 2 | 8 movement_works | the Light Works |
| 3 | 9 mainspring | the Mainspring, small ring, with room kept beside it for the Escapement and the Heavy Works |
| 4 | crew mainspring 3 | three Winders on it |
| 5 | 11 regulator | supply |
| 6 | clock_soldier 2 | two Clock Soldiers at home (the Brood's rushes arrive from about 2:30) |
| 7 | escapement | as soon as the Light Works stands |
| 8 | workers 18 | Winders up to 18 |
| 9 | heavy_works | as soon as the Escapement works, on the kept spot |
| 10 | clock_soldier 2 | |
| 11 | regulator | supply (no supply number: a supply-gated step held the Pendulums up for half a minute) |
| 12 | pendulum 2 | two Pendulums |
| 13 | workers 22 | |
| 14 | clocktower | the expansion, behind the Pendulums |
| 15 | pendulum 1 | the third |
| 16 | clock_soldier 4 | the front |
| 17 | end | the plan's middle game |

After the opening: the Heavy Works keeps four Pendulums (more when the swarm rule wants them: two, and one for every ten
Raptors seen), then one Great Winder; the Light Works keeps eight Clock Soldiers (two more for every push gone out); the
shared computer trains the rest (Springers, Netters, Swifts against flyers). THE PUSH goes once three Pendulums and five
front units (Clock Soldiers, Springers, Netters) are at home, 18 supply or more.

### Heavy Works push

| # | step | what it means |
|---|---|---|
| 1-8 | the same as the Pendulums | |
| 9 | heavy_works | |
| 10 | clock_soldier 2 | |
| 11 | regulator | |
| 12 | ballista 1 | the first Spring Ballista |
| 13 | workers 22 | |
| 14 | clocktower | the expansion |
| 15 | great_winder 1 | the Great Winder |
| 16 | ballista 1 | the second |
| 17 | clock_soldier 4 | |
| 18 | end | |

After the opening: the Heavy Works keeps three Ballistas, then the Great Winder (against the Brood: two Pendulums first,
then two Ballistas, then the Great Winder); the Light Works keeps fourteen Clock Soldiers (two more for every push). THE
PUSH goes once two Ballistas, the Great Winder and ten front units are at home, 20 supply or more (against the Brood:
six front units and a Pendulum). It goes for the enemy's main only with 2,600 value or more, and its front is kept on a
shorter leash (360 px).

Why a small Mainspring (the Springer timing has the big one): in round A the big Mainspring's Tension sat at its cap,
400, for minutes, while the cogs were short. A Pendulum is 75 Tension every 35 seconds, a Ballista 50 every 30: about 2 a
second, the small ring's rate. Three Winders on the small ring and three more on a Cog Press: cogs earned by 7:00 went
from 3,988 to 5,308 (Greenhold 11, against the Crown).

## The push (scripts/ai_cw_push.gd)

- ONE BLOCK. An anchor point walks along the path to the goal, 200 px at a time, only when most of the front stands at
  it and the slow machines are close behind. The front (Clock Soldiers, Pendulums, Springers) stands at the anchor in a
  loose line across the way. The Ballistas stand 120 px behind it. The Great Winder walks just behind the middle (the
  shared rule). The escort Winders wind and mend behind the front, and two of them crew each Ballista.
- THE GOAL. Against the Brood: its economy first, a rooted Rootmaw or Mound Turtle it has seen (the nearest; a Rootmaw
  before a turtle), then the Mother. Against the Crown: the shared computer's target, an open expansion or economy
  building first, else its main.
- THE SCREEN. When armed enemies come near, the anchor stops. The front meets what comes within 260 px of it and holds
  the line against the rest. The Ballistas shoot from behind (they reach 300, a Musketeer 190). An enemy that reaches a
  Ballista: it rolls back and the two nearest front units meet that enemy. A front unit more than 520 px from the anchor
  after a chase walks back (360 px for the Heavy Works push). Enemies on high ground above the anchor are not chased up
  the ramp: the line steps back out of their reach. (In round A the Clock Soldiers charged the Musketeers and died one by
  one while the Ballistas stood back; in round B eight of them ran up a Crown ramp after three Musketeers and died there.)
- AT THE GOAL. The front goes for the goal itself (a Rootmaw, the Mother), else for the enemy's buildings seen near it;
  with Ballistas along, a building is SIEGED like a wall (below): the Ballistas break it from out of musket reach and the
  front screens them. Nothing left there for 12 seconds: on to the next goal.
- THE SIEGE. A wall, a gate or a Cottage (the Crown plugs its ramp with one) on the path within 340 px: the front stands 215 px from it (out of musket reach), the
  Ballistas 255 px (in their reach), aimed at it. Enemies that come out are met by the front. When it falls, the march
  goes on. At most 150 seconds at one piece.
- THE MAIN WAITS. The enemy's main (its start: a Crown or Clockwork main, the Mother's nest) only with the strength for
  it: worth 1.3 times the enemy army seen in the last two minutes (and, for the Heavy Works push, 2,600 value at least:
  the army in a main is mostly unseen). Else the push holds on the ground it took, and the reinforcements join it. (In round A the push razed the Crown's expansion, walked up to its main and met its whole army,
  about 25 Musketeers, at the ramp: 3,100 value lost in a minute.)
- REINFORCEMENTS. Fighters made after it left gather at home and walk out as a group of 6 supply or more. They count as
  the push's once they reach it. (Counted at once, the ones on the road dragged the front's middle home, the anchor never
  moved again, and the push fed them into the Brood's nest a few at a time for four minutes.)
- RETREAT, home, where it gathers again (the next push waits for 4 supply more, up to 20 more):
  - armed enemies near it worth 1.4 times the push (and over 300);
  - it has lost two thirds of what went out and joined;
  - it is worth less than 0.65 of the enemies near it and has lost a third;
  - fewer than three fighters left;
  - the base is attacked by more than 1.5 times its home guard while the push is far out;
  - a siege took too long.
- THE REWIND. A machine at home run down off the gear ground, with no enemy beside it, gets a Winder who walks out and
  winds it. (In round A, three Pendulums that had chased Raptors past the gear field stood frozen for two minutes: the
  shared escort winds only when no threat holds the army at home.)
- The shared computer still defends the base with what is at home, and sends no waves of its own while the plan runs.

## The coaching (round A, fixes, round B)

As for the Springer timing and the Brood (docs/brood_new_play_3.md), each plan was played in filmed, coached games
(tools/play_clockwork_builds_b.gd), and I looked at the pictures myself, frame by frame. Round A: eight filmed games
(Greenhold 11 and Kestrel Rise 12; the Pendulums against the Brood's Rush and Timing; the Heavy Works push against the
Hard Crown), and a few measured ones between them. What the films showed, and what was changed:

1. The push waited until 11:00. The shared computer's own training made Springers and a Ballista, few Clock Soldiers,
   and the push wanted eight. Now the plan trains its own mix after the opening: its heavy machines at the Heavy Works,
   and its front (Clock Soldiers) at the Light Works, the front's first few before the heavy machine's cogs.
2. A supply-gated step ("18 regulator") stopped the reading while the Brood's rush kept the supply under 18: the
   Pendulums waited half a minute. Now that Regulator has no supply number (the supply guard lays one when it is short).
3. Three Pendulums stood frozen at home for two minutes: they had chased Raptors past the gear field and run down, and
   the shared escort winds only while no threat holds the army at home. Now a Winder walks out to wind them (THE REWIND).
4. The big Mainspring's Tension sat at its cap (400) for minutes while the cogs were short: the small one now, three
   Winders more on a Cog Press (cogs earned by 7:00, Greenhold 11 against the Crown: 3,988 before, 5,308 after).
5. Against the Crown, the Heavy Works push never went (it wanted 28 supply), and the Crown's Musketeers came to the
   Clockwork's expansion at 9:12 and wiped out the army at home: the Clockwork lost the game at 13:00. Now it goes with
   about 20 supply.
6. Out, the Clock Soldiers charged the Musketeers at the Crown's new Town Hall and died one by one while the Ballistas
   stood back. Now THE SCREEN: the front holds a line in front of the Ballistas and meets only what comes close.
7. The push razed the Crown's expansion (the Ballistas' bolts burned its Town Hall and Mills), then walked up to the main
   and met its whole army at the ramp: 3,100 value lost in a minute. Now THE MAIN WAITS (worth 1.3 times the enemy's army
   seen lately; for the Heavy Works push also 2,600 value at least, since a main's army is mostly unseen), and it retreats
   at once from an army worth 1.4 times its own.
8. On Kestrel Rise the anchor walked past the end of the path, toward the Mother over a footprint, where the front could
   not follow: the push stood still at her nest's edge for three minutes. Now the anchor stops at the path's end and the
   front goes for the goal itself.
9. On Greenhold the reinforcements on the road counted in the front's middle: it never seemed "at" the anchor, the anchor
   never moved, and new units were fed into the Brood's nest a few at a time for four minutes (6,245 value lost). Now
   they join on arrival, and the push retreats once it has lost two thirds of what went out and joined.
10. The Pendulums fought the Brood Mother when her Rootmaws stood beside her: the push's memory of the Brood ran one think
    in six, and the Rootmaws were "never seen". Now every think: it heads for the Rootmaws, the Mound Turtles and the
    rooted father first.

Then a first measured round (25 games) and three more films, and the last fixes, all for the Heavy Works push against
the Crown (the Pendulums' numbers below were measured after fix 10 and did not change after it):

11. Eight Clock Soldiers walked up to a Crown ramp having seen one Musketeer and died there: the main now also waits for
    2,600 value (the army in a main is mostly unseen), and enemies above the anchor on high ground are not chased up the
    ramp (the line steps back out of their reach).
12. Clock Soldiers chased kiting Musketeers 500 px from their Ballistas: the Heavy Works push's leash is 360 px.
13. At a Crown town the front went for the buildings by itself, away from its Ballistas: a building is now sieged like a
    wall when Ballistas are along. A Cottage in a ramp counts as a wall.

Round B is the measured games below (each plan and the old plans on the same maps and seeds), and three filmed games for
the pictures.

## The numbers (round B)

Hard Clockwork against a Hard computer, 12 minutes each (or until a winner). The same map and seed for every plan. The
games are not exactly repeatable: the same seed can play out a little differently from run to run.
`tools/test_clockwork_builds_b.gd` plays them (`json:<file>`); `tools/clockwork_builds_b_report.py` makes these tables.
"Brood economy lost" counts Rootmaws, Mound Turtles and grubs the Brood lost. "Killed / lost" is the value of units the
Clockwork killed and lost.

### When the build is ready

| map | foe | plan | Heavy Works laid | stands | 1st Pendulum | 2nd | 3rd | 1st Ballista | 2nd | Great Winder | 2nd hall laid | push out | first wall piece down | first Rootmaw/turtle killed |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Greenhold 11 | Brood rush | Pendulums | 2:58 | 3:47 | 4:32 | 5:07 | 5:49 | 6:53 | 8:22 | never | 4:47 | 6:42 | never | never |
| Greenhold 11 | Brood timing | Pendulums | 2:57 | 3:47 | 4:35 | 5:11 | 5:46 | 7:00 | 7:50 | never | 3:38 | 5:46 | never | 7:49 |
| Greenhold 11 | Brood xrush | Pendulums | 2:58 | 3:47 | 4:23 | 5:02 | 5:45 | 7:09 | 8:54 | never | 4:55 | 6:58 | never | 9:24 |
| Greenhold 11 | Brood economy | Pendulums | 2:57 | 3:46 | 4:30 | 5:05 | 5:41 | 6:15 | 8:48 | never | 3:37 | 5:41 | never | 9:30 |
| Kestrel Rise 12 | Brood timing | Pendulums | 2:58 | 3:48 | 4:36 | 5:11 | 5:46 | 7:00 | 9:41 | never | 3:38 | 8:41 | never | 9:59 |
| Greenhold 11 | Brood balanced | Pendulums | 2:57 | 3:47 | 4:32 | 5:07 | 5:42 | 6:48 | 7:42 | never | 3:38 | 5:42 | never | 8:23 |
| Kestrel Rise 12 | Brood rush | Pendulums | 2:52 | 3:42 | 4:18 | 4:53 | 5:30 | 6:56 | 9:33 | 8:28 | 4:32 | 6:56 | never | 9:09 |
| Frostmere 11 | Brood rush | Pendulums | 2:54 | 3:43 | 4:18 | 4:54 | 5:29 | 6:35 | 10:16 | never | 4:34 | 7:51 | never | 9:51 |
| Highmoor 7 | Brood economy | Pendulums | 2:57 | 3:47 | 4:35 | 5:11 | 5:46 | 8:33 | never | never | 3:38 | 5:47 | never | never |
| Greenhold 12 | Crown balanced | old Balanced | 4:14 | 5:04 | 9:21 | never | never | 6:42 | never | 7:53 | 3:33 | never | never | never |
| Kestrel Rise 11 | Crown balanced | old Balanced | 9:07 | 9:55 | never | never | never | never | never | never | 4:08 | never | never | never |
| Greenhold 11 | Crown rush | old Balanced | 6:12 | 7:01 | 8:12 | never | never | 9:01 | never | 10:01 | 3:33 | never | never | never |
| Greenhold 11 | Brood rush | old Balanced | 7:48 | 8:38 | 11:19 | never | never | 9:34 | never | never | 4:44 | never | never | never |
| Greenhold 11 | Brood timing | old Balanced | 5:34 | 6:23 | 7:23 | never | never | 8:18 | 9:30 | never | 3:51 | never | never | 6:08 |
| Greenhold 11 | Brood xrush | old Balanced | 5:19 | 9:34 | 11:19 | never | never | never | never | never | 4:38 | never | never | 10:52 |
| Kestrel Rise 12 | Brood timing | old Balanced | never | never | never | never | never | never | never | never | 5:16 | never | never | never |
| Frostmere 11 | Brood rush | old Balanced | never | never | never | never | never | never | never | never | 4:04 | never | never | never |
| Highmoor 7 | Brood economy | old Balanced | 4:51 | 5:42 | 7:27 | never | never | never | never | never | 3:52 | never | never | 6:56 |
| Kestrel Rise 12 | Brood timing | old Rush | never | never | never | never | never | never | never | never | 6:19 | never | never | never |
| Greenhold 11 | Brood rush | old Rush | 6:31 | 7:21 | 9:35 | 10:57 | never | 11:31 | never | never | 5:47 | never | never | never |
| Greenhold 11 | Crown balanced | old Balanced | 4:21 | 5:11 | 8:59 | 10:00 | never | 6:20 | 11:30 | 7:44 | 3:36 | never | never | never |
| Kestrel Rise 12 | Crown balanced | old Balanced | 9:24 | 10:12 | never | never | never | 11:11 | never | never | 4:06 | never | never | never |
| Frostmere 11 | Crown balanced | old Balanced | never | never | never | never | never | never | never | never | 4:47 | never | never | never |
| Greenhold 11 | Crown balanced | Heavy Works push | 3:02 | 3:52 | 7:56 | 10:54 | never | 4:27 | 5:33 | 5:02 | 3:43 | 5:40 | never | never |
| Kestrel Rise 12 | Crown balanced | Heavy Works push | 2:49 | 3:38 | 8:14 | 8:49 | 10:50 | 4:14 | 5:20 | 4:50 | 3:30 | 5:24 | never | never |
| Frostmere 11 | Crown balanced | Heavy Works push | 2:58 | 3:46 | 8:22 | 8:57 | 10:13 | 4:24 | 5:30 | 5:00 | 3:39 | 5:31 | never | never |
| Greenhold 12 | Crown balanced | Heavy Works push | 3:02 | 3:52 | 7:48 | 8:23 | 10:06 | 4:27 | 5:33 | 5:02 | 3:42 | 5:34 | never | never |
| Kestrel Rise 11 | Crown balanced | Heavy Works push | 3:06 | 3:57 | 8:14 | 9:30 | 10:29 | 4:32 | 5:37 | 5:07 | 3:47 | 5:42 | never | never |
| Greenhold 11 | Crown rush | Heavy Works push | 2:57 | 3:46 | 8:45 | 9:20 | never | 4:22 | 5:41 | 4:57 | 3:37 | 5:44 | never | never |
| Greenhold 11 | Brood rush | Heavy Works push | 2:57 | 3:47 | 9:46 | never | never | 4:17 | 5:35 | 5:02 | 4:13 | never | never | never |
| Kestrel Rise 12 | Brood timing | Heavy Works push | 2:53 | 3:44 | never | never | never | 4:19 | 5:25 | 4:54 | 3:35 | never | never | never |

### The economy and the fights

| map | foe | plan | Winders 6:00 / 8:00 / 10:00 | cogs earned 6:00 / 8:00 / 10:00 | foe earned 8:00 / 10:00 | army 8:00 (CW / foe) | killed / lost by 8:00 | by 10:00 | by 12:00 | Brood economy lost by 12:00 (Rootmaws, turtles, grubs) | pushes, retreats | winner |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Greenhold 11 | Brood rush | Pendulums | 19 / 24 / 30 | 3917 / 5972 / 9189 | 3757 / 4669 | 1535 / 1275 | 1650 / 1180 | 1775 / 2035 | 3125 / 3175 | 0, 0, 13 | 2, 1 | none by 12:00 |
| Greenhold 11 | Brood timing | Pendulums | 21 / 26 / 36 | 4378 / 6624 / 9958 | 8541 / 11977 | 2350 / 1500 | 2225 / 690 | 2350 / 1415 | 6595 / 7370 | 1, 0, 30 | 1, 1 | none by 12:00 |
| Greenhold 11 | Brood xrush | Pendulums | 19 / 21 / 30 | 3703 / 5633 / 8590 | 2610 / 3525 | 1675 / 1150 | 850 / 730 | 2100 / 1350 | 3625 / 1550 | 0, 1, 27 | 1, 0 | clockwork at 10:43 |
| Greenhold 11 | Brood economy | Pendulums | 23 / 28 / 34 | 4391 / 6891 / 10099 | 9792 / 10723 | 1790 / 3145 | 2075 / 1095 | 2750 / 1785 | 4300 / 3875 | 0, 1, 23 | 2, 2 | none by 12:00 |
| Kestrel Rise 12 | Brood timing | Pendulums | 17 / 15 / 23 | 4307 / 5535 / 7193 | 3927 / 6021 | 1340 / 1300 | 2050 / 2300 | 2225 / 2500 | 3825 / 2965 | 2, 2, 14 | 1, 0 | none by 12:00 |
| Greenhold 11 | Brood balanced | Pendulums | 23 / 25 / 36 | 4384 / 6734 / 9853 | 9321 / 12619 | 1785 / 2350 | 3350 / 1075 | 5425 / 2025 | 8140 / 5800 | 2, 1, 28 | 2, 2 | none by 12:00 |
| Kestrel Rise 12 | Brood rush | Pendulums | 22 / 26 / 30 | 3862 / 5739 / 8781 | 3428 / 4378 | 1305 / 1375 | 1425 / 890 | 2225 / 890 | 4590 / 1720 | 1, 2, 28 | 1, 0 | clockwork at 11:36 |
| Frostmere 11 | Brood rush | Pendulums | 22 / 23 / 30 | 4163 / 5942 / 8808 | 3717 / 4580 | 2120 / 1225 | 1875 / 670 | 2800 / 950 | 4250 / 1735 | 2, 0, 28 | 1, 0 | clockwork at 11:16 |
| Highmoor 7 | Brood economy | Pendulums | 22 / 27 / 4 | 4389 / 7285 / 8624 | 9383 / 12856 | 1800 / 4995 | 575 / 930 | 3650 / 5525 | 4025 / 9575 | 0, 0, 25 | 2, 2 | brood at 11:44 |
| Greenhold 12 | Crown balanced | old Balanced | 23 / 28 / 29 | 4374 / 6812 / 9493 | 6460 / 9880 | 1735 / 840 | 440 / 1040 | 555 / 2710 | 2085 / 6170 | - | - | none by 12:00 |
| Kestrel Rise 11 | Crown balanced | old Balanced | 23 / 30 / 30 | 4415 / 6923 / 10447 | 7220 / 11020 | 1685 / 1210 | 280 / 280 | 1035 / 3290 | 2240 / 6855 | - | - | none by 12:00 |
| Greenhold 11 | Crown rush | old Balanced | 19 / 24 / 23 | 3818 / 5907 / 8194 | 6080 / 9500 | 1675 / 1130 | 115 / 720 | 350 / 2165 | 1590 / 4255 | - | - | none by 12:00 |
| Greenhold 11 | Brood rush | old Balanced | 12 / 23 / 26 | 3843 / 5596 / 8066 | 3885 / 5513 | 810 / 1450 | 925 / 1520 | 1975 / 2505 | 2990 / 3845 | 0, 0, 14 | - | none by 12:00 |
| Greenhold 11 | Brood timing | old Balanced | 22 / 28 / 12 | 4416 / 6866 / 9093 | 7991 / 11130 | 1495 / 3925 | 975 / 1430 | 3725 / 5595 | 4365 / 8690 | 0, 1, 31 | - | none by 12:00 |
| Greenhold 11 | Brood xrush | old Balanced | 12 / 15 / 19 | 3546 / 4975 / 6730 | 2438 / 3703 | 445 / 1000 | 1075 / 2130 | 1250 / 2550 | 2700 / 2610 | 0, 2, 13 | - | none by 12:00 |
| Kestrel Rise 12 | Brood timing | old Balanced | 5 / 0 / 0 | 3892 / 3892 / 3892 | 3935 / 3955 | 0 / 2700 | 425 / 4815 | 425 / 4915 | 425 / 4915 | 0, 0, 10 | - | brood at 8:02 |
| Frostmere 11 | Brood rush | old Balanced | 17 / 9 / 13 | 4234 / 5462 / 6385 | 3937 / 5570 | 515 / 1450 | 975 / 3345 | 2075 / 3965 | 3725 / 4195 | 0, 0, 12 | - | none by 12:00 |
| Highmoor 7 | Brood economy | old Balanced | 16 / 2 / 1 | 4226 / 4930 / 4935 | 8426 / 12168 | 765 / 3655 | 1350 / 2520 | 2375 / 3685 | 2525 / 5965 | 1, 1, 33 | - | brood at 11:38 |
| Kestrel Rise 12 | Brood timing | old Rush | 19 / 0 / 0 | 3984 / 4809 / 4809 | 3652 / 4583 | 0 / 2250 | 625 / 3925 | 625 / 5820 | 625 / 5820 | 0, 0, 11 | - | brood at 9:22 |
| Greenhold 11 | Brood rush | old Rush | 16 / 19 / 23 | 3681 / 5399 / 7161 | 3043 / 3792 | 740 / 1725 | 725 / 1700 | 1575 / 2650 | 1650 / 3100 | 0, 0, 21 | - | none by 12:00 |
| Greenhold 11 | Crown balanced | old Balanced | 24 / 28 / 27 | 4390 / 6663 / 9183 | 6840 / 9120 | 2490 / 815 | 165 / 500 | 1090 / 805 | 3515 / 3670 | - | - | none by 12:00 |
| Kestrel Rise 12 | Crown balanced | old Balanced | 22 / 30 / 32 | 4395 / 6792 / 10235 | 6840 / 9500 | 1510 / 1220 | 50 / 365 | 1535 / 1760 | 3375 / 3660 | - | - | none by 12:00 |
| Frostmere 11 | Crown balanced | old Balanced | 17 / 24 / 24 | 4270 / 6030 / 8417 | 3800 / 7600 | 2350 / 1020 | 50 / 310 | 590 / 2180 | 2030 / 4060 | - | - | none by 12:00 |
| Greenhold 11 | Crown balanced | Heavy Works push | 24 / 29 / 31 | 4312 / 6931 / 9478 | 6460 / 9880 | 1575 / 1210 | 420 / 1235 | 900 / 2810 | 3440 / 4660 | - | 2, 2 | none by 12:00 |
| Kestrel Rise 12 | Crown balanced | Heavy Works push | 27 / 36 / 36 | 4435 / 7154 / 10738 | 6840 / 8360 | 1620 / 1055 | 475 / 530 | 2460 / 1700 | 3085 / 2100 | - | 1, 1 | none by 12:00 |
| Frostmere 11 | Crown balanced | Heavy Works push | 24 / 33 / 37 | 4292 / 6915 / 10225 | 5700 / 8360 | 1200 / 790 | 755 / 1150 | 755 / 1400 | 940 / 2420 | - | 2, 1 | none by 12:00 |
| Greenhold 12 | Crown balanced | Heavy Works push | 25 / 29 / 35 | 4318 / 6833 / 9881 | 6840 / 10260 | 1615 / 770 | 280 / 820 | 760 / 940 | 2835 / 2585 | - | 2, 1 | none by 12:00 |
| Kestrel Rise 11 | Crown balanced | Heavy Works push | 26 / 29 / 33 | 4184 / 6306 / 9812 | 6840 / 9880 | 1200 / 1120 | 465 / 1250 | 1280 / 2100 | 2470 / 4710 | - | 2, 1 | none by 12:00 |
| Greenhold 11 | Crown rush | Heavy Works push | 22 / 28 / 25 | 4121 / 6045 / 9225 | 6460 / 9500 | 1760 / 485 | 715 / 750 | 1505 / 2300 | 2225 / 3645 | - | 1, 1 | none by 12:00 |
| Greenhold 11 | Brood rush | Heavy Works push | 8 / 13 / 13 | 3301 / 3861 / 5126 | 3989 / 6306 | 520 / 1625 | 950 / 1480 | 1475 / 2690 | 2755 / 4735 | 0, 0, 15 | 0, 0 | none by 12:00 |
| Kestrel Rise 12 | Brood timing | Heavy Works push | 23 / 15 / 18 | 4361 / 5628 / 6529 | 3908 / 5732 | 200 / 1800 | 1550 / 2685 | 2125 / 3355 | 2450 / 5865 | 0, 0, 17 | 0, 0 | none by 12:00 |

### Averages

| plan | foe | games | Winders 8:00 | earned 8:00 | earned 10:00 | killed / lost by 10:00 | by 12:00 | Brood economy lost by 12:00 | push out | won / lost / none |
|---|---|---|---|---|---|---|---|---|---|---|
| old Balanced | Brood | 6 | 12.8 | 5286 | 6516 | 1970 / 3869 | 2788 / 5036 | 0.8 Rootmaws/turtles, 18.8 grubs | never | 0 / 2 / 4 |
| old Balanced | Crown | 6 | 27.3 | 6521 | 9328 | 859 / 2151 | 2472 / 4778 | - | never | 0 / 0 / 6 |
| Heavy Works push | Brood | 2 | 14.0 | 4744 | 5827 | 1800 / 3022 | 2602 / 5300 | 0.0 Rootmaws/turtles, 16.0 grubs | never | 0 / 0 / 2 |
| Heavy Works push | Crown | 6 | 30.7 | 6697 | 9893 | 1276 / 1875 | 2499 / 3353 | - | 5:36 (6 of 6) | 0 / 0 / 6 |
| Pendulums | Brood | 9 | 23.9 | 6261 | 9010 | 2811 / 2052 | 4719 / 4196 | 1.7 Rootmaws/turtles, 24.0 grubs | 6:40 (9 of 9) | 3 / 1 / 5 |
| old Rush | Brood | 2 | 9.5 | 5104 | 5985 | 1100 / 4235 | 1137 / 4460 | 0.0 Rootmaws/turtles, 16.0 grubs | never | 0 / 1 / 1 |


Crown buildings razed by 12:00 (Heavy Works push / old Balanced, same maps and seeds): Greenhold 11 5 / 13, Kestrel Rise
12 6 / 4, Frostmere 11 3 / 0, Greenhold 12 9 / 2, Kestrel Rise 11 2 / 1, Greenhold 11 against the Crown's Rush 2 / 0.
Average 4.5 / 3.3. The Crown's Labourers killed by 12:00: 4.7 / 6.2.

## Pictures

docs/shots/clockwork_builds_b/ (captions.md says what each shows): the Pendulums against the Brood's Rush on Greenhold 11
(round B), the Heavy Works push against the Hard Crown on Greenhold 11 (round B, and the coached game straight to the
main), two round A pictures, and a GIF of the Pendulums' first push fight.

## Tools

- `tools/test_clockwork_builds_b.gd`: one game, with the milestones, a line every 30 seconds and the numbers at 4, 6, 8,
  10 and 12 minutes. THE TESTS: `check:pendulum` (Greenhold 11 against the Hard Brood's Rush, `until:540`): the Heavy
  Works by 4:30, two Pendulums by 6:30, 16 Winders at 6:00, a second Clocktower by 7:30, the push out by 9:00, still in
  the game. `check:heavy` (Greenhold 11 against the Hard Crown, `until:600`): two Ballistas and the Great Winder by 8:00,
  16 Winders at 6:00, a second Clocktower by 7:30, the push out by 10:00. Both pass (2:57, 5:00, 22, 4:41, 6:54; and
  5:33 and 5:02, 24, 3:43, 5:54).

      godot --headless --fixed-fps 30 --script res://tools/test_clockwork_builds_b.gd -- map:greenhold seed:11 cw:pendulum foe:brood fp:rush until:540 check:pendulum
      godot --headless --fixed-fps 30 --script res://tools/test_clockwork_builds_b.gd -- map:greenhold seed:11 cw:heavy foe:crown fp:balanced until:600 check:heavy

- `tools/play_clockwork_builds_b.gd`: the coached, filmed game. `cw:`, `foe:`, `fp:`, `set:key=value` (any plan
  setting), `main_k:0` (the coach's variant: straight for the enemy's main). It writes minutes.txt, events.txt and the
  key moments (the Heavy Works, each push going out, the march every 30 seconds, sieges, falls, retreats, goals, the
  GIF frames of the first push fight).

      xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_clockwork_builds_b.gd -- cw:pendulum foe:brood fp:rush map:greenhold seed:11 out:/abs/dir end:690

- `tools/test_clockwork_springer_timing.gd check:1` still passes (READY at 4:18, the leap at 5:34).

## What is open (for the owner)

Proposals (balance: the owner's call; nothing was changed):
1. THE BROOD'S ECONOMY PLAN out-masses every Clockwork plan by 7:00 to 8:00 (3,100 to 5,000 army value against 1,800).
   The Pendulums' blades are the right answer, but four of them cannot hold 60 Raptors. Worth a look at the Brood's
   Raptor rate on that plan, or at the Pendulum's price (200 cogs + 75 Tension) so a few more come.
2. THE CLOCK SOLDIER AGAINST THE MUSKETEER loses every exchange in the open, which is why the Heavy Works push trades
   badly with the Crown even with the Ballistas behind it: SHIELD WALL helps only once researched (Light Works, Tension).
   Cheaper or earlier SHIELD WALL, or a little more armour against shots on the march, would give the push's front a
   chance.
3. THE SPRING BALLISTA reaches 300 against a Musketeer's 190, but reloads only while it stands (7 s): it is good against
   buildings (the Crown's expansions burned in most games) and weak in a moving fight. A shorter reload when crewed would
   make the push's "screen and shoot" work against an army, not only against a town.
4. THE GREAT WINDER is slow (27): the push walks at its speed and the Ballistas' (34). That is the plan's idea ("slow and
   hard to stop"), but it gives the Crown a minute and a half to gather.

The computer (next jobs):
5. A real siege of a walled ramp was never reached in 12 minutes: the push waits for 2,600 value or 1.3 times the
   enemy army it has seen. Longer games, or a second push that joins the first, would test it.
6. Scouting: the push decides on what its side has seen. Against the Brood a Swift over its nest at about 5:00 would
   tell the push when the Raptor mass is too big to walk into (the Economy games).
7. The Heavy Works push against the Brood never went out (it wants two Ballistas, the Great Winder, a Pendulum and six
   front units; the Brood's Raptors kept killing the front). Against the Brood the computer should play the Pendulums;
   RANDOM PLAN already prefers them, but the plan could also switch when its scout sees the Brood.
8. The goal flips at times between the Crown's expansion and its main (the shared target rule changes its mind every
   ten seconds); the push then walks back and forth a little.

Merge notes (for the main session): `scripts/ai.gd` gets two rows in `AI.STRATEGIES` (after "xrush", before the Springer
timing's comment) and `AI.random_plan`; `scripts/main.gd` one line (the RANDOM PLAN pick); `scripts/ai_clockwork.gd`
small marked hooks in `_ready`, `_make_plan`, `_on_errand`, `_army`, `_produce`, `_spot`, `_do_build`, and a block at the
end. The strategy tooltip in tools/i18n/50_springer_timing.txt still says only "Springer timing is Clockwork only".
