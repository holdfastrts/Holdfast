# The Brood computer defends as a swarm (0.25.27)

From the owner's playtest of 2026-11-01 (docs/playtests/ai_clock_v_brood_2026-11-01: a HARD RUSH Clockwork against a
HARD ECONOMY Brood on Glimmerdeep, seed 123537401, v0.25.25). The owner: "Brood played well, but in the screenshot it
let a trickle of Raptors go by sight trigger instead of swarming the enemy with all the force. There were a few moments
also that it uprooted the Brood Mother with no reason. The Tyrant or just a Rootmaw could probably deal with an early
harass of 2 clock soldiers." And (corrected): a Rootmaw rooted at the expansion sat taking blows from one or two Clock
Soldiers; it should uproot and fight back if it wins, or uproot and back off if not, and root again once safe.

Code: scripts/ai_brood_new.gd (`_nb_defend`, `_nb_hold_rest`, `_nb_mother_up`, `_nb_maw_guard`, `_fight_wins`),
scripts/brood_new.gd (`mother_guard`'s "stay"). Only the Brood's files; the Crown and Clockwork computers are untouched.

## What was wrong

1. THE TRICKLE. The army at home stood IDLE at the staging point, and an idle creature picks its own fight with
   anything in sight (Unit "idle": `_pick_target`, 320 px leash). Raptors went one by one as each saw a Clock Soldier.
   On top of that, every think sent each idle creature at home (each Raptor as it hatched) on attack-move toward the
   staging point or the threat, alone. Defence only started when an enemy was within 13 tiles of the Mother; a fight
   at the natural (where the alarm put the staging point) got no organised answer at all.
2. THE MOTHER GOT UP FOR TWO CLOCK SOLDIERS. `BroodNew.mother_guard` uprooted her whenever any ground enemy came within
   3 tiles of her body or struck her. Reproduced with tools/run_brood_ai_match.gd: at 3:06 two Clock Soldiers near her
   got her up; her swamp went with her and, two seconds later (`DRY_GRACE`), two Rootmaws lost their swamp and uprooted
   (the log's 3:08 and 3:10 lines and the sound log's uproot/root sounds from 3:03 to 3:47). No other code path uproots
   her: the computer never walks her off, and swamp and defence go through `mother_guard` only.
3. SMALL HARASS. The Tyrant Sire got up only for a big attack (`_nb_sires_needed`), so two Clock Soldiers before any
   Raptors were answered by nobody (or by the Mother, see 2).
4. ROOTED ROOTMAWS just took it: no rooted creature attacks (the owner's rule), and nothing got them up.

## What it does now

### The army at home holds a rally (no fights by sight)
Idle army creatures at home walk to the RALLY (the staging point, as before: the natural during an alarm) on a plain
move and HOLD there: they fight only what reaches their claws. Waves leave from there as before; creatures come home
from a wave the same way. (`_nb_hold_rest`)

### Enemies at home get a squad sized to them, sent all at once
Every think it looks at the enemies at home its creatures see: within 26 tiles of the Mother (`HOME_R`) or 9 tiles of
any of its rooted creatures (`SITE_R`: the expansions and their Rootmaws). Fighters only (not workers); flyers only when
it has Hatchlings. The group answered is the enemy nearest the Mother and every enemy within 10 tiles of it.
- A small harass (value up to 250, `SMALL_HARASS`: up to three Clock Soldiers or Musketeers): the nearest creatures
  until the fight is won on paper (`_fight_wins`: hits pooled, armour off each blow, each enemy killed in turn while
  the rest hit back; at most 60% of their health lost). With no warriors to spare and the harass within 22 tiles of
  the Mother, the TYRANT SIRE gets up for it (1,000 health, 42 a bite; not while he researches); he roots on his nest
  again once it is over.
- A bigger attack: the whole army at home, if it wins on paper (80% margin), or always when the fight is at the Mother
  (within 14 tiles of her: everything near her joins at once, the Sires too when the attack is big, as before).
- Too strong to meet away from the Mother: nobody goes. The rally moves to her far side from the attack and the army
  gathers there (a lost fight is lost ground, not the army).
- While the squad fights, creatures within 12 tiles of the fight (or by the Mother when the fight is at her) join at
  once; the others join from the rally only as a group (4 supply), unless the squad is losing. A squad losing away from
  the Mother is pulled back to her.
- Nothing left at home: the squad goes back to the rally (no chase across the map: a creature 14 tiles off the fight
  and outside home is called back).
- A wave out is called home when the attack at her is big and the creatures at home can't hold it (as before).

### The Mother gets up only for a real reason (`_nb_mother_up`)
Rooted she has 3 more armour and takes a quarter less: two Clock Soldiers take five minutes to bring her down. The
computer tells `mother_guard` to keep her rooted ("stay") unless one of these holds:
- "big": a real attack at her (250 value or more within 8 tiles of her body) that the army near her (14 tiles) does not
  match: she is the strongest fighter it has;
- "alone": she is under 80% health, enemies strike her and nobody of hers (army or Sire) fights them near her;
- "last": a last stand, under 40% health with enemies striking her.
Never for a scout, a lone raider, a small harass, flyers, or enemies only passing near. Up already with no reason
left, she roots again after 4 s with nobody at her (`MOTHER_STAY_CALM`). The player's Mother is never touched;
tools/test_brood_new_defence.gd (which calls `mother_guard` without "stay") behaves as before.

### A rooted Rootmaw under attack (`_nb_maw_guard`)
A rooted Rootmaw struck (or its grubs struck within 4 tiles of it) looks at the ground fighters within 6 tiles:
- it beats them on paper (uprooted, its armour off; 80% margin): it UPROOTS keeping its food (HAUL) and bites back,
  never more than 8 tiles from its spot; if the fight turns, it backs off;
- it does not: it uproots SPILLING its food (a pile its grubs collect later) so it runs at full speed (80, a Clock
  Soldier is 68) and backs off to the Mother's far side;
- either way it roots again on its own spot once nothing has been near it or its spot for 4 s (`MAW_SAFE`); after
  90 s away the normal Rootmaw logic finds it a spot.
One Clock Soldier or two: it fights (on paper it loses about 190 of its 450 health against two); three or more: it
backs off.

## Tests

tools/test_brood_ai_defend.gd (Glimmerdeep, the Brood computer on, the Clockwork computer off, soldiers put down by
hand): all pass on 0.25.27.
- swarm: 12 Raptors hold at the rally; 5 Clock Soldiers come in; all 12 sent in the same think, the soldiers die in
  10 s; afterwards all back at the rally, holding.
- mother: 2 Clock Soldiers strike the rooted Mother with nobody to answer: she stays rooted for 30 s (2,272 of 2,400
  health), no Rootmaw loses its swamp; a Tyrant Sire laid by hand gets up, kills both in 7 s, she never got up, he
  roots again.
- maw1: 1 Clock Soldier strikes a rooted Rootmaw: it uproots, kills it in 8 s (415 of 450 health left), roots again
  on its spot.
- maw4: 5 Clock Soldiers strike it: it uproots and backs off 8 tiles toward the Mother.

tools/run_brood_ai_match.gd (new): a computer Brood against a computer foe, headless, measuring the Mother's uproots,
the Rootmaws that lost their swamp, and LONE FIGHTS (army creatures fighting with fewer than 2 of their own fighting
within 5 tiles: the trickle) with each lone death and whether it was in a wave, in defence or on its own.

## AI v AI: the playtest's match (Glimmerdeep, seed 123537401, Clockwork Hard Rush v Brood Hard Economy)

| | 0.25.26 (before) | 0.25.27 |
|---|---|---|
| Mother uprooted | 1 (3:06, two Clock Soldiers) | 0 |
| Rootmaws lost their swamp | 2 (3:08, 3:10) | 0 |
| Brood food earned by 7:00 | 4,188 | 7,315 |
| Brood losses by 6:00 | 10 | 2 |
| lone deaths at home (by 6:00) | 4 (3:58, 4:31 x2, 5:31) | 2 (3:57, 4:00: the first Raptors beside the Tyrant Sire against the 3:47 wave) |
| result (run to 11:00) | Brood wins at 9:30, 20 lost | Brood wins at 9:45, 24 lost, 11,756 earned (9,267 before) |

The first Clockwork harass (2:57) now meets the Tyrant Sire, who sends both soldiers home; the 3:47 wave (3 Clock
Soldiers, then more) meets the Sire and the first Raptor while a struck Rootmaw backs off, and the Clockwork pulls its
wave back at 4:11 having lost 350 for 50. The lone deaths after 7:50 are in the Clockwork's base during the Brood's
own wave (Netters catching Raptors), not at home.

## Left open

- Waves: a creature in the Brood's own wave still fights by itself once it is in the enemy's base (attack-move), and
  Netters pick them off; the wave logic was not changed here.
- With the economy no longer set back at 3:00, the Economy Brood banks food (1,600 at 6:00, 3,000 at 7:00 in this
  match): her eggs, not food, hold it back until her stage 2. tools/test_ai_brood.gd (Balanced, Greenhold) fails
  "natural by 200 s" and the bank check on 0.25.26 and on 0.25.27 alike (known flaky timing; the bank's longest run
  is shorter now: 100 s against 207 s).
- The numbers (SMALL_HARASS 250, the margins, HOME_R 26, SITE_R 9) are first guesses for the owner to tune.
