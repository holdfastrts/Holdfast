"""Music study (job music-study): compare the game's pieces with the real pieces, make the charts and tables.

Usage: python3 tools/music/study_compare.py SYM.json AUDIO.json OUTDIR
  SYM.json   from study_analyse.py, AUDIO.json from study_audio.py
  OUTDIR     gets the charts (PNG), features.csv, compare.json and tables.md (pasted into the report)
"""
import csv
import json
import math
import os
import sys
from collections import Counter, defaultdict

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import study_refs  # noqa: E402

# the reference palette (dataviz skill, light mode): blue, orange, aqua for the three sides; grey for the rest
COL = {"crown": "#2a78d6", "clock": "#eb6834", "brood": "#1baf7a", "menu": "#8a8984", "ref": "#0b0b0b"}
FAC_NAME = {"crown": "Crown", "clock": "Clockwork", "brood": "Brood", "menu": "Menu", "all": "All"}
SURF, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"

SHARED = ["beat_bpm", "harm_rhythm", "chromatic", "phrase_square", "tune_repeat", "mel_step", "mel_repeat",
          "mel_leap", "mel_range", "lra", "climax_pos", "counter_line_share"]
LABEL = {"beat_bpm": "tempo (beats a minute)", "harm_rhythm": "chord changes a bar", "chromatic": "notes outside the key",
         "phrase_square": "phrases of 2, 4 or 8 bars", "tune_repeat": "tune brought back", "mel_step": "melody steps",
         "mel_repeat": "melody repeated notes", "mel_leap": "melody leaps (a 4th+)", "mel_range": "melody range (semitones)",
         "lra": "loudness range (LU)", "climax_pos": "climax position",
         "counter_line_share": "bars with a counter-melody"}


def style(ax, title=None, xlabel=None, ylabel=None):
    ax.set_facecolor(SURF)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color(GRID)
    ax.tick_params(colors=INK2, labelsize=8)
    ax.grid(True, color=GRID, linewidth=0.6)
    ax.set_axisbelow(True)
    if title:
        ax.set_title(title, color=INK, fontsize=10, loc="left")
    if xlabel:
        ax.set_xlabel(xlabel, color=INK2, fontsize=8)
    if ylabel:
        ax.set_ylabel(ylabel, color=INK2, fontsize=8)


def game_rows(sym, aud):
    rows = []
    for r in sym:
        a = aud.get(r["file"], {})
        g = dict(r)
        for k, v in a.items():
            g["a_" + k] = v
        g["beat_bpm"] = r["pulse_bpm"]
        g["lra"] = a.get("lra")
        # the climax from the audio: the loudest 3 s window of a lightly smoothed short-term loudness curve
        st = np.array(a.get("st_curve") or [0])
        if len(st) > 6:
            sm = np.convolve(st, np.ones(5) / 5, mode="same")
            sm[:2], sm[-2:] = st[:2], st[-2:]
            g["climax_pos"] = float(np.argmax(sm) / (len(sm) - 1))
            q = max(1, len(sm) // 6)
            g["build_db"] = float(sm.max() - np.mean(sm[:q]))
            g["release_db"] = float(sm.max() - np.mean(sm[-q:]))
        else:
            g["climax_pos"] = None
        rows.append(g)
    return rows


def zscale(vals_by_feat):
    out = {}
    for k, v in vals_by_feat.items():
        v = np.array([x for x in v if x is not None], float)
        out[k] = (float(np.mean(v)), float(np.std(v) or 1.0))
    return out


def dist(a, b, sc, feats=SHARED):
    d, n = 0.0, 0
    for k in feats:
        x, y = a.get(k), b.get(k)
        if x is None or y is None:
            d += 1.0      # a missing feature counts as one spread apart (else a piece with no tune looks close)
            n += 1
            continue
        if k == "beat_bpm":
            x, y = math.log2(x), math.log2(y)
            s = 0.5
        else:
            s = sc[k][1]
        d += ((x - y) / s) ** 2
        n += 1
    d = d / max(1, n)
    d += 0.6 * (a.get("metre_class") != b.get("metre_class")) + 0.6 * (bool(a.get("majorish")) != bool(b.get("majorish")))
    return math.sqrt(d)


# craft checks: each compares one measured feature with the span of the real pieces (judgement on the thresholds,
# taken from the reference table's 10th-90th percentiles, rounded)
def checks(g, ref_span):
    res = []

    def chk(name, ok, val):
        res.append((name, bool(ok), val))
    v = g.get("lra")
    chk("loudness range >= 6 LU", v is not None and v >= 6, v)
    v = g.get("climax_pos")
    chk("climax in the last 3/4", v is not None and v >= 0.25, v)
    v = g.get("build_db")
    chk("builds 3+ LU to its climax", v is not None and v >= 3, v)
    lo, hi = ref_span["harm_rhythm"]
    v = g.get("harm_rhythm")
    chk("chord changes in the real range", v is not None and lo <= v <= hi, v)
    v = g.get("chromatic")
    chk("some colour outside the key (3-25%)", v is not None and 0.03 <= v <= 0.25, v)
    v = g.get("mel_step")
    chk("melody mostly steps (40-85%)", v is not None and 0.40 <= v <= 0.85, v)
    v = g.get("mel_leap")
    chk("some leaps (5-45%)", v is not None and 0.05 <= v <= 0.45, v)
    v = g.get("mel_range")
    chk("melody range 12-36", v is not None and 12 <= v <= 36, v)
    v = g.get("tune_repeat")
    chk("tune comes back (20-70%)", v is not None and 0.20 <= v <= 0.70, v)
    v = g.get("phrase_square")
    chk("phrases mostly 2/4/8 bars (>= 50%)", v is not None and v >= 0.5, v)
    v = g.get("bar_rhythm_same_prev")
    chk("rhythm changes bar to bar (< 50% same)", v is not None and v < 0.5, v)
    v = g.get("counter_line_share")
    chk("a counter-melody in 15%+ of bars", v is not None and v >= 0.15, v)
    v = g.get("motif_development")
    chk("motifs moved or varied, not only repeated (>= 40%)", v is not None and v >= 0.4, v)
    v = g.get("cad_total_pm")
    chk("cadences 2+ a minute", v is not None and v >= 2, v)
    return res


def main():
    sym_p, aud_p, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    sym = json.load(open(sym_p))
    aud = json.load(open(aud_p))
    games = game_rows(sym, aud)
    refs = study_refs.refs()
    for r in refs:     # the reference's line count as a rough share of bars with a counter-melody (judgement)
        r["counter_line_share"] = {1: 0.0, 2: 0.15, 3: 0.45, 4: 0.85}[r["indep_lines"]]
    pieces = [g for g in games if g["job"] not in ("win", "defeat")]
    stings = [g for g in games if g["job"] in ("win", "defeat")]
    sc = zscale({k: [r.get(k) for r in refs] + [g.get(k) for g in pieces] for k in SHARED if k != "beat_bpm"})
    ref_span = {k: (float(np.percentile([r[k] for r in refs if r[k] is not None], 10)),
                    float(np.percentile([r[k] for r in refs if r[k] is not None], 90))) for k in SHARED}

    # ---------------------------------------------------- nearest real pieces
    near = {}
    for g in pieces:
        ds = sorted((dist(g, r, sc), r["num"]) for r in refs)
        near[g["name"]] = ds[:3]
    by_num = {r["num"]: r for r in refs}

    # ---------------------------------------------------- craft score
    craft = {}
    for g in pieces:
        c = checks(g, ref_span)
        craft[g["name"]] = (sum(ok for _, ok, _ in c) / len(c), c)

    # ---------------------------------------------------- group summaries (faction x job)
    def jobkey(g):
        return "calm" if g["job"].startswith("calm") else g["job"]
    groups = defaultdict(list)
    for g in pieces:
        groups[(g["faction"], jobkey(g))].append(g)
    summ = {}
    for (fac, job), gs in sorted(groups.items()):
        rg = [r for r in refs if set(r["groups"]) & set(study_refs.JOB_GROUPS[job])]
        cnt = Counter()
        for g in gs:
            for d, num in near[g["name"]]:
                cnt[num] += 1
        means = {k: float(np.mean([g[k] for g in gs if g.get(k) is not None])) if any(g.get(k) is not None for g in gs)
                 else None for k in SHARED}
        rmeans = {k: float(np.mean([r[k] for r in rg if r[k] is not None])) for k in SHARED}
        diffs = sorted(((abs(means[k] - rmeans[k]) / (0.5 if k == "beat_bpm" else sc[k][1]) if k != "beat_bpm"
                         else abs(math.log2(means[k] / rmeans[k])) / 0.5, k) for k in SHARED if means[k] is not None),
                       reverse=True)
        summ[(fac, job)] = dict(n=len(gs), names=[g["name"] for g in gs], closest=cnt.most_common(4), means=means,
                                rmeans=rmeans, ref_names=[r["name"] for r in rg], diffs=diffs[:4])

    # ---------------------------------------------------- hypotheses: game vs refs
    def dstat(vals):
        v = np.array([x for x in vals if x is not None], float)
        return dict(med=float(np.median(v)), p25=float(np.percentile(v, 25)), p75=float(np.percentile(v, 75)), n=len(v))
    hyp = {}
    for k in SHARED + ["beat_bpm"]:
        hyp[k] = dict(game=dstat([g.get(k) for g in pieces]), ref=dstat([r.get(k) for r in refs]),
                      fac={f: dstat([g.get(k) for g in pieces if g["faction"] == f]) for f in ("crown", "clock", "brood", "menu")})
    gextra = {}
    for k in ("bar_rhythm_same_prev", "bar_rhythm_top_share", "motif_development", "motif_literal", "motif_sequence",
              "motif_varied", "motif_new", "chord_vocab", "chord_sevenths", "chord_secdom", "chord_borrowed",
              "chord_power_sus", "key_changes", "cad_total_pm", "cad_auth_pm", "cad_half_pm", "cad_phryg_pm",
              "contrary_of_moving", "motion_contrary", "motion_static", "phrase_len_median", "insts_mean", "voices_mean",
              "notes_per_s", "mel_turns", "mel_distinct_durs", "mel_syncop", "tempo_var", "near_repeat",
              "bass_same", "bass_longest_pedal_bars", "dyn_range_db", "build_db", "release_db", "key_clarity",
              "a_centroid_hz", "a_band_lowmid", "a_band_presence", "a_band_low", "a_side_mid_db", "a_lufs",
              "a_decay_db_100ms", "a_crest_db", "a_start_rel_db", "a_end_rel_db", "a_end_drop_db", "a_tilt_db_oct",
              "a_beat_cv", "a_length_s", "length_s", "form_distinct", "insts_total"):
        gextra[k] = {f: dstat([g.get(k) for g in pieces if g["faction"] == f]) for f in ("crown", "clock", "brood", "menu")}
        gextra[k]["all"] = dstat([g.get(k) for g in pieces])
    forms = {f: Counter(g.get("form_class") for g in pieces if g["faction"] == f) for f in ("crown", "clock", "brood", "menu")}
    metres = {f: Counter(g.get("metre_class") for g in pieces if g["faction"] == f) for f in ("crown", "clock", "brood", "menu")}
    modes = {f: Counter(g.get("mode") for g in pieces if g["faction"] == f) for f in ("crown", "clock", "brood", "menu")}
    tempos = {f: sorted(g["beat_bpm"] for g in pieces if g["faction"] == f) for f in ("crown", "clock", "brood", "menu")}

    # ---------------------------------------------------- clustering: do the pieces group by side?
    FEAT_ALL = ["beat_bpm", "harm_rhythm", "chromatic", "phrase_square", "tune_repeat", "mel_step", "mel_leap",
                "mel_range", "mel_register", "lra", "indep_lines", "chord_sevenths", "chord_power_sus",
                "bar_rhythm_same_prev", "motif_development", "notes_per_s", "insts_mean", "mel_syncop", "tempo_var",
                "a_centroid_hz", "a_band_lowmid", "a_band_presence", "a_side_mid_db", "a_decay_db_100ms",
                "majorish", "dens_drums", "dens_figure", "dens_pad", "key_clarity"]
    fac_pieces = [g for g in pieces if g["faction"] in ("crown", "clock", "brood")]
    X = []
    for g in fac_pieces:
        row = []
        for k in FEAT_ALL:
            v = g.get(k)
            v = float(v) if v is not None else np.nan
            if k == "beat_bpm":
                v = math.log2(v)
            row.append(v)
        X.append(row)
    X = np.array(X)
    col_mean = np.nanmean(X, 0)
    X = np.where(np.isnan(X), col_mean, X)
    Xz = (X - X.mean(0)) / (X.std(0) + 1e-9)
    labels = np.array([g["faction"] for g in fac_pieces])
    D = np.sqrt(((Xz[:, None, :] - Xz[None, :, :]) ** 2).sum(-1))
    # leave-one-out nearest neighbour: is a piece's closest piece from the same side?
    nn_ok = 0
    for i in range(len(Xz)):
        d = D[i].copy()
        d[i] = 1e9
        nn_ok += labels[int(np.argmin(d))] == labels[i]
    nn_acc = nn_ok / len(Xz)
    # silhouette by side
    sil = []
    for i in range(len(Xz)):
        same = [D[i, j] for j in range(len(Xz)) if j != i and labels[j] == labels[i]]
        other = [np.mean([D[i, j] for j in range(len(Xz)) if labels[j] == f]) for f in set(labels) if f != labels[i]]
        a, b = np.mean(same), min(other)
        sil.append((b - a) / max(a, b))
    sil_by = {f: float(np.mean([s for s, l in zip(sil, labels) if l == f])) for f in ("crown", "clock", "brood")}
    within = {f: float(np.mean([D[i, j] for i in range(len(Xz)) for j in range(len(Xz))
                               if i < j and labels[i] == f and labels[j] == f])) for f in ("crown", "clock", "brood")}
    between = float(np.mean([D[i, j] for i in range(len(Xz)) for j in range(len(Xz)) if i < j and labels[i] != labels[j]]))
    # the closest pairs inside a side (pieces that sound alike on paper)
    pairs = sorted((D[i, j], fac_pieces[i]["name"], fac_pieces[j]["name"]) for i in range(len(Xz)) for j in range(i + 1, len(Xz))
                   if labels[i] == labels[j])[:8]
    # which features separate the sides best (F ratio)
    fr = []
    for k, col in zip(FEAT_ALL, Xz.T):
        groups_v = [col[labels == f] for f in ("crown", "clock", "brood")]
        mb = np.mean([len(gv) * (gv.mean() - col.mean()) ** 2 for gv in groups_v]) * 3 / 2
        mw = np.sum([((gv - gv.mean()) ** 2).sum() for gv in groups_v]) / (len(col) - 3)
        fr.append((mb / max(mw, 1e-9), k))
    fr.sort(reverse=True)
    # k-means, 3 groups, against the sides
    rng = np.random.default_rng(3)
    best = None
    for _ in range(30):
        C = Xz[rng.choice(len(Xz), 3, replace=False)]
        for _ in range(50):
            lab = np.argmin(((Xz[:, None] - C[None]) ** 2).sum(-1), 1)
            C = np.array([Xz[lab == k].mean(0) if (lab == k).any() else C[k] for k in range(3)])
        inertia = ((Xz - C[lab]) ** 2).sum()
        if best is None or inertia < best[0]:
            best = (inertia, lab)
    km = {int(k): dict(Counter(labels[best[1] == k])) for k in range(3)}
    # PCA
    U, S, Vt = np.linalg.svd(Xz, full_matrices=False)
    P = Xz @ Vt[:2].T
    var = (S ** 2 / (S ** 2).sum())[:2]

    # ---------------------------------------------------- charts
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.rcParams["font.family"] = "DejaVu Sans"

    # 1. PCA of the game pieces by side
    fig, ax = plt.subplots(figsize=(7.2, 5.2), dpi=150, facecolor=SURF)
    for f, mk in (("crown", "o"), ("clock", "s"), ("brood", "^")):
        sel = labels == f
        ax.scatter(P[sel, 0], P[sel, 1], s=46, marker=mk, color=COL[f], edgecolor=SURF, linewidth=1.5,
                   label=FAC_NAME[f], zorder=3)
    for i, g in enumerate(fac_pieces):
        ax.annotate(g["name"].replace("_battle", " b").replace("_peace", " p").replace("crown", "cr")
                    .replace("clock", "cl").replace("brood", "br"), P[i], fontsize=5.5, color=INK2,
                    xytext=(3, 2), textcoords="offset points")
    style(ax, "The %d faction pieces, measured on %d features and flattened to two (PCA)" % (len(fac_pieces), len(FEAT_ALL)),
          "first component (%d%% of the spread)" % round(var[0] * 100), "second component (%d%%)" % round(var[1] * 100))
    ax.legend(frameon=False, fontsize=8, labelcolor=INK)
    fig.tight_layout()
    fig.savefig(os.path.join(out, "clusters_by_side.png"), facecolor=SURF)
    plt.close(fig)

    # 2. game v real on the shared features (strip charts)
    feats = ["harm_rhythm", "chromatic", "phrase_square", "tune_repeat", "mel_step", "mel_leap", "mel_range", "lra",
             "climax_pos", "counter_line_share"]
    fig, axes = plt.subplots(2, 5, figsize=(12, 5.6), dpi=150, facecolor=SURF)
    cats = [("Real", None), ("Crown", "crown"), ("Clockwork", "clock"), ("Brood", "brood"), ("Menu", "menu")]
    for ax, k in zip(axes.flat, feats):
        for xi, (nm, f) in enumerate(cats):
            vals = [r[k] for r in refs if r[k] is not None] if f is None else [g[k] for g in pieces if g["faction"] == f and g.get(k) is not None]
            jit = np.random.default_rng(xi).uniform(-0.18, 0.18, len(vals))
            ax.scatter(xi + jit, vals, s=10, color=COL["ref"] if f is None else COL[f], alpha=0.75, linewidth=0)
            if vals:
                ax.plot([xi - 0.3, xi + 0.3], [np.median(vals)] * 2, color=INK, linewidth=2)
        ax.set_xticks(range(len(cats)))
        ax.set_xticklabels([c[0] for c in cats], rotation=35, fontsize=7)
        style(ax, LABEL[k])
    fig.suptitle("Real pieces (estimates) against the game's pieces (measured); a bar marks the median",
                 color=INK, fontsize=10, x=0.01, ha="left")
    fig.tight_layout()
    fig.savefig(os.path.join(out, "game_vs_real.png"), facecolor=SURF)
    plt.close(fig)

    # 3. loudness curves: three pieces with the most build and three with the least
    ranked = sorted([g for g in pieces if g.get("build_db") is not None], key=lambda g: g["build_db"])
    fig, axes = plt.subplots(1, 2, figsize=(11, 3.6), dpi=150, facecolor=SURF, sharey=True)
    for ax, sel, title in ((axes[0], ranked[-3:], "The three pieces that build the most"),
                           (axes[1], ranked[:3], "The three that build the least")):
        for g in sel:
            st = np.array(g["a_st_curve"])
            t = np.linspace(0, 1, len(st))
            ax.plot(t, st - st.max(), color=COL[g["faction"]], linewidth=2, label=g["title"])
        style(ax, title, "time through the piece", "short-term loudness below its peak (LU)")
        ax.set_ylim(-25, 2)
        ax.legend(frameon=False, fontsize=7, labelcolor=INK)
    fig.tight_layout()
    fig.savefig(os.path.join(out, "loudness_curves.png"), facecolor=SURF)
    plt.close(fig)

    # 4. loudness range per piece, sorted, against the real pieces' span
    srt = sorted(pieces, key=lambda g: g["lra"])
    fig, ax = plt.subplots(figsize=(12, 3.8), dpi=150, facecolor=SURF)
    ax.bar(range(len(srt)), [g["lra"] for g in srt], color=[COL[g["faction"]] for g in srt], width=0.75)
    lo, hi = ref_span["lra"]
    ax.axhspan(lo, hi, color=GRID, alpha=0.6, zorder=0)
    ax.text(len(srt) - 0.5, hi + 0.3, "the real pieces (10th-90th percentile, estimated)", ha="right", fontsize=7, color=INK2)
    ax.set_xticks(range(len(srt)))
    ax.set_xticklabels([g["name"] for g in srt], rotation=90, fontsize=5.5)
    style(ax, "Loudness range of every piece (LU, measured from the .ogg)", None, "LU")
    from matplotlib.patches import Patch
    ax.legend(handles=[Patch(color=COL[f], label=FAC_NAME[f]) for f in ("crown", "clock", "brood", "menu")],
              frameon=False, fontsize=7, labelcolor=INK, loc="upper left")
    fig.tight_layout()
    fig.savefig(os.path.join(out, "loudness_range.png"), facecolor=SURF)
    plt.close(fig)

    # 5. craft score per piece
    srt = sorted(pieces, key=lambda g: craft[g["name"]][0])
    fig, ax = plt.subplots(figsize=(12, 3.8), dpi=150, facecolor=SURF)
    ax.bar(range(len(srt)), [craft[g["name"]][0] * 14 for g in srt], color=[COL[g["faction"]] for g in srt], width=0.75)
    ax.set_xticks(range(len(srt)))
    ax.set_xticklabels([g["name"] for g in srt], rotation=90, fontsize=5.5)
    style(ax, "How many of the 14 craft checks each piece passes", None, "checks passed")
    ax.legend(handles=[Patch(color=COL[f], label=FAC_NAME[f]) for f in ("crown", "clock", "brood", "menu")],
              frameon=False, fontsize=7, labelcolor=INK, loc="upper left")
    fig.tight_layout()
    fig.savefig(os.path.join(out, "craft_checks.png"), facecolor=SURF)
    plt.close(fig)

    # 6. spectrum balance by side
    fig, ax = plt.subplots(figsize=(7.5, 3.6), dpi=150, facecolor=SURF)
    bands = ["sub", "low", "lowmid", "mid", "presence", "air"]
    w = 0.2
    for i, f in enumerate(("crown", "clock", "brood", "menu")):
        vals = [np.median([g["a_band_" + b] for g in pieces if g["faction"] == f]) * 100 for b in bands]
        ax.bar(np.arange(len(bands)) + (i - 1.5) * w, vals, width=w * 0.9, color=COL[f], label=FAC_NAME[f])
    ax.set_xticks(range(len(bands)))
    ax.set_xticklabels(["20-80 Hz", "80-250", "250-600", "600-2k", "2-5k", "5-16k"], fontsize=7)
    style(ax, "Where the energy sits, median share by side (%)", None, "% of the energy")
    ax.legend(frameon=False, fontsize=7, labelcolor=INK)
    fig.tight_layout()
    fig.savefig(os.path.join(out, "spectrum_by_side.png"), facecolor=SURF)
    plt.close(fig)

    # ---------------------------------------------------- tables and data
    with open(os.path.join(out, "features.csv"), "w", newline="") as fh:
        keys = ["name", "title", "faction", "job", "length_s", "pulse_bpm", "metre", "tonic", "mode", "tempo_var",
                "mel_inst", "mel_range", "mel_register", "mel_step", "mel_repeat", "mel_leap", "mel_syncop",
                "mel_distinct_durs", "notes_per_s", "insts_mean", "voices_mean", "harm_rhythm", "chord_vocab",
                "chord_sevenths", "chord_secdom", "chord_borrowed", "chord_power_sus", "chromatic", "key_est",
                "key_changes", "cad_total_pm", "cad_auth_pm", "cad_half_pm", "cad_phryg_pm", "phrase_len_median",
                "phrase_square", "tune_repeat", "form_blocks", "form_class", "motif_development", "bar_rhythm_same_prev",
                "indep_lines", "contrary_of_moving", "bass_same", "bass_longest_pedal_bars", "lra", "climax_pos",
                "build_db", "release_db", "a_lufs", "a_true_peak_dbtp", "a_centroid_hz", "a_band_lowmid",
                "a_band_presence", "a_side_mid_db", "a_decay_db_100ms", "a_start_rel_db", "a_end_rel_db",
                "a_end_drop_db", "craft"]
        wr = csv.writer(fh)
        wr.writerow(keys)
        for g in sorted(games, key=lambda g: g["name"]):
            g = dict(g)
            g["craft"] = round(craft[g["name"]][0] * 14) if g["name"] in craft else ""
            wr.writerow([round(g[k], 3) if isinstance(g.get(k), float) else g.get(k, "") for k in keys])

    comp = dict(near={k: [(round(d, 2), by_num[n]["name"]) for d, n in v] for k, v in near.items()},
                craft={k: dict(score=round(v[0] * 14), failed=[(n, None if x is None else round(float(x), 2))
                                                                for n, ok, x in v[1] if not ok]) for k, v in craft.items()},
                groups={"%s/%s" % k: dict(v, closest=[(by_num[n]["name"], c) for n, c in v["closest"]],
                                          diffs=[(round(d, 2), k2) for d, k2 in v["diffs"]]) for k, v in summ.items()},
                hyp=hyp, extra=gextra, forms={f: dict(c) for f, c in forms.items()},
                metres={f: dict(c) for f, c in metres.items()}, modes={f: dict(c) for f, c in modes.items()},
                tempos=tempos, nn_acc=nn_acc, silhouette=sil_by, within=within, between=between,
                alike=[(round(d, 2), a, b) for d, a, b in pairs], separating=[(round(f, 2), k) for f, k in fr[:10]],
                weakest_sep=[(round(f, 2), k) for f, k in fr[-6:]], kmeans=km, pca_var=[float(v) for v in var],
                stings={g["name"]: dict(lufs=g.get("a_lufs"), length=g.get("a_length_s"), lra=g.get("lra")) for g in stings},
                ref_span=ref_span)
    json.dump(comp, open(os.path.join(out, "compare.json"), "w"), indent=1, default=float)
    print("nn accuracy %.2f  silhouette %s  within %s between %.2f" % (nn_acc, sil_by, within, between))
    print("separating", fr[:8])
    print("kmeans", km)


if __name__ == "__main__":
    main()
