"""Music study (job music-study): export every piece's score as notes, without rendering audio.

Each piece function in compose.py (and the modules it registers) builds a Song whose notes sit in
song.ev before render(). This tool calls every piece, keeps song.ev and the score's tempo, metre,
tonic and mode, and writes one JSON per piece. Nothing in assets/ is touched.

Usage: python3 tools/music/study_export.py OUTDIR [name ...]
Each JSON: {name, file, title, cls, bpm, meter, tonic, mode, ev: [[t0, kind, inst, midi, dur, vel, pan], ...]}
kind "n" = a pitched note (dur in seconds), "d" = a drum hit (inst = drum code, midi 0).
Times are the written grid: the humanised timing jitter is left out (see _NoJitter), and pieces whose tempo
breathes are put back on their nominal tempo (their tempo curve is kept in "tempo_curve").
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import compose as C  # noqa: E402

# the stings are written under another file name than their function name
FILE_OF = {"crown_win": "win_crown", "brood_win": "win_brood", "clock_win": "win_clockwork"}


class _NoJitter:
    """Wraps a Song's random generator: the timing jitter (normal(0, humanize) and normal(0, humanize * 0.7)) comes
    back as 0, but the draw is still made, so every later random choice (scattered bubbles, insects) is the same as
    in the shipped piece. The exported times are then the written grid, not the humanised performance."""

    def __init__(self, rng, h):
        self._rng, self._h = rng, h

    def normal(self, loc=0.0, scale=1.0, *a, **k):
        x = self._rng.normal(loc, scale, *a, **k)
        if self._h and scale in (self._h, self._h * 0.7):
            return loc
        return x

    def __getattr__(self, k):
        return getattr(self._rng, k)


_orig_init = C.Song.__init__


def _init(self, *a, **k):
    _orig_init(self, *a, **k)
    self.rng = _NoJitter(self.rng, self.humanize)


def export(name):
    C.Song.__init__ = _init
    try:
        s = C.SONGS[name]()
    finally:
        C.Song.__init__ = _orig_init
    ev = getattr(s, "ev", None)
    if ev is None:
        return None
    # pieces whose tempo moves (brood_more's BSong) keep a beat -> seconds map in s._cum; the times are put back
    # on the nominal grid (beats at the score's bpm) so that bars line up, and the tempo curve is kept apart
    cum = getattr(s, "_cum", None)
    nominal = 60.0 / s.bpm
    tempo_curve = []
    if cum is not None:
        st = s._st
        grid = np.arange(len(cum)) * st

        def to_nom(t):
            return float(np.interp(t, cum, grid)) * nominal
        bar_beats = np.arange(0, (ev and max(e[0] + e[4] for e in ev) or 0) / nominal + s.meter, s.meter)
        secs = [s.sec(b) for b in bar_beats]
        tempo_curve = [round(s.bpm * nominal * s.meter / max(1e-6, b - a), 2) for a, b in zip(secs, secs[1:])]
    else:
        def to_nom(t):
            return t
    rows = []
    for e in ev:
        t0 = to_nom(float(e[0]))
        t1 = to_nom(float(e[0]) + float(e[4])) if e[1] == "n" else t0
        rows.append([round(t0, 4), e[1], str(e[2]), int(e[3]), round(t1 - t0, 4), round(float(e[5]), 3),
                     round(float(e[6]), 2)])
    rows.sort(key=lambda r: r[0])
    return {"name": name, "file": FILE_OF.get(name, getattr(s, "name", name)), "title": getattr(s, "title", name),
            "cls": type(s).__name__, "bpm": float(s.bpm), "meter": float(s.meter), "tonic": int(s.tonic),
            "mode": s.mode, "bed": bool(getattr(s, "bed_x", None) is not None), "tempo_curve": tempo_curve, "ev": rows}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    names = sys.argv[2:] or sorted(C.SONGS)
    for nm in names:
        d = export(nm)
        if d is None:
            print("skip", nm)
            continue
        with open(os.path.join(out, nm + ".json"), "w") as f:
            json.dump(d, f)
        print("%-18s %-34s %5d events" % (nm, d["title"][:34], len(d["ev"])))


if __name__ == "__main__":
    main()
