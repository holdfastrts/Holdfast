# Rebuilding the Clockwork computer, step 1: the Springer timing (0.28.0, branch clockwork-springer)

Short sentences, to be read aloud.

The owner, 2026-11-03: "as soon as possible, 4 Springers that can jump and 1 flying unit that can scout. So we need an
Aviary, a Mainspring, an Escapement... It isn't an all-in, the economy is still being built behind this. Maybe 4 minutes.
Maybe it's going to be too late to be a reasonable strategy. But this is an important milestone for Clockwork."

Design rules followed (docs/design_principles.md): 1, telegraph and fairness (every leap shows its crouch; a Springer leaps
up only where its side sees, so the Swift has to be there and can be shot down; the computer knows only where the enemy
started and what its side sees); 2, anti-snowball (the economy keeps growing behind the attack; the raid can always leap
out and walk home). No unit, building or research number was changed.

## The short version

- The timing comes on time: four Springers, HIGH LEAP and the Swift are ready at **4:11 to 4:23** (average 4:19), in
  all 8 games. The owner's guess was 4:00. The old Balanced computer had its first Springers at 5:39 to 8:36 and never
  researched HIGH LEAP before 9:00.
- The economy keeps growing behind it, at a cost. At 6:00 it has **20 Winders and 3,969 cogs earned**, against 22.7 and
  4,382 for the old Balanced plan (about 9% less). At 8:00: 25.3 Winders and 5,818 cogs, against 27.0 and 6,818 (15%
  less). Its second Clocktower is laid at 4:51 to 5:14 (Balanced: 3:32 to 4:14).
- **As a fight, the attack is weak.** The raid goes out at 4:17 to 4:33 and first leaps in at 5:24 to 5:38. Against the
  Hard Crown, by 6:00 the Clockwork killed 155 value of units and lost 442 (average of 6 games). By 10:00: killed 353,
  lost 1,198 (the old Balanced plan, same games: 852 and 1,915). The Crown lost only 1 to 3 workers in a game (one is
  often its own scout): its workers run.
- **As harassment, it hurts where the Farms are in reach.** On Kestrel Rise the Springers landed in the Crown's Farms and
  burned them (two Farms in a game). The Crown's income stalled: it had earned 2,660 and 4,940 gold by 10:00, against
  9,120 when the same Crown played the old Balanced Clockwork. On Greenhold the Farms are out of reach of a leap; the Crown
  still earned 11 to 16% less by 8:00 (its farmers kept running). On Frostmere the Crown earned more against the
  Springer timing than against the old Balanced plan, whose early Clock Soldiers there cost it more. Over the 6 Hard games the Crown earned 22% less by 8:00 and
  18% less by 10:00 than against the old Balanced plan; the Clockwork itself earned 15% and 14% less.
- Against the Normal Crown (2 games): by 10:00 killed 695, lost 840 (Balanced: 675 / 2,135).
- No game had a winner by 10:00, either plan.
- So, plainly: the build works (on time, the economy keeps going). The attack works as economic harassment on a map like
  Kestrel Rise, where a Farm is within a leap of the cliff, and hardly at all where it is not. It never wins a fight: four
  Springers at 5:30 cannot stand against the five to eight Musketeers the Hard Crown keeps at home. Part of the Kestrel
  damage is the Crown computer's own weakness: it did not rebuild its Farms for minutes. The reasons, and what would make
  the attack work, are below. The owner decides; no balance number was changed.

## Why the attack does little (what the films show)

1. **The Musketeers come in about ten seconds.** The Hard Crown has 425 to 535 army value at 5:00 (five to eight
   Musketeers, a Horseman), standing at its ramp's top and its Barracks. A Crown main is small: they reach any landing
   spot in 8 to 12 seconds. Four Springers (450 value) lose to that many Musketeers, who also outrange them (190 against
   170).
2. **The spring needs 10 seconds after a leap.** So the Springers cannot leap out before the Musketeers are on them. A
   StarCraft Blink is ready again in 7 seconds, and Stalkers can blink out of a fight they just blinked into.
3. **The workers run.** The Crown's workers flee from armed enemies within about 8 tiles. A Labourer walks 74, a Springer
   70: the workers in reach when they land get away. What the raid does to the economy is the farmers' lost time (the
   films show a Farm going from 8 farmers to 0 for 20 to 30 seconds), not dead workers.
4. **The Farms are too far from the cliff.** On Greenhold and Kestrel Rise the Crown's Farms stand 7 to 9 tiles in from
   the cliff edge. The leap is 5 tiles. So the Springers land in the open, two Farms away, and walk the rest.
5. **Wind.** A Springer runs down in about 80 seconds off its gear field. The walk to the enemy main takes 40 to 60
   seconds. Without the two Winders at the cliff foot there would be no second leap. With them, there are 2 to 7 leaps in
   a game.
6. The diversion (four Clock Soldiers at the foot of the enemy's ramp) did not draw the Musketeers away: the Crown
   computer holds its ramp's top with part of its army and sends the rest to the leap.

What went better: on Kestrel Rise (seeds 11 and 12, Hard Crown) and against the Normal Crown, the Springers leapt in 4 to
7 times and the side killed 490 to 835 value after the raid went out. On Kestrel Rise seed 11 the third leap, at 9:04,
stayed up for 37 seconds and the fourth went straight back in at the same spot when the defence had walked off.

## What would make it work (proposals for the owner; nothing changed)

Balance (the owner's call):
1. **JUMP cooldown 10 s to 6 or 7 s** (the Blink). The Springers could leap out before the second volley, and back in
   sooner. This is the change closest to the idea.
2. **JUMP range 5 tiles to 6 or 7.** From the cliff foot they would land by the Farms, not two Farms away.
3. Springer reach 170 to 190 (the Musketeer's): they would not lose every exchange at range.
4. HIGH LEAP 100 Tension to 50: the timing would come about 20 seconds sooner (Tension is the brake on this build).

The computer (next jobs):
5. Hit where the army is not: the Crown's new Town Hall goes down at about 5:00, unwalled at first, with workers round it;
   or wait at the foot until the Crown's army has walked out of its main.
6. Six Springers instead of four (about 25 seconds later).
7. A real diversion: the plan's Clock Soldiers attack the gate (not stand at the foot), or the whole army pushes the ramp
   while the Springers leap at the back.

## The architecture

- `scripts/ai_clockwork.gd`, class `AIClockwork extends AI`: the Clockwork's computer of its own, made the way the Brood's
  is (`scripts/ai_brood_new.gd`). Every place that makes a computer makes it for the Clockwork: the match (`main.gd`), the
  sandbox, an online side taken over (`net_session.gd`), `tools/perf_bench.gd`.
- It keeps every shared part of `scripts/ai.gd`: the scout, the swarm rules, worker safety, the escorts, home defence,
  the micro, gg. Only while its opening build runs are the shared parts that spend switched off: the economy builder, the
  build-up, research, training and supply (`_econ_build`, `_build_up`, `_research`, `_produce`, `_supply`), and its scout
  does not change the plan.
- The plan OWNS the gold during the opening. No hiding of gold. The next step that is held up puts its price by; Winders
  are trained only from what is left.
- After the opening's `end` step it hands over to the shared computer, on the plan's row in `AI.STRATEGIES` (Balanced
  numbers). That is where later jobs put the milestone rules.
- The other Clockwork plans (Balanced, Rush, Economy, Timing attack) play exactly as before: AIClockwork passes them
  straight to the shared computer.
- `-- cwnew:off` on the command line plays a Springer timing slot as the old computer's Balanced, for comparisons.
- Small hooks in the shared computer: `AI._held_worker(u)` (a worker a plan keeps: the economy, the builders, the escorts,
  worker safety and the scout leave him be), and the Hard computer's "pull the whole wave back" leaves units on an errand
  alone.
- The plan is a selectable strategy, "Springer timing" (pt/es: "Ataque de Saltadores"), Clockwork only. A computer on
  RANDOM PLAN can pick it.

## The build order

Steps are read in order, as a player reads a written build. A number in front is the supply it waits for ("9 mainspring":
at 9 supply). A step waiting for a building or for Tension lets the next steps go with the cogs left over. A step waiting
for cogs, or for its supply, stops the reading there.

| # | step | what it means |
|---|---|---|
| 1 | 7 cog_press | the second Cog Press at 7 supply (the first stands at the start) |
| 2 | 8 movement_works | the first Light Works |
| 3 | 9 mainspring:big | the Mainspring on its BIG ring (2.6 Tension a second with 6 Winders, stores 400) |
| 4 | crew mainspring 6 | six Winders on it, from then on |
| 5 | 11 regulator | supply |
| 6 | escapement | as soon as the Works stands |
| 7 | movement_works | a second Works (two Springers at a time) |
| 8 | workers 18 | Winders up to 18 (14 before) |
| 9 | research high_leap | as soon as the Escapement works and 100 Tension is there |
| 10 | cuckoo_house | the Clock Aviary (50 Tension) |
| 11 | springer 4 | four Springers, from both Works |
| 12 | 18 regulator | supply |
| 13 | cuckoo 1 | the Swift |
| 14 | clock_soldier 4 | four Clock Soldiers, for the diversion at the enemy's ramp |
| 15 | attack | the raid takes the Springers, the Swift, two Winders and the Clock Soldiers, once HIGH LEAP is done or under way |
| 16 | workers 21 | |
| 17 | clocktower | the expansion |
| 18 | end | the shared computer plays on |

A Regulator also goes up out of order whenever the supply is nearly blocked.

Why the big Mainspring: Tension is what holds the plan back. HIGH LEAP 100, the Aviary 50, four Springers 100, the Swift 15:
265 Tension in about two minutes. The first draft had the small ring (2.0 a second with 3 Winders): ready at 4:41 on
Greenhold. The big ring: ready at 4:19. A Clocktower allows one Mainspring, so the big ring is the only way to more.

The first draft also kept the cogs of every step it was waiting for, three steps deep. The Winders stopped at 11 for a
minute while 300 to 600 cogs sat in the bank. Now only the first step held up keeps its price, and a step waiting for
Tension keeps its cogs only when the Tension is due within 12 seconds.

## The raid (scripts/ai_springer_raid.gd)

- A LANDING SPOT: open ground on the enemy main's high ground, within a jump of low ground our side can walk to (the
  STAGE, at the cliff foot). It is chosen near the enemy's economy that our side has seen (before anything is seen: the
  side of its hall away from its ramp, where a Crown's Farms and Mill stand), away from the guns seen in the last 15
  seconds, away from its ramp and gate, away from spots already used, and with the walk there clear of its ramp.
- The Swift flies over the stage. Nothing on the low ground sees up a cliff; the Swift does.
- The Clock Soldiers walk to the foot of the enemy's ramp, out of musket reach, as a diversion.
- The Springers LEAP IN together when they are wound, their springs are ready, the diversion is in place, and the armed
  enemies seen by the landing, or near it in the last 30 seconds, are weaker.
- Up there: armed enemies in reach first, the most hurt (focus fire); then workers in reach; then the economy that cannot
  run away (a Farm, the Powder Mill, the Horse Breeder), all on the same one. They stay within about 7 tiles of the
  landing, so they can leap out.
- LEAP OUT, down to the two Winders at the foot, when one is hurt, when the defence comes, when they are low on wind, or
  after 40 seconds. A Springer whose spring is still winding (10 seconds) walks to the edge meanwhile.
- At the foot, back from the edge, the Winders wind and mend them. Then back in at the same spot if the defence has walked
  off, else at another spot along the same cliff. Two or fewer left: home, topped up from the army at home, out again.
- After the opening: fresh Springers join it up to six; a lost Swift is replaced at the Aviary.

## The numbers

Hard Clockwork (Springer timing, or the old Balanced plan for comparison) against the Crown computer on Balanced. One game
of 10 minutes each, the same map and seed for both plans. tools/test_clockwork_springer_timing.gd, tables by
tools/clockwork_springer_report.py. The openings are nearly the same from seed to seed (a few seconds); the fights are not:
the value killed by 10:00 went from 50 to 1,055 between games on the same plan.

### When the build is ready

| map, seed | Crown | plan | Works | Mainspring | Escapement | HIGH LEAP | 4th Springer | Swift | READY | attack | 1st leap | 2nd hall laid |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| greenhold 11 | hard | springer | 1:35 | 2:02 | 2:36 | 3:41 | 4:14 | 4:18 | 4:18 | 4:18 | 5:27 | 4:58 |
| greenhold 11 | hard | balanced | 1:37 | 3:59 | 4:04 | never | 6:42 | never | never | never | never | 3:50 |
| greenhold 12 | hard | springer | 1:35 | 2:02 | 2:36 | 3:41 | 4:14 | 4:17 | 4:17 | 4:17 | 5:26 | 4:55 |
| greenhold 12 | hard | balanced | 1:37 | 3:44 | 3:49 | never | 5:39 | never | never | never | never | 3:33 |
| kestrel_rise 11 | hard | springer | 1:37 | 2:04 | 2:35 | 3:42 | 4:15 | 4:21 | 4:21 | 4:21 | 5:27 | 4:52 |
| kestrel_rise 11 | hard | balanced | 1:37 | 4:17 | 4:23 | never | 8:18 | never | never | never | never | 4:06 |
| kestrel_rise 12 | hard | springer | 1:37 | 2:04 | 2:34 | 3:42 | 4:15 | 4:21 | 4:21 | 4:21 | 5:24 | 4:51 |
| kestrel_rise 12 | hard | balanced | 1:37 | 3:44 | 3:50 | never | 6:40 | never | never | never | never | 3:32 |
| frostmere 11 | hard | springer | 1:37 | 2:01 | 2:37 | 3:38 | 4:11 | 4:23 | 4:23 | 4:33 | 5:38 | 5:14 |
| frostmere 11 | hard | balanced | 1:38 | 4:24 | 4:32 | 9:38 | 7:22 | never | never | never | never | 4:14 |
| frostmere 12 | hard | springer | 1:38 | 2:01 | 2:33 | 3:38 | 4:11 | 4:17 | 4:17 | 4:17 | 5:37 | 4:54 |
| frostmere 12 | hard | balanced | 1:38 | 4:14 | 4:19 | 8:58 | 6:59 | never | never | never | never | 4:02 |
| greenhold 11 | normal | springer | 1:36 | 2:02 | 2:36 | 3:41 | 4:14 | 4:18 | 4:18 | 4:22 | 5:25 | 4:55 |
| greenhold 11 | normal | balanced | 1:37 | 3:47 | 3:53 | never | 8:36 | never | never | never | never | 3:37 |
| kestrel_rise 12 | normal | springer | 1:37 | 2:04 | 2:35 | 3:42 | 4:15 | 4:21 | 4:21 | 4:21 | 5:25 | 4:52 |
| kestrel_rise 12 | normal | balanced | 1:37 | 3:46 | 3:50 | never | 6:52 | never | never | never | never | 3:32 |

### The economy and the fights

"Workers lost" counts the Crown's workers that died (its scout included). "Killed / lost" is the value of units killed by
the Clockwork side and lost by it.

| map, seed | Crown | plan | Winders 6:00 | cogs earned 6:00 | Winders 8:00 | cogs earned 8:00 | army 8:00 (CW / Crown) | Crown workers lost by 6:00 / 10:00 | value killed / lost by 6:00 | by 10:00 | winner |
|---|---|---|---|---|---|---|---|---|---|---|---|
| greenhold 11 | hard | springer | 21 | 4083 | 24 | 5743 | 1580 / 745 | 1 / 1 | 50 / 480 | 50 / 1855 | none by 10:00 |
| greenhold 11 | hard | balanced | 20 | 4301 | 30 | 6539 | 1355 / 1210 | 1 / 1 | 50 / 0 | 375 / 1570 | none by 10:00 |
| greenhold 12 | hard | springer | 20 | 4053 | 25 | 5680 | 1580 / 860 | 1 / 1 | 50 / 480 | 50 / 1575 | none by 10:00 |
| greenhold 12 | hard | balanced | 23 | 4381 | 28 | 6788 | 2000 / 1255 | 1 / 2 | 50 / 100 | 1035 / 2070 | none by 10:00 |
| kestrel_rise 11 | hard | springer | 20 | 4104 | 26 | 6188 | 1060 / 420 | 1 / 2 | 265 / 520 | 1055 / 880 | none by 10:00 |
| kestrel_rise 11 | hard | balanced | 24 | 4421 | 30 | 7207 | 1670 / 1105 | 1 / 3 | 50 / 0 | 1850 / 1810 | none by 10:00 |
| kestrel_rise 12 | hard | springer | 21 | 4063 | 26 | 5966 | 1310 / 605 | 3 / 3 | 365 / 400 | 540 / 720 | none by 10:00 |
| kestrel_rise 12 | hard | balanced | 23 | 4566 | 25 | 7119 | 2325 / 1045 | 2 / 2 | 100 / 210 | 1160 / 3005 | none by 10:00 |
| frostmere 11 | hard | springer | 18 | 3394 | 25 | 5278 | 1090 / 720 | 1 / 1 | 50 / 340 | 225 / 980 | none by 10:00 |
| frostmere 11 | hard | balanced | 22 | 4277 | 25 | 6647 | 2165 / 975 | 1 / 2 | 50 / 60 | 100 / 1180 | none by 10:00 |
| frostmere 12 | hard | springer | 20 | 4118 | 26 | 6052 | 1380 / 930 | 1 / 2 | 150 / 430 | 200 / 1180 | none by 10:00 |
| frostmere 12 | hard | balanced | 24 | 4344 | 24 | 6606 | 2345 / 860 | 1 / 5 | 50 / 60 | 595 / 1855 | none by 10:00 |
| greenhold 11 | normal | springer | 19 | 4081 | 25 | 5673 | 1580 / 605 | 1 / 3 | 50 / 440 | 505 / 1090 | none by 10:00 |
| greenhold 11 | normal | balanced | 21 | 4368 | 29 | 6422 | 2150 / 1465 | 1 / 1 | 50 / 70 | 1070 / 2330 | none by 10:00 |
| kestrel_rise 12 | normal | springer | 21 | 4198 | 26 | 6205 | 1575 / 420 | 2 / 3 | 200 / 270 | 885 / 590 | none by 10:00 |
| kestrel_rise 12 | normal | balanced | 19 | 4418 | 25 | 6554 | 1550 / 1560 | 1 / 1 | 50 / 320 | 280 / 1940 | none by 10:00 |

What the raid did to the Crown's economy (gold earned is the Crown's harvests and sales):

| map, seed | Crown | Crown's gold earned 6:00 / 8:00 / 10:00, against the Springer timing | the same, against the old Balanced | Crown buildings lost by 10:00 (Springer / Balanced) |
|---|---|---|---|---|
| greenhold 11 | hard | 3420 / 6080 / 9880 | 3800 / 7220 / 10260 | 0 / 1 |
| greenhold 12 | hard | 3420 / 6080 / 10260 | 3800 / 6840 / 9880 | 0 / 3 |
| kestrel_rise 11 | hard | 2660 / 3420 / 4940 | 3800 / 7220 / 9120 | 3 / 4 |
| kestrel_rise 12 | hard | 2660 / 2660 / 2660 | 3800 / 6460 / 9120 | 2 / 1 |
| frostmere 11 | hard | 3420 / 4940 / 7980 | 2280 / 4180 / 7600 | 1 / 1 |
| frostmere 12 | hard | 3420 / 4940 / 7980 | 2280 / 4180 / 7220 | 1 / 0 |
| greenhold 11 | normal | 3420 / 4560 / 7220 | 3420 / 6080 / 9500 | 1 / 0 |
| kestrel_rise 12 | normal | 2660 / 3420 / 5320 | 3040 / 5700 / 9500 | 5 / 0 |

Averages:

| plan, Crown | games | Winders 6:00 | earned 6:00 | Winders 8:00 | earned 8:00 | READY | killed / lost by 6:00 | by 10:00 |
|---|---|---|---|---|---|---|---|---|
| Springer timing, Hard | 6 | 20.0 | 3,969 | 25.3 | 5,818 | 4:19 | 155 / 442 | 353 / 1,198 |
| old Balanced, Hard | 6 | 22.7 | 4,382 | 27.0 | 6,818 | never | 58 / 72 | 852 / 1,915 |
| Springer timing, Normal | 2 | 20.0 | 4,140 | 25.5 | 5,939 | 4:19 | 125 / 355 | 695 / 840 |
| old Balanced, Normal | 2 | 20.0 | 4,393 | 27.0 | 6,488 | never | 50 / 195 | 675 / 2,135 |

Leaps in a game (Springer timing): Greenhold 2 and 2, Kestrel Rise 4 and 7, Frostmere 2 and 1 (Hard Crown); 7 and 7
against the Normal Crown.

## The coaching (round A and round B)

As for the Brood (docs/brood_new_play_3.md), the plan was played in filmed, coached games, and looked at picture by
picture. Round A (5 games, Greenhold and Kestrel Rise) found:
- the reserve held the cogs of three waiting steps at once: Winders stopped at 11 for a minute (fixed: only the first);
- the "end" step ran before the attack, so the raid never went (fixed: it waits for every step before it);
- the first Swift flew over the enemy's ramp for a look and was shot down (now it only flies over the stage);
- the first landing spot was by the gate (no economy seen yet, so it aimed at the hall); now it aims at the side of the
  hall away from the ramp, and keeps away from the ramp;
- the Springers chased fleeing workers far from the edge and could not leap out (now they stay near the landing, shoot
  what is in reach, then a Farm or the Mill);
- a leap out aimed only at the stage failed from deeper in (now any low ground within a jump);
- after the first leap they walked round the main to a second spot past the ramp, into the army (now the next spot is
  along the same cliff, and the walk there must keep clear of the ramp; back in at the same spot if the defence left).
Round B is the 16 measured games above and the filmed Kestrel Rise game in the pictures.

## Pictures

docs/shots/clockwork_springer/ (captions.md says what each shows).

## What is open

1. The proposals above (balance: the owner's call; the computer: next jobs).
2. After the opening the shared computer takes over (Balanced numbers). The milestone rules for the Springer timing's
   mid game are not written yet; the raid keeps going on its own, topped up to six Springers.
3. The shared computer may turn the raid's Swift into a Ticking Owl late (after 13:00, its Owl rule). Not seen in 10-minute
   games.
4. Only against the Crown. Against the Brood there is no high-ground main (its Mother sits where it started), the raid
   then walks in and treats her nest as the landing; not tested.
5. The other Clockwork plans are untouched: they wait for their own build orders in later jobs.

## Tools

- `tools/test_clockwork_springer_timing.gd`: one game, Clockwork computer against Crown computer, with the milestones, a
  line every 30 seconds, the numbers at 5, 6, 8 and 10 minutes, and the plan's decisions. `check:1` is the test (see
  below). `json:<file>` appends a line for `tools/clockwork_springer_report.py`, which makes the tables of this page.
- `tools/play_clockwork_springer.gd`: the coached, filmed game, in the style of the Brood's coaching
  (`tools/play_brood_3.gd`). `coach:draft|big|noswift|ai`, `set:key=value`. It writes minutes.txt (a line a minute),
  events.txt (the plan's decisions), the base when the 4th Springer is out, the Swift's look, every leap in and out, the
  diversion, fights, and the frames of the first leap for a GIF (`tools/play_brood_new_gif.py`).

    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_clockwork_springer.gd -- \
        coach:draft map:greenhold seed:11 out:/some/folder end:600
