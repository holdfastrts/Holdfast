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
| `cadence_a.ogg` | **A, step down home (now in the game).** The D is shorter (a long-short "dum-di" with the next note), then a quick C, then the home note B flat on the beat, held for a moment and dying away, with one snare drum stroke on it, like the band's last beat. 3, 2, 1: the most common way a march ends. |
| `cadence_b.ogg` | **B, the fifer's own ending.** After the C, the fifer's own little flourish exactly as he played it in the recording: a quick E flat, the D, and down to B flat. No drum, the fife alone. It sounds more like a real player and a little softer; the last note is a touch shorter than in A. |

If you prefer B (or want A without the drum stroke, or B with it), it is one word in `tools/audio/make_recruit.py` (`barracks(end="a")`). `python3 tools/audio/make_recruit.py compare` remakes these three files.
