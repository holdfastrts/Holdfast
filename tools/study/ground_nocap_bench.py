#!/usr/bin/env python3
"""NO FARM/PRESS LIMIT, the economy benches (ground-nocap-study, docs/ground_nocap_study.md):
    python3 tools/study/ground_nocap_bench.py DIR
DIR holds tools/econ_bench.gd runs bench_<faction>_<map>_d<N>.json/.out (the scripted ideal build, ground ON, N Farms /
Presses a hall; d2 = the limit kept) and tools/econ_ai_alone.gd runs alone_<faction>_<map>_<kept|drop>.json/.out (the Hard
OPTIMAL computer alone). Prints the income earned by 5/8/10/12/15 min (cumulative), as a share of the kept arm, the halls
and when each district ran dry (the bench's '(ground)' lines: a spent Farm / Press pulled down with its district under 5%)."""
import json, os, re, sys

MINS = [5, 8, 10, 12, 15]


def cum(rows, m, key="p_cum"):
    r = [x for x in rows if x["min"] == m]
    return r[0][key] if r else None


def dry_times(out):
    first = {}
    if not os.path.exists(out):
        return []
    for l in open(out, errors="replace"):
        m = re.search(r"\(ground\) (\d+) s: a spent \S+ at .* district \[([\d.e+-]+), ([\d.e+-]+)\]", l)
        if m:
            t, left, full = int(m.group(1)), float(m.group(2)), float(m.group(3))
            key = round(full)
            if left < 0.05 * full and key not in first:
                first[key] = t
    return sorted(first.values())


def mmss(t):
    return "%d:%02d" % (t // 60, t % 60)


def load(p):
    try:
        return json.load(open(p))
    except Exception:
        return None


def main(d):
    print("## The scripted bench (ideal build, ground ON): income earned by m:00 (cumulative), N Farms / Presses a hall\n")
    print("| faction, map | N | " + " | ".join("%d:00" % m for m in MINS + [20]) + " | halls at 20:00 | districts dry at |")
    print("|---|---|" + "---|" * (len(MINS) + 1) + "---|---|")
    for f in ("crown", "clockwork"):
        for mp in ("greenhold", "hollowfen"):
            base = load(os.path.join(d, "bench_%s_%s_d2.json" % (f, mp)))
            for n in (2, 3, 4):
                j = load(os.path.join(d, "bench_%s_%s_d%d.json" % (f, mp, n)))
                if not j:
                    continue
                cells = []
                for m in MINS + [20]:
                    v = cum(j["rows"], m, "value_cum")
                    b = cum(base["rows"], m, "value_cum") if base else None
                    cells.append(("%d" % v + (" (%.2f)" % (v / b) if b and n != 2 else "")) if v is not None else "-")
                last = j["rows"][-1]
                dts = dry_times(os.path.join(d, "bench_%s_%s_d%d.out" % (f, mp, n)))
                print("| %s, %s | %d | %s | %s | %s |" % (f.capitalize(), mp, n, " | ".join(cells), last["econ"].get("halls", "-"),
                      ", ".join(mmss(t) for t in dts) or "-"))
    print("\n## The computer alone (Hard OPTIMAL, nobody in its way, ground ON): income earned by m:00, limit kept v dropped\n")
    print("| faction, map | arm | " + " | ".join("%d:00" % m for m in MINS) + " | halls up at | workers 15:00 | Farms/Presses 15:00 |")
    print("|---|---|" + "---|" * len(MINS) + "---|---|---|")
    for f in ("crown", "clockwork"):
        for mp in ("greenhold", "hollowfen"):
            kept = load(os.path.join(d, "alone_%s_%s_kept.json" % (f, mp)))
            for arm in ("kept", "drop"):
                j = load(os.path.join(d, "alone_%s_%s_%s.json" % (f, mp, arm)))
                if not j:
                    continue
                cells = []
                for m in MINS:
                    v = cum(j["rows"], m, "value_cum")
                    b = cum(kept["rows"], m, "value_cum") if kept else None
                    cells.append(("%d" % v + (" (%.2f)" % (v / b) if b and arm == "drop" else "")) if v is not None else "-")
                last = j["rows"][-1]
                ek = "farm" if f == "crown" else "cog_press"
                print("| %s, %s | %s | %s | %s | %d | %s |" % (f.capitalize(), mp, "dropped" if arm == "drop" else "kept", " | ".join(cells),
                      ", ".join(mmss(int(t)) for t in j.get("halls_at", [])), last["workers"], last["econ"].get(ek, "-")))


if __name__ == "__main__":
    main(sys.argv[1])
