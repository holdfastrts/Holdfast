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
