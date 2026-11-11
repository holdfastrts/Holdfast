extends "res://tools/qa_match.gd"
## START SPOTS (start-spots study, docs/start_spots_study.md): tools/qa_match.gd plus a LAYOUT record, measuring only.
## Same arguments as qa_match.gd. Also writes <out>/layout.json: each player's start cell and side number, and once a
## minute every building of each player ([kind, centre x, centre y in tiles, built]) and its army's centre and value, so
## the study can see whether the two spots build their bases the same way (a mirrored map should give mirrored bases).
var lay_rows: Array = []
var _next_lay := 30.0


func _every10() -> void:
	super._every10()
	if g.clock >= _next_lay:
		_next_lay += 60.0
		_lay_snap()


func _lay_snap() -> void:
	var row := {"t": int(round(g.clock)), "p": []}
	for tm in n:
		var bl: Array = []
		for b in g.buildings:
			if b.team == tm and not b.dead:
				var c: Vector2 = b.rect().get_center() / Game.T
				bl.append([b.kind, snappedf(c.x, 0.1), snappedf(c.y, 0.1), b.built])
		var sum := Vector2.ZERO
		var k := 0
		for u in _army_units(tm):
			sum += u.global_position / Game.T
			k += 1
		row["p"].append({"b": bl, "army_n": k, "army_c": [snappedf(sum.x / k, 0.1), snappedf(sum.y / k, 0.1)] if k > 0 else [],
			"army_v": _army_value(tm)})
	lay_rows.append(row)


func _finish() -> void:
	_lay_snap()
	var st: Array = []
	for tm in n:
		st.append([g.starts[tm].x, g.starts[tm].y])
	var f := FileAccess.open(out.path_join("layout.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"size": [Game.W, Game.H], "starts": st, "sides": g.sides, "rows": lay_rows}))
	f.close()
	super._finish()
