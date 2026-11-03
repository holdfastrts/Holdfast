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
| Musketeers from now on, 6 supply in the opening | - | 1st at 2:40-2:50 |
| the second Town Hall (safest rated site, three builders) | 15 labourers | 3:10 |

Mill crew in the opening: 2 hands, 4 from 14 labourers, 6 from 18 (fewer while powder piles up). Then the milestones:
a second Barracks at 20 labourers with two halls, the Horse Breeder (the rider scout) at 22, the Foundry (the ramp cannon)
at 26 with two halls, the Armoury at 30, a third Barracks at 34, the Church at 40, a second Foundry at 48 with three
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
| the second Town Hall | 15 labourers | 4:00-5:00 |

Mill crew: 3, 5 from 13 labourers, 6 from 16. Milestones: the second Barracks at 18 labourers, the Foundry at 22, the
Armoury at 26, the third Barracks at 30, the Church at 36 with two halls, a second Foundry at 44 with three. Army 0.55
supply a labourer; the first wave at 18 supply.

### Timing attack (Powder Mill opening): one hall, two Barracks, one hit

| step | trigger | (when) |
|---|---|---|
| the ramp Cottage, the Gate | 5 supply | 0:22, 0:37 |
| the Barracks and the Powder Mill | 7 labourers | 0:43 |
| the second Farm | 9 labourers | 1:48 |
| Musketeers from now on, no cap | - | 2:04 |
| the second Barracks | 13 labourers | 3:45 |
| the Horse Breeder | 15 labourers | 4:30 |
| the Foundry (a cannon with the wave) | 17 labourers | 5:45 |
| the first attack: 22 supply | 22 army supply | 6:00-7:00 |

The labourers stop at 19 in the opening. The wave goes only with an edge over the enemy army it knows (1.5 times against
the Brood); held back 45 s, the timing is called off and the plan expands. Milestones: Armoury at 20 labourers, third
Barracks at 28, Church at 30 with two halls, second Foundry at 40 with three. Army 0.7 supply a labourer.

### Rush (Horse Breeder opening): three Horsemen at the enemy's workers

| step | trigger | (when) |
|---|---|---|
| the ramp Cottage | 5 supply | 0:22 |
| the Barracks | 7 labourers | 0:36 |
| the Horse Breeder | 8 labourers | 0:49 |
| the second Farm | 9 labourers | 1:42 |
| Horsemen from now on, before labourers | - | 1st at 2:00-2:40 |
| the ramp Gate | 10 labourers | 2:15 |
| the first attack: 9 supply (3 Horsemen) | 9 army supply | 3:20-3:56 |

The labourers stop at 12 until the rush is out. Mill crew 2 (the Mill comes as the first milestone). Milestones: the
Powder Mill, second Barracks at 16 labourers, Foundry at 22, Armoury at 24, third Barracks at 30, Church at 34 with two
halls. The rush is judged by the shared rush rules (FAILED: home and build up; SUCCEEDED: mop up).

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
   extreme rush now comes at 2:37 (`tools/test_ai_wall_vs_rush.gd` all pass; 2:45 before), and a11 (the same game as
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

SECTIONS_TO_FILL
