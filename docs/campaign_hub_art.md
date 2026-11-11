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
