"""Music study (job music-study): audio features of every assets/music/*.ogg.

Usage: python3 tools/music/study_audio.py OUT.json [name ...]

Per file: integrated loudness (ITU-R BS.1770 via pyloudnorm, LUFS), short-term loudness over 3 s windows and its
range (95th - 10th percentile, close to EBU's LRA), sample peak and a 4x oversampled true peak, spectral centroid
and spread over time, the energy share in five bands, librosa's beat tracking (tempo, how steady the beats are),
the start and the end (level and spectrum of the first and last 2 s, for the cross-fade into the next piece),
stereo width (side / mid energy, L-R correlation) and a reverb tail estimate (how fast the level falls after
onsets). Nothing is written to assets/.
"""
import json
import os
import subprocess
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MUSIC = os.path.join(ROOT, "assets", "music")
SR = 44100
BANDS = [("sub", 20, 80), ("low", 80, 250), ("lowmid", 250, 600), ("mid", 600, 2000), ("presence", 2000, 5000),
         ("air", 5000, 16000)]


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def db(x):
    return 20 * np.log10(np.maximum(x, 1e-9))


def analyse(path):
    import librosa
    import pyloudnorm as pyln
    from scipy.signal import resample_poly
    x = load(path)
    f = {"length_s": len(x) / SR}
    meter = pyln.Meter(SR)
    f["lufs"] = float(meter.integrated_loudness(x))
    st = []
    w, hop = 3 * SR, SR
    for i in range(0, max(1, len(x) - w), hop):
        v = meter.integrated_loudness(x[i:i + w]) if len(x[i:i + w]) >= int(0.4 * SR) else -70
        st.append(v if np.isfinite(v) else -70.0)
    st = np.array(st)
    gated = st[st > f["lufs"] - 20] if len(st) else st
    f["st_curve"] = [round(float(v), 1) for v in st]
    f["lra"] = float(np.percentile(gated, 95) - np.percentile(gated, 10)) if len(gated) > 3 else 0.0
    f["st_max"] = float(st.max()) if len(st) else 0.0
    f["peak_dbfs"] = float(db(np.max(np.abs(x))))
    up = resample_poly(x[: min(len(x), 60 * SR)], 4, 1, axis=0)
    f["true_peak_dbtp"] = float(db(np.max(np.abs(up))))
    mono = x.mean(1)
    y = librosa.resample(mono.astype(np.float32), orig_sr=SR, target_sr=22050)
    sr = 22050
    S = np.abs(librosa.stft(y, n_fft=2048, hop_length=512))
    freqs = librosa.fft_frequencies(sr=sr, n_fft=2048)
    cen = librosa.feature.spectral_centroid(S=S, sr=sr)[0]
    spr = librosa.feature.spectral_bandwidth(S=S, sr=sr)[0]
    loud = S.sum(0) > np.percentile(S.sum(0), 20)
    f["centroid_hz"] = float(np.median(cen[loud]))
    f["centroid_sd"] = float(np.std(cen[loud]))
    f["spread_hz"] = float(np.median(spr[loud]))
    # band shares from the long-term power spectrum of the full-rate signal
    P = np.zeros(4097)
    nfft = 8192
    for i in range(0, len(mono) - nfft, nfft * 4):
        P += np.abs(np.fft.rfft(mono[i:i + nfft] * np.hanning(nfft))) ** 2
    fr = np.fft.rfftfreq(nfft, 1 / SR)
    tot = P[(fr >= 20) & (fr < 16000)].sum() + 1e-12
    for nm, lo, hi in BANDS:
        f["band_" + nm] = float(P[(fr >= lo) & (fr < hi)].sum() / tot)
    # tilt: dB per octave of the long-term spectrum, 100 Hz - 10 kHz
    sel = (fr > 100) & (fr < 10000)
    f["tilt_db_oct"] = float(np.polyfit(np.log2(fr[sel]), 10 * np.log10(P[sel] + 1e-12), 1)[0])
    # tempo and beat steadiness
    oenv = librosa.onset.onset_strength(y=y, sr=sr)
    tempo, beats = librosa.beat.beat_track(onset_envelope=oenv, sr=sr)
    tempo = float(np.atleast_1d(tempo)[0])
    bt = librosa.frames_to_time(beats, sr=sr)
    ibi = np.diff(bt)
    f["tempo_bpm"] = tempo
    f["beat_cv"] = float(np.std(ibi) / np.mean(ibi)) if len(ibi) > 4 else None
    f["pulse_clarity"] = float(np.max(librosa.autocorrelate(oenv - oenv.mean())[10:200]) /
                               (np.sum((oenv - oenv.mean()) ** 2) + 1e-9))
    f["onsets_per_s"] = float(len(librosa.onset.onset_detect(onset_envelope=oenv, sr=sr)) / (len(y) / sr))
    # the start and the end (the game cross-fades 2.5 s into the next piece)
    def seg_feats(a):
        rms = float(db(np.sqrt(np.mean(a ** 2)) + 1e-12))
        sp = np.abs(np.fft.rfft(a.mean(1)[: 2 * SR] * np.hanning(min(len(a), 2 * SR)), n=2 * SR))
        return rms, sp
    act = np.where(np.abs(mono) > 10 ** (-50 / 20))[0]
    a0, a1 = (act[0], act[-1]) if len(act) else (0, len(mono) - 1)
    r_s, sp_s = seg_feats(x[a0:a0 + 2 * SR])
    r_e, sp_e = seg_feats(x[max(0, a1 - 2 * SR):a1])
    body = float(db(np.sqrt(np.mean(mono ** 2))))
    f["start_rel_db"] = r_s - body
    f["end_rel_db"] = r_e - body
    f["lead_silence_s"] = a0 / SR
    f["tail_s"] = (len(mono) - a1) / SR
    # the last 4 s: how the level falls (a fade, a final chord, or a cut)
    tail = mono[max(0, a1 - 4 * SR):a1]
    if len(tail) > SR:
        env = [db(np.sqrt(np.mean(tail[i:i + SR // 4] ** 2))) for i in range(0, len(tail) - SR // 4, SR // 4)]
        f["end_drop_db"] = float(env[0] - env[-1])
    # stereo
    mid, side = (x[:, 0] + x[:, 1]) / 2, (x[:, 0] - x[:, 1]) / 2
    f["side_mid_db"] = float(10 * np.log10((np.mean(side ** 2) + 1e-12) / (np.mean(mid ** 2) + 1e-12)))
    f["lr_corr"] = float(np.corrcoef(x[:, 0], x[:, 1])[0, 1])
    # reverb: median level fall 50-300 ms after strong onsets, in dB per 100 ms (smaller = wetter)
    ons = librosa.onset.onset_detect(onset_envelope=oenv, sr=sr, units="samples")
    rms = librosa.feature.rms(y=y, frame_length=1024, hop_length=256)[0]
    falls = []
    for o in ons:
        k0 = int(o / 256)
        k1, k2 = k0 + int(0.05 * sr / 256), k0 + int(0.30 * sr / 256)
        if k2 < len(rms) and rms[k0:k1 + 1].max() > np.percentile(rms, 60):
            falls.append((db(rms[k0:k1 + 1].max()) - db(rms[k2])) / 2.5)
    f["decay_db_100ms"] = float(np.median(falls)) if falls else None
    # crest: peak to RMS (low = heavily limited, flat)
    f["crest_db"] = float(db(np.max(np.abs(mono))) - db(np.sqrt(np.mean(mono ** 2))))
    return f


def main():
    out = sys.argv[1]
    names = sys.argv[2:] or sorted(fn[:-4] for fn in os.listdir(MUSIC) if fn.endswith(".ogg"))
    res = {}
    for nm in names:
        res[nm] = analyse(os.path.join(MUSIC, nm + ".ogg"))
        r = res[nm]
        print("%-16s %5.1fs %6.1f LUFS LRA %4.1f tp %5.1f cen %5.0f tempo %5.1f cv %s side %5.1f" % (
            nm, r["length_s"], r["lufs"], r["lra"], r["true_peak_dbtp"], r["centroid_hz"], r["tempo_bpm"],
            "%.3f" % r["beat_cv"] if r["beat_cv"] is not None else "-", r["side_mid_db"]), flush=True)
    json.dump(res, open(out, "w"), indent=0)


if __name__ == "__main__":
    main()
