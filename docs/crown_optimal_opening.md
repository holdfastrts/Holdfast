# The Crown's OPTIMAL opening (crown-optimal-opening, 0.33.1)

The owner watched a Hard Brood OPTIMAL v Hard Crown OPTIMAL game on 0.33.0 (Saltmarsh Isles,
`docs/playtests/2026-11-06/crown_optimal_slow_expand_log.txt`) and asked why the Crown took so long to expand.
His decision (2026-11-06 09:17):

> "the powder mill was a mistake. It could have made barracks because you don't know if the enemy is rushing, but after
> the barracks it should've been a Farm. After scouting, then a decision on powder mill or horse breeder. In that
> particular game I think horse breeder to punish the greed."

## What was wrong, and why

In the owner's game the Crown had 8, 9, 12, 15, 17 labourers at minutes 1-5 (the Brood 7, 11, 15, 19, 32) and its second
hall went down at 4:45. Three causes:

1. **The common opening against the Brood** (`PLANS["optimal"]["bo_brood"]`) was the Barracks AND the Powder Mill at 0:44
   with 7 labourers, then 4 Musketeers, then the "pick" step. The pick step waits for the scout's read but had no
   exemption from the stall rule (`_bo_stalled`): at 1:29 it logged "Optimal waited 45 s with the gold in the bank" and
   was moved to the back. One labourer in the whole second minute: the gold went to the Mill and the Musketeers, and the
   labourers were capped by the farms' posts (one Farm = few posts, `owner_lab_cap`).
   (In the Crown mirror the same rule DROPPED the pick at 2:16 after two stalls; the opening ended there and the
   milestones put a Barracks AND a Horse Breeder down at once, before any read: measured in the baseline runs below.)
2. **Supply blocked 18/18 at 3:00**: the Siege push's opening used the old margin (two, two a Barracks): its Cottage
   was laid at 15/18 at 2:43 and stood at 3:03; the hall and the Barracks filled the 20 s build. 16-56 s blocked before
   6:00 in every baseline game against the Brood.
3. **The answer to a greedy Brood**: the read GREEDY came at 1:36-1:53 and `AIOptimal._punish` always picked the SIEGE
   PUSH against the Brood ("the riders would come too late"). Its `bo_brood` put 8 Musketeers, the 2nd Farm and the
   Horse Breeder BEFORE the second hall (at 15 labourers): the slowest expansion of all (4:20-4:45 laid) and no punish
   either (its guns came after 6:00).

## What changed

- **The common opening** (`scripts/ai_crown.gd` `PLANS["optimal"]`, one order in every matchup): the ramp Cottage, the
  Gate, the **Barracks** (at 7 labourers), the second **Farm** (at 8), then `pick`. No Powder Mill and no soldiers before
  the read. A rush seen (AIScout verdict `rush` = AGGRESSIVE) puts the Mill and the soldiers in at once (`_bo_defence`,
  unchanged; with the crown-ammo rule a Musketeer trained before the Mill grinds comes out with his bayonet and refills
  later, as `docs/crown_ammo.md` says).
- **The pick never stalls** (`_bo_stalled`: `pick` joins `attack`, `army`, `labs`): it holds no gold, the labourers and
  the Cottages ahead spend it while it waits; `AIOptimal.tick` still plays a normal game if no read comes by 3:00
  (`DECIDE_BY`) or 45 s after a first UNKNOWN.
- **After the read** (`scripts/ai_optimal.gd`):
  - AGGRESSIVE: Balanced, with the Mill and Musketeers first (`_bo_defence`); measured in `tools/test_ai_optimal.gd`
    case 6: the Mill is laid the same second as the read, no Horseman rush.
  - GREEDY, the Brood (read before 2:45, `BREEDER_BY`): **the Horse Breeder at once, the riders** (the owner's call):
    the Rush played from the common opening, `PLANS["rush"]["bo_opt"]`: the Breeder, Horsemen before labourers but
    the labourers never capped (the hall keeps one coming while the Barracks is busy), the riders out at 9 supply (3
    Horsemen), then the Powder Mill and the second hall right behind the raid (`_bo_after_attack`: the opening goes on
    past the attack step). Read later than 2:45: out-expand it (the Economy plan). Never the Siege push any more.
  - GREEDY, the Clockwork: unchanged (Horseman rush 35% while early, else Balanced's steady waves); the Crown: the Timing
    attack, never Horsemen (test case 4).
  - NORMAL / DEFENSIVE: unchanged (by the matchup's weights; Economy then a siege). Every one of these builds has the
    Powder Mill as its next step after the common opening.
  - The Foundry before the second Barracks: untouched (every plan's milestones keep it).
- **Supply** (`_supply_margin`, used by `_supply_due` for every plan and by the owner plans' `_supply_ahead`): the supply
  the halls, Barracks, Horse Breeders (new: 3 supply a 22 s Horseman) and Foundries make during a Cottage's build
  (`SUPPLY_LEAD` 26 s), plus two; in the opening never less than the old margin. 0 s blocked before 6:00 in every run
  after (16-56 s before).
- **The Rush trains no dry Musketeer while its Horse Breeder goes up** (`_breeder_first`): the riders' plan spent 60 gold
  on a Musketeer with no powder at 1:54.
- **A study switch** for the measures: `-- greedybrood:economy` (or `siege`) makes OPTIMAL answer a greedy Brood with
  that plan instead of the riders (`AIOptimal.GREEDY_BROOD_TRY`).
- **The AI STORY**: the pick line says why ("P1 Crown reads the enemy as GREEDY (a second base and little army) and picks
  Rush: punish the greed: the Horse Breeder at once, the riders before its army."); the opening's line names the
  Barracks; a new line for the riders' hall ("P1 Crown's riders are out: it lays its second base right behind the raid."). Texts in
  `tools/i18n/55_ai_optimal.txt` (pt/es).

## Numbers, before and after

Tool: `tools/measure_crown_opening.gd` (one game, headless; the Crown OPTIMAL is P1, Hard v Hard; one JSON line: labourers
each minute, the second hall laid/done, the buildings, the first Horseman and the riders' ride-out, what the Horsemen
killed, seconds at the supply cap, OPTIMAL's picks, the result). Maps: Saltmarsh Isles (the owner's), Dune Sea, Greenhold,
Red Coast, Ashford Crossing. "Before" is main at 0.33.0. The riders were measured with the opening as it is now and
the three answers to a greedy Brood side by side: the Siege push (before), the Horse Breeder at the read (the riders,
`greedybrood:rush` while it was being measured), out-expanding (`greedybrood:economy`).

### The opening (seed 1, to 10:00; averages, the second hall's spread in brackets)

Ashford Crossing reads the Brood NORMAL in every run and picks the one-hall Timing attack (hall at 7:10-8:30): it
stretches the Brood rows' averages, the GREEDY reads' halls are given apart.

| Crown OPTIMAL v | | labourers at 1-6 min | 2nd hall laid | supply blocked before 6:00 | income at 10:00 (Crown v foe) |
|---|---|---|---|---|---|
| Brood OPTIMAL (6) | before (Siege push) | 8, 9, 12, 15, 16, 17.8 | 4:20-4:37 (GREEDY reads) | 25 s | 5,700 v 14,266 |
| Brood OPTIMAL (5) | after, the riders | 8, 9.2, 11, 12.4, 15.6, 18.8 | 4:15-4:20 | 0 s | 5,700 v 11,990 |
| Brood OPTIMAL (5) | after, out-expanding | 8, 10, 14, 17.6, 23, 28.6 | 2:21-2:25 | 0 s | 7,600 v 14,667 |
| Brood Economy (5) | before (Siege push) | 8, 9, 12.2, 15, 16, 18.6 | 4:18-4:37 | 27 s | 7,144 v 14,611 |
| Brood Economy (5) | after, the riders | 8, 9.2, 11.6, 13.8, 15.2, 17.6 | 4:15-4:39 | 0 s | 7,068 v 12,785 |
| Brood Economy (5) | after, out-expanding | 8, 10, 14.2, 18.4, 25.2, 29.4 | 2:22-2:25 | 0 s | 9,196 v 14,768 |
| Clockwork OPTIMAL (5) | before | 8, 12, 14.6, 19.2, 22, 28.6 | 1:35-2:16 | 0 s | 8,512 v 12,233 |
| Clockwork OPTIMAL (5) | after (GREEDY read: Balanced, unchanged) | 8, 9.8, 13.8, 16, 22, 24.4 | 2:21-2:30 | 0 s | 8,284 v 11,820 |
| Crown OPTIMAL mirror (5) | before | 8, 12.2, 15.8, 17.6, 19.6, 23.4 | 2:16-5:19 | 1 s | 8,664 v 9,196 |
| Crown OPTIMAL mirror (5) | after (UNKNOWN: Economy) | 8, 9, 13.2, 15.6, 21.8, 25.2 | 2:22-2:35 | 0 s | 10,108 v 10,640 |

(The riders' rows are the first riders' build, without the Powder Mill behind the raid; with it, below, the labourers
are 8, 9, 10, 11.5, 14.4, 16 and the hall 4:17-4:42.)

### The riders against a greedy Brood (to 15:00, every GREEDY read)

- The Horse Breeder laid at the read (1:39-1:41 on a read at ~1:36), the first Horseman at **2:30-2:48**, the riders out
  (3 Horsemen) at **3:34-4:04**. The Brood's first Raptors hatched at **3:14-3:22 in every game**: the riders always come
  after them, by 12-50 s.
- They kill 2-19 by 6:00 (grubs mostly; about 6 on average) and 12-50 by the end; the Brood's workers at 5:00 are
  17-36 (mostly 21-27) against 33-42 with the other two answers, its income at 10:00 about 2,500 lower.
- The cost: Horsemen before labourers, the Crown's labourers stand at 10-12 from 2:00 to 4:00 and the second hall still
  comes at 4:17-4:42 (the same as the Siege push; out-expanding has it at 2:22). The first version had the Powder Mill
  after the hall (5:17-5:51): its army stood at 12 supply for want of powder and the Brood took both halls at 8:20
  (Greenhold); the Mill now goes down as the riders leave (3:53-4:08).

The outcome, every game where the Brood was read GREEDY, to 15:00 (seeds 1-3 against the Brood's OPTIMAL, seed 1 against
its Economy):

| answer to a greedy Brood | games | held to 15:00 | lost at | Crown's income at the end |
|---|---|---|---|---|
| the Siege push (before) | 8 | **0** | 10:49-14:19 | 4,560-9,880 |
| out-expanding (Economy, hall at 2:22) | 16 | **0** | 10:28-14:42 | 6,840-13,560 |
| **the Horse Breeder, the riders (the new default)** | 16 | **6** | 8:59-14:19 | 3,800-13,180 |

The Crown's OPTIMAL against the Brood's still loses most games by 15:00 whatever its opening (the Brood earns about
twice as much: the mid-game, the army's post and the cannons are crown-hold's job; the Brood's FOOD_BONUS is the owner's
open question). Of the three answers only the riders held games: 4 of 12 against OPTIMAL, 2 of 4 against Economy. They
also lost the three earliest (8:59-10:06: seed 1 on Dune Sea, Greenhold and Red Coast): a raid that fails leaves the
Crown thinner for a while than the other two answers do. Riskier, but the only one that held.

## Tests

- `tools/test_ai_optimal.gd` (updated): case 4 now checks that a greedy Brood read by 2:30 gets the riders (300 of 300)
  and one read later is out-expanded, never the Siege push; new case 5 (Crown OPTIMAL v the Brood's own Economy computer,
  Greenhold): the Barracks (45 s) before the second Farm (57 s), no Powder Mill before the read, 9+ labourers at 1:30,
  the pick never "waited with the gold in the bank", GREEDY -> Rush, the Horse Breeder at once, the riders out, the
  Powder Mill and the second hall behind the raid; new case 6 (an AGGRESSIVE read): the Powder Mill at once, no
  Horseman rush.
- `tools/test_ai_wall_vs_rush.gd` (the owner's 6-pool Brood rush, Ashford Crossing): `crown:optimal optlean:off` now
  checks the common opening (the Barracks by 75 s, the Mill after the rush read by 110 s). Before this job OPTIMAL failed
  7 checks there (it leans to the Horseman rush on that seed: no gate, the first Musketeer at 2:54; with the new opening
  but waiting for powder, at 3:13). Now ALL PASS: the wall at 37 s, the Barracks at 46 s, the Mill at 102 s (the read at ~1:20), Musketeers at
  1:57, 2:12, 2:27 (Balanced: 2:08, 2:23, 2:38), 1 labourer lost.
- Results (0.33.1): test_ai_optimal ALL PASS, test_ai_scout ALL PASS, test_ai_wall_vs_rush ALL PASS (Balanced, and
  OPTIMAL with optlean:off), test_crown_stall PASS, test_crown_ammo 0 failures, test_i18n PASS, test_files 0 failures.

Two more changes the tests asked for:
- **Gold-only Musketeers while a rush is held before the first Mill grinds** (`AICrownAmmo._hold_dry`; the owner's
  ammunition rule makes it legal, the computer used to wait for a full load's powder): they come out with the bayonet
  and refill later (the computer's refill errands, crown-ammo).
- **The supply lead is off while a rush is held** (`_supply_margin` returns the old opening margin when `_def_on`): with
  the lead, Balanced's third Musketeer against the 6-pool never came by 2:40 (a Cottage's gold went first).
- `optlean:off` on the command line turns OPTIMAL's lean to the Horseman rush before scouting off (tests, studies).

## Claude's choices for the owner

1. **The riders are the default against a greedy Brood although they come after its Raptors.** The brief said: if the
   measured riders still arrive after the Raptors in most games, fall back to out-expanding. They do arrive after them,
   in every game (3:34-4:04 against 3:14-3:22), and the first two runs (to 10:00) pointed to out-expanding (no losses by
   10:00, ~2,000 more earned). Played to 15:00 the picture turned: out-expanding lost all 16 games (10:28-14:42), the
   Siege push all 8, the riders held 6 of 16. The raid works as a punish even late (the Brood's workers at 5:00: 21-27
   instead of 33-42), so I kept your call. Out-expanding is one switch away (`-- greedybrood:economy`; to make it the
   default: `_punish` in `scripts/ai_optimal.gd`). Ways to make the riders arrive before the Raptors, not tried: ride
   out with the first two Horsemen (~3:10), or a scout that reads sooner than 1:36.
2. **The second hall behind the raid is not sooner** than before (4:17-4:42, Horsemen first take the gold); the hall
   at 2:22 is the out-expanding answer's. If you want both, the hall before the riders costs the raid about a minute.
3. **The Barracks is in the common opening in every matchup**, as the decision says ("you don't know if the enemy is
   rushing"). Against the Clockwork and the Crown, where the opening had no Barracks before the read, it costs about
   two labourers at 2:00 and the second hall comes at 2:21-2:35 instead of 1:35-2:16 (the Crown mirror's hall is sooner
   than before on average, 2:30 against 3:55: the old pick step was dropped there). To keep it only against the Brood:
   a `bo_brood` in `PLANS["optimal"]`.
4. **The Mill after the read**: against a rush at once (Balanced + `_bo_defence`); the riders lay it as they leave
   (3:53-4:08); the Economy plan behind its hall (15 labourers); Siege push, Timing, Dragoon raids, Balloon harass have
   it as their next step.
5. The 45 s stall rule no longer touches the pick (it spends nothing while it waits).

## Open questions

- The Crown v the Brood after 10:00: every answer loses most games to the Brood's OPTIMAL by 15:00 (the Brood earns
  about twice as much). The mid-game army is crown-hold's job; the Brood's FOOD_BONUS (1.5 -> 0.8) waits on the owner.
- Clockwork OPTIMAL on Greenhold (seed 1): the Crown lost both halls by 9:00 in the "after" run (the game did not end);
  the "before" game lost 23 units by 9:00 with ~400 of army too. One game; the army's job, not the opening's.
- In the Crown mirror the scout never reads (the walled ramp keeps it out): it picks at the UNKNOWN timeout.
- Only seed 1 was run against the Clockwork, the Crown and the Brood's Economy; the riders' outcome table has 16 games.
