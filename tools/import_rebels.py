"""The Free Assembly's sprites (campaign mission 1, docs/rebel_art.md) from the owner's four ChatGPT sheets:

  art/campaign/rebels/militia_chatgpt.png      -> assets/units/rebel_militia/   (plays as the Musketeer)
  art/campaign/rebels/pikeman_chatgpt.png      -> assets/units/rebel_pikeman/   (the Pikeman)
  art/campaign/rebels/torchbearer_chatgpt.png  -> assets/units/rebel_torch/     (the Labourer, with a torch)
  art/campaign/rebels/varenne_chatgpt.png      -> assets/units/rebel_varenne/   (the dismounted Officer)

Each sheet: figures on a flat grey ground, five DIRECTION groups left to right (s, se, e, ne, n; the pikeman,
torch-bearer and Varenne sheets have thin divider lines between them, the militia sheet only one after the s group)
and one ROW per animation. How a sheet is cut:
  1. the grey ground keyed out (its colour = the median of the sheet's border), the divider lines removed;
  2. figures = connected pieces; smoke puffs (light, grey) dropped; small pieces (a muzzle flash, a flame, the tip
     of a pike cut off by a gap) given to the nearest figure within reach, else dropped;
  3. pieces holding SEVERAL men (pikes or muskets laid over the next man) split by their BODIES: columns where the
     piece is tall; a pixel inside a body's columns is that man's, one outside goes to the nearest body on its
     left (the weapons point to the right) or simply the nearest one (ROW_RULE);
  4. rows = the men's soles clustered; groups = the body's middle against the group edges;
  5. scaled so hat to soles of the idle row is BODY_H game px (the Crown's Musketeer: 30), soles on the cell's
     ground row, the body's middle on the anchor; painted colours kept (no team key reds: the rebels stay green and
     black whatever their side's colour), any exact key red nudged off it (import_art.unteam).
Animations the sheets lack are filled from the nearest drawn frames (STAND_INS, listed in docs/rebel_art.md).

Writes the strips and prints the RebelArt.ART entries (scripts/campaign/rebel_art.gd is written by --write).

Usage (repo root): python3 tools/import_rebels.py [--contact DIR] [--write]
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import unteam  # noqa: E402
from import_cannon2 import clean  # noqa: E402
from redraw_lib import DIRS5, runs, shrink  # noqa: E402

SHEETS = {
	# art: (sheet, group edges x, row animations, hat-to-soles game px)
	"rebel_militia": ("militia", [0, 270, 560, 955, 1245, 1536],
		["idle", "walk", "aim", "fire", "reload_a", "reload_b", "death"], 30),
	"rebel_pikeman": ("pikeman", [0, 295, 588, 912, 1219, 1536],
		["idle", "walk", "brace", "attack", "unarmed", "death"], 30),
	"rebel_torch": ("torchbearer", [0, 295, 588, 912, 1219, 1536],
		["idle", "walk", "setfire", "thrust", "crouch", "death"], 30),
	"rebel_varenne": ("varenne", [0, 295, 588, 912, 1219, 1536],
		["idle", "walk", "shout", "pistol", "sabre", "death"], 31),
}
# rows whose weapons point right (a piece's pixels outside every body go to the body on their left)
ROW_RULE = {"aim": "left", "fire": "left", "brace": "left", "attack": "left", "thrust": "left", "pistol": "left",
	"sabre": "near", "setfire": "left"}
# frames picked out of a drawn row: (art, anim) -> {dir: [indices]} (default: every frame)
PICK = {
	("rebel_militia", "idle"): {"e": [0, 1]},      # the e group's idle has two pairs: the first is the side view
}
BIG = 1100            # sheet px: a piece this big is (part of) a man
ATTACH = 26           # sheet px: a small piece this close to a man is his (a flash, a flame, a pike's tip)
BODY_COL = 22         # sheet px: a column at least this tall in a piece is a man's body
GROUND_PAD = 2        # game px from the soles to the cell's bottom edge


def load(name):
	px = np.asarray(Image.open("art/campaign/rebels/%s_chatgpt.png" % name).convert("RGB")).astype(int)
	border = np.concatenate([px[:4].reshape(-1, 3), px[-4:].reshape(-1, 3), px[:, :4].reshape(-1, 3),
		px[:, -4:].reshape(-1, 3)])
	bg = np.median(border, 0)
	fg = np.abs(px - bg).max(-1) > 20
	# the divider lines: columns lit over most of the sheet's height (and their neighbours)
	cols = [c for c in range(fg.shape[1]) if max([b - a for a, b in runs(fg[:, c], 1, 1)] or [0]) > 330]
	for c in cols:
		fg[:, max(0, c - 2):c + 3] = False
	lab, _n = ndimage.label(fg, structure=np.ones((3, 3)))
	for i, o in enumerate(ndimage.find_objects(lab)):
		if o is None:
			continue
		h, w = o[0].stop - o[0].start, o[1].stop - o[1].start
		if w <= 6 and h > 120:
			fg[o][lab[o] == i + 1] = False
	return px, fg, bg


def is_smoke(px, m):
	rgb = px[m].astype(float)
	lum = rgb.mean(1)
	sat = rgb.max(1) - rgb.min(1)
	return np.median(lum) > 105 and np.median(sat) < 40


def bodies(mask, dark=None):
	"""[(x0, x1)] column runs of a piece's mask where it is tall (a man's body), in the mask's own columns; a run must
	reach down to the piece's ground (a raised torch, a pike's shaft are tall too, but stand on nothing)"""
	h = mask.shape[0]
	cnt = mask.sum(0)
	out = []
	for a, b in runs(cnt >= max(BODY_COL, 0.4 * h), 6, 16):
		low = np.nonzero(mask[:, a:b].any(1))[0].max()
		if dark is not None:
			dk = (dark[:, a:b] & mask[:, a:b]).sum()
			if dk < 250 or dk < 0.5 * mask[:, a:b].sum():
				continue      # (a burning torch on the ground: bright)
		if low >= h - 14:
			out.append((a, b))
	return out


def figures(px, fg):
	"""every man of the sheet: dicts {mask (full sheet bool, cropped by box), box, cx (body middle), sole}"""
	lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
	objs = ndimage.find_objects(lab)
	sizes = ndimage.sum(fg, lab, range(1, n + 1))
	men, small = [], []
	for i, o in enumerate(objs):
		m = lab[o] == i + 1
		if sizes[i] >= BIG:
			if is_smoke(px[o], m):
				continue
			men.append((o, m))
		elif sizes[i] >= 6:
			small.append((o, m))
	figs = []
	for o, m in men:
		y0, x0 = o[0].start, o[1].start
		lum = px[o].mean(-1)
		bs = bodies(m, lum < 90)
		if not bs or ((lum < 90) & m).sum() < max(500, 0.35 * m.sum()):
			small.append((o, m))      # (a dropped torch, a lone flame: not a man)
			continue
		if len(bs) == 1:
			b = bs[0]
			figs.append({"o": o, "m": m, "cx": x0 + (b[0] + b[1]) / 2.0, "body": (x0 + b[0], x0 + b[1])})
			continue
		# several men in one piece: split when the row's rule is known (assemble)
		for k, (a, b) in enumerate(bs):
			figs.append({"o": o, "m": m, "cx": x0 + (a + b) / 2.0, "body": (x0 + a, x0 + b), "_split": (bs, k)})
	return figs, small


def attach(px, figs, small):
	"""the small pieces (a flash, a flame, a torch's head): to the man nearest by pixels, within reach; in a row
	whose weapons point right, a man on the piece's left first"""
	for o, m in small:
		if is_smoke(px[o], m):
			continue
		pad = ATTACH + 2
		y0, y1 = max(0, o[0].start - pad), o[0].stop + pad
		x0, x1 = max(0, o[1].start - pad), o[1].stop + pad
		cands = []
		for f in figs:
			fo = f["o"]
			if fo[0].stop < y0 or fo[0].start > y1 or fo[1].stop < x0 or fo[1].start > x1:
				continue
			fm = np.zeros((y1 - y0 + 1, x1 - x0 + 1), bool)
			oy0, ox0 = max(fo[0].start, y0), max(fo[1].start, x0)
			oy1, ox1 = min(fo[0].stop, y1 + 1), min(fo[1].stop, x1 + 1)
			fm[oy0 - y0:oy1 - y0, ox0 - x0:ox1 - x0] = f["own"][oy0 - fo[0].start:oy1 - fo[0].start, ox0 - fo[1].start:ox1 - fo[1].start]
			if not fm.any():
				continue
			dist = ndimage.distance_transform_edt(~fm)
			sm = np.zeros_like(fm)
			sm[o[0].start - y0:o[0].stop - y0, o[1].start - x0:o[1].stop - x0] = m
			d = dist[sm].min()
			if d <= ATTACH:
				cands.append((d, f))
		if not cands:
			continue
		rule = cands[0][1].get("rule", "near")
		if rule == "left":
			lefts = [c for c in cands if c[1]["cx"] < (o[1].start + o[1].stop) / 2.0]
			if lefts:
				cands = lefts
		best = min(cands, key=lambda c: c[0])[1]
		best.setdefault("extra", []).append((o, m))


FLAME = None       # [mask of the piece being split] (bright orange: a torch's fire), set by figures' caller


def flame_mask(rgb):
	return (rgb[..., 0] > 170) & (rgb[..., 1] > 70) & (rgb[..., 2] < 110) & (rgb[..., 0] - rgb[..., 2] > 90)


def split(m, bs, k, rule):
	"""man k's share of a piece holding several men (bodies bs)"""
	h, w = m.shape
	cols = np.full(w, -1)
	for i, (a, b) in enumerate(bs):
		cols[max(0, a - 1):b + 1] = i
	owner = np.where(m, cols[None, :].repeat(h, 0), -1)
	out = m & (owner < 0)
	xs = np.arange(w)[None, :].repeat(h, 0)
	mids = np.array([(a + b) / 2.0 for a, b in bs])
	if rule == "pike":
		# the pikes are straight and parallel: find their slope, then each pike's line (its intercept); a pike
		# belongs to the man at its butt (the left end: they point right)
		ys, xx = np.nonzero(out)
		if len(xx):
			best, bsl = -1, 0.0
			for sl in np.arange(-0.8, 0.81, 0.01):
				hist = np.bincount(np.round(ys - sl * xx).astype(int) - int(np.floor((ys - sl * xx).min())))
				sc = (hist.astype(float) ** 2).sum()
				if sc > best:
					best, bsl = sc, sl
			bvals = ys - bsl * xx
			order = np.argsort(bvals)
			groups, cur = [], [order[0]]
			for i in order[1:]:
				if bvals[i] - bvals[cur[-1]] > 2.5:
					groups.append(cur)
					cur = []
				cur.append(i)
			groups.append(cur)
			for g in groups:
				g = np.array(g)
				xmin = xx[g].min()
				who = next((i for i, (a, b) in enumerate(bs) if b + 6 >= xmin), len(bs) - 1)
				owner[ys[g], xx[g]] = who
	else:
		# connectivity: what joins man k's body once the other men's bodies are cut away
		claims = []
		for i in range(len(bs)):
			reg = m & ((owner == i) | (owner < 0))
			lab, _n = ndimage.label(reg, structure=np.ones((3, 3)))
			ids = np.unique(lab[owner == i])
			ids = ids[ids > 0]
			claims.append(np.isin(lab, ids) & (owner < 0))
		claims = np.array(claims)
		nc = claims.sum(0)
		left_of = np.clip(np.searchsorted(mids, xs, side="right") - 1, 0, len(bs) - 1)
		near = np.abs(xs[..., None] - mids[None, None, :]).argmin(-1)
		first = claims.argmax(0)
		pick = np.where(nc == 1, first, left_of if rule == "left" else near)
		# shared: of the claimants, by the rule (left: the nearest claimant on the left)
		owner = np.where(out, pick, owner)
	if rule == "left" and FLAME is not None:
		# a torch's flame reaching over the next man's back is still the torch's: a flame blob goes whole to the man
		# whose body's middle is the last one left of the blob's middle
		fl = m & FLAME[0]
		lab, n = ndimage.label(ndimage.binary_dilation(fl, iterations=2) & m, structure=np.ones((3, 3)))
		for i, sl in enumerate(ndimage.find_objects(lab)):
			bm = lab == i + 1
			if bm.sum() < 20:
				continue
			c = (sl[1].start + sl[1].stop) / 2.0
			who = max([j for j in range(len(bs)) if mids[j] < c] or [0])
			owner[bm] = who
	return m & (owner == k)


def smoke_px(px, o):
	"""light grey pixels (a smoke puff fused with the muzzle flash) of a box"""
	rgb = px[o].astype(int)
	return (rgb.mean(-1) > 95) & ((rgb.max(-1) - rgb.min(-1)) < 40)


def assemble(px, f):
	"""a man as an RGBA image over his own box, and that box (x0, y0)"""
	o, m = f["o"], f["own"].copy()
	parts = [(o, m)] + [(eo, em & ~smoke_px(px, eo)) for eo, em in f.get("extra", [])]
	y0 = min(p[0][0].start for p in parts)
	y1 = max(p[0][0].stop for p in parts)
	x0 = min(p[0][1].start for p in parts)
	x1 = max(p[0][1].stop for p in parts)
	full = np.zeros((y1 - y0, x1 - x0), bool)
	for po, pm in parts:
		full[po[0].start - y0:po[0].stop - y0, po[1].start - x0:po[1].stop - x0] |= pm
	# smoke puffs fused with the muzzle flash or the musket: big light grey clusters (and their grey fringe) go
	rgb = px[y0:y1, x0:x1].astype(int)
	lum, sat = rgb.mean(-1), rgb.max(-1) - rgb.min(-1)
	grey = full & (lum > 95) & (sat < 40)
	lab, n = ndimage.label(grey, structure=np.ones((3, 3)))
	if n:
		sz = ndimage.sum(grey, lab, range(1, n + 1))
		round_ = np.zeros(n + 1, bool)
		for i, sl in enumerate(ndimage.find_objects(lab)):
			hh, ww = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
			round_[i + 1] = sz[i] >= 150 and max(hh, ww) <= 2.2 * min(hh, ww) and sz[i] >= 0.35 * hh * ww
		puff = round_[lab] & (lab > 0)      # (a puff is round and full; a sabre's blade, a musket's barrel are long)
		if puff.any():
			near = ndimage.binary_dilation(puff, iterations=3)
			full &= ~(puff | (near & (lum > 75) & (sat < 45)))
			lab2, n2 = ndimage.label(full, structure=np.ones((3, 3)))
			if n2 > 1:
				sz2 = ndimage.sum(full, lab2, range(1, n2 + 1))
				full &= (sz2 >= 0.02 * sz2.max())[lab2 - 1] & (lab2 > 0)
	return full, (x0, y0)


def hat_top(img):
	a = img[..., 3] > 0
	lum = img[..., :3].astype(int).sum(-1) / 3.0
	rows = np.nonzero((a & (lum < 75)).sum(1) >= 14)[0]
	return int(rows.min()) if len(rows) else int(np.nonzero(a.any(1))[0].min())


def cut_sheet(art):
	name, edges, anims, body_h = SHEETS[art]
	px, fg, _bg = load(name)
	figs, small = figures(px, fg)
	# rows: cluster the soles (the body's lowest pixel)
	for f in figs:
		ys = np.nonzero(f["m"].any(1))[0]
		f["sole"] = f["o"][0].start + ys.max()
	soles = sorted(f["sole"] for f in figs)
	bands, cur = [], [soles[0]]
	for s in soles[1:]:
		if s - cur[-1] > 40:
			bands.append(cur)
			cur = []
		cur.append(s)
	bands.append(cur)
	assert len(bands) == len(anims), (art, [(b[0], b[-1]) for b in bands])
	rows = {a: {d: [] for d in DIRS5} for a in anims}
	for f in figs:
		r = next(i for i, b in enumerate(bands) if b[0] <= f["sole"] <= b[-1])
		f["anim"] = anims[r]
		f["rule"] = ROW_RULE.get(f["anim"], "near")
		if "_split" in f:
			global FLAME
			FLAME = [flame_mask(px[f["o"]])]
			f["own"] = split(f["m"], f["_split"][0], f["_split"][1], f["rule"])
		else:
			f["own"] = f["m"]
	# a "man" that is mostly fire is a torch lying on the ground (or flying off): a small piece for its owner
	keep = []
	for f in figs:
		own = f["own"]
		if (flame_mask(px[f["o"]]) & own).sum() > 0.2 * own.sum():
			small.append((f["o"], own))
		else:
			keep.append(f)
	figs = keep
	attach(px, figs, small)
	for f in figs:
		g = int(np.searchsorted(edges, f["cx"], side="right") - 1)
		g = min(max(g, 0), 4)
		anim = f["anim"]
		mask, (x0, y0) = assemble(px, f)
		h, w = mask.shape
		img = np.zeros((h, w, 4), np.uint8)
		img[..., :3] = px[y0:y0 + h, x0:x0 + w]
		img[..., 3] = np.where(mask, 255, 0)
		rows[anim][DIRS5[g]].append({"img": img, "x0": x0, "y0": y0, "cx": f["cx"] - x0, "sx": f["cx"]})
	for a in anims:
		for d in DIRS5:
			rows[a][d].sort(key=lambda e: e["sx"])
			pick = PICK.get((art, a), {}).get(d)
			if pick is not None:
				rows[a][d] = [rows[a][d][i] for i in pick]
	# scale: hat to soles of the idle row
	hs = []
	for d in DIRS5:
		for e in rows["idle"][d]:
			ys = np.nonzero(e["img"][..., 3].any(1))[0]
			hs.append(ys.max() - hat_top(e["img"]) + 1)
	scale = body_h / float(np.median(hs))
	print(art, "idle hat to soles (sheet px)", sorted(hs), "scale %.4f" % scale)
	return rows, scale


def small_of(e, scale):
	s = shrink(e["img"], scale, 0.4)
	s = unteam(clean(s))
	ys = np.nonzero(s[..., 3].any(1))[0]
	return s, e["cx"] * scale, (ys.max() if len(ys) else s.shape[0] - 1)


def place(frames, cell, anchor):
	cells = []
	for s, cx, sole in frames:
		out = np.zeros((cell[1], cell[0], 4), np.uint8)
		x = int(round(anchor[0] - cx))
		y = int(round(anchor[1] - 1 - sole))
		h, w = s.shape[:2]
		sx0, sy0 = max(0, -x), max(0, -y)
		dx0, dy0 = max(0, x), max(0, y)
		ww, hh = min(w - sx0, cell[0] - dx0), min(h - sy0, cell[1] - dy0)
		if ww > 0 and hh > 0:
			part = s[sy0:sy0 + hh, sx0:sx0 + ww]
			mm = part[..., 3] > 0
			out[dy0:dy0 + hh, dx0:dx0 + ww][mm] = part[mm]
		cells.append(out)
	return cells


# the game's animations from the drawn rows: art -> anim -> [(row, frame indices or None = all)]
# (a dir that a row lacks falls back on the game's own nearest-direction rule)
BUILD = {
	"rebel_militia": {
		"idle": [("idle", None)], "walk": [("walk", None)], "aim": [("aim", None)], "fire": [("fire", None)],
		"reload": [("reload_a", None), ("reload_b", None)], "death": [("death", None)],
		# STAND-INS (docs/rebel_art.md): no bayonet row, no aiming up
		"melee": [("aim", [0, (0, 3), (0, 5), (0, 2)])],      # the levelled musket pushed forward: a thrust
		"aimup": [("aim", None)], "fireup": [("fire", None)],
	},
	"rebel_pikeman": {
		# the sheet draws each row's men overlapping (a pike runs over the next man): only the LAST man of a brace or
		# attack row keeps his whole pike, so the thrust is that man moved: drawn back, then lunging
		"idle": [("idle", None)], "walk": [("walk", None)], "brace": [("brace", [-1])],
		"attack": [("attack", [(-1, -7), (-1, -4), (-1, 1), (-1, 5), (-1, 2)])], "death": [("death", None)],
	},
	"rebel_torch": {
		"idle": [("idle", None)], "walk": [("walk", None)], "death": [("death", None)],
		# (the n group's walk and setting fire lose or double the torch from frame to frame in the sheet: STAND-INS)
		"walk@n": [("walk", [1, (1, 0, 1)])], "mine@n": [("idle", None)],
		"mine@se": [("setfire", [0]), ("thrust", None)],     # (the se group's second and third: the torch flies off)
		"mine": [("setfire", None), ("thrust", None)],      # setting fire: raise the torch, thrust it in
		"build": [("crouch", None)],                         # STAND-IN: the crouch row
	},
	"rebel_varenne": {
		"idle": [("idle", None)], "walk": [("walk", None)], "shout": [("shout", None)],
		"aim": [("pistol", [0])], "fire": [("pistol", "rest")], "melee": [("sabre", None)], "death": [("death", None)],
	},
}


def build(art, rows, scale):
	out = {}
	for anim, srcs in BUILD[art].items():
		if "@" in anim:
			continue
		for d in DIRS5:
			fr = []
			srcs = BUILD[art].get(anim + "@" + d, BUILD[art][anim])
			for row, idx in srcs:
				es = rows[row][d]
				if not es:
					continue
				if idx is None:
					fr += es
				elif idx == "rest":
					fr += es[1:] if len(es) > 1 else es
				else:
					for i in idx:
						i, dx, dy = (i, 0, 0) if isinstance(i, int) else (tuple(i) + (0,))[:3]
						if -len(es) <= i < len(es):
							fr.append(dict(es[i], dx=dx, dy=dy))
			if fr:
				out[(anim, d)] = []
				for e in fr:
					sm, cx, sole = small_of(e, scale)
					out[(anim, d)].append((sm, cx - e.get("dx", 0), sole - e.get("dy", 0)))
	# the cell: room for every frame around the anchor
	left = right = up = 0
	for frs in out.values():
		for s, cx, sole in frs:
			left = max(left, int(np.ceil(cx)) + 1)
			right = max(right, s.shape[1] - int(np.floor(cx)) + 1)
			up = max(up, sole + 2)
	half = max(left, right)
	cell = (2 * half + (2 * half) % 2, up + GROUND_PAD)
	anchor = (cell[0] // 2, cell[1] - GROUND_PAD)
	strips = {k: place(v, cell, anchor) for k, v in out.items()}
	return strips, cell, anchor


def contact(path, strips, cell, scale=3, only=None):
	from PIL import ImageDraw
	keys = sorted(k for k in strips if only is None or k[0] in only)
	W = max(len(strips[k]) for k in keys) * cell[0]
	H = len(keys) * (cell[1] + 2)
	sheet = Image.new("RGBA", (W * scale, H * scale), (104, 132, 84, 255))
	for i, k in enumerate(keys):
		im = Image.fromarray(np.concatenate(strips[k], 1))
		y = i * (cell[1] + 2)
		sheet.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (0, y * scale))
		ImageDraw.Draw(sheet).text((2, y * scale + 2), "%s_%s" % k, fill=(255, 255, 0, 255))
		for c in range(1, len(strips[k])):
			ImageDraw.Draw(sheet).line([(c * cell[0] * scale, y * scale), (c * cell[0] * scale, (y + cell[1]) * scale)], fill=(80, 100, 60, 255))
	sheet.save(path)


def gd_entry(art, cell, anchor, counts):
	lines = ['\t"%s": {"cell": Vector2i(%d, %d), "anchor": Vector2(%d, %d), "frames": {' % (art, cell[0], cell[1],
		anchor[0], anchor[1])]
	keys = sorted(counts, key=lambda k: (k.rsplit("_", 1)[0], DIRS5.index(k.rsplit("_", 1)[1])))
	anims = []
	for k in keys:
		a = k.rsplit("_", 1)[0]
		if a not in anims:
			anims.append(a)
	for a in anims:
		lines.append("\t\t" + ", ".join('"%s": %d' % (k, counts[k]) for k in keys if k.rsplit("_", 1)[0] == a) + ",")
	lines.append("\t\t}},")
	return "\n".join(lines)


def main():
	cdir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None
	entries = []
	for art in SHEETS:
		rows, scale = cut_sheet(art)
		strips, cell, anchor = build(art, rows, scale)
		print(art, "cell", cell, "anchor", anchor)
		d = "assets/units/%s" % art
		os.makedirs(d, exist_ok=True)
		for f in os.listdir(d):
			if f.endswith(".png"):
				os.remove(os.path.join(d, f))
		counts = {}
		for (anim, dr), cells in strips.items():
			Image.fromarray(np.concatenate(cells, 1)).save("%s/%s_%s.png" % (d, anim, dr))
			counts["%s_%s" % (anim, dr)] = len(cells)
		entries.append(gd_entry(art, cell, anchor, counts))
		if cdir:
			os.makedirs(cdir, exist_ok=True)
			anims = sorted(set(k[0] for k in strips))
			for i in range(0, len(anims), 3):
				contact(os.path.join(cdir, "%s_%d.png" % (art, i // 3)), strips, cell, only=anims[i:i + 3])
	text = "\n".join(entries)
	print(text)
	if "--write" in sys.argv:
		path = "scripts/campaign/rebel_art.gd"
		src = open(path).read()
		start = src.index("## REBELS-BEGIN")
		end = src.index("## REBELS-END")
		src = src[:start] + "## REBELS-BEGIN (written by tools/import_rebels.py)\n" + text + "\n\t" + src[end:]
		open(path, "w").write(src)


if __name__ == "__main__":
	main()
