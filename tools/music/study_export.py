"""Music study (job music-study): export every piece's score as notes, without rendering audio.

Each piece function in compose.py (and the modules it registers) builds a Song whose notes sit in
song.ev before render(). This tool calls every piece, keeps song.ev and the score's tempo, metre,
tonic and mode, and writes one JSON per piece. Nothing in assets/ is touched.

Usage: python3 tools/music/study_export.py OUTDIR [name ...]
Each JSON: {name, file, title, cls, bpm, meter, tonic, mode, ev: [[t0, kind, inst, midi, dur, vel, pan], ...]}
kind "n" = a pitched note (dur in seconds), "d" = a drum hit (inst = drum code, midi 0).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import compose as C  # noqa: E402

# the stings are written under another file name than their function name
FILE_OF = {"crown_win": "win_crown", "brood_win": "win_brood", "clock_win": "win_clockwork"}


def export(name):
    s = C.SONGS[name]()
    ev = getattr(s, "ev", None)
    if ev is None:
        return None
    rows = [[round(float(e[0]), 4), e[1], str(e[2]), int(e[3]), round(float(e[4]), 4), round(float(e[5]), 3),
             round(float(e[6]), 2)] for e in ev]
    rows.sort(key=lambda r: r[0])
    return {"name": name, "file": FILE_OF.get(name, getattr(s, "name", name)), "title": getattr(s, "title", name),
            "cls": type(s).__name__, "bpm": float(s.bpm), "meter": float(s.meter), "tonic": int(s.tonic),
            "mode": s.mode, "bed": bool(getattr(s, "bed_x", None) is not None), "ev": rows}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    names = sys.argv[2:] or sorted(C.SONGS)
    for nm in names:
        d = export(nm)
        if d is None:
            print("skip", nm)
            continue
        with open(os.path.join(out, nm + ".json"), "w") as f:
            json.dump(d, f)
        print("%-18s %-34s %5d events" % (nm, d["title"][:34], len(d["ev"])))


if __name__ == "__main__":
    main()
