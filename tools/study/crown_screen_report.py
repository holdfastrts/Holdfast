#!/usr/bin/env python3
"""CROWN RIDER SCREEN (docs/crown_rider_screen.md): the measuring tables of batches made with
tools/study/crown_line_fight.py (one folder per game: result.json, engage.json, crownlog.txt and, from crown-rider-screen,
screen.json). A measuring tool: it changes no rule.
    python3 tools/study/crown_screen_report.py DATA [DATA2 ...] [--same]
For each DATA: tools/study/crown_line_report.py's tables (results, fights, the line's log lines), then the screen's:
  - away fights (the waves: more than 900 px from all Crown halls): how many; FORMED = the line was formed when the fight
    began (engage.json "prev_st", the line's state just before: form / step / set / advance / back; only in batches
    filmed with the crown-rider-screen film_line.gd); the line's log lines' share "formed before an army" of (that +
    "deployed under fire"), which every batch has; WARNING = the median of the fights' "warn" (how long the enemy
    soldiers in it had been in sight, s) and the share with 5 s or more; the trade (killed / lost) and the shooters
    firing in the first 5 s;
  - home fights: the same warning;
  - the screen (screen.json): riders sent, riders lost on the screen, pickets lost, the line formed on the screen's
    sightings, the picket's warnings, the flank work's rides."""
import json, sys, os, re, statistics as S
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import crown_line_report as R

FORMED = ("form", "step", "set", "advance", "back")


def screen_rows(rows, key, data_of):
    sel = [x for x in rows if ('_%s_' % key) in x[0]]
    if not sel:
        return None
    out = dict(games=len(sel), away=0, formed=0, has_st=0, warn=[], warn_home=[], k=0, l=0, fired=0, n5=0, sent=0, lost=0,
               plost=0, sight=0, warns=0, flank=0, f_army=0, deploy=0)
    for name, r, E in sel:
        crown = set(R.crown_sides(r))
        for e in E:
            if e['team'] not in crown:
                continue
            if e['home']:
                if 'warn' in e:
                    out['warn_home'].append(e['warn'])
                continue
            out['away'] += 1
            out['k'] += e['killed']
            out['l'] += e['lost']
            if e['n'] >= 4 and e['fired5'] >= 0:
                out['fired'] += e['fired5']
                out['n5'] += e['n']
            if 'prev_st' in e:
                out['has_st'] += 1
                if e['prev_st'] in FORMED:
                    out['formed'] += 1
            if 'warn' in e:
                out['warn'].append(e['warn'])
        f = os.path.join(data_of[name], name, 'screen.json')
        if os.path.exists(f):
            sc = json.load(open(f))
            for t in crown:
                s = sc.get(str(t))
                if s:
                    out['sent'] += s['sent']
                    out['lost'] += s['lost']
                    out['plost'] += s['picket_lost']
                    out['sight'] += s['sightings']
                    out['warns'] += len(s['warns'])
                    out['flank'] += s['flank_hits']
        lg = os.path.join(data_of[name], name, 'crownlog.txt')
        if os.path.exists(lg):
            t = open(lg, errors='replace').read()
            out['f_army'] += len(re.findall(r"forms its line before the enemy army ahead", t))
            out['deploy'] += len(re.findall(r"deploy into a line", t))
    return out


def pct(a, b):
    return '%d%%' % (100 * a / b) if b else '-'


def med(v):
    return '%.1f' % S.median(v) if v else '-'


if __name__ == '__main__':
    dirs = [a for a in sys.argv[1:] if not a.startswith('--')]
    keep = None
    if '--same' in sys.argv:
        keep = set.intersection(*[set(n for n, _, _ in R.load(d)) for d in dirs])
    for d in dirs:
        rows = [x for x in R.load(d) if keep is None or x[0] in keep]
        data_of = {x[0]: d for x in rows}
        R.DATA_OF.update(data_of)
        print('## %s (%d games)' % (d, len(rows)))
        print()
        print('| matchup | games | Crown W-D-L | won or led | army 8:00 | 10:00 | income 8:00 | 10:00 | Crown halls lost / game |')
        print('|---|---|---|---|---|---|---|---|---|')
        for key, nm in R.KEYS:
            t = R.table(rows, key)
            if t:
                print('| %s | %d | %d-%d-%d | %d of %d | %d | %d | %d | %d | %.2f |' % (nm, t['games'], t['won'], t['draw'], t['lost'],
                      t['led'], t['sides'], t['a8'], t['a10'], t['i8'], t['i10'], t['halls']))
        print()
        print('| matchup | away fights | formed when it began | line log: formed before an army / (that + deployed under fire) | warning (median s), 5 s or more | killed / lost (ratio) | firing in 5 s | home fights: warning (median s) |')
        print('|---|---|---|---|---|---|---|---|')
        for key, nm in R.KEYS:
            s = screen_rows(rows, key, data_of)
            if s:
                w5 = sum(1 for w in s['warn'] if w >= 5.0)
                print('| %s | %d | %s | %d / %d (%s) | %s, %s | %d / %d (%.2f) | %s | %s |' % (nm, s['away'],
                      ('%d of %d (%s)' % (s['formed'], s['has_st'], pct(s['formed'], s['has_st']))) if s['has_st'] else '-',
                      s['f_army'], s['f_army'] + s['deploy'], pct(s['f_army'], s['f_army'] + s['deploy']),
                      med(s['warn']), pct(w5, len(s['warn'])) if s['warn'] else '-', s['k'], s['l'], s['k'] / max(1, s['l']),
                      pct(s['fired'], s['n5']), med(s['warn_home'])))
        print()
        print('| matchup | riders sent to the screen | lost on the screen | pickets lost | the line formed on the screen\'s sighting | picket warnings | flank rides |')
        print('|---|---|---|---|---|---|---|')
        for key, nm in R.KEYS:
            s = screen_rows(rows, key, data_of)
            if s:
                print('| %s | %d | %d | %d | %d | %d | %d |' % (nm, s['sent'], s['lost'], s['plost'], s['sight'], s['warns'], s['flank']))
        print()
        print('| matchup | ' + ' | '.join(nm for nm, _ in R.LINES) + ' |')
        print('|---|' + '---|' * len(R.LINES))
        for key, nm in R.KEYS:
            c = R.lines(rows, key)
            if c:
                print('| %s | ' % nm + ' | '.join(str(c.get(n, 0)) for n, _ in R.LINES) + ' |')
        print()
