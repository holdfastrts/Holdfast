"""The Clockwork hub, Meister Hollweg's workshop in Nuremberg (docs/campaign_hub_art.md): the owner's two ChatGPT
pictures (2026-11-12) made into the hub's layers.

  art/campaign/hub/nuremberg_room_chatgpt.png     the empty workshop (background), 1672 x 941: the round brass
                                                  mechanical war map in the middle, an empty stool on the right
  art/campaign/hub/nuremberg_hollweg_chatgpt.png  Hollweg seated on his own stool, on flat magenta

Writes campaign/hub/nuremberg_room.jpg (the room with its empty stool painted out: Hollweg's own stool takes its place),
nuremberg_hollweg.png (keyed, scaled, toned into the lantern light), nuremberg_hollweg_face.png (the talk box's
portrait) and campaign/hub/nuremberg.json (layers and fx, read by scripts/campaign/hub_scene.gd).
  python3 tools/import_hub_nuremberg.py [--preview OUT.png]"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hub_key  # noqa: E402

SRC = "art/campaign/hub/nuremberg_%s_chatgpt.png"
OUT = "campaign/hub"
# The room's empty stool (room pixels): painted out, Hollweg's stool stands where it stood.
STOOL = [(1488, 552), (1614, 552), (1636, 700), (1634, 722), (1494, 724), (1486, 700)]
# Hollweg: his layer's scale and where his stool's feet land (room pixels); his stool's feet in his own picture.
SCALE = 0.235
FEET_ROOM = (1556, 712)
FEET_FIG = (512, 1452)
# The lantern light of the room: warm orange, the shadows lifted toward the room's brown; the lantern on his right.
TONE = {"mul": [0.80, 0.66, 0.50], "lift": [0.02, 0.01, 0.0], "gamma": 1.2}


def paint_out(room, poly):
    """The stool painted out: inpainted from what is round it, then given back the floor's and cabinet's grain (a
    copy of the texture just left of it) so the patch isn't a smear."""
    a = np.asarray(room.convert("RGB")).copy()
    mask = Image.new("L", room.size, 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    mk = np.asarray(mask)
    filled = cv2.inpaint(a[..., ::-1].copy(), mk, 9, cv2.INPAINT_TELEA)[..., ::-1].astype(float)
    # grain: the high frequencies of a strip of floor and cabinet to the right of the stool, tiled over the patch
    blur = cv2.GaussianBlur(a.astype(float), (0, 0), 3.0)
    hi = a.astype(float) - blur
    ys, xs = np.where(mk > 0)
    src_x = 1636 + (xs - xs.min()) % 34
    filled[ys, xs] += hi[ys, src_x] * 0.9
    out = a.astype(float)
    soft = cv2.GaussianBlur(mk.astype(float) / 255.0, (0, 0), 1.5)[..., None]
    out = out * (1 - soft) + filled * soft
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    room = paint_out(Image.open(SRC % "room").convert("RGB"), STOOL)
    room.save(os.path.join(OUT, "nuremberg_room.jpg"), quality=90)
    info = {"room": "res://campaign/hub/nuremberg_room.jpg", "size": list(room.size), "layers": []}
    comp = room.convert("RGBA")
    fig, box = hub_key.key(Image.open(SRC % "hollweg"), fringe=14)
    fig = hub_key.scaled(fig, SCALE)
    fig = hub_key.tone(fig, TONE["mul"], TONE["lift"], TONE["gamma"])
    fig = hub_key.side_light(fig, [1.0, 0.7, 0.35], "left", 0.18)   # the lantern on the bench at his right hand (screen left)
    pos = [round(FEET_ROOM[0] - (FEET_FIG[0] - box[0]) * SCALE), round(FEET_ROOM[1] - (FEET_FIG[1] - box[1]) * SCALE)]
    # his shadow on the floor, under the stool and his feet
    fx, fy = FEET_ROOM[0] + 4, FEET_ROOM[1] - 2
    comp.alpha_composite(hub_key.shadow(comp.size, (fx, fy), 74, 12, 120, 7))
    info["layers"].append({"id": "hollweg_shadow", "shadow": [fx, fy, 78, 13]})
    fig.save(os.path.join(OUT, "nuremberg_hollweg.png"))
    info["layers"].append({"id": "hollweg", "image": "res://campaign/hub/nuremberg_hollweg.png", "pos": pos,
                           "size": [fig.width, fig.height]})
    hub_key.paste(comp, fig, pos)
    # what the hub animates in code (room pixels): the two lanterns' flicker, a gleam running round the brass map's
    # rim and one across the clock's face, his breath
    info["fx"] = {
        "lamps": [[306, 382, 46, [1.0, 0.7, 0.32]], [1426, 404, 44, [1.0, 0.7, 0.32]]],
        "glints": [{"ellipse": [950, 560, 460, 68], "period": 9.0, "color": [1.0, 0.86, 0.5], "size": 13},
                   {"ellipse": [950, 560, 404, 52], "period": -14.0, "color": [1.0, 0.82, 0.45], "size": 9},
                   {"ellipse": [1108, 170, 50, 50], "period": 60.0, "color": [1.0, 0.9, 0.6], "size": 6}],
        "breathe": {"hollweg": 0.005},
    }
    fb = (pos[0] + round((565 - box[0]) * SCALE) - 37, pos[1] + round((165 - box[1]) * SCALE) - 37)
    hub_key.face(comp, (fb[0], fb[1], fb[0] + 74, fb[1] + 74), os.path.join(OUT, "nuremberg_hollweg_face.png"))
    info["focus"] = [1.0, 0.5]      # a narrow box crops the left only: Hollweg sits at the right edge
    with open(os.path.join(OUT, "nuremberg.json"), "w") as f:
        json.dump(info, f, indent=1)
    if "--preview" in sys.argv:
        comp.convert("RGB").save(sys.argv[sys.argv.index("--preview") + 1])
    print("nuremberg hub:", [(l["id"], l.get("pos"), l.get("size")) for l in info["layers"]], "face", fb)


if __name__ == "__main__":
    main()
