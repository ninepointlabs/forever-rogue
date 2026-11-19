# STATUS: Forever Rogue (2026-11-19)

**What it is:** the WoW Forever-only, do-everything Rogue companion. It covers every Rogue race and both factions; **Rip** (Human Rogue, Alliance, realm `CAMWOWUS2Realm1PvE`, Normal/PvE, level 4 in Northshire Valley) is the test character and the persona in About and the docs. Its headline feature is a **Pick Pocket log with earnings**. It follows Tazu's Addon's structure, window, data pipeline and tests, and Tristan's Addon's PvP module pattern. Tim approved coding on 2026-11-19.

**Repo:** https://github.com/ninepointlabs/forever-rogue (public, default branch `main`, topics `wow-addon` + `world-of-warcraft`), local `/home/tim/Projects/forever-rogue`, `origin` set. Created and pushed 2026-11-19 at Tim's request. Commits use `Nine Point Labs <179739321+ninepointlabs@users.noreply.github.com>` (repo-local git config).
- **Released:** **v0.1.0** on 2026-11-19 at Tim's request: https://github.com/ninepointlabs/forever-rogue/releases/tag/v0.1.0 (annotated tag on `3e29473`, `main`). Before tagging, `omaforge clients` reported Forever 1.60.1.70959 / Interface 16001, matching both TOCs.
  - **GitHub Actions never started on push events in this repo** (not for the pushes to `main`, not for the tag), although Actions is enabled and GitHub's status page showed no incident. CI was run by hand (`workflow_dispatch`, run 44571153136: all steps pass).
  - So the release zip was **built locally from the `v0.1.0` tag** the way the BigWigs packager does it (Tazu's v0.1.1 zip used as the reference): `ForeverRogue/` with the two TOCs (`## Version: v0.1.0`), LICENSE, Core, Data, Modules, UI and a short CHANGELOG.md (71 files), plus `release.json` (flavor `forever`, interface 16001). Uploaded with `gh release create`. Release notes are a short feature summary; no autonomix-cli line because the release ships no Linux executables.
  - `release.yml` now also has `workflow_dispatch`, so a future tag can be packaged by hand if push events still don't fire. Worth checking why push triggers don't fire (repo settings / GitHub support).
- **OmaForge:** `omaforge search -c forever ninepointlabs/forever-rogue` resolves `github:ninepointlabs/forever-rogue` **v0.1.0, compatible**. A plain search ("forever rogue", "rogue") lists it after the CurseForge results (`-p github` shows it first). I cleared five stale entries from omaforge's 1-hour search cache (`~/.cache/omaforge/http`) that predated GitHub indexing the repo. I did **not** run `omaforge install` against the live AddOns folder.
- `main` and `feature/initial-addon` point at the same commits: Tim asked for a push and an OmaForge-installable addon, not a PR, so `main` was fast-forwarded to the branch (no base-commit-plus-PR as in Tazu's repo).
- **Not done (not authorized):** no CurseForge/Wago, no Pages setting, no DNS (`docs/CNAME` is the file only), no email or social posts. Nothing was installed into the live WoW folder.
- **Kept local:** `BRIEF.md` is gitignored because it names Tim's account/WTF path. `research/raw/` (archived pages) is gitignored, as in the sister repos.

## Decisions

**Tim decided (2026-11-19):**
1. The name is **Forever Rogue**, with one slash command, **`/frogue`**.
2. **Junkbox/lockbox values** use Auctionator prices when Auctionator is installed and loaded, and vendor prices otherwise.
   - Implementation: `C_AddOns.IsAddOnLoaded("Auctionator")`, then `Auctionator.API.v1.GetAuctionPriceByItemLink` (and `…ByItemID`), every call guarded by `pcall`. The vendor price is the 11th return of `GetItemInfo`.
   - Each value is labelled "AH (Auctionator)" or "Vendor".
   - The TOC has `## OptionalDeps: Auctionator`.
3. **GoldScout's crowdsourced pickpocket numbers ship**, labelled "Community data (GoldScout)" with the sample size (n) and an unconfirmed badge. They sit beside the player's own best mobs and are credited in About, Sources & notes and the README.
4. **PvP is in v0.1.**

**Defaults (Tim hasn't decided; all still his to change):**
1. **Names:** folder/TOC `ForeverRogue`, SavedVariables `ForeverRogueDB` / `ForeverRogueCharDB`, repo folder `forever-rogue`, future site `forever-rogue.myazerothlife.com` (CNAME file only). `## X-Website` points to `github.com/ninepointlabs/forever-rogue`, which doesn't exist yet.
2. **Leveling spec:** Combat to 40, then dual spec Combat (A) + Subtlety (B). The picker marks Combat "recommended for leveling". It describes Subtlety as the solo/PvP alternative and Assassination as coming online with Mutilate.
3. **Pick Pocket log:** keeps the last **2,000** entries per character in a ring buffer. Session, day and lifetime totals, plus per-mob and per-zone totals, are never trimmed.
4. **Buttons ship:** the **Pick Lock button** and the **two poison buttons**. They are secure macros, work out of combat only, one press = one action, with no keybinds by default and Super/Meta refused.
5. **Website and README are text only**, with no Rip art.
6. **Pocket refill timer:** defaults to **10 minutes**. That is a fan-site figure (kickegg); conquestcapped says "a few minutes". The setting offers 5, 10, 15 or 20 minutes, and repeats on the same mob are measured and shown next to it.
7. **Sidebar:** PvP sits under *Play* (Rotation, Gear, PvP). The brief's §4.1 screen list didn't place it.
8. **Gold screen:** v0.1 ships a simple version: session by source, history, farms, tips. The fuller gold/hour work is v0.2 per the brief.

## What works (verified headlessly, 2026-11-19)

| Check | Result |
|---|---|
| `lua5.1 tests/run.lua` | **39/39 pass** |
| `python3 tools/build_data.py --check` | `Data/*.lua up to date` |
| `python3 tools/ivcalc.py` (51-point check) | All **7** Icy Veins build links decode on Forever's trees, **each exactly 51 points**: Assassination leveling 31/15/5, Mutilate 33/18/0, Combat leveling, Sinister Strike and Backstab builds 16/35/0, Subtlety leveling 12/8/31, Bleed 15/5/31. "0 need attention". |
| `python3 tools/rogue-changes-poller/tests/test_poller.py` | 5/5 pass |
| Lua syntax | Every `.lua` in the repo loads with `lua5.1` |
| `tools/install-dev.sh <scratch dir>` | Copies only the TOCs, Core, Data, Modules, UI and LICENSE (64 files) |
| `omaforge clients` (TUF, 2026-11-19) | Forever `1.60.1.70959`, Interface `16001`. This matches both TOCs. |
| Website | `docs/index.html` parses. I haven't viewed it in a browser. |
| CI | `.github/workflows/test.yml` adds a 51-point step. It hasn't run: there is no remote. |

**What the tests cover.** The strict WoW mock treats undefined globals as errors. It loads every TOC file and renders every screen and sub-tab for all three specs at levels 1, 24, 40 and 60. Brief §11 cases:
- **Level 1 with no spec:** the picker recommends Combat and lays out the Combat + Subtlety dual-spec plan.
- **Level 4 Human in Northshire (Rip):**
  - Home shows **Seek out SI:7** (level 10) as the next class quest and the **Book Bag** (Book Return) as the next bag.
  - The Pick Pocket log and Home show the empty state, and Poisons points to the class quest.
- **Level 20 before the poison quest:** the Poisons screen names *Mathias and the Defias*, and no poison buttons appear.
- **Level 24 with Shank:** Shank is in the rotation and cooldowns, and untaken talents stay hidden.
- **Level 40 dual spec:** Combat/Subtlety profiles follow `ACTIVE_TALENT_GROUP_CHANGED`.
- **Level 60 secret-values run:** with the target, cooldowns, own Energy, combo points and weapons all secret, every value shows "hidden". Suggestions flag hidden info and nothing is guessed.
- **Instance mode:** with names and GUIDs secret, the log records "unknown mob, Blackrock Depths". Coin and items are still counted, and no GUID is kept.
- **Faction filtering:** Rip sees no Horde or other-race class quests, and Horde Undead sees only Horde quests.
- **Bag math:** free slots and the next upgrade, filtered by race and faction.
- **Lockpicking:** cap math (level × 5, capped at 300) and the junkbox skill colours.
- **Money attribution:** pickpocket, loot, merchant, mail, quest and other.
- **Junkbox value:** with Auctionator mocked present (AH price), absent (vendor price), and throwing an error (falls back to vendor).
- **GoldScout rows** carry the Community data label, n= and the unconfirmed flag.
- **The log trims at 2,000** while lifetime and per-mob totals keep counting.
- **PvP** renders at levels 10, 30 and 60.
- **`/frogue`** opens and toggles the window, and no second slash command exists.
- **No leftover text:** no Shaman, Paladin, Mage, Priest or sister-addon text in code or the window, except About links and sourced data such as the mob "Syndicate Shadow Mage".

Also covered:
- **Pick Lock button:** `type=macro` with `/cast Pick Lock` + `/use <bag> <slot>`, lowest-requirement box first.
  - Disarmed when there is no box you can open.
  - Frozen in combat; key override bindings work, and keys can't be set in combat.
- **Poison buttons:**
  - `/use <poison>` + `/use 16|17`, with the best rank in your bags and Icy Veins' Instant (main hand) / Deadly (off hand).
  - A poison **and** a sharpening stone on one weapon are both read.
  - The button disarms while the poison is on and re-arms under 5 minutes; a stone alone stays armed; a pinned poison overrides the suggestion.
  - No player macros are ever created.
- **Rotation conditions:** every Learn rotation step uses a supported condition (combo points, energy, stealth, poisons, buffs, debuffs) and a researched spell.
- **Pick Pocket open-world entry:** mob, level, zone, coin from the money delta, a Worn Junkbox, the refill timer, and a measured repeat.
- **Other:** reagent cells and reminders (Flash Powder for Vanish, Thieves' Tools), equipment rules (leather; daggers, swords, maces, fist, axes; no two-handers or shields; off hand from 10), weapon-speed notes, stat parsing including weapon speed, Mark on map (pins only with coordinates), Learn lessons by level and faction, What's new, and every gap and conflict carrying text.

## Features (v0.1)

- **Window:** Home · *Play:* Rotation, Gear, PvP · *Rogue:* **Pockets & Locks**, **Poisons** · *Progress:* Leveling, Talents, **Gold** · *Learn:* Learn the Rogue · What's new · Settings. It has a search box (spells, items, poisons, pickpocket mobs, boxes, bags, quests, dungeons), "Sources & notes" on every screen, and the spec pill with A/B profiles. The rogue colour is #FFF569 and the icon is `Ability_Stealth`.
- **Pockets & Locks:** Log · Best targets · Boxes · Lockpicking · Doors.
- **Poisons:** On your weapons · Poisons · Reagents & tools.
- **Gold:** Session · History · Farms · Tips.
- **PvP:** Honor & Rank · Battlegrounds · Rogue PvP · Gear.
- **Rotation:** Solo · Dungeon · Raid · Cooldowns · Energy.
- **Gear:** For my level · Best overall · By bracket · **Bags** · Consumables · Weights.
- **Leveling:** Path · Zones & dungeons · Trainer · Class quests · **Weapon skills** · Riding & gold.
- **Rogue bar** (`UI/RogueBar.lua`, `UI/RogueButtons.lua`): the Pick Lock button, MH and OH poison buttons, a reagents & tools cell, and a "Pockets: N · Xg Ys" counter.
- **Reminders:** poisons on both weapons (once unlocked), Flash Powder, Blinding Powder, Thieves' Tools, and class quests. They also run when you leave a capital city.
- **What's new:** 27 items from the poller's first run on 2026-11-19, including the Nov 17 rogue hotfixes (poison max rank, Shank combo-point wipe, the Ravenholdt letter).
- **Data:**
  - Abilities and talents: 46 spell rows, 82 talent/aura/racial records, 7 builds, 18 class quests.
  - Gear: 372 gear rows, with Icy Veins DB sources for 102 of 163 items.
  - Rogue data: 20 poisons, 69 pickpocket targets (55 GoldScout rows + 14 fan-guide spots), 4 junkboxes, 14 lockboxes, 20 route steps, 11 doors, 113 bags, 14 farms, 9 weapon skills, 9 supplies.
  - Research notes: 30 conflicts and 43 gaps, all shown in game.
- **Teaching content** (`content/learn.json`): 38 spells, 54 talents, 22 mechanics, 20 rogue articles, 6 roles, leveling tips per spec, 16 mistakes, 53 lessons (6 faction-specific), and 9 rotations.

## How it was built

- Code was copied from Tazu's Addon and renamed, then:
  - **Removed:** Shaman pieces (totems, imbues, shields, Fire Nova, the Shaman bar).
  - **New:** `Modules/{Rogue,Pockets,Gold,Locks,Poisons,BagSpace,PvP}.lua`, `UI/RogueBar.lua`, `UI/RogueButtons.lua`, and the Pockets, Poisons, Gold and PvP panels.
  - **Changed:** the rotation engine now uses rogue conditions (`cp_at_least`, `energy_*`, `stealthed`, `poison_missing`, `buff_up` …).
- PvP data and the probe-based reader come from Tristan's Addon. Paladin content (Forbearance, Blessings, burst coach) was left out.
- Research parts were built by four parallel agents from `research/raw/`, following `research/SCHEMA.md`. I merged them and checked them with the build and tests.
  - Item IDs in `gear.json` were cross-checked against the raw HTML, `ids.json` and the parsed BiS files.
  - The parts were not independently re-verified field by field; the conflicts and gaps lists are where to look.
- The talent trees (three calculator versions) and `item_sources.json` were fetched from Icy Veins' static/DB endpoints. The change poller fetched the public feeds once. Nothing was fetched from Wowhead.

## Conflicts (30; all in Settings › About the data, none silently decided)

- **Abilities and talents:**
  - Pick Lock level (1 / 15 / 16); Pick Lock is shown with no level.
  - Mutilate level (30 / 40 / 48 / 50).
  - Venom level and spell ID.
  - Flawless Execution −10 vs −15.
  - Feint "doubled" vs ~5×.
  - Undead Touch of the Dead cooldown.
- **Poisons:**
  - Unlock level (20 vs 24–26).
  - Poison + stone stacking.
  - Duration (30 min vs 1 h).
  - AP scaling.
  - Deadly V and Mind-numbing charge figures.
- **Weapons and gear:**
  - **One-handed axes:** Blizzard says yes, the Wowhead table says no. The addon allows them and flags it.
  - Combat level-60 weapon first choice.
  - Rune of the Guard Captain's faction.
  - Subtlety weapon-speed wording.
- **Quests:**
  - Poison-quest chest skill (75 vs 70).
  - The Skyborne level-10 quest.
  - The "Mission: Possible" title.
- **Locks and boxes:**
  - BRD door values.
  - Durnholde footlocker tier.
  - Heavy Junkbox mob levels.
  - Whether junkboxes drop from kills.
  - Whether boxes need skill.
  - SM junkbox tier.
- **Other:**
  - Pocket refill time.
  - The Thieves' Tools vendor.
  - The Barrens ship boxes.
  - Wowhead bag slot counts.
  - The Berserker Rage/Sap hotfix date (the article lists it under Nov 13; the brief says Nov 16).

## Gaps (43; never guessed)

- **Abilities and data IDs:**
  - Later rank levels for most spells come only from endgametools.
  - Per-rank spell IDs are missing, so spells are detected **by name**.
  - Aura IDs for Venom, Poised and Riposte are missing.
  - Several Energy costs are missing.
- **Quests and NPCs:**
  - Lockpicking quest names and IDs come from secondary sites only.
  - Most class-quest IDs aren't linked. Without an ID, completion can't be checked, so quest reminders stop 5 levels past the quest.
  - The A Simple Request rewards aren't named.
  - Full trainer rosters and Skyborne trainers are missing.
  - Book Return's quest giver isn't on an archived page.
- **Poisons and reagents:**
  - Poison recipes, reagents, vendors and item IDs are missing, so poisons are matched **by name in your bags**.
  - Flash Powder and Blinding Powder vendors are missing.
  - The Thistle Tea effect is missing.
- **Locks and pickpockets:**
  - Lock values are Classic.
  - Heavy Junkbox pickpocket rates are missing.
  - There is no Forever pickpocket data for levels 4–20; your own log fills this.
- **Gear:**
  - endgametools brackets 19–59 weren't archived, so only **level 60 pre-raid** lists ship. "By bracket" shows Icy Veins leveling brackets 10–50 plus 60.
  - No raid BiS; no 51–60 leveling gear.
  - Defias Enforcer's Garb piece IDs are missing.
  - Rogue enchants and consumables aren't archived.
- **Bags:** no bag item IDs (the Wowhead bags page is text only).
- **Other:** the Orc mount trainer is missing; no rogue PvP set items or PvP trinket details.

## Addon assumptions (shown in About the data)

- **Pick Pocket detection:** a Pick Pocket cast followed by a loot window within 4 s (`LOOT_READY`/`LOOT_OPENED`). Coin = money after `LOOT_CLOSED` minus money at the cast.
- **Money attribution:** money is labelled by whatever window is open when it changes.
- **Lock colours** follow Classic skill-up colours (orange under +25, yellow under +50, green under +100).
- **Gear scoring:** weights come from the priority order. A "slow" main hand starts at 2.6 speed (Icy Veins says only "slow"). Percent stats and weapon DPS count 10 points per 1% / 1 DPS.
- **Poisons** are read by name from the weapon tooltips; anything else on a weapon is treated as a stone or oil.
- **Lockpicking and Poisons skills** are read through the Classic `GetSkillLineInfo` API, feature-tested.
- **Combo points:** `UnitPower(player, ComboPoints)`, then `GetComboPoints` as a fallback.

## Install / test on TUF

```sh
cd ~/Projects/forever-rogue && git checkout feature/initial-addon
python3 research/merge.py        # only after editing research/parts/*.json
python3 tools/build_data.py      # regenerate Data/*.lua (--check fails if stale)
python3 tools/ivcalc.py          # 51-point check
lua5.1 tests/run.lua
tools/install-dev.sh "<AddOns folder>"   # only into the live _forever_ AddOns with Tim's OK
```

In game: `/reload`, then `/frogue`. Debug the bar with `/frogue bar debug`.

## Commits (`feature/initial-addon`)

- `ca51cab` Forever Rogue v0.1: Rogue companion for WoW Forever
- The STATUS/gap-normalization commit that follows it (see `git log`)

## Still to check in game

1. **Slash command:** is `/frogue` free?
2. **Pick Pocket log** (the headline feature):
   - Does `UNIT_SPELLCAST_SUCCEEDED` report Pick Pocket with a readable spell ID, and does `LOOT_READY`/`LOOT_OPENED` fire for pockets?
   - Do `GetLootSlotLink` and `GetMoney` work in the open world and inside BRD, SM and Alcaz Prison? Which values are secret in instances: names, GUIDs, loot links?
   - With auto-loot, are items still read?
3. **Pocket refill:** measure the real time with repeats on one mob (the log shows the median).
4. **Pick Lock button:** does `/cast Pick Lock` followed by `/use <bag> <slot>` pick the box in one press on Forever? Also check:
   - Pick Lock's learn level on Rip at 15–16 (the conflict).
   - That the Lockpicking skill line is readable through `GetSkillLineInfo`.
   - The real lock values of junkboxes.
5. **Poison buttons:**
   - Does `/use <poison>` + `/use 16|17` apply in one press?
   - How do the tooltips show a poison next to a sharpening stone (two lines?).
   - Are charges readable from `GetWeaponEnchantInfo`?
   - Does the "Poisons" skill line exist under that name?
6. **Combo points and Energy:** readable in combat (HUD line)? Is `IsStealthed` available?
7. **Auctionator:** prices appear when it's loaded (`Auctionator.API.v1` present on Forever?).
8. **Bags:** the Book Bag from Book Return for Rip; free-slot counts including the reagent bag (bag 5); bank scanning (bank bag IDs −1 and 6–12 are assumed).
9. **Weapons:** can rogues train one-handed axes (Buliwyf / Sayoc)? Is the off-hand allowed from 10?
10. **Conflicts:** Mutilate level, Flawless Execution, Feint, poison unlock level, poison duration.
11. **PvP probes:** which rank/honor APIs are readable (the PvP screen lists them).
12. **Map pins** for route steps and farms; zone-name matching (e.g. "Riverglades", "Arathi Highlands").
13. **General:** dual spec at 40 (Combat A / Subtlety B auto-switch), window layout (the window is now 700 px tall for the 12-item sidebar), Rogue bar position, Lua errors (`/console scriptErrors 1`), spec icons exist in Forever.
14. **Website:** open `docs/index.html` in a browser.

## Recommended next steps (not done)

- Create the GitHub repo and push the branch / open a PR, only with Tim's OK.
- Fetch the endgametools 19–59 brackets and the Wowhead rogue enchants/consumables pages (WebFetch), then rerun the pipeline.
- v0.2 per the brief: the Gold screen (gold/hour splits, best activity per level), the Stealth helper, the combo-point carry-over helper, lockbox service mode.
