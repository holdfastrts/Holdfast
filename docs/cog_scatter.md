# SCATTER COGS: the Great Winder's slow field

The owner's idea (2026-11-01): "I think I found a way to cast a slow spell for clockwork without magic. The Great Winder
could have a spell that it throws a lot of cogs and parts from its top in an area of effect, littering the ground with
stuff. This would make that area a slow field."

Built on branch `cog-scatter` as version 0.26.3.
Code: `scripts/cog_scatter.gd` (rules, card, computer, looks). Numbers: `Defs.COG_SCATTER`.
Test: `tools/test_cog_scatter.gd`. Pictures: `tools/shot_cog_scatter.gd`, written to `docs/shots/cog_scatter/`.
Icon: `tools/make_cog_scatter_icon.py` (a stand-in, see prompt 3).

## What it does

Select a Great Winder, press SCATTER COGS (key C), and tap a spot.

1. If the spot is farther than 6 tiles, the Winder rolls closer first.
2. Its key arm winds for half a second. This is the warning: the enemy can see it coming.
3. Its hopper flings 34 pieces into the air: cogs, bolts, springs, nuts and small plates. They fly for 0.6 seconds.
   The edge of the field is marked on the ground from the throw, so the enemy can see where it will land.
4. The pieces land and litter a circle of radius 2.5 tiles (80 px).
5. For 15 seconds, ENEMY units ON THE GROUND whose feet are in the litter move 40% slower.
   Their attacks are not slowed. Flyers are not slowed. The Clockwork's own units are not slowed.
6. A unit that walks out of the litter is free a quarter of a second later.
7. A slowed unit shows three small cogs turning round its feet.
8. The litter fades over its last 1.5 seconds.

It costs 40 cogs, paid at the throw. The hopper then needs 25 seconds to refill.
A throw that is refused (the hopper is not full, too few cogs) costs nothing.

## The numbers (Claude's guesses, to be tuned)

All in `Defs.COG_SCATTER`.

| key | value | what it is |
| --- | --- | --- |
| range | 192 px (6 tiles) | how far it throws; farther, it rolls closer first |
| radius | 80 px (2.5 tiles) | the litter's circle (the squashed ellipse every field uses) |
| time | 15 s | how long the litter lasts after it lands |
| slow | 0.6 | speed in the litter: 40% slower |
| linger | 0.25 s | the slow left after stepping out |
| cost | 40 cogs | paid at the throw |
| cooldown | 25 s | the hopper refills |
| cast | 0.5 s | the key arm's windup before the throw |
| flight | 0.6 s | the pieces in the air |
| parts | 34 | pieces thrown (looks only) |
| air | false | true would slow flyers too |
| slows_own | false | true would slow everyone in it, the Clockwork's own units too (the owner may want this) |
| ai_min | 4 | the computer's smallest clump worth a throw (melee counts 1.5) |

Why these numbers (design principles 1 and 2):

- 40% slower is the same as the Storm Engine's acid slow (`Defs.ACID_SLOW`, 0.6). Two slows in the game, one size. They do not stack.
- Only movement is slowed, not attacks. A slow on attacks too would be a hard counter. This one is soft: walk round it, or through it quickly.
- A radius of 2.5 tiles is a little smaller than a Mist Toad's fog (3 tiles) and the same as the Stormcaller's storm.
  It catches a clump, not an army spread out. Spreading out is the counter.
- 15 seconds is long enough to matter for a charge or a chase, and the area is fixed: the enemy can go round.
- 0.5 s windup, a 0.6 s flight, and the edge marked on the ground at the throw: a fair warning (principle 1: telegraph).
- 40 cogs is a bit more than half a Clock Soldier (70). It is cheap because the Great Winder must be close to the fight to throw it, and it is slow (27 px a second) and unarmed.
- 25 s means one field per fight per Winder, not a carpet.
- Not on flyers: a pile of cogs on the ground does not stop a flyer. It matches the fiction.
- Not on own units: the Clockwork throws it in front of its own line, to hold a charge off or to catch a running army. If the owner wants friendly slowing (the stuff is on the ground for everyone), set `slows_own` to true.

## The computer

`CogScatter.ai_tick`, called from `AI._abilities` (one line in `scripts/ai.gd`), on difficulty Easy and up.
A Great Winder that can throw looks at enemy ground units it can see, within its throw, where they will be when the pieces land.
It counts the ones that are:

- CHARGING: melee units (range under 60 px: Raptors, Horsemen, Brutes...) moving toward our army, our Great Winder or our base, or
- RUNNING AWAY: any unit moving away from our army, with our army within 360 px.

Melee counts 1.5, others 1, units already slowed count half. With at least 4, it throws at the best spot.
One throw per think. `AI._great_winder_follow` leaves a Great Winder alone while it is throwing.
It was kept small and in its own function because another job is editing the Clockwork computer's army.

## Online, replays and saves

- The order goes through the spells' command funnel (`Game.cast_order`, already in `NetCommands.GAME`).
- The host runs the field (`Game.zones`, kind "scatter"). The guest's copy is looks only.
- Snapshots carry two new unit properties: `scatter_ready` (when the hopper is full again: the card's countdown) and
  `littered` (slowed now: the cogs round its feet). Replays record the same rows.
- The throw goes to the guest and into the replay as an effect row "k" (`NetSession.note_scatter`, played by `play_fx`).
  The pieces come from a random generator seeded by the spot, so every screen shows the same litter.
- A save keeps the hopper's countdown (the 4th value of the Great Winder's "gw" row). The litter on the ground is not
  saved, the same as fog, storms and miasma.

## The test

`godot --headless --fixed-fps 30 --script res://tools/test_cog_scatter.gd` checks:

- the order, the windup and the throw; 40 cogs paid; the 25 s countdown; 34 pieces fly;
- nobody is slowed while the pieces are in the air;
- an enemy Musketeer walking through the litter goes 0.60 of the pace of its twin walking outside (29.8 px against 49.6 px in 0.8 s);
- the twin outside, a balloon over the litter, and our own Clock Soldier in it are not slowed;
- still slowed near the end, nothing after 15 s, the looks gone;
- a second throw too soon is refused; with 39 cogs it is refused; out of range it rolls within 6 tiles, then throws;
- a save keeps the countdown;
- online: a guest's order runs on the host, the throw reaches the guest as an effect row, the guest gets the countdown and the slowed mark, the check lists match, replays carry it;
- the computer does not throw at a clump standing still, and throws ahead of 6 charging Raptors.

## The pictures

`docs/shots/cog_scatter/` (from `tools/shot_cog_scatter.gd`, the Clockwork Lab):

- `0_card_scatter_cogs.png`: the card with SCATTER COGS beside MEND and SWEEP.
- `1_windup_key_arm.png`: the windup.
- `2_throw_mid_air.png`, `2b_throw_coming_down.png`: the pieces in the air.
- `3_littered_field.png`: the litter.
- `4_littered_field_slowed_enemies.png`: enemy Musketeers walking through it (slowed) beside their twins outside.
- `5_close_litter_slowed_feet.png`: a close look, with the cogs round the slowed feet.
- `6_litter_fading.png`: the last second.

## Art: what is code, and the ChatGPT prompts

Everything is drawn in code for now (logged in `docs/art_style_inconsistency.md`). The cogs are the gear field's own idler
cog, baked small; the bolts, springs, nuts and plates are lines and polygons. The Great Winder has no throwing animation:
it plays its WIND strip during the windup.

Three separate requests. Each stands alone, with its own pictures to attach (at most 3).

### Prompt 1: the litter sprite sheet

Attach:
1. `docs/shots/cog_scatter/5_close_litter_slowed_feet.png` (the game's look and scale)
2. `art/redraws/great_winder_dirs_v2_chatgpt.png` (the Great Winder: the colours and metals to match)
3. `art/clockwork/gear/band_small.png` (the brass cog band of the gear field)

```
Pixel art sprite sheet for a 2D real-time strategy game seen from above at a 3/4 angle (the camera looks down at about 55 degrees), in the same painted pixel-art style, palette and lighting as the attached pictures (light from the top left). The first picture shows the game: the small brass cogs, bolts and springs lying in the circle are drawn in code and need to be replaced.

Draw LOOSE MACHINE PARTS LYING ON THE GROUND, thrown out of a clockwork machine's hopper: one piece per cell, on a fully transparent background, in a grid of 6 columns and 4 rows, each cell 32 x 32 pixels, each piece centred in its cell and lying flat on the ground (seen at the 3/4 angle, so round things are squashed ovals about half as tall as wide), with a small soft dark shadow under it.

Row 1: six brass cogs of different sizes (8 to 18 pixels across), 6 to 10 teeth, some with a hub hole, some with spokes, in the brass of the second picture.
Row 2: six steel parts: two hex bolts (one straight, one bent), two hex nuts, a washer, a short steel rod.
Row 3: six coil springs and clock parts: two coil springs (one stretched, one squashed), a clock hand, a small key, a ratchet pawl, a broken piece of a clock face.
Row 4: six small brass plates and scraps: a riveted plate, a bent strip, a cracked gear half, two small scraps, a tiny pile of three mixed parts.

Every piece small, readable at its size, with a dark outline and a bright highlight on its top-left edge (a glint). No text, no labels, no grid lines, no ground, no background colour.
```

### Prompt 2: the throw animation

Attach:
1. `art/redraws/great_winder_dirs_v2_chatgpt.png` (the Great Winder in its directions)
2. `assets/units/great_winder/wind_se.png` (its key-arm strip: the size and the frame layout)
3. `docs/shots/cog_scatter/2_throw_mid_air.png` (the throw in the game now)

```
Pixel art animation strip for a 2D real-time strategy game, the same machine, style, palette and size as the attached pictures. The machine is the GREAT WINDER: a big clockwork machine on four cog wheels, with a round open hopper on its back and a big wind-up key on top. It is seen from the SOUTH-EAST (as in the second picture), at the 3/4 angle from above.

Draw it THROWING A SHOWER OF COGS from its hopper, in 8 frames in one row, each frame the same size as the frames of the second picture (182 x 103 pixels), the machine standing in the same place in every frame (its wheels do not move), on a fully transparent background:
1-2: the key on top turns and the machine squats a little, winding up.
3: the hopper's lid springs open with a jolt.
4-5: a burst of small brass cogs, bolts and springs shoots up and forward out of the hopper (toward the bottom right of the frame), a little puff of grey dust.
6: the last few pieces leave the hopper; the machine rocks back.
7-8: the lid closes and the machine settles back to its standing pose.

Keep the machine exactly as drawn in the pictures (red and brass body, blue trim, the clock face). The flying pieces stay inside the frame. No text, no labels, no grid lines, no background.
```

### Prompt 3: the command icon

Attach:
1. `assets/icons/clockwork/ab_sweep.png` (the Clockwork command icons' frame and style)
2. `assets/icons/clockwork/ab_jump.png` (the yellow arc arrow style)
3. `assets/icons/clockwork/ab_scatter.png` (the stand-in icon to replace)

```
A square game command icon, 64 x 64 pixels, pixel art, in exactly the same style, frame and colours as the first two attached icons (a dark blue panel inside a bronze frame with dark corners). The third picture is a rough stand-in to replace: keep its idea, draw it properly.

The icon is SCATTER COGS: a big clockwork machine on cog wheels (red and brass, a round hopper on its back, a wind-up key on top) at the bottom left, flinging a spray of small brass cogs, a bolt and a spring out of its hopper along a yellow dotted arc (like the arc in the second icon) that lands on a small heap of cogs and bolts at the bottom right. Readable at 64 pixels: few, big shapes, dark outlines. No text, no letters.
```

When an answer comes back: the litter sheet replaces the code pieces in `CogScatter._piece` (a sprite per piece kind), the
throw strip becomes a "scatter" strip played during the windup and throw (`GreatWinder.anim`), and the icon replaces
`assets/icons/clockwork/ab_scatter.png`.

## What is left, and questions for the owner

- `slows_own`: should the Clockwork's own units be slowed in their own litter? (Now: no.)
- Should the litter slow flyers that land, or buildings' units walking out? (Now: flyers never.)
- Two fields on the same spot do not stack: the slow is one size, 40%.
- Not tried in a real match against a player: the computer's rule (4 units, charging melee or a running army) may throw
  too often or too late. The study scripts can measure it.
- The Great Winder has no throwing animation (prompt 2).
