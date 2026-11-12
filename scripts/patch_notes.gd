class_name PatchNotes
extends RefCounted
## What each version changed, newest first (the PATCH NOTES page in Settings shows the entry of
## the running version first). Add an entry for every pushed version (see CLAUDE.md).

const NOTES := [
	{"v": "0.33.17", "items": [
		"THE BROOD COMPUTER AGAINST ANOTHER BROOD, COACHED (docs/brood-v-brood-coach.md): two Hard Brood computers were filmed on five maps and each mistake fixed and replayed. It no longer takes the other Brood's Raptors for Horsemen: every Raptor wave used to set off its answer to a Horseman rush for the rest of the game (grubs off work, warriors on guard, no chase, waves held back), and its economy at 8:00 was a third of what it is now (about 9,500 earned and 54 grubs, was 2,500-3,500 and 12-25).",
		"It no longer reads the other Brood's normal opening (no production building, a turtle on new ground) as greed and rushes it at 1:40: against a Brood, greed is a third base early with little army. Its OPTIMAL plan no longer throws the dice for the Raptor rush against another Brood either (it lost or trailed 5 of 6 measured games).",
		"NO BASE TRADE: when the enemy Brood's army heads for its Mother while its own wave walks the other way, the wave turns and meets it; and a wave strung out along the road closes up before it meets an enemy army instead of arriving single file.",
		"IT KILLS THE MOTHER: a wave with the upper hand at the enemy Brood's Mother goes for her instead of her fresh eggs, hatchlings and Sires (a Mother at a fifth of her health lived for minutes with a hundred Raptors round her).",
		"ITS SIRE KEEPS LAYING: with eggs in her clutch and the food for them, the Sire of its quickest line stays on his nest when the enemy comes to the Mother (all three got up to fight and nothing could be laid while the food piled up), and it saves nothing for her growth while she is under attack.",
		"A wave fed by reinforcements now counts them in what it lost (it fought on into a ramp for eight minutes and never pulled back), and a wave that is winning goes on instead of going home at a quarter of its size. Only against another Brood; no unit, building or economy number changed.",
	]},
	{"v": "0.33.16", "items": [
		"THE KING'S STUDY (campaign): the Prologue's hub is now the King's study in Rome, painted in layers: the King in his chair lighting his pipe, old Cardinal Tomasz standing by, the war map on the desk and Saint Peter's in the window. The candles flicker, the pipe smokes and both men breathe. Point at the King, Tomasz, the map or Fairleigh's letter: it lights up and its name shows; the talks show their faces.",
	]},
	{"v": "0.33.15", "items": [
		"THE CLOCKWORK COMPUTER FINISHES WHAT IT STARTS: when its push is clearly ahead (from 8:00, worth twice the enemy army it has seen and reckons) it goes for the enemy's halls (against the Brood: the Brood Mother), no longer stops short of a main it can take, and its soldiers break buildings together with the Ballistas. A big push marches in rows and no longer stands still because its front could not all fit on one line. Its push now counts as an attack for the match tools.",
		"ITS GREAT WINDER SWEEPS: it walks just behind the army and, between fights, sweeps the Clockwork wrecks near the army into cogs (it stood far behind and swept nothing).",
		"DRY LAND: with its brass spent, the Clockwork computer stops its opening build and saves for a new Clocktower and its Cog Press before more units (it trained soldiers until it was broke, then stood still); Cog Presses left by a lost Clocktower that no longer turn are pulled down so the new Clocktower gets its own.",
		"A Clock Soldier or two left far from home harass the enemy's workers again (past rooted creatures) instead of attack-moving home into a rooted Mound Turtle; units far out walk home with a plain move.",
		"ENEMY FLYERS: the Clockwork computer lays its Clock Aviary as soon as it sees one (anywhere on its gear field) and trains Swifts at once (it took a minute or more).",
		"Its sentry at a walled ramp peeks up the ramp now and then to see behind the wall; a computer unit on a move order no longer rides round a turning gear band for long.",
	]},
	{"v": "0.33.14", "items": [
		"THE CROWN COMPUTER PLAYS WHAT WORKS IN EACH MATCHUP (its OPTIMAL plan): every Crown plan was measured against the Hard Brood and Clockwork computers on four maps. Against the Clockwork it now picks the Timing attack first (it won or led 3 of 4), sometimes the economic race or the balloons, where it used to play Balanced (won or led 2 games of 33); against the Brood it keeps the Horseman rush (the Economy plan, tried, did no better).",
		"NO NEW BASE INTO THE ENEMY THAT JUST TOOK ONE: the Crown computer remembers where it lost a Town Hall and keeps off that ground until the enemy has gone (it used to lay the new hall in the same spot and lose it again), and with its last hall under attack it keeps its gold to rebuild.",
		"ITS ARMY IS NO LONGER SHUT IN ITS MAIN: the computer's buildings keep the two cells in front of its own gates clear (its second Barracks could block the way to the ramp's gate, and the army stood at the cliff edge for minutes).",
		"THE NATURAL'S PALISADE GOES UP ON TIME: once a hall's worth of labourers works, the Crown computer lays its natural's wall before more labourers (sealed about 3 to 4 minutes after the hall stands; before, mostly open long after).",
		"WATCHING COMPUTERS: the AI STORY says why the Crown holds the top of its ramp or its natural's gate (its army goes down only with a margin over the enemy), that it lost a base and keeps off that ground, and no longer says \"its best base has only 100% left\".",
	]},
	{"v": "0.33.13", "items": [
		"THE FREE ASSEMBLY IN ITS OWN COLOURS (campaign mission 1): the rebels no longer borrow the Crown's soldiers painted green. The militiaman, the pikeman, the torch-bearer and Etienne Varenne wear new drawings of their own, green and black whatever the side's colour: the militia load, aim, fire and fall; the pikemen level their pikes and lunge; the torch-bearers carry a burning torch and raise and thrust it into a barn while they set it alight; Varenne raises his fist, fires his pistol and fights with his sabre.",
		"The torch-bearer's torch is no longer drawn over his head by the game: he holds his own.",
	]},
	{"v": "0.33.12", "items": [
		"CANNON AND MORTAR SHOTS ON BUILDINGS AGREE: a Field Cannon or Mortar told to attack a building (a right-click, an attack-move, a target it picked itself) hit it with its building bonus twice, while ATTACK GROUND on the same spot hit it once (a cannon ball did 270 or 108, a shell 68 or 45). Now every way of firing applies the bonus once, and the bonus was raised so a shot does what a right-click did: a cannon ball 270 to a building (bonus x6.25, with the splash), a mortar shell 68 (bonus x2.25). Bombarding a building is now as strong as attacking it. The card's \"Bonus vs buildings\" line says what a hit does to a building and how much a second.",
		"NO ATTACK BUTTON FOR THE UNARMED: the Powder Wagon, Messenger, Observation Balloon, Great Winder, Marching Band and the Missionaries no longer show ATTACK (and A does nothing for them). In a mixed selection the armed units attack and the unarmed ones walk along.",
		"A SIDE WITH NOTHING LEFT LOSES: no workers, no fighting units and no way to make more (nothing in training, no building that can train a unit you can pay for) for a whole minute is a defeat, as when the last building falls; you are warned when the minute starts. A side with a worker, a soldier, a unit in training, or a hall and the price of a worker is never beaten this way. The Brood still lives while its Mother does.",
		"COMPUTERS FINISH THE GAME: once the enemy has no army left, the computer sends its army after the enemy's last buildings (and the Brood's Mother) instead of waiting at home.",
		"Fixed two errors in computer games: the Crown's siege could stick on a palisade piece the enemy had turned into a gate, and the Spring Ballista stopped picking targets near a crate or powder keg on the ground.",
		"The dismounted Officer between pistol shots and the uprooted Mound Turtle fighting now use their idle and walk pictures on purpose (their own strips are still to be drawn).",
	]},
	{"v": "0.33.11", "items": [
		"CARD LINES FIT THEIR CARD AGAIN: the Great Winder's short line (in every language) and the Portuguese lines of the Marching Band and the Mainspring were longer than a card holds and ran off it; they are shorter now.",
		"WATCHING COMPUTERS: the story line \"its scout was stopped before it saw anything\" now shows (it was lost to an error).",
	]},
	{"v": "0.33.10", "items": [
		"QA OF THE INTERFACE (docs/qa_2026_11_08_ui.md): every menu page, Settings tab and button, the skirmish setup with every map, the HUD of each faction, the end screen, the tutorial, the campaign, the map editor, saves, replays, online play and the web version were checked at two computer sizes and two phone sizes in English, Portuguese and Spanish. Every setting saves, and a saved match comes back identical.",
		"Fixed: the CONTINUE button's factions and clock were cut off, and HOW TO PLAY shrank to a tiny font (a label may now take two lines); a long map name lost its arrow in the skirmish setup; a random pool with one fitting map said \"One of 1 maps\"; the Town Hall's card said Soil and Saltpetre in English in Portuguese and Spanish; watching computers on a phone, VIEW said \"Free · all vision\" in English, the panels said P1 where the lines above said J1, a build-order step (\"Farm 2\") was left English and a scout line showed \"?\" for the player; the layout page, the animation viewer and the relay address row are translated; a new map in the editor is named in your language; three card lines that ran over the card's length are shorter.",
	]},
	{"v": "0.33.9", "items": [
		"FEWER FREEZES FROM THE AUTOSAVE: the save every 15 seconds and the match log are now written to the phone's storage in the background. When the storage was busy, that writing froze the game for a tenth to a quarter of a second in the middle of play. Its first step on screen is also lighter (the save's text is made a frame later).",
		"LESS MEMORY ON PHONES: the Brood Mother's pictures of a stage she has grown out of are let go (about 70 MB each, kept for the whole match before), and every unit and building picture of a match is let go when you go back to the menu (before, a session kept every picture it had ever shown: 100 to 260 MB per matchup).",
		"Units hidden behind a building or a big creature (their silhouettes) are found with a third less work: up to 16 ms in one frame in a big musket battle with cannons. The same silhouettes as before.",
		"THE WEB VERSION: the campaign's paintings and voices moved from the code download (downloaded again after every update) to the art download (kept by the browser): an update that only changes the game now downloads 4.4 MB instead of 13.7 MB.",
		"The game plays out exactly the same as before: checked unit by unit in 12 big battles and 3 whole computer matches.",
		"Pictures of units about to appear (an egg's hatchling, a unit in training, a Horseman getting off his horse, the Mother's first egg) are loaded ahead in the background: their first appearance froze the game for a tenth of a second or more.",
	]},
	{"v": "0.33.8", "items": [
		"RELEASE LETS THE HORSES GO FOR GOOD: a Labourer or soldier sent to LEAD fetches up to three horses one after another; pressing RELEASE while he was still fetching let go of the ones in hand, then he went on and took the rest. Now RELEASE also calls off the fetches still to come, and online it reaches the host (it was only done on your screen).",
		"TOOLTIPS: the TEAM button of the Field Cannon, Mortar and Powder Wagon and the gate's LOCK / UNLOCK now say what they do.",
	]},
	{"v": "0.33.8", "items": [
		"RELEASE LETS THE HORSES GO FOR GOOD: a Labourer or soldier sent to LEAD fetches up to three horses one after another; pressing RELEASE while he was still fetching let go of the ones in hand, then he went on and took the rest. Now RELEASE also calls off the fetches still to come, and online it reaches the host (it was only done on your screen).",
		"TOOLTIPS: the TEAM button of the Field Cannon, Mortar and Powder Wagon and the gate's LOCK / UNLOCK now say what they do.",
	]},
	{"v": "0.33.7", "items": [
		"THE MUSKETEER MARCHES ON NEW LEGS: a hand-drawn six-step walk in every direction, his musket carried the same way it is held when he aims (before, his legs were the labourer's pasted under him and each direction had its own number of steps, so turning jumped).",
	]},
	{"v": "0.33.6", "items": [
		"THE BROOD EARNS A LITTLE LESS FROM FAR ROOTMAWS: a Rootmaw far from the Brood Mother now pays up to 2.2 times the near rate (was 2.5). Near Rootmaws pay as before.",
	]},
	{"v": "0.33.5", "items": [
		"THE BROOD COMPUTER READS THE HORSEMAN RUSH IN TIME (the owner's Hollowfen game: it read \"a standard opening\" one second before three riders hit it). Against the Crown its first watching grub now walks round the Crown's main before it settles at the foot of the ramp: a Horse Breeder early with no Powder Mill, a Horseman or horses early, or riders seen leaving the main is read as a rider rush, about two minutes before the riders come in the computer's games. A watching grub that sees soldiers backs off and comes back instead of walking home.",
		"IT DEFENDS THE GRUBS, NOT THE OPEN FIELD: on the read the Tyrant Sire comes at once and Raptors are laid just in time (no Sire research meanwhile); grubs a rider comes near run to the warriors, which guard them by the Mother or at the threatened Rootmaw and never chase a rider past a short leash. Grubs no longer gang up on a healthy Horseman (only on a lone hurt one, or as a last resort with no warriors at home), and the Mother stays rooted, her swamp feeding the Rootmaws, while her warriors are there.",
		"AND IT GETS BACK TO WORK: riders are no longer the generic rush alarm (no grub cap, no three minutes of Raptors only, no Mound Turtle walking out in front of the natural); once the riders have gone it says so and goes back to grubs and expanding. The AI STORY tells the read, the guard and the end of the raid.",
	]},
	{"v": "0.33.4", "items": [
		"THE CLOCKWORK'S PUSH NO LONGER CHASES ONE RIDER (the owner's Hard Crown OPTIMAL v Hard Clockwork game: its attack turned round and the whole army ran after one Horseman). A few fast riders round the push (all faster than its front, worth less than 260 and 15% of it) no longer stop the march: the front shoots what comes in reach and walks on, a soldier led more than 300 px off after one walks back to the block, and in a real fight its line follows the enemy at most 360 px from where the fight began.",
		"A raid at home does not call the push back unless it is a real attack (as before) or a hall or Mainspring is about to fall (under 35% with enemies at it); a token raid is met by the units at home. An army defending its base gives up a chase once it is 520 px out from its buildings and walks back.",
		"THE CROWN COMPUTER PUTS ITS ARMY FIRST when it is far behind (the same game: 44 labourers and an army of 455 at 7:00 against 1,490, and Barracks 2-4, a Church and an Armoury built with an army of 3-4 supply): once its second hall stands and 22 labourers work, while its army is worth less than 60% of the enemy's it reckons (what its scouts saw, never less than a Hard computer of that age has), the soldiers come before more labourers, the Church and the Armoury wait, and another Barracks or Foundry only when every one it has is busy. After a GREEDY read answered with an attacking plan it keeps 90%: a greedy read means pressure, not more labourers.",
		"The Crown computer's musket line no longer climbs to the cliff edge above a palisade or a building of its walled natural: those are held from inside the wall. The cliff edge is for a building right under the main without a wall. And the army goes down to its natural's gate once half its wall is closed (it waited for 70%).",
		"The AI STORY tells these: the push that does not chase riders, the push turning home for a building about to fall, the army giving up a chase, the whole army defending its base, the Crown putting its army first.",
	]},
	{"v": "0.33.3", "items": [
		"THE CROWN'S OPTIMAL OPENING, THE OWNER'S CALL: the ramp Cottage, the Gate, the BARRACKS (a rush is not ruled out yet), then the second FARM; no Powder Mill and no soldiers before the scout's read. While it waits for the read its labourers and Cottages keep coming (it used to wait 45 s with the gold in the bank, and in the Crown mirror it gave the pick up). After the read: the Powder Mill and Musketeers at once against a rush, the Mill or riders by the plan it picks otherwise.",
		"AGAINST A GREEDY BROOD the Crown's OPTIMAL now builds the HORSE BREEDER the moment its scout reads the greed (the owner's call) and sends its first three Horsemen at the Brood's grubs (out at about 3:35), then lays its Powder Mill and second hall behind the raid; read too late (after 2:45), it out-expands it instead. It was the Siege push, with 8 Musketeers, a Farm and the Horse Breeder before its second hall (4:20-4:45) and its guns after 6:00: no punish at all. Measured to 15:00 against greedy Brood computers: the riders come after the first Raptors, yet the Crown held 6 games of 16 with them, none with the Siege push or with an early second hall.",
		"NO MORE SUPPLY BLOCKS IN THE CROWN COMPUTER'S OPENINGS: every plan starts its next Cottage while there is still room for what its hall, Barracks, Breeder and Foundry make during the Cottage's 20 s build (it stood at 18/18 for 16-56 s before 6:00 against the Brood). The Horseman rush trains no Musketeer without powder while its Horse Breeder goes up. Holding a rush before its first Mill grinds, the Crown computer trains its Musketeers with gold only (bayonets at the gate, the shots refilled once the Mill grinds): against the owner's 6-pool Brood rush the common opening's first three Musketeers come at 1:57-2:27 and the gate holds.",
	]},
	{"v": "0.33.2", "items": [
		"THE CLOCKWORK COMPUTER'S ARMY RESTS ON ITS GEARS (the owner's Kestrel Rise game: the idle army wound down). At home it now waits at the edge of its own gear ground where the enemy's way in reaches the base, each unit on its own spot beside the turning gears (a still floor plate when there is room); a unit run down to 80% steps onto the gears for two or three seconds (they wind 0.3 a second) and walks back, a few at a time, and the Winders wind the rest. In 16 test games its army waited at 0.91 wind on average, against 0.83 before.",
		"THE WHOLE ARMY DEFENDS THE BASE: the gathering point is now between the base and the way the enemy comes (it waited by the newest Clocktower, away from where the Brood came in); an attack on any building, the Winders at work or a press is answered by the whole army with its Winders, the raids counted together (a swarm comes in at several buildings at once: 65 Raptors used to be met by groups of 4, 13, 7 and 6), and it stays until the base is calm, then walks back to its gears. Only a token raid (worth less than 12% of the army, at most 300) gets a group. The AI STORY says it: \"the army rests on its gears\", \"the whole army defends the base\".",
	]},
	{"v": "0.33.1", "items": [
		"THE CROWN COMPUTER HOLDS ITS WALLED NATURAL (the owner's playtest on Dune Sea): the GATE of a walled expansion now goes on the stretch of palisade nearest the foot of the main's ramp, so the army walks out of the main straight through it (on Dune Sea 7 steps from the ramp's foot instead of 17, on the far side of the wall).",
		"Once the natural's wall is mostly closed and its gate stands, the Crown computer's army waits DOWN at that gate, just inside the palisade, Musketeers on HOLD facing out and the guns behind them, instead of on the main's high ground (the cliff-edge post stays for the main alone, before there is a walled natural). Against a force it can't beat it holds the gate and the labourers run in behind the line.",
		"SITES KEEP CLEAR, for everyone: soldiers standing on a building you place step a full cell clear of it, a man on HOLD holds again where he stepped to, and nobody is walked back onto a site still waiting to start (a move, a rally or a guard post there stops just outside it). The computer no longer places a building again on a spot that stayed blocked: it looks elsewhere.",
		"The Crown computer makes 3 Field Cannons before its first Mortar, in every plan (the siege push too); once its line has 4 Musketeers its Barracks and its tech (Church, Armoury) wait for those guns' gold, unless the enemy is at home.",
	]},
	{"v": "0.33.0", "items": [
		"THE MARCHING BAND IS A REAL CROWN UNIT (the owner's decisions): no more experiment switch. It is trained at the ARMOURY, and a new band is a DRUMMER (75 health). The FIFER and the PIPER are Armoury research, in any order: once done the musician joins every band you have, on the field at once, and every new band comes out with him (+15 health each); each makes a new band 25 gold dearer (50, 75, 100: the train button shows the real price).",
		"SEVERAL BANDS may play, like cannons, but their rings don't add up: each stat takes the strongest band's. Every instrument always gives +5% within 5 tiles (DRUMS movement speed, FIFE reload, PIPES melee damage) and +30% in its SOLO for 8 s, then 45 s before that instrument may solo again; one solo at a time in a band (two bands may solo at once). The fife now also speeds the Officer's pistol reload, and doesn't speed a man who has no shots. A solo that ended no longer lingers on men who stay in the ring.",
		"THE BAND'S ART: the owner's drawings of the Drummer, the Fifer and the Piper marching and playing (south-east; that view stands in for the others until they are drawn). The band is drawn as a group that grows: the Drummer leads, the Fifer and the Piper fall in behind him once researched; the musician leading a solo bobs and stands a little bigger, notes in his instrument's colour over him.",
		"THE CROWN COMPUTER trains a band once its army is about 10 strong (a second one at 30), researches the Fifer first in a musket army and the Piper first otherwise, keeps the gold back for them, keeps its bands behind the line, and plays the FIFE when 3 or more ringed soldiers are shooting, the PIPES when half are in melee, the DRUMS to catch a retreating enemy or get out of a lost fight.",
		"THE MIST TOAD'S FOG AND MIASMA are now research at the Venom Sire (cheap and quick; the Toad itself comes at the Mother's stage 3), as the band's solos are behind research; TONGUE needs none. The buttons show them locked until then. The Brood computer researches them once it has a Toad.",
	]},
	{"v": "0.32.3", "items": [
		"A NEW COMPUTER PLAN FOR EVERY FACTION, OPTIMAL: \"plays the best it can: scouts and picks from all its builds\". It opens the way its faction usually does (the Crown: the ramp Cottage, the Gate, the second Farm; the Clockwork: its economy opening; the Brood: Balanced's economy), sends a scout at once, reads what it sees and picks one of ALL its faction's builds for it: against a rush it defends first and counter-attacks; against a greedy enemy it punishes it while it can (the Crown's Horseman rush, sometimes, against the Clockwork, never the Crown; the Clockwork's Clock Soldier rush; the Brood's Raptor rush, or a timing attack; the Crown's Siege push against a greedy Brood its riders could not reach in time) or out-expands it when it is too late; against a normal game a normal game, a timing or an economic race by matchup, with a little chance in it; against a turtle it out-expands and later besieges it (Siege push, Heavy Works push, Brute siege). It reads again on every scout trip and changes its build at most once a stage (opening, middle, late). Against the Brood the Crown's OPTIMAL sometimes leans to the Horseman rush before it scouts. Pick OPTIMAL as a computer's plan (the RANDOM PLAN may pick it too).",
		"THE COMPUTER READS ITS SCOUT (the owner: \"the absence of army or buildings is already information\"): every report reads GREEDY (no army and no production at its base, an early second base, a full economy with nothing military), NORMAL, AGGRESSIVE (fast rush units early, a big early army, production on a thin economy, a Horse Breeder by 1:50), DEFENSIVE (turrets or rooted defenders, walls all round one base, a wall that kept the scout out) or UNKNOWN. UNKNOWN is never a reason for an army any more: no extra Barracks or Works, no army first; another scout goes 35 seconds later. A scout shut out of a walled main still looks at the natural.",
		"EVERY PLAN KEEPS ITS IDENTITY but survives: a seen rush is always defended; otherwise the plan you picked plays its own strategy so you can train against it or watch it. Economy races a greedy or turtling enemy (its next bases sooner) instead of turning into a timing attack; Balanced and Timing still punish a real greed with the timing attack; the other plans carry on. Every Clockwork build now reads a rush from what its own units see and answers it with Clock Soldiers. The Brood reads what its creatures see too, and its watching grub looks at the Crown's natural on its rounds.",
		"THE AI STORY TELLS WHY: what the scout saw, what the computer makes of it and what it does (\"P1 Clockwork reads the enemy as GREEDY (no army and no production at its base) and picks Clock Soldier rush: punish the greed before its army is up\"). Fixed lines that were wrong: \"could not see the enemy: plays safe\" (its scout was being sent back to a Farm halfway: fixed, and an empty look is a read now), a Raptor seen in mid game called \"a sign of a rush\", the enemy's own defenders at home read as a rush coming, an army walking out at 5:30 read as a rush, \"Musketeers first\" on the plans that build the second hall first, \"it fears a rush\" when the Rush plan walled its own ramp, \"the Barracks and the Mill first\" when both stood already.",
	]},
	{"v": "0.32.2", "items": [
		"THE CLOCKWORK COMPUTER FIGHTS AS ONE ARMY (the owner: \"it kept sending 1 or 2 Clock Soldiers to die instead of using the Pendulum and Springers it had\"). Every fighter now belongs to one army: no Clock Soldier scouts, harasses alone, guards the Winders in twos or runs out as a lone catcher any more. At home the army waits together in front of the Clocktower nearest the enemy, its Winders winding and mending it. A raid is met by a group worth half again as much as the raid (never fewer than three), or by the whole army when it is big; then they walk back together.",
		"IT GOES OUT AS ONE BLOCK: every Clockwork plan now attacks with the Pendulum plan's push: the army walks at the pace of its slowest unit, the Winders behind the front stay with it in a fight instead of running home, the Spring Ballistas are kept with the block, fresh units join it as a group, and it pulls back as one. It goes out only when it is stronger than the enemy army it reckons (what it saw in the last two minutes, never less than an enemy of that age has, never nothing), with a fresh scout report, and after a push that had to pull back only bigger than that one. Against the Crown a push without Ballistas waits short of the Crown's main until it is worth 2,000.",
		"IT USES ITS KIT AND MASSES SOONER: the Springers jump in to shooting range when the front engages (never into a knot of melee); the Pendulums and Netters fight beside the rest. On Economy and Balanced the army grows from the moment the second Clocktower's presses are laid. In 28 coached games (Hard, four maps, against the Brood and the Crown) fighters fighting alone fell from 9.4 to 4.4 a game (against the Brood from 9.4 to 2.4), the army was about 10% bigger, it lost about 11% less by 10:00, and no Clockwork base fell (before: 2).",
	]},
	{"v": "0.32.1", "items": [
		"SMOOTHER TO WATCH (the owner's Frostfang log: Hard Brood Economy against Hard Clockwork Economy fell from 87 to 8 frames a second by minute 7). The spectator's PRODUCTION, ARMY & STRUCTURES and AI STORY panels cost about 34 ms every time they were drawn: Godot keeps only its last 64 pieces of text ready, and the panels draw and measure hundreds (the AI STORY measured every line it wraps word by word), so every piece of text was worked out again on every redraw. The text is now kept ready between redraws (scripts/ui/text_cache.gd), each panel is on its own layer and redrawn only when what it shows changes (the AI STORY when a line comes in), and moving the mouse no longer redraws them. The panels went from about 18 ms a redraw (every frame while the mouse moved) to 0.2 to 2 ms, 4 times a second or less; the whole HUD's drawing from 10 to 34 ms a frame to under 1 ms.",
		"Watching computers, the fog of war (every side's sight and explored ground, worked out 4 times a second) is now worked out a whole row at a time, as in a match you play: 4 to 5 ms an update down to under 2 ms, exactly the same seen and explored ground.",
		"Smaller savings in the units' and buildings' work (exactly the same game): the turning gears' check for units in a Clockwork base, the Brood's rooted creatures' pictures, the footprints and gear rings asked thousands of times a second, the worker labels under the mouse, the top bar's supply. And the Brood computer's choice of what a grub turns into keeps the answers it already has within one think.",
	]},
	{"v": "0.32.0", "items": [
		"CROWN AMMUNITION, NO POWDER LOCK (the owner's rule): the Barracks trains Musketeers and Officers without any other building (no Powder Mill, no Horse Breeder: an Officer without a horse walks). Powder buys their shots instead: every soldier with a firearm comes out with the shots the powder in the bank pays for, 1 powder a shot (a Musketeer 10, an Officer's or Horseman's pistol 5: the loaded shot and 4 charges). With less powder he comes out with fewer shots; with none he comes out with the bayonet or the sabre only and fights with it until he refills. Horsemen and Dragoons still need the Horse Breeder.",
		"REFILLS COST 1 POWDER A SHOT (they were half), at a Mill, Barracks, Town Hall or Powder Wagon: training a man dry and refilling him is never the cheap way. The Powder Wagon fills at 1 powder a shot too (a keg is 30). An empty pistol is loaded at a reloading point, even in the saddle.",
		"ARM WITH POWDER, a toggle on the Barracks (on at the start): off, its recruits come out with no shots, the powder is kept for the guns, and that Barracks refills nobody. The train button shows the powder in its corner, and its tooltip says how many shots he would come out with now.",
		"THE AMMO ICON on the unit card for every firearm (the musket, the pistol, the cannon ball, the mortar shell) with the shots left; at 0 shots a red 'no' sign and NO AMMO under it; a bar filling with RELOADING while it reloads between shots or refills. A small red mark over your men with no shot on the field.",
		"THE CROWN COMPUTER trains Musketeers only with their shots' powder in the bank, turns ARM WITH POWDER off while its guns need the powder, and sends men low on shots to refill before a fight. The Horseman rush goes on as before (its riders come out with the sabre until there is powder).",
	]},
	{"v": "0.31.2", "items": [
		"THE CROWN COMPUTER NO LONGER STALLS ITS BUILD ORDER (the owner's Red Coast game: it opened well, then laid its Foundry at 4:13, the Foundry's labourer was sent at a Brood grub a second later and the site was dropped; the Horse Breeder step behind it waited for that Foundry for ever, so it built nothing but Cottages and labourers: 7 Musketeers, 68 labourers, 3,400 gold in the bank, and it lost). Now a site whose builder is pulled away gets another labourer, a half-built building nobody works on is finished, a dropped site's step comes back, and a step that waits 45 seconds with its gold in the bank goes to the back of the plan (then is dropped): the plan always goes on.",
		"LABOURERS STOP AT SATURATION (the owner: \"2 bases saturated and a few haulers, maybe 45 to 50 labourers\"): on the Economy and Balanced plans the Crown trains labourers up to the posts of its farms and Mills plus a few, never more than 48 on two halls; more only for a third hall.",
		"A BIG BANK IS SPENT: with over 700 gold for 15 seconds the Crown adds production (a Barracks, a Foundry, then a Church) whatever its income reckoning says, and a milestone it cannot place no longer holds up the ones after it. On the same Red Coast game: the Foundry stands at 5:04, the opening is over at 5:05, at most 48-51 labourers, under 400 gold in the bank all game, and an army of 1,800 at 8:00 instead of 420.",
	]},
	{"v": "0.31.1", "items": [
		"SHIELD WALL makes the Clock Soldier tougher: +10 health (75 -> 85) for every Clock Soldier, the ones already in the field too (the owner: Clock Soldiers are not that tough).",
	]},
	{"v": "0.31.0", "items": [
		"THE CAMPAIGN'S FIRST MISSION, \"THE LEAF AND THE FIRE\" (Virginia, 2767), as the owner's approved script: it is the Prologue now (the old test mission is gone from the campaign). The King, an old man in Rome, lights his pipe and tells it: five oil-painting stills open it, each with its lines and the speaker's name (THE KING, TOMASZ, LORD FAIRLEIGH); a tap or NEXT moves on, SKIP ends it. The ending plays over the canister still. Every line has a slot for a recorded voice (campaign/voice/p01/<line>.ogg): it plays when the file is there.",
		"PART 1, NIGHT: hold the plantation (the manor, the chapel, five drying barns) until dawn, about 8 minutes, against waves of the Free Assembly out of the tobacco fields. Torch-bearers set barns alight: kill them first. Varenne shouts his slogans, Captain Ruggieri answers with the guns, Tomasz sees the dead. The scene is tinted dark blue by night and warm at dawn. Lost if the manor falls, if every barn burns, or with fewer than three barns at dawn.",
		"PART 2, THE ROAD: clear two rebel camps, then a CHOICE: save the loyal families trapped at burning Hollins Farm (you arrive later and the rebels are better dug in at the fort) or march on (Tomasz remembers). The choice is kept for later missions. PART 3, THE GATE: bring the guns up, load CANISTER (a pointer shows the button on the cannon's card), \"Canister. On my word.\", and break the charge.",
		"THE FREE ASSEMBLY, GREEN AND BLACK, a minor side nobody can pick in a skirmish. Until the owner's art comes its men are stand-ins in green: militia (Musketeers), torch-bearers (Labourers with a torch), Etienne Varenne (an Officer with his name over him), and the PIKEMAN, back from retirement for the campaign only with his old strips: a long pike that out-reaches a bayonet and hurts horses. CO-OP: the friend commands Ruggieri's guns; VERSUS: the friend plays the Free Assembly.",
	]},
	{"v": "0.30.12", "items": [
		"THE BROOD COMPUTER NO LONGER SHUTS ITS OWN UNITS IN (the owner: \"Brood bad base design: the turtle-locked units are stuck inside\"). Before it roots a Mound Turtle, a Rootmaw or a Sire, or a grub turns into one, it now checks that the footprint closes no pocket: every piece of open ground, and every grub and warrior of its own, keeps a way out to the rest of the map at least two tiles wide (a Sire's nest, the cliffs and the map's edge count; the ground the Mother's nest will take as she grows is kept free). In the test games before the fix its whole base was shut in on Redrock Canyon (up to 69 units) and on Cinder Steps (149 units, its whole army, from 8:08 to the end); after it, no unit was shut in in any game.",
		"THE ALARM KEEPS THE TURTLES THAT FEED ROOTMAWS: when an enemy army comes out, the Mound Turtle the alarm sends in front of the natural is never one whose swamp is the only swamp under live Rootmaws (their swamp would go and they would uproot, as in the owner's Thornwood game at 3:32), unless it is dying; and on its way, met by enemies, it roots where it stands only where it closes nothing (it once rooted at its own ramp).",
		"A SAFETY NET: if its own units still end up shut in by its rooted creatures, the one that closes the pocket (a Rootmaw, a Sire or a Mound Turtle, never the Mother) gets up and roots elsewhere, or the units walk out through their own creatures. Brood units of any player walking out through their own rooted creatures now walk on until they are out on the open map, not just out of a small gap.",
	]},
	{"v": "0.30.11", "items": [
		"THE CLOCKWORK COMPUTER'S ECONOMY (the owner: \"it creates a Light Works for no reason very early without scouting any rush... minute 4 and it didn't expand yet\"). On ECONOMY and BALANCED the Clockwork computer now plays a written opening: Winders non-stop from every Clocktower, a Regulator, the second Cog Press, then the SECOND CLOCKTOWER at about 1:45, the Mainspring, the new Clocktower's two presses the moment it stands, and only then the Light Works and the Escapement (Balanced: its Light Works right after the second Clocktower, and a few Clock Soldiers). No Light Works and no soldiers before that unless its scout sees a RUSH coming (fast rush units or a big early army): then a Light Works and Clock Soldiers sized to what it saw come first, and a Ratchet Turret by the ramp only against a big rush (an emergency, never a plan), and the economy goes on behind them. In coached games against the Hard Crown and the Hard Brood it had about 26 Winders at 4:00 (before: 15) and earned about 40% more cogs by 6:00 and 8:00.",
		"EACH FACTION NOW HAS ITS OWN BEST EXPANSION SPOT. The Clockwork's is where its Clocktower's gear ring AND the ring of buildings it powers (Cog Presses, the Mainspring, Regulators, Works, the Escapement) all fit on open ground of the Clocktower's own level, away from cliffs and ramps, and near its other Clocktowers and safe. The gold EXPANSION SPOTS shown to a Clockwork player follow this rule, and so does the Clockwork computer's next Clocktower (before, the Clockwork was shown the general rating and its computer could squeeze its second Clocktower against the main's cliff and ramp). The Crown keeps its own rule (by the ramp's foot and the map's border) and the Brood its Mound Turtle spots.",
	]},
	{"v": "0.30.10", "items": [
		"THE CROWN COMPUTER PLAYS THE OWNER'S ECONOMY (the Economy and Balanced plans; the owner: \"First we need a better Crown AI\"). NO BARRACKS WITHOUT A REASON: the Economy plan walls its ramp, takes its second Farm and lays its SECOND TOWN HALL at about 1:30, before any Barracks; its Barracks comes after the second hall, or at once when its scout sees a rush coming (the scout now leaves at the start). The Balanced plan builds its Barracks right after the second hall, or sooner when the scout's first look saw nothing (against the Brood, whose fastest rush comes before any look, at the old time).",
		"A FARM AT EVERY NEW TOWN HALL AT ONCE (its gold is set aside while the hall goes up), labourers from every hall without a break, COTTAGES AHEAD OF THE SUPPLY (several at once when the Barracks are busy, so it is not stuck at the supply cap with gold in the bank), the natural's PALISADE RING by about 4 to 6 minutes in every matchup, the third Town Hall only when two halls are full and the army can hold it, and MORE BARRACKS AS THE INCOME GROWS (a Foundry every fifth). In coached games its army at 8:00 now matches the owner's own game.",
		"A LAID-OUT BASE: the computer plans each base when its Town Hall stands: the Farms and the Mill by the hall, Cottages packed together at the back edge of the main, the Barracks, Foundry, Church and the rest in neat rows with walk lanes between them, and the way from the hall to the ramp kept clear (it used to scatter them).",
		"DEFEND AT THE WALL, NOT ON THE HIGH GROUND: when the enemy attacks the palisade of a walled Town Hall, the army now goes inside that wall and shoots over it, Musketeers in rows behind the stakes, guns behind them, and labourers mend the hurt pieces. The cliff-edge line is kept for a hall without a wall. Powder Wagons at home stand apart by different halls instead of together.",
	]},
	{"v": "0.30.9", "items": [
		"ENEMY BUILDINGS ARE REMEMBERED UNDER THE FOG, AS LAST SEEN (the owner: \"after we scout buildings I don't think they are showing as ghosts in the fog of war, they should\"). Before, an enemy building you had seen stayed on screen as the LIVE building: under the fog you could watch it being built, damaged, its wheels turning and even its ruin when it fell. Now, once your eyes leave, it stays drawn where it stood as it looked when you last saw it (its frame, its damage, how far it was built, its gear ring stopped), a little darker, and on the minimap as a darker square. Razed out of your sight, it stays until you look at that ground again; then the picture goes and you see what is really there.",
		"The Brood's ROOTED creatures are its buildings, so a rooted Rootmaw, Mound Turtle, Sire or the Mother (or a cocoon) is remembered the same way, rooted where you saw it, until you look there again (seen walking elsewhere, its old picture goes). A remembered picture can't be selected; a right-click there is an order to that ground. Watching computers, replays and full vision are unchanged.",
	]},
	{"v": "0.30.8", "items": [
		"THE CROWN COMPUTER AGAINST THE BROOD (the owner: \"the problem with Brood vs Crown is the Crown AI\"). NO BLIND ATTACKS: against the Brood a wave or a timing now goes only with a fresh scout report (an enemy soldier seen, or its main looked at, in the last 75 seconds); without one the army waits on the high ground and a scout goes out first. And a Brood army it has not seen no longer counts as nothing: it reckons what a Brood of that age, with the Rootmaws it has seen, would have, and goes only with an army worth half again as much. It no longer lays a new hall while its army is out or clearly behind.",
		"THE NEW HALL IS WALLED AT ONCE against the Brood: its palisade goes down in the first minutes, in batches, the pieces nearest the enemy first, instead of waiting for a saturated hall and a big army (before, two Cottages of the plan stood alone in the open and no palisade came). The wall never takes the gold set aside for a building, the first Field Cannon, a labourer or a Musketeer. An empty slot in the line is closed with palisade 25 seconds after the hall stands. The ramp wall (the Cottage and the Gate) was already closed: a new test sends Raptors at it on eight maps.",
		"THE ARMY KEEPS UP: against the Brood the Crown computer keeps its army at about 60% of the Brood army it reckons, training soldiers before labourers while it is behind, and putting up its next Foundry or Barracks early when every one it has is busy.",
		"THE HORSEMAN RUSH KEEPS RAIDING while it wins against the Brood, hunting grubs and Rootmaws, and rides home only when the riders are beaten down, a real answer comes, or nothing has died for 75 seconds. A RANDOM PLAN against the Brood never picks the Balloon harass. Fixed: the match log said \"found no wall plan for its new Town Hall\" every second; it now says it once, with the reason, and asks again every 30 seconds.",
	]},
	{"v": "0.30.7", "items": [
		"TWO NEW PLANS FOR THE BROOD COMPUTER (pick them in the PLAN list, or a random plan may land on them). SPITTER TIMING: the Venom Sire early, Spitters ahead of the Raptors, the Venom line's Bigger Clutch the moment he is on his nest, and a Spitter-backed wave from 6:30 that walks at the Spitters' pace (the Raptors just ahead of them, not running off alone); the economy grows behind it as in Balanced. Once what is left is behind a wall it has no Brutes to break, it comes home.",
		"BRUTE SIEGE: the Mother grows to her third stage early, food and spoils are kept for Brutes, and with four Brutes and Battering Horns the push goes out: the Brutes batter the wall piece, gate or Ratchet Turret in the way while the Spitters cover them and the Raptors wait, then the whole swarm goes in through the breach. It falls back if its Brutes die or the wall holds.",
		"In coached games on Hard the Spitter timing won all six (trade 2.7 to 1; Balanced 4 won, 1 drawn, 1 lost on the same games) and its wave hit the Clockwork hard; the Brute siege won 6 of 8 and broke every wall or turret its Brutes reached, but both win about a minute later than Balanced against the Crown.",
	]},
	{"v": "0.30.6", "items": [
		"THE CROWN'S EXPANSION SPOTS, STEADIER: the OPTIMAL EXPANSION SPOT no longer wanders farther along under the main's cliff when a few decorations crowd the ground below the ramp (seen on the classic maps with 4 players). A spot more than 12 steps from the ramp's foot, or a first expansion more than 5 tiles past the least hall distance, now wins only when nothing nearer is free.",
		"THE CROWN COMPUTER NO LONGER STALLS THE GAME TO PICK ITS NEXT HALL (the owner's 0.30.4 match log: a 0.6-second frame at 5:14): it works the spots out ahead, a few milliseconds a frame, and keeps what it has measured until a building goes up near it. The same spots; the pick takes about 10 ms instead of up to 600.",
	]},
	{"v": "0.30.5", "items": [
		"Watching computers play: the PRODUCTION and ARMY & STRUCTURES panels are drawn again 4 times a second instead of 20. In the owner's Redrock Canyon game they took up to 45% of the computer's time once the armies passed 100 units.",
	]},
	{"v": "0.30.4", "items": [
		"THE CROWN'S EXPANSION SPOTS, REDONE (the owner: \"I don't know why you left the second expansion so far out\"): the OPTIMAL EXPANSION SPOT is back where the natural expansion was, but pulled in to the least distance a hall allows (18 tiles from the main), as close to the foot of the main's ramp as it can be (a short walk for the army and the workers) and against the edge of the map where there is one (fewer sides to wall). The second spot mirrors it on the other side of the ramp, with the same aims, instead of far round the main's cliff. From the 4th hall on: as close as possible to your other halls, against the map's edge where it may be. The Crown computer expands to the same spots, and finds them about four times faster.",
	]},
	{"v": "0.30.3", "items": [
		"THE MAINSPRING'S COIL GAUGE (the owner): over every Mainspring a brass spring now shows the Tension it holds. Empty, the spring lies relaxed along its slot; as your Tension fills what your Mainsprings store, a plate presses in and the coils squeeze together, tight and bright when full. A Mainspring whose Clocktower's spring life is spent (FATIGUED) shows a dull, slack spring.",
		"BARS NO LONGER COVER THE BUILDINGS (the owner): every bar and label over a building now stands above its picture's real top, each in its own row: the health bar, then the building, training or crop bar, the coil gauge, the worker label (HAULERS, FARMERS, POWDER MAKERS, WINDERS), the UNLINKED badge and a gate's padlock. They used to lie across spires, chimneys, flags, windmill sails and the Clockwork buildings' tops. The gold spring mark moved just above the building, right of its bars.",
		"The same for the Brood's rooted creatures: the Rootmaw's food bar, ground bar and DRY label no longer sit on its back, a Sire's nest bar no longer covers his health bar, and the GROWING, ROOTING and RESEARCHING bars go on top, clear of the egg lines and labels.",
		"THE BROOD MOTHER'S EGG COUNT STAYS CLOSE ABOVE HER (the owner: at stage 2 it went far too high): it was placed at the highest her body reached while laying or swiping; now it sits just over her nest at stages 1, 2 and 3, stays put while she lays, and is centred over her.",
	]},
	{"v": "0.30.2", "items": [
		"SMOOTHER BIG GAMES AGAINST THE BROOD COMPUTER: late in a game with a big Brood, its computer thought for a tenth to a fifth of a second in one frame, two or three times a second (the owner's lag on Cinder Steps). Almost all of it was the search for fresh ground for its Rootmaws, where every spot was checked against every unit on the map. It now lists the units once and gets the same answers, about five times faster, and its thinking is spread over four frames in a row. In the owner's match replayed, the late game went from about 100 frames a minute over 50 ms to one or none.",
		"The Clockwork computer no longer freezes the game every few seconds in a crowded base: when it finds no room for its Heavy Works' big ring it looks again 20 seconds later (was 5; each search took up to a fifth of a second), and every computer that finds no free spot for a new hall waits 4 seconds before looking again.",
		"Units in big fights: paths are shared when several walkers ask the same way in the same moment, the turning-gear check is skipped far from the gears, the Brood's research speed is kept on each creature, and the silhouettes of units behind buildings are worked out faster. The game plays out exactly the same. New tools measure an army ladder (50 to 300 units) and check the cost at 200 units (docs/perf_armies.md).",
	]},
	{"v": "0.30.1", "items": [
		"MIXED REPLAYS (Settings > GAMEPLAY > REPLAY RECORDING > MIXED, now the default on phones and tablets): instead of pictures of every unit several times a second, the replay keeps every player's orders with their times, the computers' decisions (their units' new orders and their buildings' queues, twice a second), every death and one whole picture of the match every 10 seconds. Recording costs about a tenth of FULL (in a big battle about 1 ms per second of match instead of 10) and the file is a quarter to a third of the size.",
		"Watching a mixed replay runs the real game: it starts from the whole picture before the moment you pick and plays the match on from there with the recorded orders; every 10 seconds the next whole picture puts right whatever drifted (units glide back to where they really were). It is close to the match but not exact: in a big battle a unit is usually within a tile of where it really was. A jump on the timeline plays up to 10 seconds forward as fast as the device can. Replays recorded as pictures (FULL, LIGHT) play exactly as before.",
	]},
	{"v": "0.30.0", "items": [
		"A TUTORIAL BUTTON beside CAMPAIGN on the main menu (the owner: Tutorial is for learning the game, Campaign for people who know how to play and want the story). Seven short lessons, step by step: each step waits for you to do it, the teacher says one thing at a time in the dialogue box, the task stays on the LESSON panel, and a gold ring or arrow shows where to look (the map, the command card, the minimap, the group bar).",
		"THE BASICS (played with the Crown, the same for every faction): moving and zooming the view, selecting, moving and attacking, the command card and its keys, the minimap, control groups; computer and phone each get their own words.",
		"THE CROWN: the Farm and Labourers, the Powder Mill, soil and saltpetre running out, the Cottage, the Barracks and Musketeers, a wall and a gate on the ramp, the Foundry and a cannon, then holding the high ground against raiders. THE CLOCKWORK: Winders, the gear rings and the GEAR VIEW, a second Cog Press, the Mainspring and Tension, the Light Works and Clock Soldiers. THE BROOD: the Mother's eggs, food, a Mound Turtle on new ground with a Rootmaw on its swamp, the Tyrant Sire and Raptors.",
		"Each faction ends with a PRACTICE GAME against an Easy computer, with hints as you go. A finished lesson gets a tick on the list, and NEXT LESSON leads on. The main menu is now four buttons wide.",
	]},
	{"v": "0.29.16", "items": [
		"Fixed: a computer player's PLAN list in the lobby offered every faction's plans (the Springer timing for a Brood computer, say). It now shows only the plans of that player's faction, and a plan left over from another faction turns back to Balanced; a RANDOM faction gets only the shared plans.",
	]},
	{"v": "0.29.15", "items": [
		"NEW ANNOUNCERS, RECORDED: the Crown's is now a royal herald (\"To arms! The town is under attack!\", \"Victory! God save the King!\") and the Brood's is the campaign's scientist, a gentleman who admires the creatures (\"Good heavens, they are attacking the nest!\", \"Another splendid specimen.\"). Both are the owner's recordings, levelled to the Clockwork's announcer. They speak English in every language for now.",
		"The Brood's scientist has two lines of his own: \"The Mother! Someone protect the Mother!\" when your Brood Mother is attacked, and \"Oh dear. A Sire has fallen.\" when one of your fathers is killed. The Crown's herald now says \"Our men are out of powder!\" when your Musketeers or guns run dry.",
	]},
	{"v": "0.29.14", "items": [
		"A NEW PLAN FOR THE CROWN COMPUTER, BALLOON HARASS: the safe Musketeer opening with a Foundry, then two Observation Balloons carry Musketeers over cliffs and water to the enemy's workers (the Brood's grubs at its Rootmaws and the Mother's nest, the Clockwork's Winders at the Cog Presses and the Mainspring). Each balloon goes to a different place, hovers over the workers so the basket fires at them, and backs off from anti-air (Swifts, Springers, Ratchet Turrets, Skywings, the Storm and Venom fliers); with a little anti-air near it drops its men away from it and lifts them out when the defence comes. When a big attack comes at home the balloons come back and fire down on it from above. Pick BALLOON HARASS as a Crown computer's plan (the RANDOM PLAN may pick it too).",
		"In coached games on Hard the Balloon harass traded about 2.5 to 1 (Balanced 1.5 to 1 on the same games) and lived to 13:00 in all eight, at the price of a smaller economy (22 labourers at 8:00 against Balanced's 29); against the Clockwork it killed up to 36 Winders in a game. The numbers and the open questions are in docs/crown_builds_c.md.",
	]},
	{"v": "0.29.13", "items": [
		"The main menu painting shows the three faction colours: the Crown purple, the Clockwork red, the Brood green.",
	]},
	{"v": "0.29.12", "items": [
		"EACH FACTION HAS ITS OWN COLOUR: the Crown PURPLE, the Clockwork RED, the Brood GREEN. The menus, faction cards and buttons follow (the Crown was red and the Clockwork blue there).",
	]},
	{"v": "0.29.11", "items": [
		"A NEW CROWN COMPUTER PLAN, THE SIEGE PUSH (pick it in the PLAN list): Field Cannons and Mortars behind a line of Musketeers go out together to break a defended position, the Clockwork's turrets and the Winders that mend them, or the Brood's rooted creatures. The guns travel limbered behind the line, which stands on HOLD in a row in front of the target while the guns unlimber behind it, out of the defenders' reach. They shoot turrets first, then the workers mending, rooted creatures, enemy guns, the army (canister when it comes close, never through their own men). The Powder Wagon stays well behind the guns, and the push falls back, guns first, when it is losing or home is attacked.",
		"The Siege push builds its economy first (the second hall at 15 labourers, the safer Musketeer opening against the Brood), then the Horse Breeder and the Foundry; while a gun is wanted its gold is kept from everything else. In coached games against the Clockwork its push went out at 7:45-9:15 and it ended each game with more labourers than the Balanced plan; against the Brood one push broke three Mound Turtles and three Rootmaws for 50 lost.",
	]},
	{"v": "0.29.10", "items": [
		"THE CROWN WEARS PURPLE: the main menu painting is repainted with the Crown's army in royal purple and gold (it was blue), the Crown's new standard colour.",
	]},
	{"v": "0.29.9", "items": [
		"A NEW CROWN COMPUTER PLAN, DRAGOON RAIDS (pick it in the lobby, or a random plan may land on it): the safe Musketeer opening and the second hall, then Dragoons, Musketeers on horseback, ride out in groups of four to the enemy's workers: grubs at their Rootmaws, Winders at their presses, Labourers at their farms. They pick an expansion away from the enemy's army, ride round the side of its main, get off to shoot, and mount and ride off as soon as a real defender comes (a Tyrant Sire, a pack of Raptors, an army bigger than the group). The Musketeer line holds the main's high ground meanwhile. Against the Brood a group waits at home for the Brood's army to come out, then raids the grubs it left behind.",
	]},
	{"v": "0.29.8", "items": [
		"A NEW PLAN FOR THE CLOCKWORK COMPUTER, OWL RAIDS: a written opening build (the Light Works, the Mainspring on its big ring, the Escapement, two Clock Aviaries, TICKING OWL researched in one while the other makes Swifts), the first Ticking Owl at about 5:05, the economy growing behind it. Two Winders walk out with the Owls to a post near the enemy, out of sight, to wind them (an Owl runs down in about 80 seconds off its gear field), and the Owls strike its Farms, Mills, new Town Halls and workers from there, away from the anti-air seen, and fly back when it comes. A Swift scouts ahead. A real attack on the base calls the Owls home: Raptors, Horsemen and Clock Soldiers cannot hit them. Against the Brood it is the best Clockwork plan so far; against the Crown its Musketeers drive the Owls off. A computer on RANDOM PLAN can pick it.",
		"Fixed: the Clockwork computer could turn the Springer raid's scouting Swift into a Ticking Owl late in the game.",
	]},
	{"v": "0.29.7", "items": [
		"TWO NEW PLANS FOR THE CLOCKWORK COMPUTER, BUILT ROUND THE HEAVY WORKS. PENDULUMS, the answer to the Brood's Raptor swarms: two Clock Soldiers early, the Heavy Works as soon as the Escapement works, three Pendulums with the expansion behind them, then a slow push of Pendulums and Clock Soldiers, with Winders behind them, to the Brood's Rootmaws, its father and then its Mother. HEAVY WORKS PUSH: Clock Soldiers in front, Spring Ballistas behind them and the Great Winder behind those: a slow push that razes expansions from out of musket reach, breaks a wall in its way, waits short of the enemy's main until it is strong enough, and pulls back before it is wiped out. A computer on RANDOM PLAN picks the Pendulums half the time against the Brood.",
		"The Clockwork computer on these plans sends a Winder out to wind its machines that ran down at home.",
	]},
	{"v": "0.29.6", "items": [
		"A NEW PLAN FOR THE CLOCKWORK COMPUTER, THE CLOCK SOLDIER RUSH (a written opening): a Light Works at 6 supply and a second one soon after, six Clock Soldiers out at about 2:45 with two Winders behind them to wind and mend them, straight at the enemy's workers. A wall held by guns or menders is not charged: the soldiers back out of the muskets' reach, watch the foot of the enemy's ramp for a while (its expansion, the workers who come out), and then the computer turns to its economy (a turret, the Mainspring, a second Clocktower) with no trickle of soldiers. Pick it as a Clockwork computer's plan (RANDOM PLAN can pick it too). A second plan from the same work, the TURRET TURTLE, is not offered: static defence is not a build of its own (the owner). Its base layout and its turrets as an answer to a rush or to harass are to become rules for every Clockwork plan. The numbers, the films and what is still weak (the rush against the Brood) are in docs/clockwork_builds_a.md.",
	]},
	{"v": "0.29.5", "items": [
		"THE BROOD COMPUTER PLAYS TODAY'S ECONOMY: its six plans were timed on the economy of 0.22.5, and since far Rootmaws pay up to two and a half times more its eco plans earn about twice what those times were written for. From about 4:30 her clutch ran dry, food piled up (9,000 to 14,000 banked by the end) and Balanced, Timing and Economy never got their Venom Sire or her stage 3: a big bank made it stop keeping spoils for them. Now, once her eggs hold it back, her next stage, the next Sire and the next Mound Turtle on new ground (each makes her lay faster) come at once instead of at the plan's clock, the spoils for the Venom Sire and her stage 3 are always kept (Raptors are offered up for them), and spare food goes into maturing. On a peaceful Crown every eco plan now gets its Venom Sire by 6:12 to 6:39 and her stage 3 by 7:05 to 8:56.",
		"A BEATEN ENEMY IS FOUND: with nothing left that it has seen, a Brood wave used to walk between two empty places for minutes while one hidden building kept the enemy in the game. It now goes for any wall piece it has seen, else splits into packs of 8 that search the places it has not looked at lately, each pack on to the next place when it arrives, and gathers again on whatever it finds. Two games that ended in draws were won.",
		"THE SIRES STAY ON A LEASH: a Sire sent against a small raid now goes back to his nest once only riders are left, once he is 16 tiles from the Mother or after 30 seconds. A Tyrant Sire chasing Horsemen that kept out of his reach laid no Raptor for minutes while 4,000 food piled up.",
		"THE RUSHES ARE AN OPENING: the Rush and the Extreme rush call their first wave off when the scout saw an army twice its size, play Balanced once that wave is home (one that killed more than it lost kept making no grubs until 8:00) and expand at once; a Rootmaw no longer waits for 100 food in hand (they had 2 Rootmaws and 14 grubs until 8:30). After a rush it builds for two minutes before the next wave.",
		"WARRIORS WHEN THE ARMY IS SHORT: with too little army at home the Brood computer now holds its new Rootmaws and expansions until it has one, judges the enemy army also by what any player knows of the Crown's and the Clockwork's tempo (its scouts see little of an army gathering in its main), does not grow the Mother (no eggs for a minute) while an army twice its own was seen lately, and no longer sends a Mound Turtle out to the natural once the attack is already at home (one walked into 12 Clock Soldiers uprooted). Coached in 36 filmed games against the Hard Crown and Clockwork (docs/brood_ai_tune.md).",
	]},
	{"v": "0.29.4", "items": [
		"THE CROWN COMPUTER HOLDS THE CLIFF EDGE (the owner's playtest on Thornwood Maze, where its new Town Hall below the main fell while its Musketeers stood behind the ramp wall): when the enemy is at one of its buildings under the main's cliff, its Musketeers and guns move to the high ground's edge above it, within musket range, spread along it on HOLD, and shoot down; they never step down the ramp, and they walk back to the ramp when the threat is gone. Two to four labourers go to repair the building meanwhile; one a Raptor goes for runs to the cliff's foot under the line and comes back when it is clear. None are sent when the building would fall anyway.",
		"CANNONS FIRST AGAINST THE BROOD: once the Crown computer sees the Brood, its Foundry comes before its Horse Breeder and its first gun is a Field Cannon (its canister into the Raptors at the ramp or from the cliff edge); the rider scout comes after the cannon. And in every Crown plan, against anyone, the Foundry now comes before the second Barracks (the owner's rule: the cannon's canister also hits flyers and its round shot has the longest range in the game).",
		"THE CROWN'S OWN EXPANSION SPOTS: for the Crown the gold OPTIMAL EXPANSION SPOT marks now show its 2nd and 3rd halls at the least distance a hall allows (18 tiles), close together and right under the main's cliff, where Musketeers on the edge can shoot over the new hall and the walls can join up; from the 4th hall on, as close as possible to its other halls. They are worked out again whenever you place a hall. The Crown computer expands to the same spots. The Clockwork's marks stay as they were.",
	]},
	{"v": "0.29.3", "items": [
		"FEWER FREEZES: the long frames of a quarter to half a second came from the Crown computer drawing up the wall plan for a new Town Hall in one go (each time it expanded). That plan is now made about four times faster and is exactly the same plan. The Crown computer's first search for a hall spot (a 55 ms frame) is about four times faster too.",
		"NO MORE HITCHES WHEN A PICTURE IS FIRST SHOWN: each unit's pictures (its attack, death, rooting, laying...) were loaded the first time they were shown, a moment's freeze each, several at once in the first fight. They are now loaded in the background as soon as the kind is on the field (the ones standing at the start while the match loads), and the sounds too. On the web, one picture at a time when the game has a moment to spare.",
		"The tooltip under the mouse is built 4 times a second instead of 20 (it still follows the mouse). The match log now names the cause of every frame over 50 ms (a \"slow frame\" line), so the next freeze can be found. The game plays out exactly the same.",
	]},
	{"v": "0.29.2", "items": [
		"THE CLOCKWORK'S ATTACK ALARM IS GENTLER: one alarm for units and buildings alike, the alarm clock ringing twice briefly, a little lower and softer on the ear (it was one long ring, and another for the base). The owner's pick.",
	]},
	{"v": "0.29.1", "items": [
		"POWDER SMOKE: SHORTER, STAYS WHERE IT WAS FIRED, NO BLINK (the owner): every puff now lives about 3 seconds, solid for 2 and fading over the last 1 (it lingered 10 to 20 seconds, mostly too thin to see, and drifted far). The shot's push carries it less far. Its fade reaches nothing a moment before it goes, so it no longer blinks at the end, and a thick cloud no longer makes its puffs age in sudden jumps.",
	]},
	{"v": "0.29.0", "items": [
		"THE CROWN HAS A COMPUTER OF ITS OWN, like the Brood's: each plan (Economy, Balanced, Timing attack, Rush) now plays a real opening build order, step by step, each step waiting for so many labourers or so much supply, never for the clock. The plan keeps the gold for its next step: nothing else may spend it, and the labourers and soldiers get what is left. After the opening its milestones put up the second Barracks, the Breeder, the Foundry, the Armoury and the Church at so many labourers and halls. Everything that worked stays: the scout, the raids, the ramp post on HOLD, the rider scouts, the walls of a new hall, the counter-attack after a held rush.",
		"A rush scouted in the opening is now defended by the plan itself: the wall, the Barracks and the Mill first, soldiers before labourers, no new hall until the rush is held, then the hall at once. Against the Brood's extreme rush the third Musketeer comes at 2:38 instead of 2:45, and the economy no longer stalls at a dozen labourers for minutes.",
		"The Crown computer keeps its army together on the high ground: against the Brood its Musketeers go down to the expansion only with twice the force there (Musketeers in the open lose to a swarm their value says they beat), no guards walk out to a new hall site, no new hall goes down while the enemy is at the door, a wave goes only with an edge over the enemy army it knows, and the Powder Wagon waits by the hall while the army is at home (a wagon blown up among the Musketeers on HOLD at the ramp took the line with it).",
		"The Crown computer's Powder Mill crew now follows the powder: a hand goes back to the farms when powder piles up and one comes over when it runs short (six hands on the Mill had left the farms empty while 300 powder lay unspent), and after the opening its army grows with its economy: a hall trains a labourer only while every Barracks is busy, until the army is the plan's share of the labourers.",
	]},
	{"v": "0.28.5", "items": [
		"WINDERS SOUND LIKE WHAT THEY DO (the owner's two new recordings): a Winder winding a soldier, standing or on the march, makes the sound of a toy being wound; a Winder repairing a building works a ratchet wrench. Both used the building sound before.",
		"THE CLOCKWORK'S BUILDING KEYS FOLLOW THE CROWN'S (the owner: no far keys like L and H): each building takes the key of the Crown building with the same job, all near the number keys: Clocktower T (the Town Hall's), Regulator C (supply, the Cottage's), Cog Press F (the main resource, the Farm's), Mainspring W (the second resource, the Powder Mill's), Ratchet Turret A (defence, the Palisade's), Light Works B (the Barracks'), Heavy Works D (the Foundry's), Escapement Q (tech, the Armoury's), Clock Aviary R (the fast units, the Horse Breeder's). Keys you set yourself in INTERFACE LAYOUT & HOTKEYS still win.",
	]},
	{"v": "0.28.4", "items": [
		"THE SPRINGER HAS A REAL ATTACK SOUND: its shot was a tenth of a second of ratchet click, lost under the muskets. Now each shot is either a spring's twang and the clank of the screw flying, or a springy thwip with a lighter clank (the owner's two picks, from his Clockwork recordings).",
	]},
	{"v": "0.28.3", "items": [
		"THE BROOD MOTHER LAYS WHILE SHE GROWS: growing to her next stage no longer stops her laying. She lays on at half her speed until she is done, and the eggs she already holds can be used to hatch creatures as before (the owner: no eggs at all for 45 to 60 seconds was too harsh).",
	]},
	{"v": "0.28.2", "items": [
		"REPLAY RECORDING (Settings, GAMEPLAY): FULL records 5 pictures a second as before; LIGHT records 2, and the replay still glides each unit between them (in a battle of about 125 units the recording takes half the time and the file is about a third smaller; units are drawn on average about a pixel from where they really were); OFF records no replay of a skirmish, a campaign mission or a watched match. LIGHT is the default on phones and tablets, FULL on computers and in the browser. Online the host always records, at LIGHT when it is set to LIGHT or OFF, so each friend still gets the whole replay; the pictures sent to the friends during the match do not change. Replays keep their own rate, so old ones play as before.",
		"Replays show each shot, explosion and puff of smoke at the moment it happened, not all together with the next picture (new replays only).",
	]},
	{"v": "0.28.1", "items": [
		"A NEW PLAN FOR THE CLOCKWORK COMPUTER, THE SPRINGER TIMING (the owner's): a written opening build, step by step by supply like a StarCraft build order (a second Cog Press, the Light Works, a Mainspring on its big gear with six Winders, the Escapement, a second Works, HIGH LEAP, the Clock Aviary, four Springers, a Swift, four Clock Soldiers), the economy growing behind it (Winders keep coming, a second Clocktower at about 4:55). Four Springers, HIGH LEAP and the Swift are ready at 4:11 to 4:23. Then the Springers leap up onto the enemy's main where the Swift shows a landing spot away from its guns, shoot there, leap down to two Winders at the cliff foot who wind and mend them, and leap in again, while the Clock Soldiers stand at the foot of the enemy's ramp as a diversion. Pick SPRINGER TIMING as a Clockwork computer's plan (RANDOM PLAN can pick it too). Against the Hard Crown computer it is not strong yet: its Musketeers come within ten seconds of a leap and its workers run, so the raids so far kill little; the reasons and the owner's choices are in docs/clockwork_ai_rebuild.md.",
		"The Clockwork computer now has its own script, like the Brood's (scripts/ai_clockwork.gd): the first step of rebuilding it plan by plan. Its other plans play exactly as before.",
		"Fixed: the Crown computer wrote an error every moment it had a new Town Hall it found no wall plan for.",
	]},
	{"v": "0.28.0", "items": [
		"THE CAMPAIGN OPENS (its engine, with one short test mission): CAMPAIGN on the main menu leads to the HUB of a storyline, a scene (a placeholder picture for now) with places to click: the WAR TABLE to pick a mission, people to talk to (what they say changes after each mission) and an ARMOURY that is a placeholder for later. The same places are listed beside the scene, with big buttons for phones. Storylines open as the story goes: after the prologue, the Explorer's and the Clockmaker's stories (their missions are being written).",
		"THE FIRST MISSION, THE REVOLT AT THE FORD (a test: its story will be replaced): the year 2500, a village has risen against the Crown; lead the Crown's column over the ford and burn the rebels' Town Hall, keeping Captain Hale alive. A briefing with a still, lines of dialogue in the period's words in a box at the top right (NEXT and SKIP; nothing pauses), the objectives at the top left (ticked, crossed, the time left), a counter-attack, horse that comes to help, and an end screen that says where the story goes. SOLO against the computer, CO-OP (a friend online on your side, with the Crown's horse) and VERSUS (a friend online plays the rebels: the story follows whoever wins) from an online room the CAMPAIGN page opens.",
	]},
	{"v": "0.27.2", "items": [
		"THE CROWN COMPUTER FEEDS ITS ECONOMY FIRST: on Normal and up it now keeps the gold for its next labourer, its next Farm (once its farms are nearly manned, or a new hall has none) and its first Horseman before it pays for more buildings and, once its army has the minimum for the clock, more soldiers. On the Economy and Balanced plans its Barracks, Armoury, Foundry and Church wait while a Farm is due or the labourers are well short of the posts, and an enemy it could not scout no longer gets it three Barracks. Replaying the owner's Red Coast game it now has 26-29 labourers and 3 farms at 6:00 instead of 19-21 and 2, earns about a quarter more from minute 6 to 8, and gets its first Horseman about a minute after the Breeder instead of two (no spare horses bought before it); the Brood's Hard timing attack still wins there, but later.",
		"NO MORE PHANTOM THREATS: the Crown computer took an enemy it could not see standing by one of its buildings (the Brood's grub watching the foot of its ramp) for an army of 300, held the top of its ramp against it every 30 seconds for four minutes, ran its labourers up and put its expansion off. It now counts only enemies it sees (or saw a moment ago), or any enemy by a building that was just hit.",
		"THE CROWN'S SCOUT READS THE BROOD BETTER: a look that saw only the Brood Mother and a far Mound Turtle no longer counts as a greedy Brood with no army (the Crown switched to a timing attack and was hit a minute later); it now needs to have seen the Brood's economy (Rootmaws or grubs) and looked for its army, and the match log says what it saw (the Mother, turtles on new ground, Rootmaws, grubs, Sires, the army).",
		"The Crown computer's Musketeers no longer go off to hunt workers as a little band: a Crown soldier slower than a rider found far from home always walks back. An empty wall slot at a new hall is now logged as palisade planned for later, which is what it is (the gold is spent only when the economy is saturated and the army is not short), and no Farm or Mill is placed where a fight is going on.",
	]},
	{"v": "0.27.1", "items": [
		"THE SCREEN NO LONGER GETS LOCKED TO THE TOP LEFT: on computer controls the view scrolls when the mouse rests at an edge of the screen, and it did so even when no mouse had moved: on a touch screen (or before the mouse first moved) the game thinks the mouse sits at the very top-left corner, so the view slid to the top-left of the map every moment, however you moved it, while playing and while watching. Now only a mouse that has really moved over the game scrolls at an edge, and a finger on the screen turns that off. Also, when the mouse left the window by an edge and the browser never said it came back, the view kept scrolling that way: moving the mouse over the game now stops it. And the view never takes a broken position (a jump to nowhere is ignored).",
	]},
	{"v": "0.27.0", "items": [
		"THE SPECTATOR OVERHAUL: watching computers or a replay, three panels in the same style as VIEW, each opened and closed by its title and each with its own player list (All players or one player), independent of VIEW and of each other. PRODUCTION and ARMY & STRUCTURES stand down the right, the AI STORY down the left under the players' resources; they keep clear of the minimap, the bottom panels, the command card and a replay's bar, on a computer and on a phone. None of it exists in a match you play. The old PRODUCTION button beside VIEW is gone: its list is the PRODUCTION panel.",
		"ARMY & STRUCTURES: for each player its army value and supply, its resources with the painted icons (gold, powder and horses; biomass and spoils; cogs and tension), its units with their counts (the army first, then the workers) and its buildings with their counts; buildings going up are dimmer, with the bar of the one furthest along.",
		"THE AI STORY: each computer's plan at the start (its level, its strategy and what it means, the Crown's opening) and then its decisions with their reasons in short sentences, newest first: what its scout saw and the plan it chose from it, attacks and pull-backs, rushes held or failed, expansions, defence at the ramp or behind the wall, tech and research, walls, raids, its answer to a swarm, giving up. They are the computers' own match-log lines rewritten by a phrase book (scripts/ai_story_lines.gd, easy to extend), with repeats dropped, bursts of details limited and lines of one kind merged (×2); big decisions are bright, details dim. The mouse wheel or a tap pages back. Replays recorded from now on keep the story too.",
		"THE NARRATOR: the AI STORY's big decisions are read out loud with the system's text-to-speech voice in the game's language (Windows, Android and browsers that have one), one line at a time, never two at once; when lines pile up the older ones are dropped. The speaker on the AI STORY panel or the N key mutes it at once; Settings > SOUND has SPECTATOR NARRATOR, NARRATOR VOLUME and NARRATOR SPEED. Without a voice for the language the story stays text only and the panel says so. The match log also notes every attack wave now, not only the first.",
	]},
	{"v": "0.26.23", "items": [
		"THE PORTRAITS LOSE THEIR THIRD WING: the Hatchling's and the Storm Challenger's portraits (their cards and buttons) had a wing too many: the one raised at the upper left behind the head. It is gone, painted over with the portrait's own dark backdrop, and the body is outlined where it was. The wing at the bottom left is the creature's own and stays; on the Storm Challenger the red spines down its neck stay too.",
	]},
	{"v": "0.26.22", "items": [
		"THE CROWN COMPUTER HOLDS ITS RAMP: its army at home now stands on HOLD at the top of the main's ramp, Musketeers in a line across it behind the ramp wall (a lane left open in front of the gate) and its Field Cannon behind them, instead of waiting by the Town Hall. It goes down only to attack, or to meet a force at its expansion that it clearly beats; against more it holds the top, and the labourers below run up the ramp to it.",
		"The Crown computer scouts with Horsemen: one rider (two once it has four) rides a loop round the map's hall sites and the foot of the enemy's ramp, so it knows the enemy's army, halls and tech; when it finds workers it can take it turns to hunting them, and it rides home when hurt or chased by what can catch it. Its first Horseman is trained as soon as the Horse Breeder can give it a horse. The match log gives a scouting report.",
		"The Crown computer's new hall gets its slow wall against the Brood too: the wall now waits only while the enemy army seen on its side of the map (rooted Brood creatures count as buildings, not as an army) is bigger than the army at home, and once the economy is nearly saturated, not only when every last post is filled.",
		"After expanding the Crown computer goes down to fight when it is ready: when its army is worth clearly more than the enemy army it knows, when it is big and not behind, when the enemy is seen taking a third hall, or when it has not attacked for four minutes and is not behind. Never with less than 18 supply.",
	]},
	{"v": "0.26.21", "items": [
		"THE BARRACKS PLAYS THE BAND'S OWN ENDING (the owner's choice): the end of a slow piece from the fife-and-drum recording, as it was played, landing on the home note with a big drum stroke and two more strokes ringing away. The added fife notes of 0.26.19 are gone.",
	]},
	{"v": "0.26.20", "items": [
		"A BROOD SIDE TAKEN OVER BY THE COMPUTER PLAYS AS THE BROOD: online, when a Brood player left, the computer that took over their side was the one for the Crown and the Clockwork. The Brood has no buildings, so it stood looking for a hall to build and threw an error every tick. It is now the Brood's own computer, as in a skirmish.",
	]},
	{"v": "0.26.19", "items": [
		"FIFE AND DRUM END TOGETHER: the Barracks now recruits to the close of the band's slow tune (the owner's pick of the three): a held high chord, then three big drum strokes, and the fife now plays on with them, one note a stroke, D, C and home to B flat, the last held through the final stroke's ring so fife and drum stop together. The added notes are the same fifers in the same tune, not pitched up or down, and the fife is a little louder against the drums. Same loudness in a match; another version to compare is in docs/sounds_compare/flute/.",
	]},
	{"v": "0.26.18", "items": [
		"THE RIGHT WINGS THIS TIME: 0.26.14 erased the wrong wing in a few Storm line frames. In the south-east wing beat of the Hatchlings and the Storm Challenger, the downstroke now keeps both wings swept down and loses the stray wing raised at the top left instead. The Hatchling and Storm Challenger portraits, the Hatchlings' deaths and the Storm Sire's south-east dive are back as they were drawn.",
	]},
	{"v": "0.26.17", "items": [
		"NEW LABOURER WALKS, SOUTH AND SOUTH-EAST: the Labourer walking toward the camera and down to the right is a new drawing with a real stride, in the same style as his east walk, instead of the east walk's legs squeezed under him. The south walk now steps on alternate feet, and the south-east walk's last frame no longer shows a tangled back leg. The new legs also go under the Labourer carrying gold, a powder keg or a loaded shovel, and under the Musketeer and Guardsman walking south and south-east.",
	]},
	{"v": "0.26.16", "items": [
		"SMOOTHER BIG BATTLES (a first pass at the units' own work): what each army sees is worked out in one pass over all its men instead of man by man (the fog's update, 4 times a second, 15 to 45% lighter on average, with smaller spikes); the command card of a big selected army is rebuilt on a frame without a game tick, so it no longer adds to a tick's frame; the units' pictures skip work that changed nothing (a sprite set to what it already showed). The units' own tick is about as heavy as before: the next big savings would change how they move and fight a little, and are the owner's call. The game plays out exactly the same: whole-state traces of every test battle and of computer matches are identical before and after.",
	]},
	{"v": "0.26.15", "items": [
		"THE BARRACKS RECRUITS TO REAL FIFE AND DRUMS: its call is no longer put together note by note with an added echo and drum tap. It is now a piece of a real fife-and-drum band recording, as it was played: the fifes over a rolling snare climb to a held F and walk down F, E flat, D onto the home note B flat, which the drum marks, and the band stops there. Nothing added, no echo. Two other places in the recording to compare are in docs/sounds_compare/flute/.",
	]},
	{"v": "0.26.14", "items": [
		"NO MORE THIRD WINGS ON THE STORM LINE: a few of the painted frames had a hallucinated extra wing. The Hatchlings' south-east wing beat and five of their deaths, the Storm Challenger's south-east wing beat, the Storm Sire's south-east dive and the Hatchling and Storm Challenger portraits now show two wings. Nothing else changes: the same timing, and each body stays where it was.",
	]},
	{"v": "0.26.13", "items": [
		"THE CROWN COMPUTER USES A HELD RUSH: once it has beaten off a rush (no armed enemy near its buildings for 10 s, its army worth at least what the enemy showed), it picks one move at once instead of sitting in its defensive build for minutes: a counter-attack with its whole army when it is worth half again the enemy's and has 12 supply or more, or else its second Town Hall right away (the gold held for it, the army at home covering it). Either way the defensive build ends: labourers and tech come back. The match log says which it chose and why.",
		"No more trickle attacks from the Crown computer's Timing plan: when its scout has not sized the attack, the first wave waits for 16 supply (or 1.6 times the enemy army seen) instead of going out with 3 Musketeers.",
		"The Crown computer's new-hall walls give way to its army: while the enemy army it has seen is bigger than its own, the palisade there is laid only from gold above two Musketeers' price, a few pieces at a time. A full wave no longer waits for two thirds of the army guarding a half-walled hall: two stay, the rest go.",
		"REPAIR FIRST: while the Crown computer's ramp wall or gate is being hit, it keeps 80 gold back from labourers, buildings and soldiers for mending it. On Ashfall against a Brood rush the gate now holds and no labourers are lost (3 before).",
		"THE CROWN COMPUTER PLAYS THE OWNER'S WAY: it keeps training labourers (an enemy it could not scout no longer holds them back, and hands are trained ahead for a hall going up), expands as soon as its main is full instead of waiting for the soil to run low, keeps its army on the main's high ground instead of sending two thirds to stand by the new hall, and walls the new hall only once its economy is saturated, a few pieces at a time. On Kestrel Rise and Mirewood against the Brood economy it had about 38 labourers at 8:00 (21 before) and twice the army.",
		"Workers and army before walls: the Crown computer lays no palisade at a new hall while its army is smaller than the enemy's or than its minimum for the time of the game (one log: its expansion wall cost about 1,080 gold, its whole army 470).",
	]},
	{"v": "0.26.12", "items": [
		"PAINTED RESOURCE ICONS (the owner's ChatGPT pictures): the top bar shows a picture for each resource instead of a coloured dot: gold coins and a powder keg for the Crown (and a horse's head by the horses), meat and leaves for the Brood's food and a bone-and-claw bundle for its spoils, three brass gears for the Clockwork's cogs; the supply pill shows the supply icon. The resource chips on a building's card use them too: a Farm's soil (a clod with a sprout), a Powder Mill's saltpetre (white crystals), a Cog Press's brass (two ingots), a Rootmaw's food and ground, and a Mainspring's spring life (the Tension spring).",
		"THE PISTOL MARK on a Horseman's, Cuirassier's or Officer's card is a painted flintlock: a spark at the pan when loaded, smoke from the muzzle once fired.",
	]},
	{"v": "0.26.11", "items": [
		"NO MORE STANDING AT A HALF-BUILT WALL: soldiers on an attack-move no longer stop to hack or shoot at an enemy palisade they can walk round (only when the place they were sent to is walled off do they break a piece); after killing a man on the way they go on to where they were sent instead of stopping there; standing idle they only hit a wall piece already in reach, rather than walking up to one. A piece still going up can be broken when it is what shuts them out, and a soldier that makes no headway for 3 seconds (a crowd jostling at a wall) looks for a fresh way. (A playtest: five Musketeers stood at the computer's half-built diagonal wall for good though its end was open.)",
	]},
	{"v": "0.26.10", "items": [
		"THE BARRACKS' FIFE ENDS LIKE A TUNE: the fife's little call when the Barracks recruits no longer stops on a note that sounds like a question. It now steps down home, D, C, then the home note B flat, held and dying away, with one drum stroke on it.",
		"THE RAPTOR'S OLD BITE IS BACK (the owner's choice): the quick swish and snap the Raptor had before 0.24.6. The other Brood creatures keep their bites.",
	]},
	{"v": "0.26.9", "items": [
		"POWDER SMOKE WITHOUT CUT EDGES OR BLINKING: the painted smoke of every shot (and of the chimneys) had straight, cut-off sides; it is soft all round now. Each shot's quick puff fades out smoothly instead of dimming in one step and then vanishing. The lingering haze glides smoothly instead of moving in small jumps 20 times a second, no longer pops in at the screen's edge or after the camera jumps (a minimap tap), and a puff at the edge of your sight no longer blinks as your men's sight flickers. It lingers as long as before.",
		"LESS LAG IN BIG BATTLES: the powder haze draws about a fifth fewer pixels, the work a phone's graphics chip pays for (rounder puffs, and fewer puffs piled on one spot, which looked the same), and its own work each tick is about a quarter lighter, and the panel of a selected army is redrawn 10 times a second instead of 20 (with an army selected it was the interface's biggest cost). The game plays out exactly as before.",
	]},
	{"v": "0.26.8", "items": [
		"THE BARRACKS' FIFE ENDS CLEANLY: when the Barracks recruits a soldier, the fife's last long note no longer stutters (it was one short piece of the recording repeated five times, with the band's drum in it) and no longer stops short. It is now a real held note from the fifer, fading out smoothly, and the low drum thump and hum under the tune are gone.",
	]},
	{"v": "0.26.7", "items": [
		"THE COMPUTER'S HORSEMEN STAY AND RAID (the owner's playtest): a Tyrant Sire, the Brood Mother or a Rootmaw on foot can't catch a Horseman, so the Crown's raid no longer rides home from one. The riders keep out of its bite, ride round it to the grubs it can't reach in time and cut them down, their loaded pistols for the grubs, not the Sire. They still ride home from what can catch or shoot them (Raptors in numbers, Spitters, more than the party) or when badly hurt, and a Crown behind in economy raids longer. A lone Musketeer that chased something far out now comes home instead of harassing alone.",
		"THE BROOD AGAINST HORSEMEN: the Brood's computer no longer sends its Tyrant Sire after fast riders (he never catches them). Grubs a rider is at gang up on him when they are enough to win, else run to the warriors, a turtle or the Mother, and go back to work when he is gone. With riders about it grows the Venom Sire at once and lays a Spitter for every Raptor.",
		"THE BROOD'S COMPUTER KEEPS GROWING AND SPENDING: with no room left round the Mother it roots Mound Turtles for supply anywhere on or beside its swamp (on a cramped map it sat at 76 supply for six minutes with thousands of food). At its supply cap with a big bank it attacks, and a wave that razed its target goes on to the next enemy building it knows (the weakest enemy in a free-for-all) instead of standing on the ruins. A Rootmaw that gets up to fight keeps its spot: no new Rootmaw is planned there while it is away.",
	]},
	{"v": "0.26.6", "items": [
		"THE CLOCKWORK COMPUTER AGAINST A SWARM: once it has seen a mass of Raptors (10 or more light melee creatures among the fighters it saw lately, at least half of them), it builds the Heavy Works and its Pendulums first (whose blades cut every enemy in the arc), before Ballistas, the Great Winder or more Springers, two to six of them; it adds a Ratchet Turret at home; it does not expand or send a new wave into a swarm clearly bigger than its army until two Pendulums are out. Against the Brood it makes two Pendulums as soon as the Heavy Works stands, swarm seen or not, and against a swarm it saves for its tech and the Heavy Works even under attack, before a new hall.",
		"THE CLOCKWORK COMPUTER FINDS ROOM FOR ITS HEAVY WORKS: since Tension flows through the whole gear network (0.25.0) the Heavy Works need not stand beside a Mainspring, and the computer now takes any spot a Mainspring feeds, and keeps room for its big ring as soon as its Mainspring stands, so its Regulators do not take it. (A main too cramped for it waits for a new hall's field, as before.)",
		"THE CLOCKWORK COMPUTER'S WINDERS STAY WITH ITS WAVE: the Winders that go with an attack follow the wave itself (not the middle of the whole army), no longer run home from the fight like raided workers, and walk home with the wave when it pulls back.",
		"FIX: a computer's rush is no longer called a success because the soldiers sent after it were not counted, nor 'finished' when it saw only one worker and no army (the Brood's grubs sit unseen behind its rooted creatures).",
	]},
	{"v": "0.26.5", "items": [
		"+ WORKER AND - WORKER ON A FARM, POWDER MILL OR OTHER CREWED BUILDING (the owner's playtest: on a phone there was no way to move workers from the farms to a Powder Mill): select the building and press + WORKER: one more worker comes to work it, an idle one first, else the nearest one taken from the least important job (a Farm before a Powder Mill, haulers last). - WORKER sends one of its workers to another job with room. The same buttons are on the computer's card. On a phone you can also select workers (a tap on a FARMERS label selects that farm's) and tap one of your Farms or Mills: they go to work it.",
		"EVERY HORSE BREEDER BREEDS: with several Barracks training Horsemen, the horses they need are shared between all your Horse Breeders (the one with the fewest horses queued takes the next) instead of all going to the nearest one while the others stood idle. A breeder with nothing to do also takes over a horse still waiting in another breeder's queue. The computer's breeders do the same.",
	]},
	{"v": "0.26.4", "items": [
		"SCATTER COGS, THE GREAT WINDER'S SLOW FIELD (the owner's idea: a slow spell without magic): press SCATTER COGS (C) and tap a spot within 6 tiles. Its key arm winds up for half a second, then its hopper flings a shower of cogs, bolts and springs that litter a circle of 2.5 tiles for 15 s. Enemies on the ground in the litter move 40% slower (their attacks are not slowed); flyers and your own units are not slowed. It costs 40 cogs and the hopper refills in 25 s. The Clockwork computer throws it on clumps of charging melee (Raptors, Horsemen) and on armies running away.",
	]},
	{"v": "0.26.3", "items": [
		"RAIDING HORSEMEN AT THE NEW RAMP WALL (Cottage and Gate): the computer's raid strikes the ramp Cottage as well as the gate, so the riders spread over both instead of queueing at a one-tile gate. A labourer mending the gate from the riders' side is ridden down first rather than counted as endless repair, and a worker coming into sight on the near side no longer makes the raid give up on a gate it could break.",
	]},
	{"v": "0.26.2", "items": [
		"THE BROOD COMPUTER DEFENDS AS A SWARM: its army at home gathers at a rally and holds there, so Raptors no longer run off one by one at every enemy they see. Enemies at home get a group sized to them, sent all at once: a few Raptors, or the Tyrant Sire for a small harass when there are no warriors to spare, the whole army for a real attack, and everything near the Mother when the fight is at her. An attack too strong to meet away from her makes the army gather on her side instead. The Mother stays rooted for a scout or a small harass (her swamp and the Rootmaws on it stay) and gets up only for a real attack, when hurt with nobody fighting for her, or as a last stand. A rooted Rootmaw that is struck gets up and bites back when it can win, or backs off to the Mother when it can't, then roots again on its spot.",
	]},
	{"v": "0.26.1", "items": [
		"HORSEMEN BREAK A SHUT GATE: the computer's Horsemen out raiding no longer gallop into a shut enemy gate and stand pressed against it. When a wall is between them and the workers, the party weighs it up: if it can bring a piece down in time and nothing shoots them hard there, every rider sets about the gate or the palisade beside it, spread over the pieces (two to a face), and a rider with his pistol loaded shoots a labourer mending it that he can see. If the piece won't go down (menders hidden behind it on the high ground, or muskets on the wall), they ride off after workers they can reach, or home, and come again later. A Horseman riding at prey behind a wall breaks the piece in the way instead of pushing at it.",
	]},
	{"v": "0.26.0", "items": [
		"WINDERS WIND THE ARMY ON THE MARCH (the owner's idea): a Winder now winds a Clockwork soldier that is walking, walking just behind it at its pace and cranking as he goes (his new winding-while-walking animation), until it is full; then he goes to the next one, and once none needs it, back to his own move. Its charge fills at the usual rate and the soldier is never slowed (a Winder is faster than a Clock Soldier). Right-click (REPAIR) a walking soldier to do it by hand; with automatic repair on (the default), Winders moving with the army (move, attack-move or follow) do it by themselves for the walking soldiers near them under 80% charge, lowest first, two Winders never on the same one. A marching army with Winders now arrives wound instead of run down. The computer's Winders do the same. A soldier being wound says Winding up on its card.",
		"A box over your army keeps the Winders that are winding soldiers in the selection.",
	]},
	{"v": "0.25.28", "items": [
		"THE CROWN COMPUTER'S RAMP WALL HAS NO USELESS PALISADE: it lays only the pieces that close a gap. A high-ground cell that only touches the ramp's corner, with the cliff on one side and the Cottage (or another piece) on the other, can't be walked into, so it no longer gets a palisade; on Ashfall the wall is now just the Cottage and the Gate. The same goes for the palisade line on any other ramp up to the main.",
	]},
	{"v": "0.25.27", "items": [
		"GEAR VIEW COLOURS (Clockwork): each step has its own colour, so a ring at 70% no longer looks stopped: green 100%, lime 90%, yellow 80%, orange 70%, and red only for a ring that is stopped (unlinked or idle).",
	]},
	{"v": "0.25.26", "items": [
		"THE ANDROID APP'S NEW-VERSION BOX speaks to a phone: when a newer version is out, the main menu says to download it and install it over this app (the Windows program still says to replace its copy).",
	]},
	{"v": "0.25.25", "items": [
		"PALISADE ON THE DIAGONAL, AND BENT WALLS: press where a wall (or a row of gates) starts and drag to where it ends, or click both ends as before. The line runs along a row, a column or an exact diagonal, whichever is nearest the mouse; a diagonal is one piece per cell, corner to corner, with the diagonal palisade art (no more staircase: 5 pieces for 4 cells across instead of 9). The ghost shows every piece and what they cost. On a computer, hold Shift and click to make a corner and draw on from there (straight, then diagonal...); let go of Shift to lay the whole path (queued, as every Shift order), or finish with a plain click. On a phone the end snaps the same way; a bend is two walls.",
	]},
	{"v": "0.25.24", "items": [
		"DIAGONAL PALISADE: palisade pieces that touch only at their corners now join along the diagonal, with stakes drawn corner to corner, so a diagonal wall no longer looks full of holes (new art from the owner's drawing). A piece that joins a straight run and a diagonal one shows both. Nobody walks or squeezes through the corner between two diagonal pieces (as before), and gates in a diagonal line still let their own side through.",
	]},
	{"v": "0.25.23", "items": [
		"THE CROWN COMPUTER'S EXPANSION WALL WRAPS ROUND ITS RAMP: when it expands below its main's ramp, the wall no longer plugs the foot of the ramp. It goes round the ramp's foot and the new base together, on the far side, so the main and the expansion are one walled space; the ramp comes down inside, and the gate faces out toward the enemy.",
	]},
	{"v": "0.25.22", "items": [
		"THE PALISADE IS WEAKER, TO MATCH ITS LOWER PRICE: 200 health a piece (was 300), armour 2 as before.",
	]},
	{"v": "0.25.21", "items": [
		"THE PALISADE IS CHEAPER: 15 gold a piece (was 25). Walling a base (yours or the computer's, which now walls its expansions) costs about 40% less; the buildings that stand in a wall cost nothing extra, as they would be built anyway.",
	]},
	{"v": "0.25.20", "items": [
		"THE CROWN COMPUTER WALLS IN ITS EXPANSIONS (Normal and Hard): every new Town Hall gets a wall across its ways in, the ground an enemy walks in by. Its own buildings make the wall first: Barracks, Cottages, a Church (and later Foundries, Horse Breeders) are placed in the gaps, palisade fills what is left, and a gate faces the way to its main. The first palisade is laid as the hall goes up; the Farms and the Powder Mill go inside the wall, and part of the army stays at the new hall until the wall is mostly up.",
	]},
	{"v": "0.25.19", "items": [
		"EVERY FULL BAR IS HIDDEN: health shows only on a hurt unit or building (no longer on a selected one at full health), and the charge and powder bars only when not full. Settings, DISPLAY, HEALTH BARS: ONLY WHEN NOT FULL (the default) or ALWAYS (every bar, full or not).",
	]},
	{"v": "0.25.18", "items": [
		"THE BROOD MOTHER'S RALLY POINTS ARE LABELLED: WORKERS under the gold point (her grubs) and ARMY under the green flag (her warriors).",
	]},
	{"v": "0.25.17", "items": [
		"SACRIFICE ON EGGS: select eggs and press SACRIFICE (C): as they hatch, their young go straight to the Brood Mother to be devoured, with no rally on the way. The button shows the spoils the eggs' young will give.",
	]},
	{"v": "0.25.16", "items": [
		"THE MISSIONARY CAN BE KILLED AWAY FROM HIS CHURCH: he is untouchable only within 20 tiles of one of your Churches (and never near enemy buildings, as before). Before, he could not be hurt anywhere except near enemy buildings, so he strolled untouched through a Brood base, which has none.",
	]},
	{"v": "0.25.15", "items": [
		"A rooted Mound Turtle is drawn in the middle of its 3x3 ground, no longer sitting in its bottom row.",
	]},
	{"v": "0.25.14", "items": [
		"THE BROOD MOTHER'S GRUB IS S, StarCraft's worker key: on her card alone (rooted or uprooted, with any research) GRUB is S and STOP is G. A selection mixing her with other creatures is an army card: STOP keeps S there.",
		"SETTINGS IN A MATCH: the match MENU has a SETTINGS button that opens the same Settings page as the main menu (GAMEPLAY, DISPLAY, SOUND, EXPERIMENTAL, OTHER) over the match: change the hotkeys and layout, the command keys, the interface size, the health and charge bars, the expansion spots, the powder smoke, full screen or the volumes, and they apply in the match. A single-player match is paused meanwhile; online the match keeps running. What only a new match picks up (the experiments, PLAYING ON) is dimmed with \"(next match)\"; RESET SETTINGS, the animation viewer and the patch notes stay in the main menu. BACK or Esc returns to the match MENU.",
	]},
	{"v": "0.25.13", "items": [
		"ARMIES BUNCH UP LESS: soldiers of one side keep about a quarter more room between them, standing and on the move (a group of 30 Musketeers stands about 20 px apart instead of 17, Raptors 15 instead of 12), so a fight is easier to see and to micro and a blast catches fewer of them. No formations: a group sent somewhere still heads for about the same place as before and spreads out by pushing apart, a little more than before. In a gap, a gate or on a ramp, men who are stuck close up to the old spacing, so a crowd still goes through. Their bodies are not bigger: clicks, hits, paths, ramps and gates are as before. Enemies still close right in, so melee units reach their prey as before; workers keep the old spacing at mines, farms and yards.",
	]},
	{"v": "0.25.12", "items": [
		"THE BROOD'S PLANNED ROOTS STAY ON THE GROUND: every Rootmaw, Mound Turtle or lure your grubs are on their way to, or have queued with Shift, is drawn as a faint ghost of its footprint and picture until it roots, so you can plan several at once (as the Crown's and Clockwork's building sites stay drawn).",
	]},
	{"v": "0.25.11", "items": [
		"ORDERS ON THE MINIMAP: PATROL (and every other order waiting for a point: rally points, ATTACK GROUND, spells) can be given by clicking the minimap, with Shift to queue it, as MOVE and ATTACK could; it used to move the view instead.",
	]},
	{"v": "0.25.10", "items": [
		"F2 (ARMY) PRESSED TWICE: the camera goes to where most of your army stands (its biggest clump), as a group's number does when pressed twice. F3 (MAKE) twice goes to your production buildings.",
	]},
	{"v": "0.25.9", "items": [
		"HARVEST AUTOCAST REACHES FARTHER: a grub with automatic harvest on goes to any body its side can see (up to 60 tiles), not only those within 10 tiles of it; the nearest first. A HARVEST order given by hand still takes the bodies near it.",
	]},
	{"v": "0.25.8", "items": [
		"THE FACTION FRAMES SIT ROUND THE PANEL, NOT OVER IT: the unit panel's and the command card's frames are drawn thinner and a little outside them, so the Brood's rope (and the Crown's and Clockwork's corner ornaments) no longer run over the portrait, the stats row or the icons.",
	]},
	{"v": "0.25.7", "items": [
		"RAMPS: the stone kerbs down a ramp's sides run parallel, the same width from top to bottom; the rock wedge that narrowed down the slope drew them as a funnel.",
	]},
	{"v": "0.25.6", "items": [
		"FIX: the main menu's buttons in Portuguese and Spanish: a longer word (ESCARAMUÇA, CONFIGURAÇÕES) grew its button over its neighbour. The text now shrinks to fit its button (it was measured in English before), and a button never grows past its place.",
	]},
	{"v": "0.25.5", "items": [
		"THE ROOTMAW'S CIRCLE, A LITTLE SMALLER: 8 tiles round it (was 10), so Rootmaws stand 16 tiles apart: about two fit at the Brood Mother's base. The 10-tile circle was too harsh on the Brood's economy; each Rootmaw still holds 3,000 food.",
	]},
	{"v": "0.25.4", "items": [
		"THINNER BARS, IN BOXES (StarCraft 2 style): the health bar over units and buildings is thinner (3 px, a building's 4) with a thin dark outline, and cut into BOXES: 25 health a box up to 300 health, 50 up to 800, 100 up to 2,000, 250 above (bigger boxes when they would be too narrow to read). The bars are a little narrower too. The reload, charge (wind) and powder bars are 2 px, flush under the health bar, shown only when not full, never more than two.",
		"HEALTH BARS setting (Settings, DISPLAY): DAMAGED OR SELECTED (the default: a bar over a hurt or selected unit or building) or ALWAYS.",
		"WILL CONNECT: while you place a Clockwork building, every building whose ring would mesh with the ghost's ring is outlined with a link line to it, and an OFF (unlinked) building that the new one would bring onto the gear field glows teal, with its link line and a WILL CONNECT mark over it (off buildings meshing in a chain behind it too).",
		"SILHOUETTES ONLY WHEN REALLY HIDDEN: a unit is drawn as a silhouette only when it stands behind a building or a big creature AND that picture's solid pixels really lie over it (not its empty corners, not the gear rings or floor plates on the ground), and only the covered part of the unit is drawn as a silhouette. Winders working at a Cog Press no longer show one.",
	]},
	{"v": "0.25.3", "items": [
		"ONLINE: A GUEST'S MATURED UNITS COME OUT OF THEIR COCOONS: a Raptor maturing into a Tyrant Challenger (and every other moult) stayed a grey shell on the guest's screen for good once the host finished it, so the guest was commanding cocoons. Now the shell splits, the Challenger steps out with its own art and the empty shell and skin are left behind, as on the host. A Swift turning into a Ticking Owl shows its puff of smoke too.",
		"ONLINE: THE GUEST SEES THE ANIMATIONS THE HOST'S GAME PLAYS: the Mist Toad hops (it slid along crouched), a Springer's jump plays its crouch, arc and landing (it glided), and the moult, a Swift's morph, rooting and uprooting, a cocoon, an egg hatching and the Brood Mother laying run smoothly between the host's updates instead of stuttering over a slow line, with their sounds.",
		"ROOTMAW GROUND, FAIRER: a new Rootmaw's ground loses what was drunk from each old, spent circle it overlaps, by how much of that circle it covers. Before, it took the LEAST of every circle it touched, so a fresh spot just inside a spent circle's edge had 0 food. Rooting on (or right beside) spent ground still gives almost nothing. The ROOT ghost says \"Ground spent: 0 food\" in red on spent ground, and the computer only roots where at least a third of a full ground is left. (Online, the guest's ghost reads the host's ground since 0.25.1; in 0.24.34 every guest's Rootmaw showed 0% and every ghost 3,000.)",
	]},
	{"v": "0.25.2", "items": [
		"A new Clocktower icon (the owner's ChatGPT drawing): the brass tower with its clock face, red pennant and gear, readable at a glance, in place of the shrunken building picture.",
	]},
	{"v": "0.25.1", "items": [
		"ONLINE: THE HOST'S BUILDINGS NO LONGER VANISH ON THE GUEST'S SCREEN: the guest's copy of the match was dropping the host's planned sites as \"nobody was coming to start it\", because it can't see the host's Winder out of sight nor anyone's Shift queue (one match logged 108 of them). Only the host decides now; its sites stay and get built. A freshly placed site also waits a moment before it can be dropped.",
		"ONLINE: THE ROOTMAWS' GROUND REACHES THE GUEST: a Brood guest saw every Rootmaw's ground as 0% (cards, tooltips, labels and the match log). It is sent with the match now, when it changes.",
		"ONLINE: MORE ORDERS WORK FOR A GUEST: the Brood Mother's WORKER / ARMY rally keys, taking a research off the queue, a Field Cannon's CANISTER / ROUND SHOT and a gate's ROTATE. (The first was refused with \"That order can't be given online yet.\")",
		"LIGHTER DRAWING FOR THE BROOD: with the Brood Mother or a father selected, the father's range no longer redraws the map's overlay every frame, only when it changes or she walks (an online guest spent a third of each frame on it); the hover ring over a rooted creature doesn't either.",
	]},
	{"v": "0.25.0", "items": [
		"TENSION FLOWS THROUGH THE WHOLE GEAR NETWORK (Clockwork): a building that uses or spends Tension (the Escapement, the Clock Aviary, the Heavy Works, a Light Works for its Springers and Netters) no longer has to mesh right beside a Mainspring. It is fed when a Mainspring stands anywhere in its gear network, through any chain of meshed rings, so the Mainspring can stand anywhere in your town and nothing has to be demolished to move it. Two Clocktowers whose networks touch share their Mainsprings. Still 1 Mainspring per Clocktower, with its Winders, spring life and 5% floor; a fatigued Mainspring still feeds its network, a destroyed one feeds nothing. The ghost says TENSION FED or NEEDS MAINSPRING, the spring mark reads 'Fed by a Mainspring through the gear network', and the help and descriptions say so.",
	]},
	{"v": "0.24.34", "items": [
		"GROUP KEYS AS IN STARCRAFT 2: Shift+number ADDS the selection to that group; Alt+number sets the group and takes those units out of every other group (Shift+Alt+number adds them and takes them out); Ctrl+number sets it, the number selects it, as before. The group buttons take the same modifiers on a click. (Shift+number used to add the group to the selection.)",
	]},
	{"v": "0.24.33", "items": [
		"SETTINGS IN TABS: the Settings page is split into GAMEPLAY (language, device, command keys or one-finger drag, layout and hotkeys, tooltips, build grid, replays kept, online relay), DISPLAY (full screen, interface size, minimap solidity, powder smoke, area marks, expansion spots, charge bars), SOUND, EXPERIMENTAL (turning gears, marching band, Clockwork lab) and OTHER (patch notes, animation viewer, reset settings). The tab you pick stays picked until you close the game.",
		"FULL SCREEN ON A COMPUTER: a FULL SCREEN switch in Settings > DISPLAY; the Windows program also switches with F11 or Alt+Enter and starts the way you left it. In a browser the switch works from the click (F11 still works too).",
		"SMALL MUTE BUTTONS: music, sound and ambience each have a small speaker button beside their volume bar instead of the big ON / OFF buttons; the match menu's volume bars have one too.",
		"RESET SETTINGS (Settings > OTHER, press twice): every choice back to how it starts, except the language, the device, the sound and the online relay.",
	]},
	{"v": "0.24.32", "items": [
		"A NEW VERSION BOX: the Windows program and the Android app check the site once a run; when a newer version is out, the main menu says so, with DOWNLOAD (opens the new file in your browser) and LATER. The browser version is always the newest, so it never asks.",
		"The Windows program is on the site: https://holdfastrts.github.io/Holdfast/Holdfast_windows.zip (rebuilt on every update, like the Android app).",
		"The Android app may now use the internet (for this check and for online play).",
	]},
	{"v": "0.24.31", "items": [
		"THE CROWN'S RAIDERS DON'T WAIT AT A ROOTMAW: Horsemen raiding the Brood who have killed every grub in sight no longer stand hitting the rooted Rootmaw or Mound Turtle the grubs worked at; they wait beside it for the next grub (they still fight any armed creature that comes).",
	]},
	{"v": "0.24.30", "items": [
		"Developer tests only: the selection panel, command key and HUD frame tests now play as on a computer whatever the saved settings say (a settings file without a device made them run as on a phone). Nothing changes in the game.",
	]},
	{"v": "0.24.29", "items": [
		"BODIES UNDER A ROOTING CREATURE ARE PUSHED OUT: when a Rootmaw, a Mound Turtle, a Sire on his nest or the Mother roots (or the Mother grows) over bodies or a food pile, they are moved to the nearest free ground just outside its footprint, so your grubs can still harvest them; a body keeps its value and its rot, a pile its food. The same when any building is put down over a body.",
		"GRUBS FIND THE MOTHER THROUGH HER SIRES: with Sires and other creatures rooted close round her, grubs coming from a far Rootmaw no longer get stuck against one of them; they walk in through any open gap. (A grub stuck beside a rooted creature used to be sent on a straight detour round its body, which often ended inside its footprint or a neighbour's, again and again, instead of finding a new path.) If her rim can't be reached at all, a grub delivers from the nearest spot it can reach beside her.",
	]},
	{"v": "0.24.28", "items": [
		"A FAR ROOTMAW PAYS MORE AND FASTER (Brood): the food of a Rootmaw rises with its distance from the Brood Mother, now up to two and a half times as rich at 24 tiles or more (was +30% at 18). It counts twice: each grub's trip pays more AND the Rootmaw drinks its ground that much faster (before, every Rootmaw drank 4 a second wherever it was, so the distance hardly paid). Its 3,000 food stay the same: a Rootmaw at 23 tiles pays about 560 food a minute and is spent in about 5 and a half minutes, one at 31 tiles about 650 a minute, the Mother's own near one about 230 a minute as before. A far Rootmaw takes one more grub every 3 tiles beyond 8 (was every 4 beyond 6), up to 12.",
	]},
	{"v": "0.24.27", "items": [
		"THE COMPUTER HARASSES THE WORKERS: a computer's soldier out alone in the enemy's land (a Clock Soldier that chased a scout out of its base, the Crown's raiding Horsemen, a soldier scout) no longer stops to hit a ROOTED Brood creature (a Mound Turtle, a Rootmaw) or a building: it walks past them and goes for the workers (grubs, Labourers, Winders), the ones standing still first, and keeps walking to the worker line. A Sire, the Brood Mother on her feet or a stronger force makes it pull back, then it comes again; hurt or out too long, it goes home. A big army attack still hits whatever it meets.",
	]},
	{"v": "0.24.26", "items": [
		"THE UNIT CARD SAYS IT SHORT: the selection panel's line under the health now gives a short description of the unit or building, one line (\"Builds, repairs, works Farms and Mills, and hauls. Weak in a fight.\"), instead of the long text cut off in the middle. Rest the mouse on its PORTRAIT (a long press on a phone) for the full text and its numbers: health, attack, armour, speed, sight, supply and what it costs.",
		"OLD TEXTS FIXED: the Labourer's card no longer says he mines gold (the gold mines are long gone); the Clocktower's text no longer speaks of batteries, Boilers and coal (it holds brass and spring life, and allows 2 Cog Presses and 1 Mainspring); the Mist Toad's text and energy line name its third spell, MIASMA.",
	]},
	{"v": "0.24.25", "items": [
		"THE COMMAND CARD'S KEYS STAY PUT: a command's letter no longer depends on which other buttons are showing. Each kind of selection gets its letters once, over every command it can ever have (all its research, rooted and uprooted, armoured soldiers, CANCEL, the refits...), and keeps them all match: starting, queueing or finishing a research, rooting or uprooting, a button greying out never moves another command's letter. STOP keeps S everywhere it can appear, so a research is never S on a card that can show STOP.",
		"STOP RESEARCH is X (a Sire's or the Brood Mother's), STOP GROWING is Z: before, starting a research could hand its S to STOP RESEARCH, so pressing S again to queue the next one cancelled it. Pressing a research's key again queues the next of its line (MATCHLOCK, then FLINTLOCK, on the same F) or, if there is none, just says it is already being researched: the key never falls through to another command (such as STOP).",
	]},
	{"v": "0.24.24", "items": [
		"THE BROOD'S SWAMP SPREADS AT A WALK: a newly rooted Mound Turtle's swamp (and the Brood Mother's) grows out from it 1 tile a second up to its full size, drawn growing; when it gets up or dies, the swamp only it held shrinks back just as fast (swamp another source still covers stays). A Rootmaw roots only where the swamp has already reached. Saves and online games keep how far it has spread.",
		"NO SWAMP, NO ROOTMAW: a rooted Rootmaw needs swamp under it, as it does to root. When its swamp goes (its Mound Turtle got up or died, or the Mother walked off and her swamp shrank back), it stops feeding and uproots by itself, keeping its food, with an alert: \"A Rootmaw lost its swamp and uprooted.\" Its ground keeps the food left in it.",
		"A HATCHING EGG KEEPS YOUR SELECTION: a selected egg that hatches hands the selection to its young (all 2 or 3 of a clutch), and they join its control groups; the rest of the selection stays. The same for a grub turning into a Rootmaw, Mound Turtle or Sire: its cocoon is selected in its place. Online too.",
		"ORDERS WHILE UPROOTING: a creature pulling up its roots now also takes ROOT (pick the spot as usual, Shift to queue it), besides right-clicks, Shift+right-clicks and MOVE: e.g. Shift-queue \"move there, then ROOT there\"; it carries them out once it is up.",
		"HARVEST AUTOCAST ON PATROL: a grub with HARVEST on that is patrolling, holding or attack-moving breaks off for a body near it, harvests it, delivers it to the Mother and goes back to what it was doing: the same patrol between the same two points, its hold spot, its attack-move.",
	]},
	{"v": "0.24.23", "items": [
		"THE BROOD HEALS ONLY OUT OF THE FIGHT: the swamp's healing (and SWAMP MENDING) and the rooted Mother's own healing start 5 s after an enemy last hit the creature, no longer during the fight. A Clock Soldier could not kill a rooted Mound Turtle: the swamp healed it nearly as fast as he hit.",
	]},
	{"v": "0.24.22", "items": [
		"WATCHING COMPUTERS: the PRODUCTION list shows the Brood too (it has no buildings, so it was empty): its eggs hatching, its young moulting into their mature forms, and its Sires' and Mother's research, with what waits after it.",
	]},
	{"v": "0.24.21", "items": [
		"THE MAIN MENU'S BOTTOM LINE: \"Version 0.24.21\" (click it to read the patch notes; their BACK returns to the main menu) and \"This game was made with the help of AI\".",
	]},
	{"v": "0.24.20", "items": [
		"THE MAIN MENU IS ONE FLAT GRID (the owner's drawn layout): the title on one line across the top-left, and under it three rows of buttons, all in the painting's empty sky so none of the battle is covered: CAMPAIGN (coming later), SKIRMISH and ONLINE; HOW TO PLAY, REPLAYS and EDITOR; then CONTINUE (only when you have a saved match), SETTINGS and EXIT. No more PLAY, LEARN or WORKSHOP steps: every page is one tap away and its BACK returns here. EXIT saves and closes the game (not in a browser, where there is no EXIT). MATCH LOGS is now a button on the REPLAYS page.",
	]},
	{"v": "0.24.19", "items": [
		"THE MAIN MENU OVER THE WHOLE PAINTING: the battle painting now covers the whole screen, with no wooden bar. The title and a column of buttons sit in the top-left corner, over the painting's dark storm sky (on a wide phone, two columns of buttons under a smaller title); the language flags are in the top-right corner and the version small in the bottom-right. The buttons work as before: PLAY, LEARN and WORKSHOP open their choices in the same place, and BACK, Esc or the back button return.",
	]},
	{"v": "0.24.18", "items": [
		"THE MAIN MENU'S PAINTING, WIDENED: more of the Crown's pikes and muskets on the left and more Clockwork columns on the right, so the painting fills the whole screen above the bar, edge to edge, on computers and phones.",
	]},
	{"v": "0.24.17", "items": [
		"THE MAIN MENU HAS ONE SLIM BAR: the painting fills the screen above a single wooden bar along the bottom, with the title on its left, one row of buttons in the middle and the language flags and version on its right. The row: CONTINUE (when you have a saved match), PLAY, LEARN, WORKSHOP and SETTINGS. PLAY opens SKIRMISH, ONLINE and CAMPAIGN (coming later) in the same place; LEARN opens HOW TO PLAY; WORKSHOP opens EDITOR, REPLAYS and MATCH LOGS. BACK, Esc, and the phone's or browser's back button go back one step, and a page you leave brings you back to the row you opened it from.",
	]},
	{"v": "0.24.16", "items": [
		"THE MAIN MENU'S PAINTING IS SHOWN WHOLE: the title sits on a wooden bar above it and the buttons on one below, so nothing covers the picture; on a wide screen its sides are filled with the painting's own colours, dimmed.",
	]},
	{"v": "0.24.15", "items": [
		"THE MAIN MENU'S NEW PICTURE: one still oil painting of the three armies clashing (the Crown's volley and charge, the Brood pouring down the hill under its Mother, the Clockwork marching in brass), in place of the three panning faction pictures.",
	]},
	{"v": "0.24.14", "items": [
		"PICK THE GEAR WHEN YOU BUILD (Clockwork): while you place a Cog Press, Mainspring, Light Works, Ratchet Turret, Escapement, Clock Aviary or Regulator, the card has a SMALL GEAR / BIG GEAR button (key G) and the ghost shows its ring at that size and says which. A big ring costs 25 cogs more, takes 4 s longer to build and needs more room: the ghost checks the big ring, so it can't cut into another ring. Once placed the size is fixed. Each kind remembers your last pick for the match. The big ring's numbers are back: a Cog Press with up to 8 Winders for 10 cogs a second (small: 5 for 7.2), a Mainspring with 6 Winders storing 400 Tension (small: 3 and 200), the Ratchet Turret's slow heavy screws; the Light Works, Escapement and Clock Aviary work slower on it. The Heavy Works is always big.",
		"The Clockwork computer lays a big Cog Press when it has the spare Winders to fill one and the room for its ring; everything else small. Online and in replays the size goes with the build order; saves keep each building's ring and your last picks.",
	]},
	{"v": "0.24.13", "items": [
		"THE ROOTMAW'S GROUND IS TWICE AS WIDE: its circle is now 10 tiles round it (was 5), and two rooted circles still may not overlap, so Rootmaws stand 20 tiles apart. Each keeps the same 3,000 food and drinks at the same rate: this is a NERF to the Brood's economy (stacking 4 or 5 Rootmaws on one base was too strong). About 1 or 2 now fit on the Brood Mother's own swamp and 1 round each Mound Turtle; more swamp (turtles) means more room. The computer roots a turtle on new ground when it has no room for another Rootmaw.",
		"MUSIC: you hear your own faction's music. With the default setting the opening, calm and skirmish pieces are always your faction's; only in a full battle is one piece in five the enemy's battle music (before, one piece in five was the enemy's in every moment, calm included). YOUR FACTION ONLY never plays the enemy's.",
	]},
	{"v": "0.24.12", "items": [
		"THE UNIT PANEL AND THE COMMAND CARD STAY UP WITH NOTHING SELECTED: they are drawn empty, with your faction's name faint in the panel (watching or a replay: the player you look through). Clicks on them never go to the map. EACH FACTION HAS ITS OWN FRAMES now, behind the icons and text, selected or not: the Crown dark wood with gold crowns and fleurs-de-lis, the Clockwork riveted brass with cogs and springs, the Brood twisted rope with claws and eggs.",
	]},
	{"v": "0.24.11", "items": [
		"ONE COMMAND CARD, NO PAGES: the MORE button and its \"1/2\" pages are gone. All of a selection's commands are on one card, four to a row; it shows three rows and scrolls when there are more: the mouse wheel over the card, a finger dragged up or down on a phone, or the thin scroll bar at its right edge (Tab scrolls too). A new selection starts at the top; a unit dying keeps where you were. A worker's BUILD page scrolls the same way.",
		"EVERY KEY ON THE CARD IS ITS OWN: no two commands on a card share a letter, and a command's key works even while its button is scrolled out of view, so you can just press it if you know it. The first row's commands and the production buttons keep their usual letters; a command that clashes takes the next free letter of its name. The Brood Mother: Raptors keep R; her RALLY and WORKERS take free letters (F and Z while QUICK ROOTS and SWAMP MENDING are still to research, Q and W after); rooted, UPROOT is D (was Q); uprooted, ROOT keeps D (the Mist Toad takes Q).",
		"The rarer commands go to the bottom of the card: WORK, AUTO REFIT, TEAM, HOLD FIRE, then RALLY and WORKERS (a right-click sets them too) and DEMOLISH last, so scrolling is rarely needed.",
	]},
	{"v": "0.24.10", "items": [
		"THE BROOD'S NEW SOUNDS, from the owner's sound pack: real bites and chomps under every Brood blow (the Raptor and the Grub too), wet splats where a venom glob lands (small for the Spitter, bigger for the Venom Challenger, biggest for the Venom Sire), a wet burst under every Brood death, eggs cracking as they hatch (3 kinds), a cocoon or moult splitting open, the Mother laying an egg, a grub's squish as it takes food, a squelch as a creature roots or uproots, and wingbeats when you send a flyer (small for the Hatchlings and Skywings, two beats for the Storm Challenger, heavy leathery beats for the Storm Sire; one flap for a whole flock). New takes for the Tyrant Challenger and the Tyrant Sire.",
		"THE BROOD'S ERROR SOUND is now a creature's grunt (the owner's pick): every failed order (not enough food or spoils, no supply, no room, can't do that) grunts instead of clicking, a little softer when the announcer speaks too.",
	]},
	{"v": "0.24.9", "items": [
		"THE GEAR SWAP IS GONE (Clockwork): the SMALL GEAR / BIG GEAR button is removed (a ring that grew clipped into the gears around it). Each building keeps the gear it is built with: the Heavy Works its big gear (the Pendulums, Ballistas and Great Winders are made there), every other building its small one. Saves made before still load.",
		"THE SPRING MARK (the little gold coil over a Clockwork building) now shows only on buildings that use or spend Tension, and explains itself: rest the mouse on it (or long-press it on a phone): a Mainspring's ring meshes with this building's, so it is fed Tension and can work and make what costs Tension.",
		"THE CLOCKTOWER'S PICK SOUND is gentler and varied: four short strikes of the old bell (two pitched a little, one with two ticks before it) instead of two long ones, its low hum and clangy ring softened, and played a little quieter, like the Town Hall's (it is picked for every Winder).",
	]},
	{"v": "0.24.8", "items": [
		"THE CLOCKWORK'S CHARGE IS SHOWN: every Clockwork unit that runs on a spring (Clock Soldier, Springer, Netter, Pendulum, Spring Ballista and the rest; not the Winders nor the Great Winder) shows its charge on its card: an amber bar under the health and the words first on the line: Charge 63%, Winding up: 63% while it stands on the gear field (or a Winder or a Great Winder winds it), Fully wound, or RUN DOWN. In a group, each portrait has a thin charge line under its health.",
		"CHARGE BARS OVER YOUR UNITS: a thin amber bar over each of your Clockwork units that is not fully wound, draining as the spring runs down; on the gear field it turns pale gold and fills, and it is gone once full, so a wound-up army shows no extra bars. Settings: SHOW CHARGE BARS turns them off.",
		"THE SPRINGER'S SCREW is drawn about 1.8 times bigger in flight, so it is easier to see; its damage and its sparks are unchanged.",
		"THE NETTER'S NET NO LONGER SHUTS A UNIT DOWN: a caught unit cannot move nor use its abilities or spells for the net's 4 s, but it still fights: it fires or strikes at whatever is in its reach. A flyer caught still comes down to the ground. It is not a stun (no stars).",
	]},
	{"v": "0.24.7", "items": [
		"The Brood Mother's egg line and health bar stay put: they no longer bob up and down as she lays, swipes or walks, so her egg count and its tooltip are easy to read.",
	]},
	{"v": "0.24.6", "items": [
		"POWDER SMOKE, SMOOTHER: the puffs no longer show square edges when they grow (the painted frames touched their borders: each puff now fades out in a soft circle), no longer pop at the edge of the screen, and fade in over half a second. No puff vanishes at once any more: near the limit the oldest age faster and a new shot waits instead of wiping out an old puff.",
		"POWDER SMOKE, NO MORE WHITE WALL: where many volleys land in one place the smoke merges into one cloud: each puff there is drawn thinner and ages faster, and a full cloud takes only some of a new shot's puffs. A heavy firefight still leaves a haze that lingers, but it thins steadily: after 30 Musketeers and 4 Field Cannons fire for 12 s, the thickest spot is about a third as solid as before (no white wall), and the haze still lingers some 20 s, thinning steadily.",
	]},
	{"v": "0.24.5", "items": [
		"THE COMPUTER EXPANDS BEFORE IT GOES BROKE: since 0.24.0 spent land pays nothing, and a Hard Crown that lost its second Town Hall sat for ten minutes with 36 idle Labourers and no income. Now the Crown and Clockwork computers keep a hall's gold (and its first Farm's or Cog Press's) once their land runs low, even with enemies about; take any free hall ground when every usual site is on the enemy's side; train no Labourers or Winders for spent land; and send the hands waiting by the halls to the new Farms. The Brood computer already moves its Rootmaws off spent ground.",
	]},
	{"v": "0.24.4", "items": [
		"THE SELECTION PANEL SHOWS EVERYONE: with several units selected the panel no longer ends in \"+N\". First comes one icon per kind with its count (gold frame), then every unit's own icon with his health; when they don't fit, scroll with the mouse wheel, by dragging the icons (a finger on a phone) or with the bar at the right.",
		"CLICKS ON THE PANEL, THE SC2 WAY: on a unit, a click keeps only him, Ctrl+click keeps his kind, Shift+click drops him, Ctrl+Shift+click drops his kind; on a kind's icon, a click keeps that kind, Shift+click drops it. On a phone: tap = the click, double tap on a unit = his kind, long press = drop (him, or the kind on a kind's icon).",
		"THE SAME ON THE MAP: Ctrl+Shift+click on one of your units drops his kind from the selection (if none of his kind is selected, it adds every one of his kind on screen); click, Ctrl+click (or a double click) and Shift+click work as before.",
		"A CLICK ON A WORKER LABEL SELECTS ITS WORKERS: the label over a Town Hall (HAULERS), a Farm (FARMERS), a Powder Mill, a Cog Press or Mainspring (WINDERS), a Rootmaw or a food pile (GRUBS) now selects the workers of that building (Shift+click adds them to the selection; a tap on a phone); it used to select the building. The same with a click on the worker chip on the building's card (a long press on a phone; a tap still shows its tooltip). With nobody assigned, the click selects the building as before.",
	]},
	{"v": "0.24.3", "items": [
		"THE BROOD MOTHER'S TWO RALLY POINTS: with her selected, her right-clicks take turns: the FIRST sets her GRUBS' rally (drawn gold: her new grubs go there; on a Rootmaw or a food pile they gather there), the SECOND her WARRIORS' rally (drawn green), and so on. The button the next right-click sets is shown pressed on her card; WORKERS and RALLY set either one directly. Her rallies come first, always: warriors hatching in a Sire's nest go to HER warrior rally (the Sire's only if she has none). Fixed: warriors didn't go to the rally, since an egg kept the rally she had when she laid it; now a hatchling looks at her rally when it hatches. Without a grubs' rally a new grub finds work by itself.",
		"Grubs bringing food deliver at the NEAREST edge of the Mother (her back, her sides), no longer walking round to her front. The same for grubs bringing a body or going to be offered up, and for anyone walking up to a rooted creature.",
		"UNITS BEHIND BIG PICTURES ARE SHOWN AS SILHOUETTES (as in StarCraft 2 and Warcraft 3): your unit behind the Brood Mother, a rooted creature, a big creature or any building is drawn over it in your colour, see-through, with a bright rim. Only your units and the ones you select, so it stays cheap in big battles.",
		"A creature that is UPROOTING has its card (MOVE, ATTACK, STOP...): orders, right-clicks and Shift-queued orders given now start as soon as it is up.",
		"PAY AT ONCE: a grub sent to turn into a Rootmaw, a Mound Turtle or a Sire's lure pays the moment it is ordered, as a building placed; all of it comes back if it is killed on the way, stopped, given another order or can't morph there. (A Shift-queued one pays when its turn comes.)",
		"F2 (ARMY) no longer selects rooted creatures (the rooted Mother, Rootmaws, Mound Turtles, Sires on their nests), eggs or cocoons: only warriors and creatures that are up. F3 (MAKE) still selects the Mother.",
		"A Rootmaw's card shows the food left in its GROUND beside the food it holds; placing a Rootmaw (a grub's BUILD or ROOT) shows over the ghost the food in the ground there: 3000 on fresh ground, less on partly spent ground, 0 on spent ground.",
		"HARVEST AUTOCAST: right-click (or long-press) a grub's HARVEST to switch it on (it glows): an idle grub harvests the bodies near it by itself, then goes back to work.",
		"MATURE matures ONE unit of the selection a click (or a key press); Ctrl+click, Ctrl+its key, a right-click or a long press matures ALL that can.",
		"THE BROOD'S RESEARCH QUEUES like a building's: while a Sire (or the Mother) researches, his other research stays on his card to queue (up to 5, each paid when queued); the queue's icons show on the card with the first one's bar, and a click on one cancels it, paid back. A Sire with research in hand or queued still fathers no eggs; the Mother keeps laying; enemies still see nothing of it.",
		"The Venom Challenger is drawn smaller than the Tyrant Challenger (it was much bigger), still bigger than a Spitter; its body is smaller to match. The venom globs grow with the creature: the Spitter's glob, the Venom Challenger's 1.4 times it, the Venom Sire's 1.8 times (he spat a small acid ball).",
		"THE MIST TOAD'S MIASMA (the retired Spore Mother's spell, as decided on 2026-10-29): its third energy spell (60 energy, Q): a green cloud on a spot for 8 s; the Brood inside heal up to 30% of their health (7 a second; clouds don't stack). A new Mist Toad has 75 energy of its 150 (it already did: on swamp it fills twice as fast, 3 a second, so it is full 25 s after hatching).",
		"THE CROWN: a Town Hall's rally set ON a building going up sends each new Labourer to help build it, as a right-click on it would (they used to walk there and stand). A rally on a Farm or another work site still puts them to work there.",
	]},
	{"v": "0.24.2", "items": [
		"A key held down fires only once (training keys still repeat): holding B no longer opens BUILD and then picks the Barracks. Some browsers send a held key's repeats as fresh presses; a key now counts again only after it is let go.",
	]},
	{"v": "0.24.1", "items": [
		"NO SOUNDS THROUGH THE FOG: a sound at a spot you can't see (an enemy's hammer on a building going up, gunfire, a death in the fog) is no longer heard. Your own base and your allies' are always heard; alerts and the announcer still speak; watching computers with all vision, a replay or FOG: OFF hear everything. Online, each player hears by his own vision.",
		"THE COMPUTER (ALMOST) NEVER USES PLAIN MOVE: a computer's soldier sent to scout now goes on attack-move (a Musketeer scout was killed by one Raptor without firing back): it fires at enemies that fight back but not at every hall on its loop, turns and fights one or two it can't outrun, and walks home on attack-move (driven off, it still retreats on a plain move). A raider hunting workers attack-moves when an enemy soldier is in reach; the Brood's Raptor scout and its army gathering at the staging point attack-move too. Retreats, workers, siege set-up, wagons and horses still walk.",
		"RESOURCE TOOLTIPS: rest the mouse on gold, powder, cogs, Tension, food or spoils in the top bar: what it is, how it is earned, what it pays for, how it runs out (spent soil, brass and ground pay nothing; powder and Tension fall to a floor), the workers on it out of the most its buildings take (Workers: 40 / 50 on 5 Farms), and your income a minute.",
		"REFITS ONE AT A TIME: a click (or the key) on a refit (Armour, the shot pouch, a better lock, the bayonet) sends ONE soldier of the selection; Ctrl+click or Ctrl+the key sends all that can. The same for the Clockwork's MORPH TO OWL.",
		"ATTACK GROUND's key now reads Ctrl+A (it read ^A).",
		"FIX: continuing a match from the main menu, the fog of war was missing through the 3, 2, 1 countdown (every enemy unit stood in plain sight): it is in place from the first picture.",
	]},
	{"v": "0.24.0", "items": [
		"EXHAUSTED MEANS EXHAUSTED: no free income for anyone. A Farm, Cog Press or Mainspring with nobody working it makes NOTHING (Farms and presses used to grow at 15% by themselves). Spent soil, spent brass and a Rootmaw's spent ground pay nothing (spent brass used to pay a quarter forever).",
		"POWDER AND TENSION DON'T RUN DRY: a Powder Mill grinds less as its Town Hall's saltpetre runs down and 15% once it is spent; a Mainspring winds less as its Clocktower's new SPRING LIFE (1,320 Tension) runs down and 5% once it is spent. A spent Mainspring is FATIGUED (the spring has taken a set): it still drives its rings, stores Tension and counts as a Mainspring for everything meshed with it. Only while worked: an empty Mill or Mainspring gives nothing. A new hall brings them back to full strength.",
		"CLOCKWORK LIMITS AND NUMBERS: 2 Cog Presses and 1 Mainspring per Clocktower (Mainsprings had no limit; older saves keep the ones they have). A Cog Press takes 5 Winders for 7.2 cogs a second (big gear: 8 for 10), a Winder costs 60, a Clocktower holds 9,000 brass (was 11,400): fewer Winders than the Crown's Labourers for about the same income.",
		"The computers: the Crown fills its first Farm before it staffs the Mill (unless it fears a rush); the Clockwork builds one Mainspring per Clocktower and a new one by a fresh Clocktower once its springs are fatigued, and counts the spring life when it decides to expand.",
		"Fixes: the Clockwork's \"cogs earned\" on the end screen no longer loses what was spent on repairs; the Powder Mill's card no longer says spent saltpetre pays a quarter; the Clocktower's card shows its brass and spring life; the help pages describe the gear economy instead of the old batteries and coal.",
	]},
	{"v": "0.23.0", "items": [
		"THE MARCHING BAND (an EXPERIMENT, off by default: switch on MARCHING BAND (experiment) in Settings; a match keeps the rule it started with). The Crown can train ONE band at a Barracks (50 gold, 15 s). It starts as the bandmaster alone; ADD DRUMMER (50 gold, 8 s), ADD PIPER (75 gold, 12 s) and ADD FIFER (60 gold + 10 powder, 10 s) on its card take on musicians, one at a time, each +15 health. Every instrument it has plays a small buff to your soldiers and guns within 5 tiles of it: drums +5% speed, pipes +7% melee damage, fife +5% reload speed.",
		"THE BAND'S SOLOS: DRUMS SOLO, PIPES SOLO and FIFE SOLO put that instrument in the lead for 8 s with its full buff (drums +25% speed, pipes +35% melee damage, fife +30% reload speed), then 45 s before it can solo again; one solo at a time. Its ring on the ground turns the instrument's colour and pulses (the enemy sees it too) and the band's music plays near it. It is unarmed and fragile: kill it and the music stops. With no orders it falls in behind your soldiers on the march; right-click one of your units to have it follow him.",
		"The Crown computer trains a band when the experiment is on, takes on musicians and plays the fife's solo when its line fires, the pipes' when the enemy reaches it.",
		"Studies, no numbers changed: what each Armoury research is worth in a fight (docs/armoury_study.md) and the band's fights (docs/marching_band.md).",
	]},
	{"v": "0.22.10", "items": [
		"No change to play: a study of the Clockwork's and the Crown's economies (docs/cw_economy_study.md) and the tool that measures them, with a switch only the study uses to try limits such as one Mainspring per Clocktower.",
		"No change to the game: a TEST of the Musketeer at 55 health and the Guardsman at 65 (docs/musket_hp_test.md). The recommendation: keep 70 / 90, or at most 65 / 85.",
	]},
	{"v": "0.22.9", "items": [
		"THE BROOD COMPUTER PLAYS A REAL ECONOMY (the designer's build): its first Mound Turtle goes on the NATURAL expansion in the first minute, its third Rootmaw at the natural's far edge (farther loads pay more), grubs come nonstop, and a second turtle takes the third expansion with Rootmaws round it. The Mother grows once her eggs, not her food, hold the Brood back. Against the Crown it now earns about as much as the Crown for the first ten minutes (it earned three quarters before).",
		"A Brood grub now keeps WATCH all game: against the Crown it walks to and fro at the foot of the enemy's ramp, against the Clockwork it walks round the enemy's main. When an enemy army leaves its main the computer raises the ALARM: warriors before grubs, the army waits at the natural, grubs run from Rootmaws the enemy comes near, and a Mound Turtle roots in front of the natural. It never lets its army fall far behind the enemy army it has seen.",
		"The Brood computer's Air rush lays Raptors and offers them up for the Storm line's spoils, and sends more grubs to harvest bodies.",
	]},
	{"v": "0.22.8", "items": [
		"The line over the Brood Mother now says what it counts: Eggs: 4/10  4.8s · 00:35.",
	]},
	{"v": "0.22.7", "items": [
		"THE MOTHER'S EGG TOOLTIP: rest the mouse on the egg line over the Brood Mother (4/10  4.8s · 00:35) and a tooltip explains every number: her eggs and her clutch's size (her stage sets it: 10, 15, 20), the next egg and the time to a full clutch, her laying in all (eggs a minute, one every N s) and each lever with its value: her stage, the Sires near her (named), the Mound Turtles on new ground, her harvest veterancy, and the sum. It says what stops her laying (growing, a full clutch; a Sire who researches fathers no eggs of his line). Her card's LAYING button gives the same text. Only for your own Mother (and spectators).",
		"ICONS ON THE UNIT CARD WITH THEIR TOOLTIPS: the stats row of a card now starts with what it works with. The Brood Mother: her EGGS (an egg and 4/10: the egg tooltip) and the GRUBS bringing her food. A Rootmaw or a food pile: its GRUBS (5/6) and its food. A Town Hall: its HAULERS; a Farm: FARMERS and its soil; a Powder Mill: POWDER MAKERS and its saltpetre; a Cog Press: WINDERS and its brass; a Mainspring: WINDERS; a Horse Breeder: its Town Hall's HAULERS. Rest the mouse on one (tap it on a phone) for the same tooltip as the label over it on the map.",
	]},
	{"v": "0.22.6", "items": [
		"The Brood Mother's egg line shows her next egg in tenths of a second once it is under 10 s, and always the time until her clutch is full: \"4/10  4.8s · 00:35\". At her fastest (stage 3, three Sires, three far turtles, full harvest veterancy) she lays about one egg every 1.4 s.",
	]},
	{"v": "0.22.5", "items": [
		"Over the Brood Mother, beside her eggs (4/10), a countdown to her next egg (00:05), at her laying rate now. None when her clutch is full or while she grows.",
	]},
	{"v": "0.22.4", "items": [
		"GRUBS CAN BE SACRIFICED: SACRIFICE (C) is on the grub's card now. A grub offered up at the Brood Mother gives 10 spoils and a whole egg back (it hatches alone, like a Brute). A grub at work can be sent: it hands over the food or the body it carries when it gets to her. A grub on its way to turn into a Rootmaw, a Mound Turtle or a Sire can't be.",
		"SACRIFICE PAYS MORE FOR RAPTORS: a Raptor offered up gives 15 spoils (was 9): 30 for the two of one egg, 45 for the three of a Bigger Clutch egg. The other creatures are unchanged (a Spitter 16, Hatchlings 14, a Tyrant Challenger or a Mist Toad 35, a Brute or a Venom or Storm Challenger 53).",
		"The VENOM SIRE now costs 25 spoils on top of his 200 food (offer up three grubs, two Raptors, or harvest a few bodies). The Tyrant Sire still costs no spoils.",
		"HARVESTED BODIES GIVE TWICE THE SPOILS: a body a grub wraps and carries to the Brood Mother gives 4 spoils for each point of its supply (was 2) plus 2 for each kill it made (was 1), the kills part up to 100 (was 50): a Musketeer 4, a Brute 12, a Horseman with his horse 16.",
		"THE BROOD MOTHER'S VETERANCY: every harvest a grub delivers to her gives her 1 veterancy, and each makes her lay 1% faster, up to +50% (50 harvests). It adds to her other levers (her stage, the Sires near her, turtles on new ground). Her card shows it (VETERANCY 23 · EGGS +23%) once she has some.",
	]},
	{"v": "0.22.3", "items": [
		"FIX: THE BROOD MOTHER CAN HIT A GATE ON A RAMP. Sent to ATTACK a gate (or anything out of her reach), the uprooted Mother stood still: she never chased what she was told to attack (a rule meant for the computer's Mother, kept on a leash at home). Now she goes for what you send her at, on ATTACK and ATTACK-MOVE; on her own (idle, HOLD) she still stands her ground, and the computer's Mother keeps her leash.",
		"FIX: big Brood creatures got stuck at the top or foot of a ramp. The Mother's body was too wide to stand on a ramp's side lane where the path ran, and she stood pressing at the ramp's edge (the Tyrant Sire nearly so). The Mother, the Sires and the Mound Turtle now walk the ground with a narrower body: every ramp, 2 or 3 tiles wide, at every stage of the Mother.",
		"THE MOTHER'S SIZE: her picture still grows with her stage (x1.15, x1.3), but her body does not, so she still fits through every ramp. She reaches from her drawn edge, enemies reach her at her drawn edge, and a click anywhere on her picture picks her.",
		"SACRIFICE: the eggs a sacrifice gives back are now per EGG: the young of one egg together give the Mother ONE egg (two Raptors of one egg: one egg; three of a Bigger Clutch: one egg), not one each. Spoils are paid for each creature as before. A creature that hatches alone (a Brute) gives a whole egg; a matured Challenger counts as the young it was.",
	]},
	{"v": "0.22.2", "items": [
		"The TYRANT SIRE, the father every Brood opening needs (Raptors), is now the cheaper one: 150 food and 30 s (was 200, 35 s). The VENOM SIRE, the specialist, costs 200 food and 35 s (was 150, 30 s).",
	]},
	{"v": "0.22.1", "items": [
		"MAKE (F3) selects the Brood Mother for a Brood player (the Brood has no buildings: she lays every egg) and jumps to her.",
	]},
	{"v": "0.22.0", "items": [
		"A REAL BROOD COMPUTER: the computer now plays the Brood from a build order per plan (Extreme rush, Rush, Timing attack, Balanced, Economy, Air rush). It grows the Brood Mother on time, raises its Sires through their lures (the Storm Sire first when it sees enemy flyers), researches (Bigger Clutch early, Pack Hunt before it attacks, Battering Horns before a siege, Quick Roots later), matures its young before a push, and expands with Mound Turtles on new ground with Rootmaws round them.",
		"It scouts with a grub (and later a Raptor) and reacts to what it sees: an early army on the move makes it hold at home, enemy flyers bring the Storm Sire, a musket wall means Spitters and Brutes instead of Raptor waves into it. It gathers its army before it attacks, pulls a losing wave back, calls a wave home when the Mother is attacked, keeps Hatchlings home unless the enemy flies, and keeps its grubs to a sensible number.",
		"Fixed for the computer's Brood: it no longer sits on food for minutes while saving for the Mother's stage 3, and a Sire sent to a nest spot it can't reach no longer walks there forever.",
	]},
	{"v": "0.21.2", "items": [
		"ART: THE GRUB'S COCOON is the designer's drawing now. A grub turning into a Rootmaw or a Mound Turtle fades into a small scaly case on the earth, the case grows to full size, glows, shakes and cracks, splits open as the creature comes out, and its empty broken shell stays on the ground a moment.",
		"ART: THE MOULT is drawn now. A young Spitter, Raptor or Hatchling maturing turns south-east, hunches and greys, a stone-grey shell closes round it and swells, glows, shakes, cracks and splits, and the Challenger steps out grey and regains its colour; the broken shell and the shed skin stay on the ground a moment. A Hatchling comes down to the ground for it and its Storm Challenger rises out of the shell into the air.",
		"ART: the designer's portraits for the Spitter, the Venom Challenger and the Tyrant Challenger, and for the Brood Mother at stages 2 and 3: her card shows the portrait of her current stage.",
	]},
	{"v": "0.21.1", "items": [
		"THE BROOD MOTHER'S STAGES IN EVERY DIRECTION: at stage 2 and stage 3 she now walks and swipes with her own pictures facing south, east, north-east and north too (and the west views, mirrored), no longer her stage-1 frames made bigger. She keeps her size as she turns and grows only by her stage.",
		"Her swipe from behind (north) no longer shows an odd frame of her tail and a burst of earth: her claw stays raised a moment longer and comes down as the blow lands.",
	]},
	{"v": "0.21.0", "items": [
		"THE STORM LINE: the Storm Sire now fathers HATCHLINGS (the Brood Mother at stage 2), two to an egg (80 food and 10 spoils): cheap, fast little flyers that bite only FLYERS. They can't touch the ground: a flock to keep the enemy's flyers off, fragile against muskets.",
		"STORM CHALLENGER: at her stage 3 a Hatchling MATURES (110 food and 25 spoils, 9 s moult) into a Storm Challenger, a young Storm Sire that swoops down to bite flyers and ground units alike, over cliffs and water.",
		"The SKYWING is retired: it was the Storm Sire's stand-in and is no longer laid. Skywings in older saves still fight, and a Skywing egg in an older save hatches Hatchlings.",
		"The Storm Sire's BIGGER CLUTCH works now (Hatchlings three to an egg, 120 food and 15 spoils). UPDRAFT speeds up Hatchlings (132 to 152), Storm Challengers (120 to 138) and the Storm Sire while they fly.",
		"The computer's Brood lays Hatchlings against enemy flyers (about two for each), and at stage 3 a few more to mature into Storm Challengers.",
		"ART: the designer's Hatchling and Storm Challenger sheets (fly, bite or swoop, death, in every direction). Their portraits are the designer's too; they speak with the Skywing's sounds until their own come.",
	]},
	{"v": "0.20.3", "items": [
		"THE BROOD'S OWN CALLS: every Brood creature answers with grunts, growls, roars and hisses cut from the designer's recordings (no words): each line its own (the Tyrant line roars, the Venom line croaks and hisses, the Storm line cries), pitched down for the big creatures and up for the small ones. The Raptor keeps its lizard voice.",
		"Every creature has its own blows and death now: the Tyrant Challenger, the Sires, the Brood Mother, the Rootmaw, the Mound Turtle and the Mist Toad no longer clash like swords. Each spitter has its own venom hiss, the Mist Toad's TONGUE its own lash, the Brute's charge his bellow.",
		"Each Sire roars his own call when he comes to his lure and breathes his own on the eggs; a young creature calls out as it matures; a mixed Brood group answers with a chorus of creatures.",
	]},
	{"v": "0.20.2", "items": [
		"ART: the designer's icons for the Brood's research (BIGGER CLUTCH for Raptors, Spitters and Hatchlings, PACK HUNT, BATTERING HORNS, SLITHER, LONG SPIT, UPDRAFT, QUICK ROOTS, SWAMP MENDING) replace the temporary ones, in the Brood's own bronze frame.",
		"The grub's BUILD card shows each Sire's LURE on his button: the Tyrant's red spiked lure, the Venom's dripping yellow-green one, the Storm's crest-fin in its white haze. The Sire's own portrait stays on his card.",
	]},
	{"v": "0.20.1", "items": [
		"THE STORM SIRE FLIES IN: when his lure is ripe he now comes flying from a few tiles away, his shadow on the ground under him, glides down, brakes and lands on the lure, then eats it and stands. The same total time.",
		"THE SIRES' EGGS take their lure's colour, faintly: the Tyrant's a faint red, the Venom's a faint yellow-green, the Storm's a faint storm-cloud white. They take it as he breathes on them; grub eggs keep their colour. The Storm Lure's haze is storm-cloud white too, no longer blue (it clashed with a blue team).",
		"LONG SPIT: Spitters and Venom Challengers now spit 165 as standard, under a Musketeer's 190; LONG SPIT brings them to 190, the Musketeer's range, not beyond.",
		"PACK HUNT also speeds up the Tyrant Sire (64 to 75), UPDRAFT the flying Storm Sire (110 to 127).",
		"What a Sire researches is shown only to his own side, its allies and spectators: an enemy sees only his production animation, no bar, label or card text.",
	]},
	{"v": "0.20.0", "items": [
		"THE BROOD'S RESEARCH: with no buildings, its rooted creatures research. Each Sire, rooted on his nest, researches his own line's upgrades on his card; the Brood Mother the ones for every creature. One at a time each, paid up front; getting up stops it (paid back), and a Sire killed while researching loses it (paid back); what is done stays.",
		"A SIRE RESEARCHING fathers no eggs: the Mother can't lay his line's eggs until he is done, but his fertilising animation keeps playing, so a scout sees him busy. His card shows RESEARCHING and its bar in place of his eggs, and STOP RESEARCH. The Mother keeps laying while she researches (she can't grow meanwhile).",
		"YOUNG TWO TO AN EGG: Raptors and Spitters hatch two to an egg (a Raptor egg 50 food). BIGGER CLUTCH (each Sire's: 100 food, 15 spoils, 40 s) makes it three, the egg costing more so each young costs the same (75 for three Raptors; 135 food and 8 spoils for three Spitters).",
		"TYRANT SIRE: PACK HUNT (Raptors and Tyrant Challengers run a little slower than before as standard, 96 and 84, and with it faster than before, 114 and 98) and BATTERING HORNS (the Mother's stage 3: Brutes x3.5 against buildings, walls and gates, was x2.5). VENOM SIRE: SLITHER (Spitters and Venom Challengers about 15% faster) and LONG SPIT (about 20% more range: a Spitter 205, a Venom Challenger 215). STORM SIRE: UPDRAFT (flyers about 15% faster while flying) and BIGGER CLUTCH for the Hatchlings (coming). THE MOTHER (stage 2): QUICK ROOTS (every creature roots and uproots in half the time) and SWAMP MENDING (on your swamp, out of the fight, creatures heal more).",
		"TARGETS: Spitters no longer shoot flyers (the Venom Challenger, the Venom Sire and the Skywing still do).",
		"The computer's Brood researches too: BIGGER CLUTCH early, PACK HUNT before an attack, BATTERING HORNS before a siege, QUICK ROOTS mid game, one Sire at a time so its army keeps coming.",
		"The research buttons have stand-in icons (the creature with a badge) until the designer's drawings come.",
	]},
	{"v": "0.19.0", "items": [
		"THE SIRE LURES: a grub no longer turns into a grown Sire. Picked on a grub's BUILD card, it roots and swells into the Sire's LURE, a living pheromone gland (the Tyrant's red and spiked, the Venom's yellow-green, the Storm's with a crest-fin in a blue haze). When it is ripe the Sire arrives, eats it and nests on its spot. The same cost and time as before, one Sire of each kind (a lure counts as its Sire), and the computer makes its Sires the same way.",
		"A lure is rooted and can be attacked: killed before the Sire comes, it is lost (no refund) and another can grow at once. Its card reads Tyrant, Venom or Storm Lure and its bar LURE RIPENING, then THE SIRE ARRIVES; his roar is the cue.",
		"THE SIRES' EGGS IN FRONT: the eggs a Sire fertilises now lie in a row just in front of his nest, seen at once and drawn on top (as the Brood Mother's), reddening under his breath and hatching there, while he keeps his fertilising animation.",
		"ART: the designer's lure and arrival sheets for the three Sires: the grub swelling into the lure, the ripe lure pulsing in its haze, and each Sire's 12-frame arrival.",
	]},
	{"v": "0.18.2", "items": [
		"THE VENOM LINE'S NEW COLOURS: the Spitter, the Venom Challenger and the Venom Sire keep their olive scales and wear the team colour on their spikes and frill (as the rest of the Brood), on their belly (throat, chest, belly and the underside of the tail) and on a stripe of scales along the middle of each flank. The whole body in the team colour was too much.",
	]},
	{"v": "0.18.1", "items": [
		"THE SPITTER'S NEW LOOK: the Venom line's young, redrawn: a small lizard with only a tiny ruff, walking, spitting and dying in every direction (it had side views only). The ruff opens and the mouth gapes before each spit, and its glob of venom now flies as a straight, comet-like shot.",
		"THE VENOM CHALLENGER'S OWN PICTURES: walking, spitting (its frill spreads wide) and dying in every direction, no longer the Venom Sire drawn smaller; its glob flies as its own straight shot too. The line reads small, medium, big: the Spitter, the Venom Challenger, the Venom Sire.",
		"THE MIST TOAD keeps its own colours again, its details in the team colour (as before 0.18.0); only the Spitter, the Venom Challenger and the Venom Sire wear their scales in the team colour.",
	]},
	{"v": "0.18.0", "items": [
		"THE BROOD IS NOW THE BROOD OF CREATURES: the experiment's Brood (the Brood Mother, the fathers, rooting) replaces the old one everywhere a faction is picked, and the \"(new, experiment)\" entry is gone. The old Brood's buildings (Burrow, Warren, Broodmound, Clutch Mound, Feeding Pit, Gorge Pit, Brood Pen, Roost), its Spore Mother and Bloater, its swamp and its old computer are removed.",
		"OLD SAVES AND REPLAYS: a saved match or a replay with the old Brood in it can no longer be continued or watched; the game says so instead of failing. Ones with the experiment's Brood still work.",
		"THE VENOM LINE'S COLOURS: the Spitter, the Venom Challenger, the Venom Sire and the Mist Toad now wear their scales in the team colour and their spikes and frill in olive; the venom keeps its yellow-green glow.",
		"The Crown's and the Clockwork's computers scout the Brood of creatures: the Brood Mother counts as its hall, rooted Rootmaws as its economy, the fathers as its tech.",
	]},
	{"v": "0.17.0", "items": [
		"THE NEW BROOD (EXPERIMENT): YOUNG AND MATURE. The Brood Mother lays only the young; from her stage 2 a young warrior MATURES into a CHALLENGER, a young Sire: MATURE on its card (on a group, each as far as the food allows). It pays the Challenger's price less its own share of its egg, MOULTS 9 s where it stands (it cannot move or fight; a shimmer for now), then it is the Challenger, its veterancy and wounds kept. A Raptor grows into a TYRANT CHALLENGER (a medium all-round biter between the Raptor and the Brute: 130 health, armour 1, 15 a bite; 75 food and 10 spoils to mature). A Spitter grows into a VENOM CHALLENGER (a heavier glob a little farther, 180, that splashes a little and strips armour, flyers too: 220 health, armour 1, slower; 105 food and 17 spoils). The computer matures its young when food piles up.",
		"THE TIERS: the Spitter is now the Venom Sire's young, laid from the start (stage 1); the Challengers come at stage 2; the Brute and the Mist Toad stay at stage 3.",
		"THE BROOD MOTHER'S STAGES: she has her own pictures at stage 2 and stage 3 (walking, her swipe, her death, rooting, her nest, laying), bigger and more terrible at each stage. The other walking views borrow her stage-1 frames for now.",
		"FIX: a unit on ATTACK-MOVE whose way ends at an enemy wall or gate short of its goal now breaks the piece in the way, instead of sometimes stopping there.",
	]},
	{"v": "0.16.3", "items": [
		"THE MIST TOAD'S TONGUE no longer pulls a Field Cannon or a Mortar: it only staggers them, and every stagger now lasts 2.5 s (was 1 s; the Brood Mother and the Sires too). The Crown keeps its guns, but must kill the marked Toad by hand.",
	]},
	{"v": "0.16.2", "items": [
		"SPOILS: the Brood's second resource is now called SPOILS (it was essence): spoils of war, from any body or wreck, flesh or metal, and from SACRIFICE. The top bar, costs and refusals (\"Not enough spoils.\", also spoken), help pages, harvest and sacrifice texts, floating numbers and the match log say it, for the old and the new Brood. Nothing else changes.",
	]},
	{"v": "0.16.1", "items": [
		"THE VENOM SIRE'S PICTURES: the pictures that go with 0.16.0's numbers (his frames lined up on his feet, not on the venom's lowest drop, so he no longer floats over his shadow while he spits). 0.16.0 shipped with the previous cut.",
	]},
	{"v": "0.16.0", "items": [
		"THE NEW BROOD (EXPERIMENT): THREE FATHERS, the SIRES, each fathering his own line, and TIERS by the Brood Mother's growth stage. The TYRANT SIRE (the Tyrannosaur) and the VENOM SIRE (a lean Dilophosaurus) are open from the start; the STORM SIRE (a Pterodactyl) at her stage 2. Her warriors: Raptors (Tyrant) from the start; Spitters (Venom) at stage 2; Brutes (Tyrant), Mist Toads (Venom) and Skywings (Storm) at stage 3. One of each Sire at a time, each made from a grub (its BUILD menu); anything locked is greyed with the reason, \"Needs the Brood Mother at stage 2\". The Bloater is out of the new Brood (more units come later).",
		"THE MOTHER'S CARD offers every line; a warrior's egg is laid only with ITS father rooted beside her, and the refusal names him (\"Needs the Venom Sire rooted beside the Brood Mother\"). Each line's eggs roll into their own father's nest, where he fertilises them all at once and they hatch. Each father near her adds +20% to her laying: all three, +60%. The father range ring shows for whichever father is selected or being placed. The Mist Toad's TONGUE only staggers every father.",
		"THE VENOM SIRE roots on a smaller nest (3x3) and, uprooted, SPITS venom from afar like a strong Spitter (acid that strips armour, flyers too): 650 health, 150 food (no essence: he is a first-tier Sire), 30 s. THE STORM SIRE FLIES while uprooted (over cliffs and water) and DIVES to bite ground and air units: 700 health, 200 food and 50 essence, 40 s. ROOT: he lands on a nest (4x3) beside her and is then a ground creature that anything can hit; UPROOT: he takes off again.",
		"THE COMPUTER raises both the Tyrant and the Venom Sire early, saves food (and grubs harvest bodies or a spare one is offered up for essence) to grow its Brood Mother to stages 2 and 3 for Spitters, Brutes and Mist Toads, makes the Storm Sire at stage 2, nests them beside her and lays a mix of each line as her stage allows: Raptors, Spitters behind them, some Brutes, a Mist Toad or two (which cast FOG and TONGUE), Skywings against flyers.",
		"ART: the designer's own drawings for both new fathers in every direction: walks and spits, flights and dives, landing, fertilising, take-off and death, and their portraits.",
		"FIX: a rooting creature that has got up (a Rootmaw, a Mound Turtle, a Sire; the Brood Mother still keeps to her leash) now chases the enemy it is told to attack, instead of standing still when it is out of reach.",
	]},
	{"v": "0.15.26", "items": [
		"THE BRUTE IS BIGGER: every picture of the Brute (standing, walking, the charge, the attack and the death, in every direction) is drawn 20% bigger, its feet on the same spot, and its body is wider to match (radius 20 -> 24): the selection ring, the health bar and its room on the ground grow with it. It still fits through a one-tile gap, such as the hole a broken Gate leaves. Old and new Brood.",
		"THE BRUTE BREAKS WALLS: its damage against buildings goes from x1.6 to x2.5, the Field Cannon's own bonus. Five blows break a Gate or a palisade piece: one Brute breaks the Crown's ramp Gate in about 10 s of hitting (16 s before), four in about 2.5 s. It is now the Brood's wall-breaker, faster than the same price in Raptors; it still has to walk up to the wall under the defenders' fire. Old and new Brood.",
		"THE SPITTER REACHES FURTHER: its range goes from 150 to 170 (a Musketeer's is 190). Old and new Brood.",
	]},
	{"v": "0.15.25", "items": [
		"THE NEW BROOD (EXPERIMENT): SPITTERS join it. The Tyrannosaur fathers them (until a Spitter father of their own), on the Brood Mother's card with the grub, Raptor, Brute and Mist Toad; the retired Spore Mother is gone from it. The computer lays about one Spitter for every three Raptors.",
	]},
	{"v": "0.15.24", "items": [
		"THE STUN MARK: a stunned unit shows a little ring of stars spinning over its head while the stun lasts, for everyone who can see it (online and in replays too). It fades in fast and fades out over the stun's last 0.2 s, and the unit card says STUNNED with the seconds left. Only real stuns show it: a Mist Toad's tongue (a pulled unit 0.9 s, a staggered one 1 s) and a Cavalry charge's knock (0.6 s). A heavy unit's short charge knock (0.24 s) shows none, nor does a run-down construct; a unit caught in a Netter's net shows its net, not stars.",
		"THE MIST TOAD'S TONGUE: it can now tongue FLYING units too. A pulled flyer is dragged through the air to just over the Toad and stays in the air; the crosshair, the 3 s windup and the ways to break it work as on the ground. Heavy flyers are only staggered, like heavy ground units. The computer's Toads go for Balloons, Ornithopters and Skywings too.",
		"THE MIST TOAD'S TONGUE can never pull the Brood Mother or a father (the Tyrannosaur): they are only staggered, stunned 1 s with the stun mark. The Field Cannon is still pulled for now.",
	]},
	{"v": "0.15.23", "items": [
		"EXPANSION SPOTS: a spot disappears as soon as a hall, any building, or a rooted Mound Turtle or Brood Mother touches its tinted tiles, and stays while they are completely off it. Every shown spot reads \"OPTIMAL EXPANSION SPOT\".",
	]},
	{"v": "0.15.22", "items": [
		"THE DISMOUNTED CUIRASSIER, ALL NEW: his sword attack and his death are now the designer's new drawings too, in every direction. From his guard he raises the sword, swings it down, the blow lands on the slash (a white trail), he follows through and comes back to guard; when he falls he staggers, drops his sword, sinks to his knees and lies still with his helmet off beside him, and that is the body that stays. The blow and its damage now come exactly on the slash frame, in a match, in the ANIMATION VIEWER and in the Barracks drill.",
		"THE DISMOUNTED CUIRASSIER IS BIGGER: every picture of him on foot (standing, walking, aiming, firing, the sword and the death) is drawn about 10% bigger, as tall as the old drawing was with its plume, so he no longer looks smaller than the Musketeer. His pistol smoke starts at his raised hand, in a match and at the Barracks.",
	]},
	{"v": "0.15.21", "items": [
		"TWO NEW STAT ICONS on the unit card, from the designer's sheet: BONUS VS LIGHT (a sword striking a cloth tunic, on the Pendulum) and DAMAGE A SECOND (an hourglass with a blood drop), which takes the place of the letters DPS.",
		"THE DISMOUNTED CUIRASSIER, NEW ART: in every direction, the Armoured Officer on foot is the designer's new drawing, made to match the mounted Cuirassier: steel helmet and breastplate, white sleeves, sash and breeches in the team colour, the same size in every view. He stands with 4 frames, walks with 6 (at the same pace as before), and his pistol shot raises the pistol, aims, fires with a flash as the ball leaves, then lowers it; the smoke of an Officer's shot on foot now comes from his hand, not his feet. His sabre and his fall are the old drawing until they are redrawn.",
	]},
	{"v": "0.15.20", "items": [
		"THE MIST TOAD HOPS: it no longer walks, it hops in every direction (front, back, sides and diagonals), the designer's own drawings: a crouch, the push off, high in the air over its shadow, then it lands with a small splash. One hop for every stretch of ground it covers, so its feet never slide; its spell casting, tongue, idle and death are as before.",
	]},
	{"v": "0.15.19", "items": [
		"WORKER LABELS SAY WHOSE THEY ARE: the count over each economy building has its job word: HAULERS on a Town Hall, FARMERS on a Farm, POWDER MAKERS on a Powder Mill, WINDERS on a Cog Press and a Mainspring, GRUBS on a Feeding Pit, a Rootmaw and a food pile. Rest the mouse on it for half a second (a long press on a phone) and a tooltip says what those workers do, with the real numbers: gold a minute for each farmer, powder a minute for each powder maker, cogs and Tension for each Winder and what the % means (crew x drive x brass), food a trip and a minute for each grub. A click on a label still selects the building.",
		"HAULERS: the Town Hall's label now reads assigned / needed. The second number is how many haulers the base can use: 1 for each Horse Breeder, and for each Powder Wagon on SUPPLY that is being drawn from, its kegs a second x the walk from the Mill and back (a far wagon under heavy fire needs a long line of haulers), up to 6 a hall. It is worked out every few seconds and does not flicker. White below the need, green at it, orange over it (Labourers who could be farming). Its tooltip says how many are free and what the need is made of. The computer assigns haulers up to the need.",
		"KEGS GO BY THE NEED: there is no longer a limit of 2 kegs on the way to one wagon, nor of its room. As many haulers carry kegs to a wagon as its recent powder use calls for. A hauler who finds it full waits by it, keg in hand, follows it as it moves, and hands the keg over as soon as there is room, first come first served (his card says so). A full wagon nobody draws from pulls no kegs.",
		"DROPPED KEGS: a keg never goes back into the stores. A hauler who cannot deliver it (the wagon destroyed, ordered away, his job cut short) sets it down where he stands. On the ground it is a powder supply: your soldiers nearby refill from it as from a wagon until it is empty. It is also a bomb: enemies shoot it and it blows up, scaled by the powder left. A free hauler picks it up and delivers it before fetching a new keg from the Mill. A hauler killed with a keg on his back still blows up. Saves, replays and online games keep the kegs.",
	]},
	{"v": "0.15.18", "items": [
		"THE NEW BROOD (EXPERIMENT), from the designer's screenshot: a rooted creature's picture now sits on its footprint like a building on its tiles: the bottom of the Brood Mother's nest (at every growth stage), the Rootmaw, the Mound Turtle's mud and the Tyrannosaur's nest touch the bottom edge of their green rectangle, sliding down smoothly as they root (no jump), and the selection rectangle and the pointer's corners are drawn under the creature, not across it. The eggs she lays in her nest and the Tyrannosaur's nest eggs moved with the pictures, and the FATHER RANGE label sits at the bottom of its ring, off her body.",
	]},
	{"v": "0.15.17", "items": [
		"THE NEW BROOD (EXPERIMENT): a father fertilises ALL the warrior eggs in his nest at once, not one at a time: a queue of 10 Raptor eggs is fathered together and hatches together. The same for every father.",
	]},
	{"v": "0.15.16", "items": [
		"THE NEW BROOD (EXPERIMENT), from the designer's playtest: a grub keeps BUILD (B) like every worker; its build menu has the Rootmaw, the Mound Turtle and the Tyrannosaur, then the ROOT ghost. The grub's card, its tooltips and every text a new-Brood player sees now speak of the Rootmaws and the Brood Mother, not the old Brood's buildings (in Portuguese and Spanish too, with the labels that were still in English).",
		"EXPANSION SPOTS SAY SO: \"OPTIMAL EXPANSION SPOT\" on the best gold spot and \"EXPANSION SPOT\" on the next, small on the ground, when zoomed in and while placing a hall, for every faction that shows them. The new Brood sees them too: its best spots for a Mound Turtle on fresh ground, 15 tiles or more from the Mother, with room for Rootmaws.",
		"THE BROOD MOTHER: her laying in the nest lasts about 3 seconds (she still lays as fast); her eggs go to the nearest empty spot round her, never hidden under a creature rooted beside her, and when she is boxed in they are laid on top of her creatures; hatchlings walk out through their own side's rooted creatures (enemies still can't). A click anywhere on her drawn body selects her (and the other rooted creatures the same way). While she grows, a bar over her and on her card shows it, with STOP GROWING.",
		"A rooted Rootmaw and a food pile show their grubs at work and the most they take (\"4/6\"), like the Crown's farms, and a Rootmaw warns when its ground runs low. The Tyrannosaur keeps his fertilising animation until the last warrior egg in his nest has hatched. Cocoons, rooting and uprooting, eggs and his nest show their progress on the card. The Mound Turtle costs 100 (was 150): with the grub it uses up, 150 for 12 supply, the same as the Crown's Cottage.",
	]},
	{"v": "0.15.15", "items": [
		"UNIT STATS ON THE CARD: the selected unit's card has a row of icons with its numbers: the attack (damage a hit, melee, ranged or area), the time between attacks, damage a second, range in tiles, bonuses (against armour, buildings, light units, flyers), whether it hits flyers, then armour, health, speed, sight and supply, and the names of its special attacks. Every number is the one it has now (veterancy, research, refits, wind, rooted...); hover over a chip, or tap it on a phone, for the full explanation and the trained value. Works for every unit of all factions.",
		"The new Brood's Rootmaw, Mound Turtle, Tyrannosaur and Brood Mother show their bite when uprooted; rooted, the row says ROOTED (they cannot attack) and shows the extra armour. The icons are the owner's ChatGPT drawings.",
	]},
	{"v": "0.15.14", "items": [
		"THE NEW BROOD (EXPERIMENT): A ROOTED CREATURE IS A BUILDING. Rooted, the Brood Mother, a Rootmaw, a Mound Turtle and the Tyrannosaur take a building's footprint on the ground (paths go round it, units standing there are pushed out), are drawn under the units round them, and have a building's card: no move, attack, stop or hold, only their own commands and RALLY. A right-click on the ground sets their rally point and never gets them up: only UPROOT does. Idle, they hold still; they move only while they work.",
		"GRUBS TURN INTO THE ROOTMAW, THE MOUND TURTLE AND THE TYRANNOSAUR: pick one on a grub's card (no old Brood buildings there any more) and place it like a building. The grub walks there, pays and morphs in a cocoon that opens rooted. The Brood Mother lays only grubs and warriors now.",
		"ROOT WORKS LIKE BUILD: a ghost on the grid shows where it will root, green or red with the reason (no swamp, another Rootmaw's ground, a cliff, out of the father range...); the creature walks there and roots on that spot. While a Tyrannosaur is picked or placed, and while the Mother is picked, a ring round her shows the father range.",
		"EGGS: a picked egg's card shows what it will hatch and when (or that it waits for the father). Her eggs take the Mother's rally point, a right-click gives an egg its own, and the warriors hatching in the Tyrannosaur's nest go to his.",
		"The computer's Brood Mother no longer gets up and roots again over and over when shot at from range: she stays up while enemies are near and roots only after a real calm.",
	]},
	{"v": "0.15.13", "items": [
		"THE NEW BROOD (EXPERIMENT): THE BROOD MOTHER GROWS. GROW on her card (rooted; she lays no eggs meanwhile): stage 2 for 300 food and 45 s holds 15 eggs and lays 30% faster; stage 3 for 500 food, 75 essence and 60 s holds 20 and lays 70% faster. She gets bigger and slower, with a wider swamp. Uprooting stops it and pays it back.",
		"THREE LEVERS RAISE HER LAYING, AND THEY STACK: her stage; every father near her (+20%: his pheromones); and every Mound Turtle rooted on new ground, 15 tiles or more from her and from the other counted ones (+15%, up to 3). Turtles at home now give supply and swamp only. Her card shows what is working.",
		"The computer grows its Mother when food piles up.",
	]},
	{"v": "0.15.12", "items": [
		"THE NEW BROOD (EXPERIMENT): the Tyrannosaur ROOTS. Rooted on his nest near the Brood Mother he is the Brood's barracks: her warrior eggs go into his nest (counted over him like a training queue), he breathes on them one at a time and they hatch there. Rooted he takes less damage; uprooted he walks and fights as before. His breath is drawn in his picture now: the orange puffs are gone.",
		"EVERY ROOTED CREATURE MOVES (a rooted creature is a building): the Tyrannosaur breathes fire on his nest, the Rootmaw breathes at each stage of its filling (the designer's drawings), and the food, the eggs and the fire glow and pulse.",
		"THE BROOD MOTHER LAYS IN HER NEST: rooted, she rears up and lays the egg in front of her clutch, and it rolls out to the nest's rim (walking, it still drops behind her).",
		"NO ROOTED CREATURE ATTACKS: rooted means building, for the Brood Mother, the Rootmaw, the Mound Turtle and the Tyrannosaur alike; to fight they must uproot. A rooted turtle on a ramp still closes it. The computer gets the Tyrannosaur up to fight off an attack at the Mother, and the Mother herself when enemies reach her, and roots them again after.",
		"SACRIFICE gives the Brood Mother 1 egg at once, on top of the essence (none if her clutch is full).",
	]},
	{"v": "0.15.11", "items": [
		"THE NEW BROOD (EXPERIMENT), fixes found by playing ten games with it (docs/brood_new_play.md): a rooted Brood Mother no longer slides across the ground as her own eggs push her (in ten minutes she could drift nine tiles, her swamp with her, and leave her first Rootmaw dry), and she no longer uproots and walks off by herself after swiping at a scout.",
		"No more creatures stuck by the Mother: eggs and food piles no longer shove anything, a creature pressed against the rooted Mother or the Tyrannosaur standing at her eggs steps round them, a walking Mound Turtle is too heavy for the grubs to wash back, and your own creatures climb over your rooted Mound Turtles as they should. A grub whose Rootmaw died no longer freezes.",
		"The computer's new Brood no longer sends a Rootmaw, a Mound Turtle or the Tyrannosaur to a spot off the edge of the map, where it stood for good.",
	]},
	{"v": "0.15.10", "items": [
		"THE NEW BROOD (EXPERIMENT): the Mound Turtle has its own pictures now (the designer's): it walks, sinks into the mud as it roots, breathes there rooted, rises and dies, and walks in every direction with the designer's drawings; its card has its own portrait.",
		"SIZES: the Brood Mother is bigger, as wide in her nest as a Clocktower's gear ring, and the Tyrannosaur as big as a Barracks.",
		"FERTILISING READS AT A GLANCE: the Tyrannosaur's red-gold breath is a thick stream now, and the egg he breathes on turns red as he does it. A rooted Brood Mother's eggs roll out in front of her nest, where you can see them, instead of under her body.",
	]},
	{"v": "0.15.9", "items": [
		"THE NEW BROOD (EXPERIMENT): pick \"The Brood (new, experiment)\" in the skirmish setup. The Brood as the designer is redrawing it: no buildings, only creatures, some of which ROOT into the ground (more armour and less damage while rooted). The old Brood stays as it is and is still the default.",
		"THE BROOD MOTHER: kill her and that side is out. She roots and uproots, hoards the food the grubs bring her, and only she lays eggs, rooted or walking: pick a creature on her card and its egg drops behind her, then hatches. Rooted, she spreads swamp round her, heals, and is the base's defence: alone she beats an early all-in of Raptors, Horsemen, Musketeers or Clock Soldiers. SACRIFICE happens at her: she devours the creature offered up.",
		"THE ROOTMAW, a swamp lizard, is the Feeding Pit: it roots on fresh ground on your swamp (3,000 food in a 5-tile circle) and drinks it into its body, swelling as it fills; grubs take the food at its flank (their new harvesting animation) and carry it to the Mother, the farther the better. UPROOT spills its food as a pile that grubs can still collect (it rots); HAUL walks off with it, slow and fat, and it bursts if killed.",
		"THE MOUND TURTLE is the Clutch Mound: rooted it sinks into the mud, gives 12 supply, makes the Mother lay faster and spreads swamp, so it is how the Brood expands (Rootmaws root on any of your swamp, even far from home). It is a tank, and rooted on a ramp it closes it like a wall. Its pictures are stand-ins for now.",
		"THE TYRANNOSAUR is the father of the ground warriors: standing near the Mother he breathes a red-gold mist on her warrior eggs to fertilise them (Raptors, Brutes, Spore Mothers, Mist Toads). One at a time; an egg he doesn't reach in time hatches as a grub. Spitters and flyers wait for their own fathers. The computer can play the new Brood with a simple plan. docs/brood_new.md has the numbers.",
	]},
	{"v": "0.15.8", "items": [
		"BIG BATTLES RUN ABOUT TWICE AS FAST (the owner's question: 200 Raptors a side, docs/swarm_perf.md). In a melee of 400 Raptors the game's own work each tick is about half what it was, and the longest frames are a third as long. A unit looking for a target now looks only at enemies, nearest first; units pushing each other apart skip the ones too far away; the unit's tick asks less. The game plays out exactly the same as before.",
		"Fewer stutters in a big match: the replay's pictures and the 15-second autosave (now written a little each frame) no longer land on the same frame as a game tick, and with a hundred soldiers selected the command card takes under 2 ms instead of 14 (the MOUNT and LEAD buttons asked every man for the nearest horse).",
		"In a big battle on screen (more than about 160 units in view) the units' pictures change 10 times a second instead of 15, and a unit's sprite no longer flicks between two facings when it turns by a hair (the Labourer's rule, now for every unit). Only the drawing changes.",
	]},
	{"v": "0.15.7", "items": [
		"COMPUTER EXPANSIONS (Crown and Clockwork): a computer no longer lays a Town Hall or Clocktower on the enemy's side of the map. It now measures the walk over land, cliffs included, instead of a straight line; with no free site left on its own side, it does not expand at all. It also uses the rated expansion sites, the gold-marked best ones first. On Hollowfen, Saltmarsh Isles and Cinder Steps the natural touches a ramp, so the computer could not build there and went 40 tiles out; now it builds right beside it.",
		"CLOCKWORK COMPUTER KEEPS ATTACKING: after it pulls a wave back, the higher bar for its next wave lasts three minutes only. An army at the supply cap, or worth three times the biggest enemy army it saw lately, goes out again. A few unarmed enemies near its buildings no longer keep its whole army at home: its detachments deal with them.",
		"CROWN COMPUTER: against the Clockwork it opens with Musketeers, not the Horseman rush (unless its plan is Rush). It keeps a spot on its main's high ground for the Armoury and the Foundry. It expands sooner (a hall under 40% soil counts as tired), sends farmers to fresh soil, and waits when a bigger enemy army stands by the spot. A Labourer goes back to a Town Hall site its builders left. Once its soil runs low it keeps a Town Hall's gold in the bank.",
	]},
	{"v": "0.15.6", "items": [
		"SIDEWAYS RAMPS: a ramp that runs east-west no longer has slanted lines across its planks along the rails. Its rails now cast an even shadow band along each side, and a soft shadow lies across its high end, where it leaves the plateau, fading downhill. North-south ramps are unchanged. Only the drawing changed.",
	]},
	{"v": "0.15.5", "items": [
		"CLIFF SIDES: the east and west edges of high ground now have a visible side wall, a narrow strip of the same rock as the south walls, with the high ground's lip along its top edge. West-facing walls are a little lit; east-facing walls are in shadow and cast a slightly deeper shadow on the ground beside them. A sideways ramp now clearly climbs a cliff instead of seeming to lead onto flat ground. Only the drawing changed: the ground, paths and building spots are the same.",
	]},
	{"v": "0.15.4", "items": [
		"RAMPS, AS THE OWNER DREW THEM: the cliff edge now runs straight up to both sides of every ramp, at its own row: no tile sticks out and none is pulled back beside the planks. The ramps themselves are the same cells as before.",
		"RAMP RAILS: a low stone kerb runs down both sides of every ramp, from the cliff to the row above its bottom one. No unit can cross it, so you get onto a ramp only straight on at its top or its bottom, or from the side onto its bottom row. The ground beside a ramp is normal ground again: the invisible block of 0.15.3 is gone, and units can walk and stand at the foot of the cliff. Paths, group moves, pushing and knockback all keep to the rails, on every map, the editor's too.",
	]},
	{"v": "0.15.3", "items": [
		"RAMPS, AS THE OWNER WANTS THEM: the cliff walls added beside the ramps in 0.15.2 are gone, and the map looks exactly as in 0.15.1 again, with no extra tiles. Instead, the cells beside a ramp's top two rows, under or against the drawn cliff wall, are an invisible block: nothing can walk, stand or be built there, so no unit stands on the drawn wall and looks as if it floats. The ramp keeps its three lanes, and units on it go straight up and down the planks.",
		"RAMPS DRAWN MORE CLEARLY: the planks are a little darker, with stronger steps; a stone kerb runs down both sides; the walls cast a shadow on the planks, deepest at the top; and a shadow line marks where the planks leave the high ground. A ramp now reads as a narrow way through with walls on both sides.",
	]},
	{"v": "0.15.2", "items": [
		"RAMPS ARE FUNNELS: beside the top two rows of every ramp, the ground is now cliff. The cliff wall steps down beside the planks, and nothing can stand there or be built there, so a unit no longer stands on the drawn wall beside a ramp and looks as if it floats. The only way between the high ground and the low ground is the ramp itself, exactly as wide as its planks. Units on the high ground stop at the edge; units below stop at the foot of the wall. This holds on every map: the built-in ones, generated ones, and maps made in the editor. A computer's ramp wall still takes three pieces.",
	]},
	{"v": "0.15.1", "items": [
		"GREAT WINDER IN A CROWD: when soldiers stand round a wreck so the big machine cannot roll right over it, it now sweeps it from the edge of the crowd after a second, instead of pushing at them for good (the computer's Great Winder sometimes never swept a soldier that fell in the middle of its army). If it cannot get near at all for 6 seconds, it leaves that wreck for 10 seconds and sweeps another.",
	]},
	{"v": "0.15.0", "items": [
		"BIGGER MAPS: every built-in map is larger, about 1.3 times on each side (1.75 times the ground). The classic maps (Greenhold, Highmoor, Dune Sea, Frostfang, Twin Fords, Ashfall, Mirewood, Border March, Red Coast) go from 84 x 60 to 110 x 80: the walk from main to main is about 110 tiles, close to a minute for a Musketeer. The team maps grow by the same factor; the 1v1 maps that already had a long walk grow a little less (Saltmarsh Isles, Frostmere, Hollowfen, Thornwood Maze, Ashford Crossing, Amberfall Vale). Ramps, rivers and tree walls keep their width; the main plateaus are a little bigger.",
		"MORE BASES: every map has more base sites, the same for every player (the maps are still turned through their middle). Each side's natural sits close to its main, in front of its ramp; then 3 or 4 more sites per side in corners, beside ponds and lakes and in pockets. On Greenhold (the owner's drawing): the natural moved up to the foot of the main's ramp, a new site in the bottom-left corner and one just right of the bottom-left pond, plus one along the top and one on the open ground below it. With 4 players the classic maps have two sites per corner. Each site has a hall's full reserves, for the Crown and the Clockwork.",
		"Replays and a saved match of a built-in map from before 0.15.0 can't be shown or resumed (they were played on the old, smaller map). Your own maps keep their size; a new map in the editor starts at 110 x 80, and the editor's sizes go up to 256 x 256.",
	]},
	{"v": "0.14.104", "items": [
		"TURNING GEARS (an EXPERIMENT, the owner's idea, on by default for now): only the outer toothed band of a Clockwork building's gear ring turns; the plate in the middle stays still. Any ground unit standing on a turning band is carried round with the teeth, about a tile a second, and meshed rings turn opposite ways. A unit that stays on the band keeps going round: idle units and units on HOLD ride until you move them off. A unit walking across drifts sideways for the time it is on the band and still gets where it was sent.",
		"Workers at work (Winders going to a press, a building site, a repair) walk straight in across the band and are never carried. Flyers, limbered guns and the big machines (Field Cannon, Spring Ballista, Great Winder) are not carried either. The computer walks its own idle and HOLD units off a band after a second. A carried unit kicks up a little dust; point at a band, or open the GEAR VIEW, to see gold chevrons running the way it turns.",
		"To switch it off: Settings > TURNING GEARS (experiment) > OFF. It applies from the next match: a match keeps the rule it started with, and an online game and a replay follow the host's.",
	]},
	{"v": "0.14.103", "items": [
		"GREAT WINDER SWEEPS WRECKS INTO COGS (the owner's rule: each side gets something different from bodies; the Brood essence, the Crown raises its own, the Clockwork regains cogs). Standing idle, it rolls to a Clockwork wreck near it (yours, and the enemy's in a Clockwork mirror match), sweeps it up with its rollers and gives you 30% of that unit's cog price at once (\"+21 cogs\" for a Clock Soldier; no Tension back), then rolls back to where it stood, so it stays with the army. It leaves a wreck alone while an enemy soldier is near it. No more parts: the hopper, the 100 cap and the planned reassembly are gone. Its winding ring and MEND are unchanged, and the computer's Great Winder sweeps the same way. Old saves still load.",
	]},
	{"v": "0.14.102", "items": [
		"The game is now called Working Title for RTS for the time being (the old name belongs to another game). Your settings, saves, replays and hotkeys carry over; the web address and the Android app file keep their old names for now, and the app installs over the old one.",
	]},
	{"v": "0.14.101", "items": [
		"NEW COG PRESS ART (the owner's drawing): the Cog Press is now an open iron gantry press facing south-east, a stamping ram inside the frame and a crate of fresh cogs at its feet, so it no longer looks like the Mainspring. Its red bars take your side's colour. While Winders wind it, the ram falls fast onto the cog in its tray, holds for the stamp and climbs back slowly (a 12-frame loop). New pictures for the press being built (on scaffolding), damaged and destroyed, and a new portrait.",
		"COG PRESS STAMP: a quiet, heavy stamp sounds as the ram hits the cog (cut from the owner's two stamp recordings, pitched down with a little iron under it). Only presses you can see are heard, on every other stroke, and a row of presses never drums: at most one stamp in 0.7 s.",
	]},
	{"v": "0.14.100", "items": [
		"CLOCKWORK COMPUTER against Horsemen: the Winders near a raided Cog Press, Mainspring or Clocktower band together and all hit the same rider instead of scattering (riders are faster than them: running only fed them one by one), the nearest Clock Soldiers come as one group to the Winders instead of chasing a rider, and once it has seen riders and has 10 or more Clock Soldiers at home, 3 or 4 of them stand on HOLD at the top of its ramp. Against Balloons, and armies they cannot fight, the Winders still run.",
	]},
	{"v": "0.14.99", "items": [
		"BLACK POWDER SMOKE: every powder shot now leaves its smoke on the field. A Musketeer's or Guardsman's musket (a Dragoon's too, once off his horse), a Horseman's pistol, a Field Cannon (round shot and canister), a Mortar and its bursting shell, a keg or a Powder Wagon going up: each leaves grey-white puffs that drift slowly on a light wind, grow, thin and fade over 10 to 24 seconds (a cannon's last longest). A long firefight builds a haze over the firing lines that clears slowly afterwards. It is only for the look: it hides nothing and changes nothing in the fight, the units stay visible in it, and their health bars, rings and orders are drawn over it. You see it only where your side sees the ground. The Clockwork and the Brood fire no powder.",
		"POWDER SMOKE in Settings: OFF, LIGHT, FULL or THICK (experiment). LIGHT has fewer puffs with shorter lives. It applies from the next match.",
		"THICK (an EXPERIMENT, the owner's, and the default for now on every platform): the smoke is drawn OVER everything on the field, the units, their health bars, the selection rings and the order lines (still under the interface, the minimap and the menus), a third denser and lasting a quarter longer than FULL. It is meant to be a bit annoying, as a real powder battle was. It is still only for the look: it hides nothing from your side's sight and changes nothing in the fight. To go back: Settings > POWDER SMOKE > FULL (a choice you made before is kept).",
	]},
	{"v": "0.14.98", "items": [
		"TAKING THE REINS has its own moment now: a man told to LEAD a horse stops at its head for half a second and reaches for the bridle, the horse stops and turns its head to him, the rein appears, and then they walk off together (a pause at each horse when he fetches several). The rein is easier to see: tan leather with a dark edge. Mounting is unchanged: a soldier right-clicked on a horse still gets on it; LEAD (Q) is how a soldier leads one. Labourers lead on a right-click.",
	]},
	{"v": "0.14.97", "items": [
		"CLOCKWORK GEAR RULES (the owner's, from the gear study): each RATCHET TURRET now claims a circle of ground 4 tiles round it, and two turrets' circles may not overlap: a turret's spring draws all the force from the gears under it, so turrets stand at least 8 tiles apart. While you place one, the circles are drawn and the ghost says TOO NEAR A TURRET. Old saves keep the turrets they have.",
		"NEW CLOCKWORK BUILDING, the HEAVY WORKS (175 cogs, 45 s, needs a working Escapement): a gantry crane yard where the PENDULUM, the SPRING BALLISTA and the GREAT WINDER are now made, and you can watch each machine rise in its bay as it trains. It sits on its BIG gear only and uses Tension, so its ring must mesh with a Mainspring's (else NEEDS MAINSPRING).",
		"The LIGHT WORKS now makes only the light machines: the Clock Soldier, the Springer and the Netter (no more Pendulums, Ballistas or Great Winders).",
		"SIZE SETS THE TEMPO: a small gear works fast and light, a big gear slow and strong. The Light Works trains 15% faster on its small gear, 15% slower on its big one; the Escapement and the Clock Aviary work 10% faster or slower. A Ratchet Turret on its small gear fires 11 damage every 1.2 s; on its big gear 21 every 2.2 s, better against armour, with the same reach. Each card says its gear's trade in one line.",
		"READABILITY: the Mainspring, the Escapement, the Heavy Works and the Clock Aviary stand on a polished brass floor plate; a small spring mark shows a building fed by a Mainspring; the placing ghost lights its meshing teeth green and its clashes red and gives its reason in one red line; the GEAR VIEW (the ` key, or GEAR VIEW on a Clockwork building's card) shows the whole network: the drivers gold, every ring green to red by how well it works, each Mainspring's reach and the turret circles.",
		"CLOCKWORK COMPUTER: it lays a Heavy Works by a Mainspring as soon as its Escapement works (its first Spring Ballista, then its Pendulums), keeps room for it by its first Mainspring, and spaces its turrets by the new rule.",
	]},
	{"v": "0.14.96", "items": [
		"HORSEMEN AND CUIRASSIERS ATTACK ON THE MOVE, like the Cyclone: on any order (move, attack-move, attack, patrol) they strike an enemy in sabre reach as they ride past, on their normal reload and at full damage, without slowing or stopping. A plain move still goes where you sent them, cutting down what they pass.",
		"Told to attack a unit or a building, a rider rides AT it, strikes in passing, rides on a little and swings round its far end for the next pass, instead of standing beside it. A man on the run is ridden down. His one pistol shot is fired from the gallop too (on an attack or attack-move).",
		"HOLD POSITION, or stopped on guard, a rider stands and fights as before. Walls and gates are still hacked at standing. The Cavalry Charge doubles only the first blow after a gallop (no blow for 5 s, then 2 s at the gallop), not every pass. The Dragoon is unchanged.",
	]},
	{"v": "0.14.95", "items": [
		"EXPANSION SPOTS: the best places to expand are now marked on every map, as a few ground tiles in warm gold where a new Town Hall or Clocktower fits. Each side gets its best spot (a little brighter) and the next one, picked for the room to build round it, few ways in, a short walk from home and distance from the enemy. Both sides of a map get the same. They show for the Crown and the Clockwork (not for the Brood, which rarely moves its capital) and when watching, as small gold squares on the minimap too, and a touch brighter while you place a hall. A spot hides once a building you know of stands on it. Settings: SHOW EXPANSION SPOTS turns them off.",
		"FIX: on the classic river maps (Twin Fords, Mirewood, Border March) the fords were a few cells wider on one side than the other. Now both sides match.",
	]},
	{"v": "0.14.94", "items": [
		"Officers, Horsemen and Cuirassiers wear white coats and team-colour breeches, with a team-colour saddle cloth: easy to tell from Musketeers.",
	]},
	{"v": "0.14.93", "items": [
		"Getting on a horse and leading it now sound different: the horse whinnies when a man gets on it, and only snorts softly when a man takes it by the reins. The message from 0.14.92 is gone (it got old fast).",
	]},
	{"v": "0.14.92", "items": [
		"A soldier right-clicking a horse gets on it (Musketeer to Dragoon, Officer to Horseman...). Now a message says so and how to lead it by the reins instead: press LEAD (Q). Labourers still lead a horse on a right-click.",
	]},
	{"v": "0.14.91", "items": [
		"The Great Winder rolls on cog wheels instead of legs. Four brass cogs, the Clockwork's own wheel (as on the Spring Catapult and the Spring Ballista), turn as it moves, at just the speed it goes, and stand still while it mends or sweeps. When it is destroyed its wheels come off. Its speed is unchanged (27): it is still slow on purpose.",
	]},
	{"v": "0.14.90", "items": [
		"FIX: a Gate laid over part of a planned palisade now replaces only that piece (its price comes back); the rest of the wall stays planned and its Labourers carry on with it. Before, the whole planned wall, and the gate, could vanish. Over a wall being built or a built wall, the gate still takes just that one piece.",
		"FIX: a drag let go over the buttons or the minimap now ends there. The right-drag line no longer keeps following the mouse after its button is up (and the same for the box select, the middle-button map drag and a finger lifted over a button).",
		"CLOCKWORK COMPUTER: it no longer sends a Clocktower into your base. A new Clocktower goes only on its own side of the map, never nearer your halls, your main or your natural expansion than its own main; and where it lost a Clocktower or its crate, it does not try that ground again for four minutes.",
	]},
	{"v": "0.14.89", "items": [
		"FIX: a man getting on or off his horse, and a gun limbering or unlimbering, stays selected and in its control groups, and you can click or box-select it all the while (a click on him getting on picked the hidden horse). An order you give meanwhile waits: he finishes getting on (or off), then carries it out, and Shift-queued orders follow it.",
		"FIX: Shift + PATROL now queues the patrol: a unit on the move finishes the move, then patrols between where it ended and the point you clicked (it used to drop the move). The PATROL mode stays on while Shift is held, and the planned patrol shows from the end of its orders.",
	]},
	{"v": "0.14.88", "items": [
		"The Clockwork's Movement Works is now called the LIGHT WORKS (it makes the light machines; the Heavy Works for the big ones is coming). Its build key is L.",
	]},
	{"v": "0.14.87", "items": [
		"Clockwork build keys: the Clocktower is now T and the Cog Press C (the Cog Press's G looked like a C, and C built a Clocktower you could not afford).",
	]},
	{"v": "0.14.86", "items": [
		"The Crown's buildings have terracotta roofs.",
	]},
	{"v": "0.14.85", "items": [
		"FIX: Clockwork buildings go up out of their crate again. Only the Clocktower showed the crate: the Cog Press, Mainspring, Regulator, Movement Works, Ratchet Turret, Escapement and Clock Aviary jumped straight to their scaffold. Now every one shows the crate the Winder set down opening up and unfolding into its frame, for you and the computer alike.",
		"Clockwork buildings now BUILD UP: after the crate unfolds, the scaffold rises out of its plates from the bottom as the building goes up (all of it by half way), then the finished building stands.",
	]},
	{"v": "0.14.84", "items": [
		"The match log now records every building or button the game refused you, with the reason and the resources you had at that moment, so a refused build can be traced afterwards.",
	]},
	{"v": "0.14.83", "items": [
		"NEW CLOCKWORK UNIT, the GREAT WINDER (Movement Works, once an Escapement works; 175 cogs and 75 Tension): the Clockwork's big, slow, walking winding machine, with no weapon. It does the job the Winders walking with the army did, as one machine.",
		"WINDING: every Clockwork soldier near the Great Winder (the ring on the ground when it is selected) slowly winds up, so an army off the gear ground no longer runs down beside it, and run-down soldiers there wake up again. It never runs down itself.",
		"MEND (automatic, press to switch off): standing about, it mends the most hurt Clockwork unit near it with its key arm, one at a time and half again as fast as a Winder (it costs cogs, like a repair). Right-click a hurt unit to send it there.",
		"SWEEP (automatic, press to switch off): with nothing to mend, it sweeps up the wrecks of your own Clockwork units with its rollers and keeps them as PARTS (up to 100, shown on its card). Parts do nothing yet: they are for rebuilding machines in the field, later. It never sweeps Crown or Brood bodies.",
		"The Clockwork computer builds one Great Winder once it can and sends it behind its army; fewer of its Winders go with the army while it does.",
	]},
	{"v": "0.14.82", "items": [
		"Internal: the Springer's files and ids renamed from Jack; old saves and replays still load.",
	]},
	{"v": "0.14.81", "items": [
		"CLOCKWORK COMPUTER: its tech now comes on time. On Hard the Mainspring and the Escapement stand by about 4:00, so its first Springers, Netters and SHIELD WALL are out for the first big fight. It makes sure a Movement Works can make Springers (a Mainspring beside it, or a Works beside a Mainspring), keeps its cogs for the tech under a raid it can beat, and spends its Tension instead of leaving it at the cap. Its army is about one Springer for every one and a half Clock Soldiers, with a few Netters and Pendulums.",
		"CLOCKWORK COMPUTER SIEGES: its Springers and Netters shoot and net the workers mending a wall or gate first, then the shooters on the edge, while the Clock Soldiers hit the gate, and its reckoning of a siege counts that. Against a walled enemy its first attack waits for four Springers (two on Normal). With HIGH LEAP its Springers jump up onto the high ground when the enemies by the landing are worth less than they are. A siege going worse than it reckoned, or a wave that keeps losing far more than it kills, is called off, all the way back to the rally.",
		"CLOCKWORK COMPUTER TARGETS: it goes first for what it can reach without breaking a wall: an expansion, farms, outlying buildings (not a spot right under a walled plateau's guns). On Hard its Netters net fighters rather than workers, its Pendulums walk into knots of enemy soldiers, and badly hurt Clock Soldiers step back to a Winder to be mended.",
		"FIX: a unit given a new order while its blow was landing skipped its reload. A Netter given an order every second fired a net every second (its reload is 14 s). Now the reload always follows the blow, for every unit and every player.",
	]},
	{"v": "0.14.80", "items": [
		"NEW CLOCKWORK UNIT, the SPRING BALLISTA (Movement Works, once an Escapement works; 150 cogs and 50 Tension): a bolt thrower on cog wheels whose giant screw flies in a straight line THROUGH its target into one or two enemies behind it. Hard on armoured units and buildings (a wall or gate stops the bolt), weak up close and against swarms. No set-up: it fires as soon as it stops, and on the move at what is ahead, but its spring is wound again only while it stands.",
		"The Spring Ballista has a Winder built in. Up to 4 more Winders can BOARD it (LOAD CREW on the Ballista, BOARD on the Winders, or right-click it): each makes it reload and move 10% faster. They push it and crank it beside it, and they can be shot. UNLOAD CREW sets them down. The computer builds a couple and crews them with its escort Winders.",
		"When a Spring Ballista is destroyed, its bow snaps, a wheel comes off and the spring bursts out of its drum (the owner's painted wreck).",
	]},
	{"v": "0.14.79", "items": [
		"Brood: a new DEMOLISH button (a talon striking down on a split mound), so it can no longer be mistaken for BUILD; the Bloater's SPIT button now has its own picture, the Bloater spitting acid.",
	]},
	{"v": "0.14.78", "items": [
		"WINDERS have new art for carrying a building's crate: they walk with it held out in both hands, stand with it, and bend down to set it on the ground before it unfolds into the building, in every direction.",
	]},
	{"v": "0.14.77", "items": [
		"A Winder walking away from you with a building's crate now shows it over his head (it is in his hands in front of him), instead of hiding it behind his back.",
	]},
	{"v": "0.14.76", "items": [
		"WINDERS carry a building's crate out in front of them in their hands (it was on their backs), and at the site they lower it to the ground in front of them before it unfolds into the building.",
	]},
	{"v": "0.14.75", "items": [
		"The Clockwork's jumping screw-shooter is now called the SPRINGER (it was the Jack): the name says what it does, a soldier on a spring.",
	]},
	{"v": "0.14.74", "items": [
		"PATHFINDING, THE HIGH GROUND: a click on the edge of a plateau now means the top. Before, a click on the rim often counted as the low ground under the cliff, and the whole group walked down the ramp and round to stand in a heap at the foot of it. A line drawn along a cliff edge puts everybody on top too, each man on his own spot.",
		"PATHFINDING, GROUPS AT AN EDGE: a group sent near a cliff, a wall or a building spreads out on the side you clicked. Before, every man whose place in the group fell over the edge was sent to the exact spot you clicked, and they piled up there against the cliff.",
		"PATHFINDING, NO WAY THERE: a unit sent where it can't go (up a cliff with no way round, into a walled base) walks to the nearest place it can reach and stops. Before, it walked on from there straight into the cliff or wall and pushed at it for good; computer scouts did this for minutes under the enemy base.",
		"MELEE AND THE HIGH GROUND: Raptors, Brutes and other fighters no longer run to the foot of a cliff under an enemy they can't get at. With a wall or gate in the way they go and break it; with no way at all they leave him and look for another fight. A Raptor or Brute circling its prey no longer picks a spot below the cliff edge either.",
		"CORNERS: a unit that walks into a corner (a step in a cliff, the corner of a building) slips round it instead of stopping dead, and big units (Horsemen, Brutes, Pendulums, guns and wagons) plan their paths a little further from corners. Details and numbers: docs/pathfinding_audit.md.",
	]},
	{"v": "0.14.73", "items": [
		"CROWN COMPUTER, coached over 32 games against the Clockwork and the Brood computers: after a Horseman opening it no longer holds its Labourers at eight for ten minutes (its Horsemen now count as defenders); an ordinary Clockwork Movement Works is no longer taken for a rush (two of them early still are); it expands in time (a fresh Town Hall for every 16 Labourers, three at most) instead of waiting until its main is barren; it does not lay a new Town Hall again and again on a spot its builders were just chased from; and when powder piles up while gold runs out, Labourers go back from the Powder Mills to the farms.",
	]},
	{"v": "0.14.72", "items": [
		"Behind the scenes: a test switch that lets a computer's siege play out to the end, used to check when the computer should call an attack off. Nothing changes in play.",
	]},
	{"v": "0.14.71", "items": [
		"CLOCKWORK COMPUTER: its Winders now go with the army, at the rally point and on the attack, about one for every five soldiers. Out there they wind the soldiers up (the run-down ones first, then the lowest), and mend them second, and fetch soldiers left run down on the way. The Winders that go are extra hands: the presses keep theirs. Before, two Winders followed an attack and never wound a Clock Soldier, so a long march left half the army standing still.",
		"COMPUTER SIEGES: an army breaking in at a gate now gathers and queues on the side it can walk up to (down the ramp below a ramp gate), not at the foot of the cliff beside it, under the muskets on the high ground.",
	]},
	{"v": "0.14.70", "items": [
		"FIXES from a long test run of every map and mode: a Brood computer no longer places a Clutch Mound and drops it again every second while raiders stand near its grubs (it waits a little before trying again); a Brood swarm no longer calls its whole wave off when one of its Raptors is eaten or otherwise gone; a soldier raised by a Missionary who had been on his way to a horse no longer breaks his next order; a building whose rally point followed a unit that turned into something else (a grub that became a building, a man who mounted) lets go of it cleanly; and the dismounted Cuirassier walking east no longer asks for a picture that is not there.",
	]},
	{"v": "0.14.69", "items": [
		"GUARDSMAN: facing down the screen, he now aims and fires at you, the muzzle toward you and the flash in front of his chest, and thrusts the bayonet at you. Now every way the Musketeer and the Guardsman face, they fire that way.",
	]},
	{"v": "0.14.68", "items": [
		"GUARDSMAN: facing up-right, he now aims, fires and thrusts the bayonet that way, his back to you. His south view comes next.",
	]},
	{"v": "0.14.67", "items": [
		"GUARDSMAN: facing down-right, he now aims, fires and thrusts the bayonet that way, like the Musketeer. His up-right and down views come next.",
	]},
	{"v": "0.14.66", "items": [
		"WEB: closing the tab, reloading the page or swiping the browser away no longer shows THE GAME CLOSED UNEXPECTEDLY the next time you open the game. A real crash is still reported.",
		"MAP EDITOR: BACK, SAVE, LOAD, HELP and the other buttons work again after you paint with a mouse, and BACK works with a tap on a phone (the editor ate the button's click).",
		"SCREENS THAT RAN OFF THE EDGE: PATCH NOTES wraps its lines and fits a phone; MATCH LOGS and the crash report sit on a panel and wrap; the in-game MENU fits a phone held sideways and its volume bars no longer run through their words; the INTERFACE LAYOUT hotkey list no longer has its note drawn over it; long dropdown labels (RANDOM 2V2 MAP) shrink to fit instead of being cut; IDLE / ARMY / MAKE shrink further on a phone (PRODUCIR, EJÉRCITO).",
		"REPLAYS in Portuguese and Spanish: the players' names show in your language (they said \"P1 Crown (you)\", \"(easy AI)\" in English).",
	]},
	{"v": "0.14.65", "items": [
		"MUSKETEER: facing down the screen, he now aims and fires at you: the musket points toward the viewer, the flash bursts in front of his chest and the smoke rolls toward you, and his bayonet thrusts toward you. With the down-right and up-right views of the last version, every way he can face now fires the way he faces (the left-hand views are mirrors).",
	]},
	{"v": "0.14.64", "items": [
		"FAIR STARTS: on Jade Wilds with four Clockwork players, the two corner bases got their first Cog Press 9 tiles from the Clocktower and the two middle bases 7.5. A starting building one lane in from the edge of the main now counts as hugging it, so every base gets the same 7.5. Starting Farms, Feeding Pits and Cog Presses may sit a little closer to the main building on other maps too; every map was checked and is fair.",
	]},
	{"v": "0.14.63", "items": [
		"MUSKETEER: facing down-right or up-right, he now aims, fires and thrusts the bayonet that way. Before, every view pointed its musket to the right, so a line firing down the screen shot sideways. The new frames were painted one direction at a time over guides made from his own frames. The south and the Guardsman come next.",
	]},
	{"v": "0.14.62", "items": [
		"ONLINE, EVERY ORDER ANSWERS AT ONCE for the friend who joins: not only moves now. Units told to attack turn to the target and start walking into range; stop and hold stand them still at once; a building site appears where you placed it, faint and outlined until the host confirms it, and the worker heads for it; the cost and the supply show as spent; a trained unit, a research or a hall upgrade goes into the queue (drawn faint until confirmed) with its progress bar running; cancelling takes it out with the refund shown; the rally flag, hold fire, auto-train, deploying or packing a gun, cancelling a site or pulling a building down all show on the click. The host still decides everything: a moment later its game takes over, without a jump, and an order the host refuses (not enough gold, a blocked spot) is taken back at once with the reason.",
		"ONLINE, THE HOST'S OWN ORDERS (with \"Same delay for both players\"): they still wait half the ping, but the queue, the resources and supply and a building site show at once, and the units turn at once, as on the friend's screen.",
	]},
	{"v": "0.14.61", "items": [
		"BROOD ANIMATIONS: Raptors and Grubs no longer hop when they turn up or down the screen or stop (those walks stood 2 px above the ground). The Raptor's run plays faster (12 frames a second, was 8), so its feet skate less. A hovering Skywing beats its wings at a real pace (was 2 frames a second), and its east attack no longer shows a frame with only a wing.",
		"BROOD ANIMATIONS: the Mist Toad's death plays to the end: its body now lies flat instead of freezing half fallen. A Grub's wrapping takes as long as the wrap itself: the cocoon closes just as it picks it up, for small and big bodies alike.",
		"TEAM COLOUR: the Brood Queen's crest and the Clutch Mound's frills are now in your colour (they were red for every player), and the thin red rims on Brood crests and frills follow the team colour too. Veteran Raptors walking up or down the screen now show their veteran skin on their legs.",
	]},
	{"v": "0.14.60", "items": [
		"BROOD MUSIC: ten new pieces, so the Brood has twenty like the Crown, each with its own moment. Two open a match while the swamp wakes, tense under the calm: The Brood Wakes and The Hive Gathers. Three play in a lighter fight, a hunt held back from the kill: Something in the Water, The Scent of Blood and Circling. Three are the full battle, the swarm at full cry with big drums, the throat choir, brass and strings: The Swarm at Full Cry, The Queen's War-Song and Ten Thousand Mouths. Two are calm and slow: The Queen's Lullaby and Night over the Drowned Wood. The Queen Stirs may now open a match too.",
		"THE HIVE CALL: the new Brood pieces share a short theme of six notes (a low note, a leap up, then a sigh down to the start). A flute sings it plainly in the lullaby, the skirmishes chase it in broken pieces, and in the battles the whole choir roars it in long notes.",
	]},
	{"v": "0.14.59", "items": [
		"JACK: it keeps both drill launchers when it hops and jumps. Before, its left launcher turned back into the old claw every time it moved. The hop and the jump are now made from the same painting as its standing and shooting, so nothing changes shape between them. (Its death and its shot up at a flyer still show the claw until they are repainted.)",
	]},
	{"v": "0.14.58", "items": [
		"CLOCKWORK MUSIC: ten new pieces, so the Clockwork has twenty, like the Crown. They share one short theme, the Clockwork's motif: a tick and a tock, then a note left hanging. A music box plays it plainly in the calm pieces, the machine repeats it and shifts it in the skirmishes, and the whole orchestra hammers it in the battles. Their percussion is made of real clocks, an old clock bell, metal clangs, a typewriter, a crank and a spring.",
		"OPENING pieces (the first minutes of a match): The Great Escapement and Calibration. SKIRMISH pieces (a small fight): Tick, Tock, Alarm; The Watchful Gear; Pressure Rising. FULL BATTLE pieces (when the fight grows): Cathedral of Gears; Anvil Chorus of a Thousand Hands; The Grand Calculation. CALM pieces: The Clockmaker's Lament and Canon of Perfect Order. The calm Winding the Spring may now also open a Clockwork match. All of them are in the music player.",
	]},
	{"v": "0.14.57", "items": [
		"JACK: it no longer slides about on its spring while it stands. Its foot plate now stays on the spot in every frame and every direction, so switching between standing, shooting and hopping no longer makes it jump sideways (up to 6 pixels before). The screws still leave from the drill tips.",
		"CLOCK SOLDIER: facing right, the frame just before its sword comes down no longer loses its head cap, so its player colour shows all through the swing. A few stray dark pixels near its feet are gone.",
		"CLOCK AVIARY: while it works, only its doors and the little brass bird move. Before, every frame was painted anew, so the whole tower shimmered and it changed look when it started or stopped.",
	]},
	{"v": "0.14.56", "items": [
		"CROWN ANIMATIONS, small fixes from an audit of every Crown animation (docs/animation_audit_crown.md): the Officer and the Armoured Officer no longer hop as they walk (their walking feet now stay on the ground, as when they stand), and the Armoured Officer no longer floats a little when he aims and fires. The Horseman's horse no longer bobs up when it stops facing down and to the right. The Messenger galloping right no longer shows two or three riders in two of its frames. The Mortar's crew no longer jumps from side to side while the gun waits. The Mounted Missionary gallops at a gallop's pace (its horse slid along in slow motion). A stray dash under the Musketeer's muzzle is gone.",
	]},
	{"v": "0.14.55", "items": [
		"CHECKED: every automated test of the game was run (118), the files were checked against each other (every unit animation strip, building picture, icon, sound and requirement: a new test of 1,026 checks), and the README brought up to date (each Feeding Pit's own ground, replays). Two old tests that did not know the newer rules were updated; the game was right.",
		"FIX: every match tried to load a picture that no longer exists (an old walking frame of the Armoured Officer) and logged an error for it; that leftover is gone. The Android app no longer packs the retired units' art.",
	]},
	{"v": "0.14.54", "items": [
		"CLOCKWORK SOUNDS from the owner's recordings of real clocks and machines (a typewriter, an alarm clock, an old clock bell, a crank, a spring, metal clangs). The Clock Soldier, Jack, Swift, Ticking Owl, Pendulum and Netter now answer in their own machine voices when picked or ordered: typewriter keys for the Clock Soldier, a spring's boing for the Jack, quick high ticks and a little bell for the Swift, slow low ticks for the Owl, the old clock bell and a heavy crank for the Pendulum, a crank cocking the spring cannon for the Netter.",
		"CLOCKWORK FIGHTING: bright clangs for the Clock Soldier's sword, heavy low clangs for the Pendulum's blows, a ratchet spin for each screw the Jack and the Ratchet Turret shoot, a typewriter key for the Swift's peck, a clang for the Owl's talons. The Jack's spring presses, boings and clanks as it jumps and lands; the Netter's spring lets go when it fires and the chain net rattles where it lands; the Owl's weight lets go with a wobble and lands with a heavy clang. Every Clockwork unit (the Winder too) dies with a crash of metal, pieces rattling down and a spring letting go.",
		"CLOCKWORK BUILDINGS each have their own sound when picked: the Clocktower's old bell, a crank turning for the Cog Press, a spring for the Mainspring, ticking for the Escapement and (slower, with a soft bell) the Regulator, clangs for the Movement Works, a ratchet for the Ratchet Turret, high ticks and a ding for the Clock Aviary. A Winder working a Cog Press is heard cranking it; building and repairing is a click and a clang; the crate is a real ratchet.",
		"CLOCKWORK ALARM: when your Clockwork units are attacked an alarm clock rings (and rings again, after a tick, when your buildings are attacked), instead of the bell and drums the other factions keep. Research done rings the old clock bell once; a building finished slides the typewriter's carriage back and rings its bell; a unit ready turns a ratchet and rings the bell. MORPH TO OWL turns a crank, and the old bell rings when the Owl is ready.",
	]},
	{"v": "0.14.53", "items": [
		"CLOCK SOLDIER: a little quicker (speed 68, was 62) and lighter (75 health, was 90). These numbers are a first guess.",
		"SHIELD WALL, a new research at the Movement Works (100 cogs + 50 Tension, 45 s; it costs Tension, so only at a Works whose ring meshes with a Mainspring's): every Clock Soldier gets SHIELD FORWARD (key F). The soldier raises its shield in front of it (half a second, standing still): it walks 40% slower and swings a little slower, but has 1 more armour, takes half the damage from shots coming from the front and a fifth less from blows from the front. Nothing against blows from the side or behind, nor against splash. Press it again to lower the shields. With the shields up a squad wins a stand-up fight against shooters it used to lose, but it can no longer catch a Musketeer who walks off, and running away it takes far more. Raised shields show: the shield is carried in front of the body. Works online and in saved games.",
		"CLOCKWORK COMPUTER: it researches SHIELD WALL once it has met an army of shooters, raises its Clock Soldiers' shields as they walk into ranged fire, and lowers them to chase a shooter that walks off or to fall back.",
	]},
	{"v": "0.14.52", "items": [
		"AREA MARKS: area attacks now show where they strike, the way the canister's cone and the round shot's line show before a cannon fires. At the moment of the blow a see-through mark of its real shape lies on the ground for about half a second, under the units: the Pendulum's wedge in front of it, a canister's cone, a round shot's line, the ring of a Mortar shell, a keg or Powder Wagon going up, an Owl's bomb, a Bloater's burst, the oval of a Spore Mother's spit. Shells and spit that land later (a Mortar shell, a Spore Mother's spit, the Ticking Owl's bomb) first show a blinking warning where they will land, filling in as they come down, so you can see it coming and step out. Clouds that stay a while (a Bloater's gas, Miasma, a Mist Toad's fog, storms) keep a faint edge for as long as they last. You see a mark only where your side sees the ground (or your own side's). AREA MARKS in Settings turns them off.",
		"PENDULUM: its blade leaves a cold steel smear along its low sweep, from the side it swung from across its front, that lingers about a third of a second after each blow, so it reads as a sweep at any zoom. The hit timing and damage are the same.",
		"CLOCKWORK INCOME YOU CAN SEE: a working Cog Press shows a \"+N\" over itself every 4 seconds with the cogs it pressed, and a Mainspring a \"+N tension\" every 6 seconds while it winds, like the Farm's harvest and the grub's drop at the capital. Only the owner sees them. Online, a friend now sees the numbers over their own Farms, grubs, Cog Presses, Mainsprings and Ore Trains too.",
	]},
	{"v": "0.14.51", "items": [
		"REPLAYS: every match is recorded, a skirmish, a match between computers you watch and online, and the REPLAYS button on the main menu lists them, newest first, with the date, map, players (name, faction, colour, team), your result, length, game version and size. A replay is not a video: it keeps what was on the map five times a second, so while it plays you move the camera anywhere, select units and buildings to read their health, orders and queues, look through any player's fog or see everything, follow the camera of a player who recorded it, and watch at half speed up to 8x, with pause and a timeline to jump to any moment. The chat comes at its times, and the top bar shows every player's resources, supply, income per minute, army value and workers. On a computer: Space pauses, + and - change the speed, Home goes back to the start.",
		"REPLAYS ONLINE: the host's game records every side; when the match ends the host sends the whole replay to each friend (\"Sending it to your friend: 40%\" on the end screen), never before, so nothing hidden by the fog travels during the match. Until it arrives, or if you leave early, a friend keeps a replay of what it saw itself, marked YOUR VIEW ONLY.",
		"REPLAYS are kept on the device: the newest 30 that you have not marked KEEP stay (Settings > REPLAYS KEPT), DELETE removes one, EXPORT saves a file (in the browser, a download) and IMPORT plays a file a friend sent you. The end screen says \"Replay saved\" and has WATCH REPLAY. A replay from another version of the game still plays, with a note that some things may look different; a unit that no longer exists is shown greyed. A match closed in the middle keeps its replay up to its last few seconds.",
		"MAIN MENU in two rows (one row got crowded with REPLAYS): ONLINE, SKIRMISH and REPLAYS on top; HOW TO PLAY, EDITOR, MATCH LOGS and SETTINGS below.",
	]},
	{"v": "0.14.50", "items": [
		"HOLD has its own picture for the Clockwork (a brass shield with a blue steel arrow pointing down) and the Brood (a shield of hide and bone with a yellow arrow pointing down), the same idea as the Crown's shield, so HOLD reads the same in every faction.",
	]},
	{"v": "0.14.49", "items": [
		"NEW ICONS, painted: buttons and portraits that borrowed the Crown's pictures or were cut from the sprites. The CLOCKWORK: portraits of the Clock Soldier, Jack, Swift, Ticking Owl, Pendulum, Netter and Winder; its own BACK, CANCEL, DEMOLISH (a gear in pieces), PATROL (a swinging pendulum), RALLY, WORK, MORE and ATTACK GROUND (a clock hand striking the ground); SMALL GEAR and BIG GEAR, JUMP, MORPH TO OWL, and the HIGH LEAP and TICKING OWL research; and a wound mainspring for TENSION in the top bar. The BROOD: its own BACK, CANCEL, DEMOLISH, PATROL (claw prints), RALLY (a skull totem), WORK, MORE, TONGUE, TAKE OFF and ATTACK GROUND (a Spore Mother's lob). The CROWN: ATTACK GROUND (a cannonball landing in a red ring), TEAM (two harness horses), MORE (a page turning), RESTOCK, AUTO REFIT and the Mortar's DEPLOY. HOLD keeps the Crown's shield for now: the Brood's and the Clockwork's are being drawn.",
		"HORSE BREEDER: picking it plays hooves trotting with a horse neighing over them (three takes), instead of the Crown's usual building sound.",
	]},
	{"v": "0.14.48", "items": [
		"THE NEW PENDULUM: the Clockwork's tall clock tower now has two arms instead of a blade hanging between its legs, each a brass rod ending in a heavy weight with a crescent blade. It attacks forward and its arms cut in turn, right then left: each blow is a LOW SWEEP, like a scythe mowing at ankle height: the arm swings back behind its hip, then sweeps forward and across just above the ground in front of its feet, the blade's edge first, through every enemy on the ground in the wide arc in front of it (Raptors, Labourers and the like stand right in its path), and follows through low past them. New look in every view (standing, walking, attacking, dying) and a new card portrait.",
		"PENDULUM BALANCE: lighter, quicker blows (12 damage every 1.4 s, one arm at a time, instead of 22 every 2.6 s: about the same damage a second), and light units (Musketeers, Labourers, Raptors and the like) take half as much again from each blow. These numbers are a first guess.",
	]},
	{"v": "0.14.47", "items": [
		"CLOCK SOLDIER: its sword is now in its right hand and its shield on its left arm whichever way it faces. Turned toward the lower left, left or upper left it no longer swaps them (those views were the right-facing ones mirrored): it has its own west-facing drawings, so facing left you see the shield in front with the sword's blade beyond it, and facing right the sword. Its walk, attack and death in those three views are made from the new drawings: the sword arm, now on the far side, swings partly behind the body.",
	]},
	{"v": "0.14.46", "items": [
		"BODIES HAVE HEALTH AND ROT: a body has the health its unit had in life (a rider's adds his horse's, who lies with him) and loses it at one speed for everyone, twice as fast with every minute it lies: a Raptor's lasts about 1:20, a Labourer's or a grub's 1:35, a Musketeer's 2:00, a Horseman's with his horse 3:15, a Brute's 3:30, a Pendulum's 4:00. This replaces the fixed times (2 minutes with the Brood in the match, 30 seconds without), so it is the same in every match. The thin bar over a body is its health. Hitting a body takes health off and makes it go sooner; a body brought to 0 is torn up: the Brood can't harvest it and a Missionary can't raise it (who still raises a fallen soldier within 60 s, as before).",
		"ATTACK GROUND (Ctrl+A, the button was BOMBARD): now for every unit that can attack, not only cannons, mortars and Spore Mothers: shooters, melee units and workers (Labourers, grubs, Winders) too. Click a spot and everyone attacks it (melee units and workers take the bodies within a tile and a half of it); hold the left button and drag a line, as with the right-drag formation, and the line is shared out among them, each its own stretch, with a preview while you drag. A short drag is a click; Shift queues it. Shooters fire along their stretch, at the bodies on it while there are any: a shot lands where it is aimed and hits an enemy standing there, else the nearest body, else the ground, and spends powder as usual. Melee units and workers walk up and strike the bodies on their stretch, new ones too, and wait when there are none; workers hit softly and take longer. They keep at it until you give another order: hold a lane of fire if you like. A Mortar shell, round shot, canister or spit blob fired at the ground hurts every body in its blast (10 times its damage: it still tears up most bodies at once; a Pendulum's needs two). Ordinary fire at enemies still leaves the bodies alone. Works online and in saved games.",
		"HARVEST: a grub wraps a small body quickly and a beefy one a little longer: about 0.9 s for a Raptor, 1.2 s for a Musketeer, 2 s for a Horseman with his horse, 2.2 s for a Brute, never more than 3 s.",
	]},
	{"v": "0.14.45", "items": [
		"BROOD COMPUTER plays better. It keeps adding Grubs while it builds its army (it stopped at 9 whenever the enemy army it saw was bigger, so its income stood still), and keeps its eggs for the army once it has enough. It is no longer stuck at the supply limit with biomass in hand: Clutch Mounds go up ahead of need. Its Brood Pen goes up at about minute 5 (it often came at minute 6 or 7, or never), it offers up a few spare Raptors there and harvests the bodies after a fight, so Spitters join the Raptors, and an egg waits for a Spitter's biomass instead of always hatching Raptors. A second Burrow goes up when its eggs, not its biomass, hold the army back.",
		"BROOD COMPUTER attacks with judgement. It remembers the enemy soldiers it has seen and does not attack into an army clearly stronger than its own (it defends and builds up instead); when it has seen nothing of the enemy for a while it first sends two Raptors to look; and an attack that is clearly losing pulls back home instead of fighting to the last Raptor. Two enemy Horsemen hunting its Grubs are answered by the Raptors as a pack.",
	]},
	{"v": "0.14.44", "items": [
		"FIX (online): with the Jack's two launchers (0.14.35) a friend's game read every unit's values one place off after the new value, and stopped updating its units; it reads the Jack's launcher now, and the online test checks that the lists match.",
		"ONLINE: the automatic online test now plays every kind of order a friend gives (move, attack-move, a line, hold, stop, hold fire, bombard, rally, train and cancel, auto-train, gather, a hall upgrade the host refuses with its reason, demolish), the chat both ways, a pause and its resume, and a surrender from either player, in a 1 vs 1 with each faction and in co-op (where a friend who surrenders is out and the match goes on for the host).",
		"ONLINE: the ping counter keeps its place left of the clock (under it when a phone's top bar has no room for it), and the zoom gauge steps aside instead of covering the clock.",
		"ONLINE ROOM: a refused colour's words stay for a moment, then the room's line comes back.",
		"ONLINE MENU AND PAUSE are two things now: MENU (top right) opens the menu over the running match, with PAUSE, the volume sliders, the music player, SURRENDER and QUIT TO MENU (both asked twice online) and BACK TO THE MATCH. PAUSE stops the match; online either player can pause it for both (3 pauses each, at most 2 minutes each, then a 3, 2, 1), and both screens say who paused. The same in a skirmish.",
		"MUSIC PLAYER in the in-game MENU: the piece playing and how far into it, NEXT, and a list of every song to pick from (your faction's first). A picked song plays to its end, then the music follows the match again. Only on your own screen.",
		"ONLINE, SAME DELAY FOR BOTH PLAYERS (a switch in the room, on by default): the host's own orders wait as long as the friend's take to reach the host's game (half the ping, at most 250 ms), so neither side reacts faster. The click is answered at once on both sides (the ring, the voice). The match log says how long they wait.",
		"ONLINE, THE FRIEND'S UNITS ANSWER AT ONCE: on the friend's screen, units told to move or attack-move start walking at the click instead of a round trip later, then blend into where the host's game has them, without a jump.",
		"ONLINE, SMOOTHER: the host sends a picture every two game ticks (15 a second), fewer in a big battle or on a slow uplink (only what changed is sent), and the friend's screen shows the units a little behind the newest picture, from a buffer sized to how unevenly the pictures arrive, so they walk at an even speed.",
		"ONLINE, PING: a counter left of the clock (green, yellow, red) shows the round trip to the other player; \"Waiting for the host...\" shows when no picture has come for a second; a host whose browser tab or app goes to the background pauses the match for both. The match log has an online line every minute (ping average and highest, this device's leg to the relay, pictures, orders sent, run and refused, stalls) and notes stalls and hidden windows.",
		"ONLINE: the chat reaches the other player both ways; the ring where you click shows only on your own screen (the friend's at once); an order the host refuses tells the friend why.",
		"ONLINE ROOM: a friend who joins says hello again every 2 seconds until the room arrives (a room that sat empty on \"Waiting for the host...\"), the host sends the room again, the room shows the ping, and after 8 seconds with no answer it says so (and keeps trying).",
	]},
	{"v": "0.14.43", "items": [
		"SMOOTHER LATE GAME: big matches run faster, and play exactly the same (a computer-vs-computer match with the same seed plays out move for move as before). Measured on The Sundered Realm, 2 against 2, at 18 minutes with about 250 units: the game does about a quarter less work per second of play, and stutters (frames slower than 33 ms) are about five times fewer. The biggest savings: the selection card (a selected Town Hall or soldier fitted its info line letter by letter 20 times a second: frames of up to 70 ms), the fog of war (half the work), the computer players and the buildings (a quarter less), and the search for nearby units.",
	]},
	{"v": "0.14.42", "items": [
		"BROOD GROUND, A CIRCLE PER PIT: every Feeding Pit now has its own ground, 3,000 biomass in a circle 5 tiles round it; its grubs draw on it load by load, and a spent pit yields nothing. The Burrows (the capital too) have no ground any more: the capital is still the only drop-off and the Queen's seat. Your pits' circles may not overlap (their centres stay 10 tiles apart: about 4 or 5 pits fit on a main plateau). While you place a pit you see the circle of every pit of yours, the ghost's own circle (green where it fits, red where it would overlap, with the pit it clashes with in red) and what ground it would get; a refused spot says why (\"Too close to another Feeding Pit: their grounds would overlap.\"). A selected pit shows its circle and \"Ground: %\" on the map and on its card, and each pit warns for itself when it runs low. The ground belongs to the land: a pit that dies leaves its circle as dim old ground with what was left, and a new pit over old ground takes over the smallest amount left there, so rebuilding beside a spent pit can't refresh it. One more grub per pit: the base crew is 6 (was 5), still +1 for every 4 tiles beyond 6 from the capital, up to 12. The computer keeps to the circles, prefers fresh ground and replaces spent pits farther out on its swamp.",
	]},
	{"v": "0.14.41", "items": [
		"ESSENCE: the +1 essence a harvested body gives for each kill it made now stops at 50, the same 50 kills veterancy counts (it had no cap).",
	]},
	{"v": "0.14.40", "items": [
		"BROOD ESSENCE: SACRIFICE pays much better: a creature offered up at a Brood Pen gives 35% of its biomass cost as essence (9 a Raptor, was 3; 53 a Brute). The Brood Pen no longer turns bodies that fall near it into essence by itself; the fallen, friend or foe, are harvested by grubs, and a harvested body is worth more: 2 essence for each point of its supply (was 1.25), plus 1 for each kill it made (a Musketeer 2, a Horseman with his horse 8).",
	]},
	{"v": "0.14.39", "items": [
		"WEB VERSION LOADS FASTER: the first visit downloads about 60 MB instead of about 145 MB, and after an update usually only about 2 MB. The game is split into a small code pack and an art pack that only downloads again when the art changes; the browser keeps both (and the engine) for the next visit. The music no longer comes in the first download: each piece downloads when it is first played (the menu and match music start a moment later the first time) and is kept too. A new loading screen in the game's colours shows how far it is. The Android app is unchanged (everything inside it) and a little smaller.",
	]},
	{"v": "0.14.38", "items": [
		"CLOCKWORK ECONOMY (gear mode; the study: docs/clockwork_economy_study.md). TENSION is a full resource now: every Mainspring STORES 200 Tension (400 on its big gear, which takes up to 6 Winders and winds 2.6 a second); winding stops when you hold what your Mainsprings store (the top bar reads held / stored), and nothing unwinds. Buildings can cost Tension: the CLOCK AVIARY is 150 cogs + 50 Tension (a cancelled site gives it back; the computer pays it too).",
		"EFFICIENCY: every working Clockwork building shows its % over it and on its card: its crew share times its DRIVE. The Clocktower and every Mainspring drive the gear field: a building meshing with one works at 100%, each ring farther out 10% less (at least 70%); an idler costs nothing. Drive sets a Cog Press's cogs, a Mainspring's winding and the speed of training and research (not supply, the Ratchet Turret or building). The placement ghost shows the % before you place (LINKS 90%), and a Mainspring's ghost how many buildings it would feed (FEEDS 2).",
		"THE TENSION RULE grows: anything that costs Tension is made only at a building whose gear ring meshes with a Mainspring's. The Clock Aviary now stands idle without one (NEEDS MAINSPRING), like the Escapement, and a Movement Works makes Jacks, Netters and Pendulums only with a Mainspring meshing with it (its Clock Soldiers need none; the Pendulum still needs the big gear too).",
		"GEARS MESH ONLY ON THE SAME GROUND LEVEL: a ring on the high ground no longer links with one below the cliff, nor one at the top of a ramp with one at its foot, and no idler is put across a cliff. The placement ghost says NO LINK: OTHER LEVEL.",
		"BALANCE: the Clockwork earned about twice what the Crown did per worker, so a Cog Press now takes 6 Winders (big gear 12) for the same top rate: a Winder adds about what a Labourer adds on a Farm.",
		"The Clockwork computer puts its presses and Works on the Clocktower's ring, keeps room for a Mainspring beside its first Works, builds a Works by its Mainspring for Jacks and its Aviary by a Mainspring, and puts a Works that meshes with a Mainspring on its big gear for Pendulums. In the CLOCKWORK LAB the big-gear Works has a second Mainspring beside it, which also feeds the Aviary, and the Mainsprings start wound full.",
	]},
	{"v": "0.14.37", "items": [
		"LIMBERED GUNS no longer clip through walls or jam: a Field Cannon, Mortar or Powder Wagon on the move (its horse team drawn ahead of it) now keeps the whole team, not just the gun, off walls, palisades, buildings and cliffs. The gun itself is narrow enough for a one-tile gate; it lines up on the gate before it goes through and drives straight out the far side (one that stopped in a gateway carries on through instead of backing out), and at a wall end or a block of rock the team swings round it instead of pointing into it and sticking.",
		"HORSES NO LONGER VANISH INTO BUILDINGS: a horse taken for a Horseman, Cuirassier, Dragoon, Field Cannon, Mortar or Powder Wagon (standing at the building, kept at a breeder or led over by a Town Hall hauler) walks to its own spot beside the Barracks or Foundry and waits there HITCHED, in sight, where it can't be hurt or taken, until the recruit comes out: the rider mounts it there (on its coat and health as they are then) and the gun comes out drawn by it. Cancelling the recruit frees the horse where it stands. Before, it walked into the building and was gone (after 90 s even if it never got there).",
		"HAULERS: a Labourer leading a horse to a recruit whose building has a side shut in by a palisade or other buildings now goes round to a side he can reach, instead of walking at the palisade and standing stuck.",
	]},
	{"v": "0.14.36", "items": [
		"POWDER MILL WORK YARD: the mill's crew no longer stands stuck. The mill's front row is now its work yard, walkable like a Farm's fields (nothing can be built on it): the labourers dig at the three heaps, carry the loaded shovel along the front and tip it into the hopper, all inside the mill's own ground, so Cottages, walls or a cliff edge right against the mill no longer block them (with every open side of the yard built up, they go in through the shed). The six spread over the heaps and the hopper and keep a step apart instead of bunching at one side, always shovelling or walking (no frozen poses), and they are drawn in front of the shed, heaps and hopper they work at.",
	]},
	{"v": "0.14.35", "items": [
		"CLOCKWORK COLOURS: every Clockwork unit is now brass and your colour, with no blue left. The Jack's body and shoulders are in your colour; the Clock Soldier is all brass except its head (the cap with the crown spike), which is in your colour, so the two are easy to tell apart. On the others the blue ball joints and wing springs are now in your colour. Steel stays steel (the Jack's drill tips are a plain steel grey now, not icy blue) and the clock faces stay white. The red parts no longer show orange streaks on other colours, and the Clock Soldier seen from behind no longer has the top of its head cut off.",
		"THE JACK now has two drill launchers and fires them in turn, a screw from each arm, each from its own tip. Its hop, jump and death still show the old claw arm until their new drawings arrive.",
		"THE SWIFT's peck is painted now: it brakes with its wings up, stabs its beak forward and down, and pulls away; the blow lands on the stab.",
		"THE PENDULUM's death seen from behind and from the back three-quarter view is painted now (it was a rough sketch).",
		"THE CLOCK SOLDIER is drawn about 30% smaller (about a Musketeer's size, well under the Jack), and its body is smaller to match (radius 14 down to 10, a Musketeer's): it takes less room in a crowd and is easier to tell from the Jack.",
	]},
	{"v": "0.14.34", "items": [
		"NEW WINDER: the Clockwork's worker is the new clock-faced Winder in every view (standing, walking, winding, attacking, dying), in brass and the player's colour (his blue joints and red heart now show the team colour). He moves on a clockwork beat: ticking steps; his work goes hammer, hammer, pause with a small crank turning in his hands (at a Cog Press, repairing, and on the crate he sets down on a site, which he gives a few turns as it unfolds); the hands on his clock face tick once a second; and when he dies he runs down. New card portrait.",
	]},
	{"v": "0.14.33", "items": [
		"ART: the ESCAPEMENT's working loop redone. Its anchor now rocks on its pivot like a pendulum and, each time it swings through the middle, the escape wheel jumps forward half a tooth and stops: tick... tock..., a beat every half second (24 frames instead of 8). The wheel turns cleanly in its own plane (no more smeared, jagged spokes and teeth) and is evened out from its own painted pieces (12 teeth, 8 spokes); what it and the anchor uncover is the drum's own paint, not a flat dark fill, and the drum no longer has see-through holes. The idle building and its card picture show the evened wheel too, and its red panels no longer show specks of the player's colour.",
	]},
	{"v": "0.14.32", "items": [
		"FOG OF WAR: one grey only, as in StarCraft 2. The black fog over ground nobody had looked at is gone: the whole map's ground (cliffs, ramps, water, trees, rocks, the places to build a base) shows from the start under the grey fog, on the minimap too, and what your side sees is clear. The enemy still shows only once seen: its units while in sight, its buildings once spotted (then remembered under the grey as you last saw them), its swamp only where you have looked; smoke, shots and blasts on ground you have never looked at stay hidden. The same when you watch the computers through one player's eyes, and online.",
		"BUILD ANYWHERE: a building can be placed anywhere on the map, seen or not (no more \"Unexplored.\"). The worker walks there; if an enemy building you had not seen stands in the way when he arrives, the site fails as usual (\"Can't build there: the spot is blocked.\") and its cost comes back. Enemy buildings you have seen still block the ghost; ones you haven't do not show on it, nor on the build grid.",
	]},
	{"v": "0.14.31", "items": [
		"CLOCKWORK: only the rebuilt army in the live game. The old Assembly Works and its prototype units (Wind-up Soldiers, Thresher, Bulwark, Arc Thrower, Tin Militia, Scrapper, Rail Rifleman) can no longer be built or trained, and the SANDBOX's CLOCK tab lists only the new units and buildings: Winder, Clock Soldier, Jack, Pendulum, Netter, Swift and Ticking Owl.",
	]},
	{"v": "0.14.30", "items": [
		"ONLINE MATCH LOGS are kept: an online match left before its end (QUIT, a lost connection) now saves its log in MATCH LOGS, and the running log is kept as UNFINISHED OR CLOSED MATCH while you play, as in a skirmish.",
	]},
	{"v": "0.14.29", "items": [
		"CROWN BUILDINGS IN YOUR COLOUR: every flag, banner, pennant, awning and red cloth on the Crown's buildings now wears the player's colour: the Town Hall's striped market awning, the Horse Breeder's saddles and blankets, the Foundry's wall hangings and its workmen, the Armoury inventor's shirt, and the red edges of the banners (some of it was painted in a red that stayed red for every player). The Farm's windmill roof is terracotta now, no longer the player's colour. Bricks, fire, powder kegs, food and the Barracks' target stay as painted (the Foundry's forge fire and some of its bricks used to show the player's colour).",
		"The building you are placing shows your colour on its flags, like the building will.",
	]},
	{"v": "0.14.28", "items": [
		"ONLINE: the MENU opens again during an online match, so you can SURRENDER or QUIT. The match keeps running behind it (online nothing pauses); its first button is BACK.",
		"ONLINE: turning a phone upright no longer holds the match when you play online (a held host stopped the game for the other player too).",
	]},
	{"v": "0.14.27", "items": [
		"FIX: the gear rings under Clockwork buildings now stand drawn through the 3, 2, 1 countdown (in the Clockwork Lab, a skirmish or online) instead of popping in at GO.",
	]},
	{"v": "0.14.26", "items": [
		"FIRE AT A SPOT (BOMBARD): Ctrl+A (A is still attack-move) or the new BOMBARD button on their card, then a spot on the ground: the Field Cannons, Mortars and the Brood's Spore Mothers in the selection walk into range, set up and keep firing at it, into the fog too, until you give another order, as long as their shot lasts (a Powder Wagon nearby keeps them going). A Cannon fires what it is loaded with, round shot or canister. Shift queues it; with orders queued behind it, each fires 3 shots at the spot and goes on. While they are selected their spot shows on the map; the order is kept in a saved game and works online. Its icons are placeholders until the painted ones come.",
		"AREA SHOTS DESTROY BODIES: a Mortar shell, round shot or canister fired at a spot (BOMBARD) tears up the bodies lying in its blast: the Brood can no longer harvest them and a Missionary can no longer raise them (the Crown's own dead too: the price of blasting). The men the shot itself kills still fall as bodies. Ordinary fire at enemies leaves the bodies alone: measured, a gun line holding against Brood waves would otherwise have torn up 9 bodies in 10 by accident; clearing a field is a choice that costs powder and keeps the guns busy. To make up for it, a harvested body now gives 1.25 essence for each point of supply instead of 1 (a Musketeer or a Raptor 1.25, a Brute 3.75, a Horseman with his horse 5, plus 1 for each kill); SACRIFICE and the Brood Pen are unchanged.",
		"The Crown computer, facing the Brood with nothing attacking its base, has an idle Cannon or Mortar fire a few shots at a pile of bodies the Brood could harvest; never in a battle (it stops as soon as an armed enemy shows up).",
	]},
	{"v": "0.14.25", "items": [
		"FIX ONLINE: on a phone the ROOM CODE box (and the relay address boxes) could not be tapped. A tap now selects it and opens the keyboard; in a phone's browser it opens the browser's own text box.",
		"ONLINE: the 3, 2, 1, GO countdown is back, and it waits until every player's match has loaded, so a slower phone no longer starts behind the host.",
	]},
	{"v": "0.14.24", "items": [
		"WORKERS take the primary resource's jobs first, in every faction: a new Labourer goes to a Farm before any Powder Mill and hauls at the Town Hall only when both are full (Grubs: Feeding Pits; Winders: Cog Presses before Mainsprings). Nearest first within each.",
		"CAMERA: it now scrolls only 7 tiles past the map's edge (it was 25).",
	]},
	{"v": "0.14.23", "items": [
		"CLOCKWORK TIER 3 (gear mode): two new units from the MOVEMENT WORKS once an Escapement works, both paid in cogs and Tension. The PENDULUM (200 cogs + 75 Tension, 4 supply, 340 hp, 2 armour, slow), a tall clock tower on long legs, swings its pendulum blade through EVERY enemy on the ground in the wide arc in front of it (22 damage to each, a swing about every 2.6 s); it never hits its own side and cannot reach flyers. It is made only while the Works runs on its BIG gear (swap the gear on the Works' card): on the small gear its button says why, and a Works making a Pendulum cannot go back to the small gear until it is done or cancelled. The NETTER (125 cogs + 50 Tension, 2 supply, 120 hp, weak) fires a weighted chain NET from its spring cannon at ONE enemy up to 180 away: the net flies where you can see it, and the enemy it catches cannot move or fight for 4 s; a flyer it catches comes down to the ground for that time, where anything can hit it. One net about every 15 s; by itself it nets the most dangerous enemy in reach that is not caught already (right-click one to choose). The CLOCKWORK LAB starts with its Movement Works on the big gear, two Pendulums and two Netters; the SANDBOX's CLOCK tab spawns them. The Clockwork computer puts one Works on its big gear once it has an Escapement and adds a few Pendulums and Netters to its army.",
		"CLOCKWORK AIR, smoothed: a Swift or a Ticking Owl that is shot down no longer drifts sideways while it spins; the Swift's peck now dips its beak into the blow, nose down, and holds it there a moment (re-timed from its flight frames). ONLINE: the guest now sees the Owl's bomb fall, not only burst, and the progress bar of a Swift's MORPH TO OWL.",
	]},
	{"v": "0.14.22", "items": [
		"FIX: the Crown Mortar's DEPLOY / PACK button showed the Clockwork's tesla tripod; it now shows the Mortar with the Crown's red limber arrow.",
	]},
	{"v": "0.14.21", "items": [
		"CLOCKWORK AIR (gear mode): the CLOCK AVIARY, a tall clock tower on its gear ring (2x2, 175 cogs, 900 hp), makes the Clockwork's flyers; it can only be built while an Escapement works (meshed with a Mainspring). While it trains, its little doors open and a brass bird flies off. The SWIFT (75 cogs + 15 Tension, 2 supply, 90 hp, fast) hunts flyers only: it darts in and pecks (10 damage about every 1.3 s) and cannot touch the ground. Research TICKING OWL at the Aviary (150 cogs + 150 Tension, 60 s), then MORPH TO OWL rebuilds each Swift on its own into a TICKING OWL (100 cogs + 50 Tension, 20 s; it hovers in place meanwhile while a clock hand sweeps round it; CANCEL MORPH pays it back): a heavy, slow flyer (220 hp, 1 armour, 4 supply) that swoops down on units with its talons (20 damage every 2 s) and lets its pendulum weight fall on buildings as a bomb that bursts where it lands (45 damage to the buildings round it, every 3 s). It cannot hit flyers: Ratchet Turrets, Musketeers, Spitters, Skywings, Jacks and Swifts shoot it down. Shot-down flyers fall to the ground. The JACK now raises its arm to shoot at flyers. The CLOCKWORK LAB starts with an Aviary, three Swifts and a Ticking Owl; the Clockwork computer builds an Aviary when it sees enemy flyers (or late), answers them with Swifts and morphs an Owl now and then late in the game.",
	]},
	{"v": "0.14.20", "items": [
		"CLOCKWORK TIER 2 (gear mode): the ESCAPEMENT, the Clockwork's tech building (3x3, 150 cogs, needs a Movement Works), unlocks the JACK and researches HIGH LEAP. It uses Tension, so its gear ring must mesh with a Mainspring's ring (right beside it; an idler cog between them counts): otherwise it stands idle and shows NEEDS MAINSPRING, and its placement ghost says so; if its Mainspring is destroyed it waits until one meshes again. The JACK, the first unit that costs Tension (100 cogs + 25 Tension, 2 supply), is a jack-in-the-box on a coil spring: it hops about and shoots spinning screws at ground and air (10 damage about every 1.4 s, a little short of a Musketeer's reach). JUMP (E, then a spot): a short crouch, then a leap of up to 5 tiles along an arc over its shadow; it cannot shoot in the air and its spring takes 10 s to wind back; flat ground or down a cliff any time, UP a cliff only after HIGH LEAP (150 cogs + 100 Tension) and only where you can see. Tension prices show on the cards (100+25) and in the tooltips. The CLOCKWORK LAB starts with an Escapement meshing with the Mainspring and three Jacks; the Clockwork computer builds a Mainspring and an Escapement, mixes Jacks into its army and jumps them out of a melee when they are hurt.",
	]},
	{"v": "0.14.19", "items": [
		"CROWN WORKERS take real jobs first and HAUL only when every job is taken: a new Labourer (or one whose Farm is full) goes to the nearest Farm or Powder Mill with room, and only when all of them are full does he become a hauler at the Town Hall (if it has a free hauler slot). FIX: until now a Town Hall's hauler slots counted as the nearest job, so every Crown game started with all four Labourers hauling and the starting Farm unworked. A rally on the ground still sends new workers to that spot.",
	]},
	{"v": "0.14.18", "items": [
		"CLOCKWORK, no more power (gear mode): steam and electricity are only looks now. The Boiler, the Charging Pylon (the tesla tower), the Engine Hall and the Capacitor Works are gone from the Clockwork's build list, and nothing that needs them or costs energy is trained; the Clocktower fills no batteries and no longer zaps flyers. The top bar shows cogs, TENSION and supply (no energy pill). The RATCHET TURRET is the Clockwork's new static defence (2x2, 125 cogs, 450 hp, needs a Movement Works): its head turns to the nearest enemy and fires big spinning screws at ground and air alike (14 damage every 1.5 s, range a little over a Musketeer's). Like every gear building it must stay linked to the gear field or it does not fire. The CLOCKWORK LAB starts with one (and no Pylon); the Clockwork computer builds one or two.",
	]},
	{"v": "0.14.17", "items": [
		"FIX: workers sent to a Feeding Pit, Farm or Powder Mill whose ground is spent no longer stand idle under a \"0/5\" with the wrong message \"fully crewed\": they go to the nearest site on fresh land, or, when there is none, you are told the ground is spent; a barren site's label now reads \"spent\". The CAMERA can now scroll 25 tiles past every edge of the map, so a base by the edge can be viewed centred (orders, rallies and buildings still stay on the map).",
	]},
	{"v": "0.14.16", "items": [
		"CLOCKWORK ARMY, first look (gear mode): the MOVEMENT WORKS, the Clockwork's barracks (4x3, 150 cogs), trains the CLOCK SOLDIER, a plain melee front-line soldier with a clock-hand sword and a pocket-watch shield (70 cogs, 90 hp, 1 armour, 10 damage). Its hanging line runs while it trains. The REGULATOR, a squat pendulum clock (2x2, 100 cogs, +10 supply), replaces the Spring Tower; its pendulum swings while it is linked. Every Clockwork building's ring now has a bolted iron FLOOR PLATE in its middle that the ring turns round. The CLOCKWORK LAB starts with a Movement Works, a Regulator and four Clock Soldiers too; the Clockwork computer builds Movement Works and Regulators and trains Clock Soldiers on the gear field.",
	]},
	{"v": "0.14.15", "items": [
		"CLOCKWORK GEAR FIELD, painted: the ground gear rings are now the painted brass-and-iron rings, with big chunky teeth (the same size on every ring) and a thick edge, lying on the ground at the camera's angle. Meshing rings turn with their teeth exactly in each other's gaps. Where two linked rings do not quite touch, a small IDLER cog sits between them and meshes both. The placement ghost shows its ring already turning meshed, with the idler it would get; a clash is washed red. Rings may overlap only about half a tooth now and link across a gap of up to 2 tiles. The Cog Press has its own painted art (built, building, damaged, wreck) and a working loop while Winders crank it. New Clockwork building: the MAINSPRING (3x3, up to 3 Winders), which winds TENSION, a second resource shown in the top bar (nothing spends it yet). The CLOCKWORK LAB now opens on the gear field: the Clocktower with two Cog Presses and a Mainspring meshing round it, Winders at work.",
	]},
	{"v": "0.14.14", "items": [
		"CLOCKWORK GEAR PROTOTYPE: the Clockwork's economy is now a field of turning GEARS instead of the Line. Every Clockwork building sits in a ring of toothed ground gears (small or big; the Clocktower has the biggest); meshing rings turn against each other. A building works only while its ring touches a ring that links back to a Clocktower: unlinked buildings stop and show UNLINKED, new buildings must be placed touching the field (the ghost shows its ring and LINKS / NO LINK), and constructs wind down off the gear ground. The Cog Press replaces the Ore Crusher: it pays COGS (the new resource, start 300) by itself and more for every Winder crewing it (small gear: faster, 3 Winders; big gear: 6 Winders, better only when full); 2 presses per Clocktower, each Clocktower holds a finite reserve of brass. GEAR SWAP (25 cogs, 4 s) changes a building's gear size. The AI places presses and links its buildings. Saves and online games carry gear sizes. The Line, trains and pressure are shelved behind Defs.line_mode (off). Art is placeholder. See docs/clockwork_gear_prototype.md.",
	]},
	{"v": "0.14.13", "items": [
		"CLOCKWORK TRAINS (Clockwork Lab): rail vehicles can be COUPLED into one train. Select two or more of the Work Car, Plate Wagon, Heavy Locomotive, Carrier Car, Tesla Locomotive and Storm Engine and press COUPLE (C): the one with a Heavy Locomotive (else another locomotive) leads and waits, the others drive to its last car and hook on, and driving a vehicle into an idle one hooks it on too. The train is one unit to command: tapping any car selects the whole train, it moves as one at the speed of its slowest car, holds its couplings round bends, loops and lanes, queues behind a slower train going the same way, and turns round by swapping ends so no wagon sticks out. Every car keeps its job: crews still build and mend, the Plate Wagon still blocks the track, Tesla Locomotives and Heavy Locomotives still fire, the Carrier Car still lands flyers. A Heavy Locomotive shields the other cars (15% less damage). UNCOUPLE (U) splits the train in front of the car you tapped; a car that dies breaks the train there and both parts carry on. Saves and online snapshots carry the trains. The Ore Train and Troop Train of the economy are separate and cannot be coupled to.",
		"FIX: a rail vehicle in its lane no longer gets pulled into a side branch it is only passing at a junction.",
	]},
	{"v": "0.14.12", "items": [
		"CLOCKWORK LINE, bigger and clearer: pipes and rails are drawn 1.5 times larger, trains and wagons too, and the wagons are coupled close behind the locomotive with a visible hook. The Line now has TWO tracks, one for each direction (drive on the right): trains going opposite ways pass each other, and a train only waits behind one going the same way. A Line that ends at a Drill or the Clocktower gets a LOOP of rail round (or beside) the building so trains turn round without backing up; the LINE preview shows it in amber with its cost. Where a loop does not fit, a train backs out of the dead end after a short pause and changes lane. Sidings now let a slow rail vehicle step aside so a faster one can pass.",
	]},
	{"v": "0.14.11", "items": [
		"FIX: with several Clockwork Winders selected, a shift-queue of buildings is shared out: each Winder takes a different building instead of only the first one working while the rest stood still.",
	]},
	{"v": "0.14.10", "items": [
		"FIX: VIEW MAP on the battle report works again: after the match you can pan, zoom, select and use the minimap while the report is hidden.",
	]},
	{"v": "0.14.9", "items": [
		"CLOCKWORK LAB (EDITOR menu, or the same switch in Settings): an experimental batch of Clockwork units to try and cut. Production: Tin Militia, Scrapper and Rail Rifleman at the Assembly Works; Work Car, Plate Wagon, Heavy Locomotive, Carrier Car, Tesla Locomotive and Storm Engine at the new Rail Yard. SIDINGS let rail vehicles pass each other on one track. The computer ignores all of it. Numbers are rough: see docs/clockwork_units_prototype.md.",
	]},
	{"v": "0.14.8", "items": [
		"CLOCKWORK: rails and ore trains. Every Line segment carries a rail. The Ore Drill replaces the Ore Crusher: it digs your Clocktower's ore, and Ore Trains (buy them at the Clocktower) carry it along the Line to the Clocktower. A train follows the pressure, keeps its distance from the train ahead (one rail carries at most about 24 ore a second), stops where the Line is cut or has no pressure, and enemies can shoot it. Troop Trains (RIDE) carry up to 8 soldiers along the Line. Winders no longer haul batteries. Sprites for pipes, relay, drill, locomotive and wagons are imported from the ChatGPT sheets.",
	]},
	{"v": "0.14.7", "items": [
		"CLOCKWORK: the LINE. Winders lay pipe segments (LINE button, then LAY) from a Clocktower or Boiler; Assembly Works, Engine Hall, Capacitor Works, Ore Crusher and Pylon must stand beside the Line and run at the speed the pressure allows. Pressure falls along the pipe; a Pressure Relay boosts it again. PRESSURE (or the ` key) shows the overlay; a building with no Line beside it says NO LINE. Enemies can shoot pipes, Winders repair them.",
	]},
	{"v": "0.14.6", "items": [
		"New home for the game: holdfastrts.github.io/Holdfast/ (the Android app is Holdfast.apk in the same place). The older addresses stop working after a while.",
	]},
	{"v": "0.14.5", "items": [
		"ONLINE room now looks and works like the SKIRMISH screen: the same player rows (PLAYER, FACTION, COLOUR, PLAN, TEAM), the 1v1 and CO-OP buttons on top, and the same map panel with the picker, preview and random pools. Everyone picks their own faction and colour (a colour another player has is refused); the host also sets the computer's level and plan, the teams and the map. A guest sees the same screen with the host's controls greyed out.",
	]},
	{"v": "0.14.4", "items": [
		"The game is now called HOLDFAST. New web address (cavaleirobrancopensante.github.io/Holdfast/) and the Android app file is Holdfast.apk. Your settings, saves and hotkeys on a computer or phone carry over; on the web build they start fresh because the address changed.",
	]},
	{"v": "0.14.3", "items": [
		"ONLINE: a COPY button next to the room code, so the host can paste it to a friend.",
	]},
	{"v": "0.14.2", "items": [
		"ONLINE now knows the relay address by itself: nobody has to paste anything, just press ONLINE, then host or join with the room code.",
	]},
	{"v": "0.14.1", "items": [
		"The game speaks three languages: English, Brazilian Portuguese and Spanish. Click a flag (US, Brazil, Spain) at the top right of the main menu, or pick LANGUAGE in Settings; it changes at once and is remembered. Menus, the match screen, unit and building names and descriptions, tips, the help pages and these patch notes are translated; the spoken unit, announcer and taunt voices have Portuguese and Spanish recordings too (the creature sounds and the music are the same in every language).",
		"Map names, music titles and the match log stay in English. How to add a language: docs/localisation.md.",
	]},
	{"v": "0.14.0", "items": [
		"ONLINE (first playable): one of you opens ONLINE, presses HOST A GAME and tells a friend the 4-letter room code; the friend presses JOIN. Web and Android play together. Modes: 1 vs 1, or you both against a computer (co-op). The host's device runs the match; the guest sees and plays it with about 0.1 to 0.2 s of delay.",
		"The relay that connects you is a free Cloudflare Worker (tools/relay/README.md has the steps). Paste its address under ONLINE or in SETTINGS.",
		"Not yet in an online match: sounds of fights from the friend's side, cannon and mortar shells in flight, pausing, reconnecting. A friend who leaves is replaced by a computer.",
	]},
	{"v": "0.13.7", "items": [
		"MINIMAP SOLIDITY slider in Settings and in the pause menu: from nearly see-through to fully solid (starts at 60%).",
	]},
	{"v": "0.13.6", "items": [
		"The minimap is see-through now (about 60% opaque), so you can see the battlefield behind it.",
	]},
	{"v": "0.13.5", "items": [
		"Brood computer: when the Crown has walled its ramp and the scouts are shut out, one Grub keeps watch at the foot of the ramp (it backs away from any armed unit and comes back when they have gone), so the Brood is no longer blind to a Crown rush.",
		"Brood computer: when it sees Horsemen it keeps its Raptors at home (no attack wave until its army, Raptors counting a third, is worth 1.2 times what it saw; a Raptor found far from the capital walks back), saves for the Brood Pen and Gorge Pit and hatches Spitters and Brutes. A Rush plan that sees Horsemen turns into a normal game.",
		"Crown computer: when more than 950 gold has sat unspent for 15 s it puts up a second Cottage if supply-blocked, researches whatever is missing and takes a Town Hall on fresh soil if the best land is under 60%.",
	]},
	{"v": "0.13.4", "items": [
		"The Brood capital's swamp reaches 5 tiles farther than other Burrows', so a normal main base is swamp from edge to edge (a very big main would not be fully covered).",
	]},
	{"v": "0.13.3", "items": [
		"The Crown computer now builds its first Cottage at the foot of its ramp as part of a wall: one Gate beside it (and a palisade piece only where a gap is left) seals the mouth, so the wall stands earlier and costs less. The Gate still lets its own army, workers and horses out.",
		"A labourer mends a damaged ramp wall, Gate or ramp Cottage while it is safe where he stands, and stops at once when enemies come near.",
		"A Brood wave that finds the ramp sealed breaks the Gate or palisade instead of milling about at the foot.",
	]},
	{"v": "0.13.2", "items": [
		"The computer's early rush (Horseman rush, Raptor rush, the Rush plan) now judges how it went: enemy value killed, riders left, defenders and workers seen. If it failed, the survivors ride home, new cavalry stay home as defence and it builds up before it attacks again; if it worked, a few Horsemen may finish the last workers, otherwise a bigger mop-up force goes out as one group.",
		"The computer no longer sends single soldiers into your base: units trained after an attack left wait at home and join only in groups, and a raiding party cut down to one rider is called back.",
	]},
	{"v": "0.13.1", "items": [
		"The Brood and the Clockwork have their own mouse cursors (pointer, attack, attack on an enemy, move, select, build, rally, forbidden, patrol), shown in a match of that faction; the menus keep the Crown's.",
		"Hover feedback: what the mouse is over is marked so you can see what an order will hit: a pulsing ring and a bobbing arrow on a unit (red for an enemy, green for yours or an ally's, yellow for a loose horse), corner brackets on a building.",
	]},
	{"v": "0.13.0", "items": [
		"The attack alarm is now a bell struck three times, a short gap, three more, over low war drums. The faction's voice says what was hit once it has rung.",
	]},
	{"v": "0.12.99", "items": [
		"Brood Burrows no longer need to stand 8 tiles apart: with deliveries going to the capital they own no ground, so you may build one right beside another (only the usual footprint and gap rules apply).",
	]},
	{"v": "0.12.98", "items": [
		"The attack alarm is now a low war horn calling twice over deep war drums, warmer and rounder than the sharp klaxon of 0.12.97.",
	]},
	{"v": "0.12.97", "items": [
		"One attack alarm for all three factions: a rising three-blast klaxon plays whenever your forces, workers, base or an ally are hit (not while you are looking at the fight), and the faction's voice says which about a second later.",
	]},
	{"v": "0.12.96", "items": [
		"Workers at war: a Grub or Labourer given the ATTACK command (a click on an enemy or an attack-move) now has the fight before its automatic WORK and REPAIR. It goes on from enemy to enemy until none is left in sight, and only then goes back to work. Any other order ends it.",
		"SURRENDER (and any defeat): the battle report has a VIEW MAP button. The report steps aside, the fog is lifted and you can roam the map to see what the enemy did; a small bar at the top brings the report back or leaves for the menu.",
	]},
	{"v": "0.12.95", "items": [
		"New Brood sounds from the designer's insect clips. The Grub no longer squeaks: sent off it skitters on insect feet, and selecting it gives a short, soft chitter. Spitters, Brutes, Spore Mothers, Bloaters and Mist Toads get the same insect feet when sent off; Brutes and Spore Mothers also roar from the monster clips (Spore Mother, Bloater and Mist Toad had no voice before).",
		"Brood deaths: a small insect cry for Grubs, Spitters, Bloaters, Mist Toads and Skywings, a deep long one for Brutes and Spore Mothers. Raptors keep their lizard voice.",
	]},
	{"v": "0.12.94", "items": [
		"Grubs told to ATTACK now fight: an attack-move makes them go and engage what they meet, like Raptors. (Idle grubs still never pick fights, and Labourers still just walk.)",
	]},
	{"v": "0.12.93", "items": [
		"Patrol now shows its path: a dashed light-blue line between the two ends with an arrowhead at each and a ring on the end the unit is walking to, for every selected unit that is patrolling. While you are choosing the patrol point, the walk there and back follows your mouse.",
	]},
	{"v": "0.12.92", "items": [
		"Camera views are F4-F10 now (seven tabs), so they no longer clash with the browser's full screen (F11) and developer tools (F12).",
	]},
	{"v": "0.12.91", "items": [
		"Group keys work as in StarCraft 2, with Ctrl and Shift only: Ctrl+number sets the group, Ctrl+Shift+number adds the selection to it, Shift+number adds the group to your selection. To drop a unit: select the group, Shift+click the unit off, Ctrl+number again. Alt is not used.",
	]},
	{"v": "0.12.90", "items": [
		"Group keys were briefly Shift adds, Ctrl sets, Ctrl+Shift removes (replaced in 0.12.91).",
	]},
	{"v": "0.12.89", "items": [
		"New hotkey bar above the selection card: IDLE (F1), ARMY (F2), MAKE (F3) and groups 1 2 3 4 5 6 7 8 9 0 in one row. The old quick buttons (and HALL) are gone from the bottom left; the room is given back.",
		"Groups: Shift+number adds the selection to the group, Ctrl+number removes the selected units from it, Alt+number sets it (it was Ctrl+number). The same with Shift/Ctrl/Alt+click on the bar. Ten groups now.",
		"F1 selects every idle worker, F3 (MAKE) every building that makes something, the Town Hall too.",
		"Camera views: nine tabs F4-F12 peek out above the bar. F4-F12 jump to a saved view, Shift+F4-F12 saves one; on a phone tap a tab to jump (an empty one saves), hold to save.",
		"Fixed: groups and camera views were lost when you left a match and came back; they are now kept in the autosave and when you leave to the menu.",
		"Hotkey bar buttons and command card buttons now look pressed for a moment when you use their key.",
		"Fixed: a selection of different buildings (4 Barracks and an Armoury) left the command card blank. It now shows everything they can do on one card (a unit goes to the least busy building that makes it, a research to the building that offers it); MORE or Tab flips to the next page when it does not fit.",
	]},
	{"v": "0.12.88", "items": [
		"Brood computer: its first Clutch Mound goes on the plateau by the top of the ramp, and the next ones on the low ground at the edge of its swamp nearest the enemy, so the swamp walks forward toward them.",
		"Swamp that loses its building (a destroyed Clutch Mound) now retreats gradually, one ring of tiles every half second from the outside in, instead of vanishing at once.",
	]},
	{"v": "0.12.87", "items": [
		"Brood: the Spore Vent and SEED VENT are gone. The Clutch Mound (the supply building) now spreads swamp itself (10 tiles, grows over a few seconds), so supply is something to plant forward and defend.",
		"Clutch Mound: must be built (by a grub, as before) on swamp joined to a Burrow's swamp. If a mound falls, the swamp only it held shrinks back (buildings left standing on it stay, but no longer count as joined, so nothing new can be placed there).",
		"Clutch Mound has new art with the Spore Vent's chimneys and a spore plume (built: ChatGPT drawing; under construction, damaged and destroyed are made from it in code, until ChatGPT redraws them).",
		"Brood computer: puts its Clutch Mounds out at the swamp's edge when its Feeding Pits have no room; its build timing is unchanged.",
	]},
	{"v": "0.12.86", "items": [
		"The swamp shimmer now takes its owner's colour (blue, red, yellow...), so swamp stands out from the ground on every map and you can tell whose swamp it is at a glance.",
	]},
	{"v": "0.12.85", "items": [
		"Brood swamp now shimmers slowly: soft waves of light and a little teal drift over it (one small shader on the whole layer, almost no cost), so it reads as alive instead of a flat dark patch.",
	]},
	{"v": "0.12.84", "items": [
		"Supply cap is 200 for every faction (was 100; 160 for the Brood). Bigger armies are possible, but each side still needs the supply buildings to get there.",
	]},
	{"v": "0.12.83", "items": [
		"Settings on a phone: the BACK button is pinned under the heading, so it is always on screen (the list below it scrolls).",
	]},
	{"v": "0.12.82", "items": [
		"Main menu: the version line at the bottom is bigger, bright and outlined, so it is easy to read.",
	]},
	{"v": "0.12.81", "items": [
		"Powder Mill: labourers now work a real round: dig a shovelful at a heap, walk with the loaded shovel along the front of the shed to the hopper, tip it in and walk back to the next heap. The six are staggered so they do not bunch. Powder output is unchanged.",
		"Powder Mill: the dirt track and grass edge are now drawn on the ground, under the labourers, instead of over their legs. They are still hidden behind the shed roof. (New loaded-shovel walk is a code-made placeholder, until ChatGPT redraws it.)",
	]},
	{"v": "0.12.80", "items": [
		"Brood: Spore Vents are no longer built by a grub. The capital and every finished Spore Vent have SEED VENT (E): pick a spot on joined swamp up to 10 tiles away and a new vent grows there (90 biomass, 16 s, no grub used). Each source grows one at a time; vents chain to spread the swamp far. ABANDON on the growing vent pays it all back. The Brood computer seeds its vents the same way.",
	]},
	{"v": "0.12.79", "items": [
		"Labourer walking south and south-east (and so south-west, with a sack or keg, and the Musketeers' legs): a real stride instead of a shuffle. Code placeholder: the east walk's stride squeezed under the body, until ChatGPT redraws it.",
	]},
	{"v": "0.12.78", "items": [
		"Supply tooltip now shows Workers, Army and In production supply. Computer: hover the supply number. Phone: tap the supply number.",
	]},
	{"v": "0.12.77", "items": [
		"Armoured Musketeer walking away from the camera now shows a steel back plate (taken from the dismounted Cuirassier).",
	]},
	{"v": "0.12.76", "items": [
		"Armoured Musketeer: fixed the steel armour being recoloured with the breeches; only the legs are silver-grey now.",
	]},
	{"v": "0.12.75", "items": [
		"Armoured Musketeer walk with the new legs in silver-grey breeches too, all directions; armour, helmet and musket unchanged.",
	]},
	{"v": "0.12.74", "items": [
		"Musketeer walk with the new legs (a proper alternating step) in his silver-grey breeches, all directions; tricorne and musket unchanged.",
	]},
	{"v": "0.12.73", "items": [
		"Art work files only: silver trousers option in the Musketeer preview tool (nothing changed in game).",
	]},
	{"v": "0.12.72", "items": [
		"Art work files only: cream trousers option in the Musketeer preview tool (nothing changed in game).",
	]},
	{"v": "0.12.71", "items": [
		"Art work files only: a preview tool for white trousers on the Musketeer (nothing changed in game).",
	]},
	{"v": "0.12.70", "items": [
		"Labourers carrying a sack or keg bob up and down as they walk again (the body rises at the passing steps).",
	]},
	{"v": "0.12.69", "items": [
		"Labourers walk at a calmer pace (12 frames a second at full speed, was about 20): the new legs no longer look like running, with or without a sack or keg.",
	]},
	{"v": "0.12.68", "items": [
		"Musketeer walk restored to the earlier art (tricorne with gold trim, musket in his hands); the plumed red-hat redraw is no longer used. The Armoured Musketeer keeps the musket in his hands with the new legs.",
		"Animation viewer: pinch with two fingers (or the mouse wheel) to zoom; tapping the note box now opens the keyboard.",
	]},
	{"v": "0.12.67", "items": [
		"Animation viewer on a phone: drag a list to scroll it, drag the picture to move it, CENTER puts it back; the right column scrolls too. COPY NAME copies 'unit / pose / direction / frame' to the clipboard so you can tell me which animation bothers you.",
	]},
	{"v": "0.12.66", "items": [
		"Brood AI builds a real army: it saves for the Spawning Den first and keeps its grubs down to a working minimum while the army is behind. New Extreme Rush strategy (Brood): Den at about 0:40, first Raptors about 1:20, attack about 1:40.",
		"Timing Attack now starts at 4:30; Rush and Extreme Rush send their first Raptors at the workers. Build timelines for every strategy are in docs/ai_build_timelines.md.",
	]},
	{"v": "0.12.65", "items": [
		"Animation viewer: switch pose and direction with buttons or the arrow keys (Left/Right = direction, Up/Down = pose, Q/E or Page Up/Down = unit, Space = pause, comma/period = frame). Units that still need art are marked with ! and can be filtered, with the reason shown.",
	]},
	{"v": "0.12.64", "items": [
		"Crown AI scouts for a rush, walls its ramp in time (about 2:00) and trains Musketeers behind it; against a Brood extreme rush it now holds with almost no workers lost.",
		"The AI scout knows the Brood's Raptors are a rush: foot-soldier proof is only used against the Crown.",
	]},
	{"v": "0.12.63", "items": [
		"Armoured Musketeers (all directions) and Musketeers (front and back) now walk with the new labourer legs: a proper alternating step.",
		"The Pikeman's files moved to a folder of obsolete units (he is not in the game).",
	]},
	{"v": "0.12.62", "items": [
		"Art work files only: an experiment tool that previews the labourer's new legs on other Crown units (nothing changed in game).",
	]},
	{"v": "0.12.61", "items": [
		"Labourers carrying a sack or a keg walk with the same new legs as the empty-handed walk, in all directions.",
	]},
	{"v": "0.12.60", "items": [
		"New labourer walk in all five directions, redrawn in the body's own style: his legs now alternate properly.",
	]},
	{"v": "0.12.59", "items": [
		"Art work files only: reference image for the labourer north walk prompt.",
	]},
	{"v": "0.12.58", "items": [
		"Art work files only: labourer south-east and north-east walk sheets saved for the coming walk redraw.",
	]},
	{"v": "0.12.57", "items": [
		"Art work files only: new labourer south walk sheet saved for the coming walk redraw.",
	]},
	{"v": "0.12.56", "items": [
		"AI worker safety: workers no longer all rush a small raid and die. They fight only when clearly stronger, otherwise they flee to a hall or open ground and go back to work once it is safe.",
	]},
	{"v": "0.12.55", "items": [
		"In-game chat: Enter on a computer, a speech-bubble quick-chat button on a phone.",
		"The AI says gg when its position is hopeless; reply gg and it resigns. The match log records chat and whether you were ahead or behind when you surrendered.",
	]},
	{"v": "0.12.54", "items": [
		"Walk cycles rebuilt with a real stride for the Missionary, Windup Soldier, Winder and Armoured Musketeer; Raptor improved.",
	]},
	{"v": "0.12.53", "items": [
		"Powder mill redrawn: a lean-to roof over the three ingredient piles and a wooden hopper by the millstone.",
	]},
	{"v": "0.12.52", "items": [
		"New labourer art: death, keg explosion death, bury, idle and walk redrawn in the new outfit; the side-view walk has a real stride.",
	]},
	{"v": "0.12.51", "items": [
		"Settings has an ANIMATION VIEWER: play any unit's animation in any direction, step frames, zoom, and flag frames to copy and send.",
	]},
	{"v": "0.12.50", "items": [
		"Powder mill: a roofed shed over three ingredient piles (saltpetre, sulphur, charcoal) and a hopper; labourers shovel each pile into the hopper in turn.",
	]},
	{"v": "0.12.49", "items": [
		"AI defence sizes its force to the enemy it sees: a lone horseman or scout draws at most a few fast units, never the whole army, and they are recalled after a short chase.",
		"The AI avoids sending units into ground covered by enemy artillery away from its own base, and reinforces when a real attack is winning.",
	]},
	{"v": "0.12.48", "items": [
		"Crown wall building: a sweep no longer deletes the rest of a wall right after a piece is finished.",
	]},
	{"v": "0.12.47", "items": [
		"AI scout now really attacks a gate or wall that blocks it.",
		"AI scout steps out of musketeer range and watches the ramp from a safe spot; it goes home if it keeps being shot, and remembers that the enemy has foot soldiers.",
	]},
	{"v": "0.12.46", "items": [
		"Led horses no longer get stuck in a gateway: they follow behind the leader or path around the wall.",
		"Horse delivery from the Breeder has stuck recovery (repath, then place the horse beside the recruit).",
	]},
	{"v": "0.12.45", "items": [
		"Labourer side and diagonal walk, carry and keg-carry: legs now step one foot after the other.",
	]},
	{"v": "0.12.44", "items": [
		"Build mode shows a tile grid around the ghost: blocked tiles tinted, narrow paths in amber, and a warning if the building would cut off or narrow a route. BUILD GRID on/off in Settings.",
	]},
	{"v": "0.12.43", "items": [
		"A ranged unit on high ground that fires at the low ground is revealed for about 2 seconds as a small spot of fog.",
	]},
	{"v": "0.12.42", "items": [
		"Gate lock symbol is half its size.",
	]},
	{"v": "0.12.41", "items": [
		"Cliff walls: the same soft shade on the low ground beside a wall's end.",
	]},
	{"v": "0.12.40", "items": [
		"Cliff walls: where walls step diagonally, the high ground beside the wall's end gets a soft shade, so the step is less abrupt.",
	]},
	{"v": "0.12.39", "items": [
		"Settings has a PATCH NOTES button (this page).",
		"Cliff walls: the ends where a wall steps are shaded softly instead of ending in a hard edge.",
		"Farm work uses the new hoe animation; the pickaxe is gone.",
	]},
	{"v": "0.12.38", "items": [
		"New work sounds: shovel and digging bites for farmers, hammering bites for builders.",
	]},
	{"v": "0.12.37", "items": [
		"Crown bugle and fife command calls from real recordings, softer; stop and hold calls.",
		"Sound priority system: fewer sounds at once, important ones duck the rest.",
		"Music, sound and ambience volume sliders in Settings and the pause menu.",
		"Horses are neutral: select them to hear them, move them only by leash or mount.",
		"Gate lock symbol above the gate: red closed lock, yellow open lock.",
		"AI answers a lone scout with at most two workers; the scout attacks a wall that blocks it.",
	]},
]


static func current() -> Dictionary:
	var ver: String = ProjectSettings.get_setting("application/config/version", "dev")
	for n in NOTES:
		if n["v"] == ver:
			return n
	return NOTES[0]


## The items of one entry in the chosen language (the English item where there is no translation:
## translations live in scripts/lang/patch_<code>.gd, built by tools/i18n_patch_build.py).
static func items(entry: Dictionary) -> Array:
	var en: Array = entry["items"]
	var tr: Dictionary = {}
	match Loc.lang:
		"pt":
			tr = PatchPt.N
		"es":
			tr = PatchEs.N
	if not tr.has(entry["v"]):
		return en
	var out: Array = []
	var t: Array = tr[entry["v"]]
	for i in en.size():
		out.append(t[i] if i < t.size() and t[i] != "" else en[i])
	return out
