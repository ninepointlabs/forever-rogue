-- Post-fight summary: what you cast and short Rogue tips.
-- Uses UNIT_SPELLCAST_SUCCEEDED for the player only (no combat log). If the
-- client hides spell ids as secret values in combat, those casts are counted as
-- "hidden" and the summary says so instead of guessing.
local _, ns = ...

local Summary = {}
ns.Summary = Summary

local fight

function Summary.Start(now, energy)
    fight = { start = now, energyStart = energy, casts = {}, order = {}, hidden = 0 }
end

function Summary.OnCast(spellID, name)
    if not fight then return end
    if spellID == nil or ns.Auras.IsSecret(spellID) then
        fight.hidden = fight.hidden + 1
        return
    end
    name = name or ns.Auras.SpellName(spellID) or tostring(spellID)
    if not fight.casts[name] then
        fight.casts[name] = 0
        table.insert(fight.order, name)
    end
    fight.casts[name] = fight.casts[name] + 1
end

-- Rule-based tips. Each tip references a mechanic in content/learn.json.
-- knows(name) is injectable for tests.
function Summary.Tips(f, spec, context, knows)
    knows = knows or function(name) return ns.Progress.Knows(name) end
    local tips = {}
    local dur = f.duration or 0
    local c = f.casts
    local function n(name) return c[name] or 0 end
    local finishers = n("Eviscerate") + n("Rupture") + n("Slice and Dice") + n("Kidney Shot") + n("Expose Armor") + n("Death Mark")
    local builders = n("Sinister Strike") + n("Backstab") + n("Hemorrhage") + n("Mutilate") + n("Shank") + n("Ghostly Strike") + n("Riposte")
    if builders >= 5 and finishers == 0 then
        table.insert(tips, "Lots of combo points built but no finisher. Spend them: Eviscerate at 5 (Forever keeps combo points when you switch targets).")
    end
    if spec == "Combat" and dur >= 10 and n("Riposte") == 0 and knows("Riposte") then
        table.insert(tips, "No Riposte this fight. It lights up after you parry: press it whenever it's usable.")
    end
    if (spec == "Assassination" or spec == "Subtlety") and dur >= 12 and n("Shank") == 0 and knows("Shank") then
        table.insert(tips, spec == "Assassination" and "No Shank this fight. Shank on cooldown keeps Venom up (more poison damage)."
            or "No Shank this fight. With Boot Knife it's 2 combo points on a short cooldown.")
    end
    if dur >= 20 and n("Slice and Dice") == 0 and knows("Slice and Dice") and finishers > 0 then
        table.insert(tips, "No Slice and Dice in a long fight. Put it up early when the target will live.")
    end
    if f.energyEnd and f.energyEnd >= 90 and dur >= 8 then
        table.insert(tips, "You ended near full Energy: energy was wasted somewhere. Keep pressing builders.")
    end
    if f.hidden > 0 then
        table.insert(tips, ("%d cast(s) were hidden by the client's addon restrictions and aren't counted."):format(f.hidden))
    end
    return tips
end

function Summary.Finish(now, energy)
    if not fight then return nil end
    local f = fight
    fight = nil
    f.duration = math.floor((now - f.start) + 0.5)
    f.energyEnd = energy
    local total = 0
    for _, v in pairs(f.casts) do total = total + v end
    if f.duration < 4 or (total == 0 and f.hidden == 0) then return nil end
    local spec = ns.DB.ActiveSpec()
    f.tips = Summary.Tips(f, spec, ns.DB.Profile().rotationContext, nil)
    Summary.last = f
    return f
end

function Summary.Text(f)
    local parts = {}
    table.sort(f.order, function(a, b) return f.casts[a] > f.casts[b] end)
    for _, name in ipairs(f.order) do table.insert(parts, name .. " x" .. f.casts[name]) end
    return table.concat(parts, ", ")
end
