"""The Crown's palisade running DIAGONALLY, from the owner's ChatGPT sheet
art/redraws/palisade_diagonal_chatgpt.png (1774x887, transparent): two pieces, "\\" on the
left (stakes from top-left down to bottom-right) and "/" on the right, each on a triangle
of dirt.

The sheet is not used as it is: its stakes are fatter than the straight palisade's, get
shorter toward the low end (their feet are buried deeper in the dirt the lower they stand)
and sit on a big triangle of ground. So every stake is CUT OUT on its own (a column from
its tip down, a fixed length, so the bands sit at the same height on every stake), scaled
to the straight pieces' stake (6 px wide, 35 px tip to foot, the grey and gold bands at the
same rows as in wall_ew_built.png) and set down again with its foot on the cell's
diagonal, each with a little dirt at its foot (tools/import_palisade.py's patch, as the
N-S stakes have), the lower (nearer) stake drawn over the one behind it.

Geometry (tools/import_palisade.py: Defs.TILE 32, the straight stakes stand on y = 20, the
picture's bottom row 6 px below the tile): the diagonal runs through the same point
(16, 20) as the straight line, so a diagonal joins the straight pieces' centre post.
"\\": the stakes' feet on y = x + 4 (the tile's top-left corner to its bottom-right one,
shifted down 4 like the straight line), 8 stakes 4 px apart, so the next "\\" piece (one
cell right and one down) carries on with the same step and no gap. "/" is the same line
mirrored (y = 36 - x), with the right piece's own stakes (light from the same side).

Output (assets/buildings):
  wall_diag_se_built.png   "\\" (joins NW and SE)
  wall_diag_sw_built.png   "/"  (joins NE and SW)
  wall_diag_{se,sw}_{construction,damaged,destroyed}.png: derived from the same stakes
      (construction: the far half of the stakes still short stumps; damaged: some broken;
      destroyed: stumps)
  wall_diag_half_{nw,ne,se,sw}_built.png: the half from the centre to one corner (a piece
      with a diagonal and an orthogonal neighbour: drawn over its straight picture)
  wall_diag_hub_built.png: one stake on the centre (a diagonal line's end or branch)

Usage (from the repo root): python3 tools/import_palisade_diag.py [--contact DIR]
Needs Pillow, NumPy and SciPy.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_palisade as P  # noqa: E402
from import_art import unteam  # noqa: E402

SHEET = "art/redraws/palisade_diagonal_chatgpt.png"
OUT = P.OUT
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None

TILE = P.TILE
# the stakes on the sheet: the x of each tip's middle, back (high) to front (low)
TIPS = {"se": [258, 340, 426, 512, 596, 666, 746],
        "sw": [1514, 1434, 1354, 1266, 1186, 1106, 1018]}
HALF_W = 42           # sheet px each side of the tip's middle: one stake with its outline
CUT = 330             # sheet px kept below the tip (every stake is plain wood that far down)
ABOVE = 6             # and above it (the tip's outline)
STAKE_W = 6           # game px: a straight stake with its outline
STAKE_H = 35          # game px from the tip to the foot (wall_ew_built: tips ~2, feet 37)
SY = STAKE_H / 400.0  # the sheet's stake is ~400 px tip to foot: bands at tip+190 / +255
N = 8                 # stakes per tile
STEP = TILE // N      # 4 px right and 4 px down each
ORDER = [0, 1, 2, 3, 4, 5, 1, 3]   # which sheet stake stands where (the 7th is faded)


def sheet():
    a = np.array(Image.open(SHEET).convert("RGBA"))
    m = a[..., 3] > 0
    lab, n = ndimage.label(m)
    sz = ndimage.sum(m, lab, range(1, n + 1))
    keep = np.isin(lab, np.argsort(sz)[-2:] + 1)      # the two pieces, not the stray specks
    a[~keep] = 0
    a[..., 3] = np.where(keep, 255, 0)
    return a


_PX = sheet()


def stake_img(cx):
    """One stake cut from the sheet at game size, its foot on the last row."""
    m = _PX[..., 3] > 0
    tops = [np.argmax(m[:, x]) for x in range(cx - 12, cx + 12) if m[:, x].any()]
    tip = min(tops)
    img = _PX[tip - ABOVE:tip + CUT, cx - HALF_W:cx + HALF_W].copy()
    h = round((ABOVE + CUT) * SY)
    out = P.resize(img, STAKE_W, h)
    # down to the foot: the lowest wood row again, a little darker each row (in shadow)
    full = round((ABOVE + 400) * SY)
    ext = np.zeros((full, STAKE_W, 4), np.uint8)
    ext[:h] = out
    last = out[h - 1].astype(float)
    for i, y in enumerate(range(h, full)):
        row = last.copy()
        row[:, :3] *= 0.97 ** (i + 1)
        ext[y] = row.clip(0, 255).astype(np.uint8)
        ext[y, :, 3] = out[h - 1, :, 3]
    # a touch lighter: the sheet's wood is darker than the straight pieces' (median
    # brightness 60 vs 73)
    lit = ext[..., 3] > 0
    ext[..., :3][lit] = (ext[..., :3][lit].astype(float) * 1.1 + 5).clip(0, 255).astype(np.uint8)
    # outline columns: keep the sheet's black edge down the whole stake
    for x in (0, STAKE_W - 1):
        col = ext[:, x]
        col[(col[:, 3] > 0) & (col[:, :3].max(-1) > 60)] = (18, 14, 14, 255)
    return ext


STAKES = {k: [stake_img(c) for c in v] for k, v in TIPS.items()}
CUT_FACE = np.array((176, 146, 112), np.uint8)


def broken(img, keep, seed=0):
    """A stake snapped off: only its lowest `keep` (0..1) of the length left, a jagged
    light top (the broken wood)."""
    out = img.copy()
    h = out.shape[0]
    rng = np.random.RandomState(seed)
    base = h - max(3, round((h - 1) * keep))
    for x in range(out.shape[1]):
        top = base + int(rng.randint(0, 3))
        out[:top, x] = 0
        if out[top, x, 3] and 0 < x < out.shape[1] - 1:
            out[top, x, :3] = CUT_FACE
    return out


def stake_pos(kind, i):
    """(left edge, foot row) of stake i of a tile, back (0) to front (N-1)."""
    foot = 7 + STEP * i
    left = STEP * i if kind == "se" else TILE - STAKE_W - STEP * i
    return left, foot


def put(out, img, left, foot):
    P.paste(out, img, left, foot, img.shape[0] - 1)


# the straight piece's strip of ground: rows GROUND_ROWS of wall_ew_built.png, whose stakes
# stand on its row GROUND_FOOT
_EW = np.array(Image.open(f"{OUT}/wall_ew_built.png").convert("RGBA"))
GROUND_FOOT = _EW.shape[0] - 1 - P.FOOT - (TILE - P.BASE) + 1     # (row 37 of 55)
GROUND_ROWS = (GROUND_FOOT - 1, GROUND_FOOT + 6)


def ground(out, kind, x0, x1):
    """The straight piece's dirt strip laid along the diagonal (columns x0..x1-1): each
    column of the strip moved down to the foot line there, so the ground runs on with the
    stakes like the straight wall's does."""
    for x in range(max(0, x0), min(TILE, x1)):
        foot = (x + 4) if kind == "se" else (TILE + 3 - x)
        col = _EW[GROUND_ROWS[0]:GROUND_ROWS[1], x % _EW.shape[1]]
        for k, px in enumerate(col):
            y = P.ORIGIN + foot + 1 + k
            if px[3] and 0 <= y < out.shape[0]:
                out[y, x] = px


def piece(kind, which=range(N), state="built"):
    out = P.canvas()
    lefts = [stake_pos(kind, i)[0] for i in which]
    ground(out, kind, min(lefts), max(lefts) + STAKE_W)
    for i in which:
        img = STAKES[kind][ORDER[i]]
        if state == "construction" and i >= N // 2:
            img = broken(img, 0.35, i)
        elif state == "damaged" and i in (2, 5):
            img = broken(img, 0.55 if i == 2 else 0.3, i)
        elif state == "destroyed":
            img = broken(img, (0.22, 0.3, 0.18, 0.34, 0.25, 0.2, 0.3, 0.24)[i], i)
        put(out, img, *stake_pos(kind, i))
    if state == "damaged":
        out[..., :3] = (out[..., :3] * 0.9).astype(np.uint8)
    return P.trim(out)


def hub():
    out = P.canvas()
    P.paste(out, P.DIRT_IMG, TILE // 2 - P.DIRT_IMG.shape[1] // 2, P.BASE - 1, 0)
    put(out, STAKES["se"][ORDER[3]], TILE // 2 - STAKE_W // 2, P.BASE)
    return P.trim(out)


def build():
    pics = {}
    for k in ("se", "sw"):
        pics[f"wall_diag_{k}_built"] = piece(k)
        for st in ("construction", "damaged", "destroyed"):
            pics[f"wall_diag_{k}_{st}"] = piece(k, state=st)
    # halves: "\" is NW (stakes 0-3) + SE (4-7); "/" is NE (0-3) + SW (4-7)
    pics["wall_diag_half_nw_built"] = piece("se", range(0, N // 2))
    pics["wall_diag_half_se_built"] = piece("se", range(N // 2, N))
    pics["wall_diag_half_ne_built"] = piece("sw", range(0, N // 2))
    pics["wall_diag_half_sw_built"] = piece("sw", range(N // 2, N))
    pics["wall_diag_hub_built"] = hub()
    return {n: unteam(p) for n, p in pics.items()}


# ---------------------------------------------------------------- checking

def load_pic(name, pics):
    if name in pics:
        return pics[name]
    return np.array(Image.open(f"{OUT}/{name}.png").convert("RGBA"))


def lay(cells, pics, cols, rows, k=4):
    """Draw pieces on grass in y order like the game: cells {(x, y): picture name or a
    list of names (drawn in order)}."""
    W, H = cols * TILE, rows * TILE + 48
    img = np.zeros((H, W, 4), np.uint8)
    img[...] = (78, 118, 52, 255)
    img[48::TILE, :, :3] = (70, 108, 46)
    img[48:, ::TILE, :3] = (70, 108, 46)
    for (x, y) in sorted(cells, key=lambda c: (c[1], c[0])):
        names = cells[(x, y)]
        for n in ([names] if isinstance(names, str) else names):
            p = load_pic(n, pics)
            h, w = p.shape[:2]
            bx = x * TILE + TILE // 2 - w // 2
            by = 48 + (y + 1) * TILE + P.FOOT - h
            for yy in range(h):
                for xx in range(w):
                    if p[yy, xx, 3] and 0 <= bx + xx < W and 0 <= by + yy < H:
                        img[by + yy, bx + xx] = p[yy, xx]
    return Image.fromarray(img).resize((W * k, H * k), Image.NEAREST)


def contact(pics, d):
    os.makedirs(d, exist_ok=True)
    # 4 in a row each way, and the states
    cells = {(i, i): "wall_diag_se_built" for i in range(4)}
    cells.update({(9 - i, i): "wall_diag_sw_built" for i in range(4)})
    lay(cells, pics, 11, 5).save(f"{d}/diag_rows.png")
    # states side by side, and the straight ones for scale
    names = ["wall_ew_built", "wall_diag_se_built", "wall_diag_sw_built", "wall_ns_built"]
    for st in ("construction", "damaged", "destroyed"):
        names += [f"wall_diag_se_{st}", f"wall_diag_sw_{st}"]
    lay({(i, 0): n for i, n in enumerate(names)}, pics, len(names), 1).save(f"{d}/diag_states.png")
    print("contact:", d)


def main():
    pics = build()
    os.makedirs(OUT, exist_ok=True)
    for n, img in pics.items():
        Image.fromarray(img).save(f"{OUT}/{n}.png")
    if CONTACT:
        contact(pics, CONTACT)
    print("diagonal palisade: %d pictures" % len(pics))


if __name__ == "__main__":
    main()
