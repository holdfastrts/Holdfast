# crown-v-clockwork-coach: Crown v Clockwork, coached and filmed

(Work in progress: this file grows with each coaching round.)

The owner (2026-11-11 22:35) asked for every matchup coached and filmed with the scrutiny of the Crown v Brood job. This
job is Crown v Clockwork: Hard OPTIMAL v Hard OPTIMAL, filmed (tools/shot_ai_match.gd, now with `pa:`/`pb:` plans and
`every:N` stills of each main and each army), the mistakes named with a time, a picture and the decision behind them,
fixed, and the same seeds replayed. Both computers are coached. Fixes are small and gated by the enemy's faction
(`AICrown.cc_vs_clock()`, `AIClockwork.cc_vs_crown()`); `-- crcw:off` plays the matchup as before the job.

Tools: `tools/study/crcw_coach.py` (the 16 measuring games: the qa-matches base tags and seeds of 8 maps, both start
slots; `--only others` the control batch), `tools/study/crcw_coach_report.py` (the table).

## Round 1: the games as they stood (0.33.16, main at the job's start)

Filmed: Greenhold (seed 1101, the Crown P1; seed 1138, the Crown P2), Dune Sea (1107), Hollowfen (1152, the Crown P2),
Kestrel Rise (1131), Hard OPTIMAL both sides, to 15:00, a still of each main and each army every 30 s. Measured: the 16
games of `crcw_coach.py` (the "before" table at the end). The same picture in every game:

| | 5:00 | 7:00 | 8:00 | 10:00 |
|---|---|---|---|---|
| Crown gold earned (the Timing plan, 7 games) | 2,280 | 4,180 | 5,320 | 6,460 |
| Clockwork cogs earned | 3,600-4,060 | 5,400-6,800 | 6,750-8,400 | 8,800-12,700 |
| Crown labourers / Clockwork Winders | 17-19 / 18-28 | 19 / 25-32 | 18-19 / 26-32 | 19-22 / 31-32 |

The Crown's income is the same to the coin in every Timing game: 18-19 labourers on ONE hall until 7:30-8:20, against a
Clockwork whose economy opening has its second Clocktower up at ~3:00 and 30 Winders by 7:00.

### The Crown's mistakes

1. **One hall for eight minutes against a fast expansion** (every Timing game). OPTIMAL reads the Clockwork GREEDY at
   1:15-1:30 (it is: no army, two economy buildings) and picks the Timing attack 3 times in 5 (ai_optimal.gd GREEDY_CLOCK).
   The Timing plan caps the labourers at 19 (`"labs": 19`) and lays its second hall only after the attack goes out
   (6:41-7:35). The attack is no punish: it comes at 7:10-7:35 into a Clockwork on three halls. Income at 8:00: 0.65 of
   the Clockwork's; at 10:00: 0.60. Decision: AICrown PLANS["timing"]["bo"].
2. **A natural with no Farm worked.** In the games where the Crown got a natural (8:00+), its soil stayed at 100% to the
   end ("soil 16% 100% 100%" at 10:00 on Dune Sea, "20% 96% 100%" on Hollowfen): too few labourers for its Farms while the
   main's soil ran out at 9-10 minutes; then, with the Clockwork's army below the ramp, the labourers "run up" and the
   income stops for whole minutes (earned 7,600 at 10:00 and at 11:00, Dune Sea; 7,600 at 11:00 and 12:00, Hollowfen;
   efficiency 5%).
3. **A rush read buys tech with no army** (Greenhold seed 1138, the Crown on the Economy plan): AGGRESSIVE read at 4:46,
   the plan switched to Balanced, whose opening steps all stood, so the milestones bought the Foundry, the second Barracks
   and the Horse Breeder at 4:52-5:16 with 0 army; the first Musketeer came at 5:31, the army was 60 at 6:00 against
   965, two Farms at 2 of 8 hands (picture: `r1_greenhold_sw_0532_crown_tech_no_army.jpg`). Decision: AICrown._mid_tick.
4. **The wave walks home from a won fight** (Kestrel Rise): the first attack killed the Clockwork's new Clocktower at 8:11
   with the Clockwork's army at 350 against its 1,455, then walked home (`r1_kestrel_0802_...`, `r1_kestrel_0832_...`):
   any armed enemy by any Crown building calls the whole army, the wave too, back to defend (AI._army -> _defend, unless
   the army is 100 supply or more); one or two Clock Soldiers harassing its labourers were enough. The Clockwork rebuilt to
   2,630 by 11:00 and won.
5. **Strung-out waves** (Greenhold 7:06, `r1_greenhold_0706_waves_meet.jpg`; Hollowfen 6:50,
   `r1_hollowfen_0650_column_meets_push.jpg`): the Crown's wave is an attack-move of each unit to the target; the cannon,
   the wagon and the riders trail far behind the Musketeers and the line meets the push in a column. Not fixed (see "Still
   wrong").

### The Clockwork's mistakes

1. **First pushes into the Crown's line, too small**: the Clockwork reckons the Crown's army from what it saw, never less
   than a table (AICwArmy.TABLES["crown"]: 6:00 250, 7:00 400) made before crown-ai-v2 gave the Crown an army. A Hard
   Crown now has 480 at 6:00 and 800-850 at 7:00 (lower quartile). Kestrel Rise 6:04: 8 Clock Soldiers worth 560 went out
   against the 211 it reckoned (the Crown had 760) and fought under the Crown's ramp in musket range: 350 lost for 110
   (`r1_kestrel_0628_cw_push_under_muskets.jpg`). Ashford Crossing 7:05: 1,470 out, 13 lost for 2.
2. **The bank sleeps in the written builds**: the Springer timing had 1,186 cogs in the bank at 5:00 with one Springer for
   an army (Dune Sea, `r1_dune_0502_cw_bank_1186.jpg`), the Heavy Works push 450-550: a step waiting for Tension holds the
   plan, and only the Economy and Balanced openings mass soldiers meanwhile (AIClockwork._bo_mass). The Crown's timing hit
   that empty army at 7:35 and won its only game of the 16.
3. **The whole army meets an equal raid of muskets and guns on open ground** (Kestrel Rise 7:26: "the whole army defends
   the base (11 units, 797) against a raid worth 804"; 26 lost for 7, `r1_kestrel_0720_cw_army_shot_on_its_gears.jpg`).
   Left for the owner (see "Still wrong").

## Round 2: the Crown takes its natural; the Clockwork counts the Crown right and spends its bank

Fixes (each replayed on the same seeds, headless, `tools/qa_match.gd`, then filmed):

- **CR-1 THE TIMING FROM TWO HALLS** (scripts/ai_crown.gd PLANS["timing"]["bo_clock"], `_cc_bo_key`, `_cc_lab_cap`):
  against the Clockwork only, the Timing attack's opening lays the walled natural at 12 labourers, behind the Mill and the
  second Farm, then the Foundry, the Breeder, the second Barracks and the wave of 22 supply as before; the labourers go to
  34 (`labs_clock`). The plan stays a timing (one wave at 22 supply, the second hall behind it was its old order).
- **CW-1 THE CROWN COUNTED RIGHT** (scripts/ai_cw_army.gd TABLES["crown"]): the floor of the Clockwork's reckoning of a Hard
  Crown's army is the lower quartile of the 16 games' Crown armies before their first fight (6:00 480, 7:00 800, 8:00
  1,000; was 250, 400, 600). The push goes out only worth 1.25 times it, so the first push is bigger and a little later.
- **CW-2 THE BANK WORKS** (scripts/ai_clockwork.gd `_cc_bank`, from `_bo_tick`): in a written build that is not the Economy
  or Balanced opening, once the cogs no waiting step needs stay over 350 for 15 s (a heavy machine's kept cogs excluded),
  each idle Light Works trains a Clock Soldier. Dune Sea (seed 1107): the Springer timing's army at 5:00 went from 100 to
  490, its first push came at 5:38 with 880, and the Crown's only win of the 16 (against that empty army) became a game
  the Crown led at the end instead (the Clockwork's mistake, so its fix makes this matchup harder for the Crown).

What the replays showed (the same seeds): the natural stood at 3:12-3:56 instead of 7:26-8:17, but its soil stayed at
100%: an opening lays no Farm by itself (the shared economy rules are off while a build order runs) and 26 labourers do
not fill two halls' Farms (8 hands each). Greenhold income at 8:00 was the same (5,320), at 10:00 +18%.

## Round 3: the natural worked and walled; soldiers when a rush is read

- **CR-1b** (`_cc_econ`, from the opening's think stage 1): while the two-hall Timing's opening runs, the shared economy
  rules lay the Farms and the Mill (the freshest soil first: the natural), with the opening's step gold out of reach;
  `labs_clock` 26 -> 34; the natural walled at once as on the owner's plans (`_cc_walls`, asked by `owner_walls`) and its
  wall's gold first (`wall_first`); the Barracks keep a guard of 8 supply until the Breeder (uncapped from 2:00 the
  soldiers held the labourers at 19).
- **CR-3 SOLDIERS BEFORE THE MILESTONES WHEN A RUSH IS READ** (`_cc_rush_hold`, from `_mid_tick`): against the Clockwork,
  while a rush is read or defended and the army is under 8 supply, every milestone but the first Barracks waits.
  Greenhold seed 1138 replayed: "milestone Foundry waits: a rush is read and the army has 0 supply (it wants 8 first)" at
  4:47, the first Musketeer at 5:07 (was 5:31).

Greenhold seed 1101 after round 3 (`r2c_greenhold`): the natural's soil worked from 7:00 (96% -> 66% by 12:00), income
7,980 at 10:00 (6,460), 10,640 at 12:00 (8,360), 14,820 at 14:00 (9,760); army 3,010 at 14:00 (1,175); one hall lost (one).

## Round 4: the wave stays out

- **CR-4 THE WAVE STAYS OUT FOR A SMALL RAID** (`AICrown._cc_keep_wave`, asked by `AI._army` before `_defend`): against the
  Clockwork, while a wave is out, a raid at home worth less than 40% of the wave and less than 500 is left to the
  soldiers at home; the wave's idle units walk on to the target. A hall under half health with enemies at it still calls
  everyone home.
- Film `r4_kestrel` (seed 1131) showed the next hole, the one the two-hall opening made worse on this map: the natural
  sits under the main's ramp, its wall had a few pieces, so the cliff edge was off (ai-followups: no cliff edge above a
  walled natural) and the gate post not yet on (half the wall closed): at 6:33-6:59 eleven Clock Soldiers burned the hall
  while eight Musketeers stood idle in the main's Farm above (`r4_kestrel_0654_natural_burns_line_idle.jpg`); the main fell
  at 9:12.
- Film `r4_greenhold`: the Crown held (army 1,985 against 2,090 at 11:00, 37 kills for 23) but had no Field Cannon until
  13:25 with the Foundry up since 5:15: the horses went to five riders.

## Round 5: the cliff edge until the gate post; the guns get the horses

- **CR-5** (scripts/ai_crown_hold.gd `_cc_edge_floor`, asked by `_in_walled_natural`): against the Clockwork the cliff edge
  is skipped only once the natural's wall is closed enough for the gate post (GATE_CLOSED, 0.5), not at its first piece.
- **CR-6 THE GUNS GET THE HORSES** (`AICrown._cc_guns_first`, asked by `_riders_wait`): against the Clockwork, once one rider
  (the map scout) is out and a Foundry stands, the Barracks train no more riders until 3 Field Cannons (AI.CANNONS_FIRST)
  are out or queued; the horses go to the Foundry (round 5's foundry_horses) and the Barracks save for the gun (gun_wait).

## Shared functions changed (for the merges with the other five coaching jobs)

Every new rule is in a new function, named `_cc_*` / `cc_*`, and asks `AICrown.cc_vs_clock()` or
`AIClockwork.cc_vs_crown()` (every enemy is that faction) and `cc_on` (`-- crcw:off` turns all of them off). The shared
functions only gained a call or a term:

| file | function | change |
|---|---|---|
| scripts/ai.gd | `_army` | one line before the threat branch: `army = _cc_keep_wave(army, tspots)` |
| scripts/ai.gd | new `_cc_keep_wave` | the base returns the army unchanged (AICrown overrides it) |
| scripts/ai_crown.gd | PLANS["timing"] | new keys `bo_clock` (the opening against the Clockwork) and `labs_clock` |
| scripts/ai_crown.gd | the plan set-up (`_bo_plan` from `bo_key`) and `opt_switch` | the key goes through `_cc_bo_key`, the cap through `_cc_lab_cap` |
| scripts/ai_crown.gd | `_think_stage` (stage 1, while the opening owns the gold) | `_cc_econ()` after `_bo_tick()` |
| scripts/ai_crown.gd | `_mid_tick` | `if _cc_rush_hold(k, army): continue` after the lagging check |
| scripts/ai_crown.gd | `owner_walls` | true also for `_cc_walls()` |
| scripts/ai_crown.gd | `wall_first` | `owner_on()` -> `(owner_on() or _cc_walls())` |
| scripts/ai_crown.gd | `_riders_wait` | `or _cc_guns_first()` |
| scripts/ai_crown_hold.gd | `_in_walled_natural` | `closed_share(p) <= 0.0` -> `<= _cc_edge_floor()` (0.0 unless against the Clockwork) |
| scripts/ai_clockwork.gd | `_bo_tick` | `_cc_bank()` after `_train_workers()` |
| scripts/ai_cw_army.gd | TABLES | the "crown" row only (read only when the Clockwork reckons a Crown) |

Tools: tools/shot_ai_match.gd gained `pa:`/`pb:` (the plans; the default stays "balanced") and `every:N`;
tools/study/crcw_coach.py and crcw_coach_report.py are new; tools/test_crcw_coach.gd is the matchup's test.
