#!/usr/bin/env python3
"""THIRD WINGS (the owner, 2026-10-30 19:46 and 2026-11-03: "the 3 wings that show up in icons and animation sprites of
the flying Brood... could you remove the third wings with code?"; docs/third_wing.md): ChatGPT drew some frames of the
Storm line with THREE wings. This module erases the extra wing from the owner's sheets AS THEY ARE CUT, so a re-import
keeps the fix:
  - tools/import_storm_line.py (Hatchlings, Storm Challenger) and tools/import_brood_fathers.py (the Storm Sire,
    kind "pterodactyl") call fix_rows(sheet, rows) on the cut-out frames of a sheet, before the frames are shrunk;
  - their portraits go through portrait_fixed(kind) (the extra wing arm painted out of the framed portrait with the
    portrait's own dark background).

HOW A WING IS ERASED (erase()): a hand-drawn polygon per frame (in the CUT-OUT frame's pixels: the frame's own box on
the sheet, the numbers read off gridded zooms) covers the extra wing; inside it the frame becomes transparent; little
pieces left cut off from the body by the cut (a wing tip, a claw) go too; the creature's new edge along the cut gets the
sheet's dark outline (OUTLINE source px thick, about one game pixel), so it reads as drawn. The rest of each frame stays
pixel for pixel as drawn. Every fix here is off the body (the wing lay outside it or over the background), so nothing
had to be painted back in behind it; no frame needed replacing.

ANCHORS AND TIMING stay: the importers line the flying frames up on the body's middle (the mean of its pixels), which
an erased wing would move; they take the anchors from the UNFIXED frames (the body stays where it was), and every
frame keeps its place in its strip.

Contact sheets for the owner (before on top, after below, enlarged, frame numbers):
  python3 -I tools/fix_third_wing.py --shots docs/shots/third_wing
(run after the importers; it reads the game strips and rebuilds the "before" from the sheets without the fix).
"""
import contextlib
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402

# (sheet, row, frame), 0-based as the importer cuts them -> (polygons in the cut-out frame's px, outline px, what it is)
FRAMES = {
    # HATCHLINGS (tools/import_storm_line.py; game strips 34 px tall, the sheet about 6.5x bigger)
    ("hatchling_se_chatgpt.png", 0, 2): (
        [[(0, 54), (36, 54), (48, 57), (60, 65), (72, 75), (76, 92), (76, 175), (0, 175)]], 4,
        "fly 3 (walk_se/idle_se frame 3): a second NEAR wing hanging down at the lower left (the raised near wing and "
        "the far wing down under the head stay)"),
    ("hatchling_se_chatgpt.png", 2, 4): (
        [[(-1, 50), (30, 41), (50, 37), (62, 33), (84, 34), (97, 38), (92, 50), (82, 58), (70, 66), (-1, 70)]], 4,
        "death 5: a second left wing stretched out to the far left (the folded left wing over the body stays)"),
    ("hatchling_s_chatgpt.png", 2, 4): (
        [[(-1, 40), (30, 30), (50, 22), (60, 9), (78, 9), (88, 20), (96, 28), (86, 38), (74, 48), (62, 58), (-1, 62)]], 4,
        "death 5: a second left wing stretched out to the far left"),
    ("hatchling_e_chatgpt.png", 2, 4): (
        [[(-1, 40), (30, 33), (50, 26), (68, 24), (88, 28), (92, 34), (84, 40), (72, 46), (60, 52), (-1, 54)]], 4,
        "death 5: a second left wing stretched out to the far left"),
    ("hatchling_ne_chatgpt.png", 2, 4): (
        [[(-1, 46), (30, 36), (50, 30), (64, 26), (84, 26), (94, 32), (86, 40), (76, 48), (64, 56), (-1, 60)]], 4,
        "death 5: a second left wing stretched out to the far left"),
    ("hatchling_n_chatgpt.png", 2, 0): (
        [[(66, -1), (100, -1), (124, 22), (124, 44), (114, 47), (104, 46), (94, 44), (84, 41), (74, 34), (64, 14)]], 4,
        "death 1: a third wing raised at the top middle (the left wing and the wing at the lower right stay)"),
    # STORM CHALLENGER (tools/import_storm_line.py; the sheet about 2.4x the game)
    ("storm_challenger_se_chatgpt.png", 0, 2): (
        [[(12, 52), (36, 47), (48, 50), (56, 58), (62, 72), (68, 84), (76, 92), (81, 100), (81, 182), (12, 182)]], 3,
        "fly 3 (walk_se/idle_se frame 3): a second NEAR wing hanging down at the lower left"),
    # STORM SIRE (tools/import_brood_fathers.py, kind "pterodactyl"; the dive sheet about 2x the game)
    ("pterodactyl_fly_dive_se_chatgpt.png", 1, 4): (
        [[(10, 4), (50, 12), (100, 38), (140, 66), (158, 90), (162, 116), (150, 112), (132, 100), (100, 84),
          (60, 68), (22, 52), (8, 44)]], 2,
        "dive 5 (attack_se frame 5): a second left wing raised behind the first"),
}

# the framed portraits (1254 px, the steel frame's inside about x 166..1090, y 166..1092): polygons on the SHEET
PORTRAITS = {
    "hatchlings": ("hatchling_portrait_chatgpt.png",
                   [[(140, 865), (340, 815), (440, 785), (475, 790), (470, 860), (455, 920), (450, 1000),
                     (445, 1100), (140, 1100)]],
                   "the second wing ARM and its membrane at the bottom left (the raised wing stays)"),
    "storm_challenger": ("storm_challenger_portrait_chatgpt.png",
                         [[(140, 820), (340, 820), (400, 810), (470, 815), (495, 840), (490, 900), (480, 1100),
                           (140, 1100)]],
                         "the second wing ARM (with its spikes) and membrane at the bottom left"),
}
INSIDE = (166, 166, 1090, 1092)      # the portraits' steel frame's inside (x0, y0, x1, y1): nothing outside it changes

OFF = False      # (True: the importers run as before this fix; for the "before" pictures)


def poly_mask(shape, polys):
    h, w = shape[:2]
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    for p in polys:
        d.polygon([tuple(map(float, q)) for q in p], fill=255)
    return np.array(m) > 0


def outline_colour(im):
    """The sheet's dark outline: the darkest of the frame's own edge pixels."""
    a = im[..., 3] > 0
    edge = a & ~ndimage.binary_erosion(a)
    rgb = im[..., :3][edge].astype(float)
    if not len(rgb):
        return np.array([20, 18, 12])
    lum = rgb.mean(1)
    dark = rgb[lum <= np.percentile(lum, 35)]
    return np.median(dark, 0)


def erase(im, polys, thick):
    """The frame without the pixels inside polys; loose bits cut off by it dropped; the new edge outlined."""
    out = im.copy()
    was = out[..., 3] > 0
    m = poly_mask(out.shape, polys) & was
    out[m] = 0
    a = out[..., 3] > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n > 1:
        sizes = ndimage.sum(a, lab, range(1, n + 1))
        big = sizes.max()
        near = ndimage.binary_dilation(m, iterations=6)
        for i in range(n):
            piece = lab == i + 1
            if sizes[i] < big * 0.2 and (piece & near).any():
                out[piece] = 0
                m |= piece
    a = out[..., 3] > 0
    # thin slivers left along the cut (a strip of the other wing's edge) go too: they would become a black spike
    dist = ndimage.distance_transform_edt(~m)
    r = max(1, thick // 2 + 1)
    yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
    opened = ndimage.binary_opening(a, structure=(xx * xx + yy * yy) <= r * r)
    sliver = a & ~opened & (dist <= 2 * thick)
    out[sliver] = 0
    m |= sliver
    a = out[..., 3] > 0
    # the cut edge: creature pixels within `thick` of an erased pixel (but not along the old silhouette)
    dist = ndimage.distance_transform_edt(~m)
    edge = a & (dist <= thick)
    col = outline_colour(im)
    out[edge, :3] = col.astype(np.uint8)
    return out, int(m.sum())


def fix_rows(sheet, rows, quiet=False):
    """The cut-out frames of one sheet (rows of frames) with the extra wings erased (FRAMES). Returns (rows, fixed),
    fixed = the (row, frame) keys changed."""
    fixed = []
    out = [list(r) for r in rows]
    if OFF:
        return out, fixed
    for (f, r, k), (polys, thick, what) in FRAMES.items():
        if f != sheet or r >= len(out) or k >= len(out[r]):
            continue
        out[r][k], n = erase(out[r][k], polys, thick)
        fixed.append((r, k))
        if not quiet:
            print(f"  third wing: {sheet} row {r + 1} frame {k + 1}: {n} px erased ({what})")
    return out, fixed


def fix_portrait_px(kind, px):
    """The framed portrait with the extra wing painted out in its own dark background."""
    if kind not in PORTRAITS:
        return px
    _f, polys, what = PORTRAITS[kind]
    px = px.copy()
    m = poly_mask(px.shape, polys)
    x0, y0, x1, y1 = INSIDE
    inside = np.zeros_like(m)
    inside[y0:y1, x0:x1] = True
    m &= inside
    rgb = px[..., :3].astype(int)
    # (the backdrop is a near-black blue-teal: blue above red; the creature's dark shading is olive, blue far below red)
    # (and away from the steel frame, whose inner shadow is pure black)
    deep = np.zeros_like(m)
    deep[y0 + 30:y1 - 30, x0 + 30:x1 - 30] = True
    bg = deep & ~m & (rgb.max(2) < 45) & (rgb[..., 2] >= rgb[..., 0] + 6) & (rgb.sum(2) >= 30)
    # every erased pixel takes the colour of the nearest background pixel (the dark backdrop, its soft gradient kept)
    _, (iy, ix) = ndimage.distance_transform_edt(~bg, return_indices=True)
    px[m, :3] = px[iy[m], ix[m], :3]
    print(f"  third wing: {kind} portrait: {int(m.sum())} px painted over ({what})")
    return px


@contextlib.contextmanager
def portrait_fixed(kind):
    """While inside, ia.load gives the kind's portrait sheet with its extra wing painted out."""
    if kind not in PORTRAITS or OFF:
        yield
        return
    f = PORTRAITS[kind][0]
    keep = ia.load

    def load(path):
        px = keep(path)
        return fix_portrait_px(kind, px) if path.endswith(f) else px
    ia.load = load
    try:
        yield
    finally:
        ia.load = keep


# ------------------------------------------------------------------ the owner's before/after pictures
def _sheet(frames, z, label, bg=(96, 104, 112)):
    w = max(f.shape[1] for f in frames) * z
    h = max(f.shape[0] for f in frames) * z
    can = Image.new("RGB", (len(frames) * (w + 6) + 6, h + 22), bg)
    d = ImageDraw.Draw(can)
    for k, f in enumerate(frames):
        p = Image.fromarray(f.astype(np.uint8), "RGBA").resize((f.shape[1] * z, f.shape[0] * z), Image.NEAREST)
        can.paste(p, (6 + k * (w + 6), 18), p)
        d.text((8 + k * (w + 6), 3), f"{label} {k + 1}", fill=(255, 235, 90))
    return can


def _frames(path, n):
    im = np.array(Image.open(path).convert("RGBA"))
    fw = im.shape[1] // n
    return [im[:, k * fw:(k + 1) * fw] for k in range(n)]


def shots(out_dir):
    """Before (the sheets imported without this fix, in a scratch folder) on top, after (the game's strips) below."""
    import io
    import shutil
    import tempfile
    os.makedirs(out_dir, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="third_wing_")
    keep_out, keep_argv, keep_stdout = ia.OUT, sys.argv, sys.stdout
    try:
        # the importers run here without the fix, into the scratch folder (their art_data.gd entries come out the same:
        # the anchors are the unfixed frames' either way)
        import fix_third_wing as me          # (the module the importers use, not this __main__ copy)
        import import_brood_fathers as ibf
        import import_storm_line as isl
        me.OFF = True
        ia.OUT = os.path.join(tmp, "assets")
        sys.stdout = io.StringIO()
        for mod, args in ((isl, []), (ibf, ["--only", "pterodactyl"])):
            sys.argv = ["x"] + args
            mod.ibn.FEET.clear()        # (one importer's anchors must not leak into the next's)
            mod.main()
    finally:
        me.OFF = False
        ia.OUT, sys.argv, sys.stdout = keep_out, keep_argv, keep_stdout
    try:
        strips = [("hatchlings", "walk_se", 6, 6), ("hatchlings", "death_se", 5, 6), ("hatchlings", "death_s", 5, 6),
                  ("hatchlings", "death_e", 5, 6), ("hatchlings", "death_ne", 5, 6), ("hatchlings", "death_n", 5, 6),
                  ("storm_challenger", "walk_se", 6, 3), ("pterodactyl", "attack_se", 6, 2)]
        for kind, strip, n, z in strips:
            before = _frames(os.path.join(tmp, "assets", "units", kind, strip + ".png"), n)
            after = _frames(os.path.join("assets", "units", kind, strip + ".png"), n)
            a = _sheet(before, z, "before")
            b = _sheet(after, z, "after")
            can = Image.new("RGB", (max(a.width, b.width), a.height + b.height + 4), (40, 40, 40))
            can.paste(a, (0, 0))
            can.paste(b, (0, a.height + 4))
            can.save(os.path.join(out_dir, f"{kind}_{strip}.png"))
            print(f"  {out_dir}/{kind}_{strip}.png")
        for kind in PORTRAITS:
            before = np.array(Image.open(os.path.join(tmp, "assets", "icons", kind + ".png")).convert("RGBA"))
            after = np.array(Image.open(os.path.join("assets", "icons", kind + ".png")).convert("RGBA"))
            can = _sheet([before, after], 5, "before / after")
            can.save(os.path.join(out_dir, f"{kind}_portrait.png"))
            print(f"  {out_dir}/{kind}_portrait.png")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    if "--shots" in sys.argv:
        shots(sys.argv[sys.argv.index("--shots") + 1])
    else:
        print(__doc__)
