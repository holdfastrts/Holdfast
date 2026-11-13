"""Compose parts of several repaints into the menu painting by hand-drawn masks (owner 2026-11-13: "the healing priests,
the previous cross carrier and the battle line we made before adding the priests"). Layers in art/menu_fix/layers.json:
  {"src": png (scaled to "box"), "box": [x0,y0,x1,y1] where the source sits in the painting, "poly": [[x,y],...] the part
   to take (painting coords), "dx"/"dy": move the taken part, "keep": [[poly], ...] base areas that stay on top,
   "feather": px, "opacity": 0-1}
applied in order over assets/menu/battle.jpg's source (art/menu_fix/battle_current.png).
  python3 tools/menu_fix_layers.py OUT.png"""
import json, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

base = Image.open("art/menu_fix/battle_current.png").convert("RGB")
W, H = base.size
out = np.asarray(base).astype(float)
orig = out.copy()
def sprite(L, out):
    """A figure painted alone on flat magenta (owner 2026-11-13: compose the painting like the hubs): keyed with
    tools/hub_key.py, scaled to "height", its bottom centre at "at", optional "flip" and "tone", with a soft shadow."""
    sys.path.insert(0, "tools")
    from hub_key import key
    fig, _box = key(Image.open(L["sprite"]))
    if L.get("flip"):
        fig = fig.transpose(Image.FLIP_LEFT_RIGHT)
    k = L["height"] / fig.height
    fig = fig.resize((max(1, round(fig.width * k)), max(1, round(fig.height * k))), Image.LANCZOS)
    a = np.asarray(fig).astype(float)
    a[..., :3] *= np.array(L.get("tone", [1, 1, 1]))
    x = round(L["at"][0] - fig.width / 2)
    y = round(L["at"][1] - fig.height)
    if L.get("shadow", True):
        sh = Image.new("L", (W, H), 0)
        cx, cy, rw = L["at"][0], L["at"][1], fig.width * 0.45
        ImageDraw.Draw(sh).ellipse([cx - rw, cy - rw * 0.12, cx + rw, cy + rw * 0.12], fill=110)
        sa = (np.asarray(sh.filter(ImageFilter.GaussianBlur(6))).astype(float) / 255.0)[..., None]
        out = out * (1 - sa * 0.6)
    al = a[..., 3:4] / 255.0
    x0, y0 = max(x, 0), max(y, 0)
    x1, y1 = min(x + fig.width, W), min(y + fig.height, H)
    sub = out[y0:y1, x0:x1]
    fa = a[y0 - y:y1 - y, x0 - x:x1 - x]
    fal = al[y0 - y:y1 - y, x0 - x:x1 - x]
    out[y0:y1, x0:x1] = sub * (1 - fal) + np.clip(fa[..., :3], 0, 255) * fal
    return out


for L in json.load(open("art/menu_fix/layers.json")):
    if "sprite" in L:
        if __import__("os").path.exists(L["sprite"]):
            out = sprite(L, out)
        continue
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
    a = (np.asarray(m).astype(float) / 255.0)[..., None] * L.get("opacity", 1.0)   # a see-through layer (dust over a part)
    moved = np.roll(np.roll(src, dy, 0), dx, 1)
    out = out * (1 - a) + moved * a
Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(sys.argv[1])
