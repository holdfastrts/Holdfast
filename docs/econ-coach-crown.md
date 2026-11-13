# The Crown computer's economy, coached (job econ-coach-crown, 2026-11-13)

The owner (2026-11-13 01:18): "The computers reach only part of what their faction could earn ... This must be corrected
with AI coaching before we ever touch balance." This job changed **only how the Crown computer plays its economy**: no unit,
building, price, yield or rule number. Design rules followed (docs/design_principles.md): 2 (exposed income that pays;
depletion forces expansion, it must not strangle it), 4 (every choice has an opportunity cost: a Farm hand repays his
50 gold in 42 s). Sister jobs econ-coach-clockwork and econ-coach-brood run beside it; this one touches only the Crown's
own files (scripts/ai_crown.gd, the Crown branches of scripts/ai_optimal.gd) and tools.

## In short

1. **Alone, the Crown computer's Economy plan already reaches its design by 10:00** (0.99 of the bench), and its early
   gap (0.79 at 5:00) is mostly what the bench gets for free: the bench builds without builders, the computer pays 18-20
   labourer-minutes of building and 4 of scouting in its first 8 minutes (~1,600 gold of farming).
2. **In the games, before 9:00, the Crown earns what its chosen PLAN earns alone**: the opponent costs it little before
   the first big fights (hall losses come at a median 12:00). So the 0.53-0.70 of the games is mostly the plans OPTIMAL
   picks (the Horseman rush against the Brood, the Timing attack against the Clockwork, raids and timings in the mirror,
   each built to trade economy for army), then the halls lost after 9:00.
3. **Fixed (kept)**: spent Farms pulled down when they block a fresh hall's Farms; **free Farm posts first** (the halls
   no longer stand idle for want of gold or behind the army-share hold while built Farms have empty posts, unless the
   army's survival checks say otherwise). Alone, every plan rose: Balanced 0.62 -> 0.79 at 5:00 and 0.79 -> 0.95 at 8:00,
   the Siege push 0.59 -> 0.79 at 8:00, the raids +0.08-0.11. In 36 real games: the mirror +5-14%, against the Clockwork
   +7-11% from 10:00, fewer losses (Crown v Clockwork 0-8-4 -> 0-10-2), Crown v Brood unchanged (its rush's own economy).
4. **Tried and NOT kept as defaults** (study switches): the riders only for a "truly greedy" Brood (the Economy race
   earned +20% by 8:00-10:00 but lost more games: the riders' worth is in the BROOD's economy), and the rush saturating
   its main (its posts were full already; the gold was the limit).
5. **For the owner** (section 6): a rule question on spent Farms, and whether OPTIMAL should pick more economy (the only
   lever left that moves the Crown's in-game income a lot, at a cost in identity and, against the Brood, results).

## 1. How it was measured

- **The bench** (tools/econ_bench.gd, docs/economy_parity.md section 1): the Crown's design, a scripted ideal build alone
  on Greenhold, halls at 4:00 / 8:00 / 12:00. Value = gold + powder: 4,364 / 10,034 / 14,079 / 26,559 at 5 / 8 / 10 / 15
  minutes; primary only (the games' statistic) 4,180 / 9,500 / 13,180 / 24,460.
- **The computer alone** (new: tools/econ_ai_alone.gd; report tools/study/econ_alone_report.py): the bench's setup (the
  other slot an idle dummy, kept standing), the Hard computer playing a plan to 15:00. Per minute: earned, workers and
  what they do (farm, mill, build, haul, scout, idle), Farm and Mill crews against their posts, spent Farms standing,
  supply-blocked seconds, production idle time, army, plan.
- **The games** (tools/study/qa_matches.py `--only crown`, report tools/study/econ_coach_crown.py): Hard OPTIMAL v Hard
  OPTIMAL to 15:00, the parity design (Greenhold, Dune Sea, Frostfang, Ashford Crossing, Hollowfen, Cinder Steps; both
  rounds, sides swapped): 12 games each of Crown v Brood, Crown v Clockwork and the Crown mirror. BEFORE = the same 36
  tags of the win-rate study (0.33.25: the same computers as main 0.33.31). tools/qa_match.gd now also records the Crown's
  Farms, Mills, posts and crews, what its other labourers do and why an idle hall trains nothing (every 5 s).

## 2. Where it loses

### 2.1 Alone (Greenhold; value against the bench at 5 / 8 / 10 / 15 min)

| plan (before) | 5:00 | 8:00 | 10:00 | 15:00 | 2nd / 3rd hall |
|---|---|---|---|---|---|
| Economy | 0.79 | 0.87 | 0.99 | 1.07 | 2:07 / 8:18 |
| Balanced | 0.62 | 0.79 | 0.87 | 1.09 | 2:06 / 8:54 |
| OPTIMAL v an idle Clockwork (picks Economy) | 0.62 | 0.68 | 0.82 | 0.91 | 2:54 / 9:18 |
| OPTIMAL v an idle Brood (picks Balanced) | 0.62 | 0.67 | 0.76 | 0.96 | 3:00 / 9:06 |
| OPTIMAL v an idle Crown (picks Timing) | 0.64 | 0.60 | 0.57 | 0.67 | 7:30 / 9:00 |
| Rush (v Brood; then Balanced) | 0.70 | 0.74 | 0.76 | 0.76 | 4:48 / 9:54 |
| Siege push | 0.64 | 0.59 | 0.71 | 0.78 | 3:36 / 8:48 |
| Dragoon raids | 0.56 | 0.52 | 0.68 | 0.77 | 5:24 / 8:42 |
| Balloon harass | 0.58 | 0.56 | 0.68 | 0.76 | 5:48 / 9:00 |
| Timing attack | 0.57 | 0.56 | 0.57 | 0.72 | 6:54 / 9:06 |

- **The Economy plan meets the bench by 10:00 and beats it at 15:00** (it takes a 4th and 5th hall at 9-12 min where
  the bench took its 4th at 12:00). Its early gap is labour the bench does not pay: 19.8 labourer-minutes building and 4.4
  scouting by 8:00 (~1,700 gold of farming at 71 a Farm hand a minute); the bench's 1,280 lead at 8:00 is about that.
- The army plans lose what they are built to trade (the Timing attack's 19 labourers on one hall until its attack, the
  raids' Horse Breeders and riders), plus the same building labour.
- **The Farm is no worse thin than full** (Defs.FARM_BASE 0: each hand grows 71 gold a minute, however few): what counts
  is the number of hands on Farms, and a Mill hand is worth a quarter of one (17 powder a minute).

### 2.2 In the games (before; primary against the bench's primary)

| matchup | 5:00 | 8:00 | 10:00 | 15:00 | halls 5 / 8 / 10 | workers 5 / 8 / 10 | W-D-L |
|---|---|---|---|---|---|---|---|
| Crown v Brood | 0.68 | 0.60 | 0.64 | 0.60 | 1.2 / 2.0 / 1.9 | 18 / 27 / 33 | 0-5-7 |
| Crown v Clockwork | 0.59 | 0.55 | 0.53 | 0.43 | 1.1 / 1.8 / 2.4 | 18 / 22 / 25 | 0-8-4 |
| Crown mirror (both sides) | 0.61 | 0.55 | 0.62 | 0.65 | 1.9 / 2.0 / 2.4 | 18 / 26 / 36 | 0-24-0 |

What the opponent costs and what the computer does itself:
- **Before 9:00 the in-game income is the chosen plan's own** (Crown v Brood: the Rush then Economy, 0.60 at 8:00, alone
  0.74; v Clockwork: the Timing attack 8 of 12 games, 0.55 at 8:00, alone 0.56; the mirror's mix of Dragoon raids, Timing,
  Economy, Siege and Balanced, 0.51-0.59, alone 0.52-0.87). The opponent costs a few labourers to raids (1-2 fleeing at a
  time from 8:00) and little else.
- **After 9:00 it is the opponent**: halls lost (25-28 in the 12 cross games of each matchup, at a median 12:00),
  labourers 23 at 15:00 against the Brood.
- **Its own macro losses, measured in the games** (the instrumented games): 8-12 Farm posts empty at 5:00-10:00 (26-28
  labourers for 32 Farm posts at 7:00-8:00), the halls training 3.3 labourers a minute where two can train 10; and the
  reason, counted every 5 s with a hall idle and Farm posts free: the GOLD (under a labourer's 50: a harvest's 380 spent on
  buildings and soldiers in the other think stages before the next look at the labourers), the army-share hold
  ("an army the size of the economy"), and inside the build orders the next step's reserve.
- **Spent Farms**: a main's two Farms on spent soil stood from ~10:00 in most long games; they blocked a fresh hall's Farm
  only now and then in 15-minute games (the limit is rarely full then), more later.
- **Income per labourer** (the owner's question: 34 a minute at 10:00 against the Clockwork's 57): by design the Crown's
  is lower (the bench: 45 gold a labourer a minute at 10:00, gold only; a Mill hand's 17 powder pulls it down, as do the
  Farms' 380-gold lumps), so about two thirds of that gap is the design and one third the computer (builders, empty Farm
  posts, labourers fleeing raids).

## 3. The fixes and what each did

| fix (switch) | kept? | measured |
|---|---|---|
| **Spent Farms come down** (AICrown._recycle_spent, `farmrecycle:off`) | yes | a Farm on spent soil is pulled down, one at a time, when the Farm limit is full and a hall on fresh soil (25%+) has fewer than its two live Farms. Rare before 15:00 (3 pulled in 36 games); it matters in longer games and was the bench's trap. |
| **Free Farm posts first** (AICrown._posts_first / _bo_posts_first / _econ_keep, `postsfirst:off`) | yes | while 2+ built Farm posts on live soil stand empty: the army-share hold no longer stops the halls, the next labourers' gold is kept from the other spending (past 10:00 too), and in a build order a labourer comes before the next step's reserve; never while a rush is defended, enemies are at our buildings or labourers (a raid), a rush was read in the first 7 minutes, or the army is far behind (army_lags, the Brood's army_behind / army_grows), and never past a plan's own labourer count (the Timing attack's 19) or before its riders/soldiers-first steps. Alone: see 4.1. Games: see 4.2. |
| **The riders only for a truly greedy Brood** (AIOptimal._true_greed_brood, `truegreed:on`) and **the lean no longer binds** (`leanfree:on`) | no (switches) | the Brood's usual opening (Mother + one far turtle, "a second base and little army", 35 of 38 reads) answered by the Economy race instead of the Horseman rush: income +20% by 8:00-10:00 (0.60 -> 0.73, 0.64 -> 0.75), but 0-60 of army until 6:00, the Brood's economy unharassed and its army at 8:00 doubled (1,000-2,600 against 800-1,500), results 0-5-7 -> 0-3-9. The riders' worth is in the Brood's economy, not the Crown's: the owner's rule stays. |
| **The rush saturates its main** (AICrown._rush_labs, `rushsat:on`) | no (switch) | in the rush the main's posts were full already (2 Farms, 16 posts, 15-16 labourers at 4:00; the gold, all on riders, held the hall): income unchanged in 12 games. |

Also: `greedyclock:<plan>` (a study switch: the Crown answers a greedy Clockwork with that plan) for the owner's question
below; not run.

## 4. Results

### 4.1 The computer alone (Greenhold; before -> after, value against the bench)

| plan | 5:00 | 8:00 | 10:00 | 15:00 |
|---|---|---|---|---|
| Economy | 0.79 -> 0.79 | 0.87 -> 0.91 | 0.99 -> 1.00 | 1.07 -> 1.23 |
| Balanced | 0.62 -> 0.79 | 0.79 -> 0.95 | 0.87 -> 0.95 | 1.09 -> 1.11 |
| Siege push | 0.64 -> 0.74 | 0.59 -> 0.79 | 0.71 -> 0.85 | 0.78 -> 0.89 |
| Dragoon raids | 0.56 -> 0.65 | 0.52 -> 0.63 | 0.68 -> 0.70 | 0.77 -> 0.79 |
| Balloon harass | 0.58 -> 0.66 | 0.56 -> 0.64 | 0.68 -> 0.71 | 0.76 -> 0.79 |
| Timing attack | 0.57 -> 0.57 | 0.56 -> 0.60 | 0.57 -> 0.62 | 0.72 -> 0.76 |

(Other maps and the OPTIMAL runs: docs/econ-coach-crown/alone/*.json, the same tool; single runs, a few percent of noise.)
Each plan against what it can reach: the Economy plan reaches the bench (less its builders' labour early); the Balanced
plan now nearly does; the army plans keep their identity (fewer labourers, an army out early) and reach 0.6-0.8 by 8:00.

### 4.2 The games (36 before, 36 after; primary against the bench; W-D-L from the Crown's side)

| matchup | 5:00 | 8:00 | 10:00 | 15:00 | army 8:00 | W-D-L | halls lost |
|---|---|---|---|---|---|---|---|
| Crown v Brood | 0.68 -> 0.70 | 0.60 -> 0.57 | 0.64 -> 0.61 | 0.60 -> 0.57 | 817 -> 820 | 0-5-7 -> 0-6-6 | 28 -> 22 |
| Crown v Clockwork | 0.59 -> 0.62 | 0.55 -> 0.57 | 0.53 -> 0.57 | 0.43 -> 0.48 | 1,304 -> 1,287 | 0-8-4 -> 0-10-2 | 25 -> 27 |
| Crown mirror, P1 | 0.59 -> 0.61 | 0.51 -> 0.58 | 0.57 -> 0.62 | 0.58 -> 0.63 | 759 -> 859 | 0-12-0 -> 0-11-1 | 13 -> 7 (both) |
| Crown mirror, P2 | 0.63 -> 0.61 | 0.59 -> 0.61 | 0.66 -> 0.67 | 0.71 -> 0.72 | 932 -> 1,013 | | |

Decided games' length: Crown v Brood 13:13 -> 13:12, Crown v Clockwork 13:55 -> 14:53. (The "after" games ran the
branch before two small last changes: the rush's saturation, since made a switch, and the raid check of section 3, which
only makes "posts first" step aside sooner; both re-tested in the AI tests, not in another 36 games.) Single games are noisy
(the same tag agrees with itself about 2 times in 3): read the totals. The batches in between (all 36 tags each):
a1 = the true-greed read (Crown v Brood 0.73 / 0.75 at 8 / 10 min, 0-3-9), a3 = posts first without the gold kept
(no change in income: the gold, not the hold, was what kept the halls idle).

**What it shows**: the computer's own economy is now close to its plans' designs; the in-game income moved little against
the Brood (its rush plan's economy is its identity, and the Brood's raids and attacks after 8:00), a little against the
Clockwork and in the mirror. The big remaining gap in the games is WHICH plan OPTIMAL plays and the halls lost after 9:00.

### 4.3 Filmed (Greenhold, seed 1102, Crown mirror, OPTIMAL both; P1 plays Economy; `-- postsfirst:off farmrecycle:off` before)

docs/econ-coach-crown/: before_base_0_0802.jpg / after_base_0_0802.jpg (the main at 8:00), before/after_base_0_1002.jpg,
before/after_army_1132.jpg, and the coach's status lines (before_coach.txt, after_coach.txt). P1 at 11:51: earned 11,020
with 47 labourers and an army of 1,795 (2,430 of value lost) before; 13,300 with 53 labourers and 2,365 (1,355 lost)
after; at 8:21 31 against 38 labourers.

### 4.4 The AI tests

All 39 tools/test_ai_*.gd and tools/test_crown_*.gd were run. Failing, and failing the same with the changes switched off
(`postsfirst:off farmrecycle:off rushsat:off`, so not this job's): test_ai_rush_followup (14 checks), test_crown_dragoon_raid
([plan] the group out by 690 s). Flaky, passed on a rerun: test_ai_cw_horse_raid, test_ai_worker_safety, test_crown_hold
([below], known flaky). Broken by the first version and fixed: test_crown_mirror ("a Musketeer is queued for the raider":
the labourers' kept gold held it; "posts first" now steps aside while an armed enemy is at the labourers, _raided) and
test_ai_rush ("workers before the Brood Mother", with the rush's saturation on: the switch is off by default now).

## 5. What is left

- **OPTIMAL's picks** (the big lever, not changed: the owner's identity question). Against the Clockwork it plays the
  Timing attack (8 of 12; 0.55-0.57 of the bench all game, and it still wins none); the mirror's picks mix four army plans.
  `greedyclock:economy` can measure the Economy race against the Clockwork; against the Brood the Economy race was measured
  here (section 3) and lost more.
- **Builders**: the Crown's every building takes a labourer off a Farm; 2-5 at a time in the first 8 minutes, and the
  natural's palisade 9-11 at once around 7:00 in some games. Fewer builders on the wall would be more gold and a later wall.
- **Halls lost after 9:00** (the opponent's part, legitimate): the army's work, not the economy's.
- **Late game**: alone, the Economy and Balanced plans run to 100-120 labourers at the 200 cap (no owner cap past five
  halls); fine alone, too many against an army.

## 6. For the owner (proposed, NOT applied)

1. **Should a Farm on spent soil still count against "2 Farms a Town Hall"?** Today it does (Game.econ_count counts every
   Farm, as it counts Mills and Presses); the computer now pulls its spent Farms down when they block a fresh hall, but a
   player who does not know to demolish a barren Farm is capped. Proposal: count only Farms on live soil (as AI._workers
   already does for posts), or leave it as a player's skill.
2. **OPTIMAL against the Clockwork**: Timing attack (today, 3 of 5) or more of the Economy race? A measured batch with
   `-- greedyclock:economy` would say what it costs in results.
3. **The riders against the Brood's usual opening**: kept (your rule). The Economy race earns 20% more by 10:00 and loses
   more games; if the Crown is to out-earn the Brood, the riders' raid is what keeps the Brood's economy down.

## How to run it

- Alone: `godot --headless --fixed-fps 30 --script res://tools/econ_ai_alone.gd -- crown plan=<plan> [foe=clockwork]
  [map=greenhold] [minutes=15] [out=file.json] [switches]`, about 3 minutes a run; `python3 tools/study/econ_alone_report.py
  FILE...`.
- Games: `python3 tools/study/qa_matches.py run OUT --data DATA --only crown|crbr|crcw|crcr --jobs 2 [--extra a,b]
  [--root DIR]`; `python3 tools/study/econ_coach_crown.py DATA`.
- Films: `xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script
  res://tools/shot_ai_match.gd -- a:crown b:crown map:greenhold seed:1102 out:DIR pa:optimal pb:optimal coach:1 end:720`.
