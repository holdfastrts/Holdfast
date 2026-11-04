# The Brood's written builds: Spitter timing and Brute siege (branch brood-builds)

The owner (2026-11-03, "do it all", queued until brood-ai-tune was merged): two new WRITTEN BUILDS for the Brood
computer, each coached like the other coached builds (docs/clockwork_builds_a.md, docs/crown_builds_b.md): filmed games
against the Hard Crown and the Hard Clockwork on several maps, pictures, rounds of fixes, numbers against the Balanced
plan.

1. **SPITTER TIMING**: the Venom Sire early, a Spitter-backed wave at a set time, the economy growing behind it (not an
   all-in; it can come home: docs/design_principles.md 2).
2. **BRUTE SIEGE**: Brutes lead a push that breaks the Crown's walls and the Clockwork's turret lines, the army behind
   them goes in through the breach, and it falls back when the push is losing.

No unit, building or economy number was changed (the owner's rule): every number below is the computer's own
behaviour; balance ideas are proposals at the end. Pictures with captions: `docs/shots/brood_builds/`.

## 1. What it is

- Two plans the player can pick for a Brood computer in the lobby's PLAN list: **Spitter timing** (pt *Ataque de
  Cuspidores*, es *Ataque de Escupidores*) and **Brute siege** (pt *Cerco de Brutamontes*, es *Asedio de Brutos*).
  `AI.STRATEGIES["spitter"]` / `["brute"]`, "brood_only": the Crown and the Clockwork don't get them; RANDOM PLAN may
  pick them for the Brood (`AI.strategies_for("brood")`).
- The Brood's own computer plays them (`scripts/ai_brood_new.gd`, `PLANS["spitter"]` / `["brute"]`: both are eco plans
  like Balanced, with a `"build"` key). The push itself is its own file, **`scripts/ai_brood_builds.gd`** (a helper
  object, `AIBroodNew.bb`, made when the plan has a "build"). Small hooks in `ai_brood_new.gd`: before a wave leaves
  (`bb.decides()` / `bb.may_go()`: the build decides when its push goes instead of the plan's size, edge, wall and
  Pack Hunt rules), when it left (`bb.started`), every think of a wave out (`bb.tick`: 0 leave it to the Brood
  computer, 1 the build steers it, 2 call it home), when it ends (`bb.ended`), what it lays (`brute_cap`,
  `save_for_spitters`, `save_for_brutes`), what it researches first (`research_first`, `research_only`), the spoils
  it keeps (`spoils_keep`, `spoils_want`, `spoils_first`), when its Sires come (`sire_first`, `hold_storm`) and its
  supply (`supply_ahead`). Everything else (economy, defence, the alarm, the retreat rules, later waves) is the
  Brood computer as brood-ai-tune left it.
- The AI STORY tells both (`scripts/ai_story_lines.gd`, texts in `tools/i18n/53_brood_builds.txt`): "P1 Brood plans a
  Spitter timing...", "P1 Brood's Spitter timing goes out: 28 supply, 11 Spitters behind a pack of Raptors.", "P1
  Brood's Brutes batter the enemy's Gate while its Spitters cover them.", "P1 Brood's Brutes break through: the swarm
  pours in through the gap.", "... Brute siege falls back: the way in still stands."
- Easy plays the same plans with Easy's usual slowing (the wave time +2 minutes, fewer grubs).

## 2. The Spitter timing

### Build order (on the Balanced economy)

| | Spitter timing | (Balanced) |
|---|---|---|
| grubs a minute on the curve, most grubs | 7, 50 | 7, 54 |
| the Tyrant Sire | 12 grubs or 2:20 | 13 or 2:30 |
| the natural turtle, the third Rootmaw, far turtles | at once, as Balanced; far turtles by 0:00, 5:00, 9:00 | 0:00, 5:00, 9:00 |
| the Venom Sire | from 3:30 with 18 grubs: **his food is saved** (the grub curve waits for him) | 6:00 (or egg-bound) |
| research | **only the build's own until the timing: the Venom line's BIGGER CLUTCH the moment he is on his nest**; Long Spit and the rest after | Bigger Clutch (Raptors), Pack Hunt... |
| eggs | one Spitter for each Raptor ("venom" mix); **food is kept for the next Spitter egg** instead of a Raptor while the Spitters are behind | one Spitter for two Raptors |
| spoils | its own first: the Spitter eggs' and Bigger Clutch's; none kept for her stage 3 until the timing went | |
| supply | 6 more ahead from 4:00 (three Spitters hatch from an egg with Bigger Clutch) | |
| the Storm Sire | waits for the timing (unless flyers are seen) | egg-bound |

**THE TIMING** (`AIBroodBuilds.may_go`): from **6:30** (`wave_t` 390) once **10 hatched Spitters** stand and the army is
22 supply; at the latest at **8:30** (`TIMING_LATE`) with what it has (16 supply). It still does not go into a fight
it can't win (its army under 85% of 0.6 times the biggest enemy army seen lately; 0.4 against the Clockwork), and the
Brood computer's alarm holds it home while an enemy army is out of its main (75 s).

**THE MARCH**: at the Spitters' pace. The Spitters attack-move to the target; the Raptors keep 2 tiles ahead of the
Spitters' middle instead of running ahead alone (`FRONT`). **CONTACT** (enemy soldiers or a turret within 11 tiles of
the Spitters, or the target reached): the Raptors go in, the Spitters spit from behind them. From then on the Brood
computer fights the wave as always (its retreat rules: under half left with more ahead, and so on), with one more
rule: **once what it goes for next is behind a wall or gate it knows and it has no Brutes, it comes home** with what it
took. Later waves are the plan's (every 8 supply more), as Balanced.

### What the coaching found (rounds A, B, D)

| | round A (first draft) | round B | round D (final) |
|---|---|---|---|
| economy | its own: grubs 5.5 a minute, the Venom Sire before the grub curve, grubs held at 32 | the same | **Balanced's** |
| food earned by 6:00 / 8:00 | 3,150-3,360 / 4,200-7,630 | 3,320-3,590 / 4,640-7,050 | **3,630-5,150 / 7,350-10,150** |
| the timing left at | 7:46-9:40 (9 to 24 Spitters) | 7:43-8:10 (8 to 10 Spitters; b04 never went) | **6:53-8:23 (10 to 17 Spitters)** |
| won / drawn / lost | 1 / 3 / 0 | 0 / 4 / 0 | **6 / 0 / 0** |
| killed / lost (all four or six games) | 25,850 / 15,235 (1.7:1) | 19,290 / 17,245 (1.1:1) | **53,275 / 19,940 (2.7:1)** |

1. **Round A: the Venom Sire came at 4:20-4:40 and the first Spitters at 6:00-7:00.** His 200 food was never saved:
   `_nb_next_father` skipped him while the food was short ("Not enough biomass"), so nothing was kept and every 50 food
   went into a grub on the curve. **Fix:** the build saves for him (`sire_first`). And the spoils: the egg-bound rule
   kept her stage 3's 75 spoils, so no Spitter egg could be laid with 65 spoils in hand at 6:00. **Fix:** the build's
   own spoils first (`spoils_first`). And with the line's food short the eggs went to Raptors: **fix:**
   `save_for_spitters`. A second wave was told as a second "timing" (a03): only the first push is the timing now.
2. **Round B: Bigger Clutch and Long Spit held the Venom line from 6:02 to 7:27** (one Sire researches at a time and
   his line lays nothing meanwhile): 49 Raptors were laid instead and the timing went at 7:54 with 8 Spitters (b01).
   **Fix:** Bigger Clutch the moment he is on his nest (before his first eggs); Long Spit after the timing.
   **The timing stood at the Crown's ramp gate under the musket line** (b01 and b03, picture 04): it broke the
   expansion outside the wall, then piled at the gate and lost half its Raptors. **Fix:** with no Brutes, it comes home
   once what is left is behind a wall (d01 and d03 did: picture 02 is d01 before it).
3. **The economy was the real problem.** Round B's Spitter timing earned about half of Balanced's food on the same
   games (6,850 against 11,070 by 8:00 on Greenhold 11). The grub hold, the Venom Sire before the grub curve and the
   5.5 grubs a minute cost more than the earlier Spitters gave. **Fix (round D):** Balanced's economy (7 grubs a
   minute, no grub hold), the Venom Sire saved for only once 18 grubs stand, 6 supply more ahead. Its food by 8:00 came
   back to Balanced's (7,350-10,150) and the timing went sooner, with more Spitters.

### Round D against the Balanced plan on the same games

| game | against | map, seed | Spitter timing: result | timing out (supply, Spitters) | the timing killed | game killed / lost | Balanced: result | Balanced first wave | Balanced killed / lost |
|---|---|---|---|---|---|---|---|---|---|
| d01 / c01 | Crown | Greenhold 11 | **W 11:36** | 6:59 (28, 11), came home 8:31 | 1,720 | 7,995 / 1,965 | W 9:37 | 6:59 | 5,670 / 1,435 |
| d02 / c02 | Clockwork | Highmoor 5 | **W 11:41** | 7:38 (49, 13) | 8,155 | 8,450 / 2,580 | D | 7:48 | 6,320 / 10,240 |
| d03 / c03 | Crown | Dune Sea 7 | **W 12:47** | 6:53 (31, 11), came home 8:01 | 665 | 7,650 / 5,535 | W 10:50 | 6:53 | 6,340 / 3,220 |
| d04 / c04 | Clockwork | Twin Fords 9 | **W 12:21** | 8:23 (46, 17) | 8,600 | 9,540 / 3,440 | **L 12:53** | - | 2,715 / 6,240 |
| d05 / c05 | Crown | Highmoor 5 | **W 12:39** | 7:11 (34, 12), pulled back 8:29 | 780 | 8,900 / 4,240 | W 11:25 | 6:32 | 6,615 / 4,415 |
| d06 / c06 | Clockwork | Greenhold 3 | **W 12:08** | 8:14 (62, 10) | 9,915 | 10,740 / 2,180 | W 11:14 | 6:27 | 7,595 / 3,350 |
| all six | | | **6 W** | | | **53,275 / 19,940 (2.7:1)** | 4 W, 1 D, 1 L | | 35,255 / 28,900 (1.2:1) |

- **Against the Clockwork the timing is the plan's strength**: it killed 8,155 to 9,915 with the push itself in three
  of the three games (pictures 05, 06), and won the two games Balanced drew or lost (Highmoor 5, Twin Fords 9, where
  every Brood plan had lost or drawn before: a04, b04, c04).
- **Against the Crown the timing itself does little** (665 to 1,720 killed): it takes what is outside the wall (an
  expansion, a Mill, Musketeers in the field: pictures 02, 03) and comes home; the games are won later by the plan's
  bigger waves on its economy, about a minute later than Balanced wins them. Spitters (165) are outranged by
  Musketeers (190) until Long Spit, which now comes after the timing.

(The food and army at 6:00 / 8:00 / 10:00 of every game are in the full tables below.)

## 3. The Brute siege

### Build order (an eco plan)

| | Brute siege |
|---|---|
| grubs a minute, most | 7, 50 |
| the Tyrant Sire | 12 grubs or 2:20 |
| her growth | **at the plan's times, not waiting for her eggs to run out** (`grow_now`): stage 2 from 3:10, stage 3 from 6:00: she reached stage 3 at 5:02 to 6:09 (Balanced: 8:53 in the brood-ai-tune measures) |
| the Venom Sire | from 5:00 (Spitters to cover the Brutes) |
| research before the first push | **only its own**: Bigger Clutch for the Raptors (from 2:30, 4 Raptors), **BATTERING HORNS** with 2 Brutes; no Pack Hunt first (it held the Tyrant Sire's line a minute in round A) |
| Brutes | up to 6 at once (the Brood's own rule allows 4, 6 with a wall seen, one for 6 other warriors); **food is kept for the next Brute** instead of a Raptor from her stage 3 until 4 stand |
| spoils | **kept for the Brutes and the horns** from her stage 2: two Brutes' worth (40) and the horns' (40); Spitter eggs, maturing and the other research can't eat them; Raptors are offered up for them |
| the Storm Sire | waits for the first push (unless flyers are seen) |

**GO** (`may_go`): from **7:30** (`wave_t` 450) with **4 hatched Brutes, Battering Horns** and 28 supply, the army worth
0.6 of the biggest enemy army seen lately (0.4 against the Clockwork); from **10:30** with 2 Brutes, horns or not. Its
first push went at 7:34 to 8:41 in the coached games when the Brutes were there.

**THE BARRIER** (`_find_barrier`): the first known wall piece or gate within 2.5 tiles of the way to the target
(`Game.find_path`; a gate is no wall to the pathfinder but it is shut to the enemy, so it is looked for along the
way, a gate before the stakes beside it), or the wall piece where the way is walled off, or, with no wall in the way,
the known Ratchet Turret nearest the way in (within 10 tiles of the target or 6 of the straight way). With none known
when it leaves, it looks again on the way (the gate was found at 8:44 in the trial game, picture 07).

| part | what it does | numbers |
|---|---|---|
| MARCH | everyone attack-moves to a gathering spot short of the barrier | STAGE_D 8 tiles (a Musketeer reaches 4 to 5) |
| BREAK | the Brutes batter the barrier; the Spitters, the Venom Sire and Mist Toads stand off it and spit at what shoots; the Raptors wait at the gathering spot and bite what comes out (not into the line behind the wall) | SPIT_D 5 tiles |
| BREACH | the barrier falls: a second turret near it is broken too; else everyone goes in through the gap to the nearest building it knows, and the Brood computer has the wave again | NEXT_R 9 tiles |
| BACK | every Brute dead before the breach, or no headway (the barrier over half its health after 70 s); and the Brood computer's own retreat rules | BREAK_T 70 s, BREAK_HP 0.5 |

### The coached games (rounds A and B) against Balanced on the same games (round C)

| game | against | map, seed | Brute siege A | A: first push (supply, Brutes) -> breach | A killed / lost | Brute siege B | B: first push -> breach | B killed / lost | Balanced (C) | C killed / lost |
|---|---|---|---|---|---|---|---|---|---|---|
| 05 | Crown | Highmoor 5 | W 11:22 | 8:41 (78, 4) -> **10:20 gate** | 8,420 / 2,810 | W 12:17 | 7:49 (67, 4), no wall in its way | 7,430 / 5,880 | W 11:25 | 6,615 / 4,415 |
| 06 | Clockwork | Greenhold 3 | D | 11:05 (138, 6) -> **12:36 turret** | 12,660 / 2,500 | D | none (its economy stalled, below) | 2,755 / 2,855 | W 11:14 | 7,595 / 3,350 |
| 07 | Crown | Twin Fords 9 | W 11:39 | 7:57 (38, 1), no wall in its way | 7,510 / 4,425 | W 10:35 | 7:34 (50, 4) -> **9:29 gate** | 6,625 / 2,365 | W 9:20 | 5,170 / 1,475 |
| 08 | Clockwork | Dune Sea 7 | W 11:50 | 9:36 with no Brute (a normal wave) | 11,290 / 2,875 | W 12:38 | 8:40 (53, 4) -> **10:48 turret** | 9,720 / 3,540 | W 11:38 | 7,605 / 4,600 |
| all | | | 3 W, 1 D | 2 breaches | 39,880 / 12,610 (3.2:1) | 3 W, 1 D | 2 breaches | 26,530 / 14,640 (1.8:1) | 4 W | 26,985 / 13,840 (1.9:1) |

Plus the trial game before round A (Crown, Greenhold 3): out at 7:58 with 4 Brutes, the gate found at 8:44, **broken
at 8:59**, the Crown out at 10:07 (6,800 killed for 1,540; pictures 07, 08 and the GIF).

- **The breach works when the Brutes get there**: five pushes with Brutes met a barrier and all five broke it (two Crown
  ramp gates, two Ratchet Turrets, the trial's gate), the army went in each time, and four of those games were won.
  Against the Crown the push often found no wall in its way: its target was an expansion outside the wall (b05, a07),
  and it razed it.
- **It wins slower than Balanced**: Balanced waves at 5:00 to 7:48 with matured Challengers; the siege waits for 4
  Brutes and the horns (7:34 to 8:41), and its games end about a minute later. Its trade is as good or better (3.2:1 in
  round A).

What the films showed, and what was changed:

1. **Round A: 0 to 4 Brutes by 10:00, Battering Horns at 12:30** (first headless trial): the spoils went to Spitters,
   maturing and Pack Hunt as fast as Raptors were offered up (3 spoils in hand from 6:30 to 11:00). **Fixes:** the
   spoils kept for the Brutes and the horns, her growth on the plan's clock (stage 3 at 5:00 to 6:00), food kept for
   the next Brute. Round A: 4 Brutes by 7:34 to 8:40.
2. **The Crown's ramp gate was not seen as a barrier** (the trial game): the pathfinder walks through a gate, so "the
   way is walled off" never fired and the push walked to the gate as a normal wave. **Fix:** a known wall piece or gate
   on the way is the barrier.
3. **Round A: a push with 1 Brute, or none** (a07, a08): the count included Brutes still in their eggs, and at 10:30
   the plan let a normal wave go without them. **Fix:** hatched Brutes at home count. Pack Hunt and the Tyrant's
   research held the line in round A (a06 researched Battering Horns twice: the first was lost when he got up to
   defend): **fix:** only its own research before the push.
4. **b06: the economy stalled from 7:00** (income 1,867 a minute at 6:00, 540 from 7:00 to 13:00): three far Rootmaws
   sat full (300/300) with no grubs at them while the Clockwork's army walked round the expansions (two far turtles
   died); the same game in round A earned 13,100 by 10:00 and Balanced 12,850. This is the Brood computer's economy
   under pressure, not the build (see What is open).

## 4. Tests

- **`tools/test_brood_builds.gd`** (one case a run):
  - `case:picks`: the lobby offers both for the Brood only, their names in pt and es, RANDOM PLAN picks either, a Brood
    computer on each gets its build (and Balanced none), the AI story tells the plans and the breach.
  - `case:timing` (Hard against Hard, `foe:` `map:` `seed:`): the timing leaves between 6:20 and 9:00 with at least 8
    Spitters, the Venom line's Bigger Clutch is in or being researched, it reaches contact, and the economy grew behind it (24 grubs and a
    turtle on new ground when it left). Prints a line every 30 s (stage, food, spoils, supply, grubs, Raptors /
    Spitters / Brutes, Sires, research, the enemy army it has seen, eggs) and its decisions.
  - `case:breach`: the push leaves with Brutes by 12:00, Battering Horns are in, and THE BREACH is made (a wall piece,
    gate or turret broken by the push and the army sent in) by 15:00.
- **`tools/play_brood_builds.gd`** (the coach; extends tools/play_brood_3.gd): the pictures and clips of the push
  (push_out, push_contact, push_break, push_breach, push_back), and `builds.txt`: the economy at 4/6/8/10 minutes, a
  line per push, the result. **`tools/brood_builds_table.py DIR...`** makes the tables above.

Results on this branch (0.29.16, Godot 4.7 headless; the "Aborted" Godot prints after quitting is the known one):
- boot check (`godot --headless --quit-after 300`): no script error.
- `test_brood_builds.gd`: picks 0 failures; timing against the Crown (Greenhold 11) 0 failures (out at 6:44 with 11
  Spitters in the trial run); timing against the Clockwork (Greenhold 3) 0 failures (out at 7:59 with 25 Spitters,
  contact 8:23; an earlier run failed only the Bigger Clutch check: it had started 2 s before the go, so the check now
  counts it being researched); breach against the Crown (Greenhold 3) 0 failures (a Gate at 10:35); breach against the
  Clockwork (Dune Sea 7) 0 failures (a Ratchet Turret at 11:41).
- `test_brood_new.gd` 0 failures; `test_brood_ai_defend.gd` ALL PASS; `test_ai_brood.gd` balanced, timing, rush:
  0 failures each (the other three profiles were not re-run: the plans and code paths they use are unchanged; every
  hook is behind `bb != null`, which only the two new plans have).

## 5. What is open

- **Against the Crown, the Spitter timing's own wave does little** (665 to 1,720 killed): what is outside the wall, then
  home. A Long Spit timing (Spitters at 190, the Musketeers' range) would trade at the wall but costs the Venom line
  45 s of eggs before it; the owner may prefer that.
- **The Brute siege is slower than Balanced** (its first push at 7:34 to 8:41 against Balanced's waves from 5:00 to
  7:48). Brutes need her stage 3 (500 food, 75 spoils) and 20 spoils each.
- **The Brood computer's economy under the Clockwork's pressure** (b04, b06, c04): full far Rootmaws with no crew while
  enemies walk near them, far turtles lost. Every plan shares it.
- **The barrier at the Crown**: the push breaks the first known wall piece or gate on its way; when the wall has another
  gap (a second gate, a gap the Crown left), it still breaks the one in front.
- The alarm (an enemy army out of its main) holds the timing home for 75 s at a time (d02: 7:38 instead of 6:30).

## 6. Proposals for the owner (not changed here)

1. **Spitter range**: the Spitter (165) is outranged by the Musketeer (190) until Long Spit; against the Crown's wall
   the Spitter timing can only take what is outside it. Either Long Spit a little cheaper or quicker (45 s holds the
   Venom line), or the Spitter's base range 175-180, would let a Spitter timing trade at a wall.
2. **Brutes cost 20 spoils each** on top of her stage 3's 75 and the horns' 40: a Brute siege needs about 215 spoils by
   7:30, about 14 Raptors offered up. 15 spoils a Brute would bring the siege about half a minute sooner.
3. **The Brood out-earns both Hard computers** (as brood-ai-tune found): the coached games earned 18,000-21,000 food by
   13:00 against 7,600-10,000 for the Crown and Clockwork. brood-ai-tune's FOOD_BONUS 1.5 -> 0.8 proposal stands.

## Tools and files

- `scripts/ai_brood_builds.gd` (new), hooks in `scripts/ai_brood_new.gd` (PLANS "spitter" and "brute", `bb`),
  `scripts/ai.gd` (STRATEGIES), `scripts/ai_story_lines.gd`, `tools/i18n/53_brood_builds.txt`.
- `tools/test_brood_builds.gd`, `tools/play_brood_builds.gd`, `tools/brood_builds_table.py`.
- Pictures: `docs/shots/brood_builds/` (`captions.md`).

## The full tables (tools/brood_builds_table.py)

"food 6/8/10" is the Brood's food earned by 6, 8 and 10 minutes (the enemy's income in brackets); "army 8:00" the
Brood's army value (the enemy's); "lost" in the last column is what the enemy killed.

### Round A

| game | plan | against | map, seed | result | food 6/8/10 (enemy) | army 8:00 (enemy) | first push: out (supply, Spitters, Brutes) | contact | breach (broke) | push killed | end | game killed / lost |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| a01 | spitter | crown | Greenhold 11 | D | 3337/7209/12147 (3040/5320/7980) | 1280 (1135) | 8:02 (36, 9, 0) | 8:08 | - | 5200 | out to the end | 5315 / 5885 |
| a02 | spitter | clockwork | Highmoor 5 | W 12:50 | 3338/6326/10203 (4419/6622/8637) | 1555 (1445) | 8:30 (52, 24, 0) | 8:44 | - | 8590 | out to the end | 9760 / 3355 |
| a03 | spitter | crown | Dune Sea 7 | D | 3356/7627/12336 (2660/4940/7980) | 1475 (1250) | 7:46 (27, 9, 0) | 8:29 | - | 1460 | came home 9:12 | 8125 / 5570 |
| a04 | spitter | clockwork | Twin Fords 9 | D | 3153/4201/5258 (4571/7133/10450) | 995 (2095) | 9:40 (36, 16, 0) | 10:03 | - | 1720 | out to the end | 2650 / 425 |
| a05 | brute | crown | Highmoor 5 | W 11:22 | 5716/10802/15112 (3040/5320/8360) | 1460 (1150) | 8:41 (78, 17, 4) | 10:17 | 10:20 (1 gate) | 7760 | out to the end | 8420 / 2810 |
| a06 | brute | clockwork | Greenhold 3 | D | 5894/8605/13100 (4412/6697/9729) | 1560 (1370) | 11:05 (138, 36, 6) | 12:25 | 12:36 (1 ratchet turret) | 9930 | out to the end | 12660 / 2500 |
| a07 | brute | crown | Twin Fords 9 | W 11:39 | 5753/10612/15104 (3040/5320/7600) | 1725 (1160) | 7:57 (38, 10, 1) | - | - | 7510 | out to the end | 7510 / 4425 |
| a08 | brute | clockwork | Dune Sea 7 | W 11:50 | 5296/8073/13115 (4395/6653/9709) | 1570 (1725) | 9:36 (78, 12, 0) | - | - | 9250 | out to the end | 11290 / 2875 |

### Round B (and Balanced, c01-c08)

| game | plan | against | map, seed | result | food 6/8/10 (enemy) | army 8:00 (enemy) | first push: out (supply, Spitters, Brutes) | contact | breach (broke) | push killed | end | game killed / lost |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| b01 | spitter | crown | Greenhold 11 | D | 3354/6851/11592 (2660/4940/7600) | 1585 (1070) | 7:54 (57, 8, 0) | 8:03 | - | 2940 | came home 11:11 | 4685 / 5205 |
| b02 | spitter | clockwork | Highmoor 5 | D | 3323/6019/9017 (4223/6118/7772) | 1350 (1030) | 8:10 (46, 10, 0) | 8:27 | - | 1710 | came home 9:18 | 6855 / 4490 |
| b03 | spitter | crown | Dune Sea 7 | D | 3363/7054/11794 (2660/4940/7600) | 1905 (1205) | 7:43 (59, 8, 0) | 8:00 | - | 2635 | came home 9:14 | 3835 / 4780 |
| b04 | spitter | clockwork | Twin Fords 9 | D | 3591/4637/5717 (4541/7485/10922) | 0 (1665) | - | - | - | - | - | 3915 / 2770 |
| b05 | brute | crown | Highmoor 5 | W 12:17 | 5675/10615/15414 (3040/4940/7600) | 2495 (1160) | 7:49 (67, 16, 4) | - | - | 7430 | out to the end | 7430 / 5880 |
| b06 | brute | clockwork | Greenhold 3 | D | 5546/6814/7896 (4437/6737/9558) | 1230 (2025) | - | - | - | - | - | 2755 / 2855 |
| b07 | brute | crown | Twin Fords 9 | W 10:35 | 5761/10629/15633 (2660/4940/6460) | 1950 (960) | 7:34 (50, 10, 4) | 9:23 | 9:29 (1 gate) | 6625 | out to the end | 6625 / 2365 |
| b08 | brute | clockwork | Dune Sea 7 | W 12:38 | 5367/8236/12940 (4457/6824/9417) | 1415 (1320) | 8:40 (53, 25, 4) | 10:41 | 10:48 (1 ratchet turret) | 8585 | out to the end | 9720 / 3540 |
| c01 | balanced | crown | Greenhold 11 | W 9:37 | 5756/11069/- (2660/4940/-) | 2625 (1075) | - | - | - | - | - | 5670 / 1435 |
| c02 | balanced | clockwork | Highmoor 5 | D | 4818/9078/13638 (4447/6440/8374) | 1800 (1600) | - | - | - | - | - | 6320 / 10240 |
| c03 | balanced | crown | Dune Sea 7 | W 10:50 | 5762/10864/16699 (2660/4940/6080) | 1655 (920) | - | - | - | - | - | 6340 / 3220 |
| c04 | balanced | clockwork | Twin Fords 9 | L 12:53 | 3749/5361/7273 (4416/6345/9515) | 190 (1735) | - | - | - | - | - | 2715 / 6240 |
| c05 | balanced | crown | Highmoor 5 | W 11:25 | 5762/10769/15984 (3040/4940/6840) | 1845 (1090) | - | - | - | - | - | 6615 / 4415 |
| c06 | balanced | clockwork | Greenhold 3 | W 11:14 | 4755/8499/12854 (4365/5488/6721) | 1375 (325) | - | - | - | - | - | 7595 / 3350 |
| c07 | balanced | crown | Twin Fords 9 | W 9:20 | 5920/10996/- (3040/4940/-) | 2490 (185) | - | - | - | - | - | 5170 / 1475 |
| c08 | balanced | clockwork | Dune Sea 7 | W 11:38 | 5297/10102/14832 (4291/5809/6767) | 1050 (880) | - | - | - | - | - | 7605 / 4600 |

### Round D

| game | plan | against | map, seed | result | food 6/8/10 (enemy) | army 8:00 (enemy) | first push: out (supply, Spitters, Brutes) | contact | breach (broke) | push killed | end | game killed / lost |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| d01 | spitter | crown | Greenhold 11 | W 11:36 | 5118/10105/15202 (3040/5320/7980) | 1655 (400) | 6:59 (28, 11, 0) | 7:43 | - | 1720 | came home 8:31 | 7995 / 1965 |
| d02 | spitter | clockwork | Highmoor 5 | W 11:41 | 4461/9354/14331 (4407/6377/7713) | 2555 (1850) | 7:38 (49, 13, 0) | 7:43 | - | 8155 | out to the end | 8450 / 2580 |
| d03 | spitter | crown | Dune Sea 7 | W 12:47 | 5145/9350/14128 (2660/4940/7220) | 1175 (1400) | 6:53 (31, 11, 0) | 7:51 | - | 665 | lost, came home 8:01 | 7650 / 5535 |
| d04 | spitter | clockwork | Twin Fords 9 | W 12:21 | 3630/7350/12817 (4201/6235/8757) | 1690 (1155) | 8:23 (46, 17, 0) | 8:35 | - | 8600 | out to the end | 9540 / 3440 |
| d05 | spitter | crown | Highmoor 5 | W 12:39 | 5146/10149/14929 (3040/5700/8740) | 2185 (890) | 7:11 (34, 12, 0) | 7:56 | - | 780 | lost, came home 8:29 | 8900 / 4240 |
| d06 | spitter | clockwork | Greenhold 3 | W 12:08 | 4273/8590/13925 (4397/6963/9589) | 1740 (1720) | 8:14 (62, 10, 0) | 8:29 | - | 9915 | out to the end | 10740 / 2180 |
