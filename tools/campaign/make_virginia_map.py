#!/usr/bin/env python3
"""Writes campaign/maps/virginia_leaf.json, mission 1's map ("The Leaf and the Fire", docs/campaign_m1_build.md), in
the MAP EDITOR's own format (user://maps/<name>.json: name, size, cells, biome, starts, teams, halls, props; see
scripts/mapgen.gd). To edit it by hand: copy it to <user folder>/maps/, open it in the MAP EDITOR, save, and copy it
back (the mission refers to it as "campaign:virginia_leaf"). Rebuild: python3 tools/campaign/make_virginia_map.py

The ground, west to east (128 x 80 cells):
  - the PLANTATION in the west (the manor, the chapel, the drying barns, the Barracks are the mission's buildings),
    tobacco fields north and east of it (drying racks, sheaves), and the WOODS beyond them where the rebels come out;
  - the ROAD east along the middle, past two rebel CAMPS (tents, fires), to the province FORT in the east (its walls and
    gate are the mission's buildings: the rebels hold it);
  - a SIDE PATH north off the road, through a gap in the woods, to Hollins Farm, where the loyal families are trapped.
"""
import json
import os

W, H = 128, 80
cells = [["."] * W for _ in range(H)]


def put(x, y, ch):
    if 0 <= x < W and 0 <= y < H:
        cells[y][x] = ch


def blob(cx, cy, rx, ry, ch, every=1):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0 and (x * 7 + y * 13) % every == 0:
                put(x, y, ch)


def rect(x0, y0, x1, y1, ch):
    for y in range(y0, y1):
        for x in range(x0, x1):
            put(x, y, ch)


def clear(x0, y0, x1, y1):
    for y in range(y0, y1):
        for x in range(x0, x1):
            if 0 <= x < W and 0 <= y < H and cells[y][x] in "tk":
                put(x, y, ".")


# the woods: a ragged belt north of the fields and the road, a band east of the fields, the southern forest
for x in range(0, W):
    depth = 6 + (x * 7 % 5) + (2 if 40 < x < 90 else 0)
    for y in range(0, depth):
        put(x, y, "t")
for x in range(0, W):
    top = 66 - (x * 5 % 4) - (3 if 30 < x < 100 else 0)
    for y in range(top, H):
        put(x, y, "t")
blob(50, 18, 5, 9, "t")          # east of the north fields
blob(50, 58, 5, 7, "t")          # east of the south fields
blob(64, 22, 6, 6, "t")          # the copse the side path skirts
blob(84, 22, 8, 7, "t")
blob(70, 56, 9, 5, "t")
blob(92, 58, 8, 5, "t")
blob(98, 14, 6, 5, "t")
blob(40, 62, 5, 3, "t")
blob(4, 70, 4, 4, "t")
rect(116, 8, 128, 26, "t")
rect(116, 54, 128, 66, "t")
blob(74, 46, 1.5, 1.5, "k")
blob(60, 48, 1.4, 1.2, "k")
blob(96, 44, 1.2, 1.2, "k")

# the plantation and its fields, the road, the camps, the fort ground and the side path
clear(2, 8, 46, 64)              # plantation, north and south fields
clear(44, 30, 116, 48)           # the road and the camps
clear(100, 24, 124, 54)          # the fort and the ground before it
clear(66, 6, 82, 34)             # the side path north to Hollins Farm
clear(62, 4, 80, 18)             # Hollins Farm

starts = [[12, 36], [70, 9], [107, 36], [30, 40]]   # (hall-sized spots; the mission places its own buildings)
teams = [0, 1, 1, 0]

# decorations: tobacco in rows (sheaves and drying racks), the camps, the farm, the road
props = []


def prop(name, x, y, flip=False):
    props.append([name, x, y, flip])


for row, y in enumerate([11, 14, 17]):              # the north fields: tobacco in rows
    for x in range(8, 40, 3):
        prop("sheaf" if (x + row) % 2 == 0 else "grass_tall", x, y)
for row, y in enumerate([57, 60]):                  # the south fields
    for x in range(8, 40, 3):
        prop("sheaf" if (x + row) % 2 else "grass_tall", x, y)
for x in range(36, 44, 3):                          # the east fields
    for y in range(26, 50, 3):
        prop("sheaf", x, y)
for x, y in [(30, 25), (34, 25), (6, 50), (40, 52), (42, 22)]:
    prop("drying_rack", x, y)
for x, y in [(24, 24), (30, 50)]:
    prop("haystack_b", x, y)
# (the manor, chapel, barns, Barracks, Mill and cottages stand on cells kept free of props: see the mission's
# "buildings"; their cells: hall 10,34; church 18,28; barns 24,30 / 24,38 / 6,22 / 14,22 / 20,48; barracks 8,44;
# mill 16,44; cottages 3,29 / 3,33 / 3,41)
for name, x, y in [("well", 19, 41), ("cart_a", 31, 44), ("barrel_a", 22, 45), ("crate_hay", 31, 37), ("bench", 22, 27),
                   ("signpost", 46, 39), ("flowers", 7, 31), ("sacks_pile", 7, 40)]:
    prop(name, x, y)
# the road: carts and posts along it
for name, x, y in [("cart_c", 58, 43), ("signpost", 66, 37), ("stump", 72, 44), ("signpost", 92, 37), ("log", 86, 44)]:
    prop(name, x, y)
# the rebel camps
CAMP = [["tent_white", 0, 0], ["tent_round", 3, -1], ["campfire", 0, 2], ["crate_b", -2, -1], ["barrel_a", -2, 3],
        ["flag", 5, 1], ["firewood", 2, 3], ["cauldron", -3, 1]]
for cx, cy in [(53, 34), (80, 34)]:
    for name, dx, dy in CAMP:
        prop(name, cx + dx, cy + dy)
# Hollins Farm (its house is the mission's cottage), burning: haystacks, a cart, fences
for name, x, y in [("haystack", 66, 12), ("haybales", 76, 13), ("fence", 68, 15), ("fence_b", 70, 15), ("cart_b", 75, 9),
                   ("well", 64, 9), ("scarecrow", 78, 7), ("sheaf", 63, 15), ("sheaf", 79, 15)]:
    prop(name, x, y)
# the fort's yard
for name, x, y in [("cannonballs", 107, 47), ("barrel_tall", 118, 47), ("crate_long", 107, 30), ("banner_pole", 118, 30),
                   ("flag", 118, 36)]:
    prop(name, x, y)

data = {
    "name": "virginia_leaf", "size": [W, H], "cells": "".join("".join(r) for r in cells),
    "mirror": "off", "mix": "diag", "biome": "grass",
    "starts": starts, "teams": teams, "mode": "2v2", "halls": [],
    "props": props, "checked": True,
}
out = os.path.join(os.path.dirname(__file__), "..", "..", "campaign", "maps", "virginia_leaf.json")
with open(out, "w") as f:
    json.dump(data, f)
print("wrote", os.path.normpath(out))
