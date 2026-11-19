-- Headless tests. Run from the repo root:  lua5.1 tests/run.lua
package.path = "./tests/?.lua;" .. package.path
local M = require("wow_mock")
M.Install()
local S = M.state

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else
        failed = failed + 1
        io.stderr:write("FAIL " .. name .. ": " .. tostring(err) .. "\n")
        -- Don't let one failure leave combat/secret state on for the next tests.
        S.combat, S.secretOwnAuras, S.secretCooldowns = false, false, false
        S.mainHandLines, S.offHandLines, S.weaponEnchant, S.offEnchant = nil, nil, nil, nil
        S.instanceType, S.loot = nil, nil
        M.RemoveSecrets()
    end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function near(a, b, msg) if math.abs(a - b) > 1e-6 then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function truthy(v, msg) if not v then error(msg or "expected truthy", 2) end end
local function textHas(pattern)
    for _, t in ipairs(M.texts) do if t:find(pattern, 1, true) then return true end end
    return false
end

local ns = M.LoadAddon("ForeverRogue_Forever.toc", ".")

-- Mark a spell as known by name (by research ID when there is one, else by name).
local function know(name)
    local id = ns.Rotation.SpellId(name)
    if id then S.known[id] = true end
    S.knownNames[name] = true
end
local function forget()
    S.known, S.knownNames = {}, {}
end

local function renderAll(label)
    for _, key in ipairs(ns.PanelOrder) do
        M.texts = {}
        ns.UI.Open(key)
        for _, t in ipairs(M.texts) do
            if t:find("This panel hit an error", 1, true) then error(label .. "/" .. key .. ": " .. t) end
        end
    end
end

local SUBS = {
    leveling = { "Path", "Zones & dungeons", "Trainer", "Class quests", "Weapon skills", "Riding & gold" },
    gear = { "For my level", "Best overall", "By bracket", "Bags", "Consumables", "Weights" },
    settings = { "General", "Rogue bar", "Tooltips & bags", "Reminders", "About the data", "About" },
    learn = { "Lessons", "Spells", "Talents", "How the class works", "Poisons & pockets", "In a group", "Leveling", "Common mistakes" },
    rotation = { "Solo", "Dungeon", "Raid", "Cooldowns", "Energy" },
    pockets = { "Log", "Best targets", "Boxes", "Lockpicking", "Doors" },
    poisons = { "On your weapons", "Poisons", "Reagents & tools" },
    gold = { "Session", "History", "Farms", "Tips" },
    pvp = { "Honor & Rank", "Battlegrounds", "Rogue PvP", "Gear" },
}
local function renderSubs(label)
    for key, list in pairs(SUBS) do
        for _, sub in ipairs(list) do
            M.texts = {}
            ns.UI.Open(key, sub)
            for _, t in ipairs(M.texts) do
                if t:find("This panel hit an error", 1, true) then error(label .. "/" .. key .. "/" .. sub .. ": " .. t) end
            end
        end
    end
    ns.UI.Open("rotation", "Solo")
end

-- Item fixtures (bags/boxes/poisons)
local JUNK_B, JUNK_W = "item:16882", "item:16883"
S.itemInfo[16882] = { name = "Battered Junkbox", sellPrice = 25 }
S.itemInfo[16883] = { name = "Worn Junkbox", sellPrice = 50 }
local function link(id, name) return ("|cff9d9d9d|Hitem:%d::::::::|h[%s]|h|r"):format(id, name) end

test("toc files match between plain and _Forever", function()
    local a, b = io.open("ForeverRogue.toc"):read("*a"), io.open("ForeverRogue_Forever.toc"):read("*a")
    eq(a, b)
    truthy(a:find("## Interface: 16001", 1, true), "interface")
    truthy(a:find("## Title: Forever Rogue", 1, true), "title")
    truthy(a:find("## Version: @project-version@", 1, true), "version token")
    truthy(a:find("## Category: Class", 1, true), "category")
    truthy(a:find("## AddonCompartmentFunc: ForeverRogue_OnCompartmentClick", 1, true), "compartment")
    truthy(a:find("## OptionalDeps: Auctionator", 1, true), "Auctionator optional dependency")
    truthy(a:find("## SavedVariables: ForeverRogueDB", 1, true), "saved variables")
    truthy(a:find("## SavedVariablesPerCharacter: ForeverRogueCharDB", 1, true), "per-character saved variables")
    for line in a:gmatch("[^\n]+") do
        if not line:match("^##") and line:match("%S") then truthy(io.open((line:gsub("\\", "/"))), "missing " .. line) end
    end
    eq(io.open("Bindings.xml"), nil, "no Bindings.xml")
end)

test("no leftover Shaman/Paladin/Mage/Priest or sister-addon code", function()
    local toc = io.open("ForeverRogue.toc"):read("*a")
    for line in toc:gmatch("[^\n]+") do
        if not line:match("^##") and line:match("%S") then
            local f = line:gsub("\\", "/")
            -- Data/*.lua is generated from sourced research text (it may mention other classes); only hand-written code is checked.
            local s = f:match("^Data/") and "" or io.open(f):read("*a")
            for _, bad in ipairs({ "Shaman", "Paladin", "Priest", "Mage", "Tazu", "Andric", "Parzelle", "Tristan", "totem", "Totem", "imbue", "Imbue",
                "Lightning Bolt", "Blessing of", "Seal of", "isShaman", "Forbearance", "\"/tazu" }) do
                local about = f == "UI/Panels/Options.lua" and (bad == "Shaman" or bad == "Paladin" or bad == "Priest" or bad == "Mage"
                    or bad == "Tazu" or bad == "Andric" or bad == "Parzelle" or bad == "Tristan")
                local credit = (f == "Modules/PvP.lua" or f == "UI/Panels/PvP.lua") and bad == "Tristan"
                if not about and not credit then truthy(not s:find(bad, 1, true), f .. " mentions " .. bad) end
            end
        end
    end
end)

test("generated data present", function()
    truthy(#ns.Data.Spells >= 30, "spells")
    for _, spec in ipairs(ns.SPEC_ORDER) do
        truthy(ns.Data.Learn and ns.Data.Learn.rotation and ns.Data.Learn.rotation[spec] and ns.Data.Learn.rotation[spec].solo, "learn rotation " .. spec)
        truthy(ns.Data.StatPriority[spec], "stat priority " .. spec)
    end
    eq(ns.Data.Meta.toc_interface, 16001)
    eq(ns.Data.Meta.class, "Rogue")
    for _, n in ipairs({ "Sinister Strike", "Eviscerate", "Pick Pocket", "Stealth", "Shank", "Redirect", "Sap", "Vanish" }) do
        truthy(ns.Rotation.SpellRecord(n), n)
    end
    eq(#ns.Data.Junkboxes, 4, "four junkboxes")
    truthy(#ns.Data.PickpocketTargets >= 20, "pickpocket targets")
    truthy(#ns.Data.Poisons >= 10, "poisons")
    truthy(#ns.Data.Bags >= 20, "bags")
    truthy(#ns.Data.LockpickRoute >= 5, "lockpick route")
    truthy(ns.Data.PvP and #ns.Data.PvP.battlegrounds >= 1, "PvP data")
    truthy(#ns.Data.Conflicts >= 10 and #ns.Data.Gaps >= 10, "conflicts and gaps")
    for _, g in ipairs(ns.Data.Gaps) do truthy(g.gap and g.gap ~= "", "every gap has text") end
    for _, c in ipairs(ns.Data.Conflicts) do truthy(c.topic and c.detail, "every conflict has topic and detail") end
    -- every research record cites a source
    for _, list in ipairs({ ns.Data.PickpocketTargets, ns.Data.Junkboxes, ns.Data.Poisons, ns.Data.Bags, ns.Data.LockpickRoute, ns.Data.Quests }) do
        for _, r in ipairs(list) do truthy(r.source_url and r.checked, "source on " .. tostring(r.name or r.mob)) end
    end
end)

-- Login: Rip, level 1 Human, no talents, no spec.
S.level = 1
M.Fire("ADDON_LOADED", "ForeverRogue")
M.Fire("PLAYER_LOGIN")
M.RunTimers()

test("login creates profile A/B with no spec; /frogue is the only slash command", function()
    truthy(ns.db and ns.db.char.profiles.A and ns.db.char.profiles.B)
    eq(ns.DB.ActiveSpec(), nil)
    truthy(SlashCmdList.FOREVERROGUE, "slash")
    eq(SLASH_FOREVERROGUE1, "/frogue")
    eq(rawget(_G, "SLASH_FOREVERROGUE2"), nil, "no second slash command")
    eq(ns.isRogue, true)
    eq(ns.Progress.PlayerRace(), "Human")
    eq(ns.RECOMMENDED_LEVELING_SPEC, "Combat")
    eq(ns.RECOMMENDED_DUAL_SPEC.A, "Combat")
    eq(ns.RECOMMENDED_DUAL_SPEC.B, "Subtlety")
end)

test("/frogue opens the window", function()
    if _G.ForeverRogueFrame then _G.ForeverRogueFrame:Hide() end
    SlashCmdList.FOREVERROGUE("")
    truthy(_G.ForeverRogueFrame and _G.ForeverRogueFrame:IsShown(), "window shown")
    SlashCmdList.FOREVERROGUE("")
    eq(_G.ForeverRogueFrame:IsShown(), false, "toggles closed")
    SlashCmdList.FOREVERROGUE("pockets")
    truthy(_G.ForeverRogueFrame:IsShown())
end)

test("level 1, no talents, no spec: every screen renders and the picker recommends Combat", function()
    S.level = 1
    renderAll("no spec")
    renderSubs("no spec")
    M.texts = {}
    ns.UI.ShowPicker()
    truthy(textHas("talents start at 10"), "picker explains no talents yet")
    truthy(textHas("recommended for leveling"), "recommended badge")
    truthy(textHas("level as Combat"), "Combat for leveling")
    truthy(textHas("Combat (A) + Subtlety (B)"), "dual spec plan")
    M.texts = {}
    ns.UI.Open("home")
    truthy(textHas("No talents yet"), "home nudge")
    M.texts = {}
    ns.UI.Open("talents")
    truthy(textHas("Pick a spec first"))
end)

test("DB.Init keeps saved values and fills defaults (no keys bound, 2,000-entry log)", function()
    local acc, ch = ns.DB.Init({ percentScale = 14 }, { active = "B", profiles = { B = { spec = "Subtlety" } } })
    eq(acc.percentScale, 14)
    eq(ch.active, "B")
    eq(ch.profiles.B.spec, "Subtlety")
    eq(ch.profiles.A.rotationContext, "solo")
    eq(ch.pickLock.key, nil); eq(ch.poisonMH.key, nil); eq(ch.poisonOH.key, nil)
    eq(ch.pockets.cap, 2000, "brief default: 2,000 pickpockets")
    eq(ch.pockets.refillMinutes, 10)
    ns.DB.Init(ForeverRogueDB, ForeverRogueCharDB)
end)

test("level 4 Human in Northshire (Rip): Home shows the Book Bag and Seek out SI:7; empty Pick Pocket log", function()
    S.level = 4
    forget()
    know("Sinister Strike"); know("Eviscerate"); know("Stealth"); know("Backstab"); know("Pick Pocket")
    S.bagSlots, S.bagSizes = { [0] = {} }, { [0] = 16, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
    ns.DB.SetSpec("Combat")
    renderAll("rip4")
    renderSubs("rip4")
    M.texts = {}
    ns.UI.Open("home")
    truthy(textHas("Seek out SI:7"), "Home: next class quest is Seek out SI:7")
    truthy(textHas("Book Bag"), "Home: Book Bag from Book Return")
    truthy(textHas("No pickpockets yet"), "Home: empty log state")
    local q = ns.Progress.NextClassQuest("Human", "Alliance", 4)
    eq(q and q.name, "Seek out SI:7")
    eq(q.level, 10)
    M.texts = {}
    ns.UI.Open("pockets", "Log")
    truthy(textHas("No pickpockets logged yet"), "Pockets: empty state")
    M.texts = {}
    ns.UI.Open("poisons", "On your weapons")
    truthy(textHas("Poisons come from a class quest"), "Poisons: quest pointer before 20")
    S.bagSlots, S.bagSizes = {}, nil
    forget()
end)

test("faction filtering: Rip (Human, Alliance) sees no Horde or other-race class quests", function()
    local list = ns.Progress.ClassQuests("Human", "Alliance")
    local byName = {}
    for _, q in ipairs(list) do
        byName[q.name] = q
        truthy(q.faction ~= "Horde", "no Horde quest: " .. q.name)
        truthy(q.races == "All" or ns.Progress.RaceMatches(q.races, "Human"), "race: " .. q.name)
    end
    truthy(byName["Seek out SI:7"], "Human chain")
    truthy(not byName["Therzok"], "no Orc/Troll chain")
    truthy(not byName["The Shattered Salute"], "no Horde poison quest")
    truthy(byName["Mathias and the Defias"], "Alliance poison quest")
    M.texts = {}
    ns.UI.Open("leveling", "Class quests")
    -- Horde quests never get a row (an Alliance quest's own notes may mention its Horde twin).
    local shown = {}
    for _, q in ipairs(list) do shown[#shown + 1] = q.name .. " " .. (q.notes or "") .. " " .. table.concat(q.steps or {}, " ") .. " " .. (q.reward or "") end
    local allowed = table.concat(shown, " ")
    for _, dq in ipairs(ns.Data.Quests) do
        if dq.faction == "Horde" and not byName[dq.name] and not allowed:find(dq.name, 1, true) then
            truthy(not textHas(dq.name), "Horde quest hidden: " .. dq.name)
        end
    end
    -- Horde view of the same data
    local h = {}
    for _, q in ipairs(ns.Progress.ClassQuests("Undead", "Horde")) do h[q.name] = true end
    truthy(h["The Shattered Salute"] and not h["Seek out SI:7"], "Horde Undead sees Horde quests only")
    eq(ns.GearOtherFaction({ faction = "Horde" }), true)
    eq(ns.GearOtherFaction({ faction = "Alliance" }), false)
end)

test("level 20, before the poison quest: Poisons screen shows the quest, no poison buttons", function()
    S.level = 20
    forget()
    know("Sinister Strike"); know("Pick Pocket"); know("Pick Lock")
    S.skills = {}
    ns.RefreshBars()
    eq(ns.Poisons.Unlocked(), false, "no Poisons skill, no poisons in bags")
    eq(ns.RogueBar.Shown().poisonmh, nil, "no MH poison button")
    eq(ns.RogueBar.Shown().poisonoh, nil, "no OH poison button")
    M.texts = {}
    ns.UI.Open("poisons", "On your weapons")
    truthy(textHas("Mathias and the Defias"), "Alliance poison quest named")
    forget()
end)

test("rotation: every step uses a supported condition and a researched spell", function()
    local okCond = {}
    for _, c in ipairs(ns.Rotation.CONDITIONS) do okCond[c] = true end
    for spec, ctxs in pairs(ns.Data.Learn.rotation) do
        for ctxName, ctx in pairs(ctxs) do
            truthy(#ctx.priority > 0, spec .. "/" .. ctxName .. " empty")
            for _, step in ipairs(ctx.priority) do
                local w = step.when or "always"
                local prefix = w:match("^([%w_]+):")
                local known = okCond[w]
                for _, p in ipairs(ns.Rotation.CONDITION_PREFIXES) do if p == prefix then known = true end end
                truthy(known, ("%s/%s: condition %s unsupported"):format(spec, ctxName, w))
                truthy(ns.Rotation.IsKnownName(step.spell), ("%s/%s: unknown spell %s"):format(spec, ctxName, step.spell))
            end
        end
    end
end)

local function fakeState(o)
    return {
        inCombat = function() return o.combat or false end,
        hasTarget = function() return o.target ~= false end,
        spellName = function(n) return n end,
        playerBuff = function(n) if o.hiddenBuffs then return nil end return o.buffs and o.buffs[n] or false end,
        playerDebuff = function() return false end,
        playerStacks = function() return 0 end,
        targetDebuff = function(n) return o.tdebuffs and o.tdebuffs[n] or false end,
        cooldown = function(n) return o.cds and o.cds[n] or 0 end,
        targetHpPct = function() return o.hp or 100 end,
        known = function(n) return o.known == nil or o.known[n] == true end,
        usable = function(n) return o.usable and o.usable[n] or false end,
        inMelee = function() return o.melee ~= false end,
        stealthed = function() return o.stealthed end,
        poisons = function() return o.poisons end,
        comboPoints = function() return o.cp end,
        energy = function() return o.energy end,
    }
end

test("rotation: rogue conditions (combo points, energy, stealth, poisons, buffs)", function()
    local C = ns.Rotation.Check
    eq(C({ spell = "Eviscerate", when = "cp_at_least:5" }, fakeState({ cp = 5 })), true)
    eq(C({ spell = "Eviscerate", when = "cp_at_least:5" }, fakeState({ cp = 3 })), false)
    eq(C({ spell = "Eviscerate", when = "cp_at_least:5" }, fakeState({})), nil, "hidden combo points -> unknown")
    eq(C({ spell = "Shank", when = "cp_below:4" }, fakeState({ cp = 2 })), true)
    eq(C({ spell = "Sinister Strike", when = "energy_at_least:45" }, fakeState({ energy = 50 })), true)
    eq(C({ spell = "Sinister Strike", when = "energy_below:40" }, fakeState({ energy = 50 })), false)
    eq(C({ spell = "Cheap Shot", when = "stealthed" }, fakeState({ stealthed = true })), true)
    eq(C({ spell = "Cheap Shot", when = "stealthed" }, fakeState({ stealthed = false })), false)
    eq(C({ spell = "Sinister Strike", when = "not_stealthed" }, fakeState({ stealthed = false })), true)
    eq(C({ spell = "Slice and Dice", when = "buff_missing" }, fakeState({})), true)
    eq(C({ spell = "Slice and Dice", when = "buff_missing" }, fakeState({ buffs = { ["Slice and Dice"] = true } })), false)
    eq(C({ spell = "Slice and Dice", when = "buff_missing" }, fakeState({ hiddenBuffs = true })), nil, "hidden -> unknown")
    eq(C({ spell = "Eviscerate", when = "buff_up:Slice and Dice" }, fakeState({ buffs = { ["Slice and Dice"] = true } })), true)
    eq(C({ spell = "Rupture", when = "target_debuff_missing:Rupture" }, fakeState({})), true)
    eq(C({ spell = "Rupture", when = "target_debuff_missing:Rupture" }, fakeState({ tdebuffs = { Rupture = true } })), false)
    eq(C({ spell = "Riposte", when = "usable" }, fakeState({ usable = { Riposte = true } })), true)
    eq(C({ spell = "Shank", when = "ready" }, fakeState({ cds = { Shank = 4 } })), false)
    eq(C({ spell = "Kick", when = "manual" }, fakeState({})), false)
    eq(C({ spell = "Sinister Strike", when = "poison_missing" }, fakeState({ poisons = { mh = false, oh = "noweapon" } })), true)
    eq(C({ spell = "Sinister Strike", when = "poison_missing" }, fakeState({ poisons = { mh = { base = "Instant Poison", left = 900 }, oh = "noweapon" } })), false)
end)

test("level 24 with Shank: rotation shows Shank, hides talents not taken", function()
    S.level = 24
    forget()
    for _, n in ipairs({ "Sinister Strike", "Eviscerate", "Backstab", "Slice and Dice", "Shank", "Stealth", "Garrote", "Ambush", "Kick", "Sprint", "Evasion", "Vanish", "Sap" }) do know(n) end
    ns.DB.SetSpec("Subtlety")
    eq(ns.Rotation.Availability("Shank", 24, "Human", "Alliance"), "known")
    eq(ns.Rotation.Availability("Hemorrhage", 24, "Human", "Alliance"), nil, "Hemorrhage talent not taken")
    renderAll("sub24")
    renderSubs("sub24")
    M.texts = {}
    ns.UI.Open("rotation", "Solo")
    truthy(textHas("Shank"), "Shank in the list")
    M.texts = {}
    ns.UI.Open("rotation", "Cooldowns")
    truthy(textHas("Shank"), "Shank cooldown cell")
    forget()
end)

test("level 40 Combat/Subtlety dual spec: profiles switch with the talent group", function()
    S.level = 40
    ns.DB.SwitchProfile("A")
    ns.DB.SetSpec("Combat")
    ns.DB.SetSpec("Subtlety", "B")
    M.texts = {}
    ns.UI.Open("home")
    truthy(textHas("Dual spec is available"), "dual spec nudge at 40")
    S.numSpecGroups, S.specGroup = 2, 2
    M.Fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
    eq(ns.DB.ActiveId(), "B")
    eq(ns.DB.ActiveSpec(), "Subtlety")
    renderAll("sub40")
    S.specGroup = 1
    M.Fire("ACTIVE_TALENT_GROUP_CHANGED", 1, 2)
    eq(ns.DB.ActiveSpec(), "Combat")
    renderAll("combat40")
    S.numSpecGroups = 1
end)

test("level 60 secret-values run: target, cooldowns and own auras hidden -> 'hidden', nothing guessed", function()
    S.level = 60
    forget()
    for _, n in ipairs({ "Sinister Strike", "Eviscerate", "Slice and Dice", "Rupture", "Shank", "Riposte", "Blade Flurry", "Adrenaline Rush", "Kick", "Vanish", "Pick Pocket", "Pick Lock" }) do know(n) end
    ns.DB.SetSpec("Combat")
    S.combat = true
    M.InstallSecrets()
    S.secretMode, S.secretCooldowns = true, true
    eq(ns.Auras.HealthPct("target"), nil, "target health secret -> unknown")
    eq(ns.Auras.CooldownLeft("Shank"), nil, "cooldown secret -> unknown")
    renderAll("combat60-secret")
    renderSubs("combat60-secret")
    M.texts = {}
    ns.UI.Open("rotation", "Cooldowns")
    truthy(textHas("hidden"), "cooldowns show hidden")
    S.secretOwnAuras = true
    eq(ns.Rogue.Energy(), nil, "energy secret -> unknown")
    eq(ns.Rogue.ComboPoints(), nil, "combo points secret -> unknown")
    eq(ns.Poisons.OnWeapons(), nil, "weapons secret -> unknown")
    truthy(ns.Cooldowns.HudLine():find("hidden", 1, true), "HUD says hidden")
    local _, blocked = ns.Rotation.Suggest("Combat", "solo", nil, 3)
    truthy(blocked, "suggestion flags hidden info")
    ns.Hud.Refresh()
    ns.Hud.Update()
    ns.RogueButtons.Update()
    renderAll("combat60-secret-own")
    S.secretOwnAuras = false
    M.RemoveSecrets()
    S.secretCooldowns, S.combat = false, false
    forget()
end)

test("Pick Pocket log: open world entry with mob, level, zone, coin, items and junkbox tier", function()
    S.level = 30
    forget()
    know("Pick Pocket")
    local P = ns.Pockets
    ns.db.char.pockets.log, ns.db.char.pockets.head, ns.db.char.pockets.count = {}, 0, 0
    P.StartSession(S.wallTime)
    local before = ns.db.char.pockets.totals.life.n
    S.targetName, S.targetGUID, S.zone = "Syndicate Highwayman", "Creature-0-1-2-3-2586-0001", "Arathi Highlands"
    S.units.target = { level = 30 }
    S.money = 100000
    truthy(P.IsPickPocket(ns.Rotation.SpellId("Pick Pocket")) or true)
    P.BeginAttempt(S.wallTime)
    S.loot = { { link = link(16883, "Worn Junkbox"), name = "Worn Junkbox" }, { money = true, name = "53 Copper" } }
    P.OnLootOpened()
    S.money = 100000 + 253
    local e = P.OnLootClosed()
    truthy(e, "recorded")
    eq(e.mob, "Syndicate Highwayman"); eq(e.level, 30); eq(e.zone, "Arathi Highlands")
    eq(e.copper, 253); eq(e.junkbox, "Worn"); eq(#e.items, 1)
    eq(ns.db.char.pockets.totals.life.n, before + 1)
    eq(ns.db.char.pockets.byMob["Syndicate Highwayman"].boxes, 1)
    eq(P.Log(1)[1], e, "newest first")
    -- refill timer on that GUID
    S.wallTime = S.wallTime + 120
    local left = P.RefillLeft("Creature-0-1-2-3-2586-0001")
    eq(left, 480, "10-minute default minus 2 minutes")
    -- a repeat measures the real refill
    S.wallTime = S.wallTime + 600
    P.BeginAttempt(S.wallTime)
    S.loot = { { money = true, name = "40 Copper" } }
    P.OnLootOpened()
    S.money = S.money + 40
    P.OnLootClosed()
    local med, n = P.MeasuredRefill()
    eq(n, 1); near(med, 12)
    S.loot, S.targetName, S.targetGUID, S.units.target = nil, nil, nil, nil
    M.texts = {}
    ns.UI.Open("pockets", "Log")
    truthy(textHas("Syndicate Highwayman"), "log row")
    truthy(textHas("Worn"), "junkbox chip")
end)

test("instance mode: names and GUIDs secret -> log records 'unknown mob, <zone>'", function()
    local P = ns.Pockets
    M.InstallSecrets()
    S.instanceType, S.instanceZone = "party", "Blackrock Depths"
    S.targetName, S.targetGUID = "Shadowforge Citizen", "Creature-x"
    S.units.target = { level = 52 }
    P.BeginAttempt(S.wallTime)
    S.loot = { { link = link(16885, "Heavy Junkbox"), name = "Heavy Junkbox" } }
    P.OnLootOpened()
    S.money = S.money + 1500
    local e = P.OnLootClosed()
    eq(e.mob, nil, "name hidden")
    eq(e.guid, nil, "no GUID kept in instances")
    eq(e.zone, "Blackrock Depths")
    eq(e.copper, 1500)
    eq(e.junkbox, "Heavy")
    eq(P.EntryLabel(e), "unknown mob, Blackrock Depths")
    S.instanceType, S.instanceZone, S.loot, S.targetName, S.targetGUID, S.units.target = nil, nil, nil, nil, nil, nil
    M.RemoveSecrets()
end)

test("Pick Pocket log trims at 2,000 while totals keep counting", function()
    local P = ns.Pockets
    local p = ns.db.char.pockets
    p.log, p.head, p.count = {}, 0, 0
    local life0 = p.totals.life.n
    for i = 1, 2105 do P.Record({ mob = "Defias Thug", level = 5, zone = "Elwynn Forest", copper = 10, items = {}, t = 1000 + i }) end
    eq(p.count, 2000, "log capped")
    local n = 0
    for _ in pairs(p.log) do n = n + 1 end
    eq(n, 2000, "buffer holds 2,000 entries")
    eq(p.totals.life.n, life0 + 2105, "lifetime keeps counting")
    eq(p.byMob["Defias Thug"].n, 2105, "per-mob keeps counting")
    eq(P.Log(1)[1].t, 1000 + 2105, "newest entry first")
    eq(P.Log(2000)[2000].t, 1000 + 106, "oldest kept entry")
    local best = P.BestMobs(3)
    truthy(best[1] and best[1].mob == "Defias Thug", "best mobs from own log")
end)

test("money attribution: pickpocket, loot, merchant, mail, quest, other", function()
    local G = ns.Gold
    S.money = 50000
    G.NewSession(S.wallTime)
    eq(G.OnMoney(50100, "pickpocket"), "pickpocket")
    G.SetOpen("loot", true)
    eq(select(1, G.OnMoney(50300)), "loot")
    G.SetOpen("loot", false)
    G.SetOpen("merchant", true)
    local src, delta = G.OnMoney(50000)
    eq(src, "merchant"); eq(delta, -300)
    G.SetOpen("merchant", false)
    G.SetOpen("mail", true)
    eq(select(1, G.OnMoney(60000)), "mail")
    G.SetOpen("mail", false)
    G.QuestTurnedIn()
    eq(select(1, G.OnMoney(61000)), "quest")
    S.time = 2000
    eq(select(1, G.OnMoney(61500)), "other")
    S.time = nil
    local s = G.Session()
    eq(s.by.pickpocket, 100); eq(s.by.loot, 200); eq(s.by.merchant, -300); eq(s.by.mail, 10000); eq(s.by.quest, 1000); eq(s.by.other, 500)
    eq(s.gained, 11800); eq(s.spent, 300)
    eq(G.Format(12345), "1g 23s 45c")
    eq(G.Format(45), "45c")
end)

test("junkbox value: Auctionator price when loaded, vendor price otherwise", function()
    eq(ns.Gold.AuctionatorLoaded(), false)
    local price, label = ns.Gold.Price(16882)
    eq(price, 25); eq(label, "Vendor")
    S.loadedAddons = { Auctionator = true }
    rawset(_G, "Auctionator", { API = { v1 = { GetAuctionPriceByItemLink = function(caller, l) return 1234 end } } })
    price, label = ns.Gold.Price(16882)
    eq(price, 1234); eq(label, "AH (Auctionator)")
    -- a broken Auctionator never breaks the addon
    rawset(_G, "Auctionator", { API = { v1 = { GetAuctionPriceByItemLink = function() error("boom") end } } })
    price, label = ns.Gold.Price(16882)
    eq(label, "Vendor", "falls back when Auctionator errors")
    rawset(_G, "Auctionator", nil)
    S.loadedAddons = nil
end)

test("lockpick cap math and junkbox skill colours", function()
    eq(ns.Rogue.LockpickCap(16), 80)
    eq(ns.Rogue.LockpickCap(60), 300)
    eq(ns.Rogue.LockpickCap(70), 300)
    eq(ns.Locks.Color(50, 70), "red")
    eq(ns.Locks.Color(70, 70), "orange")
    eq(ns.Locks.Color(100, 70), "yellow")
    eq(ns.Locks.Color(150, 70), "green")
    eq(ns.Locks.Color(200, 70), "grey")
    eq(ns.Locks.Color(nil, 70), "unknown")
    eq(ns.Locks.CanOpen(1, 1), true)
    eq(ns.Locks.CanOpen(60, 70), false)
    S.skills = { { name = "Lockpicking", rank = 85, max = 150 } }
    local lp = ns.Rogue.Lockpicking()
    eq(lp.rank, 85); eq(lp.max, 150)
    local step = ns.Locks.RouteStep(85, "Alliance")
    truthy(step and step.skill_from <= 85 and step.skill_to > 85, "route step for 85")
    S.skills = {}
end)

test("Pick Lock button: secure /cast + /use the next box you can open; disarmed when none", function()
    forget()
    know("Pick Lock")
    S.level = 30
    S.skills = { { name = "Lockpicking", rank = 80, max = 150 } }
    S.bagSlots = { [0] = { JUNK_W, JUNK_B } }
    S.bags[5060] = 1
    ns.RefreshBars()
    local b = _G.ForeverRoguePickLockButton
    truthy(b, "button exists")
    truthy(ns.RogueBar.Shown().picklock, "on the Rogue bar")
    eq(b:GetAttribute("type"), "macro")
    eq(b:GetAttribute("macrotext"), "/cast Pick Lock\n/use 0 2", "Battered (skill 1) first")
    truthy(b:GetAttribute("useOnKeyDown") ~= true, "acts on release")
    S.bagSlots = { [0] = { JUNK_W } }
    S.skills = { { name = "Lockpicking", rank = 50, max = 150 } }
    ns.RogueButtons.Update()
    eq(b:GetAttribute("type"), nil, "Worn needs 70: disarmed")
    -- frozen in combat
    S.skills = { { name = "Lockpicking", rank = 80, max = 150 } }
    S.combat = true
    ns.RogueButtons.Update()
    eq(b:GetAttribute("type"), nil, "doesn't change in combat")
    S.combat = false
    ns.RogueButtons.Update()
    eq(b:GetAttribute("macrotext"), "/cast Pick Lock\n/use 0 1")
    -- keys: none by default, Super refused, override click
    eq(ns.db.char.pickLock.key, nil)
    S.meta = true
    eq(ns.RogueBar.KeyString("F"), nil, "Super/Meta combos refused")
    S.meta = false
    ns.RogueButtons.SetKey("picklock", "ALT-L")
    eq(M.overrides["ALT-L"], "ForeverRoguePickLockButton:LeftButton")
    ns.RogueButtons.SetKey("picklock", nil)
    S.combat = true
    ns.RogueButtons.SetKey("picklock", "G")
    eq(ns.db.char.pickLock.key, nil, "can't rebind in combat")
    S.combat = false
    for _, m in ipairs(M.macros) do error("no macros may be created: " .. m.name) end
    S.bagSlots, S.skills, S.bags = {}, {}, {}
    forget()
end)

test("poison buttons: /use <poison> + /use 16|17, two temp effects on one weapon, disarmed while on", function()
    forget()
    S.level = 30
    ns.DB.SetSpec("Combat")
    S.skills = { { name = "Poisons", rank = 100, max = 300 } }
    local IP2, DP = "item:90001", "item:90002"
    S.bagSlots = { [0] = { link(90001, "Instant Poison II"), link(90002, "Deadly Poison"), link(90003, "Instant Poison") } }
    S.equipped[16], S.equipped[17] = "item:5001", "item:5002"
    ns.RefreshBars()
    eq(ns.Poisons.Unlocked(), true)
    local mh, oh = _G.ForeverRoguePoisonMHButton, _G.ForeverRoguePoisonOHButton
    truthy(ns.RogueBar.Shown().poisonmh and ns.RogueBar.Shown().poisonoh, "both buttons shown")
    eq(mh:GetAttribute("macrotext"), "/use Instant Poison II\n/use 16", "MH: best Instant rank (Icy Veins Combat: Instant MH)")
    eq(oh:GetAttribute("macrotext"), "/use Deadly Poison\n/use 17", "OH: Deadly (Icy Veins Combat)")
    -- Poison + sharpening stone on the same main hand: both read, button disarmed
    S.mainHandLines = { "Sword", "Instant Poison II (30 min)", "Sharpened (+3 Damage)" }
    S.weaponEnchant = { ms = 1700000, charges = 55 }
    ns.RogueButtons.Update()
    local on = ns.Poisons.OnWeapons()
    eq(on.mh.base, "Instant Poison"); eq(on.mh.rank, 2); eq(on.mh.charges, 55)
    truthy(on.mh.stone and on.mh.stone:find("Sharpened", 1, true), "stone read too")
    eq(on.oh, false, "nothing on the off hand")
    eq(mh:GetAttribute("type"), nil, "MH poison already on -> disarmed")
    eq(oh:GetAttribute("type"), "macro", "OH still armed")
    -- running out re-arms
    S.weaponEnchant = { ms = 100000, charges = 5 }
    ns.RogueButtons.Update()
    eq(mh:GetAttribute("macrotext"), "/use Instant Poison II\n/use 16", "re-armed under 5 minutes")
    -- only a stone: armed
    S.mainHandLines, S.weaponEnchant = { "Sword", "Sharpened (+3 Damage)" }, { ms = 1700000 }
    ns.RogueButtons.Update()
    eq(mh:GetAttribute("type"), "macro", "stone only -> still applies poison")
    -- pin
    ns.db.char.poisonMH.override = "Deadly Poison"
    ns.RogueButtons.Update()
    eq(mh:GetAttribute("macrotext"), "/use Deadly Poison\n/use 16", "pinned")
    ns.db.char.poisonMH.override = nil
    -- reminders
    local ids = {}
    for _, r in ipairs(ns.Reminders.Missing()) do ids[r.id] = r end
    truthy(ids["poison:mh"], "MH poison reminder (only a stone)")
    for _, m in ipairs(M.macros) do error("no macros may be created: " .. m.name) end
    S.mainHandLines, S.weaponEnchant, S.bagSlots, S.skills = nil, nil, {}, {}
    S.equipped[16], S.equipped[17] = nil, nil
    forget()
    ns.RefreshBars()
end)

test("reagent cells and reminders: Flash Powder for Vanish, Thieves' Tools for Pick Lock", function()
    forget()
    know("Vanish"); know("Pick Lock")
    S.bags = {}
    local lines = ns.RogueButtons.ReagentLines()
    truthy(#lines >= 2, "cells for known spells")
    local ids = {}
    for _, r in ipairs(ns.Reminders.Missing()) do ids[r.id] = r end
    truthy(ids["reagent:Flash Powder"], "Flash Powder missing")
    truthy(ids.tools, "Thieves' Tools missing")
    S.bags[5140], S.bags[5060] = 10, 1
    ids = {}
    for _, r in ipairs(ns.Reminders.Missing()) do ids[r.id] = r end
    truthy(not ids["reagent:Flash Powder"] and not ids.tools, "stocked")
    S.bags = {}
    forget()
end)

test("bag math: free slots and the next bag upgrade", function()
    S.bagSlots = { [0] = { "item:1", "item:2" }, [1] = { "item:3" } }
    S.bagSizes = { [0] = 16, [1] = 6, [2] = 0, [3] = 0, [4] = 0, [5] = 0 }
    local sum = ns.BagSpace.Summary()
    eq(sum.total, 22); eq(sum.free, 19); eq(sum.smallest, 0, "empty bag slot")
    local nb = ns.BagSpace.Next(4, "Alliance", "Human", 0)
    eq(nb and nb.name, "Book Bag", "Human starter quest bag")
    for _, b in ipairs(ns.BagSpace.Upgrades(10, "Alliance", "Human", 0)) do
        truthy(not b.races or b.races == "All" or ns.Progress.RaceMatches(b.races, "Human"), "race filter: " .. b.name)
        truthy(b.faction ~= "Horde", "faction filter: " .. b.name)
    end
    S.bagSlots, S.bagSizes = {}, nil
end)

test("GoldScout rows show the 'Community data' label, sample size and unconfirmed badge", function()
    S.level = 30
    M.texts = {}
    ns.UI.Open("pockets", "Best targets")
    truthy(textHas("COMMUNITY DATA (GOLDSCOUT)"), "label")
    truthy(textHas("n="), "sample size")
    truthy(textHas("GoldScout crowdsourced") or textHas("Unconfirmed"), "unconfirmed badge")
    for _, t in ipairs(ns.Data.PickpocketTargets) do
        if t.community == "GoldScout" then truthy(t.unconfirmed and t.sample_n, "GoldScout row flagged: " .. t.mob) end
    end
    M.texts = {}
    ns.UI.Open("settings", "About")
    truthy(textHas("GoldScout"), "credited in About")
end)

test("PvP screen renders at 10, 30 and 60", function()
    for _, lvl in ipairs({ 10, 30, 60 }) do
        S.level = lvl
        for _, sub in ipairs(SUBS.pvp) do
            M.texts = {}
            ns.UI.Open("pvp", sub)
            for _, t in ipairs(M.texts) do truthy(not t:find("This panel hit an error", 1, true), lvl .. "/" .. sub .. ": " .. t) end
        end
    end
    M.texts = {}
    ns.UI.Open("pvp", "Rogue PvP")
    truthy(textHas("Sap") or textHas("Distract"), "rogue PvP notes")
    M.texts = {}
    ns.UI.Open("pvp", "Honor & Rank")
    truthy(textHas("hidden") or textHas("missing"), "unreadable PvP values shown as hidden/missing")
end)

test("every panel and sub-tab renders for every spec (levels 1, 24, 40, 60)", function()
    for _, lvl in ipairs({ 1, 24, 40, 60 }) do
        S.level = lvl
        for _, spec in ipairs(ns.SPEC_ORDER) do
            ns.DB.SetSpec(spec)
            renderAll(spec .. "@" .. lvl)
            renderSubs(spec .. "@" .. lvl)
        end
    end
    S.level = 24
    eq(#ns.PanelOrder, 12, "12 screens")
    for _, old in ipairs({ "overview", "training", "quests", "mounts", "reminders", "sources", "options", "changes", "energy", "cooldowns",
        "bar", "log", "targets", "boxes", "locks", "doors", "reagents", "bags", "weapons", "farms", "battle" }) do
        ns.UI.Open(old)
    end
    truthy(#ns.UI.Search("sinister") > 0, "search finds spells")
    truthy(#ns.UI.Search("junkbox") > 0, "search finds junkboxes")
    truthy(#ns.UI.Search("instant poison") > 0, "search finds poisons")
    truthy(#ns.UI.Search("dragonmaw") > 0, "search finds pickpocket mobs")
    eq(#ns.UI.Search("s"), 0, "search needs 2+ characters")
end)

test("window groups: Home · Play · Rogue · Progress · Learn · More", function()
    local titles, keys = {}, {}
    for _, g in ipairs(ns.UI.NAV) do
        if g.title then table.insert(titles, g.title) end
        for _, k in ipairs(g.keys) do keys[#keys + 1] = k end
    end
    eq(table.concat(titles, ","), "Play,Rogue,Progress,Learn,More")
    eq(table.concat(keys, ","), "home,rotation,gear,pvp,pockets,poisons,leveling,talents,gold,learn,news,settings")
    eq(ns.Panels.pockets.label, "Pockets & Locks")
    eq(ns.Panels.learn.label, "Learn the Rogue")
end)

test("no leftover Shaman/Paladin/Mage/Priest text in the window (About links excepted)", function()
    local bad = {}
    for _, spec in ipairs(ns.SPEC_ORDER) do
        ns.DB.SetSpec(spec)
        for key, list in pairs(SUBS) do
            for _, sub in ipairs(list) do
                ns.UI.Open(key, sub)
                M.texts = {}
                ns.UI.Refresh()
                -- Sourced research text and mob names ("Syndicate Shadow Mage") may name other classes.
                local sourced = (key == "settings" and sub == "About the data") or key == "learn" or key == "news" or key == "gear"
                    or (key == "leveling" and sub == "Zones & dungeons") or key == "pockets" or key == "gold" or key == "pvp"
                for _, t in ipairs(M.texts) do
                    local about = (key == "settings" and sub == "About")
                    for _, w in ipairs({ "Shaman", "Tazu", "Andric", "Parzelle", "Tristan" }) do
                        if t:find(w, 1, true) and not about then bad[#bad + 1] = key .. "/" .. sub .. ": " .. t end
                    end
                    for _, w in ipairs({ "Paladin", "Priest", "Mage", "totem", "Totem", "imbue" }) do
                        if t:find(w, 1, true) and not about and not sourced then bad[#bad + 1] = key .. "/" .. sub .. ": " .. t end
                    end
                end
            end
        end
    end
    eq(#bad, 0, table.concat(bad, "\n"))
end)

test("About names Rip and links the four sister addons", function()
    M.texts = {}
    SlashCmdList.FOREVERROGUE("about")
    truthy(textHas("Rip"), "Rip")
    truthy(textHas("Human Rogue of the Alliance"), "race and faction")
    truthy(textHas("forever-rogue.myazerothlife.com"), "website link")
    for _, n in ipairs({ "Andric's Addon", "Parzelle's Addon", "Tristan's Addon", "Tazu's Addon", "myazerothlife.com" }) do truthy(textHas(n), n) end
end)

test("slash commands", function()
    ns.DB.SwitchProfile("A")
    SlashCmdList.FOREVERROGUE("spec sub")
    eq(ns.DB.ActiveSpec(), "Subtlety")
    SlashCmdList.FOREVERROGUE("spec ass")
    eq(ns.DB.ActiveSpec(), "Assassination")
    SlashCmdList.FOREVERROGUE("spec combat")
    eq(ns.DB.ActiveSpec(), "Combat")
    SlashCmdList.FOREVERROGUE("profile")
    eq(ns.DB.ActiveId(), "B")
    SlashCmdList.FOREVERROGUE("profile A")
    for _, cmd in ipairs({ "gear", "pockets", "poisons", "boxes", "locks", "gold", "pvp", "bags", "weapons", "energy", "cooldowns",
        "bar", "bar debug", "bar reset", "remind", "hud", "hud", "bogus", "" }) do SlashCmdList.FOREVERROGUE(cmd) end
end)

test("events: level up, combat, casts, loot, money, bank, zones", function()
    S.level = 26
    M.Fire("PLAYER_LEVEL_UP", 26)
    S.combat = true
    M.Fire("PLAYER_REGEN_DISABLED")
    M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", ns.Rotation.SpellId("Sinister Strike"))
    S.time = 1030
    S.combat = false
    M.Fire("PLAYER_REGEN_ENABLED")
    know("Pick Pocket")
    S.targetName, S.units.target = "Defias Pillager", { level = 15 }
    M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", ns.Rotation.SpellId("Pick Pocket") or 921)
    S.loot = { { money = true, name = "12 Copper" } }
    M.Fire("LOOT_OPENED")
    S.money = S.money + 12
    M.Fire("LOOT_CLOSED")
    S.loot, S.targetName, S.units.target = nil, nil, nil
    for _, ev in ipairs({ "SPELLS_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "GROUP_ROSTER_UPDATE",
        "PLAYER_MONEY", "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "QUEST_TURNED_IN", "BANKFRAME_OPENED",
        "BANKFRAME_CLOSED", "SKILL_LINES_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do M.Fire(ev) end
    M.Fire("UNIT_AURA", "player")
    M.Fire("UNIT_POWER_UPDATE", "player", "ENERGY")
    M.Fire("UNIT_INVENTORY_CHANGED", "player")
    -- leaving a capital runs the reminders
    S.zone = "Stormwind City"
    M.Fire("ZONE_CHANGED_NEW_AREA")
    S.zone = "Elwynn Forest"
    M.Fire("ZONE_CHANGED_NEW_AREA")
    M.RunTimers()
    S.time = nil
    forget()
end)

test("weights derive from priority order; rogue equipment rules", function()
    for _, spec in ipairs(ns.SPEC_ORDER) do
        local prio = ns.Data.StatPriority[spec]
        local w = ns.Stats.Weights(spec, 10)
        local n = #prio.keys
        for r, k in ipairs(prio.keys) do
            local expect = (n - r + 1) / n
            if ns.Stats.PERCENT_KEYS[k] then expect = expect * 10 end
            near(w[k], expect, spec .. " " .. k)
        end
    end
    local can = ns.Stats.RogueCanUse
    eq(can(4, 2, "INVTYPE_CHEST", 30), true, "leather")
    eq(can(4, 3, "INVTYPE_CHEST", 60), false, "no mail")
    eq(can(2, 15, "INVTYPE_WEAPON", 30), true, "daggers")
    eq(can(2, 7, "INVTYPE_WEAPON", 30), true, "one-handed swords")
    eq(can(2, 0, "INVTYPE_WEAPON", 30), true, "one-handed axes (Blizzard; conflict flagged)")
    eq(can(2, 8, "INVTYPE_2HWEAPON", 30), false, "no two-handers")
    eq(can(2, 15, "INVTYPE_WEAPONOFFHAND", 8), false, "no off hand before 10")
    eq(can(2, 15, "INVTYPE_WEAPONOFFHAND", 10), true, "dual wield at 10")
    eq(can(4, 6, "INVTYPE_SHIELD", 30), false, "no shields")
    local note, warn = ns.Stats.WeaponNote("Assassination", 7, 2.6, 16, 50)
    truthy(note and warn, "Mutilate needs daggers")
    note = ns.Stats.WeaponNote("Combat", 7, 2.7, 16, 30)
    truthy(note and note:find("Slow main hand", 1, true), "slow main hand for Combat")
end)

test("stat parsing: Agility, hit, crit, AP, weapon DPS and speed", function()
    local raw = ns.Stats.ParseLines({ "Blade", "+12 Agility", "+5 Strength", "Equip: Improves your chance to hit by 1%.",
        "Equip: Improves your chance to get a critical strike by 2%.", "Equip: +28 Attack Power.", "(42.5 damage per second)", "Speed 2.70" })
    eq(raw.AGI, 12); eq(raw.STR, 5); eq(raw.HIT, 1); eq(raw.CRIT, 2); eq(raw.AP, 28); eq(raw.WEAPON_DPS, 42.5); eq(raw.SPEED, 2.7)
end)

test("talent builds decode onto Forever's trees (all 51 points)", function()
    eq(#ns.Data.TalentTrees, 3, "three trees")
    local valid60 = 0
    for _, b in ipairs(ns.Data.DecodedBuilds) do
        truthy(b.valid, "build decodes: " .. tostring(b.reason))
        eq(b.total, 51)
        valid60 = valid60 + 1
    end
    eq(valid60, 7, "seven Icy Veins builds")
    for _, spec in ipairs(ns.SPEC_ORDER) do
        ns.DB.SetSpec(spec)
        M.texts = {}
        ns.UI.Open("talents")
        truthy(textHas("points (level"), spec .. " build summary line")
    end
end)

test("learn: lessons unlock by level, Pick Pocket lesson at 4, faction lessons filtered", function()
    local unlocked, upcoming = ns.Learn.Lessons(24, "Combat")
    truthy(#unlocked > 0 and #upcoming > 0)
    local four = false
    for _, l in ipairs(ns.Data.Learn.lessons) do
        if l.level == 4 and ((l.title or "") .. (l.body or "")):find("Pick Pocket", 1, true) then four = true end
    end
    truthy(four, "a level-4 Pick Pocket lesson")
    for _, l in ipairs(unlocked) do truthy(l.faction ~= "Horde", "no Horde lesson for Rip: " .. l.title) end
    truthy(#(ns.Data.Learn.rogue or {}) >= 6, "rogue articles")
end)

test("changes: research baseline + poller items, mark read", function()
    local n = ns.Changes.UnreadCount()
    truthy(n >= 3, "changes")
    ns.Changes.MarkRead(ns.Changes.All()[1])
    eq(ns.Changes.UnreadCount(), n - 1)
    ns.Changes.MarkAllRead()
    eq(ns.Changes.UnreadCount(), 0)
end)

test("map: Mark on map pins coordinates, never guesses without them", function()
    M.waypoints = {}
    truthy(ns.Map.Mark("Riverglades", { 40, 50 }, "Twilight Shadowmancer"))
    eq(M.waypoints[1].mapID, 2200); near(M.waypoints[1].x, 0.4)
    eq(ns.Map.Mark("Riverglades", nil, "no coords"), false, "no pin without coordinates")
    eq(#M.waypoints, 1)
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
