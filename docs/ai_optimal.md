# The computer reads its scout, every plan adapts, and OPTIMAL (branch ai-optimal, 0.32.0)

The owner (2026-11-05 09:34 and 09:54):

> "Do an AI storyteller check. Sometimes it says something that makes no sense, and maybe that is because the actual AI
> game logic is stupid. For example: 'It couldn't spot anything, it will check later'. That is correct, but the absence
> of army or buildings is already information. It tells you that the enemy is greedy, and now the AI should have a
> choice: rush or economy."

> "Every plan needs to be adaptive to some point. [...] specific plans and strategies the AI defaults to, so we can train
> against them or watch them. But we need a plan, OPTIMAL [...], where the AI has access to all the build orders [...]
> and does what is necessary at that moment."

What was done, in four parts:

1. **A story audit** (section 1): every line the three computers can tell, checked against what the computer knew and did,
   in the code and in AI-v-AI games. Wrong lines fixed, and where a right line showed a dumb decision, the decision fixed.
2. **The read of a scout report** (section 2): GREEDY, NORMAL, AGGRESSIVE, DEFENSIVE or UNKNOWN, for all three factions.
   UNKNOWN is never a reason for an army any more.
3. **Every plan adapts to some point and keeps its identity** (section 3).
4. **A new plan, OPTIMAL, for each faction** (section 4), with coached games (section 5).

No unit, building or economy number was changed. Pictures: `docs/shots/ai_optimal/`.
Tools: `tools/play_ai_optimal.gd` (one game, its reads, picks and economy), `tools/study/ai_optimal_games.py` (the
coached games and their table), `tools/shot_ai_optimal.gd` (pictures with the AI STORY open), `tools/test_ai_optimal.gd`.

## 1. The story audit

The story is the AI STORY panel and the narrator (scripts/ai_story.gd); its sentences come from the computers' match-log
lines through the phrase book (scripts/ai_story_lines.gd). I read every log line of the three computers (about 300 places
in 25 scripts), the phrase book, the owner's logs of 2026-11-04 and 2026-11-05 and about 100 AI-v-AI games of this job
(the coached games of section 5, their Balanced baseline and the development games). The lines
that were wrong, and what was wrong behind them:

| The line (as the story told it) | What was wrong | Fix |
|---|---|---|
| "could not see the enemy: it plays safe, army and walls before greed, and will look again" (the owner's Red Coast and Frostfang logs, 1:01 and 1:20) | **The logic.** (a) The scout labourer was taken back to work halfway: an idle moment on its road and the shared worker code sent it to a Farm, or the worker-safety code put it on its flee list near the enemy and then "resumed" it to work. The trip ended "pulled away" at 28% of the enemy's main, every time. (b) A look at an empty base was no read at all. (c) "Playing safe" built an army for nothing: Balanced put the Barracks and the Mill in at once, the shared rules wanted two Barracks (two Works for the Clockwork), the army first and the first wave held to 16 supply. | (a) A scout is not for work: WORK autocast off while it scouts, left out of the idle and flee lists. (b) The absence is information: GREEDY (section 2). (c) UNKNOWN keeps the plan's own settings and sends another scout 35 s later. New line: "saw too little (the scout was killed): that proves nothing, so it builds no army for it and looks again soon." |
| "scout ...: playing safe, will look again" and "scout under guard (Raptors), backing out of range", both told as "its scout plays safe and will look again" | One rule caught every line starting "scout "; the second is not playing safe at all. | Their own rules: "was stopped before it saw anything; it will look again soon" and "backs away from a guarded spot (Raptors) and keeps looking". |
| "spots an enemy Raptors: a sign of a Brood rush" at 5:10 and 5:25 | Any fast unit seen for the first time was called rush evidence, in mid game too. | Only before 4:30; later "fast raiders to watch for" (a detail). |
| "scouted: rush (4 fast Raptors seen at 3:58): switching to defence" | **The logic.** Our own Horsemen raiding the Brood saw its defenders at home and the scout read a rush coming: the Crown put the Barracks and the Mill "first" again. | Fast soldiers seen on their own half after 2:30 are a defence, not a rush; only before 2:30 do fast soldiers at home say a rush is getting ready. |
| "scouted: rush (early army (6 supply) in or out of its base)" at 5:34 and 6:22 | **The logic.** Any army seen out of its base before 6:40 read as a rush; the Timing attack put "the wall, the Barracks and the Mill first" again (all three stood), held its labourers and called its own timing off. | An army reads AGGRESSIVE only before 5:00 (RUSH_READ_BY); after 4:30 the line says "an attack is coming", not "a rush". |
| "a rush is scouted: the wall, the Barracks and the Mill first" | Said whatever stood already. | It names only what it puts in first, or none. |
| "scouted: greedy economy, switching to a timing attack" on Economy, Dragoon raids, Siege push, Springer timing... | **The logic.** A greedy read turned EVERY plan except the rushes into a Timing attack (and the Crown's milestones into the Timing plan's): the plan the owner picked was gone. | Only Balanced and Timing punish a real greed with the timing attack; Economy races it; the others keep their plan (section 3). |
| "opens with a Powder Mill: Musketeers first, a steady line of fire" on Economy and Balanced | The owner's plans build the second hall first; the Mill and the Barracks come after it (3:20 on Economy). | "opens with its economy: the second base before any Barracks, Musketeers when there is a reason." |
| "walls its ramp in a hurry: it fears a rush" | Said when the Rush plan walled its own ramp, and when the scout simply saw nothing. | Only on a rush read. |
| "scouted: balanced, carrying on" for a Barracks and a Horse Breeder at 1:30 with no Horseman out yet | **The logic.** The Horseman rush was read NORMAL until its riders were seen. | A Horse Breeder by 1:50 is rush evidence (every other Crown plan has it from 2:00 on). |
| "P1 Crown: 's base layout at its main..." | A line no rule knows that starts "'s" came out with a colon. | "P1 Crown's base layout ...". |
| The Clockwork's "could not see the enemy" against every Crown | **The logic.** Its scout stopped at the Crown's walled ramp and went home; the Crown's second hall at its natural was never looked at. | A scout shut out of the main goes on to the natural; a hall away from the enemy's start counts as an expansion even with the main unseen. |
| The Brood: no read at all | **The logic.** The Brood had its rush evidence but no greedy or normal read; its watching grub at the Crown's ramp foot never saw the Crown's second hall (18 tiles out, by the ramp's foot). | The Brood reads what its creatures see (`AIBroodNew._nb_read`); the watcher's round takes in both Crown hall spots by the ramp (the Crown's rule, docs/expansion_spots.md). |
| (none: DEFENSIVE did not exist) | Walls and turrets were never read; a wall that kept the scout out was "could not see". | DEFENSIVE (section 2). |
| The Clockwork's written builds (Springer timing, Clock Soldier rush, Pendulums, Heavy Works push, Owl raids) told nothing of the enemy | **The logic.** They switched their scout off while their opening ran: a rush was seen only when it hit them. | They still send no scout in their opening (a Winder out cost the Springer timing a fifth of its income and its attack: test_clockwork_springer_timing), but the scout reads what their own units see (passive), and a rush read gets the rush reaction (a Light Works and Clock Soldiers, `BuildsEco.urgent`) ahead of their steps. |

Lines checked and right as they are (the rest of the phrase book): the attacks and waves, the held rush and its
counter-attack or expansion (AITransition), the ramp hold, the walls of a new hall, the expansions, the milestones, the
raids (Dragoons, balloons, the Springer raid, the Owls), the siege push, the Brood's alarm, defence, waves, growth and
research, the gg. In the games of this job none of them said something the computer did not know or do.

## 2. The read of a scout report

`scripts/ai_read.gd` (the words and the phrases), `AIScout._evaluate` (the Crown, the Clockwork) and
`AIBroodNew._nb_read` (the Brood). Only what its own side saw (the fog of war). Each read comes with a fixed phrase of what
was seen, which the story tells, translated.

| Read | What it saw | Thresholds |
|---|---|---|
| AGGRESSIVE | fast rush units early (on their way, or at their base before 2:30); a big early army (before 4:00, or out of its base before 5:00); production buildings on a thin economy; two Light Works by 2:30; a Tyrant Sire by 2:10; a Horse Breeder by 1:50 | `RUSH_VALUE`, `EARLY_PROD`, `RUSH_READ_BY` 300 s, `HOME_RUSH_BY` 150 s |
| DEFENSIVE | 2 static defences (Ratchet Turrets, rooted Brood warriors), or 1 on a single base before 5:00; walls all round a single base with little army (8 pieces; 24 for the Crown, which walls its ramp and every new hall as its normal game); a wall that shut the scout out (the same 24 for the Crown) | `DEF_TURRETS`, `DEF_WALLS`, `DEF_WALLS_CROWN` |
| GREEDY | **no army and no production at its base** (looked at: 40% of its main, the Brood's Mother's ground 45%, from 0:55: a rush has its production by then); an early second base with little army (a hall away from its start counts even when its main was not seen: a walled Crown's natural); a full economy with no military building. Against the Brood only when the look saw its economy (2 Rootmaws or 8 grubs) and its ground or its army (THE BROOD READ of crown-v-brood: its Mother and a far turtle alone are no greed) | `GREEDY_ABSENT_FROM` 55 s, `ABSENT_COV` |
| NORMAL | anything else it saw: production and a small army, a standard opening | |
| UNKNOWN | the scout killed, blocked or turned back before it saw anything, or too little of the base | another scout 35 s later (`RESCOUT_UNKNOWN`); from the second denied trip a soldier scouts |

A read changes at most every 75 s (a rush read at once; the first read after an UNKNOWN at once). `-- absence:off` on
the command line reads as 0.31.1 (for study games).

## 3. How each fixed plan adapts

The owner: "you can't just see a rush coming and keep doing what you're doing", but "if I chose an AI to go economic ...
it would default to trying to outpace in an economic race". So:

| Read | Every plan | Balanced | Timing | Economy | The others (Rush, Dragoon raids, Siege push, Balloon harass; Springer timing, Clock Soldier rush, Pendulums, Heavy Works push, Owl raids; Spitter timing, Brute siege, Air rush, Extreme rush) |
|---|---|---|---|---|---|
| AGGRESSIVE | **survival**: the defence (the Crown: the wall, the Barracks and the Mill first, soldiers before labourers, no new hall till it is held; the Clockwork: a Light Works and Clock Soldiers, a turret only for a big rush; the Brood: its army home, warriors laid), then the counter-attack or the expansion (AITransition) | | | | (the rush plans keep rushing: their scout is their raid) |
| GREEDY | | a timing attack, sized and timed from what was seen, on a REAL greed (a second base, a full economy); an empty early base alone is no reason to leave its plan | the timing comes sooner | **races it**: its next halls sooner (`RACE_EXPAND`) | keep their plan |
| DEFENSIVE | | out-expands and techs up | keeps its plan | races it | keep their plan |
| NORMAL | | | | | keep their plan |
| UNKNOWN | **no army for it**: the plan's own settings; another scout soon | | | | |

The obvious answers that were already there stay (anti-air when flyers are seen, the Storm Sire first, the Pendulums
against a swarm, Brutes and Battering Horns against a wall).

## 4. OPTIMAL

Lobby name **OPTIMAL** (pt *Ótimo*, es *Óptimo*), tooltip "OPTIMAL plays the best it can: scouts and picks from all its
builds." Every faction has it; RANDOM PLAN may pick it. `scripts/ai_optimal.gd` decides; each faction's own computer plays
the pick (`opt_switch`: AICrown, AIClockwork, AIBroodNew). Balanced stays as it is: it is the plain game to train against
and the baseline the coached builds were measured on (and it still answers a real greed with its timing attack).

**The common opening** (the owner: "most Crown games start the same: a Cottage, a Gate, then a Farm"):
- the Crown (since crown-optimal-opening, docs/crown_optimal_opening.md, the owner 2026-11-06): the ramp Cottage, the
  Gate, the BARRACKS (a rush is not ruled out yet), the second FARM, the scout out at once (0:02), then the build order
  WAITS at a "pick" step (labourers and Cottages keep coming, nothing is held for it) until the pick; NO Powder Mill before
  the read, in every matchup (a seen rush puts the Mill and the soldiers first). After the read: the Mill (Musketeer play)
  or the Horse Breeder (riders). Before scouting it may LEAN to the Horseman rush against the Brood (the owner: "it
  could decide on a Horseman rush based on the map or the matchup"): 35% on a short map, 20% on a long one; never against
  anyone else.
- the Clockwork: its Balanced economy opening (Winders non-stop, a fast second Clocktower), a Winder scouts at 0:18.
- the Brood: Balanced's economy opening, its watching grub out at 0:40 (into the enemy's main; against the Crown at its
  ramp foot and its two hall spots).

**The picks** (by the read, the matchup, the map, and a little chance where the owner asked for it):

| Read | Crown | Clockwork | Brood |
|---|---|---|---|
| AGGRESSIVE | defend, then Balanced (its counter) | defend, then Balanced | defend, then Balanced |
| GREEDY, early (before 2:30) | v Brood (read before 2:45): the **Horseman rush**, the Horse Breeder at once (the owner, 2026-11-06; later: out-expand, Economy); v Clockwork: the Horseman rush 35%, else Balanced's steady waves; v Crown: the **Timing attack**, never Horsemen | the **Clock Soldier rush** | v Clockwork, Brood: the **Raptor rush**; v Crown (walled): the **Spitter timing** |
| GREEDY, later (to 5:30) | Timing attack (v Clockwork: Balanced; v Brood: Economy, out-expand it) | Springer timing | Spitter timing (v Crown), Timing attack |
| GREEDY, too late | Economy (out-expand it) | Economy | Economy |
| NORMAL (weights) | v Brood: Balanced 3, Siege push 2, Timing 2; v Clockwork: Balanced 3, Economy 2, Dragoon raids 2, Timing 1; v Crown: Economy 3, Balanced 2, Dragoon raids 2, Siege push 1, Timing 1 | v Brood: Pendulums 3, Balanced 2, Owl raids 2; v Crown: Balanced 2, Economy 2, Springer timing 2, Heavy Works push 1; v Clockwork: Balanced 3, Economy 2, Springer timing 1 | v Crown: Balanced 2, Spitter timing 2, Brute siege 2, Timing 1; v Clockwork: Timing 2, Spitter timing 2, Balanced 2; v Brood: Balanced 2, Timing 2, Economy 1, Rush 1 |
| DEFENSIVE | opening: Economy; middle: Siege push | opening: Economy; middle: Heavy Works push | opening: Economy; middle: Brute siege |
| UNKNOWN | no pick: it looks again; no read 45 s after a first UNKNOWN, or none by 3:00: the NORMAL table | | |

It re-reads on every scout trip and switches at most ONCE A STAGE (opening to 4:30, middle to 10:00, late), never
flip-flopping; keeping the build it plays is no switch. The one exception is survival: a rush read while it plays
Economy or its own early rush (no gate, no line yet) switches to Balanced's defence at once. Every read and pick is in the
match log and the story: "P1 Crown reads the enemy as GREEDY (a second base and little army) and picks Rush: punish the
greed before its army is up."

How a pick is played from where the game stands: the Crown's build order takes the new plan's steps from the next one
(the steps already done pass by), its milestones, its siege push, balloons, Dragoon raids or Horseman rush; the
Clockwork's written opening of the new build runs again with what stands marked done (`_mark_existing`), its raid, rush,
Owls or push made new; the Brood's plan is remade on its next think (its times run from the clock).

## 5. The coached games

Each faction's OPTIMAL (Hard) against each faction's Economy, Rush, Timing and Balanced (Hard), mirrors too: 36 games of
10 minutes, the maps in turn (Highmoor, Redrock Canyon, Thornwood Maze, Greenhold), and the same 36 games with the
computer on **Balanced** in its seat, as the baseline (`python3 tools/study/ai_optimal_games.py run OUT` and
`... run BASE --plan balanced`; the table: `tools/study/ai_optimal_report.py OUT BASE`). A game not won by 10:00 is
"ahead" or "behind" when one side's gold earned plus twice its army is a tenth more than the other's, else "even".
One game a cell, so a single result is noise (OPTIMAL's own dice change the match's random stream, so even a game
where it keeps Balanced plays out differently from the baseline); the totals and the picks are what to read.

| OPTIMAL | v | its plan | map | OPTIMAL: result, earned / foe, army / foe at the end | its picks (clock read->build) | Balanced in the same seat |
|---|---|---|---|---|---|---|
| brood | brood | balanced | greenhold | even 10:00, 11215 / 14126, 2795 / 1590 | 1:40 GREEDY->rush | ahead 10:00, 16261 / 12199, 2615 / 400 |
| brood | brood | economy | highmoor | even 10:00, 13392 / 11324, 1370 / 1770 | 1:40 GREEDY->rush; 4:52 GREEDY->timing | behind 10:00, 15710 / 15282, 490 / 3620 |
| brood | brood | rush | redrock_canyon | ahead 10:00, 13591 / 4290, 995 / 425 | 3:00 UNKNOWN->balanced | ahead 10:00, 12571 / 8280, 3365 / 550 |
| brood | brood | timing | thornwood_maze | ahead 10:00, 13278 / 10847, 1760 / 1160 | 3:00 UNKNOWN->rush | ahead 10:00, 14674 / 12542, 1740 / 1330 |
| brood | clockwork | balanced | greenhold | ahead 10:00, 11150 / 9293, 2625 / 1110 | 1:41 GREEDY->rush; 8:24 DEFENSIVE->brute | ahead 10:00, 13841 / 10916, 3200 / 290 |
| brood | clockwork | economy | highmoor | WON 8:18, 7959 / 4693, 2630 / 0 | 1:40 GREEDY->rush; 8:11 GREEDY->economy | behind 10:00, 13101 / 13215, 400 / 2715 |
| brood | clockwork | rush | redrock_canyon | ahead 10:00, 8399 / 7890, 1765 / 1415 | 1:33 NORMAL->spitter | ahead 10:00, 10612 / 4766, 1750 / 0 |
| brood | clockwork | timing | thornwood_maze | ahead 10:00, 13224 / 8654, 2645 / 0 | 1:37 NORMAL->balanced; 9:16 DEFENSIVE->brute | ahead 10:00, 12018 / 8289, 2125 / 200 |
| brood | crown | balanced | greenhold | ahead 10:00, 15767 / 7600, 3420 / 1675 | 2:18 NORMAL->spitter | ahead 10:00, 16928 / 7600, 3980 / 0 |
| brood | crown | economy | highmoor | ahead 10:00, 15793 / 12160, 1940 / 315 | 1:47 GREEDY->spitter; 6:59 GREEDY->economy | ahead 10:00, 15835 / 8740, 4370 / 0 |
| brood | crown | rush | redrock_canyon | ahead 10:00, 9021 / 7220, 1235 / 1480 | 2:01 NORMAL->balanced | ahead 10:00, 11926 / 4560, 2525 / 0 |
| brood | crown | timing | thornwood_maze | ahead 10:00, 13896 / 6460, 1550 / 190 | 2:27 NORMAL->spitter | ahead 10:00, 12869 / 6460, 1730 / 1005 |
| clockwork | brood | balanced | greenhold | behind 10:00, 7920 / 10814, 860 / 1455 | 1:42 GREEDY->cs_rush; 3:48 AGGRESSIVE->balanced | behind 10:00, 10948 / 12756, 0 / 3680 |
| clockwork | brood | economy | highmoor | even 10:00, 8173 / 8296, 470 / 450 | 1:44 GREEDY->cs_rush | behind 10:00, 10556 / 14081, 200 / 1750 |
| clockwork | brood | rush | redrock_canyon | behind 10:00, 10144 / 11620, 460 / 1475 | 1:45 AGGRESSIVE->balanced | LOST 9:36, 6088 / 8682, 0 / 3155 |
| clockwork | brood | timing | thornwood_maze | LOST 9:36, 6607 / 8490, 0 / 2650 | 1:41 GREEDY->cs_rush | behind 10:00, 10923 / 11164, 0 / 3025 |
| clockwork | clockwork | balanced | greenhold | even 10:00, 13544 / 13656, 2430 / 2770 | 1:41 GREEDY->balanced | even 10:00, 13754 / 13527, 2430 / 2720 |
| clockwork | clockwork | economy | highmoor | behind 10:00, 13371 / 13876, 1350 / 3260 | 1:42 GREEDY->balanced | behind 10:00, 13681 / 14342, 1565 / 2660 |
| clockwork | clockwork | rush | redrock_canyon | behind 10:00, 7774 / 7515, 595 / 1635 | 1:56 NORMAL->balanced | ahead 10:00, 12320 / 7890, 3030 / 1200 |
| clockwork | clockwork | timing | thornwood_maze | even 10:00, 11020 / 9837, 1535 / 1615 | 1:43 NORMAL->economy; 5:41 GREEDY->balanced | ahead 10:00, 12951 / 9423, 4305 / 480 |
| clockwork | crown | balanced | greenhold | ahead 10:00, 12345 / 9880, 2850 / 0 | 3:00 UNKNOWN->economy | ahead 10:00, 13030 / 7980, 5210 / 425 |
| clockwork | crown | economy | highmoor | even 10:00, 10760 / 9880, 1510 / 1810 | 3:00 UNKNOWN->springer | even 10:00, 12693 / 11020, 1730 / 2755 |
| clockwork | crown | rush | redrock_canyon | behind 10:00, 3398 / 8360, 0 / 1370 | 1:31 AGGRESSIVE->balanced | ahead 10:00, 10613 / 7600, 2910 / 1115 |
| clockwork | crown | timing | thornwood_maze | ahead 10:00, 9602 / 6080, 835 / 1045 | 2:18 UNKNOWN->springer | ahead 10:00, 12977 / 6080, 3770 / 630 |
| crown | brood | balanced | greenhold | behind 10:00, 6080 / 14191, 0 / 3615 | 1:27 GREEDY->siege | behind 10:00, 4940 / 14578, 0 / 3100 |
| crown | brood | economy | highmoor | behind 10:00, 9120 / 13275, 300 / 3240 | 1:29 GREEDY->siege | behind 10:00, 6840 / 15571, 1515 / 2910 |
| crown | brood | rush | redrock_canyon | ahead 10:00, 5700 / 4666, 1115 / 1200 | 0:00 LEAN->rush; 3:14 AGGRESSIVE->balanced | behind 10:00, 7980 / 12225, 1850 / 2245 |
| crown | brood | timing | thornwood_maze | behind 10:00, 5320 / 12434, 0 / 3265 | 1:29 GREEDY->siege | behind 10:00, 6080 / 13174, 75 / 3030 |
| crown | clockwork | balanced | greenhold | ahead 10:00, 7220 / 4998, 1485 / 140 | 1:29 GREEDY->rush; 7:42 GREEDY->balanced | behind 10:00, 6080 / 11958, 0 / 4350 |
| crown | clockwork | economy | highmoor | behind 10:00, 11400 / 12825, 1565 / 2500 | 1:30 GREEDY->balanced | behind 10:00, 9500 / 12869, 885 / 4380 |
| crown | clockwork | rush | redrock_canyon | ahead 10:00, 6840 / 7622, 1185 / 0 | 1:31 NORMAL->timing | behind 10:00, 3420 / 8347, 0 / 2410 |
| crown | clockwork | timing | thornwood_maze | behind 10:00, 8360 / 10494, 1555 / 1960 | 1:28 NORMAL->dragoon | behind 10:00, 8740 / 10645, 1670 / 2925 |
| crown | crown | balanced | greenhold | behind 10:00, 7980 / 10640, 1435 / 2160 | 2:34 UNKNOWN->siege | ahead 10:00, 10260 / 10640, 2010 / 760 |
| crown | crown | economy | highmoor | behind 10:00, 9500 / 10260, 525 / 2795 | 2:35 UNKNOWN->economy | behind 10:00, 8360 / 11020, 410 / 2840 |
| crown | crown | rush | redrock_canyon | ahead 10:00, 10640 / 7600, 1780 / 585 | 1:07 AGGRESSIVE->balanced | even 10:00, 7600 / 7980, 1320 / 715 |
| crown | crown | timing | thornwood_maze | ahead 10:00, 7600 / 6840, 1935 / 485 | 2:04 UNKNOWN->timing | even 10:00, 7220 / 6840, 955 / 775 |

- brood OPTIMAL: won or ahead in 10 of 12, lost or behind in 0; Balanced in the same 12 games: won or ahead in 10 (score +11 for OPTIMAL against +8 for Balanced: won 2, ahead 1, even 0, behind -1, lost -2)
- clockwork OPTIMAL: won or ahead in 2 of 12, lost or behind in 6; Balanced in the same 12 games: won or ahead in 5 (score -5 for OPTIMAL against -1 for Balanced: won 2, ahead 1, even 0, behind -1, lost -2)
- crown OPTIMAL: won or ahead in 5 of 12, lost or behind in 7; Balanced in the same 12 games: won or ahead in 1 (score -2 for OPTIMAL against -8 for Balanced: won 2, ahead 1, even 0, behind -1, lost -2)

What the games say:

- **The Crown: OPTIMAL is clearly better than Balanced** (5 of 12 won or ahead against 1 of 12). Its gains are the reads:
  the Crown's Rush read at 1:07 (a Horse Breeder by 1:50) defended and ahead 10,640 to 7,600; the lean's Horseman rush
  against the Brood's Rush, held by the survival switch at 3:14 (picture `crown_lean_rush_pick_2.png`); the Horseman
  rush picked against a greedy Clockwork (ahead 7,220 to 5,000, Balanced behind 6,080 to 11,960); the Timing attack
  against the Clockwork's Rush and the Crown's Timing. Against the Brood it is behind like Balanced (the Brood earns 2 to
  3 times the Crown in every one of these games, OPTIMAL or not: the FOOD_BONUS question in CLAUDE.md), a little less
  far behind with the Siege push (9,120 against 6,840 earned on Highmoor).
- **The Brood: about the same as Balanced, a little better** (10 of 12 either way; score +11 against +8). Its Raptor rush
  on a greedy Clockwork won the Economy game at 8:18; on a greedy Brood the rush gave an even game where Balanced was
  ahead once and behind once. Its Spitter timing on the Crown is ahead every time, like Balanced.
- **The Clockwork: worse than Balanced** (2 of 12 against 5 of 12). Against the Crown's Rush it read the rush at 1:31
  and defended, and still lost its economy (3,398 earned) where Balanced in the same seat was ahead: its rush reaction
  (a Light Works and 3 Clock Soldiers) is Balanced's own, so that game is the noise of one seat, but the Clockwork's
  answer to the Horseman rush is thin in both (docs/ai_round5.md). Against the Brood its Clock Soldier rush on a
  greedy Brood was even once, behind once and lost once; Balanced was behind three times and lost once there, so the
  rush is no worse. Against the Crown it reads UNKNOWN (the walled ramp) and picks for the matchup at 3:00.

Builds tried and changed on these games (the same seats, run by the tools above):
1. **The Crown's Horseman rush on a GREEDY read of the Brood** (the read comes at ~1:30): the riders rode out at 3:52-4:02,
   after the Brood's Raptors hatched, and the rush FAILED in all three games (3,800-6,500 earned against 10,600-14,800,
   army 0 in two). The riders only arrive in time when the computer leans to them before scouting; on the read it picks
   the Siege push now.
2. **The Clockwork's Clock Soldier rush on a greedy Clockwork**: behind both times (9,000-9,300 earned against
   11,800-12,500) where Balanced was even or close; the mirror's Clock Soldiers come at 2:00 whatever it plays. It plays
   Balanced's waves now (then even and behind, as Balanced).
3. **The Owl raids on a greedy Brood** instead of the Clock Soldier rush: behind in all three games, with less earned
   (4,800-6,700 against the rush's 6,600-8,200); back to the Clock Soldier rush (your "Clock Soldier/Springer timing").

### Pictures (`docs/shots/ai_optimal/`, the AI STORY open on the OPTIMAL side; `tools/shot_ai_optimal.gd`)

| Picture | What it shows |
|---|---|
| `crown_v_brood_pick_1.png` | 1:36, the Crown's OPTIMAL against the Brood's Economy (Highmoor): its scout read the Brood as GREEDY (a second base and little army) and it picks the Siege push, "the riders would come too late". Its Barracks at 0:46 is the common opening against the Brood. |
| `crown_v_brood_pt_pick_1.png` | The same moment in Portuguese: the reads, the saw phrases and the reasons are translated. |
| `crown_lean_rush_pick_1.png` | 0:06, the Crown's OPTIMAL against the Brood's Rush (Redrock Canyon) leans to the Horseman rush before it scouts ("Horsemen are good against the Brood's grubs"). |
| `crown_lean_rush_pick_2.png` | 3:22, the same game: the GREEDY read at 1:26 could not change the build (once a stage: "Siege push waits"); at 3:15 the Raptors at its ramp read AGGRESSIVE and the survival switch puts Balanced's defence in at once; it holds the top of its ramp. |
| `clockwork_v_crown_rush_pick_1.png` | 1:14, the Clockwork's OPTIMAL against the Crown's Horseman rush (Highmoor): a Horse Breeder seen at 1:08 reads AGGRESSIVE ("a production building very early"): a Light Works and Clock Soldiers first, then back to its economy. |
| `clockwork_v_brood_eco_pick_1.png` | 1:48, the Clockwork's OPTIMAL against the Brood's Economy (Thornwood Maze): GREEDY, it picks the Clock Soldier rush. |
| `clockwork_v_brood_eco_attack.png` | 7:28, the same game: its army out. |
| `brood_v_crown_eco_pick_1.png` | 1:54, the Brood's OPTIMAL against the Crown's Economy (Greenhold): its watching grub saw the Crown's new hall by the ramp's foot ("a new base by its natural"): GREEDY, it picks the Spitter timing. |
| `brood_v_crown_eco_attack.png` | 6:51, the same game: the Spitter timing goes out. |
| `crown_v_crown_timing_pick_1.png`, `crown_v_crown_timing_0155.png` | The Crown against a walled Crown (Thornwood Maze): the scout was blocked at 1:19, "that proves nothing, so it builds no army for it and looks again soon"; it picks for the matchup when no read settles it. |
| `economy_races_0140.png` | A FIXED plan keeping its identity: the Crown's Economy against the Clockwork's Economy (Highmoor) reads GREEDY at 1:28 ("no army and no production at its base") and races it, more bases sooner, instead of turning into a timing attack. |

## 6. Tests

- `tools/test_ai_optimal.gd` (new): a greedy enemy is read GREEDY and punished in time by each faction's OPTIMAL (the
  Crown v the Clockwork, the Clockwork v the Crown, the Brood v the Clockwork); a scout killed early reads UNKNOWN and
  no army is built for it, another scout within a minute; the Crown's Economy reads a greedy enemy and stays the Economy
  plan (it races), and against a rush defends and stays the Economy plan; OPTIMAL never Horseman-rushes the Crown (300
  picks and 100 leans) and does against a greedy Brood.
- `tools/test_ai_scout.gd`: case 4 rewritten to the owner's rule (a walled-in empty base reads GREEDY and the Economy
  plan races it; a scout killed early reads UNKNOWN: no army, another scout soon).
- `tools/test_crown_build_order.gd` knows OPTIMAL's "pick" step; `tools/test_ai_wall_vs_rush.gd` takes `crown:optimal`.
- The whole suite (`tools/test_ai_*`, `test_crown_*`, `test_clockwork_*`, `test_brood_*`: 53 scripts; the coaching tools
  with `check:1`: test_clockwork_eco (also `rush:1`, `foe:crown`), test_clockwork_springer_timing, test_clockwork_owls,
  test_clockwork_builds_a) was run on this branch, and every failing one again on origin/main (0.31.1) in a worktree:
  - pass: all the others, among them test_ai_scout, test_ai_scout_threat, test_ai_scout_sentry, test_ai_scout_defence,
    test_ai_wall_vs_rush, test_ai_optimal, test_ai_rush, test_ai_harass, test_ai_placement, test_brood_builds,
    test_brood_layout, test_brood_spend, test_crown_balloon, test_crown_build_order, test_crown_dragoon_raid,
    test_crown_farms, test_crown_hold, test_crown_siege, test_crown_v_brood, test_clockwork_eco check:1,
    test_clockwork_springer_timing check:1, test_clockwork_builds_a check:1, test_i18n;
  - failing on main the same way (not this job's): test_ai_crown_bank (1), test_ai_expand (2, the Clockwork's new hall),
    test_ai_expand_wall (6 here, 7 on main), test_ai_round6 (7, the first hall spot at the natural), test_ai_rush_followup
    (13), test_crown_owner_eco (1, the natural's ring by 6:30), test_brood_voices (Hatchlings have no voice);
    test_brood_new_defence hangs in its Musketeers case at 5:17 on main too (killed by the 30-minute limit);
  - load-dependent: test_ai_rush's "never supply-blocked for 20 s" read 21 s once with three games running (main the
    same under the same load); alone it passes (0 s);
  - test_clockwork_owls check:1 on its default seed 11: the first Owl sortie "never" by 8:00 (the Owls were held at home
    twice to defend against riders that cannot hit them; main 7:16). On seed 12 it passes here at 6:47 (main 7:18). The
    games part early (the Crown's scout reads differently), so this one seed is the divergence, not a rule of the Owls.
    Worth a look when merging.

## 7. Questions for the owner

1. **The Crown's lean to the Horseman rush against the Brood before it scouts** (35% on a short map, 20% on a long one):
   your "it could decide on a Horseman rush based on the map or the matchup". It is a gamble: against the Brood's Extreme
   rush the riders' opening has no Gate and no line yet (the survival switch puts both in on the rush read, ~1:15). Keep
   it, make it rarer, or only after the scout's first look?
2. **The Brood reads GREEDY too easily**: every Brood economy plan roots a Mound Turtle on new ground at 0:00, so at 1:30
   the Brood always shows "a second base and little army" (Economy and Timing look the same then; its Sire tells them
   apart only at 2:00-2:45). OPTIMAL's Horseman rush then goes against the Timing plan as well. Should the Brood's first
   far turtle count as its standard opening (NORMAL), and only a second one, or no Sire by 2:30, as greed?
3. **The walled Crown is hard to read**: a scout cannot get into a walled main, so it reads the Crown from its natural
   (a second hall early = GREEDY) and otherwise UNKNOWN; OPTIMAL then picks for the matchup 45 s after the first UNKNOWN.
   Is a walled ramp with nothing at the natural a NORMAL read for you (most Crown games), or should the scout wait at the
   ramp foot for the first soldiers?
4. **Once a stage** (opening to 4:30, middle to 10:00, late): enough room to adapt, or should the middle allow a second
   switch when the read changes from GREEDY to AGGRESSIVE?
5. **The NORMAL tables** (section 4) are first guesses from the coached builds' reports; the games below say which picks
   did well in each matchup. Tell me the ones you would never play (e.g. the Owl raids against the Crown were left out,
   the Balloon harass is never picked).
6. **Economy's race** only brings its next halls sooner (`expand` x0.3): the Crown's owner Economy opening already takes
   its second hall at 11 labourers, so against a greedy Crown it changes little until the third hall. Enough, or should it
   also skip its Barracks until the second hall stands?
