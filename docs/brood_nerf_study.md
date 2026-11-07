# Brood nerf study (brood-nerf-study, on 0.33.6)

The question: the owner's slight Brood economy nerf in 0.33.6 (Defs.FOOD_BONUS 1.5 -> 1.2: a far Rootmaw pays up to x2.2
the near rate instead of x2.5; near ones unchanged). Does it close the Crown v Brood gap without breaking Brood v Clockwork?

## How it was measured

- 170 computer games, Hard v Hard, up to 15:00, all played on 0.33.6 code. The "before" games use a measuring switch,
  not an old checkout: `Game.food_bonus` (a static var that defaults to Defs.FOOD_BONUS; Game.food_mult reads it) set by
  `fb:1.5` on tools/play_ai_optimal.gd. The game itself never changes it, so the rules are unchanged; everything else in
  the "before" games is the 0.33.6 code (the only difference between 0.33.5 and 0.33.6 in the game was this constant).
- Matchups: Crown v Brood (OPTIMAL v OPTIMAL), Clockwork v Brood (OPTIMAL v OPTIMAL), Crown OPTIMAL v Brood ECONOMY, and
  Crown v Clockwork (OPTIMAL v OPTIMAL) as the control: the bonus does not enter that game at all, so its "1.5" and "1.2"
  games are just two runs of the same game, and the gap between them is pure noise.
- Maps: Dune Sea, Greenhold, Red Coast, Hollowfen, Kestrel Rise. Seeds: 5 per map per matchup per bonus value (2 for the
  Brood on Economy), the same map and seed for both values; sides swap between seeds (the subject is P1 in about half).
- No game stalled or crashed (all 170 have a result). One game took ~80-90 s of CPU, two at a time.
- Tools: tools/study/brood_nerf_games.py (runs the queue), tools/study/brood_nerf_report.py (the tables below), raw
  results per game in docs/brood_nerf_study/data/ (result.txt: a line a minute per side; story.txt: the AI STORY lines).
- Income = gold earned (Brood biomass, Crown gold, Clockwork gold; the Crown's powder and the Clockwork's Tension are
  not in it, the same measure as the earlier studies). A game with no winner at 15:00 is a draw; its "leader" is the side
  whose income earned + 2 x army value is 10% ahead.

**The games are not deterministic run to run.** The same map and seed played twice (the control twins) gave the same
result only 16 times in 25, and the Crown's income ratio at 8:00 moved by 0.12 on average (up to 0.47) between twins. On
Kestrel Rise the control went 2-3-0 one way and 5-0-0 the other with nothing changed. So: one game says almost nothing; a
swing of about 2 wins in 25 is noise.

## The answer in short

| | before (1.5) | now (1.2) | noise check |
|---|---|---|---|
| Crown v Brood: Brood W-D-L (25 games) | 22-3-0 | 16-9-0 | control moved 3 -> 5 wins with no change |
| ... Brood won or ahead at 15:00 | 25 of 25 | 25 of 25 | |
| ... Brood income / Crown's at 8:00 | 1.62 | 1.46 | |
| ... mean length of decided games | 11:47 | 12:24 | |
| Clockwork v Brood: Brood W-D-L | 9-13-3 | 8-15-2 | |
| ... Brood won or ahead / behind | 14 / 8 | 13 / 10 | |
| ... Brood income / Clockwork's at 8:00 | 0.86 | 0.72 | |
| Brood's own income at 8:00, same map and seed, 1.2 over 1.5 | | CvB 0.89, KvB 0.89, Economy 0.91 | control 0.99 |

1. **1.2 cut the Brood's income by about 10-11%** (paired by map and seed; the control shows ~1% drift), most of it after
   5:00 when the far Rootmaws are up. Halls (3.7), Rootmaws (~6) and grubs (~48) at 8:00 v the Crown barely changed: the
   Brood still takes the same ground, it just earns less from it.
2. **It slowed the Crown v Brood games but did not change who wins.** The Brood's wins fell 22 -> 16 of 25 and the
   draws rose 3 -> 9, but in every one of those draws the Brood was ahead at 15:00, and the Crown did not win or lead a
   single game at either value (0 of 50 OPTIMAL games, 0 of 20 against the Brood on Economy). The win drop is at the edge
   of noise (Fisher p = 0.10). The Brood still earns about 1.5x the Crown at 8:00 and 1.6x at 10:00, and its army is
   about 1.7x the Crown's at 8:00 (was 2.5x).
3. **Brood v Clockwork held.** The results barely moved (9-13-3 -> 8-15-2; won or ahead 14 -> 13), well inside the noise.
   But the Brood already earned LESS than the Clockwork before the nerf (0.86 at 8:00) and now earns 0.72; its grubs at
   8:00 fell 37 -> 31. It wins on its army's efficiency, not its income. This matchup has less room for further cuts than
   the Crown one suggests.
4. **The control says the Crown computer is the weak side, not only the Brood the strong one**: the Crown also loses to
   the Clockwork (won 3-5 of 25, earns ~0.67 of the Clockwork's income at 8:00, army ~0.3 of it). The Crown v Brood gap
   is partly the Brood's economy and largely the Crown computer, which the owner already said (2026-11-04: "the Crown AI
   is still too stupid to make that judgement").

**Conclusion.** 1.2 did what a slight nerf should: the Brood earns ~10% less, its games against the Crown last longer and
end as Brood leads instead of Brood kills more often, and Brood v Clockwork is not visibly hurt. It did NOT close the
Crown v Brood gap: the Crown still never wins. A further small step (1.0, roughly another 5-7% of the Brood's income by
the same scaling) would probably not flip those games either, and it would push the Brood further below the Clockwork's
income, where it is already behind. So no further economy step looks needed or useful now; the bigger lever for Crown v
Brood is the Crown computer (it is also losing to the Clockwork). If the owner still wants one more small notch, 1.0 is the
size to try, and it should be re-measured against the Clockwork with this same tool before it ships.

Run it again: `python3 tools/study/brood_nerf_games.py run OUT --rounds 5 --jobs 2 --data DATA` then
`python3 tools/study/brood_nerf_report.py DATA` (add a bonus value to MATCHUPS to try 1.0).

## Per map notes

- **Kestrel Rise** is the Brood's best map against the Crown (income ~1.8-2.0x at 8:00 with either value; 4-5 wins of 5)
  and the nerf did nothing there. It is also the map where the control twins disagreed most.
- **Dune Sea and Hollowfen** moved the most against the Crown (Brood wins 4 -> 2 of 5 each, more draws; income ratio
  at 8:00 1.63 -> 1.27 on Dune Sea).
- **Greenhold and Red Coast**: the Brood still won 4 of 5 at 1.2.
- **Clockwork v Brood**: Hollowfen is the Clockwork's map (the Brood lost 2 of 5 with either value, earning 0.6-0.8 of the
  Clockwork); Greenhold is where 1.2 hurt the Brood's income most (0.99 -> 0.64 at 8:00), though no extra losses came of it.

## Tables (tools/study/brood_nerf_report.py)

## Summary per matchup and bonus

Win / draw / loss are the subject's (the Brood; the Crown in the control). Draws: who led at 15:00 (income + 2 x army, 10% margin) as subject / even / opponent. Ratios are the subject's mean over its opponent's mean (games still running at that time).

| matchup | bonus | games | W-D-L | draws led (subj/even/opp) | mean length (decided games) | income ratio 5:00 / 8:00 / 10:00 | army ratio 8:00 / 10:00 |
|---|---|---|---|---|---|---|---|
| Crown v Brood (OPTIMAL v OPTIMAL) | 1.5 | 25 | 22-3-0 | 3/0/0 | 11:47 (22) | 1.24 / 1.62 / 1.83 | 2.51 / 4.11 |
| Crown v Brood (OPTIMAL v OPTIMAL) | 1.2 | 25 | 16-9-0 | 9/0/0 | 12:24 (16) | 1.16 / 1.46 / 1.58 | 1.69 / 2.38 |
| Crown OPTIMAL v Brood ECONOMY | 1.5 | 10 | 8-2-0 | 2/0/0 | 13:18 (8) | 1.18 / 1.69 / 1.89 | 1.53 / 1.61 |
| Crown OPTIMAL v Brood ECONOMY | 1.2 | 10 | 5-5-0 | 5/0/0 | 13:12 (5) | 1.07 / 1.51 / 1.64 | 1.38 / 1.51 |
| Clockwork v Brood (OPTIMAL v OPTIMAL) | 1.5 | 25 | 9-13-3 | 5/3/5 | 13:36 (12) | 0.68 / 0.86 / 1.11 | 0.63 / 0.66 |
| Clockwork v Brood (OPTIMAL v OPTIMAL) | 1.2 | 25 | 8-15-2 | 5/2/8 | 12:20 (10) | 0.64 / 0.72 / 0.93 | 0.73 / 0.61 |
| Crown v Clockwork (control; Crown's view) | 1.5 | 25 | 3-14-8 | 3/2/9 | 11:49 (11) | 0.63 / 0.67 / 0.70 | 0.31 / 0.28 |
| Crown v Clockwork (control; Crown's view) | 1.2 | 25 | 5-13-7 | 3/0/10 | 12:32 (12) | 0.64 / 0.65 / 0.68 | 0.30 / 0.30 |

## The Brood's economy at 8:00 (Brood games)

| matchup | bonus | Brood income 5:00 / 8:00 / 10:00 | opponent's | Brood army 8:00 / 10:00 | opponent's | Brood halls / Rootmaws / grubs at 8:00 |
|---|---|---|---|---|---|---|
| Crown v Brood (OPTIMAL v OPTIMAL) | 1.5 | 3167 / 8138 / 12685 | 2554 / 5031 / 6926 | 1526 / 2696 | 609 / 656 | 3.7 / 6.0 / 49.1 |
| Crown v Brood (OPTIMAL v OPTIMAL) | 1.2 | 2867 / 7147 / 11187 | 2478 / 4910 / 7062 | 1145 / 2192 | 677 / 922 | 3.7 / 5.7 / 48.2 |
| Crown OPTIMAL v Brood ECONOMY | 1.5 | 2867 / 7690 / 12496 | 2432 / 4560 / 6612 | 1005 / 1694 | 656 / 1055 | 3.8 / 6.1 / 56.0 |
| Crown OPTIMAL v Brood ECONOMY | 1.2 | 2650 / 7036 / 11617 | 2470 / 4674 / 7068 | 902 / 1741 | 652 / 1156 | 3.8 / 5.6 / 54.0 |
| Clockwork v Brood (OPTIMAL v OPTIMAL) | 1.5 | 2349 / 6076 / 10434 | 3438 / 7064 / 9367 | 772 / 1310 | 1217 / 1976 | 3.5 / 5.8 / 37.2 |
| Clockwork v Brood (OPTIMAL v OPTIMAL) | 1.2 | 2280 / 5208 / 8840 | 3560 / 7218 / 9477 | 932 / 1330 | 1269 / 2165 | 3.1 / 5.5 / 31.0 |

## Spread between seeds (what is noise)

| matchup | bonus | income ratio 8:00, min-max (sd) | income ratio 10:00 | army ratio 10:00 |
|---|---|---|---|---|
| Crown v Brood (OPTIMAL v OPTIMAL) | 1.5 | 1.11-2.11 (sd 0.30) | 1.17-2.96 (sd 0.44) | 0.46-44.08 (sd 13.66) |
| Crown v Brood (OPTIMAL v OPTIMAL) | 1.2 | 0.78-2.15 (sd 0.32) | 1.06-2.95 (sd 0.47) | 0.53-22.00 (sd 4.80) |
| Crown OPTIMAL v Brood ECONOMY | 1.5 | 1.18-2.21 (sd 0.30) | 1.30-3.40 (sd 0.64) | 0.65-5.20 (sd 1.31) |
| Crown OPTIMAL v Brood ECONOMY | 1.2 | 1.13-2.11 (sd 0.31) | 1.17-2.93 (sd 0.57) | 0.21-14.05 (sd 4.09) |
| Clockwork v Brood (OPTIMAL v OPTIMAL) | 1.5 | 0.52-1.12 (sd 0.18) | 0.49-1.78 (sd 0.30) | 0.06-12.86 (sd 2.73) |
| Clockwork v Brood (OPTIMAL v OPTIMAL) | 1.2 | 0.38-1.20 (sd 0.20) | 0.52-1.88 (sd 0.30) | 0.15-34.79 (sd 7.30) |
| Crown v Clockwork (control; Crown's view) | 1.5 | 0.36-0.97 (sd 0.17) | 0.33-1.37 (sd 0.28) | 0.00-10.75 (sd 2.18) |
| Crown v Clockwork (control; Crown's view) | 1.2 | 0.37-1.28 (sd 0.24) | 0.28-1.63 (sd 0.35) | 0.00-4.02 (sd 0.96) |

Control twins (Crown v Clockwork, same map and seed, run twice; the bonus does not enter): 25 pairs, the same result in 16; the Crown's income ratio at 8:00 differs by 0.12 on average (max 0.47) between the twins. The game is not deterministic run to run, so this is the noise floor of one game.


## Per map (subject's W-D-L; income ratio at 8:00)

| map | cvb 1.5 | cvb 1.2 | cvbe 1.5 | cvbe 1.2 | kvb 1.5 | kvb 1.2 | cvk 1.5 | cvk 1.2 |
|---|---|---|---|---|---|---|---|---|
| dune_sea | 4-1-0, 1.63 | 2-3-0, 1.27 | 1-1-0, 1.97 | 0-2-0, 1.41 | 2-3-0, 0.84 | 3-2-0, 0.80 | 1-2-2, 0.74 | 0-4-1, 0.66 |
| greenhold | 4-1-0, 1.57 | 4-1-0, 1.40 | 2-0-0, 1.54 | 1-1-0, 1.38 | 3-2-0, 0.99 | 1-4-0, 0.64 | 0-2-3, 0.54 | 0-4-1, 0.48 |
| red_coast | 5-0-0, 1.77 | 4-1-0, 1.58 | 2-0-0, 1.86 | 1-1-0, 1.47 | 1-3-1, 0.75 | 1-4-0, 0.70 | 0-3-2, 0.59 | 0-1-4, 0.53 |
| hollowfen | 4-1-0, 1.50 | 2-3-0, 1.40 | 1-1-0, 1.52 | 1-1-0, 1.40 | 0-3-2, 0.79 | 0-3-2, 0.58 | 0-4-1, 0.76 | 0-4-1, 0.71 |
| kestrel_rise | 5-0-0, 1.83 | 4-1-0, 1.84 | 2-0-0, 1.80 | 2-0-0, 2.04 | 3-2-0, 0.95 | 3-2-0, 0.95 | 2-3-0, 0.81 | 5-0-0, 1.00 |

## Every game

| game | subject P | result | end | draw leader | income 8:00 subj/opp | army 8:00 | army 10:00 | Brood halls/maws/grubs 8:00 | subject's builds |
|---|---|---|---|---|---|---|---|---|---|
| cvb dune_sea s301 fb1.2 | P2 | W | 11:54 |  | 6767/4560 | 1220/115 | 2685/0 | 4/4/44 | balanced |
| cvb dune_sea s301 fb1.5 | P2 | W | 10:48 |  | 8002/3800 | 1410/0 | 2945/0 | 4/5/46 | balanced |
| cvb dune_sea s318 fb1.2 | P1 | D | 15:00 | subj | 6814/5700 | 690/645 | 2245/2020 | 4/6/52 | balanced>economy |
| cvb dune_sea s318 fb1.5 | P1 | W | 11:29 |  | 7063/5320 | 780/645 | 2645/60 | 4/6/53 | balanced |
| cvb dune_sea s335 fb1.2 | P2 | D | 15:00 | subj | 4856/3800 | 375/470 | 1080/585 | 4/6/44 | balanced>spitter |
| cvb dune_sea s335 fb1.5 | P2 | D | 15:00 | subj | 6036/4180 | 520/645 | 1445/1695 | 4/6/49 | balanced>spitter |
| cvb dune_sea s352 fb1.2 | P1 | D | 15:00 | subj | 4736/6080 | 425/760 | 1390/1725 | 4/6/42 | balanced>spitter |
| cvb dune_sea s352 fb1.5 | P1 | W | 12:15 |  | 7397/5700 | 1505/770 | 2085/765 | 4/6/48 | balanced>spitter |
| cvb dune_sea s369 fb1.2 | P2 | W | 13:55 |  | 8588/5320 | 775/935 | 2780/1590 | 4/7/52 | balanced |
| cvb dune_sea s369 fb1.5 | P2 | W | 11:05 |  | 8917/4560 | 1615/710 | 2940/0 | 4/7/54 | balanced |
| cvb greenhold s302 fb1.2 | P1 | W | 12:51 |  | 7839/6460 | 1650/765 | 1550/940 | 4/7/49 | balanced>spitter |
| cvb greenhold s302 fb1.5 | P1 | D | 15:00 | subj | 6736/6080 | 1035/995 | 1645/2120 | 4/6/49 | balanced>spitter |
| cvb greenhold s319 fb1.2 | P2 | W | 13:53 |  | 6282/4940 | 975/470 | 1940/1650 | 4/4/49 | balanced |
| cvb greenhold s319 fb1.5 | P2 | W | 10:25 |  | 8722/4560 | 1690/345 | 4035/0 | 4/7/51 | balanced |
| cvb greenhold s336 fb1.2 | P1 | W | 12:29 |  | 6158/4180 | 555/700 | 1640/640 | 4/7/53 | balanced |
| cvb greenhold s336 fb1.5 | P1 | W | 14:34 |  | 5498/3420 | 975/635 | 625/1065 | 4/6/39 | balanced |
| cvb greenhold s353 fb1.2 | P2 | D | 15:00 | subj | 7333/4180 | 1485/870 | 3265/1180 | 3/4/46 | balanced>brute |
| cvb greenhold s353 fb1.5 | P2 | W | 12:36 |  | 9443/4940 | 1745/815 | 3910/365 | 4/7/49 | balanced>brute |
| cvb greenhold s370 fb1.2 | P1 | W | 11:55 |  | 7206/5700 | 1015/535 | 1595/240 | 4/6/53 | balanced |
| cvb greenhold s370 fb1.5 | P1 | W | 14:53 |  | 7836/6080 | 815/420 | 600/1295 | 3/6/53 | balanced |
| cvb hollowfen s304 fb1.2 | P1 | D | 15:00 | subj | 6195/5320 | 910/835 | 1875/1190 | 3/4/31 | balanced>spitter |
| cvb hollowfen s304 fb1.5 | P1 | W | 14:00 |  | 8093/6080 | 1780/760 | 1910/1000 | 3/6/50 | balanced>spitter |
| cvb hollowfen s321 fb1.2 | P2 | W | 14:30 |  | 6642/4560 | 875/815 | 3365/1360 | 3/6/50 | balanced>spitter |
| cvb hollowfen s321 fb1.5 | P2 | D | 15:00 | subj | 8031/4560 | 2150/700 | 2470/1115 | 3/6/49 | balanced>spitter |
| cvb hollowfen s338 fb1.2 | P1 | D | 15:00 | subj | 7139/6080 | 955/1000 | 3385/1895 | 3/6/50 | balanced>brute |
| cvb hollowfen s338 fb1.5 | P1 | W | 12:01 |  | 8190/5700 | 1570/1055 | 3205/345 | 3/6/49 | balanced>brute |
| cvb hollowfen s355 fb1.2 | P2 | W | 12:42 |  | 6813/4180 | 740/410 | 1320/60 | 3/6/53 | balanced |
| cvb hollowfen s355 fb1.5 | P2 | W | 12:11 |  | 8901/5320 | 1540/820 | 3400/585 | 3/6/54 | balanced |
| cvb hollowfen s372 fb1.2 | P1 | D | 15:00 | subj | 7247/4560 | 955/885 | 285/490 | 3/6/52 | balanced |
| cvb hollowfen s372 fb1.5 | P1 | W | 13:30 |  | 8854/6840 | 2650/1175 | 1510/1365 | 3/6/51 | balanced>economy |
| cvb kestrel_rise s305 fb1.2 | P2 | W | 11:41 |  | 7871/3800 | 1685/350 | 1870/340 | 4/7/46 | balanced>timing |
| cvb kestrel_rise s305 fb1.5 | P2 | W | 8:52 |  | 8550/4180 | 1770/0 | None/None | 4/6/46 | balanced>timing |
| cvb kestrel_rise s322 fb1.2 | P1 | W | 9:21 |  | 8106/4560 | 1925/290 | None/None | 4/5/49 | balanced |
| cvb kestrel_rise s322 fb1.5 | P1 | W | 9:34 |  | 9084/4560 | 1250/0 | None/None | 4/5/52 | balanced |
| cvb kestrel_rise s339 fb1.2 | P2 | W | 10:29 |  | 7343/3420 | 1015/525 | 3125/0 | 4/5/52 | balanced |
| cvb kestrel_rise s339 fb1.5 | P2 | W | 12:13 |  | 7839/4180 | 1420/410 | 2715/575 | 4/6/53 | balanced |
| cvb kestrel_rise s356 fb1.2 | P1 | D | 15:00 | subj | 6458/4180 | 1200/695 | 950/1265 | 4/6/50 | balanced>spitter |
| cvb kestrel_rise s356 fb1.5 | P1 | W | 12:34 |  | 8297/5320 | 2200/645 | 3860/1545 | 4/6/50 | balanced>spitter |
| cvb kestrel_rise s373 fb1.2 | P2 | W | 12:03 |  | 7646/4560 | 2185/930 | 3675/530 | 4/6/49 | balanced>spitter |
| cvb kestrel_rise s373 fb1.5 | P2 | W | 11:01 |  | 8892/5320 | 2335/710 | 3735/0 | 4/7/49 | balanced>spitter |
| cvb red_coast s303 fb1.2 | P2 | W | 14:20 |  | 7387/4560 | 1135/870 | 2905/1415 | 4/5/48 | balanced>brute |
| cvb red_coast s303 fb1.5 | P2 | W | 11:56 |  | 8556/4180 | 1805/645 | 3555/115 | 4/5/46 | balanced>brute |
| cvb red_coast s320 fb1.2 | P1 | D | 15:00 | subj | 7594/6080 | 865/885 | 1270/2380 | 4/6/48 | balanced>brute |
| cvb red_coast s320 fb1.5 | P1 | W | 12:04 |  | 9157/6080 | 1695/1185 | 3840/300 | 4/5/48 | balanced>brute |
| cvb red_coast s337 fb1.2 | P2 | W | 12:51 |  | 8413/4560 | 1470/520 | 1730/0 | 4/5/46 | balanced |
| cvb red_coast s337 fb1.5 | P2 | W | 10:15 |  | 8717/4560 | 1115/240 | 2105/0 | 3/5/46 | balanced |
| cvb red_coast s354 fb1.2 | P1 | W | 12:46 |  | 8450/6840 | 1850/1065 | 3795/645 | 4/6/50 | balanced>brute |
| cvb red_coast s354 fb1.5 | P1 | W | 11:29 |  | 9263/6460 | 1595/890 | 4125/115 | 4/7/48 | balanced>brute |
| cvb red_coast s371 fb1.2 | P2 | W | 10:45 |  | 8784/4560 | 1700/585 | 2900/0 | 3/7/46 | balanced>timing |
| cvb red_coast s371 fb1.5 | P2 | W | 9:49 |  | 7383/3800 | 1190/0 | None/None | 3/5/45 | balanced>timing |
| cvbe dune_sea s301 fb1.2 | P2 | D | 15:00 | subj | 6453/5700 | 950/650 | 2055/1725 | 4/5/53 | economy |
| cvbe dune_sea s301 fb1.5 | P2 | D | 15:00 | subj | 7898/4560 | 1545/810 | 1870/1430 | 4/6/56 | economy |
| cvbe dune_sea s318 fb1.2 | P1 | D | 15:00 | subj | 5753/3420 | 700/525 | 1365/885 | 4/5/52 | economy |
| cvbe dune_sea s318 fb1.5 | P1 | W | 12:52 |  | 7573/3420 | 475/470 | 990/530 | 4/6/57 | economy |
| cvbe greenhold s302 fb1.2 | P1 | W | 12:48 |  | 8008/5700 | 1000/880 | 2600/185 | 4/6/58 | economy |
| cvbe greenhold s302 fb1.5 | P1 | W | 14:47 |  | 8682/5320 | 740/820 | 2650/1495 | 4/7/55 | economy |
| cvbe greenhold s319 fb1.2 | P2 | D | 15:00 | subj | 6152/4560 | 875/695 | 1780/1100 | 4/6/57 | economy |
| cvbe greenhold s319 fb1.5 | P2 | W | 13:46 |  | 6608/4560 | 755/820 | 1915/1310 | 4/6/57 | economy |
| cvbe hollowfen s304 fb1.2 | P1 | D | 15:00 | subj | 6545/5320 | 775/895 | 490/2340 | 3/4/52 | economy |
| cvbe hollowfen s304 fb1.5 | P1 | D | 15:00 | subj | 7626/6460 | 1225/650 | 1305/1665 | 3/6/56 | economy |
| cvbe hollowfen s321 fb1.2 | P2 | W | 12:50 |  | 7764/4940 | 925/530 | 2935/705 | 3/7/55 | economy |
| cvbe hollowfen s321 fb1.5 | P2 | W | 14:29 |  | 8501/4560 | 1520/585 | 1770/1010 | 3/5/57 | economy |
| cvbe kestrel_rise s305 fb1.2 | P2 | W | 12:45 |  | 8832/4180 | 2065/755 | 3065/1295 | 4/5/57 | economy |
| cvbe kestrel_rise s305 fb1.5 | P2 | W | 12:09 |  | 8563/5320 | 1825/710 | 2250/760 | 4/6/58 | economy |
| cvbe kestrel_rise s322 fb1.2 | P1 | W | 12:52 |  | 7449/3800 | 475/410 | 1200/815 | 4/6/58 | economy |
| cvbe kestrel_rise s322 fb1.5 | P1 | W | 12:42 |  | 7601/3800 | 750/470 | 900/580 | 4/7/58 | economy |
| cvbe red_coast s303 fb1.2 | P2 | D | 15:00 | subj | 7926/5320 | 650/760 | 440/1600 | 4/5/55 | economy |
| cvbe red_coast s303 fb1.5 | P2 | W | 13:33 |  | 7702/4560 | 840/870 | 850/1300 | 4/5/58 | economy |
| cvbe red_coast s320 fb1.2 | P1 | W | 14:46 |  | 5478/3800 | 600/415 | 1480/905 | 4/7/43 | economy |
| cvbe red_coast s320 fb1.5 | P1 | W | 12:13 |  | 6145/3040 | 375/355 | 2445/470 | 4/7/48 | economy |
| cvk dune_sea s301 fb1.2 | P1 | L | 14:52 |  | 4180/8174 | 355/1450 | 755/2535 | - | optimal>rush |
| cvk dune_sea s301 fb1.5 | P1 | L | 11:06 |  | 4180/8067 | 525/1870 | 0/3630 | - | optimal>rush |
| cvk dune_sea s318 fb1.2 | P2 | D | 15:00 | opp | 5320/6904 | 175/1430 | 1295/2780 | - | optimal>balanced |
| cvk dune_sea s318 fb1.5 | P2 | D | 15:00 | even | 5320/6891 | 175/1695 | 570/1540 | - | optimal>balanced |
| cvk dune_sea s335 fb1.2 | P1 | D | 15:00 | opp | 5700/6751 | 525/1450 | 950/1365 | - | optimal>balanced |
| cvk dune_sea s335 fb1.5 | P1 | D | 15:00 | opp | 6080/6673 | 945/1660 | 1755/1945 | - | optimal>balanced |
| cvk dune_sea s352 fb1.2 | P2 | D | 15:00 | subj | 3800/6143 | 640/890 | 1010/1030 | - | optimal>rush |
| cvk dune_sea s352 fb1.5 | P2 | W | 12:28 |  | 4180/4307 | 410/1315 | 1075/100 | - | optimal>rush |
| cvk dune_sea s369 fb1.2 | P1 | D | 15:00 | opp | 4940/8827 | 290/2020 | 0/4670 | - | optimal>balanced |
| cvk dune_sea s369 fb1.5 | P1 | L | 14:14 |  | 4940/9025 | 0/2760 | 250/3800 | - | optimal>balanced |
| cvk greenhold s302 fb1.2 | P2 | D | 15:00 | opp | 3040/8191 | 0/2290 | 0/3820 | - | optimal>rush>balanced |
| cvk greenhold s302 fb1.5 | P2 | L | 11:11 |  | 4560/8272 | 585/2430 | 0/3740 | - | optimal>rush>balanced |
| cvk greenhold s319 fb1.2 | P1 | L | 14:42 |  | 4180/7760 | 410/2350 | 0/3960 | - | optimal>rush>balanced |
| cvk greenhold s319 fb1.5 | P1 | L | 10:31 |  | 4180/8031 | 235/2310 | 0/3955 | - | optimal>rush>balanced |
| cvk greenhold s336 fb1.2 | P2 | D | 15:00 | opp | 4180/9227 | 60/3290 | 180/5190 | - | optimal>balanced |
| cvk greenhold s336 fb1.5 | P2 | L | 10:58 |  | 3420/9504 | 350/3140 | 0/5430 | - | optimal>balanced |
| cvk greenhold s353 fb1.2 | P1 | D | 15:00 | opp | 5320/9164 | 235/2680 | 1000/3465 | - | optimal>balanced |
| cvk greenhold s353 fb1.5 | P1 | D | 15:00 | opp | 6080/8884 | 705/2540 | 0/3435 | - | optimal>balanced |
| cvk greenhold s370 fb1.2 | P2 | D | 15:00 | opp | 4180/9542 | 490/2970 | 0/3550 | - | optimal>balanced |
| cvk greenhold s370 fb1.5 | P2 | D | 15:00 | opp | 5320/9215 | 135/3230 | 360/5090 | - | optimal>balanced |
| cvk hollowfen s304 fb1.2 | P2 | D | 15:00 | subj | 6460/6544 | 1305/1360 | 1770/1330 | - | optimal>balanced |
| cvk hollowfen s304 fb1.5 | P2 | D | 15:00 | subj | 6460/6886 | 1050/1330 | 1745/1580 | - | optimal>balanced>siege |
| cvk hollowfen s321 fb1.2 | P1 | D | 15:00 | opp | 5700/6805 | 820/1370 | 1430/2505 | - | optimal>balanced |
| cvk hollowfen s321 fb1.5 | P1 | D | 15:00 | opp | 6080/6835 | 815/1495 | 1715/2915 | - | optimal>balanced |
| cvk hollowfen s338 fb1.2 | P2 | D | 15:00 | opp | 5320/9068 | 880/2300 | 670/3715 | - | optimal>balanced |
| cvk hollowfen s338 fb1.5 | P2 | D | 15:00 | opp | 7600/9058 | 1080/1690 | 1365/2915 | - | optimal>balanced |
| cvk hollowfen s355 fb1.2 | P1 | D | 15:00 | opp | 5700/9026 | 900/2190 | 710/3825 | - | optimal>balanced |
| cvk hollowfen s355 fb1.5 | P1 | D | 15:00 | opp | 5320/8788 | 760/2120 | 1475/3000 | - | optimal>balanced |
| cvk hollowfen s372 fb1.2 | P2 | L | 10:34 |  | 3800/7786 | 180/2380 | 0/3940 | - | optimal>rush>balanced |
| cvk hollowfen s372 fb1.5 | P2 | L | 11:17 |  | 4180/8034 | 525/1755 | 0/3035 | - | optimal>rush |
| cvk kestrel_rise s305 fb1.2 | P1 | W | 13:12 |  | 4560/6180 | 360/560 | 1365/560 | - | optimal>rush>balanced |
| cvk kestrel_rise s305 fb1.5 | P1 | D | 15:00 | subj | 3800/6036 | 465/560 | 885/560 | - | optimal>rush>balanced |
| cvk kestrel_rise s322 fb1.2 | P2 | W | 10:54 |  | 7600/6082 | 1110/580 | 2000/0 | - | optimal>balanced |
| cvk kestrel_rise s322 fb1.5 | P2 | D | 15:00 | even | 5320/6788 | 650/1230 | 790/1305 | - | optimal>balanced |
| cvk kestrel_rise s339 fb1.2 | P1 | W | 13:16 |  | 4180/5276 | 475/630 | 945/630 | - | optimal>rush>balanced |
| cvk kestrel_rise s339 fb1.5 | P1 | D | 15:00 | subj | 4560/4914 | 700/140 | 835/420 | - | optimal>rush |
| cvk kestrel_rise s356 fb1.2 | P2 | W | 10:45 |  | 7600/5944 | 1130/680 | 1845/0 | - | optimal>balanced |
| cvk kestrel_rise s356 fb1.5 | P2 | W | 11:24 |  | 5320/6224 | 760/750 | 1775/0 | - | optimal>balanced |
| cvk kestrel_rise s373 fb1.2 | P1 | W | 13:38 |  | 4940/5122 | 605/560 | 1125/280 | - | optimal>rush>balanced |
| cvk kestrel_rise s373 fb1.5 | P1 | W | 13:24 |  | 4560/5216 | 535/350 | 890/560 | - | optimal>rush>balanced |
| cvk red_coast s303 fb1.2 | P1 | D | 15:00 | subj | 3800/5838 | 350/1145 | 520/845 | - | optimal>rush |
| cvk red_coast s303 fb1.5 | P1 | D | 15:00 | opp | 4180/5822 | 115/1680 | 290/2325 | - | optimal>rush>balanced |
| cvk red_coast s320 fb1.2 | P2 | L | 13:09 |  | 3420/6267 | 0/1485 | 170/2315 | - | optimal>rush |
| cvk red_coast s320 fb1.5 | P2 | D | 15:00 | opp | 3800/6362 | 530/1225 | 1160/1115 | - | optimal>rush |
| cvk red_coast s337 fb1.2 | P1 | L | 10:37 |  | 4180/8259 | 635/2570 | 0/3955 | - | optimal>rush>balanced |
| cvk red_coast s337 fb1.5 | P1 | L | 11:19 |  | 3800/8073 | 415/2240 | 170/3195 | - | optimal>rush |
| cvk red_coast s354 fb1.2 | P2 | L | 10:29 |  | 3420/7941 | 350/2170 | 0/3815 | - | optimal>rush>balanced |
| cvk red_coast s354 fb1.5 | P2 | D | 15:00 | opp | 4940/8318 | 765/2040 | 60/1405 | - | optimal>rush>balanced |
| cvk red_coast s371 fb1.2 | P1 | L | 14:24 |  | 4180/7721 | 645/1940 | 595/1985 | - | optimal>rush |
| cvk red_coast s371 fb1.5 | P1 | L | 12:07 |  | 4180/7588 | 355/2430 | 0/3750 | - | optimal>rush>balanced |
| kvb dune_sea s301 fb1.2 | P2 | D | 15:00 | even | 4954/7219 | 750/1615 | 1690/3135 | 4/6/34 | balanced>rush>balanced |
| kvb dune_sea s301 fb1.5 | P2 | D | 15:00 | opp | 4916/7433 | 1450/1745 | 1285/2775 | 4/5/19 | balanced>rush>balanced |
| kvb dune_sea s318 fb1.2 | P1 | W | 12:27 |  | 7266/8140 | 275/1810 | 3025/2365 | 4/6/43 | balanced>rush>timing>brute |
| kvb dune_sea s318 fb1.5 | P1 | W | 13:07 |  | 7439/6768 | 1180/1400 | 1790/2065 | 4/7/44 | balanced>rush>balanced>brute |
| kvb dune_sea s335 fb1.2 | P2 | D | 15:00 | subj | 4981/6359 | 800/270 | 1330/1020 | 3/6/29 | balanced>rush>balanced>brute |
| kvb dune_sea s335 fb1.5 | P2 | D | 15:00 | even | 5975/7180 | 550/1710 | 590/3020 | 3/6/40 | balanced>rush>balanced |
| kvb dune_sea s352 fb1.2 | P1 | W | 11:13 |  | 6371/6893 | 1195/840 | 2435/70 | 3/6/35 | balanced>rush>timing>brute |
| kvb dune_sea s352 fb1.5 | P1 | W | 11:29 |  | 7862/7651 | 590/965 | 2540/0 | 4/6/54 | balanced>rush>balanced>brute |
| kvb dune_sea s369 fb1.2 | P2 | W | 13:49 |  | 5405/7374 | 1625/1250 | 1400/440 | 3/6/30 | balanced>rush>balanced>brute |
| kvb dune_sea s369 fb1.5 | P2 | D | 15:00 | opp | 4190/7504 | 600/1950 | 1265/3285 | 3/5/21 | balanced>rush>balanced |
| kvb greenhold s302 fb1.2 | P1 | D | 15:00 | subj | 4864/7866 | 1725/1925 | 1375/2285 | 3/6/24 | balanced>rush>balanced>timing |
| kvb greenhold s302 fb1.5 | P1 | D | 15:00 | subj | 7570/6863 | 885/1470 | 935/2500 | 4/7/45 | balanced>rush>balanced |
| kvb greenhold s319 fb1.2 | P2 | D | 15:00 | subj | 5048/7339 | 775/1485 | 675/3275 | 2/5/36 | balanced>rush>balanced |
| kvb greenhold s319 fb1.5 | P2 | D | 15:00 | opp | 5822/6814 | 300/1765 | 690/2255 | 3/4/41 | balanced>rush>balanced |
| kvb greenhold s336 fb1.2 | P1 | W | 14:31 |  | 4734/8305 | 250/340 | 1035/1150 | 3/6/27 | balanced>rush>balanced>timing>brute |
| kvb greenhold s336 fb1.5 | P1 | W | 14:24 |  | 7783/7195 | 550/1445 | 1915/2475 | 4/6/51 | balanced>rush>balanced>brute |
| kvb greenhold s353 fb1.2 | P2 | D | 15:00 | opp | 4819/7264 | 900/1155 | 985/2605 | 2/4/30 | balanced>rush>balanced |
| kvb greenhold s353 fb1.5 | P2 | W | 13:32 |  | 6402/6379 | 900/200 | 1895/300 | 4/6/42 | balanced>rush>balanced>brute |
| kvb greenhold s370 fb1.2 | P1 | D | 15:00 | subj | 5488/8142 | 1400/2115 | 1275/1855 | 3/5/21 | balanced>rush>balanced |
| kvb greenhold s370 fb1.5 | P1 | W | 13:53 |  | 7425/8014 | 850/1315 | 650/1855 | 4/7/43 | balanced>rush>balanced>brute |
| kvb hollowfen s304 fb1.2 | P1 | D | 15:00 | even | 4592/8118 | 1250/1730 | 800/2645 | 3/6/21 | balanced>rush>balanced |
| kvb hollowfen s304 fb1.5 | P1 | L | 14:45 |  | 6970/7695 | 1340/2025 | 650/2685 | 3/7/43 | balanced>rush>timing |
| kvb hollowfen s321 fb1.2 | P2 | L | 14:20 |  | 4133/7166 | 750/1480 | 705/3215 | 3/6/19 | balanced>rush>balanced |
| kvb hollowfen s321 fb1.5 | P2 | L | 14:34 |  | 4399/7308 | 975/1240 | 875/3045 | 3/6/19 | balanced>rush>balanced |
| kvb hollowfen s338 fb1.2 | P1 | L | 11:43 |  | 4719/8133 | 690/1745 | 675/2310 | 1/3/34 | balanced>rush>balanced |
| kvb hollowfen s338 fb1.5 | P1 | D | 15:00 | opp | 6708/7578 | 835/1545 | 715/2835 | 3/6/45 | balanced>rush>balanced |
| kvb hollowfen s355 fb1.2 | P2 | D | 15:00 | opp | 4300/7266 | 975/1650 | 775/3075 | 3/6/20 | balanced>rush>balanced |
| kvb hollowfen s355 fb1.5 | P2 | D | 15:00 | even | 4781/6951 | 600/240 | 900/990 | 3/7/33 | balanced>rush>balanced>brute |
| kvb hollowfen s372 fb1.2 | P1 | D | 15:00 | opp | 4716/8053 | 725/1145 | 420/2810 | 3/6/29 | balanced>rush>balanced>timing |
| kvb hollowfen s372 fb1.5 | P1 | D | 15:00 | even | 6832/7646 | 775/1785 | 800/3040 | 3/6/52 | balanced>rush>balanced |
| kvb kestrel_rise s305 fb1.2 | P2 | W | 9:26 |  | 6183/5151 | 1300/0 | None/None | 4/6/40 | balanced>rush>balanced |
| kvb kestrel_rise s305 fb1.5 | P2 | D | 15:00 | subj | 6760/6048 | 440/270 | 1475/1215 | 4/7/38 | balanced>rush>balanced |
| kvb kestrel_rise s322 fb1.2 | P1 | D | 15:00 | opp | 4276/6989 | 1075/1120 | 1275/2700 | 4/6/19 | balanced>rush>balanced |
| kvb kestrel_rise s322 fb1.5 | P1 | W | 14:17 |  | 6869/6528 | 1000/1610 | 3025/2170 | 4/7/44 | balanced>rush>balanced>brute |
| kvb kestrel_rise s339 fb1.2 | P2 | W | 11:00 |  | 5505/5145 | 1025/0 | 875/0 | 4/5/33 | balanced>rush>balanced |
| kvb kestrel_rise s339 fb1.5 | P2 | W | 11:59 |  | 5150/5541 | 675/0 | 900/70 | 4/5/28 | balanced>rush>balanced |
| kvb kestrel_rise s356 fb1.2 | P1 | W | 12:01 |  | 4219/5952 | 700/100 | 950/0 | 4/5/23 | balanced>rush>balanced |
| kvb kestrel_rise s356 fb1.5 | P1 | W | 14:36 |  | 5798/6388 | 1000/1400 | 1340/1760 | 4/5/34 | balanced>rush>balanced>brute |
| kvb kestrel_rise s373 fb1.2 | P2 | D | 15:00 | opp | 7584/6432 | 1290/1755 | 2540/3295 | 4/5/48 | balanced>rush>balanced |
| kvb kestrel_rise s373 fb1.5 | P2 | D | 15:00 | subj | 4857/6546 | 575/125 | 835/480 | 3/5/21 | balanced>rush>balanced>brute |
| kvb red_coast s303 fb1.2 | P2 | D | 15:00 | opp | 5325/6998 | 400/1540 | 975/2880 | 3/5/43 | balanced>rush>balanced |
| kvb red_coast s303 fb1.5 | P2 | D | 15:00 | subj | 4312/6605 | 500/170 | 1265/780 | 3/5/25 | balanced>rush>balanced>brute |
| kvb red_coast s320 fb1.2 | P1 | W | 12:50 |  | 5964/8076 | 1125/1545 | 2275/1805 | 3/6/40 | balanced>rush>balanced>brute |
| kvb red_coast s320 fb1.5 | P1 | W | 12:37 |  | 7850/7625 | 725/1585 | 2675/2325 | 3/6/43 | balanced>rush>timing>brute |
| kvb red_coast s337 fb1.2 | P2 | D | 15:00 | opp | 2791/7264 | 150/1340 | 520/3230 | 2/4/24 | balanced>rush>balanced |
| kvb red_coast s337 fb1.5 | P2 | L | 14:05 |  | 5577/7303 | 500/1740 | 2050/3150 | 4/6/43 | balanced>rush>balanced |
| kvb red_coast s354 fb1.2 | P1 | D | 15:00 | subj | 6982/7603 | 690/1725 | 1975/2060 | 4/6/47 | balanced>rush>balanced |
| kvb red_coast s354 fb1.5 | P1 | D | 15:00 | subj | 5758/7561 | 1075/1205 | 1500/1350 | 4/6/38 | balanced>rush>balanced |
| kvb red_coast s371 fb1.2 | P2 | D | 15:00 | opp | 4969/7199 | 1450/2050 | 1935/3740 | 3/6/26 | balanced>rush>balanced |
| kvb red_coast s371 fb1.5 | P2 | D | 15:00 | opp | 3894/7476 | 440/1530 | 190/2975 | 2/3/24 | balanced>rush>balanced |
