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

RESULTS_SHORT

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
PUSH goes once two Ballistas, the Great Winder and twelve front units are at home, 22 supply or more (against the Brood:
six front units and a Pendulum).

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
  after a chase walks back. (In round A the Clock Soldiers charged the Musketeers and died one by one while the Ballistas
  stood back.)
- AT THE GOAL. The front goes for the goal itself (a Rootmaw, the Mother), else for the enemy's buildings seen near it.
  Nothing left there for 12 seconds: on to the next goal.
- THE SIEGE. A wall or gate on the path within 340 px: the front stands 215 px from it (out of musket reach), the
  Ballistas 255 px (in their reach), aimed at it. Enemies that come out are met by the front. When it falls, the march
  goes on. At most 150 seconds at one piece.
- THE MAIN WAITS. The enemy's main (its start: a Crown or Clockwork main, the Mother's nest) only with the strength for
  it: worth 1.3 times the enemy army seen in the last two minutes. Else the push holds on the ground it took, and the
  reinforcements join it. (In round A the push razed the Crown's expansion, walked up to its main and met its whole army,
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

ROUNDS

NUMBERS

PICTURES

OPEN
