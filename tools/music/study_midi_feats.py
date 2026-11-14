"""Summary statistics of MIDI files (no notes copied): python3 -I midi_feats.py OUT.json FILE..."""
import sys, json, collections
import mido

KS = {0: "C", 1: "Db", 2: "D", 3: "Eb", 4: "E", 5: "F", 6: "F#", 7: "G", 8: "Ab", 9: "A", 10: "Bb", 11: "B"}
MAJ = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
MIN = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]


def corr(a, b):
    ma, mb = sum(a) / 12, sum(b) / 12
    num = sum((x - ma) * (y - mb) for x, y in zip(a, b))
    da = sum((x - ma) ** 2 for x in a) ** .5
    db = sum((y - mb) ** 2 for y in b) ** .5
    return num / (da * db + 1e-9)


def feats(path):
    m = mido.MidiFile(path)
    tpb = m.ticks_per_beat
    notes, tempos, metres = [], [], []
    for ti, tr in enumerate(m.tracks):
        t, on = 0, {}
        for msg in tr:
            t += msg.time
            if msg.type == "set_tempo":
                tempos.append((t, mido.tempo2bpm(msg.tempo)))
            elif msg.type == "time_signature":
                metres.append(f"{msg.numerator}/{msg.denominator}")
            elif msg.type == "note_on" and msg.velocity > 0:
                on[(msg.channel, msg.note)] = (t, msg.velocity)
            elif msg.type in ("note_off", "note_on"):
                k = (msg.channel, msg.note)
                if k in on:
                    s, v = on.pop(k)
                    notes.append((s / tpb, (t - s) / tpb, msg.note, v, ti))
    notes.sort()
    beats = max(n[0] + n[1] for n in notes)
    pcs = [0.0] * 12
    for s, d, p, v, _ in notes:
        pcs[p % 12] += d
    rot = lambda prof, k: [prof[(i - k) % 12] for i in range(12)]
    best = max([(corr(pcs, rot(MAJ, k)), KS[k] + " major") for k in range(12)] +
               [(corr(pcs, rot(MIN, k)), KS[k] + " minor") for k in range(12)])
    # top line: highest note at each onset
    by_on = collections.defaultdict(list)
    for s, d, p, v, _ in notes:
        by_on[round(s, 3)].append(p)
    top = [max(by_on[k]) for k in sorted(by_on)]
    iv = [abs(b - a) for a, b in zip(top, top[1:]) if b != a]
    steps = sum(1 for x in iv if x <= 2)
    durs = collections.Counter(round(d * 4) / 4 for _, d, _, _, _ in notes)
    vels = [v for *_, v, _ in notes]
    # polyphony: mean notes sounding at each onset
    onsets = sorted(by_on)
    poly = sum(len(by_on[k]) for k in onsets) / len(onsets)
    # rhythmic repetition: identical onset patterns per 4-beat window
    win = collections.Counter()
    for w in range(int(beats // 4)):
        pat = tuple(sorted(round(k - 4 * w, 2) for k in onsets if 4 * w <= k < 4 * w + 4))
        win[pat] += 1
    rep = (sum(c for c in win.values() if c > 1) / max(1, sum(win.values())))
    bpm0 = tempos[0][1] if tempos else 120.0
    return {
        "file": path.split("/")[-1].split("-", 1)[-1],
        "metre": metres[0] if metres else "?", "tempo_bpm_first": round(bpm0, 1),
        "tempo_changes": len(tempos), "tempo_range": [round(min(t for _, t in tempos), 1), round(max(t for _, t in tempos), 1)] if tempos else None,
        "length_beats": round(beats, 1), "notes": len(notes), "notes_per_beat": round(len(notes) / beats, 2),
        "key_estimate": best[1], "key_fit": round(best[0], 2),
        "chromatic_share": round(1 - sum(sorted(pcs)[-7:]) / sum(pcs), 3),
        "pitch_range": [min(n[2] for n in notes), max(n[2] for n in notes)],
        "top_line_range": [min(top), max(top)],
        "top_step_share": round(steps / max(1, len(iv)), 2),
        "top_mean_leap": round(sum(iv) / max(1, len(iv)), 2),
        "top_big_leaps_share(>=5)": round(sum(1 for x in iv if x >= 5) / max(1, len(iv)), 2),
        "distinct_durations": len(durs),
        "velocity_range": [min(vels), max(vels)], "velocity_layers": len(set(vels)),
        "mean_polyphony_at_onset": round(poly, 2),
        "repeated_4beat_rhythm_share": round(rep, 2),
        "tracks": len(m.tracks),
    }


out = [feats(p) for p in sys.argv[2:]]
json.dump(out, open(sys.argv[1], "w"), indent=1)
for f in out:
    print(f["file"], f["key_estimate"], f["metre"], f["tempo_bpm_first"], f["notes_per_beat"], f["top_step_share"], f["velocity_layers"], f["repeated_4beat_rhythm_share"])
