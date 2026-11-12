"""Shared by the hub importers (tools/import_hub_*.py, docs/campaign_hub_art.md): key a figure painted on flat magenta
(#FF00FF) out of its background, scale it, tone it into a room's light, and the small helpers the hubs share."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

BG = np.array([250.0, 2.0, 250.0])


def bg_mask(px):
    """The magenta background connected to the picture's border (float RGB array in)."""
    m = np.minimum(px[..., 0], px[..., 2]) - px[..., 1]
    lab, _n = ndimage.label(m > 110)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return np.isin(lab, list(border))


def key(img, erase_boxes=(), fringe=0, keep=None):
    """RGBA: the magenta background connected to the border made transparent, soft over 2 px, de-spilled; pockets of
    pure magenta shut in by the figure are keyed too. erase_boxes: (x0, y0, x1, y1) where pink paint over the magenta
    (a smoke wisp) is turned back into background first. fringe: a band that many pixels wide along the background
    where magenta mixed into fine edges (loose hair) is unmixed (a warm figure's own red and blue are not both over its
    green: skin and brown hair are left alone), the pixel losing that share of its alpha too; keep: a bool mask the fringe leaves alone (a green jar).
    Returns (the figure cropped to its pixels, that box)."""
    px = np.asarray(img.convert("RGB")).astype(float)
    for x0, y0, x1, y1 in erase_boxes:
        sub = px[y0:y1, x0:x1]
        pink = (np.minimum(sub[..., 0], sub[..., 2]) - sub[..., 1] > 25) & (sub[..., 0] > 110)
        sub[pink] = BG
    r, g, b = px[..., 0], px[..., 1], px[..., 2]
    m = np.minimum(r, b) - g                       # magenta-ness
    bgish = m > 110
    lab, _n = ndimage.label(bgish)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    # pockets of background shut in by the figure (between a hand, a pipe and a face): pure magenta, keyed too
    means = ndimage.mean(m, lab, range(1, _n + 1))
    sizes = ndimage.sum(bgish, lab, range(1, _n + 1))
    pockets = [i + 1 for i in range(_n) if means[i] > 170 and sizes[i] > 20 and (i + 1) not in border]
    bg |= np.isin(lab, pockets)
    fg = ~bg
    # alpha: 1 inside, a ramp on the 2-pixel rim by how magenta it is
    rim = fg & ndimage.binary_dilation(bg, iterations=2)
    a = np.where(fg, 1.0, 0.0)
    ramp = np.clip((200.0 - m) / 120.0, 0.0, 1.0)
    a[rim] = ramp[rim]
    # unmix the background out of the rim: c = a f + (1 - a) BG
    out = px.copy()
    aa = np.maximum(a, 0.05)[..., None]
    un = (px - (1.0 - aa) * BG) / aa
    out[rim] = np.clip(un[rim], 0, 255)
    # whatever is still magenta-ish on the rim loses its tint
    tint = rim & (np.minimum(out[..., 0], out[..., 2]) - out[..., 1] > 60)
    out[tint, 2] = np.minimum(out[tint, 2], out[tint, 1] + 40)
    out[tint, 0] = np.minimum(out[tint, 0], out[tint, 1] + 60)
    if fringe > 0:
        band = fg & ndimage.binary_dilation(bg, iterations=fringe) & ~rim
        if keep is not None:
            band &= ~keep
        m0 = np.minimum(px[..., 0], px[..., 2]) - px[..., 1]
        f = np.where(band & (m0 > -15.0), np.clip((m0 + 15.0) / 263.0, 0.0, 0.92), 0.0)
        ff = f[..., None]
        un = (px - ff * BG) / (1.0 - ff)
        out = np.where(band[..., None], np.clip(un, 0, 255), out)
        a = a * (1.0 - np.clip(f * 1.3, 0.0, 1.0))
        # what is left of it is red (the magenta's red with too little green under it): no warm hair or skin is
        # redder than 1.8 times its green, so the edge is held to that
        edge = band | rim
        out[..., 0] = np.where(edge, np.minimum(out[..., 0], out[..., 1] * 1.8 + 12.0), out[..., 0])
        out[..., 2] = np.where(edge, np.minimum(out[..., 2], out[..., 1] * 1.1 + 6.0), out[..., 2])
    rgba = np.dstack([out, a * 255.0]).astype(np.uint8)
    im = Image.fromarray(rgba, "RGBA")
    return im.crop(im.getbbox()), im.getbbox()


def scaled(fig, s):
    return fig.resize((round(fig.width * s), round(fig.height * s)), Image.LANCZOS)


def tone(fig, mul, lift=(0.0, 0.0, 0.0), gamma=1.0):
    """Into the room's light: multiply each channel (the room's colour of light), an optional lift of the shadows
    toward the room's ambient colour, and a gamma (contrast in the darks)."""
    a = np.asarray(fig).astype(float)
    c = a[..., :3] / 255.0
    if gamma != 1.0:
        c = np.power(c, gamma)
    c = c * np.array(mul) + np.array(lift) * (1.0 - c)
    a[..., :3] = c * 255.0
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def side_light(fig, warm, side="right", amount=0.25):
    """A gradient across the figure: the side toward the room's main light a little brighter and warmer, the other
    side darker (so a cut-out painted in even studio light sits in the room's lamp light)."""
    a = np.asarray(fig).astype(float)
    w = a.shape[1]
    x = np.linspace(0.0, 1.0, w)
    if side == "left":
        x = 1.0 - x
    k = (1.0 - amount) + 2.0 * amount * x            # 1 - amount .. 1 + amount
    a[..., :3] *= k[None, :, None]
    a[..., :3] = a[..., :3] * (1.0 - 0.15 * x[None, :, None]) + np.array(warm) * 255.0 * 0.15 * x[None, :, None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def shadow(size, centre, rx, ry, alpha=110, blur=9):
    """A soft ground shadow (an ellipse) as an RGBA layer of the room's size."""
    sh = Image.new("RGBA", size, (0, 0, 0, 0))
    fx, fy = centre
    ImageDraw.Draw(sh).ellipse([fx - rx, fy - ry, fx + rx, fy + ry], fill=(0, 0, 0, alpha))
    return sh.filter(ImageFilter.GaussianBlur(blur))


def paste(comp, fig, pos):
    comp.alpha_composite(fig, (max(pos[0], 0), max(pos[1], 0)), (max(-pos[0], 0), max(-pos[1], 0)))


def face(comp, box, out):
    """The talk box's portrait: a square cut from the composed room, 192 px."""
    comp.crop(box).convert("RGB").resize((192, 192), Image.LANCZOS).save(out)
