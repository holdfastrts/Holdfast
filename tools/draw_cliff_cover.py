#!/usr/bin/env python3
"""Draw the Crown's main, its cliff edge, the musket reach from the edge and the hall spots, from the JSON that
tools/measure_cliff_cover.gd writes (out:DIR). One picture a map, 1200 px wide, JPEG.
    python3 -I tools/draw_cliff_cover.py IN.json OUT.jpg ["title"]
Low ground light, high ground darker, cliffs black, ramps tan, trees/rocks green-grey; the edge cells orange, the ground
within musket reach of them (CrownSites.REACH) washed blue; the main hall white, the computer's OLD pick red, the old gold marks (base sites) purple, the NEW Crown marks gold
(#1 bright, #2 faint)."""
import json
import math
import sys

from PIL import Image, ImageDraw, ImageFont

src, dst = sys.argv[1], sys.argv[2]
title = sys.argv[3] if len(sys.argv) > 3 else ""
d = json.load(open(src))
grid = d["grid"]
lo = list(d["lo"])
# (cut to the map: cells outside it are blank)
rows = [i for i, r in enumerate(grid) if r.strip()]
cols = [j for j in range(len(grid[0])) if any(r[j] != " " for r in grid)]
grid = [r[cols[0]:cols[-1] + 1] for r in grid[rows[0]:rows[-1] + 1]]
lo = [lo[0] + cols[0], lo[1] + rows[0]]
H = len(grid)
W = len(grid[0])
C = 1200 // W
img = Image.new("RGB", (W * C, H * C + 60), (20, 20, 20))
dr = ImageDraw.Draw(img, "RGBA")
col = {".": (196, 186, 150), "^": (140, 128, 96), "#": (30, 26, 22), "/": (214, 170, 110), "t": (96, 120, 84),
       "T": (70, 92, 62), " ": (0, 0, 0)}
for y, row in enumerate(grid):
    for x, ch in enumerate(row):
        dr.rectangle([x * C, y * C, x * C + C - 1, y * C + C - 1], fill=col.get(ch, (255, 0, 255)))
edge = {(e[0] - lo[0], e[1] - lo[1]) for e in d["edge"]}
reach = d["reach"]
# musket reach from the edge, on the low ground
for y, row in enumerate(grid):
    for x, ch in enumerate(row):
        if ch not in ".t":
            continue
        best = min((math.hypot(x - ex, y - ey) for ex, ey in edge), default=99)
        if best <= reach:
            dr.rectangle([x * C, y * C, x * C + C - 1, y * C + C - 1], fill=(60, 120, 230, 70))
for ex, ey in edge:
    dr.rectangle([ex * C + 1, ey * C + 1, ex * C + C - 2, ey * C + C - 2], fill=(240, 130, 30))
sx, sy = d["size"]


def box(c, outline, width, fill=None, label=""):
    if c is None or c[0] < 0:
        return
    x, y = c[0] - lo[0], c[1] - lo[1]
    dr.rectangle([x * C, y * C, (x + sx) * C - 1, (y + sy) * C - 1], outline=outline, width=width, fill=fill)
    if label:
        dr.text((x * C + 3, y * C + 2), label, fill=(0, 0, 0), font=FONT_S)


try:
    FONT = ImageFont.truetype("DejaVuSans-Bold.ttf", 20)
    FONT_S = ImageFont.truetype("DejaVuSans-Bold.ttf", 14)
except OSError:
    FONT = FONT_S = ImageFont.load_default()
box(d["main"], (255, 255, 255), 4, (255, 255, 255, 90), "MAIN")
for i, m in enumerate(d.get("oldmarks", [])):
    if m != d["old"]:
        box(m, (200, 60, 160), 3, (200, 60, 160, 50), "OLD MARK #%d" % (i + 1))
box(d["old"], (220, 30, 30), 5, (220, 30, 30, 70), "OLD PICK")
marks = d.get("marks", [])
for i, m in enumerate(marks):
    box(m, (255, 200, 60), 5 if i == 0 else 3, (255, 200, 60, 110 if i == 0 else 60), "NEW #%d" % (i + 1))
y0 = H * C + 8
dr.text((10, y0), title, fill=(240, 240, 240), font=FONT)
dr.text((10, y0 + 28), "orange: cliff edge   blue: musket reach   red: old pick (= old mark #1)   purple: old mark #2   gold: new Crown spots",
        fill=(200, 200, 200), font=FONT_S)
if img.width != 1200:
    img = img.resize((1200, int(img.height * 1200 / img.width)), Image.LANCZOS)
img.save(dst, "JPEG", quality=85)
print(dst, img.size)
