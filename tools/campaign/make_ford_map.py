#!/usr/bin/env python3
"""Writes campaign/maps/ford_village.json, the test mission's map, in the MAP EDITOR's own format
(user://maps/<name>.json: name, size, cells, biome, starts, teams, halls, props; see scripts/mapgen.gd).

A campaign map is normally drawn in the editor and copied from the user folder into campaign/maps/; this one is
made by a script so it can be rebuilt. To edit it by hand: copy it to <user folder>/maps/, open it in the
MAP EDITOR, save, and copy it back (the mission refers to it as "campaign:ford_village").

  python3 tools/campaign/make_ford_map.py

The ground: a village on the west bank of a north-south river (one ford in the middle and a
narrow one in the south), hedgerows and copses, and a camp on the east bank.
"""
import json
import os

W, H = 96, 64
cells = [["."] * W for _ in range(H)]


def put(x, y, ch):
    if 0 <= x < W and 0 <= y < H:
        cells[y][x] = ch


def blob(cx, cy, rx, ry, ch, every=1):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0 and (x * 7 + y * 13) % every == 0:
                put(x, y, ch)


# the river: four cells wide, wandering a little
for y in range(H):
    x0 = 57 + (1 if 18 < y < 40 else 0) + (-1 if y > 48 else 0)
    for x in range(x0, x0 + 4):
        put(x, y, "w")
# the ford at the village (rows 29-34) and a narrow one in the south (rows 54-56)
for y in list(range(29, 35)) + list(range(54, 57)):
    for x in range(54, 64):
        if cells[y][x] == "w":
            put(x, y, "f")

# copses and hedgerows (trees on low ground: "t"); rocks ("k")
blob(34, 8, 7, 4, "t")
blob(40, 54, 6, 4, "t")
blob(78, 52, 6, 5, "t")
blob(76, 10, 5, 4, "t")
blob(6, 6, 4, 4, "t")
blob(6, 58, 5, 4, "t")
for x in range(26, 48):                      # a hedgerow north of the village, with a gap for the lane
    if not 35 <= x <= 38:
        put(x, 18, "t")
for x in range(26, 48):                      # and one south of it
    if not 33 <= x <= 36:
        put(x, 44, "t")
blob(50, 24, 1.5, 1.5, "k")
blob(48, 40, 1.5, 1.2, "k")
blob(70, 36, 1.5, 1.5, "k")

# keep the halls' ground and the lanes clear
def clear(x0, y0, x1, y1):
    for y in range(y0, y1):
        for x in range(x0, x1):
            if cells[y][x] in "tk":
                put(x, y, ".")


clear(8, 22, 30, 40)      # the village and its fields
clear(70, 22, 94, 42)     # the east camp
clear(0, 26, 96, 37)      # the road across the ford

starts = [[14, 28], [82, 29]]          # hall spots (top-left of 5 x 4): the village, the east camp
teams = [0, 1]

KITS = {   # (as MapGen.KITS: name, dx, dy)
    "village": [["chapel", 0, 0], ["cottage", 4, 1], ["windmill", -4, -1], ["well", 1, 3], ["stall", -3, 3], ["cart_b", 4, 4],
                ["sacks_pile", 6, 0], ["crates_pair", -1, 5], ["barrel_a", 2, 2], ["banner_a", -2, 1]],
    "farm": [["cottage", 0, 0], ["haystack", 3, 1], ["well", -3, 1], ["fence", -1, 2], ["fence_b", 1, 2], ["cart_a", 3, -2],
             ["scarecrow", 5, 2], ["beehive", -2, -2], ["sacks", 2, 0], ["haybales", 4, 3]],
    "camp": [["tent_white", 0, 0], ["tent_red", 3, -1], ["tent_blue", -3, 1], ["campfire", 0, 2], ["spit_roast", 2, 2],
             ["crate_b", -2, -1], ["barrel_a", -2, 3], ["flag", 5, 1], ["wagon", 4, 3], ["table", -1, 4], ["cannonballs", 1, 4]],
}
props = []
for kit, cx, cy in [("village", 32, 24), ("farm", 30, 38), ("camp", 78, 24)]:
    for name, dx, dy in KITS[kit]:
        props.append([name, cx + dx, cy + dy, False])

data = {
    "name": "ford_village", "size": [W, H], "cells": "".join("".join(r) for r in cells),
    "mirror": "off", "mix": "diag", "biome": "grass",
    "starts": starts, "teams": teams, "mode": "1v1", "halls": [[12, 50]],
    "props": props, "checked": True,
}
out = os.path.join(os.path.dirname(__file__), "..", "..", "campaign", "maps", "ford_village.json")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w") as f:
    json.dump(data, f)
print("wrote", os.path.normpath(out))
