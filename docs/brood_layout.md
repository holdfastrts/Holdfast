# The Brood computer's base layout (branch brood-layout)

The owner, 2026-11-04 19:57, watching Hard Crown Economy against Hard Brood Economy on 0.30.8: **"Brood bad base
design: the turtle-locked units are stuck inside."** His picture (`docs/playtests/2026-11-04/eco_v_eco_4_brood_turtle_traps_units.jpg`):
the Brood computer's rooted creatures (a Mound Turtle, Rootmaws, the Mother's nest, the Sires) and the edge of its
plateau close a pocket, and its own grubs, warriors and a Sire inside it can't get out.

Also seen that afternoon (`spectate_brood_econ_v_crown_horseman_rush_thornwood_0305.txt`, 3:23 to 3:42): the ALARM sent
a Mound Turtle "in front", and two of its own Rootmaws lost their swamp and uprooted (3:32, 3:34): a defensive move that
shut down half its economy.

No unit, building or economy number was changed: only where the computer roots its creatures, which turtle its alarm
gets up, and a safety net for its own units. (docs/design_principles.md 3, meaningful base building: placement
matters, so the computer must place well; and 1, no punishment its own player could not prevent.)

## 1. What was wrong

- **A rooted creature is a building** (scripts/brood_root.gd): its footprint is solid ground for everyone, its own side
  too (a Mound Turtle is 3 x 3 tiles, a Rootmaw 3 x 2, a Sire 3 x 3 or 4 x 3, the Mother 9 x 4 and more as she grows).
- **The computer's spot finders only asked "may it root here?"** (BroodRoot.place_problem: the grid, the swamp, the
  circles, the ramps). Nobody asked "what does it close?". Its supply turtles (docs/raid_micro.md F) pack in 3 tiles
  from each other round the Mother, its Sires nest three quarters of their reach out, its Rootmaws root on her swamp:
  in a base on a plateau, against its cliffs, they can join up into a ring.
- **The old escape only worked for tiny pockets.** A creature hatched or pushed into a pocket walks out through its own
  creatures (BroodRoot.start_pass), but only when the pocket is under 48 cells (Game.POCKET, `sealed_in`). A pocket of
  200 or 400 cells counted as "the open map": nothing walked out, the pathfinder's partial paths ended at the rim, and
  every egg the Mother laid hatched into the same prison.
- **The alarm's turtle**: the alarm got up the rooted turtle nearest the front spot, whatever stood on its swamp.
  Rootmaws feed only on swamp; with their turtle up its swamp recedes, and two seconds later they uproot.

## 2. The fix

All in `scripts/brood_layout.gd` (BroodLayout) and a few hooks.

1. **Before the computer roots anything** (every spot finder: Rootmaws, Mound Turtles at home, on new ground and in front
   of the natural, the Sires' nests, a Rootmaw rooting again after a fight, a grub's cocoon), `BroodRoot.place_problem`
   (with `ai = true`, so never the player's own ROOT) asks `BroodLayout.closes`: would this footprint cut any ground
   off from the open map?
   - The ground is looked at in **lanes two tiles wide**: a "block" is a 2 x 2 square of free cells; blocks join
     side to side. A gap of one tile between a creature and a cliff is no lane.
   - It compares the blocks that reach the open map **before** and **after** the footprint (the other creatures' planned
     spots count as taken in both). Any piece that loses its way out is a no: "It would close a pocket (keep a way out
     two tiles wide)", or "It would shut N of its own in" when its units stand there. A nook of up to 4 blocks against
     a cliff with nobody in it is let be.
   - Quick: a footprint with two free tiles all round it can't close anything (the answer at once); otherwise a window
     of 16 tiles round the spot is looked at.
2. **The spot finally picked is checked on the whole map** (`BroodLayout.exact`, `AIBroodNew._layout_ok`, before a
   creature is sent to root or a grub to morph): a pocket bigger than the window is caught there. A refused spot is
   left alone for a minute and the finder picks another (the match log says "layout: not a Mound Turtle there (...)").
3. **The alarm keeps the turtles that feed Rootmaws** (`BroodLayout.feeds_maws`): a rooted turtle whose swamp is the only
   swamp under one or more live rooted Rootmaws never gets up for the alarm, unless it is dying (under a quarter of its
   health). Another turtle goes (one that feeds none), or none: "ALARM: no Mound Turtle gets up: its turtles feed the
   Rootmaws' swamp".
4. **The safety net** (`AIBroodNew._nb_unstick`, every 3 s): if its own units on foot still stand in a pocket bordered
   by its own rooted creatures (the Mother rooting back on her home spot, something rooted before the rule), the
   creature that closes the pocket on the open map gets up (a Rootmaw first, keeping its food; then a Sire; then a Mound
   Turtle that feeds no Rootmaw; never the Mother), its spot is left alone for 2 minutes, and the computer roots it
   elsewhere. With none to get up, the units walk out through their own creatures (BroodRoot's pass).
5. **Walking out through its own creatures now aims for the open map** (`BroodRoot.boxed`, `exit_point`, `pass_move`
   use `BroodLayout.own_pocket` / `out_ok`): a pocket its own creatures close counts as boxed in at any size, and the
   walk ends only out on the open map, not inside a big pocket. This one also helps the player's own Brood.
6. **Her nest grows**: the ground the Mother's last-stage nest will take round her rooted feet counts as taken in the
   check, so nothing roots where her growing nest would close a gap later (the Cinder Steps games).
7. **The alarm's turtle met on its way**: it used to root where it stood (ROOT, the player's rules: on a ramp is allowed
   for a turtle); now only where the computer may root (not on or by a ramp, no pocket closed), else it walks on to its
   spot (`AIBroodNew._front_may_root_here`; the Redrock Canyon games).
8. `BroodLayout.off` (or `BROOD_LAYOUT_OFF=1` for any tool) runs the computer as before, for comparisons.

## 3. Numbers

`tools/study_brood_layout.gd` (one game; `off:1` = the computer before the fix) and `tools/study_brood_layout.sh` (the
list `tools/study_brood_layout.list`, each game before and after). Hard Brood against a Hard Crown or Clockwork,
Godot 4.7 headless. **Stuck** = its units on foot in a walkable area other than the open map that borders its own rooted
creatures, counted once a second (unit-seconds), with the most at once and the longest any one unit stayed.
**Dry by own turtle** = a Rootmaw that went dry and uprooted within 10 s of one of its own Mound Turtles in reach
getting up.

21 games, each played twice from the same seed: before the fix (`off:1`) and after it. The games are not
deterministic, so before and after part ways after the first minutes; "to 10:00" = still going when the run stopped.
The "after" column of the first 15 rows is a second run on the final code (the first after-runs, on an earlier
commit, gave 0 stuck unit-seconds too).

| map | Brood plan v foe | seed | stuck unit-s before | after | most at once before | after | longest before | after | spots refused (after) | before | after |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Highmoor | Economy v Crown | 3 | 56 | 0 | 13 | 0 | 4 s | 0 s | 3 | to 10:00 | to 10:00 |
| Highmoor | Rush v Clockwork | 3 | 0 | 0 | 0 | 0 | 0 s | 0 s | 0 | to 10:00 | to 10:00 |
| Redrock Canyon | Balanced v Crown | 5 | 0 | 0 | 0 | 0 | 0 s | 0 s | 2 | to 10:00 | to 10:00 |
| Redrock Canyon | Spitter timing v Clockwork | 5 | 13,592 | 0 | 69 | 0 | 245 s | 0 s | 0 | to 10:00 | to 10:00 |
| Thornwood Maze | Economy v Crown | 2103718835 | 0 | 0 | 0 | 0 | 0 s | 0 s | 0 | to 10:00 | to 10:00 |
| Thornwood Maze | Timing v Clockwork | 4 | 1 | 7 | 1 | 1 | 0 s | 6 s | 1 | to 10:00 | to 10:00 |
| Greenhold | Brute siege v Crown | 6 | 1 | 0 | 1 | 0 | 0 s | 0 s | 3 | to 10:00 | to 10:00 |
| Greenhold | Air v Clockwork | 6 | 0 | 0 | 0 | 0 | 0 s | 0 s | 0 | to 10:00 | to 10:00 |
| Cinder Steps | Extreme rush v Crown | 8 | 0 | 0 | 0 | 0 | 0 s | 0 s | 1 | to 10:00 | to 10:00 |
| Cinder Steps | Economy v Clockwork | 8 | 0 | 0 | 0 | 0 | 0 s | 0 s | 3 | Brood won 9:52 | Brood won 9:20 |
| Highmoor | Economy v Crown | 11 | 12 | 0 | 6 | 0 | 2 s | 0 s | 3 | Brood won 14:06 | Brood won 14:46 |
| Redrock Canyon | Economy v Crown | 11 | 9 | 0 | 4 | 0 | 3 s | 0 s | 1 | Brood won 13:47 | to 15:00 |
| Thornwood Maze | Economy v Crown | 11 | 2 | 1 | 1 | 1 | 0 s | 0 s | 2 | to 15:00 | Brood won 13:28 |
| Greenhold | Economy v Crown | 11 | 0 | 0 | 0 | 0 | 0 s | 0 s | 6 | Brood won 14:33 | to 15:00 |
| Cinder Steps | Economy v Crown | 11 | 56,443 | 0 | 149 | 0 | 412 s | 0 s | 1 | to 15:00 | Brood won 13:13 |
| Redrock Canyon | Spitter timing v Clockwork | 21 | 22,613 | 0 | 68 | 0 | 477 s | 0 s | 1 | to 14:00 | to 14:00 |
| Redrock Canyon | Spitter timing v Clockwork | 22 | 2 | 0 | 1 | 0 | 1 s | 0 s | 2 | Brood won 12:03 | to 14:00 |
| Cinder Steps | Economy v Crown | 21 | 46,465 | 0 | 146 | 0 | 375 s | 0 s | 5 | to 14:00 | to 14:00 |
| Cinder Steps | Economy v Crown | 22 | 31,294 | 0 | 105 | 0 | 354 s | 0 s | 2 | to 14:00 | Brood won 12:04 |
| Cinder Steps | Balanced v Crown | 23 | 37,461 | 1 | 121 | 1 | 375 s | 0 s | 8 | to 14:00 | Brood won 12:37 |
| Redrock Canyon | Economy v Clockwork | 23 | 6 | 0 | 6 | 0 | 0 s | 0 s | 6 | to 14:00 | Brood won 9:27 |

Total stuck unit-seconds: before 207,957, after 9. Games 21; Brood wins before 5, after 7; Rootmaws dried by own turtle before 0, after 0; safety net actions after 2.

- **The owner's bug, found twice**: Redrock Canyon, Spitter timing against the Clockwork (seed 5): from 5:55 its whole
  base (406 cells round the Mother) was shut in by the Mother, two Rootmaws, the Tyrant and Venom Sires and three Mound
  Turtles; 42 units at first, 69 at 10:00, as every egg hatched inside. Cinder Steps, Economy against the Crown Economy
  (the owner's eco v eco, 15 minutes, seed 11): from 8:08 the supply turtles packed round the Mother shut 95 units in,
  then 149 (two pockets, 130 and 57 cells) to the end: its whole army sat at home while the Crown army grew to 5,190.
  After the fix: no unit shut in for a second in either game; the Cinder Steps game was won at 13:33 (13:13 on the final code).
- **Small pockets** (13 units for 4 s, Highmoor 9:21: the Mother, three turtles and two Sires round a 23-cell gap) were
  already walked out of by the old escape; after the fix they don't happen.
- **The bug is common where the main is a cramped plateau**: every Cinder Steps game with an economic plan against
  the Crown shut its army in before the fix (4 of 4: 95 to 149 units, for 6 to 7 minutes), and 2 of 3 Spitter timing
  games on Redrock Canyon. After the fix: 9 stuck unit-seconds in all 21 games (Thornwood Maze, Timing against the
  Clockwork: one unit for 6 s, walked out by the safety net; Cinder Steps, Balanced: one unit for a second).
- **Who was it?** In the study logs (`a ... roots at`, `the Mother grows`, `the one to get up`): on Redrock Canyon the
  alarm's turtle, met by the Clockwork on its way out, rooted where it stood at the main's ramp (5:53 got up, 6:05
  rooted, the pocket from 6:03); on Cinder Steps the Mother grew to stage 3 (7:17, her nest 12 x 5) and her bigger
  nest, the supply turtles packed round her and the cliff closed the ramp's mouth (pocket from 8:00).
- **The whole-map check refused 0 to 8 spots a game**; the safety net acted twice in 21 games.
- **Rootmaws dried by its own turtle: 0 in every game, before and after.** In the owner's Thornwood log the order is:
  3:23 alarm, 3:25 a Rootmaw backs off from 3 Cuirassiers, 3:29 an uproot sound, 3:31 "defends ... at the Mother",
  3:32 and 3:34 two Rootmaws lose their swamp, 3:42 "a Mound Turtle gets up to root in front of the natural". The
  turtle's getting up is logged ten seconds AFTER the Rootmaws went dry, so the likelier cause there is the Mother
  getting up to fight the Cuirassiers at her (her swamp goes with her). The turtle rule is done as asked and tested by
  hand (`case:alarm`: on the old computer the alarm takes the turtle feeding the Rootmaw and it goes dry; now it takes
  the other one). The Mother's own rule (docs/brood_ai_swarm.md) is unchanged: a question for the owner in section 6.
- **Results**: the Brood won 7 of the 21 games after the fix, 5 before (no unit number changed; its army is no longer
  stuck at home). Grubs and army were otherwise about the same.

## 4. Pictures

`docs/shots/brood_layout/` (captions in `captions.md`).

See `captions.md` for each. Redrock Canyon (Spitter timing v Clockwork, seed 5): `01` before at 4:00 (open), `02` before
at 6:01 (shut in), `03` before at 7:00 (the ramp's mouth closed), `04` after at 7:00 (open). Cinder Steps (Economy v
Crown Economy): `05` before at 7:00 (the Mother growing), `06` before at 8:01 (shut in, the owner's shape), `07` seed 21
before at 8:05 (wide: the ramp, the turtle under it, the crowd at the cliff), `08` seed 21 before at 9:50, `09` seed 21
after at 9:50 (open), `10` seed 11 after at 10:00 (open; won at 13:33).

## 5. Tests

- **`tools/test_brood_layout.gd`** (one case a run; `tools/test_brood_layout.sh` runs them all; `off:1` runs a case
  on the computer before the fix):
  - `case:rule map:<m>`: every 3 x 3 spot a Mound Turtle could root on (the player's rules), rooted for a moment by hand:
    every spot the whole-map check lets be shuts nothing off (no own unit leaves the open map, no more than a nook of
    open ground is cut off); the spots it refuses really would; some are refused.
  - `case:opening map:<m> [bs:] [foe:] [seed:] [end:]`: after 1:00 no unit of its own stays shut in by its own creatures for more
    than 15 s, and no more than 60 unit-seconds in all.
  - `case:alarm` (Thornwood Maze, Economy): at 4:30 the alarm is set off by hand: no Mound Turtle whose swamp is the only
    swamp of live Rootmaws gets up (unless dying), and no Rootmaw goes dry in the next 40 s because of its own turtle.

Results on this branch (0.30.9, Godot 4.7 headless; the "Aborted" Godot prints after quitting is the known one):
- boot check (`godot --headless --quit-after 300`): no script error.
- `test_brood_layout.gd`: rule on Greenhold (6,152 spots let be, 16 refused, all correct) and Redrock Canyon (30
  refused, all correct); opening on Highmoor, Redrock Canyon, Thornwood Maze, Greenhold, Cinder Steps (Economy v Crown,
  7:00), Redrock Canyon Spitter v Clockwork seed 5 (10:00) and Cinder Steps eco v eco seed 11 (10:00): 0 stuck
  unit-seconds each, ALL PASS (with `off:1` the Cinder Steps eco v eco case FAILS: 14,053 unit-seconds, one grub shut in for 120 s); alarm ALL PASS (with `off:1` it FAILS 3 checks: the alarm takes the turtle
  feeding the Rootmaw, the Rootmaw goes dry).
- `test_brood_new.gd` 0 failures; `test_brood_ai_defend.gd` ALL PASS; `test_ai_brood.gd` balanced, timing, rush 0
  failures each.
- `test_brood_builds.gd`: picks 0 failures; timing against the Crown (Greenhold 11) and the Clockwork (Greenhold 3) 0
  failures. **breach**: the checks depend on how the game goes, and these games are not deterministic:
  - against the Crown, Greenhold seed 3: twice the Brood's FIRST push (no wall in its way, at 7:54 and 7:57) killed the
    Crown outright (game over 11:06, 11:13), before the Crown put a Gate up, so "THE BREACH by 15:00" could not happen
    (on the old computer the same seed met a Gate at 9:59 and breached it). With seed 4: 0 failures (a Gate at 9:33).
  - against the Clockwork, Dune Sea seed 7, four runs: one passed (a Ratchet Turret broken at 9:20), two failed (the
    Brood lost its army to an early Clockwork attack and the push went late or lost), one was cut off; on the old
    computer one run passed. No "layout" refusal was logged in any of these runs (the whole-map check never fired;
    only the quick check moved a spot or two), so I read this as the game's variance, not the change; it is worth a
    look at merge (`BROOD_LAYOUT_OFF=1` reruns any of them on the old computer).

## 6. What is open

- The Mother's home spot is not held for her while she is up fighting (a turtle could root on part of it); she roots
  back where she stands, and the safety net would open any pocket that makes. Not seen in these games.
- The alarm turtle rule keeps a turtle feeding Rootmaws home; when every home turtle feeds Rootmaws, no turtle goes in
  front (the computer does not make a new one for it). A proposal for the owner: should the alarm morph a fresh turtle
  in front instead?
- Big creatures (the Mother, a Sire) are wider than 2 tiles: a 2-tile lane lets grubs and warriors out, not always a
  Sire walking off his nest. The safety net counts only units shut in by walkable area, not by width.
