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

**In short.** Against the Clockwork the Crown computer now won or led 4 of 16 Hard OPTIMAL games (2 before), its army
at 8:00 is 1.09 of the Clockwork's (0.38) and it no longer pours gold into lost hall spots; against the Brood nothing
changed what matters: 0 of 16 won or led before and after, with every Crown plan (the Brood beats the Crown computer
whatever it plays: a balance question for the owner, section "Claude's choices"). No Crown army group was shut in its main
in the 40 games after (13 stuck units against the Clockwork before, 4 single ones after in 32 cross games). The natural's
palisade is closed 3-4 minutes after the hall stands (it was mostly open). Numbers at the end.

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
- A GREEDY Brood read in time: the riders, as before (the owner's rule). The Economy race was tried on half of those reads
  (RIDERS_V_BROOD 0.5, "out-expand it: its early ground is its usual opening") in the 32 OPTIMAL games below and did no
  better (0 of 9 won or led, the riders 0 of 7), so RIDERS_V_BROOD is 1.0 again (the knob stays for a study); too late
  for the riders: the Economy plan as before. Never the Siege push.
- A GREEDY Clockwork read: the riders RIDERS_V_CLOCK (15%, was 35%) when early, else GREEDY_CLOCK: the Timing attack 3,
  the Economy race 1, the balloons 1 (was Balanced, every time).
- A NORMAL read: against the Brood the Economy plan 3 or Balanced 1 (was Balanced 3, the Siege push 2, Timing 2: those
  lost every plan game); against the Clockwork the Timing attack 3, the Economy race 1, the balloons 1.
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
- a hall SITE that vanished counts as lost too (razed, or given up because raiders chased its builders off: Frostmere v
  the Clockwork, a site given up at 9:50 was laid again and lost at 13:35); only a site dropped because its ground stayed
  blocked is no loss;
- THE ARMY BEFORE THE NEXT HALL AFTER A LOSS: for LOST_HALL_WAIT after a loss, while the army is under LAG_SHARE (60%) of
  the enemy army it reckons (AICrown.foe_reckon, the Brood's foe_estimate), no hall is laid: the gold goes to the army
  (the same Frostmere game laid four sites on four spots in five minutes after its natural fell, and lost every one);
- the match log and the AI STORY say it ("lost a base: it keeps off that ground until it is clear of enemies").
Switch for comparison games: `-- lostwait:off`. Test: tools/test_crown_lost_hall.gd (the natural razed with Raptors by
it: the loss noted and told, no hall within 16 tiles for 120 s with gold to spare, a hall asked for there refused, the
last hall in a fight lays no expansion).

## 4. Crown units shut in their own main

**What was wrong.** Replayed the QA game base_hollowfen_crcw_r1 (seed 1189) to 7:00 and drew the main (a map dump of the
ground and every building): the ramp's wall is the ramp Cottage at (23, 11) and the Gate at (24, 13) with the cliff below
it; the production row (AICrownLayout: the Horse Breeder, a Barracks, the second Barracks at (19, 13)) ran up to x = 22, so
the cell in front of the Gate, (23, 13), had buildings on three sides and was reached only by a corner squeeze between the
second Barracks and the ramp Cottage. No path led out of the main: the army's attack-move ended at the nearest reachable
spot, the cliff edge at (22, 16), the very tile the QA study saw 8 Musketeers stand on from 9:50 to 12:40. Thornwood Maze's
main has the same shape (the ramp Cottage, a one-cell Gate, the production row running towards it), and its stuck tiles
(21, 15) and (14, 20) sit the same way inside it: most likely the same cause (its replay with the fix, below, kept the
way open; the runs are not deterministic, so a replay of the old code with the same seed did not always seal it either).

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
- past 22 labourers, one labourer at a time is trained (a second only from gold over WALL_LAB_KEEP 60);
- before wall_first the owner's plans keep the next labourer's gold from the wall (as his ring waited for his 26th);
- empty slots wait SLOT_WAIT (60 s) for the Cottage the supply needs or a production building of their size, and no
  Church is bought for one.
Switch: `-- wallfirst:off`.

Also: while the wall comes first it looks for gold every second (WALL_FIRST_LAY; every 4 s the labourers trained in between
took it), and AICrownHold holds a building standing in a wall slot from inside the wall like the palisade.

**Tests:** test_ai_expand_wall: 60-100% of the ways in shut 180 s after the stand and SEALED (no enemy walk into the core)
180-215 s after it on all three maps (before: 10-33%, never sealed), buildings stand in the wall; its MIN_SHUT is 0.5 now
(was 0.8: the opening's own steps keep their gold before the wall's; the sealing check is the aim). test_crown_owner_eco:
the closed ring by 6:30 passes (it failed on main) with 23 labourers at 4:00 (22 on main).


## 6. The AI STORY

- "holds the top of its ramp: the force below (484) is more than its army (820) can beat" read the wrong way round (205
  lines in the QA study, 47 at the natural's gate): the army goes down only with an edge over the force (AICrownHold._beat:
  1.3, 2.0 against the Brood). The line now gives the margin: "against the force below (484) its army (820) goes down only
  at 968"; the same for the natural's gate.
- "expands to fresh land: its best base has ONLY 92-100% left" (482 lines) was no reason: an expansion from a base with
  60% or more left now reads "expands while its base is still rich: more land, 23 tiles out".
- New: "lost a base: it keeps off that ground until it is clear of enemies"; OPTIMAL's new reasons ("out-expand it", "out-
  expand it: its early ground is its usual opening") in tools/i18n/55_ai_optimal.txt.
- Not changed (the other computers' lines, or left open): "riders" said of Raptors and Winders by the Brood and the
  Clockwork; the Crown's army reckoning ("puts its army first (A against the B it reckons)"), off by 1.5x or more 146
  times; a scout read that stays NORMAL while the base is being destroyed.

## 7. Tests (the final build)

| test | result |
|---|---|
| test_files | 1303 checks, 0 failures |
| test_i18n | PASS |
| test_ai_wall_vs_rush | ALL PASS |
| test_crown_ammo | 0 failures |
| test_crown_gate | PASS |
| test_build_shove | PASS |
| test_crown_stall | PASS (it failed once on the way: the Foundry 20 s late while the wall held its gold from the steps; the steps keep theirs now) |
| test_ai_optimal (updated) | ALL PASS: a greedy Clockwork answered in time (the Timing attack, the Economy race, the balloons or the riders), a greedy Brood with the riders 300 of 300 (AIOptimal.RIDERS_V_BROOD), never the riders against the Crown |
| test_ai_expand_wall (updated) | PASS: 60 / 94 / 75% shut 180 s after the stand, SEALED at 215 / 190 / 210 s (before: 23 / 11 / 18%, never sealed) |
| test_crown_owner_eco | ALL PASS: 22-23 labourers at 4:00, the natural's ring closed by 6:30 (it failed on main), the army at the natural's gate and not the cliff edge (the wall post's spots now end with it: that check failed in half the runs once the ring closed) |
| test_crown_lost_hall (new) | PASS |

## Claude's choices for the owner

1. **The riders against a greedy Brood stay** (your rule, "horse breeder to punish the greed"). The Brood roots its first
   Mound Turtle at 0:00 in every plan, so "a second base and little army" is its usual opening and the read says little;
   the riders picked on it won or led 0 of 36 QA games. I tried the Economy race on half of those reads: 0 of 9, no better
   (the riders 0 of 7 in the same games). In the plan games nothing won or led against the Brood either: the fixed Horseman
   rush held to 15:00 3 times of 4 (behind), the Economy plan kept its income even and lost 3 of 4. The Crown computer
   cannot beat the Hard Brood with any of its plans as the game stands; whether that is the Brood's numbers or the
   Crown's is a balance question for you (not touched here: "don't touch the game's numbers").
2. **Against the Clockwork the Timing attack first** (3 : Economy 1 : balloons 1, the riders 15% early): it won or led 3
   of 4 plan games, though a coached note of 0.29 says the one-hall Timing attack lost the economic race on Highmoor. It is
   a gamble: it wins or leads, or it falls far behind (half the Clockwork's income by 15:00).
3. **"Keep enough to rebuild once"** read as: with one hall left and enemies at it, no new expansion; after a loss, no new
   hall while the army is under 60% of the enemy's it reckons; never a hall within 16 tiles of a hall lost in the last
   240 s, nor with an armed enemy in sight by the spot. The gold is not banked as such: it goes to the army.
4. **The gate's way**: the two cells straight in front of a gate, on each open side, are kept free of the computer's
   buildings (1 cell wide). A wider berth (3 wide) would also stop a slot building of a walled natural from standing next
   to its gate; not needed in the games seen.
5. **The natural's wall's timing**: after 22 labourers (your 26th) or 100 s after the hall stood, whichever first; the
   test's 80% at 180 s became 50% (with sealing by 240 s, which it now does on all three maps).

## Open questions

- The Crown against the Brood (above). And the Crown's income per labourer is below the Clockwork's (game numbers).
- A Crown labourer was sent to (-1, 13), off the map (Red Coast v the Clockwork, 11:50: a flight or refuge point outside
  the map); not looked into.
- The QA report's other items for the Crown's story (the army reckoning, the stale NORMAL read).

## Numbers

### The plan games (every Crown plan against Hard OPTIMAL; data: docs/crown_ai_v2/plans/)

`python3 tools/study/crown_ai_v2_report.py --plans docs/crown_ai_v2/plans` (0.33.11 + the lost-hall memory; one game per plan
and map, sides alternating; "behind" / "led": a draw at 15:00 whose income + 2 x army is 10% apart):

| Crown plan | v OPTIMAL | games | results | won or led | income 5:00 | 8:00 | 10:00 | labourers 5:00 (Crown / foe) | halls 8:00 (Crown / foe) |
|---|---|---|---|---|---|---|---|---|---|
| balanced | brood | 3 | L L L | 0 | 0.56 | 0.46 | 0.47 | 16.7 / 35.7 | 1.3 / 3.7 |
| balloon | brood | 2 | L L | 0 | 0.63 | 0.53 | 0.50 | 15.5 / 32.5 | 2.0 / 3.5 |
| dragoon | brood | 2 | L L | 0 | 0.73 | 0.59 | 0.58 | 15.0 / 30.5 | 2.0 / 3.5 |
| economy | brood | 4 | behind L L L | 0 | 1.03 | 0.91 | 0.86 | 29.5 / 33.8 | 2.2 / 3.5 |
| rush | brood | 4 | behind behind L behind | 0 | 0.95 | 0.73 | 0.69 | 12.5 / 19.8 | 2.0 / 3.8 |
| siege | brood | 2 | L L | 0 | 0.68 | 0.64 | 0.56 | 16.0 / 35.0 | 2.0 / 3.5 |
| timing | brood | 2 | L L | 0 | 0.71 | 0.60 | 0.55 | 16.0 / 31.0 | 1.0 / 3.5 |
| balanced | clockwork | 4 | even behind W behind | 1 | 0.71 | 1.00 | 1.11 | 23.0 / 21.8 | 2.0 / 2.2 |
| balloon | clockwork | 3 | led L behind | 1 | 0.54 | 0.68 | 0.73 | 16.0 / 23.7 | 2.0 / 2.3 |
| dragoon | clockwork | 2 | behind L | 0 | 0.53 | 0.56 | 0.58 | 15.5 / 22.0 | 2.0 / 2.5 |
| economy | clockwork | 4 | behind behind behind W | 1 | 0.77 | 0.98 | 1.10 | 26.2 / 20.2 | 2.2 / 2.2 |
| rush | clockwork | 2 | behind L | 0 | 0.62 | 0.47 | 0.44 | 12.5 / 21.0 | 2.0 / 2.0 |
| siege | clockwork | 2 | even behind | 0 | 0.63 | 0.82 | 0.84 | 16.5 / 18.0 | 2.0 / 2.0 |
| timing | clockwork | 4 | led behind led W | 3 | 0.62 | 0.78 | 0.88 | 16.2 / 20.0 | 2.0 / 1.5 |

### Before and after: Crown OPTIMAL against Brood OPTIMAL and Clockwork OPTIMAL (and the mirror), Hard, to 15:00

8 maps (Greenhold, Highmoor, Dune Sea, Red Coast, Thornwood Maze, Hollowfen, Frostmere, Amberfall Vale), 2 seeds each
with the sides swapped (the mirror: one seed, the first-named = P1). BEFORE = the qa-matches base games on the same maps,
seeds and sides (0.33.7: the game is the same as 0.33.11 for these computers but for the QA fixes). AFTER = this branch at
dfbf7d01 (`python3 tools/study/crown_ai_v2.py run OUT --only measure1`; data: docs/crown_ai_v2/after/). The final build
differs from the measured one in four details made after it, each checked with its tests: a greedy Brood read gets the riders
every time again (the measured build gave half of them the Economy race: 0 of 9 won or led, the riders 0 of 7), the natural's
wall looks for gold every second while it comes first, a slot building of the natural's wall is held from inside the wall,
and the wall post's spots end with it. `python3 tools/study/crown_ai_v2_report.py docs/crown_ai_v2/after` (it reads the
"before" from docs/qa_2026_11_08_matches/data):


#### Before (qa-matches, 0.33.7): 40 games

| Crown v | games | W-D-L | won or led | income 5:00 | 8:00 | 10:00 | army 8:00 | halls 8:00 (Crown / foe) | Crown halls lost (built + sites) | same spot lost twice | Crown units stuck |
|---|---|---|---|---|---|---|---|---|---|---|---|
| brood | 16 | 0-5-11 | 0 | 0.90 | 0.66 | 0.62 | 0.91 | 1.9 / 3.4 | 38 | 1 | 0 |
| clockwork | 16 | 0-15-1 | 2 | 0.65 | 0.63 | 0.65 | 0.38 | 1.9 / 2.5 | 25 | 1 | 13 |
| crown | 8 | 1-7-0 | 2 | 0.98 | 1.07 | 1.11 | 0.98 | 1.9 / 2.0 | 14 | 0 | 3 |

#### After (crown-ai-v2): 40 games

| Crown v | games | W-D-L | won or led | income 5:00 | 8:00 | 10:00 | army 8:00 | halls 8:00 (Crown / foe) | Crown halls lost (built + sites) | same spot lost twice | Crown units stuck |
|---|---|---|---|---|---|---|---|---|---|---|---|
| brood | 16 | 0-3-13 | 0 | 0.88 | 0.72 | 0.66 | 0.52 | 1.9 / 3.4 | 38 | 0 | 1 |
| clockwork | 16 | 0-16-0 | 4 | 0.61 | 0.67 | 0.64 | 1.09 | 1.5 / 2.4 | 28 | 0 | 3 |
| crown | 8 | 0-8-0 | 3 | 0.93 | 0.99 | 1.01 | 1.34 | 2.0 / 2.0 | 13 | 0 | 0 |

"won or led" in the mirror is the P1 side's (a control: it should sit near half). Halls lost, built and sites apart:
against the Brood 32 built + 6 sites before, 36 + 2 after; against the Clockwork 19 + 6 before, 22 + 6 after. The same spot
lost twice in a game: 2 before, 0 after.

What OPTIMAL played at 5:00 in the after games: against the Clockwork the Timing attack 11 times (4 led or won, 7 behind),
the balloons 2 (1 even), the Horseman rush 2 and the Economy race 1 (behind); against the Brood the Economy race 9 (2
behind, 7 lost) and the Horseman rush 7 (1 behind, 6 lost; the rush hands over to Balanced when it fails).

Noise: the QA study found the same map and seed agree on the result about 2 times in 3, and the per-game income ratio at
8:00 has a standard deviation of 0.14-0.20; with 16 games a matchup, a difference of 2 won-or-led games is within it.
