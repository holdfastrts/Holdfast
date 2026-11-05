# Old units, obsolete for now

Files of units that are no longer in the game, kept in case they come back. Godot ignores this folder (.gdignore).

- pikeman/ : (BACK FOR THE CAMPAIGN since 0.31.0: his strips were copied to assets/units/pikeman, thrust_* named attack_*, his icon and voice too; he is the Free Assembly's pikeman in mission 1, campaign only: docs/campaign_m1_build.md. This folder keeps the originals.) art strips (units/), voice lines (voice/), icon. The Pikeman was removed (the Musketeer's bayonet does his job); a saved Pikeman loads as a Musketeer. Its sprite entry was removed from scripts/art_data.gd. NOTE: tools/import_art.py, import_round10.py and fix_weapons.py still know the pikeman and would write assets/units/pikeman again and re-add the art_data entry if tools/rebuild_art.sh is run in full; delete those pikeman lines first, or move the folder again afterwards. The combat sound combat/pikeman_attack stays in assets/audio (the bayonet uses it).
