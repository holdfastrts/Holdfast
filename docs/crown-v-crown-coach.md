# crown-v-crown-coach: the Crown mirror, coached and filmed

The owner (2026-11-11 22:35) asked for every matchup to be COACHED and FILMED "with the same level of scrutiny and
attention" as the Crown v Brood job. This is the Crown mirror: Hard Crown OPTIMAL against Hard Crown OPTIMAL. Coaching as a
human coach does it: film real games, watch them, name each mistake with its time and a picture, find the decision behind
it in the code, fix that decision, play the same seed again and look at the same moment.

Rules followed: docs/design_principles.md (1 fairness: a mirror must be decided by play, 2 anti-snowball: the defender's
advantage early that FADES so a winner can finish, 4 epic battles that carry the weight of the match) and the owner's Crown
rules in CLAUDE.md (Foundry before the 2nd Barracks, 3 Field Cannons before any Mortar, the walled natural with its gate
toward the ramp, the army at the gate, OPTIMAL picks by read). No unit, building or economy number was changed.

**Everything new is gated to the mirror** (the Crown computer facing a Crown, Normal and up: `AICrown.mirror()`), lives in a
new file, `scripts/ai_crown_mirror.gd` (class `AICrownMirror`), and is switched off with `-- mirror:off` for comparison
games. The shared code only calls in (section "Shared functions changed").

## Tools

- `tools/film_coach.gd` (new): `tools/qa_match.gd`'s measured match (result.json, story.txt, log.txt) plus
  - a MAP picture every 15 s (`map_MMSS.png`, 3 px a cell, works headless): high ground lighter, water blue, each side's
    buildings in its colour (walls and gates darker, sites dark), soldiers as bright dots (P1 light blue, P2 yellow), workers
    as small pale dots, each army's centre as a white ring;
  - a coach's line every 15 s (`coach.txt`): per side its plan, bank, labourers and what they do, army value and kinds,
    halls, the wave (its men, where, how spread out, the siege piece), the army's centre and its distance from both mains;
  - with `shots:1` under xvfb: camera pictures of each army every 30 s (`focus:MMSS-MMSS` every 5-15 s), each hall every
    2 minutes and the fights.
- `tools/study/crown_v_crown_report.py`: the measuring table of a batch.

## The "before": 16 games on main (0.33.16)

Hard OPTIMAL v Hard OPTIMAL, 8 maps (Greenhold, Highmoor, Dune Sea, Red Coast, Thornwood Maze, Hollowfen, Frostmere,
Kestrel Rise), the QA study's two seeds of each (docs/qa_2026_11_08_matches), to 15:00.

| batch | games | decided (P1-P2) | P1 won or led | decided by | median length decided | army 8:00 | 10:00 | income 8:00 | 10:00 | lead ratio army 10:00 (median) | halls lost / game | waves / game | pull-backs / game | dominant minutes -> enemy hall lost in 3 min |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| before | 16 | 2 (1-1) | 7 | 2 before 15:00 | 13:56 | 738 | 1249 | 5130 | 7944 | 1.52 | 1.2 | 2.6 | 1.2 | 61 -> 22 |

In short: **the mirror does not end** (14 of 16 draws). A side with an army 1.8 times the other's (and 800+) for a minute
saw an enemy hall fall in the next three minutes only 22 times in 61 such minutes. Every opening read was UNKNOWN (the
Crown walls its ramp at 0:22 and the scout sees nothing; OPTIMAL then plays the NORMAL table), so the picks were
Balanced, Dragoon raids, Economy and Timing about equally.

## Round 1: the 16 games of main, four of them filmed

Coach's notes (P1 = the first start spot; times are game time; "army" is the value of the soldiers):

- **Frostmere 1148** (P1 Dragoon raids v P2 Balanced, filmed). P1's economy runs ahead (38 v 18 labourers at 11:00) and its
  army is ahead from 4:00 (230 v 0) to 11:00 (1,625 v 1,370), yet it first goes out at 10:49, twenty seconds after P2's
  wave left. The two waves meet in the open at 11:05: **P1 comes in a column** (Dragoons and Horsemen first, the Musketeers
  strung out behind, spread 7 tiles), P2 in a formed line of 15 Musketeers with a gun. 1,625 falls to 540 against 1,550 in
  fifteen seconds; P2's wave walks on and takes P1's main hall at 14:09. Pictures: `r1_frostmere_1100_p1_column.jpg`
  (P1's wave leaving its natural), `r1_frostmere_1105_column_v_line.jpg` (the meeting).
  ![](shots/crown-v-crown-coach/r1_frostmere_1105_column_v_line.jpg)
- **Hollowfen 1154** (Dragoon raids v Dragoon raids, filmed). Nobody attacks for 11 minutes (both raid with Horsemen, both
  build 40 labourers on four halls). P1's first wave (16 men) is spread 9 tiles at 11:30 and **14 tiles at 11:45** when it
  meets P2's (spread 8): 1,665 to 1,010 in thirty seconds (`r1_hollowfen_1146_trickle.jpg`, `r1_hollowfen_1206_scattered.jpg`).
  P2's own waves are strung over 29-40 tiles from 12:45 (reinforcements walking alone) but P1 has nothing left to punish it.
- **Highmoor 1143** (P1 Economy v P2 Timing, filmed). P2's timing goes at 7:28 with 1,470 against 295 into **P1's walled
  natural, which sits under P1's main cliff**: the musket line on the high ground and a gun behind the palisade
  (`r1_highmoor_0812_natural_under_cliff.jpg`, `..._0833...`). It trades about even and kills no labourer (P1 47 v P2 23
  labourers at 8:00); P1's economy wins the game, but from 12:15 P1's own waves trickle along the road one man at a time
  into P2's cliff line (`r1_highmoor_maps_1130_1430.jpg`: the light blue dots strung across the map).
- **Thornwood Maze 1136** (P1 Balanced v P2 Economy, filmed) and **Greenhold 1140** (Balanced v Dragoon raids): **the
  Balanced plan's economy stops**. After its opening (Powder Mill at 3:20) its milestones put a Foundry, a second Powder
  Mill and a Horse Breeder in at 14-15 labourers; the Mills take the hands (the crew follows the powder bank alone), the
  Farms stand half empty and the gold stops: Thornwood 1,900 earned at 4:00 and at 5:00, Greenhold 2,280 from 5:00 to 7:00.
  No soldier is trained (the Barracks stood from 1:25) and a single enemy Horseman (the Dragoon plan's scout, 4:15) rides
  through the labourers for three minutes: Greenhold 16 -> 3 labourers, the game lost at 13:06 (9:20 in the replay).
  `r1_thornwood_maps_economy_stall.jpg`.
- **Greenhold 1103** (Timing v Dragoon raids): P1's Timing army is 2.4 times P2's at 7:00 (1,515 v 640). In one replay it
  goes at 6:48, walks to P2's walled natural and pulls back at 7:42 having lost 10 for 0; **in another replay OPTIMAL turned
  the Timing attack into the Economy race at 6:31** on a late greedy read ("too late to punish: out-expand it") and the army
  sat at home on one hall.
- **Red Coast 1164** (Balanced v Economy -> Siege push, filmed): the Siege push trades even at 9:10-10:31 and then **stays
  home for four minutes with 2,050-2,880 of army** because "an enemy force (465) is at our buildings" (P1's riders at the
  edge of its base).
- The rest (Dune Sea, Red Coast 1127, Kestrel Rise, Thornwood 1173, Hollowfen 1191): the same shapes. A side ahead
  sits at home until a GO rule fires (often "no attack for 300-500 s"); waves go strung out; the defender's natural under its
  cliff holds; and a side that wins the field takes minutes to break palisade after palisade (Frostmere 1148: 14 palisades
  broken one by one from 12:11 to 14:12, the natural's hall at 13:17, the main never reached).

The biggest mistakes, and the decision behind each:

| # | mistake | seen | the decision (file, function) |
|---|---|---|---|
| 1 | the wave meets the enemy strung out (a column against a line) and reinforcements walk alone | Frostmere 11:05, Hollowfen 11:45, Highmoor 12:15 | AI._army (attacking): each idle man of the wave is sent to the target on his own; nothing keeps the wave together |
| 2 | the Mills take the farm hands, the gold stops | Thornwood 4:00-5:00, Greenhold 5:00-7:00 | AICrown._mill_feedback: after the opening the crew follows the powder bank only |
| 3 | no soldier against a lone raider among the labourers | Greenhold 4:15-7:50 | nothing trains a soldier for a raid: the Balanced plan's gold goes to milestones and walls; the shared defence has no army to send |
| 4 | the Timing attack is turned into the Economy race just as it is ready | Greenhold 6:31 | AIOptimal._punish: after TOO_LATE a greedy read is "out-expand it" for every plan |
| 5 | the Siege push stays home for a small raid | Red Coast 11:00-15:00 | AICrownSiege._maybe_go: any force of 250+ at our buildings holds it, whatever the push is worth |
| 6 | a won field takes minutes to turn into halls (palisade after palisade) | Frostmere 12:11-14:12, Highmoor 12:39-14:30 | AI._siege_plan / _enemy_base: looked at in round 2 |

The fixes (all in `scripts/ai_crown_mirror.gd` unless said, all only in the mirror):

1. **The wave marches as one** (`AICrownMirror.cohesion`, called from `AI._army` through the new virtual `AI._cohesion`):
   while no enemy soldier is within 300 px of the wave and no siege is on, a wave whose BODY (the men within 12 tiles of
   the one with the most others near him) is spread over 5 tiles stops: the head waits where it is (riders stop in the
   saddle), the tail walks up to the middle; with an enemy army in sight ahead (worth a quarter of the wave) it forms up
   tighter (3 tiles) before it walks into musket range. It goes on together at 2.2 tiles apart, or after 14 s; the next
   regroup waits 18 s. Stragglers far behind are called up and not counted (the first version counted a man still at the
   gate: "goes on together (27 tiles apart)").
2. **The farms before the Mills** (`AICrownMirror.farms_starved`, from `AICrown._mill_feedback`): with 30 powder in the bank
   and a Farm short of half its crew, the Mills give a hand back to the farms (never below one a Mill).
3. **The raider gets an answer** (`AICrownMirror.raid_answer`, from `AICrown._think_stage` stage 2, before the plan's
   gold is set aside): an armed enemy within 300 px of a labourer, and our soldiers within 700 px of it worth less than
   1.5 times it: Musketeers into the Barracks queues first (up to 3 at a time).
4. **The Timing keeps its timing** (`AIOptimal._mirror_keep`): in the mirror a greedy read keeps the Timing attack.
5. **A raid does not hold the siege at home** (`AICrownMirror.threat_small`, from `AICrownSiege._maybe_go`): a force at our
   buildings worth under a quarter of the push is the guards' business; the push goes.

ROUND1_AFTER

ROUNDS

