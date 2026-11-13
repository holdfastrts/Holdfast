"""Vary the menu painting's front Springers (owner 2026-11-13: "the springers being repetitive"): they all stood in the
same pose, drills out, spring at rest. Here, from the painting itself (no repaint):
  - the middle one LAUNCHES: its spring uncoils (stretched up), the body and drills ride up with it, the foot plate
    stays on the ground; the ground it showed before is filled with the mud's own texture;
  - the bottom one LEANS into its bounce (tilted forward to the left).
Writes art/menu_fix/f42_springer_poses.png (the whole painting with these two changed), which art/menu_fix/layers.json
takes over the Springers' area.
  python3 tools/menu_springer_poses.py IN.png"""
import sys
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

src = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(np.float32)
H, W = src.shape[:2]
out = src.copy()


def poly_mask(pts, feather=0):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon([tuple(p) for p in pts], fill=255)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather))
    return np.asarray(m).astype(np.float32) / 255.0


def mud_fill(img, hole):
    """Fill `hole` (bool) smoothly from round it, then lay the mud's own brush detail over it so it isn't a smear."""
    u8 = np.clip(img, 0, 255).astype(np.uint8)
    base = cv2.inpaint(u8, hole.astype(np.uint8) * 255, 7, cv2.INPAINT_TELEA).astype(np.float32)
    patch = src[860:915, 1240:1340]                       # plain trodden mud left of the bottom Springer
    detail = patch - cv2.GaussianBlur(patch, (0, 0), 3)
    tile = np.tile(detail, (H // patch.shape[0] + 1, W // patch.shape[1] + 1, 1))[:H, :W]
    a = cv2.GaussianBlur(hole.astype(np.float32), (0, 0), 2)[..., None]
    return img * (1 - a) + (base + tile * 0.9) * a


# --- the middle Springer launches -----------------------------------------------------------------------------
LIFT = 46
upper = [[1478, 636], [1500, 640], [1506, 655], [1535, 655], [1540, 690], [1562, 700], [1585, 728], [1602, 758],
         [1585, 772], [1548, 752], [1532, 744], [1462, 746], [1448, 752], [1414, 772], [1396, 780], [1396, 768],
         [1418, 730], [1440, 708], [1452, 698], [1455, 660], [1470, 655]]
spring_top, spring_bot = 740, 812                          # the coils between the body and the foot plate
sx0, sx1 = 1472, 1550
um = poly_mask(upper) > 0.5
hole = cv2.dilate(um.astype(np.uint8), np.ones((9, 9), np.uint8)) > 0     # the old drills' soft rims too
coils = src[spring_top:spring_bot, sx0:sx1]
new_h = spring_bot - (spring_top - LIFT)
stretched = cv2.resize(coils, (sx1 - sx0, new_h), interpolation=cv2.INTER_CUBIC)
cm = np.zeros((H, W), bool)
cm[spring_top:spring_bot, sx0:sx1] = True
# the coils' own silhouette: what is not mud-brown in the original column (the coils are blue-grey and dark)
c = coils
coil_px = (c[..., 2] > c[..., 0] * 0.72) & (c.mean(2) < 170)
coil_px[:, :6] = False
coil_px[:, -5:] = False
coil_px = cv2.morphologyEx(coil_px.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
coil_px = cv2.morphologyEx(coil_px, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)) > 0
hole[spring_top:spring_bot, sx0:sx1] |= cv2.dilate(coil_px.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
out = mud_fill(out, hole)
# stretched coils
sil = cv2.resize(coil_px.astype(np.float32), (sx1 - sx0, new_h), interpolation=cv2.INTER_LINEAR)
sil = cv2.GaussianBlur(sil, (0, 0), 1.0)[..., None]
y0 = spring_top - LIFT
out[y0:spring_bot, sx0:sx1] = out[y0:spring_bot, sx0:sx1] * (1 - sil) + stretched * sil
# the body and drills, LIFT higher, with a soft edge
ua = cv2.GaussianBlur(um.astype(np.float32), (0, 0), 1.2)
ua_up = np.roll(ua, -LIFT, 0)[..., None]
src_up = np.roll(src, -LIFT, 0)
out = out * (1 - ua_up) + src_up * ua_up
# a soft shadow of the body on the ground where it stood
sh = np.zeros((H, W), np.float32)
cv2.ellipse(sh, (1500, 818), (70, 12), 0, 0, 360, 1.0, -1)
sh = cv2.GaussianBlur(sh, (0, 0), 7)[..., None]
out[:] = out * (1 - sh * 0.35 * (1 - np.pad(sil, ((y0, H - spring_bot), (sx0, W - sx1), (0, 0)))))

# --- the bottom Springer leans into its bounce -----------------------------------------------------------------
bot = [[1440, 778], [1452, 778], [1460, 800], [1486, 812], [1495, 840], [1520, 860], [1542, 892], [1530, 902],
       [1500, 886], [1486, 882], [1484, 941], [1423, 941], [1422, 884], [1405, 882], [1380, 902], [1350, 918],
       [1346, 906], [1370, 872], [1400, 850], [1408, 815], [1430, 800]]
bm = poly_mask(bot) > 0.5
ANG, PIV = 10.0, (1452, 1010)                                 # degrees anticlockwise about its foot (off the frame)
R = cv2.getRotationMatrix2D(PIV, ANG, 1.0)
rot = cv2.warpAffine(src, R, (W, H), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REFLECT)
rm = cv2.warpAffine(bm.astype(np.float32), R, (W, H), flags=cv2.INTER_LINEAR) > 0.5
gap = (cv2.dilate(bm.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0) & ~rm
out = mud_fill(out, gap)
ra = cv2.GaussianBlur(rm.astype(np.float32), (0, 0), 1.2)[..., None]
out = out * (1 - ra) + rot * ra

Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save("art/menu_fix/f42_springer_poses.png")
