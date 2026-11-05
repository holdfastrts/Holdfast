class_name AIRead
extends RefCounted
## THE READ OF A SCOUT REPORT (ai-optimal, the owner 2026-11-05 09:34: "the absence of army or buildings is already
## information. It tells you that the enemy is greedy"; docs/ai_optimal.md). Every computer's scout report reads as one of
## five words. The Crown's and the Clockwork's scout (scripts/ai_scout.gd) keeps its old verdict keys inside; the Brood's
## own sight (scripts/ai_brood_new.gd, _nb_read) reads straight into these.
##   GREEDY      no army and no production at its base (looked at, from ~0:55), an early expansion with little army, or a
##               full economy with no military building
##   NORMAL      a standard opening: production and a small army, nothing that says rush or greed
##   AGGRESSIVE  a rush: fast rush units early, a big early army, production on a thin economy
##   DEFENSIVE   static defences (turrets, rooted defenders) or one base walled all round with little army; a wall that
##               kept the scout out
##   UNKNOWN     nothing reachable seen (the scout killed, blocked, lost, or saw too little): that proves nothing. It is
##               never a reason for an army: the scout looks again soon.

## AIScout's verdict keys -> the read's word.
const NAME := {"greedy": "GREEDY", "balanced": "NORMAL", "rush": "AGGRESSIVE", "defensive": "DEFENSIVE", "uncertain": "UNKNOWN", "pending": "UNKNOWN"}
## The read's word -> AIScout's verdict key.
const KEY := {"GREEDY": "greedy", "NORMAL": "balanced", "AGGRESSIVE": "rush", "DEFENSIVE": "defensive", "UNKNOWN": "uncertain"}

## Static defence buildings (a turret line says DEFENSIVE).
const DEFENCES := ["ratchet_turret"]

## The fixed phrases of what was seen (the story tells them translated: tools/i18n/55_ai_optimal.txt). Keep this list and
## the i18n file together.
const SAW := [
	"no army and no production at its base",
	"a second base and little army",
	"a full economy and no military building",
	"a standard opening",
	"fast rush units early",
	"a big early army",
	"production buildings and a thin economy",
	"two Light Works very early",
	"a production building very early",
	"turrets or rooted defenders",
	"walls all round one base",
	"a walled ramp that kept the scout out",
	"too little of its base",
	"the scout was killed",
	"the scout was blocked",
	"the scout was driven off",
	"the scout was turned back",
	"no scout got out",
	"an army near its home",
	"its army on the move early",
	"a new base by its natural",
]


static func word(verdict: String) -> String:
	return String(NAME.get(verdict, "UNKNOWN"))


static func default_saw(verdict: String) -> String:
	match verdict:
		"greedy":
			return "no army and no production at its base"
		"rush":
			return "fast rush units early"
		"defensive":
			return "turrets or rooted defenders"
		"uncertain":
			return "too little of its base"
	return "a standard opening"
