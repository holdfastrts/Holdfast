class_name Prof
## A cheap profiler for the match log's lag lines: time (microseconds) spent in each part of
## the game since the last minute, and how often. MatchLog prints and resets it each minute.
## It also keeps what each frame spent (frame_us): MatchLog writes a "slow frame" line with the
## parts that took the time whenever a frame takes longer than MatchLog.SLOW_FRAME_MS.
static var us := {}
static var calls := {}
## This frame's parts (cleared by MatchLog each frame).
static var frame_us := {}
## The parts timed hundreds of times a second (every unit's and building's tick) add up here
## first, without the dictionaries, and go in with flush().
static var unit_us := 0
static var unit_n := 0
static var bld_us := 0
static var bld_n := 0
## The slowest single unit tick since the last frame_reset() (and that unit): a slow frame
## names it ("slowest unit: raptor 31 ms, order attack").
static var slow_unit_us := 0
static var slow_unit: Object = null
## By kind (tools only: tools/perf_bench.gd "kinds"): "kind order" -> [microseconds, ticks]; off in a match.
static var by_kind := false
static var kind_us := {}
static var bkind_us := {}
## Units' and buildings' time this frame (unit_us / bld_us before the frame's flush).
static var _fu := 0
static var _fb := 0
## unit_us / bld_us already flushed into us (so a flush in the middle of a frame loses nothing).
static var _u_done := 0
static var _b_done := 0


static func add(key: String, t0: int) -> void:
	var dt := Time.get_ticks_usec() - t0
	us[key] = int(us.get(key, 0)) + dt
	calls[key] = int(calls.get(key, 0)) + 1
	frame_us[key] = int(frame_us.get(key, 0)) + dt


## Put the batched parts in (before reading us / calls).
static func flush() -> void:
	_u_done += unit_us
	_b_done += bld_us
	if unit_n > 0:
		us["units"] = int(us.get("units", 0)) + unit_us
		calls["units"] = int(calls.get("units", 0)) + unit_n
		unit_us = 0
		unit_n = 0
	if bld_n > 0:
		us["buildings"] = int(us.get("buildings", 0)) + bld_us
		calls["buildings"] = int(calls.get("buildings", 0)) + bld_n
		bld_us = 0
		bld_n = 0


## This frame's parts with the units' and buildings' ticks in them: {part: microseconds}.
static func frame_parts() -> Dictionary:
	var d := frame_us.duplicate()
	var fu := _u_done + unit_us - _fu
	var fb := _b_done + bld_us - _fb
	if fu > 0:
		d["units"] = fu
	if fb > 0:
		d["buildings"] = fb
	return d


## A new frame begins: forget the last one's parts.
static func frame_reset() -> void:
	frame_us.clear()
	_fu = _u_done + unit_us
	_fb = _b_done + bld_us
	slow_unit_us = 0
	slow_unit = null


static func reset() -> void:
	us.clear()
	calls.clear()
	frame_us.clear()
	unit_us = 0
	unit_n = 0
	bld_us = 0
	bld_n = 0
	_u_done = 0
	_b_done = 0
	_fu = 0
	_fb = 0
