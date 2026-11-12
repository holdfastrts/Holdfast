# The Clockwork mirror, coached (job clockwork-v-clockwork-coach)

Short sentences, to be read aloud. (Written as the job goes; the numbers at the end are filled in last.)

The owner (2026-11-11 22:35): every matchup coached and filmed "with the same level of scrutiny and attention" as the
Crown v Brood job. This job is the Clockwork mirror: Hard Clockwork OPTIMAL against Hard Clockwork OPTIMAL. Coaching, as a
human coach would: film real games, watch them, name each mistake with its time and a picture, fix the decision behind
it, play the same seeds again and look for the mistake.

No unit, building or economy number changed. Only the Clockwork computer's play (scripts/ai_cw_push.gd and
scripts/ai_clockwork.gd, new functions; the lines changed in existing functions are listed below).

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
