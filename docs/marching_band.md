# The Marching Band (a real Crown unit since 0.33.0; v2 in 0.36.0: docs/band_v2.md; individual musicians in 0.37.0: docs/band_individuals.md; the experiment of 0.23.0 below)

The owner's idea (2026-10-30, docs/idea_bucket.md "CROWN MARCHING BAND"), made a real Crown unit by his decisions of
2026-11-05 (CLAUDE.md "MARCHING BAND AS A REAL UNIT"): a 17th-century band that follows the soldiers and gives AREA BUFFS
by the music it plays. BAGPIPES melee, DRUMS movement speed, FIFE ranged (as reload speed). The experiment's write-up,
its fight measurements and the answer to "strong or minor buffs?" are kept below ("The 0.23.0 experiment").

## What changed in 0.37.0 (job band-individuals): read docs/band_individuals.md

- **No band unit**: the Armoury trains the DRUMMER (the old `band` id), the FIFER (70 gold, no powder) and the PIPER,
  1 supply each, each with his own ring, +5%, SOLO (+30%, 8 s) and 45 s cooldown. The same instrument never adds up.
- **A BAND forms by itself** when one of each stand within each other's rings: one gold ring round the three, +8% each,
  solos +40% for 10 s (one at a time), in step, marching as a row behind the Drummer; SELECT BAND picks the three.
- **Lone musicians of different instruments overlapping are OUT OF STEP**: only the stronger buff counts there.
- **SOLO**: a press plays ONE selected musician of that instrument, Ctrl every one. **Buff markers** over soldiers'
  heads (an icon and "+8%"; Settings BAND BUFF MARKS, default SELECTED). **BandSound**: the nearest band in step, or
  up to 3 lone musicians each out of step. Old saves' band units load as their musicians, standing together.
- So, below: the band unit, its recruit / join walk (0.36.0) and the one-band-many-instruments rules are history.

## What changed in 0.36.0 (job band-v2): read docs/band_v2.md

- **The Fifer and the Piper are UNITS, not research**: trained at the Armoury one at a time (Fifer 60 gold + 10 powder,
  Piper 75 gold, 20 s), each walks to a band and JOINS it, as an Officer walks to his horse (one of each a band; RECRUIT
  FIFER / PIPER on the band's card sends one to that band; right-click or JOIN BAND; by default the nearest band that
  wants him; none: he waits). The band costs 50 flat (no more "+25 a musician"). Old saves' research still fills every
  band. The computer trains them after its band.
- **The three stand side by side** in a row (MarchingBand.SPOT), the shadow, selection ring and click as wide as the row.
- **The sound is BandSound** (scripts/band_sound.gd): one band heard at a time, on one shared clock, the always-on
  playing quiet, the solo clear, the game music ducked a little. The band's music itself is still the 0.33.0 loops (a new
  music job will replace them: the brief is in docs/band_v2.md; CC0 samples in art/audio_src/band/).
- So, below: the 0.33.0 research, its price rule and the "every band gets the musician" rule are history.

## What changed in 0.33.0 (job marching-band)

- **No experiment switch.** Settings' MARCHING BAND (experiment) toggle, `Settings.marching_band`, `Defs.marching_band`
  and its gating (the Barracks' card, the AI hooks, `MarchingBand.on`) are gone. The band is always the Crown's. An old
  saved setup, replay header or online cfg that carries `"marching_band"` still loads: the key is simply ignored
  (main.gd). Old saves with a band in them load (their `"h"`/`"he"`, a musician being taken on, are dropped; the
  research decides the musicians now).
- **Trained at the ARMOURY** (Defs.BUILDINGS armoury "trains": ["band"]; the Barracks no longer trains it): 15 s, 1
  supply. **A new band is a DRUMMER**: 60 + 15 = **75 health**, the drums playing from the start. The bandmaster-alone
  stage is gone.
- **The FIFER and the PIPER are Armoury research** (Defs.RESEARCH `band_fife`, `band_pipes`), in ANY order:

  | research | price | time | brings |
  |---|---|---|---|
  | Fifer | 60 gold + 10 powder | 25 s | the fife: reload speed |
  | Piper | 75 gold | 25 s | the bagpipes: melee damage |

  (The old ADD prices, 60+10 and 75; the time is research-like, the old 10-12 s join was for one band.) Research is
  permanent and applies to **every** band of the player: bands on the field gain the musician the moment it finishes
  (`MarchingBand.sync`, every band tick: +15 health each, "+ Fifer" over it), and new bands come out with every musician
  researched (`sync` in Unit._ready).
- **Several bands allowed** (like cannons): the one-per-player limit is gone. **Each band's price grows with the
  musicians researched: 50 gold + 25 a musician** (50, 75, 100; `Defs.MARCHING_BAND "per_musician"`,
  `Game.unit_price` -> `MarchingBand.price_extra`). The train button's corner and its tooltip show the real price, and
  the tooltip says who comes out in it ("Comes out with: Drummer, Fifer. Each musician researched at the Armoury adds 25
  gold to its price."). A band queued at 100 and cancelled is paid back 100 (the kit's `"bandx"`).
- **Rings don't stack**: each covered unit keeps one entry per band that reaches it (`Unit.band_src`, its band's
  multipliers and how long they last) and takes, stat by stat, the strongest (`MarchingBand.mix`). This also FIXES a POC
  bug: a soldier who stayed in the ring kept a solo's +30% after the solo ended (the old code took the max of the old and
  new buff on every pass while the buff hadn't lapsed, so it never came down).
- **The buffs (the owner's numbers)**: every instrument always gives **+5%** (its secondary), and **+30% during its
  SOLO** (DRUMS movement speed, PIPES melee damage (any blow under 60 px reach: bayonets, sabres), FIFE reload/cooldown
  speed (muskets, the Dragoon on foot, cannons, mortars, and now the **Officer's pistol** (`Unit._pistol_reload`, Defs.PISTOL
  "reload") which the POC missed). A solo lasts **8 s**, each instrument has its **own 45 s cooldown** (from the solo's
  start), no energy. **One solo at a time per band**; a second band may solo at the same time. Kept: the 5-tile ring, the
  0.6 s linger, the telegraph (the ring turns the leading instrument's colour: drums red, pipes green, fife blue), the
  escort/follow behaviour, the music, save/load, the online snapshot and the replay field.
- **CROWN AMMUNITION (0.32.0)**: the band needs no powder (its price is gold; the Fifer research keeps 10 powder). The fife
  only speeds men who actually have shots: a firearm man with an empty pouch (`_k_ammo` and `ammo_shots() == 0`) gets no
  reload buff (his cooldown runs as anyone's); his bayonet still gets the pipes'.
- **The card**: three SOLO buttons (DRUMS / PIPES / FIFE SOLO); the Fifer's and Piper's show locked ("Research the Fifer at
  the Armoury first.") until researched. With several bands selected a SOLO plays on the first selected band free to play
  it. The ADD buttons are gone (`Unit.band_hire` is kept as a no-op so an old replay's or old guest's command finds it).
- **The Mist Toad (fairness)**: FOG and MIASMA are research at the Venom Sire (the Dilophosaurus, the Toad's father):
  `nb_fog` "Fog Bank" (50 food + 10 spoils, 20 s) and `nb_miasma` "Miasma Cloud" (60 + 15, 25 s), both at the Mother's
  stage 3, as the Toad itself. TONGUE stays free. `Game.spell_problem` refuses them before ("Research Fog Bank at the
  Venom Sire first."), the card buttons show them locked, the Brood computer researches FOG then MIASMA as soon as it has a
  Toad (ai_brood_new.gd `_nb_research`, put first in its list, even while another Sire researches) and its Toads only
  cast FOG once it is researched (AI._toad).
- Help (main.gd HELP: a Marching Band paragraph after the Armoury's, a Toad research line), the unit's, the Armoury's and
  the researches' about texts, tooltips, i18n en/pt/es (tools/i18n/56_marching_band_unit.txt), patch notes.

## The art (tools/import_band.py)

The owner's ChatGPT sheets (art/redraws/band_*_walk_se_chatgpt.png): 4 marching-and-playing frames, south-east, navy
ground. `tools/import_band.py` keys the navy, finds the 4 figures, scales each sheet so hat-top to soles is 34 game px
(the drumsticks, drones and flag above it don't count), centres each frame on the coat, snaps the reds below the face to
the team key reds (so the band wears its side's colour, like a Musketeer) and writes walk / idle / death strips into
assets/units/band (the Drummer), band_fifer, band_piper (cell 44 x 46, soles on row 43) and `scripts/band_art.gd`
(BandArt.ART, merged into ArtData.UNITS beside RebelArt's; tools/import_art.py writes the same merge line).

- **The fifer**: of the two options, **B** (band_fifer_walk_se_b_chatgpt.png). Measured on the sheets
  (`python3 tools/import_band.py --compare-fifers`): hat-to-soles 301-302 sheet px for both (the drummer 304-311, the
  piper 311-314), but the stride (the feet's spread in the bottom rows) is 149-160 px in all four frames of B (the
  drummer 130-144, the piper 131-152), while A's feet come together in three of its four frames (50-70 px): A shuffles
  next to the other two, B marches with them.
- **A group that grows** (`MarchingBand.group_look`, from Unit._animate): the Drummer is the unit's own sprite and leads in
  the middle; the Fifer and the Piper are child sprites of it, since 0.36.0 SIDE BY SIDE with him in one row
  (MarchingBand.SPOT, 22 px apart in the SE picture's space: the Fifer on his right, the Piper on his left; before, they
  were tucked behind his shoulders), each only once he has joined. They take his pose and view, one and two frames out of step so the three don't
  march as one, and mirror with him.
- **Every view uses the SE art** until the others are drawn (Unit falls back to the nearest drawn view; the west views are
  the east mirrored): logged in docs/art_style_inconsistency.md ("The Marching Band") and docs/art_redraw_queue.md (item
  43: S, E, NE, N per musician, one direction per ChatGPT request). The importer picks up
  art/redraws/band_<drummer|fifer|piper>_walk_<dir>_chatgpt.png by itself when they arrive.
- **Idle** = the walk frames played at the idle pace (2 a second: marking time, still playing). **Death** = the first frame
  tipped over in three steps (code-made, logged).
- The tinted-Officer stand-in (Defs.TEMP_ART "band") and the code-drawn instruments are gone. Kept: the code-drawn notes
  over the band during a solo (now only in a solo, over the leading musician), and the leading musician **bobs 2 px and
  stands 12% bigger** during his solo.
- Pictures: docs/shots/marching_band/ (tools/shot_marching_band.gd, 1200 px JPEGs).

## The computer

- **AI._band** (in the produce step, before research and soldiers): the Crown computer trains a band at an Armoury once
  its army has **10** fighting units (`BAND_ARMY`; workers, horses, bands not counted) and a **second at 30**
  (`BAND_ARMY2`). It researches the musicians: the **Fifer first** when half or more of its army shoots (muskets, Dragoons,
  guns), else the Piper first; Easy never takes the Piper. **It saves for them**: while a band is wanted and not yet
  affordable, or a musician's research is next and not yet affordable, that price is kept back from the soldiers for this
  think (the gold is put back after `_produce`, like the hall plan's `_hide_kept`), so the research comes even when every
  coin goes into men (the POC's computer never could afford a musician). Not with an enemy in its base, nor while the
  hall plan keeps its gold. The plan notes say "trains a Marching Band (12 soldiers)" / "researches the band's Fifer".
  The shared research loop (`AI._research`) skips the band's research.
- **MarchingBand.ai_tick** (every think, every band): **behind the line**: each band walks to a spot 70 px behind the
  middle of its nearest group of soldiers, away from the nearest enemy (its army's attack-moves are overridden: the band
  never walks in front); with no enemy near it keeps with them; far from all soldiers it follows the nearest.
  **Solos**: PIPES when 3+ ringed soldiers fight and half or more of them are in melee; FIFE when 3+ are shooting (aiming
  or reloading at a target); DRUMS when 3+ are chasing a target that walks away (catching a retreat) or when the enemies
  round the band outnumber its soldiers by 3 and its men are falling back (escaping a lost fight). If the wanted one is on
  cooldown it plays the other fighting one when that fits.

## THE TESTS AND THE MATCHES

- `tools/test_marching_band.gd` (62 checks, all pass): no switch; the Barracks refuses a band, the Armoury trains it;
  50 gold with no musician, two queued at once (no limit), paid back; a band out of the Armoury is a Drummer at 75/75
  playing +5% drums, no fife or pipes solo; the Piper researched FIRST at the Armoury's queue joins the band on the field
  (90 health) and the price goes to 75; then the Fifer (105 health, price 100, paid back 100 when cancelled); a new band
  comes out with all three; +5% on every stat with no solo; the ring (in, out, worker, enemy, itself); FIFE SOLO: one solo
  at a time, +30% reaches the ring while the others stay at +5%, a musket reloads 30% faster (by the game clock), **the
  Officer's pistol reloads 30% faster**, a musketeer with no shots isn't sped (against one outside the ring, also dry);
  **two bands soloing at once** (fife and drums), **no stacking** (1.30 / 1.05 / 1.30, the strongest per stat); outside the
  rings the reload is normal; the solos end after 8 s and **the ring falls back to +5%** (the POC's lingering-solo bug);
  the cooldown; PIPES SOLO +30% on a bayonet thrust (vs +5%); the drums' +5% and DRUM SOLO +30% on the walk; the drawn
  group (the Drummer's own strip, the Fifer and the Piper as visible child sprites); a save (state, research, 105 health);
  an old experiment save (the bandmaster alone, a Piper joining) loads and fills in from the research; the online snapshot
  and a replay's field list; the command funnel (band_solo, and band_hire kept); the buff gone 0.6 s after the band dies;
  an old cfg key changes nothing.
- `tools/test_toad_research.gd` (new, 15 checks, all pass): FOG and MIASMA research at the Venom Sire, stage 3, cheap; no
  research for TONGUE; a Toad with energy is refused FOG and MIASMA before, can after (each its own); the Brood computer's
  research list takes them once it has a Toad.
- Also run and passing: test_files, test_i18n (0 of 411 data texts untranslated in pt and es), test_settings_tabs (the
  toggle gone), test_crown_ammo (0 failures), test_replay (ALL OK). ("Aborted" at exit is the usual headless exit.)
- Pictures (tools/shot_marching_band.gd, docs/shots/marching_band/): `0_drummer_band_card` (a new band: the Drummer alone,
  75/75, DRUMS SOLO live, PIPES and FIFE locked), `1_full_band_ring_and_card` (Drummer, Fifer, Piper behind a Musketeer
  line, its ring), `2_fife_solo_volleys` (the ring blue), `3_pipe_solo_bayonets` (green), `4_two_bands_one_solo` (two
  full bands, one in its DRUM SOLO: the red ring).

### Whole matches (tools/test_marching_band_match.gd, Hard Crown computer, Balanced)

| map, seed | against | how it went | the band |
|---|---|---|---|
| ashford_crossing 4242 | Hard Brood | Crown lost at 10:20 (army at most 17) | none: no 10 soldiers with an Armoury standing |
| ashford_crossing 4242 | Hard Clockwork | 12:00 not over; the Crown army never over 7 | none |
| greenhold 4242 | Hard Brood | Crown lost at 10:58 (13 soldiers at 8-9 min) | none |
| greenhold 4242 | Hard Clockwork | Crown lost at 15:51 (army at most 5) | none |
| red_coast 7 | Hard Brood | Crown lost at 11:04 (army at most 12) | none |
| red_coast 7 | **Hard Clockwork** | 20:00 not over; army 16-21 from 9:00 | **band at 10:22 (Drummer), Fifer 13:17, Piper 13:57 (Fifer first: a musket army; the Piper 40 s later, saved for); solos: DRUMS 11:48 (13 soldiers in the ring), FIFE 15:28 (6), DRUMS 15:36 (2, falling back); never lost** |
| ashford_crossing 4242 | Normal Brood | Crown lost at 11:19 | none |

The band works in a match (trained, both musicians researched with the gold kept back, behind the line, solos one at a
time, never lost), but **the Hard Crown computer rarely reaches 10 soldiers with an Armoury standing**: against the Brood
it is beaten at 10-11 minutes in every game, against the Clockwork it mostly trades its army away. This is not the band:
the same ashford match on main (0.32.1, the experiment off) ended the same way at 10:14. So the band shows up in the
computer's mid game only when that mid game happens (here 1 game in 7).

## Claude's choices for the owner

- **Research prices and times**: Fifer 60 gold + 10 powder, Piper 75 gold (the old ADD prices), both 25 s (research-like;
  the old joins were 10-12 s for one band). Toad: Fog Bank 50 food + 10 spoils, 20 s; Miasma Cloud 60 + 15, 25 s; both at
  the Mother's stage 3 (as the Toad). Names: the Toad research is "Fog Bank" / "Miasma Cloud" (the bare "Miasma" reads the
  same in pt/es and test_i18n counts it untranslated).
- **The band unit**: 50 gold, 15 s, 1 supply, 60 + 15 a musician (75, 90, 105), radius 12 (was 10, for the group).
- **Rings don't stack, per stat** (the owner's rule), done per band entry on each covered unit so a solo that ends stops
  counting at the band's next pass (0.25 s).
- **The fife and dry men**: a firearm man with no shots gets no reload buff (his cooldown runs normally); his bayonet still
  gets the pipes. A gun is never "dry" in that check unless its own ammunition is 0 (Defs.AMMO kinds).
- **Several bands selected**: one press of a SOLO plays it on the first selected band free to (so a second press plays it
  on the next); Ctrl doesn't play it on all (the owner may want that).
- **The computer**: Fifer first when half or more of its fighting units shoot (muskets, Dragoons, guns), Piper first
  otherwise; Easy never researches the Piper. It keeps the price of the next band/musician back from the soldiers (only
  with a built Armoury for the first band). The band is held 70 px behind the middle of its nearest soldiers, away from
  the nearest enemy. It does NOT make the Crown build its Armoury earlier for the band (the plans' build orders are the
  owner's coached ones): see the open question.
- **The art**: fifer option B (its stride matches); the group's places (Fifer behind the Drummer's left shoulder, Piper
  behind his right) are set for the SE view; idle = the walk slowed; death = code-tipped frames; the portrait and button
  icons are still the 0.23 PIL ones (now also the research buttons' icons).
- **Old saves**: a 0.23 band in a save loads; a musician it was taking on is dropped (the research decides); the band ADD
  order (`band_hire`) is a no-op kept for old replays and guests. The old experiment's i18n strings (tools/i18n/
  33_marching_band.txt) are kept (unused).
- **Git**: origin had an old `marching-band` branch from an older, rewritten history (the 0.23 experiment, already in
  main). A force-push was refused, so it is kept under this branch by an "ours" merge (commit c0538abe: nothing of it
  changes any file). **Merge this branch into main with a SQUASH** (or merge only from ca162e25 on) so the old history
  isn't brought into main.

## Open questions for the owner

1. **The Crown computer's mid game**: should a computer that wants a band (10+ soldiers) build its Armoury for it (it comes
   at 20-42 labourers in the plans), or keep the plans as coached? In 7 matches the band appeared once, because the Crown
   rarely got to 10 soldiers with an Armoury (it loses to the Brood at 10-11 min with or without this job).
2. **Price and research**: 50 + 25 a musician, the musicians 60+10 and 75 at 25 s: cheap enough for a second band?
3. **Ctrl + SOLO** on several selected bands: play the solo on all of them at once?
4. **Toad research numbers**: 50/10 and 60/15 at the Venom Sire, 20-25 s. And should FOG and MIASMA be one research?
5. **The art still to draw** (docs/art_redraw_queue.md item 43): S, E, NE, N marching for each of the three musicians, and a
   death row; a real band portrait and solo icons; real bagpipes audio.
6. The band could be shown on the Armoury's rally / research buttons' tooltips with its live price only; is the "Comes out
   with" note enough?

# The 0.23.0 experiment (history: what the proof of concept was and measured)

## How it plays

- **Trained at the Barracks** (the simplest place: no new building): 50 gold, 15 s, 1 supply. **One per player**: a second
  is refused while one is on the field or waiting in any Barracks queue ("Only one Marching Band per player."). Without the
  experiment the Barracks doesn't show it and refuses it.
- **The bandmaster alone** at first: 60 health, no armour, unarmed, a Musketeer's pace (62).
- **ADD DRUMMER / ADD PIPER / ADD FIFER** on its card (like a refit: a price and a short time, anywhere, one at a time, each
  once). Each musician adds his instrument and 15 health (105 with all three).

| musician | price | time | instrument | buff | secondary | SOLO (8 s) |
|---|---|---|---|---|---|---|
| Drummer | 50 gold | 8 s | Drums | movement speed | +5% | +25% |
| Piper | 75 gold | 12 s | Pipes | melee damage (bayonets, sabres, any blow under 60 px reach) | +7% | +35% |
| Fifer | 60 gold + 10 powder | 10 s | Fife | reload speed (the cooldown runs faster: muskets, the Dragoon on foot, cannons, mortars) | +5% | +30% |

- **The ring**: everything of its side (and allies) within **5 tiles** (160 px) that fights is covered: soldiers, riders,
  guns; not workers, horses, wagons, medics, flyers or the band itself. A covered unit keeps the buff 0.6 s after it leaves
  the ring (no flicker at the edge). Two bands' rings (allies) don't add: each stat takes the stronger.
- **SOLOS** (DRUMS SOLO, PIPES SOLO, FIFE SOLO, once that musician is in): the instrument leads for **8 s** with its full
  buff, then **45 s** before IT may solo again (counted from the solo's start). **One solo at a time.** The others keep
  playing their secondary share meanwhile.
- **Telegraph** (design_principles 1): the ring is drawn on the ground for everyone who sees the band (the enemy too):
  gold, with ticks in its instruments' colours; in a solo it turns the leading instrument's colour (drums red, pipes green,
  fife blue), thickens and pulses, the leading instrument is drawn bigger and notes rise over the band. Its music plays
  near it (assets/audio/band/: a phrase every 4 s of each instrument it has, the lead louder).
- **Escort**: with no orders it falls in behind the nearest of its moving soldiers within 7 tiles (`order follow`, 56 px
  behind); right-click one of your units with it to follow that one. HOLD keeps it where it is.
- **The computer** (only with the experiment on): trains a band once its army is 6 strong, takes on musicians as gold
  allows (drums, fife, pipes), and plays the FIFE solo when 3+ of its soldiers in the ring are fighting, the PIPES when half
  of them are on the bayonet (MarchingBand.ai_tick).

Card info line: "Plays: Drums, Pipes, Fife · 5 tiles · Fife SOLO: 6 s · a Piper joins in 4 s".

## Code

- `scripts/marching_band.gd` (MarchingBand): the state, the tick (musicians joining, solos ending, the ring's pulse every
  0.25 s, the escort), the buffs, the orders, the AI's use, drawing (ring, instruments, notes), the card and its tooltips,
  save/load of the state.
- The band's state is one field on the unit, `Unit.band` = {"m": instruments, "h"/"he": a musician joining and when,
  "s"/"se": the solo and when it ends, "cd": {instrument: when it may solo again}}. Times are the GAME CLOCK, so the state
  changes only when something happens (cheap to send). It is saved (SaveGame "band"), sent online and recorded in replays
  (NetSnapshot.UNIT_PROPS "band": replays are the online snapshots, ReplayRecorder.lists() names it).
- A covered unit's buff: `Unit.band_mul` (speed, melee, reload) until `Unit.band_until`. Speed: Unit tick after the base
  speed; reload: the cooldown runs down `band_mul.z` times faster (not on the bayonet); melee: `_strike` and `_blow_damage`
  for the bayonet, sabres and any blow under 60 px reach.
- Orders: `Unit.band_hire(ins)`, `Unit.band_solo(ins)` (NetCommands.ENTITY: an online guest's go to the host).
- `Defs.MARCHING_BAND` (every number), `Defs.UNITS["band"]`, `Defs.TEMP_ART["band"]`, the Barracks' "trains" (hidden by
  `Defs.train_keys` while the experiment is off), `Game.can_train` (one band; a stand-in's sprites count as art).
- Settings `marching_band`, Main.start (cfg), the Settings toggle; the AI hook in AI._produce and AI._abilities.
- Art: code-drawn stand-ins, logged in docs/art_style_inconsistency.md ("The Marching Band"): the Officer's sprites tinted
  with a plume, the instruments and notes drawn in code, the icons (`tools/make_band_icons.py`), the bagpipes synthesised
  (`tools/audio/make_band_sounds.py`: the drums are the owner's snare recordings, the fife the real fife notes).

Tests: `tools/test_marching_band.gd` (off by default; one band only, also in a queue; musicians paid, timed, once each, +15
health; secondaries; the area: in, out, workers, enemies, the band itself; solos: needs its instrument, one at a time, the
cooldown; the reload +30% by the clock, the bayonet +35%/+7%, the walk +25%; a save; the online snapshot and a replay's
field list; the command funnel; the buff gone 0.6 s after the band dies) and `tools/test_marching_band_match.gd` (a Hard
Crown computer with the band in a whole match). Also passing: test_files, test_i18n, test_replay.

## The numbers: first guesses, and why

- **Ring 5 tiles**: a Musketeer reaches 190 px (6 tiles); a band 2-3 tiles behind the second rank covers a 15-20 man line
  (a two-rank line of 16 is ~190 px wide) but not a whole spread army. Coverage is the brake on a fixed-price multiplier:
  however big the army, one ring holds about 15-25 men (design_principles 2: pro-snowball upgrades need a brake).
- **Solo 8 s**: about one exchange of volleys (a Musketeer's cycle is 3.55 s: two to three shots each). **Cooldown 45 s**:
  about one fight per solo; the three instruments' solos can be chained (24 s of solos, then nothing for ~20 s), a choice
  the player makes.
- **Solo strength ~ one Armoury tier inside the solo**: the fife's +30% reload is +22% fire rate (a Flintlock's +19%, a
  Caplock's +31%), the pipes' +35% is the Socket Bayonet's +33% damage again, the drums' +25% lets Musketeers (62 -> 77.5)
  outpace Clock Soldiers (68) for 8 s.
- **Secondaries ~ a fifth of the solo** (+5 / +7 / +5%): felt, not decisive.
- **Prices**: band 50, musicians 50 / 75 / 60+10 = 245 gold + 10 powder in all (3.5 Musketeers), about a lock line's
  research. The Piper is dearest (the pipes cover the Crown's weak spot); the Fifer pays powder (the drill is the powder drill).
- **Health 60 + 15 a musician**: a Raptor pack or a cannon shot kills it in seconds if it is reached; the risk is the point.

## Measured: the fights

Harness: `tools/study_armoury_band.gd` groups MB and MD (`tools/study_armoury_band.sh`; Raptor rows have 10 seeds: a second
run with `seed0:4 seeds:6`). 15 Musketeers (Matchlock + Bayonet, the mid kit) in two ranks on HOLD, the band 60 px behind
the second rank on HOLD, against an enemy that attack-moves in, sized so the fight WITHOUT a band is close (Raptors 1200,
Clock Soldiers 2000, attacking Musketeers 900). Solos as a player would play them: FIFE at the first shot, PIPES when the
enemy reaches the line, "both" = fife first, pipes when the fife's is over and the enemy is at the line. MARGIN: what is
left of the Crown's SOLDIERS minus what is left of the enemy (resources by health; the band's own value, "kept", is not in
it); (Δ) against "none". Raw fights: docs/armoury_study_data/MB_*.jsonl, MD_*.jsonl.

| config | men | vs Raptors (1200): won · lost/killed · margin ±sd (Δ) | vs Clock Soldiers (2000) | vs Musketeers attacking (900) |
|---|---|---|---|---|
| MB_none: no band | 15 | 0/10 · 1215/692 · -397 ±157 | 2/4 · 952/1855 · +44 ±331 | 0/4 · 1215/455 · -384 ±47 |
| MB_sec: band, secondaries only | 15 | 1/10 · 1207/840 · -274 ±161 (+124) | 1/4 · 1094/1592 · -212 ±317 (-256) | 0/4 · 1215/455 · -344 ±50 (+40) |
| MB_fife: FIFE SOLO | 15 | 3/10 · 1126/892 · -194 ±234 (+203) | 3/4 · 911/1890 · +84 ±361 (+40) | 1/4 · 1114/682 · -112 ±219 (**+272**) |
| MB_pipes: PIPES SOLO | 15 | 2/10 · 1110/792 · -236 ±314 (+161) | 4/4 · 526/2030 · +518 ±130 (**+475**) | 0/4 · 1215/525 · -329 ±34 (+55) |
| MB_both: fife then pipes | 15 | 2/10 · 1118/752 · -307 ±332 (+90) | 4/4 · 729/2030 · +311 ±80 (+267) | 0/4 · 1215/542 · -262 ±86 (+122) |
| MB_cap_none: Caplock, no band | 15 | 2/10 · 1264/850 · -238 ±233 | 3/4 · 1068/1942 · +144 ±217 | 0/4 · 1335/542 · -242 ±58 |
| MB_cap_fife: Caplock + FIFE SOLO | 15 | 3/10 · 1210/912 · -144 ±280 (+94) | 3/4 · 912/1855 · +150 ±407 (+7) | 0/4 · 1335/648 · -182 ±147 (+59) |
| MB_eq_none: 1200 of men, no band | 15 | 4/10 · 1126/935 · -157 ±242 | 1/4 · 1114/1680 · -184 ±299 | 0/4 · 1215/508 · -322 ±77 |
| MB_eq_both: the band paid out of 1200 (12 men), both solos | 12 | 0/10 · 972/448 · -652 ±120 (-495) | 0/4 · 972/928 · -850 ±204 (-666) | 0/4 · 972/332 · -456 ±123 (-135) |
| MD_none: 15 attack 900 of holding Musketeers | 15 | | | 4/4 · 263/910 · +812 ±38 |
| MD_sec | 15 | | | +815 ±24 (+3) |
| MD_drums: DRUM SOLO as they set off | 15 | | | +809 ±88 (-3) |
| MD_drums_fife: drums, then the fife at the first shot | 15 | | | +833 ±25 (+20) |

In every one of these fights **the band never died**: standing behind the line, the enemy (who goes for the nearest) reached
it only after the line was gone. (MB_none and MB_eq_none are the same fight run twice: their gap, 240 against Raptors, is
the noise there.)

What it says:
- **A timed solo is worth about an Armoury lock tier in that fight.** The FIFE SOLO gains +272 against the musket line (the
  cleanest measure) and +203 against Raptors; the Caplock (over the Matchlock: MB_cap_none - MB_none) gains +142 and +159.
  The PIPES SOLO is the big one when the enemy reaches the line: +475 against Clock Soldiers (bayonet fight), little against
  muskets (nobody closes).
- **The secondaries alone are within the noise** (+40 against muskets, +124 / -256 elsewhere): felt by a player, not
  decisive. As intended.
- **Stacking with the Caplock adds less**: Caplock + fife +59 / +94 over the Caplock line, against +272 / +203 over the
  Matchlock line (diminishing: the aim and strike phases don't speed up, and a faster line kills before the fife's 8 s run
  out).
- **The drums do nothing in a straight fight** (-3 / +20 walking 520 px into a musket line: under fire ~0.6 s less). Their
  worth is in moving: catching, retreating, reinforcing, out-walking Clock Soldiers for 8 s; none of which this harness
  plays.
- **Paid out of a 1200 army, the band loses**: 12 men + band vs 15 men: -135 to -666. Its 245 is 3 Musketeers, and one
  fight's solo (+200..+475) is worth less than three more men there. It pays back only by **surviving several fights**
  (it never died here: each fight it survives is another solo) and by covering a **bigger army** (it covers ~15-25 men
  whatever the army's size: at 25 men in the ring a solo is worth ~1.7x what it is at 15).

## Measured: in whole matches (the computer playing it)

`tools/test_marching_band_match.gd` (Hard Crown computer, experiment on, 12 minutes):

Cut short (the owner's call): one 12-minute match against a Hard Brood (ashford_crossing, seed 4242). The Crown computer
trained its band at 11:44 (it hovered at 0-110 gold all match and reached 6+ soldiers late), but never had the 50+ gold
spare for a musician, so it played no solo. **Open:** the computer must SAVE for its musicians (e.g. hold production while
the band lacks one and the army is 10+), then the band's use in AI matches can be measured.

## THE OWNER'S QUESTION: strongest or minor?

> Should the band's buffs be the STRONGEST (it is a unit that can die: risky) or MINOR (because of that)?

Value = strength x uptime x units covered, against the Armoury's permanent, global upgrades:

| | strength | uptime | covered | value (relative, "+% fire rate x share of the time x men") | risk | price |
|---|---|---|---|---|---|---|
| Caplock (Armoury) | +31% fire rate | 100% | every refitted man, everywhere | 31 x 1.0 x ALL | none | 225 + 75 research, 16 a man |
| FIFE SOLO | +22% fire rate | 8 s in 45 s = 18% of the clock, but ~100% of the 8 decisive seconds of a fight if timed | the ring: 15-25 men | 22 x 0.18 x ring ≈ 4 x ring (per clock); ≈ 22 x ring (per fight) | the band dies: all 245 lost | 245 + 10 for the band |
| fife secondary | +4% fire rate | 100% while alive | the ring | 4 x 1.0 x ring | same | (same band) |

Two facts from the fights decide it:
1. **Per fight, a timed solo already equals an Armoury tier** (+200..+475 against the Caplock's +140..+160 in the same
   fights), while **per clock, it is a fifth of one** (18% uptime) and covers one ring, not the army.
2. **The band is not worth its price in one fight** (-135 to -666 paid out of the army); it earns its keep only by living
   through several fights and by covering a big army.

So, **neither the strongest nor minor: strong SHORT solos with long cooldowns, and MINOR secondaries** (the numbers as they
are). Why:
- If the buffs were the STRONGEST (big permanent auras: say +30% always on), the band would beat the whole lock line at a
  third of its price, stack with it to +57% fire rate and more, and be a must-build in every army: the Armoury's choices
  stop mattering, and one cheap unit snowballs the bigger army (design_principles 2, 4). Its risk would not balance it:
  in these fights nothing even reached it.
- If they were MINOR (secondaries only), it would not change a fight (within the noise here) and would never pay back its
  245 or its risk: nobody would train it.
- Strong-short-on-cooldown makes it a SKILL unit: the player chooses WHICH buff and WHEN (fife for the volleys, pipes when
  the Raptors reach the line, drums to catch or to run), the enemy sees it coming (the ring changes colour, the music
  changes) and can answer by killing the band or by waiting the 8 s out (design_principles 1: telegraph, counterplay). The
  45 s cooldown keeps it to about one swing a fight; the small secondaries give it a reason to stay alive between fights.
- Its risk is real only if the enemy can reach it: Raptors that run round the line, Horsemen, Swifts and Springers'
  jumps, a mortar or cannon shell. That is the right kind of counterplay (focus the musicians, as the owner's Jacks focus
  the repairers), so its health stays low (60 + 15 a musician) on purpose.

**Tuning advice for playtests** (not done): if it feels like a must-build, shorten the solos to 6 s or lengthen the
cooldown to 60 s, not the strength; if nobody builds it, make the band and the Drummer cheaper (it loses most when paid out
of a small army). With the Armoury's P1 (docs/armoury_study.md: the locks give accuracy, the fife owns reload) the fife solo
could rise to +35%.

## What is left (not in the POC)

- The computer's use: it trains the band but doesn't save gold for musicians (see above); no measured AI matches.

- Real art (a drum major and the musicians as figures; real bagpipes audio).
- The band's music is a Sfx "din" sound (tier 1): in a very big fight the sound cap may skip a phrase.
- No hotkeys of their own (the card gives the letters).
- The Officer's pistol reload (Defs.PISTOL "reload") is not sped up by the fife.
- The idea bucket's other instruments (bugle: cavalry charge recovery; psalm with a Missionary: slow heal; drum roll:
  armour while standing) are not in.
- Online lobby and the map editor need nothing; the replay viewer shows the ring and the card's line from the recorded field.
