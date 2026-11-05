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
in 25 scripts), the phrase book, the owner's logs of 2026-11-04 and 2026-11-05 and about 40 AI-v-AI games of this job
(each faction's OPTIMAL against every faction's Economy, Rush, Timing and Balanced, plus the development games). The lines
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
| The Clockwork's written builds (Springer timing, Clock Soldier rush, Pendulums, Heavy Works push, Owl raids) told nothing of the enemy | **The logic.** They switched their scout off while their opening ran: a rush was seen when it hit them. | Every build scouts; a rush read gets the rush reaction (a Light Works and Clock Soldiers, `BuildsEco.urgent`) ahead of its steps. |

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
| GREEDY | **no army and no production at its base** (looked at: 40% of its main, the Brood's Mother's ground 45%, from 0:55: a rush has its production by then); an early second base with little army; a full economy with no military building | `GREEDY_ABSENT_FROM` 55 s, `ABSENT_COV` |
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
- the Crown: the ramp Cottage, the Gate, the second Farm, the scout out at once (0:02), then the build order WAITS at a
  "pick" step (labourers keep coming) until the pick; against the Brood the Barracks and the Mill at 7 labourers instead
  of the Farm, as Balanced does (the Brood's fastest rush is at the ramp by ~1:50, before a read can put a Barracks up in
  time: tools/test_ai_wall_vs_rush.gd). Before scouting it may LEAN to the Horseman rush against the Brood (the owner: "it
  could decide on a Horseman rush based on the map or the matchup"): 35% on a short map, 20% on a long one; never against
  anyone else.
- the Clockwork: its Balanced economy opening (Winders non-stop, a fast second Clocktower), a Winder scouts at 0:18.
- the Brood: Balanced's economy opening, its watching grub out at 0:40 (into the enemy's main; against the Crown at its
  ramp foot and its two hall spots).

**The picks** (by the read, the matchup, the map, and a little chance where the owner asked for it):

| Read | Crown | Clockwork | Brood |
|---|---|---|---|
| AGGRESSIVE | defend, then Balanced (its counter) | defend, then Balanced | defend, then Balanced |
| GREEDY, early (before 2:30) | v Brood: the **Siege push** (riders picked on the read come too late: only its lean before scouting rides); v Clockwork: the Horseman rush 35%, else Balanced's steady waves; v Crown: the **Timing attack**, never Horsemen | the **Clock Soldier rush** | v Clockwork, Brood: the **Raptor rush**; v Crown (walled): the **Spitter timing** |
| GREEDY, later (to 5:30) | Timing attack (v Clockwork: Balanced; v Brood: Siege push) | Springer timing | Spitter timing (v Crown), Timing attack |
| GREEDY, too late | Economy (out-expand it) | Economy | Economy |
| NORMAL (weights) | v Brood: Balanced 3, Siege push 2, Timing 2; v Clockwork: Balanced 3, Economy 2, Dragoon raids 2, Timing 1; v Crown: Economy 3, Balanced 2, Dragoon raids 2, Siege push 1, Timing 1 | v Brood: Pendulums 3, Balanced 2, Owl raids 2; v Crown: Balanced 2, Economy 2, Springer timing 2, Heavy Works push 1; v Clockwork: Balanced 2, Economy 2, Springer timing 1, Clock Soldier rush 1 | v Crown: Balanced 2, Spitter timing 2, Brute siege 2, Timing 1; v Clockwork: Timing 2, Spitter timing 2, Balanced 2; v Brood: Balanced 2, Timing 2, Economy 1, Rush 1 |
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

RESULTS_HERE

## 6. Tests

- `tools/test_ai_optimal.gd` (new): a greedy enemy is read GREEDY and punished in time by each faction's OPTIMAL (the
  Crown v the Clockwork, the Clockwork v the Crown, the Brood v the Clockwork); a scout killed early reads UNKNOWN and
  no army is built for it, another scout within a minute; the Crown's Economy reads a greedy enemy and stays the Economy
  plan (it races), and against a rush defends and stays the Economy plan; OPTIMAL never Horseman-rushes the Crown (300
  picks and 100 leans) and does against a greedy Brood.
- `tools/test_ai_scout.gd`: case 4 rewritten to the owner's rule (a walled-in empty base reads GREEDY and the Economy
  plan races it; a scout killed early reads UNKNOWN: no army, another scout soon).
- TESTS_HERE

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
