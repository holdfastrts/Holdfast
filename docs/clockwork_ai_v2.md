# The Clockwork computer, second pass (job clockwork-ai-v2, 0.33.12)

Short sentences, to be read aloud.

The owner approved six fixes from the QA study of 8 November (docs/qa_2026_11_08_tests.md items 3, 5, 6, 7, 14 and 16;
docs/qa_2026_11_08_matches.md points 3 and 4) on 2026-11-11. This job owns the Clockwork computer (scripts/ai_clockwork.gd,
ai_cw_army.gd, ai_cw_push.gd). The changes to shared files are small and only touch the Clockwork: two Cog Press rules in
scripts/ai.gd (gear mode only), the sentry's peek in scripts/ai_scout.gd (the Clockwork only), and the computer's rule on
a turning gear band in scripts/gear_turn.gd (the computer's own units only). No unit, building or research number changed.
The other computers are not touched.

## The short version

1. **Dry land.** With its brass spent, the opening build hands over to the shared hall-first rule: a new Clocktower and its
   press first, before more units. Two more holes on the way: Cog Presses left by a razed Clocktower kept the new
   Clocktower's presses out for good, and the next press went by the dry main. Both fixed. test_ai_expand [clock] passes.
2. **Exceptions to ONE ARMY.** (a) A soldier or two found far from home harass the workers again (the shared harass);
   units far out walk home with a plain move, never an attack-move into a rooted creature. test_ai_harass [clock] passes.
   (b) The Great Winder walks just behind the army and sweeps the wrecks near it between fights. test_great_winder passes.
3. **The gear band.** A computer unit on a move order rides a turning band 6 s at most, then crosses without drifting.
   test_gear_turn_match passes.
4. **The sentry** peeks up the walled ramp now and then and backs off when it sees the guard (or is shot at).
   test_ai_scout_sentry passes (6 of 29 windows with a sighting; it wants 3; before 1).
5. **The air.** Enemy flyers seen: the Clock Aviary is laid at once, anywhere on the gear field, and Swifts trained at once.
   test_cw_air_ai: the Aviary placed 1 s after the balloon was seen (before 60-90+ s), built in 49 s, a Swift 20 s later.
6. **Finishing games.** The push COMMITS when it is clearly ahead: it goes for the enemy's halls (the Brood Mother against
   the Brood), stops holding short of a main it can take, and its front breaks buildings with the Ballistas. A big push
   marches in rows (a push of 55 soldiers stood still for three minutes because its front did not fit on one line). A push
   in the field survives OPTIMAL's late switch. Against the Brood the army no longer waits at home for an enemy twice the
   real one (the reckoning's table). The push now sets the shared "attacking" flag. The numbers are below.

## The numbers

Hard Clockwork OPTIMAL against Hard Crown OPTIMAL, Hard Brood OPTIMAL and itself, 8 maps (Cinder Steps, Red Coast, Ashfall,
Greenhold, Frostfang, Dune Sea, Redrock Canyon, Twin Fords), 2 seeds a map with the sides swapped, to 15:00: the qa
study's tags and seeds. "Before" twice: the qa study's own 48 games of these tags (0.33.7), and main at 0.33.11 (27 of the
48 played here, the first four and a half maps, cut to save time once they agreed with the qa games). "After": this branch,
all 48. Won or led: won, or led a draw (income earned + 2 x army value 10% ahead at the end). Mirrors are the P1 side's.

| Clockwork's pairing | | W-D-L | won or led | games decided (mean length) | enemy halls lost | its own halls lost |
|---|---|---|---|---|---|---|
| v the Crown | before (qa, 0.33.7) | 1-14-1 | 13 of 16 | 2 (13:03) | 24 | 7 |
| | before (0.33.11, 9 games) | 3-6-0 | 8 of 9 | 3 (12:24) | 12 | 1 |
| | **after** | **6-10-0** | **14 of 16** | **6 (11:29)** | 25 | 8 |
| v the Brood | before (qa) | 2-10-4 | 5 of 16 | 6 (13:18) | 11 | 15 |
| | before (0.33.11, 9 games) | 0-6-3 | 3 of 9 | 3 (13:34) | 4 | 12 |
| | **after** | **5-4-7** | **7 of 16** | **12 (12:11)** | 14 | 20 |
| mirror | before (qa) | 0-16-0 | | 0 | 26 | 4 |
| | before (0.33.11, 9 games) | 0-9-0 | | 0 | 17 | 2 |
| | **after** | **4-12-0** | | **4 (13:04)** | 33 | 10 |

- **It finishes more games.** Against the Crown 6 wins in 16 (before 1 in 16, 3 in 9), the decided games 1.5 to 2 minutes
  sooner; the first Clockwork mirrors ever decided (4 of 16; before 0 of 38 in the qa study). It committed in 13 of the 16
  Crown games and won 6 of those.
- **Against the Brood it goes out now, and it is decided both ways.** 12 of 16 decided (before 6 of 16): 5 wins (before 2),
  7 losses (before 4); won or led 7 of 16 (before 5 of 16, and 3 of 9). It committed in 6 games and won 5 of them. The
  losses are the cost of leaving home against an army the reckoning no longer doubles: see the open questions.
- **The economy is the same**: cogs earned by 8:00 7,590 / 7,066 / 9,450 (v the Crown / the Brood / mirror) against
  7,487 / 7,197 / 9,570 in the qa games; army at 8:00 1,850 / 1,205 / 1,875 against 1,812 / 1,227 / 1,785.
- **Its first attack is seen**: a median 6:20 against the Crown, 5:00 against the Brood, 5:20 in the mirror (before: never,
  the push did not set the flag).
- **The Great Winder**: a Great Winder comes only in some plans and games, and before it already swept now and then by its
  own idle look. Sides that swept anything: 17 of 64 after, 10 of 36 before (about the same share); cogs per side that
  swept: 148 against the Crown (before 44), 83 against the Brood (15), 120 in the mirror (163). The clear before/after is
  the test (test_great_winder: swept 0 before, a wreck swept within 15 s by the army now).
- **No stalls**: one "no unit made for 90 s" in 48 games (before: 3 in the qa games, 1 in the 27). Idle Winders after 4:00:
  1.1 to 2.9 on average, as before (1.5 to 3.2).
- **Script errors**: one game with ballista.gd:400 (a null target, the known error rules-fixes owns), as before.

Raw data: docs/clockwork_ai_v2/data/before_0_33_11/ and docs/clockwork_ai_v2/data/after/ (result.json, story.txt and
cwlog.txt, the Clockwork's own match log lines, per game); the qa study's in docs/qa_2026_11_08_matches/data/. The table:
`python3 tools/study/cw_v2_report.py docs/clockwork_ai_v2/data/after` (and any other data folder).


## What was wrong, and what changed

### 1. The stall on spent brass (tests item 3)

What was wrong. The Clockwork's opening runs as a written build order (AIClockwork.bo_on). While it runs, the shared
building rules are off, and with them AI._hall_first, the rule that saves a new hall's price once the land runs dry. In the
test (Cinder Steps, a Hard Balanced Clockwork, every other hall razed at 4:00, its bank cut to 150 and its brass to 8%)
the build order kept training soldiers and Winders. The brass ran out at about 1:00, and nothing came in again: 21 of 24
Winders idle for minutes, no Clocktower laid.

On the way two more holes showed up, once the hall was laid:
- The Cog Presses of the razed second Clocktower were still standing. A new Clocktower on the same ground does not turn
  them (they are not linked), but they count against the limit of two presses a Clocktower. So the new Clocktower got no
  press at all, ever. The rule that pulls down a spent press (AI._recycle_spent) thought the new hall was "worked",
  because those dead presses were by it.
- The next press was laid by the dry main, not by the new Clocktower: the gear-mode press spot (AI._drive_spot) tried the
  halls nearest home first, whatever their brass.

What changed.
- AIClockwork._dry_hand_over: once its land is dry (AI._dry: every hall under 25% of its brass) the build order ends ("its
  land is dry: a new Clocktower and its press first, before more units") and the shared rules take over at once. Their
  hall-first rule keeps the 540 cogs (hall and press) back from training. The plan's heavy machines (AIClockwork._b_keep)
  also wait while that money is kept.
- AI._recycle_spent (gear mode only): a Cog Press counts only if its gears turn; a press that stands still is pulled down
  like a spent one; a fresh Clocktower wants its two working presses before the pulling down stops.
- AI._drive_spot (gear mode, the Cog Press only): only halls with brass left, when there is one.
- Result: the hall is laid at 28 s, its press comes, and the computer earns again (test_ai_expand: 1,140 cogs in the
  last minute where it had 0). Design principle 2: depletion forces expansion; a barren computer is no opponent.

### 2a. The harass again, and the walk home (tests item 5)

What was wrong. Since ONE ARMY (clockwork-army) the shared harass was never ticked for the Clockwork. A lone Clock Soldier
out by the Brood was sent home with an attack-move. An attack-move stops at the first enemy on the way, and a rooted Mound
Turtle is one: it stood there for the whole 40 s.

What changed (the owner said yes to the exception).
- AIClockwork._army_one runs the shared harass again (scripts/ai_harass.gd): a soldier or two found 900 px or more from any
  of its buildings (left behind by a push or a chase; never the army's defenders, never during a whole-army defence) is
  taken by it, at most three at once. The harass goes for the worker line, rides past rooted creatures, pulls back from
  a Tyrant Sire and comes again, and goes home when hurt, run down, out too long or driven back too often.
- ai_cw_army: a unit walking back to the gathering point from more than 640 px out (FAR_PLAIN) walks with a plain move.
  Nearer home it is an attack-move, as before.
- `-- cwharass:off` plays it as 0.33.11.

### 2b. The Great Winder sweeps (tests item 6)

What was wrong. Two things gave the computer's Great Winder orders while the push was out: the push (190 px behind its
anchor) and the shared follow (60 px behind the army's middle). Each moved it, again and again. Its sweep is an idle job,
so it never swept. It stood 230-330 px from the army.

What changed.
- One controller at a time: the push while the Great Winder is in it (it joins the push at once, with a plain move, not
  with the joiners' attack-move across the map), else the follow.
- It stands nearer: 90 px behind the push's anchor (BACK_GW_V2), 100 px behind the army's middle at home (GW_BACK).
- Between fights (no enemy soldier within 420 px of it) the computer itself sends it to the nearest wreck within 300 px
  of it or of the army's middle (AIClockwork.gw_tend, GreatWinder.sweep_pick: its own side's wrecks and an enemy
  Clockwork's, never one with an enemy soldier near it). It rolls back after.
- `-- cwgw:off` plays it as 0.33.11.

### 3. The Winder riding a gear band (tests item 7)

What was wrong. A computer Winder had a move order to a spot just past a turning band. The band carried it back round
as it walked; 39 s in one go. The computer walks its idle and HOLD units off a band, not a unit on a move order.

What changed. scripts/gear_turn.gd: Unit.ride_t now counts the seconds of the ride in one go (it was a total nobody read).
A COMPUTER's own unit on a plain move order that has ridden MOVE_RIDE (6 s) in one go crosses the rest of the band without
drifting, like a worker on its way to work. The player's units ride as before. The test's longest ride on a move order
is now 6.7 s (before 39 s). The test no longer counts a loose horse standing on a band (a horse takes no orders).

### 4. The walled-ramp sentry (tests item 14)

What was wrong. The sentry stands outside every gun it knows of, with a margin. A Winder sees 7 tiles (224 px); a
Musketeer reaches 190 px plus the two radii, plus that margin: 222 px. So it stood where it could see nothing. And seen
from the low ground, the high ground behind the wall is hidden anyway (Game._stamp: only the next cells).

What changed (scripts/ai_scout.gd, the Clockwork only): THE PEEK. Once it has stood at its post 20 s, and every 22 s after
(SENTRY_PEEK), it walks 4 tiles up the ramp. The moment it sees an armed enemy, after 7 s, or when it is shot at, it walks
back to its post. Shot at, the next peek waits twice as long. It accepts the risk the owner allowed: in the test it was
lost twice in 300 s (a Winder each time, replaced as before), and the computer had a sighting in 6 of 29 ten-second
windows (before: 1). `-- cwpeek:off` switches it off.

### 5. The air answer (tests item 16)

What was wrong. The shared air rule (AI._air) runs from the tech round, which looks again only every 20 s, and not at all
while the opening build runs. With no room by a Mainspring it first built a spare Mainspring and laid the Aviary only once
that stood. The Aviary came 60-90+ s after a Crown balloon was seen.

What changed. AIClockwork._air_answer, every think (the build order included): enemy flyers seen and no Aviary: the shared
rule first, and if it laid nothing, an Aviary anywhere on the gear field (a Mainspring anywhere in the network feeds it,
as for the Escapement since 0.25.0). Once it stands, Swifts at once, one more than the flyers seen (up to 6).
`-- cwair:off` plays it as 0.33.11.

### 6. Finishing games (matches points 3 and 4)

What was wrong, read from the push's own log lines (the measured games below keep them, cwlog.txt):
- **It held short of the enemy's main** with far more than the enemy: "holds short of the enemy's main: worth 1,980, the
  enemy's army seen lately 0" (Greenhold, against the Crown, 11:16). Against the Crown the main waits for 2,000 of push
  (main_min) and for 1.3 times the enemy army seen lately.
- **A big push stood still.** The front stood on one line across the way, 260 px wide at most. A push of 55 Clock
  Soldiers could not all fit there; the march goes on only when 60% of the front is within 140 px of its anchor; they
  never were. Greenhold mirror: a push of 69 units (6,425 value) went out at 12:01, "heads for the enemy's base", and
  nothing else happened until 15:00.
- **Its Ballistas broke every building alone.** At a goal every building was a siege for the Ballistas, the front
  screening them: one Cottage or Palisade every 10 s.
- **The match tools never saw it attack.** The push never set the shared "attacking" flag.

What changed (scripts/ai_cw_push.gd):
- **The commit.** From 8:00, a push worth twice the enemy army it has seen near it lately AND twice the enemy army it
  reckons (ai_cw_army.reckon: what it saw, never less than an enemy of that age has, less half what it has killed), and
  at least 1,200, is COMMITTED. Committed it goes for the enemy's nearest HALL (against the Brood: the Brood Mother, the
  losing condition), it no longer holds short of a main for the enemy army it has seen (a walled Crown main still wants
  the plan's 2,000), and at the goal the whole push breaks the building (the front too, not only the Ballistas); at a wall
  in the way the front helps the Ballistas when no enemy comes out. It still pulls back by the usual rules. It says so in
  the AI STORY ("is clearly ahead ... it presses on to the enemy's halls to finish").
  A first try committed from any time and against the enemy seen only: at 6:27 on Greenhold it took 1,350 against 57 seen
  up to the Crown's walled main and lost the push. Hence 8:00 and the reckoning.
  Once committed it stays so down to 1.6 times (a fight's numbers going up and down made it flip every few seconds).
  Committed, a hall it aims at stays its goal until it falls (picked again every 8 s as the nearest to the anchor, the
  goal swapped between two halls and the push walked to and fro), and a main wants 0.75 of the plan's main_min (1,500
  against the Crown, 1,950 for the Heavy Works push: 1,875 held short of a Crown main for four minutes against 187 seen).
- **A push out survives OPTIMAL's switch.** OPTIMAL may switch the build once a stage; the switch made a new push and
  dropped the one in the field (its units walked home one by one; a committed push of 65 among them, Cinder Steps mirror
  13:50). Now the push out goes on under the new build's push settings.
- **The Brood's reckoning.** The army waits at home until it is worth 1.25 times the enemy army it reckons
  (ai_cw_army.may_launch). Against the Brood the reckoning's table (what a Hard Brood has at that age) was about twice the
  Hard Brood's real army from 7:00: in the before games the reckoning was 1.8 to 3.5 times the Brood's real army, and the
  Clockwork's army "held at its gathering point" 7 to 12 times a game, often never going out until the Brood had out-grown
  it. The table from 7:00 is now the strongest quarter of the Hard Brood's army in the qa study's 152 Brood sides: 1,100 at
  7:00, 1,300 at 8:00, 1,900 at 10:00, 2,700 at 12:00, 3,100 at 14:00 (was 1,400, 2,200, 3,800, 5,000, 5,000). Its rooted
  creatures seen still count on top (1.5 times). The Crown's and the Clockwork's tables were checked the same way and are
  at or under their real armies' median: unchanged.
- **Rows.** A front of more than 12 stands in rows of 12, 26 px apart, and "at the anchor" grows with the rows.
- **"Attacking".** AIClockwork sets the shared flag while the push marches, fights or lays a siege.
- The end-of-game hunt for the last buildings is rules-fixes' job (the shared AI); this job makes the Clockwork's own push
  press on.
- `-- cwcommit:off` and `-- cwrows:off` play those as 0.33.11.

## Tests

Run on the branch (all pass): test_ai_expand (both cases), test_ai_harass (clock, horse, raid), test_great_winder,
test_gear_turn_match, test_ai_scout_sentry, test_cw_air_ai, test_clockwork_army (check:1), test_clockwork_home (check:1),
test_ai_optimal, test_files, test_i18n.

Tests changed:
- test_great_winder: with the push out, "the army" it checks the Great Winder against is the push (since clockwork-army the
  Great Winder is the push's); it prints where the victim falls and the nearest enemy.
- test_gear_turn_match: a loose horse standing on a band is not counted (it takes no orders); the longest ride per order
  prints its goal, whether that is on a band, and its path.
- test_ai_expand (EXPAND_LOG): prints each press's cell, link and speed and the halls.
- test_cw_air_ai (AIR_LOG) and test_ai_scout_sentry (SENTRY_TRACE): optional traces.

## How it was measured

- tools/qa_match.gd (qa-matches' tool) now also writes, per player and minute, the cogs its Great Winders swept
  ("gw_cogs"), the idle Winders now and on average after 4:00 ("idle_w", "idle_w_avg"), and the Clockwork push's phase.
- tools/study/qa_matches.py `--only cw`: the Clockwork's three pairings (v the Crown, v the Brood, the mirror) on 8 maps
  (Cinder Steps, Red Coast, Ashfall, Greenhold, Frostfang, Dune Sea, Redrock Canyon, Twin Fords: its best and worst maps of
  the qa study and a few between), the base rounds' tags and seeds (2 seeds a map, the sides swapped between them), Hard
  OPTIMAL on both sides, to 15:00: 48 games. `--root DIR` runs another checkout (the "before"), `--cwlog` keeps the
  Clockwork's own lines of each match log.
- tools/study/cw_v2_report.py: the table above.
- "Before" is main at 0.33.11 (worktree, the same tools). The qa study's own 48 games of these tags (0.33.7) are a second
  "before".

## Claude's choices for the owner

1. **Which strays harass.** The shared harass's own rule: a soldier found 900 px or more from any of the Clockwork's
   buildings, on an attack-move, attacking or idle, not one of the army's defenders, not during a whole-army defence; at
   most three at once. Under ONE ARMY such strays are the ones a push or a chase left behind. The plans' own raids are
   unchanged. If you would rather the lone ones always walk home, `-- cwharass:off` is that (they then walk home with a
   plain move from 640 px out).
2. **The Great Winder's leash.** It stands 90-100 px behind the army and sweeps wrecks within 300 px of itself or of the
   army's middle, between fights (no enemy soldier within 420 px of it, and the wreck itself safe by the Great Winder's
   own danger rule). In the test it never was more than 136-156 px from the army's middle while it swept. Your "within
   ~150 px" is its resting place; a sweep may take it a little further for a few seconds.
3. **The gear band rule** is in scripts/gear_turn.gd, next to the rule that walks the computer's idle units off a band:
   6 s of riding on a plain move order, then it crosses without drifting. Only the computer's units; the player's ride as
   before.
4. **The sentry's risk.** A peek every 22 s once it has stood 20 s at its post (44 s after it was shot at), up to 7 s,
   back at once when it sees an armed enemy. In the test it lost a Winder about every 100 s (3 posts in 300 s, as before)
   for 6 sightings in 29 windows. A Winder can only see behind a wall from the ramp itself (the high ground is hidden from
   the low ground beyond the next cells), and a Winder's sight is a Musketeer's reach: there is no safe spot that sees.
5. **The commit's numbers**: from 8:00, twice what it has seen near it lately and twice the reckoning, at least 1,200,
   kept down to 1.6 times. A walled Crown main still wants 2,000 of push (the plan's own number, clockwork-army). Its
   retreats are the usual ones.
6. **The Brood's reckoning table** (an AI table, not a game number): from 7:00 it is now the strongest quarter of the Hard
   Brood's army in the qa study (it was about twice that). Before 7:00 it is as it was (raised on purpose by
   clockwork-army). Without this the Clockwork rarely went out against the Brood at all: in the before games its army
   "held at its gathering point" 7-12 times a game against a reckoning 1.8 to 3.5 times the Brood's real army.
7. **Dry land ends the opening build for good** (it does not come back to it once a new hall stands): the shared rules
   then play the plan's numbers, as after any opening.
8. **The air**: an Aviary anywhere on its gear field rather than waiting for a spare Mainspring with room by it.
9. **"Attacking"**: the Clockwork's push now sets the shared flag (while it marches, fights or lays a siege). Nothing else
   of the Clockwork reads it; the qa tools and the AI STORY's first-attack count do.

## Open questions

1. **Against the Brood the Clockwork now loses more as well as wins more** (7 losses in 16, before 4). With the old
   reckoning it mostly waited at home and the games ran to 15:00; with the reckoning at the Brood's real army it goes out
   with 1.25 times it. Its pushes against the Brood still meet the rooted Rootmaws and Mound Turtles and the Raptors that
   come (clockwork-army's finding). Worth a look of its own: a higher margin against the Brood (1.5 instead of 1.25?), or
   the Pendulums first (the Clockwork's anti-swarm machine) before a push against the Brood.
2. **The commit's numbers** (8:00, twice, 1.6 to stay, 0.75 of main_min) were set from these games; a later study could
   tune them. A committed push still loses to a walled Crown main now and then (the Crown's Musketeers on the high ground).
3. **The end of the game** is still often a draw with one side beaten in all but name: the last buildings are rules-fixes'
   hunt (the shared AI). With the hunt merged the decided games should rise again; worth measuring both together.
4. **The sentry** costs about a Winder every 100 s on a walled ramp. A flyer would see over the wall without the risk (the
   Clockwork has the Swift once its Aviary stands): a Swift sentry when there is one?
5. **The AI STORY's expansion line** reads "its best base has only 100% left" when the Clockwork expands for its Winder
   count, not its brass (AI._hall_first's need by workers). Not changed here (a shared line).
