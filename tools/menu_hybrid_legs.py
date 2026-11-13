"""The menu painting had a Clock Soldier (sword, shield) standing on a Springer's spring (a hallucination; owner
2026-11-13 circled it). Its spring is taken out and it gets a Clock Soldier's legs: the big front Clock Soldier's own
painted legs, scaled to its size, so it is a real Clock Soldier again.
Writes art/menu_fix/f43_hybrid_legs.png (the whole painting with this change); art/menu_fix/layers.json takes the
area from it.
  python3 tools/menu_hybrid_legs.py IN.png"""
import sys
import cv2
import numpy as np
from PIL import Image, ImageDraw

src = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(np.float32)
H, W = src.shape[:2]
out = src.copy()

# 1. the spring out: painted over from the smoke round it, with the smoke's own brush detail laid over the fill
spring = [[1248, 602], [1298, 600], [1304, 622], [1298, 652], [1252, 656], [1244, 626]]
hole = np.zeros((H, W), np.uint8)
cv2.fillPoly(hole, [np.array(spring, np.int32)], 255)
base = cv2.inpaint(np.clip(out, 0, 255).astype(np.uint8), hole, 9, cv2.INPAINT_TELEA).astype(np.float32)
patch = src[548:580, 1196:1236]                           # plain bright smoke left of its head
detail = patch - cv2.GaussianBlur(patch, (0, 0), 3)
tile = np.tile(detail, (H // patch.shape[0] + 1, W // patch.shape[1] + 1, 1))[:H, :W]
a = cv2.GaussianBlur(hole.astype(np.float32) / 255, (0, 0), 3)[..., None]
out = out * (1 - a) + (base + tile) * a

# 2. the legs: cut from the big Clock Soldier (hips at y 742), scaled, hips under its body
X0, Y0, X1, Y1 = 1178, 740, 1308, 822
legs = [[[1192, 748], [1216, 744], [1213, 790], [1207, 809], [1186, 811], [1180, 791], [1187, 770]],
        [[1250, 748], [1273, 741], [1291, 775], [1306, 804], [1301, 819], [1274, 819], [1258, 791]]]
m = Image.new("L", (X1 - X0, Y1 - Y0), 0)
for p in legs:
    ImageDraw.Draw(m).polygon([(x - X0, y - Y0) for x, y in p], fill=255)
K = 0.55
w, h = round((X1 - X0) * K), round((Y1 - Y0) * K)
piece = cv2.resize(src[Y0:Y1, X0:X1], (w, h), interpolation=cv2.INTER_AREA)
ma = cv2.resize(np.asarray(m).astype(np.float32) / 255, (w, h), interpolation=cv2.INTER_AREA)
ma = cv2.GaussianBlur(ma, (0, 0), 0.6)[..., None]
tx, ty = 1268 - w // 2, 600
piece *= np.array([0.95, 0.93, 0.92])                     # a step farther back: a touch less bright
out[ty:ty + h, tx:tx + w] = out[ty:ty + h, tx:tx + w] * (1 - ma) + piece * ma

Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save("art/menu_fix/f43_hybrid_legs.png")
