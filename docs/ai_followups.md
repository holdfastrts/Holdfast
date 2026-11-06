# ai-followups (0.33.3): the Crown's army, its home post, and the Clockwork's raid answers

The owner watched a Hard Crown OPTIMAL v Hard Clockwork OPTIMAL game (0.33.0, Ashford Crossing, seed 2091978150; log
`docs/playtests/2026-11-06/crown_v_clockwork_unprepared_log.txt`, picture `clockwork_army_chases_horseman.jpg`) and asked:
"What happened in this game? Why was the Crown so unprepared? Again it wasn't at the palisade to greet the enemy with fire,
it was on the high ground. There was a very bad mistake by the Clockwork: it stopped the attack and sent the whole army to
chase down 1 Horseman."

## Merges

Branch `ai-followups` = main (crown-hold already merged, 0.33.1) + `crown-optimal-opening` + `clockwork-home`.

- **crown-optimal-opening was NOT DONE** (its last commit, 12:40, is a WIP: "a greedy Brood is out-expanded ... the riders
  kept as a study switch"); it was merged as it stood. Its last change (the opening's supply margin from the production
  rate) broke `tools/test_ai_wall_vs_rush.gd` (1 Musketeer by 2:40 instead of 3, 4 labourers lost): main passed, the merge
  failed, so the opening now keeps its old margin while a rush is defended (`AICrown._supply_margin`), and the test passes.
- clockwork-home (DONE) also called itself 0.33.1: its patch notes are now 0.33.2 (crown-hold keeps 0.33.1); this job is
  0.33.3.

## What happened in the owner's game

**The Crown.** It read GREEDY at 1:38 and picked Balanced ("steady waves punish the greed"), then built no army: 0 at 4:00,
175 at 5:00, 275 at 6:00, 455 at 7:00 against the Clockwork's 280, 490, 840, 1,490, while it went to 44-50 labourers
(the Clockwork 31). Two rules made that:
- `owner_labs` (crown-owner-eco: "labourers non-stop to two halls' worth", up to 40) switched off BOTH brakes on labourers:
  the army's share of the economy (`_army_due`, Balanced 0.55 of the labourers in supply) and round 5's "the army
  catches up first against the Clockwork". Nothing weighed the enemy's army against the Clockwork at all (the
  crown-v-brood reckoning, `army_behind`, is for the Brood only).
- the milestones (`_mid_tick`) only look at labourers and halls: Barracks 2 (5:40), 3 (6:21), 4 (7:06), the Armoury and
  the Church went up with an army of 3-4 supply, each one taking the gold that would have trained soldiers.
So a plan that says it punishes greed never sent anything: the wave waited for 1.1 times the enemy army it knew, and its
army never got there.

**The home post.** At 5:29-5:55 the cliff-edge rule (crown-cliff-edge, 0.29.2) answered the Clockwork's scout and its first
units at the natural by moving the line to "the cliff edge above its Palisade", 158-182 px from it; the line only went
inside the wall when the wall itself was hit (6:47). crown-hold (0.33.1) added the GATE POST at a walled natural, but only
once the wall is 70% closed with its gate up, and the cliff edge still ran for any building below the main, the palisade
pieces included.

**The Clockwork.** The push went out at 6:15 (1,140 against 206). At 6:44 and again at 7:40 the push's FIGHT logic met
"1 armed enemy (115 value)", the Horseman: with nothing in its screen's reach and no Ballista reaching it, the push walks
its anchor toward the enemy 60 px a think, with no limit; a Horseman keeping out of reach drew the whole block back across
the map (7:05 heads for (23, 8), 7:40 fighting at (72, 51) near its own base). It was not the home defence that called it
back ("the whole army (1 units, 100) meets a raid worth 103" at 7:18 was the one unit at home); the push's own recall
(`_should_retreat`, "a big attack on the base") needs 350 or more, so a lone rider never triggered it.

## What changed

### 1. The Crown puts its army first (scripts/ai_crown.gd)
- `army_lags()`: from 3:30, once the second hall stands and 22 labourers work (`LAG_LABS`, one hall's farms and Mill and
  a few builders), the army must be worth `LAG_SHARE` 60% of the enemy army it reckons (`foe_reckon()`: what its scouts saw
  in the last two minutes, never less than `LAG_TABLE`, the lowest a Hard Clockwork / Crown had at that age in the coached
  games, less half of what it killed). Not against the Brood (the crown-v-brood reckoning does it there).
- While it lags: `owner_labs` no longer overrides the brakes (the halls train a labourer only when every Barracks is busy,
  `_army_due`); the Church, the Armoury and the like wait; another Barracks or Foundry only when every one of its kind is
  busy or the bank holds 150 more than its price (`_mid_ok_lagging`; the first Foundry and the Horse Breeder always); the
  natural's wall is not held back waiting for the expansion to saturate (`wall_sat`). (Keeping 65 gold from the soldiers for
  the wall while it is under half closed, `_wall_keep`, was tried and left off: `-- wallkeep:on`, numbers below.)
- A GREEDY READ IS PRESSURE: while OPTIMAL's last pick answered a GREEDY read with an attacking plan (Balanced, Timing, the
  Horseman rush) the army keeps 90% of the enemy's (`pressure()`, `LAG_PRESS`).
- Study switch `-- armylag:off` plays without it. Match log / AI STORY: "the army first: 160 of army against the 630 it
  reckons the enemy has (it wants 60%): the labourers and the tech wait for the soldiers", "milestone Barracks waits: the
  army is far behind the enemy's".

### 2. The home post (scripts/ai_crown_hold.gd)
- The cliff edge never answers a threat at a palisade or gate, or at a building of a natural with a wall plan that has any
  piece down (`_in_walled_natural`, 16 tiles round the walled hall); when the threat is only there, there is no edge post at
  all ("above the enemy below" is gone too): the line meets it at the wall (`_wall_plan`, the gate post, or AI._defend).
- The gate post comes at half the wall closed (`GATE_CLOSED` 0.7 -> 0.5; against the Clockwork the wall seldom reached 0.7
  before its first push).

### 3. The Clockwork's raid answers (scripts/ai_cw_push.gd, scripts/ai_cw_army.gd)
- RIDERS: armed foes round the push that are all faster than its front (1.2 times its slowest front unit or more) and worth
  less than 260 and 15% of the push together are not a fight: the march goes on and the front shoots what comes in reach
  ("1 fast rider (115 value) round it: it does not chase them, the march goes on").
- LEASH on the march: a front unit chasing a foe more than 300 px from the anchor walks back to it (a plain move).
- CHASE CAP in a fight: the anchor walks toward enemies it cannot reach at most 360 px from where the fight began.
- KEY BUILDING: a hall or Mainspring under 35% with armed enemies at it calls the push home even for a small raid ("its
  Clocktower at ... is about to fall"); otherwise only a real attack does (as before: 350 or more); a token raid is met by
  the units at home (clockwork-home's group).
- A whole-army defence gives up a chase: a unit 520 px out from its buildings after a foe that is itself 360+ px out walks
  back to the gathering point ("gives up a chase ... back to its gathering point"). clockwork-home's rule (the whole army
  defends a real attack on the base) is kept.

### 4. The AI STORY
New rows in `scripts/ai_story_lines.gd` (pt/es in `tools/i18n/57_ai_followups.txt`): the push that does not chase riders,
the push turning home for a building about to fall or a real attack, the push going out, the army giving up a chase, the
whole army defending the base, a small raid met by a group, the base calm again, the Crown putting its army first, a
milestone waiting for the army. (The Clockwork's army and push lines had no rows: they showed as plain English details.)

## Numbers

All games: Hard OPTIMAL v Hard OPTIMAL, 12:00, seed 1, `tools/play_ai_optimal.gd` (now with `every:60`, `diag:1` and a
FIRSTWAVE line: where the Crown's muskets stood when 300+ of enemy army first came within 500 px of its buildings).
"Before" = this branch's merges without this job (7a3f545c), "after" = the job's last commit.

Crown army value at 4:00 / 6:00 / 8:00 / 10:00 / 12:00 (the enemy's in brackets), income earned by 8:00, the end:

| map, enemy | before: Crown army (enemy) | after | income by 8:00 before / after (Crown/enemy) | end before / after |
|---|---|---|---|---|
| Dune Sea v Clockwork | 0/120/175/0/0 (210/995/2530/4120/6520) | 0/460/1015/1530/880 (210/995/2345/2065/4440) | 4940/9431 / 6080/9090 | 12:00 winner none / 12:00 winner none |
| Dune Sea v Brood | 0/180/525/0/0 (175/725/3120/3885/0) | 0/180/535/0/0 (175/650/2690/3280/0) | 7600/10572 / 7600/10900 | 11:41 winner P2 / 11:57 winner P2 |
| Greenhold v Clockwork | 0/0/285/1400/955 (210/1065/2010/2985/4515) | 0/60/530/0/0 (210/995/2850/4565/6165) | 5700/8817 / 4940/9388 | 12:00 winner none / 12:00 winner none |
| Greenhold v Brood | 0/300/0/0/0 (175/950/2955/4345/0) | 0/300/120/0/0 (175/950/2700/4335/0) | 5700/10663 / 6460/11017 | 11:26 winner P2 / 10:57 winner P2 |
| Red Coast v Clockwork | 0/0/180/60/0 (210/1135/2950/5090/7170) | 0/60/525/180/0 (210/1065/2705/4250/5960) | 6460/9205 / 6080/9401 | 12:00 winner none / 12:00 winner none |
| Red Coast v Brood | 0/425/125/125/0 (200/815/2880/4285/0) | 0/240/0/0/0 (200/815/2330/3835/0) | 6460/10834 / 7220/11140 | 11:17 winner P2 / 11:05 winner P2 |
| Kestrel Rise v Clockwork | 0/120/1255/2020/0 (0/0/0/0/0) | 0/135/1140/2235/0 (0/0/0/0/0) | 6840/6047 / 7600/6179 | 10:07 winner P1 / 11:00 winner P1 |
| Kestrel Rise v Brood | 0/240/375/350/795 (500/1175/3630/4610/4435) | 0/240/295/115/0 (500/1065/3545/4680/4605) | 7220/10918 / 6840/10584 | 12:00 winner none / 12:00 winner none |

Where the Crown's line stood when the first enemy wave came (muskets by its palisade / on the main's high ground /
elsewhere; gate post up), and the Clockwork's raid answers (riders not chased, chases given up, groups, whole-army
defences, pushes pulled back):

| map, enemy | first wave before | after | cliff-edge moves before / after | Clockwork: riders not chased, chases given up, groups, whole army, push pulled back (before -> after) |
|---|---|---|---|---|
| Dune Sea v Clockwork | - | 6:03: 0 / 1 / 0, gate no | 7 / 7 | 0, 0, 0, 0, 0 -> 4, 0, 3, 2, 1 |
| Dune Sea v Brood | - | 7:21: 9 / 1 / 0, gate up | 2 / 0 | - |
| Greenhold v Clockwork | 7:02: 2 / 0 / 0, gate up | 5:57: 0 / 1 / 0, gate no | 1 / 7 | 0, 0, 0, 2, 1 -> 7, 0, 0, 0, 0 |
| Greenhold v Brood | 6:49: 6 / 0 / 0, gate up | 6:53: 8 / 0 / 0, gate up | 3 / 1 | - |
| Red Coast v Clockwork | 7:06: 0 / 0 / 0, gate up | 6:49: 3 / 0 / 0, gate up | 0 / 8 | 0, 0, 0, 1, 0 -> 5, 0, 0, 1, 0 |
| Red Coast v Brood | 6:53: 5 / 0 / 0, gate up | 6:56: 7 / 0 / 0, gate up | 14 / 4 | - |
| Kestrel Rise v Clockwork | - | - | 3 / 1 | 0, 0, 0, 0, 0 -> 0, 0, 0, 0, 0 |
| Kestrel Rise v Brood | 7:11: 8 / 0 / 0, gate up | 7:08: 5 / 0 / 0, gate up | 2 / 0 | - |

What the tables say (one seed a map, so a direction, not a verdict):
- Against the Clockwork the Crown's army at 8:00 rose on Dune Sea (175 -> 1,015), Greenhold (285 -> 530) and Red Coast
  (180 -> 525), and was the same on Kestrel Rise (whose Clockwork never built an army). It still loses the game: the
  Clockwork earns 1.4-1.9 times the Crown by 8:00 (the open question below), and on Greenhold the after game's first push
  came a minute earlier (5:33 against 6:31: the riders it no longer chased did not stop it) and broke the Crown at the
  natural, where the before game's Crown survived to 12:00 with 955. The "army first" line appeared 2-6 times a game
  against the Clockwork, never against the Brood (by design).
- Against the Brood nothing in the Crown's rules changed; the differences are the game's own spread.
- The cliff edge: before, 12 moves "above its Palisade", 4 "above its Gate" and 10 "above its Town Hall" (the natural's);
  after none of those. What is left is "above its Cottage" (26 moves): Cottages the layout puts below the main, outside
  the natural's wall.
- The Clockwork's push left 4-7 lone riders unchased a game and none of its pushes turned round for one; no chase had to be
  given up at home (the HOME test shows the rule).
- With the wall's coins kept (`-- wallkeep:on`, a second run of all games): the Crown's army at 8:00 was 650 / 0 / 370 on
  Dune Sea / Greenhold / Red Coast v the Clockwork, and the line still met the first push without a gate post: left off.
  Ashford Crossing seed 1 v the Clockwork: before 530 at 8:00 (2,330), with the wall keep 290 (2,900).

The owner's seed (Ashford Crossing 2091978150, to 10:00): before, the Crown's army 60 / 350 / 230 at 6:00 / 8:00 / 10:00
against 685 / 1,385 / 2,315, the line "on the cliff edge above its Palisade" at 6:26-6:33 (the owner's complaint, again).
After: 120 / 1,005 / 1,290 against 685 / 920 / 1,890 in one run, 60 / 350 / 585 against 685 / 1,360 / 2,335 in another
(with the wall's coins kept): one seed swings that much between runs, so the tables above are a direction, not a verdict.
No "cliff edge above its Palisade" after.

## Tests
- NEW `tools/test_cw_raid_leash.gd` (staged, a Hard Clockwork against a Crown whose computer is off): PUSH: a Horseman at
  its Clocktower and a bait rider kiting just out of reach behind the push toward its home: the push does not go home, its
  anchor does not walk back, it gets 200+ px nearer its goal in 40 s, no front unit strays 700+ px for more than 8 s.
  HOME: a rider hits a Cog Press then rides off across the map: after 40 s no soldier is more than 900 px from its
  buildings. Before: the push stood still (1,387 -> 1,387 px from its goal) and a front unit chased for 33 s: FAIL; after:
  ALL PASS (1,386 -> 1,016 px, longest stray 3 s).
- `tools/test_ai_optimal.gd` case 7 (THE ARMY FIRST): Crown OPTIMAL v a greedy Clockwork: pressure on, an army worth half
  the reckoning by 8:00 (1,285 of 1,400, 26 supply for 37 labourers), no Church or Armoury laid while the army lagged, the
  story line: ALL PASS.
- test_files, test_i18n, test_crown_stall, test_crown_ammo, test_ai_wall_vs_rush (after the margin fix), test_ai_optimal,
  test_clockwork_home check:1, test_clockwork_army check:1: PASS.

## Claude's choices for the owner
- LAG_SHARE 60% (90% after a greedy read) of the enemy army the Crown reckons, from 22 labourers on two halls; the reckoning
  never below a table of the lowest Hard armies seen (the Clockwork 600 at 6:00, 950 at 7:00, 1,400 at 8:00). Lower it if
  the Crown now starves its economy; raise it if it still sits on labourers.
- A "token" raid for the push = all its foes faster than its front, worth under 260 and 15% of it. Two Horsemen (230) are
  a token for a push of 1,600+; three are not.
- The gate post at half the natural's wall closed (was 70%), so the line goes down to the palisade sooner.
- The cliff edge is skipped for anything inside 16 tiles of a walled natural's hall once one piece of its wall is down.

## Open questions
- **The Crown's economy is the bigger gap.** In every game it earned 55-75% of the Clockwork's by 8:00. Main (before
  crown-optimal-opening) had 12 labourers at 2:00 and 6,460 earned at 8:00 on Greenhold seed 1; with crown-optimal-opening's
  WIP opening (the Barracks before the second Farm) 9 labourers at 2:00 and 4,940-5,700 by 8:00. The gold for the
  Barracks at 0:45 and the farms' lumpy pay leave it with 30 gold from 1:00 to 1:40. That is the owner's decided opening;
  crown-optimal-opening should measure it against the Clockwork before it says DONE.
- The palisade is often not there yet when the Clockwork's first push comes (5:30-6:40): the doctrine lays the natural's
  wall only once the expansion is saturated and the army has a minimum (`AI.wall_yield`), so the first wave meets a line on
  the main's high ground or at the ramp in most Clockwork games (FIRSTWAVE above). Earlier walls cost labourers or army;
  the owner's own palisade went down 3:49-5:42.
- The Clockwork on Kestrel Rise seed 1 had no army at all at any minute, before and after: OPTIMAL picked the Springer plan
  at ~2:50 and it sat at 18 supply and 18 Winders from 3:00 to the end (income still coming: 3,570 by 5:00), so the Crown
  won at 10-11 minutes. A Springer plan stall (supply or a build step that never comes); not looked into here.
- The Crown still loses most games against the Brood at 11:00-12:00 (unchanged by this job: the Brood rules were left
  alone; FOOD_BONUS is the owner's open question).
