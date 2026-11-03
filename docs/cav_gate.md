# Horsemen at a shut gate (0.25.26)

The owner's playtest, 2026-11-01 (AI Crown v AI Crown, Ashfall 2p, seed 1864215939, 0.25.25; log and pictures in
`docs/playtests/ai_crown_v_crown_2026-11-01/`, problem 2, `2_horsemen_at_gate.jpg`, about 7:41):

> at the ramp the horsemen didn't attack the gate. They kept galloping to it and got stuck in it, not attacking it.
> They had a real chance to destroy it because the green player was caught off his base, and if the workers came to
> repair, officers can shoot them with pistols, but instead the horseman didn't even attack the gate.

## What went wrong

Yellow's riders were its **raiding party** (`AI._raid`: after its Horseman rush failed at 4:15 the raids came back at
about 6:45, up to 4 riders; the log has no "first attack goes out" line for yellow, so it was not a wave). A raid rides
at the workers with `AI._hunt`, and `_hunt` rides on a **plain move** (attack-move only with an enemy soldier near).
The workers were behind green's ramp wall, on the high ground, where riders below can't see them (`game._stamp`: from
low ground only the next cells of high ground are seen). So:

- no worker in sight, no soldier near: a plain move to the prey spot, through the gate (paths treat gates as open);
- the unit's own wall rules (`Unit._walled_check`, the stuck rule in `Unit._move`, `_attack_detour`) only act on
  attack-move, idle or attack orders, never on a plain move: the riders pressed at the gate for good.

Attack-move and attack orders were already fine for riders (tests 1 and 2 below passed before the fix: a rider stands
and hacks at a wall piece, `RideBy.steer` hands a wall to `Unit._engage`).

## The fix

**Unit level, the hunt (`AI._hunt`)**: a rider on a plain move with an enemy wall or gate piece beside him
(`game.blocking_wall`) and no way on foot to his prey switches to attack-move to it; the unit's wall rule then breaks the
piece in the way. While he hacks at it (attack-move with a building target) `_hunt` leaves him to it.

**AI level, the raid (`AI._raid_wall`, called from `_raid` each think)**: when the party can't walk to its prey it
weighs the wall up as one, like the wave's siege (`_siege_plan`) but simpler:

- the piece to break: `_piece_to_break` (the enemy wall or gate nearest the prey that the party can walk up to; it was
  written before and never used);
- the race (`_raid_weigh`): the riders' blows on it less the repair of the menders **it can see**, against the fire of
  the defenders **it can see** that reach the piece's outer face. It goes in when the piece comes down within
  `RAID_BREAK_MAX` (45 s) and in under 0.6 of the time the defenders need to cut the riders down;
- going in: the riders spread over the pieces within `RAID_LINE` (100 px) of it, two to a face (a one-tile piece has
  room for about two horses; the rest stood behind out of reach, and one rider's 14.5 dps never beats one mender's
  25 hp/s), and a labourer can only mend one piece at a time. A rider with his pistol loaded attacks a mender he can see
  in pistol reach (the pistol fires in passing, `RideBy.blows`); one in sabre reach across the piece is cut at;
- giving up: the piece won't go down in time, or the party has been at it `RAID_STALL` (30 s) with every piece of that
  stretch still above 80% (menders hidden on the high ground show as this). The wall is left be for `RAID_SHUT_FOR`
  (90 s) and the party rides for workers or economy buildings it **can** walk up to (`_open_prey`: an expansion, a farm
  outside the wall; at most 8 path checks), else home, and no party forms for `RAID_BLOCK` (45 s).
- It writes one match-log line per decision: "yellow's raid breaks in at the gate in the way: down in ~N s (M menders,
  D dps of fire on it)", "... finds the way to the workers shut (why): it rides for workers it can get at / it rides home
  and comes again later", "... is through the wall: after the workers".

A cavalry **wave** (the Horseman rush on the Rush plan, `_army`) was already covered by the wave's siege
(`_siege_tick`); test 7 checks it.

### About the pistols and the menders

The owner expected the pistols to shoot the workers who come to mend. They do, **when the riders can see them**: a
mender out on the ramp side of the wall is shot or cut (test 6). Menders behind the wall at the top of a ramp are on the
high ground and hidden from riders below (the high-ground rule, a defender's advantage, `docs/design_principles.md` 2
and 5); the computer does not count or shoot what it can't see. Against two hidden menders the four riders, spread
over the gate and the palisade, still broke a piece in about 40 s in the test; if they hadn't, the stall rule sends them
off. If the owner wants riders to see a little way over a wall they are hitting (a mender at the piece always visible),
that is a vision rule change, not made here.

## Test

`tools/test_cav_gate.gd` (Ashfall, the playtest's seed; green's own ramp wall from `AI.plan_cottage_wall`: Cottage,
palisade, gate; green's soldiers removed):

    godot --headless --fixed-fps 30 --script res://tools/test_cav_gate.gd
    xvfb-run -a godot --rendering-driver opengl3 --resolution 1000x700 --fixed-fps 30 --script res://tools/test_cav_gate.gd -- shots docs/shots/cav_gate

| # | case | before (0.25.25) | after (0.25.26) |
|---|------|------------------|-----------------|
| 1 | 2 Horsemen ATTACK-MOVE past the gate | strike | strike |
| 2 | 2 Horsemen ATTACK a Labourer behind the gate | strike | strike |
| 3 | the computer's hunt for a Labourer behind the gate | **never strike, order move, 7 px from the gate** | strike |
| 4 | the raid (4 Horsemen), unmanned wall | **nothing down in 90 s** | a piece down in 12 s |
| 5 | the raid vs two hidden menders | **nothing down in 120 s** | a piece down in ~40 s (or it gives up within 45 s) |
| 6 | the raid vs a mender on the ramp side | - | mender shot or cut, a piece down in 12 s |
| 7 | a cavalry wave (4 Horsemen), no defender | - | a piece down in 10 s |

Pictures: `docs/shots/cav_gate/` (`hunt_strikes_gate.png`, `raid_none.png`, `raid_inside.png`, `raid_outside.png`,
`wave.png`).

Other tests run on 0.25.26: `tools/test_pathing.gd` (the same 3 Brood `rim_click_from_low` failures as on 0.25.25,
unrelated), `tools/test_ai_harass.gd` (passes; one run showed the known flaky Clock Soldier/Sire lines, the same on
0.25.25), `tools/test_ai_wall_vs_rush.gd` (the known open "3 Musketeers by 2:40" line only). `tools/test_ride_by_raid.gd` stops
at its set-up ("no open ground for the test" on Hollowfen), before any AI code runs: to look at separately.

## 0.26.3: the Cottage + Gate ramp wall

0.25.28 (`AI.cw_prune`) made the computer's ramp wall a Cottage and a Gate only. On merged main test case 6 failed: at
0 s the raid said "walled with nothing it can break" and rode home. Cause (behaviour, not the test's set-up):
`_piece_to_break` checked reachability against a fresh `_prey_spot`, which by then named the mender standing on the
riders' side of the wall (reachable), so it returned no piece. Fixed: it checks the spot the raid is going for. Also:
the ramp Cottage counts in the stretch the riders strike (`_raid_line`: the gate has room for two horses, the Cottage's
faces for the rest), and a visible mender the riders can get at is counted as hit points to cut through, not as
repair for good (`_raid_weigh`). All 7 cases pass on 0.26.3.

## Open

- The wave's siege sim and the raid's race are two separate estimates; they could share one.
- `AI._raid`'s danger check (armed enemies within 260 px) still counts units the raid can't see.
