-- Rogue state readers: Energy, Combo Points, Stealth, skill lines (Lockpicking,
-- Poisons), reagents and tools in your bags, the "next class quest" helpers.
--
-- Contract (same as Modules/Auras.lua): a reader returns a value, false
-- (definitely absent) or nil (the client won't tell us: secret or missing API).
-- Your own Energy and Combo Points are readable even in combat on Forever
-- (BRIEF §3); everything is still pcall-wrapped and secret-checked.
local _, ns = ...

local Rogue = {}
ns.Rogue = Rogue

local function secret(v) return ns.Auras.IsSecret(v) end

-- Enum.PowerType: Energy = 3, ComboPoints = 4 (fallbacks when Enum is absent).
local function powerType(name, fallback)
    local E = rawget(_G, "Enum")
    local pt = E and E.PowerType and E.PowerType[name]
    if type(pt) == "number" then return pt end
    return fallback
end

function Rogue.Energy()
    local ok, cur = pcall(UnitPower, "player", powerType("Energy", 3))
    if not ok or cur == nil or secret(cur) then return nil end
    return cur
end

function Rogue.EnergyMax()
    local ok, max = pcall(UnitPowerMax, "player", powerType("Energy", 3))
    if not ok or max == nil or secret(max) then return nil end
    return max
end

-- Combo points: Forever keeps them on the player (they survive a target switch,
-- BRIEF §7.1), so read the player's ComboPoints power first, then the Classic
-- GetComboPoints("player", "target") if the client has it.
function Rogue.ComboPoints()
    local ok, cp = pcall(UnitPower, "player", powerType("ComboPoints", 4))
    if ok and type(cp) == "number" and not secret(cp) then return cp end
    local fn = rawget(_G, "GetComboPoints")
    if fn then
        local ok2, cp2 = pcall(fn, "player", "target")
        if ok2 and type(cp2) == "number" and not secret(cp2) then return cp2 end
    end
    return nil
end

-- Stealth or Vanish up (true/false/nil).
function Rogue.Stealthed()
    local fn = rawget(_G, "IsStealthed")
    if fn then
        local ok, v = pcall(fn)
        if ok and v ~= nil and not secret(v) then return v and true or false end
    end
    local st = ns.Auras.PlayerHas("Stealth")
    if st == nil then return nil end
    if st then return true end
    local va = ns.Auras.PlayerHas("Vanish")
    if va == nil then return nil end
    return va and true or false
end

-- In melee range of the target: Sinister Strike's range check when the client
-- answers, else unknown.
function Rogue.InMelee()
    if not UnitExists("target") then return false end
    if C_Spell and C_Spell.IsSpellInRange then
        local ok, r = pcall(C_Spell.IsSpellInRange, ns.Rotation.SpellId("Sinister Strike") or "Sinister Strike", "target")
        if ok and r ~= nil and not secret(r) then return r and true or false end
    end
    return nil
end

----------------------------------------------------------------------------
-- Skill lines (Lockpicking and Poisons are their own lines in Forever).
-- Classic API GetNumSkillLines/GetSkillLineInfo(i) -> name, isHeader, isExpanded,
-- rank, numTempPoints, modifier, maxRank. Returns { rank, max } or nil.
----------------------------------------------------------------------------
function Rogue.SkillLine(name)
    local n = rawget(_G, "GetNumSkillLines")
    local info = rawget(_G, "GetSkillLineInfo")
    if not n or not info then return nil end
    local ok, count = pcall(n)
    if not ok or type(count) ~= "number" or secret(count) then return nil end
    for i = 1, count do
        local ok2, sname, header, _, rank, temp, mod, max = pcall(info, i)
        if ok2 and sname and not secret(sname) and not header and sname == name then
            if secret(rank) or secret(max) then return nil end
            return { rank = (rank or 0) + (mod or 0), base = rank or 0, max = max or 0 }
        end
    end
    return false
end

-- Lockpicking cap = level x 5 (BRIEF §7.7: 80 at 16 ... 300 at 60).
function Rogue.LockpickCap(level)
    local per = (ns.Data.LockpickRules and ns.Data.LockpickRules.cap_per_level) or 5
    return math.min(300, (level or 1) * per)
end

function Rogue.Lockpicking()
    return Rogue.SkillLine("Lockpicking")
end

function Rogue.PoisonsSkill()
    return Rogue.SkillLine("Poisons")
end

----------------------------------------------------------------------------
-- Bags: counts by item id or by item name (links carry the name).
----------------------------------------------------------------------------
Rogue.BAGS = { 0, 1, 2, 3, 4, 5 } -- backpack, four bags, reagent bag

function Rogue.EachBagItem(fn, bags)
    if not (C_Container and C_Container.GetContainerNumSlots) then return end
    for _, bag in ipairs(bags or Rogue.BAGS) do
        local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
        if ok and type(n) == "number" and not secret(n) then
            for slot = 1, n do
                local ok2, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                if ok2 and type(info) == "table" and info.hyperlink and not secret(info.hyperlink) then
                    local name = info.itemName or tostring(info.hyperlink):match("%[(.-)%]")
                    local id = info.itemID or tonumber(tostring(info.hyperlink):match("item:(%d+)"))
                    if fn(bag, slot, id, name, info.stackCount or 1, info.hyperlink) then return end
                end
            end
        end
    end
end

function Rogue.CountItem(id, name)
    if id and C_Item and C_Item.GetItemCount then
        local ok, n = pcall(C_Item.GetItemCount, id)
        if ok and type(n) == "number" and not secret(n) then return n end
    end
    local total = 0
    Rogue.EachBagItem(function(_, _, iid, iname, count)
        if (id and iid == id) or (name and iname == name) then total = total + count end
    end)
    return total
end

-- Reagents & tools the addon checks (from research rogue_supplies; ids sourced).
-- Each: { name, item_id, for, needed = bool (a spell you know uses it), count }
function Rogue.Supplies()
    local out = {}
    for _, r in ipairs(ns.Data.RogueSupplies or {}) do
        local use = r["for"]
        local needed
        if use == "Pick Lock" then
            -- Only Thieves' Tools are required; gloves/potions on the same line are optional helpers.
            needed = (r.name or ""):find("Thieves", 1, true) ~= nil and ns.Progress.Knows("Pick Lock")
        elseif use and ns.Rotation.IsKnownName(use) then
            needed = ns.Progress.Knows(use)
        else
            needed = false
        end
        table.insert(out, { rec = r, name = r.name, item_id = r.item_id, use = use, needed = needed,
            count = Rogue.CountItem(r.item_id, r.name) })
    end
    return out
end

function Rogue.HasThievesTools()
    for _, s in ipairs(Rogue.Supplies()) do
        if s.use == "Pick Lock" and (s.name or ""):find("Thieves", 1, true) then return s.count > 0, s end
    end
    return nil
end

----------------------------------------------------------------------------
-- Instance / unit readability (BRIEF §3: inside instances creature names and
-- GUIDs are secret).
----------------------------------------------------------------------------
function Rogue.InInstance()
    if not IsInInstance then return false end
    local ok, inside, kind = pcall(IsInInstance)
    if not ok or secret(inside) then return true end
    return inside and true or false, kind
end

function Rogue.ZoneName()
    local fn = rawget(_G, "GetRealZoneText") or rawget(_G, "GetZoneText")
    if fn then
        local ok, z = pcall(fn)
        if ok and z and z ~= "" and not secret(z) then return z end
    end
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and id and not secret(id) then
            local ok2, info = pcall(C_Map.GetMapInfo, id)
            if ok2 and info and info.name and not secret(info.name) then return info.name end
        end
    end
    return nil
end

-- Target name/level/guid if readable (each nil when secret).
function Rogue.TargetInfo()
    if not UnitExists("target") then return nil end
    local info = {}
    local ok, n = pcall(UnitName, "target")
    if ok and n and not secret(n) then info.name = n end
    local ok2, l = pcall(UnitLevel, "target")
    if ok2 and type(l) == "number" and not secret(l) then info.level = l end
    local ok3, g = pcall(UnitGUID, "target")
    if ok3 and g and not secret(g) then info.guid = g end
    local ok4, t = pcall(UnitCreatureType, "target")
    if ok4 and t and not secret(t) then info.creatureType = t end
    return info
end

-- Combat summary/HUD line: Energy and Combo Points.
function Rogue.HudLine()
    local e, cp = Rogue.Energy(), Rogue.ComboPoints()
    return ("Energy %s · CP %s"):format(e and tostring(e) or "hidden", cp and (cp .. "/5") or "hidden")
end
