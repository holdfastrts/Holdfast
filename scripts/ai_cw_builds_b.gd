extends RefCounted
## cw-builds-b (the owner, 2026-11-03: "do it all"; docs/clockwork_builds_b.md): two Clockwork computer plans built round the
## HEAVY WORKS, each a written OPENING BUILD ORDER (read by AIClockwork, scripts/ai_clockwork.gd: the step words are its) and
## then a PUSH (scripts/ai_cw_push.gd):
##  - "pendulum", PENDULUMS: the answer to the Brood's Raptor swarms (the owner's playtests: "it should have gone Pendulum").
##    A few Clock Soldiers early (the Brood's rushes come at 2:00 to 3:30), the Mainspring and the Escapement, the Heavy
##    Works as soon as the Escapement works, two Pendulums, the expansion behind them, a third Pendulum; then the push of
##    Pendulums and Clock Soldiers with the escort Winders, to the Brood's Rootmaws and Mound Turtles, then the Mother.
##  - "heavy", HEAVY WORKS PUSH: a slow, hard-to-stop mid-game push: Clock Soldiers in front, two Spring Ballistas behind
##    them, the Great Winder behind those (it winds and mends them, sweeps the wrecks into cogs, throws SCATTER COGS on a
##    charge). It sieges a Crown wall from out of musket reach; against the Brood it walks to its nests like the Pendulums.
## Plan keys (as AIClockwork.PLANS): workers0, steps; and
##  push       the push's settings (scripts/ai_cw_push.gd): "need" {kind: n} before it goes ("front": the Clock Soldiers,
##             Springers and Netters together; against the Brood "need_brood" when given), "min_supply" (the army's supply)
##  keep       after the opening, the Heavy Works keeps n of each kind first, in order ([[kind, n], ...]); "keep_brood"
##             against the Brood. (Pendulums: never fewer than the swarm rule wants, AISwarm.pend_want.)
##  front      after the opening, the Light Works keeps this many Clock Soldiers (2 more for each push gone out)
## Supply: "N kind" waits for N supply as in the Springer timing. The opening's Clock Soldiers stay at home (the shared
## computer's defence); the shared computer's turret rule still lays a Ratchet Turret at a threat after 2:30.

const PLANS := {
	"pendulum": {
		"workers0": 14,
		"steps": [
			"7 cog_press",
			"8 movement_works",
			"9 mainspring",
			"crew mainspring 3",
			"11 regulator",
			"clock_soldier 2",
			"escapement",
			"workers 18",
			"heavy_works",
			"clock_soldier 2",
			"regulator",
			"pendulum 2",
			"workers 22",
			"clocktower",
			"pendulum 1",
			"clock_soldier 4",
			"end",
		],
		"push": {"need": {"pendulum": 3, "front": 5}, "min_supply": 18},
		"keep": [[Defs.PENDULUM, 4], [Defs.GREAT_WINDER_KIND, 1]],
		"front": 8,
	},
	"heavy": {
		"workers0": 14,
		"steps": [
			"7 cog_press",
			"8 movement_works",
			"9 mainspring",
			"crew mainspring 3",
			"11 regulator",
			"clock_soldier 2",
			"escapement",
			"workers 18",
			"heavy_works",
			"clock_soldier 2",
			"regulator",
			"ballista 1",
			"workers 22",
			"clocktower",
			"great_winder 1",
			"ballista 1",
			"clock_soldier 4",
			"end",
		],
		"push": {"need": {"ballista": 2, "great_winder": 1, "front": 12}, "min_supply": 22,
			"need_brood": {"ballista": 2, "great_winder": 1, "front": 6, "pendulum": 1}},
		"keep": [[Defs.BALLISTA_KIND, 3], [Defs.GREAT_WINDER_KIND, 1]],
		"keep_brood": [[Defs.PENDULUM, 2], [Defs.BALLISTA_KIND, 2], [Defs.GREAT_WINDER_KIND, 1]],
		"front": 14,
	},
}
