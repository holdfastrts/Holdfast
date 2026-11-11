# crown-v-clockwork-coach: Crown v Clockwork, coached and filmed

(Work in progress: this file grows with each coaching round.)

The owner (2026-11-11 22:35) asked for every matchup coached and filmed with the scrutiny of the Crown v Brood job. This
job is Crown v Clockwork: Hard OPTIMAL v Hard OPTIMAL, filmed (tools/shot_ai_match.gd, now with `pa:`/`pb:` plans and
`every:N` stills of each main and each army), the mistakes named with a time, a picture and the decision behind them,
fixed, and the same seeds replayed. Both computers are coached. Fixes are small and gated by the enemy's faction
(`AICrown.cc_vs_clock()`, `AIClockwork.cc_vs_crown()`); `-- crcw:off` plays the matchup as before the job.

Tools: `tools/study/crcw_coach.py` (the 16 measuring games: the qa-matches base tags and seeds of 8 maps, both start
slots; `--only others` the control batch), `tools/study/crcw_coach_report.py` (the table).
