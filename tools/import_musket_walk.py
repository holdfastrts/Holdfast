"""The Musketeer's WALK in the five drawn views (s, se, e, ne, n), from the owner's ChatGPT sheets (2026-11-07; before
them his legs were the labourer's, pasted in code by tools/import_crown_legs.py, and each view had its own frame count:
docs/art_redraw_queue.md item 9).

  art/redraws/musketeer_walk_<dir>_chatgpt.png   one row of six figures on navy: contact, down, passing, contact (the
      other foot), down, passing

Each sheet: the six men are the six tallest pieces (anything else joins the man nearest to it); one scale per sheet, so
that hat to soles over the middle of the red coat (a musket raised past the hat is not counted) is BODY_H px, as his
other poses (tools/import_musket_aim_dirs.py); centred on the middle of the red coat; soles on the cell's ground row.
FIXES (applied in game pixels after the cut): the east and north-east sheets drew a second musket barrel sticking out
behind his head (the owner, 2026-11-07: "there is something strange in his back"); it is erased (STRAY), and the north
sheet's back of the head, a flat brown blob, gets hair and a black ribbon (queue) like the other views.

Writes assets/units/musketeer/walk_<dir>.png (6 frames each) and the counts in scripts/art_data.gd. Then run
tools/import_vet_trim.py --only musketeer (the hat's lace takes the veterancy colour).
  python3 tools/import_musket_walk.py [dir ...] [--contact DIR]"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redraw_lib import contact, cut, is_red, load_sheet, save_strip, to_cell, write_counts  # noqa: E402

UNIT = "musketeer"
CELL = (90, 36)
ANCHOR = (45, 35)          # soles on row 34, as his other strips
BODY_H = 30                # hat to soles, game px
N = 6


def figures(name):
    """The six figures, left to right, as (rgba crop, the man's sole row in the crop, the man's height)."""
    px, fg = load_sheet(name)
    lab, n = ndimage.label(ndimage.binary_closing(fg, iterations=2) | fg)
    objs = ndimage.find_objects(lab)
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    pieces = [(i + 1, sl, int(sizes[i])) for i, sl in enumerate(objs) if sizes[i] >= 30]
    men = sorted(pieces, key=lambda p: -(p[1][0].stop - p[1][0].start))[:N]
    men.sort(key=lambda p: p[1][1].start)
    groups = {p[0]: [p] for p in men}
    for p in pieces:
        if p[0] in groups:
            continue
        cx = (p[1][1].start + p[1][1].stop) / 2.0
        best = min(men, key=lambda m: abs(cx - (m[1][1].start + m[1][1].stop) / 2.0))
        groups[best[0]].append(p)
    out = []
    for m in men:
        g = groups[m[0]]
        y0 = min(p[1][0].start for p in g)
        y1 = max(p[1][0].stop for p in g)
        x0 = min(p[1][1].start for p in g)
        x1 = max(p[1][1].stop for p in g)
        keep = np.isin(lab[y0:y1, x0:x1], [p[0] for p in g])
        sub_fg = np.zeros_like(fg)
        sub_fg[y0:y1, x0:x1] = fg[y0:y1, x0:x1] & keep
        img = cut(px, sub_fg, (x0, y0, x1, y1), keep_frac=0.0)
        sole = int(np.nonzero(img[..., 3].any(1))[0].max())
        out.append((img, sole, sole - head_top(img)))
    return out


def head_top(img):
    """The top of the hat over the middle of the red coat (a musket raised past the hat lies to the side of it)."""
    a = img[..., 3] > 0
    red = is_red(img[..., :3].astype(int), a)
    xs = np.nonzero(red)[1]
    cx = int(np.median(xs)) if len(xs) > 8 else img.shape[1] // 2
    cols = a[:, max(0, cx - 10):cx + 11]
    return int(np.nonzero(cols.any(1))[0].min())


def is_steel_or_wood(c):
    r, g, b = int(c[0]), int(c[1]), int(c[2])
    grey = abs(r - g) < 22 and abs(g - b) < 26 and r > 70           # the barrel: steel greys
    wood = r > 70 and r > g + 18 and g > b and b < 90 and r < 200     # the stock: browns
    return grey or wood


def erase_stray(cell, rule):
    """A second barrel sticking out behind his head on the left (east and north-east sheets): under the hat's crown,
    down to the coat's top row, every pixel at or left of the hat's left edge goes (the hat's left edge is measured on
    its top rows, where the stray barrel does not reach; the musket he carries lies on the right). rule = (first row
    under the hat's top, hat rows measured, margin: the last column erased is the hat's left edge + margin)."""
    a = cell[..., 3] > 0
    red = is_red(cell[..., :3].astype(int), a)
    rows = np.nonzero(red.any(1))[0]
    if len(rows) == 0:
        return cell
    coat_top = int(rows.min())
    top = int(np.nonzero(a.any(1))[0].min())
    from_row, hat_rows, margin = rule
    xs = np.nonzero(a[top:top + hat_rows, :CELL[0] // 2 + 6].any(0))[0]
    if len(xs) == 0:
        return cell
    hat_l = int(xs.min())
    out = cell.copy()
    for y in range(top + from_row, coat_top):
        for x in range(0, hat_l + margin + 1):
            out[y, x] = 0
    return out


HAIR = [(92, 58, 30), (122, 80, 42)]     # dark and light brown, the colour of his hair in the other views
RIBBON = (24, 18, 16)


def north_hair(cell):
    """The north sheet's back of the head is a flat brown blob: between the hat's black crown and the coat, the
    brown pixels become hair (dark with light streaks on alternate columns) and the middle column a black ribbon
    (his queue), as the back of the head reads in the north-east view."""
    a = cell[..., 3] > 0
    rgb = cell[..., :3].astype(int)
    red = is_red(rgb, a)
    rows = np.nonzero(red.any(1))[0]
    if len(rows) == 0:
        return cell
    coat_top = int(rows.min())
    dark = a & (rgb.max(-1) < 48)
    hat_rows = [y for y in range(coat_top) if dark[y].sum() >= 4]
    if not hat_rows:
        return cell
    y0 = max(hat_rows) + 1
    out = cell.copy()
    xs_all = []
    for y in range(y0, coat_top):
        for x in range(CELL[0]):
            if not a[y, x]:
                continue
            r, g, b = rgb[y, x]
            skin = r > 200 and g > 130
            if skin or not (r > g >= b):
                continue
            out[y, x, :3] = HAIR[(x + y) % 2 if y > y0 else 0]
            xs_all.append(x)
    if xs_all:
        mid = int(round((min(xs_all) + max(xs_all)) / 2.0))
        for y in range(y0, coat_top):
            if out[y, mid, 3] > 0:
                out[y, mid, :3] = RIBBON
    return out


def run(d, contacts=None):
    name = "%s_walk_%s_chatgpt" % (UNIT, d)
    if not os.path.exists("art/redraws/%s.png" % name):
        return False
    figs = figures(name)
    assert len(figs) == N, (name, len(figs))
    scale = BODY_H / float(np.median([h for _i, _s, h in figs]))
    extra = 0
    for img, sole, _h in figs:
        ys = np.nonzero(img[..., 3] > 0)[0]
        above = (sole - ys.min()) * scale - (ANCHOR[1] - 1)
        extra = max(extra, int(np.ceil(above)) + 1)
    cells = [to_cell(img, scale, (CELL[0], CELL[1] + extra), (ANCHOR[0], ANCHOR[1] + extra), ground=sole)
             for img, sole, _h in figs]
    if d in STRAY:
        cells = [erase_stray(c, STRAY[d]) for c in cells]
    if d == "n":
        cells = [north_hair(c) for c in cells]
    save_strip(UNIT, "walk", d, cells)
    write_counts(UNIT, {"walk_%s" % d: N})
    print("%s walk %s: scale %.3f, cell height %d" % (UNIT, d, scale, CELL[1] + extra))
    if contacts:
        os.makedirs(contacts, exist_ok=True)
        contact(os.path.join(contacts, "%s_walk_%s.png" % (UNIT, d)), [("walk_%s" % d, cells)], CELL[0])
    return True


STRAY = {"e": (5, 5, 0), "ne": (0, 2, -2)}     # (east: under the hat brim; north-east: the barrel rises past the brim)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    contacts = None
    if "--contact" in sys.argv:
        contacts = sys.argv[sys.argv.index("--contact") + 1]
        args = [a for a in args if a != contacts]
    for d in (args or ["s", "se", "e", "ne", "n"]):
        if not run(d, contacts):
            print("%s walk %s: no sheet yet" % (UNIT, d))


if __name__ == "__main__":
    main()
