# content/learn.json

Hand-written teaching and rotation content for **Learn the Rogue** and the **Rotation** tab. `tools/build_data.py` turns it into `Data/Learn.lua`.

Rules (the weekly recheck must keep to them):

- Only facts from `research/data.json` or the archived pages behind it (`research/raw/`). Every entry lists `sources` (URLs).
- Anything not stated by a source, stated by only one third-party site, or conflicting between sources gets `"unconfirmed": true` and a short `"flag"`. The addon shows the flag in-game.
- Don't invent numbers (costs, coefficients, cooldowns, durations, drop rates). Conflicts (Pick Lock level, Mutilate level, Flawless Execution -10 vs -15, Feint doubled vs ~5x, poison unlock level, one-handed axes) are stated as conflicts, never decided.
- Spell keys match the trainer/talent spell names exactly (`spells_by_level[].name` without " (talent)"); talent keys match `research/talents_rogue.json`.
- Forever changes come first: Sap no longer breaks Stealth; Distract lowers detection; combo points survive a target switch; Redirect, Poised, Shank, Venom, Mutilate (row 7), Death Mark, Hack and Slash are new; poisons are their own skill line from the level-20 class quest and stack with sharpening stones/weightstones.
- The addon serves every Rogue race and both factions. An entry may carry `"faction": "Alliance"|"Horde"` or `"races"`; the addon hides other-faction entries. Rip (Human, Alliance) is the test character, not the only reader.

## Sections

`version`, `checked`, `spells`, `talents`, `mechanics`, `rogue` (articles on poisons, pick pocket, lockpicking, stealth, combo points, energy), `roles`, `leveling` (per spec), `mistakes`, `lessons` (unlock at `level`, optional `spec`, `faction`), `first_learn_hints`, `rotation`.

`mechanics[]` entries may carry `"topic": "energy"` (shown on Rotation › Energy). `rogue[]` articles show on Learn › Poisons & pockets and on the Poisons / Pockets & Locks screens (`"topic": "poisons"|"pockets"|"locks"|"stealth"|"combo"`).

`rotation.<Assassination|Combat|Subtlety>.<solo|dungeon|raid>` = `{ summary, kind: "damage", priority: [{spell, when, note}], tips, unconfirmed, flag, sources }`.

`when` must be one the engine (`Modules/Rotation.lua`) understands:
`always`, `manual` (listed for reading, never suggested by the on-screen helper), `ready`, `usable`, `in_combat`, `out_of_combat`, `in_melee`,
`stealthed`, `not_stealthed`, `buff_missing` (your buff named like the step's spell is missing), `debuff_missing` (the target's debuff named like the step's spell is missing),
`poison_missing` (a weapon has no poison/temp enchant), `cp_at_least:N`, `cp_below:N`, `energy_at_least:N`, `energy_below:N`, `target_hp_below:N`,
`proc:<Buff name>`, `buff_missing:<Buff name>`, `buff_up:<Buff name>`, `target_debuff_missing:<Debuff name>`.
`tests/run.lua` fails if a step uses anything else or names a spell the research doesn't know.

After editing: `python3 tools/build_data.py && lua5.1 tests/run.lua`.
