"""The band's balance, measured (job band-repertoire, docs/band_music.md "Repertoire and playlist"): each part's
loudness alone (LUFS) and in the band, and how CLEAR each part is in the band: the share of the time-frequency
cells it sounds in (0.1 s x a third of an octave, 150 Hz to 12 kHz) where it is at least as
loud as all the others together, -3 dB (a rough measure of how easily a part is picked out). BEFORE = the files of 0.37.5 (git f015e851) at
0.37.5's levels; AFTER = the files now at BandSound's levels.
Run: python3 tools/audio/band_balance.py"""
import os
import subprocess
import sys

import numpy as np
import pyloudnorm as pyln
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_band_music as m  # noqa: E402

SR = 44100
METER = pyln.Meter(SR)


def lufs(x):
    v = METER.integrated_loudness(x)
    return float(v) if np.isfinite(v) else -70.0


def owned(parts):
    """{part: share of cells it owns}."""
    f, t, Z = None, None, {}
    for k, x in parts.items():
        f, t, z = signal.stft(x, SR, nperseg=4410, noverlap=0)
        Z[k] = np.abs(z) ** 2
    edges = 150 * 2 ** (np.arange(0, 6.4, 1 / 3))
    bands = [(lo, hi) for lo, hi in zip(edges[:-1], edges[1:])]
    E = {k: np.stack([z[(f >= lo) & (f < hi)].sum(axis=0) for lo, hi in bands]) for k, z in Z.items()}
    tot = sum(E.values()) + 1e-12
    big = max(E.values(), key=lambda e: e.sum())
    keys = list(E)
    stack = np.stack([E[k] for k in keys])
    win = np.argmax(stack, axis=0)
    loud_cell = tot > tot.max() * 1e-4
    out = {}
    for i, k in enumerate(keys):
        others = tot - E[k]
        clear = E[k] >= others * 0.5             # the part at least as loud as everything else there, -3 dB
        there = E[k] >= tot * 1e-3               # cells where the part sounds at all (within 30 dB of the cell)
        out[k] = float((clear & there & loud_cell).sum() / max(1, (there & loud_cell).sum()))
    return out


def fife_line(lv):
    """The fife's melody over the others AT ITS OWN PITCH (its strongest partial 600-1800 Hz each 0.1 s): median dB."""
    Z = {}
    for k, v in lv.items():
        f, t, z = signal.stft(v, SR, nperseg=4410, noverlap=0)
        Z[k] = np.abs(z) ** 2
    sel = np.nonzero((f > 600) & (f < 1800))[0]
    fz = Z["fife"][sel]
    on = fz.max(axis=0) > fz.max() * 1e-3
    r = []
    for j in np.nonzero(on)[0]:
        b = sel[int(np.argmax(fz[:, j]))]
        fe = Z["fife"][b - 1:b + 2, j].sum()
        ot = sum(Z[k][b - 1:b + 2, j].sum() for k in Z if k != "fife")
        r.append(10 * np.log10(fe / (ot + 1e-12)))
    return float(np.median(r))


def snare_hits(lv):
    """The snare's strokes over the others (2-8 kHz, 12 ms frames, the strongest tenth of the drums' frames): median dB."""
    Z = {}
    for k, v in lv.items():
        f, t, z = signal.stft(v, SR, nperseg=512, noverlap=0)
        Z[k] = (np.abs(z) ** 2)[(f > 2000) & (f < 8000)].sum(axis=0)
    d = Z["drums"]
    ot = sum(Z[k] for k in Z if k != "drums")
    top = d >= np.quantile(d, 0.9)
    return float(np.median(10 * np.log10(d[top] / (ot[top] + 1e-12))))


def report(tag, parts, gains):
    lv = {k: parts[k] * 10 ** (g / 20) for k, g in zip(parts, gains)}
    alone = {k: lufs(v) for k, v in lv.items()}
    band = sum(lv.values())
    own = owned(lv)
    print("%-7s alone LUFS: %s | band %.1f LUFS | clear: %s | the fife's tune %+.1f dB, the snare %+.1f dB over the rest" % (
        tag, ", ".join("%s %.1f" % (k, v) for k, v in alone.items()), lufs(band),
        ", ".join("%s %.0f%%" % (k, 100 * v) for k, v in own.items()), fife_line(lv), snare_hits(lv)))
    return alone, own


def main():
    before = {}
    for k in ("drums", "fife", "pipes"):
        r = subprocess.run(["git", "show", "f015e851:assets/audio/band/%s.ogg" % k], capture_output=True,
                           cwd=m.ROOT)
        p = "/tmp/old_band_%s.ogg" % k
        open(p, "wb").write(r.stdout)
        before[k] = m.decode(p)
    n = min(len(v) for v in before.values())
    report("BEFORE", {k: v[:n] for k, v in before.items()}, [m.OLD_QUIET] * 3)
    for t in ("scotland", "grenadiers", "garryowen", "minstrel", "godsave"):
        after = {k: m.decode(os.path.join(m.OUT, "%s_%s.ogg" % (t, k))) for k in ("drums", "fife", "pipes")}
        n = min(len(v) for v in after.values())
        report(t[:7], {k: v[:n] for k, v in after.items()}, [m.QUIET] * 3)


if __name__ == "__main__":
    main()
