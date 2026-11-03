# Raid micro, and the Brood's answers (0.26.6, branch raid-micro)

The owner's playtests of 2026-11-03 (v0.26.2, logs in `docs/playtests/2026-11-03/`). Six items, A to F. Design rules
followed (docs/design_principles.md): 1 (soft counters: a slow defender is out-run, not a hard stop; fast units and
shooters remain the counter to riders), 2 (anti-snowball: a side behind in economy must be able to hurt the leader's
exposed income; a bank at the cap must not sit unused), 3 (builders worth harassing, and the harassed side has answers).

## A. The Crown's Horsemen ran from the Tyrant Sire (Mirewood, Crown AI v Brood Economy, about 4:08)

Owner: "Crown turned tail and ran too soon; with 3 Horsemen stay there and kill more workers... not fight the Tyrant
Sire and try to focus on the workers... Brood is too far ahead in economy."

Note: `crown_raid_ran_early.txt` in the folder is a copy of `human_crown_v_brood_econ.txt` (the owner's own game, not the
Crown AI game in the picture), so the cause was read from the code, and the test rebuilds the situation.

**Why.** Both the raid (AI._raid) and the harass (AIHarass) treated a Tyrant Sire, or the Mother on her feet, as a
reason to go home at once (`is_big` in `outmatched`), and the raid also counted every non-worker within 260 px by
supply (a Sire is 4) towards "danger". A Sire walks at 64; a Horseman rides at 112. He can never catch them.

**What changed** (scripts/ai_harass.gd, the raid in scripts/ai.gd):
- A defender is **slow** when it is melee (reach under 100 px) and at most 0.74 of the party's slowest speed: against
  Horsemen that is the Tyrant Sire (64), the Mother (24), a Rootmaw on foot (80), a Brute (56), a Mound Turtle; never a
  Raptor (96), a Tyrant Challenger (84), Spitters (they shoot) or anything against a Clock Soldier or a Musketeer.
- Slow defenders are **kited**: a rider that is within 80 px of a slow defender's bite steps 170 px away (a plain move,
  so his loaded pistol is kept for a grub), choosing among 12 directions the open one that puts most distance between
  them, leaning towards his prey. Prey (grubs) that a slow defender would reach before the rider cuts it down (its reach,
  plus 80 px, plus 1.5 s of its walk) counts 300 px farther: the grubs it can't reach in time come first.
  Grubs are attacked with an attack order (RideBy fires the pistol at the order's target, the grub). Without prey the
  rider rides on to the worker line on a plain move, never an attack-move (which would pick the Sire, pistol and all).
- They **go home** only for a threat that can catch them or shoot them: the armed units that are not slow, worth more
  than the party (catchers, fast enough to catch them, at twice the party's number or more count double: 8 Raptors
  against 3 Horsemen send them home), the supply of non-slow defenders near them (6, or 9 when behind), or low health.
- **Behind in economy** (the enemy workers it has seen, the scout's count or in sight now, are over 1.3 times ours plus
  3): the raid stays longer: home below 35% health instead of 45% (the harass: 25% instead of 35%), danger 9 instead of
  6, the harass's MAX_BACKS 5 instead of 3 and MAX_TIME 240 s instead of 150.

**Test** `tools/test_raid_kite.gd`: a Brood worker line (8 grubs at a rooted Rootmaw), a Tyrant Sire chasing the nearest
rider the whole time (the worst case: the Brood's computer is off), three Horsemen of the Crown's raid.

| | grubs killed in 30 s | riders lost | kite steps |
|---|---|---|---|
| 0.26.5 (before) | 0 (the party rode home at once) | 0 | 0 |
| 0.26.6 | 6 | 0 | 30 |

Then 8 Raptors come at them: the party rides home (about 440 px homeward in 6 s, all three alive).

`tools/test_ai_harass.gd` still passes its Horseman and raid cases. Its Clock Soldier case fails two checks (it dies to
the Sire, 0/75 hp) on main before this change too: a Clock Soldier (68) is not faster than the Sire (64), so nothing
here changes for it.

## B. Why a lone Musketeer went to harass (Greenhold, `crown_lone_musketeer_rootmaw_bug.txt`, 2:35)

Claude's reading is **confirmed**: "goes on to harass the workers (out alone)" is the line `AIHarass.adopt_strays`
writes, and it adopts any army unit (not in a wave, detachment, guard, raid, scout or errand) found more than 900 px
from our nearest building. It was not a plan. The Musketeer was the Crown's first (2:12) and got that far by chasing:
most likely the Brood's ramp-watch grub (posted at 1:10 at the foot of the Crown's ramp), which a Musketeer engages and
follows as the 0.24.24 Clock Soldier followed a scout (docs/ai_harass.md). A headless re-run of the seed diverges from
the owner's game, so the chase itself could not be replayed.

**Decision** (owner: "usually it would be a bad idea"): a slow soldier (under 95 speed: a Musketeer, a Guardsman)
found out alone (no armed friend within 400 px) is **not** taken by the harass; it walks home ("comes home (out alone,
too slow to harass)"), unless it is clearly safe (no armed enemy on its feet seen within 15 tiles). Riders are still
adopted. The Clockwork keeps its old rule: the owner asked on 2026-10-31 for a stray Clock Soldier to push on to the
worker line (docs/ai_harass.md).

## C. A Rootmaw got up to fight and a new Rootmaw took its spot (same log, `rootmaw_double.jpg`)

**Why.** 0.26.2's uproot-to-fight (`_nb_maw_guard` in scripts/ai_brood_new.gd) got the Rootmaw up; up, it no longer
claimed its ground (`BroodRoot.place_problem` only counts ROOTED Rootmaws and planned ones), so the computer's next
Rootmaw was planned on the "free" spot. When the fight ended the old one walked back and tried to root where the new one
now stood.

**Fix.** A Rootmaw the computer gets up to fight keeps its spot: `nb["keep"]`, which `BroodRoot.plan_of` reports as its
plan while it is up, so no other creature may root or be planned there (the player's ROOT ghost sees it too). It
re-roots on it when the fight is over (as before), and the reservation goes when it is rooted again or after 90 s. If
the spot really was taken anyway (a creature rooted there), it lets go ("a Rootmaw's spot was taken while it fought: it
roots elsewhere"), the spot is marked bad for 60 s and `_nb_rootmaws` finds it a free spot on the next think: no loop.

**Test** `tools/test_rootmaw_reroot.gd` (the Brood's computer on): a Musketeer hits one of its Rootmaws; it gets up,
its spot is reserved, the computer's next Rootmaw spot is elsewhere; the Musketeer leaves; it roots again on its own
spot (0 px off) and no new Rootmaw was planned there. [taken]: with a turtle forced onto its spot it roots on another
spot (about 38 tiles away: the Economy plan prefers the far edge of its ground) within 45 s, never trying the taken one.

## D. The Brood could not defend a micro'd Horseman rush (Glimmerdeep, the owner as Crown v Brood Balanced)

Owner: "the brood ai tried to defend only with the Tyrant and I was able to juke it. They need to use the workers to
fight and the Rootmaw to fight and block... Tyrant is too slow... keep the Tyrant rooted and make Raptors, but the real
answer is Spitters actually."

**What changed** (scripts/ai_brood_new.gd):
- **Riders** (`is_rider`: on the ground, armed, speed 95 or more, melee): the computer remembers how many it has seen at
  once in the last 3 minutes (`riders_n`, `riders_about()` with 2 or more).
- **The Sire is not sent after riders**: the small-harass defence no longer adds the Tyrant Sire when every enemy in the
  group is a rider (0.26.2's rule sent him), and `_nb_sires_needed` (which got the Sires up for an attack at the Mother)
  leaves riders out of the count.
- **Grubs fight or run** (`_nb_grubs_vs_riders`, every profile): grubs within 5 tiles of a rider gang up on it when
  they are 5 or more and win on paper (`_fight_wins`, margin 0.6); else they run to the nearest warriors or rooted Mound
  Turtle (not where the rider is), or the Mother. They go back to work 8 s after the rider is gone from their Rootmaw (or
  after 40 s): the alarm's old pull-back rule, now for every profile (`_nb_pull_back`).
- **Spitters**: with riders about, the Venom Sire is grown at once (the plan's time and the rush's "warriors first" wait
  are skipped) and the eggs go one Spitter per Raptor.
- Already there and unchanged: the Rootmaw gets up to bite or back off (C), and the alarm roots a Mound Turtle in front
  of the natural.
- Not done: moving a turtle onto the main's ramp to block it (the alarm's "turtle in front of the natural" is the
  nearest thing; a ramp block would also shut the Brood's own army in).

**The kiting test against the smarter Brood** (`test_raid_kite.gd [smart]`, the Brood's computer on, 40 s, three
Horsemen, 8 grubs at a Rootmaw, its Sire rooted at his nest, the Raptors it lays meanwhile): the Sire never went
after the riders (0.26.5: he did, 13 half-seconds on a rider and 445 px from his nest). Honest result: with the Sire
kept home the riders killed **6 to 7 grubs and lost 0 to 1 rider** (two runs); with the Sire chasing (before the
change) they killed 2 and lost none (he did scare them off, at the price of his line laying no warriors while he was away). In 40 s no Spitter can
hatch, so this test shows the first minute only; the answer the owner names (Spitters, Raptors) comes with the Venom
Sire over the next minutes. To check in his next game: whether grubs ganging up costs more grubs than it saves.

## E. A maxed Brood army stood idle (Ashfall 3-player FFA, 8:55, `brood_army_idle.jpg`)

**Why.** The Brood's wave target (`_wave_target`) was set once, when the wave left. Its first target, the Clockwork's
main, was razed by 8:27; the wave had lost nothing and seen no enemy army, so it never "pulled back", and idle creatures
were only sent again to the same razed spot. The Clockwork's new hall was a few screens away.

**Fix.** A wave at its goal (within 7 tiles) with nothing armed ahead and no enemy building it knows within 9 tiles goes
on (`_nb_next_goal`): to the **weakest** enemy still in the game (fewest supply; in a free-for-all the one it can
finish), its nearest building the Brood has seen, else that enemy's centre or start. Logged "its wave goes on to the
next target".

**Test** `tools/test_brood_spend.gd [goal]`: ten Raptors as a wave on an empty spot, the Crown's Town Hall seen 19
tiles away: the wave turns to the hall within a few seconds and walks there.

## F. A banked Brood stopped growing (Thornwood Maze, the owner as Crown v Brood Hard Economy)

The log: 76/76 supply from about 6:00 to 12:00, the bank climbing from 1,297 to 11,502, the army flat at about 1,900, no
attack until 13:00.

**Why** (reproduced headless on the owner's seed, Crown AI in his place: the same 76/76 from 5:30): supply comes from
the Mother (16) and each rooted Mound Turtle (12). When supply ran short the computer looked for a turtle spot on the
rings 7 to 13 tiles round the Mother, 5 tiles clear of every turtle and Rootmaw, in her home region, or a turtle spot on
new ground (an expansion). On Thornwood's cramped main every ring spot was used by 5:30, every new-ground spot was taken
or too far, and the morph silently gave up each think. The owner's hint was right: turtles were laid for expansions or
in a narrow ring, never "just for supply". With supply capped the army could never reach the Economy plan's attack size
(34), and the plan's wave time (8:30) and then the alarm held it at home anyway.

**Fix** (`_nb_supply_turtle_spot`): with no ring spot left, a supply turtle roots anywhere legal on or beside its swamp:
round the Mother out to 17 tiles, or round any rooted turtle (home or new ground), 3 tiles clear of the others instead of
5, in any region it can walk to (its home region first), away from the enemy, the spot nearest the Mother first. When
short of supply with 300+ food, a turtle on new ground (forward) is still preferred when one is free and safe. And a
Brood **at its cap with 1,500+ food** and 12+ army supply attacks whatever the plan's wave time, the alarm, a rush hold
or the attack size say (`_nb_army`).

**Measured** (the probe on the owner's seed): 0.26.5: cap 76 from 5:30 on, food 855 at 6:30 and climbing. 0.26.6: cap
88 at 6:30, 100 at 7:00, 124 at 7:30, 160 (the maximum) at 9:00. **Test** `tools/test_brood_spend.gd [supply]`: the cap
passes 100 by 8:00 (112 at 7:30; 124 at 8:30, 184 at 9:30), it was at its cap with 1,000+ food for only 10 s, and its
first wave left at 8:30 (13:00 in the owner's game).

## Open

- A turtle rooted on the main's ramp as a block against riders (D) is not done.
- The kiting is tuned for and tested with Horsemen; any fast harasser of the Clockwork's taken by AIHarass gets the same
  rule, untested here.
- Headless Godot exits with code 134 (an abort at shutdown) after every test here, after printing its result; the
  result lines are what count.
