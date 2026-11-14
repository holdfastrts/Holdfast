# cinder-clockwork-ai: the Clockwork computer after the owner's Cinder Steps watch (0.35.15)

The owner watched Hard Crown (OPTIMAL) v Hard Clockwork (OPTIMAL) on Cinder Steps (0.35.10;
docs/playtests/2026-11-13_cinder_steps_notes.md). This job fixes the CLOCKWORK computer for items 1, 4 and 6. It changes
only the AI. No unit numbers changed.

## What was wrong

1. **Item 1: two Winders killed by two Labourers (2:36-2:49).** The scout (trip 2) and the sentry peeking up the walled
   ramp each traded blows with two Crown Labourers until they died. The cause: the scout's and the sentry's threat
   checks (scripts/ai_scout.gd `_threats`, `_sentry_threats`) only counted units where `Unit.has_attack()` is true, and
   that is **false for every worker**. A Labourer hits as hard as a Winder, and two of them beat one, but the scout
   never counted them as a danger. So it stood its ground on its hold or move order and fought back.
2. **Item 4: the army "respected" three cannons guarded by two Musketeers.** When enemies stood on high ground above
   the push, it stepped its line back 90 px at a time, but only while they were within 300 px. A Field Cannon reaches
   430 px, so the line stood inside round shot range for minutes ("enemies shoot down from high ground: the line steps
   back out of their reach", 10:14 and 13:55). It never weighed how thin the guard was, and it never went for the guns.
3. **Item 6: the push pulled back at 11:49 with enough left to finish.** The rule "pull back once less than 40% of what
   went out is left" (`GRIND`) only counted its own losses. It never looked at what still stood in front of it.

## What changed

- **Scouts and sentries run from workers that come for them** (scripts/ai_scout.gd, `_worker_after`,
  `_run_from_workers`). An enemy worker counts as a threat when it is after our Winder: it hit the Winder in the last 4 s,
  or the Winder is its target, within 200 px. Workers busy with their own work are still walked past. From workers
  alone, the Winder runs straight away from them and toward home (320 px). It does not go to the stand-off spot by the
  ramp, which would be in among them. A peek up the ramp also ends at once when a worker comes for it. This change is
  for the Clockwork only, because the Crown's scouting belongs to the other job (cinder-crown-ai).
- **Guns with a thin guard are rushed** (new scripts/ai_cw_guns.gd, used by the push in scripts/ai_cw_push.gd
  `_gun_rush_tick` and by the whole-army base defence in scripts/ai_cw_army.gd):
  - **The trigger.** Enemy guns (Field Cannons and Mortars, limbered or not) are in sight within 600 px of the front, and
    the army is worth **2.5 times** the guard plus half the guns. The guard is the armed enemies within 300 px of a gun.
    If the guns are up on high ground above it, the army must be worth **3.5 times** instead.
  - **The rush.** Every front unit is sent straight at a gun, nearest first and spread over the guns. A guard standing in
    the way is cut down first. The Springers jump in, and the Great Winder stays behind.
  - **Keeping it going.** The rush goes on while the army is still worth 1.4 times the guard plus half the guns. Once
    units are at the guns, 0.8 times is enough, because turning round inside canister range is the worst choice. Guns
    and guards seen in the last 8 s still count, because on high ground they drop in and out of sight.
- **Guns too well guarded: it steps back out of their reach.** It now steps back past the guns' range plus 40 px
  (470 px), not just to 300 px.
- **Against the Crown, a push that still wins finishes the job** (`_finishing`). When a loss rule would pull it back
  (lost 60%, or lost a third and weaker than what is near), it stays in two cases. The first is that it is rushing guns
  and the rush still wins. The second is that it is worth 2.5 times everything it knows of: what it sees near it, plus
  every armed enemy it saw in the last minute that it cannot see now. The outnumbered rule and the base-under-attack
  rules are unchanged.
- **Switches** (study only): `-- cwscoutflee:off`, `cwguns:off`, `cwfinish:off` play each part as 0.35.14.

## The numbers

### Full games

These are Hard OPTIMAL v Hard OPTIMAL games to 15:00, on 8 maps: Cinder Steps, Red Coast, Ashfall, Greenhold, Frostfang,
Dune Sea, Redrock Canyon and Twin Fords. Each map was played from both start spots, using the qa-matches seeds
(`tools/study/qa_matches.py` `cw()`). There is also one game on the owner's own seed (Cinder Steps, 1909496369).

"Before" is the same code with the three switches off. W-D-L is the Clockwork's result. A draw means the game went to
15:00, and a side "led" if it was ahead at the end.

| | before | after |
|---|---|---|
| **Clockwork v Crown** (17 games), W-D-L | 5-12-0 | **8-9-0** |
| won or led | 17 | 17 |
| Clockwork units lost by 4:00, per game | 1.24 | **0.18** |
| gun rushes | 0 | 44 |
| line steps back from high ground | 26 | 16 |
| push pull-backs | 21 | 22 |
| Clockwork units killed by Field Cannons | 61 | 62 |
| units lost (Clockwork / Crown), all games | 1,374 / 1,356 | 1,476 / 1,261 |
| **Clockwork v Brood** (16 games), W-D-L | 3-6-7 | 2-10-4 |
| won or led | 7 | 7 |

- **Against the Crown, more games are won outright.** 8 wins against 5, with the Crown no stronger. The early Winder
  losses are almost gone.
- **Against the Brood, nothing in its play changed.** The Brood has no guns, and the finish rule is for the Crown only.
  The difference is within the noise: won-or-led stayed 7 of 16, and a won-or-led count moves about ±3 between two runs
  of the same games.
- **Labourers still kill a few Clockwork units over a whole game** (7 before, 9 after). These are not the scouts any
  more (losses by 4:00 fell 1.24 to 0.18 a game). They are base fights later on.
- **The owner's seed:** before, the Clockwork won (12:51). After, it was a draw well ahead at 15:00, with income 30,033
  against the Crown's 9,500. It rushed guns 4 times.

### Sandbox

The sandbox is `tools/test_cw_gun_rush.gd`. A Clockwork push of 16 Clock Soldiers and 4 Springers (1,520 value) meets 3
deployed Field Cannons. Each case ran 8 seeds before and after.

- **Guard:** 2 Musketeers ("thin") or 6.
- **R:** the guns are at the top of the Crown main's ramp, and the army starts at its foot (already in round shot range).
- **F:** the guns are on open ground 520 px from the army.

| case | guns all killed (before → after) | value lost of 1,520 (before → after) |
|---|---|---|
| thin F | 5/8 → **7/8** | 874 → **812** |
| thin R | 0/8 → **3/8** (guns left 2.6 → 0.9 on average) | 1,133 → 1,383 |
| 6 guards F | 1/8 → 3/8 | 1,246 → 1,312 |
| 6 guards R | 0/8 → 0/8 | 1,157 → **1,472** |

- **On open ground the rush is better on both counts.** It kills the guns more often and loses less.
- **Up a ramp the rush kills the guns, but it costs more.** Clock Soldiers squeeze up the ramp into canister. Standing
  at the foot loses almost as much and kills nothing.
- **With 6 guards up a ramp it should not rush, but it does.** From the low ground it sees only some of the guard, so a
  strong guard looks thin. See open question 1.
- `tools/test_cw_scout_workers.gd`: a Winder made the sentry at the foot of the Crown's ramp, with two Labourers sent at
  it. Before, it died (8 blows). After, it lived. The scout case lives in both.

### Tests

The AI tests (tools/test_ai*.gd), test_clockwork_army, test_clockwork_home, test_cw_raid_leash, test_crcw_coach and the
two new tests all pass. The exceptions are the known flaky ones: test_ai_brood stage 3, test_ai_rush ("workers before
the Brood Mother") and test_ai_rush_followup. These are Crown v Brood, and nothing here touches them.

## Open questions for the owner

1. **Rushing guns up a ramp.** From below, the Clockwork sees only part of the guard on the high ground. So it rushes
   when the guard is thin (good: in the sandbox it kills the guns 3 times in 8 instead of never), but also sometimes when
   the guard is strong (bad: 6 Musketeers and 3 guns up a ramp cost it about 300 more value than standing off). Options:
   - keep it as it is (your words: "everything at once rather than piecemeal");
   - never rush guns uphill until a unit has seen the top (it would mostly stand off then);
   - send a Springer up first to look.
2. **The finish rule is Crown-only for now.** Should a push that clearly wins also stay against the Brood and in the
   mirror? There the losses usually come from an army it cannot see, so we kept it out.
3. **The scout fix is Clockwork-only for now.** The Crown's Labourer scout and the Brood's grubs have the same blind spot:
   `has_attack()` is false for workers. It could be opened to every faction once cinder-crown-ai has merged.
4. **Field Cannons still kill as many Clockwork units over a game (61 → 62).** The rush kills guns sooner, but the
   Crown's later guns still catch the army in the open. Is canister (27 a hit against light units, 35 up close, a wide
   cone) as strong as you want? That is a balance question, not an AI one, so nothing was changed.
