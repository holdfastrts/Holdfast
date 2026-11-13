# Notes for Claude

- **Version:** every pushed change advances the game version. Run `tools/bump_version.sh`
  (patch number, e.g. 0.7.3 -> 0.7.4) before committing; bigger features may bump the minor
  number by hand. Also add an entry for the new version to `scripts/patch_notes.gd` (the PATCH NOTES page in Settings); the script updates the version in README.md itself. The version shows in the main menu and on the first line of every match log.
- **Art:** legs and tools drawn in code are tracked in `docs/art_style_inconsistency.md` (the owner wants them redrawn by ChatGPT later for one uniform style); add every new code-drawn edit there.
- **Web build:** `tools/web/build_web.sh` (CI uses it): a code pack, an art pack (`assets/`, cached by the browser across updates) and the music downloaded on demand; see `docs/web_load.md`. Keep runtime files out of `docs/` and `art/`.
- THE NAME (owner, 2026-11-13): **Triumviwar: Is All Lost?** (config/name "Triumviwar", GameName.SUBTITLE on the big headings). Match logs (playtest reports pasted by the user) start with `Triumviwar vX.Y.Z match log` (older ones: `Working Title for RTS v...`, `Holdfast v...`; GameName.is_log_header accepts all). Holdfast is taken by another game: never use it as the name. The shown name comes from project.godot `application/config/name` (scripts/game_name.gd); the user folder stays `Pocket RTS`.
- **Design:** read `docs/design_principles.md` (fairness, anti-snowball, meaningful base building)
  before balance, economy, AI or building changes; the owner wants these followed.

## Backlog (owner's list, easiest first; jobs marked "branch" were stopped half done: the work is kept on their branch (worktree-agent-*; uncommitted parts were saved as a "WIP snapshot" commit and the worktrees removed to free disk): recreate a worktree from the branch to resume, or merge it)

- Crown research: the owner is thinking about spreading the Armoury's 9 researches over other buildings (e.g. Cavalry Charge at the Horse Breeder, Prepared Charges at the Powder Mill); undecided, pros and cons discussed 2026-10-27.
- BROOD REDESIGN, DECIDED in principle (owner, 2026-10-28): the Brood has NO buildings, only units; some units ROOT (armour and defensive buffs while rooted; uprooted they move as units); the QUEEN roots too, hoards the resources, and is the losing condition (kill her and you win). Details: docs/idea_brood_mobile_buildings.md. NOW THE ONLY BROOD (0.18.0, branch brood-replace, docs/brood_replace.md): the old Brood (its buildings, swamp, Spore Mother, Bloater, old AI) is removed; faction "brood" is the Brood of creatures (BroodNew.on(g,t) = factions[t] == "brood"; Game.nb_teams is gone; the old slot id "brood_new" still loads as "brood"); saves and replays with the old Brood are refused with a note (Defs.old_brood, BROOD_FORMAT 2, replay FORMAT 2). First built as an experiment (branch brood-redesign, merged 0.15.9). scripts/brood_new.gd, scripts/ai_brood_new.gd, tools/import_brood_new.py, tools/test_brood_new.gd; docs/brood_new.md has the numbers, Claude's choices for the owner to confirm (supply, swamp, spoils (was essence), the old buildings' roles) and what is missing (online lobby, other fathers, research). FATHERS (owner, 2026-10-28): the tech is father creatures (a Tyrannosaur for ground warriors, a Pterodactyl for fliers, another for Spitters...), one of each, each must be near the Queen to fertilise her eggs. ART DIRECTION (owner, 2026-10-28): the Brood is REPTILIAN first; some insect is fine, too much makes it a Zerg knock-off.
- Queen animation (not started; the Queen is a still sprite at the Brood capital).
- Armoury art polish (patch wobble, yellow specks, dummy target colour in its experiment animations): the Crown animation audit (anim-audit-crown) looks at it; wall balance check; optional player build grid; loosen the 24-tile limit in tools/test_ai_placement.gd.
- AI wall timing and scouting: DONE for the Crown Musketeer opening (AI._wall_wanted/_wall_off/adopt_site, AIScout rush evidence by faction; tools/test_ai_wall_vs_rush.gd: wall at ~2:00 behind the Barracks and Mill, 3 Musketeers by ~2:30, vs the owner's extreme rush). Still open: the walled Brood AI scouting by a patrolling grub at the ramp foot, Clockwork's equivalent, and a Crown that holds 3 Musketeers by 2:00 (needs the early farm income, which pays in lumps).
- AI: Brood AI on Rush built no army by 4:30 after the capital/income nerf: wt-brood-ai (0.14.45) reworked the Brood computer; check it in the study-v2 results.
- Exhausting resources: DECIDED (owner): resources run out (the Crown's soil too); only the timing of when they run out may need fine tuning (once seen ~10 min for the Crown, with 1-2k unspent gold at the supply cap).
- MUSIC: all three factions have 20 pieces in the same shape (Music.ROLES: opening, skirmish, full battle, calm). Clockwork merged 0.14.58 (tools/music/clock_more.py, one motif, the owner's clock recordings as percussion via tools/music/clock_kit.py; docs/music_clockwork.md, tools/test_music_clock.gd); Brood merged 0.14.60 (tools/music/brood_more.py, the Hive Call motif; docs/music_brood.md, tools/test_music_roles.gd). Still to do: an "army" select sound (voice/<faction>_army) for mixed Brood and Clockwork selections.
- Art (make better): the Clockwork buildings' turning parts (Cog Press, Mainspring, Escapement and the other gear buildings): the owner wants them as perfect as possible. The Clockwork animation audit (anim-audit-clockwork) checks every Clockwork building's loops; details of the rough parts in docs/art_style_inconsistency.md.
- Done and crossed off (2026-10-29): the dismounted Cuirassier (dismounted_armoured) redrawn by ChatGPT in every strip (0.15.21 idle/walk/aim/fire, 0.15.22 sword attack and death, all at 33 px helmet to soles; docs/art_style_inconsistency.md).
- Done and crossed off (2026-10-27): the in-game music player (scripts/ui/menu_music.gd); the labourer leading a horse getting stuck and the limbered guns and vanishing horses (fix-guns-horses, 0.14.37; the horse and hauler tests pass on 0.14.53); the late-game lag pass (perf-lag, 0.14.43); the Crown losing all its workers to a Raptor counterattack (obsolete, owner); Brood ground (0.14.42).

## Current work

- CROWN: FOUNDRY BEFORE THE SECOND BARRACKS, ALWAYS (owner, DECIDED 2026-11-03 22:33), in every plan and matchup (the Horseman
  rush is done with 1 Barracks). The Horse Breeder comes either way (cannons need horses). Canister hits flyers, round shot
  has the longest range (430). Riders are an addition when the scout sees drops/leaps, enemy artillery, a greedy enemy or
  for map control. Apply it to crown-builds-a/b/c's plans at merge. POSSIBLE EXCEPTION, UNDECIDED (owner, 22:36): the
  Dragoon raids might go 2 Barracks before the Foundry, but only when scouted and for a reason, as an answer to something.
  CONFIRMED (owner, 2026-11-04 20:50, asked after his own game went 2 Barracks first): "it depends, but most of the time
  Foundry first is the best option": Foundry first stays the default; a second Barracks first only for a scouted reason.
- FULL QA STUDY (owner, 2026-11-07 23:20: "an overall study and complete systematic test of the game"): five cloud jobs,
  each on its own branch, merge on "DONE: <job>:": qa-tests (run all ~244 tools/test_*.gd, fix/refresh, list untested
  areas), qa-content (tools/test_content_all.gd: every unit/building/ability/research of every faction), qa-matches (Hard v
  Hard, all 9 matchups incl. mirrors, every map, 15:00), qa-ui (every screen, 3 languages, desktop + phone sizes, tutorial,
  campaign, editor, save/load, replays, online loopback, web), qa-perf (tick/draw/memory on every map, big battles).
  Reports docs/qa_2026_11_08_<area>.md. ALL MERGED 2026-11-08: qa-content 0.33.8, qa-perf 0.33.9, qa-ui 0.33.10,
  qa-tests 0.33.11, qa-matches and brood-nerf-study (data/tools). OWNER DECISIONS WAITING: the cannon/mortar double
  building bonus on a right-click (qa_content item 3); ATTACK on unarmed cards; the Clockwork's harass and Great Winder
  sweep under ONE ARMY; draws (dead sides should lose, winners hunt); the P1 start-spot edge (44-25).
  OWNER 2026-11-11 04:55 "ok do it" (Claude's picks, say so if wrong): the bonus applied ONCE but RAISED to keep today's
  siege punch; ATTACK hidden on unarmed cards; a side with no workers/army/means for 60 s is BEATEN and the winner hunts;
  ONE ARMY gets exceptions (harass groups, the Great Winder sweeps). MERGED 2026-11-11: rules-fixes 0.33.12, rebel-art
  0.33.13 (docs/rebel_art.md, redraw prompts inside), crown-ai-v2 0.33.14, clockwork-ai-v2 0.33.15, start-spots (study:
  docs/start_spots_study.md; its fixes WAIT for the owner: mirror the start units exactly, one base anchor (hall centre)
  for the computers, then study again). Then the KING'S STUDY hub 0.33.16 (docs/campaign_hub_art.md).
  OWNER 2026-11-11 22:28: YES to the start-spot fixes (job start-spots-fix: mirror the start units, hall-centre anchor,
  rerun the study) and a COACHED, FILMED Crown v Brood job (crown-v-brood-coach: "crown can beat brood, it's crown AI
  that is bad"; Crown AI play only, no Brood balance change). Merge each on "DONE: <job>:".
  OWNER 22:35: EVERY matchup coached and filmed with the same scrutiny: jobs crown-v-crown-coach, crown-v-clockwork-coach,
  clockwork-v-brood-coach, clockwork-v-clockwork-coach, brood-v-brood-coach (docs/<job>.md each). Six AI jobs at once:
  fixes kept small and gated by matchup; merge them one at a time and rerun the AI tests after each.
  MERGED 2026-11-12: crown-v-crown-coach 0.33.17 (all gated to the mirror, AICrownMirror; Claude's choice 1: open its
  fixes to the Crown's other matchups after a measured batch), crown-v-clockwork-coach 0.33.18 (the Clockwork now wins
  10 of 16; OWNER QUESTIONS in its doc: the Crown earns less per worker than the Clockwork, 34 v 57 a minute at 10:00;
  a Crown march with a formed line and guns is the next job; the Clockwork's fixes kept though they hurt the Crown).
  Then crown-v-brood-coach 0.33.19 (docs/crown_v_brood_coach.md; Crown W-D-L v Brood 0-14-26 -> 1-18-21; BALANCE PROPOSAL
  waiting: Cottage 10 supply or the hall training 2 labourers at once; the GREEDY read of every Brood), clockwork-v-brood-
  coach 0.33.20 (Clockwork won or led 6 -> 9 of 16), clockwork-v-clockwork-coach 0.33.21 (a side clearly ahead wins 11
  of 13, was 8 of 15), brood-v-brood-coach 0.33.22 (income at 8:00 5,546 -> 9,606; the Raptor no longer read as a rider
  in the mirror), start-spots-fix 0.33.23 (docs/start_spots_fix.md: no spot edge left except the Brood mirror 26-13-1, p
  0.05; proposals there). test_ai_brood's stage-3 timing is flaky; test_brood_new_defence's rooted-muskets case fails on
  main too. ALL SEVEN JOBS MERGED 2026-11-12.
  OWNER 2026-11-12 07:59: the Crown computer never uses the player's DRAG-A-LINE (no AI calls Game.line_move): a line of
  Musketeers with the cannons behind it. Job crown-line-fight (coached, filmed; docs/crown_line_fight.md): the line at
  every position and before contact, guns unlimbered behind it, the march as a formed body; merge on its DONE.
  OWNER 08:03: PAIR IT WITH HORSEMEN SCOUTING IN FRONT: queued as job crown-rider-screen, to start once crown-line-fight
  merges (riders ahead and on the flanks of the marching line, find the enemy before the line walks in, pull back behind
  the line at contact, catch fleeing/harassing units; a forward picket at defended positions).
  MERGED crown-line-fight 0.33.24 (2026-11-12; scripts/ai_crown_line.gd, docs/crown_line_fight.md, switch line:off):
  waves form the player's drag-a-line before a known enemy, a gate or a halt, guns 2.6 tiles behind; v Clockwork fights
  1.67 killed per 1 lost (was 1.36); results by 12:00 unchanged; most fights still start unformed (the enemy first seen at
  contact) -> crown-rider-screen started. 9 Claude's choices for the owner in its doc. test_crown_hold's [below] labourer
  check is flaky too.
  MERGED crown-rider-screen 0.33.25 (2026-11-12; scripts/ai_crown_screen.gd, docs/crown_rider_screen.md, switch
  screen:off): 2-4 Horsemen ahead/flanks of a marching wave, the line forms on their sightings (from 8% of the wave),
  flank work at contact, a picket forward at home; 9 of 291 riders lost; fights begun formed: mirror 42% (was 22%), v
  Clockwork 36% (was 28%); trades and results unchanged within noise. Still wrong: v the Clockwork most fights are at its
  bases where units come out at a few seconds' notice; after a won fight the line marches on as a crowd. 8 choices in its
  doc.
  OWNER 2026-11-12 20:47: WIN RATES IN ALL MATCHUPS, coached: study jobs winrate-a (Crown v Brood, Crown v Clockwork),
  winrate-b (Clockwork v Brood, Crown mirror), winrate-c (Clockwork and Brood mirrors): the 0.33.7 qa-matches design (19
  maps x 2 seeds, 15:00), 2 filmed games per pairing with coach's notes and proposals (no code changes); combine into
  docs/winrate_2026_11_12.md. MERGED 2026-11-13 (docs/winrate_2026_11_12.md has the table and the proposals, none
  applied): the Crown computer 0 wins in 76 (v Brood 0-11-27, v Clockwork 0-30-8; its blind Horseman rush v every Brood
  read as GREEDY fails 33 of 38); Clockwork v Brood now even (11-15-12); Clockwork mirror ends (20 decided, was 0); Crown
  mirror 35 of 38 draws; Brood mirror leans to spot A on the named maps, Clockwork v Brood to spot A on the classic maps.
  OWNER 2026-11-12 21:04: ALL ECONOMIES ABOUT EQUAL PER MINUTE, by NERFING the Clockwork and Brood (not buffing the
  Crown), a slower game; asked which RTS the pace resembles. Job economy-parity (branch, docs/economy_parity.md): a
  scripted bench, proposed nerfs applied ON THE BRANCH ONLY, games, the pace compared; DO NOT MERGE until the owner OKs.
  RESULT (docs/economy_parity.md, bench on main, its balance numbers still only on the branch): by DESIGN the economies
  are close (Clockwork 1.02-1.06 of the Crown, Brood 0.75-1.00); the COMPUTERS reach Crown ~55%, Brood ~60%, Clockwork
  72-91% of their bench. OWNER 2026-11-13 01:18: COACH THE COMPUTERS TO ~100% OF THEIR ECONOMY BEFORE ANY BALANCE
  CHANGE ("so we have a complete picture and then make decisions"): jobs econ-coach-crown, econ-coach-clockwork,
  econ-coach-brood (AI only, no numbers; docs/econ-coach-<faction>.md); merge one at a time on DONE. Pace now: Warcraft III
  with a StarCraft II opening. Also running: online-ranked (OWNER 01:04: SERVER-AUTHORITATIVE ranked matches, Steam-only
  ladder, bans by SteamID64 + optional Steam game ban; prototype + docs/online_ranked.md). Main menu painting: hallucination
  fixes by crop repaints (art/menu_fix/, tools/menu_fix_composite.py): gunner and horseman done 0.33.31, the Clockwork
  front and the Brood Mother DONE 0.33.32 (one repaint of the right side, art/menu_fix/f34_right_fixed.png, a stray sword inpainted).
  GROUND SYSTEM (owner, DECIDED 2026-11-13 01:34-01:40; docs/ground_system.md): every economy building drinks from a
  CIRCLE of ground like the Rootmaw; spent ground shown RED while placing; overlap with spent ground gives a proportional
  yield; ground exists only in a DISTRICT PER HALL (fixed amount each); the layer shows FAINTLY while placing ANY building
  (owner 01:37: placement strategy), the economy building being placed its own circle stronger. Build it AFTER the three econ-coach jobs merge, as a
  Settings experiment, benched and with the computers coached on it. (Why: today's Farm limit counts spent Farms empire-wide,
  so a fresh hall can stand farmless; the owner: tearing a Farm down never renews the soil.)
  ART 2026-11-12/13: the Clockwork and Brood campaign hubs (hubs-cw-brood 0.33.26: Hollweg's workshop, Lindqvist's
  station), the Clock Soldier's 8-way walk and the Raptor's S/N run (walks-raptor-clock 0.33.27), the rebels' back
  views, Varenne's calm idles, the pikeman's S/SE pike (rebel-art-2 0.33.28), the Raptor's SE (Claude's composite of two
  sheets) and NE run (0.33.29): no code legs left in the Raptor's run.
- CROWN HOLDS ITS WALLED NATURAL (owner's playtest 2026-11-06, Dune Sea; job crown-hold, 0.33.1, docs/crown_hold.md): the
  natural's GATE on the palisade stretch nearest the main's ramp foot (AIExpandWall._gate_by_ramp); once that wall is 70%
  closed with its gate up the army's HOME post is DOWN at the gate (AICrownHold section 7, the gate post; ramp post = main
  alone, cliff edge = no walled natural); SITES KEEP CLEAR for everyone (Game.site_keepout, step_aside keeps HOLD, the
  computer avoids a blocked spot 90 s); 3 Field Cannons before any Mortar in every Crown plan (AI.CANNONS_FIRST).
- AI FOLLOW-UPS (owner's Crown OPTIMAL v Clockwork game 2026-11-06; job ai-followups, 0.33.3, docs/ai_followups.md): the
  Crown puts its ARMY FIRST when far behind the enemy's (AICrown.army_lags: 60% of foe_reckon, 90% after a GREEDY read;
  labourers and tech wait, the natural's wall keeps a few coins); no cliff edge above a walled natural (the gate post at
  half the wall); the Clockwork's push does not chase fast riders (riders_only, march leash, chase cap) and only a real
  attack or a hall/Mainspring about to fall calls it home; a defence gives up a chase 520 px out. Open: the Crown's
  economy (55-75% of the Clockwork's by 8:00; crown-optimal-opening's Barracks-first opening), the late natural wall.
- CROWN AMMUNITION, NO POWDER LOCK (owner, DECIDED 2026-11-05 07:48-07:54; job crown-ammo): Barracks units have NO
  building requirement any more (the Musketeer no longer needs the Powder Mill; the Officer no longer needs the Horse
  Breeder; an Officer without a horse walks). Every unit with a firearm costs POWDER for its ammunition, the Officer too
  (pistol): trained with powder in the bank it comes out armed; trained with gold only it comes out with ZERO shots and
  fights with its melee weapon (bayonet, sabre) until it refills at a reloading point (Mill, Barracks, Town Hall, Powder
  Wagon), the refill taking that powder from the bank. A Barracks toggle ARM WITH POWDER (default ON). PARTIAL ammo when
  the bank holds less than a full load. The gold-only rush is allowed (it is the Horseman rush: the Horse Breeder costs only
  gold). MOUNTED and LIMBERED units keep the Horse Breeder requirement; a Horseman with no horse is an Officer.
- AI PLANS: ADAPTIVE + OPTIMAL (owner, DECIDED 2026-11-05 09:54; job ai-optimal): a scout report is information even
  when it sees nothing (GREEDY / NORMAL / AGGRESSIVE / DEFENSIVE / UNKNOWN). EVERY plan adapts to some point (survival:
  a seen rush is defended; obvious answers) but keeps its identity so the owner can train against / watch each strategy
  (Economy still races v a greedy enemy). NEW plan OPTIMAL per faction: a common opening, an early scout, then it picks
  from ALL the faction's builds by the read, matchup and map (v greedy punish or out-expand; v aggressive defend then
  counter; v defensive out-expand, tech, siege); switches at most once a stage. Horseman rush: good v the Brood, somewhat
  v the Clockwork, NOT v the Crown. Also an audit of every AI STORY line (and the logic behind wrong ones).
- CROWN OPTIMAL OPENING (owner, DECIDED 2026-11-06 09:17; job crown-optimal-opening): the ramp Cottage, the Gate, the
  BARRACKS (rush unknown), then the second FARM; NO Powder Mill before the scout's read. After the read: POWDER MILL
  (Musketeer play) or HORSE BREEDER (riders); v a GREEDY Brood the Horse Breeder to punish (not the Siege push). Also running:
  job crown-hold (2026-11-06 07:55): the natural's gate toward the ramp, the army posted at the natural's palisade, units
  clear building footprints, 3-4 Field Cannons before the first Mortar.
- EXPANSION SPOTS PER FACTION (owner, DECIDED 2026-11-03 22:25): each faction has its own optimal expansion spot (the Brood
  already does: Mound Turtle spots). CROWN: 2nd and 3rd bases at the MINIMUM hall distance (Defs.HALL_SPACING 18) and close
  together, covered by the main's high ground (Musketeer range from its edge) and easy to wall (walls join up); 4th base on:
  the same, as close as possible to its other halls, without the main's high ground. Being built by the local job
  crown-cliff-edge (with: Musketeers at the cliff edge above a threatened building, repairers that juke, Foundry/cannon
  before the Horse Breeder once the Brood is scouted). REDONE (owner, 2026-11-04 07:05; job crown-spots-v2, 0.29.5): the
  2nd base where the old natural was but pulled in to 18 tiles, as near the ramp's foot and the map's border as may be;
  the 3rd its MIRROR on the other side of the main's ramp, same aims ("I don't know why you left the second expansion so
  far out"); the cliff cover is only a tie-breaker now (docs/expansion_spots.md "The Crown's rule").
- STATIC DEFENCE IS NOT A BUILD (owner, 2026-11-03 21:45): "Good base design should be for all builds. Static defense
  isn't a good strategy on its own: it is either a desperate attempt to hold a rush or a later security against harass so
  you can concentrate your army." So cw-builds-a's TURRET TURTLE plan is NOT to be merged as a strategy: at merge, take its
  good base layout (production behind the hall, Regulators/buildings toward the ramp) as a SHARED rule for every Clockwork
  plan, and turrets only REACTIVE: an emergency vs a scouted/arriving rush, and later at expansions/worker lines against
  harass so the army can leave home. The fast second Clocktower part may become the Clockwork's Economy plan.
- COACHED BUILDS, "do it all" (owner, 2026-11-03 20:32): ALL MERGED: brood-ai-tune 0.29.5, cw-builds-a 0.29.6 (Clock
  Soldier rush; Turret turtle kept but hidden), cw-builds-b 0.29.7 (Pendulums, Heavy Works push), cw-builds-c 0.29.8 (Owl
  raids), crown-builds-a 0.29.9 (Dragoon raids), crown-builds-b 0.29.11 (Siege push), crown-builds-c 0.29.14 (Balloon
  harass); the Crown plans keep the Foundry before the second Barracks. RUNNING: cloud job brood-builds (Spitter timing,
  Brute siege; merge on "DONE: brood-builds:"). Later: the computer picks its build by matchup and switches on what its
  scout sees. Brood FOOD_BONUS: SLIGHT NERF 1.5 -> 1.2 in 0.33.6 (owner 2026-11-07 00:43: "nerf the Brood's economy, but just slightly, not a harsh nerf"; far Rootmaws pay x2.2, was x2.5). Earlier: 1.5 -> 0.8 proposed (it out-earns both Hard computers 1.4-2x): NOT YET (owner, 2026-11-04 15:05: "the
  Crown AI is still too stupid to make that judgement"; maybe the Balloon harass is just bad v the Brood; the Horseman rush
  is extremely effective v the Brood Economy). Proposals waiting on the owner:
  Springer: jump recharge 10 -> 6-7 s, range 5 -> 6-7 tiles, Springer range 170 -> 190, High Leap 100 -> 50 Tension; the
  build reports' own proposals (docs/clockwork_builds_*.md, docs/crown_builds_*.md).

- MIXED REPLAYS built by the cloud job replay-mixed (0.29.5, docs/replay_mixed.md): Settings REPLAY RECORDING MIXED
  (default on phones; FULL stays the computers' default): commands (Game.net_forward/net_set -> ReplayRecorder.note_cmd),
  the computers' decisions as order/queue diffs twice a second (no AI runs in playback), a SaveGame keyframe every
  10 s; ReplayMix plays the real game from the keyframes and corrects in place; format 3 (T_KEY, T_CMDS).
- REPLAYS, NEXT (owner said yes, 2026-11-03): after the perf-stutter job reports, a job for MIXED replays: record the
  players' commands (StarCraft-style) plus one full keyframe every ~10 s instead of 5 pictures a second; playback re-runs
  the commands between keyframes and each keyframe corrects drift (determinism a bonus, not a must). The quick Settings
  option REPLAY RECORDING (FULL / LIGHT / OFF, LIGHT default on phones) is the job replay-rate. Also pending after
  perf-stutter: an Android follow-up if it only measured the computer (the owner's slowdowns were on the APK, growing
  late in the game, not at the start).

- TUTORIAL (owner, 2026-11-04: "a TUTORIAL button and a CAMPAIGN button"), 0.30.0 (branch tutorial, docs/tutorial.md):
  TUTORIAL beside CAMPAIGN (menu grid 4 x 3); lessons on the mission engine (campaign/tutorial.json, campaign/missions/
  t*.json with "steps"; Tutorial, TutorialMenu; tutorial conditions and the `point` action in MissionRun; the pointer in
  MissionUi): Basics, the Crown, the Clockwork, the Brood, and an Easy practice game per faction. tools/test_tutorial.gd
  plays every lesson; texts in tools/i18n/campaign/tutorial.txt.

- CAMPAIGN ENGINE (owner, 2026-11-03), 0.30.0 (branch campaign-engine, docs/campaign_engine.md): data in campaign/
  (campaign.json: storylines with hubs, hotspots, talks; missions/<id>.json; maps/ = map editor maps, id "campaign:<name>"),
  scripts/campaign/ (Campaign, MissionRun = game.mission, MissionUi, CampaignMenu, StillView), texts in
  tools/i18n/campaign/, tools/test_campaign.gd. One placeholder mission (p01_revolt: the Crown puts down a revolt; the
  story is being written with the owner). Open: a real two-device online run of CO-OP / VERSUS, saving a mission, art.
- CAMPAIGN STORY (owner, 2026-11-04; the lines below are his decisions and ideas, in order):
  - CAMPAIGN STRUCTURE (owner, DECIDED 2026-11-04 09:41): ONE story spine merging all options: every battle playable from
  both sides (solo pick a side, co-op same side, versus = the other side of the same mission), choices carry forward as
  consequences (start forces, allies, units, heroes alive/dead; a lost battle returns as a reclaim mission), hub remembers,
  branches split and rejoin (diamond), real splits only at the endings; a canon timeline kept for the writers. The two
  storylines (Brood: explorer v scientists; Clockwork: clockmaker v priest) CROSS 3 TIMES: beginning, middle, end.
  - CAMPAIGN STRUCTURE PLAN (owner, DECIDED 2026-11-11 05:49; docs/campaign_structure.md): acts in time order AND
  braided storylines AND a global war map (three-way in Act 3); listeners come and go; the finale is in the present and
  the heir puts the King's lessons into practice; crossings = Church council in Rome, Brazil between Brood and Clockwork,
  the global war (Clockwork and Brood also fight each other); solo/co-op/co-op versus all supported; 2 endings + minor
  variations; 3 hubs (one per faction); no naval in the engine; medium to large; Act 1's choice = spare or execute
  Varenne. HUBS (06:03): layered painting rooms (motion in code) + the war map as each hub's table, different per
  faction. VOICES: ElevenLabs is out; free options offered, undecided.
  - CAMPAIGN FRAME (owner, idea 2026-11-04 09:50): the story is FLASHBACKS. Present: total global war; the Crown (a
  world empire, capital ROME, colonies round the globe, once unchecked) barely holds its key colonies and capitals. The
  campaign follows the fall from hegemony: heretical, rebellious uprisings (themed on the French Revolution) crushed by
  the Church Inquisition and the Crown Armed Forces, then the Clockwork and Brood problems pile up and the Crown loses
  ground, up to the present war.
  - CAMPAIGN NARRATOR (owner, DECIDED 2026-11-04 09:55): the KING is the main narrator (the frame, in the present); each
  part/mission has its own narrator from that side's perspective (the explorer, the scientist, the clockmaker, the priest...).
  - CAMPAIGN TONE (owner, DECIDED 2026-11-04 09:59): the game is Catholic and monarchist; the Crown and the Church are
  objectively the good guys, no subverting expectations. The King narrates truthfully (no unreliable-King twist); the
  other sides' narrators may be mistaken or deceived, the Crown's are not.
  - CAMPAIGN YEAR is about 2767 (owner 2026-11-04, not 2500). A global story.
  - MISSION 1 (owner, 2026-11-04 10:26): a TOBACCO PLANTATION in the American colony attacked by heretical rebels (against
  Church and Crown; they want freedom and secularism). Witness: the missionary PRIEST, then a young seminarian, watches the
  colony's lord put the unrest down with swift, extreme violence (canister into the mob). Play: train and defend the
  plantation with Musketeer lines and cannon, push the rebels back to the province stronghold they took, blast them with
  canister. The King smokes a pipe; other characters smoke cigars and pipes and shudder at rebels destroying the precious leaf.
  - MISSION 1 settled (owner 10:53): VIRGINIA (Brazil saved for another mission); names Claude's choice, European from all
  over (proposed: King Constantine IV in Rome; Lord Edmund Fairleigh, Governor of Virginia; seminarian Tomasz Wierzbicki,
  later the missionary priest; Captain Matteo Ruggieri of the guns; rebel leader Etienne Varenne of the Free Assembly,
  green and black). The REBELS are a minor non-playable faction with their own units and art. OPENING = oil-painting
  STILLS (5+), the first being the King lighting his pipe, which is also the main menu picture.
  - MISSION 1 SCRIPT APPROVED (owner, 2026-11-04 20:50): docs/campaign_mission1.md (the King's lines, three parts, the
  families choice, the canister ending). Being built by the cloud job campaign-m1 with stand-in rebels until the owner's
  ChatGPT rebel art arrives; the King's voice to be recorded by the owner in ElevenLabs.
  OWNER 2026-11-04 21:45: the skeleton is fine but the DIALOGUE has many AI tells: he will rewrite it himself in detail
  later (treat all mission texts as placeholders; hold the other characters' recordings). OPEN: who the King is talking
  to (who the player is: a new general? the King's son?), and the handover to Tomasz needs its own still (Tomasz with the
  King, not the King alone).
  - MISSION 1 BUILT (cloud job campaign-m1, 0.31.0; docs/campaign_m1_build.md): p01_leaf is the Prologue (p01_revolt
  kept only as the engine's test bed); map campaign:virginia_leaf; stills in campaign/stills/; the Free Assembly's roles
  in scripts/campaign/rebels.gd (art drops in via RebelArt.ART); the Pikeman back as a campaign-only unit; the engine
  gained opening/ending shows, choices and flags (Campaign.flag), light (night/dawn), voice files
  (campaign/voice/p01/<line>.ogg, list in docs/campaign_mission1_voice.md); tools/test_campaign_m1.gd.
  - FACTION COLOURS (owner, DECIDED 2026-11-04 12:06): CROWN PURPLE, CLOCKWORK RED (and brass), BROOD GREEN (venom green);
  UiStyle.ACCENT follows (0.29.12); the menu painting's Brood (red spines) to be made green by ChatGPT.
  - CROWN COLOUR IS PURPLE (owner, 2026-11-04 11:35): the Crown's standard colour changes to purple (stills done in purple;
  main menu painting assets/menu/battle.jpg to be redone by ChatGPT, the Crown was blue there). The mission 1 stills are in
  art/campaign/stills/p01_01..06 (move into campaign/ when wired in) (king pipe = also a main menu candidate).
- MARCHING BAND AS A REAL UNIT (owner, 2026-11-05 12:18; experiment since 0.23.0, docs/marching_band.md): BAGPIPES melee,
  DRUMS movement speed, FIFE ranged (Claude: as reload speed); always +5%, a SOLO +30%, each solo its own cooldown (no
  energy); both band and Armoury may buff (tune later). Trained at the ARMOURY, which also researches the musicians: the band
  starts with the Drummer, then Fifer and Piper in any order. Art: a group that grows (drawn as three musicians placed
  together in code); ChatGPT prompts for the SE marching cycles given, refs in docs/redraw_refs/band/. Also: the Mist Toad's
  FOG and MIASMA to be locked behind research (at the Dilophosaurus; TONGUE free). DECIDED (owner 13:35): ONE SOLO AT A TIME
  per band; SEVERAL BANDS allowed (like cannons; rings don't stack: each stat takes the strongest); each band costs MORE per
  researched musician. The owner's SE art is in art/redraws/band_{drummer,fifer,fifer_b,piper}_walk_se_chatgpt.png (two
  fifer options). BUILT by the cloud job marching-band (0.33.0, branch marching-band, docs/marching_band.md: Armoury, research
  musicians, several bands, fifer art option B, Toad FOG/MIASMA research); MERGE IT WITH A SQUASH (the branch carries an
  old rewritten history by an "ours" merge); open questions in its doc.
- MAP VARIETY (owner, DECIDED 2026-11-04 15:50): no single map rule; a pool with variety (some POCKET naturals sharing
  the main's choke, some open naturals, some between; mains hugging the corner is the milder option). He weighed turning
  every ramp toward a corner pocket and rejected it as a global rule (one point of defence = Crown turtling too strong).
  QUEUED after crown-v-brood merges: make a pocket variant of a classic map (e.g. Greenhold, ramp toward the corner) in
  the map editor and run the computer study on it v the normal map: ALL matchups incl. the MIRRORS (Crown v Crown,
  Brood v Brood, Clockwork v Clockwork) and the Clockwork's (owner: "testing is overall a good practice"): win rates,
  game length, halls lost. The corner-pocket natural A/B test is part of crown-v-brood (item 6).
- IDEA BUCKET: the Clockwork tempo/beat (commands in a beat window, sync bonuses), owner 2026-11-04: "leave it in the idea
  bucket". TO DO LATER: translate every announcer line (Crown herald, Brood scientist) into pt/es voices.

- EXHAUSTED MEANS EXHAUSTED (owner, 2026-10-30), 0.24.0 (branch exhaust-economy, docs/exhaust_economy.md): no trickle for
  anyone; spent soil/brass/ground pay 0; powder and Tension fall with their reserve to a FLOOR (Defs.POWDER_FLOOR 15%,
  TENSION_FLOOR 5%, only while worked); each Clocktower's SPRING LIFE (1,320, in its `soil`) feeds its Mainspring, spent =
  FATIGUED; 2 presses + 1 Mainspring per Clocktower; press 7.2/5 and 10/8, Winder 60, brass 9,000. Open: the Crown's
  anti-rush timing slipped to 2:49 (test_ai_wall_vs_rush), the floors unmeasured in fights; tools/test_exhaust.gd.

- Stun mark (owner, 2026-10-29), DONE in 0.15.24 (branch stun-mark): stars over a REALLY stunned unit (scripts/stun_mark.gd; Unit.stun(t, show, until) is the only way to stun; under 0.3 s, internal holds and nets show none); TONGUE pulls flyers through the air and never pulls the Brood Mother or a father (Defs.TONGUE "no_pull" + "father"); the Field Cannon question is still open. docs/stun_mark.md (durations table), tools/test_stun_mark.gd, pictures docs/shots/stun_mark/.
- Swarm performance (owner, 2026-10-28: "200 Raptors a side... not a lag fest"): cloud job branch `swarm-perf` (0.15.6), DONE: docs/swarm_perf.md (numbers before/after, what is left). tools/stress_swarm.gd (+ .sh): idle, walk, melee, offmelee, grubs, muskets scenarios, trace:FILE must match between versions. The unit grid is packed (Game._gpos/_gteam/_grad, GRID_SLACK and grid_slack: a unit moved farther than the slack must call game.note_move or move in its own tick), find_target looks only at enemies (_near_foe), animation steps 10 Hz in a big battle on screen (anim_crowd), replay pictures and the autosave (SaveGame.begin/SaveJob) avoid a tick's frame. Left: the clash's peak ticks, walking crowds, draw calls on phones.

- Turning gear rings experiment (owner, 2026-10-28; cloud job branch `gear-turn`, 0.14.104, DONE; docs/gear_turn.md has the speeds and open questions): only the outer toothed band turns (gear's own speed, meshed gears opposite ways; GearNet.bands / carry_at, scripts/gear_turn.gd); any unit on a band is carried round, walkers drift the full correct amount (no damping); idle units stay where they are and keep being carried (no automatic step-off: the player moves them off; only the computer walks its own idle/HOLD units off); workers at work walk straight in to the building; hold units are carried; big machines (radius >= 22), flyers and limbered guns are not; a walker pinned in a corner by the ride grips the floor 1.5 s and repaths. Setting TURNING GEARS (experiment), on by default, kept in the match cfg ("gear_turn"). Tests tools/test_gear_turn.gd, test_gear_turn_match.gd; film docs/shots/gear_turn/.

- Bodies (owner's rule, 2026-10-28): each faction gets something different from bodies: the Brood spoils (any body; the resource was called essence before 2026-10-29), the Crown resurrects its own, the Clockwork regains cogs (the Great Winder sweeps Clockwork wrecks of both sides). DONE in 0.14.103: the Great Winder's SWEEP pays 30% of the unit's cog price at once (Defs.GREAT_WINDER "share"), as an idle job: it rolls to a wreck near it, skips wrecks with enemies near, rolls back; no parts, no reassembly; MEND stays as it is. docs/great_winder.md, pictures in docs/shots/great_winder_sweep/.
- Expansion spots (owner, 2026-10-27): DONE in 0.14.95 (branch expansion-spots): the two best free hall spots of each side tinted gold on the ground (best brighter), for Crown and Clockwork players and spectators, not the Brood; minimap squares, brighter while placing a hall; Settings SHOW EXPANSION SPOTS. scripts/expansion_spots.gd (rating: room on the hall's level, ways in, walk, safety), docs/expansion_spots.md (each map's spots, weak sites: Thornwood Maze, Redrock third, 4-player classic naturals), tools/test_expansion_spots.gd, pictures in docs/shots/expansion_spots/. Also fixed the classic river maps' fords (not the same on both sides).

- Animation packs are done (Barracks drills, Breeder coats, Armoury experiments in game); the Queen is a still sprite at the Brood capital. Status table: `docs/animation_packs.md`.
- Animation audits (cloud jobs, 2026-10-27): every animation of each faction measured and looked at, safe fixes made, ChatGPT redraw prompts written: branches anim-audit-crown, anim-audit-brood, anim-audit-clockwork (docs/animation_audit_<faction>.md).
- Jobs running in separate cloud sessions (one-shot scheduled tasks), each pushing to its own branch, never to main; merge a branch when its summary doc is written or its last commit starts with "DONE:" / "TOOLS READY:". Merged on 2026-10-27: brood-pit-ground (0.14.42), perf-lag (0.14.43), wt-online (0.14.44), wt-brood-ai (0.14.45), ground-attack (0.14.46), clock-soldier-west (0.14.47), pendulum-sweep (0.14.48), icons round 13 (0.14.49/50), replays (0.14.51; EDITOR kept on the main menu, buttons in two rows), aoe-show (0.14.52), clock-soldier-shield (0.14.53), clockwork-sounds (0.14.54), the local QA pass (0.14.55, docs/qa_2026_10_27.md), anim-audit-crown (0.14.56), anim-audit-clockwork (0.14.57), music-clockwork (0.14.58), the Jack's two-launcher hop and jump (0.14.59, tools/jack_guide/hop_twin.py), music-brood (0.14.60), anim-audit-brood (0.14.61), net-instant (0.14.62), the Musketeer's south-east and north-east aims (0.14.63), fair starts on Jade Wilds (0.14.64), the Musketeer's south aim (0.14.65), qa-web (0.14.66: no crash page after a normal web visit, map editor buttons, phone layouts; docs/qa_web.md), catapult-facing-3 (art). study-v2 (docs/study_v2.md): four cloud machines (study-v2-m1..m4, pinned to 0.14.49) were CUT AT 11:00 on the owner's word ("we can extrapolate from that"); their data is in docs/study_v2/data/ and the report in docs/ai_balance_study_v2.md (tools/study/report_v2.py combine; it marks scripts that stalled). qa-soak merged (0.14.70; docs/qa_soak.md has 5 design questions for the owner, e.g. run-down Clock Soldiers stranded for good). Crown v Clockwork scrutiny (owner, 2026-10-27: a few games looked at closely, with screenshots: tools/shot_ai_match.gd films a match: fights, bases, a wind count of the Clockwork army).
- Pathfinding job (owner, 2026-10-27: "units should not bunch up at a cliff... small corners and other problems"): branch `pathfinding` (0.14.73) is DONE: rim clicks and lines stay on the high ground, group spots spread on the clicked side (Game.group_points/_walk_fill), unreachable goals end at the nearest reachable spot (find_path), melee leaves men it can't reach (Unit._siege_reaches), corner slip in resolve_terrain; test bed tools/test_pathing.gd (+ shot_pathing.gd, test_pathing_match.gd for stuck time in AI games); docs/pathfinding_audit.md has the numbers and what is left (match determinism). 0.14.71 already fixed the computer's siege gathering under the cliff (AI._siege_out) and added the Clockwork Winder escort.
- Clockwork computer job (owner, 2026-10-27: "we need the AI to play better"; DECIDED: repair is NOT to be nerfed, "it is the only thing keeping the Crown from losing, it can be dealt with": Jacks should focus the repairing workers; he thinks 4 Clock Soldiers fit at a gate face): a cloud session (scheduled 13:31) on branch `clockwork-ai` (tech on time, sieges with Jacks on the repairers, better targets, kit micro; docs/clockwork_ai.md); merge when its last commit starts with "DONE: clockwork-ai:". Siege experiment on 0.14.72 (Greenhold, 27-28 Clock Soldiers v 13 Musketeers at the ramp gate): with repair the gate held and the wave lost 25 for 1; without repair the gate fell in 38 s and the wave killed 13 of 15.
- Online (owner, 2026-10-27): asked about a dedicated server (free: Oracle Always Free ARM, 2 cores/12 GB since mid-2026) and lockstep; Claude suggested testing 0.14.44's lag fixes on his two devices first (ping counter, minute lines in the match log), then a server mode; lockstep only if needed (cross-device determinism between web and Android is the risk). Awaiting his choice.
- Musketeer and Guardsman aiming in every direction (Crown animation audit, finding 1): ChatGPT fails all five views in one sheet; one direction per request over a pose guide works (tools/musket_guide/aim_dirs.py writes art/redraws/guides/<unit>_aim_<dir>_guide.png; the owner's answers go to art/redraws/<unit>_aim_<dir>_chatgpt.png and tools/import_musket_aim_dirs.py imports them, then tools/import_vet_trim.py --only <unit>). Done: Musketeer se, ne (0.14.63), s (0.14.65; of the owner's two ChatGPT answers the first was used: the second was blockier with a huge hat and its flash streaked sideways). Guardsman (musketeer_armoured) se, ne, s done (s 0.14.69, ne 0.14.68) (0.14.67); all directions done.
- Gear rules job (owner, 2026-10-27; study docs/clockwork_gear_study.md): branch `gear-rules` (0.14.94; docs/gear_rules.md): the Ratchet Turret's 4-tile circle (no two overlap), the HEAVY WORKS (Pendulum, Spring Ballista, Great Winder; big gear only, by a Mainspring; the machine in training drawn rising in its bay, scripts/heavy_works.gd), the Movement Works shown as the LIGHT WORKS (internal id unchanged), size sets the tempo (Defs.GEAR "tempo", the turret's two screws in Defs.TURRET), brass floor plates for the Tension users, the GEAR VIEW (` key), the computer's kept spots (Game.ai_keep); merge when its last commit starts with "DONE: gear-rules:".
- Jade Wilds 4-player Clockwork start fairness: FIXED in 0.14.64 (Game._find_start_spot scores maxi(0, gap - 1): one lane from the edge still hugs it); tools/test_start_layout.gd passes on every map.
- Clock Soldier: west views in (0.14.47; docs/clock_soldier_west.md has ChatGPT clean-up prompts for the west attack and death and an E repaint so the shield isn't "on its back").
- Great Winder legs: pass 2 merged (shorter crouched legs, brush housing on the ground; 4 legs default). Spring Catapult: facing pass 3 merged (NE cup turned diagonally).
- Icons round 13 (0.14.49): the owner's 7 ChatGPT sheets are in (tools/import_round13.py, art/ui/icons3/; status in docs/command_icons_audit.md "TO DRAW"). The new HOLD icons are in (0.14.50: Clockwork blue arrow, Brood yellow arrow, his picks). Waiting on him: maybe a Brood DEMOLISH redo (it looks like the Brood BUILD), and SPIT with the Bloater (the sheet drew the Mist Toad; brood/ab_spit.png is cut but not wired).
- Clockwork sounds: the owner sent 8 recordings on 2026-10-27 (art/audio_src/clockwork/, SOURCES.txt: bell, alarm clock, crank loop, spring scrape, clangs, typewriter, wobble, metal noise) to cut into the Clockwork's sounds (he had asked to be reminded to find coil, spring and machine sounds). Merged in 0.14.54 (branch clockwork-sounds): voices, combat, deaths, building picks, alarm, research, crank for every gear-mode Clockwork unit and building, all from tools/audio/make_clockwork_sounds.py (one line per sound); docs/clockwork_sounds.md, tools/test_clockwork_sounds.gd.
