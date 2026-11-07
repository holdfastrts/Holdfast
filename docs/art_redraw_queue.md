# ChatGPT art redraw queue (Pocket RTS, v0.26.4, built 2026-11-03)

Scope: every picture in the game that is either **CODE-DRAWN** (drawn, composed, recoloured or animated in code on top
of or instead of painted art) or **FLAWED** ChatGPT art (hallucinations, wrong views, skating/shuffling gaits,
mismatched frames, wrong colours). Sources: docs/art_style_inconsistency.md (all sections, incl. "Still to prompt" and
"COULD BE BETTER"), docs/animation_audit_{crown,brood,clockwork,labourer}.md, docs/command_icons_audit.md (TO DRAW),
docs/animation_redraw_prompts_2.md, docs/winder_walk.md, docs/cog_scatter.md, docs/clock_soldier_west.md,
docs/clock_soldier_shield.md, docs/unit_stats.md, scripts/ui/hud.gd, scripts/ui/unit_stats.gd, scripts/card_tips.gd,
tools/rebuild_art.sh and the importers, and the CLAUDE.md backlog.

Order = how much the player sees it: always-on-screen UI and card icons first, then the most common units' most
frequent animations, then rarer units, buildings, effects, terrain. Already redrawn or obsolete items are listed at the
end so nobody re-does them.

Conventions in the tables: "cell" = one frame in game px (W x H); "strip" = the asset file, frames side by side.
West views are the east ones mirrored by the game unless noted (the Clock Soldier has its own west strips).

---

## 0. Before any request: rules and the reference images

- Owner's rules: every request stands alone (several ChatGPT accounts); at most 3 reference images per request; one
  request per view when a unit needs several views; download the PNG with ChatGPT's download button (no screenshots,
  no JPEG: the Mound Turtle's JPEG screenshots had to be median-keyed and stayed soft).
- Background: the prompts ask for a FLAT NAVY background, not transparency. Every importer here keys a flat colour
  (tools/redraw_lib.py keys anything within ~24 levels of RGB 0,22,48; tools/import_stat_icons.py keys the sheet's
  border colour). ChatGPT's "transparent" PNGs often come back with a painted grey checkerboard, which breaks the cut.
- Small game strips (assets/units/...) are 30-90 px tall; attach them ENLARGED (nearest neighbour, hard pixels, on
  navy). One-off helper for the main session (writes into the scratchpad, not the repo):

```
cd /home/claude/pocketrts && python3 - <<'EOF'
from PIL import Image; import os, sys
OUT = "/tmp/claude-0/-home-claude/3bf5c283-94b1-59fe-b83b-7f9d81ecfc35/scratchpad/refs"; os.makedirs(OUT, exist_ok=True)
def big(src, k=6):
    im = Image.open(src).convert("RGBA"); bg = Image.new("RGBA", im.size, (0, 22, 48, 255)); bg.alpha_composite(im)
    bg.resize((im.width * k, im.height * k), Image.NEAREST).convert("RGB").save(os.path.join(OUT, src.replace("/", "__")))
for d in ["s", "se", "e", "ne", "n"]:
    big(f"assets/units/labourer/walk_{d}.png"); big(f"assets/units/musketeer/walk_{d}.png")
big("assets/units/labourer/idle_s.png"); big("assets/units/labourer/idle_se.png")
EOF
```
  (Prompts below say "attach X enlarged" for these; the enlarged file is refs/assets__units__<unit>__<strip>.png.)

---

## 1. Summary table: the whole queue in priority order

Reason: CODE = code-drawn / code-built / code-recoloured; FLAWED = ChatGPT art with a defect (named).
Prompt column: "NEW" = written in section 2 of this file; otherwise the doc and section that already has one.

### Tier A: on screen all game (HUD, unit card, icons)

| # | item | faction | reason | in game (asset / code) | size / layout the importer expects | import step | prompt |
|---|---|---|---|---|---|---|---|
| 1 | DONE 0.26.8 (docs/shots/res_icons/) **Resource icons**: top-bar pills (gold, powder, horses; Brood food + spoils; Clockwork cogs) and unit-card resource chips (soil, saltpetre, brass) | all | CODE: plain coloured dots/box (Hud._pill, hud.gd ~l.4680; card_tips.gd FOOD/SOIL/SALT/BRASS dots); COGS is GearNet.draw_gear in code. Only TENSION (assets/icons/tension.png) is painted | none yet: new files assets/ui/stats/res_<name>.png (64x64) | a sheet of framed square icons on flat navy; importer finds icons by blobs, any grid; frames cut away (INSET 0.14), 64x64 out, drawn at 18-24 px | add each sheet to EXTRA in tools/import_stat_icons.py; then small code hook: Hud._pill already takes `pic` (pass UnitStats.texture("res_gold") etc.), CardTips chips take `pic` instead of `dot`; supply pill can reuse existing assets/ui/stats/supply.png (no drawing needed) | **NEW: 1A, 1B** |
| 2 | DONE 0.26.8 (docs/shots/res_icons/) **Pistol mark** on the Officer / Horseman / Cuirassier card (loaded / empty) | Crown | CODE: Hud._draw_pistol (hud.gd l.4129): rectangles and a polygon, red bar when empty (the owner noticed it) | none yet: assets/ui/stats/pistol_loaded.png, pistol_empty.png | 2 framed icons on navy, same importer | EXTRA in tools/import_stat_icons.py; code: _draw_pistol draws UnitStats.texture(...) when present (keep the code drawing as fallback) | **NEW: 2** |
| 3 | Code/PIL-made command icons: Marching Band portrait + DRUMS/PIPES/FIFE buttons; GEAR VIEW; SCATTER COGS; COUPLE/UNCOUPLE (LAB only) | Crown, Clockwork | CODE: tools/make_band_icons.py (PIL flat shapes); CwArt._ability_glyph "ab_gear_view"; tools/make_cog_scatter_icon.py (PIL composite) | assets/icons/band.png, ab_band_drums/pipes/fife.png; assets/icons/clockwork/ab_gear_view.png (missing: code glyph shown); assets/icons/clockwork/ab_scatter.png | 64x64. Crown: steel bevel style sheet (3x2 on 1536x1024); Clockwork: bronze frame sheet. See command_icons_audit.md "The format of a new sheet" | tools/import_round13.py-style cut (add a sheet entry), files win over code by themselves | band: none (art_style_inconsistency.md "The Marching Band", ICONS bullet describes them); scatter: docs/cog_scatter.md "Prompt 3: the command icon"; gear view: none |
| 4 | Framed-crop buttons that are not painted as buttons: Clockwork MEND, SWEEP, CREW/BOARD | Clockwork | CODE: painted parts / a Winder sprite set in the bronze frame by importers | assets/icons/clockwork/ab_mend.png, ab_sweep.png, ab_crew.png | 64x64 bronze style | import_great_winder.py / import_ballista.py write them; a round13-style sheet would replace | none (art_style_inconsistency.md "The Great Winder in the game", MEND/SWEEP bullet; "Spring Ballista", portrait bullet) |
| 5 | Stats row: named bonuses ("x2 against Raptor") borrow the vs-armoured icon | all | CODE (borrowed picture) | assets/ui/stats/vs_armoured.png reused | 1 framed icon | EXTRA in import_stat_icons.py + code to pick it | none (docs/unit_stats.md "The icons") |
| 6 | Portrait flaws: Hatchling and Storm Challenger portraits drew an EXTRA WING (PAINTED OUT IN CODE 0.26.10, tools/fix_third_wing.py; a redraw would fill the empty bottom left: docs/third_wing.md prompts C1, C2); Brood Mother stage 2 and 3 portraits too alike | Brood | FLAWED: no visual step between stages (wing: code-fixed) | assets/icons/hatchlings.png, storm_challenger.png, brood_mother_2/3 portraits (from art/redraws/*_portrait_chatgpt.png) | portrait sheet as the owner's other Brood portraits | tools/import_brood_new.py portrait / import_storm_line.py | none (art_style_inconsistency.md "COULD BE BETTER" bullets 1 and 4) |
| 7 | Language flags (US, Brazil, Spain) on the main menu and Settings | menu | CODE: scripts/ui/flags.gd FlagIcon, vector shapes | no file | small flag icons, pixel style | needs a loader in flags.gd | none (art_style_inconsistency.md section B, "Language flags") |

### Tier B: the most common units' most frequent animations

| # | item | faction | reason | in game | cell / frames | import step | prompt |
|---|---|---|---|---|---|---|---|
| 8 | ~~Labourer walk S and SE~~ **DONE 0.26.15** | Crown | DONE 2026-11-03: the owner's ChatGPT v4 sheets (art/redraws/labourer_walk_{s,se}_v4.png) imported by tools/import_labourer_v2.py (V3 s/se; the S sheet came on a transparent background whose RGB holds a red glow: keyed by alpha, the cut runs inside the dark outline, no halo left). Repairs in code: S frames 4-6 have their own legs mirrored (ChatGPT lifted the same leg in both halves: a limp); SE frame 6 (tangled back leg, stacked boots) has frame 3's legs under its body. tools/import_labourer_stride.py retired. Carry, carry_keg, walk_shovel and the Musketeer / Guardsman s/se walks rebuilt on the new legs. Pictures: docs/shots/labourer_walk_v4/ (before_after_6x.png, game shots; tools/shot_labourer_walk.gd) | assets/units/labourer/walk_s.png, walk_se.png | cell 42x35, 6 frames | done | (left, optional: a SE sheet whose frame 6 is drawn right, and an S sheet that steps on alternate feet, to drop the two code repairs) |
| 9 | ~~Musketeer walk, all five views~~ **DONE 0.33.7** (the owner's ChatGPT sheets art/redraws/musketeer_walk_<d>_chatgpt.png, tools/import_musket_walk.py: 6 frames every view; the east and north-east sheets' second barrel behind the head erased in code, the north back of the head given hair and a ribbon in code; docs/shots/musket_walk/) | Crown | CODE + FLAWED: legs are the labourer's ChatGPT legs pasted in code (import_crown_legs.py, silver-grey recolour, mixed boot style); frame counts 3/4/6/5/7 (S/SE/E/NE/N) so turning jumps the phase and the S walk is a 0.25 s shuffle (Crown audit finding 10). A whole-sheet ChatGPT walk (art/redraws/musketeer_walk.png) was dropped: it lost the tricorne and the musket in his hands | assets/units/musketeer/walk_{s,se,e,ne,n}.png | cell 90x36, anchor (45,35), hat-to-soles 30 px; 6 frames each wanted (strips 540x36) | new tools/import_musket_walk_dirs.py modelled on tools/import_musket_aim_dirs.py (one row per view, 6 tallest pieces = the men, redraw_lib.to_cell, write_counts walk 6); remove "musketeer" from TARGETS in tools/import_crown_legs.py; then tools/import_vet_trim.py --only musketeer | **NEW: 4S, 4SE, 4E, 4NE, 4N** (older all-views text: animation_audit_crown.md "Prompt A") |
| 10 | **Clock Soldier walk, all eight views** | Clockwork | FLAWED + CODE: it SKATES (feet move 1-3 px a step, it covers 41 px a cycle: Clockwork audit finding 3); S/SE legs bent in code (walk_code.py), E/NE/N legs from the cut-out parts rig (rig.py), the three west walks code-built from the west idle (soldier_guide/west.py) | assets/units/clock_soldier/walk_{s,se,e,ne,n,sw,w,nw}.png | cell 78x66, 6 frames (strip 468x66); S idle 42 px tall; importer recolours (cw_palette: red body -> brass, blue -> brass, cap -> team colour) | today SHEETS["walk"] = art/redraws/clock_soldier_walk_mix.png (5 rows x 6), WEST_SHEETS["walk"] = clock_soldier_walk_west.png (3 rows SW W NW). Either stack the per-view answers into those two layouts (rows top to bottom) or add a per-view loader to tools/import_clock_soldier.py; then tools/anim_audit/fix_clockwork.py; retune WALK_FPS_ART (scripts/unit.gd) to the new stride | **NEW: 5S..5NW** (older all-rows text: animation_audit_clockwork.md "Prompt B") |
| 11 | **Raptor walk S, SE, NE, N** | Brood | CODE: legs rebuilt per frame in code (tools/import_gait_raptor.py, stick legs, small stride); E is a real painted run | assets/units/raptor/walk_{s,se,ne,n}.png | cell 58x30, anchor (29,28), 6 frames (strip 348x30) | per-view loader (copy the raptor part of tools/import_redraw_creatures.py, or stack the rows into a 5-row sheet for it); remove tools/import_gait_raptor.py from rebuild_art.sh; tools/anim_audit/fix_brood.py re-anchors | **NEW: 6S, 6SE, 6NE, 6N** (older all-views text: animation_redraw_prompts_2.md "18. Raptor walk") |
| 12 | Guardsman (armoured Musketeer) walk, all five views | Crown | CODE + FLAWED: as item 9 (labourer legs pasted, 3/4/6/5/7 frames) | assets/units/musketeer_armoured/walk_*.png | cell 90x36, 6 frames each | as item 9 for unit musketeer_armoured | animation_redraw_prompts_2.md "16. Guardsman walk" (all views in one sheet: re-split it per view like prompts 4x) |
| 13 | Labourer carry (gold sack) and carry_keg walks | Crown | CODE: the new walk legs pasted under the carry bodies (import_labourer_carry_legs.py); s/se inherit item 8's squeezed legs | assets/units/labourer/carry_*.png, carry_keg_*.png | cell 42x35, 6 frames | new rows into import_labourer_v2-style loader | animation_redraw_prompts_2.md "8. Labourer walking with a gold sack" and "9. ... powder keg" (same technique as prompts 31-34: one row per view) |
| 14 | Labourer farm hoe (the farm work loop, `mine_*`) | Crown | CODE: the hoe, its arc and the soil clods drawn on the ChatGPT pick bodies (tools/import_labourer_hoe.py); flaws: E frame 0/3 tool from the hip, flat plate, crouch coat flap | assets/units/labourer/mine_{s,se,e,ne,n}.png | cell 42x35, 4 frames (strike = frame 2) | a ChatGPT candidate exists, NOT installed: art/redraws/labourer_hoe_v2.png (tools/import_labourer_v2.py cand_frames writes /tmp/cand_hoe.png): look at it first | animation_redraw_prompts_2.md "5. Labourer farm hoe swing" (refs docs/redraw_refs/05_labourer_hoe/) |
| 15 | Winder: the crank in WIND / REPAIR, and WALK_WIND | Clockwork | CODE: a 4x4 code crank drawn on every frame (CRANK in tools/import_winder_v2.py; his painted arms are stiff); walk_wind = wind top over walk legs (tools/winder_guide/walk_wind.py) | assets/units/winder/wind_*.png, repair_*.png, walk_wind_*.png | cell 76x49, 4 frames | import_winder_v2.py (wind_v2 sheet); walk_wind per view | walk_wind: docs/winder_walk.md "ChatGPT redraw prompt (one view per request)". Wind crank: none (art_style_inconsistency.md "The new Winder in the game", CODE-DRAWN bullet) |
| 16 | Clock Soldier: E idle shield "on its back"; E attack frame 3 headless; west ATTACK and DEATH code-built (west deaths 20-30% bigger, nothing comes loose) | Clockwork | FLAWED + CODE | assets/units/clock_soldier/idle_e, attack_e, attack_{sw,w,nw}, death_{sw,w,nw} | cell 78x66; idle 4, attack 6, death 7 | tools/import_clock_soldier.py SHEETS / WEST_SHEETS | docs/clock_soldier_west.md "1. West attack clean-up", "2. West death clean-up", "3. E idle repaint"; animation_audit_clockwork.md "Prompt C" |
| 17 | Clock Soldier SHIELD FORWARD stance (guard, guard_walk), 8 views | Clockwork | CODE: shield cut from the W idle and pasted, arm wiped and smeared (tools/soldier_guide/shield.py) | assets/units/clock_soldier/guard_*.png (4 fr), guard_walk_*.png (6 fr) | cell 78x66 | import_clock_soldier.py | docs/clock_soldier_shield.md "ChatGPT requests" 1-4 |
| 18 | Grub: the cocoon grub is a different animal (upright lime frog-like creature) in wrap / carry_cocoon / idle_cocoon / death_cocoon; up/down walks barely move | Brood | FLAWED (Brood audit finding 1; owner wants reptilian) | assets/units/grub/wrap_*, carry_cocoon_*, idle_cocoon_*, death_cocoon_*, walk_* | cell 42x29 (strips 34 tall) | import_redraw_creatures.py / fix_brood.py | animation_audit_brood.md "B1. Grub carrying a cocoon", "B2. Grub wrapping a body"; animation_redraw_prompts_2.md "19. Grub worker walk" |
| 19 | Raptor attack, leap and death exist in the EAST view only | Brood | FLAWED: missing views (it bites sideways when facing S/N) | assets/units/raptor/attack_e (5 fr), leap_e, death_e | cell 58x30 | new rows, same loader as item 11 | none |
| 20 | Jack: DEATH and ATTACK UP still show the old CLAW arm (swaps launcher/claw every action); HOP, JUMP and the two-launcher ATTACK are code-built from the painted idle; Netter-style muzzle burst separate | Clockwork | FLAWED + CODE (Clockwork audit finding 1) | assets/units/springer/death_* (7 fr), attack_up_* (6), walk_* = hop (6), jump_* (8), attack_r/l_* (6) | cell 108x80 | tools/import_springer.py | animation_audit_clockwork.md "Prompt A" (to repeat on jack_death_final.png and jack_attack_up_body.png) |
| 21 | Labourer shovel at the Powder Mill and walking with a loaded shovel | Crown | CODE: shovel and loads drawn on the hoe bodies; walk_shovel = shovel lift body on walk legs | assets/units/labourer/shovel_* (3 loads x 4 = 12 fr), walk_shovel_* (3 x 6 = 18 fr) | cell 42x35 | import_labourer_shovel.py, import_labourer_shovel_walk.py | none (art_style_inconsistency.md section B rows 2-3) |
| 22 | Labourer bury, north row | Crown | CODE: crouch + soil pile repaired in code (sheet repeated the standing back view) | assets/units/labourer/bury_n.png | cell 42x35, 6 fr | import_labourer_v2.py REPAIRS | none (section B row 4; prompt 03 set 2 was the source sheet) |
| 23 | Light Officer (Horseman on foot): idle, aim, fire, death are the OLD narrow man; aim 1 frame; death the same east picture in every view | Crown | FLAWED (Crown audit finding 3; the Armoured Officer is fixed since 0.15.22) | assets/units/dismounted/idle_* (2), aim_* (1), fire_* (2), death_* (5) | cell 90x36 | model on tools/import_cuirassier_dismounted.py (two sheets per view, BODY_H) | animation_redraw_prompts_2.md "10. Officer idle, aim and fire", "11. Officer death"; art_style_inconsistency.md "Prompt OW-3" for the white coat |
| 24 | Officers and riders WHITE COAT, team breeches, sash, plume, saddle cloth recoloured in code | Crown | CODE (colours code-picked: flat whites, ragged saddle cloth, leftover red sleeves) | horseman/*, cuirassier/*, dismounted/* (+ portraits), mount strips | as today | retire tools/recolour_officers.py | art_style_inconsistency.md "Prompt OW-1" (Horseman), "OW-2" (Cuirassier), "OW-3" (Officer); OW-4 is done |
| 25 | Missionary: walk legs code-built; idle 3 px taller than walk, E idle 1 frame; death starts on the ground, no N death, SE death jumbled | Crown | CODE + FLAWED | assets/units/missionary/walk_* (4 fr; s 3), idle_*, death_* | cell 48x40 | import_gait_missionary.py to retire | animation_audit_crown.md "Prompt F" (idle, death); walk: none (section C "Still to prompt") |
| 26 | Horseman / Cuirassier blow in passing: code sabre arc over the gallop; no pistol-at-gallop strip | Crown | CODE (RideBy.Slash) | scripts/ride_by.gd | 6-8 fr per facing, cell 98x70 | new strips | none (art_style_inconsistency.md "The Horseman's and Cuirassier's blow in passing") |

### Tier C: less common units

| # | item | faction | reason | in game | cell / frames | import | prompt |
|---|---|---|---|---|---|---|---|
| 27 | Cavalry views: Armoured Dragoon has ONE view (same gallop everywhere, N faces camera); Dragoon trots in place, S is a 3/4 view, idle rider bigger than walking; Cuirassier NE walk is its back view; Messenger E gallop | Crown | FLAWED (Crown audit findings 2, 5, 6) | dragoon_armoured/walk_* (10 fr), dragoon/*, cuirassier/walk_ne, messenger/walk_e | cell 98x70 | import_redraw_mounted.py | animation_audit_crown.md "Prompt D"; prompts_2 "20", "21", "23", "24" |
| 28 | Riderless horse: death starts lying, graze SE = S | Crown | FLAWED | horse/death_* (3 fr), graze_se | 98x70 | import_horse_units.py | Crown audit "Prompt C"; prompts_2 "25" |
| 29 | Field Cannon walk SE/E/NE = one side view, loader jumps, a horse in a deployed gun's death; Powder Wagon NE = E; Mortar crew | Crown | FLAWED (findings 5, 9) | cannon/*, powder_wagon/*, mortar/* | 165x129, 60x80, 158x91 | import_cannon2 / import_round6 / import_mortar_walk | Crown audit "Prompt G" |
| 30 | Observation Balloon death hangs in air, then lies down | Crown | FLAWED | balloon/death_* | 184x224 | import_balloon.py | Crown audit "Prompt C" (balloon part) |
| 31 | Spitter E walk has no real gait (owner 2026-10-30); E/NE shuffle | Brood | FLAWED | spitter/walk_e (6 fr), walk_ne | cell 74x65 | tools/import_spitter_redo.py | none (art_style_inconsistency.md "TO REDRAW" owner 19:33) |
| 32 | Storm line EXTRA WINGS: SURVEYED AND ERASED IN CODE in 0.26.10 (docs/third_wing.md: 8 frames, tools/fix_third_wing.py; still wanted: the Hatchling and Challenger SE downstroke with both wings down, prompts A, B); N fly shows beak at bottom; N swoop flipped; NE swoop rebuilt from 3 frames | Brood | FLAWED: wings code-fixed; the rest as before | hatchlings/*, storm_challenger/*, pterodactyl/* | 50x34, 120x89, 210x219 | tools/import_storm_line.py, import_brood_fathers.py | none (art_style_inconsistency.md "TO REDRAW" owner 19:46; docs/storm_line.md) |
| 33 | Brood Mother: rearing-up laying frames show TWO TAILS; stage 2 S drawn as SE; stage 3 sheets bulky, N slam frame dropped | Brood | FLAWED | brood_mother*/nest/lay strips, walk/swipe S, N | 528x373 etc. | tools/import_brood_mature.py, import_brood_new.py | none (art_style_inconsistency.md "TO REDRAW" owner 19:13; "COULD BE BETTER") |
| 34 | Tyrant Challenger weak SE run and N; Venom Challenger stiff NE walk | Brood | FLAWED | tyrant_challenger/*, venom_challenger/walk_ne | 88x64, 90x82 | import_brood_mature.py | none ("COULD BE BETTER" double-check list) |
| 35 | Brute: walk/attack/death east only (slides sideways up/down); 3 idle frames = 3 bodies; attack frame 5 leaps 25 px, head cut | Brood | FLAWED (Brood audit findings 2, 8) | brute/walk_e, attack_e, death_e, idle_* | cell 120x67 | import_redraw_creatures-style | animation_audit_brood.md "B3. Brute walk", "B4. Brute idle and attack" |
| 36 | Mist Toad: tongue, fog and death east only | Brood | FLAWED | mist_toad/tongue_e, fog_e, death_e | 100x82 | import_mist_toad.py | none (walk is fixed by import_toad_hop.py) |
| 37 | Mound Turtle S, NE, N walks from JPEG screenshots (soft), N squashed to 78% in code | Brood | FLAWED | mound_turtle/* | 94x65 | import_brood_new.py | none (art_style_inconsistency.md "The new Brood", MOUND TURTLE bullet: ask for PNG redraws of those three) |
| 38 | Pendulum idle sway, walk, both attack sweeps: all code-built (rotated paint, telescoping knees, code steel smear) | Clockwork | CODE | pendulum/idle_* (4), walk_* (8), attack_r/l_* (6) | cell 130x91 | tools/import_tier3.py | none (art_style_inconsistency.md "Pendulum v2" sections: "a ChatGPT pass on the swung-back and sweeping poses") |
| 39 | Netter: idle = walk frame held (dead still); walk trot and fire recoil code-built; recoil 2-3 px | Clockwork | CODE + FLAWED (audit finding 9) | netter/idle_* (1), walk_* (8), attack_* (6) | cell 84x58 | tools/import_tier3.py | none |
| 40 | Great Winder on wheels: every wheel code (catapult cog), idle and death made in code, no painting of it on wheels | Clockwork | CODE | great_winder/walk_* (12), idle_* (2), death_* (5), wind, sweep | cell 182x103 | tools/import_great_winder.py | none (docs/great_winder.md "The art") |
| 41 | Spring Ballista: idle/walk/attack are single frames (no motion); death same 4 SE frames in every view; crew step bob code | Clockwork | CODE + FLAWED | ballista/* | cell 176x96 | tools/import_ballista.py | none |
| 42 | Swift -> Owl MORPH: code shiver, clock hand and bar | Clockwork | CODE | scripts/cw_air.gd | strip | import_cuckoo.py | none ("Wanted: a painted rebuild") |
| 43 | Marching Band: the owner's SE march for the Drummer, Fifer (option B) and Piper is in (0.33.0); the SE strips stand in for EVERY other view (S, E, NE, N; the west ones mirrored); idle = the walk slowed, death = code-tipped frames | Crown | ChatGPT (SE only) + CODE (other views, death) | assets/units/band, band_fifer, band_piper (walk_se, idle_se, death_se; cell 44x46, soles row 43) | per musician: walk S, E, NE, N (4 frames each, marching and playing, the same man as his SE sheet); later a death row | tools/import_band.py: add each sheet to SHEETS by view (it cuts one row of 4 on navy #001630, ~9 sheet px a game px, hat to soles 34 px) | one direction per request over the SE sheet as the reference (art/redraws/band_<who>_walk_se_chatgpt.png; the Fifer: band_fifer_walk_se_b_chatgpt.png) |
| 44 | Clockwork palette recolour in code (Clock Soldier, Jack, Swift, Owl, Pendulum, Netter: blue joints -> brass/team) | Clockwork | CODE (colour only) | all those strips | as today | tools/cw_palette.py (retire per unit when repainted brass + pure red) | none (rule: "a ChatGPT repaint in these colours would retire each line") |

### Tier D: buildings

| # | item | faction | reason | in game | size | import | prompt |
|---|---|---|---|---|---|---|---|
| 45 | Cog Press: 12 working frames (ram moved in code), construction, damaged, destroyed all code-made | Clockwork | CODE (the Clockwork's income building, on screen all game; owner wants turning parts perfect) | assets/buildings/cog_press_{work_0..11,construction,damaged,destroyed}.png | 108x164 | tools/import_cog_press.py | none for the new gantry press (art_style_inconsistency.md "Cog Press working animation": wanted construction/damaged/destroyed in the same style, navy, same angle). NOTE: animation_audit_clockwork.md "Prompt D" is OBSOLETE (old flywheel press) |
| 46 | Mainspring work: gauge needle + steam puff code; frames 7-8 shake the whole building incl. base | Clockwork | CODE + FLAWED | mainspring_work_* | 121x145 | tools/gear_art/import_buildings.py | none |
| 47 | Escapement: wheel rebuilt from painted pieces, anchor rocked in code | Clockwork | CODE (owner: "suboptimal") | escapement_work_0..23 | 116x139 | press_anim/escapement_work.py | none (wanted: building without wheel/anchor + wheel 12 even teeth / 8 spokes + anchor, separately on navy) |
| 48 | Regulator pendulum swung in code; Movement Works key turned + bodies moved in code; Heavy Works key turned in code, machine-in-bay darkening + hot seam | Clockwork | CODE | regulator_work_*, movement_works_*, heavy_works_work_*, scripts/heavy_works.gd | 95x113, -, 120x135 | gear_art/import_buildings.py | none |
| 49 | Gear field: ring EDGE and idler cog HUB flat code colour; brass floor plate made in code; SPRING MARK; COGS icon (item 1) | Clockwork | CODE | scripts/gear_art.gd, assets/gear/floor_plate_brass.png | tiles | gear_art/unwrap_rings.py, make_brass_plate.py | none |
| 50 | Clockwork crate unfold: one sheet scaled for every building; construction = hard clip of the scaffold sprite | Clockwork | CODE | assets/effects/crate_unfold_<kind>.png (648x124 = 6 fr), Building._rise | per building | tools/import_crate.py | none |
| 51 | Armoury experiments: roof patch boils (100-300 px change per frame), yellow specks, dummy target colour | Crown | FLAWED (CLAUDE.md backlog; Crown audit "Armoury: the experiments": a fixed patch in import_armoury_anims.py is a code fix, not a redraw) | assets/buildings/armoury_anim_*.png | 6 fr each | tools/import_armoury_anims.py | none |
| 52 | Crown buildings: terracotta roofs and flat team-red cloth recoloured in code; Farm windmill cap | Crown | CODE (colour) | town_hall, barracks, foundry, church, powder_mill, armoury, farm + portraits | as today | tools/recolour_crown_buildings.py, import_windmill.py tile_cap | none ("Wanted: a ChatGPT repaint of the Crown buildings with terracotta roofs") |
| 53 | Diagonal palisade: damaged, construction, destroyed made in code | Crown | CODE | palisade diagonal pieces | 6x35 stakes | tools/import_palisade_diag.py | none |

### Tier E: effects, terrain, rare

| # | item | reason | where | prompt |
|---|---|---|---|---|
| 54 | Black powder smoke: the muzzle smoke puff scaled 2-5x with linear filtering | CODE | scripts/powder_smoke.gd, assets/effects/smoke.png | none |
| 55 | Scatter Cogs litter, throw (no Great Winder throw anim), slowed-mark cogs | CODE | scripts/cog_scatter.gd | docs/cog_scatter.md "Prompt 1: the litter sprite sheet", "Prompt 2: the throw animation" |
| 56 | Torn-up body puff (dust tinted brown) | CODE | Game.torn_fx | none |
| 57 | Stun stars | CODE | scripts/stun_mark.gd (drop assets/ui/stun_stars.png in: no code change) | none (docs/stun_mark.md) |
| 58 | Brood: sire lure growing (one concept recoloured), ripe pulse, killed-lure squash, Storm Sire fly-in glide; moult shell (cocoon recoloured), young hunch; cocoon fade compromises; egg tint | CODE | scripts/brood_root.gd, moult_look.gd | none (art_style_inconsistency.md "The Sire lures", "Young and mature") |
| 59 | Turning gears dust and chevrons; reins line and the held "take the reins" frame | CODE | GearNet._draw_turning, Unit._draw_rein | none |
| 60 | Owl bomb ground shadow, net drop/shiver, flyer in a net, Jack jump shadow | CODE | cw_air.gd, effects | none |
| 61 | Ramp kerbs/shadows/rails, east and west cliff walls | CODE (terrain) | Game._paint_ramps, scripts/ramp_rails.gd, scripts/cliff_art.gd | none (wanted: per-biome ramp tile set, kerb piece, cliff side pieces) |
| 62 | Clutch-Mound-style "Queen still sprite" backlog line | see "obsolete" below | | |

UI marks that can stay code-drawn (not queued): area marks, expansion spots, gear view wash, turret circles, the JUMP
target, the Great Winder winding ring, attack-ground lines, meshing-teeth arcs, research bars, egg counts, health bars.

### Already done or obsolete (do NOT redo)

- Brood DEMOLISH redrawn (art/ui/icons3/brood_demolish_2.png, round 13). SPIT icon: the Bloater is gone (old Brood removed 0.18.0); brood_spit_2.png exists but the button is obsolete.
- BOMBARD x3, TEAM, MORE, RESTOCK, AUTO REFIT, Clockwork BACK/CANCEL/HOLD/..., Clock Soldier/Jack/Swift/Owl/Pendulum/Netter/Catapult portraits: drawn (rounds 13/14). Shield icons ab_shield / research_shield now exist as painted files.
- Stats-row icons: all 16 painted (assets/ui/stats/); the draw_icon shapes are only a fallback.
- Items 1 and 2 (0.26.8): the resource icons (res_gold, res_powder, res_horses, res_soil, res_saltpetre, res_food, res_spoils, res_cogs, res_brass) and the pistol mark (pistol_loaded, pistol_empty) are painted, cut by tools/import_stat_icons.py (EXTRA) into assets/ui/stats/ and wired into the top bar pills, the card chips and Hud._draw_pistol. Costs on buttons and tooltips are text only (no dots), so nothing else changed.
- Winder walk legs (retired 2026-10-26), labourer walk E/NE/N (ChatGPT v3), the dismounted Cuirassier (0.15.21/22), Musketeer and Guardsman aim/fire/bayonet directions (0.14.63-0.14.69), Clock Aviary boil (fixed).
- Obsolete with the old Brood (0.18.0): Clutch Mound states, the Queen (her "still sprite" backlog line is stale: the Brood Mother has full animations), Spore Mother, Bloater, Skywing prompts B7-B12 of the Brood audit.
- Off in normal games: Windup Soldier walk (old roster), the LAB prototype roster and its code icons (CwArt), the Clockwork Line art and trains.
- Officer code poses (branch wt-officer-pose) were never merged: nothing in game.

---

## 2. Ready-to-paste prompts for the first six items

Each block below is ONE complete request: attach the listed images (in order), paste the block, download the PNG.

### Item 1: resource icons (DONE 0.26.8)

#### Request 1A: Crown resource icons (5 icons)

Attach:
1. `art/redraws/stat_icons_chatgpt.png` (the game's stat icons: the style and frame to match)
2. `art/redraws/stat_icons_light_dps_chatgpt.png` (two more icons of the same set)

Save as `art/redraws/res_icons_crown_chatgpt.png`. Import: add `("art/redraws/res_icons_crown_chatgpt.png", ["res_gold", "res_powder", "res_horses", "res_soil", "res_saltpetre"])` to EXTRA in tools/import_stat_icons.py, run `python3 tools/import_stat_icons.py --contact docs/shots/unit_stats/icons_contact.png`.

```
The two attached images are icon sheets from my pixel-art RTS game (a 17th-century gunpowder setting): small square icons, each inside a thin brass frame with round rivets at the corners, on a flat dark navy background. Draw FIVE NEW ICONS in exactly the same style, frame, size and lighting (light from the upper left), for the resource counters of the game's top bar:

1. GOLD: a small stack of gold coins with one coin standing on its edge, warm yellow gold with darker gold shading.
2. GUNPOWDER: a small wooden powder keg on its side with a little heap of black powder spilling from its open bung.
3. HORSES: a brown horse's head and neck in profile facing right, with a leather bridle.
4. SOIL: a clod of dark brown tilled earth with a small green sprout on top (the farmland's reserve).
5. SALTPETRE: a small heap of white-grey crystals with a few sharp facets catching the light.

Each icon must read clearly when shown very small (about 20 pixels): one bold subject, a strong dark outline, few details, no text, letters or numbers.

Layout: a landscape image 1536 x 1024 pixels. Background: ONE flat even dark navy colour everywhere (about RGB 18, 30, 48, like the attached sheets), no texture, no vignette, no shadows, no labels. Two rows of icons: icons 1, 2, 3 in the top row, icons 4 and 5 in the bottom row, left to right. Every icon the same square size (about 260 x 260 pixels including its brass frame), at least 80 pixels of empty navy between frames and around the edge, frames never touching, the whole picture inside its frame.

Style: hard square pixels, no anti-aliasing, no blur, no glow, no gradients beyond two or three painted tones per colour, exactly like the attached icons. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 1B: Brood and Clockwork resource icons (4 icons)

Attach:
1. `art/redraws/stat_icons_chatgpt.png` (the style and frame)
2. `art/redraws/food_pile_chatgpt.png` (the Brood's food pile: what Brood FOOD looks like)
3. `assets/icons/tension.png` (the Clockwork's painted Tension icon: the brass look of that faction)

Save as `art/redraws/res_icons_brood_clockwork_chatgpt.png`. Import: EXTRA entry `["res_food", "res_spoils", "res_cogs", "res_brass"]`, same command as 1A.

```
The first attached image is an icon sheet from my pixel-art RTS game: small square icons, each inside a thin brass frame with round corner rivets, on a flat dark navy background. The second image shows the food pile of my reptile faction (the Brood); the third is the painted resource icon of my clockwork faction (brass and steel machines). Draw FOUR NEW ICONS in exactly the style, frame, size and lighting (light from the upper left) of the first image:

1. FOOD (reptile faction): a small heap of raw red meat and green leafy swamp plants, like the food pile in image 2, shrunk to one simple lump.
2. SPOILS (reptile faction, gathered from the bodies of the dead): a small bundle of bones, a curved claw and a few green scales tied with dark sinew. Reptilian, not insect.
3. COGS (clockwork faction): three small brass cog wheels lying in a heap, the top one seen almost face-on with a dark hub.
4. BRASS (clockwork faction): two stacked brass ingots with a bright edge highlight.

Each icon must read clearly when shown very small (about 20 pixels): one bold subject, a strong dark outline, few details, no text, letters or numbers.

Layout: a landscape image 1536 x 1024 pixels. Background: ONE flat even dark navy colour everywhere (about RGB 18, 30, 48, like the first image), no texture, no vignette, no shadows, no labels. Two rows of two icons: 1 and 2 on top, 3 and 4 below, left to right. Every icon the same square size (about 260 x 260 pixels including its brass frame), at least 80 pixels of empty navy between frames and around the edge, frames never touching, the whole picture inside its frame.

Style: hard square pixels, no anti-aliasing, no blur, no glow, two or three painted tones per colour, exactly like the first image. Deliver a PNG file (not a JPEG, not a screenshot).
```

### Item 2: the pistol mark on the unit card (DONE 0.26.8)

#### Request 2: pistol loaded / pistol fired

Attach:
1. `art/redraws/stat_icons_chatgpt.png` (the style and frame)
2. `art/redraws/cuirassier_dismounted_e_chatgpt.png` (row 3: the officer's own flintlock pistol, the gun to draw)

Save as `art/redraws/pistol_icons_chatgpt.png`. Import: EXTRA entry `["pistol_loaded", "pistol_empty"]` in tools/import_stat_icons.py; then in Hud._draw_pistol draw `UnitStats.texture("pistol_loaded" / "pistol_empty")` at about 24 x 24 when the file exists (keep the code drawing as the fallback).

```
The first attached image is an icon sheet from my pixel-art RTS game (17th-century gunpowder setting): small square icons in a thin brass frame with round corner rivets, on a flat dark navy background. The second image is a sprite sheet of a cavalry officer; its third row shows him firing his flintlock PISTOL. Draw TWO NEW ICONS of that same pistol, in exactly the style, frame, size and lighting (light from the upper left) of the first image:

1. PISTOL LOADED: the flintlock pistol seen from the side, pointing right, the cock pulled back, polished steel barrel and lock, warm brown wooden grip, a tiny bright orange spark of priming powder in the pan.
2. PISTOL FIRED: the very same pistol in the very same position and size, but the cock down, the steel dull and darker, the wood darker, and a thin curl of grey smoke rising from the muzzle. No red cross or bar.

Both pistols identical in shape, size and position inside their frames so they can swap without moving. They must read when shown very small (about 24 pixels): bold silhouette, strong dark outline, no text, letters or numbers.

Layout: a landscape image 1536 x 1024 pixels, ONE flat even dark navy background (about RGB 18, 30, 48), no texture, vignette, shadow or labels. The two icons side by side in one row in the middle, each the same square size (about 300 x 300 pixels including its brass frame), at least 100 pixels of empty navy between them and around the edge, nothing crossing a frame.

Style: hard square pixels, no anti-aliasing, no blur, no glow, two or three painted tones per colour, like the first image. Deliver a PNG file (not a JPEG, not a screenshot).
```

### Item 3: Labourer walk, south and south-east (one request per view)

DONE 2026-11-03 (0.26.15): the v4 answers are in (table item 8). The requests below are kept for the record.

Why again: the v3 attempts (art/redraws/labourer_walk_s_v3.png, _se_v3.png) kept the feet together. This time the
game's CURRENT strip is attached as the pose guide: its legs are code-made (the east stride squeezed) and show the
step size wanted; ChatGPT repaints them in the body's style.

#### Request 3S: Labourer walk, SOUTH

Attach:
1. `art/redraws/labourer_walk_east_test.png` (the same man walking EAST, drawn by you: the style and leg timing to copy)
2. `assets/units/labourer/walk_s.png` ENLARGED 6x (section 0: refs/assets__units__labourer__walk_s.png): the game's current south walk; its legs are a rough code pose guide showing how far the feet must move
3. `art/redraws/labourer_walk_s_v3.png` (your earlier south walk: the body, hat and coat to keep; its legs barely move, which is the mistake)

Save as `art/redraws/labourer_walk_s_v4.png`. Import: V3["s"] = "labourer_walk_s_v4.png" in tools/import_labourer_v2.py, remove "s" from SQUEEZE in tools/import_labourer_stride.py, run tools/rebuild_art.sh (the carry and Crown leg passes reuse these legs).

```
Draw a 6-frame WALK cycle of this labourer (wide brown felt hat, red coat with a dark belt and crossing straps, grey trousers, brown boots), EMPTY hands, no tool, in the SOUTH view: he walks straight toward the viewer, we see his face, the front of his coat and both legs, with the slight top-down camera of a classic RTS.

Reference 1 is the same man walking in the EAST view, drawn exactly as I want: copy its pixel style, its quality and its leg timing (frame 1 contact, frame 2 down, frame 3 passing, frame 4 contact with the other foot, frame 5 down, frame 6 passing, flowing back into frame 1).
Reference 2 is the game's current south walk, enlarged: its legs are only a rough guide made by a program, but they show the STEP SIZE I need: copy how far apart the boots are in each frame, not the thin drawing of the legs.
Reference 3 is your earlier south walk: keep its body, hat, face and coat exactly, but its legs hardly move, so in the game he slides. That is the mistake to fix.

Legs from the front: in the CONTACT frames (1 and 4) one boot is placed forward (lower in the picture, nearer to us) and the other back (higher in the picture), clearly apart: about a third of the body's width sideways and a quarter of the leg's length up and down. In the DOWN frames (2 and 5) the body is one pixel lower and the back knee bends. In the PASSING frames (3 and 6) the moving boot is lifted clearly off the ground, its sole visible, passing the planted leg. Frames 4 to 6 repeat with the OTHER foot, so left and right boots swap roles. Arms swing a little against the legs; the shoulders sway a little. Head and hat keep the same size and drawing in every frame. Planted boots stay on the same ground line.

WHAT MUST NOT CHANGE: the man (hat, face, red coat, belt, straps, grey trousers, brown boots), his size, the pixel style of references 1 and 3, drawn with the same outline weight and two or three tones per colour on the trousers and boots.
AVOID: both boots flat side by side in every frame, a limp, a third leg or boot, legs of different length, a tool, sack or keg, any text, the labels or enlarged pixels of reference 2.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no gradients, no glow; a dark near-black outline of one game pixel; each game pixel a clean square block of about 6 x 6 image pixels.

Background: one flat solid dark navy colour, exactly RGB 0, 22, 48 (#001630), everywhere, nothing else on it: no title, labels, numbers, grid, ground, shadow or borders. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all standing on the same invisible ground line near the middle of the image, all the same size. Landscape image 1536 x 1024 pixels. Each figure fits in a box about 230 px wide and 300 px high, at least 20 px of navy between neighbours, none touching or cut by the edge. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 3SE: Labourer walk, SOUTH-EAST

Attach:
1. `art/redraws/labourer_walk_east_test.png` (the EAST walk: style and timing)
2. `assets/units/labourer/walk_se.png` ENLARGED 6x (refs/assets__units__labourer__walk_se.png): the current south-east walk, code legs = step size guide
3. `art/redraws/labourer_walk_se_v3.png` (your earlier south-east walk: body to keep, legs that barely move)

Save as `art/redraws/labourer_walk_se_v4.png`. Import: V3["se"] in tools/import_labourer_v2.py; remove "se" from SQUEEZE in tools/import_labourer_stride.py (with both views in, drop the script from tools/rebuild_art.sh and its line in docs/art_style_inconsistency.md section A).

```
Draw a 6-frame WALK cycle of this labourer (wide brown felt hat, red coat with a dark belt and crossing straps, grey trousers, brown boots), EMPTY hands, no tool, in the SOUTH-EAST view: a three-quarter view from the front right, he walks toward the LOWER RIGHT of the picture; we see his face turned right and down, the front and his left side of the coat, and both legs, with the slight top-down camera of a classic RTS.

Reference 1 is the same man walking in the EAST view, drawn exactly as I want: copy its pixel style, its quality and its leg timing (frame 1 contact, frame 2 down, frame 3 passing, frame 4 contact with the other foot, frame 5 down, frame 6 passing, flowing back into frame 1).
Reference 2 is the game's current south-east walk, enlarged: its legs are only a rough guide made by a program, but they show the STEP SIZE I need: copy how far apart the boots are in each frame, not the thin drawing of the legs.
Reference 3 is your earlier south-east walk: keep its body, hat, face and coat exactly, but its legs hardly move, so in the game he slides. That is the mistake to fix.

Legs in this view: the east stride, foreshortened. In the CONTACT frames (1 and 4) the front boot is placed forward toward the lower right and the back boot behind toward the upper left, clearly apart (about half the body's width). In the DOWN frames (2 and 5) the body is one pixel lower and the back knee bends. In the PASSING frames (3 and 6) the moving boot is lifted clearly off the ground with the knee forward. Frames 4 to 6 swap the feet. Arms swing a little against the legs. Head and hat keep the same size and drawing in every frame. Planted boots stay on the same ground line.

WHAT MUST NOT CHANGE: the man (hat, face, red coat, belt, straps, grey trousers, brown boots), his size, the pixel style of references 1 and 3, with the same outline weight and two or three tones per colour on the trousers and boots.
AVOID: boots side by side in every frame, a limp, a third leg or boot, legs of different length, a tool, sack or keg, any text, the labels or enlarged pixels of reference 2.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no gradients, no glow; a dark near-black outline of one game pixel; each game pixel a clean square block of about 6 x 6 image pixels.

Background: one flat solid dark navy colour, exactly RGB 0, 22, 48 (#001630), everywhere, nothing else on it: no title, labels, numbers, grid, ground, shadow or borders. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all standing on the same invisible ground line near the middle of the image, all the same size. Landscape image 1536 x 1024 pixels. Each figure fits in a box about 230 px wide and 300 px high, at least 20 px of navy between neighbours, none touching or cut by the edge. Deliver a PNG file (not a JPEG, not a screenshot).
```

### Item 4: Musketeer walk (one request per view)

Same three kinds of reference in each: (1) `art/redraws/musketeer_aim_se_chatgpt.png`, the ChatGPT Musketeer already in
the game (body, tricorne, coat, style); (2) `art/redraws/labourer_walk_east_test.png`, the walk whose legs he wears now
(timing and leg style); (3) the game's CURRENT walk strip of that view, enlarged 6x (refs/assets__units__musketeer__walk_<d>.png),
for how he carries the musket in that view. Save each answer as `art/redraws/musketeer_walk_<d>_chatgpt.png`.
Importer (to write, see table item 9): one row of 6, CELL (90, 36), ANCHOR (45, 35), BODY_H 30 hat to soles, centred
on the coat; then drop "musketeer" from tools/import_crown_legs.py TARGETS and run tools/import_vet_trim.py --only musketeer.

#### Request 4S: Musketeer walk, SOUTH

Attach: `art/redraws/musketeer_aim_se_chatgpt.png`, `art/redraws/labourer_walk_east_test.png`, `assets/units/musketeer/walk_s.png` enlarged 6x.

```
Draw a 6-frame WALK cycle (a steady march) of this musketeer from my pixel-art RTS (a 17th-century gunpowder setting), in the SOUTH view: he marches straight toward the viewer, we see his face and the front of his coat, with the slight top-down camera of a classic RTS.

Reference 1 is the musketeer as he must look: black tricorne hat with gold lace, red coat with cream facings and turn-backs, white cross belt, grey breeches, brown boots, a long brown musket. Copy him exactly: his face, hat, coat, colours, proportions and pixel style.
Reference 2 is another man of the same game walking east: copy its leg timing (frame 1 contact, frame 2 down, frame 3 passing, frame 4 contact with the other foot, frame 5 down, frame 6 passing, flowing back into frame 1) and the way the legs are drawn, not the man.
Reference 3 is the game's current south walk of the musketeer, enlarged: it shows how he carries the musket in this view (upright at his side against the shoulder). Keep the musket exactly like that, the same hand, angle and length, in every frame.

Legs from the front: in the CONTACT frames one boot is forward (lower in the picture, nearer to us) and the other back (higher), clearly apart; in the DOWN frames the body is one pixel lower; in the PASSING frames the moving boot is lifted clearly off the ground, its sole visible. Frames 4 to 6 swap the feet. The free arm swings a little. The head and hat keep the same size and drawing in every frame.

WHAT MUST NOT CHANGE: the tricorne (black with gold lace: not a slouch hat, no plume), the red coat, the grey breeches, the brown boots, the musket held in his hands or against his shoulder in every frame, his size.
AVOID: losing the hat or the musket in any frame, a musket that grows, shrinks or jumps between frames, both boots side by side in every frame, a limp, extra or missing limbs, a green or white plume, any text, the enlarged pixels or labels of reference 3.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no gradients, no glow; a dark near-black outline of one game pixel; two or three painted tones per colour; each game pixel a clean square block of about 6 x 6 image pixels.

Background: one flat solid dark navy colour, exactly RGB 0, 22, 48 (#001630), everywhere, nothing else on it: no title, labels, numbers, grid, ground, smoke, shadow or borders. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all standing on the same invisible ground line near the middle of the image, all the same size. Landscape image 1536 x 1024 pixels. Each figure with its musket fits in a box about 230 px wide and 300 px high, at least 20 px of navy between neighbours, none touching or cut by the edge. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 4SE: Musketeer walk, SOUTH-EAST

Attach: `art/redraws/musketeer_aim_se_chatgpt.png`, `art/redraws/labourer_walk_east_test.png`, `assets/units/musketeer/walk_se.png` enlarged 6x.

```
Draw a 6-frame WALK cycle (a steady march) of this musketeer from my pixel-art RTS (a 17th-century gunpowder setting), in the SOUTH-EAST view: a three-quarter view from the front right, he marches toward the LOWER RIGHT of the picture; we see his face turned right and down and the front and left side of his coat, with the slight top-down camera of a classic RTS. Reference 1 shows him in exactly this view.

Reference 1 is the musketeer as he must look: black tricorne hat with gold lace, red coat with cream facings and turn-backs, white cross belt, grey breeches, brown boots, a long brown musket. Copy him exactly: his face, hat, coat, colours, proportions and pixel style.
Reference 2 is another man of the same game walking east: copy its leg timing (frame 1 contact, frame 2 down, frame 3 passing, frame 4 contact with the other foot, frame 5 down, frame 6 passing, flowing back into frame 1) and the way the legs are drawn, not the man.
Reference 3 is the game's current south-east walk of the musketeer, enlarged: it shows how he carries the musket in this view (sloped across his body, the muzzle up to the right). Keep the musket exactly like that, the same hands, angle and length, in every frame.

Legs in this view: in the CONTACT frames the front boot is placed toward the lower right and the back boot toward the upper left, clearly apart (about half the body's width); in the DOWN frames the body is one pixel lower; in the PASSING frames the moving boot is lifted off the ground with the knee forward. Frames 4 to 6 swap the feet. The head and hat keep the same size and drawing in every frame.

WHAT MUST NOT CHANGE: the tricorne (black with gold lace: not a slouch hat, no plume), the red coat, the grey breeches, the brown boots, the musket in his hands in every frame, his size.
AVOID: losing the hat or the musket in any frame, a musket that grows, shrinks or jumps between frames, boots side by side in every frame, a limp, extra or missing limbs, a green or white plume, any text, the enlarged pixels or labels of reference 3.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no gradients, no glow; a dark near-black outline of one game pixel; two or three painted tones per colour; each game pixel a clean square block of about 6 x 6 image pixels.

Background: one flat solid dark navy colour, exactly RGB 0, 22, 48 (#001630), everywhere, nothing else on it: no title, labels, numbers, grid, ground, smoke, shadow or borders. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all standing on the same invisible ground line near the middle of the image, all the same size. Landscape image 1536 x 1024 pixels. Each figure with its musket fits in a box about 230 px wide and 300 px high, at least 20 px of navy between neighbours, none touching or cut by the edge. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 4E: Musketeer walk, EAST

Attach: `art/redraws/musketeer_aim_se_chatgpt.png`, `art/redraws/labourer_walk_east_test.png`, `assets/units/musketeer/walk_e.png` enlarged 6x.

```
Draw a 6-frame WALK cycle (a steady march) of this musketeer from my pixel-art RTS (a 17th-century gunpowder setting), in the EAST view: seen from the side, he marches to the RIGHT of the picture, with the slight top-down camera of a classic RTS.

Reference 1 is the musketeer as he must look: black tricorne hat with gold lace, red coat with cream facings and turn-backs, white cross belt, grey breeches, brown boots, a long brown musket. Copy him exactly: his face, hat, coat, colours, proportions and pixel style (reference 1 shows him from the front right; turn him to a clean side view).
Reference 2 is another man of the same game walking east, drawn the way I want the legs: copy its leg timing (frame 1 contact, frame 2 down, frame 3 passing, frame 4 contact with the other foot, frame 5 down, frame 6 passing, flowing back into frame 1) and its stride length, not the man.
Reference 3 is the game's current east walk of the musketeer, enlarged: it shows how he carries the musket in this view (sloped on the shoulder, the muzzle up and forward). Keep the musket exactly like that, the same hands, angle and length, in every frame.

Legs from the side: in the CONTACT frames the front leg reaches forward and the back leg back, a wide clear step; in the DOWN frames the body is one pixel lower and the front knee bends; in the PASSING frames the back leg swings through, its boot lifted. Frames 4 to 6 swap the legs (the near leg drawn lighter, the far leg a little darker). The head and hat keep the same size and drawing in every frame.

WHAT MUST NOT CHANGE: the tricorne (black with gold lace: not a slouch hat, no plume), the red coat, the grey breeches, the brown boots, the musket on his shoulder in every frame, his size.
AVOID: losing the hat or the musket in any frame, a musket that grows, shrinks or jumps between frames, a limp, extra or missing limbs, a green or white plume, any text, the enlarged pixels or labels of reference 3.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no gradients, no glow; a dark near-black outline of one game pixel; two or three painted tones per colour; each game pixel a clean square block of about 6 x 6 image pixels.

Background: one flat solid dark navy colour, exactly RGB 0, 22, 48 (#001630), everywhere, nothing else on it: no title, labels, numbers, grid, ground, smoke, shadow or borders. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all standing on the same invisible ground line near the middle of the image, all the same size. Landscape image 1536 x 1024 pixels. Each figure with its musket fits in a box about 230 px wide and 300 px high, at least 20 px of navy between neighbours, none touching or cut by the edge. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 4NE: Musketeer walk, NORTH-EAST

Attach: `art/redraws/musketeer_aim_se_chatgpt.png`, `art/redraws/labourer_walk_east_test.png`, `assets/units/musketeer/walk_ne.png` enlarged 6x.

```
Draw a 6-frame WALK cycle (a steady march) of this musketeer from my pixel-art RTS (a 17th-century gunpowder setting), in the NORTH-EAST view: a three-quarter view from the BACK right, he marches toward the UPPER RIGHT of the picture; we see the back of his tricorne and head, his back and right side, with the slight top-down camera of a classic RTS. His face is NOT visible.

Reference 1 is the musketeer as he must look: black tricorne hat with gold lace, red coat with cream facings and turn-backs, white cross belt, grey breeches, brown boots, a long brown musket. Copy his outfit, colours, proportions and pixel style exactly, turned to this back three-quarter view.
Reference 2 is another man of the same game walking east: copy its leg timing (frame 1 contact, frame 2 down, frame 3 passing, frame 4 contact with the other foot, frame 5 down, frame 6 passing, flowing back into frame 1) and the way the legs are drawn, not the man.
Reference 3 is the game's current north-east walk of the musketeer, enlarged: it shows how he carries the musket in this view (sloped on the shoulder, the muzzle up and to the right). Keep the musket exactly like that, the same hands, angle and length, in every frame.

Legs from behind, foreshortened: in the CONTACT frames the front boot is toward the upper right and the back boot toward the lower left, clearly apart; in the DOWN frames the body is one pixel lower; in the PASSING frames one boot is lifted with the heel up and the sole showing. Frames 4 to 6 swap the feet. The head and hat keep the same size and drawing in every frame.

WHAT MUST NOT CHANGE: the tricorne (black with gold lace, seen from behind), the red coat with its turn-backs, the grey breeches, the brown boots, the musket on his shoulder in every frame, his size.
AVOID: showing his face, losing the hat or the musket in any frame, a musket that grows, shrinks or jumps, boots side by side in every frame, a limp, extra or missing limbs, any plume, any text, the enlarged pixels or labels of reference 3.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no gradients, no glow; a dark near-black outline of one game pixel; two or three painted tones per colour; each game pixel a clean square block of about 6 x 6 image pixels.

Background: one flat solid dark navy colour, exactly RGB 0, 22, 48 (#001630), everywhere, nothing else on it: no title, labels, numbers, grid, ground, smoke, shadow or borders. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all standing on the same invisible ground line near the middle of the image, all the same size. Landscape image 1536 x 1024 pixels. Each figure with its musket fits in a box about 230 px wide and 300 px high, at least 20 px of navy between neighbours, none touching or cut by the edge. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 4N: Musketeer walk, NORTH

Attach: `art/redraws/musketeer_aim_se_chatgpt.png`, `art/redraws/labourer_walk_east_test.png`, `assets/units/musketeer/walk_n.png` enlarged 6x.

```
Draw a 6-frame WALK cycle (a steady march) of this musketeer from my pixel-art RTS (a 17th-century gunpowder setting), in the NORTH view: he marches straight AWAY from the viewer; we see the back of his tricorne and head, the back of his red coat with its cross belts and turn-backs, and both legs from behind, with the slight top-down camera of a classic RTS.

Reference 1 is the musketeer as he must look: black tricorne hat with gold lace, red coat with cream facings and turn-backs, white cross belt, grey breeches, brown boots, a long brown musket. Copy his outfit, colours, proportions and pixel style exactly, seen from behind.
Reference 2 is another man of the same game walking east: copy its leg timing (frame 1 contact, frame 2 down, frame 3 passing, frame 4 contact with the other foot, frame 5 down, frame 6 passing, flowing back into frame 1) and the way the legs are drawn, not the man.
Reference 3 is the game's current north walk of the musketeer, enlarged: it shows how he carries the musket in this view (upright at his left shoulder, the stock low). Keep the musket exactly like that, the same side, angle and length, in every frame.

Legs from behind: in the CONTACT frames one boot is forward (higher in the picture, away from us) and the other back (lower, nearer to us), clearly apart; the boot nearer to us shows its sole as it pushes off; in the DOWN frames the body is one pixel lower; in the PASSING frames one boot is clearly lifted with its heel up while the other leg is straight. Frames 4 to 6 swap the feet. The shoulders sway a little. The head and hat keep the same size and drawing in every frame.

WHAT MUST NOT CHANGE: the tricorne (black with gold lace, seen from behind), the red coat, the grey breeches, the brown boots, the musket at his shoulder in every frame, his size.
AVOID: showing his face, both boots flat side by side in every frame (the main mistake to avoid), losing the hat or the musket in any frame, a musket that grows, shrinks or jumps, a limp, extra or missing limbs, any plume, any text, the enlarged pixels or labels of reference 3.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no gradients, no glow; a dark near-black outline of one game pixel; two or three painted tones per colour; each game pixel a clean square block of about 6 x 6 image pixels.

Background: one flat solid dark navy colour, exactly RGB 0, 22, 48 (#001630), everywhere, nothing else on it: no title, labels, numbers, grid, ground, smoke, shadow or borders. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all standing on the same invisible ground line near the middle of the image, all the same size. Landscape image 1536 x 1024 pixels. Each figure with its musket fits in a box about 230 px wide and 300 px high, at least 20 px of navy between neighbours, none touching or cut by the edge. Deliver a PNG file (not a JPEG, not a screenshot).
```

### Item 5: Clock Soldier walk (one request per view, eight views)

The Clock Soldier has its own west views (sword stays in its RIGHT hand), so SW, W and NW are drawn too.
References: east views attach `art/redraws/clock_soldier_idle.png` (its painted idle, 5 rows S/SE/E/NE/N: body and style),
`art/redraws/clock_soldier_walk_mix.png` (the current walk: same layout; the legs are code-made and barely step) and
`art/redraws/clock_soldier_attack_final.png` (a cleaned ChatGPT sheet of the same robot). West views attach
`art/redraws/clock_soldier_idle_west_chatgpt.png` (rows SW/W/NW), `art/redraws/clock_soldier_walk_west.png` (current
west walk, code-made) and `art/redraws/clock_soldier_idle.png`.
Keep the painted colours as they are (red body, blue shoulder balls): the importer recolours them (tools/cw_palette.py).
Save as `art/redraws/clock_soldier_walk_<d>_chatgpt.png`; import as in table item 10.

#### Request 5S: Clock Soldier walk, SOUTH

Attach: `art/redraws/clock_soldier_idle.png`, `art/redraws/clock_soldier_walk_mix.png`, `art/redraws/clock_soldier_attack_final.png`.

```
I am attaching three pixel-art sheets of the same small clockwork soldier from my RTS game: a round red body with a clock face on its chest, a gold cap with a spike on top, blue ball shoulders, short brass-and-steel legs with round brass feet, a short golden sword in its RIGHT hand and a round brass shield on its LEFT arm, on a flat navy background. In every sheet the rows face: 1 down (south), 2 down-right, 3 right, 4 up-right, 5 up.

Image 1 is its standing idle: copy the robot exactly from its row 1 (size, colours, pixel style, clock face, cap).
Image 2 is its current WALK, row 1 is this view: the problem is that the feet hardly move, so in the game it slides over the ground.
Image 3 is another finished sheet of the same robot, for the style.

Draw ONLY the SOUTH view (walking straight toward the viewer, the clock face toward us): a 6-frame brisk march with REAL steps. Frames 1 and 4 are the widest steps (in frame 1 its right foot is forward, lower in the picture and nearer to us, the left foot back and higher; in frame 4 the other way round), frames 2 and 5 the body lowest, frames 3 and 6 one foot clearly lifted off the ground passing the other. The steps are short and stubby like the legs, but clearly visible: the forward foot at least a whole foot's length lower in the picture than the back foot. The body bobs one or two pixels up on the passing frames and sways a little. The sword stays in its RIGHT hand (on the left of the picture) and the shield on its LEFT arm (on the right of the picture), held in front, in every frame. The clock face, cap and body never change shape or size.

AVOID: feet that stay side by side, long thin legs, the sword or shield changing hands, a missing cap, motion lines, shadows, any text.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no glow; a dark outline; the same palette and painted shading as image 1.

Background: one flat solid navy colour, exactly RGB 0, 22, 48 (#001630), nothing else on it: no labels, grid, ground or shadow. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line, each the same size as in image 1, at least 30 px of navy between them, none touching or cut by the edge. Landscape image 1536 x 1024 pixels. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 5SE: Clock Soldier walk, SOUTH-EAST

Attach: `art/redraws/clock_soldier_idle.png`, `art/redraws/clock_soldier_walk_mix.png`, `art/redraws/clock_soldier_attack_final.png`.

```
I am attaching three pixel-art sheets of the same small clockwork soldier from my RTS game: a round red body with a clock face on its chest, a gold cap with a spike on top, blue ball shoulders, short brass-and-steel legs with round brass feet, a short golden sword in its RIGHT hand and a round brass shield on its LEFT arm, on a flat navy background. In every sheet the rows face: 1 down (south), 2 down-right, 3 right, 4 up-right, 5 up.

Image 1 is its standing idle: copy the robot exactly from its row 2 (size, colours, pixel style, clock face, cap).
Image 2 is its current WALK, row 2 is this view: the problem is that the feet hardly move, so in the game it slides over the ground.
Image 3 is another finished sheet of the same robot, for the style.

Draw ONLY the SOUTH-EAST view (three-quarter from the front, walking toward the LOWER RIGHT of the picture): a 6-frame brisk march with REAL steps. Frames 1 and 4 are the widest steps (the front foot placed toward the lower right, the back foot toward the upper left, about a third of the body's width apart; frame 4 with the other foot in front), frames 2 and 5 the body lowest, frames 3 and 6 one foot clearly lifted off the ground passing the other with the knee forward. The body bobs one or two pixels up on the passing frames. The sword stays in its RIGHT hand and the shield on its LEFT arm, held in front of the body, in every frame. The clock face, cap and body never change shape or size.

AVOID: feet that stay side by side, long thin legs, the sword crossing in front of the near leg, the sword or shield changing hands, a missing cap, motion lines, shadows, any text.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no glow; a dark outline; the same palette and painted shading as image 1.

Background: one flat solid navy colour, exactly RGB 0, 22, 48 (#001630), nothing else on it: no labels, grid, ground or shadow. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line, each the same size as in image 1, at least 30 px of navy between them, none touching or cut by the edge. Landscape image 1536 x 1024 pixels. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 5E: Clock Soldier walk, EAST

Attach: `art/redraws/clock_soldier_idle.png`, `art/redraws/clock_soldier_walk_mix.png`, `art/redraws/clock_soldier_attack_final.png`.

```
I am attaching three pixel-art sheets of the same small clockwork soldier from my RTS game: a round red body with a clock face on its chest, a gold cap with a spike on top, blue ball shoulders, short brass-and-steel legs with round brass feet, a short golden sword in its RIGHT hand and a round brass shield on its LEFT arm, on a flat navy background. In every sheet the rows face: 1 down (south), 2 down-right, 3 right, 4 up-right, 5 up.

Image 1 is its standing idle: copy the robot exactly from its row 3 (size, colours, pixel style, cap), except the shield (see below).
Image 2 is its current WALK, row 3 is this view: the problem is that the feet hardly move, so in the game it slides over the ground.
Image 3 is another finished sheet of the same robot, for the style.

Draw ONLY the EAST view (seen from the side, walking to the RIGHT): a 6-frame brisk march with REAL steps. Frames 1 and 4 are the widest steps: the front foot reaches about a third of the body's width ahead and the back foot as far behind; frames 2 and 5 the body lowest, frames 3 and 6 the back leg swinging through with its foot lifted. The near leg is drawn lighter, the far leg a little darker behind it. The body bobs one or two pixels up on the passing frames.
Its RIGHT side faces us: the sword is in its right hand, in front of us, pointing forward and down. The SHIELD: in images 1 and 2 it shows only as a rim behind the robot's back, so it looks like a shield carried on its back. Fix that: the far (left) arm holds the shield FORWARD, guarding the front of the body, so its rim and part of its face show on the RIGHT side of the body (the side it walks toward), partly hidden by the body. Nothing on its back. The clock face, cap and body never change shape or size.

AVOID: feet that stay together, long thin legs, a shield on the back, the sword or shield changing hands, a missing cap, motion lines, shadows, any text.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no glow; a dark outline; the same palette and painted shading as image 1.

Background: one flat solid navy colour, exactly RGB 0, 22, 48 (#001630), nothing else on it: no labels, grid, ground or shadow. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line, each the same size as in image 1, at least 30 px of navy between them, none touching or cut by the edge. Landscape image 1536 x 1024 pixels. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 5NE: Clock Soldier walk, NORTH-EAST

Attach: `art/redraws/clock_soldier_idle.png`, `art/redraws/clock_soldier_walk_mix.png`, `art/redraws/clock_soldier_attack_final.png`.

```
I am attaching three pixel-art sheets of the same small clockwork soldier from my RTS game: a round red body with a clock face on its chest, a gold cap with a spike on top, blue ball shoulders, short brass-and-steel legs with round brass feet, a short golden sword in its RIGHT hand and a round brass shield on its LEFT arm, on a flat navy background. In every sheet the rows face: 1 down (south), 2 down-right, 3 right, 4 up-right, 5 up.

Image 1 is its standing idle: copy the robot exactly from its row 4 (size, colours, pixel style, the riveted red back, cap).
Image 2 is its current WALK, row 4 is this view: the problem is that the feet hardly move, so in the game it slides over the ground.
Image 3 is another finished sheet of the same robot, for the style.

Draw ONLY the NORTH-EAST view (three-quarter from the BACK, walking toward the UPPER RIGHT of the picture; the clock face is not visible, we see its red riveted back): a 6-frame brisk march with REAL steps. Frames 1 and 4 are the widest steps (the front foot toward the upper right, the back foot toward the lower left, clearly apart; frame 4 with the other foot in front), frames 2 and 5 the body lowest, frames 3 and 6 one foot lifted with its sole showing as it pushes off. The body bobs one or two pixels up on the passing frames. The sword stays in its RIGHT hand (on the right of the picture, pointing down and forward) and the shield on its LEFT arm (on the left of the picture), in every frame. The body and cap never change shape or size.

AVOID: feet that stay side by side, long thin legs, showing the clock face, the sword or shield changing hands, a missing cap, motion lines, shadows, any text.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no glow; a dark outline; the same palette and painted shading as image 1.

Background: one flat solid navy colour, exactly RGB 0, 22, 48 (#001630), nothing else on it: no labels, grid, ground or shadow. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line, each the same size as in image 1, at least 30 px of navy between them, none touching or cut by the edge. Landscape image 1536 x 1024 pixels. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 5N: Clock Soldier walk, NORTH

Attach: `art/redraws/clock_soldier_idle.png`, `art/redraws/clock_soldier_walk_mix.png`, `art/redraws/clock_soldier_attack_final.png`.

```
I am attaching three pixel-art sheets of the same small clockwork soldier from my RTS game: a round red body with a clock face on its chest, a gold cap with a spike on top, blue ball shoulders, short brass-and-steel legs with round brass feet, a short golden sword in its RIGHT hand and a round brass shield on its LEFT arm, on a flat navy background. In every sheet the rows face: 1 down (south), 2 down-right, 3 right, 4 up-right, 5 up.

Image 1 is its standing idle: copy the robot exactly from its row 5 (size, colours, pixel style, the red back with its round brass winding hole, cap).
Image 2 is its current WALK, row 5 is this view: the problem is that the feet hardly move, so in the game it slides over the ground.
Image 3 is another finished sheet of the same robot, for the style.

Draw ONLY the NORTH view (walking straight AWAY from the viewer, its back toward us): a 6-frame brisk march with REAL steps. Frames 1 and 4 are the widest steps (one foot forward, higher in the picture, the other back, lower and nearer to us, clearly apart; frame 4 the other way round), frames 2 and 5 the body lowest, frames 3 and 6 one foot clearly lifted with its sole showing. The body bobs one or two pixels up on the passing frames and sways a little. Seen from behind, the shield on its LEFT arm is on the LEFT of the picture and the sword in its RIGHT hand on the RIGHT of the picture, in every frame. The body and cap never change shape or size.

AVOID: both feet flat side by side in every frame (the main mistake), long thin legs, showing the clock face, the sword or shield changing sides, a missing cap, motion lines, shadows, any text.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no glow; a dark outline; the same palette and painted shading as image 1.

Background: one flat solid navy colour, exactly RGB 0, 22, 48 (#001630), nothing else on it: no labels, grid, ground or shadow. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line, each the same size as in image 1, at least 30 px of navy between them, none touching or cut by the edge. Landscape image 1536 x 1024 pixels. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 5SW: Clock Soldier walk, SOUTH-WEST

Attach: `art/redraws/clock_soldier_idle_west_chatgpt.png`, `art/redraws/clock_soldier_walk_west.png`, `art/redraws/clock_soldier_idle.png`.

```
I am attaching three pixel-art sheets of the same small clockwork soldier from my RTS game: a round red body with a clock face on its chest, a gold cap with a spike on top, blue ball shoulders, short brass-and-steel legs with round brass feet, a short golden sword in its RIGHT hand and a round brass shield on its LEFT arm, on a flat navy background.

Image 1 is its standing idle facing LEFT, three rows: 1 down-left (south-west), 2 left (west), 3 up-left (north-west). Copy the robot exactly from its row 1 (size, colours, pixel style, clock face, cap, the shield in front).
Image 2 is its current WALK in the same three rows, made by a program: the feet hardly move, so in the game it slides over the ground.
Image 3 is the same robot facing the other ways, for its style.

Draw ONLY the SOUTH-WEST view (three-quarter from the front, walking toward the LOWER LEFT of the picture): a 6-frame brisk march with REAL steps. Frames 1 and 4 are the widest steps (the front foot placed toward the lower left, the back foot toward the upper right, about a third of the body's width apart; frame 4 with the other foot in front), frames 2 and 5 the body lowest, frames 3 and 6 one foot clearly lifted passing the other with the knee forward. The body bobs one or two pixels up on the passing frames. The shield stays on its LEFT arm, held in front of the body toward the lower left, and the sword in its RIGHT hand, behind the shield on the far side, in every frame (do NOT mirror the robot: the sword stays in the right hand). The clock face, cap and body never change shape or size.

AVOID: feet that stay side by side, long thin legs, the sword or shield changing hands, a missing cap, motion lines, shadows, any text.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no glow; a dark outline; the same palette and painted shading as image 1.

Background: one flat solid navy colour, exactly RGB 0, 22, 48 (#001630), nothing else on it: no labels, grid, ground or shadow. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line, each the same size as in image 1, at least 30 px of navy between them, none touching or cut by the edge. Landscape image 1536 x 1024 pixels. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 5W: Clock Soldier walk, WEST

Attach: `art/redraws/clock_soldier_idle_west_chatgpt.png`, `art/redraws/clock_soldier_walk_west.png`, `art/redraws/clock_soldier_idle.png`.

```
I am attaching three pixel-art sheets of the same small clockwork soldier from my RTS game: a round red body with a clock face on its chest, a gold cap with a spike on top, blue ball shoulders, short brass-and-steel legs with round brass feet, a short golden sword in its RIGHT hand and a round brass shield on its LEFT arm, on a flat navy background.

Image 1 is its standing idle facing LEFT, three rows: 1 down-left (south-west), 2 left (west), 3 up-left (north-west). Copy the robot exactly from its row 2 (size, colours, pixel style, cap, the shield facing us).
Image 2 is its current WALK in the same three rows, made by a program: the feet hardly move, so in the game it slides over the ground.
Image 3 is the same robot facing the other ways, for its style.

Draw ONLY the WEST view (seen from the side, walking to the LEFT): a 6-frame brisk march with REAL steps. Frames 1 and 4 are the widest steps: the front foot reaches about a third of the body's width ahead (to the left) and the back foot as far behind; frames 2 and 5 the body lowest, frames 3 and 6 the back leg swinging through with its foot lifted. The near leg is drawn lighter, the far leg a little darker behind it. The body bobs one or two pixels up on the passing frames. Its LEFT side faces us: the round shield on its left arm is held in front of the body, facing us and the way it walks, as in image 1 row 2; the sword in its RIGHT hand is on the far side, its blade showing past the body. Do NOT mirror the robot. The cap and body never change shape or size.

AVOID: feet that stay together, long thin legs, the sword or shield changing hands, a missing cap, motion lines, shadows, any text.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no glow; a dark outline; the same palette and painted shading as image 1.

Background: one flat solid navy colour, exactly RGB 0, 22, 48 (#001630), nothing else on it: no labels, grid, ground or shadow. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line, each the same size as in image 1, at least 30 px of navy between them, none touching or cut by the edge. Landscape image 1536 x 1024 pixels. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 5NW: Clock Soldier walk, NORTH-WEST

Attach: `art/redraws/clock_soldier_idle_west_chatgpt.png`, `art/redraws/clock_soldier_walk_west.png`, `art/redraws/clock_soldier_idle.png`.

```
I am attaching three pixel-art sheets of the same small clockwork soldier from my RTS game: a round red body with a clock face on its chest, a gold cap with a spike on top, blue ball shoulders, short brass-and-steel legs with round brass feet, a short golden sword in its RIGHT hand and a round brass shield on its LEFT arm, on a flat navy background.

Image 1 is its standing idle facing LEFT, three rows: 1 down-left (south-west), 2 left (west), 3 up-left (north-west). Copy the robot exactly from its row 3 (size, colours, pixel style, the riveted red back, cap).
Image 2 is its current WALK in the same three rows, made by a program: the feet hardly move, so in the game it slides over the ground.
Image 3 is the same robot facing the other ways, for its style.

Draw ONLY the NORTH-WEST view (three-quarter from the BACK, walking toward the UPPER LEFT of the picture; the clock face is not visible): a 6-frame brisk march with REAL steps. Frames 1 and 4 are the widest steps (the front foot toward the upper left, the back foot toward the lower right, clearly apart; frame 4 with the other foot in front), frames 2 and 5 the body lowest, frames 3 and 6 one foot lifted with its sole showing as it pushes off. The body bobs one or two pixels up on the passing frames. The shield stays on its LEFT arm (on the left of the picture, toward where it walks) and the sword in its RIGHT hand (on the right of the picture), in every frame. Do NOT mirror the robot. The body and cap never change shape or size.

AVOID: feet that stay side by side, long thin legs, showing the clock face, the sword or shield changing hands, a missing cap, motion lines, shadows, any text.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no glow; a dark outline; the same palette and painted shading as image 1.

Background: one flat solid navy colour, exactly RGB 0, 22, 48 (#001630), nothing else on it: no labels, grid, ground or shadow. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line, each the same size as in image 1, at least 30 px of navy between them, none touching or cut by the edge. Landscape image 1536 x 1024 pixels. Deliver a PNG file (not a JPEG, not a screenshot).
```

### Item 6: Raptor walk, S, SE, NE, N (one request per view; E is kept)

References: `docs/redraw_refs/18_raptor_walk/1_current_raptor_walk.png` (the current walk enlarged: row 3 = the good
painted east run; the other rows have code legs), `docs/redraw_refs/18_raptor_walk/2_raptor_idle.png` (the raptor
standing), and `art/redraws/young_tyrant_<d>_chatgpt.png` (the Tyrant Challenger, the Raptor's grown-up form, drawn by
ChatGPT in that view: the Brood's current style and the view's angle). Keep the crest and spines PURE RED (#FF0000 lit,
#960000 shaded): they are the team colour. Save as `art/redraws/raptor_walk_<d>_chatgpt.png`; import as in table item 11
(cell 58x30, anchor (29,28), 6 frames; same scale as the east strip).

#### Request 6S: Raptor walk, SOUTH

Attach: `docs/redraw_refs/18_raptor_walk/1_current_raptor_walk.png`, `docs/redraw_refs/18_raptor_walk/2_raptor_idle.png`, `art/redraws/young_tyrant_s_chatgpt.png`.

```
I am attaching three pixel-art references from my RTS game. The creature to draw is the RAPTOR: a small, fast, two-legged reptile, olive-green scaly body with a pale yellow belly, a long tail, and a crest and a row of back spines in PURE RED. Image 1 is its current run, enlarged, rows top to bottom facing down, down-right, right, up-right, up: row 3 (running right) is drawn the way I want; the other rows have stiff stick legs made by a program. Image 2 is the raptor standing. Image 3 is a bigger, grown-up relative of the raptor drawn in my game's current style, seen from the front: use it for the pixel style, the scales and the way a front view of this kind of creature looks, but do NOT draw the bigger creature: draw the small raptor of images 1 and 2.

Draw ONLY the SOUTH view (running straight toward the viewer, head and chest toward us, the tail behind the body rising up the picture): a 6-frame run cycle with the same timing as row 3 of image 1: frame 1 contact (one leg reaching forward, lower in the picture and nearer to us, the other back), frame 2 down, frame 3 passing (the back leg lifted and swinging forward under the body), frames 4 to 6 the same with the other leg. The legs MUST visibly alternate, with clawed feet and bent knees, drawn in the same style as the body (not thin sticks). The head bobs one pixel, the tail sways opposite to the head, the small arms tucked with claws.

WHAT MUST NOT CHANGE: the raptor's size (small and slim), olive-green colours, the crest and spines in PURE RED (#FF0000 lit, #960000 shaded: no orange, pink or dark red), the head and tail of images 1 and 2.
AVOID: legs that stay in the same position, stick legs, extra legs or a third arm, the bigger relative's heavy body or its many tall spikes, a flat sideways view, motion lines, shadows, any text, the enlarged pixels or labels of image 1.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no glow; a dark outline; two or three painted tones per colour, like image 3.

Background: one flat solid navy colour, exactly RGB 0, 22, 48 (#001630), nothing else on it: no labels, grid, ground or shadow. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line, all the same size, at least 30 px of navy between them, none touching or cut by the edge. Landscape image 1536 x 1024 pixels, each figure about 200 px tall. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 6SE: Raptor walk, SOUTH-EAST

Attach: `docs/redraw_refs/18_raptor_walk/1_current_raptor_walk.png`, `docs/redraw_refs/18_raptor_walk/2_raptor_idle.png`, `art/redraws/young_tyrant_se_chatgpt.png`.

```
I am attaching three pixel-art references from my RTS game. The creature to draw is the RAPTOR: a small, fast, two-legged reptile, olive-green scaly body with a pale yellow belly, a long tail, and a crest and a row of back spines in PURE RED. Image 1 is its current run, enlarged, rows top to bottom facing down, down-right, right, up-right, up: row 3 (running right) is drawn the way I want; the other rows have stiff stick legs made by a program. Image 2 is the raptor standing. Image 3 is a bigger, grown-up relative of the raptor drawn in my game's current style, seen three-quarter from the front right: use it for the pixel style, the scales and this view's angle, but do NOT draw the bigger creature: draw the small raptor of images 1 and 2.

Draw ONLY the SOUTH-EAST view (three-quarter from the front, running toward the LOWER RIGHT of the picture, the tail stretching back toward the upper left): a 6-frame run cycle with the same timing as row 3 of image 1: frame 1 contact (one leg reaching forward toward the lower right, the other back), frame 2 down, frame 3 passing (the back leg lifted and swinging forward under the body), frames 4 to 6 the same with the other leg. The legs MUST visibly alternate, with clawed feet and bent knees, drawn in the same style as the body (not thin sticks). The head bobs one pixel, the tail sways opposite to the head.

WHAT MUST NOT CHANGE: the raptor's size (small and slim), olive-green colours, the crest and spines in PURE RED (#FF0000 lit, #960000 shaded: no orange, pink or dark red), the head and tail of images 1 and 2.
AVOID: legs that stay in the same position, stick legs, extra legs, the bigger relative's heavy body or its many tall spikes, motion lines, shadows, any text, the enlarged pixels or labels of image 1.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no glow; a dark outline; two or three painted tones per colour, like image 3.

Background: one flat solid navy colour, exactly RGB 0, 22, 48 (#001630), nothing else on it: no labels, grid, ground or shadow. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line, all the same size, at least 30 px of navy between them, none touching or cut by the edge. Landscape image 1536 x 1024 pixels, each figure about 220 px long. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 6NE: Raptor walk, NORTH-EAST

Attach: `docs/redraw_refs/18_raptor_walk/1_current_raptor_walk.png`, `docs/redraw_refs/18_raptor_walk/2_raptor_idle.png`, `art/redraws/young_tyrant_ne_chatgpt.png`.

```
I am attaching three pixel-art references from my RTS game. The creature to draw is the RAPTOR: a small, fast, two-legged reptile, olive-green scaly body with a pale yellow belly, a long tail, and a crest and a row of back spines in PURE RED. Image 1 is its current run, enlarged, rows top to bottom facing down, down-right, right, up-right, up: row 3 (running right) is drawn the way I want; row 4 is this view but its stick legs were made by a program and the body stands almost upright, which looks wrong. Image 2 is the raptor standing. Image 3 is a bigger, grown-up relative of the raptor drawn in my game's current style, seen three-quarter from the back right: use it for the pixel style, the scales and this view's angle, but do NOT draw the bigger creature: draw the small raptor of images 1 and 2.

Draw ONLY the NORTH-EAST view (three-quarter from the BACK, running toward the UPPER RIGHT of the picture: we see its back with the red spines along it, the head pointing up and right, the tail stretching back toward the lower left; the body is held level like a running bird, not upright): a 6-frame run cycle with the same timing as row 3 of image 1: frame 1 contact (one leg reaching forward toward the upper right, the other back toward the lower left), frame 2 down, frame 3 passing (the back leg lifted, its clawed foot showing its sole), frames 4 to 6 the same with the other leg. The legs MUST visibly alternate, drawn in the same style as the body (not thin sticks). The tail sways opposite to the head.

WHAT MUST NOT CHANGE: the raptor's size (small and slim), olive-green colours, the crest and spines in PURE RED (#FF0000 lit, #960000 shaded: no orange, pink or dark red), the head and tail of images 1 and 2.
AVOID: an upright body, legs that stay in the same position, stick legs, extra legs, the bigger relative's heavy body or its many tall spikes, motion lines, shadows, any text, the enlarged pixels or labels of image 1.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no glow; a dark outline; two or three painted tones per colour, like image 3.

Background: one flat solid navy colour, exactly RGB 0, 22, 48 (#001630), nothing else on it: no labels, grid, ground or shadow. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line, all the same size, at least 30 px of navy between them, none touching or cut by the edge. Landscape image 1536 x 1024 pixels, each figure about 220 px long. Deliver a PNG file (not a JPEG, not a screenshot).
```

#### Request 6N: Raptor walk, NORTH

Attach: `docs/redraw_refs/18_raptor_walk/1_current_raptor_walk.png`, `docs/redraw_refs/18_raptor_walk/2_raptor_idle.png`, `art/redraws/young_tyrant_n_chatgpt.png`.

```
I am attaching three pixel-art references from my RTS game. The creature to draw is the RAPTOR: a small, fast, two-legged reptile, olive-green scaly body with a pale yellow belly, a long tail, and a crest and a row of back spines in PURE RED. Image 1 is its current run, enlarged, rows top to bottom facing down, down-right, right, up-right, up: row 3 (running right) is drawn the way I want; the other rows have stiff stick legs made by a program. Image 2 is the raptor standing. Image 3 is a bigger, grown-up relative of the raptor drawn in my game's current style, seen from behind: use it for the pixel style, the scales and the way a back view of this kind of creature looks, but do NOT draw the bigger creature: draw the small raptor of images 1 and 2.

Draw ONLY the NORTH view (running straight AWAY from the viewer: we see its back with the red spine row down the middle, the back of the head and crest at the top, the tail toward us at the bottom of the figure): a 6-frame run cycle with the same timing as row 3 of image 1: frame 1 contact (one leg forward, higher in the picture, the other back, lower and nearer to us), frame 2 down, frame 3 passing (the near leg lifted, its clawed sole showing), frames 4 to 6 the same with the other leg. The legs MUST visibly alternate, drawn in the same style as the body (not thin sticks). The tail sways from side to side opposite to the head.

WHAT MUST NOT CHANGE: the raptor's size (small and slim), olive-green colours, the crest and spines in PURE RED (#FF0000 lit, #960000 shaded: no orange, pink or dark red), the head and tail of images 1 and 2.
AVOID: legs that stay in the same position, two straight stick legs side by side, extra legs, the bigger relative's heavy body or its many tall spikes, a flat sideways view, motion lines, shadows, any text, the enlarged pixels or labels of image 1.

Pixel art: hard square pixels, NO anti-aliasing, no blur, no glow; a dark outline; two or three painted tones per colour, like image 3.

Background: one flat solid navy colour, exactly RGB 0, 22, 48 (#001630), nothing else on it: no labels, grid, ground or shadow. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line, all the same size, at least 30 px of navy between them, none touching or cut by the edge. Landscape image 1536 x 1024 pixels, each figure about 200 px tall. Deliver a PNG file (not a JPEG, not a screenshot).
```

---

## 3. Notes for the main session

- Items 1 and 2 need a few lines of code each (no texture hook exists yet for the top-bar pills, card resource chips
  or the pistol); everything else drops in through existing importers or small loader changes noted per row.
- Items 8, 12 and 13 are linked: the labourer's walk legs are pasted under the carry strips and both Musketeers'
  walks today (import_labourer_carry_legs.py, import_crown_legs.py). Doing item 9 (and 12) retires the Musketeers'
  dependency; the carry strips still need item 13 (item 8 is done: 0.26.15, their s / se legs are the v4 walk's).
- After each import: tools/bump_version.sh, a patch note in scripts/patch_notes.gd, and remove the matching line from
  docs/art_style_inconsistency.md (CLAUDE.md rules).
- Stale CLAUDE.md backlog line: "Queen animation (not started; the Queen is a still sprite at the Brood capital)"
  refers to the old Brood removed in 0.18.0.
