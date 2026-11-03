# The Crown's own computer (0.29.0, branch crown-ai-rebuild)

The owner (2026-11-03): the Crown and Clockwork computer was one 8,000-line script (`scripts/ai.gd`) with branches per
faction; its strategies were five multipliers (first wave size, expand sooner or later, tech sooner or later, worker
count); gold went to whichever stage of the think spent first, and later fixes HID gold to reserve it (`_hide_econ`,
`_hide_kept`, `_hide_repair`); every playtest added a module beside the old code. The Crown still lost to the Brood's
economy and timing. The job: give the Crown a computer of its own, like the Brood's (`scripts/ai_brood_new.gd`), with a
real opening build order per plan that owns the gold, then milestone rules per plan that follow the owner's doctrine,
coached and filmed like the Brood's (docs/brood_new_play_3.md).

Pictures: `docs/shots/crown_ai_rebuild/` (captions in its `captions.md`).

## 1. How it is built

`scripts/ai_crown.gd`, `class_name AICrown extends AI`, is made for every Crown computer wherever the Brood gets
`AIBroodNew` (`scripts/main.gd`, `scripts/ui/sandbox.gd`, `scripts/net/net_session.gd`, `tools/perf_bench.gd`). It
inherits the shared computer and overrides only what it owns, so everything that worked keeps working: the scout and its
reads (`scripts/ai_scout.gd`), the raids and the harass micro (`scripts/ai_harass.gd`), the ramp post on HOLD and the
rider scouts (`scripts/ai_crown_hold.gd`), the walls on a new hall (`scripts/ai_expand_wall.gd`), the transitions after a
held rush (`scripts/ai_transition.gd`), the retreat, the horses, the repairs and the gg.

What it owns:

| part | what it does | where |
|---|---|---|
| the plans | `AICrown.PLANS`: per plan an opening (`"opening"`: mill or breeder), the build order (`"bo"`), the Mill's crew in the opening (`"mill"`), the labourer cap in the opening (`"labs"`), the army's share of the labourers after it (`"army"`), the milestones (`"mid"`) and the shared settings it plays with (`"s"`: wave, step, expand...) | top of the file |
| the opening | `_think_stage` while `bo_owns()`: the plan's reserve is taken out of the bank for every other part of the think, the labourers are trained from what is left (`_bo_labs`), the next step is done when its trigger is met (`_bo_tick`, `_st_*`), a Cottage first whenever the supply is about to block (`_supply_due`) | "the think", "the steps" |
| a rush in the opening | `_defending` / `_bo_defence` / `_soldiers_first`: the wall, the Barracks and the Mill put first, soldiers before labourers, no hall till the rush is held, then the hall at once | after `_bo_tick` |
| the end of the opening | its last step done (the second hall laid, or the first attack out), the timing called off (`ATTACK_WAIT`), or `BO_LIMIT` (10:00) | `_bo_end` |
| the milestones | after the opening `_build_up` (the shared one: halls, the bank, the walls) then `_mid_tick`: the plan's next building whose trigger (labourers, halls, army supply) is met, one a think, its gold set aside (`_reserve`) | "after the opening" |
| the Mill's crew | `_mill_cap`: the plan's most in the opening; after it the crew follows the powder bank (`_mill_feedback`: a bank over twice `POWDER_WANT` sends a hand back to the farms, one under it brings one over, at most one every 8 s) | `_mill_cap` |
| an army the size of the economy | `_army_due` / `_base_trains_labs`: after the opening, while the army's supply is under the plan's share of the labourers, a hall trains a labourer only when every Barracks is busy | `_army_due` |
| no wave into a bigger army | `_wave_worth`: a wave goes only worth 1.1 times (1.5 against the Brood) the enemy's mobile army seen in the last 2 minutes, unless it is 60 supply or at the cap | `_wave_worth` |
| the doctrine's high ground | `_hall_first`: no third hall while the enemy is at our buildings or clearly bigger on our side; `_guard_new_hall`: no guards walk out to a hall site; `hold_beat`: against the Brood the ramp post goes down to the expansion only with twice the force there | after `_mill_cap` |

Hooks in the shared `scripts/ai.gd` (small, so the parallel Clockwork job merges cleanly): `_base_trains_labs()` (the
hall trains labourers by the shared rule), `_plan_tech()` (the Barracks, Foundry, Armoury and Church come from a plan's
milestones instead of the shared clock rule) and `bo_owns()` (a build order owns the gold: the scout's defence builds
nothing meanwhile, `scripts/ai_scout.gd`). `scripts/ai_crown_hold.gd` asks `hold_beat()` for its BEAT when the computer
has one. The AI STORY has sentences for the new match-log lines (`scripts/ai_story_lines.gd`, `tools/i18n/50_crown_ai.txt`).

No hiding tricks in the opening: the shared code's `_hide_repair`, `_hide_econ` and `_hide_kept` are not called while
the plan owns the gold; one rule does it, the plan's reserve. After the opening the shared economy-first rules play on
(they are what made 0.27.2's economy work), with the two changes above (the army's share, the milestones).

**Switch**: `-- crownnew:off` on the command line plays every Crown computer as the 0.27.2 shared computer (the AICrown
object then calls the shared code for everything). Easy plays the shared rules (no build order, no milestones).

**Deleted**: nothing. Every Crown path the plan replaces is still what `crownnew:off`, the Easy level and the tests that
make a shared `AI.new()` for the Crown play; deleting it would remove the comparison the owner asked to keep. What the
owner can drop once he has compared: in `scripts/ai.gd` the Crown branches of `_econ_build` (the build order of farms,
Mill and Breeder), the Crown tech lines of `_build_up`, `_workers`' `hold_gold` rules for the Crown, `_army_first` /
`_eco_first` / `_tech_wait` / `_turtling` / `_econ_wait`, and `AIScout._defence` for the Crown.

**The Marching Band** (an experiment, off by default) is not used by any plan. Its hook in `AI._produce` (one band once
the army is 6 strong) keeps working when the experiment is on, because the plan trains soldiers through the shared
`_produce`. To make a plan want it later: a `{"do": "army", ...}` step already lets `_produce` run; a step
`{"do": "build", "k": "barracks"}` plus a line in `_produce`'s band rule reading `plan.get("band", 0)` is all it needs.

SECTIONS_TO_FILL
