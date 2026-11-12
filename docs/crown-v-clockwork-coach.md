# crown-v-clockwork-coach: Crown v Clockwork, coached and filmed

**In short.** Six coaching rounds on five maps (films of every 30 s of each main and army, the match logs, the AI STORY),
then 16 measuring games before and after. Named and fixed, each gated by the matchup: for the Crown, the wave that walked
home from a won fight for one raider (it stays out now), horses that went to riders while the Foundry waited (the guns
first: the first Field Cannon at 4:30-8:40 instead of 13:25), a rush read that bought tech with no army (soldiers first),
an idle line above a natural under attack (the cliff edge until the gate post), labourers that "the army first" stopped
for good (the Farms first while the army holds half); for the Clockwork, a reckoning of the Crown's army at half its
size (first pushes of 8 Clock Soldiers into musket lines) and a bank that slept in the written builds (1,186 cogs at
5:00). A two-hall Timing for the Crown was built, measured and turned off (0 of 6 won or led). Result: the Clockwork now
decides 12 of 16 games (7 before) and wins 10 (6); the Crown won or led 2 of 16 before and after, its first attacks kill
more, but its income is still 0.65 of the Clockwork's at 8:00, and that, with the per-worker yield (a balance question
for the owner, below), is what decides this matchup.

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
| scripts/ai_crown.gd | `_mid_tick` | `if _cc_rush_hold(k, army) or _cc_tech_hold(k): continue` after the lagging check |
| scripts/ai_crown.gd | `_army_due` | `if _cc_labs_due(): short = false` after "the army first" |
| scripts/ai_crown.gd | `owner_walls` | true also for `_cc_walls()` |
| scripts/ai_crown.gd | `wall_first` | `owner_on()` -> `(owner_on() or _cc_walls())` |
| scripts/ai_crown.gd | `_riders_wait` | `or _cc_guns_first()` |
| scripts/ai_crown_hold.gd | `_in_walled_natural` | `closed_share(p) <= 0.0` -> `<= _cc_edge_floor()` (0.0 unless against the Clockwork) |
| scripts/ai_clockwork.gd | `_bo_tick` | `_cc_bank()` after `_train_workers()` |
| scripts/ai_cw_army.gd | TABLES | the "crown" row only (read only when the Clockwork reckons a Crown) |

Tools: tools/shot_ai_match.gd gained `pa:`/`pb:` (the plans; the default stays "balanced") and `every:N`;
tools/study/crcw_coach.py and crcw_coach_report.py are new; tools/test_crcw_coach.gd is the matchup's test.

## Round 6: the measuring batch says no to the two-hall Timing; the Farms before "the army first"

The first measuring batch with rounds 2-5 (6 of the 16 games played before it was stopped, "after A", data
docs/crown-v-clockwork-coach/data/afterA/): the Crown won or led 0 of 6 (before: 2 of the same 6), its income 0.57 of
the Clockwork's at 8:00 and 10:00 (before 0.66 / 0.63 on all 16), its army at 8:00 437 (before 1,056) against 1,740.
The two halls paid from 10:00 on (Greenhold 14,820 against 9,760 at 14:00) but the window from 5:00 to 8:00, with an
army of 240-480, was where the games were lost: the Clockwork's first push comes at 5:40-6:15 with 560-1,245 and took the
natural (Kestrel Rise, Frostmere: "lost" where the one-hall Timing had led). A coach's verdict: the timing is the
Crown's strength in this matchup (its one-hall army of 1,300-1,900 at 8:00 wins the first big fight in most games); what
loses afterwards is the economy behind it. So:

- **CR-1 is off by default** (`-- crcw:twohall` plays it, for a study): the Timing attack opens on one hall as before.
- **CR-1' THE FARMS BEFORE "THE ARMY FIRST"** (`AICrown._cc_labs_due`, asked by `_army_due`): against the Clockwork,
  "the army first" (army_lags: 60% of the enemy army it reckons, 90% after a GREEDY read answered by an attacking plan)
  stopped the labourers for good, because the Clockwork's army grows faster than a one-hall Crown's: 18-19 labourers from
  5:00 to 8:00 and 19-22 at 10:00, the natural's soil at 100% to the end. Now, while the labourers are fewer than 16 a
  built hall with land (40 at most) and the army is worth half the reckoning or more, the halls keep training labourers.
- **... AND THE FARMS BEFORE THE TECH** (`_cc_tech_hold`, from `_mid_tick`): the Armoury and the Church wait while the halls
  lack those labourers (the replay bought the Armoury at 8:09 with 21 labourers and the Church at 9:22 while the main's
  soil ran out and the natural stood unworked).
- CR-3, CR-4, CR-5 and CR-6 stay (each matters with one hall too: the wave stays out, the cliff edge until the gate post,
  the guns get the horses, soldiers when a rush is read).

## What is still wrong

- **The Crown earns less per labourer than the Clockwork per Winder, and the gap grows** (the 16 "before" games, gold or
  cogs earned per worker per minute, medians): 8:00 Crown 45 / Clockwork 54; 10:00 34 / 57; 12:00 31 / 51. The Crown's
  soil runs down (a main is spent at 9-10 minutes), its labourers run from raids and haul, and a Farm needs 8 hands; the
  Clockwork's Winders keep their pace on fresh brass. The computers' play cannot close that alone: see "Claude's choices".
- **The Crown's waves into the Clockwork's base trade badly** (Hollowfen 9:45 after round 5: 20 lost for 3; Greenhold
  10:27: about 20 lost): the wave is an attack-move of each unit to the target, the guns and the wagon trail behind, and it
  walks into the gear field where the Winders mend and the Netters net. Defending, the Crown's line wins (Kestrel 7:26:
  26 Clock Soldiers for 7). A Crown march like the Clockwork's push (an anchor, the line formed, the guns set up behind it,
  a halt out of reach of the gear field) is the next job; it was not started here (a new module, not a small fix).
- **The Clockwork's whole army meets an equal raid of muskets and guns on open ground** (Kestrel 7:26, 797 against 804:
  26 lost for 7). Its rule (AICwArmy._defend: the whole army goes unless worth less than 0.55 of the raid, and only far
  from its gathering point) does not weigh a musket line with canister against Clock Soldiers. Not changed: a stricter
  rule lets the Crown's line shoot the Clocktower down unanswered; the right answer (pull back out of reach to the main,
  come back with the Ballistas) is the push's own logic, not the defence's.
- **The Crown's horses and powder.** With the guns first the Field Cannon comes at 7:30-8:40 (was 13:25 in one game), but
  the powder bank sits at 13-30 in the fights after 9:00 (one Powder Mill to 10:00-12:00), so guns and Musketeers wait
  for powder (AI._produce skips the Foundry under 20 powder).
- **Kestrel Rise**: the natural under the main's ramp falls to the Clockwork's first push in most runs, two halls or one.

## The numbers: 16 measuring games, before and after

Hard Crown OPTIMAL v Hard Clockwork OPTIMAL, to 15:00, 8 maps (Greenhold, Dune Sea, Hollowfen, Kestrel Rise, Ashford
Crossing, Red Coast, Frostmere, Border March), the qa-matches base seeds of rounds 0 and 1 (each map played from both
start slots). Before: main at 0.33.16 (this job's start). After: this branch's final code (rounds 1-6, the two-hall
Timing off). `python3 tools/study/crcw_coach_report.py docs/crown-v-clockwork-coach/data/before
docs/crown-v-clockwork-coach/data/after` and `tools/study/crcw_coach_sides.py` the same. "Won or led": won, or ahead at
15:00 by income earned + 2 x army value by 10%. No script errors in any of the 32 games.

| | before | after |
|---|---|---|
| Crown W-D-L (won or led) | 1-9-6 (2) | 2-4-10 (2) |
| games decided (mean length) | 7 (12:46) | 12 (12:59) |
| income Crown / Clockwork, 8:00 / 10:00 | 0.66 / 0.63 | 0.65 / 0.61 |
| army 8:00, Crown / Clockwork | 1,056 / 1,569 | 965 / 1,396 |
| army 10:00, Crown / Clockwork | 852 / 2,505 | 635 / 2,441 |
| halls at 8:00, Crown / Clockwork | 1.4 / 2.6 | 1.7 / 2.6 |
| halls lost, Crown / Clockwork | 36 / 13 | 33 / 7 |
| the Crown's first attacks (12 each) | 106 lost for 218 killed | 111 lost for 261 killed |
| the Clockwork's first attacks | 104 lost for 54 killed (15) | 91 lost for 60 killed (16) |
| the Clockwork's bank at 5:00, median (most) | 146 (1,177) | 111 (736) |
| Crown labourers at 8:00 / 10:00 (medians) | 19.5 / 21.5 | 20.5 / 22.5 |

Per game (before -> after): Ashford Crossing D -> L and D -> D; Border March D -> D and L -> L; Dune Sea W -> W and
D -> L; Frostmere L -> L and D (Crown ahead) -> W; Greenhold D -> L and L -> L; Hollowfen D -> D and L -> L; Kestrel
Rise L -> L and D -> D; Red Coast L -> L and D -> L.

**What it says.** Both computers play this matchup better in the ways that were coached, and the Clockwork's gains are
the bigger ones: it finishes 12 of 16 games instead of 7 (10 wins instead of 6), loses half as many halls (7 against
13), its first pushes lose less, and its bank no longer sleeps. The Crown's first attacks kill a fifth more (261 against
218) and its guns come early (the round 5-6 films: the first Field Cannon at 4:32-8:40 instead of 13:25), its waves
stay out, but its economy is where it was (0.65 of the Clockwork's income at 8:00) and that is what loses its games. The
Crown computer still won or led only 2 of 16; the matchup is now decided more often, in the Clockwork's favour.

The one-hall Timing against the two-hall try ("after A", 6 games of the 16, in docs/crown-v-clockwork-coach/data/afterA):
0 of 6 won or led, income 0.57, army at 8:00 437.

## The tests

Run on the final code (`godot --headless --fixed-fps 30 --script res://tools/X.gd`): test_crcw_coach (new: 12 of 13,
see below), test_ai_optimal (35 of 35; its "army keeps up against a greedy Clockwork" check failed with the two-hall
Timing, 460 of army at 8:00, and passes with the final code, 1,865), test_ai_wall_vs_rush, test_crown_hold,
test_ai_round6, test_crown_lost_hall, test_clockwork_home, test_crown_owner_eco, test_clockwork_builds_b,
test_ai_crown_bank, test_crown_stall, test_clockwork_army, test_cw_army: all pass.

Two Crown-v-Brood tests fail on this branch (twice each) and pass on main, and the failure is NOT this job's logic:
test_crown_build_order ([rush] the first attack at 196 s with 2 Horsemen, wants 3) and test_ai_expand_wall (Kestrel Rise
40% of the ways in shut at 180 s, wants 50%; in the second run also Cinder Steps 48%); test_ai_harass (its Tyrant Sire
check, Crown v Brood) failed in one of two runs here. Bisected with a worktree
of main plus single files: main + ai_crown.gd + ai.gd passes, adding ai_crown_hold.gd fails, and with a print in
`_cc_edge_floor` the function is **never called** in that test (0 calls); replacing the never-run call by the literal
`0.0` makes the test pass again. The outcome of these games depends on the scripts' layout (most likely the order of
object ids in dictionaries keyed by units and buildings), not on any rule that runs against the Brood: every new rule
here returns at once unless every enemy is the Clockwork (or, for the Clockwork, the Crown). The same flips are to be
expected from any change to these files; they are reported here for the owner, not "fixed" by tuning the Brood games.
test_clockwork_springer_timing ("the Springers leap up onto the enemy main by 6:30") failed once of two on this branch
(it plays the Clockwork against the Crown, so CW-1 and CW-2 do apply there).

test_crcw_coach's one failure: "a natural standing by 7:00 is worked" (the natural stood at 8:05 in that run and was not
worked by 10:00): the one-hall Timing's natural comes late and its Farms wait for labourers and gold (see "Still wrong").

## Claude's choices for the owner to confirm

1. **The two-hall Timing is off** (kept as `-- crcw:twohall`): it gave the Crown its economy from 10:00 on but lost the
   window from 5:00 to 8:00 to the Clockwork's first push (0 of 6 won or led). The Crown's timing on one hall is its best
   card in this matchup today.
2. **The Clockwork was coached too**, and it now beats the Crown computer more often (10 wins of 16 against 6). Its two
   fixes are corrections of plain mistakes (an army reckoned at half its size, a bank of 1,186 cogs with one Springer);
   I kept them although they make this matchup harder for the Crown. Say if the Crown's side should come first instead.
3. **A balance question, not applied** (the job does not change numbers): per worker the Crown earns less than the
   Clockwork, and the gap grows as its soil tires (8:00 45 against 54 a minute; 10:00 34 against 57; 12:00 31 against
   51, the 16 "before" games). With the computers playing their best builds the Crown computer is behind 0.6-0.66 in
   income in every game. Proposals to weigh: a Crown Farm's yield on tired soil (the "tired land pays a third" curve)
   or its 8 hands, or the Clockwork's press yield against the Crown only after the owner's own games agree.
4. **The wave stays out** for a raid at home worth under 40% of the wave and under 500; a hall under half health still
   calls it home. The numbers are my pick.
5. **The guns get the horses** until 3 Field Cannons are out or queued (the owner's CANNONS_FIRST), one rider for the
   scouting always allowed.
6. **The Clockwork's reckoning of a Crown** is now the lower quartile of 16 games' Crown armies; if the Crown computer
   changes a lot (the other coaching jobs), this row should be measured again.

## Pictures (docs/shots/crown-v-clockwork-coach/)

- `r1_kestrel_wave_goes_home.gif`: Kestrel Rise before, 7:02-9:02 every 30 s: the Crown's wave at the Clockwork's new
  Clocktower, then back home with the Clockwork's army at 350.
- `ba_kestrel_wave_after_the_clocktower.jpg`: the same seed, before (8:32, home) and after (8:02, still out with three
  Field Cannons and the wagon; the Clocktower fell at 7:50).
- `ba_kestrel_natural_defence.jpg`: round 4 (the natural burns, the line idle in the Farm above) and round 5 (the line at
  the cliff edge from 6:01; the natural still fell, at 7:12).
- `ba_greenhold_0632_crown_main.jpg`: Greenhold 6:32 before (one hall) and with the two-hall Timing (turned off later).
- Round 1 stills: `r1_greenhold_0706_waves_meet.jpg`, `r1_hollowfen_0650_column_meets_push.jpg` (the Crown's strung-out
  waves), `r1_kestrel_0628_cw_push_under_muskets.jpg` (the Clockwork's too-small first push at the Crown's ramp),
  `r1_kestrel_0720_cw_army_shot_on_its_gears.jpg`, `r1_dune_0502_cw_bank_1186.jpg`,
  `r1_greenhold_sw_0532_crown_tech_no_army.jpg` (the rush read buying tech, Farms at 2 of 8 hands),
  `r1_kestrel_0802_...` and `r1_kestrel_0832_...`, `r4_kestrel_0654_natural_burns_line_idle.jpg`.

The films themselves (about 100 stills a game) were not kept in the repository; `/tmp/cc/bin/film.sh`'s command is
`xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_ai_match.gd
-- a:crown b:clockwork pa:optimal pb:optimal map:kestrel_rise seed:1131 swap:0 out:/abs/dir end:900 every:30`.

## The AI STORY

New narrator rows (scripts/ai_story_lines.gd, pt/es in tools/i18n/61_crcw_coach.txt): the Crown's wave staying out (for
scouts, or a raid left to the soldiers at home), the Farms first, a milestone held back by a rush read, and the
Clockwork's idle cogs put into Clock Soldiers. The rows were checked against real log lines (AIStoryLines.match_line).
