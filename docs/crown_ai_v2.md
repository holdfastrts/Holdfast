# crown-ai-v2: the Crown computer, the weak side everywhere (0.33.12)

The owner approved (2026-11-11) the QA study's top item (docs/qa_2026_11_08_matches.md "What to fix first" 1, 3, 4;
docs/qa_2026_11_08_tests.md items 4 and 13): Hard v Hard on 19 maps the Crown computer won 1 of 76 cross games; against
the Brood 0-13-25 and it never led; against the Clockwork it led 4 of 38; it earned 0.65-0.68 of its opponent's income at
5:00-8:00 and held 1.9 halls at 8:00 against 3.4 (Brood) and 2.4 (Clockwork); OPTIMAL picked Balanced in 67 of 76 cross
sides and those won or led 2 of 67.

This job owns the Crown computer only (scripts/ai_crown*.gd, ai_optimal.gd's Crown parts, the Crown expansion wall); the
shared changes are small and guarded by faction. Design rules followed (docs/design_principles.md): 1 fairness (a side
that cannot win against anyone), 2 anti-snowball (a lost base must not become a lost game; defender's advantage early),
3 meaningful base building (walls and gates that work), 4 the economy-first play the owner showed.

(sections below: written as the work went; the numbers at the end)

## 1. What OPTIMAL picks for the Crown in the cross matchups

**What was wrong.** OPTIMAL's Crown reads its opponent at ~1:40 and picks a build (scripts/ai_optimal.gd). In the QA games
the read was GREEDY in 73 of 76 cross games: against the Brood "a second base and little army" (35 of 38: the Brood roots a
Mound Turtle on new ground at 0:00 in every one of its plans, so this is its standard opening as much as greed), against
the Clockwork "no army and no production at its base" (38 of 38: the Clockwork opens on its economy). The answers were the
Horseman rush against the Brood (every time before BREEDER_BY) and Balanced (65%) or the Horseman rush (35%) against the
Clockwork; a failed rush hands over to Balanced. Result: Balanced at 5:00 in 67 of 76 sides, won or led 2.

**Measured.** Every Crown plan against Hard Brood OPTIMAL and Hard Clockwork OPTIMAL (`python3 tools/study/crown_ai_v2.py
run OUT --only plans:...` then `pick:...`; the Crown on its fixed plan, sides alternating, 15:00), on Border March, Ashford
Crossing, Kestrel Rise and Glimmerdeep (the table: section "Numbers"). Against the Brood no plan won or led (the Brood
beats every Crown plan, as it beats the Clockwork in the QA study); only the Economy plan (the owner's own opening) kept its
income even with the Brood's (1.01 at 5:00, 0.91 at 8:00), and the Horseman rush (the fixed plan, riders out by ~3:00)
held to 15:00 every time, behind; Balanced, Timing, the Siege push, the Dragoon raids and the balloons lost every game.
Against the Clockwork the Economy plan's income passed the Clockwork's by 8:00 (1.07, 1.21 at 10:00) and won once;
the Timing attack won or led 2 of 3; the balloons led their one game; Balanced was even once and behind twice.

**What changed** (scripts/ai_optimal.gd, the Crown's rows only):
- A GREEDY Brood read in time: the riders (the owner's rule: the Horseman rush is good against the Brood) RIDERS_V_BROOD
  (35%) of the time, else the Economy plan ("out-expand it: its early ground is its usual opening"); too late for the
  riders: the Economy plan as before. Never the Siege push.
- A GREEDY Clockwork read: the riders RIDERS_V_CLOCK (25%, was 35%) when early, else a weighted pick of the plans that
  won or led (see the weights in `_punish`): the Economy race first.
- A NORMAL read: against the Brood the Economy plan (3) or Balanced (1); against the Clockwork see NORMAL in the code.
  The mirror is unchanged (the Economy plan already leads it there; the Horseman rush never against the Crown).
- AGGRESSIVE (a rush seen) is defended as before; DEFENSIVE out-expands then sieges as before.
- The new "why" phrases are in tools/i18n/55_ai_optimal.txt (pt, es).

## 2. The Crown's economy

**Why it earned 0.65 of the others' income by 5:00.** In the QA games the Crown was neither supply-blocked (23 of 45 supply
used at 5:00 against the Clockwork) nor banking (31-100 gold at 5:00): it spent everything, on the wrong things for the
matchup. Its labourers: 10 at 3:00 and 15-18 at 5:00 against 15-17 and 23 for its opponents, while the owner's own Economy
game had 17 at 3:00 and 30 at 5:00 (docs/crown_owner_eco.md). The picks (section 1) put it on the riders' opening (the
Barracks at 7 labourers and the Horse Breeder, the labourers held at 12 till the riders were out) or on Balanced's
(Musketeers from the second hall), not on the owner's economy. The hall: 1.4 at 5:00 against the Brood. Per labourer the
Crown also earns less than the Clockwork (5,100 gold by 8:00 on 26 labourers against 8,300 on 28): the game's numbers,
not this job's.

**What changed:** the picks (section 1: the Economy plan's labourers at 5:00 were 27-29 in the plan games against 13-17 for
the other plans); the natural's wall no longer double-counts the opening's step gold (section 5); a lost base no longer eats
the last gold (section 3).

## 3. No hall into the enemy that just took one (anti-snowball)

**What was wrong.** The shared AI remembers a lost hall's spot only for the Clockwork (AI._note_lost_halls runs in gear
mode only); the Crown had no such memory, and several hall paths (the opening's, AICrown's site pick, the shared
_more_halls' ground round a hall, the natural's own spot) placed halls without one. A beaten Crown laid its next hall on the
spot it had just lost, 7 times in the QA games (60 sites lost), and once more in a plan game of this job (Border March:
built hall lost 13:25, sites on the same cell lost 13:55 and 14:25).

**What changed** (scripts/ai_crown.gd, "NO HALL INTO THE ENEMY THAT JUST TOOK ONE"):
- every hall of the Crown that disappears, built or a site razed with an enemy by it (a site it dropped itself is not a
  loss), is noted with AI.note_lost_site: the spot waits LOST_HALL_WAIT (240 s) and the ground round it counts as the
  enemy's for the shared pick; the Crown's own pick (CrownSites) leaves anything within LOST_NEAR (16 tiles) of it while it
  waits;
- AICrown._construct, where every hall path ends, refuses a hall on that ground, with an armed enemy in sight within 14
  tiles of the spot, or while its last hall is in a fight (REBUILD ONCE: with one hall left and enemies at it, no new
  expansion is laid: the gold stays for the main if it falls);
- the match log and the AI STORY say it ("lost a base: it keeps off that ground until it is clear of enemies").
Switch for comparison games: `-- lostwait:off`. Test: tools/test_crown_lost_hall.gd.

## 4. Crown units shut in their own main

**What was wrong.** Replayed the QA game base_hollowfen_crcw_r1 (seed 1189) to 7:00 and drew the main (a map dump of the
ground and every building): the ramp's wall is the ramp Cottage at (23, 11) and the Gate at (24, 13) with the cliff below
it; the production row (AICrownLayout: the Horse Breeder, a Barracks, the second Barracks at (19, 13)) ran up to x = 22, so
the cell in front of the Gate, (23, 13), had buildings on three sides and was reached only by a corner squeeze between the
second Barracks and the ramp Cottage. No path led out of the main: the army's attack-move ended at the nearest reachable
spot, the cliff edge at (22, 16), the very tile the QA study saw 8 Musketeers stand on from 9:50 to 12:40. Thornwood Maze's
main has the same shape (ramp Cottage, a one-cell Gate, the production row towards it): its stuck tiles (21, 15) and (14,
20) are the same story. (The runs are not deterministic: replays with the same seed did not always seal it.)

**What changed** (scripts/game.gd, `_blocks_own_gate`, only for the computer's (`ai`) placements of Crown buildings): a
building (not palisade or a gate) never covers the two cells straight in front of a gate of its own side, on either side
where the gate opens onto open ground ("Keep the gate clear."). With it, Thornwood Maze's production row stops at x = 17
and the way to the Gate stays open. tools/qa_match.gd now writes the ground round a stuck unit (21 x 21 cells, its path)
into its event, so a stuck group can be read from the data.

## 5. The late natural wall

**What was wrong** (test_ai_expand_wall: 10-33% of the ways in shut 180 s after the hall stood, never sealed by 240 s;
test_crown_owner_eco's ring by 6:30 failed): the palisade was planned at once and then lost every coin. In the opening the
wall's keep counted the build order's step gold twice (it is already out of reach in the think stage the wall is laid in:
a 400-gold hall step kept 860 gold from every piece), the shared "a Musketeer's gold first" keep came on top, the next
labourer always got the gold before the next piece (gold 0-30 from 4:00 to 7:30 while the labourers went 14 -> 34), a
Church was bought for an empty wall slot at 4:30, and the gold left after the soldiers and the steps never reached the
Gate's 50.

**What changed** (scripts/ai_crown.gd "THE NATURAL'S WALL ON TIME", scripts/ai_expand_wall.gd): on the owner's plans, once
22 labourers work (the owner's ring went down after his 26th) or 100 s after the walled hall stood, while its plan has
pieces to lay and nothing more urgent stands (a rush defended, the army far behind: AICrown.wall_first):
- the pieces are laid from any gold over the opening's step (no Musketeer keep, no double count) and the hall's first Farm;
- the gold for the next pieces is kept from the soldiers, the research and the steps in the other think stages;
- one labourer at a time is trained (a second only from gold over WALL_LAB_KEEP 60);
- empty slots wait SLOT_WAIT (60 s) for the Cottage the supply needs or a production building of their size, and no
  Church is bought for one.
Switch: `-- wallfirst:off`.

