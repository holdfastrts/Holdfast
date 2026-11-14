"""THE MARCHING BAND's MUSIC (job band-music, docs/band_music.md): renders the six loops BandSound plays
(scripts/band_sound.gd: PARTS, PHRASE, BPM, BARS) from real instrument samples, and the owner's listening files.

The tune: SCOTLAND THE BRAVE (traditional pipe march, public domain as a melody), the pipe setting with its gracenotes
(Part 1 and Part 2, 16 bars of 4/4 = one loop). Key: G (the FreePats chanter's tonic, drones on G: every part plays in
the pipes' key). Tempo: 98 beats a minute (the owner's pipe band pieces sit at ~99). At 98 the loop is exactly
1,728,000 samples (44.1 kHz), a whole number of drone cycles, so the drones loop without a seam.

  pipes   FreePats bagpipe (Gilles Sadowski, CC0): the chanter notes retuned to just intonation over the two drones
          (G2, G3), played as one unbroken sound (a bagpipe never stops): note to note crossfades, the gracenotes of
          the pipe setting (G, D, E gracenotes, doublings, grips, taorluath-like throws); the drones under everything.
          Always-on: plain melody with single gracenotes. Solo: every gracenote, the chanter forward.
  fife    VCSL Baroque Soprano Recorder (Versilian Studios, CC0), made fife-like (brighter, breath noise, tongued):
          the melody an octave over the pipes. Always-on: plain and a little detached. Solo: cuts and rolls.
  drums   MuldjordKit (Lars Muldjord, CC BY 4.0): the snare tuned up and tightened into a marching snare (EQ, short
          envelope, wire sizzle, a small room), the kick tuned down into a parade bass drum (felt, a big room), the
          floor tom as the tenor drum, the crash as the cymbal. A pipe band snare score: flams, drags, 5- and 7-stroke
          rolls, buzz rolls; velocity layers chosen by the stroke's force, never the same hit twice in a row.

Every note and stroke is a little off the grid and a little uneven in force (seeded: the same files each run).
The loops are rendered "folded": anything that rings past the end comes back in at the start, so each file loops
seamlessly (rooms and long notes included).

Run:  python3 tools/audio/make_band_music.py            (writes assets/audio/band/*.ogg and docs/band_sound/*.mp3)
      python3 tools/audio/make_band_music.py --no-docs  (only the game's loops)
      python3 tools/audio/make_band_music.py --docs-only  (only the listening files, from the loops as they are)
Needs numpy, scipy, soundfile, soxr, ffmpeg."""
import os
import re
import subprocess
import sys

import numpy as np
import soundfile as sf
import soxr
from scipy import signal

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "art", "audio_src", "band")
OUT = os.path.join(ROOT, "assets", "audio", "band")
DOCS = os.path.join(ROOT, "docs", "band_sound")

SR = 44100
BPM = 98.0
BEAT = 60.0 / BPM
BARS = 16
L = int(round(BARS * 4 * BEAT * SR))          # 1,728,000 samples = 39.18 s
assert L == 1728000
EIGHTH = BEAT / 2

rng = np.random.default_rng(1707)


# ------------------------------------------------------------------ helpers

def load(path, sr=SR):
    x, s = sf.read(path, dtype="float64", always_2d=True)
    x = x.mean(axis=1)
    if s != sr:
        x = soxr.resample(x, s, sr, quality="HQ")
    return x


def shift(x, ratio):
    """Pitch by `ratio` (2.0 = an octave up) by resampling (the length changes the other way)."""
    if abs(ratio - 1.0) < 1e-6:
        return x.copy()
    return soxr.resample(x, SR, SR / ratio, quality="HQ")


class Loop:
    """A buffer of L samples; anything added past the end wraps to the start (and before the start to the end)."""

    def __init__(self):
        self.y = np.zeros(L)

    def add(self, sig, t):
        i = int(round(t * SR)) % L
        n = len(sig)
        pos = 0
        while pos < n:
            k = min(n - pos, L - i)
            self.y[i:i + k] += sig[pos:pos + k]
            pos += k
            i = 0


def circ_conv(x, ir):
    """Circular convolution (a room on a loop: the tail of the last bar rings into the first)."""
    n = len(x)
    h = np.zeros(n)
    h[:len(ir)] = ir[:n]
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(h), n)


def room(seconds, tau, bright=6000.0, seed=0):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = r.standard_normal(n) * np.exp(-t / tau)
    b, a = signal.butter(2, bright / (SR / 2), "low")
    ir = signal.lfilter(b, a, ir)
    ir[:int(0.006 * SR)] *= np.linspace(0, 1, int(0.006 * SR))    # early reflections start after the direct sound
    return ir / np.sqrt(np.sum(ir ** 2))


def peq(x, f0, gain_db, q=1.0):
    """A peaking EQ (RBJ cookbook)."""
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * f0 / SR
    al = np.sin(w0) / (2 * q)
    b = [1 + al * A, -2 * np.cos(w0), 1 - al * A]
    a = [1 + al / A, -2 * np.cos(w0), 1 - al / A]
    return signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], x)


def hp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def lp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def fades(n, fin, fout):
    """Equal-power fade in over fin samples and out over fout samples (sin/cos)."""
    e = np.ones(n)
    if fin > 0:
        e[:fin] = np.sin(np.linspace(0, np.pi / 2, fin))
    if fout > 0:
        e[n - fout:] *= np.cos(np.linspace(0, np.pi / 2, fout))
    return e


def loud(x, win=0.3):
    """The loudest `win` seconds (RMS, dB): the same measure tools/audio/make_mix.py levels game sounds with."""
    w = int(SR * win)
    e = [np.sqrt(np.mean(x[i:i + w] ** 2)) for i in range(0, len(x) - w, w // 3)]
    return 20 * np.log10(max(e) + 1e-9)


def jit(ms):
    return rng.normal(0.0, ms / 1000.0)


# ------------------------------------------------------------------ the tune
# Scotland the Brave, the Highland pipe setting (traditional; K:HP, L:1/8). Gracenotes in {}. Part 1 then Part 2.
# Pipe note names: G low G, A low A, B, c (C sharp on Highland pipes), d, e, f (F sharp), g (high G), a (high A).
TUNE = """
e|{g}A2 {GdGe}A3/2B/2 {gcd}c{e}A {gcd}ce|{ag}a2 {g}a2 {GdG}ae {gcd}c{e}A|{GdGc}d2 {g}f3/2d/2 {gcd}ce {gcd}c{e}A|{GdG}B2 {gef}e2 {A}e3/2f/2 {gef}e3/4d/4c3/4B/4|
{g}A2 {GdGe}A3/2B/2 {gcd}c{e}A {gcd}ce|{ag}a2 {g}a2 {GdG}ae {gcd}c{e}A|{GdGc}d2 {g}f3/2d/2 {gcd}ce {gcd}c{e}A|{GdG}B2 {g}A3/2B/2 {G}A2 {gcd}ce|
{ag}a2 {g}a2 {GdG}ae {gcd}c{e}A|{ag}a2 {g}a2 {GdG}ae {gcd}ce|{ag}a2 {g}a3/2g/2 {a}f2 {ag}a3/2g/2|{a}fa {f}gf {g}ed {g}e3/4d/4c3/4B/4|
{g}A2 {GdGe}A3/2B/2 {gcd}c{e}A {gcd}ce|{ag}a2 {g}a2 {GdG}ae {gcd}c{e}A|{GdGc}d2 {g}f3/2d/2 {gcd}ce {gcd}c{e}A|{GdG}B2 {g}A3/2B/2 {G}A3|
"""
# In G (the FreePats chanter): the pipe "A" (the tonic) is our G4. Ratios over the tonic (just intonation, as pipes
# are tuned to their drones); the pipe's high G is a flat seventh (16/9).
PIPE_RATIO = {"G": 8 / 9, "A": 1.0, "B": 9 / 8, "c": 5 / 4, "d": 4 / 3, "e": 3 / 2, "f": 5 / 3, "g": 16 / 9, "a": 2.0}
SCALE = "GABcdefga"
TONIC = 392.0                      # G4, exactly two octaves over the bass drone (98 Hz)


def parse_tune():
    """[(start s, length s, note, [graces])], the pickup at -1 eighth (it lands at the end of the loop)."""
    out = []
    t = -1.0
    bars = [b for b in re.split(r"\|", TUNE.replace("\n", "")) if b.strip()]
    for bi, bar in enumerate(bars):
        tot = 0.0
        for m in re.finditer(r"(\{[^}]*\})?([A-Ga-g])(\d*)(/?)(\d*)", bar):
            g, n, num, sl, den = m.groups()
            d = float(num) if num else 1.0
            if sl:
                d /= float(den) if den else 2.0
            out.append((t * EIGHTH, d * EIGHTH, n, list(g[1:-1]) if g else []))
            t += d
            tot += d
        assert bi == 0 and abs(tot - 1) < 1e-6 or abs(tot - 8) < 1e-6 or bi == len(bars) - 1, (bi, bar, tot)
    assert abs(t - (BARS * 8 - 1)) < 1e-6, t   # (the pickup at -1 closes the loop)
    return out


TUNE_EV = parse_tune()


def plain_graces(gr):
    """The always-on pipes: a single gracenote (the first G or A gracenote of an embellishment), no grips/doublings."""
    if not gr:
        return []
    for c in gr:
        if c in "ga":
            return [c]
    return []


# ------------------------------------------------------------------ pipes

def pitch_of(x, lo=80, hi=1000):
    """The pitch of a steady tone (autocorrelation over the middle second, refined parabolically)."""
    mid = len(x) // 2
    s = x[mid - SR // 2: mid + SR // 2]
    s = s - s.mean()
    c = np.fft.irfft(np.abs(np.fft.rfft(s, 2 * len(s))) ** 2)[:len(s)]
    a, b = int(SR / hi), int(SR / lo)
    k = a + int(np.argmax(c[a:b]))
    # the first peak near the strongest one that is nearly as strong (not an octave too low)
    for div in (4, 3, 2):
        kk = int(round(k / div))
        if kk > a:
            j = kk - 3 + int(np.argmax(c[kk - 3:kk + 4]))
            if c[j] > 0.9 * c[k]:
                k = j
                break
    y0, y1, y2 = c[k - 1], c[k], c[k + 1]
    p = 0.5 * (y0 - y2) / (y0 - 2 * y1 + y2)
    return SR / (k + p)


PIPE_FILES = {"G": ["F4_31.wav"], "A": ["G4_31.wav", "G4_32.wav"], "B": ["A4_31.wav", "A4_32.wav"],
              "c": ["B4_31.wav", "B4_32.wav"], "d": ["C5_31.wav", "C5_32_411c3f40.wav"],
              "e": ["D5_31.wav", "D5_32.wav"], "f": ["E5_31.wav", "E5_32.wav"],
              "g": ["F5_31_1d9ccd36.wav", "F5_32_b1f9371c.wav"], "a": ["G5_31.wav"]}
_chanter = {}


def chanter(n):
    """The takes of chanter note n, each retuned to its just pitch over the drones (steady part only)."""
    if n not in _chanter:
        takes = []
        for f in PIPE_FILES[n]:
            x = load(os.path.join(SRC, "freepats_bagpipe", f))
            f0 = pitch_of(x, 250, 900)
            want = TONIC * PIPE_RATIO[n]
            y = shift(x, want / f0)
            takes.append(y[int(0.3 * SR):len(y) - int(0.25 * SR)])
            print("  chanter %s %-22s %.1f Hz -> %.1f Hz (%+.0f cents)" % (n, f, f0, want, 1200 * np.log2(want / f0)))
        _chanter[n] = takes
    return _chanter[n]


def drone_loop(fname, period, n_loop):
    """A seamless loop of n_loop samples (a whole number of cycles of `period` samples) from a drone recording."""
    x = load(os.path.join(SRC, "freepats_bagpipe", fname))
    f0 = pitch_of(x, 60, 300)
    want = SR / period
    expect = int(round(n_loop * want / f0))       # the loop's length before retuning
    a = int(0.25 * SR)
    xf = int(0.08 * SR)
    ref = x[a:a + xf]
    best, bk = -1e9, expect
    for k in range(expect - 300, expect + 301):
        if a + k + xf >= len(x):
            break
        c = np.dot(ref, x[a + k:a + k + xf]) / (np.linalg.norm(x[a + k:a + k + xf]) + 1e-9)
        if c > best:
            best, bk = c, k
    seg = x[a:a + bk + xf].copy()
    lo = seg[:bk].copy()
    w = np.linspace(0, 1, xf)
    lo[:xf] = seg[bk:bk + xf] * np.cos(w * np.pi / 2) + seg[:xf] * np.sin(w * np.pi / 2)
    out = soxr.resample(lo, SR, SR * n_loop / bk, quality="VHQ")[:n_loop]
    if len(out) < n_loop:
        out = np.pad(out, (0, n_loop - len(out)), mode="edge")
    print("  drone %s %.2f Hz -> %.2f Hz, loop %d samples (%d cycles)" % (fname, f0, want, n_loop, n_loop // period))
    return out


def render_pipes(solo):
    tr = Loop()
    xf = int(0.006 * SR)                 # note-to-note crossfade (a finger change)
    gl = 0.028 if solo else 0.032        # a gracenote's length (s)
    take_i = {n: 0 for n in SCALE}
    segs = []                            # (start, length, note)
    for (t, d, n, gr) in TUNE_EV:
        t += jit(4)
        g = gr if solo else plain_graces(gr)
        # the gracenotes come just before the beat, taking their time from the note before
        gt = t - gl * len(g)
        for c in g:
            segs.append((gt, gl * (0.85 + 0.3 * rng.random()), c))
            gt += gl
        segs.append((t, d, n))
    # every segment runs until the next one starts: the sound never breaks
    segs.sort(key=lambda s: s[0])
    for i, (t, d, n) in enumerate(segs):
        nxt = segs[(i + 1) % len(segs)][0] + (BARS * 4 * BEAT if i + 1 == len(segs) else 0)
        d = nxt - t
        takes = chanter(n)
        take = takes[take_i[n] % len(takes)]
        take_i[n] += 1
        n_s = int(round(d * SR)) + xf
        off = int(rng.uniform(0, max(1, len(take) - n_s - 1)))
        s = take[off:off + n_s]
        if len(s) < n_s:
            s = np.pad(s, (0, n_s - len(s)))
        tr.add(s * fades(n_s, xf, xf), t - xf / 2 / SR)
    chan = tr.y
    t3 = np.tile(drone_loop("drone_G3_3.wav", 225, L // 8), 8)
    t2 = np.tile(drone_loop("drone_G2_1.wav", 450, L // 20), 20)
    drones = 0.55 * t3 / np.sqrt(np.mean(t3 ** 2)) + 0.5 * t2 / np.sqrt(np.mean(t2 ** 2))
    chan = chan / np.sqrt(np.mean(chan ** 2))
    mix = (1.0 if solo else 0.75) * chan + (0.42 if solo else 0.5) * drones
    mix = peq(mix, 2800, 1.5 if solo else -1.5, 0.8)
    return circ_conv(mix, room(1.2, 0.18, 7000, 3)) * 0.22 + mix


# ------------------------------------------------------------------ fife

REC_DIR = os.path.join(SRC, "vcsl", "Aerophones", "Edge-blown Aerophones", "Baroque Soprano Recorder", "Sustain")
_rec = {}


def recorder():
    """{midi: steady recorder note} (the VCSL soprano recorder sounds an octave over its file names)."""
    if not _rec:
        names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
        for f in os.listdir(REC_DIR):
            m = re.search(r"Sus_([A-G]#?)(\d)_", f)
            if not m:
                continue
            midi = 12 * (int(m.group(2)) + 1) + names[m.group(1)] + 12
            x = load(os.path.join(REC_DIR, f))
            on = int(np.argmax(np.abs(x) > 0.05 * np.abs(x).max()))
            _rec[midi] = (x[max(0, on - int(0.004 * SR)):], pitch_of(x, 400, 2500))
    return _rec


def fife_note(freq):
    """(onset part, steady part) of the nearest recorder note retuned to freq, made fife-like."""
    rec = recorder()
    midi = 69 + 12 * np.log2(freq / 440.0)
    k = min(rec, key=lambda m: abs(m - midi))
    x, f0 = rec[k]
    y = shift(x[:int(4.0 * SR)], freq / f0)
    return y


_fife_cache = {}


def fife_tone(freq):
    key = round(freq, 2)
    if key not in _fife_cache:
        y = fife_note(freq)
        # the fife's edge: a touch of saturation (upper harmonics) and a brighter top
        y = y / (np.abs(y).max() + 1e-9)
        y = np.tanh(2.2 * y) / np.tanh(2.2) * 0.7 + y * 0.3
        y = peq(y, 3500, 4.0, 0.9)
        _fife_cache[key] = y
    return _fife_cache[key]


def breath(n, level):
    b = rng.standard_normal(n)
    b = lp(hp(b, 2500), 7500)
    return b * level


def render_fife(solo):
    tr = Loop()
    ev = TUNE_EV
    for i, (t, d, n, gr) in enumerate(ev):
        t += jit(5)
        f = 2 * TONIC * PIPE_RATIO[n]
        tone = fife_tone(f)
        vel = (0.92 + 0.12 * rng.random()) * (1.0 if solo else 0.85)
        dur = d * (0.93 if solo else 0.82)          # tongued: a little gap between notes (more when plain)
        # ornaments (solo): a cut (the note above, very short) where the pipes have gracenotes; a roll on long notes
        orn = []
        if solo and gr:
            up = SCALE[min(SCALE.index(n) + 1, len(SCALE) - 1)]
            if d >= 3 * EIGHTH - 1e-6 or (i % 7 == 3 and d >= 2 * EIGHTH - 1e-6):
                lo = SCALE[max(SCALE.index(n) - 1, 0)]
                orn = [(up, 0.035), (n, 0.04), (lo, 0.035)]     # a roll (turn) into the long note
            else:
                orn = [(up, 0.032)]                              # a cut
        ot = t - sum(o[1] for o in orn)
        for (on, od) in orn:
            ft = fife_tone(2 * TONIC * PIPE_RATIO[on])
            ns = int(od * SR) + int(0.004 * SR)
            seg = ft[int(0.15 * SR):int(0.15 * SR) + ns] * fades(ns, int(0.003 * SR), int(0.004 * SR))
            tr.add(seg * vel * 0.8, ot)
            ot += od
        ns = int(dur * SR)
        start = int(0.12 * SR) if orn else 0          # after an ornament the note is slurred, not tongued again
        seg = tone[start:start + ns].copy()
        if len(seg) < ns:
            seg = np.pad(seg, (0, ns - len(seg)))
        env = fades(ns, int(0.004 * SR) if orn else 0, int(0.025 * SR))
        # tongued attack: a little accent and a puff of air
        a = int(0.05 * SR)
        if not orn:
            env[:a] *= 1.0 + 0.35 * np.linspace(1, 0, a)
        b = breath(ns, 0.035) * np.exp(-np.arange(ns) / (0.06 * SR))
        tr.add((seg * env + b) * vel, t)
    y = tr.y + breath(L, 0.006)                        # the player's breath under it all
    y = hp(y, 300)
    return y + circ_conv(y, room(1.0, 0.15, 9000, 5)) * 0.25


# ------------------------------------------------------------------ drums

DR = os.path.join(SRC, "muldjord_drums")


def layers(folder):
    fs = sorted(os.listdir(os.path.join(DR, folder)), key=lambda f: int(f.split("-")[0]))
    return [load(os.path.join(DR, folder, f)) for f in fs]


class Kit:
    def __init__(self):
        sn = layers("Snare1")
        # the marching snare: tuned up (tighter head), the boom cut, the crack and wires brought up, a short decay
        self.snare = []
        for x in sn:
            y = shift(x, 2 ** (2.5 / 12))
            y = hp(y, 170, 2)
            y = peq(y, 320, -5.0, 1.0)
            y = peq(y, 4800, 4.0, 0.9)
            y = peq(y, 9500, 2.5, 0.8)
            t = np.arange(len(y)) / SR
            y *= np.where(t < 0.03, 1.0, np.exp(-(t - 0.03) / 0.10))
            self.snare.append(y[:int(0.7 * SR)])
        self.rim = [shift(x, 2 ** (2 / 12))[:int(0.5 * SR)] for x in layers("SnareRest1")]
        # the parade bass drum: the kick tuned down five semitones (a bigger shell), the beater softened (felt)
        self.bass = []
        for x in layers("KdrumL"):
            y = shift(x, 2 ** (-5 / 12))
            y = lp(y, 1400, 2)
            y = peq(y, 70, 3.0, 0.9)
            self.bass.append(y[:int(1.6 * SR)])
        self.tenor = [peq(lp(shift(x, 2 ** (3 / 12)), 5000), 180, 3.0)[:int(1.4 * SR)] for x in layers("Tom4")]
        self.crash = [hp(x, 400)[:int(5 * SR)] for x in layers("CrashL")]
        self.last = {}

    def hit(self, kind, vel):
        """The layer for this force (never the same file twice in a row), scaled a little by the force."""
        ls = getattr(self, kind)
        n = len(ls)
        v = float(np.clip(vel, 0.02, 1.0))
        c = int(round(v * (n - 1)))
        spread = max(1, n // 14)
        for _ in range(8):
            i = int(np.clip(c + rng.integers(-spread, spread + 1), 0, n - 1))
            if i != self.last.get(kind):
                break
        self.last[kind] = i
        layer_v = i / max(1, n - 1)
        g = (0.55 + 0.45 * v) * (1.0 + 0.25 * (v - layer_v))
        return ls[i] * g


def wire(vel):
    """Snare wire sizzle: a short band of noise (a marching snare's bright snap)."""
    n = int(0.12 * SR)
    b = rng.standard_normal(n)
    b = lp(hp(b, 3000), 11000)
    return b * np.exp(-np.arange(n) / (0.035 * SR)) * 0.09 * vel


# The snare score. One character a sixteenth (16 a bar):
#   F flam accent   A accent   t tap   g ghost   r rim click   D drag (a ruff) accent
#   R a 5-stroke roll ending here   S a 7-stroke roll ending here   z a buzz roll from here, - it goes on   . rest
SNARE_ON = ["F..tt.t.A..tt.t.", "F..tt.t.A..tR..t", "F..tt.t.A..tt.t.", "F..tt.t.z---A..g",
            "F..tt.t.A..tt.t.", "F..tt.t.A..tR..t", "F..tt.t.A..tt.t.", "F..tt.t.A...S.gt",
            "F..tt.t.A..tt.t.", "F..tt.t.A..tR..t", "F..tr.t.A..tr.t.", "F..tt.t.z---A..g",
            "F..tt.t.A..tt.t.", "F..tt.t.A..tR..t", "F..tt.t.A..tt.t.", "F..tt.t.z-----gt"]
SNARE_SOLO = ["F.tgt.ttA.tgR.tt", "F.ttz---A.ttS..t", "F.tgt.ttD.ttR.tt", "F.ttz-------A..g",
              "F.tgt.ttA.tgR.tt", "F.ttz---A.ttS..t", "F.tgt.ttD.ttR.tt", "S.ttA.ttz-----tt",
              "F.ttR.ttF.ttR.tt", "F.ttz---F.ttS.tt", "F.tgt.ttD.ttR.tt", "F.ttz-------A..g",
              "F.tgt.ttA.tgR.tt", "F.ttz---A.ttS..t", "D.tgt.ttD.ttR.tt", "F.ttz---A.ttz-tt"]
# Bass and tenor: per bar, sixteenth -> force
BASS_ON = {0: 0.8, 4: 0.42, 8: 0.66, 12: 0.42}
BASS_SOLO_EXTRA = [{}, {14: 0.4}, {}, {6: 0.45}, {}, {14: 0.4}, {3: 0.35}, {10: 0.5, 14: 0.55},
                   {}, {14: 0.4}, {}, {6: 0.45}, {}, {14: 0.4}, {3: 0.35}, {10: 0.5, 14: 0.55}]
TENOR_SOLO = [{0: .7, 8: .55}, {0: .6, 6: .5, 8: .6}, {0: .7, 8: .55}, {0: .7, 4: .5, 8: .6, 12: .5},
              {0: .7, 8: .55}, {0: .6, 6: .5, 8: .6}, {0: .7, 8: .55}, {0: .7, 10: .55, 14: .6},
              {0: .8, 4: .5, 8: .7, 12: .5}, {0: .7, 6: .5, 8: .6}, {0: .7, 8: .55}, {0: .7, 4: .5, 8: .6, 12: .5},
              {0: .7, 8: .55}, {0: .6, 6: .5, 8: .6}, {0: .7, 8: .55}, {0: .7, 10: .55, 14: .6}]


def render_drums(solo):
    kit = Kit()
    sn, bd, tn, cy = Loop(), Loop(), Loop(), Loop()
    six = BEAT / 4
    score = SNARE_SOLO if solo else SNARE_ON
    lvl = 1.0 if solo else 0.8
    hand = [0]

    def stroke(t, v, kind="snare"):
        v = float(np.clip(v * (1 + rng.normal(0, 0.05)), 0.03, 1.0))
        t += jit(3)
        s = kit.hit(kind, v)
        sn.add(s, t)
        if kind == "snare":
            sn.add(wire(v), t)
        hand[0] ^= 1

    for b, bar in enumerate(score):
        t0 = b * 4 * BEAT
        i = 0
        while i < 16:
            c = bar[i]
            t = t0 + i * six
            if c in "FADtgr":
                v = {"F": 0.88, "A": 0.82, "D": 0.86, "t": 0.46, "g": 0.24, "r": 0.5}[c] * lvl
                # the lead hand is a touch stronger (a real player's two hands)
                v *= 1.0 if hand[0] == 0 else 0.93
                if c == "F":
                    stroke(t - 0.026, 0.22 * lvl)
                if c == "D":
                    stroke(t - 0.062, 0.26 * lvl)
                    stroke(t - 0.040, 0.24 * lvl)
                stroke(t, v, "rim" if c == "r" else "snare")
            elif c in "RS":
                strokes = 4 if c == "R" else 6
                span = six if c == "R" else 2 * six
                for k in range(strokes):
                    vv = (0.30 + 0.22 * k / strokes) * lvl * (1.0 if k % 2 == 0 else 0.86)
                    stroke(t - span + k * span / strokes, vv)
                stroke(t, 0.84 * lvl)
            elif c == "z":
                j = i + 1
                while j < 16 and bar[j] == "-":
                    j += 1
                end = t0 + j * six
                n = int((end - t) / (BEAT / 12))
                for k in range(n):
                    tk = t + k * BEAT / 12
                    vv = (0.30 + 0.28 * k / max(1, n)) * lvl * (1.0 if k % 2 == 0 else 0.88)
                    stroke(tk, vv)
                    stroke(tk + 0.012, vv * 0.38)           # the press: the stick buzzes on the head
                    stroke(tk + 0.024, vv * 0.16)
                i = j
                continue
            i += 1
        for k, v in BASS_ON.items():
            bd.add(kit.hit("bass", v * lvl * (1 + rng.normal(0, 0.04))), t0 + k * six + jit(3))
        if solo:
            for k, v in BASS_SOLO_EXTRA[b].items():
                bd.add(kit.hit("bass", v * (1 + rng.normal(0, 0.04))), t0 + k * six + jit(3))
            for k, v in TENOR_SOLO[b].items():
                tn.add(kit.hit("tenor", v * (1 + rng.normal(0, 0.05))), t0 + k * six + jit(4))
    if solo:
        cy.add(kit.hit("crash", 0.45) * 0.5, 0.0 + jit(2))
        cy.add(kit.hit("crash", 0.7) * 0.6, 8 * 4 * BEAT + jit(2))
    s = sn.y
    s = s + circ_conv(s, room(0.6, 0.07, 9000, 11)) * 0.22     # a small room: crisp, close
    bdy = bd.y + circ_conv(bd.y, room(2.0, 0.28, 2500, 12)) * 0.35   # the bass drum in a big space
    tny = tn.y + circ_conv(tn.y, room(1.5, 0.2, 4000, 13)) * 0.3
    return s * 1.0 + bdy * (0.9 if solo else 1.0) + tny * 0.55 + cy.y * 0.35


# ------------------------------------------------------------------ levels and files

def music_target():
    """The game sounds' loudness (make_mix.py: the music's median loudness + music.gd VOL)."""
    vals = []
    for f in sorted(os.listdir(os.path.join(ROOT, "assets", "music"))):
        if f.endswith(".ogg"):
            vals.append(loud(decode(os.path.join(ROOT, "assets", "music", f)), 3.0))
    return float(np.median(vals)) - 8.0


def decode(path, sr=SR):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(sr), "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(float)


def level(y, target):
    y = y * 10 ** ((target - loud(y)) / 20)
    pk = np.abs(y).max()
    if pk > 0.97:                       # a soft limiter on the loudest peaks (drum hits)
        y = np.tanh(y / 0.97 * 1.2) / np.tanh(1.2) * 0.97
    return y


def write_ogg(path, y, q=4):
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), path], input=y.astype(np.float32).tobytes(), check=True)


def write_mp3(path, y, stereo=False):
    ch = 2 if stereo else 1
    pk = np.abs(y).max()
    if pk > 0.98:
        y = y * 0.98 / pk
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", str(ch), "-i", "-",
                    "-c:a", "libmp3lame", "-b:a", "128k", path], input=y.astype(np.float32).tobytes(), check=True)


def db(x):
    return 10 ** (x / 20)


def main():
    docs = "--no-docs" not in sys.argv
    os.makedirs(OUT, exist_ok=True)
    if "--docs-only" in sys.argv:              # the listening files from the loops already in assets/audio/band/
        parts = {k: decode(os.path.join(OUT, k + ".ogg"))[:L] for k in
                 ("pipes", "pipes_lead", "fife", "fife_lead", "drums", "drums_lead")}
        listening(parts, None)
        return
    target = music_target()
    print("the game sounds' loudness: %.1f dB" % target)
    parts = {}
    for name, fn in [("pipes", render_pipes), ("fife", render_fife), ("drums", render_drums)]:
        for solo in (False, True):
            print("rendering %s %s" % (name, "solo" if solo else "always-on"))
            y = fn(solo)
            # the always-on loop is the quieter, plainer one; the solo loop sits at the game sounds' loudness
            y = level(y, target - (3.0 if not solo else 0.0))
            key = name + ("_lead" if solo else "")
            parts[key] = y
            write_ogg(os.path.join(OUT, key + ".ogg"), y)
            print("  %s.ogg: %.2f s, loudest %.1f dB, peak %.2f" % (key, len(y) / SR, loud(y), np.abs(y).max()))
    if docs:
        listening(parts, target)


# ------------------------------------------------------------------ the owner's listening files

QUIET, LEAD, UNDER = -15.0, -1.0, -19.0          # BandSound.QUIET_DB / LEAD_DB / UNDER_DB
MUSIC_VOL, DUCK, DUCK_SOLO = -8.0, -2.5, -6.0     # music.gd VOL, BandSound.DUCK_DB / DUCK_SOLO_DB


def band(parts, lead="", have=("drums", "fife", "pipes"), base=0.0):
    """One band as BandSound plays it: the lead's solo loop at LEAD_DB, the others' always-on loops under it."""
    y = np.zeros(L)
    for ins in have:
        if ins == lead:
            y += parts[ins + "_lead"] * db(LEAD + base)
        else:
            y += parts[ins] * db((UNDER if lead else QUIET) + base)
    return y


def seconds(y, s, start=0.0):
    """s seconds of a loop from `start` (wrapping)."""
    i = int(start * SR) % L
    n = int(s * SR)
    return np.take(y, np.arange(i, i + n) % L)


def fade_out(y, s=2.0):
    n = int(s * SR)
    y = y.copy()
    y[-n:] *= np.linspace(1, 0, n)
    return y


def norm(y, peak=0.9):
    return y * peak / (np.abs(y).max() + 1e-9)


def listening(parts, target):
    os.makedirs(DOCS, exist_ok=True)
    for f in os.listdir(DOCS):
        if f.endswith(".mp3"):
            os.remove(os.path.join(DOCS, f))
    out = []

    def put(name, y, stereo=False, what=""):
        write_mp3(os.path.join(DOCS, name + ".mp3"), y, stereo)
        out.append((name, what))
        print("  docs/band_sound/%s.mp3" % name)

    S = 45.0
    # 1. each solo loop alone (the instrument by itself, at its solo level)
    POSS = {"pipes": "the pipes'", "fife": "the fife's", "drums": "the drums'"}
    for ins in ("pipes", "fife", "drums"):
        put("01_%s_solo_alone" % ins, norm(fade_out(seconds(parts[ins + "_lead"], S))),
            what="%s solo loop alone" % POSS[ins])
    # 2. each always-on loop alone
    for ins in ("pipes", "fife", "drums"):
        put("02_%s_always_on_alone" % ins, norm(fade_out(seconds(parts[ins], S)), 0.6),
            what="%s always-on loop alone (quieter and plainer)" % POSS[ins])
    # 3. the full band, always-on (as heard in a match: all three at QUIET_DB)
    put("03_full_band_always_on", norm(fade_out(seconds(band(parts), S)), 0.6),
        what="all three playing along (the always-on loops together)")
    # 4. the full band with each solo
    for ins in ("pipes", "fife", "drums"):
        put("04_full_band_%s_solo" % ins, norm(fade_out(seconds(band(parts, ins), S))),
            what="all three, the %s soloing over the others" % ins)
    # 5. smaller bands
    put("05_drummer_and_piper", norm(fade_out(seconds(band(parts, have=("drums", "pipes")), S)), 0.6),
        what="a band of Drummer + Piper, always-on")
    put("05_drummer_and_fifer", norm(fade_out(seconds(band(parts, have=("drums", "fife")), S)), 0.6),
        what="a band of Drummer + Fifer, always-on")
    # 6. two bands at once on the one clock (left: a full band with the pipes soloing; right: a full band playing along)
    a = band(parts, "pipes")
    b = band(parts)
    st = np.zeros((int(S * SR), 2))
    st[:, 0] = seconds(a, S) * 0.85 + seconds(b, S) * 0.25
    st[:, 1] = seconds(b, S) * 0.85 + seconds(a, S) * 0.25
    st = norm(st)
    n = int(2 * SR)
    st[-n:] *= np.linspace(1, 0, n)[:, None]
    put("06_two_bands_one_clock", st.reshape(-1), stereo=True,
        what="two bands at once on the one clock (left a pipe solo, right playing along): they stay in step "
             "(in a match BandSound plays only the band nearest the middle of the screen)")
    # 7. over each faction's battle music, as the game mixes it (music at VOL, ducked; the band at its BandSound levels)
    for fac, f in [("crown", "crown_battle_7"), ("clockwork", "clock_battle_7"), ("brood", "brood_battle_7")]:
        m = decode(os.path.join(ROOT, "assets", "music", f + ".ogg"))
        start = 20.0
        mus = m[int(start * SR):int((start + S) * SR)]
        if len(mus) < int(S * SR):
            mus = np.pad(mus, (0, int(S * SR) - len(mus)))
        half = int(S * SR / 2)
        g = np.full(len(mus), db(MUSIC_VOL + DUCK))
        g[half:] = db(MUSIC_VOL + DUCK_SOLO)                     # the second half: the pipes' solo
        bnd = np.concatenate([seconds(band(parts), S / 2), seconds(band(parts, "pipes"), S / 2, S / 2)])
        y = fade_out(mus * g + bnd[:len(mus)])
        put("07_over_%s_battle_music" % fac, norm(y, 0.9 * np.abs(y).max() / max(0.9, np.abs(y).max())),
            what="the band over the %s's battle music (%s.ogg) as the game mixes it: playing along, then "
                 "the pipes' solo halfway" % (fac, f))
    # 8. the old sounds (the 4 s loops before this job), the same combinations
    old = old_parts()
    if old:
        n4 = len(old["drums"])
        reps = int(np.ceil(S * SR / n4))
        def oband(lead=""):
            y = np.zeros(n4)
            for ins in ("drums", "fife", "pipes"):
                y += old[ins + ("_lead" if ins == lead else "")] * db(LEAD if ins == lead else (UNDER if lead else QUIET))
            return np.tile(y, reps)[:int(S * SR)]
        put("08_OLD_full_band_always_on", norm(fade_out(oband()), 0.6), what="BEFORE: the old 4 s loops, all three playing along")
        put("08_OLD_full_band_pipes_solo", norm(fade_out(oband("pipes"))), what="BEFORE: the old loops, the pipes' solo")
        put("08_OLD_full_band_fife_solo", norm(fade_out(oband("fife"))), what="BEFORE: the old loops, the fife's solo")
    with open(os.path.join(DOCS, "LIST.txt"), "w") as fh:
        for name, what in out:
            fh.write("%s.mp3  %s\n" % (name, what))


def old_parts():
    """The band's loops before this job (from git: the commit before band-music changed them)."""
    out = {}
    for k in ("drums", "drums_lead", "fife", "fife_lead", "pipes", "pipes_lead"):
        r = subprocess.run(["git", "-C", ROOT, "show", "%s:assets/audio/band/%s.ogg" % (OLD_REV, k)], capture_output=True)
        if r.returncode != 0:
            return {}
        p = os.path.join("/tmp", "old_band_%s.ogg" % k)
        with open(p, "wb") as fh:
            fh.write(r.stdout)
        out[k] = decode(p)
    n = min(len(v) for v in out.values())
    return {k: v[:n] for k, v in out.items()}


OLD_REV = "2b182020"     # main before band-music

if __name__ == "__main__":
    main()
