# Late-game sound (job late-game-sound, 0.35.15)

The owner's Cinder Steps watch (docs/playtests/2026-11-13_cinder_steps_notes.md, item 7): late in a big game "the
sounds were glitching more than the fps" (about 20 fps from 13:00, ~140 units, Clock Soldiers, Springers, cannons;
Windows desktop).

## The cause

**Every copy of a sound shared one player, and each new copy wrecked the ones still ringing.** `Sfx.play` kept one
`AudioStreamPlayer` per sound name (`max_polyphony` 6) and for every new copy it did `stream = ...`, `volume_db = ...`,
`pitch_scale = ...` on that player, then `play()`. In Godot 4.7:

- setting `stream` **stops every playback of that player** (`AudioStreamPlayerInternal::set_stream` calls stop), so
  the 6-voice polyphony never happened: each new Clock Soldier blow or musket shot cut the one before it off mid-sound;
- setting `pitch_scale` and `volume_db` changes **all** of the player's playbacks at once, so a far, quiet copy pulled
  a near copy's loudness down (and its pitch sideways) in the middle of the sound.

Early in a game a sound rarely plays again before it ends, so nothing shows. In a big fight the same few sounds come
every 110-200 ms (their GAPs) while lasting 0.4-1.5 s, so most of them are chopped and re-pitched: the clatter turns
into stutter and crackle. That is the "glitching", and it gets worse with more units of one kind, not with the fps.

The playtest's own SOUND LOG shows it: from 13:00 the busiest seconds have 5-8 `clock_soldier_attack`, 2-4
`springer_attack` and several `pendulum_attack` / `crown_death` a second, each on its single shared player.

What it was **not**, measured: the time spent in sound code is about 0.01-0.02 ms a frame (110-130 microseconds a
sound, ~8 sounds a second in the stress battles), so sounds are not what slows the game, and on Windows the mixer runs
on its own thread, so a 20 fps main thread does not starve it.

**The web build is different:** it is single-threaded (`variant/thread_support=false`), and there the engine mixes the
sound on the main thread whenever the browser asks. Its buffer was ~43 ms (50 ms default, rounded to 2048 samples at
48 kHz), shorter than a 50 ms frame at 20 fps, so in the browser a slow late game also runs the sound dry.

## What changed

- **A voice pool** (`scripts/sfx.gd`, `_take`): every fight sound gets a player of its own (polyphony 1) and nothing
  touches a player while its sound plays; each sound plays to its end with its own pitch and loudness.
  - at most `POOL_MAX` 24 fight sounds at once (players are made as needed, up to 24, and reused);
  - at most `SAME_MAX` 4 copies of one sound at once: a fifth copy only gets a player if it is clearly louder (3 dB)
    than the quietest copy, which then gives way, else it is dropped;
  - a full pool: the quietest sound gives way, counting how far it is through (a nearly finished tail counts as 12 dB
    quieter), else the new, quieter sound is dropped;
  - voices, horse calls and the bugle (tier 2) always get a player.
  - The old limits stay: each sound's GAP, the 6 new fight sounds per quarter second, the ducking under voices.
  - Unit voices and the announcer keep their own players, as before.
- **Web: a bigger sound buffer**: `audio/driver/output_latency.web=100` (project.godot): about 85 ms (4096 samples),
  enough for 50-80 ms frames. A click's sound may come ~40 ms later in the browser; nothing else changes. Desktop and
  Android keep the engine's default (their mixer has its own thread).
- Tools: `Sfx.legacy` plays the old way and `Sfx.test_clock` drives the sounds' clock from a tool;
  `tools/stress_swarm.gd ... sound` prints a SWARM sound line (`sfxold` = the old way); `tools/test_sound_pool.gd`
  checks the pool; `Sfx.clear_voices()` for tests that run faster than real time (test_brood_sounds,
  test_clockwork_sounds use it).

## Numbers

`tools/test_sound_pool.gd`: a minute of a late battle's sound mix (the log's busiest kinds, ~18 sounds a second):

| | sounds played | cut short by the next copy | players taken from a sounding tail | dropped | sounding at once (most) |
|---|---|---|---|---|---|
| old shared players | 1102 | **831 (75%)** | - | 0 | - |
| voice pool | 1102 | **0** | 43 (4%, all nearly finished) | 0 | 24 |

`tools/stress_swarm.gd pair ... sound`, headless, 60 s with a battle in view:

| battle | way | sounds a second | cut short a second | tails taken a second | sound code |
|---|---|---|---|---|---|
| Clockwork v Clockwork, 200 a side | old | 7.9 | **6.8** | - | 0.014 ms a frame |
| | pool | 8.0 | **0** | 0.6 | 0.017 ms a frame |
| Clockwork v Crown, 200 a side | old | 4.5 | **3.3** | - | 0.009 ms a frame |
| | pool | 4.8 | **0** | 0.4 | 0.010 ms a frame |
| Crown v Clockwork, 140 a side (40 s) | old | 7.0 | **4.7** | - | 0.013 ms a frame |
| | pool | 7.8 | **0** | 0.8 | 0.016 ms a frame |

(Headless measures the logic: the frame rates are not the owner's; the sound counts are per second of game time.)
At normal sizes nothing changes: few sounds overlap, and a lone sound plays exactly as before.

test_sound_pool, test_clockwork_sounds, test_brood_sounds and test_fog_sound_amove pass.

## Open questions for the owner

1. **Listen on Windows in a big late battle** (Cinder Steps again, or any 140-unit fight): the crackle should be gone.
   If some still comes, the next suspect is the Windows sound buffer: the job left desktop at the engine's default
   (15 ms); `audio/driver/output_latency.windows=30` is a one-line try.
2. **The numbers**: 24 at once and 4 copies of one sound. More copies make a fuller roar of muskets (a volley of 10 is
   still heard as a volley: each shot is 1-1.4 s long and up to 4 ring together, new ones replacing the oldest tails);
   fewer make it cleaner. Easy to change (`Sfx.POOL_MAX`, `Sfx.SAME_MAX`).
3. **The browser's 85 ms buffer**: the engine rounds the setting to a power of two of samples, so the real choice is
   2048 (43 ms, the old one, runs dry below ~23 fps) or 4096 (85 ms, the new one; any setting from 64 to 127 ms gives
   it). If clicks in the web build feel late, say so.
4. The Android APK was not measured on a device (its mixer has its own thread like Windows, so the pool fix is the
   one that matters there).
