"""Blend the owner's ChatGPT repaints of crops of the main menu painting back into it (docs: art/menu_fix/).
Each art/menu_fix/<name>_fixed.png is the repaint of the crop boxes.json[<name>] of art/menu_fix/battle_full.png (the
original). It is scaled to the box, colour-matched to the original crop (per-channel mean/std on the outer ring, so the
light stays the painting's), and laid in with a feathered edge (FEATHER px fading to the original) so no seam shows.
boxes.json "_erase_lines": [x0, y0, x1, y1, width] strokes inpainted afterwards (a stray sword). Writes assets/menu/battle.jpg.  python3 tools/menu_fix_composite.py [--preview DIR]"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

D = "art/menu_fix"
FEATHER = 28


def main():
    base = Image.open(os.path.join(D, "battle_full.png")).convert("RGB")
    out = np.asarray(base).astype(float)
    boxes = json.load(open(os.path.join(D, "boxes.json")))
    used = []
    erase = boxes.pop("_erase_lines", [])
    for name, b in boxes.items():
        p = os.path.join(D, name + "_fixed.png")
        if not os.path.exists(p):
            continue
        x0, y0, x1, y1 = b
        w, h = x1 - x0, y1 - y0
        fx = np.asarray(Image.open(p).convert("RGB").resize((w, h), Image.LANCZOS)).astype(float)
        orig = out[y0:y1, x0:x1]
        ring = np.zeros((h, w), bool)
        ring[:FEATHER * 2, :] = ring[-FEATHER * 2:, :] = True
        ring[:, :FEATHER * 2] = ring[:, -FEATHER * 2:] = True
        for c in range(3):    # the repaint's tones toward the painting's, measured where they must meet
            fm, fs = fx[ring, c].mean(), fx[ring, c].std() + 1e-3
            om, os_ = orig[ring, c].mean(), orig[ring, c].std() + 1e-3
            fx[..., c] = (fx[..., c] - fm) * (0.5 + 0.5 * os_ / fs) + om * 0.6 + fm * 0.4
        m = Image.new("L", (w, h), 0)
        inner = Image.new("L", (w - 2 * FEATHER, h - 2 * FEATHER), 255)
        m.paste(inner, (FEATHER, FEATHER))
        # edges that are the painting's own border need no fade
        if x0 == 0 or y0 == 0 or x1 == base.width or y1 == base.height:
            a = np.asarray(m).copy()
            if x0 == 0: a[:, :FEATHER] = a[:, FEATHER:FEATHER + 1]
            if y0 == 0: a[:FEATHER, :] = a[FEATHER:FEATHER + 1, :]
            if x1 == base.width: a[:, -FEATHER:] = a[:, -FEATHER - 1:-FEATHER]
            if y1 == base.height: a[-FEATHER:, :] = a[-FEATHER - 1:-FEATHER, :]
            m = Image.fromarray(a)
        m = m.filter(ImageFilter.GaussianBlur(FEATHER / 2.5))
        a = (np.asarray(m).astype(float) / 255.0)[..., None]
        out[y0:y1, x0:x1] = orig * (1 - a) + np.clip(fx, 0, 255) * a
        used.append(name)
    im = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    if erase:     # stray bits the repaints kept (a sword with no hand): painted over from their surroundings
        import cv2
        a = np.asarray(im).copy()
        mask = np.zeros(a.shape[:2], np.uint8)
        for x0, y0, x1, y1, w in erase:
            cv2.line(mask, (x0, y0), (x1, y1), 255, w)
        a = cv2.inpaint(a, mask, 6, cv2.INPAINT_TELEA)
        im = Image.fromarray(a)
    im.save("assets/menu/battle.jpg", quality=92)
    print("menu painting: blended", used)
    if "--preview" in sys.argv:
        dd = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(dd, exist_ok=True)
        im.save(os.path.join(dd, "battle_fixed.png"))
        for name in used:
            x0, y0, x1, y1 = boxes[name]
            pad = 60
            bb = (max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad))
            w2 = Image.new("RGB", ((bb[2] - bb[0]) * 2, bb[3] - bb[1]))
            w2.paste(base.crop(bb), (0, 0)); w2.paste(im.crop(bb), (bb[2] - bb[0], 0))
            w2.save(os.path.join(dd, "before_after_%s.png" % name))


if __name__ == "__main__":
    main()
