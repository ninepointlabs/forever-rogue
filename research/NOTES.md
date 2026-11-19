# Research notes (Forever Rogue)

Starting summary for whoever rechecks the data. The full research brief (BRIEF.md, kept local) has the cited tables;
`sources.md` lists every archived page; `SCHEMA.md` is the data contract.

- **Pipeline:** `parts/core.json` (spells, talents, builds, rotations, stats, quests, trainers, racials, changes),
  `parts/gear.json` (gear by bracket, weapons, professions, world, riding, mounts, change sources) and
  `parts/rogue.json` (poisons, pickpocket targets, junkboxes, lockboxes, Lockpicking route and doors, bags, gold,
  weapon skills, supplies, legacy perks, stealth notes, PvP) -> `merge.py` -> `data.json` -> `tools/build_data.py` -> `Data/*.lua`.
- **Talent trees:** Icy Veins calculator data, `talents_rogue.json` (70959-a8fe1dab, current) plus the two 70755 versions
  the build links use. `tools/ivcalc.py` decodes all 7 builds to 51 points.
- **Item sources:** `item_sources.json` from `tools/fetch_item_sources.py` (Icy Veins DB, 2026-11-19): 163 items, 102 with a source.
- **API limits that shape the addon:** no combat log; other units' values secret in combat; inside instances creature
  names/GUIDs are secret (pickpocket log degrades to "unknown mob, <zone>"); secure buttons use `type=macro` + macrotext,
  change only out of combat, no Bindings.xml, no /click, no Super binds.
- **Big caveats:** lock values are Classic values (Forever's DB shows placeholders); GoldScout numbers are crowdsourced with
  small samples; endgametools BiS is computed (secondary); only the level-60 endgametools lists were archived (19-59 are a gap).
- Conflicts and gaps live in `data.json` (`conflicts[]`, `gaps[]`) and show in game under Settings > About the data.
