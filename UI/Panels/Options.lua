-- Settings: General · Rogue bar · Tooltips & bags · Reminders · About the data · About.
local _, ns = ...
local UI = ns.UI

UI.SettingsSections = UI.SettingsSections or {}
local S = UI.SettingsSections

local TABS = { "General", "Rogue bar", "Tooltips & bags", "Reminders", "About the data", "About" }
local tab = "General"

S.General = function(L, c)
    local g, ch = ns.db.global, ns.db.char
    L:Label("Specs & dual spec")
    for _, id in ipairs(ns.DB.PROFILE_IDS) do
        local p = ns.DB.Profile(id)
        local items = {}
        for _, spec in ipairs(ns.SPEC_ORDER) do
            table.insert(items, { label = spec, active = p.spec == spec, onClick = function()
                ns.DB.SetSpec(spec, id)
                UI.Refresh()
            end })
        end
        L:Text(("Profile %s · talent spec %s%s"):format(id, id == "A" and "1" or "2", ns.DB.ActiveId() == id and (UI.Hex(UI.C.good) .. "  (active)|r") or ""))
        L:Buttons(items, 110)
    end
    local cb = L:Check("Switch profile automatically with my talent spec", ch.autoSwitch, function(v)
        ch.autoSwitch = v
        if v then ns.DualSpec.Sync() end
        UI.Refresh()
    end, "Swapping talent specs (dual spec, level 40) swaps the addon profile: spec 1 -> A, spec 2 -> B.")
    if not ns.DualSpec.IsAvailable() then
        cb:Disable()
        L:Text(UI.Hex(UI.C.dim) .. "This client doesn't expose the talent-group API.|r", { size = 12, indent = 30 })
    else
        local grp = ns.DualSpec.ActiveGroup()
        L:Text(UI.Hex(UI.C.dim) .. (ns.DualSpec.HasDualSpec() and ("Dual spec learned. Active talent spec: " .. tostring(grp or "?") .. ".")
            or "Dual spec not learned yet (level 40, at your class trainer). The plan: Enhancement on A, Restoration on B for groups.") .. "|r", { size = 12, indent = 30 })
    end

    L:Label("Rotation helper & fight summary")
    L:Check("Show the on-screen rotation helper", ch.rotation.enabled, function(v) ch.rotation.enabled = v ns.Fire("HUD_TOGGLE") end)
    L:Check("Only in combat", ch.rotation.showInCombatOnly, function(v) ch.rotation.showInCombatOnly = v ns.Fire("HUD_TOGGLE") end)
    L:Check("Post-fight summary in chat", ch.summary.enabled, function(v) ch.summary.enabled = v end)
    L:Buttons({ { label = "Reset helper position", onClick = function() ch.rotation.point = nil ns.Fire("HUD_RESET") end } })

    L:Label("Learning & window")
    L:Check("Hint the first time I learn a spell", ch.learn.hints, function(v) ch.learn.hints = v end)
    L:Check("Show minimap button", not g.minimap.hide, function(v) g.minimap.hide = not v ns.Fire("MINIMAP_TOGGLE") end)
    L:Check("Debug messages", g.debug, function(v) g.debug = v end)
    L:Text(UI.Hex(UI.C.dim) .. "Slash: /frogue · /frogue spec ass|combat|sub · /frogue pockets · /frogue poisons · /frogue boxes · /frogue gold · /frogue pvp · /frogue bar [reset|debug]|r", { size = 12 })
end

-- Cycle a setting through steps (button label "Keep 20" -> next value).
local function cycle(cfgT, key, steps, after)
    return function()
        local nextV = steps[1]
        for i, v in ipairs(steps) do if v == cfgT[key] then nextV = steps[i + 1] or steps[1] end end
        cfgT[key] = nextV
        if after then after() end
        UI.Refresh()
    end
end

local function keyRow(L, key, what, startCapture, clear)
    L:Row({ title = what .. " key", sub = key and "Pressing it presses the button, even if the key is bound to something else in Blizzard's menu." or "No key set (none by default).",
        right = key and (UI.Hex(UI.C.good) .. key .. "|r") or (UI.Hex(UI.C.dim) .. "none|r") })
    L:Buttons({
        { label = "Set key", onClick = startCapture, tip = "Press any key (Shift/Ctrl/Alt combos work). Esc cancels." },
        { label = "Clear key", onClick = function() clear(nil) UI.Refresh() end },
    })
end

S["Rogue bar"] = function(L, c)
    L:Text("One small bar: the Pick Lock button and the two poison buttons (they act: one press = one action, set up out of combat), plus reagent and pocket-counter cells that never act. Drag the strip on top to move it.", { size = 12 })
    L:Buttons({ { label = "Reset bar position", onClick = function() if not InCombatLockdown() then ns.RogueBar.ResetPosition() end end } })
    local ch = ns.db.char
    local function toggle(label, cfgKey, tip)
        L:Check(label, ch[cfgKey].enabled, function(v)
            if InCombatLockdown() then ns.Print("Out of combat only.") return end
            ch[cfgKey].enabled = v
            ns.RefreshBars()
            UI.Refresh()
        end, tip)
    end
    L:Label("Pick Lock")
    toggle("Show the Pick Lock button", "pickLock", "/cast Pick Lock + /use the next box you have the skill for. Verify on Forever: the macro pattern players use.")
    keyRow(L, ch.pickLock.key, "Pick Lock", function() ns.RogueButtons.StartKeyCapture("picklock") end, function(k) ns.RogueButtons.SetKey("picklock", k) end)
    L:Label("Poisons")
    toggle("Show the main-hand poison button", "poisonMH", "/use <poison> + /use 16. Shows once poisons are unlocked (level-20 class quest).")
    keyRow(L, ch.poisonMH.key, "Main-hand poison", function() ns.RogueButtons.StartKeyCapture("poisonmh") end, function(k) ns.RogueButtons.SetKey("poisonmh", k) end)
    toggle("Show the off-hand poison button", "poisonOH", "/use <poison> + /use 17. From level 10 (dual wield).")
    keyRow(L, ch.poisonOH.key, "Off-hand poison", function() ns.RogueButtons.StartKeyCapture("poisonoh") end, function(k) ns.RogueButtons.SetKey("poisonoh", k) end)
    L:Buttons({ { label = "Pick poisons", onClick = function() UI.Select("poisons") end } })
    L:Label("Cells")
    L:Check("Reagents & tools cell", ch.reagentCells.enabled, function(v) ch.reagentCells.enabled = v ns.RefreshBars() UI.Refresh() end)
    L:Check("Pockets this session counter", ch.pocketCounter.enabled, function(v) ch.pocketCounter.enabled = v ns.RefreshBars() UI.Refresh() end)
    L:Space(6)
    L:Text(UI.Hex(UI.C.dim) .. "Pick keys your desktop doesn't use (on Omarchy, Super combos belong to the desktop, so they're never offered). No key is bound by default. What the secure buttons do and their keys only change out of combat (Blizzard rule).|r", { size = 12 })
end

S["Tooltips & bags"] = function(L, c)
    local g = ns.db.global
    L:Check("Upgrade tips on item tooltips", g.tooltip.enabled, function(v) g.tooltip.enabled = v end)
    L:Check("Show what improves (stat changes) in tooltips", g.tooltip.showStats, function(v) g.tooltip.showStats = v end)
    L:Check("Highlight upgrades in my bags", g.bags.highlight, function(v) g.bags.highlight = v ns.Bags.RefreshAll() end,
        "Glow + arrow on bag items that beat what you're wearing for your active spec and that you can equip now.")
    L:Check("Tell me when an upgrade lands in my bags", g.bags.toast, function(v) g.bags.toast = v end)
    L:Space(6)
    L:Row({ title = "Hit/crit value", sub = "How many points of Agility/attack power 1% hit or crit (or 1 weapon DPS) is worth. An addon assumption, not from the research.",
        button = { label = g.percentScale .. " per 1%", onClick = function()
            local steps = { 5, 8, 10, 12, 14, 20 }
            local nextV = steps[1]
            for i, v in ipairs(steps) do if v == g.percentScale then nextV = steps[i + 1] or steps[1] end end
            g.percentScale = nextV
            ns.Stats.ClearCache()
            UI.Refresh()
        end } })
end

S.About = function(L, c)
    local version = tostring(ns.VERSION)
    if not version:match("^v") then version = "v" .. version end
    L:Row({ icon = ns.NEUTRAL_ICON, title = ns.TITLE .. " " .. version,
        sub = "The do-everything Rogue companion for World of Warcraft: Forever, for every Rogue race and both factions." })
    L:Label("Tested on")
    L:Row({ icon = "Interface\\Icons\\Ability_Stealth", title = "Rip",
        sub = "Human Rogue of the Alliance, on the CAMWOWUS2Realm1PvE realm (Normal). Rip is the test character and the default persona in these pages." })
    L:Text(UI.Hex(UI.C.dim) .. "If your pockets feel lighter in Northshire Valley, say hello.|r", { size = 12 })
    L:Label("Links")
    L:Link("Website", "https://forever-rogue.myazerothlife.com")
    L:Label("Sister addons")
    L:Link("Andric's Addon (Priest)", "https://andricsaddon.myazerothlife.com")
    L:Link("Parzelle's Addon (Mage)", "https://parzelles-addon.myazerothlife.com")
    L:Link("Tristan's Addon (Paladin)", "https://tristans-addon.myazerothlife.com")
    L:Link("Tazu's Addon (Shaman)", "https://tazus-addon.myazerothlife.com")
    L:Link("My Azeroth Life", "https://myazerothlife.com")
    L:Label("Credits")
    L:Row({ title = "Made by Nine Point Labs", sub = "Free and open source, MIT licence." })
    L:Row({ title = "Information from Blizzard, Icy Veins, Wowhead, wowfdb and endgametools", sub = "Credited per fact: see About the data, or the Sources & notes link on each screen. Single-source fan-site facts are marked unconfirmed." })
    L:Row({ title = "Community pickpocket data: GoldScout (wowgoldscout.com)", sub = "Crowdsourced by GoldScout addon users; shown with sample sizes and marked unconfirmed." })
    L:Text(UI.Hex(UI.C.dim) .. "Forever Rogue is an unofficial fan project, not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft and Warcraft are trademarks of Blizzard Entertainment, Inc.|r", { size = 11 })
end

UI.RegisterPanel({
    key = "settings", label = "Settings",
    setSub = function(sub) for _, t in ipairs(TABS) do if t == sub then tab = sub end end end,
    render = function(L, c)
        L:Title("Settings")
        local items = {}
        for _, t in ipairs(TABS) do
            table.insert(items, { label = t, active = tab == t, onClick = function() tab = t UI.Refresh() end })
        end
        L:Tabs(items)
        local fn = S[tab] or S.General
        fn(L, c)
    end,
})
