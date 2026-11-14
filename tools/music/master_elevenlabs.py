"""Master the owner's ElevenLabs Music pieces for the game (job music-elevenlabs).

Usage: python3 tools/music/master_elevenlabs.py [stem ...]      (no stems = all twelve + the menu theme)
       python3 tools/music/master_elevenlabs.py --report OUT.json  (also measure before/after with study_audio)

Sources: art/audio_src/music_elevenlabs/*.mp3 (untouched downloads). Output: assets/music/<stem>.ogg (Vorbis, 44.1 kHz,
-q:a 4). The chain, per piece (one line each in PIECES below):
  1. trim the leading silence (below -50 dBFS; 30 ms kept) and the trailing silence (below -60 dBFS; 0.5 s kept);
  2. a high-pass (2nd order Butterworth run forward and back, so 4th order with no phase shift) at `hp` Hz;
  3. a gentle low-shelf at 100 Hz, stepped down 0.5 dB at a time (to -6 dB at most) until the energy share below
     80 Hz is at most `sub` (the study's band share: 20-80 Hz of 20 Hz-16 kHz); nothing when it is already under;
  4. optional "air": a high-shelf of `air` dB at `air_hz` (3.5 kHz unless given; the dull Brood calm piece);
  5. a fade-out of `fade` seconds; "auto" fades 2.5 s only when the piece stops abruptly (its last 0.3 s within
     12 dB of its body), a real final chord that dies away is left alone;
  6. a gain to the game's loudness (TARGET, the median of the 73 generated pieces, measured by the study) but never
     more than MAX_LIMIT dB (or the piece's `limit`) above what the true-peak ceiling allows: a dynamic piece stays quieter rather than
     being squashed; then a look-ahead true-peak limiter (4x oversampled peaks, 40 ms hold, 20 ms smoothing) to the
     ceiling. No compressor: the loudness range is kept;
  7. encode, decode and measure the true peak again; if Vorbis pushed it over -1 dBTP the ceiling drops by the excess
     and the piece is made again.
Needs ffmpeg, numpy, scipy, pyloudnorm (and librosa for --report).
"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy.ndimage import minimum_filter1d, uniform_filter1d
from scipy.signal import butter, lfilter, resample_poly, sosfiltfilt

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "audio_src", "music_elevenlabs")
OUT = os.path.join(ROOT, "assets", "music")
SR = 44100
TARGET = -12.8        # LUFS: the generated pieces' median (docs/music_study/audio.json, 73 pieces)
CEILING = -1.3        # dBTP before Vorbis; the check after encoding wants <= -1.0
TP_MAX = -1.0
MAX_LIMIT = 3.0       # dB of peak limiting allowed at most to reach TARGET
QUALITY = 4

# stem, source file, title, where it plays, settings
PIECES = [
    ("crown_battle_12", "Campaign_of_the_Crown", "Campaign of the Crown", "Crown opening", dict(hp=35, sub=0.25)),
    ("crown_battle_13", "Musketeer_Charge", "Musketeer Charge", "Crown skirmish", dict(hp=35, sub=0.25)),
    ("crown_battle_14", "March_of_the_Iron_Standard", "March of the Iron Standard", "Crown full battle",
     dict(hp=35, sub=0.25)),
    ("crown_peace_10", "Dawn_Over_the_Colony", "Dawn Over the Colony", "Crown calm", dict(hp=35, sub=0.25)),
    ("clock_battle_14", "Clockwork_Awakening", "Clockwork Awakening", "Clockwork opening", dict(hp=35, sub=0.25)),
    ("clock_battle_15", "Clockwork_Skirmish", "Clockwork Skirmish", "Clockwork skirmish",
     dict(hp=35, sub=0.25, limit=5.0)),      # (its peaks are clicks and ticks: 5 dB of limiting leaves the LRA alone)
    ("clock_battle_16", "Forge_Of_Iron_Command", "Forge of Iron Command", "Clockwork full battle",
     dict(hp=35, sub=0.25)),
    ("clock_peace_8", "Clockmakers_Waltz", "Clockmaker's Waltz", "Clockwork calm", dict(hp=35, sub=0.25)),
    ("brood_battle_14", "Swamp_Queen_Awakening", "Swamp Queen Awakening", "Brood opening", dict(hp=38, sub=0.25)),
    ("brood_battle_15", "Swamp_Hunt_Frenzy", "Swamp Hunt Frenzy", "Brood skirmish", dict(hp=38, sub=0.25)),
    ("brood_battle_16", "Stampede_of_the_Ancients", "Stampede of the Ancients", "Brood full battle",
     dict(hp=38, sub=0.25)),
    ("brood_peace_8", "Swamp_After_Dark", "Swamp After Dark", "Brood calm", dict(hp=38, sub=0.25, air=3.0, air_hz=1500)),
    ("menu_11", "Crown_Of_Ashes", "Crown of Ashes", "main menu (heard first)", dict(hp=38, sub=0.25)),
]


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def db(v):
    return 20 * np.log10(np.maximum(v, 1e-12))


def lufs(x):
    import pyloudnorm as pyln
    return float(pyln.Meter(SR).integrated_loudness(x))


def true_peak(x):
    return float(db(np.max(np.abs(resample_poly(x, 4, 1, axis=0)))))


def sub_share(x):
    mono = x.mean(1)
    nfft = 8192
    P = np.zeros(nfft // 2 + 1)
    for i in range(0, len(mono) - nfft, nfft * 4):
        P += np.abs(np.fft.rfft(mono[i:i + nfft] * np.hanning(nfft))) ** 2
    fr = np.fft.rfftfreq(nfft, 1 / SR)
    return float(P[(fr >= 20) & (fr < 80)].sum() / (P[(fr >= 20) & (fr < 16000)].sum() + 1e-12))


def shelf(x, f0, gain_db, kind, q=0.707):
    """RBJ cookbook shelf (kind "low" / "high")."""
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f0 / SR
    al = np.sin(w) / (2 * q)
    c = np.cos(w)
    s = 2 * np.sqrt(A) * al
    if kind == "low":
        b = [A * ((A + 1) - (A - 1) * c + s), 2 * A * ((A - 1) - (A + 1) * c), A * ((A + 1) - (A - 1) * c - s)]
        a = [(A + 1) + (A - 1) * c + s, -2 * ((A - 1) + (A + 1) * c), (A + 1) + (A - 1) * c - s]
    else:
        b = [A * ((A + 1) + (A - 1) * c + s), -2 * A * ((A - 1) + (A + 1) * c), A * ((A + 1) + (A - 1) * c - s)]
        a = [(A + 1) - (A - 1) * c + s, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - s]
    return lfilter(np.array(b) / a[0], np.array(a) / a[0], x, axis=0)


def trim(x):
    m = np.max(np.abs(x), 1)
    on = np.where(m > 10 ** (-50 / 20))[0]
    a = max(0, on[0] - int(0.03 * SR)) if len(on) else 0
    on2 = np.where(m > 10 ** (-60 / 20))[0]
    b = min(len(x), on2[-1] + int(0.5 * SR)) if len(on2) else len(x)
    return x[a:b], a / SR, (len(x) - b) / SR


def abrupt(x):
    body = np.sqrt(np.mean(x ** 2))
    end = np.sqrt(np.mean(x[-int(0.3 * SR):] ** 2))
    return float(db(end) - db(body))


def limit(x, ceiling_db):
    c = 10 ** (ceiling_db / 20)
    up = np.abs(resample_poly(x, 4, 1, axis=0)).max(1)
    pk = up[: len(x) * 4].reshape(-1, 4).max(1)
    if len(pk) < len(x):
        pk = np.pad(pk, (0, len(x) - len(pk)))
    need = np.minimum(1.0, c / np.maximum(pk, 1e-12))
    hold, smooth = int(0.04 * SR), int(0.02 * SR)
    g = minimum_filter1d(need, size=hold + smooth, mode="nearest")
    g = uniform_filter1d(g, size=smooth, mode="nearest")
    return x * g[:, None], float(-db(g.min()))


def encode(x, path):
    pcm = np.clip(x, -1, 1).astype(np.float32).tobytes()
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(QUALITY), path], input=pcm, check=True)


def master(stem, src, s):
    x = load(os.path.join(SRC, src + ".mp3"))
    info = {"stem": stem}
    x, info["lead_trim_s"], info["tail_trim_s"] = trim(x)
    sos = butter(2, s.get("hp", 35), btype="highpass", fs=SR, output="sos")
    x = sosfiltfilt(sos, x, axis=0)
    shelf_db = 0.0
    if sub_share(x) > s.get("sub", 0.25):
        base = x
        while shelf_db > -6.0 and sub_share(x) > s.get("sub", 0.25):
            shelf_db -= 0.5
            x = shelf(base, 100, shelf_db, "low")
    info["low_shelf_db"] = shelf_db
    if s.get("air"):
        x = shelf(x, s.get("air_hz", 3500), s["air"], "high")
        info["air_db"] = s["air"]
    fade = s.get("fade", "auto")
    end_db = abrupt(x)
    info["end_vs_body_db"] = round(end_db, 1)
    if fade == "auto":
        fade = 2.5 if end_db > -12 else 0.0
    if fade:
        n = int(fade * SR)
        x[-n:] *= (np.cos(np.linspace(0, np.pi, n)) * 0.5 + 0.5)[:, None]
    info["fade_s"] = fade
    loud, tp = lufs(x), true_peak(x)
    ceiling = CEILING
    for _ in range(5):
        gain = min(TARGET - loud, ceiling - tp + s.get("limit", MAX_LIMIT))
        y, lim = limit(x * 10 ** (gain / 20), ceiling)
        path = os.path.join(OUT, stem + ".ogg")
        encode(y, path)
        z = load(path)
        tp_out = true_peak(z)
        if tp_out <= TP_MAX:
            break
        ceiling -= tp_out - TP_MAX + 0.1
    info.update(gain_db=round(gain, 2), limit_db=round(lim, 2), ceiling_dbtp=round(ceiling, 2),
                lufs_out=round(lufs(z), 2), tp_out=round(tp_out, 2), length_s=round(len(z) / SR, 2))
    return info


def main():
    args = sys.argv[1:]
    report = None
    if "--report" in args:
        i = args.index("--report")
        report = args[i + 1]
        del args[i:i + 2]
    out = {}
    for stem, src, title, where, s in PIECES:
        if args and stem not in args:
            continue
        info = master(stem, src, s)
        info.update(title=title, where=where, source=src + ".mp3")
        print(json.dumps(info))
        if report:
            sys.path.insert(0, os.path.dirname(__file__))
            from study_audio import analyse
            keys = ["length_s", "lufs", "lra", "true_peak_dbtp", "band_sub", "band_low", "band_presence", "band_air",
                    "centroid_hz", "start_rel_db", "end_rel_db", "lead_silence_s", "crest_db"]
            b = analyse(os.path.join(SRC, src + ".mp3"))
            a = analyse(os.path.join(OUT, stem + ".ogg"))
            info["before"] = {k: b.get(k) for k in keys}
            info["after"] = {k: a.get(k) for k in keys}
        out[stem] = info
    if report:
        with open(report, "w") as f:
            json.dump(out, f, indent=1)


if __name__ == "__main__":
    main()
