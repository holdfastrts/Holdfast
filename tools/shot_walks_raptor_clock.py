"""GIFs of tools/shot_walks_raptor_clock.gd's shots: docs/shots/walks_raptor_clock/<unit>_walk_8dirs.gif (the middle of the
picture, at screen size, 64 colours), then the single shots are removed.
  python3 tools/shot_walks_raptor_clock.py"""
import glob
import os

from PIL import Image

D = "docs/shots/walks_raptor_clock/"
CROP = {"clock_soldier": 900, "raptor": 1000}
for unit, side in CROP.items():
    fs = sorted(glob.glob(D + unit + "_[0-9][0-9].png"))
    if not fs:
        continue
    frames = []
    for f in fs:
        im = Image.open(f).convert("RGB")
        c = (im.width - side) // 2, (im.height - side) // 2
        frames.append(im.crop((c[0], c[1], c[0] + side, c[1] + side)).quantize(64, dither=Image.Dither.NONE))
    frames[0].save(D + unit + "_walk_8dirs.gif", save_all=True, append_images=frames[1:], duration=67, loop=0)
    for f in fs:
        os.remove(f)
    print(unit, len(frames), "frames")
