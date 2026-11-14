# Veterancy chevrons (job vet-chevrons, 0.36.1)

The owner's decision (2026-11-14, 02:13-02:16): veterancy is shown by ONE CHEVRON over the unit, for every faction,
and the old hat-trim and skin colours go.

## What changed

- **The ranks** (`Defs.VET`): bronze from 15 kills, silver from 30, gold from 50 (`"bronze": 15, "silver": 30,
  "gold": 50`). No chevron under 15 kills. The damage bonus is unchanged and still fluid: +1% a kill, up to +50% at 50
  kills. A body's spoils still count every kill (`Game.corpse_value`). The chevron is only a label.
- **Who wears one:** every unit with 15+ kills: the Crown, the Clockwork, the Brood, guns, workers, flyers, balloons, the
  campaign's rebels. A balloon's passengers and a man being bandaged (off the field) show none while they are out of
  sight in the basket or the tent.
- **Where:** centred, just above where the unit's health bar is drawn (`Unit.bar_top`), whether the bar shows or not
  (the bar itself is unchanged: hidden while the unit is untouched). It follows a Springer's leap, a flyer's height, a
  mounted man and a big machine's taller bar. It also goes above a rooting Brood creature's reload bar, the acid strip
  and a campaign character's name, so it never covers them.
- **Size:** the same size on the screen at every zoom: 15 px wide at the usual zoom and closer, shrinking to 11 px when
  zoomed far out (so a zoomed-out army is not a carpet of chevrons). It is smoothly scaled from a 4x copy with
  mipmaps, so it stays crisp.
- **Bodies:** a fallen veteran's body shows the same chevron (colour by its kills), for everyone, just over the body.
  The spoils NUMBER stays, but only for a **Brood player** (the side that harvests bodies) and for those who watch
  (computer v computer games, spectators, replays). For a Brood player the chevron sits over the number.
- **Gone:** the Crown's silver/gold hat trim and the Brood's amber/obsidian skin. `VetLook` no longer recolours by
  kills. The Crown's trim mask still draws the hat lace / band / helmet edge BLACK, as every soldier's always was
  below 25 kills, so a recruit looks exactly as before. The venom line's colours (belly and flank stripe in the team
  colour) are untouched. The Brood skin masks (`assets/units/skin_masks/`, 2.5 MB) are deleted; `tools/import_vet_skin.py`
  stays because the venom importer uses its skin finder, but `tools/rebuild_art.sh` no longer runs it.
- **The unit card** names the rank: "Veteran (bronze): 17 kills, +17% damage", "Veteran (gold): 64 kills, +50% damage";
  under 15 kills: "3 kills, +3% damage". In Portuguese and Spanish too. The help line about veterancy is rewritten.
- **Art:** the owner's ChatGPT sheet (`art/ui/vet_chevrons_chatgpt.png`) was already in the repository, so the game
  uses it from the start: `tools/import_vet_chevrons.py` keys out the magenta, finds each chevron's pixel grid (15 x 11
  art pixels) and writes `assets/ui/vet_bronze.png`, `vet_silver.png`, `vet_gold.png`. A code-drawn chevron
  (`VetChevrons.chevron_image`) stays only as a stand-in if those files are ever missing (logged in
  `docs/art_style_inconsistency.md`). `rebuild_art.sh` runs the importer.

## How it works

`scripts/vet_chevrons.gd` (`Game.vet_layer`). Each veteran carries one small `Sprite2D` child named "VetChevron" (z 3,
absolute: over every unit and flyer, under the stun stars and the fog clouds). Because it is a child, the engine moves
it with the unit, hides it with the unit in the fog and fades it with a dying body: nothing is redrawn per frame. The
layer makes these sprites (the `kills` setter tells it at once; a scan every 0.25 s also finds units whose kills came
from a save, an online snapshot or a replay), and places a tenth of them each frame (each 6 times a second), Springers
in the air every frame, and all of them when the zoom changes. All three chevrons are one atlas texture, so a crowd of
mixed ranks draws in one batch.

Online and replays: kills were already in the snapshots (`NetSnapshot`), and the guest's and the replay viewer's
units are found by the same scan, so they show the chevrons. The number rule goes by the viewer: a Brood guest sees
the numbers, a Crown or Clockwork guest does not; a replay always does.

## Performance

`tools/stress_swarm.gd` has a new option `vets` (every man spawned with 15-64 kills). Melee, 200 v 200, all veterans,
rendered at 1600x900 on this cloud machine's software renderer (llvmpipe, a slow machine: 10 fps on that scene either
way):

| run | fps | draw calls | chevrons ms a frame |
| --- | --- | --- | --- |
| no veterans | 10.7 | 1,161 | 0 |
| 400 veterans, first try (one layer redrawn every frame) | 9.7 | 1,245 | 4.15 |
| 400 veterans, child sprites | 10.6 | 1,417 | 0.75 |
| 400 veterans, child sprites + one atlas (shipped) | 10.6 | 1,221 | 0.50 |

The 0.5 ms is the placing work on a machine where the units' own tick costs 7.6 ms a frame; on a normal computer it is
a few times less. The extra 60 draw calls are the chevrons' batches.

## Tests and pictures

- `tools/test_vet_chevrons.gd`: the thresholds (14/15/29/30/49/50), the card text, every faction's units (18 kinds, a
  rebel included), the place over the bar with and without the bar, a Springer's leap, the screen size at three zooms,
  the fog, no veterancy colours (the shader has no level any more) while the venom colours stay, a body's chevron and
  its place over the number, the number rule for a computers' game, a Crown, Clockwork and Brood player and a replay,
  save/load, an online guest (kills and chevrons through a snapshot, the guest's own number rule), 400 veterans.
  All pass. Also passing: test_unit_stats, test_i18n, test_files, test_orphan_imports, test_card_text, test_horses,
  test_brood_controls, test_egg_tooltips, test_brood_new (0 failures), test_content_all (0 FAIL, 10 WARN) and
  test_replay (ALL OK). (test_brood_new, test_content_all and test_replay end with exit code 134, an abort while
  Godot shuts down after the results are printed; it is not from this change's checks.)
- `tools/shot_vet_chevrons.gd` writes `docs/shots/vet_chevrons/`: a line of Musketeers with 0-63 kills close and at the
  usual zoom (1, 2), every faction (3), an army zoomed out and at zoom 1 (4, 5), a field of bodies as a Crown player
  (6: chevrons, no numbers) and as a Brood player (7: chevrons over the numbers). `import_contact.png` is the cut
  chevrons at 12x.

## Claude's choices (say if any is wrong)

1. **The Crown's hat trim stays black** rather than going back to the painted gold lace. Black is what every soldier
   showed under 25 kills, so a recruit looks the same as before, and painted gold lace on every man could be read as
   the old "gold veteran". Dropping the trim mask entirely (painted colours) is a one-line change in `VetLook.STYLES`.
2. **Size:** 15 px on screen at the usual zoom (about the width of a Musketeer's health bar's two thirds), shrinking
   to 11 px zoomed far out. It does not grow when zoomed in (it stays 15 px on screen).
3. **Bodies:** the chevron goes just over the lying body (over the spoils number for a Brood player), not at the
   standing unit's bar height.
4. **The number for watchers:** spectators, computer v computer games and replays see it, as asked; an online guest
   goes by his own faction.
5. **Order with other marks:** the chevron sits directly above the health bar (and above a rooted creature's reload
   bar, the acid strip, a named man's name). The stun stars draw over it while a unit is stunned. For the
   band-individuals job: its buff icons should go above the chevron or beside it (the chevron's top is about
   `bar_top - 1 - 2/zoom - 11/zoom`; `VetChevrons.bottom_of(u, gap)` gives its bottom).
6. **The skin masks were deleted** (no longer used); the trim and venom masks stay.

## Questions for the owner

- Should the chevron also show on the selection portraits (today they show a gold kill count in the corner)?
- Should a balloon's gunners show their chevrons in the basket?
