# Clockwork v Brood, coached (job clockwork-v-brood-coach)

Short sentences, to be read aloud.

The owner (2026-11-11 22:35) wants every matchup coached and filmed with the same scrutiny as the Crown v Brood job. This
job is the Clockwork against the Brood: Hard OPTIMAL against Hard OPTIMAL, filmed, watched closely, each mistake named with
its time and a picture, the decision behind it fixed, the same seed played again. Both computers are coached. No unit,
building or economy number was changed: every fix is a decision of a computer.

## The short version

Five coaching rounds (six filmed games each, the same seeds every round) and one extra film, then a measuring batch of
16 games (8 maps, both start slots) before and after. Ten decisions changed: eight of the Clockwork's, two of the
Brood's. One fix (C1) was tried, shown wrong by the films and taken back.

| | the Clockwork's W-D-L | won or led | games decided (mean length) | halls lost: Clockwork / Brood | income at 8:00 / 10:00 (medians, CW / BR) | army at 8:00 (CW / BR) |
|---|---|---|---|---|---|---|
| before (main, 0.33.16) | 2-8-6 | 6 of 16 | 8 (12:37) | 22 / 10 | 7,109 / 4,742 ; 9,763 / 7,574 | 1,090 / 775 |
| **after** | **4-7-5** | **9 of 16** | 9 (11:52) | **20 / 17** | 7,367 / 5,426 ; 10,209 / 9,579 | 1,375 / 775 |

The films, round by round (the Clockwork's result in the six games): round 1 (main) 1 win, 1 loss, 4 draws; round 2 0-2-4
(C1 was wrong); round 3 4 wins, 2 draws; round 4 1 win, 5 draws; round 5 2 wins, 1 loss, 3 draws. One game a seed is
noise (the qa study: a seed agrees with itself about 2 times in 3), so read the batch, not a single film.

**The Clockwork** (scripts/ai_cw_army.gd, ai_cw_push.gd, ai_clockwork.gd; every fix gated on a Brood enemy):
- C2 **counter-attacks** right after its defence breaks a Brood wave (it sat on its gears for minutes before);
- C3 + C5 a push far out **turns home fighting** when Raptors raid the base (the guard rule counted the push itself as
  the base's guard, so it never came; and when it came it walked home on plain moves into the raid);
- C4 **does not push out into a wave** that is at its door (it met it in the open and lost 1,555 in 12 s);
- C6 a written build stuck for 60 s with 1,000 cogs in the bank **hands over** to the shared rules (a Pendulum build
  waited 5 minutes for a Heavy Works it had no room for, bank 4,545);
- C7 a new Cog Press goes **by the Clocktower with the most brass** for each press (four presses sat on the dying main,
  none by the natural; the Clockwork's income stopped at about 9:00 in 4 of 16 games);
- C8 a push pulling back from the Brood **falls back fighting** when chased (Raptors ran it down from behind).
**The Brood** (scripts/ai_brood_new.gd; gated on a Clockwork enemy):
- B1 **the pack marches together**: its wave waits for its bulk until contact instead of arriving in a column;
- B2 **the Mother moves house** to her safest expansion when a push she cannot meet stands at her nest; her Sires go
  with her instead of dying in the defence.
Not changed (written up): the Clockwork's counters into the Brood's swamp (2 of 8 lost badly), its Winders lost while a
push turns home, the Brood's biomass piling up at 1,000-2,000 in some games, a shared economy finding for the mirror.

## How the games are filmed

- `tools/shot_ai_match.gd` (extended, additive): `pa:` / `pb:` set the plans (OPTIMAL here), `every:60` adds a picture of
  each side's army (its densest group) every 60 s, a stats line per side every 15 s (`stats.txt`: income earned, bank,
  workers, army value and kinds, rooted creatures, halls, supply, units and buildings lost, where the army stands, the
  Clockwork's push phase) and the AI STORY (`story.txt`). The fights and the bases are filmed as before.
  `xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_ai_match.gd -- a:clockwork b:brood pa:optimal pb:optimal map:greenhold seed:11 swap:0 out:DIR end:900 every:60`
- The six filmed seeds (both start slots on the first two maps): Greenhold 11 (both slots), Dune Sea 23 (both slots),
  Hollowfen 37 (Clockwork P1), Kestrel Rise 41 (Clockwork P2). Every round plays the same six.
- `tools/study/cvb_coach.py`: the measuring batch (16 games, tools/qa_match.gd, headless) and its report.
- Pictures: `docs/shots/clockwork-v-brood-coach/` (jpg, 640 wide). Names: round, map/seed/slot, game clock, what. The films' stats and AI STORY lines: `docs/clockwork-v-brood-coach/films/<round>/`.

## Round 1 (main, 0.33.16)

Results: Greenhold 11 draw (Clockwork P1, even) and draw (Brood P1 led); Dune Sea 23 **Brood won 14:49** (Clockwork P1) and
draw (Clockwork P2 led); Hollowfen 37 **Clockwork won 12:59**; Kestrel Rise 41 draw (the Brood far ahead: the Clockwork
had 0 army and 8 Winders at 15:00).

### The pattern (all six games)

| time | what happened | games |
|---|---|---|
| 1:36-1:48 | the Brood's scout grub reads the Clockwork GREEDY ("no army and no production at its base") and picks Rush | 6 of 6 |
| 1:43-1:57 | the Clockwork's scout reads the Brood GREEDY ("a second base and little army": the Mound Turtle the Brood roots on new ground at 0:00 in every plan) and picks the Clock Soldier rush | 6 of 6 |
| 2:44-2:54 | the Brood's rush: 10 supply of Raptors | 6 of 6 |
| 3:10-3:23 | the Clockwork sees the Raptors, reads AGGRESSIVE and drops its Clock Soldier rush for Balanced | 6 of 6 |
| 3:29-3:59 | the rush pulls back with 75-100 of 250 left, having killed 130-470 (Winders): it pays | 6 of 6 |
| 5:44-7:46 | the Brood's first real wave (29-47 supply) at the Clockwork's base | 6 of 6 |
| 7:20-12:49 | the Clockwork's first real push (one never went out before 12:49 on Kestrel Rise) | |

### Coach's notes: the Clockwork

1. **A false read and a wasted opening** (every game, 1:43-1:57). The Brood's turtle on new ground at 0:00 is its normal
   opening, not greed. The Clock Soldier rush it picks is dropped 1.5 minutes later, before it did anything. The second
   Clocktower, the point of the economy opening, came at 4:49-5:19. *Decision:* `AIOptimal._punish` (scripts/ai_optimal.gd),
   the Clockwork against the Brood. *Fix C1* below.
2. **No counter-push after a held wave** (Greenhold 11, Clockwork P1, 12:45; picture
   `r1_g11w0_1302_army_waits_after_hold.jpg`). The Brood's wave of 2,570 broke on the Clockwork's base and pulled back with
   620. The Clockwork, 2,595 strong, sat on its gears for two minutes: "holds at its gathering point: its last push (2800)
   had to pull back; the next goes worth 3500". The Brood rebuilt to 3,785 and the game was drawn. A human counter-attacks
   there. *Decision:* `ai_cw_army.may_launch` (the AFTER_FAIL rule never forgets a failed push). *Fix C2.*
3. **The push walks on while Raptors kill the base** (Dune Sea 23, Clockwork P1, 9:07-10:41; picture
   `r1_d23w0_1000_winders_gone.jpg`: "WINDERS 0/5" at every press). Raids of 549 and 805 Raptors went round the push of
   2,030 into the base. The Winders fell from 27 to 6; the push turned round only at 10:13, when a Clocktower was about to
   fall. The Clockwork lost its main at 10:41 and the game at 14:49. Kestrel Rise ended the same way (12:55, 0 army, 8
   Winders left). *Decision:* `ai_cw_push._should_retreat`: "the base is attacked" compares the raid with
   `AI._guard_value()`, the WHOLE army with the push in it, so a raid had to be worth 1.5 times the push. *Fix C3.*
4. **The army stays small at home for minutes** (Kestrel Rise 41: 560-840 from 4:29 to 10:38, the reckoning
   487 -> 1,721). The Brood's waves every 1.5-2 minutes kill Winders and soldiers (killed 470, 560, 1,995, 770, 480) and the
   army never grows. Not fixed in round 1 (C2 and C3 attack it from both ends).

### Coach's notes: the Brood

1. **The waves arrive in a column** (Greenhold 11 at 7:36, picture `r1_g11w0_0736_raptor_column.jpg`, and at 7:00 with the
   sides swapped, `r1_g11w1_0700_raptor_wave.jpg`). Every unit is given its own attack-move to the goal; the Raptors run
   ahead of the Spitters and of those from the far side of the base, and the Clockwork's army meets them a few at a time.
   Waves of 1,025 and 1,000 lost 775 each. *Decision:* the wave's launch in `AIBroodNew._nb_army` and `_nb_wave_tick`.
   *Fix B1.*
2. **Not a mistake: the rush and the waves pay.** Measured from the log, the rush killed 130-470 for 75-175 lost in all
   six games, and the mid-game waves killed 530, 2,225, 620, 4,075, 700, 1,950 (Winders and buildings included) for
   425-925 each. The pressure is the Brood's strength in this matchup: it stays.
3. **The base trade works for it** (Dune Sea 23 9:34, Kestrel Rise 12:55): its army went round the Clockwork's push into
   the base. Good play; the Clockwork must answer it (C3).
4. **Biomass piles up** (Dune Sea 23: 1,214-2,160 from 8:34 to 11:35; Greenhold 11: 1,154-1,311 at 9:49-10:19; Hollowfen
   37: 750-1,276 at 10:50-11:35 while the Clockwork's push stood at its Mother). Looked into in round 2.
5. **A Sire lost in a hopeless defence** (Hollowfen 37, 10:23): "defends with 7 (5 raptor, 1 tyrannosaur, 1 dilophosaurus,
   475) against 1,100" at the Mother. The Tyrant Sire died; no Raptor egg until a new Tyrant Lure grew from 11:36; the
   Mother fell at 12:59.

### Fixes after round 1

- **C1, the Brood's opening is not greed** (`AIOptimal._cw_v_brood_greedy`, new; one line in `_punish`): the Clockwork
  against the Brood answers a GREEDY read with the matchup's normal pick (`NORMAL["clockwork"]["brood"]`: Pendulums 3,
  Balanced 2, Owl raids 2), not the Clock Soldier rush. `-- cvbread:off` plays it as before.
- **C2, the counter-push** (`ai_cw_army._held_note` / `_counter_ok`, new; one line in `tick` and one in `may_launch`):
  against the Brood, for 75 s after a whole-army defence that killed 600 or more, the push may go worth 1.4 times the
  enemy army it has seen alive lately (at least 900), whatever the last failed push or the reckoning's table say.
  `-- cvbcounter:off`.
- **C3, raiders in the base call the push home** (`ai_cw_push._brood_raid_home`, new; one line in `_should_retreat`):
  against the Brood, a raid worth 300 or more at the base that the armed units at home (not the push's) do not match calls
  a push that is 1,000 px or more out home. `-- cvbhome:off`.
- **B1, the pack marches together** (`AIBroodNew._nb_close_start` / `_nb_close_ranks` / `_nb_close_release`, new; one line
  at the wave's launch, one in `_nb_wave_tick`, one in `_wave_end_nb`): against the Clockwork (the plans without a
  written build, not a rush's first wave, 6 units or more), until contact (an armed enemy or an enemy building within 12
  tiles of the leaders, the leaders within 14 tiles of the goal, or 75 s) the units more than 5 tiles ahead of the pack's
  bulk (its 70th percentile on the way) wait on HOLD. Then all go in together. `-- nbpack:off`.

## Round 2 (round 1's fixes)

Results: Greenhold 11 **Brood won 14:51** (Clockwork P1; round 1 draw) and draw, the Clockwork far ahead (army 3,900 to
195; round 1 the Brood led); Dune Sea 23 **Brood won 14:10** (Clockwork P1; round 1 14:49) and draw; Hollowfen 37 **Brood
won 8:55** (round 1 the Clockwork won); Kestrel Rise 41 **Brood won 11:16** (round 1 a draw the Brood led).
Worse for the Clockwork. What the films showed:

### What worked

- **C2, the counter** (Greenhold 11, Clockwork P2, 11:52): "counter-attacks: its defence killed 1,170, it goes out worth
  3,615 against the 72 it has seen alive lately"; the push committed at 11:53 and held the field to 15:00 (army 3,900 to
  195, income even).
- **C3 fired** (Dune Sea 23, 11:02): "Brood raiders in the base (1,250 value, 70 at home to meet them)".
- **B1, the pack**: "its pack meets the enemy: all go in together (62 supply)" (Dune Sea 23, 7:51); that wave killed 2,710.

### Coach's notes: the Clockwork

1. **C1 was wrong.** Without the Clock Soldier rush pick the Brood's read of the Clockwork did not change at 3:20: it kept
   its Rush plan, and its next wave was bigger (Hollowfen 37: 53 supply of Raptors at 6:29 against 33 in round 1, picture
   `r2_h37w0_0656_rush_brood_wave.jpg`; the Clockwork's whole army of 1,625 was gone by 7:19). In round 1 the Clock
   Soldiers of the dropped rush went out at 3:37-4:16 ("push goes out: 8 units") and the Brood answered "defends its home
   with 12 against 560", read the Clockwork AGGRESSIVE and turned Balanced. Checked on the two lost seeds with
   `-- cvbread:off` and the other fixes kept: Hollowfen 37 the Clockwork won (11:27), Kestrel Rise 41 the Brood won (13:15).
   The early Clock Soldiers are worth their cost against the Brood: **C1 is reverted** (scripts/ai_optimal.gd is as on
   main). A human coach's lesson too: the "wasted" rush was the pressure that kept the Brood at home.
2. **The push goes out into the Brood's wave at its own door** (Greenhold 11, Clockwork P1, 8:44; picture
   `r2_g11w0_0844_push_into_wave.jpg`): "goes out: worth 2,420 against the 1,822 it reckons (a report 0 s old)", as 56
   supply of Raptors reached the base; it met them in the open and "pulls back (it has lost 1,555 of the 2,420)" 12 s
   later. *Decision:* `ai_cw_army.may_launch` does not look at an army at its door. *Fix C4.*
3. **Called home, the push walked into the raid and died** (Dune Sea 23, Clockwork P1, 11:02-12:04; picture
   `r2_d23w0_1110_push_far_out_when_called.jpg`, the push deep in the Brood's land at 11:10): C3 turned it round, but
   `_retreat` walks it home on plain moves (it does not shoot) for up to 90 s; the push of 3,050 met the raid of 2,120 on
   the way and was lost to the last soldier (84 units by 12:04). *Fix C5.*
4. **The counter went out too small** (Greenhold 11, 12:03): 950 "against the 135 it has seen alive lately" while the
   Brood had 85 supply coming at 12:16 (it pulled back unharmed). *Fix: the counter's floor.*
5. **A stuck written build** (Kestrel Rise 41, Clockwork P2, the Pendulums picked at 1:51; picture
   `r2_k41w1_0802_stuck_build_560_army.jpg`): "finds no room for a Heavy Works by its Mainsprings"; the steps after the
   Heavy Works waited for it and the bank went 618 -> 4,545 from 5:00 to 10:04 with the army at 560. A build switched
   from the common opening has no time cap (`_bo_cap_t`), and nothing noticed. *Fix C6.*

### Coach's notes: the Brood

1. **Its Rush pays when it is not answered** (Hollowfen 37, Kestrel Rise 41): the waves after it were its biggest yet.
2. **The pack** brings the wave in at once; the Clockwork's armies at home lost more to them (Hollowfen 37 6:55: 1,625
   gone in 25 s). Kept: it is the Brood playing better.

### Fixes after round 2

- **C1 reverted** (see above).
- **C4, no push into a wave at the door** (`ai_cw_army._wave_at_door`, new; one line in `may_launch`): against the Brood
  the push does not go while an enemy army worth 300 or more is in sight within 900 px of its buildings; the army meets it
  on its gears, then C2 counters.
- **C5, turn home fighting** (in `ai_cw_push._brood_raid_home`): the push recalled by raiders is not a failed push: every
  unit attack-moves at the raid (the Great Winder walks) and the army's whole-army defence takes them over at once; no
  "need_up", no AFTER_FAIL.
- **The counter's floor** (`_counter_ok`): also at least 0.7 of the reckoning's table for that minute (1,900 at 12:00).
- **C6, a stuck build hands over** (`AIClockwork._stuck_hand_over`, new; one line in `_build_up`): against the Brood, a
  written build that has done no step for 60 s with 1,000 cogs or more in the bank ends; the shared rules play on.
  `-- cvbstuck:off`.

## Round 3 (C1 reverted; C2-C6, B1)

Results: Greenhold 11 **Clockwork won 13:40** (P1) and draw, the Brood ahead (income 23,105 to 13,141); Dune Sea 23
**Clockwork won 12:14** (P1) and **Clockwork won 10:23** (P2); Hollowfen 37 **Clockwork won 12:45**; Kestrel Rise 41 draw
(even). (One game per seed: the qa study found the same seed agrees with itself about 2 times in 3. The batch decides.)

### What worked

- **C4** held the push home 7 times in 6 games ("holds at its gathering point: a Brood army of 600 is at its door; it
  meets it on its gears first"), and **C2** then countered (Dune Sea 23, P2: "its defence killed 650, it goes out worth
  1,385 against the 332 it has seen alive lately"; the push committed and the Mother fell at 10:23).
- **C5** (Hollowfen 37, 7:4x): "turns home fighting: Brood raiders in the base (325 value, 140 at home)"; nothing lost on
  the way; push 3 went out 1:30 later and won the game.
- **B1**: the Brood's waves now arrive as one body (picture `r3_g11w1_0936_the_pack_arrives_together.jpg`, 66 Raptors at
  9:36): that wave beat the Clockwork's whole army of 2,395 at its own gears (it fell to 945 in 15 s) and killed 2,995.

### Coach's notes: the Brood

1. **The Mother dies on her nest** (Dune Sea 23 7:49-10:22, picture `r3_d23w1_1002_mother_falls_on_her_nest.jpg`; also
   Greenhold 11 and Hollowfen 37): the Clockwork's push of 1,455 stood at her nest for two and a half minutes, its Netters
   caught her and the creatures near her, her army there was 75-300. She stays rooted or fights on her leash; the computer
   never takes her away. Her expansions (rooted Mound Turtles 26-32 tiles out) were untouched. *Decision:* nothing in
   `AIBroodNew._nb_mother` / `BroodNew.mother_guard` ever moves her nest. *Fix B2.*
2. **A Sire alone into the push** (Dune Sea 23, 10:07: "defends with 1 (1 tyrannosaur, 150) against 1,455 at the Mother").
   `_nb_sires_needed` sends every Sire when the threat at her is big and the army small, the very case they cannot win.
   *Fix with B2:* while she moves house her Sires go with her.

### Coach's notes: the Clockwork

1. **The main runs dry and the new Clocktowers get no presses** (Greenhold 11, P2: the main's brass spent at 9:10, picture
   `r3_g11w1_1000_main_spent_no_new_presses.jpg`; one press at 9:16, the next at 11:46 although Clocktowers finished at
   8:32 and 9:58; income 9,000 at 9:19 and 9,958 at 12:05). Its army had just been beaten (9:37) and every cog went into
   soldiers. This is the shared economy's (AI._drive_spot, AI._hall_first; clockwork-ai-v2's dry-land rules) and the
   mirror's too: **not changed here**, written up for the owner and the clockwork-v-clockwork job.
2. **Its army at home loses to the pack** (the same game, 9:37): 29 units on their gears against 66 Raptors arriving at
   once. Met as one body, Raptors with Pack Hunt beat Clock Soldiers. The Pendulums (the anti-swarm machine) were 0-2 in
   these armies: written up below (open questions).

### Fix after round 3

- **B2, the Mother moves house** (`AIBroodNew._nb_mother_moves`, new; one line in `_nb_mother`, one in
  `_nb_sires_needed`): against the Clockwork, armed enemies worth 600 or more within 14 tiles of her and her warriors and
  Sires there worth less than half of that: she gets up and walks to her expansion farthest from the push with no enemy
  seen within 18 tiles of it; her nest moves there (`_q_guard["home"]`) and she roots again once it is calm. Once per
  120 s. Her Sires are not "needed" in the defence while she moves (they keep to her). `-- nbmove:off`.

## Round 4 (B2 added)

Results: Greenhold 11 draw, the Clockwork far ahead (army 2,780 to 300) and draw, the Brood far ahead (the Clockwork 0
army); Dune Sea 23 **Clockwork won 12:05** (P1) and draw, the Clockwork ahead; Hollowfen 37 draw, the Brood ahead;
Kestrel Rise 41 draw, even.

### What worked

- **B2**: "the Mother moves house: a push of 1,410 at her nest against 575 of hers; she goes to her ground 22 tiles away"
  (Dune Sea 23 at 10:49, picture `r4_d23w0_1055_the_mother_moves_house.jpg`: she walks off with 15 eggs while the push
  fights at her old nest) and Greenhold 11 at 13:55 (she lived to 15:00 where round 3's fell at 13:40). On Dune Sea she
  bought 76 s; the push found her again.

### Coach's notes: the Clockwork

1. **The economy collapses at about 9:00** (Greenhold 11, Clockwork P2: income 9,000 at 9:19 and 10,360 at 15:00; the
   Brood out-earned it 22,170 to 10,360 and razed it). Measured in the "before" batch, the Clockwork's cogs a minute fell
   from 1,400-1,650 to 0-430 at 9:00-10:00 in 4 of 16 games (Greenhold, Twin Fords, Frostfang, Dune Sea, all with the
   Clockwork as P2) with 27-30 Winders alive. A dump of the Clockwork's halls and presses at 8:00 (Greenhold 11, P2):
   four Cog Presses on the main at 9% brass, none by the natural at 83% (it had only Mainsprings). Its first press for the
   natural ("press_new" at 3:23) went by the old Clocktower: the Brood's rush stood at the natural then (`AICwEco._press_new`
   skips a Clocktower with an enemy within 360 px); every later press went by the hall nearest the main
   (`AI._drive_spot`). At 9:00 the main was spent, 15 Winders stood idle, and new presses came one at a time while every
   cog went to the army the Brood kept killing. *Fix C7.*
2. **A counter into the swamp** (Hollowfen 37, 12:43, picture `r4_h37w0_1324_counter_into_the_swamp.jpg`): after a held
   wave ("its defence killed 2,025") the push of 3,155 marched for the Brood's main and met 50 fresh Raptors on its swamp
   at 13:24: "lost 1,940 of 3,155, killed 450". The Brood rebuilds fast from her eggs; what it saw "alive lately" (308)
   was not what was there. Not changed (the counter won the other games where it went: Dune Sea 23 round 3, Greenhold 11
   rounds 2 and 4); written down as an open question.
3. **The recall costs Winders** (the same game, 11:21): the push turned home fighting from far out; the Brood's 875 at the
   base killed 13 Winders before it came. C5 saves the push, not the Winders: the guard at home is the answer, open.

### Fix after round 4

- **C7, presses where the brass is** (`AIClockwork._drive_spot`, an override, and `_press_by_brass`, new): against the
  Brood a new Cog Press goes by the built Clocktower with the most brass left for each press it already has. In the same
  dump with C7 the natural had its press by 8:00 and the third Clocktower one by 9:00; income 10,478 at 10:00 and 11,238 at
  11:00 (before: 9,371 and 10,063). `-- cvbpress:off`.

## Round 5 (C7 added)

Results: Greenhold 11 draw, the Clockwork ahead (army 2,155 to 600) and **Brood won 13:39** (Clockwork P2); Dune Sea 23
two draws, the Brood far ahead in both (the Clockwork's army 0 and 70 at 15:00); Hollowfen 37 **Clockwork won 12:55**;
Kestrel Rise 41 **Clockwork won 14:44** (P2; round 1 a Brood-led draw, round 2 a Brood win).

### What worked

- **C7**: Greenhold 11, Clockwork P2, income 9,235 at 9:04 and 11,572 at 11:04 (round 4, the same seat: 9,000 -> 9,419,
  flat). The economy no longer stops when the main runs dry.

### Coach's notes: the Clockwork

1. **A push that pulls back is run down** (Greenhold 11, Clockwork P2, 10:49-12:04; pictures
   `r5_g11w1_1102_push_walks_home_in_a_column.jpg` and `r5_g11w1_1132_the_raptors_catch_it_at_home.jpg`): "pulls back (the
   enemy's army comes, worth 2,850 against its 1,960)"; it walked home on plain moves in a column, the Raptors (faster than
   anything it has) caught it on the way and at its third Clocktower; by 12:04 its army was 270 and 19 Winders had died,
   and the Brood razed it at 13:39. A human does not turn his back on Zerglings. *Decision:* `ai_cw_push._go_back`
   (plain moves home for up to 90 s). *Fix C8.*
2. **Counters into the Brood's land lose** (Dune Sea 23, Clockwork P1, 8:56: "counter-attacks ... worth 1,790 against
   the 188 it has seen alive lately", then "pulls back (it has lost 1,305 of the 2,000 ...), killed 250"). With round 4's
   Hollowfen counter that is 2 bad counters of 8 seen in the films (4 good, 2 even). Open question below.

### Fix after round 5

- **C8, falling back fighting** (`ai_cw_push._fall_back_fighting`, new; one line in `_go_back`): against the Brood a
  pulling-back push unit with an armed enemy (not rooted) within 180 px walks home on an ATTACK-move (it turns and fights
  what catches it); with none near it walks on a plain move again. `-- cvbback:off`.
- Before and after at the same moment: `ba_d23w0_1000_base_round1_vs_round3.jpg` (Dune Sea 23, Clockwork P1, its main at
  10:00): round 1, "WINDERS 0/5" at every press while the push was out; round 3 (C3-C5), the presses manned and the
  push back in time.
- One more film of the lost seed with C8 (Greenhold 11, Clockwork P2; "round 6"): a draw, even (income 16,854 to 15,956,
  army 2,305 to 2,075), its push out at 7:11 came back at 11:39 having killed 1,905 for 1,850, and it countered at 14:02.

## The measuring batch

Hard Clockwork OPTIMAL against Hard Brood OPTIMAL, to 15:00, 8 maps of different shapes (Greenhold, Dune Sea, Hollowfen,
Kestrel Rise, Redrock Canyon, Twin Fords, Frostfang, Cinder Steps), both start slots, fixed seeds (3300 + 7 x the map's
index). "Before" is main at 0.33.16 (a worktree), "after" this branch. Won or led: won, or led a draw (income earned +
2 x army value at the end 10% ahead, as docs/brood_nerf_study.md). Halls lost: the Clockwork's Clocktowers; the Brood's
grounds lost (qa_match.gd's events).
`python3 tools/study/cvb_coach.py run OUT --data DATA [--root DIR] [--set main|other]`, `... report DATA`.
Data: docs/clockwork-v-brood-coach/data/ (result.json and the AI STORY per game).

| game | before | after |
|---|---|---|
| Cinder Steps, Clockwork P1 | draw, CW led | draw, BR led |
| Cinder Steps, Clockwork P2 | draw, even | draw, even |
| Dune Sea, CW P1 | draw, BR led | draw, CW led |
| Dune Sea, CW P2 | BR won 13:03 | BR won 14:22 |
| Frostfang, CW P1 | draw, BR led | **CW won 10:29** |
| Frostfang, CW P2 | BR won 12:53 | draw, CW led |
| Greenhold, CW P1 | BR won 9:11 | draw, CW led |
| Greenhold, CW P2 | draw, BR led | draw, CW led |
| Hollowfen, CW P1 | CW won 14:58 | CW won 10:53 |
| Hollowfen, CW P2 | draw, CW led | draw, CW led |
| Kestrel Rise, CW P1 | BR won 13:48 | BR won 8:15 |
| Kestrel Rise, CW P2 | draw, CW led | BR won 14:24 |
| Redrock Canyon, CW P1 | BR won 13:51 | BR won 14:14 |
| Redrock Canyon, CW P2 | BR won 10:26 | **CW won 14:33** |
| Twin Fords, CW P1 | CW won 12:52 | CW won 6:39 |
| Twin Fords, CW P2 | draw, CW led | BR won 12:59 |
| **the Clockwork** | **2-8-6, won or led 6** | **4-7-5, won or led 9** |

- **The Clockwork wins and leads more** (9 of 16 against 6) and loses fewer (5 against 6); the Brood loses more of its
  ground (17 against 10) and the Clockwork fewer halls (20 against 22). Decided games 9 (8), 50 s shorter.
- **The Clockwork's economy holds after 9:00**: its income at 10:00 10,209 (9,763); its cogs a minute did not collapse at
  9:00-10:00 in any after game with its Winders alive (before: 4 of 16, C7). Its army at 8:00 1,375 (1,090).
- **The Brood earns more too** (5,426 at 8:00 against 4,742; 9,579 at 10:00 against 7,574): it is not weaker for the
  Clockwork's fixes; its waves arrive together (B1) and its losses now come late (four of its five wins after 12:59).
- Per game the noise is large (Twin Fords P1: a win at 6:39 in the batch, at 14:31 when played again); 16 games say the
  direction, not the size.

### The other matchups (no worse)

Two games each, Greenhold and Dune Sea, the sides swapped between them, Hard OPTIMAL. Every change here is gated on a
Clockwork-v-Brood pairing, so these should play as before up to noise:

| pairing, map (P1 v P2) | before | after |
|---|---|---|
| Clockwork v Crown, Greenhold | Clockwork won 10:04 | Clockwork won 12:12 |
| Crown v Clockwork, Dune Sea | Crown won 14:41 | Crown won 13:26 |
| Brood v Crown, Greenhold | Brood won 12:06 | Brood won 13:35 |
| Crown v Brood, Dune Sea | Brood won 10:16 | Brood won 13:05 |
| Clockwork mirror, Greenhold | P1 won 12:05 | draw, P1 led |
| Clockwork mirror, Dune Sea | draw, P1 led | P1 won 13:35 |
| Brood mirror, Greenhold | draw, P2 led | P2 won 14:35 |
| Brood mirror, Dune Sea | P2 won 12:22 | draw, P2 led |

The same winner or leader in all eight; nothing got worse.

## Tests

Run on this branch: test_clockwork_army (check:1), test_clockwork_home (check:1), test_clockwork_builds_b, test_ai_harass,
test_great_winder, test_ai_optimal, test_cw_air_ai, test_ai_expand, test_brood_new, test_brood_new_defence,
test_brood_ai_defend, test_brood_builds, test_ai_brood, test_files, test_i18n. All pass but two, which fail the same way on
main at 0.33.16 (run there too): test_great_winder (3 checks: "a wreck with its own soldiers crowding round it is still
swept", "it is sent to the army", "and follows it when it moves") and test_brood_new_defence ([rooted] muskets: the Mother
dies). Neither touches a change of this job (the Great Winder is not in any fix here; the defence test is against the
Crown's muskets, and B2 only acts against the Clockwork).

## Shared functions changed (for the merges)

Every fix is NEW code in a new function; the shared functions got one-line hooks:

| file | function | the change | gate |
|---|---|---|---|
| scripts/ai_cw_army.gd | `tick` | keeps `_defend`'s result in a variable and calls `_held_note()` | (the note is cheap; acts only via `_counter_ok`) |
| scripts/ai_cw_army.gd | `may_launch` | `if _wave_at_door(): return false` and `if _counter_ok(mine): return true`, after `_note_retreat()` | enemy is the Brood |
| scripts/ai_cw_push.gd | `_should_retreat` | `if _brood_raid_home(): return true` before the "base is attacked" rule | enemy is the Brood |
| scripts/ai_cw_push.gd | `_go_back` | `if _fall_back_fighting(u, home): continue` before the plain move | enemy is the Brood |
| scripts/ai_clockwork.gd | `_build_up` | `if bo_on and _stuck_hand_over(): return` after the dry-land hand-over | enemy is the Brood |
| scripts/ai_clockwork.gd | `_drive_spot` (new override of AI's) | a Cog Press by `_press_by_brass()`, else `super` | enemy is the Brood |
| scripts/ai_brood_new.gd | `_nb_army` | `_nb_close_start(first_rush)` after the wave's orders | enemy is the Clockwork |
| scripts/ai_brood_new.gd | `_nb_wave_tick` | `if _closing and _nb_close_ranks(): ... return` after the written build's block | enemy is the Clockwork |
| scripts/ai_brood_new.gd | `_wave_end_nb` | `_closing = false` | |
| scripts/ai_brood_new.gd | `_nb_mother` | `_nb_mother_moves(q)` before `mother_guard` | enemy is the Clockwork |
| scripts/ai_brood_new.gd | `_nb_sires_needed` | `false` while the Mother is moving house | (only set against the Clockwork) |
| tools/shot_ai_match.gd | `_initialize`, `_process`, `_finish` | new args `pa:` `pb:` `every:` (stats, army pictures, the AI STORY); the Brood's "base" picture at her Mother | additive |

scripts/ai_optimal.gd is unchanged (C1 was reverted). New tool: tools/study/cvb_coach.py. Every fix has an off switch
(`-- cvbcounter:off`, `cvbhome:off`, `cvbstuck:off`, `cvbpress:off`, `cvbback:off`, `nbpack:off`, `nbmove:off`; C4 goes
with `cvbcounter:off`).

## What is still wrong

1. **The Clockwork's counters into the Brood's land** lose now and then (2 of 8 in the films: Hollowfen 37 round 4,
   Dune Sea 23 round 5): what it has seen alive lately is not what the Mother lays in a minute on her swamp. A counter to
   the Brood's nearest expansion (its rooted turtles away from the Mother) rather than its main would be the next try.
2. **Winders die while the push turns home** (Hollowfen 37 round 4: 13). C5 saves the push; the base needs a guard that
   stays (a few soldiers on the worker line) when the push goes out against the Brood. Not tried.
3. **The Clockwork's army at home loses to the pack** (Greenhold 11 round 3: 2,395 to 66 Raptors with Pack Hunt in 15 s).
   With B1 the Brood's waves are a real threat; the Clockwork's answer (Pendulums) rarely comes in Balanced (0-2 a game).
4. **The Brood's biomass piles up** to 1,000-2,000 for minutes in some games (Dune Sea 23 round 1 from 8:34; Hollowfen 37
   round 1 while the push stood at her nest). Her eggs are the limit (one egg every few seconds, faster with Sires near
   and expansions); not looked into further.
5. **A shared economy finding for the mirror job**: the opening's `press_new` step skips a Clocktower with an enemy
   within 360 px and lays the press by the old one; with the Brood's rush at the natural at 3:20 every early press went by
   the main. C7 fixes the later presses against the Brood only; the step itself and `AI._drive_spot` for the other
   matchups are unchanged.

## Claude's choices for the owner to confirm

1. **C1 reverted**: against the Brood the Clockwork still reads the Brood's 0:00 turtle as GREEDY and picks the Clock
   Soldier rush, then Balanced when the Raptors come. The films showed the rush's early soldiers are what turn the Brood
   to Balanced and keep its waves small. The read's wording ("a second base and little army") is the same untruth the
   Crown study found; only the pick was tried.
2. **The counter** (C2): 75 s after a defence that killed 600 or more, worth 1.4 times the enemy army seen alive lately,
   at least 900 and 0.7 of the reckoning's table for that minute. Not before a wave at the door (C4: 300 or more within
   900 px of its buildings).
3. **The recall** (C3/C5): a raid worth 300 or more that the armed units at home do not match, the push 1,000 px or more
   out. The push turns round on attack-moves and the army's whole-army defence takes it over: no "need_up", no AFTER_FAIL.
4. **The stuck build** (C6): 60 s with no step and 1,000 cogs banked. Against the Brood only (the mirror job may want it
   too).
5. **Presses by brass** (C7) against the Brood only; it would help every matchup in the same way (the main dries at about
   9:00 everywhere).
6. **Falling back fighting** (C8): an armed enemy within 180 px turns that unit's walk home into an attack-move.
7. **The pack** (B1): units more than 5 tiles ahead of the bulk (70th percentile) hold until contact (an armed enemy or a
   building within 12 tiles of the leaders, 14 tiles from the goal, or 75 s). Not on a rush's first wave, not for the
   written builds (they march their own way), only against the Clockwork. The Crown would face it too if it were turned
   on there.
8. **The Mother moves house** (B2): a push worth 600 or more within 14 tiles of her and her army there under half of it;
   to the expansion farthest from the push with no enemy within 18 tiles; once every 120 s. Her swamp goes with her, so
   the Rootmaws by the old nest lose theirs. This is the "Queen safety" the owner named; it changes how the Brood loses
   (later, and not always), never a number.
