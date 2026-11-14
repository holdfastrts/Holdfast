# Crown v Clockwork: the answer to a GREEDY Clockwork (crown-v-cw-plan-study, 2026-11-13/14)

A STUDY, no game code changed (branch `crown-v-cw-plan-study`, on 0.35.5). The owner's question (2026-11-13 08:03, after
docs/econ-coach-crown.md section 6 item 2): when the Crown's OPTIMAL plan reads a greedy Clockwork, should it answer with
the Timing attack (today) or with the Economy race more often? "This decision should be based on data."

## How it was measured

- Hard OPTIMAL Crown v Hard OPTIMAL Clockwork, the qa-matches design: the 19 two-player maps x 2 rounds (round 1 swaps
  the sides), 38 games, 15:00, the base rounds' tags and seeds (`tools/study/qa_matches.py --only crcw38`, new; `crcw19r0`
  / `crcw19r1` for one round).
- Three runs of the same 38: **default** (today: `AIOptimal.GREEDY_CLOCK` = Timing 3, Economy 1, Balloon 1),
  **economy** (`-- greedyclock:economy`), **balanced** (`-- greedyclock:balanced`). The early riders' roll
  (`RIDERS_V_CLOCK` 15%, checked before the switch) stays in all three: 3 games of each run went to the riders.
- `tools/study/crown_v_cw_plan_study.sh` runs it all (round 0 of the three runs first); `tools/study/crown_v_cw_plan_report.py
  docs/crown_v_cw_plan_study/data [round]` makes the tables; the full output is docs/crown_v_cw_plan_study/report.md (with
  every game). Data: docs/crown_v_cw_plan_study/data/<run>/<game>/ (result.json, story.txt). No script errors, no failed game.
- "Won or led" = won, or a draw ahead at the end by income earned + 2 x army value by 10% or more. Noise: a won-or-led count
  moves about +-3 between two runs of the same 38 (docs/winrate_2026_11_12.md); the W-D-L columns about as much.
- Two filmed games of the Economy race (Greenhold r0, Highmoor r0; `tools/shot_ai_match.gd coach:1 greedyclock:economy`),
  kept in docs/crown_v_cw_plan_study/films/ (coach notes, logs and 4 pictures each).

## First finding: "a greedy Clockwork" is every Clockwork

The greedy read fired in **all 114 games**, at 1:11-1:42 (median 1:28): "its base seen at 1:2x: no army, no production
building; 2 economy buildings, 7-8 workers" (AIScout's absence rule, GREEDY_ABSENT_FROM 0:55). That is the Clockwork's
normal opening: by 6:30 the same scout reads it NORMAL. So `GREEDY_CLOCK` is not an answer to greed: it is the Crown's whole
plan against the Clockwork, in every game.

## The table (38 games each, the Crown's view)

| | default (Timing 23, Balloon 7, Economy 5, riders 3) | Economy race (35 + riders 3) | Balanced (35 + riders 3) |
|---|---|---|---|
| W-D-L | 0-28-10 | 0-24-14 | 0-25-13 |
| won or led / lost or trailed | 0 / 37 | 0 / 38 | 0 / 38 |
| decided games, mean length; mean end | 10, 13:23; 14:34 | 14, 13:11; 14:20 | 13, 13:02; 14:19 |
| Crown income against its bench, 5:00 / 8:00 / 10:00 / 15:00 | 0.63 / 0.59 / 0.58 / 0.52 | **0.66 / 0.67 / 0.70 / 0.65** | 0.64 / 0.59 / 0.63 / 0.54 |
| Crown earned by 10:00 (Clockwork) | 7,700 (14,333) | 9,260 (14,776) | 8,310 (14,960) |
| army 8:00, Crown / Clockwork | **1,200 / 1,306** | 788 / 1,849 | 728 / 1,799 |
| army 10:00 | **987 / 2,353** | 886 / 3,126 | 787 / 3,095 |
| army 12:00 | **857 / 3,793** | 701 / 4,890 | 550 / 5,154 |
| halls standing at 10:00, Crown / Clockwork | 2.3 / 3.6 | 1.7 / 3.6 | 1.7 / 3.7 |
| halls lost, Crown / Clockwork | 72 / **8** | 63 / 0 | 71 / 0 |
| the Crown's first hall lost (games, median time) | 34, 11:20 | 29, 10:10 | 34, 10:32 |
| end score, Crown / Clockwork (income + 2 x army; mean) | 0.35 | 0.35 | 0.28 |
| paired with default (same map, seed, sides): better / same / worse result | - | 3 / 27 / 8 | 5 / 25 / 8 |
| paired: end score higher than default's | - | 21 of 38 | 11 of 38 |
| the Clockwork read the Crown GREEDY | 3 | 21 | 19 |
| the Clockwork's plan at the end | economy 14, springer 9, heavy 8, balanced 7 | economy 17, springer 10, heavy 8, balanced 3 | economy 19, heavy 10, springer 7, balanced 2 |

Inside the default run, by the plan it picked: Timing 23 games 0-18-5, army at 8:00 1,392 against the Clockwork's 975,
6 of the 8 Clockwork halls taken, but income 7,087 at 10:00 and 49 halls lost (2.1 a game); Balloon 7 games 0-5-2; Economy
5 games 0-4-1 (end score 0.44, too few games to read); riders 3 games 0-1-2.

## What the data says

1. **No answer wins or leads a game.** 0 of 114. At the floor the result columns cannot separate the three runs: losses
   10 / 14 / 13 are inside the noise (+-3-4), and every run trails in 37-38 games.
2. **The Economy race does what it says on the economy, and nothing else.** Income +14% at 8:00, +20% at 10:00, +25% at
   15:00 (0.58 -> 0.70 of the bench at 10:00): the biggest Crown economy measured against Hard Clockwork. But its army at
   8:00 is a third lower (788 v 1,200), the Clockwork reads it GREEDY in 21 of 38 games (at ~3:35, "a second base and
   little army") and plays a free game: its army at 8:00 +42% (1,849 v 1,306), no Clockwork hall ever lost, the Crown's first
   hall falls a minute earlier (10:10 v 11:20). The end score is the same as today's (0.35 v 0.35; higher in 21 of 38 paired
   games, a coin toss) and it loses a few more (14 v 10, within the noise).
3. **The Timing attack is the only answer that hurts the Clockwork**: the only run where the Crown's army at 8:00 matches
   the Clockwork's, and 8 Clockwork halls down (0 in the other two runs). It pays for it later: by 10:00 its income is the
   lowest (0.58) and its army falls behind as the Clockwork's economy pays (987 v 2,353).
4. **Balanced is worse than both**: the lowest army at every minute, the lowest end score (0.28; below default's in 27 of
   38 paired games, two-sided binomial p ~ 0.01), no hall taken.
5. **The films** (the Economy race): Greenhold (a draw) - the Crown's army is 0 at 5:06 and 180 at 6:06 ("the army first: 0 of
   army against the 287 it reckons"), 10 Musketeers, 2 Cuirassiers and a cannon at 8:05 against 20 Clock Soldiers, 3
   Springers and a Ballista; at 11:55 a
   single file of 8 Musketeers walks out of the palisade toward a block of ~25 Clock Soldiers and Pendulums while its third
   hall stands half built; army 475 v 3,445 at 12:05. Highmoor (a loss at 14:25): the Crown re-reads AGGRESSIVE at 4:50 and
   goes Balanced; 0 army at 5:04, 12 Musketeers at 8:00 against 1,955 of Clockwork; at 9:17 the Clock Soldiers are through
   its main's ramp gate; by 12:05 1 hall, 19 workers, no army. Both films: the extra gold goes into workers and halls the
   Crown cannot hold, and the army that should hold them comes late and in a line too thin to face the push.

## RECOMMENDATION for the owner (not applied)

- **Keep today's answer** (Timing 3, Economy 1, Balloon 1). Do not make the Economy race more frequent: on these 38 games x
  3 it buys +20% income and pays for it with the Clockwork's army +40% at 8:00 and no harm to the Clockwork at all; the
  results and the end score are no better (within the noise, a few more losses). Balanced is measurably worse.
- **The question behind the question**: the "greedy Clockwork" read is every Clockwork at 1:28, so the plan mix is the
  Crown's whole game plan against the Clockwork, and none of the three gets a single game. What decides these games is after
  8:00: in every run the Crown's army shrinks from 8:00 to 12:00 while the Clockwork's triples. Two possible next jobs (your
  choice): (a) make the read honest against the Clockwork (a "truly greedy" check like the Brood's `_true_greed_brood`, or the
  absence rule later for the Clockwork), so OPTIMAL picks by a real read; (b) a Timing attack that turns into an expansion
  after its hit (the Timing run's 8:00 army with the Economy run's later income), coached and measured like this.

## Files

- docs/crown_v_cw_plan_study.md (this), docs/crown_v_cw_plan_study/report.md (every table and every game),
  docs/crown_v_cw_plan_study/data/{default,economy,balanced}/ (114 games), docs/crown_v_cw_plan_study/films/.
- tools/study/qa_matches.py (`--only crcw38 / crcw19r0 / crcw19r1`), tools/study/crown_v_cw_plan_study.sh,
  tools/study/crown_v_cw_plan_report.py.
