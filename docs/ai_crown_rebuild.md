# The Crown's own computer (0.29.0, branch crown-ai-rebuild)

The owner (2026-11-03): the Crown and Clockwork computer was one 8,000-line script (`scripts/ai.gd`) with branches per
faction; its strategies were five multipliers (first wave size, expand sooner or later, tech sooner or later, worker
count); gold went to whichever stage of the think spent first, and later fixes HID gold to reserve it (`_hide_econ`,
`_hide_kept`, `_hide_repair`); every playtest added a module beside the old code. The Crown still lost to the Brood's
economy and timing. The job: give the Crown a computer of its own, like the Brood's (`scripts/ai_brood_new.gd`), with a
real opening build order per plan that owns the gold, then milestone rules per plan that follow the owner's doctrine,
coached and filmed like the Brood's (docs/brood_new_play_3.md).

Pictures: `docs/shots/crown_ai_rebuild/` (captions in its `captions.md`).

## 1. How it is built

`scripts/ai_crown.gd`, `class_name AICrown extends AI`, is made for every Crown computer wherever the Brood gets
`AIBroodNew` (`scripts/main.gd`, `scripts/ui/sandbox.gd`, `scripts/net/net_session.gd`, `tools/perf_bench.gd`). It
inherits the shared computer and overrides only what it owns, so everything that worked keeps working: the scout and its
reads (`scripts/ai_scout.gd`), the raids and the harass micro (`scripts/ai_harass.gd`), the ramp post on HOLD and the
rider scouts (`scripts/ai_crown_hold.gd`), the walls on a new hall (`scripts/ai_expand_wall.gd`), the transitions after a
held rush (`scripts/ai_transition.gd`), the retreat, the horses, the repairs and the gg.

What it owns:

| part | what it does | where |
|---|---|---|
| the plans | `AICrown.PLANS`: per plan an opening (`"opening"`: mill or breeder), the build order (`"bo"`), the Mill's crew in the opening (`"mill"`), the labourer cap in the opening (`"labs"`), the army's share of the labourers after it (`"army"`), the milestones (`"mid"`) and the shared settings it plays with (`"s"`: wave, step, expand...) | top of the file |
| the opening | `_think_stage` while `bo_owns()`: the plan's reserve is taken out of the bank for every other part of the think, the labourers are trained from what is left (`_bo_labs`), the next step is done when its trigger is met (`_bo_tick`, `_st_*`), a Cottage first whenever the supply is about to block (`_supply_due`) | "the think", "the steps" |
| a rush in the opening | `_defending` / `_bo_defence` / `_soldiers_first`: the wall, the Barracks and the Mill put first, soldiers before labourers, no hall till the rush is held, then the hall at once | after `_bo_tick` |
| the end of the opening | its last step done (the second hall laid, or the first attack out), the timing called off (`ATTACK_WAIT`), or `BO_LIMIT` (10:00) | `_bo_end` |
| the milestones | after the opening `_build_up` (the shared one: halls, the bank, the walls) then `_mid_tick`: the plan's next building whose trigger (labourers, halls, army supply) is met, one a think, its gold set aside (`_reserve`) | "after the opening" |
| the Mill's crew | `_mill_cap`: the plan's most in the opening; after it the crew follows the powder bank (`_mill_feedback`: a bank over twice `POWDER_WANT` sends a hand back to the farms, one under it brings one over, at most one every 8 s) | `_mill_cap` |
| an army the size of the economy | `_army_due` / `_base_trains_labs`: after the opening, while the army's supply is under the plan's share of the labourers, a hall trains a labourer only when every Barracks is busy | `_army_due` |
| no wave into a bigger army | `_wave_worth`: a wave goes only worth 1.1 times (1.5 against the Brood) the enemy's mobile army seen in the last 2 minutes, unless it is 60 supply or at the cap | `_wave_worth` |
| the doctrine's high ground | `_hall_first`: no third hall while the enemy is at our buildings or clearly bigger on our side; `_guard_new_hall`: no guards walk out to a hall site; `hold_beat`: against the Brood the ramp post goes down to the expansion only with twice the force there | after `_mill_cap` |

Hooks in the shared `scripts/ai.gd` (small, so the parallel Clockwork job merges cleanly): `_base_trains_labs()` (the
hall trains labourers by the shared rule), `_plan_tech()` (the Barracks, Foundry, Armoury and Church come from a plan's
milestones instead of the shared clock rule) and `bo_owns()` (a build order owns the gold: the scout's defence builds
nothing meanwhile, `scripts/ai_scout.gd`). `scripts/ai_crown_hold.gd` asks `hold_beat()` for its BEAT when the computer
has one. The AI STORY has sentences for the new match-log lines (`scripts/ai_story_lines.gd`, `tools/i18n/50_crown_ai.txt`).

No hiding tricks in the opening: the shared code's `_hide_repair`, `_hide_econ` and `_hide_kept` are not called while
the plan owns the gold; one rule does it, the plan's reserve. After the opening the shared economy-first rules play on
(they are what made 0.27.2's economy work), with the two changes above (the army's share, the milestones).

**Switch**: `-- crownnew:off` on the command line plays every Crown computer as the 0.27.2 shared computer (the AICrown
object then calls the shared code for everything). Easy plays the shared rules (no build order, no milestones).

**Deleted**: nothing. Every Crown path the plan replaces is still what `crownnew:off`, the Easy level and the tests that
make a shared `AI.new()` for the Crown play; deleting it would remove the comparison the owner asked to keep. What the
owner can drop once he has compared: in `scripts/ai.gd` the Crown branches of `_econ_build` (the build order of farms,
Mill and Breeder), the Crown tech lines of `_build_up`, `_workers`' `hold_gold` rules for the Crown, `_army_first` /
`_eco_first` / `_tech_wait` / `_turtling` / `_econ_wait`, and `AIScout._defence` for the Crown.

**The Marching Band** (an experiment, off by default) is not used by any plan. Its hook in `AI._produce` (one band once
the army is 6 strong) keeps working when the experiment is on, because the plan trains soldiers through the shared
`_produce`. To make a plan want it later: a `{"do": "army", ...}` step already lets `_produce` run; a step
`{"do": "build", "k": "barracks"}` plus a line in `_produce`'s band rule reading `plan.get("band", 0)` is all it needs.

## 2. The plans

### Crown doctrine lines (every plan, every matchup: apply them to any new plan)

- **THE FOUNDRY BEFORE THE SECOND BARRACKS** (the owner, DECIDED 2026-11-03 22:33: "even in the Horseman rush, the rush is
  done with 1 Barracks; I don't think there is any case you build the second Barracks before the Foundry"). The Field
  Cannon's canister also hits flyers (the Crown's answer to massed air) and its round shot has the longest range in the game
  (430). Every plan's opening and milestones list the Foundry before any second Barracks (`tools/test_crown_build_order.gd`
  [table] checks it), and `AICrown._construct` turns any other call for a second Barracks with no Foundry (the shared rules,
  the scout's plan, the bank) into the Foundry. The Horse Breeder comes either way (the gun needs a horse).
- **Riders are an addition, never a reason to skip or delay the Foundry**: when the scout sees things landing in the base
  (Springers, drops), enemy artillery (the Horsemen's bonus against cannons, Spitters, Arc Throwers), a greedy enemy to
  punish, or for map control. Against the Brood the first horse goes to a Field Cannon (`AICrown.cannon_first`,
  docs/crown_cliff_edge.md).
- **The Crown's expansions** at the least hall distance, close together, under the main's cliff edge (CrownSites,
  docs/expansion_spots.md "The Crown's rule").

Every step waits for its trigger, then its price is set aside until it is paid; the labourers and the soldiers only get
what is left. A Cottage comes first whenever the supply is about to block (two left, two more for each Barracks). The
triggers are labourers (the hall trains one every 12 s while the gold lasts) or supply, never the clock. Times in brackets
are what the coached games showed on Hard (Red Coast, Greenhold, Kestrel Rise), to read the order by, not rules.

### Economy (Powder Mill opening): expand first

| step | trigger | (when) |
|---|---|---|
| the ramp Cottage (the first piece of the wall) | 5 supply | 0:00, done 0:22 |
| the second Farm | 7 labourers | 0:39 |
| the ramp Gate | 7 labourers | 0:39 |
| the Barracks | 8 labourers | 0:52 |
| the Powder Mill | 8 labourers | 1:00-1:40 (the next harvest) |
| Musketeers from now on, 6 supply in the opening | - | 1st at 2:48-3:33 |
| the second Town Hall (safest rated site, three builders) | 15 labourers | 3:08-3:25 |

Mill crew in the opening: 2 hands, 4 from 14 labourers, 6 from 18 (fewer while powder piles up). Then the milestones:
the Foundry (the ramp cannon) at 20 labourers with two halls, the Horse Breeder at 20, a second Barracks at 22 with two
halls (0.29.2: the Foundry before the second Barracks; before, the second Barracks at 20, the Breeder at 22, the Foundry at
26), the Armoury at 30, a third Barracks at 34, the Church at 40, a second Foundry at 48 with three
halls. The army is kept at 0.4 supply a labourer; the first wave at 34 supply (the doctrine's timing on two halls
may send it sooner).

### Balanced (Powder Mill opening): the safe Musketeer opening, expand at 15

| step | trigger | (when) |
|---|---|---|
| the ramp Cottage | 5 supply | 0:00, done 0:22 |
| the ramp Gate | 5 supply | 0:22, done 0:37 |
| the Barracks and the Powder Mill | 7 labourers | 0:43 |
| Musketeers from now on, 8 supply in the opening | - | 1st at 2:04-2:10 |
| the second Farm | 9 labourers | 1:48 |
| the Horse Breeder | 13 labourers | 3:30-4:10 |
| the second Town Hall | 15 labourers | 4:00-5:05 |

Mill crew: 3, 5 from 13 labourers, 6 from 16. Milestones: the Foundry at 18 labourers, then the second Barracks at 18
(0.29.2; before, the second Barracks at 18 and the Foundry at 22; against the Brood the Foundry comes before the Breeder
in the opening, docs/crown_cliff_edge.md), the Armoury at 26, the third Barracks at 30, the Church at 36 with two halls, a second Foundry at 44 with three. Army 0.55
supply a labourer; the first wave at 18 supply.

### Timing attack (Powder Mill opening): one hall, the Foundry, two Barracks, one hit

| step | trigger | (when, 0.29.0 order) |
|---|---|---|
| the ramp Cottage, the Gate | 5 supply | 0:22, 0:37 |
| the Barracks and the Powder Mill | 7 labourers | 0:43 |
| the second Farm | 9 labourers | 1:48 |
| Musketeers from now on, no cap | - | 2:04 |
| the Foundry (a cannon with the wave) | 13 labourers | (0.29.2; was third, at 17) |
| the Horse Breeder | 15 labourers | 4:30 |
| the second Barracks | 17 labourers | (0.29.2; was first, at 13) |
| the first attack: 22 supply | 22 army supply | 7:00-7:30 |

The labourers stop at 19 in the opening. The wave goes only with an edge over the enemy army it knows (1.5 times against
the Brood); held back 45 s, the timing is called off and the plan expands. Milestones: Armoury at 20 labourers, third
Barracks at 28, Church at 30 with two halls, second Foundry at 40 with three. Army 0.7 supply a labourer.

### Rush (Horse Breeder opening): three Horsemen at the enemy's workers

| step | trigger | (when) |
|---|---|---|
| the ramp Cottage | 5 supply | 0:22 |
| the Barracks | 7 labourers | 0:36 |
| the Horse Breeder | 8 labourers | 0:49 |
| Horsemen from now on, before labourers | - | 1st at 1:52-2:04 |
| the second Farm | 9 labourers and the first Horseman | 2:50 |
| the ramp Gate | 10 labourers | 2:20 |
| the first attack: 9 supply (3 Horsemen) | 9 army supply | 2:56-3:13 |

The labourers stop at 12 until the rush is out. Mill crew 2 (the Mill comes as the first milestone). Milestones: the
Powder Mill, the Foundry at 16 labourers, then the second Barracks at 16 (0.29.2; before, the second Barracks at 16 and
the Foundry at 22; the rush itself is done with one Barracks), Armoury at 24, third Barracks at 30, Church at 34 with two
halls. The rush is judged by the shared rush rules (FAILED: home and build up; SUCCEEDED: mop up). After it the plan
plays a full economy (all the posts, a normal expansion time: the shared Rush settings, 0.75 of the posts and a late
hall, held it at 16 labourers till 6:00).

### A rush scouted in the opening (any Musketeer plan)

The scout's "rush" verdict (an early army or fast riders seen) puts the defence first inside the plan: the ramp Cottage,
the Gate, the Barracks and the Mill are moved to the front if they are not up, soldiers have no cap, a hall trains a
labourer only when every Barracks is busy (until 6 Musketeers), the Mill keeps at least 3 hands, and the hall step waits.
When AITransition calls the rush held (no enemy at our buildings for 10 s, our army worth what it saw), the hall step
goes at once (EXPAND) or the whole army goes out (COUNTER), and the build order carries on.

## 3. Coaching, round A (the first drafts)

The tool is `tools/play_crown_1.gd` (it extends `tools/shot_ai_match.gd`, the filmed AI match): side 0 is the Crown
computer on a forced plan (`coach:<plan>`, any plan setting changed with `set:key=value`), side 1 the normal computer on
Hard. Every game is filmed: the fights, both bases at 3:00 / 6:00 / 10:00, the second hall laid, the labourer scout at
the enemy's base, the first Horseman scout out, the ramp post holding, an enemy force at home (and a clip of it), the
first attack (a clip, made into a GIF by `tools/play_brood_new_gif.py`) and a picture when it arrives; `minutes.txt` has
a line a minute (labourers, farms, Mills and their crew, gold and powder banked and earned that minute, supply, both
armies by kind, kills and losses, the plan's state); `events.txt` the build order's steps and the plan's decisions.
`tools/play_crown_table.py` makes the table below from a round's folder.

    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_crown_1.gd -- \
        coach:economy b:brood sb:timing map:red_coast seed:4291306512 out:/some/folder end:780
    python3 -I tools/play_brood_new_gif.py /some/folder

Round A: 12 games of 13 minutes, the opponent on Hard. The fixes went in while the round was played (each game played
the code as it stood when it started: a01-a02 the first draft, a03-a10 with the Mill's crew and the high-ground fixes,
a11-a12 with the plan's own rush defence too). I looked at every game's pictures; what they showed is under the table.

| game | plan | against | map, seed | result | labourers 4/6/8 | gold a minute 6/8 | army 6/8 | enemy army 8 | 2nd hall | 1st attack (supply) | killed / lost |
|---|---|---|---|---|---|---|---|---|---|---|---|
| a01 | Economy | Brood Timing | Red Coast 4291306512 | L 9:49 | 18/30/30 | 1140/1140 | 420/100 | 3450 | 3:12 | - | 1775 / 3305 |
| a02 | Balanced | Brood Rush | Greenhold 3 | alive 13:00 | 9/10/9 | 0/0 | 475/475 | 1150 | 4:43 | 12:49 (18) | 2525 / 335 |
| a03 | Timing | Brood Economy | Kestrel Rise 2039763518 | alive 13:00 | 14/18/20 | 760/760 | 780/595 | 3200 | 7:30 | 6:59 (22) | 2700 / 3510 |
| a04 | Rush | Brood Balanced | Greenhold 11 | alive 13:00 | 13/19/36 | 760/1140 | 560/905 | 3615 | 4:35 | 3:39 (9) | 5340 / 7355 |
| a05 | Economy | Clockwork Balanced | Kestrel Rise 5 | alive 13:00 | 12/17/30 | 760/1520 | 480/875 | 1750 | 3:18 | 9:10 (18) | 3815 / 3730 |
| a06 | Balanced | Clockwork Timing | Red Coast 7 | alive 13:00 | 14/21/36 | 1140/1900 | 655/1095 | 2295 | 5:05 | 7:31 (14) | 5445 / 3135 |
| a07 | Timing | Clockwork Rush | Greenhold 3 | alive 13:00 | 14/15/20 | 380/1140 | 535/750 | 1960 | 4:42 | 11:08 (28) | 4315 / 2660 |
| a08 | Economy | Brood Extreme rush | Ashford Crossing 4242 | alive 13:00 | 9/12/14 | 380/760 | 360/540 | 1200 | 3:48 | 11:21 (19) | 2875 / 1585 |
| a09 | Balanced | Brood Timing | Highmoor 1 | L 11:25 | 15/21/31 | 1140/1520 | 715/1050 | 3675 | 5:02 | - | 3225 / 6015 |
| a10 | Rush | Clockwork Balanced | Highmoor 5 | alive 13:00 | 12/17/26 | 760/1140 | 735/860 | 1895 | 4:14 | 3:56 (9) | 3975 / 2505 |
| a11 | Balanced | Brood Rush | Greenhold 3 | alive 13:00 | 14/18/29 | 760/760 | 635/1105 | 1525 | 4:57 | 8:21 (18) | 3500 / 1355 |
| a12 | Economy | Brood Timing | Red Coast 4291306512 | L 11:35 | 18/32/22 | 1520/760 | 455/850 | 4595 | 3:13 | - | 3370 / 6370 |

("alive" = both sides still standing at 13:00; the enemy army counts the Brood's rooted creatures, its Mother too.)

What the films showed, and what was changed:

1. **The Mill's crew starved the farms, then the soldiers** (a01, a02; `base_0_0600` of a02: both farms 0/8 and 1/8,
   the Mill 6/6, 300 powder unspent and no gold for three minutes). The shared rule kept 1-3 hands on the Mill until
   5:00 and then sent everyone; the first draft gave every Mill its full crew after the opening. **Fix**: the crew follows
   the powder bank (`_mill_feedback`), a hand at a time, at most one every 8 s (a think each time swung it 6 -> 1 -> 6 in
   a03).
2. **The army went down in ones and twos** (a01 `fight_0720`: Musketeers spread over the open ground at the expansion,
   each one fought by Raptors). Three causes: the ramp post went down to the expansion against a force it "beat" by value
   (twelve Musketeers against twenty Raptors count as more, and lose in the open); guards walked to a third hall site 35
   tiles away during the Brood's attack (`_guard_new_hall`); the third hall itself was laid while the Brood was at the
   door. **Fix**: against the Brood the post goes down only with twice the force there (`hold_beat`), no guards walk out
   under the doctrine, no new hall while the enemy is at our buildings or clearly bigger on our side.
3. **A scouted rush handed the game to the shared defence, which cut the economy** (a02, a05, a07, a08: 9-14 labourers
   at 4:00-8:00). **Fix**: the plan defends itself (section 2, the last paragraph): the 3rd Musketeer against the
   extreme rush now comes at 2:38 (`tools/test_ai_wall_vs_rush.gd` all pass; 2:45 before), and a11 (the same game as
   a02) had 14/18/29 labourers at 4/6/8 against 9/10/9.
4. **The Timing attack went into a bigger army** (a03: 22 supply at 6:59 into a Brood economy with 3,150 of army; it
   died). **Fix**: a wave needs an edge over the enemy's mobile army it knows (1.5 times against the Brood), and an
   opening's attack held back 45 s is called off and the plan expands.
5. **The Horseman rush rode into a rooted Rootmaw on the Brood's ramp** (a04 `fight_0408`: the three riders hacking at
   the creature at the top of the ramp, no grubs near): FAILED at 4:13, 225 killed for 115 lost by 5:00. The rush itself is the shared rush
   code (`_hunt`, the riders go for the prey spot); left as it is, an open question (section 7). The Rush plan's first
   Horseman came late (2:36 against 0.27.2's 1:56: the labourers ate the gold the Horseman waited for). **Fix**:
   Horsemen before labourers in the Rush plan.
6. **Against the Brood's Timing attack the army is too small at 6:00** (a01, a09, a12: 420-715 of army when 20-30
   Raptors and Challengers came at 5:45-6:30, the Brood earning 1.5 times the Crown's gold a minute). The ramp post on
   HOLD behind the gate held the first waves (a11 `defence_still`: the Musketeers firing down at the Raptors on the ramp;
   the owner's own game held 33 Raptors and 12 Challengers with 11 Musketeers and a cannon, docs/playtests/2026-11-03/),
   but the economy behind it was 2-3 times smaller and the next waves broke in. **Fix** (round B): an army the size of the
   economy after the opening (a hall trains a labourer only while every Barracks is busy, until the army's supply is the
   plan's share of the labourers) and the second Barracks with the second hall (one Barracks makes 4 Musketeers a minute
   at most). Against the Clockwork the Crown was ahead or even (a06 killed 5,445 for 3,135).

## 4. Coaching, round B (the fixes of round A)

Eight of round A's games again (the same plans, opponents, maps and seeds), on the round B code (b01-b02 before the
Powder Wagon fix, b03-b08 with it; the Rush plan's Horsemen-before-the-second-Farm order came after b04).

| game | same as | plan | against | map | result | labourers 4/6/8 | gold a minute 6/8 | army 6/8 | enemy army 8 | 2nd hall | 1st attack (supply) | killed / lost |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| b01 | a01, a12 | Economy | Brood Timing | Red Coast | L 10:28 | 18/28/21 | 1520/760 | 580/40 | 2550 | 3:13 | - | 2325 / 6025 |
| b02 | a02, a11 | Balanced | Brood Rush | Greenhold | alive 13:00 | 14/16/24 | 760/760 | 520/935 | 1500 | 4:57 | 8:39 (19) | 4050 / 1650 |
| b03 | a03 | Timing | Brood Economy | Kestrel Rise | alive 13:00 | 15/17/19 | 380/1140 | 935/1920 | 4400 | 7:50 | 7:25 (25) | 4230 / 2445 |
| b04 | a04 | Rush | Brood Balanced | Greenhold | alive 13:00 | 14/20/34 | 1140/1140 | 500/900 | 3590 | 4:02 | 3:21 (9) | 3100 / 3030 |
| b05 | a05 | Economy | Clockwork Balanced | Kestrel Rise | alive 13:00 | 15/20/29 | 380/1140 | 480/880 | 845 | 3:09 | 9:31 (19) | 4620 / 2985 |
| b06 | a06 | Balanced | Clockwork Timing | Red Coast | alive 13:00 | 14/21/36 | 1140/1520 | 655/940 | 2590 | 5:03 | 8:20 (20) | 5530 / 1625 |
| b07 | a08 | Economy | Brood Extreme rush | Ashford Crossing | alive 13:00 | 14/20/27 | 760/1140 | 480/1075 | 1550 | 4:13 | 8:40 (25) | 2975 / 2190 |
| b08 | a09 | Balanced | Brood Timing | Highmoor | alive 13:00 | 14/19/24 | 1140/1140 | 695/930 | 2400 | 5:05 | - | 9400 / 2080 |

Against round A: the extreme rush (b07 against a08) and the Brood's Rush (b02 against a02) no longer cut the economy
(14/20/27 labourers against 9/12/14); the Brood's Timing on Highmoor went from a loss at 11:25 to 9,400 killed for 2,080
(b08: the post behind the gate held every wave, picture 02 and 11); the Timing plan against the Brood's economy now
waits (b03 went at 7:25 with 25 supply and traded 4,230 for 2,445, a03 died at the enemy's base); the Rush traded even
(b04 3,100 / 3,030, a04 5,340 / 7,355); against the Clockwork both games stayed well ahead (b05, b06).

What round B still showed:

1. **The Brood's Timing attack on Red Coast still wins** (b01, every Economy game on the owner's seed, new and old
   computer alike): the Brood earns about 1.5 times the Crown's gold a minute from 5:00 and sends 15-30 Raptors and
   Challengers at 5:45-6:30, then 50-90 at 8:00-9:00. b01's line held at the gate until its Powder Wagon blew up among
   it (picture 09; fixed for b03 on).
2. **Holding costs the expansion's income** (b08, 10:44, picture 02): the Brood raids the second hall below the ramp
   again and again, its labourers run up behind the line (the doctrine), and with the main's soil at 11% the Crown earned
   380-760 gold a minute with 36 labourers. The third hall waits while the enemy is at the door (round A's fix 2).
3. **The army grows with the economy, at some cost in labourers**: in the matched games the labourers at 8:00 are about
   the same (b02 24 and b07 27 against 9 and 14, b01 21 and b08 24 against 30 and 31, the rest within 2), and the armies
   at 8:00 are bigger where the rush defence or the wave's edge kept them alive (b02 935, b03 1,920, b07 1,075 against
   475, 595, 540).

## 5. Before and after (headless, Hard v Hard, 12:00, the Crown in slot 0)

`tools/crown_ai_measure.py` runs `tools/study/study_game.gd` games and makes the columns. "0.27.2" is the same game with
`-- crownnew:off` (and the plan's opening fixed, `open0:mill` / `open0:breeder`, since 0.27.2 rolled the Breeder opening
3 games in 10). "New" is the final code (the last tweaks, the Rush's order and settings and the Brood army share, were
measured on the games they are for: B1, B6, B7, C4). One game a row: results are noisy (the same code gave B4 a loss at
10:40 and a game alive at 12:00), the timings and the economy columns are the solid part. "lead" = both alive at 12:00,
that side ahead by the study's power count.

| game | Crown plan v opponent (Hard), map, seed | result 0.27.2 -> new | labourers 4/6/8 | gold earned 6/8 | army 6/8 | 2nd hall | 1st attack |
|---|---|---|---|---|---|---|---|
| B1 | Economy v Brood Timing, Red Coast 4291306512 (the owner's) | **L 9:40 -> alive, Brood lead** | 17/27/28 -> 18/30/38 | 3420/6080 -> 4180/6460 | 715/995 -> 600/1155 | 4:31 -> 3:10 | - -> 8:40 |
| B2 | Economy v Brood Economy, Kestrel Rise 2039763518 | Brood lead -> **Crown lead** | 17/29/46 -> 18/28/40 | 3800/7600 -> 3800/7600 | 655/1285 -> 480/1365 | 4:29 -> 3:18 | 10:00 -> 8:55 |
| B3 | Balanced v Brood Rush, Greenhold 3 | even -> **Crown lead** | 14/19/23 -> 14/18/27 | 3040/5320 -> 3040/4560 | 180/140 -> 635/875 | 4:43 -> 4:57 | - -> 9:01 |
| B4 | Balanced v Brood Timing, Mirewood 3 | **L 11:18 -> alive, Brood lead** | 17/29/40 -> 14/19/24 | 3420/7220 -> 3040/4940 | 600/1230 -> 635/780 | 3:54 -> 5:05 | - |
| B5 | Timing v Brood Balanced, Highmoor 1 | **gg 11:13 -> alive, Brood lead** | 17/26/31 -> 15/17/18 | 3420/6840 -> 3040/4560 | 360/115 -> 935/1605 | 3:54 -> 8:12 | - |
| B6 | Rush v Brood Economy, Red Coast 11 | even -> Brood lead | 11/18/36 -> 13/17/27 | 3420/5700 -> 3040/4940 | 620/1255 -> 370/725 | 4:49 -> 4:49 | 3:24 -> 2:56 |
| B7 | Economy v Brood Timing, Red Coast 7 | **gg 11:16 -> alive, Brood lead** | 17/29/41 -> 17/30/24 | 3420/6840 -> 3420/6080 | 660/690 -> 540/980 | 3:54 -> 3:25 | - |
| B8 | Balanced v Brood Economy, Greenhold 11 | **gg 11:37 -> alive, Brood lead** | 17/26/46 -> 14/20/30 | 3420/7220 -> 3040/5700 | 595/1090 -> 695/935 | 3:53 -> 5:05 | - -> 7:31 |
| C1 | Balanced v Clockwork Balanced, Kestrel Rise 5 | Clockwork lead -> Clockwork lead | 9/11/20 -> 13/19/28 | 2280/3800 -> 3040/5320 | 515/900 -> 515/1025 | 3:55 -> 4:13 | - |
| C2 | Economy v Clockwork Timing, Greenhold 3 | Crown lead -> Crown lead | 16/25/35 -> 16/27/40 | 3800/6840 -> 3420/6840 | 695/870 -> 480/1240 | 4:29 -> 3:08 | 8:26 -> 7:49 |
| C3 | Timing v Clockwork Rush, Red Coast 7 | Crown lead -> Crown lead (round A's code: **win 10:33**) | 16/19/30 -> 14/17/18 | 3420/5700 -> 2660/4560 | 455/1200 -> 870/1900 | 4:40 -> 8:06 | 8:51 -> 7:45 |
| C4 | Rush v Clockwork Economy, Highmoor 5 | Crown lead -> Crown lead | 13/17/32 -> 12/18/26 | 3040/5700 -> 2660/4940 | 500/1135 -> 385/685 | 4:51 -> 4:38 | 3:24 -> 3:13 |
| C5 | Economy v Clockwork Rush, Mirewood 3 | Crown lead -> Crown lead | 16/22/39 -> 16/26/38 | 3420/6460 -> 3420/6840 | 575/1200 -> 420/1210 | 4:43 -> 3:09 | 8:01 -> 10:14 |

The first Horseman: 1:52-2:04 on the Rush plan (0.27.2 1:56), 4:35-6:34 on the others (the Breeder is a milestone;
0.27.2 4:20-7:38). The first Musketeer: 2:02-2:16 on Balanced and Timing (0.27.2 2:11-2:59), 2:48-3:33 on Economy (2:10-3:00).

Read:
- **Against the Brood the Crown no longer dies by 12:00**: 0.27.2 lost or gave up in 5 of these 8 games (9:40 to 11:37),
  the new computer in none; it leads in 2 (B2, B3, where 0.27.2 was behind or even). On the owner's Red Coast seed (B1) it
  lives to 12:00 (0.27.2 fell at 9:40).
- **The cost is income on the plans that hold**: on Balanced and Timing the army the size of the economy and the
  later second hall leave fewer labourers at 8:00 in four games of six (B4, B5, B8, C3: 18-30 against 30-46) and less gold
  earned by 8:00 in five (4,560-5,700 against 5,320-7,220; C1 the other way). On Economy the second hall comes 30-95 s
  sooner; the labourers and gold at 8:00 are mixed (more on B1, C5, fewer on B2, B7).
- **Against the Clockwork nothing is lost**: the same results (the Crown ahead in 4 of 5), more labourers and gold on C1,
  bigger armies at 8:00 on C2, C3.
- **The Rush plan** is quicker (3 Horsemen out at 2:56-3:13 against 3:24) but no better in results: B6 went from even
  to a Brood lead, C4 kept the same Crown lead (round A's a04: the riders stopped by a rooted Rootmaw).

## 6. Tests

- `tools/test_crown_build_order.gd` (new): the plans are well formed; on Economy against a still Brood the steps are done
  in order and none before its trigger, a triggered step is paid within 60 s (one harvest), the hall keeps training
  labourers, the second hall by 4:30 (3:26), the opening ends and the milestones take over, 24+ labourers and a Mill crew
  of 4+ by 6:00; the Rush sends 3 Horsemen by 5:00 (2:58) and ends its opening; with `on` false the shared computer
  plays. All pass.
- `tools/test_ai_wall_vs_rush.gd`: **all pass** on the default map (the third Musketeer at 158 s, the known limit of 165 s
  against 160 s is gone) and on Ashfall (152 s, 0.27.2 167-168 s).
- `tools/test_crown_farms.gd`, `tools/test_crown_hold.gd`, `tools/test_raid_kite.gd`: all pass.
- Boot: `godot --headless --quit-after 300` prints no script or parse error. (Every headless run here ends with an engine
  abort at quit after the results, on 0.27.2 too: not a test failure.)

## 7. Open questions (for the owner)

1. **The Brood's economy and its Timing attack.** In every Crown v Brood game here the Brood earns about 1.5 times the
   Crown's gold a minute from 5:00 (2,000-2,400 against 1,140-1,520) and fields 2-4 times the army by 8:00. The new
   computer holds the high ground (it lives to 12:00 in all 8 games), but it does not win them. Is that the matchup the
   owner wants (the Crown a defender that must out-play the Brood), or a balance question (section 8)?
2. **Holding costs the expansion.** The doctrine keeps the army on the main and lets the expansion's labourers run up;
   against a Brood that raids the second hall again and again (b08) the Crown's income falls to 380-760 a minute with 36
   labourers. Should the post move down to the expansion once it is walled (the slow wall), or the third hall go to a
   safer spot behind the main?
3. **The Horseman rush rides into rooted creatures** (a04): the shared rush (`_hunt`) picks the "prey spot" and the
   riders fight whatever is in the way; a rooted Rootmaw at the top of the Brood's ramp stopped all three. Should the
   rush skip a Brood whose ramp is held by a rooted creature, or go round it to the grubs?
4. **The labourers against the army.** The plan's army share (0.4-0.7 supply a labourer, at least 0.55 against the Brood)
   is what keeps the Crown alive against the Brood and what costs it 10-15 labourers at 8:00 on Balanced and Timing.
   The owner's own game had 34 labourers and 570 of army at 8:00. Which he prefers decides the numbers.
5. **Deleting the old Crown paths** in `scripts/ai.gd` (section 1): kept for `crownnew:off`, Easy and the tests that make a
   shared `AI.new()` for the Crown. Delete once compared?
6. **The Marching Band**: no plan uses it. When the owner decides (drop it, one a player, or a buildable support unit), a
   plan can add it as a step or a milestone (section 1).
7. **The Clockwork job** on another branch makes `scripts/ai_clockwork.gd` the same way; the hooks here
   (`_base_trains_labs`, `_plan_tech`, `bo_owns`) are generic and can serve it, and the four lines that create the
   computers (`main.gd`, `sandbox.gd`, `net_session.gd`, `perf_bench.gd`) will need both names at merge.

## 8. Proposals (balance: not changed here, the owner decides; design_principles.md 1 and 2)

1. **The Powder Mill and the Barracks set the Crown's army rate**, not its gold: one Barracks trains 4 Musketeers a minute,
   one hand on a Mill grinds 20 powder (2 Musketeers) a minute. With 30+ labourers the Crown banks gold it cannot turn into
   soldiers fast enough before the Brood's 5:45 attack. Two ideas: a cheaper second Barracks (150 -> 100), or the
   Musketeer's training time 15 s -> 12 s. Either brings the Crown's defence at 6:00 closer to the Brood's attack without
   touching its economy.
2. **The Brood's Timing attack is the yardstick that decides most of these games** (it won or led in every Brood game
   here, against both computers). If the owner's own games show the same (his phone game held one big wave with 11
   Musketeers and a cannon, then the log ends at 9:00), a small brake on the Brood's economy from 5:00 to 8:00 (the
   Rootmaw's yield, or the grubs' cap on its Timing plan) would keep the anti-snowball rule (section 2) honest.
3. **The Powder Wagon's blast** hurts friends as much as foes (b01: the line on HOLD was gone a minute after the wagon blew
   up among it). A smaller blast for friends, or the wagon's kegs not going off when it is destroyed by melee, would make
   the wagon a support unit rather than a bomb next to one's own army (design_principles 1: a punishment should match the
   mistake). The computer now keeps it by the hall at home.

## 9. Play it again

    # a coached, filmed game (side 0 the Crown computer on its plan)
    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_crown_1.gd -- \
        coach:balanced b:brood sb:timing map:highmoor seed:1 out:/abs/dir end:780 [set:labs=18]
    python3 -I tools/play_brood_new_gif.py /abs/dir            # the clips as GIFs
    python3 -I tools/play_crown_table.py /abs/round_dir         # a round's table
    # headless, new against 0.27.2
    python3 -I tools/crown_ai_measure.py /abs/out run B1_new "pa:economy b:brood pb:timing map:red_coast seed:4291306512"
    python3 -I tools/crown_ai_measure.py /abs/out run B1_old "pa:economy b:brood pb:timing map:red_coast seed:4291306512 open0:mill crownnew:off"
    python3 -I tools/crown_ai_measure.py /abs/out table
