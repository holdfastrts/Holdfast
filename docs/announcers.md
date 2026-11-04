# Announcers

Each faction has one announcer voice that tells the player what is happening ("Our men are under attack!").
The game plays `assets/voice/announcer/<crown|clock|brood>/<key>.ogg` through `Sfx.announce(faction, key, gap)`
(scripts/sfx.gd): the same line is not said again within `gap` seconds, and a missing file is silent.

## The voices

| Faction | Voice | Where it comes from |
|---|---|---|
| Crown | a royal herald | the owner's recordings, ElevenLabs (eleven v3, a voice he designed), 2026-11-04. Sources: `art/audio_src/crown_herald/01.mp3 ... 21.mp3` |
| Brood | the campaign's scientist: a posh gentleman who admires the Brood but is not part of it | the owner's recordings, ElevenLabs (eleven v3), 2026-11-04. Sources: `art/audio_src/brood_scientist/01.mp3 ... 21.mp3` |
| Clockwork | a flat robot voice | synthetic (Kokoro TTS through a robot chain), `tools/audio/make_voices.py` |

The Crown's and the Brood's old Kokoro lines (a gruff herald, a whispering hive mind) were replaced on 2026-11-04.

## Languages

The recorded Crown and Brood lines are in **English only**. For now the game plays them in English in every
language (Portuguese and Spanish too): `Sfx.ENGLISH_ONLY` in scripts/sfx.gd lists the folders that skip the
`assets/voice_pt/` and `assets/voice_es/` lookup. The owner has not decided whether to record pt / es versions.
The old Kokoro pt / es announcer lines are still in `assets/voice_pt|es/announcer/` but are not heard; when pt / es
recordings come, import them there and take the faction off `ENGLISH_ONLY`.
The Clockwork's announcer is unchanged: it still has its own pt / es lines.

## The lines

The standard set is 19 keys for every faction, plus 2 of each faction's own (the files are numbered 01 to 21 in
this order). "When" says what makes the game say it; "not wired" means the file exists but nothing plays it yet.

| # | Key | When (gap) | Crown (herald) | Brood (scientist) | Clockwork |
|---|---|---|---|---|---|
| 01 | unit_ready | not wired (a line for every trained unit would be said all game long) | Ready for His Majesty's service. | Another splendid specimen. | Unit ready. |
| 02 | building_done | a building finished (3 s) | The work is finished, my lord. | Ah, it has taken root. | Construction complete. |
| 03 | research_done | a research finished (3 s) | Our craftsmen have mastered it. | Fascinating! They have adapted. | Research complete. |
| 04 | under_attack | your units attacked away from the camera (20 s; all alarms share a 15 s gate) | Our men are under attack! | Oh no, the Brood is under attack! | Our forces are under attack. |
| 05 | base_attack | your buildings attacked; the Brood: its rooted creatures (15 s) | To arms! The town is under attack! | Good heavens, they are attacking the nest! | Our base is under attack! |
| 06 | workers_attack | your workers attacked (20 s) | The labourers are under attack! | The poor grubs are under attack! | Winders under attack. |
| 07 | ally_attack | an ally's units or buildings attacked (25 s) | Our allies are hard pressed! | The Brood's allies are in trouble, I'm afraid. | Allied units under attack. |
| 08 | expansion | a new hall finished (3 s) | A new hall stands for the Crown. | A new nest! How marvellous. | New hall established. |
| 09 | building_lost | a finished building destroyed (6 s) | We have lost a building. | Oh, one has fallen. Such a pity. | A building has fallen. |
| 10 | site_lost | a building site destroyed (6 s) | The work has been stopped! | The growth has been torn away! | Assembly interrupted. |
| 11 | bad_place | a building can't go there (4 s) | We cannot build there. | It won't take root there, I'm afraid. | Placement invalid. |
| 12 | no_gold | not enough of the first resource (5 s) | The treasury is short of gold. | They're hungry. More food is needed. | Insufficient ore. |
| 13 | no_res2 | not enough of the second resource (5 s) | We need more powder. | The Brood needs more spoils. I'm afraid. | Insufficient energy. |
| 14 | no_supply | no supply left (5 s) | We need more cottages for the men. | The clutch needs more room. | More springs required. |
| 15 | depleted | a resource spot ran out (10 s) | This soil is spent. | This ground is quite exhausted. | Coal reserve exhausted. |
| 16 | victory | the match won | Victory! God save the King! | Magnificent! Nature triumphs! | Victory! |
| 17 | defeat | the match lost | We are defeated. | Oh... the end of a magnificent species. | We are defeated. |
| 18 | paused | the game paused | Hold. | Let us pause and observe. | Time halted. |
| 19 | resumed | the game resumed | Carry on. | Splendid. Let us continue. | Time resumed. |
| 20 | Crown: no_powder | your Musketeers or guns ran dry (25 s, with the "out of powder" note) | Our men are out of powder! | | |
| 21 | Crown: horse_stolen | an enemy took one of your horses (8 s) | A horse has been stolen! | | |
| 20 | Brood: mother_attack | your Brood Mother attacked (15 s; it took over base_attack for her) | | The Mother! Someone protect the Mother! | |
| 21 | Brood: sire_lost | one of your fathers (Tyrannosaur, Dilophosaurus, Pterodactyl) killed, once he has come (not a lure still ripening) (8 s) | | Oh dear. A Sire has fallen. | |

The Clockwork has no 20th and 21st lines yet (two are planned: units running down, a Mainspring fatigued).
The attack lines wait 3 s after the alarm and are not said while the camera is on the fight.

## Loudness

`tools/audio/import_announcers.py` levels every recorded line so its loudest 0.3 s (the measure of
tools/audio/make_mix.py) matches the median of the Clockwork announcer's lines (-17.7 dB); then each line's
entry in scripts/sound_mix.gd is about -0.2 dB, so in game they sit level with the Clockwork's and the music
(-18 dB). The quiet, sad Brood lines (09 building_lost, 15 depleted, 17 defeat, 14 no_supply) were raised the most
(+11 to +15 dB), so their background is a little louder too.

## Re-importing

1. Put the new MP3s in `art/audio_src/crown_herald/` or `art/audio_src/brood_scientist/`, numbered as in the table.
2. `python3 tools/audio/import_announcers.py` (or `... crown` / `... brood`): trims the silence (keeps 40 ms), fades,
   levels, mono, writes the .ogg files.
3. `python3 tools/audio/make_mix.py` writes the whole of scripts/sound_mix.gd again; to change only the announcers,
   copy just their new lines into the old file (the full run also moves other sounds that were tuned by hand).
4. `godot --headless --import`, then `godot --headless --script res://tools/test_announcers.gd`.

`tools/audio/make_voices.py` skips the Crown's and the Brood's announcers, so re-running it never overwrites the
recordings (`--kokoro-announcers` would, on purpose only).

A new key: add its recording for each faction that says it, add it to `SETS` in import_announcers.py and to
`STANDARD` / `EXTRA` in tools/test_announcers.gd (the test fails on a key the scripts play with no recordings).
