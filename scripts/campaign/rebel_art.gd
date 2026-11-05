class_name RebelArt
extends RefCounted
## The rebels' sprite sets (scripts/campaign/rebels.gd), merged into ArtData.UNITS. Kept apart, with no other class in
## it, so ArtData can read it while the game loads.

## Sprite sets the rebels bring (merged into ArtData.UNITS). "pikeman": the retired Crown Pikeman's strips, back for the
## campaign (assets/units/pikeman; the cell and anchor as tools/experiment_crown_legs.py had them). The owner's
## redrawn rebels go here as they come: e.g. "rebel_pikeman": {"cell": ..., "anchor": ..., "frames": {...}}.
const ART := {
	"pikeman": {"cell": Vector2i(68, 66), "anchor": Vector2(34, 64), "frames": {
		"idle_s": 2, "idle_se": 2, "idle_e": 2, "idle_ne": 2, "idle_n": 2,
		"walk_s": 2, "walk_se": 2, "walk_e": 4, "walk_ne": 4, "walk_n": 4,
		"attack_s": 2, "attack_se": 2, "attack_e": 2, "attack_ne": 2, "attack_n": 2,
		"brace_s": 1, "brace_se": 1, "brace_e": 1, "brace_ne": 1, "brace_n": 1,
		"death_s": 2, "death_se": 2, "death_e": 2, "death_ne": 2, "death_n": 1}},
}
