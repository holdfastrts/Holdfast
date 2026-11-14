"""Music study (job music-study): a short demo rewrite, for the owner to listen to. NOT a game file.

It applies the study's rules (docs/music_study_classical.md) to one of the weakest and most heard pieces,
"The Queen Stirs" (brood_peace_4, the piece that opens Brood matches), in under a minute, and renders the
current piece's first minute next to it for comparison. Both go to docs/music_study/demos/; nothing in assets/
is written and the game's piece is not changed.

Rules applied, with the measured gap each one answers:
  - a dynamic arc: start pp, a layer every 4 bars, the top at about 70% of the piece, then a release
    (the game's median: loudness range 6.9 LU, the top at 94%, 1.9 LU of release);
  - colour outside the mode: a raised fourth leading to the fifth in the counter-line, a major V (F sharp) at the
    half cadences, a chromatic lament bass G-F#-F-E-Eb-D under the second statement (the game's median: 0%);
  - a counter-melody: the horn's slow line against the tune's second statement (the game's median: 0% of bars);
  - a different cadence bar: every 4th bar the drums change (a fill, a held hit or a rest) (the game: 80% of bars
    repeat the bar before);
  - the tune comes back changed: the closing four bars bring its opening back softly, an octave down.

Usage: python3 tools/music/study_demos.py
"""
import os
import subprocess
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import compose as C  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "docs", "music_study", "demos")


def write(name, L, R, seconds=None, q=1):
    os.makedirs(OUT, exist_ok=True)
    if seconds:
        n = int(seconds * C.SR)
        L, R = L[:n].copy(), R[:n].copy()
        f = int(2.5 * C.SR)
        L[-f:] *= np.linspace(1, 0, f)
        R[-f:] *= np.linspace(1, 0, f)
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(C.SR)
        w.writeframes((np.clip(np.stack([L, R], 1), -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(q),
                    os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)
    print(name, "%.1f s" % (len(L) / C.SR))


def queen_stirs_rule():
    s = C.Song("demo_queen_stirs", "The Queen Stirs (study demo)", 88, 4, C.n("G", 3), "dorian", reverb=(3.2, 0.7),
               seed=213, q=1, ceiling=0.8)
    # the same tune as the game's piece (its first eight bars), so the comparison is about the treatment
    A = ["1:2 5:2", "4:1 3:1 4:1 6:1", "5:2 4:1 3:1", "2:2 7,:2",
         "1:2 3:1 5:1", "6:2 4:2", "5:1 4:1 2:1 7,:1", "1:4"]
    # bar 4 ends on a major V (raised 7th, F sharp): a half cadence; bar 8 closes on i
    Ar = [0, 3, 0, 4, 0, 3, 4, 0]
    # the horn's counter-line: long notes moving against the tune, a raised fourth (C sharp) leading to the fifth
    CL = ["3:4", "1:2 2:2", "3:2 4+:2", "5:4", "5:2 4:2", "3:2 4:2", "4+:2 5:2", "3:4"]
    logs = "1:1.5 1:0.5 5,:1 1:1"
    G2 = s.pitch(0) - 12

    def major_v(b, vel):
        # the half-cadence chord with its raised third (D, F sharp, A), held by the choir
        for i, acc in ((4, 0), (6, 1), (8, 0)):
            s.note("choir_u", s.bar(b), 4, s.pitch(i, acc), vel, 0.0, 0.6)

    s.scatter(0, 21, 0, 1, lambda bt, r: s.hit("q", bt, r.uniform(0.2, 0.35), r.uniform(-0.6, 0.6), 0.35), 1.0)
    # bars 0-1: the heartbeat alone, very soft
    for i in range(2):
        s.hit("B", s.bar(i), 0.3 + 0.05 * i)
        s.hit("B", s.bar(i) + 0.6, 0.2 + 0.04 * i)
    s.note("throat", 0, 8, G2, 0.25, 0.0, 0.5)
    b = 2
    # bars 2-9: the tune in the low choir, pp, a log-drum pulse; a new drum bar every 4th bar
    s.rel("throat", b, Ar, "1:4", 0.28, -1, 0.0, 0.4)
    s.rel("log", b, Ar, logs, 0.3, -1, 0.2, 0.25)
    s.drums(b, 4, {"B.......d...d...": 0.0}, 0.3, fill={"B...........B...": 0.0})
    s.drums(b + 4, 4, {"B.......d...d...": 0.0, "x...x...x...x...": -0.4}, 0.34,
            fill={"B.......B.B.B...": 0.0, "x.x.x.x.x.x.x.x.": -0.4})
    major_v(b + 3, 0.22)
    s.mel("choir_u", b, A, 0.42, 0, 0.0, 0.6)
    b += 8
    # bars 10-17: the second statement, louder, the horn's counter-line, a chromatic lament bass under the first half
    lament = [0, -1, -2, -3]           # G, F sharp, F, E in semitones below the tonic, one a bar
    for i, d in enumerate(lament):
        s.note("throat", s.bar(b + i), 4, G2 + d, 0.42 + 0.03 * i, 0.0, 0.4)
        s.note("lowstr", s.bar(b + i), 4, G2 + d - 12, 0.4 + 0.04 * i, 0.15, 0.3)
    s.rel("throat", b + 4, Ar[4:], "1:4", 0.48, -1, 0.0, 0.4)
    s.rel("log", b, Ar, logs, 0.45, -1, 0.2, 0.25)
    s.drums(b, 4, {"B.......B...d.d.": 0.0, "..t...t...t...t.": 0.4}, 0.44,
            fill={"B...B...B.B.BBBB": 0.0, "..t...t...tttttt": 0.4})
    s.drums(b + 4, 4, {"D...d...D.d.d...": 0.0, "..t...t...t..tt.": 0.4, "x.xxx.xxx.xxx.xx": -0.4}, 0.52,
            fill={"D.......D.......": 0.0, "x...............": -0.4})       # the climax bar: held, then space
    s.pad("choir_u", b + 4, Ar[4:], 0.34, 0, 0.0, 0.6)
    s.mel("horn", b, CL, 0.46, 0, 0.25, 0.4, legato=0.98)
    s.mel("shawm", b, A, 0.58, 1, -0.25, 0.35)
    b += 8
    # bars 18-20: the release; the tune's opening comes back softly, an octave down, over a held tonic
    s.note("throat", s.bar(b), 12, G2, 0.3, 0.0, 0.5)
    s.mel("horn", b, ["1:2 5:2", "5:2 4:1 3:1", "1:4"], 0.3, -1, 0.2, 0.5)
    s.hit("B", s.bar(b), 0.35)
    s.hit("B", s.bar(b + 2), 0.25)
    for d in (0, 2, 4):
        s.note("choir_u", s.bar(b + 2), 4, s.pitch(d), 0.22, 0.0, 0.7)
    return s


def main():
    demo = queen_stirs_rule()
    L, R = demo.render()
    write("queen_stirs_demo", L, R)
    cur = C.SONGS["brood_peace_4"]()
    L, R = cur.render()
    write("queen_stirs_current_first_minute", L, R, seconds=60)


if __name__ == "__main__":
    main()
