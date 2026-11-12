"""The Raptor's run toward the viewer (SOUTH) and away from it (NORTH) from the owner's ChatGPT sheets (2026-11-12,
docs/art_redraw_queue.md item 6 / table item 11): art/redraws/raptor_walk_{s,n}_chatgpt.png, one row of 6 frames on
navy (0, 22, 48). They replace the code-made stick legs (tools/import_gait_raptor.py, which now rebuilds only SE and NE)
of the 2026-10-24 redraw. The SE and NE answers of that round were side views and are NOT used (their strips stay).

Per frame: the navy keyed out with the shared redraw cutter (tools/redraw_lib.cut: edge pixels still tinted navy
removed, specks dropped), shrunk by one SCALE for both views (box filter, hard alpha, team reds snapped to the key reds),
put on the 58 x 30 cell: horizontally the figure's column-mass middle on anchor x (the head and tail sway, the body
stays put), vertically the SHEET's own ground (the median of the six frames' sole rows) on the anchor row, so the
contact frames reach a pixel lower and the passing frames lift as ChatGPT drew them (no per-frame re-snapping, which
would flatten the stride). Run after import_gait_raptor.py, before fix_brood.py and import_vet_skin.py
(tools/rebuild_art.sh).

SCALE: the creature as the redraw's E-scale S / N strips had it (11 px across the body, the S run 24-25 px crest to
soles); both views share it so turning S <-> N keeps its size. Crest and spines are pure red in the sheets: after the
shrink the key reds are checked (KEY_MIN of them a frame) and fix_brood.py snaps the near-key fringe.

Usage (repo root): python3 tools/import_raptor_walk_sn.py [--contact FILE]
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redraw_lib import col_boxes, cut, load_sheet, save_strip, to_cell, write_counts  # noqa: E402

CELL = (58, 30)
ANCHOR = (29, 28)
FRAMES = 6
SCALE = 0.068
VIEWS = ("s", "n")
KEY_MIN = 12


def frames(d):
    px, fg = load_sheet("raptor_walk_%s_chatgpt" % d)
    H, W = fg.shape
    figs = [cut(px, fg, (x0, 0, x1, H)) for x0, x1 in col_boxes(fg, 0, H, (0, W), FRAMES)]
    ground = float(np.median([np.nonzero((f[..., 3] > 0).any(1))[0].max() for f in figs]))
    cells = []
    for f in figs:
        a = f[..., 3] > 0
        col = a.sum(0).cumsum()
        cx = float(np.searchsorted(col, col[-1] / 2.0))
        cells.append(to_cell(f, SCALE, CELL, ANCHOR, cx=cx, ground=ground))
    # the soles as fix_brood.py wants them: the median frame's lowest row on the anchor row (the shrink's hard alpha
    # drops the thin claw tips, so the cells come out a row or two high); one shift for the six, the stride kept
    bots = [int(np.nonzero((c[..., 3] > 0).any(1))[0].max()) for c in cells]
    dy = min(ANCHOR[1] - int(np.median(bots)), CELL[1] - 1 - max(bots))
    if dy > 0:
        cells = [np.concatenate([np.zeros((dy, CELL[0], 4), np.uint8), c[:-dy]], 0) for c in cells]
    return cells


def key_count(c):
    r, g, b = [c[..., i].astype(int) for i in range(3)]
    return int(((c[..., 3] > 0) & (g == 0) & (b == 0) & ((r == 255) | (r == 150))).sum())


def main():
    strips = {}
    for d in VIEWS:
        cells = frames(d)
        keys = [key_count(c) for c in cells]
        assert min(keys) >= KEY_MIN, "walk_%s: too few team reds %s" % (d, keys)
        save_strip("raptor", "walk", d, cells)
        strips[d] = cells
        print("raptor walk_%s: %d frames, team key px %s" % (d, len(cells), keys))
    write_counts("raptor", {"walk_%s" % d: FRAMES for d in VIEWS})
    if "--contact" in sys.argv:
        out = sys.argv[sys.argv.index("--contact") + 1]
        rows = [np.concatenate(strips[d], 1) for d in VIEWS]
        im = Image.new("RGBA", (CELL[0] * FRAMES * 6, (CELL[1] + 2) * len(rows) * 6), (104, 132, 84, 255))
        for i, r in enumerate(rows):
            im.alpha_composite(Image.fromarray(r).resize((r.shape[1] * 6, r.shape[0] * 6), Image.NEAREST),
                               (0, i * (CELL[1] + 2) * 6))
        im.save(out)


if __name__ == "__main__":
    main()
