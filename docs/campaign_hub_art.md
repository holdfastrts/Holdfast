# Hub art: the Rome study (option 2, layered)

Owner's decision 2026-11-11: each hub is a LAYERED PAINTING (background, then each character on its own) with motion in
code (smoke, candles, breathing), and the war map as the hub's table (different per faction). The Rome study is the
first test. ChatGPT prompts were given in chat on 2026-11-11, one request each:

1. the empty study (no people), the parchment war map on the desk as the table hotspot; refs p01_01, p01_02
2. the King seated with his pipe, alone on flat magenta (#FF00FF) to be keyed out; refs p01_01 + request 1's answer
3. old Tomasz as a cardinal, standing, on flat magenta; refs p01_03 (young Tomasz) + request 1's answer

Answers go to art/campaign/hub/rome_{room,king,tomasz}_chatgpt.png. Then: key out the magenta, place the layers in the
hub (CampaignMenu), smoke from the pipe bowl, candle flicker, slow breathing; the hotspots become glows on the layers.
The heir's layer waits for his name and look (docs/campaign_timeline.md).

## Built (0.33.16)

- tools/import_hub_rome.py: keys out the magenta (also the pocket between the King's hand, pipe and face), tones
  Tomasz's daylight scarlet into the candlelight, cuts the desk's front from the room (drawn over the King so he sits
  behind it), the two faces for the talk box's portraits, campaign/hub/rome.json (layers, fx points, focus).
- scripts/campaign/hub_scene.gd (HubScene): the layered painting, covering the box with its shape kept (focus 0.72:
  the crop takes more from the left so the King stays whole); candle halos, the room's flicker, the match, the pipe
  smoke, breathing; image_rect() places the hotspots on the picture. A hub uses it when it names "scene".
- The Prologue's hub is now THE KING'S STUDY: hotspots THE KING, TOMASZ (old, a cardinal), the WAR TABLE (the map on
  the desk), FAIRLEIGH'S LETTER (the sealed letter on the desk), ARMOURY (in the list only). Over the painting a
  hotspot has no box: pointed at, the person brightens (or the map/letter gets a gold wash) and its name shows. The
  King's and Tomasz's talk lines are PLACEHOLDERS for the owner to rewrite.
- Pictures and a film: docs/shots/hub_rome/ (tools/shot_hub.gd ... [film]).

## Built: the Clockwork and Brood hubs (0.33.26, job hubs-cw-brood)

The owner's ChatGPT pictures of 2026-11-12 (art/campaign/hub/nuremberg_{room,hollweg}_chatgpt.png,
station_{room,lindqvist}_chatgpt.png), made into layered hubs the same way as Rome.

- tools/hub_key.py: the code the importers share (the magenta key moved out of import_hub_rome.py, its Rome output
  checked pixel for pixel unchanged), plus a FRINGE clean-up for loose hair (magenta mixed into fine edges unmixed, held
  to warm colours), scaling, toning into a room's light (colour, lifted darks, gamma, a light from one side), floor
  shadows and the 192 px face portraits.
- tools/import_hub_nuremberg.py: MEISTER HOLLWEG'S WORKSHOP (Nuremberg). The room's empty stool on the right is
  painted out (inpainted, the floor's grain copied back over it) and Hollweg sits there on his own stool (scale 0.235:
  sized by his body against the workbench and the stool he replaces, his stool's feet on the old stool's spot),
  toned into the orange lantern light, lit a little more on the lantern's side, a soft shadow under him.
  campaign/hub/nuremberg.json fx: the two lanterns' flicker ("lamps"), a gleam running round the brass map's outer
  ring and another the other way round its inner ring, one round the clock's face once a minute ("glints"), his
  breath. The map's rings do not turn: that needs the ring painted on its own (docs/art_style_inconsistency.md).
  focus 1.0: a narrow box crops the left (the automaton), never Hollweg.
- tools/import_hub_station.py: DR. LINDQVIST'S STATION (the Amazon). The jar he holds is see-through glass and the
  magenta showed in it: that tint is turned into the jar's green glass at the same brightness before the key (the
  background round the jar stays background). He stands on the floor right of the table, before the nest (scale 0.43:
  his belt a little over the table top beside him), toned into the lamp light, lit from the lamp's side.
  campaign/hub/station.json fx: the desk lamp's flicker, the jars' slow green glow (eleven, his own jar too: "glows"),
  mist drifting and rain falling in the window ("mist", clipped to the window), his breath.
- scripts/campaign/hub_scene.gd: the new fx keys are generic and data-driven ("lamps", "glows", "glints", "mist",
  "flicker"; listed in its header); Rome's json names none of them and looks as before.
- campaign/campaign.json: the CLOCKMAKER storyline's hub is HOLLWEG'S WORKSHOP (hotspots BRASS MAP = the war table,
  MEISTER HOLLWEG, THE GREAT CLOCK, THE AUTOMATON, ARMOURY in the list), the EXPLORER storyline's (the Brood line) is
  LINDQVIST'S STATION (SPECIMEN CHART = the war table, DR. LINDQVIST, THE EGG under its bell jar, THE SPECIMEN JAR,
  ARMOURY). Their talk lines are PLACEHOLDERS for the owner to write (tools/i18n/campaign/campaign.txt, marked). Both
  storylines still open after the Prologue; Campaign.open_all (tests and tools/shot_hub.gd only) opens them early.
  The old placeholder hubs (the explorer's ship, the clockmaker's workshop with a priest) and their texts are gone.
- OPEN for the owner: the explorer storyline's line under the title still says "goes down into the deep earth"
  (written before the timeline put the creatures on an Amazon plateau); the storyline is called The Explorer though
  its hub is now Lindqvist's (the Brood side's narrator): rename or keep?
- Pictures and films: docs/shots/hub_nuremberg/ and docs/shots/hub_station/ (pc 1280x720 and a phone's 20:9,
  pointed-at and talk views, a 6 s film each), by tools/shot_hub.gd <outdir> pc|mobile [film] line:clockmaker /
  line:explorer.
- Tests: tools/test_campaign.gd checks both hubs (the painting loads with its person, the hotspots, the talk).
