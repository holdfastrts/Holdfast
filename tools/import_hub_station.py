"""The Brood hub, Dr. Lindqvist's research station on the Amazon (docs/campaign_hub_art.md): the owner's two ChatGPT
pictures (2026-11-12) made into the hub's layers.

  art/campaign/hub/station_room_chatgpt.png       the empty station (background), 1672 x 941: the specimen chart with
                                                  the plateau map on the table, the jars, the nest on the right
  art/campaign/hub/station_lindqvist_chatgpt.png  Lindqvist standing, holding up a glowing green jar, on magenta

The jar's glass is see-through, so the magenta showed in it: that tint is turned into green glass before the key (not
keyed to a hole). Writes campaign/hub/station_room.jpg, station_lindqvist.png, station_lindqvist_face.png and
campaign/hub/station.json (layers and fx, read by scripts/campaign/hub_scene.gd).
  python3 tools/import_hub_station.py [--preview OUT.png]"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hub_key  # noqa: E402

SRC = "art/campaign/hub/station_%s_chatgpt.png"
OUT = "campaign/hub"
# The jar in his hands (his own picture's pixels): its glass, where the magenta shows through.
JAR = (346, 36, 434, 208)
# Lindqvist: his scale and where his feet land (room pixels: on the floor right of the table, before the nest);
# his feet in his own picture.
SCALE = 0.43
FEET_ROOM = (1500, 905)
FEET_FIG = (566, 1482)
# The station's light: the brass lamp warm on the table to his left, the room dark brown, a green cast from the jars.
TONE = {"mul": [0.74, 0.60, 0.44], "lift": [0.015, 0.012, 0.0], "gamma": 1.22}


def green_glass(img):
    """The jar's see-through glass: wherever the magenta background tints it, that tint becomes the jar's own
    green-yellow glass (same brightness), so keying leaves the glass whole."""
    a = np.asarray(img.convert("RGB")).astype(float)
    x0, y0, x1, y1 = JAR
    sub = a[y0:y1, x0:x1]
    m = np.minimum(sub[..., 0], sub[..., 2]) - sub[..., 1]
    # the background round the jar stays magenta, and the glass's last 2 px against it are left to the key
    outside = ndimage.binary_dilation(hub_key.bg_mask(a), iterations=2)[y0:y1, x0:x1]
    t = np.where(outside, 0.0, np.clip((m + 10.0) / 70.0, 0.0, 1.0))[..., None]   # 1: pure magenta seen through
    lum = sub.mean(axis=2, keepdims=True)
    glass = np.clip(lum * np.array([0.95, 1.25, 0.42]) + np.array([10.0, 20.0, 0.0]), 0, 255)
    sub[:] = sub * (1.0 - t) + glass * t
    return Image.fromarray(a.astype(np.uint8), "RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    room = Image.open(SRC % "room").convert("RGB")
    room.save(os.path.join(OUT, "station_room.jpg"), quality=90)
    info = {"room": "res://campaign/hub/station_room.jpg", "size": list(room.size), "layers": []}
    comp = room.convert("RGBA")
    src = green_glass(Image.open(SRC % "lindqvist"))
    keep = np.zeros((src.height, src.width), bool)     # the fringe clean-up leaves the green glass alone (not the fingers)
    sp = np.asarray(src).astype(int)
    keep[JAR[1]:JAR[3], JAR[0]:JAR[2]] = (sp[..., 1] >= sp[..., 0])[JAR[1]:JAR[3], JAR[0]:JAR[2]]
    fig, box = hub_key.key(src, fringe=14, keep=keep)
    fig = hub_key.scaled(fig, SCALE)
    fig = hub_key.tone(fig, TONE["mul"], TONE["lift"], TONE["gamma"])
    fig = hub_key.side_light(fig, [1.0, 0.72, 0.36], "left", 0.2)
    pos = [round(FEET_ROOM[0] - (FEET_FIG[0] - box[0]) * SCALE), round(FEET_ROOM[1] - (FEET_FIG[1] - box[1]) * SCALE)]
    fx, fy = FEET_ROOM[0] + 6, FEET_ROOM[1] - 4
    comp.alpha_composite(hub_key.shadow(comp.size, (fx, fy), 120, 16, 125, 9))
    info["layers"].append({"id": "lindqvist_shadow", "shadow": [fx, fy, 125, 17]})
    fig.save(os.path.join(OUT, "station_lindqvist.png"))
    info["layers"].append({"id": "lindqvist", "image": "res://campaign/hub/station_lindqvist.png", "pos": pos,
                           "size": [fig.width, fig.height]})
    hub_key.paste(comp, fig, pos)
    jar = [round(pos[0] + (390 - box[0]) * SCALE), round(pos[1] + (130 - box[1]) * SCALE)]
    # what the hub animates in code (room pixels): the lamp's flicker, the jars' slow green glow (his jar too), mist
    # and rain at the window, his breath
    green = [0.62, 1.0, 0.25]
    info["fx"] = {
        "lamps": [[838, 405, 60, [1.0, 0.75, 0.4]]],
        "glows": [[158, 435, 62, green], [250, 462, 44, green], [318, 490, 34, green], [50, 480, 40, green],
                  [797, 258, 44, green], [928, 255, 42, green], [870, 296, 30, green], [1175, 448, 26, green],
                  [1080, 448, 22, green], [1600, 118, 34, green], [jar[0], jar[1], 48, green]],
        "mist": {"rect": [362, 6, 226, 452], "color": [0.62, 0.78, 0.6], "rain": 0.55},
        "breathe": {"lindqvist": 0.005},
    }
    fb = (pos[0] + round((598 - box[0]) * SCALE) - 50, pos[1] + round((150 - box[1]) * SCALE) - 50)
    hub_key.face(comp, (fb[0], fb[1], fb[0] + 100, fb[1] + 100), os.path.join(OUT, "station_lindqvist_face.png"))
    info["focus"] = [0.95, 0.5]     # a narrow box crops mostly the left: Lindqvist stands at the right
    with open(os.path.join(OUT, "station.json"), "w") as f:
        json.dump(info, f, indent=1)
    if "--preview" in sys.argv:
        comp.convert("RGB").save(sys.argv[sys.argv.index("--preview") + 1])
    print("station hub:", [(l["id"], l.get("pos"), l.get("size")) for l in info["layers"]], "face", fb, "jar", jar)


if __name__ == "__main__":
    main()
