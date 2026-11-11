#!/usr/bin/env python3
"""CROWN V CROWN COACH (docs/crown-v-crown-coach.md): the measuring table of a batch of Crown mirror games made with
tools/film_coach.gd (one folder per game with result.json and log.txt). A measuring tool: it changes no rule.
    python3 tools/study/crown_v_crown_report.py DIR [DIR2 ...]   (one table row per DIR)"""
import json, sys, glob, os, re, statistics as S


def game_rows(d):
    out = []
    for f in sorted(glob.glob(os.path.join(d, '*', 'result.json'))):
        r = json.load(open(f))
        m = {(x['t'], x['p']): x for x in r['minutes']}
        fin = {x['p']: x for x in r['final']}
        sc = {p: fin[p]['income'] + 2 * fin[p]['army'] for p in (0, 1)}
        log = open(os.path.join(os.path.dirname(f), 'log.txt'), errors='replace').read()
        halls = [e for e in r['events'] if e['ev'] == 'hall_lost']
        dom = conv = 0
        for t in range(360, r['end'] + 1, 60):
            for p in (0, 1):
                a, b = m.get((t, p)), m.get((t, 1 - p))
                if a and b and a['army'] >= 800 and a['army'] >= 1.8 * max(1, b['army']):
                    dom += 1
                    if any(e['p'] == 1 - p and t <= e['t'] <= t + 180 for e in halls):
                        conv += 1
        waves = len(re.findall(r"(first attack goes out|wave \d+ goes out)", log))
        pulls = len(re.findall(r"pulls its wave back|Crown pulls back from the ", log))
        out.append(dict(name=os.path.basename(os.path.dirname(f)), end=r['end'], winner=r['winner'],
                        lead=(0 if sc[0] > 1.1 * sc[1] else 1 if sc[1] > 1.1 * sc[0] else -1) if r['winner'] < 0 else r['winner'],
                        m=m, halls=len(halls), dom=dom, conv=conv, waves=waves, pulls=pulls,
                        lost=[fin[p]['lost'] for p in (0, 1)]))
    return out


def ratio(rows, t, key):
    v = []
    for g in rows:
        a, b = g['m'].get((t, 0)), g['m'].get((t, 1))
        if a and b:
            hi, lo = max(a[key], b[key]), min(a[key], b[key])
            v.append(hi / max(1, lo))
    return S.median(v) if v else float('nan')


def mean_of(rows, t, key):
    v = []
    for g in rows:
        for p in (0, 1):
            x = g['m'].get((t, p))
            if x:
                v.append(x[key])
    return S.mean(v) if v else float('nan')


if __name__ == '__main__':
    print('| batch | games | decided (P1-P2) | P1 won or led | decided by | median length decided | army 8:00 | 10:00 | income 8:00 | 10:00 | lead ratio army 10:00 (median) | halls lost / game | waves / game | pull-backs / game | dominant minutes -> enemy hall lost in 3 min |')
    print('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
    for d in sys.argv[1:]:
        rows = game_rows(d)
        dec = [g for g in rows if g['winner'] >= 0]
        p1 = sum(1 for g in rows if g['lead'] == 0)
        lens = [g['end'] for g in dec]
        by = sum(1 for g in dec if g['end'] < 900)
        print('| %s | %d | %d (%d-%d) | %d | %s | %s | %.0f | %.0f | %.0f | %.0f | %.2f | %.1f | %.1f | %.1f | %d -> %d |' % (
            os.path.basename(d.rstrip('/')), len(rows), len(dec), sum(1 for g in dec if g['winner'] == 0), sum(1 for g in dec if g['winner'] == 1), p1,
            '%d before 15:00' % by, ('%d:%02d' % divmod(int(S.median(lens)), 60)) if lens else '-',
            mean_of(rows, 480, 'army'), mean_of(rows, 600, 'army'), mean_of(rows, 480, 'income'), mean_of(rows, 600, 'income'),
            ratio(rows, 600, 'army'), S.mean(g['halls'] for g in rows), S.mean(g['waves'] for g in rows), S.mean(g['pulls'] for g in rows),
            sum(g['dom'] for g in rows), sum(g['conv'] for g in rows)))
