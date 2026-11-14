# No Farm/Press limit with the ground system (job ground-nocap-study, 2026-11-14; 0.36.1)

The owner's question (2026-11-14 02:24-02:25), one of the open ground-system choices in docs/ground_system.md ("keep the
local limit or drop it"): **with the GROUND SYSTEM on, what happens if a hall no longer limits its Farms / Cog Presses?**
Today a Town Hall allows 2 Farms (+1 Powder Mill), a Clocktower 2 Cog Presses (+1 Mainspring). Dropped, the ground is the
only limit: more drinkers empty the same district faster, overlapping circles share it.

**Short answer:** it does **not** push toward one-base turtling and it does **not** make the leader snowball harder. But
it is a large **Clockwork buff** (+27% income by 8:00, +37% by 12:00 in real games; the Crown computer gains almost
nothing), so it breaks the economy parity the owner asked for. **Recommendation: keep the limit (the local one) for now.**
Details and the alternatives at the end.

## What was built (all OFF by default; only meaningful with the ground system on)

- **The switch**: Settings > EXPERIMENTAL > **NO FARM/PRESS LIMIT (with the ground system)** (Settings.ground_nocap), kept
  in the match's setup as cfg `ground_nocap` (Defs.ground_nocap = ground on AND this), so a continued match, an online
  guest and a replay agree. Study switch: `groundcap:off` (tools/qa_match.gd, tools/shot_ai_match.gd) /
  `groundcap=off` (tools/econ_bench.gd, tools/econ_ai_alone.gd).
- **The player**: no limit at all on Farms (Crown) and Cog Presses (Clockwork): neither the empire count nor the district
  rule (Game.econ_capped). The build card reads "FARM 5" instead of "FARM 5/6" and its line says "5, no limit: the
  ground decides". The placing view is unchanged: every circle still shows its share ("49% GOOD SPOT", "HALF SPENT",
  "POOR SPOT", the BEST SPOT arrow, "ground running low: expand to a new hall"), so a player sees each extra one's value
  fall. The **Powder Mill and the Mainspring stay 1 a hall** (they drink the hall's own reserve, not the map).
- **The Brood is unchanged: it has no limit of this kind to drop.** Its FACTIONS "econ" is empty; Rootmaws are limited
  only by their ground circles (which may not overlap, PIT_CLAIM). The "2-3 Rootmaws" are the Brood computer's plans
  (ai_brood_new.gd "maws"), not a rule.
- **The computers** (Crown and Clockwork, behind the switch; Game.nocap_allow / _nocap_limit, Defs.LAND):
  - a district gets **one more** Farm / Press than it feeds now only while (a) it has fewer than `nocap_max` (2) beyond
    the usual 2, and (b) the ground its district still holds, **shared out among them all**, pays `nocap_pay` (3) times
    the new one's price plus its crew's (a Farm 100 + 8 labourers = 500: one more while the district holds 1,500 a
    drinker; a fresh 9,000 district takes a 3rd at once, a 4th only above 6,000);
  - and only on a spot whose circle still holds `extra_min` (35%) of a fresh one (the "running low" line of the placing
    view);
  - the worker caps grow by the extra crews (AI.nocap_hands: the Crown's labourer cap, AICrown.owner_lab_cap, the
    Clockwork's Winder cap);
  - **expansion is untouched**: the computers' "economy full" and dry-ground rules read the same econ_limit, so a
    district that is fed well enough (or running low) still sends them to a new hall. Measured below: they expand as
    much or more.
  - Everything is gated on Defs.ground_nocap; with the switch off the AI code paths are the same as before.
- Tests: **tools/test_ground_nocap.gd** (off: no third Farm by a hall; on: the player lays a 3rd and 4th, still one
  Powder Mill; a computer gets a 3rd by a fresh hall and none once the district's ground left would not pay for it);
  tools/test_ground_system.gd, test_settings_tabs.gd, test_qa_settings_persist.gd pass with the new row.

## Measured

Raw data: docs/ground_nocap_data/ (bench/ the bench JSONs, games.tar.gz every game's result.json, games_report.md and
bench_report.md the full tables, the two films' coach and story lines). Tools: tools/study/ground_nocap.py (the games and
their report), tools/study/ground_nocap_bench.py (the benches).

### 1. The economy bench (one faction alone, ground ON in both arms)

**The scripted ideal build** (tools/econ_bench.gd, expansions at 4:00 and 8:00, `drink=N` Farms / Presses a hall),
income earned by m:00, as a share of N = 2 (the limit kept):

| | N | 5:00 | 8:00 | 10:00 | 12:00 | 15:00 | 20:00 | districts dry at |
|---|---|---|---|---|---|---|---|---|
| Crown, Greenhold | 2 | 4,359 | 9,620 | 14,154 | 19,269 | 24,381 | 28,538 | 10:21, 14:30, 19:06 |
| | 3 | 1.13 | 1.08 | 1.11 | 1.05 | 1.06 | **1.00** | 9:13, 13:53, 17:07 |
| | 4 | 1.05 | 1.21 | 1.17 | 1.12 | 1.12 | **0.99** | 7:24, 12:58, 13:47 |
| Crown, Hollowfen | 2 | 4,360 | 9,572 | 14,106 | 18,789 | 25,166 | 29,027 | 10:20, 18:36 |
| | 3 | 1.13 | 1.07 | 1.10 | 1.15 | 1.08 | **1.00** | 9:50, 15:50 |
| | 4 | 1.05 | 1.19 | 1.19 | 1.21 | 1.11 | **0.99** | 7:55, 13:23 |
| Clockwork, Greenhold | 2 | 4,629 | 10,457 | 15,267 | 20,943 | 26,822 | 28,137 | |
| | 3 or 4 | 0.95 | 1.01 | 1.03 | 1.05 | 1.00 | 1.02 | |
| Clockwork, Hollowfen | 2 | 4,630 | 10,437 | 14,647 | 19,907 | 24,654 | 29,396 | |
| | 3 or 4 | 0.95 | 1.03 | 1.06 | 1.09 | 1.15 | 0.99 | |

What it shows: the ground is a real limit. More drinkers per hall **do not make more money in total** (the same by
20:00, the districts hold what they hold); they make it **sooner** (+5-21% in the middle game) and the district **runs dry
1-3 minutes earlier** (4 Farms a hall: the main is dry at 7:24 instead of 10:21). The scripted Clockwork could seldom fit a
4th press (the meshing ring leaves little room by a Clocktower), so 3 and 4 came out the same.

**The computer alone** (tools/econ_ai_alone.gd, Hard OPTIMAL, nobody in its way), income earned, dropped as a share of kept:

| | 5:00 | 8:00 | 10:00 | 12:00 | 15:00 | halls up (kept / dropped) |
|---|---|---|---|---|---|---|
| Crown, Greenhold | 1.00 | 0.99 | 1.02 | 1.05 | 1.11 | 5 by 12:39 / 6 by 14:30 |
| Crown, Hollowfen | 1.00 | 1.00 | 1.05 | 1.13 | 1.22 | 5 by 13:42 / 6 by 14:51 |
| Clockwork, Greenhold | 1.05 | 1.17 | 1.16 | 1.18 | 1.16 | 4th hall 9:49 / **8:10** |
| Clockwork, Hollowfen | 1.08 | 1.19 | 1.19 | 1.16 | 1.17 | 4th hall 9:45 / **7:59** |

Alone, both computers use it sensibly and **expand sooner, not later** (a district fed by 3-4 runs dry sooner and the
dry-ground rules send them out). The Clockwork takes it from the first minutes (+17-19% by 8:00); the Crown only late
(it reaches its posts' saturation late; from 12:00 +5-22%).

### 2. Real games (Hard OPTIMAL v Hard OPTIMAL to 15:00, ground ON in both arms)

60 games an arm, paired (the same map, seed and sides): 6 maps (Greenhold, Frostfang, Hollowfen, Dune Sea, Cinder
Steps, Ashford Crossing) x 5 pairings x 2 rounds (the sides swapped). Results from the first-named faction's view:

| pairing | kept W-D-L | dropped W-D-L | P1 / P2 income 8:00, kept / dropped | 12:00 | decided (mean end) kept / dropped |
|---|---|---|---|---|---|
| Crown v Clockwork | 0-7-5 | **0-2-10** | 0.56 / 0.50 | 0.40 / **0.29** | 5 (13:26) / 10 (13:21) |
| Crown v Brood | 0-2-10 | 0-5-7 | 0.79 / 0.81 | 0.73 / 0.76 | 10 (12:56) / 7 (11:57) |
| Brood v Clockwork | 2-5-5 | 1-6-5 | 0.72 / 0.62 | 0.77 / 0.76 | 7 (13:16) / 6 (13:22) |
| Crown mirror | 0-11-1 | 0-11-1 | 0.98 / 0.93 | 0.89 / 0.90 | 1 / 1 |
| Clockwork mirror | 1-8-3 | 0-11-1 | 1.00 / 0.99 | 0.88 / 1.02 | 4 (12:59) / 1 (14:10) |

Per faction, every side it played (medians unless "mean"):

| | Crown kept | Crown dropped | Clockwork kept | Clockwork dropped | Brood kept | Brood dropped |
|---|---|---|---|---|---|---|
| income earned by 8:00 | 5,320 | 5,320 (1.00) | 8,830 | 11,178 (**1.27**) | 5,781 | 6,107 (1.06) |
| income earned by 12:00 | 9,004 | 9,788 (1.09) | 16,684 | 22,798 (**1.37**) | 12,539 | 13,161 (1.05) |
| income earned by 15:00 | 11,091 | 12,594 (1.14) | 20,798 | 26,628 (1.28) | 16,048 | 16,294 (1.02) |
| income in the 8th minute | 1,056 | 1,140 | 1,674 | 2,683 (**1.60**) | | |
| army value 8:00 / 12:00 | 878 / 1,202 | 870 / 835 | 1,302 / 3,308 | 1,320 / 3,745 | 838 / 1,480 | 772 / 2,002 |
| halls at 10:00 / 15:00 (mean) | 2.21 / 2.02 | 2.17 / 2.04 | 2.88 / 3.46 | **3.69 / 4.35** | | |
| most halls held (mean) | 2.98 | 2.88 | 4.19 | **5.02** | 4 | 4 |
| Farms / Presses live a hall 8:00 (mean) | 1.76 | 1.86 | 1.80 | 2.51 | | |
| most in one district (mean, spent ones too) | 2.04 | 2.56 | 2.38 | 4.23 | | |
| sides that ever had 3+ in one district | 2% | 50% | 25%* | 100% | | |
| army within 24 tiles of its halls from 5:00 (mean share: the TURTLE measure) | 0.68 | 0.70 | 0.57 | 0.61 | 0.60 | 0.60 |
| halls lost (mean) | 1.33 | 1.17 | 1.17 | 1.04 | | |

(*with the limit kept a district can still count 3 when one is spent, which no longer counts against the limit.)

**Parity** (median income each faction earned, as a share of the Crown's):

| | kept 8:00 | dropped 8:00 | kept 12:00 | dropped 12:00 |
|---|---|---|---|---|
| Clockwork | 1.66 | **2.10** | 1.85 | **2.33** |
| Brood | 1.09 | 1.15 | 1.39 | 1.34 |

(The computers' parity was already off in games, the Crown computer's known weakness, docs/winrate_2026_11_12.md;
dropping the limit widens the gap to the Clockwork a lot more.)

**Snowball check** (all games): the side ahead at 8:00 held 57% of the income by 8:00 and 65% of the income in the 10th to
12th minutes with the limit kept, 58% and 63% dropped; it won 23 of 27 decided games kept, 24 of 25 dropped. **No more
snowball than today.**

### 3. Two filmed games, the limit dropped (tools/shot_ai_match.gd, coach:1 every:30)

Pictures: docs/shots/ground_nocap/. Coach and story lines: docs/ground_nocap_data/film_*.

**Crown v Clockwork, Greenhold, seed 1101** (P2 Clockwork won at 13:02). Coach's notes:
- 6:05: the Clockwork's main has **three** Cog Presses, each with 5 of 5 Winders, meshed round the Clocktower
  (crcw_clockwork_main_0605.jpg). Its income by 6:20 is 6,717 to the Crown's 3,800; 32 Winders against 19 labourers.
- The Crown's main at 6:05 (crcw_crown_main_0605.jpg) has its 2 Farms at 15% and 23% of their ground: the computer
  rightly builds no third one there (the district would not pay for it), it expands at 7:23 ("its best base has only
  45% left"). The Crown's problem is not the limit: it sits on 19 labourers for minutes (the army-first holds), so it
  never had a third Farm's crew to feed.
- The Clockwork expanded at 6:09, 7:23 and 10:43, each "while its base is still rich": dropping the limit did not keep it
  at home. By 10:25 it had 4 halls, 54 Winders and a 2,770 army; by 12:25, 5 halls and 5,070 (50 Clock Soldiers) against
  the Crown's empty base.
- Fights: the Crown's one good trade (8:24, killed 2,475 for 510) did not matter; the Clockwork rebuilt from an income
  three times the Crown's.

**Clockwork mirror, Frostfang, seed 1105** (P1 won in all but name: P2 had no hall left by 14:55, the clock ran out).
- Both open for the economy and use 3-4 presses a main; P1's main at 8:04 (cwcw_p1_main_0804.jpg): a ring of presses,
  every one 5 of 5 or 8 of 8 Winders.
- Both expanded at 4:46-4:51 and again at 7:09-7:16 (both "while the base is still rich"); 4 halls each by 8:23. The
  game turned on one won fight (P1's push at 7:33, 18 units, "clearly ahead" at 8:01), not on the economy rule: by 10:24
  P1 had 4,650 army to P2's broken one, and 6 halls by 14:24.
- Nothing turtled: the armies left home as soon as they had a block of 10.

## What changed in how games are played

1. **The Clockwork plays a much richer early game.** 3-4 presses by its main by 5:00-6:00 (every Clockwork side built 3+
   in a district), 60% more income in the 8th minute, a 4th hall about a minute and a half sooner. Its army is the same
   size at 8:00 and larger by 12:00.
2. **The Crown computer barely changes.** It rarely saturates even 2 Farms in a real game (its labourer holds while it
   builds an army), so half its sides never built a third Farm and its income moved only late (+9% by 12:00). In the
   bench and alone, where nothing holds its labourers back, it gains as much as the Clockwork later on.
3. **Bases run dry sooner and everyone expands as much or more.** No one-base turtling: the Clockwork holds more halls
   (5.0 against 4.2), the Crown the same, and the army stays at home the same share of the time (the turtle measure moves
   by 0.02-0.04). The fixed district already does what the limit did: a hall ringed with drinkers is empty in 7-8
   minutes and pushes its owner out.
4. **Results**: the Crown v Clockwork matchup gets one-sided (the Clockwork wins 10 of 12, was 5); the Clockwork mirror
   ends in draws more (both sides rich, armies maxed); Crown v Brood slightly better for the Crown (7 losses, was 10:
   noise-sized, 12 games).
5. **No new snowball**: a lead at 8:00 grows and wins as often as before.

## Recommendation (for the owner; not applied: the switch stays OFF by default)

**Keep the limit (the local district limit made by the ground system) for now.** In plain words:

- Dropping it is **fine for the design rules** you care about most: it does not reward sitting on one base (the ground
  runs out and forces expansion even sooner), and it does not let a leader run away more than today. Base building gets
  a real choice (more Farms now and an earlier move, or fewer and a longer-lived hall), which section 3 of the design
  principles likes.
- But it is **a big Clockwork buff and a small Crown one**, the opposite of what you asked for on 2026-11-12 ("all
  economies about equal per minute, by nerfing the Clockwork and Brood"): +27-37% Clockwork income in real games against
  +0-9% for the Crown computer. The Cog Press pays per Winder and the Clockwork's Winder cap was the only thing holding
  it, so more presses = more Winders at once; the Crown's Farm is held back by its labourer count first.
- If you like the idea of "the ground is the only limit" (it is simpler to explain and the placing view already teaches
  it), drop it **together with** one of these, then measure again:
  1. a tighter brass district (Defs.LAND "district_brass" 9 -> 7-8 tiles) so a Clocktower's extra presses drain it in
     6-7 minutes and the gain becomes timing, not income; or
  2. a soft cap of 3 a hall instead of none (one extra Farm / Press a hall: most of the placement choice, half the
     Clockwork's gain); or
  3. wait until the Crown computer reaches its economy in games (econ-coach / cinder-crown-ai jobs), then re-run this
     study (`python3 tools/study/ground_nocap.py run OUT DATA`): the real question is the Clockwork's gain against the
     Crown's when both computers fill their posts.
- The Brood needs nothing: it never had this limit.

## How to run it again

- Tests: `godot --headless --fixed-fps 30 --script res://tools/test_ground_nocap.gd`.
- Bench: `tools/econ_bench.gd -- crown ground=1 groundcap=off drink=3 out=...`; the computer alone:
  `tools/econ_ai_alone.gd -- clockwork minutes=15 ground=1 groundcap=off out=...`; tables:
  `python3 tools/study/ground_nocap_bench.py DIR`.
- Games: `NOCAP_ROOT=<a copy of the project> python3 tools/study/ground_nocap.py run OUT DATA --jobs 2 [--maps ...]
  [--pairs crcw,...]` (both arms, map by map), then `python3 tools/study/ground_nocap.py report DATA`. 120 games took
  about 4 hours on 2 cores.
- Films: `xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script
  res://tools/shot_ai_match.gd -- a:crown b:clockwork pa:optimal pb:optimal map:greenhold seed:1101 out:/abs/dir coach:1
  every:30 end:900 ground:1 groundcap:off`.
- Dials (Defs.LAND, `land.<key>=<n>` on the bench tools): `nocap_max` 2, `nocap_pay` 3.0, `extra_min` 0.35.
- One error line showed in one game (dropped arm, Cinder Steps, Crown v Clockwork): `has_tag` called on a dead (Nil)
  target, the same message as the known Spring Ballista splash error (ballista.gd); nothing in this job's code calls it.
