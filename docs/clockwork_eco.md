# The Clockwork computer's economy and its own expansion spot (0.30.10, branch clockwork-eco)

Short sentences, to be read aloud.

The owner, 2026-11-04 at 20:24, watching the Hard Clockwork on Economy against the Hard Brood on Economy, Cinder Steps,
0.30.8: "Clockwork does the same mistake: it creates a Light Works for no reason very early without scouting any rush.
Instead of making a second Clocktower fast it builds a force of Clock Soldiers, basically without any reason. I think the
Clockwork economy needs serious work: minute 4 and it didn't expand yet." And: "The Clockwork's optimal expansion spot has to
be different than it currently is: the Clocktower's gear is very important, Clocktowers need room around them."

No unit, building or research number was changed. Ideas for numbers are proposals at the end.

## The short version

- **The opening.** On Economy and on Balanced the Clockwork computer now plays a written opening. Winders come non-stop
  from every Clocktower. The second Clocktower is laid at about 1:45 (before: 3:30 to 5:00). Its two Cog Presses are laid
  the moment it stands. Only then come the Light Works and the Escapement. No Light Works and no soldier come earlier,
  unless the scout sees a rush coming.
- **The result.** {{SHORT_RESULT}}
- **The spot.** Each faction now has its own best expansion spot. The Clockwork's is where its Clocktower's ring of
  buildings fits on open ground of its own level. The gold marks a Clockwork player sees follow it, and so does the
  computer's next Clocktower. On Cinder Steps the old pick was the squeezed spot of the owner's picture, with room for 5
  of the 9 ring buildings; the new one, a few tiles out, has room for 8.

## What was wrong

From the owner's log (docs/playtests/2026-11-04/spectate_clockwork_econ_v_brood_econ_cinder_0308.txt):

- At 1:02 the scout had not seen the enemy. The shared computer then "plays safe": army and production first. For the
  Clockwork that meant TWO Light Works (AIScout._defence), at 1:38 and 2:21, and Clock Soldiers from both: 7 by 3:00.
  Nothing had been seen. That is the "Light Works for no reason".
- The Economy plan had no opening of its own. The expansion came from the shared rule "one hall for every 13 Winders",
  and with the gold going to soldiers the Winders stayed at 14 to 16. So the second Clocktower was laid only at 4:49 and
  stood at 6:00.
- Its spot was the map's own natural (Game.expansions), at the foot of the main's ramp, against the cliff and the map's
  border. Rings mesh only on one ground level, so half of the Clocktower's ring had no ground to build on (the owner's
  picture, docs/playtests/2026-11-04/clockwork_2nd_clocktower_no_room_0644.jpg). The computer then "found no room for a
  Heavy Works" twice.
- What each faction was shown, before this job: the Crown its own spots (CrownSites, since 0.29.2), a Brood player its
  Mound Turtle spots (since 0.15.16), and the Clockwork the old general rating of the map's base sites (the rating every
  side had before 0.29.2). So the owner was nearly right: the Clockwork's marks were the generic ones, and its computer
  did not even use them for its first expansion.

## The owner's own game

The owner played an Economy Clockwork by hand against the Hard Brood on Economy (Glimmerdeep, 0.30.8,
docs/playtests/2026-11-04/human_clockwork_econ_v_brood_econ_glimmerdeep_0308.txt). Minute by minute:

| minute | Winders | cogs earned | army | what he did |
|---|---|---|---|---|
| 1 | 8 | 361 | 0 | a Regulator first (done 0:41) |
| 2 | 12 | 1,005 | 0 | the second Cog Press (1:26), the Mainspring (1:37) |
| 3 | 17 | 1,858 | 0 | the second Clocktower laid about 2:19; a Regulator |
| 4 | 19 | 2,722 | 0 | the Clocktower stood at 3:19; four Light Works at once (3:21 to 3:52); Shield Wall; a press |
| 5 | 26 | 4,176 | 480 | the new presses, the Escapement (4:28), first soldier 4:23, first Springer 4:59 |
| 6 | 25 | 5,666 | 495 | the Brood raided at 5:30 and killed his unfinished third Clocktower |
| 7 | 29 | 7,271 | 1,125 | three more Light Works, the third Clocktower at 7:06 |
| 8 | 34 | 8,676 | 1,235 | two Heavy Works |
| 9 | 40 | 10,853 | 1,985 | he gave up at 9:09 against 5,270 of Brood army |

The Brood earned 3,504 by 5:00, 5,503 by 6:00, 9,660 by 8:00 in that game.

What the computer took from it: Winders without a pause, the Regulator and the second press first, the Mainspring early,
the second Clocktower before any production, no army until about 4:00, then production in a burst once the new
Clocktower's presses are going. His order was Mainspring before the Clocktower; the computer lays the Clocktower first
(its 400 cogs are the long wait) and the Mainspring 15 seconds after.

## The new opening (scripts/ai_cw_eco.gd)

It uses the Clockwork computer's build-order machinery (scripts/ai_clockwork.gd, the Springer timing's): steps by supply,
the next step's cogs put by, the shared computer's own building off while it runs. Two things are new for these plans:

1. **Winders first.** Each Clocktower keeps one Winder in its queue before any step puts cogs by. (In the first try the
   Clocktower's 400 cogs were put by with the Winders stopped at 9 for a minute: worse than the old plan at 4:00.)
2. **The scout stays on**, and only RUSH EVIDENCE changes the build (below). A scout that saw nothing changes nothing.

| # | Economy | Balanced |
|---|---|---|
| 1 | 7 supply: a Regulator | the same |
| 2 | 8 supply: the second Cog Press | the same |
| 3 | Winders up to 16 | up to 15 |
| 4 | THE SECOND CLOCKTOWER (on its own spot, below) | the same |
| 5 | the Mainspring and 3 Winders on it | a Light Works |
| 6 | 15 supply: a Regulator; Winders up to 24 | the Mainspring and its crew; a Regulator; Winders up to 22 |
| 7 | the new Clocktower's two Cog Presses, the moment it stands | 2 Clock Soldiers, then the two new presses |
| 8 | a Light Works; a Regulator; Winders up to 28 | a second Light Works; a Regulator; the Escapement |
| 9 | a second Light Works, the Escapement, 6 Clock Soldiers | 6 Clock Soldiers; Winders up to 26 |
| 10 | a Regulator, then the shared computer plays on (Economy numbers) | the same (Balanced numbers) |

A step waiting for a building does not hold up the next ones, so the first Light Works is laid while the new Clocktower is
still going up (about 2:27), and the presses follow when it stands (about 3:00).

### Rush evidence

The scout's verdict "rush" (AIScout: fast rush units seen early, Raptors or Horsemen, or a big army early) is the only
reason for military before the schedule. Then, ahead of every step:

- a Light Works, if there is none;
- Clock Soldiers: one more than 1.4 times the supply of army seen, at least 3 and at most 8;
- a Ratchet Turret by the ramp's top only when the army seen is worth 300 or more, and only once two soldiers stand: an
  emergency (the owner's rule, "static defence is not a build").

The steps go on after them. After the opening a scout that saw nothing still builds nothing for the Economy and Balanced
Clockwork (AIScout._defence used to lay two Light Works for "could not see the enemy").

`-- cweco:off` on the command line plays the old shared Economy and Balanced (the "old" columns below).

## The spot rule (scripts/clock_sites.gd)

{{SPOT_RULE}}

### Old and new spot, map by map

{{SPOT_TABLE}}

## The coached games

Hard Clockwork against the Hard Brood or the Hard Crown, seed 11, 10 minutes, five maps. "Old" is the shared computer
with the old spot (`cweco:off clocksites:off`). One game a row: fights vary a lot from game to game.
tools/test_clockwork_eco.gd plays them; tools/clockwork_eco_report.py makes the tables.

{{TABLES}}

### Reading the numbers

{{READING}}

## Open questions for the owner

{{OPEN}}

## Proposals (numbers: the owner's call; nothing was changed)

{{PROPOSALS}}

## Tests and tools

- `tools/test_clockwork_eco.gd check:1` (Cinder Steps against the Brood Economy, until:300 is enough): no Light Works and
  no soldier before the second Clocktower without rush evidence; the second Clocktower by 2:45; 19 or more Winders at 4:00;
  the second Clocktower's spot has room for 7 or more of its ring. `rush:1` makes the enemy a rush (the Brood's Extreme
  rush, or the Crown's Rush): then a Light Works within 45 s of the evidence and the Clockwork still standing.
- `tools/test_expansion_spots.gd`: every map, the Clockwork's marks have room for 7+ of the ring, and on each side's best
  spot the game itself lets 6+ of the 8 ring buildings be laid.
- `tools/probe_clock_sites.gd`: the old and new spot of each map, with their ring room.
- `tools/shot_clock_sites.gd`: the pictures of old and new spots with the ring laid.
- `tools/film_clockwork_eco.gd`: a filmed game (pictures at set times, the rush reaction, frames for the GIF).

## Pictures

docs/shots/clockwork_eco/ (captions.md says what each shows).
