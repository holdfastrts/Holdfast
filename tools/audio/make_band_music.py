"""THE MARCHING BAND's MUSIC (jobs band-music, band-music-v2 and band-repertoire, docs/band_music.md): renders the
band's REPERTOIRE (scripts/band_sound.gd: TUNES, PARTS, ORDER) from real instrument samples, and the owner's listening
files.

Since band-repertoire (owner's playtest 2026-11-14 13:18) the band plays a PLAYLIST, not one loop: every tune is one
file per part (drums, fife, pipes; a quiet "always-on" file and a "solo" file of each), each file

    [the roll-off] [the tune once, start to end] [a short tail]

all six files of a tune exactly the same length, so a band's parts stay in step and the next tune follows the last:
the drums' ROLL-OFF (two rolls into the tune's first beat, in the new tune's tempo) links one tune to the next.

The tunes (traditional melodies, public domain; see TUNES): The British Grenadiers (2/4, from the owner's score),
Scotland the Brave (4/4, from the owner's score, as band-music-v2 made it), Garry Owen (6/8 quickstep), The Minstrel Boy
(4/4 slow air), God Save the King (3/4, an extra). The drum beatings are OUR OWN, written in the style of rudimental
fife-and-drum corps parts (flams on the accents, 5-, 7- and 9-stroke rolls, drags, sixteenth runs at phrase ends; the
slow air with a muffled drum only), and Scotland the Brave keeps the pipe band pattern of band-music-v2.

  pipes   FreePats bagpipe (Gilles Sadowski, CC0): the chanter notes retuned to just intonation over the two drones
          (the recorded G drones moved to the tune's tonic), played as one unbroken sound with the pipe gracenotes.
          Always-on: the plain melody with single gracenotes. Solo: every gracenote and a second pipe in unison (and in
          Scotland the Brave the score's lower voice). The pipes STRIKE IN during the roll-off (the drones, then the
          chanter on the fifth for the last beat before the tune, as a pipe band does).
  fife    VCSL Baroque Soprano Recorder (Versilian Studios, CC0), made fife-like: the melody an octave over the pipes.
  drums   MuldjordKit (Lars Muldjord, CC BY 4.0): a marching snare, a parade bass drum, a tenor drum, a cymbal.

LEVELS (band-repertoire): every file is levelled by its INTEGRATED LOUDNESS (LUFS, ITU-R BS.1770: pyloudnorm), not by
its loudest moment, so the drums (short loud strokes) are no longer far quieter than the pipes (a steady sound): the
always-on files at ON_LUFS, the solo files at SOLO_LUFS, each part moved by PART_LU (the pipes a little back, they mask
the others). Peaks are held under 0.97 by a soft limiter with a little look-ahead.

Run:  python3 tools/audio/make_band_music.py            (writes assets/audio/band/*.ogg and docs/band_sound/*.mp3)
      python3 tools/audio/make_band_music.py --no-docs  (only the game's files)
      python3 tools/audio/make_band_music.py --docs-only  (only the listening files, from the files as they are)
      python3 tools/audio/make_band_music.py --only grenadiers,minstrel   (only these tunes)
Needs numpy, scipy, soundfile, soxr, pyloudnorm, ffmpeg."""
import json
import os
import re
import subprocess
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
import soxr
from scipy import signal

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "art", "audio_src", "band")
OUT = os.path.join(ROOT, "assets", "audio", "band")
DOCS = os.path.join(ROOT, "docs", "band_sound")

SR = 44100
METER = pyln.Meter(SR)
ON_LUFS = -27.0            # the always-on files
SOLO_LUFS = -23.0          # the solo files (4 LU over: the soloist's part forward)
PART_LU = {"pipes": -2.0, "fife": 0.5, "drums": 1.0}     # the pipes a little back (they mask the others)
AIR_DRUMS_LU = -5.0        # the slow air's drums: a muffled drum, not a beating (on top of PART_LU)

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


class Buf:
    """A buffer of n samples; anything added past the end is cut (the files are not loops any more)."""

    def __init__(self, n):
        self.n = n
        self.y = np.zeros(n)

    def add(self, sig, t):
        i = int(round(t * SR))
        a, b = max(0, i), min(self.n, i + len(sig))
        if b > a:
            self.y[a:b] += sig[a - i:b - i]


def conv(x, ir):
    """A room on a file (linear convolution, cut to the file's length)."""
    return signal.fftconvolve(x, ir)[:len(x)]


def room(seconds, tau, bright=6000.0, seed=0):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = r.standard_normal(n) * np.exp(-t / tau)
    b, a = signal.butter(2, bright / (SR / 2), "low")
    ir = signal.lfilter(b, a, ir)
    ir[:int(0.006 * SR)] *= np.linspace(0, 1, int(0.006 * SR))
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
    """Equal-power fade in over fin samples and out over fout samples."""
    e = np.ones(n)
    if fin > 0:
        e[:fin] = np.sin(np.linspace(0, np.pi / 2, fin))
    if fout > 0:
        e[n - fout:] *= np.cos(np.linspace(0, np.pi / 2, fout))
    return e


def lufs(x):
    v = METER.integrated_loudness(x)
    return float(v) if np.isfinite(v) else -70.0


def jit(ms):
    return rng.normal(0.0, ms / 1000.0)


# ------------------------------------------------------------------ the tunes

NAMES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi_of(name):
    m = re.match(r"([A-G]#?)(\d)", name)
    return 12 * (int(m.group(2)) + 1) + NAMES[m.group(1)]


def abc(text, sharps=("F",)):
    """A small ABC reader (L:1/8; enough for these tunes): notes C-B (octave 4), c-b (octave 5), ' and , octaves,
    lengths (2, 3, /, 3/2), the broken rhythm A>B, ties A2-A2 (merged), z rests, | bar lines (checked by the caller).
    -> [(length in sixteenths, written midi or None for a rest, staccato)] with a "|" between bars."""
    out = []
    toks = re.findall(r"\||-|>|z[\d/]*|[\^_=]?[A-Ga-g][',]*[\d/]*'?", text)
    pend_tie = False
    broken = False
    for tk in toks:
        if tk == "|":
            out.append("|")
            continue
        if tk == "-":
            pend_tie = True
            continue
        if tk == ">":
            broken = True
            continue
        m = re.match(r"([\^_=]?)([A-Ga-gz])([',]*)([\d/]*)", tk)
        acc, letter, octs, ln = m.groups()
        if ln == "":
            f = 1.0
        elif ln == "/":
            f = 0.5
        elif "/" in ln:
            a, b = ln.split("/")
            f = float(a or 1) / float(b or 2)
        else:
            f = float(ln)
        six = f * 2.0
        if letter == "z":
            note = None
        else:
            up = letter.upper()
            o = 5 if letter.islower() else 4
            o += octs.count("'") - octs.count(",")
            semis = NAMES[up] + (1 if (up in sharps and acc == "") or acc == "^" else 0) - (1 if acc == "_" else 0)
            note = 12 * (o + 1) + semis
        if broken:                     # A>B: the note before dotted, this one halved
            ln0, n0, s0 = out[-1]
            out[-1] = (ln0 * 1.5, n0, s0)
            six *= 0.5
            broken = False
        if pend_tie and note is not None:
            out.append(("tie", six))           # (the note before goes on: read() lengthens it)
            pend_tie = False
            continue
        out.append((six, note, False))
    return out


class Tune:
    """One tune: its notes from bar 1's downbeat (in sixteenths; a pick-up before it is negative), its metre, tempo,
    key, how it is sounded, and the drum beating."""

    def __init__(self, tid, title, grid, beat_six, bpm, transpose, tonic, scale, text=None, events=None, pickup=0,
                 kind="march", n_bars=None):
        self.id, self.title, self.grid, self.beat_six = tid, title, grid, beat_six
        self.pickup = pickup
        self.bpm, self.transpose, self.kind = bpm, transpose, kind
        self.six = 60.0 / bpm / beat_six             # seconds a sixteenth
        self.tonic_w = tonic                          # the tonic, written (midi)
        self.scale = scale                            # semitones of the mode over the tonic, with just ratios
        if events is None:
            events = self.read(text, pickup)
        self.ev = events                              # [(start six, length six, written midi, staccato, bar)]
        self.n_bars = n_bars or getattr(self, "read_bars", max(e[4] for e in self.ev) + 1)
        notes = sorted(set(e[2] for e in self.ev))
        self.lo, self.hi = notes[0], notes[-1]
        self.notes = notes
        self.lower = {}                               # (Scotland) the score's lower voice
        self.second_rest = []                         # bars the solo's second pipe rests (Scotland: Part B)

    def read(self, text, pickup):
        """Events from ABC text: bar lengths are checked (the pick-up and the last bar may be short)."""
        items = abc(text)
        ev = []
        t = -pickup
        bar = -1 if pickup > 0 else 0
        bar_t = 0.0
        bars = []
        for it in items:
            if it == "|":
                bars.append(bar_t)
                bar += 1
                bar_t = 0.0
                continue
            if it[0] == "tie":
                a, b, c, d, e = ev[-1]
                ev[-1] = (a, b + it[1], c, d, e)
                bar_t += it[1]
                t += it[1]
                continue
            six, n, st = it
            if n is not None:
                ev.append((t, six, n, st, max(bar, 0)))
            t += six
            bar_t += six
        if bar_t > 0:
            bars.append(bar_t)
        inner = bars[1:-1] if pickup > 0 else bars[:-1]
        bad = [i for i, b in enumerate(inner) if abs(b - self.grid) > 1e-6]
        assert not bad, (self.id, "bars of the wrong length", [(i, inner[i]) for i in bad])
        self.end_six = t
        self.read_bars = len(bars) - (1 if pickup > 0 else 0)
        return [(float(a), float(b), c, d, e) for (a, b, c, d, e) in ev]

    # sound
    def ratio(self, semis):
        o, s = divmod(semis, 12)
        return 2.0 ** o * self.scale[s]

    def freq(self, written):
        """The pipes' sounding pitch of a written note: just intonation over the drones (the tonic)."""
        return self.tonic_hz * self.ratio(written - self.tonic_w)

    @property
    def tonic_hz(self):
        return 440.0 * 2 ** ((self.tonic_w + self.transpose - 69) / 12)

    def scale_notes(self):
        """The mode's notes (written) from a fifth under the tune's lowest to a third over its highest."""
        out = []
        for m in range(self.lo - 7, self.hi + 5):
            if (m - self.tonic_w) % 12 in self.scale:
                out.append(m)
        return out

    def step(self, n, k):
        sc = self.scale_notes()
        i = min(range(len(sc)), key=lambda j: abs(sc[j] - n))
        return sc[max(0, min(len(sc) - 1, i + k))]

    def t(self, six):
        """Seconds from bar 1's downbeat."""
        return six * self.six


MAJOR = {0: 1.0, 2: 9 / 8, 4: 5 / 4, 5: 4 / 3, 7: 3 / 2, 9: 5 / 3, 11: 15 / 8}
DORIAN = {0: 1.0, 2: 9 / 8, 3: 6 / 5, 5: 4 / 3, 7: 3 / 2, 9: 5 / 3, 10: 9 / 5}

# ---- Scotland the Brave: as band-music-v2 made it from the owner's score (written in D, sounding in E)
SCOT_BAR = {
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
SCOT_FORM = [1, 2, 3, 4, 1, 2, 3, 8, 9, 10, 11, 12, 1, 2, 3, 8]
SCOT_LOWER = {1: "D4 F#4", 2: "F#4 D4", 3: "D4 D4", 4: "C#4 E4", 8: "C#4 D4",
              9: "A4 E4", 10: "F#4 D4", 11: "F#4 A4", 12: "E4 D4"}


def scotland():
    ev = []
    t = 0.0
    for bi, b in enumerate(SCOT_FORM):
        for tok in SCOT_BAR[b].split(","):
            n, d = tok.split()
            ev.append((t * 2, float(d) * 2, midi_of(n.rstrip("'")), n.endswith("'"), bi))
            t += float(d)
    # D#5 (the score's chromatic note) over E: its own just ratio (the leading note into E5)
    scale = dict(MAJOR)
    scale[1] = 135 / 128               # (D#5 = 2 x 135/128 over D4: the leading note into E5)
    tu = Tune("scotland", "Scotland the Brave", 16, 4, 110.0, 2, midi_of("D4"), scale, events=ev, n_bars=16)
    tu.end_six = 16 * 16
    tu.lower = SCOT_LOWER
    tu.second_rest = list(range(8, 12))
    tu.form = SCOT_FORM
    return tu


GRENADIERS = """D2|G2 D2|G2 A2|B4|A2 B>c|d2 G2|B>A G>F|G4-|G2 D2|
G2 D2|G2 A2|B4|A2 B>c|d2 G2|B>A G>F|G4-|G2 B>c|
d3 e|d2 c2|B3 c|d2 G2|G2 A>B|c2 B2|A4|z2 D>D|
G2 D2|G2 A2|B4|A2 Bc|d2 G2|B>A G>F|G4-|G2 z2|"""

GARRYOWEN = """g/f/|edc BAG|B>cB B2 g/f/|edc BAG|A>BA A2 g/f/|edc BAG|B>cB B2 c|def gdB|A>BA A2 g/f/|
edc BAG|B>cB B2 g/f/|edc BAG|A>BA A2 g/f/|edc BAG|B>cB B2 c|def gdB|A>BA A2 B/c/|
d2B d2B|d2B dgf|e2c e2c|e2c e2f|g2a b2a|gfe d2B|def gdB|A>BA A2 B/c/|
d2B d2B|d2B dgf|e2c e2c|e2c e2f|g2a b2a|gfe d2B|def gdB|A>BA A2 z|"""

# The B part's last bar as the brief has it (e>d ef gf e) is seven eighths: a D (the pick-up back into the A part)
# fills it. The A part is played once more at the end, ending on a held G.
MINSTREL = """d|G3 A cBAG|B2 d2 g2 fg|e2 d2 B>c dB|A4 G3 d|
G3 A cBAG|B2 d2 g2 fg|e2 d2 B>c dB|A4 G3 d|
g2 f2 e2 fg|f2 e2 d3 d|e3 B B3 d|e>d ef gf ed|
G3 A cBAG|B2 d2 g2 fg|e2 d2 B>c dB|A4 G4|"""

GODSAVE = """G2 G2 A2|F3 G A2|B2 B2 c2|B3 A G2|A2 G2 F2|G6|d2 d2 d2|d3 c B2|c2 c2 c2|c3 B A2|B2 cB AG|B3 c d2|ed c2 B2|A2 G4|"""


def all_tunes():
    return {
        # 2/4, crotchet 100 (the owner's score: half note = 50); written in G, sounding in A
        "grenadiers": Tune("grenadiers", "The British Grenadiers", 8, 4, 100.0, 2, midi_of("G4"), MAJOR,
                           GRENADIERS, pickup=4),
        "scotland": scotland(),
        # 6/8 quickstep, dotted crotchet 118; A dorian written (one sharp), sounding in F# dorian
        "garryowen": Tune("garryowen", "Garry Owen", 12, 6, 118.0, -3, midi_of("A4"), DORIAN, GARRYOWEN,
                          pickup=2, kind="quick"),
        # 4/4 slow air, crotchet 70; in G
        "minstrel": Tune("minstrel", "The Minstrel Boy", 16, 4, 70.0, 0, midi_of("G4"), MAJOR, MINSTREL,
                         pickup=2, kind="air"),
        # 3/4, crotchet 72; in G
        "godsave": Tune("godsave", "God Save the King", 12, 4, 72.0, 0, midi_of("G4"), MAJOR, GODSAVE,
                        kind="anthem"),
    }


# ------------------------------------------------------------------ the drum beatings (our own)
# One character a sixteenth, the whole piece as one string (the roll-off first):
#   F flam accent   A accent   t tap   g ghost   D drag accent   R 5-stroke roll ending here (over the sixteenth
#   before)   S 7-stroke roll ending here (over the two before)   N 9-stroke roll ending here (over the three before)
#   z a buzz roll from here, - it goes on (swelling into what follows)   . rest
# Scotland the Brave keeps band-music-v2's pattern after the reference score.

SC_A1 = "F.t.t.t.F.t.t.tt"
SC_A2 = "F.t.t.t.F.t.t.D."
SC_CAD = "F.t.F.t........."
SC_B1 = "F...t...F.t....."
SC_B2 = "A.t.t.t.A.t.t.t."
SC_ON = [SC_A1, SC_A2, SC_A1, SC_CAD, SC_A1, SC_A2, SC_A1, SC_CAD, SC_B1, SC_B1, SC_B2, SC_B2, SC_A1, SC_A2, SC_A1, SC_CAD]
SC_SOLO = ["F.tgt.ttF.tgR.tt", "F.tgt.tgF.ttt.D.", "F.ttR.ttF.tgt.tt", "F.t.F.t.z-----S.",
           "F.tgt.ttF.tgR.tt", "F.tgt.tgF.ttt.D.", "F.ttR.ttF.tgt.tt", "F.t.F.t.z-----S.",
           "F...t.t.F.t.z---", "F...t.t.F.t.z-S.", "A.ttt.ttA.ttR.tt", "A.ttt.tgA.ttz-S.",
           "F.tgt.ttF.tgR.tt", "F.tgt.tgF.ttt.D.", "F.ttR.ttF.tgt.tt", "F.t.F.t........."]

# The British Grenadiers, 2/4 (8 a bar): flams on the beats, 5- and 7-stroke rolls, drags at phrase ends.
GR_A = ["F.t.A.t.", "F.t.A.tt", "F...S.t.", "F.t.A.t.", "F.t.A.t.", "F.ttA.t.", "F.t.F.t.", "F...D.t."]
GR_A2 = GR_A[:7] + ["F...R.t."]
GR_B = ["F.t.R.t.", "F.t.A.t.", "F...S.t.", "F.t.A.tt", "F.t.R.t.", "F.t.A.t.", "F...S...", "z---A.t."]
GR_END = GR_A[:6] + ["F.t.F.t.", "A......."]
GR_ON = GR_A + GR_A2 + GR_B + GR_END
GR_SOLO = ["F.tgA.tg", "F.tgA.tt", "F...S.tg", "F.t.R.tt", "F.tgA.tg", "F.ttA.tt", "F.tgF.tg", "F...N.tt",
           "F.tgA.tg", "F.tgA.tt", "F...S.tg", "F.t.R.tt", "F.tgA.tg", "F.ttA.tt", "F.tgF.tg", "F...S.t.",
           "F.t.R.tg", "F.ttA.tg", "F...S.tt", "F.tgA.tt", "F.t.R.tg", "F.ttA.tg", "F...N...", "z---A.tt",
           "F.tgA.tg", "F.tgA.tt", "F...S.tg", "F.t.R.tt", "F.tgA.tg", "F.ttA.tt", "F.tgF.t.", "A......."]
GR_ROLL = "z-----------A...z-----------A..."      # two rolls; the second's accent is the pick-up's beat

# Garry Owen, 6/8 (12 a bar): a 7-stroke roll into bar 1's accent; straight quavers accented on the dotted-crotchet
# beats; at the 2-bar phrase ends a 6-note sixteenth run into an accented dotted crotchet (or two 7-stroke rolls);
# the second strain more rolls and flams; the last bar an accented crotchet and rest.
GO_A = ["S.t.t.F.t.t.", "ttttttF.....", "F.t.t.F.t.t.", "ttttttF.....",
        "F.t.t.F.t...", "S.....S.....", "F.t.t.F.t.t.", "F.t.t.A....."]
GO_B = ["S.t.t.F.t.F.", "F.t...S.....", "F.t.t.F.t.t.", "ttttttF.....",
        "F.t.t.F.t.F.", "F.t...S.....", "F.t.t.F.t.t.", "F.t.t.A....."]
GO_ON = GO_A + GO_A + GO_B + GO_B
GO_SOLO_A = ["S.tgt.F.tgt.", "ttttttF.t.tg", "F.tgt.F.tgt.", "ttttttF...R.",
             "F.tgt.F.t...", "S.....S...R.", "F.tgt.F.tgt.", "F.tgt.A....."]
GO_SOLO_B = ["S.tgt.F.tgF.", "F.t...S...R.", "F.tgt.F.tgt.", "ttttttF.ttt.",
             "F.tgt.F.tgF.", "F.t...S...R.", "F.tgt.F.tgt.", "F.tgt.A....."]
GO_SOLO = GO_SOLO_A + GO_SOLO_A + GO_SOLO_B + GO_SOLO_B
GO_ROLL = "z-------A...z-------A..."

# God Save the King, 3/4 (12 a bar): flams on beat 1, a roll swelling into the next bar's first beat at phrase ends.
GS_ON = ["F...t...t...", "F...t...t...", "F...t...t...", "F...t...z---", "F...t...t...", "F...t...z---",
         "F...t...t...", "F...t...t...", "F...t...t...", "F...t...z---", "F...t...t...", "F...t...z---",
         "F...t...t...", "F.....A....."]
GS_SOLO = ["F...t.t.t.t.", "F.t.t...t.t.", "F...t.t.R...", "F...t...z---", "F...t.t.t.t.", "F...t...z---",
           "F...t.t.t.t.", "F.t.t...t.t.", "F...t.t.R...", "F...t...z---", "F...t.t.t.t.", "F...t...z---",
           "F.t.t...t.t.", "F.....A....."]
GS_ROLL = "z-----------------------"

SC_ROLL = "z-----------A...z-----------A..."


def score_of(tu, solo):
    """[roll-off string, tune string, bass {sixteenth in the piece: force}, tenor {...}, cymbal [six]]"""
    g = tu.grid
    bass, tenor, cym = {}, {}, []
    if tu.id == "scotland":
        roll, bars = SC_ROLL, (SC_SOLO if solo else SC_ON)
        for b in range(16):
            part_b = 8 <= b < 12
            bass[b * g] = 0.9 if part_b else 0.78
            bass[b * g + 8] = 0.6
        if solo:
            for b, extra in enumerate([{}, {14: .4}, {}, {4: .55}, {}, {14: .4}, {}, {4: .55}, {12: .4}, {12: .4}, {},
                                       {14: .45}, {}, {14: .4}, {}, {4: .55}]):
                for k, v in extra.items():
                    bass[b * g + k] = v
            for b in range(16):
                tenor[b * g] = 0.7
                tenor[b * g + 8] = 0.55
            cym = [0, 8 * g]
    elif tu.id == "grenadiers":
        roll, bars = GR_ROLL, (GR_SOLO if solo else GR_ON)
        for b in range(tu.n_bars):
            bass[b * g] = 0.8 if b % 4 == 0 else 0.7
            bass[b * g + 4] = 0.55
            if solo and b % 2 == 1:
                tenor[b * g] = 0.6
                tenor[b * g + 4] = 0.5
        if solo:
            cym = [0, 16 * g]
    elif tu.id == "garryowen":
        roll, bars = GO_ROLL, (GO_SOLO if solo else GO_ON)
        for b in range(tu.n_bars):
            bass[b * g] = 0.8
            bass[b * g + 6] = 0.6
            if solo:
                for k in (2, 4, 8, 10):
                    if b % 2 == 0:
                        bass[b * g + k] = 0.35        # the bass doubling the quavers now and then
                tenor[b * g] = 0.6
        if solo:
            cym = [0, 16 * g]
    elif tu.id == "godsave":
        roll, bars = GS_ROLL, (GS_SOLO if solo else GS_ON)
        for b in range(tu.n_bars):
            bass[b * g] = 0.85
            if solo:
                bass[b * g + 4] = 0.4
                bass[b * g + 8] = 0.4
        if solo:
            cym = [0, 6 * g]
    else:            # the slow air: no snare beating (drum_air below)
        return None
    s = "".join(bars)
    assert len(roll) % g == 0 and len(s) == tu.n_bars * g, (tu.id, len(roll), len(s), tu.n_bars * g)
    return roll, s, bass, tenor, cym


ROLL_BARS = {"scotland": 2, "grenadiers": 4, "garryowen": 2, "minstrel": 1, "godsave": 2}


# ------------------------------------------------------------------ pipes

def pitch_of(x, lo=80, hi=1000):
    """The pitch of a steady tone (autocorrelation over the middle second, refined parabolically)."""
    mid = len(x) // 2
    s = x[mid - SR // 2: mid + SR // 2]
    s = s - s.mean()
    c = np.fft.irfft(np.abs(np.fft.rfft(s, 2 * len(s))) ** 2)[:len(s)]
    a, b = int(SR / hi), int(SR / lo)
    k = a + int(np.argmax(c[a:b]))
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


_takes = []
_chanter = {}


def chanter(freq):
    """The takes nearest this pitch (by their MEASURED pitch), each retuned to it (steady part only)."""
    if not _takes:
        d = os.path.join(SRC, "freepats_bagpipe")
        for f in sorted(os.listdir(d)):
            if f.endswith(".wav") and not f.startswith("drone"):
                x = load(os.path.join(d, f))
                f0 = pitch_of(x, 250, 900)
                _takes.append((69 + 12 * np.log2(f0 / 440.0), f0, x, f))
    key = round(freq, 2)
    if key not in _chanter:
        wm = 69 + 12 * np.log2(freq / 440.0)
        best = min(abs(t[0] - wm) for t in _takes)
        near = [t for t in _takes if abs(t[0] - wm) <= best + 0.35]
        out = []
        for (m, f0, x, f) in near:
            y = shift(x, freq / f0)
            out.append(y[int(0.3 * SR):len(y) - int(0.25 * SR)])
        _chanter[key] = (out, 1200 * np.log2(freq / near[0][1]))
    return _chanter[key][0]


_drones = {}


def drone_loop(fname, freq, cycles):
    """A seamless loop of `cycles` cycles of a drone recording retuned to freq (the recorded G drones to the tonic)."""
    k = (fname, round(freq, 3))
    if k in _drones:
        return _drones[k]
    x = load(os.path.join(SRC, "freepats_bagpipe", fname))
    f0 = pitch_of(x, 60, 300)
    expect = int(round(cycles * SR / f0))
    a = int(0.25 * SR)
    xf = int(0.08 * SR)
    ref = x[a:a + xf]
    best, bk = -1e9, expect
    for kk in range(expect - 300, expect + 301):
        if a + kk + xf >= len(x):
            break
        c = np.dot(ref, x[a + kk:a + kk + xf]) / (np.linalg.norm(x[a + kk:a + kk + xf]) + 1e-9)
        if c > best:
            best, bk = c, kk
    seg = x[a:a + bk + xf].copy()
    lo = seg[:bk].copy()
    w = np.linspace(0, 1, xf)
    lo[:xf] = seg[bk:bk + xf] * np.cos(w * np.pi / 2) + seg[:xf] * np.sin(w * np.pi / 2)
    n_loop = int(round(cycles * SR / freq))
    out = soxr.resample(lo, SR, SR * n_loop / bk, quality="VHQ")[:n_loop]
    if len(out) < n_loop:
        out = np.pad(out, (0, n_loop - len(out)), mode="edge")
    _drones[k] = out
    return out


def graces_scotland(tu, i, solo):
    """band-music-v2's gracenotes for Scotland the Brave (written in D: D4 = the pipes' low A)."""
    G_, D_, E_, LG = midi_of("C#5"), midi_of("G4"), midi_of("A4"), midi_of("C#4")
    DOUBLING = {midi_of("D4"): [G_, midi_of("D4"), D_], midi_of("E4"): [G_, midi_of("E4"), D_],
                midi_of("F#4"): [G_, midi_of("F#4"), D_], midi_of("G4"): [G_, midi_of("G4"), E_],
                midi_of("A4"): [G_, midi_of("A4"), midi_of("B4")], midi_of("B4"): [G_, midi_of("B4"), G_],
                midi_of("C#5"): [midi_of("D5"), midi_of("C#5"), midi_of("D5")], midi_of("D5"): [G_],
                midi_of("D#5"): [], midi_of("E5"): [midi_of("F#5")], midi_of("F#5"): [midi_of("D5")]}

    def single(n):
        if n <= midi_of("B4"):
            return [G_]
        return {midi_of("C#5"): [midi_of("D5")], midi_of("D5"): [G_], midi_of("E5"): [midi_of("F#5")],
                midi_of("F#5"): [midi_of("D5")]}.get(n, [])
    t, d, n, st, _ = tu.ev[i]
    prev = tu.ev[i - 1][2]
    on_beat = abs(t / 4 - round(t / 4)) < 1e-6
    long_ = d >= 4 - 1e-6
    rep = prev == n
    if not solo:
        return single(n) if (rep or (long_ and on_beat)) else []
    if rep and n <= midi_of("A4"):
        return [LG, D_, LG] if n != midi_of("G4") else [LG, E_, LG]
    if rep:
        return single(n)
    if long_ and on_beat:
        return DOUBLING.get(n, single(n))
    if d >= 3 - 1e-6 or on_beat:
        return single(n)
    if n < prev and n <= midi_of("E4"):
        return [E_]
    return []


def graces(tu, i, solo):
    """The pipe gracenotes before note i, as a piper ornaments a tune: a high gracenote (the "high G": the mode's
    note just under the tune's top) on long notes on the beat and on repeated notes, doublings and grips in the solo.
    The tune's top notes take the note above (or a strike from below at the very top)."""
    if tu.id == "scotland":
        return graces_scotland(tu, i, solo)
    t, d, n, st, _ = tu.ev[i]
    if i == 0:
        return [tu.step(tu.hi, -1)] if n < tu.step(tu.hi, -1) else []
    prev = tu.ev[i - 1][2]
    on_beat = abs(t / tu.beat_six - round(t / tu.beat_six)) < 1e-6
    long_ = d >= 4 - 1e-6
    rep = prev == n
    hig = tu.step(tu.hi, -1)                       # the "high G" gracenote

    def single(m):
        if m < hig:
            return [hig]
        if m == hig:
            return [tu.hi]
        return [tu.step(m, -2)]                    # the top note: a strike from under it
    low = tu.lo
    mid = tu.step(low, 3)
    if not solo:
        return single(n) if (rep or (long_ and on_beat)) else []
    if rep and n <= mid:
        return [low, mid if n != mid else tu.step(low, 4), low]       # a grip between repeated low notes
    if rep:
        return single(n)
    if long_ and on_beat:
        if n < hig:
            return [hig, n, tu.step(n, 2) if tu.step(n, 2) < hig else tu.step(n, 1)]    # a doubling
        return single(n)
    if d >= 3 - 1e-6 or on_beat:
        return single(n)
    if n < prev and n <= tu.step(low, 1):
        return [tu.step(low, 4)]                   # stepping down to the bottom: the "E" gracenote
    return []


def chanter_line(tu, notes, gl, end_t, crossfade_ms=6, wobble=4):
    """One chanter playing `notes` [(t s, written midi, [graces])] as one unbroken sound: each note runs until the
    next begins (a finger change: a short crossfade), the last one until end_t; gracenotes just before the beat."""
    tr = Buf(tu.N)
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
        last = i + 1 == len(segs)
        nxt = end_t if last else segs[i + 1][0]
        d = nxt - t
        f = tu.freq(n)
        takes = chanter(f)
        take = takes[take_i.get(f, 0) % len(takes)]
        take_i[f] = take_i.get(f, 0) + 1
        fo = int(0.09 * SR) if last else xf
        n_s = int(round(d * SR)) + (0 if last else xf)
        off = int(rng.uniform(0, max(1, len(take) - n_s - 1)))
        s = take[off:off + n_s]
        if len(s) < n_s:
            s = np.resize(take[len(take) // 4:], n_s)
        tr.add(s * fades(n_s, xf, min(fo, n_s)), t - xf / 2 / SR)
    return tr.y


def render_pipes(tu, solo):
    gl = 0.028 if solo else 0.032
    t0 = tu.roll_s
    ev = tu.ev
    end_t = t0 + tu.t(ev[-1][0] + ev[-1][1])
    # the strike-in: the chanter on the fifth for the last beat before the tune's first note
    first = t0 + tu.t(ev[0][0])
    fifth = tu.step(tu.tonic_w, 4) if tu.step(tu.tonic_w, 4) >= tu.lo else tu.step(tu.tonic_w + 12, 4)
    strike = [(first - tu.t(tu.beat_six), fifth, [tu.step(tu.hi, -1)] if fifth < tu.step(tu.hi, -1) else [])]
    lead = strike + [(t0 + tu.t(t), n, graces(tu, i, solo)) for i, (t, d, n, st, b) in enumerate(ev)]
    chan = chanter_line(tu, lead, gl, end_t)
    chan = chan / np.sqrt(np.mean(chan[chan != 0] ** 2))
    mix = (1.0 if solo else 0.75) * chan
    if solo:
        # the second pipe in unison (another take, a few ms behind, plainer); in Scotland it rests in Part B
        sec = strike + [(t0 + tu.t(t) + 0.008, n, graces(tu, i, False)) for i, (t, d, n, st, b) in enumerate(ev)]
        s2 = chanter_line(tu, sec, 0.032, end_t, wobble=6)
        tt = np.arange(tu.N) / SR
        gate = np.ones(tu.N)
        for b in tu.second_rest:
            gate[(tt >= t0 + tu.t(b * tu.grid)) & (tt < t0 + tu.t((b + 1) * tu.grid))] = 0.0
        gate = np.convolve(gate, np.ones(int(0.04 * SR)) / int(0.04 * SR), mode="same")
        mix += 0.42 * s2 / np.sqrt(np.mean(s2[s2 != 0] ** 2)) * gate
        if tu.lower:
            low = []
            for bi, b in enumerate(tu.form):
                for k, nm in enumerate(tu.lower[b].split()):
                    low.append((t0 + tu.t(bi * 16 + k * 8), midi_of(nm), [midi_of("C#5")] if k == 0 else []))
            s3 = chanter_line(tu, low, 0.03, end_t, wobble=5)
            mix += 0.3 * s3 / np.sqrt(np.mean(s3[s3 != 0] ** 2))
    # the drones (the recorded G drones moved to the tonic: two octaves and one octave under it), struck in at the
    # second half of the roll-off, dying with the last note
    f1 = tu.tonic_hz / 2
    while f1 > 240:
        f1 /= 2
    t3 = drone_loop("drone_G3_3.wav", f1, 400)
    t2 = drone_loop("drone_G2_1.wav", f1 / 2, 200)
    dr = np.zeros(tu.N)
    for x, g in ((t3, 0.55), (t2, 0.5)):
        dr += g * np.resize(x, tu.N) / np.sqrt(np.mean(x ** 2))
    on = int(max(0.0, first - tu.t(tu.beat_six) - min(1.4, t0 * 0.5)) * SR)
    off = int(end_t * SR)
    env = np.zeros(tu.N)
    a = int(0.25 * SR)
    env[on:on + a] = np.linspace(0, 1, a) ** 2
    env[on + a:off] = 1.0
    r = int(0.22 * SR)
    env[off:off + r] = np.linspace(1, 0, len(env[off:off + r]))
    mix = mix + (0.42 if solo else 0.35) * dr * env     # (the background part's drones further back: they cover the fife)
    mix = peq(mix, 2800, 1.5, 0.8) if solo else peq(mix, 3300, -4.0, 0.7)     # (background: the top back, the snare's room)
    return conv(mix, room(1.2, 0.18, 7000, 3)) * 0.22 + mix


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


_fife_cache = {}


def fife_tone(freq):
    key = round(freq, 2)
    if key not in _fife_cache:
        rec = recorder()
        midi = 69 + 12 * np.log2(freq / 440.0)
        k = min(rec, key=lambda m: abs(m - midi))
        x, f0 = rec[k]
        y = shift(x[:int(4.0 * SR)], freq / f0)
        y = y / (np.abs(y).max() + 1e-9)
        y = np.tanh(2.2 * y) / np.tanh(2.2) * 0.7 + y * 0.3
        y = peq(y, 3500, 4.0, 0.9)
        _fife_cache[key] = y
    return _fife_cache[key]


def breath(n, level):
    b = rng.standard_normal(n)
    b = lp(hp(b, 2500), 7500)
    return b * level


def render_fife(tu, solo):
    tr = Buf(tu.N)
    t0 = tu.roll_s
    air = tu.kind == "air"
    order = tu.scale_notes()
    for i, (ts, ds, n, st, b) in enumerate(tu.ev):
        t = t0 + tu.t(ts) + jit(5)
        d = tu.t(ds)
        f = 2 * tu.freq(n)
        tone = fife_tone(f)
        vel = (0.92 + 0.12 * rng.random()) * (1.0 if solo else 0.85)
        dur = d * ((0.97 if air else 0.93) if solo else (0.95 if air else 0.82))
        if st:
            dur = d * 0.5
        orn = []
        gr = graces(tu, i, True)
        k = order.index(n)
        long_ = ds >= 4 - 1e-6
        if solo and (gr and (i == 0 or n != tu.ev[i - 1][2]) or ds >= 8 - 1e-6):
            up = order[min(k + 1, len(order) - 1)]
            if long_ and not st:
                lo = order[max(k - 1, 0)]
                orn = [(up, 0.035), (n, 0.04), (lo, 0.035)]     # a roll (turn) into the long note
            else:
                orn = [(up, 0.032)]                              # a cut
        elif solo and gr:
            orn = [(order[min(k + 1, len(order) - 1)], 0.03)]
        elif air and not solo and long_ and gr:
            orn = [(order[min(k + 1, len(order) - 1)], 0.04)]   # the air: a cut on the long notes even when plain
        ot = t - sum(o[1] for o in orn)
        for (on, od) in orn:
            ft = fife_tone(2 * tu.freq(on))
            ns = int(od * SR) + int(0.004 * SR)
            seg = ft[int(0.15 * SR):int(0.15 * SR) + ns] * fades(ns, int(0.003 * SR), int(0.004 * SR))
            tr.add(seg * vel * 0.8, ot)
            ot += od
        ns = int(dur * SR)
        start = int(0.12 * SR) if orn else 0
        seg = tone[start:start + ns].copy()
        if len(seg) < ns:                                 # a note longer than the recording: loop its steady part
            body = tone[int(0.5 * SR):int(3.5 * SR)]
            seg = np.concatenate([seg, np.resize(body, ns - len(seg))])
        env = fades(ns, int(0.004 * SR) if orn else 0, int(0.04 * SR) if air else int(0.025 * SR))
        a = int(0.05 * SR)
        if not orn:
            env[:a] *= 1.0 + (0.15 if air else 0.35) * np.linspace(1, 0, a)
        if air and ns > SR // 2:                          # a slow air's long notes: a gentle vibrato in the swell
            tt = np.arange(ns) / SR
            env *= 1.0 + 0.06 * np.clip(tt - 0.4, 0, None) / max(0.4, tt[-1]) * np.sin(2 * np.pi * 5.2 * tt)
        bb = breath(ns, 0.035) * np.exp(-np.arange(ns) / (0.06 * SR))
        tr.add((seg * env + bb) * vel, t)
    on = int((t0 + tu.t(tu.ev[0][0]) - 0.3) * SR)
    y = tr.y
    y[on:] += breath(tu.N - on, 0.006)
    y = hp(y, 300)
    return y + conv(y, room(1.0, 0.15, 9000, 5)) * 0.25


# ------------------------------------------------------------------ drums

DR = os.path.join(SRC, "muldjord_drums")


def layers(folder):
    fs = sorted(os.listdir(os.path.join(DR, folder)), key=lambda f: int(f.split("-")[0]))
    return [load(os.path.join(DR, folder, f)) for f in fs]


class Kit:
    def __init__(self):
        sn = layers("Snare1")
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
        self.bass = []
        for x in layers("KdrumL"):
            y = shift(x, 2 ** (-5 / 12))
            y = lp(y, 1400, 2)
            y = peq(y, 70, 3.0, 0.9)
            self.bass.append(y[:int(1.6 * SR)])
        # the muffled bass of the slow air: a cloth on the head (duller, shorter)
        self.muffled = [lp(x, 500, 2)[:int(0.9 * SR)] * np.exp(-np.arange(int(0.9 * SR)) / (0.25 * SR))[:len(x[:int(0.9 * SR)])]
                        for x in self.bass]
        self.tenor = [peq(lp(shift(x, 2 ** (3 / 12)), 5000), 180, 3.0)[:int(1.4 * SR)] for x in layers("Tom4")]
        # snares off (the slow air's soft rolls): the tenor drum's head, higher and shorter
        self.soft = [lp(shift(x, 2 ** (7 / 12)), 3500)[:int(0.6 * SR)] for x in layers("Tom4")]
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
    return b * np.exp(-np.arange(n) / (0.035 * SR)) * 0.12 * vel


_KIT = None


def kit():
    global _KIT
    if _KIT is None:
        _KIT = Kit()
    _KIT.last = {}
    return _KIT


def play_snare(k, buf, s, t_of, six, lvl):
    """The snare string s (one character a sixteenth) into buf; t_of(i) = the time of sixteenth i."""
    hand = [0]

    def stroke(t, v):
        v = float(np.clip(v * (1 + rng.normal(0, 0.05)), 0.03, 1.0))
        t += jit(3)
        buf.add(k.hit("snare", v), t)
        buf.add(wire(v), t)
        hand[0] ^= 1

    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        t = t_of(i)
        if c in "FADtg":
            v = {"F": 0.88, "A": 0.82, "D": 0.86, "t": 0.46, "g": 0.24}[c] * lvl
            v *= 1.0 if hand[0] == 0 else 0.93
            if c == "F":
                stroke(t - 0.026, 0.22 * lvl)
            if c == "D":
                stroke(t - 0.062, 0.26 * lvl)
                stroke(t - 0.040, 0.24 * lvl)
            stroke(t, v)
        elif c in "RSN":
            strokes, span = {"R": (4, 1), "S": (6, 2), "N": (8, 3)}[c]
            span = span * six
            for kk in range(strokes):
                vv = (0.30 + 0.22 * kk / strokes) * lvl * (1.0 if kk % 2 == 0 else 0.86)
                stroke(t - span + kk * span / strokes, vv)
            stroke(t, 0.84 * lvl)
        elif c == "z":
            j = i + 1
            while j < n and s[j] == "-":
                j += 1
            end = t_of(j)
            step = 0.05                            # a buzz stroke every 50 ms, each pressed into the head
            m = int((end - t) / step)
            for kk in range(m):
                tk = t + kk * step
                vv = (0.26 + 0.34 * kk / max(1, m)) * lvl * (1.0 if kk % 2 == 0 else 0.88)
                stroke(tk, vv)
                stroke(tk + 0.012, vv * 0.38)
                stroke(tk + 0.024, vv * 0.16)
            i = j
            continue
        i += 1


def render_drums(tu, solo):
    k = kit()
    sn, bd, tn, cy = Buf(tu.N), Buf(tu.N), Buf(tu.N), Buf(tu.N)
    six = tu.six
    lvl = 1.0 if solo else 0.8
    t0 = tu.roll_s
    nroll = ROLL_BARS[tu.id] * tu.grid
    if tu.kind == "air":
        return render_drums_air(tu, solo, k, t0)
    roll, s, bass, tenor, cym = score_of(tu, solo)
    whole = roll + s
    play_snare(k, sn, whole, lambda i: (i - nroll) * six + t0, six, lvl)
    # the roll-off's bass: on each roll's accent
    for i, c in enumerate(roll):
        if c == "A":
            bd.add(k.hit("bass", 0.75 * lvl), (i - nroll) * six + t0 + jit(3))
    for p, v in bass.items():
        bd.add(k.hit("bass", v * lvl * (1 + rng.normal(0, 0.04))), t0 + p * six + jit(3))
    for p, v in tenor.items():
        tn.add(k.hit("tenor", v * (1 + rng.normal(0, 0.05))), t0 + p * six + jit(4))
    for p in cym:
        cy.add(k.hit("crash", 0.55) * 0.55, t0 + p * six + jit(2))
    s_ = sn.y + conv(sn.y, room(0.6, 0.07, 9000, 11)) * 0.22
    bdy = bd.y + conv(bd.y, room(2.0, 0.28, 2500, 12)) * 0.35
    tny = tn.y + conv(tn.y, room(1.5, 0.2, 4000, 13)) * 0.3
    return s_ + bdy * (0.9 if solo else 1.0) + tny * 0.55 + cy.y * 0.35


def render_drums_air(tu, solo, k, t0):
    """The slow air: no snare beating. A muffled bass drum on beat 1 of every bar (and softly on 3 in the solo), a soft
    roll (snares off) swelling over the last two beats of each phrase into the next; the roll-off one soft roll."""
    six = tu.six
    bd, sf_ = Buf(tu.N), Buf(tu.N)
    lvl = 1.0 if solo else 0.85

    def soft_roll(a, b, v0, v1):
        step = 0.055
        m = int((b - a) / step)
        for kk in range(m):
            v = (v0 + (v1 - v0) * kk / max(1, m)) * lvl * (1.0 if kk % 2 == 0 else 0.85)
            sf_.add(k.hit("soft", v), a + kk * step + jit(4))
    first = t0 + tu.t(tu.ev[0][0])
    soft_roll(0.05, first - 0.05, 0.12, 0.42)
    bd.add(k.hit("muffled", 0.6 * lvl), first - tu.t(4) + jit(3))
    for b in range(tu.n_bars):
        bt = t0 + tu.t(b * tu.grid)
        bd.add(k.hit("muffled", (0.7 if b % 4 == 0 else 0.55) * lvl), bt + jit(4))
        if solo:
            bd.add(k.hit("muffled", 0.35), bt + tu.t(8) + jit(4))
            if b % 2 == 1:
                sf_.add(k.hit("soft", 0.3), bt + tu.t(12) + jit(4))
        if b % 4 == 3 and b + 1 < tu.n_bars:
            soft_roll(bt + tu.t(8), bt + tu.t(16) - 0.03, 0.12, 0.40 if solo else 0.32)
    bdy = bd.y + conv(bd.y, room(2.0, 0.3, 2000, 12)) * 0.4
    sfy = sf_.y + conv(sf_.y, room(1.4, 0.2, 4000, 13)) * 0.35
    return bdy + sfy * 0.8


# ------------------------------------------------------------------ levels and files

def limit(y, ceil=0.97):
    """A soft limiter with 3 ms look-ahead: the gain follows the peaks (down before them, ~60 ms back up), so a drum
    stroke is turned down for a moment instead of being clipped."""
    from scipy.ndimage import maximum_filter1d, minimum_filter1d
    la = int(0.003 * SR)
    pk = maximum_filter1d(np.abs(y), size=2 * la + 1)
    want = np.minimum(1.0, ceil * 0.95 / np.maximum(pk, 1e-9))
    g = minimum_filter1d(want, size=4 * la + 1)
    b, a = signal.butter(1, 1.0 / (0.06 * SR * np.pi), "low")
    g = np.minimum(g, signal.filtfilt(b, a, g))
    return np.clip(y * g, -ceil, ceil)


def level_to(y, target):
    y = y * 10 ** ((target - lufs(y)) / 20)
    if np.abs(y).max() > 0.97:
        y = limit(y)
        y = y * 10 ** ((target - lufs(y)) / 20)
        y = np.clip(y, -0.985, 0.985)
    return y


def decode(path, sr=SR):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(sr), "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(float)


def write_ogg(path, y, q=3):
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), path], input=y.astype(np.float32).tobytes(), check=True)


def write_mp3(path, y, stereo=False, rate="96k"):
    ch = 2 if stereo else 1
    pk = np.abs(y).max()
    if pk > 0.98:
        y = y * 0.98 / pk
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", str(ch), "-i", "-",
                    "-c:a", "libmp3lame", "-b:a", rate, path], input=y.astype(np.float32).tobytes(), check=True)


def db(x):
    return 10 ** (x / 20)


def prepare(tu):
    """The file's timeline: the roll-off, the tune, a tail; N samples."""
    tu.roll_s = ROLL_BARS[tu.id] * tu.grid * tu.six
    end = tu.roll_s + tu.t(max(e[0] + e[1] for e in tu.ev))
    tu.N = int(round((end + 0.9) * SR))
    tu.length = tu.N / SR
    # phrase ends (4 bars; the slow air and the anthem too): where the band may change tune early
    # (at a phrase's pick-up, if it has one: the cut comes before the next phrase's first note)
    tu.phrases = []
    for b in range(4, tu.n_bars, 4):
        at = b * tu.grid
        pick = [e[0] for e in tu.ev if at - tu.pickup <= e[0] < at]
        tu.phrases.append(round(tu.roll_s + tu.t(min(pick) if pick else at), 4))
    return tu


PARTS = ["drums", "fife", "pipes"]


def main():
    docs = "--no-docs" not in sys.argv
    os.makedirs(OUT, exist_ok=True)
    tunes = {k: prepare(v) for k, v in all_tunes().items()}
    only = None
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1].split(",")
    if "--docs-only" in sys.argv:
        listening(tunes)
        return
    meta = {}
    for tid, tu in tunes.items():
        meta[tid] = {"title": tu.title, "n": tu.N, "len": round(tu.length, 4), "roll": round(tu.roll_s, 4),
                     "phrases": tu.phrases, "kind": tu.kind, "bpm": tu.bpm,
                     "key": [k for k, v in NAMES.items() if v == (tu.tonic_w + tu.transpose) % 12][0]}
        if only and tid not in only:
            continue
        print("%s: %d bars, %.2f s (roll-off %.2f s), %s" % (tu.title, tu.n_bars, tu.length, tu.roll_s, meta[tid]["key"]))
        for name, fn in (("pipes", render_pipes), ("fife", render_fife), ("drums", render_drums)):
            for solo in (False, True):
                y = fn(tu, solo)[:tu.N]
                tgt = (SOLO_LUFS if solo else ON_LUFS) + PART_LU[name]
                if name == "drums" and tu.kind == "air":
                    tgt += AIR_DRUMS_LU
                y = level_to(y, tgt)
                key = "%s_%s%s" % (tid, name, "_lead" if solo else "")
                write_ogg(os.path.join(OUT, key + ".ogg"), y)
                print("  %-26s %.3f s  %.1f LUFS  peak %.2f" % (key, len(y) / SR, lufs(y), np.abs(y).max()))
    with open(os.path.join(ROOT, "tools", "audio", "band_repertoire.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    if docs:
        listening(tunes)


# ------------------------------------------------------------------ the owner's listening files

QUIET, LEAD, UNDER = -9.0, -3.0, -10.0           # BandSound.QUIET_DB / LEAD_DB / UNDER_DB
MUSIC_VOL, DUCK, DUCK_SOLO = -8.0, -12.0, -16.0   # music.gd VOL, BandSound.DUCK_DB / DUCK_SOLO_DB (a band centred)
MUSIC_SLIDER = 20 * np.log10(0.5)
DUCK_RATE, FADE_RATE = 10.0, 60.0
OLD_QUIET, OLD_LEAD, OLD_UNDER = -15.0, -1.0, -19.0     # before band-repertoire
LISTEN_GAIN = 3.0          # dB added to the listening files of the game's mix (04, 05), all alike


def load_parts(tunes):
    out = {}
    for tid in tunes:
        for p in PARTS:
            for suf in ("", "_lead"):
                k = "%s_%s%s" % (tid, p, suf)
                out[k] = decode(os.path.join(OUT, k + ".ogg"))[:tunes[tid].N]
    return out


def seq(parts, tunes, order, part, start=0.0, secs=50.0, lead_from=None, lead_to=None, lead=False):
    """A part playing a playlist from `start` s into the first tune: secs s of it."""
    y = []
    for tid in order:
        y.append(parts["%s_%s%s" % (tid, part, "_lead" if lead else "")])
    y = np.concatenate(y)
    a = int(start * SR)
    return y[a:a + int(secs * SR)]


def fade_out(y, s=2.0):
    n = min(len(y), int(s * SR))
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


def env_curve(n, points, rate):
    """A level curve (dB) over n samples moving toward targets [(t, dB)] at `rate` dB a second."""
    k = 441
    steps = n // k + 1
    out = np.zeros(steps)
    cur = points[0][1]
    j = 0
    for i in range(steps):
        t = i * k / SR
        while j + 1 < len(points) and points[j + 1][0] <= t:
            j += 1
        want = points[j][1]
        cur += np.clip(want - cur, -rate * k / SR, rate * k / SR)
        out[i] = cur
    return np.interp(np.arange(n) / k, np.arange(steps), db(out))


def listening(tunes):
    os.makedirs(DOCS, exist_ok=True)
    for f in os.listdir(DOCS):
        if f.endswith(".mp3"):
            os.remove(os.path.join(DOCS, f))
    parts = load_parts(tunes)
    out = []

    def put(name, y, what, stereo=False, game=False):
        # to hear: a file of one scene at -18 LUFS; the game's mixes (04, 05) all by the same LISTEN_GAIN, so they
        # compare with each other as the game plays them
        y = y * db(LISTEN_GAIN) if game else y * db(-18.0 - lufs(y))
        write_mp3(os.path.join(DOCS, name + ".mp3"), y, stereo)
        out.append((name, what))
        print("  docs/band_sound/%s.mp3 (%.0f KB)" % (name, os.path.getsize(os.path.join(DOCS, name + ".mp3")) / 1024))

    S = 45.0
    order = ["grenadiers", "scotland", "garryowen", "minstrel"]
    # 1. each lone musician in the background (his always-on part at QUIET_DB), through a tune change
    st = tunes["grenadiers"].length - 15.0
    for p, who in (("drums", "drummer"), ("fife", "fifer"), ("pipes", "piper")):
        y = seq(parts, tunes, order, p, st, S) * db(QUIET)
        put("01_lone_%s_background" % who, fade_out(y),
            "a lone %s playing along (his background part), the end of The British Grenadiers, the "
            "roll-off and into Scotland the Brave" % who)
    # 2. the full band playing along
    y = sum(seq(parts, tunes, order, p, st, S) * db(QUIET) for p in PARTS)
    put("02_full_band_background", fade_out(y), "the full band playing along: the end of The British Grenadiers, "
        "the roll-off, Scotland the Brave")
    # 3. a playlist run across two tune changes: Scotland's end -> Garry Owen -> The Minstrel Boy's beginning
    st2 = tunes["grenadiers"].length + tunes["scotland"].length - 12.0
    y = sum(seq(parts, tunes, order, p, st2, 60.0) * db(QUIET) for p in PARTS)
    put("03_playlist_two_changes", fade_out(y), "the playlist across two tune changes: the end of Scotland the Brave, "
        "the roll-off, all of Garry Owen, the roll-off, the start of The Minstrel Boy")
    # 4. a solo over a tune with the game music under it (the band centred on the screen; the fife solos 15-30 s;
    # the tune does not change: its fife part comes forward, the music goes down further)
    for ins in ("fife", "drums", "pipes"):
        mus = music_bit("crown_battle_7", S)
        n = len(mus)
        sol = lambda t, ins=ins: 15.0 <= t < 30.0
        gm = env_curve(n, [(0, DUCK), (15, DUCK_SOLO), (30, DUCK)], DUCK_RATE) * db(MUSIC_VOL + MUSIC_SLIDER)
        y = mus * gm
        for p in PARTS:
            a = seq(parts, tunes, ["grenadiers"], p, 0.0, S)
            b = seq(parts, tunes, ["grenadiers"], p, 0.0, S, lead=True)
            a = np.pad(a, (0, n - len(a)))
            b = np.pad(b, (0, n - len(b)))
            if p == ins:
                y += a * env_curve(n, [(0, QUIET), (15, -80), (30, QUIET)], FADE_RATE)
                y += b * env_curve(n, [(0, -80), (15, LEAD), (30, -80)], FADE_RATE)
            else:
                y += a * env_curve(n, [(0, QUIET), (15, UNDER), (30, QUIET)], FADE_RATE)
        put("04_%s_solo_over_battle_music" % ins, fade_out(y),
            "The British Grenadiers over the Crown's battle music, the band centred (the music ducked %d dB); the %s "
            "SOLOS from 15 s to 30 s: the same tune, the %s's solo part forward and the music %d dB down, then back"
            % (-DUCK, ins, ins, -DUCK_SOLO), game=True)
    # 5. the same scene before and after the rebalance: the full band playing along over the battle music
    old = {}
    for k in ("drums", "fife", "pipes"):
        p = os.path.join("/tmp", "old_band_%s.ogg" % k)
        r = subprocess.run(["git", "-C", ROOT, "show", "%s:assets/audio/band/%s.ogg" % (OLD_REV, k)], capture_output=True)
        if r.returncode == 0:
            open(p, "wb").write(r.stdout)
            old[k] = decode(p)
    if old:
        mus = music_bit("crown_battle_7", S)
        n = len(mus)
        bm = mus * db(MUSIC_VOL + MUSIC_SLIDER + DUCK)
        yo = bm + sum(np.resize(old[p], n) * db(OLD_QUIET) for p in PARTS)
        put("05a_BEFORE_full_band_over_battle_music", fade_out(yo),
            "BEFORE (0.37.5): the full band playing along over the Crown's battle music: the drums and the fife barely heard",
            game=True)
        lone_d = mus * db(MUSIC_VOL + MUSIC_SLIDER + DUCK) + np.resize(old["drums"], n) * db(OLD_QUIET)
        put("05b_BEFORE_lone_drummer_over_battle_music", fade_out(lone_d),
            "BEFORE (0.37.5): a lone Drummer over the Crown's battle music: next to nothing", game=True)
        yn = bm + sum(np.resize(parts["scotland_%s" % p], n) * db(QUIET) for p in PARTS)
        put("05c_AFTER_full_band_over_battle_music", fade_out(yn),
            "AFTER: the same scene now (Scotland the Brave): the snare and the fife's tune clear, the pipes a little back",
            game=True)
        lone_n = mus * db(MUSIC_VOL + MUSIC_SLIDER + DUCK) + np.resize(parts["scotland_drums"], n) * db(QUIET)
        put("05d_AFTER_lone_drummer_over_battle_music", fade_out(lone_n),
            "AFTER: a lone Drummer over the battle music: his background beating", game=True)
    # 6. every tune, the full band with each solo once (a short taste of each)
    for tid in ("grenadiers", "garryowen", "minstrel", "godsave"):
        tu = tunes[tid]
        n = tu.N
        y = sum(parts["%s_%s" % (tid, p)] * db(QUIET) for p in PARTS)
        put("06_%s_full_band" % tid, fade_out(y[:int(min(S + 15, tu.length) * SR)]),
            "%s, the full band playing along (%s, %s)" % (tu.title, "%g a minute" % tu.bpm, tu.kind))
    with open(os.path.join(DOCS, "LIST.txt"), "w") as fh:
        for name, what in out:
            fh.write("%s.mp3  %s\n" % (name, what))


OLD_REV = "f015e851"     # main with band-music-v2 (0.37.5), before band-repertoire

if __name__ == "__main__":
    main()
