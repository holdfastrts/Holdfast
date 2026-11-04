#!/usr/bin/env python3
"""Before and after pictures of the Crown's hall spots, from the JSON tools/measure_crown_spots.gd writes (out:DIR tag:T).
    python3 -I tools/draw_crown_spots.py BEFORE.json AFTER.json OUT.jpg ["title"]
Two panels, BEFORE left and AFTER right, 1200 px wide, JPEG: low ground light, high ground darker, cliffs black, ramps tan,
trees/rocks/water green-grey; the main hall white, the ramp's foot a red dot, the old natural (the base-site rating's #1)
a dashed purple box; the Crown's 2nd, 3rd and 4th bases gold (2nd bright, 3rd lighter, 4th faint), each with its numbers
below: tiles from the main, the walk from the ramp's foot, tiles from the map's border, sides open."""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

bpath, apath, dst = sys.argv[1], sys.argv[2], sys.argv[3]
title = sys.argv[4] if len(sys.argv) > 4 else ""
B = json.load(open(bpath))
A = json.load(open(apath))
try:
    FONT = ImageFont.truetype("DejaVuSans-Bold.ttf", 20)
    FONT_S = ImageFont.truetype("DejaVuSans-Bold.ttf", 13)
    FONT_T = ImageFont.truetype("DejaVuSans.ttf", 13)
except OSError:
    FONT = FONT_S = FONT_T = ImageFont.load_default()
COL = {".": (196, 186, 150), "^": (140, 128, 96), "#": (30, 26, 22), "/": (214, 170, 110), "t": (96, 120, 84)}
GOLD = [(255, 196, 40), (255, 222, 120), (240, 236, 200)]
PANEL = 594
GAP = 12


def panel(d, label):
    grid = d["grid"]
    h, w = len(grid), len(grid[0])
    c = max(1, PANEL // w)
    im = Image.new("RGB", (w * c, h * c), (0, 0, 0))
    dr = ImageDraw.Draw(im, "RGBA")
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            dr.rectangle([x * c, y * c, x * c + c - 1, y * c + c - 1], fill=COL.get(ch, (255, 0, 255)))
    lo = d["lo"]
    sx, sy = d["size"]

    def box(cell, outline, width, fill, text, dash=False):
        x, y = cell[0] - lo[0], cell[1] - lo[1]
        r = [x * c, y * c, (x + sx) * c - 1, (y + sy) * c - 1]
        if dash:
            for i in range(r[0], r[2], 8):
                dr.line([i, r[1], min(i + 4, r[2]), r[1]], fill=outline, width=width)
                dr.line([i, r[3], min(i + 4, r[2]), r[3]], fill=outline, width=width)
            for j in range(r[1], r[3], 8):
                dr.line([r[0], j, r[0], min(j + 4, r[3])], fill=outline, width=width)
                dr.line([r[2], j, r[2], min(j + 4, r[3])], fill=outline, width=width)
        else:
            dr.rectangle(r, outline=outline, width=width, fill=fill)
        if text:
            tw = dr.textlength(text, font=FONT_S)
            dr.rectangle([r[0], r[1] - 16, r[0] + tw + 6, r[1] - 1], fill=(20, 20, 20, 200))
            dr.text((r[0] + 3, r[1] - 16), text, fill=(255, 255, 255), font=FONT_S)

    box(d["main"], (255, 255, 255), 3, (255, 255, 255, 80), "MAIN")
    for s in d["spots"]:
        if s["what"] == "natural1":
            box(s["c"], (200, 60, 200), 3, None, "", dash=True)
            x, y = s["c"][0] - lo[0], s["c"][1] - lo[1]
            dr.text((x * c + 2, (y + sy) * c + 1), "old natural", fill=(150, 30, 150), font=FONT_S)
    for i, s in enumerate([s for s in d["spots"] if s["what"] in ("2nd", "3rd", "4th")]):
        box(s["c"], GOLD[i], 4 if i == 0 else 3, GOLD[i] + ((150, 110, 70)[i],), s["what"].upper())
    if d.get("foot"):
        fx, fy = d["foot"][0] - lo[0], d["foot"][1] - lo[1]
        dr.ellipse([fx * c - 4, fy * c - 4, fx * c + c + 3, fy * c + c + 3], fill=(220, 30, 30), outline=(255, 255, 255))
    dr.rectangle([0, 0, 108, 24], fill=(20, 20, 20, 210))
    dr.text((6, 2), label, fill=(255, 255, 255), font=FONT)
    if im.width != PANEL:
        im = im.resize((PANEL, int(im.height * PANEL / im.width)), Image.NEAREST)
    return im


pb, pa = panel(B, "BEFORE"), panel(A, "AFTER")
rows_h = 16 * 4 + 64
H = max(pb.height, pa.height)
img = Image.new("RGB", (1200, H + rows_h), (20, 20, 20))
img.paste(pb, (0, 0))
img.paste(pa, (PANEL + GAP, 0))
dr = ImageDraw.Draw(img)
dr.text((10, H + 6), title, fill=(240, 240, 240), font=FONT)
for k, d in enumerate((B, A)):
    x0 = 10 + k * (PANEL + GAP)
    y = H + 34
    for s in d["spots"]:
        if s["what"] not in ("2nd", "3rd", "4th", "natural1"):
            continue
        name = "old natural" if s["what"] == "natural1" else s["what"]
        dr.text((x0, y), "%-11s %4.1f from main, walk %s from ramp foot, %d from border, %d sides open" % (
            name, s["main"], s["walk"], s["edge"], s["open"]), fill=(215, 215, 215), font=FONT_T)
        y += 16
dr.text((10, H + rows_h - 20), "white: main   red dot: the ramp's foot   gold: the Crown's 2nd, 3rd, 4th bases   dashed purple: the old natural (base-site rating)",
        fill=(170, 170, 170), font=FONT_T)
img.save(dst, "JPEG", quality=85)
print(dst, img.size)
