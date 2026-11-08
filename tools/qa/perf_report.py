#!/usr/bin/env python3
"""qa-perf (0.33.8): tables from tools/qa/perf_matrix.sh's CSVs (docs/qa_2026_11_08_perf.md).
    python3 tools/qa/perf_report.py docs/perf/qa/before [docs/perf/qa/after]
Prints markdown: per map (units, game tick ms avg / p95 / max at minutes 5, 10 and the last, frames, memory),
the minute-by-minute average over all maps, and where the tick's time goes late in the game."""
import csv, glob, os, sys

SKIP = {'min', 'frames', 'avg_ms', 'fps', 'low1_fps', 'worst_ms', 'over33', 'over50', 'n_units', 'n_buildings', 'n_bodies',
        'n_effects', 'n_projectiles', 'floats', 'pings', 'nodes', 'objects', 'orphans', 'draw_calls', 'mem_mb', 'log_lines',
        'wall_s', 'cpu_s', 'paths', 'paths_shared', 'worst_frame_zones', 'tick_n', 'tick_avg', 'tick_p95', 'tick_max',
        'rss_mb', 'mem_static_mb', 'tex_mb', 'vid_mb', 'resources', 'n_dead_units', 'replay_kb', 'replay_frames_buf'}


def load(d):
    out = {}
    for f in sorted(glob.glob(os.path.join(d, '*.csv'))):
        rows = list(csv.DictReader(open(f)))
        if rows:
            out[os.path.basename(f)[:-4]] = rows
    return out


def at(rows, m):
    for r in rows:
        if int(r['min']) == m:
            return r
    return None


def fl(r, k, d=0.0):
    try:
        return float(r[k])
    except (KeyError, TypeError, ValueError):
        return d


def main():
    a = load(sys.argv[1])
    b = load(sys.argv[2]) if len(sys.argv) > 2 else None
    print('| map | ends | units 5 / 10 / last | tick ms 5:00 | tick ms 10:00 | tick ms last (avg / p95 / max) | fps last | 1% low last | worst frame ms | RSS MB 1 -> last |')
    print('|---|---|---|---|---|---|---|---|---|---|')
    for m, rows in a.items():
        last = rows[-1]
        r5, r10 = at(rows, 5), at(rows, 10)
        wf = max(fl(r, 'worst_ms') for r in rows)
        def tk(r):
            return '%.1f' % fl(r, 'tick_avg') if r else '-'
        print('| %s | %s:00 | %s / %s / %s | %s | %s | %.1f / %.1f / %.0f | %.0f | %.0f | %.0f | %.0f -> %.0f |' % (
            m, last['min'], r5['n_units'] if r5 else '-', r10['n_units'] if r10 else '-', last['n_units'], tk(r5), tk(r10),
            fl(last, 'tick_avg'), fl(last, 'tick_p95'), fl(last, 'tick_max'), fl(last, 'fps'), fl(last, 'low1_fps'), wf,
            fl(rows[0], 'rss_mb'), fl(last, 'rss_mb')))
    print()
    print('Minute by minute, the average over the maps still playing:')
    print()
    print('| minute | maps | units | tick ms avg | tick ms p95 | tick ms max | us a unit a tick | units ms/frame | ai | game | buildings | hud+draw | replay |')
    print('|---|---|---|---|---|---|---|---|---|---|---|---|---|')
    for mi in range(1, 16):
        rs = [at(rows, mi) for rows in a.values()]
        rs = [r for r in rs if r]
        if not rs:
            continue
        n = len(rs)
        u = sum(fl(r, 'n_units') for r in rs) / n
        t = sum(fl(r, 'tick_avg') for r in rs) / n
        hud = sum(fl(r, 'hud') + fl(r, 'hud draw') + fl(r, 'unit draw') + fl(r, 'building draw') + fl(r, 'overlay draw') for r in rs) / n
        print('| %d | %d | %.0f | %.2f | %.2f | %.1f | %.0f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |' % (
            mi, n, u, t, sum(fl(r, 'tick_p95') for r in rs) / n, sum(fl(r, 'tick_max') for r in rs) / n,
            1000.0 * t / max(u, 1.0), sum(fl(r, 'units') for r in rs) / n, sum(fl(r, 'ai') for r in rs) / n,
            sum(fl(r, 'game') for r in rs) / n, sum(fl(r, 'buildings') for r in rs) / n, hud, sum(fl(r, 'replay/record') for r in rs) / n))
    print()
    print('Where the time goes in each map\'s last minute (ms a frame, the biggest parts):')
    print()
    for m, rows in a.items():
        last = rows[-1]
        z = [(fl(last, k), k) for k in last if k not in SKIP and not k.startswith('med ') and '/' not in k or k in ('game/fog', 'game/gears', 'game/paths', 'game/unit grid', 'game/econ', 'ai/brood', 'ai/army', 'ai/build', 'ai/workers', 'hud/look', 'silhouettes', 'replay/record', 'autosave')]
        z = [x for x in z if x[0] >= 0.05]
        z.sort(reverse=True)
        print('- %s (%s:00, %s units): %s' % (m, last['min'], last['n_units'], ', '.join('%s %.2f' % (k, v) for v, k in z[:10])))
    if b:
        print()
        print('Before and after (the same match; tick ms average over the whole game, the last minute, worst frame):')
        print()
        print('| map | same length | tick avg before | after | last minute before | after | worst frame before | after |')
        print('|---|---|---|---|---|---|---|---|')
        for m, rows in a.items():
            if m not in b:
                continue
            r2 = b[m]
            def avg(rr):
                w = sum(fl(r, 'tick_n') for r in rr)
                return sum(fl(r, 'tick_avg') * fl(r, 'tick_n') for r in rr) / max(w, 1.0)
            print('| %s | %s | %.2f | %.2f | %.2f | %.2f | %.0f | %.0f |' % (m, 'yes' if rows[-1]['min'] == r2[-1]['min'] and rows[-1]['n_units'] == r2[-1]['n_units'] else 'NO',
                avg(rows), avg(r2), fl(rows[-1], 'tick_avg'), fl(r2[-1], 'tick_avg'), max(fl(r, 'worst_ms') for r in rows), max(fl(r, 'worst_ms') for r in r2)))


main()
