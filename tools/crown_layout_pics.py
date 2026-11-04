#!/usr/bin/env python3
"""THE CROWN'S BASE LAYOUT AS A PICTURE (crown-owner-eco, docs/crown_owner_eco.md).

Reads the base_MMSS.json files tools/play_crown_owner_eco.gd writes (the main's ground, our buildings, the layout's plan)
and draws them as a map, like the game's minimap but bigger: one square a tile.
  python3 -I tools/crown_layout_pics.py OUT.jpg TITLE_A A.json [TITLE_B B.json]   (two side by side: before / after)
  python3 -I tools/crown_layout_pics.py --plan OUT.jpg TITLE A.json                 (the plan's blocks drawn over the ground)
"""
import json
import sys
from PIL import Image, ImageDraw, ImageFont

GROUND = {"h": (150, 136, 92), ".": (96, 104, 74), "#": (52, 58, 44), "r": (170, 130, 80), "w": (60, 90, 140)}
KIND = {
    "town_hall": (130, 70, 170), "cottage": (225, 150, 60), "farm": (220, 200, 90), "powder_mill": (140, 100, 60),
    "barracks": (190, 60, 50), "foundry": (80, 80, 90), "horse_breeder": (150, 110, 70), "armoury": (110, 130, 160),
    "church": (235, 235, 230), "wall": (30, 25, 20), "gate": (90, 60, 30),
}
PLAN = {"cottage": (255, 170, 60), "prod": (90, 170, 255), "farm": (255, 235, 120), "mill": (200, 140, 90)}
CELL = 9


def font(size):
    for f in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def draw_base(d, plan_only=False):
    rows = d["rows"]
    w, h = len(rows[0]), len(rows)
    im = Image.new("RGB", (w * CELL, h * CELL), (0, 0, 0))
    dr = ImageDraw.Draw(im)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            dr.rectangle([x * CELL, y * CELL, x * CELL + CELL - 1, y * CELL + CELL - 1], fill=GROUND.get(ch, (0, 0, 0)))
    if not plan_only:
        for b in d["buildings"]:
            c = KIND.get(b["k"], (200, 200, 200))
            if not b["built"]:
                c = tuple(int(v * 0.6) for v in c)
            x0, y0 = b["x"] * CELL, b["y"] * CELL
            dr.rectangle([x0, y0, x0 + b["w"] * CELL - 2, y0 + b["h"] * CELL - 2], fill=c, outline=(0, 0, 0))
    for p in d.get("plan", []):
        c = PLAN.get(p["k"], (255, 255, 255))
        x0, y0 = p["x"] * CELL, p["y"] * CELL
        dr.rectangle([x0 + 1, y0 + 1, x0 + p["w"] * CELL - 3, y0 + p["h"] * CELL - 3], outline=c, width=2)
    return im


def legend(dr, x, y, f, per=5):
    items = [("Town Hall", KIND["town_hall"]), ("Cottage", KIND["cottage"]), ("Farm", KIND["farm"]), ("Mill", KIND["powder_mill"]),
             ("Barracks", KIND["barracks"]), ("Foundry", KIND["foundry"]), ("Breeder", KIND["horse_breeder"]),
             ("Armoury", KIND["armoury"]), ("Church", KIND["church"]), ("Palisade", KIND["wall"])]
    for i, (name, c) in enumerate(items):
        xx = x + (i % per) * 150
        yy = y + (i // per) * 26
        dr.rectangle([xx, yy, xx + 18, yy + 18], fill=c, outline=(0, 0, 0))
        dr.text((xx + 24, yy), name, fill=(240, 240, 240), font=f)


def main():
    a = sys.argv[1:]
    plan_only = a[0] == "--plan"
    if plan_only:
        a = a[1:]
    out = a[0]
    pairs = [(a[i], json.load(open(a[i + 1]))) for i in range(1, len(a) - 1, 2)]
    ims = [draw_base(d, plan_only) for _, d in pairs]
    f = font(22)
    fs = font(17)
    W = sum(im.width for im in ims) + 30 * (len(ims) + 1)
    per = max(2, min(5, (W - 30) // 150))
    H = max(im.height for im in ims) + 70 + 26 * ((10 + per - 1) // per)
    can = Image.new("RGB", (W, H), (24, 22, 20))
    dr = ImageDraw.Draw(can)
    x = 30
    for (title, d), im in zip(pairs, ims):
        dr.text((x, 12), "%s (%s)" % (title, d["t"][:2] + ":" + d["t"][2:]), fill=(250, 240, 210), font=f)
        can.paste(im, (x, 48))
        x += im.width + 30
    legend(dr, 30, max(im.height for im in ims) + 60, fs, per)
    if can.width > 1200:
        can = can.resize((1200, int(can.height * 1200 / can.width)), Image.LANCZOS)
    can.save(out, quality=88)


if __name__ == "__main__":
    main()
