# The Clockwork computer's air plan: the Owl raids (cw-builds-c, 0.28.5)

Short sentences, to be read aloud.

The owner, 2026-11-03: "do it all". This job is the AIR plan: Clock Aviaries, Swifts for scouting and the air, and
Ticking Owls that swoop on units and bomb buildings, harassing workers and soft production, keeping away from anti-air,
with the economy growing and a ground army at home.

Design rules followed (docs/design_principles.md): 1, fairness and counterplay (the Owls are slow, every anti-air unit
answers them, the computer sees only what its side sees and knows only where the enemy started); 2, anti-snowball (the
economy keeps growing behind the flock: Winders to 22 in the opening, a second Clocktower by 4:50). No unit, building or
research number was changed. The proposals are at the end.

## The short version

- **The build is on time.** The first Ticking Owl flies at 5:05 to 5:10 in every game. The third at 6:00 to 8:15. The
  computer researches TICKING OWL at 3:30 to 3:55. Its economy keeps up: 22 Winders at 6:00 against the Crown (the old
  Balanced plan: 23; the Springer timing: 19), about 13% fewer cogs earned by 8:00 than the old Balanced plan.
- **Against the Brood it is the best Clockwork plan we have.** The Brood's Hard computer floods the Clockwork base with
  Raptors from about 5:30, and Raptors cannot hit flyers. The Owls kill them for nothing: 1,075 to 3,950 value killed by
  the Owls alone in a game, 140 Raptors in one. Over three maps the Owl raids killed 4,066 and lost 3,643 by 10:00 (the
  old Balanced plan: killed 2,651, lost 5,930; the Springer timing: 650 and 5,808, and it lost two of the three games).
  The Owl raids lost none of the three.
- **Against the Crown it does little damage.** The Crown's Musketeers and Dragoons shoot flyers, and the Hard Crown keeps
  five to eight of them by its economy. In the coached and measured games the Owls killed two Labourers, a Cuirassier and four
  Musketeers in all. They mostly defend the base against the Crown's riders. The Crown earned about as much as against the
  old Balanced plan.
- **Why so little: the wind.** A Ticking Owl runs down in about 80 seconds off its gear field, and it flies 56 pixels a
  second. From home it cannot reach the enemy's main and come back. So two Winders (the CRANKS) go out with the flock to a
  CRANK POST about 22 tiles from the enemy's start, and the Owls go out from there. Setting the post up takes a minute or
  two, and the posts are often found by the enemy's army (Crown riders, Musketeers walking to a new Town Hall, Raptors).
- So, plainly: the plan works as a defence against the Brood, and as a slow, careful harass that the Crown answers easily.
  Making it a real harass needs a change to the Owl or to the wind of flyers (the owner's call, below).

## The build order

Steps are read in order, as a player reads a written build (the way scripts/ai_clockwork.gd reads every plan). A number
in front is the supply it waits for. A step waiting for a building or for Tension lets the next steps go with the cogs
left over; a step waiting for cogs or supply stops the reading there.

| # | against the Crown | against the Brood | what it means |
|---|---|---|---|
| 1 | 7 cog_press | 7 cog_press | the second Cog Press at 7 supply |
| 2 | 8 movement_works | 8 movement_works | the first Light Works (the Escapement needs it) |
| 3 | 9 mainspring:big | 9 mainspring:big | the Mainspring on its BIG ring (2.6 Tension a second with 6 Winders) |
| 4 | crew mainspring 6 | crew mainspring 6 | six Winders on it |
| 5 | 11 regulator | 11 regulator | supply |
| 6 | escapement | escapement | as soon as the Works stands |
| 7 | workers 18 | workers 18 | Winders up to 18 |
| 8 | cuckoo_house | cuckoo_house | the first Clock Aviary (it will research) |
| 9 | clock_soldier 2 | clock_soldier 3 | a little ground army at home |
| 10 | research owl_morph | ratchet_turret | TICKING OWL / a Ratchet Turret by the base (Raptors come at 5:30) |
| 11 | cuckoo_house | research owl_morph | the second Aviary (it makes the Swifts while the first researches) |
| 12 | 18 regulator | cuckoo_house | |
| 13 | cuckoo 4 | 18 regulator | four Swifts |
| 14 | morph 2 | cuckoo 4 | two Owls (each Swift that is safe at home, one by one: 100 cogs, 50 Tension, 20 s) |
| 15 | owl_raid | morph 3 | the raid starts with the flock (two Owls; three against the Brood) |
| 16 | workers 22 | owl_raid | |
| 17 | clocktower | workers 22 | the expansion |
| 18 | end | clocktower, end | the shared computer plays on (the "Owl raids" row: Balanced numbers, a later first wave) |

A Regulator also goes up out of order when the supply is nearly blocked. The opening is over by 7:30 whatever is left of
it (round A: on Frostmere its Swifts were lost and it waited for one with 3,900 cogs in the bank).

Why two Aviaries: TICKING OWL is a 60 second research AT an Aviary, and an Aviary does one thing at a time. With one
Aviary the first Swift would come after the research. With two, the Swifts are ready when the research ends, and the
first two Owls start at once.

What holds it back is Tension, as for the Springer timing: the Aviaries 50 each, TICKING OWL 150, the Swifts 15 each, each
morph 50. That is about 450 Tension by 5:30. The big Mainspring winds 2.6 a second.

## The raid (scripts/ai_cw_builds_c.gd)

- **The flock** is the Owls. **The scout** is one Swift (more when the enemy shows flyers): it loops round the enemy's
  start and its natural, out of reach of the anti-air it has seen, and flies ahead of the flock on a sortie. It pecks
  enemy flyers that come at the Owls. The other Swifts wait at home to be morphed.
- **The crank post**: on a ring about 22 tiles from the enemy's start, on low ground our side can walk, away from its
  ramp and the line its army walks out on, away from its natural expansions, from everything of the enemy seen there in
  the last two minutes, and from places where cranks were lost. The scout looks at it first. Then the two cranks walk out
  with the flock flying over them: anything that cannot hit flyers meets the Owls first, and a crank winds an Owl running
  low as they go (a Winder winds a unit he follows). At the post the cranks wind and mend the Owls.
- **A sortie**: when the flock is wound (90%) and mended (70% on average) and has three Owls (two after 45 seconds of
  waiting; two against a Brood with no anti-air seen), it picks a target: a Farm, the Powder Mill, a Town Hall going up,
  a Horse Breeder, Cottages, workers seen in the last 45 seconds (grubs and Rootmaws for the Brood). Each is scored by
  what it is worth, less the anti-air seen by it lately, less the anti-air on the way, less the distance, and only if the
  wind lets the Owls get there, strike and come back to the post. It flies round the anti-air seen on the straight line.
- **Up there**: anti-air in reach and weaker than 60% of the flock: the Owls swoop on it first (the most hurt). Then
  workers in reach, then the building aimed at, then the weakest building near it. Nothing left: the next target if the
  wind allows, else back.
- **Back** to the post (or home) when the anti-air there is worth more than 75% of the flock, when the flock is hurt
  (under 45% on average), when any Owl's wind is only just enough for the way back, or after 75 seconds.
- **Home defence comes first**: enemies at the base that cannot hit flyers (Raptors, Horsemen, Clock Soldiers) are the
  Owls'. A real attack on the base (150 value or more) calls the flock back from anywhere.
- **The post is found** (armed enemies by it): a new post at once if there is one far enough away, else the cranks run
  home and the Owls rest at home. Two cranks lost: no post for 150 seconds.
- **After the opening** the flock is topped up to six Owls: a Swift trained and morphed at home, from what the bank can
  spare, one at a time. New Owls fly to where the flock rests and join it there.
- The shared computer no longer turns a Swift that a plan uses (the Springer raid's scout, the Owl raids' Swifts) into a
  Ticking Owl (`AI._air` skips `_on_errand` units). This was the known issue in docs/clockwork_ai_rebuild.md.

## The coaching (round A and round B)

As for the Brood (docs/brood_new_play_3.md) and the Springer timing, the plan was played in filmed games, and the pictures
were looked at one by one. tools/play_clockwork_owls.gd films a game; tools/test_clockwork_owls.gd measures one.

Round A (Greenhold against the Hard Crown and the Hard Brood, three filmed games and about fifteen measured ones) found:

1. **From home the Owls cannot reach the enemy's main.** On Greenhold the first sortie turned back half way, low on wind,
   37 seconds out (picture 02: the two mains are corner to corner). So came the crank post.
2. **The cranks walking out alone were killed**, first by the Crown's rider scout at the map's middle (picture 04), then by
   Musketeers and Raptors. Now the flock flies over them and they wait at home when the flock is busy.
3. **The first posts were at the enemy's new expansion**: by the Crown's second Town Hall (picture 05) and by a Brood
   expansion (picture 07). One was even off the map. Now the post keeps away from the natural expansions, from all
   enemies seen there in the last two minutes, and the scout looks at it first.
4. **A new Owl made at home was counted in a sortie from the post**, 100 tiles away, and turned the sortie back at once.
   Now new Owls fly to the flock and join it there.
5. **The opening waited forever for a Swift that had died** (Frostmere: 3,900 cogs in the bank, nothing built). Now the
   opening ends by 7:30 whatever is left, and the third Owl is a top-up, not a step.
6. **Against the Brood the flock went raiding while Raptors ate the base** (picture 06: Raptors among the Clockwork
   buildings). Now a real attack on the base calls the flock back from anywhere, and the build against the Brood has a
   Ratchet Turret and a third Clock Soldier.
7. **Against the Crown the Owls struck a Powder Mill and a Cottage and were driven off within seconds** (picture 09): the
   Crown's main is small and its Musketeers are always near.

Round B is the measured games below and two filmed games on Kestrel Rise (pictures 08 to 14). One more fix came from them:
after a post was found, five new posts were picked in a second, each next to the enemies that had found the last one. Now
a post is never picked where enemies are seen.

## The numbers

Hard Clockwork against the Hard Crown and the Hard Brood (both on Balanced), seed 11, ten minutes, three maps. The Owl
raids against the old Balanced plan and the Springer timing on the same map and seed. tools/test_clockwork_owls.gd,
tables by tools/clockwork_owls_report.py. The fights vary a lot from game to game; one seed per map is a small sample.

### When the build is ready

| map, seed | enemy | plan | Aviary | TICKING OWL | 1st Owl | 3rd Owl | 1st sortie | 1st strike | 2nd hall laid |
|---|---|---|---|---|---|---|---|---|---|
| frostmere 11 | brood | owls | 3:30 | 4:43 | 5:10 | 5:58 | 7:01 | 7:14 | 4:50 |
| greenhold 11 | brood | owls | 3:38 | 4:46 | 5:07 | 6:01 | never | never | 5:41 |
| kestrel_rise 11 | brood | owls | 3:31 | 4:28 | 5:07 | 6:21 | 6:01 | 6:10 | 5:16 |
| frostmere 11 | crown | owls | 3:36 | 4:45 | 5:05 | 6:36 | 6:51 | never | 4:45 |
| greenhold 11 | crown | owls | 3:41 | 4:46 | 5:07 | never | 6:18 | never | 4:47 |
| kestrel_rise 11 | crown | owls | 3:25 | 4:49 | 5:09 | 8:13 | 8:16 | 8:32 | 4:49 |

(On Greenhold against the Brood the flock never went out: the base was under attack from 5:40 to the end, and it
defended. On Greenhold against the Crown the third Owl came after 10:00; the sortie at 6:18 was two Owls.)

### The economy and the fights

| map, seed | enemy | plan | Winders 4/6/8 min | cogs earned 4/6/8 min | enemy earned 8/10 min | killed / lost by 6:00 | by 8:00 | by 10:00 | the Owls' kills (value, workers, buildings) | sorties | winner |
|---|---|---|---|---|---|---|---|---|---|---|---|
| frostmere 11 | brood | owls | 18 / 21 / 27 | 2396 / 4055 / 5889 | 8995 / 11431 | 25 / 130 | 875 / 680 | 2565 / 4595 | 1075, 0, 0 | 1 | none |
| frostmere 11 | brood | springer | 18 / 19 / 3 | 2471 / 4113 / 5496 | 8948 / 11092 | 50 / 660 | 225 / 3305 | 450 / 6340 | - | - | brood (9:07) |
| frostmere 11 | brood | balanced | 15 / 22 / 19 | 2791 / 4475 / 6115 | 9178 / 12962 | 75 / 1030 | 1100 / 2200 | 2250 / 6260 | - | - | none |
| greenhold 11 | brood | owls | 16 / 22 / 2 | 2144 / 3782 / 4377 | 9283 / 14076 | 50 / 140 | 1450 / 1960 | 4185 / 3725 | 2585, 0, 0 | 0 | none |
| greenhold 11 | brood | springer | 18 / 19 / 7 | 2475 / 4110 / 5288 | 9041 / 11607 | 75 / 730 | 100 / 2520 | 175 / 6125 | - | - | brood (9:24) |
| greenhold 11 | brood | balanced | 15 / 18 / 14 | 2741 / 4318 / 5724 | 9549 / 13825 | 0 / 140 | 1675 / 2390 | 3315 / 6335 | - | - | none |
| kestrel_rise 11 | brood | owls | 18 / 18 / 20 | 2396 / 3838 / 5345 | 9716 / 13518 | 375 / 450 | 2850 / 1200 | 5450 / 2610 | 3950, 0, 0 | 1 | none |
| kestrel_rise 11 | brood | springer | 18 / 21 / 18 | 2479 / 4161 / 5597 | 9903 / 11457 | 475 / 380 | 1075 / 2245 | 1325 / 4960 | - | - | none |
| kestrel_rise 11 | brood | balanced | 15 / 20 / 26 | 2783 / 4455 / 7047 | 8233 / 13141 | 425 / 770 | 650 / 1260 | 2390 / 5195 | - | - | none |
| frostmere 11 | crown | owls | 18 / 22 / 28 | 2232 / 3931 / 5929 | 6840 / 9880 | 50 / 75 | 50 / 760 | 380 / 2335 | 0 | 1 | none |
| frostmere 11 | crown | springer | 15 / 17 / 25 | 2158 / 3301 / 4966 | 5320 / 8360 | 50 / 260 | 275 / 560 | 510 / 1820 | - | - | none |
| frostmere 11 | crown | balanced | 14 / 22 / 24 | 2609 / 4302 / 6620 | 4180 / 7980 | 50 / 60 | 100 / 700 | 215 / 940 | - | - | none |
| greenhold 11 | crown | owls | 18 / 22 / 27 | 2280 / 3964 / 5952 | 6460 / 10260 | 50 / 150 | 215 / 715 | 785 / 1690 | 0 | 1 | none |
| greenhold 11 | crown | springer | 18 / 20 / 26 | 2401 / 4067 / 5815 | 6080 / 9500 | 50 / 480 | 50 / 840 | 50 / 1875 | - | - | none |
| greenhold 11 | crown | balanced | 15 / 23 / 27 | 2659 / 4367 / 6779 | 6460 / 9120 | 50 / 100 | 50 / 1080 | 365 / 2160 | - | - | none |
| kestrel_rise 11 | crown | owls | 18 / 22 / 31 | 2545 / 4209 / 6107 | 5700 / 8740 | 50 / 0 | 165 / 315 | 915 / 1525 | 275, 2, 0 | 1 | none |
| kestrel_rise 11 | crown | springer | 18 / 21 / 26 | 2525 / 4211 / 6107 | 2660 / 2660 | 300 / 280 | 415 / 660 | 895 / 860 | - | - | none |
| kestrel_rise 11 | crown | balanced | 15 / 24 / 29 | 2711 / 4486 / 7190 | 6840 / 8740 | 50 / 70 | 125 / 550 | 1645 / 2555 | - | - | none |

Averages:

| plan, enemy | games | Winders 6:00 | earned 6:00 | earned 8:00 | killed / lost by 10:00 | the Owls' kills by 10:00 | games the Clockwork lost |
|---|---|---|---|---|---|---|---|
| Owl raids v Brood | 3 | 20.3 | 3,891 | 5,203 | 4,066 / 3,643 | 2,536 | 0 |
| Springer timing v Brood | 3 | 19.7 | 4,128 | 5,460 | 650 / 5,808 | - | 2 |
| old Balanced v Brood | 3 | 20.0 | 4,416 | 6,295 | 2,651 / 5,930 | - | 0 |
| Owl raids v Crown | 3 | 22.0 | 4,034 | 5,996 | 693 / 1,850 | 91 | 0 |
| Springer timing v Crown | 3 | 19.3 | 3,859 | 5,629 | 485 / 1,518 | - | 0 |
| old Balanced v Crown | 3 | 23.0 | 4,385 | 6,863 | 741 / 1,885 | - | 0 |

What the Owls killed: against the Brood, Raptors almost only (238 Raptors in the three games, 25 each), 13 Tyrant
Challengers and 8 Spitters; against the Crown, in the measured games, a Cuirassier, two Labourers and a Musketeer (Kestrel
Rise), and three Musketeers at a new Town Hall in a game of round A.
Workers lost by the enemy: the Crown 1 or 2 in a game (as against every plan: its workers run); the Brood about 20 against every
plan (the test counts a grub that turns into a creature or is spent as lost too); the Owls killed none.

## Why the harass is weak (what the films show)

1. **The wind.** 80 seconds of flight off the gear field, at 56 pixels a second: about 4,500 pixels in all, out and back.
   Greenhold's mains are about 3,000 pixels apart. So the Owls need the crank post, and the post needs a minute or two to
   set up, and is found often: the middle of the map is where the enemy's army and expansions are.
2. **The Crown's anti-air is its army.** Every Musketeer and Dragoon shoots flyers (20 a shot, 220 health and 1 armour on
   the Owl: 12 shots). The Hard Crown keeps five to eight Musketeers by its Town Hall and Farms, and they reach any spot
   of its small main in seconds. The Owls are slower than a Musketeer (56 against 62): they cannot even get away.
3. **The Crown's workers run** from armed enemies, and a Labourer (74) is faster than an Owl (56).
4. **The bomb is for buildings, but slowly**: 45 every 3 seconds. Three Owls take about 12 seconds for a Farm (500), with
   Musketeers on them after about 5.
5. **Against the Brood the Owls are near untouchable** until it makes Hatchlings, Pterodactyls or Challengers, and its
   computer did not make enough of them in these games. That is why the plan is good against the Brood: the Owls are the
   defence its Raptor floods cannot answer.

## Proposals for the owner (nothing changed)

Balance (the owner's call):
1. **Flyers run down slower** (Swift and Owl: half of Defs.WIND_DECAY, about 160 seconds), or the Clock Aviary winds the
   flyers in a wide ring round it. The Owls could then reach a main and back without a crank post. This is the change
   closest to the idea of an air harass.
2. **Owl speed 56 to 70.** It could leave the Musketeers behind (62) and catch a worker more often. Still slower than a
   Swift (118) and a Skywing.
3. **The bomb a little faster against Farms and Mills** (45 every 3 s to every 2 s), so a strike of 10 seconds does
   something before the Musketeers come. Telegraphed by the Owl's dive, as now.
4. **The Brood's computer should answer flyers** (Hatchlings from its Storm Sire when it sees Owls): today the Owl raids
   can farm its Raptors. This is the Brood computer's job (brood-ai-tune), not this plan's.

The computer (next jobs):
5. Pick the post from the map's shape before the game (a corner of the map near the enemy, away from every expansion),
   not only from what was seen.
6. Use the Owls against the Crown where its army is NOT: its third Town Hall and its Farms while its army is out attacking.
7. A switch: against the Crown, after two failed sorties, the plan turns to Springers or a Heavy Works (the "later" plan in
   docs/clockwork_ai_rebuild.md: the computer switches on what its scout sees).

## The architecture

- `scripts/ai_cw_builds_c.gd` (no class name; preloaded as `BuildsC` by AIClockwork): the plan (`PLANS["owls"]`, with
  `steps_brood` for the Brood), its own steps (`morph N`, `owl_raid`), the flock, the scout, the cranks and the post.
  Self-contained, so it merges cleanly with cw-builds-a and -b: AIClockwork only reads its PLANS, calls `step()` for a step
  it does not know, `tick()` every army think and `has()` for its units (`_on_errand`, `_held_worker`).
- `scripts/ai.gd`: the strategy row "owls" (name "Owl raids"; pt "Ataque de Corujas", es "Ataque de Búhos"), Clockwork
  only; a computer on RANDOM PLAN can pick it. And the one-line fix in `_air` (a plan's own Swift is never morphed).
- The other Clockwork plans play exactly as before.

## Tools

- `tools/test_clockwork_owls.gd`: one game, the Clockwork computer against the Crown or the Brood computer (`vs:`), with the
  milestones, a line every 30 seconds, the numbers at 4, 6, 8 and 10 minutes, what the Owls killed and the plan's
  decisions. `cw:balanced` or `cw:springer` for the comparisons. `check:1` is the test: the first Owl by 5:30, the raid
  ready by 6:00, the first sortie by 8:00, 18 Winders at 6:00, a second Clocktower laid by 7:30 (Greenhold seed 11 against
  the Hard Crown, `until:480`). `json:<file>` appends a line for `tools/clockwork_owls_report.py`. `owldebug` prints the
  flock, the cranks and the post every 10 seconds.
- `tools/play_clockwork_owls.gd`: the coached, filmed game. `coach:draft|nopost|ai`, `vs:crown|brood`, `set:key=value`. It
  writes minutes.txt, events.txt, and the pictures: the first Owl, the whole map when a post is picked, the post 40 s
  later, 8 s into each sortie, each strike, each turn back, each defence, a building destroyed, and the frames of the first
  strike for a GIF (`tools/play_brood_new_gif.py`).

      xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_clockwork_owls.gd -- \
          coach:draft vs:brood map:kestrel_rise seed:11 out:/some/folder end:600

## Pictures

docs/shots/clockwork_builds_c/ (captions.md says what each shows).

## What is open

1. The proposals above.
2. One seed per map: the fights vary a lot. More seeds would firm up the averages.
3. Against the Crown the harass does almost nothing yet (see why above).
4. Normal difficulty was not measured.
