"""The muzzle smoke (assets/effects/smoke.png, 4 frames of 27 x 25) was painted touching the edges of its frames:
frame 0 on its left and right, frame 1 on three sides, frame 2 on its left, frame 3 top and bottom. Every shot's
quick puff (and the chimney smoke, and the powder haze's atlas) so showed straight, cut-off edges: the "clipping"
the owner saw (docs/perf_smoke.md). This feathers each frame's alpha to nothing toward the sides it touches, and
rounds every frame's corners a little, so no straight edge is left.

The painted original is kept in art/world/smoke_effect_original.png; this always starts from it (re-runnable).
  python3 tools/fix_smoke_edges.py"""
import os
import numpy as np
from PIL import Image

SRC = "art/world/smoke_effect_original.png"
OUT = "assets/effects/smoke.png"
FW = 27          # frame width (ArtData.EFFECTS["smoke"])
FEATHER = 6.0    # px over which the alpha fades to nothing toward a side the art touches


def smooth(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def main():
    if not os.path.exists(SRC):
        os.makedirs(os.path.dirname(SRC), exist_ok=True)
        Image.open(OUT).save(SRC)          # (the first run keeps the painted original)
    im = np.array(Image.open(SRC).convert("RGBA")).astype(np.float32)
    h = im.shape[0]
    n = im.shape[1] // FW
    ys, xs = np.mgrid[0:h, 0:FW].astype(np.float32)
    # distance (px, pixel centres) to each side
    d_l, d_r = xs + 0.5, FW - xs - 0.5
    d_t, d_b = ys + 0.5, h - ys - 0.5
    for k in range(n):
        f = im[:, k * FW:(k + 1) * FW]
        a = f[..., 3]
        m = np.ones_like(a)
        # the sides the painted smoke touches fade to nothing over FEATHER px
        for side, d in (("l", d_l), ("r", d_r), ("t", d_t), ("b", d_b)):
            edge = {"l": a[:, 0], "r": a[:, -1], "t": a[0, :], "b": a[-1, :]}[side]
            if edge.max() > 0:
                m *= smooth((d - 0.5) / FEATHER)
        # and a soft ellipse, so the corners never show a square either
        r = np.sqrt(((xs + 0.5 - FW / 2) / (FW / 2)) ** 2 + ((ys + 0.5 - h / 2) / (h / 2)) ** 2)
        m *= 1.0 - smooth((r - 0.78) / 0.3)
        f[..., 3] = a * m
        im[:, k * FW:(k + 1) * FW] = f
    Image.fromarray(np.clip(im + 0.5, 0, 255).astype(np.uint8), "RGBA").save(OUT)
    print("feathered %d frames -> %s" % (n, OUT))


if __name__ == "__main__":
    main()
