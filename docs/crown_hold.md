# The Crown holds its walled natural (0.33.1, branch crown-hold)

The owner watched a Hard Brood (Economy) v Hard Crown (Economy) game on Dune Sea, seed 693532400, v0.33.0
(`docs/playtests/2026-11-06/crown_v_brood_eco_log.txt`, pictures `crown_gate_far_from_ramp.jpg` and
`crown_army_on_high_ground.jpg`): "Crown went much better this time", but it lost at ~8:37 to the Brood's attack on its
walled natural. His five points, and what was done about each.

Design: docs/design_principles.md 2 (the defender's advantage: walls, gates and high ground used where the fight is) and 3
(meaningful base building: the gate where the army goes out, a site that can be built).

## 1. The gate went on the far stretch of the palisade

**What was wrong.** The walled-expansion planner (`scripts/ai_expand_wall.gd`, docs/crown_wall_expand.md) put the gate,
when the main's ramp comes down inside the wall, on the ways-in cell *nearest the enemy by land* ("where the expansion's
men leave"). On Dune Sea the enemy's shortest walk comes in over the far (northern) stretch, so the gate went there, 17
steps from the ramp's foot: the army coming down the ramp had to cross the whole natural to get out ("waaay over the top
of the palisade in a bad spot").

**What changed.** `AIExpandWall._gate_by_ramp`: the gate goes on the ways-in cell the fewest steps by land from the
**foot of the main's ramp** (a walk from every foot cell, `_walk_steps_from`), and its second cell beside it; the enemy's
steps only break a tie among cells within `GATE_TIE` 3 steps of the nearest. With no ramp off the main, the old "nearest
our main by land" stays. The plan keeps `gate_ramp` (the steps), and the match log's gate-post line says it.

**Numbers** (`tools/test_crown_gate.gd`: the Hard Crown's own 2nd-hall pick on each map, both sides, its wall plan;
steps by land from the main's ramp foot to the gate):

| Map | side 0 now / before | side 1 now / before |
|---|---|---|
| Dune Sea | 7 / 17 | 6 / 17 |
| Greenhold | 7 / 17 | 6 / 17 |
| Red Coast | 6 / 7 | 6 / 7 |
| Ashford Crossing | 6 / 10 | 6 / 7 |
| Highmoor | 6 / 7 | 6 / 7 |
| Thornwood Maze | 8 / 11 | 9 / 11 |

(About 6 is the least: the ground within 4 tiles of the ramp's foot is kept inside the wall, RAMP_CLEAR.) Picture:
`docs/shots/crown_hold/dune_sea_after_540.png` (5:40 of the owner's seed: the gate beside the ramp, the army behind it).

## 2. The army stayed on the high ground

**What was wrong.** The doctrine's home post (`scripts/ai_crown_hold.gd` section 1, THE RAMP POST) is the top of the
main's ramp, whatever else the Crown has; the army went down to the natural's palisade only once the Brood was at it
(`_wall_plan`, crown-owner-eco C), too late and by a detour (the gate far away).

**What changed.** A new section 7, **THE GATE POST** (`AICrownHold._gate_plan`, `gate_live`): once the Crown has a
walled natural (an expansion whose wall plan is closed at least `GATE_CLOSED` 70% and whose gate stands; the nearest
such hall to the main), the waiting army's HOME post is down at that gate: the Musketeers in rows 1.2-3.8 tiles inside
the stretch of palisade either side of the gate (8 tiles of it), nearest the gate first, a lane 1.2 tiles wide kept open
behind the gate itself; the guns 3.8-7 tiles in; all on HOLD facing out. Riders and the rest rally behind the line
(`home_front`), and a labourer who runs from raiders runs in behind it (`refuge`). The post is planned again every 20 s
(every 3 s while there are more muskets than places), never on a wall slot waiting for its building or on a site.
- An attack on another stretch of that palisade moves the line along it (the old `_wall_plan`, unchanged).
- A threat it can beat (BEAT, or `AICrown.hold_beat` against the Brood) is met the usual way (`AI._defend`); against a
  bigger force it **holds the gate** and says so ("holds its natural's gate: the force outside (x) is too strong to go
  out to with its army at home (y)").
- The ramp post stays for the main alone (no walled natural yet, or the natural lost), the cliff-edge post for a
  building under the cliff while there is no walled natural. Study switch `-- gatepost:off`.
- AI STORY: "P2 Crown posts its army down at its natural's gate: room for 6 Musketeers behind the palisade and 2 guns
  behind them." and "... holds the gate of its walled natural ...", "... moves its army along the palisade to where it is
  attacked (a line of 9 behind the wall)", "... moves its musket line to the cliff edge above its Town Hall.", "... looks
  for another spot for its Barracks: the first one stayed blocked." (tools/i18n/49_spectator.txt, pt and es).

In the replays the gate post was set up between 4:27 and 8:11 (5:19 on the owner's seed), in 11 of 13 games (not in the two
Clockwork games on Greenhold and Dune Sea 2: no natural wall 70% closed with its gate up while the army waited).

## 3. Units shoved off a site walked back onto it

**What was wrong.** A unit standing on a placed site was asked to step aside (`Game.step_aside`) to the nearest cell
*touching* the footprint (still overlapping it, its radius), as a plain move: a unit on HOLD lost its HOLD, its leash
stayed on the site, and the computer's post logic (`AICrownHold._post`: muskets on HOLD at their spots, the wall line
1-3 tiles behind the palisade, where the wall's empty building slots are) sent it straight back to its spot on the
site at the next think. After `GHOST_WAIT` 5 s still blocked the site was dropped: "couldn't start a Church/Barracks:
the spot was blocked (refunded)" six times at 6:41-7:47 in the owner's game, the same Barracks spot four times.

**What changed (for the player's units too).**
- `Game.spot_outside`: a cell's margin clear of the footprint first (ring 2, then 3, 4; the touching ring 1 only when
  there is no room farther out).
- `Game.step_aside`: a unit on HOLD holds again where it stepped to; an idle unit's leash moves there.
- `Game.site_keepout(team, point, radius)`: a point inside an allied site still waiting to start (its footprint grown by
  10 px and the unit's radius) is moved just outside it. `Unit.cmd_move` uses it for every ground unit (a move, a rally,
  a guard post, the computer's re-posting), and `AICrownHold._post` keeps its HOLD spots off sites the same way, so
  nobody is walked back onto a waiting site. The gate and wall posts also skip the wall's empty slots.
- `AI.site_failed` with "blocked": that spot (its footprint) is held as terrain for `BAD_SITE_T` 90 s while the
  computer looks for a spot (`AI._find_spot` wraps `_find_spot_any`, which `AICrown` now overrides), so it picks
  another; the match log says "looks for another spot for its Barracks (that one stayed blocked)".

**Test.** `tools/test_build_shove.gd`: six Musketeers on a Barracks (or Church) footprint, for the player and the
computer: on HOLD, idle, and GUARDING (sent back to their post inside the footprint four times a second, as the
computer's posts are on every think). Each site must start, nobody may stand inside it, the HOLD men must be on HOLD
again; a blocked computer site must make the next pick another spot; the keep-out point. On 0.33.0 it fails as the
owner's game did: both GUARD cases "dropped as blocked", 0 / 6 on HOLD after stepping aside, the same spot picked again.
Now all pass (the sites start in 2-5 s).

In the replays: 0-1 blocked sites per game before and after (the owner's game had 6; the replays do not follow it move
for move).

## 4. One cannon, then the Mortar

**What was wrong.** `AI._produce` (shared by every Crown plan) trained a Mortar as soon as there were 6 Musketeers (one
per 6, two at most) and a cannon only while `cannons * 4 < army + 2`; the siege push asked for its Mortars once its
cannons were at 1 + muskets / 5. So: 1 Field Cannon, then the Mortar (7:14-8:27 in four of the before games). And the
Barracks spent every coin first, so a second cannon seldom came at all (the most cannons any before game had: 2).

**What changed.**
- `AI.CANNONS_FIRST` 3: no Mortar until 3 Field Cannons are out or queued, in every Crown plan, the siege push too
  (`AICrownSiege._gun_want` asks for a cannon instead while its Mortars wait).
- MASS CANNONS FIRST: while fewer than 3 cannons are out or queued, the line has `GUN_LINE_FIRST` 4 Musketeers, a
  Foundry stands idle that may cast one and the enemy is not at home, the Barracks wait for the gun's gold
  (`AI._produce`) and the tech milestones (Church, Armoury...; not production) wait too (`AICrown.guns_short`,
  `-- gunmass:off`).
- The Foundry before the second Barracks is unchanged (test_crown_stall, test_ai_optimal pass).

After: 3 Field Cannons by 9:00-11:00 (the minute summaries) in 3 of the 8 Economy games v the Brood and in the Balanced
one, 2 in four more (before: 1 in most games, never more than 2); no Mortar in any game by 12:00 (before: the Mortar at
7:14-8:27 in four games, after one or two cannons). The Economy plan spends most of its gold on halls, farms and walls,
so the third cannon still comes late there. No plan's doc makes the Mortar its point
(the siege push's doc, crown_builds_b.md, wants both guns), so no plan is exempt.

## 5. Is the Brood's attack on the natural holdable now?

Replays with `tools/play_ai_optimal.gd`, both computers Hard, 12:00 of game time each (the result says "none" at 12:00
when nobody has won; "first hall lost" is the Crown's first Town Hall lost; "-" = none lost by 12:00). Before = 0.33.0
(main), after = this branch. One game per row: the games do not replay move for move, so a single row is noisy.

### v the Brood (Hard Crown Economy v Hard Brood Economy unless noted)

| Game | first hall lost before / after | Crown alive at 12:00 before / after (halls, workers) | Crown kills / losses before | after | peak Crown army before / after |
|---|---|---|---|---|---|
| Dune Sea 693532400 (the owner's seed, Brood P1) | 8:37 / 11:31 | dead at 11:40 / 2 halls, 34 workers | 86 / 102 | 249 / 68 | 1,635 / 3,040 |
| Dune Sea 1 | 10:15 / 9:58 | 2 halls, 8 / 3 halls, 5 | 13 / 78 | 137 / 46 | 2,005 / 2,095 |
| Dune Sea 2 | 10:52 / - | dead / 3 halls, 29 | 68 / 106 | 228 / 53 | 1,685 / 2,620 |
| Dune Sea 4 | 8:59 / - | dead / 4 halls, 66 | 86 / 115 | 168 / 32 | 1,685 / 2,745 |
| Dune Sea 5 | 9:07 / 11:21 | dead / 3 halls, 59 | 44 / 84 | 130 / 19 | 1,380 / 2,515 |
| Greenhold 1 | 10:18 / 10:19 | dead / dead | 7 / 92 | 17 / 92 | 1,980 / 2,345 |
| Red Coast 1 | 9:53 / 8:59 | dead / dead | 63 / 75 | 129 / 98 | 1,240 / 1,620 |
| Ashford Crossing 1 | 9:30 / 9:48 | dead / dead | 52 / 82 | 76 / 102 | 1,720 / 1,360 |
| Dune Sea 3 (Crown Balanced v Brood Rush) | - / 10:53 | 3 halls, 29 / 3 halls, 48 | 67 / 12 | 77 / 9 | 1,450 / 2,330 |

- Economy v Economy, 8 games: the Crown still had a base at 12:00 in **1 before, 5 after**; the first Town Hall fell at
  9:41 on average before, 10:45 or later after (the games still standing at 12:00 counted as 12:00); the Crown's kills
  went from 419 to 1,134 and its losses from 734 to 510.
- The owner's own seed: the Brood's attacks on the natural were held (it lost a Town Hall only at 11:31, killed 249 for
  68). Pictures: `docs/shots/crown_hold/dune_sea_after_952.png` (9:52, the line and the guns at the natural's gate,
  beside the ramp, the Brood on the palisade).
- Greenhold, Red Coast and Ashford Crossing are still lost by 12:00: the Brood's army there is worth 2-3 times the
  Crown's from 8:00 (its income runs 1.4-2 times the Crown's: the FOOD_BONUS question the owner left open, "NOT YET").

### v the Clockwork (Hard Crown Economy v Hard Clockwork Economy)

| Game | first hall lost before / after | at 12:00 before / after | kills / losses before | after |
|---|---|---|---|---|
| Greenhold 1 | - / 7:08 | 2 halls / dead | 10 / 57 | 11 / 73 |
| Red Coast 1 | 9:33 / - | dead / 3 halls, 53 workers | 15 / 69 | 54 / 28 |
| Ashford Crossing 1 | 10:15 / 11:17 | 1 hall / 1 hall | 11 / 66 | 12 / 66 |
| Dune Sea 2 | 10:31 / 11:18 | 2 halls, 14 workers / 1 hall, 0 workers | 9 / 81 | 16 / 89 |

Mixed: one game much better (Red Coast), one much worse (Greenhold: the Economy plan had 1-2 Musketeers at 6:00 and was
supply-blocked at 44/44 when the Clock Soldiers came; the gate post and the cannons did not come into it: it never had 4
Musketeers nor a walled natural). Kills 45 before, 93 after; losses 273 before, 256 after.

## Tests

- New: `tools/test_build_shove.gd` (point 3), `tools/test_crown_gate.gd` (point 1), `tools/shot_crown_hold.gd` (the
  pictures, xvfb).
- Passing: test_files, test_i18n, test_crown_stall, test_ai_optimal, test_ai_wall_vs_rush (the wall at 37 s, Musketeers
  at 128-158 s as before), test_expansion_spots, test_crown_ammo, test_build_shove, test_crown_gate.
  test_expansion_spots failed once in three runs on this branch (Red Coast, 4 players, all Clockwork: "(41, 67) is marked,
  its twin (64, 9) is not") and passed the other two with no change between them: a flaky twin check, noted here.
- The replays: `play_ai_optimal.gd` with a list file (`a sa b sb map seed end` per line), each 4-7 minutes of real time.

## Claude's choices for the owner

- **When the army moves down**: once the natural's wall is 70% closed *and* its gate stands (before that, the wall's
  guards and the ramp post as before). Earlier (as soon as the hall stands) would put the army in an open half-ring.
- **The lane**: the line stands either side of the gate, not in front of it, so the army can file out; the guns stand
  behind the middle.
- **The main is left to its ramp wall** while the army is at the gate: a drop or a flier in the main is met by
  `AI._defend` as before. Against the Clockwork's round-5 hold (a big wave at the main's ramp) the old rule still pulls
  the army up.
- **A bigger force at the gate**: the army holds the gate (it does not climb back to the main); the labourers run in
  behind the line. If the natural's hall falls the post goes back to the ramp's top.
- **3 cannons** (the owner said "3 to 4"); the Barracks and the tech wait for them only once the line has 4 Musketeers
  and the enemy is not at home, so a rushed Crown still trains Musketeers first. The siege push keeps its Mortars, after
  3 cannons.
- **Blocked spots** are avoided for 90 s, for every kind of building (the same footprint only).

## Open questions

- The Brood's economy: with the gate held, the Crown now survives most Dune Sea games to 12:00, but on the other three
  maps the Brood's army is 2-3 times the Crown's by 8:00 and the natural still falls (FOOD_BONUS 1.5 -> 0.8 waits on the
  owner).
- The Crown Economy plan v the Clockwork on Greenhold had almost no army at 6:00 in one game (supply-blocked): worth a
  look apart from this job.
- The gate post's line counts places, not men: with 4 Musketeers it still lays out 6 places (the extra ones empty).
- Should the line stand at the gate of the 3rd hall too once that one is walled and the natural is not attacked?
  For now the natural (the walled hall nearest the main) is the home.
