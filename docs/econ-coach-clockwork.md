# Coaching the Clockwork computer's economy (job econ-coach-clockwork)

The owner (2026-11-13 01:18): "The computers reach only part of what their faction could earn ... This must be corrected with
AI coaching before we ever touch balance. The AI must be 100% or as close as possible to what it could do, so we have a
complete picture and then make decisions." This job: the Hard Clockwork computer's economy as close as possible to its
design, measured by the economy bench (tools/econ_bench.gd, docs/economy_parity.md section 1). **No rule or number of the
game changed**: no unit, building, price, yield or rule; only how the Clockwork computer plays (scripts/ai_cw_macro.gd, new,
and small hooks in scripts/ai_clockwork.gd and scripts/ai_cw_eco.gd; nothing in the shared scripts/ai.gd). Design rules
followed (docs/design_principles.md): section 2 (an economy that expands and runs out must be worked before the factions can
be compared fairly), section 1 (fairness: the same design, measured, not guessed). `-- cwmacro:off` plays as before.

## In short

1. **Where it lost** (the computer alone against an idle dummy, the bench's own setup, and 36 Hard games): its Winders
   **stopped at 32** (the shared cap counted the 2-12 Winders that walk with the army to wind it among them, so only 20-25
   worked while its presses had 36-46 posts); a **written build kept its own small economy** (a build without "press_new"
   steps stood a second Clocktower with no press beside it: on Hollowfen OPTIMAL earned 9,000 cogs in 15 minutes); **every
   press was on the small ring** (two bases could pay at most 72% of the bench's two); the Regulators came late once four
   or five Clocktowers trained Winders (3-4 minutes supply-blocked); a press at a time after a base ran dry (15-37 Winders
   idle for a minute).
2. **Five fixes** (section 3), each kept because the economy rose with the army and the results holding or better.
3. **The computer alone** (OPTIMAL, Economy, Balanced; Greenhold and Hollowfen; cogs as a share of the bench's):
   **0.96 / 0.90 / 0.86 / 0.75 at 5 / 8 / 10 / 15 minutes before, 1.00 / 1.08 / 1.17 / 1.20 after**. Economy and Balanced
   beat the bench from 8:00 on (1.14-1.21 at 8:00); the aggressive plans keep their lean openings and reach 0.95-1.18 at
   15:00 (was 0.65-0.84).
4. **In the games** (Hard OPTIMAL v Hard OPTIMAL, the parity batch's 36 Clockwork games, before = the win-rate study's games
   on the same tags and seeds): RESULTS_SHORT
5. **What is left** (section 5): the lean early minutes of the aggressive plans (their identity), the bank piling up at the
   200 supply cap (nothing to spend it on), the escorts, the Brood's raids (the opponent's, legitimate), and two RULE
   questions for the owner, proposed, not applied.

## 1. How it was measured

- **The bench** (main, docs/economy_parity/before/fix_clockwork.json and hollowfen/before_clockwork.json): the scripted
  ideal build, 2 big Cog Presses and a Mainspring a Clocktower, Clocktowers at 4:00, 8:00 and 12:00, no army. The yardstick
  is the PRIMARY income, cogs earned (section 3 of docs/economy_parity.md compared the games the same way).
- **The computer alone** (new: tools/econ_alone_cw.gd, run by tools/study/econ_alone_cw.sh, read by
  tools/study/econ_alone_cw_report.py): the bench's setup with the Hard Clockwork computer playing instead of the script,
  on any plan, to 15:00. The dummy (a Crown nobody plays) is kept standing (its buildings healed, its bank full) so the
  computer's attacks never end the game; the computer is NOT peaceful, its scout reads (OPTIMAL picks its build from that:
  against an idle Crown it reads GREEDY and picks the Clock Soldier rush, the punish). A line a minute: cogs and Tension
  earned, Winders (at work, idle, escorts), posts (the crews of its working presses and Mainsprings), presses (big, small,
  spent standing), Clocktowers, bank, supply, army; and the seconds supply-blocked, the Winder-seconds of empty posts, the
  idle-Winder seconds, the seconds a Clocktower stood idle while posts were empty. Data: docs/econ_coach_clockwork/alone/.
- **The games**: tools/study/econ_coach_cw_games.py runs the 36 games of `qa_matches.py --only parity` with a Clockwork
  side (Crown v Clockwork, Brood v Clockwork, the mirror; Greenhold, Dune Sea, Frostfang, Ashford Crossing, Hollowfen,
  Cinder Steps; both rounds), Hard OPTIMAL both sides, 15:00; tools/study/econ_coach_cw_report.py reads them. BEFORE = the
  same tags and seeds from the win-rate study (docs/winrate_2026_11_12/winrate-a/b/c, 0.33.25: the Clockwork computer is
  the same as on main). Data: docs/econ_coach_clockwork/games/.

## 2. Where it lost (before)

The computer alone (cogs earned as a share of the bench's at 5 / 8 / 10 / 12 / 15 minutes):

| plan (what it played) | Greenhold | Hollowfen |
|---|---|---|
| OPTIMAL (Clock Soldier rush; Hollowfen then the Springer timing) | 0.82 / 0.72 / 0.73 / 0.72 / 0.76 | 0.81 / 0.62 / 0.56 / 0.49 / **0.36** |
| Economy | 1.07 / 1.03 / 0.96 / 0.88 / 0.81 | 1.07 / 1.04 / 1.01 / 0.95 / 0.91 |
| Balanced | 1.04 / 1.02 / 0.97 / 0.90 / 0.86 | 0.97 / 0.97 / 0.93 / 0.87 / 0.83 |

The written openings are good (Economy and Balanced are AT or above the bench until 8:00); the computer falls behind from
8:00 on, by the same few mistakes in every plan:

1. **The Winders stopped at 32.** AI._workers (shared) caps the Clockwork at 13 a Clocktower and 32 at most (Hard), and the
   escorts (AI._escort_want: 2 + one for every 5 constructs, up to 10, plus the Great Winder's and the Ballistas' crews), the
   builder and the Winders on the army's errands are among those 32. From 8:00-9:00 every run sat at exactly 32 Winders,
   20-25 at work, while its posts grew to 36-46: 1,000-1,500 Winder-seconds of empty posts a minute (the "empty" column),
   and its Clocktowers stood idle with posts empty for 2-4 minutes in all. This is the "labourers stop at 26-32" of
   economy_parity section 3. In the games: 29-32 Winders at 8:00, 23-32 at 15:00.
2. **A written build kept its own small economy.** While an opening build runs (AIClockwork.bo_on) the shared rules are off:
   only its steps build and its worker goal trains. A build with no "press_new" step (the Clock Soldier rush, the Springer
   timing, the Owls...) laid its second Clocktower and no press beside it. On Hollowfen OPTIMAL picked the Clock Soldier rush
   at 1:45, switched to the Springer timing at 5:17; the Springer timing's steps then waited on a Swift for ten minutes with
   1,000-1,700 cogs in the bank: 13 posts all game (2 small presses and a Mainspring at the main), 21 Winders, 9,000 cogs at
   15:00, the main spent at 12:00 and nothing coming in after.
3. **OPTIMAL's second switch had no time cap** (AIClockwork.opt_switch: a build picked while another written build still
   ran got no OPT_BO_CAP), and the hand-over of a stuck build (no step for 60 s with 1,000 cogs banked) ran only against the
   Brood (clockwork-v-brood-coach's gate).
4. **Every press was small.** The shared rule (AI._want_big_gear) lays a BIG press only when spare Winders already stand, and
   with the Winders trained for the posts there never are; the press steps and the shared rule's spot (laid with `at` given)
   were small anyway. Two small presses take 5 Winders each and press 7.2 cogs a second; two big ones 8 each and 10: two
   bases on small presses can pay at most 4 x 7.2 = 28.8 cogs a second, 72% of the bench's 40, until a third Clocktower
   stands. The big ring costs 25 cogs and 4 s more (Defs.GEAR "big_pick").
5. **Regulators late, presses one at a time.** After the opening the shared supply rule keeps a margin of 3 + 3 a Works,
   not counting four or five Clocktowers training Winders: 3-4 minutes supply-blocked from 6:00 once the Winders could grow
   (it showed only after fix 1). And the shared rule lays one press at a time: when a main ran dry its crews (15-37 Winders)
   stood idle for a minute or more while the next presses went up one by one.

Not losses (checked): the expansions are on time alone (Clocktowers 2 / 3-4 / 4 / 5-6 at 5 / 8 / 10 / 15 minutes, the
bench's 2 / 3 / 3 / 4); the spent presses are pulled down (AI._recycle_spent) when the limit needs it; idle Winders before
9:00 are mostly escorts at rest by the army and the crew trained ahead for a Clocktower going up.

## 3. The fixes, each measured

All in scripts/ai_cw_macro.gd (AIClockwork.macro), Hard and up (Easy and Normal keep their smaller economy):

| # | fix | where | measured |
|---|---|---|---|
| 1 | **Winders for every post**: the count the shared rules train after the opening (AIClockwork._lab_want -> macro.want) is every post of its working presses and Mainsprings (standing or going up) + the escorts + a builder + a press crew ahead for each Clocktower going up, the plan's "workers" share scaling it down (Rush 0.75), at most MAX_WINDERS 54 (the rest of the 200 supply is the army's) | ai_cw_macro.want | with 2-3: alone 0.75 -> 1.15 of the bench at 15:00 (mean of 6) |
| 2 | **The economy under any written build**: while an opening runs, posts left empty get Winders (from the cogs its waiting step leaves), and a standing Clocktower on fresh brass short of its two presses gets one, unless the build lays its own press within its next 4 steps (the opening stays as written) | ai_cw_macro.bo_tick | Hollowfen OPTIMAL 9,000 -> 28,748 cogs at 15:00 |
| 3 | **OPTIMAL's second switch capped** (OPT_BO_CAP 300 s, as the first switch after the opening), and **the stuck-build hand-over against every faction** (it was the Brood only) | ai_clockwork.opt_switch, _stuck_hand_over | the Hollowfen build handed over at 5:26 (stuck 66 s, 1,003 banked) |
| 4 | **Regulators ahead of every maker** after the opening: a margin of 4 + one a Clocktower + 3 a Works (Light or Heavy), two going up at once when tight | ai_cw_macro.supply | supply-blocked 0-78 s a run before; 227-230 s with fix 1 alone (the Winders grew); 0-40 s with this |
| 5 | **Presses after the opening by the macro**, the freshest Clocktower first, **a second at once for 4+ idle Winders**, and **the BIG ring for the first three Clocktowers' presses** (under 140 supply; the press_new steps too), the small ring later (at the supply cap the small ring's 86 cogs a Winder a minute beat the big one's 75) | ai_cw_macro.presses_after, presses_more, lay_press; ai_cw_eco._press_new | alone 1.15 -> 1.20 at 15:00, 1.01 -> 1.08 at 8:00, 1.08 -> 1.17 at 10:00 |

The computer alone, the mean of OPTIMAL, Economy and Balanced on Greenhold and Hollowfen (share of the bench's cogs):

| | 5:00 | 8:00 | 10:00 | 12:00 | 15:00 |
|---|---|---|---|---|---|
| before (main) | 0.96 | 0.90 | 0.86 | 0.80 | 0.75 |
| fixes 1-4 + presses after (macro 1) | 0.98 | 1.01 | 1.08 | 1.11 | 1.15 |
| + the big ring (macro 2, the branch) | **1.00** | **1.08** | **1.17** | **1.18** | **1.20** |

Per plan, before -> after (cogs at 15:00; share of the bench at 5 / 8 / 10 / 15; Winders at 8 / 10 / 15; army at 15:00):

| plan | before | after |
|---|---|---|
| OPTIMAL Greenhold | 19,055; 0.82 / 0.72 / 0.73 / 0.76; 31 / 30 / 32; 10,870 | 27,616; 0.82 / 0.83 / 0.97 / 1.10; 44 / 54 / 54; 10,115 |
| OPTIMAL Hollowfen | 9,000; 0.81 / 0.62 / 0.56 / 0.36; 21 / 21 / 21; 5,620 | 27,356; 0.94 / 0.99 / 1.10 / 1.10; 54 / 54 / 54; 9,915 |
| Economy Greenhold | 20,237; 1.07 / 1.03 / 0.96 / 0.81; 32 / 32 / 32; 11,510 | 31,570; 1.09 / 1.21 / 1.28 / 1.26; 54 / 54 / 54; 9,895 |
| Economy Hollowfen | 22,524; 1.07 / 1.04 / 1.01 / 0.91; 32 / 32 / 32; 11,695 | 31,489; 1.08 / 1.19 / 1.28 / 1.27; 54 / 54 / 52; 10,020 |
| Balanced Greenhold | 21,606; 1.04 / 1.02 / 0.97 / 0.86; 32 / 32 / 32; 11,715 | 31,281; 1.03 / 1.14 / 1.23 / 1.25; 53 / 54 / 54; 10,080 |
| Balanced Hollowfen | 20,590; 0.97 / 0.97 / 0.93 / 0.83; 32 / 32 / 32; 11,710 | 29,872; 1.01 / 1.08 / 1.17 / 1.20; 46 / 54 / 54; 9,970 |

The other plans, Greenhold (before = the same code with `cwmacro:off`):

| plan | share of the bench at 5 / 8 / 10 / 12 / 15 before | after | Winders 8 / 10 / 15 before -> after |
|---|---|---|---|
| Springer timing | 0.78 / 0.61 / 0.63 / 0.64 / 0.66 | 0.78 / 0.69 / 0.80 / 0.89 / 0.97 | 25/32/32 -> 39/54/54 |
| Pendulums | 0.84 / 0.79 / 0.80 / 0.78 / 0.79 | 0.84 / 0.84 / 0.98 / 1.05 / 1.12 | 32/32/32 -> 45/54/54 |
| Heavy Works push | 0.84 / 0.76 / 0.82 / 0.83 / 0.84 | 0.84 / 0.78 / 0.89 / 0.98 / 1.05 | 31/32/32 -> 38/54/54 |
| Owl raids | 0.79 / 0.67 / 0.70 / 0.67 / 0.66 | 0.79 / 0.67 / 0.74 / 0.85 / 0.95 | 30/32/32 -> 32/53/54 |
| Clock Soldier rush | 0.81 / 0.70 / 0.74 / 0.73 / 0.76 | 0.81 / 0.73 / 0.82 / 0.92 / 1.01 | 30/32/32 -> 36/54/54 |
| Rush | 0.81 / 0.59 / 0.58 / 0.58 / 0.65 | 0.93 / 0.85 / 0.86 / 0.87 / 0.95 | 23/25/32 -> 32/41/44 |
| Timing attack | 0.85 / 0.86 / 0.85 / 0.81 / 0.80 | 0.95 / 0.94 / 1.09 / 1.13 / 1.18 | 32/32/32 -> 50/54/54 |
| mean of the 7 | 0.82 / 0.71 / 0.73 / 0.72 / 0.74 | 0.85 / 0.79 / 0.88 / 0.96 / 1.03 | |

**How to read the aggressive plans**: they trade economy for army ON PURPOSE in their opening (the Springer timing, the Owls,
the Clock Soldier rush: a second Clocktower late, few Winders until the attack has left), so their 5:00-8:00 share stays
low (0.67-0.85): that is the plan, not a mistake, and it is kept (the owner wants to train against each strategy). What
such a plan COULD reach is its own opening and then the economy played fully: before, they never caught up (0.65-0.84 at
15:00, the 32 cap); now they reach the bench by 12:00-15:00 (0.95-1.18). The Economy and Balanced plans beat the bench from
8:00 (more Clocktowers than its schedule: 4 at 10:00, 6 at 15:00).

**What it costs**: alone, at the 200 supply cap (from about 11:00 alone, with no losses), 54 Winders leave less room for the
army: army value at 15:00 about 10,000 against 11,500 before, with 5,000-12,000 cogs banked that the cap does not let it
spend. In the games the cap is rarely reached (armies die), and the army at 15:00 is BIGGER after (section 4).

## 4. The games

RESULTS_TABLE

## 5. What is left

- **The aggressive plans' lean openings** (0.67-0.85 of the bench at 5:00-8:00): their identity, kept.
- **The bank at the supply cap**: alone it reaches 200 supply at 11:00-13:00 and banks 5,000-12,000 cogs it cannot spend
  (no army room). Not an economy loss; a sink would be a rule question (below).
- **The escorts**: 2-12 Winders walk with the army to wind it (a Clockwork rule: constructs run down off their gear field);
  they are counted on top of the posts now. At home, resting, they could work a press between pushes: not done (the push
  logic is shared with the army jobs; a small gain, about 5% of the Winders' time).
- **Spent presses standing**: pulled down only when the press limit needs the place (AI._recycle_spent, shared), so 2-6
  stand late in the game; they cost nothing but their place, so left.
- **Against the Brood** the Clockwork still earns 0.6-0.8 of the bench by 15:00 in the games: its raids kill Winders and
  presses (legitimate: the opponent's play). Its third Clocktower comes at about 9:00 against the Brood (8:00 against the
  others), held by the threat checks of the shared expansion rule (AI._hall_first / _more_halls), which this job left alone.
- **Rule questions for the owner (proposed, NOT applied)**:
  1. A Cog Press on spent brass counts against "2 per Clocktower" until it is pulled down, like the Crown's Farms
     (economy_parity section 8.3): should a spent press free its place by itself? The computer pulls them down; a player who
     does not know to is capped.
  2. With the computers now working their economies, the Clockwork alone banks thousands at the 200 supply cap: is the cap
     the brake the owner wants, or should the late game have a cog sink (research, a costlier upkeep)? Only once the other
     two computers are coached (econ-coach-crown, econ-coach-brood), so the three can be compared.

## 6. Tests

Run with tools/study/econ_coach_cw_tests.sh (the 23 AI tests and the Clockwork's 20; each in its own process and user
folder): TESTS_SUMMARY

## Pictures

FILMS

## How to run it

- The computer alone: `godot --headless --fixed-fps 30 --script res://tools/econ_alone_cw.gd -- plan=optimal map=greenhold
  seed=1 minutes=15 [peace=1] [cwmacro:off] out=FILE.json`, or `tools/study/econ_alone_cw.sh OUT 2 "optimal economy" "greenhold
  hollowfen" 1 0 [cwmacro:off]`; the table: `python3 tools/study/econ_alone_cw_report.py DIR [DIR2 ...]`.
- The games: `python3 tools/study/econ_coach_cw_games.py OUT DATA --jobs 2 [--extra cwmacro:off]`; the table:
  `python3 tools/study/econ_coach_cw_report.py BEFORE_DATA AFTER_DATA`.
- The tests: `tools/study/econ_coach_cw_tests.sh OUT 2 [cwmacro:off]`.
