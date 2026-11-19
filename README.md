# Forever Rogue

The do-everything Rogue companion for **World of Warcraft: Forever**: a Pick Pocket log with earnings, the best
pickpocket targets, junkboxes and Lockpicking, poisons, a small Rogue bar, rotation help for Assassination, Combat and
Subtlety, gear and bags, leveling, class quests, gold, PvP basics and Learn the Rogue. It works for every Rogue race and
both factions. The test character is **Rip**, a Human Rogue of the Alliance from Northshire Valley.

It's the fifth sibling of [Andric's Addon](https://andricsaddon.myazerothlife.com) (Priest),
[Parzelle's Addon](https://parzelles-addon.myazerothlife.com) (Mage),
[Tristan's Addon](https://tristans-addon.myazerothlife.com) (Paladin) and
[Tazu's Addon](https://tazus-addon.myazerothlife.com) (Shaman), from the makers of [My Azeroth Life](https://myazerothlife.com).

> **Status:** v0.1 in development on a local branch. Not released, not published anywhere yet. See `STATUS.md`.

- Website (text only for now): files in `docs/`, planned for `forever-rogue.myazerothlife.com` (the domain isn't set up).
- WoW Forever only (`WOW_PROJECT_ID 18`), Interface `16001`. No Ace3; Blizzard API only. MIT.

## Install

Not released yet. From a checkout, `tools/install-dev.sh <AddOns folder>` copies only the files WoW needs into
`<AddOns folder>/ForeverRogue`. Then `/reload` and `/frogue`.

## Getting started

1. Type `/frogue` (the only slash command).
2. Pick a spec. Under level 10 there are no talents, so pick what you plan to level as. The default plan:
   **level as Combat**, then at 40 dual spec **Combat (A) + Subtlety (B)**. Subtlety is the solo/PvP alternative;
   Assassination comes online once Mutilate (talent row 7) is reached.
3. Drag the **Rogue bar** somewhere handy. Keys are optional and unbound by default.

## Features

Screens: **Home** · *Play:* Rotation, Gear, PvP · *Rogue:* Pockets & Locks, Poisons · *Progress:* Leveling, Talents, Gold ·
*Learn:* Learn the Rogue · What's new · Settings. Search box, "Sources & notes" on every screen, spec pill with the A/B profile.

- **Pockets & Locks:** *Log* (every pickpocket: coin, items, junkbox tier, mob, level, zone, time; session/day/lifetime
  totals, copper per pickpocket, pickpockets per hour, a refill timer per mob) · *Best targets* (your best mobs next to
  GoldScout's community data, with sample sizes and an "unconfirmed" badge) · *Boxes* (bags and bank, can you open it,
  value from Auctionator or the vendor) · *Lockpicking* (skill vs cap, next route step, Thieves' Tools) · *Doors*.
- **Poisons:** what's on each weapon (poison and stone together), stock, suggested poison per hand, pin your own,
  reagents & tools.
- **Rogue bar:** Pick Lock button (`/cast Pick Lock` + `/use` the next box you can open), main-hand and off-hand poison
  buttons (`/use <poison>` + `/use 16|17`), reagent cells, "pockets this session" counter.
- **Rotation:** Solo/Dungeon/Raid priorities per spec (known spells only), Energy and combo-point readout, Cooldowns
  (Riposte, Shank, Ghostly Strike, Vanish ...; "hidden" when Forever won't say), post-fight tips.
- **Gear:** for my level / best overall / by bracket, **Bags** (free slots, next bag upgrade for your race and faction),
  consumables, weights; tooltip upgrade lines with weapon-speed and dagger notes per spec.
- **Leveling:** path, zones and dungeons, trainer, class quests for your race and faction, weapon skills and trainers, riding.
- **Talents:** the seven Icy Veins builds decoded on Forever's own trees (each exactly 51 points), Nov 2 rework notes.
- **Gold:** this session by source (pickpocket coin, loot, merchant, mail, quests), past sessions, farm spots, tips.
- **PvP:** Honor & Rank (where readable), battlegrounds, rogue PvP notes, poison choices, gear.
- **Learn the Rogue**, reminders (poisons, reagents, Thieves' Tools, class quests, also when you leave a capital),
  What's new (from `tools/rogue-changes-poller`), Settings with About.

## What it can't do (and why)

Forever gives addons no combat log, and other units' health, casts and auras are secret in combat. Inside instances
creature names and GUIDs are secret too, so dungeon pickpockets are logged as "unknown mob, <zone>". Secure buttons only
change out of combat, and every action needs your click or key press.

## Where the information comes from

Blizzard (deep dive, hotfix articles), Icy Veins and Wowhead guides, wowfdb and endgametools (datamined, marked
unconfirmed when single-source), community pickpocket data from **GoldScout** (wowgoldscout.com, crowdsourced by its
addon's users), and fan lockpicking guides (marked unconfirmed). Every fact carries its source and check date in game.
Conflicts between sources are shown, not decided.

## For developers

```sh
python3 research/merge.py        # research/parts/*.json -> research/data.json
python3 tools/build_data.py      # -> Data/*.lua (--check fails if stale)
python3 tools/ivcalc.py          # every talent build decodes to 51 points
lua5.1 tests/run.lua             # headless tests against the strict WoW mock
python3 tools/rogue-changes-poller/tests/test_poller.py
```

`research/raw/` (archived pages) stays local. Optional dependency: Auctionator (prices).

## License and credits

MIT, Nine Point Labs. Forever Rogue is an unofficial fan project, not affiliated with or endorsed by Blizzard
Entertainment. World of Warcraft and Warcraft are trademarks of Blizzard Entertainment, Inc.
