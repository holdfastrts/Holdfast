"""The Winder's WALK_WIND strip (winding a soldier while walking behind it; docs/winder_walk.md), built in CODE from his
two painted strips (a stand-in until ChatGPT paints one: the prompt is in docs/winder_walk.md, the entry in
docs/art_style_inconsistency.md):
  upper body (head, arms, the crank in his hands)  from wind_<view>.png frame i (rows above CUT)
  legs                                             from walk_<view>.png frame i (rows from CUT down)
Both strips share one cell (76x49, feet on the anchor 38,43) and line their heads up on the clock's stem
(tools/import_winder_v2.py), so the halves meet without shifting. Writes assets/units/winder/walk_wind_<view>.png and
the "walk_wind_<view>" frame counts in scripts/art_data.gd. The game plays it on the WALK beat (Unit.beat_of), so the
legs tick as in his walk and the crank turns a quarter on every step.

  python3 tools/winder_guide/walk_wind.py [--preview FILE]
"""
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

D = 'assets/units/winder/'
ART_DATA = 'scripts/art_data.gd'
DIRS = ['s', 'se', 'e', 'ne', 'n']
CELL = 76
# the seam (cell row): the hips, just under the hands and the crank in the wind frames
CUT = {'s': 35, 'se': 35, 'e': 35, 'ne': 35, 'n': 35}


def build(v):
    walk = np.array(Image.open(D + 'walk_%s.png' % v).convert('RGBA'))
    wind = np.array(Image.open(D + 'wind_%s.png' % v).convert('RGBA'))
    n = min(walk.shape[1], wind.shape[1]) // CELL
    out = np.zeros((walk.shape[0], n * CELL, 4), np.uint8)
    c = CUT[v]
    for f in range(n):
        x = slice(f * CELL, (f + 1) * CELL)
        out[:c, x] = wind[:c, x]
        # the legs only: the walk's swinging hands that reach under the seam are left out (only the pieces that touch
        # the ground row band, the feet and shins, are kept)
        lo = walk[c:, x]
        lab, k = ndi.label(lo[:, :, 3] > 0)
        feet = set(np.unique(lab[-8:][lab[-8:] > 0]).tolist())
        legs = np.isin(lab, list(feet))
        part = np.zeros_like(lo)
        part[legs] = lo[legs]
        # (the east views: the swinging steel hand overlaps the hip; its grey is not leg brass)
        top = part[:6].astype(int)
        grey = (top[:, :, 3] > 0) & (top[:, :, :3].max(2) - top[:, :, :3].min(2) < 30) & (top[:, :, :3].max(2) > 60)
        part[:6][grey] = 0
        lab, k = ndi.label(part[:, :, 3] > 0)          # (and the hand's dark outline left on its own)
        feet = set(np.unique(lab[-8:][lab[-8:] > 0]).tolist())
        part[~np.isin(lab, list(feet))] = 0
        out[c:, x] = part
        # the crank and hands that hang a pixel or two below the seam stay drawn over the legs
        low = wind[c:c + 3, x]
        keep = (low[:, :, 3] > 0) & (out[c:c + 3, x][:, :, 3] == 0)
        out[c:c + 3, x][keep] = low[keep]
    return out, n


def main():
    counts = {}
    sheets = []
    for v in DIRS:
        img, n = build(v)
        Image.fromarray(img).save(D + 'walk_wind_%s.png' % v)
        counts[v] = n
        sheets.append(img)
    src = open(ART_DATA).read()
    m = re.search(r'"winder": \{"cell": Vector2i\(76, 49\), "anchor": Vector2\(38, 43\), "frames": \{\n', src)
    assert m, 'winder entry not found in art_data.gd'
    src = re.sub(r'\t\t"walk_wind_(s|se|e|ne|n)": \d+,\n', '', src)
    add = ''.join('\t\t"walk_wind_%s": %d,\n' % (v, counts[v]) for v in DIRS)
    src = src[:m.end()] + add + src[m.end():]
    open(ART_DATA, 'w').write(src)
    if '--preview' in sys.argv:
        path = sys.argv[sys.argv.index('--preview') + 1]
        h = sheets[0].shape[0]
        w = max(s.shape[1] for s in sheets)
        bg = Image.new('RGBA', (w, h * len(sheets)), (60, 90, 60, 255))
        for i, s in enumerate(sheets):
            bg.alpha_composite(Image.fromarray(s), (0, i * h))
        bg.resize((bg.width * 5, bg.height * 5), Image.NEAREST).save(path)
    print('walk_wind:', counts)


if __name__ == '__main__':
    main()
