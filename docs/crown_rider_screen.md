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

(The sections below are filled as the job goes.)
