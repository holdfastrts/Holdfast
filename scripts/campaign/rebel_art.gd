class_name RebelArt
extends RefCounted
## The rebels' sprite sets (scripts/campaign/rebels.gd), merged into ArtData.UNITS. Kept apart, with no other class in
## it, so ArtData can read it while the game loads.

## Sprite sets the rebels bring (merged into ArtData.UNITS). "pikeman": the retired Crown Pikeman's strips, back for the
## campaign (assets/units/pikeman; the cell and anchor as tools/experiment_crown_legs.py had them). The Free Assembly's
## own sets (rebel_militia, rebel_pikeman, rebel_torch, rebel_varenne) are cut from the owner's ChatGPT sheets by
## tools/import_rebels.py --write, which rewrites the block between the REBELS markers (docs/rebel_art.md).
const ART := {
	"pikeman": {"cell": Vector2i(68, 66), "anchor": Vector2(34, 64), "frames": {
		"idle_s": 2, "idle_se": 2, "idle_e": 2, "idle_ne": 2, "idle_n": 2,
		"walk_s": 2, "walk_se": 2, "walk_e": 4, "walk_ne": 4, "walk_n": 4,
		"attack_s": 2, "attack_se": 2, "attack_e": 2, "attack_ne": 2, "attack_n": 2,
		"brace_s": 1, "brace_se": 1, "brace_e": 1, "brace_ne": 1, "brace_n": 1,
		"death_s": 2, "death_se": 2, "death_e": 2, "death_ne": 2, "death_n": 1}},
	## REBELS-BEGIN (written by tools/import_rebels.py)
	"rebel_militia": {"cell": Vector2i(86, 37), "anchor": Vector2(43, 35), "frames": {
		"aim_s": 2, "aim_se": 2, "aim_e": 3, "aim_ne": 2, "aim_n": 2,
		"aimup_s": 2, "aimup_se": 2, "aimup_e": 3, "aimup_ne": 2, "aimup_n": 2,
		"death_s": 4, "death_se": 3, "death_e": 3, "death_ne": 3, "death_n": 3,
		"fire_s": 2, "fire_se": 2, "fire_e": 3, "fire_ne": 2, "fire_n": 2,
		"fireup_s": 2, "fireup_se": 2, "fireup_e": 3, "fireup_ne": 2, "fireup_n": 2,
		"idle_s": 2, "idle_se": 2, "idle_e": 2, "idle_ne": 2, "idle_n": 2,
		"melee_s": 4, "melee_se": 4, "melee_e": 4, "melee_ne": 4, "melee_n": 4,
		"reload_s": 6, "reload_se": 6, "reload_e": 8, "reload_ne": 6, "reload_n": 4,
		"walk_s": 3, "walk_se": 4, "walk_e": 5, "walk_ne": 4, "walk_n": 3,
		}},
	"rebel_pikeman": {"cell": Vector2i(102, 62), "anchor": Vector2(51, 54), "frames": {
		"attack_s": 3, "attack_se": 3, "attack_e": 4, "attack_ne": 4, "attack_n": 5,
		"brace_s": 1, "brace_se": 1, "brace_e": 1, "brace_ne": 1, "brace_n": 1,
		"death_s": 3, "death_se": 3, "death_e": 3, "death_ne": 3, "death_n": 3,
		"idle_s": 2, "idle_se": 2, "idle_e": 2, "idle_ne": 2, "idle_n": 2,
		"walk_s": 3, "walk_se": 3, "walk_e": 4, "walk_ne": 4, "walk_n": 4,
		}},
	"rebel_torch": {"cell": Vector2i(120, 51), "anchor": Vector2(60, 49), "frames": {
		"build_s": 3, "build_se": 2, "build_e": 2, "build_ne": 3, "build_n": 2,
		"death_s": 3, "death_se": 3, "death_e": 3, "death_ne": 3, "death_n": 3,
		"idle_s": 2, "idle_se": 2, "idle_e": 2, "idle_ne": 2, "idle_n": 2,
		"mine_s": 6, "mine_se": 4, "mine_e": 6, "mine_ne": 6, "mine_n": 6,
		"walk_s": 3, "walk_se": 3, "walk_e": 3, "walk_ne": 3, "walk_n": 4,
		}},
	"rebel_varenne": {"cell": Vector2i(76, 37), "anchor": Vector2(38, 35), "frames": {
		"aim_s": 1, "aim_se": 1, "aim_e": 1, "aim_ne": 1, "aim_n": 1,
		"death_s": 3, "death_se": 3, "death_e": 3, "death_ne": 3, "death_n": 3,
		"fire_s": 2, "fire_se": 2, "fire_e": 2, "fire_ne": 1, "fire_n": 1,
		"idle_s": 2, "idle_se": 2, "idle_e": 2, "idle_ne": 2, "idle_n": 2,
		"melee_s": 3, "melee_se": 3, "melee_e": 3, "melee_ne": 2, "melee_n": 2,
		"shout_s": 3, "shout_se": 3, "shout_e": 3, "shout_ne": 3, "shout_n": 2,
		"walk_s": 3, "walk_se": 3, "walk_e": 3, "walk_ne": 3, "walk_n": 2,
		}},
	## REBELS-END
}
