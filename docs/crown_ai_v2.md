# crown-ai-v2: the Crown computer, the weak side everywhere (0.33.12)

The owner approved (2026-11-11) the QA study's top item (docs/qa_2026_11_08_matches.md "What to fix first" 1, 3, 4;
docs/qa_2026_11_08_tests.md items 4 and 13): Hard v Hard on 19 maps the Crown computer won 1 of 76 cross games; against
the Brood 0-13-25 and it never led; against the Clockwork it led 4 of 38; it earned 0.65-0.68 of its opponent's income at
5:00-8:00 and held 1.9 halls at 8:00 against 3.4 (Brood) and 2.4 (Clockwork); OPTIMAL picked Balanced in 67 of 76 cross
sides and those won or led 2 of 67.

This job owns the Crown computer only (scripts/ai_crown*.gd, ai_optimal.gd's Crown parts, the Crown expansion wall); the
shared changes are small and guarded by faction. Design rules followed (docs/design_principles.md): 1 fairness (a side
that cannot win against anyone), 2 anti-snowball (a lost base must not become a lost game; defender's advantage early),
3 meaningful base building (walls and gates that work), 4 the economy-first play the owner showed.

(sections below: written as the work went; the numbers at the end)
