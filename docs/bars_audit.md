# The bars audit (bars-audit, 2026-11-04)

The owner, 2026-11-04:
1. "For the Mainspring I want an indicator of how pressed it is, like a bar, but the bar itself is a COIL, and the coil
   presses as it shows how much Tension the Mainspring has."
2. "Check every bar and indicator that stays on top of buildings: many are overlapping the sprite, the Rootmaw comes to
   mind but I'm sure many others."
3. (07:45) "The Brood Mother's stage 2 egg count gets too far out."

Pictures: docs/shots/bars_audit/ (captions.md). Test: tools/test_bars_audit.gd. Pictures made by
tools/shot_bars_audit.gd (every building kind of a faction side by side, hurt, training, a site; the Brood's rooting
creatures; the Mother at stages 1-3; the coil gauge at four fills).

## What was wrong

Buildings placed their bars from the top of the picture DOWNWARD: the health bar started 2 px under the picture's top and
the building / training / research bar 7 px under it, so both lay across whatever reached highest: the Town Hall's
spire, the Barracks' flag, the Foundry's chimney, the Church's steeple, a Cottage's roof, a windmill's sails, the Clockwork
buildings' crowns. The Clockwork's UNLINKED / NEEDS MAINSPRING badge was placed from the FOOTPRINT (the ground square), and
every Clockwork building is taller than its footprint, so the badge sat on the picture; the gold spring mark sat on the
footprint's corner, on the picture too. The Brood's rooting creatures did the same over their bodies (the Rootmaw's food
bar, ground bar and "dry" were drawn ON its back), the Sires' nest bar lay over their health bar, and the progress bar
(GROWING, ROOTING, RESEARCHING) could cover a Sire's egg line or a Rootmaw's label.

The Mother's egg line: her bar was placed at the highest her body had reached since she took her picture, and her LAYING
show (she rears up) and her swipes reach 30-50 px over her rooted loop, so after her first egg the bar and the egg count
floated well above her. At stage 2 it was also latched from her standing picture, taller than her nest. It was also not
centred over her (it started 14 px left of her middle and ran to the right).

## The fix: one stack above the picture

Everything over a building now stands in ONE COLUMN ABOVE ITS PICTURE'S REAL TOP (Building.sprite_top: the first painted
row of its picture; the Farm's sails and the Ratchet Turret's head count), bottom up, 2 px apart, each in its own row:

1. the health bar;
2. the work bar (a site going up, training, research, a Farm's crop);
3. the Mainspring's coil gauge;
4. the worker label (HAULERS / FARMERS / POWDER MAKERS / WINDERS, the efficiency bar and %);
5. the gear badge (UNLINKED / NEEDS MAINSPRING);
6. a gate's padlock.

A row is kept for everything a building CAN show (shown or not: a full health bar is still hidden, as the owner wants), so
nothing jumps when a bar comes or goes. Building.bar_slots works the rows out; WorkerLabels and GearNet place theirs from
it. The spring mark stands just above the picture's top, to the right of the bars.

The Brood's rooting creatures get the same (BroodNew.stack): the health bar just above the picture's top (the highest row
of the strip it plays now, BroodRoot.strip_top: steady through a breath or a step), then a Rootmaw's food and ground bars,
its "dry", its GRUBS label; a Sire's nest bar and his egg line; the Mother's egg line; the progress bar and its word on
top. The Mother's place is taken from her loop (rooted, standing, walking) at her current stage, never from her laying
show or her swipes, so it stays put while she lays and sits close above her at stages 1, 2 and 3. Her egg line and the
Sires' lines are centred over them.

Sizes are unchanged (same bars, same text: as readable on a phone as before); only their places moved. Everything is in
world space, so it scales with the zoom as before.

## The coil gauge (scripts/coil_gauge.gd)

Over every finished Mainspring, in its row of the stack, for its side and allies (spectators and the demo too: the
production bars' rule). A brass spring lies in a dark slot: its left end on a fixed plate, a pressing plate on a steel
rod coming in from the right. EMPTY: relaxed, the spring runs the whole slot. As the side's Tension fills what its
Mainsprings store (200 a small gear, 400 a big one; Tension is one pool, so every Mainspring shows the same fill) the
plate drives in and the coils press together; FULL: the coils touch, pale gold, with a bright rim. FATIGUED (its
Clocktower's spring life spent): the same spring gone dull grey-brown, slack and sagging. The fill eases toward the
pool (a spend or a refund presses or lets it out over about a second, no jump). Cheap: two line lists for the wire,
drawn with the building's other bars (6 times a second while on screen), its points in two arrays made once.

## Every indicator

| indicator | over | overlapping or misplaced before? | fix |
| --- | --- | --- | --- |
| health bar | every building, all factions | yes: from 2 px under the picture's top downward, over spires, chimneys, flags, sails, the Clockwork crowns | row 1, its bottom 2 px above the picture's top |
| building bar (a site going up) | every site | yes: 7 px under the top, across the scaffold / roof | row 2 |
| training / research bar | Town Hall, Barracks, Breeder, Foundry, Armoury, Church, Clocktower, Works, Escapement, Aviary... | yes: 7 px under the top, across the roof | row 2 |
| crop bar | Farm | yes: on the windmill's sail tips | row 2 (the sails count in the picture's top) |
| worker label: HAULERS, FARMERS, POWDER MAKERS, WINDERS, efficiency % | Town Hall, Farm, Powder Mill, Cog Press, Mainspring, Works... | sat above the top, but the bars under it lay on the picture; spacing differed between kinds | row 4, always just over the bars |
| UNLINKED / NEEDS MAINSPRING badge | Clockwork buildings | yes: placed from the footprint, on the picture (and close to the worker label) | row 5 |
| spring mark (gold coil) | Tension users fed by a Mainspring | yes: on the footprint's corner, on the picture | just over the picture's top, right of the bars |
| padlock | gate | no (but placed by hand) | row 6 |
| Tension | Mainspring | none existed | the coil gauge, row 3 |
| health bar over the turret | Ratchet Turret | its head was not counted in the picture's top | the head counts |
| health bar | Brood rooting creatures (Mother, Rootmaw, Mound Turtle, the three Sires) | yes: from 2 px over the body downward, over spikes and wing tips | just above the strip's top (+ a row for the reload bar of those that attack) |
| food bar, ground bar, "dry" | Rootmaw | yes: drawn ON its back (6, 10 and 22 px under its top) | rows above its health bar |
| GRUBS label | rooted Rootmaw | close over the old bar, on the food bar's level at times | its own row above the food rows |
| nest bar | rooted Sires | yes: on the health bar | its own row |
| "N eggs" / "too far from the Mother" | rooted Sires | left-anchored, off-centre; the progress bar could cover it | centred, its own row |
| GROWING / ROOTING / UPROOTING / RESEARCHING bar | Brood rooting creatures | a fixed 10 or 26 px over the bar: on the Sire's line, the Rootmaw's label | top of the column |
| the egg line ("Eggs 4/15 2.7s · 00:47") | Brood Mother, stages 1-3 | yes: latched to her laying show and swipes (30-50 px too high), at stage 2 also to her taller standing picture; off-centre | over her loop's top at her stage, steady while she lays; centred |

Not changed: the "+N" income numbers (they rise and fade), the batteries over Line-mode energy buildings (an old mode),
the eggs' own hatch bars, ordinary units' bars.

## Checked

- tools/test_bars_audit.gd: every Crown and Clockwork building kind (finished and hurt, and a site): the stack starts at
  the picture's real top, the health bar's bottom at most 6 px above it, each row above the one below (the worker label's
  plate exactly on its row); the coil shortens as Tension rises and reads the side's pool; the Brood: the Mother rooted
  at stages 1, 2 and 3 (grown where she stands, as in a match), a Rootmaw on her swamp, a Mound Turtle and the three
  Sires: the health bar above the picture and within 10 px of it, the rows above it in order, the egg line above her bar,
  and her bar does not move while she lays.
- tools/test_cw_crate_build.gd updated (a rising Clockwork site's bars stay at its whole picture's top); test_worker_labels,
  test_gear_rules, test_haulers, test_kegs, test_phone_crew, test_selection_panel, test_brood_far pass;
  test_egg_tooltips has the same 3 failures as main (chips on the card, not the map).
