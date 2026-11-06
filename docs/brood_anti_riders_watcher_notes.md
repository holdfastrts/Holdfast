# brood-anti-riders: a second run's notes (branch brood-anti-riders-watcher, NOT for merging as is)

Two sessions ran the job brood-anti-riders at the same time (the other pushed f25c938d to `brood-anti-riders` at
20:19 UTC while this one was measuring). To not clobber that branch this run stopped and kept its work here for the
owner / the other run to take from. Nothing here is merged anywhere.

## What the measurements showed (tools/run_brood_v_riders.gd, a Hard Crown "rush" v Hard Brood OPTIMAL, Hollowfen, the
owner's seed 3233604515, 0.33.4)

A trace of the watching grub against the riders (trace:1) found why the Brood saw the riders only when they arrived:
- its "patrol" was a loop through the Crown's two hall sites (each 18 tiles from the Crown's hall), so half the time it
  was nowhere near the ramp's foot;
- the first rider out (~1:55) made it run HOME (6.5 tiles): a grub at 68 runs from a Horseman at 112 and dies on the
  way; the next watcher went WATCH_GAP (60 s) later and needed ~65 s to walk across Hollowfen, so the 3-rider sortie at
  3:16-3:23 rode past an empty foot (in the computer replay the second watcher was still walking, 25 tiles away);
- the shared alarm only counts what is seen past the foot + 3 tiles and 200 of value: riders at the foot don't count.
Baseline: riders arrive 3:47, the alarm 3:49 (warning -2 s); the Mother got up for 3 Horsemen (her swamp went, a Rootmaw
uprooted at 4:04); "14 grubs gang up on a Horseman".

## What this run changed (commit on this branch)
- The watcher against the Crown SITS at a post 3 tiles out from the foot and 4.5 to the side away from the Brood (off
  the riders' road, inside its 6-tile sight), looks at a hall site every 50 s (never with riders out), STEPS ASIDE from
  soldiers (6 tiles, back after 4 s calm) instead of running home, runs home only under half health; replaced after 20 s,
  up to 8 a game; the first goes at 0:40 in every economic plan against the Crown.
- A RIDERS' ALARM (_nb_riders_out): 2+ riders (or 200 value) seen off the Crown's plateau / past its foot. With it:
  outlying grubs (Rootmaws 14+ tiles from the Mother) walk to a refuge by the Mother in a 45 s head start (before 6:00
  unless the army is 2.5x the riders; after, only while the army is short), grubs within 8 tiles of a rider run there,
  warriors are laid out of saved food until the army is 1.2x the riders, then grubs again; the army holds at the refuge
  and bites only riders within 6 tiles of it (_nb_hold_vs_riders); the Mother stays rooted against riders alone; no
  turtle gets up for riders (26 speed, it never gets there); grubs gang up only on one rider under half health with 6+
  grubs winning at 30% margin. The answer ends 12 s after the riders came and left (if the army is ~0.85x them) or 60 s.
- _rush_holds(): a riders' rush stops capping grubs / holding growth once answered.
After (same game, several runs; the games are not deterministic): alarm at 3:18-3:22 for riders arriving 3:46-3:51,
warning 26-29 s (was -2 s); grubs lost in the raid's 90 s 2-4 (was 7-9); grubs at 5:00 17-24 (was 19); biomass at 10:00
9.5k-11k (was 9.9k, a game the baseline Brood won by 9:00).
