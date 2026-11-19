-- Bag space: free slots and the next bag upgrade for your level, faction and race
-- (research bags[], BRIEF §7.10). Gear upgrade glow in the bags is UI/Bags.lua.
local _, ns = ...

local BagSpace = {}
ns.BagSpace = BagSpace

local function secret(v) return ns.Auras.IsSecret(v) end

-- { free, total, bags = { [bag] = { slots, free } }, smallest = n (equipped bag 1-4, 0 = empty slot) }
function BagSpace.Summary()
    local out = { free = 0, total = 0, bags = {} }
    if not (C_Container and C_Container.GetContainerNumSlots) then return out end
    for _, bag in ipairs({ 0, 1, 2, 3, 4, 5 }) do
        local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
        n = (ok and type(n) == "number" and not secret(n)) and n or 0
        local free = 0
        if C_Container.GetContainerNumFreeSlots then
            local ok2, f = pcall(C_Container.GetContainerNumFreeSlots, bag)
            if ok2 and type(f) == "number" and not secret(f) then free = f end
        end
        out.bags[bag] = { slots = n, free = free }
        if bag ~= 5 then
            out.total = out.total + n
            out.free = out.free + free
        end
        if bag >= 1 and bag <= 4 then
            if out.smallest == nil or n < out.smallest then out.smallest = n end
        end
    end
    return out
end

local function factionOk(b, faction)
    return not b.faction or b.faction == "Both" or not faction or b.faction == faction
end

-- Research levels may be ranges ("1-17"): use the first number.
local function levelOf(b)
    return tonumber(tostring(b.level or ""):match("^(%d+)"))
end
BagSpace.LevelOf = levelOf

local function raceOk(b, race)
    return not b.races or b.races == "All" or not race or ns.Progress.RaceMatches(b.races, race)
end

-- Bags you could get now (level <= yours + 2) that beat your smallest bag,
-- best first (more slots, then easier source: quest/drop before vendor).
local ORDER = { quest = 1, drop = 2, ["world drop"] = 3, vendor = 4, craft = 5, rep = 6 }
function BagSpace.Upgrades(level, faction, race, smallest)
    local out = {}
    for _, b in ipairs(ns.Data.Bags or {}) do
        if factionOk(b, faction) and raceOk(b, race) and (b.slots or 0) > (smallest or 0)
            and (not levelOf(b) or levelOf(b) <= (level or 60) + 2) then
            out[#out + 1] = b
        end
    end
    table.sort(out, function(a, b)
        if (a.slots or 0) ~= (b.slots or 0) then return (a.slots or 0) > (b.slots or 0) end
        local oa, ob = ORDER[a.source_type] or 9, ORDER[b.source_type] or 9
        if oa ~= ob then return oa < ob end
        return (levelOf(a) or 0) < (levelOf(b) or 0)
    end)
    return out
end

-- The one bag to point at on Home: prefer a race/starter quest bag you can do
-- now, else the best upgrade.
function BagSpace.Next(level, faction, race, smallest)
    local list = BagSpace.Upgrades(level, faction, race, smallest)
    for _, b in ipairs(list) do
        if b.races and b.races ~= "All" and b.source_type == "quest" then return b end
    end
    -- Prefer something at your level over a far bigger bag you can't reach yet.
    for _, b in ipairs(list) do
        if b.source_type == "quest" and levelOf(b) and levelOf(b) <= (level or 60) + 2 then return b end
    end
    return list[1]
end
