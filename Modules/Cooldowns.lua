-- Rotation > Cooldowns: your own cooldowns (Riposte, Shank, Ghostly Strike,
-- Kick, Vanish, Evasion, Sprint, Blind, Blade Flurry, Adrenaline Rush, Cold
-- Blood, Preparation ...) and buffs (Slice and Dice, Venom, Adrenaline Rush,
-- Blade Flurry, Evasion) where Forever lets addons read them.
--
-- Only YOUR spells: cooldowns come from C_Spell.GetSpellCooldown for spells you
-- know and buffs from your own auras. Nothing reads enemy health, casts or
-- cooldowns (Forever hides them from addons). Cooldown widgets take secret
-- start/duration values directly, so a swirl still works when the numbers
-- themselves are hidden; text then says "hidden".
local _, ns = ...

local CD = {}
ns.Cooldowns = CD

-- Names only; every number shown comes from the game. Cooldown lengths are
-- never hard-coded here.
CD.SPELLS = { "Riposte", "Shank", "Ghostly Strike", "Kick", "Gouge", "Kidney Shot", "Vanish", "Evasion", "Sprint", "Blind",
    "Blade Flurry", "Adrenaline Rush", "Cold Blood", "Preparation", "Premeditation", "Feint", "Distract", "Stealth" }
-- Buffs on you worth showing: { aura, maxStacks? }.
CD.PROCS = {
    { aura = "Slice and Dice" },
    { aura = "Venom" },
    { aura = "Adrenaline Rush" },
    { aura = "Blade Flurry" },
    { aura = "Evasion" },
    { aura = "Cold Blood" },
}

-- Known cooldowns: { spell, left (sec|nil hidden), start, duration, readable }.
function CD.List(knows)
    knows = knows or function(n) return ns.Progress.Knows(n) end
    local out = {}
    for _, name in ipairs(CD.SPELLS) do
        if knows(name) then
            local id = ns.Rotation.SpellId(name) or name
            local start, duration, readable = ns.Auras.CooldownRaw(id)
            table.insert(out, { spell = name, left = ns.Auras.CooldownLeft(id), start = start, duration = duration, readable = readable })
        end
    end
    return out
end

-- Your procs: { aura, up = true|false|nil, stacks = n|nil, left = sec|nil, max }.
-- A buff counts as relevant once its talent/spell is known (Venom via Shank + the
-- Venom talent).
CD.SOURCE = { Venom = "Venom" }
function CD.Procs(knows, find)
    knows = knows or function(n) return ns.Progress.Knows(n) end
    find = find or function(n) return ns.Auras.Find("player", ns.Rotation.LiveState.spellName(n), "HELPFUL") end
    local out = {}
    for _, p in ipairs(CD.PROCS) do
        if knows(CD.SOURCE[p.aura] or p.aura) then
            local data = find(p.aura)
            local e = { aura = p.aura, max = p.max }
            if data == nil then
                e.up = nil
            elseif data == false then
                e.up, e.stacks = false, 0
            else
                e.up = true
                local c = data.applications or data.charges or data.count
                if c ~= nil and not ns.Auras.IsSecret(c) then e.stacks = math.max(1, c) end
                e.left = ns.Auras.TimeLeft(data)
            end
            table.insert(out, e)
        end
    end
    return out
end

-- One short line for the HUD: Energy, Combo Points and Slice and Dice.
function CD.HudLine(knows, find)
    local line = ns.Rogue.HudLine()
    for _, p in ipairs(CD.Procs(knows, find)) do
        if p.aura == "Slice and Dice" then
            if p.up == nil then return line .. " · SnD hidden" end
            if p.up then return line .. " · SnD " .. (p.left and (math.floor(p.left) .. "s") or "up") end
            return line .. " · SnD off"
        end
    end
    return line
end

function CD.OnCast() end -- kept for the cast event hook; nothing to track yet
