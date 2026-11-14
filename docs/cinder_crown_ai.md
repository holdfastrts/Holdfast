# The Crown computer against the Clockwork, after the Cinder Steps watch (job cinder-crown-ai, 2026-11-13/14)

The owner watched a Hard Crown (OPTIMAL) against a Hard Clockwork (OPTIMAL) on Cinder Steps
(docs/playtests/2026-11-13_cinder_steps_notes.md, items 2 and 4): the Crown read the Clockwork as GREEDY at 1:21, picked
the Timing attack, stayed on one hall with about 20 labourers until 8:05, sent a 23-supply wave at 7:15 into a bigger
Clockwork, and ended with 7,845 earned against 31,217. This job changed **only how the Crown computer plays** (no unit,
building, price or rule number), in the Crown's own files (scripts/ai_crown.gd; the read in scripts/ai_scout.gd is gated
to a Crown scouting a Clockwork). Everything is off with `-- cinder:off`. Version 0.35.15.

## In short

1. **The GREEDY read at 1:21 was wrong for the Clockwork.** The Clockwork's normal opening (OPTIMAL's common opening:
   Winders non-stop, a second Clocktower at ~1:50) has no Light Works until ~2:00-2:10. "No army and no production" at
   1:21 is its standard opening, not greed. Now the Crown's scout reads an empty Clockwork base as GREEDY only from 2:30;
   before that it reads NORMAL ("a standard opening"). OPTIMAL's pick against the Clockwork is the same either way (the
   Timing attack 3, Economy 1, Balloons 1), but a GREEDY read also made the army hold 90% of the enemy's ("pressure") and
   sized the timing from what it saw.
2. **Why the Crown sat on one hall:** the Timing attack's opening against the Clockwork is the one-hall build ("bo": the
   two-hall version is off since crown-v-clockwork-coach round 6). Its labourers stop at 19, and its second hall comes
   only from the milestones after the opening ends, and the opening ended only when the wave went out or was called off
   45 s after the army reached 22 supply. On Cinder Steps the army reached 22 at ~6:20, the call-off came at 7:06, the
   hall at 7:38 (finished 8:05).
3. **Why the 7:15 wave went into a bigger army:** the call-off at 7:06 ended the opening, and the very next wave check
   ran the ordinary rule: the army against the enemy army *seen* lately (490, seen at 6:52) times 1.1. The Crown had
   1,325, so it went. The Clockwork really had ~1,085 of army at 7:00 and three halls; it had been ahead since 5:00.
4. **Why the economy never came back (item 4, the other side):** after 9:00 the Crown's army (500-840) was far behind
   the army it reckoned for the Clockwork (2,300-3,200). Its rule "the army first" stops the labourers while the army is
   under 60% of that, and round 6's exception (labourers while the army holds half) never applied. So the labourers
   stayed at 16-25 for the rest of the game, and more soldiers on that income could never catch up. The 385 gold at
   12:00 was the next hall's gold being saved (its natural had just fallen at 11:08; the next hall went down at 12:24).
5. **Changes:** the one-hall Timing opening lays its second hall behind the army (after the Horse Breeder, at 17
   labourers or by 4:30 at the latest) and trains labourers on to 30; its wave goes only while worth 1.15 times the
   Clockwork army it reckons (seen lately, never less than the coached games' lowest at that minute); the opening is
   over by 6:40 whatever; from 8:00 each hall keeps at least 12 labourers coming even when the army lags far behind.
6. **Result:** the Crown is on two halls at ~5:00-5:50 (was 6:43-8:05), has 28-35 labourers at 8:00 (was 20-25),
   earns more by 10:00 (Timing +14%, OPTIMAL +10%), and no longer throws its army away at 6:00-7:00 (army at 12:00 1,070
   against 442 on the Timing plan). **It still loses this matchup**: the Clockwork's army is bigger by 6:00 in the games looked at
   closely, and the Crown earns about half of what the Clockwork does by 12:00. The timing attack against
   this Clockwork is never ahead (8 of 9 called off). See "For the owner".

## 1. What was wrong, from the log

| time | what the Crown did | why |
|---|---|---|
| 1:21 | GREEDY [no army and no production at its base], picks Timing attack | the absence read counts from 0:55 for every faction; the Clockwork's Light Works comes ~2:00 |
| 1:41-3:40 | Mill, Farm, Musketeers, Foundry, Horse Breeder, Barracks 2 | the Timing build order (bo) |
| 4:00-7:00 | labourers 18 -> 20 | the plan's labourer cap is 19 until the opening ends |
| 6:52 | "scouts know an enemy army of 490" | what it had seen in the last two minutes |
| 7:06 | "the timing was called off: the enemy army it knows is bigger" | 45 s at the attack step without a wave (ATTACK_WAIT) |
| 7:15 | the first wave goes, 23 supply | the ordinary wave rule: 1,325 against 490 seen x 1.1 |
| 7:38 / 8:05 | the second hall laid / up | the milestones after the opening |
| 9:00-12:00 | labourers 22-25, then 16 | "the army first" (its army 720-840 against a reckoning of 2,300-3,200) |

The Clockwork in that game: 15 Winders at 3:00, two halls from ~2:00, 34 Winders and three halls by 7:00, army 560 at
5:00, 685 at 6:00, 1,085 at 7:00, 2,290 at 10:00.

## 2. What changed (scripts/ai_crown.gd, the "cinder-crown-ai" section; scripts/ai_scout.gd)

- **The read (CK-1, AIScout.GREEDY_ABSENT_CLOCK = 150 s):** a Crown's scout reads an empty Clockwork base as GREEDY only
  from 2:30. Before that it is NORMAL ("a standard opening"). A later look that still sees no production (2:30 on) reads
  GREEDY as before. The Crown's fixed Economy plan still races that economy opening (expand x0.3, as it did on the GREEDY
  read: its AI STORY line says "an economy opening, so its Economy plan races it").
- **The Timing attack's opening against the Clockwork, "bo_clock1" (CK-2):** the same one-hall build as before up to the
  Horse Breeder, then the **second hall** (at 17 labourers, or by 4:30 whatever the count: the labourers stall at 17-18
  behind the soldiers, so a step at 19 never came), the labourers on to 30, the second Barracks (by 5:00), then the
  attack step. A step may now carry "by" (game seconds): it is ready at that time whatever else it waits for.
  The two-hall opening of round 2-5 (`-- crcw:twohall`) is unchanged and still off.
- **The wave goes only while ahead (CK-3, `_ck_window`):** the Timing's first wave against the Clockwork goes only while
  the army sent is worth CK_EDGE = 1.15 times the Clockwork army it reckons (AICrown.foe_reckon: what it saw in the last
  two minutes, never less than LAG_TABLE, the lowest a Hard Clockwork had at that minute in the coached games, less half
  of what it has killed). While it waits the AI STORY says "the timing waits: X of army against the Y it reckons".
  Held 20 s at the attack step (was 45 s), the timing is called off; and at **6:40 (CK_LATE)** the opening is over
  whatever (if the second hall stands). After that the milestones and the doctrine play as before; the first wave still
  needs the edge.
- **The labourers never stop for good (CK-4, `_ck_floor_due`):** from 8:00, against the Clockwork, a built hall with land
  keeps training labourers while the Crown has fewer than 12 a hall (40 at most), even when "the army first" holds and
  the army is under half the reckoning (round 6's exception). Not while a rush is being defended. AI STORY: "keeps
  training labourers ... though its army is far behind the enemy's: more soldiers alone cannot catch up".
- Nothing else in the Crown's play changes, and nothing outside Crown v Clockwork: every rule above asks
  `cc_vs_clock()` (every enemy is the Clockwork) and the read asks for a Crown scouting a Clockwork.

## 3. The numbers

Hard v Hard, both computers, `tools/qa_match.gd`, the same 10 tags before and after (Cinder Steps x4, Greenhold,
Kestrel Rise, Highmoor, Frostmere, Hollowfen, Ashford Crossing; seeds 4400+, sides alternating on Cinder Steps). Before
= main 0.35.14. "Earned" = the Crown's gold earned so far (median); "ratio" = the Crown's earned over the Clockwork's
(median of the games); results at the end: W won, L lost (out), trail/lead = alive with the army behind/ahead.

**Crown OPTIMAL v Clockwork OPTIMAL, to 15:00 (10 games each)**

| | earned 5:00 / 8:00 / 10:00 / 12:00 | ratio 5 / 8 / 10 / 12 | labourers at 8:00 | Crown army 12:00 | results |
|---|---|---|---|---|---|
| before | 2,660 / 5,320 / 7,410 / 9,060 | 0.66 / 0.60 / 0.52 / 0.43 | 25.5 | 630 | 0 W, 6 trail, 4 L |
| after | 2,660 / 6,080 / 8,170 / 9,380 | 0.65 / 0.66 / 0.55 / 0.45 | 35 | 578 | 0 W, 1 lead, 4 trail, 5 L |

OPTIMAL's picks differ by run (it throws its dice): before Timing 4, Economy 4, Balloons 1, Rush 1; after Economy 5,
Balloons 3, Timing 2. With 10 games the results are within noise; the income from 8:00 is up.

**The Timing attack itself (Crown fixed on Timing v Clockwork OPTIMAL, to 12:00, 10 games each)**: this is the plan
the owner watched, and the one the changes are for.

| | earned 5 / 8 / 10 / 12 | ratio 5 / 8 / 10 / 12 | labourers 8:00 | second hall laid | first wave | army 8:00 / 12:00 | results |
|---|---|---|---|---|---|---|---|
| before | 2,280 / 5,130 / 6,650 / 8,550 | 0.54 / 0.53 / 0.43 / 0.38 | 20 | 6:09-6:47 | all 10 at 6:04-6:32, 14-18 supply | 1,210 / 443 | 10 trail |
| after | 2,280 / 5,320 / 7,600 / 9,060 | 0.55 / 0.53 / 0.49 / 0.41 | 28 | 4:32-5:27 | 8 of 9 called off at 6:40; later waves 8:56-10:38 | 1,183 / 1,070 | 10 trail |

In the four games looked at minute by minute the Clockwork's army was bigger than the Crown's by 6:00 (590-700 against
240-590) and at 7:00 (1,025-1,115 against 300-765), on 35-43 Winders against 18-26 labourers. The one-hall timing does
not get its window against this Clockwork; the fix makes it notice that and expand instead of walking in.

**The Economy plan (Crown fixed on Economy v Clockwork OPTIMAL, to 12:00; for the owner's question below)**, on the
same 6 tags (Cinder Steps x4, Greenhold, Kestrel Rise): before 7,030 earned at 8:00 and 12,670 at 12:00 (0.71 / 0.63 of
the Clockwork); after the read change alone 7,600 / 13,620; after the race kept (the final code) 6,840 / 12,480 (0.72 /
0.57): the same within noise. 41-44 labourers at 8:00, no game lost by 12:00 (26 games in all), but the army 650-830
against the Clockwork's ~4,600 at 12:00. On all 10 tags before: 0.78 of the Clockwork at 8:00, 0.67 at 12:00 (the Timing
attack: 0.53 and 0.38).

**Other matchups**: the changes cannot reach them (section 2). The AI and Crown tests below were run.

## 4. Tests

- New: `tools/test_cinder_crown.gd` (Cinder Steps, Crown Timing v Clockwork OPTIMAL): the opening's table, the second
  hall by 5:30 (here 5:21), 23+ labourers at 7:30 (27), the first wave only while ahead, the opening over by 6:55 (6:40),
  no GREEDY read of an empty Clockwork base before 2:30. ALL PASS.
- `tools/test_crcw_coach.gd` updated: the one-hall opening is "bo_clock1" now (`bo` with `-- cinder:off`). ALL PASS.
- All 40 `tools/test_ai_*.gd`, `tools/test_crown_*.gd` and test_crcw_coach were run on the branch. Failing, and failing the same on
  main 0.35.14 (or in the known flaky list): test_ai_harass [raid] (Crown v Brood: a rider 35-55 px nearer home, fails on
  main too), test_crown_mirror "a Musketeer is queued for the raider (12.0 s)" (fails on main too), test_ai_rush and
  test_ai_rush_followup (Crown v Brood, known), test_crown_dragoon_raid [plan] (known). test_spectator's army panel check
  failed once and passed on the next run (flaky). test_ai_scout, test_ai_optimal, test_i18n: ALL PASS.

How to run: `godot --headless --fixed-fps 30 --script res://tools/qa_match.gd -- map:cinder_steps seed:4412 end:900
out:DIR slots:crown/optimal/0,clockwork/optimal/1` (`crown/timing/0` for the plan alone; `cinder:off` as before).

## 5. For the owner

1. **The Timing attack is no answer to this Clockwork any more.** crown-ai-v2 measured it winning or leading 3 of 4
   against Hard Clockwork OPTIMAL (0.33.14); since econ-coach-clockwork (0.34.1) the Clockwork reaches 35-54 Winders by
   8:00 and its army is bigger than the one-hall Crown's by 6:00 in the games looked at closely. Now the plan notices and expands
   at ~5:00, but OPTIMAL still picks it 3 times in 5 against the Clockwork (NORMAL and GREEDY alike). The Economy plan
   keeps 0.75-0.78 of the Clockwork's income at 8:00 (Timing 0.53) and lost no game by 12:00 here, though it trails in
   army. Should OPTIMAL pick Economy more against the Clockwork? That is the question of the queued study
   crown-v-cw-plan-study ("decide on data"); this job did not change the picks.
2. **Is the Clockwork's economy opening "greedy"?** I read it as its standard opening (NORMAL) before 2:30, because
   every Clockwork OPTIMAL opens that way. If you see it as greed by nature (it is the Clockwork's economy-first
   identity), the read can go back to 0:55 with `GREEDY_ABSENT_CLOCK = 55`; the pick is the same either way.
3. **The Crown earns about half the Clockwork by 12:00 in every plan but Economy.** The computers' play is now close to
   what each plan earns alone (econ-coach-crown); what remains is the matchup's balance (docs/economy_parity.md, the
   Clockwork and Brood nerfs waiting on the branch). Claude's view: no AI change will close a 2:1 income gap at 12:00.
4. **Halls laid into the enemy's army.** In the watched game the Crown laid halls at 9:59 and 10:27 while 800-2,000 of
   Clockwork stood below its ramp, and lost them in 40-60 s (400 gold each). AIRound5.hold_hall stops a hall while the army
   is small, but not once the main's soil is under its "dry" mark. Not changed here: should a dry Crown save its gold for
   soldiers rather than lay a hall the enemy is standing on?
5. **Claude's choices in this job** (say if wrong): the hall at 17 labourers or 4:30; the wave's edge 1.15 times the
   reckoning; the call-off after 20 s at the attack step and the end of the opening at 6:40; the floor of 12 labourers a
   hall from 8:00.
