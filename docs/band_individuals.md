# The Marching Band as individual musicians (job band-individuals, 0.37.0)

The owner's redesign (2026-11-14 02:01-02:08): no band unit; three musicians of their own who make a band by standing
together. The older write-ups stay in docs/marching_band.md (0.33.0, the 0.23.0 experiment) and docs/band_v2.md (0.36.0:
the walk-and-join structure, now gone, and the sound engine, which stays).

## What changed, in short

- **No band unit.** The Armoury trains three musicians, each a unit: the **Drummer** (the old band's unit id `band`
  becomes him, so old saves find him), the **Fifer** (`band_fifer`) and the **Piper** (`band_piper`).
- **Each musician is complete on his own**: his own ring (5 tiles), his own always-on buff (+5%), his own SOLO (+30%
  for 8 s) and his own solo cooldown (45 s). Drums: movement speed. Pipes: melee damage. Fife: reload (muskets,
  pistols, cannons, mortars; not a man out of shots). Same effects as before.
- **The same instrument never adds up.** Under two drummers a soldier gets the stronger drum only (each stat its
  strongest, as before, but per musician now).
- **A band forms by itself** when a Drummer, a Fifer and a Piper each stand within the others' rings. It is stronger:
  +8% each (was +5%), solos +40% for 10 s (was +30% for 8 s), one solo at a time in the band. It plays from one ring
  round the three of them (gold, with the word BAND under their feet). With extra musicians about, the closest set
  forms the band and the others stay lone. A band holds together until two of its three are more than 1.15 rings
  apart (so it doesn't flicker at the edge), then they are three lone musicians again.
- **Lone musicians play out of step.** Where two lone musicians' rings of DIFFERENT instruments overlap (and they are
  not a band), a soldier there gets only the stronger of their buffs (tie: drums, then fife, then pipes). Their rings
  turn dashed and say "out of step" over their heads; the soldier's marker for the dropped buff is grey and struck
  through, and his card says "(out of step: not counted)". Two lone drummers overlapping are not "out of step" (the same
  instrument simply never adds up).
- **The trade-off (kept)**: lone musicians cover more ground (three rings), a band is stronger but bunched (three men
  in one spot, one ring).

## The numbers (Claude's starting numbers, the owner's to tune; Defs.MARCHING_BAND and Defs.UNITS)

| | Drummer | Fifer | Piper |
|---|---|---|---|
| cost | 50 gold | **70 gold, no powder** (was 60 + 10 powder) | 75 gold |
| time | 15 s | 18 s (was 20) | 18 s (was 20) |
| supply | 1 | 1 (was 0) | 1 (was 0) |
| health | 40 | 35 | 35 |
| speed | 62 | 62 | 62 |

| | alone | in a band |
|---|---|---|
| always-on | +5% | +8% (`band_second`) |
| solo | +30% for 8 s | +40% for 10 s (`band_lead`, `band_solo`) |
| solo cooldown | 45 s from the solo's start | 45 s |
| ring | 5 tiles (160 px) round him | 5 tiles round the middle of the three |
| a band holds until | | two of them are 1.15 rings apart (`keep`) |

Health: the old band was 60 + 15 a musician (105 for all three); the three men now have 110 between them (40/35/35), a
little more because each can now be picked off alone. No "more per band" price rule.

## How it works (scripts/marching_band.gd)

- **One pass a pulse** (`MarchingBand.pass_tick`, every 0.25 s, run by the first musician that ticks): the bands form
  and break (`form_bands`, host only), the Fifer and the Piper keep their row beside their Drummer while he walks
  (`keep_rows`), the out-of-step marks (`mark_out_of_step`), and the buffs on everyone in a ring (`play_over` -> `mix`).
  An online guest and a replay run the same pass from the snapshot's state (they do not form bands themselves; the
  host's "b" decides), so their rings and markers match the host's.
- **A musician's state** (`Unit.band`, saved, in the online snapshot and the replay field as before): `id` his number on
  his side, `se` his solo's end, `cd` his cooldown, `b` his band (its Drummer's `id`; 0 lone).
- **A covered soldier** gets `band_mul` (speed, melee, reload), `band_until` (0.6 s linger) and `band_show` (what the
  markers and the card say: instrument, percent, flags band / solo / out of step).
- **The row**: when a band forms, idle Fifer and Piper step to 24 px either side of the Drummer; while the Drummer
  walks, his idle (or row-walking, or escorting) Fifer and Piper walk to their places beside where he is going; a group
  move with the whole band gives them their places beside his spot (`row_spots`, from `Game.group_move`), so they
  arrive and march as a row. A Fifer you order elsewhere goes there (if he leaves the ring, the band breaks).
- **In step**: a band's three take the same walk / idle frame from the game clock and bob together in a solo; a lone
  musician is shifted by his own offset (`step_offset`), so two lone ones visibly march out of step.

## Orders and the card

- **SOLO buttons** (DRUMS / FIFE / PIPES SOLO, the same labels and so the same hotkeys as before) show for each
  instrument in the selection. A plain press (or its key) makes ONE selected musician of that instrument play, the first
  one free; **Ctrl + press** (or Ctrl + key) makes every selected one of that instrument play. Each solo goes through
  the online funnel (`Unit.band_solo`) as before. The corner shows how many are free ("2/3") or the cooldown.
- **SELECT BAND** (the old JOIN BAND icon, `ab_band_join`): selects the whole band of each selected musician. Selecting
  one musician selects the man; a double-click selects his kind (as for any unit).
- **The card line**: "Alone: +5% movement speed (solo +30%) · 5 tiles" or "In a BAND: +8% ... · in step", "OUT OF STEP
  with another musician...", "SOLO: 7 s" / "solo again in 30 s".
- **A buffed soldier's card** adds what he gets, by source: "Band +8%: speed, reload, melee", "Fife SOLO, band +40%:
  reload", "Pipes +5%: melee (out of step: not counted)".
- Gone: RECRUIT FIFER / PIPER, JOIN BAND, the right-click JOIN, the walk to a band, the wait at the rally point. Their
  net commands (`band_recruit`, `band_hire`) stay as no-ops so old replays and old guests find them.

## The buff markers (the owner 02:08: "a percentage and an icon on top")

Over a buffed soldier's head: the instrument's small icon (the owner's SOLO icons shrunk to 10 px) and the percentage.
Buffs of the same size and kind share one number (a band's three icons and one "+8%"). Gold for a band, white alone,
bigger (13 px) and in the instrument's colour in a solo, grey and struck through when out of step. The enemy sees them
too (on any unit it can see).

**Settings > DISPLAY > BAND BUFF MARKS: ALWAYS / SELECTED / OFF. Claude's default: SELECTED**, which shows them on
the selected units, the unit under the cursor, and **everyone in a ring during a solo** (the moment worth telegraphing).
ALWAYS on a 20-man line at normal zoom is readable but busy (picture 5a), which is why it is not the default.

Pictures (tools/shot_marching_band.gd, docs/shots/marching_band/individuals/):

| | |
|---|---|
| `1_band_close.jpg` | a band of three side by side, selected: the gold ring round them, BAND, the card (the three SOLOs, SELECT BAND) |
| `2_lone_spread.jpg` | three lone musicians spread along a 30-man line: three plain rings in their colours (more ground covered) |
| `3_band_fife_solo.jpg` | the band's Fifer solos: the ring turns blue, everyone in it shows "+40%" big and blue beside the band's "+8%" |
| `4_out_of_step.jpg` | a lone Fifer and a lone Piper: dashed rings, "out of step" over them, the pipes' marker grey and struck through |
| `5a_markers_line_always.jpg` | ALWAYS, a 20-man line at normal zoom: three icons and "+8%" each |
| `5b_markers_line_selected.jpg` | SELECTED (the default): only the selected men show it |
| `5c_markers_close_and_card.jpg` | close up, one man selected: his card says "Band +8%: speed, reload, m..." |

## The sound (scripts/band_sound.gd): only WHO is heard changed

The files and their list (`BandSound.PARTS`, assets/audio/band/) are untouched, so the band-music job's files drop in.

- **Either the nearest band or the nearest few lone musicians** (never both): whichever is nearest the middle of the
  screen (a solo counts 400 px nearer). The band heard keeps it unless another band is 90 px nearer.
- **A band plays in step**: its parts on the one shared clock (as 0.36.0's one band).
- **Lone musicians play out of step**: each his own part from his own players (three "lone slots"), started a little
  off the shared clock (0.23 / 0.41 / 0.62 / 0.79 s by his number), so the player hears the cacophony when they are not
  a band. At most **3** lone musicians are heard (the nearest), each at the quiet level (or his solo's), so it is never
  loud chaos. The game music is ducked as before.

## Old saves and replays

- A **0.33-0.36 band unit** in a save (or a MIXED replay's keyframe) loads as its musicians standing together: the unit
  becomes the Drummer, and a Fifer and a Piper are added 24 px either side of him for each instrument it had (or its
  side had researched in an old save), so they form a band at once. The old band's wounds are shared out (a band at
  70 of 105 gives three men at two thirds of their health), a solo under way carries on with that musician, and each
  instrument's cooldown goes to its musician.
- A 0.36.0 save with a Fifer or Piper **walking to join**: he loads as a lone musician (the JOIN order is gone).
- An old **FULL replay** (pictures) shows its band as it was (the Drummer with the Fifer and Piper as child sprites),
  since a picture can't make new units.

## The computer (AI._band, MarchingBand.ai_tick)

- With an Armoury and 10+ soldiers it trains a **Drummer, then the Fifer and the Piper** (the Fifer first in a musket
  army; Easy never the Piper), a second set at 30+ soldiers, keeping each one's gold back from the soldiers as before.
- Its lone Fifers and Pipers walk to the nearest Drummer of theirs without one (forming a band); in a band they keep to
  their Drummer's row whatever the army told them; the Drummer keeps behind the line (as the old band did).
- Solos as before, per band or per lone musician: fife when 3+ in the ring are shooting, pipes when half the fighters
  are at the bayonet or sabre, drums to chase or to get out of a lost fight.
- **Not done: a lone drummer with its fast raiders.** A drummer walks at 62 and cannot keep up with Horsemen or Dragoons,
  so sending one with a raid would leave him behind on his own (say if you want it anyway, e.g. with a slower raid).

## Tests

- `tools/test_marching_band.gd` (rewritten; 84 checks, all pass): training each at the Armoury (prices, no powder for
  the Fifer, supply, health), a lone ring, the same-instrument rule, a drum solo's speed, the out-of-step overlap (the
  stronger buff only, the grey marker, the card, the piper's solo winning, apart again), a band forming (one of each),
  never out of step, +8% / +40% / 10 s, one solo at a time, the fife's reload at +40%, the markers (SELECTED, OFF,
  ALWAYS), the band breaking and re-forming and holding a little past the ring, the nearest set forming it, the row (a
  group move; the Drummer walking with his row), SELECT BAND, plain and Ctrl SOLO, the funnel, the sound (a band heard
  with no offset; lone musicians heard each off the clock and apart; the cap of 3), a new save, an old band unit's
  conversion (three units, a band, health shared, the solo kept), an old save's research, the snapshot, the replay
  field, an old FULL replay's band picture, the buff gone when the musician dies.
- `tools/test_marching_band_match.gd` (rewritten for musicians), Hard Crown v Easy Clockwork, 15 min:
  - ashford_crossing 4242: Drummer out 7:37, Fifer 10:36, Piper 11:34, **band formed 12:27**; solos: drums 8:48 (lone,
    8 soldiers buffed), fife 11:35 and 12:25 (lone), drums (band) 14:06 (15), pipes (band) 14:33 (17); a second set at
    30+ soldiers formed a second band at 14:59; no musician lost. All checks pass.
  - red_coast 7: in one run the Crown computer lost at 11:52 before 10 soldiers stood (no musician; the same weakness as
    0.36.0, docs/winrate_2026_11_12.md); another run of the same map and seed got its Drummer at 10:18 and its Fifer at
    11:41 (the matches are not deterministic between runs). 0.36.0 main on the same seed in this session was at 5
    soldiers by 11:00.
- `tools/test_content_all.gd -- only=crown`: 52 of 52 entries PASS (each musician trained, paid, cancelled, comes out
  with 1 supply; their cards: MOVE, STOP, PATROL, their SOLO, SELECT BAND, HOLD; a Drummer's ring on a Musketeer; the
  three make a band; the band's FIFE SOLO). (A first run alongside two match runs on this 2-core machine timed out its
  Labourers' builds; run alone it passes, as main does.)
- `tools/test_rules_fixes.gd`: 0 failures (the three musicians' cards have no ATTACK). `tools/test_i18n.gd`: PASS (0 of
  412 data texts untranslated in pt and es). `tools/test_files.gd`: passes. `tools/test_replay.gd`: ALL OK. (Each of
  these Godot runs ends with an "Aborted" at exit, as on main.)

## Claude's choices (say if wrong)

1. **Supply 1 each** (a full band is 3 supply, was 1): a man is a man, and lone musicians are now useful on their own.
2. **Health 40 / 35 / 35** (110 for the three; the old full band had 105).
3. **Fifer and Piper 18 s** (were 20), the Drummer 15 s as before.
4. **One solo at a time in a band** kept (your 2026-11-05 rule), each musician's cooldown his own. Lone musicians may all
   solo at once.
5. **The band's ring is round the middle of the three**, one ring, not three.
6. **A band holds until 1.15 rings apart** (forms within 1 ring): no flicker when one steps along the edge.
7. **Out of step only between DIFFERENT instruments** of lone musicians; a band's ring is never out of step, and a band
   ring plus a lone musician's ring do not clash (the stronger of each stat counts).
8. **The Drummer leads the row**: his Fifer and Piper follow him when he walks (unless you gave them another order); the
   Drummer does not follow them.
9. **Markers default SELECTED** (plus everyone in a ring during a solo).
10. **SELECT BAND** as a card button with the old JOIN icon (not Ctrl+click, which already means "all of this kind").
11. **No lone drummer with raiders** (above).

## Questions for the owner

1. The numbers above (supply 1 each? the band's +8% / +40% / 10 s?).
2. Should a band's Fifer and Piper also follow the Drummer when he is ordered to ATTACK-move (they do now, as a row),
   or should a band be told "stay together" only when you select all three?
3. Is the out-of-step penalty right-sized: only the stronger buff counts in the overlap (mild), or should it cost a
   little more (e.g. both buffs halved)?
4. Do you want a small painted BAND banner (instead of the word) and small painted buff glyphs for the markers?
