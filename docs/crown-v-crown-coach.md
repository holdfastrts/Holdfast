# crown-v-crown-coach: the Crown mirror, coached and filmed

The owner (2026-11-11 22:35) asked for every matchup to be COACHED and FILMED "with the same level of scrutiny and
attention" as the Crown v Brood job. This is the Crown mirror: Hard Crown OPTIMAL against Hard Crown OPTIMAL. Coaching as a
human coach does it: film real games, watch them, name each mistake with its time and a picture, find the decision behind
it in the code, fix that decision, play the same seed again and look at the same moment.

Rules followed: docs/design_principles.md (1 fairness: a mirror must be decided by play, 2 anti-snowball: the defender's
advantage early that FADES so a winner can finish, 4 epic battles that carry the weight of the match) and the owner's Crown
rules in CLAUDE.md (Foundry before the 2nd Barracks, 3 Field Cannons before any Mortar, the walled natural with its gate
toward the ramp, the army at the gate, OPTIMAL picks by read). No unit, building or economy number was changed.

**Everything new is gated to the mirror** (the Crown computer facing a Crown, Normal and up: `AICrown.mirror()`), lives in a
new file, `scripts/ai_crown_mirror.gd` (class `AICrownMirror`), and is switched off with `-- mirror:off` for comparison
games. The shared code only calls in (section "Shared functions changed").

## Tools

- `tools/film_coach.gd` (new): `tools/qa_match.gd`'s measured match (result.json, story.txt, log.txt) plus
  - a MAP picture every 15 s (`map_MMSS.png`, 3 px a cell, works headless): high ground lighter, water blue, each side's
    buildings in its colour (walls and gates darker, sites dark), soldiers as bright dots (P1 light blue, P2 yellow), workers
    as small pale dots, each army's centre as a white ring;
  - a coach's line every 15 s (`coach.txt`): per side its plan, bank, labourers and what they do, army value and kinds,
    halls, the wave (its men, where, how spread out, the siege piece), the army's centre and its distance from both mains;
  - with `shots:1` under xvfb: camera pictures of each army every 30 s (`focus:MMSS-MMSS` every 5-15 s), each hall every
    2 minutes and the fights.
- `tools/study/crown_v_crown_report.py`: the measuring table of a batch.

## The "before": 16 games on main (0.33.16)

Hard OPTIMAL v Hard OPTIMAL, 8 maps (Greenhold, Highmoor, Dune Sea, Red Coast, Thornwood Maze, Hollowfen, Frostmere,
Kestrel Rise), the QA study's two seeds of each (docs/qa_2026_11_08_matches), to 15:00.

BEFORE_TABLE

In short: **the mirror does not end** (14 of 16 draws). A side with an army 1.8 times the other's (and 800+) for a minute
saw an enemy hall fall in the next three minutes only 22 times in 61 such minutes. Every opening read was UNKNOWN (the
Crown walls its ramp at 0:22 and the scout sees nothing; OPTIMAL then plays the NORMAL table), so the picks were
Balanced, Dragoon raids, Economy and Timing about equally.

ROUNDS
