# The Marching Band, version 2 (job band-v2, 0.36.0)

The owner's words (2026-11-13 23:46-23:49), and what was done with each. The older write-ups stay in
docs/marching_band.md (0.33.0 and the 0.23.0 experiment); this page says what changed.

## 1. The layout: side by side

"They are too bunched up, put the sprites side by side instead of diagonally bunched up so we can see the musicians
together."

- The Drummer is still the unit's own sprite; the Fifer and the Piper are still child sprites of his (they take his pose,
  his frame (one and two frames out of step) and his mirror). They now stand **in one row with him**:
  `MarchingBand.SPOT` = Fifer 22 px to his right, Piper 22 px to his left (in the south-east picture's space; mirrored
  with the band when it faces west). Each figure is about 20 px wide in its 44 px cell, so 22 px apart no two bodies
  overlap (checked in tools/test_marching_band.gd: same height, at least 20 px from the middle each, 44 px apart).
- The band's **radius** is 16 (was 12), its **shadow and green selection ring** are stretched to cover the whole row
  (`MarchingBand.ring_span`, drawn in Unit._draw), and a **click** anywhere along the row picks it (`Game.entity_at`: the
  band is looked for 40 px either side instead of 26).
- Only the south-east view is drawn (as before), so the row reads best from the front; facing north it still shows its
  south-east side.

Pictures (tools/shot_marching_band.gd, docs/shots/marching_band/):

| | |
|---|---|
| `1b_side_by_side_close.jpg` | the full band, the three side by side, selected (the ring under all three) |
| `1c_side_by_side_walking_west.jpg` | walking west: the row mirrored |
| `1a_fifer_walks_to_join.jpg` | a Fifer (selected: JOIN BAND on his card) and a Piper walking over to a Drummer |
| `0_drummer_band_card.jpg` | a new band: the Drummer alone; its card with RECRUIT FIFER / RECRUIT PIPER |
| `1_full_band_ring_and_card.jpg`, `2_...`, `3_...`, `4_...` | the band behind a line, the fife and pipe solos, two bands |

## 2. The new structure: musicians are recruited and walk over

"We recruit a band that starts with a drummer, and we can then recruit the next musician that will spawn in the
[training building] and go to the band walking to join it, like an officer goes to a horse."

- **Where**: the owner wrote "foundry", but the band has been trained at the **Armoury** since 0.33.0 and nothing in the
  code ties it to the Foundry, so the Armoury it stays: it trains the band, the Fifer and the Piper (Defs.BUILDINGS
  armoury "trains": band, band_fifer, band_piper). Say if you want them at the Foundry.
- **The research is gone** (Defs.RESEARCH band_fife / band_pipes). The **Fifer** (`band_fifer`: 60 gold + 10 powder, 20 s)
  and the **Piper** (`band_piper`: 75 gold, 20 s) are UNITS (the old research prices, 20 s instead of 25). 30 health,
  unarmed, **no supply** of their own (the band has its 1).
- **They walk over and join**, the way an Officer walks to his horse (the same pattern as Unit.cmd_mount / _mount_run: an
  order "join" with the band as its target; `MarchingBand.start_join`, `join_run`). At the band he is taken off the field
  (`Game.consume_unit`, as the horse is) and the band gains his instrument, its +5%, its SOLO and +15 health (as hale as he
  was). "+ Fifer" floats over the band. If he was selected, the band is selected instead.
- **One of each a band**: a band "wants" a musician only while it has none and none is walking to it
  (`MarchingBand.wants`).
- **Which band**:
  - **RECRUIT FIFER / RECRUIT PIPER** on the band's card (`Unit.band_recruit`, through the online funnel): one is queued at
    the nearest Armoury that can train him (the shortest queue counts), paid now, and his queue entry carries the band's
    number (`Unit.band["id"]`, saved); when he comes out he walks to THAT band, even past a nearer one. Greyed with the
    reason when the band has one, one is on his way or queued for it, or there is no Armoury.
  - **JOIN**: right-click a band with Fifers or Pipers selected (`Game.smart_command`, and its online preview
    `_smart_choice`), or **JOIN BAND** on the musician's card (the nearest band that wants him).
  - **By default** (trained plainly at the Armoury, or left idle): the nearest band of his side that wants him
    (`MarchingBand.pick_band`; an idle musician looks once a second, `musician_tick`).
  - **No band wants him**: he goes to the Armoury's rally point (or stays by it) and waits; when a band wants one, he goes.
  - **His band dies on the way**: he stops and goes to another that wants him, or waits.
- **A band that dies drops nothing**: its musicians die with it.
- **The price**: the band costs 50, flat. The 0.33.0 rule "every new band costs 25 more per researched musician" is gone
  (each musician is paid for).
- **Old saves and replays**: an old save's or replay's research flag (band_fife / band_pipes) still gives EVERY band of
  that side the musician, as before (`MarchingBand.available`); a research still in an old save's queue becomes the
  musician (`MarchingBand.OLD_QUEUE`, SaveGame.restore). A band saved without a number gets one.
- **The computer** (`AI._band`): it trains its band as before (army 10+, a second at 30+), then for each band that wants a
  musician and has none walking or queued, trains one at the Armoury (the Fifer first in a musket army, else the Piper;
  Easy never the Piper), keeping its price back from the soldiers like the band's. Its musicians always go to a band that
  wants them, whatever its army orders them to do (`musician_tick`). `MarchingBand.ai_tick` (behind the line, the solos)
  is unchanged.
- **Texts**: the unit, Armoury and tooltip texts, the HELP paragraph, the card lines ("Walking to a Marching Band to
  join it (Fife).", "No band to join: every band has a Fifer. Waiting."), the train tooltip (where he goes, how many bands
  want one), tools/i18n/67_band_v2.txt (en/pt/es), patch notes 0.36.0.
- **Icons**: the owner's ChatGPT icons came in 0.35.15 (before this job), so no placeholders were needed: the Fifer's and
  Piper's portraits are their train buttons and the band's RECRUIT buttons, `ab_band_join` is JOIN BAND
  (docs/command_icons_audit.md "The Marching Band").

## 3. The sound: the engine only, not the music

"Currently the band sounds are not good, all of it is a cacophony." The music itself is NOT redone here (the owner will
send real reference music for a later job; his first six pieces are measured in docs/band_music_refs.md). What changed is
how the band's sound is played: **BandSound** (scripts/band_sound.gd), one node per match, its own players on the SFX
bus (the shared Sfx player is not touched).

Why it was a cacophony (besides the music): every band played every instrument's 4 s phrase from its own clock (each
band's `_sound_t`), so two bands meant the same loop twice, out of step; each phrase went through Sfx.play, whose din cap
(6 new sounds in 250 ms) could drop one part of a phrase while the others played; and all of it sat at full level under
the game music.

The rules now:

- **One band is heard at a time**: the one nearest the middle of the screen (screen px, so zoom counts), a band in a SOLO
  first; the band heard keeps it unless another is 90 px nearer (no flip-flopping between two bands). Bands further than
  760 screen px, hidden by the fog (Sfx.heard) or with no musician are not heard. Never two copies of a loop.
- **One clock**: every part is a looping player started at the shared clock's place in the phrase (the time since the
  match's BandSound was made, wrapped at 4 s), so the three parts always play in step, and when the heard band changes the
  music carries on in the same bar instead of restarting. A part that drifts more than 80 ms is put back in step.
- **Quiet always-on playing**: the +5% playing is at -15 dB (was 0 for the lead, -7 for the others), a **solo** at -1 dB
  with the others at -19 dB under it, so a solo is clearly heard. Further from the middle of the screen it fades to
  -30 dB at the edge; zoomed far out it is a little quieter still. Levels glide (no clicks).
- **The game music is ducked** a little while a band is heard (-2.5 dB), more during a heard solo (-6 dB): an Amplify
  effect named `band_duck` on the Music bus (the volume slider is untouched), back to 0 when the match ends.
- **New music drops in at one place**: `BandSound.PARTS` lists each instrument's two files (the always-on loop and the
  solo loop), `PHRASE` their length, `BPM` / `BARS` for the record. Nothing else needs to change.

Real instrument samples, all CC0, are in `art/audio_src/band/` (with a .gdignore: never imported, never in a build) and
listed in its SOURCES.txt: the FreePats bagpipe (Gilles Sadowski: chanter F4-G5, two drones in G), and from the VCSL
library a rope-tension snare (the period's field drum), a marching snare, a bass drum and a baroque soprano recorder (no
CC0 fife or piccolo was found on GitHub: the recorder is the nearest; the owner's real fife notes in art/audio_src/fife/
remain the better fife).

## 4. A brief for the music job to come

What the files must be (they replace assets/audio/band/*.ogg, named in BandSound.PARTS):

- **Six loops**: for each instrument (drums, fife, pipes) an **always-on** loop (steady, plain, could play for minutes
  without tiring the ear) and a **solo** loop (the same tune, busier and louder: the drums' rolls, the fife's flourishes,
  the pipes' grace notes and full chanter).
- **One tempo and one key for all six**, and **one length** for all: a whole number of bars, e.g. 4 bars of 2/4 or 4/4
  at the quick march (100-116 beats a minute; the owner's pipe band pieces sit near 100, the fife-and-drum ones near
  110-120). Then set `PHRASE` to that length. Longer loops (8 bars, ~16-20 s) would tire the ear much less than today's
  4 s; the engine does not care how long they are as long as all six match.
- **The key** follows the pipes (docs/band_music_refs.md: Highland pipes sound near B-flat; the FreePats pipe is in G,
  so a band built on it plays in G, with the drones on G). The fife and the drums fit the pipes.
- **Parts that fit together in every combination**: a band may be the Drummer alone, Drummer + Fifer, Drummer + Piper or
  all three, and any one of them may be the solo with the others under it. Each part should sound complete alone.
- **No fade in or out at the ends** (today's phrases have a 120 ms fade-out, which dips at every bar line): cut on the
  beat so the loop is seamless.
- Mixed by BandSound as above; no need to bake levels into the files beyond a sensible peak (SoundMix/make_mix.py can
  give them a gain).

What would help from the owner: two or three pieces he wants the band to sound like (already has six: say which one is
closest), whether the band should play ONE tune (a march everyone knows: The British Grenadiers, Scotland the Brave...,
all public domain as melodies) or an original march in that style, and whether the always-on playing should be the
drum alone (quietest) with the fife and pipes only in their solos.

## 5. Tests

- `tools/test_marching_band.gd` (all pass): no research; RECRUIT (queued at the Armoury, paid, refused twice, the
  musician walks to THAT band past a nearer one, joins, +15 health, gone from the field); a plain Fifer to the nearest
  band; a right-click JOIN; the band killed on the way (he goes to another); no band (he waits, then goes to a new one);
  an old save's research fills every band; the side-by-side row; the click along the row; BandSound (one band heard,
  only its parts, the always-on quiet, a solo 18 dB over the others, one clock); and everything from 0.33.0 (buffs,
  solos, rings, save, snapshot, replay field, the funnel).
- `tools/test_content_all.gd -- only=crown` (0 FAIL, 1 WARN fixed after): the Fifer and the Piper are trained, paid,
  cancelled, come out; JOIN BAND on their cards; a Fifer joins and the FIFE SOLO works.
- `tools/test_rules_fixes.gd`: the Fifer's and the Piper's cards have no ATTACK. test_i18n, test_files, test_replay,
  test_save_job pass.
- `tools/test_marching_band_match.gd` (a Hard Crown computer, whole matches): see the table below.

MATCH_TABLE

## Claude's choices (say if wrong)

1. The Armoury, not the Foundry (above).
2. Fifer and Piper: the old research prices (60 + 10 powder, 75), 20 s each, 30 health, no supply.
3. RECRUIT queues at the nearest Armoury with the shortest queue; refused while one is on his way or queued for that band.
4. A musician walking to a band is a real unit: he can be killed on the way (and if the band is far, the walk is long:
   in a match the computer's Fifer walked 80 s to reach its band at the front). He is not escorted.
5. A musician whose band dies goes to another band that wants him; with none he waits where he is (or at the rally).
6. The computer's musicians always go to a band, whatever its army orders.
7. Joining takes no time (the moment he reaches the band). The Officer's mount takes 1-2 s; a short "falling in" pause could
   be added.
8. Sound: one band heard at a time (not "the nearest loud, others quiet": two copies of the same loop sound like an echo
   even when quiet), -15 dB always-on, the music ducked -2.5 / -6 dB.

## Open questions for the owner

1. Should the musicians be trained at the Foundry after all (or at both)?
2. A musician walking alone across the map is easy prey: should he start at the band instead (paid at the Armoury, appears
   by the band after the training time), or keep walking (your words: "like an officer goes to a horse")?
3. Should a band with no Fifer/Piper ask for one by itself (auto-recruit, like auto-train)?
4. The music: the brief above, and which of your reference pieces is closest to what you want.
