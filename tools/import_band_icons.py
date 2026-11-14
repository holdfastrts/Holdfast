#!/usr/bin/env python3
"""The Marching Band's icons (the owner's ChatGPT sheets, 2026-11-13), in art/ui/icons3/:

  band_portraits.png  3 steel portrait frames: band (the Drummer, the band's portrait), band_fifer, band_piper
  band_abilities.png  4 steel ability frames: ab_band_drums, ab_band_fife, ab_band_pipes (the SOLOs), ab_band_join
  ab_reload.png       one steel frame filling the picture (no magenta): ab_reload, the RELOAD command (2026-11-14)

Cut like round 13's steel sheets (tools/import_round13.py): the picture inside the frame, made square, box-shrunk and
set in the Crown icons' steel bevel -> assets/icons/<name>.png. The sheets' ground is magenta (tools/hub_key.bg_mask).
They replace the code-drawn tools/make_band_icons.py pictures. Usage: python3 tools/import_band_icons.py"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
_argv = sys.argv[:]
sys.argv = sys.argv[:1]
import import_round11 as r  # noqa: E402
from hub_key import bg_mask  # noqa: E402
sys.argv = _argv

SRC = "art/ui/icons3"
SHEETS = {
    "band_portraits": ["band", "band_fifer", "band_piper"],
    "band_abilities": ["ab_band_drums", "ab_band_fife", "ab_band_pipes", "ab_band_join"],
}

SINGLE = ["ab_reload"]


def build():
    for sheet, names in SHEETS.items():
        px = r.load(f"{SRC}/{sheet}.png")
        bg = bg_mask(px.astype(float))
        for name, sl in zip(names, r.frame_boxes(px, bg, len(names))):
            oy0, oy1, ox0, ox1 = r.outer_edges(bg, sl)
            iy0, iy1, ix0, ix1 = r.inner_box(px, oy0, oy1, ox0, ox1)
            pic = px[iy0:iy1, ix0:ix1]
            r.save_icon(r.framed(r.shrink(r.square(pic, name), r.INNER)), name)
            print(name, (ox0, oy0, ox1, oy1), "inner", (ix0, iy0, ix1, iy1))

    for name in SINGLE:             # one frame filling the whole picture
        px = r.load(f"{SRC}/{name}.png")
        iy0, iy1, ix0, ix1 = r.inner_box(px, 0, px.shape[0] - 1, 0, px.shape[1] - 1)
        r.save_icon(r.framed(r.shrink(r.square(px[iy0:iy1, ix0:ix1], name), r.INNER)), name)
        print(name, "inner", (ix0, iy0, ix1, iy1))


if __name__ == "__main__":
    build()
