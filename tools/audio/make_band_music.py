"""THE MARCHING BAND's MUSIC (jobs band-music and band-music-v2, docs/band_music.md): renders the six loops BandSound
plays (scripts/band_sound.gd: PARTS, PHRASE, BPM, BARS) from real instrument samples, and the owner's listening files.

The tune: SCOTLAND THE BRAVE (traditional, public domain as a melody), note for note as a reference score the owner
supplied (band-music-v2; the score itself is someone else's arrangement and is not in the repo): 16 bars of 4/4,
A (1-4) A' (5-8) B (9-12) A' (13-16), no pick-up. The score is written in D; we play it in E (every note a whole
tone up), the key where the FreePats chanter's own notes fit the tune's range (C#4..F#5 written, D#4..G#5 here) with
the smallest retuning (all chanter notes within 1.6 semitones of a recorded take; in G the top notes needed +4).
Tempo: 110 quarter notes a minute as the score has it (109.91 exactly: the loop is 1,540,800 samples = 2,880 cycles
of the low drone, so the drones run through the loop point without a seam).

  pipes   FreePats bagpipe (Gilles Sadowski, CC0): the chanter notes retuned to just intonation over the two drones
          (E2, E3: the recorded G drones moved down three semitones), played as one unbroken sound (a bagpipe never
          stops), with the pipe gracenotes (G, D and E gracenotes, doublings, grips) on the long and repeated notes.
          Always-on: the plain melody with single gracenotes. Solo: every gracenote, a second pipe in unison (resting
          in Part B, as in the score), the score's lower voice quietly under it, the chanter forward.
  fife    VCSL Baroque Soprano Recorder (Versilian Studios, CC0), made fife-like (brighter, breath noise, tongued):
          the melody an octave over the pipes. Always-on: plain and a little detached. Solo: cuts and rolls.
  drums   MuldjordKit (Lars Muldjord, CC BY 4.0): the snare tuned up and tightened into a marching snare, the kick
          tuned down into a parade bass drum, the floor tom as the tenor drum, the crash as the cymbal. The snare plays
          the score's pattern (constant eighths, flams on 1 and 3, sixteenth pairs and drags at bar ends, the
          "flam, flam, rest" cadence closing each 4-bar phrase, quarters in Part B); the bass drum on 1 and 3 (a flam
          into 1 in Part B). Velocity layers chosen by the stroke's force, never the same hit twice in a row.

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
DRONE_P = 535                                   # samples a cycle of the low drone (E2 = 82.43 Hz)
L = DRONE_P * 2880                              # 1,540,800 samples = 34.94 s: 16 bars, a whole number of drone cycles
BARS = 16
BEAT = L / SR / (BARS * 4)
BPM = 60.0 / BEAT                               # 109.91 (the score: 110)
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
# Scotland the Brave as the reference score has it, WRITTEN IN D (the score's pitches; we sound them a tone higher).
# One note: name+octave and its length in eighths (1 = eighth, 2 = quarter, 1.5 = dotted eighth, .5 = sixteenth,
# 4 = half); "'" after a note = staccato (bar 12). Bar 1 as the score plays it: D q, D e., E s, F# e, D e, F# e, A e.
BAR = {
    1: "D4 2, D4 1.5, E4 .5, F#4 1, D4 1, F#4 1, A4 1",
    2: "D5 2, D5 1.5, C#5 .5, D5 1, A4 1, F#4 2",
    3: "G4 2, B4 1.5, G4 .5, F#4 1, A4 1, F#4 1, D4 1",
    4: "E4 2, A4 1.5, B4 .5, A4 4",
    8: "E4 2, D4 1.5, C#4 .5, D4 4",
    9: "E5 2, E5 1.5, D#5 .5, E5 1, C#5 1, A4 2",
    10: "D5 2, F#5 1.5, E5 .5, D5 1, A4 1, F#4 2",
    11: "D5 2, D5 2, C#5 2, D5 1.5, C#5 .5",
    12: "B4 1, D5 1, C#5' 2, A4' 2, F#4 1, E4 1",
}
FORM = [1, 2, 3, 4, 1, 2, 3, 8, 9, 10, 11, 12, 1, 2, 3, 8]      # A A' B A'
# The score's lower voice (the second pipes' harmony line), two half notes a bar, written in D.
LOWER = {1: "D4 F#4", 2: "F#4 D4", 3: "D4 D4", 4: "C#4 E4", 8: "C#4 D4",
         9: "A4 E4", 10: "F#4 D4", 11: "F#4 A4", 12: "E4 D4"}
TRANSPOSE = 2                                   # semitones: written D -> sounding E
NAMES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi_of(name):
    m = re.match(r"([A-G]#?)(\d)", name)
    return 12 * (int(m.group(2)) + 1) + NAMES[m.group(1)]


D4 = midi_of("D4")
# Just intonation over the drones (the tonic = the drones' note), by semitones above the written tonic D4: the score's
# C#s are leading notes (15/8), its D# (bar 9) the leading note into E5.
JUST = {-1: 15 / 16, 0: 1.0, 2: 9 / 8, 4: 5 / 4, 5: 4 / 3, 7: 3 / 2, 9: 5 / 3, 11: 15 / 8, 12: 2.0, 13: 135 / 64,
        14: 9 / 4, 16: 5 / 2}
TONIC = 4 * SR / DRONE_P                         # E4 = 329.72 Hz, exactly two octaves over the low drone


def freq_of(written):
    return TONIC * JUST[written - D4]


def parse_tune():
    """[(start s, length s, written midi, staccato, bar)]: the 16 bars from bar 1's downbeat."""
    out = []
    t = 0.0
    for bi, b in enumerate(FORM):
        tot = 0.0
        for tok in BAR[b].split(","):
            n, d = tok.split()
            st = n.endswith("'")
            out.append((t * EIGHTH, float(d) * EIGHTH, midi_of(n.rstrip("'")), st, bi))
            t += float(d)
            tot += float(d)
        assert abs(tot - 8) < 1e-6, (b, tot)
    assert abs(t - BARS * 8) < 1e-6
    return out


TUNE_EV = parse_tune()


# Pipe gracenotes, by the written note (the pipe names: D4 = low A, E4 = B, F#4 = C, G4 = D, A4 = E, B4 = F,
# C#5 = high G, D5 = high A; C#4 = low G). G = the high G gracenote (written C#5), D = the D gracenote (G4), E = the
# E gracenote (A4). The tune's notes over high A (D#5, E5, F#5: the score's Part B) take the note above or a strike.
G_, D_, E_, LG = midi_of("C#5"), midi_of("G4"), midi_of("A4"), midi_of("C#4")
DOUBLING = {midi_of("D4"): [G_, midi_of("D4"), D_], midi_of("E4"): [G_, midi_of("E4"), D_],
            midi_of("F#4"): [G_, midi_of("F#4"), D_], midi_of("G4"): [G_, midi_of("G4"), E_],
            midi_of("A4"): [G_, midi_of("A4"), midi_of("B4")], midi_of("B4"): [G_, midi_of("B4"), G_],
            midi_of("C#5"): [midi_of("D5"), midi_of("C#5"), midi_of("D5")], midi_of("D5"): [G_],
            midi_of("D#5"): [], midi_of("E5"): [midi_of("F#5")], midi_of("F#5"): [midi_of("D5")]}


def single(n):
    """The one gracenote of a plain embellishment: high G on the low notes, high A on high G, the note above higher."""
    if n <= midi_of("B4"):
        return [G_]
    if n == midi_of("C#5"):
        return [midi_of("D5")]
    if n == midi_of("D5"):
        return [G_]
    if n == midi_of("E5"):
        return [midi_of("F#5")]
    if n == midi_of("F#5"):
        return [midi_of("D5")]
    return []


def graces(i, solo):
    """The gracenotes before note i (written midi), as a piper plays this tune: on the beat's long notes, repeated
    notes and the half notes; the plain (always-on) part keeps a single gracenote on the long and repeated notes."""
    t, d, n, st, _ = TUNE_EV[i]
    prev = TUNE_EV[i - 1][2]
    on_beat = abs((t / BEAT) - round(t / BEAT)) < 1e-6
    long_ = d >= 2 * EIGHTH - 1e-6
    rep = prev == n
    if not solo:
        return single(n) if (rep or (long_ and on_beat)) else []
    if rep and n <= midi_of("A4"):
        return [LG, D_, LG] if n != midi_of("G4") else [LG, E_, LG]   # a grip between repeated notes
    if rep:
        return single(n)
    if long_ and on_beat:
        return DOUBLING.get(n, single(n))
    if d >= 1.5 * EIGHTH - 1e-6:
        return single(n)
    if on_beat:
        return single(n)
    if n < prev and n <= midi_of("E4"):
        return [E_]                                   # stepping down to low A or B: the E gracenote
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


_takes = []          # [(measured midi, steady recording)] of every chanter take in the owner's set
_chanter = {}


def chanter(written):
    """The takes nearest this note's pitch (by their MEASURED pitch: the set's file names are not all right), each
    retuned to the note's just pitch over the drones (steady part only)."""
    if not _takes:
        d = os.path.join(SRC, "freepats_bagpipe")
        for f in sorted(os.listdir(d)):
            if f.endswith(".wav") and not f.startswith("drone"):
                x = load(os.path.join(d, f))
                f0 = pitch_of(x, 250, 900)
                _takes.append((69 + 12 * np.log2(f0 / 440.0), f0, x, f))
    if written not in _chanter:
        want = freq_of(written)
        wm = 69 + 12 * np.log2(want / 440.0)
        best = min(abs(t[0] - wm) for t in _takes)
        near = [t for t in _takes if abs(t[0] - wm) <= best + 0.35]
        out = []
        for (m, f0, x, f) in near:
            y = shift(x, want / f0)
            out.append(y[int(0.3 * SR):len(y) - int(0.25 * SR)])
            print("  chanter %-4s %-22s %.1f Hz -> %.1f Hz (%+.0f cents)" % (
                [k for k, v in NAMES.items() if v == (written + TRANSPOSE) % 12][0], f, f0, want, 1200 * np.log2(want / f0)))
        _chanter[written] = out
    return _chanter[written]


def drone_loop(fname, period, n_loop):
    """A seamless loop of n_loop samples (a whole number of cycles of `period` samples) from a drone recording,
    retuned to SR / period (the recorded G drones down to E)."""
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
    print("  drone %s %.2f Hz -> %.2f Hz (%.2f semitones), loop %d samples (%.0f cycles)" % (
        fname, f0, want, 12 * np.log2(want / f0), n_loop, n_loop / period))
    return out


def chanter_line(notes, gl, crossfade_ms=6, wobble=4):
    """One chanter playing `notes` [(t, written midi, [graces])] as one unbroken sound: each note runs until the
    next begins (a finger change: a short crossfade), the gracenotes just before the beat, taking their time from the
    note before."""
    tr = Loop()
    xf = int(crossfade_ms / 1000 * SR)
    take_i = {}
    segs = []
    for (t, n, g) in notes:
        t += jit(wobble)
        gt = t - gl * len(g)
        for c in g:
            segs.append((gt, c))
            gt += gl * (0.85 + 0.3 * rng.random())
        segs.append((t, n))
    segs.sort(key=lambda s: s[0])
    for i, (t, n) in enumerate(segs):
        nxt = segs[(i + 1) % len(segs)][0] + (L / SR if i + 1 == len(segs) else 0)
        d = nxt - t
        takes = chanter(n)
        take = takes[take_i.get(n, 0) % len(takes)]
        take_i[n] = take_i.get(n, 0) + 1
        n_s = int(round(d * SR)) + xf
        off = int(rng.uniform(0, max(1, len(take) - n_s - 1)))
        s = take[off:off + n_s]
        if len(s) < n_s:                                 # (a note longer than the take: loop its steady part)
            s = np.resize(take[len(take) // 4:], n_s)
        tr.add(s * fades(n_s, xf, xf), t - xf / 2 / SR)
    return tr.y


def render_pipes(solo):
    gl = 0.028 if solo else 0.032        # a gracenote's length (s)
    lead = [(t, n, graces(i, solo)) for i, (t, d, n, st, b) in enumerate(TUNE_EV)]
    chan = chanter_line(lead, gl)
    chan = chan / np.sqrt(np.mean(chan ** 2))
    mix = (1.0 if solo else 0.75) * chan
    if solo:
        # the second pipes in unison (another take, a few ms behind, plainer), resting in Part B as the score has it
        sec = [(t + 0.008, n, graces(i, False)) for i, (t, d, n, st, b) in enumerate(TUNE_EV)]
        s2 = chanter_line(sec, 0.032, wobble=6)
        b0, b1 = 8 * 4 * BEAT, 12 * 4 * BEAT
        tt = np.arange(L) / SR
        gate = np.where((tt >= b0) & (tt < b1), 0.0, 1.0)
        gate = np.convolve(gate, np.ones(int(0.04 * SR)) / int(0.04 * SR), mode="same")
        mix += 0.42 * s2 / np.sqrt(np.mean(s2 ** 2)) * gate
        # the score's lower voice, quietly: half notes
        low = []
        for bi, b in enumerate(FORM):
            for k, nm in enumerate(LOWER[b].split()):
                low.append((bi * 4 * BEAT + k * 2 * BEAT, midi_of(nm), [G_] if k == 0 else []))
        s3 = chanter_line(low, 0.03, wobble=5)
        mix += 0.3 * s3 / np.sqrt(np.mean(s3 ** 2))
    # the drones: the recorded G drones moved down three semitones to E (E3 and E2), whole cycles in the loop
    t3 = np.tile(drone_loop("drone_G3_3.wav", DRONE_P / 2, L // 10), 10)
    t2 = np.tile(drone_loop("drone_G2_1.wav", DRONE_P, L // 20), 20)
    drones = 0.55 * t3 / np.sqrt(np.mean(t3 ** 2)) + 0.5 * t2 / np.sqrt(np.mean(t2 ** 2))
    mix = mix + (0.42 if solo else 0.5) * drones
    mix = peq(mix, 2800, 1.5 if solo else -1.5, 0.8)
    return circ_conv(mix, room(1.2, 0.18, 7000, 3)) * 0.22 + mix


# ------------------------------------------------------------------ fife

REC_DIR = os.path.join(SRC, "vcsl", "Aerophones", "Edge-blown Aerophones", "Baroque Soprano Recorder", "Sustain")
_rec = {}


def recorder():
    """{midi: steady recorder note} (the VCSL soprano recorder sounds an octave over its file names)."""
    if not _rec:
        for f in os.listdir(REC_DIR):
            m = re.search(r"Sus_([A-G]#?)(\d)_", f)
            if not m:
                continue
            midi = 12 * (int(m.group(2)) + 1) + NAMES[m.group(1)] + 12
            x = load(os.path.join(REC_DIR, f))
            on = int(np.argmax(np.abs(x) > 0.05 * np.abs(x).max()))
            _rec[midi] = (x[max(0, on - int(0.004 * SR)):], pitch_of(x, 400, 2500))
    return _rec


def fife_note(freq):
    """The nearest recorder note retuned to freq."""
    rec = recorder()
    midi = 69 + 12 * np.log2(freq / 440.0)
    k = min(rec, key=lambda m: abs(m - midi))
    x, f0 = rec[k]
    return shift(x[:int(4.0 * SR)], freq / f0)


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


ORDER = sorted(set(midi_of(n) for n in ["C#4", "D4", "E4", "F#4", "G4", "A4", "B4", "C#5", "D5", "D#5", "E5", "F#5"]))


def render_fife(solo):
    tr = Loop()
    for i, (t, d, n, st, b) in enumerate(TUNE_EV):
        t += jit(5)
        f = 2 * freq_of(n)
        tone = fife_tone(f)
        vel = (0.92 + 0.12 * rng.random()) * (1.0 if solo else 0.85)
        dur = d * (0.93 if solo else 0.82)          # tongued: a little gap between notes (more when plain)
        if st:
            dur = d * 0.5                           # the score's staccato quarters (bar 12)
        # ornaments (solo): a cut (the note above, very short) where the pipes have gracenotes; a roll on long notes
        orn = []
        gr = graces(i, True)
        k = ORDER.index(n)
        if solo and gr and n != TUNE_EV[i - 1][2] or (solo and d >= 4 * EIGHTH - 1e-6):
            up = ORDER[min(k + 1, len(ORDER) - 1)]
            if d >= 2 * EIGHTH - 1e-6 and not st:
                lo = ORDER[max(k - 1, 0)]
                orn = [(up, 0.035), (n, 0.04), (lo, 0.035)]     # a roll (turn) into the long note
            else:
                orn = [(up, 0.032)]                              # a cut
        elif solo and gr:
            orn = [(ORDER[min(k + 1, len(ORDER) - 1)], 0.03)]    # a cut between repeated notes
        ot = t - sum(o[1] for o in orn)
        for (on, od) in orn:
            ft = fife_tone(2 * freq_of(on))
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
        a = int(0.05 * SR)
        if not orn:
            env[:a] *= 1.0 + 0.35 * np.linspace(1, 0, a)    # tongued attack: a little accent and a puff of air
        bb = breath(ns, 0.035) * np.exp(-np.arange(ns) / (0.06 * SR))
        tr.add((seg * env + bb) * vel, t)
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


# The snare score, after the reference score's pattern. One character a sixteenth (16 a bar):
#   F flam accent   A accent   t tap (an eighth or a sixteenth)   g ghost   r rim click   D drag (a ruff) accent
#   R a 5-stroke roll ending here   S a 7-stroke roll ending here   z a buzz roll from here, - it goes on   . rest
# Part A bars: constant eighths, a flam on 1 and 3, a sixteenth pair or a drag at the bar's end; the last bar of each
# 4-bar phrase: "flam eighth, flam eighth, rest". Part B (bars 9-10): quarter, quarter, eighth eighth, rest, flams on
# 1 and on the first eighth of beat 3; bars 11-12: straight eighths.
A1 = "F.t.t.t.F.t.t.tt"          # 8th 8th 8th 8th | flam 8th 8th 16 16
A2 = "F.t.t.t.F.t.t.D."          # ... a drag into the next bar
CAD = "F.t.F.t........."         # flam 8th, flam 8th, rest (the phrase's last bar)
B1 = "F...t...F.t....."          # quarter, quarter, 8th 8th, rest
B2 = "A.t.t.t.A.t.t.t."          # straight eighths
SNARE_ON = [A1, A2, A1, CAD, A1, A2, A1, CAD, B1, B1, B2, B2, A1, A2, A1, CAD]
# The solo: the same pattern, filled out the way a lead tip plays it (rolls into the accents, ghost notes between the
# eighths, a buzz roll through Part B's rests, a 7-stroke roll into each new phrase).
SNARE_SOLO = ["F.tgt.ttF.tgR.tt", "F.tgt.tgF.ttt.D.", "F.ttR.ttF.tgt.tt", "F.t.F.t.z-----S.",
              "F.tgt.ttF.tgR.tt", "F.tgt.tgF.ttt.D.", "F.ttR.ttF.tgt.tt", "F.t.F.t.z-----S.",
              "F...t.t.F.t.z---", "F...t.t.F.t.z-S.", "A.ttt.ttA.ttR.tt", "A.ttt.tgA.ttz-S.",
              "F.tgt.ttF.tgR.tt", "F.tgt.tgF.ttt.D.", "F.ttR.ttF.tgt.tt", "F.t.F.t.z-----S."]
# Bass: on 1 and 3 throughout; in Part B a grace (flam) into beat 1, accented. Per bar: sixteenth -> force.
BASS_ON = {0: 0.78, 8: 0.6}
BASS_B = {0: 0.9, 8: 0.6}
BASS_SOLO_EXTRA = [{}, {14: 0.4}, {}, {4: 0.55}, {}, {14: 0.4}, {}, {4: 0.55},
                   {12: 0.4}, {12: 0.4}, {}, {14: 0.45}, {}, {14: 0.4}, {}, {4: 0.55}]
TENOR_SOLO = [{0: .7, 8: .55}, {0: .6, 6: .5, 8: .6}, {0: .7, 8: .55}, {0: .7, 4: .6},
              {0: .7, 8: .55}, {0: .6, 6: .5, 8: .6}, {0: .7, 8: .55}, {0: .7, 4: .6},
              {0: .8, 4: .5, 8: .7}, {0: .7, 4: .5, 8: .6}, {0: .7, 8: .55}, {0: .7, 4: .5, 8: .6, 12: .5},
              {0: .7, 8: .55}, {0: .6, 6: .5, 8: .6}, {0: .7, 8: .55}, {0: .7, 4: .6}]


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
        assert len(bar) == 16, (b, bar)
        t0 = b * 4 * BEAT
        i = 0
        while i < 16:
            c = bar[i]
            t = t0 + i * six
            if c in "FADtgr":
                v = {"F": 0.88, "A": 0.82, "D": 0.86, "t": 0.46, "g": 0.24, "r": 0.5}[c] * lvl
                v *= 1.0 if hand[0] == 0 else 0.93          # the lead hand a touch stronger
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
        part_b = 8 <= b < 12
        for k, v in (BASS_B if part_b else BASS_ON).items():
            tt = t0 + k * six + jit(3)
            if part_b and k == 0:
                bd.add(kit.hit("bass", 0.3 * lvl), tt - 0.03)        # the grace into beat 1
            bd.add(kit.hit("bass", v * lvl * (1 + rng.normal(0, 0.04))), tt)
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
MUSIC_VOL, DUCK, DUCK_SOLO = -8.0, -12.0, -16.0   # music.gd VOL, BandSound.DUCK_DB / DUCK_SOLO_DB (a band centred)
MUSIC_SLIDER = 20 * np.log10(0.5)                # the Music bus at the MUSIC slider's default (0.5: -6 dB); SOUND 1.0 (0 dB)
DUCK_RATE, FADE_RATE = 10.0, 60.0                 # dB a second: BandSound.DUCK_RATE (the music), FADE x 10 (the band)


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


def music_bit(f, s, start=20.0):
    m = decode(os.path.join(ROOT, "assets", "music", f + ".ogg"))
    mus = m[int(start * SR):int((start + s) * SR)]
    if len(mus) < int(s * SR):
        mus = np.pad(mus, (0, int(s * SR) - len(mus)))
    return mus


def game_mix(mus, parts, state, duck0=0.0, band0=-80.0):
    """BandSound's mix over time: state(t) -> (band on screen, the pipes soloing). The music at MUSIC_VOL and the
    sliders' defaults (MUSIC_SLIDER) plus the duck
    (moving to DUCK / DUCK_SOLO at DUCK_RATE dB a second while the band is heard, back to 0 when not); the band's
    parts move to their levels at FADE_RATE dB a second (-80 = off). Worked out every 10 ms, smoothed in between."""
    n = len(mus)
    k = 441
    steps = n // k + 1
    duck, lv = duck0, {p: (band0 if p in ("drums", "fife", "pipes") else -80.0) for p in parts}
    gm = np.zeros(steps)
    gp = {p: np.zeros(steps) for p in parts}
    dt = k / SR
    for i in range(steps):
        on, solo = state(i * dt)
        want = {p: -80.0 for p in parts}
        if on:
            for ins in ("drums", "fife", "pipes"):
                if solo and ins == "pipes":
                    want["pipes_lead"] = LEAD
                else:
                    want[ins] = UNDER if solo else QUIET
        dw = (DUCK_SOLO if solo else DUCK) if on else 0.0
        duck += np.clip(dw - duck, -DUCK_RATE * dt, DUCK_RATE * dt)
        for p in parts:
            lv[p] += np.clip(want[p] - lv[p], -FADE_RATE * dt, FADE_RATE * dt)
            gp[p][i] = db(lv[p]) if lv[p] > -79.0 else 0.0
        gm[i] = db(MUSIC_VOL + MUSIC_SLIDER + duck)
    x = np.arange(n) / k
    y = mus * np.interp(x, np.arange(steps), gm)
    for p in parts:
        y += seconds(parts[p], n / SR) * np.interp(x, np.arange(steps), gp[p])
    return y


def listening(parts, target):
    os.makedirs(DOCS, exist_ok=True)
    for f in os.listdir(DOCS):
        if f.endswith(".mp3") and not f.startswith("09_PREVIOUS_"):
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
    # 7. over each faction's battle music, as the game mixes it NOW (band-music-v2): the band centred on the screen the
    # whole file, so the music is ducked DUCK dB under the band playing along and DUCK_SOLO under the pipes' solo (the
    # second half), moving at DUCK_RATE dB a second; 07b: the camera comes to the band for the middle third only.
    for fac, f in [("crown", "crown_battle_7"), ("clockwork", "clock_battle_7"), ("brood", "brood_battle_7")]:
        mus = music_bit(f, S)
        half = S / 2
        y = game_mix(mus, parts, lambda t: (True, t >= half), duck0=DUCK, band0=QUIET)
        put("07_over_%s_battle_music" % fac, fade_out(y),
            what="the band over the %s's battle music (%s.ogg) as the game mixes it now: the band centred on the "
                 "screen, the music ducked %.0f dB under it, %.0f dB under the pipes' solo (from halfway)"
                 % (fac, f, -DUCK, -DUCK_SOLO))
    mus = music_bit("crown_battle_7", S)
    y = game_mix(mus, parts, lambda t: (S / 3 <= t < 2 * S / 3, False), duck0=0.0, band0=-80.0)
    put("07b_camera_comes_and_goes", fade_out(y),
        what="the Crown's battle music; the camera comes to a band playing along for the middle third (15 s to 30 s) "
             "and leaves: the music ducks %.0f dB in about %.1f s and comes back up the same way" % (-DUCK, -DUCK / DUCK_RATE))
    for f in sorted(os.listdir(DOCS)):
        if f.startswith("09_PREVIOUS_"):
            out.append((f[:-4], "BEFORE (0.37.1, Scotland the Brave in G at 98, the music ducked only 2.5 / 6 dB): " + f[12:-4]))
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
