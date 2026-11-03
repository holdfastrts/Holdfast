#!/usr/bin/env python3
"""The SCATTER COGS command icon (assets/icons/clockwork/ab_scatter.png), a stand-in until ChatGPT draws one
(docs/cog_scatter.md has the prompt): the Clockwork icon frame of ab_sweep.png with its picture cleared, the Great
Winder's own south idle frame (assets/units/great_winder/idle_s.png) at the left, and cogs and bolts flying from its
hopper along a dotted yellow arc (the JUMP icon's arrow colour) to a heap of litter at the right. Code-drawn: logged in
docs/art_style_inconsistency.md.
    python3 tools/make_cog_scatter_icon.py
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PANEL = (26, 40, 56, 255)
BRASS = (222, 170, 78, 255)
BRASS_D = (104, 66, 22, 255)
STEEL = (150, 156, 166, 255)
STEEL_D = (52, 54, 62, 255)
ARC = (246, 206, 70, 255)
SS = 4          # drawn 4x, then scaled down (smooth edges)


def cog(d, cx, cy, r, col, dark, teeth=8):
    pts = []
    for i in range(teeth * 2):
        a = math.pi * 2 * i / (teeth * 2)
        rr = r if i % 2 == 0 else r * 0.72
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=col, outline=dark, width=SS)
    h = r * 0.32
    d.ellipse((cx - h, cy - h, cx + h, cy + h), fill=dark)


def flat_cog(img, cx, cy, r, col, dark):
    """A cog lying on the ground: drawn round, squashed to the 3/4 angle."""
    s = int(r * 2 + 4 * SS)
    tile = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    cog(ImageDraw.Draw(tile), s / 2, s / 2, r, col, dark)
    tile = tile.resize((s, int(s * 0.55)), Image.LANCZOS)
    img.alpha_composite(tile, (int(cx - s / 2), int(cy - s * 0.55 / 2)))


def bolt(d, x, y, l, a, w=SS * 2):
    dx, dy = math.cos(a) * l / 2, math.sin(a) * l / 2
    d.line((x - dx, y - dy, x + dx, y + dy), fill=STEEL_D, width=w + SS)
    d.line((x - dx, y - dy, x + dx, y + dy), fill=STEEL, width=w)
    hr = w * 0.9
    d.regular_polygon((x - dx, y - dy, hr), 6, fill=STEEL, outline=STEEL_D)


def main():
    base = Image.open(os.path.join(ROOT, "assets/icons/clockwork/ab_sweep.png")).convert("RGBA")
    W = 64 * SS
    big = base.resize((W, W), Image.NEAREST)
    d = ImageDraw.Draw(big)
    d.rectangle((9 * SS, 9 * SS, 55 * SS - 1, 55 * SS - 1), fill=PANEL)
    # the Great Winder: its own south idle frame, trimmed, mirrored (its hopper to the right) and scaled at the left
    gw = Image.open(os.path.join(ROOT, "assets/units/great_winder/idle_s.png")).convert("RGBA").crop((0, 0, 182, 103))
    gw = gw.crop(gw.getbbox()).transpose(Image.FLIP_LEFT_RIGHT)
    h = 23 * SS
    gw = gw.resize((int(gw.width * h / gw.height), h), Image.LANCZOS)
    gx, gy = 10 * SS, 54 * SS - h
    big.alpha_composite(gw, (gx, gy))
    # the dotted arc from its hopper to the heap
    x0, y0 = gx + gw.width * 0.62, gy + h * 0.3
    x1, y1 = 47 * SS, 46 * SS
    peak = 24 * SS
    for i in range(0, 15):
        f = i / 14.0
        x = x0 + (x1 - x0) * f
        y = y0 + (y1 - y0) * f - peak * 4 * f * (1 - f)
        if i % 2 == 1 and f < 0.9:
            d.ellipse((x - 1.1 * SS, y - 1.1 * SS, x + 1.1 * SS, y + 1.1 * SS), fill=ARC)
    # pieces in the air along the arc
    for f, kind in ((0.28, "cog"), (0.5, "bolt"), (0.72, "cog_s")):
        x = x0 + (x1 - x0) * f
        y = y0 + (y1 - y0) * f - peak * 4 * f * (1 - f) - 5 * SS
        if kind == "cog":
            cog(d, x, y, 5.0 * SS, BRASS, BRASS_D)
        elif kind == "cog_s":
            cog(d, x, y, 4.0 * SS, STEEL, STEEL_D)
        else:
            bolt(d, x, y, 9 * SS, 0.7)
    # the heap of litter on the ground
    flat_cog(big, 43 * SS, 50 * SS, 5.6 * SS, BRASS, BRASS_D)
    flat_cog(big, 51 * SS, 47.5 * SS, 4.2 * SS, STEEL, STEEL_D)
    flat_cog(big, 50 * SS, 52.5 * SS, 4.4 * SS, BRASS, BRASS_D)
    bolt(ImageDraw.Draw(big), 37 * SS, 53 * SS, 8 * SS, -0.3, SS * 2)
    out = big.resize((64, 64), Image.LANCZOS)
    # keep the frame crisp: the original outside the panel
    for y in range(64):
        for x in range(64):
            if not (9 <= x < 55 and 9 <= y < 55):
                out.putpixel((x, y), base.getpixel((x, y)))
    path = os.path.join(ROOT, "assets/icons/clockwork/ab_scatter.png")
    out.save(path)
    print("wrote", path)


if __name__ == "__main__":
    main()
