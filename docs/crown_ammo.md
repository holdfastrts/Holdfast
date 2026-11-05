# Crown ammunition, no powder lock (crown-ammo, 0.32.0)

The owner's rule of 2026-11-05 (07:48 to 07:58), built on the branch `crown-ammo`.

## The rule

1. **No powder lock.** Barracks units need no other building: the Musketeer no longer needs the Powder Mill, the
   Officer no longer needs the Horse Breeder (an Officer without a horse walks). Mounted and limbered units keep the
   Horse Breeder requirement: the Horseman (and the Cuirassier), the Dragoon (it needed the Mill AND the Breeder; now
   only the Breeder), the guns and the wagon. A Horseman with no horse is an Officer, as before.
2. **Powder buys the shots.** Every Barracks soldier with a firearm pays powder for his ammunition when he comes out
   (`Game.arm_recruit`, `Defs.AMMO`):
   - with a full load's powder in the bank he comes out armed;
   - with less he takes what there is (a PARTIAL load: 6 powder, 6 shots);
   - with none (or ARM WITH POWDER off) he comes out with ZERO shots and fights with his melee weapon (the Musketeer's
     bayonet, the Officer's and Horseman's sabre) until he refills.
   The powder is taken when he comes out, not when he is queued (the bank as it is then decides his load).
3. **Refills are paid from the bank, shot by shot**, at a Mill, Barracks, Town Hall or Powder Wagon (the wagon's
   own load, already paid, as before). No free refills (there were none before either).
4. **ARM WITH POWDER**, a toggle on the Barracks' command card (on by default; glowing = on), with a tooltip, in
   en/pt/es. Off: its recruits come out with no shots, the powder is kept for the guns, and that Barracks is not a
   reloading point (otherwise a dry man coming out of it would refill on the spot and the toggle would save nothing).
5. **The gold-only rush is allowed**: the Horseman rush (the Horse Breeder costs only gold) works as before; its riders
   come out with the sabre only until there is powder in the bank.
6. **The ammo icon on the unit card** for every firearm (below).

## The numbers (what I chose)

| | full load | powder | how |
|---|---|---|---|
| Musketeer, Guardsman | 10 shots | 10 | his old price: 10 powder for his 10 shots, so **1 powder a shot** |
| Dragoon (on foot: a Musketeer) | 10 shots | 10 | the same |
| Officer, Armoured Officer | the loaded pistol + 4 charges = 5 shots | 5 | **1 powder a pistol shot**, like a musket ball (he cost 0 powder before; the pistol's 4 charges cost 0.5 each to refill) |
| Horseman, Cuirassier | the same 5 | 5 | the same pistol |

- **Refills: 1 powder a shot** for muskets and pistols (they were 0.5). Training at 1 a shot and refilling at 0.5 would
  have made training a man dry and refilling him at the Barracks the cheap way (5 powder instead of 10), and the
  toggle would have saved nothing. Cannons and mortars keep 1.5 a shot.
- **The Powder Wagon fills at 1 powder a shot** (it was 1 per 2 shots), so a shot from the wagon costs what a shot from
  the bank costs; a keg (30 shots) is 30 powder; a cannon shot takes 1.5 of the wagon's musket shots (was 3).
- **The Shot Pouch**: a soldier refitted with it carries 20 shots; the extra 10 are bought at the next refill, 1 powder
  each (a bigger load costs more powder). Recruits still don't come with it.
- **An empty pistol is loaded at a reloading point**, even in the saddle (before, a Horseman could only reload on foot:
  a dry Horseman would never get his shot otherwise). On foot the Officer still reloads by himself (4 s, a charge).
- **The guns** (proposal, not changed): the Field Cannon still comes out with its 8 shots for 0 powder, the Mortar with
  its 6 shells for 20 powder paid when queued. The same rule would fit them plainly (a cannon load: 8 x 1.5 = 12 powder,
  a mortar load: 6 x 1.5 = 9 powder, taken when it comes out, partial loads, the Mortar's 20 queued powder dropped), but
  it changes the guns' price and the Foundry's opening, so it waits for the owner.
- **The Crown starts with 0 powder** (unchanged): an early Barracks soldier comes out dry until a Mill grinds.

## The card's ammo icon

The Horseman's pistol icon (bright loaded, smoking empty) after the health figures is now the ammo icon of every
firearm: the musket (Musketeer, Guardsman, Dragoon), the pistol (Officer, Horseman, Cuirassier), the cannon ball
(Field Cannon) and the mortar shell (Mortar). The musket, the ball and the shell are drawn in code (logged in
docs/art_style_inconsistency.md); the pistols are the painted icons.

- beside it, **the shots left** (a pistol counts its loaded shot and its charges);
- **0 shots**: a red "no" sign (a ring with a slash) over the weapon and **NO AMMO** under it;
- **reloading** (between shots, the Officer reloading his pistol, or refilling at a reloading point or a wagon): a bar
  under the icon fills up with **RELOADING** under it (refilling: the bar is the load filling up);
- on the field, a small red "no" mark beside the health bar of your men (and allies') with no shot.
- The train button's corner shows gold + powder (`60+10`; `60+6` with 6 in the bank; `60` alone when he'd come out
  dry), and its tooltip's cost line says it: `60 gold · ammunition: 10 powder for 10 shots`, `6 of 10 shots (6 powder)`,
  `no ammunition (no powder)` or `no ammunition (ARM WITH POWDER off)`.

Pictures (docs/shots/crown_ammo/, tools/shot_crown_ammo.gd):

| | |
|---|---|
| ![full](shots/crown_ammo/1_card_musketeer_full.png) | a full Musketeer: the musket and 10 |
| ![no ammo](shots/crown_ammo/2_card_musketeer_no_ammo.png) | 0 shots: NO AMMO |
| ![reloading](shots/crown_ammo/3_card_musketeer_reloading_shot.png) | RELOADING between shots |
| ![refilling](shots/crown_ammo/6_card_musketeer_refilling.png) | RELOADING while he refills at the Town Hall |
| ![horseman](shots/crown_ammo/5_card_horseman_no_ammo.png) | a dry Horseman: NO AMMO on the pistol |
| ![field](shots/crown_ammo/4_field_no_ammo_marks.png) | the no-ammo marks on the field |
| ![barracks](shots/crown_ammo/7_card_barracks_arm_with_powder.png) | the Barracks' card: ARM WITH POWDER, the train buttons' powder |
| ![tip](shots/crown_ammo/8_tip_musketeer_partial_ammo.png) | the Musketeer button's tooltip with 6 powder in the bank |
| ![tip off](shots/crown_ammo/9_tip_arm_with_powder_off.png) | ARM WITH POWDER off, its tooltip |

## The Crown computer (scripts/ai_crown_ammo.gd, every plan)

1. **It trains armed men**: a Musketeer or Dragoon is queued only with a full load's powder in the bank (as when he
   cost 10 powder) and ARM WITH POWDER on (AI._soldier_key and the Dragoon raids ask `musket_ok`). Riders are queued
   as before (a dry rider has his sabre). A deliberate rush (the Horse Breeder opening) never waits for powder.
2. **It keeps powder for its guns** with the toggle: off at every Barracks while a Mortar waits in a Foundry's queue
   or one of its guns is under half its shots, and the bank is under 30; on again at 40. (A first version also switched
   it off while a Foundry had no gun yet: in the first coached game the Economy plan then trained no Musketeers for
   minutes. Dropped.)
3. **It sends empty men to refill before a fight**: every 2 s, a man with a firearm under 40% of his load (a pistol:
   empty with no charge), with no enemy within 10 tiles and a reloading point within 22 tiles (a Mill, Town Hall or
   armed Barracks with powder in the bank, or the stocked Powder Wagon), walks to it and stays out of the army's orders
   (AI._on_errand) until he is full, the powder runs out or 30 s pass. A deliberate rush's riders are left alone.
4. **It never sends bayonet-only Musketeers into a gunfight on purpose**: they are not trained dry (1), and dry ones go
   to refill (3); a wave already out keeps its men (only those near a reloading point are pulled back).
5. **The Horseman rush is unchanged** (its riders come out dry until the first Mill grinds).

## Coached games

RESULTS

## Open questions for the owner

- **The refill price.** I made a shot cost 1 powder everywhere (training, refills, the wagon) so that training dry and
  refilling is never cheaper. It doubles what refills cost the Crown. The other way: keep 0.5 a shot everywhere and
  make a full Musketeer 5 powder (half what he cost).
- **The guns** under the same rule (above): a cannon load 12 powder, a mortar load 9, taken when they come out?
- **The Horseman rush's pistols**: the riders now come out with no pistol shot (the Crown starts with 0 powder). A
  small starting powder (say 25) would give the first five riders their shot; it would also arm the first Musketeers.
- **The Officer** needs nothing now: 75 gold, 3 supply, a pistol and a sabre on foot from the first Barracks. Is he too
  early a unit against the Brood's first Raptors? (Not seen in the coached games: the computer doesn't train Officers.)
- **The dry men's refill at the Barracks they come out of**: with ARM WITH POWDER on and powder arriving later, a dry
  recruit standing by the Barracks fills up by himself; with it off, that Barracks never refills anyone. Fine?
