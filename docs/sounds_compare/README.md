# Sounds to compare (2026-11-03)

Two things from the owner's playtest: the Brood's bites, and the end of the fife when the Barracks recruits.
Every file here is an .ogg you can play on the phone or the computer. Nothing in this folder is used by the game.

## 1. The bites (`bite/`)

**What was there before, and what is there now.** Up to 0.24.5 the Raptor's bite was made by the computer (no recording): a quick swish and a short "tok" snap. The bigger creatures (Tyrant Challenger, Tyrant Sire, Brute) had their growl over an older computer-made crunch. In 0.24.6 (30 October) every Brood bite was cut from the owner's sound pack: the "chomping" recording and the "monster bite" recording (`art/audio_src/brood/`), with the creature's growl over it.

**Why the bites now sound muddy (measured, since the files can't be listened to here).**
- The jaws close late. The cuts start before the real snap: the Raptor's first bite is loudest 0.23 s after it starts, so it sounds like a soft chew rather than a snap.
- The chomping recording is "boxy": most of its sound is in the middle (300 to 1500 Hz), with almost nothing bright on top, where the teeth would be.

Each file is a row of bites with a short gap between them. Every bite is set to the same loudness, so you hear the difference in the sound itself, not in the volume.

| File | What it is |
|---|---|
| `old_raptor.ogg` | The Raptor's 3 bites BEFORE 0.24.6 (computer-made swish and snap). |
| `new_raptor.ogg` | The Raptor's 3 bites NOW (a quick rasp, then a bite cut from the chomping/monster-bite recordings). |
| `new_grub.ogg` | The Grub's 2 bites now (the Grub had no bite sound before). |
| `old_tyrant_challenger.ogg` / `new_tyrant_challenger.ogg` | The Tyrant Challenger's 3 bites, before and now. |
| `old_tyrannosaur.ogg` / `new_tyrannosaur.ogg` | The Tyrant Sire's 2 bites, before and now. |
| `old_brute.ogg` / `new_brute.ogg` | The Brute's 2 bites, before and now. |
| `old_bite_layer.ogg` | The old computer-made crunch on its own (it was under every big creature's bite before 0.24.6). |
| `cand_a_tight_snap.ogg` | **Candidate A, tight snap.** The crispest bites in the pack, cut right at the moment the jaws meet, short, with the muddy middle turned down and the bright top turned up. |
| `cand_b_bone_crunch.ogg` | **Candidate B, bone crunch.** A, plus a dry crack under the snap (an egg shell from the pack, pitched down so it sounds like bone). |
| `cand_c_clack_crunch.ogg` | **Candidate C, clack then crunch.** The teeth clack first (a short bright crack), then the crunch 35 ms later: a two-part bite. |

Each candidate row plays, in order: **three Raptor bites** (each from a different recording and at a slightly different pitch), **one Grub bite** (higher), **one Tyrant Sire bite** (his growl as in the game now, with the new bite pitched down under it).

Measured against the bites now: the candidates hit their loudest point at about 0.06 s (now up to 0.23 s), last about half as long, and have about twice as much bright "teeth" sound.

**Pitch per play.** The game already plays every bite a little higher or lower each time (up to 7% either way), and each creature has 2 or 3 different takes. If you want more variety, that can go up to 10 to 12% for the bites only (one number in `scripts/sfx.gd`).

**The game's bites were not changed** (in 0.26.5). Pick A, B or C (or "none"), and it goes into the game for every Brood biter: Raptor, Grub, Tyrant Challenger, Tyrant Sire, Brute, Brood Mother, Rootmaw, Mound Turtle, Storm Sire, Storm Challenger, Hatchlings.

**The owner's answer (0.26.9): "For now use the old raptor."** The Raptor's bite in the game is the old one again, the one in `old_raptor.ogg`: the computer-made quick swish and short snap it had up to 0.24.5. It is remade exactly, bit for bit the same files as before 0.24.6, by `python3 tools/audio/make_sfx2.py combat/raptor_attack`, and played at its old loudness (`scripts/sound_mix.gd`). `tools/audio/make_brood_sounds.py` no longer makes the Raptor's bite, so running it again can't put the chomp back. Every other Brood creature keeps its bite from the recordings, as now. (`new_raptor.ogg` is now the bite the Raptor had from 0.24.6 to 0.26.8.) The candidates A, B and C are still here if you want to try one later.

Made by `tools/audio/make_bite_compare.py` (run it again to remake the folder).

## 2. The fife when the Barracks recruits (`flute/`)

**What was wrong.** The tune is four notes: F, B flat, C, then a long D. The recording only had a short D (0.6 s) with the band's drum under it, so the old tool stretched it by repeating the same 0.3 s piece five times. That made a stuttering "tok-tok-tok" under the held note for the last 1.5 seconds (the five repeats were exactly identical), and then the sound stopped short with almost no fade. There was also a low drum thump and hum (50 to 60 Hz) under the whole tune.

**The fix.** The last D is now a real long D from the same fife recording (the fifer holding it for a full second, with no drum under it). It fades out smoothly over its last half second and ends in silence. The low thump and hum under the whole tune were filtered out (the fife's lowest note is far above them). The first three notes are the same. The sound is now 2.9 s long (it was 3.8 s).

| File | What it is |
|---|---|
| `old_barracks_recruit.ogg` | The Barracks recruit fife as it was (the stuttering held note and the sudden end). |
| `current.ogg` | The fixed one (0.26.5 to 0.26.8; see the next part for the new ending). |

**The other Crown recruit sounds were checked for the same fault.** None has it: the Town Hall's bugle, the Foundry's kettledrums and the Horse Breeder's neigh have no repeated piece and all fade to silence. (The Town Hall bugle's last note fades in about 0.1 s, which is quick but clean; it is a bugle, which stops like that.)

Made by `tools/audio/make_recruit.py barracks` (the fix is the `barracks` part of it).

### The tune's ending (0.26.9)

**The owner, after 0.26.8:** "The current barracks sound is good, I like it ends with the fife. I just don't like the way it ends; I would like it to end similar to a tune ending; currently it doesn't make a lot of sense."

**Why it doesn't sound finished.** The fife is a B flat fife, and the little tune is in B flat. Its notes, measured from the sound itself, are F, B flat, C, D: in the scale of B flat that is the 5th, the home note (1st), the 2nd and the 3rd. Stopping on the 3rd (D) leaves the tune hanging, like a question. A tune sounds finished when it lands on its home note, B flat, usually by stepping down onto it.

**The two endings.** The start (F, B flat, C) is exactly as before in both. Every new note is a real note played by the fifer, cut from a part of the same recording where he plays alone with no drum (found by measuring the pitch of the whole recording; no note was pitched up or down). Both endings get a little room echo, so the last note dies away instead of stopping dead. Both are 3.5 seconds long.

| File | What it is |
|---|---|
| `current.ogg` | The ending in the game until now (0.26.8): the long D that fades out. |
| `cadence_a.ogg` | **A, step down home (in the game from 0.26.9 to 0.26.14).** The D is shorter (a long-short "dum-di" with the next note), then a quick C, then the home note B flat on the beat, held for a moment and dying away, with one snare drum stroke on it, like the band's last beat. 3, 2, 1: the most common way a march ends. |
| `cadence_b.ogg` | **B, the fifer's own ending.** After the C, the fifer's own little flourish exactly as he played it in the recording: a quick E flat, the D, and down to B flat. No drum, the fife alone. It sounds more like a real player and a little softer; the last note is a touch shorter than in A. |

If you prefer B (or want A without the drum stroke, or B with it), it is one word in `tools/audio/make_recruit.py` (`barracks(end="a")`). `python3 tools/audio/make_recruit.py compare` remakes these three files.

### The real fife and drums (0.26.15)

**The owner:** "For the barracks sound I want you to focus on the fife. That sound of drums and fife. Nothing else."

**What changed.** Until now the sound was built note by note: single fife notes cut from the recording and put in a row, the drum's low sound filtered away, a computer-made room echo added, and a snare stroke from another recording laid on top. Now it is **one piece of the recording as it was played**: the fifes and their drums together, at a place where the music itself comes to an end. Nothing is added: no echo, no pitch change, no filter except the deep rumble under 60 Hz (below any drum's body). Each cut starts on a note with its drum stroke and stops where the players stop, with only a very short fade over the last moment of sound.

The recording is `fife_music.mp3` (the one the fife notes were cut from). It is several fife-and-drum pieces in a row: some in B flat, one in F, one slow. The three places below were found by measuring where the drums and the fifes stop together and which notes the fifes land on (the files can't be listened to here).

| File | Where in the recording | What you hear, and how it ends |
|---|---|---|
| `fife_drums_1.ogg` | 0:01.7 to 0:05.4 (3.6 s), the opening strain | In the game in 0.26.15 and 0.26.16. A B flat march strain: the fifes (in two octaves) over a rolling snare. The tune climbs B flat, C, D, E flat to a long held F, then walks down F, E flat, D and lands on the home note B flat with a drum stroke. The fifes hold the B flat for half a second and let go together with the roll's last stroke. The end is quick: the players stop and the next strain starts right after in the recording, so there is no long ring, only their release. |
| `fife_drums_2.ogg` | 1:10.8 to 1:14.4 (3.6 s), the end of the slow piece | The slow tune's last bars, the fifes high and sweet: a held chord (A and C, the "almost there" chord), then they land on B flat with a big bass-drum stroke, and the drums close the piece with two more strokes (boom, boom, boom) that ring away into real silence. The most final-sounding of the three, but the fife is softer than the drums and is over after about a second and a half. |
| `fife_drums_3.ogg` | 0:12.8 to 0:15.5 (2.7 s), the end of the F major strain | A march in F: B flat chord, F chord, B flat chord, a held F chord, then one short last F chord stabbed together with the drum's final stroke ("ta-DA"). A firm, short "amen" close (the 4 to 1 chords) rather than a dying note. The shortest. |

All three are set to the loudness of the old sound, as far as the drum strokes allow without clipping (nothing squashes them); the game plays the Barracks sound 1.2 dB louder to make up for it, so in a match it is as loud as before.

### Fife and drum ending together (0.26.17)

**The owner:** "I like fife drums 2. But could you give us a couple more notes of fife in rhythm, to finish together fife and drum?"

**What changed.** Candidate 2 is kept as it was played (the held A and C chord, then the three big drum strokes, 0.62 s apart), but now the fife plays on with the strokes, one note per stroke, and its last note, the home note B flat, lands on the last stroke and is held through its ring, so fife and drum stop together. No other passage of the recording ends that way (the other piece endings either stop the drums first or run straight on), so the extra notes are laid in: each is a real note of the **same fifers in the same slow tune**, a few seconds earlier in the recording (same instruments, same tuning, nothing pitched up or down). Only the fifes' part of those notes is taken (everything above the fife's lowest note there), so the drums of that earlier moment don't come along. Each new note is as loud as the fifes' own held chord just before it. The drums' deep part (the boom, below 1,000 Hz) is turned down 4 dB in both, so the fife is nearer the drums than before. No echo or other effect.

| File | What you hear |
|---|---|
| `fife_drums_2b.ogg` | **Now in the game.** The held chord, then with the strokes the fifes walk down home: **D** (on the first stroke, with the B flat that was already there: the two fifes in harmony) - **C** (with the second fife a third above, on the second stroke) - **B flat** (on the last stroke, held for about a second while the drum rings, then let go). The tune steps 3, 2, 1, the most common way a march ends, so it sounds finished. Legato: each note runs into the next. |
| `fife_drums_2c.ogg` | Closer to the first version: the B flat on the first stroke stays short as it was played, a short gap, then the "almost there" chord (A and C) comes back on the second stroke and the fifes go home to the long **B flat** on the last stroke, held while the drum rings, as in 2b. Home, almost, home: more of a call and answer with the drum, a little more stop-and-go. |

If you prefer 2c (or the first version, 2), it is one name in `tools/audio/make_recruit.py` (`fife_drums("2b")` in `SOUNDS`), and the mix gain in `scripts/sound_mix.gd` goes to what `python3 tools/audio/make_recruit.py fife_drums` prints for it (2b -1.3, 2c -0.9, 2 -1.2), so it stays as loud as before. The notes and where they come from are `FIFE_ON` in that file.

If you prefer 1 or 3, it is one number in `tools/audio/make_recruit.py` (`fife_drums("2b")` in `SOUNDS`). `python3 tools/audio/make_recruit.py fife_drums` remakes these files (1, 2, 3, 2b, 2c); `python3 tools/audio/make_recruit.py barracks --built` puts the old note-by-note tune (`cadence_a.ogg`) back.
