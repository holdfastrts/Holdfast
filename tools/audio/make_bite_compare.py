"""Brood bites to listen to side by side (owner, 2026-11-03: "The sound of the bites should get better. What was the
previous sound so I can compare?"). Writes docs/sounds_compare/bite/ (.ogg); does NOT touch the game's sounds.

  old_*   the bites before 0.24.6 (git f72c2faf^): the synth slash-and-snap of make_sfx2.py (Raptor) or a creature's
          call over the old synth bite (assets/audio/bite.wav)
  new_*   the bites in the game now (0.24.6 on): tools/audio/make_brood_sounds.py, CHOMPS (the owner's chomping and
          monster-bite recordings)
  cand_*  candidates, cut from the owner's Brood pack (art/audio_src/brood/), each one a row: three Raptor bites, a Grub
          bite, a Tyrant Sire bite (the creature's own growl kept as it is in the game; only the bite under it changes)

Why the bites in the game sound muddy (measured, docs/sounds_compare/README.md):
  - the jaws close LATE: the cuts start before the real snap (the monster bite is cut from 0.44 s, its snap is at
    0.66 s; the chomping take at 1.00 s snaps at 1.13 s and peaks at 1.31 s): raptor_attack_1 peaks 0.23 s in
  - the chomping recording is boxy: 60-75% of its energy is between 300 and 1500 Hz, almost nothing above 3 kHz
Every row is levelled the same (each bite to the same loudness) so only the character differs.

Run:  python3 tools/audio/make_bite_compare.py"""
import os
import subprocess
import sys
import numpy as np
from scipy.signal import butter, sosfilt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_brood_sounds as MB      # noqa: E402  (cut, layer, the recordings)

SR = MB.SR
ROOT = MB.ROOT
OUT = os.path.join(ROOT, "docs", "sounds_compare", "bite")
OLD = "f72c2faf^"     # the commit before the owner's Brood pack went in (0.24.6)

# the sharp snaps in the pack (onsets of the >2 kHz band, measured): (recording, snap at s)
SNAPS = [("chomp", 6.904), ("chomp", 12.476), ("chomp", 21.110), ("chomp", 23.698), ("chomp", 27.906),
         ("mbite", 0.660), ("chomp", 2.892)]
# short dry cracks (egg shells, pitched down they read as bone): (recording, crack at s)
CRACKS = [("egg5", 0.220), ("egg5", 0.410), ("eggc", 1.080), ("egg14", 0.552), ("egg5", 0.578)]


def bp(x, lo, hi):
    return sosfilt(butter(2, [lo, hi], "band", fs=SR, output="sos"), x)


def clean(x):
    """Less mud, more teeth: no rumble under 250 Hz, the boxy 450-1000 Hz half as loud, a lift at 2.5-6 kHz."""
    x = sosfilt(butter(2, 250, "high", fs=SR, output="sos"), x)
    return x - 0.5 * bp(x, 450, 1000) + 0.5 * bp(x, 2500, 6000)


def piece(src, start, length, pitch=1.0, fade=0.06):
    return MB.layer(src, start, length, pitch, fade)


def snap(v, pitch=1.0, length=0.17):
    """A bite cut 8 ms before its snap, short, cleaned."""
    s, t = SNAPS[v % len(SNAPS)]
    return clean(piece(s, t - 0.008, length, pitch, 0.07))


def crack(v, pitch=0.7):
    s, t = CRACKS[v % len(CRACKS)]
    return piece(s, t - 0.004, 0.06, pitch, 0.04)


def mix(parts):
    n = max(int(at * SR) + len(p) for at, p, _ in parts)
    out = np.zeros(n)
    for at, p, g in parts:
        a = int(at * SR)
        out[a:a + len(p)] += p * g
    out = sosfilt(butter(2, 50, "high", fs=SR, output="sos"), out)
    i = max(0, int(np.argmax(np.abs(out) > np.abs(out).max() * 0.05)) - int(0.004 * SR))
    out = out[i:]
    out[:int(0.003 * SR)] *= np.linspace(0, 1, int(0.003 * SR))
    return out / (np.abs(out).max() + 1e-9) * 0.7


# the bite only, three kinds (v: which take; p: pitch)
def bite_a(v, p):        # A, TIGHT SNAP: the crispest bites of the pack, cut right at the snap and cleaned
    return [(0.0, snap(v, p), 1.0)]


def bite_b(v, p):        # B, BONE CRUNCH: A with a dry crack (an egg shell pitched down) at the moment the jaws meet
    return [(0.0, snap(v, p), 1.0), (0.004, crack(v, 0.68 * p), 0.45)]


def bite_c(v, p):        # C, CLACK THEN CRUNCH: the teeth clack first (a short bright crack), the crunch 35 ms after
    return [(0.0, crack(v + 2, 0.9 * p), 0.8), (0.035, snap(v + 3, p * 0.95, 0.2), 1.0)]


def raptor(bite, v, p):  # the Raptor's quick rasp before the bite, as in the game (raspy 0.20 / 1.27 s)
    r = piece("raspy", [0.20, 1.27, 0.20][v % 3], 0.10, 0.9, 0.05)
    return mix([(0.0, r, 0.3)] + [(0.04 + at, x, g) for at, x, g in bite(v, p)])


def grub(bite, v, p):
    return mix(bite(v, p))


def tyrannosaur(bite, v, p):   # the Tyrant Sire's growl as in the game, the bite pitched down under it
    g = piece("tsire", 0.22, 0.32, 0.85, 0.1)
    return mix([(0.0, g, 0.7)] + [(0.03 + at, x, gg) for at, x, gg in bite(v, p)])


CANDS = {"cand_a_tight_snap": bite_a, "cand_b_bone_crunch": bite_b, "cand_c_clack_crunch": bite_c}


def level(x):
    """Each take to the same loudness (RMS of its loudest 50 ms at -14 dBFS), so the rows compare by character."""
    w = int(0.05 * SR)
    loud = max(np.sqrt((x[i:i + w] ** 2).mean()) for i in range(0, max(1, len(x) - w), w // 2))
    y = x * (10 ** (-14 / 20) / (loud + 1e-9))
    return y / max(1.0, np.abs(y).max() / 0.95)


def row(takes, gap=0.45):
    out = [np.zeros(int(0.15 * SR))]
    for x in takes:
        out += [level(x), np.zeros(int(gap * SR))]
    return np.concatenate(out)


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f64le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", p], input=x.astype(np.float64).tobytes(), check=True)
    print("%-40s %.1f s" % (os.path.relpath(p, ROOT), len(x) / SR))


def wav(path, rev=None):
    """A game file (assets/audio/...), as it is now or at a git revision."""
    if rev:
        data = subprocess.run(["git", "-C", ROOT, "show", "%s:%s" % (rev, path)], capture_output=True, check=True).stdout
        cmd = ["ffmpeg", "-v", "quiet", "-i", "-", "-f", "f64le", "-ac", "1", "-ar", str(SR), "-"]
        raw = subprocess.run(cmd, input=data, capture_output=True, check=True).stdout
    else:
        cmd = ["ffmpeg", "-v", "quiet", "-i", os.path.join(ROOT, path), "-f", "f64le", "-ac", "1", "-ar", str(SR), "-"]
        raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float64)


GAME = {"raptor": 3, "grub": 2, "tyrant_challenger": 3, "tyrannosaur": 2, "brute": 2}


def main():
    for kind, n in GAME.items():
        files = ["assets/audio/combat/%s_attack_%d.wav" % (kind, i + 1) for i in range(n)]
        if kind != "grub":          # (the Grub had no bite before 0.24.6)
            write("old_" + kind, row([wav(f, OLD) for f in files]))
        write("new_" + kind, row([wav(f) for f in files]))
    write("old_bite_layer", row([wav("assets/audio/bite.wav")]))
    # candidates: three Raptor takes (different bites, pitches 1.08 / 1.0 / 1.14), a Grub (higher), a Tyrant Sire (lower)
    for name, b in CANDS.items():
        write(name, row([raptor(b, 0, 1.08), raptor(b, 1, 1.0), raptor(b, 2, 1.14), grub(b, 4, 1.4), tyrannosaur(b, 5, 0.75)]))


if __name__ == "__main__":
    main()
