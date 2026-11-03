"""Recruit bites for the Crown, one voice per building (all from the user's real recordings):
town hall = the bugle call Reunir (made by bugle_sampler: trained_1), Barracks = a short fife
phrase, Foundry = kettledrum strokes cut from the timpani solo. Output: assets/voice/crown_recruit/.

Run:  python3 tools/audio/make_recruit.py [barracks|foundry ...]   (no name: all of them)
      python3 tools/audio/make_recruit.py compare   (docs/sounds_compare/flute/: cadence_a, cadence_b, current .ogg)

THE BARRACKS' LAST NOTE (owner, 2026-11-03: "the end of the flute sound when recruiting in the barracks"): the
phrase ended on a D held three beats, but the sampler's D (fife/notes/74.wav) is only 0.6 s and has the band's drum
under it, so fife_sampler.note() looped a 0.3 s piece of it five times (a stuttering tok-tok-tok under the note) and
stopped it with an 80 ms fade. 0.26.5 made the last D a REAL held D from the same recording (fife_music.mp3 96.56 s,
1.06 s of the fife alone, no drum), faded out over its last 0.45 s, and took the drum's 50-60 Hz thump off the whole
phrase (highpass 330 Hz; the fife's lowest note is 466 Hz).

THE BARRACKS' CADENCE (owner, 2026-11-03: "I like it ends with the fife. I just don't like the way it ends; I would
like it to end similar to a tune ending"): the phrase is in B flat (a B flat fife): F, B flat, C, D = 5, 1, 2, 3 of
the scale, and stopping on the 3 (D) sounds like a question. Both endings walk home to B flat (1); every new note is a
real drum-free note of the fifer's solo passage in fife_music.mp3 (pitch-tracked, see CLEAN), none pitch-shifted:
  a     D. C | B flat: the D cut to three quarters of a beat, a quick C, then B flat on the next beat, held, with one
        snare stroke on it (drums1.mp3 2.02 s, a stroke with a full second of quiet after it). IN THE GAME (0.26.9).
  b     the fifer's own ending: after the C, his E flat - D - B flat exactly as he played it (126.25-127.47 s: a little
        turn, then down home), no drum, the fife alone.
  held  the ending before (the long D): docs/sounds_compare/flute/current.ogg.
The new endings get a small room's echo (0.7 s) so the last note dies away instead of stopping; the start (F B C) is
the same as before."""
import os, subprocess, sys
import numpy as np
from scipy.signal import butter, lfilter
sys.path.insert(0, os.path.dirname(__file__))
import fife_sampler as FS
ROOT = FS.ROOT
OUT = os.path.join(ROOT, "assets", "voice", "crown_recruit")
SR = FS.SR
FIFE_REC = os.path.join(ROOT, "art", "audio_src", "brood", "fife_music.mp3")   # (the fife sampler's own recording)
HELD_D = (96.56, 1.06)          # a clean held D in it (measured: 580 Hz all through, nothing under 300 Hz)
# the fifer's solo passage (114-128 s, no drum: under 1% of the sound below 300 Hz), pitch-tracked: (start s, length s)
CLEAN = {"C": (114.975, 0.20),          # C (523 Hz, midi 72.0-72.2)
         "Bb": (126.955, 0.52),         # B flat (468 Hz, midi 70.2), ending in his own release at 127.45
         "turn": (126.25, 0.705)}       # E flat (midi 75.3) 126.26-126.42, then D (74.0) to 126.92, up to his B flat
DRUM_TAP = (os.path.join(ROOT, "art", "audio_src", "marching", "drums1.mp3"), 2.02, 0.7)   # one snare stroke


def save(name, x, path=None):
    os.makedirs(OUT, exist_ok=True)
    x = x / (np.abs(x).max() + 1e-9) * 0.7
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-ac", "2",
                    path or os.path.join(OUT, name + ".wav")], input=x.astype(np.float32).tobytes(), check=True)


def rec(src, start, length):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-ss", str(start), "-t", str(length), "-i", src, "-f", "f32le",
                          "-ar", str(SR), "-ac", "1", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(float)


def held(start, length, release):
    """A held note cut from the recording, levelled as the sampler levels its notes, a soft start and a long,
    curved release that ends at silence (no loop, no click)."""
    x = rec(FIFE_REC, start, length)
    x = x / (np.sqrt((x[int(0.1 * SR):int(0.3 * SR)] ** 2).mean()) + 1e-9) * 0.12
    fi = int(0.015 * SR)
    x[:fi] *= np.linspace(0, 1, fi)
    fo = int(release * SR)
    x[-fo:] *= np.cos(np.linspace(0, np.pi / 2, fo)) ** 2
    return x


def level(x, a=0.05, b=0.05, to=0.12 * 0.7):
    """A drum-free piece to the loudness of the held D (the sampler's 0.12, 3 dB down): the RMS of its middle."""
    mid = x[int(a * SR):len(x) - int(b * SR)]
    return x / (np.sqrt((mid ** 2).mean()) + 1e-9) * to


def fades(x, fin=0.01, fout=0.04):
    x = x.copy()
    x[:int(fin * SR)] *= np.linspace(0, 1, int(fin * SR))
    fo = int(fout * SR)
    x[-fo:] *= np.cos(np.linspace(0, np.pi / 2, fo)) ** 2
    return x


def splice(a, b, xf=0.08):
    """a then b, crossfaded over xf s; b slides by up to one period of the note so the two waves line up."""
    n = int(xf * SR)
    tail = a[-n:]
    best = max(range(0, 80), key=lambda s: float(np.dot(tail, b[s:s + n])))
    b = b[best:]
    f = np.linspace(0, np.pi / 2, n)
    return np.concatenate([a[:-n], tail * np.cos(f) + b[:n] * np.sin(f), b[n:]])


def long_bb():
    """The B flat held a little longer: its first 0.30 s, then (one join, not a loop) the rest from 0.10 s on with
    his release, so 0.12 s of a steady, drum-free note is heard twice (0.64 s in all)."""
    s, n = CLEAN["Bb"]
    return splice(rec(FIFE_REC, s, 0.30), rec(FIFE_REC, s + 0.10, n - 0.10))


def room(x, rt=0.7, wet=0.22):
    """A small room's echo (noise dying away over rt s, darkened): the last note rings on after it stops."""
    rng = np.random.default_rng(7)
    n = int(rt * SR)
    ir = rng.standard_normal(n) * np.exp(-6.9 * np.arange(n) / n)
    ir = lfilter(*butter(2, 2500 / (SR / 2)), ir)
    ir[:int(0.012 * SR)] = 0                                # (the first echo 12 ms after the sound)
    ir /= np.sqrt((ir ** 2).sum())
    return np.concatenate([x, np.zeros(n - 1)]) + wet * np.convolve(x, ir)


def drum_tap():
    path, s, n = DRUM_TAP
    x = rec(path, s, n)
    x = lfilter(*butter(2, 120 / (SR / 2), "high"), x)
    x[-int(0.25 * SR):] *= np.cos(np.linspace(0, np.pi / 2, int(0.25 * SR))) ** 2
    return x / (np.abs(x).max() + 1e-9)


def ending(kind, beat):
    """The phrase from its 4th note on (beat 3): (sound, snare stroke at s from there, or None)."""
    if kind == "held":                                     # (0.26.5 to 0.26.8: the long D)
        return held(HELD_D[0], HELD_D[1], 0.45) * 0.7, None
    if kind == "a":                                        # D. C | B flat, a snare stroke on the B flat
        d = held(HELD_D[0], 0.75 * beat + 0.04, 0.05) * 0.7
        c = fades(level(rec(FIFE_REC, *CLEAN["C"]), 0.03, 0.03), 0.008, 0.04)
        bb = fades(level(long_bb(), 0.05, 0.12), 0.012, 0.03)
        out = np.zeros(int(beat * SR) + len(bb))
        for at, x in [(0.0, d), (0.75 * beat, c), (beat, bb)]:
            o = int(at * SR)
            out[o:o + len(x)] += x[:len(out) - o]
        return out, beat
    if kind == "b":                                        # his own E flat - D - B flat, as he played it
        x = rec(FIFE_REC, CLEAN["turn"][0], CLEAN["turn"][1] + CLEAN["Bb"][1])
        return fades(level(x, 0.2, 0.2), 0.012, 0.03), None
    raise ValueError(kind)


def barracks(end="a"):
    B, C, F = FS.B, FS.C, FS.F
    beat = 60.0 / 96
    head = [(F, 1), (B, 1), (C, 1)]                       # the phrase's start, F B C, as before; then the ending
    tail, tap = ending(end, beat)
    if end != "held":
        tail = room(tail)
    out = np.zeros(int(3 * beat * SR) + len(tail) + int(0.2 * SR))
    t = 0.0
    for m, d in head:
        x = FS.note(m, d * beat * 0.92)
        o = int(t * SR)
        out[o:o + len(x)] += x[:len(out) - o]
        t += d * beat
    o = int(t * SR)
    out[o:o + len(tail)] += tail       # (the drum-free notes sit 3 dB down, as loud as the fife in the other notes)
    out = lfilter(*butter(4, 330 / (SR / 2), "high"), out)          # (the drum's thump and hum under the fife)
    out = lfilter(*butter(2, 3200 / (SR / 2)), out) * 0.9             # (as before: the fife's breathy top softened)
    if tap is not None:                                    # (after the filters: the stroke keeps its body and snap)
        x = drum_tap() * np.abs(out).max() * 0.55
        o = int((t + tap) * SR)
        out[o:o + len(x)] += x[:len(out) - o]
    last = np.where(np.abs(out) > np.abs(out).max() * 0.003)[0][-1] + 1
    out = out[:last]
    out[-int(0.02 * SR):] *= np.linspace(1, 0, int(0.02 * SR))       # (ends at exact silence)
    return out


def foundry():
    src = os.path.join(ROOT, "art", "audio_src", "orchestra", "timpani_solo_clean.ogg")
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", src, "-t", "8", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-"],
                         capture_output=True).stdout
    t = np.frombuffer(raw, np.float32)
    env = np.convolve(np.abs(t), np.ones(320) / 320, "same")
    on = np.where(env > env.max() * 0.5)[0][0] - int(0.03 * SR)
    seg = t[max(on, 0): max(on, 0) + int(1.9 * SR)].copy()
    seg[-int(0.6 * SR):] *= np.linspace(1, 0, int(0.6 * SR))
    return seg


SOUNDS = {"barracks_1": barracks, "foundry_1": foundry}      # (town_hall_1: make_bugle.py; horse_breeder_1: make_breeder_select.py)


def compare():
    """docs/sounds_compare/flute/: the two cadences and the ending before them, as .ogg."""
    d = os.path.join(ROOT, "docs", "sounds_compare", "flute")
    for name, end in [("cadence_a", "a"), ("cadence_b", "b"), ("current", "held")]:
        x = barracks(end)
        x = x / (np.abs(x).max() + 1e-9) * 0.7
        subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-c:a",
                        "libvorbis", "-q:a", "6", os.path.join(d, name + ".ogg")],
                       input=x.astype(np.float32).tobytes(), check=True)
        print("%-12s %.2f s" % (name, len(x) / SR))


def main(only):
    if only == ["compare"]:
        return compare()
    for name, f in SOUNDS.items():
        if only and not any(o in name for o in only):
            continue
        x = f()
        save(name, x)
        print("%-12s %.2f s" % (name, len(x) / SR))


if __name__ == "__main__":
    main(sys.argv[1:])
