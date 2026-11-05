#!/usr/bin/env python3
"""The coached games of crown-owner-eco as tables (docs/crown_owner_eco.md).
  python3 -I tools/crown_owner_eco_report.py DIR [NAMES...]
DIR holds one folder per game (tools/play_crown_owner_eco.gd out:), named B_<game> (before: -- owner:off) and A_<game>
(after). Prints markdown: the owner's minutes beside the computer's, then one row per game."""
import os
import re
import sys

OWNER = {  # the owner's Highmoor game (0.30.8, human_crown_v_brood_brute_siege_highmoor_0308.txt): labourers, gold earned, army
    "0400": (25, 2280, 0), "0500": (30, 3800, 240), "0600": (32, 5320, 580), "0700": (38, 6840, 1360), "0800": (42, 8740, 2080),
}


def read(d):
    o = os.path.join(d, "owner.txt")
    if not os.path.exists(o):
        return None
    rows = {}
    extra = ""
    ev = []
    for line in open(o):
        if line.startswith("| 0") or line.startswith("| 1"):
            c = [x.strip() for x in line.strip().strip("|").split("|")]
            rows[c[0]] = c
        elif line.startswith("2nd hall"):
            extra = line.strip()
        elif re.match(r"^\d{4} ", line):
            ev.append(line.strip())
    s = os.path.join(d, "summary.txt")
    summ = open(s).readline().strip() if os.path.exists(s) else ""
    return {"rows": rows, "extra": extra, "ev": ev, "summary": summ}


def cell(r, t, i):
    c = r["rows"].get(t)
    return c[i] if c else "-"


def main():
    base = sys.argv[1]
    names = sys.argv[2:] or sorted({n[2:] for n in os.listdir(base) if n.startswith(("A_", "B_")) and os.path.isdir(os.path.join(base, n))})
    print("| game | 4:00 labs / gold / army | 5:00 | 6:00 | 7:00 | 8:00 | blocked with 300+ gold (s, to 12:00) | first Barracks | 2nd hall | natural closed 5:00 / 6:00 | wall post / cliff edge moves | halls lost | end |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    print("| the owner (Highmoor, by hand) | " + " | ".join("%d / %d / %d" % OWNER[t] for t in ["0400", "0500", "0600", "0700", "0800"]) + " | 0 to 9:00 (then 105-114/126) | 3:29 (after the 2nd hall) | 1:46 (done 2:46) | ring 3:49-5:42 | (at the palisade) | 0 | held 16 min |")
    for n in names:
        for tag in ("B", "A"):
            r = read(os.path.join(base, "%s_%s" % (tag, n)))
            if r is None:
                continue
            snaps = []
            for t in ["0400", "0500", "0600", "0700", "0800"]:
                snaps.append("%s / %s / %s" % (cell(r, t, 1), cell(r, t, 2), cell(r, t, 3)))
            last = sorted(r["rows"].keys())[-1] if r["rows"] else None
            blocked = r["rows"][last][6] if last else "-"
            m = re.search(r"2nd hall laid (\S+) done (\S+) \| first Barracks (\S+) \(([^)]*)\).*natural wall closed 4:00 (\S+) 5:00 (\S+) 6:00 (\S+) 7:00 (\S+) \| wall post moves (\d+) \| edge moves (\d+)", r["extra"])
            hl = re.search(r"halls lost (\d+)", r["summary"])
            end = re.search(r"^end (\S+)", r["summary"])
            win = re.search(r"winner (\S+)", r["summary"])
            if m:
                fb = "%s (%s)" % (m.group(3), m.group(4))
                h2 = m.group(1)
                nat = "%s / %s" % (m.group(6), m.group(7))
                wm = "%s / %s" % (m.group(9), m.group(10))
            else:
                fb = h2 = nat = wm = "-"
            print("| %s %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                n, "before" if tag == "B" else "after", " | ".join(snaps), blocked, fb, h2, nat, wm,
                hl.group(1) if hl else "-", end.group(1) if end else "-"))


if __name__ == "__main__":
    main()
