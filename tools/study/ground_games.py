#!/usr/bin/env python3
"""GROUND SYSTEM games (ground-system, docs/ground_system.md): compares a batch of Hard OPTIMAL v Hard OPTIMAL games with
the setting OFF against the same tags with it ON (`qa_matches.py --only ground`): per matchup the result (W-D-L of the
first-named), the income each side earned (primary), and the game length.
    python3 tools/study/ground_games.py OFF_DATA ON_DATA
Single games are noisy; read the totals."""
import json, os, sys, statistics as st
SH = {"crown": "cr", "brood": "br", "clockwork": "cw"}
PAIR_ORDER = ["crbr", "crcw", "brcw", "crcr", "brbr", "cwcw"]


def games(d):
    out = {}
    if not os.path.isdir(d):
        return out
    for tag in sorted(os.listdir(d)):
        f = os.path.join(d, tag, "result.json")
        if os.path.exists(f):
            out[tag] = json.load(open(f))
    return out


def at(rows, p, t):
    r = [x for x in rows if x["p"] == p and x["t"] == t]
    return r[0]["income"] if r else None


def pair_of(tag):
    return tag.split("_")[-2]


def summarise(data, label):
    # per pairing key (ordered, P1's view): W-D-L, income ratio at points, lengths
    by = {}
    for tag, d in data.items():
        facs = [s[0] for s in d["slots"]]
        pk = pair_of(tag)
        b = by.setdefault(pk, {"n": 0, "w": 0, "dr": 0, "l": 0, "len": [], "inc": {m: [[], []] for m in (5, 8, 10, 15)}})
        b["n"] += 1
        if not d["over"]:
            b["dr"] += 1
        elif d["winner"] == 0:
            b["w"] += 1
        else:
            b["l"] += 1
        b["len"].append(d["end"])
        for m in (5, 8, 10, 15):
            for p in (0, 1):
                v = at(d["minutes"], p, m * 60)
                if v is not None:
                    b["inc"][m][p].append(v)
    return by


def main(off_dir, on_dir):
    off = games(off_dir)
    on = games(on_dir)
    print("# Ground system: Hard OPTIMAL games, the setting OFF vs ON (%d off, %d on)\n" % (len(off), len(on)))
    bo = summarise(off, "off")
    bn = summarise(on, "on")
    print("| matchup (P1 view) | W-D-L off | W-D-L on | income ratio P1/P2 10:00 off / on | median length off / on |")
    print("|---|---|---|---|---|")
    for pk in PAIR_ORDER:
        o = bo.get(pk)
        n = bn.get(pk)
        if not o and not n:
            continue
        def wdl(b):
            return "%d-%d-%d" % (b["w"], b["dr"], b["l"]) if b else "-"
        def ratio(b):
            if not b or not b["inc"][10][0] or not b["inc"][10][1]:
                return "-"
            a = st.mean(b["inc"][10][0]); c = st.mean(b["inc"][10][1])
            return "%.2f" % (a / c) if c else "-"
        def length(b):
            return "%d:%02d" % (int(st.median(b["len"])) // 60, int(st.median(b["len"])) % 60) if b and b["len"] else "-"
        lab = pk[:2] + " v " + pk[2:]
        print("| %s | %s | %s | %s / %s | %s / %s |" % (lab, wdl(o), wdl(n), ratio(o), ratio(n), length(o), length(n)))
    # totals: income earned, all games, each side pooled
    print("\nIncome earned (all games pooled, both sides), primary:\n")
    print("| | 5:00 | 8:00 | 10:00 | 15:00 |")
    print("|---|---|---|---|---|")
    for data, lab in ((off, "off"), (on, "on")):
        row = [lab]
        for m in (5, 8, 10, 15):
            vals = []
            for d in data.values():
                for p in (0, 1):
                    v = at(d["minutes"], p, m * 60)
                    if v is not None:
                        vals.append(v)
            row.append("%d" % int(st.mean(vals)) if vals else "-")
        print("| %s |" % " | ".join(row))
    # decided games and median length overall
    for data, lab in ((off, "off"), (on, "on")):
        dec = [d["end"] for d in data.values() if d["over"]]
        allg = [d["end"] for d in data.values()]
        print("\n%s: %d of %d games decided; median length %d:%02d (decided %d:%02d)" % (
            lab, len(dec), len(data), int(st.median(allg)) // 60 if allg else 0, int(st.median(allg)) % 60 if allg else 0,
            int(st.median(dec)) // 60 if dec else 0, int(st.median(dec)) % 60 if dec else 0))
    # errors
    for data, lab in ((off, "off"), (on, "on")):
        errs = 0
        for tag in data:
            ef = os.path.join(off_dir if lab == "off" else on_dir, tag, "errors.txt")
            if os.path.exists(ef) and os.path.getsize(ef) > 0:
                errs += 1
        print("%s: %d games with a logged error" % (lab, errs))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
