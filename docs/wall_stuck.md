# Units stuck at a half-built wall (0.26.3, branch wall-stuck)

The owner's playtest (AI Crown v AI Crown, 0.25.25, Ashfall, 2026-11-01; docs/playtests/ai_crown_v_crown_2026-11-01/,
problem 3): "a half completed wall stuck 5 musketeers indefinitely ... they could have just walked up because the
wall wasn't finished to the north." Picture: 3_musketeers_stuck_wall.jpg, about 8:34.

## What it was (not the diagonal)

The new diagonal pieces and their corner guard (docs/wall_diag.md) were not the cause, and neither was the
pathfinder: built pieces and pieces going up are solid both to the pathfinder and to the movement test, planned
pieces are open ground to both. A plain MOVE past the same half-built wall, diagonal or straight, walks round its
open end every time (tools/test_wall_stuck.gd, before and after).

It was the ATTACK-MOVE (which is what the computer's waves use), three faults that fed each other:

1. **An attack-move ended where its last fight was.** A unit that chased a man (its path now led to him) or shot at
   one from where it stood (its path dropped), and saw him die or let him go, walked the old path's end, or took the
   empty path for "there", and stopped: order over, IDLE, often hundreds of pixels short of where it was sent.
2. **Units picked a wall piece by themselves.** With nobody else in sight a palisade piece is a target (Game.find_target
   adds 400 to its distance, but it is still picked when it is all there is). So an attack-move, or a unit standing idle
   after (1), went up to the wall and shot or stabbed at it, though the way round was open. A palisade has 200 hp and
   armour 2, and its labourers were building and mending it: "forever". Dry Musketeers (no shots left; Crown green had
   1 powder) fix bayonets, so they stood right against it, as in the picture.
3. **Jostling at a wall counted as "walled out".** A unit stuck for 1.2 s next to an enemy wall took the piece for its
   target, whether or not it could walk round (for a shooter, whenever its man was out of range).

## The fix (scripts/unit.gd, scripts/game.gd)

- `Unit._walled_out(p)`: can `p` be walked to (enemy gates shut; built pieces and pieces going up in the way; planned
  ones open)? Asked at most every 2 s for the same spot.
- Attack-move: a wall or gate piece is picked by itself only when the place it was sent to is walled out
  (`_pick_target`); one it is hitting is dropped, and it goes on, as soon as the way is open (the amove branch, and
  `_headway`). Ordered attacks on a piece and the computer's sieges (attack orders, `siege_t`) are untouched.
- Attack-move with no target: if its path does not lead to where it was sent (or was dropped), a fresh path there
  first; it only stops when it gets there (or its path ends at a wall that really shuts it out: it breaks that piece).
- Idle: a wall or gate piece only if it can hit it from where it stands (it no longer walks off to hack at a palisade).
- Stuck against a wall: it takes the piece for its target only when walled out from where it is going or from the
  man it is after (`_walk_reaches_cached`), else it repaths.
- A piece going up (solid, not built) can be what shuts units out: `Game.blocking_wall`, `Unit._wall_toward` and
  `_any_enemy_wall` now count it (they looked at built pieces only, so men walled out by one pushed at it for good).
  The computer's siege planner (AI._siege_plan) still weighs built pieces only.
- General safeguard, `Unit._headway`: a unit that has wanted to move for 3 s and got under 14 px gets a fresh path
  (and drops a wall it took by itself if the way is open). In a crowd pressed against a wall every man is shoved a
  little each tick, so the old stuck timer, which wants no movement at all, never filled.

## Test

`tools/test_wall_stuck.gd` (headless; `-- shots` under xvfb writes docs/shots/wall_stuck/): an enemy wall, 9 or 10
pieces, the first two only planned (the open end), the third going up, the rest built; diagonal ("\\", as in the
playtest) and straight. Squads sent past it: Musketeers, dry Musketeers, Horsemen (attack-move), Musketeers (move),
and dry Musketeers and Horsemen started pressed against the wall; an enemy labourer standing behind it. Each must get
round the open end within 40 s, nobody hitting the wall, nobody standing 4 s without headway. Then: a finished, closed
box keeps a plain move out; an attack-move into the box, one piece still going up, breaks a piece.

Before the fix 10 of the 12 squad cases failed (every attack-move: all of them hacking at the wall, none there); the
two plain moves passed. After: all pass. tools/test_wall_diag.gd, test_wall_drag.gd and test_pathing.gd still pass.

Pictures: docs/shots/wall_stuck/half_built_diagonal.png (the test's wall: two planned pieces at the open end, one
going up, the rest built); before_fix_dry_musketeers_amove_6s.png (0.25.25, six seconds in: the dry Musketeers on an
attack-move standing at the built pieces, bayonets on the wall, though the end is open).

Merged with main 0.26.2 (0.26.1's Horsemen at a shut gate, docs/cav_gate.md, go on attack-move only when the prey
can't be walked to, which agrees with the rule here); tools/test_cav_gate.gd passes.
