# The Clockwork mirror, coached (job clockwork-v-clockwork-coach)

Short sentences, to be read aloud.

The owner (2026-11-11 22:35): every matchup coached and filmed "with the same level of scrutiny and attention" as the
Crown v Brood job. This job is the Clockwork mirror: Hard Clockwork OPTIMAL against Hard Clockwork OPTIMAL. Coaching, as a
human coach would: film real games, watch them, name each mistake with its time and a picture, fix the decision behind
it, play the same seeds again and look for the mistake.

No unit, building or economy number changed. Only the Clockwork computer's play (scripts/ai_cw_push.gd,
scripts/ai_clockwork.gd, scripts/ai_cw_army.gd and one line of scripts/ai_optimal.gd; new functions, the lines changed in
existing functions are listed below). Version 0.33.17.

## The short version

Five coaching rounds, 18 filmed games on six maps (Greenhold, Dune Sea, Hollowfen, Kestrel Rise, Cinder Steps, Red
Coast), the pictures in docs/shots/clockwork-v-clockwork-coach/. The mirror is decided by small edges in the middle game;
that is as it should be. The mistakes were mostly the WINNER's: it did not finish a won game.

1. The hunt took the army off its push: no Winders went along, 50 of 78 soldiers stood run down in the enemy's main.
   Now the push hunts, its Winders along. (All matchups.)
2. At an enemy Clocktower, the soldiers go for the Winders mending it first.
3. One enemy on the cliff no longer holds a winning push at the foot of a ramp.
4. The march no longer waits for the Great Winder (sweeping wrecks at home, 2,275 px away). (All matchups.)
5. ... nor more than 12 s for Ballistas shooting something off the way.
6. Hunting, the push does not regroup after every building.
7. Both sides: the push going out no longer counts every unit killed since 0:00 against the enemy army it expects
   ("worth 4,445 against the 1,225 it reckons", into 49 soldiers on their gears).
8. A goal in reach (420 px) is the goal reached: everyone breaks it.
9. The hunt's order: the enemy's halls, its other buildings (none left = out at once), then its Winders.
10. With every enemy hall gone the push splits into parties, one at each last building and unit.
11. The side behind: a few reactive Clockwork turrets no longer read as a turtle (it switched to the Heavy Works build and
    stopped training soldiers, 1,915 cogs in the bank while its army died).

## The numbers

Hard Clockwork OPTIMAL against itself, 8 maps (Greenhold, Dune Sea, Hollowfen, Kestrel Rise, Cinder Steps, Red Coast,
Frostfang, Twin Fords), the same seeds before and after, headless to 15:00 (tools/study/cwcw_coach.py). "Before" is main at
0.33.16 (24 games, 3 seeds a map); "after" is this branch (16 games, the first 2 seeds of each map; the third seed was cut to
save time once the fixes were final). The 16 before games of the same seeds are the fair comparison.

| | before, the same 16 seeds | after (16) | before, all 24 |
|---|---|---|---|
| decided by 15:00 | 8 (P1 4, P2 4) | **11** (P1 7, P2 4) | 14 (P1 9, P2 5) |
| mean length of the decided | 12:53 | 13:10 | 12:52 |
| a side clearly ahead (army twice the other's, 1,500 or more) | 15 games, at 8:44 | 13 games, at 8:36 | 22, at 8:43 |
| ... and it won | **8 of 15**, 4:53 after | **11 of 13**, 4:38 after | 14 of 22, 4:43 after |
| draws with one side beaten in all but name | 0 | 0 | 1 |
| cogs earned per side at 8:00 / 10:00 | 9,340 / 12,623 | 9,040 / 12,292 | 9,338 / 12,617 |
| army per side at 8:00 / 10:00 | 1,578 / 2,317 | 1,526 / 2,309 | 1,538 / 2,324 |
| first attack (median) | 5:15 | 5:20 | 5:15 |
| games with a script error | 1 (ballista.gd:328, known) | 1 (the same) | 1 |

- The won games are finished: a side clearly ahead won 11 of 13 games (before 8 of 15). The 5 draws left are 2 even games
  with nobody ahead and 3 where the leader got ahead only at 11:00 or not at all.
- The economy and the armies are the same (no number changed): the fixes are in what the army does.
- Two measured versions on the way were WORSE and were not kept, which is why the numbers matter: fixes 1-11 with the hunt
  going for the enemy's Winders before its buildings (14 games: 6 decided, the side ahead won 6 of 13, 2 draws beaten in
  all but name) and the same with the hunting parties after units only (16 games: 5 decided, 5 draws beaten in all but
  name). The Winders outran their hunters while the buildings stood. Data: docs/clockwork-v-clockwork-coach/data/.

## How it was watched

- tools/shot_ai_match.gd (extended): `sa:`/`sb:` the plans (here `optimal` on both sides), `every:30` a picture of each
  side's army (where most of its soldiers stand) and of its main every 30 s, plus the fights it finds; `status.txt` a line
  per side every 15 s (bank, cogs earned, Winders, army, run down, halls, the push's phase), `story.txt` (the AI STORY
  lines), `ai.txt` every 30 s with the push's state (phase, size, how much of its front is at its anchor, the goal and how
  far, committed, hunting, the army's wind, each Ballista's and the Great Winder's distance from its spot). The files are
  written every minute, so a film that dies on the way keeps what it saw (one did, at 14:02).
- The coaching seeds: Greenhold seed 1, Dune Sea seed 2 (sides swapped), Hollowfen seed 3, Kestrel Rise seed 4 (swapped).
  Four maps of different shapes: a ramp to a high main (Greenhold), open desert (Dune Sea), a big marsh with far bases
  (Hollowfen), a ridge map (Kestrel Rise).
- A game is not the same game twice with the same seed (the computers' timings and the path queue differ run to run).
  So "the same seed again" means the same map and starts, and the same kind of moment is looked for, not the same frame.
- tools/study/cwcw_coach.py: the measuring batch (8 maps x 3 seeds, headless, to 15:00) and its report.

## Round 1 (main at 0.33.16): what the films showed

Every game opens the same way on both sides: OPTIMAL's common opening (Winders non-stop and a fast second Clocktower), the
scout reads the other as GREEDY at 1:30-2:00 and both keep Balanced ("steady waves punish the greed"). The economies are
within 2-5% of each other to 7:00. Both armies go out at 5:00-5:45 with 10-13 Clock Soldiers (700-965). Who wins that
first exchange is close to a coin toss (the side that attacked first won or led about half the games). The side that
loses it falls behind; from about 8:00 the other is two to seven times stronger. So far so good: a mirror is decided by
small edges. The mistakes are in what comes after: the winner does not finish.

- **Greenhold 1** (headless): P2 ahead from 8:00 (2,185 against 461). P1 at 0 army from 14:00. A draw at 15:00, P1 with 1
  hall left. P2 hunted at 12:34, stopped at 12:50 (P1 had trained one soldier), hunted again at 13:05.
- **Dune Sea 2**: P2 pushed at 5:00 (700) into P1's 700 on its own gears and pulled back; P1 countered at 5:53 (1,195
  against 925) and won the fight in P2's natural. P1 ahead from 8:00 (2,480 against 320), but P2 fell only at 12:07. The
  hunt went on and off eight times (P2 trained one Clock Soldier, the hunt ended, 5 s later began again); each time the
  shared hunt took the army off the push. P1's push headed for a Clocktower at 9:41 and reached it at 10:58.
- **Hollowfen 3**: P1 ahead from 8:00 (2,105 against 967), P2 at 0 army from 12:00. The hunt began at 11:58 and never
  ended. At 14:02 50 of P1's 78 soldiers stood RUN DOWN in P2's main, 119 tiles from home (picture
  r1_hollowfen_1402_rundown.jpg: the blue army piled round P2's Clocktower, standing still). A draw.
- **Kestrel Rise 4**: P1 won at 11:18 (its push of 1,110 beat P2's 850 at P2's natural at 6:36; P2's defenders came out
  of the main a few at a time).

## Mistakes and fixes

### 1. The hunt ran the army down (the winner, every won game)

Seen: Hollowfen 3, 12:00-15:00 (picture r1_hollowfen_1402_rundown.jpg); Greenhold 1 and Dune Sea 2, the hunt on and off.

The decision: AIClockwork._army ran the shared hunt (scripts/ai_hunt.gd, rules-fixes 3) first and returned when it
hunted. So while the enemy had no army, the Clockwork's push, its ONE ARMY rules, its escort Winders and its rewinding
(_b_rewind) all stood still. The hunt sends every soldier to the enemy's nearest building with an attack-move. A Clockwork
soldier off its gear ground runs down in about 80 s. And the shared hunt ends the moment the enemy trains one soldier.

The fix (AIClockwork._cw_hunt, CwPush.hunt_on, _hunt_launch, _hunt_goal):
- With ONE ARMY the Clockwork's hunt is its PUSH. When the enemy has no fighting unit (and had one, or from 8:00, the shared
  rule), the push goes out with what is at home, committed, and its goal is the enemy's nearest HALL, then its nearest
  building of any kind, then its last unit. Its escort Winders go along and wind the soldiers, as on any push.
- The hunt ends only for an enemy army worth a quarter of ours (and 300 at least), not for one new soldier.
- `-- cwhunt:off` plays it as before.

### 2. The menders first (the winner, at the enemy's halls)

Seen: Dune Sea 2 (round 2), 7:41-9:00: two Spring Ballistas laid siege to P1's main Clocktower for 79 s, the front
screening them, and it did not fall: every Winder near it mended it. Round 1, Dune Sea 2: a committed push took 77 s from
"heads for the Clocktower" to "at its goal" and more to break it.

The decision: at the goal, the committed push sent everyone at the building (CwPush._assault) and the Ballistas' siege
kept the front screening (CwPush._siege_tick). Nobody went for the Winders mending it.

The fix (CwPush._break_fixers, _siege_fixers): at a building it breaks, up to 40% of the front go for the enemy Winders
within 220 px of it, the nearest first, two at most on each; the rest break the building. Against the Clockwork only.
A new line says how long each building at its goal took to fall ("the Clocktower at its goal falls after N s").
`-- cwfixers:off` plays it as before.

### 3. One soldier on the cliff held a winning push at the ramp's foot

Seen: Greenhold 1 (round 2), 10:03-11:26: P1's committed push of 44 units (4,360 value, every one at its anchor) stood
at the foot of P2's ramp (picture r2_greenhold_1033_ramp.jpg). The log: "meets 1 armed enemies (70 value)", "enemies shoot
down from high ground: the line steps back out of their reach".

The decision: CwPush._fight steps the line back out of reach of enemies on high ground when the anchor is below them (made
against the Crown's Musketeers on a ramp: 8 Clock Soldiers ran up a Crown ramp after 3 Musketeers and died).

The fix (CwPush._climb_ok): a COMMITTED push against the Clockwork, worth 4 times what stands up there, goes on up.
`-- cwclimb:off` plays it as before.

### 4. The march waited for the Great Winder

Seen: Hollowfen 3 (round 2), 10:02-11:32: P1's committed push of 30-38 (2,885-3,500 value) stood at P2's natural, its
anchor still for 90 s (picture r2_hollowfen_1032_waits_for_gw.jpg). The push's state line: "[great_winder (29, 13) off
2275 order sweep]": its Great Winder was at home, sweeping wrecks 2,275 px away.

The decision: since clockwork-ai-v2 the Great Winder joins the push at once wherever it is (CwPush._join) and sweeps the
wrecks near it between fights (AIClockwork.gw_tend). CwPush._march waits ("lag") until every Ballista and the Great Winder
is within HEAVY_LAG (320 px) of its spot behind the front. A Great Winder sweeping at home never comes.

The fix (CwPush.gw_nowait_on, one line in _march): the march never waits for the Great Winder (unarmed, it catches up).
In every matchup (it is a plain fault, not the mirror's). `-- cwgwlag:off` plays it as before.

### 5. ... nor for long for its Ballistas

Seen: Hollowfen 3 (round 2), 13:32-14:02: P1's committed push, all 60 of its front at its anchor, stood still in the open
(picture r2_hollowfen_1402_waits_for_ballistas.jpg). "[ballista (99, 74) off 559 order amove]": its two Ballistas were
shooting a building 550 px off the way (the attack order of the last goal).

The fix (CwPush._lag_wait): a committed push against the Clockwork waits for its Ballistas 12 s at most; then the lagging
ones are walked to their spot with a plain move (they stop shooting elsewhere) and the march goes on.

### 6. Hunting, no regrouping

Seen: Greenhold 1 (round 3), 13:03-13:33: hunting (the enemy had no army), P1's front of 57 had 13 at its anchor; the march
waits until 60% of the front is at the anchor, so after each building the whole army walked back together before the next.

The fix (one condition in CwPush._march): hunting, the anchor goes on at once.

### 7. Going out into an equal army on its gears (both sides, the middle game)

Seen: Dune Sea 2 (round 3): "goes out: worth 3,015 against the 765 it reckons" (9:49; the enemy had about 2,200 at home),
"worth 4,445 against the 1,225 it reckons" (12:43; the enemy had 49 units, 3,920, on its gears: the push lost half and
pulled back at 13:40), "worth 5,435 against the 1,395 it reckons" (14:50; the enemy had about 2,940).

The decision: the army goes out worth 1.25 times the enemy army it reckons (ai_cw_army.may_launch). The reckoning is what it
saw lately, but never less than the table of what an enemy of that age has, less HALF OF EVERYTHING IT HAS KILLED SINCE
0:00. The table (3,500 at 12:00) is the army of an enemy that has lost units too, and the Clockwork enemy rebuilds about
1,400 of army a minute at 12:00. By the middle game everything killed had wiped the table out.

The fix (ai_cw_army._killed_for_reckon, one changed line in reckon): against the Clockwork only what it killed in the last
150 s counts for the push going out. The push's "clearly ahead" check (the commit, which finishes won games) still counts
everything killed (reckon(true)). `-- cwreckon:off` plays it as before.
The mirror table itself was checked against the real armies of the first 21 measured games (median at 5:00 630, 6:00 1,040,
8:00 1,670, 10:00 2,380, 12:00 3,070; the table 400, 800, 1,500, 2,500, 3,500): close enough from 8:00, left as it is.

### 8. The goal in reach is the goal reached

Seen: Kestrel Rise 4 (round 3), 8:32-10:18: P1 clearly ahead and committed (1,780 growing to 3,860 against 470-775), its
anchor stood 360 px short of P2's natural Clocktower for two minutes; "front 32, 16 at anchor". Half the front was already
at the Clocktower, shooting it on its attack-move, so the march never had 60% of the front at its anchor and never
"arrived" to send everyone in. The Clocktower fell at 10:18; the game at 12:57.

The fix (CwPush._goal_in_reach, one condition in _march's "arrived"): committed against the Clockwork, a building goal within
420 px of the anchor counts as reached: everyone breaks it, the menders first. `-- cwreach:off` plays it as before.

Picture r3_dune_1306_into_the_gears.jpg (Dune Sea 2, round 3, 13:06) is fix 7's moment: P1's push (left, its Ballistas
far left in the open) walks into P2's base, where P2's army of 49 stands on its own gears between the Cog Presses. It lost
half and pulled back at 13:40.

### 9. The hunt broke the enemy's last buildings one at a time

Seen: Dune Sea 2 (round 4, fixes 1-8 in): P1 won, but only at 14:17. From 13:07 P2 had no hall, no army and no cogs, only
12-14 Winders (10-12 of them idle). The whole push broke its buildings one by one, "the Regulator at its goal falls after
2-7 s" a dozen times, walking as a block from each to the next (picture r4_dune_1332_buildings_not_winders.jpg: P1's army
in rows breaking UNLINKED buildings, P2's Winders scattered top left). Hollowfen 3 (round 4): P1's last Clocktower fell at
12:53 and 11 of its Winders were still alive at 15:00, a draw.

How a side loses: with no building left it is out at once, whatever units it has; with buildings it is beaten once it
has had no worker, no soldier and no means for a minute (rules-fixes).

A first fix sent the hunt at the WORKERS before the other buildings, and the parties (10) after the units. Measured, it was
worse: a Winder runs 74, a Clock Soldier 68, a hunted Winder flees, and the last one or two outran their party while the
buildings stood: 5 of the first 16 "after" games were draws with one side beaten in all but name (before: 1 of 24).

The fix (CwPush._hunt_goal): the hunt's order is the enemy's halls, then its other buildings, then its workers, then any
unit.

### 10. Hunting parties

The fix (CwPush._hunt_parties, CwPush._party_score): hunting against the Clockwork (and the Crown, after the check game
below) with every enemy hall gone, the push
stops marching as a block; its front and its Ballistas split into parties of up to 4, each at one of the enemy's last
buildings, then its units (Winders first), the nearest first. With 6 targets or fewer everyone goes, split evenly. At a
unit the shooters (Springers, range 170) and the Netters (they hold a unit 4 s) go first.

### 11. A few reactive turrets read as a turtle (the side behind, the middle game)

Seen: Cinder Steps 5 (round 5, a new map), 7:52: P2's scout saw P1's two Ratchet Turrets at an expansion, read DEFENSIVE
("turrets or rooted defenders") and OPTIMAL switched to the Heavy Works push from where it stood: its written build, 7
steps left, Spring Ballistas and a Great Winder first. It trained no soldier while it saved: 874 cogs in the bank at 8:06,
1,915 at 9:06, while P1's push of 1,990 (out at 7:39) broke its army of 1,450 at home. Its army was 100 at 9:06, the game
lost at 13:14. The same read came late in four other games (11:48-14:20), by the side already winning.

The decision: AIOptimal.choose, DEFENSIVE after the opening: the Clockwork picks the Heavy Works push ("a siege to break its
defences"). But the Clockwork computer only lays turrets as an answer (the owner's rule: static defence is not a build,
turrets only reactive), so in the mirror a DEFENSIVE read is never a turtle.

The fix (AIOptimal._mirror_turrets, one line in choose): the Clockwork against the Clockwork, after the opening, keeps what
it plays on a DEFENSIVE read. `-- optturrets:off` plays it as before.

## Rounds 4 and 5: the same seeds again, and two new maps

Round 4 replayed the four coaching seeds with fixes 1-8 (9 from Greenhold on), round 5 two new maps (Cinder Steps seed 5,
Red Coast seed 6, sides swapped) with fixes 1-10.

| film | round 1 (main) | round 4 / 5 |
|---|---|---|
| Greenhold 1 | (headless) P2 far ahead from 8:00, a draw | an even game to 12:00; P2 ahead from 13:00 (its push 5,900 against 1,215 reckoned), a draw |
| Dune Sea 2 | P1 ahead from 8:00, won 12:07 (the hunt on and off 8 times) | P1 ahead from 7:00, won 14:17 (fixes 9-10 came from it) |
| Hollowfen 3 | P1 ahead from 8:00, a draw: 50 soldiers run down in P2's main | P2 ahead from 9:49, no run-down soldier, P1's last hall at 12:53, a draw with 11 Winders left (fix 10 came from it) |
| Kestrel Rise 4 | P1 won 11:18 | P1 won 11:57 (the hunt from 8:08) |
| Cinder Steps 5 | | P1 won 13:14 (fix 11 came from P2's side of it) |
| Red Coast 6 | | P1 won 14:23; hunting parties from 12:44 (11 enemy units left, 1 at 13:44) |

A coach's eye on the winner in rounds 4-5: at most one soldier stood run down at any time in the six films (round 1: 55
in Hollowfen, 6 in Dune Sea); the hunt no longer flips on and off; a Clocktower at the committed push's goal fell in a
median 25 s (20 Clocktowers, 10 to 81 s), mostly after "goes for the N Winders mending it first" (the time was not logged
before this job; in round 2 two Ballistas did not break a mended main Clocktower in 79 s of siege); the push no longer
stands still for its Great Winder or its Ballistas.

## What changed where (for the merges)

New functions (all new logic is in these): AIClockwork._cw_hunt, _cw_hunt_set (scripts/ai_clockwork.gd); CwPush._hunt_launch,
_hunt_goal, _hunt_parties, _break_fixers, _break_note, _siege_fixers, _climb_ok, _lag_wait, _goal_in_reach
(scripts/ai_cw_push.gd); CwArmy._killed_for_reckon (scripts/ai_cw_army.gd); AIOptimal._mirror_turrets
(scripts/ai_optimal.gd).

Existing functions changed (each a line or two calling the new ones):
- AIClockwork._army: with ONE ARMY the Clockwork's own hunt (_cw_hunt) instead of the shared AIHunt.tick, which returned
  before the push ran. All matchups (the run-down army is not the mirror's alone). The shared hunt (scripts/ai_hunt.gd) is
  not changed; the Clockwork still reads its constants (EVERY, HUNT_AFTER, fighter) and its `_had_army`.
- CwPush.tick: the hunt's launch (_hunt_launch) and the hunting parties (_hunt_parties) before the goal.
- CwPush._commit_check: hunting = committed; the reckoning there is reckon(true) (all kills, as before).
- CwPush._commit_goal / _commit_goal_kept: the hunt's goal.
- CwPush._pick_goal: says when the building at its goal fell (_break_note).
- CwPush._march: no waiting for the Great Winder (gw_nowait_on, all matchups); _lag_wait; hunting needs no 60% at the
  anchor; _goal_in_reach in "arrived".
- CwPush._assault (committed at a building): the menders first (_break_fixers). CwPush._siege_tick: the same at a sieged
  building that is no wall (_siege_fixers).
- CwPush._fight: `low` is false when _climb_ok.
- CwArmy.reckon: a parameter `all_kills` (default false) and _killed_for_reckon in place of the plain value_killed.
- AIOptimal.choose: the DEFENSIVE branch first asks _mirror_turrets.
Gated against the Clockwork (the enemy's faction): the menders first, the cliff, the Ballistas' wait, the reckoning, the
goal in reach; the hunting parties against the Clockwork and the Crown (not the Brood, which lives while its Mother does);
OPTIMAL's DEFENSIVE read: the Clockwork against the Clockwork only. In every matchup:
the hunt through the push and its order (halls, other buildings, workers, the rest), the march not waiting for the Great Winder.
Every one has a switch (`-- cwhunt:off`, `cwfixers:off`, `cwclimb:off`, `cwgwlag:off`, `cwreckon:off`, `cwreach:off`,
`optturrets:off`; the Ballistas' wait goes with `cwgwlag:off`).
No unit, building, research or economy number changed. No shared AI file (scripts/ai.gd, ai_hunt.gd, ai_cw_army's tables)
changed apart from the lines above.

Tools: tools/shot_ai_match.gd (sa:/sb: plans, every:N pictures, status.txt, story.txt, the push's state in ai.txt, files
written every minute), tools/study/cwcw_coach.py (the measuring batch and its report; `--slots` for other pairings).

## Still wrong (for a later look)

1. **The middle game is a coin toss decided by who attacks into whom.** Both sides go out at 5:00-5:45 with 10-13 Clock
   Soldiers; the side that wins that exchange (about half the time the one that went first) snowballs. Pushes into the
   enemy's base, where its army stands on its own gears, wound and mended, need about 1.3 times the defenders to win
   (Hollowfen: 2,510 against 1,875 won; Dune Sea: 4,445 against 3,920 lost half). Fix 7 stops the worst ones (the
   reckoning wiped out by old kills), but the table of what an enemy of that age has is still the "typical" Clockwork army,
   and a side that out-earned its enemy by 10% still walks into an equal army now and then (Greenhold round 4, 12:02:
   "worth 3,355 against the 2,065 it reckons", the enemy had 3,660). A mirror-only reckoning by TRADES (the enemy's army is
   about ours plus what we lost less what we killed: the same AI, the same economy) was weighed and not applied: alone it
   would stop the 5:00 pushes too, and with nobody going out the mirror would be a 15:00 draw. A proposal for the owner
   below.
2. **The defence comes out in pieces.** The side defending its natural sometimes meets the push with a few units at a
   time while the rest are still on the way from the main (Kestrel Rise 4, round 1, 6:36). Not looked into further.
3. **The loser's economy dies with its Winders alive.** With its presses broken, 20-32 Winders stand idle, 0 cogs, no new
   press or hall laid (Hollowfen before, 12:00-15:00; Greenhold round 3, "idle 19"). The game ends only when they are
   hunted down. Not changed (the losing side's rebuild is the shared AI's dry-land rule, and a beaten side).
4. **The "fast rider" rule in the mirror.** The push ignores lone enemy Clock Soldiers round it as "fast riders" (a Clock
   Soldier is faster than a front with a Netter, a Pendulum or a run-down soldier in it): 10-20 such lines a game. Harmless
   in these games (the front still shoots what comes in reach), noted.
5. **Greenhold's high main.** A committed push took 80 s from the natural to the main's Clocktower up the ramp (after games,
   Greenhold s0, 11:30-12:51); the headless batch has no push state to say why (the films do: tools/shot_ai_match.gd).

## Claude's choices for the owner to confirm

1. **The hunt goes through the push in every matchup** (fix 1), not only the mirror: the run-down army and the missing
   Winders are the Clockwork's whatever the enemy. Its end condition is the Clockwork's own: an enemy army worth a quarter
   of ours (300 at least), not one new soldier. `-- cwhunt:off` gives back the shared hunt.
2. **The hunt's order** (fix 9): halls, other buildings, Winders, the rest. A side with no building left is out at once;
   chasing Winders first lost games (measured above).
3. **The menders first** (fix 2): up to 40% of the front, two at most on each Winder within 220 px of the building. Against
   the Clockwork only; the Crown's labourers mend too (a look for crown-v-clockwork-coach).
4. **The cliff** (fix 3): committed and worth 4 times what stands on the high ground, the push goes up. Against the
   Clockwork only (the rule was made for Crown Musketeers on a ramp, and it stays for them).
5. **The Great Winder is never waited for** (fix 4, every matchup); **Ballistas 12 s at most** (fix 5, committed against
   the Clockwork).
6. **The reckoning** (fix 7): against the Clockwork, the push going out takes off only what it killed in the last 150 s;
   the "clearly ahead" check keeps all kills (it is what finishes games).
7. **The turrets** (fix 11): in the mirror, after the opening, a DEFENSIVE read keeps the plan.
8. **Seeds**: films and batches use fixed seeds, but a seed is not the same game twice (see "How it was watched").

## Proposals (not applied)

1. **The mirror's reckoning by trades.** The table of what a Clockwork of that age has, less half of recent kills, still
   misjudges: "goes out: worth 3,470 against the 1,070 it reckons" at 9:50 (after games, Dune Sea s0) with about 2,500 of
   the enemy at home 40 s later; the push lost 2,940 for 1,260. In the mirror the same AI on the same economy has about our
   army plus what we lost less what we killed. As the only floor it would stop the 5:00 pushes too (no trades yet: the
   enemy is reckoned as big as us), and with nobody going out the mirror would end 15:00 draws; as a second floor from
   7:00 it might be right. Worth a measured try.
2. **The lockout after a failed push.** After a push pulls back the next one waits until it is worth 1.25 times what went
   out (AFTER_FAIL). Twice in a row and the bar can never be met: "its last push (4,870) had to pull back; the next goes
   worth 6,087 (it has 2,430)" from 11:44 to 15:00 (after games, Dune Sea s0), a draw. A bar that fades with time (back to
   the plain reckoning after 2-3 minutes) would let it go again. Shared by every matchup (ai_cw_army.may_launch), so left
   for the owner.
3. **The defender's edge on its gears.** A push into the enemy's base needs about 1.3 times the army there (mended,
   wound, its Ballistas behind). That is the defender's advantage the design principles ask for; keep it. If games should
   end sooner, a stronger push (Ballistas first, Springers on the cliffs) is the AI's way, not a number.

The data: docs/clockwork-v-clockwork-coach/data/<before|after|after_v1|after_v2>/<game>/ (result.json, cwlog.txt.gz: the
Clockwork's own match log lines). The table: `python3 tools/study/cwcw_coach.py report docs/clockwork-v-clockwork-coach/data/after`.

## Tests and the other matchups

The AI tests the Clockwork's computer has, run on the branch, all pass: test_ai_gg_rule, test_great_winder, test_ai_harass
(clock, horse, raid), test_ai_expand (crown, clockwork, brood), test_gear_turn_match, test_ai_optimal, test_clockwork_army
check:1, test_clockwork_home check:1, test_cw_air_ai, test_ai_scout_sentry; test_files and test_i18n too.

The other matchups, one game each (Hard OPTIMAL, Greenhold and Dune Sea, the same seeds; before = main at 0.33.16,
after = this branch before the last change, the parties against the Crown). Single games: they show nothing broke, not
a rate.

| Clockwork against | map | before | after |
|---|---|---|---|
| the Crown | Greenhold | won at 14:48 (the Crown's halls gone) | a draw: the Crown at 0 halls, 0 army, its last Cottages and palisades standing (hence the parties against the Crown) |
| the Crown | Dune Sea | a draw, the Crown ahead (12,920 earned against 11,354) | a draw, the Clockwork ahead (14,903 against 13,680) |
| the Brood | Greenhold | won at 7:20 | won at 9:19 |
| the Brood | Dune Sea | LOST at 9:09 | a draw at 15:00 (the Brood ahead on income) |

Data: docs/clockwork-v-clockwork-coach/data/cross/.
