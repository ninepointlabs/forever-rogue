-- Leveling › Class quests
local _, ns = ...
local UI = ns.UI

UI.LevelingSections = UI.LevelingSections or {}

UI.LevelingSections["Class quests"] = function(L, c)
    L:Text(UI.Hex(UI.C.dim) .. "Rogue class quests for " .. (c.race or "your race") .. " (" .. (c.faction or "?") .. "): the level-10 weapon quest, lockpicking around 15-16, poisons at 20 (the one you really need), then Horn of Xelthos, Ravenholdt and more. Other races' and the other faction's versions stay hidden.|r", { size = 12 })
    local list = ns.Progress.ClassQuests(c.race, c.faction)
    if #list == 0 then L:Text("No class quests in the research for you yet.") end
    for _, q in ipairs(list) do
        local done = ns.Progress.IsQuestDone(q.quest_id)
        local chip
        if done then chip = { text = "Done", kind = "good" }
        elseif q.missing and c.level >= (q.level or 0) then chip = { text = "Ready · ID unknown", kind = "warn" }
        elseif q.missing then chip = { text = "Level " .. (q.level or "?") .. " · ID unknown", kind = "neutral" }
        elseif c.level >= (q.level or 0) then chip = { text = "Ready", kind = "info" }
        else chip = { text = "Level " .. (q.level or "?"), kind = "neutral" } end
        local sub = {}
        if q.start_npc then table.insert(sub, "From " .. q.start_npc) end
        if q.zone then table.insert(sub, q.zone) end
        if q.reward_spell then table.insert(sub, "Teaches " .. q.reward_spell) end
        if q.needs then table.insert(sub, "Needs " .. q.needs) end
        if q.reward then table.insert(sub, "Reward: " .. q.reward) end
        if q.unconfirmed then table.insert(sub, UI.FLAG_ICON .. " " .. UI.Hex(UI.C.warn) .. (q.flag or "unconfirmed") .. "|r") end
        if q.notes then table.insert(sub, q.notes) end
        if q.coords then table.insert(sub, "Starts at " .. (type(q.coords) == "table" and table.concat(q.coords, ", ") or tostring(q.coords))) end
        if q.missing then L:Note(q.name .. ": quest ID not captured in the research, so completion can't be checked.") end
        L:Row({
            chip = chip, title = q.name, sub = table.concat(sub, " · "),
            right = "level " .. (q.level or "?") .. (q.quest_id and (" · #" .. q.quest_id) or ""),
            onEnter = q.reward_item_id and function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(q.reward_item_id)
                GameTooltip:Show()
            end or nil,
        })
        if q.steps and #q.steps > 0 and not done and c.level >= (q.level or 0) - 2 then
            for i, step in ipairs(q.steps) do L:Text(UI.Hex(UI.C.dim) .. i .. ".|r " .. step, { size = 12, indent = 30 }) end
        end
        L:Source(q)
    end
    local t = ns.Data.ClassTrainers
    if t and t.trainers then
        L:Label("Rogue trainers")
        local names = {}
        for _, tr in ipairs(t.trainers) do
            if type(tr) == "string" then names[#names + 1] = tr
            elseif not tr.faction or tr.faction == "Both" or tr.faction == c.faction then names[#names + 1] = tr.name .. " (" .. (tr.place or "?") .. ")" end
        end
        L:Text(table.concat(names, " · "), { size = 12 })
        if t.note then L:Note(t.note) end
        L:Source(t)
    end
end
