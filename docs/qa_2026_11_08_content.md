# QA study 2026-11-08: the game content (job qa-content)

Part of the owner's "overall study and complete systematic test of the game" (2026-11-07). This job owns the
GAME CONTENT: every unit, building, research and ability of the Crown, the Clockwork and the Brood, and the
campaign-only Pikeman and Free Assembly roles. (The existing test suite, the computer matches, the menus and the
performance are the other four jobs.)

## The tool

`tools/test_content_all.gd` (new):

    godot --headless --fixed-fps 30 --script res://tools/test_content_all.gd > out.txt 2>&1
    (one part only: add  -- only=static | crown | clockwork | brood)

About 3 minutes for everything. The full output of the run on 0.33.8 is in docs/qa_2026_11_08_content_output.txt. It walks Defs and plays three small test games (Crown, Clockwork and Brood, each
against a computer that is switched off, on Greenhold). For every entry it prints one line per check
(`PASS / FAIL / WARN / INFO / SKIP  entry  check  note`), then a list of the animations the units asked for, a
cost-per-effect table, a summary table (one row per entry, the worst result of each check) and the FAIL and WARN
lists. Script errors raised while a check runs are caught (a Godot `Logger`) and become FAILs of that check.

What it checks, per entry:

| check | what |
|---|---|
| data | numbers sane (hp, cost, time, cooldown, min range < range); made where Defs says (a building that trains it, the Mother who lays it, a grub that turns into it, MATURE); requirements name something real |
| text | name, description and research button have a pt and an es translation |
| icon | the button picture exists (found the way the HUD finds it) |
| art | every strip in art_data.gd exists, is frames x cell wide, is not empty and has no empty frame; idle, walk and death in the five views; every animation a unit ASKED FOR in the live tests has a strip |
| sound | voice (select / move / attack), attack and death sound: its own or the fallback |
| place | refused on top of the hall and before its requirement; allowed at the game's own find_spot; refused off the gear field (Clockwork) |
| cost | the price charged exactly (gold, powder / batteries, Tension) for buildings, units, research, grub morphs, eggs, MATURE, GROW; ABANDON / CANCEL / STOP pay it all back |
| build, repair, demolish | one worker builds it to the end (the Clockwork's crate and gear link checked: linked and working); a worker mends a damaged one; DEMOLISH pulls it down (supply cap drops) |
| refuse, make, rally, queue | training refused without each requirement (the building taken away for a moment) and before Armour; it comes out, supply goes up by Defs, it walks to the rally; Barracks recruits armed from the bank; five in a queue, the sixth refused, CANCEL x5 pays back |
| research, effect | refused before its chain / its building; done; then its effect on a unit already in the field AND a new one (reload, range, health, speed, clutch, spells, refits, root time, the bands) |
| grow | the Brood Mother's GROW to stages 2 and 3 (price, STOP pays back, the stage reached) |
| buttons | every button on the card: an icon file, a tooltip, en/pt/es texts |
| ability | every button PRESSED on a fresh unit (a target given when it asks: an enemy, the ground, the damaged hall, a rider), then something must change in 4 s; plus direct tests of the rules the presses can't show (below) |
| fight | attacks a dummy (an enemy that can't move or fight back, huge health) at a sensible distance for 24 s: the damage a second against the card's own figure (UnitStats); then a building, then a flyer for the anti-air units; a slow heavy weapon's ONE shot on a building against damage x building bonus |
| targets | can_hit air / ground agrees with Defs (anti_air, air_only, ground_only) |
| body | killed: supply comes back, a body / wreck stays (Brood spoils value, the Clockwork's cogs for the Great Winder) |
| numbers | cost per effect (information only) |

The rules tested directly: the Crown's ammunition (ARM WITH POWDER off, a partial bank, a dry Musketeer refilling at the
Barracks), MOUNT / DISMOUNT for all four riders, LEAD and RELEASE, HARNESS and RELEASE HORSE for the three harnessed
machines, UNLIMBER / DEPLOY and back, the Marching Band's ring and its FIFE SOLO, the Missionary raising a fallen
Musketeer, the Free Assembly roles and the torch-bearer burning a building; the Clockwork's winding (a Winder winds a
run-down Clock Soldier) and the gear field; the Brood's rooting armour, UPROOT / ROOT for a Mound Turtle and a Sire,
every Sire's nest fertilising its eggs, the spoils of a harvested body, every research at the creatures.

## Results (v0.33.8)

126 entries (retired units and the shelved Line economy buildings are listed as SKIP: kept for old saves only).
After the fixes below: **115 PASS, 11 WARN, 0 FAIL** entries; about 1,540 checks passed. (The WARNs are listed in the
next sections; none of them is a crash or a wrong price.)

Everything that is made in a normal game can be made the way the rules say, costs exactly its price and gives it all
back when cancelled; every requirement refuses when it is missing; every research is done and its effect shows on old
and new units; every building is placed, built, repaired and pulled down; every fighting unit fights a dummy within
its card's damage a second (all between x0.6 and x1.4 except as noted under the bugs); who hits air agrees with Defs
everywhere; every unit leaves a body; no script error was raised in any of the three games.

### Bugs found and FIXED (0.33.8)

1. **RELEASE did not let the horses go for good.** LEAD sends a Labourer or soldier for up to three horses, one after
   another (queued orders). Pressing RELEASE while he was still fetching let go of the horses in hand, then he went on
   and took the rest: 4 s after RELEASE he held a horse again. Also, RELEASE was never sent online (the HUD called
   `release_horses()` directly, not through the host): a guest's RELEASE happened only on his screen.
   Fix: `Unit.cmd_release()` (lets go, drops the queued LEAD orders, stops a fetch under way; goes through
   `net_forward`, listed in `NetCommands.ENTITY`), used by the RELEASE button. Test: "RELEASE (pressed while he still
   fetches more)" in the Crown rules (FAIL before the fix, PASS after).
2. **Buttons with no tooltip:** TEAM (Field Cannon, Mortar, Powder Wagon: how many horses it keeps) and the gate's
   LOCK / UNLOCK showed only their name. Added to `Hud.CMD_TIPS`, with pt/es (tools/i18n/59_qa_content.txt).

### Bugs found and NOT fixed (they change balance: the owner decides)

3. **The Field Cannon and the Mortar hit a building they are told to attack with their building bonus TWICE.**
   `Unit._strike` multiplies the damage by `building_bonus` when the target is a building, and the shot's landing
   (`Game.round_shot_land`, `Game.mortar_land`) multiplies it by the bonus again for the building where it lands.
   Measured, one shot on a building:
   - Field Cannon: **270** (32 x 2.5 x 2.5 = 200, plus the splash's 32 x 2.5 x 0.35 x 2.5 = 70) instead of 80 (+28
     splash) = 108; the card says 14.7 a second on buildings, it does about 40-54.
   - Mortar: **68** (30 x 1.5 x 1.5) instead of 45.
   - With ATTACK GROUND on the same spot the shot is raw (`_fire_at_spot`), so it does the intended 108 / 45: the same
     gun does 2.5x (cannon) or 1.5x (mortar) more to a building by right-clicking it than by bombarding it.
   - Reproduce: `test_content_all.gd -- only=crown`, line "unit:cannon fight vs a building ... one shot does 270".
   - The one-line fix: in `Unit._strike`, skip the generic `dmg *= building_bonus` for the cannon's round shot and the
     mortar (`kind == "mortar" or (kind == "cannon" and mode != "canister")`), since their landing adds it. NOT done:
     the Crown's sieges (the computer's Siege push, the owner's own games) have been played and tuned with today's
     numbers; fixing it cuts the cannon's siege by 2.5x. If the owner wants the old punch, raise the cannon's
     `building_bonus` instead so that the card, a right-click and ATTACK GROUND all agree.
   - Related: `Game.explode` (the round shot's splash) multiplies its damage to buildings by a fixed 2.5 whatever fired
     it (only the cannon uses it now, and the retired Line roster).

### For the owner to look at (WARN)

- **ATTACK on unarmed units' cards.** The Powder Wagon, Messenger, Observation Balloon, Great Winder, Marching Band and
  Missionary show ATTACK; told to attack an enemy they do nothing (as an attack-move they just walk). Either hide it or
  make it a move for them.
- **Missing voices:** Mortar, Powder Wagon, Messenger, Officer (dismounted), Observation Balloon, Marching Band, Mounted
  Missionary have no voice/<kind>/select|move|attack lines (silent when picked or ordered). The Horse and the Dragoon
  have only the horse's neigh.
- **Missing animation strips the game asks for** (the unit shows idle instead):
  - the Officer (dismounted) asks for `reload` between pistol shots: no such strip (the Musketeer has one);
  - the Mound Turtle asks for `attack` when it fights uprooted: no such strip.
  - The Observation Balloon has no walk strip (it floats on its idle frames: probably meant).

### Information (INFO lines; not bugs)

- **Views the art doesn't have** (the nearest view is used; mostly the Brood's SE-first art direction):
  Brute (attack, charge, death, walk in S/SE/NE/N), Raptor (attack, leap, death), Grub (attack, death), Mist Toad
  (fog, tongue, death), the Sires and the Mound Turtle (root, rooted, uproot, death drawn in SE only), the Rootmaw
  (fill, death), the Brood Mother (death), the Marching Band (idle, walk, death in SE only), the riders' `mount` (no NE),
  the Missionary (bandage in S and NE, death in N).
- **Shared sounds:** no own death sound for the Labourer, Musketeer, Field Cannon, Mortar, Powder Wagon, Horse,
  Messenger, Dragoon, Officer, Pikeman, Balloon, Band, Missionaries (the faction's death sound plays); no own attack
  sound for the Labourer and the Officer; no own select sound for the Armoury. Every Clockwork and Brood unit has its own.
- **The Free Assembly** has no sprites of its own yet (stand-ins, as planned) and its roles' descriptions have no pt/es,
  but they are not shown anywhere in the game yet.
- **Bodies with no spoils:** the Brood Mother, the Rootmaw and the Mound Turtle are worth 0 spoils when harvested (no
  supply: `Game.corpse_value` goes by supply and kills).
- **Fights well off the card's figure but by design:** the Pendulum hits x1.42 on a Light dummy (its sweep's +50% vs
  light), the Ticking Owl x1.41 on a building (its bomb), the Rootmaw and the Storm Challenger x1.3, the Spitters and
  the Venom Challenger x1.3-1.8 on buildings (the acid's damage over time), the Netter 0.3 a second (its net is the
  point; it doesn't fire at buildings).

### Numbers that look out of line (cost per effect, for the owner; nothing changed)

"price" = gold + 2 x the second resource or Tension (a Brood egg's price shared by its young; a rider's horse included);
"pow/100" = sqrt(damage a second x health, armour counted as 8% more health a point) per 100 of price. Median of all
fighters: about 28.

| unit | price | dps | hp | pow/100 | vs median | note |
|---|---|---|---|---|---|---|
| Tyrant Sire (tyrannosaur) | 150 | 16.2 | 1000 | 91 | x3.3 | a structure too (a father on his nest), but uprooted he is a 1000 hp brawler for 150 |
| Rootmaw | 75 | 7.2 | 450 | 76 | x2.7 | an economy creature that bites 7 a second with 450 hp |
| Raptors | 25 each | 4.4 | 36 | 51 | x1.8 | cheap and fast (the early rush) |
| Pikeman (campaign) | 50 | 6.2 | 85 | 48 | x1.7 | campaign only |
| Officer (dismounted) | 75 | 10.9 | 80 | 41 | x1.5 | more per gold than the Musketeer (33) and the Horseman (27) |
| Storm Challenger | 210 | 8.5 | 150 | 17 | x0.6 | the weakest of the mature forms for its price (the Tyrant Challenger 28) |
| Mortar | 185 | 5.0 | 120 | 14 | x0.5 | splash and range not counted |
| Mist Toad | 150 | 1.8 | 90 | 8 | x0.3 | a caster (fog, miasma, tongue) |
| Netter | 175 | 0.3 | 120 | 3 | x0.1 | its net is the point |

The whole table is printed by the tool ("NUMBERS"). Splash, range, speed and spells are not in this one number: read it
as "is this unit paid for by something the number can't see?".

## What the test cannot check

- How things LOOK and SOUND: an animation can exist and still be wrong (a frame out of place, a wrong facing), a sound
  can exist and be the wrong one. The art and sound checks only prove the files are there and the strips are whole.
- Timing and feel: build times measured include the walk and the crate; only "it finishes" is checked.
- Rules that need a real game to show: the Cavalry Charge's double blow, High Leap onto a cliff, Swamp Mending, Updraft's
  air speed, the Shield Wall's frontal reduction, Battering Horns on a wall, the fog's misses, the Tongue's pull, the
  Balloon's drops, the Great Winder's sweep for cogs, resource exhaustion, the computer's use of any of it (qa-matches).
  These are only checked as "researched / the button does something".
- Online play and replays (each press is a local call; the net lists are read, not exercised).
- The retired Clockwork roster and Line economy (Defs.retired, kept for old saves) and the old Brood (refused on load).
- Balance: the numbers table is arithmetic on Defs, not results of games.

## Claude's choices for the owner

- The Cannon/Mortar double building bonus is reported, not fixed (see bug 3): it would cut the Crown's siege a lot.
- "Unarmed units with ATTACK" is a WARN, not changed: maybe meant as attack-move.
- A label put together from translated pieces (the Mother's "LAYING +15%") is not counted as untranslated.
- Retired units and buildings are SKIPped, not tested; campaign-only entries (Pikeman) are tested in the Crown's game.
- The fights use a dummy that can't fight back, with armour 0 and huge health: the measured damage is the weapon's,
  not a duel's outcome.

## For the other QA jobs

- `tools/test_horses.gd` (qa-tests) still expects "Musketeers need a Powder Mill": crown-ammo (0.33.x) removed that
  rule on the owner's word; the check is out of date, not the game.
