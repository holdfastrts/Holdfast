# RELOAD: send gunpowder units for powder (reload-command, 0.35.17)

The owner (2026-11-13 23:59): "for every gunpowder unit we should have a command to reload / grab powder, meaning if the
unit is 5/10 we give the command and it goes to the powder wagon or any powder source and gets to 10/10. So another icon
and command for the command card."

Code: `scripts/reload_order.gd` (ReloadOrder). Test: `tools/test_reload_command.gd`.

## What it does

- **Who gets the button.** Every selected unit of yours whose firearm uses powder: it is found by the ammunition code
  (`Unit.ammo_weapon()` and `ammo_max()`), not by a list. Today that is the Musketeer, Guardsman, Dragoon (mounted or on
  foot), Horseman, Cuirassier, Officer (the pistol), Field Cannon and Mortar. A unit added later with ammunition gets it
  by itself. The Observation Balloon keeps its own RESTOCK (its store fills its riders); men riding in a basket are left
  out (they refill from the basket).
- **When it shows.** Always on such a card, so its key never moves; it is lit while any selected one is below a full load,
  greyed ("They are all full.") otherwise. The corner shows the shots of the whole selection (for example 23/40).
- **Key: R** (the card's other commands keep theirs; R is free on soldier and gun cards. REPAIR, a must-have key, wins R
  on a card with Labourers in it, and RELOAD then takes another letter).
- **Icon:** `assets/icons/ab_reload.png`, the owner's ChatGPT drawing (in since 0.35.16), so no placeholder was needed.
- **Tooltip:** its name, what it does, and the powder the first low unit would go to ("Nearest powder: the Powder Mill.";
  "No powder to reload from now." when there is none).

Each unit that is below full, on the press:

1. **Picks the nearest powder that can fill it now**: a Powder Mill, a Barracks (with ARM WITH POWDER on) or a Town Hall
   while the bank holds at least one shot's powder; a Powder Wagon holding a shot; a powder keg on the ground. One already
   in reach is taken at once; otherwise the (up to) three nearest in a straight line that are not much farther than the
   nearest (1.6 times) are pathed and the shortest walk wins (so a Mill across a cliff loses to a wagon up the ramp); a
   source with no rival that close is taken without pathing (a press may send a hundred men).
2. **Walks there.** A crowd spreads round the source: each man takes the next place on a ring around it (alternating sides
   from the first man's side; a second ring after 8). A set-up Field Cannon or a deployed Mortar limbers up first. A
   wagon that rolls on is followed.
3. **Stands until full.** The refill is the usual one (`Unit._powder_tick`, `_take_shots`): the same price, the same speed
   (2 shots a second), the bank or the wagon pays as before. Nothing new is paid or given.
4. **If the source runs dry** (nothing came in for 3 s while in reach, the bank emptied, the wagon is empty or gone) it
   goes to the next nearest; with none left it stops where it is and says "No more powder to reload from: the bank and
   the wagons are empty." A trip that can't arrive within 2 minutes stops with "Couldn't reach the powder: stopped."
5. **Full, it walks back to where it was when the reload began**, then carries on with its Shift-queued orders.

If nobody selected can be filled now, nobody goes and the card says "No Powder Wagon, keg, or Mill, Barracks or Town Hall
with powder to reload from."

## Choices made (Claude's; the owner may change any)

- **It comes back.** A reload in battle is a trip to the wagon behind the line and back: the unit returns to the spot it
  stood on when the reload began. (Easy to drop: `ReloadOrder._finish`.) A gun comes back limbered; it does not set up
  again by itself (see open questions).
- **Shift** queues the reload after the unit's other orders, like any order; a move queued after the reload starts once
  the unit is back at its spot.
- **A gun without its horse** is not sent (it can't move): as before, a hauler brings it a keg (`Unit.needs_keg`).
- **Units already full are not sent**, even in a mixed selection; the others go.
- **The computer is unchanged.** `scripts/ai_crown_ammo.gd` still walks its empty men to a reloading point and keeps them
  there (no walk back: its army orders take them on). Switching it to RELOAD would change how it plays (the walk back,
  the sources it picks), which the job said not to do.

## Online, replays, saves

- The command is an ordinary order, `Unit.give({"o": "reload"}, shift)`, so a guest's RELOAD goes to the host through the
  same funnel as every other unit order (`NetCommands` "give"), and mixed replays record it as they record the other
  orders. FULL replays record pictures, as always.
- Saves keep a unit on its way (`"rld"`: the spot it goes back to); on load it picks its source again and goes on.

## Open questions for the owner

1. Should a gun that was set up when it left **set up again** when it gets back (it comes back limbered now)?
2. Should **HOLD**, or a unit in a fight, go back to holding when it returns? (It comes back and stands, as after a move.)
3. Should the computer use RELOAD (with the walk back) for its own men?
4. Should units that are only a little short (say 9 of 10) be left out of a group reload, so a press sends only the ones
   that really need it? (Now any unit below full goes.)
