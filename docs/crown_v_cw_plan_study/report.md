## Results

| run | games | W-D-L | won or led | lost or trailed | decided (mean length) | mean end | halls lost Crown / CW | greedy pick fired (plan picked) |
|---|---|---|---|---|---|---|---|---|
| default | 38 | 0-28-10 | 0 | 37 | 10 (13:23) | 14:34 | 72 / 8 | 38 (balloon 7, economy 5, rush 3, timing 23) |
| economy | 38 | 0-24-14 | 0 | 38 | 14 (13:11) | 14:20 | 63 / 0 | 38 (economy 35, rush 3) |
| balanced | 38 | 0-25-13 | 0 | 38 | 13 (13:02) | 14:19 | 71 / 0 | 38 (balanced 35, rush 3) |

## The Crown's primary income against its bench, and the Clockwork's (mean over games still running)

| run | Crown 5:00 | 8:00 | 10:00 | 15:00 | CW 5:00 | 8:00 | 10:00 | 15:00 |
|---|---|---|---|---|---|---|---|---|
| default | 2620 = 0.63 (38) | 5610 = 0.59 (38) | 7700 = 0.58 (38) | 12692 = 0.52 (28) | 4064 (38) | 9437 (38) | 14333 (38) | 26908 (28) |
| economy | 2770 = 0.66 (38) | 6400 = 0.67 (38) | 9260 = 0.70 (38) | 15903 = 0.65 (24) | 4068 (38) | 9469 (38) | 14776 (38) | 28146 (24) |
| balanced | 2680 = 0.64 (38) | 5630 = 0.59 (38) | 8310 = 0.63 (38) | 13101 = 0.54 (25) | 4104 (38) | 9545 (38) | 14960 (38) | 28625 (25) |

## Army value at 8/10/12 (Crown / Clockwork) and halls standing at 10:00

| run | army 8:00 | 10:00 | 12:00 | halls 10:00 |
|---|---|---|---|---|
| default | 1200 / 1306 (38) | 987 / 2353 (38) | 857 / 3793 (36) | 2.3 / 3.6 |
| economy | 788 / 1849 (38) | 886 / 3126 (38) | 701 / 4890 (36) | 1.7 / 3.6 |
| balanced | 728 / 1799 (38) | 787 / 3095 (38) | 550 / 5154 (37) | 1.7 / 3.7 |

## Continuous measures (the results are all at the floor)

| run | Crown score / CW score at the end (income + 2 x army; mean, median) | Crown's first hall lost (games, median time) | units lost Crown / CW (mean) |
|---|---|---|---|
| default | 0.35, 0.30 | 34, 11:20 | 72 / 90 |
| economy | 0.35, 0.29 | 29, 10:10 | 89 / 74 |
| balanced | 0.28, 0.26 | 34, 10:32 | 82 / 66 |

## Paired with the default run (the same map, seed and sides)

| run | games paired | better result / same / worse (L < D- < D < D+ < W) | score ratio higher in |
|---|---|---|---|
| economy | 38 | 3 / 27 / 8 | 21 of 38 |
| balanced | 38 | 5 / 25 / 8 | 11 of 38 |

## What the Clockwork did: its reads of the Crown and its OPTIMAL picks

| run | CW read the Crown GREEDY | read it AGGRESSIVE | CW plans picked (all picks) | CW plan at the end |
|---|---|---|---|---|
| default | 3 | 4 | economy 18, springer 9, heavy 8, balanced 7 | economy 14, springer 9, heavy 8, balanced 7 |
| economy | 21 | 3 | economy 20, springer 12, heavy 8, balanced 6 | economy 17, springer 10, heavy 8, balanced 3 |
| balanced | 19 | 2 | economy 20, springer 12, heavy 12, balanced 5 | economy 19, heavy 10, springer 7, balanced 2 |

## Only the games where the greedy answer fired (in that run)

| run | games | W-D-L | won or led | Crown inc 8:00 | 10:00 | CW inc 10:00 | army 10:00 C / CW | halls lost C / CW |
|---|---|---|---|---|---|---|---|---|
| default | 38 | 0-28-10 | 0 | 5610 | 7700 | 14333 | 987 / 2353 | 72 / 8 |
| economy | 38 | 0-24-14 | 0 | 6400 | 9260 | 14776 | 886 / 3126 | 63 / 0 |
| balanced | 38 | 0-25-13 | 0 | 5630 | 8310 | 14960 | 787 / 3095 | 71 / 0 |

## Game by game (Crown's result; + = a draw it led; the greedy pick; the Clockwork's plans after it)

| game | slot | default | economy | balanced |
|---|---|---|---|---|
| amberfall_vale_r0 | P1 | D- · G@1:34 balloon · CW balanced>springer | D- · G@1:34 economy · CW balanced>springer | D- · G@1:34 balanced · CW balanced>springer>heavy |
| amberfall_vale_r1 | P2 | D- · G@1:37 timing · CW balanced>springer | D- · G@1:37 economy · CW balanced>springer | D- · G@1:37 balanced · CW balanced>springer |
| ashfall_r0 | P2 | D- · G@1:19 timing · CW balanced>springer | D- · G@1:18 economy · CW balanced>springer | D- · G@1:19 balanced · CW balanced>springer>heavy |
| ashfall_r1 | P1 | D- · G@1:28 economy · CW balanced>springer | L 14:51 · G@1:31 economy · CW balanced>springer | D- · G@1:28 balanced · CW balanced>springer |
| ashford_crossing_r0 | P2 | D- · G@1:42 balloon · CW balanced>economy | D- · G@1:42 economy · CW balanced>economy | D- · G@1:42 balanced · CW balanced>economy |
| ashford_crossing_r1 | P1 | D- · G@1:30 timing · CW balanced>heavy | D- · G@1:29 economy · CW balanced>heavy | D- · G@1:30 balanced · CW balanced>heavy |
| border_march_r0 | P2 | D- · G@1:17 timing · CW balanced | L 11:48 · G@1:17 economy · CW balanced>springer | D- · G@1:17 balanced · CW balanced>springer>heavy |
| border_march_r1 | P1 | L 12:37 · G@1:28 economy · CW balanced>economy | L 12:23 · G@1:28 economy · CW balanced>economy | L 11:52 · G@1:29 balanced · CW balanced>economy |
| cinder_steps_r0 | P1 | D- · G@1:15 timing · CW balanced>heavy | L 14:22 · G@1:15 economy · CW balanced>heavy | D- · G@1:14 balanced · CW balanced>heavy>economy |
| cinder_steps_r1 | P2 | D- · G@1:11 timing · CW balanced | D- · G@1:11 economy · CW balanced>springer | D- · G@1:11 balanced · CW balanced>springer>heavy |
| dune_sea_r0 | P1 | D- · G@1:32 timing · CW balanced>springer | D- · G@1:32 economy · CW balanced>springer>economy | D- · G@1:32 balanced · CW balanced>springer |
| dune_sea_r1 | P2 | D- · G@1:17 timing · CW balanced>economy | D- · G@1:17 economy · CW balanced>economy | L 12:41 · G@1:18 balanced · CW balanced>economy |
| frostfang_r0 | P2 | D- · G@1:18 balloon · CW balanced>economy | D- · G@1:18 economy · CW balanced>economy | D- · G@1:18 balanced · CW balanced>economy |
| frostfang_r1 | P1 | L 14:56 · G@1:31 balloon · CW balanced | D- · G@1:31 economy · CW balanced | D- · G@1:30 balanced · CW balanced |
| frostmere_r0 | P2 | L 10:14 · G@1:17 rush · CW balanced>economy>balanced | L 14:34 · G@1:36 rush · CW balanced>economy>balanced | L 13:06 · G@1:36 rush · CW balanced>economy |
| frostmere_r1 | P1 | D- · G@1:30 timing · CW balanced>springer | D- · G@1:30 economy · CW balanced>springer | D- · G@1:29 balanced · CW balanced>springer |
| glimmerdeep_r0 | P1 | L 13:53 · G@1:25 balloon · CW balanced | L 14:18 · G@1:25 economy · CW balanced>springer | L 13:33 · G@1:25 balanced · CW balanced>springer>heavy |
| glimmerdeep_r1 | P2 | D- · G@1:14 timing · CW balanced>economy>balanced | D- · G@1:14 economy · CW balanced>economy>heavy | L 12:02 · G@1:14 balanced · CW balanced>economy |
| greenhold_r0 | P1 | L 14:22 · G@1:31 timing · CW balanced>heavy | D- · G@1:31 economy · CW balanced>heavy | D- · G@1:28 balanced · CW balanced>heavy |
| greenhold_r1 | P2 | D- · G@1:17 economy · CW balanced>economy>heavy | D- · G@1:17 economy · CW balanced>economy | D- · G@1:17 balanced · CW balanced>economy |
| highmoor_r0 | P2 | L 14:11 · G@1:19 timing · CW balanced>economy | D- · G@1:19 economy · CW balanced>economy | D- · G@1:18 balanced · CW balanced>economy |
| highmoor_r1 | P1 | D- · G@1:31 timing · CW balanced>economy | D- · G@1:31 economy · CW balanced>economy | D- · G@1:31 balanced · CW balanced>economy |
| hollowfen_r0 | P2 | D- · G@1:21 timing · CW balanced>heavy | D- · G@1:21 economy · CW balanced>heavy | L 12:15 · G@1:21 balanced · CW balanced>heavy |
| hollowfen_r1 | P1 | D- · G@1:33 timing · CW balanced>economy | D- · G@1:33 economy · CW balanced>economy | D- · G@1:34 balanced · CW balanced>economy |
| kestrel_rise_r0 | P1 | D- · G@1:17 timing · CW balanced>economy | D- · G@1:17 economy · CW balanced>economy | L 13:34 · G@1:17 balanced · CW balanced>economy |
| kestrel_rise_r1 | P2 | D- · G@1:28 rush · CW balanced>heavy | D- · G@1:26 rush · CW balanced>heavy | D- · G@1:28 rush · CW balanced>heavy |
| mirewood_r0 | P1 | L 14:45 · G@1:31 timing · CW balanced>economy | L 11:51 · G@1:29 economy · CW balanced>economy | D- · G@1:31 balanced · CW balanced>economy |
| mirewood_r1 | P2 | D- · G@1:18 timing · CW balanced>economy | L 13:54 · G@1:17 economy · CW balanced>economy | D- · G@1:19 balanced · CW balanced>economy |
| red_coast_r0 | P1 | L 10:52 · G@1:33 rush · CW balanced>economy>balanced | L 12:28 · G@1:33 rush · CW balanced>economy>balanced | L 12:45 · G@1:33 rush · CW balanced>economy>balanced |
| red_coast_r1 | P2 | D- · G@1:18 balloon · CW balanced>economy | L 12:02 · G@1:19 economy · CW balanced>economy | L 14:19 · G@1:18 balanced · CW balanced>economy |
| redrock_canyon_r0 | P1 | D- · G@1:28 timing · CW balanced>springer | L 12:56 · G@1:28 economy · CW balanced>springer>economy | D- · G@1:28 balanced · CW balanced>springer |
| redrock_canyon_r1 | P2 | D- · G@1:30 economy · CW balanced>economy | L 13:14 · G@1:30 economy · CW balanced>economy | D- · G@1:29 balanced · CW balanced>economy |
| saltmarsh_isles_r0 | P2 | D- · G@1:28 economy · CW balanced>heavy | D- · G@1:28 economy · CW balanced>heavy | L 14:28 · G@1:28 balanced · CW balanced>heavy>economy |
| saltmarsh_isles_r1 | P1 | D- · G@1:37 balloon · CW balanced>heavy | D- · G@1:40 economy · CW balanced>heavy | D- · G@1:36 balanced · CW balanced>heavy |
| thornwood_maze_r0 | P2 | D · G@1:17 timing · CW balanced>springer | D- · G@1:17 economy · CW balanced>springer | L 12:59 · G@1:17 balanced · CW balanced>springer |
| thornwood_maze_r1 | P1 | L 13:20 · G@1:33 timing · CW balanced>economy | L 12:23 · G@1:33 economy · CW balanced>economy | L 12:25 · G@1:33 balanced · CW balanced>economy |
| twin_fords_r0 | P1 | D- · G@1:30 timing · CW balanced>springer | D- · G@1:28 economy · CW balanced>springer | L 13:29 · G@1:30 balanced · CW balanced>springer |
| twin_fords_r1 | P2 | L 14:48 · G@1:17 timing · CW balanced>economy | L 13:40 · G@1:17 economy · CW balanced>economy | D- · G@1:17 balanced · CW balanced>economy |
