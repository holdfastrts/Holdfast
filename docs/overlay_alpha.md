# Overlay opacity, the hall texts with NO FARM/PRESS LIMIT, Farms away from a hall (job overlay-alpha)

The owner's playtest, 2026-11-14 13:18:

> "The overlaying information on top of the soldiers should have some level of transparency; currently it is blocking
> the view and can impede micro. Everything that isn't actual game sprites of units, structures and things happening on
> the battlefield: health bars, veterancy, buff and debuff static status like the band and percentages: they should not
> be fully opaque."

## A. See-through overlays

### What is drawn over the battlefield, and what was done with each

| Overlay | Where | Now |
|---|---|---|
| Health bar (units, buildings, crates, the train, powder kegs) | `Entity.draw_health` | bar opacity, a hurt bar stronger (below) |
| Acid strip over the health bar | `Entity.draw_health` | bar opacity |
| Thin bars: reload / limbering / rooting, Clockwork CHARGE, Powder Wagon powder | `Entity.draw_sub_bar`, `Unit._draw_charge_bar` | bar opacity |
| Powder Wagon horn and SUPPLY dot | `Unit._draw_unit` | bar opacity |
| Building work bar (going up, training, research, a Farm's crop) | `Building._draw_building` | bar opacity |
| Veterancy chevron (0.37.2) | `VetChevrons.place` (the sprite's `self_modulate`) | bar opacity |
| Band buff marks: instrument icons, "+8%", the struck-through out-of-step mark | `MarchingBand.draw_marks` | mark opacity; the NUMBER `sqrt` of it (below) |
| Stun stars | `StunMark._draw` | bar opacity (times their own fade) |
| NO AMMO mark | `Unit._draw_no_ammo` | mark opacity |
| Just-bandaged cross | `Unit._draw_unit` | mark opacity |
| Carrying dots (a Labourer's gold, a Grub's food) | `Unit._draw_unit` | mark opacity |
| Spoils number on a body (Brood players, spectators) | `Unit._draw_number` | mark opacity |
| A campaign's named man (his name over the bar) | `Unit._draw_mission_marks` | mark opacity |
| Moulting bar (Brood), Owl morph bar (Clockwork) | `BroodMature._bar`, `CwAir.draw_morph` | bar opacity (the morph's ring on the ground is a guide: kept) |
| Rootmaw food bar and "dry", the Brood's growing / rooting / research bar and its label | `BroodNew.draw` | bar opacity; the label's outline `sqrt` |
| Selection circles, rally lines, a Maw's claim ring, gun aim lines, the band's rings, AoE previews, ground marks | | **kept as they are**: guides on the ground, thin lines that do not cover the men, and the selected ones are what is being microed |
| Mainspring coil gauge, worker labels, the gear badges (UNLINKED...), a gate's padlock | building column over the picture | **kept**: they stand in their own rows above a building's picture (the bars audit), never over a soldier |
| The Queen's egg countdown | `BroodNew.draw` | kept (one label, read often) |
| Selection-group numbers | HUD only (the bottom bar), nothing over the units | none on the field |
| The Winder's battery strip, the balloon's battery, a grub's cocoon | | kept: they are pictures of things the unit carries |

### The opacities, and why

- **Bars and chevrons: 60%** (`Settings.OVERLAY_DEFAULT`). The bar's colour still reads at a glance against grass,
  sand, snow and moss (pictures below), its dark edge (now 48% black) still frames it, and the men under it show
  through. Lower than ~45% the green bars start to sink into the grass maps.
- **Marks (buffs, debuffs, numbers, status icons): 51%** (bars x `Entity.MARK_K` 0.85). A band at full strength puts
  three icons and "+8%" over every soldier in its ring (the worst cover of all: the "before" pictures); they matter less
  for micro than the bars, so a little fainter. The **number** itself is drawn at `sqrt` of that (about 71%) with its
  outline the same: at 51% the white "+8%" was hard to read on the sand of Dune Sea; the icons keep 51%.
- **Selected units and the one under the mouse: 100%** (`Entity.ov_a`), bars, marks and chevrons alike: what is being
  microed reads clearly. (Phones have no hover: only the selection.)
- **A hurt health bar is a little stronger**: `lerp(opacity, 1, 0.35 x (1 - health))`: 60% at full health (it is only
  drawn when hurt, or with BARS: ALWAYS), 67% at half, 73% at 10%. A dying man's bar reads first in a crowd.

The slider **OVERLAY OPACITY** (Settings > DISPLAY, under BAND BUFF MARKS) goes from 30% to 100%, default 60%, saved in
settings.cfg (`ui/overlay_alpha`), put back by RESET SETTINGS, translated (pt OPACIDADE DAS MARCAS, es OPACIDAD DE LAS
MARCAS) with a hint line under it.

### The cost

Only the colours' alpha changes where they are set: no extra draw call, no extra node. A unit's drawing is cached by its
redraw key; it is now redrawn also when the setting changes or the mouse comes onto it or leaves it (`Unit._ov_k`: one
comparison a tick). The chevrons are placed again at once when the setting changes or the mouse moves onto a veteran
(the selected ones follow in their tenth-a-frame slice, at most 1/6 s later). Buildings redraw 6 times a second already.

tools/stress_swarm.gd `mixed vets`, 200 units (100 Musketeers v 100 Raptors, a third of them veterans), 20 s, headless,
two runs each, main (0.37.4) against the branch:

| | avg frame | median | units ms/frame | unit draw | vet chevrons |
|---|---|---|---|---|---|
| main run 1 / 2 | 6.83 / 7.04 ms | 5.99 / 6.23 | 4.37 / 4.51 | 0.03 | 0.43 / 0.44 |
| branch run 1 / 2 | 6.35 / 6.40 ms | 4.59 / 4.88 | 4.18 / 4.18 | 0.03 | 0.39 / 0.41 |

No regression (the branch's lower numbers are the machine's noise, not a gain).

### Pictures (docs/shots/overlay_alpha/)

`tools/shot_overlay_alpha.gd` (one map per run): two lines of Musketeers (hurt men, veterans of every rank), Horsemen, a
band behind the line with its marks shown ALWAYS, a stunned man, three selected, one under the mouse (its tooltip
shows), the Brood's Raptors and Spitters across the field; the same frame at 100% ("before": today's look) and 60%
("after").

- desktop 1600x900: `desktop_ashford_crossing_{before_100,after_60}.jpg` (grass, usual zoom) and the close-ups
  `desktop_<map>_close_{before_100,after_60}.jpg` on ashford_crossing (grass), dune_sea (sand), frostmere (snow),
  hollowfen (bog moss);
- a phone-sized screen 1280x592: `phone_ashford_crossing_{before_100,after_60}.jpg` and its close-up (the computer
  layout at that size: the test machine's settings say COMPUTER).

## B. The Town Hall and Clocktower texts with NO FARM/PRESS LIMIT on

With the ground system and NO FARM/PRESS LIMIT on (`Defs.ground_on and Defs.ground_nocap`: `Defs.nocap_now`), the hall
texts no longer say "allows 2 Farms" / "2 Cog Presses": `Defs.nocap_text` swaps the sentence (`Defs.NOCAP_SUB`) in the
card's line (`short_of`), the portrait's tooltip (`about_of`), the hover tip (`tip`, `GEAR_TIPS`) and the HUD's info
line (`hud.gd`, Town Hall and gear-mode Clocktower):

- Town Hall: "Its Farms are limited only by the soil of its district; 1 Powder Mill nearby." (the about), "Farms
  limited only by its district's soil; 1 Powder Mill nearby; its soil and saltpetre run out in time." (the tip),
  "Trains Labourers and haulers. Farms: as its soil allows; 1 Powder Mill." (the card's line, within 80 characters in
  all three languages), "... · Farms limited only by its district's soil, 1 Powder Mill nearby" (the info line);
- Clocktower: "Its Cog Presses are limited only by the brass of its district; 1 Mainspring nearby." and "... · Cog Presses
  limited only by its district's brass, 1 Mainspring nearby".

With the experiment off (or the ground system on without NO LIMIT) every text is as before. Each new text is a key of
its own in `tools/i18n/69_overlay_alpha.txt` (pt and es made from the old translations with the same sentence swapped).
Not changed: the general help page's sentence "Each Town Hall allows 2 Farms and 1 Powder Mill nearby" in the
Labourers' economy paragraph (the game's rules page, not a hall's card; it still describes the default game).

## C. A Farm away from every hall

Not changed: with the ground system, ground lies only in a district round each hall (docs/ground_system.md), so a Farm
or Cog Press away from every hall is still refused. Made clear instead:

- the refusal says why, with the ground system on: "No soil here: Farms draw on the soil of a Town Hall's district."
  (Clockwork: "No brass here: Cog Presses draw on the brass of a Clocktower's district.": `Game.NO_GROUND_MSG`),
  translated; off, the old "Must be near your Town Hall." stays. (A Clockwork press far away is usually refused first by
  the gear rule: its ring must mesh with the field. That message already says why.)
- while placing a Farm / Cog Press, the player's own halls' districts of that ground show their edge clearer
  (`GroundView._draw`: a thin dark under-stroke and a soil-gold / brass edge at 0.3 x GROUND LAYER + 0.4 opacity; it was
  a faint white line at 0.17), so where Farms can stand is seen before trying. Placing anything else keeps the faint
  white edge.

## Tests

- **tools/test_overlay_alpha.gd** (new, 31 checks): the default 60%, saved and read back, clamped at 30%, RESET; a
  unit's bars at the setting and its marks at x0.85; selected and hovered full; the neighbour stays see-through; a hurt
  bar stronger (0.60 / 0.67 / 0.73), selected-and-hurt full; a building's bars; the redraw key changes on hover and on a
  new setting; a chevron's opacity follows the setting, selection and the mouse at once; part C's two messages; part B's
  texts on and off, translated in pt and es, the card's line within 80 characters.
- tools/test_settings_tabs.gd: OVERLAY OPACITY (and BAND BUFF MARKS, which was missing from its list) in exactly one tab,
  DISPLAY: ALL PASS.
- tools/test_qa_settings_persist.gd: the slider changes the setting and it is saved, computer and phone; band_marks added
  to its snapshot and to its many-way choices (it failed on main: "pressed changes it" saw no change because the
  snapshot lacked it; a 3-way choice is not back after two presses): 0 failures.
- test_ground_system, test_ground_nocap, test_vet_chevrons, test_marching_band, test_stun_mark, test_bars_audit,
  test_card_text, test_i18n: pass. test_marching_band_match (the Crown computer training a band) fails its 3 checks on
  main too (run on origin/main 0.37.4 the same day: the computer trains no Drummer): not this job.
