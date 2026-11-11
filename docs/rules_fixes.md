# Rules fixes (rules-fixes, 0.33.12)

The owner approved five fixes from the QA study on 2026-11-11 ("ok do it"; docs/qa_2026_11_08_content.md,
docs/qa_2026_11_08_matches.md, docs/qa_2026_11_08_tests.md). This job changes game rules, the HUD and small guards; in the
computer players it touches only the end-of-game hunt and the two script errors (crown-ai-v2 and clockwork-ai-v2 run at
the same time on the computers' play). Test: `tools/test_rules_fixes.gd` (24 checks).

## 1. Cannon and Mortar building damage counted once

Before: `Unit._strike` multiplied a shot's damage by the gun's `building_bonus` when its target was a building, and the
landing (`Game.round_shot_land`, `Game.mortar_land`) multiplied by it again; `Game.explode` (the round shot's splash) used a
fixed x2.5. ATTACK GROUND (`Game.bombard_shot`) passed the raw damage, so it got the bonus once.

| one shot on a building (no armour) | right-click / attack-move / own target (before) | ATTACK GROUND (before) | every path (now) |
|---|---|---|---|
| Field Cannon (damage 32) | 270 = 32 x 2.5 x 2.5 + splash 32 x 2.5 x 0.35 x 2.5 | 108 = 80 + 28 | **270** = 32 x 6.25 x (1 + 0.35) |
| Mortar (damage 30) | 68 = 30 x 1.5 x 1.5 | 45 | **68** = 30 x 2.25 (67.5) |

Now (scripts/unit.gd `_bonus_on_landing`): the round shot (not canister) and the shell skip the bonus at the strike; the
landing applies it once, whatever the gun was aimed at. To keep today's siege punch (the Crown computer is the weakest
side: 0 won-or-led of 38 against the Brood, and its sieges were tuned on the old numbers) the bonus is raised so one
application gives what a right-click gave: **cannon building_bonus 2.5 -> 6.25, mortar 1.5 -> 2.25**
(scripts/defs.gd). `Game.explode` takes the bonus of whatever fired it (a new argument; the round shot passes the
cannon's 6.25; others use the shooter's own, 1 when it is gone) instead of the fixed 2.5.

Side effects to know:
- ATTACK GROUND on a building is now as strong as attacking it (it was 2.5x weaker for the cannon, 1.5x for the mortar).
- The card's chip reads "x6.25 damage against buildings" / "x2.25"; its tooltip adds what one hit does to a building and
  how much a second ("A hit on a building: 270 damage (... a second)", UnitStats.building_hit, which counts the round
  shot's splash; en/pt/es in tools/i18n/60_rules_fixes.txt). test_content_all against a building: cannon 53.4 a second
  measured (its card's plain dps x bonus says 36.7: the splash and the first shot's timing make the rest), mortar 10.6
  against 11.3.
- The computers' siege estimates (AI dps against a wall piece, ai.gd 3529, 6116, 6514) read `building_bonus` and were
  low by 2.5x for the cannon; they are now about right (no AI code changed).
- `Game.explode` is also the retired Line roster's heavy loco splash: it now uses that unit's 1.5 instead of 2.5.
- test_content_all's one-shot check now expects damage x bonus (+ the splash for the cannon) and FAILS if a shot lands
  under 70% of it (the bonus lost) as well as WARN over 130% (applied twice). Measured: cannon 270 / 270, mortar 68 / 68.

## 2. ATTACK hidden on unarmed cards

`Unit.armed()` = `UnitStats.attack_type(kind, d) != "none"` (no damage, a medic, or `no_attack`). The HUD shows ATTACK
only when a selected unit is armed, and A starts the attack mode only then (scripts/controls.gd). Unarmed today: Powder
Wagon, Messenger, Observation Balloon, Marching Band, Missionary and the mounted Missionary, the Great Winder (and the
Brood's egg and food pile, the retired roster's wagons and cars). A mixed selection keeps ATTACK: clicking an enemy, the
armed units attack it and the unarmed ones attack-move (walk) to that spot with them (they used to get an attack order
they could not carry out). Workers keep ATTACK (they can hit). test_hotkeys: 0 failed; test_content_all's "ATTACK on an
unarmed card" WARN is gone (8 WARN left: missing voices and the balloon's walk).

## 3. Dead sides lose, winners hunt

**Helpless = beaten** (scripts/game.gd `helpless`, `_helpless_check`, `HELPLESS_TIME` 60): checked once a second in
`_check_end`. A side is helpless when it has no worker, no armed unit (horses and unarmed carts don't count; a Messenger
counts, he dismounts to a Labourer), nothing in training, and no finished building that trains a unit it can pay for
now (gold). After 60 s in a row it is beaten exactly as when its last building falls: its units die, its remaining
buildings fall, the end screen, and the match log line "P2 Crown is beaten: nothing left to fight with" (instead of
"is out"). A human player gets a warning when the minute starts ("Nothing left to fight with: train a worker or a soldier
within a minute, or the battle is lost.", en/pt/es). The Brood keeps its own rule (it lives while its Mother does) and is
never checked. NOT beaten: a worker or a soldier alive, a unit in training, or a hall (or any production building) with
the price of one of its units in the bank. Campaign missions with their own end are untouched (`_check_end` returns
before).

**The hunt** (scripts/ai_hunt.gd, `AIHunt`, one small object per computer): every 5 s, when the computer's enemy has no
fighting unit left (and has had one, or the game is past 8:00) and the computer has 3+ fighters, its army attack-moves
to the enemy's nearest building (else its nearest unit, the Brood's Mother; else its start), re-sending the idle ones;
the wave logic waits meanwhile. It stops when the enemy fields an army again. Match log: "P1 Clockwork hunts: the enemy
has no army left (N units go for its last buildings)" / "... ends the hunt: ...". The computer already knows where the
enemy's buildings are (as `_enemy_base` does), so no separate scouting walk was needed. Hooked in three places, one line
each: `AI._army` (after the defence), `AIClockwork._army` (before the push and ONE ARMY: the Clockwork's army never
reaches the shared code) and `AIBroodNew._nb_army` (after its defence, when no wave is out).

### Measured

Hard v Hard, OPTIMAL plans, 15:00, the same maps, seeds and sides as docs/qa_2026_11_08_matches.md (tools/qa_match.gd
through tools/study/qa_matches.py's run_one), 20 base games: the 4 dead-side draws that report names, then 16 more over
every pairing and 14 maps. Data in docs/rules_fixes_data/<game>/ (result.json, story.txt). The baseline is v0.33.7, this
run v0.33.12, so other changes since (0.33.8-0.33.11, small) play in too; one seed per game, so read the totals, not a
single row.

**Draws at 15:00: 16 of 20 before, 9 of 20 now.** Every game where one side sat with no workers and no army for minutes
now ends (the minute samples "dead from" show it: a side seen dead at a minute is beaten within about a minute, or the
hunt finishes it); the four named in the report: Frostmere and Highmoor now end at 11:44 and 10:35, Glimmerdeep and Border
March are draws in which no side died this time. The draws left are games where both sides still had an army at 15:00
(Crown mirrors, Clockwork mirrors on big maps, Hollowfen): the hunt only starts once the enemy has no army, so a weak but
living army still holds a draw. No script errors in any of the 20 games (both errors of item 4 were seen in this
kind of game before).

| game | sides (P1 v P2) | before (0.33.7) | now (0.33.12) | errors |
|---|---|---|---|---|
| base_amberfall_vale_crbr_r0 | crown v brood | draw 15:00 P1 dead from 15:00 | P2 won 14:15 P1 dead from 14:00 | 0 error lines |
| base_ashfall_crcw_r0 | clockwork v crown | draw 15:00  | P1 won 13:48 P2 dead from 13:00 | 0 error lines |
| base_border_march_crcr_r0 | crown v crown | draw 15:00 P1 dead from 12:00 | draw 15:00  | 0 error lines |
| base_cinder_steps_cwcw_r0 | clockwork v clockwork | draw 15:00  | P1 won 14:15  | 0 error lines |
| base_dune_sea_crcw_r0 | crown v clockwork | draw 15:00 P2 dead from 13:00 | draw 15:00 P2 dead from 15:00 | 0 error lines |
| base_frostfang_crcw_r0 | clockwork v crown | P1 won 14:01  | P1 won 10:11 P2 dead from 10:00 | 0 error lines |
| base_frostmere_crcw_r0 | clockwork v crown | draw 15:00 P2 dead from 10:00 | P1 won 11:44 P2 dead from 11:00 | 0 error lines |
| base_frostmere_cwcw_r1 | clockwork v clockwork | draw 15:00  | draw 15:00  | 0 error lines |
| base_glimmerdeep_crcw_r1 | clockwork v crown | draw 15:00 P2 dead from 11:00 | draw 15:00  | 0 error lines |
| base_greenhold_crbr_r0 | crown v brood | P2 won 11:17 P1 dead from 11:00 | P2 won 13:03 P1 dead from 13:00 | 0 error lines |
| base_greenhold_cwcw_r0 | clockwork v clockwork | draw 15:00  | P1 won 12:54 P2 dead from 12:00 | 0 error lines |
| base_highmoor_brcw_r0 | clockwork v brood | draw 15:00  | P2 won 13:54  | 0 error lines |
| base_highmoor_crcw_r0 | clockwork v crown | draw 15:00 P2 dead from 13:00 | P1 won 10:35 P2 dead from 10:00 | 0 error lines |
| base_hollowfen_crcw_r1 | crown v clockwork | draw 15:00  | draw 15:00  | 0 error lines |
| base_kestrel_rise_crcr_r0 | crown v crown | draw 15:00 P1 dead from 14:00 | draw 15:00  | 0 error lines |
| base_mirewood_brbr_r0 | brood v brood | P2 won 14:02  | P2 won 14:05  | 0 error lines |
| base_red_coast_brcw_r0 | brood v clockwork | P1 won 13:07 P2 dead from 13:00 | draw 15:00  | 0 error lines |
| base_saltmarsh_isles_cwcw_r0 | clockwork v clockwork | draw 15:00  | draw 15:00  | 0 error lines |
| base_thornwood_maze_crcr_r1 | crown v crown | draw 15:00  | draw 15:00  | 0 error lines |
| base_twin_fords_brbr_r0 | brood v brood | draw 15:00  | P1 won 12:48  | 0 error lines |

("dead from" = the first minute sample where that side had no workers and no army value.)

## 4. The two script errors

- `ai_crown_siege.gd:501` ("Left operand of 'is' is a previously freed instance", 201 times in base_glimmerdeep_crcr_r0):
  the siege's `anchor` was a building freed at once without dying: `Game._remove_quietly` frees a palisade piece the
  enemy turns into a gate (and a wall laid over a gate), and a dropped site. `_alive(anchor)` was safe, the `anchor is
  Building` test after it was not, so the function stopped there every tick and the siege stood still for the rest of the
  game. Now a freed anchor is forgotten first (`anchor = null`), and the siege picks the next one or marches on. (The dead
  `k == "?"` lines are gone.)
- `ballista.gd:400` ("Nonexistent function 'has_tag' in base 'Nil'", 9 times in three Clockwork mirrors): `Ballista._worth`
  cast every non-building target to a Unit, but `Game.find_target` also gives a Clockwork crate or a powder keg lying on
  the ground (Entities that are neither): they now score 0.5 (last of all) and the Ballista goes on picking.

## 5. Missing animations

- The dismounted Officer asked for `reload` between pistol shots (no strip): `_anim_or("reload", "idle")`.
- The uprooted Mound Turtle asked for `attack`: `BroodNew.anim` asks for `attack` only when the art has it
  (`BroodNew.has_strip`), else walk/idle.
Both showed idle already (Unit._set_anim's fallback); now they ask for an existing strip and the content test no longer
lists them. Logged for the owner to draw: docs/art_redraw_queue.md items 63 and 64, docs/art_style_inconsistency.md
"Missing strips the game asks for".

## Tests run

test_files (1303 checks, 0 failures), test_i18n (PASS), test_content_all (0 FAIL, 8 WARN), test_hotkeys (0 failed),
test_crown_ammo (0 failures), test_replay (ALL OK), test_rules_fixes (0 failures), test_ballista (ALL PASS), test_loose_horses (ALL PASS), test_brute_siege (0 failed), test_unit_stats (0 failures),
test_brood_new (0 failures), test_ai_wall_vs_rush (ALL PASS), test_ballista_ai (1 FAIL: "its escort Winders crew it", the
known flaky check of docs/qa_2026_11_08_tests.md, "pass, FAIL, pass" there; nothing here touches the Winders' crewing).

## Claude's choices for the owner

- **Bonus values**: 6.25 and 2.25 are the old right-click numbers exactly. ATTACK GROUND on buildings got 2.5x (cannon) /
  1.5x (mortar) stronger as a result; if bombarding buildings feels too strong, lower the bonus (it now means the same
  thing on every path, so any value is honest).
- **What counts as "a way to make more"**: a building that trains a unit whose GOLD price is in the bank (the second
  resource and supply are not checked: a side with gold but a full supply cap is not called helpless). A Crown side with
  a hall and 0 gold and no worker is beaten (no farm can work without a worker). The task's line "a hall standing ... is
  NOT beaten" was read together with "no money to make a worker": a hall alone, with no money and nobody, is beaten.
- **Static defences** (a tower, a turret) do not keep a side alive: they cannot rebuild anything.
- **Buildings of a beaten side** fall with it (its units die as before), so a 3-4 player game does not keep empty
  buildings of a side that is out.
- **The hunt's start**: "the enemy has no army" = no armed non-worker unit. To keep it from turning early openings into
  hunts (before the enemy trained its first soldier) it starts only once the enemy has had an army, or from 8:00.
- **Saves**: the helpless clock is not saved; a game loaded mid-minute starts the minute again.
