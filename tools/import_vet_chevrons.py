#!/usr/bin/env python3
"""Veterancy chevrons (docs/vet_chevrons.md): the owner's ChatGPT sheet of three chevrons, cut into the game's files.

Source
  art/ui/vet_chevrons_chatgpt.png   three chevrons left to right: bronze, silver, gold, on flat magenta #FF00FF.
                                    Pixel art drawn big: each art pixel is a square block of screen pixels.

Output
  assets/ui/vet_bronze.png, vet_silver.png, vet_gold.png   one chevron each at its own pixel size (the sheet's: 15 x 11),
      transparent around it. The game draws them a fixed size on screen (VetChevrons.SCREEN_W), smoothly scaled from a
      4x copy it makes at load, so they stay crisp at every zoom.

How
  1. the magenta is keyed out (a pixel close to #FF00FF is background), the three blobs found by their columns
  2. each blob's art-pixel grid is found by trying 8..24 pixels across and keeping the grid whose blocks are the most
     even (the lowest spread of colour inside each block's middle)
  3. every block becomes one pixel: the median colour of its middle; a block mostly magenta is transparent

Usage (from the repo root)
  python3 tools/import_vet_chevrons.py [--sheet PATH] [--contact FILE]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

NAMES = ["bronze", "silver", "gold"]
SHEET = "art/ui/vet_chevrons_chatgpt.png"
OUT = "assets/ui"


def magenta(a):
    return (np.abs(a[:, :, 0] - 255) < 70) & (a[:, :, 1] < 90) & (np.abs(a[:, :, 2] - 255) < 70)


def blobs(fg):
    cols = np.where(fg.sum(0) > 2)[0]
    out = []
    s = p = cols[0]
    for c in cols[1:]:
        if c > p + 12:
            out.append((s, p))
            s = c
        p = c
    out.append((s, p))
    boxes = []
    for x0, x1 in out:
        rows = np.where(fg[:, x0:x1 + 1].sum(1) > 2)[0]
        boxes.append((x0, rows[0], x1 + 1, rows[-1] + 1))
    return boxes


def grid(sub):
    h, w = sub.shape[:2]
    best = None
    for n in range(8, 25):
        cw = w / n
        m = max(1, round(h / cw))
        ch = h / m
        err = 0.0
        for j in range(m):
            for i in range(n):
                blk = sub[int(j * ch + ch * 0.25):int((j + 1) * ch - ch * 0.25), int(i * cw + cw * 0.25):int((i + 1) * cw - cw * 0.25)]
                if blk.size:
                    err += blk.reshape(-1, 3).std(0).sum()
        err /= n * m
        if best is None or err < best[0]:
            best = (err, n, m)
    return best[1], best[2]


def cut(sub, n, m):
    h, w = sub.shape[:2]
    cw, ch = w / n, h / m
    img = np.zeros((m, n, 4), np.uint8)
    for j in range(m):
        for i in range(n):
            blk = sub[int(j * ch + ch * 0.25):int((j + 1) * ch - ch * 0.25), int(i * cw + cw * 0.25):int((i + 1) * cw - cw * 0.25)]
            px = blk.reshape(-1, 3)
            bg = magenta(blk).reshape(-1)
            if bg.mean() > 0.5:
                continue
            img[j, i, :3] = np.median(px[~bg], 0).astype(np.uint8)
            img[j, i, 3] = 255
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", default=SHEET)
    ap.add_argument("--contact", default="")
    args = ap.parse_args()
    if not os.path.exists(args.sheet):
        sys.exit("no sheet at %s (the game draws its own chevrons until it is there)" % args.sheet)
    a = np.asarray(Image.open(args.sheet).convert("RGB")).astype(float)
    fg = ~magenta(a)
    boxes = blobs(fg)
    if len(boxes) != 3:
        sys.exit("expected 3 chevrons on the sheet, found %d" % len(boxes))
    os.makedirs(OUT, exist_ok=True)
    outs = []
    for name, (x0, y0, x1, y1) in zip(NAMES, boxes):
        sub = a[y0:y1, x0:x1]
        n, m = grid(sub)
        img = cut(sub, n, m)
        path = os.path.join(OUT, "vet_%s.png" % name)
        Image.fromarray(img, "RGBA").save(path)
        outs.append(img)
        print("%s: %dx%d art pixels from a %dx%d box -> %s" % (name, n, m, x1 - x0, y1 - y0, path))
    if args.contact:
        k = 12
        w = sum(o.shape[1] for o in outs) * k + 40
        hh = max(o.shape[0] for o in outs) * k + 20
        sheet = Image.new("RGBA", (w, hh), (60, 90, 50, 255))
        x = 10
        for o in outs:
            im = Image.fromarray(o, "RGBA").resize((o.shape[1] * k, o.shape[0] * k), Image.NEAREST)
            sheet.alpha_composite(im, (x, 10))
            x += o.shape[1] * k + 10
        sheet.save(args.contact)


if __name__ == "__main__":
    main()
