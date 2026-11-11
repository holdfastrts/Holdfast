# Brood v Brood, coached (brood-v-brood-coach)

The owner (2026-11-11 22:35): every matchup COACHED and FILMED "with the same level of scrutiny and attention" as the Crown v
Brood job. This is the Brood mirror: both sides are the Hard Brood computer (scripts/ai_brood_new.gd), OPTIMAL against
OPTIMAL. Coaching as a human coach does it: film real games, watch them, name each mistake with its time and a picture,
find the decision behind it in the code, fix that decision, replay the same seed and check the mistake is gone.

No unit, building or economy number was changed. Every fix is the computer's play and is GATED to the mirror (the enemy
is the Brood) unless said otherwise.

## The tool

`tools/shot_brood_mirror.gd` (new): two Brood computers on any map and seed, filmed and logged.

    xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 30 --script res://tools/shot_brood_mirror.gd -- \
        map:greenhold seed:1 out:/abs/dir [end:900] [sa:optimal] [sb:optimal] [shots:1] [every:30]

It writes `lines.txt` (every 30 s per side: food, spoils, income earned, supply, grubs, eggs, army by kind and value, the
Mother's stage, health and rooting, its rooted creatures, value killed and lost, the computer's plan, wave, defence squad,
attack_at and the enemy army it has seen), `story.txt` (both computers' own lines), `log.txt`, `result.txt`, and
pictures: the whole map and each Mother every minute, every fight of 4+ creatures a side (at most every 20 s), a Mother
under 70% health. A 15:00 game takes about 5 minutes with pictures on this machine (two at a time).

Maps: Greenhold (crossroads), Highmoor (highlands), Hollowfen and Kestrel Rise (hand-made), Twin Fords (rivers) for the
measuring batch. (Dune Sea was dropped after round 2: it is Greenhold's crossroads layout in the desert biome, the same
geography, and its games were the same as Greenhold's minute by minute.)

## Round 1: 0.33.16 as it is (Greenhold, Dune Sea, Hollowfen, Kestrel Rise; seed 1)

| map | result | P1 picks | P2 picks | income at 8:00 (P1 / P2) | grubs at 8:00 |
|---|---|---|---|---|---|
| Greenhold | draw at 15:00 (P2's Mother dying) | 1:40 Rush, 3:06 Balanced | 1:50 Rush, 3:06 Balanced | 2,803 / 2,788 | 16 / 12 |
| Dune Sea | P2 wins 14:56 | 1:40 Rush, 3:02 Balanced | 1:41 Rush, 3:02 Balanced | 3,471 / 2,547 | 25 / 20 |
| Hollowfen | P2 wins 11:43 | 1:48 Rush, 3:36 Balanced | (no read, Balanced) | 3,703 / 7,928 | 10 / 54 |
| Kestrel Rise | P1 wins 13:25 | (no read, Balanced) | (no read, Balanced) | 9,684 / 9,574 | 53 / 53 |

For scale: the QA study's Brood earned 5,842 by 8:00 on average against every opponent.

### Coach's notes

Greenhold (the clearest game; Dune Sea played the same):
- 0:00 both root a Mound Turtle 22 tiles out (their standard opening), 0:40 a grub to the enemy's main.
- 1:40 / 1:50 both read the other GREEDY, "no army and no production at its base", and pick the Rush. Neither was
  greedy: this is the Brood's normal opening (no production building exists; the Tyrant Sire comes at 2:00-3:00).
- 2:49 / 2:50 both Raptor rushes (10) leave at the same second and cross. 3:06 both read AGGRESSIVE "a Horse Breeder or
  riders early" and switch to Balanced: the enemy's RAPTORS were taken for Horsemen.
- 3:06 to 15:00: 34 lines of "riders in its land", "guards its grubs with N against M riders, no chase", "a Rootmaw
  under attack uproots to back off": the anti-Horseman lockdown (grubs run to the warriors, warriors guard and never
  chase, Raptors laid until the "riders" are matched, waves wait while it is "short of warriors against the riders").
  Picture: the Mother's clutch full (Eggs 10/10) at 4:37 while the food is spent on Raptors that stand guard.
- Economy flat for five minutes: 8 grubs at 5:00, 16 at 8:00, 2,800 earned by 8:00. Stage 2 only at 9:33 / 10:34.
- 10:09 P2's first real wave is 43 Raptors and nothing else; 11:16 P1's 24.

Hollowfen: P1 read GREEDY and rushed, then sat in the rider lockdown (stage 2 at 9:42); P2 never got a read, played
Balanced, earned twice as much (7,928 at 8:00, 54 grubs), had stage 3 by 7:24, and its Spitters and Raptors killed P1's
Mother at 11:43. Kestrel Rise: neither read anything early, both played Balanced and both economies were healthy (9,700 at
8:00); there the problems were the attacks (round 2).

![The rider lockdown, Greenhold 4:37](shots/brood-v-brood-coach/r1_greenhold_0437_rider_lockdown.jpg)
![Greenhold at 8:00, round 1: few grubs, armies loitering](shots/brood-v-brood-coach/r1_greenhold_0800_overview.jpg)

### The biggest mistakes (both sides: it is the same computer)

1. **1:40, the read of the Brood's normal opening as GREEDY** (AIBroodNew._nb_read): "no army and no production at its
   base" and "a second base and little army" are true of every Brood opening (no production building; a turtle on new
   ground at 0:00). OPTIMAL then punishes "greed" with a Rush into an opponent who is not greedy, and the Rush makes the
   Rush's own economy (9 grubs).
2. **3:06, the enemy's Raptors read as riders** (AIBroodNew.is_rider: speed 95 or more, melee, not one of the Brood's
   OWN rooting kinds; a Raptor runs at 96). Every Raptor wave set off the brood-anti-riders answer to a Horseman rush for
   the rest of the game: grubs off work, warriors on guard, no chase, Raptor eggs instead of grubs, waves held back. This
   is the single biggest mistake: the economy at 8:00 was a third of the healthy games'.
3. Stage 2 at 9:30-10:30 instead of 4:20-5:00, and the first real wave at 10:00 (both follow from 2).

## Round 2: fixes 1 and 2 (same seeds)

Fix 1 (first try): against another Brood, greed is a third base early or no Sire seen by 3:30.
Fix 2: `is_rider` is false for every Brood unit (a Raptor is a warrior, met by the swarm defence).

| map | result | P1 | P2 | income at 8:00 | grubs at 8:00 |
|---|---|---|---|---|---|
| Greenhold | P1 wins 13:17 | 3:30 GREEDY, Timing | 4:05 GREEDY, Timing | 9,693 / 9,203 | 43 / 45 |
| Dune Sea | draw | (as Greenhold) | | 9,705 / 9,302 | 43 / 45 |
| Hollowfen | draw | 3:30 GREEDY Timing, 6:03 Economy | Balanced | 7,630 / 9,374 | 48 / 54 |
| Kestrel Rise | draw | Balanced | Balanced | 9,735 / 9,745 | 54 / 53 |

The lockdown is gone (0 rider lines in all four games) and the economies are three times bigger at 8:00 (9,200-9,700,
43-54 grubs; stage 2 at 4:21-6:01).

![Greenhold at 8:00, round 2](shots/brood-v-brood-coach/r2_greenhold_0800_overview.jpg)

### Coach's notes, round 2

- The "no Sire seen by 3:30" half of fix 1 still read GREEDY on three maps: the Sires root beside the Mother out of the
  watching grub's sight. Greenhold P1 then played the Timing attack: 5:56, 23 Raptors into an army of 600; it lost 425
  and killed 150 (thrown away).
- **THE BASE TRADE** (Kestrel Rise, both sides): both waves leave at the same second, 6:30 (30 supply) and 8:35 (81
  supply), and walk past each other. Each wave razes the other's Rootmaws and turtles while the other's eats its grubs
  at home; at 9:11 P1 pulls back with 495 of 2,155 and P2 at 7:10 with 270 of 1,230. Neither army ever fought the
  other. A human sees the enemy army leave (the watching grub sees it: the ALARM line fires the moment its own wave is
  home) and meets it, at home if need be, where the swamp, the Sires and the fresh eggs help.

![Kestrel Rise 6:43, round 1: the two armies cross the middle](shots/brood-v-brood-coach/r1_kestrel_0643_armies_pass.jpg)
![Kestrel Rise 8:48, round 2: the base trade, P1's column (red) heads for P2's base while P2 (blue) kills P1's turtle](shots/brood-v-brood-coach/r2_kestrel_0848_base_trade.jpg)

Fixes for round 3:
- Fix 1 (final): only a third base early with little army seen is greed against another Brood (_nb_brood_greedy).
- Fix 3, the meeting (AIBroodNew._nb_meet_army, called from _nb_wave_tick): against another Brood, while its wave is
  still on the road (more than 18 tiles from its goal), an enemy army worth 40% of the wave or more, seen nearer its
  Mother than the wave is (and not beside the wave), becomes the wave's target: it turns and meets it.

(Rounds 3 onward below.)
