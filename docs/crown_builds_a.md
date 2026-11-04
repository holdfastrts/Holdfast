# Crown builds A: Dragoon raids (crown-builds-a, 0.29.1)

The owner (2026-11-03, "do it all"; "Dragoon raids are one thing, balloon harass is another"): a new Crown computer plan
in the framework of `scripts/ai_crown.gd` (docs/ai_crown_rebuild.md), coached and filmed. **Dragoon raids**: Musketeers on
horseback (a Powder Mill and a Horse Breeder) as a mobile mid-game build whose identity is raiding: they hit workers
(Brood grubs at their Rootmaws, Clockwork Winders, Labourers), dismount to shoot where it pays, mount and ride off before
the army arrives, several groups at once, while the main army holds the high ground; they avoid the Tyrant Sire and Raptor
packs and pick undefended expansions. The Balloon harass is another job (crown-builds-c); the siege push another
(crown-builds-b).

Pictures: `docs/shots/crown_builds_a/` (captions in its `captions.md`).

## 1. How it is built

| part | what | where |
|---|---|---|
| the plan | `AICrown.PLANS["dragoon"]`: an opening, milestones, `"raid"` (when the riders come), `"s"` (wave 30, step 10) | `scripts/ai_crown.gd` |
| the strategy | `AI.STRATEGIES["dragoon"]` ("Dragoon raids", `crown_only`: `AI.strategies_for` gives it to the Crown only; a RANDOM PLAN may land on it) | `scripts/ai.gd` (2 small hunks) |
| the riders | `AICrown._train_dragoons`: after the second hall, Dragoons from every Barracks before the line's Musketeers, up to `DragoonRaid.want` (4 once the line has 2 Musketeers, 4 more every 8 labourers over 14, 12 at most); a Dragoon's gold (100, his horse too) is kept from the Musketeers while the riders are short, unless the enemy is at home | `scripts/ai_crown.gd`, end of file |
| the raids | `DragoonRaid` (`scripts/ai_dragoon_raid.gd`): the groups, the sites, the danger rule, the strike; ticked from `AICrown._raid`, its rider micro every physics tick (`AICrown._tick_ai` -> `micro`); its riders are out of the army's think (`AICrown._on_errand`) | new file |
| the story | the AI STORY's sentences for the raids (`scripts/ai_story_lines.gd`), the plan's name and the sentences in pt/es (`tools/i18n/52_dragoon_raids.txt`) | |
| the coach | `tools/play_crown_builds_a.gd` (extends `tools/play_crown_1.gd`, which got one COACH line), `tools/play_crown_builds_a_table.py` | tools |
| the test | `tools/test_crown_dragoon_raid.gd` | tools |

Everything the raids add sits in its own file or at the end of `ai_crown.gd`, so crown-builds-b and -c (which add plans to
the same file) merge with one conflict at most: the end of `PLANS` and the end of the file. Nothing runs on another plan
(`dragoon_plan()` is false), and `crownnew:off` and Easy play as before.

### The build order (triggers, never the clock)

| step | trigger | (when, round C) |
|---|---|---|
| the ramp Cottage | 5 supply | 0:00 |
| the ramp Gate | 5 supply | 0:22 |
| the Barracks and the Powder Mill | 7 labourers | 0:42 |
| Musketeers from now on, 8 supply in the opening | - | 1st at 2:03-2:05 |
| the second Farm | 9 labourers | 1:48 |
| the Horse Breeder | 13 labourers | 3:30-4:00 |
| the second Town Hall | 15 labourers | 5:03-5:08 |
| (the opening ends: the milestones and the raids take over) | | |
| Dragoons, before the line's Musketeers | the second hall laid, 2 Musketeers | 1st at 5:18-5:23 |
| the first raid group (4 Dragoons) | 4 Dragoons free at home | 7:02-7:27 |
| one more group | every 8 labourers over 14 (3 groups at most) | 8:00-9:30 |

Mill crew: 3, 5 from 13 labourers, 6 from 17. Milestones (CHANGED AT THE MERGE, 0.29.9: the owner's rule "the Foundry
before the second Barracks, always" (2026-11-03); the job had the second Barracks at 18 and the Foundry at 24, and this
plan's second Barracks answers no scouted threat, so the owner's possible Dragoon exception does not apply; it now follows
Balanced: the Foundry at 18 labourers, then the second Barracks at 18; the coached numbers below were measured with the
old order): the Foundry at 18, the second Barracks at 18, a second
Horse Breeder at 26 with two halls (the horses), the Armoury at 28, the third Barracks at 32, the Church at 38 with two
halls, the second Foundry at 46 with three. The army is kept at 0.5 supply a labourer (0.55 against the Brood: the shared
rule); the line's waves go at 30 supply. The opening is Balanced's but for the Breeder (13 labourers, like Balanced) and a
Musketeer cap of 8: round A showed any rider before the second hall costs it (section 3).

### A group's life (scripts/ai_dragoon_raid.gd)

1. **gather**: four Dragoons free at home (full health, 70% of their shot) meet at the main's front; they set out when
   all are there (or 25 s) AND the way out is clear (no armed enemy seen within 900 px of the rally point). Against the
   Brood they also wait for its army to come out to our side (`ch.foe_near()` 250 or more: THE COUNTER-RAID) or 75 s.
2. **ride**: a plain ride, mounted, to the best site, round the side away from the enemy's main and the armies it saw (a
   waypoint beside the straight ride). Danger met within 1,100 px of our hall is the line's business: the group goes back
   to gather, nothing counted against the site.
3. **strike** (within 300 px of the site): every rider in reach shoots the same worker (three muskets kill a grub or a
   Winder in one volley); a Dragoon told to attack gets off (0.8 s), fires as a Musketeer and gets back on by himself to
   move. With nothing in sight the group waits on the workers' path (where workers were seen in the last 40 s, else
   toward the hall or Mother they haul to). A slow defender close is stepped away from (`AIHarass.kite_from`). On foot a
   rider who picked a structure by himself (a rooted turtle, a building) is put back on a worker every tick. 14 s with
   nothing to shoot, or 50 s at the site: on to the next.
4. **leave** (the danger rule, every think): a Sire or the Mother on her feet; fast melee in number (at least 3, and at
   least the group's size: a Raptor pack); a defender the group can't outrun worth more than it (`AIHarass.outmatched`);
   or slow ones worth 1.5 times the group (30 Clock Soldiers are "slow" each, a Dragoon on foot is slower). Every rider
   mounts (one whose horse wandered runs to it) and rides away from the danger toward home; the site is HOT for 90 s; the
   group goes on to another site, or home after two chases.
5. **home**: hurt (under half), short of shot (under 30%), cut to one, out 4 minutes, or chased twice: home to refill
   (the Barracks, the hall and the Mill refill a musket), and let go there. A rider under 30% goes home alone.

**Sites** are remembered only once SEEN (no cheating): the enemy's halls and economy buildings, the Brood's Rootmaws and
Mother; plus guesses (its natural, the base sites on its half) struck off for 150 s when found empty. Scored by the workers
seen there and on the way (the last 90 s), distance from the enemy's main (an expansion), minus an army seen near it in
the last minute, minus another group's site (spread out); its main (750 px) is never a site while its army is home.

## 2. Coached games

The tool: `tools/play_crown_builds_a.gd` (everything of `play_crown_1.gd`: minutes.txt, events.txt, the base and fight
pictures) plus `raid.txt` (the raid log and totals) and the pictures `strike_*` (a group strikes), `leave_*` (it rides off),
`raid_*` (on the ride), `clip_first_strike_*`. The minute line adds the enemy workers killed by the whole Crown and by the
raiders, the value the raiders killed and lost, the Dragoons, and where the enemy's workers are (at a site, at home, on the
way, seen). The opponent is the normal computer on Hard; every game 12:00 (720 s). "B" = the Crown's Balanced plan on the
same game (the comparison the owner asked for). I looked at the pictures of every game; what they showed is under each
round.

    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_crown_builds_a.gd -- \
        coach:dragoon b:brood sb:economy map:kestrel_rise seed:2039763518 out:/abs/c03 end:720
    python3 -I tools/play_crown_builds_a_table.py /abs/round_dir c01 c02 ...

Columns: labourers at 4/6/8 min; gold earned a minute at 6/8; army value at 6/8; enemy army at 8 (the Brood's rooted
creatures count); the second hall; the first raid group out; enemy workers killed by the whole Crown by 8:00 and by
12:00 (by the raiders in brackets); value the raiders killed / lost; strikes / chased off; value killed / lost by the whole
Crown at the end.

### Round A (the first draft; a04-a06 with the first fixes)

| game | plan | against | map, seed | result | labourers 4/6/8 | gold 6/8 | army 6/8 | enemy army 8 | 2nd hall | 1st group | workers killed 8:00 (raid) | at 12:00 (raid) | raid killed / lost | strikes / chased | killed / lost |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| a01 | Dragoon | Brood Economy | Red Coast 4291306512 | L 11:46 | 10/16/27 | 760/1140 | 750/1050 | 4625 | 6:21 | 5:34 | 4 (2) | 4 (2) | 100 / 480 | 6/8 | 1995 / 4705 |
| a01b | Balanced | " | " | alive | 14/20/31 | 1140/1900 | 695/1210 | 5725 | 5:05 | - | 2 | 3 | - | - | 4700 / 8515 |
| a02 | Dragoon | Brood Timing | Highmoor 1 | L 11:28 | 10/17/18 | 760/760 | 695/695 | 2575 | 5:43 | 6:33 | 4 (0) | 5 (0) | 175 / 240 | 0/11 | 2935 / 5480 |
| a02b | Balanced | " | " | L 11:40 | 14/19/27 | 1140/1140 | 675/1050 | 4240 | 5:05 | - | 1 | 1 | - | - | 2870 / 5860 |
| a03 | Dragoon | Brood Economy | Kestrel Rise 2039763518 | alive | 10/16/23 | 760/1140 | 710/1045 | 4650 | 9:24 | 5:04 | 3 (2) | 11 (2) | 375 / 180 | 3/2 | 2725 / 1370 |
| a03b | Balanced | " | " | alive | 14/19/31 | 760/1900 | 575/1200 | 5075 | 4:59 | - | 2 | 39 | - | - | 4425 / 585 |
| a04 | Dragoon | Clockwork Balanced | Kestrel Rise 5 | alive | 13/14/25 | 760/760 | 440/875 | 2310 | 4:13 | 8:00 | 2 (0) | 5 (1) | 60 / 480 | 7/9 | 1490 / 805 |
| a04b | Balanced | " | " | alive | 13/18/28 | 380/1140 | 515/1205 | 1700 | 4:14 | - | 7 | 12 | - | - | 1980 / 250 |
| a05 | Dragoon | Clockwork Economy | Greenhold 3 | alive | 14/21/28 | 1140/1900 | 580/1055 | 3010 | 5:04 | 7:14 | 0 (0) | 5 (1) | 60 / 420 | 4/2 | 2380 / 2285 |
| a05b | Balanced | " | " | alive | 14/21/37 | 1140/1520 | 655/1110 | 2135 | 5:04 | - | 3 | 24 | - | - | 4695 / 1800 |
| a06 | Dragoon | Clockwork Timing | Red Coast 7 | alive | 14/20/27 | 1140/1900 | 580/1035 | 2075 | 5:02 | 8:04 | 0 (0) | 6 (1) | 230 / 540 | 5/9 | 2220 / 1095 |
| a06b | Balanced | " | " | alive | 14/20/32 | 1140/1900 | 580/1090 | 2030 | 5:02 | - | 2 | 14 | - | - | 4385 / 1705 |

(a01-a03: the first draft, the Breeder at 9-10 labourers and the riders in the opening. a04-a06: the opening fixed, the
counter-raid gate; the fixes below 3-5 not yet in. Before the round, seven development games on the same seeds, t1-t7, found
the first bugs: a group fleeing "every second" from the same pack, the riders unable to "see" a Rootmaw on the high ground,
the Rush-plan-like Breeder starving the farms.)

What the films showed, and what was changed:

1. **Riders before the second hall cost the economy** (a01-a03: 10 labourers at 4:00 against 14, the second hall at 6:21,
   5:43 and 9:24 against Balanced's 4:59-5:05). **Fix**: Balanced's opening (the Breeder at 13 labourers) and the
   Dragoons only once the hall is laid (a04-a06: the same labourers and hall time as Balanced).
2. **Every Brood site had a Raptor pack within seconds** (a01 picture 08: the group at a new Rootmaw, the pack and a walking
   Rootmaw on it at once; a02: 11 chases, no strike). The Hard Brood keeps 10-30 Raptors round its Rootmaws from 6:00.
   **Fix**: THE COUNTER-RAID: against the Brood a group goes when its army is out on our side (or after 75 s at home).
3. **A group rode into the Clockwork's main past 30 Clock Soldiers and died** (a05 picture 07): each Clock Soldier is
   "slow" (68 against the Dragoon's 112), so the harass rule kites it rather than leaves; but a Dragoon on foot walks 62.
   **Fix**: slow defenders worth 1.5 times the group are danger too; the enemy's main is never a site while its army is
   home.
4. **Groups rode from pack to pack** (a01: eight chases in one sortie, riders lost one by one). **Fix**: two chases and
   the group goes home.
5. **Rootmaws with no grubs at them** (a01 picture 10: "GRUBS 31/12" over a Rootmaw and none in sight; the coach's new
   minute line showed most grubs on the way to the Mother, 600-1,300 px). **Fix**: the group waits where workers were seen
   in the last 40 s, else on the way to what they haul to; sites are scored by the workers seen near them.

### Round B (fixes 1-5)

| game | same as | result | labourers 4/6/8 | gold 6/8 | army 6/8 | enemy army 8 | 2nd hall | 1st group | workers killed 8:00 (raid) | at 12:00 (raid) | raid killed / lost | strikes / chased | killed / lost |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| b01 | a01 | L 11:19 | 14/19/28 | 1140/1140 | 655/875 | 5475 | 5:05 | 7:59 | 3 (0) | 3 (0) | 125 / 660 | 0/8 | 1725 / 6620 |
| b02 | a02 | L 11:12 | 14/19/30 | 1140/1520 | 655/915 | 4125 | 5:05 | 7:21 | 1 (0) | 1 (0) | 0 / 300 | 1/8 | 1900 / 6695 |
| b03 | a03 | alive | 14/18/23 | 1140/1140 | 540/1120 | 5350 | 5:00 | 7:38 | 0 (0) | 15 (10) | 500 / 0 | 4/3 | 1450 / 120 |
| b04 | a04 | alive | 13/14/19 | 380/380 | 520/975 | 1495 | 4:14 | 6:35 | 3 (1) | 8 (3) | 320 / 240 | 3/4 | 2995 / 1840 |
| b05 | a05 | alive | 14/21/30 | 1140/1520 | 655/1175 | 2380 | 5:04 | 7:33 | 0 (0) | 9 (1) | 130 / 60 | 4/12 | 1490 / 300 |
| b06 | a06 | alive | 14/19/31 | 1140/1900 | 540/935 | 1990 | 5:02 | 11:15 | 0 (0) | 14 (0) | 0 / 0 | 1/0 | 4675 / 2835 |

The economy is now Balanced's (14/19-21/28-31 labourers, the hall at 5:00-5:05 in every game). b03 had the first good raids
(10 grubs for no loss; picture 04: the riders on foot firing at the grubs by the Brood's main, the Tyrant Sire getting up,
and the group mounting and riding off). Still wrong:

6. **The counter-raid rode down our own ramp into the Brood's army at the door** (b01 picture 09, b02: "a pack of 6"
   one second after setting out: the Brood's army was "out on our side" because it was at our gate). **Fix**: a group
   sets out only with the way out clear (no armed enemy within 900 px of the rally point), and danger met near home
   sends it back to wait behind the line.
7. **A milestone's gold held the riders back** (b06: the first group at 11:15): the riders gave way to any reserved gold
   once the army had 8 supply, the line's Musketeers only at the shared minimum (6 + 1 a 20 s). **Fix**: the same minimum.

### Round C (fixes 6-7, the same seeds and two new maps)

| game | plan | against | map, seed | result | labourers 4/6/8 | gold 6/8 | army 6/8 | enemy army 8 | 2nd hall | 1st group | workers killed 8:00 (raid) | at 12:00 (raid) | raid killed / lost | strikes / chased | killed / lost |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| c01 | Dragoon | Brood Economy | Red Coast 4291306512 | L 10:13 | 14/19/31 | 1140/1140 | 655/995 | 5075 | 5:05 | 7:12 | 1 (0) | 5 (4) | 200 / 240 | 3/0 | 825 / 6595 |
| c02 | Dragoon | Brood Timing | Highmoor 1 | L 11:43 | 14/20/24 | 1140/1140 | 655/840 | 3975 | 5:05 | - | 1 (0) | 2 (0) | 0 / 0 | 0/0 | 1600 / 5740 |
| c03 | Dragoon | Brood Economy | Kestrel Rise 2039763518 | alive | 14/19/31 | 1140/1140 | 600/1120 | 5500 | 5:08 | 7:02 | 0 (0) | 37 (15) | 775 / 300 | 9/4 | 4075 / 1640 |
| c04 | Dragoon | Brood Economy | Ashford Crossing 4242 | L 11:19 | 13/18/28 | 760/760 | 640/1000 | 5500 | 5:08 | 7:03 | 1 (0) | 7 (6) | 300 / 480 | 5/1 | 2425 / 7250 |
| c04b | Balanced | " | " | alive | 14/19/31 | 1140/1140 | 635/1030 | 4825 | 5:05 | - | 3 | 3 | - | - | 4915 / 7945 |
| c05 | Dragoon | Clockwork Rush | Mirewood 3 | alive | 14/14/22 | 760/1140 | 540/995 | 1545 | 5:03 | 7:27 | 0 (0) | 5 (1) | 330 / 300 | 3/4 | 2390 / 1220 |
| c05b | Balanced | " | " | alive | 14/16/31 | 1140/1140 | 635/1115 | 1515 | 5:05 | - | 2 | 16 | - | - | 4940 / 1765 |

What round C showed:

- **On Kestrel Rise against the Brood's Economy the raids work** (c03, pictures 01-03 and the GIF): three groups, nine
  strikes, 15 grubs and 775 of value for 300 lost; the Crown killed 37 workers in all (Balanced's a03b 39) and traded
  4,075 for 1,640, with the economy of Balanced. The groups struck the new Rootmaws on the turtles' swamp and the grubs by
  the Brood's main while its army was out, and rode off from the Tyrant Sire every time (picture 02).
- **On the highland maps (Red Coast, Highmoor, Ashford Crossing) the Brood wins anyway, on both plans**: the Brood earns
  about 1.5 times the Crown's gold from 5:00 and its army is 4,000-5,500 at 8:00 against the Crown's 840-1,000 (the open
  question of docs/ai_crown_rebuild.md, 7.1). The raids there are short (c01: 4 grubs; c02: no group ever set out, its
  Dragoons fought at the gate first) and the Dragoons are 4-12 supply missing from the line when the Timing attack comes.
  The Balanced plan lived to 12:00 on two of these three seeds (a01b, c04b), the Dragoon plan on none.
- **Against the Clockwork the raids pay a little** (b04 320 / 240, b05 130 / 60, c05 330 / 300), but Balanced's waves do
  more: Balanced killed 12-24 workers by 12:00 (a04b, a05b, a06b, c05b) and traded 1,980-4,940 for 250-1,800; the Dragoon
  plan 5-14 workers and 1,490-4,675 for 300-2,835 (b04 fought more on Kestrel Rise: 2,995 / 1,840 against a04b's 1,980 /
  250). Winders work inside the Clocktower's gear ring, mostly in the main; the expansions are few before 9:00 (picture 06:
  a group at a new Clocktower's press with a Clock Soldier guard coming).

After round C one more fix from the test: a rider on foot whose horse got away (another rider took it, or it wandered)
no longer runs after it while the group leaves; he goes on foot (a test run had one chase his horse 900 px into the
Sire's reach).

## 3. Numbers against the Balanced plan

Same games (seed, map, opponent):

| | Dragoon (best code: b / c) | Balanced |
|---|---|---|
| labourers at 4/6/8 | 13-14 / 14-21 / 19-31 | 13-14 / 18-21 / 27-37 |
| second hall | 4:14-5:08 | 4:14-5:05 |
| first Musketeer / first Dragoon | 2:03-2:05 / 5:18-5:23 | 2:03-2:05 / - |
| first raid group out | 6:35-7:38 (b06 11:15 before fix 7) | - |
| enemy workers killed by 12:00 | 1-37 (raids 0-15) | 1-39 |
| results against the Brood (round C, 4 games; Balanced on the same seeds) | alive 1, lost 3 | alive 3, lost 1 (a01b, a02b, a03b, c04b) |
| results against the Clockwork (rounds B-C, 4 games) | alive 4 | alive 4 |
| value killed / lost against the Clockwork | 1,490-4,675 / 300-2,835 | 1,980-4,940 / 250-1,800 |

Read: the plan is cheap now (its economy is Balanced's to the labourer), it raids from about 7:00 with one to three groups,
and the groups live (two chases and home; the Sire and the packs are left); where the enemy's workers stand on open
ground at expansions (Kestrel Rise) it kills as many as Balanced's waves for less. Against a Hard Brood on the highland
maps it is worse than Balanced: the Dragoons are supply the line misses when the Timing attack comes.

## 4. Tests

- `tools/test_crown_dragoon_raid.gd` (new; all pass): [table] the plan is there, well formed, Crown only; [strike] four
  Dragoons sent to grubs at a rooted Rootmaw behind a rooted turtle (the Brood's computer off): the grubs lose 80+ hit points
  in 45 s, the riders get off to shoot, and hardly ever set about the turtle or the Rootmaw (0 frames of 576); [leave] a
  Tyrant Sire comes: the group rides off in 1 s, the riders are back in the saddle in 2 s (all but one at most: a rider
  whose horse wandered off runs on foot), three or four alive after 20 s;
  [plan] a Hard Crown on the plan against a still Brood: the Breeder (3:59) and the second hall (5:05) by 6:00, 4+ Dragoons
  and a group out by 11:30 (with the Brood's army never out the group waits its 75 s at home first); [others] the Balanced plan makes no raids.
- `tools/test_crown_build_order.gd`: still passes (the four plans unchanged).
- Boot: `godot --headless --quit-after 300` prints nothing.

## 5. Open questions (for the owner)

1. **Should the computer pick Dragoon raids against the Brood at all?** On the highland maps it lost every game where
   Balanced lived in two of three; on Kestrel Rise it was as good. A plan picked by matchup (the queued job: "the computer
   picks its build by matchup") could take it against the Clockwork and on open maps only.
2. **The counter-raid** waits for the Brood's army to come out. Against the Brood's Timing the army comes out to our gate,
   which blocks the only way out of the main (c02: no group ever left). Should a group leave earlier (before the attack, at
   a fixed army size) and take the risk, or ride out of the main by another way (a second ramp, where a map has one)?
3. **One group or three?** The plan sends up to three groups of four (12 Dragoons, 1,200 gold with the horses). Two groups
   at once struck two sites in c03 (picture 03), but most games had one group out at a time; the rest waited at home.
4. **The line misses the Dragoons** when the attack comes. Should the raiders come home to the ramp post when the enemy's
   army is at the gate (they are Musketeers on foot there)? Now they stay out (the counter-raid's point).
5. **The tooltip** of the strategy dropdown (`scripts/main.gd`, `scripts/ui/multiplayer_menu.gd`) lists the plans that are
   faction-only; Dragoon raids is Crown only. Not changed here (the other Crown jobs change it too): the main session can
   add "Dragoon raids is Crown only" at merge (an i18n line with it).

## 6. Proposals (balance: not changed here, the owner decides; design_principles.md 1 and 2)

1. **The Dragoon's dismount and remount** (0.8 s each) and its reload on foot (1.3 times a Musketeer's) make a strike cost
   about 5 s for one volley; a Raptor pack (96, 114 with its research) closes 190 px in 2 s. A faster quick dismount for the
   Dragoon (0.8 -> 0.5 s) would make the hit-and-run the plan's identity, without making the Dragoon a better soldier in a
   line (design_principles 1: niche units shine in a defined context).
2. **The Dragoon's sight** (8, the Musketeer's) is the edge of its musket's reach plus a little: on the swamp a group
   arriving at a Rootmaw sees the grubs only when they are 250 px off. Sight 9 for the Dragoon (a rider looks farther)
   would let a group pick its prey before it is in the Raptors' reach.
3. **The Brood's grubs and the Crown's labourers flee riders** (`_nb_grubs_vs_riders`, docs/raid_micro.md D) only from
   armed riders; a mounted Dragoon is unarmed in the saddle, so the grubs keep working until he gets off. That is fair
   (the dismount is the telegraph), noted only so it is a choice.

## 7. Play it again

    # a coached, filmed game (side 0 the Crown computer on its plan)
    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_crown_builds_a.gd -- \
        coach:dragoon b:brood sb:economy map:kestrel_rise seed:2039763518 out:/abs/dir end:720
    python3 -I tools/play_crown_builds_a_table.py /abs/round_dir    # the table
    godot --headless --fixed-fps 30 --script res://tools/test_crown_dragoon_raid.gd
