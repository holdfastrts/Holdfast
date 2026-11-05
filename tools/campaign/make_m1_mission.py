#!/usr/bin/env python3
"""Writes campaign/missions/p01_leaf.json: mission 1, "The Leaf and the Fire" (the approved script:
docs/campaign_mission1.md; what was built: docs/campaign_m1_build.md). The mission is written here as Python so the fort's
walls (a piece per cell) and the waves stay readable; the JSON it writes is what the game reads.
  python3 tools/campaign/make_m1_mission.py
After changing a text: add its Portuguese and Spanish to tools/i18n/campaign/p01_leaf.txt and run
python3 tools/i18n_build.py (tools/test_campaign_m1.gd checks every text has both).
"""
import json
import os

STILL = "res://campaign/stills/%s.jpg"

# ---------------------------------------------------------------- the fort (rebel walls and gate)
FX0, FX1, FY0, FY1 = 104, 120, 28, 50
GATE = [(104, y) for y in range(37, 41)]
fort = []
for x in range(FX0, FX1 + 1):
    for y in (FY0, FY1):
        fort.append((x, y))
for y in range(FY0 + 1, FY1):
    for x in (FX0, FX1):
        fort.append((x, y))
walls = [{"team": "rebels", "kind": "gate" if c in GATE else "wall", "at": [c[0], c[1]], "tag": "fort_gate" if c in GATE else "fort_wall"}
         for c in fort]


def wave(tid, when, parts, say=None, extra=None):
    """A wave out of the fields: parts = [(area, role, kind, count)], all ordered to attack the plantation."""
    do = []
    for area, role, kind, n in parts:
        sp = {"team": "rebels", "kind": kind, "count": n, "at": area, "tag": "night"}
        if role:
            sp["as"] = role
        do.append({"spawn": sp})
    do.append({"order": {"tag": "night", "do": "attack", "to": "plantation"}})
    if say:
        do.append({"say": say})
    if extra:
        do.extend(extra)
    return {"id": tid, "when": {"all": [{"time": when}, {"not": {"fired": "dawn"}}]}, "do": do}


M = {
    "id": "p01_leaf",
    "title": "The Leaf and the Fire",
    "summary": "Virginia, 2767. Rebels of the Free Assembly come out of the tobacco fields by night. Hold the plantation until dawn, march on the fort they took, and break them at its gate.",
    "map": "campaign:virginia_leaf",
    "voice": "p01",
    "light": "night",
    "expansion_spots": False,
    "modes": ["solo", "coop", "versus"],
    "factions": {"free_assembly": {"name": "The Free Assembly", "stand_in": "crown", "campaign_only": True}},
    "sides": [
        {"id": "crown", "name": "The Crown", "about": "Lord Fairleigh, Governor of Virginia, his musketeers and Captain Ruggieri's guns."},
        {"id": "rebels", "name": "The Free Assembly", "about": "Rebels against Church and Crown, under Etienne Varenne. Green and black."},
    ],
    "teams": [
        {"id": "governor", "side": "crown", "faction": "crown", "colour": 4, "start": "none", "camera": "lawn", "gold": 500, "powder": 150,
         "control": {"solo": "p1", "coop": "p1", "versus": "p1"}},
        {"id": "guns", "side": "crown", "faction": "crown", "colour": 0, "start": "none", "camera": "lawn",
         "control": {"solo": "script", "coop": "p2", "versus": "script"}},
        {"id": "loyal", "side": "crown", "faction": "crown", "colour": 3, "start": "none", "camera": "hollins",
         "control": {"solo": "script", "coop": "script", "versus": "script"}},
        {"id": "rebels", "side": "rebels", "faction": "free_assembly", "colour": 2, "start": "none", "camera": "fort", "gold": 300,
         "control": {"solo": "script", "coop": "script", "versus": "p2"}},
    ],
    "areas": {
        "plantation": [6, 20, 26, 34], "manor": [8, 30, 18, 18], "lawn": [16, 32, 7, 8],
        "edge_n": [10, 7, 26, 3], "edge_ne": [38, 8, 8, 5], "edge_e": [44, 24, 4, 7], "edge_se": [38, 52, 7, 6],
        "edge_s": [12, 61, 20, 2],
        "camp1": [49, 31, 11, 9], "camp2": [76, 31, 11, 9], "road": [44, 34, 50, 10], "fork": [64, 30, 9, 12],
        "hollins": [62, 6, 18, 12],
        "before_gate": [86, 32, 15, 14], "kill_zone": [90, 32, 13, 14], "gate": [100, 35, 6, 8],
        "fort": [105, 29, 15, 21], "mass": [106, 33, 10, 12],
    },
    "units": [
        {"team": "governor", "kind": "dismounted", "count": 1, "at": [17, 38], "tag": "fairleigh", "name": "Lord Fairleigh"},
        {"team": "governor", "kind": "missionary", "count": 1, "at": [20, 31], "tag": "tomasz", "name": "Tomasz"},
        {"team": "governor", "kind": "musketeer", "count": 10, "at": "lawn", "tag": "line"},
        {"team": "governor", "kind": "labourer", "count": 4, "at": [14, 40]},
        {"team": "governor", "kind": "cannon", "count": 2, "at": [20, 35], "tag": "guns", "modes": ["solo", "versus"]},
        {"team": "guns", "kind": "cannon", "count": 2, "at": [20, 35], "tag": "guns", "modes": ["coop"]},
        {"team": "guns", "kind": "musketeer", "count": 3, "at": [21, 37], "modes": ["coop"]},
        # the fort: its guard on the walls, the mass that will charge (Varenne joins it at dawn)
        {"team": "rebels", "kind": "musketeer", "as": "militia", "count": 14, "at": "mass", "tag": "mass", "order": "hold"},
        {"team": "rebels", "kind": "pikeman", "as": "pikeman", "count": 8, "at": "mass", "tag": "mass", "order": "hold"},
        # the camps on the road
        {"team": "rebels", "kind": "musketeer", "as": "militia", "count": 6, "at": "camp1", "tag": "camp1", "order": "hold"},
        {"team": "rebels", "kind": "pikeman", "as": "pikeman", "count": 3, "at": "camp1", "tag": "camp1", "order": "hold"},
        {"team": "rebels", "kind": "musketeer", "as": "militia", "count": 7, "at": "camp2", "tag": "camp2", "order": "hold"},
        {"team": "rebels", "kind": "pikeman", "as": "pikeman", "count": 4, "at": "camp2", "tag": "camp2", "order": "hold"},
    ],
    "buildings": [
        {"team": "governor", "kind": "town_hall", "at": [10, 34], "tag": "manor"},
        {"team": "governor", "kind": "church", "at": [18, 28], "tag": "chapel"},
        {"team": "governor", "kind": "barracks", "at": [8, 44]},
        {"team": "governor", "kind": "powder_mill", "at": [16, 44]},
        {"team": "governor", "kind": "cottage", "at": [3, 29]},
        {"team": "governor", "kind": "cottage", "at": [3, 33]},
        {"team": "governor", "kind": "cottage", "at": [3, 41]},
        {"team": "governor", "kind": "farm", "at": [24, 30], "tag": "barns"},
        {"team": "governor", "kind": "farm", "at": [24, 38], "tag": "barns"},
        {"team": "governor", "kind": "farm", "at": [6, 22], "tag": "barns"},
        {"team": "governor", "kind": "farm", "at": [14, 22], "tag": "barns"},
        {"team": "governor", "kind": "farm", "at": [20, 48], "tag": "barns"},
        {"team": "loyal", "kind": "farm", "at": [68, 9], "tag": "hollins_farm"},
        {"team": "rebels", "kind": "town_hall", "at": [111, 30], "tag": "fort_hall"},
        {"team": "rebels", "kind": "barracks", "at": [112, 44]},
    ] + walls,
    "wiped_out": {"crown": 0},
    "objectives": [
        {"id": "rising", "side": "crown", "primary": True, "kind": "manual", "text": "Put down the rising."},
        {"id": "manor", "side": "crown", "primary": True, "kind": "protect", "tag": "manor", "text": "The manor must stand."},
        {"id": "barns", "side": "crown", "primary": True, "kind": "protect", "tag": "barns", "text": "Do not let every drying barn burn."},
        {"id": "dawn", "side": "crown", "primary": True, "kind": "survive", "time": 480, "text": "Hold until dawn, with at least three barns standing."},
        {"id": "camps", "side": "crown", "primary": True, "kind": "manual", "hidden": True, "text": "Clear the two rebel camps on the road."},
        {"id": "families", "side": "crown", "primary": False, "kind": "manual", "hidden": True, "text": "Save the families at Hollins Farm."},
        {"id": "gate", "side": "crown", "primary": True, "kind": "reach", "hidden": True, "area": "before_gate", "side_units": "crown", "count": 6,
         "text": "Bring the army before the fort's gate."},
        {"id": "charge", "side": "crown", "primary": True, "kind": "manual", "hidden": True, "text": "Break their charge with canister."},
        {"id": "burn", "side": "rebels", "primary": True, "kind": "destroy", "tag": "manor", "text": "Burn the Governor's manor."},
        {"id": "ash", "side": "rebels", "primary": False, "kind": "destroy", "tag": "barns", "text": "Burn every drying barn."},
    ],
    "triggers": [
        # ---------------------------------------------------------------- part 1: hold until dawn (night)
        {"id": "intro", "when": {"time": 1}, "do": [{"say": ["p1_fair", "p1_rugg", "p1_tip"]}, {"ping": {"area": "edge_n"}}]},
        {"id": "intro_rebels", "when": {"time": 1}, "modes": ["versus"], "do": [{"say": ["r_intro"]}]},
        wave("w1", 25, [("edge_n", "militia", "musketeer", 4), ("edge_n", "torch", "labourer", 2)], ["v_1", "r_1"]),
        wave("w2", 85, [("edge_e", "militia", "musketeer", 5), ("edge_e", "torch", "labourer", 3), ("edge_e", "pikeman", "pikeman", 2)], ["t_1"]),
        {"id": "varenne", "when": {"time": 140}, "do": [
            {"spawn": {"team": "rebels", "kind": "dismounted", "as": "varenne", "count": 1, "at": "edge_ne", "tag": "varenne", "order": "hold"}},
            {"spawn": {"team": "rebels", "kind": "pikeman", "as": "pikeman", "count": 3, "at": "edge_ne", "tag": "guard", "order": "hold"}},
            {"say": ["v_2", "f_1"]}, {"ping": {"area": "edge_ne"}}]},
        {"id": "varenne_off", "when": {"fired": "varenne"}, "delay": 40, "do": [
            {"order": {"tag": "varenne", "do": "move", "to": "fort"}}, {"order": {"tag": "guard", "do": "move", "to": "fort"}}]},
        wave("w3", 150, [("edge_n", "militia", "musketeer", 5), ("edge_n", "pikeman", "pikeman", 3), ("edge_ne", "torch", "labourer", 3)], ["r_2"]),
        wave("w4", 225, [("edge_e", "militia", "musketeer", 6), ("edge_e", "torch", "labourer", 3), ("edge_n", "pikeman", "pikeman", 4)], ["v_3"]),
        {"id": "leaf", "when": {"time": 260}, "do": [{"say": ["r_leaf", "f_leaf"]}]},
        wave("w5", 300, [("edge_n", "militia", "musketeer", 5), ("edge_e", "militia", "musketeer", 4), ("edge_n", "pikeman", "pikeman", 4),
                         ("edge_se", "torch", "labourer", 3), ("edge_n", "torch", "labourer", 1)], ["v_4", "t_2"]),
        wave("w6", 385, [("edge_e", "militia", "musketeer", 6), ("edge_se", "pikeman", "pikeman", 4), ("edge_s", "torch", "labourer", 3)], ["r_3"]),
        wave("w7", 440, [("edge_n", "torch", "labourer", 3), ("edge_n", "militia", "musketeer", 3)], ["t_lauds"],
             [{"light": {"to": "dawn", "secs": 40}}]),
        {"id": "barn_hit", "when": {"hurt": "barns"}, "do": [{"say": ["f_barn"]}]},
        {"id": "barn_lost", "when": {"count": {"tag": "barns", "buildings": True, "below": 5}}, "do": [{"say": ["t_barn"]}]},
        {"id": "manor_hit", "when": {"hurt": "manor"}, "do": [{"say": ["f_manor"]}]},
        # dawn: with fewer than three barns standing the year is lost; else the rebels fall back and the march begins
        {"id": "dawn_lost", "when": {"all": [{"done": "dawn"}, {"count": {"tag": "barns", "buildings": True, "below": 3}}]}, "do": [
            {"say": ["f_ash"]}, {"lose": "crown"}]},
        {"id": "dawn", "when": {"all": [{"done": "dawn"}, {"count": {"tag": "barns", "buildings": True, "at_least": 3}}]}, "do": [
            {"light": {"to": "dawn", "secs": 4}},
            {"order": {"tag": "night", "do": "move", "to": "fort"}},
            {"say": ["f_dawn", "r_dawn", "p2_tip"]},
            {"objective": {"id": "camps", "set": "active"}},
            {"spawn": {"team": "governor", "kind": "musketeer", "count": 6, "at": "manor", "tag": "relief"}},
            {"give": {"team": "governor", "gold": 300, "powder": 100}},
            {"reveal": {"area": "camp1", "side": "crown", "secs": 30}}, {"ping": {"area": "camp1"}},
            {"order": {"tag": "varenne", "do": "move", "to": "mass"}}]},
        {"id": "versus_dawn", "when": {"fired": "dawn"}, "modes": ["versus"], "do": [{"say": ["r_dawn_v"]}]},
        {"id": "day", "when": {"fired": "dawn"}, "delay": 90, "do": [{"light": {"to": "day", "secs": 60}}]},
        # ---------------------------------------------------------------- part 2: the road
        {"id": "camp1_down", "when": {"all": [{"fired": "dawn"}, {"dead": "camp1"}]}, "do": [
            {"spawn": {"team": "loyal", "kind": "labourer", "count": 6, "at": "hollins", "tag": "families", "order": "hold"}},
            {"spawn": {"team": "rebels", "kind": "musketeer", "as": "militia", "count": 4, "at": [72, 15], "tag": "raiders", "order": "hold"}},
            {"spawn": {"team": "rebels", "kind": "labourer", "as": "torch", "count": 1, "at": [68, 15], "tag": "raiders"}},
            {"say": ["t_smoke", "f_choice"]},
            {"reveal": {"area": "hollins", "side": "crown", "secs": 25}}, {"ping": {"area": "hollins"}},
            {"choice": {"id": "families", "side": "crown", "default": "leave", "time": 120,
                        "title": "Hollins Farm is burning, and loyal families are trapped there.",
                        "options": [
                            {"id": "save", "label": "SAVE THE FAMILIES",
                             "about": "March north and drive off the raiders. The rebels will have time to dig in at the fort.",
                             "do": [{"say": ["f_save"]}, {"objective": {"id": "families", "set": "active"}},
                                    {"spawn": {"team": "rebels", "kind": "musketeer", "as": "militia", "count": 6, "at": "mass", "tag": "mass", "order": "hold"}},
                                    {"spawn": {"team": "rebels", "kind": "pikeman", "as": "pikeman", "count": 4, "at": "mass", "tag": "mass", "order": "hold"}},
                                    {"build": {"team": "rebels", "kind": "wall", "at": [101, 36], "tag": "earthworks"}},
                                    {"build": {"team": "rebels", "kind": "wall", "at": [101, 41], "tag": "earthworks"}}]},
                            {"id": "leave", "label": "MARCH ON",
                             "about": "Keep to the road and strike the fort before it is ready. Tomasz will remember.",
                             "do": [{"say": ["f_leave"]}]}]}}]},
        {"id": "raiders_go", "when": {"fired": "camp1_down"}, "delay": 6, "do": [{"order": {"tag": "raiders", "do": "attack", "to": "hollins"}}]},
        {"id": "saved", "when": {"all": [{"flag": {"families": "save"}}, {"dead": "raiders"}, {"count": {"tag": "families", "at_least": 1}}]}, "do": [
            {"objective": {"id": "families", "set": "done"}}, {"say": ["t_saved", "f_late"]},
            {"order": {"tag": "families", "do": "move", "to": "plantation"}}]},
        {"id": "families_lost", "when": {"all": [{"flag": {"families": "save"}}, {"dead": "families"}]}, "do": [
            {"objective": {"id": "families", "set": "failed"}}, {"say": ["t_toolate"]}]},
        {"id": "left", "when": {"flag": {"families": "leave"}}, "delay": 40, "do": [
            {"hurt": {"tag": "hollins_farm", "amount": 2000}}, {"hurt": {"tag": "families", "amount": 500}}, {"say": ["t_left"]}]},
        {"id": "camps_clear", "when": {"all": [{"fired": "dawn"}, {"dead": "camp1"}, {"dead": "camp2"}]}, "do": [
            {"objective": {"id": "camps", "set": "done"}}, {"objective": {"id": "gate", "set": "active"}},
            {"say": ["f_fort"]}, {"reveal": {"area": "before_gate", "side": "crown", "secs": 20}}, {"ping": {"area": "before_gate"}}]},
        # ---------------------------------------------------------------- part 3: the gate
        {"id": "at_gate", "when": {"done": "gate"}, "do": [
            {"say": ["r_mass", "f_canister_load", "tip_canister"]},
            {"point": {"ui": "card", "icon": "ab_canister"}},
            {"objective": {"id": "charge", "set": "active"}},
            {"reveal": {"area": "fort", "side": "crown", "secs": 30}}]},
        {"id": "dug_in", "when": {"all": [{"fired": "at_gate"}, {"flag": {"families": "save"}}]}, "delay": 3, "do": [{"say": ["r_dug"]}]},
        {"id": "on_my_word", "when": {"fired": "at_gate"}, "delay": 22, "do": [{"say": ["v_5", "f_word"]}, {"point": {}}]},
        {"id": "charge_go", "when": {"any": [{"fired": "on_my_word"}, {"all": [{"fired": "camps_clear"}, {"hurt": "mass"}]}]},
         "delay": 6, "do": [
            {"order": {"tag": "mass", "do": "attack", "to": "before_gate"}},
            {"order": {"tag": "varenne", "do": "attack", "to": "before_gate"}},
            {"order": {"tag": "night", "do": "attack", "to": "before_gate"}},
            {"say": ["v_charge"]}]},
        {"id": "fire", "when": {"all": [{"fired": "charge_go"}, {"count": {"tag": "mass", "area": "kill_zone", "at_least": 4}}]}, "do": [{"say": ["f_fire"]}]},
        {"id": "varenne_down", "when": {"dead": "varenne"}, "do": [{"say": ["r_varenne"]}]},
        {"id": "broken", "when": {"all": [{"fired": "charge_go"}, {"any": [
            {"all": [{"not": {"flag": {"families": "save"}}}, {"count": {"tag": "mass", "below": 6}}]},
            {"all": [{"flag": {"families": "save"}}, {"count": {"tag": "mass", "below": 8}}]}]}]}, "do": [
            {"objective": {"id": "charge", "set": "done"}}, {"objective": {"id": "rising", "set": "done"}}]},
    ],
    "speakers": {
        "king": {"name": "The King", "side": "crown"},
        "tomasz": {"name": "Tomasz", "side": "crown"},
        "fairleigh": {"name": "Lord Fairleigh", "side": "crown"},
        "ruggieri": {"name": "Captain Ruggieri", "side": "crown"},
        "varenne": {"name": "Varenne", "side": "rebels"},
    },
    "lines": {
        # the opening (StillShow over the stills)
        "k_open1": {"who": "king", "text": "You ask how the world came to burn. Sit. Let an old man light his pipe first. The leaf is from Virginia. It is fitting. That is where it began."},
        "k_open2": {"who": "king", "text": "In those days the sun did not set on the Crown. From Rome to the farthest islands there was one faith, one law, one King. We were not perfect. But we were at peace, and we thought peace was the natural state of things."},
        "k_open3": {"who": "king", "text": "Virginia gave us its golden leaf, and gave its sons to the seminaries. That summer a young Pole, Tomasz Wierzbicki, waited there for his ship to Rome."},
        "t_open3": {"who": "tomasz", "text": "I remember the smell of the drying barns, and how quiet the evenings were. I was reading Augustine under the oak. I thought I knew what evil was."},
        "k_open4": {"who": "king", "text": "Then came the men who called themselves the Free Assembly. Free of God, free of their King, free of every bond that had kept them fed and safe. They began, as such men always do, with fire."},
        "f_open5": {"who": "fairleigh", "text": "Captain Ruggieri, run out the guns. No man burns the King's leaf while I stand on these steps."},
        "t_open5": {"who": "tomasz", "text": "He did not raise his voice. He did not need to."},
        # the ending
        "t_end": {"who": "tomasz", "text": "I prayed for them that morning, and I pray for them still. But I never again believed that disorder was a kind of mercy."},
        "k_end": {"who": "king", "text": "Fairleigh ended the rising in a single morning. We thought it was over. It was the first spark."},
        # part 1
        "p1_fair": {"who": "fairleigh", "text": "Musketeers to the barns. Captain, your guns on the lawn. We hold until the sun comes up."},
        "p1_rugg": {"who": "ruggieri", "text": "The guns are run out, my lord. Let them come into the light."},
        "p1_tip": {"who": "ruggieri", "to": "crown", "text": "Train more men at the Barracks, my lord. Kill the torch-bearers first: a barn they reach will burn."},
        "v_1": {"who": "varenne", "text": "No king but the people! Burn the leaf of the tyrants!"},
        "r_1": {"who": "ruggieri", "text": "Give fire!"},
        "t_1": {"who": "tomasz", "text": "They carried pitchforks and torches, and some of them were boys. I knelt by the first one who fell. He was already gone."},
        "v_2": {"who": "varenne", "text": "Free of priests! Free of lords! Liberty or the grave!"},
        "f_1": {"who": "fairleigh", "text": "That is their orator. He shouts from the dark and sends others into the light."},
        "r_2": {"who": "ruggieri", "text": "Steady, gentlemen. Let them close. Then give it to them."},
        "v_3": {"who": "varenne", "text": "Every barn that burns is a chain broken!"},
        "r_leaf": {"who": "ruggieri", "text": "A whole year's leaf, my lord. I could weep. I shall want my pipe after this."},
        "f_leaf": {"who": "fairleigh", "text": "You shall have it, Captain. And they shall have the guns."},
        "v_4": {"who": "varenne", "text": "Now, brothers! All of you! Let it burn!"},
        "t_2": {"who": "tomasz", "text": "They burned the curing sheds with families sleeping beside them. I learned that night what their freedom meant."},
        "r_3": {"who": "ruggieri", "text": "Fewer of them now. Keep firing."},
        "t_lauds": {"who": "tomasz", "text": "Then the sky went grey over the woods, and the chapel bell rang for Lauds."},
        "f_barn": {"who": "fairleigh", "text": "A barn is alight. Drive them off it!"},
        "t_barn": {"who": "tomasz", "text": "The first barn fell in. The leaf went up like incense, and the smell was everywhere."},
        "f_manor": {"who": "fairleigh", "text": "They are at the house. To the manor!"},
        "f_ash": {"who": "fairleigh", "text": "The leaf is ash. Virginia has lost its year, and we have lost Virginia."},
        "f_dawn": {"who": "fairleigh", "text": "Dawn. They are falling back to the fort. We follow."},
        "r_dawn": {"who": "ruggieri", "text": "Limber the guns! Down the road!"},
        "p2_tip": {"who": "ruggieri", "to": "crown", "text": "Two camps lie on the road to the fort. A cannon must be limbered to march and set up again to fire."},
        "r_intro": {"who": "varenne", "to": "rebels", "text": "Tonight we burn their leaf and their manor. Out of the fields, brothers!"},
        "r_dawn_v": {"who": "varenne", "to": "rebels", "text": "Back to the fort! Let them come to our walls."},
        # part 2
        "t_smoke": {"who": "tomasz", "text": "Smoke to the north, my lord. Hollins Farm. The families there are loyal, and they are trapped."},
        "f_choice": {"who": "fairleigh", "text": "Every hour we spend there, they dig in at the fort."},
        "f_save": {"who": "fairleigh", "text": "We do not leave the King's people to burn. North."},
        "f_leave": {"who": "fairleigh", "text": "The fort first. God keep them."},
        "t_saved": {"who": "tomasz", "text": "They came out of the smoke carrying their children. A woman kissed the Governor's hand. He did not know where to look."},
        "f_late": {"who": "fairleigh", "text": "To the road again. We are late."},
        "t_toolate": {"who": "tomasz", "text": "We came too late. I said the prayers for the dead over them, and we marched on."},
        "t_left": {"who": "tomasz", "text": "We saw the smoke of Hollins Farm for an hour. No one spoke of it. I have prayed for those families every year since."},
        "f_fort": {"who": "fairleigh", "text": "The road is clear. The fort."},
        # part 3
        "r_mass": {"who": "ruggieri", "text": "They are massing behind the gate, my lord. Hundreds of them."},
        "f_canister_load": {"who": "fairleigh", "text": "Bring the guns up. Load canister."},
        "tip_canister": {"who": "ruggieri", "to": "crown", "phone": "Tap a cannon, then CANISTER on its card. Canister reaches short and cuts down a crowd.",
                         "text": "Select a cannon and press CANISTER on its card. Canister reaches short and cuts down a crowd."},
        "r_dug": {"who": "ruggieri", "text": "They have had time to dig in. More of them than I would like."},
        "v_5": {"who": "varenne", "text": "Brothers! Their guns are few! One charge and Virginia is free!"},
        "f_word": {"who": "fairleigh", "text": "Canister. On my word."},
        "v_charge": {"who": "varenne", "text": "Forward! For the people!"},
        "f_fire": {"who": "fairleigh", "text": "Fire."},
        "r_varenne": {"who": "ruggieri", "text": "Their orator is down."},
    },
    "stills": {
        "pipe": {"image": STILL % "p01_01", "caption": "Rome, the present. The King lights his pipe."},
        "map": {"image": STILL % "p01_02", "caption": "The Crown's dominions, from Rome to the farthest islands."},
        "plantation": {"image": STILL % "p01_03", "caption": "A tobacco plantation in Virginia, 2767. Tomasz reads under the oak."},
        "rebels": {"image": STILL % "p01_04", "caption": "The Free Assembly comes out of the fields with torches."},
        "governor": {"image": STILL % "p01_05", "caption": "Lord Fairleigh on the manor steps; the guns are run out."},
        "canister": {"image": STILL % "p01_06", "caption": "Canister at the fort's gate, at dawn."},
    },
    "opening": [
        {"still": "pipe", "lines": ["k_open1"]},
        {"still": "map", "lines": ["k_open2"]},
        {"still": "plantation", "lines": ["k_open3", "t_open3"]},
        {"still": "rebels", "lines": ["k_open4"]},
        {"still": "governor", "lines": ["f_open5", "t_open5"]},
    ],
    "ending": {"crown": [{"still": "canister", "lines": ["t_end", "k_end"]}]},
    "briefing": {
        "crown": {"still": "governor", "text": [
            "Virginia, 2767. The Free Assembly has risen against Church and Crown, and tonight it comes for the plantation.",
            "Hold the manor and the drying barns until dawn. Then march down the road, clear the rebel camps, and break them at the fort they took.",
            "Kill the torch-bearers first. Keep the guns: you will need canister at the gate."]},
        "rebels": {"still": "rebels", "text": [
            "Virginia, 2767. You are the Free Assembly. Tonight your men come out of the tobacco fields.",
            "Burn the Governor's manor before dawn. At dawn fall back to the fort and hold its gate."]},
    },
    "debrief": {
        "crown": {"still": "canister", "title": "The rising is broken",
                  "text": "Lord Fairleigh ended the rising in a single morning. Virginia's leaf was saved, and Tomasz sailed for Rome."},
        "rebels": {"still": "rebels", "title": "Virginia burns",
                   "text": "The manor fell and the leaf burned. The Free Assembly's fire spread along the coast."},
    },
    "next": {"crown": "", "rebels": ""},
}

out = os.path.join(os.path.dirname(__file__), "..", "..", "campaign", "missions", "p01_leaf.json")
with open(out, "w") as f:
    json.dump(M, f, indent="\t", ensure_ascii=False)
print("wrote", os.path.normpath(out), len(walls), "fort pieces")
