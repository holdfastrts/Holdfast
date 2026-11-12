# Clockwork v Brood, coached (job clockwork-v-brood-coach)

Short sentences, to be read aloud.

The owner (2026-11-11 22:35) wants every matchup coached and filmed with the same scrutiny as the Crown v Brood job. This
job is the Clockwork against the Brood: Hard OPTIMAL against Hard OPTIMAL, filmed, watched closely, each mistake named with
its time and a picture, the decision behind it fixed, the same seed played again. Both computers are coached. No unit,
building or economy number was changed: every fix is a decision of a computer.

(This document grows round by round; the numbers and the summary come at the end of the job.)

## How the games are filmed

- `tools/shot_ai_match.gd` (extended, additive): `pa:` / `pb:` set the plans (OPTIMAL here), `every:60` adds a picture of
  each side's army (its densest group) every 60 s, a stats line per side every 15 s (`stats.txt`: income earned, bank,
  workers, army value and kinds, rooted creatures, halls, supply, units and buildings lost, where the army stands, the
  Clockwork's push phase) and the AI STORY (`story.txt`). The fights and the bases are filmed as before.
  `xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_ai_match.gd -- a:clockwork b:brood pa:optimal pb:optimal map:greenhold seed:11 swap:0 out:DIR end:900 every:60`
- The six filmed seeds (both start slots on the first two maps): Greenhold 11 (both slots), Dune Sea 23 (both slots),
  Hollowfen 37 (Clockwork P1), Kestrel Rise 41 (Clockwork P2). Every round plays the same six.
- `tools/study/cvb_coach.py`: the measuring batch (16 games, tools/qa_match.gd, headless) and its report.
- Pictures: `docs/shots/clockwork-v-brood-coach/` (jpg, 640 wide). Names: round, map/seed/slot, game clock, what.

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
