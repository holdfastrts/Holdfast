# Mission 1 voice lines (p01_leaf, "The Leaf and the Fire")

Recorded lines drop in as files, one per line: `campaign/voice/p01/<line id>.ogg` (`.wav` or `.mp3` work too). The game plays
a line's file when it is there and stays silent when not (scripts/campaign/campaign_voice.gd); the line waits for its
recording to finish before the next one. Godot must import the files once (open the project in the editor, or
`godot --headless --import`). Voices: the KING (the owner records him in ElevenLabs: an old man, warm, unhurried, a
pipe in his hand), TOMASZ (young, Polish, quiet; the same man years later as a priest), LORD FAIRLEIGH (English,
stern, never raises his voice), CAPTAIN RUGGIERI (Italian, a gunner), VARENNE (French orator, shouting).

Lines marked *to crown* / *to rebels* are heard only by that side (tips, versus lines). `tip_canister` has a phone
version of its words (the same recording can serve both).

| # | line id | speaker | where | text |
| --- | --- | --- | --- | --- |
| 1 | `k_open1` | THE KING | opening | You ask how the world came to burn. Sit. Let an old man light his pipe first. The leaf is from Virginia. It is fitting. That is where it began. |
| 2 | `k_open2` | THE KING | opening | In those days the sun did not set on the Crown. From Rome to the farthest islands there was one faith, one law, one King. We were not perfect. But we were at peace, and we thought peace was the natural state of things. |
| 3 | `k_open3` | THE KING | opening | Virginia gave us its golden leaf, and gave its sons to the seminaries. That summer a young Pole, Tomasz Wierzbicki, waited there for his ship to Rome. |
| 4 | `t_open3` | TOMASZ | opening | I remember the smell of the drying barns, and how quiet the evenings were. I was reading Augustine under the oak. I thought I knew what evil was. |
| 5 | `k_open4` | THE KING | opening | Then came the men who called themselves the Free Assembly. Free of God, free of their King, free of every bond that had kept them fed and safe. They began, as such men always do, with fire. |
| 6 | `f_open5` | LORD FAIRLEIGH | opening | Captain Ruggieri, run out the guns. No man burns the King's leaf while I stand on these steps. |
| 7 | `t_open5` | TOMASZ | opening | He did not raise his voice. He did not need to. |
| 8 | `p1_fair` | LORD FAIRLEIGH | part | Musketeers to the barns. Captain, your guns on the lawn. We hold until the sun comes up. |
| 9 | `p1_rugg` | CAPTAIN RUGGIERI | part | The guns are run out, my lord. Let them come into the light. |
| 10 | `p1_tip` | CAPTAIN RUGGIERI | part *to crown* | Train more men at the Barracks, my lord. Kill the torch-bearers first: a barn they reach will burn. |
| 11 | `r_intro` | VARENNE | part *to rebels* | Tonight we burn their leaf and their manor. Out of the fields, brothers! |
| 12 | `v_1` | VARENNE | part | No king but the people! Burn the leaf of the tyrants! |
| 13 | `r_1` | CAPTAIN RUGGIERI | part | Give fire! |
| 14 | `t_1` | TOMASZ | part | They carried pitchforks and torches, and some of them were boys. I knelt by the first one who fell. He was already gone. |
| 15 | `v_2` | VARENNE | part | Free of priests! Free of lords! Liberty or the grave! |
| 16 | `f_1` | LORD FAIRLEIGH | part | That is their orator. He shouts from the dark and sends others into the light. |
| 17 | `r_2` | CAPTAIN RUGGIERI | part | Steady, gentlemen. Let them close. Then give it to them. |
| 18 | `v_3` | VARENNE | part | Every barn that burns is a chain broken! |
| 19 | `r_leaf` | CAPTAIN RUGGIERI | part | A whole year's leaf, my lord. I could weep. I shall want my pipe after this. |
| 20 | `f_leaf` | LORD FAIRLEIGH | part | You shall have it, Captain. And they shall have the guns. |
| 21 | `v_4` | VARENNE | part | Now, brothers! All of you! Let it burn! |
| 22 | `t_2` | TOMASZ | part | They burned the curing sheds with families sleeping beside them. I learned that night what their freedom meant. |
| 23 | `r_3` | CAPTAIN RUGGIERI | part | Fewer of them now. Keep firing. |
| 24 | `t_lauds` | TOMASZ | part | Then the sky went grey over the woods, and the chapel bell rang for Lauds. |
| 25 | `f_barn` | LORD FAIRLEIGH | part | A barn is alight. Drive them off it! |
| 26 | `t_barn` | TOMASZ | part | The first barn fell in. The leaf went up like incense, and the smell was everywhere. |
| 27 | `f_manor` | LORD FAIRLEIGH | part | They are at the house. To the manor! |
| 28 | `f_ash` | LORD FAIRLEIGH | part | The leaf is ash. Virginia has lost its year, and we have lost Virginia. |
| 29 | `f_dawn` | LORD FAIRLEIGH | part | Dawn. They are falling back to the fort. We follow. |
| 30 | `r_dawn` | CAPTAIN RUGGIERI | part | Limber the guns! Down the road! |
| 31 | `p2_tip` | CAPTAIN RUGGIERI | part *to crown* | Two camps lie on the road to the fort. A cannon must be limbered to march and set up again to fire. |
| 32 | `r_dawn_v` | VARENNE | part *to rebels* | Back to the fort! Let them come to our walls. |
| 33 | `t_smoke` | TOMASZ | part | Smoke to the north, my lord. Hollins Farm. The families there are loyal, and they are trapped. |
| 34 | `f_choice` | LORD FAIRLEIGH | part | Every hour we spend there, they dig in at the fort. |
| 35 | `f_save` | LORD FAIRLEIGH | part | We do not leave the King's people to burn. North. |
| 36 | `f_leave` | LORD FAIRLEIGH | part | The fort first. God keep them. |
| 37 | `t_saved` | TOMASZ | part | They came out of the smoke carrying their children. A woman kissed the Governor's hand. He did not know where to look. |
| 38 | `f_late` | LORD FAIRLEIGH | part | To the road again. We are late. |
| 39 | `t_toolate` | TOMASZ | part | We came too late. I said the prayers for the dead over them, and we marched on. |
| 40 | `t_left` | TOMASZ | part | We saw the smoke of Hollins Farm for an hour. No one spoke of it. I have prayed for those families every year since. |
| 41 | `f_fort` | LORD FAIRLEIGH | part | The road is clear. The fort. |
| 42 | `r_mass` | CAPTAIN RUGGIERI | part | They are massing behind the gate, my lord. Hundreds of them. |
| 43 | `f_canister_load` | LORD FAIRLEIGH | part | Bring the guns up. Load canister. |
| 44 | `tip_canister` | CAPTAIN RUGGIERI | part *to crown* | Select a cannon and press CANISTER on its card. Canister reaches short and cuts down a crowd. |
| 45 | `r_dug` | CAPTAIN RUGGIERI | part | They have had time to dig in. More of them than I would like. |
| 46 | `v_5` | VARENNE | part | Brothers! Their guns are few! One charge and Virginia is free! |
| 47 | `f_word` | LORD FAIRLEIGH | part | Canister. On my word. |
| 48 | `v_charge` | VARENNE | part | Forward! For the people! |
| 49 | `f_fire` | LORD FAIRLEIGH | part | Fire. |
| 50 | `r_varenne` | CAPTAIN RUGGIERI | part | Their orator is down. |
| 51 | `t_end` | TOMASZ | ending | I prayed for them that morning, and I pray for them still. But I never again believed that disorder was a kind of mercy. |
| 52 | `k_end` | THE KING | ending | Fairleigh ended the rising in a single morning. We thought it was over. It was the first spark. |
