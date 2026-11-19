-- Poisons: On your weapons · Poisons · Reagents & tools.
local _, ns = ...
local UI = ns.UI

local TABS = { "On your weapons", "Poisons", "Reagents & tools" }
local tab = "On your weapons"
local S = {}

local function green(t) return UI.Hex(ns.PoisonAccent) .. t .. "|r" end
local function flag(e) return UI.FlagText(e) end

local function questRow(L, c)
    for _, q in ipairs(ns.Progress.ClassQuests(c.race, c.faction)) do
        if q.type == "poisons" then
            L:Row({ chip = { text = "Level " .. q.level, kind = "info" }, title = "Poisons come from a class quest: " .. q.name,
                sub = (q.zone and (q.zone .. " · ") or "") .. (q.needs and ("needs " .. q.needs .. " · ") or "") .. (q.reward or "teaches Poisons") .. flag(q),
                button = { label = "Quest", onClick = function() UI.Select("leveling", "Class quests") end } })
            return true
        end
    end
    L:Row({ chip = { text = "Level 20", kind = "info" }, title = "Poisons come from the level-20 class quest", sub = "See Leveling > Class quests." })
    return false
end

S["On your weapons"] = function(L, c)
    local unlocked = ns.Poisons.Unlocked()
    if not unlocked then
        questRow(L, c)
        L:Text(UI.Hex(UI.C.dim) .. "Until then there are no poison buttons. Sharpening stones and weightstones still work on your weapons.|r", { size = 12 })
        if unlocked == nil then L:Note("Poisons skill line not readable; the addon also counts poisons in your bags.") end
        return
    end
    local on = ns.Poisons.OnWeapons()
    local stock = ns.Poisons.Stock()
    for _, hand in ipairs({ "mh", "oh" }) do
        local want, base = ns.Poisons.ForHand(hand, c.spec, stock)
        local h = on and on[hand]
        local title, sub
        if on == nil then title, sub = "hidden", "The game isn't letting addons read your weapons right now."
        elseif h == "noweapon" then title, sub = "No weapon", ""
        elseif h == false then title, sub = "No poison", "Nothing on this weapon."
        else
            title = (h.name or "Temporary enchant") .. (h.left and ("  " .. ns.Poisons.FormatLeft(h.left)) or "")
            sub = (h.charges and (h.charges .. " charges") or "charges not shown") .. (h.stone and (" · also " .. h.stone) or "")
        end
        local okHand = ns.Poisons.HandOk(h, base)
        L:Row({ chip = { text = ns.Poisons.HAND_LABEL[hand], kind = okHand and "good" or "warn" }, title = title,
            sub = sub .. (want and ("\nSuggested: " .. want .. (ns.db.char[hand == "mh" and "poisonMH" or "poisonOH"].override and " (your pick)" or "")) or "") })
    end
    local rules = ns.Data.PoisonRules
    if rules and rules.stacks_with_temp_enchant then
        L:Note("Forever: a poison and a sharpening stone or weightstone can sit on the same weapon (Blizzard deep dive; not in client data yet per wowfdb). Verify in game.")
    end
    L:Label(green("Pin a poison per hand"))
    local bases = ns.Poisons.Bases()
    for _, hand in ipairs({ "mh", "oh" }) do
        local cfg = ns.db.char[hand == "mh" and "poisonMH" or "poisonOH"]
        local items = { { label = "Suggested", active = cfg.override == nil, onClick = function() cfg.override = nil ns.RefreshBars() UI.Refresh() end } }
        for _, b in ipairs(bases) do
            table.insert(items, { label = (b:gsub(" Poison", "")), active = cfg.override == b, onClick = function() cfg.override = b ns.RefreshBars() UI.Refresh() end })
        end
        L:Text(ns.Poisons.HAND_LABEL[hand], { size = 12 })
        L:Buttons(items, 92)
    end
    if rules then
        for _, s in ipairs(rules.suggested or {}) do
            L:Row({ title = s.spec .. ": " .. tostring(s.main_hand or "?") .. " / " .. tostring(s.off_hand or "?"), sub = s.why })
        end
        L:Source(rules)
    end
end

S.Poisons = function(L, c)
    local stock = ns.Poisons.Stock()
    local byBase = {}
    for _, p in ipairs(ns.Data.Poisons or {}) do
        local b = p.base or p.name
        byBase[b] = byBase[b] or {}
        table.insert(byBase[b], p)
    end
    for _, b in ipairs(ns.Poisons.Bases()) do
        local list = byBase[b] or {}
        table.sort(list, function(x, y) return (x.learn_level or 0) < (y.learn_level or 0) end)
        local have = stock[b]
        L:Label(green(b) .. (have and (UI.Hex(UI.C.dim) .. "  · " .. have.total .. " in bags|r") or ""))
        for _, p in ipairs(list) do
            local now = (p.learn_level or 99) <= c.level
            L:Row({ chip = { text = tostring(p.learn_level or "?"), kind = now and "good" or "neutral" }, title = p.name,
                right = p.charges and (p.charges .. " charges") or nil,
                sub = (p.effect or "") .. ((p.reagents and #p.reagents > 0) and ("\nReagents: " .. (function()
                    local t = {}
                    for _, r in ipairs(p.reagents) do t[#t + 1] = (r.count and (r.count .. "x ") or "") .. r.name end
                    return table.concat(t, ", ")
                end)()) or "") .. (p.notes and ("\n" .. p.notes) or "") .. flag(p) })
            L:Source(p)
        end
    end
    if #ns.Poisons.Bases() == 0 then L:Flag("No poison data in the research.") end
    local rules = ns.Data.PoisonRules
    if rules then
        if rules.charges_note then L:Note(rules.charges_note) end
        if rules.ap_scaling_note then L:Note(rules.ap_scaling_note) end
        if rules.max_rank_hotfix then L:Note("Hotfix " .. rules.max_rank_hotfix .. ": poison ranks can no longer exceed max rank.") end
    end
end

S["Reagents & tools"] = function(L, c)
    L:Text(UI.Hex(UI.C.dim) .. "Counts from your bags. Only reagents for spells you know are reminded (Settings > Reminders).|r", { size = 12 })
    for _, s in ipairs(ns.Rogue.Supplies()) do
        local r = s.rec
        L:Item(r.item_id, r.name, ("for %s%s%s"):format(tostring(r["for"] or "?"), r.vendor and (" · " .. r.vendor) or "", r.notes and ("\n" .. r.notes) or "") .. flag(r),
            (s.count > 0 and UI.Hex(UI.C.good) or (s.needed and UI.Hex(UI.C.warn) or UI.Hex(UI.C.dim))) .. s.count .. "|r")
        L:Source(r)
    end
    if not (ns.Data.RogueSupplies and ns.Data.RogueSupplies[1]) then L:Flag("No supplies in the research.") end
    L:Note("Leaving a city? The addon checks these when you zone out of a capital (reminders on).")
end

UI.RegisterPanel({
    key = "poisons", label = "Poisons",
    setSub = function(sub) for _, t in ipairs(TABS) do if t == sub then tab = sub end end end,
    render = function(L, c)
        L:Title("Poisons", "What's on your weapons, what to carry, and the reagents and tools you need")
        local items = {}
        for _, t in ipairs(TABS) do table.insert(items, { label = t, active = tab == t, onClick = function() tab = t UI.Refresh() end }) end
        L:Tabs(items)
        ;(S[tab] or S["On your weapons"])(L, c)
    end,
})
