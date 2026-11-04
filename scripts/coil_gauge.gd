class_name CoilGauge
extends RefCounted
## THE MAINSPRING'S COIL GAUGE (the owner, 2026-11-04: "an indicator of how pressed it is, like a bar, but the bar itself
## is a COIL, and the coil presses as it shows how much Tension the Mainspring has"). Drawn in code over every finished
## Mainspring (Building._draw_building, in its bar stack: Building.bar_slots), for its side and allies (the production
## bars' rule; spectators and the demo too).
##
## A brass spring lies in a dark slot. Its left end sits on a fixed plate; a pressing plate on a steel rod comes in from
## the right. EMPTY: the spring is relaxed and runs the whole slot. As the side's Tension rises toward what its Mainsprings
## store (GearEcon.tension_cap: 200 a small gear, 400 a big one; every Mainspring shows the side's one pool), the plate
## drives in and the coils press together; FULL: the coils touch, short and bright, the rod all the way in. FATIGUED
## (Building.fatigued: its Clocktower's spring life is spent): the same spring gone dull, grey-brown and slack, sagging in
## the middle.
## Cheap: two draw_multiline calls for the wire (its back half, then its front half) over a few rects; the points go into
## two arrays made once and reused. Code-drawn: docs/art_style_inconsistency.md.

const H := 10.0                 # the gauge's height (px), the slot's included
const TURNS := 8                # coils in the spring
const SEG := 8                  # wire segments a turn
const WIRE := 1.5               # the front wire's width
const TIGHT := 2.3              # px a turn takes when pressed solid
const LOOP := 1.6               # half the slant of each turn (px): the loops read as a coil, not a wave

const RIM := Color(0.52, 0.38, 0.16, 0.95)
const SLOT := Color(0.06, 0.05, 0.04, 0.85)
const ROD := Color(0.62, 0.64, 0.66)
const PLATE := Color(0.86, 0.66, 0.3)
const BRASS := Color(0.98, 0.8, 0.38)
const BRASS_BACK := Color(0.5, 0.34, 0.12)
const BRASS_TIGHT := Color(1.0, 0.9, 0.55)
const SET := Color(0.6, 0.55, 0.47)          # fatigued: the spring has taken a set
const SET_BACK := Color(0.3, 0.27, 0.23)

static var _front := PackedVector2Array()
static var _back := PackedVector2Array()


## The spring's length in px for a gauge `w` wide at fill f (0 empty .. 1 full).
static func length(w: float, f: float) -> float:
	var inner := w - 8.0
	var tight := minf(float(TURNS) * TIGHT, inner)
	return lerpf(inner, tight, clampf(f, 0.0, 1.0))


## Draw the gauge on ci in rect r (local px), filled to f; `tired`: fatigued.
static func draw(ci: CanvasItem, r: Rect2, f: float, tired: bool) -> void:
	f = clampf(f, 0.0, 1.0)
	if _front.size() != TURNS * SEG:
		_front.resize(TURNS * SEG)
		_back.resize(TURNS * SEG)
	ci.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.8))
	ci.draw_rect(r, SLOT)
	ci.draw_rect(r, RIM, false, 1.0)
	var cy := r.position.y + r.size.y * 0.5
	var x0 := r.position.x + 2.0                 # the fixed plate
	var l := length(r.size.x, f)
	var xp := x0 + 2.0 + l                       # the pressing plate
	# the rod that drives the plate in, from the slot's right end
	ci.draw_line(Vector2(xp + 2.0, cy), Vector2(r.end.x - 1.0, cy), ROD, 2.0)
	# the wire: a helix seen from the side (each turn a slanted loop), its far half drawn first and darker
	var amp := (r.size.y * 0.5 - 1.5) * (0.75 if tired else 1.0)
	var n := TURNS * SEG
	var fi := 0
	var bi := 0
	var prev := Vector2.ZERO
	for i in n + 1:
		var u := float(i) / float(n)
		var a := u * TAU * float(TURNS)
		var p := Vector2(x0 + 2.0 + l * u + LOOP * sin(a), cy - amp * cos(a))
		if tired:
			p.y += 1.3 * sin(PI * u) + 0.4 * sin(u * 17.0)       # (slack: it sags, its turns uneven)
		if i > 0:
			var am := (float(i) - 0.5) / float(SEG) * TAU
			if sin(am) >= 0.0:
				_front[fi] = prev
				_front[fi + 1] = p
				fi += 2
			else:
				_back[bi] = prev
				_back[bi + 1] = p
				bi += 2
		prev = p
	var front := SET if tired else BRASS.lerp(BRASS_TIGHT, smoothstep(0.7, 1.0, f))
	ci.draw_multiline(_back, SET_BACK if tired else BRASS_BACK, 1.0)
	ci.draw_multiline(_front, front, WIRE)
	# the plates
	var pc := SET if tired else PLATE
	ci.draw_rect(Rect2(x0, r.position.y + 1.0, 2.0, r.size.y - 2.0), pc.darkened(0.25))
	ci.draw_rect(Rect2(xp, r.position.y + 1.0, 2.0, r.size.y - 2.0), pc)
	if f >= 0.995 and not tired:
		ci.draw_rect(r.grow(0.5), Color(1.0, 0.85, 0.4, 0.55), false, 1.0)      # (wound tight: a bright rim)
