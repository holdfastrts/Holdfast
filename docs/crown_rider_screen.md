# crown-rider-screen: Horsemen ahead of the Crown's line

The owner (2026-11-12 08:03): "This line movement work is great and also should be paired with Horsemen on front
scouting." crown-line-fight (0.33.24, docs/crown_line_fight.md) made the Crown computer's waves form the player's
drag-a-line with the guns behind it, but found that most fights still began unformed: the line forms only on what the
Crown knows (an enemy in sight or seen in the last 20 s), a musket sees 8 tiles and reaches 6, so the enemy army was
first seen at contact. It named the rider screen as the answer.

Rules followed: docs/design_principles.md 1 (fair: the computer uses its riders as a player would and knows only what they
see) and 4 (scouting reveals strategy; battles with formed lines). The owner's Crown rules are untouched (the walled
natural with its gate toward the ramp and the army at the gate, 3 Field Cannons before any Mortar, the Foundry before the
second Barracks, the OPTIMAL opening). No unit, building or economy number was changed. The Horseman rush, the raids
(Horsemen, Dragoons) and the Balloon harass keep their own riders and play. The Clockwork and Brood computers are
untouched (everything is in `AICrown`; the shared code only calls in).

**Switch:** `-- screen:off` plays as before (no screen, no picket, no riders trained for them).

## What was built (`scripts/ai_crown_screen.gd`, class `AICrownScreen`)

1. **The screen ahead.** While a Crown wave marches (the main army's wave with a line to form: not a riders' wave, not
   the Horseman rush), 2 Horsemen ride for it (3 from 20 supply, 4 from 40): its own Horsemen first, then the free ones
   at home, then the map loop's rider scouts (AICrownHold: while a wave's screen is short the loop takes no new scout).
   The lead rides 620 px ahead of the wave's head along its road (`Game.find_path` to the wave's target, looked up every
   3 s), two flankers 300 px ahead and 430 px out to each side, a fourth beside the lead. They never fight the enemy
   army: each keeps 360 px from every enemy soldier known (its spot pulled back along the road), and backs off toward the
   wave from anything that can catch it (as fast as 85% of a Horseman, within 300 px), shoot it (a reach of 80+, within
   its reach + 110 px) or stands next to it, and from a Ratchet Turret's reach. A rider below 30% of its hit points
   leaves the screen; none below 45% is taken.
2. **The line knows what the screen sees.** `AICrownLine._known` takes the riders as the wave's eyes: an armed enemy in
   sight within 300 px of a screen rider (a Horseman sees 256) counts as "ahead" while it is within 1,300 px of the
   wave's body (the line's own eyes reach 760), and is remembered 20 s where it was seen, as before. So the line HALTS
   and FORMS on the screen's sighting, out of reach and facing the enemy (the line's own rules: 330 px from the nearest
   enemy, never ahead of its head; then it steps on with its guns). The log says so: "forms its line before the enemy
   army ahead (480): 10 muskets in 1 rank, 2 guns behind (its screen saw it 555 px off)".
3. **At contact** (the line's fight, or its falling back) the riders pull back: the flankers to beyond the line's ends,
   a little behind the front rank; the lead behind the guns, off to one side; a rider in front of the line rides out
   round its end first (never through its fire). Then the FLANK WORK, each from its post on a 620 px leash: what comes
   at our guns first, then enemy workers, the hurt (under 40%) and the stragglers and scouts alone; never a prey with two
   enemies beside it that can catch or shoot a rider, never one in front of the muskets. Won the field, the riders take
   their places on the screen again.
4. **The picket at home.** While the army is at home (and not in the Horseman rush), one free Horseman stands 520 px
   forward of the army's post (the natural's gate post once there is one, else the cliff edge's line, else the ramp's
   top) along the road toward the enemy's base, on HOLD. When it sees an armed force worth 150 or more it says so in the
   log, rides back to the post (behind the gate post's line, or into the main behind the ramp post) and stays back while
   the enemy is about (25 s at least); anything that can catch or shoot it sends it back at once. When a wave goes out
   short of riders, the picket rides with it.
5. **Riders for it.** The Barracks trains a Horseman for the screen and the picket (the screen's own training, every
   second, with 40 gold to spare over its price, not while the hall plan keeps its gold or the enemy is at home) while
   fewer than 3 sound Horsemen (45%+) are free for them (the loop's scouts count) and fewer than 5 are alive and in
   training, once the plan has a Horse Breeder, 4:00 has passed and the line has 8 supply of muskets. The shared
   training reaches its turn too, but it seldom does (the Barracks wait for the guns' gold, crown-hold).

The riders are out of the shared army's orders while on the screen or the picket (`AI._on_errand`), so the line, the
harass's strays and the micro leave them alone. The match log's new lines have AI STORY rows (`scripts/ai_story_lines.gd`,
pt and es in `tools/i18n/63_crown_screen.txt`): "'s wave sends 2 Horsemen ahead and to its flanks as a screen", "'s screen
pulls back to the line's flanks at contact", "'s screen rider rides down a worker on the flank", "'s screen rider is
lost", "sets a Horseman as a picket on the road 520 px out from its post", "'s picket sees a force coming (490: 7
soldiers) and rides back to the post".

## Tools

- `tools/film_line.gd` (crown-line-fight's film, extended; it changes no rule): every engagement in `engage.json` now has
  its WARNING (how long the enemy soldiers in it had been in the Crown's sight when it began: each enemy soldier's
  sighting starts when it comes into sight; `warn` is the median of those near the contact, `warn_first` the earliest,
  60 s at most), the line's state just before it (`prev_st`: form / step / set / advance / back = FORMED) and the seconds
  since the line was last laid; `screen.json` has the screen's counts per Crown side (riders sent, lost on the screen,
  pickets lost, the line formed on the screen's sightings, the picket's warnings, the flank work's rides, riders
  trained).
- `tools/study/crown_screen_report.py`: crown-line-fight's tables plus the screen's (away fights formed when they began,
  the warning, the trade, the screen's counts).
- `tools/test_crown_rider_screen.gd`: a marching wave sends its Horsemen ahead; a rider gets 250+ px ahead of the
  muskets; the screen sees an enemy army 1,100 px down the road and the line forms on it at least 4 s before contact;
  at contact the riders pull back (none in front of the muskets), none is lost; at home a picket stands 300+ px forward
  of the post toward the enemy, sees a force coming, warns and rides back.

## The sessions (coached)

(Times are game time; P1 is the first start spot. The games are not deterministic: a replay of a seed is the same start,
not the same game. Main = 0.33.24, the line without the screen.)

### Round 1: Greenhold 1101 (Crown v Clockwork), Kestrel Rise 1130 (v Brood), the first cut

- **Greenhold 1101, 6:44:** the first wave went out with one Horseman, and he was the loop's scout, hurt (he had been
  handed to the harass at 5:09 and came home at 5:55): the screen had nobody, the wave met the Clock Soldiers at 7:01
  unformed. No rider was trained for the screen in 12 minutes: the shared training reaches the screen's turn only after
  a random pick and the scout's, and the Barracks were held for the guns' gold (crown-hold's first Field Cannons) most of
  the time. **Fix:** the screen trains its own rider (point 5).
- **Kestrel Rise 1130, 3:04:** the picket took one of the three Horsemen the Rush plan was gathering for its Horseman
  rush (4:51). **Fix:** no picket during the rush (as the loop's scouts: none then).
- A counter (`pulled`) counted contacts with no rider out (91 in one game). Fixed.

### Round 2: Greenhold 1103 (the mirror), Dune Sea 1107, Kestrel Rise 1131 (v Clockwork)

- **Greenhold 1103 (mirror), P2 11:41-11:45:** the wave sent 2 riders ahead; 4 s later "forms its line before the enemy
  army ahead (345): 10 muskets in 1 rank, 1 gun behind (its screen saw it 717 px off)". P1's wave (7:07) sent 3 riders,
  but at 7:12 it met an enemy scout party at a turn of the road before the screen was out in front.
- **The picket "warned" for one enemy scout** (115: 1 soldier) six times in the mirror: anything that could catch it sent
  it back with a warning. **Fix:** a warning only for a force worth 150 or more (a scout sends it back without one).
- **Every game:** a hurt rider (under 60%) was never taken, and most of the Crown's Horsemen were hurt from the harass.
  **Fix:** a rider from 45% may screen (it keeps out of reach: it is there to see), and leaves the screen under 30%.
- **The loop's scout and the screen fought over the newest rider** (7:46: "sends a Horseman to scout the map" and "the
  wave sends 1 Horseman ... as a screen" in the same second). **Fix:** the loop takes no new scout while a wave's screen
  is short (`AICrown.screen_short`).

### Round 3: Dune Sea 1107 (Crown v Clockwork), filmed, main against the screen

The key picture. On main the wave walked into the Clockwork's Clocktower at 8:39-8:40 strung out, its three guns far back
on the left ("meets the enemy before its line is formed: 6 muskets deploy into a line through the 4 already firing").
With the screen (8:13): "forms its line before the enemy army ahead (450): 11 muskets in 1 rank, 3 guns behind (its screen
saw it 334 px off)"; at 8:15 the fight began with the line formed: 9 of its 11 muskets fired in the first 5 s, 1,615
killed for 360. The riders worked the flank (8:15 "rides down a worker on the flank", 9:05 a hurt Clock Soldier, 9:29 a
hurt Springer); 12 flank rides, no rider lost.
![](shots/crown_rider_screen/key_dunesea1107_before_after.jpg)

But at 8:17 (the lower picture) the lead rider, riding back from ahead, stood in front of the line's muskets, in their
fire. **Fix:** a rider in front of the line rides out round its end first, then to its post.

### Round 4: Kestrel Rise 1133 (the mirror), Hollowfen 1151 (v Brood), Ashford Crossing 1128 (v Clockwork)

- **Ashford Crossing 1128, P2 8:08-8:37:** the wave sent its rider at once; at 8:31 "forms its line before the enemy army
  ahead (270): 10 muskets in 1 rank, 2 guns behind (its screen saw it 799 px off)", contact at 8:37 (6 s): 8 of 10
  muskets fired in the first 5 s, but the Clockwork army was the bigger one (590 killed for 1,055) and the line fell back
  in order at 8:45.
- **Kestrel Rise 1133 (mirror), P1 10:27:** formed on the screen's sighting 476 px off; 17 flank rides in the game (the
  enemy's workers, hurt Musketeers, two Horsemen), no rider lost. P2's picket stood on the road from its ramp from 5:49,
  but P1's three attacks (8:43, 9:10, 10:26) came at its natural from the other side: it warned once (10:58). One picket
  on one road (see "What is still wrong").
- **Hollowfen 1151 (v Brood):** the Horseman rush succeeded (5:10), the picket stood from 5:51 and warned at 9:34 ("a
  force coming (150: 6 soldiers)"); the Brood came to the walled natural at 9:36, the fight began with 2.5 s of warning
  by the measure (17.5 s for the first enemy seen) and the Crown won it, 1,165 killed for 230. No Crown wave went out in
  12 minutes (the Brood army was reckoned bigger), so no screen.

### Round 5: the first after batch, cut at 18 games; Dune Sea 1109 (the mirror) filmed

The first after batch (the code of round 4) was looked at game by game after 18 games (its data: the measure of the
first cut, below). The screen went out with most waves (25 riders sent in the 9 Clockwork and mirror games looked at, none
lost), but the line formed on its sighting in only 2 of them. Dune Sea 1109 (the mirror), P2's second wave, filmed every
5 s from 9:40: its two riders backed off "from the enemy (1 near)" at 9:47, 9:55 and 10:06, the line never formed, and at
10:06 the wave walked into P1's ramp post unformed, 13 muskets deploying under its fire: 600 lost for 0, falling back at
10:39. The screen had seen two or three of P1's Musketeers at the ramp's gate (the rest of the ramp post's line stood
behind the lip, out of a rider's sight from below), worth under a quarter of the wave: the line's rule for an army ahead
(SEE_SHARE).
![](shots/crown_rider_screen/r5_dunesea1109_0955-1005_into_the_gate_unformed.jpg)

**Fixes:** what the screen sees counts from 8% of the wave (100 at least: `AICrownLine.SCREEN_SHARE`, `SCREEN_MIN`): a few
seen up ahead are often the front of more. Replayed (headless, the same start): P2's first wave formed at 7:26 "before the
enemy army ahead (115) ... (its screen saw it 975 px off)". And the picket rode back from the first enemy musket without a
warning (a musket's reach, 190 + 110 px, is longer than a Horseman's sight, 256): two soldiers that can catch or shoot it
are now a warning too. The after batch was started again with this code.

The Dune Sea 1107 screen at work (the after picture above, every 10 s from 8:00):
![](shots/crown_rider_screen/after_dunesea1107_0800-0850.gif)

