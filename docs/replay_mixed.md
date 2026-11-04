# Mixed replays

Version 0.29.5 (branch replay-mixed). Settings > GAMEPLAY > REPLAY RECORDING has a new choice, MIXED, and it is the
default on phones and tablets. A mixed replay is recorded the way StarCraft 2 records one, plus a whole picture every
ten seconds. It costs almost nothing while you play, and the file is a quarter to a third of the size. The price is that it
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
3. **Every death**, any side's, in the same look twice a second: in the replay that unit falls then too. Without it a
   big fight drifted four times as far: the soldiers that had died in the match kept fighting in the replay until the
   next keyframe, and the fights around them went another way.
4. **A keyframe every 10 seconds**: the whole match as a saved game keeps it (SaveGame.capture: every unit and
   building with its health, queue, kit and the rest, every player's resources and research), plus each unit's id,
   its order and, for a worker, where it is in its round (on its way, at work, carrying back).
5. The chat, the AI STORY lines, who was out and who won, and the recording player's camera twice a second (and
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
| normal, 2:00 to 5:00 (26 to 97 units) | 6.55 | 3.34 | 0.65 |
| big battle, about 125 units (the whole 5 minutes) | 9.67 | 4.61 | 1.32 |
| big battle, about 215 units (the whole 4 minutes) | 11.36 | 5.95 | 1.50 |

MIXED's cost in the 215-unit battle: keyframes 0.43, packing and writing them 0.24, the computers' decisions and the deaths 0.75
(looking at every unit twice a second), the players' commands 0.08. A keyframe there takes about 6 ms in one frame
every 10 seconds (the pictures' keyframes took about as long). In the big battles the test's own marching orders (50
soldiers a side sent somewhere every 4 seconds, as a player would) are about a third of the commands and the
decisions; a normal match writes far fewer. A phone is about four times slower: about 40 ms a second at FULL and 20 at LIGHT in a big
battle (2 to 4% of its time, where FULL already drops toward 3 pictures a second), against about 5 to 6 at MIXED (about half a percent).

### File size, KB per minute

| | FULL | LIGHT | MIXED |
|---|---|---|---|
| normal, 5 minutes | 101 | 64 | 27 |
| big battle, about 125 units | 172 | 110 | 57 |
| big battle, about 215 units | 227 | 154 | 70 |

### Drift: how far a unit is from where it really was

From the middle of a 5-minute big battle (about 125 units, spawn:50), at three keyframes: first 10 seconds with the
corrections turned off, then 30 seconds with them (three keyframes). Each unit with an id, twice a second, against
its true place in the match at that moment.

Distance from the true place (px; a tile is 32 px, a soldier about 30 px tall): mean / 95% of units within / worst.

| | about 125 units | about 215 units |
|---|---|---|
| half a second after a keyframe | 4 / 19 / 86 | 10 / 64 / 128 |
| 1 s after, no correction | 9 / 33 / 115 | 11 / 42 / 96 |
| 2 s after, no correction | 14 / 44 / 96 | 19 / 72 / 207 |
| 5 s after, no correction | 22 / 56 / 120 | 29 / 100 / 512 |
| 9.5 s after, no correction | 37 / 170 / 260 | 31 / 110 / 664 |
| with the corrections, every sample over 30 s | 27 / 104 / 499 | 27 / 112 / 962 |
| ...1 s after each keyframe (its glide done) | 13 / 49 / 201 | 12 / 50 / 335 |

So without the keyframes a replay drifts about half a tile on average in 10 seconds of a big battle, with one unit
in twenty off by 3 to 5 tiles (in a fight that went another way). The keyframes keep it there: on average under a
tile, and right after each one about a third of a tile. Half the soldiers are within half a tile all the time
(the median, not shown: 12 px). In a normal match (few soldiers, mostly workers) it is about the same: 95% within
112 px 10 s after a keyframe, 73 px with the corrections; the workers on a farm wander there differently, which is
most of it.

How the first versions did, in the 125-unit battle, 10 s after a keyframe (95% within): the AI run again instead of
its decisions recorded: 263 px (mean 93); the decisions recorded four times a second: 82 px, at twice the cost of
looking (1.5 ms a second instead of 0.7); without the deaths recorded, at 215 units: 493 px (a big fight went
another way within seconds: the units that had died in the match kept fighting in the replay).

### Seeking

A jump runs the game forward from the keyframe before it, about 4 to 8 times as fast as the match on this machine:

| | about 125 units | about 215 units |
|---|---|---|
| 5 s past a keyframe | 1.1 s | 1.9 s |
| 9.5 s past a keyframe (the longest) | 3.2 s | 3.0 s |

A jump onto a keyframe itself takes about a tenth of a second (putting it on the map). On a phone, about four times
slower, a jump in a big battle can take several seconds; the picture replays jump in 0.07 s here (they only read
pictures forward). Keyframes every 5 seconds would halve the jumps for about 0.5 ms more a second of recording: a
choice for the owner.

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
