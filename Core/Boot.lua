-- Events, slash commands, startup. Loaded last.
local ADDON, ns = ...

local f = CreateFrame("Frame")
ns.EventFrame = f

-- Rogue bar: Pick Lock and poison buttons, reagent and pocket cells (out of combat only).
function ns.RefreshBars()
    pcall(ns.RogueButtons.Refresh)
end

-- Capital cities: leaving one runs the reminders ("before you leave a city").
ns.CITIES = { ["Stormwind City"] = true, ["Ironforge"] = true, ["Darnassus"] = true, ["Orgrimmar"] = true,
    ["Undercity"] = true, ["Thunder Bluff"] = true }
local lastZone

local function OnLogin()
    if ns.disabled then
        ns.Print(("This addon is for WoW Forever only (needs WOW_PROJECT_ID %d, this client reports %s). It will stay off."):format(
            ns.FOREVER_PROJECT_ID, tostring(WOW_PROJECT_ID)))
        return
    end
    ForeverRogueDB, ForeverRogueCharDB = ns.DB.Init(ForeverRogueDB, ForeverRogueCharDB)
    local _, class = UnitClass("player")
    ns.isRogue = (class == "ROGUE")

    ns.UI.MinimapButton()
    ns.UI.RegisterSettings()
    ns.Tooltip.Install() -- gear tips follow the active profile's spec
    pcall(ns.Bags.Install)
    ns.Pockets.Register()
    ns.Gold.Register()
    ns.Locks.Register()
    ns.RefreshBars()
    ns.DualSpec.Register(f)
    lastZone = ns.Rogue.ZoneName()

    for _, ev in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_AURA",
        "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "PLAYER_TARGET_CHANGED", "GET_ITEM_INFO_RECEIVED", "GROUP_ROSTER_UPDATE",
        "UI_ERROR_MESSAGE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
        "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UNIT_INVENTORY_CHANGED", "UNIT_POWER_UPDATE" }) do
        pcall(f.RegisterEvent, f, ev)
    end
    pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SUCCEEDED", "player")
    pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SENT", "player")
    pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_FAILED", "player")

    if not ns.isRogue then
        ns.Print("You're not a Rogue; the window still works for reading. Tooltip tips use the active profile's spec.")
    end
    ns.Learn.ScanSpells(true)
    ns.db.char.lastLevel = UnitLevel("player")

    if ns.isRogue and not ns.DB.HasChosenSpec() then
        C_Timer.After(3, function()
            local lvl = UnitLevel("player") or 1
            if lvl < 10 then
                ns.Print(("Welcome! Talents start at level 10. Pick Assassination, Combat or Subtlety any time; for leveling the plan is %s, then dual spec at 40: Combat + Subtlety. (/frogue)"):format(ns.RECOMMENDED_LEVELING_SPEC))
            else
                ns.Print("Welcome! Pick Assassination, Combat or Subtlety to tailor everything. (/frogue)")
            end
            ns.UI.ShowPicker()
        end)
    end
    local unread = ns.Changes.UnreadCount()
    if unread > 0 then
        C_Timer.After(5, function() ns.Print(("%d unread in What's new. /frogue news"):format(unread)) end)
    end
    ns.Hud.Refresh()
    -- Upgrades already sitting in the bags: one summary line, no toast spam.
    C_Timer.After(6, function()
        local found = ns.Bags.Scan(true)
        if #found > 0 then
            ns.Print(("|cff3fdc5a%d upgrade(s) in your bags|r for %s, highlighted in your bags: %s"):format(#found, ns.DB.ActiveSpec(), found[1].link .. (#found > 1 and " ..." or "")))
        end
        ns.Bags.RefreshAll()
    end)
end

-- Reminder toast, throttled; out of combat only.
local lastReminder = 0
local function CheckReminders(force)
    if InCombatLockdown() or not ns.db then return end
    local now = GetTime()
    if not force and now - lastReminder < 60 then return end
    local miss = ns.Reminders.Missing()
    if #miss > 0 then
        lastReminder = now
        local names = {}
        for _, r in ipairs(miss) do table.insert(names, r.label) end
        ns.Hud.Toast("Reminder", "Missing: " .. table.concat(names, ", "), miss[1].icon)
    end
end
ns.CheckReminders = CheckReminders

local refreshPending
local function SoftRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.5, function()
        refreshPending = false
        ns.UI.Refresh()
        ns.UI.UpdateMinimap()
    end)
end

-- Bags: re-check highlights and announce new upgrades (throttled, out of combat).
local bagPending
local function BagRefresh()
    if bagPending then return end
    bagPending = true
    C_Timer.After(0.7, function()
        bagPending = false
        pcall(ns.Bags.RefreshAll)
        if not InCombatLockdown() then pcall(ns.Bags.Scan, false) end
    end)
end
ns.BagRefresh = BagRefresh

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then f:UnregisterEvent("ADDON_LOADED") end
        return
    end
    if event == "PLAYER_LOGIN" then
        OnLogin()
        return
    end
    if ns.disabled or not ns.db then return end
    ns.Fire("WOW_" .. event, ...)
    if event == "PLAYER_LEVEL_UP" then
        local level = ...
        ns.Training.OnLevelUp(level)
        for _, l in ipairs(ns.Learn.NewLessonsAt(level, ns.DB.ActiveSpec())) do
            ns.Hud.Toast("New lesson: " .. l.title, "Open Learn the Rogue (/frogue learn).", "Interface\\Icons\\INV_Misc_Book_07")
        end
        ns.db.char.lastLevel = level
        SoftRefresh()
        BagRefresh()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if ns.db.char.summary.enabled then ns.Summary.Start(GetTime(), ns.Rogue.Energy()) end
        ns.Hud.Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        local fight = ns.Summary.Finish(GetTime(), ns.Rogue.Energy())
        if fight and ns.db.char.summary.enabled then
            ns.Print(("Fight %ds: %s"):format(fight.duration, ns.Summary.Text(fight)))
            for _, t in ipairs(fight.tips) do print("  |cffffd200>|r " .. t) end
        end
        ns.Hud.Refresh()
        ns.RefreshBars()
        C_Timer.After(2, function() CheckReminders(false) end)
        SoftRefresh()
        BagRefresh()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then
            ns.Summary.OnCast(spellID)
            if not ns.Auras.IsSecret(spellID) then
                pcall(ns.Cooldowns.OnCast, spellID)
                if ns.Pockets.IsPickPocket(spellID) then ns.Pockets.BeginAttempt() end
            end
        end
    elseif event == "LOOT_OPENED" or event == "LOOT_READY" then
        ns.Gold.SetOpen("loot", true)
        ns.Pockets.OnLootOpened()
    elseif event == "LOOT_CLOSED" then
        local e = ns.Pockets.OnLootClosed()
        ns.Gold.OnMoney(nil, e and "pickpocket" or nil)
        ns.Gold.SetOpen("loot", false)
        if e then pcall(ns.RogueButtons.UpdatePlain) SoftRefresh() end
    elseif event == "PLAYER_MONEY" then
        ns.Gold.OnMoney()
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" then
        ns.Gold.SetOpen("merchant", event == "MERCHANT_SHOW")
    elseif event == "MAIL_SHOW" or event == "MAIL_CLOSED" then
        ns.Gold.SetOpen("mail", event == "MAIL_SHOW")
    elseif event == "QUEST_TURNED_IN" then
        ns.Gold.QuestTurnedIn()
    elseif event == "BANKFRAME_OPENED" or event == "BANKFRAME_CLOSED" then
        ns.Locks.SetBankOpen(event == "BANKFRAME_OPENED")
    elseif event == "SKILL_LINES_CHANGED" then
        pcall(ns.Locks.TrackSkill)
        if not InCombatLockdown() then ns.RefreshBars() end
    elseif event == "UNIT_POWER_UPDATE" then
        local unit = ...
        if unit == "player" then pcall(ns.Hud.Update) end
    elseif event == "SPELLS_CHANGED" then
        ns.Learn.ScanSpells(false)
        if not InCombatLockdown() then ns.RefreshBars() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        pcall(ns.Hud.Update)
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then SoftRefresh() pcall(ns.RogueButtons.Update) end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if not InCombatLockdown() then ns.RefreshBars() end
        local zone = ns.Rogue.ZoneName()
        if lastZone and ns.CITIES[lastZone] and zone ~= lastZone then
            C_Timer.After(2, function() CheckReminders(true) end)
        end
        lastZone = zone or lastZone
        SoftRefresh()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then pcall(ns.RogueButtons.Update) end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        ns.Stats.ClearCache()
        SoftRefresh()
        BagRefresh()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        SoftRefresh() -- uncached items were never stored in the stat cache, so no clear needed
        BagRefresh()
    elseif event == "BAG_UPDATE_DELAYED" then
        SoftRefresh()
        BagRefresh()
        pcall(ns.Locks.ScanBank)
        if not InCombatLockdown() then ns.RefreshBars() end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if not InCombatLockdown() then ns.RefreshBars() end
    end
end)
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

ns.On("SPEC_CHANGED", function()
    ns.Stats.ClearCache()
    ns.Bags.Reset()
    BagRefresh()
    if ns.UI.UpdateMinimap then ns.UI.UpdateMinimap() end
    ns.Hud.Refresh()
end)
ns.On("HUD_TOGGLE", function() ns.Hud.Refresh() end)
ns.On("HUD_RESET", function() ns.Hud.Place() end)
ns.On("MINIMAP_TOGGLE", function() ns.UI.MinimapButton() end)
ns.On("CHANGES_READ", function() ns.UI.UpdateMinimap() end)
ns.On("TOAST", function(title, text, icon) ns.Hud.Toast(title, text, icon) end)
ns.On("KEY_CHANGED", function() ns.UI.Refresh() end)
ns.On("REMINDERS_CHANGED", function() CheckReminders(true) end)

local function Slash(msg)
    if ns.disabled then
        ns.Print("Disabled: WoW Forever only.")
        return
    end
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local cmd, arg = msg:match("^(%S*)%s*(.*)$")
    local tabs = { home = "home", overview = "home", rotation = "rotation", learn = "learn", leveling = "leveling", talents = "talents",
        gear = "gear", quests = "quests", trainer = "trainer", riding = "riding", training = "training", spells = "training", mounts = "mounts",
        reminders = "reminders", news = "news", changes = "news", sources = "sources", about = "about", settings = "settings", options = "settings", config = "settings",
        energy = "energy", cooldowns = "cooldowns", cds = "cooldowns", pockets = "pockets", log = "log", pickpocket = "pickpocket", targets = "targets",
        boxes = "boxes", locks = "locks", lockpicking = "lockpicking", doors = "doors", poisons = "poisons", poison = "poisons", reagents = "reagents",
        gold = "gold", farms = "farms", pvp = "pvp", bags = "bags", weapons = "weapons" }
    if cmd == "" then
        ns.UI.Toggle()
    elseif cmd == "spec" then
        local aliases = { ass = "Assassination", assa = "Assassination", assassination = "Assassination", mut = "Assassination",
            combat = "Combat", com = "Combat", sub = "Subtlety", subtlety = "Subtlety", sublety = "Subtlety" }
        local want = aliases[arg]
        if want and ns.Specs[want] then
            ns.DB.SetSpec(want)
            ns.Print("Profile " .. ns.DB.ActiveId() .. " is now " .. want .. ".")
        else
            ns.UI.ShowPicker()
        end
    elseif cmd == "profile" or cmd == "swap" then
        local id = arg ~= "" and arg:upper() or ns.DB.OtherProfileId()
        if ns.DB.SwitchProfile(id) then ns.Print("Switched to profile " .. id .. " (" .. (ns.DB.ActiveSpec() or "no spec") .. ").") end
    elseif cmd == "hud" then
        ns.db.char.rotation.enabled = not ns.db.char.rotation.enabled
        ns.Hud.Refresh()
    elseif cmd == "reset-hud" then
        ns.db.char.rotation.point = nil
        ns.Hud.Place()
    elseif cmd == "bar" then
        if arg == "debug" then ns.RogueButtons.Debug() return end
        if InCombatLockdown() then ns.Print("Out of combat only.") return end
        if arg == "reset" then
            ns.RogueBar.ResetPosition()
            ns.Print("Rogue bar moved back to its default spot.")
        else
            ns.UI.Open("settings", "Rogue bar")
        end
    elseif cmd == "remind" then
        CheckReminders(true)
    elseif tabs[cmd] then
        ns.UI.Open(tabs[cmd])
    else
        ns.Print("/frogue [home|rotation|gear|pvp|pockets|poisons|leveling|talents|gold|learn|news|settings]")
        ns.Print("also: log targets boxes locks doors reagents bags weapons farms energy cooldowns trainer quests riding reminders sources about")
        ns.Print("/frogue spec [ass|combat|sub] · /frogue profile [A|B] · /frogue hud · /frogue reset-hud · /frogue remind · /frogue bar [reset|debug]")
    end
end

-- Tim's decision: one slash command, /frogue.
SLASH_FOREVERROGUE1 = "/frogue"
SlashCmdList.FOREVERROGUE = Slash
