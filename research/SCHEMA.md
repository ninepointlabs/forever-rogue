# research/data.json schema (Forever Rogue)

Same shape as Tazu's Addon (`/home/tim/Projects/tazus-addon/research/SCHEMA.md` and its `research/data.json`, read them for
examples) with Rogue additions in a third part (`parts/rogue.json`) and a `pvp` object modelled on Tristan's Addon
(`/home/tim/Projects/tristans-addon/research/data.json` key `pvp`). **Read the sister repos only; never edit them.**

`BRIEF.md` §7 and §9 summarise the research with sources; `research/raw/` holds the archived pages (HTML + MD),
`research/ids.json` the spell/item IDs linked on each Icy Veins page, `research/bis_endgametools_parsed.txt` / `bis_top.txt`
the parsed endgametools BiS lists, `research/spells_by_level_endgametools.txt` the client spell list by level,
`research/talents_rogue*.json` the talent trees (Icy Veins calculator data, versions 70959 current and 70755 for build links).

## Rules (every part)

- **Every record** (list item or dict) carries `source_url` (the page the fact came from, the original URL, not the raw file name)
  and `checked` (`"2026-11-19"` for pages fetched 2026-11-19, or the date of a sister record you copy).
- **Never invent** spell IDs, item IDs, quest IDs, NPC IDs, coordinates, rates, prices, stats, costs, cooldowns or durations.
  Use only what a raw page states. IDs come from links in the raw HTML (`item=NNN`, `/item/NNN`, `spell=NNN`, `quest=NNN`, `npc=NNN`)
  or `ids.json`. Unknown -> omit the field (or `null`) and add a `gaps[]` entry.
- Conflicts -> `conflicts[]` (`{topic, detail, source_url, checked}`) with both sides; pick neither.
- Facts from **one secondary/low-confidence site only** (wowfdb, endgametools, conquestcapped, warcrafttavern, kickegg, zockify,
  wowcamp, warcraftmaps, wowguide, foreverguide, mobalytics, GoldScout) get `"unconfirmed": true` and a short `"flag"`.
- Crowdsourced GoldScout numbers additionally get `"community": "GoldScout"` and `sample_n`.
- Spell names are the exact English in-game names. Talent-taught spells are named `"<Name> (talent)"` in `spells_by_level`.
- Specs: `"Assassination"`, `"Combat"`, `"Subtlety"`. Factions: `"Alliance"`, `"Horde"`, `"Both"`.
- Races (Forever rogues): Human, Dwarf, Gnome, Night Elf, Skyborne (Alliance); Orc, Troll, Undead, Windshaper Skyborne (Horde).
  `races` fields use `"Human"`, `"Dwarf/Gnome"`, `"Night Elf"`, `"Orc/Troll"`, `"Undead"`, `"Skyborne"`, `"All"` (a slash list is fine).
- Plain ASCII-friendly text is preferred (the build maps curly quotes and dashes to ASCII anyway).

## Part 1: `research/parts/core.json`

- `meta`: copy Tazu's `meta` and change `class: "Rogue"`, `latest_build_seen: "1.60.1.70959 (omaforge clients on TUF, 2026-11-19)"`,
  `talent_calc_version: "70959-a8fe1dab"`, `talent_calc_note` (build links use 70755-6b631983 / 70755-c04a9251), `checked: "2026-11-19"`.
  Keep `toc_interface: 16001`, `max_level: 60`, `wow_project_id`.
- `sources`: `{ short_key: url }` for every page used.
- `spells_by_level`: `[{ name, rank_learn_levels: [..], spell_id?, category, school?: "Physical"|"Nature"|null, talent_tree?, quest?,
  reagent?: "Flash Powder"|"Blinding Powder"|..., energy?: N (only if sourced), notes?, unconfirmed?, flag?, source_url, checked }]`.
  `category` is one of `builder`, `finisher`, `opener`, `stealth`, `cc`, `interrupt`, `defense`, `cooldown`, `movement`, `utility`, `poison`, `passive`.
  All trainer spells 1-60 from the endgametools client list (levels) cross-checked with wowfdb abilities/utility pages; talent spells
  (Riposte, Blade Flurry, Adrenaline Rush, Cold Blood, Mutilate, Hemorrhage, Ghostly Strike, Premeditation, Preparation, Death Mark)
  as `(talent)` with `talent_tree` and `rank_learn_levels` from the tree row (`required_points + 10` = first level; record later ranks
  from endgametools if listed). Include Pick Pocket, Pick Lock (level conflict -> conflicts[]), Redirect, Poised, Shank, Detect Traps,
  Disarm Trap, Safe Fall, Vanish (reagent Flash Powder), Blind (reagent Blinding Powder), Sap, Distract, Kidney Shot, Cheap Shot,
  Expose Armor, Feint, Evasion, Sprint, Kick, Gouge, Garrote, Ambush, Rupture, Slice and Dice, Eviscerate, Sinister Strike, Backstab, Stealth.
- `talent_and_other_spell_ids`: `[{ name, spell_id, tree?, kind: "talent"|"buff"|"debuff"|"racial"|"proc", max_rank?, required_points?, notes?, source_url, checked }]`
  every talent in `research/talents_rogue.json` (spell_id = the first rank id from that file) plus auras the addon reads by name
  (Slice and Dice, Stealth, Vanish, Adrenaline Rush, Blade Flurry, Evasion, Sprint, Cold Blood, Rupture, Garrote, Expose Armor, Death Mark,
  Venom, Riposte proc if any). IDs only if sourced (else `null`).
- `milestones`: `{ items: [{level, what, source_url, checked}], talent_milestones, trainer_costs?, respec, source_url, checked }` (1 Redirect, 4 Pick Pocket,
  10 Blade of Cunning quest + dual wield + talents, 15/16 lockpicking quest, 20 poisons quest + Riposte, 22 Vanish, 24 Shank, 26 Cheap Shot,
  30 Blade Flurry/Hemorrhage/Kidney Shot, 34 Blind, 40 Adrenaline Rush/Death Mark/dual spec/riding, 50 Ravenholdt...).
- `talent_changes`: `[{ tree: "Assassination"|"Combat"|"Subtlety"|"Baseline", stage, change, source_url, checked }]` (deep dive, Nov 2 rework, Nov 16/17 hotfix).
- `builds`: `[{ spec, purpose, talent_calc_url, notes?, source_url, checked }]`: every `data-talentcalculator-pointsurl="#tc-...~VERSION"` link on the
  Icy Veins rogue pages (7 links: assassination/combat/subtlety leveling + spec-builds pages; combat builds page has two). Full URL =
  `https://www.icy-veins.com/wow-forever/rogue-talent-calculator#tc-...~VERSION`. Use the heading around each link as `purpose`.
  `python3 tools/ivcalc.py` decodes them (all 7 are 51 points).
- `rotations`: `{ assassination, combat, subtlety, energy, poisons, sources, source_url, checked }` short sourced summaries naming spells exactly.
- `stat_priority`: `[{ spec, priority: "A > B > C", notes?, source_url, checked }]` for Assassination, Combat, Subtlety (and `Leveling` if sourced).
  Tokens allowed: `Weapon DPS`, `Weapon damage`, `Hit`, `Expertise`, `Crit`, `Agility`, `Strength`, `Attack power`, `Stamina` (parentheses allowed for notes,
  e.g. `Hit (to 8%)`). Haste is not a token (notes only).
- `quests`: `[{ type: "class"|"breadcrumb"|"lockpicking"|"poisons"|"repeatable", level, races, faction, name, quest_id?, zone?, start_npc?, coords?,
  steps?: [..], reward?, reward_items?: [{name, item_id}], reward_spell?, needs?: "Lockpicking 75"|..., notes?, unconfirmed?, flag?, source_url, checked }]`.
  Every chain from Icy Veins rogue-class-quests (Human Seek out SI:7 ... Blade of Cunning 7298; Dwarf/Gnome; Night Elf; Orc/Troll; Undead; Skyborne none),
  the lockpicking quests (conquestcapped, unconfirmed), the level-20 poisons quests (Alliance Klaven's Tower, Horde Mission: Possible But Not Probable),
  Horn of Xelthos, The Manor Ravenholdt, The Eye of Bhossca, A Simple Request / The Perfect Poison, Junkboxes Needed (unconfirmed). Put each chain's
  steps in order; quest IDs only from links.
- `class_trainers`: `{ trainers: [{name, place, faction, npc_id?}], note, respec_note, source_url, checked }` (BRIEF §7.2; unknown rosters -> gap).
- `racials`: rogue races' racials only as sourced (Human Ruthless +1% crit; Gnome/Undead per Icy Veins); others -> gap.
- `race_notes`: `{ text, source_url, checked }`.
- `changes_log`: `[{ date, change, source_url, checked }]` Rogue-relevant dated changes (deep dive, Nov 2 rework, Nov 16/17 hotfixes, wowfdb change log).
- `conflicts`, `gaps`: as above (include every BRIEF §9 item that concerns core data).

## Part 2: `research/parts/gear.json`

- `gear_by_bracket`: `[{ bracket: "level 10"|"level 20"|"level 30"|"level 40"|"level 50"|"level 19"|"level 29"|"level 39"|"level 49"|"level 59"|"level 60 pre-raid",
  spec?: "Assassination"|"Combat"|"Subtlety"|null, name, item_id, slot, source, source_type?: "quest"|"dungeon"|"world drop"|"crafted"|"vendor"|"rep"|"pvp",
  level?, faction?, weapon_type?: "Dagger"|"Sword"|"Mace"|"Fist"|"Axe"|"Bow"|"Crossbow"|"Gun"|"Thrown", speed?, stats?, notes?, unconfirmed?, flag?, source_url, checked }]`
  from the Icy Veins leveling pages (all three specs; faction from the page), the Icy Veins BiS pages, and the endgametools BiS pages
  (`bis_endgametools_parsed.txt`: brackets 49/59/60; keep the first-choice item per slot as `notes: "first choice"`; endgametools is secondary -> unconfirmed).
  Item IDs only from links/parsed files.
- `other_weapons`: `{ note, rules: [{spec, rule}], source_url, checked }` (daggers for Backstab/Ambush/Mutilate; slow main hand for Sinister Strike/Riposte;
  Subtlety "15 DPS 1.9 speed < 14 DPS 2.8 speed"; Hack and Slash and axes conflict).
- `bis`: `{ status, flag, source_url, checked }`.
- `consumables_enchants`: `[{ type, spec?, name, item_id?, notes?, source_url, checked }]` only if sourced (Icy Veins/Wowhead pages archived; else gap).
- `professions`: `{ leveling, raiding?, alternatives: [...], note (Rip has Skinning + Mining; do not tell him to drop them), source_url, checked }`.
- `riding`, `zones_by_level`, `new_zones`, `dungeons`, `raids`, `raid_rules`, `roadmap`, `addons`, `addon_dev`: copy from Tazu's data.json
  (race-independent facts keep their source_url/checked), then add Rogue-relevant items from the rogue leveling pages
  (Riverglades, Alcaz Prison, City of Dalaran, The Drowned City, Excavation Site: Wetlands, Hall of Thanes, Ruins of Lordaeron) only where sourced.
  `zones_by_level` rows need `levels`, `alliance`, `horde`, `dungeons`.
- `mounts`: rows for Human (Alliance) and every rogue race only if a source states trainer/vendor; otherwise copy what Tazu/Tristan/Andric/Parzelle have
  for those races (check `/home/tim/Projects/{tristans-addon,wow-forever-priest-addon,parzelles-addon}/research/data.json` `mounts`), else gap.
- `change_sources`: copy Tazu's list and add rogue pages (wowfdb rogue changes, Blizzard hotfix article 24315281).

## Part 3: `research/parts/rogue.json`

- `poisons`: `[{ name: "Instant Poison"|"Instant Poison II"|..., base: "Instant Poison", rank, learn_level, item_id?, effect, charges?, duration_min: 30,
  reagents?: [{name, item_id?, count?}], vendor?, notes?, unconfirmed?, flag?, source_url, checked }]` (BRIEF §7.2 poison ranks; wowfdb).
- `poison_rules`: `{ skill_line: "Poisons", unlock: "level-20 class quest", unlock_quest_by_faction: {Alliance, Horde}, stacks_with_temp_enchant: true,
  max_rank_hotfix: "2026-11-16", charges_note, ap_scaling_note, suggested: [{spec, main_hand, off_hand, why}], source_url, checked }`.
- `pickpocket_targets`: `[{ mob, npc_id?, level_min, level_max, zone, faction_note?, junkbox?: "Battered"|"Worn"|"Sturdy"|"Heavy", chance_pct?, sample_n?,
  notes, community?: "GoldScout", source_url, checked, unconfirmed: true, flag }]` (every row of the GoldScout item pages 16882-16885, pickpocket rows
  only, plus fan-guide spots like BRD, Tanaris Wastewanders, Southsea Pirates, SM, STV Bloodsail; plus seed hints for 4-20 if a source names them).
- `junkboxes`: `[{ name, item_id, lock_skill, mob_level_range, source: "pickpocket", contents?, source_url, checked, unconfirmed?, flag? }]` (Battered 16882 ... Heavy 16885).
- `lockboxes`: `[{ name, item_id?, lock_skill, mob_level_range, source: "drop", source_url, checked, unconfirmed?, flag? }]` (Ornate Bronze ... Eternium).
  Classic lock values: flag that Forever's DB shows placeholder values.
- `lockpick_rules`: `{ cap_per_level: 5, cast_time_s: 5, range_yd: 5, tools: {name: "Thieves' Tools", item_id: 5060}, notes, source_url, checked }`.
- `lockpick_route`: `[{ skill_from, skill_to, zone, spot, coords?: [x, y], object, faction: "Alliance"|"Horde"|"Both", notes, source_url, checked, unconfirmed: true, flag }]`.
- `lock_doors`: `[{ dungeon, what, skill, source_url, checked, unconfirmed?, flag? }]`.
- `bags`: `[{ name, item_id?, slots, source_type: "quest"|"drop"|"vendor"|"craft"|"rep"|"world drop", source, zone?, level?, faction?, races?, price?, bop?,
  source_url, checked, unconfirmed?, flag? }]` (BRIEF §7.10, Wowhead bags page archived as wowhead_forever_guide_bags_storage_bank.md).
- `bag_rules`: `{ backpack: 16, bag_slots: 4, reagent_bag: true, bank_slots, bank_bag_slots, notes, source_url, checked }`.
- `gold_farms`: `[{ level_min, level_max, zone, spot, method: "pickpocket"|"kill"|"lockbox"|"gather"|"service", what_sells, faction, coords?, notes?, source_url, checked, unconfirmed?, flag? }]`.
- `gold_tips`: `[{ title, body, source_url, checked, unconfirmed?, flag? }]`.
- `weapon_skills`: `[{ skill, rogue_default: bool, trainable: bool, trainers: [{npc, city, faction, coords?: [x,y], teaches?}], notes?, source_url, checked }]`
  (Wowhead weapon trainer page archived as wowhead_forever_guide_weapon_trainer_skill_locations.md; axes conflict).
- `rogue_supplies`: `[{ name, item_id?, for: "Vanish"|"Blind"|"Pick Lock"|"Poisons"|..., vendor?, notes?, source_url, checked, unconfirmed? }]`
  (Flash Powder 5140, Blinding Powder, Thieves' Tools 5060, Thistle Tea 7676, poison reagents if sourced, else gap).
- `legacy_perks`: `[{ name, what, rogue_note?, source_url, checked }]` (wowfdb legacy page: Reagent Economy and others relevant to rogues).
- `stealth_notes`: `[{ title, body, source_url, checked, unconfirmed? }]` (Sap no longer breaks Stealth, Distract lowers detection, Master of Deception...).
- `pvp`: copy Tristan's `pvp` object keys `summary`, `rulesets`, `honor`, `rank_points`, `ranks`, `rank_titles`, `gear_path`, `battlegrounds`, `queue`,
  `call_to_arms`, `seasonal`, `limits`, `api_notes` (keep their source_url/checked; rewrite Paladin-specific text out; `gear_path` must not mention Paladins),
  and add `rogue_notes: [{title, body, source_url, checked, unconfirmed?, flag?}]` (BRIEF §7.13 + wowfdb pvp page) and
  `poison_choices: [{poison, when, source_url, checked}]`, `gear: [{bracket, name, item_id?, slot, source, source_url, checked, unconfirmed?, flag?}]` only where sourced.
- `conflicts`, `gaps`, `sources`.

## Merge
`python3 research/merge.py` merges `parts/core.json` + `parts/gear.json` + `parts/rogue.json` into `data.json`
(`gaps`/`conflicts` concatenated, `sources` merged, any other duplicate key is an error).
