"""Isolate figures from the main menu painting into the figure library (owner 2026-11-13: "instead of prompts can you do
it yourself?"). Segment Anything (rembg's "sam", vit_b) prompted with points on the figure (art/figures/isolate.json,
painting pixels; "neg" points exclude), on the crop "box" of "src" (default assets/menu/battle.jpg) at 2x. Writes
art/figures/cut/<name>.png (RGBA) and art/figures/<name>.png (on flat magenta, like the ChatGPT figures).
  python3 tools/menu_isolate.py [name ...]   (needs: pip install rembg onnxruntime)"""
import json, sys
from PIL import Image
from rembg import remove, new_session

import numpy as np
from scipy import ndimage


def clean(o, keep):
    """Drop the specks SAM leaves around a painted figure: alpha pieces under `keep` of the largest one go."""
    a = np.asarray(o).copy()
    m = a[..., 3] > 40
    lab, n = ndimage.label(ndimage.binary_closing(m, iterations=2))
    if n > 1:
        sz = ndimage.sum(m, lab, range(1, n + 1))
        good = [i + 1 for i in range(n) if sz[i] >= keep * sz.max()]
        a[..., 3][~np.isin(lab, good)] = 0
    return Image.fromarray(a)


SPEC = json.load(open("art/figures/isolate.json"))
names = sys.argv[1:] or list(SPEC)
s = new_session("sam")
for n in names:
    f = SPEC[n]
    src = Image.open(f.get("src", "assets/menu/battle.jpg")).convert("RGB")
    x0, y0, x1, y1 = f["box"]
    k = 2
    im = src.crop((x0, y0, x1, y1)).resize(((x1 - x0) * k, (y1 - y0) * k), Image.LANCZOS)
    prompt = [{"type": "point", "data": [(p[0] - x0) * k, (p[1] - y0) * k], "label": 1} for p in f["pos"]]
    prompt += [{"type": "point", "data": [(p[0] - x0) * k, (p[1] - y0) * k], "label": 0} for p in f.get("neg", [])]
    o = remove(im, session=s, sam_prompt=prompt)
    o = clean(o, f.get("keep_small", 0.02))
    o = o.crop(o.getbbox())
    o.save("art/figures/cut/%s.png" % n)
    m = Image.new("RGBA", (o.width + 60, o.height + 60), (255, 0, 255, 255))
    m.alpha_composite(o, (30, 30))
    m.convert("RGB").save("art/figures/%s.png" % n)
    print(n, o.size)
