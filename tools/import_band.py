#!/usr/bin/env python3
"""The Marching Band's musicians from the owner's ChatGPT sheets (2026-11-05; docs/marching_band.md "The art"):

  art/redraws/band_drummer_walk_se_chatgpt.png     the Drummer    (4 frames marching and playing, south-east view)
  art/redraws/band_fifer_walk_se_chatgpt.png       the Fifer, option A
  art/redraws/band_fifer_walk_se_b_chatgpt.png     the Fifer, option B (FIFER below picks one: see the doc)
  art/redraws/band_piper_walk_se_chatgpt.png       the Piper
  (1536 x 1024 each, one row of 4 figures on navy #001630, about 6 sheet pixels to a game pixel)

The band is drawn as a GROUP THAT GROWS (scripts/marching_band.gd): the Drummer is the unit's own sprite (art "band"),
the Fifer and the Piper (arts "band_fifer", "band_piper") are child sprites placed side by side with him in a row (band-v2), each only
once researched. Each musician gets:
      walk_se   4 frames   (the sheet's row)
      idle_se   4 frames   (the same frames: Unit plays idle at 2 frames a second, marking time in place, still playing)
      death_se  3 frames   (CODE-MADE: the first walk frame tipped over 35, 70 and 90 degrees about his feet;
                            docs/art_style_inconsistency.md)
Only the SE view exists yet: Unit._set_anim falls back to the nearest drawn view (every view shows SE, the west ones
mirrored). The owner will draw S, E, NE, N later (docs/art_redraw_queue.md): save each as
art/redraws/band_<drummer|fifer|piper>_walk_<s|e|ne|n>_chatgpt.png and run this again (sheets_of finds them).
(MarchingBand.group_look takes the Drummer's view for the Fifer and the Piper; their places, MarchingBand.SPOT, are set
for the SE view: give it a place per view then.)

One scale per sheet: hat top to soles = BODY_H game px (the median over its frames; the hat's top is the first row at
least HAT_W sheet pixels wide, so the drumsticks, the drones and the flag don't count). Every frame: soles on the
anchor row, centred on the middle of his coat. Colours: below the head, the reds (coat, the drum's hoops, the pipes'
bag) are snapped to the team key reds (import_art.snap_team), so the band wears its side's colour like a Musketeer.

Writes assets/units/band{,_fifer,_piper}/<anim>_se.png and scripts/band_art.gd (BandArt.ART, merged into ArtData.UNITS).
Usage (repo root): python3 tools/import_band.py [--contact FILE]; then godot --headless --import."""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import snap_team  # noqa: E402
from import_cannon2 import clean  # noqa: E402
from import_cuirassier_dismounted import row_bands, figures  # noqa: E402
from redraw_lib import shrink  # noqa: E402

FIFER = "b"            # "" = option A, "b" = option B (measured: see main's printout and docs/marching_band.md)
WHO = {"band": "drummer", "band_fifer": "fifer", "band_piper": "piper"}
DIRS = ["s", "se", "e", "ne", "n"]
# (the SE sheets; a view's own sheet art/redraws/band_<who>_walk_<dir>_chatgpt.png is used when it exists)
SHEETS = {"band": "art/redraws/band_drummer_walk_se_chatgpt.png",
          "band_fifer": "art/redraws/band_fifer_walk_se%s_chatgpt.png" % ("_b" if FIFER else ""),
          "band_piper": "art/redraws/band_piper_walk_se_chatgpt.png"}


def sheets_of(art):
    """{view: sheet} for every view drawn so far (SE always)."""
    out = {}
    for d in DIRS:
        p = SHEETS[art] if d == "se" else "art/redraws/band_%s_walk_%s_chatgpt.png" % (WHO[art], d)
        if os.path.exists(p):
            out[d] = p
    return out
CELL = (44, 46)
ANCHOR = (22, 44)      # soles on row 43
BODY_H = 34            # hat top to soles, game px (a Musketeer is ~33-35 in his 36 px strips)
HAT_W = 24             # sheet px: a row this wide is the hat, not a stick or a drone
HEAD = 10              # game rows from the hat's top kept out of the team snap (faces, the plume)


def load(sheet):
    px = np.asarray(Image.open(sheet).convert("RGB")).astype(int)
    b = 6
    edge = np.concatenate([px[:b].reshape(-1, 3), px[-b:].reshape(-1, 3), px[:, :b].reshape(-1, 3), px[:, -b:].reshape(-1, 3)])
    bg = np.median(edge, 0)
    fg = np.abs(px - bg).max(-1) > 24
    return px, fg, bg


def hat_top(f):
    man = f["man"]
    w = man.sum(1)
    rows = np.nonzero(w >= HAT_W)[0]
    return int(rows.min()) if len(rows) else f["top"]


def body_mid(f):
    """The coat's middle: median column of the man's pixels 35-65% of the way from hat to soles."""
    man = f["man"]
    t = hat_top(f)
    h = f["sole"] - t
    xs = np.nonzero(man[t + int(h * 0.35):t + int(h * 0.65)])[1]
    lo, hi = np.percentile(xs, [20, 80])
    return float(np.median(xs[(xs >= lo) & (xs <= hi)]))


def to_cell(f, scale):
    small = clean(shrink(f["img"], scale))
    cx = body_mid(f) * scale
    sole = (f["sole"] + 1) * scale
    out = np.zeros((CELL[1], CELL[0], 4), np.uint8)
    x = int(round(ANCHOR[0] - cx))
    y = int(round(ANCHOR[1] - sole))
    h, w = small.shape[:2]
    sx0, sy0 = max(0, -x), max(0, -y)
    dx0, dy0 = max(0, x), max(0, y)
    ww, hh = min(w - sx0, CELL[0] - dx0), min(h - sy0, CELL[1] - dy0)
    part = small[sy0:sy0 + hh, sx0:sx0 + ww]
    m = part[..., 3] > 0
    lost = int((small[..., 3] > 0).sum() - m.sum())
    assert lost <= 3, "%d px cut off the cell" % lost
    out[dy0:dy0 + hh, dx0:dx0 + ww][m] = part[m]
    head = int(round(ANCHOR[1] - (f["sole"] + 1 - hat_top(f)) * scale)) + HEAD
    body = out.copy()
    snap_team(body)
    body[:max(0, head)] = out[:max(0, head)]
    return body


def fall(cell, deg):
    """The standing frame tipped over `deg` degrees about his feet (backwards), lying on the ground, the body
    centred in the cell (he lies where he fell)."""
    W = CELL[0] * 3
    big = np.zeros((CELL[1], W, 4), np.uint8)
    big[:, CELL[0]:CELL[0] * 2] = cell
    piv = (CELL[0] + ANCHOR[0], ANCHOR[1] - 1)
    a = np.asarray(Image.fromarray(big).rotate(deg, resample=Image.NEAREST, center=piv)).copy()
    ys = np.nonzero(a[..., 3].any(1))[0]
    if len(ys) and ys.max() < ANCHOR[1] - 1:
        a = np.roll(a, ANCHOR[1] - 1 - ys.max(), 0)      # (lying on the ground, not floating)
    xs = np.nonzero(a[..., 3].any(0))[0]
    mid = int(round((xs.min() + xs.max()) / 2.0))
    x0 = max(0, min(W - CELL[0], mid - ANCHOR[0]))
    return np.ascontiguousarray(a[:, x0:x0 + CELL[0]])


def stride(cells):
    """The feet's spread (px) over the frames: the widest bottom-4-rows span, and the mean."""
    sp = []
    for c in cells:
        xs = np.nonzero(c[ANCHOR[1] - 4:ANCHOR[1], :, 3].any(0))[0]
        sp.append(int(xs.max() - xs.min() + 1) if len(xs) else 0)
    return max(sp), float(np.mean(sp))


def height(cells):
    """Hat-to-soles height in game px as cut (the first row at least 7 px wide)."""
    hs = []
    for c in cells:
        w = (c[..., 3] > 0).sum(1)
        rows = np.nonzero(w >= 7)[0]
        hs.append(int(ANCHOR[1] - rows.min()))
    return float(np.median(hs))


def cut(sheet):
    px, fg, bg = load(sheet)
    band = row_bands(fg, 1)[0]
    men = figures(px, fg, bg, band, 4)
    hs = [m["sole"] + 1 - hat_top(m) for m in men]
    scale = BODY_H / float(np.median(hs))
    return [to_cell(m, scale) for m in men], scale


def write_art(views):
    lines = ["class_name BandArt",
             "## Generated by tools/import_band.py - do not edit by hand. The Marching Band's three musicians (only the SE",
             "## view so far: Unit falls back to it for every view). Merged into ArtData.UNITS.", "",
             "const ART := {"]
    for a, ds in views.items():
        lines.append('\t"%s": {"cell": Vector2i(%d, %d), "anchor": Vector2(%d, %d), "frames": {' % (a, CELL[0], CELL[1], ANCHOR[0], ANCHOR[1]))
        for k, n in sorted([("death_" + d, 3) for d in ds] + [("idle_" + d, 4) for d in ds] + [("walk_" + d, 4) for d in ds]):
            lines.append('\t\t"%s": %d,' % (k, n))
        lines.append("\t}},")
    lines.append("}")
    open("scripts/band_art.gd", "w").write("\n".join(lines) + "\n")


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    if "--compare-fifers" in sys.argv:
        for name, sh in (("drummer", SHEETS["band"]), ("fifer A", "art/redraws/band_fifer_walk_se_chatgpt.png"),
                         ("fifer B", "art/redraws/band_fifer_walk_se_b_chatgpt.png"), ("piper", SHEETS["band_piper"])):
            px, fg, bg = load(sh)
            men = figures(px, fg, bg, row_bands(fg, 1)[0], 4)
            raw_h = [m["sole"] + 1 - hat_top(m) for m in men]
            sp = []
            for m in men:
                xs = np.nonzero(m["man"][m["sole"] - 20:m["sole"] + 1].any(0))[0]
                sp.append(int(xs.max() - xs.min() + 1))
            legs = [m["sole"] - int(np.nonzero(m["man"].sum(1) >= 0.6 * m["man"].sum(1).max())[0].max()) for m in men]
            print("%-8s sheet px: height %s  stride %s  under the widest row %s" % (name, raw_h, sp, legs))
        return
    strips = []
    views = {}
    for art in SHEETS:
        views[art] = []
        for d, sheet in sheets_of(art).items():
            cells, scale = cut(sheet)
            os.makedirs("assets/units/" + art, exist_ok=True)
            walk = np.concatenate(cells, 1)
            Image.fromarray(walk).save("assets/units/%s/walk_%s.png" % (art, d))
            Image.fromarray(walk).save("assets/units/%s/idle_%s.png" % (art, d))
            death = [fall(cells[0], a) for a in (35, 70, 90)]
            Image.fromarray(np.concatenate(death, 1)).save("assets/units/%s/death_%s.png" % (art, d))
            print("%-11s %-2s scale %.4f  height %.1f px  stride %s" % (art, d, scale, height(cells), stride(cells)))
            strips.append(cells + death)
            views[art].append(d)
    write_art(views)
    if "--contact" in sys.argv:
        rows = [np.concatenate(s, 1) for s in strips]
        sheet = Image.new("RGBA", (rows[0].shape[1] * 4, sum(r.shape[0] for r in rows) * 4), (104, 132, 84, 255))
        y = 0
        for r in rows:
            im = Image.fromarray(r)
            sheet.alpha_composite(im.resize((im.width * 4, im.height * 4), Image.NEAREST), (0, y))
            y += r.shape[0] * 4
        sheet.save(sys.argv[sys.argv.index("--contact") + 1])


if __name__ == "__main__":
    main()
