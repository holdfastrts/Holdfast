"""Import the owner's recorded announcers (ElevenLabs, 2026-11-04) into the game.

  art/audio_src/crown_herald/01.mp3 ... 21.mp3      the Crown: a royal herald
  art/audio_src/brood_scientist/01.mp3 ... 21.mp3   the Brood: the campaign's scientist

Each line: mono, leading/trailing silence trimmed (40 ms kept), a short fade in and out, levelled so its loudest
0.3 s matches the median of the Clockwork announcer's (assets/voice/announcer/clock/*.ogg, the same measure
tools/audio/make_mix.py uses), written as Ogg Vorbis to assets/voice/announcer/<crown|brood>/<key>.ogg (replacing
the old Kokoro lines). Then run python3 tools/audio/make_mix.py so scripts/sound_mix.gd has their gains.
The table of keys and texts: docs/announcers.md.

  python3 tools/audio/import_announcers.py            (both)
  python3 tools/audio/import_announcers.py crown      (one faction)
"""
import glob, os, subprocess, sys
import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SR = 44100
KEEP = 0.040          # silence kept before and after the speech (s)
FADE_IN = 0.010
FADE_OUT = 0.040
PEAK_MAX = 0.97       # never clip: a line whose level would push it over is limited to this peak
QUALITY = "4"         # libvorbis -q:a (mono ~80-110 kbps, like the Clockwork lines)

# line number (1-based) -> key; the standard 21 per faction (docs/announcers.md)
STANDARD = ["unit_ready", "building_done", "research_done", "under_attack", "base_attack", "workers_attack",
            "ally_attack", "expansion", "building_lost", "site_lost", "bad_place", "no_gold", "no_res2",
            "no_supply", "depleted", "victory", "defeat", "paused", "resumed"]
SETS = {
    "crown": ("art/audio_src/crown_herald", STANDARD + ["no_powder", "horse_stolen"]),
    "brood": ("art/audio_src/brood_scientist", STANDARD + ["mother_attack", "sire_lost"]),
}


def load(p):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", p, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def loud(x, win=0.3):
    """make_mix.py's measure: the RMS of the loudest `win` seconds (dB)."""
    w = int(SR * win)
    if len(x) <= w:
        return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
    e = [np.sqrt(np.mean(x[i:i + w] ** 2)) for i in range(0, len(x) - w, w // 3)]
    return 20 * np.log10(max(e) + 1e-9)


def trim(x):
    """Cut the silence before and after the speech: 10 ms windows under 40 dB below the loudest (or -60 dBFS)."""
    w = int(SR * 0.010)
    n = len(x) // w
    db = np.array([20 * np.log10(np.sqrt(np.mean(x[i * w:(i + 1) * w] ** 2)) + 1e-9) for i in range(n)])
    thr = max(db.max() - 40.0, -60.0)
    on = np.where(db > thr)[0]
    a = max(0, on[0] * w - int(SR * KEEP))
    b = min(len(x), (on[-1] + 1) * w + int(SR * KEEP))
    return x[a:b].copy()


def fade(x):
    i, o = int(SR * FADE_IN), int(SR * FADE_OUT)
    x[:i] *= np.linspace(0, 1, i)
    x[-o:] *= np.linspace(1, 0, o) ** 2
    return x


def write_ogg(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", QUALITY, path],
                   input=np.clip(x, -1, 1).astype(np.float32).tobytes(), check=True)


def main():
    clock = sorted(glob.glob(os.path.join(ROOT, "assets/voice/announcer/clock/*.ogg")))
    target = float(np.median([loud(load(f)) for f in clock]))
    print("target (median of %d Clockwork lines, loudest 0.3 s): %.1f dB" % (len(clock), target))
    which = sys.argv[1:] or list(SETS)
    for fac in which:
        src, keys = SETS[fac]
        for i, key in enumerate(keys):
            p = os.path.join(ROOT, src, "%02d.mp3" % (i + 1))
            raw = load(p)
            x = fade(trim(raw))
            g = target - loud(x)
            peak = float(np.max(np.abs(x)))
            limited = peak * 10 ** (g / 20) > PEAK_MAX
            if limited:
                g = 20 * np.log10(PEAK_MAX / peak)
            x = x * 10 ** (g / 20)
            out = os.path.join(ROOT, "assets/voice/announcer", fac, key + ".ogg")
            for old in (out[:-4] + ".wav",):
                if os.path.exists(old):
                    os.remove(old)
            write_ogg(out, x)
            print("%s %02d %-15s %.2f s -> %.2f s, gain %+.1f dB%s, now %.1f dB" % (
                fac, i + 1, key, len(raw) / SR, len(x) / SR, g, " (peak-limited)" if limited else "", loud(x)))
    print("now run: python3 tools/audio/make_mix.py")


if __name__ == "__main__":
    main()
