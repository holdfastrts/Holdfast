# The Clockwork computer against a swarm (branch clock-ai-swarm, 0.26.5)

Short sentences, to be read aloud.

## What the owner saw

Game 1, 2026-11-01, v0.25.25, Glimmerdeep, seed 123537401. Hard Clockwork on Rush against Hard Brood on Economy.
Log: docs/playtests/ai_clock_v_brood_2026-11-01/log.txt.
"Clockwork misread the situation entirely, brood had a mass of Raptors and Clockwork expanded without a plan to deal with the mass of Raptors, it should have gone Pendulum. Clockwork is still attacking without a few Winders with it to repair and rewind."

Game 2, 2026-11-03, v0.26.2, Cinder Steps, seed 4031632555. Hard Brood on Extreme Rush against Hard Clockwork on Rush.
Log: docs/playtests/2026-11-03/clock_v_brood_pendulum.txt.
"Clockwork didn't tech up soon enough, when it saw the mass of Raptors should have got a few Pendulums."

## What was wrong

1. No room for the Heavy Works, ever.
   The computer looked for a spot only right beside a Mainspring.
   Since 0.25.0 Tension flows through the whole gear network, so that rule was out of date.
   But the bigger cause: on a corner main like Glimmerdeep the plateau is full by about 3:30.
   I checked it cell by cell. At 3:10 there were 8 spots for the Heavy Works' big ring.
   At 3:50, after the Mainspring and the Escapement went down, there were none at all, anywhere on the main.
   Two Light Works, two Cog Presses, four Regulators, a Mainspring and an Escapement fill it.
2. Nothing in the computer reacted to a mass of Raptors. Pendulums came only after three Springers, and only from a Heavy Works it never had.
3. The rush verdict. "SUCCEEDED, 1 workers left and no defenders" at 4:29 had two causes.
   The wave's worth was counted from the first six soldiers only; the ones that joined later were not counted, so a few kills looked like a win.
   And "finish them" was decided from the workers it could see: the Brood's grubs sit unseen behind its rooted creatures, so it saw one.
4. The escort Winders. The escort of 0.14.71 existed, but it followed the middle of the whole army, half of it at home.
   And a Winder near a fight was treated as a raided worker: it ran home to its press.

## What the computer does now

All of it is in scripts/ai.gd (small hooks) and scripts/ai_swarm.gd (the swarm rules).
`-- swarm:off` on the command line plays the computer as before, for comparisons.

- It counts every enemy fighter it has seen in the last two minutes that is still alive, each once, not only what is in sight at once.
  Rooted Brood creatures do not count: they are the Brood's buildings.
  A SWARM is 10 or more light melee bodies (Raptors), at least half of the fighters seen, by count.
  (By value, the Tyrant Sire and the Mother outweighed 13 Raptors, and the swarm was never seen.)
- Against a swarm: Pendulums first, from 2 up to 6 (2, and one more for every 10 Raptors), before the Ballista, the Great Winder and more Springers, without waiting for three Springers.
  Their Tension is kept from the Springers.
- Against the Brood, two Pendulums as soon as the Heavy Works stands, swarm seen or not.
  The Raptors mass at home, out of sight. In most test games the swarm was first "seen" at about 7:00, when it came.
- Against a swarm it saves for the tech and the Heavy Works even while its line is pressed.
- It holds its expansion while a swarm is seen, its tier-2 time has come, and the Heavy Works is not laid.
  Not when its main has no room for the Heavy Works at all: then the new hall is where the Heavy Works goes.
- It holds its expansion, and new waves, while the swarm seen is clearly bigger than its army (1.3 times, plus 100) and fewer than two Pendulums are out. A wave still goes when the supply is near its cap.
- A Ratchet Turret more at home once the Heavy Works stands (three when outmatched).
- The Heavy Works goes on any spot a Mainspring feeds through the network (beside a Mainspring first).
  As soon as a Mainspring stands, that spot is KEPT, so Regulators and turrets do not take it. The keep does not time out.
- The escort Winders follow the wave itself, do not run from the fight while soldiers of ours are within 260 px, and walk home with the wave when it pulls back.
  (Since 0.26.0 they also wind while they walk.)
- The rush verdict counts the units that joined the wave, and calls "finish" only after it saw six workers or more fall to three, with no enemy army seen in the last 20 seconds.

### Tried and switched off

A keep for the Heavy Works from the tier-2 start (about 2:50), before any Mainspring.
On Greenhold it got the Heavy Works down. On Glimmerdeep and Cinder Steps the Mainspring then had no room, and the tech came minutes late, or not at all.
It is in the code behind `-- fieldkeep:on`. It is off.

## Measurements

AI against AI, Hard Clockwork on Rush. Same seeds, on main 0.26.2 to 0.26.4 plus this branch. One game each.
These games are not exactly repeatable: the same seed gave tier-2 times a minute apart between runs.
tools/test_clock_ai_swarm.gd plays them (`map:`, `seed:`, `brood:xrush broodfirst:1` for the owner's second game, `swarm:off` for before).
Army value is cogs plus Tension of the Clockwork army, against the Brood's.

| Game | | Mainspring | Escapement | Heavy Works laid | first Pendulum | army at 7:00 | at 9:00 |
|---|---|---|---|---|---|---|---|
| Glimmerdeep 123537401 v Economy | before | 4:46 | 4:52 | never | never | 1,210 v 2,250 | dead |
| | after | 4:20 | 4:26 | never | never | 1,355 v 2,750 | 250 v 3,175 |
| Greenhold 11 v Economy | before | 4:58 | 5:03 | never | never | 1,070 v 2,525 | dead |
| | after (1) | 4:03 | 4:08 | 5:44 | 8:01 | 1,575 v 3,150 | 415 v 2,275 |
| | after (2) | 5:22 | 5:30 | 6:01 | never | 1,090 v 2,525 | dead |
| Highmoor 7 v Economy | before | 4:03 | 4:07 | never | never | 1,005 v 3,150 | dead |
| | after (1) | 4:03 | 4:07 | 5:07 | never | 1,395 v 3,200 | dead |
| | after (2) | 5:22 | 5:28 | 5:54 | 8:54 | 1,355 v 2,550 | 800 v 3,275 |
| Cinder Steps 4031632555 v Extreme Rush | before | never | never | never | never | 630 v 1,050 | 700 v 925 |
| | after | 4:18 | 8:17 | never | never | 490 v 800 | 1,260 v 825 |

(Greenhold after (1) and Highmoor after (1) were played before the "two Pendulums against the Brood" rule; the (2) runs with it.)

Other numbers:
- The misread "workers left and no defenders": gone in every game.
- Winders with the wave out in the field (2 or more within 320 px of its middle): 48% to 94% of the time before (Highmoor 48%, Glimmerdeep 64%), 76% to 100% after.
- The swarm was seen at 3:35 to 3:51 against the Extreme Rush, and at 6:14 to 7:15 against Economy.

## What this means, plainly

The Heavy Works now goes down on Greenhold and Highmoor, where it never did. Pendulums still come late, at 8:00 to 9:00.
On Glimmerdeep, the owner's map, nothing changed for the Pendulum: the main has no room, and the yard waits for the second hall.
Against the Extreme Rush the Mainspring now comes at 4:18 instead of never, and the computer survives to 9:00 with the bigger army, but the Escapement came at 8:17.
No game was won by the Clockwork, before or after. The Raptor mass of the Economy Brood (50 to 80 by 7:00) still beats it.

## Open (for the owner)

1. A cramped main. Should the computer plan its main for the Heavy Works from the start (fewer Regulators there, or one Light Works fewer), or should a cramped main expand early on purpose and put the yard at the new hall?
2. Pendulums come about two minutes after the Heavy Works stands. I did not find why in the time I had: Tension, the yard's queue, or the cogs. Worth a look next.
3. The Escapement against the Extreme Rush came four minutes after the Mainspring (Cinder Steps).
4. The computer cannot see the Raptors massing at home. Would a scout (a soldier or a Swift) at about 4:00 against the Brood be wanted?
