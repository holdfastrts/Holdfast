# The Marching Band's music (job band-music, 0.36.6)

The owner (2026-11-14): today's 4 s band loops are "a cacophony" and the bagpipe "synthesised, not pleasant". He sent
six reference pieces (measured in docs/band_music_refs.md) and the real instrument samples to build new music from.
This job made it: six new loops in `assets/audio/band/`, made by `tools/audio/make_band_music.py` from real samples
only, and listening files for the owner in `docs/band_sound/`.

## In short

- **The tune**: **Scotland the Brave**, the traditional pipe march (public domain as a melody), in its Highland pipe
  setting with the gracenotes: Part 1 and Part 2, 16 bars of 4/4. One tune for all three players, so any mix of them is
  the same music.
- **Key: G.** The FreePats bagpipe is a pipe in G (its drones are G), so the whole band plays in G: the pipes' "A"
  (their home note) is our G, and every other note moves down a tone with it. The fife and the drums follow the pipes.
  (A Highland pipe sounds near B-flat, which is why the owner's pipe band pieces read as B-flat; ours is a smaller pipe
  in G. Same tune, same intervals, a little lower.)
- **Tempo: 98 beats a minute** (quarter notes), the pace of the owner's pipe band references (~99).
- **Each loop is the whole tune once**: 16 bars = 39.18 s (exactly 1,728,000 samples at 44.1 kHz), instead of a 4 s
  phrase. All six files are exactly that long; the tune's pick-up note sits at the end of the loop and leads straight
  back into bar 1, so the loop has no seam.
- **One place lists it all**: `BandSound.PARTS` (the six files), `BandSound.BPM` (98), `BandSound.BARS` (16) and
  `BandSound.PHRASE` (worked out from them: 39.18 s) in scripts/band_sound.gd. Nothing else in the engine changed: the
  band heard, the shared clock, the levels and the music duck all work as band-v2 made them (docs/band_v2.md).

## The six loops

| File | What it plays |
|---|---|
| `pipes.ogg` (always-on) | the drones (bass G2 and tenor G3) and the melody **plain**: only single G and A gracenotes, no grips or doublings; the chanter a little back in the mix |
| `pipes_lead.ogg` (solo) | the drones and the melody with **every gracenote of the pipe setting** (G, D and E gracenotes, doublings, grips, the throws on D), the chanter forward |
| `fife.ogg` (always-on) | the melody **an octave over the pipes**, plain and a little detached |
| `fife_lead.ogg` (solo) | the same with **ornaments**: a cut (a flick of the note above) wherever the pipes have a gracenote, and a roll (a quick turn) into the long notes |
| `drums.ogg` (always-on) | a plain pipe band beat: bass drum on every beat (strong on 1, then 3), the snare with a flam on 1 and an accent on 3, taps on the dotted rhythm of the tune, an occasional 5-stroke roll or buzz roll into the end of a phrase, rim clicks now and then |
| `drums_lead.ogg` (solo) | a full pipe band snare score: flams, drags (ruffs), 5- and 7-stroke rolls, buzz (press) rolls through half bars, ghost notes; the bass drum with extra hits on the off-beats, the tenor drum (floor tom) accenting the phrases, the cymbal at the top of the tune and of Part 2 |

Every loop works alone and with any of the others: the band's always-on playing is all three plain loops together; a
solo is one solo loop with the others' plain loops under it. The always-on loops are made 3 dB quieter than the solos in
the file itself (on top of BandSound's own levels); the solos sit at the loudness the game's other sounds are levelled to
(tools/audio/make_mix.py's target: the music's median loudness - 8 dB).

## How each part was made

All rendering is in Python (numpy, scipy, soundfile, soxr; ffmpeg writes the files). The loops are rendered "folded":
anything that rings past the end of the loop (a long note, a cymbal, a room's echo) comes back in at the start, so every
file loops seamlessly, rooms and all. Every note and every stroke is a few ms off the grid and a little uneven in force,
seeded, so it does not sound mechanical and the script makes the same music each run.

**Pipes** (FreePats bagpipe, Gilles Sadowski, CC0):
- The chanter notes F4 to G5, two takes of most, one picked by its measured pitch (the owner's set has some notes a
  semitone off under the same name: the C# and B-flat takes are not used). Each note is retuned to **just intonation
  over the drones** (the chanter as recorded sits 26-50 cents flat against its own drones): G, A 9/8, B 5/4, C 4/3,
  D 3/2, E 5/3, F 16/9 (the pipes' flat high G), G 2, low F 8/9. The shifts are small (under half a semitone).
- **A bagpipe never stops**: the chanter is one unbroken sound; each note runs until the next begins, joined by a 6 ms
  crossfade (a finger change), taken from the steady middle of the recording (never its start, so no new attack).
- **Gracenotes** (28-32 ms each) come just before the beat, taking their time from the note before, as pipers play them.
  The always-on loop keeps only a single G or A gracenote of each embellishment.
- **The drones**: one seamless loop each (G3: 4.9 s = 960 cycles; G2: 1.96 s = 192 cycles), cut where the waveform
  matches itself best and stretched by under 0.2% so it holds a whole number of cycles. At 98 beats a minute the whole
  loop is a whole number of drone cycles, so the drones run on through the loop point without a seam.
- A little room around the whole pipe.

**Fife** (VCSL Baroque Soprano Recorder, Versilian Studios, CC0):
- Why not the old fife notes: the owner's earlier fife notes (art/audio_src/fife/notes/, cut from his fife-and-drum
  recording) have the other fifes and the drums in every note (measured: the strongest sound in most of them is a drum
  below 100 Hz, and three of them are louder at another pitch than their own). The brief allowed better CC0 / CC-BY fife
  or flute samples: no CC0 fife or piccolo was found (band-v2 looked too), and the CC0 soprano recorder already in
  art/audio_src/band/vcsl/ is clean, has a note every whole tone (each note is moved a semitone at most) and long
  sustains. A recorder is a whistle flute like the fife's cousin; it was made fife-like: a touch of saturation for the
  fife's edge, a brighter top (+4 dB at 3.5 kHz), a puff of breath at each tongued note and a little breath under it all.
- The melody an octave over the pipes (G5 to G6), in the same just intonation, so it lies on the pipes exactly.

**Drums** (MuldjordKit, Lars Muldjord, CC BY 4.0: credit required, see below):
- **Snare**: the kit's 56-layer snare made into a marching snare: tuned up 2.5 semitones (a tighter head), the boom cut
  (high-pass 170 Hz, -5 dB at 320 Hz), the crack and wires brought up (+4 dB at 4.8 kHz, +2.5 dB at 9.5 kHz), a short
  decay (a dry, tight drum), a burst of bright noise on each stroke for the snare wires' snap, and a small room.
  The rim / rest hits (SnareRest1) are the rim clicks.
- **Bass drum**: the kit's kick tuned down 5 semitones (a bigger shell), its beater softened (low-pass 1.4 kHz: a felt
  mallet), more low end, and a big room (a parade drum outdoors between buildings).
- **Tenor drum**: the floor tom, tuned up 3 semitones. **Cymbal**: the crash, softly, twice a loop in the solo.
- **Velocity layers**: each stroke picks the layer that fits its force, with a little spread, and never the same file
  twice in a row; the two hands are a touch uneven. Flams (a soft grace stroke 26 ms before), drags (two grace strokes),
  5-stroke rolls (four strokes in the sixteenth before), 7-stroke rolls (six in the eighth before), buzz rolls (strokes
  every triplet thirty-second with two softer bounces each: the stick pressed into the head), crescendo into the accent.
- The owner's Pixabay marching drum solos (art/audio_src/marching/) were not needed: the sampled kit gives a cleaner,
  steady part that can be written to fit the tune bar by bar (the solos are other people's performances, at their own
  tempo).

## Checked

- `tools/test_band_music.gd` (new): the loop is 16 bars at 98; all six files exactly one phrase long (39.1837 s); each
  file played through the game's own mixer across its loop point (a second before the end to a second after the start):
  never silent, no click (no step between two samples bigger than the music's own); two parts started on the shared
  clock (one joining later, as a solo does) stay **2.5 ms** apart at worst across the loop point and within **9 ms** of
  the clock (BandSound puts a part back only past 80 ms). The sound checks need the engine to mix sound, which it does
  under the movie writer:
  `xvfb-run -a godot --rendering-driver opengl3 --write-movie /tmp/band_test/out.png --fixed-fps 30 --resolution 320x180 --script res://tools/test_band_music.gd`
  (plain `--headless` mixes nothing: then only the length checks run, with a note). All pass.
- `tools/test_marching_band.gd` (87 checks, BandSound's included), `test_i18n`, `test_files`: pass.
- In the script, measured on the files: every fife note within 40 cents of the tune's note (102 of 102); the pipes'
  notes too wherever the pitch tracker could hear the chanter over the drones.

## The listening files (docs/band_sound/, 45 s each, mp3)

The levels are BandSound's own (always-on -15 dB, a solo -1 dB with the others at -19 dB, the music at -8 dB ducked
-2.5 dB under a band and -6 dB under a solo). The list with one line each is also in `docs/band_sound/LIST.txt`.

| File | What you hear |
|---|---|
| `01_pipes_solo_alone`, `01_fife_solo_alone`, `01_drums_solo_alone` | each solo loop by itself |
| `02_pipes_always_on_alone`, `02_fife_always_on_alone`, `02_drums_always_on_alone` | each always-on loop by itself |
| `03_full_band_always_on` | all three playing along (what a full band sounds like most of the time) |
| `04_full_band_pipes_solo`, `04_full_band_fife_solo`, `04_full_band_drums_solo` | all three, one soloing over the others |
| `05_drummer_and_piper`, `05_drummer_and_fifer` | the smaller bands, playing along |
| `06_two_bands_one_clock` | two bands at once on the one clock (left a pipe solo, right playing along): in step. In a match only one band is heard at a time (the one nearest the middle of the screen); this shows that switching between them never jumps |
| `07_over_crown_battle_music`, `07_over_clockwork_battle_music`, `07_over_brood_battle_music` | the band over each faction's battle music as the game mixes it: playing along for the first half, the pipes' solo in the second |
| `08_OLD_full_band_always_on`, `08_OLD_full_band_pipes_solo`, `08_OLD_full_band_fife_solo` | BEFORE: the old 4 s loops in the same combinations, for comparison |

To remake them: `python3 tools/audio/make_band_music.py` (the loops and the listening files) or `--docs-only`.

## Sources and licences

| What | Source | Licence | Credit |
|---|---|---|---|
| Bagpipe chanter and drones | FreePats Bagpipe, Gilles Sadowski (art/audio_src/band/freepats_bagpipe/) | CC0 1.0 | not required (credited) |
| Snare, rim, bass drum, tenor, cymbal | MuldjordKit, Lars Muldjord, FreePats version (art/audio_src/band/muldjord_drums/) | CC BY 4.0 | **required**: "MuldjordKit drum samples by Lars Muldjord, CC BY 4.0" |
| Fife | VCSL Baroque Soprano Recorder, Versilian Studios (art/audio_src/band/vcsl/) | CC0 1.0 | not required (credited) |
| The tune | Scotland the Brave, traditional (the pipe setting's notes as text, from an ABC file marked "Traditional") | public domain melody | none |

All in docs/audio_credits.md. No note was cut from anyone's recording other than these sample sets.

## Claude's choices (say if wrong)

1. **One tune, Scotland the Brave**, for all three parts. Two tunes (a pipe tune and a fife tune) cannot play at once
   without clashing, and the engine plays any mix of parts together. Scotland the Brave is a pipe tune that fits the
   chanter's nine notes exactly, and was one of the owner's references.
2. **G, not B-flat**: the recorded pipe is in G. Moving the pipe up to B-flat would mean shifting every note and the
   drones by three semitones (the brief: shift a sample only a little).
3. **98 a minute** (the pipe band refs), not the fife-and-drum corps' 108-117.
4. **Part 1 and Part 2 once each** (16 bars, 39 s), not the march's full AABB (32 bars, 78 s): half the size, and 39 s
   is long enough not to tire the ear; the always-on drums vary bar to bar within it.
5. **The fife is a recorder made fife-like** (above). The fife plays the melody an octave up, not a harmony part.
6. **The always-on loops play the melody too** (plainly), so a band playing along sounds like a band playing the tune,
   and the solo is the same tune "brought forward" with all its ornaments.
7. The listening files and loops are mono; the game plays the band in mono anyway (one AudioStreamPlayer per part).

## Questions for the owner

1. Does the snare sound like a marching snare to you (tight and crisp), and the bass drum big enough? Both are a rock kit
   reworked; easy to retune (`Kit` in the script).
2. Is the fife (a recorder made brighter) good enough, or should we look for a real fife or piccolo set (CC0 / CC-BY),
   or would you record one?
3. Should the band have more than one tune (e.g. The British Grenadiers for a band with no Piper: the fife and drums
   could play it, in G, at a quicker pace), or one tune for all?
4. Too quiet or too loud over the game music? (07_* files; BandSound's levels can move in one place.)
5. Should the always-on playing be the drums alone (the quietest), with the fife and pipes only in their solos?
