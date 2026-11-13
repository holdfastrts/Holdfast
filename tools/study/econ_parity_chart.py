#!/usr/bin/env python3
"""ECONOMY PARITY charts (docs/economy_parity.md): the bench curves before and after, and the AI games' income.
    python3 tools/study/econ_parity_chart.py [AFTER_GAMES_DATA_DIR] [BEFORE_GAMES_DATA_DIR]   (this study: docs/economy_parity/games/after and the win-rate study's same 72 tags)
Writes docs/economy_parity/curves.png. Faction colours: the owner's (Crown purple, Clockwork red, Brood green), checked
for colour-blind separation; before = dashed, after = solid, every line labelled at its end."""
import json, os, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
D = os.path.join(ROOT, "docs/economy_parity")
COL = {"crown": "#7b4fc9", "clockwork": "#d0452f", "brood": "#1f8f6a"}
NAME = {"crown": "Crown", "clockwork": "Clockwork", "brood": "Brood"}
INK, MUTED, GRID = "#2b2b2b", "#6b6b6b", "#e6e6e3"


def rows(p):
    return json.load(open(p))["rows"]


def style(ax, title, ylab):
    ax.set_title(title, loc="left", fontsize=11, color=INK, pad=10)
    ax.set_xlabel("game minute", color=MUTED, fontsize=9)
    ax.set_ylabel(ylab, color=MUTED, fontsize=9)
    ax.grid(True, color=GRID, linewidth=0.8)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color("#bdbdb8")
    ax.tick_params(colors=MUTED, labelsize=8)
    ax.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: "{:,.0f}".format(v)))


def label_end(ax, x, y, text, col, dy=0):
    ax.annotate(text, (x, y), xytext=(6, dy), textcoords="offset points", color=INK, fontsize=8, va="center")
    ax.plot([x], [y], "o", color=col, markersize=4)


def main():
    fig, axes = plt.subplots(1, 3, figsize=(16, 5.2), facecolor="#fcfcfb")
    # 1. bench, cumulative value
    ax = axes[0]
    sets = [("crown", "before/fix_crown.json", "before/fix_crown.json"),
            ("clockwork", "before/fix_clockwork.json", "after/fix_clockwork.json"),
            ("brood", "before/nat_brood.json", "before/nat_brood.json")]
    offs = {"crown": 6, "clockwork": -8, "brood": 0}
    for fac, b, a in sets:
        rb, ra = rows(os.path.join(D, b)), rows(os.path.join(D, a))
        xs = [0] + [r["min"] for r in rb]
        if fac == "clockwork":
            ax.plot(xs, [0] + [r["value_cum"] for r in rb], color=COL[fac], lw=1.6, ls=(0, (4, 3)), alpha=0.8)
        ax.plot([0] + [r["min"] for r in ra], [0] + [r["value_cum"] for r in ra], color=COL[fac], lw=2)
        label_end(ax, 15, ra[14]["value_cum"], NAME[fac] + (" after" if fac == "clockwork" else " (unchanged)"), COL[fac], offs[fac])
    ax.set_xlim(0, 20)
    style(ax, "Bench: value earned, cumulative\n(ideal build; dashed = before 0.33.26)", "resources earned (primary + secondary)")
    # 2. bench, per minute, after
    ax = axes[1]
    for fac, b, a in sets:
        ra = rows(os.path.join(D, a))
        ax.plot([r["min"] for r in ra], [r["value"] for r in ra], color=COL[fac], lw=2, label=NAME[fac])
    ax.set_xlim(1, 20)
    ax.legend(frameon=False, fontsize=8, labelcolor=INK)
    style(ax, "Bench after: income per minute\n(Crown, Clockwork: bases at 4, 8, 12 min; Brood 1, 6, 10)", "resources a minute")
    # 3. AI games
    ax = axes[2]
    sys.path.insert(0, os.path.join(ROOT, "tools/study"))
    import econ_parity_report as R
    srcs = []
    if len(sys.argv) > 2:
        srcs.append(("before", sys.argv[2]))
    else:
        srcs.append(("before", os.path.join(ROOT, "docs/qa_2026_11_08_matches/data")))
    if len(sys.argv) > 1:
        srcs.append(("after", sys.argv[1]))
    for tag, src in srcs:
        r = R.analyse(R.load(src))
        for fac in ("crown", "clockwork", "brood"):
            inc = r["income"].get(fac, {})
            ts = sorted(int(t) for t in inc)
            ax.plot([0] + [t / 60 for t in ts], [0] + [inc[t] for t in ts], color=COL[fac], lw=2 if tag == "after" else 1.6,
                    ls="-" if tag == "after" else (0, (4, 3)), alpha=1 if tag == "after" else 0.8)
            if tag == srcs[-1][0]:
                label_end(ax, 15, inc[900], NAME[fac], COL[fac])
    ax.set_xlim(0, 17.5)
    style(ax, "Hard computer games: primary income earned\n(%s)" % ("dashed = before, solid = after" if len(srcs) > 1 else "before"), "resources earned")
    fig.tight_layout()
    out = os.path.join(D, "curves.png")
    fig.savefig(out, dpi=130, facecolor=fig.get_facecolor())
    print(out)


if __name__ == "__main__":
    main()
