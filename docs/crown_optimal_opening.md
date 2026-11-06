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
  - GREEDY, the Brood: **out-expand it** (the Economy plan: its second hall at 11 labourers, the Mill at 15 behind it,
    the Foundry, then the Breeder). Not the Siege push, and, after measuring it, not the Horseman rush either (below).
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
- **The riders, kept as a study switch**: `PLANS["rush"]["bo_opt"]` is the Rush played from the common opening (the
  Breeder at once, Horsemen first, labourers uncapped, the riders out at 9 supply, then the Powder Mill and the second
  hall right behind the raid: `_bo_after_attack`). OPTIMAL plays it against a greedy Brood only with
  `-- greedybrood:rush` on the command line (`AIOptimal.GREEDY_BROOD_TRY`; `greedybrood:siege` gives the old answer).
- **The AI STORY**: the pick line says why ("reads the enemy as GREEDY (a second base and little army) and picks Economy:
  the riders would come after its Raptors: out-expand it."); the opening's line names the Barracks; a new line for the
  riders' hall ("P1 Crown's riders are out: it lays its second base right behind the raid."). Texts in
  `tools/i18n/55_ai_optimal.txt` (pt/es).

## Numbers, before and after

Tool: `tools/measure_crown_opening.gd` (one game, headless; the Crown OPTIMAL is P1, Hard v Hard; one JSON line: labourers
each minute, the second hall laid/done, the buildings, the first Horseman and the riders' ride-out, what the Horsemen
killed, seconds at the supply cap, OPTIMAL's picks, the result). Seed 1, 10:00 (15:00 where marked); maps Saltmarsh Isles
(the owner's), Dune Sea, Greenhold, Red Coast, Ashford Crossing. "Before" is main at 0.33.0.

Averages (labourers at minutes 1-6; the hall's spread in brackets; Ashford reads the Brood NORMAL, picks the one-hall
Timing attack and expands at 7:30-8:30 in every variant, so it stretches every average):

| Crown OPTIMAL v | variant | labourers 1-6 min | 2nd hall laid | 1st Horseman / riders out | Horsemen's kills by 6:00 | blocked | income at the end (Crown v foe) | result |
|---|---|---|---|---|---|---|---|---|
| Brood OPTIMAL (6) | before (Siege push) | 8, 9, 12, 15, 16, 17.8 | 5:00 (4:20-7:44) | 4:58 / never | 0.7 | 25 s | 5,700 v 14,266 | none lost by 10:00 |
| Brood OPTIMAL (5) | Horse Breeder at the read (`rush`) | 8, 9.2, 10.8, 11.8, 14.8, 15.8 | 5:00 (4:19-7:44) | 3:05 / 3:35 | 3.4 | 0 s | 5,776 v 14,285 (15:00) | **lost 4 of 5**, at 8:59-12:28 |
| Brood OPTIMAL (5) | **out-expand (Economy), the new default** | 8, 10, 14, 17.8, 24, 28.4 | 3:36 (**2:22-2:25** on the GREEDY reads) | 6:43 | 0.8 | 0 s | 7,524 v 18,234 (15:00) | lost 5 of 5, at 10:28-14:32 |
| Brood OPTIMAL (5) | before (Siege push), to 15:00 | 8, 9, 12, 15, 16, 19 | 4:21-4:34 | 4:48 | 1.0 | 21 s | 4,560-6,460 v ~16,000 | lost all, at 10:49-12:13 (see the note) |
| Brood Economy (5) | before (Siege push) | 8, 9, 12.2, 15, 16, 18.6 | 5:05 (4:18-7:37) | 5:02 | 1.4 | 27 s | 7,144 v 14,611 | none lost by 10:00 |
| Brood Economy (5) | Horse Breeder at the read | 8, 9.2, 11, 12.4, 14.8, 16.4 | 5:02 (4:17-7:58) | 2:55 / 3:35 | 7.8 | 0 s | 8,284 v 21,219 (15:00) | lost 3 of 5, at 12:05-14:06 |
| Brood Economy (5) | out-expand (Economy) | 8, 10, 14.2, 18.4, 25.2, 29.4 | 3:18 (**2:22-2:25** on the GREEDY reads) | 6:37 | 0.6 | 0 s | 9,196 v 14,768 | none lost by 10:00 |
| Clockwork OPTIMAL (5) | before | 8, 12, 14.6, 19.2, 22, 28.6 | 1:55 (1:35-2:16) | 6:31 | 0 | 0 s | 8,512 v 12,233 | none lost by 10:00 |
| Clockwork OPTIMAL (5) | after (the Barracks in the opening) | 8, 9.8, 13.8, 16, 22, 24.4 | 2:26 (2:21-2:30) | 6:07 | 0.2 | 0 s | 8,284 v 11,820 | none ended by 10:00 (Greenhold: both halls lost by 9:00) |
| Crown OPTIMAL mirror (5) | before | 8, 12.2, 15.8, 17.6, 19.6, 23.4 | 3:55 (2:16-5:19) | 3:50 | 3.2 | 1 s | 8,664 v 9,196 | none ended |
| Crown OPTIMAL mirror (5) | after | 8, 9, 13.2, 15.6, 21.8, 25.2 | 2:30 (2:22-2:35) | 7:03 | 0 | 0 s | 10,108 v 10,640 | none ended |

The riders against the Brood, game by game: the Horse Breeder laid at the read (1:39-1:41), the first Horseman at
2:31-2:55, the riders out (3 Horsemen) at **3:34-3:58**; the Brood's first Raptors hatched at **3:14-3:22 in all ten games**.
So the riders arrived after the Raptors every time; they killed 2-19 by 6:00 (grubs mostly) and cut the Brood's
workers at 5:00 from 34-42 to 27-31, but the Crown's labourers stood at 10-12 from 2:00 to 4:00 (Horsemen first), its
Mill came at 3:53 (5:17-5:51 before the riders' plan had it behind the raid: its army stood at 12 supply with no powder
till 7:00 at Greenhold) and it lost 5 of the 7 games that reached 9:00 against the Brood's OPTIMAL and Economy. The
Economy plan's hall at 2:22 lost none of its ten games by 10:00 and earned 1,500-2,400 more by then.

**The note:** the Crown's OPTIMAL loses to the Brood's OPTIMAL by 10:30-12:30 whatever its opening (before, riders,
out-expand: the Brood earns about twice as much). That is the mid-game (the army's post, the cannons, crown-hold's job,
and the Brood's FOOD_BONUS question the owner has not decided); the opening now keeps up: the second hall about two
minutes sooner, twice the labourers at 5:00, no supply blocks.

## Tests

- `tools/test_ai_optimal.gd` (updated): case 4 now checks that a greedy Brood is out-expanded (Economy, 300 of 300) and
  never the Siege push or a Horseman rush on the read; new case 5 (Crown OPTIMAL v the Brood's own Economy computer,
  Greenhold): the Barracks (45 s) before the second Farm (57 s), no Powder Mill before the read, 9+ labourers at 1:30,
  the pick never "waited with the gold in the bank", GREEDY -> Economy, the second hall laid soon after; new case 6 (an
  AGGRESSIVE read): the Powder Mill at once, no Horseman rush.
- Also run: test_files, test_i18n, test_ai_scout, test_crown_stall, test_ai_wall_vs_rush (Balanced and OPTIMAL),
  test_crown_ammo (results at the end of this file).

## Claude's choices for the owner

1. **The riders against a greedy Brood are not the default.** You asked for the Horse Breeder to punish the greed, and
   for the out-expansion if the riders measured still came after the Raptors. They did, in every game, by 15-40 s at
   best, and the Crown lost more and sooner with them; so OPTIMAL out-expands a greedy Brood. The riders' build from the
   common opening is kept (`-- greedybrood:rush`) if you want to watch it. What could make them arrive in time: riding
   out with the first Horseman alone (~2:35, at the Brood's grubs by ~3:00), or a read that comes sooner than 1:36.
2. **The Barracks is in the common opening in every matchup**, as the decision says ("you don't know if the enemy is
   rushing"). Against the Clockwork and the Crown, where the opening had no Barracks before the read, it costs about two
   labourers at 2:00 and the second hall comes at 2:21-2:35 instead of 1:35-2:16. If you'd rather keep the Barracks only
   against the Brood, it is one line (`bo_brood` in `PLANS["optimal"]`).
3. The Mill, after the read: Balanced against a rush (at once), and in the Economy plan behind the hall (at 15
   labourers); Siege push, Timing, Dragoon raids, Balloon harass have it as their next step.
4. The 45 s stall rule no longer touches the pick (it is not stalled: it spends nothing).

## Open questions

- The Crown v the Brood after 10:00 (all variants lose to the Brood's OPTIMAL by 10:30-12:30; the Brood earns about 2x).
- Clockwork OPTIMAL on Greenhold: the Crown lost both halls by 9:00 in the "after" run (the game did not end); the baseline
  game also lost 23 units by 9:00 with ~400 of army. One game, the army's job (crown-hold), not the opening's.
- In the Crown mirror the scout never reads (the walled ramp keeps it out): it picks Economy at the UNKNOWN timeout.
