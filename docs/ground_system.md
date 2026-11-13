# The ground system (owner's idea, DECIDED 2026-11-13 01:34-01:40; not built yet)

## The idea (the owner, 01:34)

"What if we made all resources linked to a radius area like the Rootmaw is? But we made a clear indication of where
things are exhausted, maybe during the building menu when selecting a resource we see the radius in red where it is
already exhausted, and we can overlap but extract less. ... when we place a resource there the radius will overlap with
some of the exhausted area, then we get a proportional amount of available resources there."

Why: today "2 Farms a Town Hall" is counted over the whole empire (Game.econ_limit = per hall x halls, Game.econ_count
counts every Farm, spent ones too), so Farms on a spent hall's soil block Farms at a fresh hall until they are pulled
down: a trap a player cannot see (docs/economy_parity.md section 3, item 2). The soil itself lives in the Town Hall
(Defs.LODE, "Harvests draw on its Town Hall's soil").

## Decisions

- **District per hall** (owner, 01:40): resource ground exists only in a hall's district (Crown Town Hall, Clockwork
  Clocktower; the Brood: the Mother and its Mound Turtles' ground, as the Rootmaw already works); each district holds a
  fixed amount. Expanding stays the way to new ground.
- **After the economy coaching** (owner, 01:40): the jobs econ-coach-crown / -clockwork / -brood finish on today's rules
  first (a clean "before" picture); then the ground system is built as a SETTINGS EXPERIMENT (like TURNING GEARS), benched
  with tools/econ_bench.gd, and the computers coached to place on good ground.

## Claude's draft of how it works (for the owner to change)

- A **ground layer** on the map grid: every tile in a district holds an amount of its resource (Crown: soil for Farms,
  saltpetre for the Powder Mill; Clockwork: brass ore for the Cog Presses / Mainspring; Brood: biomass for Rootmaws, as now).
- Each economy building **drinks from a circle** around it (the Rootmaw's 8 tiles as the model), evenly from the tiles it
  covers; its yield is the share of its circle's ground still there. Overlapping circles of one side **share** the tiles
  (no free income from stacking). Spent tiles stay spent (docs/exhaust_economy.md: exhausted means exhausted).
- **Placing**: the circle is tinted green (full) to red (spent) and shows "62% of a fresh spot"; the minimap can show the
  same layer.
- **The ground layer shows while placing ANY building** (owner, 2026-11-13 01:37: "it can affect building strategic
  placement"), not only economy ones: a FAINT tint over the districts (where the ground is fresh or spent, and the circles
  of the economy buildings already there), so a Barracks or a wall is not put on the best ground by mistake. Faint enough
  not to distract; the economy building being placed shows its own circle stronger, with the "%" number. (A Settings
  slider for its strength is the obvious extra.) The building limit per hall becomes local (or goes away: to decide when built, measured with the bench).
- Saves, replays and online carry the layer (a compact grid; online sends changes).
- Open for the build job: the exact radii and amounts per faction (measured so today's bench curves stay about the same),
  whether the Clockwork's spring life stays in the Clocktower, how the AI chooses spots (best ground in its districts),
  performance on big maps.
