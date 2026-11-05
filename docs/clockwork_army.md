# The Clockwork fights as one army (branch clockwork-army)

Short sentences, to be read aloud.

The owner, 2026-11-05 at 09:24, watching the Hard Clockwork on Economy against the Hard Brood on Economy, Frostfang, 0.31.0
(his log: docs/playtests/2026-11-05/spectate_clockwork_econ_v_brood_econ_frostfang_0310.txt, his picture:
clockwork_army_split_0638.jpg): "I think the Clockwork played mostly well, but it could have started massing army a bit
sooner. What really troubled me is that it kept sending 1 or 2 Clock Soldiers to die instead of using the Pendulum and
Springers it had. Most of the time the army has to be together; I don't understand why the Clockwork behaved like that.
It should have massed the army with Winders to repair and wind and squashed the Brood; it could have done that."

No unit, building or research number was changed. Ideas for numbers are proposals at the end.

## The short version

@@SHORT@@

## What was wrong

The Clockwork computer had no army of its own. It used the shared computer's army rules (scripts/ai.gd, AI._army), and
those split the army over half a dozen jobs, each taking a unit or two:

- **The scout.** From its second trip with nothing seen, the shared scout takes the fastest idle army unit. For the
  Clockwork that was a Clock Soldier: "sends a Clock Soldier to scout again (trip 3)" at 5:08 in the owner's game. It
  walked alone into the Brood's Raptors.
- **The harass.** A soldier found out alone far from home becomes a harasser (AIHarass.adopt_strays). The Clock Soldier
  was the one exception the shared rule kept as a harasser, so a stray Clock Soldier went on alone at the enemy's workers.
- **The round-5 guard.** Riders at the Winders draw three to eight Clock Soldiers "to the Winders the riders hit" (5:36),
  and with ten soldiers a few hold the ramp. Those groups stood away from the rest.
- **The detachments.** Each raid on a building got "as many soldiers as the visible enemy needs", and a lone fast raider
  (a Raptor pair) up to four catchers on a leash. In practice one or two at a time ran out, chased, came back, ran out.
- **The rally.** What was left waited in front of the main hall, not the forward Clocktower. The Springers, the Netter and
  the Pendulum came out of the Works and Heavy Works where they were made. The owner's picture at 6:38 shows exactly that:
  the Pendulum and Springers by the second base's Works, a few soldiers by the main, Winders fighting riders alone.
- **The waves.** The shared attack sends a wave once it reaches a supply number, and fresh units join it "as a group of 6
  supply": three Clock Soldiers walking across the map to wherever the wave is, fighting what they meet on the way.
- **The escort.** The Winders that wind and mend the army followed the middle of ALL the army, which, split like this, was
  an empty spot between the groups. And a Winder near an enemy ran home like any raided worker (only against a swarm did
  it stay). In the Heavy Works push the Winders by the army were 0.5 on average.
- **No massing.** On Economy the opening's soldiers came only at its last steps (the first at 4:20, five at 5:00).

What the old code did, measured in the coached "before" games below: on average 9.6 times a game a Clockwork fighter fought
with no other fighter of its own within 6 tiles (6.0 of them away from its buildings), and 1.6 fresh units a game had
their first fight alone, away from home.

## The fixes

### One army (scripts/ai_cw_army.gd)

The Clockwork computer (Normal and up, gear mode) now keeps ONE ARMY. Every combat unit belongs to it, except the units a
plan sends on its own errand (the Springer raid, the Clock Soldier rush, the Owl raids). The shared scout, harass, round-5
guard, detachments and rally no longer take any of it.

- **One gathering point.** At home the army stands together in front of the Clocktower nearest the enemy (on that
  Clocktower's ground, the way in). Every unit made walks there. The escort Winders keep it wound and mended there.
- **Raids are met by a group or by the whole army.** An armed raid worth little next to the army is met by the nearest
  units worth 1.5 times the raid, never fewer than three. A raid worth 45% of the army or more is met by the whole army; the
  ones ahead of the rest wait for them on the way; one led off after a runner comes back to the others. When the raid is
  over, or when a defender is led 16 tiles from the buildings, they walk back to the gathering point. If the whole army is
  worth less than 55% of a raid away from the main, it does not walk into it: it holds together at the main's gate.
  Unarmed scouts and loose workers are left to the Winders and the turrets.
- **No fighter scouts.** The scout's second and later trips take a Swift if there is one, else a Winder, never a ground
  fighter.

### It goes out as one block: the push for every plan (scripts/ai_cw_push.gd)

The Pendulum and Heavy Works plans already had a good way to move an army: THE PUSH. One anchor point walks along the path
a step at a time, only when the front is at it and the slow machines are close behind, so the block moves at the pace of
its slowest unit. The front (Clock Soldiers, Pendulums, Springers, Netters) stands in a line at the anchor; the Ballistas
and the Great Winder behind; the escort Winders behind the front. It fights as a line, sieges a wall, pulls back as one,
and fresh units join it as a group walking to the anchor.

Now every Clockwork plan attacks with it: Economy, Balanced, and the Springer timing and Clock Soldier rush after their
openings. Small fixes to the push with it:

- the escort Winders out with the army stay with it in a fight, winding and mending, instead of running home like a
  raided worker (AIClockwork._escort_stays);
- a Spring Ballista led more than 12 tiles from the anchor in a fight walks back behind the block;
- against the Crown, a push without Ballistas goes up to the enemy's main only once it is worth 2,000; until then it holds
  short of the main and kills what is outside (14 Clock Soldiers stood under a Crown main's cliff for two minutes in the
  first test game and lost 1,400);
- the push's own units no longer include the units of the other plans' errands.

### It goes out only stronger than the enemy it knows

Before a push goes out the army's word is asked (AICwArmy.may_launch):

- **The reckoning.** The enemy army it reckons is what it saw in the last two minutes, but never less than an enemy of that
  age has (a table per faction, from the coached games: for the Brood the Crown's crown-v-brood table, raised before 7:00),
  less half of what it has killed. Unknown never counts as nothing. Against the Brood the rooted Rootmaws and Mound Turtles
  it has seen count too, one and a half times: the push's goals are those, and rooted they fight hard.
- **Stronger.** It goes only worth 1.25 times the reckoning (the Pendulum and Heavy Works plans, which have their own
  needs, 1.0 times).
- **A fresh report.** It goes only if an enemy soldier was in sight, or the enemy's main was looked at, in the last 75 s.
  Otherwise it asks the scout to go now and holds.
- **After a failed push.** A push that had to pull back is news too: the next one goes only worth 1.25 times what that one
  had.
- Not while the army at home is busy with a raid, and not into a big swarm before the Pendulums are out (the swarm rule).

Meanwhile it holds at its gathering point, near its bases.

### It uses its kit

- **The Springers jump in** when the front engages: a ready Springer, not hurt, whose nearest enemy is beyond its shot but
  within a jump and a shot, leaps to a spot in shooting reach of it, on our side, where no enemy melee stands close and the
  enemies near the spot are not worth more than our front (AICwArmy.spring_in).
- The Pendulums walk into the thickest knot of enemy foot and the Netters net the most dangerous fighter in reach, as
  before (AI._micro, _pendulum_aim, _netter_aim). They now do it beside the rest of the army.

### It masses sooner

On Economy and Balanced, once the second Clocktower's two presses are laid, every Light Works that stands idle trains a
Clock Soldier at once (after the Winders, before the opening's later steps). Before, the army waited for the opening's
last steps.

## The coached games

@@GAMES@@

## Reading the numbers

@@READ@@

## Open questions for the owner

@@OPEN@@

## Proposals (numbers: the owner's call; nothing was changed)

@@PROP@@

## Tests and tools

- `tools/test_clockwork_army.gd`: one game, measured. `check:1` is the test (Frostfang, the Hard Economy Clockwork against
  the Hard Brood Economy, until:600): at most 2 fights alone away from home, at most 2 first fights alone away from home,
  and the Winders with the army (2 or more on average while it is out). `cwarmy:off` plays the old army code.
- `tools/clockwork_army_report.py`: the tables above from the test's json lines.
- `tools/film_clockwork_army.gd`: a filmed game (the army at set times, the push, the Springers' jumps, GIF frames).
- The old tests still pass: test_clockwork_eco, test_clockwork_builds_a (Clock Soldier rush and turtle),
  test_clockwork_builds_b (Pendulums and Heavy Works), test_clockwork_owls, test_clockwork_springer_timing,
  test_ai_wall_vs_rush.

## Pictures

docs/shots/clockwork_army/ (captions.md).
