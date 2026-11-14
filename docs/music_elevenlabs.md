# The owner's ElevenLabs pieces in the game (job music-elevenlabs)

Twelve faction pieces and a main menu theme, made by the owner with ElevenLabs Music (Music v2.5, instrumental,
2026-11-14; sources untouched in `art/audio_src/music_elevenlabs/`, prompts in its SOURCES.txt), mastered for the
game and added to the music rotation. No generated piece was changed or removed.

## Where they play

| File | Title | Role | How it is picked |
|---|---|---|---|
| crown_battle_12 | Campaign of the Crown | Crown opening | Music.ROLES "open" |
| crown_battle_13 | Musketeer Charge | Crown skirmish | Music.ROLES "skirmish" |
| crown_battle_14 | March of the Iron Standard | Crown full battle | by name (`_battle`, no role) |
| crown_peace_10 | Dawn Over the Colony | Crown calm | by name (`_peace`) |
| clock_battle_14 | Clockwork Awakening | Clockwork opening | ROLES "open" |
| clock_battle_15 | Clockwork Skirmish | Clockwork skirmish | ROLES "skirmish" |
| clock_battle_16 | Forge of Iron Command | Clockwork full battle | by name |
| clock_peace_8 | Clockmaker's Waltz | Clockwork calm | by name |
| brood_battle_14 | Swamp Queen Awakening | Brood opening | ROLES "open" |
| brood_battle_15 | Swamp Hunt Frenzy | Brood skirmish | ROLES "skirmish" |
| brood_battle_16 | Stampede of the Ancients | Brood full battle | by name |
| brood_peace_8 | Swamp After Dark | Brood calm | by name |
| menu_11 | Crown of Ashes | main menu overture | the FIRST piece heard at the main menu after the game starts (Music.MENU_FIRST) |

**Weight.** All thirteen are in `Music.FEATURED`: a featured piece is picked `WEIGHT` (3) times as often as a
generated one, and it comes back sooner (it is kept out only while it is among the last 2 pieces played; a generated
piece still waits until most of its pool has played). At the menu each round of the shuffle holds Crown of Ashes 3
times among the other overtures (never twice in a row). The generated pieces stay in rotation, the setting's modes
(your faction / everything / ticked) work as before, and the in-game music player and the Settings music list show the
new pieces with their titles (they come from `scripts/music_tracks.gd`, which `tools/music/compose.py --tracks` now
writes with these pieces at the end, from `master_elevenlabs.PIECES`).

**Endings.** These pieces have real endings, so they are not looped (the .import files have `loop=false`, like every
music piece). The player plays a piece to its end and then picks the next one of the same mood (`Music._on_finished`;
the opening piece hands over to a calm one), cross-fading only when the mood changes (2.5 s). All thirteen end on a
final chord that dies away to silence (the last 0.3 s is 46-69 dB under the body), so none needed a fade-out; the
tool fades 2.5 s automatically when an ending is abrupt. Leading silence was trimmed (Campaign of the Crown began
with 4.8 s of digital silence, which would have been 4.8 s of nothing after a cross-fade). Swamp Queen Awakening is
59 s, the rest 110-120 s.

**The band.** The duck under a marching band (BandSound.duck_for) is an Amplify effect on the Music bus, so it works on
these pieces like on every other one; scripts/band_sound.gd was not touched.

**Web.** Nothing to change: `tools/web/build_web.sh` copies every `assets/music/*.ogg` next to the page and lists it in
the music table; each piece downloads when first wanted. The new files are 0.8-2.2 MB (44.1 kHz Vorbis q4,
~110-145 kb/s; the generated pieces are 32 kHz q3, but these are real recordings with real high end).

## The mastering (tools/music/master_elevenlabs.py)

One line per piece in `PIECES` (stem, source, title, role, settings); `python3 tools/music/master_elevenlabs.py [stem
...]` remakes them, `--report docs/music_study/elevenlabs.json` also measures before and after with the study's
`study_audio.analyse`. The chain: trim silence; a high-pass at 35 Hz (38 Hz for the Brood and the menu theme); a
gentle low-shelf at 100 Hz, stepped down 0.5 dB at a time until at most 25% of the energy is below 80 Hz (so the
weight stays and the mud phones cannot play goes); +3 dB of high-shelf from 1.5 kHz on the dull Brood calm piece; a
gain toward the game's loudness, -12.8 LUFS (the median of the 73 generated pieces), but never more than 3 dB of
peak limiting to get there (5 dB on Clockwork Skirmish, whose peaks are clicks and ticks); a look-ahead true-peak
limiter (4x oversampled, 40 ms hold); then encode, decode, and remake with a lower ceiling if Vorbis pushed the true
peak over -1 dBTP. No compressor: the loudness range is kept, and the dynamic pieces stay a little quieter in
integrated loudness rather than being squashed (their loud parts are as loud as the other pieces).

| Piece (file) | Plays as | LUFS before → after | LRA before → after | True peak before → after | Sub-bass share before → after | What was done |
|---|---|---|---|---|---|---|
| Campaign of the Crown (crown_battle_12) | Crown opening | -14.7 → -12.9 | 4.3 → 3.8 | -2.2 → -1.1 | 0% → 0% | 4.8 s of silence trimmed from the start; high-pass 35 Hz; gain +1.9 dB; peaks limited up to 2.4 dB |
| Musketeer Charge (crown_battle_13) | Crown skirmish | -12.6 → -12.9 | 5.8 → 5.8 | -0.4 → -1.1 | 16% → 15% | 0.5 s of silence trimmed from the start; high-pass 35 Hz; gain -0.2 dB; peaks limited up to 1.2 dB |
| March of the Iron Standard (crown_battle_14) | Crown full battle | -11.6 → -12.9 | 5.1 → 5.2 | -0.4 → -1.4 | 14% → 12% | high-pass 35 Hz; gain -1.1 dB |
| Dawn Over the Colony (crown_peace_10) | Crown calm | -19.2 → -14.1 | 2.3 → 2.2 | -5.4 → -1.2 | 0% → 0% | 0.8 s of silence trimmed from the start; high-pass 35 Hz; gain +5.1 dB; peaks limited up to 3.0 dB |
| Clockwork Awakening (clock_battle_14) | Clockwork opening | -15.2 → -14.6 | 16.7 → 15.8 | -0.2 → -1.2 | 17% → 16% | 0.6 s of silence trimmed from the start; high-pass 35 Hz; gain +1.4 dB; peaks limited up to 3.0 dB |
| Clockwork Skirmish (clock_battle_15) | Clockwork skirmish | -18.0 → -15.6 | 14.2 → 13.7 | -3.5 → -1.3 | 14% → 14% | high-pass 35 Hz; gain +2.9 dB; peaks limited up to 5.0 dB |
| Forge of Iron Command (clock_battle_16) | Clockwork full battle | -12.6 → -13.1 | 10.9 → 11.1 | -0.5 → -1.2 | 28% → 25% | high-pass 35 Hz; low-shelf -0.5 dB at 100 Hz; gain -0.1 dB; peaks limited up to 1.7 dB |
| Clockmaker's Waltz (clock_peace_8) | Clockwork calm | -14.8 → -12.9 | 3.5 → 3.2 | -0.3 → -1.0 | 0% → 0% | high-pass 35 Hz; gain +2.0 dB; peaks limited up to 3.0 dB |
| Swamp Queen Awakening (brood_battle_14) | Brood opening | -16.7 → -14.4 | 17.4 → 18.1 | -0.3 → -1.2 | 48% → 24% | 1.1 s of silence trimmed from the start; high-pass 38 Hz; low-shelf -4.5 dB at 100 Hz; gain +4.2 dB; peaks limited up to 3.0 dB |
| Swamp Hunt Frenzy (brood_battle_15) | Brood skirmish | -14.8 → -14.5 | 14.8 → 13.8 | -0.4 → -1.0 | 34% → 25% | 1.1 s of silence trimmed from the start; high-pass 38 Hz; low-shelf -2.0 dB at 100 Hz; gain +1.5 dB; peaks limited up to 3.0 dB |
| Stampede of the Ancients (brood_battle_16) | Brood full battle | -12.8 → -13.1 | 10.3 → 10.4 | -0.9 → -1.1 | 23% → 19% | high-pass 38 Hz; gain +0.1 dB; peaks limited up to 1.3 dB |
| Swamp After Dark (brood_peace_8) | Brood calm | -18.8 → -12.8 | 8.1 → 9.5 | -6.4 → -1.1 | 41% → 24% | 0.6 s of silence trimmed from the start; high-pass 38 Hz; low-shelf -4.5 dB at 100 Hz; high-shelf +3 dB from 1.5 kHz; gain +7.3 dB; peaks limited up to 1.4 dB |
| Crown of Ashes (menu_11) | main menu (heard first) | -13.7 → -14.1 | 8.9 → 10.4 | -0.8 → -1.2 | 50% → 24% | 0.6 s of silence trimmed from the start; high-pass 38 Hz; low-shelf -4.5 dB at 100 Hz; gain +1.1 dB; peaks limited up to 3.0 dB |

(LUFS and LRA as the music study measures them (pyloudnorm, 3 s short-term windows); true peak "before" is the
study's figure over the first 60 s, "after" over the whole file after Vorbis; sub-bass = energy share 20-80 Hz of
20 Hz-16 kHz. The generated pieces: median -12.8 LUFS, LRA 6.8 LU, true peak -1.6 dBTP, sub-bass 12%.)

## The study's verdict, against our generated pieces of the same role

Climax = where in the piece its loudest 3 s window is (100% = the last chord; the study found our generated pieces
climax at the very end). Generated column = the median of the generated pieces in that role (how many in brackets).

| Role | Generated: LRA / climax / sub-bass (n) | ElevenLabs: LRA / climax / sub-bass | Verdict |
|---|---|---|---|
| Crown open: Campaign of the Crown | 5.8 LU / 79% / 3% (3) | 3.8 LU / 94% / 0% | FLATTER than ours, peaks at the end, same bass |
| Crown skirmish: Musketeer Charge | 6.2 LU / 98% / 40% (3) | 5.8 LU / 89% / 15% | FLATTER than ours, peaks before the end, lighter bass |
| Crown battle: March of the Iron Standard | 6.5 LU / 96% / 35% (7) | 5.2 LU / 61% / 12% | FLATTER than ours, peaks before the end, lighter bass |
| Crown peace: Dawn Over the Colony | 5.0 LU / 97% / 1% (7) | 2.2 LU / 68% / 0% | FLATTER than ours, peaks before the end, same bass |
| Clockwork open: Clockwork Awakening | 8.6 LU / 97% / 1% (3) | 15.8 LU / 84% / 16% | real dynamics, peaks before the end, more bass |
| Clockwork skirmish: Clockwork Skirmish | 7.6 LU / 71% / 4% (3) | 13.7 LU / 97% / 14% | real dynamics, peaks at the end, more bass |
| Clockwork battle: Forge of Iron Command | 8.3 LU / 98% / 16% (8) | 11.1 LU / 94% / 25% | real dynamics, peaks at the end, more bass |
| Clockwork peace: Clockmaker's Waltz | 6.4 LU / 65% / 2% (6) | 3.2 LU / 66% / 0% | FLATTER than ours, peaks before the end, same bass |
| Brood open: Swamp Queen Awakening | 7.5 LU / 76% / 12% (3) | 18.1 LU / 93% / 24% | real dynamics, peaks at the end, more bass |
| Brood skirmish: Swamp Hunt Frenzy | 8.1 LU / 80% / 18% (3) | 13.8 LU / 96% / 25% | real dynamics, peaks at the end, more bass |
| Brood battle: Stampede of the Ancients | 8.5 LU / 97% / 43% (8) | 10.4 LU / 82% / 19% | real dynamics, peaks before the end, lighter bass |
| Brood peace: Swamp After Dark | 5.5 LU / 62% / 2% (6) | 9.5 LU / 40% / 24% | real dynamics, peaks before the end, more bass |
| Main menu: Crown of Ashes | 6.9 LU / 97% / 17% (9) | 10.4 LU / 79% / 24% | real dynamics, peaks before the end, more bass |

In short: the Clockwork's three fighting pieces, all four Brood pieces and Crown of Ashes have what the study found
missing in ours (loudness ranges of 10-18 LU, against real music's ~12 and our 6.8); the bass that made the Brood and
the menu theme muddy was cut back to the cap. The four Crown pieces and the Clockmaker's Waltz are FLATTER than our
own generated pieces (2.2-5.8 LU): they are well played but stay at one level from start to finish.

## Candidates for the owner to remake (the flat ones)

ElevenLabs Music costs about 900 credits a minute, so a 2-minute remake is about 1,800 credits (the five below about
9,000). Suggested prompts, written to force the dynamics the numbers lack (keep "instrumental"):

1. **Dawn Over the Colony** (Crown calm, LRA 2.2, the flattest; also very quiet at the source, -19 LUFS, so it needed
   +5 dB). *"Baroque chamber music at dawn, instrumental, 2 minutes. Begin with a single solo lute, very quiet and
   slow, almost alone, for 20 seconds. A recorder joins, then a string quartet enters softly. Grow gradually: by the
   middle the full ensemble with harpsichord plays a warm minuet, clearly louder and brighter, with distant church
   bells at the peak around 1:20. Then thin out again to the lute and one violin, and end softly on a long held
   chord. Strong contrast between the quiet start, the full middle and the quiet ending."*
2. **Campaign of the Crown** (Crown opening, LRA 3.8; the prompt asked for a soft start but it starts at full level
   after 4.8 s of silence). *"Baroque military opening, instrumental, 2 minutes. Start very quietly with a solo snare
   drum alone, pianissimo, for the first 15 seconds. A single natural trumpet calls from far away, then answers. Low
   strings creep in under it, then harpsichord. Build steadily over a minute: more strings, horns, timpani rolls,
   organ, getting louder bar by bar, to a full, loud climax with trumpets and organ around 1:30. After the climax drop
   suddenly to strings alone, and end on a quiet trumpet call and a soft final chord. The beginning must be very
   soft."*
3. **March of the Iron Standard** (Crown full battle, LRA 5.2). *"Epic baroque battle march, instrumental, 2
   minutes. Open with snares and timpani alone, moderately loud. Trumpets and horns enter in waves: each wave louder
   than the last. At about 0:50 drop to a quiet passage of strings and a lone fife over a soft drum, then a sudden
   fortissimo return of the full orchestra with organ and cymbals, the loudest moment at about 1:30. End with three
   hammered full-orchestra chords and silence. Big contrasts between loud and quiet sections."*
4. **Musketeer Charge** (Crown skirmish, LRA 5.8). *"Classical military skirmish, instrumental, about 2 minutes.
   Start with a solo piccolo fife and a quiet snare. Staccato strings join, building tension, then trumpets and
   timpani burst in loudly. Alternate: a quiet, tense section with only pizzicato strings and a ticking snare, then
   another loud charge with the whole orchestra, louder than the first. End abruptly on one loud chord."*
5. **Clockmaker's Waltz** (Clockwork calm, LRA 3.2). *"A delicate clockwork waltz, instrumental, 3/4, 2 minutes.
   Begin with a solo music box, very soft, with a ticking clock. Celesta and glass harmonica join, then pizzicato
   strings. Swell gently to a fuller, warmer middle section with soft strings carrying the melody, clearly louder.
   Slow down at the end as if the spring is running out: the music box alone, slowing, quieter and quieter, until it
   stops."* (This also answers the study's open question about the Clockwork winding down at the end.)

The other seven are good by these numbers; if any is remade, Swamp After Dark is the one with almost nothing above
2 kHz (the +3 dB shelf helps a little; a prompt asking for "a high bone flute melody and insect-like string
harmonics" would give it more air).

## Tests

`tools/test_music_roles.gd`: every role still has music, every listed piece has its .ogg and .import, the Brood counts
now 24 (open 3, skirmish 4, battle 9, calm 8), each ElevenLabs piece is in its role and FEATURED, Crown of Ashes is a
menu piece and MENU_FIRST, every featured file loads as a non-looping Vorbis stream over 50 s, and the weighted pick
gives a featured piece about 3x the plays of a generated one.
