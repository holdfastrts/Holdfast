#!/usr/bin/env python3
"""CROWN LINE FIGHT (docs/crown_line_fight.md): the measuring table of a batch made with tools/study/crown_line_fight.py
(one folder per game: result.json, engage.json). A measuring tool: it changes no rule.
    python3 tools/study/crown_line_report.py DATA [DATA2 ...] [--same]  (a block per DATA: per matchup, then the fights;
        --same: only the games every DATA has)
Per matchup (the Crown's side; in the mirror both sides): games, the Crown won / lost / drew, won-or-led (a draw is led
when income + 2 x army at the end is 10% over the other's), army and income at 8:00 and 10:00 (means), Crown halls lost
a game. The fights (engage.json, every engagement of a Crown army worth 60+ in losses): how many, value killed / lost
(all of them summed), the share of the shooters near the contact that fired in the first 5 s, the median shape at
contact (across / depth, px), the share of guns there that were set up and behind the shooters, and the fights won (killed
> lost)."""
import json, sys, glob, os, statistics as S

KEYS = [("crbr", "v Brood"), ("crcw", "v Clockwork"), ("crcr", "mirror")]


def load(d):
    out = []
    for f in sorted(glob.glob(os.path.join(d, '*', 'result.json'))):
        r = json.load(open(f))
        g = os.path.dirname(f)
        e = json.load(open(os.path.join(g, 'engage.json'))) if os.path.exists(os.path.join(g, 'engage.json')) else []
        out.append((os.path.basename(g), r, e))
    return out


def crown_sides(r):
    return [s[2] if len(s) > 2 else i for i, s in enumerate(r['slots']) if s[0] == 'crown']


def table(rows, key):
    sel = [x for x in rows if ('_%s_' % key) in x[0]]
    if not sel:
        return None
    won = lost = draw = led = 0
    halls = 0
    a8, a10, i8, i10 = [], [], [], []
    for name, r, _ in sel:
        sides = crown_sides(r)
        fin = {x['p']: x for x in r['final']}
        m = {(x['t'], x['p']): x for x in r['minutes']}
        for p in sides:
            q = 1 - p
            if r['winner'] == p:
                won += 1
                led += 1
            elif r['winner'] == q:
                lost += 1
            else:
                draw += 1
                sp = fin[p]['income'] + 2 * fin[p]['army']
                sq = fin[q]['income'] + 2 * fin[q]['army']
                if sp > 1.1 * sq:
                    led += 1
            halls += len([e for e in r['events'] if e['ev'] == 'hall_lost' and e['p'] == p])
            for t, a, i in ((480, a8, i8), (600, a10, i10)):
                x = m.get((t, p))
                if x:
                    a.append(x['army'])
                    i.append(x['income'])
    n = sum(len(crown_sides(r)) for _, r, _ in sel)
    mean = lambda v: int(S.mean(v)) if v else 0
    return dict(games=len(sel), sides=n, won=won, lost=lost, draw=draw, led=led, a8=mean(a8), a10=mean(a10), i8=mean(i8),
                i10=mean(i10), halls=halls / max(1, n))


def fights(rows, key):
    es = [e for name, r, E in rows if ('_%s_' % key) in name for e in E]
    if not es:
        return None
    k = sum(e['killed'] for e in es)
    l = sum(e['lost'] for e in es)
    sh = [e for e in es if e['n'] >= 4 and e['fired5'] >= 0]
    fired = sum(e['fired5'] for e in sh) / max(1, sum(e['n'] for e in sh))
    big = [e for e in es if e['n'] >= 6]
    across = S.median([e['across'] for e in big]) if big else 0
    depth = S.median([e['depth'] for e in big]) if big else 0
    wide = sum(1 for e in big if e['across'] > 1.5 * max(10, e['depth'])) / max(1, len(big))
    guns = [g for e in es for g in e['guns']]
    gset = sum(1 for g in guns if g['set']) / max(1, len(guns))
    gbeh = sum(1 for g in guns if g['behind']) / max(1, len(guns))
    gfired = sum(e['guns_fired'] for e in es) / max(1, len(guns))
    won = sum(1 for e in es if e['killed'] > e['lost'])
    out_ = [e for e in es if not e['home']]
    ko = sum(e['killed'] for e in out_)
    lo = sum(e['lost'] for e in out_)
    return dict(n=len(es), k=k, l=l, ratio=k / max(1, l), fired=fired, across=across, depth=depth, wide=wide, guns=len(guns),
                gset=gset, gbeh=gbeh, gfired=gfired, won=won, out=len(out_), ratio_out=ko / max(1, lo))


if __name__ == '__main__':
    dirs = [a for a in sys.argv[1:] if not a.startswith('--')]
    keep = None
    if '--same' in sys.argv:
        # (only the games every batch has: a batch still running is compared on what it has)
        keep = set.intersection(*[set(n for n, _, _ in load(d)) for d in dirs])
    for d in dirs:
        rows = [x for x in load(d) if keep is None or x[0] in keep]
        print('## %s (%d games)' % (d, len(rows)))
        print()
        print('| matchup | games | Crown W-D-L | won or led | army 8:00 | 10:00 | income 8:00 | 10:00 | Crown halls lost / game |')
        print('|---|---|---|---|---|---|---|---|---|')
        for key, nm in KEYS:
            t = table(rows, key)
            if t:
                print('| %s | %d | %d-%d-%d | %d of %d | %d | %d | %d | %d | %.2f |' % (nm, t['games'], t['won'], t['draw'], t['lost'],
                      t['led'], t['sides'], t['a8'], t['a10'], t['i8'], t['i10'], t['halls']))
        print()
        print('| matchup | fights | killed / lost (ratio) | away from home: fights, ratio | won | shooters firing in the first 5 s | shape at contact across / depth (median, 6+ shooters) | in a line (across > 1.5 depth) | guns near: set up / behind / fired |')
        print('|---|---|---|---|---|---|---|---|---|')
        for key, nm in KEYS:
            f = fights(rows, key)
            if f:
                print('| %s | %d | %d / %d (%.2f) | %d, %.2f | %d | %d%% | %d / %d | %d%% | %d: %d%% / %d%% / %d%% |' % (nm, f['n'], f['k'], f['l'], f['ratio'],
                      f['out'], f['ratio_out'], f['won'], 100 * f['fired'], f['across'], f['depth'], 100 * f['wide'], f['guns'],
                      100 * f['gset'], 100 * f['gbeh'], 100 * f['gfired']))
        print()
