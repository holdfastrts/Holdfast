# The Free Assembly's own sprites (rebel-art, 0.33.13)

The owner's four ChatGPT sheets for campaign mission 1's rebels (art/campaign/rebels/, SOURCES.txt) are cut into game
strips and worn over the campaign-m1 stand-ins (docs/campaign_m1_build.md). Cutter: `tools/import_rebels.py`
(`--contact DIR` writes contact sheets, `--write` rewrites the REBELS block of `scripts/campaign/rebel_art.gd`).
Pictures: `tools/shot_rebel_art.gd` -> docs/shots/rebel_art/.

| role (Rebels.ROLES) | plays as | sheet | strips | cell / anchor |
| --- | --- | --- | --- | --- |
| militia | Musketeer | militia_chatgpt.png | assets/units/rebel_militia/ | 86 x 37 / (43, 35) |
| pikeman | Pikeman | pikeman_chatgpt.png | assets/units/rebel_pikeman/ | 128 x 56 / (64, 54) |
| torch | Labourer + torch | torchbearer_chatgpt.png | assets/units/rebel_torch/ | 120 x 51 / (60, 49) |
| varenne | dismounted Officer | varenne_chatgpt.png | assets/units/rebel_varenne/ | 76 x 37 / (38, 35) |

The cells are as big as the widest frame needs around the anchor (the pike levelled, the torch thrust, a body lying with
its burning torch); soles are always 2 px above the cell's bottom, on the anchor row.

## How the sheets were cut

- The flat grey ground is keyed out (its colour is the median of the sheet's border, a pixel 21+ away from it is
  drawn); the divider lines (a column lit for more than 330 px in one run) are wiped.
- Figures are connected pieces with a BODY: a run of columns at least 40% of the piece's height that reaches the
  piece's ground and is mostly dark (a burning torch on the ground or a lone flame is bright, so it is not a man).
- Pieces holding several men (the sheets draw the men of a row overlapping: muskets, pikes and torches lie over the next
  man) are split body by body: pixels in a body's columns are that man's, the rest go to the man they stay joined to
  once the other bodies are cut away; pixels joined to two go by the row's rule (aim, fire, pike and torch rows: the
  man on the left, their weapons point right; others: the nearest). A torch's flame touching the next man's back goes
  whole to the man on its left.
- Smoke puffs (round, full, light grey clusters) are dropped, also where they touch the muzzle; the orange muzzle
  flash is kept on the fire frames (it reads well). Small pieces (a flash, a flame, a pike tip cut off by a gap) go to
  the nearest man within 26 sheet px.
- Rows: the men's soles clustered (a 40 px gap = a new row). Direction groups: the body's middle against the group
  edges (militia 0/270/560/955/1245; the other sheets their divider lines 295/588/912/1219).
- Scale: the median hat-to-soles of the idle row = 30 game px (the Crown Musketeer's), Varenne 31 (an officer). Militia
  x0.311, pikeman x0.280, torch-bearer x0.261, Varenne x0.245. Box filter, alpha kept from 40% coverage, specks cleaned.
- Colours as painted. The team shader only recolours the two key reds; the rebels have none (an exact key red would be
  nudged off it by import_art.unteam), so they stay GREEN AND BLACK whatever the side's colour. The Free Assembly's side
  colour in the mission stays green (palette 2: rings, bars, minimap); nothing else needed. No veterancy trim masks
  (tools/import_vet_trim.py is for the Crown's hats; the rebels never level up in the mission).

## Rows used, and the STAND-INS

| art | animation | from | stand-in? |
| --- | --- | --- | --- |
| militia | idle, walk, aim, fire, death | rows 1, 2, 3, 4, 7 | the e group's idle has two pairs: the first (the side view) is used |
| militia | reload | rows 5 + 6 | |
| militia | melee | the aim frame pushed 3, 5, 2 px forward (a bayonet thrust) | STAND-IN: the sheet has no bayonet row |
| militia | aimup, fireup | the aim and fire rows | STAND-IN: no aiming up (the mission has no flyers) |
| pikeman | idle, walk, death | rows 1, 2, 6 | |
| pikeman | brace | row 3, its last man | the other men's pikes run over the next man and are cut off |
| pikeman | attack | row 4's last man drawn back 7 and 4 px, then lunging 1, 5, 2 px | STAND-IN (moved, not redrawn), for the same reason |
| pikeman | (row 5, without his pike) | unused | |
| torch | idle, walk, death | rows 1, 2, 6 | |
| torch | mine (setting fire; played while he burns a building: Rebels.tick sets `torch_burning`, Unit._anim_name) | rows 3 + 4: torch raised, then thrust in | |
| torch | build | row 5 (the crouch with the flask) | STAND-IN: rebels never build |
| torch | walk n | row 2's second n frame twice (a 1 px bob) | STAND-IN: the sheet's n walk has no torch in frame 1 and two in frame 3 |
| torch | mine n | the idle n frames (torch held up) | STAND-IN: the n set-fire frames lose the torch or put it on his head |
| torch | mine se | row 3's first se frame + row 4 | STAND-IN: the se group's 2nd and 3rd frames throw the torch away (a lone torch) |
| varenne | idle, walk, death | rows 1, 2, 6 | |
| varenne | aim / fire | row 4 (pistol): the first frame / the rest | e and ne have the flash, s, se and n none |
| varenne | melee | row 5 (sabre) | |
| varenne | shout | row 3 | strips only (`shout_<dir>`): no animation plays it yet; a mission pose for later |

The code-drawn torch over a torch-bearer's head (Unit._draw_mission_marks) is now drawn only when he lacks the
rebel_torch strips.

## Problems in the sheets (a ChatGPT redraw would fix them)

1. The S, SE and NE groups are mostly SIDE VIEWS facing east (pikeman: every row but idle; militia: aim, fire, walk;
   torch-bearer: walk and set fire). Walking south the men are seen side-on. The Crown's own Musketeer sheet has the
   same layout (the owner's sheets were drawn over it), so it matches the Crown, but a real south view would read better.
2. Varenne's N group is drawn FACING SOUTH (his face, a raised fist): walking or standing north he shows his face. His
   idle in se / e / ne / n raises his fist (a shout) instead of standing.
3. The torch-bearer's N group: the torch comes and goes (walk frame 1 has none, frame 3 has two; set fire frames lose
   it or put the flame on his hat); the SE set-fire row throws the torch away.
4. The pikeman's brace and thrust rows: the men overlap, each pike runs over the next man's body, so only the last man
   of each group keeps a whole pike (the game uses that man, moved).
5. Death strips: the lying body is centred on the man's spot like the standing frames (the sheets give no common
   ground point), so the body slides half a body sideways as he falls.

### Ready prompts (one request each)

**A. Torch-bearer, north (back) view**: references: `art/campaign/rebels/torchbearer_chatgpt.png`,
`art/crown/musketeer.png`.
> Redraw ONLY the right-most column group of the attached torch-bearer sheet: the same man (black tricorne, black
> shirt, green neckerchief, brown breeches, flask on his belt) seen from BEHIND, walking away from us. Same pixel-art
> style, same size, flat grey background (#444748), no smoke, no text. Five rows, left to right in each row: (1) idle,
> 2 frames, torch held up in his RIGHT hand above his right shoulder; (2) walk, 4 frames, a real stride cycle, the
> torch ALWAYS in his right hand above his shoulder; (3) setting fire, 3 frames: torch raised, then swung forward and
> down in front of him (we see his back), then held low; (4) thrusting, 3 frames: the torch pushed forward at waist
> height; (5) death, 3 frames: he staggers, falls forward, lies face down with the torch burning beside him. Exactly one
> torch in every frame, never on his head. Leave clear space between figures so no torch touches another man.

**B. Varenne, north (back) view and calm idle**: references: `art/campaign/rebels/varenne_chatgpt.png`.
> Redraw ONLY the right-most column group of the attached sheet: Etienne Varenne (long black coat, green sash, black
> tricorne with a green cockade, sabre and pistol at his belt) seen from BEHIND, walking away from us. Same style, size
> and flat grey background, no text. Six rows: (1) idle 2 frames, standing calmly, hands down; (2) walk 3 frames;
> (3) shout 2 frames, fist raised over his head (from behind); (4) pistol 2 frames: aiming away from us, then firing
> (small flash, no smoke); (5) sabre 2 frames: raised, then cutting; (6) death 3 frames, falling forward. Then, on a
> second line below, his IDLE for the four other directions (south, south-east, east, north-east, left to right), 2
> frames each, standing calmly with his hands down (no raised fist).

**C. Pikeman, levelled pike and thrust**: references: `art/campaign/rebels/pikeman_chatgpt.png`,
`art/crown/pikeman.png`.
> Redraw ONLY rows 3 and 4 of the attached pikeman sheet (the levelled pike and the thrust), all five direction groups,
> with MUCH more space between the men: each man's whole pike, butt to point, must be clear of the next man (leave at
> least a pike's length between figures). Row 3: 1 frame per direction, pike levelled at chest height. Row 4: 3 frames
> per direction: drawn back, lunging forward with the arms straight, recovering. Same man, style, size and flat grey
> background; no text, no other rows. The south and south-east groups should face toward us (south, south-east), not
> to the right.

## Checks

- `tools/test_campaign_m1.gd`: 0 failures (the rebel pikeman wears `rebel_pikeman`; new checks: every animation the
  stand-in plays is drawn for each role, in all five directions). `tools/test_campaign.gd`: 0 failures. A boot with no
  SCRIPT ERROR. (Godot 4.7 aborts at exit after these headless runs, as it does on main.)
- Contact sheets of every strip: docs/shots/rebel_art/strips_*.png (4x, game green). Looked at by eye: no merged
  neighbours, no cut-off muskets, smoke gone; the faults left are the sheets' own (above).

## Pictures (docs/shots/rebel_art/, tools/shot_rebel_art.gd: a band of every role spawned and sent at the manor)

- `1_night_attack.jpg`, `2_night_attack_b.jpg`: night, zoom 2.5: Varenne (named), militia, pikes, torches coming at a
  barn. At night the black coats are dark silhouettes; the green sashes and cockades show up close.
- `3_stronghold.jpg`, `4_stronghold_close.jpg`: the fort's massed militia and pikemen (zoom 2 and 3.5).
- `5_day_skirmish.jpg`, `6_day_skirmish_b.jpg`: by day, zoom 3, the band at the manor fighting the Governor's men.
