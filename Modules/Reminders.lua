-- Out-of-combat reminders: poisons on your weapons (once you have poisons),
-- reagents for spells you know (Flash Powder for Vanish, Blinding Powder for
-- Blind), Thieves' Tools once you know Pick Lock, the next class quest, and
-- Slice and Dice is NOT reminded out of combat (it's a finisher; the rotation
-- helper covers it). "Before you leave a city" runs the same checks on a zone
-- change out of a city (Boot.lua).
local _, ns = ...

local Reminders = {}
ns.Reminders = Reminders

local function itemCount(id, name)
    return ns.Rogue.CountItem(id, name)
end
Reminders.ItemCount = itemCount

-- The class quest that's open for this character at this level: the earliest one
-- at or below your level (+0) that isn't done. Quests without a researched ID
-- count as done once you turn them in or mark them done (Progress.IsClassQuestDone).
function Reminders.ClassQuest(level, race, faction)
    for _, q in ipairs(ns.Progress.ClassQuests(race, faction)) do
        -- Quests without a researched id can't be checked: remind only within 5 levels of them.
        -- If completion can't be read at all, stop reminding 5 levels later.
        local done = ns.Progress.IsClassQuestDone(q)
        local open = q.level and ((done == nil and (level or 1) - q.level <= 5) or done == false)
        if open and q.level <= (level or 1) and q.type ~= "repeatable" then
            return q
        end
    end
    return nil
end

-- Reagents & tools for spells you know.
function Reminders.Reagents()
    local out = {}
    for _, s in ipairs(ns.Rogue.Supplies()) do
        if s.needed and (s.item_id or s.name) then table.insert(out, s) end
    end
    return out
end

-- Returns { {id, label, ok, detail, icon} ... }.
function Reminders.Evaluate()
    local cfg = ns.db.char.reminders
    local out = {}
    local function add(id, enabled, applies, label, ok, detail, icon)
        if enabled and applies then
            table.insert(out, { id = id, label = label, ok = ok, detail = detail, icon = icon })
        end
    end

    -- Poisons: only once poisons are unlocked (level-20 class quest).
    local unlocked = ns.Poisons.Unlocked()
    if unlocked then
        local on = ns.Poisons.OnWeapons()
        local spec = ns.DB.ActiveSpec()
        local stock = ns.Poisons.Stock()
        for _, hand in ipairs({ "mh", "oh" }) do
            local want, base = ns.Poisons.ForHand(hand, spec, stock)
            local h = on and on[hand]
            if want and h ~= "noweapon" then
                local ok = ns.Poisons.HandOk(h, nil)
                add("poison:" .. hand, cfg.poisons, true, "Poison (" .. ns.Poisons.HAND_LABEL[hand]:lower() .. ")",
                    ok ~= false,
                    ok == nil and "can't read your weapons right now"
                        or ("Press the " .. (hand == "mh" and "MH" or "OH") .. " poison button on the Rogue bar: " .. want .. ". Lasts 30 minutes."),
                    "Interface\\Icons\\Ability_Poisons")
            end
        end
    end

    for _, r in ipairs(Reminders.Reagents()) do
        if r.use == "Pick Lock" then
            add("tools", cfg.thievesTools, true, r.name, r.count > 0, "You have no " .. r.name .. " (Pick Lock needs them in your bags).",
                "Interface\\Icons\\INV_Misc_Gear_03")
        else
            add("reagent:" .. r.name, cfg.reagents, true, r.name, r.count > 0, "You have none (for " .. tostring(r.use) .. ").",
                "Interface\\Icons\\INV_Misc_Bag_10")
        end
    end

    local level = UnitLevel("player") or 1
    local q = Reminders.ClassQuest(level, ns.Progress.PlayerRace(), UnitFactionGroup("player"))
    add("classQuest", cfg.classQuests, q ~= nil, "Class quest: " .. (q and q.name or ""), false,
        q and ("Level " .. q.level .. (q.reward and (": " .. q.reward) or "") .. (q.zone and (" · " .. q.zone) or "")) or "",
        "Interface\\Icons\\INV_Misc_Note_01")
    return out
end

function Reminders.Missing()
    if not ns.db.char.reminders.enabled or InCombatLockdown() then return {} end
    local miss = {}
    for _, r in ipairs(Reminders.Evaluate()) do
        if not r.ok then table.insert(miss, r) end
    end
    return miss
end
