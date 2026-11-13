extends SceneTree
## How many ranked matches one processor core can host (docs/online_ranked.md "Capacity"). A Hard computer v Hard
## computer match (they stand in for the two players' armies) runs as fast as it can (--fixed-fps 30: every frame is one
## game tick), with a host session making the two players' fog-filtered pictures as a dedicated host does (both
## sides' views, 15 a second, packed for the wire). Per game minute: the processor time the whole program used (/proc),
## and the computers' own thinking (Prof "ai", which a ranked host does not run: its players are people), so
##   host cost = program - computers' thinking.
##   godot --headless --fixed-fps 30 --script res://tools/server/capacity_bench.gd -- map:hollowfen minutes:12 [f0:crown f1:brood]
## Prints a line a minute and a summary: the share of one core a match needs at that minute, and over the match.
var main: Node
var args := {}
var g: Game
var hs: NetSession
var frames := 0
var minute := 0
var cpu0 := 0.0
var ai_prev := {}
var ai_ms := 0.0
var snap_ms := 0.0
var bytes := 0
var rows: Array = []
var done := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var i := a.find(":")
		if i > 0:
			args[a.substr(0, i)] = a.substr(i + 1)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


static func cpu_s() -> float:
	var f := FileAccess.open("/proc/self/stat", FileAccess.READ)      # (its size says 0: read it as a line)
	if f == null:
		return -1.0
	var st := f.get_line()
	var parts := st.substr(st.rfind(")") + 2).split(" ")
	return (float(parts[11]) + float(parts[12])) / 100.0     # utime + stime, in clock ticks (100 a second)


func _ai_us() -> float:
	var total := 0.0
	for k in ["ai", "ai/brood"]:
		var v := float(Prof.us.get(k, 0))
		var p := float(ai_prev.get(k, 0.0))
		total += v - p if v >= p else v       # (the match log empties Prof each minute)
		ai_prev[k] = v
	return total


func _process(_d: float) -> bool:
	if done:
		return false
	if main.game == null:
		if frames == 0:
			main.start({"map": String(args.get("map", "hollowfen")), "seed": int(args.get("seed", "4242")), "slots": [
				{"who": "hard", "faction": String(args.get("f0", "crown")), "colour": 0, "side": 0, "strategy": "balanced"},
				{"who": "hard", "faction": String(args.get("f1", "brood")), "colour": 1, "side": 1, "strategy": "balanced"}]})
		frames += 1
		return false
	if g == null:
		g = main.game
		paused = false
		hs = NetSession.new()
		hs.game = g
		hs.is_host = true
		hs.go_given = true
		hs.link = NetLink.new()
		hs._m_reset()
		hs.peer_team = {1: 0, 2: 1}
		hs.strict = true
		cpu0 = cpu_s()
	paused = false
	frames += 1
	ai_ms += _ai_us() / 1000.0
	if frames % 2 == 0:
		var t0 := Time.get_ticks_usec()
		hs.snap_n += 1
		for v in hs.side_views():
			bytes += NetCodec.pack(NetSnapshot.build(hs, v)).size()
		hs.fx = []
		snap_ms += (Time.get_ticks_usec() - t0) / 1000.0
	if g.clock >= (minute + 1) * 60.0 or g.over:
		minute += 1
		var c := cpu_s()
		var prog_ms := (c - cpu0) * 1000.0
		var host_ms := prog_ms - ai_ms
		rows.append([minute, g.units.size(), prog_ms / 60.0, ai_ms / 60.0, host_ms / 60.0, snap_ms / 60.0, bytes / 60.0 / 2.0])
		print("CAP min %2d  units %3d  program %6.1f ms/s  computers' thinking %6.1f  HOST %6.1f ms/s (%4.1f%% of a core)  pictures %5.1f ms/s  %5.1f KB/s a player" % [minute, g.units.size(), prog_ms / 60.0, ai_ms / 60.0, host_ms / 60.0, host_ms / 600.0, snap_ms / 60.0, bytes / 60.0 / 2.0 / 1024.0])
		cpu0 = c
		ai_ms = 0.0
		snap_ms = 0.0
		bytes = 0
		if minute >= int(args.get("minutes", "12")) or g.over:
			_summary()
	return false


func _summary() -> void:
	done = true
	var tot := 0.0
	var peak := 0.0
	for r in rows:
		tot += float(r[4])
		peak = maxf(peak, float(r[4]))
	var avg := tot / maxf(rows.size(), 1)
	print("CAP SUMMARY %s %s v %s, %d minutes: host avg %.1f ms/s (%.1f%% of a core), busiest minute %.1f ms/s (%.1f%%): about %d matches a core on average, %d at their busiest" % [g.map_id, g.faction_of(0), g.faction_of(1), rows.size(), avg, avg / 10.0, peak, peak / 10.0, int(1000.0 / maxf(avg, 1.0)), int(1000.0 / maxf(peak, 1.0))])
	quit(0)
