# The Brood computer retuned to today's economy (0.27.3, branch brood-ai-tune)

The owner (2026-11-03): the Brood computer's six plans (Extreme rush, Rush, Timing attack, Balanced, Economy, Air rush)
were last tuned on 2026-10-30 at 0.22.5, before the economy changes: 0.24.0 (exhausted resources pay nothing),
0.24.13 and 0.25.5 (the Rootmaw circle), 0.24.28 (far Rootmaws pay up to x2.5 and drink faster) and later tweaks. Its
milestones were clock times measured on that old economy. The job: measure each plan on the current game, retune its
numbers (a trigger on what exists rather than a fragile clock time, as a StarCraft build order goes by supply), then
coach it in filmed games like round 3 (docs/brood_new_play_3.md) and fix what the films show.

Code: scripts/ai_brood_new.gd only. No unit, building or economy number was changed (docs/design_principles.md: the
balance findings are proposals at the end). Pictures with captions: docs/shots/brood_ai_tune/.

## 1. What today's economy does to the old plans (measured, before any change)

Each plan against a peaceful Hard Crown (it defends but never attacks) on Greenhold seed 3, and against a Hard Crown
and a Hard Clockwork that play normally (tools/measure_brood_ai.gd, now with milestones, Rootmaw ground, egg-bound and
banked time). The 0.22.5 table (docs/ai_build_timelines.md) is the comparison.

**The economy is about twice what the plans were written for.** The eco plans (Timing, Balanced, Economy, Air) earned
4,600 to 6,000 food by 6:00 (0.22.5: 2,000 to 2,600) and 13,600 to 16,800 by 10:00 (0.22.5: about 6,300 to 7,700). The
cause is the distance pay of brood-far (0.24.22, merged as 0.24.28: FOOD_BONUS 0.3 to 1.5, a far Rootmaw's load is worth x2.5 and it drinks x2.5 faster).

What the old numbers did on it:

| Plan | What went wrong |
| --- | --- |
| Timing, Balanced, Economy | **Egg-bound from about 4:30.** Her clutch ran dry (0 eggs) at 4:00 to 6:00 and stayed dry; food piled up: Balanced banked 9,000 food at 12:00, Timing 14,000 at 15:00 (bank over 600 for 440 to 625 s of the game). |
| the same | **No Venom Sire and no stage 3 in 15 minutes** (Balanced, Timing; Economy got stage 3 only on the peaceful map). A bank over 900 made `_nb_spoils_keep` return 0 ("never sit on food for spoils"), so the Venom Sire's 25 spoils and her stage 3's 75 were never kept and no Raptor was offered up for them. Spoils stayed at 0 to 5 all game. Each missing Sire is 20% of laying lost; stage 3 is 30% more. |
| Timing, Air | **A wave at the supply cap walked between two empty points for four minutes** (every 4 s, "goes on to the next target") while a Crown with no army kept one building it had not seen. Draws that were won games. |
| Rush, Extreme rush | **The economy stopped at 2 Rootmaws and 14 grubs until 8:30 to 10:00.** Every 50 food went into Raptors, and a Rootmaw was only chosen with 100 food in hand, so it never was. A failed rush kept the rush's own expansion list (one turtle on new ground at 10:00). Food by 10:00: 3,900 to 4,700 (the eco plans: 13,000+). |
| Extreme rush | A first wave that paid for itself kept the Extreme rush plan, whose grub curve is 0 a minute: 6 grubs until 8:00 (round A g10). |

What still worked: the natural turtle (0:33 in every eco game), the third Rootmaw at the natural's far edge (2:04 to
2:23), grubs nonstop (30 by 3:35 to 4:11), the scout and the watching grub, the alarm, the swarm defence. **The
Rootmaws' ground keeps up**: the total ground under the rooted Rootmaws stayed between 5,000 and 11,000 all game, one
or two Rootmaws were spent from 11:00 on and moved (the code uproots a spent one and finds it fresh ground); the
expansions came on time (3 far turtles by 5:19 to 8:01).

## 2. The new numbers and why

**Eggs are the clock now.** On today's economy what holds the Brood back from about 4:30 on is her laying, not food.
So what lays faster comes by that state, the plan's clock only as the latest time (`_nb_egg_bound`: her clutch run down
to 2 eggs or fewer in the last 45 s, after 1:30):

| | 0.22.5 (clock) | Now |
| --- | --- | --- |
| Her next stage (eco plans) | the plan's time (Balanced 4:00 / 8:00), then eggs-low or 4 minutes late | **at once when egg-bound** (and the Tyrant Sire is there), the plan's time as the latest |
| The Venom and Storm Sires (+20% laying each) | the plan's time (Balanced 6:00 / 9:00) | **at once when egg-bound** (Storm: at her stage 2), riders seen still call the Venom Sire at once |
| Turtles on new ground (+15% laying each, up to 3) | the plan's times | **the next one at once when egg-bound** (eco plans) |
| Spoils for the Venom Sire and stage 3 | dropped with a bank over 900 | **always kept; Raptors are offered up for them** (an offered pair gives its egg back) |
| RICH (egg-bound with 600 food or more) | nothing | spoils wanted for maturing (80), and twice the maturing a think: food no egg can take |

The rushes:
- the Extreme rush's far turtles 4:00 and 7:00 (were 10:00), the Rush's 4:30, 7:00 and 10:00 (were 7:00 and 11:00);
  in practice a rush turns Balanced when its first wave comes home and expands from then on (below);
- a Rootmaw needs no "100 food in hand" any more (the food is kept for it like any structure);
- **a rush is an opening**: once its first wave is home it plays Balanced (a failed one as before; a successful one too,
  after two minutes of building), expanding at once (turtles on new ground now, +1:30, +3:00);
- **a rush is called off** before it leaves when its scout saw an army twice its own (and 400 or more): the Raptors stay
  home as its defence and the economy starts (round A g08: 10 Raptors went into 560 of Clockwork and the game was lost).
  It did not fire in the later games: by 3:00 the scouts had not seen twice the wave; the fixes after the wave did the
  work.

The wave's end: with nothing left that it has seen, it goes for wall pieces it has seen (walls keep a side in the game),
else it splits into packs of 8 that sweep the nearest places it has not looked at for 150 s (round the enemy's start,
then a grid every 10 tiles), each pack its own; once anything is seen the wave gathers on it.

Why these and not new clock times: on the 0.22.5 economy a 4:00 stage was early; on today's it is late (egg-bound at
4:30) and on the next economy change it will be wrong again. A state ("her eggs ran out", "the scout saw twice my
army", "nothing left I know of") stays right when the numbers move.

## 3. The coaching (round 3's method)

Filmed games, the Brood computer on its own plan (`coach:ai sb2:<plan>`) against the Hard Crown or Clockwork, 15 minutes:

    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_brood_3.gd -- \
        coach:ai sb2:timing b:crown map:greenhold seed:11 out:/some/folder end:900

I looked at the pictures of every game (the Mother every 3 minutes, every fight, wave and alarm, the Sires as they
come) and read its decisions (the match log) and its minutes (minutes.txt). Round A ran with the retuned computer;
what it showed was fixed for round B; what round B showed was fixed for round C (the rush games again); what round C
showed was fixed for round D.

Results: W won, D draw (both alive at 15:00), L lost. "Trade" is enemy value killed / Brood value lost. "Earned" is
food against the enemy's gold at the end.

| Game | Plan | Against | Map, seed | Round A | Round B | Round C / D |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | Balanced | Crown | Highmoor 5 | D (8,955 / 3,845; 27,815 / 9,500) | **W 14:37** (11,985 / 8,140) | |
| 02 | Balanced | Clockwork | Dune Sea 7 | W 10:47 (6,805 / 2,450) | W 11:58 (5,660 / 3,775) | |
| 03 | Economy | Crown | Dune Sea 7 | W 12:55 (7,790 / 5,025) | W 11:46 (6,515 / 3,050) | |
| 04 | Economy | Clockwork | Twin Fords 9 | W 10:23 (5,785 / 1,875) | D (9,715 / 10,745; 21,142 / 17,930) | C14: W 14:52 (11,840 / 8,965) |
| 05 | Timing | Crown | Greenhold 11 | D (4,675 / **10,685**; 18,960 / 21,280) | D (**14,235** / 10,195; 26,728 / 14,440) | |
| 06 | Timing | Clockwork | Highmoor 5 | D (7,935 / 9,820) | **W 13:02** (11,420 / 6,100) | |
| 07 | Rush | Crown | Greenhold 3 | D (4,290 / 3,760; 13,846 / 21,280) | L 12:23 (1,900 / 7,500) | C: D (9,285 / 9,195; 19,970 / 16,340); D: L 12:29 (1,350 / 6,925) |
| 08 | Rush | Clockwork | Twin Fords 9 | L 8:46 (900 / 2,450) | L 13:01 (3,440 / 2,950; 3,862 / 14,043) | C: D (10,695 / 5,205; 19,440 / 13,397); D: D (8,015 / 7,380; 16,952 / 17,416) |
| 09 | Extreme rush | Crown | Highmoor 5 | D (8,365 / 5,035) | D (7,750 / 3,450) | C: D (8,500 / 2,250; 17,280 / 17,100) |
| 10 | Extreme rush | Clockwork | Greenhold 3 | L 14:25 (3,390 / 4,000; 5,438 / 13,947) | L 10:39 (980 / 4,050) | C: **W 12:33** (6,535 / 1,420); D: D (8,475 / 3,845; 16,047 / 16,270) |
| 11 | Air rush | Crown | Twin Fords 9 | W 12:27 (8,775 / 2,425) | W 13:26 (8,930 / 3,260) | |
| 12 | Air rush | Clockwork | Greenhold 3 | W 10:18 (7,380 / 1,050) | W 11:12 (8,175 / 2,250) | |
| 13 | Rush | Clockwork | Dune Sea 7 | | | C: L 11:10 (1,650 / 4,100; 4,590 / 9,595); D: D (4,055 / 3,440; 10,627 / 16,128) |
| 15 | Balanced | Clockwork | Greenhold 3 | | | D: W 12:10 (8,570 / 2,250; 17,599 / 8,731) |
| 16 | Timing | Crown | Twin Fords 9 | | | D: D (12,985 / 4,625; 22,169 / 15,580) |

| | Round A | Round B | Round C/D (rush games and checks) |
| --- | --- | --- | --- |
| Won / drawn / lost | 5 / 5 / 2 | 6 / 3 / 3 | C: 2 / 3 / 1, D: 1 / 4 / 1 |
| The Mother got up | for a real attack (a06: 15 Clock Soldiers at her nest) | never without a big attack or a last stand | the same (c10: 12 Clock Soldiers) |

By plan: the eco plans (Timing, Balanced, Economy, Air) won 13, drew 6 and lost none of their 19 filmed games. The
rushes (won / drawn / lost): round A 0 / 2 / 2, round B 0 / 1 / 3, round C 1 / 3 / 1, round D 0 / 3 / 1: they went
from losing their economy to holding even with the enemy's income in most games, but a rush against a walled Crown or
the Clockwork's early army is still the weakest way to play the Brood.

(0.22.0's round 3, same kind of games on the old economy and the old computer: no win, 8 draws, 3 losses in round B.)

### What round A showed (fixed for round B)

1. **The Tyrant Sire chased riders and no Raptor was laid** (a05, picture 03). A Musketeer and a Cuirassier at home got
   him up at 9:13 (the swarm defence sends him against a small harass when no warriors can take it). The Crown's riders
   then kept out of his reach (they kite slow defenders since 0.27.0), and he stayed in the squad, following them, for
   minutes. Her clutch sat full (19/20) with 4,000 food in hand: an egg of his line needs him on his nest. The Crown
   came back at 13:30 and the Brood ended the game behind. **Fix:** a Sire in the defence goes back to his nest once
   only riders are left, once he is 16 tiles from her, or after 30 s (unless the fight is at the Mother and needs the
   Sires); he is not sent out again for 40 s. Round B: the same game traded 14,235 for 10,195 (was 4,675 for 10,685).
2. **One hidden building kept a beaten side alive** (a01, picture 09): from 11:00 the Crown had no army and no hall,
   the Brood had 135 Raptors at its supply cap and 12,780 food, and the wave walked between two places for four
   minutes. **Fix:** the hunt (above). Round B: won at 14:37.
3. **The Rush went into an army twice its size** (a08: 10 Raptors into 560 of Clockwork at 3:00; lost at 8:46).
   **Fix:** called off by what its scout saw.
4. **An Extreme rush that "won" its first wave stayed a rush** (a10: 6 grubs until 8:00, 3,187 food by 10:00 against
   7,545; lost at 14:25). **Fix:** every rush plays Balanced once its first wave is home.

### What round B showed (fixed for round C)

5. **After the rush, all economy and no army** (b07, b08, b10: all three lost). The Balanced economy put every 100
   food into Rootmaws and turtles on new ground with 3 Raptors at home from 4:00 to 8:00, while the Crown's army grew to
   1,360 (b07) and the Clockwork's to 1,600 (b10, which took the Mother at 9:47). Against the Clockwork its watching
   grub sees little of an army that gathers in its main, so the brake (warriors first when its army is under 70% of the
   enemy army it saw) never started. And b07 grew to stage 3 at 9:36 (60 s without eggs) with 1,075 of army against
   2,440 seen. **Fixes:** under-armed with under 30 army supply, no more Rootmaws (from the fourth) or expansions until
   the army is up; against the Clockwork the army it wants is at least 2 a second from 2:00, up to 800 (what any
   player knows of the Clockwork's tempo, not what it sees); no growth while an army twice its own was seen lately.
   Round C: b07 and b08 became draws with better trades and more income than the enemy, b10 became a win.

### What round C showed (fixed for round D)

6. **A turtle misused** (c10, picture 06). The alarm sends a Mound Turtle from home to root in front of the natural;
   at 6:33 it got up while 12 Clock Soldiers were already at the Mother and walked into them, uprooted (its 12 supply
   gone while it walks). **Fix:** no alarm turtle once enemies are at the Mother or 150 of army is near home; one that
   meets enemies on its way roots where it stands, a tank in their way.
7. **A rush that came home kept attacking** (c13, Dune Sea): its second wave of 14 Raptors went at 5:30 into the
   Clockwork and died, then the brake held its third Rootmaw: lost at 11:10 on 4,590 earned. **Fix:** two minutes of
   building after the rush; the brake holds Rootmaws only from the fourth. And the alarm's "warriors before grubs" only
   with 16 grubs or more: in the headless check of the same plan on Greenhold its grubs stood at 9 to 14 until 12:00
   under an alarm that never went off. Round D: the same game held to 15:00 (a draw, 4,055 for 3,440).
8. **The packs found nothing for three minutes** (the headless Economy game against the Crown: 14 packs sent at 11:46,
   nothing more until 14:25: packs that arrived went back to the wave's one target). **Fix:** each pack gets its next
   place when it arrives; a grid every 10 tiles (a Raptor sees 7). The same headless game was then won at 14:18: the packs found the last buildings four times in a row (8 s to 23 s each).

### The owner's known weak spots, as the films showed them

- **The army idling at home:** not seen in the eco plans (waves from 6:00 to 8:00 in every game, and at its cap the
  army goes whatever the plan says). It was seen as the egg-bound bank (food idle, not the army) and fixed by item 1
  and section 2.
- **The Mother uprooting when she should not:** not seen in the 36 filmed games. Where she got up it was for a big
  attack at her nest with little army at home (pictures 04 and 05: 15 Clock Soldiers; c10: 12), the swarm defence's
  "big" rule, or in the last stand of a lost game.
- **Turtles misused:** the alarm turtle (item 6). The natural turtle and the turtles on new ground were always well
  placed (picture 01).
- **Horsemen harassing workers:** the grubs gang up on a lone rider or run (5 grubs gang up in most games); the problem
  the films showed was the Tyrant Sire chasing them (item 1).
- **Rooted Rootmaws under attack:** they uprooted and fought one or two soldiers, and backed off from more, in every
  game (pictures 04, 11), then rooted again.
- **The Brood economy beating the Crown too easily:** yes, see the balance proposals.

## 4. Before and after (headless, Hard against Hard, Greenhold seed 3)

Each plan against a peaceful Hard Crown (milestones):

**Before** (0.27.2, the 0.22.5 plans on today's economy):

| Plan | Tyrant Sire | natural turtle | 3rd Rootmaw | 8 Raptors | stage 2 | Venom Sire | Storm Sire | stage 3 | 1st research | Pack Hunt | 3 far turtles | first wave | food by 6:00 | by 10:00 | egg-bound | food over 600 | result |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| xrush | 0:31 | 4:56 | 8:34 | 1:43 | 10:51 | 9:10 | 12:52 | - | - | - | 14:06 | 1:55 | 2,194 | 4,106 | 20 s | 0 s | draw |
| rush | 1:44 | 0:33 | 8:33 | 2:48 | 10:17 | 9:03 | - | 13:55 | 11:25 | 13:20 | 12:58 | 3:03 | 2,418 | 4,749 | 9 s | 104 s | draw |
| timing | 2:29 | 0:33 | 2:04 | 4:13 | 6:43 | - | - | - | 4:55 | 5:52 | 8:01 | 6:05 | 5,145 | 13,773 | 235 s | 575 s | draw |
| balanced | 2:40 | 0:33 | 2:15 | 4:37 | 5:16 | - | - | - | 5:19 | 6:14 | 6:08 | 6:30 | 5,936 | 16,798 | 364 s | 439 s | won 12:11 |
| economy | 2:49 | 0:33 | 2:23 | 4:24 | 5:07 | - | - | 8:00 | 5:07 | 6:53 | 7:27 | 8:30 | 5,975 | 16,555 | 205 s | 254 s | won 10:47 |
| air | 2:31 | 0:33 | 2:04 | 5:57 | 5:03 | - | 5:45 | 8:46 | 5:45 | 6:40 | 6:58 | 7:11 | 4,573 | 13,608 | 109 s | 462 s | draw |

**After** (this branch; the rushes measured after the last rush fixes):

| Plan | Tyrant Sire | natural turtle | 3rd Rootmaw | 8 Raptors | stage 2 | Venom Sire | Storm Sire | stage 3 | 1st research | Pack Hunt | 3 far turtles | first wave | food by 6:00 | by 10:00 | egg-bound | food over 600 | result |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| xrush | 0:31 | 3:15 | 4:01 | 1:43 | 8:20 | 8:01 | - | 9:38 | 8:20 | 9:15 | 7:25 | 1:55 | 1,974 | 9,292 | 33 s | 420 s | draw |
| rush | 1:44 | 0:33 | 3:44 | 2:48 | 8:03 | 7:43 | - | 9:23 | 8:02 | 9:02 | 7:24 | 3:03 | 2,406 | 10,498 | 60 s | 366 s | won 13:52 |
| timing | 2:33 | 0:33 | 2:02 | 5:04 | 6:42 | 6:36 | 8:14 | 8:56 | 4:55 | 5:51 | 8:01 | 6:04 | 5,171 | 13,506 | 88 s | 394 s | won 12:01 |
| balanced | 2:51 | 0:33 | 1:58 | 5:26 | 5:11 | 6:12 | 8:50 | 8:53 | 6:08 | 7:05 | 5:39 | 7:20 | 4,860 | 15,165 | 154 s | 330 s | won 11:54 |
| economy | 3:12 | 0:33 | 1:49 | 5:23 | 5:15 | 6:19 | - | 7:05 | 6:13 | 7:55 | 5:07 | 7:56 | 5,730 | 15,866 | 79 s | 371 s | won 11:02 |
| air | 2:34 | 0:33 | 1:58 | 5:53 | 5:04 | 6:39 | 5:45 | 8:43 | 5:46 | 6:35 | 6:03 | 7:00 | 4,587 | 13,720 | 81 s | 190 s | won 11:31 |

- Her stage 3 now comes in every plan (7:05 to 9:38; before: in 3 of 6, Economy 8:00, Air 8:46 and the Rush 13:55),
  the Venom Sire in every plan (6:12 to 8:01; before: none in Timing, Balanced, Economy and Air), the third far turtle
  by 5:07 to 8:01.
- The rushes earn twice what they did by 10:00 (9,300 to 10,500 against 4,100 to 4,700) and the Extreme rush's third
  Rootmaw comes at 4:01 instead of 8:34.
- Egg-bound time fell from 109 to 364 s to 79 to 154 s in the eco plans. Food over 600 is still common (190 to 420 s):
  most of it is at the supply cap (200) late in the game, see What is open.
- "8 Raptors" comes later in the eco plans (5:04 to 5:53 against 4:13 to 5:57): grubs and her growth come first now
  that eggs are the limit.

Against a Hard Crown and a Hard Clockwork that play normally (result, enemy value killed / value lost, food by 10:00
against the enemy's gold):

| Plan | Against | Before: result | Before: killed / lost | Before: food by 10:00 / enemy | After: result | After: killed / lost | After: food by 10:00 / enemy |
|---|---|---|---|---|---|---|---|
| Air rush | Clockwork | draw | 6,065 / 9,475 | 10,107 / 8,392 | won 13:42 | 11,145 / 4,125 | 10,464 / 8,915 |
| Air rush | Crown | draw | 12,410 / 9,925 | 12,766 / 10,640 | won 12:15 | 8,605 / 3,450 | 13,259 / 9,500 |
| Balanced | Clockwork | won 13:04 | 9,255 / 6,425 | 14,190 / 7,600 | draw | 10,390 / 6,020 | 11,671 / 8,586 |
| Balanced | Crown | won 10:36 | 7,880 / 4,700 | 16,276 / 7,980 | won 11:53 | 9,210 / 3,915 | 15,953 / 9,500 |
| Economy | Clockwork | won 9:57 | 7,635 / 1,225 | 10,340 / 6,731 | draw | 13,300 / 7,135 | 12,620 / 9,604 |
| Economy | Crown | won 12:38 | 10,010 / 5,850 | 16,785 / 8,360 | won 12:13 | 10,600 / 4,350 | 13,961 / 10,260 |
| Timing | Clockwork | draw | 5,645 / 12,050 | 12,863 / 9,699 | draw | 13,285 / 7,595 | 11,166 / 9,019 |
| Timing | Crown | draw | 4,255 / 10,575 | 14,014 / 8,740 | won 12:39 | 8,455 / 7,925 | 14,068 / 8,360 |
| Rush | Clockwork | draw | 4,620 / 2,625 | 4,565 / 7,284 | **lost 11:21** | 1,770 / 3,725 | 3,654 / 9,089 |
| Rush | Clockwork (Dune Sea 7) | | | | draw | 4,350 / 3,705 | 5,257 / 7,619 |
| Rush | Crown | draw | 2,860 / 6,915 | 4,680 / 7,600 | draw | 8,705 / 5,335 | 8,444 / 9,500 |
| Extreme rush | Clockwork | draw | 5,810 / 3,515 | 3,897 / 6,797 | draw | 8,485 / 5,895 | 6,576 / 7,720 |
| Extreme rush | Clockwork (Twin Fords 9) | | | | draw | 5,205 / 5,285 | 6,417 / 7,159 |
| Extreme rush | Crown | draw | 1,120 / 4,675 | 4,105 / 6,080 | draw | 10,070 / 4,100 | 8,566 / 7,980 |

On the same twelve games: **before 4 won, 8 drawn, 0 lost, killed 77,565 for 77,955 lost (1 to 1); after 5 won, 6
drawn, 1 lost, killed 114,020 for 63,570 lost (1.8 to 1).** The eco plans went from 1.05 to 1.9 to 1, the rushes from
0.8 to 1.5 to 1. Two eco wins against the Clockwork became draws in this one run each (the filmed games of the same
plans against the Clockwork were won: b02, b06, b12, c14, d15); single games swing by a win either way, the trade is the
steadier measure. The Rush against the Clockwork on Greenhold is the plan's weak spot (What is open).

## 5. What is open

- **The eco plans still bank food at their supply cap** (200): from about 10:00 the Brood sits on 1,000 to 15,000 food
  in long games. Its army is as big as it can be; only spending it (a wave) or maturing (which needs supply) uses
  food. That is the supply cap's job (design_principles 2: "a big bank must not be a win button").
- **The hunt** finds a hidden building in about a minute on the maps tried; a building on ground its creatures can't
  reach is not handled.
- **The Rush and the Extreme rush against the Clockwork** now survive and sometimes win, but earn less than the
  Clockwork all game: their opening (9 or 6 grubs) costs more than the rush gains against an army of 560 at 3:00.
- **The Crown wall rule** (no wave into a wall with claws alone) still decides when the Brood attacks the Crown.
- **The other tests**: see Tests.

## 6. Balance proposals for the owner (not changed here)

1. **The Brood out-earns both Hard computers by far.** On Greenhold seed 3 the eco plans earned 13,500 to 16,800 food
   by 10:00 against the Crown's 8,400 to 10,600 gold and the Clockwork's 7,600 to 9,700 cogs (x1.4 to x2). The Hard
   Brood computer won 14 of the 24 eco-plan games filmed or measured here and lost none. The source is 0.24.22's
   distance pay (Defs.FOOD_BONUS 1.5: a far Rootmaw x2.5). A middle value, **FOOD_BONUS 0.8 (x1.8)**, would by the
   numbers above put the Brood near the Crown by 10:00 (about 10,000 to 11,500) and still well above 0.22.5's 6,300 to
   7,700. Or keep the bonus and shorten the Rootmaw's ground (PIT_GROUND 3,000), so the far pay moves the Brood to new
   ground sooner (more exposed income, design_principles 2).
2. **Her laying is the Brood's real limit from 4:30**, not food: a stronger economy only grows the bank. If the owner
   lowers the far pay, the egg-bound triggers here still hold (they follow her clutch, not a clock).
3. **The rushes against the Clockwork:** the Clockwork has 560 of army at 3:00 on Hard; neither rush can hit before
   it (8 Raptors at 1:43, 200 of value). The Extreme rush yardstick (docs/design_principles.md 5) is met in time (8
   Raptors by 1:43, the wave at 1:55) but it is beaten by the Clockwork's first wind-ups, as it should be by a proper
   defence.

## Tests

Run on this branch (Godot 4.7 headless; the "Aborted" Godot prints after quitting is the known one).

- **Boot check** (`godot --headless --quit-after 300`): no script error.
- **tools/test_ai_brood.gd, all six profiles: 0 failures.** Its limits moved to today's times with about a minute's
  margin (the table in section 4; xrush 8 Raptors by 2:40 / attack 2:55, rush Tyrant Sire by 2:00, the eco plans'
  third Rootmaw by 4:00, stage 2 by 7:00 to 8:00, the Venom Sire by 7:10 to 8:20, her stage 3 by 9:40 to 10:40 (new),
  food by 6:00 at least 4,000, Air 3,400). Two checks were fixed, not just moved:
  - "natural": the test took the natural from the AI's list of free spots at 1 s, when the grub sent to it at 0:00
    already blocked it, so it took the third expansion (32 tiles out on Greenhold) for the natural and failed in every
    eco profile (on main too). It now ranks the spots by walk without the "taken" tests: the natural at 0:33, passes.
  - the bank check counts only a STALL: food over 900 for a minute while she has eggs and the supply is not full. On
    today's economy food over 900 at the supply cap or with her clutch empty is the economy, not the computer (it
    failed with 204 to 259 s on main).
  - one last change came from these runs: Balanced's stage 3 waited for its wave to end (all its Raptors were in it,
    none at home to offer for the 75 spoils), so the spoils kept for a Sire or her stage 3 now get Raptors laid for
    them while a wave is out too. Balanced's stage 3 then came at 8:24.
- tools/test_brood_new.gd: 0 failures. tools/test_brood_ai_defend.gd: ALL PASS (the swarm, the Mother kept rooted, the
  Tyrant Sire against a small harass, the struck Rootmaws).
- tools/test_ai_wall_vs_rush.gd: one failure, "at least 3 Musketeers by 2:40" (the Crown's third at 2:59). It fails the
  same way on main (3:00): it is the Crown's opening after 0.24.0 (docs/exhaust_economy.md, open question 1), not the
  Brood computer. The wall, the gate and the rest of the test pass.

The headless measurements (sections 1 and 4) ran before the last two changes (the alarm turtle, the hunt's packs and
the Crown tempo floor were in for the rush re-runs and the films of round D; the spoils fed during a wave only for the
tests above).

## Tools

- tools/measure_brood_ai.gd: now also records each milestone (8 Raptors, research, Pack Hunt, the far turtles, Rootmaw
  counts, grub counts, the supply cap), the ground left under the rooted Rootmaws each minute, spent and uprooted
  Rootmaws, the Mother's eggs each minute, and the seconds it was egg-bound, banked over 600 / 1,200 food and at its
  supply cap.
- tools/test_ai_brood.gd: its milestones moved to today's times (section 4).
