"""Compose parts of several repaints into the menu painting by hand-drawn masks (owner 2026-11-13: "the healing priests,
the previous cross carrier and the battle line we made before adding the priests"). Layers in art/menu_fix/layers.json:
  {"src": png (scaled to "box"), "box": [x0,y0,x1,y1] where the source sits in the painting, "poly": [[x,y],...] the part
   to take (painting coords), "dx"/"dy": move the taken part, "keep": [[poly], ...] base areas that stay on top,
   "feather": px}
applied in order over assets/menu/battle.jpg's source (art/menu_fix/battle_current.png).
  python3 tools/menu_fix_layers.py OUT.png"""
import json, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

base = Image.open("art/menu_fix/battle_current.png").convert("RGB")
W, H = base.size
out = np.asarray(base).astype(float)
orig = out.copy()
for L in json.load(open("art/menu_fix/layers.json")):
    if L.get("src") == "@base":
        src = orig.copy()
    elif L.get("src") == "@out":      # what has been composed so far (to move a finished figure)
        src = out.copy()
    else:
        x0, y0, x1, y1 = L["box"]
        im = Image.open(L["src"]).convert("RGB").resize((x1 - x0, y1 - y0), Image.LANCZOS)
        src = orig.copy()
        src[y0:y1, x0:x1] = np.asarray(im).astype(float)
    for poly, cx, cy in L.get("clone", []):   # cover a figure with the source's own texture from (cx, cy) away
        cm = Image.new("L", (W, H), 0)
        ImageDraw.Draw(cm).polygon([tuple(p) for p in poly], fill=255)
        ca = (np.asarray(cm.filter(ImageFilter.GaussianBlur(6))).astype(float) / 255.0)[..., None]
        shifted = np.roll(np.roll(src, -cy, 0), -cx, 1)
        src = src * (1 - ca) + shifted * ca
    if L.get("inpaint"):         # figures to take out of the source (a too-small drummer): painted over from around them
        import cv2
        hm = np.zeros(src.shape[:2], np.uint8)
        for poly in L["inpaint"]:
            cv2.fillPoly(hm, [np.array(poly, np.int32)], 255)
        src = cv2.inpaint(np.clip(src, 0, 255).astype(np.uint8), hm, 9, cv2.INPAINT_TELEA).astype(float)
    dx, dy = L.get("dx", 0), L.get("dy", 0)
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon([(x + dx, y + dy) for x, y in L["poly"]], fill=255)
    for k in L.get("keep", []):
        ImageDraw.Draw(m).polygon([tuple(p) for p in k], fill=0)
    if "bright_above" in L:     # above this row only the bright parts (a glowing cross on a dark sky), not the sky itself
        yb, thr = L["bright_above"]
        lum = moved_l = np.roll(np.roll(src, dy, 0), dx, 1).mean(2)
        from scipy import ndimage
        br = ndimage.binary_dilation(lum > thr, iterations=3)
        a0 = np.asarray(m).copy()
        a0[:yb][~br[:yb]] = 0
        m = Image.fromarray(a0)
    m = m.filter(ImageFilter.GaussianBlur(L.get("feather", 10)))
    a = (np.asarray(m).astype(float) / 255.0)[..., None]
    moved = np.roll(np.roll(src, dy, 0), dx, 1)
    out = out * (1 - a) + moved * a
Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(sys.argv[1])
