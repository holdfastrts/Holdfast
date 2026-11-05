class_name AIStoryLines
extends RefCounted
## THE AI STORY's phrase book (spectator overhaul 0.27.0, docs/spectator.md): how a computer's match-log line becomes a
## short narrator sentence. Data only: add a row here when an AI gets a new log line.
##
## A row: [pattern, template, priority, tag]
##   pattern   a regular expression on the line AFTER the player ("P1 Crown"): it starts with "'s " or with the verb
##             ("opens with ...", "'s rush: ..."). The first row that matches wins.
##   template  the narrator's sentence: %s is the player ("P1 Crown"), then each capture group of the pattern in
##             order (use (?:...) for groups that are not wanted). An English text: it is also the i18n key
##             (tools/i18n/49_spectator.txt has its pt and es). "" drops the line (a duplicate of another).
##   priority  3 a big decision (strategy, attacks, expansions, giving up: spoken aloud), 2 a decision worth telling
##             (tech, walls, defence, raids: spoken when the narrator has been quiet a while), 1 a detail (shown dim,
##             never spoken, at most one per player every few seconds).
##   tag       what kind of decision: lines of the same player and tag close together are merged (AIStory.MERGE).
## A line no row matches is kept as a detail in plain English ("P1 Crown: <the line>").

const RULES := [
	# ---- THE READ OF A SCOUT REPORT and OPTIMAL's picks (ai-optimal, scripts/ai_read.gd, scripts/ai_optimal.gd): what it saw
	# -> what it makes of it -> what it does. The saw phrases and the why phrases are fixed (AIRead.SAW, AIOptimal) and are
	# translated as words of their own (tools/i18n/55_ai_optimal.txt).
	["^(?:'s (?:plan|Clockwork|Brood): )?OPTIMAL: the common opening", "", 1, "plan"],
	["^'s (?:plan|Clockwork|Brood): optimal: leans to (.+?) before it scouts \\((.+)\\)$", "%s leans to %s before it scouts: %s.", 3, "pick"],
	["^'s (?:plan|Clockwork|Brood): optimal: reads (\\w+) \\[(.+?)\\]: picks (.+?) \\((.+)\\)$", "%s reads the enemy as %s (%s) and picks %s: %s.", 3, "pick"],
	["^'s (?:plan|Clockwork|Brood): optimal: reads (\\w+) \\[(.+?)\\]: keeps (.+?) \\(it switched once this stage already; (.+) waits\\)$", "%s reads the enemy as %s (%s) but keeps %s: it has switched once this stage already, %s waits.", 2, "pick"],
	["^'s (?:plan|Clockwork|Brood): optimal: reads (\\w+) \\[(.+?)\\]: keeps (.+?) \\((.+?) cannot be played from here\\)$", "%s reads the enemy as %s (%s) and keeps %s: %s cannot be played from here.", 2, "pick"],
	["^'s (?:plan|Clockwork|Brood): optimal: reads (\\w+) \\[(.+?)\\]: keeps (.+?) \\((.+)\\)$", "%s reads the enemy as %s (%s) and keeps %s: %s.", 2, "pick"],
	["^'s Clockwork: plays the (.+?) from here", "%s now plays the %s from where it stands.", 2, "plan"],
	["^(?:'s Brood: )?scouted: (\\w+) \\[(.+?)\\] \\(.*\\): OPTIMAL picks its build from this", "%s reads the enemy as %s (%s).", 2, "scout"],
	["^(?:'s Brood: )?scouted: (\\w+) \\[(.+?)\\] \\(.*\\): it is all economy; switches to a timing attack at (\\d+:\\d+) \\((\\d+) supply\\)", "%s reads the enemy as %s (%s): it is all economy, so it switches to a timing attack at %s with %s supply.", 3, "plan"],
	["^(?:'s Brood: )?scouted: (\\w+) \\[(.+?)\\] \\(.*\\): it is all economy; races it", "%s reads the enemy as %s (%s): it is all economy, so its Economy plan races it, more bases sooner.", 3, "plan"],
	["^(?:'s Brood: )?scouted: (\\w+) \\[(.+?)\\] \\(.*\\): it is all economy; keeps to its (.+) plan", "%s reads the enemy as %s (%s): it is all economy, and it keeps to its %s plan.", 2, "plan"],
	["^(?:'s Brood: )?scouted: (\\w+) \\[(.+?)\\] \\(.*\\): a rush is coming", "%s reads the enemy as %s (%s): a rush is coming, so it defends first, then counter-attacks.", 3, "plan"],
	["^(?:'s Brood: )?scouted: (\\w+) \\[(.+?)\\] \\(.*\\): an attack is coming", "%s reads the enemy as %s (%s): an attack is coming, so it defends first, then counter-attacks.", 3, "plan"],
	["^(?:'s Brood: )?scouted: (\\w+) \\[(.+?)\\] \\(.*\\): it turtles; out-expands it", "%s reads the enemy as %s (%s): it turtles, so it out-expands it and techs up.", 3, "plan"],
	["^(?:'s Brood: )?scouted: (\\w+) \\[(.+?)\\] \\(.*\\): it turtles; keeps to its (.+) plan", "%s reads the enemy as %s (%s): it turtles, and it keeps to its %s plan.", 2, "plan"],
	["^(?:'s Brood: )?scouted: (\\w+) \\[(.+?)\\] \\(.*\\): keeps to its (.+) plan", "%s reads the enemy as %s (%s): it keeps to its %s plan.", 2, "plan"],
	["^could not see the enemy \\[(.+?)\\]", "%s's scout saw too little (%s): that proves nothing, so it builds no army for it and looks again soon.", 2, "scout"],
	["^scout trip \\d+ ends", "", 1, "scout"],
	["^scout under guard \\((.+?)\\)", "%s's scout backs away from a guarded spot (%s) and keeps looking.", 1, "scout"],
	["^scout pulled away", "", 1, "scout"],
	# ---- the opening and the plan
	["^opens with a Horse Breeder", "%s opens with a Horse Breeder: it plans an early Horseman rush.", 3, "plan"],
	["^opens with a Powder Mill", "%s opens with a Powder Mill: Musketeers first, a steady line of fire.", 3, "plan"],
	["^opens with its economy", "%s opens with its economy: the second base before any Barracks, Musketeers when there is a reason.", 3, "plan"],
	["^plays the Brood", "", 1, "plan"],
	# ---- the Clockwork's Economy and Balanced openings (clockwork-eco, scripts/ai_cw_eco.gd, scripts/clock_sites.gd)
	["^'s Clockwork: plays the (?:Economy|Balanced): the opening build", "%s opens for its economy: Winders non-stop and a fast second Clocktower, no army before it without a reason.", 3, "plan"],
	["^'s Clockwork: rush evidence", "%s saw a rush coming: a Light Works and Clock Soldiers first, then back to its economy.", 3, "defence"],
	["^'s Clockwork: lays a Light Works against the rush", "", 1, "defence"],
	["^'s Clockwork: lays a Ratchet Turret by the ramp against the rush", "%s lays a Ratchet Turret by its ramp: an emergency against the rush.", 2, "defence"],
	["^'s Clockwork: its next Clocktower's spot: .+?, room for (\\d+) of its ring", "%s picks its next Clocktower's spot where its ring of buildings fits (%s of them).", 1, "expand"],
	["^'s Clockwork: lays a Cog Press by its (?:new|old) Clocktower", "%s lays a Cog Press by its new Clocktower.", 1, "build"],
	# ---- the Crown's own computer (scripts/ai_crown.gd): its build order and milestones
	["^'s plan: (.+?), a build order of (\\d+) steps", "%s follows its own %s build order: %s steps, then its milestones.", 3, "plan"],
	["^'s build order: (?:Town Hall|the ramp)", "", 1, "build"],
	["^'s build order: (.+?) \\(supply", "%s's build order: %s.", 1, "build"],
	["^'s plan: the opening is over", "%s's opening is over: its milestones and its doctrine take over.", 2, "plan"],
	["^'s plan: milestone: (.+?) \\(", "%s puts up its next milestone: %s.", 2, "tech"],
	["^'s plan: the wave waits", "%s holds its wave back: the enemy army it knows is bigger.", 2, "attack"],
	# ---- the Crown's Dragoon raids (crown-builds-a, scripts/ai_dragoon_raid.gd)
	["^'s Dragoon raid: group \\d+ rides for", "%s's Dragoons ride out to raid the enemy's workers.", 2, "raid"],
	["^'s Dragoon raid: group \\d+ strikes", "%s's Dragoons get off their horses and shoot at the workers.", 2, "raid"],
	["^'s Dragoon raid: group \\d+ rides off", "%s's Dragoons mount and ride off before the defenders reach them.", 2, "raid"],
	["^'s Dragoon raid: ", "", 1, "raid"],
	["^'s plan: ", "", 1, "build"],
	# ---- the Crown's siege push (crown-builds-b, scripts/ai_crown_siege.gd)
	["^'s siege push: goes out: (\\d+) supply \\((\\d+) guns", "%s's siege push goes out: %s supply, %s guns behind a line of Musketeers.", 3, "attack"],
	["^'s siege push: sets up against (?:a|the) (.+?) \\(", "%s's line stands and its guns unlimber behind it, against the enemy's %s.", 2, "attack"],
	["^'s siege push: falls back", "%s's siege push falls back: the guns limber and go home first.", 3, "attack"],
	["^'s siege push: waits", "%s holds its siege push back: the enemy army it knows is bigger.", 2, "attack"],
	["^'s siege push: ", "", 1, "attack"],
	# ---- scouting and what it decides from it
	["^saw an enemy (.+?) \\(fast, a (\\w+) rush unit\\): evidence of a rush", "%s spots an enemy %s: a sign of a %s rush.", 2, "scout"],
	["^saw an enemy (.+?) \\(fast\\): raiders to watch for", "%s spots an enemy %s: fast raiders to watch for.", 1, "scout"],
	["^saw an enemy (.+?): a slow foot soldier", "%s spots an enemy %s: a normal opening, no rush yet.", 1, "scout"],
	["^sends a (.+?) to scout(?: again)?", "%s sends a %s to scout.", 1, "scout"],
	["^scout (?:was )?(\\w+).*: it saw nothing to go on", "%s's scout was stopped before it saw anything; it will look again soon.", 1, "scout"],
	["^the sentry backs away", "", 1, "scout"],
	["^posts a (.+?) at the foot of the walled ramp", "%s posts a %s at the foot of the enemy's ramp to keep watch.", 1, "scout"],
	# ---- rushes
	["^'s rush: goes out \\((\\d+) Horsemen", "%s's rush rides out: %s Horsemen together.", 3, "attack"],
	["^'s rush: FAILED \\((.+)\\): the riders", "%s's rush has failed (%s): it builds up and will attack only with a proper force.", 3, "rush"],
	["^'s rush: SUCCEEDED, mop-up", "%s's rush worked: the riders regroup to finish the job together.", 3, "rush"],
	["^'s rush: SUCCEEDED, (\\d+) workers left", "%s's rush worked: only %s enemy workers are left.", 3, "rush"],
	["^'s (?!Brood: )(.+?) failed: it builds up", "%s's %s failed: it falls back on economy and tech, and will return in force.", 3, "rush"],
	["^'s rush: ", "", 1, "rush"],
	# ---- after a held rush (AI transitions)
	["its army (\\d+) against the (\\d+) it saw: counter-attacks now with its whole army \\((\\d+) supply\\)", "%s held the enemy (its army %s against %s): it counter-attacks now with everything, %s supply.", 3, "attack"],
	["its army (\\d+) against the (\\d+) it saw: expands now", "%s held the enemy (its army %s against %s): it expands now while its army covers the new base.", 3, "expand"],
	["its army (\\d+) against the (\\d+) it saw: back to economy and tech; the next attack waits for (\\d+) supply", "%s held the enemy (its army %s against %s): back to economy and tech; the next attack waits for %s supply.", 3, "plan"],
	# ---- attacks
	["^'s first attack goes out \\((\\d+) supply, (\\d+) Horsemen\\)", "%s sends out its first attack: %s supply, %s of them Horsemen.", 3, "attack"],
	["^'s wave (\\d+) goes out \\((\\d+) supply; the next waits for (\\d+)\\)", "%s attacks again: wave %s goes out with %s supply; the next one waits for %s.", 3, "attack"],
	["^'s army is at the supply cap or far ahead \\((\\d+) supply\\)", "%s is at the supply cap or far ahead (%s supply): it attacks again.", 3, "attack"],
	["^pulls its wave back: it lost (\\d+) for (\\d+)", "%s pulls its army back: it lost %s for only %s, a bad trade.", 3, "attack"],
	["breaks in at an? (.+?): down in", "%s breaks through at the enemy's %s.", 3, "attack"],
	["pulls back from the (.+?): ", "%s pulls back from the enemy's %s: the fire there is too strong.", 2, "attack"],
	["would pull back from the", "", 1, "attack"],
	["^dropped (\\d+) Musketeers from a balloon", "%s drops %s Musketeers from a balloon behind the enemy lines!", 3, "raid"],
	["^sends its Great Winder with the army", "%s sends its Great Winder along with the army, to mend it in the field.", 2, "attack"],
	["^sent (\\d+) soldiers? back to refit", "%s sends %s soldiers home to refit.", 1, "army"],
	# ---- raids
	["^'s raid is through the wall", "%s's raiders are through the wall and after the workers.", 2, "raid"],
	["^'s raid breaks in at the (.+?) in the way", "%s's raiders break the %s in their way.", 2, "raid"],
	["^'s raid finds the way to the workers shut", "%s's raiders find the workers walled off and look elsewhere.", 2, "raid"],
	["^'s (.+?) goes on to harass the workers", "%s's %s goes after the enemy workers.", 2, "raid"],
	["^'s (.+?) (?:goes|comes) home", "%s's %s comes home.", 1, "raid"],
	["^'s (.+?) (?:keeps away|pulls back) from (.+?)(?: \\(|$)", "%s's %s keeps away from a %s.", 1, "raid"],
	# ---- defence
	["^holds the top of its ramp: the force below \\((\\d+)\\) is more than its army at home \\((\\d+)\\)", "%s holds the top of its ramp: the force below (%s) is more than its army (%s) can beat.", 2, "defend"],
	["^goes down with its army", "%s goes down its ramp with its army.", 2, "defend"],
	["^holds behind its wall: the wave \\((\\d+)\\) is bigger than its army \\((\\d+)\\)", "%s holds behind its wall: the enemy wave (%s) is bigger than its army (%s).", 2, "defend"],
	["^keeps its army home: the enemy army seen \\((\\d+)\\) is bigger than its own \\((\\d+)\\)", "%s keeps its army home: the enemy's army (%s) is bigger than its own (%s).", 2, "defend"],
	["^posts (\\d+) Clock Soldiers on HOLD at the top of its ramp", "%s posts %s Clock Soldiers at the top of its ramp against the riders.", 2, "defend"],
	["^groups its Winders up to fight the riders", "%s gathers its Winders to fight the riders together.", 2, "defend"],
	["^sends its Clock Soldiers as a group to the Winders", "%s sends its Clock Soldiers as one group to guard its Winders.", 2, "defend"],
	["^thinks it is hopeless", "%s thinks the game is lost.", 3, "end"],
	["^resigned after gg", "%s resigns: good game.", 3, "end"],
	# ---- walls
	["^walled its ramp(?: with a Cottage)? \\((\\d+) pieces, (?:\\d+) labourers on it, feared rush\\)", "%s walls its ramp in a hurry, %s pieces: it fears a rush.", 2, "wall"],
	["^walled its ramp(?: with a Cottage)? \\((\\d+) pieces", "%s walls off its ramp: %s pieces.", 2, "wall"],
	["^'s ramp wall stands", "%s's ramp wall is up.", 1, "wall"],
	["^plans a walled expansion", "%s plans a walled expansion.", 2, "wall"],
	["^lays (\\d+) wall pieces at its new hall", "%s walls in its new hall: %s pieces.", 1, "wall"],
	["^(?:closes an empty wall slot|plans palisade for an empty wall slot|found no wall plan|has no Cottage wall plan|sends a Labourer back)", "", 1, "wall"],
	# ---- the economy and expansions
	["^is expanding to fresh (\\w+) \\(left at its best hall: (\\d+)%\\), (\\d+) tiles", "%s expands to fresh %s: its best base has only %s%% left, so it goes %s tiles out.", 3, "expand"],
	["^'s economy is saturated on (\\d+) halls?", "%s's economy is full on %s bases: it needs a new one to grow.", 2, "expand"],
	["^holds its expansion: (?:a|the) swarm", "%s puts its expansion off: it must answer the swarm first.", 2, "expand"],
	["^puts its next hall off until its army can hold it", "%s puts its next base off until its army can hold it.", 2, "expand"],
	["^holds its Labourers at (\\d+) until the army catches up", "%s stops at %s workers: the army comes first.", 2, "plan"],
	["^pulled down a (.+?) by spent", "%s pulls down a spent %s.", 1, "expand"],
	# ---- tech
	["^researches SHIELD WALL \\(it met (\\d+) shooters\\)", "%s researches Shield Wall: it has met %s enemy shooters.", 2, "tech"],
	["^researches HIGH LEAP \\((\\d+) Springers", "%s researches High Leap for its %s Springers, to jump the enemy's cliffs and walls.", 2, "tech"],
	["^sees a swarm \\((\\d+) light melee", "%s sees a swarm of %s light fighters: it answers with a Heavy Works, Pendulums and another turret.", 3, "tech"],
	["^lays a Heavy Works", "%s lays down a Heavy Works, for Pendulums and Spring Ballistas.", 2, "tech"],
	["^builds a Mainspring by a Light Works", "%s builds a Mainspring by its Light Works, so it can make Springers.", 2, "tech"],
	["^builds a Mainspring by a fresh Clocktower", "%s builds a Mainspring by a fresh Clocktower: its old springs are worn out.", 2, "expand"],
	["^(?:keeps room|lets go of|lost the spot|finds no room|builds a Mainspring with room|lays its Escapement)", "", 1, "tech"],
	["^sends (\\d+) Winders to crew its Spring Ballista", "%s sends %s Winders to crew its Spring Ballista.", 1, "army"],
	["^'s (.+?) shells (\\d+) bodies", "%s's %s shells %s bodies so the Brood cannot feed on them.", 1, "army"],
	# ---- the Brood (its lines start "'s Brood: ")
	# ---- the Brood's written builds (brood-builds, scripts/ai_brood_builds.gd)
	["^'s Brood: spitter timing: goes out at [0-9:]+: (\\d+) supply, (\\d+) Spitters", "%s's Spitter timing goes out: %s supply, %s Spitters behind a pack of Raptors.", 3, "attack"],
	["^'s Brood: spitter timing: contact", "%s's Raptors go in and its Spitters spit from behind them.", 2, "attack"],
	["^'s Brood: brute siege: goes out: (\\d+) supply, (\\d+) Brutes", "%s's Brute siege goes out: %s supply, %s Brutes in front to break the way in.", 3, "attack"],
	["^'s Brood: brute siege: the Brutes batter the (.+?),", "%s's Brutes batter the enemy's %s while its Spitters cover them.", 2, "attack"],
	["^'s Brood: brute siege: BREACH", "%s's Brutes break through: the swarm pours in through the gap.", 3, "attack"],
	["^'s Brood: brute siege: falls back", "%s's Brute siege falls back: the way in still stands.", 3, "attack"],
	["^'s Brood: (?:spitter timing|brute siege): ", "", 1, "attack"],
	["^'s Brood attacks with", "", 1, "attack"],
	["^'s Brood: ALARM: an enemy army of (\\d+) out of its main", "%s sounds the alarm: an enemy army of %s is on the move. Warriors gather, grubs pull back.", 3, "defend"],
	["^'s Brood: ALARM: a Mound Turtle gets up", "%s gets a Mound Turtle up to root in front of its natural.", 2, "defend"],
	["^'s Brood: rush evidence", "%s sees signs of a rush: it keeps its army home and lays warriors.", 3, "plan"],
	["^'s Brood: attacks with (\\d+) supply", "%s attacks with %s supply.", 3, "attack"],
	["^'s Brood: pulls back: (\\d+) of (\\d+) left", "%s pulls its wave back: only %s of %s is left.", 3, "attack"],
	["^'s Brood: its wave goes on to the next target", "%s's wave moves on to the next target.", 2, "attack"],
	["^'s Brood: calls its wave home", "%s calls its wave home: the Mother is under attack.", 3, "defend"],
	["^'s Brood: its rush failed", "%s's rush failed: it builds up and will return in force.", 3, "rush"],
	["^'s Brood: defends with (\\d+) .* against (\\d+) .* at the Mother", "%s defends its Mother with %s against %s.", 2, "defend"],
	["^'s Brood: defends with (\\d+) .* against (\\d+)", "%s defends its home with %s against %s.", 2, "defend"],
	["^'s Brood: pulls its defenders back to the Mother", "%s pulls its defenders back to the Mother.", 2, "defend"],
	["^'s Brood: grows the Mother to stage (\\d+)", "%s grows its Mother to stage %s.", 3, "tech"],
	["^'s Brood: researches (.+)", "%s researches %s.", 2, "tech"],
	["^'s Brood: a grub goes to root a Mound Turtle on new ground, (\\d+) tiles out", "%s takes new ground: a Mound Turtle roots %s tiles out.", 3, "expand"],
	["^'s Brood: a grub goes to grow the (.+)", "%s sends a grub to grow a %s.", 2, "tech"],
	["^'s Brood: a Mound Turtle roots in front of the natural", "%s roots a Mound Turtle in front of its natural.", 2, "defend"],
	["^'s Brood: (?:\\d+) grubs gang up on an? (.+)", "%s's grubs gang up on a %s.", 1, "defend"],
	["^'s Brood: sends an? (.+?) to", "%s sends a %s to scout.", 1, "scout"],
	["^'s Brood: a Rootmaw", "", 1, "defend"],
]


## Plans the narrator tells at the start from the strategy (AI.STRATEGIES): what each one means.
const PLANS := {
	"balanced": "%s (%s) plays a balanced game: economy, tech and an army in steady waves.",
	"rush": "%s (%s) plans a rush: an early attack with a small army, expanding late.",
	"economy": "%s (%s) plays greedy: many workers and bases first, a big army later.",
	"timing": "%s (%s) plans a timing attack: it builds up and strikes once, in force, at about 4:30.",
	"air": "%s (%s) plans an air rush: fliers early, before the enemy can shoot them down.",
	"xrush": "%s (%s) gambles on an extreme rush: everything on Raptors, the first wave as soon as they hatch.",
	"spitter": "%s (%s) plans a Spitter timing: the Venom Sire early and a Spitter-backed wave at about 6:00, its economy growing behind it.",
	"brute": "%s (%s) plans a Brute siege: its Mother grows fast for Brutes that break the walls and turrets, the swarm behind them.",
	"optimal": "%s (%s) plays OPTIMAL: a common opening and an early scout, then it picks its build from what it sees.",
}

## The level names shown in the plan lines.
const LEVELS := ["easy", "normal", "hard", "brutal"]

static var _rx: Array = []


## The compiled patterns (once).
static func compiled() -> Array:
	if _rx.is_empty():
		for r in RULES:
			var rx := RegEx.new()
			if rx.compile(String(r[0])) != OK:
				push_error("AIStoryLines: bad pattern %s" % r[0])
				rx = null
			_rx.append(rx)
	return _rx


## The rule a line (after the player) matches: {i, template, prio, tag, args} or {} for none.
static func match_line(rest: String) -> Dictionary:
	var rxs := compiled()
	for i in RULES.size():
		var rx: RegEx = rxs[i]
		if rx == null:
			continue
		var m := rx.search(rest)
		if m == null:
			continue
		var args: Array = []
		for g in range(1, m.get_group_count() + 1):
			if m.get_start(g) >= 0:
				args.append(m.get_string(g))
		var r: Array = RULES[i]
		return {"i": i, "template": String(r[1]), "prio": int(r[2]), "tag": String(r[3]), "args": args}
	return {}
