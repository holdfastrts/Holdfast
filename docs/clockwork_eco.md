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
- **The result.** Against the Hard Crown and the Hard Brood, on five maps: 25 to 26 Winders at 4:00 (before: 15), about 40% more cogs earned by 6:00 and 45 to 50% more by 8:00. It lost no game the old plan did not lose, and the old plan lost 4 that the new one did not (detail below). The army comes later (about 4:15 instead of 1:52), so it is smaller at 6:00, and bigger by 8:00.
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

A Clockwork spot is good when, in this order of weight:

1. **The ring fits.** Round the Clocktower's big ring, 3x3 buildings on their small rings (a Cog Press, the Mainspring,
   the Escapement) are packed one after another, every 6 degrees, each meshing with the tower's ring directly, each on
   open ground of the Clocktower's own level, off ramps and clear of them, with its free lane round it, and off the others'
   rings (ClockSites.ring_fit). Open ground holds 9. A spot short of 8 pays 15 points for each one missing.
2. **Room beyond.** The share of the 4-tile band outside that ring that is open ground of the same level (where the Works,
   the Heavy Works, more Regulators go): up to 50 points.
3. **Near.** Half a point a tile past the least hall distance (18) from the nearest hall, half a point a step of the walk
   from the main.
4. **Safe.** Never nearer the enemy by land; a little better the nearer us than the enemy. The computer also keeps away
   from enemy halls it knows, ground where it lost a hall lately, and enemy soldiers in sight (as before).

Any free ground counts, not only the map's base sites (a Clocktower's ore is the same fresh reserve anywhere). The
candidates are every cell 18 to 30 tiles from a hall of ours; the cheap terms rank them, and the ring is measured for the
best ones only. A pick takes about 50 to 120 ms (a side's two marks at the start, again when its halls change; the
computer keeps its pick for 4 seconds).

What each faction is shown now: the Crown its own spots (CrownSites), the Clockwork its own (ClockSites), a Brood player
its Mound Turtle spots. Watching, every side shows its own faction's spots. `-- clocksites:off` brings back the old
marks and the old computer pick (comparisons).

### Old and new spot, map by map

| map | old mark (base-site rating) | its ring | new mark (ClockSites) | its ring | open ground beyond | walk from the main |
|---|---|---|---|---|---|---|
| greenhold | (7, 30) | 8 of 9 | (11, 31) | 8 of 9 | 93% | 20 steps |
| highmoor | (7, 31) | 8 of 9 | (11, 31) | 8 of 9 | 93% | 20 steps |
| dune_sea | (7, 30) | 8 of 9 | (11, 31) | 8 of 9 | 92% | 20 steps |
| frostfang | (7, 31) | 8 of 9 | (12, 30) | 8 of 9 | 89% | 19 steps |
| twin_fords | (30, 28) | 9 of 9 | (15, 30) | 8 of 9 | 94% | 20 steps |
| ashfall | (7, 31) | 8 of 9 | (11, 31) | 8 of 9 | 93% | 20 steps |
| mirewood | (30, 28) | 9 of 9 | (15, 30) | 8 of 9 | 94% | 20 steps |
| border_march | (30, 28) | 9 of 9 | (15, 30) | 8 of 9 | 94% | 20 steps |
| red_coast | (7, 31) | 8 of 9 | (11, 31) | 8 of 9 | 92% | 20 steps |
| ashford_crossing | (7, 31) | 8 of 9 | (14, 33) | 8 of 9 | 93% | 24 steps |
| kestrel_rise | (5, 26) | 5 of 9 | (11, 29) | 8 of 9 | 94% | 22 steps |
| thornwood_maze | (31, 6) | 6 of 9 | (33, 9) | 8 of 9 | 88% | 21 steps |
| redrock_canyon | (35, 33) | 8 of 9 | (36, 29) | 8 of 9 | 88% | 20 steps |
| saltmarsh_isles | (28, 5) | 4 of 9 | (32, 11) | 8 of 9 | 89% | 21 steps |
| glimmerdeep | (31, 34) | 9 of 9 | (11, 31) | 8 of 9 | 95% | 21 steps |
| frostmere | (39, 12) | 8 of 9 | (13, 29) | 8 of 9 | 93% | 21 steps |
| cinder_steps | (29, 28) | 7 of 9 | (9, 32) | 8 of 9 | 78% | 21 steps |
| hollowfen | (53, 12) | 9 of 9 | (35, 10) | 8 of 9 | 94% | 22 steps |
| amberfall_vale | (50, 33) | 7 of 9 | (52, 30) | 7 of 9 | 91% | 21 steps |
| twin_crowns | (54, 15) | 8 of 9 | (33, 10) | 7 of 9 | 88% | 21 steps |
| jade_wilds | (11, 54) | 9 of 9 | (11, 32) | 8 of 9 | 93% | 21 steps |
| shattered_coast | (30, 10) | 6 of 9 | (32, 12) | 8 of 9 | 85% | 20 steps |
| ember_reach | (8, 30) | 8 of 9 | (12, 32) | 8 of 9 | 94% | 21 steps |
| whitecap_pass | (30, 6) | 5 of 9 | (33, 11) | 7 of 9 | 87% | 21 steps |
| kingsfield | (30, 8) | 6 of 9 | (33, 12) | 7 of 9 | 89% | 21 steps |
| pinewall_marches | (8, 30) | 8 of 9 | (8, 31) | 8 of 9 | 76% | 20 steps |
| sundered_realm | (54, 12) | 8 of 9 | (33, 8) | 8 of 9 | 80% | 21 steps |

The old computer's own pick (it did not use the marks: its plans took the map's natural first, Game.expansions) and the
new one, with the ring LAID by the game (ClockSites.fill_ring, 8 kinds: pictures 01 to 10):

| map | old computer's 2nd Clocktower | laid round it | new | laid round it |
|---|---|---|---|---|
| cinder_steps | (5, 29) | 5 of 8 | (9, 32) | 7 of 8 |
| thornwood_maze | (31, 6) | 6 of 8 | (33, 9) | 7 of 8 |
| greenhold | (7, 30) | 8 of 8 | (11, 31) | 7 of 8 |
| highmoor | (7, 31) | 8 of 8 | (11, 31) | 7 of 8 |
| redrock_canyon | (35, 33) | 8 of 8 | (36, 29) | 6 of 8 |

So the old pick was cramped on Cinder Steps and Thornwood Maze, and fine on the other three. The new rule is never
cramped there (6 or more laid everywhere; test_expansion_spots checks every map), but on Redrock Canyon its spot, nearer
the main and under the ramp, is a little tighter than the old one. Among the old MARKS (the table above), six maps had a
best spot with room for 6 or fewer: Kestrel Rise 5, Thornwood Maze 6, Saltmarsh Isles 4, Shattered Coast 6, Whitecap
Pass 5, Kingsfield 6. The new marks have room for 7 to 8 of 9 on every map.

## The coached games

Hard Clockwork against the Hard Brood or the Hard Crown, seed 11, 10 minutes, five maps. "Old" is the shared computer
with the old spot (`cweco:off clocksites:off`). One game a row: fights vary a lot from game to game.
tools/test_clockwork_eco.gd plays them; tools/clockwork_eco_report.py makes the tables.

#### When things happen

| map | foe | plan | rush seen | 1st Light Works | 1st soldier | 2nd Clocktower laid | up | Mainspring | Escapement | 3rd Clocktower | 2nd's ring (of 9) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| cinder_steps | brood air | Economy old | 2:52 | 0:53 | 1:52 | 4:37 | 5:48 | 4:11 | 4:11 | never | 5 |
| cinder_steps | brood air | Economy new | 2:50 | 2:28 | 3:27 | 1:44 | 2:54 | 1:59 | 4:09 | 4:55 | 8 |
| cinder_steps | brood balanced | Balanced old | 3:19 | 0:53 | 1:52 | 4:44 | 5:52 | 4:14 | 4:14 | never | 5 |
| cinder_steps | brood balanced | Balanced new | 2:53 | 1:59 | 2:59 | 1:44 | 2:53 | 2:15 | 3:59 | never | 8 |
| cinder_steps | brood balanced | Economy old | 2:56 | 0:53 | 1:52 | 4:38 | 5:49 | 4:11 | 4:11 | never | 5 |
| cinder_steps | brood balanced | Economy new | 2:52 | 2:28 | 3:27 | 1:45 | 2:54 | 1:59 | 4:09 | 4:55 | 8 |
| greenhold | brood balanced | Balanced old | 2:49 | 0:54 | 1:51 | 3:50 | 5:00 | 3:19 | 3:19 | never | 8 |
| greenhold | brood balanced | Balanced new | 5:24 | 1:59 | 2:58 | 1:45 | 2:54 | 2:17 | 3:48 | 4:59 | 8 |
| highmoor | brood balanced | Balanced old | 2:49 | 0:54 | 1:51 | 3:49 | 4:59 | 3:19 | 3:19 | never | 8 |
| highmoor | brood balanced | Balanced new | 5:32 | 1:59 | 2:56 | 1:45 | 2:54 | 2:17 | 3:50 | 4:58 | 8 |
| redrock_canyon | brood balanced | Balanced old | 2:53 | 0:53 | 1:51 | 3:59 | 5:11 | 3:30 | 3:30 | never | 8 |
| redrock_canyon | brood balanced | Balanced new | 5:25 | 1:59 | 2:57 | 1:45 | 2:54 | 2:15 | 3:46 | 4:54 | 8 |
| thornwood_maze | brood balanced | Balanced old | 2:54 | 0:54 | 1:51 | 3:40 | 4:51 | 3:12 | 3:12 | never | 6 |
| thornwood_maze | brood balanced | Balanced new | 3:37 | 1:59 | 2:56 | 1:45 | 2:56 | 2:17 | 3:56 | 7:26 | 8 |
| cinder_steps | brood brute | Economy old | 2:46 | 0:53 | 1:52 | 4:05 | 5:14 | 3:38 | 3:38 | 8:24 | 5 |
| cinder_steps | brood brute | Economy new | 3:48 | 2:28 | 4:04 | 1:44 | 2:53 | 1:59 | 4:01 | 5:14 | 8 |
| cinder_steps | brood economy | Economy old | 6:38 | 0:53 | 1:52 | 4:35 | 5:43 | 5:27 | 5:27 | never | 5 |
| cinder_steps | brood economy | Economy new | 5:08 | 2:27 | 4:14 | 1:44 | 2:53 | 1:59 | 3:58 | 4:47 | 8 |
| greenhold | brood economy | Economy old | 3:24 | 0:54 | 1:51 | 3:51 | 5:00 | 3:23 | 3:23 | 9:16 | 8 |
| greenhold | brood economy | Economy new | 5:25 | 2:29 | 4:14 | 1:45 | 2:54 | 1:59 | 3:57 | 4:46 | 8 |
| highmoor | brood economy | Economy old | 3:37 | 0:54 | 1:51 | 5:00 | 6:10 | 4:29 | 4:29 | never | 8 |
| highmoor | brood economy | Economy new | 5:29 | 2:29 | 4:14 | 1:45 | 2:54 | 1:59 | 3:57 | 4:44 | 8 |
| redrock_canyon | brood economy | Economy old | 3:01 | 0:53 | 1:51 | 3:58 | 5:10 | 3:30 | 3:30 | 9:10 | 8 |
| redrock_canyon | brood economy | Economy new | never | 2:26 | 4:13 | 1:45 | 2:54 | 1:59 | 3:56 | 4:44 | 8 |
| thornwood_maze | brood economy | Economy old | 2:57 | 0:54 | 1:51 | 4:27 | 5:39 | 3:56 | 3:56 | never | 6 |
| thornwood_maze | brood economy | Economy new | 3:37 | 2:26 | 3:51 | 1:45 | 2:56 | 1:59 | 4:03 | 5:44 | 8 |
| cinder_steps | brood rush | Economy old | 3:13 | 0:53 | 1:52 | 4:19 | 5:29 | 3:30 | 3:30 | 9:11 | 5 |
| cinder_steps | brood rush | Economy new | 3:37 | 2:25 | 3:51 | 1:44 | 2:53 | 1:58 | 4:12 | 5:44 | 8 |
| cinder_steps | brood spitter | Economy old | 2:46 | 0:53 | 1:52 | 3:54 | 5:07 | 3:27 | 3:27 | 8:29 | 5 |
| cinder_steps | brood spitter | Economy new | 2:50 | 2:28 | 3:27 | 1:44 | 2:54 | 1:59 | 4:09 | 5:17 | 8 |
| cinder_steps | brood timing | Economy old | 2:56 | 0:53 | 1:52 | 4:38 | 5:49 | 4:11 | 4:11 | never | 5 |
| cinder_steps | brood timing | Economy new | 2:48 | 2:28 | 3:27 | 1:44 | 2:53 | 1:59 | 4:09 | 5:01 | 8 |
| cinder_steps | brood xrush | Economy old | 1:16 | 0:53 | 1:52 | 5:04 | 6:12 | 3:56 | 3:56 | never | 5 |
| cinder_steps | brood xrush | Economy new | 1:17 | 1:18 | 2:18 | 1:59 | 3:09 | 2:43 | never | never | 8 |
| cinder_steps | crown balanced | Balanced old | 6:26 | 0:53 | 1:52 | 4:08 | 5:18 | 3:38 | 3:38 | 6:44 | 5 |
| cinder_steps | crown balanced | Balanced new | 6:11 | 2:02 | 2:59 | 1:47 | 2:57 | 2:16 | 3:49 | 4:55 | 8 |
| cinder_steps | crown balanced | Economy old | never | 0:53 | 1:52 | 3:32 | 4:43 | 3:05 | 3:05 | 6:15 | 5 |
| cinder_steps | crown balanced | Economy new | never | 2:26 | 4:15 | 1:46 | 2:57 | 2:01 | 3:58 | 4:44 | 8 |
| greenhold | crown balanced | Balanced old | never | 0:54 | 1:51 | 3:50 | 5:03 | 3:20 | 3:20 | 6:34 | 8 |
| greenhold | crown balanced | Balanced new | 3:31 | 2:03 | 3:00 | 1:48 | 2:57 | 2:17 | 4:07 | 6:22 | 8 |
| greenhold | crown balanced | Economy old | 5:45 | 0:54 | 1:51 | 4:42 | 5:53 | 6:15 | 6:15 | 7:58 | 8 |
| greenhold | crown balanced | Economy new | 3:31 | 2:28 | 3:46 | 1:48 | 2:58 | 2:02 | 4:14 | 5:38 | 8 |
| highmoor | crown balanced | Balanced old | 5:45 | 0:54 | 1:51 | 4:05 | 5:16 | 3:38 | 3:38 | 8:05 | 8 |
| highmoor | crown balanced | Balanced new | 3:30 | 2:02 | 2:59 | 1:48 | 2:57 | 2:16 | 4:07 | 6:23 | 8 |
| highmoor | crown balanced | Economy old | 3:30 | 0:54 | 1:51 | 5:03 | 6:14 | 4:33 | 4:33 | 8:10 | 8 |
| highmoor | crown balanced | Economy new | 3:31 | 2:28 | 3:46 | 1:48 | 2:57 | 2:02 | 4:14 | 5:38 | 8 |
| redrock_canyon | crown balanced | Balanced old | 6:39 | 0:53 | 1:49 | 4:13 | 5:26 | 3:16 | 3:16 | 8:13 | 8 |
| redrock_canyon | crown balanced | Balanced new | 6:38 | 2:04 | 3:00 | 1:49 | 2:59 | 2:18 | 3:53 | 5:00 | 8 |
| redrock_canyon | crown balanced | Economy old | never | 0:53 | 1:51 | 4:16 | 5:27 | 3:16 | 3:16 | 7:34 | 8 |
| redrock_canyon | crown balanced | Economy new | 6:35 | 2:29 | 4:16 | 1:49 | 2:58 | 2:04 | 4:00 | 4:46 | 8 |
| thornwood_maze | crown balanced | Balanced old | 3:35 | 0:54 | 1:51 | 4:41 | 5:52 | 4:11 | 4:11 | 7:59 | 6 |
| thornwood_maze | crown balanced | Balanced new | 3:34 | 2:03 | 2:59 | 1:48 | 3:00 | 2:17 | 4:25 | 6:59 | 8 |
| thornwood_maze | crown balanced | Economy old | 3:35 | 0:54 | 1:51 | 4:29 | 5:40 | 4:00 | 4:00 | 8:15 | 6 |
| thornwood_maze | crown balanced | Economy new | 3:37 | 2:28 | 3:51 | 1:48 | 2:59 | 2:02 | 4:14 | 5:39 | 8 |
| cinder_steps | crown rush | Economy old | never | 0:53 | 1:52 | 3:38 | 4:47 | 3:12 | 3:12 | 6:09 | 5 |
| cinder_steps | crown rush | Economy new | never | 2:24 | 4:14 | 1:44 | 2:54 | 1:58 | 3:56 | 4:43 | 8 |

#### The economy, minute by minute (Winders / cogs earned; the enemy's earned)

| map | foe | plan | Winders 2/3/4/5/6/8 | earned 3/4/5/6/8/10 | foe earned 4/6/8/10 | army 4/6/8 (foe) | killed / lost by 10 | bld lost | winner |
|---|---|---|---|---|---|---|---|---|---|
| cinder_steps | brood air | Economy old | 11/14/14/15/16/22 | 1945/2788/3599/4415/5999/7136 | 2245/5155/8631/11778 | 1120 (800)/1820 (2225)/585 (3340) | 2420 / 4720 | 2 | none |
| cinder_steps | brood air | Economy new | 13/18/25/28/20/30 | 1911/2899/4563/5979/8495/11150 | 2122/4820/8589/12452 | 210 (725)/125 (2025)/1025 (3250) | 2725 / 5460 | 1 | none |
| cinder_steps | brood balanced | Balanced old | 11/14/15/15/16/1 | 1938/2795/3585/4252/5476/- | 2333/5578/9471/- | 1120 (1000)/965 (1895)/0 (4750) | 750 / 6490 | 14 | foe (8:53) |
| cinder_steps | brood balanced | Balanced new | 13/17/22/26/17/14 | 1908/2864/4332/5534/6703/- | 2336/4399/7611/- | 280 (1400)/690 (1975)/0 (2575) | 970 / 7715 | 16 | foe (9:49) |
| cinder_steps | brood balanced | Economy old | 11/14/14/15/16/0 | 1938/2784/3600/4277/5612/- | 2438/5498/9114/- | 1120 (1075)/1105 (1650)/0 (4425) | 1025 / 6625 | 15 | foe (9:32) |
| cinder_steps | brood balanced | Economy new | 13/18/25/28/19/24 | 1911/2889/4567/5681/7569/8537 | 2368/5274/9114/11022 | 210 (1400)/375 (2200)/995 (4190) | 2175 / 7475 | 8 | none |
| greenhold | brood balanced | Balanced old | 11/14/14/16/19/6 | 1917/2700/3444/4230/5531/6530 | 2080/4753/8462/12714 | 840 (1100)/895 (1450)/0 (3475) | 1350 / 6020 | 14 | none |
| greenhold | brood balanced | Balanced new | 13/17/22/27/22/34 | 1911/2885/4429/5908/8772/12854 | 2120/5391/9703/13776 | 140 (1050)/425 (1750)/1140 (2450) | 1675 / 2405 | 1 | none |
| highmoor | brood balanced | Balanced old | 11/14/14/15/16/21 | 1916/2695/3373/4016/5560/7887 | 2083/5160/7919/11915 | 840 (1050)/1140 (2585)/845 (1700) | 1830 / 4645 | 4 | none |
| highmoor | brood balanced | Balanced new | 13/17/22/27/28/32 | 1905/2808/4336/5822/9446/13802 | 2053/5403/9440/14122 | 140 (1100)/940 (1725)/1605 (3500) | 5295 / 4245 | 0 | none |
| redrock_canyon | brood balanced | Balanced old | 11/14/14/16/16/20 | 1962/2794/3534/4298/5972/7527 | 2018/4466/9177/13579 | 980 (1100)/1475 (2025)/1900 (4105) | 2420 / 4735 | 3 | none |
| redrock_canyon | brood balanced | Balanced new | 13/17/22/27/23/32 | 1947/2895/4455/5762/9251/11867 | 2051/4931/9397/14342 | 140 (1100)/675 (1550)/2260 (4135) | 2525 / 7685 | 7 | none |
| thornwood_maze | brood balanced | Balanced old | 11/14/15/15/20/20 | 1882/2690/3525/4385/5928/- | 2442/5192/8544/- | 700 (1100)/845 (1875)/390 (4120) | 1425 / 7380 | 16 | foe (9:41) |
| thornwood_maze | brood balanced | Balanced new | 13/17/22/26/24/27 | 1913/2852/4355/5556/8547/11375 | 2203/5096/8899/13139 | 210 (1000)/440 (1375)/1285 (2685) | 2690 / 5065 | 1 | none |
| cinder_steps | brood brute | Economy old | 11/14/14/16/21/26 | 1938/2776/3585/4398/6968/10022 | 2285/5316/8409/11861 | 1050 (825)/1580 (1810)/2620 (3875) | 1285 / 2705 | 0 | none |
| cinder_steps | brood brute | Economy new | 13/18/26/28/28/32 | 1908/2885/4612/6317/9552/12343 | 2386/5365/8828/10032 | 0 (950)/1000 (2000)/2725 (3860) | 4065 / 2180 | 0 | none |
| cinder_steps | brood economy | Economy old | 11/14/17/20/20/23 | 1954/2805/3663/4511/6341/7394 | 2342/5438/9318/12144 | 910 (1225)/1400 (1950)/985 (4225) | 1515 / 6660 | 8 | none |
| cinder_steps | brood economy | Economy new | 13/18/26/30/21/25 | 1921/2905/4632/5816/7684/10197 | 2209/4181/8305/10950 | 0 (1350)/500 (2000)/1510 (2150) | 2395 / 5630 | 5 | none |
| greenhold | brood economy | Economy old | 11/14/15/16/16/20 | 1921/2750/3523/4335/6000/8290 | 1780/3299/4320/5208 | 770 (925)/1560 (1650)/950 (2150) | 525 / 2320 | 0 | none |
| greenhold | brood economy | Economy new | 13/18/26/28/28/31 | 1901/2945/4634/6185/9519/12602 | 2144/5413/9893/14904 | 0 (1100)/320 (1460)/2005 (3295) | 6065 / 3495 | 2 | none |
| highmoor | brood economy | Economy old | 11/14/15/15/16/21 | 1926/2746/3499/4237/5926/7571 | 1934/4364/9166/13753 | 1050 (1050)/1385 (1700)/1795 (3850) | 3170 / 4435 | 0 | none |
| highmoor | brood economy | Economy new | 13/18/26/28/28/30 | 1900/2932/4612/6288/9686/12446 | 2114/4973/9461/13898 | 0 (1100)/585 (1725)/2250 (4000) | 4290 / 4565 | 3 | none |
| redrock_canyon | brood economy | Economy old | 11/14/14/16/16/21 | 1965/2806/3635/4487/6148/8095 | 1921/4267/8265/13243 | 980 (1250)/725 (1750)/1110 (2475) | 4150 / 3925 | 2 | none |
| redrock_canyon | brood economy | Economy new | 13/18/27/28/27/34 | 1946/2961/4642/6026/9467/13353 | 2089/5238/9967/14625 | 0 (1200)/850 (1450)/1785 (3150) | 5180 / 4425 | 1 | none |
| thornwood_maze | brood economy | Economy old | 11/14/14/16/16/0 | 1886/2681/3423/4210/5433/- | 2215/5230/8872/- | 1120 (1100)/1440 (1925)/0 (4725) | 750 / 6470 | 14 | foe (8:47) |
| thornwood_maze | brood economy | Economy new | 13/18/27/28/27/25 | 1937/2922/4641/5985/8933/9012 | 2056/5005/8697/12619 | 70 (1100)/980 (1350)/445 (3710) | 1400 / 8065 | 13 | none |
| cinder_steps | brood rush | Economy old | 11/14/15/15/18/20 | 1972/2817/3581/4378/6179/8298 | 1063/1876/3268/6091 | 770 (725)/1475 (1000)/1060 (1575) | 1300 / 2500 | 0 | none |
| cinder_steps | brood rush | Economy new | 13/18/27/28/28/32 | 1953/2811/4473/6162/9063/11673 | 1117/1870/3313/4691 | 70 (625)/910 (850)/2505 (1250) | 2275 / 1010 | 0 | none |
| cinder_steps | brood spitter | Economy old | 11/14/14/16/20/25 | 1947/2794/3589/4411/6921/9466 | 2076/3557/6837/10739 | 910 (1300)/1440 (1575)/2260 (3685) | 975 / 4650 | 4 | none |
| cinder_steps | brood spitter | Economy new | 13/18/25/28/27/32 | 1912/2895/4547/6237/9471/12768 | 2202/3987/7685/11449 | 210 (1475)/1140 (1850)/2840 (3905) | 3635 / 4895 | 0 | none |
| cinder_steps | brood timing | Economy old | 11/14/14/15/16/17 | 1948/2782/3604/4312/5849/- | 2075/5068/8735/- | 1120 (1100)/980 (1970)/620 (3760) | 1125 / 6750 | 16 | foe (9:20) |
| cinder_steps | brood timing | Economy new | 13/18/25/28/21/31 | 1915/2890/4536/5762/8523/10505 | 2058/5250/8861/12530 | 210 (1100)/550 (1910)/1560 (3000) | 3760 / 5375 | 3 | none |
| cinder_steps | brood xrush | Economy old | 11/11/11/15/16/13 | 1764/2490/3219/4018/5451/6497 | 988/2156/4336/6955 | 1050 (700)/1470 (1300)/250 (1975) | 1375 / 5415 | 2 | none |
| cinder_steps | brood xrush | Economy new | 13/16/20/22/18/21 | 1925/2786/3636/4325/5559/7287 | 984/1507/2099/3295 | 140 (875)/70 (1000)/280 (775) | 900 / 3010 | 1 | none |
| cinder_steps | crown balanced | Balanced old | 11/14/15/18/22/26 | 1913/2746/3568/4408/6853/10287 | 1520/3040/5320/6840 | 1050 (490)/1510 (700)/2040 (1305) | 1015 / 1470 | 0 | none |
| cinder_steps | crown balanced | Balanced new | 13/17/22/27/28/32 | 1924/2853/4414/6080/9641/12809 | 1520/3040/5320/6840 | 140 (490)/1360 (700)/2290 (1290) | 2485 / 2705 | 0 | none |
| cinder_steps | crown balanced | Economy old | 11/14/15/18/25/30 | 1900/2733/3578/4577/7655/11233 | 1520/3040/5320/7220 | 630 (490)/1390 (770)/2235 (1310) | 1240 / 1970 | 0 | none |
| cinder_steps | crown balanced | Economy new | 13/18/26/28/30/31 | 1933/2900/4609/6272/9496/12394 | 1520/3040/5320/7220 | 0 (490)/990 (700)/3595 (1390) | 2140 / 1255 | 0 | none |
| greenhold | crown balanced | Balanced old | 11/14/14/18/24/29 | 1832/2612/3421/4308/7198/10692 | 1520/3040/5700/8740 | 770 (560)/1155 (745)/1715 (1330) | 1270 / 3000 | 0 | none |
| greenhold | crown balanced | Balanced new | 13/17/22/26/25/33 | 1915/2880/4349/5914/8997/12575 | 1520/3040/5320/9120 | 280 (560)/1105 (700)/2455 (1500) | 1275 / 2885 | 0 | none |
| greenhold | crown balanced | Economy old | 11/14/15/16/16/29 | 1859/2678/3523/4369/6507/9533 | 1520/3040/4940/8740 | 1050 (560)/1960 (745)/2380 (1460) | 285 / 3695 | 1 | none |
| greenhold | crown balanced | Economy new | 13/18/25/28/27/34 | 1918/2885/4566/6192/9199/12332 | 1520/3040/5320/7980 | 70 (560)/980 (700)/2930 (860) | 2720 / 1350 | 0 | none |
| highmoor | crown balanced | Balanced old | 11/14/15/19/20/29 | 1863/2690/3513/4353/6542/8682 | 1520/3040/5700/7980 | 980 (560)/1420 (630)/2540 (1220) | 450 / 2155 | 0 | none |
| highmoor | crown balanced | Balanced new | 13/17/22/26/25/34 | 1923/2878/4349/5861/8643/12290 | 1520/3040/5700/8360 | 280 (560)/1105 (700)/2035 (1125) | 1425 / 2120 | 0 | none |
| highmoor | crown balanced | Economy old | 11/14/15/15/16/29 | 1864/2674/3466/4266/6153/8831 | 1520/3040/5700/8740 | 1050 (560)/1820 (700)/2195 (1195) | 665 / 1995 | 0 | none |
| highmoor | crown balanced | Economy new | 13/18/25/28/27/34 | 1910/2900/4586/6176/9128/12585 | 1520/3040/5320/8740 | 70 (560)/980 (700)/3000 (1240) | 1340 / 2350 | 0 | none |
| redrock_canyon | crown balanced | Balanced old | 11/14/15/18/19/29 | 1885/2731/3551/4399/6504/9362 | 1520/3040/4940/8360 | 980 (490)/1405 (675)/2450 (930) | 355 / 1450 | 0 | none |
| redrock_canyon | crown balanced | Balanced new | 13/17/22/27/28/36 | 1902/2846/4443/6128/9590/13220 | 1520/3040/5320/6840 | 140 (490)/1250 (700)/2405 (1125) | 700 / 1925 | 0 | none |
| redrock_canyon | crown balanced | Economy old | 11/14/14/19/19/33 | 1888/2739/3547/4374/6539/9543 | 1520/3040/5700/9500 | 910 (490)/1350 (700)/1995 (1240) | 1140 / 1510 | 1 | none |
| redrock_canyon | crown balanced | Economy new | 13/18/25/28/28/34 | 1895/2856/4545/6241/9774/13540 | 1520/3040/5320/9500 | 0 (490)/920 (700)/3460 (1145) | 1385 / 3045 | 0 | none |
| thornwood_maze | crown balanced | Balanced old | 11/14/15/16/16/30 | 1846/2672/3459/4296/6314/9019 | 1520/3040/5700/9120 | 980 (490)/1665 (745)/1300 (1030) | 1010 / 2010 | 0 | none |
| thornwood_maze | crown balanced | Balanced new | 13/17/21/25/26/32 | 1910/2774/4020/5588/8356/11397 | 1520/3040/5700/8740 | 280 (490)/1420 (745)/1060 (975) | 590 / 2705 | 0 | none |
| thornwood_maze | crown balanced | Economy old | 11/14/15/16/16/26 | 1851/2684/3482/4294/6385/9383 | 1520/3040/5700/8360 | 1120 (490)/1720 (745)/2235 (1095) | 665 / 1965 | 0 | none |
| thornwood_maze | crown balanced | Economy new | 13/18/25/28/28/32 | 1909/2877/4582/6269/9304/12440 | 1520/3040/5700/7220 | 70 (490)/980 (745)/3100 (1140) | 2625 / 2195 | 0 | none |
| cinder_steps | crown rush | Economy old | 11/16/18/22/26/32 | 1986/2850/3713/4649/7811/11116 | 1900/3040/4180/4940 | 560 (230)/1320 (230)/2330 (230) | 1345 / 250 | 0 | none |
| cinder_steps | crown rush | Economy new | 12/17/26/30/32/32 | 1974/2968/4693/6401/10062/- | 1900/3040/4180/- | 0 (230)/920 (230)/3380 (230) | 1995 / 250 | 0 | clockwork (9:05) |

#### Averages

| foe | plan | games | Winders 4:00 | Winders 6:00 | earned 4:00 | earned 6:00 | earned 8:00 | foe earned 8:00 | 2nd Clocktower laid | killed / lost by 10 | lost games |
|---|---|---|---|---|---|---|---|---|---|---|---|
| brood air | Economy new | 1 | 25.0 | 20.0 | 2899 | 5979 | 8495 | 8589 | 1:44 | 2725 / 5460 | 0 |
| brood air | Economy old | 1 | 14.0 | 16.0 | 2788 | 4415 | 5999 | 8631 | 4:37 | 2420 / 4720 | 0 |
| brood balanced | Balanced new | 5 | 22.0 | 22.8 | 2861 | 5716 | 8544 | 9010 | 1:44 | 2631 / 5423 | 1 |
| brood balanced | Balanced old | 5 | 14.4 | 17.4 | 2735 | 4236 | 5693 | 8715 | 4:00 | 1555 / 5854 | 2 |
| brood balanced | Economy new | 1 | 25.0 | 19.0 | 2889 | 5681 | 7569 | 9114 | 1:45 | 2175 / 7475 | 0 |
| brood balanced | Economy old | 1 | 14.0 | 16.0 | 2784 | 4277 | 5612 | 9114 | 4:38 | 1025 / 6625 | 1 |
| brood brute | Economy new | 1 | 26.0 | 28.0 | 2885 | 6317 | 9552 | 8828 | 1:44 | 4065 / 2180 | 0 |
| brood brute | Economy old | 1 | 14.0 | 21.0 | 2776 | 4398 | 6968 | 8409 | 4:05 | 1285 / 2705 | 0 |
| brood economy | Economy new | 5 | 26.4 | 26.2 | 2933 | 6060 | 9058 | 9265 | 1:44 | 3866 / 5236 | 0 |
| brood economy | Economy old | 5 | 15.0 | 16.8 | 2758 | 4356 | 5970 | 7988 | 4:22 | 2022 / 4762 | 1 |
| brood rush | Economy new | 1 | 27.0 | 28.0 | 2811 | 6162 | 9063 | 3313 | 1:44 | 2275 / 1010 | 0 |
| brood rush | Economy old | 1 | 15.0 | 18.0 | 2817 | 4378 | 6179 | 3268 | 4:19 | 1300 / 2500 | 0 |
| brood spitter | Economy new | 1 | 25.0 | 27.0 | 2895 | 6237 | 9471 | 7685 | 1:44 | 3635 / 4895 | 0 |
| brood spitter | Economy old | 1 | 14.0 | 20.0 | 2794 | 4411 | 6921 | 6837 | 3:54 | 975 / 4650 | 0 |
| brood timing | Economy new | 1 | 25.0 | 21.0 | 2890 | 5762 | 8523 | 8861 | 1:44 | 3760 / 5375 | 0 |
| brood timing | Economy old | 1 | 14.0 | 16.0 | 2782 | 4312 | 5849 | 8735 | 4:38 | 1125 / 6750 | 1 |
| brood xrush | Economy new | 1 | 20.0 | 18.0 | 2786 | 4325 | 5559 | 2099 | 1:59 | 900 / 3010 | 0 |
| brood xrush | Economy old | 1 | 11.0 | 16.0 | 2490 | 4018 | 5451 | 4336 | 5:04 | 1375 / 5415 | 0 |
| crown balanced | Balanced new | 5 | 21.8 | 26.4 | 2846 | 5914 | 9045 | 5472 | 1:48 | 1295 / 2468 | 0 |
| crown balanced | Balanced old | 5 | 14.8 | 20.2 | 2690 | 4353 | 6682 | 5472 | 4:11 | 820 / 2017 | 0 |
| crown balanced | Economy new | 5 | 25.2 | 28.0 | 2884 | 6230 | 9380 | 5396 | 1:48 | 2042 / 2039 | 0 |
| crown balanced | Economy old | 5 | 14.8 | 18.4 | 2702 | 4376 | 6648 | 5472 | 4:24 | 799 / 2227 | 0 |
| crown rush | Economy new | 1 | 26.0 | 32.0 | 2968 | 6401 | 10062 | 4180 | 1:44 | 1995 / 250 | 0 |
| crown rush | Economy old | 1 | 18.0 | 26.0 | 2850 | 4649 | 7811 | 4180 | 3:38 | 1345 / 250 | 0 |


### Reading the numbers

- **The economy.** Economy against the Brood Economy: 26.4 Winders at 4:00 (old 15.0), 6,060 cogs by 6:00 (old 4,356),
  9,058 by 8:00 (old 5,970). Against the Crown Balanced: 6,230 by 6:00 (4,376), 9,380 by 8:00 (6,648). Balanced: 5,716
  and 5,914 by 6:00 (old 4,236 and 4,353). The owner's own game: 5,666 by 6:00 and 8,676 by 8:00. The computer is now at
  his pace, a little ahead in cogs and behind him in army after 6:00.
- **Against the Brood's income.** Before, the Brood out-earned the Economy Clockwork by about a third by 8:00 (7,988 to
  5,970). Now they are level (9,265 to 9,058). The Brood still earns more against Balanced.
- **Safety.** Lost games by 10:00: old 5 (Economy v Brood Economy on Thornwood, v Brood Balanced and v Brood Timing on
  Cinder Steps; Balanced v Brood Balanced twice), new 1 (Balanced v Brood Balanced on Cinder Steps, at 9:49 instead of
  8:53). Value lost by 10:00 is about the same; value killed is about twice as high.
- **The army comes later.** First soldier at about 4:15 when no rush is seen (old 1:52). At 6:00 the new army is about
  500 to 1,000 against the old 1,400 to 1,800: the Brood's first big attack (5:30 to 6:15) hurts more (Cinder Steps: 1,310
  lost by 6:00). By 8:00 the new army is the bigger one (2,000 to 3,600 against 1,000 to 2,400).
- **Rushes.** Against the Brood's Extreme rush the Raptors were seen at 1:17 and the Light Works laid at 1:17; the
  Clockwork lost 3,010 value by 10:00 (old 5,415) and kept both bases. Against the Crown's Rush it lost 250 (as the old)
  and won at 9:05. Against the other Brood plans the reaction came at 2:48 to 3:37 when Raptors showed up.
- **The spot.** On Cinder Steps and Thornwood Maze the second Clocktower's ring went from 5 and 6 to 8 of 9 (rated).

## Open questions for the owner

1. **The army at 6:00.** The new Economy has half the old army at 6:00, and the Brood's first big attack lands then. It
   held in every measured game but Cinder Steps cost 1,300 value. Is that the trade the owner wants from "Economy", or
   should the second Light Works come a minute sooner?
2. **Redrock Canyon.** The new spot is nearer the main, under its ramp, and lays 6 of 8 ring buildings; the old one, a
   few tiles farther, laid 8. Should "room beyond" weigh more than "near" (the owner's own 2nd Clocktower in Glimmerdeep
   was right beside his main)?
3. **The third Clocktower.** After the opening the shared computer lays the third at about 4:45 (one hall for every 13
   Winders), 30 to 40 steps out. The owner laid his at 5:58 and lost it unfinished at 5:30 to a raid. Keep it, or wait
   for the army?
4. **Rush evidence against the Brood.** Two Raptors seen near our base count as "rush" (AIScout), so against most Brood
   plans the reaction starts at about 3:00 even when it is no rush: it is cheap (a Light Works and 3 to 5 soldiers),
   but should the Clockwork wait for more?
5. **Turrets.** The plan's emergency turret comes only when 300+ value of rush is seen while the opening runs; after the
   opening the shared computer still lays a turret of its own when it sees a swarm (as before this job). The owner's rule
   says turrets only as a reaction: both are reactions, but the shared one may want the same review.

## Proposals (numbers: the owner's call; nothing was changed)

1. **The Brood's income** is still level with the new Economy Clockwork and ahead of Balanced: the FOOD_BONUS question
   (1.5 -> 0.8) is still the owner's, and these games say the Clockwork can now keep up without it against the Brood
   Economy.
2. **A Clocktower ring that holds 9** buildings is enough for 2 presses, the Mainspring and 6 more. No number change is
   needed for the spot rule.
3. Nothing else: no unit, building or research number was touched.

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
