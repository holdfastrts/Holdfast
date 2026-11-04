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
6. While the computer's Mother is up (fighting), her home footprint is not kept for her yet: what roots there in the
   meantime is checked like anything else, and she roots back on her home spot (the safety net covers it).

## 3. Numbers

`tools/study_brood_layout.gd` (one game; `off:1` = the computer before the fix) and `tools/study_brood_layout.sh` (the
list `tools/study_brood_layout.list`, each game before and after). Hard Brood against a Hard Crown or Clockwork,
Godot 4.7 headless. **Stuck** = its units on foot in a walkable area other than the open map that borders its own rooted
creatures, counted once a second (unit-seconds), with the most at once and the longest any one unit stayed.
**Dry by own turtle** = a Rootmaw that went dry and uprooted within 10 s of one of its own Mound Turtles in reach
getting up.

STUDY_TABLE

- **The owner's bug, found twice**: Redrock Canyon, Spitter timing against the Clockwork (seed 5): from 5:55 its whole
  base (406 cells round the Mother) was shut in by the Mother, two Rootmaws, the Tyrant and Venom Sires and three Mound
  Turtles; 42 units at first, 69 at 10:00, as every egg hatched inside. Cinder Steps, Economy against the Crown Economy
  (the owner's eco v eco, 15 minutes, seed 11): from 8:08 the supply turtles packed round the Mother shut 95 units in,
  then 149 (two pockets, 130 and 57 cells) to the end: its whole army sat at home while the Crown army grew to 5,190.
  After the fix: no unit shut in for a second in either game; the Cinder Steps game was won at 13:33.
- **Small pockets** (13 units for 4 s, Highmoor 9:21: the Mother, three turtles and two Sires round a 23-cell gap) were
  already walked out of by the old escape; after the fix they don't happen.
- **Every game after the fix: 0 stuck unit-seconds**; the whole-map check refused 0 to 6 spots a game; the safety net
  never had to act (0 uproots, 0 walk-outs).
- **Rootmaws dried by its own turtle: 0 in every game, before and after**: the alarm's turtle did not get up next to
  live Rootmaws in these games (the owner's Thornwood seed against the Horseman rush played differently; the Brood went
  on). The rule is tested by hand instead (`case:alarm` below). The Mother getting up dried one Rootmaw once before
  the fix (Highmoor, Rush against the Clockwork); that is the Mother's own rule (docs/brood_ai_swarm.md), unchanged.
- Results otherwise as before (who won, grubs, army): the change takes no time from the economy.

## 4. Pictures

`docs/shots/brood_layout/` (captions in `captions.md`).

PICTURES

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

TEST_RESULTS

## 6. What is open

- The Mother's home spot is not held for her while she is up fighting (a turtle could root on part of it); she roots
  back where she stands, and the safety net would open any pocket that makes. Not seen in these games.
- The alarm turtle rule keeps a turtle feeding Rootmaws home; when every home turtle feeds Rootmaws, no turtle goes in
  front (the computer does not make a new one for it). A proposal for the owner: should the alarm morph a fresh turtle
  in front instead?
- Big creatures (the Mother, a Sire) are wider than 2 tiles: a 2-tile lane lets grubs and warriors out, not always a
  Sire walking off his nest. The safety net counts only units shut in by walkable area, not by width.
