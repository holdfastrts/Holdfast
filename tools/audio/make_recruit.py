"""Recruit bites for the Crown, one voice per building (all from the user's real recordings):
town hall = the bugle call Reunir (made by bugle_sampler: trained_1), Barracks = a short fife
phrase, Foundry = kettledrum strokes cut from the timpani solo. Output: assets/voice/crown_recruit/.

Run:  python3 tools/audio/make_recruit.py [barracks|foundry ...]   (no name: all of them)

THE BARRACKS' LAST NOTE (owner, 2026-11-03: "the end of the flute sound when recruiting in the barracks"): the
phrase ends on a D held three beats, but the sampler's D (fife/notes/74.wav) is only 0.6 s and has the band's drum
under it, so fife_sampler.note() looped a 0.3 s piece of it five times (a stuttering tok-tok-tok under the note) and
stopped it with an 80 ms fade. Now the last D is a REAL held D from the same recording (fife_music.mp3 96.56 s, 1.06 s
of the fife alone, no drum), faded out over its last 0.45 s, and the whole phrase loses the drum's 50-60 Hz thump
(highpass 330 Hz; the fife's lowest note is 466 Hz). Before/after: docs/sounds_compare/flute/."""
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


def barracks():
    B, C, D, F = FS.B, FS.C, FS.D, FS.F
    beat = 60.0 / 96
    head = [(F, 1), (B, 1), (C, 1)]                       # the phrase as before: F B C, then the held D
    out = np.zeros(int((3 * beat + HELD_D[1] + 0.2) * SR))
    t = 0.0
    for m, d in head:
        x = FS.note(m, d * beat * 0.92)
        o = int(t * SR)
        out[o:o + len(x)] += x[:len(out) - o]
        t += d * beat
    x = held(HELD_D[0], HELD_D[1], 0.45)
    o = int(t * SR)
    out[o:o + len(x)] += x * 0.7       # (the drum-free D sits 3 dB down, as loud as the fife in the other notes)
    out = lfilter(*butter(4, 330 / (SR / 2), "high"), out)          # (the drum's thump and hum under the fife)
    out = lfilter(*butter(2, 3200 / (SR / 2)), out) * 0.9             # (as before: the fife's breathy top softened)
    end = np.where(np.abs(out) > np.abs(out).max() * 0.003)[0][-1] + 1
    out = out[:end]
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


def main(only):
    for name, f in SOUNDS.items():
        if only and not any(o in name for o in only):
            continue
        x = f()
        save(name, x)
        print("%-12s %.2f s" % (name, len(x) / SR))


if __name__ == "__main__":
    main(sys.argv[1:])
