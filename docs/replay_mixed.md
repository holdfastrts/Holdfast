# Mixed replays

Version 0.29.5 (branch replay-mixed). Settings > GAMEPLAY > REPLAY RECORDING has a new choice, MIXED, and it is the
default on phones and tablets. A mixed replay is recorded the way StarCraft 2 records one, plus a whole picture every
ten seconds. It costs almost nothing while you play, and the file is about a quarter of the size. The price is that it
plays the match again rather than showing pictures of it, so it is close to what happened but not exact.

## What is recorded

1. **Every player's commands**, with their game times. Everything a player orders goes through one funnel already
   (the online mode needs it: scripts/net/net_commands.gd), so the recorder is told at that one place
   (Game.net_forward and Game.net_set call ReplayRecorder.note_cmd). An online host records its friends' orders the
   same way. A unit or building in a command is written with its id, and also its kind, side and place, so the
   viewer can find one its own game made.
2. **The computers' decisions.** The computer players don't use the funnel: their AI orders units directly. So twice
   a second the recorder looks at each computer unit's order and each computer building's queue and rally, and writes
   down what changed: a new order (move here, attack that, gather there, hold), a new queue, a new building site. A
   unit stopping because it got where it was going is left out (it stops by itself in the replay too), and so is a
   soldier picking its next target in a fight.
3. **A keyframe every 10 seconds**: the whole match as a saved game keeps it (SaveGame.capture: every unit and
   building with its health, queue, kit and the rest, every player's resources and research), plus each unit's id,
   its order and, for a worker, where it is in its round (on its way, at work, carrying back).
4. The chat, the AI STORY lines, who was out and who won, and the recording player's camera twice a second (and
   online every friend's), as before.

The file is the same kind of .hfr file, format 3, with two new kinds of record: a keyframe (zstd packed) and the
commands since the keyframe before (zstd packed), written every 10 seconds, so a crash still keeps all but the last
ten seconds.

## Watching

The viewer opens the match's map and puts the keyframe before the time asked on it. Then the game itself plays on
from there: the units walk, fight and work by the game's own code, the recorded commands and computer decisions are
given at their times, and at each next keyframe whatever drifted is put right: every unit glides to where the keyframe
has it (in half a second; one more than 360 px off is put there), health, orders, queues, resources and research are
set as they were, a unit or building the viewer's game made that the match didn't have goes, and one it is missing is
made.

The computers' AI does not run while watching. That was the first version: the AI made anew, playing its side again.
It drifted three times as far (below), because the AI simply decides differently each time, and a fresh AI after a
jump reorganises its army at once. With its decisions recorded, every side is played the same way: its orders as
given.

Speed: the game's ticks run faster (2x is twice as many ticks a second, each one as long as in the match), so 4x costs
four times the work of playing; on a slow phone 8x may not keep up and simply runs slower.

A jump on the timeline puts the keyframe before it on the map, then runs the game forward to the time asked, silently
and as fast as the device can (up to 40 times). The bar's clock races to the time meanwhile.

Everything else is as in the picture replays: the timeline, the speeds, FOG and CAMERA, selecting anything (no order
can be given: the viewer's clicks are dropped at the funnel), the observer bar, the chat and the AI STORY at their
times.

## Why it drifts

The game is not the same run to run (docs/pathfinding_audit.md, tools/test_determinism.gd: the path queue's time
budget, the order in which units are looked at, rounding), and a keyframe is a saved game, which leaves things out
(each unit's path, what a soldier is aiming at, a worker's exact step on a farm). So from a keyframe the replay's
units do what they did in the match, but not to the pixel: a soldier picks another target, a fight goes a little
differently, a worker on a farm wanders another way. The keyframe 10 seconds later puts it right.

## Measured

tools/test_replay.gd rec:mixed, two Hard computers on Hollowfen, --fixed-fps 60, on this shared 2-CPU cloud machine.
"Normal" is the match on its own (26 units at 2:00, 97 at 5:00); spawn:50 adds 50 Musketeers and 50 Raptors marching
about in the middle (about 125 units); spawn:100 about 215 units. FULL and LIGHT are the picture replays, measured
the same way on the same version.

### Recording, ms per second of match

| | FULL | LIGHT | MIXED |
|---|---|---|---|
| normal, 2:00 to 5:00 (60 to 97 units) | 6.55 | 3.34 | MIX50 |
| big battle, about 125 units | 9.67 | LIGHT120 | MIX120 |
| big battle, about 215 units | 11.36 | LIGHT200 | MIX200 |

MIXED's cost: MIXSPLIT. A phone is about four times slower: about 40 ms a second at FULL and 20 at LIGHT in a big
battle (2 to 4% of its time, where FULL already drops toward 3 pictures a second), against about MIXPHONE at MIXED.

### File size, KB per minute

| | FULL | LIGHT | MIXED |
|---|---|---|---|
| normal, 5 minutes | 101 | 64 | SZ50 |
| big battle, about 125 units | 172 | SZL120 | SZ120 |
| big battle, about 215 units | 227 | SZL200 | SZ200 |

### Drift: how far a unit is from where it really was

From the middle of a 5-minute big battle (about 125 units, spawn:50), at three keyframes: first 10 seconds with the
corrections turned off, then 30 seconds with them (three keyframes). Each unit with an id, twice a second, against
its true place in the match at that moment.

DRIFTTABLE

### Seeking

SEEKTEXT

## Old replays

A picture replay (format 2) plays exactly as before (ReplayPlayer, the puppet game): ReplayFile.is_mixed picks the
viewer from the header. FULL and LIGHT can still be chosen in Settings. Online, the host's pictures for its friends
are NetSession's own and are untouched; the host records MIXED when that is its setting (its friends get the mixed
replay at the end and watch it the same way); a friend's own fallback record (its view only) stays a picture record,
at LIGHT's rate when the setting is MIXED, since a friend's game simulates nothing.

## The settings

| Choice | What it records | Default |
|---|---|---|
| MIXED | the commands, the computers' decisions, a keyframe every 10 s | phones and tablets |
| FULL | 5 pictures a second | computers and the browser |
| LIGHT | 2 pictures a second | |
| OFF | nothing (online the host still records, at LIGHT) | |

FULL stays the default on computers and in the browser: there recording at FULL is about 1% of the time, and its
replays are exact and cheaper to watch (nothing is simulated). On a phone late in a big match MIXED is the one that
matters.

## The code

| Where | What |
|---|---|
| scripts/replay/replay_mix_recorder.gd | ReplayMixRecorder (a ReplayRecorder): note_cmd, _diffs (the computers' decisions), key (the keyframe) |
| scripts/replay/replay_mix.gd | ReplayMix (a ReplayPlayer): play_mixed, seek (restore + fast-forward), _correct (the keyframe put right in place), _give (a command), _decision |
| scripts/save_game.gd | capture(game, cfg, replay): ids, orders and worker steps; restore puts the ids back |
| scripts/replay/replay_file.gd | T_KEY, T_CMDS, unpack_key, is_mixed |
| scripts/game.gd | net_forward / net_set: the recorder hears each command; a mixed replay drops the viewer's clicks |
| scripts/main.gd | REPLAY RECORDING MIXED; a mixed replay's game is a real one (not a puppet) with no AI |

## Tests

`godot --headless --fixed-fps 30 --script res://tools/test_replay.gd -- rec:mixed` (also secs:300 spawn:50 for a big
battle): the recorder writes keyframes and commands; the replay opens a real game (no puppet, no AI); half a second
after a keyframe units are within a few px of their true places; the drift without and with the corrections, and the
bounds (95% of units within 250 px 10 s after a keyframe without corrections, 150 px with them); the commands are given
again; a seek lands on the time asked with nothing stale; pause holds the clock; the viewer's click orders nothing; a
seek to the end stops there. `rec:full` and `rec:light` still test the picture replays, old files included.
`recordonly` stops after the recording (the cost tables).

## What is rough

Drift is real: in a big battle a unit is typically 10 to 30 px from its true place, and some are 100 or more by the
end of a 10-second stretch (a fight that went the other way); the keyframe puts it right with a half-second glide,
which shows as units sliding a little every 10 seconds in a big fight.

A seek in a big battle on a phone can take a few seconds (it plays up to 10 seconds of the match forward).

What the keyframe doesn't put back in place on the running game: the Clockwork's rail line and trains, the Brood's
ground, the fog's explored ground (a seek starts them from the keyframe; a correction leaves the running ones).

Orders the computers give that aren't a plain order (a spell, a tongue, mounting, unloading a balloon) are not among
their recorded decisions: they happen in the replay only if the replay's own unit does them, else the keyframe puts
the result right.
