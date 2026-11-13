# The ranked ladder service

Sign-in (Steam / a test server's DEV sign-in), the 1v1 queue, Glicko-2 ratings, seasons, match records, bans and the
match hosts' reports, in one Node program with one SQLite file. Everything about ranked play, why it is built this way
and the owner's steps to go live: `docs/online_ranked.md`.

    LADDER_SECRET=<long random> node tools/ladder/ladder.mjs [--dev] --relay ws://127.0.0.1:8799 --godot godot
    node tools/ladder/admin.mjs ban|unban|bans|reports|seen|player|appeals|season new ...
    node tools/ladder/test_ladder.mjs          # its own tests (no network)
    tools/test_ranked.sh                       # the whole thing end to end on one computer

Files: `ladder.mjs` (HTTP + queue + starting match hosts), `store.mjs` (SQLite), `glicko2.mjs`, `steam.mjs` (Steam Web
API, server side only), `tickets.mjs` (the signed seats, same format as `scripts/net/ladder_ticket.gd`), `admin.mjs`,
`fixtures/` (Steam answers for the tests). The data (database, results, replays) goes to `tools/ladder/data/` unless
`--out` says otherwise; keep it out of git.
