# The Marching Band's music (jobs band-music 0.37.1 and band-music-v2 0.37.4)

The owner (2026-11-14): the 4 s band loops were "a cacophony", so band-music (0.37.1) made six loops of Scotland the
Brave from real samples. His verdict on it (09:57): "almost good job, but try again now you have the proper
information": he sent a reference score of the tune (pipes, second pipes, snare, bass drum). The score is someone
else's arrangement and is NOT in the repo; only the traditional melody's notes and the drum pattern's shape were taken
from it. And (09:58, after hearing 07_over_crown_battle_music): "if we are hovering our camera near the band the game
music has to drop down so the main piece is the band's music". band-music-v2 did both.

## In short (0.37.4)

- **The tune**: Scotland the Brave **note for note as the reference score has it**: 16 bars of 4/4, A (1-4), A' (5-8),
  B (9-12), A' (13-16), no pick-up. The score plays it twice and ends on a flourish; a loop needs neither.
- **Tempo: 110** quarter notes a minute, as the score has it (exactly 109.91: see the loop below).
- **Key: E.** The score is written in D. The tune spans C#4 to F#5 written: a tenth and a half step, more than the
  chanter's nine notes. Measured, the owner's FreePats set has takes at almost every semitone from about E4 to G5
  (the file names are not all right: some "A4" takes are a semitone off, they were measured by pitch). In E every note
  of the tune lands within 1.7 semitones of a recorded take (most within 0.7); in G (0.37.1's key) the top notes would
  need +4 semitones, in F +2.3. The only thing moved further is the drones: the recorded G drones down 3 semitones to E
  (a steady buzzing tone takes that well).
- **Each loop is the tune once**: 16 bars = 34.94 s = **1,540,800 samples** at 44.1 kHz = exactly 2,880 cycles of the
  low drone (E2, 535 samples a cycle) and 5,760 of the tenor drone, so the drones run on through the loop point. That
  is why the tempo is 109.91, not 110.00 (110.00 would be 1,539,491 samples, not a whole number of drone cycles).
- **One place lists it all**: `BandSound.PARTS`, `BandSound.BARS` (16), `BandSound.PHRASE` (1,540,800 / 44,100 s) and
  `BandSound.BPM` (worked out from them) in scripts/band_sound.gd; `Defs.MARCHING_BAND["phrase"]` (34.94).
- **The game music gives way to the band** (below): -12 dB under a band in the middle of the screen, -16 dB under a
  solo, fading in and out over about 1.2-1.6 s.

## What changed from 0.37.1, note by note

0.37.1 played the tune from a Highland pipe setting found as text (an ABC file). Against the reference score (written
in D; 0.37.1's notes given in the same written pitches, pipe low A = D4):

| Bar | 0.37.1 played | The score (0.37.4 plays) | What was wrong |
|---|---|---|---|
| (pick-up) | A4 eighth before bar 1 | none | the score starts on the downbeat |
| 1, 5, 13 | D q, D e., E s, F# e, D e, F# e, A e | the same | right |
| 2, 6, 14 | D5 q, D5 q, D5 e, A4 e, F#4 e, D4 e | D5 q, **D5 e., C#5 s**, D5 e, A4 e, **F#4 q** | the dotted D5-C#5 figure was a plain D5 quarter; the bar ended F#4 D4 eighths instead of an F#4 quarter |
| 3, 7, 15 | G q, B e., G s, F# e, A e, F# e, D e | the same | right |
| 4 | E4 q, A4 q, A4 e., B4 s, a turn A G F# E | E4 q, **A4 e., B4 s, A4 half** | an extra A4 quarter, and a running turn where the phrase holds A4 (open, on the dominant) |
| 8, 16 | E4 q, D4 e., **E4** s, D4 q, F#4 e, A4 e | E4 q, D4 e., **C#4** s, **D4 half** | E4 where the leading note C#4 (the pipes' low G) belongs; the home D4 cut short by a run back up |
| 9 | D5 q, D5 q, D5 e, A4 e, F#4 e, D4 e (Part A's bar 2 again) | **E5 q, E5 e., D#5 s, E5 e, C#5 e, A4 q** | the whole Part B was wrong: the score's B climbs ABOVE the pipes' high A (E5, F#5) with a chromatic D#5 |
| 10 | D5 q, D5 q, D5 e, A4 e, F#4 e, A4 e | **D5 q, F#5 e., E5 s**, D5 e, A4 e, **F#4 q** | the leap to F#5 was missing |
| 11 | D5 q, D5 e., C5 s, B4 q, D5 e., C5 s | **D5 q, D5 q, C#5 q**, D5 e., C#5 s | rhythm, and C natural (the pipes' flat high G) where the score has C# |
| 12 | B4 e, D5 e, C5 e, B4 e, A4 e, G4 e, a turn | B4 e, D5 e, **C#5 q, A4 q** (staccato), F#4 e, E4 e | the staccato quarters and the line down into bar 13 |
| all | 98 a minute, in G | **110**, in E | the score's tempo |

The fife plays the same melody an octave up, so all of this applies to it too.

## The six loops (0.37.4)

| File | What it plays |
|---|---|
| `pipes.ogg` (always-on) | the drones (E2, E3) and the melody **plain**: one gracenote (high G, or the note above for the top notes) on the long and repeated notes only; the chanter a little back |
| `pipes_lead.ogg` (solo) | the drones and the melody with the **pipe gracenotes**: doublings on the long notes on the beat (high G, the note, then a D or E gracenote), grips (low G, D, low G) between repeated low notes (bar 1's D D, bar 11's D5 D5 take a high G), the E gracenote stepping down to low A / B; **a second pipe in unison** (another take, 8 ms behind, plainer) that **rests in Part B** (bars 9-12) as the score's second pipes do the first time through; the score's **lower voice** quietly under it as half notes (bars 1-3: D/F#, F#/D, D/D; bar 4: C#/E; bar 8: C#/D; bars 9-12: A/E, F#/D, F#/A, E/D); the chanter forward |
| `fife.ogg` (always-on) | the melody an octave over the pipes, plain and a little detached; bar 12's two quarters staccato |
| `fife_lead.ogg` (solo) | the same with ornaments: a roll (a turn) into the long notes, a cut where the pipes have a gracenote |
| `drums.ogg` (always-on) | the score's snare pattern (below), plainly; the bass drum on 1 and 3, in Part B a grace into an accented 1 |
| `drums_lead.ogg` (solo) | the same pattern filled out: ghost notes between the eighths, 5- and 7-stroke rolls into the accents, buzz rolls through the cadences' rests and Part B's rests, drags at bar ends; extra bass and tenor drum strokes, the cymbal at bar 1 and at Part B |

**The snare pattern** (one character a sixteenth, F = flam, t = tap, D = drag, . = rest), after the score's:
Part A bars `F.t.t.t.F.t.t.tt` / `F.t.t.t.F.t.t.D.` (constant eighths, a flam on 1 and 3, a sixteenth pair or a drag at
the bar's end); the last bar of each 4-bar phrase (4, 8, 16) `F.t.F.t.........` (flam eighth, flam eighth, rest); Part
B bars 9-10 `F...t...F.t.....` (quarter, quarter, eighth eighth, rest, flams on 1 and the first eighth of beat 3);
bars 11-12 straight eighths `A.t.t.t.A.t.t.t.`.

The always-on loops are levelled 3 dB under the solos in the file itself, the solos at the game sounds' loudness, as in
0.37.1. Every loop works alone and with any other.

## The game music gives way to the band

In scripts/band_sound.gd (the duck is an Amplify effect named band_duck on the Music bus, as since band-v2):

| | 0.37.1 | 0.37.4 |
|---|---|---|
| a band (or lone musicians) heard, in the middle of the screen | -2.5 dB | **-12 dB** (`DUCK_DB`) |
| ... its solo heard | -6 dB | **-16 dB** (`DUCK_SOLO_DB`) |
| further from the middle | scaled by level/20 | `duck_for`: full within NEAR (160 screen px), fading to none at level -24 dB (640 screen px from the middle; CUT is 760) |
| zoomed in | - | up to **-2 dB more** (`ZOOM_IN_DB`, zoom 1 -> 2); zoomed out the band's level is lower, so the duck is less |
| how fast | 30 dB a second (a jump) | **10 dB a second** (`DUCK_RATE`): -12 dB in 1.2 s, back up from a solo in 1.6 s |

The players keep the balance: the duck never touches the MUSIC and SOUND volume sliders (the Music and SFX buses), so
anyone who wants more or less battle music under the band moves the MUSIC slider. With the default sliders (MUSIC 0.5 =
-6 dB, SOUND 1.0) a band playing along now sits about 5 dB OVER the ducked battle music (it was about 10 dB under it in
0.37.1), and a solo about 20 dB over it.

## Checked

- `tools/test_band_music.gd`: 16 bars at 110 (109.91), all six files exactly one phrase (34.9388 s); with the movie
  writer (the engine mixes sound): every file plays on through its loop point with no click (the check now skips the
  first 20 ms of the capture: starting playback mid-wave is a step of its own, which 0.37.1's check counted by luck),
  two parts on the shared clock stay 2.5 ms apart at worst and within 9 ms of the clock. The old "never quiet near the
  loop point" check was dropped: the score's snare rests in each phrase's last bar, a rest, not a drop-out.
- `tools/test_marching_band.gd` (91 checks, all pass; new ones): a band in the middle of the screen sets the music's duck to -12 dB; it
  gets there smoothly within 1.6 s; the Music bus's band_duck effect is under -10 dB; a solo takes it to -16 dB; the
  band off to the side ducks it less; the camera leaving brings it back up smoothly (still under -8 dB right after, 0
  within 2 s). `test_i18n`, `test_files`: pass.
- In the script (measured on the files, autocorrelation per note): fife solo 79 of 80 notes and fife always-on 80 of 80
  within 45 cents of the score's note (the one miss is 49 cents, the tracker's resolution at 1.3 kHz); the pipes' solo
  80 of 80 (octave-folded: the drones are under it).

## The listening files (docs/band_sound/, 45 s each, mp3)

The band levels are BandSound's own (always-on -15 dB, a solo -1 dB with the others at -19 dB); the 07 files are the
game's mix NOW: the music at its level (-8 dB) and the MUSIC slider's default (-6 dB), ducked as above, the band's parts
fading in and out at BandSound's speed. `docs/band_sound/LIST.txt` has one line each.

| File | What you hear |
|---|---|
| `01_*_solo_alone`, `02_*_always_on_alone` | each solo loop and each always-on loop by itself |
| `03_full_band_always_on`, `04_full_band_*_solo` | all three playing along; all three with one soloing |
| `05_drummer_and_piper`, `05_drummer_and_fifer` | the smaller bands |
| `06_two_bands_one_clock` | two bands on the one clock (left a pipe solo, right playing along): in step |
| `07_over_crown_battle_music`, `07_over_clockwork_battle_music`, `07_over_brood_battle_music` | the band centred on the screen the whole file over each faction's battle music, the music ducked 12 dB; the pipes' solo from halfway (16 dB) |
| `07b_camera_comes_and_goes` | the Crown's battle music; the camera reaches a band playing along at 15 s and leaves at 30 s: the duck in and out |
| `08_OLD_*` | before 0.37.1: the old 4 s loops |
| `09_PREVIOUS_*` | 0.37.1's listening files (in G at 98, the old tune text, the music ducked only 2.5 / 6 dB), kept to compare |

To remake them: `python3 tools/audio/make_band_music.py` (the loops and the listening files) or `--docs-only` (the
09_PREVIOUS_ files are kept).

## How each part is made

All in Python (numpy, scipy, soundfile, soxr; ffmpeg writes the files). The loops are rendered "folded": anything that
rings past the end comes back in at the start, so every file loops seamlessly, rooms and all. Every note and stroke is
a few ms off the grid and a little uneven in force, seeded, so the script makes the same music each run.

**Pipes** (FreePats bagpipe, Gilles Sadowski, CC0): every chanter take's pitch is measured; a note uses the takes
nearest its pitch, retuned to **just intonation over the drones** (E, F# 9/8, G# 5/4, A 4/3, B 3/2, C# 5/3, the
leading notes D# 15/8 and the score's D#5 as the leading note into E5 (135/64 over the octave), E 2, F# 9/4, G# 5/2,
low D# 15/16). The chanter never stops: each note runs until the next, joined by a 6 ms crossfade, from the steady
middle of a take. Gracenotes (28-32 ms) come just before the beat, taking their time from the note before. The drones:
one seamless loop each (E3: 576 cycles in 3.49 s, E2: 144 cycles in 1.75 s), cut where the recording matches itself
best. A little room around the whole pipe.

**Fife** (VCSL Baroque Soprano Recorder, Versilian Studios, CC0), made fife-like as in 0.37.1 (saturation, a brighter
top, a puff of breath at each tongued note): the melody an octave over the pipes (E5 to G#6) in the same intonation.

**Drums** (MuldjordKit, Lars Muldjord, CC BY 4.0): the kit reworked as in 0.37.1 (the snare tuned up 2.5 semitones,
tightened, wire snap; the kick down 5 semitones with a felt beater and a big room; the floor tom as the tenor; the
crash). Velocity layers by the stroke's force, never the same file twice in a row; flams, drags, 5- and 7-stroke rolls,
buzz rolls.

## Sources and licences

| What | Source | Licence | Credit |
|---|---|---|---|
| Bagpipe chanter and drones | FreePats Bagpipe, Gilles Sadowski (art/audio_src/band/freepats_bagpipe/) | CC0 1.0 | not required (credited) |
| Snare, rim, bass drum, tenor, cymbal | MuldjordKit, Lars Muldjord, FreePats version (art/audio_src/band/muldjord_drums/) | CC BY 4.0 | **required**: "MuldjordKit drum samples by Lars Muldjord, CC BY 4.0" |
| Fife | VCSL Baroque Soprano Recorder, Versilian Studios (art/audio_src/band/vcsl/) | CC0 1.0 | not required (credited) |
| The tune | Scotland the Brave, traditional; the notes as in a reference score the owner supplied (an arrangement by someone else, not in the repo: only the traditional melody and the shape of the drum pattern were taken) | public domain melody | none |

All in docs/audio_credits.md.

## Claude's choices (say if wrong)

1. **E, not G**: the key where the recorded chanter fits the score's range best (above); the drones moved down 3
   semitones for it.
2. **109.91 a minute** instead of exactly 110, so the loop is a whole number of drone cycles (no seam in the drones).
3. **Bar 1's rhythm**: the brief's transcription of bar 1 ("D q, D q, E s, F# e., D e, F# e, A e") adds up to nine
   eighths; the score's bars 3, 5 and 13 and the familiar opening have D q, D e., E s, F# e, D e, F# e, A e (eight),
   which is what plays.
4. **The tune once** (16 bars, 34.9 s), not twice with the flourish: the loop repeats it anyway.
5. **Gracenotes for the notes over high A** (E5, F#5: the score's Part B is beyond a real chanter): E5 takes an F#5
   gracenote, F#5 a strike from D5; the D#5 sixteenth none.
6. **The second pipes and the lower voice only in the solo**; the always-on pipes are one plain chanter, so a band
   playing along stays quiet and clear.
7. **The duck numbers**: -12 dB (a band) and -16 dB (a solo), 10 dB a second, none past 640 screen px from the middle (CUT is 760);
   no new slider (the MUSIC slider balances it).

## Questions for the owner

1. Is the duck right: should the battle music drop more (or less) under a band playing along (-12 dB now)?
2. Is E (a little lower than a Highland pipe's B-flat) a good key for the band, or would you rather hear it nearer
   B-flat (the chanter's top notes would then be moved further)?
3. Do the second pipes and the harmony line make the Piper's solo better, or muddier?
4. 0.37.1's open questions still stand: the snare and bass drum sound, the fife (a recorder made brighter), one tune or
   more, the always-on playing.
