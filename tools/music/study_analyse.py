"""Music study (job music-study): symbolic features of every game piece, from study_export.py's JSON.

Usage: python3 tools/music/study_analyse.py EXPORT_DIR OUT.json

Everything here is measured from the notes the generator writes (not from the audio). The methods are simple and
written out so the numbers can be checked:
- the melody is the instrument whose notes are mostly one at a time, high, present through the piece and not a
  short repeating loop (doubling instruments give the same line);
- chords are guessed per beat by matching the sounding pitch classes (weighted by length and loudness, the bass
  counted twice) against triad and seventh templates;
- phrases end at a melody rest of a beat or more, or a held note of 2+ beats;
- blocks of 4 bars are compared note for note (literal repeats) and by melody (form letters).
"""
import json
import math
import os
import sys
from collections import Counter, defaultdict

import numpy as np

MODES = {
    "ionian": [0, 2, 4, 5, 7, 9, 11], "dorian": [0, 2, 3, 5, 7, 9, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10], "aeolian": [0, 2, 3, 5, 7, 8, 10], "phrygian_dom": [0, 1, 4, 5, 7, 8, 10],
    "lydian": [0, 2, 4, 6, 7, 9, 11], "locrian": [0, 1, 3, 5, 6, 8, 10], "harmonic": [0, 2, 3, 5, 7, 8, 11],
}
MAJORISH = {"ionian", "lydian", "mixolydian"}
# instruments that are not melody or harmony carriers (pitched percussion, sound effects)
PERC = {"timpani", "log", "volt", "bullroar", "springres", "cymswell", "tinebell", "bell", "clockbell"}
# Krumhansl-Kessler key profiles
KK_MAJ = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
KK_MIN = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
CHORDS = {"maj": (0, 4, 7), "min": (0, 3, 7), "dim": (0, 3, 6), "aug": (0, 4, 8), "sus": (0, 5, 7), "5": (0, 7),
          "7": (0, 4, 7, 10), "maj7": (0, 4, 7, 11), "m7": (0, 3, 7, 10), "m7b5": (0, 3, 6, 10), "dim7": (0, 3, 6, 9)}
SEVENTHS = {"7", "maj7", "m7", "m7b5", "dim7"}


def felt_tempo(bpm, meter):
    """(pulse per minute, beats per bar as felt, metre label). Scores above 200 bpm count quavers."""
    m = int(round(meter))
    if bpm >= 200:
        if m in (6, 9, 12):
            return bpm / 3.0, m // 3, "%d/8 (compound)" % m
        return bpm / 2.0, m / 2.0, "%d/8" % m
    return bpm, m, "%d/4" % m


def metre_class(bpm, meter):
    m = int(round(meter))
    if bpm >= 200 and m in (6, 9, 12):
        return "compound"
    if m in (5, 7, 11) or (bpm >= 200 and m % 2 == 1):
        return "odd"
    if m == 3 or (m == 9 and bpm < 200):
        return "triple"
    return "duple"


def key_estimate(pc_w):
    best = (-9, 0, "major")
    for t in range(12):
        for prof, nm in ((KK_MAJ, "major"), (KK_MIN, "minor")):
            r = np.corrcoef(np.roll(prof, t), pc_w)[0, 1] if pc_w.sum() > 0 else 0
            if r > best[0]:
                best = (r, t, nm)
    return best


class Piece:
    def __init__(self, d):
        self.d = d
        self.bpm, self.meter = d["bpm"], d["meter"]
        self.beat = 60.0 / self.bpm
        self.bar = self.beat * self.meter
        # the felt pulse: scores above 200 bpm count quavers (6/8, 9/8, 12/8 felt in dotted crotchets)
        m = int(round(self.meter))
        self.pulse = self.beat * ((3 if m in (6, 9, 12) else 2) if self.bpm >= 200 else 1)
        ev = d["ev"]
        self.notes = [e for e in ev if e[1] == "n"]
        self.drums = [e for e in ev if e[1] == "d"]
        self.length = max([e[0] + (e[4] if e[1] == "n" else 0.3) for e in ev] + [1.0])
        self.nbars = max(1, int(math.ceil(self.length / self.bar - 1e-6)))
        self.by_inst = defaultdict(list)
        for e in self.notes:
            self.by_inst[e[2]].append(e)
        self.tonic_pc = d["tonic"] % 12
        self.mode = d["mode"]
        self.scale = set((self.tonic_pc + i) % 12 for i in MODES[self.mode])

    # -------------------------------------------------- layers
    def inst_stats(self):
        out = {}
        for inst, ns in self.by_inst.items():
            ns = sorted(ns, key=lambda e: e[0])
            on = np.array([e[0] for e in ns])
            # monophony: notes that do not start together with another note of the same instrument
            together = np.sum(np.diff(on) < 0.03) if len(on) > 1 else 0
            mono = 1 - 2 * together / max(1, len(on))
            med_p = float(np.median([e[3] for e in ns]))
            med_dur = float(np.median([e[4] for e in ns])) / self.beat
            bars_with = len(set(int((e[0] + 0.03) // self.bar) for e in ns))
            ioi = np.round(np.diff(on) / self.beat * 12)
            ioi = ioi[ioi > 0]
            reg = Counter(ioi.tolist()).most_common(1)[0][1] / len(ioi) if len(ioi) else 0
            out[inst] = dict(n=len(ns), mono=mono, pitch=med_p, dur=med_dur, cover=bars_with / self.nbars,
                             loop=self.loopness(ns), regular=reg, per_bar=len(ns) / self.nbars)
        return out

    def loopness(self, ns):
        """Share of bars whose (onset, pitch) pattern equals the pattern of the bar before or two before."""
        pat = defaultdict(list)
        for e in ns:
            b = int((e[0] + 0.03) // self.bar)
            pat[b].append((round((e[0] - b * self.bar) / self.beat * 4), e[3]))
        bars = sorted(pat)
        if len(bars) < 3:
            return 0.0
        same = sum(1 for b in bars if tuple(sorted(pat[b])) in (tuple(sorted(pat.get(b - 1, []))),
                                                               tuple(sorted(pat.get(b - 2, [])))))
        return same / len(bars)

    def layers(self):
        st = self.inst_stats()
        self.st = st
        cands = []
        for inst, s in st.items():
            if inst in PERC or s["n"] < 12 or s["mono"] < 0.75 or s["pitch"] < 55 or s["dur"] > 4:
                continue
            if s["loop"] > 0.6 or (s["regular"] > 0.7 and s["per_bar"] >= 4):
                continue      # an ostinato or a running figure, not a tune
            cands.append(inst)
        self.cands = set(cands)
        roles = {}
        for inst, s in st.items():
            if inst in PERC:
                roles[inst] = "perc"
            elif inst in self.cands:
                roles[inst] = "melody"
            elif s["pitch"] < 50 and s["dur"] <= 6:
                roles[inst] = "bass"
            elif s["dur"] >= 2.0 or s["mono"] < 0.5 and s["dur"] >= 1.2:
                roles[inst] = "pad"
            else:
                roles[inst] = "figure"
        self.roles = roles
        mel = self.melody()
        cnt = Counter(e[2] for e in mel)
        self.lead = cnt.most_common(1)[0][0] if cnt else None
        return self.lead, roles

    # -------------------------------------------------- melody
    def melody(self):
        """The top line of the tune-carrying instruments (a skyline: a note is kept when no other tune note
        sounding at its start is higher)."""
        if hasattr(self, "_mel"):
            return self._mel
        ns = sorted([e for e in self.notes if e[2] in self.cands], key=lambda e: e[0])
        clusters = []
        for e in ns:      # notes starting within 40 ms of each other start together (the timing is humanised)
            if clusters and e[0] - clusters[-1][0][0] < 0.04:
                clusters[-1].append(e)
            else:
                clusters.append([e])
        out = []
        active = []      # (end, pitch) of tune notes already sounding
        for cl in clusters:
            t = cl[0][0]
            active = [a for a in active if a[0] > t + 0.04]
            top = max(cl, key=lambda e: e[3])
            if not any(p > top[3] for _, p in active):
                out.append(top)
            for e in cl:
                active.append((e[0] + e[4], e[3]))
        self._mel = out
        return out

    def melody_feats(self):
        m = self.melody()
        f = {}
        if len(m) < 4:
            return f, m
        p = np.array([e[3] for e in m])
        iv = np.diff(p)
        a = np.abs(iv)
        f["mel_inst"] = self.lead
        f["mel_range"] = int(p.max() - p.min())
        f["mel_register"] = float(np.median(p))
        f["mel_repeat"] = float(np.mean(a == 0))
        f["mel_step"] = float(np.mean((a >= 1) & (a <= 2)))
        f["mel_third"] = float(np.mean((a >= 3) & (a <= 4)))
        f["mel_leap"] = float(np.mean(a >= 5))
        f["mel_bigleap"] = float(np.mean(a >= 8))
        nz = iv[iv != 0]
        f["mel_turns"] = float(np.mean(np.sign(nz[1:]) != np.sign(nz[:-1]))) if len(nz) > 2 else 0.0
        hist = Counter(int(min(12, x)) for x in a)
        f["mel_iv_hist"] = [hist.get(k, 0) / len(a) for k in range(13)]
        # rhythm of the melody (in beats, quantised to 1/12)
        onb = np.array([e[0] / self.pulse for e in m])
        ioi = np.diff(np.array([e[0] / self.beat for e in m]))
        q = np.round(ioi * 12) / 12
        f["mel_distinct_durs"] = len(set(q[q > 0]))
        frac = onb % 1.0
        offbeat = (np.minimum(frac, 1 - frac) > 0.06)
        durb = np.array([e[4] / self.pulse for e in m])
        to_next_beat = np.ceil(onb + 1e-6) - onb
        f["mel_syncop"] = float(np.mean(offbeat & (durb > to_next_beat + 0.05)))
        f["mel_notes_per_bar"] = len(m) / self.nbars
        return f, m

    # -------------------------------------------------- texture
    def texture(self):
        f = {}
        dens = defaultdict(float)
        for inst, r in self.roles.items():
            dens[r] += len(self.by_inst[inst]) / self.length
        dens["drums"] = len(self.drums) / self.length
        for k in ("melody", "bass", "pad", "figure", "perc", "drums"):
            f["dens_" + k] = round(dens.get(k, 0.0), 3)
        f["notes_per_s"] = round((len(self.notes) + len(self.drums)) / self.length, 2)
        # simultaneous instruments and notes, sampled every 0.25 s
        ts = np.arange(0, self.length, 0.25)
        cnt = np.zeros(len(ts))
        insts = [set() for _ in ts]
        for e in self.notes:
            i0, i1 = int(e[0] / 0.25), int(min(len(ts) - 1, (e[0] + max(e[4], 0.1)) / 0.25))
            for i in range(i0, i1 + 1):
                if i < len(ts):
                    cnt[i] += 1
                    insts[i].add(e[2])
        f["voices_mean"] = float(np.mean(cnt))
        f["insts_mean"] = float(np.mean([len(s) for s in insts]))
        f["insts_total"] = len(self.by_inst) + len(set(e[2] for e in self.drums))
        return f

    # -------------------------------------------------- harmony
    def beat_chords(self):
        B = self.pulse
        nb = int(math.ceil(self.length / B))
        pcs = np.zeros((nb, 12))
        basspc = [None] * nb
        bassp = [999] * nb
        for e in self.notes:
            if self.roles.get(e[2]) == "perc":
                continue
            w_role = 2.0 if self.roles.get(e[2]) == "bass" else 1.0
            b0, b1 = e[0] / B, (e[0] + e[4]) / B
            for b in range(int(b0), min(nb, int(math.ceil(b1)))):
                ov = min(b + 1, b1) - max(b, b0)
                if ov <= 0:
                    continue
                pcs[b, e[3] % 12] += ov * e[5] * w_role
                if e[3] < bassp[b]:
                    bassp[b], basspc[b] = e[3], e[3] % 12
        labels = []
        for b in range(nb):
            v = pcs[b]
            if v.sum() < 1e-6:
                labels.append(None)
                continue
            v = v / v.sum()
            best, bl = -9, None
            for root in range(12):
                for q, tpl in CHORDS.items():
                    inside = sum(v[(root + i) % 12] for i in tpl)
                    score = inside - 0.6 * (1 - inside) - (0.04 * (len(tpl) - 3) if len(tpl) > 3 else 0)
                    score -= 0.08 if q in ("5", "sus", "aug") else 0
                    if basspc[b] == root:
                        score += 0.06
                    if score > best:
                        best, bl = score, (root, q)
            labels.append(bl)
        return labels, basspc

    def harmony(self):
        f = {}
        labels, basspc = self.beat_chords()
        # merge half-beat noise: a chord must last a beat; count changes
        seq = []
        for i, l in enumerate(labels):
            if l is None:
                continue
            if not seq or seq[-1][1] != l:
                seq.append((i, l))
        # harmonic rhythm counts changes of the chord ROOT only (maj -> maj7 or a sus is colour, not a new chord),
        # after a 3-pulse majority filter so one passing note does not make a chord
        roots = [l[0] if l else None for l in labels]
        sm = list(roots)
        for i in range(1, len(roots) - 1):
            a, b, c = roots[i - 1], roots[i], roots[i + 1]
            if b is not None and a is not None and a == c and b != a:
                sm[i] = a
        rseq = [r for i, r in enumerate(sm) if r is not None and (i == 0 or sm[i - 1] != r)]
        changes = max(0, len(rseq) - 1)
        f["harm_label_changes"] = max(0, len(seq) - 1)
        sounding_bars = max(1, sum(1 for l in labels if l is not None) * self.pulse / self.bar)
        f["harm_rhythm"] = changes / sounding_bars
        f["harm_label_rate"] = f.pop("harm_label_changes") / sounding_bars
        tot = len(seq) or 1
        qual = Counter(l[1] for _, l in seq)
        f["chord_sevenths"] = sum(qual[q] for q in SEVENTHS) / tot
        f["chord_power_sus"] = (qual["5"] + qual["sus"]) / tot
        f["chord_vocab"] = len(set(l for _, l in seq))
        diat = 0
        sec_dom = borrowed = 0
        tpc = self.tonic_pc
        par = set((tpc + i) % 12 for i in (MODES["aeolian"] if self.mode in MAJORISH else MODES["ionian"]))
        for k, (i, (root, q)) in enumerate(seq):
            tones = set((root + x) % 12 for x in CHORDS[q])
            if tones <= self.scale:
                diat += 1
            elif tones <= par | self.scale and not tones <= self.scale:
                borrowed += 1
            if q in ("maj", "7") and k + 1 < len(seq):
                nroot = seq[k + 1][1][0]
                if (root - nroot) % 12 == 7 and nroot != tpc and nroot in self.scale:
                    sec_dom += 1
        f["chord_diatonic"] = diat / tot
        f["chord_borrowed"] = borrowed / tot
        f["chord_secdom"] = sec_dom / tot
        # chromaticism: per 8 bars, the share of note-time outside the 7-note scale that fits those bars best
        # (any major / natural minor collection, any harmonic minor, or the score's own mode), so that a change of
        # key, or a score whose declared mode is not the one it uses, does not count as chromatic
        scales = [set((t + i) % 12 for i in MODES["ionian"]) for t in range(12)] + \
                 [set((t + i) % 12 for i in MODES["harmonic"]) for t in range(12)] + \
                 [set((t + i) % 12 for i in MODES["phrygian_dom"]) for t in range(12)] + [self.scale]
        w_in = w_out = 0.0
        win = 8 * self.bar
        nwin = int(math.ceil(self.length / win))
        pcw = np.zeros((nwin, 12))
        for e in self.notes:
            if self.roles.get(e[2]) == "perc":
                continue
            pcw[min(nwin - 1, int(e[0] // win)), e[3] % 12] += e[4] * e[5]
        for row in pcw:
            if row.sum() <= 0:
                continue
            best = max(sum(row[i] for i in sc) for sc in scales)
            w_in += best
            w_out += row.sum() - best
        f["chromatic"] = w_out / max(1e-6, w_in + w_out)
        decl_out = sum(pcw[:, i].sum() for i in range(12) if i not in self.scale)
        f["outside_declared_mode"] = float(decl_out / max(1e-6, pcw.sum()))
        # roots relative to the tonic
        rel = Counter((l[0] - tpc) % 12 for _, l in seq)
        f["root_tonic_share"] = rel[0] / tot
        # cadences: chord pairs at the tonic
        auth = plag = half = decep = phryg = 0
        for k in range(1, len(seq)):
            (r0, q0), (r1, q1) = seq[k - 1][1], seq[k][1]
            d0, d1 = (r0 - tpc) % 12, (r1 - tpc) % 12
            if d1 == 0 and d0 == 7 and q0 in ("maj", "7"):
                auth += 1
            elif d1 == 0 and d0 == 7:
                auth += 0.5         # a minor v to i, the modal cadence
            elif d1 == 0 and d0 == 5:
                plag += 1
            elif d1 == 0 and d0 == 1:
                phryg += 1
            elif d0 == 7 and q0 in ("maj", "7") and d1 in (8, 9):
                decep += 1
            if d1 == 7 and k + 1 < len(seq) and (seq[k + 1][0] - seq[k][0]) * self.pulse >= self.bar * 0.99:
                half += 1           # resting a bar or more on the dominant
        mins = self.length / 60.0
        f["cad_auth_pm"] = auth / mins
        f["cad_plag_pm"] = plag / mins
        f["cad_half_pm"] = half / mins
        f["cad_decep_pm"] = decep / mins
        f["cad_phryg_pm"] = phryg / mins
        f["cad_total_pm"] = (auth + plag + half + decep + phryg) / mins
        # key changes: Krumhansl key per 8 bars
        win = 8
        keys = []
        for b0 in range(0, self.nbars, win):
            pcw = np.zeros(12)
            for e in self.notes:
                if self.roles.get(e[2]) == "perc":
                    continue
                if b0 * self.bar <= e[0] < (b0 + win) * self.bar:
                    pcw[e[3] % 12] += e[4] * e[5]
            if pcw.sum() > 0:
                r, t, mm = key_estimate(pcw)
                keys.append((t, mm) if r > 0.55 else None)
        ks = [k for k in keys if k]
        f["key_changes"] = sum(1 for a, b in zip(ks, ks[1:]) if a != b)
        pcw = np.zeros(12)
        for e in self.notes:
            if self.roles.get(e[2]) != "perc":
                pcw[e[3] % 12] += e[4] * e[5]
        r, t, mm = key_estimate(pcw)
        f["key_est"] = "%s %s" % (NAMES[t], mm)
        f["key_clarity"] = float(r)
        self.chord_seq = seq
        return f

    # -------------------------------------------------- bass
    def bass(self):
        f = {}
        bins = [e for e in self.notes if self.roles.get(e[2]) == "bass"]
        if len(bins) < 8:
            return f
        bins.sort(key=lambda e: (e[0], e[3]))
        line = []
        for e in bins:
            if line and abs(e[0] - line[-1][0]) < 0.03:
                continue
            line.append(e)
        p = np.array([e[3] for e in line])
        a = np.abs(np.diff(p))
        f["bass_same"] = float(np.mean(a % 12 == 0))
        f["bass_step"] = float(np.mean((a >= 1) & (a <= 2)))
        f["bass_45"] = float(np.mean((a == 5) | (a == 7)))
        f["bass_notes_per_bar"] = len(line) / self.nbars
        # pedal: the longest run of the same pitch class, in bars
        best = cur = 0.0
        for k in range(1, len(line)):
            if line[k][3] % 12 == line[k - 1][3] % 12:
                cur += line[k][0] - line[k - 1][0]
            else:
                cur = 0.0
            best = max(best, cur)
        f["bass_longest_pedal_bars"] = best / self.bar
        self.bass_line = line
        return f

    # -------------------------------------------------- rhythm sameness
    def rhythm(self):
        """How often a bar has the same rhythm (all onsets, every instrument and drum) as the bar before.
        Two bars count as the same when they have the same number of onsets and each lies within 45 ms of its
        partner (the Brood's timing is humanised by up to 20 ms, so exact grid matching would hide repeats)."""
        f = {}
        sig = defaultdict(list)
        for e in self.notes + self.drums:
            b = int((e[0] + 0.03) // self.bar)
            sig[b].append(e[0] - b * self.bar)
        for b in sig:     # merge onsets closer than 30 ms (a chord, a doubled line)
            xs = sorted(sig[b])
            out = [xs[0]]
            for x in xs[1:]:
                if x - out[-1] > 0.03:
                    out.append(x)
            sig[b] = np.array(out)

        def same(a, c):
            return len(a) == len(c) and (len(a) == 0 or float(np.max(np.abs(a - c))) < 0.045)
        bars = [b for b in range(self.nbars) if b in sig]
        same_prev = sum(1 for b in bars if b - 1 in sig and same(sig[b], sig[b - 1]))
        f["bar_rhythm_same_prev"] = same_prev / max(1, len(bars) - 1)
        reps = []
        for b in bars:
            for r in reps:
                if same(sig[b], sig[r[0]]):
                    r.append(b)
                    break
            else:
                reps.append([b])
        f["bar_rhythm_top_share"] = max(len(r) for r in reps) / max(1, len(bars)) if reps else 0
        f["bar_rhythm_distinct"] = len(reps) / max(1, len(bars))
        return f

    # -------------------------------------------------- phrases
    def phrases(self, m):
        f = {}
        if len(m) < 6:
            return f
        bounds = [m[0][0]]
        for k in range(len(m) - 1):
            end = m[k][0] + m[k][4]
            gap = m[k + 1][0] - end
            if gap >= self.pulse * 0.95 or m[k][4] >= 2 * self.pulse * 0.95 and m[k + 1][0] - m[k][0] >= 2 * self.pulse:
                bounds.append(m[k + 1][0])
        bounds.append(m[-1][0] + m[-1][4])
        lens = np.diff(bounds) / self.bar
        lens = lens[lens >= 0.75]
        if not len(lens):
            return f
        # merge sub-bar fragments into a phrase of at least one bar
        f["phrase_count"] = len(lens)
        f["phrase_len_median"] = float(np.median(lens))
        r = np.round(lens)
        f["phrase_square"] = float(np.mean(np.isin(r, (2, 4, 8)) & (np.abs(lens - r) < 0.35)))
        f["phrase_48"] = float(np.mean(np.isin(r, (4, 8)) & (np.abs(lens - r) < 0.35)))
        f["phrase_len_hist"] = dict(Counter(int(x) for x in r))
        return f

    # -------------------------------------------------- form and repetition
    def form(self, m):
        f = {}
        blk = 4
        # blocks start at the bar of the first tune note (an intro of 2 bars would shift every block)
        org = int((m[0][0] + 0.03) // self.bar) * self.bar if m else 0.0
        nblk = max(1, int(round((self.length - org) / self.bar)) // blk)
        full = []
        for k in range(nblk):
            t0, t1 = org + k * blk * self.bar - 0.03, org + (k + 1) * blk * self.bar - 0.03
            full.append(frozenset((e[2], e[3], int(round((e[0] - t0) / self.beat * 4)))
                                  for e in self.notes if t0 <= e[0] < t1))
        lit = sum(1 for k in range(nblk) if full[k] and full[k] in full[:k])
        f["literal_repeat"] = lit / nblk
        # near repeats of the whole texture (Jaccard >= 0.85)
        near = 0
        for k in range(nblk):
            for j in range(k):
                a, b = full[k], full[j]
                if a and b and len(a & b) / len(a | b) >= 0.85:
                    near += 1
                    break
        f["near_repeat"] = near / nblk
        # form letters by melody per block: rhythm (onsets) and intervals, so a tune moved to another key or
        # mode (a diatonic shift changes a step by a semitone) still counts as the same tune
        mel = []
        for k in range(nblk):
            t0, t1 = org + k * blk * self.bar - 0.03, org + (k + 1) * blk * self.bar - 0.03
            bn = [e for e in m if t0 <= e[0] < t1]
            mel.append((frozenset(int(round((e[0] - t0) / self.beat * 2)) for e in bn),
                        [bn[i + 1][3] - bn[i][3] for i in range(len(bn) - 1)]))

        def sim(a, b):
            if not a[0] or not b[0]:
                return 0.0
            rj = len(a[0] & b[0]) / len(a[0] | b[0])
            n = min(len(a[1]), len(b[1]))
            if n == 0:
                return rj
            ij = sum(1 for x, y in zip(a[1], b[1]) if abs(x - y) <= 1) / max(len(a[1]), len(b[1]))
            return 0.5 * rj + 0.5 * ij
        letters, protos = [], []
        for k in range(nblk):
            if not mel[k][0]:
                letters.append("-")
                continue
            hit = None
            for i, pr in enumerate(protos):
                if sim(mel[k], pr) >= 0.7:
                    hit = i
                    break
            if hit is None:
                protos.append(mel[k])
                hit = len(protos) - 1
            letters.append(chr(65 + hit) if hit < 26 else "*")
        s = "".join(letters)
        f["form_blocks"] = s
        # sliding: every 4-bar stretch of the tune, from every bar, against the stretches at least 4 bars earlier
        wins = []
        nb = int(math.ceil(self.length / self.bar))
        for b in range(nb - blk + 1):
            t0, t1 = b * self.bar - 0.03, (b + blk) * self.bar - 0.03
            bn = [e for e in m if t0 <= e[0] < t1]
            wins.append((frozenset(int(round((e[0] - t0) / self.beat * 2)) for e in bn),
                         [bn[i + 1][3] - bn[i][3] for i in range(len(bn) - 1)], len(bn)))
        rep = tot = 0
        for b, w in enumerate(wins):
            if w[2] < 3:
                continue
            tot += 1
            if any(wins[j][2] >= 3 and sim(w, wins[j]) >= 0.85 for j in range(0, b - blk + 1)):
                rep += 1
        f["tune_repeat"] = rep / max(1, tot)
        used = [c for c in s if c != "-"]
        f["form_distinct"] = len(set(used)) / max(1, len(used))
        f["form_returns"] = sum(1 for i, c in enumerate(used) if c in used[:i] and (i == 0 or used[i - 1] != c))
        if not used:
            f["form_class"] = "no melody"
        elif f["form_distinct"] >= 0.7:
            f["form_class"] = "through-composed"
        elif used[0] == used[-1] and len(set(used)) >= 2 and f["form_returns"] <= 2:
            f["form_class"] = "A-B-A"
        elif f["form_returns"] >= 3 and len(set(used)) >= 3:
            f["form_class"] = "rondo-like"
        else:
            f["form_class"] = "strophic / loop"
        return f

    # -------------------------------------------------- motif work
    def motifs(self, m):
        """4-note cells (3 intervals + 3 durations) of the melody: literal, moved (sequence), varied, inverted."""
        f = {}
        if len(m) < 10:
            return f
        p = [e[3] for e in m]
        d = [round((m[k + 1][0] - m[k][0]) / self.beat * 4) for k in range(len(m) - 1)] + [0]
        cells = []
        for k in range(len(m) - 3):
            iv = tuple(p[k + i + 1] - p[k + i] for i in range(3))
            rh = tuple(d[k:k + 3])
            cells.append((p[k], iv, rh))
        seen_lit, seen_iv, seen_rh, seen_ct = set(), set(), set(), set()
        lit = seq = var = inv = new = 0
        for start, iv, rh in cells:
            ct = tuple(int(np.sign(x)) for x in iv)
            if (start, iv, rh) in seen_lit:
                lit += 1
            elif (iv, rh) in seen_iv:
                seq += 1
            elif tuple(-x for x in iv) + rh in seen_iv or (tuple(-x for x in iv), rh) in seen_iv:
                inv += 1
            elif (ct, rh) in seen_ct or rh in seen_rh and ct in {c for c, _ in seen_ct}:
                var += 1
            else:
                new += 1
            seen_lit.add((start, iv, rh))
            seen_iv.add((iv, rh))
            seen_rh.add(rh)
            seen_ct.add((ct, rh))
        n = len(cells)
        f["motif_literal"] = lit / n
        f["motif_sequence"] = seq / n
        f["motif_inverted"] = inv / n
        f["motif_varied"] = var / n
        f["motif_new"] = new / n
        f["motif_development"] = (seq + inv + var) / max(1, seq + inv + var + lit)
        return f

    # -------------------------------------------------- dynamics
    def dynamics(self):
        f = {}
        w = 2  # bars per window
        nw = max(1, self.nbars // w)
        en = np.zeros(nw)
        for e in self.notes + self.drums:
            k = min(nw - 1, int(e[0] // (self.bar * w)))
            dur = e[4] if e[1] == "n" else 0.15
            en[k] += e[5] ** 2 * (0.3 + min(dur, self.bar * w))
        en = np.maximum(en, 1e-6)
        db = 10 * np.log10(en / en.max())
        sm = np.convolve(db, np.ones(3) / 3, mode="same") if nw >= 5 else db
        f["dyn_curve"] = [round(float(x), 2) for x in sm]
        f["dyn_range_db"] = float(np.percentile(sm, 95) - np.percentile(sm, 10))
        f["dyn_climax_pos"] = float(np.argmax(sm) / max(1, nw - 1))
        f["dyn_start_db"] = float(np.mean(sm[: max(1, nw // 8)]))
        f["dyn_end_db"] = float(np.mean(sm[-max(1, nw // 8):]))
        f["vel_mean"] = float(np.mean([e[5] for e in self.notes])) if self.notes else 0
        f["vel_std"] = float(np.std([e[5] for e in self.notes])) if self.notes else 0
        return f

    # -------------------------------------------------- counterpoint
    def counterpoint(self, m):
        f = {}
        lines = [i for i, r in self.roles.items() if r in ("melody", "figure", "bass") and len(self.by_inst[i]) >= 12]
        onsets = {i: set(int(round(e[0] / self.beat * 4)) for e in self.by_inst[i]) for i in lines}
        # independent lines: rhythm differs from every line already counted (Jaccard < 0.5)
        chosen = []
        for i in sorted(lines, key=lambda x: -len(self.by_inst[x])):
            if all(len(onsets[i] & onsets[j]) / max(1, len(onsets[i] | onsets[j])) < 0.5 for j in chosen):
                chosen.append(i)
        f["indep_lines"] = len(chosen)
        # a counter-line: in a bar, a second tune-carrying instrument (not the lead's) whose rhythm differs from the
        # top line's (onset Jaccard < 0.6), so a doubling of the tune in octaves or thirds does not count, but a slow
        # line of long notes under a moving tune does
        if m:
            top = defaultdict(set)
            for e in m:
                top[int((e[0] + 0.03) // self.bar)].add(int(round(e[0] / self.beat * 4)))
            per = defaultdict(lambda: defaultdict(set))
            for e in self.notes:
                if e[2] in self.cands:
                    per[int((e[0] + 0.03) // self.bar)][e[2]].add(int(round(e[0] / self.beat * 4)))
            bars = [b for b in top]
            cl = 0
            for b in bars:
                for inst, ons in per[b].items():
                    if inst != self.lead and len(ons | top[b]) and len(ons & top[b]) / len(ons | top[b]) < 0.6:
                        cl += 1
                        break
            f["counter_line_share"] = cl / max(1, len(bars))
        bl = getattr(self, "bass_line", None)
        if m and bl and len(m) > 8:
            bt = np.array([e[0] for e in bl])
            bp = np.array([e[3] for e in bl])

            def bass_at(t):
                k = np.searchsorted(bt, t + 0.02) - 1
                return bp[k] if k >= 0 else None
            mot = Counter()
            for k in range(1, len(m)):
                b0, b1 = bass_at(m[k - 1][0]), bass_at(m[k][0])
                if b0 is None or b1 is None:
                    continue
                dm, db = np.sign(m[k][3] - m[k - 1][3]), np.sign(b1 - b0)
                if dm == 0 and db == 0:
                    mot["static"] += 1
                elif dm == 0 or db == 0:
                    mot["oblique"] += 1
                elif dm == db:
                    mot["similar"] += 1
                else:
                    mot["contrary"] += 1
            moving = mot["contrary"] + mot["similar"]
            tot = sum(mot.values()) or 1
            f["motion_contrary"] = mot["contrary"] / tot
            f["motion_similar"] = mot["similar"] / tot
            f["motion_oblique"] = mot["oblique"] / tot
            f["motion_static"] = mot["static"] / tot
            f["contrary_of_moving"] = mot["contrary"] / max(1, moving)
        return f

    def run(self):
        d = self.d
        pulse, felt_beats, metre = felt_tempo(self.bpm, self.meter)
        f = dict(name=d["name"], file=d["file"], title=d["title"], cls=d["cls"], bed=d.get("bed", False),
                 length_s=round(self.length, 1), bpm_score=self.bpm, meter_score=self.meter, pulse_bpm=round(pulse, 1),
                 metre=metre, metre_class=metre_class(self.bpm, self.meter), bars=self.nbars,
                 tonic=NAMES[self.tonic_pc], mode=self.mode, majorish=self.mode in MAJORISH)
        tc = d.get("tempo_curve") or []
        f["tempo_var"] = float((np.percentile(tc, 95) - np.percentile(tc, 5)) / np.median(tc)) if len(tc) > 3 else 0.0
        self.layers()
        f["roles"] = self.roles
        mf, m = self.melody_feats()
        f.update(mf)
        f.update(self.texture())
        f.update(self.harmony())
        f.update(self.bass())
        f.update(self.rhythm())
        f.update(self.phrases(m))
        f.update(self.form(m))
        f.update(self.motifs(m))
        f.update(self.dynamics())
        f.update(self.counterpoint(m))
        return f


def faction_job(name, file):
    import re
    if name.endswith("_win") or file.startswith("win_"):
        fac = name.split("_")[0]
        return fac, "win"
    if name == "defeat":
        return "all", "defeat"
    if name.startswith("menu"):
        return "menu", "menu"
    fac = name.split("_")[0]
    roles = {"crown_battle_6": "open", "crown_battle_7": "skirmish", "crown_battle_9": "skirmish",
             "crown_battle_11": "skirmish", "clock_battle_6": "open", "clock_battle_7": "open",
             "clock_battle_8": "skirmish", "clock_battle_9": "skirmish", "clock_battle_10": "skirmish",
             "brood_battle_6": "open", "brood_battle_7": "open", "brood_battle_8": "skirmish",
             "brood_battle_9": "skirmish", "brood_battle_10": "skirmish"}   # = scripts/music.gd ROLES
    open_calm = ["crown_peace", "crown_peace_4", "clock_peace", "brood_peace_4"]
    if name in roles:
        return fac, roles[name]
    if re.search(r"_peace", name):
        return fac, ("calm+open" if name in open_calm else "calm")
    return fac, "battle"


def main():
    src, out = sys.argv[1], sys.argv[2]
    rows = []
    for fn in sorted(os.listdir(src)):
        if not fn.endswith(".json"):
            continue
        d = json.load(open(os.path.join(src, fn)))
        f = Piece(d).run()
        f["faction"], f["job"] = faction_job(d["name"], d["file"])
        rows.append(f)
        print("%-16s %-8s %-9s lead=%-9s hr=%.2f lit=%.2f dev=%s form=%s" % (
            f["name"], f["faction"], f["job"], f.get("mel_inst"), f["harm_rhythm"], f["literal_repeat"],
            "%.2f" % f["motif_development"] if "motif_development" in f else "-", f.get("form_blocks", "")[:24])
              + " nr=%.2f ph=%s sq=%s" % (f["near_repeat"], f.get("phrase_len_median"), f.get("phrase_square")))
    json.dump(rows, open(out, "w"), indent=0, default=float)


if __name__ == "__main__":
    main()
