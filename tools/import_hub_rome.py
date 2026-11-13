"""The Rome study hub (docs/campaign_hub_art.md): the owner's three ChatGPT pictures (2026-11-11) made into the hub's
layers.

  art/campaign/hub/rome_room_chatgpt.png     the empty study (background), 1672 x 941
  art/campaign/hub/rome_king_chatgpt.png     the King in his chair, on flat magenta
  art/campaign/hub/rome_tomasz_chatgpt.png   old Tomasz (cardinal), on flat magenta

Writes campaign/hub/rome_room.jpg, rome_king.png and rome_tomasz.png (the figures keyed out: the magenta that
touches the picture's border goes, soft at the edge, with the magenta taken out of the edge pixels; purple robes inside
stay), rome_desk.png (the desk's front, cut from the room, drawn over the King so he sits BEHIND it), and
campaign/hub/rome.json (where each layer sits in the room's pixels; read by scripts/campaign/hub_scene.gd).
  python3 tools/import_hub_rome.py [--preview OUT.png]"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hub_key  # noqa: E402

SRC = "art/campaign/hub/rome_%s_chatgpt.png"
OUT = "campaign/hub"

# Where the figures go, in the room's pixels: the layer's own scale and its top-left corner. The King's lion
# armrests land on the room chair's arms; Tomasz stands on the clear floor on the left, turned to the King.
PLACE = {
    "king": {"scale": 0.52, "at": [923, 164]},
    "tomasz": {"scale": 0.74, "at": [-262, 222], "tone": [0.76, 0.68, 0.62]},
}
FACES = {"king": (1338, 160, 1498, 320), "tomasz": (288, 228, 398, 338)}
# The desk's back edge in the room (x, y): everything below it, right of the candelabrum, is the desk drawn over
# the King.
DESK_EDGE = [(840, 640), (1000, 626), (1200, 616), (1400, 608), (1672, 600)]


# The King's painted smoke wisp, over the magenta, came out pink: it is erased (the hub draws its own smoke).
SMOKE_BOX = {"king": (700, 150, 840, 330)}


def key(img, name=""):
    return hub_key.key(img, [SMOKE_BOX[name]] if name in SMOKE_BOX else [])


def desk(room):
    w, h = room.size
    mask = Image.new("L", (w, h), 0)
    pts = list(DESK_EDGE) + [(w, h), (DESK_EDGE[0][0], h)]
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    d = room.convert("RGBA")
    d.putalpha(mask)
    return d.crop(mask.getbbox()), mask.getbbox()


def main():
    os.makedirs(OUT, exist_ok=True)
    room = Image.open(SRC % "room").convert("RGB")
    room.save(os.path.join(OUT, "rome_room.jpg"), quality=90)
    info = {"room": "res://campaign/hub/rome_room.jpg", "size": list(room.size), "layers": []}
    comp = room.convert("RGBA")
    for name in ("tomasz", "king"):
        fig, box = key(Image.open(SRC % name), name)
        p = PLACE[name]
        s = p["scale"]
        fig = fig.resize((round(fig.width * s), round(fig.height * s)), Image.LANCZOS)
        if "tone" in p:          # into the room's candlelight (his scarlet was painted in daylight)
            a = np.asarray(fig).astype(float)
            a[..., :3] *= np.array(p["tone"])
            fig = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
        pos = [round(p["at"][0] + box[0] * s), round(p["at"][1] + box[1] * s)]
        fig.save(os.path.join(OUT, "rome_%s.png" % name))
        info["layers"].append({"id": name, "image": "res://campaign/hub/rome_%s.png" % name, "pos": pos,
                               "size": [fig.width, fig.height]})
        if name == "tomasz":     # his shadow on the floor, under his feet
            sh = Image.new("RGBA", comp.size, (0, 0, 0, 0))
            fx, fy = pos[0] + fig.width // 2, pos[1] + fig.height - 6
            ImageDraw.Draw(sh).ellipse([fx - 130, fy - 14, fx + 110, fy + 16], fill=(0, 0, 0, 110))
            from PIL import ImageFilter
            sh = sh.filter(ImageFilter.GaussianBlur(9))
            comp.alpha_composite(sh)
            info["layers"].append({"id": "tomasz_shadow", "shadow": [fx - 10, fy, 120, 15]})
        comp.alpha_composite(fig, (max(pos[0], 0), max(pos[1], 0)),
                             (max(-pos[0], 0), max(-pos[1], 0)))
        if name == "king":
            dk, dbox = desk(room)
            dk.save(os.path.join(OUT, "rome_desk.png"))
            info["layers"].append({"id": "desk", "image": "res://campaign/hub/rome_desk.png",
                                   "pos": [dbox[0], dbox[1]], "size": [dk.width, dk.height]})
            comp.alpha_composite(dk, (dbox[0], dbox[1]))
    # what the hub animates in code (room pixels): the pipe's smoke and the match, the candle flames, breathing
    info["fx"] = {"smoke": [1335, 343], "match": [1327, 331], "candles": [[617, 315], [677, 272], [737, 325]],
                  "breathe": {"king": 0.006, "tomasz": 0.004}}
    # the talk box's portraits: the faces, cut from the room as composed (square, room pixels)
    for name, box in FACES.items():
        comp.crop(box).convert("RGB").resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "rome_%s_face.png" % name))
    info["focus"] = [0.72, 0.5]    # the box is often narrower than the painting: crop more from the left (the King sits right)
    with open(os.path.join(OUT, "rome.json"), "w") as f:
        json.dump(info, f, indent=1)
    if "--preview" in sys.argv:
        comp.convert("RGB").save(sys.argv[sys.argv.index("--preview") + 1])
    print("rome hub:", [(l["id"], l.get("pos"), l.get("size")) for l in info["layers"]])


if __name__ == "__main__":
    main()
