# Notes for Claude

- **Version:** every pushed change advances the game version. Run `tools/bump_version.sh`
  (patch number, e.g. 0.7.3 -> 0.7.4) before committing; bigger features may bump the minor
  number by hand. Also add an entry for the new version to `scripts/patch_notes.gd` (the PATCH NOTES page in Settings); the script updates the version in README.md itself. The version shows in the main menu and on the first line of every match log.
- **Art:** legs and tools drawn in code are tracked in `docs/art_style_inconsistency.md` (the owner wants them redrawn by ChatGPT later for one uniform style); add every new code-drawn edit there.
- **Web build:** `tools/web/build_web.sh` (CI uses it): a code pack, an art pack (`assets/`, cached by the browser across updates) and the music downloaded on demand; see `docs/web_load.md`. Keep runtime files out of `docs/` and `art/`.
- Match logs (playtest reports pasted by the user) start with `Working Title for RTS vX.Y.Z match log` (older ones: `Holdfast vX.Y.Z match log`; GameName.is_log_header accepts both). The shown name comes from project.godot `application/config/name` (scripts/game_name.gd); the user folder stays `Pocket RTS`.
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
- CROWN AMMUNITION, NO POWDER LOCK (owner, DECIDED 2026-11-05 07:48-07:54; job crown-ammo): Barracks units have NO
  building requirement any more (the Musketeer no longer needs the Powder Mill; the Officer no longer needs the Horse
  Breeder; an Officer without a horse walks). Every unit with a firearm costs POWDER for its ammunition, the Officer too
  (pistol): trained with powder in the bank it comes out armed; trained with gold only it comes out with ZERO shots and
  fights with its melee weapon (bayonet, sabre) until it refills at a reloading point (Mill, Barracks, Town Hall, Powder
  Wagon), the refill taking that powder from the bank. A Barracks toggle ARM WITH POWDER (default ON). PARTIAL ammo when
  the bank holds less than a full load. The gold-only rush is allowed (it is the Horseman rush: the Horse Breeder costs only
  gold). MOUNTED and LIMBERED units keep the Horse Breeder requirement; a Horseman with no horse is an Officer.
- AI READS THE SCOUT (owner, 2026-11-05 09:34; job ai-reads-scout): "the absence of army or buildings is already
  information": a scout report reads GREEDY / AGGRESSIVE / DEFENSIVE / UNKNOWN. Fixed plans keep their plan (survival
  aside; owner: "it is useful to have the AI follow the plan"); Claude's proposal being built: BALANCED becomes the
  ADAPTIVE plan (v greedy: punish or out-expand; v aggressive: defend then counter; v defensive: out-expand and tech).
  Also a full audit of the AI STORY lines (wrong lines fixed; wrong logic behind them fixed).
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
  scout sees. Brood FOOD_BONUS 1.5 -> 0.8 (it out-earns both Hard computers 1.4-2x): NOT YET (owner, 2026-11-04 15:05: "the
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
