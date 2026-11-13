class_name NetView
extends RefCounted
## What one side's guests have been sent (host): NetSnapshot.build makes a picture for each view, filtered by that side's
## fog (docs/online_ranked.md "Fog"). Guests on the same side share a view (co-op); a session with no guests sides
## (a replay recorder, a test) builds with the session itself as its view (the same fields, eyes() empty = sees all).
## A ranked match (strict) also leaves out what a side could only learn by peeking: the enemy's bank and battle report.

var sides: Array = []             # the sides this view sees for (one, in practice)
var peers: Array = []             # relay ids that get this view's pictures
var strict := false               # ranked: the enemy's resources and stats are not sent until the match is over
var sent_slow := {}               # id -> hash of the values last sent whole
var sent_fast := {}               # id -> where it was / its health when last sent
var was_seen := {}                # unit ids this view could see at the last snapshot
var vknown := {}                  # id -> [entity, is_building, team, cell or place, size]: what this view's guests hold
var line_fp := -1
var keg_fp := -1
var spot_fp := -1
var leaks := 0                    # (tests: rows about an enemy this view could not see; must stay 0)


func view_eyes() -> Array:
	return sides
