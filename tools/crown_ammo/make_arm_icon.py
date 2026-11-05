#!/usr/bin/env python3
"""crown-ammo: the ARM WITH POWDER command icon (assets/icons/ab_arm_powder.png), put together from the painted pieces:
the command icons' dark frame (ab_supply's), the powder keg (assets/ui/stats/res_powder.png) and the loaded pistol
(pistol_loaded.png). Logged in docs/art_style_inconsistency.md (a stand-in until a painted one comes)."""
import os
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
frame = Image.open(os.path.join(ROOT, "assets/icons/ab_supply.png")).convert("RGBA")
w, h = frame.size
bg = frame.getpixel((10, 10))
inner = Image.new("RGBA", (w - 12, h - 12), bg)
out = frame.copy()
out.paste(inner, (6, 6))
keg = Image.open(os.path.join(ROOT, "assets/ui/stats/res_powder.png")).convert("RGBA").resize((44, 44), Image.LANCZOS)
out.alpha_composite(keg, (6, 4))
pis = Image.open(os.path.join(ROOT, "assets/ui/stats/pistol_loaded.png")).convert("RGBA").resize((36, 36), Image.LANCZOS)
out.alpha_composite(pis, (24, 24))
out.save(os.path.join(ROOT, "assets/icons/ab_arm_powder.png"))
print("wrote assets/icons/ab_arm_powder.png")
